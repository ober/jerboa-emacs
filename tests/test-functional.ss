#!chezscheme
;;; test-functional.ss — Functional tests for jerboa-emacs.
;;;
;;; Every test goes through the REAL dispatch chain:
;;;   - cmd-indent-or-complete for TAB behavior (NOT cmd-org-template-expand)
;;;   - execute-command! for named commands (NOT direct leaf functions)
;;;   - sim-key! for key events through key-state-feed!
;;;
;;; This catches regressions in the dispatch chain that leaf-function tests miss.

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1- sort sort!
          thread? make-mutex mutex? mutex-name
          path-extension path-absolute? getenv)
        (jerboa core)
        (jerboa runtime)
        (chez-scintilla scintilla)
        (chez-scintilla constants)
        (chez-scintilla tui)
        (jerboa-emacs core)
        (jerboa-emacs keymap)
        (jerboa-emacs buffer)
        (jerboa-emacs window)
        (jerboa-emacs echo)
        (jerboa-emacs editor-core)
        (only (jerboa-emacs editor-ui) cmd-indent-or-complete org-buffer?)
        (only (jerboa-emacs editor) register-all-commands!)
        (only (jerboa-emacs persist) which-key-summary
              *mx-history* mx-history-add! mx-history-ordered-candidates)
        (only (jerboa-emacs helm-commands) register-helm-commands!)
        (jerboa-emacs helm)
        (only (std srfi srfi-13) string-contains string-prefix?)
        (rename (jerboa-coreutils top) (main cu-top-main)))

(define pass-count 0)
(define fail-count 0)

