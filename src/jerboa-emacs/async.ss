;;; -*- Gerbil -*-
;;; Async infrastructure for jemacs SMP
;;;
;;; Architecture:
;;;   - Primordial thread runs Qt event loop + master timer (UI-only)
;;;   - Background threads (via fork-thread) handle blocking work:
;;;     subprocesses, file I/O, filesystem walks, git operations
;;;   - Background threads post results to UI queue via ui-queue-push!
;;;   - Master timer drains UI queue on primordial thread (safe for Qt)
;;;
;;; GC safety:
;;;   Chez SMP GC uses stop-the-world rendezvous (active_threads must reach 0).
;;;   Threads blocked in sleep/condition-wait/mutex-acquire auto-deactivate.
;;;   Threads blocked in foreign calls (read/popen) do NOT auto-deactivate.
;;;   Solution: repl-capture-command (C level) deactivates around blocking I/O.
;;;   NEVER use open-process-ports + get-line in worker threads — use
;;;   repl-capture-command instead.
;;;   NEVER block the primordial thread — it freezes the entire UI.

(export
  ;; UI action queue
  ui-queue-push!
  ui-queue-drain!

  ;; Background worker
  spawn-worker

  ;; Thread pinning (no-op on Chez — Qt affinity handled by architecture)
  pin-thread-to-processor0!

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
        :jerboa-emacs/core
        (only-in :jerboa/repl-socket
          repl-capture-command
          repl-read-file
          repl-write-file))

;;;============================================================================
;;; String Helpers
;;;============================================================================

