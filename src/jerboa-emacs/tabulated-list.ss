;;; -*- Gerbil -*-
;;; tabulated-list.ss — Reusable tabulated list mode infrastructure
;;;
;;; Provides Emacs-like tabulated-list-mode for displaying columnar data
;;; in read-only buffers with sorting, filtering, and entry selection.
;;;
;;; Usage:
;;;   1. Define columns: (list (make-tl-column "Name" 25) (make-tl-column "State" 10) ...)
;;;   2. Define entries: each entry is (cons id (vector col1-str col2-str ...))
;;;   3. Create buffer, call tabulated-list-init! to set up state
;;;   4. Call tabulated-list-refresh! to render/re-render
;;;   5. Use tabulated-list-get-id-at-line to get entry id at cursor

(export
  (struct-out tl-column)
  (struct-out tl-state)
  *tabulated-list-state*
  tabulated-list-init!
  tabulated-list-get-state
  tabulated-list-set-entries!
  tabulated-list-refresh!
  tabulated-list-get-id-at-line
  tabulated-list-get-entry-at-line
  tabulated-list-header-lines
  tabulated-list-format-header
  tabulated-list-format-entry
  tabulated-list-filter!
  tabulated-list-clear-filter!
  tabulated-list-sort!
  tabulated-list-entry-count)

(import
  (std sugar)
  (except (std srfi srfi-13) string-pad-right))

;;; Column definition
(defstruct tl-column
  (name     ;; string: column header
   width))  ;; integer: column width in characters

;;; Per-buffer tabulated list state
(defstruct tl-state
  (columns    ;; list of tl-column
   entries    ;; list of (cons id (vector col-str ...))
   filtered   ;; list of entries after filter applied (or same as entries)
   sort-col   ;; integer or #f: column index to sort by
   sort-asc?  ;; boolean: ascending sort
   filter-str ;; string or #f: current filter
   padding))  ;; integer: padding between columns

;; Maps buffer -> tl-state
(def *tabulated-list-state* (make-hash-table))

(def tabulated-list-header-lines 2)  ;; header + separator

(def (tabulated-list-init! buf columns (padding 2))
  "Initialize tabulated list state for BUF with COLUMNS."
  (let ((state (make-tl-state
                 columns  ;; columns
                 '()      ;; entries
                 '()      ;; filtered
                 #f       ;; sort-col
                 #t       ;; sort-asc?
                 #f       ;; filter-str
                 padding)))
    (hash-put! *tabulated-list-state* buf state)
    state))

(def (tabulated-list-get-state buf)
  "Get the tl-state for BUF, or #f."
  (hash-get *tabulated-list-state* buf))

(def (tabulated-list-set-entries! buf entries)
  "Set the entries for BUF's tabulated list."
  (let ((state (hash-get *tabulated-list-state* buf)))
    (when state
      (set! (tl-state-entries state) entries)
      ;; Re-apply filter if active
      (if (tl-state-filter-str state)
        (tabulated-list--apply-filter! state)
        (set! (tl-state-filtered state) entries))
      ;; Re-apply sort if active
      (when (tl-state-sort-col state)
        (tabulated-list--apply-sort! state)))))

(def (tabulated-list-entry-count buf)
  "Return number of visible (filtered) entries."
  (let ((state (hash-get *tabulated-list-state* buf)))
    (if state (length (tl-state-filtered state)) 0)))

;;; Formatting

