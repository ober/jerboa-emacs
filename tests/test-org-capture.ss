#!chezscheme
;;; test-org-capture.ss — Tests for org-capture module
;;; Ported from gerbil-emacs/org-capture-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-capture)
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

;; Adapter: org-capture-expand-template with optional source-file arg
(define (expand-template tmpl . args)
  (if (null? args)
    (org-capture-expand-template tmpl)
    (org-capture-expand-template tmpl (car args))))

;;; ========================================================================
;;; Template expansion
;;; ========================================================================

(display "--- template-expansion ---\n")

(let ((result (expand-template "* TODO %?\n  %U")))
  (check-true (string-contains result "["))
  (check (not (string-contains result "%?")) => #t))

(let ((result (expand-template "Created: %t")))
  (check-true (string-contains result "<"))
  (check-true (string-contains result ">")))

(let ((result (expand-template "Time: %T")))
  (check-true (string-contains result "<")))

(let ((result (expand-template "From: %f" "myfile.org")))
  (check-true (string-contains result "myfile.org")))

(let ((result (expand-template "100%% done")))
  (check-true (string-contains result "100%"))
  (check (not (string-contains result "%%")) => #t))

(let ((result (expand-template "* TODO Task\n  Notes here")))
  (check-true (string-contains result "TODO Task"))
  (check-true (string-contains result "Notes here")))

(let ((result (expand-template "Plain text without placeholders")))
  (check result => "Plain text without placeholders"))

;;; ========================================================================
;;; Cursor position
;;; ========================================================================

(display "--- cursor-position ---\n")

(let ((pos (org-capture-cursor-position "* TODO %?\n  %U")))
  (check (= pos 7) => #t))

(let ((pos (org-capture-cursor-position "%?Rest of template")))
  (check (= pos 0) => #t))

(let ((pos (org-capture-cursor-position "No cursor marker")))
  (check pos => #f))

;;; ========================================================================
;;; Capture menu
;;; ========================================================================

(display "--- capture-menu ---\n")

(let ((saved *org-capture-templates*))
  (set! *org-capture-templates*
        (list (make-org-capture-template "t" "TODO" 'entry '(file "test.org") "* TODO %?\n  %U")
              (make-org-capture-template "n" "Note" 'entry '(file "test.org") "* %?\n  %U")))
  (let ((menu (org-capture-menu-string)))
    (check-true (string-contains menu "[t]"))
    (check-true (string-contains menu "TODO"))
    (check-true (string-contains menu "[n]"))
    (check-true (string-contains menu "Note")))
  (set! *org-capture-templates* saved))

;;; ========================================================================
;;; Refile targets
;;; ========================================================================

(display "--- refile-targets ---\n")

(let* ((text (string-append
              "* Projects\n"
              "** Project A\n"
              "** Project B\n"
              "* Tasks\n"
              "** Daily\n"))
       (targets (org-refile-targets text)))
  (check-true (>= (length targets) 3)))

(let ((targets (org-refile-targets "No headings here\n")))
  (check (null? targets) => #t))

;;; ========================================================================
;;; Insert under heading
;;; ========================================================================

(display "--- insert-under-heading ---\n")

(let* ((text (string-append
              "* Tasks\n"
              "** Existing task\n"
              "* Notes\n"))
       (result (org-insert-under-heading text "Tasks" "** New task\n")))
  (check-true (string-contains result "New task"))
  (check-true (string-contains result "Existing task")))

;;; ========================================================================
;;; Capture lifecycle
;;; ========================================================================

(display "--- capture-lifecycle ---\n")

(let ((saved *org-capture-active?*))
  (set! *org-capture-active?* #f)
  (org-capture-start "t" "" "")
  (check *org-capture-active?* => #t)
  (org-capture-abort)
  (check *org-capture-active?* => #f)
  (set! *org-capture-active?* saved))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-capture Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
