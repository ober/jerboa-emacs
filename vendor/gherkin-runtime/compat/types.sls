#!chezscheme
;;; types.sls -- Gerbil type descriptors on Chez records
;;;
;;; Implements Gambit's |##structure| system using Chez records.
;;; A Gherkin type descriptor mirrors Gambit's layout:
;;;   0: type (the metaclass - another type descriptor or #f during bootstrap)
;;;   1: id (symbol)
;;;   2: name (symbol)
;;;   3: flags (fixnum)
;;;   4: super (parent type descriptor or #f)
;;;   5: fields (vector of field descriptors)
;;;   6: precedence-list (C3 linearization)
;;;   7: slot-vector (vector: symbol names for slots)
;;;   8: slot-table (hashtable: symbol/keyword → field index)
;;;   9: properties (alist)
;;;  10: constructor (symbol or #f)
;;;  11: methods (hashtable: symbol → procedure)
;;;
;;; All Gerbil instances are stored as Chez vectors with a type tag at index 0.
;;; This is simpler and more flexible than Chez records for this use case,
;;; because:
;;;   - We need |##structure-type-set!| (mutate the type of an instance)
;;;   - We need uniform field access by numeric index
;;;   - We need |##vector-cas!| on fields for SMP
;;;   - Chez records don't support changing the RTD after creation

(library (compat types)
  (export
    ;; Type descriptor creation and access
    make-type-descriptor
    type-descriptor?
    type-descriptor-id
    type-descriptor-name
    type-descriptor-flags
    type-descriptor-super
    type-descriptor-fields
    type-descriptor-precedence-list
    type-descriptor-slot-vector
    type-descriptor-slot-table
    type-descriptor-properties
    type-descriptor-constructor
    type-descriptor-methods
    set-type-descriptor-id!
    set-type-descriptor-name!
    set-type-descriptor-flags!
    set-type-descriptor-super!
    set-type-descriptor-fields!
    set-type-descriptor-precedence-list!
    set-type-descriptor-slot-vector!
    set-type-descriptor-slot-table!
    set-type-descriptor-properties!
    set-type-descriptor-constructor!
    set-type-descriptor-methods!

    ;; Gerbil struct record type
    gerbil-struct?
    make-gerbil-struct
    gerbil-struct-type-tag
    gerbil-struct-type-tag-set!
    gerbil-struct-field-vec
    gerbil-struct-field-vec-set!

    ;; Gambit |##structure| API
    |##structure|
    |##structure?|
    |##structure-type|
    |##structure-type-set!|
    |##structure-ref|
    |##structure-set!|
    |##unchecked-structure-ref|
    |##unchecked-structure-set!|
    |##structure-instance-of?|
    |##structure-direct-instance-of?|
    |##structure-length|
    |##structure-copy|

    ;; Gambit |##type-*| API
    |##type-id|
    |##type-name|
    |##type-flags|
    |##type-super|
    |##type-fields|
    |##type-type|

    ;; Type flag constants (Gambit base flags)
    type-flag-opaque
    type-flag-extensible
    type-flag-macros
    type-flag-concrete
    type-flag-id

    ;; Gerbil extension flags
    class-type-flag-struct
    class-type-flag-sealed
    class-type-flag-metaclass
    class-type-flag-system
    )

  (import (chezscheme))

  ;;;; Type flag constants

  (define type-flag-opaque       1)
  (define type-flag-extensible   2)
  (define type-flag-macros       4)
  (define type-flag-concrete     8)
  (define type-flag-id          16)

  (define class-type-flag-struct    1024)
  (define class-type-flag-sealed    2048)
  (define class-type-flag-metaclass 4096)
  (define class-type-flag-system    8192)

  ;;;; Instance representation
  ;;;;
  ;;;; Every Gerbil "structure" is a Chez vector with a tag at index 0.
  ;;;; - Index 0: the type descriptor (or #f during bootstrap)
  ;;;; - Index 1..N: the fields
  ;;;;
  ;;;; The tag is the *gherkin-struct-tag* unique value, stored at a
  ;;;; fixed position so we can distinguish Gerbil structures from
  ;;;; plain vectors.

  ;; Unique tag to distinguish Gerbil structures from plain vectors.
  ;; We store this in a 2-element "header" at position 0 of the vector:
  ;;   #(tag type-descriptor field0 field1 ...)
  ;; No, simpler: we use a record wrapper.

  ;; Actually, the simplest approach that supports |##structure-type-set!| and
  ;; indexed access: use a Chez record with a mutable type-tag and a vector
  ;; of fields.

  (define-record-type gerbil-struct
    (fields
      (mutable type-tag)     ;; the type descriptor (or #f)
      (mutable field-vec))   ;; vector of field values
    (sealed #t)
    (opaque #t))

  ;;;; Type descriptors
  ;;;;
  ;;;; A type descriptor is itself a gerbil-struct whose fields follow
  ;;;; Gambit's layout. We access them by index:
  ;;;;   Field 0 (index 0 in field-vec): id
  ;;;;   Field 1: name
  ;;;;   Field 2: flags
  ;;;;   Field 3: super
  ;;;;   Field 4: fields
  ;;;;   Field 5: precedence-list
  ;;;;   Field 6: slot-vector
  ;;;;   Field 7: slot-table
  ;;;;   Field 8: properties
  ;;;;   Field 9: constructor
  ;;;;  Field 10: methods

  (define type-field-count 11)

  ;; Type descriptor field indices (matching Gambit's convention where
  ;; |##type-id| is at index 1 of the |##structure|, but we offset by
  ;; the fact that our field-vec is 0-based for the Gerbil extension fields)
  (define type-id-index          0)
  (define type-name-index        1)
  (define type-flags-index       2)
  (define type-super-index       3)
  (define type-fields-index      4)
  (define type-plist-index       5)  ;; precedence-list
  (define type-slot-vec-index    6)
  (define type-slot-tab-index    7)
  (define type-props-index       8)
  (define type-ctor-index        9)
  (define type-methods-index    10)

  (define (make-type-descriptor type id name flags super fields
                                plist slot-vec slot-tab props ctor methods)
    (let ([fv (make-vector type-field-count)])
      (vector-set! fv type-id-index id)
      (vector-set! fv type-name-index name)
      (vector-set! fv type-flags-index flags)
      (vector-set! fv type-super-index super)
      (vector-set! fv type-fields-index fields)
      (vector-set! fv type-plist-index plist)
      (vector-set! fv type-slot-vec-index slot-vec)
      (vector-set! fv type-slot-tab-index slot-tab)
      (vector-set! fv type-props-index props)
      (vector-set! fv type-ctor-index ctor)
      (vector-set! fv type-methods-index methods)
      (make-gerbil-struct type fv)))

  (define (type-descriptor? x)
    ;; A type descriptor is a gerbil-struct whose field-vec has exactly
    ;; type-field-count entries. This is a heuristic check; the real check
    ;; would be (|##structure-instance-of?| x 'class).
    (and (gerbil-struct? x)
         (let ([fv (gerbil-struct-field-vec x)])
           (and (vector? fv)
                (fx= (vector-length fv) type-field-count)
                ;; The id field should be a symbol
                (symbol? (vector-ref fv type-id-index))))))

  ;; Accessors for type descriptor fields
  (define (type-descriptor-ref td idx)
    (vector-ref (gerbil-struct-field-vec td) idx))

  (define (type-descriptor-set! td idx val)
    (vector-set! (gerbil-struct-field-vec td) idx val))

  (define (type-descriptor-id td)          (type-descriptor-ref td type-id-index))
  (define (type-descriptor-name td)        (type-descriptor-ref td type-name-index))
  (define (type-descriptor-flags td)       (type-descriptor-ref td type-flags-index))
  (define (type-descriptor-super td)       (type-descriptor-ref td type-super-index))
  (define (type-descriptor-fields td)      (type-descriptor-ref td type-fields-index))
  (define (type-descriptor-precedence-list td) (type-descriptor-ref td type-plist-index))
  (define (type-descriptor-slot-vector td) (type-descriptor-ref td type-slot-vec-index))
  (define (type-descriptor-slot-table td)  (type-descriptor-ref td type-slot-tab-index))
  (define (type-descriptor-properties td)  (type-descriptor-ref td type-props-index))
  (define (type-descriptor-constructor td) (type-descriptor-ref td type-ctor-index))
  (define (type-descriptor-methods td)     (type-descriptor-ref td type-methods-index))

  (define (set-type-descriptor-id! td v)          (type-descriptor-set! td type-id-index v))
  (define (set-type-descriptor-name! td v)        (type-descriptor-set! td type-name-index v))
  (define (set-type-descriptor-flags! td v)       (type-descriptor-set! td type-flags-index v))
  (define (set-type-descriptor-super! td v)       (type-descriptor-set! td type-super-index v))
  (define (set-type-descriptor-fields! td v)      (type-descriptor-set! td type-fields-index v))
  (define (set-type-descriptor-precedence-list! td v) (type-descriptor-set! td type-plist-index v))
  (define (set-type-descriptor-slot-vector! td v) (type-descriptor-set! td type-slot-vec-index v))
  (define (set-type-descriptor-slot-table! td v)  (type-descriptor-set! td type-slot-tab-index v))
  (define (set-type-descriptor-properties! td v)  (type-descriptor-set! td type-props-index v))
  (define (set-type-descriptor-constructor! td v) (type-descriptor-set! td type-ctor-index v))
  (define (set-type-descriptor-methods! td v)     (type-descriptor-set! td type-methods-index v))

  ;;;; |##structure| API -- the core Gambit interface

  ;; (|##structure| type field0 field1 ...)
  ;; Creates a new Gerbil structure with the given type and fields.
  (define (|##structure| type . fields)
    (make-gerbil-struct type (list->vector fields)))

  ;; (|##structure?| obj)
  (define (|##structure?| obj)
    (gerbil-struct? obj))

  ;; (|##structure-type| obj)
  ;; Returns the type descriptor of the structure.
  (define (|##structure-type| obj)
    (gerbil-struct-type-tag obj))

  ;; (|##structure-type-set!| obj new-type)
  ;; Mutates the type of a structure. Critical for MOP bootstrap.
  (define (|##structure-type-set!| obj new-type)
    (gerbil-struct-type-tag-set! obj new-type))

  ;; (|##structure-ref| obj field-index type-desc slot-name)
  ;; Read field at field-index (1-based in Gambit convention, but we
  ;; adjust: Gambit field index 1 = our field-vec index 0).
  ;; Actually, in Gambit, field 0 is the type itself. Fields start at 1.
  ;; So Gambit |##structure-ref| index 1 = our field-vec[0].
  (define |##structure-ref|
    (case-lambda
      ((obj field-index)
       (if (gerbil-struct? obj)
         (vector-ref (gerbil-struct-field-vec obj) (fx- field-index 1))
         (vector-ref obj field-index)))
      ((obj field-index type-desc slot-name)
       (if (gerbil-struct? obj)
         (vector-ref (gerbil-struct-field-vec obj) (fx- field-index 1))
         (vector-ref obj field-index)))))

  (define |##structure-set!|
    (case-lambda
      ((obj field-index val)
       (if (gerbil-struct? obj)
         (vector-set! (gerbil-struct-field-vec obj) (fx- field-index 1) val)
         (vector-set! obj field-index val)))
      ((obj val field-index type-desc slot-name)
       (if (gerbil-struct? obj)
         (vector-set! (gerbil-struct-field-vec obj) (fx- field-index 1) val)
         (vector-set! obj field-index val)))))

  ;; Unchecked variants — handle both gerbil-struct and plain vectors.
  ;; Plain vectors (e.g. native raw-tables) use Gambit's convention where
  ;; index 0 = type tag, fields at 1+, so vector-ref with no adjustment.
  ;; Gerbil-structs store fields in field-vec starting at 0, so subtract 1.
  (define |##unchecked-structure-ref|
    (case-lambda
      ((obj field-index)
       (if (gerbil-struct? obj)
         (vector-ref (gerbil-struct-field-vec obj) (fx- field-index 1))
         (vector-ref obj field-index)))
      ((obj field-index type-desc slot-name)
       (if (gerbil-struct? obj)
         (vector-ref (gerbil-struct-field-vec obj) (fx- field-index 1))
         (vector-ref obj field-index)))))

  (define |##unchecked-structure-set!|
    (case-lambda
      ((obj field-index val)
       (if (gerbil-struct? obj)
         (vector-set! (gerbil-struct-field-vec obj) (fx- field-index 1) val)
         (vector-set! obj field-index val)))
      ((obj val field-index type-desc slot-name)
       (if (gerbil-struct? obj)
         (vector-set! (gerbil-struct-field-vec obj) (fx- field-index 1) val)
         (vector-set! obj field-index val)))))

  ;; (|##structure-instance-of?| obj type-id)
  ;; Checks if obj is a structure whose type (or any ancestor type) has the
  ;; given type-id.
  (define (|##structure-instance-of?| obj type-id)
    (and (gerbil-struct? obj)
         (let ([td (gerbil-struct-type-tag obj)])
           (and td
                (type-descriptor? td)
                (let walk ([td td])
                  (cond
                    [(not td) #f]
                    [(eq? (type-descriptor-id td) type-id) #t]
                    [(type-descriptor? td)
                     (walk (type-descriptor-super td))]
                    [else #f]))))))

  ;; (|##structure-direct-instance-of?| obj type-id)
  (define (|##structure-direct-instance-of?| obj type-id)
    (and (gerbil-struct? obj)
         (let ([td (gerbil-struct-type-tag obj)])
           (and td
                (type-descriptor? td)
                (eq? (type-descriptor-id td) type-id)))))

  ;; (|##structure-length| obj)
  ;; Total length including type slot (Gambit convention).
  (define (|##structure-length| obj)
    (if (gerbil-struct? obj)
      (fx+ 1 (vector-length (gerbil-struct-field-vec obj)))
      (vector-length obj)))

  ;; (|##structure-copy| obj)
  ;; Shallow copy of a gerbil structure.
  (define (|##structure-copy| obj)
    (let* ([fv (gerbil-struct-field-vec obj)]
           [n (vector-length fv)]
           [new-fv (make-vector n)])
      (do ([i 0 (fx+ i 1)])
          ((fx= i n))
        (vector-set! new-fv i (vector-ref fv i)))
      (make-gerbil-struct (gerbil-struct-type-tag obj) new-fv)))

  ;;;; |##type-*| API (access type descriptor fields via Gambit conventions)
  ;;;; In Gambit, |##type-id| is (|##structure-ref| td 1 |##type-type| 'id),
  ;;;; which maps to field-vec[0] in our system.

  ;; ##type-type is the metatype — a type descriptor whose type is itself.
  ;; In Gambit, ##type-type is both a type descriptor and used as a value
  ;; in (##structure ##type-type ...) to create type descriptors.
  ;; Its id is '##type and its fields describe the 6 fields of a basic type.
  (define |##type-type|
    (let ([fv (make-vector type-field-count)])
      (vector-set! fv type-id-index '|##type|)
      (vector-set! fv type-name-index 'type)
      (vector-set! fv type-flags-index 0)
      (vector-set! fv type-super-index #f)
      (vector-set! fv type-fields-index '#(id 0 #f name 0 #f flags 0 #f super 0 #f fields 0 #f))
      (vector-set! fv type-plist-index #f)
      (vector-set! fv type-slot-vec-index #f)
      (vector-set! fv type-slot-tab-index #f)
      (vector-set! fv type-props-index #f)
      (vector-set! fv type-ctor-index #f)
      (vector-set! fv type-methods-index #f)
      (let ([td (make-gerbil-struct #f fv)])
        ;; Self-referential: the metatype's type is itself
        (gerbil-struct-type-tag-set! td td)
        td)))

  (define (|##type-id| td)
    (type-descriptor-id td))

  (define (|##type-name| td)
    (type-descriptor-name td))

  (define (|##type-flags| td)
    (type-descriptor-flags td))

  (define (|##type-super| td)
    (type-descriptor-super td))

  (define (|##type-fields| td)
    (type-descriptor-fields td))

  ) ;; end library
