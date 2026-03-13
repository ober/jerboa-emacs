#!chezscheme
;;; face.sls — Face System: Visual Attributes for Text and UI Elements
;;;
;;; Ported from gerbil-emacs/face.ss
;;; Maps semantic names to visual properties (fg, bg, bold, italic, underline).
;;; Themes define collections of faces, enabling theme-aware syntax highlighting.

(library (jerboa-emacs face)
  (export face? face-fg face-bg face-bold face-italic face-underline
          make-face new-face
          *faces*
          define-face!
          face-get face-ref
          set-face-attribute!
          face-clear!
          load-theme!
          current-theme-name
          default-font-family default-font-size
          set-default-font! get-default-font
          set-frame-font
          parse-hex-color rgb->hex
          define-standard-faces!
          ;; Convenience accessors
          face-fg-rgb face-bg-rgb face-has-bold? face-has-italic? face-has-underline?)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (jerboa-emacs themes)
          (jerboa-emacs customize))

  ;;;============================================================================
  ;;; Face Data Structure
  ;;;============================================================================

  ;; A face defines visual attributes for text or UI elements.
  ;; All fields are optional — #f means "inherit from parent" or "no override".
  (defstruct face (fg bg bold italic underline))

  ;; Keyword-style constructor using property list
  ;; (new-face fg: "#d8d8d8" bg: "#181818" bold: #t)
  (def (new-face . props)
    (let ((fg #f) (bg #f) (bold #f) (italic #f) (underline #f))
      (let loop ((p props))
        (cond
          ((null? p) (make-face fg bg bold italic underline))
          ((null? (cdr p)) (make-face fg bg bold italic underline))
          (else
           (let ((key (car p)) (val (cadr p)))
             (cond
               ((eq? key 'fg) (set! fg val))
               ((eq? key 'bg) (set! bg val))
               ((eq? key 'bold) (set! bold val))
               ((eq? key 'italic) (set! italic val))
               ((eq? key 'underline) (set! underline val))
               ;; Also accept keyword symbols like fg:
               ((eq? key (string->symbol "fg:")) (set! fg val))
               ((eq? key (string->symbol "bg:")) (set! bg val))
               ((eq? key (string->symbol "bold:")) (set! bold val))
               ((eq? key (string->symbol "italic:")) (set! italic val))
               ((eq? key (string->symbol "underline:")) (set! underline val)))
             (loop (cddr p))))))))

  ;;;============================================================================
  ;;; Face Registry
  ;;;============================================================================

  (def *faces* (make-hash-table-eq))

  (def (define-face! name . props)
    (let ((f (apply new-face props)))
      (hash-put! *faces* name f)))

  (def (face-get name)
    (hash-get *faces* name))

  (def (face-ref name)
    (or (hash-get *faces* name)
        (error "Unknown face" name)))

  (def (set-face-attribute! name . props)
    (let* ((existing (face-get name))
           (f (apply new-face props))
           (final-fg (or (face-fg f) (and existing (face-fg existing))))
           (final-bg (or (face-bg f) (and existing (face-bg existing))))
           (final-bold (or (face-bold f) (and existing (face-bold existing))))
           (final-italic (or (face-italic f) (and existing (face-italic existing))))
           (final-underline (or (face-underline f) (and existing (face-underline existing)))))
      (hash-put! *faces* name (make-face final-fg final-bg final-bold final-italic final-underline))))

  (def (face-clear!)
    (hash-clear! *faces*))

  ;; Current active theme name
  (def *current-theme* 'dark)

  (def (current-theme-name) *current-theme*)

  (def (load-theme! theme-name)
    (let ((theme (theme-get theme-name)))
      (unless theme
        (error "Unknown theme" theme-name))
      (face-clear!)
      (for-each
        (lambda (entry)
          (let ((face-name (car entry))
                (props (cdr entry)))
            (when (pair? props)
              (apply define-face! face-name props))))
        theme)
      (set! *current-theme* theme-name)))

  ;;;============================================================================
  ;;; Font State
  ;;;============================================================================

  (def *default-font-family* "Monospace")
  (def *default-font-size* 11)

  (def (default-font-family) *default-font-family*)
  (def (default-font-size) *default-font-size*)

  (def (set-default-font! family size)
    (set! *default-font-family* family)
    (set! *default-font-size* size))

  (def (get-default-font)
    (values *default-font-family* *default-font-size*))

  (def (set-frame-font family size)
    (set! *default-font-family* family)
    (set! *default-font-size* size))

  ;;;============================================================================
  ;;; Color Parsing Utilities
  ;;;============================================================================

  (def (parse-hex-color color-str)
    (if (and (string? color-str)
             (>= (string-length color-str) 7)
             (char=? (string-ref color-str 0) #\#))
      (with-catch
        (lambda (e) (values #xd8 #xd8 #xd8))
        (lambda ()
          (let* ((hex-str (substring color-str 1 7))
                 (r-str (substring hex-str 0 2))
                 (g-str (substring hex-str 2 4))
                 (b-str (substring hex-str 4 6)))
            (values
              (string->number r-str 16)
              (string->number g-str 16)
              (string->number b-str 16)))))
      (values #xd8 #xd8 #xd8)))

  (def (rgb->hex r g b)
    (let ((r-hex (number->string r 16))
          (g-hex (number->string g 16))
          (b-hex (number->string b 16)))
      (string-append "#"
                     (if (< r 16) "0" "") r-hex
                     (if (< g 16) "0" "") g-hex
                     (if (< b 16) "0" "") b-hex)))

  ;;;============================================================================
  ;;; Convenience Accessors
  ;;;============================================================================

  (def (face-fg-rgb name)
    (let ((f (face-get name)))
      (if (and f (face-fg f))
        (parse-hex-color (face-fg f))
        (values #xd8 #xd8 #xd8))))

  (def (face-bg-rgb name)
    (let ((f (face-get name)))
      (if (and f (face-bg f))
        (parse-hex-color (face-bg f))
        (values #x18 #x18 #x18))))

  (def (face-has-bold? name)
    (let ((f (face-get name)))
      (and f (face-bold f) #t)))

  (def (face-has-italic? name)
    (let ((f (face-get name)))
      (and f (face-italic f) #t)))

  (def (face-has-underline? name)
    (let ((f (face-get name)))
      (and f (face-underline f) #t)))

  ;;;============================================================================
  ;;; Standard Face Definitions (Dark Theme Defaults)
  ;;;============================================================================

  (def (define-standard-faces!)
    ;; Base faces
    (define-face! 'default 'fg "#d8d8d8" 'bg "#181818")
    (define-face! 'region 'bg "#404060")

    ;; Syntax highlighting faces
    (define-face! 'font-lock-keyword-face 'fg "#cc99cc" 'bold #t)
    (define-face! 'font-lock-builtin-face 'fg "#66cccc")
    (define-face! 'font-lock-string-face 'fg "#99cc99")
    (define-face! 'font-lock-comment-face 'fg "#999999" 'italic #t)
    (define-face! 'font-lock-number-face 'fg "#f99157")
    (define-face! 'font-lock-operator-face 'fg "#b8b8b8")
    (define-face! 'font-lock-type-face 'fg "#ffcc66")
    (define-face! 'font-lock-preprocessor-face 'fg "#f99157")
    (define-face! 'font-lock-heading-face 'fg "#6699cc" 'bold #t)

    ;; UI element faces
    (define-face! 'modeline 'fg "#d8d8d8" 'bg "#282828")
    (define-face! 'modeline-inactive 'fg "#808080" 'bg "#282828")
    (define-face! 'line-number 'fg "#8c8c8c" 'bg "#202020")
    (define-face! 'cursor-line 'bg "#222228")

    ;; Search and matching
    (define-face! 'match 'fg "#ffff00" 'bg "#404060" 'bold #t)
    (define-face! 'mismatch 'fg "#ff4040" 'bg "#602020" 'bold #t)
    (define-face! 'isearch 'fg "#000000" 'bg "#ffcc00")
    (define-face! 'error 'fg "#ff4040")

    ;; Org-mode faces — heading levels
    (define-face! 'org-heading-1 'fg "#6699cc" 'bold #t)
    (define-face! 'org-heading-2 'fg "#f99157" 'bold #t)
    (define-face! 'org-heading-3 'fg "#99cc99" 'bold #t)
    (define-face! 'org-heading-4 'fg "#cc99cc" 'bold #t)
    (define-face! 'org-heading-5 'fg "#66cccc" 'bold #t)
    (define-face! 'org-heading-6 'fg "#ffcc66" 'bold #t)
    (define-face! 'org-heading-7 'fg "#f2777a" 'bold #t)
    (define-face! 'org-heading-8 'fg "#d27b53" 'bold #t)

    ;; Org-mode faces — keywords and elements
    (define-face! 'org-todo 'fg "#dc3232" 'bold #t)
    (define-face! 'org-done 'fg "#32b432" 'bold #t)
    (define-face! 'org-link 'fg "#5078dc" 'underline #t)
    (define-face! 'org-code 'fg "#3ca03c")
    (define-face! 'org-verbatim 'fg "#32b4b4")
    (define-face! 'org-table 'fg "#32b4b4")
    (define-face! 'org-comment 'fg "#828282" 'italic #t)
    (define-face! 'org-tag 'fg "#9650b4")
    (define-face! 'org-date 'fg "#b450b4")
    (define-face! 'org-property 'fg "#646464")
    (define-face! 'org-block-delimiter 'fg "#d28c32")
    (define-face! 'org-block-body 'fg "#646464")

    ;; Tab bar faces
    (define-face! 'tab-active 'fg "#ffffff" 'bg "#404060")
    (define-face! 'tab-inactive 'fg "#a0a0a0" 'bg "#252525")

    ;; Window border faces
    (define-face! 'window-border-active 'fg "#51afef")
    (define-face! 'window-border-inactive 'fg "#3a3a3a"))

  ) ;; end library
