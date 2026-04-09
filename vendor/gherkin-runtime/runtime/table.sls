#!chezscheme
;;; table.sls -- Hash tables for Gerbil runtime on Chez Scheme
;;; Uses Chez native hashtables with thin wrappers for Gerbil API compatibility.
;;; The raw-table API uses open-addressing with quadratic probing on vectors.

(library (runtime table)
  (export
    ;; raw table type
    __table::t
    ;; raw table operations
    make-raw-table raw-table-ref raw-table-set! raw-table-update!
    raw-table-delete! raw-table-for-each raw-table-copy raw-table-clear!
    raw-table-size-hint->size &raw-table-count
    ;; specialized tables
    make-symbolic-table symbolic-table-ref symbolic-table-set!
    symbolic-table-update! symbolic-table-delete!
    symbolic-table-for-each symbolic-table-length
    symbolic-table-copy symbolic-table-clear!
    make-eq-table eq-table-ref eq-table-set! eq-table-update! eq-table-delete!
    make-eqv-table eqv-table-ref eqv-table-set! eqv-table-update! eqv-table-delete!
    make-string-table string-table-ref string-table-set! string-table-update! string-table-delete!
    make-immediate-table immediate-table-ref immediate-table-set!
    immediate-table-update! immediate-table-delete!
    ;; hash functions
    eq-hash eqv-hash symbolic-hash string-hash immediate-hash procedure-hash
    symbolic?
    ;; gc tables (implemented with Chez hashtables)
    __gc-table::t
    make-gc-table gc-table-ref gc-table-set! gc-table-update!
    gc-table-delete! gc-table-for-each gc-table-copy gc-table-clear!
    gc-table-length
    ;; raw-table-for-each is also used by control.ss for keyword-rest
    raw-table-for-each
    ;; sentinel values (for sharing with compiled bootstrap code)
    *unused* *deleted*
    )

  (import
    (except (chezscheme) void box box? unbox set-box! string-hash)
    (compat gambit-compat)
    (only (compat types) gerbil-struct? gerbil-struct-field-vec))

  ;; --- Sentinel objects for open-addressing tables ---
  ;; MUST use the same objects as gambit-compat's macro-unused-obj/macro-deleted-obj
  ;; so compiled Gerbil code and our probe loops agree on sentinels.
  (define *unused* (macro-unused-obj))
  (define *deleted* (macro-deleted-obj))

  ;; Type tags
  (define __table::t (string->symbol "gerbil#__table::t"))
  (define __gc-table::t (string->symbol "gerbil#__gc-table::t"))

  ;; --- Raw table: vector-based open addressing with quadratic probing ---
  ;; Layout: #(tag table-vec count free hash-fn test-fn seed)
  ;; Also supports gerbil-struct wrapped tables (from compiled bootstrap code)
  ;; where the field-vec has layout #(table-vec count free hash test seed)
  (define (make-raw-table-struct vec count free hash test seed)
    (vector 'raw-table vec count free hash test seed))

  (define (raw-table? x)
    (or (and (vector? x) (fx>= (vector-length x) 7)
             (eq? (vector-ref x 0) 'raw-table))
        ;; Also recognize gerbil-struct wrapped tables from compiled bootstrap
        (and (gerbil-struct? x)
             (let ([fv (gerbil-struct-field-vec x)])
               (and (vector? fv) (fx>= (vector-length fv) 6)
                    (vector? (vector-ref fv 0)))))))

  ;; Unwrap a table: returns the backing vector for field access.
  ;; For native raw-tables, returns the table itself.
  ;; For gerbil-struct tables, returns a shifted view via the field-vec.
  (define (rt-unwrap t)
    (if (gerbil-struct? t)
      (gerbil-struct-field-vec t)
      t))

  ;; For gerbil-struct tables, field-vec indices are shifted by -1 compared to raw-table
  (define (rt-table t)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-ref t 1) (vector-ref u 0))))
  (define (rt-count t)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-ref t 2) (vector-ref u 1))))
  (define (rt-free t)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-ref t 3) (vector-ref u 2))))
  (define (rt-hash t)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-ref t 4) (vector-ref u 3))))
  (define (rt-test t)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-ref t 5) (vector-ref u 4))))
  (define (rt-seed t)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-ref t 6) (vector-ref u 5))))

  (define (rt-table-set! t v)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-set! t 1 v) (vector-set! u 0 v))))
  (define (rt-count-set! t v)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-set! t 2 v) (vector-set! u 1 v))))
  (define (rt-free-set! t v)
    (let ([u (rt-unwrap t)])
      (if (eq? u t) (vector-set! t 3 v) (vector-set! u 2 v))))

  (define &raw-table-count rt-count)

  ;; --- Size calculation ---
  (define (raw-table-size-hint->size size-hint)
    (if (and (fixnum? size-hint) (fx> size-hint 0))
      (fx* (fxmax 2 (expt 2 (fxlength size-hint))) 4)
      16))

  ;; --- Table construction ---
  (define make-raw-table
    (case-lambda
      ((size-hint hash test)
       (%make-raw-table size-hint hash test 0))
      ((size-hint hash test seed)
       (%make-raw-table size-hint hash test seed))))

  (define (%make-raw-table size-hint hash test seed)
    (let* ((size (raw-table-size-hint->size size-hint))
           (vec (make-vector size *unused*)))
      (make-raw-table-struct vec 0 (fxdiv size 2) hash test seed)))

  ;; --- Probing ---
  (define (probe-step start i size)
    (fxmod (fx+ start i (fx* i i)) size))

  ;; --- Lookup ---
  (define (table-lookup vec seed hash test key default-value)
    (let* ((h (fxxor (hash key) seed))
           (size (vector-length vec))
           (entries (fxdiv size 2))
           (start (fxsll (fxmod h entries) 1)))
      (let loop ((probe start) (i 1))
        (let ((k (vector-ref vec probe)))
          (cond
            ((eq? k *unused*) default-value)
            ((eq? k *deleted*) (loop (probe-step start i size) (fx+ i 1)))
            ((test key k) (vector-ref vec (fx+ probe 1)))
            (else (loop (probe-step start i size) (fx+ i 1))))))))

  ;; --- Insert/Update ---
  (define (table-insert! vec seed hash test key value on-insert on-resurrect)
    (let* ((h (fxxor (hash key) seed))
           (size (vector-length vec))
           (entries (fxdiv size 2))
           (start (fxsll (fxmod h entries) 1)))
      (let loop ((probe start) (i 1) (deleted #f))
        (let ((k (vector-ref vec probe)))
          (cond
            ((eq? k *unused*)
             (if deleted
               (begin
                 (vector-set! vec deleted key)
                 (vector-set! vec (fx+ deleted 1) value)
                 (on-resurrect))
               (begin
                 (vector-set! vec probe key)
                 (vector-set! vec (fx+ probe 1) value)
                 (on-insert))))
            ((eq? k *deleted*)
             (loop (probe-step start i size) (fx+ i 1) (or deleted probe)))
            ((test key k)
             (vector-set! vec probe key)
             (vector-set! vec (fx+ probe 1) value))
            (else
             (loop (probe-step start i size) (fx+ i 1) deleted)))))))

  ;; --- Update with function ---
  (define (table-update-fn! vec seed hash test key update default on-insert on-resurrect)
    (let* ((h (fxxor (hash key) seed))
           (size (vector-length vec))
           (entries (fxdiv size 2))
           (start (fxsll (fxmod h entries) 1)))
      (let loop ((probe start) (i 1) (deleted #f))
        (let ((k (vector-ref vec probe)))
          (cond
            ((eq? k *unused*)
             (if deleted
               (begin
                 (vector-set! vec deleted key)
                 (vector-set! vec (fx+ deleted 1) (update default))
                 (on-resurrect))
               (begin
                 (vector-set! vec probe key)
                 (vector-set! vec (fx+ probe 1) (update default))
                 (on-insert))))
            ((eq? k *deleted*)
             (loop (probe-step start i size) (fx+ i 1) (or deleted probe)))
            ((test key k)
             (vector-set! vec probe key)
             (vector-set! vec (fx+ probe 1) (update (vector-ref vec (fx+ probe 1)))))
            (else
             (loop (probe-step start i size) (fx+ i 1) deleted)))))))

  ;; --- Delete ---
  (define (table-delete-key! vec seed hash test key on-delete)
    (let* ((h (fxxor (hash key) seed))
           (size (vector-length vec))
           (entries (fxdiv size 2))
           (start (fxsll (fxmod h entries) 1)))
      (let loop ((probe start) (i 1))
        (let ((k (vector-ref vec probe)))
          (cond
            ((eq? k *unused*) (values))
            ((eq? k *deleted*) (loop (probe-step start i size) (fx+ i 1)))
            ((test key k)
             (vector-set! vec probe *deleted*)
             (vector-set! vec (fx+ probe 1) *unused*)
             (on-delete))
            (else (loop (probe-step start i size) (fx+ i 1))))))))

  ;; --- Rehash ---
  (define (raw-table-rehash! tab)
    (let* ((old-vec (rt-table tab))
           (old-size (vector-length old-vec))
           (new-size (if (fx< (rt-count tab) (fxdiv old-size 4))
                       old-size
                       (fx* 2 old-size)))
           (new-vec (make-vector new-size *unused*)))
      (rt-table-set! tab new-vec)
      (rt-count-set! tab 0)
      (rt-free-set! tab (fxdiv new-size 2))
      (let lp ((i 0))
        (when (fx< i old-size)
          (let ((key (vector-ref old-vec i)))
            (when (and (not (eq? key *unused*))
                       (not (eq? key *deleted*)))
              (let ((value (vector-ref old-vec (fx+ i 1))))
                (raw-table-set-internal! tab key value))))
          (lp (fx+ i 2))))))

  (define (raw-table-set-internal! tab key value)
    (table-insert! (rt-table tab) (rt-seed tab) (rt-hash tab) (rt-test tab)
                   key value
                   (lambda ()
                     (rt-free-set! tab (fx- (rt-free tab) 1))
                     (rt-count-set! tab (fx+ (rt-count tab) 1)))
                   (lambda ()
                     (rt-count-set! tab (fx+ (rt-count tab) 1)))))

  ;; --- Public raw table API ---
  (define (raw-table-ref tab key default)
    (table-lookup (rt-table tab) (rt-seed tab) (rt-hash tab) (rt-test tab) key default))

  (define (raw-table-set! tab key value)
    (when (fx< (rt-free tab)
               (fxdiv (vector-length (rt-table tab)) 4))
      (raw-table-rehash! tab))
    (raw-table-set-internal! tab key value))

  (define (raw-table-update! tab key update default)
    (when (fx< (rt-free tab)
               (fxdiv (vector-length (rt-table tab)) 4))
      (raw-table-rehash! tab))
    (table-update-fn! (rt-table tab) (rt-seed tab) (rt-hash tab) (rt-test tab)
                      key update default
                      (lambda ()
                        (rt-free-set! tab (fx- (rt-free tab) 1))
                        (rt-count-set! tab (fx+ (rt-count tab) 1)))
                      (lambda ()
                        (rt-count-set! tab (fx+ (rt-count tab) 1)))))

  (define (raw-table-delete! tab key)
    (table-delete-key! (rt-table tab) (rt-seed tab) (rt-hash tab) (rt-test tab)
                       key
                       (lambda ()
                         (rt-count-set! tab (fx- (rt-count tab) 1)))))

  (define (raw-table-for-each tab proc)
    (let* ((vec (rt-table tab))
           (size (vector-length vec)))
      (let loop ((i 0))
        (when (fx< i size)
          (let ((key (vector-ref vec i)))
            (when (and (not (eq? key *unused*))
                       (not (eq? key *deleted*)))
              (proc key (vector-ref vec (fx+ i 1)))))
          (loop (fx+ i 2))))))

  (define (raw-table-copy tab)
    (make-raw-table-struct
      (vector-copy (rt-table tab))
      (rt-count tab)
      (rt-free tab)
      (rt-hash tab)
      (rt-test tab)
      (rt-seed tab)))

  (define (raw-table-clear! tab)
    (vector-fill! (rt-table tab) *unused*)
    (rt-count-set! tab 0)
    (rt-free-set! tab (fxdiv (vector-length (rt-table tab)) 2)))

  ;; --- Hash functions ---
  (define (symbolic? obj)
    (or (symbol? obj) (|##keyword?| obj)))

  (define (symbolic-hash obj)
    (cond
      ((symbol? obj)
       (fxand (symbol-hash obj) (greatest-fixnum)))
      ((|##keyword?| obj)
       (fxand (string-hash (|##keyword->string| obj)) (greatest-fixnum)))
      (else 0)))

  (define (eq-hash obj)
    (cond
      ((fixnum? obj) (fxand obj (greatest-fixnum)))
      ((char? obj) (fxand (char->integer obj) (greatest-fixnum)))
      ((symbol? obj) (fxand (symbol-hash obj) (greatest-fixnum)))
      ((boolean? obj) (if obj 1 0))
      (else (fxand (equal-hash obj) (greatest-fixnum)))))

  (define (eqv-hash obj)
    (cond
      ((fixnum? obj) (fxand obj (greatest-fixnum)))
      ((flonum? obj) (fxand (equal-hash obj) (greatest-fixnum)))
      ((number? obj) (fxand (equal-hash obj) (greatest-fixnum)))
      (else (eq-hash obj))))

  (define (string-hash obj)
    (fxand (equal-hash obj) (greatest-fixnum)))

  (define (immediate-hash obj)
    (cond
      ((fixnum? obj) obj)
      ((char? obj) (char->integer obj))
      ((boolean? obj) (if obj 1 0))
      (else 0)))

  (define (procedure-hash obj)
    (fxand (equal-hash obj) (greatest-fixnum)))

  ;; --- Specialized table constructors ---
  (define make-symbolic-table
    (case-lambda
      ((size-hint seed)
       (%make-raw-table size-hint symbolic-hash eq? seed))
      ((size-hint)
       (%make-raw-table size-hint symbolic-hash eq? 0))))

  (define (symbolic-table-ref tab key default)
    (raw-table-ref tab key default))
  (define (symbolic-table-set! tab key value)
    (raw-table-set! tab key value))
  (define (symbolic-table-update! tab key update default)
    (raw-table-update! tab key update default))
  (define (symbolic-table-delete! tab key)
    (raw-table-delete! tab key))
  (define (symbolic-table-for-each proc tab)
    (raw-table-for-each tab proc))
  (define (symbolic-table-length tab)
    (&raw-table-count tab))
  (define (symbolic-table-copy tab)
    (raw-table-copy tab))
  (define (symbolic-table-clear! tab)
    (raw-table-clear! tab))

  (define make-eq-table
    (case-lambda
      (() (%make-raw-table #f eq-hash eq? 0))
      ((size-hint) (%make-raw-table size-hint eq-hash eq? 0))
      ((size-hint seed) (%make-raw-table size-hint eq-hash eq? seed))))

  (define (eq-table-ref tab key default) (raw-table-ref tab key default))
  (define (eq-table-set! tab key value) (raw-table-set! tab key value))
  (define (eq-table-update! tab key update default) (raw-table-update! tab key update default))
  (define (eq-table-delete! tab key) (raw-table-delete! tab key))

  (define make-eqv-table
    (case-lambda
      (() (%make-raw-table #f eqv-hash eqv? 0))
      ((size-hint) (%make-raw-table size-hint eqv-hash eqv? 0))
      ((size-hint seed) (%make-raw-table size-hint eqv-hash eqv? seed))))

  (define (eqv-table-ref tab key default) (raw-table-ref tab key default))
  (define (eqv-table-set! tab key value) (raw-table-set! tab key value))
  (define (eqv-table-update! tab key update default) (raw-table-update! tab key update default))
  (define (eqv-table-delete! tab key) (raw-table-delete! tab key))

  (define make-string-table
    (case-lambda
      (() (%make-raw-table #f string-hash string=? 0))
      ((size-hint) (%make-raw-table size-hint string-hash string=? 0))
      ((size-hint seed) (%make-raw-table size-hint string-hash string=? seed))))

  (define (string-table-ref tab key default) (raw-table-ref tab key default))
  (define (string-table-set! tab key value) (raw-table-set! tab key value))
  (define (string-table-update! tab key update default) (raw-table-update! tab key update default))
  (define (string-table-delete! tab key) (raw-table-delete! tab key))

  (define make-immediate-table
    (case-lambda
      (() (%make-raw-table #f immediate-hash eq? 0))
      ((size-hint) (%make-raw-table size-hint immediate-hash eq? 0))
      ((size-hint seed) (%make-raw-table size-hint immediate-hash eq? seed))))

  (define (immediate-table-ref tab key default) (raw-table-ref tab key default))
  (define (immediate-table-set! tab key value) (raw-table-set! tab key value))
  (define (immediate-table-update! tab key update default) (raw-table-update! tab key update default))
  (define (immediate-table-delete! tab key) (raw-table-delete! tab key))

  ;; --- GC Tables (use Chez native eq-hashtable) ---
  ;; These use Chez's built-in eq-hashtable which handles GC rehashing internally.
  ;; We wrap them to provide the Gerbil API.

  (define make-gc-table
    (case-lambda
      (() (make-eq-hashtable 16))
      ((size-hint) (make-eq-hashtable (if (fixnum? size-hint) size-hint 16)))
      ((size-hint klass) (make-eq-hashtable (if (fixnum? size-hint) size-hint 16)))
      ((size-hint klass flags) (make-eq-hashtable (if (fixnum? size-hint) size-hint 16)))))

  (define gc-table-ref
    (case-lambda
      ((tab key default) (hashtable-ref tab key default))))

  (define (gc-table-set! tab key value)
    (hashtable-set! tab key value))

  (define (gc-table-update! tab key update default)
    (hashtable-update! tab key update default))

  (define (gc-table-delete! tab key)
    (hashtable-delete! tab key))

  (define (gc-table-for-each tab proc)
    (let-values (((keys vals) (hashtable-entries tab)))
      (let ((n (vector-length keys)))
        (let lp ((i 0))
          (when (fx< i n)
            (proc (vector-ref keys i) (vector-ref vals i))
            (lp (fx+ i 1)))))))

  (define (gc-table-copy tab)
    (hashtable-copy tab #t))

  (define (gc-table-clear! tab)
    (hashtable-clear! tab))

  (define (gc-table-length tab)
    (hashtable-size tab))

  ) ;; end library
