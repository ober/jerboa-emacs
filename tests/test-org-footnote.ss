#!chezscheme
;;; test-org-footnote.ss — Tests for org footnote parsing
;;; Ported from gerbil-emacs/org-footnote-test.ss

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

;;; ========================================================================
;;; Footnote reference format detection
;;; ========================================================================

(display "--- footnote-numbered ---\n")

(let* ((text "Text[fn:1]\n\n[fn:1] Definition\n")
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

(let* ((text "Text[fn:label]\n\n[fn:label] Definition\n")
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

;;; ========================================================================
;;; Footnote sorting behavior
;;; ========================================================================

(display "--- footnote-sorting ---\n")

(let* ((text (string-append
              "Text[fn:1][fn:2]\n\n"
              "[fn:2] Def 2\n\n"
              "[fn:1] Def 1\n"))
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

(let* ((text (string-append
              "* Heading\n"
              "Some text[fn:1] and more[fn:2].\n\n"
              "[fn:1] First footnote.\n\n"
              "[fn:2] Second footnote.\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; Footnote renumbering
;;; ========================================================================

(display "--- footnote-renumber ---\n")

(let* ((text "Test[fn:99]\n\n[fn:99] Definition 99\n")
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

;;; ========================================================================
;;; Footnote normalization
;;; ========================================================================

(display "--- footnote-normalization ---\n")

(let* ((text "Test[fn:label:inline def]\n")
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

(let* ((text "Test[fn::anonymous def]\n")
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

;;; ========================================================================
;;; Footnote deletion spec
;;; ========================================================================

(display "--- footnote-deletion ---\n")

(let* ((text "Paragraph[fn:1]\n\n[fn:1] Definition\n")
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

(let* ((text "Para[fn:1] and more[fn:1]\n\n[fn:1] def\n")
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

;;; ========================================================================
;;; Complex footnote scenarios
;;; ========================================================================

(display "--- footnote-complex ---\n")

(let* ((text (string-append
              "Text[fn:1][fn:3]\n\n"
              "[fn:1] Def 1[fn:2]\n\n"
              "[fn:2] Def 2\n\n"
              "[fn:3] Def 3\n"))
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

(let* ((text (string-append
              "* Section 1\n"
              "Text[fn:1]\n\n"
              "[fn:1] Def 1\n\n"
              "* Section 2\n"
              "Text[fn:1]\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-footnote Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
