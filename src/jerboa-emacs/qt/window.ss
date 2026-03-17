;;; -*- Gerbil -*-
;;; Qt frame/window management for jerboa-emacs
;;;
;;; Ported from gerbil-emacs/qt/window.ss
;;; STUB VERSION - Full implementation to be completed in Sprint 2
;;; Uses nested QSplitters to hold multiple QPlainTextEdit panes.

(export (struct-out qt-edit-window)
        (struct-out qt-frame)
        (struct-out split-leaf)
        (struct-out split-node)
        qt-current-window
        qt-current-editor
        qt-current-buffer
        qt-frame-init!
        qt-frame-split!
        qt-frame-split-right!
        qt-frame-delete-window!
        qt-frame-delete-other-windows!
        qt-frame-other-window!
        qt-apply-editor-theme!
        split-tree-flatten
        split-tree-find-parent
        split-tree-find-leaf
        split-tree-collect-sub-splitters)

(import :std/sugar
        :jerboa-emacs/qt/sci-shim
        :jerboa-emacs/core
        :jerboa-emacs/face
        :jerboa-emacs/qt/buffer)

;;;============================================================================
;;; Structures
;;;============================================================================

(defstruct qt-edit-window
  (editor           ; QScintilla editor pointer
   container        ; QStackedWidget wrapping editor + image widget
   buffer           ; buffer struct
   line-number-area ; line-number-area pointer or #f
   image-scroll     ; QScrollArea for image display, or #f (lazy)
   image-label)     ; QLabel inside scroll area, or #f (lazy)
  transparent: #t)

(defstruct split-leaf (edit-window) transparent: #t)

(defstruct split-node
  (orientation   ; QT_HORIZONTAL | QT_VERTICAL
   splitter      ; QSplitter widget pointer
   children)     ; list of split-leaf | split-node
  transparent: #t)

(defstruct qt-frame
  (splitter     ; QSplitter pointer (permanent root splitter)
   root         ; split-leaf | split-node
   windows      ; list of qt-edit-window
   current-idx  ; index of active window
   main-win)    ; QMainWindow pointer
  transparent: #t)

;;;============================================================================
;;; Accessors
;;;============================================================================

(def (qt-current-window fr)
  (list-ref (qt-frame-windows fr) (qt-frame-current-idx fr)))

(def (qt-current-editor fr)
  (qt-edit-window-editor (qt-current-window fr)))

(def (qt-current-buffer fr)
  (qt-edit-window-buffer (qt-current-window fr)))

;;;============================================================================
;;; Split tree helpers (STUB - to be implemented)
;;;============================================================================

(def (split-tree-flatten root)
  ;; STUB: Returns flat list of edit windows from split tree
  (if (split-leaf? root)
    (list (split-leaf-edit-window root))
    '()))

(def (split-tree-find-parent tree target-splitter)
  ;; STUB: Finds parent of a splitter in tree
  #f)

(def (split-tree-find-leaf tree pred)
  ;; STUB: Finds first leaf matching predicate
  #f)

(def (split-tree-collect-sub-splitters tree)
  ;; STUB: Collects all sub-splitters
  '())

;;;============================================================================
;;; Frame operations (STUB - to be implemented)
;;;============================================================================

(def (qt-frame-init! main-win buffer)
  ;; STUB: Initialize frame with initial buffer
  (let* ((editor (qt-plain-text-edit-create))
         (container editor)  ; Simplified - should be QStackedWidget
         (win (make-qt-edit-window editor container buffer #f #f #f))
         (leaf (make-split-leaf win))
         (splitter #f)  ; To be created
         (fr (make-qt-frame splitter leaf (list win) 0 main-win)))
    (qt-buffer-attach! editor buffer)
    fr))

(def (qt-frame-split! fr (horizontal? #t))
  ;; STUB: Split current window
  (void))

(def (qt-frame-split-right! fr)
  ;; STUB: Split window vertically (side-by-side)
  (void))

(def (qt-frame-delete-window! fr)
  ;; STUB: Delete current window
  (void))

(def (qt-frame-delete-other-windows! fr)
  ;; STUB: Delete all windows except current
  (void))

(def (qt-frame-other-window! fr (delta 1))
  ;; STUB: Switch to other window
  (let* ((wins (qt-frame-windows fr))
         (n (length wins))
         (cur (qt-frame-current-idx fr))
         (new-idx (modulo (+ cur delta) n)))
    (set! (qt-frame-current-idx fr) new-idx)
    (qt-current-window fr)))

(def (qt-apply-editor-theme! editor)
  ;; STUB: Apply theme to editor
  (void))
