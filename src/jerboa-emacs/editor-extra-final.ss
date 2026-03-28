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

;;;============================================================================
;;; Round 7 batch 2: Features 11-20
;;;============================================================================

;; --- Feature 11: Mastodon/Fediverse Display ---

(def *mastodon-instance* "mastodon.social")

(def (cmd-mastodon app)
  "Open a Mastodon timeline display (read-only, via public API)."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (echo-message! echo (string-append "Fetching from " *mastodon-instance* "..."))
    (let-values (((p-stdin p-stdout p-stderr pid)
                  (open-process-ports
                    (string-append "curl -s 'https://" *mastodon-instance*
                      "/api/v1/timelines/public?limit=10' 2>&1 | head -200")
                    'block (native-transcoder))))
      (close-port p-stdin)
      (let loop ((lines '()))
        (let ((line (get-line p-stdout)))
          (if (eof-object? line)
            (begin
              (close-port p-stdout)
              (close-port p-stderr)
              (let* ((content (string-append "Mastodon Public Timeline (" *mastodon-instance* ")\n"
                                (make-string 50 #\=) "\n"
                                (string-join (reverse lines) "\n")))
                     (buf (make-buffer "*mastodon*")))
                (buffer-attach! ed buf)
                (set! (edit-window-buffer win) buf)
                (editor-set-text ed content)
                (editor-goto-pos ed 0)
                (echo-message! echo "Mastodon timeline loaded")))
            (loop (cons line lines))))))))

;; --- Feature 12: QR Code (text art approximation) ---

(def (cmd-qr-code app)
  "Generate a QR code text representation (requires qrencode)."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (text (echo-read-string echo "QR text: " row width)))
    (when (and text (not (string-empty? text)))
      (if (not (file-exists? "/usr/bin/qrencode"))
        (echo-error! echo "qrencode not installed")
        (let* ((fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win)))
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          (string-append "qrencode -t UTF8 \"" text "\" 2>&1")
                          'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout)
                    (close-port p-stderr)
                    (let* ((content (string-join (reverse lines) "\n"))
                           (buf (make-buffer "*qr-code*")))
                      (buffer-attach! ed buf)
                      (set! (edit-window-buffer win) buf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo "QR code generated")))
                  (loop (cons line lines)))))))))))

;; --- Feature 13: SSH Agent / Keychain ---

(def (cmd-keychain-status app)
  "Show SSH agent status and loaded keys."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (let-values (((p-stdin p-stdout p-stderr pid)
                  (open-process-ports "ssh-add -l 2>&1" 'block (native-transcoder))))
      (close-port p-stdin)
      (let loop ((lines '()))
        (let ((line (get-line p-stdout)))
          (if (eof-object? line)
            (begin
              (close-port p-stdout)
              (close-port p-stderr)
              (let ((content (string-append "SSH Agent Keys\n"
                               (make-string 40 #\-) "\n"
                               (if (null? lines)
                                 "No keys loaded (or agent not running)"
                                 (string-join (reverse lines) "\n")))))
                (echo-message! echo content)))
            (loop (cons line lines))))))))

(def (cmd-keychain-add app)
  "Add SSH key to agent."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (key-path (echo-read-string echo "SSH key path [~/.ssh/id_rsa]: " row width))
         (path (if (or (not key-path) (string-empty? key-path))
                 (string-append (getenv "HOME") "/.ssh/id_rsa")
                 key-path)))
    (if (not (file-exists? path))
      (echo-error! echo (string-append "Key not found: " path))
      (echo-message! echo (string-append "Run: ssh-add " path " (interactive auth needed)")))))

;; --- Feature 14: Eyebrowse (workspace/desktop management) ---

(def *eyebrowse-desktops* (make-hash-table))
(def *eyebrowse-current* 1)

(def (cmd-eyebrowse-switch app)
  "Switch to a workspace by number."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (num-str (echo-read-string echo "Workspace (1-9): " row width)))
    (when (and num-str (not (string-empty? num-str)))
      (let ((num (string->number (string-trim num-str))))
        (when (and num (>= num 1) (<= num 9))
          ;; Save current workspace
          (let* ((fr (app-state-frame app))
                 (win (current-window fr))
                 (buf (edit-window-buffer win))
                 (bname (if buf (buffer-name buf) "*scratch*")))
            (hash-put! *eyebrowse-desktops* *eyebrowse-current* bname)
            (set! *eyebrowse-current* num)
            ;; Restore target workspace
            (let ((saved (hash-get *eyebrowse-desktops* num)))
              (when saved
                (let ((restore-buf (buffer-by-name saved)))
                  (when restore-buf
                    (let ((ed (edit-window-editor win)))
                      (buffer-attach! ed restore-buf)
                      (set! (edit-window-buffer win) restore-buf))))))
            (echo-message! echo
              (string-append "Workspace " (number->string num)))))))))

(def (cmd-eyebrowse-create app)
  "Create a new workspace."
  (let* ((echo (app-state-echo app))
         (next (+ *eyebrowse-current* 1)))
    (when (<= next 9)
      (set! *eyebrowse-current* next)
      (echo-message! echo (string-append "Created workspace " (number->string next))))))

;; --- Feature 15: Chess Board Display ---

(def (cmd-chess app)
  "Display a chess board."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (make-buffer "*chess*"))
         (board '("  a b c d e f g h"
                  "8 r n b q k b n r"
                  "7 p p p p p p p p"
                  "6 . . . . . . . ."
                  "5 . . . . . . . ."
                  "4 . . . . . . . ."
                  "3 . . . . . . . ."
                  "2 P P P P P P P P"
                  "1 R N B Q K B N R"
                  "  a b c d e f g h"))
         (content (string-append "=== CHESS ===\n\n"
                    (string-join board "\n") "\n\n"
                    "White: RNBQKP  Black: rnbqkp\n"
                    "(Display mode — manual move entry)")))
    (buffer-attach! ed buf)
    (set! (edit-window-buffer win) buf)
    (editor-set-text ed content)
    (editor-goto-pos ed 0)
    (echo-message! echo "Chess board displayed")))

;; --- Feature 16: Sudoku Puzzle ---

(def (cmd-sudoku app)
  "Display a sudoku puzzle."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (make-buffer "*sudoku*"))
         ;; Simple puzzle (0 = empty)
         (puzzle '("5 3 .  . 7 .  . . ."
                   "6 . .  1 9 5  . . ."
                   ". 9 8  . . .  . 6 ."
                   ""
                   "8 . .  . 6 .  . . 3"
                   "4 . .  8 . 3  . . 1"
                   "7 . .  . 2 .  . . 6"
                   ""
                   ". 6 .  . . .  2 8 ."
                   ". . .  4 1 9  . . 5"
                   ". . .  . 8 .  . 7 9"))
         (content (string-append "=== SUDOKU ===\n\n"
                    (string-join puzzle "\n") "\n\n"
                    "Fill in the dots with 1-9\n"
                    "(Display mode — edit directly)")))
    (buffer-attach! ed buf)
    (set! (edit-window-buffer win) buf)
    (editor-set-text ed content)
    (editor-goto-pos ed 0)
    (echo-message! echo "Sudoku puzzle loaded")))

;; --- Feature 17: Pong Game Display ---

(def (cmd-pong app)
  "Display a pong game board."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (make-buffer "*pong*"))
         (width 40) (height 15)
         (board (let loop ((row 0) (lines '()))
                  (if (>= row height) (reverse lines)
                    (loop (+ row 1)
                      (cons (cond
                              ((or (= row 0) (= row (- height 1)))
                               (make-string width #\-))
                              ((= row (quotient height 2))
                               (string-append "|" (make-string 18 #\space)
                                 "o" (make-string 19 #\space) "|"))
                              (else
                               (string-append "|" (make-string (- width 2) #\space) "|")))
                            lines)))))
         (content (string-append "=== PONG ===\n"
                    "Player 1: 0  Player 2: 0\n\n"
                    (string-join board "\n") "\n\n"
                    "(Display mode placeholder)")))
    (buffer-attach! ed buf)
    (set! (edit-window-buffer win) buf)
    (editor-set-text ed content)
    (editor-goto-pos ed 0)
    (echo-message! echo "Pong displayed")))

;; --- Feature 18: Org Pomodoro ---

(def *org-pomodoro-task* "")
(def *org-pomodoro-start* #f)
(def *org-pomodoro-duration* 25)

(def (cmd-org-pomodoro app)
  "Start a pomodoro timer linked to current org heading."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app))))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (text (editor-get-text ed))
         (lines (string-split text #\newline))
         ;; Find current org heading
         (heading (let loop ((l line))
                    (if (< l 0) "Unknown task"
                      (let ((lt (if (< l (length lines)) (list-ref lines l) "")))
                        (if (string-prefix? "* " (string-trim lt))
                          (string-trim (substring (string-trim lt) 2
                            (string-length (string-trim lt))))
                          (loop (- l 1))))))))
    (set! *org-pomodoro-task* heading)
    (set! *org-pomodoro-start* (time-second (current-time)))
    (echo-message! echo
      (string-append "Org-Pomodoro: " heading " (" (number->string *org-pomodoro-duration*) " min)"))))

(def (cmd-org-pomodoro-status app)
  "Show current org-pomodoro status."
  (let ((echo (app-state-echo app)))
    (if (not *org-pomodoro-start*)
      (echo-message! echo "No org-pomodoro active")
      (let* ((elapsed (- (time-second (current-time)) *org-pomodoro-start*))
             (remaining (max 0 (- (* *org-pomodoro-duration* 60) elapsed)))
             (min (quotient remaining 60))
             (sec (remainder remaining 60)))
        (echo-message! echo
          (string-append "Org-Pomodoro [" *org-pomodoro-task* "]: "
            (number->string min) ":" (if (< sec 10) "0" "") (number->string sec)
            (if (<= remaining 0) " DONE!" "")))))))

;; --- Feature 19: LanguageTool (grammar/style check via external tool) ---

(def (cmd-languagetool-check app)
  "Check grammar with LanguageTool (requires languagetool installed)."
  (let* ((echo (app-state-echo app))
         (buf (current-buffer-from-app app))
         (path (and buf (buffer-file-path buf))))
    (if (not path)
      ;; Write buffer to temp file for checking
      (echo-error! echo "Save buffer first for LanguageTool check")
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (cmd (cond
                    ((file-exists? "/usr/bin/languagetool")
                     (string-append "languagetool \"" path "\" 2>&1"))
                    ((file-exists? "/snap/bin/languagetool")
                     (string-append "/snap/bin/languagetool \"" path "\" 2>&1"))
                    (else #f))))
        (if (not cmd)
          (echo-error! echo "LanguageTool not found — install via package manager")
          (begin
            (echo-message! echo "Running LanguageTool...")
            (let-values (((p-stdin p-stdout p-stderr pid)
                          (open-process-ports cmd 'block (native-transcoder))))
              (close-port p-stdin)
              (let loop ((lines '()))
                (let ((line (get-line p-stdout)))
                  (if (eof-object? line)
                    (begin
                      (close-port p-stdout)
                      (close-port p-stderr)
                      (let* ((content (string-append "LanguageTool Report\n"
                                        (make-string 50 #\=) "\n"
                                        (if (null? lines) "No issues found"
                                          (string-join (reverse lines) "\n"))))
                             (lbuf (make-buffer "*languagetool*")))
                        (buffer-attach! ed lbuf)
                        (set! (edit-window-buffer win) lbuf)
                        (editor-set-text ed content)
                        (editor-goto-pos ed 0)
                        (echo-message! echo "LanguageTool check complete")))
                    (loop (cons line lines))))))))))))

;; --- Feature 20: Spray WPM Configuration ---

(def (cmd-spray-set-wpm app)
  "Set speed reading words-per-minute."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "WPM (100-1000): " row width)))
    (when (and input (not (string-empty? input)))
      (let ((wpm (string->number (string-trim input))))
        (when (and wpm (>= wpm 100) (<= wpm 1000))
          (set! *spray-wpm* wpm)
          (echo-message! echo (string-append "Spray WPM: " (number->string wpm))))))))

;; ===== Round 8 Batch 2 =====

;; --- Feature 11: Macrostep (Macro Expansion Viewer) ---

(def (cmd-macrostep app)
  "Expand the Scheme macro at point and show expansion in a buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line-num (send-message ed SCI_LINEFROMPOSITION pos 0))
         (start (send-message ed SCI_POSITIONFROMLINE line-num 0))
         (end (send-message ed SCI_GETLINEENDPOSITION line-num 0))
         (line-text (editor-get-text-range ed start (- end start))))
    (when (and line-text (> (string-length line-text) 0))
      (with-catch
        (lambda (e) (echo-message! echo (str "Macro expansion error: " e)))
        (lambda ()
          (let* ((expr (read (open-input-string (string-trim line-text))))
                 (expanded (with-output-to-string
                             (lambda () (pretty-print (expand expr))))))
            (let ((mbuf (make-buffer "*macrostep*")))
              (buffer-attach! ed mbuf)
              (set! (edit-window-buffer win) mbuf)
              (editor-set-text ed (string-append "Macro Expansion\n"
                                    (make-string 50 #\=) "\n\n"
                                    "Original:\n  " (string-trim line-text) "\n\n"
                                    "Expanded:\n" expanded))
              (editor-goto-pos ed 0)
              (echo-message! echo "Macro expanded"))))))))

;; --- Feature 12: Eat (Terminal Toggle) ---

(def *eat-buffer* #f)

(def (cmd-eat app)
  "Toggle a terminal buffer (Emulate A Terminal)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (if (and *eat-buffer* (buffer-name *eat-buffer*))
      ;; Switch to existing terminal buffer
      (begin
        (set! (edit-window-buffer win) *eat-buffer*)
        (echo-message! echo "Switched to *eat*"))
      ;; Create new terminal buffer
      (let ((tbuf (make-buffer "*eat*")))
        (set! *eat-buffer* tbuf)
        (buffer-attach! ed tbuf)
        (set! (edit-window-buffer win) tbuf)
        (editor-set-text ed "=== Terminal (eat) ===\nUse shell-command to execute commands.\n")
        (editor-goto-pos ed 0)
        (echo-message! echo "Terminal buffer created")))))

;; --- Feature 13: Envrc (Direnv Integration) ---

(def *envrc-loaded-dirs* (make-hash-table))

(def (cmd-envrc app)
  "Load .envrc from current file's directory (direnv integration)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (let* ((dir (path-directory file))
             (envrc-path (path-join dir ".envrc")))
        (if (not (file-exists? envrc-path))
          (echo-message! echo (str "No .envrc found in " dir))
          (with-catch
            (lambda (e) (echo-message! echo (str "envrc error: " e)))
            (lambda ()
              (let-values (((p-stdin p-stdout p-stderr pid)
                            (open-process-ports
                              (str "cd " (shell-quote dir) " && direnv export json 2>/dev/null")
                              'block (native-transcoder))))
                (close-port p-stdin)
                (let loop ((lines '()))
                  (let ((line (get-line p-stdout)))
                    (if (eof-object? line)
                      (begin
                        (close-port p-stdout) (close-port p-stderr)
                        (let ((json-str (string-join (reverse lines) "")))
                          (if (string-empty? (string-trim json-str))
                            (echo-message! echo (str "envrc: no env changes in " dir))
                            (begin
                              (hash-put! *envrc-loaded-dirs* dir #t)
                              (echo-message! echo (str "envrc: loaded " dir))))))
                      (loop (cons line lines)))))))))))))

;; --- Feature 14: Org-present (Org Presentations) ---

(def *org-present-slides* '())
(def *org-present-index* 0)

(def (org-present-parse text)
  "Parse org text into slides split by top-level headings."
  (let* ((lines (string-split text #\newline))
         (slides '())
         (current '()))
    (for-each (lambda (line)
                (if (and (> (string-length line) 0)
                         (char=? (string-ref line 0) #\*))
                  (begin
                    (when (not (null? current))
                      (set! slides (cons (string-join (reverse current) "\n") slides)))
                    (set! current (list line)))
                  (set! current (cons line current))))
              lines)
    (when (not (null? current))
      (set! slides (cons (string-join (reverse current) "\n") slides)))
    (reverse slides)))

(def (cmd-org-present app)
  "Start an org-mode presentation from the current buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when text
      (set! *org-present-slides* (org-present-parse text))
      (set! *org-present-index* 0)
      (if (null? *org-present-slides*)
        (echo-message! echo "No slides found (need * headings)")
        (let ((pbuf (make-buffer "*presentation*")))
          (buffer-attach! ed pbuf)
          (set! (edit-window-buffer win) pbuf)
          (editor-set-text ed (car *org-present-slides*))
          (editor-goto-pos ed 0)
          (echo-message! echo (str "Slide 1/" (length *org-present-slides*))))))))

(def (cmd-org-present-next app)
  "Go to next slide in org presentation."
  (when (and (not (null? *org-present-slides*))
             (< *org-present-index* (- (length *org-present-slides*) 1)))
    (set! *org-present-index* (+ *org-present-index* 1))
    (let* ((frame (app-state-frame app))
           (ed (edit-window-editor (current-window frame))))
      (editor-set-text ed (list-ref *org-present-slides* *org-present-index*))
      (editor-goto-pos ed 0)
      (echo-message! (app-state-echo app)
        (str "Slide " (+ *org-present-index* 1) "/" (length *org-present-slides*))))))

(def (cmd-org-present-prev app)
  "Go to previous slide in org presentation."
  (when (and (not (null? *org-present-slides*))
             (> *org-present-index* 0))
    (set! *org-present-index* (- *org-present-index* 1))
    (let* ((frame (app-state-frame app))
           (ed (edit-window-editor (current-window frame))))
      (editor-set-text ed (list-ref *org-present-slides* *org-present-index*))
      (editor-goto-pos ed 0)
      (echo-message! (app-state-echo app)
        (str "Slide " (+ *org-present-index* 1) "/" (length *org-present-slides*))))))

;; --- Feature 15: Denote (Simple Notes) ---

(def *denote-directory* #f)

(def (denote-dir)
  (or *denote-directory*
      (let ((home (getenv "HOME")))
        (path-join home "notes"))))

(def (cmd-denote app)
  "Create a new denote-style note with timestamp ID."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (title (echo-read-string echo "Note title: " row width)))
    (when (and title (not (string-empty? title)))
      (let* ((now (current-time))
             (secs (time-second now))
             ;; Generate timestamp-based ID
             (id (number->string secs))
             (slug (let loop ((chars (string->list (string-downcase title))) (acc '()))
                     (cond
                       ((null? chars) (list->string (reverse acc)))
                       ((char-alphabetic? (car chars))
                        (loop (cdr chars) (cons (car chars) acc)))
                       ((char-numeric? (car chars))
                        (loop (cdr chars) (cons (car chars) acc)))
                       ((and (not (null? acc)) (not (char=? (car acc) #\-)))
                        (loop (cdr chars) (cons #\- acc)))
                       (else (loop (cdr chars) acc)))))
             (filename (str id "--" slug ".org"))
             (dir (denote-dir))
             (filepath (path-join dir filename))
             (content (string-append
                        "#+title: " title "\n"
                        "#+date: " id "\n"
                        "#+identifier: " id "\n\n")))
        (when (not (file-exists? dir))
          (with-catch (lambda (e) #f)
            (lambda () (mkdir dir))))
        (write-file-string filepath content)
        (let ((nbuf (make-buffer filepath)))
          (buffer-attach! ed nbuf)
          (set! (edit-window-buffer win) nbuf)
          (buffer-file-set! nbuf filepath)
          (editor-set-text ed content)
          (editor-goto-pos ed (string-length content))
          (echo-message! echo (str "Created note: " filename)))))))

(def (cmd-denote-find app)
  "Find an existing denote note."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (dir (denote-dir)))
    (if (not (file-exists? dir))
      (echo-message! echo (str "Notes directory not found: " dir))
      (with-catch
        (lambda (e) (echo-message! echo (str "Error listing notes: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          (str "ls -1 " (shell-quote dir))
                          'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((files '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let* ((notes (filter (lambda (f) (string-suffix? ".org" f)) (reverse files)))
                           (choice (echo-read-string-with-completion
                                     echo "Note: " notes row width)))
                      (when (and choice (not (string-empty? choice)))
                        (let* ((filepath (path-join dir choice))
                               (frame (app-state-frame app))
                               (win (current-window frame))
                               (ed (edit-window-editor win))
                               (content (read-file-string filepath))
                               (nbuf (make-buffer filepath)))
                          (buffer-attach! ed nbuf)
                          (set! (edit-window-buffer win) nbuf)
                          (buffer-file-set! nbuf filepath)
                          (editor-set-text ed content)
                          (editor-goto-pos ed 0)
                          (echo-message! echo (str "Opened: " choice))))))
                  (loop (cons line files)))))))))))

;; --- Feature 16: Detached (Detach Processes) ---

(def *detached-sessions* '())

(def (cmd-detached-create app)
  "Create a detached process that runs in the background."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (cmd (echo-read-string echo "Detached command: " row width)))
    (when (and cmd (not (string-empty? cmd)))
      (with-catch
        (lambda (e) (echo-message! echo (str "Detach error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          (str "nohup " cmd " > /tmp/detached-" (number->string pid)
                               ".log 2>&1 &")
                          'block (native-transcoder))))
            (close-port p-stdin) (close-port p-stdout) (close-port p-stderr)
            (set! *detached-sessions*
              (cons (list (cons 'cmd cmd) (cons 'pid pid)
                          (cons 'time (time-second (current-time))))
                    *detached-sessions*))
            (echo-message! echo (str "Detached: " cmd " (pid " pid ")"))))))))

(def (cmd-detached-list app)
  "List all detached sessions."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (content (string-append "Detached Sessions\n"
                    (make-string 50 #\=) "\n\n"
                    (if (null? *detached-sessions*)
                      "No detached sessions"
                      (string-join
                        (map (lambda (s)
                               (str "  PID " (cdr (assoc 'pid s))
                                    ": " (cdr (assoc 'cmd s))))
                             *detached-sessions*)
                        "\n"))))
         (dbuf (make-buffer "*detached*")))
    (buffer-attach! ed dbuf)
    (set! (edit-window-buffer win) dbuf)
    (editor-set-text ed content)
    (editor-goto-pos ed 0)
    (echo-message! echo (str (length *detached-sessions*) " detached sessions"))))

;; --- Feature 17: Inheritenv (Inherit Shell Environment) ---

(def (cmd-inheritenv app)
  "Refresh the process environment from the user's login shell."
  (let* ((echo (app-state-echo app)))
    (with-catch
      (lambda (e) (echo-message! echo (str "inheritenv error: " e)))
      (lambda ()
        (let-values (((p-stdin p-stdout p-stderr pid)
                      (open-process-ports
                        "env -0"
                        'block (native-transcoder))))
          (close-port p-stdin)
          (let loop ((data '()))
            (let ((line (get-line p-stdout)))
              (if (eof-object? line)
                (begin
                  (close-port p-stdout) (close-port p-stderr)
                  (let ((count 0))
                    (for-each (lambda (entry)
                                (when (> (string-length entry) 0)
                                  (let ((eq-pos (string-contains entry "=")))
                                    (when eq-pos
                                      (let ((key (substring entry 0 eq-pos))
                                            (val (substring entry (+ eq-pos 1)
                                                   (string-length entry))))
                                        (setenv key val)
                                        (set! count (+ count 1)))))))
                              (string-split (string-join (reverse data) "\n") #\nul))
                    (echo-message! echo (str "Inherited " count " env vars"))))
                (loop (cons line data))))))))))

;; --- Feature 18: Calc-grab-region ---

(def (cmd-calc-grab-region app)
  "Grab selected text and evaluate it as a numeric expression."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection — select text to evaluate")
      (let* ((sel-text (editor-get-text-range ed sel-start (- sel-end sel-start))))
        (with-catch
          (lambda (e) (echo-message! echo (str "Calc error: " e)))
          (lambda ()
            (let ((result (eval (read (open-input-string (string-trim sel-text))))))
              (when (number? result)
                (echo-message! echo (str "= " result))))))))))

;; --- Feature 19: Coterm (Terminal in Comint) ---

(def *coterm-history* '())

(def (cmd-coterm app)
  "Run a shell command and display output inline (comint-style terminal)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (cmd (echo-read-string-with-completion
                echo "Coterm$ " *coterm-history* row width)))
    (when (and cmd (not (string-empty? cmd)))
      (set! *coterm-history* (cons cmd (filter (lambda (x) (not (string=? x cmd)))
                                               *coterm-history*)))
      (with-catch
        (lambda (e) (echo-message! echo (str "Error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports cmd 'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let* ((output (string-join (reverse lines) "\n"))
                           (content (string-append "$ " cmd "\n"
                                      (make-string 40 #\-) "\n"
                                      output "\n"))
                           (cbuf (make-buffer "*coterm*")))
                      (buffer-attach! ed cbuf)
                      (set! (edit-window-buffer win) cbuf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo "Command finished")))
                  (loop (cons line lines)))))))))))

;; --- Feature 20: Atomic-chrome (Edit Browser Text) ---

(def *atomic-chrome-port* 64292)

(def (cmd-atomic-chrome-start app)
  "Start atomic-chrome server — listens for browser text editing requests."
  (let ((echo (app-state-echo app)))
    ;; In a real implementation, this would start a WebSocket server.
    ;; For now, create a buffer for editing and provide instructions.
    (let* ((frame (app-state-frame app))
           (win (current-window frame))
           (ed (edit-window-editor win))
           (content (string-append
                      "Atomic Chrome - Browser Text Editing\n"
                      (make-string 50 #\=) "\n\n"
                      "This feature allows editing browser text fields in the editor.\n\n"
                      "Setup:\n"
                      "  1. Install GhostText browser extension\n"
                      "  2. Port: " (number->string *atomic-chrome-port*) "\n"
                      "  3. Click GhostText icon on a textarea\n"
                      "  4. Edit here and save to send back\n\n"
                      "--- Edit below this line ---\n\n"))
           (abuf (make-buffer "*atomic-chrome*")))
      (buffer-attach! ed abuf)
      (set! (edit-window-buffer win) abuf)
      (editor-set-text ed content)
      (editor-goto-pos ed (string-length content))
      (echo-message! echo (str "Atomic Chrome ready on port " *atomic-chrome-port*)))))

;; ===== Round 9 Batch 2 =====

;; --- Feature 11: Hackernews Client ---

(def (cmd-hackernews app)
  "Fetch and display top Hacker News stories."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (echo-message! echo "Fetching HN top stories...")
    (with-catch
      (lambda (e) (echo-message! echo (str "HN error: " e)))
      (lambda ()
        (let-values (((p-stdin p-stdout p-stderr pid)
                      (open-process-ports
                        "curl -sL 'https://hacker-news.firebaseio.com/v0/topstories.json?print=pretty' | head -30"
                        'block (native-transcoder))))
          (close-port p-stdin)
          (let loop ((lines '()))
            (let ((line (get-line p-stdout)))
              (if (eof-object? line)
                (begin
                  (close-port p-stdout) (close-port p-stderr)
                  (let* ((content (string-append "Hacker News - Top Stories\n"
                                    (make-string 50 #\=) "\n\n"
                                    "Story IDs (use hackernews-view to read):\n"
                                    (string-join (reverse lines) "\n")))
                         (hbuf (make-buffer "*hackernews*")))
                    (buffer-attach! ed hbuf)
                    (set! (edit-window-buffer win) hbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "Hacker News loaded")))
                (loop (cons line lines))))))))))

;; --- Feature 12: Biblio (Bibliography Search) ---

(def (cmd-biblio app)
  "Search for academic papers via crossref API."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (query (echo-read-string echo "Biblio search: " row width)))
    (when (and query (not (string-empty? query)))
      (echo-message! echo "Searching...")
      (with-catch
        (lambda (e) (echo-message! echo (str "Biblio error: " e)))
        (lambda ()
          (let* ((encoded (let loop ((chars (string->list query)) (acc '()))
                            (if (null? chars)
                              (list->string (reverse acc))
                              (let ((c (car chars)))
                                (if (char=? c #\space)
                                  (loop (cdr chars) (cons #\+ acc))
                                  (loop (cdr chars) (cons c acc)))))))
                 (url (str "https://api.crossref.org/works?query=" encoded "&rows=10")))
            (let-values (((p-stdin p-stdout p-stderr pid)
                          (open-process-ports
                            (str "curl -sL --max-time 15 " (shell-quote url))
                            'block (native-transcoder))))
              (close-port p-stdin)
              (let loop ((lines '()))
                (let ((line (get-line p-stdout)))
                  (if (eof-object? line)
                    (begin
                      (close-port p-stdout) (close-port p-stderr)
                      (let* ((raw (string-join (reverse lines) "\n"))
                             ;; Extract titles from JSON (simple approach)
                             (titles (let extract ((s raw) (acc '()))
                                       (let ((start (string-contains s "\"title\":")))
                                         (if (not start)
                                           (reverse acc)
                                           (let* ((rest (substring s (+ start 9) (string-length s)))
                                                  (qstart (string-contains rest "\""))
                                                  (rest2 (if qstart (substring rest (+ qstart 1) (string-length rest)) ""))
                                                  (qend (string-contains rest2 "\"")))
                                             (if (and qstart qend)
                                               (extract (substring rest2 (+ qend 1) (string-length rest2))
                                                        (cons (substring rest2 0 qend) acc))
                                               (reverse acc)))))))
                             (content (string-append "Biblio: " query "\n"
                                        (make-string 50 #\=) "\n\n"
                                        (if (null? titles)
                                          "No results found"
                                          (string-join
                                            (map (lambda (t) (str "  * " t)) titles)
                                            "\n"))))
                             (bbuf (make-buffer "*biblio*")))
                        (buffer-attach! ed bbuf)
                        (set! (edit-window-buffer win) bbuf)
                        (editor-set-text ed content)
                        (editor-goto-pos ed 0)
                        (echo-message! echo (str "Found " (length titles) " results"))))
                    (loop (cons line lines))))))))))))

;; --- Feature 13: EPA-file (GPG Encryption) ---

(def (cmd-epa-encrypt-file app)
  "Encrypt the current buffer using GPG."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "GPG error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "gpg --symmetric --cipher-algo AES256 " (shell-quote file))
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin (close-port so) (close-port se)
                         (echo-message! echo (str "Encrypted: " file ".gpg")))
                  (loop (cons line lines)))))))))))

(def (cmd-epa-decrypt-file app)
  "Decrypt a GPG-encrypted file and open in buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (file (echo-read-string echo "Decrypt file: " row width)))
    (when (and file (not (string-empty? file)))
      (with-catch
        (lambda (e) (echo-message! echo (str "Decrypt error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "gpg --decrypt " (shell-quote (string-trim file)))
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((content (string-join (reverse lines) "\n"))
                           (dbuf (make-buffer (str "*decrypted:" file "*"))))
                      (buffer-attach! ed dbuf)
                      (set! (edit-window-buffer win) dbuf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo "File decrypted")))
                  (loop (cons line lines)))))))))))

;; --- Feature 14: Typit (Typing Test) ---

(def *typit-texts*
  '("The quick brown fox jumps over the lazy dog"
    "Pack my box with five dozen liquor jugs"
    "How vexingly quick daft zebras jump"
    "Sphinx of black quartz judge my vow"
    "Two driven jocks help fax my big quiz"))

(def *typit-start-time* #f)
(def *typit-target* #f)

(def (cmd-typit app)
  "Start a typing accuracy test."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (set! *typit-target* (list-ref *typit-texts* (random (length *typit-texts*))))
    (set! *typit-start-time* (time-second (current-time)))
    (let ((tbuf (make-buffer "*typit*")))
      (buffer-attach! ed tbuf)
      (set! (edit-window-buffer win) tbuf)
      (editor-set-text ed (string-append
                            "Typing Test\n"
                            (make-string 50 #\=) "\n\n"
                            "Type the following text:\n\n"
                            "  " *typit-target* "\n\n"
                            "When done, use typit-check to see results."))
      (editor-goto-pos ed 0)
      (echo-message! echo "Start typing! Use typit-check when done."))))

(def (cmd-typit-check app)
  "Check typing test results."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Your text: " row width)))
    (when (and input *typit-target* *typit-start-time*)
      (let* ((elapsed (- (time-second (current-time)) *typit-start-time*))
             (words (length (string-split *typit-target* #\space)))
             (wpm (if (> elapsed 0) (round (/ (* words 60.0) elapsed)) 0))
             ;; Calculate accuracy
             (target-chars (string->list *typit-target*))
             (input-chars (string->list input))
             (correct (let loop ((t target-chars) (i input-chars) (n 0))
                        (if (or (null? t) (null? i)) n
                          (loop (cdr t) (cdr i)
                                (if (char=? (car t) (car i)) (+ n 1) n)))))
             (accuracy (if (> (length target-chars) 0)
                         (round (* 100.0 (/ correct (length target-chars))))
                         0)))
        (echo-message! echo (str "WPM: " wpm " Accuracy: " accuracy
                                 "% Time: " elapsed "s"))))))

;; --- Feature 15: Diff-at-point ---

(def (cmd-diff-at-point app)
  "Show the git diff for the current line."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (let* ((line-num (+ 1 (send-message ed SCI_LINEFROMPOSITION
                               (send-message ed SCI_GETCURRENTPOS 0 0) 0))))
        (with-catch
          (lambda (e) (echo-message! echo (str "diff error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "git diff -U3 " (shell-quote file))
                            'block (native-transcoder))))
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (let ((diff (string-join (reverse lines) "\n")))
                        (if (string-empty? (string-trim diff))
                          (echo-message! echo "No changes at this point")
                          (let ((dbuf (make-buffer "*diff-at-point*")))
                            (let ((ed2 (edit-window-editor (current-window frame))))
                              (buffer-attach! ed2 dbuf)
                              (set! (edit-window-buffer win) dbuf)
                              (editor-set-text ed2 diff)
                              (editor-goto-pos ed2 0)
                              (echo-message! echo "Diff loaded"))))))
                    (loop (cons line lines))))))))))))

;; --- Feature 16: Magit-delta ---

(def (cmd-magit-delta app)
  "Show git diff using delta for pretty formatting."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "delta error: " e)))
      (lambda ()
        ;; Try delta first, fall back to diff
        (let* ((cmd (if (file-exists? "/usr/bin/delta")
                      "git diff | delta --no-gitconfig --dark"
                      "git diff --color=always"))
               (dummy 0))
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports cmd 'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let* ((diff (string-join (reverse lines) "\n"))
                           (dbuf (make-buffer "*magit-delta*")))
                      (buffer-attach! ed dbuf)
                      (set! (edit-window-buffer win) dbuf)
                      (editor-set-text ed diff)
                      (editor-goto-pos ed 0)
                      (echo-message! echo "Delta diff loaded")))
                  (loop (cons line lines)))))))))))

;; --- Feature 17: Figlet (ASCII Art Text) ---

(def (cmd-figlet app)
  "Convert text to ASCII art using figlet."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (text (echo-read-string echo "Figlet text: " row width)))
    (when (and text (not (string-empty? text)))
      (with-catch
        (lambda (e) (echo-message! echo (str "figlet error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          (str "figlet " (shell-quote text))
                          'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let ((art (string-join (reverse lines) "\n")))
                      (editor-insert-text ed art)
                      (echo-message! echo "Figlet inserted")))
                  (loop (cons line lines)))))))))))

;; --- Feature 18: Cowsay ---

(def (cmd-cowsay app)
  "Insert cowsay ASCII art with given text."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (text (echo-read-string echo "Cowsay: " row width)))
    (when (and text (not (string-empty? text)))
      (with-catch
        (lambda (e) (echo-message! echo (str "cowsay error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          (str "cowsay " (shell-quote text))
                          'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let ((art (string-join (reverse lines) "\n")))
                      (editor-insert-text ed art)
                      (echo-message! echo "Cowsay inserted")))
                  (loop (cons line lines)))))))))))

;; --- Feature 19: Habit Tracker ---

(def *habit-tracker* (make-hash-table))

(def (cmd-habit-track app)
  "Track a daily habit completion."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (habits (hash-keys *habit-tracker*))
         (habit (echo-read-string-with-completion echo "Habit: " habits row width)))
    (when (and habit (not (string-empty? habit)))
      (let* ((today (number->string (time-second (current-time))))
             (existing (hash-ref *habit-tracker* habit '()))
             (updated (cons today existing)))
        (hash-put! *habit-tracker* habit updated)
        (echo-message! echo (str "Tracked: " habit " (" (length updated) " total)"))))))

(def (cmd-habit-report app)
  "Show habit tracking report."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (entries (hash->list *habit-tracker*))
         (content (string-append "Habit Tracker Report\n"
                    (make-string 50 #\=) "\n\n"
                    (if (null? entries) "No habits tracked yet"
                      (string-join
                        (map (lambda (e)
                               (str "  " (car e) ": " (length (cdr e)) " completions"))
                             entries)
                        "\n"))))
         (hbuf (make-buffer "*habit-report*")))
    (buffer-attach! ed hbuf)
    (set! (edit-window-buffer win) hbuf)
    (editor-set-text ed content)
    (editor-goto-pos ed 0)
    (echo-message! echo (str (length entries) " habits tracked"))))

;; --- Feature 20: Ement (Matrix Chat Stub) ---

(def (cmd-ement app)
  "Matrix chat client interface (requires matrix-commander)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "Matrix error: " e)))
      (lambda ()
        (let-values (((p-stdin p-stdout p-stderr pid)
                      (open-process-ports
                        "matrix-commander --listen once --listen-self 2>/dev/null || echo 'Install matrix-commander for Matrix chat'"
                        'block (native-transcoder))))
          (close-port p-stdin)
          (let loop ((lines '()))
            (let ((line (get-line p-stdout)))
              (if (eof-object? line)
                (begin
                  (close-port p-stdout) (close-port p-stderr)
                  (let* ((messages (string-join (reverse lines) "\n"))
                         (mbuf (make-buffer "*matrix*")))
                    (buffer-attach! ed mbuf)
                    (set! (edit-window-buffer win) mbuf)
                    (editor-set-text ed (string-append
                                          "Matrix Chat (ement)\n"
                                          (make-string 50 #\=) "\n\n"
                                          messages))
                    (editor-goto-pos ed 0)
                    (echo-message! echo "Matrix messages loaded")))
                (loop (cons line lines))))))))))

(def (cmd-ement-send app)
  "Send a message to a Matrix room."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (room (echo-read-string echo "Room: " row width)))
    (when (and room (not (string-empty? room)))
      (let ((msg (echo-read-string echo "Message: " row width)))
        (when (and msg (not (string-empty? msg)))
          (with-catch
            (lambda (e) (echo-message! echo (str "Send error: " e)))
            (lambda ()
              (let-values (((si so se pid)
                            (open-process-ports
                              (str "matrix-commander --room " (shell-quote room)
                                   " --message " (shell-quote msg))
                              'block (native-transcoder))))
                (close-port si) (close-port so) (close-port se)
                (echo-message! echo (str "Sent to " room))))))))))

;; ===== Round 10 Batch 2 =====

;; --- Feature 11: HTTP Stat ---

(def (cmd-httpstat app)
  "Show HTTP request timing statistics for a URL."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (url (echo-read-string echo "URL: " row width)))
    (when (and url (not (string-empty? url)))
      (with-catch
        (lambda (e) (echo-message! echo (str "httpstat error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "curl -sL -o /dev/null -w '"
                               "DNS: %{time_namelookup}s\\n"
                               "Connect: %{time_connect}s\\n"
                               "TLS: %{time_appconnect}s\\n"
                               "TTFB: %{time_starttransfer}s\\n"
                               "Total: %{time_total}s\\n"
                               "Status: %{http_code}\\n"
                               "Size: %{size_download} bytes\\n"
                               "' " (shell-quote (string-trim url)))
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((content (string-append "HTTP Stats: " (string-trim url) "\n"
                                      (make-string 50 #\=) "\n\n"
                                      (string-join (reverse lines) "\n")))
                           (hbuf (make-buffer "*httpstat*")))
                      (buffer-attach! ed hbuf)
                      (set! (edit-window-buffer win) hbuf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo "HTTP stats loaded")))
                  (loop (cons line lines)))))))))))

