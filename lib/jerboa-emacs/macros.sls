#!chezscheme
;;; macros.sls — Project-wide macros for boilerplate reduction
;;;
;;; Ported from gerbil-emacs/macros.ss
;;; This file must NOT import any jerboa-emacs modules to avoid circular deps.

(library (jerboa-emacs macros)
  (export
    bind-keys!
    with-qt-editor with-editor
    msg! err!
    def-toggle def-toggle-mode
    defalias defstub
    set-face-style! set-face-style/bold! set-face-style/italic!
    set-face-styles! set-face-styles/bold! set-face-styles/italic!
    define-mode-keymap!
    with-qt-region with-region
    def-insert-template
    def-sci-getter def-sci-cmd! def-sci-setter!
    def-word-transform
    def-insert-pair
    __jemacs-macros-loaded__)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1-)
          (jerboa core)
          (jerboa runtime))

  ;; Dummy runtime definition to avoid macro-only compilation issues
  (def __jemacs-macros-loaded__ #t)

  ;;; ========================================================================
  ;;; bind-keys! — Keymap binding shorthand
  ;;; ========================================================================

  (define-syntax bind-keys!
    (syntax-rules ()
      ((_ keymap (key cmd) ...)
       (begin (keymap-bind! keymap key 'cmd) ...))))

  ;;; ========================================================================
  ;;; with-qt-editor — Qt state extraction
  ;;; ========================================================================

  (define-syntax with-qt-editor
    (syntax-rules ()
      ((_ app (ed text pos) body ...)
       (let* ((ed (current-qt-editor app))
              (text (qt-plain-text-edit-text ed))
              (pos (qt-plain-text-edit-cursor-position ed)))
         body ...))

      ((_ app (ed buf mark) body ...)
       (let* ((ed (current-qt-editor app))
              (buf (current-qt-buffer app))
              (mark (buffer-mark buf)))
         body ...))

      ((_ app (ed text) body ...)
       (let* ((ed (current-qt-editor app))
              (text (qt-plain-text-edit-text ed)))
         body ...))

      ((_ app (ed pos) body ...)
       (let* ((ed (current-qt-editor app))
              (pos (qt-plain-text-edit-cursor-position ed)))
         body ...))

      ((_ app (ed buf) body ...)
       (let* ((ed (current-qt-editor app))
              (buf (current-qt-buffer app)))
         body ...))

      ((_ app (ed) body ...)
       (let ((ed (current-qt-editor app))) body ...))))

  ;;; ========================================================================
  ;;; with-editor — TUI state extraction
  ;;; ========================================================================

  (define-syntax with-editor
    (syntax-rules ()
      ((_ app (ed text pos) body ...)
       (let* ((ed (current-editor app))
              (text (editor-get-text ed))
              (pos (editor-get-current-pos ed)))
         body ...))

      ((_ app (ed buf mark) body ...)
       (let* ((ed (current-editor app))
              (buf (current-buffer-from-app app))
              (mark (buffer-mark buf)))
         body ...))

      ((_ app (ed text) body ...)
       (let* ((ed (current-editor app))
              (text (editor-get-text ed)))
         body ...))

      ((_ app (ed pos) body ...)
       (let* ((ed (current-editor app))
              (pos (editor-get-current-pos ed)))
         body ...))

      ((_ app (ed buf) body ...)
       (let* ((ed (current-editor app))
              (buf (current-buffer-from-app app)))
         body ...))

      ((_ app (ed) body ...)
       (let ((ed (current-editor app))) body ...))))

  ;;; ========================================================================
  ;;; msg! / err! — Echo shorthand
  ;;; ========================================================================

  (define-syntax msg!
    (syntax-rules ()
      ((_ app text args ...)
       (echo-message! (app-state-echo app) text args ...))
      ((_ app text)
       (echo-message! (app-state-echo app) text))))

  (define-syntax err!
    (syntax-rules ()
      ((_ app text args ...)
       (echo-error! (app-state-echo app) text args ...))
      ((_ app text)
       (echo-error! (app-state-echo app) text))))

  ;;; ========================================================================
  ;;; def-toggle — Boolean toggle commands
  ;;; ========================================================================

  (define-syntax def-toggle
    (syntax-rules ()
      ((_ name var label)
       (def (name app)
         (set! var (not var))
         (msg! app (if var (string-append label " ON") (string-append label " OFF")))))))

  ;;; ========================================================================
  ;;; def-toggle-mode — toggle-mode! commands
  ;;; ========================================================================

  (define-syntax def-toggle-mode
    (syntax-rules ()
      ((_ name mode-sym label)
       (def (name app)
         (let ((on (toggle-mode! 'mode-sym)))
           (msg! app (if on (string-append label ": on") (string-append label ": off"))))))

      ((_ name mode-sym on-msg off-msg)
       (def (name app)
         (let ((on (toggle-mode! 'mode-sym)))
           (msg! app (if on on-msg off-msg)))))))

  ;;; ========================================================================
  ;;; defalias — Delegation commands
  ;;; ========================================================================

  (define-syntax defalias
    (syntax-rules ()
      ((_ new-name target)
       (def (new-name app) (target app)))))

  ;;; ========================================================================
  ;;; defstub — Message-only commands
  ;;; ========================================================================

  (define-syntax defstub
    (syntax-rules ()
      ((_ name message)
       (def (name app) (msg! app message)))))

  ;;; ========================================================================
  ;;; set-face-style! — Highlight macros
  ;;; ========================================================================

  (define-syntax set-face-style!
    (syntax-rules ()
      ((_ ed face-name style-id)
       (let-values (((r g b) (face-fg-rgb 'face-name)))
         (sci-send ed SCI_STYLESETFORE style-id (rgb->sci r g b))))))

  (define-syntax set-face-style/bold!
    (syntax-rules ()
      ((_ ed face-name style-id)
       (let-values (((r g b) (face-fg-rgb 'face-name)))
         (sci-send ed SCI_STYLESETFORE style-id (rgb->sci r g b))
         (when (face-has-bold? 'face-name)
           (sci-send ed SCI_STYLESETBOLD style-id 1))))))

  (define-syntax set-face-style/italic!
    (syntax-rules ()
      ((_ ed face-name style-id)
       (let-values (((r g b) (face-fg-rgb 'face-name)))
         (sci-send ed SCI_STYLESETFORE style-id (rgb->sci r g b))
         (when (face-has-italic? 'face-name)
           (sci-send ed SCI_STYLESETITALIC style-id 1))))))

  (define-syntax set-face-styles!
    (syntax-rules ()
      ((_ ed face-name style-id ...)
       (let-values (((r g b) (face-fg-rgb 'face-name)))
         (for-each (lambda (s) (sci-send ed SCI_STYLESETFORE s (rgb->sci r g b)))
                   (list style-id ...))))))

  (define-syntax set-face-styles/italic!
    (syntax-rules ()
      ((_ ed face-name style-id ...)
       (let-values (((r g b) (face-fg-rgb 'face-name)))
         (for-each (lambda (s)
                     (sci-send ed SCI_STYLESETFORE s (rgb->sci r g b))
                     (when (face-has-italic? 'face-name)
                       (sci-send ed SCI_STYLESETITALIC s 1)))
                   (list style-id ...))))))

  (define-syntax set-face-styles/bold!
    (syntax-rules ()
      ((_ ed face-name style-id ...)
       (let-values (((r g b) (face-fg-rgb 'face-name)))
         (for-each (lambda (s)
                     (sci-send ed SCI_STYLESETFORE s (rgb->sci r g b))
                     (when (face-has-bold? 'face-name)
                       (sci-send ed SCI_STYLESETBOLD s 1)))
                   (list style-id ...))))))

  ;;; ========================================================================
  ;;; define-mode-keymap! — Mode keymap definition
  ;;; ========================================================================

  (define-syntax define-mode-keymap!
    (syntax-rules ()
      ((_ mode-name (key cmd) ...)
       (let ((km (make-keymap)))
         (keymap-bind! km key 'cmd) ...
         (hash-put! *mode-keymaps* 'mode-name km)))))

  ;;; ========================================================================
  ;;; with-qt-region / with-region — Region transform commands
  ;;; ========================================================================

  (define-syntax with-qt-region
    (syntax-rules ()
      ((_ app (ed text start end region) body ...)
       (let* ((ed (current-qt-editor app))
              (buf (current-qt-buffer app))
              (mark (buffer-mark buf)))
         (if (not mark)
           (err! app "No mark set")
           (let* ((pos (qt-plain-text-edit-cursor-position ed))
                  (start (min mark pos))
                  (end (max mark pos))
                  (text (qt-plain-text-edit-text ed))
                  (region (substring text start end)))
             body ...))))))

  (define-syntax with-region
    (syntax-rules ()
      ((_ app (ed text start end region) body ...)
       (let* ((ed (current-editor app))
              (buf (current-buffer-from-app app))
              (mark (buffer-mark buf)))
         (if (not mark)
           (err! app "No mark set")
           (let* ((pos (editor-get-current-pos ed))
                  (start (min mark pos))
                  (end (max mark pos))
                  (text (editor-get-text ed))
                  (region (substring text start end)))
             body ...))))))

  ;;; ========================================================================
  ;;; def-insert-template — Template insertion
  ;;; ========================================================================

  (define-syntax def-insert-template
    (syntax-rules ()
      ((_ name template cursor-offset)
       (def (name app)
         (with-qt-editor app (ed pos)
           (qt-plain-text-edit-insert-text! ed template)
           (qt-plain-text-edit-set-cursor-position! ed (+ pos cursor-offset)))))))

  ;;; ========================================================================
  ;;; def-sci-wrapper — Scintilla wrapper macros
  ;;; ========================================================================

  (define-syntax def-sci-getter
    (syntax-rules ()
      ((_ name msg)
       (def (name sci) (sci-send sci msg)))))

  (define-syntax def-sci-cmd!
    (syntax-rules ()
      ((_ name msg)
       (def (name sci) (sci-send sci msg)))))

  (define-syntax def-sci-setter!
    (syntax-rules ()
      ((_ name msg)
       (def (name sci val) (sci-send sci msg val)))))

  ;;; ========================================================================
  ;;; def-word-transform — Word case commands
  ;;; ========================================================================

  (define-syntax def-word-transform
    (syntax-rules ()
      ((_ name transform-fn)
       (def (name app)
         (let ((ed (current-qt-editor app)))
           (let-values (((start end) (qt-word-at-point ed)))
             (when start
               (let* ((text (qt-plain-text-edit-text ed))
                      (word (substring text start end))
                      (transformed (transform-fn word))
                      (new-text (string-append (substring text 0 start) transformed
                                               (substring text end (string-length text)))))
                 (qt-plain-text-edit-set-text! ed new-text)
                 (qt-plain-text-edit-set-cursor-position! ed end)))))))))

  ;;; ========================================================================
  ;;; def-insert-pair — Delimiter pair insertion (TUI version)
  ;;; ========================================================================

  (define-syntax def-insert-pair
    (syntax-rules ()
      ((_ name open-close)
       (def (name app)
         (with-editor app (ed pos)
           (editor-insert-text ed pos open-close)
           (editor-goto-pos ed (+ pos 1)))))))

  ) ;; end library
