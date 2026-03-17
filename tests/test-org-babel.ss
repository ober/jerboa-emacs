#!chezscheme
;;; test-org-babel.ss — Tests for org-babel module
;;; Ported from gerbil-emacs/org-babel-test.ss and org-src-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-babel)
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

;; Adapter: tests pass text + 1-based line number, but actual takes lines + 0-based index.
;; org-babel-find-src-block returns (values lang header-args body begin end name).
;; Return lang (truthy if found, #f if not).
(define (org-babel-find-src-block-text text line-num)
  (let-values (((lang header-args body begin-l end-l name)
                (org-babel-find-src-block (split-lines text) (- line-num 1))))
    lang))

(define (org-babel-inside-src-block?-text text line-num)
  (org-babel-inside-src-block? (split-lines text) (- line-num 1)))

;; Adapter: tests pass symbol but actual takes string
(define (org-babel-format-result-sym output type)
  (org-babel-format-result output (symbol->string type)))

;; Adapter: tests pass text + 1-based line number
(define (org-ctrl-c-ctrl-c-context-text text line-num)
  (org-ctrl-c-ctrl-c-context (split-lines text) (- line-num 1)))

;; Adapter: inject-variables tests pass (body lang vars)
(define (org-babel-inject-variables-sym body lang vars)
  (org-babel-inject-variables (symbol->string lang) vars))

;;; ========================================================================
;;; Header argument parsing
;;; ========================================================================

(display "--- header-arg-parsing ---\n")

(let ((args (org-babel-parse-header-args
             ":var x=5 :results output :dir /tmp")))
  (check-true (hash-table? args))
  (check (hash-get args "var") => "x=5")
  (check (hash-get args "results") => "output")
  (check (hash-get args "dir") => "/tmp"))

(let ((args (org-babel-parse-header-args "")))
  (check-true (hash-table? args)))

(let ((args (org-babel-parse-header-args
             ":exports both :results output :tangle yes")))
  (check (hash-get args "exports") => "both")
  (check (hash-get args "tangle") => "yes"))

(let ((args (org-babel-parse-header-args
             ":session *my-session* :results value")))
  (check (hash-get args "session") => "*my-session*"))

;;; ========================================================================
;;; Begin line parsing
;;; ========================================================================

(display "--- begin-line-parsing ---\n")

(let ((result (org-babel-parse-begin-line "#+BEGIN_SRC python :var x=5")))
  (check-true result))

(let ((result (org-babel-parse-begin-line "#+BEGIN_SRC bash")))
  (check-true result))

(let ((result (org-babel-parse-begin-line "#+begin_src python")))
  (check-true result))

(let ((result (org-babel-parse-begin-line
               "#+BEGIN_SRC python :var x=5 :results output :dir /tmp")))
  (check-true result))

(let ((result (org-babel-parse-begin-line "not a begin line")))
  (check result => #f))

;; Various languages
(for-each
  (lambda (lang)
    (let ((result (org-babel-parse-begin-line
                   (string-append "#+BEGIN_SRC " lang))))
      (check-true result)))
  '("python" "bash" "sh" "ruby" "scheme" "sql"))

;;; ========================================================================
;;; Source block detection
;;; ========================================================================

(display "--- src-block-detection ---\n")

(let* ((text (string-append
              "Some text\n"
              "#+BEGIN_SRC python\n"
              "print('hello')\n"
              "#+END_SRC\n"
              "More text\n"))
       (block (org-babel-find-src-block-text text 2)))
  (check-true block))

(let ((text (string-append
             "#+BEGIN_SRC python\n"
             "print('hello')\n"
             "#+END_SRC\n")))
  (check (org-babel-inside-src-block?-text text 2) => #t))

(let ((text (string-append
             "Some text\n"
             "#+BEGIN_SRC python\n"
             "print('hello')\n"
             "#+END_SRC\n"
             "More text\n")))
  (check (org-babel-inside-src-block?-text text 1) => #f)
  (check (org-babel-inside-src-block?-text text 5) => #f))

;;; ========================================================================
;;; Result formatting
;;; ========================================================================

(display "--- result-formatting ---\n")

(let ((result (org-babel-format-result-sym "hello\nworld" 'output)))
  (check-true (string-contains result "hello"))
  (check-true (string-contains result "world")))

(let ((result (org-babel-format-result-sym "42" 'value)))
  (check-true (string-contains result "42")))

(let ((result (org-babel-format-result-sym "" 'output)))
  (check-true (string? result)))

(let ((result (org-babel-format-result-sym "line1\nline2\nline3" 'output)))
  (check-true (string-contains result "line1"))
  (check-true (string-contains result "line3")))

;;; ========================================================================
;;; Named blocks
;;; ========================================================================

(display "--- named-blocks ---\n")

(let* ((text (string-append
              "#+NAME: greet\n"
              "#+BEGIN_SRC python\n"
              "return 'hello'\n"
              "#+END_SRC\n"))
       (block (org-babel-find-named-block text "greet")))
  (check-true block))

(let* ((text (string-append
              "#+NAME: greet\n"
              "#+BEGIN_SRC python\n"
              "return 'hello'\n"
              "#+END_SRC\n"))
       (block (org-babel-find-named-block text "nonexistent")))
  (check block => #f))

;;; ========================================================================
;;; Tangling
;;; ========================================================================

(display "--- tangling ---\n")

(let* ((text (string-append
              "#+BEGIN_SRC bash :tangle /tmp/test.sh\n"
              "echo hello\n"
              "#+END_SRC\n"
              "#+BEGIN_SRC python :tangle /tmp/test.py\n"
              "print('world')\n"
              "#+END_SRC\n"))
       (result (org-babel-tangle text)))
  (check-true (not (null? result))))

(let* ((text (string-append
              "#+BEGIN_SRC bash :tangle no\n"
              "echo skipped\n"
              "#+END_SRC\n"))
       (result (org-babel-tangle text)))
  (check (null? result) => #t))

;;; ========================================================================
;;; Variable injection
;;; ========================================================================

(display "--- variable-injection ---\n")

(let ((result (org-babel-inject-variables-sym
               "echo $x" 'bash '(("x" . "5") ("y" . "hello")))))
  (check-true (string-contains result "x")))

(let ((result (org-babel-inject-variables-sym
               "print(x)" 'python '(("x" . "5")))))
  (check-true (string-contains result "x")))

;;; ========================================================================
;;; Noweb expansion
;;; ========================================================================

(display "--- noweb-expansion ---\n")

(let* ((text (string-append
              "#+NAME: helper\n"
              "#+BEGIN_SRC python\n"
              "def helper():\n"
              "    return 42\n"
              "#+END_SRC\n"
              "\n"
              "#+BEGIN_SRC python :noweb yes\n"
              "<<helper>>\n"
              "print(helper())\n"
              "#+END_SRC\n"))
       (result (org-babel-expand-noweb text "<<helper>>\nprint(helper())\n")))
  (check-true result))

;;; ========================================================================
;;; C-c C-c context detection
;;; ========================================================================

(display "--- ctrl-c-context ---\n")

(let ((ctx (org-ctrl-c-ctrl-c-context-text "* TODO My Task" 1)))
  (check ctx => 'heading))

(let* ((text (string-append
              "#+BEGIN_SRC python\n"
              "print('hello')\n"
              "#+END_SRC\n"))
       (ctx (org-ctrl-c-ctrl-c-context-text text 2)))
  (check ctx => 'src-block))

(let ((ctx (org-ctrl-c-ctrl-c-context-text "| a | b | c |" 1)))
  (check ctx => 'table))

;;; ========================================================================
;;; Source block in buffer context (from org-src-test)
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
  (check-true block))

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
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-babel Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
