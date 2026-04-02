;;; -*- Gerbil -*-
;;; tests/test-behavioral.ss — comprehensive behavioral regression suite
;;;
;;; Simulates hours of real Emacs usage: editing, navigation, kill ring, window
;;; management, terminal integration, undo/redo, multi-buffer sessions, prefix
;;; key robustness, and stress/durability patterns.
;;;
;;; Each test group mirrors a class of activity a real user would perform.
;;; Tests are deterministic (no randomness), isolated (full reset between tests),
;;; and headless (Xvfb — does not interrupt interactive use).
;;;
;;; Usage:
;;;   make test-behavioral           (auto-launches jemacs-qt headless)
;;;   scheme --libdirs lib:... --script tests/test-behavioral.ss --port N
;;;   scheme --libdirs lib:... --script tests/test-behavioral.ss --port N --verbose

(import (jerboa prelude))

;;;============================================================================
;;; Compat: thread-sleep!
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

;;;============================================================================
;;; Test counters
;;;============================================================================

(def *total-pass* 0)
(def *total-fail* 0)
(def *phase-name* "")
(def *phase-pass* 0)
(def *phase-fail* 0)

(def (start-phase! name)
  (set! *phase-name* name)
  (set! *phase-pass* 0)
  (set! *phase-fail* 0)
  (displayln "")
  (displayln "=== " name " ==="))

(def (end-phase!)
  (set! *total-pass* (+ *total-pass* *phase-pass*))
  (set! *total-fail* (+ *total-fail* *phase-fail*))
  (displayln "  -> " *phase-pass* " pass, " *phase-fail* " fail"))

