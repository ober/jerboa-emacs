#!chezscheme
;;; core.sls — Shared core for jemacs
;;;
;;; Ported from gerbil-emacs/core.ss
;;; Backend-agnostic logic: keymap data structures, command registry,
;;; echo state, buffer metadata, app state, file I/O helpers.
;;; No Scintilla or TUI imports — this module is pure logic.

(library (jerboa-emacs core)
  (export
    ;; Quit flag
    keyboard-quit-exception? make-keyboard-quit-exception
    quit-flag-set! quit-flag-clear! quit-flag?

    ;; Keymap data structures
    make-keymap keymap-bind! keymap-lookup keymap-entries
    key-state? make-key-state
    key-state-keymap key-state-keymap-set!
    key-state-prefix-keys key-state-prefix-keys-set!
    make-initial-key-state

    ;; Global keymaps
    *global-keymap* *ctrl-x-map* *meta-g-map* *help-map*
    *ctrl-x-r-map* *ctrl-c-map* *ctrl-c-l-map* *ctrl-c-m-map*
    lsp-server-command lsp-server-command-set!
    *meta-s-map* *ctrl-x-4-map* *ctrl-x-5-map* *ctrl-x-p-map*
    *all-commands*
    setup-default-bindings!

    ;; Mode keymaps
    *mode-keymaps* *buffer-name-mode-map*
    mode-keymap-set! mode-keymap-get mode-keymap-lookup
    setup-mode-keymaps!

    ;; Echo state
    echo-state? make-echo-state
    echo-state-message echo-state-message-set!
    echo-state-error? echo-state-error?-set!
    make-initial-echo-state
    echo-message! echo-error! echo-clear!
    notification-push! notification-get-recent
    notification-log

    ;; Hooks
    *hooks* add-hook! remove-hook! run-hooks!

    ;; Buffer metadata
    buffer? make-buffer
    buffer-name buffer-name-set!
    buffer-file-path buffer-file-path-set!
    buffer-doc-pointer buffer-doc-pointer-set!
    buffer-mark buffer-mark-set!
    buffer-modified buffer-modified-set!
    buffer-lexer-lang buffer-lexer-lang-set!
    buffer-backup-done? buffer-backup-done?-set!
    buffer-list buffer-list-add! buffer-list-remove!
    buffer-by-name buffer-scratch-name

    ;; App state
    app-state? make-app-state
    app-state-frame app-state-frame-set!
    app-state-echo app-state-echo-set!
    app-state-key-state app-state-key-state-set!
    app-state-running app-state-running-set!
    app-state-last-search app-state-last-search-set!
    app-state-kill-ring app-state-kill-ring-set!
    app-state-kill-ring-idx app-state-kill-ring-idx-set!
    app-state-last-yank-pos app-state-last-yank-pos-set!
    app-state-last-yank-len app-state-last-yank-len-set!
    app-state-last-compile app-state-last-compile-set!
    app-state-bookmarks app-state-bookmarks-set!
    app-state-rect-kill app-state-rect-kill-set!
    app-state-dabbrev-state app-state-dabbrev-state-set!
    app-state-macro-recording app-state-macro-recording-set!
    app-state-macro-last app-state-macro-last-set!
    app-state-macro-named app-state-macro-named-set!
    app-state-mark-ring app-state-mark-ring-set!
    app-state-registers app-state-registers-set!
    app-state-last-command app-state-last-command-set!
    app-state-prefix-arg app-state-prefix-arg-set!
    app-state-prefix-digit-mode? app-state-prefix-digit-mode?-set!
    app-state-key-handler app-state-key-handler-set!
    app-state-winner-history app-state-winner-history-set!
    app-state-winner-history-idx app-state-winner-history-idx-set!
    app-state-tabs app-state-tabs-set!
    app-state-current-tab-idx app-state-current-tab-idx-set!
    app-state-key-lossage app-state-key-lossage-set!
    new-app-state get-prefix-arg

    ;; Frame management
    frame-list frame-list-set!
    current-frame-idx current-frame-idx-set!
    frame-count

    ;; Key lossage
    key-lossage-record! key-lossage->string

    ;; Command registry
    register-command! find-command execute-command!
    *command-docs*
    register-command-doc! command-doc command-name->description
    find-keybinding-for-command setup-command-docs!

    ;; Shared helpers
    electric-indent-mode? electric-indent-mode-set!
    brace-char? safe-string-trim safe-string-trim-both

    ;; File I/O
    read-file-as-string write-string-to-file

    ;; Dired
    *dired-entries*
    dired-buffer? strip-trailing-slash dired-format-listing

    ;; Logging
    init-jemacs-log! jemacs-log!
    init-verbose-log! verbose-log!

    ;; Captured output
    append-error-log! append-output-log!
    get-error-log get-output-log
    clear-error-log! clear-output-log!
    has-captured-output?

    ;; REPL
    repl-buffer? *repl-state*
    eval-expression-string
    load-user-file! load-user-string!

    ;; Fuzzy matching
    fuzzy-match? fuzzy-score fuzzy-filter-sort

    ;; Paredit strict mode
    paredit-strict-mode? paredit-strict-mode-set!

    ;; Helm mode
    helm-mode? helm-mode-set!

    ;; Key translation
    *key-translation-map*
    key-translate! key-translate-char

    ;; Key-chord
    *chord-map* *chord-first-chars*
    chord-timeout chord-timeout-set!
    chord-mode? chord-mode-set!
    key-chord-define-global chord-lookup chord-start-char?

    ;; Repeat-mode
    repeat-mode? repeat-mode-set!
    *repeat-maps*
    active-repeat-map active-repeat-map-set!
    register-repeat-map! register-default-repeat-maps!
    repeat-map-for-command repeat-map-lookup repeat-map-hint
    clear-repeat-map!

    ;; Image buffer
    *editor-window-map* *image-buffer-state*
    image-buffer?
    find-defun-boundaries

    ;; Re-exports from face
    face? make-face face-fg face-bg face-bold face-italic face-underline
    new-face define-face! face-get face-ref set-face-attribute! face-clear!
    default-font-family default-font-size
    set-default-font! get-default-font parse-hex-color rgb->hex
    define-standard-faces! set-frame-font
    load-theme! current-theme-name
    face-fg-rgb face-bg-rgb face-has-bold? face-has-italic? face-has-underline?

    ;; Re-exports from themes
    register-theme! theme-get theme-names
    theme-dark theme-light theme-solarized-dark theme-solarized-light
    theme-monokai theme-gruvbox-dark theme-gruvbox-light
    theme-dracula theme-nord theme-zenburn

    ;; Re-exports from customize
    defvar! custom-get custom-set! custom-reset!
    custom-describe custom-list-group custom-list-all
    custom-groups custom-registered? *custom-registry*
    defhook! hook-doc hook-list-all)

  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std sort)
          (std string)
          (only (std srfi srfi-19) current-date date->string)
          (std misc rwlock)
          (jerboa-emacs customize)
          (jerboa-emacs face)
          (jerboa-emacs themes))

  ;;;============================================================================
  ;;; Quit flag (C-g subprocess interruption)
  ;;;============================================================================

  (defstruct keyboard-quit-exception ())

  (def *quit-flag* #f)

  (def (quit-flag-set!) (set! *quit-flag* #t))
  (def (quit-flag-clear!) (set! *quit-flag* #f))
  (def (quit-flag?) *quit-flag*)

  ;;;============================================================================
  ;;; Keymap data structure
  ;;;============================================================================

  (def (make-keymap) (make-hash-table))

  (def (keymap-bind! km key-str value)
    (hash-put! km key-str value))

  (def (keymap-lookup km key-str)
    (hash-get km key-str))

  (def (keymap-entries km)
    (hash->list km))

  ;;;============================================================================
  ;;; Key state machine for multi-key sequences
  ;;;============================================================================

  (defstruct key-state (keymap prefix-keys))

  ;;; Global keymaps
  (def *global-keymap* (make-keymap))
  (def *ctrl-x-map*   (make-keymap))
  (def *ctrl-x-r-map* (make-keymap))
  (def *ctrl-c-map*   (make-keymap))
  (def *ctrl-c-l-map* (make-keymap))
  (def *ctrl-c-m-map* (make-keymap))
  (def *lsp-server-command* "chez-lsp")
  (def (lsp-server-command) *lsp-server-command*)
  (def (lsp-server-command-set! v) (set! *lsp-server-command* v))
  (def *meta-g-map*   (make-keymap))
  (def *help-map*     (make-keymap))
  (def *meta-s-map*   (make-keymap))
  (def *ctrl-x-4-map* (make-keymap))
  (def *ctrl-x-5-map* (make-keymap))
  (def *ctrl-x-p-map* (make-keymap))

  ;;;============================================================================
  ;;; Mode keymaps — per-mode key bindings
  ;;;============================================================================

  (def *mode-keymaps* (make-hash-table))
  (def *buffer-name-mode-map* (make-hash-table))

  (def (mode-keymap-set! mode-sym km)
    (hash-put! *mode-keymaps* mode-sym km))

  (def (mode-keymap-get mode-sym)
    (hash-get *mode-keymaps* mode-sym))

  (def (mode-keymap-lookup buf key-str)
    (let* ((lang (buffer-lexer-lang buf))
           (km (or (hash-get *mode-keymaps* lang)
                   (hash-get *buffer-name-mode-map* (buffer-name buf)))))
      (and km (keymap-lookup km key-str))))

  (def (setup-mode-keymaps!)
    ;; Buffer name -> mode mapping for special buffers
    (for-each
      (lambda (pair)
        (hash-put! *buffer-name-mode-map* (car pair) (cdr pair)))
      '(("*compilation*" . compilation) ("*Grep*" . grep) ("*Occur*" . occur)
        ("*calendar*" . calendar) ("*eww*" . eww) ("*Magit*" . magit)
        ("*Magit: Commit*" . magit-commit) ("*Magit Log*" . magit-log)
        ("*Magit Commit*" . magit-commit-view) ("*Magit Stash*" . magit-stash)
        ("*Magit Stash Diff*" . magit-stash-diff) ("*Org Capture*" . org-capture)
        ("*IBBuffer*" . ibuffer)))

    ;; Dired mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("n" . next-line) ("p" . previous-line) ("g" . revert-buffer)
          ("d" . dired-do-delete) ("R" . dired-do-rename) ("C" . dired-do-copy)
          ("+" . dired-create-directory) ("q" . kill-buffer-cmd) ("^" . dired)
          ("m" . dired-mark) ("u" . dired-unmark) ("U" . dired-unmark-all)
          ("t" . dired-toggle-marks) ("D" . dired-do-delete-marked) ("x" . dired-do-delete-marked)))
      (mode-keymap-set! 'dired km))

    ;; Compilation mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("n" . next-error) ("p" . previous-error) ("g" . recompile) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'compilation km))

    ;; Grep results mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("n" . next-grep-result) ("p" . previous-grep-result) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'grep km))

    ;; Buffer list mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("n" . next-line) ("p" . previous-line) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'buffer-list km))

    ;; IBBuffer mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("d" . ibuffer-mark-delete) ("s" . ibuffer-mark-save)
          ("u" . ibuffer-unmark) ("x" . ibuffer-execute) ("RET" . ibuffer-goto-buffer)
          ("/" . ibuffer-filter-name) ("S" . ibuffer-sort-name) ("z" . ibuffer-sort-size)
          ("t" . ibuffer-toggle-marks) ("g" . ibuffer-refresh)
          ("n" . next-line) ("p" . previous-line) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'ibuffer km))

    ;; Occur mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("n" . next-line) ("p" . previous-line) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'occur km))

    ;; Calendar mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("p" . calendar-prev-month) ("n" . calendar-next-month)
          ("<" . calendar-prev-year) (">" . calendar-next-year)
          ("." . calendar-today) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'calendar km))

    ;; EWW browser mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("g" . eww) ("l" . eww-back) ("r" . eww-reload) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'eww km))

    ;; Magit mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("s" . magit-stage) ("S" . magit-stage-all) ("u" . magit-unstage)
          ("c" . magit-commit) ("a" . magit-amend) ("d" . magit-diff)
          ("l" . magit-log) ("b" . magit-branch) ("B" . magit-blame)
          ("f" . magit-fetch) ("F" . magit-pull) ("P" . magit-push)
          ("r" . magit-rebase) ("m" . magit-merge) ("z" . magit-stash)
          ("Z" . magit-stash-pop) ("x" . magit-cherry-pick) ("X" . magit-revert-commit)
          ("w" . magit-worktree) ("k" . magit-checkout) ("g" . magit-status)
          ("n" . next-line) ("p" . previous-line) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'magit km))

    ;; Magit commit mode
    (let ((km (make-keymap)))
      (keymap-bind! km "C-c C-c" 'magit-commit-finalize)
      (keymap-bind! km "C-c C-k" 'magit-commit-abort)
      (mode-keymap-set! 'magit-commit km))

    ;; Magit log mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("RET" . magit-log-show-commit) ("n" . next-line) ("p" . previous-line) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'magit-log km))

    ;; Magit commit/diff view (shared by stash-diff)
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("n" . next-line) ("p" . previous-line) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'magit-commit-view km)
      (mode-keymap-set! 'magit-stash-diff km))

    ;; Magit stash list
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("RET" . magit-stash-show) ("n" . next-line) ("p" . previous-line) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'magit-stash km))

    ;; Image mode
    (let ((km (make-keymap)))
      (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
        '(("+" . image-zoom-in) ("=" . image-zoom-in) ("-" . image-zoom-out)
          ("0" . image-zoom-fit) ("1" . image-zoom-reset) ("q" . kill-buffer-cmd)))
      (mode-keymap-set! 'image km))

    ;; Org capture mode
    (let ((km (make-keymap)))
      (keymap-bind! km "C-c C-c" 'org-capture-finalize)
      (keymap-bind! km "C-c C-k" 'org-capture-abort)
      (mode-keymap-set! 'org-capture km)))

  (def (make-initial-key-state)
    (make-key-state *global-keymap* '()))

  ;;;============================================================================
  ;;; Default Emacs-like keybindings
  ;;;============================================================================

  (def (setup-default-bindings!)
    ;; C-x prefix
    (keymap-bind! *global-keymap* "C-x" *ctrl-x-map*)

    ;; Navigation
    (keymap-bind! *global-keymap* "C-f" 'forward-char)
    (keymap-bind! *global-keymap* "C-b" 'backward-char)
    (keymap-bind! *global-keymap* "C-n" 'next-line)
    (keymap-bind! *global-keymap* "C-p" 'previous-line)
    (keymap-bind! *global-keymap* "C-a" 'beginning-of-line)
    (keymap-bind! *global-keymap* "C-e" 'end-of-line)
    (keymap-bind! *global-keymap* "C-v" 'scroll-down)
    (keymap-bind! *global-keymap* "C-l" 'recenter-top-bottom)

    ;; Arrow keys and navigation
    (keymap-bind! *global-keymap* "<up>"     'previous-line)
    (keymap-bind! *global-keymap* "<down>"   'next-line)
    (keymap-bind! *global-keymap* "<left>"   'backward-char)
    (keymap-bind! *global-keymap* "<right>"  'forward-char)
    (keymap-bind! *global-keymap* "<home>"   'beginning-of-line)
    (keymap-bind! *global-keymap* "<end>"    'end-of-line)
    (keymap-bind! *global-keymap* "<prior>"  'scroll-up)
    (keymap-bind! *global-keymap* "<next>"   'scroll-down)
    (keymap-bind! *global-keymap* "<delete>" 'delete-char)

    ;; Alt/Meta navigation
    (keymap-bind! *global-keymap* "M-f" 'forward-word)
    (keymap-bind! *global-keymap* "M-b" 'backward-word)
    (keymap-bind! *global-keymap* "M-v" 'scroll-up)
    (keymap-bind! *global-keymap* "M-<" 'beginning-of-buffer)
    (keymap-bind! *global-keymap* "M->" 'end-of-buffer)

    ;; Editing
    (keymap-bind! *global-keymap* "C-d" 'delete-char)
    (keymap-bind! *global-keymap* "DEL" 'backward-delete-char)
    (keymap-bind! *global-keymap* "C-h" 'backward-delete-char)
    (keymap-bind! *global-keymap* "C-k" 'kill-line)
    (keymap-bind! *global-keymap* "C-y" 'yank)
    (keymap-bind! *global-keymap* "C-w" 'kill-region)
    (keymap-bind! *global-keymap* "M-w" 'copy-region)
    (keymap-bind! *global-keymap* "C-_" 'undo)
    (keymap-bind! *global-keymap* "C-/" 'undo)
    (keymap-bind! *global-keymap* "C-m" 'newline)
    (keymap-bind! *global-keymap* "C-j" 'newline)
    (keymap-bind! *global-keymap* "C-o" 'open-line)

    ;; Mark
    (keymap-bind! *global-keymap* "C-@" 'set-mark)

    ;; Search
    (keymap-bind! *global-keymap* "C-s" 'search-forward)
    (keymap-bind! *global-keymap* "C-r" 'search-backward)

    ;; Function keys
    (keymap-bind! *global-keymap* "<f11>" 'uncomment-region)
    (keymap-bind! *global-keymap* "<f12>" 'comment-region)

    ;; Universal argument
    (keymap-bind! *global-keymap* "C-u" 'universal-argument)

    ;; Digit arguments
    (keymap-bind! *global-keymap* "M-0" 'digit-argument-0)
    (keymap-bind! *global-keymap* "M-1" 'digit-argument-1)
    (keymap-bind! *global-keymap* "M-2" 'digit-argument-2)
    (keymap-bind! *global-keymap* "M-3" 'digit-argument-3)
    (keymap-bind! *global-keymap* "M-4" 'digit-argument-4)
    (keymap-bind! *global-keymap* "M-5" 'digit-argument-5)
    (keymap-bind! *global-keymap* "M-6" 'digit-argument-6)
    (keymap-bind! *global-keymap* "M-7" 'digit-argument-7)
    (keymap-bind! *global-keymap* "M-8" 'digit-argument-8)
    (keymap-bind! *global-keymap* "M-9" 'digit-argument-9)
    (keymap-bind! *global-keymap* "M--" 'negative-argument)

    ;; Misc
    (keymap-bind! *global-keymap* "C-g" 'keyboard-quit)

    ;; C-x commands
    (keymap-bind! *ctrl-x-map* "C-s" 'save-buffer)
    (keymap-bind! *ctrl-x-map* "C-f" 'find-file)
    (keymap-bind! *ctrl-x-map* "C-r" 'recentf-open)
    (keymap-bind! *ctrl-x-map* "C-c" 'quit)
    (keymap-bind! *ctrl-x-map* "b"   'switch-buffer)
    (keymap-bind! *ctrl-x-map* "k"   'kill-buffer-cmd)
    (keymap-bind! *ctrl-x-map* "2"   'split-window)
    (keymap-bind! *ctrl-x-map* "o"   'other-window)
    (keymap-bind! *ctrl-x-map* "0"   'delete-window)
    (keymap-bind! *ctrl-x-map* "1"   'delete-other-windows)
    (keymap-bind! *ctrl-x-map* "3"   'split-window-right)

    ;; REPL
    (keymap-bind! *global-keymap* "M-:" 'eval-expression)
    ;; C-c prefix
    (keymap-bind! *global-keymap* "C-c" *ctrl-c-map*)
    (keymap-bind! *ctrl-c-map* "z"   'repl)

    ;; C-x r prefix (registers/bookmarks/rectangles)
    (keymap-bind! *ctrl-x-map* "r"   *ctrl-x-r-map*)
    (keymap-bind! *ctrl-x-r-map* "m" 'bookmark-set)
    (keymap-bind! *ctrl-x-r-map* "b" 'bookmark-jump)
    (keymap-bind! *ctrl-x-r-map* "l" 'bookmark-list)
    (keymap-bind! *ctrl-x-r-map* "k" 'kill-rectangle)
    (keymap-bind! *ctrl-x-r-map* "d" 'delete-rectangle)
    (keymap-bind! *ctrl-x-r-map* "y" 'yank-rectangle)

    ;; M-x
    (keymap-bind! *global-keymap* "M-x" 'execute-extended-command)

    ;; Goto line (M-g prefix map)
    (keymap-bind! *global-keymap* "M-g" *meta-g-map*)
    (keymap-bind! *meta-g-map* "g"     'goto-line)
    (keymap-bind! *meta-g-map* "M-g"   'goto-line)

    ;; Help (C-h prefix map)
    (keymap-bind! *global-keymap* "C-h" *help-map*)
    (keymap-bind! *help-map* "k"     'describe-key)
    (keymap-bind! *help-map* "b"     'list-bindings)
    (keymap-bind! *help-map* "f"     'describe-command)

    ;; Buffer list
    (keymap-bind! *ctrl-x-map* "C-b" 'list-buffers)

    ;; Query replace
    (keymap-bind! *global-keymap* "M-%" 'query-replace)

    ;; Regex search and replace
    (keymap-bind! *global-keymap* "C-M-s" 'isearch-forward-regexp)
    (keymap-bind! *global-keymap* "C-M-%" 'query-replace-regexp)
    (keymap-bind! *global-keymap* "C-M-i" 'complete-at-point)

    ;; Tab
    (keymap-bind! *global-keymap* "TAB" 'indent-or-complete)

    ;; Eshell, Shell
    (keymap-bind! *ctrl-c-map* "e"   'eshell)
    (keymap-bind! *ctrl-c-map* "$"   'shell)

    ;; Redo
    (keymap-bind! *global-keymap* "M-_" 'redo)

    ;; Toggles
    (keymap-bind! *ctrl-x-map* "l"   'toggle-line-numbers)
    (keymap-bind! *ctrl-x-map* "w"   'toggle-word-wrap)
    (keymap-bind! *ctrl-x-map* "t"   'toggle-whitespace)

    ;; Zoom
    (keymap-bind! *global-keymap* "C-=" 'zoom-in)
    (keymap-bind! *global-keymap* "C--" 'zoom-out)
    (keymap-bind! *ctrl-x-map* "C-0" 'zoom-reset)

    ;; Select all
    (keymap-bind! *ctrl-x-map* "h"   'select-all)

    ;; Duplicate line
    (keymap-bind! *ctrl-x-map* "d"   'dired)

    ;; Comment toggle
    (keymap-bind! *global-keymap* "M-;" 'toggle-comment)

    ;; Transpose chars
    (keymap-bind! *global-keymap* "C-t" 'transpose-chars)

    ;; Case
    (keymap-bind! *global-keymap* "M-u" 'upcase-word)
    (keymap-bind! *global-keymap* "M-l" 'downcase-word)
    (keymap-bind! *global-keymap* "M-c" 'capitalize-word)

    ;; Kill word
    (keymap-bind! *global-keymap* "M-d" 'kill-word)

    ;; What line
    (keymap-bind! *meta-g-map* "l"   'what-line)

    ;; Write file (save as)
    (keymap-bind! *ctrl-x-map* "C-w" 'write-file)

    ;; Beginning/end of defun
    (keymap-bind! *global-keymap* "M-a" 'backward-sentence)
    (keymap-bind! *global-keymap* "M-e" 'forward-sentence)

    ;; Count words
    (keymap-bind! *global-keymap* "M-=" 'count-words)

    ;; Yank-pop
    (keymap-bind! *global-keymap* "M-y" 'yank-pop)

    ;; Occur (search prefix M-s)
    (keymap-bind! *global-keymap* "M-s" *meta-s-map*)
    (keymap-bind! *meta-s-map* "o" 'occur)

    ;; Compile
    (keymap-bind! *ctrl-x-map* "c" 'compile)

    ;; Pipe region to shell
    (keymap-bind! *global-keymap* "M-|" 'shell-command-on-region)

    ;; Sort lines
    (keymap-bind! *ctrl-c-map* "^" 'sort-lines)

    ;; Go to matching paren
    (keymap-bind! *ctrl-c-map* "p" 'goto-matching-paren)

    ;; Join lines
    (keymap-bind! *global-keymap* "M-j" 'join-line)

    ;; Delete blank lines
    (keymap-bind! *ctrl-x-map* "C-o" 'delete-blank-lines)

    ;; Indent region
    (keymap-bind! *ctrl-c-map* "TAB" 'indent-region)

    ;; Case region
    (keymap-bind! *ctrl-x-map* "C-l" 'downcase-region)
    (keymap-bind! *ctrl-x-map* "C-u" 'upcase-region)

    ;; Shell command
    (keymap-bind! *global-keymap* "M-!" 'shell-command)

    ;; Fill paragraph
    (keymap-bind! *global-keymap* "M-q" 'fill-paragraph)

    ;; Insert file
    (keymap-bind! *ctrl-x-map* "i" 'insert-file)

    ;; Dynamic abbreviation / hippie expand
    (keymap-bind! *global-keymap* "M-/" 'hippie-expand)

    ;; Xref
    (keymap-bind! *global-keymap* "M-." 'goto-definition)
    (keymap-bind! *global-keymap* "M-," 'xref-back)

    ;; What cursor position
    (keymap-bind! *ctrl-x-map* "=" 'what-cursor-position)

    ;; Keyboard macros
    (keymap-bind! *ctrl-x-map* "(" 'start-kbd-macro)
    (keymap-bind! *ctrl-x-map* ")" 'end-kbd-macro)
    (keymap-bind! *ctrl-x-map* "e" 'call-last-kbd-macro)

    ;; Mark ring
    (keymap-bind! *ctrl-c-map* "SPC" 'pop-mark)

    ;; Registers
    (keymap-bind! *ctrl-x-r-map* "s" 'copy-to-register)
    (keymap-bind! *ctrl-x-r-map* "i" 'insert-register)
    (keymap-bind! *ctrl-x-r-map* "SPC" 'point-to-register)
    (keymap-bind! *ctrl-x-r-map* "j" 'jump-to-register)
    (keymap-bind! *ctrl-x-r-map* "w" 'window-configuration-to-register)
    (keymap-bind! *ctrl-x-r-map* "f" 'file-to-register)

    ;; Backward kill word
    (keymap-bind! *global-keymap* "M-DEL" 'backward-kill-word)

    ;; Zap to char
    (keymap-bind! *global-keymap* "M-z" 'zap-to-char)

    ;; Go to char position
    (keymap-bind! *meta-g-map* "c" 'goto-char)

    ;; Transpose
    (keymap-bind! *global-keymap* "M-t" 'transpose-words)
    (keymap-bind! *ctrl-x-map* "C-t" 'transpose-lines)

    ;; Repeat
    (keymap-bind! *ctrl-x-map* "z" 'repeat)

    ;; Just one space
    (keymap-bind! *global-keymap* "M-SPC" 'just-one-space)

    ;; Next/previous error
    (keymap-bind! *meta-g-map* "n" 'next-error)
    (keymap-bind! *meta-g-map* "p" 'previous-error)
    (keymap-bind! *meta-g-map* "M-n" 'next-error)
    (keymap-bind! *meta-g-map* "M-p" 'previous-error)

    ;; Kill whole line
    (keymap-bind! *ctrl-c-map* "k" 'kill-whole-line)

    ;; Move line up/down
    (keymap-bind! *global-keymap* "M-<up>" 'move-line-up)
    (keymap-bind! *global-keymap* "M-<down>" 'move-line-down)

    ;; Pipe buffer
    (keymap-bind! *ctrl-c-map* "!" 'pipe-buffer)

    ;; Narrow/widen
    (keymap-bind! *ctrl-c-map* "n" 'narrow-to-region)
    (keymap-bind! *ctrl-c-map* "w" 'widen)

    ;; String insert
    (keymap-bind! *ctrl-c-map* "i" 'string-insert-file)

    ;; Rectangle
    (keymap-bind! *ctrl-x-r-map* "t" 'string-rectangle)
    (keymap-bind! *ctrl-x-r-map* "o" 'open-rectangle)

    ;; Number lines, reverse region
    (keymap-bind! *ctrl-c-map* "#" 'number-lines)
    (keymap-bind! *ctrl-c-map* "r" 'reverse-region)

    ;; Flush/keep lines
    (keymap-bind! *meta-s-map* "f" 'flush-lines)
    (keymap-bind! *meta-s-map* "k" 'keep-lines)

    ;; Align regexp
    (keymap-bind! *ctrl-c-map* "a" 'align-regexp)

    ;; Sort fields
    (keymap-bind! *ctrl-c-map* "s" 'sort-fields)

    ;; Mark word, mark paragraph, paragraph navigation
    (keymap-bind! *global-keymap* "M-@" 'mark-word)
    (keymap-bind! *global-keymap* "M-h" 'mark-paragraph)
    (keymap-bind! *global-keymap* "M-}" 'forward-paragraph)
    (keymap-bind! *global-keymap* "M-{" 'backward-paragraph)

    ;; Back to indentation, delete indentation
    (keymap-bind! *global-keymap* "M-m" 'back-to-indentation)
    (keymap-bind! *global-keymap* "M-^" 'delete-indentation)

    ;; Exchange point and mark
    (keymap-bind! *ctrl-x-map* "C-x" 'exchange-point-and-mark)

    ;; C-c l → LSP prefix map
    (keymap-bind! *ctrl-c-map* "l" *ctrl-c-l-map*)

    ;; Copy line
    (keymap-bind! *ctrl-c-map* "c" 'copy-line)

    ;; Help extras
    (keymap-bind! *help-map* "w" 'where-is)
    (keymap-bind! *help-map* "a" 'apropos-command)
    (keymap-bind! *ctrl-x-map* "C-q" 'toggle-read-only)
    (keymap-bind! *ctrl-x-r-map* "n" 'rename-buffer)

    ;; Other-window commands (C-x 4 prefix)
    (keymap-bind! *ctrl-x-map* "4" *ctrl-x-4-map*)
    (keymap-bind! *ctrl-x-4-map* "b" 'switch-buffer-other-window)
    (keymap-bind! *ctrl-x-4-map* "f" 'find-file-other-window)

    ;; Frame commands (C-x 5 prefix)
    (keymap-bind! *ctrl-x-map* "5" *ctrl-x-5-map*)
    (keymap-bind! *ctrl-x-5-map* "2" 'make-frame-command)
    (keymap-bind! *ctrl-x-5-map* "0" 'delete-frame)
    (keymap-bind! *ctrl-x-5-map* "o" 'other-frame)
    (keymap-bind! *ctrl-x-5-map* "f" 'find-file-other-frame)
    (keymap-bind! *ctrl-x-5-map* "b" 'switch-to-buffer-other-frame)

    ;; Text transforms
    (keymap-bind! *ctrl-c-map* "t" 'tabify)
    (keymap-bind! *ctrl-c-map* "3" 'rot13-region)
    (keymap-bind! *ctrl-c-map* "x" 'hexl-mode)

    ;; Count matches, dedup
    (keymap-bind! *meta-s-map* "c" 'count-matches)
    (keymap-bind! *ctrl-c-map* "u" 'delete-duplicate-lines)

    ;; Diff, checksum
    (keymap-bind! *ctrl-c-map* "d" 'diff-buffer-with-file)
    (keymap-bind! *ctrl-c-map* "5" 'checksum)

    ;; Async shell command
    (keymap-bind! *global-keymap* "M-&" 'async-shell-command)

    ;; Selective display
    (keymap-bind! *ctrl-x-map* "$" 'set-selective-display)

    ;; Grep buffer
    (keymap-bind! *meta-s-map* "g" 'grep-buffer)
    (keymap-bind! *meta-s-map* "r" 'consult-ripgrep)

    ;; Insert date, insert char
    (keymap-bind! *ctrl-c-map* "D" 'insert-date)
    (keymap-bind! *ctrl-c-map* "8" 'insert-char)

    ;; Eval
    (keymap-bind! *ctrl-c-map* "E" 'eval-buffer)
    (keymap-bind! *ctrl-c-map* "v" 'eval-region)
    (keymap-bind! *ctrl-x-map* "C-e" 'eval-last-sexp)
    (keymap-bind! *ctrl-c-map* "C-e" 'eval-last-sexp)
    (keymap-bind! *ctrl-c-map* "C-d" 'eval-defun)

    ;; Org-mode
    (keymap-bind! *ctrl-c-map* "C-n" 'org-next-heading)
    (keymap-bind! *ctrl-c-map* "C-p" 'org-prev-heading)
    (keymap-bind! *ctrl-c-map* "C-t" 'org-todo)
    (keymap-bind! *ctrl-c-map* "C-l" 'org-link)
    (keymap-bind! *ctrl-c-map* "C-o" 'org-open-at-point)
    (keymap-bind! *ctrl-c-map* "C-s" 'org-schedule)
    (keymap-bind! *ctrl-c-map* "C-q" 'org-set-tags)
    (keymap-bind! *ctrl-c-map* ","   'org-priority)

    ;; Clone buffer, scratch
    (keymap-bind! *ctrl-c-map* "b" 'clone-buffer)
    (keymap-bind! *ctrl-c-map* "S" 'scratch-buffer)

    ;; Save some buffers
    (keymap-bind! *ctrl-x-map* "s" 'save-some-buffers)

    ;; Revert quick
    (keymap-bind! *ctrl-c-map* "R" 'revert-buffer-quick)

    ;; Toggle highlighting
    (keymap-bind! *ctrl-c-map* "f" 'toggle-highlighting)

    ;; Display time
    (keymap-bind! *ctrl-c-map* "T" 'display-time)

    ;; Calculator
    (keymap-bind! *ctrl-c-map* "=" 'calc)

    ;; Case fold search toggle
    (keymap-bind! *ctrl-c-map* "C" 'toggle-case-fold-search)

    ;; Describe bindings
    (keymap-bind! *help-map* "B" 'describe-bindings)

    ;; Center line
    (keymap-bind! *global-keymap* "M-o" 'center-line)

    ;; What face
    (keymap-bind! *ctrl-c-map* "F" 'what-face)

    ;; List processes
    (keymap-bind! *ctrl-c-map* "P" 'list-processes)

    ;; View messages
    (keymap-bind! *ctrl-c-map* "m" 'view-messages)

    ;; Auto fill toggle
    (keymap-bind! *ctrl-c-map* "q" 'toggle-auto-fill)

    ;; Delete trailing whitespace
    (keymap-bind! *ctrl-c-map* "W" 'delete-trailing-whitespace)

    ;; Ediff buffers
    (keymap-bind! *ctrl-c-map* "B" 'ediff-buffers)

    ;; Rename/delete file
    (keymap-bind! *ctrl-c-map* "M" 'rename-file-and-buffer)

    ;; Sudo write
    (keymap-bind! *ctrl-c-map* "X" 'sudo-write)

    ;; Sort numeric
    (keymap-bind! *ctrl-c-map* "N" 'sort-numeric)

    ;; Count words region
    (keymap-bind! *ctrl-c-map* "L" 'count-words-region)

    ;; Overwrite mode
    (keymap-bind! *global-keymap* "<insert>" 'toggle-overwrite-mode)

    ;; Visual line mode
    (keymap-bind! *ctrl-c-map* "V" 'toggle-visual-line-mode)

    ;; Fill column
    (keymap-bind! *ctrl-c-map* "." 'set-fill-column)
    (keymap-bind! *ctrl-c-map* "|" 'toggle-fill-column-indicator)

    ;; Repeat complex command
    (keymap-bind! *ctrl-c-map* "Z" 'repeat-complex-command)

    ;; Eldoc
    (keymap-bind! *ctrl-c-map* "I" 'eldoc)

    ;; Highlight symbol
    (keymap-bind! *ctrl-c-map* "h" 'highlight-symbol)
    (keymap-bind! *ctrl-c-map* "H" 'clear-highlight)

    ;; Indent rigidly
    (keymap-bind! *ctrl-c-map* ">" 'indent-rigidly-right)
    (keymap-bind! *ctrl-c-map* "<" 'indent-rigidly-left)

    ;; Buffer stats
    (keymap-bind! *ctrl-c-map* "?" 'buffer-stats)

    ;; Show tabs/eol
    (keymap-bind! *ctrl-c-map* "4" 'toggle-show-tabs)
    (keymap-bind! *ctrl-c-map* "6" 'toggle-show-eol)

    ;; Copy from above
    (keymap-bind! *ctrl-c-map* "A" 'copy-from-above)

    ;; Open line above
    (keymap-bind! *ctrl-c-map* "O" 'open-line-above)

    ;; Select line
    (keymap-bind! *ctrl-c-map* "G" 'select-line)

    ;; Split line
    (keymap-bind! *ctrl-c-map* "J" 'split-line)

    ;; Hippie expand
    (keymap-bind! *global-keymap* "M-TAB" 'hippie-expand)

    ;; Swap buffers
    (keymap-bind! *ctrl-c-map* "9" 'swap-buffers)

    ;; Tab width cycle
    (keymap-bind! *ctrl-c-map* "7" 'cycle-tab-width)

    ;; Indent tabs mode
    (keymap-bind! *ctrl-c-map* "0" 'toggle-indent-tabs-mode)

    ;; Buffer info
    (keymap-bind! *ctrl-c-map* "j" 'buffer-info)

    ;; Window resize
    (keymap-bind! *ctrl-x-map* "^" 'enlarge-window)
    (keymap-bind! *ctrl-x-map* "-" 'shrink-window)
    (keymap-bind! *ctrl-x-map* "{" 'shrink-window-horizontally)
    (keymap-bind! *ctrl-x-map* "}" 'enlarge-window-horizontally)

    ;; Whitespace cleanup
    (keymap-bind! *ctrl-c-map* "c" 'whitespace-cleanup)

    ;; Toggle electric pair
    (keymap-bind! *ctrl-c-map* "Q" 'toggle-electric-pair)

    ;; Previous/next buffer
    (keymap-bind! *ctrl-x-map* "<left>" 'previous-buffer)
    (keymap-bind! *ctrl-x-map* "<right>" 'next-buffer)

    ;; Balance windows
    (keymap-bind! *ctrl-x-map* "+" 'balance-windows)

    ;; Move to window line
    (keymap-bind! *global-keymap* "M-r" 'move-to-window-line)

    ;; Kill buffer and window
    (keymap-bind! *ctrl-x-4-map* "0" 'kill-buffer-and-window)

    ;; Flush undo
    (keymap-bind! *ctrl-c-map* "/" 'flush-undo)

    ;; Upcase initials region
    (keymap-bind! *ctrl-c-map* "U" 'upcase-initials-region)

    ;; Untabify buffer
    (keymap-bind! *ctrl-c-map* "_" 'untabify-buffer)

    ;; Insert buffer name
    (keymap-bind! *ctrl-c-map* "%" 'insert-buffer-name)

    ;; Mark defun
    (keymap-bind! *ctrl-c-map* "y" 'mark-defun)

    ;; Insert pairs
    (keymap-bind! *ctrl-c-map* "(" 'insert-parentheses)
    (keymap-bind! *ctrl-c-map* "[" 'insert-pair-brackets)

    ;; Describe char
    (keymap-bind! *ctrl-c-map* "," 'describe-char)

    ;; Find file at point
    (keymap-bind! *ctrl-c-map* "o" 'find-file-at-point)

    ;; Count chars region
    (keymap-bind! *ctrl-c-map* "K" 'count-chars-region)

    ;; Count words buffer
    (keymap-bind! *ctrl-c-map* "+" 'count-words-buffer)

    ;; Unfill paragraph
    (keymap-bind! *ctrl-c-map* ";" 'unfill-paragraph)

    ;; List registers
    (keymap-bind! *ctrl-c-map* "@" 'list-registers)

    ;; Show kill ring
    (keymap-bind! *ctrl-c-map* "Y" 'show-kill-ring)

    ;; Smart beginning of line
    (keymap-bind! *ctrl-c-map* "`" 'smart-beginning-of-line)

    ;; What buffer
    (keymap-bind! *ctrl-c-map* "~" 'what-buffer)

    ;; Narrowing indicator
    (keymap-bind! *ctrl-c-map* ":" 'toggle-narrowing-indicator)

    ;; Insert file name
    (keymap-bind! *ctrl-c-map* "&" 'insert-file-name)

    ;; S-expression navigation
    (keymap-bind! *meta-g-map* "u" 'backward-up-list)
    (keymap-bind! *meta-g-map* "d" 'forward-up-list)
    (keymap-bind! *meta-g-map* "k" 'kill-sexp)
    (keymap-bind! *meta-g-map* "f" 'forward-sexp)
    (keymap-bind! *meta-g-map* "b" 'backward-sexp)
    (keymap-bind! *meta-g-map* "SPC" 'mark-sexp)
    (keymap-bind! *meta-g-map* "TAB" 'indent-sexp)

    ;; Word frequency
    (keymap-bind! *ctrl-c-map* "*" 'word-frequency)

    ;; Insert UUID
    (keymap-bind! *ctrl-c-map* "'" 'insert-uuid)

    ;; Delete pair
    (keymap-bind! *ctrl-c-map* "}" 'delete-pair)

    ;; Toggle caret line highlight
    (keymap-bind! *ctrl-c-map* "{" 'toggle-hl-line)

    ;; Find alternate file
    (keymap-bind! *ctrl-x-map* "C-v" 'find-alternate-file)

    ;; Increment register
    (keymap-bind! *ctrl-x-r-map* "+" 'increment-register)

    ;; Scroll other window
    (keymap-bind! *meta-g-map* "v" 'scroll-other-window)
    (keymap-bind! *meta-g-map* "V" 'scroll-other-window-up)

    ;; Goto matching paren
    (keymap-bind! *meta-g-map* "m" 'goto-matching-paren)

    ;; Backward kill sexp
    (keymap-bind! *meta-g-map* "DEL" 'backward-kill-sexp)

    ;; Goto percent
    (keymap-bind! *meta-g-map* "%" 'goto-percent)

    ;; Help extras
    (keymap-bind! *help-map* "c" 'describe-key-briefly)
    (keymap-bind! *help-map* "d" 'describe-function)
    (keymap-bind! *help-map* "m" 'describe-mode)
    (keymap-bind! *help-map* "v" 'describe-variable)
    (keymap-bind! *help-map* "i" 'info)
    (keymap-bind! *help-map* "l" 'view-lossage)

    ;; Windmove
    (keymap-bind! *global-keymap* "S-<left>"  'windmove-left)
    (keymap-bind! *global-keymap* "S-<right>" 'windmove-right)
    (keymap-bind! *global-keymap* "S-<up>"    'windmove-up)
    (keymap-bind! *global-keymap* "S-<down>"  'windmove-down)

    ;; Project commands (C-x p prefix)
    (keymap-bind! *ctrl-x-map* "p" *ctrl-x-p-map*)
    (keymap-bind! *ctrl-x-p-map* "f" 'project-find-file)
    (keymap-bind! *ctrl-x-p-map* "g" 'project-grep)
    (keymap-bind! *ctrl-x-p-map* "c" 'project-compile)
    (keymap-bind! *ctrl-x-p-map* "b" 'project-switch-to-buffer)
    (keymap-bind! *ctrl-x-p-map* "d" 'project-dired)
    (keymap-bind! *ctrl-x-p-map* "e" 'project-eshell)
    (keymap-bind! *ctrl-x-p-map* "s" 'project-shell)
    (keymap-bind! *ctrl-x-p-map* "p" 'project-switch-project)
    (keymap-bind! *ctrl-x-p-map* "k" 'project-kill-buffers)
    (keymap-bind! *ctrl-x-p-map* "t" 'project-tree)

    ;; Magit
    (keymap-bind! *ctrl-x-map* "g" 'magit-status)

    ;; Imenu
    (keymap-bind! *meta-g-map* "i" 'imenu)

    ;; Code folding
    (keymap-bind! *meta-g-map* "F" 'toggle-fold)
    (keymap-bind! *meta-g-map* "C" 'fold-all)
    (keymap-bind! *meta-g-map* "E" 'unfold-all))

  ;;;============================================================================
  ;;; Echo state
  ;;;============================================================================

  (defstruct echo-state (message error?))

  (def (make-initial-echo-state) (make-echo-state #f #f))

  ;; Notification log
  (def *notification-log* '())
  (def *notification-log-count* 0)
  (def (notification-log) *notification-log*)

  (def (notification-push! msg)
    (when (and (string? msg) (> (string-length msg) 0))
      (set! *notification-log* (cons msg *notification-log*))
      (set! *notification-log-count* (+ *notification-log-count* 1))
      (when (> *notification-log-count* 150)
        (set! *notification-log* (list-head *notification-log* 100))
        (set! *notification-log-count* 100))))

  (def (notification-get-recent (n 50))
    (if (<= (length *notification-log*) n)
      *notification-log*
      (list-head *notification-log* n)))

  (def (echo-message! echo msg)
    (echo-state-message-set! echo msg)
    (echo-state-error?-set! echo #f)
    (notification-push! msg))

  (def (echo-error! echo msg)
    (echo-state-message-set! echo msg)
    (echo-state-error?-set! echo #t)
    (jemacs-log! "ERROR: " msg)
    (notification-push! (string-append "ERROR: " msg)))

  (def (echo-clear! echo)
    (echo-state-message-set! echo #f)
    (echo-state-error?-set! echo #f))

  ;;;============================================================================
  ;;; Hooks
  ;;;============================================================================

  (def *hooks* (make-hash-table))

  (def (add-hook! hook-name fn)
    (let ((fns (hash-get *hooks* hook-name)))
      (if fns
        (unless (memq fn fns)
          (hash-put! *hooks* hook-name (append fns (list fn))))
        (hash-put! *hooks* hook-name (list fn)))))

  (def (remove-hook! hook-name fn)
    (let ((fns (hash-get *hooks* hook-name)))
      (when fns
        (hash-put! *hooks* hook-name (filter (lambda (f) (not (eq? f fn))) fns)))))

  (def (run-hooks! hook-name . args)
    (let ((fns (hash-get *hooks* hook-name)))
      (when fns
        (for-each (lambda (fn)
                    (with-catch
                      (lambda (e) (void))
                      (lambda () (apply fn args))))
                  fns))))

  ;;;============================================================================
  ;;; Buffer structure and list
  ;;;============================================================================

  (defstruct buffer (name file-path doc-pointer mark modified lexer-lang backup-done?))

  (def *buffer-list* '())
  (def *buffer-list-lock* (make-rwlock))

  (def (buffer-list)
    (with-read-lock *buffer-list-lock*
      (lambda () *buffer-list*)))

  (def (buffer-list-add! buf)
    (with-write-lock *buffer-list-lock*
      (lambda ()
        (set! *buffer-list* (cons buf *buffer-list*)))))

  (def (buffer-list-remove! buf)
    (with-write-lock *buffer-list-lock*
      (lambda ()
        (set! *buffer-list*
          (let loop ((bufs *buffer-list*) (acc '()))
            (cond
              ((null? bufs) (reverse acc))
              ((eq? (car bufs) buf) (loop (cdr bufs) acc))
              (else (loop (cdr bufs) (cons (car bufs) acc)))))))))

  (def (buffer-by-name name)
    (let loop ((bufs (buffer-list)))
      (cond
        ((null? bufs) #f)
        ((string=? (buffer-name (car bufs)) name) (car bufs))
        (else (loop (cdr bufs))))))

  (def buffer-scratch-name "*scratch*")

  ;;;============================================================================
  ;;; App state
  ;;;============================================================================

  (defstruct app-state
    (frame echo key-state running last-search
     kill-ring kill-ring-idx last-yank-pos last-yank-len
     last-compile bookmarks rect-kill dabbrev-state
     macro-recording macro-last macro-named
     mark-ring registers last-command
     prefix-arg prefix-digit-mode?
     key-handler
     winner-history winner-history-idx
     tabs current-tab-idx key-lossage))

  (def (new-app-state frame)
    (make-app-state
     frame
     (make-initial-echo-state)
     (make-initial-key-state)
     #t                    ; running
     #f                    ; last-search
     '()                   ; kill-ring
     0                     ; kill-ring-idx
     #f                    ; last-yank-pos
     #f                    ; last-yank-len
     #f                    ; last-compile
     (make-hash-table)     ; bookmarks
     '()                   ; rect-kill
     #f                    ; dabbrev-state
     #f                    ; macro-recording
     #f                    ; macro-last
     (make-hash-table)     ; macro-named
     '()                   ; mark-ring
     (make-hash-table)     ; registers
     #f                    ; last-command
     #f                    ; prefix-arg
     #f                    ; prefix-digit-mode?
     #f                    ; key-handler
     '()                   ; winner-history
     0                     ; winner-history-idx
     (list (list "Tab 1" '("*scratch*") 0)) ; tabs
     0                     ; current-tab-idx
     '()))                 ; key-lossage

  (def (get-prefix-arg app (default 1))
    (let ((arg (app-state-prefix-arg app)))
      (cond
       ((not arg) default)
       ((number? arg) arg)
       ((list? arg) (car arg))
       ((eq? arg '-) -1)
       (else default))))

  ;;;============================================================================
  ;;; Frame management state
  ;;;============================================================================

  (def *frame-list* (list '(("*scratch*") "*scratch*" ())))
  (def *current-frame-idx* 0)

  (def (frame-list) *frame-list*)
  (def (frame-list-set! v) (set! *frame-list* v))
  (def (current-frame-idx) *current-frame-idx*)
  (def (current-frame-idx-set! v) (set! *current-frame-idx* v))

  (def (frame-count) (length *frame-list*))

  ;;;============================================================================
  ;;; Key lossage (last 300 keystrokes)
  ;;;============================================================================

  (def *key-lossage-max* 300)

  (def (key-lossage-record! app key-str)
    (let ((lossage (app-state-key-lossage app)))
      (app-state-key-lossage-set! app
        (if (>= (length lossage) *key-lossage-max*)
          (cons key-str (list-head lossage (- *key-lossage-max* 1)))
          (cons key-str lossage)))))

  (def (key-lossage->string app)
    (let ((keys (reverse (app-state-key-lossage app))))
      (if (null? keys)
        "(no keystrokes recorded)"
        (let loop ((ks keys) (col 0) (acc ""))
          (if (null? ks)
            acc
            (let* ((k (car ks))
                   (sep (if (and (> col 0) (= (modulo col 10) 0)) "\n" " "))
                   (new-acc (if (string=? acc "")
                              k
                              (string-append acc sep k))))
              (loop (cdr ks) (+ col 1) new-acc)))))))

  ;;;============================================================================
  ;;; Command registry
  ;;;============================================================================

  (def *commands* (make-hash-table))
  (def *all-commands* *commands*)

  (def (register-command! name proc)
    (hash-put! *commands* name proc))

  (def (find-command name)
    (hash-get *commands* name))

  (def *command-docs* (make-hash-table))

  (def (register-command-doc! name doc)
    (hash-put! *command-docs* name doc))

  (def (command-name->description name)
    (let* ((s (symbol->string name))
           (words (string-split s "-"))
           (capitalized (if (pair? words)
                         (cons (let ((w (car words)))
                                 (if (> (string-length w) 0)
                                   (string-append (string (char-upcase (string-ref w 0)))
                                                  (substring w 1 (string-length w)))
                                   w))
                               (cdr words))
                         words)))
      (string-join capitalized " ")))

  (def (command-doc name)
    (or (hash-get *command-docs* name)
        (command-name->description name)))

  (def (find-keybinding-for-command name)
    (let ((result #f))
      (for-each
        (lambda (entry)
          (unless result
            (let ((key (car entry)) (val (cdr entry)))
              (cond
                ((eq? val name) (set! result key))
                ((hash-table? val)
                 (for-each
                   (lambda (sub)
                     (unless result
                       (when (eq? (cdr sub) name)
                         (set! result (string-append key " " (car sub))))))
                   (keymap-entries val)))))))
        (keymap-entries *global-keymap*))
      result))

  (def (execute-command! app name)
    (let ((cmd (find-command name)))
      (if cmd
        (begin
          (verbose-log! "CMD " (symbol->string name))
          (app-state-last-command-set! app name)
          (quit-flag-clear!)
          (with-catch
            (lambda (e)
              (if (keyboard-quit-exception? e)
                (echo-message! (app-state-echo app) "Quit")
                (let ((msg (call-with-string-output-port
                             (lambda (p) (display e p)))))
                  (jemacs-log! "COMMAND-ERROR: " (symbol->string name) ": \n" msg)
                  (echo-error! (app-state-echo app)
                    (string-append (symbol->string name) ": " msg)))))
            (lambda () (cmd app)))
          ;; Reset prefix-arg unless prefix-building command
          (unless (memq name '(universal-argument digit-argument-0 digit-argument-1 digit-argument-2
                              digit-argument-3 digit-argument-4 digit-argument-5 digit-argument-6
                              digit-argument-7 digit-argument-8 digit-argument-9 negative-argument))
            (app-state-prefix-arg-set! app #f)
            (app-state-prefix-digit-mode?-set! app #f))
          ;; Activate repeat map if repeat-mode is on
          (when (repeat-mode?)
            (let ((rmap (repeat-map-for-command name)))
              (if rmap
                (begin
                  (active-repeat-map-set! rmap)
                  (echo-message! (app-state-echo app) (repeat-map-hint rmap)))
                (active-repeat-map-set! #f)))))
        (begin
          (jemacs-log! "UNDEFINED-CMD: " (symbol->string name))
          (echo-error! (app-state-echo app)
                       (string-append (symbol->string name) " is undefined"))))))

  (def (setup-command-docs!)
    ;; File operations
    (register-command-doc! 'find-file "Visit a file in its own buffer.")
    (register-command-doc! 'save-buffer "Save the current buffer to its file.")
    (register-command-doc! 'save-some-buffers "Save all modified file-visiting buffers.")
    (register-command-doc! 'write-file "Write the current buffer to a different file.")
    (register-command-doc! 'revert-buffer "Revert the buffer to the last saved version.")
    (register-command-doc! 'revert-buffer-quick "Revert the buffer without confirmation.")
    ;; Buffer
    (register-command-doc! 'switch-buffer "Switch to a different buffer by name.")
    (register-command-doc! 'kill-buffer-cmd "Kill (close) a buffer.")
    (register-command-doc! 'list-buffers "Display a list of all buffers.")
    (register-command-doc! 'next-buffer "Switch to the next buffer.")
    (register-command-doc! 'previous-buffer "Switch to the previous buffer.")
    ;; Navigation
    (register-command-doc! 'forward-char "Move point right one character.")
    (register-command-doc! 'backward-char "Move point left one character.")
    (register-command-doc! 'forward-word "Move point forward one word.")
    (register-command-doc! 'backward-word "Move point backward one word.")
    (register-command-doc! 'next-line "Move point down one line.")
    (register-command-doc! 'previous-line "Move point up one line.")
    (register-command-doc! 'beginning-of-line "Move point to beginning of line.")
    (register-command-doc! 'end-of-line "Move point to end of line.")
    (register-command-doc! 'beginning-of-buffer "Move point to beginning of buffer.")
    (register-command-doc! 'end-of-buffer "Move point to end of buffer.")
    (register-command-doc! 'goto-line "Go to a specific line number.")
    (register-command-doc! 'goto-char "Go to a specific character position.")
    (register-command-doc! 'scroll-up "Scroll the buffer up one screenful.")
    (register-command-doc! 'scroll-down "Scroll the buffer down one screenful.")
    (register-command-doc! 'recenter "Center the display around point.")
    ;; Editing
    (register-command-doc! 'self-insert "Insert the character that was typed.")
    (register-command-doc! 'newline "Insert a newline at point.")
    (register-command-doc! 'delete-char "Delete the character after point.")
    (register-command-doc! 'delete-backward-char "Delete the character before point.")
    (register-command-doc! 'kill-line "Kill from point to end of line.")
    (register-command-doc! 'kill-word "Kill characters forward to end of word.")
    (register-command-doc! 'backward-kill-word "Kill characters backward to beginning of word.")
    (register-command-doc! 'kill-region "Kill the region.")
    (register-command-doc! 'copy-region-as-kill "Copy the region to kill ring.")
    (register-command-doc! 'yank "Reinsert last killed text.")
    (register-command-doc! 'yank-pop "Replace yanked text with earlier kill ring item.")
    (register-command-doc! 'undo "Undo the last change.")
    (register-command-doc! 'redo "Redo the last undone change.")
    ;; Search
    (register-command-doc! 'isearch-forward "Incremental search forward.")
    (register-command-doc! 'isearch-backward "Incremental search backward.")
    (register-command-doc! 'query-replace "Interactively replace string occurrences.")
    (register-command-doc! 'occur "Show all lines matching a pattern.")
    ;; Mark and region
    (register-command-doc! 'set-mark "Set the mark at point.")
    (register-command-doc! 'exchange-point-and-mark "Swap point and mark.")
    (register-command-doc! 'mark-whole-buffer "Mark the entire buffer.")
    ;; Window
    (register-command-doc! 'split-window-below "Split window horizontally.")
    (register-command-doc! 'split-window-right "Split window vertically.")
    (register-command-doc! 'delete-window "Remove the current window.")
    (register-command-doc! 'delete-other-windows "Make current window fill frame.")
    (register-command-doc! 'other-window "Select next window.")
    ;; M-x and help
    (register-command-doc! 'execute-extended-command "Read and execute a command (M-x).")
    (register-command-doc! 'describe-key "Show what command a key is bound to.")
    (register-command-doc! 'keyboard-quit "Abort the current operation.")
    ;; Shell and REPL
    (register-command-doc! 'eshell "Open built-in shell.")
    (register-command-doc! 'shell "Open external shell buffer.")
    (register-command-doc! 'eval-expression "Evaluate an expression and show result.")
    ;; Dired
    (register-command-doc! 'dired "Open a directory editor.")
    ;; VCS
    (register-command-doc! 'magit-status "Show git status.")
    (register-command-doc! 'magit-log "Show git log.")
    (register-command-doc! 'magit-diff "Show git diff.")
    (register-command-doc! 'magit-commit "Commit staged changes.")
    ;; Org
    (register-command-doc! 'org-todo-cycle "Cycle TODO state.")
    (register-command-doc! 'org-cycle "Cycle heading visibility.")
    ;; Session
    (register-command-doc! 'session-save "Save the current session.")
    (register-command-doc! 'session-restore "Restore a saved session."))

  ;;;============================================================================
  ;;; Shared helpers
  ;;;============================================================================

  (def *electric-indent-mode* #t)
  (def (electric-indent-mode?) *electric-indent-mode*)
  (def (electric-indent-mode-set! v) (set! *electric-indent-mode* v))

  (def (brace-char? ch)
    (or (= ch 40) (= ch 41)    ; ( )
        (= ch 91) (= ch 93)    ; [ ]
        (= ch 123) (= ch 125))) ; { }

  (def (safe-string-trim str)
    (let ((len (string-length str)))
      (if (= len 0) ""
        (let ((start (let loop ((i 0))
                       (if (>= i len) len
                         (if (char-whitespace? (string-ref str i))
                           (loop (+ i 1))
                           i)))))
          (if (= start 0) str
            (if (>= start len) ""
              (substring str start len)))))))

  (def (safe-string-trim-both str)
    (let ((len (string-length str)))
      (if (= len 0) ""
        (let ((start (let loop ((i 0))
                       (if (>= i len) len
                         (if (char-whitespace? (string-ref str i))
                           (loop (+ i 1))
                           i))))
              (end (let loop ((i (- len 1)))
                     (if (< i 0) 0
                       (if (char-whitespace? (string-ref str i))
                         (loop (- i 1))
                         (+ i 1))))))
          (if (>= start end) ""
            (substring str start end))))))

  ;;;============================================================================
  ;;; File I/O helpers
  ;;;============================================================================

  (def (read-file-as-string path)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (call-with-input-file path get-string-all))))

  (def (write-string-to-file path str)
    (call-with-output-file path
      (lambda (port) (display str port))))

  ;;;============================================================================
  ;;; Dired (directory listing) shared logic
  ;;;============================================================================

  (def *dired-entries* (make-hash-table))

  (def (dired-buffer? buf)
    (eq? (buffer-lexer-lang buf) 'dired))

  (def (strip-trailing-slash path)
    (if (and (> (string-length path) 1)
             (char=? (string-ref path (- (string-length path) 1)) #\/))
      (substring path 0 (- (string-length path) 1))
      path))

  (def (dired-format-entry dir name)
    (let ((full (if (string=? name "..")
                  (path-parent dir)
                  (string-append dir "/" name))))
      (with-catch
        (lambda (e)
          (string-append "  ?  " name))
        (lambda ()
          (let* ((is-dir (with-catch (lambda (e) #f)
                           (lambda () (file-directory? full))))
                 (display-name (if is-dir
                                 (string-append name "/")
                                 name)))
            (string-append "  " (if is-dir "d" "-") " " display-name))))))

  (def (dired-format-listing dir)
    (let* ((raw-entries (with-catch
                          (lambda (e) '())
                          (lambda () (directory-list dir))))
           (filtered (filter (lambda (name)
                               (not (or (string=? name ".") (string=? name ".."))))
                             raw-entries))
           (entries (sort filtered string<?))
           (dirs (filter (lambda (name)
                           (with-catch
                             (lambda (e) #f)
                             (lambda ()
                               (file-directory? (string-append dir "/" name)))))
                         entries))
           (files (filter (lambda (name)
                            (with-catch
                              (lambda (e) #t)
                              (lambda ()
                                (not (file-directory? (string-append dir "/" name))))))
                          entries))
           (ordered (append '("..") dirs files))
           (header (string-append "  " dir ":"))
           (total-line (string-append "  " (number->string (length entries)) " entries"))
           (entry-lines (map (lambda (name) (dired-format-entry dir name)) ordered))
           (all-lines (append (list header total-line "") entry-lines))
           (text (string-join all-lines "\n"))
           (paths (list->vector
                    (map (lambda (name)
                           (if (string=? name "..")
                             (or (path-parent dir) "/")
                             (string-append dir "/" name)))
                         ordered))))
      (values text paths)))

  ;;;============================================================================
  ;;; Runtime error log file (~/.jemacs-errors.log)
  ;;;============================================================================

  (def *jemacs-log-port* #f)
  (def *jemacs-original-stderr* #f)
  (def *verbose-log-port* #f)

  (def (init-jemacs-log!)
    (let ((log-path (string-append (or (getenv "HOME") "/tmp") "/.jemacs-errors.log")))
      (set! *jemacs-original-stderr* (current-error-port))
      (set! *jemacs-log-port*
        (open-file-output-port log-path
          (file-options no-fail no-truncate)
          (buffer-mode line)
          (native-transcoder)))
      (jemacs-log! "jemacs started")))

  (def (jemacs-log! . args)
    (when *jemacs-log-port*
      (let ((port *jemacs-log-port*)
            (ts (date->string (current-date 0) "~Y-~m-~d ~H:~M:~S")))
        (put-string port "[")
        (put-string port ts)
        (put-string port "] ")
        (for-each (lambda (arg) (display arg port)) args)
        (newline port)
        (flush-output-port port))))

  (def (init-verbose-log!)
    (let ((path (string-append (or (getenv "HOME") "/tmp") "/.jemacs-verbose.log")))
      (set! *verbose-log-port*
        (open-file-output-port path
          (file-options no-fail no-truncate)
          (buffer-mode line)
          (native-transcoder)))
      (verbose-log! "=== jemacs verbose log started ===")
      path))

  (def (verbose-log! . args)
    (when *verbose-log-port*
      (let* ((port *verbose-log-port*)
             (ts (date->string (current-date 0) "~Y-~m-~d ~H:~M:~S")))
        (put-string port "[")
        (put-string port ts)
        (put-string port "] ")
        (for-each (lambda (arg) (display arg port)) args)
        (newline port)
        (flush-output-port port))))

  ;;;============================================================================
  ;;; Captured output logs
  ;;;============================================================================

  (def *captured-errors* "")
  (def *captured-output* "")

  (def (append-error-log! text)
    (set! *captured-errors* (string-append *captured-errors* text))
    (jemacs-log! "EVAL-STDERR: " text))
  (def (append-output-log! text)
    (set! *captured-output* (string-append *captured-output* text)))
  (def (get-error-log) *captured-errors*)
  (def (get-output-log) *captured-output*)
  (def (clear-error-log!) (set! *captured-errors* ""))
  (def (clear-output-log!) (set! *captured-output* ""))
  (def (has-captured-output?)
    (or (> (string-length *captured-errors*) 0)
        (> (string-length *captured-output*) 0)))

  ;;;============================================================================
  ;;; REPL shared logic
  ;;;============================================================================

  (def (repl-buffer? buf)
    (eq? (buffer-lexer-lang buf) 'repl))

  (def *repl-state* (make-hash-table-eq))

  (def (eval-expression-string str)
    (with-catch
      (lambda (e)
        (let ((msg (call-with-string-output-port (lambda (p) (display e p)))))
          (append-error-log! msg)
          (values msg #t)))
      (lambda ()
        (let* ((expr (read (open-input-string str)))
               (out-port (open-string-output-port))
               (err-port (open-string-output-port)))
          (let-values (((out-extract) out-port)
                       ((err-extract) err-port))
            ;; Re-destructure: open-string-output-port returns (values port extractor)
            ;; Actually in Chez, (open-string-output-port) returns two values
            (void))
          ;; Simpler approach: use call-with-string-output-port
          (let* ((result-and-stdout
                   (call-with-string-output-port
                     (lambda (out-p)
                       (parameterize ((current-output-port out-p))
                         (eval expr)))))
                 ;; call-with-string-output-port returns the string, not the eval result
                 ;; Need different approach
                 )
            (void)))
        ;; Simplified eval: just eval and capture result
        (let* ((expr (read (open-input-string str)))
               (result (eval expr))
               (output (call-with-string-output-port (lambda (p) (write result p)))))
          (values output #f)))))

  (def (load-user-file! path)
    (with-catch
      (lambda (e)
        (let ((msg (call-with-string-output-port (lambda (p) (display e p)))))
          (append-error-log! msg)
          (values 0 msg)))
      (lambda ()
        (let ((port (open-input-file path)))
          (let loop ((count 0))
            (let ((form (read port)))
              (if (eof-object? form)
                (begin
                  (close-input-port port)
                  (values count #f))
                (begin
                  (eval form)
                  (loop (+ count 1))))))))))

  (def (load-user-string! str (source "buffer"))
    (with-catch
      (lambda (e)
        (let ((msg (call-with-string-output-port (lambda (p) (display e p)))))
          (append-error-log! msg)
          (values 0 msg)))
      (lambda ()
        (let ((port (open-input-string str)))
          (let loop ((count 0))
            (let ((form (read port)))
              (if (eof-object? form)
                (values count #f)
                (begin
                  (eval form)
                  (loop (+ count 1))))))))))

  ;;;============================================================================
  ;;; Fuzzy matching
  ;;;============================================================================

  (def (fuzzy-match? query target)
    (let ((qlen (string-length query))
          (tlen (string-length target)))
      (let loop ((qi 0) (ti 0))
        (cond
          ((>= qi qlen) #t)
          ((>= ti tlen) #f)
          ((char=? (char-downcase (string-ref query qi))
                   (char-downcase (string-ref target ti)))
           (loop (+ qi 1) (+ ti 1)))
          (else
           (loop qi (+ ti 1)))))))

  (def (fuzzy-score query target)
    (let ((qlen (string-length query))
          (tlen (string-length target)))
      (let loop ((qi 0) (ti 0) (score 0) (consecutive 0))
        (cond
          ((>= qi qlen) score)
          ((>= ti tlen) -1)
          ((char=? (char-downcase (string-ref query qi))
                   (char-downcase (string-ref target ti)))
           (let ((bonus (+ 1
                          (if (= ti 0) 3 0)
                          (* consecutive 2)
                          (if (and (> ti 0)
                                   (memv (string-ref target (- ti 1))
                                         '(#\- #\_ #\/ #\space)))
                            2 0))))
             (loop (+ qi 1) (+ ti 1) (+ score bonus) (+ consecutive 1))))
          (else
           (loop qi (+ ti 1) score 0))))))

  (def (fuzzy-filter-sort query candidates)
    (let* ((scored (let loop ((cs candidates) (acc '()))
                     (if (null? cs) (reverse acc)
                       (let ((s (fuzzy-score query (car cs))))
                         (if (>= s 0)
                           (loop (cdr cs) (cons (cons s (car cs)) acc))
                           (loop (cdr cs) acc))))))
           (sorted (sort scored (lambda (a b) (> (car a) (car b))))))
      (map cdr sorted)))

  ;;;============================================================================
  ;;; Paredit strict mode
  ;;;============================================================================

  (def *paredit-strict-mode* #f)
  (def (paredit-strict-mode?) *paredit-strict-mode*)
  (def (paredit-strict-mode-set! v) (set! *paredit-strict-mode* v))

  ;;;============================================================================
  ;;; Helm mode
  ;;;============================================================================

  (def *helm-mode* #f)
  (def (helm-mode?) *helm-mode*)
  (def (helm-mode-set! v) (set! *helm-mode* v))

  ;;;============================================================================
  ;;; Key translation map
  ;;;============================================================================

  (def *key-translation-map* (make-hash-table))

  (def (key-translate! from to)
    (hash-put! *key-translation-map* from to))

  (def (key-translate-char ch)
    (or (hash-get *key-translation-map* ch) ch))

  ;;;============================================================================
  ;;; Key-chord system
  ;;;============================================================================

  (def *chord-map* (make-hash-table))
  (def *chord-first-chars* (make-hash-table))

  (def *chord-timeout* 200)
  (def (chord-timeout) *chord-timeout*)
  (def (chord-timeout-set! v) (set! *chord-timeout* v))

  (def *chord-mode* #t)
  (def (chord-mode?) *chord-mode*)
  (def (chord-mode-set! v) (set! *chord-mode* v))

  (def (key-chord-define-global two-char-str cmd)
    (let ((upper (string-upcase two-char-str)))
      (hash-put! *chord-map* upper cmd)
      (hash-put! *chord-first-chars* (string-ref upper 0) #t)))

  (def (chord-lookup ch1 ch2)
    (hash-get *chord-map* (string (char-upcase ch1) (char-upcase ch2))))

  (def (chord-start-char? ch)
    (and *chord-mode*
         (hash-get *chord-first-chars* (char-upcase ch))))

  ;;;============================================================================
  ;;; Repeat-mode (Emacs 28+ transient repeat maps)
  ;;;============================================================================

  (def *repeat-command-map* (make-hash-table-eq))
  (def *repeat-maps* (make-hash-table-eq))

  (def *repeat-mode-on* #t)
  (def (repeat-mode?) *repeat-mode-on*)
  (def (repeat-mode-set! v) (set! *repeat-mode-on* v))

  (def *active-repeat-map-val* #f)
  (def (active-repeat-map) *active-repeat-map-val*)
  (def (active-repeat-map-set! v) (set! *active-repeat-map-val* v))

  (def (register-repeat-map! map-name entries)
    (hash-put! *repeat-maps* map-name entries)
    (for-each (lambda (entry)
                (hash-put! *repeat-command-map* (cdr entry) map-name))
              entries))

  (def (repeat-map-for-command cmd-name)
    (let ((map-name (hash-get *repeat-command-map* cmd-name)))
      (and map-name (hash-get *repeat-maps* map-name))))

  (def (repeat-map-lookup key-str)
    (let ((amap (active-repeat-map)))
      (and amap
           (let loop ((entries amap))
             (cond
               ((null? entries) #f)
               ((string=? (car (car entries)) key-str)
                (cdr (car entries)))
               (else (loop (cdr entries))))))))

  (def (repeat-map-hint rmap)
    (string-append "(Repeat: "
      (let loop ((entries rmap) (acc ""))
        (if (null? entries) acc
          (let* ((e (car entries))
                 (item (string-append (car e) "=" (symbol->string (cdr e)))))
            (loop (cdr entries)
                  (if (string=? acc "") item
                    (string-append acc ", " item))))))
      ")"))

  (def (clear-repeat-map!)
    (active-repeat-map-set! #f))

  (def (register-default-repeat-maps!)
    (register-repeat-map! 'other-window-repeat-map
      '(("o" . other-window) ("0" . delete-window) ("1" . delete-other-windows)
        ("2" . split-window-below) ("3" . split-window-right)))
    (register-repeat-map! 'buffer-navigation-repeat-map
      '(("n" . next-buffer) ("p" . previous-buffer)))
    (register-repeat-map! 'next-error-repeat-map
      '(("n" . next-error) ("p" . previous-error)))
    (register-repeat-map! 'undo-repeat-map
      '(("/" . undo)))
    (register-repeat-map! 'page-navigation-repeat-map
      '(("[" . backward-page) ("]" . forward-page)))
    (register-repeat-map! 'window-size-repeat-map
      '(("^" . enlarge-window) ("{" . shrink-window-horizontally)
        ("}" . enlarge-window-horizontally))))

  ;;;============================================================================
  ;;; Image buffer support
  ;;;============================================================================

  (def *editor-window-map* (make-hash-table))
  (def *image-buffer-state* (make-hash-table-eq))

  (def (image-buffer? buf)
    (eq? (buffer-lexer-lang buf) 'image))

  ;;;============================================================================
  ;;; Defun boundary detection (multi-language)
  ;;;============================================================================

  (def *defun-patterns*
    '((scheme   "^\\(def[a-z]*[ \t]" "^\\(define[a-z-]*[ \t]")
      (gerbil   "^\\(def[a-z]*[ \t]" "^\\(define[a-z-]*[ \t]")
      (lisp     "^\\(def[a-z]*[ \t]" "^\\(cl:def[a-z]*[ \t]")
      (python   "^def " "^class " "^async def ")
      (ruby     "^def " "^class " "^module ")
      (javascript "^function " "^class " "^const [a-zA-Z_]+ = \\(" "^export ")
      (typescript "^function " "^class " "^const [a-zA-Z_]+ = \\(" "^export ")
      (c        "^[a-zA-Z_][a-zA-Z0-9_ *]+[a-zA-Z_][a-zA-Z0-9_]*(" "^struct " "^enum " "^typedef ")
      (cpp      "^[a-zA-Z_][a-zA-Z0-9_ *:]+[a-zA-Z_][a-zA-Z0-9_]*(" "^class " "^struct " "^namespace ")
      (java     "^[ \t]*\\(public\\|private\\|protected\\|static\\)" "^class " "^interface ")
      (go       "^func " "^type ")
      (rust     "^fn " "^pub fn " "^struct " "^enum " "^impl " "^trait ")
      (lua      "^function " "^local function ")
      (shell    "^[a-zA-Z_][a-zA-Z0-9_]*[ \t]*(" "^function ")))

  (def (find-defun-boundaries text pos lang)
    (let ((len (string-length text)))
      (if (or (= len 0) (not lang))
        (values #f #f)
        (let ((lisp? (memq lang '(scheme gerbil lisp elisp clojure))))
          (if lisp?
            ;; Lisp: find unindented open paren, match to close
            (let ((defun-start
                    (let loop ((i (min pos (- len 1))))
                      (cond
                        ((< i 0) #f)
                        ((and (char=? (string-ref text i) #\()
                              (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
                         i)
                        (else (loop (- i 1)))))))
              (if (not defun-start)
                (values #f #f)
                (let ((defun-end
                        (let loop ((i defun-start) (depth 0) (in-string? #f) (in-comment? #f))
                          (cond
                            ((>= i len) len)
                            ((and in-string? (char=? (string-ref text i) #\\) (< (+ i 1) len))
                             (loop (+ i 2) depth #t #f))
                            ((and in-string? (char=? (string-ref text i) #\"))
                             (loop (+ i 1) depth #f #f))
                            (in-string? (loop (+ i 1) depth #t #f))
                            ((and (not in-comment?) (char=? (string-ref text i) #\;))
                             (loop (+ i 1) depth #f #t))
                            ((and in-comment? (char=? (string-ref text i) #\newline))
                             (loop (+ i 1) depth #f #f))
                            (in-comment? (loop (+ i 1) depth #f #t))
                            ((char=? (string-ref text i) #\")
                             (loop (+ i 1) depth #t #f))
                            ((char=? (string-ref text i) #\()
                             (loop (+ i 1) (+ depth 1) #f #f))
                            ((char=? (string-ref text i) #\))
                             (if (= depth 1) (+ i 1)
                               (loop (+ i 1) (- depth 1) #f #f)))
                            (else (loop (+ i 1) depth #f #f))))))
                  (let ((end (if (and (< defun-end len) (char=? (string-ref text defun-end) #\newline))
                               (+ defun-end 1) defun-end)))
                    (values defun-start end)))))
            ;; Non-Lisp: find non-indented definition line
            (let* ((line-start (let loop ((i (min pos (- len 1))))
                                 (cond ((< i 0) 0)
                                       ((and (> i 0) (char=? (string-ref text (- i 1)) #\newline)) i)
                                       ((= i 0) 0)
                                       (else (loop (- i 1))))))
                   (defun-start
                     (let loop ((i line-start))
                       (if (< i 0) #f
                         (let* ((ls (if (= i 0) 0
                                      (let scan ((j (- i 1)))
                                        (cond ((< j 0) 0)
                                              ((char=? (string-ref text j) #\newline) (+ j 1))
                                              (else (scan (- j 1)))))))
                                (ch (if (< ls len) (string-ref text ls) #\space)))
                           (if (and (< ls len)
                                    (not (char=? ch #\space))
                                    (not (char=? ch #\tab))
                                    (not (char=? ch #\newline))
                                    (not (char=? ch #\#))
                                    (not (char=? ch #\/))
                                    (not (char=? ch #\}))
                                    (not (char=? ch #\)))
                                    (char-alphabetic? ch))
                             ls
                             (if (> ls 0)
                               (loop (- ls 1))
                               #f)))))))
              (if (not defun-start)
                (values #f #f)
                (let ((defun-end
                        (let loop ((i (+ defun-start 1)) (past-first-line? #f))
                          (cond
                            ((>= i len) len)
                            ((char=? (string-ref text i) #\newline)
                             (if (>= (+ i 1) len) len
                               (let ((next-ch (string-ref text (+ i 1))))
                                 (cond
                                   ((and past-first-line?
                                         (char-alphabetic? next-ch)
                                         (not (memq lang '(c cpp java javascript typescript go rust))))
                                    (+ i 1))
                                   ((and past-first-line?
                                         (memq lang '(c cpp java javascript typescript go rust))
                                         (char=? next-ch #\})
                                         (< (+ i 2) len))
                                    (let scan ((j (+ i 2)))
                                      (cond ((>= j len) len)
                                            ((char=? (string-ref text j) #\newline) (+ j 1))
                                            (else (scan (+ j 1))))))
                                   (else (loop (+ i 1) #t))))))
                            (else (loop (+ i 1) past-first-line?))))))
                  (values defun-start defun-end)))))))))

  ;;;============================================================================
  ;;; Module-level initialization expressions
  ;;; (R6RS requires all definitions before expressions)
  ;;;============================================================================

  ;; Register customizable variables
  (defvar! 'lsp-server-command "chez-lsp" "Command to launch the LSP server"
           (lambda (v) (set! *lsp-server-command* v))
           'string #f 'lsp)
  (defvar! 'paredit-strict-mode #f "Prevent deletion of unbalanced delimiters"
           (lambda (v) (set! *paredit-strict-mode* v))
           'boolean #f 'editing)
  (defvar! 'helm-mode #f "Use Helm-style incremental completion"
           (lambda (v) (set! *helm-mode* v))
           'boolean #f 'completion)
  (defvar! 'chord-timeout 200 "Milliseconds to wait for second key of a chord"
           (lambda (v) (set! *chord-timeout* v))
           'integer (cons 50 1000) 'keybindings)
  (defvar! 'chord-mode #t "Enable key-chord mode for two-key shortcuts"
           (lambda (v) (set! *chord-mode* v))
           'boolean #f 'keybindings)

  ;; Register standard hooks
  (defhook! 'after-init-hook "Run after init file loaded and startup complete.")
  (defhook! 'before-save-hook "Run before saving a buffer to disk. Args: (app buf)")
  (defhook! 'after-save-hook "Run after saving a buffer to disk. Args: (app buf)")
  (defhook! 'find-file-hook "Run after opening a file into a buffer. Args: (app buf)")
  (defhook! 'kill-buffer-hook "Run before killing a buffer. Args: (app buf)")
  (defhook! 'after-change-major-mode-hook "Run after a buffer's major mode changes.")
  (defhook! 'buffer-list-update-hook "Run when the buffer list changes.")
  (defhook! 'post-buffer-attach-hook "Run after a buffer is attached to an editor. Args: (editor buf)")

  ) ;; end library
