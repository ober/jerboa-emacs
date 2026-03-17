#!chezscheme
;;; test-org-table.ss — Tests for org-table module
;;; Ported from gerbil-emacs/org-table-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-table)
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

;;; ========================================================================
;;; Table row / separator detection
;;; ========================================================================

(display "--- table-detection ---\n")

(check (org-table-row? "| a | b | c |") => #t)
(check (org-table-row? "| hello | world |") => #t)
(check (org-table-row? "| single |") => #t)
(check (org-table-row? "|  |  |") => #t)
(check (org-table-row? "not a table row") => #f)
(check (org-table-row? "|---+---|") => #t)
(check (org-table-row? "") => #f)
(check (org-table-row? "   | indented") => #t)

(check (org-table-separator? "|---+---|") => #t)
(check (org-table-separator? "|---|") => #t)
(check (org-table-separator? "|-----+------+-------|") => #t)
(check (org-table-separator? "| a | b |") => #f)
(check (org-table-separator? "not a separator") => #f)
(check (org-table-separator? "") => #f)

;;; ========================================================================
;;; Row parsing
;;; ========================================================================

(display "--- row-parsing ---\n")

(check (org-table-parse-row "| a | bb | ccc |") => '("a" "bb" "ccc"))
(check (org-table-parse-row "|  a  |  b  |  c  |") => '("a" "b" "c"))
(check (org-table-parse-row "|  | b |  |") => '("" "b" ""))
(check (org-table-parse-row "| hello |") => '("hello"))
(check (org-table-parse-row "| 1 | 2 | 3 |") => '("1" "2" "3"))

;;; ========================================================================
;;; Column width computation
;;; ========================================================================

(display "--- column-widths ---\n")

(let ((rows '(("a" "bb" "ccc")
              ("dd" "e" "ffff"))))
  (check (org-table-column-widths rows) => '(2 2 4)))

(let ((rows '(("hello" "world"))))
  (check (org-table-column-widths rows) => '(5 5)))

(let ((rows '(("a" "" "c")
              ("" "bb" ""))))
  (check (org-table-column-widths rows) => '(1 2 1)))

;;; ========================================================================
;;; Row / separator formatting
;;; ========================================================================

(display "--- row-formatting ---\n")

(let ((result (org-table-format-row '("a" "bb" "ccc") '(4 2 3))))
  (check-true (string-contains result "| a"))
  (check-true (string-contains result "| bb"))
  (check-true (string-contains result "| ccc")))

(let ((result (org-table-format-separator '(4 2 3))))
  (check-true (string-contains result "|"))
  (check-true (string-contains result "-"))
  (check-true (string-contains result "+")))

;;; ========================================================================
;;; Numeric cell detection
;;; ========================================================================

(display "--- numeric-cell ---\n")

(check (org-numeric-cell? "123") => #t)
(check (org-numeric-cell? "0") => #t)
(check (org-numeric-cell? "-5") => #t)
(check (org-numeric-cell? "3.14") => #t)
(check (org-numeric-cell? "-0.5") => #t)
(check (org-numeric-cell? "50%") => #t)
(check (org-numeric-cell? "100%") => #t)
(check (org-numeric-cell? "hello") => #f)
(check (org-numeric-cell? "") => #f)
(check (org-numeric-cell? "abc123") => #f)

;;; ========================================================================
;;; Formula parsing
;;; ========================================================================

(display "--- formula-parsing ---\n")

(let ((result (org-table-parse-tblfm "#+TBLFM: $3=$1+$2")))
  (check-true (not (null? result))))

(let ((result (org-table-parse-tblfm
               "#+TBLFM: @>$1=vsum(@<..@>>) :: $2=2*$1")))
  (check-true (not (null? result))))

(let ((result (org-table-parse-tblfm "not a formula")))
  (check (null? result) => #t))

;;; ========================================================================
;;; CSV conversion
;;; ========================================================================

(display "--- csv-conversion ---\n")

(let ((result (org-csv-to-table "a,b,c\n1,2,3")))
  (check-true (string-contains result "| a"))
  (check-true (string-contains result "| b"))
  (check-true (string-contains result "| c"))
  (check-true (string-contains result "| 1"))
  (check-true (string-contains result "| 2"))
  (check-true (string-contains result "| 3")))

(let ((result (org-csv-to-table "a\nb\nc")))
  (check-true (string-contains result "| a"))
  (check-true (string-contains result "| b")))

(let ((result (org-csv-to-table "name,age\nAlice,30\nBob,25")))
  (check-true (string-contains result "name"))
  (check-true (string-contains result "Alice")))

;;; ========================================================================
;;; Formula structure tests
;;; ========================================================================

(display "--- formula-structure ---\n")

(let ((parsed (org-table-parse-tblfm "#+TBLFM: @>$1 = vsum(@<..@>>)")))
  (check-true (not (null? parsed))))

(let ((parsed (org-table-parse-tblfm "#+TBLFM: @>$1 = vsum(@I..@>>)")))
  (check-true (not (null? parsed))))

(let ((parsed (org-table-parse-tblfm "#+TBLFM: @>$1 = vsum(@<..@>>) :: $2 = 2 * $1")))
  (check-true (not (null? parsed))))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-table Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
