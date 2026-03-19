;;; -*- Gerbil -*-
;;; TCP REPL server for debugging a running jerboa-emacs instance.
;;; Connect with: nc 127.0.0.1 <port>
;;;
;;; THREAD-FREE DESIGN: No Chez threads are created. All socket I/O uses
;;; non-blocking FFI calls polled from the master timer (schedule-periodic!).
;;; This prevents GC deadlocks caused by Chez threads blocking in foreign
;;; calls (accept/read) that can't respond to stop-the-world GC signals.
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
        :jerboa/repl-socket
        :jerboa-emacs/async)

;;;============================================================================
;;; State
;;;============================================================================

(def *repl-listen-fd* #f)       ;; listen socket fd (non-blocking)
(def *repl-client-fd* #f)       ;; connected client fd (non-blocking), or #f
(def *repl-line-buf*  "")       ;; partial line accumulator
(def *repl-actual-port* #f)     ;; port number we're listening on
(def *repl-token* #f)           ;; auth token (or #f for no auth)
(def *repl-authed* #f)          ;; #t after successful auth (or if no token)
(def *repl-prompted* #f)        ;; #t if we've sent the prompt for current line
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
;;; Low-level I/O helpers
;;;============================================================================

(def (repl-send! str)
  "Send a string to the connected client.  No-op if no client."
  (when *repl-client-fd*
    (unless (repl-socket-write *repl-client-fd* str)
      ;; Write failed — client disconnected
      (repl-disconnect!))))

(def (repl-disconnect!)
  "Close the client connection and reset state for next accept."
  (when *repl-client-fd*
    (with-catch (lambda _ (void))
      (lambda () (repl-socket-close *repl-client-fd*))))
  (set! *repl-client-fd* #f)
  (set! *repl-line-buf* "")
  (set! *repl-authed* #f)
  (set! *repl-prompted* #f))

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
;;; Command processing
;;;============================================================================

(def (process-repl-line! line)
  "Process one REPL command line.  Returns #t to continue, #f to disconnect."
  (let ((cmd (string-trim-both line)))
    (cond
      ((string=? cmd "")
       #t)
      ((string=? cmd ",quit")
       (repl-send! "Connection closed.\n")
       #f)
      ((string=? cmd ",help")
       (repl-send! help-text)
       #t)
      ((string=? cmd ",threads")
       (with-catch
         (lambda (e) (repl-send! "  (error listing threads)\n"))
         (lambda ()
           (repl-send! "  master-timer (active)\n")))
       #t)
      ((string=? cmd ",state")
       (repl-send!
         (string-append
           "  listen-fd: " (number->string (or *repl-listen-fd* -1))
           "\n  client-fd: " (number->string (or *repl-client-fd* -1))
           "\n  bytes-allocated: " (number->string (bytes-allocated))
           "\n"))
       #t)
      ((string=? cmd ",gc")
       ;; Safe to call (collect) now — no REPL thread is blocked in a
       ;; foreign call (we run from the master timer, not a separate thread).
       ;; NOTE: Other threads (IPC accept) may still be blocked.
       ;; Use (collect 0) for a minor collection that's less likely to
       ;; need all threads at rendezvous.
       (with-catch
         (lambda (e)
           (repl-send!
             (string-append "  GC skipped (would deadlock). bytes-allocated: "
               (number->string (bytes-allocated)) "\n")))
         (lambda ()
           (collect 0)
           (repl-send!
             (string-append "  GC done (gen 0). bytes-allocated: "
               (number->string (bytes-allocated)) "\n"))))
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
             (repl-send! (string-append "ERROR: " msg "\n"))))
         (lambda ()
           (let* ((result (eval (read (open-input-string cmd))
                                (interaction-environment)))
                  (out (open-output-string)))
             (write result out)
             (repl-send! (string-append (get-output-string out) "\n")))))
       #t))))

;;;============================================================================
;;; Tick — called from master timer every 100ms
;;;============================================================================

(def (debug-repl-tick!)
  "Non-blocking REPL poll.  Called from the master timer.
   Tries to accept a connection or read data from an existing client."
  (when *repl-listen-fd*
    (with-catch
      (lambda (e) (void))  ;; swallow any unexpected errors in the tick
      (lambda ()
        (cond
          ;; No client — try to accept one
          ((not *repl-client-fd*)
           (let ((cfd (repl-socket-accept *repl-listen-fd*)))
             (when cfd
               (set! *repl-client-fd* cfd)
               (set! *repl-line-buf* "")
               (set! *repl-prompted* #f)
               ;; Check if token auth is needed
               (if *repl-token*
                 (begin
                   (set! *repl-authed* #f)
                   (repl-send! "token: "))
                 (begin
                   (set! *repl-authed* #t)
                   (repl-send! "jerboa debug REPL — type ,help for commands\n"))))))

          ;; Client connected — try to read data
          (*repl-client-fd*
           ;; Send prompt if needed
           (when (and *repl-authed* (not *repl-prompted*))
             (repl-send! "jerboa-dbg> \n")
             (set! *repl-prompted* #t))

           ;; Non-blocking read
           (let ((data (repl-socket-read *repl-client-fd*)))
             (cond
               ((string? data)
                ;; Got data — append to line buffer and process complete lines
                (set! *repl-line-buf* (string-append *repl-line-buf* data))
                (repl-process-lines!))
               ((eq? data 'eof)
                ;; Client disconnected
                (repl-disconnect!))
               ;; #f = EAGAIN, nothing to read — try again next tick
               ))))))))

(def (repl-process-lines!)
  "Extract and process complete lines from *repl-line-buf*."
  (let loop ()
    (let ((nl (repl-string-index *repl-line-buf* #\newline)))
      (when nl
        (let ((line (substring *repl-line-buf* 0 nl))
              (rest (substring *repl-line-buf* (+ nl 1)
                               (string-length *repl-line-buf*))))
          (set! *repl-line-buf* rest)
          ;; Strip trailing CR (from telnet/nc on some systems)
          (let ((line (if (and (> (string-length line) 0)
                               (char=? (string-ref line (- (string-length line) 1)) #\return))
                       (substring line 0 (- (string-length line) 1))
                       line)))
            (if *repl-authed*
              ;; Normal REPL command
              (let ((continue? (process-repl-line! line)))
                (if continue?
                  (begin
                    (set! *repl-prompted* #f)  ;; need new prompt
                    (loop))
                  (repl-disconnect!)))
              ;; Auth check
              (let ((tok (string-trim-both line)))
                (if (string=? tok *repl-token*)
                  (begin
                    (set! *repl-authed* #t)
                    (repl-send! "jerboa debug REPL — type ,help for commands\n")
                    (set! *repl-prompted* #f)
                    (loop))
                  (begin
                    (repl-send! "Access denied.\n")
                    (repl-disconnect!)))))))))))

(def (repl-string-index str ch)
  "Return the index of the first occurrence of ch in str, or #f."
  (let ((len (string-length str)))
    (let loop ((i 0))
      (cond
        ((>= i len) #f)
        ((char=? (string-ref str i) ch) i)
        (else (loop (+ i 1)))))))

;;;============================================================================
;;; Public API
;;;============================================================================

(def (start-debug-repl! port-num . args)
  "Start the TCP debug REPL on 127.0.0.1:port-num.
   Optional second argument: token string for authentication.
   Use port 0 for OS-assigned ephemeral port.
   Returns the actual port number and writes ~/.jerboa-repl-port.

   THREAD-FREE: Registers a periodic tick with the master timer instead
   of creating a background thread.  All socket I/O is non-blocking."
  ;; Stop any existing server
  (stop-debug-repl!)
  (let ((token (if (null? args) #f (car args))))
    (let-values (((fd actual-port) (repl-socket-listen "127.0.0.1" port-num)))
      (set! *repl-listen-fd* fd)
      (set! *repl-actual-port* actual-port)
      (set! *repl-token* token)
      (set! *repl-authed* (not token))
      (set! *repl-client-fd* #f)
      (set! *repl-line-buf* "")
      (set! *repl-prompted* #f)
      (write-repl-port-file! actual-port)
      ;; Register periodic tick — polls every 100ms from master timer
      (schedule-periodic! 'debug-repl 100 debug-repl-tick!)
      actual-port)))

(def (stop-debug-repl!)
  "Stop the debug REPL server and clean up."
  ;; Close client if connected
  (repl-disconnect!)
  ;; Close listen socket
  (when *repl-listen-fd*
    (with-catch (lambda _ (void))
      (lambda () (repl-socket-close *repl-listen-fd*)))
    (set! *repl-listen-fd* #f)
    (set! *repl-actual-port* #f))
  (delete-repl-port-file!))

(def (debug-repl-port)
  "Return the actual port number the debug REPL is listening on, or #f if stopped."
  *repl-actual-port*)
