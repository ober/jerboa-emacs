#!chezscheme
;;; test-org-src.ss — Tests for org-mode source block handling
;;; Ported from gerbil-emacs/org-src-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-parse)
        (jerboa-emacs org-babel)
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

;; Split text on newlines into a list of lines
(define (split-lines text)
  (let loop ([i 0] [start 0] [result '()])
    (cond
      [(= i (string-length text))
       (reverse (if (> i start)
                  (cons (substring text start i) result)
                  result))]
      [(char=? (string-ref text i) #\newline)
       (loop (+ i 1) (+ i 1) (cons (substring text start i) result))]
      [else
       (loop (+ i 1) start result)])))

;; Adapter: tests pass text + 1-based line number.
;; org-babel-find-src-block takes (lines 0-based-idx) and returns
;; (values lang header-args body begin end name).
;; Return truthy if block found (lang is non-#f).
(define (org-babel-find-src-block-text text line-num)
  (let-values (((lang header-args body begin-l end-l name)
                (org-babel-find-src-block (split-lines text) (- line-num 1))))
    lang))

;; Adapter: tests pass text + 1-based line number.
(define (org-babel-inside-src-block?-text text line-num)
  (org-babel-inside-src-block? (split-lines text) (- line-num 1)))

;;; ========================================================================
;;; Source block structure — begin detection
;;; ========================================================================

(display "--- src-block-begin ---\n")

(check (org-block-begin? "#+BEGIN_SRC python") => #t)
(check (org-block-begin? "#+BEGIN_SRC emacs-lisp") => #t)
(check (org-block-begin? "#+BEGIN_SRC bash") => #t)
(check (org-block-begin? "#+BEGIN_SRC sh") => #t)
(check (org-block-begin? "#+BEGIN_SRC ruby") => #t)
(check (org-block-begin? "#+BEGIN_SRC C") => #t)
(check (org-block-begin? "#+begin_src python") => #t)

;;; ========================================================================
;;; Block begin with header args
;;; ========================================================================

(display "--- src-block-header-args ---\n")

(check (org-block-begin? "#+BEGIN_SRC python :results output") => #t)
(check (org-block-begin? "#+BEGIN_SRC bash :var x=5") => #t)
(check (org-block-begin? "#+BEGIN_SRC python :tangle yes :results value") => #t)

;;; ========================================================================
;;; Not a src block
;;; ========================================================================

(display "--- src-not-block ---\n")

(check (org-block-begin? "#+END_SRC") => #f)
(check (org-block-begin? "#+RESULTS:") => #f)
(check (org-block-begin? "plain text") => #f)

;;; ========================================================================
;;; Language identification
;;; ========================================================================

(display "--- src-language ---\n")

(let ((result (org-babel-parse-begin-line "#+BEGIN_SRC python")))
  (check (not (not result)) => #t))

(let ((result (org-babel-parse-begin-line "#+BEGIN_SRC python :results output")))
  (check (not (not result)) => #t))

(for-each
  (lambda (lang)
    (let ((result (org-babel-parse-begin-line
                   (string-append "#+BEGIN_SRC " lang))))
      (check (not (not result)) => #t)))
  '("python" "bash" "sh" "ruby" "emacs-lisp" "C" "java"
    "javascript" "haskell" "scheme" "sql" "R" "perl" "lua"))

;;; ========================================================================
;;; Source block in buffer context
;;; ========================================================================

(display "--- src-in-buffer ---\n")

(let* ((text (string-append
              "* Heading\n"
              "Some text.\n"
              "#+BEGIN_SRC python\n"
              "print('hello')\n"
              "#+END_SRC\n"
              "More text.\n"))
       (block (org-babel-find-src-block-text text 4)))
  (check (not (not block)) => #t))

;;; ========================================================================
;;; Inside/outside detection
;;; ========================================================================

(display "--- src-inside-detection ---\n")

(let ((text (string-append
             "#+BEGIN_SRC python\n"
             "x = 42\n"
             "print(x)\n"
             "#+END_SRC\n")))
  (check (org-babel-inside-src-block?-text text 2) => #t)
  (check (org-babel-inside-src-block?-text text 3) => #t))

(let ((text (string-append
             "Before\n"
             "#+BEGIN_SRC python\n"
             "code\n"
             "#+END_SRC\n"
             "After\n")))
  (check (org-babel-inside-src-block?-text text 1) => #f)
  (check (org-babel-inside-src-block?-text text 5) => #f))

;;; ========================================================================
;;; Multiple source blocks
;;; ========================================================================

(display "--- src-multiple-blocks ---\n")

(let* ((text (string-append
              "#+BEGIN_SRC python\n"
              "print('first')\n"
              "#+END_SRC\n"
              "\n"
              "#+BEGIN_SRC bash\n"
              "echo second\n"
              "#+END_SRC\n"))
       (result (org-parse-buffer text)))
  (check (not (not result)) => #t))

;;; ========================================================================
;;; Indentation handling
;;; ========================================================================

(display "--- src-indentation ---\n")

(let* ((text (string-append
              "  #+BEGIN_SRC python\n"
              "    print('hello')\n"
              "  #+END_SRC\n"))
       (result (org-parse-buffer text)))
  (check (not (not result)) => #t))

(let* ((text (string-append
              "#+BEGIN_SRC python\n"
              "x = 1\n"
              "\n"
              "y = 2\n"
              "#+END_SRC\n"))
       (result (org-parse-buffer text)))
  (check (not (not result)) => #t))

(let* ((text (string-append
              "#+BEGIN_SRC python\n"
              "  \n"
              "#+END_SRC\n"))
       (result (org-parse-buffer text)))
  (check (not (not result)) => #t))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-src Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