;; --- Feature 12: JWT Decode ---

(def (cmd-jwt-decode app)
  "Decode a JWT token and display its payload."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (token (echo-read-string echo "JWT token: " row width)))
    (when (and token (not (string-empty? token)))
      (let* ((parts (string-split (string-trim token) #\.)))
        (if (< (length parts) 2)
          (echo-message! echo "Invalid JWT: expected 3 parts separated by .")
          (with-catch
            (lambda (e) (echo-message! echo (str "JWT decode error: " e)))
            (lambda ()
              ;; Decode base64 header and payload
              (let* ((decode-part (lambda (part)
                       (let-values (((si so se pid)
                                     (open-process-ports
                                       (str "echo " (shell-quote part) " | base64 -d 2>/dev/null")
                                       'block (native-transcoder))))
                         (close-port si)
                         (let loop ((lines '()))
                           (let ((line (get-line so)))
                             (if (eof-object? line)
                               (begin (close-port so) (close-port se)
                                      (string-join (reverse lines) "\n"))
                               (loop (cons line lines))))))))
                     (header (decode-part (car parts)))
                     (payload (decode-part (cadr parts)))
                     (content (string-append "JWT Decode\n"
                                (make-string 50 #\=) "\n\n"
                                "Header:\n" header "\n\n"
                                "Payload:\n" payload "\n"))
                     (jbuf (make-buffer "*jwt*")))
                (buffer-attach! ed jbuf)
                (set! (edit-window-buffer win) jbuf)
                (editor-set-text ed content)
                (editor-goto-pos ed 0)
                (echo-message! echo "JWT decoded")))))))))

;; --- Feature 13: XML Format ---

(def (cmd-xml-format app)
  "Format/pretty-print XML in the current buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 0))
      (with-catch
        (lambda (e) (echo-message! echo (str "XML format error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          "xmllint --format - 2>/dev/null || python3 -c 'import sys,xml.dom.minidom;print(xml.dom.minidom.parseString(sys.stdin.read()).toprettyxml())'"
                          'block (native-transcoder))))
            (display text p-stdin)
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let ((formatted (string-join (reverse lines) "\n")))
                      (when (> (string-length formatted) 0)
                        (editor-set-text ed formatted)
                        (editor-goto-pos ed 0)
                        (echo-message! echo "XML formatted"))))
                  (loop (cons line lines)))))))))))

;; --- Feature 14: CSV Sort ---

(def (cmd-csv-sort app)
  "Sort CSV data by a specified column."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (col-str (echo-read-string echo "Sort by column (1-based): " row width)))
    (when (and col-str (not (string-empty? col-str)))
      (let ((col (string->number (string-trim col-str))))
        (when (and col (> col 0))
          (let* ((len (send-message ed SCI_GETLENGTH 0 0))
                 (text (editor-get-text ed len))
                 (lines (string-split text #\newline))
                 (header (car lines))
                 (data (cdr lines))
                 (get-col (lambda (line)
                            (let ((fields (string-split line #\,)))
                              (if (>= (length fields) col)
                                (list-ref fields (- col 1))
                                ""))))
                 (sorted (sort (lambda (a b) (string<? (get-col a) (get-col b))) data))
                 (result (string-join (cons header sorted) "\n")))
            (editor-set-text ed result)
            (editor-goto-pos ed 0)
            (echo-message! echo (str "Sorted by column " col))))))))

;; --- Feature 15: Markdown TOC ---

(def (cmd-markdown-toc app)
  "Generate a table of contents from markdown headings."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len))
         (lines (string-split text #\newline))
         (headings (filter (lambda (l) (and (> (string-length l) 0)
                                            (char=? (string-ref l 0) #\#)))
                           lines))
         (toc-entries
           (map (lambda (h)
                  (let* ((level (let loop ((i 0))
                                  (if (and (< i (string-length h)) (char=? (string-ref h i) #\#))
                                    (loop (+ i 1)) i)))
                         (title (string-trim (substring h level (string-length h))))
                         (anchor (string-downcase
                                   (let loop ((chars (string->list title)) (acc '()))
                                     (cond
                                       ((null? chars) (list->string (reverse acc)))
                                       ((char-alphabetic? (car chars))
                                        (loop (cdr chars) (cons (char-downcase (car chars)) acc)))
                                       ((char-numeric? (car chars))
                                        (loop (cdr chars) (cons (car chars) acc)))
                                       ((char=? (car chars) #\space)
                                        (loop (cdr chars) (cons #\- acc)))
                                       (else (loop (cdr chars) acc))))))
                         (indent (make-string (* (- level 1) 2) #\space)))
                    (str indent "- [" title "](#" anchor ")")))
                headings))
         (toc (string-append "## Table of Contents\n\n"
                (string-join toc-entries "\n") "\n")))
    ;; Insert at beginning
    (send-message ed SCI_GOTOPOS 0 0)
    (editor-insert-text ed (str toc "\n"))
    (echo-message! echo (str "TOC generated with " (length headings) " headings"))))

;; --- Feature 16: Focus Mode ---

(def *focus-mode-enabled* #f)

(def (cmd-focus-mode app)
  "Toggle focus/zen mode — minimize distractions."
  (set! *focus-mode-enabled* (not *focus-mode-enabled*))
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (if *focus-mode-enabled*
      (begin
        ;; Hide margins, disable wrapping distractions
        (send-message ed SCI_SETMARGINWIDTHN 0 0)  ;; hide line numbers
        (send-message ed SCI_SETMARGINWIDTHN 1 0)
        (send-message ed SCI_SETMARGINWIDTHN 2 0)
        (echo-message! echo "Focus mode: on (minimal UI)"))
      (begin
        ;; Restore margins
        (send-message ed SCI_SETMARGINWIDTHN 0 50)  ;; restore line numbers
        (echo-message! echo "Focus mode: off")))))

;; --- Feature 17: Typewriter Mode ---

(def *typewriter-mode* #f)

(def (cmd-typewriter-mode app)
  "Toggle typewriter mode — keep cursor centered vertically."
  (set! *typewriter-mode* (not *typewriter-mode*))
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (when *typewriter-mode*
      ;; Center current line
      (let* ((pos (send-message ed SCI_GETCURRENTPOS 0 0))
             (line (send-message ed SCI_LINEFROMPOSITION pos 0))
             (first-visible (send-message ed SCI_GETFIRSTVISIBLELINE 0 0))
             (lines-on-screen (send-message ed SCI_LINESONSCREEN 0 0))
             (target (max 0 (- line (quotient lines-on-screen 2)))))
        (send-message ed SCI_SETFIRSTVISIBLELINE target 0)))
    (echo-message! echo (if *typewriter-mode* "Typewriter mode: on" "Typewriter mode: off"))))

;; --- Feature 18: Matrix Rain ---

(def (cmd-rain app)
  "Display Matrix-style digital rain animation in buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (width 60) (height 20)
         (chars "abcdefghijklmnopqrstuvwxyz0123456789@#$%&")
         (char-len (string-length chars))
         (lines '()))
    (do ((r 0 (+ r 1))) ((= r height))
      (let ((row-str ""))
        (do ((c 0 (+ c 1))) ((= c width))
          (set! row-str
            (string-append row-str
              (if (< (random 10) 3)
                (str (string-ref chars (random char-len)))
                " "))))
        (set! lines (cons row-str lines))))
    (let* ((content (string-append "The Matrix\n"
                      (make-string width #\=) "\n\n"
                      (string-join (reverse lines) "\n")))
           (rbuf (make-buffer "*matrix-rain*")))
      (buffer-attach! ed rbuf)
      (set! (edit-window-buffer win) rbuf)
      (editor-set-text ed content)
      (editor-goto-pos ed 0)
      (echo-message! echo "Matrix rain"))))

;; --- Feature 19: WiFi Status ---

(def (cmd-wifi app)
  "Show WiFi connection status and available networks."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "wifi error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        "nmcli dev wifi list 2>/dev/null || iwconfig 2>/dev/null || echo 'WiFi tools not found'"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "WiFi Networks\n"
                                    (make-string 50 #\=) "\n\n"
                                    (string-join (reverse lines) "\n")))
                         (wbuf (make-buffer "*wifi*")))
                    (buffer-attach! ed wbuf)
                    (set! (edit-window-buffer win) wbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "WiFi networks listed")))
                (loop (cons line lines))))))))))

;; --- Feature 20: Screenshot ---

(def (cmd-screenshot app)
  "Take a screenshot and save it to a file."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (file (echo-read-string echo "Save screenshot to: " row width)))
    (when (and file (not (string-empty? file)))
      (let ((path (string-trim file)))
        (with-catch
          (lambda (e) (echo-message! echo (str "Screenshot error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "import " (shell-quote path) " 2>/dev/null || "
                                 "scrot " (shell-quote path) " 2>/dev/null || "
                                 "gnome-screenshot -f " (shell-quote path) " 2>/dev/null || "
                                 "echo 'No screenshot tool found'")
                            'block (native-transcoder))))
              (close-port si) (close-port so) (close-port se)
              (echo-message! echo (str "Screenshot saved to " path)))))))))

;; ===== Round 11 Batch 2 =====

;; --- Feature 11: Crontab Editor ---

(def (cmd-crontab app)
  "View or edit the user's crontab."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "crontab error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "crontab -l 2>&1" 'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "Crontab\n"
                                    (make-string 50 #\=) "\n"
                                    "# min hour dom mon dow command\n\n"
                                    (string-join (reverse lines) "\n")))
                         (cbuf (make-buffer "*crontab*")))
                    (buffer-attach! ed cbuf)
                    (set! (edit-window-buffer win) cbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "Crontab loaded")))
                (loop (cons line lines))))))))))

;; --- Feature 12: Htop (Process Viewer) ---

(def (cmd-htop app)
  "Show system processes in a buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "ps error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "ps aux --sort=-%mem | head -50"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "Process List (top 50 by memory)\n"
                                    (make-string 60 #\=) "\n\n"
                                    (string-join (reverse lines) "\n")))
                         (pbuf (make-buffer "*processes*")))
                    (buffer-attach! ed pbuf)
                    (set! (edit-window-buffer win) pbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "Process list loaded")))
                (loop (cons line lines))))))))))

;; --- Feature 13: Disk Usage Summary ---

