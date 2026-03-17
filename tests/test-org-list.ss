#!chezscheme
;;; test-org-list.ss — Tests for org-list module
;;; Ported from gerbil-emacs/org-list-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-list))

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

;; Adapter: org-list-item? returns (values type indent marker),
;; but tests only check the type (first value).
(define (list-item-type? line)
  (let-values (((type indent marker) (org-list-item? line)))
    type))

;;; ========================================================================
;;; List item detection
;;; ========================================================================

(display "--- list-item-detection ---\n")

(check-true (list-item-type? "- item"))
(check-true (list-item-type? "+ item"))
(check-true (list-item-type? "  * sub item"))    ; star at indent > 0
(check-true (list-item-type? "  + sub item"))
(check-true (list-item-type? "1. First item"))
(check-true (list-item-type? "1) First item"))
(check-true (list-item-type? "10. Tenth item"))
(check-true (list-item-type? "- [ ] Todo item"))
(check-true (list-item-type? "- [X] Done item"))
(check-true (list-item-type? "- [-] Partial item"))
(check (list-item-type? "Not a list") => #f)
(check (list-item-type? "* Heading") => #f)
(check (list-item-type? "") => #f)
(check (list-item-type? "   just text") => #f)
(check-true (list-item-type? "- term :: definition"))

;;; ========================================================================
;;; Leading spaces counting
;;; ========================================================================

(display "--- leading-spaces ---\n")

(check (org-count-leading-spaces "hello") => 0)
(check (org-count-leading-spaces "  hello") => 2)
(check (org-count-leading-spaces "    hello") => 4)
(check (org-count-leading-spaces "") => 0)
(check (org-count-leading-spaces "   ") => 3)

;;; ========================================================================
;;; Bullet types
;;; ========================================================================

(display "--- bullet-types ---\n")

(check-true (list-item-type? "- item"))
(check-true (list-item-type? "+ item"))
(check-true (list-item-type? "1. item"))
(check-true (list-item-type? "1) item"))

(check-true (list-item-type? "    - deep item"))
(check-true (list-item-type? "      + deeper item"))
(check-true (list-item-type? "        1. very deep"))

;;; ========================================================================
;;; Complex nested structures
;;; ========================================================================

(display "--- nested-structures ---\n")

(let ((items '("- item A"
               "  - sub item 1"
               "    - sub sub item"
               "  - sub item 2"
               "- item B")))
  (for-each
    (lambda (line)
      (check-true (list-item-type? line)))
    items))

(let ((non-items '("  Some continuation text"
                   ""
                   "Paragraph text")))
  (for-each
    (lambda (line)
      (check (list-item-type? line) => #f))
    non-items))

;;; ========================================================================
;;; Checkbox state variants
;;; ========================================================================

(display "--- checkbox-states ---\n")

(check-true (list-item-type? "- [ ] unchecked"))
(check-true (list-item-type? "- [X] checked"))
(check-true (list-item-type? "- [-] partial"))
(check-true (list-item-type? "1. [ ] ordered unchecked"))
(check-true (list-item-type? "1. [X] ordered checked"))
(check-true (list-item-type? "  - [ ] indented checkbox"))
(check-true (list-item-type? "    + [X] deep checkbox"))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-list Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
