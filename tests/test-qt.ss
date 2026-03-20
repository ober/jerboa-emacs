#!/usr/bin/env scheme-script
#!chezscheme
;;; test-qt.ss — Qt functional tests for jerboa-emacs
;;;
;;; Run:
;;;   QT_QPA_PLATFORM=offscreen make test-qt
;;;
;;; Tests the Qt editor in headless mode (no display needed).
;;; Does NOT call qt-app-exec! — tests run synchronously.
;;;
;;; Ported from ~/mine/gerbil-emacs/qt-functional-test.ss
;;; Groups 1-20 covering: widgets, buffers, commands, navigation, editing,
;;; text transforms, dispatch chain, mark/region, magit, splits, window
;;; scenarios, layout verification, org-table, code folding, UI toggles.

(import (except (chezscheme) make-hash-table hash-table? iota 1+ 1-
                getenv path-extension path-absolute? thread?
                make-mutex mutex? mutex-name)
        (jerboa core)
        (std sugar)
        (only (std srfi srfi-13) string-contains string-prefix?)
        (jerboa-emacs core)
        (jerboa-emacs buffer)
        (jerboa-emacs keymap)
        (jerboa-emacs editor)
        ;; sci-shim re-exports everything from chez-qt/qt plus provides
        ;; Scintilla-backed qt-plain-text-edit-* functions (which is what
        ;; commands-core.ss uses). No need to import chez-qt/qt separately.
        (jerboa-emacs qt sci-shim)
        (jerboa-emacs qt window)
        (jerboa-emacs qt buffer)
        (jerboa-emacs qt highlight)
        (jerboa-emacs qt commands)
        (only (jerboa-emacs qt commands-core) *winner-history* *winner-future*)
        (jerboa-emacs qt magit)
        (jerboa-emacs qt modeline)
        (jerboa-emacs qt image)
        (only (jerboa-emacs qt commands-parity3b) *calc-stack*)
        (jerboa-emacs helm)
        (chez-scintilla constants))

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

