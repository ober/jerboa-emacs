#!chezscheme
;;; test-org-export.ss — Tests for org-export module
;;; Ported from gerbil-emacs/org-export-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-export)
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
;;; HTML escaping
;;; ========================================================================

(display "--- html-escape ---\n")

(check (html-escape "<script>") => "&lt;script&gt;")
(check (html-escape "a & b") => "a &amp; b")
(check (html-escape "say \"hello\"") => "say &quot;hello&quot;")
(check (html-escape "plain text") => "plain text")
(check (html-escape "") => "")
(check-true (string-contains
             (html-escape "<a href=\"url\">link & text</a>")
             "&lt;"))

;;; ========================================================================
;;; Inline markup conversion
;;; ========================================================================

(display "--- inline-markup ---\n")

(let ((result (org-export-inline " *bold* " 'html)))
  (check-true (string-contains result "<b>bold</b>")))

(let ((result (org-export-inline " /italic/ " 'html)))
  (check-true (string-contains result "<i>italic</i>")))

(let ((result (org-export-inline " ~code~ " 'html)))
  (check-true (string-contains result "<code>code</code>")))

(let ((result (org-export-inline " _underline_ " 'html)))
  (check-true (string-contains result "<u>underline</u>")))

(let ((result (org-export-inline " +strike+ " 'html)))
  (check-true (string-contains result "<del>strike</del>")))

(let ((result (org-export-inline " =verbatim= " 'html)))
  (check-true (string-contains result "verbatim")))

(let ((result (org-export-inline "use ~code~ here" 'markdown)))
  (check-true (string-contains result "`code`")))

(let ((result (org-export-inline " *bold* " 'markdown)))
  (check-true (string-contains result "**bold**")))

(let ((result (org-export-inline " /italic/ " 'markdown)))
  (check-true (string-contains result "*italic*")))

(let ((result (org-export-inline " *bold* " 'latex)))
  (check-true (string-contains result "\\textbf{bold}")))

(let ((result (org-export-inline " /italic/ " 'latex)))
  (check-true (string-contains result "\\textit{italic}")))

(let ((result (org-export-inline "plain text" 'text)))
  (check-true (string-contains result "plain text")))

;;; ========================================================================
;;; Block splitting
;;; ========================================================================

(display "--- block-splitting ---\n")

(let* ((text "* Heading\nParagraph text\n\n* Another heading\n")
       (blocks (org-split-into-blocks text)))
  (check-true (not (null? blocks)))
  (check-true (>= (length blocks) 2)))

(let* ((text (string-append
              "* Heading\n"
              "#+BEGIN_SRC python\n"
              "print('hello')\n"
              "#+END_SRC\n"))
       (blocks (org-split-into-blocks text)))
  (check-true (not (null? blocks))))

(let* ((text (string-append
              "* Heading\n"
              "#+BEGIN_QUOTE\n"
              "A famous quote\n"
              "#+END_QUOTE\n"))
       (blocks (org-split-into-blocks text)))
  (check-true (not (null? blocks))))

(let* ((text (string-append
              "* Heading\n"
              "| a | b |\n"
              "| 1 | 2 |\n"))
       (blocks (org-split-into-blocks text)))
  (check-true (not (null? blocks))))

;; Empty input: org-split-into-blocks may return '() or a list with empty/blank blocks
(check-true (list? (org-split-into-blocks "")))

;;; ========================================================================
;;; Full buffer export: HTML
;;; ========================================================================

(display "--- html-export ---\n")

(let ((result (org-export-buffer "* Hello\nWorld\n" 'html)))
  (check-true (string-contains result "<!DOCTYPE")))

(let ((result (org-export-buffer "* Hello\nWorld\n" 'html)))
  (check-true (string-contains result "<h1"))
  (check-true (string-contains result "Hello")))

(let ((result (org-export-buffer "* Hello\nWorld\n" 'html)))
  (check-true (string-contains result "World")))

(let ((result (org-export-buffer "* Hello\nSome *bold text* here\n" 'html)))
  (check-true (string-contains result "<b>")))

(let ((result (org-export-buffer "| a | b |\n| 1 | 2 |\n" 'html)))
  (check-true (string-contains result "<table")))

;;; ========================================================================
;;; Full buffer export: Markdown
;;; ========================================================================

(display "--- markdown-export ---\n")

(let ((result (org-export-buffer "* Hello\nWorld\n" 'markdown)))
  (check-true (string-contains result "# Hello")))

(let ((result (org-export-buffer "* H1\n** H2\n*** H3\n" 'markdown)))
  (check-true (string-contains result "# H1"))
  (check-true (string-contains result "## H2"))
  (check-true (string-contains result "### H3")))

(let ((result (org-export-buffer "Some *bold* and /italic/ text\n" 'markdown)))
  (check-true (string-contains result "**bold**"))
  (check-true (string-contains result "*italic*")))

(let ((result (org-export-buffer "Use ~code~ here\n" 'markdown)))
  (check-true (string-contains result "`code`")))

;;; ========================================================================
;;; Full buffer export: LaTeX
;;; ========================================================================

(display "--- latex-export ---\n")

(let ((result (org-export-buffer "* Hello\nWorld\n" 'latex)))
  (check-true (string-contains result "\\documentclass")))

(let ((result (org-export-buffer "* Hello\nWorld\n" 'latex)))
  (check-true (string-contains result "\\section")))

(let ((result (org-export-buffer "* H1\n** H2\n" 'latex)))
  (check-true (string-contains result "\\subsection")))

;;; ========================================================================
;;; Full buffer export: plain text
;;; ========================================================================

(display "--- text-export ---\n")

(let ((result (org-export-buffer "* Hello\nWorld\n" 'text)))
  (check-true (string-contains result "Hello"))
  (check-true (string-contains result "World")))

(let ((result (org-export-buffer "Some text\nMore text\n" 'text)))
  (check-true (string-contains result "Some text"))
  (check-true (string-contains result "More text")))

;;; ========================================================================
;;; Edge cases
;;; ========================================================================

(display "--- export-edge-cases ---\n")

(let ((result (org-export-buffer "" 'html)))
  (check-true (string? result)))

(let ((result (org-export-buffer "  \n\n  \n" 'html)))
  (check-true (string? result)))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-export Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
