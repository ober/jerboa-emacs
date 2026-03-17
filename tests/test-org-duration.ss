#!chezscheme
;;; test-org-duration.ss — Tests for duration parsing and formatting
;;; Ported from gerbil-emacs/org-duration-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-parse)
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

;; Adapter: org-parse-clock-line returns (values start-ts end-ts dur-string).
;; Return just the start timestamp (truthy if the line parsed).
(define (parse-clock-start line)
  (let-values (((start end dur) (org-parse-clock-line line)))
    start))

;; Adapter: tests call (elapsed h1 m1 h2 m2) with 4 ints.
;; Build two org-timestamp objects and call org-timestamp-elapsed.
;; make-org-timestamp: type year month day day-name hour minute end-hour end-minute repeater warning
(define (elapsed h1 m1 h2 m2)
  (let ((ts1 (make-org-timestamp 'active 2024 1 1 #f h1 m1 #f #f #f #f))
        (ts2 (make-org-timestamp 'active 2024 1 1 #f h2 m2 #f #f #f #f)))
    (org-timestamp-elapsed ts1 ts2)))

;;; ========================================================================
;;; Duration to minutes — h:mm format
;;; ========================================================================

(display "--- duration-h-mm ---\n")

(let ((c (parse-clock-start
          "CLOCK: [2024-01-15 Mon 10:00]--[2024-01-15 Mon 11:01] =>  1:01")))
  (check-true (not (not c))))

;;; ========================================================================
;;; Elapsed time string format
;;; ========================================================================

(display "--- duration-elapsed ---\n")

(check (elapsed 10 0 11 1) => "1:01")
(check (elapsed 10 0 11 0) => "1:00")
(check (elapsed 0 0 0 0) => "0:00")
(check (elapsed 9 0 17 45) => "8:45")

;;; ========================================================================
;;; Valid h:mm patterns
;;; ========================================================================

(display "--- duration-valid-patterns ---\n")

(check (not (not (parse-clock-start
                  "CLOCK: [2024-01-15 Mon 10:00]--[2024-01-15 Mon 13:12] =>  3:12")))
       => #t)
(check (not (not (parse-clock-start
                  "CLOCK: [2024-01-14 Sun 00:00]--[2024-01-19 Fri 03:12] => 123:12")))
       => #t)

;;; ========================================================================
;;; Duration formatting
;;; ========================================================================

(display "--- duration-formatting ---\n")

(check (elapsed 0 0 1 0) => "1:00")
(check (elapsed 0 0 0 30) => "0:30")
(check (elapsed 0 0 2 15) => "2:15")
(check (elapsed 10 0 10 5) => "0:05")

;;; ========================================================================
;;; Zero duration
;;; ========================================================================

(display "--- duration-zero ---\n")

(check (elapsed 12 0 12 0) => "0:00")

;;; ========================================================================
;;; Single digit minutes padded
;;; ========================================================================

(display "--- duration-padding ---\n")

(check (elapsed 10 0 10 5) => "0:05")
(check (elapsed 10 0 10 9) => "0:09")

;;; ========================================================================
;;; Large hour values
;;; ========================================================================

(display "--- duration-large-hours ---\n")

(check (elapsed 0 0 23 59) => "23:59")

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-duration Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
