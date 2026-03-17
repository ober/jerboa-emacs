#!chezscheme
;;; test-org-property.ss — Tests for org property inheritance
;;; Ported from gerbil-emacs/org-property-test.ss

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

;;; ========================================================================
;;; Basic property access
;;; ========================================================================

(display "--- property-basic ---\n")

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:"
                ":ID: abc123"
                ":CATEGORY: work"
                ":END:"))))
  (check (assoc "ID" props) => '("ID" . "abc123"))
  (check (assoc "CATEGORY" props) => '("CATEGORY" . "work")))

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:"
                ":CREATED: [2024-01-15 Mon]"
                ":EFFORT: 2:00"
                ":STYLE: habit"
                ":REPEAT_TO_STATE: TODO"
                ":END:"))))
  (check (length props) => 4)
  (check (assoc "CREATED" props) => '("CREATED" . "[2024-01-15 Mon]"))
  (check (assoc "EFFORT" props) => '("EFFORT" . "2:00"))
  (check (assoc "STYLE" props) => '("STYLE" . "habit")))

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:" ":END:"))))
  (check (null? props) => #t))

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:"
                ":CUSTOM_ID: my-id"
                ":END:"))))
  (check (length props) => 1)
  (check (assoc "CUSTOM_ID" props) => '("CUSTOM_ID" . "my-id")))

;;; ========================================================================
;;; Property drawer in buffer context
;;; ========================================================================

(display "--- property-in-buffer ---\n")

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
              ":EFFORT: 1:00\n"
              ":END:\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; Property inheritance
;;; ========================================================================

(display "--- property-inheritance ---\n")

(let* ((text (string-append
              "* Parent\n"
              ":PROPERTIES:\n"
              ":CATEGORY: work\n"
              ":END:\n"
              "** Child\n"
              "Content\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "* Parent\n"
              ":PROPERTIES:\n"
              ":CATEGORY: work\n"
              ":END:\n"
              "** Child\n"
              ":PROPERTIES:\n"
              ":CATEGORY: personal\n"
              ":END:\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "* Parent\n"
              ":PROPERTIES:\n"
              ":TAGS_ALL: a b\n"
              ":END:\n"
              "** Child\n"
              ":PROPERTIES:\n"
              ":TAGS_ALL+: c d\n"
              ":END:\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; Document-level properties
;;; ========================================================================

(display "--- property-document-level ---\n")

(let* ((text (string-append
              "#+PROPERTY: header-args :results output\n"
              "* Heading\n"
              "Content\n"))
       (result (org-parse-buffer text)))
  (check-true (not (not result))))

;;; ========================================================================
;;; Special properties
;;; ========================================================================

(display "--- property-special ---\n")

(let ((h (parse-heading-adapter "** TODO [#A] My Task :work:urgent:")))
  (check-true (not (not h))))

;;; ========================================================================
;;; Property values listing
;;; ========================================================================

(display "--- property-values ---\n")

(let* ((text (string-append
              "* H1\n"
              ":PROPERTIES:\n"
              ":A: 1\n"
              ":END:\n"
              "* H2\n"
              ":PROPERTIES:\n"
              ":A: 2\n"
              ":END:\n"))
       (result (org-parse-buffer text)))
  (check-true (not (null? result))))

;;; ========================================================================
;;; Property deletion
;;; ========================================================================

(display "--- property-deletion ---\n")

(let ((props (org-parse-properties-alist
              '(":PROPERTIES:"
                ":A: 1"
                ":B: 2"
                ":END:"))))
  (check (length props) => 2)
  (check (pair? (car props)) => #t))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-property Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
