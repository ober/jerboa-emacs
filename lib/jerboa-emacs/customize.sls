#!chezscheme
;;; customize.sls — Customization system for jemacs
;;;
;;; Ported from gerbil-emacs/customize.ss
;;; Provides a centralized variable registry with metadata (type, docstring,
;;; group, default value) — similar to Emacs defcustom.

(library (jerboa-emacs customize)
  (export
    ;; Registry
    defvar!
    custom-get
    custom-set!
    custom-reset!
    custom-describe
    custom-list-group
    custom-list-all
    custom-groups
    custom-registered?
    *custom-registry*

    ;; Hook documentation
    defhook!
    hook-doc
    hook-list-all)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std sort)
          (std misc string))

  ;;; ========================================================================
  ;;; Custom variable registry
  ;;; ========================================================================

  (def *custom-registry* (make-hash-table-eq))

  (def (validate-type type type-args value)
    (case type
      ((boolean) (boolean? value))
      ((integer)
       (and (integer? value)
            (if (pair? type-args)
              (and (>= value (car type-args))
                   (<= value (cdr type-args)))
              #t)))
      ((string) (string? value))
      ((symbol) (symbol? value))
      ((choice)
       (and (list? type-args)
            (member value type-args)))
      ((sexp) #t)
      (else #t)))

  (def (type->string type type-args)
    (case type
      ((boolean) "boolean")
      ((integer)
       (if (pair? type-args)
         (string-append "integer (" (number->string (car type-args))
                        ".." (number->string (cdr type-args)) ")")
         "integer"))
      ((string) "string")
      ((symbol) "symbol")
      ((choice)
       (string-append "one of: "
         (string-join
           (map (lambda (v)
                  (call-with-string-output-port
                    (lambda (p) (write v p))))
                (or type-args '()))
           ", ")))
      ((sexp) "any value")
      (else "unknown")))

  (def (defvar! name default docstring
                (setter #f) (type 'sexp) (type-args #f) (group 'misc))
    (let ((entry (make-hash-table-eq)))
      (hash-put! entry 'name name)
      (hash-put! entry 'default default)
      (hash-put! entry 'value default)
      (hash-put! entry 'docstring docstring)
      (hash-put! entry 'type type)
      (hash-put! entry 'type-args type-args)
      (hash-put! entry 'group group)
      (hash-put! entry 'setter setter)
      (hash-put! *custom-registry* name entry)))

  (def (custom-registered? name)
    (and (hash-get *custom-registry* name) #t))

  (def (custom-get name)
    (let ((entry (hash-get *custom-registry* name)))
      (if entry
        (hash-get entry 'value)
        (error "Unknown customizable variable" name))))

  (def (custom-set! name value)
    (let ((entry (hash-get *custom-registry* name)))
      (unless entry
        (error "Unknown customizable variable" name))
      (let ((type (hash-get entry 'type))
            (type-args (hash-get entry 'type-args)))
        (unless (validate-type type type-args value)
          (error "Type error for variable" name
                 (string-append "expected " (type->string type type-args)
                                ", got: "
                                (call-with-string-output-port
                                  (lambda (p) (write value p))))))
        (hash-put! entry 'value value)
        (let ((setter (hash-get entry 'setter)))
          (when setter
            (setter value))))))

  (def (custom-reset! name)
    (let ((entry (hash-get *custom-registry* name)))
      (unless entry
        (error "Unknown customizable variable" name))
      (let ((default (hash-get entry 'default)))
        (custom-set! name default))))

  (def (custom-describe name)
    (let ((entry (hash-get *custom-registry* name)))
      (unless entry
        (error "Unknown customizable variable" name))
      (let ((docstring (hash-get entry 'docstring))
            (type (hash-get entry 'type))
            (type-args (hash-get entry 'type-args))
            (value (hash-get entry 'value))
            (default (hash-get entry 'default))
            (group (hash-get entry 'group)))
        (string-append
          (symbol->string name) "\n"
          "  " docstring "\n"
          "  Type:    " (type->string type type-args) "\n"
          "  Group:   " (symbol->string group) "\n"
          "  Value:   " (call-with-string-output-port (lambda (p) (write value p))) "\n"
          "  Default: " (call-with-string-output-port (lambda (p) (write default p)))))))

  (def (custom-list-group group)
    (let ((result '()))
      (hash-for-each
        (lambda (name entry)
          (when (eq? (hash-get entry 'group) group)
            (set! result (cons name result))))
        *custom-registry*)
      (sort result (lambda (a b) (string<? (symbol->string a) (symbol->string b))))))

  (def (custom-list-all)
    (let ((result '()))
      (hash-for-each
        (lambda (name entry)
          (set! result (cons name result)))
        *custom-registry*)
      (sort result (lambda (a b) (string<? (symbol->string a) (symbol->string b))))))

  (def (custom-groups)
    (let ((groups (make-hash-table-eq)))
      (hash-for-each
        (lambda (name entry)
          (hash-put! groups (hash-get entry 'group) #t))
        *custom-registry*)
      (sort (hash-keys groups)
            (lambda (a b) (string<? (symbol->string a) (symbol->string b))))))

  ;;; ========================================================================
  ;;; Hook documentation registry
  ;;; ========================================================================

  (def *hook-registry* (make-hash-table-eq))

  (def (defhook! name docstring)
    (hash-put! *hook-registry* name docstring))

  (def (hook-doc name)
    (or (hash-get *hook-registry* name)
        (string-append (symbol->string name) " (undocumented)")))

  (def (hook-list-all)
    (sort (hash-keys *hook-registry*)
          (lambda (a b) (string<? (symbol->string a) (symbol->string b)))))

  ) ;; end library
