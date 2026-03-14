#!chezscheme
;;; window.sls — Frame and window layout for jemacs
;;;
;;; Ported from gerbil-emacs/window.ss
;;;
;;; Architecture:
;;;   frame holds:
;;;     - root       : the logical split tree (split-leaf | split-node)
;;;     - windows    : flat ordered list of edit-window (derived, kept in sync)
;;;     - current-idx: index of active window in windows list
;;;     - width/height: terminal dimensions
;;;
;;;   split-leaf(win)  : a single editor pane
;;;   split-node(orientation, children) : a logical split with 2+ children
;;;
;;; Splits always insert the new window AFTER the current one in the flat
;;; list. Layout is computed recursively from the tree.

(library (jerboa-emacs window)
  (export
    ;; edit-window struct
    make-edit-window edit-window?
    edit-window-editor edit-window-editor-set!
    edit-window-buffer edit-window-buffer-set!
    edit-window-x edit-window-x-set!
    edit-window-y edit-window-y-set!
    edit-window-w edit-window-w-set!
    edit-window-h edit-window-h-set!
    edit-window-size-bias edit-window-size-bias-set!
    ;; frame struct
    make-frame frame?
    frame-root frame-root-set!
    frame-windows frame-windows-set!
    frame-current-idx frame-current-idx-set!
    frame-width frame-width-set!
    frame-height frame-height-set!
    ;; split-leaf struct
    make-split-leaf split-leaf?
    split-leaf-edit-window split-leaf-edit-window-set!
    ;; split-node struct
    make-split-node split-node?
    split-node-orientation split-node-orientation-set!
    split-node-children split-node-children-set!
    ;; functions
    current-window
    frame-init!
    frame-shutdown!
    frame-resize!
    frame-layout!
    frame-refresh!
    frame-split!
    frame-split-right!
    frame-delete-window!
    frame-delete-other-windows!
    frame-other-window!
    frame-draw-dividers!
    frame-enlarge-window!
    frame-shrink-window!
    frame-enlarge-window-horizontally!
    frame-shrink-window-horizontally!
    ;; Tree helpers (for tests)
    split-tree-flatten
    split-tree-find-parent
    split-tree-find-leaf)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (jerboa-emacs core)
          (jerboa-emacs buffer)
          (chez-scintilla scintilla)
          (chez-scintilla tui))

  ;;;========================================================================
  ;;; Structures
  ;;;========================================================================

  (defstruct edit-window
    (editor    ; scintilla-editor instance
     buffer    ; buffer struct
     x y w h   ; position and size in terminal cells
     size-bias)) ; integer offset for window resize (default 0)

  ;; A split-leaf wraps a single edit window.
  (defstruct split-leaf (edit-window))

  ;; A split-node is a logical split with 2+ children (each a split-leaf or split-node).
  ;; orientation is 'horizontal or 'vertical.
  (defstruct split-node
    (orientation    ; 'horizontal | 'vertical
     children))     ; list of split-leaf | split-node

  ;; The main frame struct.
  ;; root     = logical split tree (split-leaf when single pane).
  ;; windows  = flat ordered list derived from root, kept in sync.
  ;; current-idx = index of active window in windows list.
  (defstruct frame
    (root            ; split-leaf | split-node
     windows         ; list of edit-window
     current-idx     ; index of active window
     width           ; terminal width
     height))        ; terminal height

  ;;;========================================================================
  ;;; Accessors
  ;;;========================================================================

  (define (current-window fr)
    (list-ref (frame-windows fr) (frame-current-idx fr)))

  ;;;========================================================================
  ;;; Split tree helpers
  ;;;========================================================================

  (define (split-tree-flatten node)
    "Return ordered flat list of edit-window from tree, left-to-right depth-first."
    (cond
      ((split-leaf? node) (list (split-leaf-edit-window node)))
      ((split-node? node)
       (apply append (map split-tree-flatten (split-node-children node))))))

  (define (split-tree-find-parent root win)
    "Return the split-node whose direct children include the leaf for WIN, or #f."
    (cond
      ((split-leaf? root) #f)
      ((split-node? root)
       (let loop ((children (split-node-children root)))
         (cond
           ((null? children) #f)
           ((and (split-leaf? (car children))
                 (eq? (split-leaf-edit-window (car children)) win))
            root)
           (else
            (let ((found (split-tree-find-parent (car children) win)))
              (or found (loop (cdr children))))))))))

  (define (split-tree-find-leaf root win)
    "Return the split-leaf node for WIN, or #f."
    (cond
      ((split-leaf? root)
       (if (eq? (split-leaf-edit-window root) win) root #f))
      ((split-node? root)
       (let loop ((children (split-node-children root)))
         (if (null? children) #f
           (or (split-tree-find-leaf (car children) win)
               (loop (cdr children))))))))

  (define (split-tree-find-parent-of-node root child-node)
    "Return the split-node that contains CHILD-NODE as a direct child, or #f."
    (cond
      ((split-leaf? root) #f)
      ((split-node? root)
       (if (exists (lambda (c) (eq? c child-node)) (split-node-children root))
         root
         (let loop ((children (split-node-children root)))
           (if (null? children) #f
             (or (split-tree-find-parent-of-node (car children) child-node)
                 (loop (cdr children)))))))))

  (define (split-tree-replace-child! node old-child new-child)
    "Replace OLD-CHILD with NEW-CHILD in NODE's children list."
    (split-node-children-set! node
      (map (lambda (c) (if (eq? c old-child) new-child c))
           (split-node-children node))))

  (define (split-tree-remove-child! node child)
    "Remove CHILD from NODE's children list."
    (split-node-children-set! node
      (filter (lambda (c) (not (eq? c child)))
              (split-node-children node))))

  ;;;========================================================================
  ;;; Helpers
  ;;;========================================================================

  (define (list-index pred lst)
    "Find the index of the first element matching pred, or #f."
    (let loop ((l lst) (i 0))
      (cond
        ((null? l) #f)
        ((pred (car l)) i)
        (else (loop (cdr l) (+ i 1))))))

  (define (list-remove-idx lst idx)
    (let loop ((l lst) (i 0) (acc '()))
      (cond
        ((null? l) (reverse acc))
        ((= i idx) (append (reverse acc) (cdr l)))
        (else (loop (cdr l) (+ i 1) (cons (car l) acc))))))

  (define (last-element lst)
    "Return the last element of a non-empty list."
    (if (null? (cdr lst))
      (car lst)
      (last-element (cdr lst))))

  ;;;========================================================================
  ;;; Frame initialization and shutdown
  ;;;========================================================================

  (define (frame-init! width height)
    "Create initial frame with one window and a scratch buffer."
    (let* ((edit-h (max 1 (- height 2)))  ; 1 row modeline, 1 row echo
           (ed (create-scintilla-editor width edit-h))
           (buf (buffer-create-from-editor! buffer-scratch-name ed))
           (win (make-edit-window ed buf 0 0 width (- height 1) 0))
           (root (make-split-leaf win)))
      (make-frame root (list win) 0 width height)))

  (define (frame-shutdown! fr)
    "Destroy all editors in the frame."
    (for-each (lambda (win) (editor-destroy (edit-window-editor win)))
              (frame-windows fr)))

  ;;;========================================================================
  ;;; Layout: recursively compute positions and sizes from tree
  ;;;========================================================================

  (define (frame-layout! fr)
    "Recursively layout the split tree within the frame bounds."
    (let* ((width (frame-width fr))
           (height (frame-height fr))
           (avail-h (- height 1)))  ; 1 row for echo area
      (split-tree-layout! (frame-root fr) 0 0 width avail-h)))

  (define (split-tree-layout! node x y w h)
    "Recursively layout NODE within bounding box (x, y, w, h)."
    (cond
      ((split-leaf? node)
       ;; Leaf: set window position directly
       (let* ((win (split-leaf-edit-window node))
              (edit-h (max 1 (- h 1))))  ; 1 row for modeline
         (edit-window-x-set! win x)
         (edit-window-y-set! win y)
         (edit-window-w-set! win w)
         (edit-window-h-set! win h)
         (editor-resize (edit-window-editor win) w edit-h)
         (editor-move (edit-window-editor win) x y)))

      ((split-node? node)
       ;; Node: divide space among children based on orientation
       (let* ((orientation (split-node-orientation node))
              (children (split-node-children node))
              (n (length children)))
         (if (eq? orientation 'vertical)
           ;; Vertical: stack children top to bottom
           (let* ((avail h)
                  (per-child (quotient avail n))
                  (extra (remainder avail n))
                  ;; Compute sizes (even distribution + bias)
                  (sizes (let loop ((cs children) (i 0) (acc '()))
                           (if (null? cs) (reverse acc)
                             (let* ((child (car cs))
                                    (bias (if (split-leaf? child)
                                            (or (edit-window-size-bias
                                                  (split-leaf-edit-window child)) 0)
                                            0))
                                    (size (+ per-child
                                             (if (< i extra) 1 0)
                                             bias)))
                               (loop (cdr cs) (+ i 1) (cons (max 2 size) acc))))))
                  ;; Normalize to ensure total = avail
                  (total (apply + sizes))
                  (final-sizes (if (= total avail)
                                 sizes
                                 (let ((delta (- avail total)))
                                   (cons (+ (car sizes) delta) (cdr sizes))))))
             ;; Layout children recursively
             (let loop ((cs children) (szs final-sizes) (cy y))
               (when (and (pair? cs) (pair? szs))
                 (let ((ch (car szs)))
                   (split-tree-layout! (car cs) x cy w ch)
                   (loop (cdr cs) (cdr szs) (+ cy ch))))))

           ;; Horizontal: place children left to right
           (let* ((dividers (max 0 (- n 1)))  ; vertical dividers between children
                  (avail (- w dividers))
                  (per-child (quotient avail n))
                  (extra (remainder avail n))
                  (sizes (let loop ((cs children) (i 0) (acc '()))
                           (if (null? cs) (reverse acc)
                             (let* ((child (car cs))
                                    (bias (if (split-leaf? child)
                                            (or (edit-window-size-bias
                                                  (split-leaf-edit-window child)) 0)
                                            0))
                                    (size (+ per-child
                                             (if (< i extra) 1 0)
                                             bias)))
                               (loop (cdr cs) (+ i 1) (cons (max 4 size) acc))))))
                  (total (apply + sizes))
                  (final-sizes (if (= total avail)
                                 sizes
                                 (let ((delta (- avail total)))
                                   (cons (+ (car sizes) delta) (cdr sizes))))))
             ;; Layout children recursively
             (let loop ((cs children) (szs final-sizes) (cx x))
               (when (and (pair? cs) (pair? szs))
                 (let ((cw (car szs)))
                   (split-tree-layout! (car cs) cx y cw h)
                   (loop (cdr cs) (cdr szs) (+ cx cw 1)))))))))))  ; +1 for divider

  ;;;========================================================================
  ;;; Resize (terminal size changed)
  ;;;========================================================================

  (define (frame-resize! fr width height)
    (frame-width-set! fr width)
    (frame-height-set! fr height)
    (frame-layout! fr))

  ;;;========================================================================
  ;;; Refresh all editors
  ;;;========================================================================

  (define (frame-refresh! fr)
    (for-each (lambda (win)
                (editor-refresh (edit-window-editor win)))
              (frame-windows fr)))

  ;;;========================================================================
  ;;; Window splitting — tree-based architecture
  ;;;========================================================================

  (define (frame-do-split! fr orientation)
    "Split the currently focused window with ORIENTATION ('horizontal | 'vertical).
     Returns the new editor widget."
    (let* ((cur-win   (current-window fr))
           (cur-leaf  (split-tree-find-leaf (frame-root fr) cur-win))
           (parent    (split-tree-find-parent (frame-root fr) cur-win))
           (cur-buf   (edit-window-buffer cur-win))
           (new-ed    (create-scintilla-editor))
           (new-win   (make-edit-window new-ed cur-buf 0 0 0 0 0)))

      (buffer-attach! new-ed cur-buf)

      (cond
        ;; Case A: parent has same orientation — add sibling
        ((and parent (eq? (split-node-orientation parent) orientation))
         (let ((new-leaf (make-split-leaf new-win)))
           ;; Insert new-leaf after cur-leaf in parent's children
           (split-node-children-set! parent
             (let loop ((cs (split-node-children parent)) (acc '()))
               (cond
                 ((null? cs) (reverse (cons new-leaf acc)))
                 ((eq? (car cs) cur-leaf)
                  (append (reverse (cons new-leaf (cons cur-leaf acc))) (cdr cs)))
                 (else (loop (cdr cs) (cons (car cs) acc))))))
           ;; Rebuild flat list from tree
           (frame-windows-set! fr (split-tree-flatten (frame-root fr)))
           ;; Find new window's index
           (let ((new-idx (list-index (lambda (w) (eq? w new-win)) (frame-windows fr))))
             (frame-current-idx-set! fr (or new-idx 0)))
           (frame-layout! fr)
           new-ed))

        ;; Case B: root is a leaf (very first split)
        ((split-leaf? (frame-root fr))
         (let* ((new-leaf (make-split-leaf new-win))
                (new-node (make-split-node orientation (list cur-leaf new-leaf))))
           (frame-root-set! fr new-node)
           ;; Rebuild flat list from tree
           (frame-windows-set! fr (split-tree-flatten (frame-root fr)))
           ;; Find new window's index
           (let ((new-idx (list-index (lambda (w) (eq? w new-win)) (frame-windows fr))))
             (frame-current-idx-set! fr (or new-idx 0)))
           (frame-layout! fr)
           new-ed))

        ;; Case C: no parent or different orientation — nest
        (else
         (let* ((new-leaf (make-split-leaf new-win))
                (new-node (make-split-node orientation (list cur-leaf new-leaf))))
           ;; Replace cur-leaf with new-node in parent (or set as root)
           (cond
             (parent (split-tree-replace-child! parent cur-leaf new-node))
             (else   (frame-root-set! fr new-node)))
           ;; Rebuild flat list from tree
           (frame-windows-set! fr (split-tree-flatten (frame-root fr)))
           ;; Find new window's index
           (let ((new-idx (list-index (lambda (w) (eq? w new-win)) (frame-windows fr))))
             (frame-current-idx-set! fr (or new-idx 0)))
           (frame-layout! fr)
           new-ed)))))

  (define (frame-split! fr)
    "Split vertically: add a new window below. Returns the new editor."
    (frame-do-split! fr 'vertical))

  (define (frame-split-right! fr)
    "Split horizontally: add a new window to the right. Returns the new editor."
    (frame-do-split! fr 'horizontal))

  (define (frame-delete-window! fr)
    "Delete the current window (if more than one).
     Automatically unwraps single-child split nodes when they arise."
    (when (> (length (frame-windows fr)) 1)
      (let* ((idx       (frame-current-idx fr))
             (win       (list-ref (frame-windows fr) idx))
             (root      (frame-root fr))
             (cur-leaf  (split-tree-find-leaf root win))
             (parent    (split-tree-find-parent root win)))

        ;; Destroy the editor
        (editor-destroy (edit-window-editor win))

        ;; Update tree: remove cur-leaf from parent
        (when parent
          (split-tree-remove-child! parent cur-leaf)
          (let ((remaining (split-node-children parent)))
            ;; If parent now has exactly 1 child, unwrap it
            (when (and remaining (= 1 (length remaining)))
              (let* ((only-child  (car remaining))
                     (grandparent (split-tree-find-parent-of-node root parent)))
                ;; Replace parent with only-child
                (if grandparent
                  (split-tree-replace-child! grandparent parent only-child)
                  (frame-root-set! fr only-child))))))

        ;; Rebuild flat windows list and current-idx
        (frame-windows-set! fr (split-tree-flatten (frame-root fr)))
        (when (>= idx (length (frame-windows fr)))
          (frame-current-idx-set! fr (- (length (frame-windows fr)) 1)))
        (frame-layout! fr))))

  (define (frame-delete-other-windows! fr)
    "Keep only the current window, destroy all others."
    (let ((cur (current-window fr)))
      ;; Destroy all other editors
      (for-each (lambda (win)
                  (unless (eq? win cur)
                    (editor-destroy (edit-window-editor win))))
                (frame-windows fr))
      ;; Reset tree to single leaf
      (frame-root-set! fr (make-split-leaf cur))
      (frame-windows-set! fr (list cur))
      (frame-current-idx-set! fr 0)
      (frame-layout! fr)))

  (define (frame-other-window! fr)
    "Switch to the next window."
    (let ((n (length (frame-windows fr))))
      (frame-current-idx-set! fr
        (modulo (+ (frame-current-idx fr) 1) n))))

  ;;;========================================================================
  ;;; Divider drawing (for horizontal splits)
  ;;;========================================================================

  (define (frame-draw-dividers! fr)
    "Recursively draw vertical divider lines between horizontally split windows."
    (let ((fg #x808080)
          (bg #x181818)
          (height (- (frame-height fr) 1)))
      (split-tree-draw-dividers! (frame-root fr) height fg bg)))

  (define (split-tree-draw-dividers! node height fg bg)
    "Recursively draw dividers for horizontal splits in the tree."
    (when (split-node? node)
      (when (eq? (split-node-orientation node) 'horizontal)
        ;; For each child except the last, draw a divider after it
        (let loop ((children (split-node-children node)))
          (when (and (pair? children) (pair? (cdr children)))
            (let* ((child (car children))
                   ;; Get rightmost window in this child subtree
                   (wins (split-tree-flatten child))
                   (rightmost (if (null? wins) #f (last-element wins))))
              (when rightmost
                (let ((x (+ (edit-window-x rightmost)
                            (edit-window-w rightmost))))
                  (let yloop ((y 0))
                    (when (< y height)
                      (tui-change-cell! x y (char->integer #\x2502) fg bg)
                      (yloop (+ y 1))))))
              (loop (cdr children))))))
      ;; Recurse into children
      (for-each (lambda (child) (split-tree-draw-dividers! child height fg bg))
                (split-node-children node))))

  ;;;========================================================================
  ;;; Window resizing
  ;;;========================================================================

  (define frame-enlarge-window!
    (case-lambda
      ((fr) (frame-enlarge-window! fr 1))
      ((fr delta)
       (let* ((windows (frame-windows fr))
              (n (length windows)))
         (when (> n 1)
           (let* ((idx (frame-current-idx fr))
                  (cur (list-ref windows idx))
                  ;; Steal from neighbor
                  (neighbor-idx (if (< idx (- n 1)) (+ idx 1) (- idx 1)))
                  (neighbor (list-ref windows neighbor-idx)))
             (edit-window-size-bias-set! cur
               (+ (or (edit-window-size-bias cur) 0) delta))
             (edit-window-size-bias-set! neighbor
               (- (or (edit-window-size-bias neighbor) 0) delta))
             (frame-layout! fr)))))))

  (define frame-shrink-window!
    (case-lambda
      ((fr) (frame-shrink-window! fr 1))
      ((fr delta)
       (frame-enlarge-window! fr (- delta)))))

  (define frame-enlarge-window-horizontally!
    (case-lambda
      ((fr) (frame-enlarge-window-horizontally! fr 1))
      ((fr delta)
       (frame-enlarge-window! fr delta))))

  (define frame-shrink-window-horizontally!
    (case-lambda
      ((fr) (frame-shrink-window-horizontally! fr 1))
      ((fr delta)
       (frame-shrink-window! fr delta))))

) ;; end library
