;;; -*- Gerbil -*-
;;; QScintilla compatibility shim for jerboa-emacs
;;;
;;; Ported from gerbil-emacs/qt/sci-shim.ss
;;; Provides qt-plain-text-edit-* compatible functions backed by QScintilla.

(export
  ;; Local helpers
  sci-send sci-send/string sci-recv-string rgb->sci
  *doc-editor-map* *doc-buffer-map*
  doc-editor-register! doc-buffer-register!
  qt-drain-pending-callbacks!
  SCI_REPLACESEL
  ;; Qt/Scintilla functions
  qt-plain-text-edit-create qt-plain-text-edit-set-text! qt-plain-text-edit-text
  qt-plain-text-edit-append! qt-plain-text-edit-clear!
  qt-plain-text-edit-set-read-only! qt-plain-text-edit-read-only?
  qt-plain-text-edit-set-placeholder! qt-plain-text-edit-line-count
  qt-plain-text-edit-set-max-block-count!
  qt-plain-text-edit-cursor-line qt-plain-text-edit-cursor-column
  qt-plain-text-edit-set-line-wrap! qt-on-plain-text-edit-text-changed!
  qt-plain-text-edit-cursor-position qt-plain-text-edit-set-cursor-position!
  qt-plain-text-edit-move-cursor! qt-plain-text-edit-select-all!
  qt-plain-text-edit-selected-text qt-plain-text-edit-selection-start
  qt-plain-text-edit-selection-end qt-plain-text-edit-has-selection?
  qt-plain-text-edit-set-selection! qt-plain-text-edit-insert-text!
  qt-plain-text-edit-remove-selected-text! qt-plain-text-edit-undo!
  qt-plain-text-edit-redo! qt-plain-text-edit-can-undo?
  qt-plain-text-edit-cut! qt-plain-text-edit-copy! qt-plain-text-edit-paste!
  qt-plain-text-edit-text-length qt-plain-text-edit-text-range
  qt-plain-text-edit-line-from-position qt-plain-text-edit-line-end-position
  qt-plain-text-edit-find-text qt-plain-text-edit-ensure-cursor-visible!
  qt-plain-text-edit-center-cursor!
  qt-plain-text-edit-set-document! qt-plain-text-edit-document
  qt-plain-text-document-create qt-text-document-create qt-text-document-destroy!
  qt-text-document-modified? qt-text-document-set-modified!
  qt-line-number-area-create qt-line-number-area-destroy!
  qt-line-number-area-set-visible! qt-line-number-area-set-bg-color!
  qt-line-number-area-set-fg-color!
  qt-syntax-highlighter-create qt-syntax-highlighter-destroy!
  qt-syntax-highlighter-add-rule! qt-syntax-highlighter-add-keywords!
  qt-syntax-highlighter-add-multiline-rule! qt-syntax-highlighter-rehighlight!
  qt-syntax-highlighter-clear-rules!
  qt-extra-selections-clear! qt-extra-selection-add-line!
  qt-extra-selection-add-range! qt-extra-selections-apply!
  ;; chez-qt re-exports — all chez-qt identifiers used by Qt modules
  ;; (compiled/static builds require explicit exports — not transitive through import)
  ;; Constants
  QT_ALIGN_CENTER QT_CASE_INSENSITIVE QT_HORIZONTAL QT_VERTICAL
  QT_KEEP_ANCHOR QT_MATCH_CONTAINS
  QT_PLAIN_NO_WRAP QT_PLAIN_WIDGET_WRAP
  QT_SIZE_FIXED QT_SIZE_PREFERRED
  QT_WINDOW_FULL_SCREEN QT_WINDOW_MAXIMIZED
  ;; Actions
  qt-action-create qt-action-set-shortcut!
  ;; App lifecycle
  qt-app-create qt-app-destroy! qt-app-exec!
  qt-app-process-events! qt-app-set-style-sheet!
  ;; Clipboard
  qt-clipboard-set-text! qt-clipboard-text
  ;; Completer
  qt-completer-complete-rect! qt-completer-create qt-completer-destroy!
  qt-completer-set-case-sensitivity! qt-completer-set-completion-prefix!
  qt-completer-set-filter-mode! qt-completer-set-max-visible-items!
  qt-completer-set-model-strings! qt-completer-set-widget!
  ;; Dialog
  qt-dialog-create qt-dialog-exec! qt-dialog-reject! qt-dialog-set-title!
  ;; Font
  qt-font-destroy! qt-font-point-size
  ;; Layout
  qt-hbox-layout-create qt-vbox-layout-create
  qt-layout-add-stretch! qt-layout-add-widget! qt-layout-set-margins!
  qt-layout-set-spacing! qt-layout-set-stretch-factor!
  ;; Label
  qt-label-create qt-label-set-alignment! qt-label-set-pixmap! qt-label-set-text! qt-label-text
  ;; Key events
  qt-last-key-code qt-last-key-modifiers qt-last-key-text qt-last-key-autorepeat?
  ;; Line edit
  qt-line-edit-create qt-line-edit-set-completer! qt-line-edit-set-text! qt-line-edit-text
  ;; List widget
  qt-list-widget-add-item! qt-list-widget-clear! qt-list-widget-create
  qt-list-widget-current-row qt-list-widget-set-current-row!
  ;; Main window
  qt-main-window-add-toolbar! qt-main-window-create qt-main-window-menu-bar
  qt-main-window-set-central-widget! qt-main-window-set-status-bar-text!
  qt-main-window-set-title!
  ;; Menu
  qt-menu-add-action! qt-menu-add-separator! qt-menu-bar-add-menu
  ;; Callbacks
  qt-on-clicked! qt-on-completer-activated! qt-on-item-double-clicked!
  qt-on-key-press! qt-on-key-press-consuming! qt-on-return-pressed!
  qt-on-scintilla-save-point-left! qt-on-scintilla-save-point-reached!
  qt-on-scintilla-text-changed! qt-on-text-changed! qt-on-timeout! qt-on-triggered!
  ;; Pixmap
  qt-pixmap-destroy! qt-pixmap-height qt-pixmap-load qt-pixmap-null?
  qt-pixmap-scaled qt-pixmap-width
  ;; Push button
  qt-push-button-create
  ;; Scintilla
  qt-scintilla-create qt-scintilla-get-text qt-scintilla-get-text-length
  qt-scintilla-receive-string qt-scintilla-send-message
  qt-scintilla-send-message-string qt-scintilla-set-lexer-language! qt-scintilla-set-text!
  qt-scintilla-set-utf8!
  qt-scintilla-lexer-set-color! qt-scintilla-lexer-set-paper! qt-scintilla-lexer-set-font-attr!
  ;; Scroll area
  qt-scroll-area-create qt-scroll-area-set-widget! qt-scroll-area-set-widget-resizable!
  ;; Splitter
  qt-splitter-add-widget! qt-splitter-count qt-splitter-create qt-splitter-index-of
  qt-splitter-insert-widget! qt-splitter-set-handle-width! qt-splitter-set-orientation!
  qt-splitter-set-sizes! qt-splitter-size-at
  ;; Stacked widget
  qt-stacked-widget-add-widget! qt-stacked-widget-count qt-stacked-widget-create qt-stacked-widget-set-current-index!
  ;; Timer
  qt-timer-create qt-timer-set-single-shot! qt-timer-start! qt-timer-stop!
  ;; Toolbar
  qt-toolbar-add-action! qt-toolbar-add-separator! qt-toolbar-create qt-toolbar-set-movable!
  ;; Widget
  qt-widget-close! qt-widget-create qt-widget-destroy! qt-widget-font
  qt-widget-height qt-widget-hide! qt-widget-resize! qt-widget-set-focus!
  qt-widget-set-font-size! qt-widget-set-maximum-height! qt-widget-set-minimum-height!
  qt-widget-set-minimum-size! qt-widget-set-size-policy! qt-widget-set-style-sheet!
  qt-widget-set-attribute! qt-widget-set-updates-enabled!
  qt-widget-show! qt-widget-show-fullscreen! qt-widget-show-maximized!
  qt-widget-show-minimized! qt-widget-show-normal! qt-widget-width qt-widget-window-state
  ;; Qt constants re-exported for modules that only import sci-shim
  ;; (compiled/static builds require explicit exports — values from chez-qt/ffi.ss)
  QT_MOD_SHIFT QT_MOD_ALT QT_MOD_META QT_MOD_CTRL
  QT_KEY_ESCAPE QT_KEY_BACKSPACE QT_KEY_RETURN QT_KEY_ENTER QT_KEY_DELETE
  QT_KEY_TAB QT_KEY_INSERT QT_KEY_HOME QT_KEY_END
  QT_KEY_LEFT QT_KEY_RIGHT QT_KEY_UP QT_KEY_DOWN
  QT_KEY_PAGE_UP QT_KEY_PAGE_DOWN QT_KEY_SPACE
  QT_KEY_A QT_KEY_G QT_KEY_N QT_KEY_P QT_KEY_R QT_KEY_S QT_KEY_W QT_KEY_Z
  QT_KEY_F1 QT_KEY_F2 QT_KEY_F3 QT_KEY_F4 QT_KEY_F5 QT_KEY_F6
  QT_KEY_F7 QT_KEY_F8 QT_KEY_F9 QT_KEY_F10 QT_KEY_F11 QT_KEY_F12
  QT_CURSOR_UP QT_CURSOR_DOWN QT_CURSOR_START QT_CURSOR_END
  QT_CURSOR_START_OF_BLOCK QT_CURSOR_END_OF_BLOCK
  QT_CURSOR_NEXT_CHAR QT_CURSOR_NEXT_WORD
  QT_CURSOR_PREVIOUS_CHAR QT_CURSOR_PREVIOUS_WORD
  ;; QTerminalWidget (libvterm-based terminal emulator)
  qt-terminal-create qt-terminal-destroy! qt-terminal-spawn!
  qt-terminal-send-key-event! qt-terminal-send-input!
  qt-terminal-is-running? qt-terminal-interrupt!
  qt-terminal-set-font! qt-terminal-set-colors!
  qt-terminal-focus! qt-terminal-widget)

