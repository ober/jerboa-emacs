#!chezscheme
;;; c3.sls -- C4 linearization algorithm for Chez Scheme
;;; Nearly pure algorithm, ported from src/gerbil/runtime/c3.ss

(library (runtime c3)
  (export c4-linearize)

  (import
    (except (chezscheme) void box box? unbox set-box!
            andmap ormap iota last-pair find
            1+ 1- fx/ fx1+ fx1-)
    (runtime util))

  ;; C4 linearization: topologically sort a multiple-inheritance DAG.
  ;; Returns (values precedence-list super-struct)
  ;; get-precedence-list: (X -> (NonEmptyList X))
  ;; struct?: (X -> Bool)
  ;; eq: (X X -> Bool) [default: eq?]
  ;; get-name: (X -> Y) [default: identity]
  (define c4-linearize
    (case-lambda
      ((rhead supers get-precedence-list struct?)
       (c4-linearize* rhead supers get-precedence-list struct? eq? (lambda (x) x)))
      ((rhead supers get-precedence-list struct? eq)
       (c4-linearize* rhead supers get-precedence-list struct? eq (lambda (x) x)))
      ((rhead supers get-precedence-list struct? eq get-name)
       (c4-linearize* rhead supers get-precedence-list struct? eq get-name))))

  ;; Chez member only takes 2 args; we need 3-arg version with custom equality
  (define (member/eq item lst eq)
    (memp (lambda (x) (eq item x)) lst))

  (define (c4-linearize* rhead supers get-precedence-list struct? eq get-name)
    (cond
      ((null? supers)
       (values (reverse rhead) #f))
      ((null? (cdr supers))
       (let ((pl (get-precedence-list (car supers))))
         (values (append-reverse rhead pl)
                 (find struct? pl))))
      (else
        (let ((pls (map get-precedence-list supers))
              (sis '()))

          (define (get-names lst) (map get-name lst))

          (define (err . a)
            (apply error "Inconsistent precedence graph"
                   "head:" (get-names (reverse rhead))
                   "precedence-lists:" (map get-names pls)
                   "single-inheritance-suffix:" (get-names sis)
                   a))

          (define (eqlist? l1 l2)
            (or (eq? l1 l2)
                (and (andmap eq l1 l2)
                     (fx= (length l1) (length l2)))))

          ;; Merge struct suffixes
          (define (merge-sis! sis2)
            (cond
              ((null? sis2) (values))
              ((null? sis) (set! sis sis2))
              (else
                (let loop ((t1 sis) (t2 sis2))
                  (cond
                    ((eqlist? t1 sis2) (values))
                    ((eqlist? t2 sis) (set! sis sis2))
                    ((null? t1) (if (member/eq (car sis) t2 eq) (set! sis sis2) (err)))
                    ((null? t2) (if (member/eq (car sis2) t1 eq) (values) (err)))
                    (else (loop (cdr t1) (cdr t2))))))))

          ;; Split each PL at first struct
          (define rpls
            (map (lambda (pl)
                   (let-values (((tl rh) (append-reverse-until struct? pl '())))
                     (merge-sis! tl)
                     rh))
                 pls))

          ;; Remove classes already in the sis
          (define (unsisr-rpl rpl)
            (let u ((pl-rhead rpl) (pl-tail '())
                    (sis-rhead (reverse sis)) (sis-tail '()))
              (if (null? pl-rhead) pl-tail
                (let ((c (car pl-rhead))
                      (plrh (cdr pl-rhead)))
                  (if (member/eq c sis-tail eq)
                    (err "super-out-of-order-vs-single-inheritance-tail:" (get-name c))
                    (let-values (((sis-rh2 sis-tl2)
                                  (append-reverse-until (lambda (x) (eq c x)) sis-rhead sis-tail)))
                      (if (null? sis-rh2)
                        (u plrh (cons c pl-tail) '() sis-tl2)
                        (u plrh pl-tail (cdr sis-rh2) sis-tl2))))))))

          (append1! rpls (reverse supers))
          (let ((hpls (map unsisr-rpl rpls)))

            ;; C3 select next
            (define (c3-select-next tails)
              (let ((candidate? (lambda (c)
                                  (andmap (lambda (tail) (not (member/eq c (cdr tail) eq))) tails))))
                (let loop ((ts tails))
                  (if (pair? ts)
                    (let ((c (caar ts)))
                      (if (candidate? c) c (loop (cdr ts))))
                    (err)))))

            ;; Remove chosen element
            (define (remove-next! next tails)
              (let loop ((t tails))
                (when (pair? t)
                  (when (eq? (caar t) next)
                    (set-car! t (cdar t)))
                  (loop (cdr t))))
              tails)

            ;; C3 loop
            (define precedence-list
              (let c3loop ((rhead rhead) (tails hpls))
                (let ((tails (remove-nulls! tails)))
                  (cond
                    ((null? tails) (append-reverse rhead sis))
                    ((null? (cdr tails)) (append-reverse rhead (append (car tails) sis)))
                    (else
                      (let ((next (c3-select-next tails)))
                        (c3loop (cons next rhead)
                                (remove-next! next tails))))))))

            (define super-struct
              (if (pair? sis) (car sis) #f))

            (values precedence-list super-struct)))))))

  ;; c4-linearize uses positional args since Chez doesn't have Gerbil keywords

