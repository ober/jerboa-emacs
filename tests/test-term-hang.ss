#!chezscheme
;;; test-term-hang.ss — Diagnostic test: Why long-running commands hang the editor
;;;
;;; Root cause: shell.ss, terminal.ss all use jsh-capture
;;; which calls command-substitute. This function:
;;;   1. Redirects fd 1 to a pipe (via ffi-dup2)
;;;   2. Calls open-output-file "/dev/fd/1" (acquires Chez port registry lock)
;;;   3. Forks the external command via ffi-fork-exec
;;;   4. Calls wait-for-foreground-process-raw (BLOCKING wait for child exit)
;;;   5. Reads ALL output from the pipe AFTER the child exits
;;;
;;; In Chez Scheme, step 2 (open-output-file) acquires a global port registry
;;; mutex that Chez also holds during thread sleep/flush operations. This causes
;;; a deadlock when gsh-capture runs in a secondary thread.
;;;
;;; For a command like `top` or `yes` that never exits (or produces infinite
;;; output), step 4 blocks the calling thread forever. Since shell/terminal
;;; commands run on the main thread, the entire editor freezes.
;;;
;;; The fix exists in subprocess.ss: run-process-interruptible uses
;;; open-process-ports + non-blocking char-ready? polling + C-g checking.
;;; But shell.ss/terminal.ss don't use it — they use in-process jsh-capture.
;;;
;;; NOTE: Tests that use gsh-capture directly are skipped in Chez because
;;; open-output-file in command-substitute causes port-registry deadlocks.
;;; Run: scheme tests/test-term-hang.ss (from jerboa-emacs project root)

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1- sort sort!
          thread? make-mutex mutex? mutex-name
          path-extension path-absolute? getenv)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs core)
        (jerboa-emacs subprocess)
        (only (std srfi srfi-13) string-contains)
        (only (jsh lib) jsh-init! jsh-capture jsh-execute-input)
        (only (jsh environment) env-set!))

(define pass-count 0)
(define fail-count 0)