(import
  :jerboa-emacs/core
  :chez-scintilla/constants
  :chez-scintilla/scintilla
  (except-in :chez-qt/qt
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
             qt-line-number-area-set-bg-color! qt-line-number-area-set-fg-color!
             ;; Constants we redefine as literals below
             QT_MOD_SHIFT QT_MOD_ALT QT_MOD_META
             QT_KEY_ESCAPE QT_KEY_BACKSPACE QT_KEY_RETURN QT_KEY_ENTER QT_KEY_DELETE
             QT_KEY_TAB QT_KEY_INSERT QT_KEY_HOME QT_KEY_END
             QT_KEY_LEFT QT_KEY_RIGHT QT_KEY_UP QT_KEY_DOWN
             QT_KEY_PAGE_UP QT_KEY_PAGE_DOWN QT_KEY_SPACE
             QT_KEY_F1 QT_KEY_F2 QT_KEY_F3 QT_KEY_F4 QT_KEY_F5 QT_KEY_F6
             QT_KEY_F7 QT_KEY_F8 QT_KEY_F9 QT_KEY_F10 QT_KEY_F11 QT_KEY_F12
             QT_CURSOR_UP QT_CURSOR_DOWN QT_CURSOR_START QT_CURSOR_END
             QT_CURSOR_START_OF_BLOCK QT_CURSOR_END_OF_BLOCK
             QT_CURSOR_NEXT_CHAR QT_CURSOR_NEXT_WORD
             QT_CURSOR_PREVIOUS_CHAR QT_CURSOR_PREVIOUS_WORD)
  :std/sugar)

