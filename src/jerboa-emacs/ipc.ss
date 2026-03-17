;;; -*- Gerbil -*-
;;; IPC server for emacsclient-like remote file opening.
;;; Uses (std net tcp) for cross-platform TCP networking
;;; to bridge server threads to the UI thread.

(export start-ipc-server! ipc-poll-files! stop-ipc-server! *ipc-server-file*)

(import :std/sugar
        :std/net/tcp)

;;;============================================================================
;;; State
;;;============================================================================

(def *ipc-server-file*
  (path-expand ".jemacs-server" (getenv "HOME")))

;; Mutex-protected queue of file paths received from clients
(def *ipc-queue* '())
(def *ipc-mutex* (make-mutex 'ipc-queue))

;; The server (for shutdown)
(def *ipc-server-port* #f)

;;;============================================================================
;;; Queue operations (thread-safe)
;;;============================================================================

(def (ipc-queue-push! path)
  "Push a file path onto the IPC queue (called from server threads)."
  (mutex-lock! *ipc-mutex*)
  (unwind-protect
    (set! *ipc-queue* (append *ipc-queue* (list path)))
    (mutex-unlock! *ipc-mutex*)))

(def (ipc-poll-files!)
  "Drain the IPC queue and return a list of file paths.
   Called from the UI thread."
  (mutex-lock! *ipc-mutex*)
  (unwind-protect
    (let ((files *ipc-queue*))
      (set! *ipc-queue* '())
      files)
    (mutex-unlock! *ipc-mutex*)))

;;;============================================================================
;;; Server
;;;============================================================================

(def (ipc-handle-client! in-port out-port)
  "Handle one client connection: read newline-terminated file paths,
   push them to the queue, respond with OK for each."
  (with-catch
    (lambda (e) (void))  ;; ignore errors from disconnected clients
    (lambda ()
      (let loop ()
        (let ((line (read-line in-port)))
          (unless (eof-object? line)
            (let ((path (string-trim-ipc line)))
              (when (> (string-length path) 0)
                (ipc-queue-push! path)
                (display "OK\n" out-port)
                (force-output out-port)))
            (loop))))
      (close-port in-port)
      (close-port out-port))))

(def (string-trim-ipc s)
  "Remove leading/trailing whitespace and carriage returns."
  (let* ((len (string-length s))
         (start (let loop ((i 0))
                  (if (and (< i len)
                           (let ((c (string-ref s i)))
                             (or (char=? c #\space)
                                 (char=? c #\return)
                                 (char=? c #\tab))))
                    (loop (+ i 1))
                    i)))
         (end (let loop ((i len))
                (if (and (> i start)
                         (let ((c (string-ref s (- i 1))))
                           (or (char=? c #\space)
                               (char=? c #\return)
                               (char=? c #\tab))))
                  (loop (- i 1))
                  i))))
    (substring s start end)))

(def (start-ipc-server!)
  "Start the IPC server on 127.0.0.1 with an OS-assigned port.
   Writes the host:port to *ipc-server-file*."
  (let* ((port-num (let ((env (getenv "GERBIL_EMACS_PORT" #f)))
                     (if env (string->number env) 0)))
         (srv (tcp-listen "127.0.0.1" port-num))
         (actual-port (tcp-server-port srv)))
    (set! *ipc-server-port* srv)
    ;; Write server file
    (call-with-output-file *ipc-server-file*
      (lambda (p)
        (display "127.0.0.1:" p)
        (display actual-port p)
        (newline p)))
    ;; Accept loop in background thread
    (thread-start!
      (make-thread
        (lambda ()
          (let loop ()
            (let ((client (with-catch
                            (lambda (e) #f)
                            (lambda ()
                              (call-with-values
                                (lambda () (tcp-accept srv))
                                list)))))
              (when (and client (pair? client))
                (let ((in (car client)) (out (cadr client)))
                  (thread-start!
                    (make-thread
                      (lambda () (ipc-handle-client! in out))))
                  (loop))))))
        'ipc-accept-loop))
    (void)))

(def (stop-ipc-server!)
  "Stop the IPC server and remove the server file."
  (when *ipc-server-port*
    (with-catch void (lambda () (tcp-close *ipc-server-port*)))
    (set! *ipc-server-port* #f))
  (when (file-exists? *ipc-server-file*)
    (delete-file *ipc-server-file*)))
