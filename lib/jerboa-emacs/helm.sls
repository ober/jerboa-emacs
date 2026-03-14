#!chezscheme
;;; helm.sls — Helm core framework for jemacs
;;;
;;; Ported from gerbil-emacs/helm.ss
;;; Backend-agnostic: data model, multi-match engine, filtering,
;;; session management, action dispatch. No TUI or Qt imports.

(library (jerboa-emacs helm)
  (export
    ;; Data structures
    helm-source? helm-source-name helm-source-candidates helm-source-actions
    helm-source-persistent-action helm-source-display-fn helm-source-real-fn
    helm-source-fuzzy? helm-source-volatile? helm-source-candidate-limit
    helm-source-keymap helm-source-follow?
    make-helm-source

    helm-session? helm-session-sources helm-session-pattern
    helm-session-candidates helm-session-candidates-set!
    helm-session-selected helm-session-selected-set!
    helm-session-marked helm-session-marked-set!
    helm-session-buffer-name helm-session-scroll-offset
    helm-session-scroll-offset-set! helm-session-follow?
    helm-session-follow?-set! helm-session-alive?
    helm-session-alive?-set!
    make-helm-session

    helm-candidate? helm-candidate-display helm-candidate-real
    helm-candidate-source
    make-helm-candidate

    ;; Matching
    helm-multi-match
    helm-multi-match?

    ;; Filtering
    helm-filter-source
    helm-filter-all

    ;; Session management
    helm-sessions
    helm-last-session
    helm-session-store!
    helm-session-resume

    ;; Action dispatch
    helm-default-action
    helm-run-action

    ;; Candidate construction
    make-helm-candidates

    ;; Session construction
    make-new-session
    make-simple-source

    ;; Match highlighting
    helm-match-positions

    ;; Pattern access (for volatile sources like grep)
    helm-current-pattern

    ;; Configuration
    helm-candidate-limit
    helm-follow-delay)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1-)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std srfi srfi-13)
          (only (std misc string) string-split))

  ;;;============================================================================
  ;;; Configuration
  ;;;============================================================================

  (def *helm-candidate-limit* 100)
  (def *helm-follow-delay* 0.1)

  (def (helm-candidate-limit) *helm-candidate-limit*)
  (def (helm-follow-delay) *helm-follow-delay*)

  ;; Dynamic parameter: set to current pattern during helm-filter-source
  (def *helm-current-pattern* (make-parameter ""))
  (def (helm-current-pattern) *helm-current-pattern*)

  ;;;============================================================================
  ;;; Data structures
  ;;;============================================================================

  (defstruct helm-source
    (name candidates actions persistent-action display-fn real-fn
     fuzzy? volatile? candidate-limit keymap follow?))

  (defstruct helm-session
    (sources pattern candidates selected marked buffer-name
     scroll-offset follow? alive?))

  (defstruct helm-candidate
    (display real source))

  ;; filter-map: map + filter #f results
  (def (filter-map f lst)
    (let loop ((l lst) (acc '()))
      (if (null? l) (reverse acc)
        (let ((v (f (car l))))
          (if v (loop (cdr l) (cons v acc))
            (loop (cdr l) acc))))))

  ;;;============================================================================
  ;;; Multi-match engine
  ;;;============================================================================

  (defstruct match-token (text negate? prefix?))

  ;; Fuzzy match: characters of query appear in order in candidate
  (def (fuzzy-match? query candidate)
    (let ((qlen (string-length query))
          (clen (string-length candidate)))
      (let loop ((qi 0) (ci 0))
        (cond
          ((>= qi qlen) #t)
          ((>= ci clen) #f)
          ((char-ci=? (string-ref query qi) (string-ref candidate ci))
           (loop (+ qi 1) (+ ci 1)))
          (else (loop qi (+ ci 1)))))))

  ;; Fuzzy score: higher = better match, -1 = no match
  (def (fuzzy-score query candidate)
    (let ((qlen (string-length query))
          (clen (string-length candidate)))
      (let loop ((qi 0) (ci 0) (score 0) (consecutive 0))
        (cond
          ((>= qi qlen) (+ score qlen))  ; matched all chars
          ((>= ci clen) -1)               ; ran out of candidate
          ((char-ci=? (string-ref query qi) (string-ref candidate ci))
           (loop (+ qi 1) (+ ci 1)
                 (+ score 1 consecutive
                    (if (= ci qi) 3 0))   ; bonus for same position
                 (+ consecutive 1)))
          (else (loop qi (+ ci 1) score 0))))))

  (def (parse-match-tokens pattern)
    (let ((words (filter (lambda (w) (> (string-length w) 0))
                         (string-split pattern #\space))))
      (map (lambda (word)
             (cond
               ((and (> (string-length word) 1)
                     (char=? (string-ref word 0) #\!))
                (make-match-token (substring word 1 (string-length word)) #t #f))
               ((and (> (string-length word) 1)
                     (char=? (string-ref word 0) #\^))
                (make-match-token (substring word 1 (string-length word)) #f #t))
               (else
                (make-match-token word #f #f))))
           words)))

  (def (token-matches? token candidate-str use-fuzzy?)
    (let* ((text (match-token-text token))
           (target-lower (string-downcase candidate-str))
           (text-lower (string-downcase text))
           (matches
             (cond
               ((match-token-prefix? token)
                (string-prefix? text-lower target-lower))
               (use-fuzzy?
                (fuzzy-match? text candidate-str))
               (else
                (string-contains target-lower text-lower)))))
      (if (match-token-negate? token)
        (not matches)
        (and matches #t))))

  (def (helm-multi-match? pattern candidate-str . rest)
    (let ((use-fuzzy? (if (pair? rest) (car rest) #f)))
      (let ((tokens (parse-match-tokens pattern)))
        (if (null? tokens)
          #t
          (let loop ((toks tokens))
            (cond
              ((null? toks) #t)
              ((not (token-matches? (car toks) candidate-str use-fuzzy?)) #f)
              (else (loop (cdr toks)))))))))

  (def (helm-multi-match pattern candidate-str . rest)
    (let ((use-fuzzy? (if (pair? rest) (car rest) #f)))
      (let ((tokens (parse-match-tokens pattern)))
        (if (null? tokens)
          0
          (let loop ((toks tokens) (total-score 0))
            (cond
              ((null? toks) total-score)
              (else
               (let ((tok (car toks)))
                 (if (match-token-negate? tok)
                   (let* ((text (match-token-text tok))
                          (target-lower (string-downcase candidate-str))
                          (text-lower (string-downcase text))
                          (matches (if use-fuzzy?
                                     (fuzzy-match? text candidate-str)
                                     (string-contains target-lower text-lower))))
                     (if matches -1
                       (loop (cdr toks) total-score)))
                   (let ((score (if (match-token-prefix? tok)
                                  (let* ((text-lower (string-downcase (match-token-text tok)))
                                         (target-lower (string-downcase candidate-str)))
                                    (if (string-prefix? text-lower target-lower)
                                      (+ 5 (string-length (match-token-text tok)))
                                      -1))
                                  (if use-fuzzy?
                                    (fuzzy-score (match-token-text tok) candidate-str)
                                    (let* ((text-lower (string-downcase (match-token-text tok)))
                                           (target-lower (string-downcase candidate-str)))
                                      (if (string-contains target-lower text-lower)
                                        (+ 3 (string-length (match-token-text tok))
                                           (if (string-prefix? text-lower target-lower) 5 0))
                                        -1))))))
                     (if (< score 0) -1
                       (loop (cdr toks) (+ total-score score)))))))))))))

  ;;;============================================================================
  ;;; Filtering
  ;;;============================================================================

  (def (helm-take lst n)
    (let loop ((l lst) (i 0) (acc '()))
      (if (or (null? l) (>= i n))
        (reverse acc)
        (loop (cdr l) (+ i 1) (cons (car l) acc)))))

  (def (helm-filter-source source pattern)
    (let* ((raw-candidates (parameterize ((*helm-current-pattern* pattern))
                             (let ((c (helm-source-candidates source)))
                               (if (procedure? c) (c) c))))
           (display-fn (helm-source-display-fn source))
           (real-fn (helm-source-real-fn source))
           (use-fuzzy? (helm-source-fuzzy? source))
           (limit (or (helm-source-candidate-limit source) *helm-candidate-limit*)))
      (let* ((scored
               (filter-map
                 (lambda (raw)
                   (let* ((display-str (if display-fn (display-fn raw) raw))
                          (real-val (if real-fn (real-fn raw) raw))
                          (score (if (string=? pattern "")
                                   0
                                   (helm-multi-match pattern display-str use-fuzzy?))))
                     (and (>= score 0)
                          (cons score (make-helm-candidate display-str real-val source)))))
                 raw-candidates))
             (sorted (if (string=? pattern "")
                       scored
                       (list-sort (lambda (a b) (> (car a) (car b))) scored)))
             (limited (if (> (length sorted) limit)
                        (helm-take sorted limit)
                        sorted)))
        (map cdr limited))))

  (def (helm-filter-all session)
    (let ((pattern (helm-session-pattern session))
          (sources (helm-session-sources session)))
      (let ((all-candidates
              (apply append
                (map (lambda (src)
                       (helm-filter-source src pattern))
                     sources))))
        (list->vector all-candidates))))

  ;;;============================================================================
  ;;; Candidate construction helpers
  ;;;============================================================================

  (def (make-helm-candidates strings source)
    (map (lambda (s)
           (make-helm-candidate s s source))
         strings))

  ;;;============================================================================
  ;;; Session management
  ;;;============================================================================

  (def *helm-sessions* '())
  (def *helm-last-session* #f)
  (def *helm-max-sessions* 10)

  (def (helm-sessions) *helm-sessions*)
  (def (helm-last-session) *helm-last-session*)

  (def (helm-session-store! session)
    (let ((name (helm-session-buffer-name session)))
      (set! *helm-last-session* session)
      (set! *helm-sessions*
        (cons (cons name session)
              (filter (lambda (pair) (not (string=? (car pair) name)))
                      *helm-sessions*)))
      (when (> (length *helm-sessions*) *helm-max-sessions*)
        (set! *helm-sessions* (helm-take *helm-sessions* *helm-max-sessions*)))))

  (def (helm-session-resume . rest)
    (let ((name (if (pair? rest) (car rest) #f)))
      (if name
        (let ((found (assoc name *helm-sessions*)))
          (and found (cdr found)))
        *helm-last-session*)))

  ;;;============================================================================
  ;;; Action dispatch
  ;;;============================================================================

  (def (helm-default-action source)
    (let ((actions (helm-source-actions source)))
      (and (pair? actions) (cdar actions))))

  (def (helm-run-action action candidates)
    (for-each
      (lambda (cand)
        (action (helm-candidate-real cand)))
      candidates))

  ;;;============================================================================
  ;;; Source constructors (convenience)
  ;;;============================================================================

  (def (make-simple-source name candidates-thunk action . rest)
    (let ((fuzzy? (if (pair? rest) (car rest) #t))
          (persistent-action (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) #f))
          (display-fn (if (and (pair? rest) (pair? (cdr rest)) (pair? (cddr rest))) (caddr rest) #f))
          (real-fn (if (and (pair? rest) (pair? (cdr rest)) (pair? (cddr rest)) (pair? (cdddr rest))) (cadddr rest) #f))
          (volatile? #f)
          (follow? #f))
      (make-helm-source
        name
        candidates-thunk
        (list (cons "Default" action))
        persistent-action
        display-fn
        real-fn
        fuzzy?
        volatile?
        *helm-candidate-limit*
        #f
        follow?)))

  ;;;============================================================================
  ;;; New session creation
  ;;;============================================================================

  (def (make-new-session sources . rest)
    (let ((buffer-name (if (pair? rest) (car rest) "*helm*"))
          (initial-input (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) "")))
      (let ((session (make-helm-session
                       sources
                       initial-input
                       (vector)
                       0
                       '()
                       buffer-name
                       0
                       #f
                       #t)))
        ;; Initial filter
        (helm-session-candidates-set! session (helm-filter-all session))
        session)))

  ;;;============================================================================
  ;;; Match highlighting
  ;;;============================================================================

  (def (fuzzy-match-positions pattern target)
    (let ((plen (string-length pattern))
          (tlen (string-length target)))
      (let loop ((pi 0) (ti 0) (acc '()))
        (cond
          ((>= pi plen) (reverse acc))
          ((>= ti tlen) '())
          ((char-ci=? (string-ref pattern pi) (string-ref target ti))
           (loop (+ pi 1) (+ ti 1) (cons ti acc)))
          (else
           (loop pi (+ ti 1) acc))))))

  (def (helm-match-positions pattern candidate-str . rest)
    (let ((use-fuzzy? (if (pair? rest) (car rest) #f)))
      (let ((tokens (parse-match-tokens pattern)))
        (if (null? tokens)
          '()
          (let loop ((toks tokens) (positions '()))
            (if (null? toks)
              ;; Deduplicate and sort
              (list-sort < (let dedup ((ps (list-sort < positions)) (acc '()))
                      (cond
                        ((null? ps) (reverse acc))
                        ((and (pair? acc) (= (car ps) (car acc)))
                         (dedup (cdr ps) acc))
                        (else (dedup (cdr ps) (cons (car ps) acc))))))
              (let ((tok (car toks)))
                (if (match-token-negate? tok)
                  (loop (cdr toks) positions)
                  (let* ((text (match-token-text tok))
                         (text-lower (string-downcase text))
                         (target-lower (string-downcase candidate-str))
                         (new-positions
                           (cond
                             ((match-token-prefix? tok)
                              (if (string-prefix? text-lower target-lower)
                                (let gen ((i 0) (acc '()))
                                  (if (>= i (string-length text))
                                    acc
                                    (gen (+ i 1) (cons i acc))))
                                '()))
                             (use-fuzzy?
                              (fuzzy-match-positions text candidate-str))
                             (else
                              (let ((pos (string-contains target-lower text-lower)))
                                (if pos
                                  (let gen ((i 0) (acc '()))
                                    (if (>= i (string-length text))
                                      acc
                                      (gen (+ i 1) (cons (+ pos i) acc))))
                                  '()))))))
                    (loop (cdr toks) (append positions new-positions)))))))))))

  ) ;; end library
