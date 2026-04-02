#!chezscheme
;;; util.sls -- Gerbil runtime utilities for Chez Scheme
;;; Ported from src/gerbil/runtime/util.ss

(library (runtime util)
  (export
    ;; output
    displayln display*
    ;; sentinel values
    absent-obj absent-value
    ;; boolean/void
    true false void? true?
    ;; dssl
    dssl-object? dssl-key-object? dssl-rest-object? dssl-optional-object?
    dssl-key-obj dssl-rest-obj dssl-optional-obj
    ;; type predicates
    immediate? nonnegative-fixnum? pair-or-null?
    ;; values
    values-count values-ref values->list
    ;; folds
    foldl foldl1 foldr foldr1 andmap andmap1 ormap ormap1 filter-map filter-map1
    ;; association lists
    agetq agetv aget pgetq pgetv pget
    assgetq assgetv assget
    ;; searching
    find memf
    remove1 remv1 remq1 remf
    ;; list utilities
    remove-nulls! append1! append-reverse-until
    ;; arithmetic
    1+ 1- fx1+ fx1- fxshift fx/ fx>=0? fx>0? fx=0? fx<0? fx<=0?
    ;; symbols/keywords
    interned-symbol? interned-keyword?
    make-symbol make-keyword
    symbol->keyword keyword->symbol
    as-string display-as-string
    ;; string utilities
    string-empty? string-index string-rindex string-split string-join
    ;; bytes
    bytes->string string->bytes substring->bytes
    ;; binary I/O
    read-u8vector write-u8vector
    ;; debugging
    DBG-helper DBG-printer
    ;; SMP locks (using Chez atomics)
    make-spinlock spinlock-acquire! spinlock-release!
    ;; misc
    iota last-pair last append-reverse
    identity drop take
    )

  (import
    (except (chezscheme) void box box? unbox set-box!
            andmap ormap iota last-pair find
            1+ 1- fx/ fx1+ fx1-)
    (rename (only (compat gambit-compat)
              |##void| |##keyword?| |##keyword->string| |##string->keyword|
              absent-obj)
            (absent-obj gambit:absent-obj)))

  ;; --- output ---
  (define (displayln . args)
    (for-each display args)
    (newline))

  (define (display* . args)
    (for-each display args))

  ;; --- sentinel values ---
  (define absent-obj (gambit:absent-obj))
  (define absent-value (vector (|##void|)))

  ;; --- boolean/void ---
  (define (true . ignore) #t)
  (define (true? obj) (eq? obj #t))
  (define (false . ignore) #f)
  (define (void? obj) (eq? obj (|##void|)))

  ;; --- DSSL objects ---
  ;; In Gerbil, #!key, #!rest, #!optional are special objects
  ;; We use unique symbols for these
  (define dssl-key-obj (string->symbol "#!key"))
  (define dssl-rest-obj (string->symbol "#!rest"))
  (define dssl-optional-obj (string->symbol "#!optional"))

  (define (dssl-object? obj)
    (or (eq? obj dssl-key-obj)
        (eq? obj dssl-rest-obj)
        (eq? obj dssl-optional-obj)))
  (define (dssl-key-object? obj) (eq? obj dssl-key-obj))
  (define (dssl-rest-object? obj) (eq? obj dssl-rest-obj))
  (define (dssl-optional-object? obj) (eq? obj dssl-optional-obj))

  ;; --- type predicates ---
  (define (immediate? obj)
    (or (fixnum? obj) (char? obj) (boolean? obj) (null? obj)
        (eq? obj (|##void|)) (eof-object? obj)))

  (define (nonnegative-fixnum? obj)
    (and (fixnum? obj) (fx>= obj 0)))

  (define (pair-or-null? obj)
    (or (pair? obj) (null? obj)))

  ;; --- values ---
  (define (values-count obj)
    ;; In Chez, there's no direct way to check if something is a multiple values object
    ;; We'll assume single value unless it's wrapped
    1)

  (define (values-ref obj k)
    obj)

  (define (values->list obj)
    (list obj))

  ;; --- folds ---
  (define (foldl1 f iv lst)
    (let lp ((rest lst) (r iv))
      (if (pair? rest)
        (lp (cdr rest) (f (car rest) r))
        r)))

  (define (foldl . args)
    (case (length args)
      ((3) (foldl1 (car args) (cadr args) (caddr args)))
      (else (apply foldl1 args))))

  (define (foldr1 f iv lst)
    (let recur ((rest lst))
      (if (pair? rest)
        (f (car rest) (recur (cdr rest)))
        iv)))

  (define (foldr . args)
    (case (length args)
      ((3) (foldr1 (car args) (cadr args) (caddr args)))
      (else (apply foldr1 args))))

  (define (andmap1 f lst)
    (let lp ((rest lst))
      (if (pair? rest)
        (and (f (car rest)) (lp (cdr rest)))
        #t)))

  (define (andmap f . lsts)
    (if (null? (cdr lsts))
      (andmap1 f (car lsts))
      (let lp ((lsts lsts))
        (if (for-all pair? lsts)
          (and (apply f (map car lsts))
               (lp (map cdr lsts)))
          #t))))

  (define (ormap1 f lst)
    (let lp ((rest lst))
      (if (pair? rest)
        (or (f (car rest)) (lp (cdr rest)))
        #f)))

  (define (ormap f . lsts)
    (if (null? (cdr lsts))
      (ormap1 f (car lsts))
      (let lp ((lsts lsts))
        (if (for-all pair? lsts)
          (or (apply f (map car lsts))
              (lp (map cdr lsts)))
          #f))))

  (define (filter-map1 f lst)
    (let recur ((rest lst))
      (if (pair? rest)
        (let ((r (f (car rest))))
          (if r
            (cons r (recur (cdr rest)))
            (recur (cdr rest))))
        '())))

  (define (filter-map f . lsts)
    (if (null? (cdr lsts))
      (filter-map1 f (car lsts))
      (let recur ((lsts lsts))
        (if (for-all pair? lsts)
          (let ((r (apply f (map car lsts))))
            (if r
              (cons r (recur (map cdr lsts)))
              (recur (map cdr lsts))))
          '()))))

  ;; --- association lists ---
  (define (agetq key lst . default)
    (let ((d (if (null? default) #f (car default))))
      (cond
        ((and (pair? lst) (assq key lst)) => cdr)
        ((procedure? d) (d key))
        (else d))))

  (define (agetv key lst . default)
    (let ((d (if (null? default) #f (car default))))
      (cond
        ((and (pair? lst) (assv key lst)) => cdr)
        ((procedure? d) (d key))
        (else d))))

  (define (aget key lst . default)
    (let ((d (if (null? default) #f (car default))))
      (cond
        ((and (pair? lst) (assoc key lst)) => cdr)
        ((procedure? d) (d key))
        (else d))))

  ;; backwards compat
  (define assgetq agetq)
  (define assgetv agetv)
  (define assget aget)

  ;; --- plist getters ---
  (define (pgetq key lst . default)
    (let ((d (if (null? default) #f (car default))))
      (let lp ((rest lst))
        (if (and (pair? rest) (pair? (cdr rest)))
          (if (eq? (car rest) key)
            (cadr rest)
            (lp (cddr rest)))
          (if (procedure? d) (d key) d)))))

  (define (pgetv key lst . default)
    (let ((d (if (null? default) #f (car default))))
      (let lp ((rest lst))
        (if (and (pair? rest) (pair? (cdr rest)))
          (if (eqv? (car rest) key)
            (cadr rest)
            (lp (cddr rest)))
          (if (procedure? d) (d key) d)))))

  (define (pget key lst . default)
    (let ((d (if (null? default) #f (car default))))
      (let lp ((rest lst))
        (if (and (pair? rest) (pair? (cdr rest)))
          (if (equal? (car rest) key)
            (cadr rest)
            (lp (cddr rest)))
          (if (procedure? d) (d key) d)))))

  ;; --- searching ---
  (define (find pred lst)
    (let ((r (memf pred lst)))
      (if r (car r) #f)))

  (define (memf proc lst)
    (let lp ((rest lst))
      (if (pair? rest)
        (if (proc (car rest)) rest (lp (cdr rest)))
        #f)))

  (define (remove1 el lst)
    (let lp ((rest lst) (r '()))
      (if (pair? rest)
        (if (equal? el (car rest))
          (foldl1 cons (cdr rest) r)
          (lp (cdr rest) (cons (car rest) r)))
        lst)))

  (define (remv1 el lst)
    (let lp ((rest lst) (r '()))
      (if (pair? rest)
        (if (eqv? el (car rest))
          (foldl1 cons (cdr rest) r)
          (lp (cdr rest) (cons (car rest) r)))
        lst)))

  (define (remq1 el lst)
    (let lp ((rest lst) (r '()))
      (if (pair? rest)
        (if (eq? el (car rest))
          (foldl1 cons (cdr rest) r)
          (lp (cdr rest) (cons (car rest) r)))
        lst)))

  (define (remf proc lst)
    (let lp ((rest lst) (r '()))
      (if (pair? rest)
        (if (proc (car rest))
          (foldl1 cons (cdr rest) r)
          (lp (cdr rest) (cons (car rest) r)))
        lst)))

  ;; --- list utilities ---
  (define (remove-nulls! l)
    (cond
      ((not (pair? l)) l)
      ((null? (car l)) (remove-nulls! (cdr l)))
      (else
        (let loop ((l l) (r (cdr l)))
          (cond
            ((not (pair? r)) l)
            ((null? (car r))
             (set-cdr! l (remove-nulls! (cdr r))))
            (else (loop r (cdr r)))))
        l)))

  (define (append1! l x)
    (let ((l2 (list x)))
      (if (pair? l)
        (begin (set-cdr! (last-pair l) l2) l)
        l2)))

  (define (append-reverse-until pred rhead tail)
    (let loop ((rhead rhead) (tail tail))
      (cond
        ((null? rhead) (values '() tail))
        ((pred (car rhead)) (values rhead tail))
        (else (loop (cdr rhead) (cons (car rhead) tail))))))

  (define (last-pair lst)
    (if (pair? (cdr lst))
      (last-pair (cdr lst))
      lst))

  (define (last lst)
    (car (last-pair lst)))

  (define (append-reverse rhead tail)
    (if (pair? rhead)
      (append-reverse (cdr rhead) (cons (car rhead) tail))
      tail))

  (define (identity x) x)
  (define (drop lst n) (list-tail lst n))
  (define (take lst n)
    (if (zero? n) '()
      (cons (car lst) (take (cdr lst) (- n 1)))))

  ;; --- arithmetic ---
  (define (1+ x) (+ x 1))
  (define (1- x) (- x 1))
  (define (fx1+ x) (fx+ x 1))
  (define (fx1- x) (fx- x 1))
  (define fxshift fxarithmetic-shift)
  (define fx/ fxdiv)
  (define (fx>=0? x) (and (fixnum? x) (fx>= x 0)))
  (define (fx>0? x) (and (fixnum? x) (fx> x 0)))
  (define (fx=0? x) (and (fixnum? x) (fxzero? x)))
  (define (fx<0? x) (and (fixnum? x) (fx< x 0)))
  (define (fx<=0? x) (and (fixnum? x) (fx<= x 0)))

  ;; --- symbols/keywords ---
  (define (interned-symbol? x)
    (and (symbol? x) (not (gensym? x))))

  (define (interned-keyword? x)
    (|##keyword?| x))

  (define (display-as-string x port)
    (cond
      ((or (string? x) (symbol? x) (|##keyword?| x) (number? x) (char? x))
       (display x port))
      ((pair? x)
       (display-as-string (car x) port)
       (display-as-string (cdr x) port))
      ((vector? x)
       (vector-for-each (lambda (e) (display-as-string e port)) x))
      ((or (null? x) (void? x) (eof-object? x) (boolean? x))
       (values))
      (else
       (error "cannot convert as string" x))))

  (define as-string
    (case-lambda
      ((x)
       (cond
         ((string? x) x)
         ((symbol? x) (symbol->string x))
         ((|##keyword?| x) (|##keyword->string| x))
         ((number? x) (number->string x))
         (else
           (let-values (((port get) (open-string-output-port)))
             (display-as-string x port)
             (get)))))
      (args
       (let-values (((port get) (open-string-output-port)))
         (display-as-string args port)
         (get)))))

  (define make-symbol
    (case-lambda
      ((x) (if (interned-symbol? x) x (string->symbol (as-string x))))
      (args (string->symbol (apply as-string args)))))

  (define make-keyword
    (case-lambda
      ((x) (if (interned-keyword? x) x (|##string->keyword| (as-string x))))
      (args (|##string->keyword| (apply as-string args)))))

  (define (symbol->keyword sym)
    (|##string->keyword| (symbol->string sym)))

  (define (keyword->symbol kw)
    (string->symbol (|##keyword->string| kw)))

  ;; --- string utilities ---
  (define (string-empty? str)
    (fxzero? (string-length str)))

  (define string-index
    (case-lambda
      ((str char) (string-index str char 0))
      ((str char start)
       (let ((len (string-length str)))
         (let lp ((k start))
           (and (fx< k len)
                (if (char=? char (string-ref str k))
                  k
                  (lp (fx+ k 1)))))))))

  (define string-rindex
    (case-lambda
      ((str char) (string-rindex str char #f))
      ((str char start)
       (let* ((len (string-length str))
              (start (if (fixnum? start) start (fx- len 1))))
         (let lp ((k start))
           (and (fx>= k 0)
                (if (char=? char (string-ref str k))
                  k
                  (lp (fx- k 1)))))))))

  (define (string-split str char)
    (let ((len (string-length str)))
      (let lp ((start 0) (r '()))
        (cond
          ((string-index str char start)
           => (lambda (end)
                (lp (fx+ end 1) (cons (substring str start end) r))))
          ((fx< start len)
           (reverse (cons (substring str start len) r)))
          (else
           (reverse r))))))

  (define (string-join strs join)
    (let ((join (cond
                  ((char? join) (string join))
                  ((string? join) join)
                  (else (error "expected string or char" join)))))
      (if (null? strs)
        ""
        (let lp ((rest (cdr strs))
                 (acc (car strs)))
          (if (pair? rest)
            (lp (cdr rest) (string-append acc join (car rest)))
            acc)))))

  ;; --- bytes ---
  (define bytes->string
    (case-lambda
      ((bv) (utf8->string bv))
      ((bv enc)
       (if (eq? enc 'UTF-8)
         (utf8->string bv)
         (utf8->string bv)))))  ;; simplified: only UTF-8

  (define string->bytes
    (case-lambda
      ((str) (string->utf8 str))
      ((str enc) (string->utf8 str))))

  (define substring->bytes
    (case-lambda
      ((str start end) (string->utf8 (substring str start end)))
      ((str start end enc) (string->utf8 (substring str start end)))))

  ;; --- binary I/O ---
  (define read-u8vector
    (case-lambda
      ((bv port) (get-bytevector-some! port bv 0 (bytevector-length bv)))
      ((bv port start end) (get-bytevector-some! port bv start (fx- end start)))))

  (define write-u8vector
    (case-lambda
      ((bv port) (put-bytevector port bv))
      ((bv port start end) (put-bytevector port bv start (fx- end start)))))

  ;; --- debugging ---
  (define DBG-printer (make-parameter write))

  (define (DBG-helper tag dbg-exprs dbg-thunks expr thunk)
    (let ((e (current-error-port)))
      (when (and tag (not (void? tag)))
        (display tag e)
        (newline e))
      (for-each
        (lambda (expr thunk)
          (display "  " e)
          (write expr e)
          (display " =>" e)
          (let ((v (thunk)))
            (display " " e)
            (write v e)
            (newline e)))
        dbg-exprs dbg-thunks)
      (if thunk (thunk) (values))))

  ;; --- SMP locks ---
  ;; True spinlocks using Chez native box-cas! for short critical sections.
  ;; Much lighter than pthread mutexes for SMP hot paths.
  ;; We use chez:box/chez:box-cas! to get Chez's native atomic boxes,
  ;; since gambit-compat redefines box with its own record type.
  (define chez:box (let () (import (only (chezscheme) box)) box))
  (define chez:box-cas! (let () (import (only (chezscheme) box-cas!)) box-cas!))
  (define chez:set-box! (let () (import (only (chezscheme) set-box!)) set-box!))

  (define (make-spinlock) (chez:box #f))
  (define (spinlock-acquire! lock)
    (let spin ()
      (unless (chez:box-cas! lock #f #t)
        (spin))))
  (define (spinlock-release! lock)
    (chez:set-box! lock #f))

  ;; --- misc ---
  (define iota
    (case-lambda
      ((n) (iota n 0 1))
      ((n start) (iota n start 1))
      ((n start step)
       (let lp ((i (fx- n 1)) (r '()))
         (if (fx< i 0) r
           (lp (fx- i 1) (cons (+ start (* i step)) r)))))))

  ) ;; end library
