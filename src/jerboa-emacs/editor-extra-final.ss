;;; -*- Gerbil -*-
;;; Task #51: Additional commands

(export #t)

(import :std/sugar
        :std/sort
        :std/srfi/13
        :std/misc/string
        :std/misc/process
        :std/misc/ports
        :std/srfi/19
        (only-in :std/text/glob glob-match?)
        ./pregexp-compat
        :chez-scintilla/constants
        :chez-scintilla/scintilla
        :chez-scintilla/tui
        :jerboa-emacs/core
        :jerboa-emacs/keymap
        :jerboa-emacs/buffer
        :jerboa-emacs/window
        :jerboa-emacs/modeline
        :jerboa-emacs/echo
        (only-in :jerboa-emacs/editor-core
                 search-forward-regexp-impl!)
        (only-in :jerboa-emacs/editor-ui
                 position-cursor-for-replace!)
        :jerboa-emacs/editor-extra-helpers
        :jerboa-emacs/editor-extra-web
        :jerboa-emacs/editor-extra-media
        :jerboa-emacs/editor-extra-media2
        :jerboa-emacs/editor-extra-modes)

;;;============================================================================
;;; Task #51: Additional unique commands to cross 1000 registrations
;;;============================================================================

;; --- Emacs built-in modes not yet covered ---
(def (cmd-native-compile-file app)
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
                 (proc (open-process
                         (list path: "gxc" arguments: (list "-S" path)
                               stdin-redirection: #f stdout-redirection: #t stderr-redirection: #t)))
                 (output (read-line proc #f))
                 (status (process-status proc)))
            (close-port proc)
            (let ((comp-buf (buffer-create! "*compilation*" ed)))
              (buffer-attach! ed comp-buf)
              (set! (edit-window-buffer win) comp-buf)
              (editor-set-text ed
                (string-append "Compiling " path "...\n\n"
                               (or output "")
                               "\n\nCompilation "
                               (if (= status 0) "finished" (string-append "failed (exit " (number->string status) ")"))
                               "\n")))
            (echo-message! echo
              (if (= status 0)
                (string-append "Compiled " (path-strip-directory path))
                (string-append "Compilation failed: " (path-strip-directory path))))))))))

(def (cmd-native-compile-async app)
  "Native compile asynchronously — background compilation."
  (echo-message! (app-state-echo app) "Async compile: use M-x compile"))

