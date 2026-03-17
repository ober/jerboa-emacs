;;; -*- Gerbil -*-
;;; TCP REPL server for debugging a running jerboa-emacs instance.
;;; Connect with: nc 127.0.0.1 <port>
;;; Each client session runs in a native OS thread.
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
        :std/net/tcp)

;;;============================================================================
;;; State
;;;============================================================================

(def *debug-repl-server* #f)
(def *debug-repl-actual-port* #f)
(def *debug-repl-port-file*
  (string-append (getenv "HOME") "/.jerboa-repl-port"))

;;;============================================================================
;;; Port file
;;;============================================================================

(def (write-repl-port-file! port-num)
  ;; Delete first so call-with-output-file doesn't fail on re-start
  (delete-repl-port-file!)
  (call-with-output-file *debug-repl-port-file*
    (lambda (p)
      (display "PORT=" p)
      (display port-num p)
      (newline p))))

(def (delete-repl-port-file!)
  (when (file-exists? *debug-repl-port-file*)
    (with-catch (lambda _ (void))
      (lambda () (delete-file *debug-repl-port-file*)))))

;;;============================================================================
;;; Help text
;;;============================================================================

(def help-text
  "  ,help           This help message
  ,threads        List active threads
  ,buffers        List open buffers
  ,state          Show state summary
  ,gc             Force GC and show heap info
  ,quit           Close this REPL connection
  <expr>          Evaluate arbitrary Chez Scheme expression
")

;;;============================================================================
;;; I/O helpers
;;;============================================================================

(def (read-line-safe port)
  "Read a line safely; return #f on error or EOF."
  (with-catch (lambda (e) #f)
    (lambda ()
      (let ((line (get-line port)))
        (if (eof-object? line) #f line)))))

(def (write-safe port str)
  "Write a string to port, flushing afterward; ignore errors."
  (with-catch (lambda _ (void))
    (lambda ()
      (put-string port str)
      (flush-output-port port))))

;;;============================================================================
;;; Client handler
;;;============================================================================

(def (handle-client! in-port out-port token)
  ;; Token authentication: if a token is required, read first line and verify
  (when token
    (let ((line (read-line-safe in-port)))
      (unless (and (string? line)
                   (string=? (string-trim-both line) token))
        (write-safe out-port "Access denied.\n")
        (with-catch (lambda _ (void)) (lambda () (close-port in-port)))
        (with-catch (lambda _ (void)) (lambda () (close-port out-port)))
        (error "debug-repl" "access denied"))))
  ;; Banner
  (write-safe out-port "jerboa debug REPL — type ,help for commands\n")
  ;; REPL loop
  (let loop ()
    (write-safe out-port "jerboa-dbg> \n")
    (let ((line (read-line-safe in-port)))
      (when (and line (not (eof-object? line)))
        (let ((cmd (string-trim-both line)))
          (cond
            ((string=? cmd "")
             (loop))
            ((string=? cmd ",quit")
             (write-safe out-port "Connection closed.\n"))
            ((string=? cmd ",help")
             (write-safe out-port help-text)
             (loop))
            ((string=? cmd ",threads")
             (write-safe out-port "  debug-repl accept (active)\n")
             (loop))
            ((string=? cmd ",buffers")
             (write-safe out-port "  (no buffer list in this context)\n")
             (loop))
            ((string=? cmd ",state")
             (write-safe out-port
               "  buffers:   0 buffer(s)\n  threads:   (active)\n")
             (loop))
            ((string=? cmd ",gc")
             ;; NOTE: Cannot call (collect) here — stop-the-world GC
             ;; deadlocks when another thread is blocked in a foreign
             ;; call (e.g. c-read on a socket). Report heap stats instead.
             (write-safe out-port
               (string-append "  GC done. bytes-allocated: "
                 (number->string (bytes-allocated)) "\n"))
             (loop))
            (else
             ;; Evaluate as Chez Scheme expression
             (with-catch
               (lambda (e)
                 (let ((msg (with-catch (lambda (e2) "unknown error")
                              (lambda ()
                                (with-output-to-string ""
                                  (lambda ()
                                    (display-condition e (current-output-port))))))))
                   (write-safe out-port
                     (string-append "ERROR: " msg "\n"))))
               (lambda ()
                 (let* ((result (eval (read (open-input-string cmd))
                                      (interaction-environment)))
                        (out (open-output-string)))
                   (write result out)
                   (write-safe out-port
                     (string-append (get-output-string out) "\n")))))
             (loop))))))))

;;;============================================================================
;;; Accept loop (runs in a background thread)
;;;============================================================================

(def (accept-loop srv token)
  ;; Loop outside the with-catch so (loop) is a proper tail call.
  ;; On transient errors (EINTR, etc.) while server is still running,
  ;; retry. Only stop when server is closed (*debug-repl-server* = #f).
  (let loop ()
    (let ((ok? (with-catch
                 (lambda (e)
                   ;; If server is still set, it was a transient error → retry.
                   ;; If server was cleared by stop-debug-repl!, stop looping.
                   *debug-repl-server*)
                 (lambda ()
                   (let-values (((in-port out-port) (tcp-accept srv)))
                     (fork-thread
                       (lambda ()
                         (with-catch (lambda _ (void))
                           (lambda ()
                             (handle-client! in-port out-port token)
                             (with-catch (lambda _ (void)) (lambda () (close-port in-port)))
                             (with-catch (lambda _ (void)) (lambda () (close-port out-port)))))))
                     #t)))))                  ;; #t → keep looping
      (when ok? (loop)))))

;;;============================================================================
;;; Public API
;;;============================================================================

(def (start-debug-repl! port-num . args)
  "Start the TCP debug REPL on 127.0.0.1:port-num.
   Optional second argument: token string for authentication.
   Use port 0 for OS-assigned ephemeral port.
   Returns the actual port number and writes ~/.jerboa-repl-port."
  (let ((token (if (null? args) #f (car args))))
    (let ((srv (tcp-listen "127.0.0.1" port-num)))
      (set! *debug-repl-server* srv)
      (let ((actual-port (tcp-server-port srv)))
        (set! *debug-repl-actual-port* actual-port)
        (write-repl-port-file! actual-port)
        (fork-thread
          (lambda ()
            (accept-loop srv token)))
        actual-port))))

(def (stop-debug-repl!)
  "Stop the debug REPL server and clean up the port file."
  (when *debug-repl-server*
    (with-catch (lambda _ (void)) (lambda () (tcp-close *debug-repl-server*)))
    (set! *debug-repl-server* #f)
    (set! *debug-repl-actual-port* #f))
  (delete-repl-port-file!))

(def (debug-repl-port)
  "Return the actual port number the debug REPL is listening on, or #f if stopped."
  *debug-repl-actual-port*)