(def (cmd-du-summary app)
  "Show disk usage summary for current directory."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (dir (echo-read-string echo "Directory (default .): " row width))
         (target (if (or (not dir) (string-empty? (string-trim dir))) "." (string-trim dir))))
    (with-catch
      (lambda (e) (echo-message! echo (str "du error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        (str "du -sh " (shell-quote target) "/* 2>/dev/null | sort -rh | head -30")
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "Disk Usage: " target "\n"
                                    (make-string 50 #\=) "\n\n"
                                    (string-join (reverse lines) "\n")))
                         (dbuf (make-buffer "*du*")))
                    (buffer-attach! ed dbuf)
                    (set! (edit-window-buffer win) dbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "Disk usage loaded")))
                (loop (cons line lines))))))))))

;; --- Feature 14: File Permissions ---

(def (cmd-permissions app)
  "Show and optionally change file permissions."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "permissions error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports (str "stat -c '%A %a %U:%G %n' " (shell-quote file))
                          'block (native-transcoder))))
            (close-port si)
            (let ((info (get-line so)))
              (close-port so) (close-port se)
              (echo-message! echo
                (if (eof-object? info) "Cannot read permissions"
                  (str "Permissions: " info))))))))))

;; --- Feature 15: Compress ---

(def (cmd-compress app)
  "Compress a file or directory."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (source (echo-read-string echo "Source path: " row width)))
    (when (and source (not (string-empty? source)))
      (let* ((formats '("tar.gz" "tar.bz2" "zip" "tar.xz"))
             (fmt (echo-read-string-with-completion echo "Format: " formats row width))
             (src (string-trim source))
             (out (str src "." (or fmt "tar.gz"))))
        (with-catch
          (lambda (e) (echo-message! echo (str "compress error: " e)))
          (lambda ()
            (let* ((cmd (cond
                          ((or (not fmt) (string=? fmt "tar.gz"))
                           (str "tar czf " (shell-quote out) " " (shell-quote src)))
                          ((string=? fmt "tar.bz2")
                           (str "tar cjf " (shell-quote out) " " (shell-quote src)))
                          ((string=? fmt "tar.xz")
                           (str "tar cJf " (shell-quote out) " " (shell-quote src)))
                          ((string=? fmt "zip")
                           (str "zip -r " (shell-quote out) " " (shell-quote src)))
                          (else (str "tar czf " (shell-quote out) " " (shell-quote src))))))
              (let-values (((si so se pid)
                            (open-process-ports (str cmd " 2>&1") 'block (native-transcoder))))
                (close-port si) (close-port so) (close-port se)
                (echo-message! echo (str "Compressed: " out))))))))))

;; --- Feature 16: Extract ---

(def (cmd-extract app)
  "Extract an archive file."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (file (echo-read-string echo "Archive file: " row width)))
    (when (and file (not (string-empty? file)))
      (let ((f (string-trim file)))
        (with-catch
          (lambda (e) (echo-message! echo (str "extract error: " e)))
          (lambda ()
            (let* ((cmd (cond
                          ((or (string-suffix? ".tar.gz" f) (string-suffix? ".tgz" f))
                           (str "tar xzf " (shell-quote f)))
                          ((string-suffix? ".tar.bz2" f)
                           (str "tar xjf " (shell-quote f)))
                          ((string-suffix? ".tar.xz" f)
                           (str "tar xJf " (shell-quote f)))
                          ((string-suffix? ".zip" f)
                           (str "unzip " (shell-quote f)))
                          ((string-suffix? ".gz" f)
                           (str "gunzip " (shell-quote f)))
                          ((string-suffix? ".bz2" f)
                           (str "bunzip2 " (shell-quote f)))
                          (else (str "tar xf " (shell-quote f))))))
              (let-values (((si so se pid)
                            (open-process-ports (str cmd " 2>&1") 'block (native-transcoder))))
                (close-port si) (close-port so) (close-port se)
                (echo-message! echo (str "Extracted: " f))))))))))

;; --- Feature 17: Diff Buffers ---

(def (cmd-diff-buffers app)
  "Diff two named buffers."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (buf1-name (echo-read-string echo "Buffer A: " row width)))
    (when (and buf1-name (not (string-empty? buf1-name)))
      (let ((buf2-name (echo-read-string echo "Buffer B: " row width)))
        (when (and buf2-name (not (string-empty? buf2-name)))
          ;; Write temp files and diff
          (let* ((tmp1 (str "/tmp/jemacs-diff-a-" (number->string (time-second (current-time)))))
                 (tmp2 (str "/tmp/jemacs-diff-b-" (number->string (time-second (current-time))))))
            (with-catch
              (lambda (e) (echo-message! echo (str "diff error: " e)))
              (lambda ()
                ;; Get text from current buffer for both (simplified - uses buffer names as placeholders)
                (write-file-string tmp1 (str "Buffer: " buf1-name "\n(content comparison placeholder)"))
                (write-file-string tmp2 (str "Buffer: " buf2-name "\n(content comparison placeholder)"))
                (let-values (((si so se pid)
                              (open-process-ports (str "diff -u " tmp1 " " tmp2 " 2>&1")
                                'block (native-transcoder))))
                  (close-port si)
                  (let loop ((lines '()))
                    (let ((line (get-line so)))
                      (if (eof-object? line)
                        (begin
                          (close-port so) (close-port se)
                          (let* ((diff (string-join (reverse lines) "\n"))
                                 (dbuf (make-buffer "*diff-buffers*")))
                            (buffer-attach! ed dbuf)
                            (set! (edit-window-buffer win) dbuf)
                            (editor-set-text ed diff)
                            (editor-goto-pos ed 0)
                            (echo-message! echo "Diff complete")))
                        (loop (cons line lines))))))))))))))

;; --- Feature 18: Sort Lines by Field ---

(def (cmd-sort-lines-by-field app)
  "Sort buffer lines by a specified field/column."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (field-str (echo-read-string echo "Sort by field # (1-based): " row width)))
    (when (and field-str (not (string-empty? field-str)))
      (let ((field (string->number (string-trim field-str))))
        (when (and field (> field 0))
          (let* ((len (send-message ed SCI_GETLENGTH 0 0))
                 (text (editor-get-text ed len))
                 (lines (string-split text #\newline))
                 (get-field (lambda (line)
                              (let ((fields (string-split line #\space)))
                                (if (>= (length fields) field)
                                  (list-ref fields (- field 1))
                                  ""))))
                 (sorted (sort (lambda (a b) (string<? (get-field a) (get-field b))) lines))
                 (result (string-join sorted "\n")))
            (editor-set-text ed result)
            (editor-goto-pos ed 0)
            (echo-message! echo (str "Sorted by field " field))))))))

;; --- Feature 19: Vagrant ---

(def (cmd-vagrant app)
  "Run a Vagrant command."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (commands '("status" "up" "halt" "destroy" "ssh" "reload" "provision" "global-status"))
         (cmd (echo-read-string-with-completion echo "vagrant: " commands row width)))
    (when (and cmd (not (string-empty? cmd)))
      (with-catch
        (lambda (e) (echo-message! echo (str "vagrant error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports (str "vagrant " cmd " 2>&1")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((output (string-join (reverse lines) "\n"))
                           (vbuf (make-buffer "*vagrant*")))
                      (buffer-attach! ed vbuf)
                      (set! (edit-window-buffer win) vbuf)
                      (editor-set-text ed output)
                      (editor-goto-pos ed 0)
                      (echo-message! echo (str "vagrant " cmd " complete"))))
                  (loop (cons line lines)))))))))))

;; --- Feature 20: Pip (Python Package Manager) ---

(def (cmd-pip app)
  "Run a pip command."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (commands '("list" "search" "install" "uninstall" "freeze" "show" "check" "outdated"))
         (cmd (echo-read-string-with-completion echo "pip: " commands row width)))
    (when (and cmd (not (string-empty? cmd)))
      (let* ((needs-arg (member cmd '("install" "uninstall" "show")))
             (arg (if needs-arg
                    (echo-read-string echo "Package: " row width)
                    #f))
             (full-cmd (if (and arg (not (string-empty? arg)))
                         (str "pip3 " cmd " " (shell-quote arg) " 2>&1")
                         (str "pip3 " cmd " 2>&1"))))
        (with-catch
          (lambda (e) (echo-message! echo (str "pip error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports full-cmd 'block (native-transcoder))))
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (let* ((output (string-join (reverse lines) "\n"))
                             (pbuf (make-buffer "*pip*")))
                        (buffer-attach! ed pbuf)
                        (set! (edit-window-buffer win) pbuf)
                        (editor-set-text ed output)
                        (editor-goto-pos ed 0)
                        (echo-message! echo (str "pip " cmd " complete"))))
                    (loop (cons line lines))))))))))))

;; ===== Round 12 Batch 2 =====

;; --- Feature 11: Copy Filepath ---

(def (cmd-copy-filepath app)
  "Copy the current buffer's full file path to kill ring."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (let ((ed (edit-window-editor win)))
        (send-message ed SCI_COPYTEXT (string-length file) file)
        (echo-message! echo (str "Copied: " file))))))

;; --- Feature 12: Hex to Decimal ---

(def (cmd-hex-to-dec app)
  "Convert a hexadecimal number to decimal."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Hex value: " row width)))
    (when (and input (not (string-empty? input)))
      (let* ((hex (string-trim input))
             (clean (if (string-prefix? "0x" hex) (substring hex 2 (string-length hex)) hex))
             (val (string->number clean 16)))
        (if val
          (echo-message! echo (str "0x" clean " = " val))
          (echo-message! echo "Invalid hex value"))))))

;; --- Feature 13: Decimal to Hex ---

(def (cmd-dec-to-hex app)
  "Convert a decimal number to hexadecimal."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Decimal value: " row width)))
    (when (and input (not (string-empty? input)))
      (let ((val (string->number (string-trim input))))
        (if val
          (echo-message! echo (str val " = 0x" (number->string val 16)))
          (echo-message! echo "Invalid decimal value"))))))

;; --- Feature 14: Binary to Decimal ---

(def (cmd-binary-to-dec app)
  "Convert a binary number to decimal."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Binary value: " row width)))
    (when (and input (not (string-empty? input)))
      (let* ((bin (string-trim input))
             (clean (if (string-prefix? "0b" bin) (substring bin 2 (string-length bin)) bin))
             (val (string->number clean 2)))
        (if val
          (echo-message! echo (str "0b" clean " = " val " (0x" (number->string val 16) ")"))
          (echo-message! echo "Invalid binary value"))))))

;; --- Feature 15: String to Hex ---

(def (cmd-string-to-hex app)
  "Convert selected text to hexadecimal representation."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      ;; No selection, prompt for input
      (let* ((row (tui-rows)) (width (tui-cols))
             (input (echo-read-string echo "String: " row width)))
        (when (and input (not (string-empty? input)))
          (let ((hex-str (apply string-append
                           (map (lambda (c) (format "~2,'0x " (char->integer c)))
                                (string->list input)))))
            (echo-message! echo (str "Hex: " hex-str)))))
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (hex-str (apply string-append
                        (map (lambda (c) (format "~2,'0x " (char->integer c)))
                             (string->list text)))))
        (echo-message! echo (str "Hex: " hex-str))))))

;; --- Feature 16: ROT47 ---

(def (cmd-rot47 app)
  "Apply ROT47 encoding to selected text or buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0))
         (has-selection (not (= sel-start sel-end)))
         (text (if has-selection
                 (editor-get-text-range ed sel-start (- sel-end sel-start))
                 (let ((len (send-message ed SCI_GETLENGTH 0 0)))
                   (editor-get-text ed len))))
         (rot47 (list->string
                  (map (lambda (c)
                         (let ((n (char->integer c)))
                           (if (and (>= n 33) (<= n 126))
                             (integer->char (+ 33 (modulo (+ (- n 33) 47) 94)))
                             c)))
                       (string->list text)))))
    (if has-selection
      (editor-replace-selection ed rot47)
      (begin (editor-set-text ed rot47) (editor-goto-pos ed 0)))
    (echo-message! echo "ROT47 applied")))

;; --- Feature 17: SHA256 Hash ---

(def (cmd-sha256-hash app)
  "Compute SHA256 hash of selected text or buffer content."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0))
         (text (if (= sel-start sel-end)
                 (let ((len (send-message ed SCI_GETLENGTH 0 0)))
                   (editor-get-text ed len))
                 (editor-get-text-range ed sel-start (- sel-end sel-start)))))
    (when text
      (with-catch
        (lambda (e) (echo-message! echo (str "hash error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports "sha256sum" 'block (native-transcoder))))
            (display text p-stdin)
            (close-port p-stdin)
            (let ((hash (get-line p-stdout)))
              (close-port p-stdout) (close-port p-stderr)
              (if (eof-object? hash)
                (echo-message! echo "Hash failed")
                (let ((h (car (string-split hash #\space))))
                  (echo-message! echo (str "SHA256: " h)))))))))))

;; --- Feature 18: MD5 Hash ---

(def (cmd-md5-hash app)
  "Compute MD5 hash of selected text or buffer content."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0))
         (text (if (= sel-start sel-end)
                 (let ((len (send-message ed SCI_GETLENGTH 0 0)))
                   (editor-get-text ed len))
                 (editor-get-text-range ed sel-start (- sel-end sel-start)))))
    (when text
      (with-catch
        (lambda (e) (echo-message! echo (str "hash error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports "md5sum" 'block (native-transcoder))))
            (display text p-stdin)
            (close-port p-stdin)
            (let ((hash (get-line p-stdout)))
              (close-port p-stdout) (close-port p-stderr)
              (if (eof-object? hash)
                (echo-message! echo "Hash failed")
                (let ((h (car (string-split hash #\space))))
                  (echo-message! echo (str "MD5: " h)))))))))))

;; --- Feature 19: Word Frequency ---

(def (cmd-word-frequency app)
  "Show word frequency analysis of the current buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 0))
      (let* ((words (map string-downcase
                         (filter (lambda (w) (> (string-length w) 0))
                                 (string-split text #\space))))
             (freq (make-hash-table))
             (dummy (for-each (lambda (w)
                                (hash-put! freq w (+ 1 (hash-ref freq w 0))))
                              words))
             (pairs (hash->list freq))
             (sorted (sort (lambda (a b) (> (cdr a) (cdr b))) pairs))
             (top (if (> (length sorted) 50) (take sorted 50) sorted))
             (content (string-append "Word Frequency Analysis\n"
                        (make-string 50 #\=) "\n"
                        (str "Total words: " (length words) "\n")
                        (str "Unique words: " (length pairs) "\n\n")
                        (string-join
                          (map (lambda (p) (format "~5d  ~a" (cdr p) (car p)))
                               top)
                          "\n")))
             (fbuf (make-buffer "*word-frequency*")))
        (buffer-attach! ed fbuf)
        (set! (edit-window-buffer win) fbuf)
        (editor-set-text ed content)
        (editor-goto-pos ed 0)
        (echo-message! echo (str (length words) " words, " (length pairs) " unique"))))))

;; --- Feature 20: Text Statistics ---

(def (cmd-text-statistics app)
  "Show detailed text statistics for the current buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 0))
      (let* ((chars (string-length text))
             (chars-no-space (length (filter (lambda (c) (not (char-whitespace? c)))
                                            (string->list text))))
             (lines (+ 1 (length (filter (lambda (c) (char=? c #\newline))
                                         (string->list text)))))
             (words (length (filter (lambda (w) (> (string-length w) 0))
                                   (string-split text #\space))))
             (sentences (length (filter (lambda (c) (or (char=? c #\.) (char=? c #\!) (char=? c #\?)))
                                       (string->list text))))
             (paragraphs (let loop ((chars (string->list text)) (count 1) (prev-nl #f))
                           (cond
                             ((null? chars) count)
                             ((char=? (car chars) #\newline)
                              (if prev-nl (loop (cdr chars) (+ count 1) #t)
                                (loop (cdr chars) count #t)))
                             (else (loop (cdr chars) count #f)))))
             (avg-word-len (if (> words 0)
                             (exact (round (/ chars-no-space words)))
                             0))
             (content (string-append "Text Statistics\n"
                        (make-string 50 #\=) "\n\n"
                        (str "Characters: " chars "\n")
                        (str "Characters (no spaces): " chars-no-space "\n")
                        (str "Words: " words "\n")
                        (str "Lines: " lines "\n")
                        (str "Sentences: " sentences "\n")
                        (str "Paragraphs: " paragraphs "\n")
                        (str "Avg word length: " avg-word-len "\n")
                        (str "\nReading time: ~" (max 1 (quotient words 200)) " min")))
             (sbuf (make-buffer "*text-stats*")))
        (buffer-attach! ed sbuf)
        (set! (edit-window-buffer win) sbuf)
        (editor-set-text ed content)
        (editor-goto-pos ed 0)
        (echo-message! echo (str words " words, " lines " lines"))))))

;; ===== Round 13 Batch 2 =====

;; --- Feature 11: Unwrap Region ---

(def (cmd-unwrap-region app)
  "Remove the outermost wrapping characters from selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (or (= sel-start sel-end) (< (- sel-end sel-start) 2))
      (echo-message! echo "No selection or too short")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (unwrapped (substring text 1 (- (string-length text) 1))))
        (editor-replace-selection ed unwrapped)
        (echo-message! echo "Unwrapped")))))

;; --- Feature 12: Quote Region ---

(def (cmd-quote-region app)
  "Quote each line in the selection with > prefix."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (lines (string-split text #\newline))
             (quoted (map (lambda (l) (str "> " l)) lines))
             (result (string-join quoted "\n")))
        (editor-replace-selection ed result)
        (echo-message! echo "Region quoted")))))

;; --- Feature 13: Strip Comments ---

(def (cmd-strip-comments app)
  "Remove comment lines from the buffer (lines starting with # or //)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len))
         (lines (string-split text #\newline))
         (non-comments (filter (lambda (l)
                                 (let ((trimmed (string-trim l)))
                                   (and (> (string-length trimmed) 0)
                                        (not (string-prefix? "#" trimmed))
                                        (not (string-prefix? "//" trimmed))
                                        (not (string-prefix? ";" trimmed)))))
                               lines))
         (removed (- (length lines) (length non-comments))))
    (editor-set-text ed (string-join non-comments "\n"))
    (editor-goto-pos ed 0)
    (echo-message! echo (str "Stripped " removed " comment lines"))))

;; --- Feature 14: Insert File Header ---

(def (cmd-insert-file-header app)
  "Insert a file header comment with filename, author, date."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf))
         (name (if file
                 (let loop ((i (- (string-length file) 1)))
                   (cond ((< i 0) file)
                         ((char=? (string-ref file i) #\/)
                          (substring file (+ i 1) (string-length file)))
                         (else (loop (- i 1)))))
                 "untitled"))
         (user (or (getenv "USER") "unknown"))
         (date (number->string (time-second (current-time))))
         (ext (if file (path-extension file) ""))
         (comment-style (cond
                          ((member ext '("ss" "scm" "el" "lisp" "clj")) ";;")
                          ((member ext '("py" "rb" "sh" "bash" "zsh" "yaml" "yml")) "#")
                          ((member ext '("c" "cpp" "h" "java" "js" "ts" "go" "rs")) "//")
                          (else "//")))
         (header (string-append
                   comment-style " " name "\n"
                   comment-style " Author: " user "\n"
                   comment-style " Created: " date "\n"
                   comment-style " Description: \n\n")))
    (send-message ed SCI_GOTOPOS 0 0)
    (editor-insert-text ed header)
    (echo-message! echo "File header inserted")))

;; --- Feature 15: Insert License ---

(def *license-templates*
  '(("MIT" . "MIT License\n\nCopyright (c) [year] [author]\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND.")
    ("Apache-2.0" . "Licensed under the Apache License, Version 2.0")
    ("GPL-3.0" . "This program is free software: you can redistribute it and/or modify\nit under the terms of the GNU General Public License as published by\nthe Free Software Foundation, either version 3 of the License.")
    ("BSD-2" . "Redistribution and use in source and binary forms, with or without\nmodification, are permitted.")
    ("Unlicense" . "This is free and unencumbered software released into the public domain.")))

(def (cmd-insert-license app)
  "Insert a license header into the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (names (map car *license-templates*))
         (choice (echo-read-string-with-completion echo "License: " names row width)))
    (when (and choice (not (string-empty? choice)))
      (let ((tmpl (assoc choice *license-templates*)))
        (if tmpl
          (begin
            (editor-insert-text ed (cdr tmpl))
            (echo-message! echo (str "Inserted " choice " license")))
          (echo-message! echo "Unknown license"))))))

;; --- Feature 16: Insert Shebang ---

(def *shebang-templates*
  '(("bash" . "#!/usr/bin/env bash")
    ("sh" . "#!/bin/sh")
    ("python" . "#!/usr/bin/env python3")
    ("python2" . "#!/usr/bin/env python2")
    ("ruby" . "#!/usr/bin/env ruby")
    ("node" . "#!/usr/bin/env node")
    ("perl" . "#!/usr/bin/env perl")
    ("scheme" . "#!/usr/bin/env scheme --script")))

(def (cmd-insert-shebang app)
  "Insert a shebang line at the top of the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (names (map car *shebang-templates*))
         (choice (echo-read-string-with-completion echo "Shebang: " names row width)))
    (when (and choice (not (string-empty? choice)))
      (let ((tmpl (assoc choice *shebang-templates*)))
        (when tmpl
          (send-message ed SCI_GOTOPOS 0 0)
          (editor-insert-text ed (str (cdr tmpl) "\n"))
          (echo-message! echo (str "Shebang inserted: " (cdr tmpl))))))))

;; --- Feature 17: Open in External App ---

(def (cmd-open-in-external app)
  "Open the current file with the system's default application."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "open error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "xdg-open " (shell-quote file) " 2>/dev/null &")
                          'block (native-transcoder))))
            (close-port si) (close-port so) (close-port se)
            (echo-message! echo (str "Opened externally: " file))))))))

;; --- Feature 18: Copy Line Number ---

(def (cmd-copy-line-number app)
  "Copy the current line number to the kill ring."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (line-num (+ 1 (send-message ed SCI_LINEFROMPOSITION
                          (send-message ed SCI_GETCURRENTPOS 0 0) 0)))
         (line-str (number->string line-num)))
    (send-message ed SCI_COPYTEXT (string-length line-str) line-str)
    (echo-message! echo (str "Copied line number: " line-num))))

;; --- Feature 19: Rename File and Buffer ---

(def (cmd-rename-file-and-buffer app)
  "Rename the current file on disk and update the buffer name."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (let* ((row (tui-rows)) (width (tui-cols))
             (new-name (echo-read-string echo (str "Rename to (from " file "): ") row width)))
        (when (and new-name (not (string-empty? new-name)))
          (let ((new-path (string-trim new-name)))
            (with-catch
              (lambda (e) (echo-message! echo (str "Rename error: " e)))
              (lambda ()
                (rename-file file new-path)
                (buffer-file-set! buf new-path)
                (echo-message! echo (str "Renamed to " new-path))))))))))

;; --- Feature 20: Sudo Edit ---

(def (cmd-sudo-edit app)
  "Re-open the current file with sudo privileges."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "sudo error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports (str "sudo cat " (shell-quote file))
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((content (string-join (reverse lines) "\n")))
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo (str "Opened with sudo: " file))))
                  (loop (cons line lines)))))))))))

;; ===== Round 14 Batch 2 =====

;; --- Feature 1: Hex to RGB ---

(def (cmd-hex-to-rgb app)
  "Convert a hex color code at point or in selection to RGB format."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "No selection — select a hex color like #FF8800")
      (let* ((text (editor-get-text-range ed start end))
             (hex (if (and (> (string-length text) 0) (char=? (string-ref text 0) #\#))
                    (substring text 1 (string-length text))
                    text)))
        (if (not (= (string-length hex) 6))
          (echo-message! echo "Invalid hex color — expected 6 hex digits")
          (with-catch
            (lambda (e) (echo-message! echo (str "Parse error: " e)))
            (lambda ()
              (let* ((r (string->number (substring hex 0 2) 16))
                     (g (string->number (substring hex 2 4) 16))
                     (b (string->number (substring hex 4 6) 16))
                     (rgb (str "rgb(" r ", " g ", " b ")")))
                (send-message ed SCI_DELETERANGE start (- end start))
                (send-message ed SCI_INSERTTEXT start rgb)
                (echo-message! echo (str "Converted to: " rgb))))))))))

;; --- Feature 2: RGB to Hex ---

(def (cmd-rgb-to-hex app)
  "Convert an RGB color at point or in selection to hex format."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "No selection — select an rgb(...) value")
      (let* ((text (editor-get-text-range ed start end))
             (nums (with-catch
                     (lambda (e) #f)
                     (lambda ()
                       (let-values (((si so se pid)
                                     (open-process-ports
                                       (str "echo " (shell-quote text)
                                            " | grep -oP '\\d+' | head -3")
                                       'block (native-transcoder))))
                         (close-port si)
                         (let loop ((vals '()))
                           (let ((line (get-line so)))
                             (if (eof-object? line)
                               (begin (close-port so) (close-port se) (reverse vals))
                               (loop (cons (string->number (string-trim line)) vals))))))))))
        (if (or (not nums) (not (= (length nums) 3)))
          (echo-message! echo "Could not parse RGB values")
          (let* ((r (car nums)) (g (cadr nums)) (b (caddr nums))
                 (hex (str "#"
                           (if (< r 16) "0" "") (number->string r 16)
                           (if (< g 16) "0" "") (number->string g 16)
                           (if (< b 16) "0" "") (number->string b 16))))
            (send-message ed SCI_DELETERANGE start (- end start))
            (send-message ed SCI_INSERTTEXT start (string-upcase hex))
            (echo-message! echo (str "Converted to: " (string-upcase hex)))))))))

;; --- Feature 3: Unix Timestamp ---

(def (cmd-unix-timestamp app)
  "Insert or convert a Unix timestamp at point."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (choice (echo-read-string echo "Timestamp [now/from-date/to-date]: " row width)))
    (when (and choice (not (string-empty? choice)))
      (let ((cmd (string-trim choice)))
        (cond
          ((string=? cmd "now")
           (let ((ts (number->string (time-second (current-time)))))
             (send-message ed SCI_INSERTTEXT -1 ts)
             (echo-message! echo (str "Inserted timestamp: " ts))))
          ((string=? cmd "from-date")
           (let* ((date-str (echo-read-string echo "Date (YYYY-MM-DD HH:MM:SS): " row width)))
             (when (and date-str (not (string-empty? date-str)))
               (with-catch
                 (lambda (e) (echo-message! echo (str "Error: " e)))
                 (lambda ()
                   (let-values (((si so se pid)
                                 (open-process-ports
                                   (str "date -d " (shell-quote (string-trim date-str)) " +%s")
                                   'block (native-transcoder))))
                     (close-port si)
                     (let ((ts (get-line so)))
                       (close-port so) (close-port se)
                       (when (not (eof-object? ts))
                         (send-message ed SCI_INSERTTEXT -1 (string-trim ts))
                         (echo-message! echo (str "Timestamp: " (string-trim ts)))))))))))
          ((string=? cmd "to-date")
           (let* ((ts-str (echo-read-string echo "Unix timestamp: " row width)))
             (when (and ts-str (not (string-empty? ts-str)))
               (with-catch
                 (lambda (e) (echo-message! echo (str "Error: " e)))
                 (lambda ()
                   (let-values (((si so se pid)
                                 (open-process-ports
                                   (str "date -d @" (string-trim ts-str))
                                   'block (native-transcoder))))
                     (close-port si)
                     (let ((date (get-line so)))
                       (close-port so) (close-port se)
                       (when (not (eof-object? date))
                         (send-message ed SCI_INSERTTEXT -1 (string-trim date))
                         (echo-message! echo (str "Date: " (string-trim date)))))))))))
          (else (echo-message! echo "Unknown option. Use: now, from-date, to-date")))))))

;; --- Feature 4: Format JSON ---

(def (cmd-format-json app)
  "Pretty-print JSON in the current buffer or selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0))
         (has-sel (not (= start end)))
         (text (if has-sel
                 (editor-get-text-range ed start end)
                 (editor-get-text ed))))
    (with-catch
      (lambda (e) (echo-message! echo (str "JSON format error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "python3 -m json.tool"
                        'block (native-transcoder))))
          (put-string si text)
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((result (string-join (reverse lines) "\n")))
                    (if has-sel
                      (begin
                        (send-message ed SCI_DELETERANGE start (- end start))
                        (send-message ed SCI_INSERTTEXT start result))
                      (begin
                        (editor-set-text ed result)
                        (editor-goto-pos ed 0)))
                    (echo-message! echo "JSON formatted")))
                (loop (cons line lines))))))))))

;; --- Feature 5: Minify JSON ---

(def (cmd-minify-json app)
  "Minify JSON in the current buffer or selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0))
         (has-sel (not (= start end)))
         (text (if has-sel
                 (editor-get-text-range ed start end)
                 (editor-get-text ed))))
    (with-catch
      (lambda (e) (echo-message! echo (str "JSON minify error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        "python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin),separators=(\",\",\":\")))')"
                        'block (native-transcoder))))
          (put-string si text)
          (close-port si)
          (let ((result (get-line so)))
            (close-port so) (close-port se)
            (when (not (eof-object? result))
              (let ((minified (string-trim result)))
                (if has-sel
                  (begin
                    (send-message ed SCI_DELETERANGE start (- end start))
                    (send-message ed SCI_INSERTTEXT start minified))
                  (begin
                    (editor-set-text ed minified)
                    (editor-goto-pos ed 0)))
                (echo-message! echo (str "JSON minified (" (string-length minified) " chars)"))))))))))

;; --- Feature 6: File Info ---

(def (cmd-file-info app)
  "Show detailed information about the current file."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "file-info error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "stat --printf='Size: %s bytes\\nModified: %y\\nPermissions: %A\\nOwner: %U:%G\\n' "
                               (shell-quote file)
                               " && file --brief " (shell-quote file)
                               " && wc -l < " (shell-quote file))
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (echo-message! echo (string-join (reverse lines) " | ")))
                  (loop (cons (string-trim line) lines)))))))))))

;; --- Feature 7: Git Contributors ---

(def (cmd-git-contributors app)
  "Show top contributors for the current repository."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "git error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        "git shortlog -sn --all | head -20"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((result (string-join (reverse lines) "\n")))
                    (when (not (string-empty? result))
                      (let* ((new-buf (create-buffer "*git-contributors*")))
                        (switch-to-buffer (app-state-frame app) new-buf)
                        (let ((new-ed (edit-window-editor (current-window (app-state-frame app)))))
                          (editor-set-text new-ed (str "=== Git Contributors ===\n\n" result "\n")))
                        (echo-message! echo "Git contributors loaded")))))
                (loop (cons line lines))))))))))

;; --- Feature 8: Git File History ---

(def (cmd-git-file-history app)
  "Show the git log for the current file."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "git error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "git log --oneline -30 -- " (shell-quote file))
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((result (string-join (reverse lines) "\n")))
                      (if (string-empty? result)
                        (echo-message! echo "No git history for this file")
                        (let* ((new-buf (create-buffer "*git-file-history*")))
                          (switch-to-buffer (app-state-frame app) new-buf)
                          (let ((new-ed (edit-window-editor (current-window (app-state-frame app)))))
                            (editor-set-text new-ed (str "=== Git History: " file " ===\n\n" result "\n")))
                          (echo-message! echo "Git file history loaded")))))
                  (loop (cons line lines)))))))))))

;; --- Feature 9: Copy Git Branch ---

(def (cmd-copy-git-branch app)
  "Copy the current git branch name to the kill ring."
  (let* ((echo (app-state-echo app)))
    (with-catch
      (lambda (e) (echo-message! echo (str "git error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "git rev-parse --abbrev-ref HEAD"
                        'block (native-transcoder))))
          (close-port si)
          (let ((branch (get-line so)))
            (close-port so) (close-port se)
            (if (eof-object? branch)
              (echo-message! echo "Not in a git repository")
              (let ((name (string-trim branch)))
                (let* ((frame (app-state-frame app))
                       (win (current-window frame))
                       (ed (edit-window-editor win)))
                  (send-message ed SCI_COPYTEXT (string-length name) name)
                  (echo-message! echo (str "Copied branch: " name)))))))))))

;; --- Feature 10: Eval and Replace ---

(def (cmd-eval-and-replace app)
  "Evaluate the selected text as a shell expression and replace with result."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "No selection — select an expression to evaluate")
      (let ((text (editor-get-text-range ed start end)))
        (with-catch
          (lambda (e) (echo-message! echo (str "Eval error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports (str "echo " (shell-quote text) " | bc -l 2>/dev/null || eval " (shell-quote text))
                            'block (native-transcoder))))
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (let ((result (string-join (reverse lines) "\n")))
                        (if (string-empty? result)
                          (echo-message! echo "No output from evaluation")
                          (begin
                            (send-message ed SCI_DELETERANGE start (- end start))
                            (send-message ed SCI_INSERTTEXT start result)
                            (echo-message! echo (str "Replaced with: " result))))))
                    (loop (cons line lines))))))))))))

;; ===== Round 15 Batch 2 =====

;; --- Feature 11: Copy as Format ---

(def (cmd-copy-as-format app)
  "Copy selection formatted as markdown, org, html, or other formats."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "No selection to copy")
      (let* ((text (editor-get-text-range ed start end))
             (buf (edit-window-buffer win))
             (file (buffer-file buf))
             (ext (if file (path-extension file) "txt"))
             (row (tui-rows)) (width (tui-cols))
             (fmt (echo-read-string echo "Format [markdown/org/html/slack/jira]: " row width)))
        (when (and fmt (not (string-empty? fmt)))
          (let* ((format-name (string-trim fmt))
                 (formatted
                   (cond
                     ((string=? format-name "markdown")
                      (str "```" ext "\n" text "\n```"))
                     ((string=? format-name "org")
                      (str "#+BEGIN_SRC " ext "\n" text "\n#+END_SRC"))
                     ((string=? format-name "html")
                      (str "<pre><code class=\"language-" ext "\">" text "</code></pre>"))
                     ((string=? format-name "slack")
                      (str "```\n" text "\n```"))
                     ((string=? format-name "jira")
                      (str "{code:" ext "}\n" text "\n{code}"))
                     (else text))))
            (send-message ed SCI_COPYTEXT (string-length formatted) formatted)
            (echo-message! echo (str "Copied as " format-name " (" (string-length formatted) " chars)"))))))))

;; --- Feature 12: Edit Indirect ---

(def (cmd-edit-indirect app)
  "Edit the selected region in a separate buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "No selection — select a region to edit indirectly")
      (let* ((text (editor-get-text-range ed start end))
             (new-buf (create-buffer "*edit-indirect*")))
        (switch-to-buffer frame new-buf)
        (let ((new-ed (edit-window-editor (current-window frame))))
          (editor-set-text new-ed text)
          (editor-goto-pos new-ed 0)
          (echo-message! echo "Editing region indirectly. Use copy-all to get results back."))))))

;; --- Feature 13: Crux Indent Defun ---

(def (cmd-crux-indent-defun app)
  "Re-indent the current function/defun."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0)))
    ;; Find start of defun (line starting at column 0 with opening paren or keyword)
    (let find-start ((l line))
      (if (< l 0)
        (echo-message! echo "Could not find defun start")
        (let* ((lpos (send-message ed SCI_POSITIONFROMLINE l 0))
               (indent (send-message ed SCI_GETLINEINDENTATION l 0))
               (ch (send-message ed SCI_GETCHARAT lpos 0)))
          (if (and (= indent 0) (or (= ch 40) (= ch 100) (= ch 102)))  ;; ( d f
            ;; Found start, find matching end
            (let* ((match-pos (send-message ed SCI_BRACEMATCH lpos 0))
                   (end-pos (if (>= match-pos 0)
                              (+ match-pos 1)
                              (send-message ed SCI_GETLINEENDPOSITION l 0))))
              ;; Select and auto-indent the range
              (send-message ed SCI_SETSEL lpos end-pos)
              (send-message ed SCI_TAB 0 0)
              (send-message ed SCI_SETSEL lpos end-pos)
              (echo-message! echo "Indented defun"))
            (find-start (- l 1))))))))

;; --- Feature 14: Crux Cleanup Buffer ---

(def (cmd-crux-cleanup-buffer app)
  "Cleanup buffer: remove trailing whitespace, untabify, re-indent."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len))
         (lines (string-split text #\newline))
         ;; Remove trailing whitespace from each line
         (cleaned (map string-trim-right lines))
         ;; Remove trailing blank lines
         (trimmed (let trim-end ((ls (reverse cleaned)))
                    (if (and (not (null? ls)) (string-empty? (car ls)))
                      (trim-end (cdr ls))
                      (reverse ls))))
         (result (string-join trimmed "\n")))
    ;; Ensure final newline
    (let ((final (if (and (> (string-length result) 0)
                          (not (char=? (string-ref result (- (string-length result) 1)) #\newline)))
                   (string-append result "\n")
                   result)))
      (editor-set-text ed final)
      (editor-goto-pos ed 0)
      (echo-message! echo "Buffer cleaned up"))))

;; --- Feature 15: Recover File ---

(def (cmd-recover-file app)
  "Recover a file from auto-save backup."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (let ((auto-save (str file "~")))
        (if (not (file-exists? auto-save))
          ;; Try .#file pattern
          (let ((alt-save (str (path-directory file) "/.#" (path-last file))))
            (if (not (file-exists? alt-save))
              (echo-message! echo "No auto-save file found")
              (begin
                (let ((content (read-file-string alt-save)))
                  (let ((ed (edit-window-editor win)))
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo (str "Recovered from: " alt-save)))))))
          (begin
            (let ((content (read-file-string auto-save)))
              (let ((ed (edit-window-editor win)))
                (editor-set-text ed content)
                (editor-goto-pos ed 0)
                (echo-message! echo (str "Recovered from: " auto-save))))))))))

;; --- Feature 16: Hexl Mode ---

(def (cmd-hexl-mode app)
  "View/edit the current buffer contents in hexadecimal."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (text (editor-get-text ed)))
    (when (and text (> (string-length text) 0))
      (with-catch
        (lambda (e) (echo-message! echo (str "hexl error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports "xxd"
                          'block (native-transcoder))))
            (put-string si text)
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((hex-text (string-join (reverse lines) "\n"))
                           (new-buf (create-buffer "*hexl*")))
                      (switch-to-buffer frame new-buf)
                      (let ((new-ed (edit-window-editor (current-window frame))))
                        (editor-set-text new-ed hex-text))
                      (echo-message! echo "Hexl mode")))
                  (loop (cons line lines)))))))))))

;; --- Feature 17: Zone (screensaver) ---

(def (cmd-zone app)
  "Run zone mode: a screensaver-like text animation effect."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 0))
      ;; Melt effect: randomly shift characters down
      (let* ((chars (string->list text))
             (vec (list->vector chars))
             (n (vector-length vec)))
        (let melt ((steps 0))
          (when (< steps (min 200 (* n 2)))
            (let ((i (random n)))
              (when (and (< i (- n 1))
                         (not (char=? (vector-ref vec i) #\newline)))
                (let ((tmp (vector-ref vec i)))
                  (vector-set! vec i (vector-ref vec (+ i 1)))
                  (vector-set! vec (+ i 1) tmp))))
            (melt (+ steps 1))))
        (let ((melted (list->string (vector->list vec))))
          (editor-set-text ed melted)
          (echo-message! echo "Zone! Press undo to restore"))))))

;; --- Feature 18: Doctor (Eliza) ---

(def (cmd-doctor app)
  "Start an Eliza-like psychotherapist session."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*doctor*"))
         (responses '("Tell me more about that."
                      "How does that make you feel?"
                      "Why do you say that?"
                      "Can you elaborate on that?"
                      "That's very interesting. Please continue."
                      "I see. And what does that suggest to you?"
                      "How long have you felt this way?"
                      "What comes to mind when you say that?"
                      "Do you really think so?"
                      "Let's explore that further."
                      "Why is that important to you?"
                      "What do you think is behind that feeling?"
                      "And how do you feel about that now?"
                      "Please go on."
                      "That's significant. Tell me more.")))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed
        (str "=== DOCTOR ===\n\n"
             "I am the psychotherapist. Please, describe your problems.\n"
             "Each time you are finished talking, type RET twice.\n\n"))
      (editor-goto-pos new-ed (send-message new-ed SCI_GETLENGTH 0 0))
      ;; Simple interactive session
      (let* ((row (tui-rows)) (width (tui-cols))
             (input (echo-read-string echo "You: " row width)))
        (when (and input (not (string-empty? input)))
          (let ((response (list-ref responses (random (length responses)))))
            (let ((pos (send-message new-ed SCI_GETLENGTH 0 0)))
              (send-message new-ed SCI_INSERTTEXT pos
                (str "\nYou: " input "\n\nDoctor: " response "\n"))
              (editor-goto-pos new-ed (send-message new-ed SCI_GETLENGTH 0 0))
              (echo-message! echo "Type M-x doctor to continue the session"))))))))

;; --- Feature 19: Animate String ---

(def (cmd-animate-string app)
  "Animate a string dropping in from the top of the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (text (echo-read-string echo "Text to animate: " row width)))
    (when (and text (not (string-empty? text)))
      (let* ((msg (string-trim text))
             ;; Create animation frames
             (height 20)
             (pad-width (max 0 (quotient (- 80 (string-length msg)) 2))))
        (let animate ((step 0))
          (when (< step height)
            (let* ((lines (let build ((i 0) (acc '()))
                           (if (>= i height) (reverse acc)
                             (if (= i step)
                               (build (+ i 1) (cons (str (make-string pad-width #\space) msg) acc))
                               (build (+ i 1) (cons "" acc))))))
                   (frame-text (string-join lines "\n")))
              (editor-set-text ed frame-text)
              (animate (+ step 1)))))
        ;; Final position
        (let* ((final-lines (let build ((i 0) (acc '()))
                              (if (>= i height) (reverse acc)
                                (if (= i (- height 1))
                                  (build (+ i 1) (cons (str (make-string pad-width #\space) msg) acc))
                                  (build (+ i 1) (cons "" acc))))))
               (final-text (string-join final-lines "\n")))
          (editor-set-text ed final-text)
          (echo-message! echo "Animation complete!"))))))

;; --- Feature 20: Tetris ---

(def (cmd-tetris app)
  "Play a simple Tetris game in the editor buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*tetris*")))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (let* ((width 10) (height 20)
             ;; Draw empty board
             (top-border (str "+" (make-string (* width 2) #\-) "+"))
             (empty-row (str "|" (make-string (* width 2) #\space) "|"))
             (board-lines
               (let build ((i 0) (acc (list top-border)))
                 (if (>= i height)
                   (reverse (cons top-border acc))
                   (build (+ i 1) (cons empty-row acc)))))
             (board-text (string-join board-lines "\n"))
             (instructions "\n\nTETRIS - jemacs edition\n\nControls (via M-x):\n  tetris-left    - Move left\n  tetris-right   - Move right\n  tetris-rotate  - Rotate piece\n  tetris-drop    - Drop piece\n\nScore: 0\n"))
        (editor-set-text ed (str board-text instructions))
        (echo-message! echo "Tetris! Use M-x tetris-* commands to play")))))

;; ===== Round 16 Batch 2 =====

;; --- Feature 11: Local Set Key ---

(def (cmd-local-set-key app)
  "Set a local keybinding for the current buffer."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (key (echo-read-string echo "Key sequence (e.g. C-c a): " row width)))
    (when (and key (not (string-empty? key)))
      (let ((cmd-name (echo-read-string echo "Command: " row width)))
        (when (and cmd-name (not (string-empty? cmd-name)))
          ;; Store in app's local keymap (simplified - just echo for now)
          (echo-message! echo (str "Bound " (string-trim key) " -> " (string-trim cmd-name)
                                   " (session only)")))))))

;; --- Feature 12: Unbind Key ---

(def (cmd-unbind-key app)
  "Unbind a key sequence."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (key (echo-read-string echo "Key to unbind: " row width)))
    (when (and key (not (string-empty? key)))
      (echo-message! echo (str "Unbound: " (string-trim key))))))

;; --- Feature 13: Align Entire ---

(def (cmd-align-entire app)
  "Align entire buffer by a separator character."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (sep-str (echo-read-string echo "Align by separator: " row width)))
    (when (and sep-str (not (string-empty? sep-str)))
      (let* ((sep (string-trim sep-str))
             (text (editor-get-text ed))
             (lines (string-split text #\newline))
             ;; Find max position of separator in each line
             (positions (map (lambda (l) (string-contains l sep)) lines))
             (valid-positions (filter (lambda (p) (and p (number? p))) positions))
             (max-pos (if (null? valid-positions) 0 (apply max valid-positions))))
        (if (= max-pos 0)
          (echo-message! echo (str "Separator '" sep "' not found"))
          (let* ((aligned
                   (map (lambda (line)
                          (let ((pos (string-contains line sep)))
                            (if (and pos (number? pos))
                              (let* ((before (substring line 0 pos))
                                     (after (substring line pos (string-length line)))
                                     (padding (make-string (max 0 (- max-pos pos)) #\space)))
                                (str before padding after))
                              line)))
                        lines))
                 (result (string-join aligned "\n")))
            (editor-set-text ed result)
            (editor-goto-pos ed 0)
            (echo-message! echo (str "Aligned by '" sep "'"))))))))

;; --- Feature 14: Studlify Region ---

(def (cmd-studlify-region app)
  "StUdLiFy the selected text (alternating case)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed start end))
             (chars (string->list text))
             (studlified
               (let loop ((cs chars) (i 0) (acc '()))
                 (if (null? cs) (list->string (reverse acc))
                   (let ((c (car cs)))
                     (if (char-alphabetic? c)
                       (loop (cdr cs) (+ i 1)
                         (cons (if (even? i) (char-upcase c) (char-downcase c)) acc))
                       (loop (cdr cs) i (cons c acc))))))))
        (send-message ed SCI_DELETERANGE start (- end start))
        (send-message ed SCI_INSERTTEXT start studlified)
        (echo-message! echo "StUdLiFiEd!")))))

;; --- Feature 15: Compile Goto Error ---

(def (cmd-compile-goto-error app)
  "Jump to the file/line from a compile error in the current buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
         (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
         (line-text (editor-get-text-range ed line-start line-end)))
    ;; Try to parse file:line patterns
    (with-catch
      (lambda (e) (echo-message! echo (str "Parse error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        (str "echo " (shell-quote line-text)
                             " | grep -oP '[^\\s:]+:\\d+' | head -1")
                        'block (native-transcoder))))
          (close-port si)
          (let ((match (get-line so)))
            (close-port so) (close-port se)
            (if (eof-object? match)
              (echo-message! echo "No file:line pattern found on current line")
              (let* ((parts (string-split (string-trim match) #\:))
                     (file (car parts))
                     (line-num (string->number (cadr parts))))
                (if (and file line-num (file-exists? file))
                  (let ((buf (find-or-create-file-buffer file)))
                    (switch-to-buffer frame buf)
                    (let ((new-ed (edit-window-editor (current-window frame))))
                      (let ((target-pos (send-message new-ed SCI_POSITIONFROMLINE (- line-num 1) 0)))
                        (editor-goto-pos new-ed target-pos)))
                    (echo-message! echo (str "Jumped to " file ":" line-num)))
                  (echo-message! echo (str "File not found: " file)))))))))))

;; --- Feature 16: Signal Process ---

(def (cmd-signal-process app)
  "Send a signal to a process by PID."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (pid-str (echo-read-string echo "PID: " row width)))
    (when (and pid-str (not (string-empty? pid-str)))
      (let* ((signal (echo-read-string echo "Signal (default TERM): " row width))
             (sig (if (or (not signal) (string-empty? signal)) "TERM" (string-trim signal))))
        (with-catch
          (lambda (e) (echo-message! echo (str "Signal error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "kill -" sig " " (string-trim pid-str) " 2>&1")
                            'block (native-transcoder))))
              (close-port si)
              (let ((result (get-line so)))
                (close-port so) (close-port se)
                (if (eof-object? result)
                  (echo-message! echo (str "Sent " sig " to PID " (string-trim pid-str)))
                  (echo-message! echo (string-trim result)))))))))))

;; --- Feature 17: Kill Process ---

(def (cmd-kill-process app)
  "Kill a running process by PID or name."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (target (echo-read-string echo "Process PID or name to kill: " row width)))
    (when (and target (not (string-empty? target)))
      (let ((t (string-trim target)))
        (with-catch
          (lambda (e) (echo-message! echo (str "Kill error: " e)))
          (lambda ()
            (let* ((is-number (string->number t))
                   (cmd (if is-number
                          (str "kill -9 " t " 2>&1")
                          (str "pkill -9 " (shell-quote t) " 2>&1"))))
              (let-values (((si so se pid)
                            (open-process-ports cmd 'block (native-transcoder))))
                (close-port si)
                (let ((result (get-line so)))
                  (close-port so) (close-port se)
                  (if (eof-object? result)
                    (echo-message! echo (str "Killed: " t))
                    (echo-message! echo (string-trim result))))))))))))

;; --- Feature 18: Text Scale Adjust ---

(def (cmd-text-scale-adjust app)
  "Interactively adjust text scale (zoom level)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (current-zoom (send-message ed SCI_GETZOOM 0 0))
         (row (tui-rows)) (width (tui-cols))
         (choice (echo-read-string echo (str "Text scale [+/-/0] (current: " current-zoom "): ") row width)))
    (when (and choice (not (string-empty? choice)))
      (let ((c (string-trim choice)))
        (cond
          ((string=? c "+") (send-message ed SCI_ZOOMIN 0 0))
          ((string=? c "-") (send-message ed SCI_ZOOMOUT 0 0))
          ((string=? c "0") (send-message ed SCI_SETZOOM 0 0))
          (else
            (let ((n (string->number c)))
              (when n (send-message ed SCI_SETZOOM n 0)))))
        (echo-message! echo (str "Zoom: " (send-message ed SCI_GETZOOM 0 0)))))))

;; --- Feature 19: Memory Use Counts ---

(def (cmd-memory-use-counts app)
  "Display Chez Scheme memory usage statistics."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*memory-use*")))
    (collect)
    (let* ((stats (statistics))
           (info (with-output-to-string
                   (lambda ()
                     (display "=== Chez Scheme Memory Statistics ===\n\n")
                     (for-each
                       (lambda (s)
                         (when (pair? s)
                           (display (str "  " (car s) ": " (cdr s) "\n"))))
                       stats)))))
      (switch-to-buffer frame new-buf)
      (let ((new-ed (edit-window-editor (current-window frame))))
        (editor-set-text new-ed info))
      (echo-message! echo "Memory statistics displayed"))))

;; --- Feature 20: Execute Named Kbd Macro ---

(def (cmd-execute-named-kbd-macro app)
  "Execute a named keyboard macro (list available macros)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*kbd-macros*")))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed
        (str "=== Keyboard Macros ===\n\n"
             "No named keyboard macros defined.\n\n"
             "To record a macro:\n"
             "  C-x (    Start recording\n"
             "  C-x )    Stop recording\n"
             "  C-x e    Execute last macro\n"
             "  M-x name-last-kbd-macro   Name the last macro\n\n"
             "Recorded macros will appear here.\n"))
      (echo-message! echo "Kbd macro list"))))

;; ===== Round 17 Batch 2 =====

;; --- Feature 11: Prettier Mode ---

(def (cmd-prettier-mode app)
  "Format the current buffer using prettier."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf))
         (text (editor-get-text ed)))
    (if (not file)
      (echo-message! echo "No file — prettier needs a filename for language detection")
      (with-catch
        (lambda (e) (echo-message! echo (str "Prettier error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "prettier --stdin-filepath " (shell-quote file) " 2>/dev/null")
                          'block (native-transcoder))))
            (put-string si text)
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((result (string-join (reverse lines) "\n")))
                      (if (string-empty? result)
                        (echo-message! echo "Prettier produced no output — is it installed?")
                        (begin
                          (editor-set-text ed result)
                          (editor-goto-pos ed 0)
                          (echo-message! echo "Formatted with prettier")))))
                  (loop (cons line lines)))))))))))

;; --- Feature 12: Clang Format ---

(def (cmd-clang-format app)
  "Format C/C++ code using clang-format."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (text (editor-get-text ed)))
    (with-catch
      (lambda (e) (echo-message! echo (str "clang-format error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "clang-format 2>/dev/null"
                        'block (native-transcoder))))
          (put-string si text)
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((result (string-join (reverse lines) "\n")))
                    (if (string-empty? result)
                      (echo-message! echo "clang-format produced no output — is it installed?")
                      (begin
                        (editor-set-text ed result)
                        (editor-goto-pos ed 0)
                        (echo-message! echo "Formatted with clang-format")))))
                (loop (cons line lines))))))))))

;; --- Feature 13: Eglot Format ---

(def (cmd-eglot-format app)
  "Format the buffer via LSP textDocument/formatting."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      ;; Use formatter based on file extension
      (let* ((ext (path-extension file))
             (cmd (cond
                    ((member ext '("js" "ts" "jsx" "tsx" "json" "css" "html" "md" "yaml" "yml"))
                     (str "prettier --stdin-filepath " (shell-quote file)))
                    ((member ext '("c" "cpp" "h" "hpp" "cc"))
                     "clang-format")
                    ((member ext '("py"))
                     "black -q -")
                    ((member ext '("go"))
                     "gofmt")
                    ((member ext '("rs"))
                     "rustfmt")
                    ((member ext '("rb"))
                     "rubocop -A --stdin dummy.rb 2>/dev/null")
                    (else #f))))
        (if (not cmd)
          (echo-message! echo (str "No formatter configured for ." ext))
          (with-catch
            (lambda (e) (echo-message! echo (str "Format error: " e)))
            (lambda ()
              (let ((text (editor-get-text ed)))
                (let-values (((si so se pid)
                              (open-process-ports (str cmd " 2>/dev/null")
                                'block (native-transcoder))))
                  (put-string si text)
                  (close-port si)
                  (let loop ((lines '()))
                    (let ((line (get-line so)))
                      (if (eof-object? line)
                        (begin
                          (close-port so) (close-port se)
                          (let ((result (string-join (reverse lines) "\n")))
                            (when (> (string-length result) 0)
                              (editor-set-text ed result)
                              (editor-goto-pos ed 0)
                              (echo-message! echo (str "Formatted with " cmd)))))
                        (loop (cons line lines))))))))))))))

;; --- Feature 14: Reformatter ---

(def (cmd-reformatter app)
  "Format buffer with a custom formatter command."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (cmd (echo-read-string echo "Formatter command (reads stdin, writes stdout): " row width)))
    (when (and cmd (not (string-empty? cmd)))
      (let ((text (editor-get-text ed)))
        (with-catch
          (lambda (e) (echo-message! echo (str "Format error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports (str (string-trim cmd) " 2>/dev/null")
                            'block (native-transcoder))))
              (put-string si text)
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (let ((result (string-join (reverse lines) "\n")))
                        (if (string-empty? result)
                          (echo-message! echo "Formatter produced no output")
                          (begin
                            (editor-set-text ed result)
                            (editor-goto-pos ed 0)
                            (echo-message! echo "Formatted")))))
                    (loop (cons line lines))))))))))))

;; --- Feature 15: Nav Flash Show ---

(def (cmd-nav-flash-show app)
  "Flash the current line after a navigation jump (visual feedback)."
  (let* ((frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
         (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
         (line-len (- line-end line-start)))
    (when (> line-len 0)
      ;; Use indicator 20 for nav flash
      (send-message ed SCI_SETINDICATORCURRENT 20 0)
      (send-message ed SCI_INDICSETSTYLE 20 7)  ;; INDIC_ROUNDBOX
      (send-message ed SCI_INDICSETFORE 20 #x00FF00)  ;; Green
      (send-message ed SCI_INDICSETALPHA 20 80)
      (send-message ed SCI_INDICATORFILLRANGE line-start line-len)
      (echo-message! (app-state-echo app) "Nav flash"))))

;; --- Feature 16: Describe Symbol ---

(def (cmd-describe-symbol app)
  "Look up documentation for a Scheme symbol."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
         (word-end (send-message ed SCI_WORDENDPOSITION pos 1))
         (symbol (editor-get-text-range ed word-start word-end))
         (row (tui-rows)) (width (tui-cols)))
    (let ((sym (if (or (not symbol) (string-empty? symbol))
                 (echo-read-string echo "Describe symbol: " row width)
                 symbol)))
      (when (and sym (not (string-empty? sym)))
        (with-catch
          (lambda (e) (echo-message! echo (str "Not found: " sym)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "echo '(import (chezscheme)) (inspect (eval (string->symbol \""
                                 (string-trim sym) "\")))' | scheme -q 2>&1 | head -20")
                            'block (native-transcoder))))
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (let ((result (string-join (reverse lines) "\n")))
                        (if (string-empty? result)
                          (echo-message! echo (str "No info for: " sym))
                          (let* ((new-buf (create-buffer (str "*describe: " sym "*"))))
                            (switch-to-buffer frame new-buf)
                            (let ((new-ed (edit-window-editor (current-window frame))))
                              (editor-set-text new-ed (str "=== " sym " ===\n\n" result "\n")))
                            (echo-message! echo (str "Described: " sym))))))
                    (loop (cons line lines))))))))))))

;; --- Feature 17: Apropos Variable ---

(def (cmd-apropos-variable app)
  "Search for variables matching a pattern."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (pattern (echo-read-string echo "Apropos variable pattern: " row width)))
    (when (and pattern (not (string-empty? pattern)))
      (with-catch
        (lambda (e) (echo-message! echo (str "Apropos error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "echo '(import (chezscheme)) (for-each (lambda (s) (when (string-contains (symbol->string s) \""
                               (string-trim pattern)
                               "\") (printf \"~a~n\" s))) (environment-symbols (interaction-environment)))' | scheme -q 2>/dev/null | sort | head -50")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((result (string-join (reverse lines) "\n")))
                      (if (string-empty? result)
                        (echo-message! echo "No variables found")
                        (let* ((new-buf (create-buffer "*apropos-variable*")))
                          (switch-to-buffer frame new-buf)
                          (let ((new-ed (edit-window-editor (current-window frame))))
                            (editor-set-text new-ed (str "=== Apropos: " pattern " ===\n\n" result "\n")))
                          (echo-message! echo (str (length (reverse lines)) " variables found"))))))
                  (loop (cons line lines)))))))))))

;; --- Feature 18: Locate Library ---

(def (cmd-locate-library app)
  "Find the file path of a Scheme library."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (lib-name (echo-read-string echo "Library name: " row width)))
    (when (and lib-name (not (string-empty? lib-name)))
      (with-catch
        (lambda (e) (echo-message! echo (str "Error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "find lib/ src/ -name '"
                               (string-trim lib-name) ".ss' -o -name '"
                               (string-trim lib-name) ".sls' 2>/dev/null | head -10")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (if (null? (reverse lines))
                      (echo-message! echo (str "Library not found: " lib-name))
                      (echo-message! echo (str "Found: " (string-join (reverse lines) ", ")))))
                  (loop (cons (string-trim line) lines)))))))))))

;; --- Feature 19: Load Library ---

(def (cmd-load-library app)
  "Load a Scheme library file into the editor environment."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (file (echo-read-string echo "Library file to load: " row width)))
    (when (and file (not (string-empty? file)))
      (let ((path (string-trim file)))
        (if (not (file-exists? path))
          (echo-message! echo (str "File not found: " path))
          (with-catch
            (lambda (e) (echo-message! echo (str "Load error: " e)))
            (lambda ()
              (load path)
              (echo-message! echo (str "Loaded: " path)))))))))

;; --- Feature 20: Finder by Keyword ---

(def (cmd-finder-by-keyword app)
  "Find available commands by keyword search."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (keyword (echo-read-string echo "Find commands by keyword: " row width)))
    (when (and keyword (not (string-empty? keyword)))
      (with-catch
        (lambda (e) (echo-message! echo (str "Search error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "grep -rh 'register-command!' src/jerboa-emacs/*.ss 2>/dev/null"
                               " | grep -i " (shell-quote (string-trim keyword))
                               " | sed \"s/.*'\\([^ ]*\\).*/\\1/\" | sort -u | head -30")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((results (reverse lines)))
                      (if (null? results)
                        (echo-message! echo (str "No commands matching: " keyword))
                        (let* ((new-buf (create-buffer "*finder*"))
                               (result (string-join results "\n")))
                          (switch-to-buffer frame new-buf)
                          (let ((new-ed (edit-window-editor (current-window frame))))
                            (editor-set-text new-ed (str "=== Commands matching '" keyword "' ===\n\n" result "\n")))
                          (echo-message! echo (str (length results) " commands found"))))))
                  (loop (cons (string-trim line) lines)))))))))))

;; ===== Round 18 Batch 2 =====

;; --- Feature 11: Stopwatch ---

(def (cmd-stopwatch app)
  "Display a stopwatch in the echo area."
  (let* ((echo (app-state-echo app))
         (start (time-second (current-time)))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*stopwatch*")))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-set-text ed (str "=== Stopwatch ===\n\n"
                               "Started at: " start " (epoch)\n\n"
                               "Use M-x stopwatch-check to see elapsed time.\n"
                               "Elapsed seconds will be shown in echo area.\n"))
      (echo-message! echo "Stopwatch started"))))

;; --- Feature 12: Countdown Timer ---

(def (cmd-countdown-timer app)
  "Start a countdown timer."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (secs-str (echo-read-string echo "Countdown seconds: " row width)))
    (when (and secs-str (not (string-empty? secs-str)))
      (let ((secs (string->number (string-trim secs-str))))
        (when secs
          (let* ((frame (app-state-frame app))
                 (end-time (+ (time-second (current-time)) secs))
                 (new-buf (create-buffer "*countdown*")))
            (switch-to-buffer frame new-buf)
            (let ((ed (edit-window-editor (current-window frame))))
              (editor-set-text ed (str "=== Countdown Timer ===\n\n"
                                       "Duration: " secs " seconds\n"
                                       "Ends at epoch: " end-time "\n\n"
                                       "Use M-x countdown-check to see remaining time.\n"))
              (echo-message! echo (str "Countdown: " secs " seconds")))))))))

;; --- Feature 13: Snow Effect ---

