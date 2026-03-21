;;; -*- Gerbil -*-
;;; VT100 virtual terminal screen buffer — libvterm backend.
;;;
;;; Uses libvterm (via vterm_shim.so) for complete VT100/VT220/xterm
;;; terminal emulation with:
;;;   - C-speed byte parsing (no per-byte Scheme overhead)
;;;   - Full SGR color support (16/256/RGB per-cell)
;;;   - Proper alt screen buffer with save/restore
;;;   - Unicode + combining characters + wide chars
;;;   - Scrollback ring buffer with sb_pushline/sb_popline
;;;   - Row-level damage tracking for efficient rendering
;;;   - Resize with line reflow
;;;
;;; API is backwards-compatible with the old pure-Scheme vtscreen.

(export new-vtscreen
        vtscreen-feed!
        vtscreen-render
        vtscreen-resize!
        vtscreen-rows
        vtscreen-cols
        vtscreen-cursor-row
        vtscreen-cursor-col
        vtscreen-alt-screen?
        ;; New: row-level damage tracking for batched updates
        vtscreen-has-damage?
        vtscreen-row-dirty?
        vtscreen-clear-damage!
        vtscreen-mark-all-dirty!
        ;; New: per-row text extraction
        vtscreen-get-row-text
        ;; New: scrollback access
        vtscreen-scrollback-len
        vtscreen-scrollback-line
        vtscreen-scrollback-clear!
        ;; New: per-cell color queries (packed 0x00RRGGBB, -1 = default)
        vtscreen-cell-fg
        vtscreen-cell-bg
        vtscreen-cell-attrs
        ;; New: free resources
        vtscreen-free!)

(import :std/sugar)

;;;============================================================================
;;; FFI: load vterm_shim.so and bind C functions
;;;============================================================================

(def vterm-shim-loaded
  (let ((dir (or (getenv "JERBOA_EMACS_SUPPORT")
                 (string-append (or (getenv "HOME") ".") "/mine/jerboa-emacs"))))
    (load-shared-object (string-append dir "/vterm_shim.so"))))

;; Core lifecycle
(def ffi-jvt-new       (foreign-procedure "jvt_new" (int int) void*))
(def ffi-jvt-free      (foreign-procedure "jvt_free" (void*) void))
(def ffi-jvt-write     (foreign-procedure "jvt_write" (void* u8* int) void))
(def ffi-jvt-resize    (foreign-procedure "jvt_resize" (void* int int) void))

;; Text extraction
(def ffi-jvt-get-row-text (foreign-procedure "jvt_get_row_text" (void* int u8* int) int))
(def ffi-jvt-get-text     (foreign-procedure "jvt_get_text" (void* u8* int int int) int))

;; State queries
(def ffi-jvt-is-altscreen  (foreign-procedure "jvt_is_altscreen" (void*) int))
(def ffi-jvt-get-rows      (foreign-procedure "jvt_get_rows" (void*) int))
(def ffi-jvt-get-cols      (foreign-procedure "jvt_get_cols" (void*) int))
(def ffi-jvt-get-cursor-row (foreign-procedure "jvt_get_cursor_row" (void*) int))
(def ffi-jvt-get-cursor-col (foreign-procedure "jvt_get_cursor_col" (void*) int))

;; Damage tracking
(def ffi-jvt-has-damage     (foreign-procedure "jvt_has_damage" (void*) int))
(def ffi-jvt-row-dirty      (foreign-procedure "jvt_row_dirty" (void* int) int))
(def ffi-jvt-clear-damage   (foreign-procedure "jvt_clear_damage" (void*) void))
(def ffi-jvt-mark-all-dirty (foreign-procedure "jvt_mark_all_dirty" (void*) void))

;; Per-cell color/attrs
(def ffi-jvt-get-cell-fg    (foreign-procedure "jvt_get_cell_fg" (void* int int) int))
(def ffi-jvt-get-cell-bg    (foreign-procedure "jvt_get_cell_bg" (void* int int) int))
(def ffi-jvt-get-cell-attrs (foreign-procedure "jvt_get_cell_attrs" (void* int int) int))

;; Scrollback
(def ffi-jvt-scrollback-len   (foreign-procedure "jvt_scrollback_len" (void*) int))
(def ffi-jvt-scrollback-line  (foreign-procedure "jvt_scrollback_line" (void* int u8* int) int))
(def ffi-jvt-scrollback-clear (foreign-procedure "jvt_scrollback_clear" (void*) void))

;;;============================================================================
;;; Vtscreen wrapper — opaque handle
;;;============================================================================

;; The vtscreen is just the void* handle from jvt_new.
;; We use a box so we can set it to #f after free.

