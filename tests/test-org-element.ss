#!chezscheme
;;; test-org-element.ss — Tests for org element parsing
;;; Ported from gerbil-emacs/org-element-test.ss

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

;; Adapter: org-parse-properties takes (lines start-idx), convert hash→alist
(define (org-parse-properties-alist lines)
  (hash->list (org-parse-properties lines 0)))

;; Adapter: org-parse-heading-line → struct
(define (parse-heading-adapter line)
  (let-values (((level keyword priority title tags)
                (org-parse-heading-line line)))
    (if (not level)
      #f
      (make-org-heading level keyword
                        (and priority (string (char-upcase priority)))
                        title tags
                        #f #f #f #f '() 0 #f))))

;; Adapter: org-heading-stars-of-line returns 0 for non-headings, tests expect #f
(define (heading-stars-adapter line)
  (let ((n (org-heading-stars-of-line line)))
    (if (= n 0) #f n)))

;; Adapter: org-parse-clock-line returns (values start end dur); return just start
(define (parse-clock-line-start line)
  (let-values (((start end dur) (org-parse-clock-line line)))
    start))

;;; ========================================================================
;;; Element type detection — headings
;;; ========================================================================

(display "--- element-heading-levels ---\n")

(let ((h1 (parse-heading-adapter "* Level 1"))
      (h2 (parse-heading-adapter "** Level 2"))
      (h3 (parse-heading-adapter "*** Level 3"))
      (h4 (parse-heading-adapter "**** Level 4")))
  (check (org-heading-stars h1) => 1)
  (check (org-heading-stars h2) => 2)
  (check (org-heading-stars h3) => 3)
  (check (org-heading-stars h4) => 4))

(display "--- element-heading-keywords ---\n")

(let ((todo (parse-heading-adapter "* TODO Task"))
      (done (parse-heading-adapter "* DONE Finished"))
      (none (parse-heading-adapter "* Plain heading")))
  (check (org-heading-keyword todo) => "TODO")
  (check (org-heading-keyword done) => "DONE")
  (check (org-heading-keyword none) => #f))

(display "--- element-heading-priorities ---\n")

(let ((pri-a (parse-heading-adapter "* [#A] High priority"))
      (pri-b (parse-heading-adapter "* [#B] Medium priority"))
      (pri-c (parse-heading-adapter "* [#C] Low priority"))
      (no-pri (parse-heading-adapter "* No priority")))
  (check (org-heading-priority pri-a) => "A")
  (check (org-heading-priority pri-b) => "B")
  (check (org-heading-priority pri-c) => "C")
  (check (org-heading-priority no-pri) => #f))

(display "--- element-heading-tags ---\n")

(let ((tagged (parse-heading-adapter "* Task :work:urgent:"))
      (multi (parse-heading-adapter "* Project :a:b:c:d:e:"))
      (none (parse-heading-adapter "* No tags")))
  (check (org-heading-tags tagged) => '("work" "urgent"))
  (check (length (org-heading-tags multi)) => 5)
  (check (org-heading-tags none) => '()))

(display "--- element-heading-title ---\n")

(let ((h (parse-heading-adapter "** TODO [#A] Complex Title :tag1:tag2:")))
  (check (org-heading-title h) => "Complex Title"))

;;; ========================================================================
;;; Timestamp element parsing
;;; ========================================================================

(display "--- element-timestamp ---\n")

(let ((ts (org-parse-timestamp "<2012-03-29 Thu>")))
  (check (org-timestamp? ts) => #t)
  (check (org-timestamp-type ts) => 'active)
  (check (org-timestamp-year ts) => 2012)
  (check (org-timestamp-month ts) => 3)
  (check (org-timestamp-day ts) => 29))

(let ((ts (org-parse-timestamp "<2012-03-29 Thu 16:40>")))
  (check (org-timestamp? ts) => #t)
  (check (org-timestamp-type ts) => 'active))

(let ((ts (org-parse-timestamp "[2012-03-29 Thu]")))
  (check (org-timestamp? ts) => #t)
  (check (org-timestamp-type ts) => 'inactive))

(let ((ts (org-parse-timestamp "[2012-03-29 Thu 16:40]")))
  (check (org-timestamp? ts) => #t)
  (check (org-timestamp-type ts) => 'inactive))

(let ((ts (org-parse-timestamp "<2012-03-29 Thu>")))
  (check (org-timestamp? ts) => #t))

;;; ========================================================================
;;; Clock element parsing
;;; ========================================================================

(display "--- element-clock ---\n")

(let ((c (parse-clock-line-start "CLOCK: [2012-01-01 Sun 00:01]")))
  (check (not (not c)) => #t))

(let ((c (parse-clock-line-start
          "CLOCK: [2012-01-01 Sun 00:01]--[2012-01-01 Sun 00:02] =>  0:01")))
  (check (not (not c)) => #t))

;;; ========================================================================
;;; Planning element parsing
;;; ========================================================================

(display "--- element-planning ---\n")

(let-values (((sched dead closed)
              (org-parse-planning-line "DEADLINE: <2012-03-29 Thu>")))
  (check (not (not dead)) => #t))

(let-values (((sched dead closed)
              (org-parse-planning-line "SCHEDULED: <2012-03-29 Thu>")))
  (check (not (not sched)) => #t))

(let-values (((sched dead closed)
              (org-parse-planning-line "CLOSED: [2012-03-29 Thu]")))
  (check (not (not closed)) => #t))

(let-values (((sched dead closed)
              (org-parse-planning-line
               "DEADLINE: <2012-03-29 Thu> SCHEDULED: <2012-03-28 Wed>")))
  (check (not (not dead)) => #t)
  (check (not (not sched)) => #t))

;;; ========================================================================
;;; Property drawer parsing
;;; ========================================================================

(display "--- element-property-drawer ---\n")

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:"
                ":PROP: value"
                ":END:"))))
  (check (not (null? props)) => #t)
  (check (assoc "PROP" props) => '("PROP" . "value")))

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:"
                ":A: 1"
                ":B: 2"
                ":C: 3"
                ":END:"))))
  (check (length props) => 3))

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:" ":END:"))))
  (check (null? props) => #t))

;;; ========================================================================
;;; Line type classification
;;; ========================================================================

(display "--- element-line-classification ---\n")

(check (org-comment-line? "# A comment") => #t)
(check (org-comment-line? "#  ") => #t)
(check (org-comment-line? "#+KEYWORD:") => #f)

(check (org-keyword-line? "#+TITLE: Title") => #t)
(check (org-keyword-line? "#+RESULTS:") => #t)
(check (org-keyword-line? "# comment") => #f)

(check (org-block-begin? "#+BEGIN_SRC emacs-lisp") => #t)
(check (org-block-begin? "#+begin_example") => #t)
(check (org-block-begin? "#+begin_quote") => #t)
(check (org-block-begin? "#+begin_verse") => #t)
(check (org-block-begin? "#+begin_center") => #t)
(check (org-block-begin? "#+BEGIN_COMMENT") => #t)
(check (org-block-begin? "#+END_SRC") => #f)

(check (org-table-line? "| cell |") => #t)
(check (org-table-line? "| a | b | c |") => #t)
(check (org-table-line? "text") => #f)

(check-true (not (not (heading-stars-adapter "* H"))))
(check-true (not (not (heading-stars-adapter "** H"))))
(check (heading-stars-adapter "text") => #f)

;;; ========================================================================
;;; Buffer-level parsing
;;; ========================================================================

(display "--- element-buffer-parsing ---\n")

(let ((result (org-parse-buffer "* H1\nParagraph\n* H2\n")))
  (check (>= (length result) 2) => #t))

(let ((result (org-parse-buffer
               (string-append
                "* H1\n"
                "** H1.1\n"
                "** H1.2\n"
                "* H2\n"
                "** H2.1\n"))))
  (check (not (null? result)) => #t))

(let ((result (org-parse-buffer
               (string-append
                "* H1\n"
                ":PROPERTIES:\n"
                ":ID: abc\n"
                ":END:\n"
                "Content\n"))))
  (check (not (null? result)) => #t))

(let ((result (org-parse-buffer
               (string-append
                "* TODO Task\n"
                "SCHEDULED: <2024-01-15>\n"
                "Content\n"))))
  (check (not (null? result)) => #t))

(let ((result (org-parse-buffer
               (string-append
                "* Task\n"
                "CLOCK: [2024-01-15 Mon 10:00]--[2024-01-15 Mon 11:00] => 1:00\n"))))
  (check (not (null? result)) => #t))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-element Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