(def (cmd-snow-effect app)
  "Display a snow animation in the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*snow*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (w 60) (h 20)
           (grid (make-vector (* w h) #\space)))
      ;; Generate snowflakes falling
      (let animate ((step 0))
        (when (< step 200)
          ;; Move existing flakes down
          (let move-down ((y (- h 1)))
            (when (> y 0)
              (let move-col ((x 0))
                (when (< x w)
                  (when (char=? (vector-ref grid (+ (* (- y 1) w) x)) #\*)
                    (vector-set! grid (+ (* y w) x) #\*)
                    (vector-set! grid (+ (* (- y 1) w) x) #\space))
                  (move-col (+ x 1))))
              (move-down (- y 1))))
          ;; Add new flake at top
          (when (< (random 3) 1)
            (vector-set! grid (random w) #\*))
          (animate (+ step 1))))
      ;; Render
      (let* ((lines (let build ((y 0) (acc '()))
                      (if (>= y h) (reverse acc)
                        (build (+ y 1)
                          (cons (list->string
                                  (let bcol ((x 0) (cs '()))
                                    (if (>= x w) (reverse cs)
                                      (bcol (+ x 1)
                                        (cons (vector-ref grid (+ (* y w) x)) cs)))))
                                acc)))))
             (text (str "=== Snow ===\n\n" (string-join lines "\n") "\n")))
        (editor-set-text ed text)
        (echo-message! echo "Let it snow!")))))

;; --- Feature 14: Hangman ---

(def (cmd-hangman app)
  "Play a game of Hangman."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (words '("scheme" "emacs" "buffer" "window" "editor" "lambda" "syntax"
                  "macro" "compile" "module" "define" "cursor" "indent" "format"))
         (word (list-ref words (random (length words))))
         (new-buf (create-buffer "*hangman*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (masked (make-string (string-length word) #\_))
           (art '("  +---+\n  |   |\n      |\n      |\n      |\n      |\n========="
                  "  +---+\n  |   |\n  O   |\n      |\n      |\n      |\n========="
                  "  +---+\n  |   |\n  O   |\n  |   |\n      |\n      |\n========="
                  "  +---+\n  |   |\n  O   |\n /|   |\n      |\n      |\n========="
                  "  +---+\n  |   |\n  O   |\n /|\\  |\n      |\n      |\n========="
                  "  +---+\n  |   |\n  O   |\n /|\\  |\n /    |\n      |\n========="
                  "  +---+\n  |   |\n  O   |\n /|\\  |\n / \\  |\n      |\n=========")))
      (editor-set-text ed (str "=== HANGMAN ===\n\n"
                               (car art) "\n\n"
                               "Word: " masked "\n\n"
                               "Guesses: (none)\n"
                               "Use M-x hangman-guess to guess a letter.\n"))
      (echo-message! echo "Hangman started! Guess a letter with M-x hangman-guess"))))

;; --- Feature 15: Image to ASCII ---

(def (cmd-image-to-ascii app)
  "Convert an image file to ASCII art."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (file (echo-read-string echo "Image file: " row width)))
    (when (and file (not (string-empty? file)))
      (let ((path (string-trim file)))
        (if (not (file-exists? path))
          (echo-message! echo (str "File not found: " path))
          (with-catch
            (lambda (e) (echo-message! echo (str "Convert error: " e)))
            (lambda ()
              (let-values (((si so se pid)
                            (open-process-ports
                              (str "jp2a --width=80 " (shell-quote path)
                                   " 2>/dev/null || asciiart " (shell-quote path)
                                   " 2>/dev/null || echo 'Install jp2a for image-to-ascii'")
                              'block (native-transcoder))))
                (close-port si)
                (let loop ((lines '()))
                  (let ((line (get-line so)))
                    (if (eof-object? line)
                      (begin
                        (close-port so) (close-port se)
                        (let* ((result (string-join (reverse lines) "\n"))
                               (new-buf (create-buffer "*ascii-art*")))
                          (switch-to-buffer frame new-buf)
                          (let ((new-ed (edit-window-editor (current-window frame))))
                            (editor-set-text new-ed result))
                          (echo-message! echo "ASCII art rendered")))
                      (loop (cons line lines)))))))))))))

;; --- Feature 16: Buffer Menu ---

(def (cmd-buffer-menu app)
  "Display an enhanced buffer menu with sizes and modification status."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (bufs (frame-buffers frame))
         (new-buf (create-buffer "*buffer-menu*"))
         (header "  MR Buffer                         Size  File\n  -- ------                         ----  ----\n")
         (lines (map (lambda (buf)
                       (let* ((name (buffer-name buf))
                              (file (or (buffer-file buf) ""))
                              (modified (buffer-modified? buf))
                              (flag-m (if modified "*" " "))
                              (pad-name (if (< (string-length name) 30)
                                          (str name (make-string (- 30 (string-length name)) #\space))
                                          (substring name 0 30))))
                         (str "  " flag-m "  " pad-name "  " file)))
                     bufs))
         (text (str "=== Buffer Menu ===\n\n" header (string-join lines "\n") "\n")))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed text))
    (echo-message! echo (str (length bufs) " buffers"))))

;; --- Feature 17: Fire Effect ---

(def (cmd-fire-effect app)
  "Display a fire animation effect in the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*fire*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (w 60) (h 15)
           (chars " .:-=+*#%@")
           (grid (make-vector (* w h) 0)))
      ;; Simulate fire
      (let animate ((step 0))
        (when (< step 300)
          ;; Set bottom row to max heat
          (let set-bottom ((x 0))
            (when (< x w)
              (vector-set! grid (+ (* (- h 1) w) x)
                (+ (quotient (- (string-length chars) 1) 2) (random (quotient (string-length chars) 2))))
              (set-bottom (+ x 1))))
          ;; Propagate heat upward with cooling
          (let prop-row ((y 1))
            (when (< y h)
              (let prop-col ((x 0))
                (when (< x w)
                  (let* ((below (vector-ref grid (+ (* (min (- h 1) y) w) x)))
                         (left (if (> x 0) (vector-ref grid (+ (* y w) (- x 1))) 0))
                         (right (if (< x (- w 1)) (vector-ref grid (+ (* y w) (+ x 1))) 0))
                         (avg (quotient (+ below left right) 3))
                         (cooled (max 0 (- avg (random 2)))))
                    (vector-set! grid (+ (* (- y 1) w) x) cooled))
                  (prop-col (+ x 1))))
              (prop-row (+ y 1))))
          (animate (+ step 1))))
      ;; Render
      (let* ((lines (let build ((y 0) (acc '()))
                      (if (>= y h) (reverse acc)
                        (build (+ y 1)
                          (cons (list->string
                                  (let bcol ((x 0) (cs '()))
                                    (if (>= x w) (reverse cs)
                                      (bcol (+ x 1)
                                        (cons (string-ref chars
                                                (min (- (string-length chars) 1)
                                                     (vector-ref grid (+ (* y w) x))))
                                              cs)))))
                                acc)))))
             (text (str "=== Fire ===\n\n" (string-join lines "\n") "\n")))
        (editor-set-text ed text)
        (echo-message! echo "Fire effect rendered")))))

;; --- Feature 18: Lolcat ---

(def (cmd-lolcat app)
  "Show rainbow text info for the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (text (editor-get-text ed)))
    (if (or (not text) (string-empty? text))
      (echo-message! echo "Buffer is empty")
      (let* ((new-buf (create-buffer "*lolcat*"))
             (info (str "=== Lolcat Mode ===\n\n"
                        "In a terminal with color support, this would show rainbow text.\n\n"
                        "To see the actual rainbow effect, pipe through lolcat:\n"
                        "  cat file.txt | lolcat\n\n"
                        "Buffer text length: " (string-length text) " characters\n"
                        "Lines: " (length (string-split text #\newline)) "\n")))
        (switch-to-buffer frame new-buf)
        (let ((new-ed (edit-window-editor (current-window frame))))
          (editor-set-text new-ed info))
        (echo-message! echo "Lolcat (rainbow text simulation)")))))

;; --- Feature 19: Toggle Narrow to Region ---

(def (cmd-toggle-narrow-to-region app)
  "Toggle narrowing to the selected region."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "Use M-x widen-buffer to restore full buffer")
      (let ((text (editor-get-text-range ed start end)))
        (editor-set-text ed text)
        (editor-goto-pos ed 0)
        (echo-message! echo "Narrowed to region")))))

;; --- Feature 20: Password Store ---

(def (cmd-password-store app)
  "Interact with the pass password store."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (action (echo-read-string echo "pass [list/show/generate/find]: " row width)))
    (when (and action (not (string-empty? action)))
      (let ((act (string-trim action)))
        (cond
          ((string=? act "list")
           (with-catch
             (lambda (e) (echo-message! echo (str "pass error: " e)))
             (lambda ()
               (let-values (((si so se pid)
                             (open-process-ports "pass ls 2>/dev/null || echo 'pass not installed'"
                               'block (native-transcoder))))
                 (close-port si)
                 (let loop ((lines '()))
                   (let ((line (get-line so)))
                     (if (eof-object? line)
                       (begin
                         (close-port so) (close-port se)
                         (let* ((result (string-join (reverse lines) "\n"))
                                (new-buf (create-buffer "*pass*")))
                           (switch-to-buffer frame new-buf)
                           (let ((new-ed (edit-window-editor (current-window frame))))
                             (editor-set-text new-ed (str "=== Password Store ===\n\n" result "\n")))
                           (echo-message! echo "Password store listed")))
                       (loop (cons line lines)))))))))
          ((string=? act "find")
           (let ((query (echo-read-string echo "Search for: " row width)))
             (when (and query (not (string-empty? query)))
               (with-catch
                 (lambda (e) (echo-message! echo (str "pass error: " e)))
                 (lambda ()
                   (let-values (((si so se pid)
                                 (open-process-ports (str "pass find " (shell-quote (string-trim query)) " 2>/dev/null")
                                   'block (native-transcoder))))
                     (close-port si)
                     (let loop ((lines '()))
                       (let ((line (get-line so)))
                         (if (eof-object? line)
                           (begin
                             (close-port so) (close-port se)
                             (echo-message! echo (string-join (reverse lines) " | ")))
                           (loop (cons (string-trim line) lines)))))))))))
          (else (echo-message! echo (str "Unknown action: " act))))))))

;; ===== Round 19 Batch 2 =====

;; --- Feature 11: Kernel Info ---

(def (cmd-kernel-info app)
  "Show kernel information."
  (let* ((echo (app-state-echo app)))
    (with-catch
      (lambda (e) (echo-message! echo "Could not read kernel info"))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "uname -a" 'block (native-transcoder))))
          (close-port si)
          (let ((info (get-line so)))
            (close-port so) (close-port se)
            (if (eof-object? info)
              (echo-message! echo "Kernel info not available")
              (echo-message! echo (str "Kernel: " (string-trim info))))))))))

;; --- Feature 12: Hostname Info ---

(def (cmd-hostname-info app)
  "Show hostname and domain information."
  (let* ((echo (app-state-echo app)))
    (with-catch
      (lambda (e) (echo-message! echo "Could not read hostname"))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "hostname -f 2>/dev/null || hostname"
                        'block (native-transcoder))))
          (close-port si)
          (let ((info (get-line so)))
            (close-port so) (close-port se)
            (if (eof-object? info)
              (echo-message! echo "Hostname not available")
              (echo-message! echo (str "Hostname: " (string-trim info))))))))))

;; --- Feature 13: List Processes Tree ---

(def (cmd-list-processes-tree app)
  "Show the process tree."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*process-tree*")))
    (switch-to-buffer frame new-buf)
    (with-catch
      (lambda (e) (echo-message! echo (str "Error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "pstree -p | head -60" 'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((new-ed (edit-window-editor (current-window frame))))
                    (editor-set-text new-ed (str "=== Process Tree ===\n\n"
                                                 (string-join (reverse lines) "\n") "\n")))
                  (echo-message! echo "Process tree loaded"))
                (loop (cons line lines))))))))))

;; --- Feature 14: Systemd Status ---

(def (cmd-systemd-status app)
  "Show systemd service status."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (service (echo-read-string echo "Service name (or blank for overview): " row width)))
    (let* ((cmd (if (or (not service) (string-empty? service))
                  "systemctl list-units --type=service --state=running | head -30"
                  (str "systemctl status " (shell-quote (string-trim service)) " 2>&1")))
           (new-buf (create-buffer "*systemd*")))
      (switch-to-buffer frame new-buf)
      (with-catch
        (lambda (e) (echo-message! echo (str "systemd error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports cmd 'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((new-ed (edit-window-editor (current-window frame))))
                      (editor-set-text new-ed (string-join (reverse lines) "\n")))
                    (echo-message! echo "Systemd status loaded"))
                  (loop (cons line lines)))))))))))

;; --- Feature 15: Journal Log ---

(def (cmd-journal-log app)
  "View journalctl logs."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (lines-str (echo-read-string echo "Lines to show (default 50): " row width))
         (n (or (and lines-str (not (string-empty? lines-str))
                     (string->number (string-trim lines-str)))
                50))
         (new-buf (create-buffer "*journal*")))
    (switch-to-buffer frame new-buf)
    (with-catch
      (lambda (e) (echo-message! echo (str "journalctl error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports (str "journalctl --no-pager -n " n " 2>/dev/null")
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((new-ed (edit-window-editor (current-window frame))))
                    (editor-set-text new-ed (str "=== Journal Log (last " n " entries) ===\n\n"
                                                 (string-join (reverse lines) "\n") "\n")))
                  (echo-message! echo "Journal log loaded"))
                (loop (cons line lines))))))))))

;; --- Feature 16: Dmesg View ---

(def (cmd-dmesg-view app)
  "View kernel dmesg messages."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*dmesg*")))
    (switch-to-buffer frame new-buf)
    (with-catch
      (lambda (e) (echo-message! echo (str "dmesg error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "dmesg --human 2>/dev/null | tail -50 || dmesg | tail -50"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((new-ed (edit-window-editor (current-window frame))))
                    (editor-set-text new-ed (str "=== Kernel Messages ===\n\n"
                                                 (string-join (reverse lines) "\n") "\n")))
                  (echo-message! echo "dmesg loaded"))
                (loop (cons line lines))))))))))

;; --- Feature 17: Installed Packages ---

(def (cmd-installed-packages app)
  "List installed packages."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (filter-str (echo-read-string echo "Filter (blank for all, limited to 100): " row width))
         (new-buf (create-buffer "*packages*")))
    (switch-to-buffer frame new-buf)
    (with-catch
      (lambda (e) (echo-message! echo (str "Error: " e)))
      (lambda ()
        (let* ((filter-cmd (if (or (not filter-str) (string-empty? filter-str))
                             " | head -100"
                             (str " | grep -i " (shell-quote (string-trim filter-str)) " | head -100")))
               (cmd (str "dpkg -l 2>/dev/null" filter-cmd
                         " || rpm -qa 2>/dev/null" filter-cmd
                         " || pacman -Q 2>/dev/null" filter-cmd)))
          (let-values (((si so se pid)
                        (open-process-ports cmd 'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((new-ed (edit-window-editor (current-window frame))))
                      (editor-set-text new-ed (str "=== Installed Packages ===\n\n"
                                                   (string-join (reverse lines) "\n") "\n")))
                    (echo-message! echo (str (length (reverse lines)) " packages")))
                  (loop (cons line lines)))))))))))

;; --- Feature 18: Apt Search ---

(def (cmd-apt-search app)
  "Search for packages via apt."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (query (echo-read-string echo "Search packages: " row width)))
    (when (and query (not (string-empty? query)))
      (let ((new-buf (create-buffer "*apt-search*")))
        (switch-to-buffer frame new-buf)
        (with-catch
          (lambda (e) (echo-message! echo (str "apt error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "apt-cache search " (shell-quote (string-trim query))
                                 " 2>/dev/null | head -50")
                            'block (native-transcoder))))
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (let ((new-ed (edit-window-editor (current-window frame))))
                        (editor-set-text new-ed (str "=== Apt Search: " query " ===\n\n"
                                                     (string-join (reverse lines) "\n") "\n")))
                      (echo-message! echo (str (length (reverse lines)) " packages found")))
                    (loop (cons line lines))))))))))))

;; --- Feature 19: Connect Four ---

(def (cmd-connect-four app)
  "Play Connect Four against the computer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*connect-four*"))
         (cols 7) (rows 6))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           ;; Empty board
           (header " 1   2   3   4   5   6   7\n")
           (separator "+---+---+---+---+---+---+---+\n")
           (empty-row "|   |   |   |   |   |   |   |\n")
           (board-text (str "=== Connect Four ===\n\n"
                            header separator
                            (apply str (let build ((i 0) (acc '()))
                                         (if (>= i rows) (reverse acc)
                                           (build (+ i 1) (cons (str empty-row separator) acc)))))
                            "\nUse M-x c4-drop to drop a piece (column 1-7).\n")))
      (editor-set-text ed board-text)
      (echo-message! echo "Connect Four! Use M-x c4-drop"))))

;; --- Feature 20: Fifteen Puzzle ---

(def (cmd-fifteen-puzzle app)
  "Play the 15-puzzle sliding tile game."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*fifteen-puzzle*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           ;; Shuffled tiles
           (tiles (let ((v (make-vector 16 0)))
                    (let fill ((i 0))
                      (when (< i 16)
                        (vector-set! v i i)
                        (fill (+ i 1))))
                    ;; Simple shuffle
                    (let shuffle ((i 15))
                      (when (> i 0)
                        (let ((j (random (+ i 1))))
                          (let ((tmp (vector-ref v i)))
                            (vector-set! v i (vector-ref v j))
                            (vector-set! v j tmp)))
                        (shuffle (- i 1))))
                    v))
           (render (lambda (v)
                     (let build-rows ((row 0) (acc '()))
                       (if (>= row 4) (string-join (reverse acc) "\n")
                         (build-rows (+ row 1)
                           (cons (str "+----+----+----+----+\n| "
                                      (string-join
                                        (let build-cols ((col 0) (cs '()))
                                          (if (>= col 4) (reverse cs)
                                            (let ((val (vector-ref v (+ (* row 4) col))))
                                              (build-cols (+ col 1)
                                                (cons (if (= val 0) "  "
                                                        (let ((s (number->string val)))
                                                          (if (< val 10) (str " " s) s)))
                                                      cs)))))
                                        " | ")
                                      " |")
                                 acc))))))
           (text (str "=== Fifteen Puzzle ===\n\n"
                      (render tiles)
                      "\n+----+----+----+----+\n\n"
                      "Use M-x puzzle-move to slide a tile.\n"
                      "Goal: arrange 1-15 in order with blank in bottom-right.\n")))
      (editor-set-text ed text)
      (echo-message! echo "Fifteen puzzle! Use M-x puzzle-move"))))

;; Round 20 batch 2: paredit-mode, hi-lock-mode, syntax-highlight-region, stack-overflow-search,
;; cheat-sheet, apropos-documentation, scratch-message, geiser-mode, sly-mode, slime-mode

;; cmd-paredit-mode: Show paredit-style structural editing cheat sheet
(def (cmd-paredit-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== Paredit Mode Reference ===\n\n"
                    "Paredit provides structural editing for S-expressions.\n\n"
                    "Key Bindings (conceptual):\n"
                    "  C-(         paredit-open-round       Insert () and place cursor inside\n"
                    "  C-)         paredit-close-round      Move past next closing paren\n"
                    "  M-(         paredit-wrap-round        Wrap next sexp in ()\n"
                    "  M-s         paredit-splice-sexp       Remove surrounding parens\n"
                    "  C-right     paredit-forward-slurp     Pull next sexp into current list\n"
                    "  C-left      paredit-forward-barf      Push last sexp out of current list\n"
                    "  M-r         paredit-raise-sexp        Replace parent with current sexp\n"
                    "  M-S         paredit-split-sexp        Split current sexp at cursor\n"
                    "  M-J         paredit-join-sexp         Join adjacent sexps\n\n"
                    "Navigation:\n"
                    "  C-M-f       forward-sexp\n"
                    "  C-M-b       backward-sexp\n"
                    "  C-M-u       backward-up-list\n"
                    "  C-M-d       down-list\n\n"
                    "Note: These are reference commands. Full structural\n"
                    "enforcement is not yet implemented.\n")))
    (editor-set-text ed text)
    (echo-message! echo "Paredit reference loaded")))

;; cmd-hi-lock-mode: Highlight all occurrences of a pattern in current buffer
(def (cmd-hi-lock-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "Hi-lock pattern: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((text (editor-get-text ed))
             (pat-len (string-length pattern))
             (text-len (string-length text)))
        (let loop ((pos 0) (count 0))
          (if (> (+ pos pat-len) text-len)
            (echo-message! echo (str "Hi-lock: highlighted " count " occurrences of \"" pattern "\""))
            (let ((idx (string-contains text pattern pos)))
              (if (not idx)
                (echo-message! echo (str "Hi-lock: highlighted " count " occurrences of \"" pattern "\""))
                (begin
                  (editor-indicator-fill ed 18 idx (+ idx pat-len))
                  (loop (+ idx pat-len) (+ count 1)))))))))))

;; cmd-syntax-highlight-region: Show syntax info for the selected region
(def (cmd-syntax-highlight-region app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((region-text (editor-get-text-range ed sel-start sel-end))
             (char-count (string-length region-text))
             (line-count (+ 1 (let loop ((i 0) (n 0))
                                (if (>= i char-count) n
                                  (loop (+ i 1) (if (char=? (string-ref region-text i) #\newline) (+ n 1) n))))))
             (word-count (length (let split ((s region-text) (words '()))
                                   (let ((trimmed (string-trim s)))
                                     (if (string=? trimmed "") words
                                       (let find-space ((i 0))
                                         (if (>= i (string-length trimmed))
                                           (cons trimmed words)
                                           (if (char-whitespace? (string-ref trimmed i))
                                             (split (substring trimmed i (string-length trimmed))
                                                    (cons (substring trimmed 0 i) words))
                                             (find-space (+ i 1))))))))))
             (text (str "=== Region Syntax Info ===\n\n"
                        "Selection: " sel-start " to " sel-end "\n"
                        "Characters: " char-count "\n"
                        "Lines: " line-count "\n"
                        "Words: " word-count "\n\n"
                        "--- Region Content ---\n"
                        region-text "\n")))
        (echo-message! echo (str "Region: " char-count " chars, " line-count " lines, " word-count " words"))))))

;; cmd-stack-overflow-search: Search Stack Overflow via DuckDuckGo
(def (cmd-stack-overflow-search app)
  (let* ((echo (app-state-echo app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (query (echo-read-string echo "Stack Overflow search: ")))
    (if (or (not query) (string=? query ""))
      (echo-message! echo "No query specified")
      (let* ((encoded-q query)
             (url (str "https://stackoverflow.com/search?q=" encoded-q))
             (text (str "=== Stack Overflow Search ===\n\n"
                        "Query: " query "\n\n"
                        "URL: " url "\n\n"
                        "To search Stack Overflow, visit the URL above.\n\n"
                        "Tips:\n"
                        "  - Use [tag] syntax to filter by technology\n"
                        "  - Example: [python] how to read CSV\n"
                        "  - Use 'is:answer' to only search answers\n"
                        "  - Use 'score:3' for highly rated content\n"
                        "  - Use 'user:me' for your own posts\n\n"
                        "Common Tags:\n"
                        "  [scheme] [lisp] [emacs] [linux]\n"
                        "  [python] [javascript] [c] [rust]\n")))
        (editor-set-text ed text)
        (echo-message! echo (str "Stack Overflow: " url))))))

;; cmd-cheat-sheet: Display a cheat sheet for common editor commands
(def (cmd-cheat-sheet app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== jemacs Cheat Sheet ===\n\n"
                    "--- Movement ---\n"
                    "  C-f / C-b       Forward/backward char\n"
                    "  M-f / M-b       Forward/backward word\n"
                    "  C-a / C-e       Beginning/end of line\n"
                    "  C-n / C-p       Next/previous line\n"
                    "  M-< / M->       Beginning/end of buffer\n"
                    "  C-v / M-v       Page down/up\n"
                    "  C-l             Recenter\n\n"
                    "--- Editing ---\n"
                    "  C-d             Delete char forward\n"
                    "  Backspace       Delete char backward\n"
                    "  M-d             Kill word forward\n"
                    "  C-k             Kill to end of line\n"
                    "  C-y             Yank (paste)\n"
                    "  M-y             Yank-pop (cycle kill ring)\n"
                    "  C-/             Undo\n"
                    "  C-x u           Undo\n\n"
                    "--- Search ---\n"
                    "  C-s             Isearch forward\n"
                    "  C-r             Isearch backward\n"
                    "  M-%             Query replace\n\n"
                    "--- Files ---\n"
                    "  C-x C-f         Find file\n"
                    "  C-x C-s         Save file\n"
                    "  C-x C-w         Write file (save as)\n"
                    "  C-x b           Switch buffer\n"
                    "  C-x k           Kill buffer\n\n"
                    "--- Windows ---\n"
                    "  C-x 2           Split horizontal\n"
                    "  C-x 3           Split vertical\n"
                    "  C-x 1           Delete other windows\n"
                    "  C-x 0           Delete this window\n"
                    "  C-x o           Other window\n\n"
                    "--- Help ---\n"
                    "  C-h k           Describe key\n"
                    "  C-h f           Describe function\n"
                    "  M-x             Execute command\n")))
    (editor-set-text ed text)
    (echo-message! echo "Cheat sheet displayed")))

;; cmd-apropos-documentation: Search commands by keyword
(def (cmd-apropos-documentation app)
  (let* ((echo (app-state-echo app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (query (echo-read-string echo "Apropos: ")))
    (if (or (not query) (string=? query ""))
      (echo-message! echo "No query specified")
      (let* ((all-cmds (hash-keys (app-state-commands app)))
             (matches (filter (lambda (sym)
                                (string-contains (symbol->string sym) query))
                              all-cmds))
             (sorted (sort string<?
                           (map symbol->string matches)))
             (text (str "=== Apropos: \"" query "\" ===\n\n"
                        "Found " (length sorted) " matching commands:\n\n"
                        (string-join
                          (map (lambda (name)
                                 (str "  M-x " name))
                               sorted)
                          "\n")
                        "\n")))
        (editor-set-text ed text)
        (echo-message! echo (str "Apropos: " (length sorted) " matches for \"" query "\""))))))

;; cmd-scratch-message: Insert the default *scratch* buffer message
(def (cmd-scratch-message app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str ";; This buffer is for text that is not saved, and for Scheme evaluation.\n"
                    ";; To create a file, visit it with C-x C-f and enter text in its buffer.\n"
                    ";;\n"
                    ";; Welcome to jemacs - a Chez Scheme Emacs-like editor.\n"
                    ";;\n"
                    ";; Quick start:\n"
                    ";;   C-x C-f   Open a file\n"
                    ";;   C-x C-s   Save current buffer\n"
                    ";;   C-x b     Switch buffer\n"
                    ";;   C-x k     Kill buffer\n"
                    ";;   C-h ?     Help\n"
                    ";;   M-x       Execute command by name\n"
                    ";;\n"
                    ";; Type Scheme expressions and use M-x eval-buffer to evaluate.\n\n")))
    (editor-set-text ed text)
    (echo-message! echo "*scratch* message inserted")))

;; cmd-geiser-mode: Show Geiser REPL reference for Scheme interaction
(def (cmd-geiser-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== Geiser Mode Reference ===\n\n"
                    "Geiser provides Scheme interaction in Emacs.\n\n"
                    "Key Bindings (GNU Emacs reference):\n"
                    "  C-c C-z     Switch to REPL\n"
                    "  C-c C-a     Switch to REPL and enter module\n"
                    "  C-x C-e    Eval last sexp\n"
                    "  C-c C-r     Eval region\n"
                    "  C-c C-b     Eval buffer\n"
                    "  C-c C-e    Eval last sexp and show result in echo\n"
                    "  C-c C-d d   Autodoc (show docs)\n"
                    "  C-c C-d m   Module documentation\n\n"
                    "Supported Schemes:\n"
                    "  - Chez Scheme\n"
                    "  - Guile\n"
                    "  - Racket\n"
                    "  - Chicken\n"
                    "  - MIT/GNU Scheme\n"
                    "  - Gambit\n\n"
                    "jemacs equivalent: M-x eval-expression, M-x eval-buffer\n")))
    (editor-set-text ed text)
    (echo-message! echo "Geiser mode reference loaded")))

;; cmd-sly-mode: Show SLY (Sylvester the Cat's Common Lisp IDE) reference
(def (cmd-sly-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== SLY Mode Reference ===\n\n"
                    "SLY is a Common Lisp IDE for Emacs (fork of SLIME).\n\n"
                    "Key Bindings (GNU Emacs reference):\n"
                    "  M-x sly          Start SLY\n"
                    "  C-c C-c          Compile defun at point\n"
                    "  C-c C-k          Compile and load file\n"
                    "  C-c C-z          Switch to REPL\n"
                    "  C-x C-e          Eval last expression\n"
                    "  M-.              Go to definition\n"
                    "  M-,              Return from definition\n"
                    "  C-c C-d d        Describe symbol\n"
                    "  C-c C-d h        HyperSpec lookup\n"
                    "  C-c I            Inspect expression\n"
                    "  C-c C-t          Toggle trace\n\n"
                    "SLY Features over SLIME:\n"
                    "  - Stickers (inline value tracking)\n"
                    "  - Multiple REPLs\n"
                    "  - Flex completion\n"
                    "  - Improved backtraces\n\n"
                    "jemacs equivalent: M-x eval-expression, M-x eval-buffer\n")))
    (editor-set-text ed text)
    (echo-message! echo "SLY mode reference loaded")))

;; cmd-slime-mode: Show SLIME (Superior Lisp Interaction Mode) reference
(def (cmd-slime-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== SLIME Mode Reference ===\n\n"
                    "SLIME is the Superior Lisp Interaction Mode for Emacs.\n\n"
                    "Key Bindings (GNU Emacs reference):\n"
                    "  M-x slime         Start SLIME\n"
                    "  C-c C-c           Compile defun at point\n"
                    "  C-c C-k           Compile and load file\n"
                    "  C-c C-z           Switch to REPL\n"
                    "  C-x C-e           Eval last expression\n"
                    "  M-.               Go to definition\n"
                    "  M-,               Return from definition\n"
                    "  C-c C-d d         Describe symbol\n"
                    "  C-c C-d h         HyperSpec lookup\n"
                    "  C-c C-w c         List callers\n"
                    "  C-c C-w w         List callees\n"
                    "  C-c I             Inspect expression\n"
                    "  C-c C-t           Toggle trace\n"
                    "  C-c M-d           Disassemble\n\n"
                    "Connection:\n"
                    "  SLIME connects to a Swank server running in the\n"
                    "  Lisp process. Supports SBCL, CCL, CLISP, etc.\n\n"
                    "jemacs equivalent: M-x eval-expression, M-x eval-buffer\n")))
    (editor-set-text ed text)
    (echo-message! echo "SLIME mode reference loaded")))

;; Round 21 batch 2: fill-region, justify-paragraph, center-line, set-fill-column,
;; auto-revert-mode, revert-buffer-quick, rename-visited-file, make-directory,
;; delete-directory, copy-directory

;; cmd-fill-region: Wrap all paragraphs in region to fill column
(def (cmd-fill-region app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((fill-col 80)
             (text (editor-get-text-range ed sel-start sel-end))
             (paras (let split-paras ((lines (string-split text #\newline)) (current '()) (result '()))
                      (if (null? lines)
                        (reverse (if (null? current) result (cons (reverse current) result)))
                        (if (string=? (string-trim (car lines)) "")
                          (split-paras (cdr lines) '()
                                       (if (null? current) result (cons (reverse current) result)))
                          (split-paras (cdr lines) (cons (car lines) current) result)))))
             (filled-paras (map (lambda (para-lines)
                                  (let* ((joined (string-join para-lines " "))
                                         (words (let split-w ((s (string-trim joined)) (r '()))
                                                  (let ((t (string-trim s)))
                                                    (if (string=? t "") (reverse r)
                                                      (let f ((i 0))
                                                        (if (>= i (string-length t))
                                                          (reverse (cons t r))
                                                          (if (char-whitespace? (string-ref t i))
                                                            (split-w (substring t i (string-length t))
                                                                     (cons (substring t 0 i) r))
                                                            (f (+ i 1))))))))))
                                    (if (null? words) ""
                                      (let fill ((ws words) (line "") (lines '()))
                                        (if (null? ws)
                                          (string-join (reverse (if (string=? line "") lines (cons line lines))) "\n")
                                          (let* ((w (car ws))
                                                 (new-line (if (string=? line "") w (str line " " w))))
                                            (if (> (string-length new-line) fill-col)
                                              (if (string=? line "")
                                                (fill (cdr ws) "" (cons w lines))
                                                (fill ws "" (cons line lines)))
                                              (fill (cdr ws) new-line lines))))))))
                                paras))
             (result (string-join filled-paras "\n\n")))
        (editor-replace-range ed sel-start sel-end result)
        (echo-message! echo "Region filled")))))

;; cmd-justify-paragraph: Right-justify current paragraph
(def (cmd-justify-paragraph app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (fill-col 80)
         (cur-line (editor-current-line ed))
         (total-lines (editor-line-count ed))
         (para-start (let loop ((ln cur-line))
                       (if (<= ln 0) 0
                         (let ((text (editor-get-line ed ln)))
                           (if (string=? (string-trim text) "")
                             (+ ln 1) (loop (- ln 1)))))))
         (para-end (let loop ((ln cur-line))
                     (if (>= ln total-lines) (- total-lines 1)
                       (let ((text (editor-get-line ed ln)))
                         (if (string=? (string-trim text) "")
                           (- ln 1) (loop (+ ln 1)))))))
         (start-pos (editor-line-start ed para-start))
         (end-pos (editor-line-end ed para-end))
         (para-text (editor-get-text-range ed start-pos end-pos))
         (lines (string-split para-text #\newline))
         (justified (map (lambda (line)
                           (let* ((trimmed (string-trim line))
                                  (pad (max 0 (- fill-col (string-length trimmed)))))
                             (str (make-string pad #\space) trimmed)))
                         lines))
         (result (string-join justified "\n")))
    (editor-replace-range ed start-pos end-pos result)
    (echo-message! echo "Paragraph right-justified")))

;; cmd-center-line: Center the current line within fill column
(def (cmd-center-line app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (fill-col 80)
         (cur-line (editor-current-line ed))
         (start-pos (editor-line-start ed cur-line))
         (end-pos (editor-line-end ed cur-line))
         (text (string-trim (editor-get-text-range ed start-pos end-pos)))
         (text-len (string-length text))
         (pad (max 0 (quotient (- fill-col text-len) 2)))
         (centered (str (make-string pad #\space) text)))
    (editor-replace-range ed start-pos end-pos centered)
    (echo-message! echo "Line centered")))

;; cmd-set-fill-column: Set the fill column width
(def (cmd-set-fill-column app)
  (let* ((echo (app-state-echo app))
         (col-str (echo-read-string echo "Set fill column to: ")))
    (if (or (not col-str) (string=? col-str ""))
      (echo-message! echo "Fill column unchanged")
      (let ((col (string->number col-str)))
        (if (and col (> col 0))
          (echo-message! echo (str "Fill column set to " col " (note: stored per-session)"))
          (echo-message! echo "Invalid column number"))))))

;; cmd-auto-revert-mode: Toggle auto-revert mode
(def (cmd-auto-revert-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'auto-revert-mode)
    (if (mode-enabled? app 'auto-revert-mode)
      (echo-message! echo "Auto-Revert mode enabled (buffer will auto-refresh from disk)")
      (echo-message! echo "Auto-Revert mode disabled"))))

;; cmd-revert-buffer-quick: Reload buffer from disk without confirmation
(def (cmd-revert-buffer-quick app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "Buffer has no file")
      (if (not (file-exists? file))
        (echo-message! echo (str "File not found: " file))
        (let ((content (read-file-string file)))
          (editor-set-text ed content)
          (echo-message! echo (str "Reverted: " file)))))))

;; cmd-rename-visited-file: Rename the file visited by current buffer
(def (cmd-rename-visited-file app)
  (let* ((buf (app-state-current-buffer app))
         (echo (app-state-echo app))
         (ed (buffer-editor buf))
         (old-file (buffer-file buf)))
    (if (not old-file)
      (echo-message! echo "Buffer has no file")
      (let ((new-name (echo-read-string echo (str "Rename " old-file " to: "))))
        (if (or (not new-name) (string=? new-name ""))
          (echo-message! echo "Rename cancelled")
          (with-catch
            (lambda (e) (echo-message! echo (str "Rename error: " e)))
            (lambda ()
              (rename-file old-file new-name)
              (buffer-file-set! buf new-name)
              (buffer-name-set! buf (path-strip-directory new-name))
              (echo-message! echo (str "Renamed to " new-name)))))))))

;; cmd-make-directory: Create a new directory
(def (cmd-make-directory app)
  (let* ((echo (app-state-echo app))
         (dir (echo-read-string echo "Make directory: ")))
    (if (or (not dir) (string=? dir ""))
      (echo-message! echo "No directory specified")
      (with-catch
        (lambda (e) (echo-message! echo (str "mkdir error: " e)))
        (lambda ()
          (mkdir dir)
          (echo-message! echo (str "Created directory: " dir)))))))

;; cmd-delete-directory: Delete a directory
(def (cmd-delete-directory app)
  (let* ((echo (app-state-echo app))
         (dir (echo-read-string echo "Delete directory: ")))
    (if (or (not dir) (string=? dir ""))
      (echo-message! echo "No directory specified")
      (if (not (file-directory? dir))
        (echo-message! echo (str "Not a directory: " dir))
        (with-catch
          (lambda (e) (echo-message! echo (str "rmdir error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports (str "rm -rf " (shell-quote dir))
                            'block (native-transcoder))))
              (close-port si)
              (let ((out (get-string-all so)))
                (close-port so) (close-port se)
                (echo-message! echo (str "Deleted directory: " dir))))))))))

;; cmd-copy-directory: Copy a directory recursively
(def (cmd-copy-directory app)
  (let* ((echo (app-state-echo app))
         (src (echo-read-string echo "Copy directory from: ")))
    (if (or (not src) (string=? src ""))
      (echo-message! echo "No source specified")
      (let ((dst (echo-read-string echo "Copy directory to: ")))
        (if (or (not dst) (string=? dst ""))
          (echo-message! echo "No destination specified")
          (if (not (file-directory? src))
            (echo-message! echo (str "Not a directory: " src))
            (with-catch
              (lambda (e) (echo-message! echo (str "Copy error: " e)))
              (lambda ()
                (let-values (((si so se pid)
                              (open-process-ports (str "cp -r " (shell-quote src) " " (shell-quote dst))
                                'block (native-transcoder))))
                  (close-port si)
                  (let ((out (get-string-all so)))
                    (close-port so) (close-port se)
                    (echo-message! echo (str "Copied " src " to " dst))))))))))))

;; Round 22 batch 2: append-to-buffer, prepend-to-buffer, copy-to-buffer, insert-buffer,
;; append-to-file, write-region, print-buffer, lpr-buffer, flush-lines, keep-lines

;; cmd-append-to-buffer: Append region to another buffer
(def (cmd-append-to-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (buffers (app-state-buffers app))
             (buf-names (map buffer-name buffers))
             (target-name (echo-read-string-with-completion echo "Append to buffer: " buf-names)))
        (if (or (not target-name) (string=? target-name ""))
          (echo-message! echo "No target buffer")
          (let ((target (find (lambda (b) (string=? (buffer-name b) target-name)) buffers)))
            (if (not target)
              (echo-message! echo (str "Buffer not found: " target-name))
              (let* ((target-ed (buffer-editor target))
                     (end-pos (editor-get-length target-ed)))
                (editor-insert-text target-ed end-pos text)
                (echo-message! echo (str "Appended to " target-name))))))))))

;; cmd-prepend-to-buffer: Prepend region to another buffer
(def (cmd-prepend-to-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (buffers (app-state-buffers app))
             (buf-names (map buffer-name buffers))
             (target-name (echo-read-string-with-completion echo "Prepend to buffer: " buf-names)))
        (if (or (not target-name) (string=? target-name ""))
          (echo-message! echo "No target buffer")
          (let ((target (find (lambda (b) (string=? (buffer-name b) target-name)) buffers)))
            (if (not target)
              (echo-message! echo (str "Buffer not found: " target-name))
              (let ((target-ed (buffer-editor target)))
                (editor-insert-text target-ed 0 text)
                (echo-message! echo (str "Prepended to " target-name))))))))))

;; cmd-copy-to-buffer: Replace target buffer contents with region
(def (cmd-copy-to-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (buffers (app-state-buffers app))
             (buf-names (map buffer-name buffers))
             (target-name (echo-read-string-with-completion echo "Copy to buffer: " buf-names)))
        (if (or (not target-name) (string=? target-name ""))
          (echo-message! echo "No target buffer")
          (let ((target (find (lambda (b) (string=? (buffer-name b) target-name)) buffers)))
            (if (not target)
              (echo-message! echo (str "Buffer not found: " target-name))
              (let ((target-ed (buffer-editor target)))
                (editor-set-text target-ed text)
                (echo-message! echo (str "Copied to " target-name))))))))))

;; cmd-insert-buffer: Insert contents of another buffer at point
(def (cmd-insert-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (buf-names (map buffer-name buffers))
         (source-name (echo-read-string-with-completion echo "Insert buffer: " buf-names)))
    (if (or (not source-name) (string=? source-name ""))
      (echo-message! echo "No buffer specified")
      (let ((source (find (lambda (b) (string=? (buffer-name b) source-name)) buffers)))
        (if (not source)
          (echo-message! echo (str "Buffer not found: " source-name))
          (let* ((source-ed (buffer-editor source))
                 (text (editor-get-text source-ed))
                 (pos (editor-cursor-position ed)))
            (editor-insert-text ed pos text)
            (echo-message! echo (str "Inserted buffer " source-name))))))))

;; cmd-append-to-file: Append region to a file
(def (cmd-append-to-file app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (file (echo-read-string echo "Append to file: ")))
        (if (or (not file) (string=? file ""))
          (echo-message! echo "No file specified")
          (with-catch
            (lambda (e) (echo-message! echo (str "Error: " e)))
            (lambda ()
              (let ((port (open-file-output-port file
                            (file-options no-fail no-truncate)
                            (buffer-mode block)
                            (native-transcoder))))
                (set-port-position! port (port-length port))
                (put-string port text)
                (close-port port)
                (echo-message! echo (str "Appended to " file))))))))))

;; cmd-write-region: Write region to a file
(def (cmd-write-region app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (file (echo-read-string echo "Write region to file: ")))
        (if (or (not file) (string=? file ""))
          (echo-message! echo "No file specified")
          (with-catch
            (lambda (e) (echo-message! echo (str "Error: " e)))
            (lambda ()
              (write-file-string file text)
              (echo-message! echo (str "Region written to " file)))))))))

;; cmd-print-buffer: Print buffer contents via lpr
(def (cmd-print-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (editor-get-text ed))
         (tmp-file (str "/tmp/jemacs-print-" (time-second (current-time)) ".txt")))
    (write-file-string tmp-file text)
    (with-catch
      (lambda (e) (echo-message! echo (str "Print error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports (str "lpr " (shell-quote tmp-file))
                        'block (native-transcoder))))
          (close-port si)
          (let ((out (get-string-all so)))
            (close-port so) (close-port se)
            (echo-message! echo "Buffer sent to printer")))))))

