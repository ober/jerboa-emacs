#!chezscheme
;;; test-persist.ss — Tests for persist module
;;; Ported from gerbil-emacs/persist-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs persist)
        (std srfi srfi-13))

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

;;; ========================================================================
;;; Recent files
;;; ========================================================================

(display "--- recent-files ---\n")

(let ((saved *recent-files*))
  (set! *recent-files* '())
  (recent-files-add! "/tmp/foo.txt")
  (recent-files-add! "/tmp/bar.txt")
  (recent-files-add! "/tmp/foo.txt")  ; duplicate — should deduplicate
  (check (length *recent-files*) => 2)
  (check-true (string-suffix? "foo.txt" (car *recent-files*)))
  (set! *recent-files* saved))

(let ((saved *recent-files*))
  (set! *recent-files* '())
  (let loop ([i 0])
    (when (< i 55)
      (recent-files-add! (string-append "/tmp/file" (number->string i) ".txt"))
      (loop (+ i 1))))
  (check-true (<= (length *recent-files*) 50))
  (set! *recent-files* saved))

;;; ========================================================================
;;; Desktop entry
;;; ========================================================================

(display "--- desktop-entry ---\n")

(let ((de (make-desktop-entry "test.txt" "/tmp/test.txt" 42 'scheme-mode)))
  (check-true (desktop-entry? de))
  (check (desktop-entry-buffer-name de) => "test.txt")
  (check (desktop-entry-file-path de) => "/tmp/test.txt")
  (check (desktop-entry-cursor-pos de) => 42)
  (check (desktop-entry-major-mode de) => 'scheme-mode))

;;; ========================================================================
;;; Desktop save/load round-trip
;;; ========================================================================

(display "--- desktop-round-trip ---\n")

(let ((entries (list
                 (make-desktop-entry "foo.ss" "/tmp/foo.ss" 42 'scheme-mode)
                 (make-desktop-entry "bar.py" "/tmp/bar.py" 100 'python-mode))))
  (desktop-save! entries)
  (let ((loaded (desktop-load)))
    (check (length loaded) => 2)
    (check (desktop-entry-buffer-name (car loaded)) => "foo.ss")
    (check (desktop-entry-file-path (car loaded)) => "/tmp/foo.ss")
    (check (desktop-entry-cursor-pos (car loaded)) => 42)
    (check (desktop-entry-major-mode (car loaded)) => 'scheme-mode)
    (check (desktop-entry-file-path (cadr loaded)) => "/tmp/bar.py")
    (check (desktop-entry-major-mode (cadr loaded)) => 'python-mode)))

;;; ========================================================================
;;; Auto-mode detection
;;; ========================================================================

(display "--- auto-mode ---\n")

(check (detect-major-mode "foo.ss") => 'scheme-mode)
(check (detect-major-mode "bar.py") => 'python-mode)
(check (detect-major-mode "baz.org") => 'org-mode)
(check (detect-major-mode "readme.md") => 'markdown-mode)
(check (detect-major-mode "main.rs") => 'rust-mode)
(check (detect-major-mode "app.js") => 'js-mode)
(check (detect-major-mode "Makefile") => 'makefile-mode)
(check (detect-major-mode "style.css") => 'css-mode)
(check (detect-major-mode "data.json") => 'json-mode)
(check (detect-major-mode "unknown.xyz") => #f)

;;; ========================================================================
;;; Buffer locals
;;; ========================================================================

(display "--- buffer-locals ---\n")

(let ((buf 'test-buf))
  (buffer-local-set! buf 'tab-width 4)
  (check (buffer-local-get buf 'tab-width) => 4)
  (check (buffer-local-get buf 'nonexistent 99) => 99)
  (buffer-local-delete! buf)
  (check (buffer-local-get buf 'tab-width) => #f))

;;; ========================================================================
;;; Save-place
;;; ========================================================================

(display "--- save-place ---\n")

(let ((saved-alist *save-place-alist*)
      (saved-enabled *save-place-enabled*))
  (set! *save-place-enabled* #t)
  (set! *save-place-alist* (make-hash-table))
  (save-place-remember! "/tmp/test-file.txt" 42)
  (check (save-place-restore "/tmp/test-file.txt") => 42)
  (check (save-place-restore "/tmp/nonexistent.txt") => #f)
  (set! *save-place-alist* saved-alist)
  (set! *save-place-enabled* saved-enabled))

(let ((saved-alist *save-place-alist*)
      (saved-enabled *save-place-enabled*))
  (set! *save-place-enabled* #t)
  (set! *save-place-alist* (make-hash-table))
  (save-place-remember! "/tmp/a.txt" 100)
  (save-place-remember! "/tmp/b.txt" 200)
  (save-place-save!)
  (set! *save-place-alist* (make-hash-table))
  (save-place-load!)
  (check (save-place-restore "/tmp/a.txt") => 100)
  (check (save-place-restore "/tmp/b.txt") => 200)
  (set! *save-place-alist* saved-alist)
  (set! *save-place-enabled* saved-enabled))

;;; ========================================================================
;;; M-x history
;;; ========================================================================

(display "--- mx-history ---\n")

(check-true (hash-table? (mx-history)))

(let ((saved *mx-history*))
  (set! *mx-history* (make-hash-table))
  (mx-history-add! "find-file")
  (mx-history-add! "find-file")
  (mx-history-add! "save-buffer")
  (check (hash-get *mx-history* "find-file") => 2)
  (check (hash-get *mx-history* "save-buffer") => 1)
  (set! *mx-history* saved))

(let ((saved *mx-history*))
  (set! *mx-history* (make-hash-table))
  (mx-history-add! "save-buffer")
  (mx-history-add! "find-file")
  (mx-history-add! "find-file")
  (mx-history-add! "find-file")
  (let ((ordered (mx-history-ordered-candidates
                  '("find-file" "goto-line" "save-buffer"))))
    (check (car ordered) => "find-file")
    (check (cadr ordered) => "save-buffer")
    (check (caddr ordered) => "goto-line"))
  (set! *mx-history* saved))

;; Mx-history save/load round-trip
(let ((saved *mx-history*)
      (saved-file *mx-history-file*))
  (let ((test-file (string-append (getenv "HOME") "/.jerboa-mx-history-test")))
    (set! *mx-history* (make-hash-table))
    (set! *mx-history-file* test-file)
    (mx-history-add! "find-file")
    (mx-history-add! "find-file")
    (mx-history-add! "save-buffer")
    (mx-history-save!)
    (set! *mx-history* (make-hash-table))
    (mx-history-load!)
    (check (hash-get *mx-history* "find-file") => 2)
    (check (hash-get *mx-history* "save-buffer") => 1)
    (when (file-exists? test-file)
      (delete-file test-file))
    (set! *mx-history-file* saved-file)
    (set! *mx-history* saved)))

;;; ========================================================================
;;; Which-key settings
;;; ========================================================================

(display "--- which-key ---\n")

(check-true (which-key-mode))
(check (which-key-delay) => 0.5)
(which-key-mode-set! #f)
(check-false (which-key-mode))
(which-key-mode-set! #t)

;;; ========================================================================
;;; Scroll margin
;;; ========================================================================

(display "--- scroll-margin ---\n")

(check (scroll-margin) => 3)
(scroll-margin-set! 5)
(check (scroll-margin) => 5)
(scroll-margin-set! 3)

;;; ========================================================================
;;; Mode toggles
;;; ========================================================================

(display "--- mode-toggles ---\n")

(check-false (centered-cursor-mode))
(centered-cursor-mode-set! #t)
(check-true (centered-cursor-mode))
(centered-cursor-mode-set! #f)

(check-false (auto-fill-mode))
(check (fill-column) => 80)
(check-true (abbrev-mode-enabled))
(check-false (enriched-mode))
(check-false (picture-mode))
(check-false (electric-pair-mode))
(check-false (copilot-mode))
(check (copilot-model) => "gpt-4o-mini")

;;; ========================================================================
;;; Init file path
;;; ========================================================================

(display "--- init-file ---\n")

(check-true (string? *init-file-path*))
(check-true (string-contains *init-file-path* "init"))

;;; ========================================================================
;;; Clean-on-save settings
;;; ========================================================================

(display "--- clean-on-save ---\n")

(check-true (boolean? *delete-trailing-whitespace-on-save*))
(check-true (boolean? *require-final-newline*))
(check-true (boolean? *centered-cursor-mode*))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "persist Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
