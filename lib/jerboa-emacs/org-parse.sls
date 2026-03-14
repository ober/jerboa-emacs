#!chezscheme
;;; org-parse.sls — Org-mode core parser: timestamps, headings, properties, planning, clocks.
;;;
;;; Ported from gerbil-emacs/org-parse.ss
;;; Pure logic module: no editor/Scintilla dependencies.

(library (jerboa-emacs org-parse)
  (export org-timestamp?
          org-timestamp-type org-timestamp-year org-timestamp-month org-timestamp-day
          org-timestamp-day-name org-timestamp-hour org-timestamp-minute
          org-timestamp-end-hour org-timestamp-end-minute
          org-timestamp-repeater org-timestamp-warning
          make-org-timestamp
          org-parse-timestamp
          org-timestamp->string
          org-timestamp->date
          org-timestamp-elapsed
          org-current-timestamp-string
          org-current-date-string
          org-heading?
          org-heading-stars org-heading-keyword org-heading-priority
          org-heading-title org-heading-tags
          org-heading-scheduled org-heading-deadline org-heading-closed
          org-heading-properties org-heading-clocks
          org-heading-line-number org-heading-file-path
          make-org-heading
          org-parse-heading-line
          org-split-tags
          org-split-keyword
          org-split-priority
          org-parse-planning-line
          org-planning-line?
          org-parse-properties
          org-properties-drawer?
          org-drawer-end?
          org-parse-clock-line
          org-clock-line?
          org-parse-buffer
          org-parse-buffer-settings
          org-parse-todo-keywords
          org-parse-tags-setting
          org-heading-match-tags?
          org-parse-tag-expr
          org-apply-repeater
          org-advance-timestamp
          org-copy-timestamp
          org-timestamp>=?
          org-parse-file
          read-file-string
          org-heading-line?
          org-heading-stars-of-line
          org-find-subtree-end-in-text
          org-src-block-line?
          org-src-block-end?
          org-block-begin?
          org-block-end?
          org-keyword-line?
          org-comment-line?
          org-table-line?
          string-prefix-ci?
          any-pred
          every-pred
          *day-names*
          *org-todo-keywords*
          *org-done-keywords*
          org-agenda-files org-agenda-files-set!
          *org-buffer-settings*)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std sort)
          (std string)
          (only (std srfi srfi-19)
                make-date date->string current-date
                date-year date-month date-day
                date-hour date-minute date-second
                date->time-utc time-difference time-second
                date-week-day
                make-time time-utc)
          (jerboa-emacs pregexp-compat))

  ;;;============================================================================
  ;;; Org Timestamp
  ;;;============================================================================

  (defstruct org-timestamp
    (type         ; 'active | 'inactive
     year month day
     day-name     ; string or #f ("Mon", "Tue")
     hour minute  ; integers or #f
     end-hour end-minute ; integers or #f (time ranges)
     repeater     ; string or #f ("+1w", ".+1d", "++1m")
     warning))    ; string or #f ("-3d")

  ;; Day-name abbreviations for rendering
  (def *day-names* (vector "Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"))

  (def (org-parse-timestamp str)
    (let ((len (string-length str)))
      (if (< len 12)
        #f
        (let ((first-char (string-ref str 0)))
          (cond
            ((char=? first-char #\<)
             (org-parse-timestamp-with-type str len 'active #\>))
            ((char=? first-char #\[)
             (org-parse-timestamp-with-type str len 'inactive #\]))
            (else #f))))))

  (def (org-parse-timestamp-with-type str len type close-char)
    (let ((close-pos (let loop ((i (- len 1)))
                       (cond ((< i 0) #f)
                             ((char=? (string-ref str i) close-char) i)
                             (else (loop (- i 1)))))))
      (if (not close-pos)
        #f
        (let ((inner (substring str 1 close-pos)))
          (org-parse-timestamp-inner type inner)))))

  (def (org-parse-timestamp-inner type inner)
    (let ((m (pregexp-match
              "^(\\d{4})-(\\d{2})-(\\d{2})(?:\\s+([A-Za-z]+))?(?:\\s+(\\d{1,2}):(\\d{2})(?:-(\\d{1,2}):(\\d{2}))?)?(.*)$"
              inner)))
      (if (not m)
        #f
        (let* ((year   (string->number (list-ref m 1)))
               (month  (string->number (list-ref m 2)))
               (day    (string->number (list-ref m 3)))
               (day-name (list-ref m 4))
               (hour   (and (list-ref m 5) (string->number (list-ref m 5))))
               (minute (and (list-ref m 6) (string->number (list-ref m 6))))
               (end-hour   (and (list-ref m 7) (string->number (list-ref m 7))))
               (end-minute (and (list-ref m 8) (string->number (list-ref m 8))))
               (rest (or (list-ref m 9) ""))
               ;; Parse repeater and warning from rest
               (repeater (let ((rm (pregexp-match "\\s+(\\+\\+?|\\.\\+)(\\d+[hdwmy])" rest)))
                           (and rm (string-append (list-ref rm 1) (list-ref rm 2)))))
               (warning  (let ((wm (pregexp-match "\\s+-(\\d+[hdwmy])" rest)))
                           (and wm (string-append "-" (list-ref wm 1))))))
          (make-org-timestamp type year month day day-name
                              hour minute end-hour end-minute
                              repeater warning)))))

  (def (org-timestamp->string ts)
    (let* ((open  (if (eq? (org-timestamp-type ts) 'active) "<" "["))
           (close (if (eq? (org-timestamp-type ts) 'active) ">" "]"))
           (date-part (string-append
                       (number->string (org-timestamp-year ts)) "-"
                       (pad-02 (org-timestamp-month ts)) "-"
                       (pad-02 (org-timestamp-day ts))))
           (day-part (if (org-timestamp-day-name ts)
                       (string-append " " (org-timestamp-day-name ts))
                       ""))
           (time-part (if (org-timestamp-hour ts)
                        (string-append " " (pad-02 (org-timestamp-hour ts))
                                       ":" (pad-02 (org-timestamp-minute ts)))
                        ""))
           (end-time-part (if (org-timestamp-end-hour ts)
                            (string-append "-" (pad-02 (org-timestamp-end-hour ts))
                                           ":" (pad-02 (org-timestamp-end-minute ts)))
                            ""))
           (rep-part (if (org-timestamp-repeater ts)
                       (string-append " " (org-timestamp-repeater ts))
                       ""))
           (warn-part (if (org-timestamp-warning ts)
                        (string-append " " (org-timestamp-warning ts))
                        "")))
      (string-append open date-part day-part time-part end-time-part
                     rep-part warn-part close)))

  (def (pad-02 n)
    (if (< n 10)
      (string-append "0" (number->string n))
      (number->string n)))

  (def (org-timestamp->date ts)
    (make-date 0  ; nanoseconds
               0  ; seconds
               (or (org-timestamp-minute ts) 0)
               (or (org-timestamp-hour ts) 0)
               (org-timestamp-day ts)
               (org-timestamp-month ts)
               (org-timestamp-year ts)
               0)) ; timezone offset

  (def (org-timestamp-elapsed start end)
    (let* ((d1 (org-timestamp->date start))
           (d2 (org-timestamp->date end))
           (t1 (date->time-utc d1))
           (t2 (date->time-utc d2))
           (diff (time-difference t2 t1))
           (secs (time-second diff))
           (h (quotient secs 3600))
           (m (quotient (remainder secs 3600) 60)))
      (string-append (number->string h) ":"
                     (if (< m 10) "0" "") (number->string m))))

  (def (org-current-timestamp-string (active? #t))
    (let* ((d (current-date))
           (open (if active? "<" "["))
           (close (if active? ">" "]"))
           (day-idx (date-week-day d))
           (day-abbr (vector-ref *day-names* day-idx)))
      (string-append open
                     (date->string d "~Y-~m-~d")
                     " " day-abbr " "
                     (date->string d "~H:~M")
                     close)))

  (def (org-current-date-string)
    (let* ((d (current-date))
           (day-idx (date-week-day d))
           (day-abbr (vector-ref *day-names* day-idx)))
      (string-append "<" (date->string d "~Y-~m-~d") " " day-abbr ">")))

  ;;;============================================================================
  ;;; Org Heading
  ;;;============================================================================

  (defstruct org-heading
    (stars        ; integer: number of leading *
     keyword      ; string or #f: "TODO", "DONE", etc.
     priority     ; char or #f: #\A, #\B, #\C
     title        ; string: heading text (sans keyword/priority/tags)
     tags         ; list of strings
     scheduled    ; org-timestamp or #f
     deadline     ; org-timestamp or #f
     closed       ; org-timestamp or #f
     properties   ; hash-table or #f
     clocks       ; list of (start-ts . end-ts-or-#f)
     line-number  ; integer
     file-path))  ; string or #f

  ;; Customizable per-buffer TODO keywords
  (def *org-todo-keywords* '("TODO" "DONE"))
  (def *org-done-keywords* '("DONE"))
  (def *org-agenda-files* '())
  (def (org-agenda-files) *org-agenda-files*)
  (def (org-agenda-files-set! v) (set! *org-agenda-files* v))
  (def *org-buffer-settings* (make-hash-table))

  (def (org-parse-heading-line line)
    (let ((len (string-length line)))
      (if (or (= len 0) (not (char=? (string-ref line 0) #\*)))
        (values #f #f #f #f '())
        ;; Count level
        (let loop-level ((i 0))
          (if (and (< i len) (char=? (string-ref line i) #\*))
            (loop-level (+ i 1))
            (let ((level i))
              ;; Skip space after stars
              (if (or (>= i len) (not (char=? (string-ref line i) #\space)))
                (values level #f #f (if (< i len) (substring line i len) "") '())
                (let* ((rest (string-trim (substring line (+ i 1) len)))
                       ;; Extract tags from end (e.g., ":tag1:tag2:")
                       (tags-and-title (org-split-tags rest))
                       (title-part (car tags-and-title))
                       (tags (cdr tags-and-title))
                       ;; Extract keyword
                       (kw-and-rest (org-split-keyword title-part))
                       (keyword (car kw-and-rest))
                       (after-kw (cdr kw-and-rest))
                       ;; Extract priority
                       (pri-and-rest (org-split-priority after-kw))
                       (priority (car pri-and-rest))
                       (title (string-trim (cdr pri-and-rest))))
                  (values level keyword priority title tags)))))))))

  (def (org-split-tags str)
    (let ((m (pregexp-match "^(.+?)\\s+(:[a-zA-Z0-9_@#%:]+:)\\s*$" str)))
      (if m
        (let* ((title (list-ref m 1))
               (tag-str (list-ref m 2))
               ;; Parse ":tag1:tag2:" -> ("tag1" "tag2")
               (tags (filter (lambda (s) (not (string=? s "")))
                             (string-split tag-str #\:))))
          (cons title tags))
        (cons str '()))))

  (def (org-split-keyword str)
    (let ((m (pregexp-match "^([A-Z]+)\\s+(.*)" str)))
      (if (and m (member (list-ref m 1) *org-todo-keywords*))
        (cons (list-ref m 1) (list-ref m 2))
        (cons #f str))))

  (def (org-split-priority str)
    (let ((m (pregexp-match "^\\[#([A-Z])\\]\\s*(.*)" str)))
      (if m
        (cons (string-ref (list-ref m 1) 0) (list-ref m 2))
        (cons #f str))))

  ;;;============================================================================
  ;;; Planning Lines
  ;;;============================================================================

  (def (org-parse-planning-line line)
    (let ((sched #f) (dead #f) (closed #f))
      ;; SCHEDULED: <...>
      (let ((m (pregexp-match "SCHEDULED:\\s*(<[^>]+>|\\[[^]]+\\])" line)))
        (when m (set! sched (org-parse-timestamp (list-ref m 1)))))
      ;; DEADLINE: <...>
      (let ((m (pregexp-match "DEADLINE:\\s*(<[^>]+>|\\[[^]]+\\])" line)))
        (when m (set! dead (org-parse-timestamp (list-ref m 1)))))
      ;; CLOSED: [...]
      (let ((m (pregexp-match "CLOSED:\\s*(<[^>]+>|\\[[^]]+\\])" line)))
        (when m (set! closed (org-parse-timestamp (list-ref m 1)))))
      (values sched dead closed)))

  (def (org-planning-line? line)
    (let ((trimmed (string-trim line)))
      (or (string-prefix? "SCHEDULED:" trimmed)
          (string-prefix? "DEADLINE:" trimmed)
          (string-prefix? "CLOSED:" trimmed))))

  ;;;============================================================================
  ;;; Property Drawers
  ;;;============================================================================

  (def (org-parse-properties lines start-idx)
    (let ((props (make-hash-table)))
      (let loop ((i (+ start-idx 1)))
        (if (>= i (length lines))
          props
          (let ((line (string-trim (list-ref lines i))))
            (cond
              ((string=? line ":END:") props)
              ((pregexp-match "^:([^:]+):\\s+(.*)$" line)
               => (lambda (m)
                    (hash-put! props (list-ref m 1) (string-trim (list-ref m 2)))
                    (loop (+ i 1))))
              (else (loop (+ i 1)))))))))

  (def (org-properties-drawer? line)
    (string=? (string-trim line) ":PROPERTIES:"))

  (def (org-drawer-end? line)
    (string=? (string-trim line) ":END:"))

  ;;;============================================================================
  ;;; Clock Lines
  ;;;============================================================================

  (def (org-parse-clock-line line)
    (let ((trimmed (string-trim line)))
      (cond
        ;; Closed clock: CLOCK: [start]--[end] => H:MM
        ((pregexp-match "^CLOCK:\\s*(\\[[^]]+\\])\\s*--\\s*(\\[[^]]+\\])\\s*=>\\s*(.+)$" trimmed)
         => (lambda (m)
              (let ((start (org-parse-timestamp (list-ref m 1)))
                    (end   (org-parse-timestamp (list-ref m 2)))
                    (dur   (string-trim (list-ref m 3))))
                (values start end dur))))
        ;; Open clock: CLOCK: [start]
        ((pregexp-match "^CLOCK:\\s*(\\[[^]]+\\])\\s*$" trimmed)
         => (lambda (m)
              (let ((start (org-parse-timestamp (list-ref m 1))))
                (values start #f #f))))
        (else (values #f #f #f)))))

  (def (org-clock-line? line)
    (string-prefix? "CLOCK:" (string-trim line)))

  ;;;============================================================================
  ;;; Buffer-Level Parsing
  ;;;============================================================================

  (def (org-parse-buffer text (file-path #f))
    (let* ((lines (string-split text #\newline))
           (total (length lines))
           (headings '()))
      (let loop ((i 0))
        (if (>= i total)
          (reverse headings)
          (let ((line (list-ref lines i)))
            (if (and (> (string-length line) 0)
                     (char=? (string-ref line 0) #\*))
              ;; Parse heading
              (let-values (((level keyword priority title tags)
                            (org-parse-heading-line line)))
                (if (not level)
                  (loop (+ i 1))
                  ;; Scan subsequent lines for planning, properties, clocks
                  (let-values (((sched dead closed props clocks end-i)
                                (org-scan-heading-body lines (+ i 1) total)))
                    (let ((h (make-org-heading
                              level keyword priority title tags
                              sched dead closed props clocks i file-path)))
                      (set! headings (cons h headings))
                      (loop end-i)))))
              (loop (+ i 1))))))))

  (def (org-scan-heading-body lines start total)
    (let ((sched #f) (dead #f) (closed #f)
          (props #f) (clocks '()))
      (let loop ((i start))
        (if (>= i total)
          (values sched dead closed props (reverse clocks) i)
          (let* ((line (list-ref lines i))
                 (trimmed (string-trim line)))
            (cond
              ;; Next heading — stop
              ((and (> (string-length line) 0)
                    (char=? (string-ref line 0) #\*))
               (values sched dead closed props (reverse clocks) i))
              ;; Planning line
              ((org-planning-line? line)
               (let-values (((s d c) (org-parse-planning-line line)))
                 (when s (set! sched s))
                 (when d (set! dead d))
                 (when c (set! closed c))
                 (loop (+ i 1))))
              ;; Properties drawer
              ((string=? trimmed ":PROPERTIES:")
               (set! props (org-parse-properties lines i))
               ;; Skip to :END:
               (let skip ((j (+ i 1)))
                 (if (or (>= j total) (string=? (string-trim (list-ref lines j)) ":END:"))
                   (loop (+ j 1))
                   (skip (+ j 1)))))
              ;; LOGBOOK drawer — scan for clocks
              ((string=? trimmed ":LOGBOOK:")
               (let skip ((j (+ i 1)))
                 (cond
                   ((>= j total) (loop j))
                   ((string=? (string-trim (list-ref lines j)) ":END:")
                    (loop (+ j 1)))
                   ((org-clock-line? (list-ref lines j))
                    (let-values (((start-ts end-ts dur) (org-parse-clock-line (list-ref lines j))))
                      (when start-ts
                        (set! clocks (cons (cons start-ts end-ts) clocks)))
                      (skip (+ j 1))))
                   (else (skip (+ j 1))))))
              ;; Clock line outside logbook
              ((org-clock-line? line)
               (let-values (((start-ts end-ts dur) (org-parse-clock-line line)))
                 (when start-ts
                   (set! clocks (cons (cons start-ts end-ts) clocks)))
                 (loop (+ i 1))))
              ;; Blank line or body text between heading and next item
              ((or (string=? trimmed "")
                   (and (not (string-prefix? "* " line))
                        (< (- i start) 5)))
               (loop (+ i 1)))
              ;; Regular body text — stop scanning for metadata
              (else
               (values sched dead closed props (reverse clocks) i))))))))

  ;;;============================================================================
  ;;; Buffer Settings
  ;;;============================================================================

  (def (org-parse-buffer-settings text)
    (let ((settings (make-hash-table))
          (lines (string-split text #\newline)))
      (for-each
        (lambda (line)
          (let ((m (pregexp-match "^#\\+([A-Za-z_]+):\\s*(.*)" line)))
            (when m
              (let ((key (string-downcase (list-ref m 1)))
                    (val (string-trim (list-ref m 2))))
                (hash-put! settings key val)))))
        lines)
      ;; Parse #+TODO: into keyword lists
      (let ((todo-val (hash-get settings "todo")))
        (when todo-val
          (let ((parsed (org-parse-todo-keywords todo-val)))
            (hash-put! settings "todo-active" (car parsed))
            (hash-put! settings "todo-done" (cdr parsed)))))
      ;; Parse #+TAGS: into tag list
      (let ((tags-val (hash-get settings "tags")))
        (when tags-val
          (hash-put! settings "tag-list" (org-parse-tags-setting tags-val))))
      settings))

  (def (org-parse-todo-keywords str)
    (let* ((parts (pregexp-split "\\s*\\|\\s*" str))
           (active (if (pair? parts)
                     (filter (lambda (s) (not (string=? s "")))
                             (pregexp-split "\\s+" (car parts)))
                     '()))
           (done (if (and (pair? parts) (pair? (cdr parts)))
                   (filter (lambda (s) (not (string=? s "")))
                           (pregexp-split "\\s+" (cadr parts)))
                   '())))
      (cons active done)))

  (def (org-parse-tags-setting str)
    (filter (lambda (s) (not (string=? s "")))
            (pregexp-split "\\s+" str)))

  ;;;============================================================================
  ;;; Tag Matching
  ;;;============================================================================

  (def (org-heading-match-tags? heading expr)
    (let ((tags (org-heading-tags heading)))
      (cond
        ;; OR expression
        ((string-contains expr "|")
         (let ((parts (pregexp-split "\\|" expr)))
           (any-pred (lambda (p) (org-heading-match-tags? heading (string-trim p))) parts)))
        ;; AND/NOT expression
        (else
         (let ((terms (org-parse-tag-expr expr)))
           (every-pred (lambda (term)
                         (let ((op (car term))
                               (tag (cdr term)))
                           (case op
                             ((+) (and (member tag tags) #t))
                             ((-) (not (member tag tags)))
                             (else (and (member tag tags) #t)))))
                       terms))))))

  (def (org-parse-tag-expr expr)
    (let ((result '())
          (current-op '+)
          (current-tag ""))
      (let loop ((i 0))
        (if (>= i (string-length expr))
          (begin
            (when (not (string=? current-tag ""))
              (set! result (cons (cons current-op current-tag) result)))
            (reverse result))
          (let ((c (string-ref expr i)))
            (cond
              ((char=? c #\+)
               (when (not (string=? current-tag ""))
                 (set! result (cons (cons current-op current-tag) result)))
               (set! current-op '+)
               (set! current-tag "")
               (loop (+ i 1)))
              ((char=? c #\-)
               (when (not (string=? current-tag ""))
                 (set! result (cons (cons current-op current-tag) result)))
               (set! current-op '-)
               (set! current-tag "")
               (loop (+ i 1)))
              (else
               (set! current-tag (string-append current-tag (string c)))
               (loop (+ i 1)))))))))

  ;;;============================================================================
  ;;; Repeater Handling
  ;;;============================================================================

  (def (org-apply-repeater ts base-date)
    (let ((rep (org-timestamp-repeater ts)))
      (if (not rep)
        ts
        (let ((m (pregexp-match "^(\\+\\+?|\\.\\+)(\\d+)([hdwmy])$" rep)))
          (if (not m)
            ts
            (let ((rep-num  (string->number (list-ref m 2)))
                  (rep-unit (string-ref (list-ref m 3) 0)))
              (let loop ((current ts))
                (if (org-timestamp>=? current base-date)
                  current
                  (loop (org-advance-timestamp current rep-num rep-unit))))))))))

  (def (org-advance-timestamp ts n unit)
    (let ((year (org-timestamp-year ts))
          (month (org-timestamp-month ts))
          (day (org-timestamp-day ts))
          (hour (or (org-timestamp-hour ts) 0))
          (minute (or (org-timestamp-minute ts) 0)))
      ;; org-copy-timestamp args: ts year month day hour minute end-hour end-minute
      (case unit
        ((#\h)
         (let* ((total-min (+ (* hour 60) minute (* n 60)))
                (new-hour (quotient total-min 60))
                (new-min (remainder total-min 60)))
           (org-copy-timestamp ts
             #f #f (+ day (quotient new-hour 24))
             (remainder new-hour 24) new-min)))
        ((#\d) (org-copy-timestamp ts #f #f (+ day n)))
        ((#\w) (org-copy-timestamp ts #f #f (+ day (* n 7))))
        ((#\m)
         (let* ((total-months (+ (* (- year 1) 12) (- month 1) n))
                (new-year (+ 1 (quotient total-months 12)))
                (new-month (+ 1 (remainder total-months 12))))
           (org-copy-timestamp ts new-year new-month)))
        ((#\y) (org-copy-timestamp ts (+ year n)))
        (else ts))))

  ;; Copy a timestamp with specific field overrides.
  ;; Fields: year month day hour minute end-hour end-minute
  ;; Pass #f for any field to keep the original value.
  (def (org-copy-timestamp ts
         (year #f) (month #f) (day #f)
         (hour #f) (minute #f)
         (end-hour #f) (end-minute #f))
    (make-org-timestamp
      (org-timestamp-type ts)
      (or year (org-timestamp-year ts))
      (or month (org-timestamp-month ts))
      (or day (org-timestamp-day ts))
      (org-timestamp-day-name ts)
      (or hour (org-timestamp-hour ts))
      (or minute (org-timestamp-minute ts))
      (or end-hour (org-timestamp-end-hour ts))
      (or end-minute (org-timestamp-end-minute ts))
      (org-timestamp-repeater ts)
      (org-timestamp-warning ts)))

  (def (org-timestamp>=? ts base-date)
    (let* ((d1 (org-timestamp->date ts))
           (t1 (date->time-utc d1))
           (t2 (date->time-utc base-date)))
      (>= (time-second t1) (time-second t2))))

  ;;;============================================================================
  ;;; File Parsing
  ;;;============================================================================

  (def (org-parse-file path)
    (if (file-exists? path)
      (let ((text (read-file-string path)))
        (org-parse-buffer text path))
      '()))

  (def (read-file-string path)
    (call-with-input-file path
      (lambda (port) (get-string-all port))))

  ;;;============================================================================
  ;;; Utility Helpers
  ;;;============================================================================

  (def (org-heading-line? line)
    (and (> (string-length line) 0)
         (char=? (string-ref line 0) #\*)))

  (def (org-heading-stars-of-line line)
    (let loop ((i 0))
      (if (and (< i (string-length line)) (char=? (string-ref line i) #\*))
        (loop (+ i 1))
        i)))

  (def (org-find-subtree-end-in-text lines cur-line level)
    (let loop ((i (+ cur-line 1)))
      (cond
        ((>= i (length lines)) i)
        ((let ((l (list-ref lines i)))
           (and (org-heading-line? l)
                (<= (org-heading-stars-of-line l) level)))
         i)
        (else (loop (+ i 1))))))

  (def (org-src-block-line? line)
    (string-prefix-ci? "#+begin_src" (string-trim line)))

  (def (org-src-block-end? line)
    (string-prefix-ci? "#+end_src" (string-trim line)))

  (def (org-block-begin? line)
    (string-prefix-ci? "#+begin_" (string-trim line)))

  (def (org-block-end? line)
    (string-prefix-ci? "#+end_" (string-trim line)))

  (def (org-keyword-line? line)
    (string-prefix? "#+" (string-trim line)))

  (def (org-comment-line? line)
    (let ((trimmed (string-trim line)))
      (and (> (string-length trimmed) 0)
           (char=? (string-ref trimmed 0) #\#)
           (or (= (string-length trimmed) 1)
               (not (char=? (string-ref trimmed 1) #\+))))))

  (def (org-table-line? line)
    (let ((trimmed (string-trim line)))
      (and (> (string-length trimmed) 0)
           (char=? (string-ref trimmed 0) #\|))))

  (def (string-prefix-ci? prefix str)
    (and (>= (string-length str) (string-length prefix))
         (string-ci=? prefix (substring str 0 (string-length prefix)))))

  (def (any-pred pred lst)
    (let loop ((l lst))
      (cond ((null? l) #f)
            ((pred (car l)) #t)
            (else (loop (cdr l))))))

  (def (every-pred pred lst)
    (let loop ((l lst))
      (cond ((null? l) #t)
            ((not (pred (car l))) #f)
            (else (loop (cdr l))))))

  ) ;; end library
