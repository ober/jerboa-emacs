#!chezscheme
;;; ipc.sls — IPC server for emacsclient-like remote file opening
;;;
;;; Ported from gerbil-emacs/ipc.ss
;;; UPGRADE: Uses STM (TVars) instead of mutex-protected queue — deadlock-free.
;;; UPGRADE: Uses jerboa (std net tcp) instead of Gambit open-tcp-server.

(library (jerboa-emacs ipc)
  (export start-ipc-server! ipc-poll-files! stop-ipc-server! *ipc-server-file*)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1-)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std concur stm)
          (std net tcp)
          (std srfi srfi-13))

  ;;; ========================================================================
  ;;; State
  ;;; ========================================================================

  (def *ipc-server-file*
    (string-append (or (getenv "HOME") ".") "/.jemacs-server"))

  ;; STM-protected queue of file paths received from clients
  (def *ipc-queue* (make-tvar '()))

  ;; The server (for shutdown)
  (def *ipc-server* #f)

  ;;; ========================================================================
  ;;; Queue operations (STM — deadlock-free)
  ;;; ========================================================================

  (def (ipc-queue-push! path)
    (atomically
      (lambda ()
        (let ((q (tvar-get *ipc-queue*)))
          (tvar-set! *ipc-queue* (append q (list path)))))))

  (def (ipc-poll-files!)
    (atomically
      (lambda ()
        (let ((files (tvar-get *ipc-queue*)))
          (tvar-set! *ipc-queue* '())
          files))))

  ;;; ========================================================================
  ;;; Server
  ;;; ========================================================================

  (def (ipc-handle-client! in out)
    (with-catch
      (lambda (e) (void))
      (lambda ()
        (let loop ()
          (let ((line (get-line in)))
            (unless (eof-object? line)
              (let ((path (string-trim-both line)))
                (when (> (string-length path) 0)
                  (ipc-queue-push! path)
                  (put-string out "OK\n")
                  (flush-output-port out)))
              (loop))))
        (close-port in)
        (close-port out))))

  (def (start-ipc-server!)
    (let* ((port-num (let ((env (getenv "JEMACS_PORT")))
                       (if env (or (string->number env) 0) 0)))
           (srv (tcp-listen "127.0.0.1" port-num))
           (actual-port (tcp-server-port srv)))
      (set! *ipc-server* srv)
      ;; Write server file
      (call-with-output-file *ipc-server-file*
        (lambda (p)
          (put-string p "127.0.0.1:")
          (put-string p (number->string actual-port))
          (newline p)))
      ;; Accept loop in background thread
      (fork-thread
        (lambda ()
          (let loop ()
            (let-values (((in out)
                          (with-catch
                            (lambda (e) (values #f #f))
                            (lambda () (tcp-accept srv)))))
              (when (and in out)
                (fork-thread
                  (lambda () (ipc-handle-client! in out)))
                (loop))))))
      (void)))

  (def (stop-ipc-server!)
    (when *ipc-server*
      (with-catch (lambda (e) (void)) (lambda () (tcp-close *ipc-server*)))
      (set! *ipc-server* #f))
    (when (file-exists? *ipc-server-file*)
      (delete-file *ipc-server-file*)))

  ) ;; end library