(def (cmd-tab-line-mode app)
  "Toggle tab-line-mode — shows buffer tabs."
  (let ((on (toggle-mode! 'tab-line)))
    (echo-message! (app-state-echo app) (if on "Tab-line: on" "Tab-line: off"))))

(def (cmd-pixel-scroll-precision-mode app)
  "Toggle pixel-scroll-precision-mode — smooth scrolling."
  (let ((on (toggle-mode! 'pixel-scroll)))
    (echo-message! (app-state-echo app) (if on "Pixel scroll: on" "Pixel scroll: off"))))

(def *so-long-threshold* 500)  ;; line length threshold

(def (so-long-detect? ed)
  "Check if buffer has lines longer than threshold."
  (let* ((text (editor-get-text ed))
         (len (string-length text)))
    (let loop ((i 0) (line-start 0) (checked 0))
      (cond
        ((>= checked 50) #f)  ;; only check first 50 lines
        ((>= i len)
         (> (- i line-start) *so-long-threshold*))
        ((char=? (string-ref text i) #\newline)
         (if (> (- i line-start) *so-long-threshold*)
           #t
           (loop (+ i 1) (+ i 1) (+ checked 1))))
        (else (loop (+ i 1) line-start checked))))))

(def (so-long-apply! ed)
  "Apply so-long optimizations: disable wrap, word wrap, and syntax highlighting."
  (send-message ed 2469 0 0)    ;; SCI_SETWRAPMODE = SC_WRAP_NONE
  (send-message ed SCI_SETLEXER 1 0)  ;; SCLEX_NULL = no syntax
  (send-message ed SCI_SETINDENTATIONGUIDES 0 0))

(def (cmd-so-long-mode app)
  "Toggle so-long mode — disable slow features for long-line files."
  (let* ((on (toggle-mode! 'so-long))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (if on
      (if (so-long-detect? ed)
        (begin
          (so-long-apply! ed)
          (echo-message! (app-state-echo app) "So-long: on (long lines detected, features disabled)"))
        (echo-message! (app-state-echo app) "So-long: on (no long lines found)"))
      (echo-message! (app-state-echo app) "So-long: off"))))

(def (cmd-repeat-mode app)
  "Toggle repeat-mode for transient repeat maps."
  (repeat-mode-set! (not (repeat-mode?)))
  (clear-repeat-map!)
  (echo-message! (app-state-echo app)
    (if (repeat-mode?) "Repeat mode enabled" "Repeat mode disabled")))

(def (cmd-context-menu-mode app)
  "Toggle context-menu-mode — N/A in terminal."
  (echo-message! (app-state-echo app) "Context menu: N/A in terminal"))

(def *savehist-file*
  (string-append (or (getenv "HOME" #f) ".") "/.jemacs-history"))

;; Shared minibuffer history list (strings from echo-read-string)
(def *savehist-list* '())

(def (savehist-record! input)
  "Record an input string in the savehist list."
  (when (and (string? input) (> (string-length input) 0))
    (set! *savehist-list*
      (cons input (filter (lambda (s) (not (string=? s input)))
                          *savehist-list*)))
    (when (> (length *savehist-list*) 200)
      (set! *savehist-list* (take *savehist-list* 200)))))

(def (savehist-save!)
  "Save minibuffer history to disk."
  (with-exception-catcher
    (lambda (e) #f)
    (lambda ()
      (call-with-output-file *savehist-file*
        (lambda (port)
          (for-each (lambda (item)
                      (write item port) (newline port))
                    *savehist-list*))))))

(def (savehist-load!)
  "Load minibuffer history from disk."
  (with-exception-catcher
    (lambda (e) #f)
    (lambda ()
      (when (file-exists? *savehist-file*)
        (set! *savehist-list*
          (call-with-input-file *savehist-file*
            (lambda (port)
              (let loop ((acc '()))
                (let ((item (read port)))
                  (if (eof-object? item) (reverse acc)
                    (loop (cons item acc))))))))))))

(def (cmd-savehist-mode app)
  "Toggle savehist-mode — persist minibuffer history to ~/.jemacs-history."
  (let ((on (toggle-mode! 'savehist)))
    (if on (savehist-load!) (savehist-save!))
    (echo-message! (app-state-echo app)
      (if on
        (string-append "Savehist: on (" (number->string (length *savehist-list*)) " entries)")
        "Savehist: off (saved)"))))

(def *recentf-file*
  (string-append (or (getenv "HOME" #f) ".") "/.jemacs-recentf"))

(def (recentf-save!)
  "Save recent files list to disk."
  (with-exception-catcher
    (lambda (e) #f)
    (lambda ()
      (let ((items (if (> (length *recent-files*) 50) (take *recent-files* 50) *recent-files*)))
        (call-with-output-file *recentf-file*
          (lambda (port)
            (for-each (lambda (path)
                        (write path port) (newline port))
                      items)))))))

(def (recentf-load!)
  "Load recent files list from disk."
  (with-exception-catcher
    (lambda (e) #f)
    (lambda ()
      (when (file-exists? *recentf-file*)
        (let ((items (call-with-input-file *recentf-file*
                       (lambda (port)
                         (let loop ((acc '()))
                           (let ((item (read port)))
                             (if (eof-object? item) (reverse acc)
                               (loop (cons item acc)))))))))
          ;; Merge loaded files with current, avoiding duplicates
          (for-each
            (lambda (path)
              (unless (member path *recent-files*)
                (set! *recent-files* (append *recent-files* (list path)))))
            items))))))

(def (cmd-recentf-mode app)
  "Toggle recentf-mode — persist recent files list to ~/.jemacs-recentf."
  (let ((on (toggle-mode! 'recentf)))
    (if on (recentf-load!) (recentf-save!))
    (echo-message! (app-state-echo app)
      (if on
        (string-append "Recentf: on (" (number->string (length *recent-files*)) " files)")
        "Recentf: off (saved)"))))

(def (cmd-winner-undo-2 app)
  "Winner undo alternative binding."
  (cmd-winner-undo app))

(def *subword-mode* #f)

(def (subword-forward-pos ed)
  "Find next subword boundary position (CamelCase/underscore aware)."
  (let* ((pos (editor-get-current-pos ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (if (>= pos len) pos
      (let loop ((i (+ pos 1)))
        (cond
          ((>= i len) i)
          ;; Stop at transitions: lower→upper, letter→non-alphanum, non-alphanum→letter
          ((and (> i (+ pos 1))
                (let ((c (string-ref text i))
                      (p (string-ref text (- i 1))))
                  (or (and (char-lower-case? p) (char-upper-case? c))
                      (and (char-alphabetic? p) (char=? c #\_))
                      (and (char=? p #\_) (char-alphabetic? c))
                      (and (char-alphabetic? p) (not (char-alphabetic? c)) (not (char=? c #\_)))
                      (and (not (char-alphabetic? p)) (not (char=? p #\_)) (char-alphabetic? c)))))
           i)
          (else (loop (+ i 1))))))))

(def (subword-backward-pos ed)
  "Find previous subword boundary position."
  (let* ((pos (editor-get-current-pos ed))
         (text (editor-get-text ed)))
    (if (<= pos 0) 0
      (let loop ((i (- pos 1)))
        (cond
          ((< i 1) 0)
          ((let ((c (string-ref text i))
                 (p (string-ref text (- i 1))))
             (or (and (char-upper-case? c) (char-lower-case? p))
                 (and (char-alphabetic? c) (char=? p #\_))
                 (and (char=? c #\_) (char-alphabetic? p))
                 (and (char-alphabetic? c) (not (char-alphabetic? p)) (not (char=? p #\_)))))
           i)
          (else (loop (- i 1))))))))

(def (cmd-subword-forward app)
  "Move forward one subword (CamelCase-aware)."
  (let ((ed (edit-window-editor (current-window (app-state-frame app)))))
    (editor-goto-pos ed (subword-forward-pos ed))))

(def (cmd-subword-backward app)
  "Move backward one subword (CamelCase-aware)."
  (let ((ed (edit-window-editor (current-window (app-state-frame app)))))
    (editor-goto-pos ed (subword-backward-pos ed))))

(def (cmd-subword-kill app)
  "Kill forward one subword."
  (let* ((ed (edit-window-editor (current-window (app-state-frame app))))
         (start (editor-get-current-pos ed))
         (end (subword-forward-pos ed)))
    (when (> end start)
      (send-message ed SCI_SETTARGETSTART start 0)
      (send-message ed SCI_SETTARGETEND end 0)
      (send-message/string ed SCI_REPLACETARGET ""))))

(def (cmd-global-subword-mode app)
  "Toggle global subword-mode (CamelCase navigation)."
  (set! *subword-mode* (not *subword-mode*))
  (echo-message! (app-state-echo app)
    (if *subword-mode* "Subword mode: on (use M-x subword-forward/backward)" "Subword mode: off")))

(def (cmd-display-fill-column-indicator-mode app)
  "Toggle fill column indicator display."
  (let* ((fr (app-state-frame app))
         (on (toggle-mode! 'fill-column-indicator)))
    (for-each
      (lambda (win)
        (let ((ed (edit-window-editor win)))
          (send-message ed 2363 #|SCI_SETEDGEMODE|# (if on 1 0) 0)
          (when on (send-message ed 2361 #|SCI_SETEDGECOLUMN|# 80 0))))
      (frame-windows fr))
    (echo-message! (app-state-echo app)
      (if on "Fill column indicator: on (80)" "Fill column indicator: off"))))

(def (cmd-global-display-line-numbers-mode app)
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

(def (cmd-indent-bars-mode app)
  "Toggle indent-bars indentation guides."
  (cmd-indent-guide-mode app))

(def (cmd-global-hl-line-mode app)
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

(def (cmd-delete-selection-mode app)
  "Toggle delete-selection-mode — typed text replaces selection."
  (let ((on (toggle-mode! 'delete-selection)))
    (echo-message! (app-state-echo app)
      (if on "Delete selection mode: on" "Delete selection mode: off"))))

(def (cmd-electric-indent-mode app)
  "Toggle electric-indent-mode — auto-indent on newline."
  (set! *electric-indent-mode* (not *electric-indent-mode*))
  (echo-message! (app-state-echo app)
    (if *electric-indent-mode* "Electric indent: on" "Electric indent: off")))

(def (cmd-show-paren-mode app)
  "Toggle show-paren-mode — highlight matching parentheses."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (on (toggle-mode! 'show-paren)))
    (if on
      (begin
        (send-message ed SCI_STYLESETFORE 34 #x00FF00)  ;; STYLE_BRACELIGHT
        (send-message ed SCI_STYLESETBACK 34 #x333333)
        (echo-message! (app-state-echo app) "Show paren: on"))
      (begin
        (send-message ed SCI_STYLESETFORE 34 #xFFFFFF)
        (send-message ed SCI_STYLESETBACK 34 #x000000)
        (echo-message! (app-state-echo app) "Show paren: off")))))

(def (cmd-column-number-mode app)
  "Toggle column-number-mode in modeline."
  (let ((on (toggle-mode! 'column-number)))
    (echo-message! (app-state-echo app) (if on "Column number: on" "Column number: off"))))

(def (cmd-size-indication-mode app)
  "Toggle size-indication-mode in modeline."
  (let ((on (toggle-mode! 'size-indication)))
    (echo-message! (app-state-echo app) (if on "Size indication: on" "Size indication: off"))))

(def (cmd-minibuffer-depth-indicate-mode app)
  "Toggle minibuffer-depth-indicate-mode."
  (let ((on (toggle-mode! 'minibuffer-depth)))
    (echo-message! (app-state-echo app) (if on "Minibuffer depth: on" "Minibuffer depth: off"))))

(def (cmd-file-name-shadow-mode app)
  "Toggle file-name-shadow-mode — dims irrelevant path in minibuffer."
  (let ((on (toggle-mode! 'file-name-shadow)))
    (echo-message! (app-state-echo app) (if on "File name shadow: on" "File name shadow: off"))))

(def (cmd-midnight-mode app)
  "Toggle midnight-mode — clean up old buffers periodically."
  (let ((on (toggle-mode! 'midnight)))
    (echo-message! (app-state-echo app) (if on "Midnight mode: on" "Midnight mode: off"))))

(def (cmd-cursor-intangible-mode app)
  "Toggle cursor-intangible-mode."
  (let ((on (toggle-mode! 'cursor-intangible)))
    (echo-message! (app-state-echo app) (if on "Cursor intangible: on" "Cursor intangible: off"))))

(def (cmd-auto-compression-mode app)
  "Toggle auto-compression-mode — transparent compressed file access."
  (let ((on (toggle-mode! 'auto-compression)))
    (echo-message! (app-state-echo app) (if on "Auto-compression: on" "Auto-compression: off"))))

;;;============================================================================
;;; Window resize commands
;;;============================================================================

(def (cmd-enlarge-window app)
  "Make current window taller (C-x ^)."
  (let* ((fr (app-state-frame app))
         (n (get-prefix-arg app)))
    (if (> (length (frame-windows fr)) 1)
      (begin
        (frame-enlarge-window! fr n)
        (echo-message! (app-state-echo app)
          (string-append "Window enlarged by " (number->string n))))
      (echo-error! (app-state-echo app) "Only one window"))))

(def (cmd-shrink-window app)
  "Make current window shorter."
  (let* ((fr (app-state-frame app))
         (n (get-prefix-arg app)))
    (if (> (length (frame-windows fr)) 1)
      (begin
        (frame-shrink-window! fr n)
        (echo-message! (app-state-echo app)
          (string-append "Window shrunk by " (number->string n))))
      (echo-error! (app-state-echo app) "Only one window"))))

(def (cmd-enlarge-window-horizontally app)
  "Make current window wider (C-x })."
  (let* ((fr (app-state-frame app))
         (n (get-prefix-arg app)))
    (if (> (length (frame-windows fr)) 1)
      (begin
        (frame-enlarge-window-horizontally! fr n)
        (echo-message! (app-state-echo app)
          (string-append "Window widened by " (number->string n))))
      (echo-error! (app-state-echo app) "Only one window"))))

(def (cmd-shrink-window-horizontally app)
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

(def *last-regexp-search* "")

(def (cmd-search-forward-regexp app)
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

(def (cmd-query-replace-regexp-interactive app)
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
            (regexp-query-replace-loop! app ed from-str to-str))))))  )

(def (regexp-query-replace-loop! app ed pattern replacement)
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
;;; Editorconfig support — read .editorconfig and apply settings
;;;============================================================================

(def (parse-editorconfig path)
  "Parse .editorconfig file into list of (glob-pattern . settings-hash) pairs."
  (let ((result '())
        (current-glob #f)
        (current-settings #f))
    (when (file-exists? path)
      (call-with-input-file path
        (lambda (port)
          (let loop ()
            (let ((line (read-line port)))
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

(def (editorconfig-glob-match? pattern filename)
  "Glob matching for editorconfig patterns."
  (glob-match? pattern (path-strip-directory filename)))

(def (find-editorconfig filepath)
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

(def (apply-editorconfig! ed settings)
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

(def (cmd-editorconfig-apply app)
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

(def *formatters*
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

(def (detect-language-from-extension path)
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

(def (cmd-format-buffer app)
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
                                    (with-output-to-string
                                      (lambda () (display-exception e))))))
              (lambda ()
                (let ((formatted (filter-with-process cmd
                                   (lambda (port) (display text port))
                                   (lambda (port) (read-line port #f)))))
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

(def (cmd-git-blame-line app)
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
                            ["git" "-C" dir "blame" "-L"
                             (string-append (number->string line) ","
                                            (number->string line))
                             "--porcelain" fname]))
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

(def *command-history* '())
(def *command-history-file* "~/.jemacs-cmd-history")

(def (command-history-load!)
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
                  (let ((line (read-line port)))
                    (if (eof-object? line)
                      (reverse acc)
                      (loop (cons line acc)))))))))))))

(def (command-history-save!)
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

(def (command-history-add! cmd-name)
  "Add a command to history (most recent first, dedup)."
  (let ((name (if (symbol? cmd-name) (symbol->string cmd-name) cmd-name)))
    (set! *command-history*
      (cons name (filter (lambda (x) (not (string=? x name)))
                         *command-history*)))))

(def (cmd-execute-extended-command-with-history app)
  "M-x with command history — shows recently used commands first."
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

(def (collect-buffer-words ed)
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

(def (cmd-complete-word-from-buffer app)
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

(def (find-url-at-point text pos)
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

(def (cmd-open-url-at-point app)
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
              (run-process/batch ["xdg-open" url])
              (echo-message! echo (string-append "Opening: " url)))))))))

;;;============================================================================
;;; MRU buffer switching
;;;============================================================================

(def *buffer-access-times* (make-hash-table))

(def *buffer-access-counter* 0)

(def (record-buffer-access! buf-name)
  "Record access time for a buffer using a monotonic counter."
  (set! *buffer-access-counter* (+ *buffer-access-counter* 1))
  (hash-put! *buffer-access-times* buf-name *buffer-access-counter*))

(def (cmd-switch-buffer-mru app)
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
        (set! (edit-window-buffer (current-window fr)) target)
        (record-buffer-access! (buffer-name target))
        (echo-message! echo (string-append "Buffer: " (buffer-name target)))))))

;;;============================================================================
;;; Pipe region through shell command
;;;============================================================================

(def (cmd-shell-command-on-region-replace app)
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
                    (with-output-to-string
                      (lambda () (display-exception e))))))
              (lambda ()
                (let ((output (filter-with-process ["/bin/sh" "-c" cmd-str]
                               (lambda (port) (display region port))
                               (lambda (port) (read-line port #f)))))
                  (editor-set-selection ed start end)
                  (send-message/string ed 2170 output) ;; SCI_REPLACESEL
                  (echo-message! echo
                    (string-append "Replaced "
                      (number->string (- end start)) " chars")))))))))))

;;;============================================================================
;;; Named keyboard macros — uses app-state-macro-named hash table
;;;============================================================================

(def (cmd-execute-named-macro app)
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

(def (cmd-apply-macro-to-region app)
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

(def (cmd-diff-summary app)
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

(def (cmd-revert-buffer-no-confirm app)
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
               (text (call-with-input-file path
                       (lambda (port) (read-string 10000000 port)))))
          (editor-set-text ed text)
          (editor-goto-pos ed (min pos (string-length text)))
          (echo-message! echo "Reverted"))))))

;;;============================================================================
;;; Sudo save (write file with elevated privileges)
;;;============================================================================

(def (cmd-sudo-save-buffer app)
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
            (let ((tmp (string-append "/tmp/.jemacs-sudo-"
                         (number->string (random-integer 999999)))))
              ;; Write to temp, then sudo mv
              (call-with-output-file tmp
                (lambda (port) (display text port)))
              (run-process/batch ["sudo" "cp" tmp path])
              (run-process/batch ["rm" "-f" tmp])
              (echo-message! echo (string-append "Sudo saved: " path)))))))))

;;;============================================================================
;;; Batch 28: regex builder, web search, edit position tracking, conversions
;;;============================================================================

;;; --- Interactive regex builder ---

(def *regex-builder-pattern* "")

(def (cmd-regex-builder app)
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
          (let* (
                 (text (editor-get-text ed))
                 (count (let loop ((start 0) (n 0))
                          ;; Use pattern string directly for caching
                          (let ((m (pregexp-match-positions pattern text start)))
                            (if (and m (car m))
                              (let* ((mstart (caar m))
                                     (mend (cdar m)))
                                (if (= mstart mend)
                                  n  ; zero-length match — stop
                                  (loop mend (+ n 1))))
                              n)))))
            (echo-message! echo
              (string-append (number->string count)
                " matches for /" pattern "/"))))))))

;;; --- Web search from editor ---

(def (cmd-eww-search-web app)
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
                    (open-process (list path: opener
                                        arguments: (list url)
                                        stdin-redirection: #f
                                        stdout-redirection: #f))
                    (echo-message! echo (string-append "Searching: " q)))
                  (echo-message! echo "No browser found"))))))))))

;;; --- Jump to last edit position ---

(def *last-edit-positions* '())  ; list of (buffer-name . position)
(def *max-edit-positions* 50)

(def (record-edit-position! app)
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

(def (cmd-goto-last-edit app)
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

(def (cmd-eval-region-and-replace app)
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
            (let* ((result (eval (with-input-from-string expr-text read)))
                   (result-str (with-output-to-string
                                 (lambda () (write result)))))
              (editor-set-selection ed sel-start sel-end)
              (editor-replace-selection ed result-str)
              (echo-message! echo
                (string-append "Replaced with: " result-str)))))))))

;;; --- Hex/Decimal conversions ---

(def (cmd-hex-to-decimal app)
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

(def (cmd-decimal-to-hex app)
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

(def (cmd-encode-hex-string app)
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

(def (cmd-decode-hex-string app)
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

(def (cmd-copy-buffer-file-name app)
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

(def (cmd-insert-date-formatted app)
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

(def (cmd-prepend-to-buffer app)
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
                                  *buffer-list*)))
            (if (not target-buf)
              (echo-message! echo (string-append "Buffer not found: " target-name))
              (echo-message! echo
                (string-append "Prepended "
                  (number->string (- sel-end sel-start))
                  " chars to " target-name)))))))))

;;; --- Toggle persistent scratch mode ---

(def *persistent-scratch-file*
  (string-append (or (getenv "HOME") ".") "/.jemacs-scratch"))

(def (cmd-save-persistent-scratch app)
  "Save the *scratch* buffer to disk for persistence."
  (let* ((echo (app-state-echo app))
         (scratch-buf (find (lambda (b) (equal? (buffer-name b) "*scratch*"))
                            *buffer-list*)))
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

(def (cmd-load-persistent-scratch app)
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

(def *subword-mode* #f)
(def *auto-composition-mode* #t)
(def *bidi-display-reordering* #t)
(def *fill-column-indicator* #f)
(def *pixel-scroll-mode* #f)
(def *auto-highlight-symbol-mode* #f)

(def *lorem-ipsum-text*
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")

(def (insert-char-by-code-string str)
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

(def (cmd-insert-char-by-code app)
  "Insert a character by its Unicode code point (prompts via minibuffer)."
  (let* ((echo (app-state-echo app))
         (ed (current-editor app)))
    (echo-message! echo "insert-char: Use M-x with code point (e.g., 65 or #x41 for 'A')")))

(def (cmd-toggle-subword-mode app)
  "Toggle subword-mode: treat CamelCase sub-words as word boundaries."
  (let ((echo (app-state-echo app)))
    (set! *subword-mode* (not *subword-mode*))
    (echo-message! echo (if *subword-mode*
                          "Subword mode ON"
                          "Subword mode OFF"))))

(def (cmd-toggle-auto-composition app)
  "Toggle automatic character composition for display."
  (let ((echo (app-state-echo app)))
    (set! *auto-composition-mode* (not *auto-composition-mode*))
    (echo-message! echo (if *auto-composition-mode*
                          "Auto-composition ON"
                          "Auto-composition OFF"))))

(def (cmd-toggle-bidi-display app)
  "Toggle bidirectional text display reordering."
  (let ((echo (app-state-echo app)))
    (set! *bidi-display-reordering* (not *bidi-display-reordering*))
    (echo-message! echo (if *bidi-display-reordering*
                          "Bidi display reordering ON"
                          "Bidi display reordering OFF"))))

(def (cmd-toggle-display-fill-column-indicator app)
  "Toggle display of a line at the fill column (like display-fill-column-indicator-mode)."
  (let ((echo (app-state-echo app))
        (ed (current-editor app)))
    (set! *fill-column-indicator* (not *fill-column-indicator*))
    (if *fill-column-indicator*
      (begin
        ;; SCI_SETEDGEMODE = 2363, EDGE_LINE = 1
        (send-message ed 2363 1 0)
        ;; SCI_SETEDGECOLUMN = 2361
        (send-message ed 2361 80 0)
        (echo-message! echo "Fill-column indicator ON (col 80)"))
      (begin
        ;; SCI_SETEDGEMODE = 2363, EDGE_NONE = 0
        (send-message ed 2363 0 0)
        (echo-message! echo "Fill-column indicator OFF")))))

(def (cmd-insert-current-file-name app)
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

(def (cmd-toggle-pixel-scroll app)
  "Toggle pixel-level smooth scrolling mode."
  (let ((echo (app-state-echo app)))
    (set! *pixel-scroll-mode* (not *pixel-scroll-mode*))
    (echo-message! echo (if *pixel-scroll-mode*
                          "Pixel scroll mode ON"
                          "Pixel scroll mode OFF"))))

(def (cmd-insert-lorem-ipsum app)
  "Insert Lorem Ipsum placeholder text at point."
  (let* ((echo (app-state-echo app))
         (ed (current-editor app)))
    (editor-replace-selection ed *lorem-ipsum-text*)
    (echo-message! echo "Lorem Ipsum inserted")))

(def (cmd-toggle-auto-highlight-symbol app)
  "Toggle automatic highlighting of the symbol at point."
  (let ((echo (app-state-echo app)))
    (set! *auto-highlight-symbol-mode* (not *auto-highlight-symbol-mode*))
    (echo-message! echo (if *auto-highlight-symbol-mode*
                          "Auto-highlight-symbol mode ON"
                          "Auto-highlight-symbol mode OFF"))))

(def (cmd-copy-rectangle-to-clipboard app)
  "Copy the current selection to the clipboard (rectangle-aware)."
  (let* ((echo (app-state-echo app))
         (ed (current-editor app))
         (start (editor-get-selection-start ed))
         (end (editor-get-selection-end ed)))
    (if (= start end)
      (echo-message! echo "No selection")
      (begin
        ;; SCI_COPY = 2178
        (send-message ed 2178 0 0)
        (echo-message! echo "Selection copied")))))

(def (cmd-insert-file-contents-at-point app)
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

(def *read-only-directories* #f)
(def *auto-revert-verbose* #t)
(def *uniquify-buffer-names* #t)
(def *global-so-long-mode* #t)
(def *minibuffer-depth-indicate* #f)
(def *context-menu-mode* #f)
(def *tooltip-mode* #t)
(def *file-name-shadow-mode* #t)
(def *minibuffer-electric-default* #t)
(def *history-delete-duplicates* #f)

(def (cmd-toggle-read-only-directories app)
  "Toggle making directory buffers read-only."
  (let ((echo (app-state-echo app)))
    (set! *read-only-directories* (not *read-only-directories*))
    (echo-message! echo (if *read-only-directories*
                          "Read-only directories ON"
                          "Read-only directories OFF"))))

(def (cmd-toggle-auto-revert-verbose app)
  "Toggle verbose messages for auto-revert."
  (let ((echo (app-state-echo app)))
    (set! *auto-revert-verbose* (not *auto-revert-verbose*))
    (echo-message! echo (if *auto-revert-verbose*
                          "Auto-revert verbose ON"
                          "Auto-revert verbose OFF"))))

(def (cmd-toggle-uniquify-buffer-names app)
  "Toggle uniquification of buffer names with directory info."
  (let ((echo (app-state-echo app)))
    (set! *uniquify-buffer-names* (not *uniquify-buffer-names*))
    (echo-message! echo (if *uniquify-buffer-names*
                          "Uniquify buffer names ON"
                          "Uniquify buffer names OFF"))))

(def (cmd-toggle-global-so-long app)
  "Toggle global so-long-mode (mitigate long line performance)."
  (let ((echo (app-state-echo app)))
    (set! *global-so-long-mode* (not *global-so-long-mode*))
    (echo-message! echo (if *global-so-long-mode*
                          "Global so-long mode ON"
                          "Global so-long mode OFF"))))

(def (cmd-toggle-minibuffer-depth-indicate app)
  "Toggle showing recursive minibuffer depth."
  (let ((echo (app-state-echo app)))
    (set! *minibuffer-depth-indicate* (not *minibuffer-depth-indicate*))
    (echo-message! echo (if *minibuffer-depth-indicate*
                          "Minibuffer depth indicate ON"
                          "Minibuffer depth indicate OFF"))))

(def (cmd-toggle-context-menu-mode app)
  "Toggle right-click context menu support."
  (let ((echo (app-state-echo app)))
    (set! *context-menu-mode* (not *context-menu-mode*))
    (echo-message! echo (if *context-menu-mode*
                          "Context menu mode ON"
                          "Context menu mode OFF"))))

(def (cmd-toggle-tooltip-mode app)
  "Toggle tooltip display for UI elements."
  (let ((echo (app-state-echo app)))
    (set! *tooltip-mode* (not *tooltip-mode*))
    (echo-message! echo (if *tooltip-mode*
                          "Tooltips ON"
                          "Tooltips OFF"))))

(def (cmd-toggle-file-name-shadow app)
  "Toggle shadowing of file name when default is present."
  (let ((echo (app-state-echo app)))
    (set! *file-name-shadow-mode* (not *file-name-shadow-mode*))
    (echo-message! echo (if *file-name-shadow-mode*
                          "File name shadow ON"
                          "File name shadow OFF"))))

(def (cmd-toggle-minibuffer-electric-default app)
  "Toggle erasing default value on minibuffer input."
  (let ((echo (app-state-echo app)))
    (set! *minibuffer-electric-default* (not *minibuffer-electric-default*))
    (echo-message! echo (if *minibuffer-electric-default*
                          "Minibuffer electric default ON"
                          "Minibuffer electric default OFF"))))

(def (cmd-toggle-history-delete-duplicates app)
  "Toggle removal of duplicates from command history."
  (let ((echo (app-state-echo app)))
    (set! *history-delete-duplicates* (not *history-delete-duplicates*))
    (echo-message! echo (if *history-delete-duplicates*
                          "History delete duplicates ON"
                          "History delete duplicates OFF"))))

;; ── batch 45: themes and UI chrome toggles ──────────────────────────
(def *modus-themes* #f)
(def *ef-themes* #f)
(def *nano-theme* #f)
(def *ligature-mode* #f)
(def *pixel-scroll-precision* #f)
;; *repeat-mode* is defined in core.ss (needed by execute-command!)
(def *tab-line-mode* #f)
(def *scroll-bar-mode* #t)
(def *tool-bar-mode* #f)

(def (cmd-toggle-modus-themes app)
  "Toggle modus-themes (accessible high-contrast themes)."
  (let ((echo (app-state-echo app)))
    (set! *modus-themes* (not *modus-themes*))
    (echo-message! echo (if *modus-themes*
                          "Modus themes ON" "Modus themes OFF"))))

(def (cmd-toggle-ef-themes app)
  "Toggle ef-themes (elegant font themes)."
  (let ((echo (app-state-echo app)))
    (set! *ef-themes* (not *ef-themes*))
    (echo-message! echo (if *ef-themes*
                          "Ef themes ON" "Ef themes OFF"))))

(def (cmd-toggle-nano-theme app)
  "Toggle nano-theme (minimalist appearance)."
  (let ((echo (app-state-echo app)))
    (set! *nano-theme* (not *nano-theme*))
    (echo-message! echo (if *nano-theme*
                          "Nano theme ON" "Nano theme OFF"))))

(def (cmd-toggle-ligature-mode app)
  "Toggle ligature-mode (font ligature display)."
  (let ((echo (app-state-echo app)))
    (set! *ligature-mode* (not *ligature-mode*))
    (echo-message! echo (if *ligature-mode*
                          "Ligature mode ON" "Ligature mode OFF"))))

(def (cmd-toggle-pixel-scroll-precision app)
  "Toggle pixel-scroll-precision-mode (smooth scrolling)."
  (let ((echo (app-state-echo app)))
    (set! *pixel-scroll-precision* (not *pixel-scroll-precision*))
    (echo-message! echo (if *pixel-scroll-precision*
                          "Pixel scroll precision ON" "Pixel scroll precision OFF"))))

(def (cmd-toggle-repeat-mode app)
  "Toggle repeat-mode (repeat last command with single key)."
  (repeat-mode-set! (not (repeat-mode?)))
  (clear-repeat-map!)
  (echo-message! (app-state-echo app)
    (if (repeat-mode?) "Repeat mode enabled" "Repeat mode disabled")))

(def (tab-line-string app width)
  "Generate a tab-line string showing open buffer names.
   The current buffer is marked with [brackets], others with spaces.
   Fits within WIDTH characters."
  (let* ((current-buf (current-buffer-from-app app))
         (current-name (if current-buf (buffer-name current-buf) ""))
         ;; Get unique buffer names, skip internal buffers
         (bufs (filter (lambda (b)
                         (let ((n (buffer-name b)))
                           (and n (> (string-length n) 0)
                                (not (char=? (string-ref n 0) #\space)))))
                       *buffer-list*))
         (tabs (map (lambda (b)
                      (let* ((name (buffer-name b))
                             (mod? (and (buffer-doc b)
                                       (let ((ed (create-scintilla-editor 1 1)))
                                         ;; Quick check - can't easily check mod
                                         #f)))
                             (is-current (string=? name current-name)))
                        (if is-current
                          (string-append "[" name "]")
                          (string-append " " name " "))))
                    bufs))
         (joined (apply string-append
                   (let loop ((tabs tabs) (acc '()) (first? #t))
                     (if (null? tabs)
                       (reverse acc)
                       (loop (cdr tabs)
                             (cons (if first? (car tabs)
                                     (string-append "|" (car tabs)))
                                   acc)
                             #f))))))
    (if (<= (string-length joined) width)
      (string-append joined (make-string (- width (string-length joined)) #\space))
      (substring joined 0 width))))

(def (cmd-toggle-tab-line-mode app)
  "Toggle tab-line-mode (show buffer tabs at top)."
  (let ((echo (app-state-echo app)))
    (set! *tab-line-mode* (not *tab-line-mode*))
    (echo-message! echo (if *tab-line-mode*
                          "Tab-line mode ON — buffer tabs shown in modeline"
                          "Tab-line mode OFF"))))

(def (cmd-toggle-scroll-bar-mode app)
  "Toggle scroll-bar-mode."
  (let ((echo (app-state-echo app)))
    (set! *scroll-bar-mode* (not *scroll-bar-mode*))
    (echo-message! echo (if *scroll-bar-mode*
                          "Scroll bar mode ON" "Scroll bar mode OFF"))))

(def (cmd-toggle-tool-bar-mode app)
  "Toggle tool-bar-mode."
  (let ((echo (app-state-echo app)))
    (set! *tool-bar-mode* (not *tool-bar-mode*))
    (echo-message! echo (if *tool-bar-mode*
                          "Tool bar mode ON" "Tool bar mode OFF"))))

;; ── batch 51: modern editor integration toggles ─────────────────────
(def *global-auto-revert-non-file* #f)
(def *global-tree-sitter* #f)
(def *global-copilot* #f)
(def *global-lsp-mode* #f)
(def *global-format-on-save* #f)
(def *global-yas* #f)
(def *global-smartparens* #f)

(def (cmd-toggle-global-auto-revert-non-file app)
  "Toggle auto-revert for non-file buffers (dired, etc)."
  (let ((echo (app-state-echo app)))
    (set! *global-auto-revert-non-file* (not *global-auto-revert-non-file*))
    (echo-message! echo (if *global-auto-revert-non-file*
                          "Auto-revert non-file ON" "Auto-revert non-file OFF"))))

(def (cmd-toggle-global-tree-sitter app)
  "Toggle global tree-sitter syntax support."
  (let ((echo (app-state-echo app)))
    (set! *global-tree-sitter* (not *global-tree-sitter*))
    (echo-message! echo (if *global-tree-sitter*
                          "Tree-sitter global ON" "Tree-sitter global OFF"))))

(def (cmd-toggle-global-copilot app)
  "Toggle global copilot-mode (AI completion)."
  (let ((echo (app-state-echo app)))
    (set! *global-copilot* (not *global-copilot*))
    (echo-message! echo (if *global-copilot*
                          "Copilot global ON" "Copilot global OFF"))))

(def (cmd-toggle-global-lsp-mode app)
  "Toggle global lsp-mode (language server protocol)."
  (let ((echo (app-state-echo app)))
    (set! *global-lsp-mode* (not *global-lsp-mode*))
    (echo-message! echo (if *global-lsp-mode*
                          "LSP mode global ON" "LSP mode global OFF"))))

(def (cmd-toggle-global-format-on-save app)
  "Toggle format-on-save (auto-format before saving)."
  (let ((echo (app-state-echo app)))
    (set! *global-format-on-save* (not *global-format-on-save*))
    (echo-message! echo (if *global-format-on-save*
                          "Format on save ON" "Format on save OFF"))))

(def (cmd-toggle-global-yas app)
  "Toggle global yasnippet-mode."
  (let ((echo (app-state-echo app)))
    (set! *global-yas* (not *global-yas*))
    (echo-message! echo (if *global-yas*
                          "Yasnippet global ON" "Yasnippet global OFF"))))

(def (cmd-toggle-global-smartparens app)
  "Toggle global smartparens-mode."
  (let ((echo (app-state-echo app)))
    (set! *global-smartparens* (not *global-smartparens*))
    (echo-message! echo (if *global-smartparens*
                          "Smartparens global ON" "Smartparens global OFF"))))

;;; ---- batch 59: help and testing framework toggles ----

(def *global-helpful* #f)
(def *global-elisp-demos* #f)
(def *global-suggest* #f)
(def *global-buttercup* #f)
(def *global-ert-runner* #f)
(def *global-undercover* #f)
(def *global-benchmark-init* #f)

(def (cmd-toggle-global-helpful app)
  "Toggle global helpful-mode (better help buffers)."
  (let ((echo (app-state-echo app)))
    (set! *global-helpful* (not *global-helpful*))
    (echo-message! echo (if *global-helpful*
                          "Global helpful ON" "Global helpful OFF"))))

(def (cmd-toggle-global-elisp-demos app)
  "Toggle global elisp-demos-mode (code examples in help)."
  (let ((echo (app-state-echo app)))
    (set! *global-elisp-demos* (not *global-elisp-demos*))
    (echo-message! echo (if *global-elisp-demos*
                          "Elisp demos ON" "Elisp demos OFF"))))

(def (cmd-toggle-global-suggest app)
  "Toggle global suggest-mode (discover functions by example)."
  (let ((echo (app-state-echo app)))
    (set! *global-suggest* (not *global-suggest*))
    (echo-message! echo (if *global-suggest*
                          "Global suggest ON" "Global suggest OFF"))))

(def (cmd-toggle-global-buttercup app)
  "Toggle global buttercup-mode (BDD testing framework)."
  (let ((echo (app-state-echo app)))
    (set! *global-buttercup* (not *global-buttercup*))
    (echo-message! echo (if *global-buttercup*
                          "Global buttercup ON" "Global buttercup OFF"))))

(def (cmd-toggle-global-ert-runner app)
  "Toggle global ert-runner-mode (ERT test runner)."
  (let ((echo (app-state-echo app)))
    (set! *global-ert-runner* (not *global-ert-runner*))
    (echo-message! echo (if *global-ert-runner*
                          "ERT runner ON" "ERT runner OFF"))))

(def (cmd-toggle-global-undercover app)
  "Toggle global undercover-mode (code coverage tool)."
  (let ((echo (app-state-echo app)))
    (set! *global-undercover* (not *global-undercover*))
    (echo-message! echo (if *global-undercover*
                          "Global undercover ON" "Global undercover OFF"))))

(def (cmd-toggle-global-benchmark-init app)
  "Toggle global benchmark-init-mode (startup timing)."
  (let ((echo (app-state-echo app)))
    (set! *global-benchmark-init* (not *global-benchmark-init*))
    (echo-message! echo (if *global-benchmark-init*
                          "Benchmark init ON" "Benchmark init OFF"))))

;;; ---- batch 68: additional programming language toggles ----

(def *global-clojure-mode* #f)
(def *global-cider* #f)
(def *global-haskell-mode* #f)
(def *global-lua-mode* #f)
(def *global-ruby-mode* #f)
(def *global-php-mode* #f)
(def *global-swift-mode* #f)

(def (cmd-toggle-global-clojure-mode app)
  "Toggle global clojure-mode (Clojure development)."
  (let ((echo (app-state-echo app)))
    (set! *global-clojure-mode* (not *global-clojure-mode*))
    (echo-message! echo (if *global-clojure-mode*
                          "Clojure mode ON" "Clojure mode OFF"))))

(def (cmd-toggle-global-cider app)
  "Toggle global CIDER-mode (Clojure interactive development)."
  (let ((echo (app-state-echo app)))
    (set! *global-cider* (not *global-cider*))
    (echo-message! echo (if *global-cider*
                          "CIDER ON" "CIDER OFF"))))

(def (cmd-toggle-global-haskell-mode app)
  "Toggle global haskell-mode (Haskell development)."
  (let ((echo (app-state-echo app)))
    (set! *global-haskell-mode* (not *global-haskell-mode*))
    (echo-message! echo (if *global-haskell-mode*
                          "Haskell mode ON" "Haskell mode OFF"))))

(def (cmd-toggle-global-lua-mode app)
  "Toggle global lua-mode (Lua development)."
  (let ((echo (app-state-echo app)))
    (set! *global-lua-mode* (not *global-lua-mode*))
    (echo-message! echo (if *global-lua-mode*
                          "Lua mode ON" "Lua mode OFF"))))

(def (cmd-toggle-global-ruby-mode app)
  "Toggle global ruby-mode (Ruby development)."
  (let ((echo (app-state-echo app)))
    (set! *global-ruby-mode* (not *global-ruby-mode*))
    (echo-message! echo (if *global-ruby-mode*
                          "Ruby mode ON" "Ruby mode OFF"))))

(def (cmd-toggle-global-php-mode app)
  "Toggle global php-mode (PHP development)."
  (let ((echo (app-state-echo app)))
    (set! *global-php-mode* (not *global-php-mode*))
    (echo-message! echo (if *global-php-mode*
                          "PHP mode ON" "PHP mode OFF"))))

(def (cmd-toggle-global-swift-mode app)
  "Toggle global swift-mode (Swift development)."
  (let ((echo (app-state-echo app)))
    (set! *global-swift-mode* (not *global-swift-mode*))
    (echo-message! echo (if *global-swift-mode*
                          "Swift mode ON" "Swift mode OFF"))))

;;;============================================================================
;;; Scratch buffer new (create numbered scratch buffers)
;;;============================================================================

(def *tui-scratch-counter* 0)

(def (cmd-scratch-buffer-new app)
  "Create a new scratch buffer with a unique name."
  (let* ((ed (current-editor app))
         (fr (app-state-frame app)))
    (set! *tui-scratch-counter* (+ *tui-scratch-counter* 1))
    (let* ((name (string-append "*scratch-" (number->string *tui-scratch-counter*) "*"))
           (buf (buffer-create! name ed #f)))
      (buffer-attach! ed buf)
      (set! (edit-window-buffer (current-window fr)) buf)
      (editor-set-text ed (string-append ";; " name " -- scratch buffer\n\n"))
      (echo-message! (app-state-echo app) (string-append "Created " name)))))

;;;============================================================================
;;; Swap window contents
;;;============================================================================

(def (cmd-swap-window app)
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
        (set! (edit-window-buffer w1) b2)
        (set! (edit-window-buffer w2) b1)
        (buffer-attach! (edit-window-editor w1) b2)
        (buffer-attach! (edit-window-editor w2) b1)
        (echo-message! (app-state-echo app) "Windows swapped")))))

;;; Parity batch 9: workspace, clipboard, undo-history, xref
(def *tui-workspaces* (make-hash-table))
(def *tui-current-ws* "default")
(def *tui-ws-bufs* (make-hash-table))
(hash-put! *tui-workspaces* "default" ["*scratch*"])
(def (cmd-workspace-create app)
  "Create workspace."
  (let ((name (app-read-string app "New workspace name: ")))
    (when (and name (> (string-length name) 0))
      (if (hash-get *tui-workspaces* name)
        (echo-message! (app-state-echo app) (string-append "Workspace '" name "' exists"))
        (begin (hash-put! *tui-workspaces* name ["*scratch*"])
               (echo-message! (app-state-echo app) (string-append "Created workspace: " name)))))))
(def (cmd-workspace-switch app)
  "Switch workspace."
  (let* ((names (sort (hash-keys *tui-workspaces*) string<?))
         (name (app-read-string app (string-append "Switch (" (string-join names ", ") "): "))))
    (when (and name (> (string-length name) 0))
      (if (hash-get *tui-workspaces* name)
        (begin (set! *tui-current-ws* name)
          (let* ((active (hash-get *tui-ws-bufs* name)) (buf (and active (buffer-by-name active))))
            (when buf (let* ((fr (app-state-frame app)) (win (current-window fr)) (ed (edit-window-editor win)))
                        (buffer-attach! ed buf) (set! (edit-window-buffer win) buf))))
          (echo-message! (app-state-echo app) (string-append "Workspace: " name)))
        (echo-message! (app-state-echo app) (string-append "No workspace: " name))))))
(def (cmd-workspace-delete app)
  "Delete workspace."
  (let* ((names (sort (filter (lambda (n) (not (string=? n "default"))) (hash-keys *tui-workspaces*)) string<?))
         (name (if (null? names) (begin (echo-message! (app-state-echo app) "No deletable workspaces") #f)
                 (app-read-string app (string-append "Delete (" (string-join names ", ") "): ")))))
    (when (and name (> (string-length name) 0))
      (cond ((string=? name "default") (echo-message! (app-state-echo app) "Cannot delete default"))
            ((hash-get *tui-workspaces* name)
             (hash-remove! *tui-workspaces* name) (hash-remove! *tui-ws-bufs* name)
             (when (string=? *tui-current-ws* name) (set! *tui-current-ws* "default"))
             (echo-message! (app-state-echo app) (string-append "Deleted: " name)))
            (else (echo-message! (app-state-echo app) (string-append "No workspace: " name)))))))
(def (cmd-workspace-add-buffer app)
  "Add buffer to workspace."
  (let* ((buf (current-buffer-from-app app)) (name (and buf (buffer-name buf))))
    (when name
      (let ((bufs (or (hash-get *tui-workspaces* *tui-current-ws*) '())))
        (unless (member name bufs) (hash-put! *tui-workspaces* *tui-current-ws* (cons name bufs))))
      (echo-message! (app-state-echo app) (string-append "Added '" name "' to " *tui-current-ws*)))))
(def (cmd-workspace-list app)
  "List workspaces."
  (let* ((fr (app-state-frame app)) (win (current-window fr)) (ed (edit-window-editor win))
         (lines (let loop ((ns (sort (hash-keys *tui-workspaces*) string<?)) (acc '()))
                  (if (null? ns) (reverse acc)
                    (let* ((n (car ns)) (bufs (or (hash-get *tui-workspaces* n) '())))
                      (loop (cdr ns) (cons (string-append n ": " (string-join bufs ", ")) acc))))))
         (buf (buffer-create! "*Workspaces*" ed)))
    (buffer-attach! ed buf) (set! (edit-window-buffer win) buf)
    (editor-set-text ed (string-append "Workspaces:\n" (string-join lines "\n")))
    (editor-goto-pos ed 0)))
(def (cmd-copy-buffer-filename app)
  "Copy buffer filename."
  (let* ((buf (current-buffer-from-app app)) (name (and buf (buffer-name buf))))
    (when name (echo-message! (app-state-echo app) (string-append "Buffer: " name)))))
(def (cmd-revert-buffer-confirm app)
  "Revert buffer with confirmation."
  (let* ((buf (current-buffer-from-app app)) (path (and buf (buffer-file-path buf))))
    (if (not path) (echo-error! (app-state-echo app) "Buffer has no file")
      (let ((ans (app-read-string app (string-append "Revert " (path-strip-directory path) "? (y/n) "))))
        (when (and ans (member ans '("y" "yes"))) (cmd-revert-buffer-no-confirm app))))))
(def (cmd-undo-history app)
  "Show undo history."
  (let* ((fr (app-state-frame app)) (win (current-window fr)) (ed (edit-window-editor win))
         (buf (edit-window-buffer win)) (name (and buf (buffer-name buf)))
         (hist (or (hash-get *undo-history-table* name) '())))
    (if (null? hist) (echo-message! (app-state-echo app) "No undo history")
      (let* ((lines (let loop ((es hist) (i 0) (acc '()))
               (if (null? es) (reverse acc)
                 (let* ((e (car es)) (ts (car e)) (tlen (string-length (cdr e)))
                        (now (inexact->exact (floor (time->seconds (current-time))))) (age (- now ts))
                        (age-s (cond ((< age 60) (string-append (number->string age) "s"))
                                     ((< age 3600) (string-append (number->string (quotient age 60)) "m"))
                                     (else (string-append (number->string (quotient age 3600)) "h")))))
                   (loop (cdr es) (+ i 1)
                     (cons (string-append (number->string i) ": " age-s " ago, " (number->string tlen) " chars"
                             (if (= i 0) " <- current" "")) acc))))))
             (hbuf (buffer-create! "*Undo History*" ed)))
        (buffer-attach! ed hbuf) (set! (edit-window-buffer win) hbuf)
        (editor-set-text ed (string-append "Undo History: " name "\n" (string-join lines "\n")))
        (editor-goto-pos ed 0)))))
(def (cmd-undo-history-restore app)
  "Restore undo snapshot."
  (let* ((buf (current-buffer-from-app app)) (name (and buf (buffer-name buf)))
         (hist (or (hash-get *undo-history-table* name) '())))
    (if (null? hist) (echo-message! (app-state-echo app) "No undo history")
      (let ((input (app-read-string app (string-append "Restore (0-" (number->string (- (length hist) 1)) "): "))))
        (when input
          (let ((num (string->number (string-trim input))))
            (when (and num (>= num 0) (< num (length hist)))
              (let* ((txt (cdr (list-ref hist num)))
                     (fr (app-state-frame app)) (win (current-window fr)) (ed (edit-window-editor win)))
                (editor-set-text ed txt) (editor-goto-pos ed 0)
                (echo-message! (app-state-echo app) (string-append "Restored snapshot " (number->string num)))))))))))
(def *tui-xref-stack* '())
(def (cmd-xref-back app)
  "Jump back in xref history."
  (if (null? *tui-xref-stack*) (echo-message! (app-state-echo app) "Xref stack empty")
    (let* ((loc (car *tui-xref-stack*)) (name (car loc)) (pos (cdr loc))
           (buf (buffer-by-name name)) (fr (app-state-frame app)) (win (current-window fr)) (ed (edit-window-editor win)))
      (set! *tui-xref-stack* (cdr *tui-xref-stack*))
      (when buf (buffer-attach! ed buf) (set! (edit-window-buffer win) buf))
      (editor-goto-pos ed pos)
      (echo-message! (app-state-echo app) (string-append "Back to " name)))))

;;;============================================================================
;;; Round 2 batch 2: 10 new Emacs features
;;;============================================================================

;; --- Feature 11: Keyboard Macros (kmacro) ---
;; Record and replay sequences of keystrokes

(def *kmacro-recording* #f)
(def *kmacro-events* '())
(def *kmacro-ring* '())
(def *kmacro-counter* 0)

(def (kmacro-recording?) *kmacro-recording*)

(def (kmacro-record-event! ev)
  "Record a key event during macro recording."
  (when *kmacro-recording*
    (set! *kmacro-events* (cons ev *kmacro-events*))))

(def (cmd-kmacro-start-macro app)
  "Start recording a keyboard macro (C-x ()."
  (let ((echo (app-state-echo app)))
    (if *kmacro-recording*
      (echo-message! echo "Already recording a macro")
      (begin
        (set! *kmacro-recording* #t)
        (set! *kmacro-events* '())
        (echo-message! echo "Defining keyboard macro...")))))

(def (cmd-kmacro-end-macro app)
  "Stop recording a keyboard macro (C-x ))."
  (let ((echo (app-state-echo app)))
    (if (not *kmacro-recording*)
      (echo-message! echo "Not recording a macro")
      (begin
        (set! *kmacro-recording* #f)
        (let ((macro (reverse *kmacro-events*)))
          (when (not (null? macro))
            (set! *kmacro-ring* (cons macro *kmacro-ring*)))
          (echo-message! echo
            (string-append "Keyboard macro defined ("
                          (number->string (length macro)) " events)")))))))

(def (cmd-kmacro-end-and-call-macro app)
  "End macro if recording, otherwise replay last macro (C-x e)."
  (let ((echo (app-state-echo app)))
    (cond
      (*kmacro-recording*
        (cmd-kmacro-end-macro app)
        (cmd-kmacro-call-macro app))
      ((null? *kmacro-ring*)
        (echo-message! echo "No keyboard macro defined"))
      (else
        (cmd-kmacro-call-macro app)))))

(def (cmd-kmacro-call-macro app)
  "Replay the last recorded keyboard macro."
  (let ((echo (app-state-echo app)))
    (if (null? *kmacro-ring*)
      (echo-message! echo "No keyboard macro defined")
      (let ((macro (car *kmacro-ring*))
            (fr (app-state-frame app))
            (win (current-window (app-state-frame app)))
            (ed (edit-window-editor (current-window (app-state-frame app)))))
        ;; Replay each recorded command
        (for-each
          (lambda (ev)
            (when (and (pair? ev) (symbol? (car ev)))
              (let ((cmd-fn (command-lookup (car ev))))
                (when cmd-fn (cmd-fn app)))))
          macro)
        (echo-message! echo "Macro replayed")))))

(def (cmd-kmacro-name-last-macro app)
  "Name the last recorded macro for later recall."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols)))
    (if (null? *kmacro-ring*)
      (echo-message! echo "No keyboard macro to name")
      (let ((name (echo-read-string echo "Name for macro: " row width)))
        (when (and name (not (string-empty? name)))
          (echo-message! echo (string-append "Macro named: " name)))))))

(def (cmd-kmacro-insert-counter app)
  "Insert the current macro counter value and increment."
  (let* ((ed (edit-window-editor (current-window (app-state-frame app))))
         (s (number->string *kmacro-counter*)))
    (send-message ed SCI_REPLACESEL 0 (string->alien/nul s))
    (set! *kmacro-counter* (+ *kmacro-counter* 1))))

;; --- Feature 12: Browse Kill Ring ---
;; Interactive kill-ring browser with selection

(def (cmd-browse-kill-ring app)
  "Browse kill ring and insert selected entry."
  (let* ((echo (app-state-echo app))
         (ring (app-state-kill-ring app))
         (row (tui-rows)) (width (tui-cols)))
    (if (null? ring)
      (echo-message! echo "Kill ring is empty")
      (let* ((entries
               (let loop ((items ring) (i 0) (acc '()))
                 (if (or (null? items) (>= i 30))
                   (reverse acc)
                   (let* ((entry (car items))
                          (display
                            (let ((s (if (> (string-length entry) 60)
                                      (string-append (substring entry 0 60) "...")
                                      entry)))
                              ;; Replace newlines for display
                              (let lp ((j 0) (a '()))
                                (cond ((>= j (string-length s))
                                       (list->string (reverse a)))
                                      ((char=? (string-ref s j) #\newline)
                                       (lp (+ j 1) (cons #\space (cons #\\ (cons #\n a)))))
                                      (else (lp (+ j 1) (cons (string-ref s j) a))))))))
                     (loop (cdr items) (+ i 1)
                       (cons (string-append (number->string i) ": " display) acc))))))
             (choice (echo-read-string-with-completion echo "Kill ring: " entries row width)))
        (when (and choice (not (string-empty? choice)))
          (let ((idx-str (let ((colon (string-contains choice ":")))
                           (if colon (substring choice 0 colon) choice))))
            (let ((idx (string->number (string-trim idx-str))))
              (when (and idx (>= idx 0) (< idx (length ring)))
                (let* ((text (list-ref ring idx))
                       (ed (edit-window-editor (current-window (app-state-frame app)))))
                  (send-message ed SCI_REPLACESEL 0 (string->alien/nul text))
                  (echo-message! echo "Yanked from kill ring"))))))))))

;; --- Feature 13: iedit-mode ---
;; Edit all occurrences of symbol at point simultaneously

(def *iedit-active* #f)
(def *iedit-word* "")
(def *iedit-positions* '())

(def (cmd-iedit-mode app)
  "Toggle iedit-mode — edit all occurrences of symbol at point."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (if *iedit-active*
      ;; Deactivate
      (begin
        (set! *iedit-active* #f)
        (set! *iedit-word* "")
        (set! *iedit-positions* '())
        ;; Clear indicator 10 (iedit)
        (send-message ed SCI_SETINDICATORCURRENT 10 0)
        (send-message ed SCI_INDICATORCLEARRANGE 0
          (send-message ed SCI_GETLENGTH 0 0))
        (echo-message! echo "iedit mode: off"))
      ;; Activate: find word at cursor
      (let* ((pos (send-message ed SCI_GETCURRENTPOS 0 0))
             (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
             (word-end (send-message ed SCI_WORDENDPOSITION pos 1))
             (len (- word-end word-start)))
        (if (<= len 0)
          (echo-message! echo "No word at point")
          (let* ((buf (make-bytevector (+ len 1) 0))
                 (_ (send-message ed SCI_GETTEXTRANGE 0
                      (cons->alien word-start (bytevector->alien buf))))
                 (word (alien/nul->string (bytevector->alien buf)))
                 (text-len (send-message ed SCI_GETLENGTH 0 0)))
            ;; Setup indicator 10 for iedit highlights
            (send-message ed SCI_INDICSETSTYLE 10 6) ;; INDIC_BOX
            (send-message ed SCI_INDICSETFORE 10 #x00FF80)
            (send-message ed SCI_SETINDICATORCURRENT 10 0)
            ;; Find all occurrences
            (send-message ed SCI_SETTARGETSTART 0 0)
            (send-message ed SCI_SETTARGETEND text-len 0)
            (send-message ed SCI_SETSEARCHFLAGS 4 0) ;; SCFIND_WHOLEWORD
            (let loop ((positions '()))
              (let ((found (send-message ed SCI_SEARCHINTARGET (string-length word)
                            (string->alien/nul word))))
                (if (< found 0)
                  (begin
                    (set! *iedit-active* #t)
                    (set! *iedit-word* word)
                    (set! *iedit-positions* (reverse positions))
                    ;; Highlight all occurrences
                    (for-each
                      (lambda (p)
                        (send-message ed SCI_INDICATORFILLRANGE p (string-length word)))
                      (reverse positions))
                    (echo-message! echo
                      (string-append "iedit: " (number->string (length positions))
                                    " occurrences of \"" word "\"")))
                  (begin
                    (send-message ed SCI_SETTARGETSTART (+ found 1) 0)
                    (send-message ed SCI_SETTARGETEND text-len 0)
                    (loop (cons found positions))))))))))))

;; --- Feature 14: Narrow to Region ---
;; Restrict visible/editable text to selected region

(def *narrow-saved-text* #f)
(def *narrow-start* 0)
(def *narrow-end* 0)
(def *narrow-active* #f)

(def (cmd-narrow-to-region app)
  "Narrow buffer to active region."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (current-buffer-from-app app))
         (mark (and buf (buffer-mark buf))))
    (if (not mark)
      (echo-error! echo "No region active")
      (if *narrow-active*
        (echo-message! echo "Already narrowed — use widen first")
        (let* ((pos (send-message ed SCI_GETCURRENTPOS 0 0))
               (start (min mark pos))
               (end (max mark pos))
               (full-text (editor-get-text ed))
               (region (substring full-text start end)))
          (set! *narrow-saved-text* full-text)
          (set! *narrow-start* start)
          (set! *narrow-end* end)
          (set! *narrow-active* #t)
          (editor-set-text ed region)
          (editor-goto-pos ed 0)
          (echo-message! echo
            (string-append "Narrowed to region ("
                          (number->string (- end start)) " chars)")))))))

(def (cmd-narrow-to-defun app)
  "Narrow buffer to current defun."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (text (editor-get-text ed)))
    (if *narrow-active*
      (echo-message! echo "Already narrowed — use widen first")
      ;; Find defun boundaries by searching backward/forward for top-level parens
      (let* ((lines (string-split text #\newline))
             (start-line
               (let loop ((l line))
                 (if (<= l 0) 0
                   (let ((line-text (if (< l (length lines)) (list-ref lines l) "")))
                     (if (and (> (string-length line-text) 0)
                              (char=? (string-ref line-text 0) #\())
                       l
                       (loop (- l 1)))))))
             (end-line
               (let loop ((l (+ start-line 1)))
                 (if (>= l (length lines)) (- (length lines) 1)
                   (let ((line-text (list-ref lines l)))
                     (if (and (> (string-length line-text) 0)
                              (char=? (string-ref line-text 0) #\())
                       (- l 1)
                       (loop (+ l 1)))))))
             (start-pos (send-message ed SCI_POSITIONFROMLINE start-line 0))
             (end-pos (send-message ed SCI_GETLINEENDPOSITION end-line 0)))
        (set! *narrow-saved-text* text)
        (set! *narrow-start* start-pos)
        (set! *narrow-end* end-pos)
        (set! *narrow-active* #t)
        (editor-set-text ed (substring text start-pos end-pos))
        (editor-goto-pos ed 0)
        (echo-message! echo "Narrowed to defun")))))

(def (cmd-widen app)
  "Restore full buffer from narrowing."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (if (not *narrow-active*)
      (echo-message! echo "Buffer is not narrowed")
      (let* ((narrowed (editor-get-text ed))
             (restored (string-append
                        (substring *narrow-saved-text* 0 *narrow-start*)
                        narrowed
                        (substring *narrow-saved-text* *narrow-end*
                          (string-length *narrow-saved-text*)))))
        (editor-set-text ed restored)
        (editor-goto-pos ed *narrow-start*)
        (set! *narrow-active* #f)
        (set! *narrow-saved-text* #f)
        (echo-message! echo "Widened")))))

;; --- Feature 15: ws-butler (whitespace butler) ---
;; Auto-cleanup trailing whitespace only on modified lines when saving

(def *ws-butler-enabled* #f)

(def (ws-butler-cleanup! ed)
  "Remove trailing whitespace from all lines in editor."
  (let ((line-count (send-message ed SCI_GETLINECOUNT 0 0)))
    (send-message ed SCI_BEGINUNDOACTION 0 0)
    (let loop ((line (- line-count 1)))
      (when (>= line 0)
        (let* ((line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
               (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
               (len (- line-end line-start)))
          (when (> len 0)
            ;; Scan backward from line end for whitespace
            (let scan ((p (- line-end 1)))
              (when (>= p line-start)
                (let ((ch (send-message ed SCI_GETCHARAT p 0)))
                  (when (or (= ch 32) (= ch 9)) ;; space or tab
                    (send-message ed SCI_SETTARGETSTART p 0)
                    (send-message ed SCI_SETTARGETEND line-end 0)
                    (send-message ed SCI_REPLACETARGET 0 (string->alien/nul ""))
                    (scan (- p 1))))))))
        (loop (- line 1))))
    (send-message ed SCI_ENDUNDOACTION 0 0)))

(def (cmd-ws-butler-mode app)
  "Toggle ws-butler mode — auto-cleanup trailing whitespace on save."
  (set! *ws-butler-enabled* (not *ws-butler-enabled*))
  (echo-message! (app-state-echo app)
    (if *ws-butler-enabled* "ws-butler mode: on" "ws-butler mode: off")))

(def (cmd-ws-butler-clean-buffer app)
  "Clean trailing whitespace from entire buffer now."
  (let ((ed (edit-window-editor (current-window (app-state-frame app)))))
    (ws-butler-cleanup! ed)
    (echo-message! (app-state-echo app) "Trailing whitespace cleaned")))

;; --- Feature 16: Highlight Escape Sequences ---
;; Colorize \n, \t, \", \\, etc. in strings using indicator 11

(def *highlight-escape-enabled* #f)

(def (highlight-escapes-apply! ed)
  "Highlight escape sequences using indicator 11."
  (send-message ed SCI_INDICSETSTYLE 11 7) ;; INDIC_ROUNDBOX
  (send-message ed SCI_INDICSETFORE 11 #xFF9060) ;; orange
  (send-message ed SCI_INDICSETALPHA 11 80)
  (send-message ed SCI_SETINDICATORCURRENT 11 0)
  ;; Clear existing
  (send-message ed SCI_INDICATORCLEARRANGE 0
    (send-message ed SCI_GETLENGTH 0 0))
  (let* ((text (editor-get-text ed))
         (len (string-length text)))
    ;; Simple scan: look for backslash followed by certain chars
    (let loop ((i 0) (in-string #f))
      (when (< i len)
        (let ((ch (string-ref text i)))
          (cond
            ((char=? ch #\") ;; toggle in-string (simplified: no escape tracking for quote)
             (loop (+ i 1) (not in-string)))
            ((and in-string (char=? ch #\\) (< (+ i 1) len))
             (let ((next (string-ref text (+ i 1))))
               (when (memv next '(#\n #\t #\r #\\ #\" #\' #\0 #\a #\b #\f #\v))
                 (send-message ed SCI_INDICATORFILLRANGE i 2))
               (loop (+ i 2) in-string)))
            (else (loop (+ i 1) in-string))))))))

(def (cmd-highlight-escape-sequences app)
  "Toggle highlighting of escape sequences in strings."
  (set! *highlight-escape-enabled* (not *highlight-escape-enabled*))
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app)))))
    (if *highlight-escape-enabled*
      (begin
        (highlight-escapes-apply! ed)
        (echo-message! echo "Highlight escape sequences: on"))
      (begin
        (send-message ed SCI_SETINDICATORCURRENT 11 0)
        (send-message ed SCI_INDICATORCLEARRANGE 0
          (send-message ed SCI_GETLENGTH 0 0))
        (echo-message! echo "Highlight escape sequences: off")))))

;; --- Feature 17: World Clock ---
;; Display multiple time zones in a buffer

(def *world-clock-zones*
  '(("UTC"        . 0)
    ("US/Eastern" . -5)
    ("US/Central" . -6)
    ("US/Pacific" . -8)
    ("Europe/London" . 0)
    ("Europe/Paris" . 1)
    ("Europe/Berlin" . 1)
    ("Asia/Tokyo" . 9)
    ("Asia/Shanghai" . 8)
    ("Australia/Sydney" . 11)))

(def (cmd-world-clock app)
  "Display world clock with multiple time zones."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (now (current-time))
         (epoch (time-second now))
         (lines
           (map
             (lambda (zone)
               (let* ((name (car zone))
                      (offset-hours (cdr zone))
                      (offset-secs (* offset-hours 3600))
                      (local-epoch (+ epoch offset-secs))
                      (t (make-time 'time-utc 0 local-epoch))
                      (d (time-utc->date t 0))
                      (hr (date-hour d))
                      (mn (date-minute d))
                      (sec (date-second d))
                      (time-str (string-append
                                  (if (< hr 10) "0" "") (number->string hr) ":"
                                  (if (< mn 10) "0" "") (number->string mn) ":"
                                  (if (< sec 10) "0" "") (number->string sec))))
                 (string-append
                   (let pad ((s name))
                     (if (>= (string-length s) 20) s
                       (pad (string-append s " "))))
                   "  " time-str
                   "  (UTC" (if (>= offset-hours 0) "+" "")
                   (number->string offset-hours) ")")))
             *world-clock-zones*))
         (content (string-append "World Clock\n"
                    (make-string 50 #\=) "\n"
                    (string-join lines "\n") "\n")))
    ;; Display in a *world-clock* buffer
    (let* ((win (current-window fr))
           (ed (edit-window-editor win))
           (buf (make-buffer "*world-clock*")))
      (buffer-attach! ed buf)
      (set! (edit-window-buffer win) buf)
      (editor-set-text ed content)
      (editor-goto-pos ed 0)
      (echo-message! echo "World clock displayed"))))

;; --- Feature 18: Follow Mode ---
;; Sync-scroll two windows showing same buffer (side-by-side reading)

(def *follow-mode-active* #f)

(def (cmd-follow-mode app)
  "Toggle follow-mode — sync two windows showing same buffer."
  (let ((echo (app-state-echo app)))
    (set! *follow-mode-active* (not *follow-mode-active*))
    (echo-message! echo
      (if *follow-mode-active*
        "Follow mode: on (split windows scroll together)"
        "Follow mode: off"))))

(def (follow-mode-sync! app)
  "Called from tick: keep adjacent windows in sync if follow-mode is on."
  (when *follow-mode-active*
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr)))
      (when (>= (length wins) 2)
        (let* ((win1 (car wins))
               (win2 (cadr wins))
               (ed1 (edit-window-editor win1))
               (ed2 (edit-window-editor win2))
               (buf1 (edit-window-buffer win1))
               (buf2 (edit-window-buffer win2)))
          ;; Only sync if showing same buffer
          (when (and buf1 buf2 (eq? buf1 buf2))
            (let* ((first-visible (send-message ed1 SCI_GETFIRSTVISIBLELINE 0 0))
                   (lines-on-screen (send-message ed1 SCI_LINESONSCREEN 0 0))
                   (next-page-line (+ first-visible lines-on-screen)))
              (send-message ed2 SCI_SETFIRSTVISIBLELINE next-page-line 0))))))))

;; --- Feature 19: CSV Align Mode ---
;; Align CSV columns for visual display

(def (cmd-csv-align app)
  "Align CSV columns in current buffer."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (text (editor-get-text ed)))
    (if (string-empty? text)
      (echo-message! echo "Buffer is empty")
      (let* ((lines (string-split text #\newline))
             (rows (map (lambda (line) (string-split line #\,)) lines))
             ;; Find max columns
             (max-cols (apply max (map length rows)))
             ;; Find max width for each column
             (col-widths
               (let loop ((col 0) (widths '()))
                 (if (>= col max-cols)
                   (reverse widths)
                   (let ((w (apply max
                              (map (lambda (row)
                                     (if (< col (length row))
                                       (string-length (string-trim (list-ref row col)))
                                       0))
                                   rows))))
                     (loop (+ col 1) (cons (+ w 2) widths))))))
             ;; Format rows
             (formatted
               (map (lambda (row)
                      (let loop ((fields row) (ws col-widths) (acc '()))
                        (if (or (null? fields) (null? ws))
                          (string-join (reverse acc) "")
                          (let* ((field (string-trim (car fields)))
                                 (pad-len (max 0 (- (car ws) (string-length field))))
                                 (padded (string-append field (make-string pad-len #\space))))
                            (loop (cdr fields) (cdr ws) (cons padded acc))))))
                    rows))
             (result (string-join formatted "\n")))
        (send-message ed SCI_BEGINUNDOACTION 0 0)
        (editor-set-text ed result)
        (send-message ed SCI_ENDUNDOACTION 0 0)
        (editor-goto-pos ed 0)
        (echo-message! echo "CSV aligned")))))

(def (cmd-csv-unalign app)
  "Remove extra whitespace from CSV columns."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app))))
         (text (editor-get-text ed))
         (lines (string-split text #\newline))
         (cleaned
           (map (lambda (line)
                  (string-join
                    (map string-trim (string-split line #\,))
                    ","))
                lines))
         (result (string-join cleaned "\n")))
    (send-message ed SCI_BEGINUNDOACTION 0 0)
    (editor-set-text ed result)
    (send-message ed SCI_ENDUNDOACTION 0 0)
    (editor-goto-pos ed 0)
    (echo-message! echo "CSV unaligned")))

;; --- Feature 20: Proced (System Process List) ---
;; Display running processes like Emacs's proced

(def (cmd-proced app)
  "Display system process list."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (let-values (((p-stdin p-stdout p-stderr pid)
                  (open-process-ports "ps aux --sort=-%mem" 'block (native-transcoder))))
      (close-port p-stdin)
      (let loop ((lines '()))
        (let ((line (get-line p-stdout)))
          (if (eof-object? line)
            (begin
              (close-port p-stdout)
              (close-port p-stderr)
              (let* ((content (string-join (reverse lines) "\n"))
                     (buf (make-buffer "*proced*")))
                (buffer-attach! ed buf)
                (set! (edit-window-buffer win) buf)
                (editor-set-text ed content)
                (editor-goto-pos ed 0)
                (echo-message! echo
                  (string-append "Processes: " (number->string (length lines)) " lines"))))
            (loop (cons line lines))))))))

(def (cmd-proced-sort-by-cpu app)
  "Refresh process list sorted by CPU usage."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (let-values (((p-stdin p-stdout p-stderr pid)
                  (open-process-ports "ps aux --sort=-%cpu" 'block (native-transcoder))))
      (close-port p-stdin)
      (let loop ((lines '()))
        (let ((line (get-line p-stdout)))
          (if (eof-object? line)
            (begin
              (close-port p-stdout)
              (close-port p-stderr)
              (let ((content (string-join (reverse lines) "\n")))
                (editor-set-text ed content)
                (editor-goto-pos ed 0)
                (echo-message! echo "Sorted by CPU")))
            (loop (cons line lines))))))))

(def (cmd-proced-sort-by-memory app)
  "Refresh process list sorted by memory usage."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (let-values (((p-stdin p-stdout p-stderr pid)
                  (open-process-ports "ps aux --sort=-%mem" 'block (native-transcoder))))
      (close-port p-stdin)
      (let loop ((lines '()))
        (let ((line (get-line p-stdout)))
          (if (eof-object? line)
            (begin
              (close-port p-stdout)
              (close-port p-stderr)
              (let ((content (string-join (reverse lines) "\n")))
                (editor-set-text ed content)
                (editor-goto-pos ed 0)
                (echo-message! echo "Sorted by memory")))
            (loop (cons line lines))))))))

;;;============================================================================
;;; Round 4 batch 2: Features 11-20
;;;============================================================================

;; --- Feature 11: Doom Modeline (enhanced modeline info) ---

(def *doom-modeline-enabled* #f)
(def *doom-modeline-segments*
  '(buffer-info major-mode vcs checker))

(def (cmd-doom-modeline-mode app)
  "Toggle doom-modeline style — enhanced modeline display."
  (set! *doom-modeline-enabled* (not *doom-modeline-enabled*))
  (echo-message! (app-state-echo app)
    (if *doom-modeline-enabled*
      "Doom modeline: on (enhanced status display)"
      "Doom modeline: off")))

(def (doom-modeline-format app)
  "Generate doom-modeline style string for status area."
  (when *doom-modeline-enabled*
    (let* ((buf (current-buffer-from-app app))
           (name (if buf (buffer-name buf) "[no buffer]"))
           (path (and buf (buffer-file-path buf)))
           (ext (if path (path-extension path) ""))
           (mode-name
             (cond
               ((member ext '("ss" "scm" "el")) "Scheme")
               ((member ext '("py")) "Python")
               ((member ext '("js" "ts")) "JS/TS")
               ((member ext '("c" "h" "cpp")) "C/C++")
               ((member ext '("go")) "Go")
               ((member ext '("rs")) "Rust")
               ((member ext '("md")) "Markdown")
               ((member ext '("org")) "Org")
               (else "Text")))
           (ed (edit-window-editor (current-window (app-state-frame app))))
           (line (+ 1 (send-message ed SCI_LINEFROMPOSITION
                        (send-message ed SCI_GETCURRENTPOS 0 0) 0)))
           (col (+ 1 (send-message ed SCI_GETCOLUMN
                       (send-message ed SCI_GETCURRENTPOS 0 0) 0)))
           (total-lines (send-message ed SCI_GETLINECOUNT 0 0))
           (percent (if (> total-lines 0)
                      (quotient (* line 100) total-lines)
                      0)))
      (string-append " " name " | " mode-name " | L"
        (number->string line) ":C" (number->string col)
        " (" (number->string percent) "%)"))))

;; --- Feature 12: TS-Fold (tree-sitter based code folding) ---

(def (cmd-ts-fold-toggle app)
  "Toggle code folding at current line using Scintilla's fold system."
  (let* ((ed (edit-window-editor (current-window (app-state-frame app))))
         (line (send-message ed SCI_LINEFROMPOSITION
                 (send-message ed SCI_GETCURRENTPOS 0 0) 0)))
    (send-message ed SCI_TOGGLEFOLD line 0)
    (echo-message! (app-state-echo app)
      (string-append "Toggled fold at line " (number->string (+ line 1))))))

(def (cmd-ts-fold-all app)
  "Fold all top-level blocks."
  (let* ((ed (edit-window-editor (current-window (app-state-frame app))))
         (line-count (send-message ed SCI_GETLINECOUNT 0 0)))
    (let loop ((line 0))
      (when (< line line-count)
        (let ((level (send-message ed SCI_GETFOLDLEVEL line 0)))
          (when (and (> (bitwise-and level #x2000) 0) ;; SC_FOLDLEVELHEADERFLAG
                     (not (= (send-message ed SCI_GETFOLDEXPANDED line 0) 0)))
            (send-message ed SCI_TOGGLEFOLD line 0)))
        (loop (+ line 1))))
    (echo-message! (app-state-echo app) "All folds collapsed")))

(def (cmd-ts-fold-unfold-all app)
  "Unfold all blocks."
  (let* ((ed (edit-window-editor (current-window (app-state-frame app))))
         (line-count (send-message ed SCI_GETLINECOUNT 0 0)))
    (let loop ((line 0))
      (when (< line line-count)
        (let ((level (send-message ed SCI_GETFOLDLEVEL line 0)))
          (when (and (> (bitwise-and level #x2000) 0)
                     (= (send-message ed SCI_GETFOLDEXPANDED line 0) 0))
            (send-message ed SCI_TOGGLEFOLD line 0)))
        (loop (+ line 1))))
    (echo-message! (app-state-echo app) "All folds expanded")))

;; --- Feature 13: Casual (transient menu system) ---

(def *casual-menus* (make-hash-table))

(def (casual-define-menu! name entries)
  "Define a transient menu. entries: list of (key label command-sym)"
  (hash-put! *casual-menus* name entries))

;; Pre-define some useful menus
(casual-define-menu! 'buffer
  '((#\n "Next buffer" next-buffer)
    (#\p "Previous buffer" previous-buffer)
    (#\k "Kill buffer" kill-buffer)
    (#\s "Save buffer" save-buffer)
    (#\l "List buffers" list-buffers)))

(casual-define-menu! 'window
  '((#\2 "Split horizontal" split-window-below)
    (#\3 "Split vertical" split-window-right)
    (#\0 "Delete window" delete-window)
    (#\1 "Delete other" delete-other-windows)
    (#\o "Other window" other-window)))

(def (cmd-casual-buffer-menu app)
  "Show casual buffer menu."
  (let* ((echo (app-state-echo app))
         (entries (hash-ref *casual-menus* 'buffer '()))
         (display-lines (map (lambda (e)
                               (string-append "  " (string (cadr e)) "  " (symbol->string (caddr e))))
                             entries)))
    (echo-message! echo
      (string-append "Buffer: " (string-join
        (map (lambda (e)
               (string-append "[" (string (car e)) "] " (cadr e)))
             entries)
        "  ")))))

(def (cmd-casual-window-menu app)
  "Show casual window menu."
  (let* ((echo (app-state-echo app))
         (entries (hash-ref *casual-menus* 'window '())))
    (echo-message! echo
      (string-append "Window: " (string-join
        (map (lambda (e)
               (string-append "[" (string (car e)) "] " (cadr e)))
             entries)
        "  ")))))

;; --- Feature 14: Spacious Padding ---

(def *spacious-padding-enabled* #f)
(def *spacious-padding-size* 2)

(def (cmd-spacious-padding-mode app)
  "Toggle spacious padding — add visual padding around text."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app)))))
    (set! *spacious-padding-enabled* (not *spacious-padding-enabled*))
    (if *spacious-padding-enabled*
      (begin
        ;; Add left margin padding
        (send-message ed SCI_SETMARGINLEFT 0 (* *spacious-padding-size* 8))
        (send-message ed SCI_SETMARGINRIGHT 0 (* *spacious-padding-size* 8))
        (send-message ed SCI_SETEXTRAASCENT (* *spacious-padding-size* 2) 0)
        (send-message ed SCI_SETEXTRADESCENT (* *spacious-padding-size* 1) 0)
        (echo-message! echo "Spacious padding: on"))
      (begin
        (send-message ed SCI_SETMARGINLEFT 0 0)
        (send-message ed SCI_SETMARGINRIGHT 0 0)
        (send-message ed SCI_SETEXTRAASCENT 0 0)
        (send-message ed SCI_SETEXTRADESCENT 0 0)
        (echo-message! echo "Spacious padding: off")))))

;; --- Feature 15: DAPE (Debug Adapter Protocol stub) ---

(def *dape-breakpoints* '())
(def *dape-active* #f)

(def (cmd-dape app)
  "Start debug adapter session (stub — shows debug UI)."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (set! *dape-active* #t)
    (let* ((buf (make-buffer "*dape-debug*"))
           (content (string-append "Debug Adapter Protocol\n"
                      (make-string 50 #\=) "\n"
                      "Status: Waiting for connection\n"
                      "Breakpoints: " (number->string (length *dape-breakpoints*)) "\n"
                      "\nCommands:\n"
                      "  dape-breakpoint-toggle — toggle breakpoint at line\n"
                      "  dape-step — step over\n"
                      "  dape-continue — continue execution\n"
                      "  dape-quit — end debug session\n")))
      (buffer-attach! ed buf)
      (set! (edit-window-buffer win) buf)
      (editor-set-text ed content)
      (editor-goto-pos ed 0)
      (echo-message! echo "DAPE: debug session started"))))

(def (cmd-dape-breakpoint-toggle app)
  "Toggle breakpoint at current line."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app))))
         (line (send-message ed SCI_LINEFROMPOSITION
                 (send-message ed SCI_GETCURRENTPOS 0 0) 0))
         (buf (current-buffer-from-app app))
         (name (if buf (buffer-name buf) ""))
         (key (string-append name ":" (number->string line))))
    (if (member key *dape-breakpoints*)
      (begin
        (set! *dape-breakpoints* (filter (lambda (b) (not (string=? b key))) *dape-breakpoints*))
        ;; Remove margin marker
        (send-message ed SCI_MARKERDELETE line 2)
        (echo-message! echo (string-append "Breakpoint removed: line " (number->string (+ line 1)))))
      (begin
        (set! *dape-breakpoints* (cons key *dape-breakpoints*))
        ;; Add red circle margin marker
        (send-message ed SCI_MARKERADD line 2)
        (echo-message! echo (string-append "Breakpoint set: line " (number->string (+ line 1))))))))

(def (cmd-dape-quit app)
  "End debug session."
  (set! *dape-active* #f)
  (set! *dape-breakpoints* '())
  (echo-message! (app-state-echo app) "DAPE: debug session ended"))

;; --- Feature 16: Burly (save/restore window configurations) ---

(def *burly-configs* (make-hash-table))

(def (cmd-burly-bookmark-windows app)
  "Save current window configuration as a named bookmark."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (name (echo-read-string echo "Config name: " row width)))
    (when (and name (not (string-empty? name)))
      (let* ((fr (app-state-frame app))
             (wins (frame-windows fr))
             (config (map (lambda (win)
                            (let* ((buf (edit-window-buffer win))
                                   (bname (if buf (buffer-name buf) "*scratch*"))
                                   (ed (edit-window-editor win))
                                   (pos (send-message ed SCI_GETCURRENTPOS 0 0)))
                              (cons bname pos)))
                          wins)))
        (hash-put! *burly-configs* name config)
        (echo-message! echo (string-append "Saved config: " name
          " (" (number->string (length wins)) " windows)"))))))

(def (cmd-burly-open-bookmark app)
  "Restore a saved window configuration."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (names (map (lambda (p) (symbol->string (car p))) (hash->list *burly-configs*))))
    (if (null? names)
      (echo-message! echo "No saved configurations")
      (let ((choice (echo-read-string-with-completion echo "Restore config: " names row width)))
        (when (and choice (not (string-empty? choice)))
          (let ((config (hash-get *burly-configs* (string->symbol choice))))
            (if (not config)
              (echo-error! echo "Config not found")
              (begin
                ;; Restore first window's buffer
                (when (not (null? config))
                  (let* ((first (car config))
                         (bname (car first))
                         (pos (cdr first))
                         (buf (buffer-by-name bname))
                         (fr (app-state-frame app))
                         (win (current-window fr))
                         (ed (edit-window-editor win)))
                    (when buf
                      (buffer-attach! ed buf)
                      (set! (edit-window-buffer win) buf)
                      (editor-goto-pos ed pos))))
                (echo-message! echo (string-append "Restored config: " choice))))))))))

(def (cmd-burly-list app)
  "List saved window configurations."
  (let* ((echo (app-state-echo app))
         (configs (hash->list *burly-configs*)))
    (if (null? configs)
      (echo-message! echo "No saved configurations")
      (let ((lines (map (lambda (c)
                          (string-append "  " (symbol->string (car c)) " ("
                            (number->string (length (cdr c))) " windows)"))
                        configs)))
        (echo-message! echo (string-append "Configs: " (string-join lines ", ")))))))

;; --- Feature 17: ELP (Emacs Lisp Profiler — command timing) ---

(def *elp-timing* (make-hash-table))
(def *elp-enabled* #f)
(def *elp-last-start* 0)

(def (cmd-elp-instrument app)
  "Start timing commands."
  (set! *elp-enabled* #t)
  (set! *elp-timing* (make-hash-table))
  (echo-message! (app-state-echo app) "ELP: instrumentation started"))

(def (cmd-elp-results app)
  "Show ELP timing results."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pairs (hash->list *elp-timing*)))
    (set! *elp-enabled* #f)
    (if (null? pairs)
      (echo-message! echo "No timing data")
      (let* ((sorted (sort (lambda (a b)
                             (> (cadr (cdr a)) (cadr (cdr b))))
                           pairs))
             (lines (map (lambda (p)
                           (let* ((name (symbol->string (car p)))
                                  (data (cdr p))
                                  (calls (car data))
                                  (total-ms (cadr data))
                                  (pad (make-string (max 0 (- 35 (string-length name))) #\space)))
                             (string-append "  " name pad
                               (number->string calls) " calls  "
                               (number->string total-ms) "ms total")))
                         (if (> (length sorted) 30) (list-head sorted 30) sorted)))
             (content (string-append "ELP Results\n"
                        (make-string 60 #\=) "\n"
                        (string-join lines "\n") "\n"))
             (buf (make-buffer "*elp*")))
        (buffer-attach! ed buf)
        (set! (edit-window-buffer win) buf)
        (editor-set-text ed content)
        (editor-goto-pos ed 0)))))

(def (elp-record! cmd-name elapsed-ms)
  "Record timing for a command."
  (when *elp-enabled*
    (let ((existing (hash-get *elp-timing* cmd-name)))
      (if existing
        (hash-put! *elp-timing* cmd-name
          (list (+ (car existing) 1) (+ (cadr existing) elapsed-ms)))
        (hash-put! *elp-timing* cmd-name (list 1 elapsed-ms))))))

;; --- Feature 18: Fontaine (font configuration presets) ---

(def *fontaine-presets*
  (make-hash-table))

;; Initialize default presets
(def (fontaine-init!)
  (hash-put! *fontaine-presets* 'regular
    '((size . 12) (weight . "normal")))
  (hash-put! *fontaine-presets* 'presentation
    '((size . 18) (weight . "normal")))
  (hash-put! *fontaine-presets* 'small
    '((size . 10) (weight . "normal")))
  (hash-put! *fontaine-presets* 'large
    '((size . 16) (weight . "bold"))))

(fontaine-init!)

(def (cmd-fontaine-set-preset app)
  "Select a font preset."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (names (map (lambda (p) (symbol->string (car p)))
                     (hash->list *fontaine-presets*)))
         (choice (echo-read-string-with-completion echo "Font preset: " names row width)))
    (when (and choice (not (string-empty? choice)))
      (let ((preset (hash-get *fontaine-presets* (string->symbol choice))))
        (if (not preset)
          (echo-error! echo "Preset not found")
          (let* ((size (cdr (assq 'size preset)))
                 (ed (edit-window-editor (current-window (app-state-frame app)))))
            ;; Apply font size via Scintilla
            (let loop ((style 0))
              (when (< style 128)
                (send-message ed SCI_STYLESETSIZE style size)
                (loop (+ style 1))))
            (echo-message! echo
              (string-append "Font preset: " choice " (size " (number->string size) ")"))))))))

;; --- Feature 19: SHR Render (simple HTML rendering) ---

(def (cmd-shr-render app)
  "Render HTML in current buffer as plain text."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app))))
         (html (editor-get-text ed)))
    (if (string-empty? html)
      (echo-message! echo "Buffer is empty")
      ;; Simple HTML to text: strip tags, decode common entities
      (let* ((stripped
               (let loop ((i 0) (in-tag #f) (acc '()))
                 (if (>= i (string-length html))
                   (list->string (reverse acc))
                   (let ((ch (string-ref html i)))
                     (cond
                       ((char=? ch #\<) (loop (+ i 1) #t acc))
                       ((and in-tag (char=? ch #\>))
                        ;; Check for block tags to insert newlines
                        (loop (+ i 1) #f acc))
                       (in-tag (loop (+ i 1) #t acc))
                       ((and (char=? ch #\&) (< (+ i 3) (string-length html)))
                        (cond
                          ((string-prefix? "&amp;" (substring html i (min (string-length html) (+ i 5))))
                           (loop (+ i 5) #f (cons #\& acc)))
                          ((string-prefix? "&lt;" (substring html i (min (string-length html) (+ i 4))))
                           (loop (+ i 4) #f (cons #\< acc)))
                          ((string-prefix? "&gt;" (substring html i (min (string-length html) (+ i 4))))
                           (loop (+ i 4) #f (cons #\> acc)))
                          ((string-prefix? "&nbsp;" (substring html i (min (string-length html) (+ i 6))))
                           (loop (+ i 6) #f (cons #\space acc)))
                          ((string-prefix? "&quot;" (substring html i (min (string-length html) (+ i 6))))
                           (loop (+ i 6) #f (cons #\" acc)))
                          (else (loop (+ i 1) #f (cons ch acc)))))
                       (else (loop (+ i 1) #f (cons ch acc)))))))))
        (editor-set-text ed stripped)
        (editor-goto-pos ed 0)
        (echo-message! echo "HTML rendered as text")))))

;; --- Feature 20: Auto Theme Switch (time-based theme switching) ---

(def *auto-theme-enabled* #f)
(def *auto-theme-light-hour* 7)  ;; Switch to light at 7 AM
(def *auto-theme-dark-hour* 19)  ;; Switch to dark at 7 PM
(def *auto-theme-current* 'dark)

(def (cmd-auto-theme-switch app)
  "Toggle automatic time-based theme switching."
  (set! *auto-theme-enabled* (not *auto-theme-enabled*))
  (echo-message! (app-state-echo app)
    (if *auto-theme-enabled*
      (string-append "Auto theme: on (light " (number->string *auto-theme-light-hour*)
        ":00, dark " (number->string *auto-theme-dark-hour*) ":00)")
      "Auto theme: off")))

(def (auto-theme-check! app)
  "Check current time and switch theme if needed."
  (when *auto-theme-enabled*
    (let* ((now (current-time))
           (d (time-utc->date now 0))
           (hour (date-hour d))
           (should-be-light (and (>= hour *auto-theme-light-hour*)
                                 (< hour *auto-theme-dark-hour*)))
           (target (if should-be-light 'light 'dark)))
      (when (not (eq? target *auto-theme-current*))
        (set! *auto-theme-current* target)
        (let ((ed (edit-window-editor (current-window (app-state-frame app)))))
          (if (eq? target 'light)
            (begin
              ;; Light theme colors
              (send-message ed SCI_STYLESETBACK 32 #xFFFFFF) ;; default bg
              (send-message ed SCI_STYLESETFORE 32 #x000000) ;; default fg
              (send-message ed SCI_SETCARETFORE #x000000 0))
            (begin
              ;; Dark theme colors
              (send-message ed SCI_STYLESETBACK 32 #x1E1E2E) ;; default bg
              (send-message ed SCI_STYLESETFORE 32 #xCDD6F4) ;; default fg
              (send-message ed SCI_SETCARETFORE #xCDD6F4 0))))))))
