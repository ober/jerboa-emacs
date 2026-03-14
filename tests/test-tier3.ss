#!chezscheme
;;; test-tier3.ss — Tests for Tier 3 modules (org extensions)

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1- sort sort!)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs core)
        (jerboa-emacs org-parse)
        (jerboa-emacs org-agenda)
        (jerboa-emacs org-export)
        (jerboa-emacs org-list)
        (jerboa-emacs org-table)
        (jerboa-emacs org-clock)
        (jerboa-emacs org-capture)
        (jerboa-emacs org-babel)
        (jerboa-emacs org-highlight)
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

(define-syntax check-false
  (syntax-rules ()
    ((_ expr)
     (check (not expr) => #t))))

;;; --- Org Export: Inline markup ---
(display "--- org-export-inline ---\n")
(check (org-export-inline "hello" 'text) => "hello")
(check-true (string-contains (org-export-inline "~code~" 'html) "<code>"))
(check-true (string-contains (org-export-inline "~code~" 'markdown) "`"))

;;; --- Org Export: HTML escape ---
(display "--- html-escape ---\n")
(check (html-escape "<b>") => "&lt;b&gt;")
(check (html-escape "a&b") => "a&amp;b")

;;; --- Org Export: Block splitting ---
(display "--- org-split-into-blocks ---\n")
(let ((blocks (org-split-into-blocks "* Heading\nParagraph text\n")))
  (check-true (pair? blocks))
  (check (caar blocks) => 'heading))

;;; --- Org Export: Export options ---
(display "--- org-parse-export-options ---\n")
(let ((opts (org-parse-export-options "#+TITLE: Test\n#+AUTHOR: Me\n")))
  (check (hash-get opts "title") => "Test")
  (check (hash-get opts "author") => "Me"))

;;; --- Org Export: HTML export ---
(display "--- org-export-html ---\n")
(let ((html (org-export-html "#+TITLE: My Doc\n* Hello\nWorld\n")))
  (check-true (string-contains html "<html>"))
  (check-true (string-contains html "My Doc"))
  (check-true (string-contains html "Hello"))
  (check-true (string-contains html "World")))

;;; --- Org Export: Markdown export ---
(display "--- org-export-markdown ---\n")
(let ((md (org-export-markdown "* Heading\nParagraph\n")))
  (check-true (string-contains md "# Heading"))
  (check-true (string-contains md "Paragraph")))

;;; --- Org Export: LaTeX export ---
(display "--- org-export-latex ---\n")
(let ((tex (org-export-latex "#+TITLE: Test\n* Section\nBody\n")))
  (check-true (string-contains tex "\\documentclass"))
  (check-true (string-contains tex "\\section"))
  (check-true (string-contains tex "Body")))

;;; --- Org Export: Text export ---
(display "--- org-export-text ---\n")
(let ((txt (org-export-text "* Heading\nBody\n")))
  (check-true (string-contains txt "Heading"))
  (check-true (string-contains txt "Body")))

;;; --- Org Export: Footnotes ---
(display "--- org-footnotes ---\n")
(let ((fn (org-collect-footnotes "[fn:1] This is a footnote\n")))
  (check-true (hash-table? fn))
  (check (hash-get fn "1") => "This is a footnote"))

;;; --- Org Export: Backend dispatch ---
(display "--- org-export-dispatch ---\n")
(let ((result (org-export-buffer "* Test\n" 'text)))
  (check-true (string-contains result "Test")))

;;; --- Org Export: Backend registry ---
(display "--- org-export-backends ---\n")
(let ((backends (org-export-list-backends)))
  (check-true (memq 'html backends))
  (check-true (memq 'markdown backends))
  (check-true (memq 'latex backends))
  (check-true (memq 'text backends)))

;;; --- Org Export: Table parse row ---
(display "--- org-table-parse-row-simple ---\n")
(check (org-table-parse-row-simple "| a | b | c |") => '("a" "b" "c"))
(check (org-table-parse-row-simple "") => '())

;;; --- Org List: Detection ---
(display "--- org-list-item ---\n")
(let-values (((type indent marker) (org-list-item? "  - item")))
  (check type => 'unordered)
  (check indent => 2)
  (check marker => "-"))
(let-values (((type indent marker) (org-list-item? "  1. item")))
  (check type => 'ordered))
(let-values (((type indent marker) (org-list-item? "not a list")))
  (check type => #f))

;;; --- Org List: Leading spaces ---
(display "--- org-count-leading-spaces ---\n")
(check (org-count-leading-spaces "  hello") => 2)
(check (org-count-leading-spaces "hello") => 0)
(check (org-count-leading-spaces "    ") => 4)

;;; --- Org List: Bullet cycling ---
(display "--- org-bullet-cycling ---\n")
(check (org-next-bullet "-") => "+")
(check (org-next-bullet "+") => "*")
(check (org-next-bullet "*") => "1.")
(check (org-next-bullet "1.") => "1)")
(check (org-next-bullet "1)") => "-")

;;; --- Org Table: Row detection ---
(display "--- org-table-row ---\n")
(check-true (org-table-row? "| a | b |"))
(check-false (org-table-row? "not a table"))
(check-true (org-table-separator? "|---+---|"))
(check-false (org-table-separator? "| a | b |"))

;;; --- Org Table: Parse row ---
(display "--- org-table-parse-row ---\n")
(check (org-table-parse-row "| hello | world |") => '("hello" "world"))
(check (org-table-parse-row "| a |") => '("a"))

;;; --- Org Table: Column widths ---
(display "--- org-table-column-widths ---\n")
(let ((rows '(("a" "bb" "ccc") ("dd" "e" "f"))))
  (check (org-table-column-widths rows) => '(2 2 3)))

;;; --- Org Table: Format row ---
(display "--- org-table-format-row ---\n")
(let ((result (org-table-format-row '("a" "b") '(5 5))))
  (check-true (string-contains result "| a")))

;;; --- Org Table: Format separator ---
(display "--- org-table-format-separator ---\n")
(let ((sep (org-table-format-separator '(3 4))))
  (check-true (string-contains sep "|"))
  (check-true (string-contains sep "-")))

;;; --- Org Table: Numeric detection ---
(display "--- org-numeric-cell ---\n")
(check-true (org-numeric-cell? "42"))
(check-true (org-numeric-cell? "-3.14"))
(check-false (org-numeric-cell? "hello"))
(check-false (org-numeric-cell? ""))

;;; --- Org Table: CSV ---
(display "--- org-csv-to-table ---\n")
(let ((tbl (org-csv-to-table "a,b,c\n1,2,3\n")))
  (check-true (string-contains tbl "|"))
  (check-true (string-contains tbl "a")))

;;; --- Org Table: List helpers ---
(display "--- org-table-helpers ---\n")
(check (swap-list-elements '(a b c) 0 2) => '(c b a))
(check (list-insert '(a b c) 1 'x) => '(a x b c))
(check (list-remove-at '(a b c) 1) => '(a c))

;;; --- Org Clock: Elapsed minutes ---
(display "--- org-clock ---\n")
(let ((ts1 (org-make-date-ts 2024 3 15))
      (ts2 (org-make-date-ts 2024 3 16)))
  (let ((mins (org-elapsed-minutes ts1 ts2)))
    (check-true (> mins 0))
    ;; Should be approximately 1440 minutes (1 day)
    (check-true (= mins 1440))))

;;; --- Org Clock: State ---
(display "--- org-clock-state ---\n")
(check (org-clock-start) => #f)
(check (org-clock-heading) => #f)
(check (org-clock-modeline-string) => #f)

;;; --- Org Capture: Template structure ---
(display "--- org-capture-templates ---\n")
(let ((templates (org-capture-templates)))
  (check-true (pair? templates))
  (check-true (org-capture-template? (car templates))))

;;; --- Org Capture: Template expansion ---
(display "--- org-capture-expand ---\n")
(let ((expanded (org-capture-expand-template "* TODO %?\n  %U\n" "test.txt" "/tmp/test.txt")))
  (check-true (string? expanded))
  ;; %? should be removed
  (check-false (string-contains expanded "%?"))
  ;; %U should be replaced with a timestamp
  (check-false (string-contains expanded "%U")))

;;; --- Org Capture: Cursor position ---
(display "--- org-capture-cursor ---\n")
(check (org-capture-cursor-position "hello %? world") => 6)
(check (org-capture-cursor-position "no marker") => #f)

;;; --- Org Capture: Menu ---
(display "--- org-capture-menu ---\n")
(let ((menu (org-capture-menu-string)))
  (check-true (string? menu))
  (check-true (string-contains menu "[t]")))

;;; --- Org Capture: State ---
(display "--- org-capture-state ---\n")
(check (org-capture-active?) => #f)

;;; --- Org Capture: Insert under heading ---
(display "--- org-insert-under-heading ---\n")
(let ((result (org-insert-under-heading "* Tasks\nold item\n* Other\n" "Tasks" "new item\n")))
  (check-true (string-contains result "new item"))
  (check-true (string-contains result "old item")))

;;; --- Org Capture: Refile targets ---
(display "--- org-refile-targets ---\n")
(let ((targets (org-refile-targets "* First\n* Second\nBody\n* Third\n")))
  (check (length targets) => 3)
  (check (caar targets) => "First"))

;;; --- Org Babel: Language commands ---
(display "--- org-babel-langs ---\n")
(check-true (pair? *org-babel-lang-commands*))

;;; --- Org Babel: Header args ---
(display "--- org-babel-header-args ---\n")
(let ((args (org-babel-parse-header-args ":var x=5 :results output")))
  (check (hash-get args "var") => "x=5")
  (check (hash-get args "results") => "output"))

;;; --- Org Babel: File extension ---
(display "--- org-babel-file-ext ---\n")
(check (org-babel-file-extension "python") => "py")
(check (org-babel-file-extension "bash") => "sh")
(check (org-babel-file-extension "node") => "js")

;;; --- Org Babel: Result formatting ---
(display "--- org-babel-format-result ---\n")
(let ((result (org-babel-format-result "hello\nworld" "output")))
  (check-true (string-contains result ": hello"))
  (check-true (string-contains result ": world")))

;;; --- Org Babel: Tangle ---
(display "--- org-babel-tangle ---\n")
(let ((pairs (org-babel-tangle
               "#+BEGIN_SRC bash :tangle /tmp/test.sh\necho hello\n#+END_SRC\n")))
  (check-true (pair? pairs))
  (check (cdar pairs) => "echo hello"))

;;; --- Org Babel: Noweb ---
(display "--- org-babel-noweb ---\n")
(let ((text "#+NAME: greeting\n#+BEGIN_SRC bash\necho hello\n#+END_SRC\n"))
  (let ((body (org-babel-find-named-block text "greeting")))
    (check body => "echo hello")))

;;; --- Org Babel: Context dispatch ---
(display "--- org-babel-context ---\n")
(check (org-ctrl-c-ctrl-c-context '("* Heading" "| a | b |" "text") 0) => 'heading)
(check (org-ctrl-c-ctrl-c-context '("* Heading" "| a | b |" "text") 1) => 'table)
(check (org-ctrl-c-ctrl-c-context '("* Heading" "| a | b |" "text") 2) => 'none)

;;; --- Org Highlight: Style constants ---
(display "--- org-highlight-styles ---\n")
(check ORG_STYLE_DEFAULT => 32)
(check ORG_STYLE_HEADING_1 => 33)
(check ORG_STYLE_TODO => 41)
(check ORG_STYLE_DONE => 42)

;;; --- Org Highlight: Color helper ---
(display "--- org-rgb ---\n")
(check (org-rgb 255 0 0) => (+ 0 0 (* 65536 255)))
(check (org-rgb 0 255 0) => (* 256 255))
(check (org-rgb 0 0 255) => 255)

;;; --- Org Highlight: Heading style ---
(display "--- heading-style ---\n")
(check (heading-style-for-level 1) => ORG_STYLE_HEADING_1)
(check (heading-style-for-level 8) => ORG_STYLE_HEADING_8)
(check (heading-style-for-level 0) => ORG_STYLE_DEFAULT)
(check (heading-style-for-level 9) => ORG_STYLE_HEADING_8)

;;; Results
(newline)
(display "========================================\n")
(display (string-append "Tier 3 Test Results: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
