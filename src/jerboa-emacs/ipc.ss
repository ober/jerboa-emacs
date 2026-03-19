;;; -*- Gerbil -*-
;;; IPC server for emacsclient-like remote file opening.
;;;
;;; THREAD-FREE DESIGN: Uses non-blocking sockets polled from the master
;;; timer (schedule-periodic!) to avoid GC deadlocks caused by Chez threads
;;; blocking in foreign calls (accept/read).

(export start-ipc-server! ipc-poll-files! stop-ipc-server! *ipc-server-file*)

(import :std/sugar
        :jerboa/repl-socket
        :jerboa-emacs/async)

;;;============================================================================
;;; State
;;;============================================================================

(def *ipc-server-file*
  (path-expand ".jemacs-server" (getenv "HOME")))

;; Queue of file paths received from clients (no mutex needed —
;; everything runs on the master timer thread now)
(def *ipc-queue* '())

;; Non-blocking listen socket fd
(def *ipc-listen-fd* #f)

;; Current client state
(def *ipc-client-fd* #f)
(def *ipc-line-buf* "")

;;;============================================================================
;;; Queue operations (single-threaded, no mutex needed)
;;;============================================================================

(def (ipc-queue-push! path)
  "Push a file path onto the IPC queue."
  (set! *ipc-queue* (append *ipc-queue* (list path))))

(def (ipc-poll-files!)
  "Drain the IPC queue and return a list of file paths.
   Called from the UI thread."
  (let ((files *ipc-queue*))
    (set! *ipc-queue* '())
    files))

;;;============================================================================
;;; String helpers
;;;============================================================================

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

(def (ipc-string-index str ch)
  "Return the index of the first occurrence of ch in str, or #f."
  (let ((len (string-length str)))
    (let loop ((i 0))
      (cond
        ((>= i len) #f)
        ((char=? (string-ref str i) ch) i)
        (else (loop (+ i 1)))))))

;;;============================================================================
;;; Client handling
;;;============================================================================

(def (ipc-disconnect!)
  "Close the IPC client connection."
  (when *ipc-client-fd*
    (with-catch (lambda _ (void))
      (lambda () (repl-socket-close *ipc-client-fd*))))
  (set! *ipc-client-fd* #f)
  (set! *ipc-line-buf* ""))

(def (ipc-process-lines!)
  "Process complete lines from the IPC client."
  (let loop ()
    (let ((nl (ipc-string-index *ipc-line-buf* #\newline)))
      (when nl
        (let ((line (substring *ipc-line-buf* 0 nl))
              (rest (substring *ipc-line-buf* (+ nl 1)
                               (string-length *ipc-line-buf*))))
          (set! *ipc-line-buf* rest)
          (let ((path (string-trim-ipc line)))
            (when (> (string-length path) 0)
              (ipc-queue-push! path)
              ;; Send OK response
              (repl-socket-write *ipc-client-fd* "OK\n")))
          (loop))))))

;;;============================================================================
;;; Tick — called from master timer every 100ms
;;;============================================================================

(def (ipc-tick!)
  "Non-blocking IPC poll. Accepts connections and reads file paths."
  (when *ipc-listen-fd*
    (with-catch
      (lambda (e) (void))
      (lambda ()
        (cond
          ;; No client — try to accept one
          ((not *ipc-client-fd*)
           (let ((cfd (repl-socket-accept *ipc-listen-fd*)))
             (when cfd
               (set! *ipc-client-fd* cfd)
               (set! *ipc-line-buf* ""))))

          ;; Client connected — try to read data
          (*ipc-client-fd*
           (let ((data (repl-socket-read *ipc-client-fd*)))
             (cond
               ((string? data)
                (set! *ipc-line-buf* (string-append *ipc-line-buf* data))
                (ipc-process-lines!))
               ((eq? data 'eof)
                ;; Client disconnected — process any remaining data
                (when (> (string-length *ipc-line-buf*) 0)
                  (let ((path (string-trim-ipc *ipc-line-buf*)))
                    (when (> (string-length path) 0)
                      (ipc-queue-push! path))))
                (ipc-disconnect!))))))))))

;;;============================================================================
;;; Public API
;;;============================================================================

(def (start-ipc-server!)
  "Start the IPC server on 127.0.0.1 with an OS-assigned port.
   Writes the host:port to *ipc-server-file*.

   THREAD-FREE: Registers a periodic tick with the master timer."
  (stop-ipc-server!)
  (let ((port-num (let ((env (getenv "GERBIL_EMACS_PORT" #f)))
                    (if env (string->number env) 0))))
    (let-values (((fd actual-port) (repl-socket-listen "127.0.0.1" port-num)))
      (set! *ipc-listen-fd* fd)
      ;; Write server file (delete stale file first)
      (when (file-exists? *ipc-server-file*)
        (with-catch (lambda _ (void))
          (lambda () (delete-file *ipc-server-file*))))
      (call-with-output-file *ipc-server-file*
        (lambda (p)
          (display "127.0.0.1:" p)
          (display actual-port p)
          (newline p)))
      ;; Register periodic tick
      (schedule-periodic! 'ipc-accept 100 ipc-tick!)
      (void))))

(def (stop-ipc-server!)
  "Stop the IPC server and remove the server file."
  (ipc-disconnect!)
  (when *ipc-listen-fd*
    (with-catch (lambda _ (void))
      (lambda () (repl-socket-close *ipc-listen-fd*)))
    (set! *ipc-listen-fd* #f))
  (when (file-exists? *ipc-server-file*)
    (with-catch (lambda _ (void))
      (lambda () (delete-file *ipc-server-file*)))))