(defstruct vtscreen
  (handle)   ; void* — the JvtState pointer
  transparent: #t)

(def (new-vtscreen (rows 24) (cols 80))
  "Create a new virtual terminal screen backed by libvterm."
  (let ((h (ffi-jvt-new rows cols)))
    (if h
      (make-vtscreen h)
      (error "jvt_new failed"))))

(def (vtscreen-free! vt)
  "Free the libvterm resources. Must be called when done."
  (let ((h (vtscreen-handle vt)))
    (when h
      (ffi-jvt-free h)
      (set! (vtscreen-handle vt) #f))))

;;;============================================================================
;;; Core API (backwards-compatible with old vtscreen)
;;;============================================================================

(def (vtscreen-feed! vt data)
  "Process terminal output through libvterm.
   data: a string of bytes from the PTY."
  (let ((h (vtscreen-handle vt)))
    (when h
      (let ((bv (string->utf8 data)))
        (ffi-jvt-write h bv (bytevector-length bv))))))

(def *render-buf-size* 131072)  ;; 128KB — enough for 24×80 with Unicode
(def *render-buf* (make-bytevector *render-buf-size* 0))

(def (vtscreen-render vt)
  "Render the entire screen to a string (trimmed).
   Compatible with old vtscreen-render API."
  (let ((h (vtscreen-handle vt)))
    (if h
      (let ((n (ffi-jvt-get-text h *render-buf* *render-buf-size* 0
                                 (ffi-jvt-get-rows h))))
        (if (> n 0)
          (utf8->string (let ((bv (make-bytevector n)))
                          (bytevector-copy! *render-buf* 0 bv 0 n)
                          bv))
          ""))
      "")))

(def (vtscreen-resize! vt new-rows new-cols)
  "Resize the virtual screen."
  (let ((h (vtscreen-handle vt)))
    (when h
      (ffi-jvt-resize h new-rows new-cols))))

(def (vtscreen-rows vt)
  "Get number of rows."
  (let ((h (vtscreen-handle vt)))
    (if h (ffi-jvt-get-rows h) 0)))

(def (vtscreen-cols vt)
  "Get number of columns."
  (let ((h (vtscreen-handle vt)))
    (if h (ffi-jvt-get-cols h) 0)))

(def (vtscreen-cursor-row vt)
  "Get current cursor row (0-based)."
  (let ((h (vtscreen-handle vt)))
    (if h (ffi-jvt-get-cursor-row h) 0)))

(def (vtscreen-cursor-col vt)
  "Get current cursor column (0-based)."
  (let ((h (vtscreen-handle vt)))
    (if h (ffi-jvt-get-cursor-col h) 0)))

(def (vtscreen-alt-screen? vt)
  "Check if alt screen buffer is active."
  (let ((h (vtscreen-handle vt)))
    (if h (not (= 0 (ffi-jvt-is-altscreen h))) #f)))

;;;============================================================================
;;; Row-level damage tracking (Option C: batched row updates)
;;;============================================================================

(def (vtscreen-has-damage? vt)
  "Check if any row has changed since last clear-damage."
  (let ((h (vtscreen-handle vt)))
    (if h (not (= 0 (ffi-jvt-has-damage h))) #f)))

(def (vtscreen-row-dirty? vt row)
  "Check if a specific row has changed."
  (let ((h (vtscreen-handle vt)))
    (if h (not (= 0 (ffi-jvt-row-dirty h row))) #f)))

(def (vtscreen-clear-damage! vt)
  "Clear all damage flags."
  (let ((h (vtscreen-handle vt)))
    (when h (ffi-jvt-clear-damage h))))

(def (vtscreen-mark-all-dirty! vt)
  "Mark all rows as dirty (e.g., for initial render)."
  (let ((h (vtscreen-handle vt)))
    (when h (ffi-jvt-mark-all-dirty h))))

;;;============================================================================
;;; Per-row text extraction
;;;============================================================================

(def *row-buf-size* 4096)
(def *row-buf* (make-bytevector *row-buf-size* 0))

(def (vtscreen-get-row-text vt row)
  "Get the text content of a single row as a string (trailing spaces trimmed)."
  (let ((h (vtscreen-handle vt)))
    (if h
      (let ((n (ffi-jvt-get-row-text h row *row-buf* *row-buf-size*)))
        (if (> n 0)
          (utf8->string (let ((bv (make-bytevector n)))
                          (bytevector-copy! *row-buf* 0 bv 0 n)
                          bv))
          ""))
      "")))

;;;============================================================================
;;; Scrollback access
;;;============================================================================

(def (vtscreen-scrollback-len vt)
  "Get number of scrollback lines."
  (let ((h (vtscreen-handle vt)))
    (if h (ffi-jvt-scrollback-len h) 0)))

(def *sb-buf-size* 4096)
(def *sb-buf* (make-bytevector *sb-buf-size* 0))

(def (vtscreen-scrollback-line vt idx)
  "Get scrollback line by index (0 = most recent). Returns string."
  (let ((h (vtscreen-handle vt)))
    (if h
      (let ((n (ffi-jvt-scrollback-line h idx *sb-buf* *sb-buf-size*)))
        (if (> n 0)
          (utf8->string (let ((bv (make-bytevector n)))
                          (bytevector-copy! *sb-buf* 0 bv 0 n)
                          bv))
          ""))
      "")))

(def (vtscreen-scrollback-clear! vt)
  "Clear all scrollback lines."
  (let ((h (vtscreen-handle vt)))
    (when h (ffi-jvt-scrollback-clear h))))

;;;============================================================================
;;; Per-cell color and attribute queries
;;;============================================================================

(def (vtscreen-cell-fg vt row col)
  "Get foreground color as packed 0x00RRGGBB. Returns -1 for default."
  (let ((h (vtscreen-handle vt)))
    (if h (ffi-jvt-get-cell-fg h row col) -1)))

(def (vtscreen-cell-bg vt row col)
  "Get background color as packed 0x00RRGGBB. Returns -1 for default."
  (let ((h (vtscreen-handle vt)))
    (if h (ffi-jvt-get-cell-bg h row col) -1)))

(def (vtscreen-cell-attrs vt row col)
  "Get cell attributes as packed bits (bold=0, underline=1, italic=2, etc.)."
  (let ((h (vtscreen-handle vt)))
    (if h (ffi-jvt-get-cell-attrs h row col) 0)))
