#!chezscheme
;;; syntax.sls -- Gerbil syntax objects and AST on Chez Scheme
;;; Provides AST representation and source location tracking.

(library (runtime syntax)
  (export
    ;; AST
    AST::t make-AST AST? AST-e AST-source AST-e-set! AST-source-set!
    ;; syntax operations
    stx-e stx-source stx-wrap-source
    stx-pair? stx-null? stx-list? stx-datum? stx-boolean? stx-number?
    stx-fixnum? stx-string? stx-char? stx-keyword?
    stx-map stx-for-each stx-foldl stx-foldr
    stx-andmap stx-ormap
    stx-car stx-cdr
    stx->list stx->datum
    ;; identifiers
    identifier? stx-identifier
    ;; source location
    source-location? source-location-path source-location-path?
    ;; syntax error
    SyntaxError::t raise-syntax-error syntax-error?
    ;; genident
    genident gentemps
    ;; core-identifier
    core-identifier=?
    ;; read-syntax
    read-syntax read-syntax-from-file
    )

  (import
    (except (chezscheme) void error error? raise with-exception-handler identifier?
            andmap ormap iota last-pair find
            1+ 1- fx/ fx1+ fx1-)
    (rename (only (chezscheme) error raise identifier?)
            (error chez:error)
            (raise chez:raise)
            (identifier? chez:identifier?))
    (only (compat gambit-compat) |##keyword?| |##void|)
    (compat types)
    (runtime util)
    (except (runtime table) string-hash)
    (runtime mop)
    (runtime error))

  ;; --- AST type ---
  ;; AST wraps a datum with source location information
  (define AST::t
    (make-class-type
      (string->symbol "gerbil#AST::t")
      'syntax  ;; Gerbil calls it 'syntax internally
      (list object::t)
      '(e source)
      '((struct: . #t) (print: e))
      #f))

  (define (make-AST e source)
    (let ((ast (make-class-instance AST::t)))
      (|##structure-set!| ast 1 e)
      (|##structure-set!| ast 2 source)
      ast))

  (define (AST? obj)
    (|##structure-instance-of?| obj (string->symbol "gerbil#AST::t")))

  (define (AST-e ast)
    (if (AST? ast)
      (|##structure-ref| ast 1)
      ast))

  (define (AST-source ast)
    (if (AST? ast)
      (|##structure-ref| ast 2)
      #f))

  (define (AST-e-set! ast v) (|##structure-set!| ast 1 v))
  (define (AST-source-set! ast v) (|##structure-set!| ast 2 v))

  ;; --- Syntax operations ---
  (define stx-e AST-e)

  (define (stx-source stx)
    (if (AST? stx) (AST-source stx) #f))

  (define (stx-wrap-source e src)
    (if src (make-AST e src) e))

  (define (stx-pair? stx)
    (pair? (stx-e stx)))

  (define (stx-null? stx)
    (let ((e (stx-e stx)))
      (or (null? e) (and (AST? e) (null? (AST-e e))))))

  (define (stx-list? stx)
    (let lp ((e (stx-e stx)))
      (cond
        ((null? e) #t)
        ((pair? e) (lp (stx-e (cdr e))))
        ((AST? e) (lp (AST-e e)))
        (else #f))))

  (define (stx-datum? stx)
    (let ((e (stx-e stx)))
      (or (number? e) (string? e) (char? e) (boolean? e)
          (|##keyword?| e) (null? e)
          (eq? e (|##void|)))))

  (define (stx-boolean? stx)
    (boolean? (stx-e stx)))

  (define (stx-number? stx)
    (number? (stx-e stx)))

  (define (stx-fixnum? stx)
    (fixnum? (stx-e stx)))

  (define (stx-string? stx)
    (string? (stx-e stx)))

  (define (stx-char? stx)
    (char? (stx-e stx)))

  (define (stx-keyword? stx)
    (|##keyword?| (stx-e stx)))

  (define (stx-car stx)
    (car (stx-e stx)))

  (define (stx-cdr stx)
    (cdr (stx-e stx)))

  (define (stx-map f stx)
    (map f (stx->list stx)))

  (define (stx-for-each f stx)
    (for-each f (stx->list stx)))

  (define (stx-foldl f iv stx)
    (foldl1 f iv (stx->list stx)))

  (define (stx-foldr f iv stx)
    (foldr1 f iv (stx->list stx)))

  (define (stx-andmap f stx)
    (andmap1 f (stx->list stx)))

  (define (stx-ormap f stx)
    (ormap1 f (stx->list stx)))

  (define (stx->list stx)
    (let ((e (stx-e stx)))
      (cond
        ((list? e) e)
        ((pair? e)
         (cons (car e) (stx->list (cdr e))))
        ((AST? e) (stx->list e))
        ((null? e) '())
        (else (list e)))))

  (define (stx->datum stx)
    (let ((e (stx-e stx)))
      (cond
        ((pair? e) (cons (stx->datum (car e)) (stx->datum (cdr e))))
        ((AST? e) (stx->datum e))
        ((vector? e) (vector-map stx->datum e))
        (else e))))

  ;; --- Identifiers ---
  (define (identifier? stx)
    (symbol? (stx-e stx)))

  (define (stx-identifier ctx . parts)
    (let ((sym (string->symbol
                 (apply string-append
                   (map (lambda (p)
                          (cond
                            ((string? p) p)
                            ((symbol? p) (symbol->string p))
                            ((identifier? p) (symbol->string (stx-e p)))
                            (else (format "~a" p))))
                        parts)))))
      (if (AST? ctx)
        (make-AST sym (AST-source ctx))
        sym)))

  (define (core-identifier=? stx sym)
    (eq? (stx-e stx) sym))

  ;; --- Source location ---
  (define (source-location? x)
    (and (pair? x)
         (or (string? (car x)) (not (car x)))
         (pair? (cdr x))
         (fixnum? (cadr x))))

  (define (source-location-path loc)
    (if (pair? loc) (car loc) #f))

  (define (source-location-path? loc)
    (and (source-location? loc) (string? (car loc))))

  ;; --- Syntax error ---
  (define SyntaxError::t
    (make-class-type
      (string->symbol "gerbil#SyntaxError::t")
      'SyntaxError
      (list Error::t)
      '(context marks phi)
      '((struct: . #t))
      #f))

  (define (syntax-error? e)
    (|##structure-instance-of?| e (string->symbol "gerbil#SyntaxError::t")))

  (define (raise-syntax-error where what . irritants)
    (let ((msg (if (string? what) what (format "~a" what))))
      (chez:raise
        (let ((e (make-class-instance SyntaxError::t
                   'message: msg
                   'irritants: irritants
                   'where: where
                   'continuation: #f
                   'context: #f
                   'marks: '()
                   'phi: 0)))
          e))))

  ;; --- genident ---
  (define genident-counter 0)

  (define genident
    (case-lambda
      (() (genident 'g))
      ((prefix)
       (set! genident-counter (fx+ genident-counter 1))
       (gensym (if (symbol? prefix) (symbol->string prefix) prefix)))))

  (define (gentemps ids)
    (map (lambda (id) (genident (if (identifier? id) (stx-e id) 'tmp))) ids))

  ;; --- Reading ---
  ;; Uses the Phase 1 reader from (reader reader)
  (define (read-syntax . port-arg)
    (let ((port (if (pair? port-arg) (car port-arg) (current-input-port))))
      (let ((datum (read port)))
        (if (eof-object? datum)
          datum
          (make-AST datum #f)))))

  (define (read-syntax-from-file path)
    (call-with-input-file path
      (lambda (port)
        (let lp ((forms '()))
          (let ((datum (read port)))
            (if (eof-object? datum)
              (reverse forms)
              (lp (cons (make-AST datum (list path 0 0)) forms))))))))

  ) ;; end library