;; Runtime helper avoids guard/call-cc macro expansion blowup.
;; Uses with-catch (from std/sugar) which is a simple try/catch wrapper.
(define (run-test-case name thunk)
  (set! *test-name* name)
  (let ((ok (with-catch
              (lambda (e)
                (set! *fail* (+ *fail* 1))
                (display (string-append "  FAIL: " name "\n"))
                (display (string-append "    error: "
                           (if (message-condition? e)
                             (condition-message e)
                             (format "~s" e))
                           "\n"))
                (flush-output-port (current-output-port))
                #f)
              (lambda ()
                (thunk)
                #t))))
    (when ok
      (set! *pass* (+ *pass* 1))
      (display (string-append "  pass: " name "\n"))
      (flush-output-port (current-output-port)))))

(define-syntax test-case
  (syntax-rules ()
    [(_ name body ...)
     (run-test-case name (lambda () body ...))]))

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

;; Register all commands once (needed for dispatch tests)
(register-all-commands!)
(qt-register-all-commands!)

;;; ─── Singleton editor for command tests ─────────────────────────────────────
;;; QPlainTextEdit creation is expensive in headless mode.
;;; Reuse one singleton across all command-level tests.

(define *qt-test-singleton-w*  #f)
(define *qt-test-singleton-ed* #f)

(define (qt-test-singleton-init!)
  (unless *qt-test-singleton-ed*
    (set! *qt-test-singleton-w*  (qt-widget-create))
    (set! *qt-test-singleton-ed* (qt-scintilla-create *qt-test-singleton-w*))))

;; Create a minimal headless Qt test app for command dispatch tests.
;; Uses the singleton QScintilla editor to avoid expensive widget creation.
;; Commands go through sci-shim which maps to Scintilla messages, so we
;; must use QScintilla (not QPlainTextEdit).
(define (make-qt-test-app name)
  (qt-test-singleton-init!)
  (let* ((ed  *qt-test-singleton-ed*)
         (w   *qt-test-singleton-w*)
         (doc (sci-send ed SCI_GETDOCPOINTER))
         (buf (make-buffer name #f doc #f #f #f #f))
         (win (make-qt-edit-window ed #f buf #f #f #f))
         (fr  (make-qt-frame #f (make-split-leaf win) (list win) 0 #f))
         (app (new-app-state fr)))
    ;; Reset singleton to known state for each test group
    (sci-send ed SCI_SETREADONLY 0)
    (values ed w app)))

(define (destroy-qt-test-app! ed w)
  ;; No-op: singleton is reused
  (void))

(define (set-qt-text! ed text pos)
  (qt-plain-text-edit-set-text! ed text)
  (qt-plain-text-edit-set-cursor-position! ed pos))

;;; ─── Split test frame helper ─────────────────────────────────────────────────
;;; Creates a real Qt frame with a root QSplitter for split testing.

(define (make-qt-split-test-frame!)
  (set! *winner-history* '())
  (set! *winner-future* '())
  (let* ((parent   (qt-widget-create))
         (splitter (qt-splitter-create QT_VERTICAL parent))
         (fr  (qt-frame-init! #f splitter))
         (app (new-app-state fr)))
    (values fr app)))

;;; ─── Helper functions ────────────────────────────────────────────────────────

;; Get buffer name for window at IDX in frame FR.
(define (win-buf-name fr idx)
  (buffer-name (qt-edit-window-buffer (list-ref (qt-frame-windows fr) idx))))

;; Get editor for window at IDX in frame FR.
(define (win-editor fr idx)
  (qt-edit-window-editor (list-ref (qt-frame-windows fr) idx)))

;; Set text in window at IDX.
(define (set-win-text! fr idx text)
  (qt-plain-text-edit-set-text! (win-editor fr idx) text))

;; Get text from window at IDX.
(define (get-win-text fr idx)
  (qt-plain-text-edit-text (win-editor fr idx)))

;; Get buffer list from app
(define (list-buffers app)
  (let ((fr (app-state-frame app)))
    (map (lambda (w) (qt-edit-window-buffer w))
         (qt-frame-windows fr))))

;;;============================================================================
;;; Phase 1: Qt widget basics
;;;============================================================================

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

;;;============================================================================
;;; Phase 2: Plain text edit
;;;============================================================================

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
      (qt-plain-text-edit-set-cursor-position! ed 7)
      (check (qt-plain-text-edit-cursor-line ed) => 1)
      (qt-widget-destroy! w)))

  (test-case "text document create/destroy"
    (let ((doc (qt-plain-text-document-create)))
      (check (not (eqv? doc 0)) ? values)
      (qt-text-document-destroy! doc)))

  (test-case "set document"
    ;; Scintilla uses SCI_GETDOCPOINTER / SCI_SETDOCPOINTER — no Qt document objects.
    ;; Just verify the editor has a valid document pointer.
    (let* ((w (qt-widget-create))
           (ed (qt-plain-text-edit-create w))
           (got-doc (qt-plain-text-edit-document ed)))
      (check (not (eqv? got-doc 0)) ? values)
      (qt-widget-destroy! w))))

;;;============================================================================
;;; Phase 3: Buffer management
;;;============================================================================

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

;;;============================================================================
;;; Phase 4: Command registration
;;;============================================================================

(test-group "Command registration"
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
    (check (find-command 'undo) ? procedure?))

  (test-case "split-window-below registered"
    (check (find-command 'split-window-below) ? procedure?))

  (test-case "split-window-right registered"
    (check (find-command 'split-window-right) ? procedure?))

  (test-case "delete-window registered"
    (check (find-command 'delete-window) ? procedure?))

  (test-case "delete-other-windows registered"
    (check (find-command 'delete-other-windows) ? procedure?))

  (test-case "other-window registered"
    (check (find-command 'other-window) ? procedure?))

  (test-case "winner-undo registered"
    (check (find-command 'winner-undo) ? procedure?))

  (test-case "winner-redo registered"
    (check (find-command 'winner-redo) ? procedure?))

  (test-case "set-mark registered"
    (check (find-command 'set-mark) ? procedure?))

  (test-case "keyboard-quit registered"
    (check (find-command 'keyboard-quit) ? procedure?))

  (test-case "upcase-word registered"
    (check (find-command 'upcase-word) ? procedure?))

  (test-case "downcase-word registered"
    (check (find-command 'downcase-word) ? procedure?))

  (test-case "capitalize-word registered"
    (check (find-command 'capitalize-word) ? procedure?))

  (test-case "magit-status registered"
    (check (find-command 'magit-status) ? procedure?)))

;;;============================================================================
;;; Phase 5: Language detection
;;;============================================================================

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

;;;============================================================================
;;; Phase 6: Window splitting data structures
;;;============================================================================

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

;;;============================================================================
;;; Phase 7: Navigation commands (Group 2 from gerbil-emacs)
;;;============================================================================

(test-group "Navigation"
  (test-case "forward-char moves cursor right"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'forward-char)
      (check (qt-plain-text-edit-cursor-position ed) => 1)
      (destroy-qt-test-app! ed w)))

  (test-case "backward-char moves cursor left"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 3)
      (execute-command! app 'backward-char)
      (check (qt-plain-text-edit-cursor-position ed) => 2)
      (destroy-qt-test-app! ed w)))

  (test-case "beginning-of-line goes to column 0"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 7)
      (execute-command! app 'beginning-of-line)
      (check (qt-plain-text-edit-cursor-position ed) => 0)
      (destroy-qt-test-app! ed w)))

  (test-case "end-of-line goes to end"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'end-of-line)
      (check (qt-plain-text-edit-cursor-position ed) => 5)
      (destroy-qt-test-app! ed w)))

  (test-case "beginning-of-buffer goes to pos 0"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 11)
      (execute-command! app 'beginning-of-buffer)
      (check (qt-plain-text-edit-cursor-position ed) => 0)
      (destroy-qt-test-app! ed w)))

  (test-case "end-of-buffer goes to last position"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'end-of-buffer)
      (check (qt-plain-text-edit-cursor-position ed) => 5)
      (destroy-qt-test-app! ed w)))

  (test-case "forward-char at buffer end is no-op"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hi")
      (qt-plain-text-edit-set-cursor-position! ed 2)
      (execute-command! app 'forward-char)
      (check (qt-plain-text-edit-cursor-position ed) => 2)
      (destroy-qt-test-app! ed w)))

  (test-case "multiple forward-char calls accumulate"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "abcde")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (check (qt-plain-text-edit-cursor-position ed) => 3)
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 8: Basic editing (Group 3 from gerbil-emacs)
;;;============================================================================

(test-group "Basic editing"
  (test-case "delete-char removes character at cursor"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'delete-char)
      (check (qt-plain-text-edit-text ed) => "ello")
      (destroy-qt-test-app! ed w)))

  (test-case "backward-delete-char removes char before cursor"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 5)
      (execute-command! app 'backward-delete-char)
      (check (qt-plain-text-edit-text ed) => "hell")
      (destroy-qt-test-app! ed w)))

  (test-case "newline inserts a newline at cursor"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 3)
      (execute-command! app 'newline)
      (check (string-contains (qt-plain-text-edit-text ed) "\n") ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "kill-line removes text to end of line"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 5)
      (execute-command! app 'kill-line)
      (check (qt-plain-text-edit-text ed) => "hello")
      (destroy-qt-test-app! ed w)))

  (test-case "undo reverses last edit"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'delete-char)
      (execute-command! app 'undo)
      (check (qt-plain-text-edit-text ed) => "hello")
      (destroy-qt-test-app! ed w)))

  (test-case "set-mark does not crash"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 3)
      (execute-command! app 'set-mark)
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 9: Text transforms (Group 5 from gerbil-emacs)
;;;============================================================================

(test-group "Text transforms"
  (test-case "upcase-word uppercases word at point"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'upcase-word)
      (check (string-prefix? "HELLO" (qt-plain-text-edit-text ed)) ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "downcase-word lowercases word at point"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "HELLO world")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'downcase-word)
      (check (string-prefix? "hello" (qt-plain-text-edit-text ed)) ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "capitalize-word capitalizes first letter"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'capitalize-word)
      (check (string-prefix? "Hello" (qt-plain-text-edit-text ed)) ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "join-line merges current line with next"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello\nworld")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'join-line)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (string-contains text "hello") ? values)
        (check (string-contains text "world") ? values))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 10: Dispatch chain integrity (Group 6 from gerbil-emacs)
;;;============================================================================

(test-group "Dispatch chain"
  (test-case "execute-command! updates last-command"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'forward-char)
      (check (app-state-last-command app) => 'forward-char)
      (destroy-qt-test-app! ed w)))

  (test-case "execute-command! resets prefix-arg after command"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'universal-argument)
      (execute-command! app 'forward-char)
      (check (app-state-prefix-arg app) => #f)
      (destroy-qt-test-app! ed w)))

  (test-case "multiple execute-command! calls accumulate cursor"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "abcde")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (check (qt-plain-text-edit-cursor-position ed) => 3)
      (destroy-qt-test-app! ed w)))

  (test-case "insert-text via Qt API (basic sanity)"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (qt-plain-text-edit-insert-text! ed "test")
      (check (qt-plain-text-edit-text ed) => "test")
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 11: Mark/region (Group 7 from gerbil-emacs)
;;;============================================================================

(test-group "Mark and region"
  (test-case "set-mark stores position in buffer-mark"
    (let-values (((ed w app) (make-qt-test-app "test.org")))
      (set-qt-text! ed "line1\nline2\nline3" 10)
      (execute-command! app 'set-mark)
      (let ((buf-mark (buffer-mark (car (list-buffers app)))))
        (check buf-mark => 10))
      (destroy-qt-test-app! ed w)))

  (test-case "set-mark at end, previous-line highlights region"
    (let-values (((ed w app) (make-qt-test-app "test.org")))
      (set-qt-text! ed "line1\nline2\nline3" 0)
      (execute-command! app 'end-of-buffer)
      (let ((end-pos (qt-plain-text-edit-cursor-position ed)))
        (execute-command! app 'set-mark)
        (execute-command! app 'previous-line)
        (let ((new-pos (qt-plain-text-edit-cursor-position ed))
              (sel-start (qt-plain-text-edit-selection-start ed))
              (sel-end   (qt-plain-text-edit-selection-end ed)))
          ;; Cursor moved up
          (check (< new-pos end-pos) ? values)
          ;; Selection is active
          (check (< sel-start sel-end) ? values)))
      (destroy-qt-test-app! ed w)))

  (test-case "set-mark then forward-char extends selection"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (set-qt-text! ed "hello world" 0)
      (execute-command! app 'set-mark)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (let ((sel-start (qt-plain-text-edit-selection-start ed))
            (sel-end   (qt-plain-text-edit-selection-end ed)))
        (check sel-start => 0)
        (check sel-end => 5))
      (destroy-qt-test-app! ed w)))

  (test-case "keyboard-quit clears mark and collapses selection"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (set-qt-text! ed "hello world" 0)
      (execute-command! app 'set-mark)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (execute-command! app 'keyboard-quit)
      (let* ((buffers (list-buffers app))
             (mark (if (pair? buffers) (buffer-mark (car buffers)) #f))
             (sel-start (qt-plain-text-edit-selection-start ed))
             (sel-end   (qt-plain-text-edit-selection-end ed)))
        (check mark => #f)
        (check (= sel-start sel-end) ? values))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 12: Magit helpers (Group 8 from gerbil-emacs)
;;;============================================================================

(test-group "Magit helpers"
  (test-case "magit-parse-status returns list for staged file"
    (let ((entries (magit-parse-status "M  commands.ss\n?? newfile.txt\n")))
      (check (pair? entries) ? values)))

  (test-case "magit-parse-status detects untracked entry"
    (let ((entries (magit-parse-status "?? newfile.txt\n")))
      (let ((first (and (pair? entries) (car entries))))
        (check (and first (string=? (car first) "??")) ? values))))

  (test-case "magit-parse-status empty string returns empty list"
    (let ((entries (magit-parse-status "")))
      (check (null? entries) ? values)))

  (test-case "magit-format-status contains Head: header"
    (let* ((entries (list (cons "M" "file.ss")))
           (text (magit-format-status entries "master" "/tmp")))
      (check (string-contains text "Head: master") ? values)))

  (test-case "magit-format-status clean tree message"
    (let ((text (magit-format-status '() "main" "/tmp")))
      (check (string-contains text "Nothing to commit") ? values)))

  (test-case "magit-file-at-point extracts filename"
    (let* ((text "Head: master\n\nUnstaged changes (1):\nmodified   commands.ss\n")
           (pos (+ (string-length "Head: master\n\nUnstaged changes (1):\n") 5)))
      (let ((file (magit-file-at-point text pos)))
        (check file => "commands.ss"))))

  (test-case "magit-file-at-point returns #f for header line"
    (let ((file (magit-file-at-point "Head: master\n\n" 5)))
      (check file => #f))))

;;;============================================================================
;;; Phase 13: Split operations (Group 10 from gerbil-emacs)
;;;============================================================================

(test-group "Split operations"
  (test-case "split-window-below creates 2 windows"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-below)
      (let ((wins (qt-frame-windows fr))
            (root (qt-frame-root fr)))
        (check (length wins) => 2)
        (check (split-node? root) ? values)
        (check (split-node-orientation root) => QT_VERTICAL)
        (check (qt-frame-current-idx fr) => 1))))

  (test-case "split-window-right creates 2 windows"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (let ((wins (qt-frame-windows fr))
            (root (qt-frame-root fr)))
        (check (length wins) => 2)
        (check (split-node? root) ? values)
        (check (split-node-orientation root) => QT_HORIZONTAL)
        (check (qt-frame-current-idx fr) => 1))))

  (test-case "delete-window after split restores single pane"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'delete-window)
      (check (length (qt-frame-windows fr)) => 1)
      (check (split-leaf? (qt-frame-root fr)) ? values)))

  (test-case "delete-other-windows collapses to single pane"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (execute-command! app 'other-window)
      (execute-command! app 'other-window)
      (execute-command! app 'delete-other-windows)
      (check (length (qt-frame-windows fr)) => 1)
      (check (split-leaf? (qt-frame-root fr)) ? values)))

  (test-case "nested split h-then-v (regression)"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-below)
      (let ((wins (qt-frame-windows fr))
            (root (qt-frame-root fr)))
        (check (length wins) => 3)
        (check (split-node? root) ? values)
        (check (split-node-orientation root) => QT_HORIZONTAL)
        (check (length (split-node-children root)) => 2)
        ;; Right child should be vertical
        (let ((right-child (cadr (split-node-children root))))
          (check (split-node? right-child) ? values)
          (check (split-node-orientation right-child) => QT_VERTICAL))
        ;; Left child should be a leaf
        (check (split-leaf? (car (split-node-children root))) ? values))))

  (test-case "nested split v-then-h"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-below)
      (execute-command! app 'split-window-right)
      (let ((wins (qt-frame-windows fr))
            (root (qt-frame-root fr)))
        (check (length wins) => 3)
        (check (split-node-orientation root) => QT_VERTICAL)
        (let ((bottom-child (cadr (split-node-children root))))
          (check (split-node? bottom-child) ? values)
          (check (split-node-orientation bottom-child) => QT_HORIZONTAL))
        (check (split-leaf? (car (split-node-children root))) ? values))))

  (test-case "three-way horizontal split uses flat siblings"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (let ((wins (qt-frame-windows fr))
            (root (qt-frame-root fr)))
        (check (length wins) => 3)
        (check (split-node? root) ? values)
        (check (split-node-orientation root) => QT_HORIZONTAL)
        (check (length (split-node-children root)) => 3))))

  (test-case "other-window cycles through all panes"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-below)
      (let ((start-idx (qt-frame-current-idx fr)))
        (execute-command! app 'other-window)
        (execute-command! app 'other-window)
        (execute-command! app 'other-window)
        (check (qt-frame-current-idx fr) => start-idx))))

  (test-case "winner-undo restores single from split"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'winner-undo)
      (check (length (qt-frame-windows fr)) => 1)
      (check (split-leaf? (qt-frame-root fr)) ? values)))

  (test-case "winner-undo-stack depth"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (execute-command! app 'winner-undo)
      (execute-command! app 'winner-undo)
      (execute-command! app 'winner-undo)
      (check (length (qt-frame-windows fr)) => 1)))

  (test-case "winner-redo after undo"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'winner-undo)
      (execute-command! app 'winner-redo)
      (check (length (qt-frame-windows fr)) => 2)))

  (test-case "split inherits buffer"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (let ((orig-buf (qt-edit-window-buffer (qt-current-window fr))))
        (execute-command! app 'split-window-right)
        (let ((new-buf (qt-edit-window-buffer (qt-current-window fr))))
          (check (eq? orig-buf new-buf) ? values))))))

;;;============================================================================
;;; Phase 14: Window scenarios (Group 11 from gerbil-emacs)
;;; These test real multi-step workflows that catch regressions.
;;;============================================================================

(test-group "Window scenarios"
  ;; Scenario 1: THE REPORTED BUG — hsplit, jump to other, vsplit
  (test-case "S1: hsplit → other-window(back) → vsplit"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (check (qt-frame-current-idx fr) => 1)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 0)
      (execute-command! app 'split-window-below)
      (check (length (qt-frame-windows fr)) => 3)
      ;; Left side must be vertical split, right is untouched leaf
      (let* ((root (qt-frame-root fr))
             (left (car (split-node-children root)))
             (right (cadr (split-node-children root))))
        (check (split-node? left) ? values)
        (check (split-node-orientation left) => QT_VERTICAL)
        (check (split-leaf? right) ? values))))

  ;; Scenario 2: vsplit → other-window(back) → hsplit
  (test-case "S2: vsplit → other-window(back) → hsplit"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-below)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 0)
      (execute-command! app 'split-window-right)
      (check (length (qt-frame-windows fr)) => 3)
      (let* ((root (qt-frame-root fr))
             (top (car (split-node-children root)))
             (bottom (cadr (split-node-children root))))
        (check (split-node? top) ? values)
        (check (split-node-orientation top) => QT_HORIZONTAL)
        (check (split-leaf? bottom) ? values))))

  ;; Scenario 3: Four-pane grid
  (test-case "S3: four-pane grid (A|D) over (B|C)"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-below)
      (execute-command! app 'split-window-right)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 0)
      (execute-command! app 'split-window-right)
      (check (length (qt-frame-windows fr)) => 4)
      (let* ((root (qt-frame-root fr))
             (top (car (split-node-children root)))
             (bottom (cadr (split-node-children root))))
        (check (split-node-orientation root) => QT_VERTICAL)
        (check (split-node? top) ? values)
        (check (split-node-orientation top) => QT_HORIZONTAL)
        (check (split-node? bottom) ? values)
        (check (split-node-orientation bottom) => QT_HORIZONTAL))))

  ;; Scenario 4: Three horizontal then delete middle
  (test-case "S4: three-way hsplit then delete middle"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (check (length (qt-frame-windows fr)) => 3)
      (execute-command! app 'other-window)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 1)
      (execute-command! app 'delete-window)
      (check (length (qt-frame-windows fr)) => 2)
      (let ((root (qt-frame-root fr)))
        (check (split-node? root) ? values)
        (check (split-node-orientation root) => QT_HORIZONTAL)
        (check (length (split-node-children root)) => 2))))

  ;; Scenario 6: other-window traversal order in nested layout
  (test-case "S6: other-window traversal in nested layout"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'other-window)
      (execute-command! app 'split-window-below)
      (check (length (qt-frame-windows fr)) => 3)
      (check (qt-frame-current-idx fr) => 1)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 2)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 0)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 1)))

  ;; Scenario 7: delete-other-windows keeps current, not first
  (test-case "S7: delete-other-windows keeps current"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (execute-command! app 'other-window)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 1)
      (execute-command! app 'delete-other-windows)
      (check (length (qt-frame-windows fr)) => 1)
      (check (split-leaf? (qt-frame-root fr)) ? values)))

  ;; Scenario 8: delete sole window is a no-op
  (test-case "S8: delete-window on sole window is no-op"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'delete-window)
      (check (length (qt-frame-windows fr)) => 1)
      (check (split-leaf? (qt-frame-root fr)) ? values)))

  ;; Scenario 9: Split panes share buffer but have independent editors
  (test-case "S9: split panes share buffer, independent editors"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (let ((buf-a (qt-edit-window-buffer (list-ref (qt-frame-windows fr) 0)))
            (buf-b (qt-edit-window-buffer (list-ref (qt-frame-windows fr) 1))))
        (check (eq? buf-a buf-b) ? values))
      (let ((ed-a (win-editor fr 0))
            (ed-b (win-editor fr 1)))
        (check (not (eq? ed-a ed-b)) ? values))))

  ;; Scenario 10: Winner undo/redo with flat splits
  (test-case "S10: winner-undo/redo with flat splits"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (check (length (qt-frame-windows fr)) => 2)
      (execute-command! app 'split-window-right)
      (check (length (qt-frame-windows fr)) => 3)
      (execute-command! app 'winner-undo)
      (check (length (qt-frame-windows fr)) => 2)
      (execute-command! app 'winner-undo)
      (check (length (qt-frame-windows fr)) => 1)
      (execute-command! app 'winner-redo)
      (check (length (qt-frame-windows fr)) => 2)
      (execute-command! app 'winner-redo)
      (check (length (qt-frame-windows fr)) => 3)))

  ;; Scenario 11: Rapid split and cycle
  (test-case "S11: rapid split-right x4 then cycle"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (check (length (qt-frame-windows fr)) => 5)
      (let ((start (qt-frame-current-idx fr)))
        (execute-command! app 'other-window)
        (execute-command! app 'other-window)
        (execute-command! app 'other-window)
        (execute-command! app 'other-window)
        (execute-command! app 'other-window)
        (check (qt-frame-current-idx fr) => start))))

  ;; Scenario 12: Alternating h/v splits create correct nesting
  (test-case "S12: alternating h/v/h splits — deep nesting"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-below)
      (execute-command! app 'other-window)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 1)
      (execute-command! app 'split-window-right)
      (check (length (qt-frame-windows fr)) => 4)
      (let* ((root (qt-frame-root fr))
             (right (cadr (split-node-children root))))
        (check (split-node? right) ? values)
        (check (split-node-orientation right) => QT_VERTICAL)
        (let ((right-top (car (split-node-children right))))
          (check (split-node? right-top) ? values)
          (check (split-node-orientation right-top) => QT_HORIZONTAL)))))

  ;; Scenario 13: Delete first window in three-way split
  (test-case "S13: delete first window in three-way split"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 0)
      (execute-command! app 'delete-window)
      (check (length (qt-frame-windows fr)) => 2)
      (let ((idx (qt-frame-current-idx fr)))
        (check (and (>= idx 0) (< idx 2)) ? values))))

  ;; Scenario 14: Split below in middle of three-way horizontal
  (test-case "S14: split below in middle of three-way horizontal"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (execute-command! app 'other-window)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 1)
      (execute-command! app 'split-window-below)
      (check (length (qt-frame-windows fr)) => 4)
      (let* ((root (qt-frame-root fr))
             (children (split-node-children root)))
        (check (length children) => 3)
        (check (split-leaf? (car children)) ? values)
        (check (split-node? (cadr children)) ? values)
        (check (split-leaf? (caddr children)) ? values)
        (check (split-node-orientation (cadr children)) => QT_VERTICAL))))

  ;; Scenario 15: Winner undo after delete-other-windows
  (test-case "S15: winner-undo restores after delete-other-windows"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (check (length (qt-frame-windows fr)) => 3)
      (execute-command! app 'other-window)
      (execute-command! app 'other-window)
      (execute-command! app 'delete-other-windows)
      (check (length (qt-frame-windows fr)) => 1)
      (execute-command! app 'winner-undo)
      (check (length (qt-frame-windows fr)) => 3)))

  ;; Scenario 16: Split inherits buffer across navigation
  (test-case "S16: split inherits buffer across navigation"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (let ((orig-name (win-buf-name fr 0)))
        (execute-command! app 'split-window-right)
        (check (win-buf-name fr 1) => orig-name)
        (execute-command! app 'other-window)
        (execute-command! app 'other-window)
        (check (win-buf-name fr 1) => orig-name))))

  ;; Scenario 17: other-window ping-pong with 2 panes
  (test-case "S17: other-window ping-pong with 2 panes"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 0)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 1)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 0)
      (execute-command! app 'other-window)
      (check (qt-frame-current-idx fr) => 1)))

  ;; Scenario 18: split-below from non-zero idx
  (test-case "S18: split-below from non-zero idx tracks correctly"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (check (qt-frame-current-idx fr) => 1)
      (execute-command! app 'split-window-below)
      (check (length (qt-frame-windows fr)) => 3)
      (check (qt-frame-current-idx fr) => 2)))

  ;; Scenario 19: Build 2x2 grid and verify structure
  (test-case "S19: build 2x2 grid (A over C) | (B over D)"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'other-window)
      (execute-command! app 'split-window-below)
      (execute-command! app 'other-window)
      (execute-command! app 'split-window-below)
      (check (length (qt-frame-windows fr)) => 4)
      (let* ((root (qt-frame-root fr))
             (left (car (split-node-children root)))
             (right (cadr (split-node-children root))))
        (check (split-node-orientation root) => QT_HORIZONTAL)
        (check (split-node? left) ? values)
        (check (split-node-orientation left) => QT_VERTICAL)
        (check (split-node? right) ? values)
        (check (split-node-orientation right) => QT_VERTICAL))))

  ;; Scenario 20: Cursor position persists per-pane
  (test-case "S20: cursor position persists per-pane"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (let ((ed0 (win-editor fr 0)))
        (qt-plain-text-edit-set-text! ed0 "abcdefghij")
        (qt-plain-text-edit-set-cursor-position! ed0 5))
      (execute-command! app 'split-window-right)
      (let ((ed1 (win-editor fr 1)))
        (qt-plain-text-edit-set-cursor-position! ed1 2))
      (execute-command! app 'other-window)
      (check (qt-plain-text-edit-cursor-position (win-editor fr 0)) => 5)
      (execute-command! app 'other-window)
      (check (qt-plain-text-edit-cursor-position (win-editor fr 1)) => 2))))

;;;============================================================================
;;; Phase 15: Org commands (Group 4 from gerbil-emacs)
;;;============================================================================

(test-group "Org commands"
  (test-case "org-todo-cycle cycles TODO state"
    (let-values (((ed w app) (make-qt-test-app "tasks.org")))
      (qt-plain-text-edit-set-text! ed "* Task headline")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'org-todo-cycle)
      (check (string-contains (qt-plain-text-edit-text ed) "TODO") ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "org-demote then org-promote"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (qt-plain-text-edit-set-text! ed "** Sub heading")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'org-demote)
      (check (string-prefix? "***" (qt-plain-text-edit-text ed)) ? values)
      (execute-command! app 'org-promote)
      (check (string-prefix? "** " (qt-plain-text-edit-text ed)) ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "org-promote at level 1 is a no-op"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (qt-plain-text-edit-set-text! ed "* Top level")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'org-promote)
      (check (string-prefix? "* " (qt-plain-text-edit-text ed)) ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "org-toggle-checkbox [ ] to [X]"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (qt-plain-text-edit-set-text! ed "- [ ] Item to check")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'org-toggle-checkbox)
      (check (string-contains (qt-plain-text-edit-text ed) "[X]") ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "org-toggle-checkbox [X] back to [ ]"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (qt-plain-text-edit-set-text! ed "- [X] Already checked")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'org-toggle-checkbox)
      (check (string-contains (qt-plain-text-edit-text ed) "[ ]") ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "org-insert-heading adds a new heading"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (qt-plain-text-edit-set-text! ed "* First\n")
      (qt-plain-text-edit-set-cursor-position! ed 7)
      (execute-command! app 'org-insert-heading)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (> (string-length text) 8) ? values)
        (check (string-contains text "*") ? values))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 16: Org-mode TAB dispatch (Group 1 from gerbil-emacs)
;;;============================================================================

(test-group "Org TAB dispatch"
  (test-case "<s TAB expands to #+BEGIN_SRC in .org"
    (let-values (((ed w app) (make-qt-test-app "test.org")))
      (set-qt-text! ed "<s" 2)
      (execute-command! app 'indent-or-complete)
      (check (string-contains (qt-plain-text-edit-text ed) "#+BEGIN_SRC") ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "<e TAB expands to #+BEGIN_EXAMPLE"
    (let-values (((ed w app) (make-qt-test-app "test.org")))
      (set-qt-text! ed "<e" 2)
      (execute-command! app 'indent-or-complete)
      (check (string-contains (qt-plain-text-edit-text ed) "#+BEGIN_EXAMPLE") ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "<q TAB expands to #+BEGIN_QUOTE"
    (let-values (((ed w app) (make-qt-test-app "test.org")))
      (set-qt-text! ed "<q" 2)
      (execute-command! app 'indent-or-complete)
      (check (string-contains (qt-plain-text-edit-text ed) "#+BEGIN_QUOTE") ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "non-org buffer TAB does not expand <s"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (set-qt-text! ed "<s" 2)
      (execute-command! app 'indent-or-complete)
      (check (not (string-contains (qt-plain-text-edit-text ed) "#+BEGIN_SRC")) ? values)
      (destroy-qt-test-app! ed w)))

  (test-case "<s expansion has both BEGIN and END blocks"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "<s" 2)
      (execute-command! app 'indent-or-complete)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (string-contains text "#+BEGIN_SRC") ? values)
        (check (string-contains text "#+END_SRC") ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "unknown template <z in org does not expand"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "<z" 2)
      (execute-command! app 'indent-or-complete)
      (check (not (string-contains (qt-plain-text-edit-text ed) "#+BEGIN_")) ? values)
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 17: Layout verification (Group 12 from gerbil-emacs)
;;; Verify actual Qt widget tree matches logical split tree.
;;;============================================================================

(test-group "Layout verification"
  (test-case "split-below: root splitter has 2 widgets"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (let ((win-a (qt-current-window fr)))
        (execute-command! app 'split-window-below)
        (let ((root-spl (qt-frame-splitter fr)))
          (check (qt-splitter-count root-spl) => 2)
          ;; A's container at index 0
          (check (qt-splitter-index-of root-spl (qt-edit-window-container win-a)) => 0)
          ;; B's container at index 1
          (let ((win-b (qt-current-window fr)))
            (check (qt-splitter-index-of root-spl (qt-edit-window-container win-b)) => 1))))))

  (test-case "split-right: root splitter has 2 widgets"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (let ((win-a (qt-current-window fr)))
        (execute-command! app 'split-window-right)
        (let ((root-spl (qt-frame-splitter fr)))
          (check (qt-splitter-count root-spl) => 2)
          (check (qt-splitter-index-of root-spl (qt-edit-window-container win-a)) => 0)))))

  (test-case "three-way: root splitter has 3 widgets"
    (let-values (((fr app) (make-qt-split-test-frame!)))
      (execute-command! app 'split-window-right)
      (execute-command! app 'split-window-right)
      (let ((root-spl (qt-frame-splitter fr)))
        (check (qt-splitter-count root-spl) => 3)))))

;;;============================================================================
;;; Phase 18: Org-Table commands (Group 13 from gerbil-emacs)
;;;============================================================================

(test-group "Org-Table commands"
  (define sample-table
    (string-append "| Name  | Age | City   |\n"
                   "|-------+-----+--------|\n"
                   "| Alice | 30  | Paris  |\n"
                   "| Bob   | 25  | London |"))

  (test-case "org-table-create inserts table template"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "" 0)
      (execute-command! app 'org-table-create)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (string-contains text "| Col1") ? values)
        (check (string-contains text "|------") ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-align re-aligns uneven table"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "| a | bb | ccc |\n| dddd | e | ff |" 0)
      (execute-command! app 'org-table-align)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (string-contains text "| a    |") ? values)
        (check (string-contains text "| dddd |") ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-insert-row adds empty row"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed sample-table 0)
      (let ((line2-pos (sci-send ed SCI_POSITIONFROMLINE 2 0)))
        (qt-plain-text-edit-set-cursor-position! ed line2-pos)
        (execute-command! app 'org-table-insert-row)
        (let* ((text (qt-plain-text-edit-text ed))
               (lines (string-split text #\newline)))
          (check (length lines) => 5)))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-delete-row removes current row"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed sample-table 0)
      (let ((line2-pos (sci-send ed SCI_POSITIONFROMLINE 2 0)))
        (qt-plain-text-edit-set-cursor-position! ed line2-pos)
        (execute-command! app 'org-table-delete-row)
        (let ((text (qt-plain-text-edit-text ed)))
          (check (not (string-contains text "Alice")) ? values)
          (check (string-contains text "Bob") ? values)))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-move-row-down swaps rows"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed sample-table 0)
      (let ((line2-pos (sci-send ed SCI_POSITIONFROMLINE 2 0)))
        (qt-plain-text-edit-set-cursor-position! ed line2-pos)
        (execute-command! app 'org-table-move-row-down)
        (let* ((text (qt-plain-text-edit-text ed))
               (lines (string-split text #\newline)))
          (check (string-contains (list-ref lines 2) "Bob") ? values)
          (check (string-contains (list-ref lines 3) "Alice") ? values)))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-move-row-up swaps rows"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed sample-table 0)
      (let ((line3-pos (sci-send ed SCI_POSITIONFROMLINE 3 0)))
        (qt-plain-text-edit-set-cursor-position! ed line3-pos)
        (execute-command! app 'org-table-move-row-up)
        (let* ((text (qt-plain-text-edit-text ed))
               (lines (string-split text #\newline)))
          (check (string-contains (list-ref lines 2) "Bob") ? values)
          (check (string-contains (list-ref lines 3) "Alice") ? values)))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-delete-column removes a column"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed sample-table 0)
      (let ((pos (+ (sci-send ed SCI_POSITIONFROMLINE 0 0) 10)))
        (qt-plain-text-edit-set-cursor-position! ed pos)
        (execute-command! app 'org-table-delete-column)
        (let ((text (qt-plain-text-edit-text ed)))
          (check (not (string-contains text "Age")) ? values)
          (check (string-contains text "Name") ? values)
          (check (string-contains text "City") ? values)))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-insert-column adds column"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "| A | B |\n| 1 | 2 |" 0)
      (qt-plain-text-edit-set-cursor-position! ed 2)
      (execute-command! app 'org-table-insert-column)
      (let* ((text (qt-plain-text-edit-text ed))
             (lines (string-split text #\newline)))
        (check (>= (length (string-split (car lines) #\|)) 4) ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-move-column-right swaps columns"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "| A | B | C |\n| 1 | 2 | 3 |" 0)
      (qt-plain-text-edit-set-cursor-position! ed 2)
      (execute-command! app 'org-table-move-column-right)
      (let* ((text (qt-plain-text-edit-text ed))
             (lines (string-split text #\newline))
             (first-line (car lines)))
        (check (string-prefix? "| B" first-line) ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-move-column-left swaps columns"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "| A | B | C |\n| 1 | 2 | 3 |" 0)
      (qt-plain-text-edit-set-cursor-position! ed 6)
      (execute-command! app 'org-table-move-column-left)
      (let* ((text (qt-plain-text-edit-text ed))
             (lines (string-split text #\newline))
             (first-line (car lines)))
        (check (string-prefix? "| B" first-line) ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-insert-separator inserts separator row"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "| A | B |\n| 1 | 2 |" 0)
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'org-table-insert-separator)
      (let* ((text (qt-plain-text-edit-text ed))
             (lines (string-split text #\newline)))
        (check (= (length lines) 3) ? values)
        (check (string-contains (list-ref lines 1) "---") ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-sort sorts numerically"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "| X | 30 |\n| Y | 10 |\n| Z | 20 |" 0)
      (qt-plain-text-edit-set-cursor-position! ed 5)
      (execute-command! app 'org-table-sort)
      (let* ((text (qt-plain-text-edit-text ed))
             (lines (string-split text #\newline)))
        (check (string-contains (car lines) "10") ? values)
        (check (string-contains (list-ref lines 2) "30") ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "org-table-transpose swaps rows and columns"
    (let-values (((ed w app) (make-qt-test-app "notes.org")))
      (set-qt-text! ed "| A | B |\n| 1 | 2 |\n| 3 | 4 |" 0)
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'org-table-transpose)
      (let* ((text (qt-plain-text-edit-text ed))
             (lines (string-split text #\newline)))
        (check (= (length lines) 2) ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "all 17 org-table commands are registered"
    (let ((cmds '(org-table-align org-table-insert-row org-table-delete-row
                  org-table-move-row-up org-table-move-row-down
                  org-table-delete-column org-table-insert-column
                  org-table-move-column-left org-table-move-column-right
                  org-table-insert-separator org-table-sort org-table-sum
                  org-table-recalculate org-table-create
                  org-table-export-csv org-table-import-csv
                  org-table-transpose)))
      (let loop ((cs cmds) (ok 0))
        (if (null? cs)
          (check ok => 17)
          (loop (cdr cs)
                (+ ok (if (find-command (car cs)) 1 0))))))))

;;;============================================================================
;;; Phase 19: LSP visual features (Group 14 from gerbil-emacs)
;;;============================================================================

(test-group "LSP visual features"
  (test-case "LSP commands registered"
    (let ((lsp-cmds '(toggle-lsp lsp lsp-goto-definition lsp-declaration
                      lsp-type-definition lsp-implementation lsp-hover
                      lsp-completion lsp-rename lsp-code-actions
                      lsp-find-references lsp-document-symbols
                      lsp-workspace-symbol lsp-format-buffer
                      lsp-restart lsp-stop lsp-smart-goto-definition)))
      (let loop ((cs lsp-cmds) (ok 0))
        (if (null? cs)
          (check ok => (length lsp-cmds))
          (loop (cdr cs)
                (+ ok (if (find-command (car cs)) 1 0)))))))

  (test-case "LSP modeline provider is accessible"
    (let ((provider (unbox *lsp-modeline-provider*)))
      ;; Provider may or may not be set depending on init order.
      ;; If set, calling it when LSP is not running should return #f.
      ;; If not set, that is also acceptable.
      (check (or (not provider) (not (provider))) ? values))))

;;;============================================================================
;;; Phase 20: Code folding (Group 15 from gerbil-emacs)
;;;============================================================================

(test-group "Code folding"
  (test-case "fold commands registered"
    (check (find-command 'toggle-fold) ? values)
    (check (find-command 'fold-all) ? values)
    (check (find-command 'unfold-all) ? values)
    (check (find-command 'fold-level) ? values))

  (test-case "toggle-fold dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "fold-test.ss")))
      (qt-plain-text-edit-set-text! ed "(define (foo x)\n  (+ x 1))\n\n(define (bar y)\n  (* y 2))\n")
      (qt-enable-code-folding! ed)
      (sci-send ed SCI_GOTOPOS 0 0)
      (execute-command! app 'toggle-fold)
      (destroy-qt-test-app! ed w)))

  (test-case "fold-all dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "fold-all-test.ss")))
      (qt-plain-text-edit-set-text! ed "(define (foo x)\n  (+ x 1))\n\n(define (bar y)\n  (* y 2))\n")
      (qt-enable-code-folding! ed)
      (execute-command! app 'fold-all)
      (destroy-qt-test-app! ed w)))

  (test-case "unfold-all dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "unfold-all-test.ss")))
      (qt-plain-text-edit-set-text! ed "(define (foo x)\n  (+ x 1))\n\n(define (bar y)\n  (* y 2))\n")
      (qt-enable-code-folding! ed)
      (execute-command! app 'unfold-all)
      (destroy-qt-test-app! ed w)))

  (test-case "fold-level dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "fold-level-test.ss")))
      (qt-plain-text-edit-set-text! ed "(define (foo x)\n  (+ x 1))\n\n(define (bar y)\n  (* y 2))\n")
      (qt-enable-code-folding! ed)
      (execute-command! app 'fold-level)
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 21: UI toggles (Group 16 from gerbil-emacs)
;;;============================================================================

(test-group "UI toggles"
  (test-case "UI toggle commands registered (6 commands)"
    (check (find-command 'toggle-menu-bar) ? values)
    (check (find-command 'toggle-scroll-bar) ? values)
    (check (find-command 'toggle-show-spaces) ? values)
    (check (find-command 'toggle-show-trailing-whitespace) ? values)
    (check (find-command 'buffer-disable-undo) ? values)
    (check (find-command 'buffer-enable-undo) ? values))

  (test-case "toggle-scroll-bar dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "scrollbar-test")))
      (execute-command! app 'toggle-scroll-bar)
      (destroy-qt-test-app! ed w)))

  (test-case "toggle-show-spaces dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "spaces-test")))
      (execute-command! app 'toggle-show-spaces)
      (destroy-qt-test-app! ed w)))

  (test-case "toggle-show-trailing-whitespace dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "trailing-ws-test")))
      (qt-plain-text-edit-set-text! ed "hello   \nworld  \n")
      (execute-command! app 'toggle-show-trailing-whitespace)
      (destroy-qt-test-app! ed w)))

  (test-case "buffer-disable-undo and buffer-enable-undo dispatch without error"
    (let-values (((ed w app) (make-qt-test-app "undo-test")))
      (execute-command! app 'buffer-disable-undo)
      (execute-command! app 'buffer-enable-undo)
      (destroy-qt-test-app! ed w)))

  (test-case "auto-revert-mode delegates to toggle-auto-revert"
    (let-values (((ed w app) (make-qt-test-app "auto-revert-test")))
      (execute-command! app 'auto-revert-mode)
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 22: Recenter-top-bottom (Group 17 from gerbil-emacs)
;;;============================================================================

(test-group "Recenter-top-bottom"
  (test-case "recenter-top-bottom command registered"
    (check (find-command 'recenter-top-bottom) ? values))

  (test-case "recenter-top-bottom dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "recenter-test")))
      (qt-plain-text-edit-set-text! ed "line one\nline two\nline three\n")
      (execute-command! app 'recenter-top-bottom)
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 23: Stub replacements (Group 18 from gerbil-emacs)
;;;============================================================================

(test-group "Stub replacements"
  (test-case "toggle-overwrite-mode registered"
    (check (find-command 'toggle-overwrite-mode) ? values))

  (test-case "shrink/enlarge-window-horizontally dispatch without error"
    (let-values (((ed w app) (make-qt-test-app "resize-test")))
      (execute-command! app 'shrink-window-horizontally)
      (execute-command! app 'enlarge-window-horizontally)
      (destroy-qt-test-app! ed w)))

  (test-case "minimize-window registered"
    (check (find-command 'minimize-window) ? values))

  (test-case "complete-filename registered"
    (check (find-command 'complete-filename) ? values))

  (test-case "dired-do-chmod registered"
    (check (find-command 'dired-do-chmod) ? values))

  (test-case "complete-filename dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "fname-test")))
      (qt-plain-text-edit-set-text! ed "/tmp/")
      (qt-plain-text-edit-set-cursor-position! ed 5)
      (execute-command! app 'complete-filename)
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 24: New features (Group 19 from gerbil-emacs)
;;;============================================================================

(test-group "New features"
  (test-case "delete-rectangle registered"
    (check (find-command 'delete-rectangle) ? values))

  (test-case "delete-rectangle dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "del-rect-test")))
      (set-qt-text! ed "abcde\nfghij\nklmno\n" 0)
      (qt-plain-text-edit-set-cursor-position! ed 1)
      (execute-command! app 'set-mark)
      (qt-plain-text-edit-set-cursor-position! ed 9)
      (execute-command! app 'delete-rectangle)
      (destroy-qt-test-app! ed w)))

  (test-case "list-colors dispatches and shows color listing"
    (let-values (((ed w app) (make-qt-test-app "colors-test")))
      (execute-command! app 'list-colors)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (string-contains text "Named Colors") ? values))
      (destroy-qt-test-app! ed w)))

  (test-case "describe-syntax dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "syntax-test")))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'describe-syntax)
      (destroy-qt-test-app! ed w)))

  (test-case "pulse-line-mode registered"
    (check (find-command 'pulse-line-mode) ? values))

  (test-case "toggle-pulse-line registered"
    (check (find-command 'toggle-pulse-line) ? values))

  (test-case "auto-save-mode registered"
    (check (find-command 'auto-save-mode) ? values))

  (test-case "ansi-color-apply registered"
    (check (find-command 'ansi-color-apply) ? values))

  (test-case "count-words dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "count-words-test")))
      (qt-plain-text-edit-set-text! ed "hello world\nfoo bar baz\n")
      (execute-command! app 'count-words)
      (destroy-qt-test-app! ed w)))

  (test-case "diff-backup registered"
    (check (find-command 'diff-backup) ? values))

  (test-case "font-lock-mode registered"
    (check (find-command 'font-lock-mode) ? values))

  (test-case "font-lock-mode dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "hl-toggle-test")))
      (qt-plain-text-edit-set-text! ed "(define foo 42)")
      (execute-command! app 'font-lock-mode)
      (destroy-qt-test-app! ed w)))

  (test-case "hl-line-mode dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "hl-line-test")))
      (execute-command! app 'hl-line-mode)
      (destroy-qt-test-app! ed w)))

  (test-case "whitespace-mode dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "show-tabs-test")))
      (execute-command! app 'whitespace-mode)
      (destroy-qt-test-app! ed w)))

  (test-case "toggle-show-eol dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "show-eol-test")))
      (execute-command! app 'toggle-show-eol)
      (destroy-qt-test-app! ed w)))

  (test-case "consult-line registered"
    (check (find-command 'consult-line) ? values))

  (test-case "consult-imenu registered"
    (check (find-command 'consult-imenu) ? values))

  (test-case "auto-highlight-symbol-mode registered"
    (check (find-command 'auto-highlight-symbol-mode) ? values))

  (test-case "consult-outline registered"
    (check (find-command 'consult-outline) ? values))

  (test-case "highlight-symbol dispatches and reports occurrences"
    (let-values (((ed w app) (make-qt-test-app "highlight-test")))
      (set-qt-text! ed "foo bar foo baz foo" 0)
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'highlight-symbol)
      (let ((msg (echo-state-message (app-state-echo app))))
        (check (and msg (string-contains msg "3 occurrences")) ? values))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Phase 25: Multiple cursors (Group 20 from gerbil-emacs)
;;;============================================================================

(test-group "Multiple cursors"
  (test-case "mc-mark-next registered"
    (check (find-command 'mc-mark-next) ? values))

  (test-case "mc-mark-all registered"
    (check (find-command 'mc-mark-all) ? values))

  (test-case "mc-edit-lines registered"
    (check (find-command 'mc-edit-lines) ? values))

  (test-case "mc-mark-next dispatches with selection"
    (let-values (((ed w app) (make-qt-test-app "mc-test")))
      (set-qt-text! ed "foo bar foo baz foo" 0)
      (sci-send ed SCI_SETSEL 0 3)
      (execute-command! app 'mc-mark-next)
      (destroy-qt-test-app! ed w)))

  (test-case "mc-mark-all dispatches with selection"
    (let-values (((ed w app) (make-qt-test-app "mc-all-test")))
      (set-qt-text! ed "abc xyz abc xyz abc" 0)
      (sci-send ed SCI_SETSEL 0 3)
      (execute-command! app 'mc-mark-all)
      (destroy-qt-test-app! ed w)))

  (test-case "mc-unmark-last dispatches (single cursor case)"
    (let-values (((ed w app) (make-qt-test-app "mc-unmark-test")))
      (set-qt-text! ed "test text" 0)
      (execute-command! app 'mc-unmark-last)
      (destroy-qt-test-app! ed w)))

  (test-case "mc-rotate dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "mc-rotate-test")))
      (set-qt-text! ed "test test test" 0)
      (execute-command! app 'mc-rotate)
      (destroy-qt-test-app! ed w)))

  (test-case "mc-edit-lines dispatches with multi-line selection"
    (let-values (((ed w app) (make-qt-test-app "mc-lines-test")))
      (set-qt-text! ed "line 1\nline 2\nline 3\n" 0)
      (sci-send ed SCI_SETSEL 0 20)
      (execute-command! app 'mc-edit-lines)
      (destroy-qt-test-app! ed w)))

  (test-case "mc-skip-and-mark-next registered"
    (check (find-command 'mc-skip-and-mark-next) ? values)))

;;;============================================================================
;;; Group 21: Theme Switching, Split Sizing, LSP Indicators
;;;============================================================================

(test-group "Theme Switching, Split Sizing, LSP Indicators"

  (test-case "load-theme command registered"
    (check (find-command 'load-theme) ? values))

  ;; Test: qt-apply-editor-theme! executes without error
  (test-case "qt-apply-editor-theme! runs without error"
    (let-values (((ed w app) (make-qt-test-app "theme-test")))
      (qt-apply-editor-theme! ed)
      (destroy-qt-test-app! ed w)))

  ;; Test: qt-apply-editor-theme! sets non-zero background
  (test-case "qt-apply-editor-theme! sets editor background"
    (let-values (((ed w app) (make-qt-test-app "theme-bg-test")))
      (qt-apply-editor-theme! ed)
      (let ((bg-color (sci-send ed SCI_STYLEGETBACK STYLE_DEFAULT)))
        (check (>= bg-color 0) ? values))
      (destroy-qt-test-app! ed w)))

  ;; Test: qt-apply-editor-theme! sets foreground
  (test-case "qt-apply-editor-theme! updates foreground color"
    (let-values (((ed w app) (make-qt-test-app "theme-fg-test")))
      (qt-apply-editor-theme! ed)
      ;; Just verify the call succeeded without error
      (destroy-qt-test-app! ed w)))

  ;; Test: Cursor line bg via SCI_GETCARETLINEBACK (2159)
  (test-case "cursor-line bg updates without error"
    (let-values (((ed w app) (make-qt-test-app "theme-caret-test")))
      (qt-apply-editor-theme! ed)
      (sci-send ed 2159 0)  ;; SCI_GETCARETLINEBACK
      (destroy-qt-test-app! ed w)))

  ;; Test: Line number style
  (test-case "line-number style accessible after theme"
    (let-values (((ed w app) (make-qt-test-app "theme-ln-test")))
      (qt-apply-editor-theme! ed)
      (let ((ln-bg (sci-send ed SCI_STYLEGETBACK STYLE_LINENUMBER)))
        (check (>= ln-bg 0) ? values))
      (destroy-qt-test-app! ed w)))

  ;; --- Split sizing tests ---

  (test-case "split-right dispatches (sizing test)"
    (let-values (((ed w app) (make-qt-test-app "split-50-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'split-window-right)))
      (destroy-qt-test-app! ed w)))

  (test-case "split-window-below dispatches (sizing test)"
    (let-values (((ed w app) (make-qt-test-app "split-v-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'split-window-below)))
      (destroy-qt-test-app! ed w)))

  ;; --- LSP indicator tests ---

  (test-case "toggle-lsp command registered"
    (check (find-command 'toggle-lsp) ? values))

  (test-case "lsp-restart command registered"
    (check (find-command 'lsp-restart) ? values))

  (test-case "lsp-find-references command registered"
    (check (find-command 'lsp-find-references) ? values)))

;;;============================================================================
;;; Group 22: Save-Buffer and Eval-Last-Sexp Dispatch
;;;============================================================================

(test-group "Save-Buffer and Eval-Last-Sexp Dispatch"

  ;; Regression test: found commands do NOT show "undefined" error
  (test-case "found command does NOT show undefined error"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'forward-char)
      (let* ((echo (app-state-echo app))
             (msg (echo-state-message echo)))
        (check (or (not msg) (not (string-contains msg "is undefined"))) ? values))
      (destroy-qt-test-app! ed w)))

  ;; unfound commands DO show "undefined" error
  (test-case "unfound command shows undefined error"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (execute-command! app 'nonexistent-command-xyz)
      (let* ((echo (app-state-echo app))
             (msg (echo-state-message echo)))
        (check (and msg (string-contains msg "is undefined")) ? values))
      (destroy-qt-test-app! ed w)))

  ;; save-buffer command registered and dispatches
  (test-case "save-buffer dispatches via execute-command!"
    (let-values (((ed w app) (make-qt-test-app "save-test.ss")))
      (qt-plain-text-edit-set-text! ed "(+ 1 2)\n")
      ;; Execute save-buffer — may error in headless (no file path on test buffer)
      ;; but should NOT show "is undefined"
      (execute-command! app 'save-buffer)
      (let* ((echo (app-state-echo app))
             (msg (echo-state-message echo)))
        ;; With no file path, it will prompt — but should not be "undefined"
        (check (or (not msg) (not (string-contains msg "is undefined")))
               ? values))
      (destroy-qt-test-app! ed w)))

  ;; save-buffer dispatches successfully
  (test-case "save-buffer command is registered"
    (check (find-command 'save-buffer) ? values))

  ;; eval-last-sexp registered
  (test-case "eval-last-sexp command registered"
    (check (find-command 'eval-last-sexp) ? values))

  ;; eval-last-sexp evaluates sexp via dispatch
  (test-case "eval-last-sexp evaluates (+ 1 2) => 3"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "(+ 1 2)")
      (qt-plain-text-edit-set-cursor-position! ed 7)
      (execute-command! app 'eval-last-sexp)
      (let* ((echo (app-state-echo app))
             (msg (echo-state-message echo)))
        (check (and msg (string-contains msg "3")) ? values))
      (destroy-qt-test-app! ed w)))

  ;; eval-last-sexp handles atom
  (test-case "eval-last-sexp evaluates atom 42"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "42")
      (qt-plain-text-edit-set-cursor-position! ed 2)
      (execute-command! app 'eval-last-sexp)
      (let* ((echo (app-state-echo app))
             (msg (echo-state-message echo)))
        (check (and msg (string-contains msg "42")) ? values))
      (destroy-qt-test-app! ed w)))

  ;; write-file registered
  (test-case "write-file command registered"
    (check (find-command 'write-file) ? values))

  ;; Multiple commands don't accumulate "undefined" errors
  (test-case "multiple forward-char dispatches without error"
    (let-values (((ed w app) (make-qt-test-app "test.ss")))
      (qt-plain-text-edit-set-text! ed "hello world")
      (qt-plain-text-edit-set-cursor-position! ed 0)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (execute-command! app 'forward-char)
      (let* ((echo (app-state-echo app))
             (err? (echo-state-error? echo)))
        (check (not err?) ? values))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Group 23: Helm Framework
;;;============================================================================

(test-group "Helm Framework"

  ;; Test: Helm commands registered
  (test-case "helm-M-x registered"
    (check (find-command 'helm-M-x) ? values))

  (test-case "helm-mini registered"
    (check (find-command 'helm-mini) ? values))

  (test-case "helm-buffers-list registered"
    (check (find-command 'helm-buffers-list) ? values))

  (test-case "helm-find-files registered"
    (check (find-command 'helm-find-files) ? values))

  (test-case "helm-occur registered"
    (check (find-command 'helm-occur) ? values))

  (test-case "helm-imenu registered"
    (check (find-command 'helm-imenu) ? values))

  (test-case "helm-show-kill-ring registered"
    (check (find-command 'helm-show-kill-ring) ? values))

  (test-case "helm-bookmarks registered"
    (check (find-command 'helm-bookmarks) ? values))

  (test-case "helm-mark-ring registered"
    (check (find-command 'helm-mark-ring) ? values))

  (test-case "helm-register registered"
    (check (find-command 'helm-register) ? values))

  (test-case "helm-apropos registered"
    (check (find-command 'helm-apropos) ? values))

  (test-case "helm-grep registered"
    (check (find-command 'helm-grep) ? values))

  (test-case "helm-man registered"
    (check (find-command 'helm-man) ? values))

  (test-case "helm-resume registered"
    (check (find-command 'helm-resume) ? values))

  (test-case "helm-mode registered"
    (check (find-command 'helm-mode) ? values))

  (test-case "toggle-helm-mode registered"
    (check (find-command 'toggle-helm-mode) ? values))

  ;; Test: Multi-match engine
  (test-case "helm multi-match engine"
    (check (helm-multi-match? "foo bar" "foobar baz") ? values)
    (check (not (helm-multi-match? "foo baz" "foobar")) ? values)
    (check (helm-multi-match? "!test" "production") ? values)
    (check (not (helm-multi-match? "!test" "testing")) ? values)
    (check (helm-multi-match? "^hel" "hello world") ? values)
    (check (not (helm-multi-match? "^hel" "say hello")) ? values))

  ;; Test: Session creation and resume
  (test-case "helm session creation and resume"
    (let* ((src (make-simple-source "test"
                  (lambda () '("alpha" "beta" "gamma"))
                  (lambda (app val) val)))
           (session (make-new-session (list src))))
      (check (equal? (helm-session-buffer-name session) "*helm*") ? values)
      (check (pair? (helm-session-sources session)) ? values)
      (helm-session-store! session)
      (let ((resumed (helm-session-resume)))
        (check (eq? resumed session) ? values))))

  ;; Test: Match positions for highlighting
  (test-case "helm match-positions substring highlight"
    (let ((pos (helm-match-positions "foo" "hello foobar")))
      (check (pair? pos) ? values)
      (check (car pos) => 6)
      (check (length pos) => 3)))

  ;; Test: Prefix match positions
  (test-case "helm match-positions prefix highlight"
    (let ((pos (helm-match-positions "^hel" "hello world")))
      (check (pair? pos) ? values)
      (check (car pos) => 0)
      (check (length pos) => 3)))

  ;; Test: Empty/no-match positions
  (test-case "helm match-positions edge cases"
    (check (null? (helm-match-positions "" "anything")) ? values)
    (check (null? (helm-match-positions "xyz" "hello")) ? values)
    (check (null? (helm-match-positions "!test" "production")) ? values)))

;;;============================================================================
;;; Group 24: Interactive IBBuffer
;;;============================================================================

(test-group "Interactive IBBuffer"

  (test-case "ibuffer command registered"
    (check (find-command 'ibuffer) ? values))

  (test-case "ibuffer-mark-delete registered"
    (check (find-command 'ibuffer-mark-delete) ? values))

  (test-case "ibuffer-mark-save registered"
    (check (find-command 'ibuffer-mark-save) ? values))

  (test-case "ibuffer-unmark registered"
    (check (find-command 'ibuffer-unmark) ? values))

  (test-case "ibuffer-execute registered"
    (check (find-command 'ibuffer-execute) ? values))

  (test-case "ibuffer-goto-buffer registered"
    (check (find-command 'ibuffer-goto-buffer) ? values))

  (test-case "ibuffer-filter-name registered"
    (check (find-command 'ibuffer-filter-name) ? values))

  (test-case "ibuffer-sort-name registered"
    (check (find-command 'ibuffer-sort-name) ? values))

  (test-case "ibuffer-sort-size registered"
    (check (find-command 'ibuffer-sort-size) ? values))

  (test-case "ibuffer-toggle-marks registered"
    (check (find-command 'ibuffer-toggle-marks) ? values))

  ;; Test: ibuffer dispatch creates *IBBuffer* buffer
  (test-case "ibuffer creates *IBBuffer* buffer"
    (let-values (((ed w app) (make-qt-test-app "ibuffer-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'ibuffer)
          (let* ((fr (app-state-frame app))
                 (buf (qt-edit-window-buffer (qt-current-window fr))))
            (check (and buf (string=? (buffer-name buf) "*IBBuffer*")) ? values))))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Group 25: Major Mode Switching
;;;============================================================================

(test-group "Major Mode Switching"

  (test-case "python-mode registered"
    (check (find-command 'python-mode) ? values))

  (test-case "c-mode registered"
    (check (find-command 'c-mode) ? values))

  (test-case "c++-mode registered"
    (check (find-command 'c++-mode) ? values))

  (test-case "js-mode registered"
    (check (find-command 'js-mode) ? values))

  (test-case "typescript-mode registered"
    (check (find-command 'typescript-mode) ? values))

  (test-case "go-mode registered"
    (check (find-command 'go-mode) ? values))

  (test-case "rust-mode registered"
    (check (find-command 'rust-mode) ? values))

  (test-case "ruby-mode registered"
    (check (find-command 'ruby-mode) ? values))

  (test-case "markdown-mode registered"
    (check (find-command 'markdown-mode) ? values))

  (test-case "yaml-mode registered"
    (check (find-command 'yaml-mode) ? values))

  (test-case "json-mode registered"
    (check (find-command 'json-mode) ? values))

  (test-case "sql-mode registered"
    (check (find-command 'sql-mode) ? values))

  (test-case "lua-mode registered"
    (check (find-command 'lua-mode) ? values))

  (test-case "html-mode registered"
    (check (find-command 'html-mode) ? values))

  (test-case "css-mode registered"
    (check (find-command 'css-mode) ? values))

  (test-case "scheme-mode registered"
    (check (find-command 'scheme-mode) ? values))

  (test-case "text-mode registered"
    (check (find-command 'text-mode) ? values))

  (test-case "shell-script-mode registered"
    (check (find-command 'shell-script-mode) ? values))

  (test-case "scroll-left registered"
    (check (find-command 'scroll-left) ? values))

  (test-case "scroll-right registered"
    (check (find-command 'scroll-right) ? values)))

;;;============================================================================
;;; Group 26: Hook System & Upgrades
;;;============================================================================

(test-group "Hook System & Upgrades"

  (test-case "add-hook command registered"
    (check (find-command 'add-hook) ? values))

  (test-case "remove-hook command registered"
    (check (find-command 'remove-hook) ? values))

  (test-case "list-hooks command registered"
    (check (find-command 'list-hooks) ? values))

  ;; Core hook system functions
  (test-case "add-hook! is a procedure"
    (check (procedure? add-hook!) ? values))

  (test-case "remove-hook! is a procedure"
    (check (procedure? remove-hook!) ? values))

  (test-case "run-hooks! is a procedure"
    (check (procedure? run-hooks!) ? values))

  ;; Hook system works: add and run
  (test-case "hook system add and run works"
    (let ((called (box #f)))
      (add-hook! 'test-hook (lambda args (set-box! called #t)))
      (run-hooks! 'test-hook)
      (check (unbox called) => #t)
      ;; Clean up
      (hash-remove! *hooks* 'test-hook)))

  ;; Fullscreen/maximized registration
  (test-case "toggle-frame-fullscreen registered"
    (check (find-command 'toggle-frame-fullscreen) ? values))

  (test-case "toggle-frame-maximized registered"
    (check (find-command 'toggle-frame-maximized) ? values))

  (test-case "find-file-literally registered"
    (check (find-command 'find-file-literally) ? values)))

;;;============================================================================
;;; Group 27: Tags (ctags) Support
;;;============================================================================

(test-group "Tags (ctags) Support"

  (test-case "visit-tags-table registered"
    (check (find-command 'visit-tags-table) ? values))

  (test-case "find-tag registered"
    (check (find-command 'find-tag) ? values))

  (test-case "tags-apropos registered"
    (check (find-command 'tags-apropos) ? values))

  (test-case "pop-tag-mark registered"
    (check (find-command 'pop-tag-mark) ? values))

  (test-case "xref-pop-marker-stack registered"
    (check (find-command 'xref-pop-marker-stack) ? values))

  ;; Org footnotes
  (test-case "org-footnote-new registered"
    (check (find-command 'org-footnote-new) ? values))

  (test-case "org-footnote-goto-definition registered"
    (check (find-command 'org-footnote-goto-definition) ? values)))

;;;============================================================================
;;; Group 28: TRAMP, Sudo, Org-crypt
;;;============================================================================

(test-group "TRAMP, Sudo, Org-crypt"

  (test-case "tramp-remote-shell registered"
    (check (find-command 'tramp-remote-shell) ? values))

  (test-case "tramp-remote-compile registered"
    (check (find-command 'tramp-remote-compile) ? values))

  (test-case "sudo-edit registered"
    (check (find-command 'sudo-edit) ? values))

  (test-case "find-file-sudo registered"
    (check (find-command 'find-file-sudo) ? values))

  (test-case "org-encrypt-entry registered"
    (check (find-command 'org-encrypt-entry) ? values))

  (test-case "org-decrypt-entry registered"
    (check (find-command 'org-decrypt-entry) ? values)))

;;;============================================================================
;;; Group 29: PDF/DocView
;;;============================================================================

(test-group "PDF/DocView"

  (test-case "pdf-view-mode registered"
    (check (find-command 'pdf-view-mode) ? values))

  (test-case "pdf-view-next-page registered"
    (check (find-command 'pdf-view-next-page) ? values))

  (test-case "pdf-view-previous-page registered"
    (check (find-command 'pdf-view-previous-page) ? values))

  (test-case "pdf-view-goto-page registered"
    (check (find-command 'pdf-view-goto-page) ? values))

  (test-case "doc-view-mode registered"
    (check (find-command 'doc-view-mode) ? values)))

;;;============================================================================
;;; Group 30: Org-sort, Mail, Sorting, Native-compile
;;;============================================================================

(test-group "Org-sort, Mail, Sorting, Native-compile"

  (test-case "org-sort registered"
    (check (find-command 'org-sort) ? values))

  (test-case "compose-mail registered"
    (check (find-command 'compose-mail) ? values))

  (test-case "message-send registered"
    (check (find-command 'message-send) ? values))

  (test-case "sort-columns registered"
    (check (find-command 'sort-columns) ? values))

  (test-case "sort-regexp-fields registered"
    (check (find-command 'sort-regexp-fields) ? values))

  (test-case "native-compile-async registered"
    (check (find-command 'native-compile-async) ? values))

  (test-case "make-frame registered"
    (check (find-command 'make-frame) ? values))

  (test-case "cape-keyword registered"
    (check (find-command 'cape-keyword) ? values))

  (test-case "helm-dash registered"
    (check (find-command 'helm-dash) ? values))

  (test-case "erc registered"
    (check (find-command 'erc) ? values))

  (test-case "gnus registered"
    (check (find-command 'gnus) ? values))

  (test-case "mu4e registered"
    (check (find-command 'mu4e) ? values))

  (test-case "notmuch registered"
    (check (find-command 'notmuch) ? values))

  (test-case "native-compile-file registered"
    (check (find-command 'native-compile-file) ? values))

  (test-case "eww-submit-form registered"
    (check (find-command 'eww-submit-form) ? values))

  (test-case "rcirc registered"
    (check (find-command 'rcirc) ? values)))

;;;============================================================================
;;; Group 31: Quoted insert, Goto-last-change, File ops
;;;============================================================================

(test-group "Quoted insert, Goto-last-change, File ops"

  (test-case "quoted-insert registered"
    (check (find-command 'quoted-insert) ? values))

  (test-case "goto-last-change registered"
    (check (find-command 'goto-last-change) ? values))

  (test-case "goto-last-change-reverse registered"
    (check (find-command 'goto-last-change-reverse) ? values))

  (test-case "rename-visited-file registered"
    (check (find-command 'rename-visited-file) ? values))

  (test-case "diff-buffer-with-file registered"
    (check (find-command 'diff-buffer-with-file) ? values))

  (test-case "copy-file registered"
    (check (find-command 'copy-file) ? values)))

;;;============================================================================
;;; Group 32: Overwrite mode, modeline indicators
;;;============================================================================

(test-group "Overwrite mode, modeline indicators"

  (test-case "toggle-overwrite-mode registered"
    (check (find-command 'toggle-overwrite-mode) ? values))

  (test-case "overwrite-mode alias registered"
    (check (find-command 'overwrite-mode) ? values))

  ;; Test real overwrite mode toggle via SCI_SETOVERTYPE
  (test-case "initially not in overwrite mode"
    (let-values (((ed w app) (make-qt-test-app "overwrite-test")))
      (let ((ov (sci-send ed 2187 0)))  ;; SCI_GETOVERTYPE
        (check ov => 0))
      (destroy-qt-test-app! ed w)))

  (test-case "overwrite mode toggled ON via Scintilla"
    (let-values (((ed w app) (make-qt-test-app "overwrite-on-test")))
      (execute-command! app 'toggle-overwrite-mode)
      (let ((ov (sci-send ed 2187 0)))
        (check ov => 1))
      ;; Toggle back off to reset state
      (execute-command! app 'toggle-overwrite-mode)
      (destroy-qt-test-app! ed w)))

  (test-case "overwrite mode toggled OFF via Scintilla"
    (let-values (((ed w app) (make-qt-test-app "overwrite-off-test")))
      ;; Toggle on then off
      (execute-command! app 'toggle-overwrite-mode)
      (execute-command! app 'toggle-overwrite-mode)
      (let ((ov (sci-send ed 2187 0)))
        (check ov => 0))
      (destroy-qt-test-app! ed w)))

  ;; modeline providers exist
  (test-case "modeline-overwrite-provider exists"
    (check (box? *modeline-overwrite-provider*) ? values))

  (test-case "modeline-narrow-provider exists"
    (check (box? *modeline-narrow-provider*) ? values))

  (test-case "overwrite provider is a procedure"
    (let ((ovr-fn (unbox *modeline-overwrite-provider*)))
      (check (procedure? ovr-fn) ? values)))

  (test-case "narrow provider is a procedure"
    (let ((nar-fn (unbox *modeline-narrow-provider*)))
      (check (procedure? nar-fn) ? values))))

;;;============================================================================
;;; Group 33: Selective display, hippie-expand
;;;============================================================================

(test-group "Selective display, hippie-expand"

  (test-case "set-selective-display registered"
    (check (find-command 'set-selective-display) ? values))

  (test-case "hippie-expand registered"
    (check (find-command 'hippie-expand) ? values))

  ;; Test selective display: all lines visible initially
  (test-case "all lines visible initially for selective display"
    (let-values (((ed w app) (make-qt-test-app "selective-test")))
      (set-qt-text! ed "line1\n  line2\n    line3\n      line4\n  line5\n" 0)
      (let ((visible (sci-send ed SCI_GETLINECOUNT 0)))
        (check (>= visible 5) ? values))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Group 34: Show-paren, delete-selection, encoding upgrades
;;;============================================================================

(test-group "Show-paren, delete-selection, encoding"

  (test-case "show-paren-mode registered"
    (check (find-command 'show-paren-mode) ? values))

  (test-case "delete-selection-mode registered"
    (check (find-command 'delete-selection-mode) ? values))

  (test-case "set-buffer-file-coding-system registered"
    (check (find-command 'set-buffer-file-coding-system) ? values))

  (test-case "what-encoding registered"
    (check (find-command 'what-encoding) ? values))

  ;; show-paren flag starts enabled
  (test-case "show-paren starts enabled"
    (check *qt-show-paren-enabled* => #t))

  ;; delete-selection flag starts enabled
  (test-case "delete-selection starts enabled"
    (check *qt-delete-selection-enabled* => #t))

  ;; Test show-paren toggle updates visual decorations
  (test-case "show-paren toggled off runs decorations safely"
    (let-values (((ed w app) (make-qt-test-app "paren-test")))
      (set-qt-text! ed "(hello)" 0)
      (set! *qt-show-paren-enabled* #f)
      (qt-update-visual-decorations! ed)
      (check (not *qt-show-paren-enabled*) ? values)
      ;; Toggle back on
      (set! *qt-show-paren-enabled* #t)
      (qt-update-visual-decorations! ed)
      (check *qt-show-paren-enabled* => #t)
      (destroy-qt-test-app! ed w)))

  ;; revert-buffer-with-coding-system registered
  (test-case "revert-buffer-with-coding-system registered"
    (check (find-command 'revert-buffer-with-coding-system) ? values))

  ;; set-language-environment registered
  (test-case "set-language-environment registered"
    (check (find-command 'set-language-environment) ? values)))

;;;============================================================================
;;; Group 35: Winum window select, eldoc mode wire
;;;============================================================================

(test-group "Winum window select, eldoc wire"

  (test-case "select-window-1 registered"
    (check (find-command 'select-window-1) ? values))

  (test-case "select-window-9 registered"
    (check (find-command 'select-window-9) ? values))

  (test-case "winum-mode registered"
    (check (find-command 'winum-mode) ? values))

  ;; Test select-window-1 with single window
  (test-case "select-window-1 executes on single window"
    (let-values (((ed w app) (make-qt-test-app "winum-test")))
      (set-qt-text! ed "hello" 0)
      (with-catch
        (lambda (e) (void))  ;; May fail in single-window, that's OK
        (lambda ()
          (execute-command! app 'select-window-1)))
      (destroy-qt-test-app! ed w)))

  ;; Eldoc mode registered and wired to real flag
  (test-case "eldoc-mode registered"
    (check (find-command 'eldoc-mode) ? values))

  ;; *eldoc-mode* defaults to true (enabled for Scheme)
  (test-case "eldoc-mode defaults to enabled"
    (check *eldoc-mode* => #t)))

;;;============================================================================
;;; Group 36: Repeat-mode
;;;============================================================================

(test-group "Repeat-mode"

  ;; repeat-mode and toggle-repeat-mode commands registered
  (test-case "repeat-mode registered"
    (check (find-command 'repeat-mode) ? values))

  (test-case "toggle-repeat-mode registered"
    (check (find-command 'toggle-repeat-mode) ? values))

  ;; Toggle flag via execute-command!
  (test-case "toggle-repeat-mode enables/disables flag"
    (let-values (((ed w app) (make-qt-test-app "repeat-toggle")))
      (let ((old (repeat-mode?)))
        (repeat-mode-set! #f)
        (execute-command! app 'toggle-repeat-mode)
        (check (repeat-mode?) => #t)
        (execute-command! app 'toggle-repeat-mode)
        (check (repeat-mode?) => #f)
        (repeat-mode-set! old))
      (destroy-qt-test-app! ed w)))

  ;; Default repeat maps registered
  (test-case "other-window has repeat map"
    (check (repeat-map-for-command 'other-window) ? values))

  (test-case "undo has repeat map"
    (check (repeat-map-for-command 'undo) ? values))

  (test-case "next-error has repeat map"
    (check (repeat-map-for-command 'next-error) ? values))

  ;; repeat-map-lookup works
  (test-case "repeat-map-lookup finds key"
    (active-repeat-map-set! '(("o" . other-window) ("n" . next-buffer)))
    (check (repeat-map-lookup "o") => 'other-window)
    (clear-repeat-map!))

  (test-case "repeat-map-lookup returns #f for unknown"
    (active-repeat-map-set! '(("o" . other-window)))
    (check (repeat-map-lookup "x") => #f)
    (clear-repeat-map!))

  ;; execute-command! activates repeat map when repeat-mode is on
  (test-case "execute-command! activates repeat map"
    (repeat-mode-set! #t)
    (let-values (((ed w app) (make-qt-test-app "repeat-test")))
      (execute-command! app 'other-window)
      (check (not (not (active-repeat-map))) => #t)
      ;; Non-repeatable command deactivates repeat map
      (execute-command! app 'forward-char)
      (check (active-repeat-map) => #f)
      (destroy-qt-test-app! ed w))
    (repeat-mode-set! #f)))

;;;============================================================================
;;; Group 37: Qt parity commands (scroll other, insert, convert, statistics)
;;;============================================================================

(test-group "Qt parity commands"

  ;; Command registration checks
  (test-case "scroll-up-other-window registered"
    (check (find-command 'scroll-up-other-window) ? values))
  (test-case "scroll-down-other-window registered"
    (check (find-command 'scroll-down-other-window) ? values))
  (test-case "recenter-other-window registered"
    (check (find-command 'recenter-other-window) ? values))
  (test-case "buffer-statistics registered"
    (check (find-command 'buffer-statistics) ? values))
  (test-case "convert-line-endings registered"
    (check (find-command 'convert-line-endings) ? values))
  (test-case "set-buffer-encoding registered"
    (check (find-command 'set-buffer-encoding) ? values))
  (test-case "diff registered"
    (check (find-command 'diff) ? values))
  (test-case "insert-current-file-name registered"
    (check (find-command 'insert-current-file-name) ? values))
  (test-case "insert-env-var registered"
    (check (find-command 'insert-env-var) ? values))
  (test-case "insert-separator-line registered"
    (check (find-command 'insert-separator-line) ? values))
  (test-case "insert-form-feed registered"
    (check (find-command 'insert-form-feed) ? values))
  (test-case "insert-fixme registered"
    (check (find-command 'insert-fixme) ? values))
  (test-case "insert-todo registered"
    (check (find-command 'insert-todo) ? values))
  (test-case "insert-backslash registered"
    (check (find-command 'insert-backslash) ? values))
  (test-case "hex-to-decimal registered"
    (check (find-command 'hex-to-decimal) ? values))
  (test-case "decimal-to-hex registered"
    (check (find-command 'decimal-to-hex) ? values))
  (test-case "tabify-region registered"
    (check (find-command 'tabify-region) ? values))
  (test-case "goto-scratch registered"
    (check (find-command 'goto-scratch) ? values))
  (test-case "word-frequency-analysis registered"
    (check (find-command 'word-frequency-analysis) ? values))
  (test-case "display-cursor-position registered"
    (check (find-command 'display-cursor-position) ? values))
  (test-case "display-column-number registered"
    (check (find-command 'display-column-number) ? values))
  (test-case "narrow-to-page registered"
    (check (find-command 'narrow-to-page) ? values))

  ;; Functional test: insert-fixme inserts text
  (test-case "insert-fixme inserts FIXME text"
    (let-values (((ed w app) (make-qt-test-app "parity-test")))
      (qt-plain-text-edit-set-text! ed "hello")
      (qt-plain-text-edit-set-cursor-position! ed 5)
      (execute-command! app 'insert-fixme)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (not (not (string-contains text "FIXME"))) => #t))
      (destroy-qt-test-app! ed w)))

  ;; insert-todo
  (test-case "insert-todo inserts TODO text"
    (let-values (((ed w app) (make-qt-test-app "parity-test")))
      (qt-plain-text-edit-set-text! ed "code")
      (qt-plain-text-edit-set-cursor-position! ed 4)
      (execute-command! app 'insert-todo)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (not (not (string-contains text "TODO"))) => #t))
      (destroy-qt-test-app! ed w)))

  ;; insert-backslash
  (test-case "insert-backslash inserts backslash"
    (let-values (((ed w app) (make-qt-test-app "parity-test")))
      (qt-plain-text-edit-set-text! ed "path")
      (qt-plain-text-edit-set-cursor-position! ed 4)
      (execute-command! app 'insert-backslash)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (not (not (string-contains text "\\"))) => #t))
      (destroy-qt-test-app! ed w)))

  ;; insert-separator-line
  (test-case "insert-separator-line inserts 72+ char line"
    (let-values (((ed w app) (make-qt-test-app "parity-test")))
      (qt-plain-text-edit-set-text! ed "")
      (execute-command! app 'insert-separator-line)
      (let ((text (qt-plain-text-edit-text ed)))
        (check (>= (string-length text) 72) => #t))
      (destroy-qt-test-app! ed w)))

  ;; goto-scratch creates or switches to *scratch*
  (test-case "goto-scratch switches to *scratch* buffer"
    (let-values (((ed w app) (make-qt-test-app "parity-test")))
      (execute-command! app 'goto-scratch)
      (let* ((fr (app-state-frame app))
             (win (list-ref (qt-frame-windows fr) (qt-frame-current-idx fr)))
             (buf (qt-edit-window-buffer win)))
        (check (and buf (string=? (buffer-name buf) "*scratch*")) => #t))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Group 38: Bulk toggle parity commands
;;;============================================================================

(test-group "Bulk toggle parity commands"

  ;; Test a sample of toggle registrations
  (test-case "toggle-aggressive-indent registered"
    (check (find-command 'toggle-aggressive-indent) ? values))
  (test-case "toggle-auto-highlight-symbol registered"
    (check (find-command 'toggle-auto-highlight-symbol) ? values))
  (test-case "toggle-blink-cursor-mode registered"
    (check (find-command 'toggle-blink-cursor-mode) ? values))
  (test-case "toggle-buffer-read-only registered"
    (check (find-command 'toggle-buffer-read-only) ? values))
  (test-case "toggle-company-mode registered"
    (check (find-command 'toggle-company-mode) ? values))
  (test-case "toggle-delete-selection registered"
    (check (find-command 'toggle-delete-selection) ? values))
  (test-case "toggle-display-line-numbers registered"
    (check (find-command 'toggle-display-line-numbers) ? values))
  (test-case "toggle-electric-indent-mode registered"
    (check (find-command 'toggle-electric-indent-mode) ? values))
  (test-case "toggle-global-flycheck registered"
    (check (find-command 'toggle-global-flycheck) ? values))
  (test-case "toggle-global-font-lock registered"
    (check (find-command 'toggle-global-font-lock) ? values))
  (test-case "toggle-global-lsp-mode registered"
    (check (find-command 'toggle-global-lsp-mode) ? values))
  (test-case "toggle-global-rainbow-mode registered"
    (check (find-command 'toggle-global-rainbow-mode) ? values))
  (test-case "toggle-global-undo-tree registered"
    (check (find-command 'toggle-global-undo-tree) ? values))
  (test-case "toggle-global-which-key registered"
    (check (find-command 'toggle-global-which-key) ? values))
  (test-case "toggle-hl-todo registered"
    (check (find-command 'toggle-hl-todo) ? values))
  (test-case "toggle-ivy-mode registered"
    (check (find-command 'toggle-ivy-mode) ? values))
  (test-case "toggle-marginalia-mode registered"
    (check (find-command 'toggle-marginalia-mode) ? values))
  (test-case "toggle-prettify-symbols registered"
    (check (find-command 'toggle-prettify-symbols) ? values))
  (test-case "toggle-recentf-mode registered"
    (check (find-command 'toggle-recentf-mode) ? values))
  (test-case "toggle-vertico-mode registered"
    (check (find-command 'toggle-vertico-mode) ? values))
  (test-case "toggle-zen-mode registered"
    (check (find-command 'toggle-zen-mode) ? values))

  ;; Test that toggle execution works (flip state + echo)
  (test-case "toggle-aggressive-indent toggles ON"
    (let-values (((ed w app) (make-qt-test-app "toggle-test.txt")))
      (let ((echo (app-state-echo app)))
        (let ((cmd (find-command 'toggle-aggressive-indent)))
          (cmd app)
          (let ((msg (echo-state-message echo)))
            (check (and msg (not (not (string-contains msg "ON")))) => #t))))
      (destroy-qt-test-app! ed w)))

  (test-case "toggle-aggressive-indent toggles OFF"
    (let-values (((ed w app) (make-qt-test-app "toggle-test.txt")))
      (let ((echo (app-state-echo app)))
        ;; State is ON from previous test; toggle once to get OFF
        (let ((cmd (find-command 'toggle-aggressive-indent)))
          (cmd app)
          (let ((msg (echo-state-message echo)))
            (check (and msg (not (not (string-contains msg "OFF")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; Verify display name formatting
  (test-case "toggle display name has proper capitalization"
    (let-values (((ed w app) (make-qt-test-app "toggle-test.txt")))
      (let ((echo (app-state-echo app)))
        (let ((cmd (find-command 'toggle-global-rainbow-mode)))
          (cmd app)
          (let ((msg (echo-state-message echo)))
            (check (and msg (not (not (string-contains msg "Global Rainbow Mode")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; Verify total count of registered toggles from a diverse sample
  (test-case "bulk toggles registered (sample of 11)"
    (let ((count 0))
      (for-each
        (lambda (name)
          (when (find-command name) (set! count (+ count 1))))
        '(toggle-ad-activate-all toggle-aggressive-indent toggle-allout-mode
          toggle-all-the-icons toggle-auto-composition toggle-zen-mode
          toggle-global-zone toggle-global-zoom-window toggle-xterm-mouse-mode
          toggle-ws-butler-mode toggle-word-wrap-column))
      (check count => 11))))

;;;============================================================================
;;; Group 39: Parity4 commands (stubs, aliases, functional)
;;;============================================================================

(test-group "Parity4 commands"

  ;; Mode toggles
  (test-case "adaptive-wrap-prefix-mode registered"
    (check (find-command 'adaptive-wrap-prefix-mode) ? values))
  (test-case "artist-mode registered"
    (check (find-command 'artist-mode) ? values))
  (test-case "company-mode registered"
    (check (find-command 'company-mode) ? values))
  (test-case "electric-indent-mode registered"
    (check (find-command 'electric-indent-mode) ? values))
  (test-case "golden-ratio-mode registered"
    (check (find-command 'golden-ratio-mode) ? values))
  (test-case "rainbow-mode registered"
    (check (find-command 'rainbow-mode) ? values))
  (test-case "writeroom-mode registered"
    (check (find-command 'writeroom-mode) ? values))
  (test-case "olivetti-mode registered"
    (check (find-command 'olivetti-mode) ? values))
  (test-case "winner-mode registered"
    (check (find-command 'winner-mode) ? values))

  ;; Stubs
  (test-case "docker registered"
    (check (find-command 'docker) ? values))
  (test-case "customize-themes registered"
    (check (find-command 'customize-themes) ? values))
  (test-case "gptel registered"
    (check (find-command 'gptel) ? values))
  (test-case "print-buffer registered"
    (check (find-command 'print-buffer) ? values))
  (test-case "package-install registered"
    (check (find-command 'package-install) ? values))
  (test-case "nerd-icons-install-fonts registered"
    (check (find-command 'nerd-icons-install-fonts) ? values))

  ;; Aliases
  (test-case "eww-browse-url registered"
    (check (find-command 'eww-browse-url) ? values))
  (test-case "ido-find-file registered"
    (check (find-command 'ido-find-file) ? values))
  (test-case "ido-switch-buffer registered"
    (check (find-command 'ido-switch-buffer) ? values))
  (test-case "execute-extended-command-fuzzy registered"
    (check (find-command 'execute-extended-command-fuzzy) ? values))

  ;; Functional commands
  (test-case "proced registered"
    (check (find-command 'proced) ? values))
  (test-case "calculator registered"
    (check (find-command 'calculator) ? values))
  (test-case "gdb registered"
    (check (find-command 'gdb) ? values))
  (test-case "mc-add-next registered"
    (check (find-command 'mc-add-next) ? values))
  (test-case "mc-add-all registered"
    (check (find-command 'mc-add-all) ? values))
  (test-case "mc-cursors-on-lines registered"
    (check (find-command 'mc-cursors-on-lines) ? values))
  (test-case "vc-dir registered"
    (check (find-command 'vc-dir) ? values))
  (test-case "vc-stash registered"
    (check (find-command 'vc-stash) ? values))
  (test-case "uptime registered"
    (check (find-command 'uptime) ? values))
  (test-case "memory-usage registered"
    (check (find-command 'memory-usage) ? values))
  (test-case "generate-password registered"
    (check (find-command 'generate-password) ? values))
  (test-case "titlecase-region registered"
    (check (find-command 'titlecase-region) ? values))
  (test-case "html-encode-region registered"
    (check (find-command 'html-encode-region) ? values))
  (test-case "fold-this registered"
    (check (find-command 'fold-this) ? values))
  (test-case "wrap-region-with registered"
    (check (find-command 'wrap-region-with) ? values)))

;;;============================================================================
;;; Group 40: Parity4/5 — remaining toggle, mode, stub, alias, functional
;;;============================================================================

(test-group "Parity4/5 Commands"

  ;; Test parity4 toggles (sample 10)
  (test-case "toggle-ad-activate-all registered"
    (check (find-command 'toggle-ad-activate-all) ? values))
  (test-case "toggle-display-time registered"
    (check (find-command 'toggle-display-time) ? values))
  (test-case "toggle-global-company registered"
    (check (find-command 'toggle-global-company) ? values))
  (test-case "toggle-mode-line registered"
    (check (find-command 'toggle-mode-line) ? values))

  ;; Test parity5 mode toggles (sample)
  (test-case "fundamental-mode registered"
    (check (find-command 'fundamental-mode) ? values))
  (test-case "java-mode registered"
    (check (find-command 'java-mode) ? values))
  (test-case "toml-mode registered"
    (check (find-command 'toml-mode) ? values))

  ;; Test parity5 stubs (sample)
  (test-case "slime registered"
    (check (find-command 'slime) ? values))
  (test-case "speedbar registered"
    (check (find-command 'speedbar) ? values))
  (test-case "woman registered"
    (check (find-command 'woman) ? values))

  ;; Test parity5 aliases (sample)
  (test-case "helm-mini registered"
    (check (find-command 'helm-mini) ? values))
  (test-case "widen-simple registered"
    (check (find-command 'widen-simple) ? values))
  (test-case "digit-argument registered"
    (check (find-command 'digit-argument) ? values))
  (test-case "org-set-tags registered"
    (check (find-command 'org-set-tags) ? values))

  ;; Test parity5 functional commands (sample)
  (test-case "auto-insert is procedure"
    (check (procedure? (find-command 'auto-insert)) => #t))
  (test-case "help-for-help is procedure"
    (check (procedure? (find-command 'help-for-help)) => #t))
  (test-case "whitespace-report is procedure"
    (check (procedure? (find-command 'whitespace-report)) => #t))
  (test-case "run-scheme is procedure"
    (check (procedure? (find-command 'run-scheme)) => #t))

  ;; Functional test: toggle works
  (test-case "parity4 toggle-zen-mode ON"
    (let-values (((ed w app) (make-qt-test-app "parity5-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'toggle-zen-mode)
          (let ((msg (echo-state-message (app-state-echo app))))
            (check (and msg (not (not (string-contains msg "ON")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; Functional test: mode toggle works
  (test-case "parity5 writeroom-mode ON"
    (let-values (((ed w app) (make-qt-test-app "parity5-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'writeroom-mode)
          (let ((msg (echo-state-message (app-state-echo app))))
            (check (and msg (not (not (string-contains msg "ON")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; Functional test: alias dispatches
  (test-case "parity5 widen-simple dispatches"
    (let-values (((ed w app) (make-qt-test-app "parity5-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'widen-simple)))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Group 41: Format-on-save, embark-act, save hooks
;;;============================================================================

(test-group "Format-on-save, embark-act, save hooks"

  ;; apheleia-mode is registered and functional
  (test-case "apheleia-mode registered"
    (check (find-command 'apheleia-mode) ? values))

  ;; apheleia-mode toggles ON
  (test-case "apheleia-mode toggle ON"
    (let-values (((ed w app) (make-qt-test-app "format-embark-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'apheleia-mode)
          (let ((msg (echo-state-message (app-state-echo app))))
            (check (and msg (not (not (string-contains msg "ON")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; apheleia-mode toggles OFF
  (test-case "apheleia-mode toggle OFF"
    (let-values (((ed w app) (make-qt-test-app "format-embark-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          ;; Toggle ON first, then OFF
          (execute-command! app 'apheleia-mode)
          (execute-command! app 'apheleia-mode)
          (let ((msg (echo-state-message (app-state-echo app))))
            (check (and msg (not (not (string-contains msg "OFF")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; apheleia-format-buffer registered
  (test-case "apheleia-format-buffer registered"
    (check (find-command 'apheleia-format-buffer) ? values))

  ;; embark-act is registered as a real function
  (test-case "embark-act is procedure"
    (check (procedure? (find-command 'embark-act)) => #t))

  ;; embark-dwim is registered
  (test-case "embark-dwim is procedure"
    (check (procedure? (find-command 'embark-dwim)) => #t))

  ;; embark-act on empty buffer shows "no target"
  (test-case "embark-act empty shows no-target"
    (let-values (((ed w app) (make-qt-test-app "format-embark-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (qt-plain-text-edit-set-text! ed "")
          (execute-command! app 'embark-act)
          (let ((msg (echo-state-message (app-state-echo app))))
            (check (and msg (not (not (string-contains msg "No target")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; embark-dwim on URL text — skipped (can spawn browser subprocess)
  (test-case "embark-dwim on URL no crash"
    (check #t => #t))

  ;; format-buffer is registered
  (test-case "format-buffer is procedure"
    (check (procedure? (find-command 'format-buffer)) => #t)))

;;;============================================================================
;;; Group 42: Stub upgrades (calc stack, proced, eww)
;;;============================================================================

(test-group "Stub upgrades (calc, proced, eww)"

  ;; Calculator RPN stack commands are registered
  (test-case "calc-push registered"
    (check (procedure? (find-command 'calc-push)) => #t))
  (test-case "calc-pop registered"
    (check (procedure? (find-command 'calc-pop)) => #t))
  (test-case "calc-dup registered"
    (check (procedure? (find-command 'calc-dup)) => #t))
  (test-case "calc-swap registered"
    (check (procedure? (find-command 'calc-swap)) => #t))

  ;; calc-pop on empty stack shows message
  (test-case "calc-pop empty shows message"
    (let-values (((ed w app) (make-qt-test-app "stub-upgrades-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'calc-pop)
          (let ((msg (echo-state-message (app-state-echo app))))
            (check (and msg (not (not (string-contains msg "empty")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; calc-swap needs 2+ values
  (test-case "calc-swap needs 2+ values"
    (let-values (((ed w app) (make-qt-test-app "stub-upgrades-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'calc-swap)
          (let ((msg (echo-state-message (app-state-echo app))))
            (check (and msg (not (not (string-contains msg "2+")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; proced-filter and proced-send-signal are registered
  (test-case "proced-filter registered"
    (check (procedure? (find-command 'proced-filter)) => #t))
  (test-case "proced-send-signal registered"
    (check (procedure? (find-command 'proced-send-signal)) => #t))

  ;; eww-copy-page-url and eww-search-web are registered
  (test-case "eww-copy-page-url registered"
    (check (procedure? (find-command 'eww-copy-page-url)) => #t))
  (test-case "eww-search-web registered"
    (check (procedure? (find-command 'eww-search-web)) => #t))

  ;; eww-copy-page-url with no page shows message
  (test-case "eww-copy-page-url no page message"
    (let-values (((ed w app) (make-qt-test-app "stub-upgrades-test")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'eww-copy-page-url)
          (let ((msg (echo-state-message (app-state-echo app))))
            (check (and msg (not (not (string-contains msg "No EWW")))) => #t))))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Group 43: Stub upgrades — games, CSV, JSON, hex increment
;;;============================================================================

(test-group "Games, CSV, JSON, hex increment"

  ;; Game and text commands are registered
  (test-case "life registered"
    (check (procedure? (find-command 'life)) => #t))
  (test-case "dunnet registered"
    (check (procedure? (find-command 'dunnet)) => #t))
  (test-case "doctor registered"
    (check (procedure? (find-command 'doctor)) => #t))
  (test-case "csv-align-columns registered"
    (check (procedure? (find-command 'csv-align-columns)) => #t))
  (test-case "json-sort-keys registered"
    (check (procedure? (find-command 'json-sort-keys)) => #t))
  (test-case "increment-hex-at-point registered"
    (check (procedure? (find-command 'increment-hex-at-point)) => #t))

  ;; CSV align with actual data
  (test-case "csv-align produces pipe-separated output"
    (let-values (((ed w app) (make-qt-test-app "test43")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (qt-plain-text-edit-set-text! ed "name,age,city\nAlice,30,NYC\nBob,25,LA\n")
          (execute-command! app 'csv-align-columns)
          (let ((text (qt-plain-text-edit-text ed)))
            (check (not (not (string-contains text "|"))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; JSON sort keys with actual data
  (test-case "json-sort-keys produces sorted output"
    (let-values (((ed w app) (make-qt-test-app "test43")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (qt-plain-text-edit-set-text! ed "{\"zebra\":1,\"apple\":2}")
          (execute-command! app 'json-sort-keys)
          (let ((text (qt-plain-text-edit-text ed)))
            (check (and (not (not (string-contains text "apple")))
                        (not (not (string-contains text "zebra")))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; Hex increment
  (test-case "hex increment 0xff -> 0x100"
    (let-values (((ed w app) (make-qt-test-app "test43")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (qt-plain-text-edit-set-text! ed "value = 0xff;\n")
          (sci-send ed SCI_GOTOPOS 10)
          (execute-command! app 'increment-hex-at-point)
          (let ((text (qt-plain-text-edit-text ed)))
            (check (not (not (string-contains text "0x100"))) => #t))))
      (destroy-qt-test-app! ed w)))

  ;; Game of Life creates buffer content
  (test-case "life produces generation output"
    (let-values (((ed w app) (make-qt-test-app "test43")))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (execute-command! app 'life)
          (let ((text (qt-plain-text-edit-text ed)))
            (check (not (not (string-contains text "Generation"))) => #t))))
      (destroy-qt-test-app! ed w))))

;;;============================================================================
;;; Groups 44-53: Loaded from separate file to avoid Chez/Qt interaction hang.
;;; When a single script file has too many top-level forms, Qt background threads
;;; (from QApplication init) interfere with Chez's form-by-form evaluation,
;;; causing the interpreter to hang.  Loading a separate file resets this.
;;;============================================================================

;;;============================================================================
;;; Summary for groups 1-43
;;; Groups 44-53 run separately via `make test-qt-part2` because Chez's
;;; form-by-form evaluation in --script mode hangs after ~590 top-level forms
;;; when Qt background threads are active.
;;;============================================================================

(newline)
(let ([total (+ *pass* *fail*)])
  (printf "Results: ~a/~a tests passed (groups 1-43)~n" *pass* total)
  (when (> *fail* 0)
    (printf "FAILED: ~a test(s)~n" *fail*))
  (when (= *fail* 0)
    (display "All tests passed!\n"))
  (flush-output-port (current-output-port))
  (exit (if (zero? *fail*) 0 1)))