(def (string-split-newlines str)
  "Split a string on newline characters. Drops trailing empty string."
  (let ((len (string-length str)))
    (if (= len 0) '()
      (let loop ((start 0) (i 0) (acc '()))
        (cond
          ((>= i len)
           (let ((last (substring str start len)))
             (reverse (if (string=? last "") acc (cons last acc)))))
          ((char=? (string-ref str i) #\newline)
           (loop (+ i 1) (+ i 1) (cons (substring str start i) acc)))
          (else (loop start (+ i 1) acc)))))))

(def (shell-escape-single-quotes str)
  "Escape single quotes for use inside a single-quoted shell string.
   Replaces ' with '\\'' (end quote, escaped quote, start quote)."
  (let loop ((i 0) (acc '()))
    (if (>= i (string-length str))
      (apply string-append (reverse acc))
      (if (char=? (string-ref str i) #\')
        (loop (+ i 1) (cons "'\\''" acc))
        (let ((start i))
          (let scan ((j (+ i 1)))
            (cond
              ((>= j (string-length str))
               (loop j (cons (substring str start j) acc)))
              ((char=? (string-ref str j) #\')
               (loop j (cons (substring str start j) acc)))
              (else (scan (+ j 1))))))))))

;;;============================================================================
;;; Thread Pinning (no-op on Chez)
;;;============================================================================

(def (pin-thread-to-processor0! thread)
  "No-op on Chez — Qt thread affinity is handled by architecture:
   all Qt calls run on the primordial thread, blocking work in workers."
  #f)

;;;============================================================================
;;; Background Worker
;;;============================================================================

(def (spawn-worker name thunk)
  "Spawn a background worker thread for blocking operations.
   Worker thunks should use repl-capture-command (not open-process-ports)
   for subprocess I/O, and repl-read-file/repl-write-file for file I/O.
   These C-level helpers deactivate the Chez thread during blocking system
   calls so GC can proceed, then reactivate before returning Scheme strings."
  (let ((t (make-thread
             (lambda ()
               (with-catch
                 (lambda (e)
                   (jemacs-log! "Worker " (symbol->string name) " error: "
                                (format "~a" e)))
                 thunk))
             name)))
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
            (lambda (e) (verbose-log! "UI-QUEUE-ERROR: "
                                     (with-output-to-string
                                       (lambda () (display-exception e)))))
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
                   (verbose-log! "TICK " (symbol->string name) " begin")
                   (with-catch
                     (lambda (e)
                       (verbose-log! "TIMER-ERROR in "
                                     (symbol->string name) ": "
                                     (with-output-to-string
                                       (lambda () (display-exception e)))))
                     thunk)
                   (verbose-log! "TICK " (symbol->string name) " end")
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
  "Run shell command in a background thread, deliver result via UI queue.
   Uses repl-capture-command for GC-safe subprocess I/O — the thread is
   deactivated during the blocking popen/fread at the C level.
   The callback runs on the primordial/UI thread (safe for Qt operations)."
  (spawn-worker 'async-process
    (lambda ()
      (with-catch
        (lambda (e)
          (ui-queue-push!
            (lambda ()
              (if on-error (on-error e)
                (jemacs-log! "async-process error: " (format "~a" e))))))
        (lambda ()
          (let ((full-cmd (if stdin-text
                            ;; For stdin: use printf piped to command
                            ;; (shell handles the pipe, no Chez port blocking)
                            (string-append "printf '%s' '"
                                           (shell-escape-single-quotes stdin-text)
                                           "' | " cmd)
                            cmd)))
            (let ((result (repl-capture-command full-cmd)))
              (ui-queue-push! (lambda () (callback result))))))))))

(def (async-process-stream! cmd
                            on-line: on-line
                            on-done: (on-done #f)
                            on-error: (on-error #f))
  "Run shell command in background thread, deliver each line via UI queue.
   Uses repl-capture-command for GC-safe I/O, then splits output into lines.
   Callbacks run on the primordial/UI thread (safe for Qt operations)."
  (spawn-worker 'async-process-stream
    (lambda ()
      (with-catch
        (lambda (e)
          (ui-queue-push!
            (lambda ()
              (if on-error (on-error e)
                (jemacs-log! "async-process-stream error: " (format "~a" e))))))
        (lambda ()
          (let ((output (repl-capture-command cmd)))
            ;; Split output into lines and deliver each via UI queue
            (let ((lines (string-split-newlines output)))
              (for-each
                (lambda (line)
                  (ui-queue-push! (lambda () (on-line line))))
                lines)
              (when on-done
                (ui-queue-push! on-done)))))))))

;;;============================================================================
;;; Async File I/O
;;;============================================================================

(def (async-read-file! path callback)
  "Read file in a background thread, deliver content via UI queue.
   Uses repl-read-file for GC-safe file I/O.
   Callback receives the file content string, or #f on error."
  (spawn-worker 'async-read-file
    (lambda ()
      (let ((content (with-catch (lambda (e) #f)
                       (lambda () (repl-read-file path)))))
        (ui-queue-push! (lambda () (callback content)))))))

(def (async-write-file! path content callback)
  "Write file in a background thread, deliver result via UI queue.
   Uses repl-write-file for GC-safe file I/O.
   Callback receives #t on success, #f on error."
  (spawn-worker 'async-write-file
    (lambda ()
      (let ((ok (with-catch (lambda (e) #f)
                  (lambda () (repl-write-file path content)))))
        (ui-queue-push! (lambda () (callback ok)))))))

;;;============================================================================
;;; Async Eval
;;;============================================================================

(def (async-eval! thunk callback)
  "Evaluate thunk in background thread, deliver result via UI queue.
   Callback runs on the primordial/UI thread."
  (spawn-worker 'async-eval
    (lambda ()
      (let ((result (with-catch
                      (lambda (e) (values 'error e))
                      thunk)))
        (ui-queue-push! (lambda () (callback result)))))))

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

(def *file-indexer-running* #f)

(def (start-file-indexer! root-dir)
  "Register file indexer as a periodic task (30s interval).
   The periodic tick spawns a background thread for the filesystem walk,
   then posts the result to the UI thread via atom-reset!."
  (stop-file-indexer!)
  (set! *file-indexer-root* root-dir)
  (schedule-periodic! 'file-indexer 30000
    (lambda ()
      (when (and *file-indexer-root* (not *file-indexer-running*))
        (set! *file-indexer-running* #t)
        (spawn-worker 'file-indexer
          (lambda ()
            (let ((index (build-file-index *file-indexer-root*)))
              (ui-queue-push!
                (lambda ()
                  (atom-reset! *file-index* index)
                  (set! *file-indexer-running* #f))))))))))

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

(def *git-watcher-running* #f)

(def (git-status-collect dir)
  "Run git status subprocess and return a hash with branch/modified/staged/untracked.
   Uses repl-capture-command for GC-safe subprocess I/O."
  (let* ((output (repl-capture-command
                   (string-append "git -C \"" dir "\" status --porcelain -b 2>&1")))
         (lines (string-split-newlines output))
         (status (make-hash-table))
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
              ((or (string-contains xy "M") (string-contains xy "D"))
               (set! modified (+ modified 1)))
              ((or (string-contains xy "A") (string-contains xy "R"))
               (set! staged (+ staged 1)))))))
      lines)
    (hash-put! status 'modified modified)
    (hash-put! status 'staged staged)
    (hash-put! status 'untracked untracked)
    status))

(def (git-watcher-tick!)
  "One git status poll. Spawns a background thread for the subprocess,
   posts results to UI thread. Skips if previous poll still running."
  (when (and *git-watcher-dir* (not *git-watcher-running*))
    (set! *git-watcher-running* #t)
    (let ((dir *git-watcher-dir*))
      (spawn-worker 'git-watcher
        (lambda ()
          (let ((status (with-catch (lambda (e) #f)
                          (lambda () (git-status-collect dir)))))
            (ui-queue-push!
              (lambda ()
                (when status
                  (atom-reset! *git-status-cache* status)
                  (when *git-watcher-callback*
                    (*git-watcher-callback* status)))
                (set! *git-watcher-running* #f)))))))))

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

(def *flycheck-running* #f)

(def (start-flycheck-watcher! lint-fn on-result)
  "Register flycheck as a periodic task (500ms interval).
   Spawns background thread for linting, posts results to UI thread."
  (stop-flycheck-watcher!)
  (set! *flycheck-lint-fn* lint-fn)
  (set! *flycheck-result-fn* on-result)
  (schedule-periodic! 'flycheck 500
    (lambda ()
      (when (and *flycheck-lint-fn* (pair? *flycheck-pending*) (not *flycheck-running*))
        (let ((path (car *flycheck-pending*))
              (lint *flycheck-lint-fn*)
              (result-fn *flycheck-result-fn*))
          (set! *flycheck-pending* (cdr *flycheck-pending*))
          (when (string? path)
            (set! *flycheck-running* #t)
            (spawn-worker 'flycheck
              (lambda ()
                (with-catch
                  (lambda (e)
                    (ui-queue-push!
                      (lambda ()
                        (jemacs-log! "flycheck error: " (format "~a" e))
                        (set! *flycheck-running* #f))))
                  (lambda ()
                    (let ((errors (lint path)))
                      (ui-queue-push!
                        (lambda ()
                          (result-fn path errors)
                          (set! *flycheck-running* #f))))))))))))))

(def (stop-flycheck-watcher!)
  "Stop the flycheck watcher."
  (set! *flycheck-lint-fn* #f)
  (set! *flycheck-result-fn* #f)
  (set! *flycheck-pending* '()))
