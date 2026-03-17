#!chezscheme
;;; test-org-clock.ss — Tests for org-clock module
;;; Ported from gerbil-emacs/org-clock-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-clock)
        (jerboa-emacs org-parse))

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

;; Adapter: tests call (org-elapsed-minutes h1 m1 h2 m2) with 4 ints,
;; but actual function takes two timestamp objects.
(define (make-ts h m)
  (make-org-timestamp 'active 2024 1 1 #f h m #f #f #f #f))

(define (org-elapsed-minutes-4 h1 m1 h2 m2)
  (org-elapsed-minutes (make-ts h1 m1) (make-ts h2 m2)))

;; Adapter: org-parse-clock-line returns (values start end dur); just check start
(define (parse-clock-start line)
  (let-values (((start end dur) (org-parse-clock-line line)))
    start))

;;; ========================================================================
;;; Elapsed minutes
;;; ========================================================================

(display "--- elapsed-minutes ---\n")

(check (org-elapsed-minutes-4 10 0 11 30) => 90)
(check (org-elapsed-minutes-4 10 0 10 0) => 0)
(check (org-elapsed-minutes-4 10 0 10 1) => 1)
(check (org-elapsed-minutes-4 9 0 10 0) => 60)
(check (org-elapsed-minutes-4 9 0 17 45) => 525)   ; 8h45m = 525
(check (org-elapsed-minutes-4 11 30 13 15) => 105) ; 1h45m = 105
(check (org-elapsed-minutes-4 14 10 14 55) => 45)

;;; ========================================================================
;;; Clock line parsing
;;; ========================================================================

(display "--- clock-line-parsing ---\n")

(let ((c (parse-clock-start
          "CLOCK: [2024-01-15 Mon 10:00]--[2024-01-15 Mon 11:30] =>  1:30")))
  (check-true c))

(let ((c (parse-clock-start "CLOCK: [2024-01-15 Mon 10:00]")))
  (check-true c))

(let ((c (parse-clock-start
          "  CLOCK: [2024-01-15 Mon 10:00]--[2024-01-15 Mon 11:30] =>  1:30")))
  (check-true c))

(let ((c (parse-clock-start
          "CLOCK: [2023-04-29 Sat 00:00]--[2023-05-04 Thu 01:00] => 121:00")))
  (check-true c))

(check (parse-clock-start "Not a clock line") => #f)
(check (parse-clock-start "") => #f)
(check (parse-clock-start "CLOCK: invalid") => #f)

;;; ========================================================================
;;; Modeline string
;;; ========================================================================

(display "--- modeline-string ---\n")

(let ((saved-start *org-clock-start*)
      (saved-heading *org-clock-heading*))
  (set! *org-clock-start* #f)
  (set! *org-clock-heading* #f)
  (check (org-clock-modeline-string) => #f)
  (set! *org-clock-start* saved-start)
  (set! *org-clock-heading* saved-heading))

;;; ========================================================================
;;; Clock format tests
;;; ========================================================================

(display "--- clock-formats ---\n")

(let ((c (parse-clock-start
          "CLOCK: [2023-02-19 Sun 21:30]--[2023-02-19 Sun 23:35] =>  2:05")))
  (check-true c))

(let ((c (parse-clock-start
          "CLOCK: [2023-04-29 Sat 00:00]--[2023-05-04 Thu 01:00] => 121:00")))
  (check-true c))

;; Clock state variable is accessible
(check (or (not *org-clock-start*) (number? *org-clock-start*)
           (string? *org-clock-start*)) => #t)

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-clock Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
