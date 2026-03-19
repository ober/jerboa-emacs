;;; -*- Gerbil -*-
;;; Async infrastructure for jemacs SMP
;;;
;;; Provides a unified UI action queue, async process runners,
;;; async file I/O, and a periodic task scheduler.
;;; Background threads push thunks via ui-queue-push!; a master timer
;;; drains them on the UI thread.
;;;
;;; SMP Thread Pinning:
;;; Gambit SMP can migrate green threads between OS-level Virtual Processors
;;; via work-stealing.  For Qt apps, the UI thread must stay on processor 0
;;; (the main OS thread) so Qt widget operations happen on the correct pthread.
;;; Use pin-thread-to-processor0! to pin critical threads, and
;;; spawn/name/pinned to spawn a green thread pre-pinned to processor 0.

(export
  ;; UI action queue
  ui-queue-push!
  ui-queue-drain!

  ;; SMP thread pinning
  pin-thread-to-processor0!
  spawn/name/pinned

  ;; Async command runner
  async-process!
  async-process-stream!

  ;; Async file I/O
  async-read-file!
  async-write-file!

  ;; Async eval (background thunk → UI callback)
  async-eval!

  ;; Periodic task scheduler
  schedule-periodic!
  master-timer-tick!
  current-time-ms

  ;; Background services
  *file-index*
  start-file-indexer!
  stop-file-indexer!
  file-index-lookup
  *git-status-cache*
  start-git-watcher!
  stop-git-watcher!
  flycheck-trigger!
  start-flycheck-watcher!
  stop-flycheck-watcher!)

(import :std/misc/channel
        (only-in :std/srfi/19 current-time time->seconds)
        :std/misc/atom
        :std/sugar
        :std/srfi/13
        :jerboa-emacs/core)

;;;============================================================================
;;; SMP Thread Pinning
;;;============================================================================