(def (string-pad-right s width)
  "Pad string S to WIDTH with spaces on the right. Truncate if longer."
  (let ((len (string-length s)))
    (cond
      ((>= len width) (substring s 0 width))
      (else (string-append s (make-string (- width len) #\space))))))

(def (tabulated-list-format-header state)
  "Format the header line + separator for the tabulated list."
  (let* ((cols (tl-state-columns state))
         (pad (tl-state-padding state))
         (pad-str (make-string pad #\space))
         (header (string-join
                   (map (lambda (col)
                          (string-pad-right (tl-column-name col) (tl-column-width col)))
                        cols)
                   pad-str))
         (sep (string-join
                (map (lambda (col)
                       (make-string (tl-column-width col) #\-))
                     cols)
                pad-str)))
    (string-append "  " header "\n  " sep)))

(def (tabulated-list-format-entry state entry)
  "Format one entry as a padded row string.
   ENTRY is (cons id (vector col-str ...))."
  (let* ((cols (tl-state-columns state))
         (vals (cdr entry))
         (pad (tl-state-padding state))
         (pad-str (make-string pad #\space)))
    (string-append "  "
      (string-join
        (let loop ((i 0) (cs cols) (acc '()))
          (if (null? cs) (reverse acc)
            (loop (+ i 1) (cdr cs)
                  (cons (string-pad-right
                          (if (< i (vector-length vals))
                            (vector-ref vals i)
                            "")
                          (tl-column-width (car cs)))
                        acc))))
        pad-str))))

(def (tabulated-list-format-all state)
  "Format the full tabulated list: header + all filtered entries."
  (let* ((header (tabulated-list-format-header state))
         (entries (tl-state-filtered state))
         (lines (map (lambda (e) (tabulated-list-format-entry state e))
                     entries)))
    (if (null? lines)
      (string-append header "\n  (no entries)")
      (string-append header "\n" (string-join lines "\n")))))

;;; Refresh — caller provides the Qt editor update logic
;;; This just returns the formatted text; the mode command does the buffer update.

(def (tabulated-list-refresh! buf)
  "Return the formatted text for BUF's tabulated list, or #f if no state."
  (let ((state (hash-get *tabulated-list-state* buf)))
    (and state (tabulated-list-format-all state))))

;;; Entry lookup by line number

(def (tabulated-list-get-id-at-line buf line)
  "Get the entry ID at LINE (0-based). Returns #f if not on a data line."
  (let ((state (hash-get *tabulated-list-state* buf)))
    (when state
      (let* ((idx (- line tabulated-list-header-lines))
             (entries (tl-state-filtered state)))
        (and (>= idx 0) (< idx (length entries))
             (car (list-ref entries idx)))))))

(def (tabulated-list-get-entry-at-line buf line)
  "Get the full entry (cons id vals) at LINE (0-based). Returns #f if not on a data line."
  (let ((state (hash-get *tabulated-list-state* buf)))
    (when state
      (let* ((idx (- line tabulated-list-header-lines))
             (entries (tl-state-filtered state)))
        (and (>= idx 0) (< idx (length entries))
             (list-ref entries idx))))))

;;; Filtering

(def (tabulated-list-filter! buf filter-str)
  "Apply a case-insensitive filter to the entries."
  (let ((state (hash-get *tabulated-list-state* buf)))
    (when state
      (set! (tl-state-filter-str state) (and (not (string-empty? filter-str)) filter-str))
      (if (tl-state-filter-str state)
        (tabulated-list--apply-filter! state)
        (set! (tl-state-filtered state) (tl-state-entries state)))
      (when (tl-state-sort-col state)
        (tabulated-list--apply-sort! state)))))

(def (tabulated-list-clear-filter! buf)
  "Clear the filter."
  (tabulated-list-filter! buf ""))

(def (tabulated-list--apply-filter! state)
  "Internal: filter entries by the current filter string."
  (let* ((pat (string-downcase (tl-state-filter-str state)))
         (entries (tl-state-entries state)))
    (set! (tl-state-filtered state)
      (filter
        (lambda (entry)
          (let ((vals (cdr entry)))
            (let loop ((i 0))
              (if (>= i (vector-length vals)) #f
                (if (string-contains (string-downcase (vector-ref vals i)) pat)
                  #t
                  (loop (+ i 1)))))))
        entries))))

;;; Sorting

(def (tabulated-list-sort! buf col-idx)
  "Sort entries by column COL-IDX. Toggle ascending/descending on repeated sort."
  (let ((state (hash-get *tabulated-list-state* buf)))
    (when state
      (if (eqv? (tl-state-sort-col state) col-idx)
        ;; Toggle direction
        (set! (tl-state-sort-asc? state) (not (tl-state-sort-asc? state)))
        ;; New column, ascending
        (begin
          (set! (tl-state-sort-col state) col-idx)
          (set! (tl-state-sort-asc? state) #t)))
      (tabulated-list--apply-sort! state))))

(def (tabulated-list--apply-sort! state)
  "Internal: sort filtered entries by current sort column."
  (let* ((col-idx (tl-state-sort-col state))
         (asc? (tl-state-sort-asc? state))
         (cmp (lambda (a b)
                (let ((va (vector-ref (cdr a) col-idx))
                      (vb (vector-ref (cdr b) col-idx)))
                  (if asc? (string<? va vb) (string>? va vb))))))
    (set! (tl-state-filtered state)
      (sort cmp (tl-state-filtered state)))))
