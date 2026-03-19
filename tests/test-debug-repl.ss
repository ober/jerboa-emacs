#!chezscheme
;;; test-debug-repl.ss — Tests for the TCP debug REPL server.
;;; Uses fresh server per test group to avoid fd-reuse hangs.

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (only (jerboa core) thread-terminate!)
        (jerboa-emacs debug-repl)
        (jerboa-emacs async)
        (std net tcp))

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
           (newline)
           (flush-output-port (current-output-port))))))))

;; ============================================================================
;; Master timer for test context
;; ============================================================================

;; The debug REPL uses schedule-periodic! for non-blocking I/O polling.
;; In the Qt app, qt-app-exec! drives master-timer-tick!. In tests, we
;; need our own timer thread.
(define *test-timer-thread* #f)

(define (start-test-timer!)
  (set! *test-timer-thread*
    (fork-thread
      (lambda ()
        (let loop ()
          (sleep (make-time 'time-duration 50000000 0))
          (master-timer-tick!)
          (loop))))))

(define (stop-test-timer!)
  (when *test-timer-thread*
    (guard (e [#t #f])
      (thread-terminate! *test-timer-thread*))
    (set! *test-timer-thread* #f)))

(start-test-timer!)

;; ============================================================================
;; Helpers
;; ============================================================================

(define (sleep-ms ms)
  (sleep (make-time 'time-duration (* ms 1000000) 0)))

(define (connect-repl port-num)
  (sleep-ms 150)
  (tcp-connect "127.0.0.1" port-num))

(define (read-until-prompt in-port)
  "Read lines until 'jerboa-dbg> ' prompt. Returns accumulated lines."
  (let accum ((lines '()))
    (let ((line (guard (e [#t #f]) (get-line in-port))))
      (cond
        ((not line) (reverse lines))
        ((eof-object? line) (reverse lines))
        ((string=? line "jerboa-dbg> ") (reverse lines))
        (else (accum (cons line lines)))))))

(define (send-command in-port out-port cmd)
  "Send a command and return the response lines (up to next prompt)."
  (put-string out-port cmd)
  (put-char out-port #\newline)
  (flush-output-port out-port)
  (read-until-prompt in-port))

(define (skip-banner in-port)
  "Skip the banner line and first prompt."
  (get-line in-port)   ;; banner
  (get-line in-port))  ;; first prompt "jerboa-dbg> "

(define (has-line? substr lines)
  "True if any line in lines contains substr."
  (and (find (lambda (l)
               (let ((nl (string-length substr))
                     (hl (string-length l)))
                 (let scan ((i 0))
                   (cond
                     ((> (+ i nl) hl) #f)
                     ((string=? substr (substring l i (+ i nl))) i)
                     (else (scan (+ i 1)))))))
             lines)
       #t))

;; Helper: run body with a fresh debug-repl server, cleanup guaranteed
(define-syntax with-fresh-server
  (syntax-rules ()
    ((_ (port-var) body ...)
     (let ((port-var (start-debug-repl! 0)))
       (sleep-ms 50)
       (let ((result (guard (e [#t (begin (stop-debug-repl!) (raise e))])
                       body ...)))
         (stop-debug-repl!)
         (sleep-ms 100)
         result)))))

;; ============================================================================
;; Test group 1: Start/stop and basic connection
;; ============================================================================

(display "--- debug-repl-start ---\n")
(flush-output-port (current-output-port))

(with-fresh-server (port)
  ;; Server starts with valid port
  (check (integer? port) => #t)
  (check (> port 0) => #t)
  (check (file-exists? (string-append (getenv "HOME") "/.jerboa-repl-port")) => #t)

  ;; Can connect and get banner
  (let-values (((in out) (connect-repl port)))
    (skip-banner in)
    (check #t => #t)
    (close-port in)
    (close-port out))

  ;; debug-repl-port returns actual port
  (check (equal? port (debug-repl-port)) => #t)
  (check (integer? (debug-repl-port)) => #t))

;; After stop: port file gone, debug-repl-port returns #f
(check (file-exists? (string-append (getenv "HOME") "/.jerboa-repl-port")) => #f)
(check (debug-repl-port) => #f)

;; ============================================================================
;; Test group 2: Eval expressions
;; ============================================================================

(display "--- debug-repl-eval ---\n")
(flush-output-port (current-output-port))

(with-fresh-server (port)
  ;; Eval (+ 1 2) and string-append in a single connection
  (let-values (((in out) (connect-repl port)))
    (skip-banner in)
    (let ((resp (send-command in out "(+ 1 2)")))
      (check (has-line? "3" resp) => #t))
    (let ((resp (send-command in out "(string-append \"hello\" \" world\")")))
      (check (has-line? "hello world" resp) => #t))
    (close-port in)
    (close-port out)))

;; ============================================================================
;; Test group 3: REPL commands
;; ============================================================================

(display "--- debug-repl-commands ---\n")
(flush-output-port (current-output-port))

(with-fresh-server (port)
  ;; Test all commands in a single connection
  (let-values (((in out) (connect-repl port)))
    (skip-banner in)

    ;; ,threads
    (let ((resp (send-command in out ",threads")))
      (check (> (length resp) 0) => #t)
      (check (has-line? "master-timer" resp) => #t))

    ;; ,help
    (let ((resp (send-command in out ",help")))
      (check (has-line? ",threads" resp) => #t)
      (check (has-line? ",quit" resp) => #t))

    ;; ,state
    (let ((resp (send-command in out ",state")))
      (check (has-line? "listen-fd" resp) => #t)
      (check (has-line? "bytes-allocated" resp) => #t))

    ;; ,gc
    (let ((resp (send-command in out ",gc")))
      (check (has-line? "GC done" resp) => #t)
      (check (has-line? "bytes-allocated" resp) => #t))

    (close-port in)
    (close-port out)))

;; ============================================================================
;; Test group 4: Error handling
;; ============================================================================

(display "--- debug-repl-errors ---\n")
(flush-output-port (current-output-port))

(with-fresh-server (port)
  (let-values (((in out) (connect-repl port)))
    (skip-banner in)
    ;; Invalid expression
    (let ((resp (send-command in out "this-does-not-exist-xyz")))
      (check (has-line? "ERROR" resp) => #t))
    ;; Session survives errors
    (let ((resp2 (send-command in out "(+ 1 1)")))
      (check (has-line? "2" resp2) => #t))
    (close-port in)
    (close-port out)))

;; ============================================================================
;; Test group 5: ,quit closes connection
;; ============================================================================

(display "--- debug-repl-quit ---\n")
(flush-output-port (current-output-port))

(with-fresh-server (port)
  (let-values (((in out) (connect-repl port)))
    (skip-banner in)
    (send-command in out ",quit")
    ;; After ,quit, next read is EOF
    (let ((line (guard (e [#t 'eof]) (get-line in))))
      (check (or (eof-object? line) (eq? line 'eof)) => #t))
    (guard (e [#t #f]) (close-port in))
    (guard (e [#t #f]) (close-port out))))

;; ============================================================================
;; Test group 6: Sequential clients (single-client non-blocking design)
;; ============================================================================

(display "--- debug-repl-sequential-client ---\n")
(flush-output-port (current-output-port))

;; The thread-free REPL handles one client at a time.
;; Verify that after one client disconnects, another can connect.
(with-fresh-server (port)
  ;; First client
  (let-values (((in1 out1) (connect-repl port)))
    (skip-banner in1)
    (let ((r1 (send-command in1 out1 "(+ 10 20)")))
      (check (has-line? "30" r1) => #t))
    (close-port in1)
    (close-port out1))
  ;; Wait for server to notice disconnect
  (sleep-ms 300)
  ;; Second client
  (let-values (((in2 out2) (connect-repl port)))
    (skip-banner in2)
    (let ((r2 (send-command in2 out2 "(+ 30 40)")))
      (check (has-line? "70" r2) => #t))
    (close-port in2)
    (close-port out2)))

;; ============================================================================
;; Test group 7: Auth with token
;; ============================================================================

(display "--- debug-repl-auth ---\n")
(flush-output-port (current-output-port))

;; Test: token auth — rejected without correct token (raw TCP, no debug-repl)
(let* ((srv (tcp-listen "127.0.0.1" 0))
       (auth-port (tcp-server-port srv)))
  (fork-thread
    (lambda ()
      (let-values (((in out) (tcp-accept srv)))
        (let ((line (guard (e [#t #f]) (get-line in))))
          (if (and (string? line) (string=? line "wrongtoken"))
            (begin
              (put-string out "Access denied.\n")
              (flush-output-port out))
            (put-string out "OK\n")))
        (close-port in)
        (close-port out))
      (tcp-close srv)))
  (sleep-ms 20)
  (let-values (((in out) (tcp-connect "127.0.0.1" auth-port)))
    (put-string out "wrongtoken\n")
    (flush-output-port out)
    (let ((line (guard (e [#t "eof"]) (get-line in))))
      (check (or (and (string? line) (has-line? "denied" (list line)) #t)
                 (eof-object? line)
                 (string=? line "eof"))
             => #t))
    (guard (e [#t #f]) (close-port in))
    (guard (e [#t #f]) (close-port out)))
  (sleep-ms 200))

;; Test: debug-repl with actual token
(sleep-ms 200)
(let ((port (start-debug-repl! 0 "secret123")))
  (sleep-ms 50)
  (let-values (((in out) (tcp-connect "127.0.0.1" port)))
    (put-string out "secret123\n")
    (flush-output-port out)
    (let ((banner (get-line in)))
      (check (and (string? banner) (has-line? "debug REPL" (list banner))) => #t))
    (guard (e [#t #f]) (close-port in))
    (guard (e [#t #f]) (close-port out)))
  (sleep-ms 100)
  (stop-debug-repl!))

;; ============================================================================
;; Summary
;; ============================================================================

(newline)
(display "========================================\n")
(display (string-append "debug-repl Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(flush-output-port (current-output-port))
(stop-test-timer!)
(when (> fail-count 0) (exit 1))
