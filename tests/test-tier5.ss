#!chezscheme
;;; test-tier5.ss — Tests for Tier 5 modules (editor extras)
;;;
;;; Tests pure logic parts of the editor-extra-* modules.
;;; Modules that require a live terminal/scintilla instance
;;; are only import-tested here.

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1- sort sort!)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs editor-extra-modes)
        (jerboa-emacs editor-extra-tools2)
        (jerboa-emacs editor-extra-regs)
        (jerboa-emacs editor-extra-regs2)
        (jerboa-emacs editor-extra))

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

;;; --- Smoke tests: verify modules loaded with expected exports ---

(check (procedure? register-parity-commands!) => #t)
(check (procedure? register-batch6-commands!) => #t)
(check (procedure? forge-run-gh) => #t)
(check (procedure? forge-show-in-buffer!) => #t)
(check (procedure? eww-load-bookmarks!) => #t)
(check (procedure? eww-save-bookmarks!) => #t)
(check (procedure? find-project-root) => #t)
(check (procedure? magit-run-git-tui) => #t)
(check (procedure? get-tui-terminal-buffers) => #t)

;;; Report
(display (string-append "Tier 5: " (number->string pass-count) " passed, "
           (number->string fail-count) " failed.\n"))
(when (> fail-count 0) (exit 1))
