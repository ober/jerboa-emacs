#!chezscheme
;;; debug-repl.sls — TCP REPL server for debugging a running jemacs instance.
;;;
;;; Ported from gerbil-emacs/debug-repl.ss
;;; Connect with: nc 127.0.0.1 <port>
;;; Simplified: no Gambit-specific thread introspection (##thread-state,
;;; ##display-continuation-backtrace, etc.)

(library (jerboa-emacs debug-repl)
  (export start-debug-repl! stop-debug-repl! debug-repl-port)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!
            make-mutex mutex? mutex-name thread?
            getenv path-extension path-absolute?)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std srfi srfi-13)
          (std net tcp)
          (jerboa-emacs core))

  ;;;============================================================================
  ;;; State
  ;;;============================================================================

  (def *debug-repl-server* #f)
  (def *debug-repl-actual-port* #f)
  (def *debug-repl-port-file*
    (string-append (or (getenv "HOME") ".") "/.jemacs-repl-port"))

  ;;;============================================================================
  ;;; Port file
  ;;;============================================================================

  (def (write-repl-port-file! port-num)
    (call-with-output-file *debug-repl-port-file*
      (lambda (p)
        (put-string p "PORT=") (display port-num p) (newline p)
        (put-string p "PID=") (display (get-process-id) p) (newline p))))

  (def (delete-repl-port-file!)
    (when (file-exists? *debug-repl-port-file*)
      (with-catch void
        (lambda () (delete-file *debug-repl-port-file*)))))

  ;;;============================================================================
  ;;; Comma command helpers
  ;;;============================================================================

  (def (cmd-list-buffers port)
    (for-each
      (lambda (buf)
        (let ((name (buffer-name buf))
              (path (buffer-file-path buf))
              (mod (buffer-modified buf)))
          (put-string port
            (string-append
              "  " name
              (if mod " [modified]" "")
              (if path (string-append "  " path) "  (no file)")
              "\n"))))
      (buffer-list)))

  (def (cmd-show-state port)
    (let ((bufs (buffer-list)))
      (put-string port
        (string-append
          "  buffers:   " (number->string (length bufs)) " buffer(s)\n"
          "  kill-ring: (not accessible without app)\n"))))

  (def (cmd-force-gc port)
    (collect (collect-maximum-generation))
    (put-string port "  GC done.\n"))

  (def help-text
    "  ,help           This help message
  ,buffers        List all open buffers
  ,state          Show key state summary
  ,gc             Force GC
  ,quit           Close this REPL connection
  <expr>          Evaluate arbitrary Scheme expression
")

  ;;;============================================================================
  ;;; Client handler
  ;;;============================================================================

  (def (debug-repl-handle-client! in out token)
    ;; Token auth
    (when token
      (let ((line (with-catch (lambda (e) #f) (lambda () (get-line in)))))
        (unless (and (string? line) (string=? (string-trim-both line) token))
          (put-string out "Access denied.\n")
          (flush-output-port out)
          (close-port in)
          (close-port out)
          (error 'debug-repl "access denied"))))
    ;; Banner
    (put-string out "jemacs debug REPL — type ,help for commands\n")
    (flush-output-port out)
    (let loop ()
      (put-string out "jemacs-dbg> ")
      (flush-output-port out)
      (let ((line (with-catch (lambda (e) #f) (lambda () (get-line in)))))
        (when (and line (not (eof-object? line)))
          (let ((cmd (string-trim-both line)))
            (cond
              ((string=? cmd "") (loop))
              ((string=? cmd ",quit")
               (put-string out "Connection closed.\n")
               (flush-output-port out))
              ((string=? cmd ",help")
               (put-string out help-text)
               (flush-output-port out)
               (loop))
              ((string=? cmd ",buffers")
               (cmd-list-buffers out)
               (flush-output-port out)
               (loop))
              ((string=? cmd ",state")
               (cmd-show-state out)
               (flush-output-port out)
               (loop))
              ((string=? cmd ",gc")
               (cmd-force-gc out)
               (flush-output-port out)
               (loop))
              (else
               ;; Evaluate as Scheme expression
               (with-catch
                 (lambda (e)
                   (put-string out "ERROR: ")
                   (put-string out (format "~a" e))
                   (newline out))
                 (lambda ()
                   (let ((result (eval (read (open-input-string cmd)))))
                     (write result out)
                     (newline out))))
               (flush-output-port out)
               (loop))))))))

  ;;;============================================================================
  ;;; Public API
  ;;;============================================================================

  (def (start-debug-repl! port-num . rest)
    (let ((token (if (pair? rest) (car rest) #f)))
      (let* ((srv (tcp-listen "127.0.0.1" port-num))
             (actual-port (tcp-server-port srv)))
        (set! *debug-repl-server* srv)
        (write-repl-port-file! actual-port)
        (set! *debug-repl-actual-port* actual-port)
        (fork-thread
          (lambda ()
            (let loop ()
              (let-values (((in out)
                            (with-catch
                              (lambda (e) (values #f #f))
                              (lambda () (tcp-accept srv)))))
                (when (and in out)
                  (fork-thread
                    (lambda ()
                      (with-catch
                        (lambda (e) (void))
                        (lambda ()
                          (debug-repl-handle-client! in out token)
                          (with-catch void (lambda () (close-port in)))
                          (with-catch void (lambda () (close-port out)))))))
                  (loop))))))
        actual-port)))

  (def (stop-debug-repl!)
    (when *debug-repl-server*
      (with-catch void (lambda () (tcp-close *debug-repl-server*)))
      (set! *debug-repl-server* #f)
      (set! *debug-repl-actual-port* #f))
    (delete-repl-port-file!))

  (def (debug-repl-port)
    *debug-repl-actual-port*)

  ) ;; end library
