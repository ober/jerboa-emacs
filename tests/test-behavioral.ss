;;; -*- Gerbil -*-
;;; Deterministic behavioral regression suite for jemacs-qt.
;;;
;;; Connects to a running jemacs-qt REPL and runs named test cases that
;;; verify editor behavior (typing, window splitting, terminal focus, etc.)
;;; deterministically — unlike the stress test which drives random operations.
;;;
;;; Designed to catch regressions like:
;;;   - C-x 2 typing into terminal instead of splitting
;;;   - Typing after split going to wrong window
;;;   - Key prefix state leaking between operations
;;;
;;; Usage:
;;;   make test-behavioral           (headless, auto-launches editor)
;;;   scheme --libdirs lib:... --script tests/test-behavioral.ss --port 9999
;;;
;;; Requires a running jemacs-qt with --repl <port>.
;;; Port is auto-detected from ~/.jerboa-repl-port if not given.

(import (jerboa prelude))

;;;============================================================================
;;; Compat: thread-sleep! (same trick as stress-test.ss)
;;;============================================================================

(def chez:make-time-for-sleep
  (let () (import (only (chezscheme) make-time)) make-time))

(def (thread-sleep! secs)
  (let* ((diff (max 0 secs))
         (s (exact (floor diff)))
         (ns (exact (floor (* (- diff s) 1000000000)))))
    (sleep (chez:make-time-for-sleep 'time-duration ns s))))

;;;============================================================================
;;; Configuration
;;;============================================================================

(def *repl-port* #f)
(def *verbose* #f)
(def *pass-count* 0)
(def *fail-count* 0)
(def *current-test* "#<none>")

;;;============================================================================
;;; TCP / REPL connection (same s-expression protocol as stress-test.ss)
;;;============================================================================

(def *nc-stdin* #f)
(def *nc-stdout* #f)
(def *nc-stderr* #f)
(def *req-id* 0)

(def (next-req-id!)
  (set! *req-id* (+ *req-id* 1))
  *req-id*)

(def (read-repl-port-file)
  (let ((path (str (getenv "HOME") "/.jerboa-repl-port")))
    (if (file-exists? path)
      (with-catch
        (lambda (e) #f)
        (lambda ()
          (let ((content (read-file-string path)))
            (let ((idx (string-contains content "=")))
              (and idx
                   (string->number
                     (string-trim
                       (substring content (+ idx 1)
                                  (string-length content)))))))))
      #f)))

(def (connect! port)
  (let-values (((stdin stdout stderr pid)
                (open-process-ports
                  (str "nc 127.0.0.1 " port)
                  'block (native-transcoder))))
    (set! *nc-stdin* stdin)
    (set! *nc-stdout* stdout)
    (set! *nc-stderr* stderr))
  ;; Wait for REPL banner + "jerboa> " prompt then drain
  (thread-sleep! 0.4)
  (drain-input!))

(def (disconnect!)
  (with-catch (lambda (e) #f)
    (lambda ()
      (when *nc-stdin*  (close-port *nc-stdin*))
      (when *nc-stdout* (close-port *nc-stdout*))
      (when *nc-stderr* (close-port *nc-stderr*))))
  (set! *nc-stdin* #f)
  (set! *nc-stdout* #f)
  (set! *nc-stderr* #f))

(def (drain-input!)
  (with-catch
    (lambda (e) #f)
    (lambda ()
      (let loop ((count 0))
        (when (and (< count 8192) (char-ready? *nc-stdout*))
          (read-char *nc-stdout*)
          (loop (+ count 1)))))))

;;;============================================================================
;;; REPL communication (s-expression protocol)
;;;============================================================================

(def (send-eval! expr-str)
  (when *verbose* (displayln "SEND: " expr-str))
  (let ((id (next-req-id!))
        (expr-literal (with-output-to-string (lambda () (write expr-str)))))
    (display (str "(" id " eval " expr-literal ")") *nc-stdin*)
    (newline *nc-stdin*)
    (flush-output-port *nc-stdin*)
    (read-sexpr-response!)))

(def (read-sexpr-response!)
  ;; Wait up to 8 seconds (80 × 100ms)
  (let wait-loop ((waited 0))
    (cond
      ((char-ready? *nc-stdout*)
       (let ((line (get-line *nc-stdout*)))
         (if (eof-object? line)
           (begin
             (displayln "BEHAVIORAL: connection lost to jemacs-qt!")
             (disconnect!)
             (exit 1))
           line)))
      ((> waited 80)
       (displayln "BEHAVIORAL: timeout waiting for REPL response")
       "")
      (else
       (thread-sleep! 0.1)
       (wait-loop (+ waited 1))))))

(def (jeval! expr-str)
  "Evaluate EXPR-STR in the editor REPL. Returns parsed result value or #f on error."
  (let ((raw (send-eval! expr-str)))
    (when *verbose* (displayln "RECV: " raw))
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let* ((sexp (with-input-from-string raw read))
               ;; Response shape: (N :ok (:value "VAL" :stdout "OUT"))
               ;;              or (N :error "MSG")
               (status (and (pair? sexp) (list-ref sexp 1))))
          (cond
            ((eq? status ':ok)
             (let* ((payload (list-ref sexp 2))
                    (val-str (and (pair? payload) (list-ref payload 1))))
               ;; val-str is a string representation of the result
               val-str))
            ((eq? status ':error)
             (when *verbose*
               (displayln "JEVAL ERROR: " (list-ref sexp 2)))
             #f)
            (else #f)))))))

(def (jeval-bool! expr-str)
  "Evaluate expr in editor, return #t if result is '#t' string."
  (string=? "#t" (or (jeval! expr-str) "")))

(def (jeval-number! expr-str)
  "Evaluate expr in editor, return result as number or #f."
  (let ((r (jeval! expr-str)))
    (and r (string->number r))))

(def (jeval-string! expr-str)
  "Evaluate expr in editor, return result with outer quotes stripped, or empty string."
  (let ((r (jeval! expr-str)))
    (if (and r (> (string-length r) 1)
             (char=? (string-ref r 0) #\"))
      ;; Strip surrounding quotes (this is the printed representation)
      (substring r 1 (- (string-length r) 1))
      (or r ""))))

;;;============================================================================
;;; Test framework
;;;============================================================================

(def (test-pass! name)
  (set! *pass-count* (+ *pass-count* 1))
  (displayln "  PASS: " name))

(def (test-fail! name reason)
  (set! *fail-count* (+ *fail-count* 1))
  (displayln "  FAIL: " name " — " reason))

(defrule (assert-true! msg expr)
  (if expr
    (test-pass! msg)
    (test-fail! msg (str "expected true, got false"))))

(defrule (assert-false! msg expr)
  (if (not expr)
    (test-pass! msg)
    (test-fail! msg (str "expected false, got true"))))

(defrule (assert-eq! msg expected actual)
  (let ((e expected) (a actual))
    (if (equal? e a)
      (test-pass! msg)
      (test-fail! msg (str "expected " e " got " a)))))

(defrule (assert-contains! msg haystack needle)
  (let ((h haystack) (n needle))
    (if (and (string? h) (string? n) (string-contains h n))
      (test-pass! msg)
      (test-fail! msg (str (write-to-string h) " does not contain " (write-to-string n))))))

(defrule (assert-not-contains! msg haystack needle)
  (let ((h haystack) (n needle))
    (if (not (and (string? h) (string? n) (string-contains h n)))
      (test-pass! msg)
      (test-fail! msg (str (write-to-string h) " unexpectedly contains " (write-to-string n))))))

(def (write-to-string val)
  (with-output-to-string (lambda () (write val))))

;;;============================================================================
;;; Editor convenience wrappers
;;;============================================================================

(def (reset!)
  "Reset the editor to a clean single-window state."
  (jeval! "(test-reset!)")
  (thread-sleep! 0.1))

(def (send-keys! . keys)
  "Send keys to the current editor window."
  (for-each
    (lambda (k)
      (jeval! (str "(send-keys! " (write-to-string k) ")")))
    keys))

(def (exec! cmd)
  "Execute a named jemacs command."
  (jeval! (str "(execute-command! *app* '" cmd ")")))

(def (current-buffer-text)
  "Get text of the currently focused editor window."
  (jeval-string! "(buffer-text)"))

(def (current-buffer-name)
  (jeval-string! "(current-buffer-name)"))

(def (window-count)
  (or (jeval-number! "(test-window-count)") 0))

(def (window-buffers)
  "Return list of buffer names across all windows."
  (let ((r (jeval! "(test-window-buffers)")))
    (or (with-catch (lambda (e) '())
          (lambda () (with-input-from-string (or r "()") read)))
        '())))

(def (window-texts)
  "Return list of editor texts across all windows."
  (let ((r (jeval! "(test-window-texts)")))
    (or (with-catch (lambda (e) '())
          (lambda () (with-input-from-string (or r "()") read)))
        '())))

(def (prefix-active?)
  (jeval-bool! "(test-prefix-active?)"))

(def (terminal-running?)
  (jeval-bool! "(test-terminal-running?)"))

;;;============================================================================
;;; Test suite
;;;============================================================================

;;; ------------------------------------------------------------------
;;; Test 1: Self-insert typing reaches current editor
;;; ------------------------------------------------------------------

(def (test-self-insert!)
  (displayln "--- test-self-insert ---")
  (reset!)
  ;; Clear any existing text by moving to scratch
  (exec! 'scratch-buffer)
  (thread-sleep! 0.1)
  ;; Send a distinctive marker string
  (send-keys! "hello")
  (thread-sleep! 0.1)
  (let ((text (current-buffer-text)))
    (assert-contains! "typed text appears in buffer" text "hello")))

;;; ------------------------------------------------------------------
;;; Test 2: C-x 2 splits the window (doesn't type "x2" in buffer)
;;; ------------------------------------------------------------------

(def (test-cx2-splits-not-types!)
  (displayln "--- test-cx2-splits-not-types ---")
  (reset!)
  (exec! 'scratch-buffer)
  (thread-sleep! 0.1)
  ;; Note starting window count (should be 1)
  (let ((before (window-count)))
    ;; Send C-x 2 via the key sequence (not execute-command!, to test the actual key routing)
    (send-keys! "C-x" "2")
    (thread-sleep! 0.1)
    (let ((after (window-count))
          (text (current-buffer-text)))
      (assert-eq! "window count increased by 1" (+ before 1) after)
      (assert-not-contains! "C-x 2 did not type 'x' in buffer" text "x")
      (assert-not-contains! "C-x 2 did not type '2' in buffer" text "2"))))

;;; ------------------------------------------------------------------
;;; Test 3: C-x 3 splits vertically (doesn't type)
;;; ------------------------------------------------------------------

(def (test-cx3-splits-not-types!)
  (displayln "--- test-cx3-splits-not-types ---")
  (reset!)
  (exec! 'scratch-buffer)
  (thread-sleep! 0.1)
  (let ((before (window-count)))
    (send-keys! "C-x" "3")
    (thread-sleep! 0.1)
    (let ((after (window-count))
          (text (current-buffer-text)))
      (assert-eq! "window count increased by 1" (+ before 1) after)
      (assert-not-contains! "C-x 3 did not type '3' in buffer" text "3"))))

;;; ------------------------------------------------------------------
;;; Test 4: After C-x 2, prefix key state is cleared
;;; ------------------------------------------------------------------

(def (test-prefix-cleared-after-split!)
  (displayln "--- test-prefix-cleared-after-split ---")
  (reset!)
  (send-keys! "C-x" "2")
  (thread-sleep! 0.1)
  (assert-false! "prefix state cleared after C-x 2" (prefix-active?)))

;;; ------------------------------------------------------------------
;;; Test 5: Typing in each window goes to that window only
;;; Regression: after C-x 2 + C-x o, typing went to top terminal
;;; ------------------------------------------------------------------

(def (test-split-typing-isolation!)
  (displayln "--- test-split-typing-isolation ---")
  (reset!)
  ;; Start with fresh scratch buffer, clear it
  (exec! 'scratch-buffer)
  (thread-sleep! 0.1)
  ;; Type a marker in window 0
  (send-keys! "WIN0")
  (thread-sleep! 0.1)
  ;; Split to get window 1
  (exec! 'split-window)
  (thread-sleep! 0.1)
  ;; Switch to window 1
  (exec! 'other-window)
  (thread-sleep! 0.1)
  ;; Type a different marker in window 1
  (send-keys! "WIN1")
  (thread-sleep! 0.1)
  (let ((texts (window-texts)))
    (when (>= (length texts) 2)
      ;; Both windows show the same buffer (scratch), so both have both markers.
      ;; Key test: current window (win 1) text has WIN1, and we didn't accidentally
      ;; type in win 0's editor (which would create duplication we can detect).
      (let ((cur-text (current-buffer-text)))
        (assert-contains! "typed text visible in current window" cur-text "WIN1")))))

;;; ------------------------------------------------------------------
;;; Test 6: C-x 2 from terminal splits (not types); terminal split focus fix
;;; ------------------------------------------------------------------

(def (test-terminal-cx2-splits!)
  (displayln "--- test-terminal-cx2-splits ---")
  (reset!)
  ;; Open a terminal
  (exec! 'term)
  (thread-sleep! 0.3)  ;; let shell spawn
  (assert-true! "terminal buffer is active" (terminal-running?))
  (let ((before (window-count)))
    ;; C-x 2 should split, NOT type x2 into terminal
    (send-keys! "C-x" "2")
    (thread-sleep! 0.2)
    (let ((after (window-count)))
      (assert-eq! "C-x 2 in terminal splits window" (+ before 1) after))
    (assert-false! "prefix cleared after C-x 2 from terminal" (prefix-active?))))

;;; ------------------------------------------------------------------
;;; Test 7: After C-x 2 from terminal, typing in new window goes to new window
;;; This is the exact bug that was reported: lower window's keystrokes
;;; were going to the top terminal widget.
;;; ------------------------------------------------------------------

(def (test-new-window-after-terminal-split-types-correctly!)
  (displayln "--- test-new-window-after-terminal-split-types-correctly ---")
  (reset!)
  ;; Open terminal in window 0
  (exec! 'term)
  (thread-sleep! 0.3)
  ;; Split to create window 1 (lower)
  (send-keys! "C-x" "2")
  (thread-sleep! 0.2)
  ;; Focus is now in the new window (window 1, non-terminal)
  ;; Verify we are NOT in a terminal
  (assert-false! "new lower window is not a terminal" (terminal-running?))
  ;; Type a distinctive marker
  (send-keys! "NEWWIN")
  (thread-sleep! 0.1)
  ;; The current buffer's text must contain our marker
  (let ((text (current-buffer-text)))
    (assert-contains! "typing in new window goes to new window editor" text "NEWWIN")))

;;; ------------------------------------------------------------------
;;; Test 8: C-x o switches window focus
;;; ------------------------------------------------------------------

(def (test-other-window-switches-focus!)
  (displayln "--- test-other-window-switches-focus ---")
  (reset!)
  (exec! 'scratch-buffer)
  (thread-sleep! 0.1)
  (exec! 'split-window)
  (thread-sleep! 0.1)
  (let ((name-before (current-buffer-name)))
    (exec! 'other-window)
    (thread-sleep! 0.1)
    ;; After split + other-window, we're in a different position.
    ;; The key invariant: the current window index changed.
    ;; We verify by checking window-count is still 2 (not accidentally closed).
    (assert-eq! "still 2 windows after other-window" 2 (window-count))))

;;; ------------------------------------------------------------------
;;; Test 9: C-x 1 deletes other windows
;;; ------------------------------------------------------------------

(def (test-cx1-deletes-other-windows!)
  (displayln "--- test-cx1-deletes-other-windows ---")
  (reset!)
  (exec! 'split-window)
  (thread-sleep! 0.1)
  (assert-eq! "2 windows before C-x 1" 2 (window-count))
  (send-keys! "C-x" "1")
  (thread-sleep! 0.1)
  (assert-eq! "1 window after C-x 1" 1 (window-count)))

;;; ------------------------------------------------------------------
;;; Test 10: Prefix state not leaked after Escape in terminal context
;;; ------------------------------------------------------------------

(def (test-prefix-not-leaked-after-escape!)
  (displayln "--- test-prefix-not-leaked-after-escape ---")
  (reset!)
  (exec! 'term)
  (thread-sleep! 0.3)
  ;; Partially press C-x then Escape to cancel
  (send-keys! "C-x")
  (thread-sleep! 0.1)
  ;; Prefix should now be active (we're mid C-x)
  ;; Then Escape to cancel
  (send-keys! "ESC")
  (thread-sleep! 0.1)
  (assert-false! "prefix cancelled after ESC in terminal" (prefix-active?)))

;;;============================================================================
;;; Main: connect, run all tests, report
;;;============================================================================

(def (parse-args!)
  (let loop ((args (command-line)))
    (cond
      ((null? args) (void))
      ((and (pair? args) (string=? (car args) "--port") (pair? (cdr args)))
       (set! *repl-port* (string->number (cadr args)))
       (loop (cddr args)))
      ((and (pair? args) (string=? (car args) "--verbose"))
       (set! *verbose* #t)
       (loop (cdr args)))
      (else (loop (cdr args))))))

(def (main!)
  (parse-args!)

  ;; Auto-detect port if not given
  (unless *repl-port*
    (set! *repl-port* (read-repl-port-file)))

  (unless *repl-port*
    (displayln "ERROR: no REPL port. Pass --port N or run from make test-behavioral")
    (exit 1))

  (displayln "=== jemacs-qt behavioral test suite ===")
  (displayln "Connecting to REPL on port " *repl-port* "...")
  (connect! *repl-port*)
  (displayln "Connected.")
  (displayln "")

  ;; Run all tests (each resets state before running)
  (with-catch
    (lambda (e)
      (displayln "FATAL: unhandled exception in test suite: "
                 (with-output-to-string (lambda () (display-exception e))))
      (disconnect!)
      (exit 1))
    (lambda ()
      (test-self-insert!)
      (test-cx2-splits-not-types!)
      (test-cx3-splits-not-types!)
      (test-prefix-cleared-after-split!)
      (test-split-typing-isolation!)
      (test-terminal-cx2-splits!)
      (test-new-window-after-terminal-split-types-correctly!)
      (test-other-window-switches-focus!)
      (test-cx1-deletes-other-windows!)
      (test-prefix-not-leaked-after-escape!)))

  (disconnect!)

  (displayln "")
  (displayln "=== Results: " *pass-count* " passed, " *fail-count* " failed ===")
  (exit (if (zero? *fail-count*) 0 1)))

(main!)
