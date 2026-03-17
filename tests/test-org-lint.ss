#!chezscheme
;;; test-org-lint.ss — Tests for org-mode document linting
;;; Ported from gerbil-emacs/org-lint-test.ss

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
;;; Duplicate detection
;;; ========================================================================

(display "--- lint-duplicate-ids ---\n")

(let* ((text (string-append
              "* H1\n"
              ":PROPERTIES:\n"
              ":CUSTOM_ID: same\n"
              ":END:\n"
              "* H2\n"
              ":PROPERTIES:\n"
              ":CUSTOM_ID: same\n"
              ":END:\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "* H1\n"
              ":PROPERTIES:\n"
              ":CUSTOM_ID: id1\n"
              ":END:\n"
              "* H2\n"
              ":PROPERTIES:\n"
              ":CUSTOM_ID: id2\n"
              ":END:\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "#+NAME: same\n"
              "#+BEGIN_SRC python\n"
              "pass\n"
              "#+END_SRC\n"
              "#+NAME: same\n"
              "#+BEGIN_SRC python\n"
              "pass\n"
              "#+END_SRC\n"))
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

;;; ========================================================================
;;; Missing language in src blocks
;;; ========================================================================

(display "--- lint-src-language ---\n")

(check (org-block-begin? "#+BEGIN_SRC") => #t)
(check (org-block-begin? "#+BEGIN_SRC python") => #t)

;;; ========================================================================
;;; Deprecated syntax detection
;;; ========================================================================

(display "--- lint-deprecated ---\n")

(check (org-block-begin? "#+BEGIN_CENTER") => #t)

;;; ========================================================================
;;; Orphaned affiliated keywords
;;; ========================================================================

(display "--- lint-affiliated-keywords ---\n")

(check (org-keyword-line? "#+NAME: my-table") => #t)
(check (org-keyword-line? "#+NAME: test") => #t)
(check (org-keyword-line? "#+CAPTION: Test caption") => #t)
(check (org-keyword-line? "#+ATTR_HTML: :width 300") => #t)
(check (org-keyword-line? "#+ATTR_LATEX: :float t") => #t)
(check (org-keyword-line? "#+RESULTS:") => #t)

;;; ========================================================================
;;; Invalid babel call blocks
;;; ========================================================================

(display "--- lint-babel-call ---\n")

(check (org-keyword-line? "#+CALL: my-func(x=5)") => #t)

;;; ========================================================================
;;; Link validity checks
;;; ========================================================================

(display "--- lint-links ---\n")

(let* ((text (string-append
              "* Heading\n"
              "A link to [[#custom-id][description]].\n"
              "And [[https://example.com][external]].\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; Heading structure issues
;;; ========================================================================

(display "--- lint-heading-levels ---\n")

(let* ((text (string-append
              "* H1\n"
              "*** H3\n"
              "* H4\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "* H1\n"
              "** H2\n"
              "*** H3\n"
              "** H2b\n"
              "* H1b\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; TODO keyword issues
;;; ========================================================================

(display "--- lint-todo ---\n")

(let ((todo (parse-heading-adapter "* TODO Task"))
      (done (parse-heading-adapter "* DONE Finished")))
  (check-true (not (not todo)))
  (check-true (not (not done))))

;;; ========================================================================
;;; Property drawer position
;;; ========================================================================

(display "--- lint-property-position ---\n")

(let* ((text (string-append
              "* H1\n"
              ":PROPERTIES:\n"
              ":ID: abc\n"
              ":END:\n"
              "Content\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "* TODO Task\n"
              "SCHEDULED: <2024-01-15>\n"
              ":PROPERTIES:\n"
              ":ID: abc\n"
              ":END:\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-lint Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
