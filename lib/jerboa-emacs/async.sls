#!chezscheme
;;; async.sls — Async infrastructure for jemacs SMP
;;;
;;; Ported from gerbil-emacs/async.ss
;;; Provides a unified UI action queue, async process runners,
;;; async file I/O, and a periodic task scheduler.
;;; UPGRADE: Uses jerboa native threads (no Gambit SMP pinning needed —
;;; Chez uses native OS threads, so any thread can make UI calls if synchronized).

(library (jerboa-emacs async)
  (export
    ;; UI action queue
    ui-queue-push!
    ui-queue-drain!

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
    file-index
    start-file-indexer!
    stop-file-indexer!
    file-index-lookup
    git-status-cache
    start-git-watcher!
    stop-git-watcher!
    flycheck-trigger
    flycheck-trigger!
    start-flycheck-watcher!
    stop-flycheck-watcher!)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort! atom?)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std srfi srfi-13)
          (only (std misc string) string-split)
          (std misc channel)
          (std misc atom)
          (std misc process)
          (only (jerboa prelude) path-strip-directory)
          (only (std misc thread) thread-sleep!)
          (jerboa-emacs core))

  ;;;============================================================================
  ;;; UI Action Queue
  ;;;============================================================================

  (def *ui-queue* (make-channel 4096))

  (def (ui-queue-push! thunk)
    (with-catch
      (lambda (e) (void))
      (lambda () (channel-put *ui-queue* thunk))))

  (def (ui-queue-drain!)
    (let loop ((n 0))
      (when (< n 64)
        (let-values (((action ok) (channel-try-get *ui-queue*)))
          (when ok
            (with-catch
              (lambda (e) (jemacs-log! (string-append "UI queue error: " (format "~a" e))))
              (lambda () (action)))
            (loop (+ n 1)))))))

  ;;;============================================================================
  ;;; Periodic Task Scheduler
  ;;;============================================================================

  (def *scheduled-tasks* '())

  (def (current-time-ms)
    (let ((t (current-time)))
      (+ (* (time-second t) 1000)
         (quotient (time-nanosecond t) 1000000))))

  (def (schedule-periodic! name interval-ms thunk)
    (set! *scheduled-tasks*
      (cons (list name interval-ms 0 thunk) *scheduled-tasks*)))

  (def (master-timer-tick!)
    (ui-queue-drain!)
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
                         (jemacs-log! (string-append "Timer error in "
                                                     (if (string? name) name (symbol->string name))
                                                     ": " (format "~a" e))))
                       thunk)
                     (list name interval now thunk))
                   task)))
             *scheduled-tasks*))))

  ;;;============================================================================
  ;;; Async Process Runner
  ;;;============================================================================

  (def (async-process! cmd callback . rest)
    (let ((on-error (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) #f))
          (stdin-text (if (and (pair? rest) (pair? (cdr rest)) (pair? (cddr rest)) (pair? (cdddr rest)))
                       (cadddr rest) #f)))
      (fork-thread
        (lambda ()
          (with-catch
            (lambda (e)
              (ui-queue-push!
                (lambda ()
                  (if on-error (on-error e)
                    (jemacs-log! (string-append "async-process error: " (format "~a" e)))))))
            (lambda ()
              (let ((result (run-process (list "/bin/sh" "-c" cmd))))
                (ui-queue-push! (lambda () (callback result))))))))))

  (def (async-process-stream! cmd on-line . rest)
    (let ((on-done (if (pair? rest) (car rest) #f))
          (on-error (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) #f)))
      (fork-thread
        (lambda ()
          (with-catch
            (lambda (e)
              (ui-queue-push!
                (lambda ()
                  (if on-error (on-error e)
                    (jemacs-log! (string-append "async-process-stream error: " (format "~a" e)))))))
            (lambda ()
              (let ((pp (open-process (list "/bin/sh" "-c" cmd))))
                (let ((stdout (process-port-rec-stdout-port pp)))
                  (let loop ()
                    (let ((line (get-line stdout)))
                      (if (eof-object? line)
                        (begin
                          (close-port stdout)
                          (when on-done
                            (ui-queue-push! on-done)))
                        (begin
                          (ui-queue-push! (lambda () (on-line line)))
                          (loop)))))))))))))

  ;;;============================================================================
  ;;; Async File I/O
  ;;;============================================================================

  (def (async-read-file! path callback)
    (fork-thread
      (lambda ()
        (let ((content (with-catch (lambda (e) #f)
                         (lambda ()
                           (call-with-input-file path
                             (lambda (port) (get-string-all port)))))))
          (ui-queue-push! (lambda () (callback content)))))))

  (def (async-write-file! path content callback)
    (fork-thread
      (lambda ()
        (let ((ok (with-catch (lambda (e) #f)
                    (lambda ()
                      (call-with-output-file path
                        (lambda (port) (display content port)))
                      #t))))
          (ui-queue-push! (lambda () (callback ok)))))))

  ;;;============================================================================
  ;;; Async Eval
  ;;;============================================================================

  (def (async-eval! thunk callback)
    (fork-thread
      (lambda ()
        (let ((result (with-catch
                        (lambda (e) (cons 'error e))
                        thunk)))
          (ui-queue-push! (lambda () (callback result)))))))

  ;;;============================================================================
  ;;; Background Services
  ;;;============================================================================

  ;;; File Indexer — builds file index for fast find-file completion

  (def *file-index* (atom (make-hash-table)))
  (def (file-index) *file-index*)
  (def *file-indexer-thread* #f)

  (def (build-file-index root-dir)
    (let ((index (make-hash-table)))
      (with-catch
        (lambda (e) index)
        (lambda ()
          (let walk ((dir root-dir))
            (for-each
              (lambda (entry)
                (let ((path (string-append dir "/" entry)))
                  (with-catch
                    (lambda (e) #f)
                    (lambda ()
                      (if (file-directory? path)
                        (unless (and (> (string-length entry) 0)
                                     (char=? (string-ref entry 0) #\.))
                          (walk path))
                        (let* ((name (path-strip-directory path))
                               (existing (or (hash-get index name) '())))
                          (hash-put! index name (cons path existing))))))))
              (directory-list dir)))
          index))))

  (def (start-file-indexer! root-dir)
    (stop-file-indexer!)
    (set! *file-indexer-thread*
      (fork-thread
        (lambda ()
          (let loop ()
            (let ((index (build-file-index root-dir)))
              (atom-reset! *file-index* index))
            (thread-sleep! 30)
            (loop))))))

  (def (stop-file-indexer!)
    (when *file-indexer-thread*
      ;; No clean way to interrupt — just abandon
      (set! *file-indexer-thread* #f)))

  (def (file-index-lookup name)
    (or (hash-get (atom-deref *file-index*) name) '()))

  ;;; Git Status Watcher — polls git status for modeline

  (def *git-status-cache* (atom (make-hash-table)))
  (def (git-status-cache) *git-status-cache*)
  (def *git-watcher-thread* #f)

  (def (start-git-watcher! dir . rest)
    (let ((on-update (if (pair? rest) (car rest) #f)))
      (stop-git-watcher!)
      (set! *git-watcher-thread*
        (fork-thread
          (lambda ()
            (let loop ()
              (with-catch
                (lambda (e) #f)
                (lambda ()
                  (let* ((output (run-process (list "git" "status" "--porcelain" "-b")
                                              'directory: dir))
                         (lines (string-split output #\newline))
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
                    (when on-update
                      (ui-queue-push! (lambda () (on-update status)))))))
              (thread-sleep! 5)
              (loop)))))))

  (def (stop-git-watcher!)
    (when *git-watcher-thread*
      (set! *git-watcher-thread* #f)))

  ;;; Flycheck Watcher — runs linter on save via channel trigger

  (def *flycheck-trigger* (make-channel 64))
  (def (flycheck-trigger) *flycheck-trigger*)
  (def *flycheck-watcher-thread* #f)

  (def (flycheck-trigger! path)
    (with-catch
      (lambda (e) (void))
      (lambda () (channel-put *flycheck-trigger* path))))

  (def (start-flycheck-watcher! lint-fn on-result)
    (stop-flycheck-watcher!)
    (set! *flycheck-watcher-thread*
      (fork-thread
        (lambda ()
          (let loop ()
            (let ((path (channel-get *flycheck-trigger*)))
              (when (string? path)
                (with-catch
                  (lambda (e)
                    (jemacs-log! (string-append "flycheck error: " (format "~a" e))))
                  (lambda ()
                    (let ((errors (lint-fn path)))
                      (ui-queue-push!
                        (lambda () (on-result path errors))))))))
            (loop))))))

  (def (stop-flycheck-watcher!)
    (when *flycheck-watcher-thread*
      (set! *flycheck-watcher-thread* #f)))

  ) ;; end library
