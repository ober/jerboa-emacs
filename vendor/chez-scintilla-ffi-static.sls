;;; Low-level FFI bindings for Scintilla (scintilla-termbox backend)
;;; Chez Scheme port of gerbil-scintilla/ffi.ss
;;;
;;; Provides: instance lifecycle, message passing, notification queue,
;;; input, display, clipboard, lexilla, and termbox wrappers.

(library (chez-scintilla ffi)
  (export
    ;; Instance lifecycle
    ffi-scintilla-new
    ffi-scintilla-delete
    ;; Message passing
    ffi-scintilla-send-message
    ffi-scintilla-send-message-string
    ffi-scintilla-receive-string
    ffi-scintilla-set-property
    ;; Input
    ffi-scintilla-send-key
    ffi-scintilla-send-mouse
    ;; Display
    ffi-scintilla-refresh
    ffi-scintilla-resize
    ffi-scintilla-move
    ;; Clipboard
    ffi-scintilla-get-clipboard
    ;; Lexer
    ffi-scintilla-set-lexer-language
    ;; Notification queue
    ffi-scintilla-drain-one
    ffi-scn-code
    ffi-scn-position
    ffi-scn-ch
    ffi-scn-modifiers
    ffi-scn-modification-type
    ffi-scn-text
    ffi-scn-length
    ffi-scn-lines-added
    ffi-scn-message
    ffi-scn-line
    ffi-scn-fold-level-now
    ffi-scn-fold-level-prev
    ffi-scn-margin
    ffi-scn-list-type
    ffi-scn-x
    ffi-scn-y
    ffi-scn-token
    ffi-scn-updated
    ;; Termbox
    ffi-tb-init
    ffi-tb-shutdown
    ffi-tb-width
    ffi-tb-height
    ffi-tb-clear
    ffi-tb-present
    ffi-tb-set-cursor
    ffi-tb-poll-event
    ffi-tb-peek-event
    ffi-tb-event-type
    ffi-tb-event-mod
    ffi-tb-event-key
    ffi-tb-event-ch
    ffi-tb-event-w
    ffi-tb-event-h
    ffi-tb-event-x
    ffi-tb-event-y
    ;; Termbox extended
    ffi-tb-change-cell
    ffi-tb-set-clear-attributes
    ffi-tb-select-input-mode
    ffi-tb-select-output-mode
    ffi-tb-print-string)

  (import (chezscheme))

  ;; ====================================================================
  ;; Load shared libraries
  ;; ====================================================================

  (define shim-dir
    (or (getenv "CHEZ_SCINTILLA_LIB")
        "."))

  (define static-build?
    (let ([v (getenv "JEMACS_STATIC")])
      (and v (not (string=? v "")) (not (string=? v "0")))))

  (define _shim-loaded
    (if static-build?
        #f  ; symbols already linked in via Sforeign_symbol registration
        (load-shared-object
          (format "~a/chez_scintilla_shim.so" shim-dir))))

  ;; ====================================================================
  ;; Instance lifecycle
  ;; ====================================================================

  (define ffi-scintilla-new
    (foreign-procedure "chez_scintilla_new" () void*))

  (define ffi-scintilla-delete
    (foreign-procedure "chez_scintilla_delete" (void*) void))

  ;; ====================================================================
  ;; Message passing
  ;; ====================================================================

  (define ffi-scintilla-send-message
    (foreign-procedure "chez_scintilla_send_message"
      (void* unsigned-int unsigned-long long) long))

  (define ffi-scintilla-send-message-string
    (foreign-procedure "chez_scintilla_send_message_string"
      (void* unsigned-int unsigned-long string) long))

  (define ffi-scintilla-receive-string
    (foreign-procedure "chez_scintilla_receive_string"
      (void* unsigned-int unsigned-long) string))

  (define ffi-scintilla-set-property
    (foreign-procedure "chez_scintilla_set_property"
      (void* unsigned-int string string) long))

  ;; ====================================================================
  ;; Input
  ;; ====================================================================

  (define ffi-scintilla-send-key
    (foreign-procedure "chez_scintilla_send_key"
      (void* int int int int) void))

  (define ffi-scintilla-send-mouse
    (foreign-procedure "chez_scintilla_send_mouse"
      (void* int int int int int int int) int))

  ;; ====================================================================
  ;; Display
  ;; ====================================================================

  (define ffi-scintilla-refresh
    (foreign-procedure "chez_scintilla_refresh" (void*) void))

  (define ffi-scintilla-resize
    (foreign-procedure "chez_scintilla_resize" (void* int int) void))

  (define ffi-scintilla-move
    (foreign-procedure "chez_scintilla_move" (void* int int) void))

  ;; ====================================================================
  ;; Clipboard
  ;; ====================================================================

  (define ffi-scintilla-get-clipboard
    (foreign-procedure "chez_scintilla_get_clipboard" (void*) string))

  ;; ====================================================================
  ;; Lexer
  ;; ====================================================================

  (define ffi-scintilla-set-lexer-language
    (foreign-procedure "chez_scintilla_set_lexer_language" (void* string) void))

  ;; ====================================================================
  ;; Notification queue
  ;; ====================================================================

  (define ffi-scintilla-drain-one
    (foreign-procedure "chez_scintilla_drain_one" (void*) int))

  (define ffi-scn-code
    (foreign-procedure "chez_scn_code" () int))
  (define ffi-scn-position
    (foreign-procedure "chez_scn_position" () long))
  (define ffi-scn-ch
    (foreign-procedure "chez_scn_ch" () int))
  (define ffi-scn-modifiers
    (foreign-procedure "chez_scn_modifiers" () int))
  (define ffi-scn-modification-type
    (foreign-procedure "chez_scn_modification_type" () int))
  (define ffi-scn-text
    (foreign-procedure "chez_scn_text" () string))
  (define ffi-scn-length
    (foreign-procedure "chez_scn_length" () long))
  (define ffi-scn-lines-added
    (foreign-procedure "chez_scn_lines_added" () long))
  (define ffi-scn-message
    (foreign-procedure "chez_scn_message" () int))
  (define ffi-scn-line
    (foreign-procedure "chez_scn_line" () long))
  (define ffi-scn-fold-level-now
    (foreign-procedure "chez_scn_fold_level_now" () int))
  (define ffi-scn-fold-level-prev
    (foreign-procedure "chez_scn_fold_level_prev" () int))
  (define ffi-scn-margin
    (foreign-procedure "chez_scn_margin" () int))
  (define ffi-scn-list-type
    (foreign-procedure "chez_scn_list_type" () int))
  (define ffi-scn-x
    (foreign-procedure "chez_scn_x" () int))
  (define ffi-scn-y
    (foreign-procedure "chez_scn_y" () int))
  (define ffi-scn-token
    (foreign-procedure "chez_scn_token" () int))
  (define ffi-scn-updated
    (foreign-procedure "chez_scn_updated" () int))

  ;; ====================================================================
  ;; Termbox
  ;; ====================================================================

  (define ffi-tb-init
    (foreign-procedure "chez_tb_init" () int))
  (define ffi-tb-shutdown
    (foreign-procedure "chez_tb_shutdown" () void))
  (define ffi-tb-width
    (foreign-procedure "chez_tb_width" () int))
  (define ffi-tb-height
    (foreign-procedure "chez_tb_height" () int))
  (define ffi-tb-clear
    (foreign-procedure "chez_tb_clear" () void))
  (define ffi-tb-present
    (foreign-procedure "chez_tb_present" () void))
  (define ffi-tb-set-cursor
    (foreign-procedure "chez_tb_set_cursor" (int int) void))

  (define ffi-tb-poll-event
    (foreign-procedure "chez_tb_poll_event" () int))
  (define ffi-tb-peek-event
    (foreign-procedure "chez_tb_peek_event" (int) int))

  (define ffi-tb-event-type
    (foreign-procedure "chez_tb_event_type" () int))
  (define ffi-tb-event-mod
    (foreign-procedure "chez_tb_event_mod" () int))
  (define ffi-tb-event-key
    (foreign-procedure "chez_tb_event_key" () int))
  (define ffi-tb-event-ch
    (foreign-procedure "chez_tb_event_ch" () unsigned-int))
  (define ffi-tb-event-w
    (foreign-procedure "chez_tb_event_w" () int))
  (define ffi-tb-event-h
    (foreign-procedure "chez_tb_event_h" () int))
  (define ffi-tb-event-x
    (foreign-procedure "chez_tb_event_x" () int))
  (define ffi-tb-event-y
    (foreign-procedure "chez_tb_event_y" () int))

  ;; ====================================================================
  ;; Termbox extended
  ;; ====================================================================

  (define ffi-tb-change-cell
    (foreign-procedure "chez_tb_change_cell"
      (int int unsigned-32 unsigned-32 unsigned-32) void))

  (define ffi-tb-set-clear-attributes
    (foreign-procedure "chez_tb_set_clear_attributes"
      (unsigned-32 unsigned-32) void))

  (define ffi-tb-select-input-mode
    (foreign-procedure "chez_tb_select_input_mode" (int) int))

  (define ffi-tb-select-output-mode
    (foreign-procedure "chez_tb_select_output_mode" (int) int))

  (define ffi-tb-print-string
    (foreign-procedure "chez_tb_print_string"
      (int int unsigned-32 unsigned-32 string) void))

) ;; end library
