;;; ffi.ss — Low-level FFI bindings to libpcre2-8 for Chez Scheme
;;;
;;; Loads pcre2_shim.so (C wrapper) and defines foreign-procedure bindings.
;;; The high-level API lives in pcre2.ss.

(library (chez-pcre2 ffi)
  (export
    ;; Constants
    PCRE2_CASELESS PCRE2_MULTILINE PCRE2_DOTALL PCRE2_EXTENDED
    PCRE2_UTF PCRE2_UCP PCRE2_ANCHORED PCRE2_ENDANCHORED
    PCRE2_UNGREEDY PCRE2_NO_AUTO_CAPTURE PCRE2_DUPNAMES PCRE2_LITERAL

    PCRE2_NOTBOL PCRE2_NOTEOL PCRE2_NOTEMPTY PCRE2_NOTEMPTY_ATSTART
    PCRE2_PARTIAL_SOFT PCRE2_PARTIAL_HARD PCRE2_NO_JIT

    PCRE2_SUBSTITUTE_GLOBAL PCRE2_SUBSTITUTE_EXTENDED
    PCRE2_SUBSTITUTE_UNSET_EMPTY PCRE2_SUBSTITUTE_UNKNOWN_UNSET
    PCRE2_SUBSTITUTE_LITERAL

    PCRE2_JIT_COMPLETE PCRE2_JIT_PARTIAL_SOFT PCRE2_JIT_PARTIAL_HARD

    PCRE2_ERROR_NOMATCH PCRE2_ERROR_PARTIAL
    PCRE2_ERROR_NOMEMORY PCRE2_ERROR_NOSUBSTRING

    ;; Core functions
    ffi-pcre2-compile
    ffi-pcre2-compile-errorcode
    ffi-pcre2-compile-erroroffset
    ffi-pcre2-match
    ffi-pcre2-match-data-create-from-pattern
    ffi-pcre2-match-data-create
    ffi-pcre2-get-ovector-count
    ffi-pcre2-ovector-start
    ffi-pcre2-ovector-end
    ffi-pcre2-ovector-is-unset?
    ffi-pcre2-get-error-message
    ffi-pcre2-get-startchar
    ffi-pcre2-code-free
    ffi-pcre2-match-data-free

    ;; Substitute
    ffi-pcre2-do-substitute
    ffi-pcre2-substitute-result
    ffi-pcre2-substitute-result-length
    ffi-pcre2-substitute-free

    ;; Named groups & pattern info
    ffi-pcre2-substring-number-from-name
    ffi-pcre2-capture-count
    ffi-pcre2-name-count
    ffi-pcre2-name-entry-size
    ffi-pcre2-name-entry-name
    ffi-pcre2-name-entry-group

    ;; JIT
    ffi-pcre2-jit-compile
    ffi-pcre2-jit-match)

  (import (chezscheme))

  ;; Load the C shim shared library.
  ;; Set CHEZ_PCRE2_LIB to the directory containing pcre2_shim.so,
  ;; or place it in the current directory or a system library path.
  ;;
  ;; In static builds (JEMACS_STATIC=1), dlopen("file.so") is disabled in musl.
  ;; The pcre2 shim .o is compiled into the binary, and symbols are registered
  ;; via Sforeign_symbol() in jemacs-qt-main.c before Scheme boots.
  (define static-build?
    (let ([v (getenv "JEMACS_STATIC")])
      (and v (not (string=? v "")) (not (string=? v "0")))))

  (define shim-loaded
    (if static-build?
        #f  ; symbols already linked in; registered via Sforeign_symbol
        (load-shared-object
          (let ([env (getenv "CHEZ_PCRE2_LIB")])
            (if env
                (format "~a/pcre2_shim.so" env)
                "pcre2_shim.so")))))

  ;; -----------------------------------------------------------------------
  ;; Constants — fetched once from C at load time
  ;; -----------------------------------------------------------------------

  (define PCRE2_CASELESS        ((foreign-procedure "chez_pcre2_const_caseless" () unsigned-32)))
  (define PCRE2_MULTILINE       ((foreign-procedure "chez_pcre2_const_multiline" () unsigned-32)))
  (define PCRE2_DOTALL          ((foreign-procedure "chez_pcre2_const_dotall" () unsigned-32)))
  (define PCRE2_EXTENDED        ((foreign-procedure "chez_pcre2_const_extended" () unsigned-32)))
  (define PCRE2_UTF             ((foreign-procedure "chez_pcre2_const_utf" () unsigned-32)))
  (define PCRE2_UCP             ((foreign-procedure "chez_pcre2_const_ucp" () unsigned-32)))
  (define PCRE2_ANCHORED        ((foreign-procedure "chez_pcre2_const_anchored" () unsigned-32)))
  (define PCRE2_ENDANCHORED     ((foreign-procedure "chez_pcre2_const_endanchored" () unsigned-32)))
  (define PCRE2_UNGREEDY        ((foreign-procedure "chez_pcre2_const_ungreedy" () unsigned-32)))
  (define PCRE2_NO_AUTO_CAPTURE ((foreign-procedure "chez_pcre2_const_no_auto_capture" () unsigned-32)))
  (define PCRE2_DUPNAMES        ((foreign-procedure "chez_pcre2_const_dupnames" () unsigned-32)))
  (define PCRE2_LITERAL         ((foreign-procedure "chez_pcre2_const_literal" () unsigned-32)))

  (define PCRE2_NOTBOL          ((foreign-procedure "chez_pcre2_const_notbol" () unsigned-32)))
  (define PCRE2_NOTEOL          ((foreign-procedure "chez_pcre2_const_noteol" () unsigned-32)))
  (define PCRE2_NOTEMPTY        ((foreign-procedure "chez_pcre2_const_notempty" () unsigned-32)))
  (define PCRE2_NOTEMPTY_ATSTART ((foreign-procedure "chez_pcre2_const_notempty_atstart" () unsigned-32)))
  (define PCRE2_PARTIAL_SOFT    ((foreign-procedure "chez_pcre2_const_partial_soft" () unsigned-32)))
  (define PCRE2_PARTIAL_HARD    ((foreign-procedure "chez_pcre2_const_partial_hard" () unsigned-32)))
  (define PCRE2_NO_JIT          ((foreign-procedure "chez_pcre2_const_no_jit" () unsigned-32)))

  (define PCRE2_SUBSTITUTE_GLOBAL       ((foreign-procedure "chez_pcre2_const_substitute_global" () unsigned-32)))
  (define PCRE2_SUBSTITUTE_EXTENDED     ((foreign-procedure "chez_pcre2_const_substitute_extended" () unsigned-32)))
  (define PCRE2_SUBSTITUTE_UNSET_EMPTY  ((foreign-procedure "chez_pcre2_const_substitute_unset_empty" () unsigned-32)))
  (define PCRE2_SUBSTITUTE_UNKNOWN_UNSET ((foreign-procedure "chez_pcre2_const_substitute_unknown_unset" () unsigned-32)))
  (define PCRE2_SUBSTITUTE_LITERAL      ((foreign-procedure "chez_pcre2_const_substitute_literal" () unsigned-32)))

  (define PCRE2_JIT_COMPLETE      ((foreign-procedure "chez_pcre2_const_jit_complete" () unsigned-32)))
  (define PCRE2_JIT_PARTIAL_SOFT  ((foreign-procedure "chez_pcre2_const_jit_partial_soft" () unsigned-32)))
  (define PCRE2_JIT_PARTIAL_HARD  ((foreign-procedure "chez_pcre2_const_jit_partial_hard" () unsigned-32)))

  (define PCRE2_ERROR_NOMATCH     ((foreign-procedure "chez_pcre2_const_error_nomatch" () integer-32)))
  (define PCRE2_ERROR_PARTIAL     ((foreign-procedure "chez_pcre2_const_error_partial" () integer-32)))
  (define PCRE2_ERROR_NOMEMORY    ((foreign-procedure "chez_pcre2_const_error_nomemory" () integer-32)))
  (define PCRE2_ERROR_NOSUBSTRING ((foreign-procedure "chez_pcre2_const_error_nosubstring" () integer-32)))

  ;; -----------------------------------------------------------------------
  ;; Core FFI functions
  ;; -----------------------------------------------------------------------

  ;; Compile: returns pointer or 0 on error
  (define ffi-pcre2-compile
    (foreign-procedure "chez_pcre2_compile"
      (u8* size_t unsigned-32) void*))

  (define ffi-pcre2-compile-errorcode
    (foreign-procedure "chez_pcre2_compile_errorcode" () integer-32))

  (define ffi-pcre2-compile-erroroffset
    (foreign-procedure "chez_pcre2_compile_erroroffset" () size_t))

  ;; Match: returns count (>0) on success, negative on failure
  (define ffi-pcre2-match
    (foreign-procedure "chez_pcre2_match"
      (void* u8* size_t size_t unsigned-32 void*) integer-32))

  (define ffi-pcre2-match-data-create-from-pattern
    (foreign-procedure "chez_pcre2_match_data_create_from_pattern"
      (void*) void*))

  (define ffi-pcre2-match-data-create
    (foreign-procedure "chez_pcre2_match_data_create"
      (unsigned-32) void*))

  (define ffi-pcre2-get-ovector-count
    (foreign-procedure "chez_pcre2_get_ovector_count"
      (void*) unsigned-32))

  (define ffi-pcre2-ovector-start
    (foreign-procedure "chez_pcre2_ovector_start"
      (void* unsigned-32) size_t))

  (define ffi-pcre2-ovector-end
    (foreign-procedure "chez_pcre2_ovector_end"
      (void* unsigned-32) size_t))

  (define ffi-pcre2-ovector-is-unset?
    (let ([f (foreign-procedure "chez_pcre2_ovector_is_unset"
               (void* unsigned-32) integer-32)])
      (lambda (md idx) (not (zero? (f md idx))))))

  (define ffi-pcre2-get-error-message
    (foreign-procedure "chez_pcre2_get_error_message"
      (integer-32) string))

  (define ffi-pcre2-get-startchar
    (foreign-procedure "chez_pcre2_get_startchar"
      (void*) size_t))

  (define ffi-pcre2-code-free
    (foreign-procedure "chez_pcre2_code_free" (void*) void))

  (define ffi-pcre2-match-data-free
    (foreign-procedure "chez_pcre2_match_data_free" (void*) void))

  ;; -----------------------------------------------------------------------
  ;; Substitute
  ;; -----------------------------------------------------------------------

  (define ffi-pcre2-do-substitute
    (foreign-procedure "chez_pcre2_do_substitute"
      (void* u8* size_t size_t unsigned-32 void* u8* size_t) integer-32))

  (define ffi-pcre2-substitute-result
    (foreign-procedure "chez_pcre2_substitute_result" () string))

  (define ffi-pcre2-substitute-result-length
    (foreign-procedure "chez_pcre2_substitute_result_length" () size_t))

  (define ffi-pcre2-substitute-free
    (foreign-procedure "chez_pcre2_substitute_free" () void))

  ;; -----------------------------------------------------------------------
  ;; Named groups & pattern info
  ;; -----------------------------------------------------------------------

  (define ffi-pcre2-substring-number-from-name
    (foreign-procedure "chez_pcre2_substring_number_from_name"
      (void* string) integer-32))

  (define ffi-pcre2-capture-count
    (foreign-procedure "chez_pcre2_capture_count"
      (void*) unsigned-32))

  (define ffi-pcre2-name-count
    (foreign-procedure "chez_pcre2_name_count"
      (void*) unsigned-32))

  (define ffi-pcre2-name-entry-size
    (foreign-procedure "chez_pcre2_name_entry_size"
      (void*) unsigned-32))

  (define ffi-pcre2-name-entry-name
    (foreign-procedure "chez_pcre2_name_entry_name"
      (void* unsigned-32) string))

  (define ffi-pcre2-name-entry-group
    (foreign-procedure "chez_pcre2_name_entry_group"
      (void* unsigned-32) unsigned-32))

  ;; -----------------------------------------------------------------------
  ;; JIT
  ;; -----------------------------------------------------------------------

  (define ffi-pcre2-jit-compile
    (foreign-procedure "chez_pcre2_jit_compile"
      (void* unsigned-32) integer-32))

  (define ffi-pcre2-jit-match
    (foreign-procedure "chez_pcre2_jit_match"
      (void* u8* size_t size_t unsigned-32 void*) integer-32))
)
