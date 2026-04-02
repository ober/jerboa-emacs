#!chezscheme
;;; mop.sls -- Gerbil Meta-Object Protocol on Chez Scheme
;;; Implements the Gerbil type system using Phase 1's gerbil-struct representation.

(library (runtime mop)
  (export
    ;; type flags
    type-flag-opaque type-flag-extensible type-flag-macros
    type-flag-concrete type-flag-id
    class-type-flag-struct class-type-flag-sealed
    class-type-flag-metaclass class-type-flag-system
    ;; root types
    t::t class::t object::t
    ;; type predicates
    class-type? class-type=?
    struct-type? object-type?
    type-opaque? type-extensible?
    class-type-final? class-type-struct? class-type-sealed?
    class-type-metaclass? class-type-system?
    ;; type accessors
    class-type-id class-type-name class-type-super class-type-flags
    class-type-fields class-type-precedence-list
    class-type-slot-vector class-type-slot-table
    class-type-properties class-type-constructor class-type-methods
    class-type-slot-list class-type-field-count
    ;; type creation
    make-class-type-descriptor make-class-type make-class-predicate
    make-class-slot-accessor make-class-slot-mutator
    make-class-slot-unchecked-accessor make-class-slot-unchecked-mutator
    ;; instance operations
    make-instance make-class-instance
    class-instance-init! struct-instance-init!
    class-instance?
    struct-instance? direct-class-instance? direct-struct-instance?
    ;; slot operations
    slot-ref slot-set! unchecked-slot-ref unchecked-slot-set!
    ;; precedence
    substruct? base-struct compute-class-slots
    ;; method table
    method-ref method-set! bind-method! call-method
    ;; sealing
    class-type-seal!
    ;; structure operations (re-exports from types.sls for convenience)
    |##structure?| |##structure-type| |##structure-instance-of?|
    |##structure-direct-instance-of?|
    |##structure-ref| |##structure-set!|
    |##unchecked-structure-ref| |##unchecked-structure-set!|
    |##structure| |##structure-type-set!| |##structure-copy|
    |##type-id| |##type-name| |##type-super| |##type-flags| |##type-fields|
    ;; misc
    find-super-constructor
    fxflag-set? fxflag-unset?
    )

  (import
    (except (chezscheme) void box box? unbox set-box!
            andmap ormap iota last-pair find
            1+ 1- fx/ fx1+ fx1-)
    ;; gambit-compat not needed: structure ops come from (compat types)
    (compat types)
    (runtime util)
    (except (runtime table) string-hash)
    (runtime c3))

  ;; Type flags imported from (compat types)

  ;; --- Flag helpers ---
  (define (fxflag-set? value flag)
    (fx= (fxlogand value flag) flag))
  (define (fxflag-unset? value flag)
    (fx= (fxlogand value flag) 0))

  ;; --- Bootstrap the root types ---
  ;; Type descriptor layout (indices 1-11 in gerbil-struct fields):
  ;;  1  type-id
  ;;  2  type-name
  ;;  3  type-flags
  ;;  4  type-super
  ;;  5  type-fields
  ;;  6  class-type-precedence-list
  ;;  7  class-type-slot-vector
  ;;  8  class-type-slot-table
  ;;  9  class-type-properties
  ;; 10  class-type-constructor
  ;; 11  class-type-methods

  ;; Create t::t (root type)
  (define t::t
    (let ((slot-table (make-symbolic-table #f 0))
          (flags (fxlogior type-flag-extensible type-flag-id class-type-flag-system))
          (properties '((direct-slots:) (system: . #t))))
      (|##structure|
        #f                               ; type: class::t, set below
        't                               ; type-id
        't                               ; type-name
        flags                            ; type-flags
        #f                               ; type-super
        '#()                             ; type-fields
        '()                              ; class-type-precedence-list
        '#(#f)                           ; class-type-slot-vector
        slot-table                       ; class-type-slot-table
        properties                       ; class-type-properties
        #f                               ; class-type-constructor
        #f)))                            ; class-type-methods

  ;; Create class::t (metaclass)
  (define class::t
    (let* ((slots '(id name super flags fields
                       precedence-list slot-vector slot-table
                       properties constructor methods))
           (slot-vector (list->vector (cons #f slots)))
           (slot-table
             (let ((st (make-symbolic-table #f 0)))
               (let lp ((ss slots) (i 1))
                 (when (pair? ss)
                   (symbolic-table-set! st (car ss) i)
                   (symbolic-table-set! st (symbol->keyword (car ss)) i)
                   ;; Also store colon-suffixed symbol (e.g. x:) for Chez keyword convention
                   (symbolic-table-set! st
                     (string->symbol (string-append (symbol->string (car ss)) ":")) i)
                   (lp (cdr ss) (fx+ i 1))))
               st))
           (flags (fxlogior type-flag-extensible type-flag-concrete type-flag-id
                            class-type-flag-struct))
           (fields (list->vector
                     (apply append
                       (map (lambda (s) (list s 5 #f))
                            ;; Only the last 6 fields (after Gambit's type-type fields)
                            (list-tail slots 5)))))
           (properties `((direct-slots: ,@slots) (struct: . #t)))
           (t (|##structure|
                #f                  ; type: self reference, set below
                'class              ; type-id
                'class              ; type-name
                flags               ; type-flags
                #f                  ; type-super (Gambit ##type-type; use #f for Chez)
                fields              ; type-fields
                (list t::t)         ; class-type-precedence-list
                slot-vector         ; class-type-slot-vector
                slot-table          ; class-type-slot-table
                properties          ; class-type-properties
                #f                  ; class-type-constructor
                #f)))               ; class-type-methods
      (|##structure-type-set!| t t)  ; self reference
      t))

  ;; Create object::t (root object type)
  ;; Also wire t::t's type to class::t here (must be done after both are defined)
  (define object::t
    (begin
      (|##structure-type-set!| t::t class::t)
      (let ((slot-table (make-symbolic-table #f 0))
            (flags (fxlogior type-flag-extensible type-flag-id class-type-flag-system))
            (properties '((direct-slots:) (system: . #t))))
        (|##structure|
          class::t                         ; type
          'object                          ; type-id
          'object                          ; type-name
          flags                            ; type-flags
          #f                               ; type-super
          '#()                             ; type-fields
          (list t::t)                      ; class-type-precedence-list
          '#(#f)                           ; class-type-slot-vector
          slot-table                       ; class-type-slot-table
          properties                       ; class-type-properties
          #f                               ; class-type-constructor
          #f))))

  ;; --- Type accessors ---
  (define (class-type-id klass)     (|##structure-ref| klass 1))
  (define (class-type-name klass)   (|##structure-ref| klass 2))
  (define (class-type-flags klass)  (|##structure-ref| klass 3))
  (define (class-type-super klass)  (|##structure-ref| klass 4))
  (define (class-type-fields klass) (|##structure-ref| klass 5))
  (define (class-type-precedence-list klass) (|##structure-ref| klass 6))
  (define (class-type-slot-vector klass) (|##structure-ref| klass 7))
  (define (class-type-slot-table klass) (|##structure-ref| klass 8))
  (define (class-type-properties klass) (|##structure-ref| klass 9))
  (define (class-type-constructor klass) (|##structure-ref| klass 10))
  (define (class-type-methods klass) (|##structure-ref| klass 11))

  ;; --- Type predicates ---
  (define (class-type? obj)
    (|##structure-instance-of?| obj 'class))

  (define (class-type=? x y)
    (eq? (class-type-id x) (class-type-id y)))

  (define (struct-type? klass)
    (and (class-type? klass)
         (fxflag-set? (class-type-flags klass) class-type-flag-struct)))

  (define (object-type? klass)
    (and (class-type? klass)
         (not (fxflag-set? (class-type-flags klass) class-type-flag-struct))))

  (define (type-opaque? type)
    (fxflag-set? (|##type-flags| type) type-flag-opaque))
  (define (type-extensible? type)
    (fxflag-set? (|##type-flags| type) type-flag-extensible))
  (define (class-type-final? type)
    (fxflag-unset? (|##type-flags| type) type-flag-extensible))
  (define (class-type-struct? klass)
    (fxflag-set? (|##type-flags| klass) class-type-flag-struct))
  (define (class-type-sealed? klass)
    (fxflag-set? (|##type-flags| klass) class-type-flag-sealed))
  (define (class-type-metaclass? klass)
    (fxflag-set? (|##type-flags| klass) class-type-flag-metaclass))
  (define (class-type-system? klass)
    (fxflag-set? (|##type-flags| klass) class-type-flag-system))

  ;; --- Slot operations ---
  (define (class-type-slot-list klass)
    (cdr (vector->list (class-type-slot-vector klass))))

  (define (class-type-field-count klass)
    (fx- (vector-length (class-type-slot-vector klass)) 1))

  ;; Compute the slot assignments for a new class
  (define (compute-class-slots klass)
    (let ((slot-table (class-type-slot-table klass))
          (slot-vec (class-type-slot-vector klass)))
      (values slot-vec slot-table)))

  ;; --- Type creation ---
  (define (make-class-type-descriptor type-id type-name type-super
                                      precedence-list slot-vector properties
                                      constructor slot-table methods)
    (let* ((plist (if (pair? precedence-list) precedence-list
                   (if type-super (list type-super t::t) (list t::t))))
           (is-struct (cond ((assq 'struct: properties) => cdr) (else #f)))
           (flags (fxlogior
                    type-flag-extensible
                    type-flag-concrete
                    type-flag-id
                    (if is-struct class-type-flag-struct 0)))
           ;; Build fields vector
           (slots (cdr (vector->list slot-vector)))
           (fields (list->vector
                     (apply append
                       (map (lambda (s) (list s 5 #f)) slots)))))
      (|##structure|
        class::t
        type-id type-name flags type-super fields
        plist slot-vector slot-table properties
        constructor methods)))

  ;; High-level class creation (computes slots and precedence)
  (define make-class-type
    (case-lambda
      ((id name direct-supers slots properties constructor)
       (make-class-type id name direct-supers slots properties constructor #f))
      ((id name direct-supers slots properties constructor methods)
       ;; Build slot vector and table
       (let* ((all-slots
                (let ((inherited
                        (if (null? direct-supers) '()
                          (cdr (vector->list
                                 (class-type-slot-vector (car direct-supers)))))))
                  (append inherited slots)))
              (slot-vector (list->vector (cons #f all-slots)))
              (slot-table
                (let ((st (make-symbolic-table #f 0)))
                  (let lp ((ss all-slots) (i 1))
                    (when (pair? ss)
                      (symbolic-table-set! st (car ss) i)
                      (symbolic-table-set! st (symbol->keyword (car ss)) i)
                      ;; Also store colon-suffixed symbol (e.g. x:) for Chez keyword convention
                      (symbolic-table-set! st
                        (string->symbol (string-append (symbol->string (car ss)) ":")) i)
                      (lp (cdr ss) (fx+ i 1))))
                  st)))
         ;; Compute precedence list
         (let-values (((plist super-struct)
                       (if (null? direct-supers)
                         (values (list t::t) #f)
                         (c4-linearize (list) direct-supers
                           (lambda (s) (cons s (class-type-precedence-list s)))
                           struct-type?
                           eq?
                           class-type-name))))
           (let* ((props (cons (cons 'direct-slots: slots)
                              (cons (cons 'direct-supers: direct-supers)
                                    properties)))
                  ;; Resolve constructor: use explicit arg, then properties, then supers
                  (constructor*
                    (or constructor
                        (cond ((assq 'constructor: properties) => cdr)
                              (else #f))
                        ;; Walk supers to find inherited constructor
                        (let lp ((rest direct-supers))
                          (if (null? rest) #f
                            (or (class-type-constructor (car rest))
                                (lp (cdr rest)))))))
)
             (make-class-type-descriptor
               id name (if (pair? direct-supers) (car direct-supers) #f)
               plist slot-vector props constructor* slot-table
               (or methods (make-symbolic-table #f 0)))))))))

  ;; --- Predicates ---
  (define (make-class-predicate klass)
    (let ((id (class-type-id klass)))
      (lambda (obj)
        (|##structure-instance-of?| obj id))))

  ;; --- Accessors and mutators ---
  (define (make-class-slot-accessor klass slot)
    (let ((idx (symbolic-table-ref (class-type-slot-table klass) slot #f)))
      (unless idx (error "unknown slot" klass slot))
      (lambda (obj) (|##structure-ref| obj idx))))

  (define (make-class-slot-mutator klass slot)
    (let ((idx (symbolic-table-ref (class-type-slot-table klass) slot #f)))
      (unless idx (error "unknown slot" klass slot))
      (lambda (obj val) (|##structure-set!| obj idx val))))

  (define make-class-slot-unchecked-accessor make-class-slot-accessor)
  (define make-class-slot-unchecked-mutator make-class-slot-mutator)

  ;; --- Keyword argument helpers ---
  ;; Check if a value is a keyword symbol (symbol ending with :)
  (define (keyword-symbol? v)
    (and (symbol? v)
         (let ((s (symbol->string v)))
           (and (fx> (string-length s) 1)
                (char=? (string-ref s (fx- (string-length s) 1)) #\:)))))

  ;; Strip keyword symbols from an argument list, keeping values positionally.
  ;; (strip-kw-args '(parent: env name: "gsh")) → '(env "gsh")
  (define (strip-kw-args args)
    (let lp ((rest args) (acc '()))
      (cond
        ((null? rest) (reverse acc))
        ((and (keyword-symbol? (car rest)) (pair? (cdr rest)))
         ;; Skip keyword, keep value
         (lp (cddr rest) (cons (cadr rest) acc)))
        (else
         (lp (cdr rest) (cons (car rest) acc))))))

  ;; Check if args contain keyword symbols
  (define (has-keyword-args? args)
    (let lp ((rest args))
      (cond
        ((null? rest) #f)
        ((keyword-symbol? (car rest)) #t)
        (else (lp (cdr rest))))))

  ;; --- Instance operations ---
  ;; make-instance: full constructor protocol with keyword dispatch
  ;; 1. If class has a constructor (:init!), look up the method and call it
  ;;    with keyword args stripped to positional
  ;; 2. Otherwise, initialize slots by keyword name (class-instance-init!)
  (define (make-instance klass . args)
    (let ((kons-id (class-type-constructor klass)))
      (cond
        ;; Class has a constructor method — use it
        (kons-id
         (let* ((n (class-type-field-count klass))
                (obj (apply |##structure| klass (make-list n #f)))
                (kons (method-ref klass kons-id)))
           (if kons
             ;; Strip keyword symbols so :init! gets positional args
             (let ((stripped (if (has-keyword-args? args)
                               (strip-kw-args args)
                               args)))
               (apply kons obj stripped))
             (error "missing constructor method" klass kons-id))
           obj))
        ;; Struct with exact field count — direct construction
        ((and (class-type-struct? klass)
              (fx= (class-type-field-count klass) (length args)))
         (apply |##structure| klass args))
        ;; Otherwise — keyword-based slot initialization
        (else
         (let* ((n (class-type-field-count klass))
                (obj (apply |##structure| klass (make-list n #f))))
           (class-instance-init! obj args)
           obj)))))

  ;; Alias for compatibility
  (define make-class-instance make-instance)

  (define (class-instance-init! obj args)
    (let* ((klass (|##structure-type| obj))
           (slot-table (class-type-slot-table klass)))
      (let lp ((rest args))
        (when (and (pair? rest) (pair? (cdr rest)))
          (let* ((key (car rest))
                 (val (cadr rest))
                 (idx (symbolic-table-ref slot-table key #f)))
            (when idx
              (|##structure-set!| obj idx val))
            (lp (cddr rest)))))))

  ;; struct-instance-init!: initialize struct fields positionally (starting at index 1)
  (define (struct-instance-init! obj . args)
    (let lp ((k 1) (rest args))
      (when (pair? rest)
        (|##structure-set!| obj k (car rest))
        (lp (+ k 1) (cdr rest))))
    obj)

  (define (class-instance? klass obj)
    (|##structure-instance-of?| obj (class-type-id klass)))

  (define (struct-instance? klass obj)
    (and (struct-type? klass) (class-instance? klass obj)))

  (define (direct-class-instance? klass obj)
    (|##structure-direct-instance-of?| obj (class-type-id klass)))

  (define (direct-struct-instance? klass obj)
    (and (struct-type? klass) (direct-class-instance? klass obj)))

  ;; --- Slot access ---
  (define (slot-ref obj slot)
    (let* ((klass (|##structure-type| obj))
           (idx (symbolic-table-ref (class-type-slot-table klass) slot #f)))
      (unless idx (error "unknown slot" obj slot))
      (|##structure-ref| obj idx)))

  (define (slot-set! obj slot val)
    (let* ((klass (|##structure-type| obj))
           (idx (symbolic-table-ref (class-type-slot-table klass) slot #f)))
      (unless idx (error "unknown slot" obj slot))
      (|##structure-set!| obj idx val)))

  (define (unchecked-slot-ref obj slot)
    (slot-ref obj slot))
  (define (unchecked-slot-set! obj slot val)
    (slot-set! obj slot val))

  ;; --- Substruct ---
  (define (substruct? maybe-sub maybe-super)
    (or (eq? maybe-sub maybe-super)
        (and (class-type? maybe-sub)
             (memq maybe-super (class-type-precedence-list maybe-sub))
             #t)))

  (define (base-struct klass)
    (let ((plist (class-type-precedence-list klass)))
      (let lp ((rest plist))
        (cond
          ((null? rest) #f)
          ((struct-type? (car rest)) (car rest))
          (else (lp (cdr rest)))))))

  ;; --- Method table ---
  (define (method-ref klass name)
    (let ((methods (class-type-methods klass)))
      (and methods (symbolic-table-ref methods name #f))))

  (define (method-set! klass name proc)
    (let ((methods (class-type-methods klass)))
      (unless methods
        (let ((new-methods (make-symbolic-table #f 0)))
          (|##structure-set!| klass 11 new-methods)
          (set! methods new-methods)))
      (symbolic-table-set! methods name proc)))

  ;; bind-method! is the name used in the self-hosted Gerbil runtime
  (define bind-method! method-set!)

  ;; --- Call a method on an object ---
  (define (call-method obj name . args)
    (let* ((type (|##structure-type| obj))
           (method (method-ref type name)))
      (if method
        (apply method obj args)
        (error 'call-method "method not found" name type))))

  ;; --- Sealing ---
  (define (class-type-seal! klass)
    (|##structure-set!| klass 3
      (fxlogior (class-type-flags klass) class-type-flag-sealed)))

  ;; --- Find super constructor ---
  (define (find-super-constructor klass)
    (let lp ((plist (class-type-precedence-list klass)))
      (cond
        ((null? plist) #f)
        ((class-type-constructor (car plist)) => values)
        (else (lp (cdr plist))))))

  ) ;; end library
