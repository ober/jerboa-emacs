;;; -*- Gerbil -*-
;;; treesitter.ss — Tree-sitter incremental parsing and syntax highlighting.
;;;
;;; Provides FFI bindings to the tree-sitter C library via treesitter_shim.c.
;;; Manages per-buffer parser/tree state and highlight query execution.

(export ts-parser-create
        ts-parser-delete!
        ts-parse-string!
        ts-parse-incremental!
        ts-tree-delete!
        ts-highlight-buffer!
        ts-highlight-range!
        ts-tree-changed-ranges
        ts-get-highlight-query
        ts-get-highlight-query-len
        ts-query-create
        ts-query-delete!
        ;; Per-buffer state
        ts-buffer-init!
        ts-buffer-cleanup!
        ts-buffer-reparse!
        ts-buffer-state
        (struct-out ts-state)
        *buffer-ts-state*
        ;; Language mapping
        language->ts-name
        ;; Capture -> style
        ts-capture->style-id
        ;; Style IDs
        *ts-style-keyword* *ts-style-string* *ts-style-comment*
        *ts-style-function* *ts-style-type* *ts-style-variable*
        *ts-style-constant* *ts-style-number* *ts-style-operator*
        *ts-style-property* *ts-style-punctuation* *ts-style-attribute*
        *ts-style-namespace* *ts-style-constructor* *ts-style-tag*
        *ts-style-escape* *ts-style-label* *ts-style-builtin*
        *ts-style-preproc*)

(import :std/sugar
        :std/srfi/13
        :jerboa-emacs/core
        :jerboa-emacs/qt/sci-shim)

;; Scintilla styling constants (avoid chez-scintilla/constants dep for boot order)
(define SCI_STARTSTYLING 2032)
(define SCI_SETSTYLING   2033)
(define SCI_STYLESETFORE 2051)
(define SCI_STYLESETBACK 2052)
(define SCI_STYLESETBOLD 2053)
(define SCI_STYLESETITALIC 2054)

;;;============================================================================
;;; Load the C shim shared library
;;;============================================================================

(define static-build?
  (let ((v (getenv "JEMACS_STATIC")))
    (and v (not (string=? v "")) (not (string=? v "0")))))

(define ts-shim-loaded
  (if static-build?
    #f  ;; symbols already linked in via Sforeign_symbol registration
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (load-shared-object
          (let ((dir (or (getenv "JERBOA_EMACS_SUPPORT")
                         (string-append (or (getenv "HOME") ".") "/mine/jerboa-emacs/support"))))
            (string-append dir "/treesitter_shim.so")))))))

;;;============================================================================
;;; FFI bindings
;;;============================================================================

;; Parser lifecycle
(define ffi-ts-parser-new
  (foreign-procedure "ts_shim_parser_new" () void*))
(define ffi-ts-parser-delete
  (foreign-procedure "ts_shim_parser_delete" (void*) void))
(define ffi-ts-parser-set-language
  (foreign-procedure "ts_shim_parser_set_language" (void* string) int))

;; Parsing
(define ffi-ts-parse-string
  (foreign-procedure "ts_shim_parse_string" (void* void* string int) void*))
(define ffi-ts-parse-incremental
  (foreign-procedure "ts_shim_parse_incremental"
    (void* void* string int int int int int int int int int int) void*))
(define ffi-ts-tree-delete
  (foreign-procedure "ts_shim_tree_delete" (void*) void))

;; Node slots
(define ffi-ts-tree-root-node
  (foreign-procedure "ts_shim_tree_root_node" (void* int) void))
(define ffi-ts-node-start-byte
  (foreign-procedure "ts_shim_node_start_byte" (int) int))
(define ffi-ts-node-end-byte
  (foreign-procedure "ts_shim_node_end_byte" (int) int))
(define ffi-ts-node-type
  (foreign-procedure "ts_shim_node_type" (int) string))
