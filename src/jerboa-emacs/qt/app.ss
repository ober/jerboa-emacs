;;; -*- Gerbil -*-
;;; Qt application and event loop for jemacs

(export qt-main qt-open-file! qt-do-init!)

(import :std/sugar
        :std/misc/string
        :chez-scintilla/constants
        :jerboa-emacs/qt/sci-shim
        ;; Import chez-qt directly for window/menu/toolbar functions not re-exported by sci-shim.
        ;; Exclude the sci-shim-handled variants to avoid duplicate identifier errors.
        ;; Note: qt-on-plain-text-edit-text-changed! and qt-extra-selections-* are
        ;; NOT in chez-qt — they are defined locally in sci-shim, so don't exclude them.
        (except-in :chez-qt/qt
                   ;; Exclude Qt constants re-exported by sci-shim (avoid duplicate identifier)
                   QT_MOD_NONE QT_MOD_SHIFT QT_MOD_CONTROL QT_MOD_ALT QT_MOD_META
                   QT_KEY_ESCAPE QT_KEY_BACKSPACE QT_KEY_RETURN QT_KEY_ENTER QT_KEY_DELETE
                   QT_KEY_TAB QT_KEY_BACKTAB QT_KEY_INSERT QT_KEY_HOME QT_KEY_END
                   QT_KEY_LEFT QT_KEY_RIGHT QT_KEY_UP QT_KEY_DOWN
                   QT_KEY_PAGE_UP QT_KEY_PAGE_DOWN QT_KEY_SPACE
                   QT_KEY_F1 QT_KEY_F2 QT_KEY_F3 QT_KEY_F4 QT_KEY_F5 QT_KEY_F6
                   QT_KEY_F7 QT_KEY_F8 QT_KEY_F9 QT_KEY_F10 QT_KEY_F11 QT_KEY_F12
                   QT_CURSOR_UP QT_CURSOR_DOWN QT_CURSOR_START QT_CURSOR_END
                   QT_CURSOR_START_OF_BLOCK QT_CURSOR_END_OF_BLOCK
                   QT_CURSOR_NEXT_CHAR QT_CURSOR_NEXT_WORD
                   QT_CURSOR_PREVIOUS_CHAR QT_CURSOR_PREVIOUS_WORD
                   qt-plain-text-edit-create qt-plain-text-edit-set-text!
                   qt-plain-text-edit-text qt-plain-text-edit-append!
                   qt-plain-text-edit-clear! qt-plain-text-edit-set-read-only!
                   qt-plain-text-edit-read-only? qt-plain-text-edit-set-placeholder!
                   qt-plain-text-edit-line-count qt-plain-text-edit-set-max-block-count!
                   qt-plain-text-edit-cursor-line qt-plain-text-edit-cursor-column
                   qt-plain-text-edit-set-line-wrap!
                   qt-plain-text-edit-cursor-position qt-plain-text-edit-set-cursor-position!
                   qt-plain-text-edit-move-cursor! qt-plain-text-edit-select-all!
                   qt-plain-text-edit-selected-text qt-plain-text-edit-selection-start
                   qt-plain-text-edit-selection-end qt-plain-text-edit-set-selection!
                   qt-plain-text-edit-has-selection? qt-plain-text-edit-insert-text!
                   qt-plain-text-edit-remove-selected-text!
                   qt-plain-text-edit-undo! qt-plain-text-edit-redo!
                   qt-plain-text-edit-can-undo? qt-plain-text-edit-cut!
                   qt-plain-text-edit-copy! qt-plain-text-edit-paste!
                   qt-plain-text-edit-text-length qt-plain-text-edit-text-range
                   qt-plain-text-edit-line-from-position qt-plain-text-edit-line-end-position
                   qt-plain-text-edit-find-text
                   qt-plain-text-edit-ensure-cursor-visible! qt-plain-text-edit-center-cursor!
                   qt-text-document-create qt-plain-text-document-create
                   qt-text-document-destroy!
                   qt-plain-text-edit-document qt-plain-text-edit-set-document!
                   qt-text-document-modified? qt-text-document-set-modified!
                   qt-syntax-highlighter-create qt-syntax-highlighter-destroy!
                   qt-syntax-highlighter-add-rule! qt-syntax-highlighter-add-keywords!
                   qt-syntax-highlighter-add-multiline-rule!
                   qt-syntax-highlighter-clear-rules! qt-syntax-highlighter-rehighlight!
                   qt-line-number-area-create qt-line-number-area-destroy!
                   qt-line-number-area-set-visible!
                   qt-line-number-area-set-bg-color! qt-line-number-area-set-fg-color!)
        :jerboa-emacs/core
        :jerboa-emacs/async
        :jerboa-emacs/editor
        (only-in :jerboa-emacs/persist init-file-load!
                 detect-major-mode buffer-local-set!
                 theme-settings-load! custom-faces-load!
                 *which-key-mode* *which-key-delay*
                 *abbrev-mode-enabled* *abbrev-table*)
        :jerboa-emacs/repl
        :jerboa-emacs/eshell
        (only-in :jerboa-emacs/gsh-eshell gsh-eshell-buffer?)
        :jerboa-emacs/shell
        :jerboa-emacs/shell-history
        :jerboa-emacs/terminal
        :jerboa-emacs/chat
        :jerboa-emacs/qt/keymap
        :jerboa-emacs/qt/buffer
        :jerboa-emacs/qt/window
        :jerboa-emacs/qt/modeline
        :jerboa-emacs/qt/echo
        :jerboa-emacs/qt/highlight
        :jerboa-emacs/treesitter
        :jerboa-emacs/qt/image
        :jerboa-emacs/qt/commands
        :jerboa-emacs/qt/lsp-client
        :jerboa-emacs/qt/commands-lsp
        :jerboa-emacs/qt/menubar
        :jerboa-emacs/ipc
        :jerboa-emacs/vtscreen
        (only-in :jerboa-emacs/editor-core *aggressive-indent-mode*)
        (only-in :jerboa-emacs/debug-repl start-debug-repl! stop-debug-repl! debug-repl-bind!)
        :jerboa-emacs/qt/automation)

;;;============================================================================
;;; Vterm render throttle — skip intermediate renders during fast output
;;;============================================================================

;; Minimum milliseconds between vterm renders (vtscreen → set-text!)
(def *vterm-render-interval-ms* 33)

;; Maximum bytes of PTY data to process per master-timer tick.
;; Prevents flooding commands (find ~/ -ls) from blocking the Qt event loop.
;; Excess data stays in the channel for the next tick (~50ms later).
(def *pty-batch-budget* 65536)

;; Maximum number of characters to keep in pre-pty scrollback text
(def *vterm-scrollback-limit* 100000)