;; SCI_REPLACESEL constant

;; Qt modifier/key/cursor constants re-exported for modules that only import sci-shim.
;; Values from chez-qt/chez-qt/ffi.ss.  Defined as literals so there is no import
;; dependency on chez-qt at build time for modules that import this shim.
;; (chez-qt qt) exports these same names so they are excluded via except-in above.)
(def QT_MOD_SHIFT     #x02000000)
(def QT_MOD_ALT       #x08000000)
(def QT_MOD_META      #x10000000)
(def QT_MOD_CTRL      #x04000000)
(def QT_KEY_ESCAPE    #x01000000)
(def QT_KEY_BACKSPACE #x01000003)
(def QT_KEY_RETURN    #x01000004)
(def QT_KEY_ENTER     #x01000005)
(def QT_KEY_DELETE    #x01000007)
(def QT_KEY_TAB       #x01000001)
(def QT_KEY_INSERT    #x01000006)
(def QT_KEY_HOME      #x01000010)
(def QT_KEY_END       #x01000011)
(def QT_KEY_LEFT      #x01000012)
(def QT_KEY_UP        #x01000013)
(def QT_KEY_RIGHT     #x01000014)
(def QT_KEY_DOWN      #x01000015)
(def QT_KEY_PAGE_UP   #x01000016)
(def QT_KEY_PAGE_DOWN #x01000017)
(def QT_KEY_SPACE     #x20)
;; Letter keys (ASCII values)
(def QT_KEY_A         65)
(def QT_KEY_G         71)
(def QT_KEY_N         78)
(def QT_KEY_P         80)
(def QT_KEY_R         82)
(def QT_KEY_S         83)
(def QT_KEY_W         87)
(def QT_KEY_Z         90)
;; Function keys
(def QT_KEY_F1        #x01000030)
(def QT_KEY_F2        #x01000031)
(def QT_KEY_F3        #x01000032)
(def QT_KEY_F4        #x01000033)
(def QT_KEY_F5        #x01000034)
(def QT_KEY_F6        #x01000035)
(def QT_KEY_F7        #x01000036)
(def QT_KEY_F8        #x01000037)
(def QT_KEY_F9        #x01000038)
(def QT_KEY_F10       #x01000039)
(def QT_KEY_F11       #x0100003a)
(def QT_KEY_F12       #x0100003b)
;; Cursor movement operations
(def QT_CURSOR_UP               2)
(def QT_CURSOR_DOWN            12)
(def QT_CURSOR_START            1)
(def QT_CURSOR_END             11)
(def QT_CURSOR_START_OF_BLOCK   4)
(def QT_CURSOR_END_OF_BLOCK     8)
(def QT_CURSOR_NEXT_CHAR        9)
(def QT_CURSOR_NEXT_WORD       15)
(def QT_CURSOR_PREVIOUS_CHAR    5)
(def QT_CURSOR_PREVIOUS_WORD   18)

;; Helpers
(def (sci-send sci msg (wparam 0) (lparam 0))
  (qt-scintilla-send-message sci msg wparam lparam))

(def (sci-send/string sci msg str (wparam 0))
  (qt-scintilla-send-message-string sci msg wparam str))

(def (sci-recv-string sci msg (wparam 0))
  (qt-scintilla-receive-string sci msg wparam))

(def (rgb->sci r g b)
  (+ r (* 256 g) (* 65536 b)))

;; Callback queue drain — calls C-level chez_qt_drain_pending_callbacks()
;; which pops deferred Qt signal events and dispatches them on the primordial thread.
(def ffi-drain-pending-callbacks
  (foreign-procedure "chez_qt_drain_pending_callbacks" () void))
(def (qt-drain-pending-callbacks!) (ffi-drain-pending-callbacks))

;; UTF-8 mode: calls QsciScintilla::setUtf8(enable) — the authoritative QsciScintilla
;; API, as opposed to raw SCI_SETCODEPAGE. QT_VOID in the C shim handles main-thread
;; dispatch automatically, so we call it directly.
(def ffi-qt-scintilla-set-utf8
  (foreign-procedure "qt_scintilla_set_utf8" (void* int) void))
(def (qt-scintilla-set-utf8! sci enable?)
  (ffi-qt-scintilla-set-utf8 sci (if enable? 1 0)))

;; Document tracking
(def *doc-editor-map* (make-hash-table))
(def *doc-buffer-map* (make-hash-table))

(def (doc-editor-register! doc editor)
  (hash-put! *doc-editor-map* doc editor))

(def (doc-buffer-register! doc buf)
  (hash-put! *doc-buffer-map* doc buf))

;; Widget creation
(def (qt-plain-text-edit-create parent: (parent #f))
  (qt-scintilla-create parent))

;; Text operations
(def (qt-plain-text-edit-text sci)
  (qt-scintilla-get-text sci))

(def (qt-plain-text-edit-set-text! sci text)
  (verbose-log! "qt-plain-text-edit-set-text! len=" (number->string (string-length text)))
  (qt-scintilla-set-text! sci text)
  (verbose-log! "qt-plain-text-edit-set-text! done")
  (let ((new-len (sci-send sci SCI_GETLENGTH)))
    (when (> (sci-send sci SCI_GETCURRENTPOS) new-len)
      (sci-send sci SCI_GOTOPOS new-len))
    (when (> (sci-send sci SCI_GETANCHOR) new-len)
      (sci-send sci SCI_SETANCHOR new-len))))

(def (qt-plain-text-edit-append! sci text)
  (let ((to-append (string-append "\n" text)))
    (sci-send/string sci SCI_APPENDTEXT to-append (string-length to-append))))

(def (qt-plain-text-edit-clear! sci)
  (sci-send sci SCI_CLEARALL))

(def (qt-plain-text-edit-insert-text! sci text)
  (sci-send/string sci SCI_REPLACESEL text))

(def (qt-plain-text-edit-remove-selected-text! sci)
  (sci-send/string sci SCI_REPLACESEL ""))

(def (qt-plain-text-edit-text-length sci)
  (qt-scintilla-get-text-length sci))

(def (qt-plain-text-edit-text-range sci start end)
  (let ((text (qt-scintilla-get-text sci)))
    (if (and (>= start 0) (<= end (string-length text)) (<= start end))
      (substring text start end)
      "")))

;; Cursor operations
(def (qt-plain-text-edit-cursor-position sci)
  (sci-send sci SCI_GETCURRENTPOS))

(def (qt-plain-text-edit-set-cursor-position! sci pos)
  (sci-send sci SCI_GOTOPOS (min pos (sci-send sci SCI_GETLENGTH))))

(def (qt-plain-text-edit-cursor-line sci)
  (sci-send sci SCI_LINEFROMPOSITION (sci-send sci SCI_GETCURRENTPOS)))

(def (qt-plain-text-edit-cursor-column sci)
  (sci-send sci SCI_GETCOLUMN (sci-send sci SCI_GETCURRENTPOS)))

(def (qt-plain-text-edit-line-count sci)
  (sci-send sci SCI_GETLINECOUNT))

(def (qt-plain-text-edit-line-from-position sci pos)
  (sci-send sci SCI_LINEFROMPOSITION pos))

(def (qt-plain-text-edit-line-end-position sci line)
  (sci-send sci SCI_GETLINEENDPOSITION line))

;; Cursor movement — maps QT_CURSOR_* constants to Scintilla positions
(def (qt-plain-text-edit-move-cursor! sci op mode: (mode #f))
  (let* ((keep-anchor? (and mode (= mode QT_KEEP_ANCHOR)))
         (cur-pos (sci-send sci SCI_GETCURRENTPOS))
         (new-pos
          (cond
            ((= op QT_CURSOR_END)
             (sci-send sci SCI_GETTEXTLENGTH))
            ((= op QT_CURSOR_START)
             0)
            ((= op QT_CURSOR_END_OF_BLOCK)
             (let ((line (sci-send sci SCI_LINEFROMPOSITION cur-pos)))
               (sci-send sci SCI_GETLINEENDPOSITION line)))
            ((= op QT_CURSOR_START_OF_BLOCK)
             (let ((line (sci-send sci SCI_LINEFROMPOSITION cur-pos)))
               (sci-send sci SCI_POSITIONFROMLINE line)))
            ((= op QT_CURSOR_DOWN)
             (let* ((line (sci-send sci SCI_LINEFROMPOSITION cur-pos))
                    (col (sci-send sci SCI_GETCOLUMN cur-pos))
                    (max-line (- (sci-send sci SCI_GETLINECOUNT) 1))
                    (new-line (min (+ line 1) max-line)))
               (sci-send sci SCI_FINDCOLUMN new-line col)))
            ((= op QT_CURSOR_UP)
             (let* ((line (sci-send sci SCI_LINEFROMPOSITION cur-pos))
                    (col (sci-send sci SCI_GETCOLUMN cur-pos))
                    (new-line (max (- line 1) 0)))
               (sci-send sci SCI_FINDCOLUMN new-line col)))
            ((= op QT_CURSOR_NEXT_CHAR)
             (min (+ cur-pos 1) (sci-send sci SCI_GETTEXTLENGTH)))
            ((= op QT_CURSOR_PREVIOUS_CHAR)
             (max (- cur-pos 1) 0))
            ((= op QT_CURSOR_NEXT_WORD)
             ;; Scan forward past current word, then past whitespace
             (let* ((text (qt-plain-text-edit-text sci))
                    (len (string-length text)))
               (let loop ((i cur-pos) (in-word? #t))
                 (cond
                   ((>= i len) len)
                   ((char-alphabetic? (string-ref text i))
                    (if in-word? (loop (+ i 1) #t) i))
                   ((char-whitespace? (string-ref text i))
                    (loop (+ i 1) #f))
                   (in-word? (loop (+ i 1) #f))
                   (else i)))))
            ((= op QT_CURSOR_PREVIOUS_WORD)
             ;; Scan backward past whitespace, then past word
             (let ((text (qt-plain-text-edit-text sci)))
               (let loop ((i (max (- cur-pos 1) 0)) (in-space? #t))
                 (cond
                   ((<= i 0) 0)
                   ((char-whitespace? (string-ref text i))
                    (if in-space? (loop (- i 1) #t) (+ i 1)))
                   ((char-alphabetic? (string-ref text i))
                    (if in-space? (loop (- i 1) #f) (loop (- i 1) #f)))
                   (in-space? (loop (- i 1) #f))
                   (else (+ i 1))))))
            (else cur-pos))))
    ;; Apply the movement (clamp to document length for safety)
    (let ((safe-pos (min new-pos (sci-send sci SCI_GETLENGTH))))
      (if keep-anchor?
        ;; Keep anchor — extends selection
        (sci-send sci SCI_SETCURRENTPOS safe-pos)
        ;; Move anchor too — no selection
        (sci-send sci SCI_GOTOPOS safe-pos)))))

(def (qt-plain-text-edit-ensure-cursor-visible! sci)
  (sci-send sci SCI_SCROLLCARET))

(def (qt-plain-text-edit-center-cursor! sci)
  (sci-send sci SCI_SCROLLCARET))

;; Selection
(def (qt-plain-text-edit-select-all! sci)
  (sci-send sci SCI_SELECTALL))

(def (qt-plain-text-edit-selected-text sci)
  (sci-recv-string sci SCI_GETSELTEXT))

(def (qt-plain-text-edit-selection-start sci)
  (sci-send sci SCI_GETSELECTIONSTART))

(def (qt-plain-text-edit-selection-end sci)
  (sci-send sci SCI_GETSELECTIONEND))

(def (qt-plain-text-edit-has-selection? sci)
  (not (= (sci-send sci SCI_GETSELECTIONSTART)
          (sci-send sci SCI_GETSELECTIONEND))))

(def (qt-plain-text-edit-set-selection! sci start end)
  (let ((doc-len (sci-send sci SCI_GETLENGTH)))
    (sci-send sci SCI_SETSEL (min start doc-len) (min end doc-len))))

;; Undo/Redo/Clipboard
(def (qt-plain-text-edit-undo! sci) (sci-send sci SCI_UNDO))
(def (qt-plain-text-edit-redo! sci) (sci-send sci SCI_REDO))
(def (qt-plain-text-edit-can-undo? sci) (not (= 0 (sci-send sci SCI_CANUNDO))))
(def (qt-plain-text-edit-cut! sci) (sci-send sci SCI_CUT))
(def (qt-plain-text-edit-copy! sci) (sci-send sci SCI_COPY))
(def (qt-plain-text-edit-paste! sci) (sci-send sci SCI_PASTE))

;; Properties
(def (qt-plain-text-edit-set-read-only! sci ro?)
  (sci-send sci SCI_SETREADONLY (if ro? 1 0)))

(def (qt-plain-text-edit-read-only? sci)
  (not (zero? (sci-send sci SCI_GETREADONLY))))

(def (qt-plain-text-edit-set-line-wrap! sci wrap?)
  (sci-send sci SCI_SETWRAPMODE (if wrap? SC_WRAP_WORD SC_WRAP_NONE)))

(def (qt-plain-text-edit-set-placeholder! sci text) (void))
(def (qt-plain-text-edit-set-max-block-count! sci count) (void))

;; Signals
(def (qt-on-plain-text-edit-text-changed! sci handler)
  (qt-on-scintilla-text-changed! sci handler))

;; Search
(def (qt-plain-text-edit-find-text sci text . flags)
  (let* ((pos (sci-send sci SCI_GETCURRENTPOS))
         (len (sci-send sci SCI_GETTEXTLENGTH)))
    (sci-send sci SCI_SETTARGETSTART pos)
    (sci-send sci SCI_SETTARGETEND len)
    (sci-send sci SCI_SETSEARCHFLAGS 0)
    (let ((found (sci-send/string sci SCI_SEARCHINTARGET text (string-length text))))
      (if (>= found 0) found -1))))

;; Document management
(def (qt-plain-text-edit-set-document! sci doc)
  (sci-send sci SCI_SETDOCPOINTER 0 doc))

(def (qt-plain-text-edit-document sci)
  (sci-send sci SCI_GETDOCPOINTER))

(def (qt-plain-text-document-create) #f)
(def (qt-text-document-create) #f)
(def (qt-text-document-destroy! doc) (void))

(def (qt-text-document-modified? doc)
  (let ((buf (hash-get *doc-buffer-map* doc)))
    (if buf (buffer-modified buf) #f)))

(def (qt-text-document-set-modified! doc modified?)
  (let ((buf (hash-get *doc-buffer-map* doc)))
    (when buf
      (set! (buffer-modified buf) modified?)
      (unless modified?
        (let ((ed (hash-get *doc-editor-map* doc)))
          (when ed (sci-send ed SCI_SETSAVEPOINT)))))))

;; Line number area stubs
(def (qt-line-number-area-create editor) #f)
(def (qt-line-number-area-destroy! lna) (void))
(def (qt-line-number-area-set-visible! lna visible?) (void))
(def (qt-line-number-area-set-bg-color! lna r g b) (void))
(def (qt-line-number-area-set-fg-color! lna r g b) (void))

;; Syntax highlighter stubs
(def (qt-syntax-highlighter-create doc) #f)
(def (qt-syntax-highlighter-destroy! h) (void))
(def (qt-syntax-highlighter-add-rule! h pattern r g b bold? italic?) (void))
(def (qt-syntax-highlighter-add-keywords! h keywords r g b bold? italic?) (void))
(def (qt-syntax-highlighter-add-multiline-rule! h start end r g b bold? italic?) (void))
(def (qt-syntax-highlighter-rehighlight! h) (void))
(def (qt-syntax-highlighter-clear-rules! h) (void))

;; Extra selections - indicators
(def *indic-current-line* 8)
(def *indic-brace-match* 9)
(def *indic-brace-bad* 10)
(def *indic-search* 11)
(def *pending-decorations* [])

(def (qt-extra-selections-clear! sci)
  (set! *pending-decorations* [])
  (let ((len (sci-send sci SCI_GETTEXTLENGTH)))
    (for-each
      (lambda (indic)
        (sci-send sci SCI_SETINDICATORCURRENT indic)
        (sci-send sci SCI_INDICATORCLEARRANGE 0 len))
      (list *indic-current-line* *indic-brace-match* *indic-brace-bad* *indic-search*))))

(def (qt-extra-selection-add-line! sci line bg-r bg-g bg-b)
  (sci-send sci SCI_SETCARETLINEVISIBLE 1)
  (sci-send sci SCI_SETCARETLINEBACK (rgb->sci bg-r bg-g bg-b)))

(def (qt-extra-selection-add-range! sci pos len fg-r fg-g fg-b bg-r bg-g bg-b bold: (bold? #f))
  (set! *pending-decorations*
    (cons (list pos len fg-r fg-g fg-b bg-r bg-g bg-b bold?) *pending-decorations*)))

(def (qt-extra-selections-apply! sci)
  (for-each
    (lambda (dec)
      (let ((pos (car dec))
            (len (cadr dec))
            (bg-r (list-ref dec 5))
            (bg-g (list-ref dec 6))
            (bg-b (list-ref dec 7)))
        (sci-send sci SCI_SETINDICATORCURRENT *indic-brace-match*)
        (sci-send sci SCI_INDICSETSTYLE *indic-brace-match* INDIC_ROUNDBOX)
        (sci-send sci SCI_INDICSETFORE *indic-brace-match* (rgb->sci bg-r bg-g bg-b))
        (let* ((doc-len (sci-send sci SCI_GETLENGTH))
               (safe-pos (min pos doc-len))
               (safe-len (min len (- doc-len safe-pos))))
          (when (> safe-len 0)
            (sci-send sci SCI_INDICATORFILLRANGE safe-pos safe-len)))))
    *pending-decorations*)
  (set! *pending-decorations* []))

;;;============================================================================
;;; QTerminalWidget FFI — libvterm-based terminal emulator
;;;============================================================================

(def (qt-terminal-create parent)
  "Create a QTerminalWidget as child of PARENT (typically a QStackedWidget).
   Returns an opaque pointer to the widget."
  ((foreign-procedure "qt_terminal_create" (void*) void*) parent))

(def (qt-terminal-destroy! term)
  "Destroy a QTerminalWidget and clean up its PTY."
  ((foreign-procedure "qt_terminal_destroy" (void*) void) term))

(def (qt-terminal-spawn! term cmd)
  "Spawn a shell/command in the terminal widget's PTY.
   CMD is a command string; empty string means default $SHELL."
  ((foreign-procedure "qt_terminal_spawn" (void* string) void) term cmd))

(def (qt-terminal-send-key-event! term key mods text)
  "Send a synthetic key event to the terminal widget.
   KEY is the Qt key code, MODS the Qt modifier flags, TEXT the key text."
  ((foreign-procedure "qt_terminal_send_key_event" (void* int int string) void)
   term key mods text))

(def (qt-terminal-send-input! term str)
  "Send raw string input to the terminal's PTY."
  ((foreign-procedure "qt_terminal_send_input" (void* string int) void)
   term str (string-length str)))

(def (qt-terminal-is-running? term)
  "Check if the terminal's child process is still running."
  (= 1 ((foreign-procedure "qt_terminal_is_running" (void*) int) term)))

(def (qt-terminal-interrupt! term)
  "Send SIGINT to the terminal's child process."
  ((foreign-procedure "qt_terminal_interrupt" (void*) void) term))

(def (qt-terminal-set-font! term family size)
  "Set the terminal font family and point size."
  ((foreign-procedure "qt_terminal_set_font" (void* string int) void) term family size))

(def (qt-terminal-set-colors! term fg-rgb bg-rgb)
  "Set default fg/bg colors as 0xRRGGBB integers."
  ((foreign-procedure "qt_terminal_set_colors" (void* int int) void) term fg-rgb bg-rgb))

(def (qt-terminal-focus! term)
  "Give keyboard focus to the terminal widget."
  ((foreign-procedure "qt_terminal_focus" (void*) void) term))

(def (qt-terminal-widget term)
  "Return the QWidget* pointer for the terminal (for adding to QStackedWidget)."
  ((foreign-procedure "qt_terminal_widget" (void*) void*) term))
