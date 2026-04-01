;;; -*- Gerbil -*-
;;; Automated stress test driver for jemacs-qt.
;;;
;;; Connects to the jemacs-qt debug REPL (TCP text mode via nc subprocess)
;;; and drives random editor commands continuously until the editor crashes
;;; (connection drops) or is manually stopped with Ctrl-C.
;;;
;;; Usage:
;;;   scheme --libdirs lib:$JERBOA_PATH/lib --script tests/stress-test.ss
;;;   scheme --libdirs lib:$JERBOA_PATH/lib --script tests/stress-test.ss --port 9999
;;;   scheme --libdirs lib:$JERBOA_PATH/lib --script tests/stress-test.ss --cycles 100
;;;
;;; The REPL port is auto-detected from ~/.jerboa-repl-port if --port is not given.

(import (jerboa prelude))

;;;============================================================================
;;; Configuration
;;;============================================================================

(def *repl-port* #f)             ;; auto-detect from port file if not given
(def *log-file* "stress-test.log")
(def *max-cycles* #f)            ;; #f = infinite
(def *commands-sent* 0)
(def *errors-caught* 0)

;;;============================================================================
;;; TCP connection via nc subprocess
;;;============================================================================

(def *nc-stdin* #f)
(def *nc-stdout* #f)
(def *nc-stderr* #f)
(def *nc-pid* #f)
(def *log-port* #f)

(def (read-repl-port-file)
  "Read the REPL port from ~/.jerboa-repl-port. Returns port number or #f."
  (let ((path (str (getenv "HOME") "/.jerboa-repl-port")))
    (if (file-exists? path)
      (with-catch
        (lambda (e) #f)
        (lambda ()
          (let ((content (read-file-string path)))
            ;; Format: PORT=<number>
            (let ((idx (string-contains content "=")))
              (and idx
                   (string->number
                     (string-trim
                       (substring content (+ idx 1)
                                  (string-length content)))))))))
      #f)))

(def (connect! port)
  "Connect to the debug REPL via nc subprocess."
  (let-values (((stdin stdout stderr pid)
                (open-process-ports
                  (str "nc 127.0.0.1 " port)
                  'block (native-transcoder))))
    (set! *nc-stdin* stdin)
    (set! *nc-stdout* stdout)
    (set! *nc-stderr* stderr)
    (set! *nc-pid* pid)
    ;; Read the initial prompt "jemacs> " — consume it
    (consume-prompt!)))

(def (disconnect!)
  "Close the nc subprocess."
  (with-catch (lambda (e) #f)
    (lambda ()
      (when *nc-stdin*  (close-port *nc-stdin*))
      (when *nc-stdout* (close-port *nc-stdout*))
      (when *nc-stderr* (close-port *nc-stderr*))))
  (set! *nc-stdin* #f)
  (set! *nc-stdout* #f)
  (set! *nc-stderr* #f)
  (set! *nc-pid* #f))

(def (consume-prompt!)
  "Read and discard bytes until we see the prompt or a newline.
   The text-mode REPL sends 'jemacs> ' as a prompt."
  ;; Read character by character until we get '> ' or timeout
  (with-catch
    (lambda (e) #f)
    (lambda ()
      (let loop ((count 0))
        (when (and (< count 1000) (char-ready? *nc-stdout*))
          (read-char *nc-stdout*)
          (loop (+ count 1)))))))

;;;============================================================================
;;; Logging
;;;============================================================================

(def (format-time)
  "Return a simple HH:MM:SS timestamp."
  (let ((t (current-time)))
    (let* ((secs (time-second t))
           (h (modulo (quotient secs 3600) 24))
           (m (modulo (quotient secs 60) 60))
           (s (modulo secs 60)))
      (format "~2,'0d:~2,'0d:~2,'0d" h m s))))

(def (log! msg)
  (let ((line (str "[" (format-time) "] " msg)))
    (displayln line)
    (when *log-port*
      (display line *log-port*)
      (newline *log-port*)
      (flush-output-port *log-port*))))

;;;============================================================================
;;; REPL communication
;;;============================================================================

(def (send-eval! expr-str)
  "Send an expression string to the text-mode REPL.
   Returns the response string, or triggers exit on connection loss."
  (set! *commands-sent* (+ *commands-sent* 1))
  (log! (str "SEND [" *commands-sent* "]: " expr-str))
  ;; Send the expression
  (display expr-str *nc-stdin*)
  (newline *nc-stdin*)
  (flush-output-port *nc-stdin*)
  ;; Read response lines until we see the next prompt or eof.
  ;; The text REPL prints the result, then "jemacs> ".
  ;; We read until we find char '>' followed by ' ' at start of a line,
  ;; or we get eof.
  (let ((resp (read-response!)))
    (log! (str "RECV: " resp))
    resp))

(def (read-response!)
  "Read lines from the REPL until we get a prompt or eof.
   Returns the concatenated response text."
  (let loop ((acc '())
             (timeout-chars 0))
    ;; Give the REPL up to 10 seconds to respond
    (let wait-loop ((waited 0))
      (cond
        ((char-ready? *nc-stdout*)
         ;; Read a full line if available
         (let ((line (get-line *nc-stdout*)))
           (cond
             ((eof-object? line)
              (log! "CONNECTION LOST — jemacs-qt likely crashed!")
              (log! (str "Stats: " *commands-sent* " commands sent, "
                         *errors-caught* " errors caught"))
              (disconnect!)
              (exit 1))
             ;; Check if this line is the prompt "jemacs> "
             ((and (>= (string-length line) 7)
                   (string-prefix? "jemacs>" line))
              ;; This is the prompt — we're done
              (string-join (reverse acc) "\n"))
             (else
              (loop (cons line acc) 0)))))
        ((> waited 100)
         ;; 10 seconds with no data — assume response is complete
         ;; Try to consume any partial prompt
         (consume-prompt!)
         (string-join (reverse acc) "\n"))
        (else
         ;; Wait 100ms and try again
         (thread-sleep! 0.1)
         (wait-loop (+ waited 1)))))))

(def (stress-cmd! cmd-name)
  "Execute a named command via the dispatch chain."
  (send-eval! (str "(execute-command! *app* '" cmd-name ")")))

(def (stress-eval! expr-str)
  "Evaluate an arbitrary expression in the REPL."
  (send-eval! expr-str))

;;;============================================================================
;;; Random utilities
;;;============================================================================

(def (random-choice lst)
  (list-ref lst (random (length lst))))

(def (maybe-delay!)
  "50% chance of a short delay (50-200ms)."
  (when (zero? (random 2))
    (thread-sleep! (/ (+ 50 (random 150)) 1000.0))))

(def (short-delay!)
  "Fixed short delay (100-300ms)."
  (thread-sleep! (/ (+ 100 (random 200)) 1000.0)))

(def (with-phase-error-handler phase-name thunk)
  "Run thunk, catching any Scheme-level exceptions and logging them."
  (with-catch
    (lambda (e)
      (set! *errors-caught* (+ *errors-caught* 1))
      (log! (str "ERROR in " phase-name ": "
                 (with-output-to-string (lambda () (display-condition e))))))
    thunk))

;;;============================================================================
;;; Phase 1: Window Chaos
;;;============================================================================

(def (phase-window-chaos!)
  (log! "=== PHASE: Window Chaos ===")
  (let ((ops '(split-window-right split-window-below
               delete-window delete-other-windows other-window
               balance-windows)))
    (dotimes (_ (+ 5 (random 15)))
      (with-phase-error-handler "window-chaos"
        (lambda ()
          (stress-cmd! (random-choice ops))
          (maybe-delay!))))))

;;;============================================================================
;;; Phase 2: Vterm Storm
;;;============================================================================

(def (phase-vterm-storm!)
  (log! "=== PHASE: Vterm Storm ===")
  ;; Open several vterms
  (dotimes (_ (+ 1 (random 3)))
    (with-phase-error-handler "vterm-open"
      (lambda ()
        (stress-cmd! 'vterm)
        (thread-sleep! 0.5))))
  ;; Switch between windows
  (dotimes (_ (+ 2 (random 5)))
    (with-phase-error-handler "vterm-switch"
      (lambda ()
        (stress-cmd! 'other-window)
        (maybe-delay!))))
  ;; Let things settle, then maybe close some
  (thread-sleep! 1.0)
  (dotimes (_ (random 3))
    (with-phase-error-handler "vterm-close"
      (lambda ()
        (stress-cmd! 'kill-buffer-cmd)
        (maybe-delay!)))))

;;;============================================================================
;;; Phase 3: File Churn
;;;============================================================================

(def (phase-file-churn!)
  (log! "=== PHASE: File Churn ===")
  (dotimes (i (+ 3 (random 8)))
    (with-phase-error-handler "file-churn"
      (lambda ()
        (let ((path (str "/tmp/jemacs-stress-" i ".txt"))
              ;; Generate content of varying sizes
              (content (make-string (+ 100 (random 5000)) #\x)))
          ;; Create file on disk and open it in the editor
          (stress-eval!
            (str "(begin"
                 " (write-file-string \"" path "\" "
                 "\"" (make-string (min 200 (string-length content)) #\A) "\")"
                 " (qt-open-file! *app* \"" path "\"))"))
          (short-delay!)
          ;; Do some editing operations
          (stress-cmd! 'beginning-of-buffer)
          (stress-cmd! 'open-line)
          (stress-cmd! 'end-of-buffer)
          ;; Random navigation
          (dotimes (_ (+ 5 (random 20)))
            (stress-cmd! (random-choice
              '(forward-char backward-char next-line previous-line))))
          ;; Mark and kill region
          (stress-cmd! 'set-mark)
          (dotimes (_ (+ 1 (random 30)))
            (stress-cmd! 'forward-char))
          (stress-cmd! 'kill-region)
          ;; Switch and yank
          (stress-cmd! 'other-window)
          (stress-cmd! 'yank)
          (maybe-delay!)
          ;; Maybe kill the buffer
          (when (zero? (random 3))
            (stress-cmd! 'kill-buffer-cmd)))))))

;;;============================================================================
;;; Phase 4: Navigation Stress
;;;============================================================================

(def (phase-navigation-stress!)
  (log! "=== PHASE: Navigation Stress ===")
  (dotimes (_ (+ 20 (random 50)))
    (with-phase-error-handler "navigation"
      (lambda ()
        (stress-cmd! (random-choice
          '(forward-char backward-char forward-word backward-word
            next-line previous-line
            beginning-of-line end-of-line
            beginning-of-buffer end-of-buffer
            scroll-up scroll-down
            recenter)))))))

;;;============================================================================
;;; Phase 5: EWW (web browser)
;;;============================================================================

(def (phase-eww!)
  (log! "=== PHASE: EWW ===")
  (with-phase-error-handler "eww"
    (lambda ()
      ;; Open eww
      (stress-cmd! 'eww)
      (thread-sleep! 1.0)
      ;; Navigate around
      (dotimes (_ (+ 3 (random 10)))
        (stress-cmd! (random-choice
          '(scroll-up scroll-down forward-char next-line
            previous-line backward-char beginning-of-buffer)))
        (maybe-delay!))
      ;; Switch away
      (stress-cmd! 'other-window))))

;;;============================================================================
;;; Phase 6: Edit Storm (insert/delete heavy)
;;;============================================================================

(def (phase-edit-storm!)
  (log! "=== PHASE: Edit Storm ===")
  ;; Open a scratch buffer with content
  (with-phase-error-handler "edit-storm-setup"
    (lambda ()
      (let ((path "/tmp/jemacs-stress-edit.txt"))
        (stress-eval!
          (str "(begin"
               " (write-file-string \"" path
               "\" (make-string 2000 #\\newline))"
               " (qt-open-file! *app* \"" path "\"))"))
        (short-delay!))))
  ;; Rapid editing operations
  (dotimes (_ (+ 30 (random 50)))
    (with-phase-error-handler "edit-storm"
      (lambda ()
        (stress-cmd! (random-choice
          '(kill-line yank undo redo open-line delete-char
            backward-delete-char duplicate-line
            forward-char backward-char next-line previous-line
            beginning-of-line end-of-line
            kill-word backward-kill-word
            transpose-chars)))))))

;;;============================================================================
;;; Phase 7: Buffer Management
;;;============================================================================

(def (phase-buffer-management!)
  (log! "=== PHASE: Buffer Management ===")
  ;; Open many buffers
  (dotimes (i (+ 3 (random 6)))
    (with-phase-error-handler "buffer-open"
      (lambda ()
        (let ((path (str "/tmp/jemacs-stress-buf-" i ".txt")))
          (stress-eval!
            (str "(begin"
                 " (write-file-string \"" path "\" \"buffer " i "\")"
                 " (qt-open-file! *app* \"" path "\"))"))
          (maybe-delay!)))))
  ;; Switch between them rapidly
  (dotimes (_ (+ 10 (random 20)))
    (with-phase-error-handler "buffer-switch"
      (lambda ()
        (stress-cmd! (random-choice
          '(switch-buffer other-window list-buffers)))
        (maybe-delay!))))
  ;; Kill some
  (dotimes (_ (+ 1 (random 4)))
    (with-phase-error-handler "buffer-kill"
      (lambda ()
        (stress-cmd! 'kill-buffer-cmd)
        (maybe-delay!)))))

;;;============================================================================
;;; Phase 8: Combined Chaos
;;;============================================================================

(def (phase-combined-chaos!)
  (log! "=== PHASE: Combined Chaos ===")
  (dotimes (_ (+ 20 (random 40)))
    (with-phase-error-handler "combined-chaos"
      (lambda ()
        (let ((action (random 10)))
          (cond
            ((< action 3)
             ;; Window operations
             (stress-cmd! (random-choice
               '(split-window-right split-window-below delete-window
                 other-window delete-other-windows balance-windows))))
            ((< action 5)
             ;; Navigation
             (stress-cmd! (random-choice
               '(forward-char backward-char next-line previous-line
                 scroll-up scroll-down beginning-of-buffer end-of-buffer
                 forward-word backward-word))))
            ((< action 7)
             ;; Editing
             (stress-cmd! (random-choice
               '(kill-line yank undo redo open-line delete-char
                 backward-delete-char duplicate-line transpose-chars))))
            ((< action 9)
             ;; Buffer operations
             (stress-cmd! (random-choice
               '(other-window list-buffers kill-buffer-cmd))))
            (else
             ;; Meta operations
             (stress-cmd! (random-choice
               '(mark-whole-buffer recenter))))))
        (maybe-delay!)))))

;;;============================================================================
;;; Phase 9: Rapid Window Splits and Deletes
;;;============================================================================

(def (phase-window-thrash!)
  (log! "=== PHASE: Window Thrash ===")
  ;; Split many times
  (dotimes (_ (+ 5 (random 10)))
    (with-phase-error-handler "window-thrash-split"
      (lambda ()
        (stress-cmd! (random-choice '(split-window-right split-window-below)))
        (maybe-delay!))))
  ;; Switch around
  (dotimes (_ (+ 5 (random 10)))
    (with-phase-error-handler "window-thrash-nav"
      (lambda ()
        (stress-cmd! 'other-window))))
  ;; Delete all but one
  (with-phase-error-handler "window-thrash-cleanup"
    (lambda ()
      (stress-cmd! 'delete-other-windows))))

;;;============================================================================
;;; Phase 10: Search Operations
;;;============================================================================

(def (phase-search-ops!)
  (log! "=== PHASE: Search Operations ===")
  ;; Make sure we have a buffer with content
  (with-phase-error-handler "search-setup"
    (lambda ()
      (let ((path "/tmp/jemacs-stress-search.txt"))
        (stress-eval!
          (str "(begin"
               " (write-file-string \"" path
               "\" \"hello world\\nfoo bar baz\\nline three\\nfour five six\\n\")"
               " (qt-open-file! *app* \"" path "\"))"))
        (short-delay!))))
  ;; Navigate with word motions (search-like behavior)
  (dotimes (_ (+ 10 (random 20)))
    (with-phase-error-handler "search-nav"
      (lambda ()
        (stress-cmd! (random-choice
          '(forward-word backward-word
            beginning-of-line end-of-line
            next-line previous-line
            beginning-of-buffer end-of-buffer)))))))

;;;============================================================================
;;; Cleanup
;;;============================================================================

(def (cleanup-temp-files!)
  (log! "Cleaning up temp files...")
  (with-catch (lambda (e) #f)
    (lambda ()
      (for-each
        (lambda (prefix)
          (dotimes (i 20)
            (let ((f (str "/tmp/jemacs-stress-" prefix i ".txt")))
              (when (file-exists? f)
                (delete-file f)))))
        '("" "buf-"))
      (for-each
        (lambda (f)
          (when (file-exists? f)
            (delete-file f)))
        '("/tmp/jemacs-stress-edit.txt"
          "/tmp/jemacs-stress-search.txt")))))

;;;============================================================================
;;; Main entry point
;;;============================================================================

(def (parse-args args)
  "Parse command-line arguments. Returns (port . max-cycles) pair."
  (let ((port #f)
        (cycles #f))
    (let loop ((rest args))
      (cond
        ((null? rest) (values port cycles))
        ((and (string=? (car rest) "--port")
              (pair? (cdr rest)))
         (set! port (string->number (cadr rest)))
         (loop (cddr rest)))
        ((and (string=? (car rest) "--cycles")
              (pair? (cdr rest)))
         (set! cycles (string->number (cadr rest)))
         (loop (cddr rest)))
        ((string=? (car rest) "--help")
         (displayln "Usage: stress-test.ss [--port PORT] [--cycles N]")
         (displayln "  --port PORT    REPL port (auto-detected from ~/.jerboa-repl-port)")
         (displayln "  --cycles N     Max cycles to run (default: infinite)")
         (exit 0))
        (else (loop (cdr rest)))))))

(def (main . args)
  (let-values (((port cycles) (parse-args args)))
    ;; Determine port
    (let ((port (or port (read-repl-port-file))))
      (unless port
        (displayln "ERROR: Could not determine REPL port.")
        (displayln "Either pass --port or ensure jemacs-qt is running with --repl.")
        (exit 1))

      (set! *repl-port* port)
      (set! *max-cycles* cycles)

      (displayln "=== JEMACS-QT STRESS TEST ===")
      (displayln "REPL port: " *repl-port*)
      (when *max-cycles*
        (displayln "Max cycles: " *max-cycles*))
      (displayln "Log file: " *log-file*)
      (displayln "")

      ;; Open log file
      (set! *log-port* (open-output-file *log-file* 'replace))

      ;; Connect
      (log! (str "Connecting to REPL on port " *repl-port* "..."))
      (connect! *repl-port*)
      (log! "Connected!")

      ;; Verify connection
      (let ((resp (send-eval! "(+ 1 1)")))
        (log! (str "Connection verified: (+ 1 1) => " resp)))

      ;; Run stress loop
      (let loop ((cycle 0))
        (when (or (not *max-cycles*) (< cycle *max-cycles*))
          (log! (str "========== CYCLE " cycle
                     " (cmds=" *commands-sent*
                     " errs=" *errors-caught* ") =========="))

          ;; Randomize phase order each cycle for variety
          (let ((phases (list
                          (cons "window-chaos"   phase-window-chaos!)
                          (cons "vterm-storm"     phase-vterm-storm!)
                          (cons "file-churn"      phase-file-churn!)
                          (cons "navigation"      phase-navigation-stress!)
                          (cons "eww"             phase-eww!)
                          (cons "edit-storm"      phase-edit-storm!)
                          (cons "buffer-mgmt"     phase-buffer-management!)
                          (cons "combined-chaos"  phase-combined-chaos!)
                          (cons "window-thrash"   phase-window-thrash!)
                          (cons "search-ops"      phase-search-ops!))))
            ;; Run a random subset of phases each cycle (5-10 phases)
            (let ((count (+ 5 (random 6))))
              (dotimes (_ count)
                (let ((phase (random-choice phases)))
                  (with-phase-error-handler (car phase)
                    (cdr phase))))))

          ;; Cleanup periodically
          (when (zero? (modulo (+ cycle 1) 5))
            (cleanup-temp-files!))

          (loop (+ cycle 1))))

      ;; Final stats
      (log! "=== STRESS TEST COMPLETE ===")
      (log! (str "Total commands: " *commands-sent*))
      (log! (str "Total errors caught: " *errors-caught*))
      (displayln "")
      (displayln "Stress test finished.")
      (displayln "Total commands: " *commands-sent*)
      (displayln "Total errors caught: " *errors-caught*)

      ;; Cleanup
      (cleanup-temp-files!)
      (disconnect!)
      (when *log-port*
        (close-port *log-port*)))))

;; Run
(apply main (cdr (command-line)))
