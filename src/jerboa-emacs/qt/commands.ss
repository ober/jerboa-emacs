;;; -*- Gerbil -*-
;;; Qt commands facade for jerboa-emacs
;;;
;;; CONSOLIDATED STUB VERSION - Sprint 3
;;; Ported from gerbil-emacs/qt/commands*.ss (30 files, ~42,700 lines)
;;; This stub provides interface compatibility for core commands.
;;; Full implementations to be ported incrementally in Sprint 3-4.

(export #t)

(import :std/sugar
        :jerboa-emacs/qt/sci-shim
        :jerboa-emacs/core
        :jerboa-emacs/qt/buffer
        :jerboa-emacs/qt/window
        :jerboa-emacs/qt/echo
        :jerboa-emacs/qt/highlight
        :jerboa-emacs/qt/modeline)

;;;============================================================================
;;; Winner mode (window configuration undo/redo) - STUB
;;;============================================================================

(def *winner-history* [])
(def *winner-future* [])
(def *winner-max-history* 50)

(def (winner-snapshot-tree node) '(leaf "stub"))
(def (winner-snapshot-count node) 1)
(def (winner-snapshot-leaf-names node) '("stub"))
(def (winner-current-config fr) '(leaf "stub"))
(def (winner-save! fr) (void))
(def (winner-restore-config! fr config) (void))
(def (cmd-winner-undo) (void))
(def (cmd-winner-redo) (void))

;;;============================================================================
;;; Accessors - STUB
;;;============================================================================

(def (current-qt-editor) #f)
(def (current-qt-buffer) #f)

;;;============================================================================
;;; Kill ring / clipboard - STUB
;;;============================================================================

(def (qt-kill-ring-push! text) (void))
(def (qt-clipboard-or-kill-ring) "")

;;;============================================================================
;;; Theme support - STUB
;;;============================================================================

(def (theme-color name) "#000000")
(def (load-theme! name) (void))
(def (load-theme name) (void))
(def (define-theme! name spec) (void))
(def (theme-stylesheet name) "")
(def (apply-theme! app theme) (void))

;;;============================================================================
;;; Auto-save - STUB
;;;============================================================================

(def (make-auto-save-path file-path) #f)
(def (buffer-touch! buf) (void))

;;;============================================================================
;;; Core navigation commands - STUB
;;;============================================================================

(def (cmd-forward-char) (void))
(def (cmd-backward-char) (void))
(def (cmd-forward-word) (void))
(def (cmd-backward-word) (void))
(def (cmd-next-line) (void))
(def (cmd-previous-line) (void))
(def (cmd-beginning-of-line) (void))
(def (cmd-end-of-line) (void))
(def (cmd-beginning-of-buffer) (void))
(def (cmd-end-of-buffer) (void))
(def (cmd-scroll-up-command) (void))
(def (cmd-scroll-down-command) (void))
(def (cmd-recenter-top-bottom) (void))

;;;============================================================================
;;; Editing commands - STUB
;;;============================================================================

(def (cmd-self-insert-command) (void))
(def (cmd-delete-char) (void))
(def (cmd-delete-backward-char) (void))
(def (cmd-kill-line) (void))
(def (cmd-kill-region) (void))
(def (cmd-kill-ring-save) (void))
(def (cmd-yank) (void))
(def (cmd-yank-pop) (void))
(def (cmd-undo) (void))
(def (cmd-redo) (void))
(def (cmd-newline) (void))
(def (cmd-open-line) (void))
(def (cmd-transpose-chars) (void))
(def (cmd-transpose-words) (void))
(def (cmd-transpose-lines) (void))

;;;============================================================================
;;; Mark/selection commands - STUB
;;;============================================================================

(def (cmd-set-mark-command) (void))
(def (cmd-mark-whole-buffer) (void))
(def (cmd-mark-paragraph) (void))
(def (cmd-mark-defun) (void))
(def (cmd-exchange-point-and-mark) (void))

;;;============================================================================
;;; File commands - STUB
;;;============================================================================

(def (cmd-find-file) (void))
(def (cmd-find-file-other-window) (void))
(def (cmd-save-buffer) (void))
(def (cmd-save-some-buffers) (void))
(def (cmd-write-file) (void))
(def (cmd-revert-buffer) (void))
(def (cmd-dired) (void))

;;;============================================================================
;;; Buffer commands - STUB
;;;============================================================================

(def (cmd-switch-to-buffer) (void))
(def (cmd-switch-to-buffer-other-window) (void))
(def (cmd-kill-buffer) (void))
(def (cmd-list-buffers) (void))
(def (cmd-bury-buffer) (void))
(def (cmd-rename-buffer) (void))

;;;============================================================================
;;; Window commands - STUB
;;;============================================================================

(def (cmd-split-window-below) (void))
(def (cmd-split-window-right) (void))
(def (cmd-delete-window) (void))
(def (cmd-delete-other-windows) (void))
(def (cmd-other-window) (void))
(def (cmd-balance-windows) (void))

;;;============================================================================
;;; Search commands - STUB
;;;============================================================================

(def (cmd-isearch-forward) (void))
(def (cmd-isearch-backward) (void))
(def (cmd-query-replace) (void))
(def (cmd-replace-string) (void))
(def (cmd-occur) (void))
(def (cmd-grep) (void))
(def (cmd-rgrep) (void))

;;;============================================================================
;;; S-expression commands - STUB
;;;============================================================================

(def (cmd-forward-sexp) (void))
(def (cmd-backward-sexp) (void))
(def (cmd-up-list) (void))
(def (cmd-down-list) (void))
(def (cmd-kill-sexp) (void))
(def (cmd-mark-sexp) (void))
(def (cmd-transpose-sexps) (void))
(def (cmd-paredit-forward-slurp-sexp) (void))
(def (cmd-paredit-forward-barf-sexp) (void))
(def (cmd-paredit-backward-slurp-sexp) (void))
(def (cmd-paredit-backward-barf-sexp) (void))

;;;============================================================================
;;; Shell/Terminal commands - STUB
;;;============================================================================

(def (cmd-shell) (void))
(def (cmd-eshell) (void))
(def (cmd-term) (void))
(def (cmd-shell-command) (void))
(def (cmd-async-shell-command) (void))

;;;============================================================================
;;; VCS commands - STUB
;;;============================================================================

(def (cmd-magit-status) (void))
(def (cmd-vc-diff) (void))
(def (cmd-vc-revert) (void))

;;;============================================================================
;;; IDE/LSP commands - STUB
;;;============================================================================

(def (cmd-lsp-start) (void))
(def (cmd-lsp-stop) (void))
(def (cmd-lsp-goto-definition) (void))
(def (cmd-lsp-find-references) (void))
(def (cmd-lsp-rename) (void))
(def (cmd-lsp-format) (void))
(def (cmd-lsp-hover) (void))
(def (cmd-lsp-code-action) (void))

;;;============================================================================
;;; Mode commands - STUB
;;;============================================================================

(def (cmd-fundamental-mode) (void))
(def (cmd-text-mode) (void))
(def (cmd-lisp-mode) (void))
(def (cmd-scheme-mode) (void))
(def (cmd-python-mode) (void))
(def (cmd-c-mode) (void))
(def (cmd-org-mode) (void))

;;;============================================================================
;;; Config commands - STUB
;;;============================================================================

(def (cmd-customize) (void))
(def (cmd-eval-expression) (void))
(def (cmd-eval-last-sexp) (void))
(def (cmd-eval-buffer) (void))

;;;============================================================================
;;; Help commands - STUB
;;;============================================================================

(def (cmd-describe-key) (void))
(def (cmd-describe-function) (void))
(def (cmd-describe-variable) (void))
(def (cmd-apropos) (void))

;;;============================================================================
;;; Misc commands - STUB
;;;============================================================================

(def (cmd-keyboard-quit) (void))
(def (cmd-suspend-frame) (void))
(def (cmd-save-buffers-kill-terminal) (void))
(def (cmd-quoted-insert) (void))
(def (cmd-universal-argument) (void))