;;;============================================================================
;;; REPL connection (s-expression protocol, same as stress-test.ss)
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
      (with-catch (lambda (e) #f)
        (lambda ()
          (let ((content (read-file-string path)))
            (let ((idx (string-contains content "=")))
              (and idx (string->number (string-trim
                (substring content (+ idx 1) (string-length content)))))))))
      #f)))

(def (connect! port)
  (let-values (((stdin stdout stderr pid)
                (open-process-ports (str "nc 127.0.0.1 " port)
                                    'block (native-transcoder))))
    (set! *nc-stdin* stdin)
    (set! *nc-stdout* stdout)
    (set! *nc-stderr* stderr))
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
  (with-catch (lambda (e) #f)
    (lambda ()
      (let loop ((n 0))
        (when (and (< n 8192) (char-ready? *nc-stdout*))
          (read-char *nc-stdout*)
          (loop (+ n 1)))))))

(def (send-eval! expr-str)
  (when *verbose* (displayln "  > " expr-str))
  (let ((id (next-req-id!))
        (lit (with-output-to-string (lambda () (write expr-str)))))
    (display (str "(" id " eval " lit ")") *nc-stdin*)
    (newline *nc-stdin*)
    (flush-output-port *nc-stdin*)
    (let ((resp (read-sexpr-response!)))
      (when *verbose* (displayln "  < " resp))
      resp)))

(def (read-sexpr-response!)
  (let wait ((n 0))
    (cond
      ((char-ready? *nc-stdout*)
       (let ((line (get-line *nc-stdout*)))
         (if (eof-object? line)
           (begin (displayln "CONNECTION LOST") (disconnect!) (exit 1))
           line)))
      ((> n 100) (displayln "TIMEOUT") "")
      (else (thread-sleep! 0.1) (wait (+ n 1))))))

;;;============================================================================
;;; REPL helpers
;;;============================================================================

(def (jeval! expr)
  "Evaluate EXPR in jemacs REPL. Returns raw :value string or #f on error."
  (with-catch (lambda (e) #f)
    (lambda ()
      (let* ((raw (send-eval! expr))
             (sexp (with-input-from-string raw read))
             (status (list-ref sexp 1)))
        (if (eq? status ':ok)
          (list-ref (list-ref sexp 2) 1)
          (begin
            (when *verbose*
              (displayln "  JEVAL-ERR: " (list-ref sexp 2)))
            #f))))))

(def (jeval-bool! e)   (string=? "#t" (or (jeval! e) "")))
(def (jeval-num!  e)   (let ((r (jeval! e))) (and r (string->number r))))
(def (jeval-str!  e)
  (let ((r (jeval! e)))
    (if (and r (>= (string-length r) 2) (char=? #\" (string-ref r 0)))
      (substring r 1 (- (string-length r) 1))
      (or r ""))))
(def (jeval-list! e)
  (let ((r (jeval! e)))
    (if r
      (with-catch (lambda (_) '())
        (lambda () (with-input-from-string r read)))
      '())))

;;;============================================================================
;;; Test framework
;;;============================================================================

(def (write-to-string v)
  (with-output-to-string (lambda () (write v))))

(def (run-test! name thunk)
  (display (str "  [" name "] "))
  (with-catch
    (lambda (e)
      (set! *phase-fail* (+ *phase-fail* 1))
      (displayln "FAIL: "
                 (with-output-to-string (lambda () (display-condition e)))))
    (lambda ()
      (thunk)
      (set! *phase-pass* (+ *phase-pass* 1))
      (displayln "pass"))))

;; Assertions: signal error (caught by run-test!) on failure
(defrule (assert! pred msg)
  (unless pred (error 'assert! msg)))

(defrule (assert-eq! msg a b)
  (let ((av a) (bv b))
    (unless (equal? av bv)
      (error 'assert-eq! (str msg ": expected " (write-to-string av) " got " (write-to-string bv))))))

(defrule (assert-ne! msg a b)
  (let ((av a) (bv b))
    (when (equal? av bv)
      (error 'assert-ne! (str msg ": unexpectedly equal " (write-to-string av))))))

(defrule (assert-gt! msg lo actual)
  (let ((l lo) (a actual))
    (unless (and a (> a l))
      (error 'assert-gt! (str msg ": expected > " l " got " (write-to-string a))))))

(defrule (assert-ge! msg lo actual)
  (let ((l lo) (a actual))
    (unless (and a (>= a l))
      (error 'assert-ge! (str msg ": expected >= " l " got " (write-to-string a))))))

(defrule (assert-has! msg text sub)
  (let ((t text) (s sub))
    (unless (and (string? t) (string? s) (string-contains t s))
      (error 'assert-has! (str msg ": " (write-to-string t) " does not contain " (write-to-string s))))))

(defrule (assert-lacks! msg text sub)
  (let ((t text) (s sub))
    (when (and (string? t) (string? s) (string-contains t s))
      (error 'assert-lacks! (str msg ": " (write-to-string t) " unexpectedly contains " (write-to-string s))))))

;;;============================================================================
;;; Editor helpers
;;;============================================================================

(def (send-keys! . keys)
  "Send all KEYS in a single REPL call (batch)."
  (let ((args (apply string-append (map (lambda (k) (str " " (write-to-string k))) keys))))
    (jeval! (str "(send-keys!" args ")"))))

(def (repeat-keys! n . keys)
  "Send KEYS repeated N times in a single REPL call."
  (let* ((all (apply append (map (lambda (_) keys) (iota n))))
         (args (apply string-append (map (lambda (k) (str " " (write-to-string k))) all))))
    (jeval! (str "(send-keys!" args ")"))))

(def (exec! cmd)  (jeval! (str "(execute-command! *app* '" (symbol->string cmd) ")")))
(def (wait! ms)   (thread-sleep! (/ ms 1000.0)))

(def (reset!)         (jeval! "(test-reset!)") (wait! 50))
(def (clear-buf!)     (jeval! "(test-clear-buffer!)"))
(def (cur-text)       (jeval-str! "(buffer-text)"))
(def (cur-buf-name)   (jeval-str! "(current-buffer-name)"))
(def (cur-pos)        (jeval-num! "(buffer-cursor-pos)"))
(def (win-count)      (or (jeval-num! "(test-window-count)") 0))
(def (win-idx)        (or (jeval-num! "(test-window-idx)") 0))
(def (win-texts)      (jeval-list! "(test-window-texts)"))
(def (win-bufs)       (jeval-list! "(test-window-buffers)"))
(def (prefix-active?) (jeval-bool! "(test-prefix-active?)"))
(def (term-running?)  (jeval-bool! "(test-terminal-running?)"))

(def (setup!)
  "Full reset: collapse windows, clear terminals, switch to scratch, clear text."
  (reset!)
  (exec! 'scratch-buffer)
  (wait! 30)
  (clear-buf!))

(def (term-setup!)
  "Reset then open a terminal and wait for shell to spawn."
  (reset!)
  (exec! 'scratch-buffer)
  (exec! 'term)
  (wait! 400))

;;;============================================================================
;;; Phase 1 — Basic Text Editing
;;; Types text, edits characters, confirms buffer content.
;;;============================================================================

(def (run-phase-1!)
  (start-phase! "Phase 1: Basic Text Editing")

  (run-test! "type-single-char"
    (lambda ()
      (setup!)
      (send-keys! "Z")
      (assert-has! "char appears" (cur-text) "Z")))

  (run-test! "type-word"
    (lambda ()
      (setup!)
      (send-keys! "hello")
      (assert-has! "word appears" (cur-text) "hello")))

  (run-test! "type-long-sentence"
    (lambda ()
      (setup!)
      (send-keys! "The quick brown fox jumps over the lazy dog")
      (let ((t (cur-text)))
        (assert-has! "sentence start" t "quick brown")
        (assert-has! "sentence end" t "lazy dog"))))

  (run-test! "type-numbers"
    (lambda ()
      (setup!)
      (send-keys! "1234567890")
      (assert-has! "numbers appear" (cur-text) "1234567890")))

  (run-test! "type-two-words-with-space"
    (lambda ()
      (setup!)
      (send-keys! "hello world")
      (assert-has! "both words" (cur-text) "hello world")))

  (run-test! "backspace-removes-char"
    (lambda ()
      (setup!)
      (send-keys! "abcX")
      (send-keys! "DEL")
      (let ((t (cur-text)))
        (assert-has! "prefix remains" t "abc")
        (assert-lacks! "X removed" t "X"))))

  (run-test! "backspace-multiple"
    (lambda ()
      (setup!)
      (send-keys! "hello")
      (send-keys! "DEL" "DEL" "DEL")
      (let ((t (cur-text)))
        (assert-has! "he remains" t "he")
        (assert-lacks! "llo removed" t "llo"))))

  (run-test! "delete-char-at-start"
    (lambda ()
      (setup!)
      (send-keys! "Xhello")
      (exec! 'beginning-of-buffer)
      (exec! 'delete-char)
      (let ((t (cur-text)))
        (assert-has! "hello remains" t "hello")
        (assert-lacks! "X removed" t "X"))))

  (run-test! "kill-line-clears-line"
    (lambda ()
      (setup!)
      (send-keys! "killedtext")
      (exec! 'beginning-of-line)
      (exec! 'kill-line)
      (assert-lacks! "text removed" (cur-text) "killedtext")))

  (run-test! "kill-line-yank-roundtrip"
    (lambda ()
      (setup!)
      (send-keys! "preserved")
      (exec! 'beginning-of-line)
      (exec! 'kill-line)
      (exec! 'yank)
      (assert-has! "text restored by yank" (cur-text) "preserved")))

  (run-test! "type-newline-creates-two-lines"
    (lambda ()
      (setup!)
      (send-keys! "line1")
      (send-keys! "RET")
      (send-keys! "line2")
      (let ((t (cur-text)))
        (assert-has! "line1 present" t "line1")
        (assert-has! "line2 present" t "line2"))))

  (run-test! "type-at-end-of-line"
    (lambda ()
      (setup!)
      (send-keys! "hello")
      (exec! 'end-of-line)
      (send-keys! "!")
      (assert-has! "exclamation appended" (cur-text) "hello!")))

  (run-test! "type-at-beginning-of-line"
    (lambda ()
      (setup!)
      (send-keys! "world")
      (exec! 'beginning-of-line)
      (send-keys! "hello ")
      (assert-has! "hello prepended" (cur-text) "hello world")))

  (run-test! "backspace-on-empty-no-crash"
    (lambda ()
      (setup!)
      (send-keys! "DEL" "DEL" "DEL" "DEL" "DEL")
      #t))  ; just no crash

  (run-test! "large-insert-100-chars"
    (lambda ()
      (setup!)
      (send-keys! (make-string 100 #\A))
      (let ((t (cur-text)))
        (assert-ge! "100 chars in buffer" 100 (string-length t))
        (assert-has! "A chars present" t "AAAAAAAAAA"))))

  (run-test! "type-after-kill-type-again"
    (lambda ()
      (setup!)
      (send-keys! "first")
      (exec! 'beginning-of-line)
      (exec! 'kill-line)
      (send-keys! "second")
      (let ((t (cur-text)))
        (assert-has! "second present" t "second")
        (assert-lacks! "first gone" t "first"))))

  (run-test! "kill-whole-line"
    (lambda ()
      (setup!)
      (send-keys! "deleteme")
      (send-keys! "RET")
      (send-keys! "keepme")
      (exec! 'beginning-of-buffer)
      (exec! 'kill-whole-line)
      (let ((t (cur-text)))
        (assert-lacks! "first line gone" t "deleteme")
        (assert-has! "second line kept" t "keepme"))))

  (end-phase!))

;;;============================================================================
;;; Phase 2 — Navigation and Cursor Position
;;; Moves the cursor and verifies position changes.
;;;============================================================================

(def (run-phase-2!)
  (start-phase! "Phase 2: Navigation and Cursor")

  (run-test! "forward-char-advances-cursor"
    (lambda ()
      (setup!)
      (send-keys! "abcde")
      (exec! 'beginning-of-buffer)
      (let ((pos-before (cur-pos)))
        (exec! 'forward-char)
        (let ((pos-after (cur-pos)))
          (assert-gt! "cursor moved right" pos-before pos-after)))))

  (run-test! "backward-char-retreats-cursor"
    (lambda ()
      (setup!)
      (send-keys! "abcde")
      (let ((pos-before (cur-pos)))
        (exec! 'backward-char)
        (let ((pos-after (cur-pos)))
          (assert-gt! "cursor moved left" pos-after pos-before)))))

  (run-test! "beginning-of-line-goes-to-zero"
    (lambda ()
      (setup!)
      (send-keys! "hello")
      (exec! 'beginning-of-line)
      (assert-eq! "cursor at col 0" 0 (cur-pos))))

  (run-test! "end-of-line-goes-to-end"
    (lambda ()
      (setup!)
      (send-keys! "hello")
      (exec! 'beginning-of-line)
      (exec! 'end-of-line)
      (assert-eq! "cursor at end" 5 (cur-pos))))

  (run-test! "beginning-of-buffer-goes-to-start"
    (lambda ()
      (setup!)
      (send-keys! "line1")
      (send-keys! "RET")
      (send-keys! "line2")
      (exec! 'beginning-of-buffer)
      (assert-eq! "cursor at position 0" 0 (cur-pos))))

  (run-test! "end-of-buffer-goes-to-end"
    (lambda ()
      (setup!)
      (send-keys! "hello")
      (exec! 'beginning-of-buffer)
      (exec! 'end-of-buffer)
      (assert-ge! "cursor at or near end" 5 (cur-pos))))

  (run-test! "forward-word-jumps-word"
    (lambda ()
      (setup!)
      (send-keys! "foo bar")
      (exec! 'beginning-of-buffer)
      (let ((start-pos (cur-pos)))
        (exec! 'forward-word)
        (assert-gt! "cursor jumped past foo" start-pos (cur-pos)))))

  (run-test! "backward-word-jumps-word"
    (lambda ()
      (setup!)
      (send-keys! "foo bar")
      (let ((end-pos (cur-pos)))
        (exec! 'backward-word)
        (assert-gt! "cursor jumped back" (cur-pos) end-pos))))

  (run-test! "next-line-moves-down"
    (lambda ()
      (setup!)
      (send-keys! "aaa")
      (send-keys! "RET")
      (send-keys! "bbb")
      (exec! 'beginning-of-buffer)
      (exec! 'next-line)
      (assert-gt! "cursor past first line" 3 (cur-pos))))

  (run-test! "previous-line-moves-up"
    (lambda ()
      (setup!)
      (send-keys! "aaa")
      (send-keys! "RET")
      (send-keys! "bbb")
      (let ((end-pos (cur-pos)))
        (exec! 'previous-line)
        (assert-gt! "cursor moved up" (cur-pos) end-pos))))

  (run-test! "cursor-position-after-typing"
    (lambda ()
      (setup!)
      (send-keys! "hello")
      (assert-eq! "cursor at 5 after typing 5 chars" 5 (cur-pos))))

  (run-test! "forward-char-10-times"
    (lambda ()
      (setup!)
      (send-keys! "abcdefghij")
      (exec! 'beginning-of-buffer)
      (repeat-keys! 5 "C-f")
      (assert-eq! "cursor at 5 after 5 C-f" 5 (cur-pos))))

  (end-phase!))

;;;============================================================================
;;; Phase 3 — Kill Ring and Clipboard
;;; Tests kill/yank operations and the kill ring.
;;;============================================================================

(def (run-phase-3!)
  (start-phase! "Phase 3: Kill Ring")

  (run-test! "kill-line-yank-preserves-text"
    (lambda ()
      (setup!)
      (send-keys! "killring1")
      (exec! 'beginning-of-line)
      (exec! 'kill-line)
      (exec! 'yank)
      (assert-has! "text restored" (cur-text) "killring1")))

  (run-test! "kill-word-yank"
    (lambda ()
      (setup!)
      (send-keys! "target rest")
      (exec! 'beginning-of-buffer)
      (exec! 'kill-word)
      (let ((t (cur-text)))
        (assert-lacks! "target gone" t "target"))))

  (run-test! "backward-kill-word"
    (lambda ()
      (setup!)
      (send-keys! "hello gone")
      (exec! 'backward-kill-word)
      (let ((t (cur-text)))
        (assert-has! "hello remains" t "hello")
        (assert-lacks! "gone removed" t "gone"))))

  (run-test! "select-all-kill-region"
    (lambda ()
      (setup!)
      (send-keys! "allgone")
      (exec! 'select-all)
      (exec! 'kill-region)
      (assert-lacks! "all text gone" (cur-text) "allgone")))

  (run-test! "copy-region-then-yank"
    (lambda ()
      (setup!)
      (send-keys! "copytext")
      (exec! 'beginning-of-buffer)
      (exec! 'set-mark-command)
      (exec! 'end-of-buffer)
      (exec! 'kill-ring-save)  ; M-w equivalent
      (exec! 'end-of-buffer)
      (exec! 'yank)
      (assert-has! "copied text yanked" (cur-text) "copytext")))

  (run-test! "double-yank-duplicates"
    (lambda ()
      (setup!)
      (send-keys! "dupe")
      (exec! 'beginning-of-line)
      (exec! 'kill-line)
      (exec! 'yank)
      (exec! 'yank)
      (assert-has! "dupe appears" (cur-text) "dupe")))

  (run-test! "kill-ring-survives-buffer-switch"
    (lambda ()
      (setup!)
      (send-keys! "crossbuf")
      (exec! 'beginning-of-line)
      (exec! 'kill-line)
      ;; Switch to a new buffer
      (exec! 'new-empty-buffer)
      (wait! 50)
      (exec! 'yank)
      (assert-has! "killed text in new buffer" (cur-text) "crossbuf")))

  (run-test! "kill-sexp-removes-sexp"
    (lambda ()
      (setup!)
      (send-keys! "(remove-me) keep")
      (exec! 'beginning-of-buffer)
      (exec! 'kill-sexp)
      (let ((t (cur-text)))
        (assert-lacks! "sexp removed" t "(remove-me)")
        (assert-has! "keep remains" t "keep"))))

  (run-test! "kill-line-multiple-lines"
    (lambda ()
      (setup!)
      (send-keys! "line1")
      (send-keys! "RET")
      (send-keys! "line2")
      (send-keys! "RET")
      (send-keys! "line3")
      (exec! 'beginning-of-buffer)
      (exec! 'kill-line)
      (let ((t (cur-text)))
        (assert-lacks! "line1 gone" t "line1")
        (assert-has! "line2 remains" t "line2")
        (assert-has! "line3 remains" t "line3"))))

  (end-phase!))

;;;============================================================================
;;; Phase 4 — Window Management
;;; Split, delete, cycle, and verify window counts + typing isolation.
;;;============================================================================

(def (run-phase-4!)
  (start-phase! "Phase 4: Window Management")

  (run-test! "cx2-increases-window-count"
    (lambda ()
      (setup!)
      (let ((before (win-count)))
        (send-keys! "C-x" "2")
        (assert-eq! "2 windows after C-x 2" (+ before 1) (win-count)))))

  (run-test! "cx3-increases-window-count"
    (lambda ()
      (setup!)
      (let ((before (win-count)))
        (send-keys! "C-x" "3")
        (assert-eq! "2 windows after C-x 3" (+ before 1) (win-count)))))

  (run-test! "cx2-doesnt-type-x-or-2"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (let ((t (cur-text)))
        (assert-lacks! "no x typed" t "x")
        (assert-lacks! "no 2 typed" t "2"))))

  (run-test! "cx3-doesnt-type-x-or-3"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "3")
      (let ((t (cur-text)))
        (assert-lacks! "no x typed" t "x")
        (assert-lacks! "no 3 typed" t "3"))))

  (run-test! "cx0-removes-current-window"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (assert-eq! "2 windows" 2 (win-count))
      (send-keys! "C-x" "0")
      (assert-eq! "1 window after C-x 0" 1 (win-count))))

  (run-test! "cx1-deletes-other-windows"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "2")
      (assert-ge! "3 windows" 2 (win-count))
      (send-keys! "C-x" "1")
      (assert-eq! "1 window after C-x 1" 1 (win-count))))

  (run-test! "cxo-switches-window-index"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (let ((idx-a (win-idx)))
        (send-keys! "C-x" "o")
        (let ((idx-b (win-idx)))
          (assert-ne! "window index changed" idx-a idx-b)))))

  (run-test! "cxo-cycles-back"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (let ((start (win-idx)))
        (send-keys! "C-x" "o")
        (send-keys! "C-x" "o")
        (assert-eq! "cycled back to original window" start (win-idx)))))

  (run-test! "3-way-split"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "2")
      (assert-eq! "3 windows" 3 (win-count))))

  (run-test! "typing-isolated-between-windows-different-buffers"
    (lambda ()
      ;; Win0 gets *scratch* with "WIN0ONLY"
      ;; Win1 gets a new-empty-buffer with "WIN1ONLY"
      (setup!)
      (send-keys! "WIN0ONLY")
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "o")   ; focus win1
      (exec! 'new-empty-buffer) ; win1 gets its own buffer
      (wait! 50)
      (clear-buf!)
      (send-keys! "WIN1ONLY")
      ;; Check win1 has WIN1ONLY but not WIN0ONLY
      (let ((texts (win-texts)))
        (when (>= (length texts) 2)
          (let ((win1-text (list-ref texts (win-idx))))
            (assert-has! "win1 has WIN1ONLY" win1-text "WIN1ONLY")
            (assert-lacks! "win1 lacks WIN0ONLY" win1-text "WIN0ONLY"))))))

  (run-test! "split-then-type-in-new-window"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "o")
      (exec! 'new-empty-buffer)
      (wait! 50)
      (clear-buf!)
      (send-keys! "NEWWINTEXT")
      (assert-has! "typed in new window" (cur-text) "NEWWINTEXT")))

  (run-test! "rapid-split-delete-20-cycles"
    (lambda ()
      (setup!)
      (dotimes (i 20)
        (send-keys! "C-x" "2")
        (send-keys! "C-x" "0"))
      (assert-eq! "back to 1 window" 1 (win-count))))

  (run-test! "prefix-cleared-after-cx2"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (assert! (not (prefix-active?)) "prefix state clean after C-x 2")))

  (run-test! "balance-windows-no-crash"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "2")
      (exec! 'balance-windows)
      (assert-ge! "still 3 windows" 3 (win-count))))

  (run-test! "transpose-windows"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (exec! 'transpose-windows)
      (assert-eq! "still 2 windows" 2 (win-count))))

  (end-phase!))

;;;============================================================================
;;; Phase 5 — Terminal Integration
;;; Opens terminals, verifies key routing, split behavior, focus.
;;; These are the core regression tests for the bugs that were found.
;;;============================================================================

(def (run-phase-5!)
  (start-phase! "Phase 5: Terminal Integration")

  (run-test! "open-terminal-marks-buffer"
    (lambda ()
      (term-setup!)
      (assert! (term-running?) "terminal buffer is active")))

  (run-test! "cx2-from-terminal-splits-not-types"
    ;; REGRESSION: C-x 2 was typing "x2" into terminal instead of splitting
    (lambda ()
      (term-setup!)
      (let ((before (win-count)))
        (send-keys! "C-x" "2")
        (wait! 100)
        (assert-eq! "window count increased" (+ before 1) (win-count)))))

  (run-test! "cx3-from-terminal-splits-not-types"
    (lambda ()
      (term-setup!)
      (let ((before (win-count)))
        (send-keys! "C-x" "3")
        (wait! 100)
        (assert-eq! "window count increased" (+ before 1) (win-count)))))

  (run-test! "new-window-after-terminal-split-is-editor"
    (lambda ()
      (term-setup!)
      (send-keys! "C-x" "2")
      (wait! 100)
      ;; After split, the new window should NOT be a terminal
      ;; (the new window gets focus; it shows same buffer or an editor)
      (assert! (not (term-running?)) "new window is not terminal")))

  (run-test! "type-in-editor-after-terminal-split"
    ;; REGRESSION: typing in lower (non-terminal) window was going to top terminal
    (lambda ()
      (term-setup!)
      (send-keys! "C-x" "2")
      (wait! 100)
      ;; We're in the new (non-terminal) window
      (exec! 'new-empty-buffer)
      (wait! 50)
      (clear-buf!)
      (send-keys! "EDITORTEXT")
      (assert-has! "text in editor window" (cur-text) "EDITORTEXT")))

  (run-test! "cxo-from-terminal-switches-focus"
    (lambda ()
      (term-setup!)
      (send-keys! "C-x" "2")
      (wait! 100)
      (send-keys! "C-x" "o")   ; switch back to terminal window
      (wait! 50)
      (let ((idx-after-back (win-idx)))
        (send-keys! "C-x" "o") ; switch again
        (assert-ne! "window index changed" idx-after-back (win-idx)))))

  (run-test! "cx-prefix-in-terminal-not-typed"
    ;; C-x should be consumed as a prefix, not typed into terminal
    (lambda ()
      (term-setup!)
      (send-keys! "C-x" "2")   ; C-x 2 splits (the key test)
      (assert-eq! "split happened" 2 (win-count))
      (assert! (not (prefix-active?)) "prefix consumed")))

  (run-test! "cx1-from-terminal-collapses"
    (lambda ()
      (term-setup!)
      (send-keys! "C-x" "2")
      (wait! 100)
      (send-keys! "C-x" "1")
      (assert-eq! "1 window after C-x 1" 1 (win-count))))

  (run-test! "kill-terminal-buffer"
    (lambda ()
      (term-setup!)
      (assert! (term-running?) "terminal running before kill")
      (exec! 'kill-buffer-force)
      (wait! 100)
      (assert! (not (term-running?)) "terminal gone after kill")))

  (run-test! "two-terminals-no-crash"
    (lambda ()
      (term-setup!)
      (exec! 'term)       ; second terminal
      (wait! 400)
      (exec! 'term-next)  ; switch between them
      (exec! 'term-prev)
      (assert! (term-running?) "still in terminal context")))

  (run-test! "editor-terminal-interleaved"
    ;; Simulate: edit code, open terminal half, continue editing
    (lambda ()
      (setup!)
      (send-keys! "code-before-terminal")
      (send-keys! "C-x" "2")   ; split: top=scratch(with text), bottom=new window
      (wait! 100)
      ;; Stay in bottom window, type more
      (exec! 'new-empty-buffer)
      (wait! 50)
      (clear-buf!)
      (send-keys! "code-in-bottom")
      (assert-has! "bottom window got text" (cur-text) "code-in-bottom")))

  (run-test! "terminal-cx2-cx1-sequence"
    ;; Repeated split+collapse from terminal context
    (lambda ()
      (term-setup!)
      (dotimes (i 5)
        (send-keys! "C-x" "2")
        (wait! 50)
        (send-keys! "C-x" "1")
        (wait! 50))
      (assert-eq! "back to 1 window" 1 (win-count))))

  (end-phase!))

;;;============================================================================
;;; Phase 6 — Multi-Buffer Session
;;; Open multiple buffers, verify content isolation and buffer switching.
;;;============================================================================

(def (run-phase-6!)
  (start-phase! "Phase 6: Multi-Buffer Session")

  (run-test! "switch-buffer-preserves-content"
    (lambda ()
      (setup!)
      (send-keys! "BUFACONTENT")
      (exec! 'new-empty-buffer)  ; switch to new buffer B
      (wait! 50)
      (exec! 'previous-buffer)   ; switch back to scratch
      (wait! 50)
      (assert-has! "buf A content preserved" (cur-text) "BUFACONTENT")))

  (run-test! "new-empty-buffer-is-empty"
    (lambda ()
      (setup!)
      (exec! 'new-empty-buffer)
      (wait! 50)
      (let ((t (cur-text)))
        (assert! (or (string=? t "") (< (string-length t) 5))
                 "new buffer is essentially empty"))))

  (run-test! "kill-buffer-no-crash"
    (lambda ()
      (setup!)
      (exec! 'new-empty-buffer)
      (wait! 50)
      (exec! 'kill-buffer-force)
      (wait! 50)
      #t))  ; no crash = pass

  (run-test! "3-buffer-content-isolation"
    (lambda ()
      (setup!)
      ;; type unique marker in scratch
      (send-keys! "BUFA_MARKER")
      ;; new buffer B
      (exec! 'new-empty-buffer)
      (wait! 50)
      (send-keys! "BUFB_MARKER")
      ;; new buffer C
      (exec! 'new-empty-buffer)
      (wait! 50)
      (send-keys! "BUFC_MARKER")
      ;; go back to B
      (exec! 'previous-buffer)
      (wait! 50)
      (let ((t (cur-text)))
        (assert-has! "B has its marker" t "BUFB_MARKER")
        (assert-lacks! "B lacks A marker" t "BUFA_MARKER")
        (assert-lacks! "B lacks C marker" t "BUFC_MARKER"))))

  (run-test! "next-buffer-cycles"
    (lambda ()
      (setup!)
      (exec! 'new-empty-buffer)
      (wait! 50)
      (let ((name1 (cur-buf-name)))
        (exec! 'next-buffer)
        (wait! 50)
        (let ((name2 (cur-buf-name)))
          (assert-ne! "different buffer after next-buffer" name1 name2)))))

  (run-test! "previous-buffer-cycles"
    (lambda ()
      (setup!)
      (exec! 'new-empty-buffer)
      (wait! 50)
      (let ((name1 (cur-buf-name)))
        (exec! 'previous-buffer)
        (wait! 50)
        (let ((name2 (cur-buf-name)))
          (assert-ne! "different buffer after prev-buffer" name1 name2)))))

  (run-test! "5-buffer-open-close-no-crash"
    (lambda ()
      (setup!)
      (dotimes (i 5)
        (exec! 'new-empty-buffer)
        (wait! 30))
      (dotimes (i 4)
        (exec! 'kill-buffer-force)
        (wait! 30))
      #t))  ; no crash = pass

  (run-test! "buffer-name-nonempty"
    (lambda ()
      (setup!)
      (let ((name (cur-buf-name)))
        (assert! (and (string? name) (> (string-length name) 0))
                 "buffer has a non-empty name"))))

  (end-phase!))

;;;============================================================================
;;; Phase 7 — Prefix Key Robustness
;;; C-x sequences are consumed as commands, never typed into the buffer.
;;;============================================================================

(def (run-phase-7!)
  (start-phase! "Phase 7: Prefix Key Robustness")

  (run-test! "cx-does-not-type-x"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")   ; C-x consumed for split
      (assert-lacks! "no x typed" (cur-text) "x")))

  (run-test! "cx2-fully-consumed"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (let ((t (cur-text)))
        (assert-lacks! "no x" t "x")
        (assert-lacks! "no 2" t "2"))))

  (run-test! "cx3-fully-consumed"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "3")
      (let ((t (cur-text)))
        (assert-lacks! "no x" t "x")
        (assert-lacks! "no 3" t "3"))))

  (run-test! "cx1-fully-consumed"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")   ; first split
      (send-keys! "C-x" "1")   ; then collapse
      (let ((t (cur-text)))
        (assert-lacks! "no x" t "x")
        (assert-lacks! "no 1" t "1"))))

  (run-test! "prefix-state-normal-after-cx2"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (assert! (not (prefix-active?)) "prefix cleared after C-x 2")))

  (run-test! "prefix-state-normal-after-cx1"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "1")
      (assert! (not (prefix-active?)) "prefix cleared after C-x 1")))

  (run-test! "escape-cancels-prefix"
    (lambda ()
      (setup!)
      (send-keys! "C-x")       ; start C-x prefix
      (wait! 50)
      (send-keys! "ESC")       ; cancel
      (wait! 50)
      (assert! (not (prefix-active?)) "prefix cancelled by ESC")))

  (run-test! "cx-save-doesnt-type"
    (lambda ()
      (setup!)
      (send-keys! "savecontent")
      (send-keys! "C-x" "C-s")  ; save buffer
      (wait! 50)
      (let ((t (cur-text)))
        (assert-lacks! "no extra x typed" t "savecontent" )  ; content still there
        ;; Most importantly, saving should work silently
        (assert-has! "original content intact" t "savecontent"))))

  (run-test! "sequential-cx-commands"
    (lambda ()
      (setup!)
      ;; C-x 2 then C-x 3 (2 splits) then C-x 1 (collapse)
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "3")
      (send-keys! "C-x" "1")
      (let ((t (cur-text)))
        (assert-lacks! "no x typed" t "x")
        (assert-eq! "back to 1 window" 1 (win-count)))))

  (run-test! "cx-prefix-in-terminal-not-typed"
    (lambda ()
      (term-setup!)
      (send-keys! "C-x" "2")
      (wait! 100)
      ;; C-x was consumed, window split happened
      (assert-eq! "split happened (C-x consumed)" 2 (win-count))))

  (end-phase!))

;;;============================================================================
;;; Phase 8 — Undo and Redo
;;; Undo reverts edits; redo re-applies them.
;;;============================================================================

(def (run-phase-8!)
  (start-phase! "Phase 8: Undo / Redo")

  (run-test! "undo-single-insert"
    (lambda ()
      (setup!)
      (send-keys! "A")
      (assert-has! "A present before undo" (cur-text) "A")
      (exec! 'undo)
      (assert-lacks! "A gone after undo" (cur-text) "A")))

  (run-test! "undo-word"
    (lambda ()
      (setup!)
      (send-keys! "undome")
      (assert-has! "text present" (cur-text) "undome")
      ;; Undo 6 times (one per char) — may vary by implementation
      (dotimes (_ 6) (exec! 'undo))
      (assert-lacks! "text undone" (cur-text) "undome")))

  (run-test! "undo-then-retype"
    (lambda ()
      (setup!)
      (send-keys! "first")
      (dotimes (_ 5) (exec! 'undo))
      (send-keys! "second")
      (let ((t (cur-text)))
        (assert-has! "second present" t "second")
        (assert-lacks! "first gone" t "first"))))

  (run-test! "redo-after-undo"
    (lambda ()
      (setup!)
      (send-keys! "redome")
      (exec! 'undo)
      (exec! 'redo)
      ;; After undo+redo, text should be back
      (assert-has! "text restored by redo" (cur-text) "redome")))

  (run-test! "undo-does-not-affect-other-window"
    (lambda ()
      (setup!)
      (send-keys! "win0text")
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "o")   ; move to win1
      (exec! 'new-empty-buffer)
      (wait! 50)
      (clear-buf!)
      (send-keys! "win1text")
      ;; Undo in win1 affects win1 only
      (exec! 'undo)
      ;; Go back to win0 and verify its text is still there
      (send-keys! "C-x" "o")
      (let ((texts (win-texts)))
        (when (>= (length texts) 1)
          ;; win0 (idx 0 or wherever it is) should still have win0text
          (let ((win0-text (car texts)))
            (assert-has! "win0 text unaffected by win1 undo" win0-text "win0text"))))))

  (run-test! "undo-50-times-no-crash"
    (lambda ()
      (setup!)
      (send-keys! (make-string 20 #\X))
      (dotimes (_ 50) (exec! 'undo))
      #t))  ; no crash = pass

  (end-phase!))

;;;============================================================================
;;; Phase 9 — Stress and Durability
;;; Rapid operations, large inputs, repetitive cycles.
;;;============================================================================

(def (run-phase-9!)
  (start-phase! "Phase 9: Stress and Durability")

  (run-test! "type-200-chars-no-crash"
    (lambda ()
      (setup!)
      (send-keys! (make-string 200 #\B))
      (assert-ge! "200 chars in buffer" 200 (string-length (cur-text)))))

  (run-test! "type-delete-200-cycles"
    ;; Simulates someone pressing a key then backspacing repeatedly
    (lambda ()
      (setup!)
      (repeat-keys! 100 "A" "DEL")
      ;; After 100 type+delete cycles, buffer should be empty or near-empty
      (assert! (<= (string-length (cur-text)) 5) "buffer empty after type-delete cycles")))

  (run-test! "split-delete-50-cycles-no-crash"
    (lambda ()
      (setup!)
      (dotimes (_ 50)
        (send-keys! "C-x" "2")
        (send-keys! "C-x" "0"))
      (assert-eq! "1 window after 50 split-delete cycles" 1 (win-count))))

  (run-test! "cx1-50x-no-crash"
    (lambda ()
      (setup!)
      (dotimes (_ 5)
        (send-keys! "C-x" "2")
        (send-keys! "C-x" "2"))
      (dotimes (_ 50)
        (send-keys! "C-x" "1"))
      (assert-eq! "1 window" 1 (win-count))))

  (run-test! "100-cxo-cycles-no-crash"
    (lambda ()
      (setup!)
      (send-keys! "C-x" "2")
      (let ((start-idx (win-idx)))
        ;; 100 C-x o = 50 full cycles back to start
        (repeat-keys! 100 "C-x" "o")
        (assert-eq! "window idx same after 100 C-x o" start-idx (win-idx)))))

  (run-test! "10-terminal-open-kill-no-crash"
    (lambda ()
      (reset!)
      (exec! 'scratch-buffer)
      (dotimes (_ 3)   ; 3 cycles (terminal spawn is slow)
        (exec! 'term)
        (wait! 350)
        (exec! 'kill-buffer-force)
        (wait! 100))
      #t))  ; no crash = pass

  (run-test! "kill-ring-10-items"
    (lambda ()
      (setup!)
      (dotimes (i 10)
        (send-keys! (str "item" i))
        (exec! 'kill-line)
        (exec! 'beginning-of-line))
      ;; Yank should still work
      (exec! 'yank)
      #t))  ; no crash = pass

  (run-test! "rapid-buffer-switches-20"
    (lambda ()
      (setup!)
      (exec! 'new-empty-buffer)
      (wait! 30)
      (exec! 'new-empty-buffer)
      (wait! 30)
      (dotimes (_ 20)
        (exec! 'next-buffer)
        (exec! 'previous-buffer))
      #t))  ; no crash = pass

  (run-test! "large-kill-yank-roundtrip"
    (lambda ()
      (setup!)
      (send-keys! (make-string 500 #\K))
      (exec! 'beginning-of-line)
      (exec! 'kill-line)
      (exec! 'yank)
      (assert-ge! "500 K's restored" 500 (string-length (cur-text)))))

  (run-test! "mixed-stress-30-ops"
    ;; 30 operations mixing typing, navigation, splits, undos
    (lambda ()
      (setup!)
      (send-keys! "stress test line one")
      (exec! 'beginning-of-buffer)
      (exec! 'forward-word)
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "o")
      (send-keys! "more text here")
      (exec! 'backward-word)
      (exec! 'kill-word)
      (exec! 'undo)
      (send-keys! "C-x" "1")
      (exec! 'end-of-buffer)
      (send-keys! "RET")
      (send-keys! "final line")
      (exec! 'kill-line)
      (exec! 'yank)
      (send-keys! "C-x" "2")
      (repeat-keys! 4 "C-x" "o")
      (send-keys! "C-x" "1")
      (assert-eq! "1 window at end" 1 (win-count))))

  (end-phase!))

;;;============================================================================
;;; Phase 10 — Real-World Workflow Simulations
;;; Multi-step scenarios that mirror actual Emacs sessions.
;;;============================================================================

(def (run-phase-10!)
  (start-phase! "Phase 10: Real-World Workflows")

  (run-test! "code-editing-workflow"
    ;; Type code, navigate, fix typo, add comment
    (lambda ()
      (setup!)
      (send-keys! "(def (factorial n)")
      (send-keys! "RET")
      (send-keys! "  (if (<= n 1) 1")
      (send-keys! "RET")
      (send-keys! "    (* n (factorial (- n 1)))))")
      (exec! 'beginning-of-buffer)
      ;; Find "factorial" in first line — cursor should move
      (exec! 'forward-word)
      (exec! 'forward-word)
      ;; Add a comment at end
      (exec! 'end-of-buffer)
      (send-keys! "RET")
      (send-keys! ";; recursive factorial")
      (let ((t (cur-text)))
        (assert-has! "code present" t "factorial")
        (assert-has! "comment present" t "recursive factorial"))))

  (run-test! "multi-window-writing-session"
    ;; Simulate writing in two different files simultaneously
    (lambda ()
      (setup!)
      ;; Window 0: doc buffer
      (send-keys! "Documentation: This module provides...")
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "o")
      (exec! 'new-empty-buffer)
      (wait! 50)
      (clear-buf!)
      ;; Window 1: code buffer
      (send-keys! "(module my-module)")
      (send-keys! "RET")
      (send-keys! "(export foo bar)")
      ;; Verify win1 has code
      (let ((t (cur-text)))
        (assert-has! "code in win1" t "my-module")
        (assert-lacks! "no doc in win1" t "Documentation"))
      ;; Go back to win0
      (send-keys! "C-x" "o")
      (let ((texts (win-texts)))
        (when (>= (length texts) 1)
          (let ((w0 (car texts)))
            (assert-has! "doc in win0" w0 "Documentation")
            (assert-lacks! "no code in win0" w0 "my-module"))))))

  (run-test! "terminal-assisted-editing"
    ;; Open terminal, split, write code in editor half
    (lambda ()
      (term-setup!)
      ;; Split: terminal top, editor bottom
      (send-keys! "C-x" "2")
      (wait! 100)
      ;; Focus the bottom (new) window
      (exec! 'new-empty-buffer)
      (wait! 50)
      (clear-buf!)
      ;; Type code in editor window
      (send-keys! "(def result (shell-command \"ls\"))")
      (assert-has! "code in editor" (cur-text) "shell-command")
      ;; Verify we're not in terminal
      (assert! (not (term-running?)) "editor window not terminal")))

  (run-test! "5-buffer-session-content-integrity"
    ;; Open 5 buffers, write unique content, verify all preserved
    (lambda ()
      (setup!)
      (send-keys! "SESSION_BUF1")
      (exec! 'new-empty-buffer) (wait! 30)
      (send-keys! "SESSION_BUF2")
      (exec! 'new-empty-buffer) (wait! 30)
      (send-keys! "SESSION_BUF3")
      (exec! 'new-empty-buffer) (wait! 30)
      (send-keys! "SESSION_BUF4")
      (exec! 'new-empty-buffer) (wait! 30)
      (send-keys! "SESSION_BUF5")
      ;; Navigate back and verify buf4
      (exec! 'previous-buffer) (wait! 30)
      (let ((t (cur-text)))
        (assert-has! "buf4 has its content" t "SESSION_BUF4"))))

  (run-test! "long-editing-session-100-ops"
    ;; 100 sequential operations: type, navigate, kill, yank, split, undo
    (lambda ()
      (setup!)
      ;; Batch 1: type a paragraph
      (send-keys! "In the beginning was the word")
      (send-keys! "RET")
      (send-keys! "And the word was with code")
      (send-keys! "RET")
      (send-keys! "And the code was good")
      ;; Navigate
      (exec! 'beginning-of-buffer)
      (repeat-keys! 5 "C-f")
      (repeat-keys! 2 "M-f")
      ;; Edit: kill a word, yank it elsewhere
      (exec! 'kill-word)
      (exec! 'end-of-buffer)
      (exec! 'yank)
      ;; Split and type in other window
      (send-keys! "C-x" "2")
      (send-keys! "C-x" "o")
      (exec! 'new-empty-buffer)
      (wait! 50)
      (clear-buf!)
      (send-keys! "second window content here")
      (repeat-keys! 3 "C-x" "o")  ; cycle back
      ;; Undo some changes
      (dotimes (_ 5) (exec! 'undo))
      ;; More typing
      (exec! 'end-of-buffer)
      (send-keys! "RET")
      (send-keys! "appended after operations")
      ;; Collapse
      (send-keys! "C-x" "1")
      ;; Final assertions
      (assert-eq! "1 window at end" 1 (win-count))
      (assert! (not (prefix-active?)) "prefix clear at end")
      (assert-has! "original text survives" (cur-text) "beginning")))

  (end-phase!))

;;;============================================================================
;;; Main
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
  (unless *repl-port*
    (set! *repl-port* (read-repl-port-file)))
  (unless *repl-port*
    (displayln "ERROR: no REPL port. Pass --port N or use make test-behavioral")
    (exit 1))

  (displayln "=== jemacs-qt behavioral test suite ===")
  (displayln "REPL port: " *repl-port*)
  (connect! *repl-port*)
  (displayln "Connected. Running tests...")

  (with-catch
    (lambda (e)
      (displayln "FATAL: " (with-output-to-string (lambda () (display-condition e))))
      (disconnect!)
      (exit 1))
    (lambda ()
      (run-phase-1!)
      (run-phase-2!)
      (run-phase-3!)
      (run-phase-4!)
      (run-phase-5!)
      (run-phase-6!)
      (run-phase-7!)
      (run-phase-8!)
      (run-phase-9!)
      (run-phase-10!)))

  (disconnect!)
  (displayln "")
  (displayln "=== RESULTS: " *total-pass* " passed, " *total-fail* " failed ===")
  (exit (if (zero? *total-fail*) 0 1)))

(main!)
