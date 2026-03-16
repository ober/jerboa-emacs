#!chezscheme
;;; gsh-eshell.sls — Eshell with portable fallbacks
;;;
;;; Ported from gerbil-emacs/gsh-eshell.ss
;;; gsh dependencies are stubbed: commands run via /bin/sh -c through
;;; open-process-ports.  Each eshell buffer gets a simple env hash table.

(library (jerboa-emacs gsh-eshell)
  (export gsh-eshell-buffer?
          gsh-eshell-state
          gsh-eshell-prompt-string
          gsh-eshell-get-prompt
          gsh-eshell-init-buffer!
          gsh-eshell-process-input
          gsh-eshell-strip-ansi
          interactive-command?
          eshell-history-prev
          eshell-history-next
          eshell-history-reset!
          eshell-complete
          eshell-complete-files
          eshell-complete-commands
          eshell-longest-common-prefix)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std srfi srfi-13)
          (only (std misc string) string-split)
          (jerboa-emacs core)
          (jerboa-emacs shell-history))

  ;;;==========================================================================
  ;;; State management
  ;;;==========================================================================

  ;; Maps eshell buffers to their env hash-table
  (define *gsh-eshell-state* (make-hash-table-eq))
  (define (gsh-eshell-state) *gsh-eshell-state*)

  (define *gsh-eshell-prompt* "$ ")
  (define (gsh-eshell-prompt-string) *gsh-eshell-prompt*)

  (define (gsh-eshell-buffer? buf)
    "Check if this buffer is a gsh eshell buffer."
    (eq? (buffer-lexer-lang buf) 'eshell))

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

  ;;;==========================================================================
  ;;; Shell quoting and capture via /bin/sh -c
  ;;;==========================================================================

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

  (define (sh-capture cmd)
    "Run CMD via /bin/sh -c, capture stdout+stderr.
     Returns (values output-string exit-status)."
    (let-values (((to-stdin from-stdout from-stderr pid)
                  (open-process-ports
                    (string-append "/bin/sh -c " (shell-quote cmd))
                    'block
                    (native-transcoder))))
      (close-port to-stdin)
      (let ((stdout-str (get-string-all from-stdout))
            (stderr-str (get-string-all from-stderr)))
        (close-port from-stdout)
        (close-port from-stderr)
        (let ((out (if (eof-object? stdout-str) "" stdout-str))
              (err (if (eof-object? stderr-str) "" stderr-str)))
          (values (string-append out err) 0)))))

  ;;;==========================================================================
  ;;; Hostname helper
  ;;;==========================================================================

  (define (machine-name)
    "Return the hostname."
    (with-catch
      (lambda (e) "localhost")
      (lambda ()
        (let-values (((to-stdin from-stdout from-stderr pid)
                      (open-process-ports "hostname" 'line (native-transcoder))))
          (close-port to-stdin)
          (let ((name (get-line from-stdout)))
            (close-port from-stdout)
            (close-port from-stderr)
            (if (eof-object? name) "localhost" name))))))

  ;;;==========================================================================
  ;;; Buffer init and prompt
  ;;;==========================================================================

  (define (gsh-eshell-init-buffer! buf)
    "Initialize a simple env for an eshell buffer."
    (let ((env (stub-env-init!)))
      (hash-put! *gsh-eshell-state* buf env)
      ;; Update the global prompt
      (let ((user (or (env-get env "USER") "user"))
            (cwd  (or (env-get env "PWD") (current-directory))))
        (set! *gsh-eshell-prompt*
          (string-append user "@" (machine-name) ":" cwd "$ ")))
      env))

  (define (gsh-eshell-get-prompt buf)
    "Return the prompt for this eshell buffer."
    (let ((env (hash-get *gsh-eshell-state* buf)))
      (if env
        (let ((user (or (env-get env "USER") "user"))
              (cwd  (or (env-get env "PWD") (current-directory))))
          (string-append user "@" (machine-name) ":" cwd "$ "))
        "$ ")))

  ;;;==========================================================================
  ;;; ANSI stripping
  ;;;==========================================================================

  (define (gsh-eshell-strip-ansi str)
    "Remove ANSI escape sequences from a string."
    (let* ((len (string-length str))
           (esc (integer->char 27))
           (bel (integer->char 7)))
      (let loop ((i 0) (acc '()))
        (if (>= i len)
          (list->string (reverse acc))
          (let ((ch (string-ref str i)))
            (if (char=? ch esc)
              (if (< (+ i 1) len)
                (let ((next (string-ref str (+ i 1))))
                  (cond
                    ((char=? next #\[)
                     (let skip ((j (+ i 2)))
                       (if (>= j len) (loop j acc)
                         (let ((c (string-ref str j)))
                           (if (and (char>=? c #\@) (char<=? c #\~))
                             (loop (+ j 1) acc)
                             (skip (+ j 1)))))))
                    ((char=? next #\])
                     (let skip ((j (+ i 2)))
                       (if (>= j len) (loop j acc)
                         (if (char=? (string-ref str j) bel)
                           (loop (+ j 1) acc)
                           (skip (+ j 1))))))
                    ;; Character set designation
                    ((and (memv next '(#\( #\) #\* #\+))
                          (< (+ i 2) len))
                     (loop (+ i 3) acc))
                    (else (loop (+ i 2) acc))))
                (loop (+ i 1) acc))
              (if (or (char=? ch #\return)
                      (char=? ch (integer->char 1))   ; RL_PROMPT_START_IGNORE
                      (char=? ch (integer->char 2)))   ; RL_PROMPT_END_IGNORE
                (loop (+ i 1) acc)
                (loop (+ i 1) (cons ch acc)))))))))

  ;;;==========================================================================
  ;;; History navigation (up/down arrow in eshell)
  ;;;==========================================================================

  ;; Per-buffer history navigation index (-1 = not navigating)
  (define *eshell-history-index* (make-hash-table-eq))
  ;; Per-buffer saved input
  (define *eshell-saved-input* (make-hash-table-eq))

  (define (eshell-history-prev buf current-input)
    "Navigate to the previous (older) history entry.
     Returns the history command string, or #f if no more history."
    (let* ((idx (or (hash-get *eshell-history-index* buf) -1))
           (history (gsh-history))
           (hlen (length history))
           (new-idx (+ idx 1)))
      (if (>= new-idx hlen)
        #f
        (begin
          ;; Save the original input on first navigation
          (when (= idx -1)
            (hash-put! *eshell-saved-input* buf current-input))
          (hash-put! *eshell-history-index* buf new-idx)
          (caddr (list-ref history new-idx))))))

  (define (eshell-history-next buf)
    "Navigate to the next (newer) history entry.
     Returns the history command string, the saved input, or #f."
    (let* ((idx (or (hash-get *eshell-history-index* buf) -1)))
      (cond
        ;; Not navigating
        ((< idx 0) #f)
        ;; At newest entry — restore saved input
        ((= idx 0)
         (hash-put! *eshell-history-index* buf -1)
         (let ((saved (or (hash-get *eshell-saved-input* buf) "")))
           (hash-remove! *eshell-saved-input* buf)
           saved))
        ;; Move to newer entry
        (else
         (let ((new-idx (- idx 1)))
           (hash-put! *eshell-history-index* buf new-idx)
           (caddr (list-ref (gsh-history) new-idx)))))))

  (define (eshell-history-reset! buf)
    "Reset history navigation state."
    (hash-remove! *eshell-history-index* buf)
    (hash-remove! *eshell-saved-input* buf))

  ;;;==========================================================================
  ;;; Interactive command detection
  ;;;==========================================================================

  (define *interactive-commands*
    '("top" "htop" "btop" "vim" "vi" "nvim" "nano" "emacs" "less" "more"
      "man" "screen" "tmux" "ssh" "telnet" "ftp" "sftp" "python" "python3"
      "ipython" "node" "irb" "ghci" "gdb" "lldb" "mysql" "psql" "sqlite3"
      "mongosh" "redis-cli" "nmon" "atop" "iotop" "nethogs" "watch"
      "tail -f" "journalctl -f" "dmesg -w"))

  (define (interactive-command? input)
    "Check if input starts with a known interactive/full-screen program."
    (let ((first-word (let* ((s (string-trim input))
                             (sp (string-index s char-whitespace?)))
                        (if sp (substring s 0 sp) s))))
      (member first-word *interactive-commands*)))

  ;;;==========================================================================
  ;;; Input processing
  ;;;==========================================================================

  (define (gsh-eshell-process-input input buf)
    "Process an eshell input line via /bin/sh.
     Returns (values output new-cwd)."
    ;; Reset history navigation on input submission
    (eshell-history-reset! buf)
    (let ((env (hash-get *gsh-eshell-state* buf))
          (trimmed (safe-string-trim-both input)))
      (cond
        ;; No environment
        ((not env)
         (values "Error: no environment for this buffer\n"
                 (current-directory)))
        ;; Empty input
        ((string=? trimmed "")
         (values "" (or (env-get env "PWD") (current-directory))))
        ;; Clear command
        ((string=? trimmed "clear")
         (values 'clear (or (env-get env "PWD") (current-directory))))
        ;; Exit command
        ((string=? trimmed "exit")
         (values 'exit (or (env-get env "PWD") (current-directory))))
        ;; Block interactive programs
        ((interactive-command? trimmed)
         (values (string-append trimmed ": use M-x vterm for interactive programs\n")
                 (or (env-get env "PWD") (current-directory))))
        ;; Handle cd specially
        ((or (string=? trimmed "cd")
             (and (> (string-length trimmed) 3)
                  (string=? (substring trimmed 0 3) "cd ")))
         (eshell-handle-cd trimmed env))
        ;; Everything else goes through /bin/sh
        (else
         (eshell-execute-and-capture trimmed env)))))

  (define (eshell-handle-cd trimmed env)
    "Handle cd command by updating PWD in env."
    (let* ((arg (if (string=? trimmed "cd")
                  (or (env-get env "HOME") "/tmp")
                  (safe-string-trim-both
                    (substring trimmed 3 (string-length trimmed)))))
           (target (cond
                     ((string=? arg "~")
                      (or (env-get env "HOME") "/tmp"))
                     ((and (> (string-length arg) 0)
                           (char=? (string-ref arg 0) #\/))
                      arg)
                     (else
                      (let ((pwd (or (env-get env "PWD") (current-directory))))
                        (string-append pwd "/" arg))))))
      (with-catch
        (lambda (e)
          (values (string-append "cd: " arg ": No such directory\n")
                  (or (env-get env "PWD") (current-directory))))
        (lambda ()
          (current-directory target)
          (let ((real-dir (current-directory)))
            (env-set! env "PWD" real-dir)
            (values "" real-dir))))))

  (define (eshell-execute-and-capture input env)
    "Execute INPUT via /bin/sh, capturing stdout+stderr.
     Returns (values output-string cwd-string)."
    (env-inc-cmd-number! env)
    (with-catch
      (lambda (e)
        (values (string-append "shell: "
                  (call-with-string-output-port
                    (lambda (p) (display-condition e p)))
                  "\n")
                (or (env-get env "PWD") (current-directory))))
      (lambda ()
        (let-values (((output status) (sh-capture input)))
          (let ((display-output (if (and (string? output)
                                         (> (string-length output) 0))
                                  output
                                  "")))
            (values (gsh-eshell-strip-ansi display-output)
                    (or (env-get env "PWD") (current-directory))))))))

  ;;;==========================================================================
  ;;; Tab completion for eshell
  ;;;==========================================================================

  (define (eshell-complete input buf)
    "Complete the partial word at the end of INPUT.
     Returns a sorted list of completion strings, or '() if none."
    (let* ((env (hash-get *gsh-eshell-state* buf))
           (cwd (if env (or (env-get env "PWD") (current-directory))
                   (current-directory)))
           (trimmed (safe-string-trim-both input))
           (sp (let loop ((i (- (string-length trimmed) 1)))
                 (cond ((< i 0) #f)
                       ((char=? (string-ref trimmed i) #\space) i)
                       (else (loop (- i 1))))))
           (partial (if sp
                      (substring trimmed (+ sp 1) (string-length trimmed))
                      trimmed))
           (is-first-word (not sp)))
      (if (string=? partial "")
        '()
        (let* ((file-matches (eshell-complete-files partial cwd))
               (cmd-matches (if is-first-word
                              (eshell-complete-commands partial)
                              '()))
               (all (append cmd-matches file-matches))
               ;; Manual delete-duplicates
               (unique (let loop ((lst all) (seen '()) (acc '()))
                         (if (null? lst)
                           (reverse acc)
                           (if (member (car lst) seen)
                             (loop (cdr lst) seen acc)
                             (loop (cdr lst)
                                   (cons (car lst) seen)
                                   (cons (car lst) acc)))))))
          (list-sort string<? unique)))))

  (define (eshell-complete-files partial cwd)
    "Complete PARTIAL against files/dirs in CWD."
    (with-catch
      (lambda (e) '())
      (lambda ()
        (let* ((has-slash (string-index partial (lambda (c) (char=? c #\/))))
               (dir (if has-slash
                      (let ((d (string-append cwd "/"
                                 (substring partial 0 (+ has-slash 1)))))
                        d)
                      cwd))
               (prefix (if has-slash
                         (substring partial (+ has-slash 1) (string-length partial))
                         partial))
               (dir-prefix (if has-slash
                             (substring partial 0 (+ has-slash 1))
                             ""))
               (entries (with-catch (lambda (e) '())
                          (lambda () (directory-list dir))))
               (matches (filter (lambda (f)
                                  (and (string-prefix? prefix f)
                                       (not (string=? f "."))
                                       (not (string=? f ".."))))
                                entries)))
          (map (lambda (f)
                 (let* ((full (string-append dir "/" f))
                        (suffix (if (file-exists? full)
                                  (if (file-directory? full) "/" "")
                                  "")))
                   (string-append dir-prefix f suffix)))
               matches)))))

  (define (eshell-complete-commands partial)
    "Complete PARTIAL against executable commands in PATH."
    (with-catch
      (lambda (e) '())
      (lambda ()
        (let* ((path-str (or (getenv "PATH") "/usr/bin:/bin"))
               (path-dirs (string-split path-str #\:))
               (results '()))
          (for-each
            (lambda (dir)
              (with-catch
                (lambda (e) (void))
                (lambda ()
                  (let ((entries (directory-list dir)))
                    (for-each
                      (lambda (f)
                        (when (string-prefix? partial f)
                          (set! results (cons f results))))
                      entries)))))
            path-dirs)
          ;; Manual delete-duplicates
          (let loop ((lst results) (seen '()) (acc '()))
            (if (null? lst)
              (reverse acc)
              (if (member (car lst) seen)
                (loop (cdr lst) seen acc)
                (loop (cdr lst)
                      (cons (car lst) seen)
                      (cons (car lst) acc)))))))))

  (define (eshell-longest-common-prefix strings)
    "Return the longest common prefix of a list of strings."
    (if (or (null? strings) (null? (cdr strings)))
      (if (null? strings) "" (car strings))
      (let* ((first (car strings))
             (len (string-length first)))
        (let loop ((i 0))
          (if (>= i len)
            first
            (let ((ch (string-ref first i)))
              (if (let check ((rest (cdr strings)))
                    (or (null? rest)
                        (and (> (string-length (car rest)) i)
                             (char=? (string-ref (car rest) i) ch)
                             (check (cdr rest)))))
                (loop (+ i 1))
                (substring first 0 i))))))))

  ) ;; end library
