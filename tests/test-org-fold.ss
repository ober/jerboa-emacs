#!chezscheme
;;; test-org-fold.ss — Tests for org-mode folding/visibility
;;; Ported from gerbil-emacs/org-fold-test.ss

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
;;; Heading structure for folding
;;; ========================================================================

(display "--- fold-overview ---\n")

(let* ((text (string-append
              "* Heading 1\n"
              "Body 1\n"
              "** Sub heading\n"
              "Sub body\n"
              "* Heading 2\n"
              "Body 2\n"))
       (headings (org-parse-buffer text)))
  (check-true (not (null? headings)))
  (let ((h1 (parse-heading-adapter "* Heading 1")))
    (check (org-heading-stars h1) => 1)))

(display "--- fold-contents ---\n")

(let* ((text (string-append
              "* H1\n"
              "** H1.1\n"
              "*** H1.1.1\n"
              "** H1.2\n"
              "* H2\n"
              "** H2.1\n"))
       (headings (org-parse-buffer text)))
  (check-true (not (null? headings))))

;;; ========================================================================
;;; Drawer folding
;;; ========================================================================

(display "--- fold-drawers ---\n")

(let* ((text (string-append
              "* Heading\n"
              ":PROPERTIES:\n"
              ":ID: abc\n"
              ":CATEGORY: work\n"
              ":END:\n"
              "Content\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "* Task\n"
              ":LOGBOOK:\n"
              "CLOCK: [2024-01-15 Mon 10:00]--[2024-01-15 Mon 11:00] => 1:00\n"
              ":END:\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; Block folding
;;; ========================================================================

(display "--- fold-blocks ---\n")

(let* ((text (string-append
              "* Heading\n"
              "#+BEGIN_SRC python\n"
              "def foo():\n"
              "    return 42\n"
              "#+END_SRC\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "* Heading\n"
              "#+BEGIN_EXAMPLE\n"
              "This is an example\n"
              "with multiple lines\n"
              "#+END_EXAMPLE\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "#+BEGIN_QUOTE\n"
              "A famous quote\n"
              "by someone important\n"
              "#+END_QUOTE\n"))
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

;;; ========================================================================
;;; Subtree cycling
;;; ========================================================================

(display "--- fold-subtree-cycling ---\n")

(let* ((text (string-append
              "* Parent\n"
              "Parent body\n"
              "** Child 1\n"
              "Child 1 body\n"
              "*** Grandchild\n"
              "Grandchild body\n"
              "** Child 2\n"
              "Child 2 body\n"))
       (headings (org-parse-buffer text)))
  (check-true (not (null? headings))))

;;; ========================================================================
;;; Global cycling
;;; ========================================================================

(display "--- fold-global-cycling ---\n")

(let* ((text (string-append
              "* H1\n"
              "Body 1\n"
              "** H1.1\n"
              "Body 1.1\n"
              "* H2\n"
              "Body 2\n"
              "** H2.1\n"
              "Body 2.1\n"
              "** H2.2\n"
              "Body 2.2\n"))
       (headings (org-parse-buffer text)))
  (check (>= (length headings) 2) => #t))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-fold Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