(def (pin-thread-to-processor0! thread)
  "Pin a green thread to processor 0 (no-op on Chez — no thread pinning API)."
  #f)







(def (spawn/name/pinned name thunk)
  "Spawn a named green thread pinned to processor 0.
   The thread is pinned before starting so it never runs on any other processor.
   Use for threads that must stay on the main OS thread (Qt UI operations)."
  (let ((t (make-thread thunk name)))
    (pin-thread-to-processor0! t)
    (thread-start! t)
    t))

;;;============================================================================
;;; UI Action Queue
;;;============================================================================

;; Buffered channel for UI actions. Background threads push thunks here;
;; the master timer drains them on the UI thread.
(def *ui-queue* (make-channel 4096))

(def (ui-queue-push! thunk)
  "Push a UI action from any thread. Non-blocking (buffered channel)."
  (channel-try-put *ui-queue* thunk))

(def (ui-queue-drain!)
  "Drain all pending UI actions. Called from the master timer on the UI thread.
   Processes up to 64 actions per tick to avoid starving the event loop."
  (let loop ((n 0))
    (when (< n 64)
      (let-values (((action found) (channel-try-get *ui-queue*)))
        (when found
          (with-catch
            (lambda (e) (jemacs-log! "UI queue error: " (format "~a" e)))
            action)
          (loop (+ n 1)))))))

;;;============================================================================
;;; Periodic Task Scheduler
;;;============================================================================

;; Each task: (name interval-ms last-run-ms thunk)
(def *scheduled-tasks* '())

(def (current-time-ms)
  "Current wall-clock time in milliseconds."
  (inexact->exact (floor (* (time->seconds (current-time)) 1000))))

(def (schedule-periodic! name interval-ms thunk)
  "Register a periodic task to run at the given interval.
   Tasks are run by master-timer-tick! on the UI thread."
  (set! *scheduled-tasks*
    (cons [name interval-ms 0 thunk] *scheduled-tasks*)))

(def (master-timer-tick!)
  "Master timer callback: drain the UI queue, then run periodic tasks.
   Should be called from a single Qt timer at ~16-50ms interval."
  ;; 1. Drain async UI queue
  (ui-queue-drain!)
  ;; 2. Run periodic tasks whose interval has elapsed
  (let ((now (current-time-ms)))
    (set! *scheduled-tasks*
      (map (lambda (task)
             (let ((name (car task))
                   (interval (cadr task))
                   (last (caddr task))
                   (thunk (cadddr task)))
               (if (>= (- now last) interval)
                 (begin
                   (with-catch
                     (lambda (e)
                       (jemacs-log! "Timer error in " name ": "
                                    (format "~a" e)))
                     thunk)
                   [name interval now thunk])
                 task)))
           *scheduled-tasks*))))

;;;============================================================================
;;; Async Process Runner
;;;============================================================================

(def (async-process! cmd
                     callback: callback
                     on-error: (on-error #f)
                     stdin-text: (stdin-text #f))
  "Run shell command synchronously and call callback with result.
   Blocks the caller until the subprocess finishes — avoids GC deadlocks
   caused by background Chez threads blocking in foreign calls."
  (with-catch
    (lambda (e)
      (if on-error (on-error e)
        (jemacs-log! "async-process error: " (format "~a" e))))
    (lambda ()
      (let-values (((in-port out-port err-port pid)
                    (open-process-ports cmd (buffer-mode block) (native-transcoder))))
        (when stdin-text
          (put-string out-port stdin-text)
          (flush-output-port out-port))
        (close-port out-port)
        (close-port err-port)
        ;; Read all output
        (let ((out (get-string-all in-port)))
          (close-port in-port)
          (let ((result (if (eof-object? out) "" out)))
            (callback result)))))))

(def (async-process-stream! cmd
                            on-line: on-line
                            on-done: (on-done #f)
                            on-error: (on-error #f))
  "Run shell command synchronously, deliver each line to on-line callback.
   Blocks until the subprocess finishes — avoids GC deadlocks."
  (with-catch
    (lambda (e)
      (if on-error (on-error e)
        (jemacs-log! "async-process-stream error: " (format "~a" e))))
    (lambda ()
      (let-values (((in-port out-port err-port pid)
                    (open-process-ports cmd (buffer-mode line) (native-transcoder))))
        (close-port out-port)
        (close-port err-port)
        (let loop ()
          (let ((line (get-line in-port)))
            (if (eof-object? line)
              (begin
                (close-port in-port)
                (when on-done (on-done)))
              (begin
                (on-line line)
                (loop)))))))))

;;;============================================================================
;;; Async File I/O
;;;============================================================================

(def (async-read-file! path callback)
  "Read file synchronously and call callback immediately.
   Runs on the caller's thread to avoid Chez SMP GC deadlocks caused by
   background threads blocking in foreign calls (file I/O)."
  (let ((content (with-catch (lambda (e) #f)
                   (lambda ()
                     (call-with-input-file path
                       (lambda (port) (get-string-all port)))))))
    (callback content)))

(def (async-write-file! path content callback)
  "Write file synchronously and call callback immediately.
   Runs on the caller's thread to avoid GC deadlocks."
  (let ((ok (with-catch (lambda (e) #f)
              (lambda ()
                (call-with-output-file path
                  (lambda (port) (display content port)))
                #t))))
    (callback ok)))

;;;============================================================================
;;; Async Eval
;;;============================================================================

(def (async-eval! thunk callback)
  "Evaluate thunk synchronously and call callback immediately.
   Runs on the caller's thread to avoid GC deadlocks."
  (let ((result (with-catch
                  (lambda (e) (values 'error e))
                  thunk)))
    (callback result)))

;;;============================================================================
;;; Background Services
;;;============================================================================

;;; 8.1 File Indexer — builds file index for fast find-file completion

(def *file-index* (atom (make-hash-table)))
(def *file-indexer-root* #f)

(def (build-file-index root-dir)
  "Walk directory tree and build a hash of basename -> full-path list."
  (let ((index (make-hash-table)))
    (with-catch
      (lambda (e) index)
      (lambda ()
        (let walk ((dir root-dir))
          (for-each
            (lambda (entry)
              (let ((path (path-expand entry dir)))
                (with-catch
                  (lambda (e) #f)
                  (lambda ()
                    (let ((info (file-info path)))
                      (if (eq? 'directory (file-info-type info))
                        ;; Skip hidden directories
                        (unless (string-prefix? "." entry)
                          (walk path))
                        ;; Index the file
                        (let* ((name (path-strip-directory path))
                               (existing (or (hash-get index name) '())))
                          (hash-put! index name (cons path existing)))))))))
            (directory-files dir)))
        index))))

(def (start-file-indexer! root-dir)
  "Register file indexer as a periodic task (30s interval).
   Runs on the master timer thread — no background Chez thread needed."
  (stop-file-indexer!)
  (set! *file-indexer-root* root-dir)
  (schedule-periodic! 'file-indexer 30000
    (lambda ()
      (when *file-indexer-root*
        (let ((index (build-file-index *file-indexer-root*)))
          (atom-reset! *file-index* index))))))

(def (stop-file-indexer!)
  "Stop the file indexer."
  (set! *file-indexer-root* #f))

(def (file-index-lookup name)
  "Look up a filename in the index. Returns list of full paths."
  (or (hash-get (atom-deref *file-index*) name) '()))

;;; 8.2 Git Status Watcher — polls git status for modeline

(def *git-status-cache* (atom (make-hash-table)))
(def *git-watcher-dir* #f)
(def *git-watcher-callback* #f)

(def (parse-git-status-line line)
  "Parse one line of git status --porcelain output into (status . file)."
  (when (>= (string-length line) 4)
    (let ((status (substring line 0 2))
          (file (substring line 3 (string-length line))))
      (cons (string-trim-both status) file))))

(def (git-watcher-tick!)
  "One git status poll. Called from the periodic scheduler."
  (when *git-watcher-dir*
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let-values (((in-port out-port err-port pid)
                      (open-process-ports
                        (string-append "git -C \"" *git-watcher-dir* "\" status --porcelain -b 2>&1")
                        (buffer-mode line) (native-transcoder))))
          (close-port out-port)
          (close-port err-port)
          (let* ((lines (let rd ((acc '()))
                          (let ((line (get-line in-port)))
                            (if (eof-object? line)
                              (reverse acc)
                              (rd (cons line acc)))))))
          (close-port in-port)
          (let ((status (make-hash-table))
                (modified 0) (staged 0) (untracked 0))
            (for-each
              (lambda (line)
                (when (>= (string-length line) 3)
                  (let ((xy (substring line 0 2)))
                    (cond
                      ((string-prefix? "##" xy)
                       (hash-put! status 'branch
                         (substring line 3 (string-length line))))
                      ((string-contains xy "?")
                       (set! untracked (+ untracked 1)))
                      ((or (string-contains xy "M")
                           (string-contains xy "D"))
                       (set! modified (+ modified 1)))
                      ((or (string-contains xy "A")
                           (string-contains xy "R"))
                       (set! staged (+ staged 1)))))))
              lines)
            (hash-put! status 'modified modified)
            (hash-put! status 'staged staged)
            (hash-put! status 'untracked untracked)
            (atom-reset! *git-status-cache* status)
            (when *git-watcher-callback*
              (*git-watcher-callback* status)))))))))

(def (start-git-watcher! dir (on-update #f))
  "Register git status polling as a periodic task (5s interval).
   Runs on the master timer thread — no background Chez thread needed."
  (stop-git-watcher!)
  (set! *git-watcher-dir* dir)
  (set! *git-watcher-callback* on-update)
  (schedule-periodic! 'git-watcher 5000 git-watcher-tick!))

(def (stop-git-watcher!)
  "Stop the git status watcher."
  (set! *git-watcher-dir* #f)
  (set! *git-watcher-callback* #f))

;;; 8.3 Flycheck Watcher — runs linter on save via channel trigger

(def *flycheck-pending* '())
(def *flycheck-lint-fn* #f)
(def *flycheck-result-fn* #f)

(def (flycheck-trigger! path)
  "Queue a flycheck run for the given file path."
  (unless (member path *flycheck-pending*)
    (set! *flycheck-pending* (cons path *flycheck-pending*))))

(def (start-flycheck-watcher! lint-fn on-result)
  "Register flycheck as a periodic task (500ms interval).
   Runs on the master timer thread — no background Chez thread needed."
  (stop-flycheck-watcher!)
  (set! *flycheck-lint-fn* lint-fn)
  (set! *flycheck-result-fn* on-result)
  (schedule-periodic! 'flycheck 500
    (lambda ()
      (when (and *flycheck-lint-fn* (pair? *flycheck-pending*))
        (let ((path (car *flycheck-pending*)))
          (set! *flycheck-pending* (cdr *flycheck-pending*))
          (when (string? path)
            (with-catch
              (lambda (e)
                (jemacs-log! "flycheck error: " (format "~a" e)))
              (lambda ()
                (let ((errors (*flycheck-lint-fn* path)))
                  (*flycheck-result-fn* path errors))))))))))

(def (stop-flycheck-watcher!)
  "Stop the flycheck watcher."
  (set! *flycheck-lint-fn* #f)
  (set! *flycheck-result-fn* #f)
  (set! *flycheck-pending* '()))
