#!chezscheme
;;; editor-cmds-c.sls — Command batch C (Tasks 44-45): help, dired,
;;; buffer management, isearch, abbrev
;;;
;;; Ported from gerbil-emacs/editor-cmds-c.ss

(library (jerboa-emacs editor-cmds-c)
  (export
    ;; Help system
    cmd-describe-function
    cmd-describe-variable
    cmd-describe-key-briefly
    cmd-describe-face
    cmd-describe-syntax
    cmd-info
    cmd-info-emacs-manual
    cmd-info-elisp-manual

    ;; Dired
    cmd-dired
    cmd-dired-create-directory
    cmd-dired-do-rename
    cmd-dired-do-delete
    cmd-dired-do-copy
    cmd-dired-do-chmod

    ;; Buffer management
    cmd-rename-uniquely
    cmd-revert-buffer-with-coding
    cmd-lock-buffer
    cmd-buffer-disable-undo
    cmd-buffer-enable-undo
    cmd-bury-buffer
    cmd-unbury-buffer

    ;; Navigation
    cmd-forward-sentence
    cmd-backward-sentence
    cmd-goto-word-at-point

    ;; Region / text manipulation
    cmd-center-region
    cmd-indent-rigidly
    cmd-dedent-rigidly
    cmd-transpose-paragraphs
    cmd-fill-individual-paragraphs

    ;; Bookmark enhancements
    cmd-bookmark-save
    cmd-bookmark-load

    ;; Window management
    cmd-fit-window-to-buffer
    cmd-maximize-window
    cmd-minimize-window
    cmd-rotate-windows
    cmd-swap-windows

    ;; Miscellaneous
    cmd-delete-matching-lines
    cmd-copy-matching-lines
    cmd-delete-non-matching-lines
    cmd-display-fill-column-indicator
    cmd-electric-newline-and-indent
    cmd-view-register
    cmd-append-to-register

    ;; Process / environment
    cmd-getenv
    cmd-setenv
    cmd-show-environment

    ;; Encoding / line endings
    cmd-set-buffer-file-coding
    cmd-convert-line-endings-unix
    cmd-convert-line-endings-dos

    ;; Whitespace
    cmd-whitespace-mode
    cmd-toggle-show-spaces

    ;; Folding
    cmd-fold-all
    cmd-unfold-all
    cmd-toggle-fold
    cmd-fold-level

    ;; Macro enhancements
    cmd-insert-kbd-macro

    ;; Version control extras
    run-git-command
    cmd-vc-annotate
    cmd-vc-diff-head
    cmd-vc-log-file
    cmd-vc-revert

    ;; Imenu
    cmd-imenu
    which-function-extract-name
    cmd-which-function

    ;; Buffer/file utilities
    cmd-make-directory
    cmd-delete-file
    cmd-copy-file
    cmd-sudo-find-file
    cmd-find-file-literally

    ;; Search enhancements
    cmd-isearch-forward-word
    cmd-isearch-backward-word
    cmd-isearch-forward-symbol
    cmd-query-replace-regexp
    cmd-multi-occur

    ;; Align
    cmd-align-current

    ;; Rectangle enhancements
    cmd-clear-rectangle

    ;; Abbrev mode
    cmd-abbrev-mode
    cmd-define-abbrev
    abbrev-word-before-point
    cmd-expand-abbrev
    cmd-list-abbrevs

    ;; Completion
    cmd-completion-at-point
    cmd-complete-filename

    ;; Window resize
    cmd-resize-window-width

    ;; Text operations
    cmd-zap-to-char-inclusive
    cmd-copy-word-at-point
    cmd-copy-symbol-at-point
    cmd-mark-page

    ;; Encoding/display
    cmd-set-language-environment

    ;; Theme/color
    cmd-load-theme
    cmd-customize-face
    cmd-list-colors

    ;; Text property/overlay
    cmd-font-lock-mode

    ;; Auto-revert
    cmd-auto-revert-mode

    ;; Diff enhancements
    cmd-diff-backup

    ;; Compilation
    cmd-first-error

    ;; Calculator enhancements
    cmd-quick-calc

    ;; String insertion
    cmd-insert-time
    cmd-insert-file-header

    ;; Misc
    cmd-toggle-debug-on-quit
    cmd-profiler-start
    cmd-profiler-stop
    cmd-memory-report
    cmd-emacs-version
    cmd-report-bug
    cmd-view-echo-area-messages
    cmd-toggle-menu-bar-mode
    cmd-toggle-tab-bar-mode
    cmd-split-window-below
    cmd-delete-window-below
    cmd-shrink-window-if-larger-than-buffer
    cmd-toggle-frame-fullscreen
    cmd-toggle-frame-maximized

    ;; Spell checking
    ispell-args
    cmd-ispell-word
    ispell-extract-words
    cmd-ispell-buffer
    cmd-ispell-region
    cmd-ispell-change-dictionary

    ;; Process management
    cmd-ansi-term

    ;; Dired subtree
    cmd-dired-subtree-toggle

    ;; Project tree sidebar
    project-tree-render
    cmd-project-tree
    cmd-project-tree-toggle-node

    ;; Terminal per-project
    cmd-project-term)

  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-directory path-strip-directory path-extension
                string-split string-empty? take)
          (only (std srfi srfi-13) string-join string-contains string-prefix?
                string-suffix? string-index string-trim-both string-trim-right string-trim)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (chez-scintilla style)
          (chez-scintilla tui)
          (except (jerboa-emacs core) face-get)
          (except (jerboa-emacs face) face-get)
          (jerboa-emacs themes)
          (jerboa-emacs persist)
          (jerboa-emacs repl)
          (jerboa-emacs eshell)
          (jerboa-emacs shell)
          (jerboa-emacs keymap)
          (jerboa-emacs buffer)
          (jerboa-emacs window)
          (jerboa-emacs modeline)
          (jerboa-emacs echo)
          (jerboa-emacs highlight)
          (jerboa-emacs editor-core)
          (except (jerboa-emacs editor-extra-helpers)
            current-editor current-buffer-from-app
            app-read-string editor-replace-selection)
          (jerboa-emacs editor-ui)
          (except (jerboa-emacs editor-text) shell-quote)
          (jerboa-emacs editor-advanced)
          (jerboa-emacs editor-cmds-a)
          (except (jerboa-emacs editor-cmds-b) open-output-buffer))

  ;;;==========================================================================
  ;;; Local helpers
  ;;;==========================================================================

  ;; copy-file helper (Gambit built-in, not in Chez)
  (define (copy-file-helper src dst)
    (let ((content (call-with-port (open-file-input-port src)
                     get-bytevector-all)))
      (call-with-port (open-file-output-port dst (file-options no-fail))
        (lambda (p) (put-bytevector p content)))))

  ;; run-process helper: run a command, capture output, return (values output status)
  (define (run-process-capture path-str args-list . opts)
    (let-values (((to-stdin from-stdout from-stderr proc-id)
                  (open-process-ports
                    (apply string-append path-str
                           (map (lambda (a) (string-append " " a)) args-list))
                    (buffer-mode block)
                    (native-transcoder))))
      (close-port to-stdin)
      (let* ((output (get-string-all from-stdout))
             (err-output (get-string-all from-stderr)))
        (close-port from-stdout)
        (close-port from-stderr)
        (let ((output-str (if (eof-object? output) "" output)))
          ;; Remove trailing newline
          (let ((trimmed (if (and (> (string-length output-str) 0)
                                  (char=? (string-ref output-str
                                            (- (string-length output-str) 1))
                                          #\newline))
                           (substring output-str 0 (- (string-length output-str) 1))
                           output-str)))
            (values trimmed 0))))))

  ;; aspell process helper: run aspell with stdin/stdout
  (define (run-aspell-process args-list input-text)
    (let-values (((to-stdin from-stdout from-stderr proc-id)
                  (open-process-ports
                    (apply string-append "aspell"
                           (map (lambda (a) (string-append " " a)) args-list))
                    (buffer-mode block)
                    (native-transcoder))))
      (display input-text to-stdin)
      (flush-output-port to-stdin)
      (close-port to-stdin)
      (let ((output (get-string-all from-stdout)))
        (close-port from-stdout)
        (close-port from-stderr)
        (if (eof-object? output) "" output))))

  ;;;==========================================================================
  ;;; Module-level mutable state
  ;;;==========================================================================

  (define *auto-revert-mode* #f)
  (define *debug-on-quit* #f)
  (define *profiler-running* #f)
  (define *profiler-start-time* #f)
  (define *ispell-dictionary* #f)
  (define *dired-expanded-dirs* (make-hash-table))
  (define *project-tree-expanded* (make-hash-table))
  (define *project-terminals* (make-hash-table))

  ;;;==========================================================================
  ;;; Task #44: Help system, dired, buffer management, and more
  ;;;==========================================================================

  ;; --- Help system enhancements ---

  (define (cmd-describe-function app)
    (let ((name (app-read-string app "Describe function: ")))
      (when (and name (not (string=? name "")))
        (let* ((sym (string->symbol name))
               (cmd (find-command sym)))
          (if cmd
            (let* ((fr (app-state-frame app))
                   (ed (current-editor app))
                   (doc (command-doc sym))
                   (binding (find-keybinding-for-command sym))
                   (text (string-append
                           name "\n"
                           (make-string (string-length name) #\=) "\n\n"
                           "Type: Interactive command\n"
                           (if binding
                             (string-append "Key:  " binding "\n")
                             "Key:  (not bound)\n")
                           "\n" doc "\n"))
                   (buf (or (buffer-by-name "*Help*")
                            (buffer-create! "*Help*" ed #f))))
              (buffer-attach! ed buf)
              (edit-window-buffer-set! (current-window fr) buf)
              (editor-set-text ed text)
              (editor-set-save-point ed)
              (editor-goto-pos ed 0)
              (echo-message! (app-state-echo app) (string-append "Help for " name)))
            (echo-error! (app-state-echo app)
                         (string-append name ": not found")))))))

  (define (cmd-describe-variable app)
    (let* ((registered (map symbol->string (custom-list-all)))
           (all-names (list-sort string<? registered))
           (name (app-read-string app "Describe variable: ")))
      (when (and name (not (string=? name "")))
        (let ((sym (string->symbol name)))
          (if (custom-registered? sym)
            (let* ((desc (custom-describe sym))
                   (fr (app-state-frame app))
                   (ed (current-editor app))
                   (win (current-window fr))
                   (buf (buffer-create! "*Help*" ed)))
              (buffer-attach! ed buf)
              (edit-window-buffer-set! win buf)
              (editor-set-text ed desc)
              (editor-goto-pos ed 0)
              (editor-set-read-only ed #t))
            (echo-message! (app-state-echo app)
              (string-append name ": unknown variable")))))))

  (define (cmd-describe-key-briefly app)
    (echo-message! (app-state-echo app) "Press a key...")
    (let ((ev (tui-poll-event)))
      (when ev
        (let* ((ks (key-event->string ev))
               (cmd (keymap-lookup *global-keymap* ks)))
          (if cmd
            (echo-message! (app-state-echo app)
                           (string-append ks " runs " (symbol->string cmd)))
            (echo-message! (app-state-echo app)
                           (string-append ks " is undefined")))))))

  (define (cmd-describe-face app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (style (send-message ed 2010 pos 0)))
      (echo-message! (app-state-echo app)
                     (string-append "Style at point: " (number->string style)))))

  (define (cmd-describe-syntax app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (style (send-message ed 2010 pos 0)))
      (echo-message! (app-state-echo app)
        (string-append "Syntax style: " (number->string style)))))

  (define (cmd-info app)
    (let ((topic (app-read-string app "Info topic: ")))
      (if (or (not topic) (string=? topic ""))
        (echo-message! (app-state-echo app) "Use M-x man for manual pages")
        (guard (e [#t (echo-message! (app-state-echo app) "info not available")])
          (let-values (((output status)
                        (run-process-capture "info"
                          (list "--subnodes" "-o" "-" topic))))
            (if (not (string=? output ""))
              (open-output-buffer app (string-append "*Info:" topic "*") output)
              (echo-message! (app-state-echo app)
                             (string-append "No info for: " topic))))))))

  (define (cmd-info-emacs-manual app)
    (echo-message! (app-state-echo app) "Use M-x info or M-x man for documentation"))

  (define (cmd-info-elisp-manual app)
    (echo-message! (app-state-echo app) "Use M-x info or M-x man for documentation"))

  ;; --- Dired-like operations ---

  (define (cmd-dired app)
    (let* ((dir (app-read-string app "Dired: "))
           (path (or dir ".")))
      (when (and path (not (string=? path "")))
        (guard (e [#t
                   (echo-message! (app-state-echo app)
                     (string-append "Error: "
                       (call-with-string-output-port
                         (lambda (p) (display e p)))))])
          (let-values (((output status)
                        (run-process-capture "ls" (list "-la" path))))
            (open-output-buffer app
                                (string-append "*Dired: " path "*")
                                output))))))

  (define (cmd-dired-create-directory app)
    (let ((dir (app-read-string app "Create directory: ")))
      (when (and dir (not (string=? dir "")))
        (guard (e [#t
                   (echo-message! (app-state-echo app)
                     (string-append "Error: "
                       (call-with-string-output-port
                         (lambda (p) (display e p)))))])
          (mkdir dir)
          (echo-message! (app-state-echo app)
                         (string-append "Created: " dir))))))

  (define (cmd-dired-do-rename app)
    (let ((old (app-read-string app "Rename file: ")))
      (when (and old (not (string=? old "")))
        (let ((new (app-read-string app "Rename to: ")))
          (when (and new (not (string=? new "")))
            (guard (e [#t
                       (echo-message! (app-state-echo app)
                         (string-append "Error: "
                           (call-with-string-output-port
                             (lambda (p) (display e p)))))])
              (rename-file old new)
              (echo-message! (app-state-echo app)
                             (string-append "Renamed: " old " -> " new))))))))

  (define (cmd-dired-do-delete app)
    (let ((file (app-read-string app "Delete file: ")))
      (when (and file (not (string=? file "")))
        (let ((confirm (app-read-string app
                         (string-append "Delete " file "? (yes/no): "))))
          (when (and confirm (string=? confirm "yes"))
            (guard (e [#t
                       (echo-message! (app-state-echo app)
                         (string-append "Error: "
                           (call-with-string-output-port
                             (lambda (p) (display e p)))))])
              (delete-file file)
              (echo-message! (app-state-echo app)
                             (string-append "Deleted: " file))))))))

  (define (cmd-dired-do-copy app)
    (let ((src (app-read-string app "Copy file: ")))
      (when (and src (not (string=? src "")))
        (let ((dst (app-read-string app "Copy to: ")))
          (when (and dst (not (string=? dst "")))
            (guard (e [#t
                       (echo-message! (app-state-echo app)
                         (string-append "Error: "
                           (call-with-string-output-port
                             (lambda (p) (display e p)))))])
              (copy-file-helper src dst)
              (echo-message! (app-state-echo app)
                             (string-append "Copied: " src " -> " dst))))))))

  (define (cmd-dired-do-chmod app)
    (let ((file (app-read-string app "Chmod file: ")))
      (when (and file (not (string=? file "")))
        (let ((mode (app-read-string app "Mode (e.g. 755): ")))
          (when (and mode (not (string=? mode "")))
            (guard (e [#t
                       (echo-message! (app-state-echo app)
                         (string-append "Error: "
                           (call-with-string-output-port
                             (lambda (p) (display e p)))))])
              (let-values (((output status)
                            (run-process-capture "chmod" (list mode file))))
                (echo-message! (app-state-echo app)
                               (string-append "chmod " mode " " file)))))))))

  ;; --- Buffer management ---

  (define (cmd-rename-uniquely app)
    (let* ((buf (current-buffer-from-app app))
           (name (buffer-name buf))
           (new-name (string-append name "<" (number->string (random 1000)) ">")))
      (buffer-name-set! buf new-name)
      (echo-message! (app-state-echo app)
                     (string-append "Buffer renamed to: " new-name))))

  (define (cmd-revert-buffer-with-coding app)
    (let* ((buf (current-buffer-from-app app))
           (file (buffer-file-path buf)))
      (if file
        (let ((coding (app-read-string app "Coding system (utf-8/latin-1): ")))
          (when (and coding (not (string=? coding "")))
            (guard (e [#t (echo-message! (app-state-echo app) "Error reverting buffer")])
              (let ((content (read-file-as-string file)))
                (editor-set-text (current-editor app) content)
                (echo-message! (app-state-echo app)
                               (string-append "Reverted with coding: " coding))))))
        (echo-message! (app-state-echo app) "Buffer has no file"))))

  (define (cmd-lock-buffer app)
    (let* ((ed (current-editor app))
           (ro (editor-get-read-only? ed)))
      (editor-set-read-only ed (not ro))
      (echo-message! (app-state-echo app)
                     (if (not ro) "Buffer locked (read-only)" "Buffer unlocked"))))

  (define (cmd-buffer-disable-undo app)
    (let ((ed (current-editor app)))
      (send-message ed 2175 0 0)  ;; SCI_EMPTYUNDOBUFFER
      (echo-message! (app-state-echo app) "Undo history cleared")))

  (define (cmd-buffer-enable-undo app)
    (let ((ed (current-editor app)))
      (send-message ed 2012 1 0)  ;; SCI_SETUNDOCOLLECTION
      (echo-message! (app-state-echo app) "Undo collection enabled")))

  (define (cmd-bury-buffer app)
    (echo-message! (app-state-echo app) "Buffer buried"))

  (define (cmd-unbury-buffer app)
    (let ((bufs (buffer-list)))
      (when (> (length bufs) 1)
        (let* ((ed (current-editor app))
               (fr (app-state-frame app))
               (last-buf (car (last-pair bufs))))
          (buffer-attach! ed last-buf)
          (edit-window-buffer-set! (current-window fr) last-buf)
          (echo-message! (app-state-echo app)
                         (string-append "Switched to: " (buffer-name last-buf)))))))

  ;; --- Navigation ---

  (define (cmd-forward-sentence app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (let loop ((i pos))
        (cond
          ((>= i len) (editor-goto-pos ed len))
          ((and (memv (string-ref text i) '(#\. #\? #\!))
                (< (+ i 1) len)
                (memv (string-ref text (+ i 1)) '(#\space #\newline)))
           (editor-goto-pos ed (+ i 2)))
          (else (loop (+ i 1)))))))

  (define (cmd-backward-sentence app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      (let loop ((i (- pos 2)))
        (cond
          ((<= i 0) (editor-goto-pos ed 0))
          ((and (memv (string-ref text i) '(#\. #\? #\!))
                (< (+ i 1) (string-length text))
                (memv (string-ref text (+ i 1)) '(#\space #\newline)))
           (editor-goto-pos ed (+ i 2)))
          (else (loop (- i 1)))))))

  (define (cmd-goto-word-at-point app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (> len 0)
        (let* ((ws (let loop ((i pos))
                     (if (and (> i 0) (word-char? (string-ref text (- i 1))))
                       (loop (- i 1)) i)))
               (we (let loop ((i pos))
                     (if (and (< i len) (word-char? (string-ref text i)))
                       (loop (+ i 1)) i)))
               (word (if (< ws we) (substring text ws we) "")))
          (when (not (string=? word ""))
            (let ((found (string-contains text word we)))
              (if found
                (editor-goto-pos ed found)
                ;; Wrap around
                (let ((found2 (string-contains text word 0)))
                  (when found2
                    (editor-goto-pos ed found2)
                    (echo-message! (app-state-echo app) "Wrapped"))))))))))

  ;; --- Region operations ---

  ;; --- Text manipulation ---

  (define (cmd-center-region app)
    (let* ((ed (current-editor app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (when (< sel-start sel-end)
        (let* ((text (editor-get-text ed))
               (region (substring text sel-start sel-end))
               (lines (string-split region #\newline))
               (fill-col 80)
               (centered (map (lambda (l)
                                (let* ((trimmed (string-trim-both l))
                                       (pad (max 0 (quotient (- fill-col (string-length trimmed)) 2))))
                                  (string-append (make-string pad #\space) trimmed)))
                              lines))
               (result (string-join centered "\n")))
          (send-message ed 2160 sel-start 0)  ;; SCI_SETTARGETSTART
          (send-message ed 2161 sel-end 0)    ;; SCI_SETTARGETEND
          (send-message/string ed SCI_REPLACETARGET result)))))

  (define (cmd-indent-rigidly app)
    (let* ((ed (current-editor app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (when (< sel-start sel-end)
        (let* ((text (editor-get-text ed))
               (region (substring text sel-start sel-end))
               (lines (string-split region #\newline))
               (indented (map (lambda (l) (string-append "  " l)) lines))
               (result (string-join indented "\n")))
          (send-message ed 2160 sel-start 0)
          (send-message ed 2161 sel-end 0)
          (send-message/string ed SCI_REPLACETARGET result)))))

  (define (cmd-dedent-rigidly app)
    (let* ((ed (current-editor app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (when (< sel-start sel-end)
        (let* ((text (editor-get-text ed))
               (region (substring text sel-start sel-end))
               (lines (string-split region #\newline))
               (dedented (map (lambda (l)
                                (if (and (>= (string-length l) 2)
                                         (string=? (substring l 0 2) "  "))
                                  (substring l 2 (string-length l))
                                  l))
                              lines))
               (result (string-join dedented "\n")))
          (send-message ed 2160 sel-start 0)
          (send-message ed 2161 sel-end 0)
          (send-message/string ed SCI_REPLACETARGET result)))))

  (define (cmd-transpose-paragraphs app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (len (string-length text)))
      ;; Find current paragraph boundaries
      (let* ((para-start
               (let loop ((i (- pos 1)))
                 (cond
                   ((< i 0) 0)
                   ((and (char=? (string-ref text i) #\newline)
                         (or (= i 0)
                             (and (> i 0) (char=? (string-ref text (- i 1)) #\newline))))
                    (+ i 1))
                   (else (loop (- i 1))))))
             (para-end
               (let loop ((i pos))
                 (cond
                   ((>= i len) len)
                   ((and (char=? (string-ref text i) #\newline)
                         (< (+ i 1) len)
                         (char=? (string-ref text (+ i 1)) #\newline))
                    i)
                   (else (loop (+ i 1))))))
             ;; Find next paragraph
             (next-start
               (let loop ((i (+ para-end 1)))
                 (cond
                   ((>= i len) #f)
                   ((not (or (char=? (string-ref text i) #\newline)
                             (char=? (string-ref text i) #\space)))
                    i)
                   (else (loop (+ i 1))))))
             (next-end
               (if next-start
                 (let loop ((i next-start))
                   (cond
                     ((>= i len) len)
                     ((and (char=? (string-ref text i) #\newline)
                           (< (+ i 1) len)
                           (char=? (string-ref text (+ i 1)) #\newline))
                      i)
                     (else (loop (+ i 1)))))
                 #f)))
        (if (and next-start next-end)
          (let* ((para1 (substring text para-start para-end))
                 (sep (substring text para-end next-start))
                 (para2 (substring text next-start next-end))
                 (replacement (string-append para2 sep para1)))
            (with-undo-action ed
              (editor-delete-range ed para-start (- next-end para-start))
              (editor-insert-text ed para-start replacement))
            (echo-message! (app-state-echo app) "Paragraphs transposed"))
          (echo-message! (app-state-echo app) "No next paragraph to transpose")))))

  (define (cmd-fill-individual-paragraphs app)
    (let* ((ed (current-editor app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! (app-state-echo app) "No region selected")
        (begin
          (cmd-fill-paragraph app)
          (echo-message! (app-state-echo app) "Paragraphs filled")))))

  ;; --- Bookmark enhancements ---

  (define (cmd-bookmark-save app)
    (let ((bmarks (app-state-bookmarks app)))
      (guard (e [#t
                 (echo-message! (app-state-echo app) "Error saving bookmarks")])
        (call-with-output-file "~/.gemacs-bookmarks"
          (lambda (port)
            (for-each
              (lambda (pair)
                (display (car pair) port)
                (display " " port)
                (display (cdr pair) port)
                (newline port))
              (hash->list bmarks))))
        (echo-message! (app-state-echo app) "Bookmarks saved"))))

  (define (cmd-bookmark-load app)
    (guard (e [#t
               (echo-message! (app-state-echo app) "No saved bookmarks found")])
      (let* ((content (read-file-as-string "~/.gemacs-bookmarks"))
             (lines (string-split content #\newline))
             (bmarks (app-state-bookmarks app)))
        (for-each
          (lambda (line)
            (let ((parts (string-split line #\space)))
              (when (>= (length parts) 2)
                (hash-put! bmarks (car parts) (string->number (cadr parts))))))
          lines)
        (echo-message! (app-state-echo app)
                       (string-append "Bookmarks loaded: "
                                      (number->string (hash-length bmarks)))))))

  ;; --- Window management ---

  (define (cmd-fit-window-to-buffer app)
    (let* ((ed (current-editor app))
           (lines (send-message ed SCI_GETLINECOUNT 0 0)))
      (echo-message! (app-state-echo app)
                     (string-append "Buffer has " (number->string lines) " lines"))))

  (define (cmd-maximize-window app)
    (frame-delete-other-windows! (app-state-frame app))
    (echo-message! (app-state-echo app) "Window maximized"))

  (define (cmd-minimize-window app)
    (echo-message! (app-state-echo app) "Window minimized (single-window TUI)"))

  (define (cmd-rotate-windows app)
    (let ((wins (frame-windows (app-state-frame app))))
      (if (>= (length wins) 2)
        (begin
          (frame-other-window! (app-state-frame app))
          (echo-message! (app-state-echo app) "Windows rotated"))
        (echo-message! (app-state-echo app) "Only one window"))))

  (define (cmd-swap-windows app)
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr)))
      (when (>= (length wins) 2)
        (let* ((w1 (car wins))
               (w2 (cadr wins))
               (b1 (edit-window-buffer w1))
               (b2 (edit-window-buffer w2)))
          (edit-window-buffer-set! w1 b2)
          (edit-window-buffer-set! w2 b1)
          (echo-message! (app-state-echo app) "Windows swapped")))))

  ;; --- Miscellaneous ---

  (define (cmd-delete-matching-lines app)
    (cmd-flush-lines app))

  (define (cmd-copy-matching-lines app)
    (let ((pat (app-read-string app "Copy lines matching: ")))
      (when (and pat (not (string=? pat "")))
        (let* ((ed (current-editor app))
               (text (editor-get-text ed))
               (lines (string-split text #\newline))
               (matching (filter (lambda (l) (string-contains l pat)) lines))
               (result (string-join matching "\n")))
          (open-output-buffer app "*Matching Lines*" result)))))

  (define (cmd-delete-non-matching-lines app)
    (cmd-keep-lines app))

  (define (cmd-display-fill-column-indicator app)
    (let* ((ed (current-editor app))
           (cur (send-message ed 2695 0 0)))  ;; SCI_GETEDGEMODE
      (if (= cur 0)
        (begin
          (send-message ed 2694 1 0)  ;; SCI_SETEDGEMODE EDGE_LINE
          (send-message ed 2360 80 0)  ;; SCI_SETEDGECOLUMN
          (echo-message! (app-state-echo app) "Fill column indicator on"))
        (begin
          (send-message ed 2694 0 0)  ;; SCI_SETEDGEMODE EDGE_NONE
          (echo-message! (app-state-echo app) "Fill column indicator off")))))

  (define (cmd-electric-newline-and-indent app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "\n")
      (editor-goto-pos ed (+ pos 1))
      (send-message ed 2327 0 0)))  ;; SCI_TAB (auto-indent)

  (define (cmd-view-register app)
    (echo-message! (app-state-echo app) "View register key: ")
    (let ((ev (tui-poll-event)))
      (when ev
        (let* ((ks (key-event->string ev))
               (regs (app-state-registers app))
               (val (hash-get regs ks)))
          (if val
            (echo-message! (app-state-echo app)
                           (string-append "Register " ks ": "
                             (if (> (string-length val) 60)
                               (string-append (substring val 0 57) "...")
                               val)))
            (echo-message! (app-state-echo app)
                           (string-append "Register " ks " is empty")))))))

  (define (cmd-append-to-register app)
    (echo-message! (app-state-echo app) "Append to register: ")
    (let ((ev (tui-poll-event)))
      (when ev
        (let* ((ks (key-event->string ev))
               (ed (current-editor app))
               (sel-start (editor-get-selection-start ed))
               (sel-end (editor-get-selection-end ed)))
          (if (< sel-start sel-end)
            (let* ((text (editor-get-text ed))
                   (region (substring text sel-start sel-end))
                   (regs (app-state-registers app))
                   (existing (or (hash-get regs ks) "")))
              (hash-put! regs ks (string-append existing region))
              (echo-message! (app-state-echo app)
                             (string-append "Appended to register " ks)))
            (echo-message! (app-state-echo app) "No region selected"))))))

  ;; --- Process / environment ---

  (define (cmd-getenv app)
    (let ((var (app-read-string app "Environment variable: ")))
      (when (and var (not (string=? var "")))
        (let ((val (getenv var)))
          (echo-message! (app-state-echo app)
                         (if val
                           (string-append var "=" val)
                           (string-append var " is not set")))))))

  (define (cmd-setenv app)
    (let ((var (app-read-string app "Set variable: ")))
      (when (and var (not (string=? var "")))
        (let ((val (app-read-string app "Value: ")))
          (when val
            (putenv var val)
            (echo-message! (app-state-echo app)
                           (string-append var "=" val)))))))

  (define (cmd-show-environment app)
    (guard (e [#t
               (echo-message! (app-state-echo app) "Error reading environment")])
      (let-values (((output status)
                    (run-process-capture "env" '())))
        (open-output-buffer app "*Environment*" output))))

  ;; --- Encoding / line endings ---

  (define (cmd-set-buffer-file-coding app)
    (let ((coding (app-read-string app "Coding system (utf-8): ")))
      (when (and coding (not (string=? coding "")))
        (echo-message! (app-state-echo app)
                       (string-append "Coding system: " coding " (note: Chez uses UTF-8 natively)")))))

  (define (cmd-convert-line-endings-unix app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed)))
      (let loop ((i 0) (acc '()))
        (if (>= i (string-length text))
          (let ((result (list->string (reverse acc))))
            (editor-set-text ed result)
            (echo-message! (app-state-echo app) "Converted to Unix line endings"))
          (let ((ch (string-ref text i)))
            (if (char=? ch #\return)
              (if (and (< (+ i 1) (string-length text))
                       (char=? (string-ref text (+ i 1)) #\newline))
                (loop (+ i 2) (cons #\newline acc))  ;; CR+LF -> LF
                (loop (+ i 1) (cons #\newline acc)))  ;; CR -> LF
              (loop (+ i 1) (cons ch acc))))))))

  (define (cmd-convert-line-endings-dos app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed)))
      ;; First normalize to LF, then convert to CRLF
      (let loop ((i 0) (acc '()))
        (if (>= i (string-length text))
          (let ((clean (list->string (reverse acc))))
            ;; Now add CR before each LF
            (let loop2 ((j 0) (acc2 '()))
              (if (>= j (string-length clean))
                (let ((result (list->string (reverse acc2))))
                  (editor-set-text ed result)
                  (echo-message! (app-state-echo app) "Converted to DOS line endings"))
                (let ((ch (string-ref clean j)))
                  (if (char=? ch #\newline)
                    (loop2 (+ j 1) (cons #\newline (cons #\return acc2)))
                    (loop2 (+ j 1) (cons ch acc2)))))))
          (let ((ch (string-ref text i)))
            (if (char=? ch #\return)
              (if (and (< (+ i 1) (string-length text))
                       (char=? (string-ref text (+ i 1)) #\newline))
                (loop (+ i 2) (cons #\newline acc))
                (loop (+ i 1) (cons #\newline acc)))
              (loop (+ i 1) (cons ch acc))))))))

  ;; --- Whitespace ---

  (define (cmd-whitespace-mode app)
    (let* ((ed (current-editor app))
           (visible (send-message ed 2090 0 0)))  ;; SCI_GETVIEWWS
      (if (= visible 0)
        (begin
          (send-message ed 2021 1 0)  ;; SCI_SETVIEWWS SCWS_VISIBLEALWAYS
          (echo-message! (app-state-echo app) "Whitespace visible"))
        (begin
          (send-message ed 2021 0 0)  ;; SCI_SETVIEWWS SCWS_INVISIBLE
          (echo-message! (app-state-echo app) "Whitespace hidden")))))

  (define (cmd-toggle-show-spaces app)
    (cmd-whitespace-mode app))

  ;; --- Folding ---

  (define (cmd-fold-all app)
    (let ((ed (current-editor app)))
      (send-message ed SCI_FOLDALL SC_FOLDACTION_CONTRACT 0)
      (echo-message! (app-state-echo app) "All folds collapsed")))

  (define (cmd-unfold-all app)
    (let ((ed (current-editor app)))
      (send-message ed SCI_FOLDALL SC_FOLDACTION_EXPAND 0)
      (echo-message! (app-state-echo app) "All folds expanded")))

  (define (cmd-toggle-fold app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos)))
      (send-message ed SCI_TOGGLEFOLD line 0)
      (echo-message! (app-state-echo app) "Fold toggled")))

  (define (cmd-fold-level app)
    (let ((level (app-read-string app "Fold level: ")))
      (when (and level (not (string=? level "")))
        (let ((n (string->number level)))
          (when n
            (let ((ed (current-editor app)))
              ;; Expand all first, then collapse to level
              (send-message ed 2335 1 0)  ;; SCI_FOLDALL expand
              (echo-message! (app-state-echo app)
                             (string-append "Folded to level " level))))))))

  ;; --- Macro enhancements ---

  (define (cmd-insert-kbd-macro app)
    (let ((macro (app-state-macro-last app)))
      (if (and macro (not (null? macro)))
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed))
               (desc (string-join (map (lambda (ev) (key-event->string ev)) macro) " ")))
          (editor-insert-text ed pos desc))
        (echo-message! (app-state-echo app) "No keyboard macro defined"))))

  ;; --- Version control extras ---

  (define (run-git-command dir args)
    (guard (e [#t (values (call-with-string-output-port
                            (lambda (p) (display e p)))
                          1)])
      (let-values (((to-stdin from-stdout from-stderr proc-id)
                    (open-process-ports
                      (apply string-append "cd " dir " && git"
                             (map (lambda (a) (string-append " " a)) args))
                      (buffer-mode block)
                      (native-transcoder))))
        (close-port to-stdin)
        (let* ((output (get-string-all from-stdout))
               (err (get-string-all from-stderr)))
          (close-port from-stdout)
          (close-port from-stderr)
          (let ((out-str (if (eof-object? output) "" output)))
            (values out-str 0))))))

  (define (cmd-vc-annotate app)
    (let* ((buf (current-buffer-from-app app))
           (file (buffer-file-path buf))
           (echo (app-state-echo app)))
      (if (not file)
        (echo-message! echo "Buffer is not visiting a file")
        (guard (e [#t
                   (echo-message! echo
                     (string-append "git blame failed: "
                       (call-with-string-output-port
                         (lambda (p) (display e p)))))])
          (let-values (((output status) (run-git-command (path-directory file)
                                          (list "blame" "--date=short" file))))
            (if (zero? status)
              (begin
                (open-output-buffer app
                  (string-append "*Annotate: " (path-strip-directory file) "*")
                  output)
                (echo-message! echo (string-append "git blame " (path-strip-directory file))))
              (echo-message! echo (string-append "git blame failed: " output))))))))

  (define (cmd-vc-diff-head app)
    (let* ((buf (current-buffer-from-app app))
           (file (buffer-file-path buf))
           (echo (app-state-echo app)))
      (if (not file)
        (echo-message! echo "Buffer is not visiting a file")
        (guard (e [#t
                   (echo-message! echo
                     (string-append "git diff failed: "
                       (call-with-string-output-port
                         (lambda (p) (display e p)))))])
          (let-values (((output status) (run-git-command (path-directory file)
                                          (list "diff" "HEAD" "--" file))))
            (if (zero? status)
              (if (string=? output "")
                (echo-message! echo (string-append "No changes in " (path-strip-directory file)))
                (begin
                  (open-output-buffer app
                    (string-append "*VC Diff: " (path-strip-directory file) "*")
                    output)
                  (echo-message! echo (string-append "git diff " (path-strip-directory file)))))
              (echo-message! echo (string-append "git diff failed: " output))))))))

  (define (cmd-vc-log-file app)
    (let* ((buf (current-buffer-from-app app))
           (file (buffer-file-path buf))
           (echo (app-state-echo app)))
      (if (not file)
        (echo-message! echo "Buffer is not visiting a file")
        (guard (e [#t
                   (echo-message! echo
                     (string-append "git log failed: "
                       (call-with-string-output-port
                         (lambda (p) (display e p)))))])
          (let-values (((output status) (run-git-command (path-directory file)
                                          (list "log" "--oneline" "--follow" "-50" "--" file))))
            (if (zero? status)
              (if (string=? output "")
                (echo-message! echo (string-append "No git history for " (path-strip-directory file)))
                (begin
                  (open-output-buffer app
                    (string-append "*VC Log: " (path-strip-directory file) "*")
                    output)
                  (echo-message! echo (string-append "git log " (path-strip-directory file)))))
              (echo-message! echo (string-append "git log failed: " output))))))))

  (define (cmd-vc-revert app)
    (let* ((buf (current-buffer-from-app app))
           (file (buffer-file-path buf))
           (echo (app-state-echo app)))
      (if (not file)
        (echo-message! echo "Buffer is not visiting a file")
        (let ((confirm (app-read-string app
                         (string-append "Revert " (path-strip-directory file) " to HEAD? (yes/no): "))))
          (when (and confirm (string=? confirm "yes"))
            (guard (e [#t
                       (echo-message! echo
                         (string-append "git checkout failed: "
                           (call-with-string-output-port
                             (lambda (p) (display e p)))))])
              (let-values (((output status)
                            (run-git-command (path-directory file)
                              (list "checkout" "HEAD" "--" file))))
                (if (zero? status)
                  ;; Reload the file
                  (let ((content (read-file-as-string file))
                        (ed (current-editor app)))
                    (editor-set-text ed content)
                    (editor-set-save-point ed)
                    (echo-message! echo "Reverted"))
                  (echo-message! echo (string-append "git checkout failed: " output))))))))))

  ;; --- Imenu ---

  (define (cmd-imenu app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (defs (let loop ((ls lines) (n 0) (acc '()))
                   (if (null? ls)
                     (reverse acc)
                     (let ((l (car ls)))
                       (if (or (string-contains l "(def ")
                               (string-contains l "(defstruct ")
                               (string-contains l "(defclass ")
                               (string-contains l "(defmethod ")
                               (string-contains l "(define "))
                         (loop (cdr ls) (+ n 1) (cons (cons l n) acc))
                         (loop (cdr ls) (+ n 1) acc)))))))
      (if (null? defs)
        (echo-message! (app-state-echo app) "No definitions found")
        (let* ((items (map (lambda (d) (string-append (number->string (cdr d)) ": " (car d))) defs))
               (display-text (string-join items "\n")))
          (open-output-buffer app "*Imenu*" display-text)))))

  (define (which-function-extract-name lt)
    (let ((trimmed (string-trim-both lt)))
      (cond
        ;; Scheme/Gerbil: (def (name ...) or (define (name ...)
        ((or (string-contains trimmed "(def ")
             (string-contains trimmed "(def(")
             (string-contains trimmed "(define "))
         (let* ((idx (or (string-contains trimmed "(def (")
                         (string-contains trimmed "(def(")
                         (string-contains trimmed "(define (")))
                (skip (cond ((string-contains trimmed "(define (") 9)
                            ((string-contains trimmed "(def (") 6)
                            ((string-contains trimmed "(def(") 5)
                            (else 5)))
                (start (+ (or idx 0) skip))
                (end (let loop ((j start))
                       (if (or (>= j (string-length trimmed))
                               (memq (string-ref trimmed j)
                                     '(#\space #\) #\newline #\( #\tab)))
                         j (loop (+ j 1))))))
           (if (> end start) (substring trimmed start end) #f)))
        ;; Python: def name( or class name(
        ((or (string-prefix? "def " trimmed)
             (string-prefix? "class " trimmed))
         (let* ((is-class (string-prefix? "class " trimmed))
                (start (if is-class 6 4))
                (end (let loop ((j start))
                       (if (or (>= j (string-length trimmed))
                               (memq (string-ref trimmed j)
                                     '(#\( #\: #\space #\tab)))
                         j (loop (+ j 1))))))
           (if (> end start) (substring trimmed start end) #f)))
        ;; C/Go/Rust: func name, fn name
        ((or (string-prefix? "func " trimmed)
             (string-prefix? "fn " trimmed))
         (let* ((skip (if (string-prefix? "fn " trimmed) 3 5))
                (end (let loop ((j skip))
                       (if (or (>= j (string-length trimmed))
                               (memq (string-ref trimmed j)
                                     '(#\( #\space #\{ #\tab #\<)))
                         j (loop (+ j 1))))))
           (if (> end skip) (substring trimmed skip end) #f)))
        ;; JS/TS: function name(
        ((string-prefix? "function " trimmed)
         (let* ((start 9)
                (end (let loop ((j start))
                       (if (or (>= j (string-length trimmed))
                               (memq (string-ref trimmed j)
                                     '(#\( #\space #\{ #\tab)))
                         j (loop (+ j 1))))))
           (if (> end start) (substring trimmed start end) #f)))
        (else #f))))

  (define (cmd-which-function app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (line (send-message ed 2166 pos 0)))
      ;; Search backward for function definition
      (let loop ((l line))
        (if (< l 0)
          (echo-message! (app-state-echo app) "Not in a function")
          (let* ((ls (send-message ed 2167 l 0))
                 (le (send-message ed 2136 l 0))
                 (lt (if (and (>= ls 0) (<= le (string-length text)))
                       (substring text ls le) ""))
                 (name (which-function-extract-name lt)))
            (if name
              (echo-message! (app-state-echo app) (string-append "In: " name))
              (loop (- l 1))))))))

  ;; --- Buffer/file utilities ---

  (define (cmd-make-directory app)
    (let ((dir (app-read-string app "Create directory: ")))
      (when (and dir (not (string=? dir "")))
        (guard (e [#t
                   (echo-message! (app-state-echo app)
                     (string-append "Error: "
                       (call-with-string-output-port
                         (lambda (p) (display e p)))))])
          (mkdir dir)
          (echo-message! (app-state-echo app)
                         (string-append "Created: " dir))))))

  (define (cmd-delete-file app)
    (let ((file (app-read-string app "Delete file: ")))
      (when (and file (not (string=? file "")))
        (let ((confirm (app-read-string app
                         (string-append "Really delete " file "? (yes/no): "))))
          (when (and confirm (string=? confirm "yes"))
            (guard (e [#t
                       (echo-message! (app-state-echo app)
                         (string-append "Error: "
                           (call-with-string-output-port
                             (lambda (p) (display e p)))))])
              (delete-file file)
              (echo-message! (app-state-echo app)
                             (string-append "Deleted: " file))))))))

  (define (cmd-copy-file app)
    (let ((src (app-read-string app "Copy file: ")))
      (when (and src (not (string=? src "")))
        (let ((dst (app-read-string app "Copy to: ")))
          (when (and dst (not (string=? dst "")))
            (guard (e [#t
                       (echo-message! (app-state-echo app)
                         (string-append "Error: "
                           (call-with-string-output-port
                             (lambda (p) (display e p)))))])
              (copy-file-helper src dst)
              (echo-message! (app-state-echo app)
                             (string-append "Copied: " src " -> " dst))))))))

  (define (cmd-sudo-find-file app)
    (let ((file (app-read-string app "Sudo find file: ")))
      (when (and file (not (string=? file "")))
        (guard (e [#t
                   (echo-message! (app-state-echo app)
                     (string-append "sudo failed: "
                       (call-with-string-output-port
                         (lambda (p) (display e p)))))])
          (let-values (((output status)
                        (run-process-capture "/usr/bin/sudo" (list "cat" file))))
            (let* ((ed (current-editor app))
                   (fr (app-state-frame app))
                   (buf (buffer-create! (string-append "[sudo] " file) ed #f)))
              (buffer-attach! ed buf)
              (edit-window-buffer-set! (current-window fr) buf)
              (editor-set-text ed output)
              (editor-set-save-point ed)
              (editor-set-read-only ed #t)
              (echo-message! (app-state-echo app)
                             (string-append "Opened (read-only): " file))))))))

  (define (cmd-find-file-literally app)
    (let ((file (app-read-string app "Find file literally: ")))
      (when (and file (not (string=? file "")))
        (guard (e [#t
                   (echo-message! (app-state-echo app)
                     (string-append "Error: "
                       (call-with-string-output-port
                         (lambda (p) (display e p)))))])
          (let* ((content (read-file-as-string file))
                 (ed (current-editor app))
                 (fr (app-state-frame app))
                 (buf (buffer-create! file ed #f)))
            (buffer-attach! ed buf)
            (edit-window-buffer-set! (current-window fr) buf)
            (editor-set-text ed content)
            (editor-set-save-point ed)
            (editor-goto-pos ed 0))))))

  ;;;==========================================================================
  ;;; Task #45: isearch enhancements, abbrev, and editing utilities
  ;;;==========================================================================

  ;; --- Search enhancements ---

  (define (cmd-isearch-forward-word app)
    (let ((word (app-read-string app "I-search word: ")))
      (when (and word (not (string=? word "")))
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed))
               (text (editor-get-text ed)))
          ;; Simple word boundary: space-delimited
          (let ((found (string-contains text word pos)))
            (if found
              (begin
                (editor-goto-pos ed found)
                (editor-set-selection-start ed found)
                (editor-set-selection-end ed (+ found (string-length word)))
                (app-state-last-search-set! app word))
              (echo-message! (app-state-echo app)
                             (string-append "Not found: " word))))))))

  (define (cmd-isearch-backward-word app)
    (let ((word (app-read-string app "I-search backward word: ")))
      (when (and word (not (string=? word "")))
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed))
               (text (editor-get-text ed)))
          ;; Search backward
          (let loop ((i (- pos (string-length word) 1)))
            (cond
              ((< i 0)
               (echo-message! (app-state-echo app)
                              (string-append "Not found: " word)))
              ((and (>= (+ i (string-length word)) 0)
                    (<= (+ i (string-length word)) (string-length text))
                    (string=? (substring text i (+ i (string-length word))) word))
               (editor-goto-pos ed i)
               (editor-set-selection-start ed i)
               (editor-set-selection-end ed (+ i (string-length word)))
               (app-state-last-search-set! app word))
              (else (loop (- i 1)))))))))

  (define (cmd-isearch-forward-symbol app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Get symbol at point
      (let* ((ws (let loop ((i pos))
                   (if (and (> i 0) (word-char? (string-ref text (- i 1))))
                     (loop (- i 1)) i)))
             (we (let loop ((i pos))
                   (if (and (< i len) (word-char? (string-ref text i)))
                     (loop (+ i 1)) i)))
             (symbol (if (< ws we) (substring text ws we) "")))
        (if (string=? symbol "")
          (echo-message! (app-state-echo app) "No symbol at point")
          (let ((found (string-contains text symbol (+ we 1))))
            (if found
              (begin
                (editor-goto-pos ed found)
                (editor-set-selection-start ed found)
                (editor-set-selection-end ed (+ found (string-length symbol)))
                (app-state-last-search-set! app symbol)
                (echo-message! (app-state-echo app)
                               (string-append "Symbol: " symbol)))
              ;; Wrap around
              (let ((found2 (string-contains text symbol 0)))
                (if (and found2 (< found2 ws))
                  (begin
                    (editor-goto-pos ed found2)
                    (editor-set-selection-start ed found2)
                    (editor-set-selection-end ed (+ found2 (string-length symbol)))
                    (echo-message! (app-state-echo app) "Wrapped"))
                  (echo-message! (app-state-echo app) "Only occurrence")))))))))

  (define (cmd-query-replace-regexp app)
    (let ((from (app-read-string app "Regexp replace: ")))
      (when (and from (not (string=? from "")))
        (let ((to (app-read-string app (string-append "Replace regexp \"" from "\" with: "))))
          (when to
            (let* ((ed (current-editor app))
                   (replaced 0))
              ;; Start from beginning of document
              (let loop ((pos 0))
                (let ((text-len (editor-get-text-length ed)))
                  (send-message ed SCI_SETTARGETSTART pos)
                  (send-message ed SCI_SETTARGETEND text-len)
                  (send-message ed SCI_SETSEARCHFLAGS SCFIND_REGEXP)
                  (let ((found (send-message/string ed SCI_SEARCHINTARGET from)))
                    (if (>= found 0)
                      (let ((match-end (send-message ed SCI_GETTARGETEND)))
                        (send-message ed SCI_SETTARGETSTART found)
                        (send-message ed SCI_SETTARGETEND match-end)
                        (let ((repl-len (send-message/string ed SCI_REPLACETARGETRE to)))
                          (set! replaced (+ replaced 1))
                          (loop (+ found (max repl-len 1)))))
                      (echo-message! (app-state-echo app)
                        (string-append "Replaced " (number->string replaced)
                                       " occurrence" (if (= replaced 1) "" "s")))))))))))))

  (define (cmd-multi-occur app)
    (let ((pat (app-read-string app "Multi-occur: ")))
      (when (and pat (not (string=? pat "")))
        (let* ((ed (current-editor app))
               ;; Use grep on files of file-visiting buffers
               (file-results
                 (let loop ((bufs (buffer-list)) (acc '()))
                   (if (null? bufs)
                     (reverse acc)
                     (let* ((buf (car bufs))
                            (file (buffer-file-path buf)))
                       (if (and file (file-exists? file))
                         (guard (e [#t (loop (cdr bufs) acc)])
                           (let* ((content (read-file-as-string file))
                                  (lines (string-split content #\newline))
                                  (matches
                                    (let mloop ((ls lines) (n 1) (hits '()))
                                      (if (null? ls)
                                        (reverse hits)
                                        (if (string-contains (car ls) pat)
                                          (mloop (cdr ls) (+ n 1)
                                                 (cons (string-append (buffer-name buf) ":"
                                                                      (number->string n) ": "
                                                                      (car ls))
                                                       hits))
                                          (mloop (cdr ls) (+ n 1) hits))))))
                             (loop (cdr bufs) (append acc matches))))
                         (loop (cdr bufs) acc))))))
               (output (if (null? file-results)
                         (string-append "No matches for: " pat)
                         (string-join file-results "\n"))))
          (open-output-buffer app "*Multi-Occur*" output)
          (echo-message! (app-state-echo app)
                         (string-append (number->string (length file-results))
                                        " matches for: " pat))))))

  ;; --- Align ---

  (define (cmd-align-current app)
    (let ((sep (app-read-string app "Align on: ")))
      (when (and sep (not (string=? sep "")))
        (let* ((ed (current-editor app))
               (sel-start (editor-get-selection-start ed))
               (sel-end (editor-get-selection-end ed)))
          (when (< sel-start sel-end)
            (let* ((text (editor-get-text ed))
                   (region (substring text sel-start sel-end))
                   (lines (string-split region #\newline))
                   ;; Find max column of separator
                   (max-col (let loop ((ls lines) (max-c 0))
                              (if (null? ls) max-c
                                (let ((pos (string-contains (car ls) sep)))
                                  (loop (cdr ls) (if pos (max max-c pos) max-c))))))
                   ;; Pad each line so separator aligns
                   (aligned (map (lambda (l)
                                   (let ((pos (string-contains l sep)))
                                     (if pos
                                       (string-append
                                         (substring l 0 pos)
                                         (make-string (- max-col pos) #\space)
                                         (substring l pos (string-length l)))
                                       l)))
                                 lines))
                   (result (string-join aligned "\n")))
              (send-message ed 2160 sel-start 0)
              (send-message ed 2161 sel-end 0)
              (send-message/string ed SCI_REPLACETARGET result)))))))

  ;; --- Rectangle enhancements ---

  (define (cmd-clear-rectangle app)
    (let* ((ed (current-editor app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (when (< sel-start sel-end)
        (let* ((text (editor-get-text ed))
               (start-line (send-message ed 2166 sel-start 0))
               (end-line (send-message ed 2166 sel-end 0))
               (start-col (send-message ed 2008 sel-start 0))  ;; SCI_GETCOLUMN
               (end-col (send-message ed 2008 sel-end 0))
               (min-col (min start-col end-col))
               (max-col (max start-col end-col))
               (lines (string-split text #\newline))
               (result-lines
                 (let loop ((ls lines) (n 0) (acc '()))
                   (if (null? ls)
                     (reverse acc)
                     (let ((l (car ls)))
                       (if (and (>= n start-line) (<= n end-line))
                         (let* ((len (string-length l))
                                (before (substring l 0 (min min-col len)))
                                (spaces (make-string (- max-col min-col) #\space))
                                (after (if (< max-col len)
                                         (substring l max-col len)
                                         "")))
                           (loop (cdr ls) (+ n 1) (cons (string-append before spaces after) acc)))
                         (loop (cdr ls) (+ n 1) (cons l acc)))))))
               (result (string-join result-lines "\n")))
          (editor-set-text ed result)))))

  ;; --- Abbrev mode ---
  ;; *abbrev-table* and *abbrev-mode-enabled* are defined in persist.sls

  (define (cmd-abbrev-mode app)
    (abbrev-mode-enabled-set! (not (abbrev-mode-enabled)))
    (echo-message! (app-state-echo app)
      (if (abbrev-mode-enabled) "Abbrev mode enabled" "Abbrev mode disabled")))

  (define (cmd-define-abbrev app)
    (let ((abbrev (app-read-string app "Abbrev: ")))
      (when (and abbrev (not (string=? abbrev "")))
        (let ((expansion (app-read-string app "Expansion: ")))
          (when (and expansion (not (string=? expansion "")))
            (hash-put! (abbrev-table) abbrev expansion)
            (echo-message! (app-state-echo app)
                           (string-append "Defined: " abbrev " -> " expansion)))))))

  (define (abbrev-word-before-point ed)
    (let* ((pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      (if (<= pos 0)
        (values #f #f)
        (let loop ((i (- pos 1)) (end pos))
          (if (< i 0)
            (values 0 end)
            (let ((ch (string-ref text i)))
              (if (or (char-alphabetic? ch) (char-numeric? ch))
                (loop (- i 1) end)
                (if (= (+ i 1) end)
                  (values #f #f)
                  (values (+ i 1) end)))))))))

  (define (cmd-expand-abbrev app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app)))
      (let-values (((start end) (abbrev-word-before-point ed)))
        (if (not start)
          (echo-message! echo "No word to expand")
          (let* ((text (editor-get-text ed))
                 (word (substring text start end))
                 (expansion (hash-get (abbrev-table) word)))
            (if (not expansion)
              (echo-message! echo (string-append "No abbrev for \"" word "\""))
              (begin
                ;; Delete the abbreviation
                (editor-goto-pos ed start)
                (editor-set-selection ed start end)
                (editor-replace-selection ed "")
                ;; Insert the expansion
                (editor-insert-text ed start expansion)
                (editor-goto-pos ed (+ start (string-length expansion)))
                (echo-message! echo (string-append "Expanded: " word " -> " expansion)))))))))

  (define (cmd-list-abbrevs app)
    (let* ((abbrevs (hash->list (abbrev-table)))
           (text (if (null? abbrevs)
                   "No abbreviations defined.\n\nUse M-x define-abbrev to add abbreviations."
                   (string-append "Abbreviations:\n\n"
                     (string-join
                       (map (lambda (pair)
                              (string-append "  " (car pair) " -> " (cdr pair)))
                            (list-sort (lambda (a b) (string<? (car a) (car b))) abbrevs))
                       "\n")
                     "\n\nUse M-x define-abbrev to add more."))))
      (open-output-buffer app "*Abbrevs*" text)))

  ;; --- Completion ---

  (define (cmd-completion-at-point app)
    (cmd-hippie-expand app))

  (define (cmd-complete-filename app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      ;; Get path-like prefix
      (let* ((start (let loop ((i (- pos 1)))
                      (if (and (>= i 0)
                               (not (memv (string-ref text i) '(#\space #\tab #\newline #\( #\)))))
                        (loop (- i 1))
                        (+ i 1))))
             (prefix (substring text start pos)))
        (if (string=? prefix "")
          (echo-message! (app-state-echo app) "No filename prefix")
          (guard (e [#t
                     (echo-message! (app-state-echo app) "Cannot complete")])
            (let* ((dir (path-directory prefix))
                   (base (path-strip-directory prefix))
                   (entries (directory-list (if (string=? dir "") "." dir)))
                   (matches (filter (lambda (f)
                                      (and (>= (string-length f) (string-length base))
                                           (string=? (substring f 0 (string-length base)) base)))
                                    entries)))
              (cond
                ((null? matches)
                 (echo-message! (app-state-echo app) "No completions"))
                ((= (length matches) 1)
                 (let ((completion (string-append dir (car matches))))
                   (send-message ed 2160 start 0)
                   (send-message ed 2161 pos 0)
                   (send-message/string ed SCI_REPLACETARGET completion)))
                (else
                 (echo-message! (app-state-echo app)
                                (string-append (number->string (length matches)) " completions"))))))))))

  ;; --- Window resize ---

  (define (cmd-resize-window-width app)
    (echo-message! (app-state-echo app) "Window uses full terminal width"))

  ;; --- Text operations ---

  (define (cmd-zap-to-char-inclusive app)
    (echo-message! (app-state-echo app) "Zap to char (inclusive): ")
    (let ((ev (tui-poll-event)))
      (when ev
        (let* ((ks (key-event->string ev))
               (ch (if (= (string-length ks) 1) (string-ref ks 0) #f)))
          (when ch
            (let* ((ed (current-editor app))
                   (pos (editor-get-current-pos ed))
                   (text (editor-get-text ed))
                   (len (string-length text)))
              (let loop ((i (+ pos 1)))
                (cond
                  ((>= i len)
                   (echo-message! (app-state-echo app)
                                  (string-append "Character not found: " ks)))
                  ((char=? (string-ref text i) ch)
                   ;; Kill from pos to i+1 (inclusive)
                   (let ((killed (substring text pos (+ i 1))))
                     (app-state-kill-ring-set! app
                       (cons killed (app-state-kill-ring app)))
                     (send-message ed 2160 pos 0)
                     (send-message ed 2161 (+ i 1) 0)
                     (send-message/string ed SCI_REPLACETARGET "")))
                  (else (loop (+ i 1)))))))))))

  (define (cmd-copy-word-at-point app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (when (> len 0)
        (let* ((ws (let loop ((i pos))
                     (if (and (> i 0) (word-char? (string-ref text (- i 1))))
                       (loop (- i 1)) i)))
               (we (let loop ((i pos))
                     (if (and (< i len) (word-char? (string-ref text i)))
                       (loop (+ i 1)) i)))
               (word (if (< ws we) (substring text ws we) "")))
          (if (string=? word "")
            (echo-message! (app-state-echo app) "No word at point")
            (begin
              (app-state-kill-ring-set! app
                (cons word (app-state-kill-ring app)))
              (echo-message! (app-state-echo app)
                             (string-append "Copied: " word))))))))

  (define (cmd-copy-symbol-at-point app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text))
           (sym-char? (lambda (ch)
                        (or (char-alphabetic? ch)
                            (char-numeric? ch)
                            (memv ch '(#\- #\_ #\! #\? #\*))))))
      (when (> len 0)
        (let* ((ws (let loop ((i pos))
                     (if (and (> i 0) (sym-char? (string-ref text (- i 1))))
                       (loop (- i 1)) i)))
               (we (let loop ((i pos))
                     (if (and (< i len) (sym-char? (string-ref text i)))
                       (loop (+ i 1)) i)))
               (sym (if (< ws we) (substring text ws we) "")))
          (if (string=? sym "")
            (echo-message! (app-state-echo app) "No symbol at point")
            (begin
              (app-state-kill-ring-set! app
                (cons sym (app-state-kill-ring app)))
              (echo-message! (app-state-echo app)
                             (string-append "Copied: " sym))))))))

  (define (cmd-mark-page app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed)))
      (editor-set-selection-start ed 0)
      (editor-set-selection-end ed (string-length text))
      (echo-message! (app-state-echo app) "Buffer marked")))

  ;; --- Encoding/display ---

  (define (cmd-set-language-environment app)
    (let ((lang (app-read-string app "Language environment (UTF-8): ")))
      (when (and lang (not (string=? lang "")))
        (echo-message! (app-state-echo app)
                       (string-append "Language environment: " lang " (UTF-8 is default)")))))

  ;; --- Theme/color ---

  (define (cmd-load-theme app)
    (let* ((available (map symbol->string (theme-names)))
           (theme-str (app-read-string app
                        (string-append "Load theme (" (car available) "): "))))
      (when (and theme-str (not (string=? theme-str "")))
        (let ((theme-sym (string->symbol theme-str)))
          (if (theme-get theme-sym)
            (begin
              ;; Load theme faces into *faces* registry
              (load-theme! theme-sym)
              ;; Re-apply highlighting to current buffer
              (let ((ed (current-editor app)))
                (setup-gerbil-highlighting! ed))
              ;; Persist theme choice
              (theme-settings-save! (current-theme-name) (default-font-family) (default-font-size))
              (echo-message! (app-state-echo app)
                (string-append "Theme: " theme-str)))
            (echo-message! (app-state-echo app)
              (string-append "Unknown theme: " theme-str
                            " (available: " (string-join available ", ") ")")))))))

  (define (cmd-customize-face app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (style (send-message ed SCI_GETSTYLEAT pos 0)))
      (echo-message! (app-state-echo app)
                     (string-append "Style at point: " (number->string style)))))

  (define (cmd-list-colors app)
    (let ((colors "black red green yellow blue magenta cyan white\nbright-black bright-red bright-green bright-yellow\nbright-blue bright-magenta bright-cyan bright-white"))
      (open-output-buffer app "*Colors*" colors)))

  ;; --- Text property/overlay ---

  (define (cmd-font-lock-mode app)
    (cmd-toggle-highlighting app))

  ;; --- Auto-revert ---

  (define (cmd-auto-revert-mode app)
    (set! *auto-revert-mode* (not *auto-revert-mode*))
    (echo-message! (app-state-echo app)
                   (if *auto-revert-mode*
                     "Auto-revert mode enabled"
                     "Auto-revert mode disabled")))

  ;; --- Diff enhancements ---

  (define (cmd-diff-backup app)
    (let* ((buf (current-buffer-from-app app))
           (file (buffer-file-path buf)))
      (if file
        (let ((backup (string-append file "~")))
          (if (file-exists? backup)
            (guard (e [#t
                       (echo-message! (app-state-echo app) "Error running diff")])
              (let-values (((output status)
                            (run-process-capture "diff" (list "-u" backup file))))
                (open-output-buffer app "*Diff Backup*" (if (string=? output "") "No differences" output))))
            (echo-message! (app-state-echo app) "No backup file found")))
        (echo-message! (app-state-echo app) "Buffer is not visiting a file"))))

  ;; --- Compilation ---

  (define (cmd-first-error app)
    (let* ((fr (app-state-frame app))
           (ed (current-editor app))
           (compile-buf
             (let loop ((bufs (buffer-list)))
               (if (null? bufs) #f
                 (if (string=? (buffer-name (car bufs)) "*compile*")
                   (car bufs) (loop (cdr bufs)))))))
      (if compile-buf
        (begin
          (buffer-attach! ed compile-buf)
          (edit-window-buffer-set! (current-window fr) compile-buf)
          (editor-goto-pos ed 0)
          (echo-message! (app-state-echo app) "First error"))
        (echo-message! (app-state-echo app) "No compilation output"))))

  ;; --- Calculator enhancements ---

  (define (cmd-quick-calc app)
    (let ((expr (app-read-string app "Quick calc: ")))
      (when (and expr (not (string=? expr "")))
        (let-values (((result error?) (eval-expression-string expr)))
          (echo-message! (app-state-echo app)
                         (if error?
                           (string-append "Error: " result)
                           (string-append "= " result)))))))

  ;; --- String insertion ---

  (define (cmd-insert-time app)
    (guard (e [#t
               (echo-message! (app-state-echo app) "Error getting time")])
      (let-values (((output status)
                    (run-process-capture "date" (list "+%H:%M:%S"))))
        (let* ((time-str output)
               (ed (current-editor app))
               (pos (editor-get-current-pos ed)))
          (editor-insert-text ed pos time-str)
          (editor-goto-pos ed (+ pos (string-length time-str)))))))

  (define (cmd-insert-file-header app)
    (let* ((buf (current-buffer-from-app app))
           (name (buffer-name buf))
           (ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (header (string-append ";;; -*- Gerbil -*-\n"
                                  ";;; " name "\n"
                                  ";;;\n"
                                  ";;; Description: \n"
                                  ";;;\n\n")))
      (editor-insert-text ed pos header)
      (editor-goto-pos ed (+ pos (string-length header)))))

  ;; --- Misc ---

  (define (cmd-toggle-debug-on-quit app)
    (set! *debug-on-quit* (not *debug-on-quit*))
    (echo-message! (app-state-echo app)
                   (if *debug-on-quit*
                     "Debug on quit enabled"
                     "Debug on quit disabled")))

  (define (cmd-profiler-start app)
    (set! *profiler-running* #t)
    (set! *profiler-start-time* (cpu-time))
    (echo-message! (app-state-echo app) "Profiler started"))

  (define (cmd-profiler-stop app)
    (if *profiler-running*
      (let* ((end-time (cpu-time))
             (start *profiler-start-time*)
             (elapsed (- end-time start))
             (report (string-append
                       "Profiler Report\n"
                       "===============\n"
                       "CPU time: " (number->string elapsed) "ms\n")))
        (set! *profiler-running* #f)
        (open-output-buffer app "*Profiler Report*" report))
      (echo-message! (app-state-echo app) "Profiler not running")))

  (define (cmd-memory-report app)
    (guard (e [#t
               (echo-message! (app-state-echo app) "Error getting memory info")])
      (let* ((content (read-file-as-string "/proc/self/status"))
             (lines (string-split content #\newline))
             (vm-line (let loop ((ls lines))
                        (if (null? ls) "Unknown"
                          (if (string-contains (car ls) "VmRSS:")
                            (car ls) (loop (cdr ls)))))))
        (echo-message! (app-state-echo app) (string-trim-both vm-line)))))

  (define (cmd-emacs-version app)
    (echo-message! (app-state-echo app) "jemacs 0.1"))

  (define (cmd-report-bug app)
    (echo-message! (app-state-echo app) "Report bugs at: https://github.com/ober/jerboa-emacs/issues"))

  (define (cmd-view-echo-area-messages app)
    (cmd-view-messages app))

  (define (cmd-toggle-menu-bar-mode app)
    (echo-message! (app-state-echo app) "Menu bar not available in TUI mode"))

  (define (cmd-toggle-tab-bar-mode app)
    (echo-message! (app-state-echo app)
                   (string-append "Tabs: " (number->string (length (app-state-tabs app)))
                                  " open (use C-x t for tab commands)")))

  (define (cmd-split-window-below app)
    (cmd-split-window app))

  (define (cmd-delete-window-below app)
    (let ((wins (frame-windows (app-state-frame app))))
      (if (>= (length wins) 2)
        (begin
          (frame-other-window! (app-state-frame app))
          (frame-delete-window! (app-state-frame app))
          (echo-message! (app-state-echo app) "Window below deleted"))
        (echo-message! (app-state-echo app) "No window below"))))

  (define (cmd-shrink-window-if-larger-than-buffer app)
    (let* ((ed (current-editor app))
           (lines (send-message ed SCI_GETLINECOUNT 0 0)))
      (echo-message! (app-state-echo app)
                     (string-append "Buffer: " (number->string lines) " lines"))))

  (define (cmd-toggle-frame-fullscreen app)
    (echo-message! (app-state-echo app) "TUI uses full terminal -- resize terminal for fullscreen"))

  (define (cmd-toggle-frame-maximized app)
    (echo-message! (app-state-echo app) "TUI uses full terminal -- maximize terminal window"))

  ;; --- Spell checking ---

  (define (ispell-args)
    (if *ispell-dictionary*
      (list "-a" "-d" *ispell-dictionary*)
      (list "-a")))

  (define (cmd-ispell-word app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app)))
      (let-values (((start end) (word-at-point ed)))
        (if (not start)
          (echo-message! echo "No word at point")
          (let* ((text (editor-get-text ed))
                 (word (substring text start end)))
            ;; Run aspell to check the word
            (guard (e [#t (echo-error! echo "aspell not available")])
              (let* ((aspell-output (run-aspell-process (ispell-args)
                                      (string-append word "\n")))
                     (result-lines (string-split aspell-output #\newline))
                     ;; First line is version, second is result
                     (result-line (if (>= (length result-lines) 2)
                                    (cadr result-lines)
                                    "")))
                (cond
                  ((string=? result-line "")
                   (echo-message! echo "Spell check failed"))
                  ((string-prefix? "*" result-line)
                   (echo-message! echo (string-append "\"" word "\" is correct")))
                  ((string-prefix? "&" result-line)
                   ;; Misspelled with suggestions
                   (let* ((colon-pos (string-index result-line #\:))
                          (suggestions (if colon-pos
                                         (string-trim
                                           (substring result-line (+ colon-pos 1)
                                                      (string-length result-line)))
                                         "none")))
                     (echo-message! echo (string-append "\"" word "\" misspelled. Try: " suggestions))))
                  ((string-prefix? "#" result-line)
                   ;; Misspelled with no suggestions
                   (echo-message! echo (string-append "\"" word "\" misspelled, no suggestions")))
                  (else
                   (echo-message! echo (string-append "\"" word "\" is correct")))))))))))

  (define (ispell-extract-words text)
    (let loop ((i 0) (words '()) (word-start #f))
      (if (>= i (string-length text))
        (if word-start
          (reverse (cons (substring text word-start i) words))
          (reverse words))
        (let ((ch (string-ref text i)))
          (cond
            ((char-alphabetic? ch)
             (if word-start
               (loop (+ i 1) words word-start)
               (loop (+ i 1) words i)))
            (word-start
             (loop (+ i 1) (cons (substring text word-start i) words) #f))
            (else
             (loop (+ i 1) words #f)))))))

  (define (cmd-ispell-buffer app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (words (ispell-extract-words text)))
      (if (null? words)
        (echo-message! echo "No words in buffer")
        (guard (e [#t (echo-error! echo "aspell not available")])
          (let* ((input-text (apply string-append
                               (map (lambda (w) (string-append w "\n")) words)))
                 (aspell-output (run-aspell-process (ispell-args) input-text))
                 (result-lines (string-split aspell-output #\newline)))
            ;; Parse results: skip version line, collect misspelled words
            (let loop ((lines (if (pair? result-lines) (cdr result-lines) '()))
                       (misspelled '()))
              (if (null? lines)
                (if (null? misspelled)
                  (echo-message! echo "No misspellings found")
                  (let* ((unique (let remove-dups ((lst (reverse misspelled)) (seen '()))
                                   (cond ((null? lst) (reverse seen))
                                         ((member (car lst) seen) (remove-dups (cdr lst) seen))
                                         (else (remove-dups (cdr lst) (cons (car lst) seen))))))
                         (count (length unique))
                         (shown (if (> count 5)
                                  (string-append (string-join (take unique 5) ", ") "...")
                                  (string-join unique ", "))))
                    (echo-message! echo
                      (string-append (number->string count) " misspelling(s): " shown))))
                (let ((line (car lines)))
                  (cond
                    ((or (string-prefix? "&" line) (string-prefix? "#" line))
                     (let* ((parts (string-split line #\space))
                            (word (if (> (length parts) 1) (cadr parts) "?")))
                       (loop (cdr lines) (cons word misspelled))))
                    (else
                     (loop (cdr lines) misspelled)))))))))))

  (define (cmd-ispell-region app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark-pos (buffer-mark buf)))
      (if (not mark-pos)
        (echo-message! echo "No region set (use C-SPC to set mark)")
        (let* ((pos (editor-get-current-pos ed))
               (start (min pos mark-pos))
               (end (max pos mark-pos))
               (text (editor-get-text ed))
               (region (substring text start (min end (string-length text))))
               (words (ispell-extract-words region)))
          (if (null? words)
            (echo-message! echo "No words in region")
            (guard (e [#t (echo-error! echo "aspell not available")])
              (let* ((input-text (apply string-append
                                   (map (lambda (w) (string-append w "\n")) words)))
                     (aspell-output (run-aspell-process (ispell-args) input-text))
                     (result-lines (string-split aspell-output #\newline)))
                ;; Parse results: skip version line
                (let loop ((lines (if (pair? result-lines) (cdr result-lines) '()))
                           (misspelled '()))
                  (if (null? lines)
                    (if (null? misspelled)
                      (echo-message! echo "Region: no misspellings")
                      (echo-message! echo
                        (string-append "Region: " (number->string (length misspelled))
                                       " misspelling(s)")))
                    (let ((line (car lines)))
                      (cond
                        ((or (string-prefix? "&" line) (string-prefix? "#" line))
                         (let* ((parts (string-split line #\space))
                                (word (if (> (length parts) 1) (cadr parts) "?")))
                           (loop (cdr lines) (cons word misspelled))))
                        (else
                         (loop (cdr lines) misspelled)))))))))))))

  (define (cmd-ispell-change-dictionary app)
    (let* ((echo (app-state-echo app))
           (current (or *ispell-dictionary* "default"))
           (choice (app-read-string app
                     (string-append "Dictionary (" current "): "))))
      (when (and choice (not (string=? choice "")))
        (if (string=? choice "default")
          (begin (set! *ispell-dictionary* #f)
                 (echo-message! echo "Dictionary: system default"))
          (begin (set! *ispell-dictionary* choice)
                 (echo-message! echo
                   (string-append "Dictionary: " choice)))))))

  ;; --- Process management ---

  (define (cmd-ansi-term app)
    (execute-command! app 'term))

  ;; --- Dired subtree: inline subdirectory expansion ---

  (define (cmd-dired-subtree-toggle app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app))
           (buf (edit-window-buffer win))
           (name (and buf (buffer-name buf))))
      (if (not (and name (string-prefix? "*Dired:" name)))
        (echo-message! echo "Not in a dired buffer")
        (let* ((pos (send-message ed SCI_GETCURRENTPOS 0 0))
               (line-num (send-message ed SCI_LINEFROMPOSITION pos 0))
               (line-start (send-message ed SCI_POSITIONFROMLINE line-num 0))
               (line-end (send-message ed SCI_GETLINEENDPOSITION line-num 0))
               (line-text (editor-get-text-range ed line-start line-end))
               (expanded (or (hash-get *dired-expanded-dirs* name) (make-hash-table))))
          ;; Extract directory path from dired line (last field after permissions/date)
          (let* ((trimmed (string-trim-both line-text))
                 (parts (string-split trimmed #\space))
                 (last-part (if (pair? parts) (car (last-pair parts)) #f)))
            (when (and last-part (not (string=? last-part ""))
                       (not (member last-part '("." ".." "total"))))
              ;; Try to find the dired root directory from buffer name
              (let* ((dir-match (and (> (string-length name) 8)
                                      (substring name 8 (- (string-length name) 1))))
                     (full-path (if dir-match
                                  (string-append dir-match "/" last-part)
                                  last-part)))
                (if (and (file-exists? full-path) (file-directory? full-path))
                  (if (hash-get expanded full-path)
                    ;; Collapse: remove expanded lines
                    (begin
                      (hash-remove! expanded full-path)
                      (hash-put! *dired-expanded-dirs* name expanded)
                      ;; Remove indented lines below
                      (let rm-loop ((next-line (+ line-num 1)))
                        (let* ((ns (send-message ed SCI_POSITIONFROMLINE next-line 0))
                               (ne (send-message ed SCI_GETLINEENDPOSITION next-line 0)))
                          (when (> ne ns)
                            (let ((nt (editor-get-text-range ed ns ne)))
                              (when (string-prefix? "    " nt)
                                (send-message ed SCI_SETREADONLY 0 0)
                                (let ((del-end (send-message ed SCI_POSITIONFROMLINE (+ next-line 1) 0)))
                                  (send-message ed SCI_DELETERANGE ns (- del-end ns)))
                                (send-message ed SCI_SETREADONLY 1 0)
                                (rm-loop next-line))))))
                      (echo-message! echo (string-append "Collapsed: " last-part)))
                    ;; Expand: insert directory listing indented
                    (guard (e [#t (echo-message! echo "Cannot read directory")])
                      (let* ((entries (directory-list full-path))
                             (sorted (list-sort string<? entries))
                             (lines (map (lambda (f)
                                           (let* ((fp (string-append full-path "/" f))
                                                  (is-dir (and (file-exists? fp)
                                                               (file-directory? fp))))
                                             (string-append "    " (if is-dir "d " "  ") f
                                                            (if is-dir "/" ""))))
                                         sorted))
                             (insert-text (string-append "\n" (string-join lines "\n")))
                             (insert-pos (send-message ed SCI_GETLINEENDPOSITION line-num 0)))
                        (hash-put! expanded full-path #t)
                        (hash-put! *dired-expanded-dirs* name expanded)
                        (send-message ed SCI_SETREADONLY 0 0)
                        (editor-insert-text ed insert-pos insert-text)
                        (send-message ed SCI_SETREADONLY 1 0)
                        (echo-message! echo (string-append "Expanded: " last-part
                                                           " (" (number->string (length entries)) " entries)")))))
                  (echo-message! echo (string-append "Not a directory: " last-part))))))))))

  ;; --- Project tree sidebar (treemacs-like) ---

  (define (project-tree-render dir depth max-depth)
    (if (> depth max-depth) '()
      (guard (e [#t '()])
        (let* ((entries (directory-list dir))
               (sorted (list-sort string<? entries))
               (indent (make-string (* depth 2) #\space)))
          (let loop ((es sorted) (acc '()))
            (if (null? es) (reverse acc)
              (let* ((f (car es))
                     (fp (string-append dir "/" f))
                     (is-dir (and (file-exists? fp) (file-directory? fp)))
                     (is-hidden (and (> (string-length f) 0) (char=? (string-ref f 0) #\.)))
                     (expanded (hash-get *project-tree-expanded* fp)))
                (if is-hidden
                  (loop (cdr es) acc)
                  (let ((line (string-append indent
                                (if is-dir
                                  (string-append (if expanded "v " "> ") f "/")
                                  (string-append "  " f)))))
                    (if (and is-dir expanded)
                      (let ((children (project-tree-render fp (+ depth 1) max-depth)))
                        (loop (cdr es) (append (reverse (cons line children)) acc)))
                      (loop (cdr es) (cons line acc))))))))))))

  (define (cmd-project-tree app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app))
           (root (project-current app)))
      (if (not root)
        (echo-message! echo "Not in a project")
        (let* ((lines (project-tree-render root 0 3))
               (header (string-append "Project: " (path-strip-directory root) "\n"
                                      (make-string 40 #\-) "\n"))
               (content (string-append header (string-join lines "\n") "\n"))
               (tbuf (buffer-create! "*Project Tree*" ed)))
          (buffer-attach! ed tbuf)
          (edit-window-buffer-set! win tbuf)
          (editor-set-text ed content)
          (editor-goto-pos ed 0)
          (editor-set-read-only ed #t)
          (echo-message! echo (string-append "Project tree: " root))))))

  (define (cmd-project-tree-toggle-node app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app))
           (buf (edit-window-buffer win))
           (name (and buf (buffer-name buf))))
      (if (not (equal? name "*Project Tree*"))
        (echo-message! echo "Not in project tree buffer")
        (let* ((pos (send-message ed SCI_GETCURRENTPOS 0 0))
               (line-num (send-message ed SCI_LINEFROMPOSITION pos 0))
               (line-start (send-message ed SCI_POSITIONFROMLINE line-num 0))
               (line-end (send-message ed SCI_GETLINEENDPOSITION line-num 0))
               (line-text (editor-get-text-range ed line-start line-end))
               (trimmed (string-trim-both line-text))
               (is-dir-line (string-suffix? "/" trimmed)))
          (if (not is-dir-line)
            (echo-message! echo "Not a directory")
            ;; Find the full path by walking from root
            (let* ((root (project-current app))
                   ;; Extract dir name: remove "> " or "v " prefix and trailing "/"
                   (dir-name (let ((s (cond
                                        ((string-prefix? "> " trimmed)
                                         (substring trimmed 2 (string-length trimmed)))
                                        ((string-prefix? "v " trimmed)
                                         (substring trimmed 2 (string-length trimmed)))
                                        (else trimmed))))
                               (if (string-suffix? "/" s)
                                 (substring s 0 (- (string-length s) 1))
                                 s)))
                   ;; Calculate depth from leading spaces
                   (spaces (- (string-length line-text) (string-length (string-trim line-text))))
                   (depth (quotient spaces 2))
                   ;; Build path by walking up lines
                   (full-path (if (= depth 0)
                                (string-append root "/" dir-name)
                                ;; Walk back to find parent dirs
                                (let walk ((ln (- line-num 1)) (parts (list dir-name)) (target-depth (- depth 1)))
                                  (if (or (< ln 2) (< target-depth 0))
                                    (apply string-append root
                                           (map (lambda (p) (string-append "/" p)) (reverse parts)))
                                    (let* ((ls (send-message ed SCI_POSITIONFROMLINE ln 0))
                                           (le (send-message ed SCI_GETLINEENDPOSITION ln 0))
                                           (lt (editor-get-text-range ed ls le))
                                           (sp (- (string-length lt) (string-length (string-trim lt))))
                                           (d (quotient sp 2)))
                                      (if (and (= d target-depth) (string-suffix? "/" (string-trim-both lt)))
                                        (let* ((t (string-trim-both lt))
                                               (n (cond ((string-prefix? "> " t)
                                                         (substring t 2 (- (string-length t) 1)))
                                                        ((string-prefix? "v " t)
                                                         (substring t 2 (- (string-length t) 1)))
                                                        (else (substring t 0 (- (string-length t) 1))))))
                                          (walk (- ln 1) (cons n parts) (- target-depth 1)))
                                        (walk (- ln 1) parts target-depth))))))))
              (if (hash-get *project-tree-expanded* full-path)
                (hash-remove! *project-tree-expanded* full-path)
                (hash-put! *project-tree-expanded* full-path #t))
              ;; Re-render the whole tree
              (let* ((lines (project-tree-render root 0 3))
                     (header (string-append "Project: " (path-strip-directory root) "\n"
                                            (make-string 40 #\-) "\n"))
                     (content (string-append header (string-join lines "\n") "\n")))
                (send-message ed SCI_SETREADONLY 0 0)
                (editor-set-text ed content)
                (editor-goto-pos ed (min pos (- (send-message ed SCI_GETLENGTH 0 0) 1)))
                (send-message ed SCI_SETREADONLY 1 0))))))))

  ;; --- Terminal per-project ---

  (define (cmd-project-term app)
    (let* ((echo (app-state-echo app))
           (root (project-current app)))
      (if (not root)
        (echo-message! echo "Not in a project")
        (let* ((term-name (or (hash-get *project-terminals* root)
                              (string-append "*term:" (path-strip-directory root) "*")))
               (existing (buffer-by-name term-name)))
          (if existing
            ;; Switch to existing terminal
            (let* ((fr (app-state-frame app))
                   (win (current-window fr))
                   (ed (edit-window-editor win)))
              (buffer-attach! ed existing)
              (edit-window-buffer-set! win existing)
              (echo-message! echo (string-append "Terminal: " (path-strip-directory root))))
            ;; Create new terminal in project root
            (begin
              (current-directory root)
              (hash-put! *project-terminals* root term-name)
              (execute-command! app 'shell)
              (echo-message! echo (string-append "New terminal in: " root))))))))

) ;; end library
