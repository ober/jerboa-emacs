#!chezscheme
;;; test-org-agenda.ss — Tests for org-agenda module
;;; Ported from gerbil-emacs/org-agenda-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs org-agenda)
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

(define-syntax check-false
  (syntax-rules ()
    ((_ expr)
     (check (not expr) => #t))))

;; Adapters: test functions omit file-path arg; actual functions require it.
(define (org-collect-agenda-items-test text date-from date-to)
  (org-collect-agenda-items text "" date-from date-to))

(define (zero-pad-2 n)
  (if (< n 10) (string-append "0" (number->string n)) (number->string n)))

(define (make-agenda-item heading-title type date hour minute)
  (let ((h (make-org-heading 1 #f #f heading-title '() #f #f #f #f '() 0 #f)))
    (make-org-agenda-item h type date
                          (string-append (zero-pad-2 hour) ":" (zero-pad-2 minute))
                          "" 0)))

(define (org-agenda-todo-list-test text)
  (org-agenda-todo-list text ""))

(define (org-agenda-tags-match-test text tag-expr)
  (org-agenda-tags-match text "" tag-expr))

(define (org-agenda-search-test text query)
  (org-agenda-search text "" query))

;;; ========================================================================
;;; Date utility functions
;;; ========================================================================

(display "--- date-utilities ---\n")

(check (org-date-weekday 2024 1 15) => 1)  ; Monday
(check (org-date-weekday 2024 1 14) => 0)  ; Sunday
(check (org-date-weekday 2024 1 13) => 6)  ; Saturday
(check (org-date-weekday 2024 1 17) => 3)  ; Wednesday
(check (org-date-weekday 2024 1 19) => 5)  ; Friday

;;; ========================================================================
;;; Date timestamp creation
;;; ========================================================================

(display "--- date-ts-creation ---\n")

(let ((ts (org-make-date-ts 2024 3 15)))
  (check-true ts))

(let ((ts1 (org-make-date-ts 2024 1 1))
      (ts2 (org-make-date-ts 2024 12 31)))
  (check-true ts1)
  (check-true ts2))

;;; ========================================================================
;;; Timestamp range checking
;;; ========================================================================

(display "--- timestamp-range ---\n")

(let ((ts (org-make-date-ts 2024 1 15))
      (start (org-make-date-ts 2024 1 10))
      (end (org-make-date-ts 2024 1 20)))
  (check (org-timestamp-in-range? ts start end) => #t))

(let ((ts (org-make-date-ts 2024 1 5))
      (start (org-make-date-ts 2024 1 10))
      (end (org-make-date-ts 2024 1 20)))
  (check (org-timestamp-in-range? ts start end) => #f))

(let ((ts (org-make-date-ts 2024 1 25))
      (start (org-make-date-ts 2024 1 10))
      (end (org-make-date-ts 2024 1 20)))
  (check (org-timestamp-in-range? ts start end) => #f))

;; Boundary conditions
(let ((ts (org-make-date-ts 2024 1 10))
      (start (org-make-date-ts 2024 1 10))
      (end (org-make-date-ts 2024 1 20)))
  (check (org-timestamp-in-range? ts start end) => #t))

(let ((ts (org-make-date-ts 2024 1 20))
      (start (org-make-date-ts 2024 1 10))
      (end (org-make-date-ts 2024 1 20)))
  (check (org-timestamp-in-range? ts start end) => #t))

;;; ========================================================================
;;; Date advancing
;;; ========================================================================

(display "--- date-advancing ---\n")

(let ((result (org-advance-date-ts (org-make-date-ts 2024 1 30) 3)))
  (check-true result))

(let ((result (org-advance-date-ts (org-make-date-ts 2024 6 15) 0)))
  (check-true result))

(let ((result (org-advance-date-ts (org-make-date-ts 2024 12 30) 5)))
  (check-true result))

;;; ========================================================================
;;; Agenda item collection
;;; ========================================================================

(display "--- agenda-collection ---\n")

(let* ((text (string-append
              "* TODO Task 1\n"
              "SCHEDULED: <2024-01-15 Mon 09:00>\n"
              "* TODO Task 2\n"
              "DEADLINE: <2024-01-20 Sat 17:00>\n"
              "* DONE Completed\n"
              "CLOSED: [2024-01-10 Wed]\n"))
       (start (org-make-date-ts 2024 1 1))
       (end (org-make-date-ts 2024 1 31))
       (items (org-collect-agenda-items-test text start end)))
  (check-true (>= (length items) 2)))

(let ((items (org-collect-agenda-items-test
              "" (org-make-date-ts 2024 1 1) (org-make-date-ts 2024 1 31))))
  (check (null? items) => #t))

;;; ========================================================================
;;; Agenda sorting
;;; ========================================================================

(display "--- agenda-sorting ---\n")

(let* ((item1 (make-agenda-item "Task 1" 'scheduled
                                (org-make-date-ts 2024 1 15) 9 0))
       (item2 (make-agenda-item "Task 2" 'deadline
                                (org-make-date-ts 2024 1 15) 17 0))
       (sorted (org-agenda-sort-items (list item2 item1))))
  (check (equal? (org-heading-title (org-agenda-item-heading (car sorted))) "Task 1") => #t))

;;; ========================================================================
;;; TODO list
;;; ========================================================================

(display "--- todo-list ---\n")

(let* ((text (string-append
              "* TODO Active task\n"
              "* DONE Completed task\n"
              "* TODO Another active\n"))
       (todos (org-agenda-todo-list-test text)))
  (check-true (string-contains todos "Active task"))
  (check-true (string-contains todos "Another active"))
  (check-false (string-contains todos "Completed task")))

(let ((todos (org-agenda-todo-list-test "* Just a heading\n")))
  (check-true (string-contains todos "No TODO")))

;;; ========================================================================
;;; Tag search
;;; ========================================================================

(display "--- tag-search ---\n")

(let* ((text (string-append
              "* Task A :work:\n"
              "* Task B :home:\n"
              "* Task C :work:urgent:\n"))
       (results (org-agenda-tags-match-test text "work")))
  (check-true (string-contains results "Task A"))
  (check-true (string-contains results "Task C")))

(let* ((text (string-append
              "* Task A :work:\n"
              "* Task B :home:\n"))
       (results (org-agenda-tags-match-test text "nonexistent")))
  (check-true (string-contains results "No matches")))

;;; ========================================================================
;;; Text search
;;; ========================================================================

(display "--- text-search ---\n")

(let* ((text (string-append
              "* Meeting with Alice\n"
              "* Lunch with Bob\n"
              "* Call with ALICE\n"))
       (results (org-agenda-search-test text "alice")))
  (check-true (string-contains results "Alice")))

(let* ((text "* Task A\n* Task B\n")
       (results (org-agenda-search-test text "nonexistent")))
  (check-true (string-contains results "No matches")))

;;; ========================================================================
;;; Agenda item formatting
;;; ========================================================================

(display "--- agenda-formatting ---\n")

(let* ((item (make-agenda-item "Review code" 'scheduled
                               (org-make-date-ts 2024 1 15) 10 0))
       (formatted (org-format-agenda-item item)))
  (check-true (string-contains formatted "Review code")))

(let* ((item (make-agenda-item "Review code" 'scheduled
                               (org-make-date-ts 2024 1 15) 10 0))
       (formatted (org-format-agenda-item item)))
  (check-true (string-contains formatted "10:00")))

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "org-agenda Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
