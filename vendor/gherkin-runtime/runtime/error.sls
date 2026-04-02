#!chezscheme
;;; error.sls -- Gerbil error/exception system on Chez Scheme
;;; Uses Chez conditions + Gerbil MOP classes

(library (runtime error)
  (export
    ;; exception classes
    Exception::t StackTrace::t Error::t ContractViolation::t
    RuntimeException::t
    ;; predicates
    exception? error-object? error?
    contract-violation-error?
    ;; accessors
    error-message error-irritants error-trace
    ;; raising
    raise raise-contract-violation-error
    ;; handling
    with-exception-handler with-catch with-exception-catcher
    ;; display
    display-exception
    ;; stack trace
    dump-stack-trace?
    ;; Gerbil class-style aliases (Error?, Error-message, etc.)
    Error? Error-message Error-irritants
    ;; Gambit error-exception compat
    error-exception? error-exception-message os-exception?
    ;; Formatted exception message
    exception-message
    )

  (import
    (except (chezscheme) void raise error error? with-exception-handler
            andmap ormap iota last-pair find
            1+ 1- fx/ fx1+ fx1-)
    (rename (only (chezscheme) raise error error? with-exception-handler)
            (raise chez:raise)
            (error chez:error)
            (error? chez:error?)
            (with-exception-handler chez:with-exception-handler))
    ;; gambit-compat not needed: structure ops come from (compat types)
    (compat types)
    (runtime util)
    (except (runtime table) string-hash)
    (runtime mop))

  ;; --- Exception type hierarchy ---
  ;; These are Gerbil MOP classes used for structured exceptions

  ;; Exception and StackTrace are classes (defclass), NOT structs
  (define Exception::t
    (make-class-type
      (string->symbol "gerbil#Exception::t")
      'Exception
      (list object::t)
      '()    ;; no fields - Exception is an empty base class
      '()
      #f))

  (define StackTrace::t
    (make-class-type
      (string->symbol "gerbil#StackTrace::t")
      'StackTrace
      (list object::t)
      '(continuation)
      '()
      #f))

  (define Error::t
    (make-class-type
      (string->symbol "gerbil#Error::t")
      'Error
      (list Exception::t StackTrace::t)
      '(message irritants where)
      '()
      #f))

  (define ContractViolation::t
    (make-class-type
      (string->symbol "gerbil#ContractViolation::t")
      'ContractViolation
      (list Error::t)
      '()
      '()
      #f))

  (define RuntimeException::t
    (make-class-type
      (string->symbol "gerbil#RuntimeException::t")
      'RuntimeException
      (list Exception::t StackTrace::t)
      '(exception)
      '()
      #f))

  ;; --- Predicates ---
  (define exception?
    (make-class-predicate Exception::t))

  (define error?
    (lambda (obj)
      (or (|##structure-instance-of?| obj (string->symbol "gerbil#Error::t"))
          (chez:error? obj)
          (condition? obj))))

  (define error-object?
    (lambda (obj)
      (or (exception? obj) (condition? obj))))

  (define contract-violation-error?
    (make-class-predicate ContractViolation::t))

  ;; --- Accessors ---
  (define (error-message e)
    (cond
      ((exception? e) (slot-ref e 'message))
      ((message-condition? e) (condition-message e))
      (else (format "~a" e))))

  (define (error-irritants e)
    (cond
      ((exception? e) (slot-ref e 'irritants))
      ((irritants-condition? e) (condition-irritants e))
      (else '())))

  (define (error-trace e)
    (cond
      ((and (|##structure?| e)
            (|##structure-instance-of?| e (string->symbol "gerbil#StackTrace::t")))
       (slot-ref e 'continuation))
      (else #f)))

  ;; --- Raising ---
  (define (raise exn)
    (chez:raise exn))

  (define (raise-contract-violation-error where what . irritants)
    (let ((e (make-class-instance ContractViolation::t
               'message: what
               'irritants: irritants
               'where: where
               'continuation: #f)))
      (chez:raise e)))

  ;; --- Exception handling ---
  (define (with-exception-handler handler thunk)
    (chez:with-exception-handler handler thunk))

  (define (with-catch handler thunk)
    (guard (exn (#t (handler exn)))
      (thunk)))

  (define with-exception-catcher with-catch)

  ;; --- Display ---
  (define (display-exception e . port-arg)
    (let ((port (if (pair? port-arg) (car port-arg) (current-error-port))))
      (cond
        ((exception? e)
         (display "*** ERROR " port)
         (let ((where (and (|##structure?| e)
                           (|##structure-instance-of?| e (string->symbol "gerbil#Exception::t"))
                           (slot-ref e 'where))))
           (when where
             (display "IN " port)
             (display where port)
             (display " " port)))
         (display (error-message e) port)
         (let ((irritants (error-irritants e)))
           (when (pair? irritants)
             (for-each (lambda (x) (display " " port) (write x port)) irritants)))
         (newline port))
        ((condition? e)
         (display-condition e port)
         (newline port))
        (else
         (display "*** ERROR: " port)
         (write e port)
         (newline port)))))

  ;; --- Stack trace ---
  (define dump-stack-trace? (make-parameter #f))

  ;; --- Gerbil class-style aliases ---
  ;; Gerbil's defclass Error generates Error?, Error-message, Error-irritants
  (define Error? error?)
  (define Error-message error-message)
  (define Error-irritants error-irritants)

  ;; --- Gambit error-exception compat ---
  ;; Gambit's error-exception? maps to Chez serious conditions
  (define (error-exception? e)
    (or (chez:error? e)
        (condition? e)))

  (define (error-exception-message e)
    (if (message-condition? e)
        (condition-message e)
        (format "~a" e)))

  ;; Gambit's os-exception? maps to Chez i/o conditions
  (define (os-exception? e)
    (or (i/o-error? e)
        (and (condition? e)
             (message-condition? e))))

  ;; Formatted exception message — extracts a human-readable message string.
  ;; Chez's condition-message returns format templates like "variable ~:s is not bound"
  ;; which aren't useful directly. This uses display-condition to format properly.
  (define (exception-message e)
    (define (format-condition e)
      (let ((msg (call-with-string-output-port
                   (lambda (p) (display-condition e p)))))
        ;; Strip "Exception: " or "Exception in <who>: " prefix
        (cond
          ((and (> (string-length msg) 11)
                (string=? (substring msg 0 11) "Exception: "))
           (substring msg 11 (string-length msg)))
          ((and (> (string-length msg) 13)
                (string=? (substring msg 0 13) "Exception in "))
           (let lp ((i 13))
             (cond
               ((>= (+ i 1) (string-length msg)) msg)
               ((and (char=? (string-ref msg i) #\:)
                     (char=? (string-ref msg (+ i 1)) #\space))
                (substring msg (+ i 2) (string-length msg)))
               (else (lp (+ i 1))))))
          (else msg))))
    (cond
      ((string? e) e)
      ((Error? e) (Error-message e))
      ((condition? e) (format-condition e))
      (else (call-with-string-output-port
              (lambda (p) (display e p))))))

  ) ;; end library
