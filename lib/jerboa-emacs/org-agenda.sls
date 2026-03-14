#!chezscheme
;;; org-agenda.sls — Org agenda: daily/weekly views, TODO list, tag search, filtering.
;;;
;;; Ported from gerbil-emacs/org-agenda.ss
;;; Backend-agnostic.

(library (jerboa-emacs org-agenda)
  (export
    ;; Agenda item struct
    org-agenda-item? org-agenda-item-heading org-agenda-item-type
    org-agenda-item-date org-agenda-item-time-string
    org-agenda-item-file org-agenda-item-line
    make-org-agenda-item

    ;; Global state
    org-agenda-files org-agenda-files-set!
    org-agenda-span org-agenda-span-set!

    ;; Item collection
    org-collect-agenda-items
    org-timestamp-in-range?

    ;; Sorting
    org-agenda-sort-items

    ;; Formatting
    org-format-agenda-day
    org-format-agenda-item

    ;; Date arithmetic
    org-date-weekday
    org-make-date-ts
    org-advance-date-ts
    org-today-ts

    ;; Views
    org-agenda-daily-weekly
    org-agenda-todo-list
    org-agenda-tags-match
    org-agenda-search

    ;; Recurring items
    org-expand-recurring
    org-generate-occurrences

    ;; Stuck projects
    org-find-stuck-projects)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (only (std srfi srfi-13)
                string-trim string-contains string-prefix? string-join
                string-pad-right)
          (only (std srfi srfi-19)
                current-date date-year date-month date-day date-week-day
                date->time-utc time-utc->date
                make-time add-duration)
          (jerboa-emacs pregexp-compat)
          (jerboa-emacs core)
          (jerboa-emacs org-parse))

  ;;;============================================================================
  ;;; Agenda Item Structure
  ;;;============================================================================

  (defstruct org-agenda-item
    (heading type date time-string file line))

  ;;;============================================================================
  ;;; Global Agenda State
  ;;;============================================================================

  ;; org-agenda-files / org-agenda-files-set! come from (jerboa-emacs org-parse)

  (def *org-agenda-span* 7)
  (def (org-agenda-span) *org-agenda-span*)
  (def (org-agenda-span-set! v) (set! *org-agenda-span* v))

  (def *org-agenda-start-on-weekday* 1)

  ;;;============================================================================
  ;;; Agenda Item Collection
  ;;;============================================================================

  (def (org-collect-agenda-items text file-path date-from date-to)
    (let* ((headings (org-parse-buffer text))
           (items '()))
      (for-each
        (lambda (h)
          ;; Check SCHEDULED
          (let ((sched (org-heading-scheduled h)))
            (when (and sched (org-timestamp-in-range? sched date-from date-to))
              (set! items (cons (make-org-agenda-item
                                  h 'scheduled sched
                                  (org-timestamp-time-str sched)
                                  file-path (org-heading-line-number h))
                                items))))
          ;; Check DEADLINE
          (let ((dead (org-heading-deadline h)))
            (when (and dead (org-timestamp-in-range? dead date-from date-to))
              (set! items (cons (make-org-agenda-item
                                  h 'deadline dead
                                  (org-timestamp-time-str dead)
                                  file-path (org-heading-line-number h))
                                items)))))
        headings)
      (reverse items)))

  (def (pad-02 n)
    (if (< n 10)
      (string-append "0" (number->string n))
      (number->string n)))

  (def (org-timestamp-time-str ts)
    (if (and (org-timestamp-hour ts) (org-timestamp-minute ts))
      (string-append (pad-02 (org-timestamp-hour ts)) ":"
                     (pad-02 (org-timestamp-minute ts)))
      #f))

  (def (org-timestamp-in-range? ts date-from date-to)
    (and ts
         (let ((y (org-timestamp-year ts))
               (m (org-timestamp-month ts))
               (d (org-timestamp-day ts))
               (fy (org-timestamp-year date-from))
               (fm (org-timestamp-month date-from))
               (fd (org-timestamp-day date-from))
               (ty (org-timestamp-year date-to))
               (tm (org-timestamp-month date-to))
               (td (org-timestamp-day date-to)))
           (let ((ts-val (+ (* y 10000) (* m 100) d))
                 (from-val (+ (* fy 10000) (* fm 100) fd))
                 (to-val (+ (* ty 10000) (* tm 100) td)))
             (and (>= ts-val from-val)
                  (<= ts-val to-val))))))

  ;;;============================================================================
  ;;; Sorting
  ;;;============================================================================

  (def (org-agenda-sort-items items)
    (list-sort
      (lambda (a b)
        (let ((ta (or (org-agenda-item-time-string a) "99:99"))
              (tb (or (org-agenda-item-time-string b) "99:99")))
          (if (string=? ta tb)
            (let ((pa (or (org-heading-priority (org-agenda-item-heading a)) #\C))
                  (pb (or (org-heading-priority (org-agenda-item-heading b)) #\C)))
              (if (eqv? pa pb)
                (string<? (org-heading-title (org-agenda-item-heading a))
                          (org-heading-title (org-agenda-item-heading b)))
                (char<? pa pb)))
            (string<? ta tb)))))
      items)

  ;;;============================================================================
  ;;; Day Formatting
  ;;;============================================================================

  (def *org-agenda-day-names* (vector "Sunday" "Monday" "Tuesday" "Wednesday"
                                      "Thursday" "Friday" "Saturday"))

  (def (org-format-agenda-day date-ts items)
    (let* ((day-name (or (org-timestamp-day-name date-ts)
                         (let ((wday (org-date-weekday
                                       (org-timestamp-year date-ts)
                                       (org-timestamp-month date-ts)
                                       (org-timestamp-day date-ts))))
                           (vector-ref *org-agenda-day-names* wday))))
           (date-str (string-append
                       day-name " "
                       (number->string (org-timestamp-day date-ts)) " "
                       (org-month-name (org-timestamp-month date-ts)) " "
                       (number->string (org-timestamp-year date-ts))))
           (header (string-append date-str "\n"
                                  (make-string (string-length date-str) #\-)))
           (day-items (filter
                        (lambda (item)
                          (let ((d (org-agenda-item-date item)))
                            (and (= (org-timestamp-year d) (org-timestamp-year date-ts))
                                 (= (org-timestamp-month d) (org-timestamp-month date-ts))
                                 (= (org-timestamp-day d) (org-timestamp-day date-ts)))))
                        items))
           (sorted (org-agenda-sort-items day-items))
           (item-lines (map org-format-agenda-item sorted)))
      (if (null? item-lines)
        header
        (string-append header "\n" (string-join item-lines "\n")))))

  (def (org-format-agenda-item item)
    (let* ((h (org-agenda-item-heading item))
           (type-str (case (org-agenda-item-type item)
                       ((scheduled) "  Sched:")
                       ((deadline)  "  Dead: ")
                       ((timestamp) "       ")
                       (else "       ")))
           (time-str (let ((t (org-agenda-item-time-string item)))
                       (if t (string-append " " t) "      ")))
           (kw (or (org-heading-keyword h) ""))
           (title (org-heading-title h))
           (tags (let ((t (org-heading-tags h)))
                   (if (and t (not (null? t)))
                     (string-append " :" (string-join t ":") ":")
                     ""))))
      (string-append type-str time-str " "
                     (if (string=? kw "") "" (string-append kw " "))
                     title tags)))

  (def (org-month-name month)
    (vector-ref (vector "" "January" "February" "March" "April" "May" "June"
                        "July" "August" "September" "October" "November" "December")
                month))

  ;;;============================================================================
  ;;; Date Arithmetic
  ;;;============================================================================

  (def (org-date-weekday year month day)
    (let* ((m (if (< month 3) (+ month 12) month))
           (y (if (< month 3) (- year 1) year))
           (k (remainder y 100))
           (j (quotient y 100))
           (h (remainder (+ day
                            (quotient (* 13 (+ m 1)) 5)
                            k (quotient k 4)
                            (quotient j 4) (* -2 j))
                         7))
           (d (remainder (+ h 6) 7)))
      d))

  (def (org-make-date-ts year month day)
    (make-org-timestamp 'active year month day #f #f #f #f #f #f #f))

  (def (org-advance-date-ts date-ts days)
    (let* ((d (org-timestamp->date date-ts))
           (t (date->time-utc d))
           (dur (make-time 'time-duration 0 (* days 86400)))
           (new-t (add-duration t dur))
           (new-d (time-utc->date new-t 0)))
      (make-org-timestamp
        (org-timestamp-type date-ts)
        (date-year new-d) (date-month new-d) (date-day new-d)
        #f #f #f #f #f #f #f)))

  (def (org-today-ts)
    (let ((d (current-date)))
      (org-make-date-ts (date-year d) (date-month d) (date-day d))))

  ;;;============================================================================
  ;;; Agenda Views
  ;;;============================================================================

  (def (org-agenda-daily-weekly text file-path span)
    (let* ((today (org-today-ts))
           (end-date (org-advance-date-ts today (- span 1)))
           (items (org-collect-agenda-items text file-path today end-date))
           (days (let loop ((i 0) (acc '()))
                   (if (>= i span)
                     (reverse acc)
                     (let ((day-ts (org-advance-date-ts today i)))
                       (loop (+ i 1) (cons (org-format-agenda-day day-ts items) acc)))))))
      (string-join days "\n\n")))

  (def (org-agenda-todo-list text file-path)
    (let* ((headings (org-parse-buffer text))
           (todos (filter
                    (lambda (h)
                      (let ((kw (org-heading-keyword h)))
                        (and kw (not (member kw '("DONE" "CANCELLED"))))))
                    headings))
           (sorted (list-sort
                     (lambda (a b)
                       (let ((pa (or (org-heading-priority a) #\C))
                             (pb (or (org-heading-priority b) #\C)))
                         (if (eqv? pa pb)
                           (string<? (org-heading-title a)
                                     (org-heading-title b))
                           (char<? pa pb))))
                     todos)))
      (if (null? sorted)
        "No TODO items found."
        (string-append
          "Global TODO list\n"
          "================\n"
          (string-join
            (map (lambda (h)
                   (let ((kw (or (org-heading-keyword h) ""))
                         (title (org-heading-title h))
                         (tags (let ((t (org-heading-tags h)))
                                 (if (and t (not (null? t)))
                                   (string-append " :" (string-join t ":") ":")
                                   ""))))
                     (string-append "  " kw " " title tags)))
                 sorted)
            "\n")))))

  (def (org-agenda-tags-match text file-path tag-expr)
    (let* ((headings (org-parse-buffer text))
           (matching (filter
                       (lambda (h)
                         (org-heading-match-tags? h tag-expr))
                       headings)))
      (if (null? matching)
        (string-append "No matches for tag: " tag-expr)
        (string-append
          "Tags match: " tag-expr "\n"
          (make-string (+ 13 (string-length tag-expr)) #\=) "\n"
          (string-join
            (map (lambda (h)
                   (let ((level (org-heading-stars h))
                         (kw (or (org-heading-keyword h) ""))
                         (title (org-heading-title h))
                         (tags (let ((t (org-heading-tags h)))
                                 (if (and t (not (null? t)))
                                   (string-append " :" (string-join t ":") ":")
                                   ""))))
                     (string-append "  " (make-string level #\*) " "
                                    (if (string=? kw "") "" (string-append kw " "))
                                    title tags)))
                 matching)
            "\n")))))

  (def (org-agenda-search text file-path query)
    (let* ((headings (org-parse-buffer text))
           (query-lower (string-downcase query))
           (matching (filter
                       (lambda (h)
                         (string-contains (string-downcase (org-heading-title h))
                                          query-lower))
                       headings)))
      (if (null? matching)
        (string-append "No matches for: " query)
        (string-append
          "Search: " query "\n"
          (make-string (+ 8 (string-length query)) #\=) "\n"
          (string-join
            (map (lambda (h)
                   (let ((kw (or (org-heading-keyword h) ""))
                         (title (org-heading-title h)))
                     (string-append "  "
                                    (if (string=? kw "") "" (string-append kw " "))
                                    title)))
                 matching)
            "\n")))))

  ;;;============================================================================
  ;;; Recurring Items
  ;;;============================================================================

  (def (org-expand-recurring heading date-from date-to)
    (let ((items '()))
      (let ((sched (org-heading-scheduled heading)))
        (when (and sched (org-timestamp-repeater sched))
          (let ((occurrences (org-generate-occurrences sched date-from date-to)))
            (for-each
              (lambda (ts)
                (set! items (cons (make-org-agenda-item
                                    heading 'scheduled ts
                                    (org-timestamp-time-str ts)
                                    (org-heading-file-path heading)
                                    (org-heading-line-number heading))
                                  items)))
              occurrences))))
      (let ((dead (org-heading-deadline heading)))
        (when (and dead (org-timestamp-repeater dead))
          (let ((occurrences (org-generate-occurrences dead date-from date-to)))
            (for-each
              (lambda (ts)
                (set! items (cons (make-org-agenda-item
                                    heading 'deadline ts
                                    (org-timestamp-time-str ts)
                                    (org-heading-file-path heading)
                                    (org-heading-line-number heading))
                                  items)))
              occurrences))))
      (reverse items)))

  (def (org-generate-occurrences ts date-from date-to)
    (let ((repeater (org-timestamp-repeater ts)))
      (if (not repeater)
        '()
        (let* ((m (pregexp-match "([.+]+)(\\d+)([hdwmy])" repeater))
               (amount (if m (string->number (list-ref m 2)) 1))
               (unit (if m (list-ref m 3) "d"))
               (days-per (cond
                           ((string=? unit "d") amount)
                           ((string=? unit "w") (* amount 7))
                           ((string=? unit "m") (* amount 30))
                           ((string=? unit "y") (* amount 365))
                           (else amount))))
          (let loop ((current ts) (acc '()) (safety 0))
            (if (> safety 365)
              (reverse acc)
              (if (org-timestamp-in-range? current date-from date-to)
                (loop (org-advance-date-ts current days-per)
                      (cons current acc)
                      (+ safety 1))
                (let ((cval (+ (* (org-timestamp-year current) 10000)
                               (* (org-timestamp-month current) 100)
                               (org-timestamp-day current)))
                      (tval (+ (* (org-timestamp-year date-to) 10000)
                               (* (org-timestamp-month date-to) 100)
                               (org-timestamp-day date-to))))
                  (if (> cval tval)
                    (reverse acc)
                    (loop (org-advance-date-ts current days-per)
                          acc
                          (+ safety 1)))))))))))

  ;;;============================================================================
  ;;; Stuck Projects Detection
  ;;;============================================================================

  (def (org-find-stuck-projects text)
    (let* ((headings (org-parse-buffer text))
           (total (length headings)))
      (filter
        (lambda (h)
          (let* ((level (org-heading-stars h))
                 (idx (agenda-list-index h headings))
                 (has-children? #f)
                 (has-todo-child? #f))
            (when idx
              (let loop ((i (+ idx 1)))
                (when (< i total)
                  (let* ((child (list-ref headings i))
                         (child-level (org-heading-stars child)))
                    (cond
                      ((<= child-level level) (void))
                      ((= child-level (+ level 1))
                       (set! has-children? #t)
                       (let ((kw (org-heading-keyword child)))
                         (when (and kw (member kw '("TODO" "NEXT")))
                           (set! has-todo-child? #t)))
                       (loop (+ i 1)))
                      (else (loop (+ i 1))))))))
            (and has-children? (not has-todo-child?))))
        headings)))

  (def (agenda-list-index item lst)
    (let loop ((i 0) (l lst))
      (cond
        ((null? l) #f)
        ((eq? (car l) item) i)
        (else (loop (+ i 1) (cdr l))))))

  ) ;; end library
