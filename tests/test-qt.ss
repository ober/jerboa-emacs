#!/usr/bin/env scheme-script
#!chezscheme
;;; test-qt.ss — Qt functional tests for jerboa-emacs
;;;
;;; Run:
;;;   QT_QPA_PLATFORM=offscreen make test-qt
;;;
;;; Tests the Qt editor in headless mode (no display needed).
;;; Does NOT call qt-app-exec! — tests run synchronously.

(import (except (chezscheme) make-hash-table hash-table? iota 1+ 1-
                getenv path-extension path-absolute? thread?
                make-mutex mutex? mutex-name)
        (jerboa core)
        (std sugar)
        (jerboa-emacs core)
        (jerboa-emacs buffer)
        (jerboa-emacs keymap)
        (jerboa-emacs editor)
        (jerboa-emacs qt window)
        (jerboa-emacs qt buffer)
        (jerboa-emacs qt highlight)
        (jerboa-emacs qt commands)
        (chez-qt qt))

;;; ─── Test framework ──────────────────────────────────────────────────────────

(define *pass* 0)
(define *fail* 0)
(define *test-name* "(none)")

(define-syntax test-group
  (syntax-rules ()
    [(_ name body ...)
     (begin
       (display (string-append "\n=== " name " ===\n"))
       (flush-output-port (current-output-port))
       body ...)]))

(define-syntax test-case
  (syntax-rules ()
    [(_ name body ...)
     (begin
       (set! *test-name* name)
       (guard (e [#t
                  (set! *fail* (+ *fail* 1))
                  (display (string-append "  FAIL: " name "\n"))
                  (display (string-append "    error: "
                             (if (message-condition? e)
                               (condition-message e)
                               (format "~s" e))
                             "\n"))
                  (flush-output-port (current-output-port))])
         body ...
         (set! *pass* (+ *pass* 1))
         (display (string-append "  pass: " name "\n"))
         (flush-output-port (current-output-port))))]))

(define-syntax check
  (syntax-rules (=> ?)
    [(_ expr => expected)
     (let ([got expr] [exp expected])
       (unless (equal? got exp)
         (error 'check
                (format "~a: expected ~s, got ~s" *test-name* exp got))))]
    [(_ expr ? pred)
     (let ([got expr])
       (unless (pred got)
         (error 'check
                (format "~a: predicate failed for ~s" *test-name* got))))]))

;;; ─── Qt application setup ────────────────────────────────────────────────────

;; QT_QPA_PLATFORM=offscreen must be set before qt-app-create
(unless (getenv "QT_QPA_PLATFORM")
  (setenv "QT_QPA_PLATFORM" "offscreen"))

(display "Creating Qt application (offscreen)...\n")
(flush-output-port (current-output-port))
(define *qt-app* (qt-app-create))
(display "Qt app created.\n")
(flush-output-port (current-output-port))

;;; ─── Phase 1: Qt widget basics ───────────────────────────────────────────────

(test-group "Qt application"
  (test-case "qt-app-create returns non-null"
    (check (not (eqv? *qt-app* 0)) ? values))

  (test-case "widget create/destroy"
    (let ((w (qt-widget-create)))
      (check (not (eqv? w 0)) ? values)
      (qt-widget-destroy! w)))

  (test-case "main window create"
    (let ((win (qt-main-window-create)))
      (check (not (eqv? win 0)) ? values)
      (qt-widget-destroy! win)))

  (test-case "label create/text"
    (let ((l (qt-label-create "hello")))
      (check (qt-label-text l) => "hello")
      (qt-label-set-text! l "world")
      (check (qt-label-text l) => "world")
      (qt-widget-destroy! l)))

  (test-case "line edit create/text"
    (let ((e (qt-line-edit-create)))
      (qt-line-edit-set-text! e "test input")
      (check (qt-line-edit-text e) => "test input")
      (qt-widget-destroy! e)))

  (test-case "splitter create"
    (let ((sp (qt-splitter-create QT_VERTICAL)))
      (check (not (eqv? sp 0)) ? values)
      (qt-widget-destroy! sp))))

;;; ─── Phase 2: Plain text edit ────────────────────────────────────────────────

(test-group "Plain text edit"
  (test-case "create with parent"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w)))
      (check (not (eqv? ed 0)) ? values)
      (qt-widget-destroy! w)))

  (test-case "set and get text"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w)))
      (qt-plain-text-edit-set-text! ed "Hello, world!")
      (check (qt-plain-text-edit-text ed) => "Hello, world!")
      (qt-widget-destroy! w)))

  (test-case "text length"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w)))
      (qt-plain-text-edit-set-text! ed "abc")
      (check (qt-plain-text-edit-text-length ed) => 3)
      (qt-widget-destroy! w)))

  (test-case "cursor position set/get"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w)))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 5)
      (check (qt-plain-text-edit-cursor-position ed) => 5)
      (qt-widget-destroy! w)))

  (test-case "line count"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w)))
      (qt-plain-text-edit-set-text! ed "line1\nline2\nline3")
      (check (qt-plain-text-edit-line-count ed) => 3)
      (qt-widget-destroy! w)))

  (test-case "cursor line and column"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w)))
      (qt-plain-text-edit-set-text! ed "abc\ndefgh\nij")
      ;; Move to second line, position 4
      (qt-plain-text-edit-set-cursor-position! ed 7)
      (check (qt-plain-text-edit-cursor-line ed) => 1)
      (qt-widget-destroy! w)))

  (test-case "text document create/destroy"
    (let ((doc (qt-plain-text-document-create)))
      (check (not (eqv? doc 0)) ? values)
      (qt-text-document-destroy! doc)))

  (test-case "set document"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w))
           (doc (qt-plain-text-document-create)))
      (qt-plain-text-edit-set-document! ed doc)
      (let ((got-doc (qt-plain-text-edit-document ed)))
        (check (not (eqv? got-doc 0)) ? values))
      (qt-widget-destroy! w))))

