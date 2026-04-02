#!chezscheme
;;; pty.sls — PTY (pseudo-terminal) subprocess support
;;;
;;; Ported from gerbil-emacs/pty.ss
;;; UPGRADE: Uses C shim .so + foreign-procedure instead of begin-ffi/c-lambda.

(library (jerboa-emacs pty)
  (export pty-spawn
          pty-openpty
          pty-read
          pty-last-errno
          pty-write
          pty-close!
          pty-kill!
          pty-resize!
          pty-waitpid
          pty-child-alive?)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1-
            getenv path-extension path-absolute? thread?
            make-mutex mutex? mutex-name)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std string))

  ;;; ========================================================================
  ;;; Load the C shim shared library
  ;;; ========================================================================

  (define static-build?
    (let ((v (getenv "JEMACS_STATIC")))
      (and v (not (string=? v "")) (not (string=? v "0")))))

  (define pty-shim-loaded
    (if static-build?
        #f  ; symbols already linked in via Sforeign_symbol registration
        (load-shared-object
          (let ((dir (or (getenv "JERBOA_EMACS_SUPPORT")
                         (string-append (or (getenv "HOME") ".") "/mine/jerboa-emacs/support"))))
            (string-append dir "/pty_shim.so")))))

  ;;; ========================================================================
  ;;; FFI bindings
  ;;; ========================================================================

  (define ffi-pty-spawn
    (foreign-procedure "pty_spawn" (string string int int) int))
  (define ffi-pty-get-master-fd
    (foreign-procedure "pty_get_master_fd" () int))
  (define ffi-pty-get-child-pid
    (foreign-procedure "pty_get_child_pid" () int))
  (define ffi-pty-read
    (foreign-procedure "pty_read" (int u8* int) int))
  (define ffi-pty-write
    (foreign-procedure "pty_write" (int string int) int))
  (define ffi-pty-close
    (foreign-procedure "pty_close" (int) void))
  (define ffi-pty-kill
    (foreign-procedure "pty_kill" (int int) int))
  (define ffi-pty-resize
    (foreign-procedure "pty_resize" (int int int) int))
  (define ffi-pty-waitpid
    (foreign-procedure "pty_waitpid" (int int) int))
  (define ffi-pty-waitpid-status
    (foreign-procedure "pty_get_wait_status" () int))
  (define ffi-pty-last-errno
    (foreign-procedure "pty_last_errno" () int))
  (define ffi-pty-openpty
    (foreign-procedure "pty_openpty" (int int) int))
  (define ffi-pty-get-open-slave-fd
    (foreign-procedure "pty_get_open_slave_fd" () int))

  ;;; ========================================================================
  ;;; Scheme-level API
  ;;; ========================================================================

  (def (pty-openpty rows cols)
    "Create a PTY pair without spawning a child process.
     Returns (values master-fd slave-fd) on success, (values #f #f) on failure."
    (let ((master-fd (ffi-pty-openpty rows cols)))
      (if (>= master-fd 0)
        (values master-fd (ffi-pty-get-open-slave-fd))
        (values #f #f))))

  (def (pty-spawn cmd env-alist rows cols)
    (let* ((env-str (env-alist->string env-alist))
           (result (ffi-pty-spawn cmd env-str rows cols)))
      (if (> result 0)
        (values (ffi-pty-get-master-fd) result)
        (values #f #f))))

  (def (pty-read master-fd)
    "Read from PTY master fd.
     Returns: string (data), #f (EAGAIN/retry), 'eof (true EOF), or 'error (fatal)."
    (let* ((buf (make-bytevector 4096 0))
           (n (ffi-pty-read master-fd buf 4095)))
      (cond
        ((> n 0)
         (let ((sub (make-bytevector n)))
           (bytevector-copy! buf 0 sub 0 n)
           (utf8->string sub)))
        ((= n 0) #f)       ; EAGAIN/EIO/ENXIO — retry
        ((= n -1) 'eof)    ; true EOF (read returned 0)
        (else 'error))))   ; fatal error — check pty-last-errno

  (def (pty-last-errno)
    "Return the errno from the last pty_read call."
    (ffi-pty-last-errno))

  (def (pty-write master-fd str)
    (ffi-pty-write master-fd str (string-length str)))

  (def (pty-close! master-fd child-pid)
    (ffi-pty-close master-fd)
    (when (and child-pid (> child-pid 0))
      (with-catch (lambda (e) (void))
        (lambda ()
          (ffi-pty-kill child-pid 15)
          (ffi-pty-waitpid child-pid 1)))))

  (def (pty-kill! child-pid signal)
    (when (and child-pid (> child-pid 0))
      (ffi-pty-kill child-pid signal)))

  (def (pty-resize! master-fd rows cols)
    (when (and master-fd (>= master-fd 0))
      (ffi-pty-resize master-fd rows cols)))

  (def (pty-waitpid child-pid nohang?)
    (let ((result (ffi-pty-waitpid child-pid (if nohang? 1 0))))
      (cond
        ((> result 0) (values (ffi-pty-waitpid-status) #t))
        ((= result 0) (values 0 #f))
        (else (values -1 #t)))))

  (def (pty-child-alive? child-pid)
    (let-values (((status exited?) (pty-waitpid child-pid #t)))
      (not exited?)))

  ;;; ========================================================================
  ;;; Helpers
  ;;; ========================================================================

  (def (env-alist->string alist)
    (if (or (not alist) (null? alist))
      ""
      (let loop ((entries alist) (acc '()))
        (if (null? entries)
          (string-join (reverse acc) "\n")
          (let ((e (car entries)))
            (loop (cdr entries)
                  (cons (if (pair? e)
                          (string-append (car e) "=" (cdr e))
                          e)
                        acc)))))))

  ) ;; end library