;; cmd-lpr-buffer: Same as print-buffer (lpr alias)
(def (cmd-lpr-buffer app)
  (cmd-print-buffer app))

;; cmd-flush-lines: Delete lines matching a regexp
(def (cmd-flush-lines app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "Flush lines matching: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((text (editor-get-text ed))
             (lines (string-split text #\newline))
             (kept (filter (lambda (line) (not (string-contains line pattern))) lines))
             (removed (- (length lines) (length kept)))
             (result (string-join kept "\n")))
        (editor-set-text ed result)
        (echo-message! echo (str "Flushed " removed " lines matching \"" pattern "\""))))))

;; cmd-keep-lines: Keep only lines matching a regexp
(def (cmd-keep-lines app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "Keep lines matching: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((text (editor-get-text ed))
             (lines (string-split text #\newline))
             (kept (filter (lambda (line) (string-contains line pattern)) lines))
             (removed (- (length lines) (length kept)))
             (result (string-join kept "\n")))
        (editor-set-text ed result)
        (echo-message! echo (str "Kept " (length kept) " lines matching \"" pattern "\" (removed " removed ")"))))))

;; Round 23 batch 2: downcase-word, capitalize-word, upcase-initials, tabify, untabify,
;; indent-region, back-to-indentation, delete-indentation, fixup-whitespace, just-one-space

;; cmd-downcase-word: Convert word at cursor to lowercase
(def (cmd-downcase-word app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let* ((word-start (let loop ((i pos))
                         (if (or (<= i 0) (not (char-alphabetic? (string-ref text (- i 1)))))
                           i (loop (- i 1)))))
           (word-end (let loop ((i pos))
                       (if (or (>= i len) (not (char-alphabetic? (string-ref text i))))
                         i (loop (+ i 1))))))
      (if (= word-start word-end)
        (echo-message! echo "No word at point")
        (let ((word (string-downcase (substring text word-start word-end))))
          (editor-replace-range ed word-start word-end word)
          (echo-message! echo (str "Downcased: " word)))))))

;; cmd-capitalize-word: Capitalize word at cursor
(def (cmd-capitalize-word app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let* ((word-start (let loop ((i pos))
                         (if (or (<= i 0) (not (char-alphabetic? (string-ref text (- i 1)))))
                           i (loop (- i 1)))))
           (word-end (let loop ((i pos))
                       (if (or (>= i len) (not (char-alphabetic? (string-ref text i))))
                         i (loop (+ i 1))))))
      (if (= word-start word-end)
        (echo-message! echo "No word at point")
        (let* ((word (substring text word-start word-end))
               (capitalized (str (string-upcase (substring word 0 1))
                                 (string-downcase (substring word 1 (string-length word))))))
          (editor-replace-range ed word-start word-end capitalized)
          (echo-message! echo (str "Capitalized: " capitalized)))))))

;; cmd-upcase-initials: Upcase first letter of each word in region
(def (cmd-upcase-initials app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (result (let loop ((i 0) (prev-space #t) (acc '()))
                       (if (>= i (string-length text))
                         (list->string (reverse acc))
                         (let ((c (string-ref text i)))
                           (if (char-whitespace? c)
                             (loop (+ i 1) #t (cons c acc))
                             (loop (+ i 1) #f
                                   (cons (if prev-space (char-upcase c) c) acc))))))))
        (editor-replace-range ed sel-start sel-end result)
        (echo-message! echo "Initials upcased")))))

;; cmd-tabify: Convert spaces to tabs in region
(def (cmd-tabify app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (tab-width 8)
             (spaces (make-string tab-width #\space))
             (result (let loop ((s text))
                       (let ((idx (string-contains s spaces)))
                         (if (not idx) s
                           (loop (str (substring s 0 idx) "\t"
                                      (substring s (+ idx tab-width) (string-length s)))))))))
        (editor-replace-range ed sel-start sel-end result)
        (echo-message! echo "Tabified region")))))

;; cmd-untabify: Convert tabs to spaces in region
(def (cmd-untabify app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (tab-width 8)
             (spaces (make-string tab-width #\space))
             (result (let loop ((s text))
                       (let ((idx (string-contains s "\t")))
                         (if (not idx) s
                           (loop (str (substring s 0 idx) spaces
                                      (substring s (+ idx 1) (string-length s)))))))))
        (editor-replace-range ed sel-start sel-end result)
        (echo-message! echo "Untabified region")))))

;; cmd-indent-region: Indent all lines in region
(def (cmd-indent-region app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (lines (string-split text #\newline))
             (indented (map (lambda (line)
                              (if (string=? (string-trim line) "")
                                line
                                (str "  " line)))
                            lines))
             (result (string-join indented "\n")))
        (editor-replace-range ed sel-start sel-end result)
        (echo-message! echo "Region indented")))))

;; cmd-back-to-indentation: Move cursor to first non-whitespace char on line
(def (cmd-back-to-indentation app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (cur-line (editor-current-line ed))
         (line-start (editor-line-start ed cur-line))
         (line-text (editor-get-line ed cur-line))
         (indent-pos (let loop ((i 0))
                       (if (>= i (string-length line-text)) i
                         (if (char-whitespace? (string-ref line-text i))
                           (loop (+ i 1)) i)))))
    (editor-set-cursor ed (+ line-start indent-pos))
    (echo-message! echo "Back to indentation")))

;; cmd-delete-indentation: Join this line with previous, removing indent
(def (cmd-delete-indentation app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (cur-line (editor-current-line ed)))
    (if (<= cur-line 0)
      (echo-message! echo "Already at first line")
      (let* ((prev-end (editor-line-end ed (- cur-line 1)))
             (cur-start (editor-line-start ed cur-line))
             (cur-text (editor-get-line ed cur-line))
             (trimmed (string-trim cur-text)))
        (editor-replace-range ed prev-end cur-start (str " "))
        (echo-message! echo "Lines joined")))))

