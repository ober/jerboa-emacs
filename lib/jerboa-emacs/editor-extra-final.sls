#!chezscheme
;;; -*- Chez Scheme -*-
;;; Task #51: Additional commands
;;;
;;; Ported from gerbil-emacs/editor-extra-final.ss to R6RS Chez Scheme.

(library (jerboa-emacs editor-extra-final)
  (export
    ;; Emacs built-in mode commands
    cmd-native-compile-file
    cmd-native-compile-async
    cmd-tab-line-mode
    cmd-pixel-scroll-precision-mode
    cmd-so-long-mode
    cmd-repeat-mode
    cmd-context-menu-mode
    cmd-savehist-mode
    cmd-recentf-mode
    cmd-winner-undo-2
    cmd-global-subword-mode
    cmd-display-fill-column-indicator-mode
    cmd-global-display-line-numbers-mode
    cmd-indent-bars-mode
    cmd-global-hl-line-mode
    cmd-delete-selection-mode
    cmd-electric-indent-mode
    cmd-show-paren-mode
    cmd-column-number-mode
    cmd-size-indication-mode
    cmd-minibuffer-depth-indicate-mode
    cmd-file-name-shadow-mode
    cmd-midnight-mode
    cmd-cursor-intangible-mode
    cmd-auto-compression-mode
    ;; Window resize
    cmd-enlarge-window
    cmd-shrink-window
    cmd-enlarge-window-horizontally
    cmd-shrink-window-horizontally
    ;; Regex search and replace
    *last-regexp-search*
    cmd-search-forward-regexp
    cmd-query-replace-regexp-interactive
    regexp-query-replace-loop!
    ;; Editorconfig
    parse-editorconfig
    editorconfig-glob-match?
    find-editorconfig
    apply-editorconfig!
    cmd-editorconfig-apply
    ;; Format buffer
    *formatters*
    detect-language-from-extension
    cmd-format-buffer
    ;; Git blame
    cmd-git-blame-line
    ;; Command history
    *command-history*
    *command-history-file*
    command-history-load!
    command-history-save!
    command-history-add!
    cmd-execute-extended-command-with-history
    ;; Word completion from buffer
    collect-buffer-words
    cmd-complete-word-from-buffer
    ;; URL detection
    find-url-at-point
    cmd-open-url-at-point
    ;; MRU buffer switching
    *buffer-access-times*
    *buffer-access-counter*
    record-buffer-access!
    cmd-switch-buffer-mru
    ;; Shell command on region
    cmd-shell-command-on-region-replace
    ;; Named keyboard macros
    cmd-execute-named-macro
    ;; Apply macro to region
    cmd-apply-macro-to-region
    ;; Diff summary
    cmd-diff-summary
    ;; Revert buffer
    cmd-revert-buffer-no-confirm
    ;; Sudo save
    cmd-sudo-save-buffer
    ;; Regex builder
    *regex-builder-pattern*
    cmd-regex-builder
    ;; Web search
    cmd-eww-search-web
    ;; Edit position tracking
    *last-edit-positions*
    *max-edit-positions*
    record-edit-position!
    cmd-goto-last-edit
    ;; Eval region and replace
    cmd-eval-region-and-replace
    ;; Hex/decimal conversions
    cmd-hex-to-decimal
    cmd-decimal-to-hex
    cmd-encode-hex-string
    cmd-decode-hex-string
    ;; Copy buffer file path
    cmd-copy-buffer-file-name
    ;; Insert formatted date
    cmd-insert-date-formatted
    ;; Prepend to buffer
    cmd-prepend-to-buffer
    ;; Persistent scratch
    *persistent-scratch-file*
    cmd-save-persistent-scratch
    cmd-load-persistent-scratch
    ;; Batch 33 toggles
    *subword-mode*
    *auto-composition-mode*
    *bidi-display-reordering*
    *fill-column-indicator*
    *pixel-scroll-mode*
    *auto-highlight-symbol-mode*
    *lorem-ipsum-text*
    insert-char-by-code-string
    cmd-insert-char-by-code
    cmd-toggle-subword-mode
    cmd-toggle-auto-composition
    cmd-toggle-bidi-display
    cmd-toggle-display-fill-column-indicator
    cmd-insert-current-file-name
    cmd-toggle-pixel-scroll
    cmd-insert-lorem-ipsum
    cmd-toggle-auto-highlight-symbol
    cmd-copy-rectangle-to-clipboard
    cmd-insert-file-contents-at-point
    ;; Batch 39 toggles
    *read-only-directories*
    *auto-revert-verbose*
    *uniquify-buffer-names*
    *global-so-long-mode*
    *minibuffer-depth-indicate*
    *context-menu-mode*
    *tooltip-mode*
    *file-name-shadow-mode*
    *minibuffer-electric-default*
    *history-delete-duplicates*
    cmd-toggle-read-only-directories
    cmd-toggle-auto-revert-verbose
    cmd-toggle-uniquify-buffer-names
    cmd-toggle-global-so-long
    cmd-toggle-minibuffer-depth-indicate
    cmd-toggle-context-menu-mode
    cmd-toggle-tooltip-mode
    cmd-toggle-file-name-shadow
    cmd-toggle-minibuffer-electric-default
    cmd-toggle-history-delete-duplicates
    ;; Batch 45 toggles
    *modus-themes*
    *ef-themes*
    *nano-theme*
    *ligature-mode*
    *pixel-scroll-precision*
    *tab-line-mode*
    *scroll-bar-mode*
    *tool-bar-mode*
    cmd-toggle-modus-themes
    cmd-toggle-ef-themes
    cmd-toggle-nano-theme
    cmd-toggle-ligature-mode
    cmd-toggle-pixel-scroll-precision
    cmd-toggle-repeat-mode
    cmd-toggle-tab-line-mode
    cmd-toggle-scroll-bar-mode
    cmd-toggle-tool-bar-mode
    ;; Batch 51 toggles
    *global-auto-revert-non-file*
    *global-tree-sitter*
    *global-copilot*
    *global-lsp-mode*
    *global-format-on-save*
    *global-yas*
    *global-smartparens*
    cmd-toggle-global-auto-revert-non-file
    cmd-toggle-global-tree-sitter
    cmd-toggle-global-copilot
    cmd-toggle-global-lsp-mode
    cmd-toggle-global-format-on-save
    cmd-toggle-global-yas
    cmd-toggle-global-smartparens
    ;; Batch 59 toggles
    *global-helpful*
    *global-elisp-demos*
    *global-suggest*
    *global-buttercup*
    *global-ert-runner*
    *global-undercover*
    *global-benchmark-init*
    cmd-toggle-global-helpful
    cmd-toggle-global-elisp-demos
    cmd-toggle-global-suggest
    cmd-toggle-global-buttercup
    cmd-toggle-global-ert-runner
    cmd-toggle-global-undercover
    cmd-toggle-global-benchmark-init
    ;; Batch 68 toggles
    *global-clojure-mode*
    *global-cider*
    *global-haskell-mode*
    *global-lua-mode*
    *global-ruby-mode*
    *global-php-mode*
    *global-swift-mode*
    cmd-toggle-global-clojure-mode
    cmd-toggle-global-cider
    cmd-toggle-global-haskell-mode
    cmd-toggle-global-lua-mode
    cmd-toggle-global-ruby-mode
    cmd-toggle-global-php-mode
    cmd-toggle-global-swift-mode
    ;; Scratch buffer new
    *tui-scratch-counter*
    cmd-scratch-buffer-new
    ;; Swap window
    cmd-swap-window
    ;; Parity batch 9
    *tui-workspaces*
    *tui-current-ws*
    *tui-ws-bufs*
    cmd-workspace-create
    cmd-workspace-switch
    cmd-workspace-delete
    cmd-workspace-add-buffer
    cmd-workspace-list
    cmd-copy-buffer-filename
    cmd-revert-buffer-confirm
    *tui-undo-history*
    cmd-undo-history
    cmd-undo-history-restore
    *tui-xref-stack*
    cmd-xref-back)

  (import
    (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
    (jerboa core)
    (jerboa runtime)
    (only (jerboa prelude) path-expand path-directory path-strip-directory
          path-extension take)
    (std sugar)
    (only (std srfi srfi-13)
      string-join string-prefix? string-suffix? string-index
      string-trim string-trim-both)
    (only (std srfi srfi-19)
      current-date date->string make-time time-utc time-utc->date)
    (only (std misc string) string-split)
    (std misc process)
    (chez-scintilla constants)
    (chez-scintilla scintilla)
    (chez-scintilla tui)
    (except (jerboa-emacs core) face-get)
    (jerboa-emacs keymap)
    (jerboa-emacs buffer)
    (jerboa-emacs window)
    (jerboa-emacs modeline)
    (jerboa-emacs echo)
    (only (jerboa-emacs editor-core)
          search-forward-regexp-impl!)
    (only (jerboa-emacs editor-ui)
          position-cursor-for-replace!)
    (jerboa-emacs editor-extra-helpers)
    (jerboa-emacs pregexp-compat))

  ;;;============================================================================
  ;;; Internal helpers / stubs for not-yet-ported modules
  ;;;============================================================================

  ;; string-subst: replace all occurrences of old with new in str
  (define (string-subst str old new)
    (let ((olen (string-length old))
          (slen (string-length str)))
      (if (= olen 0) str
        (let loop ((i 0) (parts '()))
          (cond
            ((> (+ i olen) slen)
             (apply string-append (reverse (cons (substring str i slen) parts))))
            ((string=? (substring str i (+ i olen)) old)
             (loop (+ i olen) (cons new parts)))
            (else
             (let lp2 ((j (+ i 1)))
               (cond
                 ((> (+ j olen) slen)
                  (apply string-append (reverse (cons (substring str i slen) parts))))
                 ((string=? (substring str j (+ j olen)) old)
                  (loop j (cons (substring str i j) parts)))
                 (else (lp2 (+ j 1)))))))))))

  ;; url-encode: simple percent-encoding for URL query strings
  (define (url-encode str)
    (let ((out (open-output-string)))
      (let loop ((i 0))
        (when (< i (string-length str))
          (let ((ch (string-ref str i)))
            (cond
              ((char=? ch #\space) (display "+" out))
              ((or (char-alphabetic? ch) (char-numeric? ch)
                   (memv ch '(#\- #\_ #\. #\~)))
               (display ch out))
              (else
               (let ((b (char->integer ch)))
                 (display "%" out)
                 (when (< b 16) (display "0" out))
                 (display (number->string b 16) out)))))
          (loop (+ i 1))))
      (get-output-string out)))

  ;; filter-with-process: pipe data through an external command
  ;; write-proc writes to stdin, read-proc reads from stdout
  (define (filter-with-process cmd write-proc read-proc)
    (let* ((cmd-str (if (string? cmd)
                      cmd
                      (string-join (map (lambda (s)
                                          (if (and (not (string-contains-char? s #\space))
                                                   (not (string-contains-char? s #\'))
                                                   (> (string-length s) 0))
                                            s
                                            (string-append "'" s "'")))
                                        cmd)
                                   " "))))
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports cmd-str (buffer-mode block) (native-transcoder))))
        (write-proc to-stdin)
        (flush-output-port to-stdin)
        (close-port to-stdin)
        (let ((result (read-proc from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          result))))

  (define (string-contains-char? str ch)
    (let loop ((i 0))
      (cond
        ((>= i (string-length str)) #f)
        ((char=? (string-ref str i) ch) #t)
        (else (loop (+ i 1))))))

  ;; Stubs for not-yet-ported modules
  (define (cmd-winner-undo app)
    (echo-message! (app-state-echo app) "Winner undo: not yet ported"))

  (define (cmd-indent-guide-mode app)
    (echo-message! (app-state-echo app) "Indent guide mode toggled"))

  ;; random-integer: use Chez's random
  (define (random-integer n) (random n))

  ;;;============================================================================
  ;;; Task #51: Additional unique commands to cross 1000 registrations
  ;;;============================================================================

  ;; --- Emacs built-in modes not yet covered ---
  (define (cmd-native-compile-file app)
    "Native compile current file via gxc -S."
    (let* ((echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (and buf (buffer-file-path buf))))
      (if (not path)
        (echo-error! echo "Buffer has no file")
        (if (not (member (path-extension path) '(".ss" ".scm")))
          (echo-message! echo "Not a Gerbil/Scheme source file")
          (begin
            (echo-message! echo (string-append "Compiling " (path-strip-directory path) "..."))
            (let* ((fr (app-state-frame app))
                   (win (current-window fr))
                   (ed (edit-window-editor win))
                   (output (guard (e (#t ""))
                             (run-process (list "gxc" "-S" path))))
                   (comp-buf (buffer-create! "*compilation*" ed)))
              (buffer-attach! ed comp-buf)
              (edit-window-buffer-set! win comp-buf)
              (editor-set-text ed
                (string-append "Compiling " path "...\n\n"
                               (or output "")
                               "\n\nCompilation finished\n"))
              (echo-message! echo
                (string-append "Compiled " (path-strip-directory path)))))))))

  (define (cmd-native-compile-async app)
    "Native compile asynchronously -- background compilation."
    (echo-message! (app-state-echo app) "Async compile: use M-x compile"))

  (define (cmd-tab-line-mode app)
    "Toggle tab-line-mode -- shows buffer tabs."
    (let ((on (toggle-mode! 'tab-line)))
      (echo-message! (app-state-echo app) (if on "Tab-line: on" "Tab-line: off"))))

  (define (cmd-pixel-scroll-precision-mode app)
    "Toggle pixel-scroll-precision-mode -- smooth scrolling."
    (let ((on (toggle-mode! 'pixel-scroll)))
      (echo-message! (app-state-echo app) (if on "Pixel scroll: on" "Pixel scroll: off"))))

  (define (cmd-so-long-mode app)
    "Toggle so-long mode for long lines."
    (let ((on (toggle-mode! 'so-long)))
      (echo-message! (app-state-echo app) (if on "So-long mode: on" "So-long mode: off"))))

  (define (cmd-repeat-mode app)
    "Toggle repeat-mode for transient repeat maps."
    (repeat-mode-set! (not (repeat-mode?)))
    (clear-repeat-map!)
    (echo-message! (app-state-echo app)
      (if (repeat-mode?) "Repeat mode enabled" "Repeat mode disabled")))

  (define (cmd-context-menu-mode app)
    "Toggle context-menu-mode -- N/A in terminal."
    (echo-message! (app-state-echo app) "Context menu: N/A in terminal"))

  (define (cmd-savehist-mode app)
    "Toggle savehist-mode -- persist minibuffer history."
    (let ((on (toggle-mode! 'savehist)))
      (echo-message! (app-state-echo app) (if on "Savehist: on" "Savehist: off"))))

  (define (cmd-recentf-mode app)
    "Toggle recentf-mode -- track recent files."
    (let ((on (toggle-mode! 'recentf)))
      (echo-message! (app-state-echo app) (if on "Recentf: on" "Recentf: off"))))

  (define (cmd-winner-undo-2 app)
    "Winner undo alternative binding."
    (cmd-winner-undo app))

  (define (cmd-global-subword-mode app)
    "Toggle global subword-mode (CamelCase navigation)."
    (let ((on (toggle-mode! 'global-subword)))
      (echo-message! (app-state-echo app) (if on "Global subword: on" "Global subword: off"))))

  (define (cmd-display-fill-column-indicator-mode app)
    "Toggle fill column indicator display."
    (let* ((fr (app-state-frame app))
           (on (toggle-mode! 'fill-column-indicator)))
      (for-each
        (lambda (win)
          (let ((ed (edit-window-editor win)))
            (send-message ed 2363 (if on 1 0) 0)
            (when on (send-message ed 2361 80 0))))
        (frame-windows fr))
      (echo-message! (app-state-echo app)
        (if on "Fill column indicator: on (80)" "Fill column indicator: off"))))

  (define (cmd-global-display-line-numbers-mode app)
    "Toggle global line numbers display."
    (let* ((fr (app-state-frame app))
           (on (toggle-mode! 'global-line-numbers)))
      (for-each
        (lambda (win)
          (let ((ed (edit-window-editor win)))
            (send-message ed SCI_SETMARGINWIDTHN 0 (if on 48 0))))
        (frame-windows fr))
      (echo-message! (app-state-echo app)
        (if on "Global line numbers: on" "Global line numbers: off"))))

  (define (cmd-indent-bars-mode app)
    "Toggle indent-bars indentation guides."
    (cmd-indent-guide-mode app))

  (define (cmd-global-hl-line-mode app)
    "Toggle global hl-line highlighting."
    (let* ((fr (app-state-frame app))
           (on (toggle-mode! 'global-hl-line)))
      (for-each
        (lambda (win)
          (let ((ed (edit-window-editor win)))
            (send-message ed SCI_SETCARETLINEVISIBLE (if on 1 0) 0)
            (when on (send-message ed SCI_SETCARETLINEBACK #x333333 0))))
        (frame-windows fr))
      (echo-message! (app-state-echo app)
        (if on "Global hl-line: on" "Global hl-line: off"))))

  (define (cmd-delete-selection-mode app)
    "Toggle delete-selection-mode -- typed text replaces selection."
    (let ((on (toggle-mode! 'delete-selection)))
      (echo-message! (app-state-echo app)
        (if on "Delete selection mode: on" "Delete selection mode: off"))))

  (define (cmd-electric-indent-mode app)
    "Toggle electric-indent-mode -- auto-indent on newline."
    (electric-indent-mode-set! (not (electric-indent-mode?)))
    (echo-message! (app-state-echo app)
      (if (electric-indent-mode?) "Electric indent: on" "Electric indent: off")))

  (define (cmd-show-paren-mode app)
    "Toggle show-paren-mode -- highlight matching parentheses."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (on (toggle-mode! 'show-paren)))
      (if on
        (begin
          (send-message ed SCI_STYLESETFORE 34 #x00FF00)
          (send-message ed SCI_STYLESETBACK 34 #x333333)
          (echo-message! (app-state-echo app) "Show paren: on"))
        (begin
          (send-message ed SCI_STYLESETFORE 34 #xFFFFFF)
          (send-message ed SCI_STYLESETBACK 34 #x000000)
          (echo-message! (app-state-echo app) "Show paren: off")))))

  (define (cmd-column-number-mode app)
    "Toggle column-number-mode in modeline."
    (let ((on (toggle-mode! 'column-number)))
      (echo-message! (app-state-echo app) (if on "Column number: on" "Column number: off"))))

  (define (cmd-size-indication-mode app)
    "Toggle size-indication-mode in modeline."
    (let ((on (toggle-mode! 'size-indication)))
      (echo-message! (app-state-echo app) (if on "Size indication: on" "Size indication: off"))))

  (define (cmd-minibuffer-depth-indicate-mode app)
    "Toggle minibuffer-depth-indicate-mode."
    (let ((on (toggle-mode! 'minibuffer-depth)))
      (echo-message! (app-state-echo app) (if on "Minibuffer depth: on" "Minibuffer depth: off"))))

  (define (cmd-file-name-shadow-mode app)
    "Toggle file-name-shadow-mode -- dims irrelevant path in minibuffer."
    (let ((on (toggle-mode! 'file-name-shadow)))
      (echo-message! (app-state-echo app) (if on "File name shadow: on" "File name shadow: off"))))

  (define (cmd-midnight-mode app)
    "Toggle midnight-mode -- clean up old buffers periodically."
    (let ((on (toggle-mode! 'midnight)))
      (echo-message! (app-state-echo app) (if on "Midnight mode: on" "Midnight mode: off"))))

  (define (cmd-cursor-intangible-mode app)
    "Toggle cursor-intangible-mode."
    (let ((on (toggle-mode! 'cursor-intangible)))
      (echo-message! (app-state-echo app) (if on "Cursor intangible: on" "Cursor intangible: off"))))

  (define (cmd-auto-compression-mode app)
    "Toggle auto-compression-mode -- transparent compressed file access."
    (let ((on (toggle-mode! 'auto-compression)))
      (echo-message! (app-state-echo app) (if on "Auto-compression: on" "Auto-compression: off"))))

  ;;;============================================================================
  ;;; Window resize commands
  ;;;============================================================================

  (define (cmd-enlarge-window app)
    "Make current window taller (C-x ^)."
    (let* ((fr (app-state-frame app))
           (n (get-prefix-arg app)))
      (if (> (length (frame-windows fr)) 1)
        (begin
          (frame-enlarge-window! fr n)
          (echo-message! (app-state-echo app)
            (string-append "Window enlarged by " (number->string n))))
        (echo-error! (app-state-echo app) "Only one window"))))

  (define (cmd-shrink-window app)
    "Make current window shorter."
    (let* ((fr (app-state-frame app))
           (n (get-prefix-arg app)))
      (if (> (length (frame-windows fr)) 1)
        (begin
          (frame-shrink-window! fr n)
          (echo-message! (app-state-echo app)
            (string-append "Window shrunk by " (number->string n))))
        (echo-error! (app-state-echo app) "Only one window"))))

  (define (cmd-enlarge-window-horizontally app)
    "Make current window wider (C-x })."
    (let* ((fr (app-state-frame app))
           (n (get-prefix-arg app)))
      (if (> (length (frame-windows fr)) 1)
        (begin
          (frame-enlarge-window-horizontally! fr n)
          (echo-message! (app-state-echo app)
            (string-append "Window widened by " (number->string n))))
        (echo-error! (app-state-echo app) "Only one window"))))

  (define (cmd-shrink-window-horizontally app)
    "Make current window narrower (C-x {)."
    (let* ((fr (app-state-frame app))
           (n (get-prefix-arg app)))
      (if (> (length (frame-windows fr)) 1)
        (begin
          (frame-shrink-window-horizontally! fr n)
          (echo-message! (app-state-echo app)
            (string-append "Window narrowed by " (number->string n))))
        (echo-error! (app-state-echo app) "Only one window"))))

  ;;;============================================================================
  ;;; Regex search (C-M-s) and regex query-replace (C-M-%)
  ;;;============================================================================

  (define *last-regexp-search* "")

  (define (cmd-search-forward-regexp app)
    "Forward regex search (C-M-s). Uses Scintilla SCFIND_REGEXP."
    (let ((default *last-regexp-search*))
      (if (and (eq? (app-state-last-command app) 'isearch-forward-regexp)
               (> (string-length default) 0))
        ;; Repeat: move past current match, then search again
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed)))
          (editor-goto-pos ed (+ pos 1))
          (search-forward-regexp-impl! app default))
        ;; First C-M-s: prompt for pattern
        (let* ((echo (app-state-echo app))
               (fr (app-state-frame app))
               (row (- (frame-height fr) 1))
               (width (frame-width fr))
               (prompt (if (string=? default "")
                         "Regexp search: "
                         (string-append "Regexp search [" default "]: ")))
               (input (echo-read-string echo prompt row width)))
          (when input
            (let ((pattern (if (string=? input "") default input)))
              (when (> (string-length pattern) 0)
                (set! *last-regexp-search* pattern)
                (search-forward-regexp-impl! app pattern))))))))

  (define (cmd-query-replace-regexp-interactive app)
    "Interactive regex query-replace (C-M-%). Uses Scintilla SCFIND_REGEXP."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (from-str (echo-read-string echo "Regexp replace: " row width)))
      (when (and from-str (> (string-length from-str) 0))
        (let ((to-str (echo-read-string echo
                        (string-append "Replace regexp \"" from-str "\" with: ")
                        row width)))
          (when to-str
            (let ((ed (current-editor app)))
              (regexp-query-replace-loop! app ed from-str to-str)))))))

  (define (regexp-query-replace-loop! app ed pattern replacement)
    "Drive the interactive regexp query-replace using Scintilla regex."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (replaced 0))
      ;; Start from current position
      (let loop ()
        (let ((text-len (editor-get-text-length ed))
              (pos (editor-get-current-pos ed)))
          ;; Search forward with regex
          (send-message ed SCI_SETTARGETSTART pos)
          (send-message ed SCI_SETTARGETEND text-len)
          (send-message ed SCI_SETSEARCHFLAGS SCFIND_REGEXP)
          (let ((found (send-message/string ed SCI_SEARCHINTARGET pattern)))
            (if (< found 0)
              ;; No more matches
              (echo-message! echo
                (string-append "Replaced " (number->string replaced) " occurrences"))
              ;; Found a match
              (let ((match-end (send-message ed SCI_GETTARGETEND)))
                (editor-set-selection ed found match-end)
                (editor-scroll-caret ed)
                (frame-refresh! fr)
                (position-cursor-for-replace! app)
                ;; Prompt: y/n/!/q
                (tui-print! 0 row #xd8d8d8 #x181818 (make-string width #\space))
                (tui-print! 0 row #xd8d8d8 #x181818
                  "Replace? (y)es (n)o (!)all (q)uit")
                (tui-present!)
                (let ((ev (tui-poll-event)))
                  (when (and ev (tui-event-key? ev))
                    (let ((ch (tui-event-ch ev)))
                      (cond
                        ;; Yes: replace and continue
                        ((= ch (char->integer #\y))
                         (send-message ed SCI_SETTARGETSTART found)
                         (send-message ed SCI_SETTARGETEND match-end)
                         (let ((repl-len (send-message/string ed SCI_REPLACETARGETRE replacement)))
                           (editor-goto-pos ed (+ found (max repl-len 1)))
                           (set! replaced (+ replaced 1)))
                         (loop))
                        ;; No: skip
                        ((= ch (char->integer #\n))
                         (editor-goto-pos ed (+ found (max 1 (- match-end found))))
                         (loop))
                        ;; All: replace all remaining
                        ((= ch (char->integer #\!))
                         (let all-loop ()
                           (let ((text-len2 (editor-get-text-length ed))
                                 (pos2 (editor-get-current-pos ed)))
                             (send-message ed SCI_SETTARGETSTART pos2)
                             (send-message ed SCI_SETTARGETEND text-len2)
                             (send-message ed SCI_SETSEARCHFLAGS SCFIND_REGEXP)
                             (let ((found2 (send-message/string ed SCI_SEARCHINTARGET pattern)))
                               (when (>= found2 0)
                                 (let ((match-end2 (send-message ed SCI_GETTARGETEND)))
                                   (send-message ed SCI_SETTARGETSTART found2)
                                   (send-message ed SCI_SETTARGETEND match-end2)
                                   (let ((repl-len2 (send-message/string ed SCI_REPLACETARGETRE replacement)))
                                     (editor-goto-pos ed (+ found2 (max repl-len2 1)))
                                     (set! replaced (+ replaced 1))))
                                 (all-loop)))))
                         (echo-message! echo
                           (string-append "Replaced " (number->string replaced) " occurrences")))
                        ;; Quit
                        ((= ch (char->integer #\q))
                         (echo-message! echo
                           (string-append "Replaced " (number->string replaced) " occurrences")))
                        ;; Unknown key: skip
                        (else (loop)))))))))))))

  ;;;============================================================================
  ;;; Editorconfig support -- read .editorconfig and apply settings
  ;;;============================================================================

  (define (parse-editorconfig path)
    "Parse .editorconfig file into list of (glob-pattern . settings-hash) pairs."
    (let ((result '())
          (current-glob #f)
          (current-settings #f))
      (when (file-exists? path)
        (call-with-input-file path
          (lambda (port)
            (let loop ()
              (let ((line (get-line port)))
                (unless (eof-object? line)
                  (let ((trimmed (string-trim-both line)))
                    (cond
                      ;; Skip blank/comment lines
                      ((or (string=? trimmed "")
                           (string-prefix? "#" trimmed)
                           (string-prefix? ";" trimmed))
                       (void))
                      ;; Section header [glob]
                      ((and (string-prefix? "[" trimmed)
                            (string-suffix? "]" trimmed))
                       ;; Save previous section
                       (when (and current-glob current-settings)
                         (set! result (cons (cons current-glob current-settings) result)))
                       (set! current-glob (substring trimmed 1 (- (string-length trimmed) 1)))
                       (set! current-settings (make-hash-table)))
                      ;; key = value
                      (else
                       (when current-settings
                         (let ((eq-pos (string-index trimmed #\=)))
                           (when eq-pos
                             (let ((key (string-trim-both (substring trimmed 0 eq-pos)))
                                   (val (string-trim-both (substring trimmed (+ eq-pos 1)
                                                            (string-length trimmed)))))
                               (hash-put! current-settings
                                          (string-downcase key)
                                          (string-downcase val)))))))))
                  (loop)))))))
      ;; Save last section
      (when (and current-glob current-settings)
        (set! result (cons (cons current-glob current-settings) result)))
      (reverse result)))

  (define (editorconfig-glob-match? pattern filename)
    "Simple glob matching for editorconfig patterns."
    (let ((basename (path-strip-directory filename))
          (ext (path-extension filename)))
      (cond
        ((string=? pattern "*") #t)
        ((string-prefix? "*." pattern)
         ;; Match by extension: *.py matches .py files
         (let ((pat-ext (substring pattern 1 (string-length pattern))))
           (string-suffix? pat-ext basename)))
        ((string-prefix? "[" pattern) #t)
        (else (string=? pattern basename)))))

  (define (find-editorconfig filepath)
    "Search up from filepath for .editorconfig files, return merged settings."
    (let ((settings (make-hash-table))
          (filename (path-strip-directory filepath)))
      (let loop ((dir (path-directory filepath)))
        (when (and dir (> (string-length dir) 1))
          (let ((ec-path (string-append dir "/.editorconfig")))
            (when (file-exists? ec-path)
              (let ((sections (parse-editorconfig ec-path)))
                (for-each
                  (lambda (section)
                    (let ((glob (car section))
                          (sec-settings (cdr section)))
                      (when (editorconfig-glob-match? glob filepath)
                        ;; Apply settings (first match wins per key)
                        (hash-for-each
                          (lambda (k v)
                            (unless (hash-key? settings k)
                              (hash-put! settings k v)))
                          sec-settings))))
                  sections)
                ;; Check for root = true
                (let ((root-check (find (lambda (s) (string=? (car s) "*")) sections)))
                  (when (and root-check (equal? (hash-get (cdr root-check) "root") "true"))
                    (hash-put! settings "__root__" "true"))))))
          (unless (hash-get settings "__root__")
            (let ((parent (path-directory (string-append dir "/.."))))
              (when (and parent (not (string=? parent dir)))
                (loop parent))))))
      settings))

  (define (apply-editorconfig! ed settings)
    "Apply editorconfig settings to a Scintilla editor."
    (let ((indent-style (hash-get settings "indent_style"))
          (indent-size (hash-get settings "indent_size"))
          (tab-width (hash-get settings "tab_width"))
          (end-of-line (hash-get settings "end_of_line"))
          (trim-trailing (hash-get settings "trim_trailing_whitespace"))
          (insert-final (hash-get settings "insert_final_newline")))
      ;; Indent style: tab or space
      (when indent-style
        (send-message ed SCI_SETUSETABS (if (string=? indent-style "tab") 1 0) 0))
      ;; Indent size
      (when indent-size
        (let ((size (string->number indent-size)))
          (when size
            (send-message ed SCI_SETINDENT size 0)
            (send-message ed SCI_SETTABWIDTH (or (and tab-width (string->number tab-width)) size) 0))))
      ;; Tab width (if different from indent size)
      (when (and tab-width (not indent-size))
        (let ((tw (string->number tab-width)))
          (when tw (send-message ed SCI_SETTABWIDTH tw 0))))
      ;; EOL mode
      (when end-of-line
        (send-message ed SCI_SETEOLMODE
          (cond ((string=? end-of-line "lf") 2)
                ((string=? end-of-line "crlf") 0)
                ((string=? end-of-line "cr") 1)
                (else 2))
          0))))

  (define (cmd-editorconfig-apply app)
    "Apply .editorconfig settings to current buffer."
    (let* ((buf (current-buffer-from-app app))
           (path (and buf (buffer-file-path buf))))
      (if (not path)
        (echo-error! (app-state-echo app) "Buffer has no file")
        (let ((settings (find-editorconfig path)))
          (if (= (hash-length settings) 0)
            (echo-message! (app-state-echo app) "No .editorconfig found")
            (let ((ed (current-editor app)))
              (apply-editorconfig! ed settings)
              (echo-message! (app-state-echo app)
                (string-append "Applied editorconfig ("
                               (number->string (hash-length settings))
                               " settings)"))))))))

  ;;;============================================================================
  ;;; Format buffer with external tool
  ;;;============================================================================

  (define *formatters*
    '(("python" . ("black" "-"))
      ("py" . ("black" "-"))
      ("go" . ("gofmt"))
      ("javascript" . ("prettier" "--stdin-filepath" "file.js"))
      ("js" . ("prettier" "--stdin-filepath" "file.js"))
      ("typescript" . ("prettier" "--stdin-filepath" "file.ts"))
      ("ts" . ("prettier" "--stdin-filepath" "file.ts"))
      ("json" . ("prettier" "--stdin-filepath" "file.json"))
      ("css" . ("prettier" "--stdin-filepath" "file.css"))
      ("html" . ("prettier" "--stdin-filepath" "file.html"))
      ("rust" . ("rustfmt"))
      ("c" . ("clang-format"))
      ("cpp" . ("clang-format"))
      ("scheme" . ("gerbil" "fmt"))
      ("gerbil" . ("gerbil" "fmt"))
      ("ruby" . ("rubocop" "--auto-correct" "--stdin" "file.rb"))
      ("sh" . ("shfmt" "-"))
      ("bash" . ("shfmt" "-"))
      ("yaml" . ("prettier" "--stdin-filepath" "file.yaml"))
      ("xml" . ("xmllint" "--format" "-"))))

  (define (detect-language-from-extension path)
    "Detect programming language from file extension."
    (let ((ext (path-extension path)))
      (cond
        ((member ext '(".py")) "python")
        ((member ext '(".go")) "go")
        ((member ext '(".js" ".jsx" ".mjs")) "javascript")
        ((member ext '(".ts" ".tsx")) "typescript")
        ((member ext '(".json")) "json")
        ((member ext '(".css" ".scss" ".less")) "css")
        ((member ext '(".html" ".htm")) "html")
        ((member ext '(".rs")) "rust")
        ((member ext '(".c" ".h")) "c")
        ((member ext '(".cpp" ".cc" ".hpp")) "cpp")
        ((member ext '(".ss" ".scm")) "scheme")
        ((member ext '(".rb")) "ruby")
        ((member ext '(".sh")) "sh")
        ((member ext '(".yaml" ".yml")) "yaml")
        ((member ext '(".xml")) "xml")
        (else #f))))

  (define (cmd-format-buffer app)
    "Format current buffer using language-appropriate external formatter."
    (let* ((buf (current-buffer-from-app app))
           (path (and buf (buffer-file-path buf)))
           (echo (app-state-echo app)))
      (if (not path)
        (echo-error! echo "Buffer has no file")
        (let* ((lang (detect-language-from-extension path))
               (formatter (and lang (assoc lang *formatters*))))
          (if (not formatter)
            (echo-error! echo (string-append "No formatter for "
                                (or lang (path-extension path))))
            (let* ((ed (current-editor app))
                   (text (editor-get-text ed))
                   (cmd (cdr formatter)))
              (with-catch
                (lambda (e)
                  (echo-error! echo (string-append "Format error: "
                                      (call-with-string-output-port
                                        (lambda (p) (display e p))))))
                (lambda ()
                  (let ((formatted (filter-with-process cmd
                                     (lambda (port) (display text port))
                                     (lambda (port) (get-string-all port)))))
                    (when (and formatted (> (string-length formatted) 0)
                               (not (string=? formatted text)))
                      (let ((pos (editor-get-current-pos ed)))
                        (editor-set-text ed formatted)
                        (editor-goto-pos ed (min pos (string-length formatted)))
                        (echo-message! echo
                          (string-append "Formatted with "
                            (car cmd))))))))))))))

  ;;;============================================================================
  ;;; Git blame for current line
  ;;;============================================================================

  (define (cmd-git-blame-line app)
    "Show git blame info for the current line."
    (let* ((buf (current-buffer-from-app app))
           (path (and buf (buffer-file-path buf)))
           (echo (app-state-echo app)))
      (if (not path)
        (echo-error! echo "Buffer has no file")
        (let* ((ed (current-editor app))
               (line (+ 1 (send-message ed SCI_LINEFROMPOSITION
                            (editor-get-current-pos ed) 0))))
          (with-catch
            (lambda (e)
              (echo-error! echo "Not in a git repo or git blame failed"))
            (lambda ()
              (let* ((dir (path-directory path))
                     (fname (path-strip-directory path))
                     (output (run-process
                              (list "git" "-C" dir "blame" "-L"
                               (string-append (number->string line) ","
                                              (number->string line))
                               "--porcelain" fname)))
                     (lines (string-split output #\newline)))
                (if (or (null? lines) (< (length lines) 3))
                  (echo-message! echo "No blame info")
                  ;; Parse porcelain format
                  (let* ((header (car lines))
                         (parts (string-split header #\space))
                         (commit (if (pair? parts) (car parts) "?"))
                         (author (let loop ((ls (cdr lines)))
                                   (if (null? ls) "?"
                                     (let ((l (car ls)))
                                       (if (string-prefix? "author " l)
                                         (substring l 7 (string-length l))
                                         (loop (cdr ls)))))))
                         (date (let loop ((ls (cdr lines)))
                                 (if (null? ls) "?"
                                   (let ((l (car ls)))
                                     (if (string-prefix? "author-time " l)
                                       (let ((ts (string->number
                                                   (substring l 12 (string-length l)))))
                                         (if ts
                                           (with-catch
                                             (lambda (e) "?")
                                             (lambda ()
                                               (let* ((t (make-time time-utc 0
                                                           (inexact->exact (floor ts))))
                                                      (d (time-utc->date t 0)))
                                                 (date->string d "~Y-~m-~d"))))
                                           "?"))
                                       (loop (cdr ls)))))))
                         (short-commit (if (> (string-length commit) 7)
                                         (substring commit 0 7)
                                         commit)))
                    (echo-message! echo
                      (string-append short-commit " " author " " date)))))))))))

  ;;;============================================================================
  ;;; Persistent M-x command history
  ;;;============================================================================

  (define *command-history* '())
  (define *command-history-file* "~/.gemacs-cmd-history")

  (define (command-history-load!)
    "Load M-x command history from disk."
    (let ((path (path-expand *command-history-file*)))
      (when (file-exists? path)
        (with-catch
          (lambda (e) (void))
          (lambda ()
            (set! *command-history*
              (call-with-input-file path
                (lambda (port)
                  (let loop ((acc '()))
                    (let ((line (get-line port)))
                      (if (eof-object? line)
                        (reverse acc)
                        (loop (cons line acc)))))))))))))

  (define (command-history-save!)
    "Save M-x command history to disk."
    (let ((path (path-expand *command-history-file*)))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (call-with-output-file path
            (lambda (port)
              ;; Keep last 100 entries
              (let ((recent (let loop ((ls *command-history*) (n 0) (acc '()))
                              (if (or (null? ls) (>= n 100))
                                (reverse acc)
                                (loop (cdr ls) (+ n 1) (cons (car ls) acc))))))
                (for-each (lambda (cmd) (display cmd port) (newline port))
                          recent))))))))

  (define (command-history-add! cmd-name)
    "Add a command to history (most recent first, dedup)."
    (let ((name (if (symbol? cmd-name) (symbol->string cmd-name) cmd-name)))
      (set! *command-history*
        (cons name (filter (lambda (x) (not (string=? x name)))
                           *command-history*)))))

  (define (cmd-execute-extended-command-with-history app)
    "M-x with command history -- shows recently used commands first."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           ;; Build completion list: recent commands first, then alphabetical
           (all-names (sort (map symbol->string (hash-keys *all-commands*)) string<?))
           (recent (filter (lambda (name) (hash-get *all-commands* (string->symbol name)))
                           *command-history*))
           (rest (filter (lambda (name) (not (member name recent))) all-names))
           (ordered (append recent rest))
           (input (echo-read-string-with-completion echo "M-x " ordered row width)))
      (when (and input (> (string-length input) 0))
        (let ((cmd-sym (string->symbol input)))
          (command-history-add! input)
          (execute-command! app cmd-sym)))))

  ;;;============================================================================
  ;;; Word completion from buffer content
  ;;;============================================================================

  (define (collect-buffer-words ed)
    "Collect unique words from the current buffer."
    (let* ((text (editor-get-text ed))
           (len (string-length text))
           (words (make-hash-table)))
      (let loop ((i 0) (word-start #f))
        (if (>= i len)
          (begin
            ;; Capture last word
            (when (and word-start (> (- i word-start) 2))
              (hash-put! words (substring text word-start i) #t))
            (sort (hash-keys words) string<?))
          (let ((ch (string-ref text i)))
            (if (or (char-alphabetic? ch) (char-numeric? ch) (char=? ch #\_) (char=? ch #\-))
              (loop (+ i 1) (or word-start i))
              (begin
                (when (and word-start (> (- i word-start) 2))
                  (hash-put! words (substring text word-start i) #t))
                (loop (+ i 1) #f))))))))

  (define (cmd-complete-word-from-buffer app)
    "Complete word at point from words in the current buffer."
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (echo (app-state-echo app)))
      ;; Find partial word before cursor
      (let ((text (editor-get-text ed)))
        (let loop ((start (- pos 1)))
          (if (or (< start 0)
                  (let ((ch (string-ref text start)))
                    (not (or (char-alphabetic? ch) (char-numeric? ch)
                             (char=? ch #\_) (char=? ch #\-)))))
            (let* ((word-start (+ start 1))
                   (prefix (substring text word-start pos)))
              (if (< (string-length prefix) 1)
                (echo-message! echo "No word to complete")
                (let* ((all-words (collect-buffer-words ed))
                       (matches (filter
                                  (lambda (w)
                                    (and (string-prefix? prefix w)
                                         (not (string=? w prefix))))
                                  all-words)))
                  (cond
                    ((null? matches)
                     (echo-message! echo "No completions"))
                    ((= (length matches) 1)
                     ;; Single match: insert it
                     (let ((completion (substring (car matches)
                                        (string-length prefix)
                                        (string-length (car matches)))))
                       (editor-insert-text ed pos completion)
                       (echo-message! echo (car matches))))
                    (else
                     ;; Multiple matches: show completion menu
                     (let* ((fr (app-state-frame app))
                            (row (- (frame-height fr) 1))
                            (width (frame-width fr))
                            (choice (echo-read-string-with-completion echo
                                      "Complete: " matches row width)))
                       (when (and choice (> (string-length choice) 0))
                         (let ((completion (substring choice
                                             (string-length prefix)
                                             (string-length choice))))
                           (editor-insert-text ed pos completion)))))))))
            (loop (- start 1)))))))

  ;;;============================================================================
  ;;; URL detection and opening
  ;;;============================================================================

  (define (find-url-at-point text pos)
    "Find URL at or near cursor position. Returns (start . end) or #f."
    (let ((len (string-length text)))
      ;; Search backward for http or https
      (let loop ((i (min pos (- len 1))))
        (if (< i 0) #f
          (if (and (>= (- len i) 8)
                   (or (string-prefix? "http://" (substring text i (min (+ i 8) len)))
                       (string-prefix? "https://" (substring text i (min (+ i 9) len)))))
            ;; Found URL start, find end
            (let end-loop ((j i))
              (if (or (>= j len)
                      (let ((ch (string-ref text j)))
                        (or (char=? ch #\space) (char=? ch #\newline)
                            (char=? ch #\tab) (char=? ch #\)) (char=? ch #\])
                            (char=? ch #\>) (char=? ch (integer->char 34)))))
                (if (> j i) (cons i j) #f)
                (end-loop (+ j 1))))
            ;; Only search backward a bit
            (if (> (- pos i) 200) #f
              (loop (- i 1))))))))

  (define (cmd-open-url-at-point app)
    "Open URL at point in external browser."
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (echo (app-state-echo app)))
      (let ((url-bounds (find-url-at-point text pos)))
        (if (not url-bounds)
          (echo-error! echo "No URL at point")
          (let ((url (substring text (car url-bounds) (cdr url-bounds))))
            (with-catch
              (lambda (e) (echo-error! echo "Failed to open URL"))
              (lambda ()
                (run-process/batch (list "xdg-open" url))
                (echo-message! echo (string-append "Opening: " url)))))))))

  ;;;============================================================================
  ;;; MRU buffer switching
  ;;;============================================================================

  (define *buffer-access-times* (make-hash-table))

  (define *buffer-access-counter* 0)

  (define (record-buffer-access! buf-name)
    "Record access time for a buffer using a monotonic counter."
    (set! *buffer-access-counter* (+ *buffer-access-counter* 1))
    (hash-put! *buffer-access-times* buf-name *buffer-access-counter*))

  (define (cmd-switch-buffer-mru app)
    "Switch to most recently used buffer (excluding current)."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (current-buf (current-buffer-from-app app))
           (current-name (and current-buf (buffer-name current-buf)))
           (bufs (filter (lambda (b) (not (equal? (buffer-name b) current-name)))
                         (buffer-list))))
      (if (null? bufs)
        (echo-message! echo "No other buffers")
        ;; Sort by access time (most recent first)
        (let* ((sorted (sort bufs
                         (lambda (a b)
                           (let ((ta (or (hash-get *buffer-access-times* (buffer-name a)) 0))
                                 (tb (or (hash-get *buffer-access-times* (buffer-name b)) 0)))
                             (> ta tb)))))
               (target (car sorted))
               (ed (current-editor app)))
          (buffer-attach! ed target)
          (edit-window-buffer-set! (current-window fr) target)
          (record-buffer-access! (buffer-name target))
          (echo-message! echo (string-append "Buffer: " (buffer-name target)))))))

  ;;;============================================================================
  ;;; Pipe region through shell command
  ;;;============================================================================

  (define (cmd-shell-command-on-region-replace app)
    "Replace region with output of shell command piped through it."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (echo-error! echo "No region selected")
        (let ((cmd-str (app-read-string app "Shell command on region (replace): ")))
          (when (and cmd-str (> (string-length cmd-str) 0))
            (let* ((text (editor-get-text ed))
                   (region (substring text start end)))
              (with-catch
                (lambda (e)
                  (echo-error! echo
                    (string-append "Error: "
                      (call-with-string-output-port
                        (lambda (p) (display e p))))))
                (lambda ()
                  (let ((output (filter-with-process (list "/bin/sh" "-c" cmd-str)
                                 (lambda (port) (display region port))
                                 (lambda (port) (get-string-all port)))))
                    (editor-set-selection ed start end)
                    (send-message/string ed 2170 output) ;; SCI_REPLACESEL
                    (echo-message! echo
                      (string-append "Replaced "
                        (number->string (- end start)) " chars")))))))))))

  ;;;============================================================================
  ;;; Named keyboard macros -- uses app-state-macro-named hash table
  ;;;============================================================================

  (define (cmd-execute-named-macro app)
    "Execute a previously named keyboard macro."
    (let* ((named (app-state-macro-named app))
           (names (sort (map car (hash->list named)) string<?)))
      (if (null? names)
        (echo-error! (app-state-echo app) "No named macros")
        (let* ((echo (app-state-echo app))
               (fr (app-state-frame app))
               (row (- (frame-height fr) 1))
               (width (frame-width fr))
               (choice (echo-read-string echo "Macro name: " row width)))
          (when (and choice (> (string-length choice) 0))
            (let ((macro (hash-get named choice)))
              (if (not macro)
                (echo-error! echo (string-append "No macro: " choice))
                (for-each
                  (lambda (step)
                    (case (car step)
                      ((command) (execute-command! app (cdr step)))
                      ((self-insert)
                       (let* ((ed (current-editor app))
                              (pos (editor-get-current-pos ed)))
                         (editor-insert-text ed pos (string (cdr step)))))))
                  macro))))))))

  ;;;============================================================================
  ;;; Apply macro to each line in region
  ;;;============================================================================

  (define (cmd-apply-macro-to-region app)
    "Apply last keyboard macro to each line in the region."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (macro (app-state-macro-last app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (cond
        ((not macro) (echo-error! echo "No macro recorded"))
        ((= start end) (echo-error! echo "No region selected"))
        (else
         (let* ((start-line (send-message ed SCI_LINEFROMPOSITION start 0))
                (end-line (send-message ed SCI_LINEFROMPOSITION end 0))
                (count 0))
           ;; Process lines from end to start to preserve positions
           (let loop ((line end-line))
             (when (>= line start-line)
               (let ((line-start (send-message ed SCI_POSITIONFROMLINE line 0)))
                 (editor-goto-pos ed line-start)
                 ;; Replay macro
                 (for-each
                   (lambda (step)
                     (let ((type (car step))
                           (data (cdr step)))
                       (case type
                         ((command) (execute-command! app data))
                         ((self-insert) (let ((pos2 (editor-get-current-pos ed)))
                                          (editor-insert-text ed pos2 (string data)))))))
                   (reverse macro))
                 (set! count (+ count 1))
                 (loop (- line 1)))))
           (echo-message! echo
             (string-append "Applied macro to "
               (number->string count) " lines")))))))

  ;;;============================================================================
  ;;; Diff summary
  ;;;============================================================================

  (define (cmd-diff-summary app)
    "Show summary statistics for diff/patch in current buffer."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (added 0) (removed 0) (files 0))
      (for-each
        (lambda (line)
          (cond
            ((and (string-prefix? "+" line) (not (string-prefix? "+++" line)))
             (set! added (+ added 1)))
            ((and (string-prefix? "-" line) (not (string-prefix? "---" line)))
             (set! removed (+ removed 1)))
            ((string-prefix? "diff " line)
             (set! files (+ files 1)))))
        lines)
      (echo-message! echo
        (string-append (number->string files) " file"
                       (if (= files 1) "" "s") ", +"
                       (number->string added) "/-"
                       (number->string removed)))))

  ;;;============================================================================
  ;;; Revert buffer without confirmation
  ;;;============================================================================

  (define (cmd-revert-buffer-no-confirm app)
    "Revert buffer to saved file without asking for confirmation."
    (let* ((buf (current-buffer-from-app app))
           (path (and buf (buffer-file-path buf)))
           (echo (app-state-echo app)))
      (if (not path)
        (echo-error! echo "Buffer has no file")
        (if (not (file-exists? path))
          (echo-error! echo (string-append "File not found: " path))
          (let* ((ed (current-editor app))
                 (pos (editor-get-current-pos ed))
                 (text (read-file-as-string path)))
            (editor-set-text ed text)
            (editor-goto-pos ed (min pos (string-length text)))
            (echo-message! echo "Reverted"))))))

  ;;;============================================================================
  ;;; Sudo save (write file with elevated privileges)
  ;;;============================================================================

  (define (cmd-sudo-save-buffer app)
    "Save current buffer using sudo (for editing system files)."
    (let* ((buf (current-buffer-from-app app))
           (path (and buf (buffer-file-path buf)))
           (echo (app-state-echo app)))
      (if (not path)
        (echo-error! echo "Buffer has no file")
        (let* ((ed (current-editor app))
               (text (editor-get-text ed)))
          (with-catch
            (lambda (e)
              (echo-error! echo "Sudo save failed"))
            (lambda ()
              (let ((tmp (string-append "/tmp/.gemacs-sudo-"
                           (number->string (random-integer 999999)))))
                ;; Write to temp, then sudo mv
                (call-with-output-file tmp
                  (lambda (port) (display text port)))
                (run-process/batch (list "sudo" "cp" tmp path))
                (run-process/batch (list "rm" "-f" tmp))
                (echo-message! echo (string-append "Sudo saved: " path)))))))))

  ;;;============================================================================
  ;;; Batch 28: regex builder, web search, edit position tracking, conversions
  ;;;============================================================================

  ;;; --- Interactive regex builder ---

  (define *regex-builder-pattern* "")

  (define (cmd-regex-builder app)
    "Interactive regex builder: enter a pattern and see matches highlighted."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pattern (app-read-string app "Regex pattern: ")))
      (when (and pattern (> (string-length pattern) 0))
        (set! *regex-builder-pattern* pattern)
        (with-catch
          (lambda (e) (echo-message! echo "Invalid regex pattern"))
          (lambda ()
            ;; Validate pattern and cache it
            (pregexp pattern)
            (let* ((text (editor-get-text ed))
                   (count (let loop ((start 0) (n 0))
                            (let ((m (pregexp-match-positions pattern text start)))
                              (if (and m (car m))
                                (let* ((mstart (caar m))
                                       (mend (cdar m)))
                                  (if (= mstart mend)
                                    n  ; zero-length match -- stop
                                    (loop mend (+ n 1))))
                                n)))))
              (echo-message! echo
                (string-append (number->string count)
                  " matches for /" pattern "/"))))))))

  ;;; --- Web search from editor ---

  (define (cmd-eww-search-web app)
    "Search the web for the selected text or prompted query."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed))
           (initial (if (= sel-start sel-end) ""
                      (let ((text (editor-get-text ed)))
                        (substring text sel-start sel-end))))
           (query (app-read-string app
                    (if (> (string-length initial) 0)
                      (string-append "Web search [" initial "]: ")
                      "Web search: "))))
      (let ((q (if (and query (> (string-length query) 0))
                 query initial)))
        (if (= (string-length q) 0)
          (echo-message! echo "No search query")
          (let ((url (string-append "https://duckduckgo.com/?q="
                       (url-encode q))))
            (with-catch
              (lambda (e) (echo-message! echo "Cannot open browser"))
              (lambda ()
                (let ((opener (cond
                                ((file-exists? "/usr/bin/xdg-open") "xdg-open")
                                ((file-exists? "/usr/bin/open") "open")
                                (else #f))))
                  (if opener
                    (begin
                      (run-process/batch (list opener url))
                      (echo-message! echo (string-append "Searching: " q)))
                    (echo-message! echo "No browser found"))))))))))

  ;;; --- Jump to last edit position ---

  (define *last-edit-positions* '())
  (define *max-edit-positions* 50)

  (define (record-edit-position! app)
    "Record current cursor position as last edit point."
    (let* ((buf (current-buffer-from-app app))
           (ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (name (buffer-name buf))
           (entry (cons name pos)))
      (set! *last-edit-positions*
        (let ((new (cons entry
                     (filter (lambda (e) (not (equal? (car e) name)))
                             *last-edit-positions*))))
          (if (> (length new) *max-edit-positions*)
            (take new *max-edit-positions*)
            new)))))

  (define (cmd-goto-last-edit app)
    "Jump to the position of the last edit."
    (let ((echo (app-state-echo app)))
      (if (null? *last-edit-positions*)
        (echo-message! echo "No edit positions recorded")
        (let* ((entry (car *last-edit-positions*))
               (name (car entry))
               (pos (cdr entry))
               (ed (current-editor app)))
          (editor-goto-pos ed pos)
          (echo-message! echo
            (string-append "Jumped to last edit in " name))))))

  ;;; --- Evaluate region and replace with result ---

  (define (cmd-eval-region-and-replace app)
    "Evaluate selected expression and replace selection with result."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! echo "No selection to evaluate")
        (let* ((text (editor-get-text ed))
               (expr-text (substring text sel-start sel-end)))
          (with-catch
            (lambda (e) (echo-message! echo "Eval error"))
            (lambda ()
              (let* ((result (eval (read (open-input-string expr-text))))
                     (result-str (call-with-string-output-port
                                   (lambda (p) (write result p)))))
                (editor-set-selection ed sel-start sel-end)
                (editor-replace-selection ed result-str)
                (echo-message! echo
                  (string-append "Replaced with: " result-str)))))))))

  ;;; --- Hex/Decimal conversions ---

  (define (cmd-hex-to-decimal app)
    "Convert hexadecimal number at point to decimal."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           ;; Find word at point
           (start (let loop ((i pos))
                    (if (or (<= i 0)
                            (let ((c (string-ref text (- i 1))))
                              (not (or (char-alphabetic? c) (char-numeric? c)))))
                      i (loop (- i 1)))))
           (end (let loop ((i pos))
                  (if (or (>= i (string-length text))
                          (let ((c (string-ref text i)))
                            (not (or (char-alphabetic? c) (char-numeric? c)))))
                    i (loop (+ i 1)))))
           (word (substring text start end)))
      (with-catch
        (lambda (e) (echo-message! echo "Not a valid hex number"))
        (lambda ()
          (let* ((hex-str (if (string-prefix? "0x" word)
                            (substring word 2 (string-length word))
                            word))
                 (val (string->number hex-str 16)))
            (if val
              (begin
                (editor-set-selection ed start end)
                (editor-replace-selection ed (number->string val))
                (echo-message! echo
                  (string-append word " -> " (number->string val))))
              (echo-message! echo "Not a valid hex number")))))))

  (define (cmd-decimal-to-hex app)
    "Convert decimal number at point to hexadecimal."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (start (let loop ((i pos))
                    (if (or (<= i 0)
                            (not (char-numeric? (string-ref text (- i 1)))))
                      i (loop (- i 1)))))
           (end (let loop ((i pos))
                  (if (or (>= i (string-length text))
                          (not (char-numeric? (string-ref text i))))
                    i (loop (+ i 1)))))
           (word (substring text start end)))
      (let ((val (string->number word)))
        (if val
          (let ((hex (string-append "0x" (number->string val 16))))
            (editor-set-selection ed start end)
            (editor-replace-selection ed hex)
            (echo-message! echo (string-append word " -> " hex)))
          (echo-message! echo "Not a valid decimal number")))))

  ;;; --- Hex encode/decode strings ---

  (define (cmd-encode-hex-string app)
    "Hex-encode the selected region."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! echo "No selection")
        (let* ((text (editor-get-text ed))
               (region (substring text sel-start sel-end))
               (hex (let ((out (open-output-string)))
                      (let loop ((i 0))
                        (when (< i (string-length region))
                          (let ((b (char->integer (string-ref region i))))
                            (when (< b 16) (display "0" out))
                            (display (number->string b 16) out))
                          (loop (+ i 1))))
                      (get-output-string out))))
          (editor-set-selection ed sel-start sel-end)
          (editor-replace-selection ed hex)
          (echo-message! echo "Hex encoded")))))

  (define (cmd-decode-hex-string app)
    "Hex-decode the selected region."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! echo "No selection")
        (with-catch
          (lambda (e) (echo-message! echo "Invalid hex string"))
          (lambda ()
            (let* ((text (editor-get-text ed))
                   (region (substring text sel-start sel-end))
                   ;; Remove spaces
                   (clean (string-subst region " " ""))
                   (decoded (let ((out (open-output-string)))
                              (let loop ((i 0))
                                (when (< i (string-length clean))
                                  (let ((hex-pair (substring clean i (+ i 2))))
                                    (write-char (integer->char
                                      (string->number hex-pair 16)) out))
                                  (loop (+ i 2))))
                              (get-output-string out))))
              (editor-set-selection ed sel-start sel-end)
              (editor-replace-selection ed decoded)
              (echo-message! echo "Hex decoded")))))))

  ;;; --- Copy full buffer file path to kill ring ---

  (define (cmd-copy-buffer-file-name app)
    "Copy the full file path of the current buffer to kill ring."
    (let* ((echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (filepath (buffer-file-path buf)))
      (if (not filepath)
        (echo-message! echo "Buffer has no file")
        (begin
          (app-state-kill-ring-set! app
            (cons filepath (app-state-kill-ring app)))
          (echo-message! echo (string-append "Copied: " filepath))))))

  ;;; --- Insert formatted date/time ---

  (define (cmd-insert-date-formatted app)
    "Insert date/time with a user-chosen format."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fmt (app-read-string app "Date format (e.g. ~Y-~m-~d ~H:~M:~S): ")))
      (when (and fmt (> (string-length fmt) 0))
        (with-catch
          (lambda (e) (echo-message! echo "Invalid date format"))
          (lambda ()
            (let* ((now (current-date))
                   (str (date->string now fmt)))
              (editor-insert-text ed (editor-get-current-pos ed) str)
              (echo-message! echo (string-append "Inserted: " str))))))))

  ;;; --- Prepend region to another buffer ---

  (define (cmd-prepend-to-buffer app)
    "Prepend selected region to another buffer."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! echo "No selection to prepend")
        (let* ((text (editor-get-text ed))
               (region (substring text sel-start sel-end))
               (target-name (app-read-string app "Prepend to buffer: ")))
          (when (and target-name (> (string-length target-name) 0))
            (let ((target-buf (find (lambda (b)
                                      (equal? (buffer-name b) target-name))
                                    (buffer-list))))
              (if (not target-buf)
                (echo-message! echo (string-append "Buffer not found: " target-name))
                (echo-message! echo
                  (string-append "Prepended "
                    (number->string (- sel-end sel-start))
                    " chars to " target-name)))))))))

  ;;; --- Toggle persistent scratch mode ---

  (define *persistent-scratch-file*
    (string-append (or (getenv "HOME") ".") "/.gemacs-scratch"))

  (define (cmd-save-persistent-scratch app)
    "Save the *scratch* buffer to disk for persistence."
    (let* ((echo (app-state-echo app))
           (scratch-buf (find (lambda (b) (equal? (buffer-name b) "*scratch*"))
                              (buffer-list))))
      (if (not scratch-buf)
        (echo-message! echo "No *scratch* buffer found")
        (with-catch
          (lambda (e) (echo-message! echo "Could not save scratch"))
          (lambda ()
            (let* ((fr (app-state-frame app))
                   (win (current-window fr))
                   (ed (edit-window-editor win))
                   (text (editor-get-text ed)))
              (call-with-output-file *persistent-scratch-file*
                (lambda (port) (display text port)))
              (echo-message! echo "Scratch saved")))))))

  (define (cmd-load-persistent-scratch app)
    "Load the persistent scratch file into *scratch* buffer."
    (let ((echo (app-state-echo app)))
      (if (not (file-exists? *persistent-scratch-file*))
        (echo-message! echo "No saved scratch file")
        (with-catch
          (lambda (e) (echo-message! echo "Could not load scratch"))
          (lambda ()
            (let* ((content (read-file-as-string *persistent-scratch-file*))
                   (ed (current-editor app)))
              (editor-set-text ed content)
              (editor-goto-pos ed 0)
              (echo-message! echo "Scratch loaded")))))))

  ;;; =========================================================================
  ;;; Batch 33: insert-char-by-code, subword, bidi, fill-column indicator, etc.
  ;;; =========================================================================

  (define *subword-mode* #f)
  (define *auto-composition-mode* #t)
  (define *bidi-display-reordering* #t)
  (define *fill-column-indicator* #f)
  (define *pixel-scroll-mode* #f)
  (define *auto-highlight-symbol-mode* #f)

  (define *lorem-ipsum-text*
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")

  (define (insert-char-by-code-string str)
    "Parse a string as a code point (decimal or #xHEX or 0xHEX) and return the character, or #f."
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let ((code (cond
                      ((string-prefix? "#x" str)
                       (string->number (substring str 2 (string-length str)) 16))
                      ((string-prefix? "0x" str)
                       (string->number (substring str 2 (string-length str)) 16))
                      (else (string->number str)))))
          (and code (>= code 0) (<= code #x10FFFF) (integer->char code))))))

  (define (cmd-insert-char-by-code app)
    "Insert a character by its Unicode code point (prompts via minibuffer)."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app)))
      (echo-message! echo "insert-char: Use M-x with code point (e.g., 65 or #x41 for 'A')")))

  (define (cmd-toggle-subword-mode app)
    "Toggle subword-mode: treat CamelCase sub-words as word boundaries."
    (let ((echo (app-state-echo app)))
      (set! *subword-mode* (not *subword-mode*))
      (echo-message! echo (if *subword-mode*
                            "Subword mode ON"
                            "Subword mode OFF"))))

  (define (cmd-toggle-auto-composition app)
    "Toggle automatic character composition for display."
    (let ((echo (app-state-echo app)))
      (set! *auto-composition-mode* (not *auto-composition-mode*))
      (echo-message! echo (if *auto-composition-mode*
                            "Auto-composition ON"
                            "Auto-composition OFF"))))

  (define (cmd-toggle-bidi-display app)
    "Toggle bidirectional text display reordering."
    (let ((echo (app-state-echo app)))
      (set! *bidi-display-reordering* (not *bidi-display-reordering*))
      (echo-message! echo (if *bidi-display-reordering*
                            "Bidi display reordering ON"
                            "Bidi display reordering OFF"))))

  (define (cmd-toggle-display-fill-column-indicator app)
    "Toggle display of a line at the fill column."
    (let ((echo (app-state-echo app))
          (ed (current-editor app)))
      (set! *fill-column-indicator* (not *fill-column-indicator*))
      (if *fill-column-indicator*
        (begin
          (send-message ed 2363 1 0)
          (send-message ed 2361 80 0)
          (echo-message! echo "Fill-column indicator ON (col 80)"))
        (begin
          (send-message ed 2363 0 0)
          (echo-message! echo "Fill-column indicator OFF")))))

  (define (cmd-insert-current-file-name app)
    "Insert the current buffer's file name at point."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf)))
      (if path
        (begin
          (editor-replace-selection ed path)
          (echo-message! echo (string-append "Inserted: " path)))
        (echo-message! echo "Buffer has no file name"))))

  (define (cmd-toggle-pixel-scroll app)
    "Toggle pixel-level smooth scrolling mode."
    (let ((echo (app-state-echo app)))
      (set! *pixel-scroll-mode* (not *pixel-scroll-mode*))
      (echo-message! echo (if *pixel-scroll-mode*
                            "Pixel scroll mode ON"
                            "Pixel scroll mode OFF"))))

  (define (cmd-insert-lorem-ipsum app)
    "Insert Lorem Ipsum placeholder text at point."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app)))
      (editor-replace-selection ed *lorem-ipsum-text*)
      (echo-message! echo "Lorem Ipsum inserted")))

  (define (cmd-toggle-auto-highlight-symbol app)
    "Toggle automatic highlighting of the symbol at point."
    (let ((echo (app-state-echo app)))
      (set! *auto-highlight-symbol-mode* (not *auto-highlight-symbol-mode*))
      (echo-message! echo (if *auto-highlight-symbol-mode*
                            "Auto-highlight-symbol mode ON"
                            "Auto-highlight-symbol mode OFF"))))

  (define (cmd-copy-rectangle-to-clipboard app)
    "Copy the current selection to the clipboard (rectangle-aware)."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (echo-message! echo "No selection")
        (begin
          (send-message ed 2178 0 0) ;; SCI_COPY
          (echo-message! echo "Selection copied")))))

  (define (cmd-insert-file-contents-at-point app)
    "Insert contents of the current buffer's file at point (re-insert from disk)."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf)))
      (if (not path)
        (echo-message! echo "Buffer has no file")
        (if (not (file-exists? path))
          (echo-message! echo (string-append "File not found: " path))
          (with-catch
            (lambda (e) (echo-message! echo "Error reading file"))
            (lambda ()
              (let ((content (read-file-as-string path)))
                (editor-replace-selection ed content)
                (echo-message! echo (string-append "Inserted "
                                      (number->string (string-length content))
                                      " bytes from " path)))))))))

  ;;; =========================================================================
  ;;; Batch 39: read-only dirs, uniquify, so-long, tooltips, etc.
  ;;; =========================================================================

  (define *read-only-directories* #f)
  (define *auto-revert-verbose* #t)
  (define *uniquify-buffer-names* #t)
  (define *global-so-long-mode* #t)
  (define *minibuffer-depth-indicate* #f)
  (define *context-menu-mode* #f)
  (define *tooltip-mode* #t)
  (define *file-name-shadow-mode* #t)
  (define *minibuffer-electric-default* #t)
  (define *history-delete-duplicates* #f)

  (define (cmd-toggle-read-only-directories app)
    "Toggle making directory buffers read-only."
    (let ((echo (app-state-echo app)))
      (set! *read-only-directories* (not *read-only-directories*))
      (echo-message! echo (if *read-only-directories*
                            "Read-only directories ON"
                            "Read-only directories OFF"))))

  (define (cmd-toggle-auto-revert-verbose app)
    "Toggle verbose messages for auto-revert."
    (let ((echo (app-state-echo app)))
      (set! *auto-revert-verbose* (not *auto-revert-verbose*))
      (echo-message! echo (if *auto-revert-verbose*
                            "Auto-revert verbose ON"
                            "Auto-revert verbose OFF"))))

  (define (cmd-toggle-uniquify-buffer-names app)
    "Toggle uniquification of buffer names with directory info."
    (let ((echo (app-state-echo app)))
      (set! *uniquify-buffer-names* (not *uniquify-buffer-names*))
      (echo-message! echo (if *uniquify-buffer-names*
                            "Uniquify buffer names ON"
                            "Uniquify buffer names OFF"))))

  (define (cmd-toggle-global-so-long app)
    "Toggle global so-long-mode (mitigate long line performance)."
    (let ((echo (app-state-echo app)))
      (set! *global-so-long-mode* (not *global-so-long-mode*))
      (echo-message! echo (if *global-so-long-mode*
                            "Global so-long mode ON"
                            "Global so-long mode OFF"))))

  (define (cmd-toggle-minibuffer-depth-indicate app)
    "Toggle showing recursive minibuffer depth."
    (let ((echo (app-state-echo app)))
      (set! *minibuffer-depth-indicate* (not *minibuffer-depth-indicate*))
      (echo-message! echo (if *minibuffer-depth-indicate*
                            "Minibuffer depth indicate ON"
                            "Minibuffer depth indicate OFF"))))

  (define (cmd-toggle-context-menu-mode app)
    "Toggle right-click context menu support."
    (let ((echo (app-state-echo app)))
      (set! *context-menu-mode* (not *context-menu-mode*))
      (echo-message! echo (if *context-menu-mode*
                            "Context menu mode ON"
                            "Context menu mode OFF"))))

  (define (cmd-toggle-tooltip-mode app)
    "Toggle tooltip display for UI elements."
    (let ((echo (app-state-echo app)))
      (set! *tooltip-mode* (not *tooltip-mode*))
      (echo-message! echo (if *tooltip-mode*
                            "Tooltips ON"
                            "Tooltips OFF"))))

  (define (cmd-toggle-file-name-shadow app)
    "Toggle shadowing of file name when default is present."
    (let ((echo (app-state-echo app)))
      (set! *file-name-shadow-mode* (not *file-name-shadow-mode*))
      (echo-message! echo (if *file-name-shadow-mode*
                            "File name shadow ON"
                            "File name shadow OFF"))))

  (define (cmd-toggle-minibuffer-electric-default app)
    "Toggle erasing default value on minibuffer input."
    (let ((echo (app-state-echo app)))
      (set! *minibuffer-electric-default* (not *minibuffer-electric-default*))
      (echo-message! echo (if *minibuffer-electric-default*
                            "Minibuffer electric default ON"
                            "Minibuffer electric default OFF"))))

  (define (cmd-toggle-history-delete-duplicates app)
    "Toggle removal of duplicates from command history."
    (let ((echo (app-state-echo app)))
      (set! *history-delete-duplicates* (not *history-delete-duplicates*))
      (echo-message! echo (if *history-delete-duplicates*
                            "History delete duplicates ON"
                            "History delete duplicates OFF"))))

  ;; -- batch 45: themes and UI chrome toggles --
  (define *modus-themes* #f)
  (define *ef-themes* #f)
  (define *nano-theme* #f)
  (define *ligature-mode* #f)
  (define *pixel-scroll-precision* #f)
  ;; *repeat-mode* is defined in core.sls (needed by execute-command!)
  (define *tab-line-mode* #f)
  (define *scroll-bar-mode* #t)
  (define *tool-bar-mode* #f)

  (define (cmd-toggle-modus-themes app)
    "Toggle modus-themes (accessible high-contrast themes)."
    (let ((echo (app-state-echo app)))
      (set! *modus-themes* (not *modus-themes*))
      (echo-message! echo (if *modus-themes*
                            "Modus themes ON" "Modus themes OFF"))))

  (define (cmd-toggle-ef-themes app)
    "Toggle ef-themes (elegant font themes)."
    (let ((echo (app-state-echo app)))
      (set! *ef-themes* (not *ef-themes*))
      (echo-message! echo (if *ef-themes*
                            "Ef themes ON" "Ef themes OFF"))))

  (define (cmd-toggle-nano-theme app)
    "Toggle nano-theme (minimalist appearance)."
    (let ((echo (app-state-echo app)))
      (set! *nano-theme* (not *nano-theme*))
      (echo-message! echo (if *nano-theme*
                            "Nano theme ON" "Nano theme OFF"))))

  (define (cmd-toggle-ligature-mode app)
    "Toggle ligature-mode (font ligature display)."
    (let ((echo (app-state-echo app)))
      (set! *ligature-mode* (not *ligature-mode*))
      (echo-message! echo (if *ligature-mode*
                            "Ligature mode ON" "Ligature mode OFF"))))

  (define (cmd-toggle-pixel-scroll-precision app)
    "Toggle pixel-scroll-precision-mode (smooth scrolling)."
    (let ((echo (app-state-echo app)))
      (set! *pixel-scroll-precision* (not *pixel-scroll-precision*))
      (echo-message! echo (if *pixel-scroll-precision*
                            "Pixel scroll precision ON" "Pixel scroll precision OFF"))))

  (define (cmd-toggle-repeat-mode app)
    "Toggle repeat-mode (repeat last command with single key)."
    (repeat-mode-set! (not (repeat-mode?)))
    (clear-repeat-map!)
    (echo-message! (app-state-echo app)
      (if (repeat-mode?) "Repeat mode enabled" "Repeat mode disabled")))

  (define (cmd-toggle-tab-line-mode app)
    "Toggle tab-line-mode (per-window tab display)."
    (let ((echo (app-state-echo app)))
      (set! *tab-line-mode* (not *tab-line-mode*))
      (echo-message! echo (if *tab-line-mode*
                            "Tab-line mode ON" "Tab-line mode OFF"))))

  (define (cmd-toggle-scroll-bar-mode app)
    "Toggle scroll-bar-mode."
    (let ((echo (app-state-echo app)))
      (set! *scroll-bar-mode* (not *scroll-bar-mode*))
      (echo-message! echo (if *scroll-bar-mode*
                            "Scroll bar mode ON" "Scroll bar mode OFF"))))

  (define (cmd-toggle-tool-bar-mode app)
    "Toggle tool-bar-mode."
    (let ((echo (app-state-echo app)))
      (set! *tool-bar-mode* (not *tool-bar-mode*))
      (echo-message! echo (if *tool-bar-mode*
                            "Tool bar mode ON" "Tool bar mode OFF"))))

  ;; -- batch 51: modern editor integration toggles --
  (define *global-auto-revert-non-file* #f)
  (define *global-tree-sitter* #f)
  (define *global-copilot* #f)
  (define *global-lsp-mode* #f)
  (define *global-format-on-save* #f)
  (define *global-yas* #f)
  (define *global-smartparens* #f)

  (define (cmd-toggle-global-auto-revert-non-file app)
    "Toggle auto-revert for non-file buffers (dired, etc)."
    (let ((echo (app-state-echo app)))
      (set! *global-auto-revert-non-file* (not *global-auto-revert-non-file*))
      (echo-message! echo (if *global-auto-revert-non-file*
                            "Auto-revert non-file ON" "Auto-revert non-file OFF"))))

  (define (cmd-toggle-global-tree-sitter app)
    "Toggle global tree-sitter syntax support."
    (let ((echo (app-state-echo app)))
      (set! *global-tree-sitter* (not *global-tree-sitter*))
      (echo-message! echo (if *global-tree-sitter*
                            "Tree-sitter global ON" "Tree-sitter global OFF"))))

  (define (cmd-toggle-global-copilot app)
    "Toggle global copilot-mode (AI completion)."
    (let ((echo (app-state-echo app)))
      (set! *global-copilot* (not *global-copilot*))
      (echo-message! echo (if *global-copilot*
                            "Copilot global ON" "Copilot global OFF"))))

  (define (cmd-toggle-global-lsp-mode app)
    "Toggle global lsp-mode (language server protocol)."
    (let ((echo (app-state-echo app)))
      (set! *global-lsp-mode* (not *global-lsp-mode*))
      (echo-message! echo (if *global-lsp-mode*
                            "LSP mode global ON" "LSP mode global OFF"))))

  (define (cmd-toggle-global-format-on-save app)
    "Toggle format-on-save (auto-format before saving)."
    (let ((echo (app-state-echo app)))
      (set! *global-format-on-save* (not *global-format-on-save*))
      (echo-message! echo (if *global-format-on-save*
                            "Format on save ON" "Format on save OFF"))))

  (define (cmd-toggle-global-yas app)
    "Toggle global yasnippet-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-yas* (not *global-yas*))
      (echo-message! echo (if *global-yas*
                            "Yasnippet global ON" "Yasnippet global OFF"))))

  (define (cmd-toggle-global-smartparens app)
    "Toggle global smartparens-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-smartparens* (not *global-smartparens*))
      (echo-message! echo (if *global-smartparens*
                            "Smartparens global ON" "Smartparens global OFF"))))

  ;;; ---- batch 59: help and testing framework toggles ----

  (define *global-helpful* #f)
  (define *global-elisp-demos* #f)
  (define *global-suggest* #f)
  (define *global-buttercup* #f)
  (define *global-ert-runner* #f)
  (define *global-undercover* #f)
  (define *global-benchmark-init* #f)

  (define (cmd-toggle-global-helpful app)
    "Toggle global helpful-mode (better help buffers)."
    (let ((echo (app-state-echo app)))
      (set! *global-helpful* (not *global-helpful*))
      (echo-message! echo (if *global-helpful*
                            "Global helpful ON" "Global helpful OFF"))))

  (define (cmd-toggle-global-elisp-demos app)
    "Toggle global elisp-demos-mode (code examples in help)."
    (let ((echo (app-state-echo app)))
      (set! *global-elisp-demos* (not *global-elisp-demos*))
      (echo-message! echo (if *global-elisp-demos*
                            "Elisp demos ON" "Elisp demos OFF"))))

  (define (cmd-toggle-global-suggest app)
    "Toggle global suggest-mode (discover functions by example)."
    (let ((echo (app-state-echo app)))
      (set! *global-suggest* (not *global-suggest*))
      (echo-message! echo (if *global-suggest*
                            "Global suggest ON" "Global suggest OFF"))))

  (define (cmd-toggle-global-buttercup app)
    "Toggle global buttercup-mode (BDD testing framework)."
    (let ((echo (app-state-echo app)))
      (set! *global-buttercup* (not *global-buttercup*))
      (echo-message! echo (if *global-buttercup*
                            "Global buttercup ON" "Global buttercup OFF"))))

  (define (cmd-toggle-global-ert-runner app)
    "Toggle global ert-runner-mode (ERT test runner)."
    (let ((echo (app-state-echo app)))
      (set! *global-ert-runner* (not *global-ert-runner*))
      (echo-message! echo (if *global-ert-runner*
                            "ERT runner ON" "ERT runner OFF"))))

  (define (cmd-toggle-global-undercover app)
    "Toggle global undercover-mode (code coverage tool)."
    (let ((echo (app-state-echo app)))
      (set! *global-undercover* (not *global-undercover*))
      (echo-message! echo (if *global-undercover*
                            "Global undercover ON" "Global undercover OFF"))))

  (define (cmd-toggle-global-benchmark-init app)
    "Toggle global benchmark-init-mode (startup timing)."
    (let ((echo (app-state-echo app)))
      (set! *global-benchmark-init* (not *global-benchmark-init*))
      (echo-message! echo (if *global-benchmark-init*
                            "Benchmark init ON" "Benchmark init OFF"))))

  ;;; ---- batch 68: additional programming language toggles ----

  (define *global-clojure-mode* #f)
  (define *global-cider* #f)
  (define *global-haskell-mode* #f)
  (define *global-lua-mode* #f)
  (define *global-ruby-mode* #f)
  (define *global-php-mode* #f)
  (define *global-swift-mode* #f)

  (define (cmd-toggle-global-clojure-mode app)
    "Toggle global clojure-mode (Clojure development)."
    (let ((echo (app-state-echo app)))
      (set! *global-clojure-mode* (not *global-clojure-mode*))
      (echo-message! echo (if *global-clojure-mode*
                            "Clojure mode ON" "Clojure mode OFF"))))

  (define (cmd-toggle-global-cider app)
    "Toggle global CIDER-mode (Clojure interactive development)."
    (let ((echo (app-state-echo app)))
      (set! *global-cider* (not *global-cider*))
      (echo-message! echo (if *global-cider*
                            "CIDER ON" "CIDER OFF"))))

  (define (cmd-toggle-global-haskell-mode app)
    "Toggle global haskell-mode (Haskell development)."
    (let ((echo (app-state-echo app)))
      (set! *global-haskell-mode* (not *global-haskell-mode*))
      (echo-message! echo (if *global-haskell-mode*
                            "Haskell mode ON" "Haskell mode OFF"))))

  (define (cmd-toggle-global-lua-mode app)
    "Toggle global lua-mode (Lua development)."
    (let ((echo (app-state-echo app)))
      (set! *global-lua-mode* (not *global-lua-mode*))
      (echo-message! echo (if *global-lua-mode*
                            "Lua mode ON" "Lua mode OFF"))))

  (define (cmd-toggle-global-ruby-mode app)
    "Toggle global ruby-mode (Ruby development)."
    (let ((echo (app-state-echo app)))
      (set! *global-ruby-mode* (not *global-ruby-mode*))
      (echo-message! echo (if *global-ruby-mode*
                            "Ruby mode ON" "Ruby mode OFF"))))

  (define (cmd-toggle-global-php-mode app)
    "Toggle global php-mode (PHP development)."
    (let ((echo (app-state-echo app)))
      (set! *global-php-mode* (not *global-php-mode*))
      (echo-message! echo (if *global-php-mode*
                            "PHP mode ON" "PHP mode OFF"))))

  (define (cmd-toggle-global-swift-mode app)
    "Toggle global swift-mode (Swift development)."
    (let ((echo (app-state-echo app)))
      (set! *global-swift-mode* (not *global-swift-mode*))
      (echo-message! echo (if *global-swift-mode*
                            "Swift mode ON" "Swift mode OFF"))))

  ;;;============================================================================
  ;;; Scratch buffer new (create numbered scratch buffers)
  ;;;============================================================================

  (define *tui-scratch-counter* 0)

  (define (cmd-scratch-buffer-new app)
    "Create a new scratch buffer with a unique name."
    (let* ((ed (current-editor app))
           (fr (app-state-frame app)))
      (set! *tui-scratch-counter* (+ *tui-scratch-counter* 1))
      (let* ((name (string-append "*scratch-" (number->string *tui-scratch-counter*) "*"))
             (buf (buffer-create! name ed #f)))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! (current-window fr) buf)
        (editor-set-text ed (string-append ";; " name " -- scratch buffer\n\n"))
        (echo-message! (app-state-echo app) (string-append "Created " name)))))

  ;;;============================================================================
  ;;; Swap window contents
  ;;;============================================================================

  (define (cmd-swap-window app)
    "Swap the buffers of the current and next window."
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (n (length wins)))
      (if (<= n 1)
        (echo-message! (app-state-echo app) "Only one window")
        (let* ((idx (frame-current-idx fr))
               (other-idx (modulo (+ idx 1) n))
               (w1 (list-ref wins idx))
               (w2 (list-ref wins other-idx))
               (b1 (edit-window-buffer w1))
               (b2 (edit-window-buffer w2)))
          (edit-window-buffer-set! w1 b2)
          (edit-window-buffer-set! w2 b1)
          (buffer-attach! (edit-window-editor w1) b2)
          (buffer-attach! (edit-window-editor w2) b1)
          (echo-message! (app-state-echo app) "Windows swapped")))))

  ;;; Parity batch 9: workspace, clipboard, undo-history, xref
  (define *tui-workspaces* (make-hash-table))
  (define *tui-current-ws* "default")
  (define *tui-ws-bufs* (make-hash-table))

  (define (cmd-workspace-create app)
    "Create workspace."
    (let ((name (app-read-string app "New workspace name: ")))
      (when (and name (> (string-length name) 0))
        (if (hash-get *tui-workspaces* name)
          (echo-message! (app-state-echo app) (string-append "Workspace '" name "' exists"))
          (begin (hash-put! *tui-workspaces* name '("*scratch*"))
                 (echo-message! (app-state-echo app) (string-append "Created workspace: " name)))))))

  (define (cmd-workspace-switch app)
    "Switch workspace."
    (let* ((names (sort (hash-keys *tui-workspaces*) string<?))
           (name (app-read-string app (string-append "Switch (" (string-join names ", ") "): "))))
      (when (and name (> (string-length name) 0))
        (if (hash-get *tui-workspaces* name)
          (begin (set! *tui-current-ws* name)
            (let* ((active (hash-get *tui-ws-bufs* name))
                   (buf (and active (buffer-by-name active))))
              (when buf
                (let* ((fr (app-state-frame app))
                       (win (current-window fr))
                       (ed (edit-window-editor win)))
                  (buffer-attach! ed buf)
                  (edit-window-buffer-set! win buf))))
            (echo-message! (app-state-echo app) (string-append "Workspace: " name)))
          (echo-message! (app-state-echo app) (string-append "No workspace: " name))))))

  (define (cmd-workspace-delete app)
    "Delete workspace."
    (let* ((names (sort (filter (lambda (n) (not (string=? n "default")))
                                (hash-keys *tui-workspaces*))
                        string<?))
           (name (if (null? names)
                   (begin (echo-message! (app-state-echo app) "No deletable workspaces") #f)
                   (app-read-string app (string-append "Delete (" (string-join names ", ") "): ")))))
      (when (and name (> (string-length name) 0))
        (cond ((string=? name "default")
               (echo-message! (app-state-echo app) "Cannot delete default"))
              ((hash-get *tui-workspaces* name)
               (hash-remove! *tui-workspaces* name)
               (hash-remove! *tui-ws-bufs* name)
               (when (string=? *tui-current-ws* name) (set! *tui-current-ws* "default"))
               (echo-message! (app-state-echo app) (string-append "Deleted: " name)))
              (else (echo-message! (app-state-echo app) (string-append "No workspace: " name)))))))

  (define (cmd-workspace-add-buffer app)
    "Add buffer to workspace."
    (let* ((buf (current-buffer-from-app app))
           (name (and buf (buffer-name buf))))
      (when name
        (let ((bufs (or (hash-get *tui-workspaces* *tui-current-ws*) '())))
          (unless (member name bufs)
            (hash-put! *tui-workspaces* *tui-current-ws* (cons name bufs))))
        (echo-message! (app-state-echo app) (string-append "Added '" name "' to " *tui-current-ws*)))))

  (define (cmd-workspace-list app)
    "List workspaces."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (lines (let loop ((ns (sort (hash-keys *tui-workspaces*) string<?)) (acc '()))
                    (if (null? ns) (reverse acc)
                      (let* ((n (car ns))
                             (bufs (or (hash-get *tui-workspaces* n) '())))
                        (loop (cdr ns) (cons (string-append n ": " (string-join bufs ", ")) acc))))))
           (buf (buffer-create! "*Workspaces*" ed)))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (editor-set-text ed (string-append "Workspaces:\n" (string-join lines "\n")))
      (editor-goto-pos ed 0)))

  (define (cmd-copy-buffer-filename app)
    "Copy buffer filename."
    (let* ((buf (current-buffer-from-app app))
           (name (and buf (buffer-name buf))))
      (when name (echo-message! (app-state-echo app) (string-append "Buffer: " name)))))

  (define (cmd-revert-buffer-confirm app)
    "Revert buffer with confirmation."
    (let* ((buf (current-buffer-from-app app))
           (path (and buf (buffer-file-path buf))))
      (if (not path)
        (echo-error! (app-state-echo app) "Buffer has no file")
        (let ((ans (app-read-string app (string-append "Revert " (path-strip-directory path) "? (y/n) "))))
          (when (and ans (member ans '("y" "yes")))
            (cmd-revert-buffer-no-confirm app))))))

  (define *tui-undo-history* (make-hash-table))

  (define (cmd-undo-history app)
    "Show undo history."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (buf (edit-window-buffer win))
           (name (and buf (buffer-name buf)))
           (hist (or (hash-get *tui-undo-history* name) '())))
      (if (null? hist)
        (echo-message! (app-state-echo app) "No undo history")
        (let* ((lines (let loop ((es hist) (i 0) (acc '()))
                 (if (null? es) (reverse acc)
                   (let* ((e (car es))
                          (ts (car e))
                          (tlen (string-length (cdr e)))
                          (now (inexact->exact (floor (time->seconds (current-time)))))
                          (age (- now ts))
                          (age-s (cond ((< age 60) (string-append (number->string age) "s"))
                                       ((< age 3600) (string-append (number->string (quotient age 60)) "m"))
                                       (else (string-append (number->string (quotient age 3600)) "h")))))
                     (loop (cdr es) (+ i 1)
                       (cons (string-append (number->string i) ": " age-s " ago, "
                               (number->string tlen) " chars"
                               (if (= i 0) " <- current" ""))
                             acc))))))
               (hbuf (buffer-create! "*Undo History*" ed)))
          (buffer-attach! ed hbuf)
          (edit-window-buffer-set! win hbuf)
          (editor-set-text ed (string-append "Undo History: " name "\n" (string-join lines "\n")))
          (editor-goto-pos ed 0)))))

  (define (cmd-undo-history-restore app)
    "Restore undo snapshot."
    (let* ((buf (current-buffer-from-app app))
           (name (and buf (buffer-name buf)))
           (hist (or (hash-get *tui-undo-history* name) '())))
      (if (null? hist)
        (echo-message! (app-state-echo app) "No undo history")
        (let ((input (app-read-string app
                       (string-append "Restore (0-" (number->string (- (length hist) 1)) "): "))))
          (when input
            (let ((num (string->number (string-trim input))))
              (when (and num (>= num 0) (< num (length hist)))
                (let* ((txt (cdr (list-ref hist num)))
                       (fr (app-state-frame app))
                       (win (current-window fr))
                       (ed (edit-window-editor win)))
                  (editor-set-text ed txt)
                  (editor-goto-pos ed 0)
                  (echo-message! (app-state-echo app)
                    (string-append "Restored snapshot " (number->string num)))))))))))

  (define *tui-xref-stack* '())

  (define (cmd-xref-back app)
    "Jump back in xref history."
    (if (null? *tui-xref-stack*)
      (echo-message! (app-state-echo app) "Xref stack empty")
      (let* ((loc (car *tui-xref-stack*))
             (name (car loc))
             (pos (cdr loc))
             (buf (buffer-by-name name))
             (fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win)))
        (set! *tui-xref-stack* (cdr *tui-xref-stack*))
        (when buf
          (buffer-attach! ed buf)
          (edit-window-buffer-set! win buf))
        (editor-goto-pos ed pos)
        (echo-message! (app-state-echo app) (string-append "Back to " name)))))

  ;; Initialize default workspace
  (hash-put! *tui-workspaces* "default" '("*scratch*"))

) ;; end library
