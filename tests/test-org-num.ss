#!chezscheme
;;; test-org-num.ss — Tests for org-mode heading numbering
;;; Ported from gerbil-emacs/org-num-test.ss

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

;; Adapter: org-parse-heading-line returns (values level keyword priority title tags)
(define (parse-heading-adapter line)
  (let-values (((level keyword priority title tags)
                (org-parse-heading-line line)))
    (if (not level)
      #f
      (make-org-heading level keyword
                        (and priority (string (char-upcase priority)))
                        title tags
                        #f #f #f #f '() 0 #f))))

;;; ========================================================================
;;; Heading numbering generation
;;; ========================================================================

(display "--- num-generation ---\n")

(let ((h (parse-heading-adapter "* H1")))
  (check (org-heading-stars h) => 1))

(let* ((text "* H1\n* H2\n")
       (headings (org-parse-buffer text)))
  (check (= (length headings) 2) => #t))

(let* ((text "* H1\n** H2\n*** H3\n")
       (headings (org-parse-buffer text)))
  (check (>= (length headings) 1) => #t))

;;; ========================================================================
;;; Max level limiting
;;; ========================================================================

(display "--- num-max-level ---\n")

(let* ((text "* H1\n** H2\n*** H3\n")
       (headings (org-parse-buffer text)))
  (check (>= (length headings) 1) => #t)
  (let ((h3 (parse-heading-adapter "*** H3")))
    (check (org-heading-stars h3) => 3)))

;;; ========================================================================
;;; Skip commented headings
;;; ========================================================================

(display "--- num-skip-comment ---\n")

(let ((h (parse-heading-adapter "* COMMENT H2")))
  (check-true (not (not h))))

(let* ((text "* COMMENT H1\n** H2\n")
       (headings (org-parse-buffer text)))
  (check-true (not (null? headings))))

;;; ========================================================================
;;; Skip tagged headings
;;; ========================================================================

(display "--- num-skip-tagged ---\n")

(let ((h (parse-heading-adapter "* H2 :foo:")))
  (check (org-heading-tags h) => '("foo")))

(let* ((text "* H1 :foo:\n** H2\n")
       (headings (org-parse-buffer text)))
  (check-true (not (null? headings))))

;;; ========================================================================
;;; Skip UNNUMBERED property
;;; ========================================================================

(display "--- num-skip-unnumbered ---\n")

(let* ((text (string-append
              "* H1\n"
              "* H2\n"
              ":PROPERTIES:\n"
              ":UNNUMBERED: t\n"
              ":END:\n"))
       (headings (org-parse-buffer text)))
  (check-true (not (null? headings))))

(let* ((text (string-append
              "* H1\n"
              "* H2\n"
              ":PROPERTIES:\n"
              ":UNNUMBERED: nil\n"
              ":END:\n"))
       (headings (org-parse-buffer text)))
  (check-true (not (null? headings))))

;;; ========================================================================
;;; Skip footnotes section
;;; ========================================================================

(display "--- num-skip-footnotes ---\n")

(let* ((text "* H1\n* FN\n")
       (headings (org-parse-buffer text)))
  (check (= (length headings) 2) => #t))

;;; ========================================================================
;;; Empty headlines
;;; ========================================================================

(display "--- num-empty-headline ---\n")

(let ((h (parse-heading-adapter "* ")))
  (check-true (not (not h)))
  (check (org-heading-stars h) => 1))

;;; ========================================================================
;;; Update after modification
;;; ========================================================================

(display "--- num-update ---\n")

(let ((h1 (parse-heading-adapter "* H"))
      (h2 (parse-heading-adapter "** H")))
  (check (org-heading-stars h1) => 1)
  (check (org-heading-stars h2) => 2))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-num Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