(define ffi-ts-node-is-null
  (foreign-procedure "ts_shim_node_is_null" (int) int))

;; Query
(define ffi-ts-query-new
  (foreign-procedure "ts_shim_query_new" (string string int u8* u8*) void*))
(define ffi-ts-query-delete
  (foreign-procedure "ts_shim_query_delete" (void*) void))

;; Query cursor
(define ffi-ts-query-cursor-new
  (foreign-procedure "ts_shim_query_cursor_new" () void*))
(define ffi-ts-query-cursor-delete
  (foreign-procedure "ts_shim_query_cursor_delete" (void*) void))
(define ffi-ts-query-cursor-exec
  (foreign-procedure "ts_shim_query_cursor_exec" (void* void* int) void))
(define ffi-ts-query-cursor-set-byte-range
  (foreign-procedure "ts_shim_query_cursor_set_byte_range" (void* int int) void))

;; Batch highlight captures
(define ffi-ts-highlight-captures
  (foreign-procedure "ts_shim_highlight_captures" (void* void* u8* int) int))

;; Capture name lookup
(define ffi-ts-query-capture-name
  (foreign-procedure "ts_shim_query_capture_name" (void* int) string))

;; Changed ranges
(define ffi-ts-tree-changed-ranges
  (foreign-procedure "ts_shim_tree_changed_ranges" (void* void* u8* int) int))

;; Embedded queries
(define ffi-ts-get-highlight-query
  (foreign-procedure "ts_shim_get_highlight_query" (string) string))
(define ffi-ts-get-highlight-query-len
  (foreign-procedure "ts_shim_get_highlight_query_len" (string) int))

;;;============================================================================
;;; High-level Scheme API
;;;============================================================================

