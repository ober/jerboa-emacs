#!chezscheme
;;; test-core.ss — Tests for (jerboa-emacs core)

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1- sort sort!)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs core))

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

;;; --- Quit flag ---
(display "--- quit-flag ---\n")
(check-false (quit-flag?))
(quit-flag-set!)
(check-true (quit-flag?))
(quit-flag-clear!)
(check-false (quit-flag?))

;;; --- Keymap ---
(display "--- keymap ---\n")
(let ((km (make-keymap)))
  (keymap-bind! km "C-f" 'forward-char)
  (check (keymap-lookup km "C-f") => 'forward-char)
  (check (keymap-lookup km "C-b") => #f)
  (let ((entries (keymap-entries km)))
    (check (length entries) => 1)))

;;; --- Key state ---
(display "--- key-state ---\n")
(let ((ks (make-key-state *global-keymap* '())))
  (check-true (key-state? ks))
  (check (key-state-prefix-keys ks) => '())
  (key-state-prefix-keys-set! ks '("C-x"))
  (check (key-state-prefix-keys ks) => '("C-x")))

;;; --- Global keymaps ---
(display "--- global-keymaps ---\n")
(check-true (hash-table? *global-keymap*))
(check-true (hash-table? *ctrl-x-map*))
(check-true (hash-table? *ctrl-c-map*))

;;; --- Mode keymaps ---
(display "--- mode-keymaps ---\n")
(let ((km (make-keymap)))
  (mode-keymap-set! 'test-mode km)
  (check (mode-keymap-get 'test-mode) => km))

;;; --- Echo state ---
(display "--- echo-state ---\n")
(let ((echo (make-initial-echo-state)))
  (check-true (echo-state? echo))
  (check (echo-state-message echo) => #f)
  (check (echo-state-error? echo) => #f)
  (echo-message! echo "hello")
  (check (echo-state-message echo) => "hello")
  (check (echo-state-error? echo) => #f)
  (echo-clear! echo)
  (check (echo-state-message echo) => #f))

;;; --- Hooks ---
(display "--- hooks ---\n")
(let ((called #f))
  (define (test-hook-fn) (set! called #t))
  (add-hook! 'test-hook test-hook-fn)
  (run-hooks! 'test-hook)
  (check-true called)
  (set! called #f)
  (remove-hook! 'test-hook test-hook-fn)
  (run-hooks! 'test-hook)
  (check-false called))

;;; --- Buffer ---
(display "--- buffer ---\n")
(let ((buf (make-buffer "test.txt" "/tmp/test.txt" #f #f #f 'scheme #f)))
  (check-true (buffer? buf))
  (check (buffer-name buf) => "test.txt")
  (check (buffer-file-path buf) => "/tmp/test.txt")
  (check (buffer-mark buf) => #f)
  (buffer-mark-set! buf 42)
  (check (buffer-mark buf) => 42))

;;; --- App state ---
(display "--- app-state ---\n")
(let ((app (new-app-state 'dummy-frame)))
  (check-true (app-state? app))
  (check (app-state-frame app) => 'dummy-frame)
  (check-true (app-state-running app))
  (check (app-state-last-search app) => #f)
  (check (app-state-kill-ring app) => '())
  (check (get-prefix-arg app) => 1)
  (check (get-prefix-arg app 5) => 5)
  (app-state-prefix-arg-set! app 3)
  (check (get-prefix-arg app) => 3)
  (app-state-prefix-arg-set! app #f)
  (check (get-prefix-arg app) => 1))

;;; --- Command registry ---
(display "--- commands ---\n")
(let ((called-with #f))
  (register-command! 'test-cmd (lambda (app) (set! called-with app)))
  (check-true (procedure? (find-command 'test-cmd)))
  (check (find-command 'nonexistent) => #f))

(display "--- command-name->description ---\n")
(check (command-name->description 'find-file) => "Find file")
(check (command-name->description 'toggle-auto-revert) => "Toggle auto revert")

;;; --- Shared helpers ---
(display "--- helpers ---\n")
(check-true (brace-char? 40))   ; (
(check-true (brace-char? 125))  ; }
(check-false (brace-char? 65))  ; A

(check (safe-string-trim "  hello  ") => "hello  ")
(check (safe-string-trim-both "  hello  ") => "hello")
(check (safe-string-trim "") => "")

;;; --- File I/O ---
(display "--- file-io ---\n")
(let ((path "/tmp/jemacs-test-io.txt"))
  (write-string-to-file path "hello world")
  (check (read-file-as-string path) => "hello world")
  (delete-file path))

;;; --- Fuzzy matching ---
(display "--- fuzzy ---\n")
(check-true (fuzzy-match? "ff" "find-file"))
(check-true (fuzzy-match? "sb" "switch-buffer"))
(check-false (fuzzy-match? "zz" "find-file"))
(check (> (fuzzy-score "ff" "find-file") 0) => #t)
(check (fuzzy-score "zz" "find-file") => -1)

(let ((results (fuzzy-filter-sort "ff" '("find-file" "forward-char" "foo-fighter" "delete-char"))))
  (check-true (member "find-file" results))
  (check-false (member "delete-char" results)))

;;; --- Key translation ---
(display "--- key-translation ---\n")
(key-translate! #\[ #\()
(check (key-translate-char #\[) => #\()
(check (key-translate-char #\a) => #\a)

;;; --- Key chord ---
(display "--- key-chord ---\n")
(key-chord-define-global "jk" 'keyboard-quit)
(check (chord-lookup #\j #\k) => 'keyboard-quit)
(check (chord-lookup #\J #\K) => 'keyboard-quit)
(check-true (chord-start-char? #\j))
(check-false (chord-start-char? #\z))

;;; --- Repeat mode ---
(display "--- repeat-mode ---\n")
(check-true (repeat-mode?))
(repeat-mode-set! #f)
(check-false (repeat-mode?))
(repeat-mode-set! #t)

(register-default-repeat-maps!)
(check-true (pair? (repeat-map-for-command 'other-window)))
(check (repeat-map-for-command 'nonexistent-command) => #f)

;;; --- Defun boundaries ---
(display "--- defun-boundaries ---\n")
(let* ((text "(define (foo x)\n  (+ x 1))\n")
       (tlen (string-length text)))
  (let-values (((start end) (find-defun-boundaries text 5 'scheme)))
    (check start => 0)
    (check (<= end tlen) => #t)
    (check (> end 20) => #t)))
(let-values (((start end) (find-defun-boundaries "" 0 'scheme)))
  (check start => #f)
  (check end => #f))

;;; --- Re-exports from face ---
(display "--- face-reexports ---\n")
(let ((f (new-face 'fg "#ff0000" 'bold #t)))
  (check-true (face? f))
  (check (face-fg f) => "#ff0000")
  (check (face-bold f) => #t))

;;; --- Re-exports from themes ---
(display "--- theme-reexports ---\n")
(check-true (pair? (theme-names)))
(check-true (pair? (theme-get 'dark)))

;;; --- Re-exports from customize ---
(display "--- customize-reexports ---\n")
(defvar! 'test-core-var 42 "A test variable")
(check (custom-get 'test-core-var) => 42)

;;; --- Frame management ---
(display "--- frames ---\n")
(check (>= (frame-count) 1) => #t)

;;; --- Dired ---
(display "--- dired ---\n")
(check (strip-trailing-slash "/home/user/") => "/home/user")
(check (strip-trailing-slash "/home/user") => "/home/user")

;;; Results
(newline)
(display "========================================\n")
(display (string-append "Core Test Results: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
