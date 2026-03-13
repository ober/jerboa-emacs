#!chezscheme
;;; test-tier0.ss — Smoke tests for all Tier 0 modules

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (std sugar)
        (jerboa-emacs macros)
        (jerboa-emacs customize)
        (jerboa-emacs themes)
        (jerboa-emacs pregexp-compat)
        (jerboa-emacs snippets)
        (jerboa-emacs vtscreen)
        (jerboa-emacs org-parse)
        (jerboa-emacs ipc))

(define pass-count 0)
(define fail-count 0)

(define (check name expr expected)
  (let ((result (guard (exn [else (list 'error exn)])
                  expr)))
    (cond
      ((equal? result expected)
       (set! pass-count (+ pass-count 1)))
      (else
       (set! fail-count (+ fail-count 1))
       (display "FAIL: ")
       (display name)
       (display " => ")
       (write result)
       (display " expected ")
       (write expected)
       (newline)))))

(define-syntax check-true
  (syntax-rules ()
    ((_ name expr)
     (let ((result (guard (exn [else #f]) expr)))
       (cond
         (result (set! pass-count (+ pass-count 1)))
         (else
          (set! fail-count (+ fail-count 1))
          (display "FAIL: ")
          (display name)
          (display " => false")
          (newline)))))))

(define-syntax check-no-error
  (syntax-rules ()
    ((_ name expr)
     (guard (exn
              [else
               (set! fail-count (+ fail-count 1))
               (display "FAIL: ")
               (display name)
               (display " => error: ")
               (write exn)
               (newline)])
       expr
       (set! pass-count (+ pass-count 1))))))

;;; ========================================================================
;;; macros.sls
;;; ========================================================================

(display "--- macros ---\n")

;; awhen
(check "awhen-true" (awhen (+ 1 2) it) 3)
(check "awhen-false" (awhen #f 42) (void))

;; aif
(check "aif-true" (aif (+ 10 20) it 0) 30)
(check "aif-false" (aif #f 42 99) 99)

;; while
(check "while" (let ((x 0)) (while (< x 5) (set! x (+ x 1))) x) 5)

;; dotimes
(check "dotimes" (let ((acc 0)) (dotimes (i 4) (set! acc (+ acc i))) acc) 6)

;; when-let
(check "when-let-true" (when-let (x (+ 1 1)) (* x 3)) 6)
(check "when-let-false" (when-let (x #f) 42) (void))

;; if-let
(check "if-let-true" (if-let (x 10) (* x 2) 0) 20)
(check "if-let-false" (if-let (x #f) 42 99) 99)

;;; ========================================================================
;;; customize.sls
;;; ========================================================================

(display "--- customize ---\n")

(check-no-error "defvar!" (defvar! 'test-var 42 "A test variable"))
(check "custom-get" (custom-get 'test-var) 42)
(check "custom-set!" (begin (custom-set! 'test-var 99) (custom-get 'test-var)) 99)
(check "custom-registered?" (custom-registered? 'test-var) #t)
(check "custom-not-registered" (custom-registered? 'nonexistent) #f)

;;; ========================================================================
;;; themes.sls
;;; ========================================================================

(display "--- themes ---\n")

(check-true "theme-names" (pair? (theme-names)))
(check-true "dark-exists" (theme-get 'dark))
(check-true "dracula-exists" (theme-get 'dracula))
(check "theme-is-alist" (pair? (theme-get 'dark)) #t)

;;; ========================================================================
;;; pregexp-compat.sls
;;; ========================================================================

(display "--- pregexp-compat ---\n")

(check-true "pregexp-match" (and (pregexp-match "^hello" "hello world") #t))
(check "pregexp-match-fail" (pregexp-match "^xyz" "hello") #f)
(check-true "pregexp-split" (pair? (pregexp-split "\\s+" "hello world")))

;;; ========================================================================
;;; snippets.sls
;;; ========================================================================

(display "--- snippets ---\n")

(check-true "builtin-snippets-c" (> (length (snippet-all-triggers 'c)) 0))
(check-true "builtin-snippets-scheme" (> (length (snippet-all-triggers 'scheme)) 0))

;;; ========================================================================
;;; vtscreen.sls
;;; ========================================================================

(display "--- vtscreen ---\n")

(let ((vt (new-vtscreen 24 80)))
  (check "vtscreen-rows" (vtscreen-rows vt) 24)
  (check "vtscreen-cols" (vtscreen-cols vt) 80)
  (vtscreen-feed! vt "Hello")
  (let ((rendered (vtscreen-render vt)))
    (check-true "vtscreen-render" (string? rendered))
    (check "vtscreen-content" (substring rendered 0 5) "Hello")))

;;; ========================================================================
;;; org-parse.sls
;;; ========================================================================

(display "--- org-parse ---\n")

;; Timestamp parsing
(let ((ts (org-parse-timestamp "<2024-01-15 Mon 10:00>")))
  (check-true "ts-parsed" (org-timestamp? ts))
  (check "ts-year" (org-timestamp-year ts) 2024)
  (check "ts-month" (org-timestamp-month ts) 1)
  (check "ts-day" (org-timestamp-day ts) 15)
  (check "ts-hour" (org-timestamp-hour ts) 10)
  (check "ts-minute" (org-timestamp-minute ts) 0)
  (check "ts-type" (org-timestamp-type ts) 'active)
  (check "ts-day-name" (org-timestamp-day-name ts) "Mon"))

(let ((ts (org-parse-timestamp "[2024-06-01]")))
  (check-true "ts-inactive" (org-timestamp? ts))
  (check "ts-inactive-type" (org-timestamp-type ts) 'inactive)
  (check "ts-no-time" (org-timestamp-hour ts) #f))

(check "ts-invalid" (org-parse-timestamp "not a timestamp") #f)

;; Timestamp rendering
(let ((ts (org-parse-timestamp "<2024-01-15 Mon 10:00>")))
  (check "ts-render" (org-timestamp->string ts) "<2024-01-15 Mon 10:00>"))

;; Heading parsing
(let-values (((level kw pri title tags) (org-parse-heading-line "** TODO [#A] My task :work:urgent:")))
  (check "heading-level" level 2)
  (check "heading-kw" kw "TODO")
  (check "heading-pri" pri #\A)
  (check "heading-title" title "My task")
  (check "heading-tags" tags '("work" "urgent")))

(let-values (((level kw pri title tags) (org-parse-heading-line "* Simple heading")))
  (check "heading-simple-level" level 1)
  (check "heading-simple-kw" kw #f)
  (check "heading-simple-title" title "Simple heading"))

;; Buffer parsing
(let* ((text "* TODO First\n** DONE Sub-task\n* Second heading\n")
       (headings (org-parse-buffer text)))
  (check "buffer-heading-count" (length headings) 3)
  (check "buffer-h1-title" (org-heading-title (car headings)) "First")
  (check "buffer-h1-kw" (org-heading-keyword (car headings)) "TODO"))

;; Buffer settings
(let* ((text "#+TITLE: My Notes\n#+AUTHOR: Test\n#+TODO: TODO NEXT | DONE CANCELLED\n")
       (settings (org-parse-buffer-settings text)))
  (check "settings-title" (hash-get settings "title") "My Notes")
  (check "settings-author" (hash-get settings "author") "Test")
  (check-true "settings-todo-active" (member "NEXT" (hash-get settings "todo-active"))))

;; Utility helpers
(check-true "heading-line?" (org-heading-line? "* foo"))
(check "not-heading-line?" (org-heading-line? "foo") #f)
(check "stars-of-line" (org-heading-stars-of-line "*** foo") 3)
(check-true "string-prefix-ci?" (string-prefix-ci? "#+BEGIN" "#+begin_src foo"))

;;; ========================================================================
;;; ipc.sls
;;; ========================================================================

(display "--- ipc ---\n")

;; Just verify the module loaded — no server start needed
(check-true "ipc-server-file" (string? *ipc-server-file*))
(check "ipc-poll-empty" (ipc-poll-files!) '())

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display "Tier 0 Test Results: ")
(display pass-count)
(display " passed, ")
(display fail-count)
(display " failed\n")
(display "========================================\n")

(when (> fail-count 0)
  (exit 1))
