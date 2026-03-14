#!chezscheme
;;; test-tier2.ss — Tests for Tier 2 modules

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1- sort sort!)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs core)
        (jerboa-emacs shell-history)
        (jerboa-emacs persist)
        (jerboa-emacs helm)
        (jerboa-emacs org-parse)
        (jerboa-emacs org-agenda)
        (jerboa-emacs async)
        (jerboa-emacs subprocess)
        (jerboa-emacs repl)
        (jerboa-emacs chat)
        (jerboa-emacs debug-repl)
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

;;; --- Shell History ---
(display "--- shell-history ---\n")
(check (gsh-history) => '())
(check (gsh-history-file) => ".gsh_history")
(check (gsh-history-max) => 10000)
(check (gsh-history-recent 5) => '())
(check (gsh-history-search "foo" 10) => '())
(check (gsh-history-all) => '())

;;; --- Persist: Recent files ---
(display "--- persist-recent-files ---\n")
(check (recent-files) => '())
(check (recent-files-max) => 50)

;;; --- Persist: Desktop entry ---
(display "--- desktop-entry ---\n")
(let ((de (make-desktop-entry "test.txt" "/tmp/test.txt" 42 'scheme-mode)))
  (check-true (desktop-entry? de))
  (check (desktop-entry-buffer-name de) => "test.txt")
  (check (desktop-entry-file-path de) => "/tmp/test.txt")
  (check (desktop-entry-cursor-pos de) => 42)
  (check (desktop-entry-major-mode de) => 'scheme-mode))

;;; --- Persist: M-x history ---
(display "--- mx-history ---\n")
(check-true (hash-table? (mx-history)))
(mx-history-add! "find-file")
(mx-history-add! "find-file")
(mx-history-add! "save-buffer")
(let ((ordered (mx-history-ordered-candidates '("find-file" "save-buffer" "quit"))))
  ;; find-file has count 2, save-buffer has count 1, quit has count 0
  (check (car ordered) => "find-file")
  (check (cadr ordered) => "save-buffer"))

;;; --- Persist: Auto-mode ---
(display "--- auto-mode ---\n")
(check (detect-major-mode "test.py") => 'python-mode)
(check (detect-major-mode "test.ss") => 'scheme-mode)
(check (detect-major-mode "Makefile") => 'makefile-mode)
(check (detect-major-mode "unknown.xyz") => #f)

;;; --- Persist: Which-key ---
(display "--- which-key ---\n")
(check-true (which-key-mode))
(check (which-key-delay) => 0.5)
(which-key-mode-set! #f)
(check-false (which-key-mode))
(which-key-mode-set! #t)

;;; --- Persist: Scroll margin ---
(display "--- scroll-margin ---\n")
(check (scroll-margin) => 3)
(scroll-margin-set! 5)
(check (scroll-margin) => 5)
(scroll-margin-set! 3)

;;; --- Persist: Buffer locals ---
(display "--- buffer-locals ---\n")
(let ((buf 'test-buf))
  (buffer-local-set! buf 'tab-width 4)
  (check (buffer-local-get buf 'tab-width) => 4)
  (check (buffer-local-get buf 'nonexistent 99) => 99)
  (buffer-local-delete! buf)
  (check (buffer-local-get buf 'tab-width) => #f))

;;; --- Persist: Save-place ---
(display "--- save-place ---\n")
(check-true (save-place-enabled))
(save-place-remember! "/tmp/test.txt" 100)
(check (save-place-restore "/tmp/test.txt") => 100)
(check (save-place-restore "/nonexistent") => #f)

;;; --- Persist: Mode toggles ---
(display "--- mode-toggles ---\n")
(check-false (centered-cursor-mode))
(centered-cursor-mode-set! #t)
(check-true (centered-cursor-mode))
(centered-cursor-mode-set! #f)

(check-false (auto-fill-mode))
(check (fill-column) => 80)

(check-true (abbrev-mode-enabled))
(check-false (enriched-mode))
(check-false (picture-mode))
(check-false (electric-pair-mode))
(check-false (copilot-mode))
(check (copilot-model) => "gpt-4o-mini")

;;; --- Helm: Data structures ---
(display "--- helm-structs ---\n")
(let ((src (make-helm-source
              "Test" (lambda () '("foo" "bar" "baz"))
              '(("Default" . ,(lambda (x) x)))
              #f #f #f #t #f 100 #f #f)))
  (check-true (helm-source? src))
  (check (helm-source-name src) => "Test")
  (check-true (helm-source-fuzzy? src)))

(let ((cand (make-helm-candidate "display" "real" 'src)))
  (check-true (helm-candidate? cand))
  (check (helm-candidate-display cand) => "display")
  (check (helm-candidate-real cand) => "real"))

;;; --- Helm: Multi-match ---
(display "--- helm-multi-match ---\n")
(check-true (helm-multi-match? "" "anything"))
(check-true (helm-multi-match? "foo" "foobar"))
(check-false (helm-multi-match? "xyz" "foobar"))
(check-true (helm-multi-match? "^foo" "foobar"))
(check-false (helm-multi-match? "^bar" "foobar"))
(check-true (helm-multi-match? "!xyz" "foobar"))
(check-false (helm-multi-match? "!foo" "foobar"))
;; Multiple tokens (AND)
(check-true (helm-multi-match? "foo bar" "foobar"))
(check-false (helm-multi-match? "foo xyz" "foobar"))

;; Score
(check (> (helm-multi-match "foo" "foobar") 0) => #t)
(check (helm-multi-match "xyz" "foobar") => -1)

;;; --- Helm: Match positions ---
(display "--- helm-match-positions ---\n")
(check-true (pair? (helm-match-positions "foo" "foobar")))
(check (helm-match-positions "" "foobar") => '())

;;; --- Helm: Session ---
(display "--- helm-session ---\n")
(check (helm-sessions) => '())
(check (helm-last-session) => #f)

;;; --- Org Agenda: Date arithmetic ---
(display "--- org-agenda-dates ---\n")
;; Monday = 1 (Zeller)
(check (org-date-weekday 2024 1 1) => 1)  ; Monday Jan 1, 2024
(let ((ts (org-make-date-ts 2024 3 15)))
  (check-true (org-timestamp? ts))
  (check (org-timestamp-year ts) => 2024)
  (check (org-timestamp-month ts) => 3)
  (check (org-timestamp-day ts) => 15))

;;; --- Org Agenda: Timestamp range ---
(display "--- org-agenda-range ---\n")
(let ((ts (org-make-date-ts 2024 3 15))
      (from (org-make-date-ts 2024 3 10))
      (to (org-make-date-ts 2024 3 20)))
  (check-true (org-timestamp-in-range? ts from to))
  (check-false (org-timestamp-in-range? ts to (org-make-date-ts 2024 3 25))))

;;; --- Org Agenda: TODO list ---
(display "--- org-agenda-todo ---\n")
(let ((text "* TODO Task one\n* DONE Task two\n* TODO Task three\n"))
  (let ((result (org-agenda-todo-list text "/tmp/test.org")))
    (check-true (string? result))
    (check-true (string-contains result "Task one"))
    (check-false (string-contains result "Task two"))
    (check-true (string-contains result "Task three"))))

;;; --- Org Agenda: Search ---
(display "--- org-agenda-search ---\n")
(let ((text "* Meeting notes\n* Shopping list\n* Code review\n"))
  (let ((result (org-agenda-search text "/tmp/test.org" "code")))
    (check-true (string-contains result "Code review"))
    (check-false (string-contains result "Shopping"))))

;;; --- Async: current-time-ms ---
(display "--- async ---\n")
(check-true (> (current-time-ms) 0))

;;; --- Subprocess: State ---
(display "--- subprocess ---\n")
(check (active-subprocess) => #f)

;;; --- Chat: State ---
(display "--- chat ---\n")
(let ((cs (chat-start! "/tmp")))
  (check-true (chat-state? cs))
  (check-false (chat-busy? cs))
  (check (chat-state-cwd cs) => "/tmp"))

;;; --- Repl: Struct ---
(display "--- repl ---\n")
(check (string? repl-prompt) => #t)

;;; Results
(newline)
(display "========================================\n")
(display (string-append "Tier 2 Test Results: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
