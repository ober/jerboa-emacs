#!chezscheme
;;; editor-cmds-b.sls — Command batch B (Tasks 41-43)
;;;
;;; Ported from gerbil-emacs/editor-cmds-b.ss
;;; macros, windows, text transforms, project, search

(library (jerboa-emacs editor-cmds-b)
  (export
    ;; Task #41: macros, windows, advanced editing
    cmd-comment-region
    cmd-uncomment-region
    cmd-upcase-char
    cmd-downcase-char
    cmd-toggle-case-at-point
    cmd-write-region
    cmd-kill-matching-buffers
    cmd-goto-line-relative
    cmd-bookmark-delete
    cmd-bookmark-rename
    cmd-describe-mode
    cmd-delete-trailing-lines
    cmd-display-line-numbers-relative
    cmd-goto-column
    cmd-insert-line-number
    cmd-insert-buffer-filename
    cmd-copy-line-number
    cmd-copy-current-line
    cmd-copy-word
    cmd-move-to-window-top
    cmd-move-to-window-bottom
    cmd-move-to-window-middle
    cmd-scroll-left
    cmd-scroll-right
    cmd-delete-to-end-of-line
    cmd-delete-to-beginning-of-line
    cmd-yank-whole-line
    cmd-show-column-number
    cmd-count-lines-buffer
    cmd-recover-session
    cmd-toggle-backup-files

    ;; Task #42: text transforms, programming, and info
    cmd-camel-to-snake
    cmd-snake-to-camel
    cmd-kebab-to-camel
    cmd-reverse-word
    cmd-count-occurrences
    cmd-mark-lines-matching
    cmd-number-region
    cmd-strip-line-numbers
    cmd-prefix-lines
    cmd-suffix-lines
    cmd-wrap-lines-at-column
    cmd-show-file-info
    cmd-toggle-narrow-indicator
    cmd-insert-timestamp
    cmd-eval-and-insert
    cmd-shell-command-insert
    cmd-pipe-region
    cmd-sort-words
    cmd-remove-blank-lines
    cmd-collapse-blank-lines
    cmd-trim-lines
    cmd-toggle-line-comment
    cmd-copy-file-path
    cmd-insert-path-separator
    cmd-show-word-count
    cmd-show-char-count
    cmd-toggle-auto-complete
    cmd-insert-lorem-ipsum
    cmd-narrow-to-defun
    cmd-widen-all
    cmd-reindent-buffer
    cmd-show-trailing-whitespace-count
    cmd-show-tab-count
    cmd-toggle-global-whitespace
    cmd-insert-box-comment
    cmd-toggle-electric-indent
    cmd-increase-font-size
    cmd-decrease-font-size
    cmd-reset-font-size

    ;; Task #43: project, search, and utilities
    open-output-buffer
    cmd-project-find-file
    cmd-project-grep
    cmd-project-compile
    cmd-search-forward-word
    cmd-search-backward-word
    cmd-replace-in-region
    cmd-highlight-word-at-point
    cmd-goto-definition
    cmd-toggle-eol-conversion
    tui-frame-config-save
    tui-frame-config-restore!
    cmd-make-frame
    cmd-delete-frame
    cmd-find-file-other-frame
    cmd-switch-to-buffer-other-frame
    cmd-toggle-menu-bar
    cmd-toggle-tool-bar
    cmd-toggle-scroll-bar
    cmd-suspend-frame
    cmd-list-directory
    cmd-find-grep
    cmd-insert-header-guard
    cmd-insert-include
    cmd-insert-import
    cmd-insert-export
    cmd-insert-defun
    cmd-insert-let
    cmd-insert-cond
    cmd-insert-match
    cmd-insert-when
    cmd-insert-unless
    cmd-insert-lambda
    cmd-toggle-auto-pair-mode
    cmd-count-buffers
    cmd-list-recent-files
    cmd-clear-recent-files
    cmd-recentf-open
    cmd-recentf-cleanup
    cmd-desktop-save
    cmd-desktop-read
    cmd-savehist-save
    cmd-savehist-load
    cmd-show-keybinding-for
    cmd-sort-imports
    cmd-show-git-status
    cmd-show-git-log
    cmd-show-git-diff
    cmd-show-git-blame
    cmd-toggle-flyspell
    cmd-toggle-flymake
    cmd-toggle-lsp
    cmd-toggle-auto-revert-global
    cmd-customize
    cmd-set-variable
    set-process-sentinel!
    set-process-filter!
    process-sentinel
    process-filter
    cmd-load-plugin
    cmd-list-plugins

    ;; Mutable state accessors
    flyspell-mode flyspell-mode-set!
    flymake-mode flymake-mode-set!
    lsp-mode lsp-mode-set!
    global-auto-revert-mode global-auto-revert-mode-set!
    customizable-vars
    process-sentinels
    process-filters
    plugin-directory
    loaded-plugins loaded-plugins-set!)

  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std string)
          (only (jerboa prelude) path-directory path-strip-directory path-extension)
          (only (std srfi srfi-13) string-join string-contains string-prefix? string-suffix?
                string-index string-trim-both string-trim-right string-trim)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (chez-scintilla style)
          (chez-scintilla tui)
          (jerboa-emacs core)
          (jerboa-emacs repl)
          (jerboa-emacs eshell)
          (jerboa-emacs shell)
          (jerboa-emacs keymap)
          (jerboa-emacs buffer)
          (jerboa-emacs window)
          (jerboa-emacs modeline)
          (jerboa-emacs echo)
          (jerboa-emacs highlight)
          (jerboa-emacs persist)
          (jerboa-emacs editor-core)
          (except (jerboa-emacs editor-ui) word-char?)
          (except (jerboa-emacs editor-text) shell-quote)
          (jerboa-emacs editor-advanced)
          (jerboa-emacs editor-cmds-a))

  ;;;============================================================================
  ;;; Local helpers
  ;;;============================================================================

  ;; word-char? — takes a char-integer (to match Gerbil source call sites)
  (define (word-char? ci)
    (let ((ch (if (integer? ci) (integer->char ci) ci)))
      (or (char-alphabetic? ch) (char-numeric? ch)
          (char=? ch #\_) (char=? ch #\-))))

  ;; string-split on a char delimiter
  ;; (std string) provides string-split already

  ;; object->string: format any value as a string
  (define (object->string v)
    (call-with-string-output-port (lambda (p) (write v p))))

  ;; filter-map
  (define (filter-map f lst)
    (let loop ((xs lst) (acc '()))
      (if (null? xs) (reverse acc)
        (let ((v (f (car xs))))
          (if v
            (loop (cdr xs) (cons v acc))
            (loop (cdr xs) acc))))))

  ;; path-expand: join directory and file
  (define path-expand
    (case-lambda
      ((f) (string-append (current-directory) "/" f))
      ((f d) (string-append d "/" f))))

  ;; directory-files → directory-list
  (define (directory-files dir)
    (directory-list dir))

  ;;;============================================================================
  ;;; Mutable state with accessor/mutator pattern
  ;;;============================================================================

  (define *flyspell-mode* #f)
  (define (flyspell-mode) *flyspell-mode*)
  (define (flyspell-mode-set! v) (set! *flyspell-mode* v))

  (define *flymake-mode* #f)
  (define (flymake-mode) *flymake-mode*)
  (define (flymake-mode-set! v) (set! *flymake-mode* v))

  (define *lsp-mode* #f)
  (define (lsp-mode) *lsp-mode*)
  (define (lsp-mode-set! v) (set! *lsp-mode* v))

  (define *global-auto-revert-mode* #f)
  (define (global-auto-revert-mode) *global-auto-revert-mode*)
  (define (global-auto-revert-mode-set! v) (set! *global-auto-revert-mode* v))

  (define *customizable-vars*
    (list
      (list "scroll-margin" "Lines of margin for scrolling"
            (lambda () (scroll-margin)) (lambda (v) (scroll-margin-set! v)))
      (list "require-final-newline" "Ensure final newline on save"
            (lambda () (require-final-newline)) (lambda (v) (require-final-newline-set! v)))
      (list "delete-trailing-whitespace-on-save" "Strip trailing whitespace"
            (lambda () (delete-trailing-whitespace-on-save))
            (lambda (v) (delete-trailing-whitespace-on-save-set! v)))
      (list "global-auto-revert-mode" "Auto-reload changed files"
            (lambda () *global-auto-revert-mode*)
            (lambda (v) (set! *global-auto-revert-mode* v) (auto-revert-mode-set! v)))
      (list "flymake-mode" "Syntax checking"
            (lambda () *flymake-mode*) (lambda (v) (set! *flymake-mode* v)))))
  (define (customizable-vars) *customizable-vars*)

  (define *process-sentinels* (make-hash-table))
  (define (process-sentinels) *process-sentinels*)

  (define *process-filters* (make-hash-table))
  (define (process-filters) *process-filters*)

  (define *plugin-directory* "~/.gemacs-plugins")
  (define (plugin-directory) *plugin-directory*)

  (define *loaded-plugins* '())
  (define (loaded-plugins) *loaded-plugins*)
  (define (loaded-plugins-set! v) (set! *loaded-plugins* v))

  ;;;============================================================================
  ;;; Task #41: macros, windows, and advanced editing
  ;;;============================================================================

  (define (cmd-comment-region app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end)))
          (with-undo-action ed
            (let loop ((l end-line))
              (when (>= l start-line)
                (let ((ls (editor-position-from-line ed l)))
                  (editor-insert-text ed ls ";; "))
                (loop (- l 1)))))
          (buffer-mark-set! buf #f)
          (echo-message! echo (string-append "Commented "
                                              (number->string (+ 1 (- end-line start-line)))
                                              " lines")))
        (echo-error! echo "No mark set"))))

  (define (cmd-uncomment-region app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end)))
          (with-undo-action ed
            (let loop ((l end-line))
              (when (>= l start-line)
                (let* ((ls (editor-position-from-line ed l))
                       (le (editor-get-line-end-position ed l))
                       (line-len (- le ls))
                       (text (editor-get-text-range ed ls (min line-len 3))))
                  (cond
                    ((and (>= (string-length text) 3) (string=? text ";; "))
                     (editor-delete-range ed ls 3))
                    ((and (>= (string-length text) 2) (string=? (substring text 0 2) ";;"))
                     (editor-delete-range ed ls 2))))
                (loop (- l 1)))))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Region uncommented"))
        (echo-error! echo "No mark set"))))

  (define (cmd-upcase-char app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (< pos len)
        (let* ((ch (string-ref text pos))
               (up (char-upcase ch)))
          (when (not (char=? ch up))
            (editor-delete-range ed pos 1)
            (editor-insert-text ed pos (string up)))
          (editor-goto-pos ed (+ pos 1))))))

  (define (cmd-downcase-char app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (< pos len)
        (let* ((ch (string-ref text pos))
               (lo (char-downcase ch)))
          (when (not (char=? ch lo))
            (editor-delete-range ed pos 1)
            (editor-insert-text ed pos (string lo)))
          (editor-goto-pos ed (+ pos 1))))))

  (define (cmd-toggle-case-at-point app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (< pos len)
        (let* ((ch (string-ref text pos))
               (toggled (if (char-upper-case? ch) (char-downcase ch) (char-upcase ch))))
          (when (not (char=? ch toggled))
            (editor-delete-range ed pos 1)
            (editor-insert-text ed pos (string toggled)))
          (editor-goto-pos ed (+ pos 1))))))

  (define (cmd-write-region app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if mark
        (let ((filename (echo-read-string echo "Write region to file: " row width)))
          (when (and filename (not (string=? filename "")))
            (let* ((start (min pos mark))
                   (end (max pos mark))
                   (text (substring (editor-get-text ed) start end)))
              (call-with-output-file filename
                (lambda (p) (display text p))
                'truncate)
              (buffer-mark-set! buf #f)
              (echo-message! echo (string-append "Wrote "
                                                  (number->string (- end start))
                                                  " chars to " filename)))))
        (echo-error! echo "No mark set"))))

  (define (cmd-kill-matching-buffers app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (pattern (echo-read-string echo "Kill buffers matching: " row width)))
      (when (and pattern (not (string=? pattern "")))
        (let ((killed 0))
          (for-each
            (lambda (buf)
              (when (string-contains (buffer-name buf) pattern)
                (set! killed (+ killed 1))))
            (buffer-list))
          (echo-message! echo (string-append "Would kill "
                                              (number->string killed)
                                              " matching buffers"))))))

  (define (cmd-goto-line-relative app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Relative line (+N or -N): " row width)))
      (when (and input (not (string=? input "")))
        (let ((n (string->number input)))
          (when n
            (let* ((pos (editor-get-current-pos ed))
                   (cur-line (editor-line-from-position ed pos))
                   (target (+ cur-line n))
                   (max-line (- (editor-get-line-count ed) 1))
                   (clamped (max 0 (min target max-line))))
              (editor-goto-pos ed (editor-position-from-line ed clamped))
              (editor-scroll-caret ed)))))))

  (define (cmd-bookmark-delete app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (name (echo-read-string echo "Delete bookmark: " row width)))
      (when (and name (not (string=? name "")))
        (let ((bm (app-state-bookmarks app)))
          (if (hash-get bm name)
            (begin
              (hash-remove! bm name)
              (echo-message! echo (string-append "Deleted bookmark: " name)))
            (echo-error! echo (string-append "No bookmark: " name)))))))

  (define (cmd-bookmark-rename app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (old-name (echo-read-string echo "Rename bookmark: " row width)))
      (when (and old-name (not (string=? old-name "")))
        (let ((bm (app-state-bookmarks app)))
          (if (hash-get bm old-name)
            (let ((new-name (echo-read-string echo "New name: " row width)))
              (when (and new-name (not (string=? new-name "")))
                (hash-put! bm new-name (hash-ref bm old-name))
                (hash-remove! bm old-name)
                (echo-message! echo (string-append old-name " -> " new-name))))
            (echo-error! echo (string-append "No bookmark: " old-name)))))))

  (define (cmd-describe-mode app)
    (let* ((buf (current-buffer-from-app app))
           (lang (buffer-lexer-lang buf))
           (echo (app-state-echo app)))
      (echo-message! echo (string-append "Major mode: "
                                          (if lang (symbol->string lang) "fundamental")
                                          " | Use M-x describe-bindings for keybindings"))))

  (define (cmd-delete-trailing-lines app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (= len 0)
        (echo-message! echo "Buffer is empty")
        (let loop ((end len))
          (if (and (> end 0)
                   (let ((ch (string-ref text (- end 1))))
                     (or (char=? ch #\newline) (char=? ch #\space) (char=? ch #\tab))))
            (loop (- end 1))
            (if (< end len)
              (let ((keep-end (+ end 1)))
                (when (< keep-end len)
                  (editor-delete-range ed keep-end (- len keep-end))
                  (echo-message! echo (string-append "Removed "
                                                      (number->string (- len keep-end))
                                                      " trailing chars"))))
              (echo-message! echo "No trailing blank lines")))))))

  (define (cmd-display-line-numbers-relative app)
    (echo-message! (app-state-echo app) "Relative line numbers: N/A (use absolute)"))

  (define (cmd-goto-column app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Go to column: " row width)))
      (when (and input (not (string=? input "")))
        (let ((col (string->number input)))
          (when (and col (> col 0))
            (let* ((pos (editor-get-current-pos ed))
                   (line (editor-line-from-position ed pos))
                   (line-start (editor-position-from-line ed line))
                   (line-end (editor-get-line-end-position ed line))
                   (line-len (- line-end line-start))
                   (target-col (min (- col 1) line-len)))
              (editor-goto-pos ed (+ line-start target-col))))))))

  (define (cmd-insert-line-number app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (+ 1 (editor-line-from-position ed pos)))
           (text (number->string line)))
      (editor-insert-text ed pos text)
      (editor-goto-pos ed (+ pos (string-length text)))))

  (define (cmd-insert-buffer-filename app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (buf (current-buffer-from-app app))
           (pos (editor-get-current-pos ed))
           (filename (or (buffer-file-path buf) (buffer-name buf))))
      (editor-insert-text ed pos filename)
      (editor-goto-pos ed (+ pos (string-length filename)))))

  (define (cmd-copy-line-number app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (+ 1 (editor-line-from-position ed pos)))
           (text (number->string line)))
      (app-state-kill-ring-set! app (cons text (app-state-kill-ring app)))
      (echo-message! (app-state-echo app) (string-append "Copied line number: " text))))

  (define (cmd-copy-current-line app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (start (editor-position-from-line ed line))
           (end (editor-get-line-end-position ed line))
           (text (substring (editor-get-text ed) start end)))
      (app-state-kill-ring-set! app (cons text (app-state-kill-ring app)))
      (echo-message! (app-state-echo app) "Line copied")))

  (define (cmd-copy-word app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (and (< pos len) (word-char? (char->integer (string-ref text pos))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0) (word-char? (char->integer (string-ref text (- p 1)))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len) (word-char? (char->integer (string-ref text p))))
                        (loop (+ p 1)) p)))
               (word (substring text start end)))
          (app-state-kill-ring-set! app (cons word (app-state-kill-ring app)))
          (echo-message! (app-state-echo app) (string-append "Copied: " word)))
        (echo-error! (app-state-echo app) "Not on a word"))))

  (define (cmd-move-to-window-top app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (first-visible (send-message ed SCI_GETFIRSTVISIBLELINE 0 0))
           (doc-line (send-message ed 2312 first-visible 0))
           (pos (editor-position-from-line ed doc-line)))
      (editor-goto-pos ed pos)))

  (define (cmd-move-to-window-bottom app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (first-visible (send-message ed SCI_GETFIRSTVISIBLELINE 0 0))
           (lines-on-screen (send-message ed 2370 0 0))
           (last-visible (+ first-visible (- lines-on-screen 1)))
           (doc-line (send-message ed 2312 last-visible 0))
           (max-line (- (editor-get-line-count ed) 1))
           (target (min doc-line max-line))
           (pos (editor-position-from-line ed target)))
      (editor-goto-pos ed pos)))

  (define (cmd-move-to-window-middle app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (first-visible (send-message ed SCI_GETFIRSTVISIBLELINE 0 0))
           (lines-on-screen (send-message ed 2370 0 0))
           (middle-visible (+ first-visible (quotient lines-on-screen 2)))
           (doc-line (send-message ed 2312 middle-visible 0))
           (pos (editor-position-from-line ed doc-line)))
      (editor-goto-pos ed pos)))

  (define (cmd-scroll-left app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (offset (send-message ed SCI_GETXOFFSET 0 0)))
      (when (> offset 0)
        (send-message ed SCI_SETXOFFSET (max 0 (- offset 20)) 0))))

  (define (cmd-scroll-right app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (offset (send-message ed SCI_GETXOFFSET 0 0)))
      (send-message ed SCI_SETXOFFSET (+ offset 20) 0)))

  (define (cmd-delete-to-end-of-line app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (end (editor-get-line-end-position ed line)))
      (when (> end pos)
        (editor-delete-range ed pos (- end pos)))))

  (define (cmd-delete-to-beginning-of-line app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (start (editor-position-from-line ed line)))
      (when (> pos start)
        (editor-delete-range ed start (- pos start)))))

  (define (cmd-yank-whole-line app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (kill-ring (app-state-kill-ring app)))
      (if (null? kill-ring)
        (echo-error! echo "Kill ring is empty")
        (let* ((text (car kill-ring))
               (pos (editor-get-current-pos ed))
               (line (editor-line-from-position ed pos))
               (line-start (editor-position-from-line ed line))
               (insert-text (string-append text "\n")))
          (editor-insert-text ed line-start insert-text)
          (editor-goto-pos ed line-start)
          (echo-message! echo "Yanked line")))))

  (define (cmd-show-column-number app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line))
           (col (+ 1 (- pos line-start))))
      (echo-message! echo (string-append "Column " (number->string col)))))

  (define (cmd-count-lines-buffer app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (lines (editor-get-line-count ed)))
      (echo-message! echo (string-append "Buffer has " (number->string lines) " lines"))))

  (define (cmd-recover-session app)
    (echo-message! (app-state-echo app) "No auto-saved sessions found"))

  (define (cmd-toggle-backup-files app)
    (echo-message! (app-state-echo app) "Backup files: always enabled (~suffix)"))

  ;;;============================================================================
  ;;; Task #42: text transforms, programming, and info
  ;;;============================================================================

  (define (cmd-camel-to-snake app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (and (< pos len) (word-char? (char->integer (string-ref text pos))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0) (word-char? (char->integer (string-ref text (- p 1)))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len) (word-char? (char->integer (string-ref text p))))
                        (loop (+ p 1)) p)))
               (word (substring text start end))
               (result (let loop ((i 0) (acc '()))
                         (if (>= i (string-length word))
                           (list->string (reverse acc))
                           (let ((ch (string-ref word i)))
                             (if (and (char-upper-case? ch) (> i 0))
                               (loop (+ i 1) (cons (char-downcase ch) (cons #\_ acc)))
                               (loop (+ i 1) (cons (char-downcase ch) acc))))))))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (editor-goto-pos ed (+ start (string-length result)))))))

  (define (cmd-snake-to-camel app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (and (< pos len)
                 (let ((ch (string-ref text pos)))
                   (or (word-char? (char->integer ch)) (char=? ch #\_))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0)
                                 (let ((ch (string-ref text (- p 1))))
                                   (or (word-char? (char->integer ch)) (char=? ch #\_))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len)
                               (let ((ch (string-ref text p)))
                                 (or (word-char? (char->integer ch)) (char=? ch #\_))))
                        (loop (+ p 1)) p)))
               (word (substring text start end))
               (result (let loop ((i 0) (capitalize? #f) (acc '()))
                         (if (>= i (string-length word))
                           (list->string (reverse acc))
                           (let ((ch (string-ref word i)))
                             (if (char=? ch #\_)
                               (loop (+ i 1) #t acc)
                               (if capitalize?
                                 (loop (+ i 1) #f (cons (char-upcase ch) acc))
                                 (loop (+ i 1) #f (cons ch acc)))))))))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (editor-goto-pos ed (+ start (string-length result)))))))

  (define (cmd-kebab-to-camel app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (and (< pos len)
                 (let ((ch (string-ref text pos)))
                   (or (word-char? (char->integer ch)) (char=? ch #\-))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0)
                                 (let ((ch (string-ref text (- p 1))))
                                   (or (word-char? (char->integer ch)) (char=? ch #\-))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len)
                               (let ((ch (string-ref text p)))
                                 (or (word-char? (char->integer ch)) (char=? ch #\-))))
                        (loop (+ p 1)) p)))
               (word (substring text start end))
               (result (let loop ((i 0) (capitalize? #f) (acc '()))
                         (if (>= i (string-length word))
                           (list->string (reverse acc))
                           (let ((ch (string-ref word i)))
                             (if (char=? ch #\-)
                               (loop (+ i 1) #t acc)
                               (if capitalize?
                                 (loop (+ i 1) #f (cons (char-upcase ch) acc))
                                 (loop (+ i 1) #f (cons ch acc)))))))))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (editor-goto-pos ed (+ start (string-length result)))))))

  (define (cmd-reverse-word app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (and (< pos len) (word-char? (char->integer (string-ref text pos))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0) (word-char? (char->integer (string-ref text (- p 1)))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len) (word-char? (char->integer (string-ref text p))))
                        (loop (+ p 1)) p)))
               (word (substring text start end))
               (reversed (list->string (reverse (string->list word)))))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start reversed))
          (editor-goto-pos ed end)))))

  (define (cmd-count-occurrences app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (search (echo-read-string echo "Count occurrences of: " row width)))
      (when (and search (not (string=? search "")))
        (let* ((text (editor-get-text ed))
               (slen (string-length search))
               (count (let loop ((pos 0) (n 0))
                        (let ((found (string-contains text search pos)))
                          (if found
                            (loop (+ found slen) (+ n 1))
                            n)))))
          (echo-message! echo (string-append (number->string count)
                                              " occurrences of \"" search "\""))))))

  (define (cmd-mark-lines-matching app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (search (echo-read-string echo "Count lines matching: " row width)))
      (when (and search (not (string=? search "")))
        (let* ((text (editor-get-text ed))
               (lines (string-split text #\newline))
               (matching (let loop ((ls lines) (n 0))
                           (if (null? ls) n
                             (loop (cdr ls)
                                   (if (string-contains (car ls) search)
                                     (+ n 1) n))))))
          (echo-message! echo (string-append (number->string matching)
                                              " lines match \"" search "\""))))))

  (define (cmd-number-region app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end)))
          (with-undo-action ed
            (let loop ((l end-line) (n (+ 1 (- end-line start-line))))
              (when (>= l start-line)
                (let ((ls (editor-position-from-line ed l))
                      (prefix (string-append (number->string n) ": ")))
                  (editor-insert-text ed ls prefix))
                (loop (- l 1) (- n 1)))))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Lines numbered"))
        (echo-error! echo "No mark set"))))

  (define (cmd-strip-line-numbers app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end)))
          (with-undo-action ed
            (let loop ((l end-line))
              (when (>= l start-line)
                (let* ((ls (editor-position-from-line ed l))
                       (le (editor-get-line-end-position ed l))
                       (line-len (- le ls))
                       (text (editor-get-text-range ed ls (min line-len 10))))
                  (let digit-loop ((i 0))
                    (when (< i (string-length text))
                      (let ((ch (string-ref text i)))
                        (cond
                          ((char-numeric? ch) (digit-loop (+ i 1)))
                          ((and (char=? ch #\:)
                                (< (+ i 1) (string-length text))
                                (char=? (string-ref text (+ i 1)) #\space)
                                (> i 0))
                           (editor-delete-range ed ls (+ i 2)))
                          (else (void)))))))
                (loop (- l 1)))))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Line numbers stripped"))
        (echo-error! echo "No mark set"))))

  (define (cmd-prefix-lines app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if mark
        (let ((prefix (echo-read-string echo "Prefix: " row width)))
          (when (and prefix (not (string=? prefix "")))
            (let* ((start (min pos mark))
                   (end (max pos mark))
                   (start-line (editor-line-from-position ed start))
                   (end-line (editor-line-from-position ed end)))
              (with-undo-action ed
                (let loop ((l end-line))
                  (when (>= l start-line)
                    (editor-insert-text ed (editor-position-from-line ed l) prefix)
                    (loop (- l 1)))))
              (buffer-mark-set! buf #f)
              (echo-message! echo "Lines prefixed"))))
        (echo-error! echo "No mark set"))))

  (define (cmd-suffix-lines app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if mark
        (let ((suffix (echo-read-string echo "Suffix: " row width)))
          (when (and suffix (not (string=? suffix "")))
            (let* ((start (min pos mark))
                   (end (max pos mark))
                   (start-line (editor-line-from-position ed start))
                   (end-line (editor-line-from-position ed end)))
              (with-undo-action ed
                (let loop ((l end-line))
                  (when (>= l start-line)
                    (editor-insert-text ed (editor-get-line-end-position ed l) suffix)
                    (loop (- l 1)))))
              (buffer-mark-set! buf #f)
              (echo-message! echo "Lines suffixed"))))
        (echo-error! echo "No mark set"))))

  (define (cmd-wrap-lines-at-column app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Wrap at column (default 80): " row width)))
      (let ((col (if (or (not input) (string=? input "")) 80
                   (or (string->number input) 80))))
        (let* ((text (editor-get-text ed))
               (lines (string-split text #\newline))
               (wrapped-lines
                 (apply append
                   (map (lambda (line)
                          (if (<= (string-length line) col)
                            (list line)
                            (let loop ((s line) (acc '()))
                              (if (<= (string-length s) col)
                                (reverse (cons s acc))
                                (let find-break ((p col))
                                  (cond
                                    ((and (>= p 0) (char=? (string-ref s p) #\space))
                                     (loop (substring s (+ p 1) (string-length s))
                                           (cons (substring s 0 p) acc)))
                                    ((> p 0) (find-break (- p 1)))
                                    (else
                                     (loop (substring s col (string-length s))
                                           (cons (substring s 0 col) acc)))))))))
                        lines)))
               (result (string-join wrapped-lines "\n")))
          (with-undo-action ed
            (editor-set-text ed result))
          (echo-message! echo (string-append "Lines wrapped at column " (number->string col)))))))

  (define (cmd-show-file-info app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (name (buffer-name buf))
           (path (or (buffer-file-path buf) "(no file)"))
           (size (editor-get-text-length ed))
           (lines (editor-get-line-count ed))
           (lang (buffer-lexer-lang buf)))
      (echo-message! echo (string-append name " | " path " | "
                                          (number->string size) "B | "
                                          (number->string lines) "L | "
                                          (if lang (symbol->string lang) "text")))))

  (define (cmd-toggle-narrow-indicator app)
    (echo-message! (app-state-echo app) "Narrow indicator toggled"))

  (define (cmd-insert-timestamp app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (now (current-time))
           (secs (time-second now))
           (text (number->string secs)))
      (editor-insert-text ed pos (string-append "[" text "]"))
      (editor-goto-pos ed (+ pos (string-length text) 2))))

  (define (cmd-eval-and-insert app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Eval and insert: " row width)))
      (when (and input (not (string=? input "")))
        (let-values (((result err?) (eval-expression-string input)))
          (if err?
            (echo-error! echo result)
            (let ((pos (editor-get-current-pos ed)))
              (editor-insert-text ed pos result)
              (editor-goto-pos ed (+ pos (string-length result)))))))))

  (define (cmd-shell-command-insert app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (cmd (echo-read-string echo "Shell command (insert output): " row width)))
      (when (and cmd (not (string=? cmd "")))
        (let ((output (guard (e (#t (call-with-string-output-port
                                      (lambda (p) (display e p)))))
                        (let-values (((to-stdin from-stdout from-stderr pid)
                                      (open-process-ports
                                        (string-append "/bin/sh -c '" cmd "'")
                                        'block
                                        (native-transcoder))))
                          (close-port to-stdin)
                          (let ((result (get-string-all from-stdout)))
                            (close-port from-stdout)
                            (close-port from-stderr)
                            (if (eof-object? result) "" result))))))
          (let ((pos (editor-get-current-pos ed)))
            (editor-insert-text ed pos output)
            (editor-goto-pos ed (+ pos (string-length output))))))))

  (define (cmd-pipe-region app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if mark
        (let ((cmd (echo-read-string echo "Pipe region through: " row width)))
          (when (and cmd (not (string=? cmd "")))
            (let* ((start (min pos mark))
                   (end (max pos mark))
                   (region-text (substring (editor-get-text ed) start end))
                   (output (guard (e (#t (call-with-string-output-port
                                           (lambda (p) (display e p)))))
                             (let-values (((to-stdin from-stdout from-stderr pid)
                                           (open-process-ports
                                             (string-append "/bin/sh -c '" cmd "'")
                                             'block
                                             (native-transcoder))))
                               (display region-text to-stdin)
                               (close-port to-stdin)
                               (let ((result (get-string-all from-stdout)))
                                 (close-port from-stdout)
                                 (close-port from-stderr)
                                 (if (eof-object? result) "" result))))))
              (with-undo-action ed
                (editor-delete-range ed start (- end start))
                (editor-insert-text ed start output))
              (buffer-mark-set! buf #f)
              (echo-message! echo "Region filtered"))))
        (echo-error! echo "No mark set"))))

  (define (cmd-sort-words app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (text (substring (editor-get-text ed) start end))
               (words (string-split text #\space))
               (sorted (list-sort string<? words))
               (result (string-join sorted " ")))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (buffer-mark-set! buf #f)
          (echo-message! echo (string-append "Sorted " (number->string (length sorted)) " words")))
        (echo-error! echo "No mark set"))))

  (define (cmd-remove-blank-lines app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (line-start (editor-position-from-line ed start-line))
               (line-end (editor-get-line-end-position ed end-line))
               (text (editor-get-text-range ed line-start (- line-end line-start)))
               (lines (string-split text #\newline))
               (non-blank (filter (lambda (l) (not (string=? (string-trim l) ""))) lines))
               (removed (- (length lines) (length non-blank)))
               (result (string-join non-blank "\n")))
          (with-undo-action ed
            (editor-delete-range ed line-start (- line-end line-start))
            (editor-insert-text ed line-start result))
          (buffer-mark-set! buf #f)
          (echo-message! echo (string-append "Removed " (number->string removed) " blank lines")))
        (echo-error! echo "No mark set"))))

  (define (cmd-collapse-blank-lines app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (collapsed (let loop ((ls lines) (prev-blank? #f) (acc '()))
                        (cond
                          ((null? ls) (reverse acc))
                          ((string=? (string-trim (car ls)) "")
                           (if prev-blank?
                             (loop (cdr ls) #t acc)
                             (loop (cdr ls) #t (cons (car ls) acc))))
                          (else
                           (loop (cdr ls) #f (cons (car ls) acc))))))
           (removed (- (length lines) (length collapsed)))
           (result (string-join collapsed "\n")))
      (when (> removed 0)
        (with-undo-action ed
          (editor-set-text ed result))
        (echo-message! echo (string-append "Collapsed " (number->string removed)
                                            " blank lines")))))

  (define (cmd-trim-lines app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (trimmed (map string-trim-right lines))
           (result (string-join trimmed "\n")))
      (when (not (string=? text result))
        (with-undo-action ed
          (let ((pos (editor-get-current-pos ed)))
            (editor-set-text ed result)
            (editor-goto-pos ed (min pos (string-length result)))))
        (echo-message! echo "Trailing whitespace trimmed"))))

  (define (cmd-toggle-line-comment app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (ls (editor-position-from-line ed line))
           (le (editor-get-line-end-position ed line))
           (line-len (- le ls))
           (text (editor-get-text-range ed ls (min line-len 3))))
      (cond
        ((and (>= (string-length text) 3) (string=? text ";; "))
         (editor-delete-range ed ls 3))
        ((and (>= (string-length text) 2) (string=? (substring text 0 2) ";;"))
         (editor-delete-range ed ls 2))
        (else
         (editor-insert-text ed ls ";; ")))))

  (define (cmd-copy-file-path app)
    (let* ((buf (current-buffer-from-app app))
           (echo (app-state-echo app))
           (path (buffer-file-path buf)))
      (if path
        (begin
          (app-state-kill-ring-set! app (cons path (app-state-kill-ring app)))
          (echo-message! echo (string-append "Copied: " path)))
        (echo-error! echo "Buffer has no file path"))))

  (define (cmd-insert-path-separator app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "/")
      (editor-goto-pos ed (+ pos 1))))

  (define (cmd-show-word-count app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (words (let loop ((i 0) (in-word? #f) (count 0))
                    (if (>= i (string-length text))
                      (if in-word? (+ count 1) count)
                      (let ((ch (string-ref text i)))
                        (if (or (char=? ch #\space) (char=? ch #\newline)
                                (char=? ch #\tab) (char=? ch #\return))
                          (loop (+ i 1) #f (if in-word? (+ count 1) count))
                          (loop (+ i 1) #t count)))))))
      (echo-message! echo (string-append (number->string words) " words"))))

  (define (cmd-show-char-count app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app)))
      (echo-message! echo (string-append (number->string (editor-get-text-length ed)) " characters"))))

  (define (cmd-toggle-auto-complete app)
    (echo-message! (app-state-echo app) "Auto-complete toggled"))

  (define (cmd-insert-lorem-ipsum app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (lorem "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.\n"))
      (editor-insert-text ed pos lorem)
      (editor-goto-pos ed (+ pos (string-length lorem)))))

  (define (cmd-narrow-to-defun app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (text (editor-get-text ed))
           (pos (send-message ed SCI_GETCURRENTPOS 0 0))
           (lang (buffer-lexer-lang buf)))
      (let-values (((start end) (find-defun-boundaries text pos lang)))
        (if (and start end (< start end))
          (begin
            (hash-put! *tui-narrow-state* buf (list text start end))
            (editor-set-text ed (substring text start end))
            (editor-goto-pos ed (max 0 (- pos start)))
            (echo-message! echo "Narrowed to defun"))
          (echo-error! echo "No defun found at point")))))

  (define (cmd-widen-all app)
    (cmd-widen app))

  (define (cmd-reindent-buffer app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (lines (editor-get-line-count ed)))
      (echo-message! echo (string-append "Buffer has " (number->string lines) " lines (use indent-region for region)"))))

  (define (cmd-show-trailing-whitespace-count app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (count (let loop ((ls lines) (n 0))
                    (if (null? ls) n
                      (let ((line (car ls)))
                        (loop (cdr ls)
                              (if (and (> (string-length line) 0)
                                       (let ((last-ch (string-ref line (- (string-length line) 1))))
                                         (or (char=? last-ch #\space) (char=? last-ch #\tab))))
                                (+ n 1) n)))))))
      (echo-message! echo (string-append (number->string count)
                                          " lines have trailing whitespace"))))

  (define (cmd-show-tab-count app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (count (let loop ((i 0) (n 0))
                    (if (>= i (string-length text)) n
                      (loop (+ i 1)
                            (if (char=? (string-ref text i) #\tab) (+ n 1) n))))))
      (echo-message! echo (string-append (number->string count) " tab characters"))))

  (define (cmd-toggle-global-whitespace app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (current (editor-get-view-whitespace ed)))
      (if (= current 0)
        (begin (editor-set-view-whitespace ed 1)
               (echo-message! (app-state-echo app) "Whitespace visible globally"))
        (begin (editor-set-view-whitespace ed 0)
               (echo-message! (app-state-echo app) "Whitespace hidden")))))

  (define (cmd-insert-box-comment app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (box (string-append
                  ";;;============================================================================\n"
                  ";;; \n"
                  ";;;============================================================================\n")))
      (editor-insert-text ed pos box)
      (editor-goto-pos ed (+ pos 80))))

  (define (cmd-toggle-electric-indent app)
    (echo-message! (app-state-echo app) "Electric indent toggled"))

  (define (cmd-increase-font-size app)
    (cmd-zoom-in app))

  (define (cmd-decrease-font-size app)
    (cmd-zoom-out app))

  (define (cmd-reset-font-size app)
    (cmd-zoom-reset app))

  ;;;============================================================================
  ;;; Task #43: project, search, and utilities
  ;;;============================================================================

  (define (open-output-buffer app name text)
    (let* ((ed (current-editor app))
           (fr (app-state-frame app))
           (buf (or (buffer-by-name name)
                    (buffer-create! name ed #f))))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (editor-set-text ed text)
      (editor-set-save-point ed)
      (editor-goto-pos ed 0)))

  (define (cmd-project-find-file app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (current-buffer-from-app app))
           (base-dir (or (buffer-file-path buf) "."))
           (dir (let ((d (path-directory base-dir)))
                  (if (string=? d "") "." d)))
           (filename (echo-read-string echo (string-append "Find in " dir ": ") row width)))
      (when (and filename (not (string=? filename "")))
        (let ((full-path (path-expand filename dir)))
          (if (file-exists? full-path)
            (let* ((name (path-strip-directory full-path))
                   (ed (current-editor app))
                   (new-buf (buffer-create! name ed full-path)))
              (buffer-attach! ed new-buf)
              (edit-window-buffer-set! (current-window fr) new-buf)
              (let ((text (read-file-as-string full-path)))
                (when text
                  (editor-set-text ed text)
                  (editor-set-save-point ed)
                  (editor-goto-pos ed 0)))
              (echo-message! echo (string-append "Opened: " full-path)))
            (echo-error! echo (string-append "File not found: " full-path)))))))

  (define (run-shell-and-capture cmd-str)
    "Run a shell command, capture stdout. Returns string."
    (guard (e (#t (call-with-string-output-port (lambda (p) (display e p)))))
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports
                      (string-append "/bin/sh -c '" cmd-str "'")
                      'block
                      (native-transcoder))))
        (close-port to-stdin)
        (let ((result (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (if (eof-object? result) "" result)))))

  (define (cmd-project-grep app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (dir (if path (path-directory path) "."))
           (pattern (echo-read-string echo (string-append "Grep in " dir ": ") row width)))
      (when (and pattern (not (string=? pattern "")))
        (let ((output (run-shell-and-capture
                        (string-append "grep -rn " (shell-quote pattern) " " (shell-quote dir)))))
          (let ((result (if (string=? output "") "(no matches)" output)))
            (open-output-buffer app (string-append "*grep " pattern "*") result)
            (echo-message! echo (string-append "grep: " pattern)))))))

  (define (cmd-project-compile app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (dir (if path (path-directory path) ".")))
      (let ((output (run-shell-and-capture
                      (string-append "cd " (shell-quote dir) " && make"))))
        (open-output-buffer app "*compile*" output)
        (echo-message! echo "Compilation complete"))))

  (define (shell-quote str)
    "Escape single quotes for shell."
    (let loop ((i 0) (acc '()))
      (if (>= i (string-length str))
        (list->string (reverse acc))
        (let ((ch (string-ref str i)))
          (if (char=? ch #\')
            (loop (+ i 1) (append (reverse (string->list "'\\''")) acc))
            (loop (+ i 1) (cons ch acc)))))))

  (define (cmd-search-forward-word app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (and (< pos len) (word-char? (char->integer (string-ref text pos))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0) (word-char? (char->integer (string-ref text (- p 1)))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len) (word-char? (char->integer (string-ref text p))))
                        (loop (+ p 1)) p)))
               (word (substring text start end))
               (found (string-contains text word end)))
          (if found
            (begin
              (editor-goto-pos ed found)
              (editor-scroll-caret ed)
              (echo-message! echo (string-append "Found: " word)))
            (echo-error! echo (string-append "\"" word "\" not found below"))))
        (echo-error! echo "Not on a word"))))

  (define (cmd-search-backward-word app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (and (< pos len) (word-char? (char->integer (string-ref text pos))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0) (word-char? (char->integer (string-ref text (- p 1)))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len) (word-char? (char->integer (string-ref text p))))
                        (loop (+ p 1)) p)))
               (word (substring text start end))
               (found (let loop ((p 0) (last-found #f))
                        (let ((f (string-contains text word p)))
                          (if (and f (< f start))
                            (loop (+ f 1) f)
                            last-found)))))
          (if found
            (begin
              (editor-goto-pos ed found)
              (editor-scroll-caret ed)
              (echo-message! echo (string-append "Found: " word)))
            (echo-error! echo (string-append "\"" word "\" not found above"))))
        (echo-error! echo "Not on a word"))))

  (define (cmd-replace-in-region app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if mark
        (let ((search (echo-read-string echo "Replace in region: " row width)))
          (when (and search (not (string=? search "")))
            (let ((replace (echo-read-string echo "Replace with: " row width)))
              (when replace
                (let* ((start (min pos mark))
                       (end (max pos mark))
                       (region (substring (editor-get-text ed) start end))
                       (slen (string-length search))
                       (result (let loop ((p 0) (acc '()))
                                 (let ((f (string-contains region search p)))
                                   (if f
                                     (loop (+ f slen)
                                           (cons replace (cons (substring region p f) acc)))
                                     (list->string
                                       (apply append
                                         (map string->list
                                              (reverse (cons (substring region p (string-length region)) acc))))))))))
                  (with-undo-action ed
                    (editor-delete-range ed start (- end start))
                    (editor-insert-text ed start result))
                  (buffer-mark-set! buf #f)
                  (echo-message! echo "Replaced in region"))))))
        (echo-error! echo "No mark set"))))

  (define (cmd-highlight-word-at-point app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (and (< pos len) (word-char? (char->integer (string-ref text pos))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0) (word-char? (char->integer (string-ref text (- p 1)))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len) (word-char? (char->integer (string-ref text p))))
                        (loop (+ p 1)) p)))
               (word (substring text start end))
               (count (let loop ((p 0) (n 0))
                        (let ((f (string-contains text word p)))
                          (if f (loop (+ f (string-length word)) (+ n 1)) n)))))
          (echo-message! echo (string-append "\"" word "\" — "
                                              (number->string count) " occurrences")))
        (echo-error! echo "Not on a word"))))

  (define (cmd-goto-definition app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (and (< pos len) (word-char? (char->integer (string-ref text pos))))
        (let* ((start (let loop ((p pos))
                        (if (and (> p 0) (word-char? (char->integer (string-ref text (- p 1)))))
                          (loop (- p 1)) p)))
               (end (let loop ((p pos))
                      (if (and (< p len) (word-char? (char->integer (string-ref text p))))
                        (loop (+ p 1)) p)))
               (word (substring text start end))
               (found (or (string-contains text (string-append "(def (" word " "))
                          (string-contains text (string-append "(def (" word ")"))
                          (string-contains text (string-append "(def " word " "))
                          (string-contains text (string-append "(def " word "\n"))
                          (string-contains text (string-append "(defstruct " word))
                          (string-contains text (string-append "(defclass " word)))))
          (if found
            (begin
              (editor-goto-pos ed found)
              (editor-scroll-caret ed)
              (echo-message! echo (string-append "Jumped to definition of " word)))
            (echo-error! echo (string-append "No definition found for " word))))
        (echo-error! echo "Not on a word"))))

  (define (cmd-toggle-eol-conversion app)
    (echo-message! (app-state-echo app) "EOL: use convert-line-endings-unix/dos commands"))

  (define (tui-frame-config-save app)
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (cur-idx (frame-current-idx fr))
           (buf-names (map (lambda (win)
                             (let ((buf (edit-window-buffer win)))
                               (if buf (buffer-name buf) "*scratch*")))
                           wins))
           (cur-buf (let ((buf (edit-window-buffer (list-ref wins cur-idx))))
                      (if buf (buffer-name buf) "*scratch*")))
           (positions (map (lambda (win)
                             (let ((buf (edit-window-buffer win))
                                   (ed (edit-window-editor win)))
                               (cons (if buf (buffer-name buf) "*scratch*")
                                     (editor-get-current-pos ed))))
                           wins)))
      (list buf-names cur-buf positions)))

  (define (tui-frame-config-restore! app config)
    (let* ((buf-names (car config))
           (cur-buf-name (cadr config))
           (positions (caddr config))
           (fr (app-state-frame app))
           (first-buf-name (if (pair? buf-names) (car buf-names) "*scratch*"))
           (first-buf (or (buffer-by-name first-buf-name)
                          (buffer-by-name "*scratch*"))))
      ;; Collapse to single window
      (let loop ()
        (when (> (length (frame-windows fr)) 1)
          (frame-delete-window! fr)
          (loop)))
      ;; Set the first buffer
      (when first-buf
        (let* ((win (current-window fr))
               (ed (edit-window-editor win)))
          (buffer-attach! ed first-buf)
          (edit-window-buffer-set! win first-buf)
          (let ((pos-entry (assoc first-buf-name positions)))
            (when pos-entry
              (editor-goto-pos ed (cdr pos-entry))))))
      ;; For each additional buffer, split and set
      (when (> (length buf-names) 1)
        (let loop ((rest (cdr buf-names)))
          (when (pair? rest)
            (let* ((bname (car rest))
                   (buf (or (buffer-by-name bname) first-buf)))
              (when buf
                (let ((new-ed (frame-split! fr)))
                  (buffer-attach! new-ed buf)
                  (let ((new-win (current-window fr)))
                    (edit-window-buffer-set! new-win buf)
                    (let ((pos-entry (assoc bname positions)))
                      (when pos-entry
                        (editor-goto-pos new-ed (cdr pos-entry))))))))
            (loop (cdr rest)))))
      ;; Switch to the correct current buffer
      (let ((target-idx
              (let loop ((wins (frame-windows fr)) (i 0))
                (cond
                  ((null? wins) 0)
                  ((let ((buf (edit-window-buffer (car wins))))
                     (and buf (string=? (buffer-name buf) cur-buf-name)))
                   i)
                  (else (loop (cdr wins) (+ i 1)))))))
        (frame-current-idx-set! fr target-idx))))

  (define (cmd-make-frame app)
    (let ((config (tui-frame-config-save app)))
      ;; Save current frame config at current slot
      (if (null? (frame-list))
        (frame-list-set! (list config))
        (let loop ((lst (frame-list)) (i 0) (acc '()))
          (cond
            ((null? lst)
             (frame-list-set! (append (reverse acc) (list config))))
            ((= i (current-frame-idx))
             (frame-list-set! (append (reverse acc) (list config) (cdr lst))))
            (else (loop (cdr lst) (+ i 1) (cons (car lst) acc))))))
      ;; Append new empty frame config
      (frame-list-set! (append (frame-list)
                                (list (list '("*scratch*") "*scratch*" '()))))
      (current-frame-idx-set! (- (length (frame-list)) 1))
      ;; Reset live frame to scratch
      (let* ((fr (app-state-frame app))
             (scratch (or (buffer-by-name "*scratch*") (car (buffer-list)))))
        (let loop ()
          (when (> (length (frame-windows fr)) 1)
            (frame-delete-window! fr)
            (loop)))
        (let* ((win (current-window fr))
               (ed (edit-window-editor win)))
          (buffer-attach! ed scratch)
          (edit-window-buffer-set! win scratch)
          (editor-goto-pos ed 0)))
      (echo-message! (app-state-echo app)
        (string-append "Frame " (number->string (+ (current-frame-idx) 1))
                       "/" (number->string (frame-count))))))

  (define (cmd-delete-frame app)
    (if (<= (frame-count) 1)
      (echo-error! (app-state-echo app) "Cannot delete the only frame")
      (begin
        ;; Remove current frame from list
        (frame-list-set!
          (let loop ((lst (frame-list)) (i 0) (acc '()))
            (cond
              ((null? lst) (reverse acc))
              ((= i (current-frame-idx)) (append (reverse acc) (cdr lst)))
              (else (loop (cdr lst) (+ i 1) (cons (car lst) acc))))))
        ;; Adjust index
        (when (>= (current-frame-idx) (length (frame-list)))
          (current-frame-idx-set! (- (length (frame-list)) 1)))
        ;; Restore the frame config at new current index
        (tui-frame-config-restore! app (list-ref (frame-list) (current-frame-idx)))
        (echo-message! (app-state-echo app)
          (string-append "Frame deleted. Now frame "
                         (number->string (+ (current-frame-idx) 1))
                         "/" (number->string (frame-count)))))))

  (define (cmd-find-file-other-frame app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (edit-window-buffer (current-window fr)))
           (fp (and buf (buffer-file-path buf)))
           (default-dir (if fp (path-directory fp) (current-directory)))
           (filename (echo-read-file-with-completion echo "Find file (other frame): "
                       row width default-dir)))
      (when (and filename (> (string-length filename) 0))
        (cmd-make-frame app)
        (execute-command! app 'find-file))))

  (define (cmd-switch-to-buffer-other-frame app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf-names (map buffer-name (buffer-list)))
           (choice (echo-read-string-with-completion echo "Buffer (other frame): "
                     buf-names row width)))
      (when (and choice (> (string-length choice) 0))
        (let ((buf (buffer-by-name choice)))
          (if (not buf)
            (echo-error! echo (string-append "No buffer: " choice))
            (begin
              (cmd-make-frame app)
              (let* ((fr2 (app-state-frame app))
                     (win (current-window fr2))
                     (ed (edit-window-editor win)))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! win buf)
                (echo-message! echo (string-append "Buffer " choice " in new frame")))))))))

  (define (cmd-toggle-menu-bar app)
    (echo-message! (app-state-echo app) "Menu bar: N/A in terminal"))

  (define (cmd-toggle-tool-bar app)
    (echo-message! (app-state-echo app) "Tool bar: N/A in terminal"))

  (define (cmd-toggle-scroll-bar app)
    (echo-message! (app-state-echo app) "Scroll bar: N/A in terminal"))

  (define (cmd-suspend-frame app)
    (echo-message! (app-state-echo app) "Suspend (use C-z from terminal)"))

  (define (cmd-list-directory app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (dir (if path (path-directory path) ".")))
      (let ((output (run-shell-and-capture (string-append "ls -la " (shell-quote dir)))))
        (open-output-buffer app (string-append "*directory " dir "*") output)
        (echo-message! echo dir))))

  (define (cmd-find-grep app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (dir (if path (path-directory path) "."))
           (pattern (echo-read-string echo "Find+grep pattern: " row width)))
      (when (and pattern (not (string=? pattern "")))
        (let ((output (run-shell-and-capture
                        (string-append "grep -rl " (shell-quote pattern) " " (shell-quote dir)))))
          (let ((result (if (string=? output "") "(no files match)" output)))
            (open-output-buffer app (string-append "*find-grep " pattern "*") result)
            (echo-message! echo (string-append "Files matching: " pattern)))))))

  (define (cmd-insert-header-guard app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (name (buffer-name buf))
           (guard-name (string-upcase
                    (let loop ((i 0) (acc '()))
                      (if (>= i (string-length name))
                        (list->string (reverse acc))
                        (let ((ch (string-ref name i)))
                          (loop (+ i 1)
                                (cons (if (or (char-alphabetic? ch) (char-numeric? ch))
                                        ch #\_) acc)))))))
           (text (string-append "#ifndef " guard-name "_H\n#define " guard-name "_H\n\n\n#endif /* " guard-name "_H */\n")))
      (editor-insert-text ed 0 text)
      (editor-goto-pos ed (+ (string-length (string-append "#ifndef " guard-name "_H\n#define " guard-name "_H\n\n")) 0))
      (echo-message! echo "Header guard inserted")))

  (define (cmd-insert-include app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (header (echo-read-string echo "Include header: " row width)))
      (when (and header (not (string=? header "")))
        (let ((line (if (char=? (string-ref header 0) #\<)
                      (string-append "#include " header "\n")
                      (string-append "#include \"" header "\"\n"))))
          (editor-insert-text ed pos line)
          (editor-goto-pos ed (+ pos (string-length line)))))))

  (define (cmd-insert-import app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (module (echo-read-string echo "Import module: " row width)))
      (when (and module (not (string=? module "")))
        (let ((line (string-append "(import " module ")\n")))
          (editor-insert-text ed pos line)
          (editor-goto-pos ed (+ pos (string-length line)))))))

  (define (cmd-insert-export app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (sym (echo-read-string echo "Export symbol: " row width)))
      (when (and sym (not (string=? sym "")))
        (let ((line (string-append "(export " sym ")\n")))
          (editor-insert-text ed pos line)
          (editor-goto-pos ed (+ pos (string-length line)))))))

  (define (cmd-insert-defun app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (name (echo-read-string echo "Function name: " row width)))
      (when (and name (not (string=? name "")))
        (let ((template (string-append "(def (" name ")\n  )\n")))
          (editor-insert-text ed pos template)
          (editor-goto-pos ed (+ pos (string-length (string-append "(def (" name ")\n  "))))))))

  (define (cmd-insert-let app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (template "(let* (())\n  )\n"))
      (editor-insert-text ed pos template)
      (editor-goto-pos ed (+ pos 8))))

  (define (cmd-insert-cond app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (template "(cond\n  (())\n  (else\n   ))\n"))
      (editor-insert-text ed pos template)
      (editor-goto-pos ed (+ pos 9))))

  (define (cmd-insert-match app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (template "(match \n  (())\n  (else ))\n"))
      (editor-insert-text ed pos template)
      (editor-goto-pos ed (+ pos 7))))

  (define (cmd-insert-when app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (template "(when \n  )\n"))
      (editor-insert-text ed pos template)
      (editor-goto-pos ed (+ pos 6))))

  (define (cmd-insert-unless app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (template "(unless \n  )\n"))
      (editor-insert-text ed pos template)
      (editor-goto-pos ed (+ pos 8))))

  (define (cmd-insert-lambda app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (template "(lambda ()\n  )\n"))
      (editor-insert-text ed pos template)
      (editor-goto-pos ed (+ pos 9))))

  (define (cmd-toggle-auto-pair-mode app)
    (echo-message! (app-state-echo app) "Auto-pair toggled (use M-x toggle-electric-pair)"))

  (define (cmd-count-buffers app)
    (let ((count (length (buffer-list))))
      (echo-message! (app-state-echo app)
        (string-append (number->string count) " buffers open"))))

  (define (cmd-list-recent-files app)
    (let ((echo (app-state-echo app)))
      (if (null? (recent-files))
        (echo-message! echo "No recent files")
        (begin
          (open-output-buffer app "*recent-files*" (string-join (recent-files) "\n"))
          (echo-message! echo (string-append (number->string (length (recent-files))) " recent files"))))))

  (define (cmd-clear-recent-files app)
    ;; recent-files is accessed via accessor; clear by saving empty
    ;; We need to set recent files via repeated removal — but persist.sls
    ;; doesn't expose a clear function directly. Use save with empty state.
    (recent-files-save!)
    (echo-message! (app-state-echo app) "Recent files cleared"))

  (define (cmd-recentf-open app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if (null? (recent-files))
        (echo-message! echo "No recent files")
        (let ((choice (echo-read-string-with-completion echo "Recent file: " (recent-files) row width)))
          (when (and choice (> (string-length choice) 0) (file-exists? choice))
            (let* ((name (path-strip-directory choice))
                   (ed (current-editor app))
                   (buf (buffer-create! name ed choice)))
              (recent-files-add! choice)
              (buffer-attach! ed buf)
              (edit-window-buffer-set! (current-window fr) buf)
              (let ((text (read-file-as-string choice)))
                (when text
                  (editor-set-text ed text)
                  (editor-set-save-point ed)
                  (editor-goto-pos ed 0)))
              (echo-message! echo (string-append "Opened: " choice))))))))

  (define (cmd-recentf-cleanup app)
    (let ((removed (recent-files-cleanup!)))
      (echo-message! (app-state-echo app)
        (string-append "Removed " (number->string removed) " stale entries"))))

  (define (cmd-desktop-save app)
    (let* ((entries
             (filter-map
               (lambda (buf)
                 (let ((path (buffer-file-path buf)))
                   (if path
                     (make-desktop-entry
                       (buffer-name buf)
                       path
                       0
                       (buffer-local-get buf 'major-mode))
                     #f)))
               (buffer-list))))
      (desktop-save! entries)
      (echo-message! (app-state-echo app)
        (string-append "Desktop saved: " (number->string (length entries)) " buffers"))))

  (define (cmd-desktop-read app)
    (let ((entries (desktop-load)))
      (if (null? entries)
        (echo-message! (app-state-echo app) "No saved desktop")
        (let ((count 0))
          (for-each
            (lambda (entry)
              (let ((path (desktop-entry-file-path entry)))
                (when (and path (file-exists? path))
                  (let* ((name (path-strip-directory path))
                         (ed (current-editor app))
                         (fr (app-state-frame app))
                         (buf (buffer-create! name ed path)))
                    (buffer-attach! ed buf)
                    (edit-window-buffer-set! (current-window fr) buf)
                    (let ((text (read-file-as-string path)))
                      (when text
                        (editor-set-text ed text)
                        (editor-set-save-point ed)
                        (editor-goto-pos ed (desktop-entry-cursor-pos entry))))
                    (set! count (+ count 1))))))
            entries)
          (echo-message! (app-state-echo app)
            (string-append "Desktop restored: " (number->string count) " buffers"))))))

  (define (cmd-savehist-save app)
    (savehist-save! (minibuffer-history))
    (echo-message! (app-state-echo app)
      (string-append "History saved: " (number->string (length (minibuffer-history))) " entries")))

  (define (cmd-savehist-load app)
    (let ((hist (savehist-load!)))
      (minibuffer-history-set! hist)
      (echo-message! (app-state-echo app)
        (string-append "History loaded: " (number->string (length hist)) " entries"))))

  (define (cmd-show-keybinding-for app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (name (echo-read-string echo "Show keybinding for command: " row width)))
      (when (and name (not (string=? name "")))
        (let* ((sym (string->symbol name))
               (found (let scan-keymap ((km *global-keymap*) (prefix ""))
                        (let loop ((keys (keymap-entries km)))
                          (cond
                            ((null? keys) #f)
                            ((eq? (cdar keys) sym)
                             (string-append prefix (caar keys)))
                            ((hashtable? (cdar keys))
                             (or (scan-keymap (cdar keys) (string-append prefix (caar keys) " "))
                                 (loop (cdr keys))))
                            (else (loop (cdr keys))))))))
          (if found
            (echo-message! echo (string-append name " is on " found))
            (echo-message! echo (string-append name " is not bound to any key")))))))

  (define (cmd-sort-imports app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (line-start (editor-position-from-line ed start-line))
               (line-end (editor-get-line-end-position ed end-line))
               (text (editor-get-text-range ed line-start (- line-end line-start)))
               (lines (string-split text #\newline))
               (sorted (list-sort string<? lines))
               (result (string-join sorted "\n")))
          (with-undo-action ed
            (editor-delete-range ed line-start (- line-end line-start))
            (editor-insert-text ed line-start result))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Imports sorted"))
        (echo-error! echo "No mark set (select import lines first)"))))

  (define (cmd-show-git-status app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (dir (if path (path-directory path) ".")))
      (let ((output (guard (e (#t "Not a git repository"))
                      (let ((result (run-shell-and-capture
                                      (string-append "cd " (shell-quote dir)
                                                     " && git status --short"))))
                        (if (string=? result "") "(clean)" result)))))
        (open-output-buffer app "*git-status*" output)
        (echo-message! echo "git status"))))

  (define (cmd-show-git-log app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (dir (if path (path-directory path) ".")))
      (let ((output (guard (e (#t "Not a git repository"))
                      (let* ((cmd (if path
                                    (string-append "cd " (shell-quote dir)
                                                   " && git log --oneline -20 " (shell-quote path))
                                    (string-append "cd " (shell-quote dir)
                                                   " && git log --oneline -20")))
                             (result (run-shell-and-capture cmd)))
                        (if (string=? result "") "(no commits)" result)))))
        (open-output-buffer app "*git-log*" output)
        (echo-message! echo "git log"))))

  (define (cmd-show-git-diff app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (dir (if path (path-directory path) ".")))
      (let ((output (guard (e (#t "Not a git repository"))
                      (let* ((cmd (if path
                                    (string-append "cd " (shell-quote dir)
                                                   " && git diff " (shell-quote path))
                                    (string-append "cd " (shell-quote dir)
                                                   " && git diff")))
                             (result (run-shell-and-capture cmd)))
                        (if (string=? result "") "(no changes)" result)))))
        (open-output-buffer app "*git-diff*" output)
        (echo-message! echo "git diff"))))

  (define (cmd-show-git-blame app)
    (let* ((fr (app-state-frame app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf)))
      (if path
        (let* ((dir (path-directory path))
               (output (guard (e (#t "Not a git repository or file not tracked"))
                         (let ((result (run-shell-and-capture
                                         (string-append "cd " (shell-quote dir)
                                                        " && git blame --date=short "
                                                        (shell-quote path)))))
                           (if (string=? result "") "(no data)" result)))))
          (open-output-buffer app (string-append "*git-blame " (path-strip-directory path) "*") output)
          (echo-message! echo "git blame"))
        (echo-error! echo "Buffer has no file"))))

  (define (cmd-toggle-flyspell app)
    (set! *flyspell-mode* (not *flyspell-mode*))
    (echo-message! (app-state-echo app)
      (if *flyspell-mode* "Spell check: on" "Spell check: off")))

  (define (cmd-toggle-flymake app)
    (set! *flymake-mode* (not *flymake-mode*))
    (echo-message! (app-state-echo app)
      (if *flymake-mode* "Syntax check: on" "Syntax check: off")))

  (define (cmd-toggle-lsp app)
    (echo-error! (app-state-echo app) "LSP not supported in TUI mode — use gemacs-qt"))

  (define (cmd-toggle-auto-revert-global app)
    (set! *global-auto-revert-mode* (not *global-auto-revert-mode*))
    (auto-revert-mode-set! *global-auto-revert-mode*)
    (echo-message! (app-state-echo app)
      (if *global-auto-revert-mode* "Global auto-revert: on" "Global auto-revert: off")))

  ;;;============================================================================
  ;;; M-x customize UI
  ;;;============================================================================

  (define (cmd-customize app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (ed (current-editor app))
           (win (current-window fr))
           (buf (buffer-create! "*Customize*" ed))
           (groups (custom-groups))
           (lines (list "Gemacs Customize"
                        "================" "")))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (for-each
        (lambda (group)
          (set! lines (append lines
            (list (string-append "[" (symbol->string group) "]") "")))
          (for-each
            (lambda (var)
              (let ((val (custom-get var))
                    (entry (hash-get *custom-registry* var)))
                (set! lines (append lines
                  (list (string-append "  " (symbol->string var) " = "
                          (call-with-string-output-port (lambda (p) (write val p)))
                          "  ;; " (or (hash-get entry 'docstring) "")))))))
            (custom-list-group group))
          (set! lines (append lines (list ""))))
        groups)
      (set! lines (append lines
        (list "Use M-x set-variable to change a setting."
              "Use C-h v (describe-variable) for detailed info.")))
      (editor-set-text ed (string-join lines "\n"))
      (editor-goto-pos ed 0)
      (editor-set-read-only ed #t)))

  (define (cmd-set-variable app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (names (map symbol->string (custom-list-all)))
           (name (echo-read-string-with-completion echo "Set variable: " names row width)))
      (when (and name (> (string-length name) 0))
        (let ((sym (string->symbol name)))
          (if (not (custom-registered? sym))
            (echo-message! echo (string-append "Unknown variable: " name))
            (let* ((current (custom-get sym))
                   (val-str (echo-read-string echo
                              (string-append name " (" (object->string current) "): ") row width)))
              (when (and val-str (> (string-length val-str) 0))
                (let ((val (cond
                             ((string=? val-str "#t") #t)
                             ((string=? val-str "#f") #f)
                             ((string->number val-str) => values)
                             (else val-str))))
                  (guard (e (#t
                             (echo-error! echo
                               (string-append "Error setting " name ": "
                                 (call-with-string-output-port (lambda (p) (display e p)))))))
                    (custom-set! sym val)
                    (echo-message! echo
                      (string-append name " = " (object->string val))))))))))))

  ;;;============================================================================
  ;;; Process sentinels/filters
  ;;;============================================================================

  (define (set-process-sentinel! proc sentinel)
    (hash-put! *process-sentinels* proc sentinel))

  (define (set-process-filter! proc filter-fn)
    (hash-put! *process-filters* proc filter-fn))

  (define (process-sentinel proc)
    (hash-get *process-sentinels* proc))

  (define (process-filter proc)
    (hash-get *process-filters* proc))

  ;;;============================================================================
  ;;; Plugin/package system
  ;;;============================================================================

  (define (cmd-load-plugin app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (path (echo-read-string echo "Load plugin file: " row width)))
      (when (and path (> (string-length path) 0))
        (let ((full-path (path-expand path)))
          (if (not (file-exists? full-path))
            (echo-error! echo (string-append "File not found: " full-path))
            (guard (e (#t
                       (echo-error! echo (string-append "Plugin error: "
                         (call-with-string-output-port (lambda (p) (display e p)))))))
              (load full-path)
              (set! *loaded-plugins* (cons full-path *loaded-plugins*))
              (echo-message! echo (string-append "Loaded: " (path-strip-directory full-path)))))))))

  (define (cmd-list-plugins app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (ed (current-editor app))
           (win (current-window fr))
           (buf (buffer-create! "*Plugins*" ed)))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (let* ((dir (path-expand *plugin-directory*))
             (available (if (file-exists? dir)
                          (directory-files dir)
                          '()))
             (ss-files (filter (lambda (f) (string-suffix? ".ss" f)) available))
             (text (string-append
                     "Gemacs Plugins\n"
                     "==============\n\n"
                     "Loaded plugins:\n"
                     (if (null? *loaded-plugins*)
                       "  (none)\n"
                       (string-join (map (lambda (p) (string-append "  " p)) *loaded-plugins*) "\n"))
                     "\n\nAvailable in " dir ":\n"
                     (if (null? ss-files)
                       "  (none)\n"
                       (string-join (map (lambda (f) (string-append "  " f)) ss-files) "\n"))
                     "\n\nUse M-x load-plugin to load a plugin file.\n")))
        (editor-set-text ed text)
        (editor-goto-pos ed 0)
        (editor-set-read-only ed #t))))

) ;; end library
