#!chezscheme
;;; gambit-compat.sls -- Gambit → Chez Scheme compatibility layer
;;;
;;; Maps Gambit's ## primitives to Chez equivalents.
;;; This is the foundation that all ported Gerbil code builds on.

(library (compat gambit-compat)
  (export
    ;; Special values
    void void? |%%void|
    absent-obj absent-obj? |%%absent|
    unbound-obj unbound-obj? |%%unbound|
    deleted-obj deleted-obj? |%%deleted|
    unused-obj unused-obj? |%%unused| |%%eof|

    ;; Fixnum operations (## → Chez fx)
    |##fx+| |##fx-| |##fx*| |##fx/| |##fxmodulo| |##fxremainder|
    |##fx<| |##fx>| |##fx=| |##fx>=| |##fx<=|
    |##fxand| |##fxior| |##fxxor| |##fxnot|
    |##fxarithmetic-shift| |##fxarithmetic-shift-left| |##fxarithmetic-shift-right|
    |##fxbit-count| |##fxlength| |##fxbit-set?| |##fxfirst-bit-set|
    |##fxabs| |##fxmin| |##fxmax|
    |##fixnum?| |##max-fixnum| |##min-fixnum| |##fx+?| |##fx-?|

    ;; Flonum operations
    |##flonum?| |##fl+| |##fl-| |##fl*| |##fl/| |##fl<| |##fl>| |##fl=| |##fl>=| |##fl<=|
    |##flabs| |##flfloor| |##flceiling| |##flround| |##fltruncate|
    |##flsqrt| |##flexpt| |##fllog| |##flexp| |##flsin| |##flcos| |##fltan|
    |##flasin| |##flacos| |##flatan|
    |##fixnum->flonum| |##flonum->fixnum|

    ;; Pair/list operations
    |##car| |##cdr| |##set-car!| |##set-cdr!| |##cons|
    |##pair?| |##null?|
    |##list| |##length| |##append| |##reverse|

    ;; Vector operations
    |##vector-ref| |##vector-set!| |##vector-length|
    |##vector-cas!|
    |##make-vector| |##vector?| |##vector-copy| |##vector->list| |##list->vector|
    |##subvector|

    ;; String operations
    |##string-ref| |##string-set!| |##string-length|
    |##make-string| |##string?| |##string-copy| |##string-append|
    |##string->list| |##list->string| |##substring|
    |##string=?| |##string<?| |##string-ci=?|
    |##string->number| |##number->string|
    |##string->symbol| |##symbol->string|
    |##string->keyword| |##keyword->string|

    ;; Char operations
    |##char?| |##char=?| |##char<?| |##char->integer| |##integer->char|
    |##char-alphabetic?| |##char-numeric?| |##char-whitespace?|
    |##char-upcase| |##char-downcase|

    ;; Symbol/keyword operations
    |##symbol?| |##keyword?|
    |##gensym| |##uninterned-symbol?| |##make-uninterned-symbol|

    ;; Boolean / type predicates
    |##boolean?| |##not| |##eq?| |##eqv?| |##equal?|
    |##number?| |##complex?| |##real?| |##rational?| |##integer?|
    |##exact?| |##inexact?|
    |##procedure?| |##port?| |##eof-object?| |##char?|

    ;; Arithmetic (generic)
    |##+| |##-| |##*| |##/| |##<| |##>| |##=| |##>=| |##<=|
    |##quotient| |##remainder| |##modulo|
    |##abs| |##min| |##max| |##gcd| |##lcm|
    |##expt| |##sqrt| |##floor| |##ceiling| |##round| |##truncate|
    |##exact->inexact| |##inexact->exact|
    |##zero?| |##positive?| |##negative?| |##odd?| |##even?|
    |##bitwise-and| |##bitwise-ior| |##bitwise-xor| |##bitwise-not|
    |##arithmetic-shift| |##bit-count| |##integer-length| |##bit-set?|

    ;; I/O
    |##read-char| |##write-char| |##peek-char|
    |##read-u8| |##write-u8|
    |##newline| |##display| |##write| |##pretty-print|
    |##open-input-file| |##open-output-file|
    |##close-input-port| |##close-output-port|
    |##input-port?| |##output-port?|
    |##current-input-port| |##current-output-port| |##current-error-port|
    |##port-name| |##read-line|
    |##open-input-string| |##open-output-string| |##get-output-string|
    |##eof-object|

    ;; Byte vectors (u8vector → bytevector)
    |##u8vector?| |##make-u8vector| |##u8vector-ref| |##u8vector-set!|
    |##u8vector-length| |##u8vector->list| |##list->u8vector|
    |##u8vector-copy| |##u8vector-copy!|
    u8vector? make-u8vector u8vector-ref u8vector-set!
    u8vector-length u8vector u8vector-append
    u8vector->list list->u8vector
    u8vector-copy u8vector-copy!
    u8vector-shrink! subu8vector

    ;; Box
    |##box| |##unbox| |##set-box!|
    |##box?| make-box box box? unbox set-box!

    ;; Will (weak references)
    |##make-will| |##will?| |##will-testator| |##will-execute!|

    ;; Hash tables (Gambit table → Chez hashtable)
    make-table table? table-ref table-set! table-delete!
    table->list table-for-each table-length table-copy
    table-merge table-merge!

    ;; Evaluation
    |##eval| |##apply|

    ;; Misc
    |##values| |##call-with-values|
    |##void|
    |##raise| |##with-exception-catcher| |##with-exception-handler|
    |##current-exception-handler|
    |##make-parameter| |##parameterize|
    |##dynamic-wind|
    |##error| |##error-object?| |##error-object-message| |##error-object-irritants|
    |##continuation?| |##continuation-capture| |##continuation-graft|
    |##continuation-return|
    |##object->serial-number|
    |##identity|
    |##time| |##cpu-time| |##real-time|

    ;; Gambit GC
    |##gc|

    ;; Property lists
    |##putprop| |##getprop| |##remprop|

    ;; Structure/type primitives — provided by (compat types)
    ;; Only extras not in types.sls:
    |##direct-structure-ref| |##direct-structure-set!|
    |##make-structure|
    |##type?| |##type-cast|
    |##subtype| |##subtyped?|

    ;; Additional primitives for runtime
    |##absent-object|
    |##cadr| |##memq| |##last-pair|
    |##closure?| |##mem-allocated?|
    |##keyword-hash| |##symbol-hash|
    keyword? keyword-hash
    string->keyword keyword->string
    uninterned-keyword?
    string->uninterned-keyword
    |##string| |##substring-move!|
    |##parameterize1|
    |##make-delay-promise| |##force-out-of-line|
    |##thread-yield!| |##thread-end-with-uncaught-exception!|
    |##primordial-exception-handler| |##primordial-thread|
    |##primordial-exception-handler-hook-set!|
    |##repl-exception-handler-hook|
    |##display-exception-hook-set!|
    |##default-display-exception|
    |##display-exception-in-context|
    |##repl| |##repl-within|
    |##continuation-next| |##continuation-last|
    |##write-string| |##read-subu8vector| |##write-subu8vector|
    |##u16vector-ref|
    |##stderr-port| |##stdin-port| |##stdout-port| |##console-port|
    |##file-exists?|
    |##current-time-point|
    |##values?| |##values-length| |##values-ref|
    |##script-marker|
    |##source?| |##source-code| |##source-locat| |##sourcify| |##make-source|
    |##locat?| |##locat-container|
    |##c-code|

    ;; Gambit runtime functions needed by compiled Gerbil code
    ;; Note: rename-file is NOT exported (conflicts with chezscheme)
    ;; Use gambit-rename-file if you need 3-arg version
    gambit-rename-file
    gambit-path-expand gambit-path-normalize
    gambit-create-symbolic-link
    gambit-file-info gambit-file-info-type gambit-file-info?
    make-condition-variable condition-variable-signal! condition-variable-broadcast!
    make-will will-testator will?
    configure-command-string system-version-string
    object->serial-number

    ;; Gambit macro-* constants and accessors
    macro-absent-obj macro-deleted-obj macro-unused-obj
    macro-max-fixnum32
    macro-gc-hash-table-flags
    macro-gc-hash-table-flag-need-rehash
    macro-gc-hash-table-flag-mem-alloc-keys
    macro-gc-hash-table-flag-weak-keys
    macro-gc-hash-table-count macro-gc-hash-table-count-set!
    macro-gc-hash-table-free macro-gc-hash-table-free-set!
    macro-gc-hash-table-size macro-gc-hash-table-key0
    macro-subtype-structure macro-subtype-boxvalues macro-subtype-vector
    macro-subtype-pair macro-subtype-ratnum macro-subtype-cpxnum
    macro-subtype-symbol macro-subtype-keyword macro-subtype-frame
    macro-subtype-continuation macro-subtype-promise macro-subtype-weak
    macro-subtype-procedure macro-subtype-return macro-subtype-foreign
    macro-subtype-string
    macro-subtype-s8vector macro-subtype-u8vector
    macro-subtype-s16vector macro-subtype-u16vector
    macro-subtype-s32vector macro-subtype-u32vector
    macro-subtype-f32vector
    macro-subtype-s64vector macro-subtype-u64vector
    macro-subtype-f64vector
    macro-subtype-flonum macro-subtype-bignum
    macro-type-fixnum macro-type-mem1 macro-type-mem2 macro-type-subtyped
    macro-type-table macro-type-time macro-type-mutex macro-type-condvar
    macro-type-thread macro-type-tgroup macro-type-port
    macro-type-object-port macro-type-character-port
    macro-type-byte-port macro-type-device-port macro-type-vector-port
    macro-type-string-port macro-type-u8vector-port
    macro-type-raw-device-port macro-type-tcp-server-port
    macro-type-udp-port macro-type-directory-port
    macro-type-event-queue-port
    macro-type-readenv macro-type-writeenv macro-type-readtable
    macro-type-processor macro-type-vm
    macro-type-file-info macro-type-socket-info macro-type-address-info
    macro-number-dispatch
    macro-ratnum-numerator macro-ratnum-denominator
    macro-cpxnum-real macro-cpxnum-imag
    macro-writeenv-style
    macro-readenv-port macro-readenv-filepos
    macro-readenv-script-line-set!
    macro-readtable-write-extended-read-macros?-set!
    macro-readtable-bracket-handler-set!
    macro-readtable-brace-handler-set!
    macro-exception?
    macro-character-port? macro-character-port-wchars
    macro-character-port-output-width macro-character-port-output-width-set!
    macro-mutex-lock! macro-mutex-unlock!
    macro-current-thread

    ;; GC hash table primitives
    |##gc-hash-table-allocate| |##gc-hash-table-ref| |##gc-hash-table-set!|
    |##gc-hash-table-rehash!| |##gc-hash-table-resize!|
    |##gc-hash-table-for-each|

    ;; Readtable / reader internals
    |##main-readtable-set!| |##make-standard-readtable|
    |##readtable-char-sharp-handler-set!| |##readtable-setup-for-language!|
    |##make-readenv| |##read-datum-or-eof|
    |##read-all-as-a-begin-expr-from-path| |##read-sharp-bang|
    |##read-line|

    ;; Eval/compile internals
    |##eval-top| |##load| |##interaction-cte|
    |##expand-source-set!| |##form-size|
    |##make-macro-descr| |##macro-descr| |##macro-descr-set!|
    |##default-user-interrupt-handler|
    |##set-parallelism-level!| |##startup-parallelism!|
    |##wr-set!|
    |##lambda|

    ;; Gambit threading API → Chez threading
    thread-sleep! make-thread thread-start! thread-join!
    thread-yield!

    ;; SMP stubs (Chez doesn't have Gambit's SMP model)
    |##set-parallelism-level!| |##startup-parallelism!|
    |##current-vm-processor-count|

    ;; Process statistics
    |##process-statistics|

    ;; f64vector (Gambit's native float64 vectors)
    f64vector-ref f64vector-set! make-f64vector f64vector-length

    ;; String/byte I/O (with-output-to-string re-exported from chezscheme)
    ;; string->bytes and bytes->string are in (runtime util)
    call-with-input-string call-with-output-string
    read-line
    write-subu8vector read-subu8vector/gambit

    ;; File & path operations (file-exists?, file-directory? re-exported from chezscheme)
    file-info file-info? file-info-type file-info-size
    file-info-device file-info-inode file-info-owner file-info-group
    file-info-mode file-info-last-modification-time file-info-last-access-time
    directory-files path-normalize path-expand
    output-port-byte-position

    ;; Process management
    open-process open-input-process process-status process-pid

    ;; Port operations (close-port is from chezscheme)
    force-output write-u8

    ;; Environment (getenv is from chezscheme)
    setenv get-environment-variables
    user-info user-info-home user-name

    ;; Time
    current-second time->seconds

    ;; Threading extras
    spawn thread-state
    thread-state-normally-terminated? thread-state-abnormally-terminated?

    ;; Numeric
    random-integer arithmetic-shift

    ;; Control flow
    let/cc

    ;; Misc
    pp with-exception-catcher tty-mode-set!
    |##cpu-count| |##set-gambitdir!|
    )

  (import (except (chezscheme)
            void                       ;; we define our own void
            box box? unbox set-box!    ;; we define our own box type
            )
          (rename (only (chezscheme) make-condition)
                  (make-condition chez:make-condition))
          (only (compat types) type-descriptor? gerbil-struct? gerbil-struct-field-vec
                               make-gerbil-struct gerbil-struct-type-tag))

  ;;;; Special values
  ;;;; Gambit uses unique objects for void, absent, etc.
  ;;;; We use Chez records for identity-based uniqueness.

  (define-record-type special-value
    (fields name)
    (sealed #t)
    (opaque #t))

  (define void-obj (make-special-value 'void))
  (define absent (make-special-value 'absent))
  (define unbound (make-special-value 'unbound))
  (define deleted (make-special-value 'deleted))
  (define unused (make-special-value 'unused))

  (define (void) void-obj)
  (define (void? x) (eq? x void-obj))
  ;; Internal names for special values, avoid recursion when compiled code redefines them
  (define (|%%void|) void-obj)
  (define (|%%eof|) (eof-object))
  (define (|%%absent|) absent)
  (define (|%%unbound|) unbound)
  (define (|%%deleted|) deleted)
  (define (|%%unused|) unused)
  (define (absent-obj) absent)
  (define (absent-obj? x) (eq? x absent))
  (define (unbound-obj) unbound)
  (define (unbound-obj? x) (eq? x unbound))
  (define (deleted-obj) deleted)
  (define (deleted-obj? x) (eq? x deleted))
  (define (unused-obj) unused)
  (define (unused-obj? x) (eq? x unused))

  ;;;; Fixnum operations

  (define |##fx+| fx+)
  (define |##fx-| fx-)
  (define |##fx*| fx*)
  (define (|##fx/| a b) (fxdiv a b))
  (define |##fxmodulo| fxmod)
  (define |##fxremainder| fxremainder)
  (define |##fx<| fx<)
  (define |##fx>| fx>)
  (define |##fx=| fx=)
  (define |##fx>=| fx>=)
  (define |##fx<=| fx<=)
  (define |##fxand| fxlogand)
  (define |##fxior| fxlogior)
  (define |##fxxor| fxlogxor)
  (define |##fxnot| fxlognot)
  (define |##fxarithmetic-shift| fxarithmetic-shift)
  (define |##fxarithmetic-shift-left| fxarithmetic-shift-left)
  (define |##fxarithmetic-shift-right| fxarithmetic-shift-right)
  (define |##fxbit-count| fxbit-count)
  (define |##fxlength| fxlength)
  (define |##fxbit-set?| fxbit-set?)
  (define |##fxfirst-bit-set| fxfirst-bit-set)
  (define (|##fxabs| x) (if (fx< x 0) (fx- 0 x) x))
  (define |##fxmin| fxmin)
  (define |##fxmax| fxmax)
  (define |##fixnum?| fixnum?)
  (define (|##max-fixnum|) (greatest-fixnum))
  (define (|##min-fixnum|) (least-fixnum))

  ;; |##fx+?| and |##fx-?| return #f on overflow instead of raising an error
  (define (|##fx+?| a b)
    (let ([r (+ a b)])
      (if (fixnum? r) r #f)))
  (define (|##fx-?| a b)
    (let ([r (- a b)])
      (if (fixnum? r) r #f)))

  ;;;; Flonum operations

  (define |##flonum?| flonum?)
  (define |##fl+| fl+)
  (define |##fl-| fl-)
  (define |##fl*| fl*)
  (define |##fl/| fl/)
  (define |##fl<| fl<)
  (define |##fl>| fl>)
  (define |##fl=| fl=)
  (define |##fl>=| fl>=)
  (define |##fl<=| fl<=)
  (define |##flabs| flabs)
  (define |##flfloor| flfloor)
  (define |##flceiling| flceiling)
  (define |##flround| flround)
  (define |##fltruncate| fltruncate)
  (define |##flsqrt| flsqrt)
  (define (|##flexpt| a b) (flexpt a b))
  (define |##fllog| fllog)
  (define |##flexp| flexp)
  (define |##flsin| flsin)
  (define |##flcos| flcos)
  (define |##fltan| fltan)
  (define |##flasin| flasin)
  (define |##flacos| flacos)
  (define |##flatan| flatan)
  (define |##fixnum->flonum| fixnum->flonum)
  (define |##flonum->fixnum| flonum->fixnum)

  ;;;; Pair/list operations

  (define |##car| car)
  (define |##cdr| cdr)
  (define |##set-car!| set-car!)
  (define |##set-cdr!| set-cdr!)
  (define |##cons| cons)
  (define |##pair?| pair?)
  (define |##null?| null?)
  (define |##list| list)
  (define |##length| length)
  (define |##append| append)
  (define |##reverse| reverse)

  ;;;; Vector operations

  (define |##vector-ref| vector-ref)
  (define |##vector-set!| vector-set!)
  (define |##vector-length| vector-length)
  ;; Gambit ##vector-cas! returns the OLD value (not boolean like Chez vector-cas!)
  ;; Args: (##vector-cas! vec idx old-val new-val) → old-value-at-idx
  (define (|##vector-cas!| vec idx old-val new-val)
    (let ([current (vector-ref vec idx)])
      (if (eq? current old-val)
        (begin (vector-set! vec idx new-val) old-val)
        current)))
  (define |##make-vector| make-vector)
  (define |##vector?| vector?)
  (define (|##vector-copy| v)
    (let* ([n (vector-length v)]
           [new (make-vector n)])
      (do ([i 0 (fx+ i 1)])
          ((fx= i n) new)
        (vector-set! new i (vector-ref v i)))))
  (define |##vector->list| vector->list)
  (define |##list->vector| list->vector)
  (define (|##subvector| v start end)
    (let* ([len (fx- end start)]
           [new (make-vector len)])
      (do ([i 0 (fx+ i 1)])
          ((fx= i len) new)
        (vector-set! new i (vector-ref v (fx+ start i))))))

  ;;;; String operations

  (define |##string-ref| string-ref)
  (define |##string-set!| string-set!)
  (define |##string-length| string-length)
  (define |##make-string| make-string)
  (define |##string?| string?)
  (define |##string-copy| string-copy)
  (define |##string-append| string-append)
  (define |##string->list| string->list)
  (define |##list->string| list->string)
  (define |##substring| substring)
  (define |##string=?| string=?)
  (define |##string<?| string<?)
  (define |##string-ci=?| string-ci=?)
  (define |##string->number| string->number)
  (define |##number->string| number->string)
  (define |##string->symbol| string->symbol)
  (define |##symbol->string| symbol->string)

  ;; Keywords: Gambit uses keyword objects; Chez doesn't have them natively.
  ;; We represent keywords as symbols with a trailing colon convention,
  ;; stored in a hashtable for identity.
  ;; This matches Gerbil's keyword representation.
  (define keyword-table (make-hashtable string-hash string=?))
  (define keyword-lock (make-mutex))

  (define-record-type keyword-object
    (fields name)
    (sealed #t))

  (define (|##keyword?| x)
    (keyword-object? x))

  (define (|##string->keyword| s)
    (mutex-acquire keyword-lock)
    (let ([existing (hashtable-ref keyword-table s #f)])
      (cond
        [existing
         (mutex-release keyword-lock)
         existing]
        [else
         (let ([kw (make-keyword-object s)])
           (hashtable-set! keyword-table s kw)
           (mutex-release keyword-lock)
           kw)])))

  (define (|##keyword->string| kw)
    (unless (keyword-object? kw)
      (error '|##keyword->string| "not a keyword" kw))
    (keyword-object-name kw))

  ;;;; Char operations

  (define |##char?| char?)
  (define |##char=?| char=?)
  (define |##char<?| char<?)
  (define |##char->integer| char->integer)
  (define |##integer->char| integer->char)
  (define |##char-alphabetic?| char-alphabetic?)
  (define |##char-numeric?| char-numeric?)
  (define |##char-whitespace?| char-whitespace?)
  (define |##char-upcase| char-upcase)
  (define |##char-downcase| char-downcase)

  ;;;; Symbol operations

  (define |##symbol?| symbol?)
  (define |##gensym| gensym)
  (define (|##uninterned-symbol?| s)
    (and (symbol? s) (gensym? s)))
  (define (|##make-uninterned-symbol| name)
    (gensym (if (symbol? name) (symbol->string name) name)))

  ;;;; Boolean / type predicates

  (define |##boolean?| boolean?)
  (define |##not| not)
  (define |##eq?| eq?)
  (define |##eqv?| eqv?)
  (define |##equal?| equal?)
  (define |##number?| number?)
  (define |##complex?| complex?)
  (define |##real?| real?)
  (define |##rational?| rational?)
  (define |##integer?| integer?)
  (define |##exact?| exact?)
  (define |##inexact?| inexact?)
  (define |##procedure?| procedure?)
  (define |##port?| port?)
  (define |##eof-object?| eof-object?)

  ;;;; Generic arithmetic

  (define |##+| +)
  (define |##-| -)
  (define |##*| *)
  (define |##/| /)
  (define |##<| <)
  (define |##>| >)
  (define |##=| =)
  (define |##>=| >=)
  (define |##<=| <=)
  (define |##quotient| quotient)
  (define |##remainder| remainder)
  (define |##modulo| modulo)
  (define |##abs| abs)
  (define |##min| min)
  (define |##max| max)
  (define |##gcd| gcd)
  (define |##lcm| lcm)
  (define |##expt| expt)
  (define |##sqrt| sqrt)
  (define |##floor| floor)
  (define |##ceiling| ceiling)
  (define |##round| round)
  (define |##truncate| truncate)
  (define |##exact->inexact| exact->inexact)
  (define |##inexact->exact| inexact->exact)
  (define |##zero?| zero?)
  (define |##positive?| positive?)
  (define |##negative?| negative?)
  (define |##odd?| odd?)
  (define |##even?| even?)
  (define |##bitwise-and| logand)
  (define |##bitwise-ior| logior)
  (define |##bitwise-xor| logxor)
  (define |##bitwise-not| lognot)
  (define |##arithmetic-shift| ash)
  (define |##bit-count| fxbit-count)
  (define |##integer-length| integer-length)
  (define |##bit-set?| fxbit-set?)

  ;;;; I/O

  (define |##read-char| read-char)
  (define |##write-char| write-char)
  (define |##peek-char| peek-char)
  (define |##read-u8| get-u8)
  (define |##write-u8| put-u8)
  (define |##newline| newline)
  (define |##display| display)
  (define |##write| write)
  (define |##pretty-print| pretty-print)
  (define |##open-input-file| open-input-file)
  (define |##open-output-file| open-output-file)
  (define |##close-input-port| close-input-port)
  (define |##close-output-port| close-output-port)
  (define |##input-port?| input-port?)
  (define |##output-port?| output-port?)
  (define |##current-input-port| current-input-port)
  (define |##current-output-port| current-output-port)
  (define |##current-error-port| current-error-port)
  (define (|##port-name| p)
    (cond
      [(input-port? p) (port-name p)]
      [(output-port? p) (port-name p)]
      [else "<unknown>"]))
  (define |##read-line|
    (case-lambda
      [() (get-line (current-input-port))]
      [(p) (get-line p)]))
  (define |##open-input-string| open-input-string)
  (define |##open-output-string| open-output-string)
  (define |##get-output-string| get-output-string)
  (define (|##eof-object|) (eof-object))

  ;;;; Byte vectors (u8vector → bytevector)
  ;;;; Gambit's u8vector is Chez's bytevector

  (define u8vector? bytevector?)
  (define |##u8vector?| bytevector?)
  (define make-u8vector make-bytevector)
  (define |##make-u8vector| make-bytevector)
  (define u8vector-ref bytevector-u8-ref)
  (define |##u8vector-ref| bytevector-u8-ref)
  (define u8vector-set! bytevector-u8-set!)
  (define |##u8vector-set!| bytevector-u8-set!)
  (define u8vector-length bytevector-length)
  (define |##u8vector-length| bytevector-length)

  (define (u8vector . args)
    (let ([bv (make-bytevector (length args))])
      (let loop ([i 0] [args args])
        (if (null? args) bv
            (begin
              (bytevector-u8-set! bv i (car args))
              (loop (fx+ i 1) (cdr args)))))))

  (define (u8vector-append . bvs)
    (let* ([total (apply + (map bytevector-length bvs))]
           [result (make-bytevector total)])
      (let loop ([bvs bvs] [offset 0])
        (if (null? bvs) result
            (let ([bv (car bvs)]
                  [len (bytevector-length (car bvs))])
              (bytevector-copy! bv 0 result offset len)
              (loop (cdr bvs) (+ offset len)))))))

  (define (u8vector->list bv)
    (let loop ([i (fx- (bytevector-length bv) 1)] [acc '()])
      (if (fx< i 0) acc
          (loop (fx- i 1) (cons (bytevector-u8-ref bv i) acc)))))
  (define |##u8vector->list| u8vector->list)

  (define (list->u8vector lst)
    (let ([bv (make-bytevector (length lst))])
      (let loop ([i 0] [lst lst])
        (if (null? lst) bv
            (begin
              (bytevector-u8-set! bv i (car lst))
              (loop (fx+ i 1) (cdr lst)))))))
  (define |##list->u8vector| list->u8vector)

  (define (u8vector-copy bv . args)
    (if (null? args)
        (bytevector-copy bv)
        (let ([start (car args)]
              [end (if (null? (cdr args))
                       (bytevector-length bv)
                       (cadr args))])
          (let ([result (make-bytevector (- end start))])
            (bytevector-copy! bv start result 0 (- end start))
            result))))
  (define |##u8vector-copy| u8vector-copy)

  (define (u8vector-copy! src src-start dst dst-start count)
    (bytevector-copy! src src-start dst dst-start count))
  (define |##u8vector-copy!| u8vector-copy!)

  (define (u8vector-shrink! bv len)
    ;; Chez doesn't support in-place shrink; return a copy
    (let ([result (make-bytevector len)])
      (bytevector-copy! bv 0 result 0 len)
      result))

  (define (subu8vector bv start end)
    (let ([result (make-bytevector (- end start))])
      (bytevector-copy! bv start result 0 (- end start))
      result))

  ;;;; Box

  (define-record-type box-type
    (fields (mutable value))
    (sealed #t))

  (define (make-box val) (make-box-type val))
  (define (box val) (make-box-type val))
  (define |##box| box)
  (define (box? x) (box-type? x))
  (define |##box?| box?)
  (define (unbox b) (box-type-value b))
  (define |##unbox| unbox)
  (define (set-box! b v) (box-type-value-set! b v))
  (define |##set-box!| set-box!)

  ;;;; Will (weak references / guardians)

  (define (|##make-will| obj action)
    (let ([g (make-guardian)])
      (g obj)
      (cons g action)))

  (define (|##will?| x)
    (and (pair? x) (guardian? (car x))))

  (define (|##will-testator| w)
    ;; Try to get the object from the guardian
    (let ([obj ((car w))])
      (if obj obj
          (error '|##will-testator| "will already executed"))))

  (define (|##will-execute!| w)
    (let ([obj ((car w))])
      (when obj
        ((cdr w) obj))))

  ;;;; Hash tables (Gambit table → Chez hashtable)

  ;; Gambit's make-table uses keyword arguments. We support the common cases.
  (define make-table
    (case-lambda
      [() (make-hashtable equal-hash equal?)]
      [(args)
       ;; Support keyword-style arguments passed as a list
       (make-hashtable equal-hash equal?)]))

  (define (table? x) (hashtable? x))

  (define table-ref
    (case-lambda
      [(t k) (hashtable-ref t k (void))]
      [(t k default) (hashtable-ref t k default)]))

  (define (table-set! t k v) (hashtable-set! t k v))
  (define (table-delete! t k) (hashtable-delete! t k))

  (define (table->list t)
    (let-values ([(keys vals) (hashtable-entries t)])
      (let loop ([i (fx- (vector-length keys) 1)] [acc '()])
        (if (fx< i 0) acc
            (loop (fx- i 1)
                  (cons (cons (vector-ref keys i) (vector-ref vals i)) acc))))))

  (define (table-for-each proc t)
    (let-values ([(keys vals) (hashtable-entries t)])
      (do ([i 0 (fx+ i 1)])
          ((fx= i (vector-length keys)))
        (proc (vector-ref keys i) (vector-ref vals i)))))

  (define (table-length t) (hashtable-size t))

  (define (table-copy t)
    (hashtable-copy t #t))

  (define (table-merge t1 t2)
    (let ([result (hashtable-copy t1 #t)])
      (table-for-each (lambda (k v) (hashtable-set! result k v)) t2)
      result))

  (define (table-merge! t1 t2)
    (table-for-each (lambda (k v) (hashtable-set! t1 k v)) t2)
    t1)

  ;;;; Evaluation

  (define |##eval| eval)
  (define |##apply| apply)

  ;;;; Misc

  (define |##values| values)
  (define |##call-with-values| call-with-values)
  (define (|##void|) void-obj)

  (define |##raise| raise)

  (define (|##with-exception-catcher| handler thunk)
    (guard (exn [#t (handler exn)])
      (thunk)))

  (define |##with-exception-handler| with-exception-handler)

  (define |##current-exception-handler|
    (make-parameter
      (lambda (exn)
        (display "unhandled exception: " (current-error-port))
        (display exn (current-error-port))
        (newline (current-error-port)))))

  (define |##make-parameter| make-parameter)

  (define-syntax |##parameterize|
    (syntax-rules ()
      [(_ ((p v) ...) body ...)
       (parameterize ((p v) ...) body ...)]))

  (define |##dynamic-wind| dynamic-wind)

  (define |##error| error)

  (define (|##error-object?| x)
    (or (condition? x)
        (error? x)
        (message-condition? x)))

  (define (|##error-object-message| x)
    (if (message-condition? x)
        (condition-message x)
        (format "~a" x)))

  (define (|##error-object-irritants| x)
    (if (irritants-condition? x)
        (condition-irritants x)
        '()))

  ;;;; Continuations

  (define (|##continuation?| x)
    (procedure? x))

  (define (|##continuation-capture| proc)
    (call/cc (lambda (k) (proc k))))

  (define (|##continuation-graft| k thunk)
    ;; Chez doesn't have graft directly; we abort to k with thunk's result
    (k (thunk)))

  (define (|##continuation-return| k . vals)
    (apply k vals))

  ;; ##structure-copy is provided by (compat types)
  ;; Re-exported here for convenience but not defined.

  ;;;; Serial numbers (Chez doesn't have this; use eq-hashtable)
  (define serial-number-table (make-eq-hashtable))
  (define serial-number-counter 0)
  (define serial-number-lock (make-mutex))

  (define (|##object->serial-number| obj)
    (let ([existing (hashtable-ref serial-number-table obj #f)])
      (or existing
          (begin
            (mutex-acquire serial-number-lock)
            (let ([existing (hashtable-ref serial-number-table obj #f)])
              (cond
                [existing
                 (mutex-release serial-number-lock)
                 existing]
                [else
                 (set! serial-number-counter (+ serial-number-counter 1))
                 (let ([n serial-number-counter])
                   (hashtable-set! serial-number-table obj n)
                   (mutex-release serial-number-lock)
                   n)]))))))

  ;;;; Identity
  (define (|##identity| x) x)

  ;;;; Timing
  (define (|##time| thunk)
    (time (thunk)))

  (define (|##cpu-time|)
    (let ([t (current-time 'time-thread)])
      (+ (* (time-second t) 1000)
         (quotient (time-nanosecond t) 1000000))))

  (define (|##real-time|)
    (let ([t (current-time 'time-monotonic)])
      (+ (* (time-second t) 1000)
         (quotient (time-nanosecond t) 1000000))))

  ;;;; GC
  (define (|##gc|) (collect))

  ;;;; Property lists
  (define |##putprop| putprop)
  (define |##getprop| getprop)
  (define |##remprop| remprop)

  ;;;; Gambit threading API → Chez threading
  ;;;; Gambit uses SRFI-18 style: make-thread, thread-start!, thread-join!
  ;;;; Chez uses: fork-thread, mutex, condition
  ;;;; We bridge the gap with a simple thread record.

  (define-record-type gambit-thread
    (fields thunk (mutable result) (mutable done?) mutex condvar)
    (protocol
      (lambda (new)
        (lambda (thunk)
          (new thunk (void) #f (make-mutex) (make-condition))))))

  (define (make-thread thunk . name)
    (make-gambit-thread thunk))

  (define (thread-start! t)
    (fork-thread
      (lambda ()
        (let ((result (guard (e [#t e])
                        ((gambit-thread-thunk t)))))
          (gambit-thread-result-set! t result)
          (mutex-acquire (gambit-thread-mutex t))
          (gambit-thread-done?-set! t #t)
          (condition-broadcast (gambit-thread-condvar t))
          (mutex-release (gambit-thread-mutex t)))))
    t)

  (define (thread-join! t)
    (mutex-acquire (gambit-thread-mutex t))
    (let lp ()
      (unless (gambit-thread-done? t)
        (condition-wait (gambit-thread-condvar t) (gambit-thread-mutex t))
        (lp)))
    (mutex-release (gambit-thread-mutex t))
    (gambit-thread-result t))

  (define (thread-sleep! seconds)
    ;; Chez's sleep takes a time duration
    (let ((ns (inexact->exact (round (* seconds 1000000000)))))
      (sleep (make-time 'time-duration ns 0))))

  (define (thread-yield!)
    ;; No direct equivalent; sleep briefly
    (sleep (make-time 'time-duration 0 0)))

  ;;;; SMP support
  ;;;; Chez Scheme has full SMP with pthreads — expose real CPU count
  ;;;; and let callers scale parallelism accordingly.

  ;; Cache the CPU count at load time (reading /proc is cheap but no need to repeat)
  (define *cpu-count*
    (guard (exn [#t 1])
      (let ([p (open-input-file "/proc/cpuinfo")])
        (let loop ([count 0])
          (let ([line (get-line p)])
            (if (eof-object? line)
              (begin (close-input-port p) (max 1 count))
              (loop (if (and (>= (string-length line) 9)
                             (string=? (substring line 0 9) "processor"))
                     (+ count 1) count))))))))

  (define (|##set-parallelism-level!| n) (void))
  (define (|##startup-parallelism!|) (void))
  (define (|##current-vm-processor-count|) *cpu-count*)

  ;;;; Process statistics
  ;;;; Gambit's ##process-statistics returns an f64vector:
  ;;;;   [0] = user time, [1] = system time, [2] = real/wall time,
  ;;;;   [3] = gc user time, [4] = gc system time, [5] = gc real time,
  ;;;;   [6] = nb GCs, [7] = bytes allocated, ...
  ;;;; We approximate using Chez's (current-time).
  (define (|##process-statistics|)
    (let* ((wall (current-time 'time-monotonic))
           (cpu  (current-time 'time-thread))
           (wall-secs (+ (time-second wall)
                         (/ (time-nanosecond wall) 1000000000.0)))
           (cpu-secs  (+ (time-second cpu)
                         (/ (time-nanosecond cpu) 1000000000.0))))
      ;; Return as a regular vector; f64vector-ref works on it via our stubs
      (let ((v (make-f64vector 8 0.0)))
        (f64vector-set! v 0 cpu-secs)     ;; user time
        (f64vector-set! v 1 0.0)          ;; system time
        (f64vector-set! v 2 wall-secs)    ;; wall time
        v)))

  ;;;; f64vector (Gambit's native float64 vectors)
  ;;;; Implemented on top of Chez bytevectors with IEEE double precision.
  (define (make-f64vector n . rest)
    (let ((bv (make-bytevector (* n 8) 0)))
      (when (pair? rest)
        (let ((fill (car rest)))
          (do ((i 0 (fx+ i 1)))
              ((fx= i n))
            (bytevector-ieee-double-native-set! bv (* i 8) (inexact fill)))))
      bv))

  (define (f64vector-ref bv i)
    (bytevector-ieee-double-native-ref bv (* i 8)))

  (define (f64vector-set! bv i val)
    (bytevector-ieee-double-native-set! bv (* i 8) (inexact val)))

  (define (f64vector-length bv)
    (fx/ (bytevector-length bv) 8))

  ;;;; ==================================================================
  ;;;; Structure/Type system extras
  ;;;; Most structure/type ops are in (compat types). Only extras here.
  ;;;; ==================================================================

  ;; ##direct-structure-ref/set! — same semantics as unchecked variants
  (define (|##direct-structure-ref| obj i type proc)
    (vector-ref obj (+ i 1)))

  (define (|##direct-structure-set!| obj val i type proc)
    (vector-set! obj (+ i 1) val))

  ;; ##make-structure — create structure with type and n fields
  ;; Must create gerbil-struct records (same as ##structure) for consistency.
  (define (|##make-structure| type-desc n . fill)
    (let* ([f (if (null? fill) 0 (car fill))]
           [v (make-vector n f)])
      (make-gerbil-struct type-desc v)))

  ;; ##type? — check if obj is a type descriptor
  ;; Recognizes gerbil-struct type descriptors (both basic 5-field and full 11-field)
  ;; and old vector-based types
  (define (|##type?| obj)
    (or (type-descriptor? obj)
        (and (gerbil-struct? obj)
             (let ([fv (gerbil-struct-field-vec obj)])
               (and (vector? fv)
                    (>= (vector-length fv) 5)
                    (symbol? (vector-ref fv 0))))) ;; id field
        (and (vector? obj)
             (>= (vector-length obj) 6)
             (getprop obj 'gherkin-instance))))

  (define (|##type-cast| obj type) obj) ;; no-op for Chez

  (define (|##subtype| obj) 0)    ;; Gambit internal tag — stub
  (define (|##subtyped?| obj)     ;; everything except fixnum/char/special
    (or (vector? obj) (string? obj) (pair? obj) (symbol? obj)
        (bytevector? obj) (procedure? obj) (port? obj)))

  ;;;; Additional list/pair primitives
  (define (|##cadr| x) (cadr x))
  (define (|##memq| obj lst) (memq obj lst))
  (define (|##last-pair| lst)
    (if (pair? (cdr lst))
        (|##last-pair| (cdr lst))
        lst))

  ;;;; Closures and allocation
  (define (|##closure?| obj) (procedure? obj))
  (define (|##mem-allocated?| obj)
    (not (or (fixnum? obj) (char? obj) (boolean? obj) (null? obj)
             (eq? obj void-obj))))

  ;;;; Keyword and symbol hashing
  (define (|##keyword-hash| kw)
    (if (keyword-object? kw)
        (string-hash (keyword-object-name kw))
        (equal-hash kw)))

  ;; ##symbol-hash must handle keyword objects too (used by symbolic-hash in table.ss)
  (define (|##symbol-hash| obj)
    (if (|##keyword?| obj)
      (symbol-hash (string->symbol (|##keyword->string| obj)))
      (symbol-hash obj)))

  ;; Bare keyword/symbol functions for Gerbil runtime
  (define keyword? |##keyword?|)
  (define keyword-hash |##keyword-hash|)
  (define string->keyword |##string->keyword|)
  (define keyword->string |##keyword->string|)
  (define (uninterned-keyword? x) #f)  ;; Chez doesn't have uninterned keywords
  (define (string->uninterned-keyword s) (|##string->keyword| s))

  ;;;; String constructors
  (define (|##string| . chars) (apply string chars))

  (define (|##substring-move!| src src-start src-end dst dst-start)
    ;; Gambit: copy src[src-start..src-end) → dst[dst-start..]
    (let ([len (- src-end src-start)])
      (do ([i 0 (fx+ i 1)])
          ((fx= i len))
        (string-set! dst (+ dst-start i) (string-ref src (+ src-start i))))))

  ;;;; Parameterize (single binding, Gambit fast path)
  (define (|##parameterize1| param val thunk)
    (parameterize ([param val]) (thunk)))

  ;;;; Promises
  (define (|##make-delay-promise| thunk)
    (delay (thunk)))

  (define (|##force-out-of-line| promise)
    (force promise))

  ;;;; Thread extras
  (define (|##thread-yield!|) (thread-yield!))

  (define (|##thread-end-with-uncaught-exception!| exn)
    ;; In Chez, just raise the exception
    (raise exn))

  (define |##primordial-exception-handler|
    (make-parameter
      (lambda (exn)
        (display "unhandled exception: " (current-error-port))
        (write exn (current-error-port))
        (newline (current-error-port)))))

  (define |##primordial-thread| #f) ;; Chez doesn't have a primordial thread object

  (define (|##primordial-exception-handler-hook-set!| proc)
    ;; Install as base exception handler
    (void))

  (define |##repl-exception-handler-hook|
    (make-parameter
      (lambda (exn k)
        (display "exception: " (current-error-port))
        (write exn (current-error-port))
        (newline (current-error-port)))))

  (define (|##display-exception-hook-set!| proc) (void))

  (define (|##default-display-exception| exn port)
    (display "Exception: " port)
    (write exn port)
    (newline port))

  (define (|##display-exception-in-context| exn cont port)
    (|##default-display-exception| exn port))

  ;;;; REPL
  (define |##repl|
    (case-lambda
      [() (void)]
      [(write-reason) (void)]))

  (define (|##repl-within| cont write-reason)
    (void))

  ;;;; Continuation extras
  (define (|##continuation-next| cont)
    ;; No direct equivalent in Chez; return #f
    #f)

  (define (|##continuation-last| cont)
    cont)

  ;;;; I/O extras
  (define (|##write-string| str port)
    (display str port))

  (define (|##read-subu8vector| bv start end port . need)
    ;; Read bytes into bytevector; return count read
    (let loop ([i start] [count 0])
      (if (>= i end) count
          (let ([b (get-u8 port)])
            (if (eof-object? b) count
                (begin
                  (bytevector-u8-set! bv i b)
                  (loop (+ i 1) (+ count 1))))))))

  (define (|##write-subu8vector| bv start end port)
    (do ([i start (fx+ i 1)])
        ((fx= i end))
      (put-u8 port (bytevector-u8-ref bv i))))

  (define (|##u16vector-ref| bv i)
    ;; Read as native-endian u16 from bytevector
    (bytevector-u16-native-ref bv (* i 2)))

  ;;;; Standard ports
  (define (|##stderr-port|) (current-error-port))
  (define (|##stdin-port|) (current-input-port))
  (define (|##stdout-port|) (current-output-port))
  (define (|##console-port|) (current-error-port))

  ;;;; File operations
  (define (|##file-exists?| path)
    (file-exists? path))

  ;;;; Time
  (define (|##current-time-point|)
    (let ([t (current-time 'time-monotonic)])
      (+ (time-second t)
         (/ (time-nanosecond t) 1000000000.0))))

  ;;;; Values introspection
  ;; Gambit can inspect multiple-values objects.
  ;; Chez doesn't expose these directly. We approximate.
  (define (|##values?| obj) #f)    ;; values objects don't exist as first-class in Chez
  (define (|##values-length| obj) 1)
  (define (|##values-ref| obj i) obj)

  ;;;; Script marker
  (define |##script-marker| (gensym "script-marker"))

  ;;;; Source objects (Gambit source tracking)
  ;; Gambit wraps datums with source info: (##make-source datum locat)
  (define-record-type gambit-source
    (fields code locat)
    (sealed #t))

  (define (|##source?| obj) (gambit-source? obj))
  (define (|##source-code| src) (gambit-source-code src))
  (define (|##source-locat| src) (gambit-source-locat src))
  (define (|##sourcify| datum locat) (make-gambit-source datum locat))
  (define (|##make-source| datum locat) (make-gambit-source datum locat))

  ;;;; Location objects
  (define-record-type gambit-locat
    (fields container position)
    (sealed #t))

  (define (|##locat?| obj) (gambit-locat? obj))
  (define (|##locat-container| loc) (gambit-locat-container loc))

  ;;;; C code — no-op on Chez
  (define-syntax |##c-code|
    (syntax-rules ()
      [(_ args ...) (void)]))

  ;;;; Absent object
  (define (|##absent-object|) absent)

  ;;;; ==================================================================
  ;;;; Gambit macro-* constants and accessors
  ;;;; These are internal type tags and accessors. Many are used by the
  ;;;; MOP and hash table code. We define them as constants/functions.
  ;;;; ==================================================================

  (define (macro-absent-obj) absent)
  (define (macro-deleted-obj) deleted)
  (define (macro-unused-obj) unused)
  (define (macro-max-fixnum32) #x7fffffff)

  ;; GC hash table flags — used by table.ss
  ;; These are bitmask values from Gambit's internals
  ;; Defined as thunks because Gambit uses them as macros: (macro-x) → value
  (define (macro-gc-hash-table-flags ht) (vector-ref ht 3))
  (define (macro-gc-hash-table-flag-need-rehash) 1)
  (define (macro-gc-hash-table-flag-mem-alloc-keys) 2)
  (define (macro-gc-hash-table-flag-weak-keys) 4)

  ;; GC hash table layout accessors
  ;; In Gambit, GC hash tables are special vectors with metadata at fixed indices
  (define (macro-gc-hash-table-count ht) (vector-ref ht 1))
  (define (macro-gc-hash-table-count-set! ht v) (vector-set! ht 1 v))
  (define (macro-gc-hash-table-free ht) (vector-ref ht 2))
  (define (macro-gc-hash-table-free-set! ht v) (vector-set! ht 2 v))
  (define (macro-gc-hash-table-size) 5)  ;; metadata slots before key/val pairs
  (define (macro-gc-hash-table-key0) 5)  ;; first key slot index

  ;; Subtype tags — arbitrary unique integers
  ;; Defined as thunks because Gambit uses them as macros: (macro-x) → value
  (define (macro-subtype-structure) 1)
  (define (macro-subtype-boxvalues) 2)
  (define (macro-subtype-vector) 3)
  (define (macro-subtype-pair) 4)
  (define (macro-subtype-ratnum) 5)
  (define (macro-subtype-cpxnum) 6)
  (define (macro-subtype-symbol) 7)
  (define (macro-subtype-keyword) 8)
  (define (macro-subtype-frame) 9)
  (define (macro-subtype-continuation) 10)
  (define (macro-subtype-promise) 11)
  (define (macro-subtype-weak) 12)
  (define (macro-subtype-procedure) 13)
  (define (macro-subtype-return) 14)
  (define (macro-subtype-foreign) 15)
  (define (macro-subtype-string) 16)
  (define (macro-subtype-s8vector) 17)
  (define (macro-subtype-u8vector) 18)
  (define (macro-subtype-s16vector) 19)
  (define (macro-subtype-u16vector) 20)
  (define (macro-subtype-s32vector) 21)
  (define (macro-subtype-u32vector) 22)
  (define (macro-subtype-f32vector) 23)
  (define (macro-subtype-s64vector) 24)
  (define (macro-subtype-u64vector) 25)
  (define (macro-subtype-f64vector) 26)
  (define (macro-subtype-flonum) 27)
  (define (macro-subtype-bignum) 28)

  ;; Type tags
  (define (macro-type-fixnum) 0)
  (define (macro-type-mem1) 1)
  (define (macro-type-mem2) 2)
  (define (macro-type-subtyped) 3)
  (define (macro-type-table) 30)
  (define (macro-type-time) 31)
  (define (macro-type-mutex) 32)
  (define (macro-type-condvar) 33)
  (define (macro-type-thread) 34)
  (define (macro-type-tgroup) 35)
  (define (macro-type-port) 36)
  (define (macro-type-object-port) 37)
  (define (macro-type-character-port) 38)
  (define (macro-type-byte-port) 39)
  (define (macro-type-device-port) 40)
  (define (macro-type-vector-port) 41)
  (define (macro-type-string-port) 42)
  (define (macro-type-u8vector-port) 43)
  (define (macro-type-raw-device-port) 44)
  (define (macro-type-tcp-server-port) 45)
  (define (macro-type-udp-port) 46)
  (define (macro-type-directory-port) 47)
  (define (macro-type-event-queue-port) 48)
  (define (macro-type-readenv) 49)
  (define (macro-type-writeenv) 50)
  (define (macro-type-readtable) 51)
  (define (macro-type-processor) 52)
  (define (macro-type-vm) 53)
  (define (macro-type-file-info) 54)
  (define (macro-type-socket-info) 55)
  (define (macro-type-address-info) 56)

  ;; Number dispatch macro — Gambit uses this for optimized numeric dispatch
  (define-syntax macro-number-dispatch
    (syntax-rules ()
      [(_ num err fixnum bignum ratnum flonum cpxnum)
       (cond
         [(fixnum? num) fixnum]
         [(flonum? num) flonum]
         [(bignum? num) bignum]
         [(ratnum? num) ratnum]
         [else cpxnum])]))

  ;; Rational/complex accessors
  (define (macro-ratnum-numerator x) (numerator x))
  (define (macro-ratnum-denominator x) (denominator x))
  (define (macro-cpxnum-real x) (real-part x))
  (define (macro-cpxnum-imag x) (imag-part x))

  ;; Write environment style
  (define (macro-writeenv-style wenv) 'write)

  ;; Read environment
  (define (macro-readenv-port renv) (current-input-port))
  (define (macro-readenv-filepos renv) 0)
  (define (macro-readenv-script-line-set! renv val) (void))

  ;; Readtable
  (define (macro-readtable-write-extended-read-macros?-set! rt val) (void))
  (define (macro-readtable-bracket-handler-set! rt handler) (void))
  (define (macro-readtable-brace-handler-set! rt handler) (void))

  ;; Exception
  (define (macro-exception? obj)
    (or (condition? obj) (error? obj)))

  ;; Character port
  (define (macro-character-port? p) (textual-port? p))
  (define (macro-character-port-wchars p) 0)
  (define (macro-character-port-output-width p) 80)
  (define (macro-character-port-output-width-set! p w) (void))

  ;; Mutex (Chez's mutex-acquire/mutex-release)
  (define macro-mutex-lock! mutex-acquire)
  (define macro-mutex-unlock! mutex-release)

  ;; Current thread — Chez doesn't expose thread identity easily
  (define (macro-current-thread) #f)

  ;;;; ==================================================================
  ;;;; GC hash table primitives
  ;;;; Gambit has internal GC-aware hash tables. We implement them using
  ;;;; Chez eq-hashtables wrapped in a vector for metadata compatibility.
  ;;;; ==================================================================

  ;; GC hash table = vector: [ht-ref, count, free, flags, ht-object]
  (define (|##gc-hash-table-allocate| size flags loads)
    (let ([v (make-vector (+ (macro-gc-hash-table-key0) (* size 2)) (void))])
      (vector-set! v 0 'gc-hash-table)
      (vector-set! v 1 0)    ;; count
      (vector-set! v 2 size) ;; free
      (vector-set! v 3 flags)
      (vector-set! v 4 (make-eq-hashtable size)) ;; actual Chez hashtable
      v))

  (define (|##gc-hash-table-ref| ht key)
    (let ([real-ht (vector-ref ht 4)])
      (hashtable-ref real-ht key (void))))

  (define (|##gc-hash-table-set!| ht key val)
    (let ([real-ht (vector-ref ht 4)])
      (hashtable-set! real-ht key val)
      (vector-set! ht 1 (hashtable-size real-ht))))

  (define (|##gc-hash-table-rehash!| ht) (void)) ;; Chez handles this internally

  (define (|##gc-hash-table-resize!| ht new-size)
    ;; Chez handles resizing internally, but we can recreate if needed
    ht)

  (define (|##gc-hash-table-for-each| ht proc)
    (let ([real-ht (vector-ref ht 4)])
      (let-values ([(keys vals) (hashtable-entries real-ht)])
        (do ([i 0 (fx+ i 1)])
            ((fx= i (vector-length keys)))
          (proc (vector-ref keys i) (vector-ref vals i))))))

  ;;;; ==================================================================
  ;;;; Readtable / reader internals — stubs
  ;;;; The Gerbil reader has its own implementation; these are stubs
  ;;;; for code that references Gambit's reader internals.
  ;;;; ==================================================================

  (define (|##main-readtable-set!| rt) (void))
  (define (|##make-standard-readtable|) (void))
  (define (|##readtable-char-sharp-handler-set!| rt ch handler) (void))
  (define (|##readtable-setup-for-language!| rt . args) (void))
  (define (|##make-readenv| port readtable wrapper closer) (void))
  (define (|##read-datum-or-eof| renv) (read))
  (define (|##read-all-as-a-begin-expr-from-path| path readtable wrapper closer)
    (call-with-input-file path
      (lambda (port)
        (let loop ([forms '()])
          (let ([datum (read port)])
            (if (eof-object? datum)
                (cons 'begin (reverse forms))
                (loop (cons datum forms))))))))
  (define (|##read-sharp-bang| renv next start-pos) (void))
  ;; ##read-line already covered by |##read-line| above

  ;;;; ==================================================================
  ;;;; Eval/compile internals — stubs
  ;;;; ==================================================================

  (define (|##eval-top| source cte) (eval source))
  (define (|##load| path) (load path))
  (define |##interaction-cte| (make-parameter #f))
  (define (|##expand-source-set!| proc) (void))
  (define (|##form-size| form) 1)
  (define (|##make-macro-descr| def-syntax? expander) (cons def-syntax? expander))
  (define (|##macro-descr| m) m)
  (define (|##macro-descr-set!| m d) (void))
  (define (|##default-user-interrupt-handler|) (void))
  (define (|##wr-set!| handler) (void))
  (define-syntax |##lambda|
    (syntax-rules ()
      [(_ args body ...) (lambda args body ...)]))

  ;;;; File/path operations (Gambit compatibility)

  ;; rename-file: Gambit takes optional replace? arg, Chez takes 2
  (define gambit-rename-file
    (case-lambda
      [(old new) (rename-file old new)]
      [(old new replace?)
       (when (and replace? (file-exists? new))
         (delete-file new))
       (rename-file old new)]))

  ;; Path operations
  (define (gambit-path-expand path . rest)
    (if (null? rest)
      (if (and (> (string-length path) 0)
               (char=? (string-ref path 0) #\~))
        (string-append (getenv "HOME") (substring path 1 (string-length path)))
        path)
      ;; (path-expand path base)
      (let ([base (car rest)])
        (if (and (> (string-length path) 0)
                 (char=? (string-ref path 0) #\/))
          path
          (string-append base "/" path)))))

  (define (gambit-path-normalize path)
    path) ;; stub

  (define (path-strip-trailing-directory-separator path)
    (let ([len (string-length path)])
      (if (and (> len 1) (char=? (string-ref path (- len 1)) #\/))
        (substring path 0 (- len 1))
        path)))

  ;; Directory and symlink operations
  (define (create-directory path)
    (mkdir path))

  (define (gambit-create-symbolic-link target link-name)
    (void)) ;; stub - would need FFI

  ;; File info — extended with metadata fields
  (define-record-type gambit-file-info-record
    (fields type size-val device-val inode-val
            owner-val group-val mode-val mtime-val atime-val))

  (define (gambit-file-info path . rest)
    ;; Return a record with file metadata (basic implementation)
    (cond
      [(file-directory? path)
       (make-gambit-file-info-record 'directory 0 0 0 0 0 0 0 0)]
      [(file-exists? path)
       (make-gambit-file-info-record 'regular 0 0 0 0 0 0 0 0)]
      [else
       (make-gambit-file-info-record #f 0 0 0 0 0 0 0 0)]))

  (define gambit-file-info? gambit-file-info-record?)

  (define (gambit-file-info-type fi)
    (if (gambit-file-info-record? fi)
      (gambit-file-info-record-type fi)
      #f))

  ;; Condition variables
  (define make-condition-variable
    (case-lambda
      [() (chez:make-condition)]
      [(name) (chez:make-condition)]))

  (define (condition-variable-signal! cv)
    (condition-signal cv))

  (define (condition-variable-broadcast! cv)
    (condition-broadcast cv))

  ;; Wills (weak reference finalizers) — stubs
  (define (make-will obj action) (cons obj action))
  (define (will-testator w) (car w))
  (define (will? w) (and (pair? w) #t))

  ;; System info
  (define (configure-command-string) "")
  (define (system-version-string) "Chez Scheme")

  ;; Object serial numbers
  (define __serial-number-table (make-eq-hashtable))
  (define __serial-counter 0)
  (define (object->serial-number obj)
    (or (eq-hashtable-ref __serial-number-table obj #f)
        (let ([n (begin (set! __serial-counter (+ __serial-counter 1))
                        __serial-counter)])
          (eq-hashtable-set! __serial-number-table obj n)
          n)))

  ;;; ================================================================
  ;;; Missing Gambit APIs for gerbil-shell self-hosting
  ;;; ================================================================

  ;; --- String/byte I/O ---
  (define (call-with-input-string str proc)
    (let ((p (open-input-string str)))
      (let ((result (proc p)))
        (close-input-port p)
        result)))

  (define (call-with-output-string proc)
    (let ((p (open-output-string)))
      (proc p)
      (get-output-string p)))

  ;; with-output-to-string is provided by Chez natively

  (define read-line
    (case-lambda
      (() (get-line (current-input-port)))
      ((port) (get-line port))))

  ;; string->bytes and bytes->string are in (runtime util)

  (define (write-subu8vector bv start end . maybe-port)
    (let ((port (if (pair? maybe-port) (car maybe-port) (current-output-port))))
      (put-bytevector port bv start (fx- end start))))

  (define (read-subu8vector/gambit bv start end . maybe-port)
    (let ((port (if (pair? maybe-port) (car maybe-port) (current-input-port))))
      (get-bytevector-n! port bv start (fx- end start))))

  ;; --- File & path operations ---

  ;; file-exists? and file-directory? are provided by Chez natively

  ;; file-info aliases mapping to gambit-file-info-record
  (define file-info gambit-file-info)
  (define file-info? gambit-file-info?)
  (define file-info-type gambit-file-info-type)
  (define file-info-size gambit-file-info-record-size-val)
  (define file-info-device gambit-file-info-record-device-val)
  (define file-info-inode gambit-file-info-record-inode-val)
  (define file-info-owner gambit-file-info-record-owner-val)
  (define file-info-group gambit-file-info-record-group-val)
  (define file-info-mode gambit-file-info-record-mode-val)
  (define file-info-last-modification-time gambit-file-info-record-mtime-val)
  (define file-info-last-access-time gambit-file-info-record-atime-val)

  (define (directory-files . args)
    ;; Gambit directory-files takes keyword args; we support path: or positional
    (let ((path (cond
                  ((null? args) ".")
                  ((string? (car args)) (car args))
                  (else "."))))
      (directory-list path)))

  (define (path-normalize path)
    (gambit-path-expand path))

  (define (path-expand path . rest)
    (gambit-path-expand path))

  (define (output-port-byte-position port pos)
    (set-port-position! port pos))

  ;; --- Process management ---
  ;; Process ports: stores Chez process ports + pid
  (define-record-type gambit-process-port
    (fields input output pid-val))

  (define (open-process settings)
    ;; Parse Gambit's property-list settings: (path: "cmd" arguments: '("a") ...)
    (let* ((path (let lp ((s settings))
                   (cond ((null? s) "/bin/sh")
                         ((and (symbol? (car s)) (eq? (car s) 'path:) (pair? (cdr s)))
                          (cadr s))
                         (else (lp (cdr s))))))
           (arguments (let lp ((s settings))
                        (cond ((null? s) '())
                              ((and (symbol? (car s)) (eq? (car s) 'arguments:) (pair? (cdr s)))
                               (cadr s))
                              (else (lp (cdr s))))))
           (cmd (string-append path
                  (let lp ((args arguments) (acc ""))
                    (if (null? args) acc
                        (lp (cdr args)
                            (string-append acc " " (car args))))))))
      ;; Use Chez's process function which returns (to-stdin from-stdout from-stderr pid)
      (let-values (((to-stdin from-stdout from-stderr pid) (process cmd)))
        (make-gambit-process-port from-stdout to-stdin pid))))

  (define (open-input-process settings)
    (open-process settings))

  (define (process-status port)
    ;; For gambit-process-port, wait and return exit status
    (if (gambit-process-port? port)
      0  ;; TODO: waitpid on (gambit-process-port-pid-val port)
      0))

  (define (process-pid port)
    (if (gambit-process-port? port)
      (gambit-process-port-pid-val port)
      0))

  ;; --- Port operations ---
  (define (force-output . maybe-port)
    (flush-output-port
      (if (pair? maybe-port) (car maybe-port) (current-output-port))))

  (define write-u8
    (case-lambda
      ((byte) (put-u8 (current-output-port) byte))
      ((byte port) (put-u8 port byte))))

  ;; close-port is provided by Chez natively

  ;; --- Environment ---
  ;; getenv is from Chez natively

  (define (setenv name value)
    (putenv name value))

  (define (get-environment-variables)
    ;; Return alist of all env vars by reading /proc/self/environ
    (guard (exn (#t '()))
      (let* ((content (call-with-port
                        (open-file-input-port "/proc/self/environ")
                        (lambda (p) (get-bytevector-all p))))
             (str (utf8->string content)))
        (let lp ((i 0) (start 0) (acc '()))
          (cond
            ((>= i (string-length str))
             (reverse acc))
            ((char=? (string-ref str i) #\nul)
             (let ((entry (substring str start i)))
               (let ((eq-pos (let scan ((j 0))
                               (cond ((>= j (string-length entry)) #f)
                                     ((char=? (string-ref entry j) #\=) j)
                                     (else (scan (+ j 1)))))))
                 (if eq-pos
                   (lp (+ i 1) (+ i 1)
                       (cons (cons (substring entry 0 eq-pos)
                                   (substring entry (+ eq-pos 1) (string-length entry)))
                             acc))
                   (lp (+ i 1) (+ i 1) acc)))))
            (else (lp (+ i 1) start acc)))))))

  ;; --- User info ---
  (define-record-type gambit-user-info (fields name-val home-val uid-val))

  (define (user-info . args)
    (let ((name (or (getenv "USER") "unknown"))
          (home (or (getenv "HOME") "/tmp"))
          (uid 0)) ;; TODO: get real UID via FFI
      (make-gambit-user-info name home uid)))

  (define user-info-home gambit-user-info-home-val)

  (define (user-name . args)
    (or (getenv "USER") "unknown"))

  ;; --- Time ---
  (define (current-second)
    (let ((t (current-time)))
      (+ (time-second t)
         (/ (time-nanosecond t) 1000000000.0))))

  (define (time->seconds t)
    (if (time? t)
      (+ (time-second t)
         (/ (time-nanosecond t) 1000000000.0))
      t))

  ;; --- Threading extras ---
  (define (spawn thunk)
    (fork-thread thunk))

  ;; Thread state — simplified for Chez
  (define-record-type gambit-thread-state
    (fields terminated? normally? result exception))

  (define (thread-state t)
    (make-gambit-thread-state #f #f #f #f))

  (define (thread-state-normally-terminated? s)
    (and (gambit-thread-state? s) (gambit-thread-state-normally? s)))

  (define (thread-state-abnormally-terminated? s)
    (and (gambit-thread-state? s)
         (gambit-thread-state-terminated? s)
         (not (gambit-thread-state-normally? s))))

  ;; --- Numeric ---
  (define (random-integer n)
    (random n))

  (define arithmetic-shift ash)

  ;; --- Control flow ---
  (define-syntax let/cc
    (syntax-rules ()
      ((_ k body ...)
       (call-with-current-continuation (lambda (k) body ...)))))

  ;; --- Misc ---
  (define pp pretty-print)

  (define (with-exception-catcher handler thunk)
    (guard (exn (#t (handler exn)))
      (thunk)))

  (define (tty-mode-set! port mode)
    ;; TODO: implement via FFI (termios)
    (void))

  (define (|##cpu-count|)
    ;; Read from /proc/cpuinfo or sysconf
    (guard (exn (#t 1))
      (let ((content (call-with-input-file "/proc/cpuinfo"
                       (lambda (p) (get-string-all p)))))
        (let lp ((i 0) (count 0))
          (cond
            ((>= (+ i 9) (string-length content)) (max 1 count))
            ((string=? (substring content i (+ i 9)) "processor")
             (lp (+ i 1) (+ count 1)))
            (else (lp (+ i 1) count)))))))

  (define (|##set-gambitdir!| dir) (void))

  ;; --- Helper: string-join ---
  (define (string-join lst sep)
    (if (null? lst) ""
        (let lp ((rest (cdr lst)) (acc (car lst)))
          (if (null? rest) acc
              (lp (cdr rest)
                  (string-append acc sep (car rest)))))))

  ) ;; end library