(def (ts-parser-create lang-name)
  "Create a parser configured for the given language.
   Returns parser pointer or #f."
  (let ((p (ffi-ts-parser-new)))
    (if (= 1 (ffi-ts-parser-set-language p lang-name))
      p
      (begin (ffi-ts-parser-delete p) #f))))

(def (ts-parser-delete! parser)
  (when parser (ffi-ts-parser-delete parser)))

(def (ts-parse-string! parser old-tree text)
  "Parse text string. Returns new tree pointer."
  (ffi-ts-parse-string parser (or old-tree 0) text (string-length text)))

(def (ts-parse-incremental! parser old-tree text
                            start-byte old-end-byte new-end-byte
                            start-row start-col
                            old-end-row old-end-col
                            new-end-row new-end-col)
  "Apply an edit and re-parse incrementally. Returns new tree pointer."
  (ffi-ts-parse-incremental parser (or old-tree 0) text (string-length text)
    start-byte old-end-byte new-end-byte
    start-row start-col
    old-end-row old-end-col
    new-end-row new-end-col))

(def (ts-tree-delete! tree)
  (when tree (ffi-ts-tree-delete tree)))

(def (ts-query-create lang-name query-source)
  "Compile a highlight query. Returns query pointer or #f."
  (with-catch
    (lambda (e) #f)
    (lambda ()
      (let* ((err-off-buf (make-bytevector 4 0))
             (err-type-buf (make-bytevector 4 0))
             (q (ffi-ts-query-new lang-name query-source
                  (string-length query-source)
                  err-off-buf err-type-buf)))
        (if q q #f)))))

(def (ts-query-delete! query)
  (when query (ffi-ts-query-delete query)))

(def (ts-get-highlight-query lang-name)
  "Get the embedded highlight query source string for a language.
   Returns string or #f."
  (let ((q (ffi-ts-get-highlight-query lang-name)))
    (if (and q (> (string-length q) 0))
      q
      #f)))

(def (ts-get-highlight-query-len lang-name)
  (ffi-ts-get-highlight-query-len lang-name))

;;;============================================================================
;;; Batch highlight — the performance-critical path
;;;============================================================================

;; Pre-allocated buffer for highlight capture results.
;; Each capture = 3 ints (12 bytes): start_byte, end_byte, capture_index.
;; 16384 captures * 12 bytes = 196608 bytes.
(define *capture-buf-size* 16384)
(define *capture-buf* (make-bytevector (* *capture-buf-size* 12) 0))

(def (ts-highlight-buffer! parser tree query text ed)
  "Run highlight query over the full tree and apply Scintilla styles.
   This is the main entry point for full-buffer highlighting."
  (when (and parser tree query ed)
    ;; Put root node in slot 0
    (ffi-ts-tree-root-node tree 0)
    ;; Create cursor, execute query
    (let ((cursor (ffi-ts-query-cursor-new)))
      (ffi-ts-query-cursor-exec cursor query 0)
      ;; Collect all captures in batch
      (let ((count (ffi-ts-highlight-captures cursor query
                     *capture-buf* *capture-buf-size*)))
        (verbose-log! "ts-highlight: captures=" (number->string count))
        ;; Apply styles
        (ts-apply-captures! ed query count))
      (ffi-ts-query-cursor-delete cursor))))

(def (ts-highlight-range! parser tree query text ed start-byte end-byte)
  "Run highlight query over a byte range and apply styles.
   Used for incremental re-highlighting after edits."
  (when (and parser tree query ed)
    (ffi-ts-tree-root-node tree 0)
    (let ((cursor (ffi-ts-query-cursor-new)))
      (ffi-ts-query-cursor-exec cursor query 0)
      (ffi-ts-query-cursor-set-byte-range cursor start-byte end-byte)
      (let ((count (ffi-ts-highlight-captures cursor query
                     *capture-buf* *capture-buf-size*)))
        ;; Clear styles in range first
        (sci-send ed SCI_STARTSTYLING start-byte 31)
        (sci-send ed SCI_SETSTYLING (- end-byte start-byte) 0)
        ;; Apply captures
        (ts-apply-captures! ed query count))
      (ffi-ts-query-cursor-delete cursor))))

(def (ts-apply-captures! ed query count)
  "Apply captured highlights to the Scintilla editor.
   Reads from *capture-buf* (filled by ts-highlight-captures)."
  (let ((buf *capture-buf*))
    (let loop ((i 0) (last-end 0) (applied 0))
      (if (< i count)
        (let* ((off (* i 12))
               (start (bytevector-s32-native-ref buf off))
               (end   (bytevector-s32-native-ref buf (+ off 4)))
               (cap-idx (bytevector-s32-native-ref buf (+ off 8)))
               (cap-name (ffi-ts-query-capture-name query cap-idx))
               (style-id (ts-capture->style-id cap-name))
               (len (- end start)))
          (when (< i 5)
            (verbose-log! "ts-capture[" (number->string i) "]: name=" cap-name
                          " style=" (number->string style-id)
                          " start=" (number->string start)
                          " end=" (number->string end)
                          " len=" (number->string len)
                          " last-end=" (number->string last-end)))
          (if (and (> style-id 0) (> len 0) (>= start last-end))
            (begin
              (sci-send ed SCI_STARTSTYLING start 31)
              (sci-send ed SCI_SETSTYLING len style-id)
              (loop (+ i 1) (max last-end end) (+ applied 1)))
            (loop (+ i 1) (max last-end end) applied)))
        (verbose-log! "ts-apply: total=" (number->string count)
                      " applied=" (number->string applied))))))

(def (ts-tree-changed-ranges old-tree new-tree)
  "Get byte ranges that changed between two trees.
   Returns list of (start-byte . end-byte) pairs."
  (if (or (not old-tree) (not new-tree))
    '()
    (let* ((buf (make-bytevector (* 256 8) 0))  ;; 256 ranges * 2 ints
           (count (ffi-ts-tree-changed-ranges old-tree new-tree buf 256)))
      (let loop ((i 0) (result '()))
        (if (>= i count)
          (reverse result)
          (let ((start (bytevector-s32-native-ref buf (* i 8)))
                (end   (bytevector-s32-native-ref buf (+ (* i 8) 4))))
            (loop (+ i 1) (cons (cons start end) result))))))))

;;;============================================================================
;;; Per-buffer tree-sitter state
;;;============================================================================

(def *buffer-ts-state* (make-hash-table))

(defstruct ts-state
  (parser     ;; void* — TSParser
   tree       ;; void* — TSTree (current parse tree) or #f
   query      ;; void* — compiled TSQuery for highlighting
   language   ;; string — tree-sitter language name
   version    ;; integer — incremented on each edit for debouncing
   )
  transparent: #t)

(def (ts-buffer-init! buf ts-name)
  "Initialize tree-sitter state for a buffer.
   Creates parser, compiles highlight query, stores in side table."
  (let ((parser (ts-parser-create ts-name)))
    (when parser
      (let* ((query-src (ts-get-highlight-query ts-name))
             (query (and query-src (ts-query-create ts-name query-src))))
        (if query
          (let ((state (make-ts-state parser #f query ts-name 0)))
            (hash-put! *buffer-ts-state* buf state)
            state)
          (begin
            (ts-parser-delete! parser)
            #f))))))

(def (ts-buffer-cleanup! buf)
  "Clean up tree-sitter state for a buffer."
  (let ((state (hash-get *buffer-ts-state* buf)))
    (when state
      (ts-tree-delete! (ts-state-tree state))
      (ts-query-delete! (ts-state-query state))
      (ts-parser-delete! (ts-state-parser state))
      (hash-remove! *buffer-ts-state* buf))))

(def (ts-buffer-reparse! buf text ed)
  "Full re-parse of buffer text and re-highlight.
   Called on initial load and after debounced edits."
  (let ((state (hash-get *buffer-ts-state* buf)))
    (verbose-log! "ts-reparse: state=" (if state "yes" "nil")
                  " text-len=" (if text (number->string (string-length text)) "nil"))
    (when state
      (let* ((parser (ts-state-parser state))
             (old-tree (ts-state-tree state))
             (new-tree (ts-parse-string! parser old-tree text)))
        (verbose-log! "ts-reparse: parser=" (if parser "yes" "nil")
                      " old-tree=" (if old-tree "yes" "nil")
                      " new-tree=" (if new-tree "yes" "nil"))
        (when new-tree
          ;; Clear all styles first (set to default)
          (sci-send ed SCI_STARTSTYLING 0 31)
          (sci-send ed SCI_SETSTYLING (string-length text) 0)
          ;; Apply highlights
          (ts-highlight-buffer! parser new-tree (ts-state-query state) text ed)
          ;; Update state
          (when old-tree (ts-tree-delete! old-tree))
          (set! (ts-state-tree state) new-tree))))))

(def (ts-buffer-state buf)
  "Get tree-sitter state for a buffer, or #f."
  (hash-get *buffer-ts-state* buf))

;;;============================================================================
;;; Language name mapping
;;;============================================================================

(def (language->ts-name lang)
  "Map jerboa-emacs language symbol to tree-sitter language name string.
   Returns #f if no tree-sitter grammar is available."
  (case lang
    ((c)                "c")
    ((c++)              "cpp")
    ((python)           "python")
    ((javascript)       "javascript")
    ((typescript)       "javascript")  ;; use JS grammar for now
    ((rust)             "rust")
    ((go)               "go")
    ((shell)            "bash")
    ((scheme lisp)      "scheme")
    ((json)             "json")
    ((ruby)             "ruby")
    ((java)             "java")
    ((css)              "css")
    ((xml)              "html")
    ((lua)              "lua")
    (else #f)))

;;;============================================================================
;;; Capture name -> Scintilla style ID mapping
;;;============================================================================

;; Style IDs 1-19: tree-sitter highlights.
;; QScintilla uses 5 style bits (0-31 valid range), so we MUST use low IDs.
;; Since tree-sitter disables the built-in lexer, styles 1-19 are free.
;; Style 0 = default text, styles 20-31 reserved for other uses.
(def *ts-style-keyword*     1)
(def *ts-style-string*      2)
(def *ts-style-comment*     3)
(def *ts-style-function*    4)
(def *ts-style-type*        5)
(def *ts-style-variable*    6)
(def *ts-style-constant*    7)
(def *ts-style-number*      8)
(def *ts-style-operator*    9)
(def *ts-style-property*    10)
(def *ts-style-punctuation* 11)
(def *ts-style-attribute*   12)
(def *ts-style-namespace*   13)
(def *ts-style-constructor* 14)
(def *ts-style-tag*         15)
(def *ts-style-escape*      16)
(def *ts-style-label*       17)
(def *ts-style-builtin*     18)
(def *ts-style-preproc*     19)

(def (ts-capture->style-id capture-name)
  "Map a tree-sitter capture name to a Scintilla style ID."
  (cond
    ;; Keywords
    ((or (string=? capture-name "keyword")
         (string-prefix? "keyword." capture-name))
     *ts-style-keyword*)
    ;; Strings
    ((or (string=? capture-name "string")
         (string-prefix? "string." capture-name))
     *ts-style-string*)
    ;; Comments
    ((or (string=? capture-name "comment")
         (string-prefix? "comment." capture-name))
     *ts-style-comment*)
    ;; Functions
    ((or (string=? capture-name "function")
         (string-prefix? "function." capture-name))
     *ts-style-function*)
    ;; Types
    ((or (string=? capture-name "type")
         (string-prefix? "type." capture-name))
     *ts-style-type*)
    ;; Variables
    ((or (string=? capture-name "variable")
         (string-prefix? "variable." capture-name))
     *ts-style-variable*)
    ;; Constants
    ((or (string=? capture-name "constant")
         (string-prefix? "constant." capture-name)
         (string=? capture-name "boolean"))
     *ts-style-constant*)
    ;; Numbers
    ((or (string=? capture-name "number")
         (string=? capture-name "float"))
     *ts-style-number*)
    ;; Operators
    ((string=? capture-name "operator")
     *ts-style-operator*)
    ;; Properties
    ((or (string=? capture-name "property")
         (string-prefix? "property." capture-name)
         (string=? capture-name "field"))
     *ts-style-property*)
    ;; Punctuation
    ((or (string-prefix? "punctuation." capture-name)
         (string=? capture-name "punctuation"))
     *ts-style-punctuation*)
    ;; Attributes
    ((or (string=? capture-name "attribute")
         (string-prefix? "attribute." capture-name))
     *ts-style-attribute*)
    ;; Namespace/module
    ((or (string=? capture-name "namespace")
         (string=? capture-name "module"))
     *ts-style-namespace*)
    ;; Constructors
    ((string=? capture-name "constructor")
     *ts-style-constructor*)
    ;; Tags (HTML/XML)
    ((or (string=? capture-name "tag")
         (string-prefix? "tag." capture-name))
     *ts-style-tag*)
    ;; Escape sequences
    ((or (string=? capture-name "escape")
         (string=? capture-name "string.escape"))
     *ts-style-escape*)
    ;; Labels
    ((string=? capture-name "label")
     *ts-style-label*)
    ;; Built-in functions/types
    ((or (string-suffix? ".builtin" capture-name))
     *ts-style-builtin*)
    ;; Preprocessor
    ((or (string=? capture-name "preproc")
         (string-prefix? "preproc." capture-name)
         (string=? capture-name "include"))
     *ts-style-preproc*)
    ;; Default — no style
    (else 0)))

;;; ts-setup-styles! is defined in qt/highlight.ss (has access to face-fg-rgb etc.)
