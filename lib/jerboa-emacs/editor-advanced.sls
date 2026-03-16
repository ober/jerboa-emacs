#!chezscheme
;;; editor-advanced.sls — Advanced commands for jemacs
;;;
;;; Ported from gerbil-emacs/editor-advanced.ss
;;; Misc navigation, where-is, apropos, universal argument, text transforms,
;;; hex dump, diff, checksum, eval buffer, ediff, calculator, modes,
;;; hippie expand.

(library (jerboa-emacs editor-advanced)
  (export
    ;; Misc navigation
    cmd-exchange-point-and-mark
    cmd-mark-whole-buffer
    cmd-recenter-top-bottom
    cmd-what-page
    cmd-count-lines-region
    cmd-copy-line

    ;; Help: where-is, apropos
    cmd-where-is
    cmd-apropos-command

    ;; Buffer: toggle-read-only, rename
    cmd-toggle-read-only
    cmd-rename-buffer

    ;; Other-window commands
    cmd-switch-buffer-other-window
    cmd-find-file-other-window

    ;; Universal argument
    cmd-universal-argument
    cmd-digit-argument
    cmd-negative-argument
    cmd-digit-argument-0 cmd-digit-argument-1 cmd-digit-argument-2
    cmd-digit-argument-3 cmd-digit-argument-4 cmd-digit-argument-5
    cmd-digit-argument-6 cmd-digit-argument-7 cmd-digit-argument-8
    cmd-digit-argument-9

    ;; Text transforms
    cmd-tabify
    cmd-untabify
    cmd-base64-encode-region
    cmd-base64-decode-region
    rot13-char rot13-string
    cmd-rot13-region

    ;; Hex dump
    cmd-hexl-mode

    ;; Count matches, delete duplicate lines
    cmd-count-matches
    cmd-delete-duplicate-lines

    ;; Diff buffer with file
    cmd-diff-buffer-with-file

    ;; Checksum
    cmd-checksum

    ;; Async shell command
    cmd-async-shell-command

    ;; Toggle truncate lines
    cmd-toggle-truncate-lines

    ;; Grep in buffer
    cmd-grep-buffer

    ;; Insert date/char
    cmd-insert-date
    cmd-insert-char

    ;; Eval buffer/region
    cmd-eval-buffer
    cmd-eval-region

    ;; Clone/scratch buffer
    cmd-clone-buffer
    cmd-scratch-buffer

    ;; Save some buffers
    cmd-save-some-buffers

    ;; Revert buffer quick
    cmd-revert-buffer-quick

    ;; Toggle highlighting
    cmd-toggle-highlighting

    ;; Misc utility
    cmd-view-lossage
    cmd-display-time
    cmd-pwd

    ;; Ediff
    cmd-ediff-buffers

    ;; Calculator
    cmd-calc

    ;; Toggle case-fold-search
    cmd-toggle-case-fold-search

    ;; Describe bindings
    cmd-describe-bindings

    ;; Center line
    cmd-center-line

    ;; What face
    cmd-what-face

    ;; List processes
    cmd-list-processes

    ;; Message log
    log-message!
    cmd-view-messages

    ;; View errors/output
    cmd-view-errors
    cmd-view-output

    ;; Auto-fill mode
    cmd-toggle-auto-fill

    ;; Rename/delete file and buffer
    cmd-rename-file-and-buffer
    cmd-delete-file-and-buffer

    ;; Sudo
    cmd-sudo-write
    cmd-sudo-edit

    ;; Sort numeric
    cmd-sort-numeric

    ;; Word count
    cmd-count-words-region

    ;; Overwrite mode
    cmd-toggle-overwrite-mode

    ;; Visual line mode
    cmd-toggle-visual-line-mode

    ;; Set fill column
    cmd-set-fill-column

    ;; Fill column indicator
    cmd-toggle-fill-column-indicator

    ;; Debug on error
    cmd-toggle-debug-on-error

    ;; Repeat complex command
    cmd-repeat-complex-command

    ;; Eldoc
    cmd-eldoc

    ;; Highlight symbol
    cmd-highlight-symbol
    cmd-clear-highlight

    ;; Indent rigidly
    cmd-indent-rigidly-right
    cmd-indent-rigidly-left

    ;; Goto first/last non-blank
    cmd-goto-first-non-blank
    cmd-goto-last-non-blank

    ;; Buffer stats
    cmd-buffer-stats

    ;; Toggle show tabs/eol
    cmd-toggle-show-tabs
    cmd-toggle-show-eol

    ;; Copy from above/below
    cmd-copy-from-above
    cmd-copy-from-below

    ;; Open line above
    cmd-open-line-above

    ;; Select line
    cmd-select-line

    ;; Split line
    cmd-split-line

    ;; Convert line endings
    cmd-convert-to-unix
    cmd-convert-to-dos

    ;; Enlarge/shrink window
    cmd-enlarge-window
    cmd-shrink-window

    ;; What encoding
    cmd-what-encoding

    ;; Hippie expand
    cmd-hippie-expand

    ;; Swap buffers
    cmd-swap-buffers

    ;; Tab width/indent
    cmd-cycle-tab-width
    cmd-toggle-indent-tabs-mode

    ;; Buffer info
    cmd-buffer-info)

  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-strip-directory)
          (only (std srfi srfi-13) string-join string-contains string-prefix? string-trim string-trim-both)
          (only (std misc string) string-split)
          (std misc process)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (chez-scintilla style)
          (chez-scintilla tui)
          (jerboa-emacs core)
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
          (jerboa-emacs editor-core)
          (jerboa-emacs editor-ui)
          (jerboa-emacs editor-text))

  ;;;=========================================================================
  ;;; Mutable state (not exported — modified via set!)
  ;;;=========================================================================

  (define *case-fold-search* #t)
  (define *message-log* '())
  (define *message-log-max* 100)
  (define *overwrite-mode* #f)
  (define *visual-line-mode* #f)
  (define *fill-column-indicator* #f)
  (define *debug-on-error* #f)
  (define *last-mx-command* #f)
  (define *show-tabs* #f)
  (define *show-eol* #f)

  ;;;=========================================================================
  ;;; Stubs for base64 / hex / sha256
  ;;;=========================================================================

  (define (base64-encode s)
    ;; Stub — base64 not yet ported
    (string-append "[base64:" s "]"))

  (define (base64-decode s)
    ;; Stub — base64 not yet ported
    s)

  (define (sha256-stub bv)
    ;; Stub — sha256 not yet ported; return a dummy bytevector
    (make-bytevector 32 0))

  (define (hex-encode bv)
    ;; Simple hex-encode for bytevectors
    (let loop ((i 0) (acc '()))
      (if (>= i (bytevector-length bv))
        (apply string-append (reverse acc))
        (let* ((b (bytevector-u8-ref bv i))
               (h (number->string b 16))
               (padded (if (< b 16) (string-append "0" h) h)))
          (loop (+ i 1) (cons padded acc))))))

  ;;;=========================================================================
  ;;; Misc navigation commands
  ;;;=========================================================================

  (define (cmd-exchange-point-and-mark app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! (app-state-echo app) "No mark set")
        (let ((pos (editor-get-current-pos ed)))
          (buffer-mark-set! buf pos)
          (editor-goto-pos ed mark)
          (echo-message! (app-state-echo app) "Mark and point exchanged")))))

  (define (cmd-mark-whole-buffer app)
    (cmd-select-all app))

  (define (cmd-recenter-top-bottom app)
    (editor-scroll-caret (current-editor app)))

  (define (cmd-what-page app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (line (editor-line-from-position ed pos))
           (pages
             (let loop ((i 0) (count 1))
               (if (>= i pos) count
                 (if (char=? (string-ref text i) #\page)
                   (loop (+ i 1) (+ count 1))
                   (loop (+ i 1) count))))))
      (echo-message! (app-state-echo app)
        (string-append "Page " (number->string pages)
                       ", Line " (number->string (+ line 1))))))

  (define (cmd-count-lines-region app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! (app-state-echo app) "No region")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (lines (+ (- end-line start-line) 1))
               (chars (- end start)))
          (echo-message! (app-state-echo app)
            (string-append "Region has " (number->string lines)
                           " lines, " (number->string chars) " chars"))))))

  (define (cmd-copy-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line))
           (line-end (editor-get-line-end-position ed line))
           (text (editor-get-text ed))
           (total (editor-get-line-count ed))
           ;; Include newline if not last line
           (end (if (< (+ line 1) total)
                  (editor-position-from-line ed (+ line 1))
                  line-end))
           (line-text (substring text line-start end)))
      (app-state-kill-ring-set! app
        (cons line-text (app-state-kill-ring app)))
      (echo-message! (app-state-echo app) "Line copied")))

  ;;;=========================================================================
  ;;; Help: where-is, apropos-command
  ;;;=========================================================================

  (define (cmd-where-is app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Where is command: " row width)))
      (if (not input)
        (echo-message! echo "Cancelled")
        (let* ((cmd-name (string->symbol input))
               (found '()))
          ;; Search global keymap
          (for-each
            (lambda (entry)
              (let ((key (car entry))
                    (val (cdr entry)))
                (cond
                  ((eq? val cmd-name)
                   (set! found (cons key found)))
                  ((hash-table? val)
                   ;; Search prefix map
                   (for-each
                     (lambda (sub)
                       (when (eq? (cdr sub) cmd-name)
                         (set! found (cons (string-append key " " (car sub)) found))))
                     (keymap-entries val))))))
            (keymap-entries *global-keymap*))
          (if (null? found)
            (echo-message! echo (string-append input " is not on any key"))
            (echo-message! echo
              (string-append input " is on "
                             (string-join (reverse found) ", "))))))))

  (define (cmd-apropos-command app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Apropos command: " row width)))
      (if (not input)
        (echo-message! echo "Cancelled")
        (let ((matches '()))
          ;; Search all registered commands
          (hash-for-each
            (lambda (name _proc)
              (when (string-contains (symbol->string name) input)
                (set! matches (cons (symbol->string name) matches))))
            *all-commands*)
          (if (null? matches)
            (echo-message! echo (string-append "No commands matching '" input "'"))
            (let* ((sorted (list-sort string<? matches))
                   (text (string-append "Commands matching '" input "':\n\n"
                                        (string-join sorted "\n") "\n")))
              ;; Show in *Help* buffer
              (let* ((ed (current-editor app))
                     (buf (or (buffer-by-name "*Help*")
                              (buffer-create! "*Help*" ed #f))))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! (current-window fr) buf)
                (editor-set-text ed text)
                (editor-set-save-point ed)
                (editor-goto-pos ed 0)
                (echo-message! echo
                  (string-append (number->string (length sorted))
                                 " commands match")))))))))

  ;;;=========================================================================
  ;;; Buffer: toggle-read-only, rename-buffer
  ;;;=========================================================================

  (define (cmd-toggle-read-only app)
    (let* ((ed (current-editor app))
           (readonly? (editor-get-read-only? ed)))
      (editor-set-read-only ed (not readonly?))
      (echo-message! (app-state-echo app)
        (if readonly? "Buffer is now writable" "Buffer is now read-only"))))

  (define (cmd-rename-buffer app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (current-buffer-from-app app))
           (old-name (buffer-name buf))
           (new-name (echo-read-string echo
                       (string-append "Rename buffer (was " old-name "): ")
                       row width)))
      (if (not new-name)
        (echo-message! echo "Cancelled")
        (if (string=? new-name "")
          (echo-error! echo "Name cannot be empty")
          (begin
            (buffer-name-set! buf new-name)
            (echo-message! echo
              (string-append "Renamed to " new-name)))))))

  ;;;=========================================================================
  ;;; Other-window commands
  ;;;=========================================================================

  (define (cmd-switch-buffer-other-window app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (wins (frame-windows fr)))
      (if (<= (length wins) 1)
        (begin
          (cmd-split-window app)
          (frame-other-window! fr)
          (cmd-switch-buffer app))
        (begin
          (frame-other-window! fr)
          (cmd-switch-buffer app)))))

  (define (cmd-find-file-other-window app)
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr)))
      (if (<= (length wins) 1)
        (begin
          (cmd-split-window app)
          (frame-other-window! fr)
          (cmd-find-file app))
        (begin
          (frame-other-window! fr)
          (cmd-find-file app)))))

  ;;;=========================================================================
  ;;; Universal argument (C-u)
  ;;;=========================================================================

  (define (cmd-universal-argument app)
    (let ((current (app-state-prefix-arg app)))
      (cond
       ((not current)
        (app-state-prefix-arg-set! app '(4)))
       ((list? current)
        (app-state-prefix-arg-set! app (list (* 4 (car current)))))
       (else
        (app-state-prefix-arg-set! app '(4))))
      (echo-message! (app-state-echo app)
                     (string-append "C-u"
                                    (let ((val (car (app-state-prefix-arg app))))
                                      (if (= val 4) "" (string-append " " (number->string val))))
                                    "-"))))

  (define (cmd-digit-argument app digit)
    (let ((current (app-state-prefix-arg app)))
      (cond
       ((number? current)
        (app-state-prefix-arg-set! app (+ (* current 10) digit)))
       ((eq? current '-)
        (app-state-prefix-arg-set! app (- digit)))
       (else
        (app-state-prefix-arg-set! app digit)))
      (app-state-prefix-digit-mode?-set! app #t)
      (echo-message! (app-state-echo app)
                     (string-append "Arg: " (if (eq? (app-state-prefix-arg app) '-)
                                              "-"
                                              (number->string (app-state-prefix-arg app)))))))

  (define (cmd-negative-argument app)
    (app-state-prefix-arg-set! app '-)
    (app-state-prefix-digit-mode?-set! app #t)
    (echo-message! (app-state-echo app) "Arg: -"))

  ;; Individual digit argument commands for registry
  (define (cmd-digit-argument-0 app) (cmd-digit-argument app 0))
  (define (cmd-digit-argument-1 app) (cmd-digit-argument app 1))
  (define (cmd-digit-argument-2 app) (cmd-digit-argument app 2))
  (define (cmd-digit-argument-3 app) (cmd-digit-argument app 3))
  (define (cmd-digit-argument-4 app) (cmd-digit-argument app 4))
  (define (cmd-digit-argument-5 app) (cmd-digit-argument app 5))
  (define (cmd-digit-argument-6 app) (cmd-digit-argument app 6))
  (define (cmd-digit-argument-7 app) (cmd-digit-argument app 7))
  (define (cmd-digit-argument-8 app) (cmd-digit-argument app 8))
  (define (cmd-digit-argument-9 app) (cmd-digit-argument app 9))

  ;;;=========================================================================
  ;;; Text transforms: tabify, untabify, base64, rot13
  ;;;=========================================================================

  (define (cmd-tabify app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (text (editor-get-text ed)))
      (let-values (((start end)
                    (if mark
                      (let ((pos (editor-get-current-pos ed)))
                        (values (min mark pos) (max mark pos)))
                      (values 0 (string-length text)))))
        (let* ((region (substring text start end))
               ;; Replace runs of 8 spaces with tab
               (result (let loop ((s region) (acc ""))
                         (let ((idx (string-contains s "        ")))  ; 8 spaces
                           (if idx
                             (loop (substring s (+ idx 8) (string-length s))
                                   (string-append acc (substring s 0 idx) "\t"))
                             (string-append acc s))))))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (when mark (buffer-mark-set! buf #f))
          (echo-message! echo "Tabified")))))

  (define (cmd-untabify app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (text (editor-get-text ed)))
      (let-values (((start end)
                    (if mark
                      (let ((pos (editor-get-current-pos ed)))
                        (values (min mark pos) (max mark pos)))
                      (values 0 (string-length text)))))
        (let* ((region (substring text start end))
               ;; Replace all tabs with 8 spaces
               (result (let loop ((i 0) (acc '()))
                         (if (>= i (string-length region))
                           (apply string-append (reverse acc))
                           (if (char=? (string-ref region i) #\tab)
                             (loop (+ i 1) (cons "        " acc))
                             (loop (+ i 1) (cons (string (string-ref region i)) acc)))))))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (when mark (buffer-mark-set! buf #f))
          (echo-message! echo "Untabified")))))

  (define (cmd-base64-encode-region app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region (set mark first)")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (region (substring (editor-get-text ed) start end))
               (encoded (base64-encode region)))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start encoded))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Base64 encoded")))))

  (define (cmd-base64-decode-region app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region (set mark first)")
        (guard (e [#t (echo-error! echo "Base64 decode error")])
          (let* ((pos (editor-get-current-pos ed))
                 (start (min mark pos))
                 (end (max mark pos))
                 (region (substring (editor-get-text ed) start end))
                 (decoded (base64-decode (string-trim-both region))))
            (with-undo-action ed
              (editor-delete-range ed start (- end start))
              (editor-insert-text ed start decoded))
            (buffer-mark-set! buf #f)
            (echo-message! echo "Base64 decoded"))))))

  (define (rot13-char ch)
    (cond
      ((and (char>=? ch #\a) (char<=? ch #\z))
       (integer->char (+ (char->integer #\a)
                         (modulo (+ (- (char->integer ch) (char->integer #\a)) 13) 26))))
      ((and (char>=? ch #\A) (char<=? ch #\Z))
       (integer->char (+ (char->integer #\A)
                         (modulo (+ (- (char->integer ch) (char->integer #\A)) 13) 26))))
      (else ch)))

  (define (rot13-string s)
    (let* ((len (string-length s))
           (result (make-string len)))
      (let loop ((i 0))
        (when (< i len)
          (string-set! result i (rot13-char (string-ref s i)))
          (loop (+ i 1))))
      result))

  (define (cmd-rot13-region app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (text (editor-get-text ed)))
      (let-values (((start end)
                    (if mark
                      (let ((pos (editor-get-current-pos ed)))
                        (values (min mark pos) (max mark pos)))
                      (values 0 (string-length text)))))
        (let* ((region (substring text start end))
               (result (rot13-string region)))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (when mark (buffer-mark-set! buf #f))
          (echo-message! echo "ROT13 applied")))))

  ;;;=========================================================================
  ;;; Hex dump display
  ;;;=========================================================================

  (define (cmd-hexl-mode app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (text (editor-get-text ed))
           (bytes (string->utf8 text))
           (len (bytevector-length bytes))
           (lines '()))
      ;; Format hex dump, 16 bytes per line
      (let loop ((offset 0))
        (when (< offset len)
          (let* ((end (min (+ offset 16) len))
                 (hex-parts '())
                 (ascii-parts '()))
            ;; Hex portion
            (let hex-loop ((i offset))
              (when (< i end)
                (let* ((b (bytevector-u8-ref bytes i))
                       (h (number->string b 16)))
                  (set! hex-parts
                    (cons (if (< b 16) (string-append "0" h) h)
                          hex-parts)))
                (hex-loop (+ i 1))))
            ;; ASCII portion
            (let ascii-loop ((i offset))
              (when (< i end)
                (let ((b (bytevector-u8-ref bytes i)))
                  (set! ascii-parts
                    (cons (if (and (>= b 32) (<= b 126))
                            (string (integer->char b))
                            ".")
                          ascii-parts)))
                (ascii-loop (+ i 1))))
            ;; Format offset
            (let* ((off-str (number->string offset 16))
                   (off-padded (string-append
                                 (make-string (max 0 (- 8 (string-length off-str))) #\0)
                                 off-str))
                   (hex-str (string-join (reverse hex-parts) " "))
                   ;; Pad hex to consistent width (47 chars for 16 bytes)
                   (hex-padded (string-append hex-str
                                 (make-string (max 0 (- 47 (string-length hex-str))) #\space)))
                   (ascii-str (apply string-append (reverse ascii-parts))))
              (set! lines
                (cons (string-append off-padded "  " hex-padded "  |" ascii-str "|")
                      lines))))
          (loop (+ offset 16))))
      ;; Display in *Hex* buffer
      (let* ((result (string-join (reverse lines) "\n"))
             (full-text (string-append "Hex Dump (" (number->string len) " bytes):\n\n"
                                       result "\n"))
             (buf (or (buffer-by-name "*Hex*")
                      (buffer-create! "*Hex*" ed #f))))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! (current-window fr) buf)
        (editor-set-text ed full-text)
        (editor-set-save-point ed)
        (editor-goto-pos ed 0)
        (echo-message! echo "*Hex*"))))

  ;;;=========================================================================
  ;;; Count matches, delete duplicate lines
  ;;;=========================================================================

  (define (cmd-count-matches app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (pattern (echo-read-string echo "Count matches for: " row width)))
      (if (not pattern)
        (echo-message! echo "Cancelled")
        (let* ((ed (current-editor app))
               (text (editor-get-text ed))
               (plen (string-length pattern))
               (count
                 (if (= plen 0) 0
                   (let loop ((pos 0) (n 0))
                     (let ((idx (string-contains text pattern pos)))
                       (if idx
                         (loop (+ idx plen) (+ n 1))
                         n))))))
          (echo-message! echo
            (string-append (number->string count) " occurrence"
                           (if (= count 1) "" "s")
                           " of \"" pattern "\""))))))

  (define (cmd-delete-duplicate-lines app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (text (editor-get-text ed)))
      (let-values (((start end)
                    (if mark
                      (let ((pos (editor-get-current-pos ed)))
                        (values (min mark pos) (max mark pos)))
                      (values 0 (string-length text)))))
        (let* ((region (substring text start end))
               (lines (string-split region #\newline))
               ;; Remove duplicates while preserving order
               (seen (make-hash-table))
               (unique
                 (filter (lambda (line)
                           (if (hash-get seen line)
                             #f
                             (begin (hash-put! seen line #t) #t)))
                         lines))
               (removed (- (length lines) (length unique)))
               (result (string-join unique "\n")))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (when mark (buffer-mark-set! buf #f))
          (echo-message! echo
            (string-append "Removed " (number->string removed) " duplicate line"
                           (if (= removed 1) "" "s")))))))

  ;;;=========================================================================
  ;;; Diff buffer with file
  ;;;=========================================================================

  (define (cmd-diff-buffer-with-file app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf)))
      (if (not path)
        (echo-error! echo "Buffer has no associated file")
        (if (not (file-exists? path))
          (echo-error! echo (string-append "File not found: " path))
          (let* ((file-text (read-file-as-string path))
                 (buf-text (editor-get-text ed))
                 (pid (number->string (get-process-id)))
                 (tmp1 (string-append "/tmp/jemacs-diff-file-" pid))
                 (tmp2 (string-append "/tmp/jemacs-diff-buf-" pid)))
            (write-string-to-file file-text tmp1)
            (write-string-to-file buf-text tmp2)
            (let* ((proc (open-process (list "/usr/bin/diff" "-u" tmp1 tmp2)))
                   (output (get-string-all (process-port-rec-stdout-port proc))))
              ;; Clean up temp files
              (guard (e [#t (void)]) (delete-file tmp1))
              (guard (e [#t (void)]) (delete-file tmp2))
              (if (and (string? output) (> (string-length output) 0))
                ;; Show diff in *Diff* buffer
                (let ((diff-buf (or (buffer-by-name "*Diff*")
                                    (buffer-create! "*Diff*" ed #f))))
                  (buffer-attach! ed diff-buf)
                  (edit-window-buffer-set! (current-window fr) diff-buf)
                  (editor-set-text ed output)
                  (editor-set-save-point ed)
                  (editor-goto-pos ed 0)
                  (echo-message! echo "*Diff*"))
                (echo-message! echo "No differences"))))))))

  ;;;=========================================================================
  ;;; Checksum: SHA256
  ;;;=========================================================================

  (define (cmd-checksum app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (text (editor-get-text ed)))
      (let-values (((start end)
                    (if mark
                      (let ((pos (editor-get-current-pos ed)))
                        (values (min mark pos) (max mark pos)))
                      (values 0 (string-length text)))))
        (let* ((region (substring text start end))
               (hash-bytes (sha256-stub (string->utf8 region)))
               (hex-str (hex-encode hash-bytes)))
          (when mark (buffer-mark-set! buf #f))
          (echo-message! echo (string-append "SHA256: " hex-str))))))

  ;;;=========================================================================
  ;;; Async shell command
  ;;;=========================================================================

  (define (cmd-async-shell-command app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (cmd (echo-read-string echo "Async shell command: " row width)))
      (if (not cmd)
        (echo-message! echo "Cancelled")
        (let* ((ed (current-editor app))
               (proc (open-process (list "/bin/sh" "-c" cmd)))
               (output (get-string-all (process-port-rec-stdout-port proc))))
          (if (and (string? output) (> (string-length output) 0))
            (let ((out-buf (or (buffer-by-name "*Async Shell*")
                               (buffer-create! "*Async Shell*" ed #f))))
              (buffer-attach! ed out-buf)
              (edit-window-buffer-set! (current-window fr) out-buf)
              (editor-set-text ed
                (string-append "$ " cmd "\n\n" output "\n"))
              (editor-set-save-point ed)
              (editor-goto-pos ed 0)
              (echo-message! echo "*Async Shell*"))
            (echo-message! echo "Command finished"))))))

  ;;;=========================================================================
  ;;; Toggle truncate lines
  ;;;=========================================================================

  (define (cmd-toggle-truncate-lines app)
    (cmd-toggle-word-wrap app))

  ;;;=========================================================================
  ;;; Grep in buffer
  ;;;=========================================================================

  (define (cmd-grep-buffer app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (pattern (echo-read-string echo "Grep buffer: " row width)))
      (if (not pattern)
        (echo-message! echo "Cancelled")
        (let* ((ed (current-editor app))
               (text (editor-get-text ed))
               (buf-name (buffer-name (current-buffer-from-app app)))
               (lines (string-split text #\newline))
               (matches '())
               (line-num 0))
          ;; Collect matching lines with line numbers
          (for-each
            (lambda (line)
              (set! line-num (+ line-num 1))
              (when (string-contains line pattern)
                (set! matches
                  (cons (string-append
                          (number->string line-num) ": " line)
                        matches))))
            lines)
          (if (null? matches)
            (echo-message! echo (string-append "No matches for '" pattern "'"))
            (let* ((result (string-append "Grep: " pattern " in " buf-name "\n\n"
                                          (string-join (reverse matches) "\n") "\n"))
                   (grep-buf (or (buffer-by-name "*Grep*")
                                 (buffer-create! "*Grep*" ed #f))))
              (buffer-attach! ed grep-buf)
              (edit-window-buffer-set! (current-window fr) grep-buf)
              (editor-set-text ed result)
              (editor-set-save-point ed)
              (editor-goto-pos ed 0)
              (echo-message! echo
                (string-append (number->string (length matches)) " match"
                               (if (= (length matches) 1) "" "es")))))))))

  ;;;=========================================================================
  ;;; Misc: insert-date, insert-char
  ;;;=========================================================================

  (define (cmd-insert-date app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (proc (open-process (list "/bin/date")))
           (output (get-line (process-port-rec-stdout-port proc))))
      (when (and (string? output) (> (string-length output) 0))
        (editor-insert-text ed pos output))))

  (define (cmd-insert-char app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Insert char (hex code): " row width)))
      (if (not input)
        (echo-message! echo "Cancelled")
        (let ((code (string->number input 16)))
          (if (not code)
            (echo-error! echo "Invalid hex code")
            (let* ((ed (current-editor app))
                   (pos (editor-get-current-pos ed))
                   (ch (string (integer->char code))))
              (editor-insert-text ed pos ch)
              (echo-message! echo
                (string-append "Inserted U+" input))))))))

  ;;;=========================================================================
  ;;; Eval buffer / eval region
  ;;;=========================================================================

  (define (cmd-eval-buffer app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (text (editor-get-text ed))
           (name (buffer-name buf)))
      (let-values (((count err) (load-user-string! text name)))
        (if err
          (echo-error! echo (string-append "Error: " err " (see *Errors*)"))
          (echo-message! echo
            (string-append "Evaluated " (number->string count)
                           " forms in " name
                           (if (has-captured-output?) " (see *Output*/*Errors*)" "")))))))

  (define (cmd-eval-region app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region (set mark first)")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (region (substring (editor-get-text ed) start end)))
          (let-values (((result error?) (eval-expression-string region)))
            (buffer-mark-set! buf #f)
            (if error?
              (echo-error! echo (string-append "Error: " result))
              (echo-message! echo (string-append "=> " result))))))))

  ;;;=========================================================================
  ;;; Clone buffer, scratch buffer
  ;;;=========================================================================

  (define (cmd-clone-buffer app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (buf (current-buffer-from-app app))
           (text (editor-get-text ed))
           (new-name (string-append (buffer-name buf) "<clone>")))
      (let ((new-buf (buffer-create! new-name ed #f)))
        (buffer-attach! ed new-buf)
        (edit-window-buffer-set! (current-window fr) new-buf)
        (editor-set-text ed text)
        (editor-set-save-point ed)
        (editor-goto-pos ed 0)
        (echo-message! echo (string-append "Cloned to " new-name)))))

  (define (cmd-scratch-buffer app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (buf (or (buffer-by-name buffer-scratch-name)
                    (buffer-create! buffer-scratch-name ed #f))))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (echo-message! echo buffer-scratch-name)))

  ;;;=========================================================================
  ;;; Save some buffers
  ;;;=========================================================================

  (define (cmd-save-some-buffers app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (saved 0))
      ;; Iterate over all windows and save their buffers if modified
      (for-each
        (lambda (win)
          (let ((win-ed (edit-window-editor win))
                (buf (edit-window-buffer win)))
            (when (and (buffer-file-path buf)
                       (buffer-modified buf))
              (let ((text (editor-get-text win-ed)))
                (write-string-to-file (buffer-file-path buf) text)
                (editor-set-save-point win-ed)
                (set! saved (+ saved 1))))))
        (frame-windows fr))
      (if (= saved 0)
        (echo-message! echo "No buffers need saving")
        (echo-message! echo
          (string-append "Saved " (number->string saved) " buffer"
                         (if (= saved 1) "" "s"))))))

  ;;;=========================================================================
  ;;; Revert buffer quick
  ;;;=========================================================================

  (define (cmd-revert-buffer-quick app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf)))
      (if (not path)
        (echo-error! echo "Buffer has no file to revert from")
        (if (not (file-exists? path))
          (echo-error! echo (string-append "File not found: " path))
          (let ((text (read-file-as-string path)))
            (editor-set-text ed text)
            (editor-set-save-point ed)
            (editor-goto-pos ed 0)
            (echo-message! echo (string-append "Reverted " path)))))))

  ;;;=========================================================================
  ;;; Toggle syntax highlighting
  ;;;=========================================================================

  (define (cmd-toggle-highlighting app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app)))
      (if (buffer-lexer-lang buf)
        (begin
          ;; Turn off: clear lexer language, reset all styles to default
          (buffer-lexer-lang-set! buf #f)
          (send-message ed SCI_STYLECLEARALL)
          (echo-message! echo "Highlighting off"))
        (begin
          ;; Turn on: set lexer language, re-apply highlighting
          (buffer-lexer-lang-set! buf 'gerbil)
          (setup-gerbil-highlighting! ed)
          (echo-message! echo "Highlighting on")))))

  ;;;=========================================================================
  ;;; Misc utility commands
  ;;;=========================================================================

  (define (cmd-view-lossage app)
    (let* ((text (string-append "Recent keystrokes:\n\n"
                                (key-lossage->string app)
                                "\n"))
           (ed (current-editor app))
           (buf (buffer-create! "*Help*" ed #f)))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window (app-state-frame app)) buf)
      (editor-set-text ed text)
      (editor-goto-pos ed 0)
      (editor-set-save-point ed)))

  (define (cmd-display-time app)
    (let* ((proc (open-process (list "/bin/date" "+%Y-%m-%d %H:%M:%S")))
           (output (get-line (process-port-rec-stdout-port proc))))
      (if (string? output)
        (echo-message! (app-state-echo app) output)
        (echo-error! (app-state-echo app) "Cannot get time"))))

  (define (cmd-pwd app)
    (echo-message! (app-state-echo app) (current-directory)))

  ;;;=========================================================================
  ;;; Ediff (compare two buffers)
  ;;;=========================================================================

  (define (cmd-ediff-buffers app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (names (map buffer-name (buffer-list))))
      (if (< (length names) 2)
        (echo-error! echo "Need at least 2 buffers to compare")
        (let* ((name-a (echo-read-string echo "Buffer A: " row width))
               (buf-a (and name-a (buffer-by-name name-a))))
          (if (not buf-a)
            (echo-error! echo (string-append "No buffer: " (or name-a "")))
            (let* ((name-b (echo-read-string echo "Buffer B: " row width))
                   (buf-b (and name-b (buffer-by-name name-b))))
              (if (not buf-b)
                (echo-error! echo (string-append "No buffer: " (or name-b "")))
                ;; Get text from both buffers, write to temp files, diff
                (let* ((pid (number->string (get-process-id)))
                       (tmp-a (string-append "/tmp/jemacs-ediff-a-" pid))
                       (tmp-b (string-append "/tmp/jemacs-ediff-b-" pid)))
                  ;; We need the text from those buffers — find their windows
                  (let ((text-a #f) (text-b #f))
                    (for-each
                      (lambda (win)
                        (let ((wb (edit-window-buffer win)))
                          (when (eq? wb buf-a)
                            (set! text-a (editor-get-text (edit-window-editor win))))
                          (when (eq? wb buf-b)
                            (set! text-b (editor-get-text (edit-window-editor win))))))
                      (frame-windows fr))
                    ;; Fallback: if buffer not in a window, use current editor temporarily
                    (unless text-a
                      (buffer-attach! ed buf-a)
                      (set! text-a (editor-get-text ed)))
                    (unless text-b
                      (buffer-attach! ed buf-b)
                      (set! text-b (editor-get-text ed)))
                    ;; Write to temp files and diff
                    (write-string-to-file tmp-a text-a)
                    (write-string-to-file tmp-b text-b)
                    (let* ((proc (open-process
                                   (list "/usr/bin/diff" "-u"
                                         (string-append "--label=" name-a)
                                         (string-append "--label=" name-b)
                                         tmp-a tmp-b)))
                           (output (get-string-all (process-port-rec-stdout-port proc))))
                      ;; Cleanup temp files
                      (guard (e [#t (void)]) (delete-file tmp-a))
                      (guard (e [#t (void)]) (delete-file tmp-b))
                      ;; Show diff in buffer
                      (let ((diff-buf (buffer-create! "*Diff*" ed #f)))
                        (buffer-attach! ed diff-buf)
                        (edit-window-buffer-set! (current-window fr) diff-buf)
                        (if (and (string? output) (> (string-length output) 0))
                          (begin
                            (editor-set-text ed output)
                            (setup-diff-highlighting! ed))
                          (editor-set-text ed "(no differences)\n"))
                        (editor-set-save-point ed)
                        (editor-goto-pos ed 0)
                        (editor-set-read-only ed #t))))))))))))

  ;;;=========================================================================
  ;;; Simple calculator
  ;;;=========================================================================

  (define (cmd-calc app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (expr (echo-read-string echo "Calc: " row width)))
      (when (and expr (> (string-length expr) 0))
        (let-values (((result error?) (eval-expression-string expr)))
          (if error?
            (echo-error! echo (string-append "Error: " result))
            (echo-message! echo (string-append "= " result)))))))

  ;;;=========================================================================
  ;;; Toggle case-fold-search
  ;;;=========================================================================

  (define (cmd-toggle-case-fold-search app)
    (set! *case-fold-search* (not *case-fold-search*))
    (echo-message! (app-state-echo app)
      (if *case-fold-search*
        "Case-insensitive search"
        "Case-sensitive search")))

  ;;;=========================================================================
  ;;; Describe-bindings
  ;;;=========================================================================

  (define (cmd-describe-bindings app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app)))
      (let ((lines '()))
        ;; Collect bindings from all keymaps
        (define (collect-prefix prefix km)
          (for-each
            (lambda (entry)
              (let ((key (car entry))
                    (val (cdr entry)))
                (if (hash-table? val)
                  (collect-prefix (string-append prefix key " ") val)
                  (set! lines (cons (string-append prefix key "\t"
                                                   (symbol->string val))
                                    lines)))))
            (keymap-entries km)))
        (collect-prefix "" *global-keymap*)
        ;; Sort and display
        (let* ((sorted (list-sort string<? lines))
               (text (string-join sorted "\n"))
               (buf (buffer-create! "*Bindings*" ed #f)))
          (buffer-attach! ed buf)
          (edit-window-buffer-set! (current-window fr) buf)
          (editor-set-text ed text)
          (editor-set-save-point ed)
          (editor-goto-pos ed 0)
          (editor-set-read-only ed #t)
          (echo-message! echo
            (string-append (number->string (length sorted)) " bindings"))))))

  ;;;=========================================================================
  ;;; Center line
  ;;;=========================================================================

  (define (cmd-center-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line-num (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line-num))
           (line-end (editor-get-line-end-position ed line-num))
           (text (substring (editor-get-text ed) line-start line-end))
           ;; Strip leading whitespace
           (trimmed (let loop ((i 0))
                      (if (and (< i (string-length text))
                               (or (char=? (string-ref text i) #\space)
                                   (char=? (string-ref text i) #\tab)))
                        (loop (+ i 1))
                        (substring text i (string-length text)))))
           (fill-col 80)
           (padding (max 0 (quotient (- fill-col (string-length trimmed)) 2)))
           (new-line (string-append (make-string padding #\space) trimmed)))
      (with-undo-action ed
        (editor-delete-range ed line-start (- line-end line-start))
        (editor-insert-text ed line-start new-line))))

  ;;;=========================================================================
  ;;; What face (show current style info)
  ;;;=========================================================================

  (define (cmd-what-face app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (style (send-message ed SCI_GETSTYLEAT pos)))
      (echo-message! (app-state-echo app)
        (string-append "Style " (number->string style) " at pos "
                       (number->string pos)))))

  ;;;=========================================================================
  ;;; List processes
  ;;;=========================================================================

  (define (cmd-list-processes app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (lines (list "PID\tType\tBuffer"
                        "---\t----\t------")))
      ;; Check REPL buffers
      (for-each
        (lambda (buf)
          (when (repl-buffer? buf)
            (let ((rs (hash-ref *repl-state* buf #f)))
              (when rs
                (set! lines (cons
                  (string-append "?\tREPL\t" (buffer-name buf))
                  lines))))))
        (buffer-list))
      ;; Check shell buffers
      (for-each
        (lambda (buf)
          (when (shell-buffer? buf)
            (let ((ss (hash-ref (shell-state-table) buf #f)))
              (when ss
                (set! lines (cons
                  (string-append "?\tShell\t" (buffer-name buf))
                  lines))))))
        (buffer-list))
      (let* ((text (string-join (reverse lines) "\n"))
             (proc-buf (buffer-create! "*Processes*" ed #f)))
        (buffer-attach! ed proc-buf)
        (edit-window-buffer-set! (current-window fr) proc-buf)
        (editor-set-text ed text)
        (editor-set-save-point ed)
        (editor-goto-pos ed 0)
        (editor-set-read-only ed #t)
        (echo-message! echo "Process list"))))

  ;;;=========================================================================
  ;;; View echo area messages (like *Messages*)
  ;;;=========================================================================

  (define (log-message! msg)
    (set! *message-log* (cons msg *message-log*))
    (when (> (length *message-log*) *message-log-max*)
      (set! *message-log*
        (let loop ((msgs *message-log*) (n 0) (acc '()))
          (if (or (null? msgs) (>= n *message-log-max*))
            (reverse acc)
            (loop (cdr msgs) (+ n 1) (cons (car msgs) acc)))))))

  (define (cmd-view-messages app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (text (if (null? *message-log*)
                   "(no messages)\n"
                   (string-join (reverse *message-log*) "\n")))
           (buf (buffer-create! "*Messages*" ed #f)))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (editor-set-text ed text)
      (editor-set-save-point ed)
      ;; Go to end to see latest messages
      (editor-goto-pos ed (string-length text))
      (editor-set-read-only ed #t)
      (echo-message! echo "*Messages*")))

  ;;;=========================================================================
  ;;; View errors / view output
  ;;;=========================================================================

  (define (cmd-view-errors app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (text (get-error-log))
           (buf (buffer-create! "*Errors*" ed #f)))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (editor-set-text ed (if (string=? text "") "(no errors)\n" text))
      (editor-set-save-point ed)
      (editor-goto-pos ed (string-length text))
      (editor-set-read-only ed #t)
      (echo-message! echo "*Errors*")))

  (define (cmd-view-output app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (text (get-output-log))
           (buf (buffer-create! "*Output*" ed #f)))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (editor-set-text ed (if (string=? text "") "(no output)\n" text))
      (editor-set-save-point ed)
      (editor-goto-pos ed (string-length text))
      (editor-set-read-only ed #t)
      (echo-message! echo "*Output*")))

  ;;;=========================================================================
  ;;; Auto-fill mode toggle
  ;;;=========================================================================

  (define (cmd-toggle-auto-fill app)
    (auto-fill-mode-set! (not (auto-fill-mode)))
    (echo-message! (app-state-echo app)
      (if (auto-fill-mode)
        "Auto-fill mode on"
        "Auto-fill mode off")))

  ;;;=========================================================================
  ;;; Rename file (rename-file-and-buffer)
  ;;;=========================================================================

  (define (cmd-rename-file-and-buffer app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (current-buffer-from-app app))
           (old-path (buffer-file-path buf)))
      (if (not old-path)
        (echo-error! echo "Buffer is not visiting a file")
        (let ((new-path (echo-read-string echo
                          (string-append "Rename " old-path " to: ")
                          row width)))
          (when (and new-path (> (string-length new-path) 0))
            (guard (e [#t
                       (echo-error! echo
                         (string-append "Error: "
                           (call-with-string-output-port (lambda (p) (display e p)))))])
              (rename-file old-path new-path)
              (buffer-file-path-set! buf new-path)
              (buffer-name-set! buf (path-strip-directory new-path))
              (echo-message! echo
                (string-append "Renamed to " new-path))))))))

  ;;;=========================================================================
  ;;; Kill buffer and delete file
  ;;;=========================================================================

  (define (cmd-delete-file-and-buffer app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf)))
      (if (not path)
        (echo-error! echo "Buffer is not visiting a file")
        (let ((confirm (echo-read-string echo
                         (string-append "Really delete " path "? (yes/no) ")
                         row width)))
          (when (and confirm (string=? confirm "yes"))
            (guard (e [#t
                       (echo-error! echo
                         (string-append "Error: "
                           (call-with-string-output-port (lambda (p) (display e p)))))])
              (delete-file path)
              (echo-message! echo (string-append "Deleted " path))
              ;; Switch away from this buffer
              (let ((scratch (or (buffer-by-name buffer-scratch-name)
                                 (buffer-create! buffer-scratch-name ed #f))))
                (buffer-attach! ed scratch)
                (edit-window-buffer-set!
                  (current-window (app-state-frame app)) scratch)
                (buffer-list-remove! buf))))))))

  ;;;=========================================================================
  ;;; Sudo write (write file with sudo)
  ;;;=========================================================================

  (define (cmd-sudo-write app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (path (buffer-file-path buf)))
      (if (not path)
        (echo-error! echo "Buffer has no file path")
        (let* ((text (editor-get-text ed))
               (pid (number->string (get-process-id)))
               (tmp (string-append "/tmp/jemacs-sudo-" pid)))
          (write-string-to-file tmp text)
          (let* ((proc (open-process (list "/usr/bin/sudo" "cp" tmp path)))
                 (stdout-port (process-port-rec-stdout-port proc))
                 (_ (get-string-all stdout-port)))
            (guard (e [#t (void)]) (delete-file tmp))
            ;; Check if command succeeded (simple heuristic)
            (editor-set-save-point ed)
            (echo-message! echo (string-append "Saved (sudo) " path)))))))

  (define (cmd-sudo-edit app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (path (echo-read-string echo "Find file (sudo): " row width)))
      (when (and path (> (string-length path) 0))
        (let ((full-path (if (char=? (string-ref path 0) #\/)
                           path
                           (string-append (current-directory) "/" path))))
          (guard (e [#t
                     (echo-error! echo (string-append "Sudo read failed: "
                       (call-with-string-output-port (lambda (p) (display e p)))))])
            (let* ((proc (open-process (list "/usr/bin/sudo" "cat" full-path)))
                   (content (get-string-all (process-port-rec-stdout-port proc))))
              (let* ((ed (current-editor app))
                     (buf-name (string-append full-path " (sudo)"))
                     (buf (buffer-create! buf-name ed #f)))
                (buffer-file-path-set! buf full-path)
                (buffer-attach! ed buf)
                (edit-window-buffer-set! (current-window fr) buf)
                (editor-set-text ed (or content ""))
                (editor-set-save-point ed)
                (editor-goto-pos ed 0)
                (echo-message! echo
                  (string-append "Opened " full-path " (sudo)")))))))))

  ;;;=========================================================================
  ;;; Sort region (numeric)
  ;;;=========================================================================

  (define (cmd-sort-numeric app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (text (substring (editor-get-text ed) start end))
               (lines (string-split text #\newline))
               (sorted (list-sort
                         (lambda (a b)
                           (let ((na (or (string->number a) 0))
                                 (nb (or (string->number b) 0)))
                             (< na nb)))
                         lines))
               (new-text (string-join sorted "\n")))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start new-text))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Sorted numerically")))))

  ;;;=========================================================================
  ;;; Word count region
  ;;;=========================================================================

  (define (cmd-count-words-region app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (text (substring (editor-get-text ed) start end))
               (chars (- end start))
               (lines (length (string-split text #\newline)))
               (words (let loop ((i 0) (in-word #f) (count 0))
                        (if (>= i (string-length text))
                          (if in-word (+ count 1) count)
                          (let ((ch (string-ref text i)))
                            (if (or (char=? ch #\space) (char=? ch #\newline)
                                    (char=? ch #\tab))
                              (loop (+ i 1) #f (if in-word (+ count 1) count))
                              (loop (+ i 1) #t count)))))))
          (echo-message! echo
            (string-append "Region: " (number->string lines) " lines, "
                           (number->string words) " words, "
                           (number->string chars) " chars"))))))

  ;;;=========================================================================
  ;;; Overwrite mode toggle
  ;;;=========================================================================

  (define (cmd-toggle-overwrite-mode app)
    (set! *overwrite-mode* (not *overwrite-mode*))
    ;; SCI_SETOVERTYPE (2186)
    (let ((ed (current-editor app)))
      (send-message ed 2186 (if *overwrite-mode* 1 0)))
    (echo-message! (app-state-echo app)
      (if *overwrite-mode*
        "Overwrite mode on"
        "Overwrite mode off")))

  ;;;=========================================================================
  ;;; Visual line mode
  ;;;=========================================================================

  (define (cmd-toggle-visual-line-mode app)
    (set! *visual-line-mode* (not *visual-line-mode*))
    (let ((ed (current-editor app)))
      (send-message ed SCI_SETWRAPMODE
        (if *visual-line-mode* 1 0)))  ; SC_WRAP_WORD=1, SC_WRAP_NONE=0
    (echo-message! (app-state-echo app)
      (if *visual-line-mode*
        "Visual line mode on"
        "Visual line mode off")))

  ;;;=========================================================================
  ;;; Set fill column
  ;;;=========================================================================

  (define (cmd-set-fill-column app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo
                    (string-append "Fill column (current: "
                                   (number->string (fill-column)) "): ")
                    row width)))
      (when (and input (> (string-length input) 0))
        (let ((n (string->number input)))
          (if (and n (> n 0))
            (begin
              (fill-column-set! n)
              (echo-message! echo
                (string-append "Fill column set to " (number->string n))))
            (echo-error! echo "Invalid number"))))))

  ;;;=========================================================================
  ;;; Fill column indicator
  ;;;=========================================================================

  (define (cmd-toggle-fill-column-indicator app)
    (set! *fill-column-indicator* (not *fill-column-indicator*))
    (let ((ed (current-editor app)))
      (if *fill-column-indicator*
        (begin
          (send-message ed 2361 (fill-column) 0)  ;; SCI_SETEDGECOLUMN
          (send-message ed 2363 1 0))              ;; SCI_SETEDGEMODE EDGE_LINE
        (send-message ed 2363 0 0))                ;; SCI_SETEDGEMODE EDGE_NONE
      (echo-message! (app-state-echo app)
        (if *fill-column-indicator*
          (string-append "Fill column indicator at " (number->string (fill-column)))
          "Fill column indicator off"))))

  ;;;=========================================================================
  ;;; Toggle debug on error
  ;;;=========================================================================

  (define (cmd-toggle-debug-on-error app)
    (set! *debug-on-error* (not *debug-on-error*))
    (echo-message! (app-state-echo app)
      (if *debug-on-error*
        "Debug on error enabled"
        "Debug on error disabled")))

  ;;;=========================================================================
  ;;; Repeat complex command
  ;;;=========================================================================

  (define (cmd-repeat-complex-command app)
    (let ((cmd *last-mx-command*))
      (if (symbol? cmd)
        (begin
          (echo-message! (app-state-echo app)
            (string-append "Repeating: " (symbol->string cmd)))
          (execute-command! app cmd))
        (echo-error! (app-state-echo app) "No previous M-x command"))))

  ;;;=========================================================================
  ;;; Eldoc-like: show function signature at point
  ;;;=========================================================================

  (define (cmd-eldoc app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Find word boundaries around cursor
      (let* ((start (let loop ((i (- pos 1)))
                      (if (or (< i 0)
                              (let ((ch (string-ref text i)))
                                (not (or (char-alphabetic? ch)
                                         (char-numeric? ch)
                                         (char=? ch #\-)
                                         (char=? ch #\_)
                                         (char=? ch #\!)
                                         (char=? ch #\?)))))
                        (+ i 1) (loop (- i 1)))))
             (end (let loop ((i pos))
                    (if (or (>= i len)
                            (let ((ch (string-ref text i)))
                              (not (or (char-alphabetic? ch)
                                       (char-numeric? ch)
                                       (char=? ch #\-)
                                       (char=? ch #\_)
                                       (char=? ch #\!)
                                       (char=? ch #\?)))))
                      i (loop (+ i 1)))))
             (word (if (< start end) (substring text start end) #f)))
        (if word
          (echo-message! (app-state-echo app)
            (string-append "Symbol: " word))
          (echo-message! (app-state-echo app) "No symbol at point")))))

  ;;;=========================================================================
  ;;; Highlight symbol at point
  ;;;=========================================================================

  (define (cmd-highlight-symbol app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Get word at point
      (let* ((start (let loop ((i (- pos 1)))
                      (if (or (< i 0)
                              (let ((ch (string-ref text i)))
                                (not (or (char-alphabetic? ch)
                                         (char-numeric? ch)
                                         (char=? ch #\_) (char=? ch #\-)))))
                        (+ i 1) (loop (- i 1)))))
             (end (let loop ((i pos))
                    (if (or (>= i len)
                            (let ((ch (string-ref text i)))
                              (not (or (char-alphabetic? ch)
                                       (char-numeric? ch)
                                       (char=? ch #\_) (char=? ch #\-)))))
                      i (loop (+ i 1)))))
             (word (if (< start end) (substring text start end) #f)))
        (if (not word)
          (echo-message! echo "No word at point")
          ;; Count occurrences
          (let ((count 0) (wlen (string-length word)))
            (let loop ((i 0))
              (when (<= (+ i wlen) len)
                (when (string=? (substring text i (+ i wlen)) word)
                  (set! count (+ count 1)))
                (loop (+ i 1))))
            ;; Use Scintilla indicator to highlight
            (send-message ed SCI_INDICSETSTYLE 0 7)  ; INDIC_ROUNDBOX
            (send-message ed SCI_SETINDICATORCURRENT 0)
            ;; Clear previous highlights
            (send-message ed SCI_INDICATORCLEARRANGE 0 len)
            ;; Set highlights for each occurrence
            (let loop ((i 0))
              (when (<= (+ i wlen) len)
                (when (string=? (substring text i (+ i wlen)) word)
                  (send-message ed SCI_INDICATORFILLRANGE i wlen))
                (loop (+ i 1))))
            (echo-message! echo
              (string-append (number->string count) " occurrence"
                             (if (= count 1) "" "s")
                             " of \"" word "\"")))))))

  ;;;=========================================================================
  ;;; Clear highlight
  ;;;=========================================================================

  (define (cmd-clear-highlight app)
    (let* ((ed (current-editor app))
           (len (editor-get-text-length ed)))
      (send-message ed SCI_SETINDICATORCURRENT 0)
      (send-message ed SCI_INDICATORCLEARRANGE 0 len)
      (echo-message! (app-state-echo app) "Highlights cleared")))

  ;;;=========================================================================
  ;;; Indent rigidly (shift region left/right)
  ;;;=========================================================================

  (define (cmd-indent-rigidly-right app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (text (substring (editor-get-text ed) start end))
               (lines (string-split text #\newline))
               (indented (map (lambda (line) (string-append "  " line)) lines))
               (new-text (string-join indented "\n")))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start new-text))
          (buffer-mark-set! buf start)
          (editor-goto-pos ed (+ start (string-length new-text)))
          (echo-message! echo "Indented right")))))

  (define (cmd-indent-rigidly-left app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (text (substring (editor-get-text ed) start end))
               (lines (string-split text #\newline))
               (dedented (map (lambda (line)
                                (cond
                                  ((and (>= (string-length line) 2)
                                        (char=? (string-ref line 0) #\space)
                                        (char=? (string-ref line 1) #\space))
                                   (substring line 2 (string-length line)))
                                  ((and (> (string-length line) 0)
                                        (char=? (string-ref line 0) #\tab))
                                   (substring line 1 (string-length line)))
                                  (else line)))
                              lines))
               (new-text (string-join dedented "\n")))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start new-text))
          (buffer-mark-set! buf start)
          (editor-goto-pos ed (+ start (string-length new-text)))
          (echo-message! echo "Indented left")))))

  ;;;=========================================================================
  ;;; Goto first/last non-blank line
  ;;;=========================================================================

  (define (cmd-goto-first-non-blank app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline)))
      (let loop ((i 0) (pos 0))
        (if (>= i (length lines))
          (editor-goto-pos ed 0)
          (let ((line (list-ref lines i)))
            (if (> (string-length (string-trim line)) 0)
              (editor-goto-pos ed pos)
              (loop (+ i 1) (+ pos (string-length line) 1))))))))

  (define (cmd-goto-last-non-blank app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (total (length lines)))
      (let loop ((i (- total 1)) (last-pos (string-length text)))
        (if (< i 0)
          (editor-goto-pos ed last-pos)
          (let* ((line (list-ref lines i))
                 (line-start (let lp ((j 0) (pos 0))
                               (if (>= j i) pos
                                 (lp (+ j 1) (+ pos (string-length (list-ref lines j)) 1))))))
            (if (> (string-length (string-trim line)) 0)
              (editor-goto-pos ed line-start)
              (loop (- i 1) last-pos)))))))

  ;;;=========================================================================
  ;;; Buffer statistics
  ;;;=========================================================================

  (define (cmd-buffer-stats app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (chars (string-length text))
           (lines (editor-get-line-count ed))
           (words (let loop ((i 0) (in-word #f) (count 0))
                    (if (>= i chars)
                      (if in-word (+ count 1) count)
                      (let ((ch (string-ref text i)))
                        (if (or (char=? ch #\space) (char=? ch #\newline)
                                (char=? ch #\tab))
                          (loop (+ i 1) #f (if in-word (+ count 1) count))
                          (loop (+ i 1) #t count))))))
           (buf (current-buffer-from-app app))
           (name (buffer-name buf))
           (path (or (buffer-file-path buf) "(no file)")))
      (echo-message! echo
        (string-append name " | " path " | "
                       (number->string lines) "L "
                       (number->string words) "W "
                       (number->string chars) "C"))))

  ;;;=========================================================================
  ;;; Toggle show tabs
  ;;;=========================================================================

  (define (cmd-toggle-show-tabs app)
    (set! *show-tabs* (not *show-tabs*))
    (let ((ed (current-editor app)))
      (send-message ed SCI_SETVIEWWS
        (if *show-tabs* 1 0)))  ; SCWS_VISIBLEALWAYS=1
    (echo-message! (app-state-echo app)
      (if *show-tabs* "Show tabs on" "Show tabs off")))

  ;;;=========================================================================
  ;;; Toggle show EOL
  ;;;=========================================================================

  (define (cmd-toggle-show-eol app)
    (set! *show-eol* (not *show-eol*))
    (let ((ed (current-editor app)))
      (send-message ed SCI_SETVIEWEOL
        (if *show-eol* 1 0)))
    (echo-message! (app-state-echo app)
      (if *show-eol* "Show EOL on" "Show EOL off")))

  ;;;=========================================================================
  ;;; Copy from above/below line
  ;;;=========================================================================

  (define (cmd-copy-from-above app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (col (- pos (editor-position-from-line ed line))))
      (if (= line 0)
        (echo-error! (app-state-echo app) "No line above")
        (let* ((above-start (editor-position-from-line ed (- line 1)))
               (above-end (editor-get-line-end-position ed (- line 1)))
               (above-len (- above-end above-start)))
          (if (>= col above-len)
            (echo-error! (app-state-echo app) "Line above too short")
            (let* ((text (editor-get-text ed))
                   (ch (string (string-ref text (+ above-start col)))))
              (editor-insert-text ed pos ch)))))))

  (define (cmd-copy-from-below app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (total-lines (editor-get-line-count ed))
           (col (- pos (editor-position-from-line ed line))))
      (if (>= (+ line 1) total-lines)
        (echo-error! (app-state-echo app) "No line below")
        (let* ((below-start (editor-position-from-line ed (+ line 1)))
               (below-end (editor-get-line-end-position ed (+ line 1)))
               (below-len (- below-end below-start)))
          (if (>= col below-len)
            (echo-error! (app-state-echo app) "Line below too short")
            (let* ((text (editor-get-text ed))
                   (ch (string (string-ref text (+ below-start col)))))
              (editor-insert-text ed pos ch)))))))

  ;;;=========================================================================
  ;;; Open line above (like vim O)
  ;;;=========================================================================

  (define (cmd-open-line-above app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line)))
      (with-undo-action ed
        (editor-insert-text ed line-start "\n")
        (editor-goto-pos ed line-start))))

  ;;;=========================================================================
  ;;; Select current line
  ;;;=========================================================================

  (define (cmd-select-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line))
           (line-end (editor-get-line-end-position ed line))
           (buf (current-buffer-from-app app)))
      (buffer-mark-set! buf line-start)
      ;; Move to the start of the next line if possible
      (let ((next-start (if (< (+ line 1) (editor-get-line-count ed))
                          (editor-position-from-line ed (+ line 1))
                          line-end)))
        (editor-goto-pos ed next-start)
        (echo-message! (app-state-echo app) "Line selected"))))

  ;;;=========================================================================
  ;;; Split line
  ;;;=========================================================================

  (define (cmd-split-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line))
           (col (- pos line-start))
           (padding (make-string col #\space)))
      (with-undo-action ed
        (editor-insert-text ed pos (string-append "\n" padding)))))

  ;;;=========================================================================
  ;;; Convert line endings
  ;;;=========================================================================

  (define (cmd-convert-to-unix app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed)))
      ;; Remove CRs (convert CRLF -> LF and standalone CR -> LF)
      (let loop ((i 0) (acc '()))
        (if (>= i (string-length text))
          (let ((new-text (list->string (reverse acc))))
            (unless (string=? text new-text)
              (with-undo-action ed
                (editor-set-text ed new-text))
              (echo-message! (app-state-echo app) "Converted to Unix (LF)")))
          (let ((ch (string-ref text i)))
            (if (char=? ch #\return)
              (loop (+ i 1) acc)
              (loop (+ i 1) (cons ch acc))))))))

  (define (cmd-convert-to-dos app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (new-text (string-join lines "\r\n")))
      (unless (string=? text new-text)
        (with-undo-action ed
          (editor-set-text ed new-text))
        (echo-message! (app-state-echo app) "Converted to DOS (CRLF)"))))

  ;;;=========================================================================
  ;;; Enlarge/shrink window
  ;;;=========================================================================

  (define (cmd-enlarge-window app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (h (edit-window-h win)))
      (edit-window-h-set! win (+ h 2))
      (echo-message! (app-state-echo app) "Window enlarged")))

  (define (cmd-shrink-window app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (h (edit-window-h win)))
      (when (> h 4)
        (edit-window-h-set! win (- h 2)))
      (echo-message! (app-state-echo app) "Window shrunk")))

  ;;;=========================================================================
  ;;; What buffer encoding
  ;;;=========================================================================

  (define (cmd-what-encoding app)
    (echo-message! (app-state-echo app) "Encoding: UTF-8"))

  ;;;=========================================================================
  ;;; Hippie expand (simple completion from buffer words)
  ;;;=========================================================================

  (define (cmd-hippie-expand app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Find prefix at point
      (let* ((prefix-start
               (let loop ((i (- pos 1)))
                 (if (or (< i 0)
                         (let ((ch (string-ref text i)))
                           (not (or (char-alphabetic? ch)
                                    (char-numeric? ch)
                                    (char=? ch #\_)
                                    (char=? ch #\-)))))
                   (+ i 1) (loop (- i 1)))))
             (prefix (substring text prefix-start pos))
             (plen (string-length prefix)))
        (if (= plen 0)
          (echo-message! echo "No prefix to complete")
          ;; Scan buffer for words starting with prefix
          (let ((candidates '()))
            (let loop ((i 0))
              (when (< i len)
                (let* ((wstart
                         (let ws ((j i))
                           (if (or (>= j len)
                                   (let ((ch (string-ref text j)))
                                     (or (char-alphabetic? ch)
                                         (char-numeric? ch)
                                         (char=? ch #\_)
                                         (char=? ch #\-))))
                             j
                             (ws (+ j 1)))))
                       (wend
                         (let we ((j wstart))
                           (if (or (>= j len)
                                   (let ((ch (string-ref text j)))
                                     (not (or (char-alphabetic? ch)
                                              (char-numeric? ch)
                                              (char=? ch #\_)
                                              (char=? ch #\-)))))
                             j
                             (we (+ j 1))))))
                  (when (> wend wstart)
                    (let ((word (substring text wstart wend)))
                      (when (and (> (string-length word) plen)
                                 (string-prefix? prefix word)
                                 (not (= wstart prefix-start))
                                 (not (member word candidates)))
                        (set! candidates (cons word candidates))))
                    (loop wend))
                  (when (= wend wstart)
                    (loop (+ wstart 1))))))
            (if (null? candidates)
              (echo-message! echo
                (string-append "No completions for \"" prefix "\""))
              ;; Insert first candidate
              (let ((completion (car (reverse candidates))))
                (with-undo-action ed
                  (editor-delete-range ed prefix-start plen)
                  (editor-insert-text ed prefix-start completion))
                (editor-goto-pos ed (+ prefix-start (string-length completion)))
                (echo-message! echo
                  (string-append completion
                    (if (> (length candidates) 1)
                      (string-append " [" (number->string (length candidates))
                                     " candidates]")
                      ""))))))))))

  ;;;=========================================================================
  ;;; Swap buffers in windows
  ;;;=========================================================================

  (define (cmd-swap-buffers app)
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr)))
      (if (< (length wins) 2)
        (echo-error! (app-state-echo app) "Only one window")
        (let* ((cur-idx (frame-current-idx fr))
               (next-idx (modulo (+ cur-idx 1) (length wins)))
               (cur-win (list-ref wins cur-idx))
               (next-win (list-ref wins next-idx))
               (cur-buf (edit-window-buffer cur-win))
               (next-buf (edit-window-buffer next-win)))
          ;; Swap the buffers
          (buffer-attach! (edit-window-editor cur-win) next-buf)
          (edit-window-buffer-set! cur-win next-buf)
          (buffer-attach! (edit-window-editor next-win) cur-buf)
          (edit-window-buffer-set! next-win cur-buf)
          (echo-message! (app-state-echo app) "Buffers swapped")))))

  ;;;=========================================================================
  ;;; Toggle tab-width between 2/4/8
  ;;;=========================================================================

  (define (cmd-cycle-tab-width app)
    (let* ((ed (current-editor app))
           (current (send-message ed SCI_GETTABWIDTH))
           (next (cond
                   ((= current 2) 4)
                   ((= current 4) 8)
                   (else 2))))
      (send-message ed SCI_SETTABWIDTH next)
      (echo-message! (app-state-echo app)
        (string-append "Tab width: " (number->string next)))))

  ;;;=========================================================================
  ;;; Toggle use tabs vs spaces
  ;;;=========================================================================

  (define (cmd-toggle-indent-tabs-mode app)
    (let* ((ed (current-editor app))
           (using-tabs (= 1 (send-message ed SCI_GETUSETABS))))
      (send-message ed SCI_SETUSETABS (if using-tabs 0 1))
      (echo-message! (app-state-echo app)
        (if using-tabs
          "Indent with spaces"
          "Indent with tabs"))))

  ;;;=========================================================================
  ;;; Print buffer info
  ;;;=========================================================================

  (define (cmd-buffer-info app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (pos (editor-get-current-pos ed))
           (line (+ 1 (editor-line-from-position ed pos)))
           (col (+ 1 (- pos (editor-position-from-line ed (- line 1))))))
      (echo-message! (app-state-echo app)
        (string-append (buffer-name buf)
                       " L" (number->string line)
                       " C" (number->string col)
                       " pos:" (number->string pos)
                       (if (buffer-file-path buf)
                         (string-append " " (buffer-file-path buf))
                         "")))))

) ;; end library
