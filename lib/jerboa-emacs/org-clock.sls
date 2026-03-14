#!chezscheme
;;; org-clock.sls — Org clock: clock-in/out with real elapsed time.
;;;
;;; Ported from gerbil-emacs/org-clock.ss
;;; Backend-agnostic (Scintilla API only, no Qt imports).

(library (jerboa-emacs org-clock)
  (export
    ;; Clock state accessors
    org-clock-start
    org-clock-heading
    org-clock-marker
    org-clock-history

    ;; Clock operations
    org-clock-in-at-point
    org-clock-out
    org-clock-cancel
    org-clock-goto
    org-clock-display
    org-clock-report

    ;; Helpers
    org-elapsed-minutes
    pad-elapsed

    ;; Mode-line
    org-clock-modeline-string)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (only (std srfi srfi-13)
                string-trim string-contains string-prefix? string-join
                string-pad-right)
          (jerboa-emacs pregexp-compat)
          (only (std misc string) string-split)
          (chez-scintilla scintilla)
          (chez-scintilla constants)
          (jerboa-emacs core)
          (jerboa-emacs org-parse))

  ;;;============================================================================
  ;;; Clock State
  ;;;============================================================================

  (def *org-clock-start* #f)      ; org-timestamp or #f
  (def *org-clock-heading* #f)    ; string — heading text for mode-line
  (def *org-clock-marker* #f)     ; line-num — where clock was started
  (def *org-clock-history* '())   ; list of (file . line) for recent clocks

  ;; Accessors for mutable state
  (def (org-clock-start) *org-clock-start*)
  (def (org-clock-heading) *org-clock-heading*)
  (def (org-clock-marker) *org-clock-marker*)
  (def (org-clock-history) *org-clock-history*)

  ;;;============================================================================
  ;;; Elapsed Minutes (no SRFI-19 dependency)
  ;;;============================================================================

  (def (org-elapsed-minutes start-ts end-ts)
    "Compute elapsed minutes between two org-timestamps."
    (let* ((d1 (+ (* (org-timestamp-year start-ts) 525600)
                   (* (org-timestamp-month start-ts) 43800)
                   (* (org-timestamp-day start-ts) 1440)
                   (* (or (org-timestamp-hour start-ts) 0) 60)
                   (or (org-timestamp-minute start-ts) 0)))
           (d2 (+ (* (org-timestamp-year end-ts) 525600)
                   (* (org-timestamp-month end-ts) 43800)
                   (* (org-timestamp-day end-ts) 1440)
                   (* (or (org-timestamp-hour end-ts) 0) 60)
                   (or (org-timestamp-minute end-ts) 0))))
      (- d2 d1)))

  ;;;============================================================================
  ;;; Helpers
  ;;;============================================================================

  (def (pad-elapsed str)
    "Pad elapsed time to align nicely. Ensures at least ' H:MM' format."
    (let ((len (string-length str)))
      (if (< len 4)
        (string-append " " str)
        str)))

  ;;;============================================================================
  ;;; Clock-In
  ;;;============================================================================

  (def (org-clock-in-at-point ed echo)
    "Clock in at the current heading. Creates :LOGBOOK: drawer with CLOCK entry."
    (let* ((pos (editor-get-current-pos ed))
           (line-num (editor-line-from-position ed pos))
           (line-end (send-message ed SCI_GETLINEENDPOSITION line-num))
           (now-str (org-current-timestamp-string #f)) ; inactive timestamp
           (clock-text (string-append "\n  :LOGBOOK:\n  CLOCK: " now-str "\n  :END:")))
      ;; Store clock state
      (set! *org-clock-start* (org-parse-timestamp now-str))
      (set! *org-clock-heading* (string-trim (editor-get-line ed line-num)))
      (set! *org-clock-marker* line-num)
      ;; Insert LOGBOOK drawer after current line
      (editor-insert-text ed line-end clock-text)
      (echo-message! echo (string-append "Clocked in: " now-str))))

  ;;;============================================================================
  ;;; Clock-Out
  ;;;============================================================================

  (def (org-clock-out ed echo)
    "Close the last open CLOCK entry with end timestamp and real elapsed time."
    (let* ((text (editor-get-text ed))
           (lines (string-split text #\newline))
           ;; Find the last open CLOCK entry (has CLOCK: [ but no --)
           (clock-line
             (let loop ((i (- (length lines) 1)))
               (cond
                 ((< i 0) #f)
                 ((let ((l (list-ref lines i)))
                    (and (string-contains l "CLOCK: [")
                         (not (string-contains l "--"))))
                  i)
                 (else (loop (- i 1)))))))
      (if (not clock-line)
        (echo-message! echo "No open clock entry")
        (let* ((now-str (org-current-timestamp-string #f))
               (now-ts (org-parse-timestamp now-str))
               (cur-line-text (list-ref lines clock-line))
               ;; Extract start timestamp from the open clock line
               (start-match (pregexp-match "CLOCK:\\s*(\\[[^]]+\\])" cur-line-text))
               (start-ts (and start-match
                              (org-parse-timestamp (list-ref start-match 1))))
               ;; Compute elapsed
               (elapsed (if (and start-ts now-ts)
                          (org-timestamp-elapsed start-ts now-ts)
                          "0:00"))
               ;; Build new line with end timestamp and elapsed
               (new-line (string-append
                          (string-trim cur-line-text) "--" now-str
                          " => " (pad-elapsed elapsed)))
               ;; Replace the line
               (line-start (editor-position-from-line ed clock-line))
               (line-end (send-message ed SCI_GETLINEENDPOSITION clock-line)))
          (send-message ed SCI_SETTARGETSTART line-start)
          (send-message ed SCI_SETTARGETEND line-end)
          (send-message/string ed SCI_REPLACETARGET new-line)
          ;; Clear clock state
          (set! *org-clock-start* #f)
          (set! *org-clock-heading* #f)
          (set! *org-clock-marker* #f)
          (echo-message! echo (string-append "Clocked out: " now-str " => " elapsed))))))

  ;;;============================================================================
  ;;; Clock Cancel
  ;;;============================================================================

  (def (org-clock-cancel ed echo)
    "Remove the last open CLOCK entry without closing it."
    (let* ((text (editor-get-text ed))
           (lines (string-split text #\newline))
           (clock-line
             (let loop ((i (- (length lines) 1)))
               (cond
                 ((< i 0) #f)
                 ((let ((l (list-ref lines i)))
                    (and (string-contains l "CLOCK: [")
                         (not (string-contains l "--"))))
                  i)
                 (else (loop (- i 1)))))))
      (if (not clock-line)
        (echo-message! echo "No open clock entry to cancel")
        (begin
          ;; Delete the clock line
          (let* ((line-start (editor-position-from-line ed clock-line))
                 (next-line-start (if (< (+ clock-line 1) (editor-get-line-count ed))
                                    (editor-position-from-line ed (+ clock-line 1))
                                    (editor-get-text-length ed))))
            (send-message ed SCI_SETTARGETSTART line-start)
            (send-message ed SCI_SETTARGETEND next-line-start)
            (send-message/string ed SCI_REPLACETARGET ""))
          ;; Clear state
          (set! *org-clock-start* #f)
          (set! *org-clock-heading* #f)
          (set! *org-clock-marker* #f)
          (echo-message! echo "Clock cancelled")))))

  ;;;============================================================================
  ;;; Clock Goto
  ;;;============================================================================

  (def (org-clock-goto ed echo)
    "Jump to the currently clocked-in heading."
    (if (not *org-clock-marker*)
      (echo-message! echo "No clock is currently active")
      (let ((pos (editor-position-from-line ed *org-clock-marker*)))
        (editor-goto-pos ed pos)
        (echo-message! echo (string-append "Clocked: " (or *org-clock-heading* "(unknown)"))))))

  ;;;============================================================================
  ;;; Clock Display (sum all CLOCK entries for current heading)
  ;;;============================================================================

  (def (org-clock-display ed echo)
    "Display total clocked time for the heading at point."
    (let* ((text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (line-num (editor-line-from-position ed pos))
           (lines (string-split text #\newline))
           ;; Find current heading
           (heading-line (let loop ((i line-num))
                           (cond
                             ((< i 0) #f)
                             ((org-heading-line? (list-ref lines i)) i)
                             (else (loop (- i 1))))))
           ;; Find end of subtree
           (heading-level (if heading-line
                            (org-heading-stars-of-line (list-ref lines heading-line))
                            0))
           (subtree-end (if heading-line
                          (org-find-subtree-end-in-text lines heading-line heading-level)
                          (length lines))))
      (if (not heading-line)
        (echo-message! echo "Not on a heading")
        ;; Sum all clock entries in the subtree
        (let loop ((i heading-line) (total-minutes 0))
          (if (>= i subtree-end)
            (let* ((h (quotient total-minutes 60))
                   (m (remainder total-minutes 60))
                   (time-str (string-append (number->string h) ":"
                                            (if (< m 10) "0" "")
                                            (number->string m))))
              (echo-message! echo (string-append "Total clocked time: " time-str)))
            (let ((l (list-ref lines i)))
              (if (org-clock-line? l)
                (let-values (((start-ts end-ts dur) (org-parse-clock-line l)))
                  (let ((mins (if (and start-ts end-ts)
                                (org-elapsed-minutes start-ts end-ts)
                                0)))
                    (loop (+ i 1) (+ total-minutes mins))))
                (loop (+ i 1) total-minutes))))))))

  ;;;============================================================================
  ;;; Clock Report
  ;;;============================================================================

  (def (org-clock-report ed echo)
    "Insert a clocktable at point showing per-heading totals."
    (let* ((text (editor-get-text ed))
           (headings (org-parse-buffer text))
           ;; Build report: heading title -> total minutes
           (report (make-hash-table))
           (_ (for-each
                (lambda (h)
                  (let* ((title (org-heading-title h))
                         (clocks (org-heading-clocks h))
                         (mins (apply + (map (lambda (pair)
                                               (if (and (car pair) (cdr pair))
                                                 (org-elapsed-minutes (car pair) (cdr pair))
                                                 0))
                                             clocks))))
                    (when (> mins 0)
                      (hash-put! report title
                                 (+ (or (hash-get report title) 0) mins)))))
                headings))
           ;; Format as org table
           (entries (hash->list report))
           (sorted (list-sort (lambda (a b) (> (cdr a) (cdr b))) entries)))
      (if (null? sorted)
        (echo-message! echo "No clock entries found")
        (let* ((total-mins (apply + (map cdr sorted)))
               (lines (cons "#+BEGIN: clocktable"
                       (cons "| Heading | Time |"
                        (cons "|---+---|"
                         (append
                          (map (lambda (entry)
                                 (let* ((h (quotient (cdr entry) 60))
                                        (m (remainder (cdr entry) 60)))
                                   (string-append "| " (car entry) " | "
                                                  (number->string h) ":"
                                                  (if (< m 10) "0" "")
                                                  (number->string m) " |")))
                               sorted)
                          (list (string-append "|---+---|")
                                (let* ((h (quotient total-mins 60))
                                       (m (remainder total-mins 60)))
                                  (string-append "| *Total* | *"
                                                 (number->string h) ":"
                                                 (if (< m 10) "0" "")
                                                 (number->string m) "* |"))
                                "#+END:"))))))
               (report-text (string-join lines "\n"))
               (pos (editor-get-current-pos ed)))
          (editor-insert-text ed pos (string-append "\n" report-text "\n"))
          (echo-message! echo "Clock report inserted")))))

  ;;;============================================================================
  ;;; Mode-Line Clock Indicator
  ;;;============================================================================

  (def (org-clock-modeline-string)
    "Return mode-line clock string or #f if not clocking."
    (and *org-clock-start*
         (let* ((now-ts (org-parse-timestamp (org-current-timestamp-string #f)))
                (elapsed (if now-ts
                           (org-timestamp-elapsed *org-clock-start* now-ts)
                           "0:00")))
           (string-append "[Clocked: " elapsed "]"))))

) ;; end library
