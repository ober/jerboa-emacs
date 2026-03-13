#!chezscheme
;;; vtscreen.sls — VT100 virtual terminal screen buffer
;;;
;;; Ported from gerbil-emacs/vtscreen.ss
;;; Maintains a rows x cols character grid. Processes ANSI/VT100 escape
;;; sequences for cursor movement, screen clearing, and scrolling.

(library (jerboa-emacs vtscreen)
  (export new-vtscreen
          vtscreen-feed!
          vtscreen-render
          vtscreen-resize!
          vtscreen-rows
          vtscreen-cols
          vtscreen-cursor-row
          vtscreen-cursor-col
          vtscreen-alt-screen?)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1-)
          (jerboa core)
          (jerboa runtime))

  ;;; ========================================================================
  ;;; Screen data structure
  ;;; ========================================================================

  (defstruct vtscreen
    (rows cols grid
     cursor-row cursor-col
     saved-row saved-col
     scroll-top scroll-bottom
     wrap-pending alt-screen?
     last-char
     parse-state csi-params osc-buf))

  (def (new-vtscreen (rows 24) (cols 80))
    (let ((grid (make-vector rows #f)))
      (let loop ((r 0))
        (when (< r rows)
          (vector-set! grid r (make-vector cols #\space))
          (loop (+ r 1))))
      (make-vtscreen rows cols grid 0 0 0 0 0 (- rows 1) #f #f #\space 'normal "" "")))

  (def (vtscreen-resize! vt new-rows new-cols)
    (let* ((old-rows (vtscreen-rows vt))
           (old-cols (vtscreen-cols vt))
           (old-grid (vtscreen-grid vt))
           (new-grid (make-vector new-rows #f)))
      (let loop ((r 0))
        (when (< r new-rows)
          (let ((new-row (make-vector new-cols #\space)))
            (when (< r old-rows)
              (let ((old-row (vector-ref old-grid r)))
                (let copy ((c 0))
                  (when (and (< c new-cols) (< c old-cols))
                    (vector-set! new-row c (vector-ref old-row c))
                    (copy (+ c 1))))))
            (vector-set! new-grid r new-row))
          (loop (+ r 1))))
      (vtscreen-grid-set! vt new-grid)
      (vtscreen-rows-set! vt new-rows)
      (vtscreen-cols-set! vt new-cols)
      (vtscreen-cursor-row-set! vt
        (min (vtscreen-cursor-row vt) (- new-rows 1)))
      (vtscreen-cursor-col-set! vt
        (min (vtscreen-cursor-col vt) (- new-cols 1)))
      (vtscreen-scroll-top-set! vt 0)
      (vtscreen-scroll-bottom-set! vt (- new-rows 1))
      (vtscreen-wrap-pending-set! vt #f)))

  ;;; ========================================================================
  ;;; Grid operations
  ;;; ========================================================================

  (def (grid-clear-row! grid row cols (start-col 0))
    (let ((row-vec (vector-ref grid row)))
      (let loop ((c start-col))
        (when (< c cols)
          (vector-set! row-vec c #\space)
          (loop (+ c 1))))))

  (def (grid-clear-row-left! grid row end-col)
    (let ((row-vec (vector-ref grid row)))
      (let loop ((c 0))
        (when (<= c end-col)
          (vector-set! row-vec c #\space)
          (loop (+ c 1))))))

  (def (grid-clear-region! grid start-row end-row cols)
    (let loop ((r start-row))
      (when (<= r end-row)
        (grid-clear-row! grid r cols)
        (loop (+ r 1)))))

  (def (grid-scroll-up! grid top bottom cols (n 1))
    (let loop ((count 0))
      (when (< count n)
        (let shift ((r top))
          (when (< r bottom)
            (vector-set! grid r (vector-ref grid (+ r 1)))
            (shift (+ r 1))))
        (vector-set! grid bottom (make-vector cols #\space))
        (loop (+ count 1)))))

  (def (grid-scroll-down! grid top bottom cols (n 1))
    (let loop ((count 0))
      (when (< count n)
        (let shift ((r bottom))
          (when (> r top)
            (vector-set! grid r (vector-ref grid (- r 1)))
            (shift (- r 1))))
        (vector-set! grid top (make-vector cols #\space))
        (loop (+ count 1)))))

  ;;; ========================================================================
  ;;; Feed data to the virtual screen
  ;;; ========================================================================

  (def (vtscreen-feed! vt data)
    (let ((len (string-length data)))
      (let loop ((i 0))
        (when (< i len)
          (let ((ch (string-ref data i)))
            (case (vtscreen-parse-state vt)
              ((normal)
               (let ((code (char->integer ch)))
                 (cond
                   ((= code 27)
                    (vtscreen-parse-state-set! vt 'esc))
                   ((= code #x9B)
                    (vtscreen-parse-state-set! vt 'csi)
                    (vtscreen-csi-params-set! vt ""))
                   ((= code #x9D)
                    (vtscreen-parse-state-set! vt 'osc)
                    (vtscreen-osc-buf-set! vt ""))
                   ((= code #x90)
                    (vtscreen-parse-state-set! vt 'dcs))
                   ((= code #x9C) (void))
                   ((and (>= code #x80) (<= code #x9F)) (void))
                   ((= code 7) (void))
                   ((= code 8)
                    (when (> (vtscreen-cursor-col vt) 0)
                      (vtscreen-cursor-col-set! vt
                        (- (vtscreen-cursor-col vt) 1))))
                   ((= code 9)
                    (let ((col (vtscreen-cursor-col vt)))
                      (vtscreen-cursor-col-set! vt
                        (min (- (vtscreen-cols vt) 1)
                             (* (+ (quotient col 8) 1) 8)))))
                   ((or (= code 10) (= code 11) (= code 12))
                    (vtscreen-wrap-pending-set! vt #f)
                    (vtscreen-cursor-col-set! vt 0)
                    (vt-linefeed! vt))
                   ((= code 13)
                    (vtscreen-wrap-pending-set! vt #f)
                    (vtscreen-cursor-col-set! vt 0))
                   ((or (= code 14) (= code 15)) (void))
                   ((< code 32) (void))
                   (else
                    (when (vtscreen-wrap-pending vt)
                      (vtscreen-wrap-pending-set! vt #f)
                      (vtscreen-cursor-col-set! vt 0)
                      (vt-linefeed! vt))
                    (let ((row (vtscreen-cursor-row vt))
                          (col (vtscreen-cursor-col vt))
                          (cols (vtscreen-cols vt)))
                      (when (and (>= row 0) (< row (vtscreen-rows vt))
                                 (>= col 0) (< col cols))
                        (vector-set! (vector-ref (vtscreen-grid vt) row) col ch))
                      (vtscreen-last-char-set! vt ch)
                      (if (< col (- cols 1))
                        (vtscreen-cursor-col-set! vt (+ col 1))
                        (vtscreen-wrap-pending-set! vt #t)))))))

              ((esc)
               (cond
                 ((char=? ch #\[)
                  (vtscreen-parse-state-set! vt 'csi)
                  (vtscreen-csi-params-set! vt ""))
                 ((char=? ch #\])
                  (vtscreen-parse-state-set! vt 'osc)
                  (vtscreen-osc-buf-set! vt ""))
                 ((char=? ch #\7)
                  (vtscreen-saved-row-set! vt (vtscreen-cursor-row vt))
                  (vtscreen-saved-col-set! vt (vtscreen-cursor-col vt))
                  (vtscreen-parse-state-set! vt 'normal))
                 ((char=? ch #\8)
                  (vtscreen-cursor-row-set! vt (vtscreen-saved-row vt))
                  (vtscreen-cursor-col-set! vt (vtscreen-saved-col vt))
                  (vtscreen-parse-state-set! vt 'normal))
                 ((char=? ch #\M)
                  (vt-reverse-index! vt)
                  (vtscreen-parse-state-set! vt 'normal))
                 ((char=? ch #\P)
                  (vtscreen-parse-state-set! vt 'dcs))
                 ((char=? ch #\N)
                  (vtscreen-parse-state-set! vt 'ss-skip))
                 ((char=? ch #\O)
                  (vtscreen-parse-state-set! vt 'ss-skip))
                 ((char=? ch #\D)
                  (vt-linefeed! vt)
                  (vtscreen-parse-state-set! vt 'normal))
                 ((char=? ch #\E)
                  (vtscreen-cursor-col-set! vt 0)
                  (vt-linefeed! vt)
                  (vtscreen-parse-state-set! vt 'normal))
                 ((char=? ch #\c)
                  (let ((rows (vtscreen-rows vt))
                        (cols (vtscreen-cols vt)))
                    (grid-clear-region! (vtscreen-grid vt) 0 (- rows 1) cols)
                    (vtscreen-cursor-row-set! vt 0)
                    (vtscreen-cursor-col-set! vt 0)
                    (vtscreen-scroll-top-set! vt 0)
                    (vtscreen-scroll-bottom-set! vt (- rows 1))
                    (vtscreen-wrap-pending-set! vt #f)
                    (vtscreen-alt-screen?-set! vt #f)
                    (vtscreen-parse-state-set! vt 'normal)))
                 ((memv ch '(#\( #\) #\* #\+))
                  (vtscreen-parse-state-set! vt 'charset-skip))
                 (else
                  (vtscreen-parse-state-set! vt 'normal))))

              ((csi)
               (cond
                 ((and (char>=? ch #\space) (char<=? ch #\?))
                  (vtscreen-csi-params-set! vt
                    (string-append (vtscreen-csi-params vt) (string ch))))
                 ((and (char>=? ch #\@) (char<=? ch #\~))
                  (vt-csi-dispatch! vt ch (vtscreen-csi-params vt))
                  (vtscreen-parse-state-set! vt 'normal))
                 (else
                  (vtscreen-parse-state-set! vt 'normal))))

              ((osc)
               (cond
                 ((char=? ch (integer->char 7))
                  (vtscreen-parse-state-set! vt 'normal))
                 ((char=? ch (integer->char 27))
                  (vtscreen-parse-state-set! vt 'normal))
                 (else (void))))

              ((charset-skip)
               (vtscreen-parse-state-set! vt 'normal))

              ((dcs)
               (cond
                 ((char=? ch (integer->char #x9C))
                  (vtscreen-parse-state-set! vt 'normal))
                 ((char=? ch (integer->char 27))
                  (vtscreen-parse-state-set! vt 'dcs-esc))
                 (else (void))))

              ((dcs-esc)
               (vtscreen-parse-state-set! vt 'normal))

              ((ss-skip)
               (vtscreen-parse-state-set! vt 'normal))

              (else
               (vtscreen-parse-state-set! vt 'normal))))
          (loop (+ i 1))))))

  ;;; ========================================================================
  ;;; Cursor movement helpers
  ;;; ========================================================================

  (def (vt-linefeed! vt)
    (let ((row (vtscreen-cursor-row vt))
          (bottom (vtscreen-scroll-bottom vt)))
      (if (>= row bottom)
        (grid-scroll-up! (vtscreen-grid vt)
                          (vtscreen-scroll-top vt)
                          bottom
                          (vtscreen-cols vt))
        (vtscreen-cursor-row-set! vt (+ row 1)))))

  (def (vt-reverse-index! vt)
    (let ((row (vtscreen-cursor-row vt))
          (top (vtscreen-scroll-top vt)))
      (if (<= row top)
        (grid-scroll-down! (vtscreen-grid vt)
                            top
                            (vtscreen-scroll-bottom vt)
                            (vtscreen-cols vt))
        (vtscreen-cursor-row-set! vt (- row 1)))))

  ;;; ========================================================================
  ;;; CSI command dispatch
  ;;; ========================================================================

  (def (parse-csi-params param-str)
    (let ((s (if (and (> (string-length param-str) 0)
                      (char=? (string-ref param-str 0) #\?))
               (substring param-str 1 (string-length param-str))
               param-str)))
      (if (string=? s "")
        '()
        (let loop ((i 0) (start 0) (acc '()))
          (cond
            ((>= i (string-length s))
             (reverse (cons (let ((sub (substring s start i)))
                              (if (string=? sub "") 0
                                (or (string->number sub) 0)))
                            acc)))
            ((char=? (string-ref s i) #\;)
             (loop (+ i 1) (+ i 1)
                   (cons (let ((sub (substring s start i)))
                           (if (string=? sub "") 0
                             (or (string->number sub) 0)))
                         acc)))
            (else (loop (+ i 1) start acc)))))))

  (def (csi-param params idx default)
    (let ((v (if (< idx (length params)) (list-ref params idx) 0)))
      (if (= v 0) default v)))

  (def (is-private-mode? param-str)
    (and (> (string-length param-str) 0)
         (char=? (string-ref param-str 0) #\?)))

  (def (vt-csi-dispatch! vt final param-str)
    (vtscreen-wrap-pending-set! vt #f)
    (let ((params (parse-csi-params param-str))
          (rows (vtscreen-rows vt))
          (cols (vtscreen-cols vt))
          (grid (vtscreen-grid vt)))
      (case final
        ((#\H #\f)
         (let ((row (- (csi-param params 0 1) 1))
               (col (- (csi-param params 1 1) 1)))
           (vtscreen-cursor-row-set! vt (max 0 (min row (- rows 1))))
           (vtscreen-cursor-col-set! vt (max 0 (min col (- cols 1))))))

        ((#\A)
         (let ((n (csi-param params 0 1)))
           (vtscreen-cursor-row-set! vt
             (max (vtscreen-scroll-top vt)
                  (- (vtscreen-cursor-row vt) n)))))

        ((#\B)
         (let ((n (csi-param params 0 1)))
           (vtscreen-cursor-row-set! vt
             (min (vtscreen-scroll-bottom vt)
                  (+ (vtscreen-cursor-row vt) n)))))

        ((#\C)
         (let ((n (csi-param params 0 1)))
           (vtscreen-cursor-col-set! vt
             (min (- cols 1) (+ (vtscreen-cursor-col vt) n)))))

        ((#\D)
         (let ((n (csi-param params 0 1)))
           (vtscreen-cursor-col-set! vt
             (max 0 (- (vtscreen-cursor-col vt) n)))))

        ((#\E)
         (let ((n (csi-param params 0 1)))
           (vtscreen-cursor-col-set! vt 0)
           (vtscreen-cursor-row-set! vt
             (min (vtscreen-scroll-bottom vt)
                  (+ (vtscreen-cursor-row vt) n)))))

        ((#\F)
         (let ((n (csi-param params 0 1)))
           (vtscreen-cursor-col-set! vt 0)
           (vtscreen-cursor-row-set! vt
             (max (vtscreen-scroll-top vt)
                  (- (vtscreen-cursor-row vt) n)))))

        ((#\G)
         (let ((col (- (csi-param params 0 1) 1)))
           (vtscreen-cursor-col-set! vt
             (max 0 (min col (- cols 1))))))

        ((#\d)
         (let ((row (- (csi-param params 0 1) 1)))
           (vtscreen-cursor-row-set! vt
             (max 0 (min row (- rows 1))))))

        ((#\J)
         (let ((mode (csi-param params 0 0))
               (crow (vtscreen-cursor-row vt))
               (ccol (vtscreen-cursor-col vt)))
           (cond
             ((= mode 0)
              (grid-clear-row! grid crow cols ccol)
              (grid-clear-region! grid (+ crow 1) (- rows 1) cols))
             ((= mode 1)
              (grid-clear-region! grid 0 (- crow 1) cols)
              (grid-clear-row-left! grid crow ccol))
             ((or (= mode 2) (= mode 3))
              (vtscreen-alt-screen?-set! vt #t)
              (grid-clear-region! grid 0 (- rows 1) cols)))))

        ((#\K)
         (let ((mode (csi-param params 0 0))
               (crow (vtscreen-cursor-row vt))
               (ccol (vtscreen-cursor-col vt)))
           (cond
             ((= mode 0)
              (grid-clear-row! grid crow cols ccol))
             ((= mode 1)
              (grid-clear-row-left! grid crow ccol))
             ((= mode 2)
              (grid-clear-row! grid crow cols)))))

        ((#\r)
         (let ((top (- (csi-param params 0 1) 1))
               (bot (- (csi-param params 1 rows) 1)))
           (vtscreen-scroll-top-set! vt (max 0 (min top (- rows 1))))
           (vtscreen-scroll-bottom-set! vt (max 0 (min bot (- rows 1))))
           (vtscreen-cursor-row-set! vt 0)
           (vtscreen-cursor-col-set! vt 0)))

        ((#\L)
         (let ((n (csi-param params 0 1))
               (crow (vtscreen-cursor-row vt))
               (bottom (vtscreen-scroll-bottom vt)))
           (when (<= crow bottom)
             (grid-scroll-down! grid crow bottom cols n))))

        ((#\M)
         (let ((n (csi-param params 0 1))
               (crow (vtscreen-cursor-row vt))
               (bottom (vtscreen-scroll-bottom vt)))
           (when (<= crow bottom)
             (grid-scroll-up! grid crow bottom cols n))))

        ((#\S)
         (let ((n (csi-param params 0 1)))
           (grid-scroll-up! grid
                            (vtscreen-scroll-top vt)
                            (vtscreen-scroll-bottom vt)
                            cols n)))

        ((#\T)
         (let ((n (csi-param params 0 1)))
           (grid-scroll-down! grid
                              (vtscreen-scroll-top vt)
                              (vtscreen-scroll-bottom vt)
                              cols n)))

        ((#\@)
         (let* ((n (csi-param params 0 1))
                (crow (vtscreen-cursor-row vt))
                (ccol (vtscreen-cursor-col vt))
                (row-vec (vector-ref grid crow)))
           (let shift ((c (- cols 1)))
             (when (>= c (+ ccol n))
               (vector-set! row-vec c (vector-ref row-vec (- c n)))
               (shift (- c 1))))
           (let clear ((c ccol))
             (when (< c (min (+ ccol n) cols))
               (vector-set! row-vec c #\space)
               (clear (+ c 1))))))

        ((#\P)
         (let* ((n (csi-param params 0 1))
                (crow (vtscreen-cursor-row vt))
                (ccol (vtscreen-cursor-col vt))
                (row-vec (vector-ref grid crow)))
           (let shift ((c ccol))
             (when (< c (- cols n))
               (vector-set! row-vec c (vector-ref row-vec (+ c n)))
               (shift (+ c 1))))
           (let clear ((c (max ccol (- cols n))))
             (when (< c cols)
               (vector-set! row-vec c #\space)
               (clear (+ c 1))))))

        ((#\X)
         (let* ((n (csi-param params 0 1))
                (crow (vtscreen-cursor-row vt))
                (ccol (vtscreen-cursor-col vt))
                (row-vec (vector-ref grid crow)))
           (let clear ((c ccol))
             (when (and (< c (+ ccol n)) (< c cols))
               (vector-set! row-vec c #\space)
               (clear (+ c 1))))))

        ((#\s)
         (vtscreen-saved-row-set! vt (vtscreen-cursor-row vt))
         (vtscreen-saved-col-set! vt (vtscreen-cursor-col vt)))

        ((#\u)
         (vtscreen-cursor-row-set! vt (vtscreen-saved-row vt))
         (vtscreen-cursor-col-set! vt (vtscreen-saved-col vt)))

        ((#\m) (void))

        ((#\h #\l)
         (when (is-private-mode? param-str)
           (let ((ps (parse-csi-params param-str)))
             (for-each (lambda (p)
                         (when (or (= p 1049) (= p 1047))
                           (vtscreen-alt-screen?-set! vt (char=? final #\h))))
                       ps))))

        ((#\b)
         (let ((n (csi-param params 0 1))
               (ch (vtscreen-last-char vt)))
           (let rep ((j 0))
             (when (< j n)
               (let ((row (vtscreen-cursor-row vt))
                     (col (vtscreen-cursor-col vt)))
                 (when (and (>= row 0) (< row rows)
                            (>= col 0) (< col cols))
                   (vector-set! (vector-ref grid row) col ch))
                 (if (< col (- cols 1))
                   (vtscreen-cursor-col-set! vt (+ col 1))
                   (begin
                     (vtscreen-cursor-col-set! vt 0)
                     (vt-linefeed! vt))))
               (rep (+ j 1))))))

        ((#\n) (void))
        ((#\c) (void))
        (else (void)))))

  ;;; ========================================================================
  ;;; Render the screen to a string
  ;;; ========================================================================

  (def (vtscreen-render vt)
    (let* ((rows (vtscreen-rows vt))
           (cols (vtscreen-cols vt))
           (grid (vtscreen-grid vt)))
      (let ((out (open-output-string)))
        (let ((last-nonempty -1))
          (let scan ((r (- rows 1)))
            (when (>= r 0)
              (if (row-empty? (vector-ref grid r) cols)
                (scan (- r 1))
                (set! last-nonempty r))))
          (let loop ((r 0))
            (when (<= r last-nonempty)
              (when (> r 0) (write-char #\newline out))
              (let* ((row-vec (vector-ref grid r))
                     (last-col (let scan ((c (- cols 1)))
                                 (if (and (>= c 0)
                                          (char=? (vector-ref row-vec c) #\space))
                                   (scan (- c 1))
                                   c))))
                (let col-loop ((c 0))
                  (when (<= c last-col)
                    (write-char (vector-ref row-vec c) out)
                    (col-loop (+ c 1)))))
              (loop (+ r 1)))))
        (get-output-string out))))

  (def (row-empty? row-vec cols)
    (let loop ((c 0))
      (if (>= c cols) #t
        (if (char=? (vector-ref row-vec c) #\space)
          (loop (+ c 1))
          #f))))

  ) ;; end library
