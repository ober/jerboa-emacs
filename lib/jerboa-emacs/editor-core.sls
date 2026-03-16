#!chezscheme
;;; editor-core.sls — Core editor commands for jemacs
;;;
;;; Ported from gerbil-emacs/editor-core.ss to R6RS Chez Scheme.
;;; Pulse highlight, clipboard, uniquify, EOL detection, file mod tracking,
;;; auto-save, accessors, self-insert, navigation, editing, kill/yank,
;;; mark/region, file operations, buffer/window commands, search,
;;; eshell/shell/chat/terminal/REPL commands, dired, info reader, git status.

(library (jerboa-emacs editor-core)
  (export
    ;; Shared state
    auto-pair-mode? auto-pair-mode-set!
    auto-revert-mode? auto-revert-mode-set!

    ;; Pulse/flash highlight
    pulse-line! pulse-tick! pulse-clear!

    ;; System clipboard
    clipboard-set! clipboard-get

    ;; Uniquify buffer name
    uniquify-buffer-name

    ;; EOL detection
    detect-eol-mode

    ;; File modification tracking and auto-save
    update-buffer-mod-time!
    auto-save-buffers!
    check-file-modifications!
    auto-save-enabled? auto-save-enabled-set!

    ;; Accessors
    current-editor
    current-buffer-from-app
    app-read-string
    editor-replace-selection
    make-auto-save-path

    ;; Self-insert
    auto-pair-char electric-pair-char electric-pair-closing?
    auto-pair-closing? paredit-delimiter?
    paredit-strict-allow-delete?
    cmd-self-insert!

    ;; Auto-fill
    tui-auto-fill-after-insert!

    ;; Navigation
    update-mark-region!
    collapse-selection-to-caret!
    cmd-forward-char cmd-backward-char
    tui-eshell-on-input-line?
    tui-eshell-current-input
    tui-eshell-replace-input!
    cmd-next-line cmd-previous-line
    cmd-beginning-of-line cmd-end-of-line
    cmd-forward-word cmd-backward-word
    cmd-beginning-of-buffer cmd-end-of-buffer
    cmd-scroll-down cmd-scroll-up
    cmd-recenter

    ;; Editing
    cmd-delete-char cmd-backward-delete-char
    cmd-backward-delete-char-untabify
    get-line-indent
    buffer-list-buffer?
    cmd-buffer-list-select
    cmd-newline cmd-open-line
    cmd-undo cmd-redo

    ;; Kill / Yank
    cmd-kill-line cmd-yank

    ;; Mark and region
    cmd-set-mark cmd-kill-region cmd-copy-region

    ;; File operations
    expand-filename
    list-directory-files
    cmd-find-file cmd-save-buffer
    cmd-write-file cmd-revert-buffer

    ;; Buffer commands
    cmd-switch-buffer cmd-kill-buffer-cmd

    ;; Window commands
    setup-new-editor-defaults!
    winner-save-config!
    cmd-split-window cmd-split-window-right
    cmd-other-window cmd-delete-window cmd-delete-other-windows
    cmd-select-window-by-number
    cmd-select-window-1 cmd-select-window-2 cmd-select-window-3
    cmd-select-window-4 cmd-select-window-5 cmd-select-window-6
    cmd-select-window-7 cmd-select-window-8 cmd-select-window-9

    ;; Search highlighting
    setup-search-indicator!
    highlight-all-matches! clear-search-highlights!

    ;; Search
    search-forward-impl! search-forward-regexp-impl!
    cmd-search-forward cmd-search-backward
    search-backward-impl!

    ;; Eshell
    cmd-eshell cmd-eshell-send
    cmd-eshell-send-legacy
    eshell-find-last-prompt
    gsh-eshell-find-last-prompt

    ;; Shell
    cmd-shell cmd-shell-send

    ;; AI Chat
    cmd-chat cmd-chat-send

    ;; Terminal
    cmd-term cmd-terminal-send
    cmd-term-interrupt cmd-term-send-eof cmd-term-send-tab

    ;; Dired
    dired-open-directory! cmd-dired-find-file

    ;; REPL
    cmd-repl cmd-repl-send

    ;; Mark ring
    push-mark-ring!

    ;; Tab insertion
    cmd-tab-to-tab-stop

    ;; Selective undo
    cmd-undo-region

    ;; Side windows
    cmd-display-buffer-in-side-window
    cmd-toggle-side-window

    ;; Info reader
    cmd-info-reader

    ;; Git status
    git-file-status
    cmd-project-tree-git)

  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-directory path-strip-directory path-extension)
          (only (std srfi srfi-13) string-join string-contains string-prefix?
                string-suffix? string-index string-trim string-trim-both
                string-trim-right)
          (only (std misc string) string-split)
          (std misc process)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (chez-scintilla style)
          (chez-scintilla tui)
          (jerboa-emacs core)
          (jerboa-emacs repl)
          (jerboa-emacs eshell)
          (jerboa-emacs gsh-eshell)
          (jerboa-emacs shell)
          (jerboa-emacs shell-history)
          (jerboa-emacs terminal)
          (jerboa-emacs chat)
          (jerboa-emacs keymap)
          (jerboa-emacs buffer)
          (jerboa-emacs window)
          (jerboa-emacs modeline)
          (jerboa-emacs echo)
          (jerboa-emacs highlight)
          (jerboa-emacs persist))

  ;;;============================================================================
  ;;; Helper: strip trailing directory separator
  ;;;============================================================================
  (define (path-strip-trailing-directory-separator p)
    (let ((len (string-length p)))
      (if (and (> len 1) (char=? (string-ref p (- len 1)) #\/))
        (substring p 0 (- len 1))
        p)))

  ;;;============================================================================
  ;;; Shared state (used across editor sub-modules)
  ;;;============================================================================
  (define *auto-pair-mode* #t)
  (define (auto-pair-mode?) *auto-pair-mode*)
  (define (auto-pair-mode-set! v) (set! *auto-pair-mode* v))

  (define *auto-revert-mode* #f)
  (define (auto-revert-mode?) *auto-revert-mode*)
  (define (auto-revert-mode-set! v) (set! *auto-revert-mode* v))

  ;;;============================================================================
  ;;; Pulse/flash highlight on jump (beacon-like)
  ;;;============================================================================
  (define *pulse-indicator* 1)
  (define *pulse-countdown* 0)
  (define *pulse-editor* #f)

  (define (pulse-line! ed line-num)
    (let* ((start (editor-position-from-line ed line-num))
           (end (editor-get-line-end-position ed line-num))
           (len (- end start)))
      (when (> len 0)
        (when *pulse-editor*
          (pulse-clear! *pulse-editor*))
        (send-message ed SCI_INDICSETSTYLE *pulse-indicator* INDIC_FULLBOX)
        (send-message ed SCI_INDICSETFORE *pulse-indicator* #x00A5FF)
        (send-message ed SCI_SETINDICATORCURRENT *pulse-indicator* 0)
        (send-message ed SCI_INDICATORFILLRANGE start len)
        (set! *pulse-editor* ed)
        (set! *pulse-countdown* 10))))

  (define (pulse-tick!)
    (when (> *pulse-countdown* 0)
      (set! *pulse-countdown* (- *pulse-countdown* 1))
      (when (= *pulse-countdown* 0)
        (when *pulse-editor*
          (pulse-clear! *pulse-editor*)))))

  (define (pulse-clear! ed)
    (let ((len (editor-get-text-length ed)))
      (send-message ed SCI_SETINDICATORCURRENT *pulse-indicator* 0)
      (send-message ed SCI_INDICATORCLEARRANGE 0 len))
    (when (eq? *pulse-editor* ed)
      (set! *pulse-editor* #f)
      (set! *pulse-countdown* 0)))

  ;;;============================================================================
  ;;; System clipboard integration (xclip/xsel/wl-copy)
  ;;;============================================================================
  (define *clipboard-command* #f)

  (define (find-clipboard-command!)
    (unless *clipboard-command*
      (set! *clipboard-command*
        (cond
          ((file-exists? "/usr/bin/wl-copy") 'wl-copy)
          ((file-exists? "/usr/bin/xclip") 'xclip)
          ((file-exists? "/usr/bin/xsel") 'xsel)
          (else 'none))))
    *clipboard-command*)

  (define (clipboard-set! text)
    (let ((cmd (find-clipboard-command!)))
      (unless (eq? cmd 'none)
        (guard (e (#t #f))
          (let ((args (case cmd
                        ((wl-copy) (list "wl-copy"))
                        ((xclip)  (list "xclip" "-selection" "clipboard"))
                        ((xsel)   (list "xsel" "--clipboard" "--input")))))
            (let-values (((to-stdin from-stdout from-stderr pid)
                          (open-process-ports
                            (string-join args " ")
                            (buffer-mode block)
                            (native-transcoder))))
              (display text to-stdin)
              (close-output-port to-stdin)))))))

  (define (clipboard-get)
    (let ((cmd (find-clipboard-command!)))
      (if (eq? cmd 'none)
        #f
        (guard (e (#t #f))
          (let ((args (case cmd
                        ((wl-copy) (list "wl-paste" "--no-newline"))
                        ((xclip)  (list "xclip" "-selection" "clipboard" "-o"))
                        ((xsel)   (list "xsel" "--clipboard" "--output")))))
            (let ((proc (open-process args)))
              (let ((text (get-string-all (process-port-rec-stdout-port proc))))
                (if (eof-object? text) #f text))))))))

  ;;;============================================================================
  ;;; Uniquify buffer name helper
  ;;;============================================================================
  (define (uniquify-buffer-name path)
    (let* ((basename (path-strip-directory path))
           (existing (filter (lambda (b)
                               (and (buffer-file-path b)
                                    (not (string=? (buffer-file-path b) path))
                                    (string=? (path-strip-directory (buffer-file-path b))
                                              basename)))
                             (buffer-list))))
      (if (null? existing)
        basename
        (begin
          (for-each
            (lambda (b)
              (when (string=? (buffer-name b) basename)
                (let ((parent (path-strip-directory
                                (path-strip-trailing-directory-separator
                                  (path-directory (buffer-file-path b))))))
                  (buffer-name-set! b (string-append basename "<" parent ">")))))
            existing)
          (let ((parent (path-strip-directory
                          (path-strip-trailing-directory-separator
                            (path-directory path)))))
            (string-append basename "<" parent ">"))))))

  ;;;============================================================================
  ;;; Line ending detection
  ;;;============================================================================
  (define (detect-eol-mode text)
    (let loop ((i 0))
      (if (>= i (string-length text))
        SC_EOL_LF
        (let ((ch (string-ref text i)))
          (cond
            ((char=? ch #\return)
             (if (and (< (+ i 1) (string-length text))
                      (char=? (string-ref text (+ i 1)) #\newline))
               SC_EOL_CRLF
               SC_EOL_CR))
            ((char=? ch #\newline) SC_EOL_LF)
            (else (loop (+ i 1))))))))

  ;;;============================================================================
  ;;; File modification tracking and auto-save
  ;;;============================================================================
  (define *buffer-mod-times* (make-hash-table))

  (define *auto-save-enabled* #t)
  (define (auto-save-enabled?) *auto-save-enabled*)
  (define (auto-save-enabled-set! v) (set! *auto-save-enabled* v))
  (define *auto-save-counter* 0)
  (define *auto-save-interval* 600)

  (define (file-mod-time path)
    (guard (e (#t #f))
      (if (file-exists? path)
        (let ((t (file-modification-time path)))
          (time-second t))
        #f)))

  (define (update-buffer-mod-time! buf)
    (let ((path (buffer-file-path buf)))
      (when path
        (let ((mt (file-mod-time path)))
          (when mt
            (hash-put! *buffer-mod-times* buf mt))))))

  (define (auto-save-buffers! app)
    (when *auto-save-enabled*
      (for-each
        (lambda (buf)
          (let ((path (buffer-file-path buf)))
            (when path
              (let loop ((wins (frame-windows (app-state-frame app))))
                (when (pair? wins)
                  (if (eq? (edit-window-buffer (car wins)) buf)
                    (let ((ed (edit-window-editor (car wins))))
                      (when (editor-get-modify? ed)
                        (let ((auto-path (make-auto-save-path path)))
                          (guard (e (#t #f))
                            (let ((text (editor-get-text ed)))
                              (write-string-to-file auto-path text))))))
                    (loop (cdr wins))))))))
        (buffer-list))))

  (define (check-file-modifications! app)
    (for-each
      (lambda (buf)
        (let ((path (buffer-file-path buf)))
          (when path
            (let ((saved-mt (hash-get *buffer-mod-times* buf))
                  (current-mt (file-mod-time path)))
              (when (and saved-mt current-mt (> current-mt saved-mt))
                (hash-put! *buffer-mod-times* buf current-mt)
                (if *auto-revert-mode*
                  (let loop ((wins (frame-windows (app-state-frame app))))
                    (if (pair? wins)
                      (if (eq? (edit-window-buffer (car wins)) buf)
                        (let ((ed (edit-window-editor (car wins))))
                          (if (editor-get-modify? ed)
                            (echo-message! (app-state-echo app)
                              (string-append (buffer-name buf)
                                " changed on disk (buffer modified, not reverting)"))
                            (let ((text (read-file-as-string path)))
                              (when text
                                (let ((pos (editor-get-current-pos ed)))
                                  (editor-set-text ed text)
                                  (editor-set-save-point ed)
                                  (editor-goto-pos ed (min pos (string-length text)))
                                  (echo-message! (app-state-echo app)
                                    (string-append "Reverted " (buffer-name buf))))))))
                        (loop (cdr wins)))
                      (void)))
                  (echo-message! (app-state-echo app)
                    (string-append (buffer-name buf) " changed on disk; revert with C-x C-r"))))))))
      (buffer-list)))

  ;;;============================================================================
  ;;; Accessors
  ;;;============================================================================
  (define (current-editor app)
    (edit-window-editor (current-window (app-state-frame app))))

  (define (current-buffer-from-app app)
    (edit-window-buffer (current-window (app-state-frame app))))

  (define (app-read-string app prompt)
    (if (pair? (test-echo-responses))
      (let ((r (car (test-echo-responses))))
        (test-echo-responses-set! (cdr (test-echo-responses)))
        r)
      (let* ((echo (app-state-echo app))
             (fr (app-state-frame app))
             (row (- (frame-height fr) 1))
             (width (frame-width fr)))
        (echo-read-string echo prompt row width))))

  (define (editor-replace-selection ed text)
    (send-message/string ed 2170 text))

  (define (make-auto-save-path path)
    (let* ((dir (path-directory path))
           (name (path-strip-directory path)))
      (string-append dir "#" name "#")))

  ;;;============================================================================
  ;;; Self-insert command
  ;;;============================================================================
  (define (auto-pair-char ch)
    (cond
      ((= ch 40) 41)
      ((= ch 91) 93)
      ((= ch 123) 125)
      ((= ch 34) 34)
      (else #f)))

  (define (electric-pair-char ch buf)
    (cond
      ((= ch 40) 41)
      ((= ch 91) 93)
      ((= ch 123) 125)
      ((= ch 34) 34)
      ((= ch 39)
       (let ((lang (and buf (buffer-lexer-lang buf))))
         (if (memq lang '(scheme lisp))
           #f
           39)))
      (else #f)))

  (define (electric-pair-closing? ch buf)
    (or (= ch 41) (= ch 93) (= ch 125) (= ch 34)
        (and (= ch 39)
             (let ((lang (and buf (buffer-lexer-lang buf))))
               (not (memq lang '(scheme lisp)))))))

  (define (auto-pair-closing? ch)
    (or (= ch 41) (= ch 93) (= ch 125) (= ch 34)))

  (define (paredit-delimiter? ch)
    (or (= ch 40) (= ch 41) (= ch 91) (= ch 93) (= ch 123) (= ch 125)))

  (define (paredit-strict-allow-delete? ed pos direction)
    (let ((text-len (send-message ed SCI_GETLENGTH 0 0)))
      (if (or (<= text-len 0) (< pos 0) (>= pos text-len))
        #t
        (let ((ch (send-message ed SCI_GETCHARAT pos 0)))
          (if (not (paredit-delimiter? ch))
            #t
            (cond
              ((or (= ch 40) (= ch 91) (= ch 123))
               (and (< (+ pos 1) text-len)
                    (let ((next (send-message ed SCI_GETCHARAT (+ pos 1) 0)))
                      (eqv? next (auto-pair-char ch)))))
              ((= ch 41)
               (and (> pos 0)
                    (= (send-message ed SCI_GETCHARAT (- pos 1) 0) 40)))
              ((= ch 93)
               (and (> pos 0)
                    (= (send-message ed SCI_GETCHARAT (- pos 1) 0) 91)))
              ((= ch 125)
               (and (> pos 0)
                    (= (send-message ed SCI_GETCHARAT (- pos 1) 0) 123)))
              (else #t)))))))

  (define (cmd-self-insert! app ch)
    (clear-search-highlights! (current-editor app))
    (let ((buf (current-buffer-from-app app)))
      (cond
        ;; Suppress self-insert in dired buffers
        ((dired-buffer? buf) (void))
        ;; In REPL buffers, only allow typing after the prompt
        ((repl-buffer? buf)
         (let* ((ed (current-editor app))
                (pos (editor-get-current-pos ed))
                (rs (hash-get *repl-state* buf)))
           (when (and rs (>= pos (repl-state-prompt-pos rs)))
             (let ((str (string (integer->char ch))))
               (editor-insert-text ed pos str)
               (editor-goto-pos ed (+ pos 1))))))
        ;; Eshell: allow typing after the last prompt
        ((eshell-buffer? buf)
         (let* ((ed (current-editor app))
                (pos (editor-get-current-pos ed))
                (str (string (integer->char ch))))
           (editor-insert-text ed pos str)
           (editor-goto-pos ed (+ pos 1))))
        ;; Shell: if PTY busy, send to PTY; otherwise insert locally
        ((shell-buffer? buf)
         (let ((ss (hash-get (shell-state-table) buf)))
           (if (and ss (shell-pty-busy? ss))
             (shell-send-input! ss (string (integer->char ch)))
             (let* ((ed (current-editor app))
                    (pos (editor-get-current-pos ed))
                    (str (string (integer->char ch))))
               (editor-insert-text ed pos str)
               (editor-goto-pos ed (+ pos 1))))))
        ;; Terminal: if PTY busy, send to PTY; otherwise insert locally
        ((terminal-buffer? buf)
         (let ((ts (hash-get *terminal-state* buf)))
           (if (and ts (terminal-pty-busy? ts))
             (terminal-send-input! ts (string (integer->char ch)))
             (let* ((ed (current-editor app))
                    (pos (editor-get-current-pos ed))
                    (str (string (integer->char ch))))
               (editor-insert-text ed pos str)
               (editor-goto-pos ed (+ pos 1))))))
        (else
         (let* ((ed (current-editor app))
                (pair-active (or *auto-pair-mode* (electric-pair-mode)))
                (close-ch (and pair-active
                               (if (electric-pair-mode)
                                 (electric-pair-char ch buf)
                                 (auto-pair-char ch))))
                (n (get-prefix-arg app)))
           (cond
             ;; Auto/electric-pair skip-over
             ((and pair-active (= n 1)
                   (if (electric-pair-mode)
                     (electric-pair-closing? ch buf)
                     (auto-pair-closing? ch)))
              (let* ((pos (editor-get-current-pos ed))
                     (len (send-message ed SCI_GETLENGTH))
                     (next-ch (and (< pos len)
                                  (send-message ed SCI_GETCHARAT pos 0))))
                (if (and next-ch (= next-ch ch))
                  (editor-goto-pos ed (+ pos 1))
                  (begin
                    (editor-insert-text ed pos (string (integer->char ch)))
                    (editor-goto-pos ed (+ pos 1))))))
             ;; Auto/electric-pair: insert both chars
             ((and close-ch (= n 1))
              (let ((pos (editor-get-current-pos ed)))
                (editor-insert-text ed pos
                  (string (integer->char ch) (integer->char close-ch)))
                (editor-goto-pos ed (+ pos 1))))
             ;; Insert character n times
             (else
              (let* ((pos (editor-get-current-pos ed))
                     (str (make-string n (integer->char ch))))
                (editor-insert-text ed pos str)
                (editor-goto-pos ed (+ pos n)))))
           (tui-auto-fill-after-insert! app ed))))))

  ;;;============================================================================
  ;;; Auto-fill check for TUI self-insert
  ;;;============================================================================
  (define (tui-auto-fill-after-insert! app ed)
    (when (auto-fill-mode)
      (let ((buf (current-buffer-from-app app)))
        (when (and buf
                   (not (dired-buffer? buf))
                   (not (shell-buffer? buf))
                   (not (terminal-buffer? buf))
                   (not (repl-buffer? buf)))
          (let* ((text (editor-get-text ed))
                 (len (string-length text))
                 (pos (min (editor-get-current-pos ed) len)))
            (when (and (> pos 0) (> len 0))
              (let* ((line-start (let loop ((i (- pos 1)))
                                   (cond ((< i 0) 0)
                                         ((char=? (string-ref text i) #\newline) (+ i 1))
                                         (else (loop (- i 1))))))
                     (col (- pos line-start)))
                (when (> col (fill-column))
                  (let ((break-end (min (+ line-start (fill-column)) (- len 1))))
                    (let loop ((i break-end))
                      (cond
                        ((<= i line-start) #f)
                        ((char=? (string-ref text i) #\space)
                         (editor-set-selection ed i (+ i 1))
                         (editor-replace-selection ed "\n")
                         (editor-goto-pos ed pos))
                        (else (loop (- i 1))))))))))))))

  ;;;============================================================================
  ;;; Navigation commands
  ;;;============================================================================
  (define (update-mark-region! app ed)
    (let* ((buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (when mark
        (editor-set-selection ed mark (editor-get-current-pos ed)))))

  (define (collapse-selection-to-caret! ed)
    (let ((pos (editor-get-current-pos ed)))
      (editor-set-selection ed pos pos)))

  (define (cmd-forward-char app)
    (let ((n (get-prefix-arg app)) (ed (current-editor app)))
      (collapse-selection-to-caret! ed)
      (if (>= n 0)
        (let loop ((i 0)) (when (< i n) (editor-send-key ed SCK_RIGHT) (loop (+ i 1))))
        (let loop ((i 0)) (when (< i (- n)) (editor-send-key ed SCK_LEFT) (loop (+ i 1)))))
      (update-mark-region! app ed)))

  (define (cmd-backward-char app)
    (let ((n (get-prefix-arg app)) (ed (current-editor app)))
      (collapse-selection-to-caret! ed)
      (if (>= n 0)
        (let loop ((i 0)) (when (< i n) (editor-send-key ed SCK_LEFT) (loop (+ i 1))))
        (let loop ((i 0)) (when (< i (- n)) (editor-send-key ed SCK_RIGHT) (loop (+ i 1)))))
      (update-mark-region! app ed)))

  (define (tui-eshell-on-input-line? ed)
    (let* ((line-count (send-message ed SCI_GETLINECOUNT 0 0))
           (cur-line (editor-line-from-position ed (editor-get-current-pos ed))))
      (= cur-line (- line-count 1))))

  (define (tui-eshell-current-input ed)
    (let* ((line-count (send-message ed SCI_GETLINECOUNT 0 0))
           (last-line (- line-count 1))
           (line-text (editor-get-line ed last-line))
           (prompt (gsh-eshell-prompt-string))
           (plen (string-length prompt)))
      (if (and (>= (string-length line-text) plen)
               (string=? (substring line-text 0 plen) prompt))
        (substring line-text plen (string-length line-text))
        line-text)))

  (define (tui-eshell-replace-input! ed new-input)
    (let* ((line-count (send-message ed SCI_GETLINECOUNT 0 0))
           (last-line (- line-count 1))
           (line-start (editor-position-from-line ed last-line))
           (line-text (editor-get-line ed last-line))
           (prompt (gsh-eshell-prompt-string))
           (plen (string-length prompt))
           (input-start (+ line-start plen))
           (doc-end (send-message ed SCI_GETLENGTH 0 0)))
      (send-message ed SCI_SETSEL input-start doc-end)
      (editor-replace-selection ed new-input)
      (let ((new-end (send-message ed SCI_GETLENGTH 0 0)))
        (send-message ed SCI_GOTOPOS new-end 0))))

  (define (cmd-next-line app)
    (let* ((buf (current-buffer-from-app app))
           (ed (current-editor app)))
      (if (and (gsh-eshell-buffer? buf) (tui-eshell-on-input-line? ed))
        (let ((cmd (eshell-history-next buf)))
          (when cmd
            (tui-eshell-replace-input! ed cmd)))
        (let ((n (get-prefix-arg app)))
          (collapse-selection-to-caret! ed)
          (if (>= n 0)
            (let loop ((i 0)) (when (< i n) (editor-send-key ed SCK_DOWN) (loop (+ i 1))))
            (let loop ((i 0)) (when (< i (- n)) (editor-send-key ed SCK_UP) (loop (+ i 1)))))
          (update-mark-region! app ed)))))

  (define (cmd-previous-line app)
    (let* ((buf (current-buffer-from-app app))
           (ed (current-editor app)))
      (if (and (gsh-eshell-buffer? buf) (tui-eshell-on-input-line? ed))
        (let ((cmd (eshell-history-prev buf (tui-eshell-current-input ed))))
          (when cmd
            (tui-eshell-replace-input! ed cmd)))
        (let ((n (get-prefix-arg app)))
          (collapse-selection-to-caret! ed)
          (if (>= n 0)
            (let loop ((i 0)) (when (< i n) (editor-send-key ed SCK_UP) (loop (+ i 1))))
            (let loop ((i 0)) (when (< i (- n)) (editor-send-key ed SCK_DOWN) (loop (+ i 1)))))
          (update-mark-region! app ed)))))

  (define (cmd-beginning-of-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line))
           (line-end (editor-get-line-end-position ed line))
           (indent-pos
             (let loop ((p line-start))
               (if (>= p line-end)
                 line-start
                 (let ((ch (send-message ed SCI_GETCHARAT p 0)))
                   (if (or (= ch 32) (= ch 9))
                     (loop (+ p 1))
                     p))))))
      (if (= pos indent-pos)
        (editor-goto-pos ed line-start)
        (editor-goto-pos ed indent-pos))
      (update-mark-region! app ed)))

  (define (cmd-end-of-line app)
    (let ((ed (current-editor app)))
      (editor-send-key ed SCK_END)
      (update-mark-region! app ed)))

  (define (cmd-forward-word app)
    (let ((n (get-prefix-arg app)) (ed (current-editor app)))
      (if (>= n 0)
        (let loop ((i 0)) (when (< i n) (editor-send-key ed SCK_RIGHT #f #t #f) (loop (+ i 1))))
        (let loop ((i 0)) (when (< i (- n)) (editor-send-key ed SCK_LEFT #f #t #f) (loop (+ i 1)))))
      (update-mark-region! app ed)))

  (define (cmd-backward-word app)
    (let ((n (get-prefix-arg app)) (ed (current-editor app)))
      (if (>= n 0)
        (let loop ((i 0)) (when (< i n) (editor-send-key ed SCK_LEFT #f #t #f) (loop (+ i 1))))
        (let loop ((i 0)) (when (< i (- n)) (editor-send-key ed SCK_RIGHT #f #t #f) (loop (+ i 1)))))
      (update-mark-region! app ed)))

  (define (cmd-beginning-of-buffer app)
    (let ((ed (current-editor app)))
      (editor-send-key ed SCK_HOME #f #t #f)
      (update-mark-region! app ed)))

  (define (cmd-end-of-buffer app)
    (let ((ed (current-editor app)))
      (editor-send-key ed SCK_END #f #t #f)
      (update-mark-region! app ed)))

  (define (cmd-scroll-down app)
    (let ((ed (current-editor app)))
      (editor-send-key ed SCK_NEXT)
      (update-mark-region! app ed)))

  (define (cmd-scroll-up app)
    (let ((ed (current-editor app)))
      (editor-send-key ed SCK_PRIOR)
      (update-mark-region! app ed)))

  (define (cmd-recenter app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (cur-line (editor-line-from-position ed pos))
           (fr (app-state-frame app))
           (win (current-window fr))
           (visible-lines (max 1 (- (edit-window-h win) 1)))
           (target-first (max 0 (- cur-line (quotient visible-lines 2)))))
      (send-message ed SCI_SETFIRSTVISIBLELINE target-first 0)))

  ;;;============================================================================
  ;;; Editing commands
  ;;;============================================================================
  (define (cmd-delete-char app)
    (let ((ed (current-editor app)))
      (if (and (paredit-strict-mode?)
               (not (paredit-strict-allow-delete? ed (editor-get-current-pos ed) 'forward)))
        (echo-message! (app-state-echo app) "Paredit: cannot delete delimiter")
        (editor-send-key ed SCK_DELETE))))

  (define (cmd-backward-delete-char app)
    (let ((buf (current-buffer-from-app app)))
      (cond
        ((repl-buffer? buf)
         (let* ((ed (current-editor app))
                (pos (editor-get-current-pos ed))
                (rs (hash-get *repl-state* buf)))
           (when (and rs (> pos (repl-state-prompt-pos rs)))
             (editor-send-key ed SCK_BACK))))
        ((shell-buffer? buf)
         (let* ((ed (current-editor app))
                (pos (editor-get-current-pos ed))
                (ss (hash-get (shell-state-table) buf)))
           (when (and ss (> pos (shell-state-prompt-pos ss)))
             (editor-send-key ed SCK_BACK))))
        ((terminal-buffer? buf)
         (let* ((ed (current-editor app))
                (pos (editor-get-current-pos ed))
                (ts (hash-get *terminal-state* buf)))
           (when (and ts (> pos (terminal-state-prompt-pos ts)))
             (editor-send-key ed SCK_BACK))))
        (else
         (let ((ed (current-editor app)))
           (if (and (paredit-strict-mode?)
                    (let ((pos (editor-get-current-pos ed)))
                      (and (> pos 0)
                           (not (paredit-strict-allow-delete? ed (- pos 1) 'backward)))))
             (echo-message! (app-state-echo app) "Paredit: cannot delete delimiter")
             (editor-send-key ed SCK_BACK)))))))

  (define (cmd-backward-delete-char-untabify app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (when (> pos 0)
        (let* ((line (editor-line-from-position ed pos))
               (line-start (editor-position-from-line ed line))
               (col (- pos line-start))
               (ch-before (send-message ed SCI_GETCHARAT (- pos 1) 0)))
          (if (and (= ch-before 9)
                   (let loop ((p line-start))
                     (or (>= p pos)
                         (let ((c (send-message ed SCI_GETCHARAT p 0)))
                           (and (or (= c 32) (= c 9))
                                (loop (+ p 1)))))))
            (editor-send-key ed SCK_BACK)
            (editor-send-key ed SCK_BACK))))))

  (define (get-line-indent text line-start)
    (let ((len (string-length text)))
      (let loop ((i line-start) (count 0))
        (if (>= i len) count
          (let ((ch (string-ref text i)))
            (cond
              ((char=? ch #\space) (loop (+ i 1) (+ count 1)))
              ((char=? ch #\tab) (loop (+ i 1) (+ count 2)))
              (else count)))))))

  (define (buffer-list-buffer? buf)
    (eq? (buffer-lexer-lang buf) 'buffer-list))

  (define (cmd-buffer-list-select app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-text (editor-get-line ed line))
           (trimmed (string-trim line-text))
           (tab-pos (string-index trimmed #\tab))
           (name (if tab-pos (substring trimmed 0 tab-pos) trimmed)))
      (if (and (> (string-length name) 0)
               (not (string=? name "Buffer"))
               (not (string=? name "------")))
        (let ((buf (buffer-by-name name)))
          (if buf
            (let ((fr (app-state-frame app)))
              (buffer-attach! ed buf)
              (edit-window-buffer-set! (current-window fr) buf)
              (editor-set-caret-line-background ed #x333333))
            (echo-error! (app-state-echo app) (string-append "No buffer: " name))))
        (echo-message! (app-state-echo app) "No buffer on this line"))))

  (define (cmd-newline app)
    (let ((buf (current-buffer-from-app app)))
      (cond
        ((dired-buffer? buf)       (cmd-dired-find-file app))
        ((buffer-list-buffer? buf) (cmd-buffer-list-select app))
        ((repl-buffer? buf)        (cmd-repl-send app))
        ((eshell-buffer? buf)      (cmd-eshell-send app))
        ((shell-buffer? buf)       (cmd-shell-send app))
        ((terminal-buffer? buf)    (cmd-terminal-send app))
        ((chat-buffer? buf)        (cmd-chat-send app))
        (else
         (let* ((ed (current-editor app))
                (pos (editor-get-current-pos ed)))
           (if (electric-indent-mode?)
             (let* ((text (editor-get-text ed))
                    (line (editor-line-from-position ed pos))
                    (line-start (editor-position-from-line ed line))
                    (indent (get-line-indent text line-start))
                    (indent-str (make-string indent #\space)))
               (editor-insert-text ed pos (string-append "\n" indent-str))
               (editor-goto-pos ed (+ pos 1 indent)))
             (begin
               (editor-insert-text ed pos "\n")
               (editor-goto-pos ed (+ pos 1)))))))))

  (define (cmd-open-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "\n")))

  (define (cmd-undo app)
    (let ((ed (current-editor app)))
      (if (editor-can-undo? ed)
        (editor-undo ed)
        (echo-message! (app-state-echo app) "No further undo information"))))

  (define (cmd-redo app)
    (let ((ed (current-editor app)))
      (if (editor-can-redo? ed)
        (editor-redo ed)
        (echo-message! (app-state-echo app) "No further redo information"))))

  ;;;============================================================================
  ;;; Kill / Yank
  ;;;============================================================================
  (define (cmd-kill-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-end (editor-get-line-end-position ed line)))
      (if (= pos line-end)
        (editor-delete-range ed pos 1)
        (begin
          (editor-set-selection ed pos line-end)
          (editor-cut ed)
          (let ((clip (editor-get-clipboard ed)))
            (when (> (string-length clip) 0)
              (app-state-kill-ring-set! app
                (cons clip (app-state-kill-ring app)))
              (clipboard-set! clip)))))))

  (define (cmd-yank app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-paste ed)
      (let ((new-pos (editor-get-current-pos ed)))
        (app-state-last-yank-pos-set! app pos)
        (app-state-last-yank-len-set! app (- new-pos pos))
        (app-state-kill-ring-idx-set! app 0))))

  ;;;============================================================================
  ;;; Mark and region
  ;;;============================================================================
  (define (cmd-set-mark app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (buf (current-buffer-from-app app)))
      (when (buffer-mark buf)
        (push-mark-ring! app buf (buffer-mark buf)))
      (buffer-mark-set! buf pos)
      (echo-message! (app-state-echo app) "Mark set")))

  (define (cmd-kill-region app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if mark
        (let ((pos (editor-get-current-pos ed)))
          (editor-set-selection ed (min mark pos) (max mark pos))
          (editor-cut ed)
          (let ((clip (editor-get-clipboard ed)))
            (when (> (string-length clip) 0)
              (clipboard-set! clip)))
          (buffer-mark-set! buf #f))
        (echo-error! (app-state-echo app) "No mark set"))))

  (define (cmd-copy-region app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if mark
        (let ((pos (editor-get-current-pos ed)))
          (editor-set-selection ed (min mark pos) (max mark pos))
          (editor-copy ed)
          (let ((clip (editor-get-clipboard ed)))
            (when (> (string-length clip) 0)
              (clipboard-set! clip)))
          (editor-set-selection ed pos pos)
          (buffer-mark-set! buf #f)
          (echo-message! (app-state-echo app) "Region copied"))
        (echo-error! (app-state-echo app) "No mark set"))))

  ;;;============================================================================
  ;;; File operations
  ;;;============================================================================
  (define (expand-filename path)
    (cond
      ((and (> (string-length path) 0)
            (char=? (string-ref path 0) #\~))
       (let ((home (or (getenv "HOME") "/")))
         (if (= (string-length path) 1)
           home
           (if (char=? (string-ref path 1) #\/)
             (string-append home (substring path 1 (string-length path)))
             path))))
      ((and (> (string-length path) 1)
            (char=? (string-ref path 0) #\$))
       (let* ((slash-pos (string-index path #\/))
              (var-name (if slash-pos
                          (substring path 1 slash-pos)
                          (substring path 1 (string-length path))))
              (rest (if slash-pos
                       (substring path slash-pos (string-length path))
                       ""))
              (value (getenv var-name)))
         (if value
           (string-append value rest)
           path)))
      (else path)))

  (define (list-directory-files dir)
    (guard (e (#t '()))
      (let ((entries (directory-list dir)))
        (list-sort string<? entries))))

  (define (cmd-find-file app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (current-buffer-from-app app))
           (fp (and buf (buffer-file-path buf)))
           (default-dir (if fp
                          (path-directory fp)
                          (current-directory)))
           (filename (echo-read-file-with-completion echo "Find file: "
                        row width default-dir)))
      (when filename
        (when (> (string-length filename) 0)
          (let ((filename (expand-filename filename)))
            (if (or (string-prefix? "/ssh:" filename)
                    (string-prefix? "/scp:" filename))
              ;; Remote file via SSH
              (let* ((rest (substring filename 5 (string-length filename)))
                     (colon-pos (string-index rest #\:))
                     (host (if colon-pos (substring rest 0 colon-pos) rest))
                     (remote-path (if colon-pos
                                    (substring rest (+ colon-pos 1) (string-length rest))
                                    "/")))
                (echo-message! echo (string-append "Fetching " host ":" remote-path "..."))
                (let ((content
                        (guard (e (#t #f))
                          (let ((proc (open-process
                                        (list "/usr/bin/ssh" host "cat" remote-path))))
                            (let* ((data (get-string-all (process-port-rec-stdout-port proc))))
                              (if (eof-object? data) #f data))))))
                  (if (not content)
                    (echo-error! echo (string-append "Failed to fetch " remote-path " from " host))
                    (let* ((name (string-append (path-strip-directory remote-path) " [" host "]"))
                           (ed (current-editor app))
                           (buf (buffer-create! name ed)))
                      (buffer-attach! ed buf)
                      (edit-window-buffer-set! (current-window fr) buf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (editor-set-save-point ed)
                      (buffer-file-path-set! buf filename)
                      (let ((lang (detect-file-language remote-path)))
                        (when lang
                          (setup-highlighting-for-file! ed remote-path)
                          (send-message ed SCI_SETMARGINTYPEN 0 SC_MARGIN_NUMBER)
                          (send-message ed SCI_SETMARGINWIDTHN 0 4)))
                      (echo-message! echo (string-append "Loaded " remote-path " from " host))))))
              ;; Check if it's a directory
              (if (and (file-exists? filename)
                       (file-directory? filename))
                (dired-open-directory! app filename)
                ;; Regular file
                (let* ((name (uniquify-buffer-name filename))
                       (ed (current-editor app))
                       (buf (buffer-create! name ed filename)))
                  (recent-files-add! filename)
                  (let ((mode (detect-major-mode filename)))
                    (when mode
                      (buffer-local-set! buf 'major-mode mode)
                      (let ((mode-cmd (find-command mode)))
                        (when mode-cmd (mode-cmd app)))))
                  (buffer-attach! ed buf)
                  (edit-window-buffer-set! (current-window fr) buf)
                  (when (file-exists? filename)
                    (let ((text (read-file-as-string filename)))
                      (when text
                        (editor-set-text ed text)
                        (editor-set-save-point ed)
                        (let ((saved-pos (save-place-restore filename)))
                          (if (and saved-pos (< saved-pos (string-length text)))
                            (begin
                              (editor-goto-pos ed saved-pos)
                              (editor-scroll-caret ed))
                            (editor-goto-pos ed 0))))))
                  (let ((lang (detect-file-language filename)))
                    (if lang
                      (setup-highlighting-for-file! ed filename)
                      (when (file-exists? filename)
                        (let ((text (editor-get-text ed)))
                          (when (and text (> (string-length text) 2))
                            (let ((shebang-lang (detect-language-from-shebang text)))
                              (when shebang-lang
                                (setup-highlighting-for-file! ed
                                  (string-append "shebang." (symbol->string shebang-lang))))))))))
                  (when (file-exists? filename)
                    (let ((text (editor-get-text ed)))
                      (when (and text (> (string-length text) 0))
                        (let ((eol-mode (detect-eol-mode text)))
                          (send-message ed SCI_SETEOLMODE eol-mode 0)))))
                  (let ((lang (or (detect-file-language filename)
                                  (and (file-exists? filename)
                                       (detect-language-from-shebang (editor-get-text ed))))))
                    (when lang
                      (send-message ed SCI_SETMARGINTYPEN 0 SC_MARGIN_NUMBER)
                      (let* ((lines (send-message ed SCI_GETLINECOUNT 0 0))
                             (width (cond ((> lines 9999) 6)
                                          ((> lines 999) 5)
                                          (else 4))))
                        (send-message ed SCI_SETMARGINWIDTHN 0 width))))
                  (run-hooks! 'find-file-hook app buf)
                  (echo-message! echo (string-append "Opened: " filename))))))))))

  ;; copy-file helper (not built-in in Chez)
  (define (copy-file src dst)
    (let ((data (call-with-port (open-file-input-port src)
                  (lambda (in) (get-bytevector-all in)))))
      (call-with-port (open-file-output-port dst (file-options no-fail))
        (lambda (out) (put-bytevector out data)))))

  (define (cmd-save-buffer app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (echo (app-state-echo app))
           (path (buffer-file-path buf)))
      (if path
        (if (or (string-prefix? "/ssh:" path)
                (string-prefix? "/scp:" path))
          ;; Save to remote host via SSH
          (let* ((rest (substring path 5 (string-length path)))
                 (colon-pos (string-index rest #\:))
                 (host (if colon-pos (substring rest 0 colon-pos) rest))
                 (remote-path (if colon-pos
                                (substring rest (+ colon-pos 1) (string-length rest))
                                "/")))
            (let ((text (editor-get-text ed)))
              (echo-message! echo (string-append "Saving to " host ":" remote-path "..."))
              (let ((ok (guard (e (#t #f))
                          (let-values (((to-stdin from-stdout from-stderr pid)
                                        (open-process-ports
                                          (string-append "/usr/bin/ssh " host " cat > " remote-path)
                                          (buffer-mode block)
                                          (native-transcoder))))
                            (display text to-stdin)
                            (flush-output-port to-stdin)
                            (close-output-port to-stdin)
                            #t))))
                (if ok
                  (begin
                    (editor-set-save-point ed)
                    (echo-message! echo (string-append "Wrote " host ":" remote-path)))
                  (echo-error! echo (string-append "Failed to save " remote-path " to " host))))))
          ;; Save to existing local path
          (begin
            (run-hooks! 'before-save-hook app buf)
            (when (and (file-exists? path) (not (buffer-backup-done? buf)))
              (let ((backup-path (string-append path "~")))
                (guard (e (#t #f))
                  (copy-file path backup-path)
                  (buffer-backup-done?-set! buf #t))))
            (save-place-remember! path (editor-get-current-pos ed))
            (when (delete-trailing-whitespace-on-save)
              (let* ((text (editor-get-text ed))
                     (lines (string-split text #\newline))
                     (cleaned (map (lambda (line) (string-trim-right line)) lines))
                     (result (string-join cleaned "\n")))
                (unless (string=? text result)
                  (with-undo-action ed
                    (editor-delete-range ed 0 (string-length text))
                    (editor-insert-text ed 0 result)))))
            (let ((text (editor-get-text ed)))
              (when (and (require-final-newline)
                         (> (string-length text) 0)
                         (not (char=? (string-ref text (- (string-length text) 1)) #\newline)))
                (editor-append-text ed "\n")
                (set! text (editor-get-text ed)))
              (write-string-to-file path text)
              (editor-set-save-point ed)
              (update-buffer-mod-time! buf)
              (let ((auto-save-path (make-auto-save-path path)))
                (when (file-exists? auto-save-path)
                  (delete-file auto-save-path)))
              (echo-message! echo (string-append "Wrote " path))
              (run-hooks! 'after-save-hook app buf))))
        ;; No path: prompt for one
        (let* ((fr (app-state-frame app))
               (row (- (frame-height fr) 1))
               (width (frame-width fr))
               (filename (echo-read-string echo "Write file: " row width)))
          (when (and filename (> (string-length filename) 0))
            (buffer-file-path-set! buf filename)
            (buffer-name-set! buf (path-strip-directory filename))
            (let ((text (editor-get-text ed)))
              (write-string-to-file filename text)
              (editor-set-save-point ed)
              (echo-message! echo (string-append "Wrote " filename))))))))

  (define (cmd-write-file app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (filename (echo-read-string echo "Write file: " row width)))
      (when (and filename (> (string-length filename) 0))
        (let* ((buf (current-buffer-from-app app))
               (ed (current-editor app))
               (text (editor-get-text ed)))
          (buffer-file-path-set! buf filename)
          (buffer-name-set! buf (path-strip-directory filename))
          (write-string-to-file filename text)
          (editor-set-save-point ed)
          (echo-message! echo (string-append "Wrote " filename))))))

  (define (cmd-revert-buffer app)
    (let* ((buf (current-buffer-from-app app))
           (path (buffer-file-path buf))
           (echo (app-state-echo app)))
      (if (and path (file-exists? path))
        (let* ((ed (current-editor app))
               (text (read-file-as-string path)))
          (when text
            (editor-set-text ed text)
            (editor-set-save-point ed)
            (editor-goto-pos ed 0)
            (update-buffer-mod-time! buf)
            (echo-message! echo (string-append "Reverted " path))))
        (echo-error! echo "Buffer is not visiting a file"))))

  ;;;============================================================================
  ;;; Buffer commands
  ;;;============================================================================
  (define (cmd-switch-buffer app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (cur-name (buffer-name (current-buffer-from-app app)))
           (names (map buffer-name (buffer-list)))
           (other-names (filter (lambda (n) (not (string=? n cur-name))) names))
           (completions (append other-names (list cur-name)))
           (name (echo-read-string-with-completion echo "Switch to buffer: "
                    completions row width)))
      (when (and name (> (string-length name) 0))
        (let ((buf (buffer-by-name name)))
          (if buf
            (let ((ed (current-editor app)))
              (buffer-attach! ed buf)
              (edit-window-buffer-set! (current-window fr) buf))
            (echo-error! echo (string-append "No buffer: " name)))))))

  (define (cmd-kill-buffer-cmd app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (cur-buf (current-buffer-from-app app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (names (map buffer-name (buffer-list)))
           (name (echo-read-string-with-completion echo
                    (string-append "Kill buffer (" (buffer-name cur-buf) "): ")
                    names row width)))
      (when name
        (let* ((target-name (if (string=? name "") (buffer-name cur-buf) name))
               (buf (buffer-by-name target-name)))
          (if buf
            (let ((ed (current-editor app)))
              (if (<= (length (buffer-list)) 1)
                (echo-error! echo "Can't kill last buffer")
                (if (and (buffer-file-path buf)
                         (editor-get-modify? ed)
                         (eq? buf (current-buffer-from-app app))
                         (let ((answer (echo-read-string echo
                                         (string-append "Buffer " target-name
                                           " modified; kill anyway? (yes/no) ")
                                         row width)))
                           (not (and answer (or (string=? answer "yes")
                                               (string=? answer "y"))))))
                  (echo-message! echo "Cancelled")
                  (begin
                    (run-hooks! 'kill-buffer-hook app buf)
                    (when (eq? buf (current-buffer-from-app app))
                      (let ((other (let loop ((bs (buffer-list)))
                                     (cond ((null? bs) #f)
                                           ((eq? (car bs) buf) (loop (cdr bs)))
                                           (else (car bs))))))
                        (when other
                          (buffer-attach! ed other)
                          (edit-window-buffer-set! (current-window fr) other))))
                    (hash-remove! *dired-entries* buf)
                    (let ((rs (hash-get *repl-state* buf)))
                      (when rs
                        (repl-stop! rs)
                        (hash-remove! *repl-state* buf)))
                    (hash-remove! (eshell-state) buf)
                    (let ((ss (hash-get (shell-state-table) buf)))
                      (when ss
                        (shell-stop! ss)
                        (hash-remove! (shell-state-table) buf)))
                    (let ((cs (hash-get (chat-state-map) buf)))
                      (when cs
                        (chat-stop! cs)
                        (hash-remove! (chat-state-map) buf)))
                    (buffer-kill! ed buf)
                    (echo-message! echo (string-append "Killed " target-name))))))
            (echo-error! echo (string-append "No buffer: " target-name)))))))

  ;;;============================================================================
  ;;; Window commands
  ;;;============================================================================
  (define (setup-new-editor-defaults! ed)
    (editor-style-set-foreground ed STYLE_DEFAULT #xd8d8d8)
    (editor-style-set-background ed STYLE_DEFAULT #x181818)
    (send-message ed SCI_STYLECLEARALL)
    (editor-set-caret-foreground ed #xFFFFFF)
    (send-message ed SCI_SETMARGINTYPEN 0 SC_MARGIN_NUMBER)
    (send-message ed SCI_SETMARGINWIDTHN 0 5)
    (editor-style-set-foreground ed STYLE_LINENUMBER #x808080)
    (editor-style-set-background ed STYLE_LINENUMBER #x181818))

  (define *winner-max-history* 50)

  (define (winner-save-config! app)
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (num-wins (length wins))
           (current-idx (frame-current-idx fr))
           (buffers (map (lambda (w)
                           (let ((buf (edit-window-buffer w)))
                             (if buf (buffer-name buf) "*scratch*")))
                         wins))
           (config (list num-wins current-idx buffers))
           (history (app-state-winner-history app)))
      (unless (and (not (null? history))
                   (equal? config (car history)))
        (let ((idx (app-state-winner-history-idx app)))
          (when (> idx 0)
            (set! history (list-tail history idx))
            (app-state-winner-history-idx-set! app 0)))
        (let ((new-history (cons config history)))
          (app-state-winner-history-set! app
            (if (> (length new-history) *winner-max-history*)
              (let loop ((lst new-history) (n *winner-max-history*) (acc '()))
                (if (or (null? lst) (<= n 0))
                  (reverse acc)
                  (loop (cdr lst) (- n 1) (cons (car lst) acc))))
              new-history))))))

  (define (cmd-split-window app)
    (winner-save-config! app)
    (let* ((fr (app-state-frame app))
           (cur-buf (edit-window-buffer (current-window fr)))
           (new-ed (frame-split! fr)))
      (setup-new-editor-defaults! new-ed)
      (run-hooks! 'post-buffer-attach-hook new-ed cur-buf)))

  (define (cmd-split-window-right app)
    (winner-save-config! app)
    (let* ((fr (app-state-frame app))
           (cur-buf (edit-window-buffer (current-window fr)))
           (new-ed (frame-split-right! fr)))
      (setup-new-editor-defaults! new-ed)
      (run-hooks! 'post-buffer-attach-hook new-ed cur-buf)))

  (define (cmd-other-window app)
    (frame-other-window! (app-state-frame app)))

  (define (cmd-delete-window app)
    (if (> (length (frame-windows (app-state-frame app))) 1)
      (begin
        (winner-save-config! app)
        (frame-delete-window! (app-state-frame app)))
      (echo-error! (app-state-echo app) "Can't delete sole window")))

  (define (cmd-delete-other-windows app)
    (winner-save-config! app)
    (frame-delete-other-windows! (app-state-frame app)))

  (define (cmd-select-window-by-number app n)
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (count (length wins))
           (idx (- n 1)))
      (if (< idx count)
        (begin
          (frame-current-idx-set! fr idx)
          (echo-message! (app-state-echo app)
            (string-append "Window " (number->string n))))
        (echo-error! (app-state-echo app)
          (string-append "No window " (number->string n)
                         " (have " (number->string count) ")")))))

  (define (cmd-select-window-1 app) (cmd-select-window-by-number app 1))
  (define (cmd-select-window-2 app) (cmd-select-window-by-number app 2))
  (define (cmd-select-window-3 app) (cmd-select-window-by-number app 3))
  (define (cmd-select-window-4 app) (cmd-select-window-by-number app 4))
  (define (cmd-select-window-5 app) (cmd-select-window-by-number app 5))
  (define (cmd-select-window-6 app) (cmd-select-window-by-number app 6))
  (define (cmd-select-window-7 app) (cmd-select-window-by-number app 7))
  (define (cmd-select-window-8 app) (cmd-select-window-by-number app 8))
  (define (cmd-select-window-9 app) (cmd-select-window-by-number app 9))

  ;;;============================================================================
  ;;; Search highlighting
  ;;;============================================================================
  (define *search-indicator* 8)
  (define SCI_INDICSETALPHA 2523)

  (define (setup-search-indicator! ed)
    (send-message ed SCI_INDICSETSTYLE *search-indicator* INDIC_ROUNDBOX)
    (send-message ed SCI_INDICSETFORE *search-indicator* #xFFCC00)
    (send-message ed SCI_INDICSETUNDER *search-indicator* 1)
    (send-message ed SCI_INDICSETALPHA *search-indicator* 80))

  (define highlight-all-matches!
    (case-lambda
      ((ed query) (highlight-all-matches! ed query 0))
      ((ed query flags)
       (setup-search-indicator! ed)
       (clear-search-highlights! ed)
       (when (> (string-length query) 0)
         (let ((len (editor-get-text-length ed)))
           (send-message ed SCI_SETINDICATORCURRENT *search-indicator*)
           (send-message ed SCI_SETSEARCHFLAGS flags)
           (let loop ((start 0))
             (when (< start len)
               (send-message ed SCI_SETTARGETSTART start)
               (send-message ed SCI_SETTARGETEND len)
               (let ((found (send-message/string ed SCI_SEARCHINTARGET query)))
                 (when (>= found 0)
                   (let ((match-end (send-message ed SCI_GETTARGETEND)))
                     (when (> match-end found)
                       (send-message ed SCI_INDICATORFILLRANGE found (- match-end found)))
                     (loop (+ (max found match-end) 1))))))))))))

  (define (clear-search-highlights! ed)
    (let ((len (editor-get-text-length ed)))
      (when (> len 0)
        (send-message ed SCI_SETINDICATORCURRENT *search-indicator*)
        (send-message ed SCI_INDICATORCLEARRANGE 0 len))))

  ;;;============================================================================
  ;;; Search
  ;;;============================================================================
  (define (search-forward-impl! app query)
    (let* ((echo (app-state-echo app))
           (ed (current-editor app)))
      (app-state-last-search-set! app query)
      (highlight-all-matches! ed query)
      (let ((pos (editor-get-current-pos ed))
            (len (editor-get-text-length ed)))
        (send-message ed SCI_SETTARGETSTART pos)
        (send-message ed SCI_SETTARGETEND len)
        (send-message ed SCI_SETSEARCHFLAGS 0)
        (let ((found (send-message/string ed SCI_SEARCHINTARGET query)))
          (if (>= found 0)
            (begin
              (editor-goto-pos ed found)
              (editor-set-selection ed found (+ found (string-length query)))
              (pulse-line! ed (editor-line-from-position ed found)))
            (begin
              (send-message ed SCI_SETTARGETSTART 0)
              (send-message ed SCI_SETTARGETEND len)
              (let ((found2 (send-message/string ed SCI_SEARCHINTARGET query)))
                (if (>= found2 0)
                  (begin
                    (editor-goto-pos ed found2)
                    (editor-set-selection ed found2 (+ found2 (string-length query)))
                    (pulse-line! ed (editor-line-from-position ed found2))
                    (echo-message! echo "Wrapped"))
                  (echo-error! echo (string-append "Not found: " query))))))))))

  (define (search-forward-regexp-impl! app pattern)
    (let* ((echo (app-state-echo app))
           (ed (current-editor app)))
      (app-state-last-search-set! app pattern)
      (highlight-all-matches! ed pattern SCFIND_REGEXP)
      (let ((pos (editor-get-current-pos ed))
            (len (editor-get-text-length ed)))
        (send-message ed SCI_SETTARGETSTART pos)
        (send-message ed SCI_SETTARGETEND len)
        (send-message ed SCI_SETSEARCHFLAGS SCFIND_REGEXP)
        (let ((found (send-message/string ed SCI_SEARCHINTARGET pattern)))
          (if (>= found 0)
            (let ((match-end (send-message ed SCI_GETTARGETEND)))
              (editor-goto-pos ed found)
              (editor-set-selection ed found match-end)
              (pulse-line! ed (editor-line-from-position ed found)))
            (begin
              (send-message ed SCI_SETTARGETSTART 0)
              (send-message ed SCI_SETTARGETEND len)
              (let ((found2 (send-message/string ed SCI_SEARCHINTARGET pattern)))
                (if (>= found2 0)
                  (let ((match-end2 (send-message ed SCI_GETTARGETEND)))
                    (editor-goto-pos ed found2)
                    (editor-set-selection ed found2 match-end2)
                    (pulse-line! ed (editor-line-from-position ed found2))
                    (echo-message! echo "Wrapped"))
                  (echo-error! echo
                    (string-append "No regexp match: " pattern))))))))))

  (define (cmd-search-forward app)
    (let ((default (or (app-state-last-search app) "")))
      (if (and (eq? (app-state-last-command app) 'search-forward)
               (> (string-length default) 0))
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed)))
          (editor-goto-pos ed (+ pos 1))
          (search-forward-impl! app default))
        (let* ((echo (app-state-echo app))
               (fr (app-state-frame app))
               (row (- (frame-height fr) 1))
               (width (frame-width fr))
               (prompt (if (string=? default "")
                         "Search: "
                         (string-append "Search [" default "]: ")))
               (input (echo-read-string echo prompt row width)))
          (when input
            (let ((query (if (string=? input "") default input)))
              (when (> (string-length query) 0)
                (search-forward-impl! app query))))))))

  (define (cmd-search-backward app)
    (let ((default (or (app-state-last-search app) "")))
      (if (and (eq? (app-state-last-command app) 'search-backward)
               (> (string-length default) 0))
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed)))
          (when (> pos 0) (editor-goto-pos ed (- pos 1)))
          (search-backward-impl! app default))
        (let* ((echo (app-state-echo app))
               (fr (app-state-frame app))
               (row (- (frame-height fr) 1))
               (width (frame-width fr))
               (prompt (if (string=? default "")
                         "Search backward: "
                         (string-append "Search backward [" default "]: ")))
               (input (echo-read-string echo prompt row width)))
          (when input
            (let ((query (if (string=? input "") default input)))
              (when (> (string-length query) 0)
                (search-backward-impl! app query))))))))

  (define (search-backward-impl! app query)
    (let* ((echo (app-state-echo app))
           (ed (current-editor app)))
      (app-state-last-search-set! app query)
      (highlight-all-matches! ed query)
      (let ((pos (editor-get-current-pos ed))
            (len (editor-get-text-length ed)))
        (send-message ed SCI_SETTARGETSTART pos)
        (send-message ed SCI_SETTARGETEND 0)
        (send-message ed SCI_SETSEARCHFLAGS 0)
        (let ((found (send-message/string ed SCI_SEARCHINTARGET query)))
          (if (>= found 0)
            (begin
              (editor-goto-pos ed found)
              (editor-set-selection ed found (+ found (string-length query)))
              (pulse-line! ed (editor-line-from-position ed found)))
            (begin
              (send-message ed SCI_SETTARGETSTART len)
              (send-message ed SCI_SETTARGETEND 0)
              (let ((found2 (send-message/string ed SCI_SEARCHINTARGET query)))
                (if (>= found2 0)
                  (begin
                    (editor-goto-pos ed found2)
                    (editor-set-selection ed found2 (+ found2 (string-length query)))
                    (pulse-line! ed (editor-line-from-position ed found2))
                    (echo-message! echo "Wrapped"))
                  (echo-error! echo (string-append "Not found: " query))))))))))

  ;;;============================================================================
  ;;; Eshell commands
  ;;;============================================================================
  (define eshell-buffer-name "*eshell*")

  (define (cmd-eshell app)
    (let ((existing (buffer-by-name eshell-buffer-name)))
      (if existing
        (let* ((fr (app-state-frame app))
               (ed (current-editor app)))
          (buffer-attach! ed existing)
          (edit-window-buffer-set! (current-window fr) existing)
          (echo-message! (app-state-echo app) eshell-buffer-name))
        (let* ((fr (app-state-frame app))
               (ed (current-editor app))
               (buf (buffer-create! eshell-buffer-name ed #f)))
          (buffer-lexer-lang-set! buf 'eshell)
          (buffer-attach! ed buf)
          (edit-window-buffer-set! (current-window fr) buf)
          (gsh-eshell-init-buffer! buf)
          (let ((welcome (string-append "gsh \x2014; Gerbil Shell\n"
                                         "Type commands or 'exit' to close.\n\n"
                                         (gsh-eshell-get-prompt buf))))
            (editor-set-text ed welcome)
            (let ((len (editor-get-text-length ed)))
              (editor-goto-pos ed len)))
          (echo-message! (app-state-echo app) "gsh started")))))

  (define (cmd-eshell-send app)
    (let* ((buf (current-buffer-from-app app))
           (env (hash-get (gsh-eshell-state) buf)))
      (if (not env)
        (cmd-eshell-send-legacy app)
        (let* ((ed (current-editor app))
               (all-text (editor-get-text ed))
               (cur-prompt (gsh-eshell-prompt-string))
               (prompt-pos (gsh-eshell-find-last-prompt all-text))
               (end-pos (string-length all-text))
               (input (if (and prompt-pos (> end-pos (+ prompt-pos (string-length cur-prompt))))
                        (substring all-text (+ prompt-pos (string-length cur-prompt)) end-pos)
                        "")))
          (let ((trimmed-input (safe-string-trim-both input)))
            (when (> (string-length trimmed-input) 0)
              (gsh-history-add! trimmed-input (current-directory))))
          (editor-append-text ed "\n")
          (let-values (((output new-cwd) (gsh-eshell-process-input input buf)))
            (cond
              ((eq? output 'clear)
               (let ((new-prompt (gsh-eshell-get-prompt buf)))
                 (editor-set-text ed new-prompt)
                 (editor-goto-pos ed (editor-get-text-length ed))))
              ((eq? output 'exit)
               (cmd-kill-buffer-cmd app))
              (else
               (when (and (string? output) (> (string-length output) 0))
                 (editor-append-text ed output))
               (let ((new-prompt (gsh-eshell-get-prompt buf)))
                 (editor-append-text ed new-prompt))
               (editor-goto-pos ed (editor-get-text-length ed))
               (editor-scroll-caret ed))))))))

  (define (cmd-eshell-send-legacy app)
    (let* ((buf (current-buffer-from-app app))
           (cwd (hash-get (eshell-state) buf)))
      (when cwd
        (let* ((ed (current-editor app))
               (all-text (editor-get-text ed))
               (prompt-pos (eshell-find-last-prompt all-text))
               (end-pos (string-length all-text))
               (input (if (and prompt-pos (> end-pos (+ prompt-pos (string-length (eshell-prompt)))))
                        (substring all-text (+ prompt-pos (string-length (eshell-prompt))) end-pos)
                        "")))
          (let ((trimmed-input (safe-string-trim-both input)))
            (when (> (string-length trimmed-input) 0)
              (gsh-history-add! trimmed-input cwd)))
          (editor-append-text ed "\n")
          (let-values (((output new-cwd) (eshell-process-input input cwd)))
            (hash-put! (eshell-state) buf new-cwd)
            (cond
              ((eq? output 'clear)
               (editor-set-text ed (eshell-prompt))
               (editor-goto-pos ed (editor-get-text-length ed)))
              ((eq? output 'exit)
               (cmd-kill-buffer-cmd app))
              (else
               (when (and (string? output) (> (string-length output) 0))
                 (editor-append-text ed output))
               (editor-append-text ed (eshell-prompt))
               (editor-goto-pos ed (editor-get-text-length ed))
               (editor-scroll-caret ed))))))))

  (define (eshell-find-last-prompt text)
    (let ((prompt (eshell-prompt))
          (prompt-len (string-length (eshell-prompt))))
      (let loop ((pos (- (string-length text) prompt-len)))
        (cond
          ((< pos 0) #f)
          ((string=? (substring text pos (+ pos prompt-len)) prompt) pos)
          (else (loop (- pos 1)))))))

  (define (gsh-eshell-find-last-prompt text)
    (let ((prompt (gsh-eshell-prompt-string))
          (prompt-len (string-length (gsh-eshell-prompt-string))))
      (let loop ((pos (- (string-length text) prompt-len)))
        (cond
          ((< pos 0) #f)
          ((string=? (substring text pos (+ pos prompt-len)) prompt) pos)
          (else (loop (- pos 1)))))))

  ;;;============================================================================
  ;;; Shell commands
  ;;;============================================================================
  (define shell-buffer-name "*shell*")

  (define (cmd-shell app)
    (let ((existing (buffer-by-name shell-buffer-name)))
      (if existing
        (let* ((fr (app-state-frame app))
               (ed (current-editor app)))
          (buffer-attach! ed existing)
          (edit-window-buffer-set! (current-window fr) existing)
          (echo-message! (app-state-echo app) shell-buffer-name))
        (let* ((fr (app-state-frame app))
               (ed (current-editor app))
               (buf (buffer-create! shell-buffer-name ed #f)))
          (buffer-lexer-lang-set! buf 'shell)
          (buffer-attach! ed buf)
          (edit-window-buffer-set! (current-window fr) buf)
          (guard (e (#t
                     (let ((msg (call-with-string-output-port
                                  (lambda (p) (display-condition e p)))))
                       (jemacs-log! "cmd-shell: gsh init failed: " msg)
                       (echo-error! (app-state-echo app)
                         (string-append "Shell failed: " msg)))))
            (let ((ss (shell-start!)))
              (hash-put! (shell-state-table) buf ss)
              (let ((prompt (shell-prompt ss)))
                (editor-set-text ed prompt)
                (shell-state-prompt-pos-set! ss (string-length prompt))
                (editor-goto-pos ed (string-length prompt))
                (editor-scroll-caret ed)))
            (echo-message! (app-state-echo app) "gsh started"))))))

  (define (cmd-shell-send app)
    (let* ((buf (current-buffer-from-app app))
           (ss (hash-get (shell-state-table) buf)))
      (when ss
        (if (shell-pty-busy? ss)
          (shell-send-input! ss "\n")
          (let* ((ed (current-editor app))
                 (all-text (editor-get-text ed))
                 (prompt-pos (shell-state-prompt-pos ss))
                 (end-pos (string-length all-text))
                 (input (if (> end-pos prompt-pos)
                          (substring all-text prompt-pos end-pos)
                          "")))
            (let ((trimmed-input (safe-string-trim-both input)))
              (when (> (string-length trimmed-input) 0)
                (gsh-history-add! trimmed-input (current-directory))))
            (editor-append-text ed "\n")
            (let-values (((mode output new-cwd) (shell-execute-async! input ss)))
              (case mode
                ((sync)
                 (cond
                   ((and (string? output) (> (string-length output) 0))
                    (editor-append-text ed output)
                    (unless (char=? (string-ref output (- (string-length output) 1)) #\newline)
                      (editor-append-text ed "\n"))))
                 (when (hash-get (shell-state-table) buf)
                   (let ((prompt (shell-prompt ss)))
                     (editor-append-text ed prompt)
                     (shell-state-prompt-pos-set! ss (editor-get-text-length ed))
                     (editor-goto-pos ed (editor-get-text-length ed))
                     (editor-scroll-caret ed))))
                ((async)
                 (editor-goto-pos ed (editor-get-text-length ed))
                 (editor-scroll-caret ed))
                ((special)
                 (cond
                   ((eq? output 'clear)
                    (editor-set-text ed "")
                    (let ((prompt (shell-prompt ss)))
                      (editor-append-text ed prompt)
                      (shell-state-prompt-pos-set! ss (editor-get-text-length ed))
                      (editor-goto-pos ed (editor-get-text-length ed))
                      (editor-scroll-caret ed)))
                   ((eq? output 'exit)
                    (shell-stop! ss)
                    (hash-remove! (shell-state-table) buf)
                    (cmd-kill-buffer-cmd app)
                    (echo-message! (app-state-echo app) "Shell exited")))))))))))

  ;;;============================================================================
  ;;; AI Chat commands
  ;;;============================================================================
  (define chat-buffer-name "*AI Chat*")
  (define chat-prompt "\nYou: ")

  (define (cmd-chat app)
    (let ((existing (buffer-by-name chat-buffer-name)))
      (if existing
        (let* ((fr (app-state-frame app))
               (ed (current-editor app)))
          (buffer-attach! ed existing)
          (edit-window-buffer-set! (current-window fr) existing)
          (echo-message! (app-state-echo app) chat-buffer-name))
        (let* ((fr (app-state-frame app))
               (ed (current-editor app))
               (buf (buffer-create! chat-buffer-name ed #f)))
          (buffer-lexer-lang-set! buf 'chat)
          (buffer-attach! ed buf)
          (edit-window-buffer-set! (current-window fr) buf)
          (let ((cs (chat-start! (current-directory))))
            (hash-put! (chat-state-map) buf cs)
            (let ((greeting "Claude AI Chat \x2014; Type your message and press Enter.\n\nYou: "))
              (editor-set-text ed greeting)
              (chat-state-prompt-pos-set! cs (string-length greeting))
              (editor-goto-pos ed (string-length greeting))
              (editor-scroll-caret ed)))
          (echo-message! (app-state-echo app) "AI Chat started")))))

  (define (cmd-chat-send app)
    (let* ((buf (current-buffer-from-app app))
           (cs (hash-get (chat-state-map) buf)))
      (when cs
        (if (chat-busy? cs)
          (echo-message! (app-state-echo app) "Waiting for response...")
          (let* ((ed (current-editor app))
                 (all-text (editor-get-text ed))
                 (prompt-pos (chat-state-prompt-pos cs))
                 (end-pos (string-length all-text))
                 (input (if (> end-pos prompt-pos)
                          (substring all-text prompt-pos end-pos)
                          "")))
            (when (> (string-length (string-trim input)) 0)
              (editor-append-text ed "\n\nClaude: ")
              (chat-state-prompt-pos-set! cs (editor-get-text-length ed))
              (editor-goto-pos ed (editor-get-text-length ed))
              (editor-scroll-caret ed)
              (chat-send! cs input)))))))

  ;;;============================================================================
  ;;; Terminal commands (gsh-backed)
  ;;;============================================================================
  (define terminal-buffer-counter 0)

  (define (cmd-term app)
    (let* ((fr (app-state-frame app))
           (ed (current-editor app))
           (name (begin
                   (set! terminal-buffer-counter (+ terminal-buffer-counter 1))
                   (if (= terminal-buffer-counter 1)
                     "*terminal*"
                     (string-append "*terminal-"
                                    (number->string terminal-buffer-counter) "*"))))
           (buf (buffer-create! name ed #f)))
      (buffer-lexer-lang-set! buf 'terminal)
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (setup-terminal-styles! ed)
      (guard (e (#t
                 (let ((msg (call-with-string-output-port
                              (lambda (p) (display-condition e p)))))
                   (jemacs-log! "cmd-term: gsh init failed: " msg)
                   (echo-error! (app-state-echo app)
                     (string-append "Terminal failed: " msg)))))
        (let ((ts (terminal-start!)))
          (hash-put! *terminal-state* buf ts)
          (let* ((raw-prompt (terminal-prompt-raw ts))
                 (segments (parse-ansi-segments raw-prompt)))
            (editor-set-text ed "")
            (let ((prompt-len (terminal-insert-styled! ed segments 0)))
              (terminal-state-prompt-pos-set! ts prompt-len)
              (editor-goto-pos ed prompt-len)
              (editor-scroll-caret ed))))
        (echo-message! (app-state-echo app) (string-append name " started")))))

  (define (cmd-terminal-send app)
    (let* ((buf (current-buffer-from-app app))
           (ts (hash-get *terminal-state* buf)))
      (when ts
        (if (terminal-pty-busy? ts)
          (terminal-send-input! ts "\n")
          (let* ((ed (current-editor app))
                 (text (editor-get-text ed))
                 (text-len (string-length text))
                 (prompt-pos (terminal-state-prompt-pos ts))
                 (input (if (< prompt-pos text-len)
                          (substring text prompt-pos text-len)
                          "")))
            (editor-append-text ed "\n")
            (let-values (((mode output new-cwd) (terminal-execute-async! input ts)))
              (case mode
                ((sync)
                 (when (and (string? output) (> (string-length output) 0))
                   (let* ((segments (parse-ansi-segments output))
                          (start-pos (editor-get-text-length ed)))
                     (terminal-insert-styled! ed segments start-pos))
                   (unless (char=? (string-ref output (- (string-length output) 1)) #\newline)
                     (editor-append-text ed "\n")))
                 (when (hash-get *terminal-state* buf)
                   (let* ((raw-prompt (terminal-prompt-raw ts))
                          (segments (parse-ansi-segments raw-prompt))
                          (start-pos (editor-get-text-length ed)))
                     (terminal-insert-styled! ed segments start-pos)
                     (terminal-state-prompt-pos-set! ts (editor-get-text-length ed))
                     (editor-goto-pos ed (editor-get-text-length ed))
                     (editor-scroll-caret ed))))
                ((async)
                 (editor-goto-pos ed (editor-get-text-length ed))
                 (editor-scroll-caret ed))
                ((special)
                 (cond
                   ((eq? output 'clear)
                    (editor-set-text ed "")
                    (let* ((raw-prompt (terminal-prompt-raw ts))
                           (segments (parse-ansi-segments raw-prompt)))
                      (editor-set-text ed "")
                      (let ((prompt-len (terminal-insert-styled! ed segments 0)))
                        (terminal-state-prompt-pos-set! ts prompt-len)
                        (editor-goto-pos ed prompt-len)
                        (editor-scroll-caret ed))))
                   ((eq? output 'exit)
                    (terminal-stop! ts)
                    (hash-remove! *terminal-state* buf)
                    (cmd-kill-buffer-cmd app)
                    (echo-message! (app-state-echo app) "Terminal exited")))))))))))

  (define (cmd-term-interrupt app)
    (let* ((buf (current-buffer-from-app app))
           (ts (and (terminal-buffer? buf) (hash-get *terminal-state* buf))))
      (cond
        ((not ts)
         (let ((ss (and (shell-buffer? buf) (hash-get (shell-state-table) buf))))
           (if (and ss (shell-pty-busy? ss))
             (begin
               (shell-interrupt! ss)
               (echo-message! (app-state-echo app) "Interrupt sent"))
             (echo-message! (app-state-echo app) "Not in a terminal buffer"))))
        ((terminal-pty-busy? ts)
         (terminal-interrupt! ts)
         (let ((ed (current-editor app)))
           (editor-append-text ed "^C\n")
           (editor-goto-pos ed (editor-get-text-length ed))
           (editor-scroll-caret ed)))
        (else
         (let* ((ed (current-editor app))
                (raw-prompt (terminal-prompt-raw ts))
                (segments (parse-ansi-segments raw-prompt)))
           (editor-append-text ed "^C\n")
           (let ((start-pos (editor-get-text-length ed)))
             (terminal-insert-styled! ed segments start-pos))
           (terminal-state-prompt-pos-set! ts (editor-get-text-length ed))
           (editor-goto-pos ed (editor-get-text-length ed))
           (editor-scroll-caret ed))))))

  (define (cmd-term-send-eof app)
    (let ((buf (current-buffer-from-app app)))
      (cond
        ((and (terminal-buffer? buf) (hash-get *terminal-state* buf))
         (let ((ts (hash-get *terminal-state* buf)))
           (let* ((ed (current-editor app))
                  (text (editor-get-text ed))
                  (text-len (string-length text))
                  (prompt-pos (terminal-state-prompt-pos ts))
                  (input (if (< prompt-pos text-len)
                           (substring text prompt-pos text-len)
                           "")))
             (if (string=? input "")
               (begin
                 (terminal-stop! ts)
                 (hash-remove! *terminal-state* buf)
                 (cmd-kill-buffer-cmd app)
                 (echo-message! (app-state-echo app) "Terminal exited"))
               (editor-send-key ed SCK_DELETE)))))
        ((and (shell-buffer? buf) (hash-get (shell-state-table) buf))
         (let ((ss (hash-get (shell-state-table) buf)))
           (let* ((ed (current-editor app))
                  (text (editor-get-text ed))
                  (text-len (string-length text))
                  (prompt-pos (shell-state-prompt-pos ss))
                  (input (if (< prompt-pos text-len)
                           (substring text prompt-pos text-len)
                           "")))
             (if (string=? input "")
               (begin
                 (shell-stop! ss)
                 (hash-remove! (shell-state-table) buf)
                 (cmd-kill-buffer-cmd app)
                 (echo-message! (app-state-echo app) "Shell exited"))
               (editor-send-key ed SCK_DELETE)))))
        ((and (gsh-eshell-buffer? buf) (hash-get (gsh-eshell-state) buf))
         (begin
           (hash-remove! (gsh-eshell-state) buf)
           (cmd-kill-buffer-cmd app)
           (echo-message! (app-state-echo app) "Eshell exited")))
        (else
          (cmd-delete-char app)))))

  (define (cmd-term-send-tab app)
    (let* ((buf (current-buffer-from-app app))
           (ts (and (terminal-buffer? buf) (hash-get *terminal-state* buf))))
      (if ts
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed)))
          (editor-insert-text ed pos "\t")
          (editor-goto-pos ed (+ pos 1)))
        (editor-send-key (current-editor app) (char->integer #\tab)))))

  ;;;============================================================================
  ;;; Dired support
  ;;;============================================================================
  (define (dired-open-directory! app dir-path)
    (let* ((dir (strip-trailing-slash dir-path))
           (name (string-append dir "/"))
           (fr (app-state-frame app))
           (ed (current-editor app))
           (buf (buffer-create! name ed dir)))
      (buffer-lexer-lang-set! buf 'dired)
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (let-values (((text entries) (dired-format-listing dir)))
        (editor-set-text ed text)
        (editor-set-save-point ed)
        (editor-goto-pos ed 0)
        (editor-send-key ed SCK_DOWN)
        (editor-send-key ed SCK_DOWN)
        (editor-send-key ed SCK_DOWN)
        (editor-send-key ed SCK_HOME)
        (hash-put! *dired-entries* buf entries))
      (echo-message! (app-state-echo app) (string-append "Directory: " dir))))

  (define (cmd-dired-find-file app)
    (let* ((buf (current-buffer-from-app app))
           (ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (entries (hash-get *dired-entries* buf)))
      (when entries
        (let ((idx (- line 3)))
          (if (or (< idx 0) (>= idx (vector-length entries)))
            (echo-message! (app-state-echo app) "No file on this line")
            (let ((full-path (vector-ref entries idx)))
              (guard (e (#t
                         (echo-error! (app-state-echo app)
                           (string-append "Error: "
                             (call-with-string-output-port
                               (lambda (p) (display-condition e p)))))))
                (cond
                  ((file-directory? full-path)
                   (dired-open-directory! app full-path))
                  ((let ((ext (string-downcase (path-extension full-path))))
                     (member ext '(".png" ".jpg" ".jpeg" ".gif" ".bmp"
                                   ".webp" ".svg" ".ico" ".tiff" ".tif"
                                   ".pdf" ".zip" ".gz" ".tar" ".exe"
                                   ".so" ".o" ".a" ".class" ".pyc")))
                   (echo-message! (app-state-echo app)
                     (string-append "Binary file: " full-path)))
                  (else
                   (let* ((fname (path-strip-directory full-path))
                          (fr (app-state-frame app))
                          (new-buf (buffer-create! fname ed full-path)))
                     (buffer-attach! ed new-buf)
                     (edit-window-buffer-set! (current-window fr) new-buf)
                     (let ((text (read-file-as-string full-path)))
                       (when text
                         (editor-set-text ed text)
                         (editor-set-save-point ed)
                         (editor-goto-pos ed 0)))
                     (when (gerbil-file-extension? full-path)
                       (setup-gerbil-highlighting! ed)
                       (send-message ed SCI_SETMARGINTYPEN 0 SC_MARGIN_NUMBER)
                       (send-message ed SCI_SETMARGINWIDTHN 0 4))
                     (echo-message! (app-state-echo app)
                       (string-append "Opened: " full-path))))))))))))

  ;;;============================================================================
  ;;; REPL commands
  ;;;============================================================================
  (define repl-buffer-name "*REPL*")

  (define (cmd-repl app)
    (let ((existing (buffer-by-name repl-buffer-name)))
      (if existing
        (let* ((fr (app-state-frame app))
               (ed (current-editor app)))
          (buffer-attach! ed existing)
          (edit-window-buffer-set! (current-window fr) existing)
          (echo-message! (app-state-echo app) repl-buffer-name))
        (let* ((fr (app-state-frame app))
               (ed (current-editor app))
               (buf (buffer-create! repl-buffer-name ed #f)))
          (buffer-lexer-lang-set! buf 'repl)
          (buffer-attach! ed buf)
          (edit-window-buffer-set! (current-window fr) buf)
          (let ((rs (repl-start!)))
            (hash-put! *repl-state* buf rs)
            (editor-set-text ed (repl-prompt))
            (let ((len (editor-get-text-length ed)))
              (repl-state-prompt-pos-set! rs len)
              (editor-goto-pos ed len)))
          (echo-message! (app-state-echo app) "REPL started")))))

  (define (cmd-repl-send app)
    (let* ((buf (current-buffer-from-app app))
           (rs (hash-get *repl-state* buf)))
      (when rs
        (let* ((ed (current-editor app))
               (prompt-pos (repl-state-prompt-pos rs))
               (all-text (editor-get-text ed))
               (end-pos (string-length all-text))
               (input (if (> end-pos prompt-pos)
                        (substring all-text prompt-pos end-pos)
                        "")))
          (editor-append-text ed "\n")
          (repl-send! rs input)
          (repl-state-prompt-pos-set! rs (editor-get-text-length ed))))))

  ;;;============================================================================
  ;;; Mark ring
  ;;;============================================================================
  (define max-mark-ring-size 16)

  (define (push-mark-ring! app buf pos)
    (let* ((entry (cons (buffer-name buf) pos))
           (ring (app-state-mark-ring app))
           (new-ring (cons entry
                       (if (>= (length ring) max-mark-ring-size)
                         (let trim ((r ring) (n (- max-mark-ring-size 1)))
                           (if (or (null? r) (= n 0)) '()
                             (cons (car r) (trim (cdr r) (- n 1)))))
                         ring))))
      (app-state-mark-ring-set! app new-ring)))

  ;;;============================================================================
  ;;; Tab insertion command
  ;;;============================================================================
  (define (cmd-tab-to-tab-stop app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (col (editor-get-column ed pos))
           (tw (send-message ed SCI_GETTABWIDTH 0 0))
           (tw (if (> tw 0) tw 4))
           (use-tabs (= 1 (send-message ed SCI_GETUSETABS 0 0))))
      (if use-tabs
        (begin
          (editor-insert-text ed pos "\t")
          (editor-goto-pos ed (+ pos 1)))
        (let* ((next-stop (* (+ 1 (quotient col tw)) tw))
               (spaces (- next-stop col))
               (str (make-string spaces #\space)))
          (editor-insert-text ed pos str)
          (editor-goto-pos ed (+ pos spaces))))))

  ;;;============================================================================
  ;;; Selective undo (region undo)
  ;;;============================================================================
  (define (cmd-undo-region app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (echo (app-state-echo app)))
      (if (not mark)
        (cmd-undo app)
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (text-before (editor-get-text ed)))
          (if (not (editor-can-undo? ed))
            (echo-message! echo "No further undo information")
            (begin
              (editor-undo ed)
              (echo-message! echo
                (string-append "Undo (region " (number->string start)
                  "-" (number->string end) ")"))))))))

  ;;;============================================================================
  ;;; Side windows
  ;;;============================================================================
  (define *side-window-visible* #f)
  (define *side-window-buffer* #f)

  (define (cmd-display-buffer-in-side-window app)
    (let* ((ed (current-editor app))
           (fr (app-state-frame app))
           (buf (current-buffer-from-app app))
           (echo (app-state-echo app)))
      (if *side-window-visible*
        (begin
          (set! *side-window-visible* #f)
          (set! *side-window-buffer* #f)
          (frame-delete-other-windows! fr)
          (echo-message! echo "Side window closed"))
        (begin
          (set! *side-window-visible* #t)
          (set! *side-window-buffer* buf)
          (frame-split-right! fr)
          (echo-message! echo
            (string-append "Side: " (buffer-name buf)))))))

  (define (cmd-toggle-side-window app)
    (cmd-display-buffer-in-side-window app))

  ;;;============================================================================
  ;;; Info reader
  ;;;============================================================================
  (define *info-topics* (make-hash-table))

  (define (info-init-topics!)
    (hash-put! *info-topics* "top"
      (string-append
        "Jemacs Info\n"
        "===========\n\n"
        "* Commands::     List of all available commands\n"
        "* Keybindings::  Default key bindings\n"
        "* Org Mode::     Org mode documentation\n"
        "* Configuration:: Configuration options\n"
        "* About::        About jemacs\n"))
    (hash-put! *info-topics* "commands"
      (string-append
        "Commands\n"
        "========\n\n"
        "Use M-x to execute any command by name.\n"
        "Common commands:\n\n"
        "  find-file          Open a file (C-x C-f)\n"
        "  save-buffer        Save current file (C-x C-s)\n"
        "  switch-buffer      Switch buffer (C-x b)\n"
        "  kill-buffer        Close buffer (C-x k)\n"
        "  search-forward     Incremental search (C-s)\n"
        "  query-replace      Find and replace (M-%)\n"
        "  split-window       Split horizontally (C-x 2)\n"
        "  other-window       Switch window (C-x o)\n"
        "  magit-status       Git status (C-x g)\n"
        "  eshell             Open eshell (M-x eshell)\n"
        "  term               Open terminal (M-x term)\n"
        "  repl               Open REPL (M-x repl)\n"))
    (hash-put! *info-topics* "keybindings"
      (string-append
        "Keybindings\n"
        "===========\n\n"
        "Movement:\n"
        "  C-f/C-b      Forward/backward char\n"
        "  M-f/M-b      Forward/backward word\n"
        "  C-n/C-p      Next/previous line\n"
        "  C-a/C-e      Beginning/end of line\n"
        "  M-</M->      Beginning/end of buffer\n\n"
        "Editing:\n"
        "  C-d          Delete char\n"
        "  C-k          Kill line\n"
        "  C-w/M-w      Kill/copy region\n"
        "  C-y          Yank\n"
        "  C-/          Undo\n\n"
        "Files:\n"
        "  C-x C-f      Find file\n"
        "  C-x C-s      Save\n"
        "  C-x b        Switch buffer\n"
        "  C-x k        Kill buffer\n\n"
        "Windows:\n"
        "  C-x 2/3      Split horiz/vert\n"
        "  C-x 0/1      Delete window/others\n"
        "  C-x o        Other window\n"))
    (hash-put! *info-topics* "org mode"
      (string-append
        "Org Mode\n"
        "========\n\n"
        "Jemacs includes substantial org mode support:\n\n"
        "  TAB          Cycle heading visibility\n"
        "  S-TAB        Global cycle\n"
        "  M-RET        New heading\n"
        "  <s TAB       Source block template\n"
        "  C-c C-t      Toggle TODO\n"
        "  C-c C-c      Context action\n"
        "  C-c C-e      Export\n"
        "  C-c a        Agenda\n\n"
        "Tables: | col1 | col2 | with TAB to align\n"
        "Babel: Execute code blocks with C-c C-c\n"
        "Export: HTML, LaTeX, Markdown, plain text\n"))
    (hash-put! *info-topics* "configuration"
      (string-append
        "Configuration\n"
        "=============\n\n"
        "Init file: ~/.jemacs-init\n"
        "  Scheme expressions evaluated at startup.\n\n"
        "Bookmarks: ~/.jemacs-bookmarks\n"
        "  Persistent named positions.\n\n"
        "Session: ~/.jemacs-session\n"
        "  Desktop save/restore.\n\n"
        "Snippets: ~/.jemacs-snippets/\n"
        "  File-based snippet definitions.\n"))
    (hash-put! *info-topics* "about"
      (string-append
        "About Jemacs\n"
        "============\n\n"
        "Jemacs is a Chez Scheme-based Emacs-like editor.\n"
        "It provides Emacs keybindings and commands with a\n"
        "Scintilla-based editing engine.\n\n"
        "Features: syntax highlighting, org mode, magit,\n"
        "LSP, terminal, REPL, snippets, and more.\n\n"
        "License: MIT\n")))

  (define (cmd-info-reader app)
    (info-init-topics!)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (topics (hash-keys *info-topics*))
           (topic (echo-read-string-with-completion echo "Info topic: " topics row width)))
      (when (and topic (> (string-length topic) 0))
        (let* ((key (string-downcase topic))
               (content (hash-get *info-topics* key)))
          (if (not content)
            (echo-message! echo (string-append "No Info topic: " topic))
            (let* ((ed (current-editor app))
                   (win (current-window fr))
                   (ibuf (buffer-create! (string-append "*info*<" topic ">") ed)))
              (buffer-attach! ed ibuf)
              (edit-window-buffer-set! win ibuf)
              (editor-set-text ed content)
              (editor-goto-pos ed 0)
              (editor-set-read-only ed #t)))))))

  ;;;============================================================================
  ;;; Git status in project tree
  ;;;============================================================================
  (define (git-file-status dir)
    (let ((result (make-hash-table)))
      (guard (e (#t result))
        (let* ((proc (open-process
                       (list "git" "-C" dir "status" "--porcelain" "-uall")))
               (output (get-string-all (process-port-rec-stdout-port proc))))
          (when (and (string? output) (not (eof-object? output))
                     (> (string-length output) 0))
            (for-each
              (lambda (line)
                (when (>= (string-length line) 3)
                  (let* ((status-char (string-ref line 1))
                         (idx-char (string-ref line 0))
                         (filepath (substring line 3 (string-length line)))
                         (basename (path-strip-directory filepath))
                         (display-char
                           (cond
                             ((char=? idx-char #\?) #\?)
                             ((char=? idx-char #\A) #\A)
                             ((char=? status-char #\M) #\M)
                             ((char=? idx-char #\M) #\M)
                             ((char=? status-char #\D) #\D)
                             ((char=? idx-char #\D) #\D)
                             ((char=? idx-char #\R) #\R)
                             (else #\space))))
                    (hash-put! result basename display-char))))
              (string-split output #\newline))))
        result)))

  (define (cmd-project-tree-git app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (file (and buf (buffer-file-path buf)))
           (start-dir (if file (path-directory file) (current-directory)))
           (root (let loop ((d start-dir))
                   (if (or (string=? d "/") (string=? d ""))
                     #f
                     (if (or (file-exists? (string-append d "/.git"))
                             (file-exists? (string-append d "/gerbil.pkg")))
                       d
                       (loop (path-directory d)))))))
      (if (not root)
        (echo-message! echo "Not in a project")
        (let* ((git-status (git-file-status root))
               (files (guard (e (#t '())) (directory-list root)))
               (sorted (list-sort string<? files))
               (lines
                 (map (lambda (name)
                        (let* ((full (string-append root "/" name))
                               (is-dir (guard (e (#t #f))
                                         (file-directory? full)))
                               (status (hash-get git-status name))
                               (status-str (if status (string status #\space) "  ")))
                          (string-append status-str
                            (if is-dir (string-append name "/") name))))
                      sorted))
               (content (string-append
                          "Project: " root "\n"
                          (string-join lines "\n") "\n"))
               (tbuf (buffer-create! "*Project Tree*" ed)))
          (buffer-attach! ed tbuf)
          (edit-window-buffer-set! win tbuf)
          (editor-set-text ed content)
          (editor-goto-pos ed 0)
          (editor-set-read-only ed #t)))))

) ;; end library
