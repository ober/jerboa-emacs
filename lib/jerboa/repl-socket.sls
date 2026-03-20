#!chezscheme
;;; Non-blocking socket primitives for the debug REPL.
;;;
;;; Provides raw fd-level non-blocking I/O that never blocks a Chez thread
;;; in a foreign call.  Used by the debug REPL's timer-based polling loop
;;; to avoid GC deadlocks (Chez stop-the-world GC cannot proceed when a
;;; thread is blocked in accept/read/poll foreign calls).

(library (jerboa repl-socket)
  (export
    repl-socket-listen    ;; (address port) → (values listen-fd actual-port)
    repl-socket-accept    ;; (listen-fd) → client-fd or #f
    repl-socket-read      ;; (fd) → string or #f (EAGAIN) or 'eof
    repl-socket-write     ;; (fd string) → #t or #f
    repl-socket-close     ;; (fd) → void
    repl-socket-poll      ;; (fd timeout-ms) → 'ready, #f (timeout), or 'error
    repl-socket-nanosleep ;; (milliseconds) → void
    repl-deactivate-thread! ;; () → void — deactivate for GC
    repl-activate-thread!   ;; () → void — reactivate after foreign call
    ;; GC-safe subprocess/file I/O — deactivates thread during blocking calls
    repl-capture-command  ;; (cmd-string) → output-string
    repl-read-file        ;; (path) → content-string (empty on error)
    repl-write-file)      ;; (path content) → #t or #f

  (import (chezscheme))

  ;; ========== FFI ==========

  ;; load-shared-object #f → dlopen(NULL) → gives access to all symbols
  ;; in the main binary, whether dynamically or statically linked.
  ;; Must always be called (even for static builds) so poll/nanosleep/etc.
  ;; are found by foreign-procedure.
  (define _libc-loaded
    (let ((v (getenv "JEMACS_STATIC")))
      (if (and v (not (string=? v "")) (not (string=? v "0")))
          #f  ; static build: symbols from repl_shim.c + libc via --export-dynamic
          (begin
            (load-shared-object #f)
            ;; Load repl_shim.so for GC-safe subprocess/file I/O helpers.
            ;; Try several paths: next to the binary, in support/, or via LD_LIBRARY_PATH.
            (let try ((paths (list "repl_shim.so"
                                   "./repl_shim.so"
                                   "support/repl_shim.so"
                                   "../support/repl_shim.so")))
              (if (null? paths)
                ;; If no .so found, the capture functions won't be available
                ;; but socket functions (from libc) still work
                (void)
                (guard (e (#t (try (cdr paths))))
                  (load-shared-object (car paths)))))))))

  (define c-socket    (foreign-procedure "socket" (int int int) int))
  (define c-bind      (foreign-procedure "bind" (int void* int) int))
  (define c-listen    (foreign-procedure "listen" (int int) int))
  (define c-accept    (foreign-procedure "accept" (int void* void*) int))
  (define c-close     (foreign-procedure "close" (int) int))
  (define c-setsockopt (foreign-procedure "setsockopt" (int int int void* int) int))
  (define c-read      (foreign-procedure "read" (int u8* size_t) ssize_t))
  (define c-write     (foreign-procedure "write" (int u8* size_t) ssize_t))
  (define c-htons     (foreign-procedure "htons" (unsigned-short) unsigned-short))
  (define c-inet-pton (foreign-procedure "inet_pton" (int string void*) int))
  (define c-getsockname (foreign-procedure "getsockname" (int void* void*) int))
  (define c-fcntl     (foreign-procedure "fcntl" (int int int) int))
  ;; poll/nanosleep/thread activation use wrapper names from repl_shim.c
  ;; because musl static binaries don't export libc symbols to dlsym.
  (define c-poll      (foreign-procedure "repl_poll" (void* unsigned-int int) int))
  (define c-nanosleep (foreign-procedure "repl_nanosleep" (void* void*) int))

  ;; Chez SMP thread activation — allows GC to proceed while this thread
  ;; is blocked in foreign calls. Must bracket foreign blocking calls:
  ;;   (repl-deactivate-thread!)  ; tell GC we're not using Scheme heap
  ;;   ... foreign blocking call (poll, nanosleep) ...
  ;;   (repl-activate-thread!)    ; re-enter Scheme safely
  (define c-deactivate (foreign-procedure "repl_deactivate_thread" () void))
  (define c-activate   (foreign-procedure "repl_activate_thread" () int))

  ;; errno
  (define c-errno-location (foreign-procedure "__errno_location" () void*))
  (define (get-errno) (foreign-ref 'int (c-errno-location) 0))
  (define EAGAIN 11)
  (define EINTR 4)

  ;; Constants
  (define AF_INET 2)
  (define SOCK_STREAM 1)
  (define SOL_SOCKET 1)
  (define SO_REUSEADDR 2)
  (define SOCKADDR_IN_SIZE 16)
  (define F_GETFL 3)
  (define F_SETFL 4)
  (define O_NONBLOCK #x800)
  (define POLLIN #x001)
  (define POLLFD_SIZE 8)  ;; struct pollfd: int fd, short events, short revents

  ;; ========== Helpers ==========

  (define (set-nonblocking! fd)
    (let ([flags (c-fcntl fd F_GETFL 0)])
      (c-fcntl fd F_SETFL (bitwise-ior flags O_NONBLOCK))))

  (define (make-sockaddr-in address port)
    (let ([buf (foreign-alloc SOCKADDR_IN_SIZE)])
      (let lp ([i 0])
        (when (< i SOCKADDR_IN_SIZE)
          (foreign-set! 'unsigned-8 buf i 0)
          (lp (+ i 1))))
      (foreign-set! 'unsigned-short buf 0 AF_INET)
      (foreign-set! 'unsigned-short buf 2 (c-htons port))
      (let ([addr-ptr (+ buf 4)])
        (when (= (c-inet-pton AF_INET address addr-ptr) 0)
          (foreign-free buf)
          (error 'make-sockaddr-in "invalid address" address)))
      buf))

  (define (sockaddr-in-port buf)
    (let ([hi (foreign-ref 'unsigned-8 buf 2)]
          [lo (foreign-ref 'unsigned-8 buf 3)])
      (+ (* hi 256) lo)))

  ;; ========== Public API ==========

  (define (repl-socket-listen address port)
    ;; Create a non-blocking TCP listen socket.
    ;; Returns (values listen-fd actual-port).
    (let ([fd (c-socket AF_INET SOCK_STREAM 0)])
      (when (< fd 0)
        (error 'repl-socket-listen "socket() failed"))
      ;; SO_REUSEADDR
      (let ([one (foreign-alloc 4)])
        (foreign-set! 'int one 0 1)
        (c-setsockopt fd SOL_SOCKET SO_REUSEADDR one 4)
        (foreign-free one))
      ;; Bind
      (let ([addr (make-sockaddr-in address port)])
        (let ([rc (c-bind fd addr SOCKADDR_IN_SIZE)])
          (foreign-free addr)
          (when (< rc 0)
            (c-close fd)
            (error 'repl-socket-listen "bind() failed" address port))))
      ;; Listen
      (when (< (c-listen fd 4) 0)
        (c-close fd)
        (error 'repl-socket-listen "listen() failed"))
      ;; Non-blocking
      (set-nonblocking! fd)
      ;; Get actual port
      (let ([actual-port
             (let ([buf (foreign-alloc SOCKADDR_IN_SIZE)]
                   [len (foreign-alloc 4)])
               (foreign-set! 'int len 0 SOCKADDR_IN_SIZE)
               (c-getsockname fd buf len)
               (let ([p (sockaddr-in-port buf)])
                 (foreign-free buf)
                 (foreign-free len)
                 p))])
        (values fd actual-port))))

  (define (repl-socket-accept listen-fd)
    ;; Non-blocking accept.  Returns client-fd or #f if no connection pending.
    (let ([cfd (c-accept listen-fd 0 0)])
      (cond
        [(>= cfd 0)
         (set-nonblocking! cfd)
         cfd]
        [else #f])))

  (define (repl-socket-read fd)
    ;; Non-blocking read.  Returns:
    ;;   string — data read
    ;;   #f     — EAGAIN (no data available)
    ;;   'eof   — client disconnected or error
    (let ([buf (make-bytevector 1024)])
      (let ([n (c-read fd buf 1024)])
        (cond
          [(> n 0)
           (utf8->string (bytevector-slice buf 0 n))]
          [(= n 0) 'eof]  ;; TCP EOF
          [else
           (let ([e (get-errno)])
             (if (or (= e EAGAIN) (= e EINTR))
               #f     ;; no data yet
               'eof))]))))  ;; real error → treat as disconnect

  (define (repl-socket-write fd str)
    ;; Write a string to fd.  Uses blocking retry for simplicity
    ;; (REPL output is small, so this returns quickly).
    ;; Returns #t on success, #f on error.
    (let* ([bv (string->utf8 str)]
           [len (bytevector-length bv)])
      (let lp ([written 0])
        (if (= written len)
          #t
          (let ([n (c-write fd
                     (if (= written 0)
                       bv
                       ;; Offset: copy remaining bytes
                       (let ([tmp (make-bytevector (- len written))])
                         (bytevector-copy! bv written tmp 0 (- len written))
                         tmp))
                     (- len written))])
            (cond
              [(> n 0) (lp (+ written n))]
              [(and (< n 0)
                    (let ([e (get-errno)])
                      (or (= e EAGAIN) (= e EINTR))))
               (lp written)]  ;; retry immediately (small data)
              [else #f]))))))

  (define (repl-socket-close fd)
    (c-close fd)
    (void))

  (define (bytevector-slice bv start end)
    (let* ([len (- end start)]
           [result (make-bytevector len)])
      (bytevector-copy! bv start result 0 len)
      result))

  (define (repl-socket-poll fd timeout-ms)
    ;; Use poll() to wait for data on fd with a timeout.
    ;; Returns 'ready if data available, #f on timeout, 'error on error.
    ;; This is a pure C call — it does NOT interact with Chez GC.
    (let ([pfd (foreign-alloc POLLFD_SIZE)])
      (foreign-set! 'int pfd 0 fd)              ;; .fd
      (foreign-set! 'short pfd 4 POLLIN)         ;; .events
      (foreign-set! 'short pfd 6 0)              ;; .revents
      (let ([rc (c-poll pfd 1 timeout-ms)])
        (let ([result (cond
                        [(> rc 0) 'ready]
                        [(= rc 0) #f]       ;; timeout
                        [else 'error])])
          (foreign-free pfd)
          result))))

  (define (repl-socket-nanosleep ms)
    ;; Sleep for ms milliseconds using raw nanosleep().
    ;; This is a pure C call — does NOT use Chez sleep/condition-wait,
    ;; so it doesn't participate in GC rendezvous.
    (let ([ts (foreign-alloc 16)])  ;; struct timespec: long tv_sec, long tv_nsec
      (foreign-set! 'long ts 0 (quotient ms 1000))
      (foreign-set! 'long ts 8 (* (remainder ms 1000) 1000000))
      (c-nanosleep ts 0)
      (foreign-free ts)))

  (define (repl-deactivate-thread!)
    ;; Deactivate this Chez thread for GC purposes.
    ;; After this call, GC will NOT wait for this thread at rendezvous.
    ;; The thread must NOT touch any Scheme heap objects until reactivated.
    (c-deactivate))

  (define (repl-activate-thread!)
    ;; Reactivate this Chez thread. Must be called before accessing any
    ;; Scheme objects. Will block if a GC is currently in progress (safe).
    (c-activate))

  ;; ========== GC-safe subprocess/file I/O ==========
  ;;
  ;; These functions deactivate the Chez thread during the blocking C call
  ;; (popen+fread, fopen+fread, fopen+fwrite) and reactivate before returning.
  ;; The Chez FFI converts the C string return to a Scheme string AFTER
  ;; reactivation, so heap allocation is safe.

  (define c-capture-command
    (foreign-procedure "repl_capture_command" (string) string))
  (define c-read-file
    (foreign-procedure "repl_read_file" (string) string))
  (define c-write-file
    (foreign-procedure "repl_write_file" (string string size_t) int))

  (define (repl-capture-command cmd)
    ;; Run a shell command in a GC-safe way.  The thread is deactivated
    ;; during the blocking popen/fread so GC can proceed.
    ;; Returns the command's stdout as a string (empty string on error).
    (c-capture-command cmd))

  (define (repl-read-file path)
    ;; Read a file in a GC-safe way.  Returns content string (empty on error).
    (c-read-file path))

  (define (repl-write-file path content)
    ;; Write content to a file in a GC-safe way.  Returns #t/#f.
    (= 0 (c-write-file path content (string-length content))))

) ;; end library
