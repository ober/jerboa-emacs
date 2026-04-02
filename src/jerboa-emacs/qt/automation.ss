;;; -*- Gerbil -*-
;;; Qt GUI automation bridge for jemacs
;;;
;;; Provides functions for Claude (via the debug REPL) to interact with
;;; the running Qt editor: send real key events, take screenshots, and
;;; query application state.

(export automation-send-keys!
        automation-send-keys-async!
        automation-screenshot!
        automation-state
        automation-wait!
        automation-set-qt-app!
        automation-set-key-target-fn!
        emacs-key->qt-event)

(import :std/sugar
        :jerboa-emacs/qt/sci-shim
        (except-in :chez-qt/qt
                   ;; Exclude Qt constants re-exported by sci-shim
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
        :jerboa-emacs/qt/window
        :jerboa-emacs/qt/echo)

;;;============================================================================
;;; Emacs key notation → Qt key event conversion
;;;============================================================================

;;; Parse an Emacs-style key string into (values qt-key-code qt-modifiers qt-text).
;;; Examples:
;;;   "C-x"   → (values 88  #x04000000 "x")
;;;   "M-x"   → (values 88  #x08000000 "x")
;;;   "C-M-a" → (values 65  #x0c000000 "a")
;;;   "a"     → (values 65  0 "a")
;;;   "RET"   → (values #x01000004 0 "")
;;;   "<f1>"  → (values #x01000030 0 "")
(def (emacs-key->qt-event key-str)
  (let ((special (emacs-special-key key-str)))
    (if special
      ;; Special key name (RET, TAB, ESC, <f1>, <up>, etc.)
      (values (car special) (cdr special) "")
      ;; Parse modifier prefixes: C- M- S-
      (let parse ((s key-str) (mods 0))
        (cond
          ((and (>= (string-length s) 2) (string=? (substring s 0 2) "C-"))
           (parse (substring s 2 (string-length s))
                  (bitwise-ior mods QT_MOD_CTRL)))
          ((and (>= (string-length s) 2) (string=? (substring s 0 2) "M-"))
           (parse (substring s 2 (string-length s))
                  (bitwise-ior mods QT_MOD_ALT)))
          ((and (>= (string-length s) 2) (string=? (substring s 0 2) "S-"))
           (parse (substring s 2 (string-length s))
                  (bitwise-ior mods QT_MOD_SHIFT)))
          ;; After stripping prefixes, check for remaining special names
          ((emacs-special-key s)
           => (lambda (pair) (values (car pair) (bitwise-ior mods (cdr pair)) "")))
          ;; Single character
          ((= (string-length s) 1)
           (let* ((ch (string-ref s 0))
                  (code (char->qt-key ch)))
             (values code mods (string ch))))
          (else
           (error "automation: unrecognized key" key-str)))))))

;;; Map a character to a Qt key code.
(def (char->qt-key ch)
  (let ((c (char->integer ch)))
    (cond
      ;; Letters a-z → Qt::Key_A (65) through Qt::Key_Z (90)
      ((and (>= c 97) (<= c 122)) (- c 32))
      ;; Uppercase A-Z → Qt::Key_A through Qt::Key_Z
      ((and (>= c 65) (<= c 90)) c)
      ;; Digits 0-9 → Qt::Key_0 (48) through Qt::Key_9 (57)
      ((and (>= c 48) (<= c 57)) c)
      ;; Space
      ((= c 32) QT_KEY_SPACE)
      ;; Common punctuation — Qt uses ASCII code points
      (else c))))

;;; Lookup table for special key names.
(def (emacs-special-key name)
  (cond
    ((string=? name "RET")     (cons QT_KEY_RETURN 0))
    ((string=? name "TAB")     (cons QT_KEY_TAB 0))
    ((string=? name "ESC")     (cons QT_KEY_ESCAPE 0))
    ((string=? name "SPC")     (cons QT_KEY_SPACE 0))
    ((string=? name "DEL")     (cons QT_KEY_BACKSPACE 0))
    ((string=? name "<delete>") (cons QT_KEY_DELETE 0))
    ((string=? name "<return>") (cons QT_KEY_RETURN 0))
    ((string=? name "<tab>")   (cons QT_KEY_TAB 0))
    ((string=? name "<escape>") (cons QT_KEY_ESCAPE 0))
    ((string=? name "<backspace>") (cons QT_KEY_BACKSPACE 0))
    ((string=? name "<home>")  (cons QT_KEY_HOME 0))
    ((string=? name "<end>")   (cons QT_KEY_END 0))
    ((string=? name "<insert>") (cons QT_KEY_INSERT 0))
    ((string=? name "<left>")  (cons QT_KEY_LEFT 0))
    ((string=? name "<right>") (cons QT_KEY_RIGHT 0))
    ((string=? name "<up>")    (cons QT_KEY_UP 0))
    ((string=? name "<down>")  (cons QT_KEY_DOWN 0))
    ((string=? name "<prior>") (cons QT_KEY_PAGE_UP 0))
    ((string=? name "<next>")  (cons QT_KEY_PAGE_DOWN 0))
    ((string=? name "<f1>")    (cons QT_KEY_F1 0))
    ((string=? name "<f2>")    (cons QT_KEY_F2 0))
    ((string=? name "<f3>")    (cons QT_KEY_F3 0))
    ((string=? name "<f4>")    (cons QT_KEY_F4 0))
    ((string=? name "<f5>")    (cons QT_KEY_F5 0))
    ((string=? name "<f6>")    (cons QT_KEY_F6 0))
    ((string=? name "<f7>")    (cons QT_KEY_F7 0))
    ((string=? name "<f8>")    (cons QT_KEY_F8 0))
    ((string=? name "<f9>")    (cons QT_KEY_F9 0))
    ((string=? name "<f10>")   (cons QT_KEY_F10 0))
    ((string=? name "<f11>")   (cons QT_KEY_F11 0))
    ((string=? name "<f12>")   (cons QT_KEY_F12 0))
    (else #f)))

;;;============================================================================
;;; Send keys
;;;============================================================================

;;; Send a sequence of Emacs key strings as real Qt key events.
;;; Each string is parsed and sent as a press+release pair.
;;; Drains the callback queue after each key so the Scheme handler fires inline.
;;; WARNING: Do NOT use for commands that open a blocking minibuffer prompt
;;; (M-x, C-x C-f, C-s, etc.) — use automation-send-keys-async! instead.
;;;
;;; Usage:
;;;   (automation-send-keys! app "C-x" "2")        ; C-x 2 (split window)
;;;   (automation-send-keys! app "hello")           ; type text
(def (automation-send-keys! app . key-strings)
  (for-each (lambda (ks) (dispatch-key-string! app ks #t)) key-strings))

;;; Send keys WITHOUT draining the callback queue.
;;; The keys are queued and processed by the master timer on the next tick.
;;; Use this for commands that trigger blocking prompts (M-x, C-x C-f, etc.).
;;; Follow up with separate REPL calls to interact with the minibuffer.
;;;
;;; Usage:
;;;   (automation-send-keys-async! app "M-x")  ; opens M-x, returns immediately
;;;   ;; ... in next REPL call, minibuffer is active ...
;;;   (automation-send-keys-async! app "find-file" "RET")
(def (automation-send-keys-async! app . key-strings)
  (for-each (lambda (ks) (dispatch-key-string! app ks #f)) key-strings))

;;; Dispatch a key string — either a single recognized key or individual chars.
(def (dispatch-key-string! app ks drain?)
  (if (or (<= (string-length ks) 1)
          (emacs-special-key ks)
          ;; Modifier prefix pattern: C-x, M-x, C-M-x, S-<f1>, etc.
          (and (>= (string-length ks) 3)
               (or (string=? (substring ks 0 2) "C-")
                   (string=? (substring ks 0 2) "M-")
                   (string=? (substring ks 0 2) "S-"))))
    ;; Single key event
    (send-one-key! app ks drain?)
    ;; Multi-char string: send each character individually
    (let loop ((i 0))
      (when (< i (string-length ks))
        (send-one-key! app (string (string-ref ks i)) drain?)
        (loop (+ i 1))))))

;;; Send a single key event (press + release) to the focused widget.
;;; If the minibuffer is active, sends to the minibuffer input widget instead.
;;; When drain? is #t, drains the deferred callback queue after each event
;;; so the Scheme key handler fires immediately.
;;;
;;; Target selection priority:
;;;   1. Minibuffer input widget (when minibuffer is active)
;;;   2. *automation-key-target-fn* override (e.g. QTerminalWidget when
;;;      terminal buffer is active — the QScintilla is hidden behind it in
;;;      the QStackedWidget and sendEvent to a non-current page is unreliable)
;;;   3. qt-current-editor (the QScintilla editor for the current window)
(def (send-one-key! app key-str drain?)
  (let-values (((code mods text) (emacs-key->qt-event key-str)))
    (let* ((fr (app-state-frame app))
           (get-target (lambda ()
                         (cond
                           (*minibuffer-active?*
                            (and *mb-input* *mb-input*))
                           (*automation-key-target-fn*
                            (*automation-key-target-fn* fr))
                           (else
                            (qt-current-editor fr)))))
           (target (get-target)))
      (when target
        (qt-send-key-press! target code mods text)
        (when drain? (qt-drain-pending-callbacks!))
        ;; Re-fetch target after drain: the key handler may have destroyed the
        ;; pressed window (e.g. C-x 0). Sending key release to a destroyed
        ;; widget causes a segfault via Qt's sendPostedEvents / event dispatch.
        (let ((release-target (get-target)))
          (when release-target
            (qt-send-key-release! release-target code mods text)))
        (when drain? (qt-drain-pending-callbacks!))))))

;;;============================================================================
;;; Screenshot
;;;============================================================================

;;; Capture the main window as a PNG screenshot.
;;; Returns #t on success, #f on failure.
(def (automation-screenshot! app path)
  (let* ((fr (app-state-frame app))
         (main-win (qt-frame-main-win fr)))
    (if main-win
      (qt-widget-screenshot! main-win path)
      #f)))

;;;============================================================================
;;; State query
;;;============================================================================

;;; Return an alist describing the current application state.
(def (automation-state app)
  (let* ((fr (app-state-frame app))
         (buf (qt-current-buffer fr))
         (ed  (qt-current-editor fr))
         (ks  (app-state-key-state app))
         (wins (qt-frame-windows fr)))
    (list
      (cons 'buffer (if buf (buffer-name buf) "#<none>"))
      (cons 'point (if ed (qt-plain-text-edit-cursor-position ed) 0))
      (cons 'key-state
            (let ((prefix (key-state-prefix-keys ks)))
              (if (null? prefix)
                "normal"
                (string-append "prefix: " (apply string-append
                  (map (lambda (k) (string-append k " ")) prefix))))))
      (cons 'minibuffer *minibuffer-active?*)
      (cons 'minibuffer-text
            (if (and *minibuffer-active?* *mb-input*)
              (qt-line-edit-text *mb-input*)
              ""))
      (cons 'windows (length wins))
      (cons 'mode (if buf
                    (let ((lang (buffer-lexer-lang buf)))
                      (if lang (symbol->string lang) "fundamental"))
                    "none")))))

;;;============================================================================
;;; Wait for condition
;;;============================================================================

;;; Poll until predicate returns true on the state alist, or timeout.
;;; Pumps the Qt event loop between checks.
;;; Returns #t if predicate matched, #f on timeout.
;;;
;;; Usage:
;;;   (automation-wait! app
;;;     (lambda (state) (cdr (assq 'minibuffer state)))
;;;     2000)  ; wait up to 2 seconds for minibuffer to appear
(def (automation-wait! app predicate timeout-ms)
  (let ((start (current-time-ms)))
    (let loop ()
      (let ((state (automation-state app)))
        (cond
          ((predicate state) #t)
          ((> (- (current-time-ms) start) timeout-ms) #f)
          (else
           (qt-app-process-events! *qt-app-ref*)
           (loop)))))))

;;; Simple wall-clock millisecond timer.
(def (current-time-ms)
  (let ((t (current-time)))
    (+ (* (time-second t) 1000)
       (quotient (time-nanosecond t) 1000000))))

;;; Global reference to the Qt app (set from app.ss during init).
(def *qt-app-ref* #f)

(def (automation-set-qt-app! app)
  (set! *qt-app-ref* app))

;;; Key-target override: called with (fr) to find the active input widget.
;;; When #f, falls back to (qt-current-editor fr).
;;; Set from app.ss after terminal widget map is available.
;;; Purpose: when a terminal buffer is active, the focused widget is the
;;; QTerminalWidget (not the hidden QScintilla). Sending key events to a
;;; hidden widget via sendEvent may not reliably trigger event filters.
(def *automation-key-target-fn* #f)

(def (automation-set-key-target-fn! fn)
  (set! *automation-key-target-fn* fn))
