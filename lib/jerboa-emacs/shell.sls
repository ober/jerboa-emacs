#!chezscheme
;;; shell.sls — Shell mode with portable fallbacks
;;;
;;; Ported from gerbil-emacs/shell.ss
;;; gsh dependencies are stubbed: commands run via /bin/sh -c through
;;; open-process-ports.  The shell-environment is a simple hash table
;;; holding env vars and a command counter.

(library (jerboa-emacs shell)
  (export shell-buffer?
          shell-state?
          make-shell-state
          shell-state-env shell-state-env-set!
          shell-state-prompt-pos shell-state-prompt-pos-set!
          shell-state-pty-master shell-state-pty-master-set!
          shell-state-pty-pid shell-state-pty-pid-set!
          shell-state-pty-channel shell-state-pty-channel-set!
          shell-state-pty-thread shell-state-pty-thread-set!
          shell-state-vtscreen shell-state-vtscreen-set!
          shell-state-pre-pty-text shell-state-pre-pty-text-set!
          shell-state-table
          shell-start!
          shell-execute!
          shell-execute-async!
          shell-poll-output
          shell-pty-busy?
          shell-interrupt!
          shell-send-input!
          shell-cleanup-pty!
          shell-stop!
          shell-prompt
          strip-ansi-codes)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std srfi srfi-13)
          (std misc channel)
          (jerboa-emacs core)
          (jerboa-emacs pty)
          (jerboa-emacs vtscreen))

  ;;;==========================================================================
  ;;; Shell state
  ;;;==========================================================================

  (define (shell-buffer? buf)
    "Check if this buffer is a shell buffer."
    (eq? (buffer-lexer-lang buf) 'shell))

  ;; Maps shell buffers to their shell-state structs
  (define *shell-state* (make-hash-table-eq))
  (define (shell-state-table) *shell-state*)

  (defstruct shell-state
    (env          ; hash-table acting as simple env
     prompt-pos   ; integer: byte position where current input starts
     pty-master   ; PTY master fd (or #f)
     pty-pid      ; child process PID (or #f)
     pty-channel  ; channel for PTY output messages (or #f)
     pty-thread   ; reader thread (or #f)
     vtscreen     ; vtscreen struct or #f
     pre-pty-text)) ; text before PTY command started, or #f

  ;;;==========================================================================
  ;;; Stubbed gsh environment — simple hash-table env
  ;;;==========================================================================

  (define (stub-env-init!)
    "Create a simple env hash-table (replaces gsh-init!)."
    (let ((env (make-hash-table)))
      (hash-put! env "HOME" (or (getenv "HOME") "/tmp"))
      (hash-put! env "USER" (or (getenv "USER") "user"))
      (hash-put! env "PWD"  (current-directory))
      (hash-put! env "SHELL" "/bin/sh")
      (hash-put! env "PS1" "$ ")
      (hash-put! env "__cmd-number" 0)
      env))

  (define (env-set! env key val)
    (hash-put! env key val))

  (define (env-get env key)
    (hash-get env key))

  (define (env-inc-cmd-number! env)
    (let ((n (or (hash-get env "__cmd-number") 0)))
      (hash-put! env "__cmd-number" (+ n 1))))

  (define (env-cmd-number env)
    (or (hash-get env "__cmd-number") 0))

  (define (env-exported-alist env)
    "Return an alist of environment variables for subprocess spawn."
    (let ((result '()))
      (hash-for-each
        (lambda (k v)
          (when (and (string? k)
                     (not (string=? k "__cmd-number"))
                     (string? v))
            (set! result (cons (string-append k "=" v) result))))
        env)
      result))

  ;;;==========================================================================
  ;;; Stub: gsh-capture replacement via /bin/sh -c
  ;;;==========================================================================

  (define (sh-capture cmd)
    "Run CMD via /bin/sh -c, capture stdout+stderr.
     Returns (values output-string exit-status)."
    (let-values (((to-stdin from-stdout from-stderr pid)
                  (open-process-ports
                    (string-append "/bin/sh -c " (shell-quote cmd))
                    (buffer-mode block)
                    (native-transcoder))))
      (close-port to-stdin)
      (let ((stdout-str (get-string-all from-stdout))
            (stderr-str (get-string-all from-stderr)))
        (close-port from-stdout)
        (close-port from-stderr)
        (let ((out (if (eof-object? stdout-str) "" stdout-str))
              (err (if (eof-object? stderr-str) "" stderr-str)))
          (values (string-append out err) 0)))))

  (define (shell-quote str)
    "Quote a string for /bin/sh."
    (string-append "'"
      (let loop ((i 0) (acc '()))
        (if (>= i (string-length str))
          (list->string (reverse acc))
          (let ((ch (string-ref str i)))
            (if (char=? ch #\')
              (loop (+ i 1) (append (reverse (string->list "'\\''")) acc))
              (loop (+ i 1) (cons ch acc))))))
      "'"))

  ;;;==========================================================================
  ;;; ANSI escape code stripping
  ;;;==========================================================================

  (define (strip-ansi-codes str)
    "Remove ANSI escape sequences from a string."
    (let* ((len (string-length str))
           (esc (integer->char 27))
           (bel (integer->char 7)))
      (let loop ((i 0) (acc '()))
        (if (>= i len)
          (list->string (reverse acc))
          (let ((ch (string-ref str i)))
            (if (char=? ch esc)
              ;; Start of escape sequence
              (if (< (+ i 1) len)
                (let ((next (string-ref str (+ i 1))))
                  (cond
                    ;; CSI: ESC [ ... letter
                    ((char=? next #\[)
                     (let skip ((j (+ i 2)))
                       (if (>= j len) (loop j acc)
                         (let ((c (string-ref str j)))
                           (if (and (char>=? c #\@) (char<=? c #\~))
                             (loop (+ j 1) acc)
                             (skip (+ j 1)))))))
                    ;; OSC: ESC ] ... BEL
                    ((char=? next #\])
                     (let skip ((j (+ i 2)))
                       (if (>= j len) (loop j acc)
                         (if (char=? (string-ref str j) bel)
                           (loop (+ j 1) acc)
                           (skip (+ j 1))))))
                    ;; Character set designation: ESC ( X, ESC ) X, etc.
                    ((and (memv next '(#\( #\) #\* #\+))
                          (< (+ i 2) len))
                     (loop (+ i 3) acc))
                    ;; Other: ESC + single char
                    (else (loop (+ i 2) acc))))
                (loop (+ i 1) acc))
              ;; Regular character — keep it (but skip carriage returns)
              (if (or (char=? ch #\return)
                      (char=? ch (integer->char 1))   ; RL_PROMPT_START_IGNORE
                      (char=? ch (integer->char 2)))   ; RL_PROMPT_END_IGNORE
                (loop (+ i 1) acc)
                (loop (+ i 1) (cons ch acc)))))))))

  ;;;==========================================================================
  ;;; Shell lifecycle
  ;;;==========================================================================

  (define (shell-start!)
    "Create a shell state with a simple env (stubbed gsh-init!)."
    (let ((env (stub-env-init!)))
      (make-shell-state env 0 #f #f #f #f #f #f)))

  (define (shell-prompt ss)
    "Return the prompt string for this shell state."
    (let* ((env (shell-state-env ss))
           (ps1 (or (env-get env "PS1") "$ "))
           (user (or (env-get env "USER") "user"))
           (cwd  (or (env-get env "PWD") (current-directory))))
      ;; Simple prompt: no gsh expand-prompt, just show user@host:cwd$
      (strip-ansi-codes
        (string-append user "@" (machine-name) ":" cwd "$ "))))

  (define (machine-name)
    "Return the hostname."
    (with-catch
      (lambda (e) "localhost")
      (lambda ()
        (let-values (((to-stdin from-stdout from-stderr pid)
                      (open-process-ports "hostname" (buffer-mode line) (native-transcoder))))
          (close-port to-stdin)
          (let ((name (get-line from-stdout)))
            (close-port from-stdout)
            (close-port from-stderr)
            (if (eof-object? name) "localhost" name))))))

  (define (shell-execute! input ss)
    "Execute a command via /bin/sh, return (values output-string new-cwd).
     Output may be a string, 'clear, or 'exit."
    (let ((env (shell-state-env ss))
          (trimmed (safe-string-trim-both input)))
      (env-inc-cmd-number! env)
      (cond
        ((string=? trimmed "")
         (values "" (or (env-get env "PWD") (current-directory))))
        ((string=? trimmed "clear")
         (values 'clear (or (env-get env "PWD") (current-directory))))
        ((string=? trimmed "exit")
         (values 'exit (or (env-get env "PWD") (current-directory))))
        ;; Handle cd specially
        ((or (string=? trimmed "cd")
             (and (> (string-length trimmed) 3)
                  (string=? (substring trimmed 0 3) "cd ")))
         (let* ((arg (if (string=? trimmed "cd")
                       (or (env-get env "HOME") "/tmp")
                       (safe-string-trim-both (substring trimmed 3 (string-length trimmed)))))
                (target (if (and (> (string-length arg) 0)
                                (char=? (string-ref arg 0) #\/))
                          arg
                          (let ((pwd (or (env-get env "PWD") (current-directory))))
                            (string-append pwd "/" arg)))))
           (with-catch
             (lambda (e)
               (values (string-append "cd: " arg ": No such directory\n")
                       (or (env-get env "PWD") (current-directory))))
             (lambda ()
               (current-directory target)
               (let ((real-dir (current-directory)))
                 (env-set! env "PWD" real-dir)
                 (values "" real-dir))))))
        (else
         (with-catch
           (lambda (e)
             (values (string-append "shell: "
                       (call-with-string-output-port
                         (lambda (p) (display-condition e p)))
                       "\n")
                     (or (env-get env "PWD") (current-directory))))
           (lambda ()
             (let-values (((output status) (sh-capture trimmed)))
               (values output
                       (or (env-get env "PWD") (current-directory))))))))))

  ;;;==========================================================================
  ;;; Async PTY execution
  ;;;==========================================================================

  (define (shell-pure-simple-command? input)
    "Check if input is a simple command without shell metacharacters."
    (let ((len (string-length input)))
      (let loop ((i 0) (in-quote #f))
        (if (>= i len) #t
          (let ((ch (string-ref input i)))
            (cond
              ((and (not in-quote) (memv ch '(#\| #\; #\& #\`)))
               #f)
              ((char=? ch #\') (loop (+ i 1) (not in-quote)))
              (else (loop (+ i 1) in-quote))))))))

  (define (shell-extract-first-word input)
    "Extract the first command word, skipping leading VAR=val assignments."
    (let ((len (string-length input)))
      (let loop ((i 0))
        (if (>= i len) #f
          (let ((ch (string-ref input i)))
            (cond
              ((char-whitespace? ch) (loop (+ i 1)))
              ((not (char-whitespace? ch))
               (let end ((j i))
                 (if (or (>= j len) (char-whitespace? (string-ref input j)))
                   (let ((word (substring input i j)))
                     (if (string-index word (lambda (c) (char=? c #\=)))
                       (loop j)  ; skip VAR=val
                       word))
                   (end (+ j 1)))))
              (else (loop (+ i 1)))))))))

  (define (shell-pty-waitpid-status pid nohang?)
    "Wait for child and return just the exit status integer."
    (let-values (((status exited?) (pty-waitpid pid nohang?)))
      status))

  (define (shell-pty-reader-loop mfd pid ch)
    "Reader thread body: poll PTY output and post to channel."
    (with-catch
      (lambda (e)
        (jemacs-log! "Shell PTY reader error: "
          (call-with-string-output-port
            (lambda (p) (display-condition e p))))
        (channel-put ch (cons 'done -1)))
      (lambda ()
        (let loop ()
          (sleep (make-time 'time-duration 50000000 0)) ; 0.05s
          (let ((data (pty-read mfd)))
            (cond
              ((string? data)
               (channel-put ch (cons 'data data))
               (loop))
              ((eq? data 'eof)
               (let ((status (shell-pty-waitpid-status pid #f)))
                 (channel-put ch (cons 'done status))))
              (else
               (if (pty-child-alive? pid)
                 (loop)
                 (let drain ()
                   (let ((d (pty-read mfd)))
                     (cond
                       ((string? d)
                        (channel-put ch (cons 'data d))
                        (drain))
                       (else
                        (let ((status (shell-pty-waitpid-status pid #t)))
                          (channel-put ch (cons 'done status)))))))))))))))

  (define (shell-execute-async! input ss)
    "Execute command: external commands go through PTY subprocess (async).
     Returns:
     - (values 'sync output cwd) for simple commands
     - (values 'async #f #f) when command dispatched to PTY
     - (values 'special 'clear|'exit cwd) for clear/exit"
    (let ((env (shell-state-env ss))
          (trimmed (safe-string-trim-both input)))
      (env-inc-cmd-number! env)
      (cond
        ((string=? trimmed "")
         (values 'sync "" (or (env-get env "PWD") (current-directory))))
        ((string=? trimmed "clear")
         (values 'special 'clear (or (env-get env "PWD") (current-directory))))
        ((string=? trimmed "exit")
         (values 'special 'exit (or (env-get env "PWD") (current-directory))))
        (else
         ;; No builtin? stub — always try PTY first, fallback to sync
         (let* ((env-alist (env-exported-alist env))
                (rows 24) (cols 80))
           (let-values (((mfd pid) (with-catch
                                     (lambda (e)
                                       (jemacs-log! "PTY-SPAWN-ERROR: "
                                         (call-with-string-output-port
                                           (lambda (p) (display-condition e p))))
                                       (values #f #f))
                                     (lambda () (pty-spawn trimmed env-alist rows cols)))))
             (if (and mfd pid)
               (let ((ch (make-channel)))
                 (shell-state-pty-master-set! ss mfd)
                 (shell-state-pty-pid-set! ss pid)
                 (shell-state-pty-channel-set! ss ch)
                 ;; Create VT100 screen buffer
                 (shell-state-vtscreen-set! ss (new-vtscreen rows cols))
                 (let ((thread (fork-thread
                                 (lambda () (shell-pty-reader-loop mfd pid ch)))))
                   (shell-state-pty-thread-set! ss thread)
                   (values 'async #f #f)))
               ;; forkpty failed, fall back to sync
               (let-values (((output cwd) (shell-execute! input ss)))
                 (values 'sync output cwd)))))))))

  (define (shell-poll-output ss)
    "Non-blocking check for PTY output. Returns:
     - (cons 'data string) — output chunk
     - (cons 'done exit-status) — child exited
     - #f — nothing available"
    (let ((ch (shell-state-pty-channel ss)))
      (if ch
        (let-values (((val ok) (channel-try-get ch)))
          (if ok val #f))
        #f)))

  (define (shell-pty-busy? ss)
    "Check if a PTY command is currently running."
    (and (shell-state-pty-pid ss) #t))

  (define (shell-interrupt! ss)
    "Send SIGINT to the PTY child process group."
    (let ((pid (shell-state-pty-pid ss)))
      (when pid
        (pty-kill! pid 2))))

  (define (shell-send-input! ss str)
    "Send string to the PTY child's stdin."
    (let ((mfd (shell-state-pty-master ss)))
      (when mfd
        (pty-write mfd str))))

  (define (shell-cleanup-pty! ss)
    "Clean up PTY state after command finishes or on stop."
    (let ((mfd (shell-state-pty-master ss))
          (pid (shell-state-pty-pid ss)))
      (when mfd
        (pty-close! mfd pid))
      (shell-state-pty-master-set! ss #f)
      (shell-state-pty-pid-set! ss #f)
      (shell-state-pty-channel-set! ss #f)
      (shell-state-pty-thread-set! ss #f)
      (shell-state-vtscreen-set! ss #f)
      (shell-state-pre-pty-text-set! ss #f)))

  (define (shell-stop! ss)
    "Clean up the shell state."
    (shell-cleanup-pty! ss))

  ) ;; end library