;;; ─── Phase 3: Buffer management ──────────────────────────────────────────────

(test-group "Buffer management"
  (test-case "make-buffer creates a buffer"
    (let* ((doc (qt-plain-text-document-create))
           (buf (make-buffer "*qt-test*" #f doc #f #f #f #f)))
      (check (buffer? buf) ? values)
      (check (buffer-name buf) => "*qt-test*")
      (check (buffer-doc-pointer buf) => doc)
      (qt-text-document-destroy! doc)))

  (test-case "buffer-file-path is #f for scratch"
    (let* ((doc (qt-plain-text-document-create))
           (buf (make-buffer "*scratch-qt*" #f doc #f #f #f #f)))
      (check (buffer-file-path buf) => #f)
      (qt-text-document-destroy! doc)))

  (test-case "buffer-list tracks buffers"
    (let ((initial (length (buffer-list))))
      (let* ((doc (qt-plain-text-document-create))
             (buf (make-buffer "*list-test*" #f doc #f #f #f #f)))
        (buffer-list-add! buf)
        (check (>= (length (buffer-list)) (+ initial 1)) ? values)
        (buffer-list-remove! buf)
        (qt-text-document-destroy! doc)))))

;;; ─── Phase 4: Command registration ──────────────────────────────────────────

(test-group "Command registration"
  ;; Register all editor commands first
  (register-all-commands!)
  (qt-register-all-commands!)

  (test-case "forward-char registered"
    (check (find-command 'forward-char) ? procedure?))

  (test-case "backward-char registered"
    (check (find-command 'backward-char) ? procedure?))

  (test-case "next-line registered"
    (check (find-command 'next-line) ? procedure?))

  (test-case "kill-line registered"
    (check (find-command 'kill-line) ? procedure?))

  (test-case "yank registered"
    (check (find-command 'yank) ? procedure?))

  (test-case "save-buffer registered"
    (check (find-command 'save-buffer) ? procedure?))

  (test-case "find-file registered"
    (check (find-command 'find-file) ? procedure?))

  (test-case "undo registered"
    (check (find-command 'undo) ? procedure?)))

;;; ─── Phase 5: Language detection ────────────────────────────────────────────

(test-group "Language detection"
  (test-case "Python"
    (check (detect-language "foo.py") => 'python))
  (test-case "Rust"
    (check (detect-language "foo.rs") => 'rust))
  (test-case "Scheme"
    (check (detect-language "foo.ss") => 'scheme))
  (test-case "C"
    (check (detect-language "foo.c") => 'c))
  (test-case "C++"
    (check (detect-language "foo.cpp") => 'c++))
  (test-case "JavaScript"
    (check (detect-language "foo.js") => 'javascript))
  (test-case "TypeScript"
    (check (detect-language "foo.ts") => 'typescript))
  (test-case "Haskell"
    (check (detect-language "foo.hs") => 'haskell))
  (test-case "Unknown returns #f"
    (check (detect-language "foo.xyz") => #f)))

;;; ─── Phase 6: Window splitting data structures ───────────────────────────────

(test-group "Split tree"
  (test-case "split-leaf contains window"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w))
           (doc (qt-plain-text-document-create))
           (buf (make-buffer "*split1*" #f doc #f #f #f #f))
           (container (qt-widget-create w))
           (win (make-qt-edit-window ed container buf #f #f #f))
           (leaf (make-split-leaf win)))
      (check (split-leaf? leaf) ? values)
      (check (split-leaf-edit-window leaf) => win)
      (qt-text-document-destroy! doc)
      (qt-widget-destroy! w)))

  (test-case "split-tree-flatten single leaf"
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w))
           (doc (qt-plain-text-document-create))
           (buf (make-buffer "*split2*" #f doc #f #f #f #f))
           (container (qt-widget-create w))
           (win (make-qt-edit-window ed container buf #f #f #f))
           (leaf (make-split-leaf win)))
      (let ((flat (split-tree-flatten leaf)))
        (check (length flat) => 1)
        (check (car flat) => win))
      (qt-text-document-destroy! doc)
      (qt-widget-destroy! w))))

;;; ─── Summary ─────────────────────────────────────────────────────────────────

(newline)
(let ([total (+ *pass* *fail*)])
  (printf "Results: ~a/~a tests passed~n" *pass* total)
  (when (> *fail* 0)
    (printf "FAILED: ~a test(s)~n" *fail*))
  (when (= *fail* 0)
    (display "All tests passed!\n"))
  (flush-output-port (current-output-port))
  (exit (if (zero? *fail*) 0 1)))