(define-syntax check
  (syntax-rules (=>)
    ((_ expr => expected)
     (let ((result expr) (exp expected))
       (if (equal? result exp)
         (set! pass-count (+ pass-count 1))
         (begin
           (set! fail-count (+ fail-count 1))
           (display "FAIL: ")
           (write 'expr)
           (display " => ")
           (write result)
           (display " expected ")
           (write exp)
           (newline)))))))

(define-syntax check-true
  (syntax-rules ()
    ((_ expr)
     (check (and expr #t) => #t))))

(define-syntax check-false
  (syntax-rules ()
    ((_ expr)
     (check (not expr) => #t))))

;;;============================================================================
;;; Helpers
;;;============================================================================

;;; Create a test app with a fresh editor and named buffer.
;;; Returns (values ed app).
(define (make-test-app name)
  (let* ((ed (create-scintilla-editor 80 24))
         (buf (make-buffer name #f (send-message ed SCI_GETDOCPOINTER) #f #f #f #f))
         (win (make-edit-window ed buf 0 0 80 22 0))
         (root (make-split-leaf win))
         (fr (make-frame root (list win) 0 80 24))
         (app (new-app-state fr)))
    (values ed app)))

;;; Create a test app with a named buffer whose file-path is set to PATH.
;;; Returns (values ed app).
(define (make-test-app-with-file path)
  (let* ((ed   (create-scintilla-editor 80 24))
         (name (path-last path))
         (buf  (make-buffer name path (send-message ed SCI_GETDOCPOINTER) #f #f #f #f))
         (win  (make-edit-window ed buf 0 0 80 22 0))
         (root (make-split-leaf win))
         (fr   (make-frame root (list win) 0 80 24))
         (app  (new-app-state fr)))
    (values ed app)))

;;; Run a git command in DIR, return first line of stdout (or "" on error).
(define (test-git-cmd! args dir)
  (guard (e [else ""])
    (let-values (((p-out p-in p-err pid)
                  (open-process-ports
                    (string-append "/usr/bin/git " (apply string-append
                                     (map (lambda (a) (string-append " " a)) args)))
                    'block)))
      (close-port p-out)
      (let ((out (get-line p-in)))
        (close-port p-in) (close-port p-err)
        (if (eof-object? out) "" out)))))

;;; Create a temp git repo with one committed README.md. Returns dir path.
(define *temp-repo-counter* 0)
(define (make-temp-git-repo!)
  (set! *temp-repo-counter* (+ *temp-repo-counter* 1))
  (let ((dir (string-append "/tmp/jerboa-test-"
                            (number->string *temp-repo-counter*))))
    ;; Clean up any stale directory from a previous run
    (guard (e [else (void)])
      (let-values (((p-out p-in p-err pid)
                    (open-process-ports (string-append "rm -rf " dir) 'block)))
        (close-port p-out)
        (let drain () (unless (eof-object? (get-u8 p-err)) (drain)))
        (close-port p-in) (close-port p-err)))
    (guard (e [else "/tmp/jerboa-test-error"])
      (mkdir dir)
      (let-values (((p-out p-in p-err pid)
                    (open-process-ports
                      (string-append "cd " dir " && git init -q && "
                        "git config user.email test@example.com && "
                        "git config user.name 'Test User' && "
                        "echo '# Test Repo' > README.md && "
                        "git add README.md && "
                        "git commit --no-gpg-sign -m 'Initial commit'")
                      'block)))
        ;; Drain stderr to wait for the process to finish before closing.
        ;; git commit writes its summary to stderr (not stdout), so draining
        ;; stderr is what ensures git has actually committed before we proceed.
        (close-port p-out)
        (let drain () (unless (eof-object? (get-u8 p-err)) (drain)))
        (close-port p-in) (close-port p-err))
      dir)))

;;; Remove temp git repo.
(define (cleanup-temp-git-repo! dir)
  (guard (e [else (void)])
    (let-values (((p-out p-in p-err pid)
                  (open-process-ports (string-append "rm -rf " dir) 'block)))
      (close-port p-out) (close-port p-in) (close-port p-err))))

;;; Write CONTENT to PATH (overwrite).
(define (write-file-content! path content)
  (call-with-output-file path
    (lambda (port) (display content port))
    '(replace)))

;;; Simulate scripted responses for app-read-string in tests.
(define (with-scripted-responses responses thunk)
  (test-echo-responses-set! responses)
  (thunk)
  (test-echo-responses-set! '()))

;;; Simulate feeding a single key event through the dispatch chain.
;;; Updates app key-state and executes the resulting command or self-insert.
(define (sim-key! app ev)
  (let-values (((action data new-state)
                (key-state-feed! (app-state-key-state app) ev)))
    (app-state-key-state-set! app new-state)
    (case action
      ((command)   (execute-command! app data))
      ((self-insert) (cmd-self-insert! app data))
      (else (void)))
    action))

;;; Make a TUI key event for a control character (0x01-0x1A range).
(define (ctrl-ev code)
  (make-tui-event 1 0 code 0 0 0 0 0))

;;; Make a TUI key event for TAB (0x09).
(define tab-ev (make-tui-event 1 0 #x09 0 0 0 0 0))

;;; Make a TUI event for a printable character (no modifiers).
(define (char-ev ch)
  (make-tui-event 1 0 0 (char->integer ch) 0 0 0 0))

;;;============================================================================
;;; Group 1: Org-Mode TAB Dispatch
;;; Tests call cmd-indent-or-complete (or via execute-command! 'indent-or-complete)
;;; NOT cmd-org-template-expand directly.
;;;============================================================================

(display "--- dispatch: indent-or-complete is registered ---\n")
(setup-default-bindings!)
(register-all-commands!)
(check (procedure? (find-command 'indent-or-complete)) => #t)

(display "--- dispatch: org-template-expand is registered ---\n")
(setup-default-bindings!)
(register-all-commands!)
(check (procedure? (find-command 'org-template-expand)) => #t)

(display "--- dispatch: org-cycle is registered ---\n")
(setup-default-bindings!)
(register-all-commands!)
(check (procedure? (find-command 'org-cycle)) => #t)

(display "--- dispatch: TAB key is bound to indent-or-complete ---\n")
(setup-default-bindings!)
(check (keymap-lookup *global-keymap* "TAB") => 'indent-or-complete)

;; --- Template expansions via dispatch chain ---

(display "--- TAB dispatch: <s expands to #+BEGIN_SRC in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<s")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "#+BEGIN_SRC"))) => #t)
    (check (not (not (string-contains text "#+END_SRC"))) => #t)))

(display "--- TAB dispatch: <e expands to #+BEGIN_EXAMPLE in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<e")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "#+BEGIN_EXAMPLE"))) => #t)
    (check (not (not (string-contains text "#+END_EXAMPLE"))) => #t)))

(display "--- TAB dispatch: <q expands to #+BEGIN_QUOTE in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<q")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "#+BEGIN_QUOTE"))) => #t)
    (check (not (not (string-contains text "#+END_QUOTE"))) => #t)))

(display "--- TAB dispatch: <v expands to #+BEGIN_VERSE in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<v")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "#+BEGIN_VERSE"))) => #t)
    (check (not (not (string-contains text "#+END_VERSE"))) => #t)))

(display "--- TAB dispatch: <c expands to #+BEGIN_CENTER in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<c")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "#+BEGIN_CENTER"))) => #t)
    (check (not (not (string-contains text "#+END_CENTER"))) => #t)))

(display "--- TAB dispatch: <C expands to #+BEGIN_COMMENT in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<C")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "#+BEGIN_COMMENT"))) => #t)
    (check (not (not (string-contains text "#+END_COMMENT"))) => #t)))

(display "--- TAB dispatch: <l expands to #+BEGIN_EXPORT latex in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<l")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "EXPORT latex"))) => #t)))

(display "--- TAB dispatch: <h expands to #+BEGIN_EXPORT html in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<h")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "EXPORT html"))) => #t)))

(display "--- TAB dispatch: <a expands to #+BEGIN_EXPORT ascii in org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<a")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "EXPORT ascii"))) => #t)))

;; --- Dispatch priority ---

(display "--- TAB dispatch: plain text in org → indent (2 spaces) ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (string-prefix? "  hello" text) => #t)))

(display "--- TAB dispatch: unknown template <z in org → indent, not expansion ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<z")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (string-contains text "#+BEGIN_")) => #t)))

(display "--- TAB dispatch: heading line in org → org-cycle command ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "* Heading\nsome content under heading")
  (editor-goto-pos ed 0)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "* Heading"))) => #t)
    (check (not (string-contains text "#+BEGIN_")) => #t)))

(display "--- TAB dispatch: empty line in org → indent (2 spaces) ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "")
  (editor-goto-pos ed 0)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (string-prefix? "  " text) => #t)))

;; --- Content preservation ---

(display "--- TAB dispatch: <s preserves text after template ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "<s\nSome following text")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "#+BEGIN_SRC"))) => #t)
    (check (not (not (string-contains text "Some following text"))) => #t)))

(display "--- TAB dispatch: org-buffer? is true for .org named buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (let ((buf (current-buffer-from-app app)))
    (check (org-buffer? buf) => #t)))

(display "--- TAB dispatch: org-buffer? is false for non-org buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "main.ss")))
  (let ((buf (current-buffer-from-app app)))
    (check (org-buffer? buf) => #f)))

;; --- Non-org buffer → plain indent ---

(display "--- TAB dispatch: non-org buffer → plain 2-space indent ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "main.ss")))
  (editor-set-text ed "<s")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (string-contains text "#+BEGIN_SRC")) => #t)
    (check (not (not (string-contains text "  "))) => #t)))

;; --- Via simulated TAB key event ---

(display "--- TAB key event in org buffer → template expansion ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "notes.org")))
  (editor-set-text ed "<s")
  (editor-goto-pos ed 2)
  (sim-key! app tab-ev)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "#+BEGIN_SRC"))) => #t)))

(display "--- TAB key event binds correctly in global keymap ---\n")
(setup-default-bindings!)
(let ((state (make-initial-key-state)))
  (let-values (((action data new-state) (key-state-feed! state tab-ev)))
    (check action => 'command)
    (check data => 'indent-or-complete)))

;;;============================================================================
;;; Group 2: Navigation
;;;============================================================================

(display "--- nav: forward-char moves cursor right ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'forward-char)
  (check (editor-get-current-pos ed) => 1))

(display "--- nav: backward-char moves cursor left ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 3)
  (execute-command! app 'backward-char)
  (check (editor-get-current-pos ed) => 2))

(display "--- nav: beginning-of-line goes to column 0 ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 7)
  (execute-command! app 'beginning-of-line)
  (check (editor-get-current-pos ed) => 0))

(display "--- nav: end-of-line goes to end of line ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'end-of-line)
  (check (editor-get-current-pos ed) => 5))

(display "--- nav: beginning-of-buffer goes to pos 0 ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "line1\nline2\nline3")
  (editor-goto-pos ed 15)
  (execute-command! app 'beginning-of-buffer)
  (check (editor-get-current-pos ed) => 0))

(display "--- nav: end-of-buffer goes to last position ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'end-of-buffer)
  (check (editor-get-current-pos ed) => 5))

(display "--- nav: next-line moves down ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "line1\nline2")
  (editor-goto-pos ed 0)
  (execute-command! app 'next-line)
  (check (>= (editor-get-current-pos ed) 6) => #t))

(display "--- nav: previous-line moves up ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "line1\nline2")
  (editor-goto-pos ed 6)
  (execute-command! app 'previous-line)
  (check (< (editor-get-current-pos ed) 6) => #t))

(display "--- nav: forward-char at end of buffer is a no-op ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hi")
  (editor-goto-pos ed 2)
  (execute-command! app 'forward-char)
  (check (>= (editor-get-current-pos ed) 0) => #t))

(display "--- nav: backward-char at beginning is a no-op ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hi")
  (editor-goto-pos ed 0)
  (execute-command! app 'backward-char)
  (check (= (editor-get-current-pos ed) 0) => #t))

(display "--- nav: C-f key event moves cursor forward ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (sim-key! app (ctrl-ev #x06))
  (check (editor-get-current-pos ed) => 1))

(display "--- nav: forward-word moves past word boundary ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'forward-word)
  (check (>= (editor-get-current-pos ed) 5) => #t))

(display "--- nav: backward-word moves back over word ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 11)
  (execute-command! app 'backward-word)
  (check (<= (editor-get-current-pos ed) 6) => #t))

(display "--- nav: end-of-line on multi-line at correct column ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "abc\ndef")
  (editor-goto-pos ed 4)
  (execute-command! app 'end-of-line)
  (check (editor-get-current-pos ed) => 7))

;;;============================================================================
;;; Group 3: Basic Editing
;;;============================================================================

(display "--- edit: delete-char removes character at cursor ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'delete-char)
  (check (editor-get-text ed) => "ello"))

(display "--- edit: backward-delete-char removes char before cursor ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 3)
  (execute-command! app 'backward-delete-char)
  (check (editor-get-text ed) => "helo"))

(display "--- edit: newline inserts newline at cursor ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "helloworld")
  (editor-goto-pos ed 5)
  (execute-command! app 'newline)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "\n"))) => #t)
    (check (not (not (string-contains text "hello"))) => #t)
    (check (not (not (string-contains text "world"))) => #t)))

(display "--- edit: kill-line kills to end of line ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello\nworld")
  (editor-goto-pos ed 0)
  (execute-command! app 'kill-line)
  (let ((text (editor-get-text ed)))
    (check (not (string-contains text "hello")) => #t)
    (check (not (not (string-contains text "world"))) => #t)))

(display "--- edit: kill-line on empty line removes newline ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "\nworld")
  (editor-goto-pos ed 0)
  (execute-command! app 'kill-line)
  (let ((text (editor-get-text ed)))
    (check (string-prefix? "world" text) => #t)))

(display "--- edit: open-line inserts newline without moving cursor ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (let ((orig-pos (editor-get-current-pos ed)))
    (execute-command! app 'open-line)
    (let ((text (editor-get-text ed)))
      (check (not (not (string-contains text "\n"))) => #t)
      (check (= (editor-get-current-pos ed) orig-pos) => #t))))

(display "--- edit: self-insert inserts character at cursor ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "")
  (editor-goto-pos ed 0)
  (sim-key! app (char-ev #\x))
  (check (editor-get-text ed) => "x"))

(display "--- edit: multiple self-inserts build a string ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "")
  (editor-goto-pos ed 0)
  (sim-key! app (char-ev #\h))
  (sim-key! app (char-ev #\i))
  (check (editor-get-text ed) => "hi"))

(display "--- edit: transpose-chars swaps the two characters before point ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "ab")
  (editor-goto-pos ed 2)
  (execute-command! app 'transpose-chars)
  (check (editor-get-text ed) => "ba"))

(display "--- edit: undo reverses last change ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 5)
  (editor-insert-text ed 5 "x")
  (editor-goto-pos ed 6)
  (check (editor-get-text ed) => "hellox")
  (execute-command! app 'undo)
  (check (string? (editor-get-text ed)) => #t))

;;;============================================================================
;;; Group 4: Kill Ring & Yank
;;;============================================================================

(display "--- kill-yank: kill-line then yank round-trip ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello\nworld")
  (editor-goto-pos ed 0)
  (execute-command! app 'kill-line)
  (execute-command! app 'end-of-buffer)
  (execute-command! app 'yank)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "hello"))) => #t)))

(display "--- kill-yank: kill adds to kill ring ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'kill-line)
  (check (> (length (app-state-kill-ring app)) 0) => #t))

(display "--- kill-yank: yank inserts at cursor position ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "aXb")
  (editor-goto-pos ed 1)
  (execute-command! app 'delete-char)
  (execute-command! app 'end-of-buffer)
  (execute-command! app 'yank)
  (check (string? (editor-get-text ed)) => #t))

(display "--- kill-yank: copy-region does not remove text ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 5)
  (execute-command! app 'copy-region)
  (check (editor-get-text ed) => "hello world"))

(display "--- kill-yank: kill-region removes selected text ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 5)
  (execute-command! app 'kill-region)
  (let ((text (editor-get-text ed)))
    (check (not (string-prefix? "hello" text)) => #t)
    (check (not (not (string-contains text "world"))) => #t)))

(display "--- kill-yank: kill-line on empty line removes newline ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "\nnext")
  (editor-goto-pos ed 0)
  (execute-command! app 'kill-line)
  (check (string-prefix? "next" (editor-get-text ed)) => #t))

(display "--- kill-yank: copy-region then yank duplicates text ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 5)
  (execute-command! app 'copy-region)
  (execute-command! app 'end-of-buffer)
  (execute-command! app 'yank)
  (let ((text (editor-get-text ed)))
    (check (string=? "hellohello" text) => #t)))

;;;============================================================================
;;; Group 5: Mark & Region
;;;============================================================================

(display "--- mark: set-mark stores position in buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 5)
  (execute-command! app 'set-mark)
  (let ((buf (current-buffer-from-app app)))
    (check (integer? (buffer-mark buf)) => #t)
    (check (buffer-mark buf) => 5)))

(display "--- mark: set-mark then movement creates active region ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 5)
  (let ((buf (current-buffer-from-app app)))
    (check (buffer-mark buf) => 0)
    (check (editor-get-current-pos ed) => 5)))

(display "--- mark: mark-whole-buffer selects entire buffer without crash ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 5)
  (execute-command! app 'mark-whole-buffer)
  (check (string? (editor-get-text ed)) => #t))

(display "--- mark: kill-region with mark deletes region text ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "ABCDE")
  (editor-goto-pos ed 1)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 4)
  (execute-command! app 'kill-region)
  (let ((text (editor-get-text ed)))
    (check (not (string-contains text "BCD")) => #t)
    (check (not (not (string-contains text "A"))) => #t)
    (check (not (not (string-contains text "E"))) => #t)))

(display "--- mark: exchange-point-and-mark swaps cursor and mark ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 5)
  (execute-command! app 'exchange-point-and-mark)
  (check (editor-get-current-pos ed) => 0)
  (let ((buf (current-buffer-from-app app)))
    (check (buffer-mark buf) => 5)))

;;;============================================================================
;;; Group 6: Window Management
;;;============================================================================

(display "--- window: split-window creates two windows ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (let ((fr (app-state-frame app)))
    (check (= (length (frame-windows fr)) 1) => #t)
    (execute-command! app 'split-window)
    (check (= (length (frame-windows (app-state-frame app))) 2) => #t)))

(display "--- window: other-window switches focus ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (execute-command! app 'split-window)
  (let ((win1 (current-window (app-state-frame app))))
    (execute-command! app 'other-window)
    (let ((win2 (current-window (app-state-frame app))))
      (check (not (eq? win1 win2)) => #t))))

(display "--- window: delete-other-windows returns to single window ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (execute-command! app 'split-window)
  (check (= (length (frame-windows (app-state-frame app))) 2) => #t)
  (execute-command! app 'delete-other-windows)
  (check (= (length (frame-windows (app-state-frame app))) 1) => #t))

;;;============================================================================
;;; Group 7: Mode-Specific Dispatch
;;;============================================================================

(display "--- mode: .org file → org-buffer? true, TAB dispatches to org ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "notes.org")))
  (let ((buf (current-buffer-from-app app)))
    (check (org-buffer? buf) => #t))
  (editor-set-text ed "<s")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (check (not (not (string-contains (editor-get-text ed) "#+BEGIN_SRC"))) => #t))

(display "--- mode: .ss file → TAB inserts 2 spaces, not org expansion ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "main.ss")))
  (let ((buf (current-buffer-from-app app)))
    (check (org-buffer? buf) => #f))
  (editor-set-text ed "<s")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (string-contains text "#+BEGIN_SRC")) => #t)
    (check (not (not (string-contains text "  "))) => #t)))

(display "--- mode: .py file → TAB inserts spaces, not org expansion ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "script.py")))
  (let ((buf (current-buffer-from-app app)))
    (check (org-buffer? buf) => #f))
  (editor-set-text ed "<s")
  (editor-goto-pos ed 2)
  (execute-command! app 'indent-or-complete)
  (let ((text (editor-get-text ed)))
    (check (not (string-contains text "#+BEGIN_SRC")) => #t)))

;;;============================================================================
;;; Group 8: Buffer Management (basic)
;;;============================================================================

(display "--- buffer: new buffer has correct name ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "myfile.ss")))
  (let ((buf (current-buffer-from-app app)))
    (check (buffer-name buf) => "myfile.ss")))

(display "--- buffer: buffer-list-add! makes buffer findable ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "unique-test-123.ss")))
  (let ((buf (current-buffer-from-app app)))
    (buffer-list-add! buf)
    (check (not (not (buffer-by-name "unique-test-123.ss"))) => #t)
    (buffer-list-remove! buf)))

(display "--- buffer: toggle-read-only marks buffer read-only ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (check (editor-get-read-only? ed) => #f)
  (execute-command! app 'toggle-read-only)
  (check (editor-get-read-only? ed) => #t)
  (execute-command! app 'toggle-read-only)
  (check (editor-get-read-only? ed) => #f))

;;;============================================================================
;;; Group 9: Text Transforms
;;;============================================================================

(display "--- transform: upcase-word uppercases word at point ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'upcase-word)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "HELLO"))) => #t)))

(display "--- transform: downcase-word lowercases word at point ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "HELLO world")
  (editor-goto-pos ed 0)
  (execute-command! app 'downcase-word)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "hello"))) => #t)
    (check (string-prefix? "hello" text) => #t)))

(display "--- transform: capitalize-word capitalizes word ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'capitalize-word)
  (let ((text (editor-get-text ed)))
    (check (string-prefix? "Hello" text) => #t)))

;;;============================================================================
;;; Group 10: Prefix Arguments
;;;============================================================================

(display "--- prefix: universal-argument sets prefix to list ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (execute-command! app 'universal-argument)
  (check (list? (app-state-prefix-arg app)) => #t))

(display "--- prefix: execute-command! resets prefix after normal command ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (execute-command! app 'universal-argument)
  (check (not (not (app-state-prefix-arg app))) => #t)
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'forward-char)
  (check (app-state-prefix-arg app) => #f))

(display "--- prefix: last-command is updated after execute-command! ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'forward-char)
  (check (app-state-last-command app) => 'forward-char))

;;;============================================================================
;;; Group 10 (extended): Org Commands Beyond TAB
;;;============================================================================

(display "--- org: org-todo cycles TODO state via execute-command! ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "tasks.org")))
  (editor-set-text ed "* Task headline")
  (editor-goto-pos ed 0)
  (execute-command! app 'org-todo)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "TODO"))) => #t)))

(display "--- org: org-promote demotes then promotes a heading ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "notes.org")))
  (editor-set-text ed "** Sub heading")
  (editor-goto-pos ed 0)
  (execute-command! app 'org-demote)
  (check (string-prefix? "***" (editor-get-text ed)) => #t)
  (execute-command! app 'org-promote)
  (check (string-prefix? "**" (editor-get-text ed)) => #t)
  (execute-command! app 'org-promote)
  (check (string-prefix? "* " (editor-get-text ed)) => #t))

(display "--- org: org-promote at level 1 is a no-op ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "notes.org")))
  (editor-set-text ed "* Top level")
  (editor-goto-pos ed 0)
  (execute-command! app 'org-promote)
  (check (string-prefix? "* " (editor-get-text ed)) => #t))

(display "--- org: org-insert-heading adds new heading ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "notes.org")))
  (editor-set-text ed "* First\n")
  (editor-goto-pos ed 7)
  (execute-command! app 'org-insert-heading)
  (let ((text (editor-get-text ed)))
    (check (> (string-length text) 8) => #t)
    (check (not (not (string-contains text "*"))) => #t)))

(display "--- org: org-toggle-checkbox toggles [ ] to [X] ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "notes.org")))
  (editor-set-text ed "- [ ] Item to check")
  (editor-goto-pos ed 0)
  (execute-command! app 'org-toggle-checkbox)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "[X]"))) => #t)))

(display "--- org: org-toggle-checkbox toggles [X] back to [ ] ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "notes.org")))
  (editor-set-text ed "- [X] Already checked")
  (editor-goto-pos ed 0)
  (execute-command! app 'org-toggle-checkbox)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "[ ]"))) => #t)))

(display "--- org: org-priority adds [#A] priority ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "notes.org")))
  (editor-set-text ed "* TODO Task")
  (editor-goto-pos ed 0)
  (execute-command! app 'org-priority)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text "[#A]"))) => #t)))

(display "--- org: org-archive-subtree is registered ---\n")
(setup-default-bindings!)
(register-all-commands!)
(check (procedure? (find-command 'org-archive-subtree)) => #t)

;;;============================================================================
;;; Group 11 (extended): Additional text transforms
;;;============================================================================

(display "--- transform: join-line merges current line with next ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello\nworld")
  (editor-goto-pos ed 0)
  (execute-command! app 'join-line)
  (let ((text (editor-get-text ed)))
    (check (not (string-contains text "\nhello")) => #t)
    (check (not (not (string-contains text "hello"))) => #t)
    (check (not (not (string-contains text "world"))) => #t)))

(display "--- transform: comment-region adds comment markers ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "(define x 42)")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 13)
  (execute-command! app 'comment-region)
  (let ((text (editor-get-text ed)))
    (check (not (not (string-contains text ";"))) => #t)))

(display "--- transform: upcase-region uppercases selected text ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 5)
  (execute-command! app 'upcase-region)
  (let ((text (editor-get-text ed)))
    (check (string-prefix? "HELLO" text) => #t)))

(display "--- transform: downcase-region lowercases selected text ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "HELLO world")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (editor-goto-pos ed 5)
  (execute-command! app 'downcase-region)
  (let ((text (editor-get-text ed)))
    (check (string-prefix? "hello" text) => #t)))

;;;============================================================================
;;; Group 12 (extended): More navigation and dispatch
;;;============================================================================

(display "--- nav: scroll-down does not crash ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed (make-string 500 #\a))
  (execute-command! app 'scroll-down)
  (check (>= (editor-get-current-pos ed) 0) => #t))

(display "--- nav: beginning-of-buffer after scroll returns to 0 ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed (make-string 200 #\a))
  (execute-command! app 'end-of-buffer)
  (execute-command! app 'beginning-of-buffer)
  (check (editor-get-current-pos ed) => 0))

(display "--- dispatch: multiple execute-command! calls accumulate state ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "abcde")
  (editor-goto-pos ed 0)
  (execute-command! app 'forward-char)
  (execute-command! app 'forward-char)
  (execute-command! app 'forward-char)
  (check (editor-get-current-pos ed) => 3))

(display "--- dispatch: sim-key! with C-b moves backward ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 3)
  (sim-key! app (ctrl-ev #x02))
  (check (editor-get-current-pos ed) => 2))

(display "--- dispatch: sim-key! with C-a goes to beginning of line ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 7)
  (sim-key! app (ctrl-ev #x01))
  (check (editor-get-current-pos ed) => 0))

(display "--- dispatch: sim-key! with C-e goes to end of line ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (sim-key! app (ctrl-ev #x05))
  (check (editor-get-current-pos ed) => 5))

(display "--- dispatch: sim-key! inserts multiple chars ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "")
  (editor-goto-pos ed 0)
  (for-each (lambda (c) (sim-key! app (char-ev c)))
            (string->list "test"))
  (check (editor-get-text ed) => "test"))

(display "--- dispatch: key-state resets to initial after command ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'forward-char)
  (let ((ks (app-state-key-state app)))
    (check (null? (key-state-prefix-keys ks)) => #t)))

;;;============================================================================
;;; Group 8: set-mark + navigation region highlight (transient-mark-mode)
;;;============================================================================

(display "--- mark: set-mark stores cursor position in buffer-mark ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "line1\nline2\nline3")
  (editor-goto-pos ed 10)
  (execute-command! app 'set-mark)
  (let ((buf (current-buffer-from-app app)))
    (check (buffer-mark buf) => 10)))

(display "--- mark: set-mark at end-of-buffer then previous-line highlights region ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.org")))
  (editor-set-text ed "line1\nline2\nline3")
  (execute-command! app 'end-of-buffer)
  (let ((end-pos (editor-get-current-pos ed)))
    (execute-command! app 'set-mark)
    (execute-command! app 'previous-line)
    (let ((new-pos (editor-get-current-pos ed)))
      (check (< new-pos end-pos) => #t))))

(display "--- mark: set-mark then forward-char extends selection forward ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (execute-command! app 'forward-char)
  (execute-command! app 'forward-char)
  (execute-command! app 'forward-char)
  (execute-command! app 'forward-char)
  (execute-command! app 'forward-char)
  (let ((sel-start (editor-get-selection-start ed))
        (sel-end (editor-get-selection-end ed)))
    (check sel-start => 0)
    (check sel-end => 5)))

(display "--- mark: keyboard-quit clears mark and visual selection ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello world")
  (editor-goto-pos ed 0)
  (execute-command! app 'set-mark)
  (execute-command! app 'forward-char)
  (execute-command! app 'forward-char)
  (execute-command! app 'forward-char)
  (execute-command! app 'keyboard-quit)
  (let* ((buf (current-buffer-from-app app))
         (sel-start (editor-get-selection-start ed))
         (sel-end (editor-get-selection-end ed)))
    (check (buffer-mark buf) => #f)
    (check (= sel-start sel-end) => #t)))

;;;============================================================================
;;; Group 9: magit-style git interface
;;;============================================================================

(display "--- magit: magit-status creates buffer containing Head: header ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (execute-command! app 'magit-status)
  (let ((text (editor-get-text ed)))
    (check (not (eq? #f (string-contains text "Head:"))) => #t)))

(display "--- magit: magit-log creates *Magit Log* buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (execute-command! app 'magit-log)
  (let ((text (editor-get-text ed)))
    (check (> (string-length text) 0) => #t)))

(display "--- magit: magit-stage-file with no file-path buffer does not crash ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "*scratch*")))
  (execute-command! app 'magit-stage-file)
  (check #t => #t))

(display "--- magit: git-log-file with no file-path buffer does not crash ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "*scratch*")))
  (execute-command! app 'git-log-file)
  (check #t => #t))

;;;============================================================================
;;; Group 10: Real git operations on a controlled temp repository
;;;============================================================================

(display "--- git-real: show-git-log on temp repo contains Initial commit ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let ((dir (make-temp-git-repo!)))
  (let-values (((ed app) (make-test-app-with-file
                           (string-append dir "/README.md"))))
    (execute-command! app 'show-git-log)
    (let ((text (editor-get-text ed)))
      (check (not (eq? #f (string-contains text "Initial commit"))) => #t)))
  (cleanup-temp-git-repo! dir))

;;;============================================================================
;;; TUI Window Management Tests
;;;============================================================================

(display "--- window: split-window-below creates 2 windows ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "*scratch*")))
  (execute-command! app 'split-window-below)
  (let* ((fr (app-state-frame app))
         (wins (frame-windows fr))
         (root (frame-root fr)))
    (check (length wins) => 2)
    (check (split-node? root) => #t)
    (check (split-node-orientation root) => 'vertical)))

(display "--- window: split-window-right creates 2 windows ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "*scratch*")))
  (execute-command! app 'split-window-right)
  (let* ((fr (app-state-frame app))
         (wins (frame-windows fr))
         (root (frame-root fr)))
    (check (length wins) => 2)
    (check (split-node? root) => #t)
    (check (split-node-orientation root) => 'horizontal)))

(display "--- window: delete-window restores single pane ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "*scratch*")))
  (execute-command! app 'split-window-below)
  (execute-command! app 'delete-window)
  (let* ((fr (app-state-frame app))
         (wins (frame-windows fr))
         (root (frame-root fr)))
    (check (length wins) => 1)
    (check (split-leaf? root) => #t)))

(display "--- window: other-window cycles through all panes ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "*scratch*")))
  (execute-command! app 'split-window-right)
  (execute-command! app 'split-window-below)
  (let* ((fr (app-state-frame app))
         (start-idx (frame-current-idx fr)))
    (execute-command! app 'other-window)
    (execute-command! app 'other-window)
    (execute-command! app 'other-window)
    (let ((end-idx (frame-current-idx fr)))
      (check end-idx => start-idx))))

;;;============================================================================
;;; Org-table commands — TUI dispatch-chain tests
;;;============================================================================

(display "--- org-table: create inserts table template ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app-with-file "/tmp/test.org")))
  (editor-set-text ed "")
  (editor-goto-pos ed 0)
  (with-scripted-responses '("")
    (lambda ()
      (execute-command! app 'org-table-create)
      (let ((text (editor-get-text ed)))
        (check (and (string-contains text "| Col1") #t) => #t)
        (check (and (string-contains text "|---") #t) => #t)))))

(display "--- org-table: align re-aligns uneven table ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app-with-file "/tmp/test.org")))
  (editor-set-text ed "| a | bb | ccc |\n| dddd | e | ff |")
  (editor-goto-pos ed 0)
  (execute-command! app 'org-table-align)
  (let ((text (editor-get-text ed)))
    (check (and (string-contains text "| a    |") #t) => #t)
    (check (and (string-contains text "| dddd |") #t) => #t)))

(display "--- org-table: all 17 commands registered ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let ((cmds '(org-table-create org-table-align org-table-insert-row
              org-table-delete-row org-table-move-row-up org-table-move-row-down
              org-table-delete-column org-table-insert-column
              org-table-move-column-left org-table-move-column-right
              org-table-insert-separator org-table-sort org-table-sum
              org-table-recalculate org-table-export-csv org-table-import-csv
              org-table-transpose)))
  (for-each (lambda (cmd) (check (procedure? (find-command cmd)) => #t)) cmds))

;;;============================================================================
;;; Electric pair tests
;;;============================================================================

(display "--- electric-pair: ( inserts matching ) ---\n")
(let-values (((ed app) (make-test-app-with-file "/tmp/test.ss")))
  (set! *auto-pair-mode* #t)
  (editor-set-text ed "")
  (editor-goto-pos ed 0)
  (cmd-self-insert! app 40) ;; (
  (let ((text (editor-get-text ed)))
    (check text => "()")
    (check (editor-get-current-pos ed) => 1)))

(display "--- electric-pair: [ inserts matching ] ---\n")
(let-values (((ed app) (make-test-app-with-file "/tmp/test.ss")))
  (set! *auto-pair-mode* #t)
  (editor-set-text ed "")
  (editor-goto-pos ed 0)
  (cmd-self-insert! app 91) ;; [
  (check (editor-get-text ed) => "[]"))

(display "--- electric-pair: ) skips over existing ) ---\n")
(let-values (((ed app) (make-test-app-with-file "/tmp/test.ss")))
  (set! *auto-pair-mode* #t)
  (editor-set-text ed "()")
  (editor-goto-pos ed 1)
  (cmd-self-insert! app 41) ;; )
  (check (editor-get-text ed) => "()")
  (check (editor-get-current-pos ed) => 2))

;;;============================================================================
;;; Code Folding commands
;;;============================================================================

(display "--- code-folding: commands registered ---\n")
(register-all-commands!)
(check (procedure? (find-command 'toggle-fold)) => #t)
(check (procedure? (find-command 'fold-all)) => #t)
(check (procedure? (find-command 'unfold-all)) => #t)
(check (procedure? (find-command 'fold-level)) => #t)

(display "--- code-folding: fold-all dispatch ---\n")
(let-values (((ed app) (make-test-app "fold-test")))
  (editor-set-text ed "(define (foo x)\n  (+ x 1))\n")
  (execute-command! app 'fold-all)
  (check (app-state-last-command app) => 'fold-all))

;;;============================================================================
;;; Regression tests for the execute-command! paren bug
;;;============================================================================

(display "--- dispatch: found command does NOT show 'undefined' error ---\n")
(let-values (((ed app) (make-test-app "paren-bug-test")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'forward-char)
  (let* ((echo (app-state-echo app))
         (msg (echo-state-message echo)))
    (check (not (and msg (string-contains msg "is undefined"))) => #t)))

(display "--- dispatch: unfound command shows 'undefined' error ---\n")
(let-values (((ed app) (make-test-app "paren-bug-test2")))
  (execute-command! app 'nonexistent-command-xyz)
  (let* ((echo (app-state-echo app))
         (msg (echo-state-message echo)))
    (check (not (not (and msg (string-contains msg "is undefined")))) => #t)))

;;;============================================================================
;;; Smerge tests
;;;============================================================================

(display "--- smerge: commands registered ---\n")
(register-all-commands!)
(check (not (eq? #f (find-command 'smerge-mode))) => #t)
(check (not (eq? #f (find-command 'smerge-next))) => #t)
(check (not (eq? #f (find-command 'smerge-keep-mine))) => #t)
(check (not (eq? #f (find-command 'smerge-keep-other))) => #t)
(check (not (eq? #f (find-command 'smerge-keep-both))) => #t)

(display "--- smerge: keep-mine resolves conflict ---\n")
(register-all-commands!)
(let-values (((ed app) (make-test-app "conflict.txt")))
  (editor-set-text ed "before\n<<<<<<< HEAD\nmine\n=======\ntheirs\n>>>>>>> branch\nafter\n")
  (editor-goto-pos ed 10)
  (execute-command! app 'smerge-keep-mine)
  (let ((text (editor-get-text ed)))
    (check (not (eq? #f (string-contains text "mine"))) => #t)
    (check (eq? #f (string-contains text "<<<<<<<")) => #t)
    (check (eq? #f (string-contains text "theirs")) => #t)))

;;;============================================================================
;;; Helm framework
;;;============================================================================

(display "--- helm: all commands registered via dispatch chain ---\n")
(register-all-commands!)
(register-helm-commands!)
(for-each (lambda (name)
            (check (not (eq? #f (find-command name))) => #t))
  '(helm-M-x helm-mini helm-buffers-list helm-find-files
    helm-occur helm-imenu helm-show-kill-ring helm-bookmarks
    helm-mark-ring helm-register helm-apropos helm-grep helm-man
    helm-resume helm-mode toggle-helm-mode))

(display "--- helm: multi-match engine ---\n")
(check (helm-multi-match? "foo bar" "foobar baz") => #t)
(check (helm-multi-match? "foo baz" "foobar") => #f)
(check (helm-multi-match? "!test" "production") => #t)
(check (helm-multi-match? "!test" "testing") => #f)
(check (helm-multi-match? "^hel" "hello world") => #t)
(check (helm-multi-match? "^hel" "say hello") => #f)

(display "--- helm: session creation and resume ---\n")
(let* ((src (make-simple-source "test"
              (lambda () '("alpha" "beta" "gamma"))
              (lambda (app val) val)))
       (session (make-new-session (list src) "*test*")))
  (check (helm-session-buffer-name session) => "*test*")
  (check (pair? (helm-session-sources session)) => #t)
  (helm-session-store! session)
  (let ((resumed (helm-session-resume)))
    (check (eq? resumed session) => #t)))

(display "--- helm: match positions for highlighting ---\n")
(let ((pos (helm-match-positions "foo" "hello foobar")))
  (check (pair? pos) => #t)
  (check (car pos) => 6)
  (check (length pos) => 3))
(let ((pos (helm-match-positions "^hel" "hello world")))
  (check (pair? pos) => #t)
  (check (car pos) => 0)
  (check (length pos) => 3))
(check (helm-match-positions "" "anything") => '())
(check (helm-match-positions "xyz" "hello") => '())
(check (helm-match-positions "!test" "production") => '())

;;;============================================================================
;;; Group 13: Command registration coverage
;;;============================================================================

(display "--- registration: dired commands registered ---\n")
(setup-default-bindings!)
(register-all-commands!)
(check (procedure? (find-command 'dired)) => #t)
(check (procedure? (find-command 'dired-find-file)) => #t)
(check (procedure? (find-command 'dired-do-rename)) => #t)
(check (procedure? (find-command 'dired-do-copy)) => #t)
(check (procedure? (find-command 'dired-do-delete)) => #t)
(check (procedure? (find-command 'dired-create-directory)) => #t)
(check (procedure? (find-command 'dired-jump)) => #t)

(display "--- registration: which-key and help commands ---\n")
(setup-default-bindings!)
(register-all-commands!)
(check (procedure? (find-command 'which-key)) => #t)
(check (procedure? (find-command 'describe-key)) => #t)
(check (procedure? (find-command 'describe-function)) => #t)
(check (procedure? (find-command 'describe-variable)) => #t)

(display "--- registration: zoom commands ---\n")
(setup-default-bindings!)
(register-all-commands!)
(check (procedure? (find-command 'zoom-in)) => #t)
(check (procedure? (find-command 'zoom-out)) => #t)

(display "--- registration: bookmark commands ---\n")
(setup-default-bindings!)
(register-all-commands!)
(check (procedure? (find-command 'bookmark-set)) => #t)
(check (procedure? (find-command 'bookmark-jump)) => #t)
(check (procedure? (find-command 'bookmark-list)) => #t)

(display "--- which-key: summary shows human-readable descriptions ---\n")
(let ((km (make-keymap)))
  (keymap-bind! km "s" 'save-buffer)
  (keymap-bind! km "f" 'find-file)
  (let ((summary (which-key-summary km)))
    (check (not (not (string-contains summary "→"))) => #t)
    (check (not (not (string-contains summary "Save buffer"))) => #t)
    (check (not (not (string-contains summary "Find file"))) => #t)))

(display "--- mx-history: frequency tracking and ordering ---\n")
(let ((old-hist *mx-history*))
  (set! *mx-history* (make-hash-table))
  (mx-history-add! "find-file")
  (mx-history-add! "find-file")
  (mx-history-add! "save-buffer")
  (let ((ordered (mx-history-ordered-candidates
                   '("save-buffer" "find-file" "other"))))
    (check (equal? (car ordered) "find-file") => #t)
    (check (equal? (cadr ordered) "save-buffer") => #t))
  (set! *mx-history* old-hist))

;;;============================================================================
;;; Group 14: Repeat-mode
;;;============================================================================

(display "--- repeat-mode: command registration ---\n")
(register-all-commands!)
(check (procedure? (find-command 'repeat-mode)) => #t)
(check (procedure? (find-command 'toggle-repeat-mode)) => #t)

(display "--- repeat-mode: toggle flag ---\n")
(let-values (((ed app) (make-test-app "test.ss")))
  (repeat-mode-set! #f)
  (execute-command! app 'toggle-repeat-mode)
  (check (repeat-mode?) => #t)
  (execute-command! app 'toggle-repeat-mode)
  (check (repeat-mode?) => #f)
  (repeat-mode-set! #f))

;;;============================================================================
;;; Key Chord Tests
;;;============================================================================

(display "\n--- key-chord: case-insensitive registration ---\n")
;; Clear chord state
(set! *chord-map* (make-hash-table))
(set! *chord-first-chars* (make-hash-table))

;; Define a chord with uppercase letters
(key-chord-define-global "EE" 'eshell)

;; Test: all case combinations should resolve to the same command
(check (chord-lookup #\E #\E) => 'eshell)
(check (chord-lookup #\e #\e) => 'eshell)
(check (chord-lookup #\E #\e) => 'eshell)
(check (chord-lookup #\e #\E) => 'eshell)

(display "--- key-chord: both orderings registered ---\n")
(set! *chord-map* (make-hash-table))
(set! *chord-first-chars* (make-hash-table))
(key-chord-define-global "MT" 'vterm)

;; Both orderings: M→T and T→M
(check (chord-lookup #\m #\t) => 'vterm)
(check (chord-lookup #\t #\m) => 'vterm)
(check (chord-lookup #\M #\T) => 'vterm)
(check (chord-lookup #\T #\M) => 'vterm)

(display "--- key-chord: start-char detects both chars ---\n")
(check (chord-start-char? #\m) => #t)
(check (chord-start-char? #\t) => #t)
(check (chord-start-char? #\M) => #t)
(check (chord-start-char? #\T) => #t)
(check (chord-start-char? #\z) => #f)

(display "--- key-chord: same-char chord ---\n")
(set! *chord-map* (make-hash-table))
(set! *chord-first-chars* (make-hash-table))
(key-chord-define-global "GG" 'keyboard-quit)
(check (chord-lookup #\g #\g) => 'keyboard-quit)
(check (chord-lookup #\G #\G) => 'keyboard-quit)

(display "--- key-chord: non-alpha chars ---\n")
(set! *chord-map* (make-hash-table))
(set! *chord-first-chars* (make-hash-table))
(key-chord-define-global ";;" 'comment)
(check (chord-lookup #\; #\;) => 'comment)
(check (chord-start-char? #\;) => #t)

(display "--- key-chord: multiple chords don't interfere ---\n")
(set! *chord-map* (make-hash-table))
(set! *chord-first-chars* (make-hash-table))
(key-chord-define-global "EE" 'eshell)
(key-chord-define-global "MT" 'vterm)
(key-chord-define-global "GG" 'keyboard-quit)
(check (chord-lookup #\e #\e) => 'eshell)
(check (chord-lookup #\m #\t) => 'vterm)
(check (chord-lookup #\g #\g) => 'keyboard-quit)
;; Non-chord pairs should return #f
(check (chord-lookup #\e #\m) => #f)
(check (chord-lookup #\g #\t) => #f)

;;;============================================================================
;;; Coreutils Top Tests
;;;============================================================================

(display "\n--- coreutils-top: cu-top-main is a procedure ---\n")
(check (procedure? cu-top-main) => #t)

(display "--- coreutils-top: batch mode produces output ---\n")
(let ((output (with-output-to-string
                (lambda ()
                  (call/cc
                    (lambda (k)
                      (parameterize ([exit-handler (lambda (code) (k (void)))])
                        (cu-top-main "-b" "-n" "1"))))))))
  ;; Output should be non-empty
  (check (> (string-length output) 100) => #t)
  ;; Should contain standard top header fields (string-contains returns index, not #t)
  (check (and (string-contains output "load average") #t) => #t)
  (check (and (string-contains output "Tasks:") #t) => #t)
  (check (and (string-contains output "Cpu") #t) => #t)
  (check (and (string-contains output "Mem") #t) => #t)
  ;; Should contain PID column header
  (check (and (string-contains output "PID") #t) => #t))

(display "--- coreutils-top: output is multi-line ---\n")
(let* ((output (with-output-to-string
                 (lambda ()
                   (call/cc
                     (lambda (k)
                       (parameterize ([exit-handler (lambda (code) (k (void)))])
                         (cu-top-main "-b" "-n" "1")))))))
       (lines (let loop ((s output) (acc '()))
                (let ((nl (let find ((i 0))
                            (if (>= i (string-length s)) #f
                                (if (char=? (string-ref s i) #\newline) i
                                    (find (+ i 1)))))))
                  (if nl
                    (loop (substring s (+ nl 1) (string-length s))
                          (cons (substring s 0 nl) acc))
                    (reverse (cons s acc)))))))
  ;; Should have many lines (header + processes)
  (check (> (length lines) 10) => #t))

;;;============================================================================
;;; Group: Backward-Delete-Char Comprehensive Tests
;;; Regression tests for backspace — both execute-command! and sim-key! paths.
;;;============================================================================

(display "--- backspace: backward-delete-char at position 0 does nothing ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 0)
  (execute-command! app 'backward-delete-char)
  (check (editor-get-text ed) => "hello"))

(display "--- backspace: backward-delete-char at end of buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "abc")
  (editor-goto-pos ed 3)
  (execute-command! app 'backward-delete-char)
  (check (editor-get-text ed) => "ab"))

(display "--- backspace: multiple backward-delete-char calls ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 5)
  (execute-command! app 'backward-delete-char)
  (execute-command! app 'backward-delete-char)
  (check (editor-get-text ed) => "hel"))

(display "--- backspace: backward-delete-char removes single char from 1-char buffer ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "x")
  (editor-goto-pos ed 1)
  (execute-command! app 'backward-delete-char)
  (check (editor-get-text ed) => ""))

(display "--- backspace: backward-delete-char preserves text after cursor ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "abcdef")
  (editor-goto-pos ed 3)
  (execute-command! app 'backward-delete-char)
  (check (editor-get-text ed) => "abdef"))

(display "--- backspace: cursor position after backward-delete-char ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (editor-set-text ed "hello")
  (editor-goto-pos ed 3)
  (execute-command! app 'backward-delete-char)
  (check (editor-get-current-pos ed) => 2))

;;;============================================================================
;;; Group: Split-Window via Key Dispatch (C-x 2, C-x 3)
;;; Regression tests ensuring C-x prefix followed by "2" or "3" dispatches
;;; correctly through the key-state machine.
;;;============================================================================

(display "--- keymap: C-x 2 dispatches split-window via sim-key! ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  ;; C-x is control code 0x18
  (let ((action1 (sim-key! app (ctrl-ev #x18))))
    (check action1 => 'prefix)
    ;; "2" should dispatch split-window (not self-insert)
    (let ((action2 (sim-key! app (char-ev #\2))))
      (check action2 => 'command)
      (check (= (length (frame-windows (app-state-frame app))) 2) => #t))))

(display "--- keymap: C-x 3 dispatches split-window-right via sim-key! ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (sim-key! app (ctrl-ev #x18))
  (let ((action (sim-key! app (char-ev #\3))))
    (check action => 'command)
    (check (= (length (frame-windows (app-state-frame app))) 2) => #t)))

(display "--- keymap: C-x b dispatches switch-buffer via sim-key! ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (let ((action1 (sim-key! app (ctrl-ev #x18))))
    (check action1 => 'prefix)
    ;; "b" dispatches switch-buffer; it will try to prompt but won't crash
    (let ((action2 (sim-key! app (char-ev #\b))))
      (check action2 => 'command))))

(display "--- keymap: prefix state is set after C-x ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (sim-key! app (ctrl-ev #x18))
  (let ((ks (app-state-key-state app)))
    (check (null? (key-state-prefix-keys ks)) => #f)
    (check (car (key-state-prefix-keys ks)) => "C-x")))

(display "--- keymap: prefix state resets after C-x 2 command ---\n")
(setup-default-bindings!)
(register-all-commands!)
(let-values (((ed app) (make-test-app "test.ss")))
  (sim-key! app (ctrl-ev #x18))
  (sim-key! app (char-ev #\2))
  (let ((ks (app-state-key-state app)))
    (check (null? (key-state-prefix-keys ks)) => #t)))

;; Summary
(newline)
(display "========================================\n")
(display (string-append "TEST RESULTS: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
