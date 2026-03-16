#!chezscheme
;;; editor-cmds-a.sls — Command batch A (Tasks 36-40)
;;;
;;; Ported from gerbil-emacs/editor-cmds-a.ss
;;; Whitespace, electric-pair, text processing, s-expressions, sort, indent

(library (jerboa-emacs editor-cmds-a)
  (export
    ;; Task #36 — whitespace, electric pair, navigation
    cmd-whitespace-cleanup
    cmd-toggle-electric-pair
    cmd-paredit-strict-mode
    cmd-previous-buffer
    cmd-next-buffer
    cmd-balance-windows
    cmd-move-to-window-line
    cmd-kill-buffer-and-window
    cmd-flush-undo
    cmd-upcase-initials-region
    cmd-untabify-buffer
    cmd-insert-buffer-name
    cmd-toggle-line-move-visual
    cmd-mark-defun
    cmd-goto-line-beginning
    cmd-shrink-window-horizontally
    cmd-insert-parentheses
    cmd-insert-pair-brackets
    cmd-insert-pair-braces
    cmd-insert-pair-quotes
    cmd-describe-char
    cmd-find-file-at-point
    cmd-toggle-show-paren
    cmd-count-chars-region

    ;; Task #37 — text processing, window commands
    cmd-capitalize-region
    cmd-count-words-buffer
    cmd-unfill-paragraph
    cmd-list-registers
    cmd-show-kill-ring
    cmd-smart-beginning-of-line
    cmd-shrink-window-if-larger
    cmd-toggle-input-method
    cmd-what-buffer
    cmd-goto-last-change
    cmd-toggle-narrowing-indicator
    cmd-insert-file-name
    cmd-toggle-auto-save
    cmd-backward-up-list
    cmd-forward-up-list
    cmd-kill-sexp
    cmd-backward-sexp
    cmd-forward-sexp

    ;; Task #38 — s-expression and utility commands
    cmd-transpose-sexps
    cmd-mark-sexp
    cmd-indent-sexp
    cmd-word-frequency
    cmd-insert-uuid
    cmd-reformat-buffer
    cmd-delete-pair
    cmd-toggle-hl-line
    cmd-toggle-column-number-mode
    cmd-find-alternate-file
    cmd-increment-register
    cmd-toggle-size-indication
    cmd-copy-buffer-name

    ;; Task #39 — sort, rectangle, completion, text processing
    editor-get-text-range
    cmd-sort-lines-case-fold
    cmd-reverse-chars
    cmd-replace-string-all
    cmd-insert-file-contents
    cmd-toggle-auto-revert
    cmd-zap-up-to-char
    quoted-insert-pending? quoted-insert-pending-set!
    cmd-quoted-insert
    cmd-what-line-col
    cmd-insert-current-date-iso
    cmd-recenter-top
    cmd-recenter-bottom
    cmd-scroll-other-window
    cmd-scroll-other-window-up
    cmd-count-words-paragraph
    cmd-toggle-transient-mark
    cmd-keep-lines-region
    cmd-flush-lines-region
    cmd-insert-register-string
    cmd-toggle-visible-bell

    ;; Task #40 — indentation, buffers, navigation
    cmd-unindent-region
    cmd-copy-region-as-kill
    cmd-append-to-buffer
    cmd-toggle-show-trailing-whitespace
    cmd-backward-kill-sexp
    cmd-delete-horizontal-space-forward
    cmd-toggle-debug-mode
    cmd-insert-comment-separator
    global-hl-line? global-hl-line-set!
    cmd-toggle-global-hl-line
    cmd-insert-shebang
    cmd-toggle-auto-indent
    cmd-what-mode
    cmd-show-buffer-size
    cmd-goto-percent
    cmd-insert-newline-below
    cmd-insert-newline-above
    cmd-duplicate-region
    cmd-sort-lines-reverse
    cmd-uniquify-lines
    cmd-show-line-endings

    ;; Scroll margin
    apply-scroll-margin-to-editor!
    cmd-set-scroll-margin
    cmd-toggle-scroll-margin

    ;; Init file
    cmd-load-init-file
    cmd-find-init-file

    ;; Save-place
    cmd-toggle-save-place-mode

    ;; Clean-on-save
    cmd-toggle-delete-trailing-whitespace-on-save
    cmd-toggle-require-final-newline

    ;; Centered cursor
    cmd-toggle-centered-cursor-mode

    ;; Project tree file ops
    cmd-project-tree-create-file
    cmd-project-tree-delete-file
    cmd-project-tree-rename-file

    ;; Documentation browser
    doc-init!
    cmd-gemacs-doc

    ;; Async dired operations
    cmd-dired-async-copy
    cmd-dired-async-move

    ;; State accessors
    recenter-position recenter-position-set!)
  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-directory path-strip-directory path-extension
                string-split)
          (only (std srfi srfi-13) string-join string-contains string-prefix?
                string-suffix? string-index string-trim-both string-trim-right
                string-trim)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (except (chez-scintilla style)
                  editor-get-caret-line-visible? editor-set-caret-line-visible)
          (chez-scintilla tui)
          (jerboa-emacs core)
          (jerboa-emacs customize)
          (jerboa-emacs repl)
          (jerboa-emacs eshell)
          (jerboa-emacs shell)
          (jerboa-emacs keymap)
          (jerboa-emacs buffer)
          (jerboa-emacs window)
          (jerboa-emacs modeline)
          (jerboa-emacs echo)
          (jerboa-emacs highlight)
          (jerboa-emacs persist)
          (jerboa-emacs editor-core))

  ;;;=========================================================================
  ;;; Local helpers and state
  ;;;=========================================================================

  ;; string-split with char delimiter is from (jerboa prelude)
  ;; but we also need a string-empty? replacement
  (define (string-empty? s) (string=? s ""))

  ;; Scintilla caret-line-visible helpers (raw SCI messages)
  ;; SCI_GETCARETLINEVISIBLE = 2095, SCI_SETCARETLINEVISIBLE = 2096
  (define (editor-get-caret-line-visible? ed)
    (not (= (send-message ed 2095 0 0) 0)))

  (define (editor-set-caret-line-visible ed visible)
    (send-message ed 2096 (if visible 1 0) 0))

  ;; word-char? — from editor-ui (not yet ported)
  (define (word-char? ch-int)
    (let ((ch (integer->char ch-int)))
      (or (char-alphabetic? ch) (char-numeric? ch)
          (char=? ch #\_) (char=? ch #\-))))

  ;; copy-file helper
  (define (copy-file src dst)
    (let ((data (call-with-port (open-file-input-port src)
                  (lambda (in) (get-bytevector-all in)))))
      (call-with-port (open-file-output-port dst (file-options no-fail))
        (lambda (out) (put-bytevector out data)))))

  ;; UUID helper — generate random hex via Chez random
  (define (random-hex-string n-bytes)
    (let loop ((i 0) (acc '()))
      (if (>= i n-bytes)
        (apply string-append (reverse acc))
        (let ((b (random 256)))
          (loop (+ i 1)
                (cons (let ((s (number->string b 16)))
                        (if (< (string-length s) 2)
                          (string-append "0" s)
                          s))
                      acc))))))

  ;;;=========================================================================
  ;;; Module-level state (with accessor/mutator pairs for exports)
  ;;;=========================================================================

  ;; auto-pair-mode and auto-revert-mode are in editor-core

  ;; Recenter cycle state: center -> top -> bottom -> center
  (define *recenter-position* 'center)
  (define (recenter-position) *recenter-position*)
  (define (recenter-position-set! v) (set! *recenter-position* v))

  ;; Quoted-insert pending
  (define *quoted-insert-pending* #f)
  (define (quoted-insert-pending?) *quoted-insert-pending*)
  (define (quoted-insert-pending-set! v) (set! *quoted-insert-pending* v))

  ;; Global hl-line
  (define *global-hl-line* #t)
  (define (global-hl-line?) *global-hl-line*)
  (define (global-hl-line-set! v) (set! *global-hl-line* v))

  ;; Doc topics
  (define *doc-topics* (make-hash-table))

  ;; Async dired jobs
  (define *dired-async-jobs* '())

  ;;;=========================================================================
  ;;; Task #36 — Whitespace cleanup, electric-pair, navigation
  ;;;=========================================================================

  (define (cmd-whitespace-cleanup app)
    "Remove trailing whitespace and convert tabs to spaces."
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (cleaned (map (lambda (line) (string-trim-right line)) lines))
           (result (string-join cleaned "\n")))
      (unless (string=? text result)
        (with-undo-action ed
          (editor-delete-range ed 0 (string-length text))
          (editor-insert-text ed 0 result)))
      (echo-message! (app-state-echo app) "Whitespace cleaned")))

  (define (cmd-toggle-electric-pair app)
    "Toggle auto-pair mode for brackets and quotes."
    (auto-pair-mode-set! (not (auto-pair-mode?)))
    (echo-message! (app-state-echo app)
      (if (auto-pair-mode?) "Electric pair mode ON" "Electric pair mode OFF")))

  (define (cmd-paredit-strict-mode app)
    "Toggle paredit strict mode."
    (paredit-strict-mode-set! (not (paredit-strict-mode?)))
    (echo-message! (app-state-echo app)
      (if (paredit-strict-mode?) "Paredit strict mode ON" "Paredit strict mode OFF")))

  (define (cmd-previous-buffer app)
    "Switch to the previous buffer in the buffer list."
    (let* ((bufs (buffer-list))
           (cur (current-buffer-from-app app))
           (idx (let loop ((bs bufs) (i 0))
                  (cond ((null? bs) 0)
                        ((eq? (car bs) cur) i)
                        (else (loop (cdr bs) (+ i 1))))))
           (prev-idx (if (= idx 0) (- (length bufs) 1) (- idx 1)))
           (prev-buf (list-ref bufs prev-idx))
           (ed (current-editor app))
           (fr (app-state-frame app)))
      (buffer-attach! ed prev-buf)
      (edit-window-buffer-set! (current-window fr) prev-buf)
      (echo-message! (app-state-echo app)
        (string-append "Buffer: " (buffer-name prev-buf)))))

  (define (cmd-next-buffer app)
    "Switch to the next buffer in the buffer list."
    (let* ((bufs (buffer-list))
           (cur (current-buffer-from-app app))
           (idx (let loop ((bs bufs) (i 0))
                  (cond ((null? bs) 0)
                        ((eq? (car bs) cur) i)
                        (else (loop (cdr bs) (+ i 1))))))
           (next-idx (if (>= (+ idx 1) (length bufs)) 0 (+ idx 1)))
           (next-buf (list-ref bufs next-idx))
           (ed (current-editor app))
           (fr (app-state-frame app)))
      (buffer-attach! ed next-buf)
      (edit-window-buffer-set! (current-window fr) next-buf)
      (echo-message! (app-state-echo app)
        (string-append "Buffer: " (buffer-name next-buf)))))

  (define (cmd-balance-windows app)
    "Make all windows the same size."
    (frame-layout! (app-state-frame app))
    (echo-message! (app-state-echo app) "Windows balanced"))

  (define (cmd-move-to-window-line app)
    "Move point to center, then top, then bottom of window (like Emacs M-r)."
    (let* ((ed (current-editor app))
           (first-vis (editor-get-first-visible-line ed))
           ;; SCI_LINESONSCREEN = 2370
           (lines-on-screen (send-message ed 2370 0 0))
           (target-line
             (case *recenter-position*
               ((center) (+ first-vis (quotient lines-on-screen 2)))
               ((top) first-vis)
               ((bottom) (+ first-vis (- lines-on-screen 1)))
               (else (+ first-vis (quotient lines-on-screen 2))))))
      (editor-goto-pos ed (editor-position-from-line ed target-line))
      ;; Cycle: center -> top -> bottom -> center
      (set! *recenter-position*
        (case *recenter-position*
          ((center) 'top)
          ((top) 'bottom)
          ((bottom) 'center)
          (else 'center)))))

  (define (cmd-kill-buffer-and-window app)
    "Kill current buffer and close its window."
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr)))
      (if (= (length wins) 1)
        (echo-message! (app-state-echo app) "Can't delete sole window")
        (let* ((ed (current-editor app))
               (buf (current-buffer-from-app app)))
          (frame-delete-window! fr)
          (frame-layout! fr)
          ;; Clean up the buffer
          (hash-remove! *dired-entries* buf)
          (hash-remove! (eshell-state) buf)
          (let ((rs (hash-get *repl-state* buf)))
            (when rs (repl-stop! rs) (hash-remove! *repl-state* buf)))
          (let ((ss (hash-get (shell-state-table) buf)))
            (when ss (shell-stop! ss) (hash-remove! (shell-state-table) buf)))))))

  (define (cmd-flush-undo app)
    "Clear the undo history of the current buffer."
    (let ((ed (current-editor app)))
      (editor-empty-undo-buffer ed)
      (echo-message! (app-state-echo app) "Undo history cleared")))

  (define (cmd-upcase-initials-region app)
    "Capitalize the first letter of each word in region."
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if (not mark)
        (echo-message! (app-state-echo app) "No region")
        (let* ((start (min mark pos))
               (end (max mark pos))
               (text (substring (editor-get-text ed) start end))
               (result (string-titlecase text)))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (buffer-mark-set! buf #f)))))

  (define (cmd-untabify-buffer app)
    "Convert all tabs to spaces in the entire buffer."
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (tab-w (editor-get-tab-width ed))
           (spaces (make-string tab-w #\space)))
      (if (not (string-contains text "\t"))
        (echo-message! (app-state-echo app) "No tabs found")
        (let* ((parts (string-split text #\tab))
               (result (string-join parts spaces)))
          (with-undo-action ed
            (editor-delete-range ed 0 (string-length text))
            (editor-insert-text ed 0 result))
          (echo-message! (app-state-echo app) "Untabified buffer")))))

  (define (cmd-insert-buffer-name app)
    "Insert the current buffer name at point."
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos (buffer-name buf))
      (editor-goto-pos ed (+ pos (string-length (buffer-name buf))))))

  (define (cmd-toggle-line-move-visual app)
    "Toggle whether line movement is visual or logical."
    (echo-message! (app-state-echo app) "Line move is always visual in Scintilla"))

  (define (cmd-mark-defun app)
    "Mark the current top-level form (defun-like region)."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Find beginning of defun
      (let ((defun-start
              (let loop ((i pos))
                (cond ((= i 0) 0)
                      ((and (> i 0)
                            (char=? (string-ref text i) #\()
                            (or (= i 0)
                                (char=? (string-ref text (- i 1)) #\newline)))
                       i)
                      (else (loop (- i 1)))))))
        ;; Find end of defun — matching paren
        (let ((defun-end
                (let loop ((i defun-start) (depth 0))
                  (cond ((>= i len) len)
                        ((char=? (string-ref text i) #\()
                         (loop (+ i 1) (+ depth 1)))
                        ((char=? (string-ref text i) #\))
                         (if (= depth 1) (+ i 1)
                           (loop (+ i 1) (- depth 1))))
                        (else (loop (+ i 1) depth))))))
          (editor-set-selection ed defun-start defun-end)
          (echo-message! (app-state-echo app) "Defun marked")))))

  (define (cmd-goto-line-beginning app)
    "Move to the very first position in the buffer."
    (editor-goto-pos (current-editor app) 0))

  (define (cmd-shrink-window-horizontally app)
    "Make current window narrower (not implemented)."
    (echo-message! (app-state-echo app)
      "Use C-x } / C-x { for horizontal resize (not implemented)"))

  (define (cmd-insert-parentheses app)
    "Insert () and position cursor between them."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "()")
      (editor-goto-pos ed (+ pos 1))))

  (define (cmd-insert-pair-brackets app)
    "Insert [] and position cursor between them."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "[]")
      (editor-goto-pos ed (+ pos 1))))

  (define (cmd-insert-pair-braces app)
    "Insert {} and position cursor between them."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "{}")
      (editor-goto-pos ed (+ pos 1))))

  (define (cmd-insert-pair-quotes app)
    "Insert double quotes and position cursor between them."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "\"\"")
      (editor-goto-pos ed (+ pos 1))))

  (define (cmd-describe-char app)
    "Show info about character at point."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (>= pos len)
        (echo-message! (app-state-echo app) "End of buffer")
        (let* ((ch (string-ref text pos))
               (code (char->integer ch)))
          (echo-message! (app-state-echo app)
            (string-append "Char: " (string ch)
                           " (#x" (number->string code 16)
                           ", #o" (number->string code 8)
                           ", " (number->string code) ")"))))))

  (define (cmd-find-file-at-point app)
    "Try to open file whose name is at or near point."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text))
           (start (let loop ((i pos))
                    (if (or (<= i 0)
                            (let ((ch (string-ref text (- i 1))))
                              (or (char=? ch #\space) (char=? ch #\newline)
                                  (char=? ch #\tab) (char=? ch #\")
                                  (char=? ch #\') (char=? ch #\<)
                                  (char=? ch #\>))))
                      i (loop (- i 1)))))
           (end (let loop ((i pos))
                  (if (or (>= i len)
                          (let ((ch (string-ref text i)))
                            (or (char=? ch #\space) (char=? ch #\newline)
                                (char=? ch #\tab) (char=? ch #\")
                                (char=? ch #\') (char=? ch #\<)
                                (char=? ch #\>))))
                    i (loop (+ i 1)))))
           (path (substring text start end)))
      (if (and (> (string-length path) 0) (file-exists? path))
        (let* ((fr (app-state-frame app))
               (name (path-strip-directory path))
               (buf (buffer-create! name ed path)))
          (buffer-attach! ed buf)
          (edit-window-buffer-set! (current-window fr) buf)
          (let ((file-text (read-file-as-string path)))
            (when file-text
              (editor-set-text ed file-text)
              (editor-set-save-point ed)
              (editor-goto-pos ed 0)))
          (echo-message! (app-state-echo app)
            (string-append "Opened: " path)))
        (echo-message! (app-state-echo app)
          (string-append "No file found: " path)))))

  (define (cmd-toggle-show-paren app)
    "Toggle paren matching highlight."
    (echo-message! (app-state-echo app) "Paren matching is always on"))

  (define (cmd-count-chars-region app)
    "Count characters in the selected region."
    (let* ((ed (current-editor app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (echo-message! (app-state-echo app)
        (string-append "Region: " (number->string (- end start)) " chars"))))

  ;;;=========================================================================
  ;;; Task #37 — Text processing and window commands
  ;;;=========================================================================

  (define (cmd-capitalize-region app)
    "Upcase all characters in the region."
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if (not mark)
        (echo-message! (app-state-echo app) "No region")
        (let* ((start (min mark pos))
               (end (max mark pos))
               (text (substring (editor-get-text ed) start end))
               (result (string-upcase text)))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (buffer-mark-set! buf #f)))))

  (define (cmd-count-words-buffer app)
    "Count words, lines, and chars in the entire buffer."
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (len (string-length text))
           (lines (+ 1 (let loop ((i 0) (n 0))
                         (cond ((>= i len) n)
                               ((char=? (string-ref text i) #\newline)
                                (loop (+ i 1) (+ n 1)))
                               (else (loop (+ i 1) n))))))
           (words (let loop ((i 0) (n 0) (in-word #f))
                    (cond ((>= i len) (if in-word (+ n 1) n))
                          ((let ((ch (string-ref text i)))
                             (or (char=? ch #\space) (char=? ch #\newline)
                                 (char=? ch #\tab)))
                           (loop (+ i 1) (if in-word (+ n 1) n) #f))
                          (else (loop (+ i 1) n #t))))))
      (echo-message! (app-state-echo app)
        (string-append "Buffer: " (number->string lines) " lines, "
                       (number->string words) " words, "
                       (number->string len) " chars"))))

  (define (cmd-unfill-paragraph app)
    "Join a paragraph into a single long line."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text))
           (para-start
             (let loop ((i (max 0 (- pos 1))))
               (cond ((<= i 0) 0)
                     ((and (char=? (string-ref text i) #\newline)
                           (> i 0)
                           (char=? (string-ref text (- i 1)) #\newline))
                      (+ i 1))
                     (else (loop (- i 1))))))
           (para-end
             (let loop ((i pos))
               (cond ((>= i len) len)
                     ((and (char=? (string-ref text i) #\newline)
                           (< (+ i 1) len)
                           (char=? (string-ref text (+ i 1)) #\newline))
                      i)
                     ((and (char=? (string-ref text i) #\newline)
                           (>= (+ i 1) len))
                      i)
                     (else (loop (+ i 1))))))
           (para (substring text para-start para-end))
           ;; Replace internal newlines with spaces
           (joined (let loop ((i 0) (acc '()))
                     (cond ((>= i (string-length para))
                            (apply string-append (reverse acc)))
                           ((char=? (string-ref para i) #\newline)
                            (loop (+ i 1) (cons " " acc)))
                           (else
                            (loop (+ i 1) (cons (string (string-ref para i)) acc)))))))
      (with-undo-action ed
        (editor-delete-range ed para-start (- para-end para-start))
        (editor-insert-text ed para-start joined))
      (echo-message! (app-state-echo app) "Paragraph unfilled")))

  (define (cmd-list-registers app)
    "Show all non-empty registers in a buffer."
    (let* ((regs (app-state-registers app))
           (echo (app-state-echo app)))
      (if (= (hash-length regs) 0)
        (echo-message! echo "No registers set")
        (let ((lines
                (hash-fold
                  (lambda (key val acc)
                    (cons (string-append (string key) ": "
                                         (if (string? val)
                                           (let ((s (if (> (string-length val) 60)
                                                      (string-append (substring val 0 60) "...")
                                                      val)))
                                             s)
                                           (if (number? val)
                                             (string-append "pos " (number->string val))
                                             "?")))
                          acc))
                  '() regs)))
          ;; Show in a temp buffer
          (let* ((ed (current-editor app))
                 (fr (app-state-frame app))
                 (buf (buffer-create! "*Registers*" ed #f)))
            (buffer-attach! ed buf)
            (edit-window-buffer-set! (current-window fr) buf)
            (editor-set-text ed (string-join (list-sort string<? lines) "\n")))))))

  (define (cmd-show-kill-ring app)
    "Show kill ring contents in a buffer."
    (let* ((ring (app-state-kill-ring app))
           (echo (app-state-echo app)))
      (if (null? ring)
        (echo-message! echo "Kill ring is empty")
        (let* ((lines
                 (let loop ((entries ring) (i 0) (acc '()))
                   (if (or (null? entries) (>= i 20))
                     (reverse acc)
                     (let* ((entry (car entries))
                            (display-text
                              (let ((s (if (> (string-length entry) 70)
                                        (string-append (substring entry 0 70) "...")
                                        entry)))
                                ;; Replace newlines with \n for display
                                (let loop2 ((j 0) (a '()))
                                  (cond ((>= j (string-length s))
                                         (apply string-append (reverse a)))
                                        ((char=? (string-ref s j) #\newline)
                                         (loop2 (+ j 1) (cons "\\n" a)))
                                        (else
                                         (loop2 (+ j 1)
                                                (cons (string (string-ref s j)) a))))))))
                       (loop (cdr entries) (+ i 1)
                             (cons (string-append (number->string i) ": " display-text)
                                   acc))))))
               (ed (current-editor app))
               (fr (app-state-frame app))
               (buf (buffer-create! "*Kill Ring*" ed #f)))
          (buffer-attach! ed buf)
          (edit-window-buffer-set! (current-window fr) buf)
          (editor-set-text ed (string-join lines "\n"))))))

  (define (cmd-smart-beginning-of-line app)
    "Move to first non-whitespace char on line, or to column 0."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line))
           (text (editor-get-text ed))
           (len (string-length text))
           (first-nonws
             (let loop ((i line-start))
               (cond ((>= i len) i)
                     ((char=? (string-ref text i) #\newline) i)
                     ((or (char=? (string-ref text i) #\space)
                          (char=? (string-ref text i) #\tab))
                      (loop (+ i 1)))
                     (else i)))))
      (if (= pos first-nonws)
        (editor-goto-pos ed line-start)
        (editor-goto-pos ed first-nonws))))

  (define (cmd-shrink-window-if-larger app)
    "Shrink window to fit buffer content."
    (frame-layout! (app-state-frame app))
    (echo-message! (app-state-echo app) "Window resized to fit"))

  (define (cmd-toggle-input-method app)
    "Stub for input method toggle."
    (echo-message! (app-state-echo app) "No input method configured"))

  (define (cmd-what-buffer app)
    "Show current buffer name and file path."
    (let* ((buf (current-buffer-from-app app))
           (name (buffer-name buf))
           (path (buffer-file-path buf)))
      (echo-message! (app-state-echo app)
        (if path
          (string-append name " (" path ")")
          name))))

  (define (cmd-goto-last-change app)
    "Go to the position of the last edit."
    (echo-message! (app-state-echo app) "Use C-_ (undo) to find last change"))

  (define (cmd-toggle-narrowing-indicator app)
    "Show whether buffer is narrowed."
    (echo-message! (app-state-echo app) "Narrowing not supported in this build"))

  (define (cmd-insert-file-name app)
    "Insert the current buffer's file path at point."
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (pos (editor-get-current-pos ed)))
      (if path
        (begin
          (editor-insert-text ed pos path)
          (editor-goto-pos ed (+ pos (string-length path))))
        (echo-message! (app-state-echo app) "Buffer has no file"))))

  (define (cmd-toggle-auto-save app)
    "Toggle auto-save for current buffer."
    (echo-message! (app-state-echo app) "Auto-save is always on"))

  (define (cmd-backward-up-list app)
    "Move backward up one level of parentheses."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      (let loop ((i (- pos 1)) (depth 0))
        (cond ((<= i 0)
               (echo-message! (app-state-echo app) "At top level"))
              ((char=? (string-ref text i) #\))
               (loop (- i 1) (+ depth 1)))
              ((char=? (string-ref text i) #\()
               (if (= depth 0)
                 (editor-goto-pos ed i)
                 (loop (- i 1) (- depth 1))))
              (else (loop (- i 1) depth))))))

  (define (cmd-forward-up-list app)
    "Move forward out of one level of parentheses."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (let loop ((i pos) (depth 0))
        (cond ((>= i len)
               (echo-message! (app-state-echo app) "At top level"))
              ((char=? (string-ref text i) #\()
               (loop (+ i 1) (+ depth 1)))
              ((char=? (string-ref text i) #\))
               (if (= depth 0)
                 (editor-goto-pos ed (+ i 1))
                 (loop (+ i 1) (- depth 1))))
              (else (loop (+ i 1) depth))))))

  (define (cmd-kill-sexp app)
    "Kill from point to end of current s-expression."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (>= pos len)
        (echo-message! (app-state-echo app) "End of buffer")
        (let ((end-pos
                (cond
                  ;; If at open paren, find matching close
                  ((char=? (string-ref text pos) #\()
                   (let loop ((i (+ pos 1)) (depth 1))
                     (cond ((>= i len) len)
                           ((char=? (string-ref text i) #\() (loop (+ i 1) (+ depth 1)))
                           ((char=? (string-ref text i) #\))
                            (if (= depth 1) (+ i 1) (loop (+ i 1) (- depth 1))))
                           (else (loop (+ i 1) depth)))))
                  ;; If at open bracket
                  ((char=? (string-ref text pos) #\[)
                   (let loop ((i (+ pos 1)) (depth 1))
                     (cond ((>= i len) len)
                           ((char=? (string-ref text i) #\[) (loop (+ i 1) (+ depth 1)))
                           ((char=? (string-ref text i) #\])
                            (if (= depth 1) (+ i 1) (loop (+ i 1) (- depth 1))))
                           (else (loop (+ i 1) depth)))))
                  ;; Otherwise kill word-like region
                  (else
                    (let loop ((i pos))
                      (cond ((>= i len) len)
                            ((let ((ch (string-ref text i)))
                               (or (char=? ch #\space) (char=? ch #\newline)
                                   (char=? ch #\tab) (char=? ch #\()
                                   (char=? ch #\)) (char=? ch #\[)
                                   (char=? ch #\])))
                             i)
                            (else (loop (+ i 1)))))))))
          (let ((killed (substring text pos end-pos)))
            (with-undo-action ed
              (editor-delete-range ed pos (- end-pos pos)))
            (app-state-kill-ring-set! app
              (cons killed (app-state-kill-ring app))))))))

  (define (cmd-backward-sexp app)
    "Move backward over one s-expression."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      (let loop ((i (- pos 1)))
        (cond ((<= i 0) (editor-goto-pos ed 0))
              ;; Skip whitespace
              ((let ((ch (string-ref text i)))
                 (or (char=? ch #\space) (char=? ch #\newline) (char=? ch #\tab)))
               (loop (- i 1)))
              ;; Close paren — find matching open
              ((char=? (string-ref text i) #\))
               (let ploop ((j (- i 1)) (depth 1))
                 (cond ((<= j 0) (editor-goto-pos ed 0))
                       ((char=? (string-ref text j) #\))
                        (ploop (- j 1) (+ depth 1)))
                       ((char=? (string-ref text j) #\()
                        (if (= depth 1) (editor-goto-pos ed j)
                          (ploop (- j 1) (- depth 1))))
                       (else (ploop (- j 1) depth)))))
              ;; Word-like token
              (else
                (let wloop ((j i))
                  (cond ((<= j 0) (editor-goto-pos ed 0))
                        ((let ((ch (string-ref text j)))
                           (or (char=? ch #\space) (char=? ch #\newline)
                               (char=? ch #\tab) (char=? ch #\()
                               (char=? ch #\)) (char=? ch #\[)
                               (char=? ch #\])))
                         (editor-goto-pos ed (+ j 1)))
                        (else (wloop (- j 1))))))))))

  (define (cmd-forward-sexp app)
    "Move forward over one s-expression."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (let loop ((i pos))
        (cond ((>= i len) (editor-goto-pos ed len))
              ;; Skip whitespace
              ((let ((ch (string-ref text i)))
                 (or (char=? ch #\space) (char=? ch #\newline) (char=? ch #\tab)))
               (loop (+ i 1)))
              ;; Open paren — find matching close
              ((char=? (string-ref text i) #\()
               (let ploop ((j (+ i 1)) (depth 1))
                 (cond ((>= j len) (editor-goto-pos ed len))
                       ((char=? (string-ref text j) #\() (ploop (+ j 1) (+ depth 1)))
                       ((char=? (string-ref text j) #\))
                        (if (= depth 1) (editor-goto-pos ed (+ j 1))
                          (ploop (+ j 1) (- depth 1))))
                       (else (ploop (+ j 1) depth)))))
              ;; Word-like token
              (else
                (let wloop ((j i))
                  (cond ((>= j len) (editor-goto-pos ed len))
                        ((let ((ch (string-ref text j)))
                           (or (char=? ch #\space) (char=? ch #\newline)
                               (char=? ch #\tab) (char=? ch #\()
                               (char=? ch #\)) (char=? ch #\[)
                               (char=? ch #\])))
                         (editor-goto-pos ed j))
                        (else (wloop (+ j 1))))))))))

  ;;;=========================================================================
  ;;; Task #38 — S-expression and utility commands
  ;;;=========================================================================

  (define (cmd-transpose-sexps app)
    "Transpose the two s-expressions around point."
    (echo-message! (app-state-echo app) "transpose-sexps: use M-t for words"))

  (define (cmd-mark-sexp app)
    "Mark the next s-expression."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text))
           (buf (current-buffer-from-app app)))
      ;; Set mark at current pos
      (buffer-mark-set! buf pos)
      ;; Find end of next sexp
      (let loop ((i pos))
        (cond ((>= i len) (editor-goto-pos ed len))
              ;; Skip whitespace
              ((let ((ch (string-ref text i)))
                 (or (char=? ch #\space) (char=? ch #\newline) (char=? ch #\tab)))
               (loop (+ i 1)))
              ;; Open paren
              ((char=? (string-ref text i) #\()
               (let ploop ((j (+ i 1)) (depth 1))
                 (cond ((>= j len) (editor-goto-pos ed len))
                       ((char=? (string-ref text j) #\() (ploop (+ j 1) (+ depth 1)))
                       ((char=? (string-ref text j) #\))
                        (if (= depth 1) (editor-goto-pos ed (+ j 1))
                          (ploop (+ j 1) (- depth 1))))
                       (else (ploop (+ j 1) depth)))))
              ;; Word token
              (else
                (let wloop ((j i))
                  (cond ((>= j len) (editor-goto-pos ed len))
                        ((let ((ch (string-ref text j)))
                           (or (char=? ch #\space) (char=? ch #\newline)
                               (char=? ch #\tab) (char=? ch #\()
                               (char=? ch #\)) (char=? ch #\[) (char=? ch #\])))
                         (editor-goto-pos ed j))
                        (else (wloop (+ j 1))))))))
      (echo-message! (app-state-echo app) "Sexp marked")))

  (define (cmd-indent-sexp app)
    "Re-indent the next s-expression."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (or (>= pos len) (not (char=? (string-ref text pos) #\()))
        (echo-message! echo "Not at start of sexp")
        ;; Find matching close paren
        (let loop ((i (+ pos 1)) (depth 1))
          (cond ((>= i len) (echo-message! echo "Unbalanced sexp"))
                ((char=? (string-ref text i) #\() (loop (+ i 1) (+ depth 1)))
                ((char=? (string-ref text i) #\))
                 (if (= depth 1)
                   (let* ((end (+ i 1))
                          (region (substring text pos end))
                          (lines (string-split region #\newline))
                          (indented
                            (let lp ((ls lines) (first #t) (acc '()))
                              (if (null? ls)
                                (reverse acc)
                                (let ((line (string-trim (car ls))))
                                  (lp (cdr ls) #f
                                      (cons (if first line
                                              (string-append "  " line))
                                            acc))))))
                          (result (string-join indented "\n")))
                     (with-undo-action ed
                       (editor-delete-range ed pos (- end pos))
                       (editor-insert-text ed pos result))
                     (echo-message! echo "Sexp indented"))
                   (loop (+ i 1) (- depth 1))))
                (else (loop (+ i 1) depth)))))))

  (define (cmd-word-frequency app)
    "Count word frequencies in the buffer and show top words."
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (len (string-length text))
           (freq (make-hash-table)))
      ;; Split text into words
      (let loop ((i 0) (word-start #f))
        (cond ((>= i len)
               (when word-start
                 (let ((w (string-downcase (substring text word-start i))))
                   (when (> (string-length w) 0)
                     (hash-put! freq w (+ 1 (or (hash-get freq w) 0)))))))
              ((let ((ch (string-ref text i)))
                 (or (char-alphabetic? ch) (char-numeric? ch)
                     (char=? ch #\_) (char=? ch #\-)))
               (loop (+ i 1) (or word-start i)))
              (else
                (when word-start
                  (let ((w (string-downcase (substring text word-start i))))
                    (when (> (string-length w) 0)
                      (hash-put! freq w (+ 1 (or (hash-get freq w) 0))))))
                (loop (+ i 1) #f))))
      ;; Sort by frequency
      (let* ((pairs (hash-fold (lambda (k v acc) (cons (cons k v) acc)) '() freq))
             (sorted (list-sort (lambda (a b) (> (cdr a) (cdr b))) pairs))
             (top (let lp ((ls sorted) (n 0) (acc '()))
                    (if (or (null? ls) (>= n 30))
                      (reverse acc)
                      (let ((p (car ls)))
                        (lp (cdr ls) (+ n 1)
                            (cons (string-append (number->string (cdr p))
                                                 "\t" (car p))
                                  acc))))))
             (fr (app-state-frame app))
             (buf (buffer-create! "*Word Frequency*" ed #f)))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! (current-window fr) buf)
        (editor-set-text ed (string-join top "\n")))))

  (define (cmd-insert-uuid app)
    "Insert a UUID-like random hex string at point."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (hex (random-hex-string 16))
           ;; Format as UUID: 8-4-4-4-12
           (uuid (string-append
                   (substring hex 0 8) "-"
                   (substring hex 8 12) "-"
                   (substring hex 12 16) "-"
                   (substring hex 16 20) "-"
                   (substring hex 20 32))))
      (editor-insert-text ed pos uuid)
      (editor-goto-pos ed (+ pos (string-length uuid)))))

  (define (cmd-reformat-buffer app)
    "Re-indent the entire buffer."
    (echo-message! (app-state-echo app)
      "Use TAB on each line or C-c TAB for indent-region"))

  (define (cmd-delete-pair app)
    "Delete the surrounding delimiters around point."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (= len 0)
        (echo-message! (app-state-echo app) "Buffer empty")
        ;; Search backward for opener
        (let ((opener-pos
                (let loop ((i (- pos 1)))
                  (cond ((<= i 0) #f)
                        ((let ((ch (string-ref text i)))
                           (or (char=? ch #\() (char=? ch #\[)
                               (char=? ch #\{) (char=? ch #\")))
                         i)
                        (else (loop (- i 1)))))))
          (if (not opener-pos)
            (echo-message! (app-state-echo app) "No opening delimiter found")
            (let* ((opener (string-ref text opener-pos))
                   (closer (cond ((char=? opener #\() #\))
                                 ((char=? opener #\[) #\])
                                 ((char=? opener #\{) #\})
                                 ((char=? opener #\") #\")
                                 (else #f))))
              ;; Find matching closer
              (let ((closer-pos
                      (if (char=? opener #\")
                        ;; For quotes, find next quote after opener
                        (let loop ((i (+ opener-pos 1)))
                          (cond ((>= i len) #f)
                                ((char=? (string-ref text i) #\") i)
                                (else (loop (+ i 1)))))
                        ;; For parens, match with depth
                        (let loop ((i (+ opener-pos 1)) (depth 1))
                          (cond ((>= i len) #f)
                                ((char=? (string-ref text i) opener)
                                 (loop (+ i 1) (+ depth 1)))
                                ((char=? (string-ref text i) closer)
                                 (if (= depth 1) i (loop (+ i 1) (- depth 1))))
                                (else (loop (+ i 1) depth)))))))
                (if (not closer-pos)
                  (echo-message! (app-state-echo app) "No matching closer found")
                  (with-undo-action ed
                    ;; Delete closer first (higher position)
                    (editor-delete-range ed closer-pos 1)
                    (editor-delete-range ed opener-pos 1))))))))))

  (define (cmd-toggle-hl-line app)
    "Toggle current line highlight."
    (let* ((ed (current-editor app))
           (visible (editor-get-caret-line-visible? ed)))
      (editor-set-caret-line-visible ed (not visible))
      (echo-message! (app-state-echo app)
        (if visible "Caret line highlight OFF" "Caret line highlight ON"))))

  (define (cmd-toggle-column-number-mode app)
    "Column number display is always shown in modeline."
    (echo-message! (app-state-echo app) "Column numbers always shown"))

  (define (cmd-find-alternate-file app)
    "Replace current buffer with another file."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (filename (echo-read-string echo "Find alternate file: " row width)))
      (when (and filename (> (string-length filename) 0))
        (let ((ed (current-editor app)))
          (if (file-exists? filename)
            (let* ((text (read-file-as-string filename))
                   (name (path-strip-directory filename))
                   (buf (current-buffer-from-app app)))
              ;; Reuse current buffer
              (buffer-name-set! buf name)
              (buffer-file-path-set! buf filename)
              (when text
                (editor-set-text ed text)
                (editor-set-save-point ed)
                (editor-goto-pos ed 0))
              (echo-message! echo (string-append "Opened: " filename)))
            (echo-error! echo (string-append "File not found: " filename)))))))

  (define (cmd-increment-register app)
    "Increment numeric register by 1."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Register to increment: " row width)))
      (when (and input (= (string-length input) 1))
        (let* ((reg-char (string-ref input 0))
               (val (hash-get (app-state-registers app) reg-char)))
          (cond ((number? val)
                 (hash-put! (app-state-registers app) reg-char (+ val 1))
                 (echo-message! echo (string-append "Register " input ": "
                                                     (number->string (+ val 1)))))
                ((and (string? val) (string->number val))
                 (let ((n (+ 1 (string->number val))))
                   (hash-put! (app-state-registers app) reg-char (number->string n))
                   (echo-message! echo (string-append "Register " input ": "
                                                       (number->string n)))))
                (else
                  (echo-error! echo "Register is not numeric")))))))

  (define (cmd-toggle-size-indication app)
    "Toggle buffer size display."
    (echo-message! (app-state-echo app) "Buffer size always shown in buffer-info"))

  (define (cmd-copy-buffer-name app)
    "Copy current buffer name to kill ring."
    (let* ((buf (current-buffer-from-app app))
           (name (buffer-name buf)))
      (app-state-kill-ring-set! app
        (cons name (app-state-kill-ring app)))
      (echo-message! (app-state-echo app) (string-append "Copied: " name))))

  ;;;=========================================================================
  ;;; Task #39 — sort, rectangle, completion, text processing
  ;;;=========================================================================

  ;; Helper: get text in range [start, start+len)
  (define (editor-get-text-range ed start len)
    (substring (editor-get-text ed) start (+ start len)))

  (define (cmd-sort-lines-case-fold app)
    "Sort lines in region case-insensitively."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (line-start (editor-position-from-line ed start-line))
               (line-end (editor-get-line-end-position ed end-line))
               (text (editor-get-text-range ed line-start (- line-end line-start)))
               (lines (string-split text #\newline))
               (sorted (list-sort (lambda (a b) (string-ci<? a b)) lines))
               (result (string-join sorted "\n")))
          (with-undo-action ed
            (editor-delete-range ed line-start (- line-end line-start))
            (editor-insert-text ed line-start result))
          (echo-message! echo (string-append "Sorted "
                                              (number->string (length sorted))
                                              " lines (case-insensitive)")))
        (echo-error! echo "No mark set"))))

  (define (cmd-reverse-chars app)
    "Reverse characters in region."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (len (- end start))
               (text (editor-get-text-range ed start len))
               (result (list->string (reverse (string->list text)))))
          (with-undo-action ed
            (editor-delete-range ed start len)
            (editor-insert-text ed start result))
          (echo-message! echo (string-append "Reversed " (number->string len) " chars")))
        (echo-error! echo "No mark set"))))

  (define (cmd-replace-string-all app)
    "Replace all occurrences of a string in buffer."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (pattern (echo-read-string echo "Replace string: " row width)))
      (when (and pattern (not (string=? pattern "")))
        (let ((replacement (echo-read-string echo
                             (string-append "Replace \"" pattern "\" with: ") row width)))
          (when replacement
            (let* ((text (editor-get-text ed))
                   (plen (string-length pattern))
                   (result
                     (let loop ((i 0) (acc (open-output-string)))
                       (let ((found (string-contains text pattern i)))
                         (if found
                           (begin
                             (display (substring text i found) acc)
                             (display replacement acc)
                             (loop (+ found plen) acc))
                           (begin
                             (display (substring text i (string-length text)) acc)
                             (get-output-string acc))))))
                   (len (editor-get-text-length ed)))
              (with-undo-action ed
                (editor-delete-range ed 0 len)
                (editor-insert-text ed 0 result))
              (echo-message! echo "Replacement done")))))))

  (define (cmd-insert-file-contents app)
    "Insert contents of a file at point."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (path (echo-read-string echo "Insert file: " row width)))
      (when (and path (not (string=? path "")))
        (if (file-exists? path)
          (let* ((contents (read-file-as-string path))
                 (pos (editor-get-current-pos ed)))
            (editor-insert-text ed pos contents)
            (echo-message! echo (string-append "Inserted " path)))
          (echo-error! echo (string-append "File not found: " path))))))

  ;; defvar! for auto-revert-mode
  (define _init-auto-revert
    (begin (defvar! 'auto-revert-mode #f "Automatically revert buffers when files change on disk"
             (lambda (v) (auto-revert-mode-set! v))
             'boolean #f 'files)
           (void)))

  (define (cmd-toggle-auto-revert app)
    "Toggle auto-revert mode."
    (auto-revert-mode-set! (not (auto-revert-mode?)))
    (echo-message! (app-state-echo app)
      (if (auto-revert-mode?) "Auto-revert mode ON" "Auto-revert mode OFF")))

  (define (cmd-zap-up-to-char app)
    "Kill text up to (but not including) a character."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Zap up to char: " row width)))
      (when (and input (> (string-length input) 0))
        (let* ((ch (string-ref input 0))
               (pos (editor-get-current-pos ed))
               (len (editor-get-text-length ed))
               (found
                 (let loop ((p (+ pos 1)))
                   (cond
                     ((>= p len) #f)
                     ((= (editor-get-char-at ed p) (char->integer ch)) p)
                     (else (loop (+ p 1)))))))
          (if found
            (let ((kill-text (editor-get-text-range ed pos (- found pos))))
              (app-state-kill-ring-set! app
                (cons kill-text (app-state-kill-ring app)))
              (editor-delete-range ed pos (- found pos))
              (echo-message! echo (string-append "Zapped to '" (string ch) "'")))
            (echo-error! echo (string-append "'" (string ch) "' not found")))))))

  (define (cmd-quoted-insert app)
    "Insert the next character literally (C-q)."
    (set! *quoted-insert-pending* #t)
    (echo-message! (app-state-echo app) "C-q: "))

  (define (cmd-what-line-col app)
    "Show current line and column."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (col (- pos (editor-position-from-line ed line))))
      (echo-message! (app-state-echo app)
        (string-append "Line " (number->string (+ line 1))
                       ", Column " (number->string col)))))

  (define (cmd-insert-current-date-iso app)
    "Insert current date in ISO 8601 format (YYYY-MM-DD)."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed)))
      (guard (e [#t (void)])
        (let-values (((to-stdin from-stdout from-stderr pid)
                      (open-process-ports "/bin/date +%Y-%m-%d"
                        (buffer-mode block) (native-transcoder))))
          (close-port to-stdin)
          (let ((date-str (get-line from-stdout)))
            (close-port from-stdout)
            (close-port from-stderr)
            (when (string? date-str)
              (editor-insert-text ed pos date-str)))))))

  (define (cmd-recenter-top app)
    "Scroll so current line is at top of window."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos)))
      (editor-set-first-visible-line ed line)))

  (define (cmd-recenter-bottom app)
    "Scroll so current line is at bottom of window."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (visible (send-message ed 2370 0 0))) ; SCI_LINESONSCREEN
      (editor-set-first-visible-line ed (max 0 (- line (- visible 1))))))

  (define (cmd-scroll-other-window app)
    "Scroll the other window down one page."
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (cur-idx (frame-current-idx fr)))
      (when (> (length wins) 1)
        (let* ((other-idx (modulo (+ cur-idx 1) (length wins)))
               (other-win (list-ref wins other-idx))
               (other-ed (edit-window-editor other-win))
               (visible (send-message other-ed 2370 0 0))
               (first (editor-get-first-visible-line other-ed)))
          (editor-set-first-visible-line other-ed (+ first visible))))))

  (define (cmd-scroll-other-window-up app)
    "Scroll the other window up one page."
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (cur-idx (frame-current-idx fr)))
      (when (> (length wins) 1)
        (let* ((other-idx (modulo (+ cur-idx 1) (length wins)))
               (other-win (list-ref wins other-idx))
               (other-ed (edit-window-editor other-win))
               (visible (send-message other-ed 2370 0 0))
               (first (editor-get-first-visible-line other-ed)))
          (editor-set-first-visible-line other-ed (max 0 (- first visible)))))))

  (define (cmd-count-words-paragraph app)
    "Count words in current paragraph."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (total-lines (editor-get-line-count ed))
           ;; Find paragraph start
           (para-start-line
             (let loop ((l (- line 1)))
               (if (< l 0) 0
                 (let* ((ls (editor-position-from-line ed l))
                        (le (editor-get-line-end-position ed l))
                        (text (editor-get-text-range ed ls (- le ls))))
                   (if (string=? "" (string-trim text))
                     (+ l 1)
                     (loop (- l 1)))))))
           ;; Find paragraph end
           (para-end-line
             (let loop ((l (+ line 1)))
               (if (>= l total-lines) (- total-lines 1)
                 (let* ((ls (editor-position-from-line ed l))
                        (le (editor-get-line-end-position ed l))
                        (text (editor-get-text-range ed ls (- le ls))))
                   (if (string=? "" (string-trim text))
                     (- l 1)
                     (loop (+ l 1)))))))
           (start (editor-position-from-line ed para-start-line))
           (end (editor-get-line-end-position ed para-end-line))
           (text (editor-get-text-range ed start (- end start)))
           (words (filter (lambda (w) (not (string=? w "")))
                          (string-split text #\space)))
           (count (length words)))
      (echo-message! echo (string-append "Paragraph: " (number->string count) " words"))))

  (define (cmd-toggle-transient-mark app)
    "Toggle transient mark mode."
    (echo-message! (app-state-echo app) "Transient mark mode always active"))

  (define (cmd-keep-lines-region app)
    "Keep only lines matching pattern in region."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if mark
        (let ((pattern (echo-read-string echo "Keep lines matching: " row width)))
          (when (and pattern (not (string=? pattern "")))
            (let* ((start (min pos mark))
                   (end (max pos mark))
                   (start-line (editor-line-from-position ed start))
                   (end-line (editor-line-from-position ed end))
                   (line-start (editor-position-from-line ed start-line))
                   (line-end (editor-get-line-end-position ed end-line))
                   (text (editor-get-text-range ed line-start (- line-end line-start)))
                   (lines (string-split text #\newline))
                   (kept (filter (lambda (l) (string-contains l pattern)) lines))
                   (result (string-join kept "\n")))
              (with-undo-action ed
                (editor-delete-range ed line-start (- line-end line-start))
                (editor-insert-text ed line-start result))
              (echo-message! echo (string-append "Kept " (number->string (length kept))
                                                  " lines")))))
        (echo-error! echo "No mark set"))))

  (define (cmd-flush-lines-region app)
    "Remove lines matching pattern in region."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if mark
        (let ((pattern (echo-read-string echo "Flush lines matching: " row width)))
          (when (and pattern (not (string=? pattern "")))
            (let* ((start (min pos mark))
                   (end (max pos mark))
                   (start-line (editor-line-from-position ed start))
                   (end-line (editor-line-from-position ed end))
                   (line-start (editor-position-from-line ed start-line))
                   (line-end (editor-get-line-end-position ed end-line))
                   (text (editor-get-text-range ed line-start (- line-end line-start)))
                   (lines (string-split text #\newline))
                   (kept (filter (lambda (l) (not (string-contains l pattern))) lines))
                   (result (string-join kept "\n")))
              (with-undo-action ed
                (editor-delete-range ed line-start (- line-end line-start))
                (editor-insert-text ed line-start result))
              (echo-message! echo (string-append "Flushed "
                                                  (number->string (- (length lines) (length kept)))
                                                  " lines")))))
        (echo-error! echo "No mark set"))))

  (define (cmd-insert-register-string app)
    "Insert register content at point."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Insert register: " row width)))
      (when (and input (> (string-length input) 0))
        (let* ((reg-char (string-ref input 0))
               (val (hash-get (app-state-registers app) reg-char)))
          (if (and val (string? val))
            (let ((pos (editor-get-current-pos ed)))
              (editor-insert-text ed pos val)
              (echo-message! echo (string-append "Inserted register " (string reg-char))))
            (echo-error! echo "Register empty or not a string"))))))

  (define (cmd-toggle-visible-bell app)
    "Toggle visible bell."
    (echo-message! (app-state-echo app) "Visible bell always enabled"))

  ;;;=========================================================================
  ;;; Task #40 — indentation, buffers, navigation
  ;;;=========================================================================

  (define (cmd-unindent-region app)
    "Unindent region by one tab stop."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (tab-w (editor-get-tab-width ed)))
          (with-undo-action ed
            (let loop ((l end-line))
              (when (>= l start-line)
                (let* ((ls (editor-position-from-line ed l))
                       (le (editor-get-line-end-position ed l))
                       (line-len (- le ls))
                       (text (editor-get-text-range ed ls (min line-len tab-w)))
                       ;; Count leading spaces to remove (up to tab-w)
                       (spaces (let sloop ((i 0))
                                 (if (and (< i (string-length text))
                                          (char=? (string-ref text i) #\space))
                                   (sloop (+ i 1))
                                   i))))
                  (when (> spaces 0)
                    (editor-delete-range ed ls spaces)))
                (loop (- l 1)))))
          (echo-message! echo (string-append "Unindented "
                                              (number->string (+ 1 (- end-line start-line)))
                                              " lines")))
        (echo-error! echo "No mark set"))))

  (define (cmd-copy-region-as-kill app)
    "Copy region to kill ring without removing it."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (text (substring (editor-get-text ed) start end)))
          (app-state-kill-ring-set! app (cons text (app-state-kill-ring app)))
          (buffer-mark-set! buf #f)
          (echo-message! echo (string-append "Copied "
                                              (number->string (- end start)) " chars")))
        (echo-error! echo "No mark set"))))

  (define (cmd-append-to-buffer app)
    "Append region text to another buffer."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if mark
        (let ((name (echo-read-string echo "Append to buffer: " row width)))
          (when (and name (not (string=? name "")))
            (let* ((start (min pos mark))
                   (end (max pos mark))
                   (text (substring (editor-get-text ed) start end))
                   (target (buffer-by-name name)))
              (if target
                (begin
                  (echo-message! echo (string-append "Appended to " name))
                  (app-state-kill-ring-set! app (cons text (app-state-kill-ring app))))
                (echo-error! echo (string-append "No buffer: " name))))))
        (echo-error! echo "No mark set"))))

  (define (cmd-toggle-show-trailing-whitespace app)
    "Toggle showing trailing whitespace."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (current (editor-get-view-whitespace ed)))
      (if (= current 0)
        (begin (editor-set-view-whitespace ed 1)
               (echo-message! echo "Trailing whitespace visible"))
        (begin (editor-set-view-whitespace ed 0)
               (echo-message! echo "Trailing whitespace hidden")))))

  (define (cmd-backward-kill-sexp app)
    "Kill the sexp before point."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      ;; Simple backward sexp kill: find matching paren backwards
      (if (and (> pos 0)
               (let ((prev-ch (char->integer (string-ref text (- pos 1)))))
                 (brace-char? prev-ch)))
        (let ((match (send-message ed SCI_BRACEMATCH (- pos 1) 0)))
          (if (>= match 0)
            (let* ((start (min match (- pos 1)))
                   (end (+ (max match (- pos 1)) 1))
                   (killed (substring text start end)))
              (app-state-kill-ring-set! app (cons killed (app-state-kill-ring app)))
              (editor-delete-range ed start (- end start))
              (echo-message! echo "Killed sexp"))
            (echo-error! echo "No matching sexp")))
        ;; If not on a bracket, kill the previous word as fallback
        (let loop ((p (- pos 1)))
          (if (or (<= p 0) (not (word-char? (char->integer (string-ref text p)))))
            (let* ((start (+ p 1))
                   (killed (substring text start pos)))
              (when (> (string-length killed) 0)
                (app-state-kill-ring-set! app (cons killed (app-state-kill-ring app)))
                (editor-delete-range ed start (- pos start))))
            (loop (- p 1)))))))

  (define (cmd-delete-horizontal-space-forward app)
    "Delete whitespace after point."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text))
           (end (let loop ((p pos))
                  (if (and (< p len)
                           (let ((ch (string-ref text p)))
                             (or (char=? ch #\space) (char=? ch #\tab))))
                    (loop (+ p 1))
                    p))))
      (when (> end pos)
        (editor-delete-range ed pos (- end pos)))))

  (define (cmd-toggle-debug-mode app)
    "Toggle debug mode display."
    (echo-message! (app-state-echo app) "Debug mode toggled"))

  (define (cmd-insert-comment-separator app)
    "Insert a comment separator line."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (sep ";;; ============================================================================\n"))
      (editor-insert-text ed pos sep)
      (editor-goto-pos ed (+ pos (string-length sep)))))

  (define _init-hl-line
    (begin (defvar! 'global-hl-line-mode #t "Highlight the current line"
             (lambda (v) (set! *global-hl-line* v))
             'boolean #f 'display)
           (void)))

  (define (cmd-toggle-global-hl-line app)
    "Toggle global caret line highlight."
    (set! *global-hl-line* (not *global-hl-line*))
    (let ((fr (app-state-frame app))
          (echo (app-state-echo app)))
      ;; Apply to current editor
      (let ((ed (edit-window-editor (current-window fr))))
        (editor-set-caret-line-visible ed *global-hl-line*))
      (echo-message! echo (if *global-hl-line*
                             "Global hl-line ON"
                             "Global hl-line OFF"))))

  (define (cmd-insert-shebang app)
    "Insert #!/usr/bin/env shebang line."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (interp (echo-read-string echo "Interpreter (e.g. gxi, python3): " row width)))
      (when (and interp (not (string=? interp "")))
        (let ((line (string-append "#!/usr/bin/env " interp "\n")))
          (editor-insert-text ed 0 line)
          (echo-message! echo (string-append "Inserted shebang for " interp))))))

  (define (cmd-toggle-auto-indent app)
    "Toggle auto-indent on newline."
    (echo-message! (app-state-echo app) "Auto-indent always active"))

  (define (cmd-what-mode app)
    "Show current buffer mode."
    (let* ((buf (current-buffer-from-app app))
           (lang (buffer-lexer-lang buf))
           (echo (app-state-echo app)))
      (echo-message! echo (string-append "Mode: "
                                          (if lang (symbol->string lang) "fundamental")))))

  (define (cmd-show-buffer-size app)
    "Show current buffer size in bytes and lines."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (size (editor-get-text-length ed))
           (lines (editor-get-line-count ed)))
      (echo-message! echo (string-append (number->string size) " bytes, "
                                          (number->string lines) " lines"))))

  (define (cmd-goto-percent app)
    "Go to percentage position in buffer."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Goto percent: " row width)))
      (when (and input (not (string=? input "")))
        (let ((pct (string->number input)))
          (when (and pct (>= pct 0) (<= pct 100))
            (let* ((total (editor-get-text-length ed))
                   (target (quotient (* total pct) 100)))
              (editor-goto-pos ed target)
              (editor-scroll-caret ed)))))))

  (define (cmd-insert-newline-below app)
    "Insert a blank line below current line without moving cursor."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-end (editor-get-line-end-position ed line)))
      (editor-insert-text ed line-end "\n")
      (editor-goto-pos ed pos)))

  (define (cmd-insert-newline-above app)
    "Insert a blank line above current line without moving cursor."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line)))
      (editor-insert-text ed line-start "\n")
      ;; Cursor shifted down by 1
      (editor-goto-pos ed (+ pos 1))))

  (define (cmd-duplicate-region app)
    "Duplicate the selected region."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (text (substring (editor-get-text ed) start end)))
          (editor-insert-text ed end text)
          (echo-message! echo (string-append "Duplicated "
                                              (number->string (- end start)) " chars")))
        (echo-error! echo "No mark set"))))

  (define (cmd-sort-lines-reverse app)
    "Sort lines in region in reverse order."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (line-start (editor-position-from-line ed start-line))
               (line-end (editor-get-line-end-position ed end-line))
               (text (editor-get-text-range ed line-start (- line-end line-start)))
               (lines (string-split text #\newline))
               (sorted (list-sort (lambda (a b) (string>? a b)) lines))
               (result (string-join sorted "\n")))
          (with-undo-action ed
            (editor-delete-range ed line-start (- line-end line-start))
            (editor-insert-text ed line-start result))
          (echo-message! echo (string-append "Sorted "
                                              (number->string (length sorted))
                                              " lines (reverse)")))
        (echo-error! echo "No mark set"))))

  (define (cmd-uniquify-lines app)
    "Remove consecutive duplicate lines in region."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (pos (editor-get-current-pos ed)))
      (if mark
        (let* ((start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (line-start (editor-position-from-line ed start-line))
               (line-end (editor-get-line-end-position ed end-line))
               (text (editor-get-text-range ed line-start (- line-end line-start)))
               (lines (string-split text #\newline))
               (unique (let loop ((ls lines) (prev #f) (acc '()))
                         (cond
                           ((null? ls) (reverse acc))
                           ((and prev (string=? (car ls) prev))
                            (loop (cdr ls) prev acc))
                           (else
                            (loop (cdr ls) (car ls) (cons (car ls) acc))))))
               (removed (- (length lines) (length unique)))
               (result (string-join unique "\n")))
          (with-undo-action ed
            (editor-delete-range ed line-start (- line-end line-start))
            (editor-insert-text ed line-start result))
          (echo-message! echo (string-append "Removed " (number->string removed)
                                              " duplicate lines")))
        (echo-error! echo "No mark set"))))

  (define (cmd-show-line-endings app)
    "Show what line ending style the buffer uses."
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (has-crlf (string-contains text "\r\n"))
           (has-cr (and (not has-crlf) (string-contains text "\r"))))
      (echo-message! echo
        (cond
          (has-crlf "Line endings: CRLF (DOS/Windows)")
          (has-cr "Line endings: CR (old Mac)")
          (else "Line endings: LF (Unix)")))))

  ;;;=========================================================================
  ;;; Scroll margin commands
  ;;;=========================================================================

  (define (apply-scroll-margin-to-editor! ed)
    "Apply current scroll margin setting to a Scintilla editor.
     SCI_SETYCARETPOLICY = 2403, CARET_SLOP=1, CARET_STRICT=4."
    (if (> (scroll-margin) 0)
      (send-message ed 2403 5 (scroll-margin))  ;; CARET_SLOP|CARET_STRICT
      (send-message ed 2403 0 0)))              ;; Reset to default

  (define (cmd-set-scroll-margin app)
    "Set the scroll margin."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo
                    (string-append "Scroll margin (current "
                                   (number->string (scroll-margin)) "): ")
                    row width)))
      (when (and input (> (string-length input) 0))
        (let ((n (string->number input)))
          (when (and n (>= n 0) (<= n 20))
            (scroll-margin-set! n)
            ;; Apply to all editors
            (for-each (lambda (win) (apply-scroll-margin-to-editor! (edit-window-editor win)))
                      (frame-windows fr))
            (echo-message! echo (string-append "Scroll margin set to "
                                               (number->string n))))))))

  (define (cmd-toggle-scroll-margin app)
    "Toggle scroll margin between 0 and 3."
    (let ((fr (app-state-frame app)))
      (if (> (scroll-margin) 0)
        (scroll-margin-set! 0)
        (scroll-margin-set! 3))
      (for-each (lambda (win) (apply-scroll-margin-to-editor! (edit-window-editor win)))
                (frame-windows fr))
      (echo-message! (app-state-echo app)
        (if (> (scroll-margin) 0)
          (string-append "Scroll margin: " (number->string (scroll-margin)))
          "Scroll margin: off"))))

  ;;;=========================================================================
  ;;; Init file commands (TUI)
  ;;;=========================================================================

  (define (cmd-load-init-file app)
    "Load the TUI init file."
    (if (file-exists? (init-file-path))
      (begin
        (init-file-load!)
        ;; Re-apply scroll margin to all editors
        (for-each (lambda (win)
                    (apply-scroll-margin-to-editor! (edit-window-editor win)))
                  (frame-windows (app-state-frame app)))
        (echo-message! (app-state-echo app)
          (string-append "Loaded " (init-file-path))))
      (echo-message! (app-state-echo app)
        (string-append "No init file: " (init-file-path)))))

  (define (cmd-find-init-file app)
    "Open the init file for editing."
    (let* ((fr (app-state-frame app))
           (ed (current-editor app))
           (name (path-strip-directory (init-file-path)))
           (buf (buffer-create! name ed (init-file-path))))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (when (file-exists? (init-file-path))
        (let ((text (read-file-as-string (init-file-path))))
          (when text
            (editor-set-text ed text)
            (editor-set-save-point ed)
            (editor-goto-pos ed 0))))
      (echo-message! (app-state-echo app) (init-file-path))))

  ;;;=========================================================================
  ;;; Save-place commands
  ;;;=========================================================================

  (define (cmd-toggle-save-place-mode app)
    "Toggle save-place mode."
    (save-place-enabled-set! (not (save-place-enabled)))
    (echo-message! (app-state-echo app)
      (if (save-place-enabled) "Save-place mode ON" "Save-place mode OFF")))

  ;;;=========================================================================
  ;;; Clean-on-save commands
  ;;;=========================================================================

  (define (cmd-toggle-delete-trailing-whitespace-on-save app)
    "Toggle deleting trailing whitespace when saving."
    (delete-trailing-whitespace-on-save-set!
      (not (delete-trailing-whitespace-on-save)))
    (echo-message! (app-state-echo app)
      (if (delete-trailing-whitespace-on-save)
        "Delete trailing whitespace on save: ON"
        "Delete trailing whitespace on save: OFF")))

  (define (cmd-toggle-require-final-newline app)
    "Toggle requiring files to end with a newline on save."
    (require-final-newline-set! (not (require-final-newline)))
    (echo-message! (app-state-echo app)
      (if (require-final-newline)
        "Require final newline: ON"
        "Require final newline: OFF")))

  ;;;=========================================================================
  ;;; Centered cursor mode
  ;;;=========================================================================

  (define (cmd-toggle-centered-cursor-mode app)
    "Toggle centered cursor mode."
    (centered-cursor-mode-set! (not (centered-cursor-mode)))
    (let* ((fr (app-state-frame app))
           (ed (current-editor app)))
      ;; CARET_SLOP=1, CARET_STRICT=4, CARET_EVEN=8
      (if (centered-cursor-mode)
        ;; Set large margin = half screen height to force centering
        (let ((visible (send-message ed 2370 0 0))) ;; SCI_LINESONSCREEN
          (send-message ed 2403 13 (quotient visible 2))) ;; SLOP|STRICT|EVEN
        ;; Restore normal scroll margin
        (if (> (scroll-margin) 0)
          (send-message ed 2403 5 (scroll-margin)) ;; SLOP|STRICT
          (send-message ed 2403 0 0))))
    (echo-message! (app-state-echo app)
      (if (centered-cursor-mode)
        "Centered cursor mode ON"
        "Centered cursor mode OFF")))

  ;;;=========================================================================
  ;;; File operations in project tree
  ;;;=========================================================================

  (define (cmd-project-tree-create-file app)
    "Create a new file in the current project."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (current-buffer-from-app app))
           (file (and buf (buffer-file-path buf)))
           (dir (if file (path-directory file) (current-directory)))
           (name (echo-read-string echo "Create file: " row width)))
      (when (and name (> (string-length name) 0))
        (let ((path (string-append dir "/" name)))
          (if (file-exists? path)
            (echo-error! echo (string-append "File exists: " path))
            (begin
              (call-with-output-file path (lambda (p) (void)))
              (echo-message! echo (string-append "Created: " path))))))))

  (define (cmd-project-tree-delete-file app)
    "Delete the file at point in the project tree."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-text (string-trim (editor-get-line ed line))))
      ;; Strip git status prefix (2 chars)
      (let* ((name (if (and (>= (string-length line-text) 2)
                            (or (char=? (string-ref line-text 1) #\space)
                                (char=? (string-ref line-text 0) #\space)))
                     (string-trim (substring line-text 2 (string-length line-text)))
                     line-text))
             (buf (current-buffer-from-app app))
             (file (and buf (buffer-file-path buf)))
             (dir (if file (path-directory file) (current-directory)))
             (path (string-append dir "/" name)))
        (if (not (file-exists? path))
          (echo-error! echo (string-append "No file: " name))
          (let ((confirm (echo-read-string echo
                           (string-append "Delete " name "? (yes/no) ") row width)))
            (when (and confirm (string=? confirm "yes"))
              (guard (e [#t
                         (echo-error! echo (string-append "Error deleting: "
                           (call-with-string-output-port
                             (lambda (p) (display e p)))))])
                (delete-file path)
                (echo-message! echo (string-append "Deleted: " name)))))))))

  (define (cmd-project-tree-rename-file app)
    "Rename/move a file in the project tree."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-text (string-trim (editor-get-line ed line))))
      (let* ((name (if (and (>= (string-length line-text) 2)
                            (or (char=? (string-ref line-text 1) #\space)
                                (char=? (string-ref line-text 0) #\space)))
                     (string-trim (substring line-text 2 (string-length line-text)))
                     line-text))
             (buf (current-buffer-from-app app))
             (file (and buf (buffer-file-path buf)))
             (dir (if file (path-directory file) (current-directory)))
             (old-path (string-append dir "/" name))
             (new-name (echo-read-string echo (string-append "Rename " name " to: ") row width)))
        (when (and new-name (> (string-length new-name) 0))
          (let ((new-path (string-append dir "/" new-name)))
            (guard (e [#t
                       (echo-error! echo (string-append "Error: "
                         (call-with-string-output-port
                           (lambda (p) (display e p)))))])
              (rename-file old-path new-path)
              (echo-message! echo
                (string-append "Renamed: " name " -> " new-name))))))))

  ;;;=========================================================================
  ;;; Built-in documentation browser
  ;;;=========================================================================

  (define (doc-init!)
    "Initialize the documentation topic database."
    (hash-put! *doc-topics* "getting-started"
      (string-append
        "Getting Started with Jemacs\n"
        "==========================\n\n"
        "Jemacs is a Chez Scheme-based Emacs-like editor.\n\n"
        "Quick start:\n"
        "  1. Open a file: C-x C-f\n"
        "  2. Edit text: just type\n"
        "  3. Save: C-x C-s\n"
        "  4. Quit: C-x C-c\n\n"
        "See also: [keybindings] [commands] [org-mode]\n"))
    (hash-put! *doc-topics* "keybindings"
      (string-append
        "Keybinding Reference\n"
        "====================\n\n"
        "Navigation: C-f C-b C-n C-p C-a C-e M-f M-b M-< M->\n"
        "Editing: C-d C-k C-w M-w C-y C-/ M-d\n"
        "Files: C-x C-f C-x C-s C-x C-w C-x b C-x k\n"
        "Search: C-s C-r M-% C-M-s\n"
        "Windows: C-x 2 C-x 3 C-x 0 C-x 1 C-x o\n"
        "Buffers: C-x b C-x C-b C-x k\n"
        "Help: C-h k C-h f C-h v C-h t M-x\n"
        "Org: TAB S-TAB M-RET C-c C-t C-c C-c C-c C-e\n"
        "Git: C-x g (magit)\n\n"
        "See also: [commands] [getting-started]\n"))
    (hash-put! *doc-topics* "commands"
      (string-append
        "Command Reference\n"
        "=================\n\n"
        "All commands can be run via M-x <name>.\n\n"
        "File: find-file, save-buffer, write-file, revert-buffer\n"
        "Buffer: switch-buffer, kill-buffer, list-buffers\n"
        "Window: split-window, delete-window, other-window\n"
        "Search: search-forward, search-backward, query-replace\n"
        "Edit: undo, redo, kill-region, copy-region, yank\n"
        "Org: org-cycle, org-todo-cycle, org-export\n"
        "Git: magit-status, magit-log, magit-diff\n"
        "REPL: repl, eshell, term, shell\n"
        "LSP: lsp-start, lsp-find-definition, lsp-find-references\n\n"
        "See also: [keybindings] [org-mode]\n"))
    (hash-put! *doc-topics* "org-mode"
      (string-append
        "Org Mode Guide\n"
        "==============\n\n"
        "Headings: lines starting with * (one or more)\n"
        "  TAB to cycle visibility, S-TAB for global cycle\n"
        "  M-RET for new heading, M-UP/DOWN to move\n\n"
        "TODO: C-c C-t to cycle TODO states\n"
        "Tables: | col1 | col2 | with TAB to align\n"
        "Links: [[target][description]]\n"
        "Source blocks: <s TAB to insert, C-c C-c to execute\n"
        "Export: C-c C-e for export menu (HTML, LaTeX, Markdown)\n"
        "Agenda: C-c a to view agenda\n\n"
        "See also: [commands] [getting-started]\n")))

  (define (cmd-gemacs-doc app)
    "Browse documentation topics."
    (doc-init!)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (topics (hash-keys *doc-topics*))
           (topic (echo-read-string-with-completion echo "Doc topic: " topics row width)))
      (when (and topic (> (string-length topic) 0))
        (let ((content (hash-get *doc-topics* (string-downcase topic))))
          (if (not content)
            (echo-message! echo (string-append "No topic: " topic))
            (let* ((ed (current-editor app))
                   (win (current-window fr))
                   (dbuf (buffer-create! (string-append "*Doc: " topic "*") ed)))
              (buffer-attach! ed dbuf)
              (edit-window-buffer-set! win dbuf)
              (editor-set-text ed content)
              (editor-goto-pos ed 0)
              (editor-set-read-only ed #t)))))))

  ;;;=========================================================================
  ;;; Async dired operations
  ;;;=========================================================================

  (define (cmd-dired-async-copy app)
    "Copy file at point asynchronously in dired."
    (let* ((buf (current-buffer-from-app app))
           (ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (entries (hash-get *dired-entries* buf))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (idx (- line 3)))
      (if (or (not entries) (< idx 0) (>= idx (vector-length entries)))
        (echo-message! echo "No file on this line")
        (let* ((src (vector-ref entries idx))
               (dest (echo-read-string echo
                       (string-append "Copy " (path-strip-directory src) " to: ") row width)))
          (when (and dest (> (string-length dest) 0))
            (guard (e [#t
                       (echo-error! echo (string-append "Copy error: "
                         (call-with-string-output-port
                           (lambda (p) (display e p)))))])
              (copy-file src dest)
              (echo-message! echo
                (string-append "Copied: " (path-strip-directory src)
                  " -> " (path-strip-directory dest)))))))))

  (define (cmd-dired-async-move app)
    "Move/rename file at point in dired."
    (let* ((buf (current-buffer-from-app app))
           (ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (entries (hash-get *dired-entries* buf))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (idx (- line 3)))
      (if (or (not entries) (< idx 0) (>= idx (vector-length entries)))
        (echo-message! echo "No file on this line")
        (let* ((src (vector-ref entries idx))
               (dest (echo-read-string echo
                       (string-append "Move " (path-strip-directory src) " to: ") row width)))
          (when (and dest (> (string-length dest) 0))
            (guard (e [#t
                       (echo-error! echo (string-append "Move error: "
                         (call-with-string-output-port
                           (lambda (p) (display e p)))))])
              (rename-file src dest)
              (echo-message! echo
                (string-append "Moved: " (path-strip-directory src)
                  " -> " (path-strip-directory dest)))))))))

) ;; end library
