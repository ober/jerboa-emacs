#!chezscheme
;;; test-org-parse.ss — Tests for org-parse module
;;; Ported from gerbil-emacs/org-parse-test.ss

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

(define-syntax check-false
  (syntax-rules ()
    ((_ expr)
     (check (not expr) => #t))))

;; Adapter: build timestamps for elapsed testing
(define (make-ts-for-elapsed h m)
  (make-org-timestamp 'active 2024 1 1 #f h m #f #f #f #f))

;; Adapter: org-parse-properties takes (lines start-idx), convert hash→alist
(define (org-parse-properties-alist lines)
  (hash->list (org-parse-properties lines 0)))

;; Adapter: org-parse-heading-line returns values; wrap into heading struct
(define (parse-heading-adapter line)
  (let-values (((level keyword priority title tags)
                (org-parse-heading-line line)))
    (if (not level)
      #f
      (make-org-heading level keyword
                        (and priority (string (char-upcase priority)))
                        title tags
                        #f #f #f #f '() 0 #f))))

;; Adapter: org-heading-stars-of-line returns 0 for non-headings; return #f
(define (heading-stars line)
  (let ((n (org-heading-stars-of-line line)))
    (if (= n 0) #f n)))

;; Adapter: org-parse-clock-line returns (values start end dur); just return start
(define (parse-clock-line-start line)
  (let-values (((start end dur) (org-parse-clock-line line)))
    start))

;;; ========================================================================
;;; Timestamp parsing
;;; ========================================================================

(display "--- timestamp-parsing ---\n")

(let ((ts (org-parse-timestamp "<2024-01-15>")))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-type ts) => 'active)
  (check (org-timestamp-year ts) => 2024)
  (check (org-timestamp-month ts) => 1)
  (check (org-timestamp-day ts) => 15))

(let ((ts (org-parse-timestamp "<2024-01-15 Mon 10:30>")))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-type ts) => 'active)
  (check (org-timestamp-year ts) => 2024)
  (check (org-timestamp-month ts) => 1)
  (check (org-timestamp-day ts) => 15)
  (check (org-timestamp-day-name ts) => "Mon")
  (check (org-timestamp-hour ts) => 10)
  (check (org-timestamp-minute ts) => 30))

(let ((ts (org-parse-timestamp "[2024-03-20 Wed 14:00]")))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-type ts) => 'inactive)
  (check (org-timestamp-year ts) => 2024)
  (check (org-timestamp-month ts) => 3)
  (check (org-timestamp-day ts) => 20)
  (check (org-timestamp-day-name ts) => "Wed")
  (check (org-timestamp-hour ts) => 14)
  (check (org-timestamp-minute ts) => 0))

(let ((ts (org-parse-timestamp "<2024-01-15 Mon 10:00-11:30>")))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-hour ts) => 10)
  (check (org-timestamp-minute ts) => 0)
  (check (org-timestamp-end-hour ts) => 11)
  (check (org-timestamp-end-minute ts) => 30))

(let ((ts (org-parse-timestamp "<2024-01-15 Mon 10:00 +1w>")))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-repeater ts) => "+1w"))

(let ((ts (org-parse-timestamp "<2024-01-15 Mon 10:00 -3d>")))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-warning ts) => "-3d"))

(check (org-parse-timestamp "not a timestamp") => #f)
(check (org-parse-timestamp "") => #f)

(let ((ts (org-parse-timestamp "[2024-06-15]")))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-type ts) => 'inactive)
  (check (org-timestamp-year ts) => 2024)
  (check (org-timestamp-month ts) => 6)
  (check (org-timestamp-day ts) => 15))

(let ((ts (org-parse-timestamp "<2024-01-15 Mon 10:00 +1w -3d>")))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-repeater ts) => "+1w")
  (check (org-timestamp-warning ts) => "-3d"))

;; Various repeater types
(let ((ts1 (org-parse-timestamp "<2024-01-15 +2y>")))
  (check (org-timestamp-repeater ts1) => "+2y"))
(let ((ts2 (org-parse-timestamp "<2024-01-15 +3m>")))
  (check (org-timestamp-repeater ts2) => "+3m"))
(let ((ts3 (org-parse-timestamp "<2024-01-15 ++1d>")))
  (check (org-timestamp-repeater ts3) => "++1d"))
(let ((ts4 (org-parse-timestamp "<2024-01-15 .+2w>")))
  (check (org-timestamp-repeater ts4) => ".+2w"))

;;; ========================================================================
;;; Timestamp round-trip
;;; ========================================================================

(display "--- timestamp-roundtrip ---\n")

(let* ((input "<2024-01-15 Mon 10:30>")
       (ts (org-parse-timestamp input))
       (output (org-timestamp->string ts)))
  (check-true (string-contains output "2024-01-15"))
  (check-true (string-contains output "10:30")))

(let* ((input "[2024-03-20 Wed 14:00]")
       (ts (org-parse-timestamp input))
       (output (org-timestamp->string ts)))
  (check-true (string-contains output "2024-03-20"))
  (check-true (string-contains output "14:00")))

;;; ========================================================================
;;; Timestamp elapsed
;;; ========================================================================

(display "--- timestamp-elapsed ---\n")

(check (org-timestamp-elapsed (make-ts-for-elapsed 10 0)
                              (make-ts-for-elapsed 11 30)) => "1:30")
(check (org-timestamp-elapsed (make-ts-for-elapsed 10 0)
                              (make-ts-for-elapsed 10 0)) => "0:00")
(check (org-timestamp-elapsed (make-ts-for-elapsed 9 0)
                              (make-ts-for-elapsed 17 45)) => "8:45")
(check (org-timestamp-elapsed (make-ts-for-elapsed 11 30)
                              (make-ts-for-elapsed 13 15)) => "1:45")

;;; ========================================================================
;;; Heading parsing
;;; ========================================================================

(display "--- heading-parsing ---\n")

(let ((h (parse-heading-adapter "** TODO [#A] My Task :work:urgent:")))
  (check-true h)
  (check (org-heading-stars h) => 2)
  (check (org-heading-keyword h) => "TODO")
  (check (org-heading-priority h) => "A")
  (check (org-heading-title h) => "My Task")
  (check (org-heading-tags h) => '("work" "urgent")))

(let ((h (parse-heading-adapter "* Hello")))
  (check-true h)
  (check (org-heading-stars h) => 1)
  (check (org-heading-keyword h) => #f)
  (check (org-heading-title h) => "Hello"))

(let ((h (parse-heading-adapter "*** Just a title")))
  (check-true h)
  (check (org-heading-stars h) => 3)
  (check (org-heading-keyword h) => #f)
  (check (org-heading-title h) => "Just a title")
  (check (org-heading-tags h) => '()))

(let ((h (parse-heading-adapter "* DONE Finished")))
  (check-true h)
  (check (org-heading-keyword h) => "DONE")
  (check (org-heading-title h) => "Finished"))

(check (parse-heading-adapter "Not a heading") => #f)
(check (parse-heading-adapter "  * indented star") => #f)
(check (parse-heading-adapter "") => #f)

(let ((h (parse-heading-adapter "***** Deep heading")))
  (check (org-heading-stars h) => 5)
  (check (org-heading-title h) => "Deep heading"))

(let ((h (parse-heading-adapter "* [#B] Just priority")))
  (check (org-heading-priority h) => "B")
  (check (org-heading-title h) => "Just priority"))

(let ((h (parse-heading-adapter "* Task :a:b:c:d:")))
  (check (org-heading-tags h) => '("a" "b" "c" "d")))

(let ((h (parse-heading-adapter "* Task :my_tag:another_one:")))
  (check (org-heading-tags h) => '("my_tag" "another_one")))

;;; ========================================================================
;;; Planning line parsing
;;; ========================================================================

(display "--- planning-parsing ---\n")

(let-values (((sched dead closed)
              (org-parse-planning-line "SCHEDULED: <2024-01-15 Mon 10:00>")))
  (check-true sched)
  (check dead => #f)
  (check closed => #f))

(let-values (((sched dead closed)
              (org-parse-planning-line "DEADLINE: <2024-02-28>")))
  (check sched => #f)
  (check-true dead))

(let-values (((sched dead closed)
              (org-parse-planning-line
               "SCHEDULED: <2024-01-15 Mon 10:00> DEADLINE: <2024-02-28>")))
  (check-true sched)
  (check-true dead))

(let-values (((sched dead closed)
              (org-parse-planning-line "CLOSED: [2024-01-15 Mon 10:00]")))
  (check-true closed))

(let-values (((sched dead closed)
              (org-parse-planning-line "Just some text")))
  (check sched => #f)
  (check dead => #f)
  (check closed => #f))

;;; ========================================================================
;;; Properties parsing
;;; ========================================================================

(display "--- properties-parsing ---\n")

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:"
                ":ID: abc123"
                ":CATEGORY: work"
                ":END:"))))
  (check-true props)
  (check (assoc "ID" props) => '("ID" . "abc123"))
  (check (assoc "CATEGORY" props) => '("CATEGORY" . "work")))

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:" ":END:"))))
  (check (null? props) => #t))

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:"
                ":CREATED: [2024-01-15]"
                ":AUTHOR: Alice"
                ":STATUS: active"
                ":END:"))))
  (check (length props) => 3)
  (check (assoc "CREATED" props) => '("CREATED" . "[2024-01-15]"))
  (check (assoc "AUTHOR" props) => '("AUTHOR" . "Alice"))
  (check (assoc "STATUS" props) => '("STATUS" . "active")))

;;; ========================================================================
;;; Clock line parsing
;;; ========================================================================

(display "--- clock-parsing ---\n")

(let ((c (parse-clock-line-start
          "CLOCK: [2024-01-15 Mon 10:00]--[2024-01-15 Mon 11:30] =>  1:30")))
  (check-true c))

(let ((c (parse-clock-line-start "CLOCK: [2024-01-15 Mon 10:00]")))
  (check-true c))

(check (parse-clock-line-start "not a clock") => #f)
(check (parse-clock-line-start "") => #f)

;;; ========================================================================
;;; Buffer parsing
;;; ========================================================================

(display "--- buffer-parsing ---\n")

(let* ((text "* Heading One\nSome content\n** Sub heading\nMore content\n* Heading Two\n")
       (result (org-parse-buffer text)))
  (check-true (not (null? result)))
  (check-true (>= (length result) 2)))

(let* ((text "* TODO Task\nSCHEDULED: <2024-01-15 Mon 10:00>\nBody text\n")
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let ((result (org-parse-buffer "")))
  (check (null? result) => #t))

(let ((result (org-parse-buffer "Just some plain text\nwithout headings\n")))
  (check (null? result) => #t))

(let* ((text (string-append
              "* Level 1\n"
              "** Level 2\n"
              "*** Level 3\n"
              "** Another Level 2\n"
              "* Another Level 1\n"))
       (result (org-parse-buffer text)))
  (check-true (>= (length result) 2)))

;;; ========================================================================
;;; Buffer settings
;;; ========================================================================

(display "--- buffer-settings ---\n")

(let* ((text "#+TITLE: My Document\n#+AUTHOR: Alice\n#+STARTUP: overview\n")
       (settings (org-parse-buffer-settings text)))
  (check-true settings))

(let* ((text "#+TODO: TODO NEXT | DONE CANCELLED\n")
       (settings (org-parse-buffer-settings text)))
  (check-true settings))

;;; ========================================================================
;;; Tag expression parsing
;;; ========================================================================

(display "--- tag-expr ---\n")

(check-true (not (null? (org-parse-tag-expr "+work-personal"))))
(check-true (not (null? (org-parse-tag-expr "work"))))
(check-true (not (null? (org-parse-tag-expr "+work+urgent"))))
(check-true (not (null? (org-parse-tag-expr "-personal-home"))))

;;; ========================================================================
;;; Line type utilities
;;; ========================================================================

(display "--- line-type-utils ---\n")

(check-true (heading-stars "* Heading"))
(check-true (heading-stars "** Sub"))
(check-true (heading-stars "*** Deep"))
(check (heading-stars "Not a heading") => #f)
(check (heading-stars " * indented") => #f)
(check (heading-stars "") => #f)

(check (org-table-line? "| a | b | c |") => #t)
(check (org-table-line? "|---+---+---|") => #t)
(check (org-table-line? "not a table") => #f)
(check (org-table-line? "") => #f)

(check (org-comment-line? "# this is a comment") => #t)
(check (org-comment-line? "#+TITLE: not a comment") => #f)
(check (org-comment-line? "normal text") => #f)

(check (org-keyword-line? "#+TITLE: My Title") => #t)
(check (org-keyword-line? "#+AUTHOR: Someone") => #t)
(check (org-keyword-line? "#+BEGIN_SRC python") => #t)
(check (org-keyword-line? "normal text") => #f)
(check (org-keyword-line? "") => #f)

(check (org-block-begin? "#+BEGIN_SRC python") => #t)
(check (org-block-begin? "#+begin_quote") => #t)
(check (org-block-begin? "#+BEGIN_EXAMPLE") => #t)
(check (org-block-begin? "#+END_SRC") => #f)
(check (org-block-begin? "normal text") => #f)

;;; ========================================================================
;;; Utility helpers
;;; ========================================================================

(display "--- utility-helpers ---\n")

(check (pad-02 0) => "00")
(check (pad-02 5) => "05")
(check (pad-02 9) => "09")
(check (pad-02 10) => "10")
(check (pad-02 23) => "23")

(let ((ts (org-current-timestamp-string)))
  (check-true (string? ts))
  (check-true (string-prefix? "<" ts))
  (check-true (string-suffix? ">" ts))
  (check-true (>= (string-length ts) 12)))

(check-true (string-prefix-ci? "#+BEGIN" "#+begin_src foo"))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-parse Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
