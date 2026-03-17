#!chezscheme
;;; test-tier4.ss — Tests for Tier 4 modules (TUI infrastructure)
;;;
;;; Tests pure logic parts of buffer, keymap, echo, window,
;;; modeline, highlight, and terminal modules.
;;; TUI-interactive parts (tui-print!, tui-poll-event, etc.)
;;; cannot be tested without a live terminal.

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1- sort sort!
          getenv path-extension path-absolute? thread?
          make-mutex mutex? mutex-name)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs core)
        (jerboa-emacs buffer)
        (jerboa-emacs keymap)
        (jerboa-emacs echo)
        (jerboa-emacs window)
        (jerboa-emacs highlight)
        (jerboa-emacs terminal)
        (only (std srfi srfi-13) string-contains))

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

;;; --- Echo: Minibuffer history ---
(display "--- echo-minibuffer-history ---\n")
;; Initial state
(check (minibuffer-history) => '())
;; Add items
(minibuffer-history-add! "hello")
(check (car (minibuffer-history)) => "hello")
(minibuffer-history-add! "world")
(check (car (minibuffer-history)) => "world")
(check (length (minibuffer-history)) => 2)
;; Empty strings are not added
(let ((before (length (minibuffer-history))))
  (minibuffer-history-add! "")
  (check (length (minibuffer-history)) => before))
;; Reset
(minibuffer-history-set! '())
(check (minibuffer-history) => '())

;;; --- Echo: Test responses ---
(display "--- echo-test-responses ---\n")
(check (test-echo-responses) => '())
(test-echo-responses-set! '("a" "b"))
(check (length (test-echo-responses)) => 2)
(test-echo-responses-set! '())

;;; --- Window: Split tree helpers ---
(display "--- window-structs ---\n")
;; Basic struct creation
(let* ((win (make-edit-window #f #f 0 0 80 24 0))
       (leaf (make-split-leaf win)))
  (check-true (edit-window? win))
  (check-true (split-leaf? leaf))
  (check (edit-window-w win) => 80)
  (check (edit-window-h win) => 24)
  (check (split-leaf-edit-window leaf) => win))

;;; --- Window: split-tree-flatten ---
(display "--- split-tree-flatten ---\n")
(let* ((w1 (make-edit-window #f #f 0 0 40 24 0))
       (w2 (make-edit-window #f #f 40 0 40 24 0))
       (l1 (make-split-leaf w1))
       (l2 (make-split-leaf w2))
       (node (make-split-node 'horizontal (list l1 l2))))
  ;; Flatten should return both windows
  (check (length (split-tree-flatten node)) => 2)
  (check (car (split-tree-flatten node)) => w1)
  (check (cadr (split-tree-flatten node)) => w2)
  ;; Single leaf
  (check (length (split-tree-flatten l1)) => 1))

;;; --- Window: split-tree-find-parent ---
(display "--- split-tree-find-parent ---\n")
(let* ((w1 (make-edit-window #f #f 0 0 40 24 0))
       (w2 (make-edit-window #f #f 40 0 40 24 0))
       (l1 (make-split-leaf w1))
       (l2 (make-split-leaf w2))
       (node (make-split-node 'horizontal (list l1 l2))))
  (check (split-tree-find-parent node w1) => node)
  (check (split-tree-find-parent node w2) => node)
  ;; Leaf is root, no parent
  (check (split-tree-find-parent l1 w1) => #f))

;;; --- Window: split-tree-find-leaf ---
(display "--- split-tree-find-leaf ---\n")
(let* ((w1 (make-edit-window #f #f 0 0 40 24 0))
       (l1 (make-split-leaf w1)))
  (check (split-tree-find-leaf l1 w1) => l1)
  (let ((w2 (make-edit-window #f #f 0 0 40 24 0)))
    (check (split-tree-find-leaf l1 w2) => #f)))

;;; --- Window: frame struct ---
(display "--- frame-struct ---\n")
(let* ((win (make-edit-window #f #f 0 0 80 24 0))
       (root (make-split-leaf win))
       (fr (make-frame root (list win) 0 80 25)))
  (check-true (frame? fr))
  (check (frame-width fr) => 80)
  (check (frame-height fr) => 25)
  (check (frame-current-idx fr) => 0)
  (check (current-window fr) => win))

;;; --- Highlight: Language detection ---
(display "--- detect-file-language ---\n")
(check (detect-file-language "test.ss") => 'scheme)
(check (detect-file-language "test.scm") => 'scheme)
(check (detect-file-language "test.sls") => 'scheme)
(check (detect-file-language "test.py") => 'python)
(check (detect-file-language "test.js") => 'javascript)
(check (detect-file-language "test.ts") => 'typescript)
(check (detect-file-language "test.c") => 'c)
(check (detect-file-language "test.rs") => 'rust)
(check (detect-file-language "test.go") => 'go)
(check (detect-file-language "test.rb") => 'ruby)
(check (detect-file-language "test.lua") => 'lua)
(check (detect-file-language "test.sql") => 'sql)
(check (detect-file-language "test.sh") => 'bash)
(check (detect-file-language "test.html") => 'html)
(check (detect-file-language "test.css") => 'css)
(check (detect-file-language "test.json") => 'json)
(check (detect-file-language "test.yaml") => 'yaml)
(check (detect-file-language "test.toml") => 'toml)
(check (detect-file-language "test.md") => 'markdown)
(check (detect-file-language "test.diff") => 'diff)
(check (detect-file-language "test.org") => 'org)
(check (detect-file-language "Makefile") => 'makefile)
(check (detect-file-language "test.java") => 'java)

;;; --- Highlight: Gerbil file extension ---
(display "--- gerbil-file-extension ---\n")
(check-true (gerbil-file-extension? "test.ss"))
(check-true (gerbil-file-extension? "test.scm"))
(check-true (gerbil-file-extension? "test.sls"))
(check-false (gerbil-file-extension? "test.py"))
(check-false (gerbil-file-extension? #f))

;;; --- Highlight: Shebang detection ---
(display "--- detect-language-from-shebang ---\n")
(check (detect-language-from-shebang "#!/bin/bash\necho hello") => 'bash)
(check (detect-language-from-shebang "#!/usr/bin/env python3\nprint('hi')") => 'python)
(check (detect-language-from-shebang "#!/usr/bin/ruby\nputs 'hi'") => 'ruby)
(check (detect-language-from-shebang "#!/usr/bin/env node\nconsole.log()") => 'javascript)
(check (detect-language-from-shebang "no shebang") => #f)

;;; --- Highlight: Custom highlighter registry ---
(display "--- custom-highlighter-registry ---\n")
(check-true (hash-table? *custom-highlighters*))

;;; --- Terminal: ANSI parsing ---
(display "--- parse-ansi-segments ---\n")
;; Plain text
(let ((segs (parse-ansi-segments "hello world")))
  (check (length segs) => 1)
  (check (text-segment-text (car segs)) => "hello world")
  (check (text-segment-fg-color (car segs)) => -1)
  (check-false (text-segment-bold? (car segs))))

;; Text with color
(let ((segs (parse-ansi-segments "\x1b;[31mred\x1b;[0m")))
  (check (length segs) => 1)
  (check (text-segment-text (car segs)) => "red")
  (check (text-segment-fg-color (car segs)) => 1))  ;; red = 1

;; Bold text
(let ((segs (parse-ansi-segments "\x1b;[1mbold\x1b;[0m")))
  (check (length segs) => 1)
  (check-true (text-segment-bold? (car segs))))

;; Multiple segments
(let ((segs (parse-ansi-segments "normal\x1b;[32mgreen\x1b;[0mback")))
  (check (length segs) => 3)
  (check (text-segment-text (car segs)) => "normal")
  (check (text-segment-text (cadr segs)) => "green")
  (check (text-segment-fg-color (cadr segs)) => 2)
  (check (text-segment-text (caddr segs)) => "back"))

;; Carriage return stripping
(let ((segs (parse-ansi-segments "hello\rworld")))
  (check (text-segment-text (car segs)) => "helloworld"))

;;; --- Terminal: color-to-style ---
(display "--- color-to-style ---\n")
(check (color-to-style -1 #f) => 0)  ;; default
(check (color-to-style -1 #t) => (+ 64 15))  ;; bright white
(check (color-to-style 1 #f) => (+ 64 1))  ;; red
(check (color-to-style 1 #t) => (+ 64 9))  ;; bright red (1+8)
(check (color-to-style 8 #f) => (+ 64 8))  ;; bright black
(check (color-to-style 8 #t) => (+ 64 8))  ;; already bright, no shift

;;; --- Terminal: terminal state ---
(display "--- terminal-state ---\n")
(let ((ts (make-terminal-state #f 0 -1 #f #f #f #f #f #f #f)))
  (check-true (terminal-state? ts))
  (check (terminal-state-prompt-pos ts) => 0)
  (check (terminal-state-fg-color ts) => -1)
  (check-false (terminal-state-bold? ts))
  (check-false (terminal-pty-busy? ts)))

;;; --- Terminal: prompt ---
(display "--- terminal-prompt ---\n")
(let ((ts (make-terminal-state #f 0 -1 #f #f #f #f #f #f #f)))
  (let ((prompt (terminal-prompt ts)))
    (check-true (string? prompt))
    (check-true (> (string-length prompt) 0))
    (check-true (string-contains prompt "$"))))

;;; --- Terminal: terminal-buffer? ---
(display "--- terminal-buffer? ---\n")
(let ((buf (make-buffer "test" #f #f #f #f #f #f)))
  (check-false (terminal-buffer? buf)))
(let ((buf (make-buffer "term" #f #f #f #f 'terminal #f)))
  (check-true (terminal-buffer? buf)))

;;; --- Terminal: styles ---
(display "--- terminal-style-constants ---\n")
(check *term-style-base* => 64)
(check SCI_STARTSTYLING => 2032)
(check SCI_SETSTYLING => 2033)

;;; Results
(newline)
(display "========================================\n")
(display (string-append "Tier 4 Test Results: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