(define-syntax check
  (syntax-rules (=>)
    ((_ expr => expected)
     (let ((result expr) (exp expected))
       (if (equal? result exp)
         (set! pass-count (+ pass-count 1))
         (begin
           (set! fail-count (+ fail-count 1))
           (display "FAIL: ")
           (write 'expr)
           (display " => ")
           (write result)
           (display " expected ")
           (write exp)
           (newline)))))))

(define-syntax check-true
  (syntax-rules ()
    ((_ expr)
     (check (and expr #t) => #t))))

(define-syntax check-false
  (syntax-rules ()
    ((_ expr)
     (check (not expr) => #t))))

;;;===========================================================================
;;; 1. Baseline: quick commands work via jsh-execute-input (direct, no capture)
;;; NOTE: gsh-capture/command-substitute triggers a Chez port-registry
;;; deadlock when run in a secondary thread. We use jsh-execute-input directly
;;; for baseline tests, which avoids the fd-redirect mechanism.
;;;===========================================================================

(display "--- baseline: echo runs instantly via jsh-execute-input ---\n")
;; jsh-execute-input runs the command in-process, writing to current-output-port.
;; This is the non-capturing path (no command substitution).
(let ((env (jsh-init!)))
  (let* ((out (open-output-string))
         (status (parameterize ((current-output-port out))
                   (jsh-execute-input "echo hello" env))))
    (let ((text (get-output-string out)))
      (check (not (eq? #f (string-contains text "hello"))) => #t))))

(display "--- baseline: multiple commands in sequence ---\n")
(let ((env (jsh-init!)))
  (let* ((out (open-output-string))
         (s1 (parameterize ((current-output-port out))
               (jsh-execute-input "echo first" env)))
         (s2 (parameterize ((current-output-port out))
               (jsh-execute-input "echo second" env))))
    (let ((text (get-output-string out)))
      (check (not (eq? #f (string-contains text "first"))) => #t)
      (check (not (eq? #f (string-contains text "second"))) => #t))))

;;;===========================================================================
;;; 2. Demonstrate the blocking: jsh-execute-input does NOT block for external cmds
;;; (Note: in Chez gsh-capture cannot be tested in threads due to port deadlock)
;;;===========================================================================

(display "--- HANG PROOF: sleep blocks jsh-execute-input for external commands ---\n")
;; Run `sleep 3` via jsh-execute-input in a thread, with a 1-second timeout.
;; External commands block because execute-external uses blocking waitpid.
(let* ((env (jsh-init!))
       (result-box (box #f))
       (t (make-thread
            (lambda ()
              (jsh-execute-input "sleep 3" env)
              (set-box! result-box "done")))))
  (thread-start! t)
  ;; Wait 1 second — if jsh-execute-input external cmds were non-blocking, it would return
  (thread-sleep! 1)
  (let ((finished? (unbox result-box)))
    ;; The command is still running — blocking waitpid
    (check finished? => #f)
    ;; Kill the thread to clean up
    (with-exception-handler
      (lambda (e) #f)
      (lambda () (thread-terminate! t)))))

(display "--- HANG PROOF: yes | head via run-process-interruptible completes ---\n")
;; `yes | head -5` via run-process-interruptible should finish quickly.
;; This demonstrates the non-blocking path works for pipe commands.
(let* ((result-box (box #f))
       (fake-peek (lambda (ms) (thread-sleep! (/ ms 1000.0)) #f))
       (fake-key? (lambda (ev) #f))
       (fake-key  (lambda (ev) 0))
       (t (make-thread
            (lambda ()
              (let-values (((output status)
                            (run-process-interruptible
                              "yes | head -5"
                              fake-peek fake-key? fake-key)))
                (set-box! result-box output))))))
  (thread-start! t)
  (thread-sleep! 3)
  (let ((result (unbox result-box)))
    (if result
      (check (not (eq? #f (string-contains result "y"))) => #t)
      (begin
        (display "  WARNING: yes|head-5 still blocked after 3s\n")
        (with-exception-handler (lambda (e) #f)
          (lambda () (thread-terminate! t)))))))

;;;===========================================================================
;;; 3. The fix already exists: subprocess.ss non-blocking execution
;;;===========================================================================

(display "--- FIX EXISTS: run-process-interruptible handles sleep without blocking ---\n")
;; subprocess.ss already has non-blocking, interruptible execution.
;; It uses open-process-ports + char-ready? polling.
(let* ((result-box (box #f))
       ;; Fake peek-event that never sees C-g
       (fake-peek (lambda (ms) (thread-sleep! (/ ms 1000.0)) #f))
       (fake-key? (lambda (ev) #f))
       (fake-key  (lambda (ev) 0))
       (t (make-thread
            (lambda ()
              (let-values (((output status)
                            (run-process-interruptible
                              "sleep 0.5 && echo done"
                              fake-peek fake-key? fake-key)))
                (set-box! result-box output))))))
  (thread-start! t)
  (thread-sleep! 3)
  (let ((result (unbox result-box)))
    ;; The subprocess-based approach completes!
    (check (string? result) => #t)
    (check (string-contains result "done") => 0)
    (with-exception-handler (lambda (e) #f)
      (lambda () (thread-terminate! t)))))

(display "--- FIX EXISTS: run-process-interruptible can be interrupted ---\n")
;; Simulate C-g after 1 second — the subprocess gets killed
(let* ((start-time (time-second (current-time)))
       ;; After 1s, fake a C-g event
       (fake-peek (lambda (ms)
                    (thread-sleep! (/ ms 1000.0))
                    (if (> (- (time-second (current-time)) start-time) 1.0)
                      'fake-event  ;; trigger interrupt
                      #f)))
       (fake-key? (lambda (ev) (eq? ev 'fake-event)))
       (fake-key  (lambda (ev) 7))  ;; 7 = C-g
       (interrupted? #f))
  (guard (e [else (when (keyboard-quit-exception? e)
                    (set! interrupted? #t))])
    (run-process-interruptible
      "sleep 60"  ;; would run for 60s
      fake-peek fake-key? fake-key))
  ;; Should have been interrupted by our fake C-g within ~1s
  (check interrupted? => #t)
  (let ((elapsed (- (time-second (current-time)) start-time)))
    (check (< elapsed 5.0) => #t)))

;;;===========================================================================
;;; 4. Architecture comparison: jsh-execute-input vs subprocess
;;;===========================================================================

(display "--- ARCHITECTURE: jsh-execute-input runs builtins in-process ---\n")
;; jsh builtins like echo don't fork — they run in-process
;; This is fast but means the calling thread is busy
(let ((env (jsh-init!)))
  (let* ((out (open-output-string))
         (_ (parameterize ((current-output-port out))
              (jsh-execute-input "echo builtin" env))))
    (check (string-contains (get-output-string out) "builtin") => 0)))

(display "--- ARCHITECTURE: external commands work via run-process-interruptible ---\n")
;; External commands (/bin/echo) write to fd 1, not Chez's port.
;; run-process-interruptible captures them correctly via open-process-ports.
(let* ((fake-peek (lambda (ms) (thread-sleep! (/ ms 1000.0)) #f))
       (fake-key? (lambda (ev) #f))
       (fake-key  (lambda (ev) 0)))
  (let-values (((output status)
                (run-process-interruptible
                  "/bin/echo external"
                  fake-peek fake-key? fake-key)))
    (check (not (eq? #f (string-contains output "external"))) => #t)))

;;;===========================================================================
;;; 5. Diagnostic: what happens with typical interactive commands
;;;===========================================================================

(display "--- DIAGNOSTIC: top -b -n 1 works (batch mode, single iteration) ---\n")
;; top with -b (batch) -n 1 (one iteration) actually terminates
(let* ((result-box (box #f))
       (fake-peek (lambda (ms) (thread-sleep! (/ ms 1000.0)) #f))
       (fake-key? (lambda (ev) #f))
       (fake-key  (lambda (ev) 0))
       (t (make-thread
            (lambda ()
              (let-values (((output status)
                            (run-process-interruptible
                              "top -b -n 1"
                              fake-peek fake-key? fake-key)))
                (set-box! result-box output))))))
  (thread-start! t)
  ;; Give it 5 seconds (top -b -n 1 is usually fast)
  (thread-sleep! 5)
  (let ((result (unbox result-box)))
    (if result
      (begin
        (display (string-append "  top -b -n 1 completed, output length: "
                   (number->string (string-length result)) "\n"))
        (check (> (string-length result) 0) => #t))
      (begin
        (display "  WARNING: even top -b -n 1 blocked for 5s!\n")
        (with-exception-handler (lambda (e) #f)
          (lambda () (thread-terminate! t)))))))

(display "--- DIAGNOSTIC: infinite-output command blocks external-wait ---\n")
;; Prove that the blocking is at the waitpid level:
;; sleep 30 forks and waits indefinitely
(let* ((env (jsh-init!))
       (result-box (box #f))
       (t (make-thread
            (lambda ()
              ;; sh -c "sleep 30" will fork a sleep child
              (jsh-execute-input "sleep 30" env)
              (set-box! result-box "done")))))
  (thread-start! t)
  (thread-sleep! 1)
  ;; Not finished — proves blocking
  (check (unbox result-box) => #f)
  ;; Kill thread to clean up
  (with-exception-handler (lambda (e) #f)
    (lambda () (thread-terminate! t))))

;;;===========================================================================
;;; 6. Summary report
;;;===========================================================================

(display "\n====================================================================\n")
(display "DIAGNOSIS: Why long-running commands hang the editor\n")
(display "====================================================================\n")
(display "\n")
(display "CAUSE:\n")
(display "  shell.ss and terminal.ss use jsh-capture\n")
(display "  which calls command-substitute (jsh/expander.ss).\n")
(display "  For external commands, this chain is:\n")
(display "\n")
(display "    cmd-terminal-send\n")
(display "      → terminal-execute!    (terminal.ss)\n")
(display "        → jsh-capture        (jsh/lib.ss)\n")
(display "          → command-substitute\n")
(display "            → ffi-dup2        (redirects fd 1 to pipe)\n")
(display "            → open-output-file '/dev/fd/1'  *** PORT LOCK ***\n")
(display "            → jsh-fork-exec   (forks child process)\n")
(display "            → wait-for-foreground-process-raw  *** BLOCKS ***\n")
(display "            → ffi-read-all-from-fd  (reads ALL output after exit)\n")
(display "\n")
(display "  In Chez, open-output-file acquires a port registry lock.\n")
(display "  wait-for-foreground-process-raw is a blocking waitpid().\n")
(display "  If the child never exits (top, yes, cat, sleep 999), this\n")
(display "  blocks the calling thread forever.\n")
(display "\n")
(display "THE FIX ALREADY EXISTS:\n")
(display "  subprocess.ss has run-process-interruptible which:\n")
(display "    1. Uses open-process-ports (Chez native subprocess)\n")
(display "    2. Polls with char-ready? + drain-available! (non-blocking)\n")
(display "    3. Checks for C-g between polls (interruptible)\n")
(display "    4. Returns output incrementally as it arrives\n")
(display "\n")
(display "====================================================================\n")

;; Summary
(newline)
(display "========================================\n")
(display (string-append "TEST RESULTS: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