;; Re-entrancy guard: prevent nested PTY polling when qt-app-process-events!
;; triggers the periodic timer inside qt-poll-terminal-pty-batch!.
;; Without this, terminal A's output can bleed into terminal B's editor.
(def *pty-poll-in-progress?* #f)

;; Per-terminal-state: timestamp (seconds) of last render
(def *vterm-last-render-time* (make-hash-table-eq))

;; Per-terminal-state: last rendered string (skip set-text if unchanged)
(def *vterm-last-rendered* (make-hash-table-eq))

;; Per-terminal-state: have we done the initial full render?
(def *vterm-initialized* (make-hash-table-eq))

;; Per-terminal-state: line offset where vtscreen rows start in the document
(def *vterm-line-offset* (make-hash-table-eq))

;; Per-terminal-state: cached row texts from last render (vector of strings)
(def *vterm-row-cache* (make-hash-table-eq))

(def (vterm-render-due? ts)
  "Return #t if enough time has elapsed since last render for this terminal."
  (let ((last (hash-ref *vterm-last-render-time* ts 0.0))
        (now (time->seconds (current-time))))
    (>= (* (- now last) 1000) *vterm-render-interval-ms*)))

(def (vterm-mark-rendered! ts)
  "Record that we just rendered this terminal."
  (hash-put! *vterm-last-render-time* ts (time->seconds (current-time))))

(def (vterm-cap-scrollback! ts)
  "Trim pre-pty-text if it exceeds the scrollback limit."
  (let ((text (terminal-state-pre-pty-text ts)))
    (when (and (string? text) (> (string-length text) *vterm-scrollback-limit*))
      ;; Keep the last *vterm-scrollback-limit* chars, trim at a newline boundary
      (let* ((start (- (string-length text) *vterm-scrollback-limit*))
             (nl (let scan ((i start))
                   (cond ((>= i (string-length text)) start)
                         ((char=? (string-ref text i) #\newline) (+ i 1))
                         (else (scan (+ i 1)))))))
        (set! (terminal-state-pre-pty-text ts)
          (substring text nl (string-length text)))))))

(def (vterm-cleanup-state! ts)
  "Remove throttle state for a terminal that's done."
  (hash-remove! *vterm-last-render-time* ts)
  (hash-remove! *vterm-last-rendered* ts)
  (hash-remove! *vterm-initialized* ts)
  (hash-remove! *vterm-line-offset* ts)
  (hash-remove! *vterm-row-cache* ts))

;;;============================================================================
;;; Row-diff rendering: update only dirty rows in QScintilla
;;;============================================================================

(def (vterm-replace-line! ed doc-line new-text)
  "Replace the content of a single line in QScintilla without touching other lines.
   doc-line is 0-based. new-text should NOT include a newline."
  (let* ((line-start (sci-send ed SCI_POSITIONFROMLINE doc-line))
         (line-end   (sci-send ed SCI_GETLINEENDPOSITION doc-line)))
    (when (>= line-start 0)
      (sci-send ed SCI_SETTARGETSTART line-start)
      (sci-send ed SCI_SETTARGETEND line-end)
      (sci-send/string ed SCI_REPLACETARGET new-text))))

(def (vterm-ensure-lines! ed needed-count)
  "Ensure the document has at least needed-count lines by appending newlines."
  (let ((current (sci-send ed SCI_GETLINECOUNT)))
    (when (< current needed-count)
      (let ((pad (make-string (- needed-count current) #\newline)))
        ;; Append at end
        (let ((end-pos (sci-send ed SCI_GETTEXTLENGTH)))
          (sci-send ed SCI_SETTARGETSTART end-pos)
          (sci-send ed SCI_SETTARGETEND end-pos)
          (sci-send/string ed SCI_REPLACETARGET pad))))))

(def (vterm-row-diff-render! ed vt ts)
  "Render vtscreen rows into the QScintilla document.
   In normal mode with many dirty rows, uses full set-text! for efficiency.
   On alt screen (top, htop, etc.), always uses per-line replacement to avoid
   the full document reset that causes visible bouncing/flicker.
   Tracks which rows actually changed in *vterm-dirty-rows* for targeted recoloring."
  (let ((rows (vtscreen-rows vt))
        (line-offset (hash-ref *vterm-line-offset* ts 0))
        (cache (hash-ref *vterm-row-cache* ts #f)))
    ;; Ensure we have a row cache
    (when (not cache)
      (set! cache (make-vector rows ""))
      (hash-put! *vterm-row-cache* ts cache))
    ;; Ensure cache is right size (may have changed after resize)
    (when (not (= (vector-length cache) rows))
      (set! cache (make-vector rows ""))
      (hash-put! *vterm-row-cache* ts cache))
    ;; Count dirty rows to decide strategy
    (let count-dirty ((r 0) (n 0))
      (cond
        ((>= r rows)
         (cond
           ((= n 0)
            ;; No dirty rows
            (vtscreen-clear-damage! vt)
            (hash-put! *vterm-dirty-rows* ts (make-hash-table))
            #f)
           ;; Alt-screen (top, htop, vim) OR many dirty rows:
           ;; Full set-text! is more reliable than per-line replacement.
           ;; setUpdatesEnabled batching (in the caller) prevents bounce.
           ((or (vtscreen-alt-screen? vt) (> n 4))
            (let* ((rendered (vtscreen-render vt))
                   (pre-text (if (vtscreen-alt-screen? vt)
                               ""  ;; alt-screen: no pre-PTY prefix
                               (or (terminal-state-pre-pty-text ts) ""))))
              ;; Update cache for all rows
              (let update ((r2 0))
                (when (< r2 rows)
                  (vector-set! cache r2 (vtscreen-get-row-text vt r2))
                  (update (+ r2 1))))
              (vtscreen-clear-damage! vt)
              ;; Full render — mark all rows dirty for coloring
              (hash-put! *vterm-dirty-rows* ts #f)
              (qt-plain-text-edit-set-text! ed (string-append pre-text rendered))
              #t))
           (else
            ;; Few dirty rows in normal mode — per-line replacement
            (vterm-ensure-lines! ed (+ line-offset rows))
            (let ((dirty-set (make-hash-table)))
              (let loop ((r2 0) (any-changed? #f))
                (if (>= r2 rows)
                  (begin
                    (vtscreen-clear-damage! vt)
                    (hash-put! *vterm-dirty-rows* ts dirty-set)
                    any-changed?)
                  (if (vtscreen-row-dirty? vt r2)
                    (let ((new-text (vtscreen-get-row-text vt r2))
                          (old-text (vector-ref cache r2)))
                      (if (string=? new-text old-text)
                        (loop (+ r2 1) any-changed?)
                        (begin
                          (vector-set! cache r2 new-text)
                          (hash-put! dirty-set r2 #t)
                          (vterm-replace-line! ed (+ line-offset r2) new-text)
                          (loop (+ r2 1) #t))))
                    (loop (+ r2 1) any-changed?))))))))
        ((vtscreen-row-dirty? vt r)
         (count-dirty (+ r 1) (+ n 1)))
        (else
         (count-dirty (+ r 1) n))))))

;;;============================================================================
;;; Per-cell color rendering
;;;============================================================================

;; Extended styles for 256-color/RGB: we allocate Scintilla styles on demand
;; Style 64-79 = standard 16 ANSI colors (already set up in terminal.ss)
;; Style 80-249 = dynamically allocated for (fg, bg) color pairs (170 slots)
(def *vterm-next-style* 80)
(def *vterm-color-to-style* (make-hash-table))  ;; (fg . bg) -> style-id
(def *vterm-max-styles* 250)  ;; Scintilla supports styles 0-255; keep 250-255 as reserve
(def *term-default-bg* #x181818)  ;; terminal background color
(def *term-default-fg* #xc5c8c6)  ;; terminal default foreground (for reverse-video substitution)

(def (vterm-get-or-alloc-style! ed fg bg)
  "Get or allocate a Scintilla style for a (fg, bg) color pair.
   fg and bg are packed 0x00RRGGBB or -1 for default.
   Returns style index, or 0 if out of style slots."
  (let ((key (cons fg bg)))
    (or (hash-ref *vterm-color-to-style* key #f)
        (if (>= *vterm-next-style* *vterm-max-styles*)
          0  ;; out of style slots, use default
          (let ((style *vterm-next-style*))
            (set! *vterm-next-style* (+ style 1))
            (when (not (= fg -1))
              (sci-send ed SCI_STYLESETFORE style fg))
            (sci-send ed SCI_STYLESETBACK style
                      (if (= bg -1) *term-default-bg* bg))
            (hash-put! *vterm-color-to-style* key style)
            style)))))

(def (vterm-apply-row-colors! ed vt row doc-line)
  "Apply per-cell fg/bg colors and reverse-video to a row using Scintilla styling."
  (let* ((cols (vtscreen-cols vt))
         (line-start (sci-send ed SCI_POSITIONFROMLINE doc-line))
         (line-end   (sci-send ed SCI_GETLINEENDPOSITION doc-line))
         (line-len   (if (>= line-start 0) (min (- line-end line-start) cols) 0)))
    (when (> line-len 0)
      ;; Walk the row and apply styles in runs of same (fg, bg)
      (let loop ((c 0) (run-start 0) (run-style #f))
        (if (>= c line-len)
          ;; Flush final run
          (when (and run-style (> c run-start))
            (sci-send ed SCI_STARTSTYLING (+ line-start run-start) 0)
            (sci-send ed SCI_SETSTYLING (- c run-start) run-style))
          (let* ((fg    (vtscreen-cell-fg vt row c))
                 (bg    (vtscreen-cell-bg vt row c))
                 (attrs (vtscreen-cell-attrs vt row c))
                 (bold?    (not (= 0 (bitwise-and attrs 1))))
                 (reverse? (not (= 0 (bitwise-and attrs 16))))
                 ;; Reverse video: swap fg/bg, substituting defaults with concrete colors
                 (eff-fg (if reverse? (if (= bg -1) *term-default-bg* bg) fg))
                 (eff-bg (if reverse? (if (= fg -1) *term-default-fg* fg) bg))
                 (style
                  (cond
                    ;; Both default — use style 0 or bold variant
                    ((and (= eff-fg -1) (= eff-bg -1))
                     (if bold? (+ *term-style-base* 15) 0))
                    ;; At least one explicit color
                    (else
                     (vterm-get-or-alloc-style! ed eff-fg eff-bg)))))
            ;; If style changed, flush previous run
            (if (eqv? style run-style)
              (loop (+ c 1) run-start run-style)
              (begin
                (when (and run-style (> c run-start))
                  (sci-send ed SCI_STARTSTYLING (+ line-start run-start) 0)
                  (sci-send ed SCI_SETSTYLING (- c run-start) run-style))
                (loop (+ c 1) c style)))))))))

;; Per-terminal-state: set of row indices updated in the last row-diff-render
(def *vterm-dirty-rows* (make-hash-table-eq))

(def (vterm-apply-colors! ed vt ts)
  "Apply colors to rows updated in the last render pass."
  (let ((rows (vtscreen-rows vt))
        (line-offset (hash-ref *vterm-line-offset* ts 0))
        (dirty-set (hash-ref *vterm-dirty-rows* ts #f)))
    (let loop ((r 0))
      (when (< r rows)
        ;; Only re-color rows that were actually replaced in the last render
        (when (or (not dirty-set)   ;; full render — color everything
                  (hash-ref dirty-set r #f))
          (let ((cache (hash-ref *vterm-row-cache* ts #f)))
            (when (and cache
                       (< r (vector-length cache))
                       (> (string-length (vector-ref cache r)) 0))
              (vterm-apply-row-colors! ed vt r (+ line-offset r)))))
        (loop (+ r 1))))))

;;;============================================================================
;;; Qt Application
;;;============================================================================

(def (parse-repl-port args)
  "Return (port-num . filtered-args) if --repl <port> is present, else #f."
  (let loop ((rest args) (acc []))
    (cond
      ((null? rest) #f)
      ((and (string=? (car rest) "--repl")
            (pair? (cdr rest))
            (string->number (cadr rest)))
       (cons (string->number (cadr rest))
             (append (reverse acc) (cddr rest))))
      (else (loop (cdr rest) (cons (car rest) acc))))))

;; Auto-save path: #filename# (Emacs convention)
(def (qt-make-auto-save-path path)
  (let* ((dir (path-directory path))
         (name (path-strip-directory path)))
    (path-expand (string-append "#" name "#") dir)))

(def (qt-update-frame-title! app)
  "Update window title to show current buffer and file path."
  (let* ((fr (app-state-frame app))
         (win (qt-frame-main-win fr))
         (buf (qt-current-buffer fr))
         (name (buffer-name buf))
         (path (buffer-file-path buf))
         (modified? (and (buffer-doc-pointer buf)
                         (qt-text-document-modified? (buffer-doc-pointer buf))))
         (title (string-append
                  (if modified? "* " "")
                  name
                  (if path (string-append " - " path) "")
                  " - jemacs")))
    (qt-main-window-set-title! win title)))

(def (qt-update-mark-selection! app)
  "Update visual selection to reflect active mark region.
   When buffer-mark is set, highlights the region between mark and cursor.
   When mark is cleared, ensures no stale selection remains."
  (let* ((fr (app-state-frame app))
         (ed (qt-current-editor fr))
         (buf (qt-current-buffer fr))
         (mark (buffer-mark buf)))
    (if mark
      (let ((pos (qt-plain-text-edit-cursor-position ed)))
        ;; anchor=mark (fixed end), caret=pos (moving end).
        ;; Must NOT normalize with min/max: that swaps anchor/caret when
        ;; navigating backwards (mark > pos), causing SCI_GETCURRENTPOS to
        ;; return the mark position and making collapse-selection-to-caret!
        ;; snap back to the mark on every subsequent keypress.
        (qt-plain-text-edit-set-selection! ed mark pos))
      ;; No mark — deselect if anything is selected
      (let ((pos (qt-plain-text-edit-cursor-position ed)))
        (qt-plain-text-edit-set-selection! ed pos pos)))))

;; Master timer tick function — set by qt-do-init!, called from qt-app-exec! loop
(def *master-timer-tick-fn* #f)
(def *pty-poll-logged?* #f)

;; Qt application object — set by qt-do-init!, used for qt-app-process-events!
(def *qt-app-ref* #f)

;; Which-key state — show available bindings after prefix key delay
(def *which-key-timer* #f)
(def *which-key-pending-keymap* #f)
(def *which-key-pending-prefix* #f)

(def (which-key-format-bindings km prefix-str)
  "Format keymap bindings for which-key display.
   Shows key → Description pairs with human-readable command names."
  (let* ((entries (keymap-entries km))
         (describe (lambda (cmd)
                     (cond
                       ((hash-table? cmd) "+prefix")
                       ((symbol? cmd) (command-name->description cmd))
                       (else "?"))))
         (strs (let loop ((es entries) (acc []))
                 (if (null? es) (reverse acc)
                   (let* ((e (car es))
                          (key (car e))
                          (val (cdr e))
                          (desc (describe val)))
                     (loop (cdr es)
                           (cons (string-append key " → " desc) acc)))))))
    (string-append prefix-str "- " (string-join strs "  "))))

;; Key-chord state — detect two rapid keystrokes as a chord
(def *chord-timer* #f)
(def *chord-pending-char* #f)  ;; first char of potential chord, or #f
(def *chord-pending-code* #f)  ;; saved raw Qt event for replay
(def *chord-pending-mods* #f)
(def *chord-pending-text* #f)
(def *chord-timer-fired* #f)   ;; set to #t when timer fires (guards against race)

;; Tab bar state — populated during qt-main, used by qt-tabbar-update!
(def *tab-bar-layout* #f)
(def *tab-bar-buttons* '())  ;; list of (buffer . button) pairs
(def *tab-bar-last-state* #f)  ;; cache: (current-buf . buffer-count) to skip redundant updates
(def *tab-bar-widget* #f)     ;; the tab bar widget itself (for show/hide)

(def (qt-tabbar-update! app)
  "Rebuild the tab bar to reflect current buffer list."
  ;; Show/hide the tab bar widget
  (when *tab-bar-widget*
    (if *tab-bar-visible*
      (qt-widget-show! *tab-bar-widget*)
      (qt-widget-hide! *tab-bar-widget*)))
  (when (and *tab-bar-layout* *tab-bar-visible*)
    (let* ((fr (app-state-frame app))
           (current-buf (qt-edit-window-buffer (qt-current-window fr)))
           (bufs (buffer-list))
           (new-state (cons current-buf (length bufs))))
      ;; Skip update if nothing changed
      (unless (and *tab-bar-last-state*
                   (eq? (car new-state) (car *tab-bar-last-state*))
                   (= (cdr new-state) (cdr *tab-bar-last-state*)))
        (set! *tab-bar-last-state* new-state)
        ;; Destroy old buttons
        (for-each (lambda (pair) (qt-widget-destroy! (cdr pair))) *tab-bar-buttons*)
        (set! *tab-bar-buttons* '())
        ;; Create new buttons for each buffer
        (for-each
          (lambda (buf)
            (let* ((name (buffer-name buf))
                   (mod? (and (buffer-doc-pointer buf)
                              (qt-text-document-modified? (buffer-doc-pointer buf))))
                   (label (if mod? (string-append name " *") name))
                   (btn (qt-push-button-create label)))
              ;; Style: current buffer gets highlighted
              (let ((font-css (string-append " font-family: " *default-font-family*
                                             "; font-size: " (number->string (max 1 (- *default-font-size* 2))) "pt;")))
                (if (eq? buf current-buf)
                  (qt-widget-set-style-sheet! btn
                    (string-append "QPushButton { color: #ffffff; background: #404060; border: 1px solid #606080; border-radius: 3px; padding: 2px 8px;" font-css " }"))
                  (qt-widget-set-style-sheet! btn
                    (string-append "QPushButton { color: #a0a0a0; background: #252525; border: 1px solid #383838; border-radius: 3px; padding: 2px 8px;" font-css " }\n"
                                   "                   QPushButton:hover { color: #d8d8d8; background: #353535; }"))))
              ;; Click handler: switch to this buffer
              (qt-on-clicked! btn
                (lambda ()
                  (let* ((ed (qt-current-editor fr)))
                    (qt-buffer-attach! ed buf)
                    (set! (qt-edit-window-buffer (qt-current-window fr)) buf)
                    (qt-update-visual-decorations! ed)
                    (qt-modeline-update! app)
                    (set! *tab-bar-last-state* #f)  ;; force refresh
                    (qt-tabbar-update! app))))
              ;; Add to layout
              (qt-layout-add-widget! *tab-bar-layout* btn)
              (set! *tab-bar-buttons* (cons (cons buf btn) *tab-bar-buttons*))))
          bufs)
        ;; Add stretch at the end to push tabs left
        (qt-layout-add-stretch! *tab-bar-layout*)))))

;;;============================================================================
;;; PTY output polling helpers (used by timer callback)
;;;============================================================================

(def (qt-poll-shell-pty-msg! fr buf ss msg)
  "Handle one PTY message for a shell buffer in Qt.
   Uses VT100 screen buffer to properly handle cursor-addressing programs."
  (let ((tag (car msg))
        (data (cdr msg))
        (vt (shell-state-vtscreen ss)))
    (cond
      ((eq? tag 'data)
       (let loop ((wins (qt-frame-windows fr)))
         (when (pair? wins)
           (if (eq? (qt-edit-window-buffer (car wins)) buf)
             (let ((ed (qt-edit-window-editor (car wins))))
               ;; Save pre-PTY text on first data chunk
               (when (and vt (not (shell-state-pre-pty-text ss)))
                 (set! (shell-state-pre-pty-text ss)
                   (qt-plain-text-edit-text ed)))
               (if vt
                 ;; Feed data to VT100 screen buffer, then render
                 (begin
                   (vtscreen-feed! vt data)
                   (let* ((rendered (vtscreen-render vt))
                          ;; Full-screen programs (alt-screen): show only vtscreen
                          ;; Simple commands: prepend pre-PTY text
                          (full (if (vtscreen-alt-screen? vt)
                                  rendered
                                  (string-append (or (shell-state-pre-pty-text ss) "")
                                                 rendered))))
                     (qt-plain-text-edit-set-text! ed full)
                     (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                     (qt-plain-text-edit-ensure-cursor-visible! ed)))
                 ;; Fallback: strip and append (no vtscreen)
                 (begin
                   (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                   (qt-plain-text-edit-insert-text! ed (strip-ansi-codes data))
                   (qt-plain-text-edit-ensure-cursor-visible! ed))))
             (loop (cdr wins))))))
      ((eq? tag 'done)
       ;; Capture final vtscreen state before cleanup destroys it
       (let* ((alt-screen? (and vt (vtscreen-alt-screen? vt)))
              (final-render (and vt (vtscreen-render vt)))
              (pre-text (shell-state-pre-pty-text ss)))
         (shell-cleanup-pty! ss)
         (let loop ((wins (qt-frame-windows fr)))
           (when (pair? wins)
             (if (eq? (qt-edit-window-buffer (car wins)) buf)
               (let ((ed (qt-edit-window-editor (car wins))))
                 (let ((prompt (shell-prompt ss)))
                   (when pre-text
                     (if alt-screen?
                       ;; Full-screen program (top, vim): restore pre-PTY text
                       (qt-plain-text-edit-set-text! ed pre-text)
                       ;; Simple command (ls, ps): keep output
                       (let* ((output (or final-render ""))
                              (sep (if (and (> (string-length output) 0)
                                           (not (char=? (string-ref output (- (string-length output) 1)) #\newline)))
                                     "\n" ""))
                              (full (string-append pre-text output sep)))
                         (qt-plain-text-edit-set-text! ed full))))
                   (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                   (qt-plain-text-edit-insert-text! ed prompt)
                   (set! (shell-state-prompt-pos ss)
                     (string-length (qt-plain-text-edit-text ed)))
                   (qt-plain-text-edit-ensure-cursor-visible! ed)))
               (loop (cdr wins))))))))))

(def (qt-poll-terminal-pty-batch! fr buf ts data)
  "Handle batched PTY data for a terminal buffer.
   Feeds data to vtscreen immediately but throttles rendering.
   Uses row-diff rendering: only updates dirty rows in QScintilla."
  (let ((vt (terminal-state-vtscreen ts)))
    (let loop ((wins (qt-frame-windows fr)))
      (when (pair? wins)
        (if (eq? (qt-edit-window-buffer (car wins)) buf)
          (let ((ed (qt-edit-window-editor (car wins)))
                (win (car wins)))
            ;; Save pre-PTY text on first data chunk
            (when (and vt (not (terminal-state-pre-pty-text ts)))
              (let ((pre-text (qt-plain-text-edit-text ed)))
                (set! (terminal-state-pre-pty-text ts) pre-text)
                ;; Count lines in pre-pty-text for line offset
                (let ((offset (if (and pre-text (> (string-length pre-text) 0))
                               (let count ((i 0) (n 1))
                                 (cond ((>= i (string-length pre-text)) n)
                                       ((char=? (string-ref pre-text i) #\newline)
                                        (count (+ i 1) (+ n 1)))
                                       (else (count (+ i 1) n))))
                               0)))
                  (hash-put! *vterm-line-offset* ts offset))))
            (if vt
              (begin
                ;; Always feed data to vtscreen so terminal state stays current
                (vtscreen-feed! vt data)
                ;; Cap scrollback to prevent unbounded growth
                (vterm-cap-scrollback! ts)
                ;; Let Qt process pending events (key presses, etc.) so the UI
                ;; stays responsive even when terminal output is flooding.
                (when *qt-app-ref*
                  (qt-app-process-events! *qt-app-ref*))
                ;; Re-check: processEvents may have triggered switch-buffer,
                ;; changing the editor's active document.  If the window no
                ;; longer shows this terminal buffer, skip the render.
                (when (and (eq? (qt-edit-window-buffer win) buf)
                           (vterm-render-due? ts))
                  (if (not (hash-ref *vterm-initialized* ts #f))
                    ;; First render: full set-text to establish the document.
                    ;; Wrap in set-updates-enabled #f/#t to prevent bounce:
                    ;; set-text! resets scroll to top, then ensure-cursor-visible
                    ;; scrolls to bottom — without suppressing updates, both
                    ;; paints are visible as a flash/bounce.
                    (let* ((rendered (vtscreen-render vt))
                           (full (if (vtscreen-alt-screen? vt)
                                   rendered
                                   (string-append (or (terminal-state-pre-pty-text ts) "")
                                                  rendered))))
                      (qt-widget-set-updates-enabled! ed #f)
                      (qt-plain-text-edit-set-text! ed full)
                      (hash-put! *vterm-last-rendered* ts full)
                      (hash-put! *vterm-initialized* ts #t)
                      ;; Initialize row cache from current vtscreen state
                      (let* ((rows (vtscreen-rows vt))
                             (cache (make-vector rows "")))
                        (let init-cache ((r 0))
                          (when (< r rows)
                            (vector-set! cache r (vtscreen-get-row-text vt r))
                            (init-cache (+ r 1))))
                        (hash-put! *vterm-row-cache* ts cache))
                      (vtscreen-clear-damage! vt)
                      ;; Apply colors to initial render
                      (vterm-apply-colors! ed vt ts)
                      (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                      (qt-plain-text-edit-ensure-cursor-visible! ed)
                      ;; Reset horizontal scroll — terminal never needs h-scroll
                      (sci-send ed SCI_SETXOFFSET 0)
                      (qt-widget-set-updates-enabled! ed #t))
                    ;; Subsequent renders: row-diff update
                    (when (vtscreen-has-damage? vt)
                      (if (vtscreen-alt-screen? vt)
                        ;; Alt screen: line-offset = 0
                        (hash-put! *vterm-line-offset* ts 0)
                        ;; Normal mode: keep existing offset
                        (void))
                      ;; Suppress intermediate repaints: disable widget updates,
                      ;; do all line replacements + styling, then re-enable for
                      ;; a single
                      (qt-widget-set-updates-enabled! ed #f)
                      (let ((changed? (vterm-row-diff-render! ed vt ts)))
                        (when changed?
                          ;; Apply colors to changed rows
                          (vterm-apply-colors! ed vt ts)
                          (if (vtscreen-alt-screen? vt)
                            ;; Alt screen (top, htop, etc.): place cursor at terminal's
                            ;; actual cursor position. Do NOT move to end or call
                            ;; ensure-cursor-visible — that forces a scroll/relayout
                            ;; on every refresh, causing the visible "bounce".
                            (let* ((crow (vtscreen-cursor-row vt))
                                   (ccol (vtscreen-cursor-col vt))
                                   (offset (hash-ref *vterm-line-offset* ts 0))
                                   (line-start (sci-send ed SCI_POSITIONFROMLINE (+ offset crow)))
                                   (pos (+ line-start ccol)))
                              (when (>= line-start 0)
                                (sci-send ed SCI_GOTOPOS pos)))
                            ;; Normal mode: scroll to bottom to follow output
                            (begin
                              (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                              (qt-plain-text-edit-ensure-cursor-visible! ed)
                              ;; Reset horizontal scroll — terminal never needs h-scroll
                              (sci-send ed SCI_SETXOFFSET 0))))
                        (qt-widget-set-updates-enabled! ed #t))))
                  (vterm-mark-rendered! ts)))
              (begin
                (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                (qt-plain-text-edit-insert-text! ed (strip-ansi-codes data))
                (qt-plain-text-edit-ensure-cursor-visible! ed)
                (sci-send ed SCI_SETXOFFSET 0))))
          (loop (cdr wins)))))))

(def (qt-poll-terminal-pty-msg! fr buf ts msg)
  "Handle one PTY message for a terminal buffer in Qt.
   Data messages are handled via qt-poll-terminal-pty-batch! for efficiency."
  (let ((tag (car msg))
        (data (cdr msg))
        (vt (terminal-state-vtscreen ts)))
    (verbose-log! "PTY-MSG tag=" (symbol->string tag))
    (cond
      ((eq? tag 'data)
       ;; Single data message fallback
       (qt-poll-terminal-pty-batch! fr buf ts data))
      ((eq? tag 'done)
       ;; Capture final vtscreen state before cleanup destroys it
       (let* ((alt-screen? (and vt (vtscreen-alt-screen? vt)))
              (final-render (and vt (vtscreen-render vt)))
              (pre-text (terminal-state-pre-pty-text ts)))
         (vterm-cleanup-state! ts)
         (terminal-cleanup-pty! ts)
         (let loop ((wins (qt-frame-windows fr)))
           (when (pair? wins)
             (if (eq? (qt-edit-window-buffer (car wins)) buf)
               (let ((ed (qt-edit-window-editor (car wins))))
                 (let ((prompt (terminal-prompt ts)))
                   ;; Suppress widget updates during done-handler edits
                   ;; to prevent bounce (multiple paints during set-text/insert/scroll).
                   (qt-widget-set-updates-enabled! ed #f)
                   (if (and pre-text alt-screen?)
                     ;; Full-screen program (top, vim): restore pre-PTY text
                     (qt-plain-text-edit-set-text! ed pre-text)
                     ;; Simple command (ls, ps): keep current editor content as-is.
                     ;; Row-diff rendering already updated the display incrementally;
                     ;; do NOT call set-text! again (causes visible bounce/flash).
                     (begin
                       (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                       ;; Ensure trailing newline before prompt
                       (let ((text (qt-plain-text-edit-text ed)))
                         (when (and text (> (string-length text) 0)
                                    (not (char=? (string-ref text (- (string-length text) 1)) #\newline)))
                           (qt-plain-text-edit-insert-text! ed "\n")))))
                   (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                   (qt-plain-text-edit-insert-text! ed prompt)
                   (set! (terminal-state-prompt-pos ts)
                     (string-length (qt-plain-text-edit-text ed)))
                   (qt-plain-text-edit-ensure-cursor-visible! ed)
                   ;; Reset horizontal scroll — terminal never needs h-scroll
                   (sci-send ed SCI_SETXOFFSET 0)
                   (qt-widget-set-updates-enabled! ed #t)))
               (loop (cdr wins))))))))))

(def (qt-do-init! qt-app args)
  ;; Initialize runtime error log (~/.jemacs-errors.log)
  (init-jemacs-log!)
  ;; Verbose hang-diagnosis log: always enabled for debugging.
  ;; Opens ~/.jemacs-verbose.log for timestamped diagnostic output.
  (init-verbose-log!)
  (verbose-log! "jemacs-qt verbose mode ON")
    ;; Initialize face system with standard faces
    (define-standard-faces!)
    ;; Load saved theme and font settings from ~/.jemacs-theme
    (let-values (((saved-theme saved-font-family saved-font-size) (theme-settings-load!)))
      ;; Apply saved theme if valid
      (when (and saved-theme (theme-get saved-theme))
        (set! *current-theme* saved-theme))
      ;; Apply saved font family if valid
      (when (and saved-font-family (not (string-empty? saved-font-family)))
        (set! *default-font-family* saved-font-family))
      ;; Apply saved font size if valid
      (when (and saved-font-size (>= saved-font-size 6) (<= saved-font-size 72))
        (set! *default-font-size* saved-font-size)))
    ;; Load theme (populates *faces* registry from theme definition)
    (load-theme! *current-theme*)
    ;; Load custom face overrides (overlays on top of theme)
    (custom-faces-load!)
    ;; Apply theme stylesheet
    (qt-app-set-style-sheet! qt-app (theme-stylesheet))

    (let* ((win (qt-main-window-create))
           ;; Central widget with vertical layout
           (central (qt-widget-create win))
           (layout (qt-vbox-layout-create central))
           ;; Tab bar for buffer switching
           (tab-bar (qt-widget-create central))
           (tab-layout (qt-hbox-layout-create tab-bar))
           ;; Main content area: splitter for editors
           (splitter (qt-splitter-create QT_VERTICAL central))
           (_ (begin
                ;; Window dividers: visible blue handle between split panes
                (qt-splitter-set-handle-width! splitter 3)
                (qt-widget-set-style-sheet! splitter
                  "QSplitter::handle { background: #51afef; }")))
           ;; Echo label at bottom
           (echo-label (qt-label-create "" central))
           ;; Initialize frame with one editor in the splitter
           (fr (qt-frame-init! win splitter))
           ;; Create app state
           (app (new-app-state fr)))

      ;; Tab bar styling
      (qt-widget-set-minimum-height! tab-bar 26)
      (qt-widget-set-style-sheet! tab-bar
        "background: #1e1e1e; border-bottom: 1px solid #383838;")
      (qt-layout-set-margins! tab-layout 2 2 2 2)
      (qt-layout-set-spacing! tab-layout 2)
      ;; Store tab bar references for dynamic updates
      (set! *tab-bar-layout* tab-layout)
      (set! *tab-bar-widget* tab-bar)

      ;; Echo label: ensure visible with minimum height and distinct style
      ;; Must be tall enough to display text clearly (not clipped)
      (qt-widget-set-minimum-height! echo-label 28)
      (let ((font-css (string-append " font-family: " *default-font-family*
                                     "; font-size: " (number->string *default-font-size*) "pt;")))
        (qt-widget-set-style-sheet! echo-label
          (string-append "color: #d8d8d8; background: #1e1e1e;" font-css " padding: 4px 6px; border-top: 1px solid #484848;")))

      ;; Layout: tab-bar at top, splitter takes remaining space, echo-label at bottom
      (qt-layout-add-widget! layout tab-bar)
      (qt-layout-add-widget! layout splitter)
      (qt-layout-add-widget! layout echo-label)
      (qt-layout-set-stretch-factor! layout tab-bar 0)
      (qt-layout-set-stretch-factor! layout splitter 1)
      (qt-layout-set-stretch-factor! layout echo-label 0)
      (qt-widget-set-size-policy! tab-bar QT_SIZE_PREFERRED QT_SIZE_FIXED)
      (qt-widget-set-size-policy! echo-label QT_SIZE_PREFERRED QT_SIZE_FIXED)
      (qt-layout-set-margins! layout 0 0 0 0)
      (qt-layout-set-spacing! layout 0)

      ;; Initialize inline minibuffer (hidden until needed)
      (qt-minibuffer-init! echo-label qt-app layout)

      ;; Store Qt app pointer for clipboard access from commands
      (set! *qt-app-ptr* qt-app)
      ;; Also store in window module for process-events during splits
      (qt-window-set-app-ptr! qt-app)

      ;; Set up keybindings and commands
      (setup-default-bindings!)
      (setup-command-docs!)
      (qt-register-all-commands!)
      (jemacs-log! "commands registered: "
                   (number->string (hash-length *all-commands*)) " total")

      ;; Set up post-buffer-attach hook for image/text display toggling
      ;; When showing an image, install key handler on the scroll area and
      ;; set focus there — the Scintilla editor is hidden by QStackedWidget
      ;; so it can't receive key events.
      (let ((image-key-installed (make-hash-table-eq))
            (terminal-key-installed (make-hash-table-eq)))
        (add-hook! 'post-buffer-attach-hook
          (lambda (editor buf)
            (with-catch
              (lambda (e)
                (verbose-log! "post-buffer-attach-hook ERROR: "
                  (with-output-to-string (lambda () (display-exception e)))))
              (lambda ()
                (cond
                  ;; QTerminalWidget buffers: switch stacked to terminal view
                  ((hash-get *terminal-widget-map* buf)
                   => (lambda (term)
                        (let ((win (hash-get *editor-window-map* editor)))
                          (when win
                            (let* ((container (qt-edit-window-container win))
                                   (count (qt-stacked-widget-count container))
                                   (tw (qt-terminal-widget term)))
                              ;; Always install consuming key filter (idempotent via guard)
                              (unless (hash-get terminal-key-installed tw)
                                ((app-state-key-handler app) tw)
                                (hash-put! terminal-key-installed tw #t))
                              (if (> count 1)
                                ;; Terminal widget lives in THIS container — show and focus it
                                (begin
                                  (qt-stacked-widget-set-current-widget! container tw)
                                  (qt-widget-set-focus! tw))
                                ;; Terminal widget is in another window (e.g. after C-x 2).
                                ;; Just show the editor in this window — don't steal focus.
                                (qt-widget-set-focus! editor)))))))
                  ;; Image buffers
                  ((image-buffer? buf)
                   (qt-show-image-buffer! editor buf)
                   (let ((win (hash-get *editor-window-map* editor)))
                     (when (and win (qt-edit-window-image-scroll win))
                       (let ((scroll (qt-edit-window-image-scroll win)))
                         (unless (hash-get image-key-installed scroll)
                           ((app-state-key-handler app) scroll)
                           (hash-put! image-key-installed scroll #t))
                         (qt-widget-set-focus! scroll)))))
                  ;; Normal text buffers
                  (else
                    (qt-hide-image-buffer! editor)
                    ;; Re-apply syntax highlighting to this editor widget.
                    ;; QScintilla lexers are per-widget, so splits need re-setup.
                    (qt-reapply-highlighting! editor buf)
                    (qt-widget-set-focus! editor))))))))

      ;; Load recent files, bookmarks, keys, abbrevs, history from disk
      (recent-files-load!)
      (bookmarks-load! app)
      (custom-keys-load!)
      (abbrevs-load!)
      (savehist-load!)
      (save-place-load!)
      (gsh-history-load!)
      (load-init-file!)
      (init-file-load!)  ;; plaintext ~/.jemacs-init (chords, key-translate, settings)

      ;; Menu bar and toolbar
      (qt-setup-menubar! app win)

      ;; Initial text in scratch buffer — restore from disk if available
      (let* ((ed (qt-current-editor fr))
             (saved (scratch-restore!))
             (text (or saved
                       (string-append
                        ";; Jemacs — *scratch*\n"
                        ";;\n"
                        ";; Key Bindings:\n"
                        ";;   C-x C-f   Find file        C-x C-s   Save buffer\n"
                        ";;   C-x b     Switch buffer     C-x k     Kill buffer\n"
                        ";;   C-x C-r   Recent files      M-x       Extended command\n"
                        ";;   C-s       Search forward    M-%       Query replace\n"
                        ";;   C-x 2     Split window      C-x o     Other window\n"
                        ";;   C-h f     Describe command   C-h k     Describe key\n"
                        ";;\n"
                        ";; This buffer is for Jerboa Scheme evaluation.\n"
                        ";; Type expressions and use M-x eval-buffer to evaluate.\n\n"))))
        (qt-plain-text-edit-set-text! ed text)
        (qt-text-document-set-modified! (buffer-doc-pointer
                                          (qt-current-buffer fr)) #f)
        (qt-plain-text-edit-set-cursor-position! ed 0)
        (scratch-update-text! text))

      ;; Run after-init-hook (user code can add hooks in init file)
      (run-hooks! 'after-init-hook app)

      ;; Key handler — define once, install on each editor
      ;; Uses consuming variant so QPlainTextEdit doesn't process keys itself.
      (let ((key-handler
             (lambda ()
               ;; Guard: ignore editor keystrokes while minibuffer is blocking.
               ;; Without this, qt-app-process-events! inside the minibuffer loop
               ;; can re-enter the key handler, causing nested command dispatch.
               (when (not *minibuffer-active?*)
               (let* ((code (qt-last-key-code))
                      (mods (normalize-qt-mods (qt-last-key-modifiers)))
                      (raw-text (qt-last-key-text))
                      (autorepeat? (qt-last-key-autorepeat?))
                      ;; Apply key translation map to printable characters
                      (text (if (= (string-length raw-text) 1)
                              (string (key-translate-char (string-ref raw-text 0)))
                              raw-text)))
                ;; Record keystroke in lossage ring
                (let ((ks (qt-key-event->string code mods text)))
                  (when ks
                    (key-lossage-record! app ks)
                    (verbose-log! "KEY " ks " code=" (number->string code)
                                  " mods=" (number->string mods))))
                ;; Modal mode intercepts: isearch and query-replace
                (cond
                 (*isearch-active*
                  (let ((handled (isearch-handle-key! app code mods text)))
                    ;; Update visual decorations and modeline
                    (qt-update-visual-decorations!
                      (qt-current-editor (app-state-frame app)))
                    (qt-modeline-update! app)
                    (qt-echo-draw! (app-state-echo app) echo-label)
                    ;; If not handled, fall through to normal processing
                    (when (not handled)
                      (let-values (((action data new-state)
                                    (qt-key-state-feed! (app-state-key-state app)
                                                        code mods text)))
                        (set! (app-state-key-state app) new-state)
                        (when (eq? action 'command)
                          (execute-command! app data))))))
                 (*qreplace-active*
                  (qreplace-handle-key! app code mods text)
                  (qt-modeline-update! app)
                  (qt-echo-draw! (app-state-echo app) echo-label))
                 (*snake-active*
                  (snake-handle-key! app code mods text))
                 (else
                ;; Normal key processing — with chord detection
                (letrec
                  ((terminal-pty-intercept?
                    ;; Check if we should intercept this key for an active PTY.
                    ;; When PTY is busy (running an interactive program like claude,
                    ;; top, vim), ALL keys must go to the PTY — not just Ctrl+letter.
                    ;; Returns #t if the key was sent to the PTY, #f otherwise.
                    (lambda (code mods text)
                      ;; Don't intercept when in a prefix key state (e.g., after C-x,
                      ;; the next key like "2" or "3" must go to jemacs, not the PTY)
                      (and (null? (key-state-prefix-keys (app-state-key-state app)))
                      (let* ((ctrl? (not (zero? (bitwise-and mods QT_MOD_CTRL))))
                             (alt?  (not (zero? (bitwise-and mods QT_MOD_ALT))))
                             (buf (qt-current-buffer (app-state-frame app))))
                        ;; Allow C-x, C-g, and M-x to pass through to jemacs
                        (and (not (and ctrl? (not alt?)
                                      (or (= code (+ QT_KEY_A 23))    ;; C-x
                                          (= code (+ QT_KEY_A 6)))))  ;; C-g
                             (not (and alt? (not ctrl?)
                                      (= code (+ QT_KEY_A 23))))      ;; M-x
                             (let ((send!
                                     (cond
                                       ((terminal-buffer? buf)
                                        (let ((ts (hash-get *terminal-state* buf)))
                                          (and ts (terminal-pty-busy? ts)
                                               (lambda (s) (terminal-send-input! ts s)))))
                                       ((shell-buffer? buf)
                                        (let ((ss (hash-get *shell-state* buf)))
                                          (and ss (shell-pty-busy? ss)
                                               (lambda (s) (shell-send-input! ss s)))))
                                       (else #f))))
                               (and send!
                                    (cond
                                      ;; Ctrl+letter → send control character
                                      ((and ctrl? (not alt?)
                                            (>= code QT_KEY_A) (<= code QT_KEY_Z))
                                       (send! (string (integer->char (+ 1 (- code QT_KEY_A)))))
                                       #t)
                                      ;; Arrow keys → send ANSI escape sequences
                                      ((= code QT_KEY_UP)    (send! "\x1b;[A") #t)
                                      ((= code QT_KEY_DOWN)  (send! "\x1b;[B") #t)
                                      ((= code QT_KEY_RIGHT) (send! "\x1b;[C") #t)
                                      ((= code QT_KEY_LEFT)  (send! "\x1b;[D") #t)
                                      ;; Enter/Return → send CR
                                      ((or (= code QT_KEY_RETURN) (= code QT_KEY_ENTER))
                                       (send! "\r") #t)
                                      ;; Backspace → send DEL (0x7f)
                                      ((= code QT_KEY_BACKSPACE)
                                       (send! (string (integer->char 127))) #t)
                                      ;; Delete → send escape sequence
                                      ((= code QT_KEY_DELETE) (send! "\x1b;[3~") #t)
                                      ;; Tab → send tab
                                      ((= code QT_KEY_TAB) (send! "\t") #t)
                                      ;; Escape → send ESC
                                      ((= code QT_KEY_ESCAPE) (send! "\x1b;") #t)
                                      ;; Home/End
                                      ((= code QT_KEY_HOME) (send! "\x1b;[H") #t)
                                      ((= code QT_KEY_END)  (send! "\x1b;[F") #t)
                                      ;; Page Up/Down
                                      ((= code QT_KEY_PAGE_UP)   (send! "\x1b;[5~") #t)
                                      ((= code QT_KEY_PAGE_DOWN) (send! "\x1b;[6~") #t)
                                      ;; Printable character → send as-is
                                      ((and (= (string-length text) 1)
                                            (> (char->integer (string-ref text 0)) 31))
                                       (send! text) #t)
                                      (else #f)))))))))
                   (do-normal-key!
                    (lambda (code mods text)
                     ;; Terminal PTY intercept: send control keys directly to PTY
                     (unless (terminal-pty-intercept? code mods text)
                     ;; Auto-repeat filter for prefix keys: when in C-x (or similar)
                     ;; Auto-repeat filter: when in prefix state (e.g. C-x), ignore:
                     ;; 1) The same key-string as the prefix (C-x auto-repeat with Ctrl held)
                     ;; 2) The bare key (x without Ctrl, when Ctrl released before X)
                     (let* ((prefix-keys (key-state-prefix-keys (app-state-key-state app)))
                            (is-prefix-autorepeat?
                              (and (pair? prefix-keys)
                                   (let* ((last-prefix (car (reverse prefix-keys)))
                                          (ks (qt-key-event->string code mods text)))
                                     (and ks
                                          (or
                                            ;; Case 1: exact same key as prefix (C-x → C-x)
                                            (string=? ks last-prefix)
                                            ;; Case 2: bare key matching prefix tail (C-x → x)
                                            (and (zero? (bitwise-and mods QT_MOD_CTRL))
                                                 (zero? (bitwise-and mods QT_MOD_ALT))
                                                 (>= (string-length last-prefix) 3)
                                                 (string=? ks
                                                   (substring last-prefix
                                                     (- (string-length last-prefix) 1)
                                                     (string-length last-prefix))))))))))
                       (if is-prefix-autorepeat?
                         (begin
                           (verbose-log! "PREFIX-AUTOREPEAT ignored key="
                                         (qt-key-event->string code mods text)
                                         " prefix=" (car (reverse prefix-keys)))
                           (void))
                     ;; Repeat-mode: check active repeat map before normal dispatch
                     (if (and (active-repeat-map)
                              (let* ((ks (qt-key-event->string code mods text))
                                     (repeat-cmd (and ks (repeat-map-lookup ks))))
                                (if repeat-cmd
                                  (begin (execute-command! app repeat-cmd) #t)
                                  (begin (clear-repeat-map!) #f))))
                       (void) ;; handled by repeat map
                     (let-values (((action data new-state)
                                   (qt-key-state-feed! (app-state-key-state app)
                                                       code mods text)))
                       (set! (app-state-key-state app) new-state)
                       ;; Cancel which-key timer on any non-prefix action
                       (when (and *which-key-timer* (not (eq? action 'prefix)))
                         (qt-timer-stop! *which-key-timer*)
                         (set! *which-key-pending-keymap* #f))
                       ;; Describe-key interception: if pending, show what the key does
                       ;; instead of executing it (except for prefix keys which continue building)
                       (if (and *qt-describe-key-pending* (not (eq? action 'prefix)))
                         (let ((ks (qt-key-event->string code mods text)))
                           (qt-describe-key-result! app ks action data))
                       ;; Quoted insert: insert next key literally (C-q)
                       (if *qt-quoted-insert-pending*
                         (qt-quoted-insert-handle! app
                           (if (and text (> (string-length text) 0)) text
                             (qt-key-event->string code mods text)))
                       (case action
                         ((command)
                          ;; Record for keyboard macro
                          (when (and (app-state-macro-recording app)
                                     (not (memq data '(start-kbd-macro end-kbd-macro
                                                       call-last-kbd-macro call-named-kbd-macro
                                                       name-last-kbd-macro list-kbd-macros
                                                       save-kbd-macros load-kbd-macros))))
                            (set! (app-state-macro-recording app)
                              (cons (cons 'command data)
                                    (app-state-macro-recording app))))
                          ;; Clear echo on command
                          (when (and (echo-state-message (app-state-echo app))
                                     (null? (key-state-prefix-keys new-state)))
                            (echo-clear! (app-state-echo app)))
                          (execute-command! app data))
                         ((self-insert)
                          ;; Check mode keymap first — special modes override self-insert
                          (let* ((buf (qt-current-buffer (app-state-frame app)))
                                 (mode-cmd (mode-keymap-lookup buf data)))
                            (if mode-cmd
                              ;; Mode keymap has a binding for this key — execute as command
                              (execute-command! app mode-cmd)
                              ;; No mode binding — normal self-insert
                              (begin
                          (when (app-state-macro-recording app)
                            (set! (app-state-macro-recording app)
                              (cons (cons 'self-insert data)
                                    (app-state-macro-recording app))))
                          ;; Handle self-insert directly here for Qt
                          (let* ((ed (qt-current-editor (app-state-frame app)))
                                 (ch (string-ref data 0))
                                 (close-ch (and *auto-pair-mode*
                                                (let ((cc (auto-pair-char (char->integer ch))))
                                                  (and cc (integer->char cc)))))
                                 (n (get-prefix-arg app))) ; Get prefix arg
                            (cond
                              ;; Suppress in dired and image buffers
                              ((dired-buffer? buf) (void))
                              ((image-buffer? buf) (void))
                              ;; In REPL buffers, only allow after the prompt
                              ((repl-buffer? buf)
                               (let* ((pos (qt-plain-text-edit-cursor-position ed))
                                      (rs (hash-get *repl-state* buf)))
                                 (when (and rs (>= pos (repl-state-prompt-pos rs)))
                                   (let loop ((i 0))
                                     (when (< i n)
                                       (qt-plain-text-edit-insert-text! ed (string ch))
                                       (loop (+ i 1)))))))
                              ;; Eshell: allow typing after the last prompt
                              ((eshell-buffer? buf)
                               (let loop ((i 0))
                                 (when (< i n)
                                   (qt-plain-text-edit-insert-text! ed (string ch))
                                   (loop (+ i 1)))))
                              ;; Terminal: if PTY busy, send to PTY (honors echo settings);
                              ;; otherwise insert locally (gsh line mode)
                              ((terminal-buffer? buf)
                               (let ((ts (hash-get *terminal-state* buf)))
                                 (if (and ts (terminal-pty-busy? ts))
                                   ;; PTY running — send keystroke to child process
                                   ;; The PTY handles echo (hides password input, etc.)
                                   (terminal-send-input! ts (string ch))
                                   ;; No PTY — local line editing
                                   (let loop ((i 0))
                                     (when (< i n)
                                       (qt-plain-text-edit-insert-text! ed (string ch))
                                       (loop (+ i 1)))))))
                              ;; Shell: if PTY busy, send to PTY; otherwise insert locally
                              ((shell-buffer? buf)
                               (let ((ss (hash-get *shell-state* buf)))
                                 (if (and ss (shell-pty-busy? ss))
                                   ;; PTY running — send keystroke to child process
                                   (shell-send-input! ss (string ch))
                                   ;; No PTY — local line editing
                                   (let loop ((i 0))
                                     (when (< i n)
                                       (qt-plain-text-edit-insert-text! ed (string ch))
                                       (loop (+ i 1)))))))
                              (else
                               ;; Delete-selection-mode: when OFF, deselect before insert
                               ;; so typed text doesn't replace selection
                               (when (not *qt-delete-selection-enabled*)
                                 (let ((pos (qt-plain-text-edit-cursor-position ed)))
                                   (sci-send ed SCI_SETSEL pos pos)))
                               (cond
                                 ;; Auto-pair skip-over: typing closing delimiter when next char matches
                                 ((and *auto-pair-mode* (= n 1)
                                       (auto-pair-closing? (char->integer ch)))
                                  (let* ((pos (qt-plain-text-edit-cursor-position ed))
                                         (text (qt-plain-text-edit-text ed))
                                         (next-ch (and (< pos (string-length text))
                                                       (string-ref text pos))))
                                    (if (and next-ch (char=? next-ch ch))
                                      ;; Skip over existing closing char
                                      (qt-plain-text-edit-set-cursor-position! ed (+ pos 1))
                                      ;; No match — insert normally
                                      (qt-plain-text-edit-insert-text! ed (string ch)))))
                                 ;; Auto-pair: insert both chars and place cursor between
                                 ((and close-ch (= n 1))
                                  (let ((pos (qt-plain-text-edit-cursor-position ed)))
                                    (qt-plain-text-edit-insert-text! ed (string ch close-ch))
                                    (qt-plain-text-edit-set-cursor-position! ed (+ pos 1))))
                                 ;; Insert character n times
                                 (else
                                  (let ((str (make-string n ch)))
                                    (qt-plain-text-edit-insert-text! ed str)))))))
                          ;; Auto-fill: break line if past fill-column
                          (auto-fill-check! (qt-current-editor (app-state-frame app)))
                          ;; Abbrev auto-expansion: when word separator typed,
                          ;; check if preceding word is a defined abbreviation
                          (when (and *abbrev-mode-enabled*
                                     (let ((c (string-ref data 0)))
                                       (or (char=? c #\space) (char=? c #\newline)
                                           (char=? c #\,) (char=? c #\.) (char=? c #\;))))
                            (let* ((aed (qt-current-editor (app-state-frame app)))
                                   (pos (qt-plain-text-edit-cursor-position aed))
                                   (text (qt-plain-text-edit-text aed))
                                   (sep-pos (- pos 1))
                                   (word-end sep-pos)
                                   (word-start
                                     (let loop ((i (- sep-pos 1)))
                                       (if (< i 0) 0
                                         (let ((c (string-ref text i)))
                                           (if (or (char-alphabetic? c) (char-numeric? c)
                                                   (char=? c #\-) (char=? c #\_))
                                             (loop (- i 1))
                                             (+ i 1))))))
                                   (word (if (> word-end word-start)
                                           (substring text word-start word-end)
                                           "")))
                              (let ((expansion (hash-get *abbrev-table* word)))
                                (when expansion
                                  (qt-plain-text-edit-set-selection! aed word-start word-end)
                                  (qt-plain-text-edit-remove-selected-text! aed)
                                  (qt-plain-text-edit-insert-text! aed expansion)
                                  (echo-message! (app-state-echo app)
                                    (string-append "\"" word "\" → \"" expansion "\""))))))
                          ;; Aggressive indent: reindent current line after closing delimiters
                          (let ((si-ch (string-ref data 0)))
                            (when (and *aggressive-indent-mode*
                                       (memv si-ch '(#\) #\] #\} #\newline)))
                              (qt-aggressive-indent-line!
                               (qt-current-editor (app-state-frame app)))))
                          ;; Track edit position for goto-last-change
                          (qt-record-edit-position! app)
                          (set! (app-state-prefix-arg app) #f)
                           (set! (app-state-prefix-digit-mode? app) #f))))) ; Reset prefix arg
                         ((prefix)
                          (let ((prefix-str
                                 (let loop ((keys (key-state-prefix-keys new-state))
                                            (acc ""))
                                   (if (null? keys) acc
                                     (loop (cdr keys)
                                           (if (string=? acc "")
                                             (car keys)
                                             (string-append acc " " (car keys))))))))
                            (echo-message! (app-state-echo app)
                                           (string-append prefix-str "-"))
                            ;; Start which-key timer if mode is enabled
                            (when *which-key-mode*
                              (set! *which-key-pending-keymap*
                                    (key-state-keymap new-state))
                              (set! *which-key-pending-prefix* prefix-str)
                              (qt-timer-start! *which-key-timer*
                                (inexact->exact (round (* *which-key-delay* 1000)))))))
                         ((undefined)
                          (echo-error! (app-state-echo app)
                                       (string-append data " is undefined")))
                         ((ignore) (void)))))  ;; bare modifier keys — do nothing (extra parens close quoted-insert + describe-key ifs)
                       ;; Update visual decorations (current-line + brace match)
                       (qt-update-visual-decorations!
                         (qt-current-editor (app-state-frame app)))
                       ;; Update mark/region visual selection
                       (qt-update-mark-selection! app)
                       ;; Update modeline, tab bar, title, and echo after each key
                       (qt-modeline-update! app)
                       (qt-tabbar-update! app)
                       (qt-update-frame-title! app)
                       (qt-echo-draw! (app-state-echo app) echo-label)))))))))  ;; extra parens close begin + repeat-map if + prefix-autorepeat if/let + pty-intercept if
                  ;; QTerminalWidget key forwarding: send non-command keys directly
                  ;; to the terminal widget, bypassing chord detection and self-insert.
                  ;; C-x prefix and M-x pass through to jemacs keymap.
                  ;;
                  ;; FOCUS GUARD: only forward to the terminal if the key event came
                  ;; FROM the QTerminalWidget itself. If the user clicked a different
                  ;; window (so the key came from that window's QScintilla), we must
                  ;; NOT forward to the terminal even if qt-current-buffer is still
                  ;; a terminal buffer (Chez state may lag the Qt focus change).
                  (let* ((qt-buf (qt-current-buffer (app-state-frame app)))
                         (qt-term (and qt-buf (hash-get *terminal-widget-map* qt-buf)))
                         (key-src-widget (qt-last-key-widget))
                         (key-from-terminal? (and qt-term
                                                   (equal? key-src-widget
                                                           (qt-terminal-widget qt-term)))))
                    (if (and qt-term
                             key-from-terminal?  ;; key must come FROM this terminal widget
                             ;; Not in a prefix key state (e.g. after C-x)
                             (null? (key-state-prefix-keys (app-state-key-state app)))
                             ;; Allow C-x to pass through to jemacs
                             (not (and (not (zero? (bitwise-and mods QT_MOD_CTRL)))
                                       (zero? (bitwise-and mods QT_MOD_ALT))
                                       (= code (+ QT_KEY_A 23))))  ;; C-x
                             ;; Allow M-x to pass through to jemacs
                             (not (and (not (zero? (bitwise-and mods QT_MOD_ALT)))
                                       (zero? (bitwise-and mods QT_MOD_CTRL))
                                       (= code (+ QT_KEY_A 23))))) ;; M-x
                      ;; Forward to terminal widget
                      (qt-terminal-send-key-event! qt-term code mods (or text ""))
                  ;; Normal: chord detection logic
                  (let ((is-printable (and (= (string-length text) 1)
                                           (> (char->integer (string-ref text 0)) 31)))
                        (no-ctrl (zero? (bitwise-and mods QT_MOD_CTRL)))
                        (no-alt  (zero? (bitwise-and mods QT_MOD_ALT))))
                    (verbose-log! "CHORD-CHECK pending=" (if *chord-pending-char* (string *chord-pending-char*) "#f")
                                  " key=" (if (and is-printable no-ctrl no-alt) text "non-printable")
                                  " chord-start?=" (if (and is-printable no-ctrl no-alt)
                                                     (if (chord-start-char? (string-ref text 0)) "Y" "N")
                                                     "N/A")
                                  " autorepeat=" (if autorepeat? "Y" "N")
                                  " prefix=" (if (null? (key-state-prefix-keys (app-state-key-state app))) "none" "active"))
                  (cond
                    ;; Case 1: A chord is pending and a new key arrived
                    ((and *chord-pending-char* (not *chord-timer-fired*))
                     (let* ((ch1 *chord-pending-char*)
                            (saved-code *chord-pending-code*)
                            (saved-mods *chord-pending-mods*)
                            (saved-text *chord-pending-text*)
                            ;; Is the new key also a plain printable character?
                            (ch2 (and (= (string-length text) 1)
                                      (> (char->integer (string-ref text 0)) 31)
                                      (zero? (bitwise-and mods QT_MOD_CTRL))
                                      (zero? (bitwise-and mods QT_MOD_ALT))
                                      (string-ref text 0))))
                       ;; Auto-repeat filter: Qt reports isAutoRepeat for held keys.
                       ;; Always ignore auto-repeat when a chord is pending — even for
                       ;; same-char chords (EE, GG) since auto-repeat is NOT two presses.
                       (cond
                         (autorepeat?
                           (verbose-log! "CHORD-AUTOREPEAT ignored ch=" (string ch1))
                           (void))  ;; ignore auto-repeat, timer keeps running
                         ;; Ignore bare modifier key releases (Shift, Ctrl, Alt, Meta).
                         ;; When typing uppercase chord chars (TM), the Shift release
                         ;; arrives between T and M — don't let it cancel the chord.
                         ;; Qt key codes: Shift=#x01000020, Ctrl=#x01000021, Meta=#x01000022,
                         ;; Alt=#x01000023, Super=#x01000053, Hyper=#x01000054, AltGr=#x01001103
                         ((and (not ch2)
                               (or (and (>= code #x01000020) (<= code #x01000025))
                                   (= code #x01000053) (= code #x01000054)
                                   (= code #x01001103)))
                           (verbose-log! "CHORD-IGNORE-MODIFIER pending=" (string ch1)
                                         " code=" (number->string code))
                           (void))  ;; ignore bare modifier, timer keeps running
                         ;; Non-chord key while chord pending (e.g. M-x, C-s, Escape):
                         ;; cancel the chord, replay the pending key, process current key.
                         ((not ch2)
                           (verbose-log! "CHORD-CANCEL-NONCHORD pending=" (string ch1)
                                         " code=" (number->string code))
                           (qt-timer-stop! *chord-timer*)
                           (set! *chord-pending-char* #f)
                           (do-normal-key! saved-code saved-mods saved-text)
                           (do-normal-key! code mods text))
                         (else
                         ;; Real second printable key — resolve the chord
                         (let ((chord-cmd (chord-lookup ch1 ch2)))
                           (verbose-log! "CHORD-RESOLVE ch1=" (string ch1)
                                         " ch2=" (string ch2)
                                         " cmd=" (if chord-cmd (symbol->string chord-cmd) "#f"))
                           (qt-timer-stop! *chord-timer*)
                           (set! *chord-pending-char* #f)
                           (if chord-cmd
                         ;; Chord matched — execute the chord command
                         (begin
                           (execute-command! app chord-cmd)
                           (qt-update-visual-decorations!
                             (qt-current-editor (app-state-frame app)))
                           (qt-update-mark-selection! app)
                           (qt-modeline-update! app)
                           (qt-tabbar-update! app)
                           (qt-update-frame-title! app)
                           (qt-echo-draw! (app-state-echo app) echo-label))
                         ;; No chord — replay saved key then process current key
                         (begin
                           (do-normal-key! saved-code saved-mods saved-text)
                           (do-normal-key! code mods text))))))))

                    ;; Case 2: Printable key that could start a chord — save and wait
                    ;; Works in ALL buffer types including terminal/shell.
                    ;; If the chord doesn't match, the replayed keys go through
                    ;; do-normal-key! which sends them to the PTY as usual.
                    ;; Skip auto-repeat keys — holding a key should not start a chord.
                    ((and (not autorepeat?)
                          (= (string-length text) 1)
                          (> (char->integer (string-ref text 0)) 31)
                          (zero? (bitwise-and mods QT_MOD_CTRL))
                          (zero? (bitwise-and mods QT_MOD_ALT))
                          (null? (key-state-prefix-keys (app-state-key-state app)))
                          (chord-start-char? (string-ref text 0)))
                     (verbose-log! "CHORD-PENDING ch=" (string (string-ref text 0))
                                   " timeout=" (number->string *chord-timeout*) "ms")
                     (set! *chord-pending-char* (string-ref text 0))
                     (set! *chord-pending-code* code)
                     (set! *chord-pending-mods* mods)
                     (set! *chord-pending-text* text)
                     (set! *chord-timer-fired* #f)
                     (qt-timer-start! *chord-timer* *chord-timeout*))

                    ;; Case 3: Normal key — no chord involvement
                    (else
                     (do-normal-key! code mods text))))))))))))))  ; extra parens close let + if + let* (terminal) + minibuffer-active? when

        ;; Install on the initial editor (consuming — editor doesn't see keys)
        (qt-on-key-press-consuming! (qt-current-editor fr) key-handler)

        ;; Store installer so split-window can install on new editors
        (set! (app-state-key-handler app)
              (lambda (editor)
                (qt-on-key-press-consuming! editor key-handler)))

        ;; Tell automation which widget to target for key events.
        ;; When a terminal buffer is active, the QTerminalWidget is the visible
        ;; focused widget; the QScintilla editor is hidden behind it in the
        ;; QStackedWidget. Sending sendEvent to a non-current QStackedWidget
        ;; page is unreliable — use the visible QTerminalWidget instead.
        (automation-set-key-target-fn!
          (lambda (fr)
            (let* ((buf (qt-current-buffer fr))
                   (term (and buf (hash-get *terminal-widget-map* buf))))
              (if term
                (qt-terminal-widget term)
                (qt-current-editor fr)))))

        ;; Install pre-container-destroy hook so that when any window container
        ;; (QStackedWidget) is about to be destroyed (by delete-other-windows,
        ;; C-x 0, kill-terminal-buffer, etc.), any terminal living inside it
        ;; is detached and destroyed first — preventing the double-free crash
        ;; that occurs when Qt auto-deletes the terminal as a child.
        (qt-window-set-pre-container-destroy-fn!
          (lambda (container)
            (let ((bufs-to-remove '()))
              (hash-for-each
                (lambda (buf stored-container)
                  (when (equal? stored-container container)
                    (let ((term (hash-get *terminal-widget-map* buf)))
                      (when term
                        (with-catch (lambda (e) #f)
                          (lambda () (qt-terminal-destroy! term)))))
                    (set! bufs-to-remove (cons buf bufs-to-remove))))
                *terminal-container-map*)
              (for-each
                (lambda (buf)
                  (hash-remove! *terminal-widget-map* buf)
                  (hash-remove! *terminal-container-map* buf))
                bufs-to-remove)))))

      ;; ================================================================
      ;; Periodic tasks — registered with schedule-periodic!, driven
      ;; by one master Qt timer that also drains the async UI queue.
      ;; ================================================================

      ;; REPL/Shell/Terminal/Chat output polling (50ms)
      (schedule-periodic! 'repl-poll 50
        (lambda ()
          (for-each
            (lambda (buf)
              (when (repl-buffer? buf)
                (let ((rs (hash-get *repl-state* buf)))
                  (when rs
                    (let ((output (repl-read-available rs)))
                      (when output
                        ;; Find a window showing this buffer
                        (let loop ((wins (qt-frame-windows fr)))
                          (when (pair? wins)
                            (if (eq? (qt-edit-window-buffer (car wins)) buf)
                              (let* ((ed (qt-edit-window-editor (car wins)))
                                     ;; Strip trailing newline — append! adds its own
                                     (trimmed (string-trim-eol output)))
                                ;; Insert output (subprocess sends its own prompt)
                                (qt-plain-text-edit-append! ed trimmed)
                                (set! (repl-state-prompt-pos rs)
                                  (string-length (qt-plain-text-edit-text ed)))
                                (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                                (qt-plain-text-edit-ensure-cursor-visible! ed))
                              (loop (cdr wins)))))))))))
            (buffer-list))
          ;; Poll Shell/Terminal PTY output
          ;; Guard against re-entrancy: qt-app-process-events! inside
          ;; qt-poll-terminal-pty-batch! can fire this timer again, causing
          ;; terminal output to bleed across buffers.
          (unless *pty-poll-in-progress?*
          (dynamic-wind
            (lambda () (set! *pty-poll-in-progress?* #t))
            (lambda ()
          (for-each
            (lambda (buf)
              (when (shell-buffer? buf)
                (let ((ss (hash-get *shell-state* buf)))
                  ;; Resize shell PTY + vtscreen when editor dimensions change
                  (when (and ss (shell-pty-busy? ss))
                    (let ((vt (shell-state-vtscreen ss)))
                      (when vt
                        (let ed-loop ((wins (qt-frame-windows fr)))
                          (when (pair? wins)
                            (if (eq? (qt-edit-window-buffer (car wins)) buf)
                              (let* ((ed (qt-edit-window-editor (car wins)))
                                     (new-rows (max 2 (sci-send ed 2370 0)))
                                     (widget-w (qt-widget-width ed))
                                     (margin-w (sci-send ed SCI_GETMARGINWIDTHN 0))
                                     (text-w (- widget-w margin-w 16))
                                     (char-w (let ((w (sci-send/string ed 2276 "M" STYLE_DEFAULT)))
                                               (if (> w 0) w 8)))
                                     (new-cols (max 20 (quotient text-w char-w)))
                                     (old-rows (vtscreen-rows vt))
                                     (old-cols (vtscreen-cols vt)))
                                (when (or (not (= new-rows old-rows))
                                          (not (= new-cols old-cols)))
                                  (verbose-log! "SHELL-PTY-RESIZE: "
                                    (number->string old-rows) "x" (number->string old-cols)
                                    " -> "
                                    (number->string new-rows) "x" (number->string new-cols))
                                  (vtscreen-resize! vt new-rows new-cols)
                                  (shell-pty-resize! ss new-rows new-cols)))
                              (ed-loop (cdr wins))))))))
                  (when (and ss (shell-pty-busy? ss))
                    (let drain ()
                      (let ((msg (shell-poll-output ss)))
                        (when msg
                          (qt-poll-shell-pty-msg! fr buf ss msg)
                          (when (eq? (car msg) 'data)
                            (drain))))))))
              (when (terminal-buffer? buf)
                (let ((ts (hash-get *terminal-state* buf)))
                  ;; Resize PTY + vtscreen when editor dimensions change.
                  ;; Must run even when PTY is idle so splits/resizes take
                  ;; effect before the next command is typed.
                  (when ts
                    (let ((vt (terminal-state-vtscreen ts)))
                      (when vt
                        ;; Find editor widget for this buffer
                        (let ed-loop ((wins (qt-frame-windows fr)))
                          (when (pair? wins)
                            (if (eq? (qt-edit-window-buffer (car wins)) buf)
                              (let* ((ed (qt-edit-window-editor (car wins)))
                                     (new-rows (max 2 (sci-send ed 2370 0)))
                                     (widget-w (qt-widget-width ed))
                                     (margin-w (sci-send ed SCI_GETMARGINWIDTHN 0))
                                     (text-w (- widget-w margin-w 16))
                                     (char-w (let ((w (sci-send/string ed 2276 "M" STYLE_DEFAULT)))
                                               (if (> w 0) w 8)))
                                     (new-cols (max 20 (quotient text-w char-w)))
                                     (old-rows (vtscreen-rows vt))
                                     (old-cols (vtscreen-cols vt)))
                                (when (or (not (= new-rows old-rows))
                                          (not (= new-cols old-cols)))
                                  (verbose-log! "PTY-RESIZE: "
                                    (number->string old-rows) "x" (number->string old-cols)
                                    " -> "
                                    (number->string new-rows) "x" (number->string new-cols))
                                  (vtscreen-resize! vt new-rows new-cols)
                                  (when (terminal-pty-busy? ts)
                                    (terminal-resize! ts new-rows new-cols))
                                  ;; Invalidate row cache after resize
                                  (hash-remove! *vterm-row-cache* ts)
                                  ;; Force full re-render on next cycle
                                  (hash-put! *vterm-initialized* ts #f)))
                              (ed-loop (cdr wins))))))))
                  (when (and ts (terminal-pty-busy? ts))
                    ;; Batch pending data chunks up to a byte budget, then render.
                    ;; Cap prevents flooding commands (find ~/ -ls) from blocking
                    ;; the Qt event loop — excess data stays in the channel for
                    ;; the next tick.
                    (let drain ((chunks []) (bytes 0) (done-msg #f))
                      (if (and (> bytes 0) (>= bytes *pty-batch-budget*))
                        ;; Budget exhausted — render what we have, leave rest for next tick
                        (let ((combined (apply string-append (reverse chunks))))
                          (verbose-log! "PTY-BATCH-CAP: " (number->string (string-length combined)) " bytes (capped)")
                          (qt-poll-terminal-pty-batch! fr buf ts combined))
                        (let ((msg (terminal-poll-output ts)))
                          (cond
                            ((not msg)
                             ;; No more messages — render accumulated data
                             (if (pair? chunks)
                               (let ((combined (apply string-append (reverse chunks))))
                                 (verbose-log! "PTY-BATCH: " (number->string (string-length combined)) " bytes")
                                 (qt-poll-terminal-pty-batch! fr buf ts combined))
                               ;; No new data — flush any throttled render
                               (when (and (terminal-state-vtscreen ts)
                                          (hash-ref *vterm-initialized* ts #f)
                                          (vterm-render-due? ts))
                                 (qt-poll-terminal-pty-batch! fr buf ts "")))
                             (when done-msg
                               (qt-poll-terminal-pty-msg! fr buf ts done-msg)))
                            ((eq? (car msg) 'data)
                             (drain (cons (cdr msg) chunks)
                                    (+ bytes (string-length (cdr msg)))
                                    done-msg))
                            (else
                             ;; 'done message — render data first, then handle done
                             (when (pair? chunks)
                               (let ((combined (apply string-append (reverse chunks))))
                                 (verbose-log! "PTY-BATCH+DONE: " (number->string (string-length combined)) " bytes")
                                 (qt-poll-terminal-pty-batch! fr buf ts combined)))
                             (qt-poll-terminal-pty-msg! fr buf ts msg))))))))))
            (buffer-list)))
            (lambda () (set! *pty-poll-in-progress?* #f))))  ;; end re-entrancy guard
          ;; Poll chat buffers (Claude CLI)
          (for-each
            (lambda (buf)
              (when (chat-buffer? buf)
                (let ((cs (hash-get *chat-state* buf)))
                  (when (and cs (chat-busy? cs))
                    (let ((result (chat-read-available cs)))
                      (when result
                        (let loop ((wins (qt-frame-windows fr)))
                          (when (pair? wins)
                            (if (eq? (qt-edit-window-buffer (car wins)) buf)
                              (let ((ed (qt-edit-window-editor (car wins))))
                                (cond
                                  ((string? result)
                                   (sci-send/string ed SCI_APPENDTEXT result (string-length result))
                                   (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                                   (qt-plain-text-edit-ensure-cursor-visible! ed))
                                  ((and (pair? result) (string? (car result)))
                                   (let ((chunk (car result)))
                                     (sci-send/string ed SCI_APPENDTEXT chunk (string-length chunk)))
                                   (qt-plain-text-edit-append! ed "\nYou: ")
                                   (set! (chat-state-prompt-pos cs)
                                     (string-length (qt-plain-text-edit-text ed)))
                                   (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                                   (qt-plain-text-edit-ensure-cursor-visible! ed))
                                  ((eq? result 'done)
                                   (qt-plain-text-edit-append! ed "\nYou: ")
                                   (set! (chat-state-prompt-pos cs)
                                     (string-length (qt-plain-text-edit-text ed)))
                                   (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                                   (qt-plain-text-edit-ensure-cursor-visible! ed))))
                              (loop (cdr wins)))))))))))
            (buffer-list))))

      ;; Auto-save (30 seconds)
      ;; Collect text snapshots on UI thread (fast), write files in background
      (schedule-periodic! 'auto-save 30000
        (lambda ()
          ;; Phase 1: Collect snapshots on UI thread (must access Qt widgets here)
          (let ((save-jobs '()))
            (for-each
              (lambda (buf)
                (let ((path (buffer-file-path buf)))
                  (when (and path
                             (buffer-doc-pointer buf)
                             (qt-text-document-modified? (buffer-doc-pointer buf)))
                    (let loop ((wins (qt-frame-windows fr)))
                      (when (pair? wins)
                        (if (eq? (qt-edit-window-buffer (car wins)) buf)
                          (let* ((ed (qt-edit-window-editor (car wins)))
                                 (text (qt-plain-text-edit-text ed))
                                 (auto-path (qt-make-auto-save-path path)))
                            (set! save-jobs (cons (cons auto-path text) save-jobs)))
                          (loop (cdr wins))))))))
              (buffer-list))
            ;; Phase 2: Write auto-save files synchronously (avoids GC deadlock)
            (for-each
              (lambda (job)
                (with-catch
                  (lambda (e) (jemacs-log! "Auto-save error: "
                               (with-output-to-string (lambda () (display-condition e)))))
                  (lambda ()
                    (let ((p (open-output-file (car job) 'replace)))
                      (display (cdr job) p)
                      (close-port p)))))
              save-jobs))
          ;; Cache scratch buffer text for persistence (fast, stays on UI thread)
          (let ((scratch (buffer-by-name "*scratch*")))
            (when scratch
              (let loop ((wins (qt-frame-windows fr)))
                (when (pair? wins)
                  (if (eq? (qt-edit-window-buffer (car wins)) scratch)
                    (scratch-update-text!
                      (qt-plain-text-edit-text
                        (qt-edit-window-editor (car wins))))
                    (loop (cdr wins)))))))
          ;; Record undo history snapshots for modified buffers (fast, stays on UI thread)
          (for-each
            (lambda (win)
              (let* ((buf (qt-edit-window-buffer win))
                     (doc (buffer-doc-pointer buf)))
                (when (and doc (qt-text-document-modified? doc))
                  (let ((text (qt-plain-text-edit-text (qt-edit-window-editor win))))
                    (undo-history-record! (buffer-name buf) text)))))
            (qt-frame-windows fr))))

      ;; File modification watcher (5 seconds)
      ;; Mtime check on UI thread (fast stat), file read in background
      (schedule-periodic! 'file-watch 5000
        (lambda ()
          (when *auto-revert-mode*
            (for-each
              (lambda (buf)
                (let ((path (buffer-file-path buf))
                      (tail? (hash-get *auto-revert-tail-buffers* (buffer-name buf))))
                  (when (and path (file-mtime-changed? path))
                    (let ((doc (buffer-doc-pointer buf)))
                      (if (and (not tail?)
                               doc (qt-text-document-modified? doc))
                        (echo-message! (app-state-echo app)
                          (string-append (buffer-name buf)
                            " changed on disk (buffer modified, not reverting)"))
                        ;; Read file in background, update widget on UI thread
                        (async-read-file! path
                          (lambda (text)
                            (when text
                              (let loop ((wins (qt-frame-windows fr)))
                                (when (pair? wins)
                                  (if (eq? (qt-edit-window-buffer (car wins)) buf)
                                    (let* ((ed (qt-edit-window-editor (car wins)))
                                           (pos (qt-plain-text-edit-cursor-position ed)))
                                      (qt-plain-text-edit-set-text! ed text)
                                      (qt-text-document-set-modified! doc #f)
                                      (if tail?
                                        (begin
                                          (qt-plain-text-edit-move-cursor! ed QT_CURSOR_END)
                                          (qt-plain-text-edit-ensure-cursor-visible! ed))
                                        (begin
                                          (qt-plain-text-edit-set-cursor-position! ed
                                            (min pos (string-length text)))
                                          (qt-plain-text-edit-ensure-cursor-visible! ed)))
                                      (file-mtime-record! path))
                                    (loop (cdr wins)))))))))))))
              (buffer-list)))))

      ;; NOTE: auto-save is registered earlier in this function (line ~941)
      ;; with better error handling and undo-history snapshot support.
      ;; Do not register a duplicate auto-save here.

      ;; Pulse-line: tick countdown + auto-detect large jumps
      (schedule-periodic! 'pulse 50
        (lambda ()
          (qt-pulse-tick!)
          (qt-pulse-check-jump! app)))

      ;; Eldoc / LSP cursor-idle (300ms)
      (schedule-periodic! 'eldoc 300
        (lambda ()
          (if (lsp-running?)
            (begin
              (lsp-eldoc-display! app)
              (lsp-diagnostic-at-cursor! app)
              (lsp-document-highlight! app)
              (lsp-inlay-hint-at-cursor! app))
            (begin
              (eldoc-display! app)
              ;; Auto-highlight symbol under cursor (non-LSP buffers)
              (qt-idle-highlight-symbol! app)))))

      ;; LSP auto-completion (500ms)
      (schedule-periodic! 'lsp-auto-complete 500
        (lambda () (lsp-auto-complete! app)))

      ;; LSP UI actions now drained by master timer via unified ui-queue

      ;; LSP didChange — send buffer content 1s after last edit
      (schedule-periodic! 'lsp-change 1000
        (lambda ()
          (when (lsp-running?)
            (let* ((fr (app-state-frame app))
                   (buf (qt-current-buffer fr))
                   (ed (qt-current-editor fr)))
              (when (and buf (buffer-file-path buf))
                (let* ((path (buffer-file-path buf))
                       (uri (file-path->uri path))
                       (text (qt-plain-text-edit-text ed)))
                  (when (lsp-content-changed? uri text)
                    (lsp-hook-did-change! app buf)
                    (lsp-record-sent-content! uri text))))))))

      ;; Install LSP UI handlers
      (lsp-install-handlers! app)

      ;; Which-key timer (one-shot, shows available prefix bindings)
      (set! *which-key-timer* (qt-timer-create))
      (qt-timer-set-single-shot! *which-key-timer* #t)
      (qt-on-timeout! *which-key-timer*
        (lambda ()
          (when (and *which-key-pending-keymap*
                     (not (null? (key-state-prefix-keys
                                   (app-state-key-state app)))))
            (echo-message! (app-state-echo app)
              (which-key-format-bindings
                *which-key-pending-keymap*
                *which-key-pending-prefix*)))))

      ;; Key-chord timer (one-shot, replays pending key on timeout)
      (set! *chord-timer* (qt-timer-create))
      (qt-timer-set-single-shot! *chord-timer* #t)
      (qt-on-timeout! *chord-timer*
        (lambda ()
          (verbose-log! "CHORD-TIMEOUT fired pending="
                        (if *chord-pending-char* (string *chord-pending-char*) "#f"))
          (when *chord-pending-char*
            (let ((saved-code *chord-pending-code*)
                  (saved-mods *chord-pending-mods*)
                  (saved-text *chord-pending-text*))
              (set! *chord-pending-char* #f)
              (set! *chord-timer-fired* #t)
              ;; Replay the pending key through normal key processing
              (let-values (((action data new-state)
                            (qt-key-state-feed! (app-state-key-state app)
                                                saved-code saved-mods saved-text)))
                (set! (app-state-key-state app) new-state)
                (case action
                  ((self-insert)
                   (let* ((buf (qt-current-buffer (app-state-frame app)))
                          (mode-cmd (mode-keymap-lookup buf data)))
                     (if mode-cmd
                       (execute-command! app mode-cmd)
                       (let* ((ed (qt-current-editor (app-state-frame app)))
                              (ch (string-ref data 0)))
                         (qt-plain-text-edit-insert-text! ed (string ch))))))
                  ((command)
                   (execute-command! app data))
                  (else (void)))
                ;; Update UI
                (qt-update-visual-decorations!
                  (qt-current-editor (app-state-frame app)))
                (qt-modeline-update! app)
                (qt-tabbar-update! app)
                (qt-update-frame-title! app)
                (qt-echo-draw! (app-state-echo app) echo-label))))))

      ;; Restore session if desktop-save-mode is on and no files given on command line
      ;; Files are read in parallel (async-read-file! in qt-open-file!)
      (when (and *qt-desktop-save-mode* (null? args))
        (let-values (((current-file entries) (session-restore-files)))
          (for-each
            (lambda (entry)
              (let ((path (car entry))
                    (pos (cdr entry)))
                (when (and (file-exists? path) (not (file-directory? path)))
                  (qt-open-file! app path
                    ;; Restore cursor position after async file load
                    (lambda (app buf)
                      (let ((ed (qt-current-editor (app-state-frame app))))
                        (qt-plain-text-edit-set-cursor-position! ed
                          (min pos (string-length (qt-plain-text-edit-text ed))))
                        (qt-plain-text-edit-ensure-cursor-visible! ed)))))))
            entries)
          ;; Switch to the buffer that was current when session was saved
          (when current-file
            (let loop ((bufs (buffer-list)))
              (when (pair? bufs)
                (if (equal? (buffer-file-path (car bufs)) current-file)
                  (let ((ed (qt-current-editor fr)))
                    (qt-buffer-attach! ed (car bufs))
                    (set! (qt-edit-window-buffer (qt-current-window fr)) (car bufs)))
                  (loop (cdr bufs))))))))

      ;; Open files from command line — skip flags and their arguments
      ;; parse-repl-port returns (port . filtered-args) with --repl <port> removed
      (let* ((repl-parsed (parse-repl-port args))
             (clean-args (if repl-parsed (cdr repl-parsed) args))
             (files (filter (lambda (a) (not (string-prefix? "-" a))) clean-args)))
        (for-each (lambda (file) (qt-open-file! app file)) files))

      ;; Show window
      (qt-main-window-set-central-widget! win central)
      (qt-main-window-set-title! win "jemacs")
      (qt-widget-resize! win 800 600)
      (qt-widget-show! win)

      ;; Initial modeline, tab bar, and title update (before any key press)
      (qt-modeline-update! app)
      (qt-tabbar-update! app)
      (qt-update-frame-title! app)

      ;; Start IPC server for jemacs-client
      (start-ipc-server!)
      ;; Start debug REPL if --repl <port> or GEMACS_REPL_PORT is set
      (let* ((repl-port-env (getenv "GEMACS_REPL_PORT" #f))
             (repl-info     (or (parse-repl-port args)
                                (and repl-port-env
                                     (cons (string->number repl-port-env) args)))))
        (when repl-info
          (start-debug-repl! (car repl-info))
          ;; Register key bindings so IPC REPL can access the running app.
          ;; Only use identifiers that are in scope (imported or defined in this module).
          (for-each
            (lambda (pair) (debug-repl-bind! (car pair) (cdr pair)))
            (list
              (cons '*app* app)
              (cons 'app-state-frame app-state-frame)
              (cons 'app-state-key-state app-state-key-state)
              (cons 'app-state-echo app-state-echo)
              (cons 'qt-current-editor qt-current-editor)
              (cons 'qt-current-buffer qt-current-buffer)
              (cons 'qt-plain-text-edit-cursor-position qt-plain-text-edit-cursor-position)
              (cons 'qt-plain-text-edit-read-only? qt-plain-text-edit-read-only?)
              (cons 'qt-plain-text-edit-has-selection? qt-plain-text-edit-has-selection?)
              (cons 'qt-plain-text-edit-insert-text! qt-plain-text-edit-insert-text!)
              (cons 'qt-plain-text-edit-set-selection! qt-plain-text-edit-set-selection!)
              (cons 'qt-plain-text-edit-remove-selected-text! qt-plain-text-edit-remove-selected-text!)
              (cons 'sci-send sci-send)
              (cons 'execute-command! execute-command!)
              (cons 'find-command find-command)
              (cons 'verbose-log! verbose-log!)
              (cons 'key-state-prefix-keys key-state-prefix-keys)
              (cons '*chord-map* *chord-map*)
              (cons '*chord-mode* *chord-mode*)
              (cons '*chord-timeout* *chord-timeout*)
              (cons 'chord-start-char? chord-start-char?)
              (cons 'chord-lookup chord-lookup)
              ;; Chord state accessors (live values, not frozen snapshots)
              (cons 'chord-pending-char (lambda () *chord-pending-char*))
              (cons 'chord-pending-info
                    (lambda () (list 'pending *chord-pending-char*
                                     'code *chord-pending-code*
                                     'mods *chord-pending-mods*
                                     'text *chord-pending-text*)))
              ;; Buffer type predicates
              (cons 'terminal-buffer? terminal-buffer?)
              (cons 'shell-buffer? shell-buffer?)
              (cons 'gsh-eshell-buffer? gsh-eshell-buffer?)
              (cons 'buffer-lexer-lang buffer-lexer-lang)
              ;; Text and key helpers
              (cons 'qt-plain-text-edit-text qt-plain-text-edit-text)
              (cons 'qt-key-event->string qt-key-event->string)
              (cons 'make-initial-key-state make-initial-key-state)
              ;; Testing helpers
              (cons 'qt-open-file! qt-open-file!)
              (cons 'buffer-name buffer-name)
              (cons 'buffer-text
                    (lambda ()
                      (let* ((fr (app-state-frame app))
                             (ed (qt-current-editor fr)))
                        (if ed (qt-plain-text-edit-text ed) ""))))
              (cons 'buffer-cursor-pos
                    (lambda ()
                      (let* ((fr (app-state-frame app))
                             (ed (qt-current-editor fr)))
                        (if ed (qt-plain-text-edit-cursor-position ed) 0))))
              (cons 'current-buffer-name
                    (lambda ()
                      (let* ((fr (app-state-frame app))
                             (buf (qt-current-buffer fr)))
                        (if buf (buffer-name buf) "#<none>"))))
              ;; Automation bridge (for Claude)
              ;; send-keys! : synchronous, drains inline (for non-blocking commands)
              ;; send-keys-async! : fire-and-forget (for M-x, C-x C-f, etc.)
              (cons 'send-keys!
                    (lambda keys (apply automation-send-keys! app keys)))
              (cons 'send-keys-async!
                    (lambda keys (apply automation-send-keys-async! app keys)))
              (cons 'screenshot!
                    (lambda (path) (automation-screenshot! app path)))
              (cons 'app-state
                    (lambda () (automation-state app)))
              (cons 'wait-echo!
                    (lambda (pat ms)
                      (automation-wait! app
                        (lambda (state)
                          (let ((mb (cdr (assq 'minibuffer state))))
                            mb))
                        ms)))
              ;; ---- Test-infrastructure helpers (test-behavioral.ss) ----
              ;; Number of open windows
              (cons 'test-window-count
                    (lambda ()
                      (length (qt-frame-windows (app-state-frame app)))))
              ;; Buffer name for each open window, in order
              (cons 'test-window-buffers
                    (lambda ()
                      (map (lambda (win)
                             (let ((buf (qt-edit-window-buffer win)))
                               (if buf (buffer-name buf) "#<none>")))
                           (qt-frame-windows (app-state-frame app)))))
              ;; Editor text for each open window, in order (empty string for terminals)
              (cons 'test-window-texts
                    (lambda ()
                      (map (lambda (win)
                             (let ((ed (qt-edit-window-editor win)))
                               (if ed (qt-plain-text-edit-text ed) "")))
                           (qt-frame-windows (app-state-frame app)))))
              ;; Is a C-x / prefix key currently pending?
              (cons 'test-prefix-active?
                    (lambda ()
                      (not (null? (key-state-prefix-keys (app-state-key-state app))))))
              ;; Is the current buffer a QTerminalWidget terminal?
              (cons 'test-terminal-running?
                    ;; True only if the current window's QStackedWidget is actually
                    ;; showing the QTerminalWidget page (not just the buffer being a
                    ;; terminal buffer — after C-x 2, new window shows editor page).
                    (lambda ()
                      (let* ((fr  (app-state-frame app))
                             (win (qt-current-window fr))
                             (buf (qt-edit-window-buffer win))
                             (term (and buf (hash-get *terminal-widget-map* buf))))
                        (and term
                             (let* ((container (qt-edit-window-container win))
                                    (count (qt-stacked-widget-count container)))
                               ;; Terminal widget was added as the last page (index count-1).
                               ;; If count > 1 and current index > 0, terminal is visible.
                               (and (> count 1)
                                    (> (qt-stacked-widget-current-index container) 0)))))))
              ;; Reset editor to a clean single-window state between tests.
              ;; Clears key prefix state, collapses to one window, destroys terminals.
              (cons 'test-reset!
                    (lambda ()
                      ;; Clear any pending prefix key (e.g. C-x)
                      (set! (app-state-key-state app) (make-initial-key-state))
                      ;; Destroy terminals BEFORE delete-other-windows: qt-terminal-destroy!
                      ;; detaches the widget from its parent QStackedWidget, preventing the
                      ;; double-free that occurs when delete-other-windows destroys the
                      ;; container and Qt auto-deletes its children.
                      (let ((term-bufs (hash-keys *terminal-widget-map*)))
                        (for-each
                          (lambda (buf)
                            (let ((term (hash-get *terminal-widget-map* buf)))
                              (when term
                                (with-catch (lambda (e) #f)
                                  (lambda () (qt-terminal-destroy! term)))
                                (hash-remove! *terminal-widget-map* buf)
                                (hash-remove! *terminal-container-map* buf))))
                          term-bufs))
                      ;; Collapse to single window (safe now: terminals detached from containers)
                      (when (> (length (qt-frame-windows (app-state-frame app))) 1)
                        (execute-command! app 'delete-other-windows))
                      'ok))
              ;; Set current editor text directly (bypasses undo — for test isolation)
              (cons 'test-clear-buffer!
                    (lambda ()
                      (let* ((fr (app-state-frame app))
                             (ed (qt-current-editor fr)))
                        (when ed (qt-plain-text-edit-set-text! ed ""))
                        'ok)))
              ;; Current window index (0-based, matches test-window-buffers/texts order)
              (cons 'test-window-idx
                    (lambda ()
                      (qt-frame-current-idx (app-state-frame app))))))))
      ;; Tree-sitter debounced re-highlight — re-parse when buffer content changes.
      ;; Tracks last-known text length per buffer to detect modifications.
      (schedule-periodic! 'treesitter-reparse 150
        (lambda ()
          (let* ((fr (app-state-frame app))
                 (buf (qt-current-buffer fr))
                 (state (and buf (ts-buffer-state buf))))
            (when state
              (let ((ed (qt-current-editor fr)))
                (when ed
                  (let* ((text (qt-plain-text-edit-text ed))
                         (new-ver (and text (string-length text)))
                         (old-ver (ts-state-version state)))
                    (when (and new-ver (not (= new-ver old-ver)))
                      (with-catch (lambda (e) (void))
                        (lambda () (ts-buffer-reparse! buf text ed)))
                      (set! (ts-state-version state) new-ver)))))))))

      (schedule-periodic! 'ipc 200
        (lambda ()
          (for-each (lambda (f) (qt-open-file! app f))
                    (ipc-poll-files!))))

      ;; Master timer tick function — passed to qt-app-exec! as the per-iteration
      ;; callback so all periodic work runs on the primordial thread.
      ;; This eliminates the second Chez thread entirely, preventing GC
      ;; rendezvous deadlocks (single thread = no stop-the-world coordination).
      (set! *master-timer-tick-fn*
        (lambda ()
          (qt-drain-pending-callbacks!)
          (master-timer-tick!)))

      )) ;; end of qt-do-init! let* and function body

(def ffi-umask (foreign-procedure "umask" (unsigned-32) unsigned-32))

(def (qt-main . args)
  ;; Restrict file permissions: new files are owner-only by default.
  ;; Prevents session data (history, scratch, desktop) from being world-readable.
  (ffi-umask #o077)
  ;; Pin the primordial thread to processor 0 (the main OS thread).
  ;; This is the most critical pinning: the primordial thread runs all
  ;; command dispatch, key handling, minibuffer poll loops, and Qt init.
  ;; Without pinning, Gambit's work-stealing scheduler could migrate it
  ;; to a different OS thread mid-operation, breaking Qt thread affinity.
  (pin-thread-to-processor0! (current-thread))
  ;; Disable IBus input method plugin to prevent Scintilla assertion crash.
  ;; IBus queries Qt::ImSurroundingText via SCI_GETTEXTRANGE with stale positions
  ;; when the document changes rapidly (e.g. terminal PTY output every 50ms).
  ;; The "compose" module handles basic compose sequences without querying text.
  (setenv "QT_IM_MODULE" "compose")
  ;; Also disable accessibility (AT-SPI) as defense-in-depth.
  (setenv "QT_ACCESSIBILITY" "0")
  (let ((qt-app (qt-app-create)))
    (set! *qt-app-ref* qt-app)
    (automation-set-qt-app! qt-app)
    (try
      ;; Run initialization synchronously before entering the event loop.
      ;; The primordial thread is pinned to processor 0, so it will always
      ;; run on the main OS thread — Qt calls go direct without needing
      ;; BlockingQueuedConnection during init.  After exec() starts,
      ;; background threads (LSP, async file I/O) use BlockingQueuedConnection
      ;; safely because the event loop is then running.
      (qt-do-init! qt-app args)
      ;; Enter Qt event loop (blocks here until quit).
      ;; Pass the master-timer tick as the per-iteration callback so all
      ;; periodic work (UI queue drain, scheduled tasks, debug REPL, IPC)
      ;; runs on the primordial thread — single Chez thread, no GC deadlock.
      (qt-app-exec! qt-app *master-timer-tick-fn*)
      ;; Cleanup after event loop exits
      (lsp-stop!)
      (stop-ipc-server!)
      (stop-debug-repl!)
      (finally
        (qt-app-quit! qt-app)
        (qt-app-destroy! qt-app)))))

;;;============================================================================
;;; File opening helper
;;;============================================================================

(def (qt-open-file! app filename (on-loaded #f))
  "Open a file or directory in a new buffer, or view an image.
   Optional on-loaded callback is called with (app buf) after text is loaded."
  ;; Track in recent files
  (recent-files-add! filename)
  (cond
    ;; Directory -> dired
    ((and (file-exists? filename)
          (eq? 'directory (file-info-type (file-info filename))))
     (dired-open-directory! app filename))
    ;; Image file -> inline image buffer
    ((image-file? filename)
     (let* ((pixmap (qt-pixmap-load filename)))
       (if (qt-pixmap-null? pixmap)
         (begin
           (qt-pixmap-destroy! pixmap)
           (echo-error! (app-state-echo app)
             (string-append "Failed to load image: " filename)))
         (let* ((name (uniquify-buffer-name! filename))
                (fr (app-state-frame app))
                (ed (qt-current-editor fr))
                (buf (qt-buffer-create! name ed filename))
                (orig-w (qt-pixmap-width pixmap))
                (orig-h (qt-pixmap-height pixmap)))
           (set! (buffer-lexer-lang buf) 'image)
           (hash-put! *image-buffer-state* buf
             (list pixmap (box 1.0) orig-w orig-h))
           (buffer-touch! buf)
           (qt-buffer-attach! ed buf)
           (set! (qt-edit-window-buffer (qt-current-window fr)) buf)))))
    ;; Regular file -> text buffer
    (else
     (let* ((name (uniquify-buffer-name! filename))
            (fr (app-state-frame app))
            (ed (qt-current-editor fr))
            (buf (qt-buffer-create! name ed filename)))
       (buffer-touch! buf)
       (qt-buffer-attach! ed buf)
       (set! (qt-edit-window-buffer (qt-current-window fr)) buf)
       (if (file-exists? filename)
         ;; Read file content in background thread.
         ;; Capture the target buffer and its doc pointer NOW — by the time
         ;; the async callback fires, the user may have switched to a different
         ;; buffer, so qt-current-editor would write into the wrong document.
         (let ((target-buf buf)
               (target-doc (buffer-doc-pointer buf)))
           (qt-plain-text-edit-set-text! ed "Loading...")
           (async-read-file! filename
             (lambda (text)
               (when text
                 (let* ((ed (qt-current-editor (app-state-frame app)))
                        (current-doc (sci-send ed SCI_GETDOCPOINTER 0)))
                   ;; Switch to the target buffer's document before writing
                   (sci-send ed SCI_SETDOCPOINTER 0 target-doc)
                   (qt-plain-text-edit-set-text! ed text)
                   (qt-text-document-set-modified! target-doc #f)
                   ;; Switch back to whatever document was active
                   (sci-send ed SCI_SETDOCPOINTER 0 current-doc)
                   ;; If the target buffer IS the current buffer, also set cursor
                   (when (eq? (qt-current-buffer (app-state-frame app)) target-buf)
                     (qt-plain-text-edit-set-cursor-position! ed 0))))
               (file-mtime-record! filename)
               (qt-setup-highlighting! app buf)
               (let ((mode (detect-major-mode filename)))
                 (when mode
                   (buffer-local-set! buf 'major-mode mode)
                   (let ((mode-cmd (find-command mode)))
                     (when mode-cmd (mode-cmd app)))))
               (lsp-maybe-auto-start! app buf)
               (lsp-hook-did-open! app buf)
               (run-hooks! 'find-file-hook app buf)
               (when on-loaded (on-loaded app buf)))))
         ;; New file — no content to read
         (begin
           (qt-setup-highlighting! app buf)
           (let ((mode (detect-major-mode filename)))
             (when mode
               (buffer-local-set! buf 'major-mode mode)
               (let ((mode-cmd (find-command mode)))
                 (when mode-cmd (mode-cmd app)))))
           (lsp-maybe-auto-start! app buf)
           (lsp-hook-did-open! app buf)
           (run-hooks! 'find-file-hook app buf)))))))
