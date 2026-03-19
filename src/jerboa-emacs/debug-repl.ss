;;; -*- Gerbil -*-
;;; TCP REPL server for debugging a running jerboa-emacs instance.
;;; Connect with: nc 127.0.0.1 <port>
;;;
;;; DEDICATED THREAD DESIGN: The REPL runs in its own background thread,
;;; independent of the Qt event loop and master timer. This means the REPL
;;; stays responsive even when the UI is hung or the master timer is blocked.
;;;
;;; GC safety: Uses non-blocking sockets + thread-sleep! between polls.
;;; thread-sleep! auto-deactivates the Chez thread (decrements active_threads),
;;; allowing stop-the-world GC to proceed without waiting for this thread.
;;; No foreign call ever blocks — accept/read return immediately (EAGAIN).
;;;
;;; API:
;;;   (start-debug-repl! port)          → actual-port
;;;   (start-debug-repl! port token)    → actual-port  (optional auth token)
;;;   (stop-debug-repl!)                → void
;;;   (debug-repl-port)                 → port-number or #f

(export start-debug-repl!
        stop-debug-repl!
        debug-repl-port)

(import :std/sugar
        :std/srfi/13
        :jerboa/repl-socket)

;;;============================================================================
;;; State
;;;============================================================================

(def *repl-listen-fd* #f)       ;; listen socket fd (non-blocking)
(def *repl-actual-port* #f)     ;; port number we're listening on
(def *repl-running* #f)         ;; #t while REPL thread should keep running
(def *repl-thread* #f)          ;; the background thread handle
(def *repl-port-file*
  (string-append (getenv "HOME") "/.jerboa-repl-port"))

;;;============================================================================
;;; Port file
;;;============================================================================

(def (write-repl-port-file! port-num)
  (delete-repl-port-file!)
  (call-with-output-file *repl-port-file*
    (lambda (p)
      (display "PORT=" p)
      (display port-num p)
      (newline p))))

(def (delete-repl-port-file!)
  (when (file-exists? *repl-port-file*)
    (with-catch (lambda _ (void))
      (lambda () (delete-file *repl-port-file*)))))

;;;============================================================================
;;; Help text
;;;============================================================================

(def help-text
  "  ,help           This help message
  ,threads        List active threads
  ,state          Show state summary
  ,gc             Force GC and show heap info
  ,quit           Close this REPL connection
  <expr>          Evaluate arbitrary Chez Scheme expression
")

;;;============================================================================
;;; Command processing (runs in REPL thread)
;;;============================================================================

(def (process-repl-line line client-fd)
  "Process one REPL command line. Returns #t to continue, #f to disconnect."
  (let ((cmd (string-trim-both line)))
    (cond
      ((string=? cmd "")
       #t)
      ((string=? cmd ",quit")
       (repl-fd-send! client-fd "Connection closed.\n")
       #f)
      ((string=? cmd ",help")
       (repl-fd-send! client-fd help-text)
       #t)
      ((string=? cmd ",threads")
       (with-catch
         (lambda (e) (repl-fd-send! client-fd "  (error listing threads)\n"))
         (lambda ()
           (repl-fd-send! client-fd "  REPL thread (active)\n")))
       #t)
      ((string=? cmd ",state")
       (repl-fd-send! client-fd
         (string-append
           "  listen-fd: " (number->string (or *repl-listen-fd* -1))
           "\n  client-fd: " (number->string client-fd)
           "\n  bytes-allocated: " (number->string (bytes-allocated))
           "\n"))
       #t)
      ((string=? cmd ",gc")
       ;; (collect) requires all threads at rendezvous — can't safely call
       ;; from a background thread. Just report stats instead.
       (with-catch
         (lambda (e)
           (repl-fd-send! client-fd "  (error reading GC stats)\n"))
         (lambda ()
           (repl-fd-send! client-fd
             (string-append
               "  bytes-allocated: " (number->string (bytes-allocated))
               "\n  collections: " (number->string (collections))
               "\n  Note: (collect) not safe from REPL thread; GC runs automatically.\n"))))
       #t)
      (else
       ;; Evaluate as Chez Scheme expression
       (with-catch
         (lambda (e)
           (let ((msg (with-catch (lambda (e2) "unknown error")
                        (lambda ()
                          (with-output-to-string
                            (lambda ()
                              (display-condition e (current-output-port))))))))
             (repl-fd-send! client-fd (string-append "ERROR: " msg "\n"))))
         (lambda ()
           (let* ((result (eval (read (open-input-string cmd))
                                (interaction-environment)))
                  (out (open-output-string)))
             (write result out)
             (repl-fd-send! client-fd (string-append (get-output-string out) "\n")))))
       #t))))

;;;============================================================================
;;; I/O helpers
;;;============================================================================

(def (repl-fd-send! fd str)
  "Send string to fd. Returns #t on success, #f on error."
  (repl-socket-write fd str))

(def (repl-string-index str ch)
  "Return the index of the first occurrence of ch in str, or #f."
  (let ((len (string-length str)))
    (let loop ((i 0))
      (cond
        ((>= i len) #f)
        ((char=? (string-ref str i) ch) i)
        (else (loop (+ i 1)))))))

;;;============================================================================
;;; Client handler (runs in REPL thread)
;;;============================================================================

(def (handle-client! client-fd token)
  "Handle one client connection. Blocks until client disconnects or ,quit.
   Uses non-blocking reads + thread-sleep! for GC safety."
  (with-catch
    (lambda (e) (void))  ;; silently close on any error
    (lambda ()
      ;; Auth phase
      (let ((authed (if token
                      (begin
                        (repl-fd-send! client-fd "token: ")
                        (let-values (((tok-line rest) (repl-read-line client-fd "")))
                          (and tok-line
                               (string=? (string-trim-both tok-line) token))))
                      #t)))
        (when authed
          (repl-fd-send! client-fd "jerboa debug REPL — type ,help for commands\n")
          ;; Main REPL loop — carry leftover buffer between reads
          (let loop ((buf ""))
            (when *repl-running*
              (repl-fd-send! client-fd "jerboa-dbg> ")
              (let-values (((line rest) (repl-read-line client-fd buf)))
                (when (and line *repl-running*)
                  (when (process-repl-line line client-fd)
                    (loop rest))))))))))
  ;; Always close the client fd
  (with-catch (lambda _ (void))
    (lambda () (repl-socket-close client-fd))))

(def (repl-read-line client-fd buf)
  "Read one line from client-fd using non-blocking reads + thread-sleep!.
   Returns (values line remaining-buffer) or (values #f \"\") on EOF/disconnect.
   Carries over leftover data in buf from previous reads."
  (let loop ((buf buf))
    (if (not *repl-running*)
      (values #f "")
      (let ((nl (repl-string-index buf #\newline)))
        (if nl
          ;; Got a complete line — return it and the remaining buffer
          (let ((line (substring buf 0 nl))
                (rest (substring buf (+ nl 1) (string-length buf))))
            ;; Strip trailing CR
            (values
              (if (and (> (string-length line) 0)
                       (char=? (string-ref line (- (string-length line) 1)) #\return))
                (substring line 0 (- (string-length line) 1))
                line)
              rest))
          ;; Need more data — non-blocking read
          (let ((data (repl-socket-read client-fd)))
            (cond
              ((string? data)
               (loop (string-append buf data)))
              ((eq? data 'eof)
               (values #f ""))
              (else
               ;; EAGAIN — sleep briefly then retry
               ;; thread-sleep! auto-deactivates for GC
               (thread-sleep! 0.05)
               (loop buf)))))))))

;;;============================================================================
;;; Accept loop (runs in REPL thread)
;;;============================================================================

(def (repl-accept-loop! token)
  "Main accept loop. Runs in the dedicated REPL thread.
   Accepts one client at a time (single-connection REPL)."
  (let loop ()
    (when *repl-running*
      (let ((cfd (with-catch (lambda _ #f)
                   (lambda () (repl-socket-accept *repl-listen-fd*)))))
        (if cfd
          (begin
            (handle-client! cfd token)
            (loop))
          (begin
            ;; No connection pending — sleep briefly then retry
            ;; thread-sleep! auto-deactivates for GC
            (thread-sleep! 0.1)
            (loop)))))))

;;;============================================================================
;;; Public API
;;;============================================================================

(def (start-debug-repl! port-num . args)
  "Start the TCP debug REPL on 127.0.0.1:port-num.
   Optional second argument: token string for authentication.
   Use port 0 for OS-assigned ephemeral port.
   Returns the actual port number and writes ~/.jerboa-repl-port.

   Runs in a dedicated background thread — independent of Qt event loop."
  ;; Stop any existing server
  (stop-debug-repl!)
  (let ((token (if (null? args) #f (car args))))
    (let-values (((fd actual-port) (repl-socket-listen "127.0.0.1" port-num)))
      (set! *repl-listen-fd* fd)
      (set! *repl-actual-port* actual-port)
      (set! *repl-running* #t)
      (write-repl-port-file! actual-port)
      ;; Spawn dedicated REPL thread
      (set! *repl-thread*
        (let ((t (make-thread
                   (lambda ()
                     (with-catch
                       (lambda (e) (void))
                       (lambda () (repl-accept-loop! token))))
                   'debug-repl)))
          (thread-start! t)
          t))
      actual-port)))

(def (stop-debug-repl!)
  "Stop the debug REPL server and clean up."
  ;; Signal thread to stop
  (set! *repl-running* #f)
  ;; Close listen socket (will cause accept to fail, unblocking the thread)
  (when *repl-listen-fd*
    (with-catch (lambda _ (void))
      (lambda () (repl-socket-close *repl-listen-fd*)))
    (set! *repl-listen-fd* #f)
    (set! *repl-actual-port* #f))
  ;; Wait briefly for thread to notice
  (when *repl-thread*
    (with-catch (lambda _ (void))
      (lambda () (thread-sleep! 0.2)))
    (set! *repl-thread* #f))
  (delete-repl-port-file!))

(def (debug-repl-port)
  "Return the actual port number the debug REPL is listening on, or #f if stopped."
  *repl-actual-port*)
