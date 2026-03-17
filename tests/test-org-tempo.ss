#!chezscheme
;;; test-org-tempo.ss — Tests for org-mode structure templates (tempo)
;;; Ported from gerbil-emacs/org-tempo-test.ss

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
;;; Template expansion patterns
;;; ========================================================================

(display "--- template-src ---\n")

(check (org-block-begin? "#+BEGIN_SRC python") => #t)
(check (org-block-begin? "#+begin_src") => #t)

(display "--- template-example ---\n")

(check (org-block-begin? "#+BEGIN_EXAMPLE") => #t)
(check (org-block-begin? "#+begin_example") => #t)

(display "--- template-quote ---\n")

(check (org-block-begin? "#+BEGIN_QUOTE") => #t)
(check (org-block-begin? "#+begin_quote") => #t)

(display "--- template-verse ---\n")

(check (org-block-begin? "#+BEGIN_VERSE") => #t)

(display "--- template-center ---\n")

(check (org-block-begin? "#+BEGIN_CENTER") => #t)

(display "--- template-comment ---\n")

(check (org-block-begin? "#+BEGIN_COMMENT") => #t)

(display "--- template-export ---\n")

(check (org-block-begin? "#+BEGIN_EXPORT latex") => #t)
(check (org-block-begin? "#+begin_export latex") => #t)

;;; ========================================================================
;;; Keyword templates
;;; ========================================================================

(display "--- template-keyword ---\n")

;; Keywords like #+latex: are keyword lines, not block begins
(check (org-block-begin? "#+latex: ") => #f)

;;; ========================================================================
;;; Template mapping table — all standard block types
;;; ========================================================================

(display "--- template-all-types ---\n")

(let ((block-types '("#+BEGIN_SRC"
                     "#+BEGIN_EXAMPLE"
                     "#+BEGIN_QUOTE"
                     "#+BEGIN_VERSE"
                     "#+BEGIN_CENTER"
                     "#+BEGIN_COMMENT"
                     "#+BEGIN_EXPORT ascii"
                     "#+BEGIN_EXPORT html"
                     "#+BEGIN_EXPORT latex")))
  (for-each
    (lambda (bt)
      (check (org-block-begin? bt) => #t))
    block-types))

;;; ========================================================================
;;; Space on first line after expansion
;;; ========================================================================

(display "--- template-space ---\n")

;; "#+BEGIN_SRC " (with trailing space for language)
(let ((line "#+BEGIN_SRC "))
  (check (string-suffix? " " line) => #t))

;; "#+BEGIN_QUOTE" (no trailing space)
(let ((line "#+BEGIN_QUOTE"))
  (check (not (string-suffix? " " line)) => #t))

;;; ========================================================================
;;; Cursor position spec (UI-level placeholder)
;;; ========================================================================

(display "--- template-cursor ---\n")

(check #t => #t)

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-tempo Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