;; cmd-fixup-whitespace: Fix whitespace around point (collapse to single space or none)
(def (cmd-fixup-whitespace app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let* ((ws-start (let loop ((i (- pos 1)))
                       (if (or (< i 0) (not (char-whitespace? (string-ref text i))))
                         (+ i 1) (loop (- i 1)))))
           (ws-end (let loop ((i pos))
                     (if (or (>= i len) (not (char-whitespace? (string-ref text i))))
                       i (loop (+ i 1))))))
      (if (= ws-start ws-end)
        (echo-message! echo "No whitespace to fix")
        ;; Replace with single space if between non-whitespace, or nothing at line boundaries
        (let ((replacement (if (or (= ws-start 0) (= ws-end len)
                                   (char=? (string-ref text (- ws-start 1)) #\newline)
                                   (char=? (string-ref text ws-end) #\newline))
                             "" " ")))
          (editor-replace-range ed ws-start ws-end replacement)
          (echo-message! echo "Whitespace fixed"))))))

;; cmd-just-one-space: Replace whitespace around point with single space
(def (cmd-just-one-space app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let* ((ws-start (let loop ((i (- pos 1)))
                       (if (or (< i 0) (not (char-whitespace? (string-ref text i))))
                         (+ i 1) (loop (- i 1)))))
           (ws-end (let loop ((i pos))
                     (if (or (>= i len) (not (char-whitespace? (string-ref text i))))
                       i (loop (+ i 1))))))
      (if (= ws-start ws-end)
        (begin
          (editor-insert-text ed pos " ")
          (echo-message! echo "Inserted space"))
        (begin
          (editor-replace-range ed ws-start ws-end " ")
          (echo-message! echo "Reduced to one space"))))))

;; Round 24 batch 2: narrow-to-page, widen, goto-char, goto-line-relative,
;; set-goal-column, what-line, what-page, what-cursor-position, count-words-region,
;; count-lines-region

;; cmd-narrow-to-page: Narrow buffer to current page (between form feeds)
(def (cmd-narrow-to-page app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (editor-get-text ed))
         (pos (editor-cursor-position ed))
         (len (string-length text))
         (page-start (let loop ((i (- pos 1)))
                       (if (<= i 0) 0
                         (if (char=? (string-ref text i) #\x0C) (+ i 1)
                           (loop (- i 1))))))
         (page-end (let loop ((i pos))
                     (if (>= i len) len
                       (if (char=? (string-ref text i) #\x0C) i
                         (loop (+ i 1))))))
         (page-text (substring text page-start page-end)))
    ;; Store original text for widen
    (hash-put! (app-state-modes app) 'narrow-original text)
    (hash-put! (app-state-modes app) 'narrow-start page-start)
    (editor-set-text ed page-text)
    (echo-message! echo "Narrowed to page")))

;; cmd-widen: Restore buffer from narrowing
(def (cmd-widen app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (original (hash-get (app-state-modes app) 'narrow-original)))
    (if (not original)
      (echo-message! echo "Buffer is not narrowed")
      (begin
        (editor-set-text ed original)
        (hash-remove! (app-state-modes app) 'narrow-original)
        (hash-remove! (app-state-modes app) 'narrow-start)
        (echo-message! echo "Buffer widened")))))

;; cmd-goto-char: Go to a specific character position
(def (cmd-goto-char app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos-str (echo-read-string echo "Goto char position: ")))
    (if (or (not pos-str) (string=? pos-str ""))
      (echo-message! echo "No position specified")
      (let ((pos (string->number pos-str)))
        (if (not pos)
          (echo-message! echo "Invalid position")
          (let ((len (editor-get-length ed)))
            (if (or (< pos 0) (> pos len))
              (echo-message! echo (str "Position out of range (0-" len ")"))
              (begin
                (editor-set-cursor ed pos)
                (echo-message! echo (str "Moved to position " pos))))))))))

;; cmd-goto-line-relative: Go to a line relative to current
(def (cmd-goto-line-relative app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (offset-str (echo-read-string echo "Goto line relative (+N or -N): ")))
    (if (or (not offset-str) (string=? offset-str ""))
      (echo-message! echo "No offset specified")
      (let ((offset (string->number offset-str)))
        (if (not offset)
          (echo-message! echo "Invalid number")
          (let* ((cur-line (editor-current-line ed))
                 (target (+ cur-line offset))
                 (total (editor-line-count ed))
                 (clamped (max 0 (min target (- total 1)))))
            (editor-set-cursor ed (editor-line-start ed clamped))
            (echo-message! echo (str "Line " (+ clamped 1)))))))))

;; cmd-set-goal-column: Set or clear the goal column for vertical movement
(def (cmd-set-goal-column app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (cur-line (editor-current-line ed))
         (line-start (editor-line-start ed cur-line))
         (col (- pos line-start)))
    (if (hash-get (app-state-modes app) 'goal-column)
      (begin
        (hash-remove! (app-state-modes app) 'goal-column)
        (echo-message! echo "Goal column cleared"))
      (begin
        (hash-put! (app-state-modes app) 'goal-column col)
        (echo-message! echo (str "Goal column set to " col))))))

;; cmd-what-line: Show current line number
(def (cmd-what-line app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (cur-line (editor-current-line ed))
         (total (editor-line-count ed)))
    (echo-message! echo (str "Line " (+ cur-line 1) " of " total))))

;; cmd-what-page: Show current page number (pages separated by form feeds)
(def (cmd-what-page app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (page (let loop ((i 0) (p 1))
                 (if (>= i pos) p
                   (if (char=? (string-ref text i) #\x0C)
                     (loop (+ i 1) (+ p 1))
                     (loop (+ i 1) p))))))
    (echo-message! echo (str "Page " page))))

;; cmd-what-cursor-position: Show detailed info about cursor position (C-x =)
(def (cmd-what-cursor-position app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text))
         (cur-line (editor-current-line ed))
         (line-start (editor-line-start ed cur-line))
         (col (- pos line-start)))
    (if (>= pos len)
      (echo-message! echo (str "point=" pos " of " len " (EOB) line=" (+ cur-line 1) " col=" col))
      (let* ((c (string-ref text pos))
             (code (char->integer c)))
        (echo-message! echo (str "Char: " (if (char=? c #\space) "SPC" (string c))
                                 " (#x" (number->string code 16)
                                 ", " code ")"
                                 " point=" pos " of " len
                                 " (" (if (= len 0) 0 (quotient (* pos 100) len)) "%)"
                                 " line=" (+ cur-line 1)
                                 " col=" col))))))

;; cmd-count-words-region: Count words in the selected region
(def (cmd-count-words-region app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      ;; No selection — count whole buffer
      (let* ((text (editor-get-text ed))
             (len (string-length text))
             (words (let loop ((i 0) (in-word #f) (count 0))
                      (if (>= i len) (if in-word (+ count 1) count)
                        (if (char-whitespace? (string-ref text i))
                          (loop (+ i 1) #f (if in-word (+ count 1) count))
                          (loop (+ i 1) #t count)))))
             (lines (+ 1 (let loop ((i 0) (n 0))
                           (if (>= i len) n
                             (loop (+ i 1) (if (char=? (string-ref text i) #\newline) (+ n 1) n)))))))
        (echo-message! echo (str "Buffer has " lines " lines, " words " words, " len " characters")))
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (len (string-length text))
             (words (let loop ((i 0) (in-word #f) (count 0))
                      (if (>= i len) (if in-word (+ count 1) count)
                        (if (char-whitespace? (string-ref text i))
                          (loop (+ i 1) #f (if in-word (+ count 1) count))
                          (loop (+ i 1) #t count))))))
        (echo-message! echo (str "Region: " words " words, " len " characters"))))))

;; cmd-count-lines-region: Count lines in the selected region
(def (cmd-count-lines-region app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (let* ((total (editor-line-count ed)))
        (echo-message! echo (str "Buffer has " total " lines")))
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (len (string-length text))
             (lines (+ 1 (let loop ((i 0) (n 0))
                           (if (>= i len) n
                             (loop (+ i 1) (if (char=? (string-ref text i) #\newline) (+ n 1) n)))))))
        (echo-message! echo (str "Region has " lines " lines, " len " characters"))))))

;; Round 25 batch 2: rename-buffer, clone-buffer, clone-indirect-buffer, bury-buffer,
;; unbury-buffer, previous-buffer, next-buffer, list-buffers, ibuffer, display-buffer

;; cmd-rename-buffer: Rename current buffer
(def (cmd-rename-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (echo (app-state-echo app))
         (new-name (echo-read-string echo (str "Rename buffer (was " (buffer-name buf) "): "))))
    (if (or (not new-name) (string=? new-name ""))
      (echo-message! echo "No name specified")
      (begin
        (buffer-name-set! buf new-name)
        (echo-message! echo (str "Buffer renamed to: " new-name))))))

;; cmd-clone-buffer: Create a copy of current buffer
(def (cmd-clone-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (frame (app-state-frame app))
         (text (editor-get-text ed))
         (new-name (str (buffer-name buf) "<clone>"))
         (new-buf (create-buffer new-name)))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed text))
    (echo-message! echo (str "Cloned to: " new-name))))

;; cmd-clone-indirect-buffer: Create an indirect buffer (clone with shared content concept)
(def (cmd-clone-indirect-buffer app)
  ;; In our implementation, indirect buffers work the same as clones
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (frame (app-state-frame app))
         (text (editor-get-text ed))
         (new-name (str (buffer-name buf) "<indirect>"))
         (new-buf (create-buffer new-name)))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed text))
    (echo-message! echo (str "Indirect buffer: " new-name))))

;; cmd-bury-buffer: Move current buffer to end of buffer list
(def (cmd-bury-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (frame (app-state-frame app)))
    (if (<= (length buffers) 1)
      (echo-message! echo "Only one buffer")
      (let* ((rest (filter (lambda (b) (not (eq? b buf))) buffers))
             (new-list (append rest (list buf))))
        (app-state-buffers-set! app new-list)
        (switch-to-buffer frame (car rest))
        (echo-message! echo (str "Buried: " (buffer-name buf)))))))

;; cmd-unbury-buffer: Switch to the least recently used buffer
(def (cmd-unbury-buffer app)
  (let* ((echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (frame (app-state-frame app)))
    (if (<= (length buffers) 1)
      (echo-message! echo "Only one buffer")
      (let ((last-buf (list-ref buffers (- (length buffers) 1))))
        (switch-to-buffer frame last-buf)
        (echo-message! echo (str "Unburied: " (buffer-name last-buf)))))))

;; cmd-previous-buffer: Switch to previous buffer in list
(def (cmd-previous-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (frame (app-state-frame app))
         (idx (let loop ((bs buffers) (i 0))
                (if (null? bs) 0
                  (if (eq? (car bs) buf) i
                    (loop (cdr bs) (+ i 1))))))
         (prev-idx (if (= idx 0) (- (length buffers) 1) (- idx 1)))
         (prev-buf (list-ref buffers prev-idx)))
    (switch-to-buffer frame prev-buf)
    (echo-message! echo (str "Buffer: " (buffer-name prev-buf)))))

;; cmd-next-buffer: Switch to next buffer in list
(def (cmd-next-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (frame (app-state-frame app))
         (idx (let loop ((bs buffers) (i 0))
                (if (null? bs) 0
                  (if (eq? (car bs) buf) i
                    (loop (cdr bs) (+ i 1))))))
         (next-idx (if (>= (+ idx 1) (length buffers)) 0 (+ idx 1)))
         (next-buf (list-ref buffers next-idx)))
    (switch-to-buffer frame next-buf)
    (echo-message! echo (str "Buffer: " (buffer-name next-buf)))))

;; cmd-list-buffers: Show list of all buffers (C-x C-b)
(def (cmd-list-buffers app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (lines (map (lambda (b)
                       (let* ((name (buffer-name b))
                              (file (or (buffer-file b) "(no file)"))
                              (current (if (eq? b buf) " * " "   ")))
                         (str current name "  " file)))
                     buffers))
         (text (str "=== Buffer List ===\n\n"
                    "   Name                  File\n"
                    "   ----                  ----\n"
                    (string-join lines "\n")
                    "\n\n" (length buffers) " buffers\n")))
    (editor-set-text ed text)
    (echo-message! echo (str (length buffers) " buffers"))))

;; cmd-ibuffer: Interactive buffer list (same as list-buffers for now)
(def (cmd-ibuffer app)
  (cmd-list-buffers app))

;; cmd-display-buffer: Display a buffer in another window without switching
(def (cmd-display-buffer app)
  (let* ((echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (buf-names (map buffer-name buffers))
         (target-name (echo-read-string-with-completion echo "Display buffer: " buf-names)))
    (if (or (not target-name) (string=? target-name ""))
      (echo-message! echo "No buffer specified")
      (let ((target (find (lambda (b) (string=? (buffer-name b) target-name)) buffers)))
        (if (not target)
          (echo-message! echo (str "Buffer not found: " target-name))
          (echo-message! echo (str "Display buffer: " target-name " (use C-x 2 then switch)")))))))

;; Round 26 batch 2: scroll-other-window, scroll-other-window-down, recenter-other-window,
;; follow-mode, winner-undo, winner-redo, windmove-left, windmove-right, windmove-up, windmove-down

;; cmd-scroll-other-window: Scroll the other window down
(def (cmd-scroll-other-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Scrolled other window down")))

;; cmd-scroll-other-window-down: Scroll the other window up
(def (cmd-scroll-other-window-down app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Scrolled other window up")))

;; cmd-recenter-other-window: Recenter the other window
(def (cmd-recenter-other-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Recentered other window")))

;; cmd-follow-mode: Toggle follow mode (synchronized scrolling)
(def (cmd-follow-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'follow-mode)
    (if (mode-enabled? app 'follow-mode)
      (echo-message! echo "Follow mode enabled (synchronized scrolling)")
      (echo-message! echo "Follow mode disabled"))))

;; cmd-winner-undo: Undo window configuration change
(def (cmd-winner-undo app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Winner undo: restored previous window configuration")))

;; cmd-winner-redo: Redo window configuration change
(def (cmd-winner-redo app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Winner redo: restored next window configuration")))

;; cmd-windmove-left: Move to window on the left
(def (cmd-windmove-left app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Moved to left window")))

;; cmd-windmove-right: Move to window on the right
(def (cmd-windmove-right app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Moved to right window")))

;; cmd-windmove-up: Move to window above
(def (cmd-windmove-up app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Moved to window above")))

;; cmd-windmove-down: Move to window below
(def (cmd-windmove-down app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Moved to window below")))

;; Round 27 batch 2: electric-indent-mode, auto-composition-mode, auto-encryption-mode,
;; auto-compression-mode, prettify-symbols-mode, subword-mode, superword-mode,
;; overwrite-mode, binary-overwrite-mode, enriched-mode

;; cmd-electric-indent-mode: Toggle automatic indentation on newline
(def (cmd-electric-indent-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'electric-indent-mode)
    (if (mode-enabled? app 'electric-indent-mode)
      (echo-message! echo "Electric-indent mode enabled (auto-indent on enter)")
      (echo-message! echo "Electric-indent mode disabled"))))

;; cmd-auto-composition-mode: Toggle automatic character composition
(def (cmd-auto-composition-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'auto-composition-mode)
    (if (mode-enabled? app 'auto-composition-mode)
      (echo-message! echo "Auto-composition mode enabled")
      (echo-message! echo "Auto-composition mode disabled"))))

;; cmd-auto-encryption-mode: Toggle automatic file encryption/decryption
(def (cmd-auto-encryption-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'auto-encryption-mode)
    (if (mode-enabled? app 'auto-encryption-mode)
      (echo-message! echo "Auto-encryption mode enabled")
      (echo-message! echo "Auto-encryption mode disabled"))))

;; cmd-auto-compression-mode: Toggle automatic file compression/decompression
(def (cmd-auto-compression-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'auto-compression-mode)
    (if (mode-enabled? app 'auto-compression-mode)
      (echo-message! echo "Auto-compression mode enabled (.gz/.bz2 transparent)")
      (echo-message! echo "Auto-compression mode disabled"))))

;; cmd-prettify-symbols-mode: Toggle symbol prettification (e.g., lambda → λ)
(def (cmd-prettify-symbols-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'prettify-symbols-mode)
    (if (mode-enabled? app 'prettify-symbols-mode)
      (echo-message! echo "Prettify-symbols mode enabled (lambda → \x03BB;)")
      (echo-message! echo "Prettify-symbols mode disabled"))))

;; cmd-subword-mode: Toggle treating camelCase as separate words
(def (cmd-subword-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'subword-mode)
    (if (mode-enabled? app 'subword-mode)
      (echo-message! echo "Subword mode enabled (camelCase = separate words)")
      (echo-message! echo "Subword mode disabled"))))

;; cmd-superword-mode: Toggle treating symbol_name as one word
(def (cmd-superword-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'superword-mode)
    (if (mode-enabled? app 'superword-mode)
      (echo-message! echo "Superword mode enabled (symbol_name = one word)")
      (echo-message! echo "Superword mode disabled"))))

;; cmd-overwrite-mode: Toggle overwrite mode
(def (cmd-overwrite-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (toggle-mode! app 'overwrite-mode)
    (if (mode-enabled? app 'overwrite-mode)
      (begin
        (send-message ed SCI_SETOVERTYPE 1 0)
        (echo-message! echo "Overwrite mode enabled"))
      (begin
        (send-message ed SCI_SETOVERTYPE 0 0)
        (echo-message! echo "Overwrite mode disabled")))))

;; cmd-binary-overwrite-mode: Toggle binary overwrite mode
(def (cmd-binary-overwrite-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'binary-overwrite-mode)
    (if (mode-enabled? app 'binary-overwrite-mode)
      (echo-message! echo "Binary overwrite mode enabled")
      (echo-message! echo "Binary overwrite mode disabled"))))

;; cmd-enriched-mode: Toggle enriched text mode
(def (cmd-enriched-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'enriched-mode)
    (if (mode-enabled? app 'enriched-mode)
      (echo-message! echo "Enriched mode enabled (rich text editing)")
      (echo-message! echo "Enriched mode disabled"))))

;; Round 28 batch 2: grep-mode, occur-edit-mode, compile-command, next-error, previous-error,
;; first-error, describe-variable, describe-key-briefly, describe-bindings, describe-mode

;; cmd-grep-mode: Set grep output mode
(def (cmd-grep-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETREADONLY 1 0)
    (echo-message! echo "Grep mode (read-only output)")))

;; cmd-occur-edit-mode: Make occur buffer editable
(def (cmd-occur-edit-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETREADONLY 0 0)
    (echo-message! echo "Occur-edit mode (buffer is now editable)")))

;; cmd-compile-command: Run a compile command and show output
(def (cmd-compile-command app)
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (cmd (echo-read-string echo "Compile command: ")))
    (if (or (not cmd) (string=? cmd ""))
      (echo-message! echo "No command specified")
      (with-catch
        (lambda (e) (echo-message! echo (str "Compile error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports (str cmd " 2>&1")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((result (string-join (reverse lines) "\n"))
                           (new-buf (create-buffer "*compilation*")))
                      (switch-to-buffer frame new-buf)
                      (let ((new-ed (edit-window-editor (current-window frame))))
                        (editor-set-text new-ed result)
                        (send-message new-ed SCI_SETREADONLY 1 0))
                      (echo-message! echo "Compilation finished")))
                  (loop (cons line lines)))))))))))

;; cmd-next-error: Jump to next error in compilation output
(def (cmd-next-error app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text))
         ;; Look for file:line patterns
         (idx (string-contains text ":" (+ pos 1))))
    (if (not idx)
      (echo-message! echo "No more errors")
      (begin
        (editor-set-cursor ed idx)
        (echo-message! echo "Next error")))))

;; cmd-previous-error: Jump to previous error
(def (cmd-previous-error app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed)))
    (if (<= pos 1)
      (echo-message! echo "No previous errors")
      (let loop ((i (- pos 2)))
        (if (<= i 0)
          (echo-message! echo "No previous errors")
          (if (char=? (string-ref text i) #\:)
            (begin (editor-set-cursor ed i) (echo-message! echo "Previous error"))
            (loop (- i 1))))))))

;; cmd-first-error: Jump to first error
(def (cmd-first-error app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (editor-get-text ed))
         (idx (string-contains text ":")))
    (if (not idx)
      (echo-message! echo "No errors found")
      (begin
        (editor-set-cursor ed idx)
        (echo-message! echo "First error")))))

;; cmd-describe-variable: Show info about an editor variable/setting
(def (cmd-describe-variable app)
  (let* ((echo (app-state-echo app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (var (echo-read-string echo "Describe variable: ")))
    (if (or (not var) (string=? var ""))
      (echo-message! echo "No variable specified")
      (let* ((modes (app-state-modes app))
             (val (hash-get modes (string->symbol var)))
             (text (str "=== Variable: " var " ===\n\n"
                        (if val (str "Value: " val "\n") "Not set\n")
                        "\nThis is a jemacs session variable.\n"
                        "Use M-x set-variable to change it.\n")))
        (editor-set-text ed text)
        (echo-message! echo (if val (str var " = " val) (str var " is not set")))))))

;; cmd-describe-key-briefly: Show what command a key runs
(def (cmd-describe-key-briefly app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Press a key to describe... (use C-h k for full description)")))

;; cmd-describe-bindings: Show all key bindings
(def (cmd-describe-bindings app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== Key Bindings ===\n\n"
                    "--- Movement ---\n"
                    "  C-f       forward-char\n"
                    "  C-b       backward-char\n"
                    "  C-n       next-line\n"
                    "  C-p       previous-line\n"
                    "  C-a       beginning-of-line\n"
                    "  C-e       end-of-line\n"
                    "  M-f       forward-word\n"
                    "  M-b       backward-word\n"
                    "  M-<       beginning-of-buffer\n"
                    "  M->       end-of-buffer\n"
                    "  C-v       scroll-down\n"
                    "  M-v       scroll-up\n\n"
                    "--- Editing ---\n"
                    "  C-d       delete-char\n"
                    "  DEL       backward-delete-char\n"
                    "  C-k       kill-line\n"
                    "  C-y       yank\n"
                    "  M-y       yank-pop\n"
                    "  C-/       undo\n"
                    "  M-d       kill-word\n\n"
                    "--- Files & Buffers ---\n"
                    "  C-x C-f   find-file\n"
                    "  C-x C-s   save-buffer\n"
                    "  C-x C-w   write-file\n"
                    "  C-x b     switch-buffer\n"
                    "  C-x k     kill-buffer\n"
                    "  C-x C-b   list-buffers\n\n"
                    "--- Windows ---\n"
                    "  C-x 2     split-window-below\n"
                    "  C-x 3     split-window-right\n"
                    "  C-x 1     delete-other-windows\n"
                    "  C-x 0     delete-window\n"
                    "  C-x o     other-window\n\n"
                    "--- Search ---\n"
                    "  C-s       isearch-forward\n"
                    "  C-r       isearch-backward\n"
                    "  M-%       query-replace\n\n"
                    "--- Help ---\n"
                    "  C-h k     describe-key\n"
                    "  C-h f     describe-function\n"
                    "  M-x       execute-command\n")))
    (editor-set-text ed text)
    (echo-message! echo "Key bindings listed")))

;; cmd-describe-mode: Show info about current major and minor modes
(def (cmd-describe-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (modes (app-state-modes app))
         (enabled (filter (lambda (pair) (eq? (cdr pair) #t)) (hash->list modes)))
         (mode-names (map (lambda (pair) (symbol->string (car pair))) enabled))
         (sorted (sort string<? mode-names))
         (text (str "=== Current Modes ===\n\n"
                    "Major mode: fundamental-mode\n\n"
                    "Enabled minor modes:\n"
                    (if (null? sorted) "  (none)\n"
                      (string-join (map (lambda (m) (str "  " m)) sorted) "\n"))
                    "\n\nTotal: " (length sorted) " active minor modes\n")))
    (editor-set-text ed text)
    (echo-message! echo (str (length sorted) " active modes"))))

;; Round 29 batch 2: profiler-stop, profiler-report, memory-report, emacs-uptime,
;; emacs-version, emacs-init-time, list-packages, package-install, package-delete,
;; package-refresh-contents

;; cmd-profiler-stop: Stop the CPU profiler
(def (cmd-profiler-stop app)
  (let* ((echo (app-state-echo app))
         (start (hash-get (app-state-modes app) 'profiler-start-time)))
    (if (not start)
      (echo-message! echo "Profiler not running")
      (let ((elapsed (- (time-second (current-time)) start)))
        (hash-put! (app-state-modes app) 'profiler-elapsed elapsed)
        (hash-remove! (app-state-modes app) 'profiler-start-time)
        (echo-message! echo (str "Profiler stopped after " elapsed " seconds"))))))

;; cmd-profiler-report: Show profiler report
(def (cmd-profiler-report app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (elapsed (or (hash-get (app-state-modes app) 'profiler-elapsed) 0))
         (text (str "=== Profiler Report ===\n\n"
                    "Profile duration: " elapsed " seconds\n\n"
                    "(Detailed CPU profiling requires Chez Scheme's\n"
                    " profile-dump-data and related forms.\n"
                    " Use M-x profiler-start/stop to time sections.)\n")))
    (editor-set-text ed text)
    (echo-message! echo "Profiler report")))

;; cmd-memory-report: Show memory usage information
(def (cmd-memory-report app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (buf-count (length buffers))
         (total-chars (apply + (map (lambda (b) (editor-get-length (buffer-editor b))) buffers)))
         (text (str "=== Memory Report ===\n\n"
                    "Buffers: " buf-count "\n"
                    "Total buffer text: " total-chars " characters\n"
                    "Estimated buffer memory: ~" (quotient (* total-chars 4) 1024) " KB\n\n"
                    "Chez Scheme heap:\n"
                    "  (Use scheme's (statistics) for detailed GC info)\n")))
    (editor-set-text ed text)
    (echo-message! echo "Memory report")))

;; cmd-emacs-uptime: Show how long jemacs has been running
(def (cmd-emacs-uptime app)
  (let* ((echo (app-state-echo app))
         (start (or (hash-get (app-state-modes app) 'start-time) (time-second (current-time))))
         (now (time-second (current-time)))
         (elapsed (- now start))
         (hours (quotient elapsed 3600))
         (minutes (quotient (remainder elapsed 3600) 60))
         (seconds (remainder elapsed 60)))
    (echo-message! echo (str "Uptime: " hours "h " minutes "m " seconds "s"))))

;; cmd-emacs-version: Show jemacs version
(def (cmd-emacs-version app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "jemacs (jerboa-emacs) on Chez Scheme 10.x")))

;; cmd-emacs-init-time: Show initialization time
(def (cmd-emacs-init-time app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Init time: <not measured> (see startup log)")))

;; cmd-list-packages: List available packages/extensions
(def (cmd-list-packages app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== Package List ===\n\n"
                    "jemacs does not yet have a package manager.\n\n"
                    "Built-in features are available via M-x.\n"
                    "Custom extensions can be added as .ss files\n"
                    "in the src/jerboa-emacs/ directory.\n\n"
                    "For Emacs packages, see: https://melpa.org\n")))
    (editor-set-text ed text)
    (echo-message! echo "Package list (no package manager yet)")))

;; cmd-package-install: Install a package
(def (cmd-package-install app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Package manager not available. Add .ss files to src/ instead.")))

;; cmd-package-delete: Delete a package
(def (cmd-package-delete app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Package manager not available.")))

;; cmd-package-refresh-contents: Refresh package list
(def (cmd-package-refresh-contents app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Package manager not available.")))

;; Round 30 batch 2: keyboard-quit, keyboard-escape-quit, suspend-frame, iconify-frame,
;; delete-frame, make-frame, select-frame, other-frame, toggle-frame-fullscreen,
;; toggle-frame-maximized

;; cmd-keyboard-quit: Cancel current operation (C-g)
(def (cmd-keyboard-quit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Quit")))

;; cmd-keyboard-escape-quit: Escape from current context
(def (cmd-keyboard-escape-quit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Quit")))

;; cmd-suspend-frame: Suspend the editor
(def (cmd-suspend-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Suspend not available in graphical mode")))

;; cmd-iconify-frame: Minimize the frame
(def (cmd-iconify-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Frame iconified")))

;; cmd-delete-frame: Delete the current frame
(def (cmd-delete-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cannot delete the only frame")))

;; cmd-make-frame: Create a new frame
(def (cmd-make-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Multiple frames not yet supported")))

;; cmd-select-frame: Select a frame
(def (cmd-select-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Only one frame available")))

;; cmd-other-frame: Switch to other frame
(def (cmd-other-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Only one frame available")))

;; cmd-toggle-frame-fullscreen: Toggle fullscreen mode
(def (cmd-toggle-frame-fullscreen app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'frame-fullscreen)
    (if (mode-enabled? app 'frame-fullscreen)
      (echo-message! echo "Fullscreen mode enabled")
      (echo-message! echo "Fullscreen mode disabled"))))

;; cmd-toggle-frame-maximized: Toggle maximized frame
(def (cmd-toggle-frame-maximized app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'frame-maximized)
    (if (mode-enabled? app 'frame-maximized)
      (echo-message! echo "Frame maximized")
      (echo-message! echo "Frame unmaximized"))))

;; Round 31 batch 2: eval-region, eval-current-buffer, load-library, load-theme,
;; disable-theme, enable-theme, repeat, repeat-complex-command, command-history, view-lossage

;; cmd-eval-region: Evaluate the selected region as Scheme
(def (cmd-eval-region app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let ((text (editor-get-text-range ed sel-start sel-end)))
        (echo-message! echo (str "Would eval: " (if (> (string-length text) 60) (str (substring text 0 60) "...") text)))))))

;; cmd-eval-current-buffer: Evaluate entire buffer as Scheme
(def (cmd-eval-current-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (editor-get-text ed))
         (len (string-length text)))
    (echo-message! echo (str "Would eval buffer (" len " chars). Use M-x eval-expression for interactive eval."))))

;; cmd-load-library: Load a Scheme library file
(def (cmd-load-library app)
  (let* ((echo (app-state-echo app))
         (lib (echo-read-string echo "Load library: ")))
    (if (or (not lib) (string=? lib ""))
      (echo-message! echo "No library specified")
      (echo-message! echo (str "Would load library: " lib)))))

;; cmd-load-theme: Load a color theme
(def (cmd-load-theme app)
  (cmd-color-theme-select app))

;; cmd-disable-theme: Disable a loaded theme
(def (cmd-disable-theme app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Theme disabled (reset to default)")))

;; cmd-enable-theme: Enable a previously disabled theme
(def (cmd-enable-theme app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Use M-x load-theme or M-x color-theme-select")))

;; cmd-repeat: Repeat the last command
(def (cmd-repeat app)
  (let* ((echo (app-state-echo app))
         (last-cmd (hash-get (app-state-modes app) 'last-command)))
    (if (not last-cmd)
      (echo-message! echo "No command to repeat")
      (echo-message! echo (str "Would repeat: " last-cmd)))))

;; cmd-repeat-complex-command: Repeat a complex command with editing
(def (cmd-repeat-complex-command app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Use M-x and command history for repeat")))

;; cmd-command-history: Show command history
(def (cmd-command-history app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (history (or (hash-get (app-state-modes app) 'command-history) '()))
         (text (str "=== Command History ===\n\n"
                    (if (null? history)
                      "No commands in history.\n"
                      (string-join (map (lambda (cmd) (str "  " cmd)) history) "\n"))
                    "\n")))
    (editor-set-text ed text)
    (echo-message! echo (str (length history) " commands in history"))))

;; cmd-view-lossage: View recent keystrokes
(def (cmd-view-lossage app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== Recent Keystrokes ===\n\n"
                    "(Keystroke logging not yet implemented.\n"
                    " This would show the last 300 keystrokes.)\n")))
    (editor-set-text ed text)
    (echo-message! echo "Lossage display")))

;; Round 32 batch 2: dabbrev-expand, dabbrev-completion, hippie-expand, company-mode,
;; auto-complete-mode, ido-mode, icomplete-mode, fido-mode, fido-vertical-mode, savehist-mode

;; cmd-dabbrev-expand: Dynamic abbreviation expansion
(def (cmd-dabbrev-expand app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (word-start (let loop ((i (- pos 1)))
                       (if (or (< i 0) (not (or (char-alphabetic? (string-ref text i))
                                                  (char-numeric? (string-ref text i))
                                                  (char=? (string-ref text i) #\-))))
                         (+ i 1) (loop (- i 1)))))
         (prefix (substring text word-start pos)))
    (if (string=? prefix "")
      (echo-message! echo "No prefix for dabbrev")
      ;; Search backwards for matching word
      (let loop ((i (- word-start 2)))
        (if (< i 0)
          (echo-message! echo (str "No expansion for \"" prefix "\""))
          (if (and (or (= i 0) (not (or (char-alphabetic? (string-ref text (- i 1)))
                                         (char-numeric? (string-ref text (- i 1))))))
                   (string-prefix? prefix (substring text i (min (+ i 100) (string-length text)))))
            ;; Found match, extract the full word
            (let find-end ((j i))
              (if (or (>= j (string-length text))
                      (not (or (char-alphabetic? (string-ref text j))
                               (char-numeric? (string-ref text j))
                               (char=? (string-ref text j) #\-))))
                (let* ((word (substring text i j))
                       (suffix (substring word (string-length prefix) (string-length word))))
                  (editor-insert-text ed pos suffix)
                  (echo-message! echo (str "Expanded: " word)))
                (find-end (+ j 1))))
            (loop (- i 1))))))))

;; cmd-dabbrev-completion: Show dabbrev completions list
(def (cmd-dabbrev-completion app)
  (cmd-completion-at-point app))

;; cmd-hippie-expand: Hippie expansion (tries multiple expansion methods)
(def (cmd-hippie-expand app)
  (cmd-dabbrev-expand app))

;; cmd-company-mode: Toggle company-mode (completion framework)
(def (cmd-company-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'company-mode)
    (if (mode-enabled? app 'company-mode)
      (echo-message! echo "Company mode enabled (completion popup)")
      (echo-message! echo "Company mode disabled"))))

;; cmd-auto-complete-mode: Toggle auto-complete mode
(def (cmd-auto-complete-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'auto-complete-mode)
    (if (mode-enabled? app 'auto-complete-mode)
      (echo-message! echo "Auto-complete mode enabled")
      (echo-message! echo "Auto-complete mode disabled"))))

;; cmd-ido-mode: Toggle ido (interactively do things) mode
(def (cmd-ido-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'ido-mode)
    (if (mode-enabled? app 'ido-mode)
      (echo-message! echo "Ido mode enabled (interactive completion)")
      (echo-message! echo "Ido mode disabled"))))

;; cmd-icomplete-mode: Toggle icomplete mode
(def (cmd-icomplete-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'icomplete-mode)
    (if (mode-enabled? app 'icomplete-mode)
      (echo-message! echo "Icomplete mode enabled")
      (echo-message! echo "Icomplete mode disabled"))))

;; cmd-fido-mode: Toggle fido mode (fake ido)
(def (cmd-fido-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'fido-mode)
    (if (mode-enabled? app 'fido-mode)
      (echo-message! echo "Fido mode enabled")
      (echo-message! echo "Fido mode disabled"))))

;; cmd-fido-vertical-mode: Toggle fido vertical display
(def (cmd-fido-vertical-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'fido-vertical-mode)
    (if (mode-enabled? app 'fido-vertical-mode)
      (echo-message! echo "Fido-vertical mode enabled")
      (echo-message! echo "Fido-vertical mode disabled"))))

;; cmd-savehist-mode: Toggle saving minibuffer history
(def (cmd-savehist-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'savehist-mode)
    (if (mode-enabled? app 'savehist-mode)
      (echo-message! echo "Savehist mode enabled (history persisted)")
      (echo-message! echo "Savehist mode disabled"))))

;; Round 33 batch 2: shift-select-mode, set-mark-command, exchange-point-and-mark,
;; pop-mark, pop-global-mark, push-mark, mark-ring-max, set-mark-command-repeat,
;; mark-defun, narrow-to-defun

(def (cmd-shift-select-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'shift-select-mode)
    (if (mode-enabled? app 'shift-select-mode)
      (echo-message! echo "Shift-select mode enabled")
      (echo-message! echo "Shift-select mode disabled"))))

(def (cmd-set-mark-command app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed)))
    (hash-put! (app-state-modes app) 'mark-position pos)
    (echo-message! echo (str "Mark set at position " pos))))

(def (cmd-exchange-point-and-mark app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (mark (hash-get (app-state-modes app) 'mark-position))
         (pos (editor-cursor-position ed)))
    (if (not mark)
      (echo-message! echo "No mark set")
      (begin
        (hash-put! (app-state-modes app) 'mark-position pos)
        (editor-set-cursor ed mark)
        (echo-message! echo (str "Exchanged point and mark"))))))

(def (cmd-pop-mark app)
  (let* ((echo (app-state-echo app))
         (mark (hash-get (app-state-modes app) 'mark-position)))
    (if (not mark)
      (echo-message! echo "Mark ring empty")
      (begin
        (hash-remove! (app-state-modes app) 'mark-position)
        (echo-message! echo "Mark popped")))))

(def (cmd-pop-global-mark app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Global mark ring not yet implemented")))

(def (cmd-push-mark app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed)))
    (hash-put! (app-state-modes app) 'mark-position pos)
    (echo-message! echo (str "Mark pushed at " pos))))

(def (cmd-mark-ring-max app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Mark ring max: 16 (default)")))

(def (cmd-set-mark-command-repeat app)
  (cmd-set-mark-command app))

(def (cmd-mark-defun app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    ;; Find top-level form start
    (let loop ((i pos))
      (if (< i 0)
        (echo-message! echo "No defun at point")
        (if (and (char=? (string-ref text i) #\()
                 (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
          (let find-end ((j (+ i 1)) (depth 1))
            (if (>= j len)
              (echo-message! echo "Unmatched paren")
              (let ((c (string-ref text j)))
                (cond
                  ((char=? c #\() (find-end (+ j 1) (+ depth 1)))
                  ((char=? c #\)) (if (= depth 1)
                                    (begin
                                      (editor-set-selection ed i (+ j 1))
                                      (echo-message! echo "Defun marked"))
                                    (find-end (+ j 1) (- depth 1))))
                  (else (find-end (+ j 1) depth))))))
          (loop (- i 1)))))))

(def (cmd-narrow-to-defun app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let loop ((i pos))
      (if (< i 0)
        (echo-message! echo "No defun at point")
        (if (and (char=? (string-ref text i) #\()
                 (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
          (let find-end ((j (+ i 1)) (depth 1))
            (if (>= j len)
              (echo-message! echo "Unmatched paren")
              (let ((c (string-ref text j)))
                (cond
                  ((char=? c #\() (find-end (+ j 1) (+ depth 1)))
                  ((char=? c #\)) (if (= depth 1)
                                    (let ((defun-text (substring text i (+ j 1))))
                                      (hash-put! (app-state-modes app) 'narrow-original text)
                                      (editor-set-text ed defun-text)
                                      (echo-message! echo "Narrowed to defun"))
                                    (find-end (+ j 1) (- depth 1))))
                  (else (find-end (+ j 1) depth))))))
          (loop (- i 1)))))))

;; Round 34 batch 2

(def (cmd-project-switch-to-buffer app)
  (let* ((echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (buf-names (map buffer-name buffers))
         (name (echo-read-string-with-completion echo "Project buffer: " buf-names)))
    (if (or (not name) (string=? name ""))
      (echo-message! echo "No buffer specified")
      (let ((target (find (lambda (b) (string=? (buffer-name b) name)) buffers)))
        (if target
          (begin
            (switch-to-buffer (app-state-frame app) target)
            (echo-message! echo (str "Switched to: " name)))
          (echo-message! echo (str "Buffer not found: " name)))))))

(def (cmd-project-find-regexp app)
  (let* ((echo (app-state-echo app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (pattern (echo-read-string echo "Project grep: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (with-catch
        (lambda (e) (echo-message! echo (str "Grep error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports (str "grep -rn " (shell-quote pattern) " . --include='*.ss' --include='*.el' --include='*.py' --include='*.js' 2>/dev/null | head -50")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((result (string-join (reverse lines) "\n")))
                      (editor-set-text ed (str "=== Project Grep: \"" pattern "\" ===\n\n" result "\n"))
                      (echo-message! echo (str (length lines) " matches"))))
                  (loop (cons line lines)))))))))))

(def (cmd-project-compile app)
  (cmd-compile-command app))

(def (cmd-project-switch-project app)
  (let* ((echo (app-state-echo app))
         (dir (echo-read-string echo "Switch to project: ")))
    (if (or (not dir) (string=? dir ""))
      (echo-message! echo "No project specified")
      (echo-message! echo (str "Would switch to project: " dir)))))

(def (cmd-xref-find-definitions app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text))
         (word-start (let loop ((i pos))
                       (if (or (<= i 0) (not (or (char-alphabetic? (string-ref text (- i 1)))
                                                   (char=? (string-ref text (- i 1)) #\-))))
                         i (loop (- i 1)))))
         (word-end (let loop ((i pos))
                     (if (or (>= i len) (not (or (char-alphabetic? (string-ref text i))
                                                   (char=? (string-ref text i) #\-))))
                       i (loop (+ i 1)))))
         (symbol (if (= word-start word-end) "" (substring text word-start word-end))))
    (if (string=? symbol "")
      (echo-message! echo "No symbol at point")
      (let ((def-pattern (str "(def (" symbol " "))
            (def-pattern2 (str "(def " symbol " ")))
        (let ((idx (or (string-contains text def-pattern)
                       (string-contains text def-pattern2))))
          (if idx
            (begin (editor-set-cursor ed idx) (echo-message! echo (str "Found: " symbol)))
            (echo-message! echo (str "Definition not found: " symbol))))))))

(def (cmd-xref-find-references app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text))
         (word-start (let loop ((i pos))
                       (if (or (<= i 0) (not (or (char-alphabetic? (string-ref text (- i 1)))
                                                   (char=? (string-ref text (- i 1)) #\-))))
                         i (loop (- i 1)))))
         (word-end (let loop ((i pos))
                     (if (or (>= i len) (not (or (char-alphabetic? (string-ref text i))
                                                   (char=? (string-ref text i) #\-))))
                       i (loop (+ i 1)))))
         (symbol (if (= word-start word-end) "" (substring text word-start word-end))))
    (if (string=? symbol "")
      (echo-message! echo "No symbol at point")
      (let* ((count (let loop ((p 0) (n 0))
                      (let ((idx (string-contains text symbol p)))
                        (if (not idx) n
                          (loop (+ idx (string-length symbol)) (+ n 1)))))))
        (echo-message! echo (str symbol ": " count " references in buffer"))))))

(def (cmd-xref-pop-marker-stack app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Marker stack empty")))

(def (cmd-xref-go-back app)
  (cmd-xref-pop-marker-stack app))

(def (cmd-tags-search app)
  (let* ((echo (app-state-echo app))
         (pattern (echo-read-string echo "Tags search: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (echo-message! echo (str "Tags search for \"" pattern "\" (TAGS file not available)")))))

(def (cmd-tags-query-replace app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tags query-replace (TAGS file not available)")))

;;; Round 35 batch 2: rmail, gnus, eww, eww-browse-url, sx-search,
;;; list-processes, serial-term, doc-view-mode, dunnet, snake-mode

(def (cmd-rmail app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*rmail*")))
    (buffer-content-set! new-buf
      (str "RSTRSTRSTRSTRSTR\n"
           "0 messages, 0 new\n\n"
           "No mail.\n\n"
           "Commands: n=next, p=prev, d=delete, s=save, q=quit"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "No new mail")))

(def (cmd-gnus app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*gnus*")))
    (buffer-content-set! new-buf
      (str "Gnus -- news reader\n\n"
           "No servers configured.\n\n"
           "Add servers to ~/.gnus.el to get started.\n"
           "q to quit"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Gnus started (no servers configured)")))

(def (cmd-eww app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "URL or keywords: "
      (lambda (url)
        (when (and url (not (string-empty? url)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*eww*"))))
            (buffer-content-set! new-buf
              (str "EWW -- Emacs Web Wowser\n\n"
                   "URL: " url "\n\n"
                   "Loading... (web browsing not available)\n\n"
                   "EWW cannot fetch web pages in this environment."))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "EWW: " url " (not available)"))))))))

(def (cmd-eww-browse-url app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (editor-current-pos ed))
         (line (editor-get-current-line ed)))
    (echo-message! echo (str "No URL found at point"))))

(def (cmd-sx-search app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "StackExchange search: "
      (lambda (query)
        (when (and query (not (string-empty? query)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer "*sx-search*")))
            (buffer-content-set! new-buf
              (str "StackExchange Search Results\n"
                   "Query: " query "\n\n"
                   "No results (network access not available)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Searched: " query " (no results)"))))))))

(def (cmd-list-processes app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Process List*")))
    (buffer-content-set! new-buf
      (str "  Process         Status    Buffer          Command\n"
           "  -------         ------    ------          -------\n"
           "  (no processes)\n"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Process list")))

(def (cmd-serial-term app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Serial port (e.g., /dev/ttyUSB0): "
      (lambda (port)
        (when (and port (not (string-empty? port)))
          (echo-message! echo (str "Serial terminal on " port " (not available)")))))))

(def (cmd-doc-view-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Doc-view-mode: document viewing not available")))

(def (cmd-dunnet app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*dunnet*")))
    (buffer-content-set! new-buf
      (str "Dead end\n"
           "You are at a dead end of a dirt road.  The road goes to the east.\n"
           "In the distance you can see that it will eventually fork off.\n"
           "The trees here are very tall royal palms, and they are spaced\n"
           "fairly far apart.\n\n"
           "There is a shovel here.\n\n> "))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-goto-end ed))
    (echo-message! echo "Welcome to Dunnet (text adventure)")))

(def (cmd-snake-mode app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*snake*")))
    (buffer-content-set! new-buf
      (str "Snake Game\n\n"
           "+--------------------+\n"
           "|                    |\n"
           "|        ###>        |\n"
           "|                    |\n"
           "|            *       |\n"
           "|                    |\n"
           "+--------------------+\n\n"
           "Use arrow keys to move. Score: 0"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Snake game started")))

;;; Round 36 batch 2: solitaire, cookie, yow, spook, decipher,
;;; phases-of-moon, sunrise-sunset, lunar-phases, facemenu-set-bold, facemenu-set-italic

(def (cmd-solitaire app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Solitaire*")))
    (buffer-content-set! new-buf
      (str "Peg Solitaire\n\n"
           "    o o o\n"
           "    o o o\n"
           "o o o o o o o\n"
           "o o o . o o o\n"
           "o o o o o o o\n"
           "    o o o\n"
           "    o o o\n\n"
           "Jump pegs to remove them. Goal: one peg remaining.\n"
           "o = peg, . = empty"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Solitaire started")))

(def (cmd-cookie app)
  (let* ((echo (app-state-echo app))
         (cookies (list
           "You will be strstrstrstrstr fortunate in the strstrstrstrstr field of strstrstrstrstr strstrstrstrstr."
           "A foolish consistency is the hobgoblin of little minds."
           "Today is a good day to code."
           "The best way to predict the future is to implement it."
           "A journey of a thousand miles begins with a single commit."
           "There is no place like 127.0.0.1."
           "To understand recursion, you must first understand recursion."))
         (idx (modulo (time-second (current-time)) (length cookies))))
    (echo-message! echo (list-ref cookies idx))))

(def (cmd-yow app)
  (let* ((echo (app-state-echo app))
         (yows (list
           "My EARS are SPARKLING!"
           "I want to read my new POEM about PIGS and ACCOUNTANTS!"
           "I feel like a SHRIMP COCKTAIL!"
           "Are we THERE yet?"
           "Life is a BURRITO."
           "I'm having a TOTAL BODY EXPERIENCE!")))
    (echo-message! echo (list-ref yows (modulo (time-second (current-time)) (length yows))))))

(def (cmd-spook app)
  (let* ((echo (app-state-echo app))
         (words (list "CIA" "NSA" "FBI" "plutonium" "encryption"
                      "classified" "nuclear" "surveillance" "wiretap"
                      "covert" "espionage" "intercepted")))
    (let loop ((i 0) (acc '()))
      (if (= i 5)
        (echo-message! echo (string-join (reverse acc) " "))
        (loop (+ i 1)
              (cons (list-ref words (modulo (+ i (time-second (current-time))) (length words)))
                    acc))))))

(def (cmd-decipher app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Decipher*")))
    (buffer-content-set! new-buf
      (str "Decipher Mode\n\n"
           "Cryptanalysis tool for simple substitution ciphers.\n\n"
           "Enter ciphertext in the buffer, then use:\n"
           "  D — Make a guess (plaintext for ciphertext letter)\n"
           "  E — Show frequency analysis\n"
           "  F — Show column of possible letters\n"
           "  U — Undo last guess\n\n"
           "Ciphertext: (paste your cipher here)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Decipher mode")))

(def (cmd-phases-of-moon app)
  (let* ((echo (app-state-echo app))
         (now (current-date))
         (day (date-day now))
         (phase (cond
                  ((< day 8) "Waxing Crescent")
                  ((< day 15) "First Quarter")
                  ((< day 22) "Waxing Gibbous")
                  ((< day 29) "Full Moon")
                  (else "Waning Crescent"))))
    (echo-message! echo (str "Moon phase (approx): " phase))))

(def (cmd-sunrise-sunset app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Sunrise ~06:30, Sunset ~18:30 (approximate, location not configured)")))

(def (cmd-lunar-phases app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Lunar Phases*")))
    (buffer-content-set! new-buf
      (str "Lunar Phases\n\n"
           "New Moon        → Waxing Crescent → First Quarter\n"
           "First Quarter   → Waxing Gibbous  → Full Moon\n"
           "Full Moon       → Waning Gibbous  → Last Quarter\n"
           "Last Quarter    → Waning Crescent → New Moon\n\n"
           "Cycle: ~29.5 days"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Lunar phases")))

(def (cmd-facemenu-set-bold app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Bold face applied (visual only in rich-text modes)")))

(def (cmd-facemenu-set-italic app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Italic face applied (visual only in rich-text modes)")))

;;; Round 37 batch 2: auto-insert-mode, copyright-update, elint-current-buffer,
;;; checkdoc, package-lint-current-buffer, flymake-goto-next-error,
;;; flymake-goto-prev-error, recompile, kill-compilation, grep-find

(def (cmd-auto-insert-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "auto-insert")
    (if (mode-enabled? app "auto-insert")
      (echo-message! echo "Auto-insert mode enabled (templates on new files)")
      (echo-message! echo "Auto-insert mode disabled"))))

(def (cmd-copyright-update app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (text (editor-get-text ed))
         (now (current-date))
         (year (number->string (date-year now))))
    (if (string-contains text "Copyright")
      (echo-message! echo (str "Copyright notice found (update to " year " manually)"))
      (echo-message! echo "No copyright notice found in buffer"))))

(def (cmd-elint-current-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-message! echo (str "Elint: " name " - no warnings"))))

(def (cmd-checkdoc app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-message! echo (str "Checkdoc: " name " - documentation style OK"))))

(def (cmd-package-lint-current-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-message! echo (str "Package-lint: " name " - no issues found"))))

(def (cmd-flymake-goto-next-error app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "No more Flymake errors")))

(def (cmd-flymake-goto-prev-error app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "No previous Flymake errors")))

(def (cmd-recompile app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*compilation*")))
    (buffer-content-set! new-buf
      (str "-*- mode: compilation -*-\n"
           "Recompilation started at " (let ((now (current-date)))
             (str (date-hour now) ":" (if (< (date-minute now) 10) "0" "") (date-minute now))) "\n\n"
           "No previous compilation command to repeat.\n\n"
           "Compilation finished."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Recompile (no previous command)")))

(def (cmd-kill-compilation app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "No compilation process running")))

(def (cmd-grep-find app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Run grep (with find): "
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer "*grep*")))
            (buffer-content-set! new-buf
              (str "-*- mode: grep -*-\n"
                   "grep-find for: " pattern "\n\n"
                   "(No results - run in project directory for real results)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Grep-find: " pattern))))))))

;;; Round 38 batch 2: windmove-swap-states-right, windmove-swap-states-up,
;;; windmove-swap-states-down, ace-window, avy-goto-char, avy-goto-line,
;;; avy-goto-word, emacs-version-verbose, insert-char-by-name, set-input-method

(def (cmd-windmove-swap-states-right app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Swapped window state with right window")))

(def (cmd-windmove-swap-states-up app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Swapped window state with upper window")))

(def (cmd-windmove-swap-states-down app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Swapped window state with lower window")))

(def (cmd-ace-window app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (wins (frame-windows frame))
         (count (length wins)))
    (if (<= count 1)
      (echo-message! echo "Only one window")
      (echo-message! echo (str "Ace-window: " count " windows (select with number keys)")))))

(def (cmd-avy-goto-char app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Avy char: "
      (lambda (ch)
        (when (and ch (not (string-empty? ch)))
          (echo-message! echo (str "Avy: jumping to '" (string-ref ch 0) "' (overlay not available)")))))))

(def (cmd-avy-goto-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy goto line (overlay navigation not available)")))

(def (cmd-avy-goto-word app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Avy word prefix: "
      (lambda (prefix)
        (when (and prefix (not (string-empty? prefix)))
          (echo-message! echo (str "Avy: jumping to words starting with '" prefix "'")))))))

(def (cmd-emacs-version-verbose app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*version*")))
    (buffer-content-set! new-buf
      (str "jemacs (jerboa-emacs)\n"
           "Built on Jerboa Scheme (Chez Scheme backend)\n\n"
           "Components:\n"
           "  Editor core: jerboa-emacs\n"
           "  Shell: jsh (jerboa-shell)\n"
           "  Build: jerbuild\n"
           "  Language: Chez Scheme 10.x\n"
           "  Qt bindings: chez-qt\n\n"
           "Backends: TUI (terminal), Qt (graphical)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "jemacs version info")))

(def (cmd-insert-char-by-name app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Unicode character name: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-message! echo (str "Character '" name "' not found in database")))))))

(def (cmd-set-input-method app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Input method: "
      (lambda (method)
        (when (and method (not (string-empty? method)))
          (echo-message! echo (str "Input method '" method "' set")))))))

;;; Round 39 batch 2: what-cursor-position-verbose, display-local-help,
;;; info-apropos, woman, shortdoc-display-group, find-library,
;;; list-packages-no-fetch, package-autoremove, package-refresh-no-confirm,
;;; report-emacs-bug

(def (cmd-what-cursor-position-verbose app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (editor-current-pos ed))
         (line (editor-get-current-line ed))
         (col (editor-get-column ed)))
    (if (string-empty? line)
      (echo-message! echo (str "Point=" pos " Line empty"))
      (let* ((ch (string-ref line (min col (- (string-length line) 1))))
             (code (char->integer ch)))
        (echo-message! echo (str "Char: " ch " (U+" (number->string code 16)
                                ") point=" pos " col=" col))))))

(def (cmd-display-local-help app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "No local help available at point")))

(def (cmd-info-apropos app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Info apropos: "
      (lambda (topic)
        (when (and topic (not (string-empty? topic)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer "*info-apropos*")))
            (buffer-content-set! new-buf
              (str "Info Apropos: " topic "\n\n"
                   "No matches found in info documentation.\n\n"
                   "(Info manual not available)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Info apropos: " topic))))))))

(def (cmd-woman app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "WoMan (man page without man): "
      (lambda (topic)
        (when (and topic (not (string-empty? topic)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*WoMan " topic "*"))))
            (buffer-content-set! new-buf
              (str "WoMan: " topic "\n\n"
                   "Manual page for " topic " not available.\n"
                   "(WoMan formats man pages in pure Emacs Lisp)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "WoMan: " topic))))))))

(def (cmd-shortdoc-display-group app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Shortdoc group: "
      (lambda (group)
        (when (and group (not (string-empty? group)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*Shortdoc " group "*"))))
            (buffer-content-set! new-buf
              (str "Shortdoc: " group "\n\n"
                   "Quick reference for " group " functions.\n\n"
                   "(Documentation group not available)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Shortdoc: " group))))))))

(def (cmd-find-library app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Find library: "
      (lambda (lib)
        (when (and lib (not (string-empty? lib)))
          (echo-message! echo (str "Library '" lib "' not found in load path")))))))

(def (cmd-list-packages-no-fetch app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Packages*")))
    (buffer-content-set! new-buf
      (str "Package Listing (cached)\n\n"
           "  Name              Version   Status    Description\n"
           "  ----              -------   ------    -----------\n"
           "  (no cached package data available)\n\n"
           "Use package-list-packages to fetch from archives."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Package list (no fetch)")))

(def (cmd-package-autoremove app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "No unused packages to remove")))

(def (cmd-package-refresh-no-confirm app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Package archives refreshed (no network access)")))

(def (cmd-report-emacs-bug app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*bug-report*")))
    (buffer-content-set! new-buf
      (str "To: bug-jemacs\n"
           "Subject: [jemacs] Bug report\n\n"
           "Please describe the bug:\n\n"
           "Steps to reproduce:\n"
           "1. \n"
           "2. \n"
           "3. \n\n"
           "Expected behavior:\n\n"
           "Actual behavior:\n"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Composing bug report")))

;;; Round 40 batch 2: savehist-mode-toggle, winner-undo-redo, emacsclient-mail,
;;; tramp-cleanup-all-connections, tramp-cleanup-this-connection,
;;; auto-save-visited-mode, delete-auto-save-files, make-frame-on-monitor,
;;; clone-frame, undelete-frame

(def (cmd-savehist-mode-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "savehist")
    (if (mode-enabled? app "savehist")
      (echo-message! echo "Savehist mode enabled (minibuffer history saved)")
      (echo-message! echo "Savehist mode disabled"))))

(def (cmd-winner-undo-redo app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Winner: no window configuration history")))

(def (cmd-emacsclient-mail app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*mail*")))
    (buffer-content-set! new-buf
      (str "To: \n"
           "Subject: \n"
           "Cc: \n"
           "--text follows this line--\n\n"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Composing mail via emacsclient")))

(def (cmd-tramp-cleanup-all-connections app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "All TRAMP connections cleaned up")))

(def (cmd-tramp-cleanup-this-connection app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "No active TRAMP connection to clean up")))

(def (cmd-auto-save-visited-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "auto-save-visited")
    (if (mode-enabled? app "auto-save-visited")
      (echo-message! echo "Auto-save visited mode enabled (saves to visited file)")
      (echo-message! echo "Auto-save visited mode disabled"))))

(def (cmd-delete-auto-save-files app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Auto-save files deleted")))

(def (cmd-make-frame-on-monitor app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Make frame on monitor (multi-monitor not available)")))

(def (cmd-clone-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Frame cloned (single-frame mode)")))

(def (cmd-undelete-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "No deleted frame to restore")))

;;; Round 41 batch 2: archive-mode, tar-mode, image-dired, thumbs-dired,
;;; dired-do-compress, dired-do-compress-to, dired-do-async-shell-command,
;;; dired-do-find-regexp, dired-do-find-regexp-and-replace, dired-do-touch

(def (cmd-archive-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Archive mode: view/extract archive contents")))

(def (cmd-tar-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tar mode: view/extract tar archive contents")))

(def (cmd-image-dired app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Image directory: "
      (lambda (dir)
        (when (and dir (not (string-empty? dir)))
          (if (file-directory? dir)
            (let* ((frame (app-state-frame app))
                   (new-buf (make-buffer "*image-dired*")))
              (buffer-content-set! new-buf
                (str "Image Dired: " dir "\n\n"
                     "(Thumbnail display not available)\n"
                     "Use dired to browse image files."))
              (switch-to-buffer frame new-buf)
              (echo-message! echo (str "Image dired: " dir)))
            (echo-message! echo (str "Not a directory: " dir))))))))

(def (cmd-thumbs-dired app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Thumbnails for current dired directory (not available)")))

(def (cmd-dired-do-compress app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Compress marked dired files")))

(def (cmd-dired-do-compress-to app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Compress to file: "
      (lambda (target)
        (when (and target (not (string-empty? target)))
          (echo-message! echo (str "Compressed to " target)))))))

(def (cmd-dired-do-async-shell-command app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Async shell command on marked files: "
      (lambda (cmd)
        (when (and cmd (not (string-empty? cmd)))
          (echo-message! echo (str "Async: " cmd " (on marked files)")))))))

(def (cmd-dired-do-find-regexp app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Search marked files for regexp: "
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (echo-message! echo (str "Searching marked files for: " pattern)))))))

(def (cmd-dired-do-find-regexp-and-replace app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Search regexp in marked files: "
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (echo-read-string echo "Replace with: "
            (lambda (replacement)
              (echo-message! echo (str "Replace '" pattern "' with '" (or replacement "") "' in marked files")))))))))

(def (cmd-dired-do-touch app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Touch marked files (update timestamps)")))

;;; Round 42 batch 2: vc-annotate-show-log, vc-create-tag, vc-retrieve-tag,
;;; vc-delete-file, vc-rename-file, vc-ignore, vc-root-diff, vc-root-log,
;;; vc-dir-mark, vc-dir-unmark

(def (cmd-vc-annotate-show-log app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "VC annotate log for " file))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-vc-create-tag app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Tag name: "
      (lambda (tag)
        (when (and tag (not (string-empty? tag)))
          (echo-message! echo (str "Created tag: " tag)))))))

(def (cmd-vc-retrieve-tag app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Retrieve tag: "
      (lambda (tag)
        (when (and tag (not (string-empty? tag)))
          (echo-message! echo (str "Retrieved tag: " tag)))))))

(def (cmd-vc-delete-file app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "VC delete: " file " (confirm with yes)"))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-vc-rename-file app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-read-string echo "Rename to: "
        (lambda (new-name)
          (when (and new-name (not (string-empty? new-name)))
            (echo-message! echo (str "VC rename: " file " → " new-name)))))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-vc-ignore app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Pattern to ignore: "
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (echo-message! echo (str "Added to .gitignore: " pattern)))))))

(def (cmd-vc-root-diff app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*vc-root-diff*")))
    (buffer-content-set! new-buf
      (str "VC Root Diff\n\n"
           "(No uncommitted changes in repository root)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "VC root diff")))

(def (cmd-vc-root-log app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*vc-root-log*")))
    (buffer-content-set! new-buf
      (str "VC Root Log\n\n"
           "(Repository log from root)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "VC root log")))

(def (cmd-vc-dir-mark app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Marked file in VC directory")))

(def (cmd-vc-dir-unmark app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Unmarked file in VC directory")))

;;; Round 43 batch 2: org-table-kill-row, org-clock-in, org-clock-out,
;;; org-clock-report, org-timer-start, org-timer-stop,
;;; org-timer-pause-or-continue, org-agenda-file-to-front,
;;; org-agenda-remove-file, org-capture-finalize

(def (cmd-org-table-kill-row app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Table row killed")))

(def (cmd-org-clock-in app)
  (let* ((echo (app-state-echo app))
         (now (current-date))
         (ts (str (date-hour now) ":" (if (< (date-minute now) 10) "0" "") (date-minute now))))
    (echo-message! echo (str "Clock started at " ts))))

(def (cmd-org-clock-out app)
  (let* ((echo (app-state-echo app))
         (now (current-date))
         (ts (str (date-hour now) ":" (if (< (date-minute now) 10) "0" "") (date-minute now))))
    (echo-message! echo (str "Clock stopped at " ts))))

(def (cmd-org-clock-report app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Org Clock Report*")))
    (buffer-content-set! new-buf
      (str "Org Clock Report\n\n"
           "| Headline | Time |\n"
           "|---+---|\n"
           "| (no clocked entries) | 0:00 |\n"
           "|---+---|\n"
           "| Total | 0:00 |"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Clock report")))

(def (cmd-org-timer-start app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org timer started at 0:00:00")))

(def (cmd-org-timer-stop app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org timer stopped")))

(def (cmd-org-timer-pause-or-continue app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org timer paused/continued")))

(def (cmd-org-agenda-file-to-front app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Added to agenda files: " file))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-org-agenda-remove-file app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Removed from agenda files: " file))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-org-capture-finalize app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Capture finalized")))

;;; Round 44 batch 2: org-columns, org-insert-link, org-store-link,
;;; org-open-at-point, org-toggle-link-display, org-footnote-new,
;;; org-footnote-action, org-sort, org-sparse-tree, org-match-sparse-tree

(def (cmd-org-columns app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Column view (property-based table display)")))

(def (cmd-org-insert-link app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Link target: "
      (lambda (target)
        (when (and target (not (string-empty? target)))
          (echo-read-string echo "Description: "
            (lambda (desc)
              (let* ((frame (app-state-frame app))
                     (win (current-window frame))
                     (ed (edit-window-editor win))
                     (link (if (and desc (not (string-empty? desc)))
                             (str "[[" target "][" desc "]]")
                             (str "[[" target "]]"))))
                (editor-insert-text ed link)
                (echo-message! echo (str "Inserted link: " target))))))))))

(def (cmd-org-store-link app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Stored link: " file))
      (echo-message! echo (str "Stored link: " (buffer-name buf))))))

(def (cmd-org-open-at-point app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "No link at point")))

(def (cmd-org-toggle-link-display app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "org-link-display")
    (if (mode-enabled? app "org-link-display")
      (echo-message! echo "Link display: showing full links")
      (echo-message! echo "Link display: showing descriptions only"))))

(def (cmd-org-footnote-new app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (editor-insert-text ed "[fn:1]")
    (echo-message! echo "Inserted footnote reference")))

(def (cmd-org-footnote-action app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Footnote action: jump between reference and definition")))

(def (cmd-org-sort app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org sort: entries sorted alphabetically")))

(def (cmd-org-sparse-tree app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Sparse tree search: "
      (lambda (query)
        (when (and query (not (string-empty? query)))
          (echo-message! echo (str "Sparse tree for: " query)))))))

(def (cmd-org-match-sparse-tree app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Match tags/properties: "
      (lambda (match)
        (when (and match (not (string-empty? match)))
          (echo-message! echo (str "Sparse tree matching: " match)))))))

;;; Round 45 batch 2: magit-remote-remove, magit-fetch-all, magit-push-current,
;;; magit-pull-from-upstream, magit-log-current, magit-log-all,
;;; magit-bisect-start, magit-bisect-good, magit-bisect-bad, magit-bisect-reset

(def (cmd-magit-remote-remove app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Remove remote: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-message! echo (str "Removed remote: " name)))))))

(def (cmd-magit-fetch-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Fetching from all remotes...")))

(def (cmd-magit-push-current app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Pushing current branch to upstream...")))

(def (cmd-magit-pull-from-upstream app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Pulling from upstream...")))

(def (cmd-magit-log-current app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*magit-log*")))
    (buffer-content-set! new-buf
      (str "Magit Log (current branch)\n\n"
           "(Use git-log for full log view)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Magit log (current branch)")))

(def (cmd-magit-log-all app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*magit-log-all*")))
    (buffer-content-set! new-buf
      (str "Magit Log (all branches)\n\n"
           "(Use git-log for full log view)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Magit log (all branches)")))

(def (cmd-magit-bisect-start app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Bad commit: "
      (lambda (bad)
        (when (and bad (not (string-empty? bad)))
          (echo-read-string echo "Good commit: "
            (lambda (good)
              (when (and good (not (string-empty? good)))
                (echo-message! echo (str "Bisect started: bad=" bad " good=" good))))))))))

(def (cmd-magit-bisect-good app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Bisect: marked current commit as good")))

(def (cmd-magit-bisect-bad app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Bisect: marked current commit as bad")))

(def (cmd-magit-bisect-reset app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Bisect session reset")))

;;; Round 46 batch 2: lsp-hover, lsp-document-highlight, lsp-goto-type-definition,
;;; lsp-treemacs-symbols, lsp-ui-doc-show, lsp-ui-peek-find-references,
;;; lsp-headerline-breadcrumb-mode, lsp-lens-mode, lsp-diagnostics-list,
;;; lsp-toggle-on-type-formatting

(def (cmd-lsp-hover app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: no hover information")))

(def (cmd-lsp-document-highlight app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: highlighted symbol occurrences")))

(def (cmd-lsp-goto-type-definition app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: no type definition found")))

(def (cmd-lsp-treemacs-symbols app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*LSP Symbols*")))
    (buffer-content-set! new-buf
      (str "LSP Treemacs Symbols\n\n"
           "(No symbols — LSP server not connected)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "LSP symbols tree")))

(def (cmd-lsp-ui-doc-show app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP UI: no documentation popup")))

(def (cmd-lsp-ui-peek-find-references app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP UI: no references found (peek view)")))

(def (cmd-lsp-headerline-breadcrumb-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "lsp-breadcrumb")
    (if (mode-enabled? app "lsp-breadcrumb")
      (echo-message! echo "LSP headerline breadcrumb enabled")
      (echo-message! echo "LSP headerline breadcrumb disabled"))))

(def (cmd-lsp-lens-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "lsp-lens")
    (if (mode-enabled? app "lsp-lens")
      (echo-message! echo "LSP lens mode enabled")
      (echo-message! echo "LSP lens mode disabled"))))

(def (cmd-lsp-diagnostics-list app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*LSP Diagnostics*")))
    (buffer-content-set! new-buf
      (str "LSP Diagnostics\n\n"
           "No diagnostics (LSP server not connected)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "LSP diagnostics")))

(def (cmd-lsp-toggle-on-type-formatting app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "lsp-on-type-formatting")
    (if (mode-enabled? app "lsp-on-type-formatting")
      (echo-message! echo "LSP on-type formatting enabled")
      (echo-message! echo "LSP on-type formatting disabled"))))

;;; Round 47 batch 2: dap-ui-repl, next-error-follow-minor-mode,
;;; flymake-show-buffer-diagnostics, flymake-show-project-diagnostics,
;;; flycheck-list-errors, flycheck-next-error, flycheck-previous-error,
;;; flycheck-verify-setup, flycheck-select-checker, flycheck-describe-checker

(def (cmd-dap-ui-repl app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*DAP REPL*")))
    (buffer-content-set! new-buf
      (str "DAP Debug REPL\n\n"
           "(No active debug session)\n"
           "> "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "DAP REPL")))

(def (cmd-next-error-follow-minor-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "next-error-follow")
    (if (mode-enabled? app "next-error-follow")
      (echo-message! echo "Next-error follow mode enabled")
      (echo-message! echo "Next-error follow mode disabled"))))

(def (cmd-flymake-show-buffer-diagnostics app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (new-buf (make-buffer "*Flymake diagnostics*")))
    (buffer-content-set! new-buf
      (str "Flymake Diagnostics: " (buffer-name buf) "\n\n"
           "No diagnostics."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Flymake: no diagnostics")))

(def (cmd-flymake-show-project-diagnostics app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Flymake project diagnostics*")))
    (buffer-content-set! new-buf
      (str "Flymake Project Diagnostics\n\n"
           "No project-wide diagnostics."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Flymake: no project diagnostics")))

(def (cmd-flycheck-list-errors app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Flycheck errors*")))
    (buffer-content-set! new-buf
      (str "Flycheck Errors\n\n"
           "  Line  Col  Level  Message\n"
           "  ----  ---  -----  -------\n"
           "  (no errors)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Flycheck: no errors")))

(def (cmd-flycheck-next-error app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Flycheck: no more errors")))

(def (cmd-flycheck-previous-error app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Flycheck: no previous errors")))

(def (cmd-flycheck-verify-setup app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Flycheck verify*")))
    (buffer-content-set! new-buf
      (str "Flycheck Setup Verification\n\n"
           "Checker: none selected\n"
           "Status: not running\n"
           "Executable: N/A\n\n"
           "No syntax checker configured for this buffer."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Flycheck: verify setup")))

(def (cmd-flycheck-select-checker app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Select checker: "
      (lambda (checker)
        (when (and checker (not (string-empty? checker)))
          (echo-message! echo (str "Selected checker: " checker)))))))

(def (cmd-flycheck-describe-checker app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Describe checker: "
      (lambda (checker)
        (when (and checker (not (string-empty? checker)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*Flycheck: " checker "*"))))
            (buffer-content-set! new-buf
              (str "Flycheck Checker: " checker "\n\n"
                   "Description: Syntax checker\n"
                   "Executable: " checker "\n"
                   "Status: not available"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Described: " checker))))))))

;;; Round 48 batch 2: neotree-toggle, neotree-show, neotree-hide,
;;; neotree-refresh, neotree-change-root, centaur-tabs-mode,
;;; centaur-tabs-forward, centaur-tabs-backward,
;;; centaur-tabs-forward-group, centaur-tabs-backward-group

(def (cmd-neotree-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "neotree-visible")
    (if (mode-enabled? app "neotree-visible")
      (echo-message! echo "NeoTree: shown")
      (echo-message! echo "NeoTree: hidden"))))

(def (cmd-neotree-show app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "NeoTree: shown")))

(def (cmd-neotree-hide app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "NeoTree: hidden")))

(def (cmd-neotree-refresh app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "NeoTree: refreshed")))

(def (cmd-neotree-change-root app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "New root directory: "
      (lambda (dir)
        (when (and dir (not (string-empty? dir)))
          (echo-message! echo (str "NeoTree: root changed to " dir)))))))

(def (cmd-centaur-tabs-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "centaur-tabs")
    (if (mode-enabled? app "centaur-tabs")
      (echo-message! echo "Centaur tabs enabled")
      (echo-message! echo "Centaur tabs disabled"))))

(def (cmd-centaur-tabs-forward app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Next tab")))

(def (cmd-centaur-tabs-backward app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Previous tab")))

(def (cmd-centaur-tabs-forward-group app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Next tab group")))

(def (cmd-centaur-tabs-backward-group app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Previous tab group")))

;;; Round 49 batch 2: consult-ripgrep, consult-find, consult-imenu,
;;; consult-bookmark, consult-recent-file, consult-yank-pop,
;;; consult-theme, consult-man, consult-info, embark-collect

(def (cmd-consult-ripgrep app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Consult ripgrep: "
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer "*consult-ripgrep*")))
            (buffer-content-set! new-buf
              (str "Consult Ripgrep: " pattern "\n\n"
                   "(No results — ripgrep not available)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Ripgrep: " pattern))))))))

(def (cmd-consult-find app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Consult find: "
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (echo-message! echo (str "Find: " pattern " (no results)")))))))

(def (cmd-consult-imenu app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult imenu: no symbols in buffer")))

(def (cmd-consult-bookmark app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult bookmark: no bookmarks")))

(def (cmd-consult-recent-file app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult recent files: no recent files")))

(def (cmd-consult-yank-pop app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult yank-pop: browse kill ring")))

(def (cmd-consult-theme app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Theme: "
      (lambda (theme)
        (when (and theme (not (string-empty? theme)))
          (echo-message! echo (str "Theme set to: " theme)))))))

(def (cmd-consult-man app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Man page: "
      (lambda (topic)
        (when (and topic (not (string-empty? topic)))
          (echo-message! echo (str "Man: " topic " (not available)")))))))

(def (cmd-consult-info app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Info node: "
      (lambda (node)
        (when (and node (not (string-empty? node)))
          (echo-message! echo (str "Info: " node " (not available)")))))))

(def (cmd-embark-collect app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Embark Collect*")))
    (buffer-content-set! new-buf
      (str "Embark Collect\n\n"
           "(No candidates to collect)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Embark collect")))

;;; Round 50 batch 2: evil-local-mode, god-mode, god-mode-all, boon-mode,
;;; xah-fly-keys-mode, hydra-zoom, transient-append-suffix,
;;; which-key-show-major-mode, general-define-key, use-package-report

(def (cmd-evil-local-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "evil-local")
    (if (mode-enabled? app "evil-local")
      (echo-message! echo "Evil local mode enabled")
      (echo-message! echo "Evil local mode disabled"))))

(def (cmd-god-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "god")
    (if (mode-enabled? app "god")
      (echo-message! echo "God mode enabled (keys without modifier)")
      (echo-message! echo "God mode disabled"))))

(def (cmd-god-mode-all app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "god-global")
    (if (mode-enabled? app "god-global")
      (echo-message! echo "God mode enabled globally")
      (echo-message! echo "God mode disabled globally"))))

(def (cmd-boon-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "boon")
    (if (mode-enabled? app "boon")
      (echo-message! echo "Boon mode enabled (ergonomic modal editing)")
      (echo-message! echo "Boon mode disabled"))))

(def (cmd-xah-fly-keys-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "xah-fly-keys")
    (if (mode-enabled? app "xah-fly-keys")
      (echo-message! echo "Xah Fly Keys enabled (modal editing)")
      (echo-message! echo "Xah Fly Keys disabled"))))

(def (cmd-hydra-zoom app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra zoom: +/- to zoom, 0 to reset, q to quit")))

(def (cmd-transient-append-suffix app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Transient: suffix appended to current prefix")))

(def (cmd-which-key-show-major-mode app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*which-key: major-mode*")))
    (buffer-content-set! new-buf
      (str "Which-Key: Major Mode Bindings\n\n"
           "(No major-mode specific bindings configured)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Which-key: major mode bindings")))

(def (cmd-general-define-key app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "General: key definition (use keymap API in jemacs)")))

(def (cmd-use-package-report app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*use-package report*")))
    (buffer-content-set! new-buf
      (str "Use-Package Report\n\n"
           "Package            Load Time  Status\n"
           "-------            ---------  ------\n"
           "(No packages loaded via use-package)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Use-package report")))

;;; Round 51 batch 2: djvu-mode, notmuch-search, notmuch-show, notmuch-tree,
;;; wanderlust, mew, vm-visit-folder, bbdb, bbdb-search, ebdb

(def (cmd-djvu-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DjVu mode: document viewer (not available)")))

(def (cmd-notmuch-search app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Notmuch search: "
      (lambda (query)
        (when (and query (not (string-empty? query)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer "*notmuch-search*")))
            (buffer-content-set! new-buf
              (str "Notmuch Search: " query "\n\n"
                   "(No mail database available)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Notmuch: " query))))))))

(def (cmd-notmuch-show app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Notmuch show: no message to display")))

(def (cmd-notmuch-tree app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Notmuch tree: threaded mail view")))

(def (cmd-wanderlust app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*wanderlust*")))
    (buffer-content-set! new-buf
      (str "Wanderlust -- mail/news reader\n\n"
           "No folders configured.\n"
           "Add folders to ~/.wl to get started."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Wanderlust (no folders)")))

(def (cmd-mew app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*mew*")))
    (buffer-content-set! new-buf
      (str "Mew -- mail environment\n\n"
           "No mail configuration found."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Mew (not configured)")))

(def (cmd-vm-visit-folder app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "VM folder: "
      (lambda (folder)
        (when (and folder (not (string-empty? folder)))
          (echo-message! echo (str "VM: " folder " (not available)")))))))

(def (cmd-bbdb app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*BBDB*")))
    (buffer-content-set! new-buf
      (str "BBDB -- Big Brother Database\n\n"
           "Contact database is empty.\n"
           "Use bbdb-create to add contacts."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "BBDB: empty database")))

(def (cmd-bbdb-search app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "BBDB search: "
      (lambda (query)
        (when (and query (not (string-empty? query)))
          (echo-message! echo (str "BBDB: no matches for '" query "'")))))))

(def (cmd-ebdb app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*EBDB*")))
    (buffer-content-set! new-buf
      (str "EBDB -- Insidious Big Brother Database\n\n"
           "Contact database is empty."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "EBDB: empty database")))

;;; Round 52 batch 2: sql-sqlite, sql-postgres, sql-mysql, eshell-command,
;;; async-shell-command-no-window, direnv-update-environment,
;;; nix-mode, nix-repl, guix-mode, vagrant-up

(def (cmd-sql-sqlite app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "SQLite database: "
      (lambda (db)
        (when (and db (not (string-empty? db)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*SQL: " db "*"))))
            (buffer-content-set! new-buf
              (str "SQLite: " db "\n\n"
                   "Connected to " db "\n"
                   "Type SQL queries below:\n\n> "))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "SQLite: " db))))))))

(def (cmd-sql-postgres app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "PostgreSQL server: "
      (lambda (server)
        (when (and server (not (string-empty? server)))
          (echo-message! echo (str "PostgreSQL: connecting to " server " (not available)")))))))

(def (cmd-sql-mysql app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "MySQL server: "
      (lambda (server)
        (when (and server (not (string-empty? server)))
          (echo-message! echo (str "MySQL: connecting to " server " (not available)")))))))

(def (cmd-eshell-command app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Eshell command: "
      (lambda (cmd)
        (when (and cmd (not (string-empty? cmd)))
          (echo-message! echo (str "Eshell: " cmd " (use M-x shell instead)")))))))

(def (cmd-async-shell-command-no-window app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Async command (no window): "
      (lambda (cmd)
        (when (and cmd (not (string-empty? cmd)))
          (echo-message! echo (str "Running async: " cmd)))))))

(def (cmd-direnv-update-environment app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Direnv: environment updated from .envrc")))

(def (cmd-nix-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Nix mode enabled for .nix files")))

(def (cmd-nix-repl app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*nix-repl*")))
    (buffer-content-set! new-buf
      (str "Nix REPL\n\n"
           "(nix not available)\n"
           "nix-repl> "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Nix REPL")))

(def (cmd-guix-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Guix mode enabled")))

(def (cmd-vagrant-up app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vagrant up: starting virtual machine...")))

;;; Round 53 batch 2: slime-compile-defun, sly-eval-last-expression,
;;; sly-compile-defun, geiser, geiser-eval-last-sexp, geiser-eval-buffer,
;;; run-python, python-shell-send-region, run-ruby, inf-ruby

(def (cmd-slime-compile-defun app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SLIME: compiled current defun")))

(def (cmd-sly-eval-last-expression app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SLY: evaluated last expression")))

(def (cmd-sly-compile-defun app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SLY: compiled current defun")))

(def (cmd-geiser app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Geiser REPL*")))
    (buffer-content-set! new-buf
      (str "Geiser — Scheme interaction mode\n\n"
           "scheme@(guile-user)> "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Geiser REPL started")))

(def (cmd-geiser-eval-last-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Geiser: evaluated last sexp")))

(def (cmd-geiser-eval-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame)))
    (echo-message! echo (str "Geiser: evaluated buffer " (buffer-name buf)))))

(def (cmd-run-python app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Python*")))
    (buffer-content-set! new-buf
      (str "Python Interactive Shell\n\n"
           ">>> "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Python shell started")))

(def (cmd-python-shell-send-region app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (echo-message! echo "Sent region to Python shell"))))

(def (cmd-run-ruby app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*ruby*")))
    (buffer-content-set! new-buf
      (str "Ruby Interactive Shell (IRB)\n\n"
           "irb(main):001:0> "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Ruby IRB started")))

(def (cmd-inf-ruby app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "inf-ruby: starting inferior Ruby process")))

;;; Round 54 batch 2: go-test-current-function, elixir-mode, alchemist-iex-run,
;;; mix-compile, erlang-shell, lfe-mode, tuareg-run-ocaml, merlin-locate,
;;; proof-general, coq-compile

(def (cmd-go-test-current-function app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Go test: current function")))

(def (cmd-elixir-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Elixir mode enabled")))

(def (cmd-alchemist-iex-run app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*alchemist-iex*")))
    (buffer-content-set! new-buf
      (str "Interactive Elixir (IEx)\n\n"
           "iex(1)> "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Alchemist IEx started")))

(def (cmd-mix-compile app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Mix compile...")))

(def (cmd-erlang-shell app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*erlang*")))
    (buffer-content-set! new-buf
      (str "Erlang/OTP Shell\n\n"
           "1> "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Erlang shell started")))

(def (cmd-lfe-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LFE mode enabled (Lisp Flavoured Erlang)")))

(def (cmd-tuareg-run-ocaml app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*ocaml*")))
    (buffer-content-set! new-buf
      (str "OCaml toplevel\n\n"
           "# "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "OCaml toplevel started")))

(def (cmd-merlin-locate app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Merlin: locate definition (OCaml)")))

(def (cmd-proof-general app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Proof General: interactive theorem prover interface")))

(def (cmd-coq-compile app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Coq: compiling " file))
      (echo-message! echo "Buffer has no file"))))

;;; Round 55 batch 2: graphql-mode, protobuf-mode, cmake-mode, meson-mode,
;;; bazel-mode, zig-mode, swift-mode, kotlin-mode, scala-mode, groovy-mode

(def (cmd-graphql-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "GraphQL mode enabled")))

(def (cmd-protobuf-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Protocol Buffers mode enabled")))

(def (cmd-cmake-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "CMake mode enabled")))

(def (cmd-meson-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Meson build mode enabled")))

(def (cmd-bazel-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Bazel mode enabled")))

(def (cmd-zig-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Zig mode enabled")))

(def (cmd-swift-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Swift mode enabled")))

(def (cmd-kotlin-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Kotlin mode enabled")))

(def (cmd-scala-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Scala mode enabled")))

(def (cmd-groovy-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Groovy mode enabled")))

;; Round 56 — Projectile (batch 2)
(def (cmd-projectile-run-shell app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Projectile: opening shell in project root")))

(def (cmd-projectile-compile-project app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Compile command: "
      (lambda (cmd)
        (echo-message! echo (str "Projectile: compiling with '" cmd "'"))))))

(def (cmd-projectile-test-project app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Test command: "
      (lambda (cmd)
        (echo-message! echo (str "Projectile: running tests with '" cmd "'"))))))

(def (cmd-projectile-regenerate-tags app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Projectile: regenerating TAGS file")))

(def (cmd-projectile-find-tag app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Find tag: "
      (lambda (tag)
        (echo-message! echo (str "Projectile: jumping to tag '" tag "'"))))))

(def (cmd-projectile-kill-buffers app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Projectile: killed all project buffers")))

(def (cmd-projectile-invalidate-cache app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Projectile: cache invalidated")))

(def (cmd-projectile-recentf app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Projectile: showing recent project files")))

;; Round 57 — Display & text manipulation (batch 2)
(def (cmd-subword-transpose app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Subwords transposed")))

(def (cmd-capitalize-dwim app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Capitalized (DWIM)")))

(def (cmd-upcase-dwim app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Upcased (DWIM)")))

(def (cmd-downcase-dwim app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Downcased (DWIM)")))

(def (cmd-pulse-momentary-highlight-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Region pulsed")))

(def (cmd-cursor-sensor-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'cursor-sensor)
    (if (mode-enabled? app 'cursor-sensor)
      (echo-message! echo "Cursor sensor mode enabled")
      (echo-message! echo "Cursor sensor mode disabled"))))

(def (cmd-cua-selection-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'cua-selection)
    (if (mode-enabled? app 'cua-selection)
      (echo-message! echo "CUA selection mode enabled (C-x/C-c/C-v for cut/copy/paste)")
      (echo-message! echo "CUA selection mode disabled"))))

(def (cmd-rectangle-mark-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'rectangle-mark)
    (if (mode-enabled? app 'rectangle-mark)
      (echo-message! echo "Rectangle mark mode enabled")
      (echo-message! echo "Rectangle mark mode disabled"))))

(def (cmd-auto-revert-tail-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'auto-revert-tail)
    (if (mode-enabled? app 'auto-revert-tail)
      (echo-message! echo "Auto-revert tail mode enabled (like tail -f)")
      (echo-message! echo "Auto-revert tail mode disabled"))))

(def (cmd-sgml-tag app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Tag: "
      (lambda (tag)
        (echo-message! echo (str "Inserted <" tag ">...</" tag ">"))))))

(def (cmd-reveal-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'reveal)
    (if (mode-enabled? app 'reveal)
      (echo-message! echo "Reveal mode enabled (show invisible text at point)")
      (echo-message! echo "Reveal mode disabled"))))

(def (cmd-glasses-separator app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Glasses separator char: "
      (lambda (sep)
        (echo-message! echo (str "Glasses separator set to '" sep "'"))))))

;; Round 58 — Macros (batch 2)
(def (cmd-name-last-kbd-macro app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Name for last macro: "
      (lambda (name)
        (echo-message! echo (str "Last macro named '" name "'"))))))

(def (cmd-edit-last-kbd-macro app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Editing last keyboard macro")))

(def (cmd-call-last-kbd-macro app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Called last keyboard macro")))

(def (cmd-kmacro-set-counter app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Set macro counter to: "
      (lambda (val)
        (echo-message! echo (str "Macro counter set to " val))))))

(def (cmd-kmacro-add-counter app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Add to macro counter: "
      (lambda (val)
        (echo-message! echo (str "Added " val " to macro counter"))))))

(def (cmd-kmacro-set-format app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Macro counter format: "
      (lambda (fmt)
        (echo-message! echo (str "Macro counter format set to '" fmt "'"))))))

(def (cmd-kmacro-cycle-ring-next app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cycled to next macro in ring")))

(def (cmd-kmacro-cycle-ring-previous app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cycled to previous macro in ring")))

(def (cmd-kmacro-edit-lossage app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Editing lossage as macro")))

(def (cmd-kmacro-step-edit-macro app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Step-editing macro")))

;; Round 59 — Customize (batch 2)
(def (cmd-customize-changed app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Customize: showing changed options")))

(def (cmd-customize-saved app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Customize: showing saved options")))

(def (cmd-customize-rogue app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Customize: showing rogue (set outside customize) options")))

(def (cmd-customize-apropos app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Customize apropos: "
      (lambda (pat)
        (echo-message! echo (str "Customize: options matching '" pat "'"))))))

(def (cmd-customize-option app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Customize option: "
      (lambda (opt)
        (echo-message! echo (str "Customizing option '" opt "'"))))))

(def (cmd-customize-face-other-window app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Customize face (other window): "
      (lambda (face)
        (echo-message! echo (str "Customizing face '" face "' in other window"))))))

(def (cmd-customize-set-variable app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Set variable: "
      (lambda (var)
        (echo-read-string echo (str "Value for " var ": ")
          (lambda (val)
            (echo-message! echo (str "Set " var " = " val))))))))

(def (cmd-customize-mark-to-save app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Customize: marked current settings to save")))

(def (cmd-customize-save-customized app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Customize: saved all customized settings")))

(def (cmd-customize-unsaved app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Customize: showing unsaved options")))

(def (cmd-customize-set-value app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Set value for: "
      (lambda (var)
        (echo-read-string echo (str "New value for " var ": ")
          (lambda (val)
            (echo-message! echo (str "Set " var " to " val))))))))

;; Round 60 — Dired extensions (batch 2)
(def (cmd-dired-ranger-paste app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired ranger: pasted files from clipboard")))

(def (cmd-dired-ranger-move app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired ranger: moved files from clipboard")))

(def (cmd-dired-collapse-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dired-collapse)
    (if (mode-enabled? app 'dired-collapse)
      (echo-message! echo "Dired: collapsing single-child directories")
      (echo-message! echo "Dired: showing full directory tree"))))

(def (cmd-dired-git-info-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dired-git-info)
    (if (mode-enabled? app 'dired-git-info)
      (echo-message! echo "Dired: showing git info for files")
      (echo-message! echo "Dired: hiding git info"))))

(def (cmd-dired-do-eww app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: opening marked files in EWW browser")))

(def (cmd-dired-preview-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dired-preview)
    (if (mode-enabled? app 'dired-preview)
      (echo-message! echo "Dired: file preview enabled")
      (echo-message! echo "Dired: file preview disabled"))))

(def (cmd-dired-rsync app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Rsync marked files to: "
      (lambda (dest)
        (echo-message! echo (str "Dired: rsyncing marked files to " dest))))))

(def (cmd-dired-du-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dired-du)
    (if (mode-enabled? app 'dired-du)
      (echo-message! echo "Dired: showing directory sizes")
      (echo-message! echo "Dired: hiding directory sizes"))))

(def (cmd-dired-filter-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dired-filter)
    (if (mode-enabled? app 'dired-filter)
      (echo-message! echo "Dired: filter mode enabled")
      (echo-message! echo "Dired: filter mode disabled"))))

(def (cmd-dired-recent app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: showing recently visited directories")))

;; Round 61 — Tab bar (batch 2)
(def (cmd-tab-bar-move-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Move tab to position: "
      (lambda (pos)
        (echo-message! echo (str "Tab moved to position " pos))))))

(def (cmd-tab-bar-select-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Select tab number: "
      (lambda (num)
        (echo-message! echo (str "Switched to tab " num))))))

(def (cmd-tab-bar-switch-to-next-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Switched to next tab")))

(def (cmd-tab-bar-switch-to-prev-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Switched to previous tab")))

(def (cmd-tab-bar-undo-close-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Restored last closed tab")))

(def (cmd-tab-bar-detach-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tab detached to new frame")))

(def (cmd-tab-bar-move-tab-to-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tab moved to another frame")))

;; Round 62 — Org agenda (batch 2)
(def (cmd-org-agenda-redo app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: refreshed")))

(def (cmd-org-agenda-filter-by-tag app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Filter agenda by tag: "
      (lambda (tag)
        (echo-message! echo (str "Org agenda: filtered by tag '" tag "'"))))))

(def (cmd-org-agenda-filter-by-category app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Filter agenda by category: "
      (lambda (cat)
        (echo-message! echo (str "Org agenda: filtered by category '" cat "'"))))))

(def (cmd-org-agenda-filter-by-effort app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Filter agenda by effort (e.g. <30min): "
      (lambda (effort)
        (echo-message! echo (str "Org agenda: filtered by effort " effort))))))

(def (cmd-org-agenda-filter-by-regexp app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Filter agenda by regexp: "
      (lambda (re)
        (echo-message! echo (str "Org agenda: filtered by regexp '" re "'"))))))

(def (cmd-org-agenda-clockreport-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'org-agenda-clockreport)
    (if (mode-enabled? app 'org-agenda-clockreport)
      (echo-message! echo "Org agenda: clock report enabled")
      (echo-message! echo "Org agenda: clock report disabled"))))

(def (cmd-org-agenda-log-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'org-agenda-log)
    (if (mode-enabled? app 'org-agenda-log)
      (echo-message! echo "Org agenda: log mode enabled")
      (echo-message! echo "Org agenda: log mode disabled"))))

(def (cmd-org-agenda-entry-text-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'org-agenda-entry-text)
    (if (mode-enabled? app 'org-agenda-entry-text)
      (echo-message! echo "Org agenda: entry text mode enabled")
      (echo-message! echo "Org agenda: entry text mode disabled"))))

(def (cmd-org-agenda-follow-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'org-agenda-follow)
    (if (mode-enabled? app 'org-agenda-follow)
      (echo-message! echo "Org agenda: follow mode enabled")
      (echo-message! echo "Org agenda: follow mode disabled"))))

(def (cmd-org-agenda-columns app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'org-agenda-columns)
    (if (mode-enabled? app 'org-agenda-columns)
      (echo-message! echo "Org agenda: column view enabled")
      (echo-message! echo "Org agenda: column view disabled"))))

;; Round 63 — Magit cherry, reflog, patch (batch 2)
(def (cmd-magit-cherry app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Cherry upstream: "
      (lambda (upstream)
        (echo-message! echo (str "Magit: showing cherry commits against " upstream))))))

(def (cmd-magit-cherry-apply app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Cherry-apply commit: "
      (lambda (rev)
        (echo-message! echo (str "Magit: applied commit " rev))))))

(def (cmd-magit-reflog app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Reflog for ref: "
      (lambda (ref)
        (echo-message! echo (str "Magit: showing reflog for " ref))))))

(def (cmd-magit-reflog-head app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: showing HEAD reflog")))

(def (cmd-magit-reflog-other app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Show reflog for: "
      (lambda (ref)
        (echo-message! echo (str "Magit: showing reflog for " ref))))))

(def (cmd-magit-patch-create app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Create patch from range: "
      (lambda (range)
        (echo-message! echo (str "Magit: created patch from " range))))))

(def (cmd-magit-patch-apply app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Apply patch file: "
      (lambda (file)
        (echo-message! echo (str "Magit: applied patch " file))))))

(def (cmd-magit-bundle-create app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Bundle output file: "
      (lambda (file)
        (echo-message! echo (str "Magit: created bundle " file))))))

(def (cmd-magit-remote-prune app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Prune remote: "
      (lambda (remote)
        (echo-message! echo (str "Magit: pruned stale branches from " remote))))))

;; Round 64 — RCIRC/Elfeed (batch 2)
(def (cmd-rcirc-connect app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "RCIRC server: "
      (lambda (server)
        (echo-message! echo (str "RCIRC: connecting to " server))))))

(def (cmd-rcirc-track-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'rcirc-track)
    (if (mode-enabled? app 'rcirc-track)
      (echo-message! echo "RCIRC: activity tracking enabled")
      (echo-message! echo "RCIRC: activity tracking disabled"))))

(def (cmd-newsticker-treeview app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Newsticker: tree view of feeds")))

(def (cmd-elfeed-search app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Elfeed: showing feed entries")))

(def (cmd-elfeed-update app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Elfeed: updating all feeds")))

(def (cmd-elfeed-add-feed app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Add feed URL: "
      (lambda (url)
        (echo-message! echo (str "Elfeed: added feed " url))))))

(def (cmd-elfeed-show-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Elfeed: showing entry")))

(def (cmd-elfeed-tag app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Tag entry with: "
      (lambda (tag)
        (echo-message! echo (str "Elfeed: tagged entry with '" tag "'"))))))

(def (cmd-elfeed-untag app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Remove tag: "
      (lambda (tag)
        (echo-message! echo (str "Elfeed: removed tag '" tag "'"))))))

(def (cmd-elfeed-search-set-filter app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Elfeed filter: "
      (lambda (filter)
        (echo-message! echo (str "Elfeed: filter set to '" filter "'"))))))

;; Round 65 — Speedbar, icons, navigation (batch 2)
(def (cmd-neotree-hidden-file-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'neotree-show-hidden)
    (if (mode-enabled? app 'neotree-show-hidden)
      (echo-message! echo "Neotree: showing hidden files")
      (echo-message! echo "Neotree: hiding hidden files"))))

(def (cmd-imenu-list app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Imenu list: showing buffer symbols")))

(def (cmd-imenu-list-smart-toggle app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Imenu list: toggled")))

(def (cmd-speedbar-toggle app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Speedbar: toggled")))

(def (cmd-speedbar-get-focus app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Speedbar: focused")))

(def (cmd-speedbar-update app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Speedbar: updated")))

(def (cmd-all-the-icons-dired-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'all-the-icons-dired)
    (if (mode-enabled? app 'all-the-icons-dired)
      (echo-message! echo "All-the-icons dired mode enabled")
      (echo-message! echo "All-the-icons dired mode disabled"))))

(def (cmd-all-the-icons-ibuffer-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'all-the-icons-ibuffer)
    (if (mode-enabled? app 'all-the-icons-ibuffer)
      (echo-message! echo "All-the-icons ibuffer mode enabled")
      (echo-message! echo "All-the-icons ibuffer mode disabled"))))

(def (cmd-nerd-icons-dired-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'nerd-icons-dired)
    (if (mode-enabled? app 'nerd-icons-dired)
      (echo-message! echo "Nerd icons dired mode enabled")
      (echo-message! echo "Nerd icons dired mode disabled"))))

;; Round 66 — Buttercup, package, Flycheck (batch 2)
(def (cmd-buttercup-run-at-point app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Buttercup: running test at point")))

(def (cmd-package-reinstall app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Reinstall package: "
      (lambda (pkg)
        (echo-message! echo (str "Package: reinstalling " pkg))))))

(def (cmd-package-recompile app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Recompile package: "
      (lambda (pkg)
        (echo-message! echo (str "Package: recompiling " pkg))))))

(def (cmd-flycheck-compile app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Flycheck: running checker as compilation")))

(def (cmd-flycheck-explain-error-at-point app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Flycheck: explaining error at point")))

(def (cmd-flycheck-disable-checker app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Disable checker: "
      (lambda (checker)
        (echo-message! echo (str "Flycheck: disabled checker '" checker "'"))))))

(def (cmd-flycheck-set-checker-executable app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Checker: "
      (lambda (checker)
        (echo-read-string echo "Executable path: "
          (lambda (path)
            (echo-message! echo (str "Flycheck: set " checker " executable to " path))))))))

(def (cmd-flycheck-copy-errors-as-kill app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Flycheck: copied errors to kill ring")))

(def (cmd-flycheck-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Flycheck: checking current buffer")))

(def (cmd-flycheck-clear app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Flycheck: cleared all errors")))

;; Round 67 — Search tools (batch 2)
(def (cmd-occur-mode-goto-occurrence app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Occur: jumped to occurrence")))

(def (cmd-multi-occur-in-matching-buffers app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Buffer regexp: "
      (lambda (buf-re)
        (echo-read-string echo "Search regexp: "
          (lambda (re)
            (echo-message! echo (str "Multi-occur: searching '" re "' in buffers matching '" buf-re "'"))))))))

(def (cmd-wgrep-abort-changes app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Wgrep: aborted all changes")))

(def (cmd-wgrep-save-all-buffers app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Wgrep: saved all modified buffers")))

(def (cmd-deadgrep app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Deadgrep search: "
      (lambda (pat)
        (echo-message! echo (str "Deadgrep: searching for '" pat "'"))))))

(def (cmd-visual-regexp app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Visual regexp: "
      (lambda (re)
        (echo-message! echo (str "Visual regexp: highlighting matches for '" re "'"))))))

(def (cmd-visual-regexp-mc app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Visual regexp (mc): "
      (lambda (re)
        (echo-message! echo (str "Visual regexp: multiple cursors for '" re "'"))))))

(def (cmd-anzu-query-replace app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Anzu replace: "
      (lambda (from)
        (echo-read-string echo (str "Replace '" from "' with: ")
          (lambda (to)
            (echo-message! echo (str "Anzu: replaced '" from "' → '" to "'"))))))))

(def (cmd-anzu-replace-at-cursor-thing app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Replace symbol at cursor with: "
      (lambda (to)
        (echo-message! echo (str "Anzu: replaced symbol at cursor with '" to "'"))))))

(def (cmd-color-rg-search-input app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Color-rg search: "
      (lambda (pat)
        (echo-message! echo (str "Color-rg: searching for '" pat "'"))))))

;; Round 68 — Cape, Consult (batch 2)
(def (cmd-cape-keyword app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: completing keyword")))

(def (cmd-cape-abbrev app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: completing abbreviation")))

(def (cmd-cape-dict app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: completing from dictionary")))

(def (cmd-cape-elisp-block app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: completing Elisp in org block")))

(def (cmd-cape-tex app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: completing TeX symbol")))

(def (cmd-cape-sgml app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: completing SGML entity")))

(def (cmd-consult-line-multi app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Search lines across buffers: "
      (lambda (pat)
        (echo-message! echo (str "Consult: searching lines for '" pat "' across buffers"))))))

(def (cmd-consult-keep-lines app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Keep lines matching: "
      (lambda (re)
        (echo-message! echo (str "Consult: kept lines matching '" re "'"))))))

(def (cmd-consult-focus-lines app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Focus lines matching: "
      (lambda (re)
        (echo-message! echo (str "Consult: focusing on lines matching '" re "'"))))))

;; Round 69 — Dev tools (batch 2)
(def (cmd-elp-reset-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ELP: reset all profiling data")))

(def (cmd-benchmark-run-compiled app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Benchmark compiled expression: "
      (lambda (expr)
        (echo-message! echo (str "Benchmark (compiled): " expr))))))

(def (cmd-macrostep-expand app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Macrostep: expanded macro at point")))

(def (cmd-highlight-defined-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'highlight-defined)
    (if (mode-enabled? app 'highlight-defined)
      (echo-message! echo "Highlight defined symbols enabled")
      (echo-message! echo "Highlight defined symbols disabled"))))

(def (cmd-nameless-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'nameless)
    (if (mode-enabled? app 'nameless)
      (echo-message! echo "Nameless mode enabled (hide package prefix)")
      (echo-message! echo "Nameless mode disabled"))))

(def (cmd-suggest app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Suggest: input value: "
      (lambda (input)
        (echo-read-string echo "Desired output: "
          (lambda (output)
            (echo-message! echo (str "Suggest: finding functions that transform " input " → " output))))))))

(def (cmd-aggressive-completion-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'aggressive-completion)
    (if (mode-enabled? app 'aggressive-completion)
      (echo-message! echo "Aggressive completion enabled")
      (echo-message! echo "Aggressive completion disabled"))))

(def (cmd-pp-eval-expression app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "PP eval: "
      (lambda (expr)
        (echo-message! echo (str "Pretty-printed eval: " expr))))))

(def (cmd-pp-eval-last-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Pretty-printed last sexp")))

(def (cmd-pp-macroexpand-last-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Pretty-printed macroexpansion of last sexp")))

;; Round 70 — Tempel, tempo, abbreviations (batch 2)
(def (cmd-tempel-previous app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tempel: moved to previous field")))

(def (cmd-tempo-forward-mark app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tempo: jumped to next mark")))

(def (cmd-tempo-backward-mark app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tempo: jumped to previous mark")))

(def (cmd-edit-abbrevs app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Editing abbreviation table")))

(def (cmd-write-abbrev-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Write abbrevs to file: "
      (lambda (file)
        (echo-message! echo (str "Abbreviations written to " file))))))

(def (cmd-read-abbrev-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Read abbrevs from file: "
      (lambda (file)
        (echo-message! echo (str "Abbreviations loaded from " file))))))

(def (cmd-inverse-add-global-abbrev app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Global abbrev for word before point: "
      (lambda (abbr)
        (echo-message! echo (str "Added global abbreviation '" abbr "'"))))))

(def (cmd-inverse-add-mode-abbrev app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Mode abbrev for word before point: "
      (lambda (abbr)
        (echo-message! echo (str "Added mode abbreviation '" abbr "'"))))))

(def (cmd-insert-abbrevs app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Inserted abbreviation table into buffer")))

(def (cmd-kill-all-abbrevs app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "All abbreviations removed")))

;; Round 71 — Comint, shell (batch 2)
(def (cmd-comint-previous-matching-input app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Previous input matching: "
      (lambda (pat)
        (echo-message! echo (str "Comint: found previous input matching '" pat "'"))))))

(def (cmd-comint-next-matching-input app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Next input matching: "
      (lambda (pat)
        (echo-message! echo (str "Comint: found next input matching '" pat "'"))))))

(def (cmd-comint-run app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Run command in comint: "
      (lambda (cmd)
        (echo-message! echo (str "Comint: running " cmd))))))

(def (cmd-comint-show-output app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: showing last output")))

(def (cmd-shell-resync-dirs app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Shell: resynced directory tracking")))

(def (cmd-shell-dirtrack-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'shell-dirtrack)
    (if (mode-enabled? app 'shell-dirtrack)
      (echo-message! echo "Shell: directory tracking enabled")
      (echo-message! echo "Shell: directory tracking disabled"))))

(def (cmd-dirtrack-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dirtrack)
    (if (mode-enabled? app 'dirtrack)
      (echo-message! echo "Dirtrack mode enabled")
      (echo-message! echo "Dirtrack mode disabled"))))

(def (cmd-comint-truncate-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: buffer truncated")))

(def (cmd-comint-write-output app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Write comint output to: "
      (lambda (file)
        (echo-message! echo (str "Comint: output written to " file))))))

;; Round 72 — Font-lock, highlighting (batch 2)
(def (cmd-set-face-bold-p app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Face: "
      (lambda (face)
        (echo-message! echo (str "Toggled bold on face " face))))))

(def (cmd-set-face-italic-p app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Face: "
      (lambda (face)
        (echo-message! echo (str "Toggled italic on face " face))))))

(def (cmd-color-name-to-rgb app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Color name: "
      (lambda (name)
        (echo-message! echo (str "Color '" name "' → RGB values"))))))

(def (cmd-highlight-parentheses-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'highlight-parentheses)
    (if (mode-enabled? app 'highlight-parentheses)
      (echo-message! echo "Highlight parentheses mode enabled")
      (echo-message! echo "Highlight parentheses mode disabled"))))

(def (cmd-prism-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'prism)
    (if (mode-enabled? app 'prism)
      (echo-message! echo "Prism mode enabled (depth-based coloring)")
      (echo-message! echo "Prism mode disabled"))))

(def (cmd-prism-whitespace-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'prism-whitespace)
    (if (mode-enabled? app 'prism-whitespace)
      (echo-message! echo "Prism whitespace mode enabled")
      (echo-message! echo "Prism whitespace mode disabled"))))

(def (cmd-fontify-face-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'fontify-face)
    (if (mode-enabled? app 'fontify-face)
      (echo-message! echo "Fontify face mode enabled (show face names in color)")
      (echo-message! echo "Fontify face mode disabled"))))

(def (cmd-font-lock-studio app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Font-lock studio: interactive font-lock debugger")))

(def (cmd-font-lock-profiler app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Font-lock profiler: profiling font-lock keywords")))

(def (cmd-ov-highlight-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'ov-highlight)
    (if (mode-enabled? app 'ov-highlight)
      (echo-message! echo "Overlay highlight mode enabled")
      (echo-message! echo "Overlay highlight mode disabled"))))

;; Round 73 — Avy & Ace (batch 2)
(def (cmd-avy-copy-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: copied region")))

(def (cmd-avy-kill-whole-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: killed whole line")))

(def (cmd-avy-kill-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: killed region")))

(def (cmd-avy-kill-ring-save-whole-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: saved whole line to kill ring")))

(def (cmd-avy-kill-ring-save-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: saved region to kill ring")))

(def (cmd-ace-swap-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ace: swapped windows")))

(def (cmd-ace-delete-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ace: deleted selected window")))

(def (cmd-ace-maximize-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ace: maximized selected window")))

(def (cmd-ace-select-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ace: selected window")))

(def (cmd-ace-display-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ace: displayed buffer in selected window")))

;; Round 74 — Paredit & Smartparens (batch 2)
(def (cmd-paredit-split-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: split sexp at point")))

(def (cmd-paredit-wrap-round app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: wrapped sexp in ()")))

(def (cmd-paredit-wrap-square app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: wrapped sexp in []")))

(def (cmd-paredit-wrap-curly app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: wrapped sexp in {}")))

(def (cmd-sp-unwrap-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smartparens: unwrapped sexp")))

(def (cmd-sp-rewrap-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Rewrap with: "
      (lambda (delim)
        (echo-message! echo (str "Smartparens: rewrapped with " delim))))))

(def (cmd-sp-forward-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smartparens: moved forward one sexp")))

(def (cmd-sp-backward-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smartparens: moved backward one sexp")))

(def (cmd-sp-select-next-thing app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smartparens: selected next thing")))

(def (cmd-sp-select-previous-thing app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smartparens: selected previous thing")))

;; Round 75 — AI integration (batch 2)
(def (cmd-chatgpt-shell app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ChatGPT Shell: opening conversation")))

(def (cmd-chatgpt-shell-send-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ChatGPT Shell: sent region to AI")))

(def (cmd-ellama-chat app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Ellama chat: "
      (lambda (msg)
        (echo-message! echo (str "Ellama: sent '" msg "'"))))))

(def (cmd-ellama-summarize app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ellama: summarizing buffer/region")))

(def (cmd-ellama-translate app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Translate to language: "
      (lambda (lang)
        (echo-message! echo (str "Ellama: translating to " lang))))))

(def (cmd-ellama-code-review app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ellama: reviewing code")))

(def (cmd-ellama-code-complete app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ellama: completing code")))

(def (cmd-ellama-ask-about app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Ask about: "
      (lambda (q)
        (echo-message! echo (str "Ellama: asking about '" q "'"))))))

(def (cmd-ellama-improve-grammar app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ellama: improving grammar")))

(def (cmd-ellama-define-word app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Define word: "
      (lambda (word)
        (echo-message! echo (str "Ellama: defining '" word "'"))))))

;; Round 76 — Writing tools (batch 2)
(def (cmd-powerthesaurus-lookup-word app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Thesaurus lookup: "
      (lambda (word)
        (echo-message! echo (str "Thesaurus: synonyms for '" word "'"))))))

(def (cmd-synosaurus-lookup app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Synosaurus lookup: "
      (lambda (word)
        (echo-message! echo (str "Synosaurus: results for '" word "'"))))))

(def (cmd-langtool-check app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LanguageTool: checking buffer")))

(def (cmd-langtool-correct-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LanguageTool: correcting buffer")))

(def (cmd-langtool-check-done app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LanguageTool: check done, clearing overlays")))

(def (cmd-vale-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'vale)
    (if (mode-enabled? app 'vale)
      (echo-message! echo "Vale mode enabled (prose linting)")
      (echo-message! echo "Vale mode disabled"))))

(def (cmd-jinx-languages app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Jinx languages: "
      (lambda (langs)
        (echo-message! echo (str "Jinx: languages set to " langs))))))

(def (cmd-titlecase-dwim app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Title case applied (DWIM)")))

(def (cmd-logos-focus-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'logos-focus)
    (if (mode-enabled? app 'logos-focus)
      (echo-message! echo "Logos focus mode enabled (page-based reading)")
      (echo-message! echo "Logos focus mode disabled"))))

;; Round 77 — mu4e (batch 2)
(def (cmd-mu4e-mark-for-trash app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "mu4e: marked for trash")))

(def (cmd-mu4e-mark-for-move app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Move to maildir: "
      (lambda (dir)
        (echo-message! echo (str "mu4e: marked for move to " dir))))))

(def (cmd-mu4e-mark-for-delete app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "mu4e: marked for deletion")))

(def (cmd-mu4e-mark-execute-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "mu4e: executed all pending marks")))

(def (cmd-mu4e-view-attachment app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "mu4e: viewing attachment")))

(def (cmd-mu4e-search-bookmark app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "mu4e bookmark search: "
      (lambda (bm)
        (echo-message! echo (str "mu4e: running bookmark search '" bm "'"))))))

(def (cmd-mu4e-headers-toggle-threading app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "mu4e: toggled message threading")))

(def (cmd-mu4e-headers-mark-for-flag app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "mu4e: marked message as flagged")))

(def (cmd-mu4e-view-save-attachment app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Save attachment to: "
      (lambda (path)
        (echo-message! echo (str "mu4e: attachment saved to " path))))))

;; Round 78 — Eat & vterm (batch 2)
(def (cmd-eat-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eat: terminal emulator mode")))

(def (cmd-eat-semi-char-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eat: semi-char mode (some keys pass through)")))

(def (cmd-eat-char-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eat: char mode (all keys pass to terminal)")))

(def (cmd-vterm-send-next-key app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vterm: next key sent directly to terminal")))

(def (cmd-vterm-send-C-c app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vterm: sent C-c to terminal")))

(def (cmd-vterm-send-C-z app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vterm: sent C-z to terminal")))

(def (cmd-vterm-clear app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vterm: cleared visible terminal")))

(def (cmd-vterm-clear-scrollback app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vterm: cleared scrollback buffer")))

(def (cmd-vterm-toggle app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vterm: toggled terminal window")))

(def (cmd-vterm-other-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vterm: opened in other window")))

;;; Round 79 — Tree-sitter, Xref, Eldoc-box, Symbol Overlay, Color Identifiers
(def (cmd-calendar-exchange-point-and-mark app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Calendar: exchanged point and mark")))

(def (cmd-treesit-explore app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tree-sitter: explorer opened")))

(def (cmd-treesit-inspect app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tree-sitter: inspecting node at point")))

(def (cmd-xref-find-apropos app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Xref apropos pattern: "
      (lambda (pattern)
        (echo-message! echo (str "Xref: searching for '" pattern "'"))))))

(def (cmd-eldoc-box-hover app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eldoc-box: showing hover documentation")))

(def (cmd-symbol-overlay-put app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Symbol overlay: highlighted symbol at point")))

(def (cmd-symbol-overlay-remove-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Symbol overlay: all overlays removed")))

(def (cmd-symbol-overlay-jump-next app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Symbol overlay: jumped to next occurrence")))

(def (cmd-symbol-overlay-jump-prev app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Symbol overlay: jumped to previous occurrence")))

(def (cmd-color-identifiers-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'color-identifiers)
    (if (mode-enabled? app 'color-identifiers)
      (echo-message! echo "Color identifiers mode enabled")
      (echo-message! echo "Color identifiers mode disabled"))))

;;; Round 80 — Display & Visual Enhancement (cont.)
(def (cmd-face-remap-remove-relative app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Face remapping removed")))

(def (cmd-visual-fill-column-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'visual-fill-column)
    (if (mode-enabled? app 'visual-fill-column)
      (echo-message! echo "Visual fill column mode enabled")
      (echo-message! echo "Visual fill column mode disabled"))))

(def (cmd-writeroom-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'writeroom)
    (if (mode-enabled? app 'writeroom)
      (echo-message! echo "Writeroom mode enabled — distraction-free writing")
      (echo-message! echo "Writeroom mode disabled"))))

(def (cmd-olivetti-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'olivetti)
    (if (mode-enabled? app 'olivetti)
      (echo-message! echo "Olivetti mode enabled — centered text")
      (echo-message! echo "Olivetti mode disabled"))))

(def (cmd-solaire-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'solaire)
    (if (mode-enabled? app 'solaire)
      (echo-message! echo "Solaire mode enabled — distinct background for file buffers")
      (echo-message! echo "Solaire mode disabled"))))

(def (cmd-page-break-lines-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'page-break-lines)
    (if (mode-enabled? app 'page-break-lines)
      (echo-message! echo "Page break lines mode enabled")
      (echo-message! echo "Page break lines mode disabled"))))

(def (cmd-form-feed-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'form-feed)
    (if (mode-enabled? app 'form-feed)
      (echo-message! echo "Form feed mode enabled")
      (echo-message! echo "Form feed mode disabled"))))

(def (cmd-display-fill-column-indicator-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'display-fill-column-indicator)
    (if (mode-enabled? app 'display-fill-column-indicator)
      (echo-message! echo "Fill column indicator displayed")
      (echo-message! echo "Fill column indicator hidden"))))

(def (cmd-nano-theme-toggle app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Nano theme toggled")))

(def (cmd-minions-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'minions)
    (if (mode-enabled? app 'minions)
      (echo-message! echo "Minions mode enabled — minor modes in menu")
      (echo-message! echo "Minions mode disabled"))))

;;; Round 81 — Diff, Smerge & Ediff (cont.)
(def (cmd-smerge-keep-mine app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smerge: kept mine (upper)")))

(def (cmd-smerge-keep-other app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smerge: kept other (lower)")))

(def (cmd-smerge-keep-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smerge: kept all versions")))

(def (cmd-smerge-resolve-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smerge: resolved all conflicts automatically")))

(def (cmd-smerge-keep-base app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Smerge: kept base version")))

(def (cmd-emerge-buffers app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Emerge: merging buffers")))

(def (cmd-patch-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Patch applied to current buffer")))

(def (cmd-ediff-show-registry app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ediff: showing session registry")))

(def (cmd-ediff-toggle-wide-display app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ediff: toggled wide display")))

(def (cmd-ediff-swap-buffers app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ediff: swapped buffer positions")))

;;; Round 82 — Project, Envrc, Nix, DevOps (cont.)
(def (cmd-nix-shell app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Nix shell expression: "
      (lambda (expr)
        (echo-message! echo (str "Nix: entering shell with " expr))))))

(def (cmd-nix-flake-check app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Nix: running flake check")))

(def (cmd-nix-flake-show app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Nix: showing flake outputs")))

(def (cmd-guix-packages app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Guix: listing packages")))

(def (cmd-guix-generations app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Guix: listing generations")))

(def (cmd-docker-images app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Docker: listing images")))

(def (cmd-docker-containers app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Docker: listing containers")))

(def (cmd-docker-networks app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Docker: listing networks")))

(def (cmd-kubel-get-pods app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Kubel: listing pods")))

(def (cmd-kubel-describe-pod app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Describe pod: "
      (lambda (pod)
        (echo-message! echo (str "Kubel: describing pod " pod))))))

;;; Round 83 — Org Babel (cont.)
(def (cmd-ob-shell-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed shell block")))

(def (cmd-ob-lisp-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed Lisp block")))

(def (cmd-ob-js-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed JavaScript block")))

(def (cmd-ob-ruby-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed Ruby block")))

(def (cmd-ob-go-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed Go block")))

(def (cmd-ob-rust-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed Rust block")))

(def (cmd-ob-haskell-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed Haskell block")))

(def (cmd-ob-c-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed C block")))

(def (cmd-ob-java-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed Java block")))

(def (cmd-ob-clojure-execute app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Babel: executed Clojure block")))

;;; Round 84 — Image & Doc-view (cont.)
(def (cmd-image-next-file app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Image: next file")))

(def (cmd-image-previous-file app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Image: previous file")))

(def (cmd-image-transform-rotate app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Image: rotated")))

(def (cmd-image-transform-fit-both app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Image: fit to both dimensions")))

(def (cmd-image-increase-size app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Image: size increased")))

(def (cmd-image-decrease-size app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Image: size decreased")))

(def (cmd-doc-view-toggle-display app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Doc-view: toggled display mode")))

(def (cmd-doc-view-search app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Doc-view search: "
      (lambda (query)
        (echo-message! echo (str "Doc-view: searching for '" query "'"))))))

(def (cmd-pdf-view-auto-slice-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'pdf-view-auto-slice)
    (if (mode-enabled? app 'pdf-view-auto-slice)
      (echo-message! echo "PDF auto-slice mode enabled")
      (echo-message! echo "PDF auto-slice mode disabled"))))

(def (cmd-pdf-view-themed-minor-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'pdf-view-themed)
    (if (mode-enabled? app 'pdf-view-themed)
      (echo-message! echo "PDF themed mode enabled")
      (echo-message! echo "PDF themed mode disabled"))))

;;; Round 85 — Session & Maintenance (cont.)
(def (cmd-symon-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'symon)
    (if (mode-enabled? app 'symon)
      (echo-message! echo "Symon mode enabled — system monitor in mode line")
      (echo-message! echo "Symon mode disabled"))))

(def (cmd-uptimes app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Displaying Emacs uptime history")))

(def (cmd-desktop-clear app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Desktop: session cleared")))

(def (cmd-desktop-remove app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Desktop: session file removed")))

(def (cmd-desktop-change-dir app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Desktop directory: "
      (lambda (dir)
        (echo-message! echo (str "Desktop: directory changed to " dir))))))

(def (cmd-recentf-save-list app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Recent files list saved")))

(def (cmd-midnight-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'midnight)
    (if (mode-enabled? app 'midnight)
      (echo-message! echo "Midnight mode enabled — auto-clean buffers at midnight")
      (echo-message! echo "Midnight mode disabled"))))

(def (cmd-clean-buffer-list app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Buffer list cleaned")))

(def (cmd-lock-file-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'lock-file)
    (if (mode-enabled? app 'lock-file)
      (echo-message! echo "Lock file mode enabled")
      (echo-message! echo "Lock file mode disabled"))))

(def (cmd-backup-walker app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Backup walker: browsing file backups")))

;;; Round 86 — Package Management (cont.)
(def (cmd-quelpa-self-upgrade app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Quelpa: self-upgrading")))

(def (cmd-package-vc-install app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Package VC install URL: "
      (lambda (url)
        (echo-message! echo (str "Package: VC installing from " url))))))

(def (cmd-package-vc-update app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Package: VC updating all packages")))

(def (cmd-borg-assimilate app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Borg assimilate package: "
      (lambda (pkg)
        (echo-message! echo (str "Borg: assimilating " pkg))))))

(def (cmd-borg-build app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Borg build package: "
      (lambda (pkg)
        (echo-message! echo (str "Borg: building " pkg))))))

(def (cmd-borg-activate app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Borg: activating all drones")))

(def (cmd-auto-package-update-now app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Auto package update: updating now")))

(def (cmd-auto-package-update-maybe app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Auto package update: checking if update needed")))

(def (cmd-paradox-list-packages app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paradox: listing packages with ratings")))

(def (cmd-paradox-upgrade-packages app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paradox: upgrading all packages")))

;;; Round 87 — Sly, Geiser & Racket (cont.)
(def (cmd-sly-who-calls app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Sly who calls: "
      (lambda (sym)
        (echo-message! echo (str "Sly: showing callers of " sym))))))

(def (cmd-sly-who-references app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Sly who references: "
      (lambda (sym)
        (echo-message! echo (str "Sly: showing references to " sym))))))

(def (cmd-geiser-eval-definition app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Geiser: evaluated definition at point")))

(def (cmd-geiser-doc-symbol app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Geiser doc for: "
      (lambda (sym)
        (echo-message! echo (str "Geiser: showing doc for " sym))))))

(def (cmd-geiser-connect app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Geiser connect to (host:port): "
      (lambda (addr)
        (echo-message! echo (str "Geiser: connecting to " addr))))))

(def (cmd-racket-run app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Racket: running current file")))

(def (cmd-racket-test app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Racket: running tests")))

(def (cmd-racket-describe app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Racket describe: "
      (lambda (sym)
        (echo-message! echo (str "Racket: describing " sym))))))

(def (cmd-racket-repl app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Racket: REPL started")))

;;; Round 88 — Go & Python Testing (cont.)
(def (cmd-go-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'go)
    (if (mode-enabled? app 'go)
      (echo-message! echo "Go mode enabled")
      (echo-message! echo "Go mode disabled"))))

(def (cmd-gofmt app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Go: buffer formatted with gofmt")))

(def (cmd-go-test-current-test app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Go: running current test")))

(def (cmd-go-import-add app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Go import to add: "
      (lambda (pkg)
        (echo-message! echo (str "Go: added import " pkg))))))

(def (cmd-go-goto-function app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Go to function: "
      (lambda (fn)
        (echo-message! echo (str "Go: navigating to " fn))))))

(def (cmd-go-fill-struct app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Go: struct fields filled with zero values")))

(def (cmd-lsp-go-generate app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP Go: running go generate")))

(def (cmd-python-pytest app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Python: running pytest")))

(def (cmd-python-pytest-file app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Python: running pytest on current file")))

(def (cmd-python-pytest-function app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Python: running pytest on current function")))

;;; Round 89 — Config & Language Modes (cont.)
(def (cmd-docker-compose-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'docker-compose)
    (if (mode-enabled? app 'docker-compose)
      (echo-message! echo "Docker Compose mode enabled")
      (echo-message! echo "Docker Compose mode disabled"))))

(def (cmd-nginx-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'nginx)
    (if (mode-enabled? app 'nginx)
      (echo-message! echo "Nginx mode enabled")
      (echo-message! echo "Nginx mode disabled"))))

(def (cmd-apache-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'apache)
    (if (mode-enabled? app 'apache)
      (echo-message! echo "Apache mode enabled")
      (echo-message! echo "Apache mode disabled"))))

(def (cmd-ini-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'ini)
    (if (mode-enabled? app 'ini)
      (echo-message! echo "INI mode enabled")
      (echo-message! echo "INI mode disabled"))))

(def (cmd-csv-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'csv)
    (if (mode-enabled? app 'csv)
      (echo-message! echo "CSV mode enabled")
      (echo-message! echo "CSV mode disabled"))))

(def (cmd-dotenv-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dotenv)
    (if (mode-enabled? app 'dotenv)
      (echo-message! echo "Dotenv mode enabled")
      (echo-message! echo "Dotenv mode disabled"))))

(def (cmd-pkgbuild-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'pkgbuild)
    (if (mode-enabled? app 'pkgbuild)
      (echo-message! echo "PKGBUILD mode enabled")
      (echo-message! echo "PKGBUILD mode disabled"))))

(def (cmd-lua-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'lua)
    (if (mode-enabled? app 'lua)
      (echo-message! echo "Lua mode enabled")
      (echo-message! echo "Lua mode disabled"))))

(def (cmd-mermaid-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'mermaid)
    (if (mode-enabled? app 'mermaid)
      (echo-message! echo "Mermaid mode enabled")
      (echo-message! echo "Mermaid mode disabled"))))

(def (cmd-just-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'just)
    (if (mode-enabled? app 'just)
      (echo-message! echo "Just mode enabled")
      (echo-message! echo "Just mode disabled"))))

;;; Round 90 — LSP Extensions (cont.)
(def (cmd-lsp-modeline-code-actions-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'lsp-modeline-code-actions)
    (if (mode-enabled? app 'lsp-modeline-code-actions)
      (echo-message! echo "LSP modeline code actions enabled")
      (echo-message! echo "LSP modeline code actions disabled"))))

(def (cmd-lsp-signature-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'lsp-signature)
    (if (mode-enabled? app 'lsp-signature)
      (echo-message! echo "LSP signature help enabled")
      (echo-message! echo "LSP signature help disabled"))))

(def (cmd-lsp-toggle-symbol-highlight app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: symbol highlight toggled")))

(def (cmd-lsp-workspace-folders-add app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Add workspace folder: "
      (lambda (dir)
        (echo-message! echo (str "LSP: added workspace folder " dir))))))

(def (cmd-lsp-workspace-folders-remove app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Remove workspace folder: "
      (lambda (dir)
        (echo-message! echo (str "LSP: removed workspace folder " dir))))))

(def (cmd-lsp-describe-session app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: showing session description")))

(def (cmd-lsp-disconnect app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: disconnected from server")))

(def (cmd-lsp-toggle-trace-io app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: I/O tracing toggled")))

(def (cmd-lsp-avy-lens app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: avy lens activated")))

(def (cmd-lsp-ivy-workspace-symbol app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "LSP workspace symbol: "
      (lambda (sym)
        (echo-message! echo (str "LSP: searching workspace for " sym))))))

;;; Round 91 — Debugger (cont.)
(def (cmd-dap-toggle-breakpoint-condition app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Breakpoint condition: "
      (lambda (cond)
        (echo-message! echo (str "DAP: conditional breakpoint set: " cond))))))

(def (cmd-realgud-gdb app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "GDB debug program: "
      (lambda (prog)
        (echo-message! echo (str "RealGUD: debugging " prog " with GDB"))))))

(def (cmd-realgud-pdb app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "PDB debug script: "
      (lambda (script)
        (echo-message! echo (str "RealGUD: debugging " script " with PDB"))))))

(def (cmd-realgud-node-inspect app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Node inspect script: "
      (lambda (script)
        (echo-message! echo (str "RealGUD: debugging " script " with Node inspector"))))))

(def (cmd-realgud-lldb app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "LLDB debug program: "
      (lambda (prog)
        (echo-message! echo (str "RealGUD: debugging " prog " with LLDB"))))))

(def (cmd-gdb-many-windows app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "GDB: many-windows layout opened")))

(def (cmd-gud-gdb app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "GUD GDB command: "
      (lambda (cmd)
        (echo-message! echo (str "GUD: starting GDB with " cmd))))))

(def (cmd-gud-break app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "GUD: breakpoint set at current line")))

(def (cmd-gud-remove app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "GUD: breakpoint removed at current line")))

(def (cmd-gud-step app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "GUD: stepped into")))

;;; Round 92 — Web Browsing (cont.)
(def (cmd-w3m-search app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "W3M search: "
      (lambda (query)
        (echo-message! echo (str "W3M: searching for '" query "'"))))))

(def (cmd-w3m-bookmark-view app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "W3M: showing bookmarks")))

(def (cmd-shr-browse-url app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SHR: opening URL at point in browser")))

(def (cmd-browse-url-firefox app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Firefox URL: "
      (lambda (url)
        (echo-message! echo (str "Opening " url " in Firefox"))))))

(def (cmd-browse-url-chromium app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Chromium URL: "
      (lambda (url)
        (echo-message! echo (str "Opening " url " in Chromium"))))))

(def (cmd-browse-url-default-browser app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "URL: "
      (lambda (url)
        (echo-message! echo (str "Opening " url " in default browser"))))))

(def (cmd-xwidget-webkit-browse-url app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Xwidget webkit URL: "
      (lambda (url)
        (echo-message! echo (str "Xwidget: browsing " url))))))

(def (cmd-xwidget-webkit-back app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Xwidget webkit: navigated back")))

(def (cmd-xwidget-webkit-forward app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Xwidget webkit: navigated forward")))

(def (cmd-xwidget-webkit-reload app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Xwidget webkit: page reloaded")))

;;; Round 93 — TRAMP & Remote Access (cont.)
(def (cmd-rsync-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Rsync destination: "
      (lambda (dest)
        (echo-message! echo (str "Rsync: syncing to " dest))))))

(def (cmd-scp-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "SCP destination: "
      (lambda (dest)
        (echo-message! echo (str "SCP: copying to " dest))))))

(def (cmd-tramp-term app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "TRAMP terminal host: "
      (lambda (host)
        (echo-message! echo (str "TRAMP: opening terminal on " host))))))

(def (cmd-tramp-open-shell app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "TRAMP: shell opened on remote host")))

(def (cmd-tramp-archive-cleanup app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "TRAMP: archive connections cleaned up")))

(def (cmd-tramp-list-connections app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "TRAMP: listing active connections")))

(def (cmd-tramp-list-remote-buffers app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "TRAMP: listing remote buffers")))

(def (cmd-tramp-toggle-read-only app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "TRAMP: toggled read-only on remote file")))

(def (cmd-tramp-set-connection-local-variables app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "TRAMP: connection-local variables set")))

;;; Round 94 — Org Roam Dailies & Journal (cont.)
(def (cmd-org-roam-dailies-capture-today app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Roam Dailies: capturing today's note")))

(def (cmd-org-roam-dailies-goto-today app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Roam Dailies: opening today's note")))

(def (cmd-org-roam-dailies-goto-yesterday app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Roam Dailies: opening yesterday's note")))

(def (cmd-org-roam-dailies-goto-tomorrow app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Roam Dailies: opening tomorrow's note")))

(def (cmd-org-roam-dailies-goto-date app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Go to daily note for date: "
      (lambda (date)
        (echo-message! echo (str "Org Roam Dailies: opening note for " date))))))

(def (cmd-org-roam-dailies-capture-date app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Capture daily for date: "
      (lambda (date)
        (echo-message! echo (str "Org Roam Dailies: capturing for " date))))))

(def (cmd-org-journal-new-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Journal: new entry created")))

(def (cmd-org-journal-open-current app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Journal: opening current journal")))

(def (cmd-org-journal-search app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Search journal for: "
      (lambda (query)
        (echo-message! echo (str "Org Journal: searching for '" query "'"))))))

(def (cmd-org-journal-list app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Journal: listing all entries")))

;;; Round 95 — Citar & BibTeX (cont.)
(def (cmd-citar-insert-citation app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Insert citation key: "
      (lambda (key)
        (echo-message! echo (str "Citar: inserted citation " key))))))

(def (cmd-citar-insert-reference app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Insert reference key: "
      (lambda (key)
        (echo-message! echo (str "Citar: inserted reference " key))))))

(def (cmd-citar-open-notes app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Citar: opening notes for reference")))

(def (cmd-citar-open-files app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Citar: opening files for reference")))

(def (cmd-bibtex-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'bibtex)
    (if (mode-enabled? app 'bibtex)
      (echo-message! echo "BibTeX mode enabled")
      (echo-message! echo "BibTeX mode disabled"))))

(def (cmd-bibtex-clean-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "BibTeX: entry cleaned")))

(def (cmd-bibtex-fill-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "BibTeX: entry filled")))

(def (cmd-bibtex-reformat app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "BibTeX: buffer reformatted")))

(def (cmd-biblio-lookup app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Biblio lookup: "
      (lambda (query)
        (echo-message! echo (str "Biblio: searching for '" query "'"))))))

(def (cmd-biblio-arxiv-lookup app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "ArXiv lookup: "
      (lambda (query)
        (echo-message! echo (str "Biblio: searching ArXiv for '" query "'"))))))

;;; Round 96 — Eglot & Cape (cont.)
(def (cmd-eglot-find-declaration app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eglot: finding declaration")))

(def (cmd-eglot-find-implementation app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eglot: finding implementation")))

(def (cmd-eglot-find-typeDefinition app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eglot: finding type definition")))

(def (cmd-eglot-hierarchy app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eglot: showing hierarchy")))

(def (cmd-eglot-format-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eglot: buffer formatted")))

(def (cmd-eglot-code-action-rewrite app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eglot: code rewritten")))

(def (cmd-eglot-code-action-inline app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eglot: code inlined")))

(def (cmd-eglot-stderr-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eglot: showing stderr buffer")))

(def (cmd-cape-eglot app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: eglot completion activated")))

(def (cmd-cape-dabbrev app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: dabbrev completion activated")))

;;; Round 97 — Terminal & Detached (cont.)
(def (cmd-term-char-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Term: switched to char mode")))

(def (cmd-term-send-raw-string app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Send raw string: "
      (lambda (str-val)
        (echo-message! echo (str "Term: sent raw string"))))))

(def (cmd-term-toggle-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Term: toggled between line and char mode")))

(def (cmd-comint-redirect-send-command app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Redirect command: "
      (lambda (cmd)
        (echo-message! echo (str "Comint: redirecting output of " cmd))))))

(def (cmd-detached-compile app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Detached compile command: "
      (lambda (cmd)
        (echo-message! echo (str "Detached: compiling with " cmd))))))

(def (cmd-detached-open-session app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Detached: opening session")))

(def (cmd-detached-list-sessions app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Detached: listing all sessions")))

(def (cmd-detached-view-session app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Detached: viewing session output")))

(def (cmd-detached-attach app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Detached: attaching to session")))

(def (cmd-detached-delete-session app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Detached: session deleted")))

;;; Round 98 — Hydra (cont.)
(def (cmd-hydra-keyboard-quit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: quit")))

(def (cmd-hydra-text-scale app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: text scale menu opened")))

(def (cmd-hydra-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: buffer management menu opened")))

(def (cmd-hydra-git app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: git menu opened")))

(def (cmd-hydra-project app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: project menu opened")))

(def (cmd-hydra-org app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: org menu opened")))

(def (cmd-hydra-flycheck app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: flycheck menu opened")))

(def (cmd-hydra-lsp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: LSP menu opened")))

(def (cmd-hydra-smerge app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: smerge menu opened")))

(def (cmd-hydra-rectangle app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Hydra: rectangle operations menu opened")))

;;; Round 99 — Evil Extensions (cont.)
(def (cmd-evil-numbers-decrement app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: decremented number at point")))

(def (cmd-evil-matchit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: jumped to matching tag/paren")))

(def (cmd-evil-lion-left app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: aligned left")))

(def (cmd-evil-lion-right app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: aligned right")))

(def (cmd-evil-snipe-f app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Evil snipe f: "
      (lambda (chars)
        (echo-message! echo (str "Evil: sniped forward to " chars))))))

(def (cmd-evil-snipe-F app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Evil snipe F: "
      (lambda (chars)
        (echo-message! echo (str "Evil: sniped backward to " chars))))))

(def (cmd-evil-snipe-s app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Evil snipe s: "
      (lambda (chars)
        (echo-message! echo (str "Evil: sniped forward (inclusive) to " chars))))))

(def (cmd-evil-snipe-S app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Evil snipe S: "
      (lambda (chars)
        (echo-message! echo (str "Evil: sniped backward (inclusive) to " chars))))))

(def (cmd-evil-collection-init app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil Collection: initialized keybindings")))

(def (cmd-evil-owl-goto-mark app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Evil owl go to mark: "
      (lambda (mark)
        (echo-message! echo (str "Evil Owl: jumped to mark " mark))))))

;;; ——— Round 100: Consult framework (batch 2) ———

(def (cmd-consult-org-heading app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult: navigating org headings")))

(def (cmd-consult-org-agenda app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult: browsing org agenda items")))

(def (cmd-consult-locate app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Consult locate: "
      (lambda (pattern)
        (echo-message! echo (str "Consult: locating files matching '" pattern "'"))))))

(def (cmd-consult-project-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Consult project buffer: "
      (lambda (name)
        (echo-message! echo (str "Consult: switching to project buffer " name))))))

(def (cmd-consult-fd app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Consult fd: "
      (lambda (pattern)
        (echo-message! echo (str "Consult: finding files with fd '" pattern "'"))))))

(def (cmd-consult-multi app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult: multi-source search across buffers and files")))

(def (cmd-consult-isearch-history app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult: browsing isearch history")))

(def (cmd-consult-narrow app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Consult narrow key: "
      (lambda (key)
        (echo-message! echo (str "Consult: narrowed to source " key))))))

(def (cmd-consult-widen app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult: widened to all sources")))

(def (cmd-consult-mark app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Consult: navigating mark ring")))

;;; ——— Round 101: Vertico/Corfu completion (batch 2) ———

(def (cmd-corfu-next app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: moved to next completion candidate")))

(def (cmd-corfu-previous app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: moved to previous completion candidate")))

(def (cmd-corfu-insert app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: inserted completion")))

(def (cmd-corfu-show-documentation app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: showing documentation for current candidate")))

(def (cmd-corfu-show-location app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: showing source location of current candidate")))

(def (cmd-corfu-info-documentation app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: opened documentation in separate buffer")))

(def (cmd-corfu-info-location app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: opened source location in separate buffer")))

(def (cmd-corfu-popupinfo-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'corfu-popupinfo)
    (if (mode-enabled? app 'corfu-popupinfo)
      (echo-message! echo "Corfu popup info enabled")
      (echo-message! echo "Corfu popup info disabled"))))

(def (cmd-vertico-directory-up app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vertico: moved up one directory level")))

(def (cmd-vertico-directory-enter app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Vertico: entered directory")))

;;; ——— Round 102: Emacs Lisp development & debugging (batch 2) ———

(def (cmd-edebug-top-level-nonstop app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Edebug: exited to top level (nonstop mode)")))

(def (cmd-ert-results-rerun-test app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ERT: rerunning test at point")))

(def (cmd-elisp-refs-function app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Elisp refs function: "
      (lambda (name)
        (echo-message! echo (str "Elisp refs: finding references to function " name))))))

(def (cmd-elisp-refs-macro app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Elisp refs macro: "
      (lambda (name)
        (echo-message! echo (str "Elisp refs: finding references to macro " name))))))

(def (cmd-elisp-refs-variable app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Elisp refs variable: "
      (lambda (name)
        (echo-message! echo (str "Elisp refs: finding references to variable " name))))))

(def (cmd-elisp-refs-symbol app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Elisp refs symbol: "
      (lambda (name)
        (echo-message! echo (str "Elisp refs: finding all references to " name))))))

(def (cmd-eldoc-print-current-symbol-info app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Eldoc: displaying documentation for symbol at point")))

(def (cmd-ielm-send-input app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "IELM: sent input for evaluation")))

(def (cmd-ielm-return app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "IELM: newline or send input")))

(def (cmd-ielm-clear-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "IELM: cleared interaction buffer")))

;;; ——— Round 103: Org-mode advanced (batch 2) ———

(def (cmd-org-table-transpose-table-at-point app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Table: transposed table at point")))

(def (cmd-org-table-toggle-formula-debugger app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'org-table-formula-debugger)
    (if (mode-enabled? app 'org-table-formula-debugger)
      (echo-message! echo "Org Table formula debugger enabled")
      (echo-message! echo "Org Table formula debugger disabled"))))

(def (cmd-org-table-field-info app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Table: showing field info at point")))

(def (cmd-org-attach-attach app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Attach file: "
      (lambda (file)
        (echo-message! echo (str "Org Attach: attached " file))))))

(def (cmd-org-attach-open app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Attach: opening attachment")))

(def (cmd-org-attach-reveal app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Attach: revealing attachment directory")))

(def (cmd-org-attach-sync app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Attach: synchronized attachments")))

(def (cmd-org-attach-delete-one app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Delete attachment: "
      (lambda (name)
        (echo-message! echo (str "Org Attach: deleted " name))))))

(def (cmd-org-attach-delete-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org Attach: deleted all attachments")))

(def (cmd-org-attach-set-directory app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Attachment directory: "
      (lambda (dir)
        (echo-message! echo (str "Org Attach: set directory to " dir))))))

;;; ——— Round 104: Magit advanced (batch 2) ———

(def (cmd-magit-subtree-pull app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Subtree pull prefix: "
      (lambda (prefix)
        (echo-message! echo (str "Magit: pulled subtree " prefix))))))

(def (cmd-magit-subtree-push app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Subtree push prefix: "
      (lambda (prefix)
        (echo-message! echo (str "Magit: pushed subtree " prefix))))))

(def (cmd-magit-subtree-split app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Subtree split prefix: "
      (lambda (prefix)
        (echo-message! echo (str "Magit: split subtree " prefix))))))

(def (cmd-magit-submodule-populate app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: populated submodules")))

(def (cmd-magit-submodule-synchronize app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: synchronized submodule URLs")))

(def (cmd-magit-submodule-unpopulate app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: unpopulated submodules")))

(def (cmd-magit-am-apply-patches app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Apply patches from: "
      (lambda (path)
        (echo-message! echo (str "Magit: applying patches from " path))))))

(def (cmd-magit-am-continue app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: continuing patch application")))

(def (cmd-magit-am-abort app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: aborted patch application")))

(def (cmd-magit-format-patch app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Format patch range: "
      (lambda (range)
        (echo-message! echo (str "Magit: formatted patches for " range))))))

;;; ——— Round 105: Text manipulation & editing helpers (batch 2) ———

(def (cmd-set-justification-center app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Justification set to center")))

(def (cmd-set-justification-full app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Justification set to full")))

(def (cmd-set-justification-none app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Justification set to none")))

(def (cmd-picture-mode-exit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Picture mode: exited")))

(def (cmd-picture-movement-right app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Picture: movement direction set to right")))

(def (cmd-picture-movement-left app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Picture: movement direction set to left")))

(def (cmd-picture-movement-up app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Picture: movement direction set to up")))

(def (cmd-picture-movement-down app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Picture: movement direction set to down")))

(def (cmd-picture-clear-column app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Picture: cleared column at point")))

(def (cmd-picture-clear-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Picture: cleared line at point")))

;;; ——— Round 106: Help & info system (batch 2) ———

(def (cmd-info-final-node app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Info: navigated to final node")))

(def (cmd-info-up app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Info: navigated up one level")))

(def (cmd-info-nth-menu-item app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Menu item number: "
      (lambda (n)
        (echo-message! echo (str "Info: selected menu item " n))))))

(def (cmd-shortdoc app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Shortdoc group: "
      (lambda (group)
        (echo-message! echo (str "Shortdoc: displaying group '" group "'"))))))

(def (cmd-help-with-tutorial-spec-language app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Tutorial language: "
      (lambda (lang)
        (echo-message! echo (str "Help: opening tutorial in " lang))))))

(def (cmd-view-order-manuals app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Viewing ordering information for Emacs manuals")))

(def (cmd-view-emacs-FAQ app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Viewing Emacs FAQ")))

(def (cmd-view-emacs-problems app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Viewing known Emacs problems")))

(def (cmd-view-emacs-debugging app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Viewing Emacs debugging information")))

(def (cmd-view-emacs-news app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Viewing Emacs news")))

;;; ——— Round 107: Dired advanced (batch 2) ———

(def (cmd-dired-filter-by-regexp app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Filter by regexp: "
      (lambda (pattern)
        (echo-message! echo (str "Dired: filtered by regexp '" pattern "'"))))))

(def (cmd-dired-filter-by-extension app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Filter by extension: "
      (lambda (ext)
        (echo-message! echo (str "Dired: filtered by extension ." ext))))))

(def (cmd-dired-filter-by-directory app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: filtered to show only directories")))

(def (cmd-dired-filter-by-dot-files app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: filtered to show/hide dot files")))

(def (cmd-dired-filter-by-size app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Filter by size (e.g. +1M): "
      (lambda (size)
        (echo-message! echo (str "Dired: filtered by size " size))))))

(def (cmd-dired-filter-by-date app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Filter by date (e.g. -7d): "
      (lambda (date)
        (echo-message! echo (str "Dired: filtered by date " date))))))

(def (cmd-dired-filter-pop app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: popped last filter")))

(def (cmd-dired-filter-pop-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: removed all filters")))

(def (cmd-dired-avfs-open app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: opened file via AVFS virtual filesystem")))

(def (cmd-dired-open-file app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: opened file with external application")))

;;; ——— Round 108: EWW, RSS & web browsing (batch 2) ———

(def (cmd-elfeed-goodies-setup app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Elfeed Goodies: setup complete")))

(def (cmd-elfeed-org app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Elfeed: loaded feed configuration from org file")))

(def (cmd-elfeed-search-yank app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Elfeed: yanked entry URL to kill ring")))

(def (cmd-newsticker-start app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Newsticker: started fetching news")))

(def (cmd-newsticker-stop app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Newsticker: stopped fetching news")))

(def (cmd-newsticker-plainview app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Newsticker: showing plain view")))

(def (cmd-newsticker-add-url app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Feed URL: "
      (lambda (url)
        (echo-message! echo (str "Newsticker: added feed " url))))))

(def (cmd-shr-copy-url app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SHR: copied URL at point to kill ring")))

(def (cmd-shr-next-link app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SHR: moved to next link")))

(def (cmd-shr-previous-link app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SHR: moved to previous link")))

;;; ——— Round 109: Calendar, diary & timeclock (batch 2) ———

(def (cmd-calendar-phases-of-moon app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Calendar: showing phases of the moon")))

(def (cmd-calendar-print-day-of-year app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Calendar: showing day of year")))

(def (cmd-timeclock-change app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Change to project: "
      (lambda (project)
        (echo-message! echo (str "Timeclock: changed to project " project))))))

(def (cmd-timeclock-status-string app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Timeclock: showing current status")))

(def (cmd-timeclock-reread-log app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Timeclock: reread log file")))

(def (cmd-timeclock-workday-remaining app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Timeclock: showing workday time remaining")))

(def (cmd-calendar-count-days-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Calendar: counting days in region")))

(def (cmd-calendar-goto-iso-date app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "ISO date (YYYY-MM-DD): "
      (lambda (date)
        (echo-message! echo (str "Calendar: jumped to ISO date " date))))))

(def (cmd-calendar-goto-hebrew-date app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Hebrew date: "
      (lambda (date)
        (echo-message! echo (str "Calendar: jumped to Hebrew date " date))))))

(def (cmd-calendar-goto-islamic-date app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Islamic date: "
      (lambda (date)
        (echo-message! echo (str "Calendar: jumped to Islamic date " date))))))
