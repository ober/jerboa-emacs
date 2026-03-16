#!chezscheme
;;; eshell.sls — Eshell: Scheme-powered shell with built-in commands
;;;
;;; Ported from gerbil-emacs/eshell.ss
;;; Features:
;;; - Built-in commands implemented in Scheme (cd, ls, pwd, cat, echo, etc.)
;;; - Pipeline support (cmd1 | cmd2 | cmd3)
;;; - Scheme expression evaluation (lines starting with '(')
;;; - External command execution for anything not built-in

(library (jerboa-emacs eshell)
  (export eshell-buffer?
          eshell-state
          eshell-prompt
          eshell-process-input
          eshell-format-ls)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-directory path-strip-directory)
          (only (std srfi srfi-13) string-join string-contains string-prefix? string-suffix? string-index string-trim string-trim-both)
          (jerboa-emacs pregexp-compat)
          (jerboa-emacs core))

  ;;;==========================================================================
  ;;; Eshell state
  ;;;==========================================================================

  (define (eshell-buffer? buf)
    "Check if this buffer is an eshell buffer."
    (eq? (buffer-lexer-lang buf) 'eshell))

  ;; Maps eshell buffers to their state (current directory, history, etc.)
  ;; Use eq? table: buffer structs are mutable
  (define *eshell-state* (make-hash-table-eq))

  ;; Accessor function since we can't export a mutable variable directly
  (define (eshell-state) *eshell-state*)

  (define *eshell-prompt* "eshell> ")
  (define (eshell-prompt) *eshell-prompt*)

  ;;;==========================================================================
  ;;; Built-in commands
  ;;;==========================================================================

  (define *eshell-builtins* (make-hash-table))

  (define (register-builtin! name proc)
    (hash-put! *eshell-builtins* name proc))

  (define (builtin? name)
    (hash-get *eshell-builtins* name))

  ;;;==========================================================================
  ;;; Helpers (must be defined before builtin registrations that use them)
  ;;;==========================================================================

  (define (mode->permission-string mode)
    (let ((p (bitwise-and mode #o777)))
      (string
        (if (not (zero? (bitwise-and p #o400))) #\r #\-)
        (if (not (zero? (bitwise-and p #o200))) #\w #\-)
        (if (not (zero? (bitwise-and p #o100))) #\x #\-)
        (if (not (zero? (bitwise-and p #o040))) #\r #\-)
        (if (not (zero? (bitwise-and p #o020))) #\w #\-)
        (if (not (zero? (bitwise-and p #o010))) #\x #\-)
        (if (not (zero? (bitwise-and p #o004))) #\r #\-)
        (if (not (zero? (bitwise-and p #o002))) #\w #\-)
        (if (not (zero? (bitwise-and p #o001))) #\x #\-))))

  (define (glob->regex pattern)
    "Convert a simple glob pattern (with * and ?) to a regex."
    (let loop ((chars (string->list pattern)) (acc "^"))
      (if (null? chars)
        (string-append acc "$")
        (let ((ch (car chars)))
          (cond
            ((char=? ch #\*) (loop (cdr chars) (string-append acc ".*")))
            ((char=? ch #\?) (loop (cdr chars) (string-append acc ".")))
            ((char=? ch #\.) (loop (cdr chars) (string-append acc "\\.")))
            (else (loop (cdr chars) (string-append acc (string ch)))))))))

  (define (walk-dir! dir proc)
    "Recursively walk dir, calling (proc full-path) for each entry."
    (for-each
      (lambda (name)
        (unless (member name '("." ".."))
          (let ((full (string-append dir "/" name)))
            (guard (e [#t (void)])  ; skip unreadable entries
              (proc full)
              (when (file-directory? full)
                (walk-dir! full proc))))))
      (directory-list dir)))

  (define (resolve-path file cwd)
    "Resolve a possibly-relative path against cwd."
    (if (string-prefix? "/" file)
      file
      (string-append cwd "/" file)))

  (define (read-file-contents path)
    "Read entire file contents as a string."
    (call-with-input-file path
      (lambda (port) (get-string-all port))))

  (define (exception->string e)
    "Convert an exception to a display string."
    (call-with-string-output-port
      (lambda (p) (display-condition e p))))

  (define (dot-file? name)
    "Check if a filename starts with a dot."
    (and (> (string-length name) 0)
         (char=? (string-ref name 0) #\.)))

  (define (directory-entries dir show-all?)
    "List directory entries, optionally filtering out dot files.
     Always filters . and .. even when show-all? is #t."
    (let ((entries (directory-list dir)))
      (if show-all?
        (filter (lambda (name) (not (member name '("." "..")))) entries)
        (filter (lambda (name) (not (dot-file? name))) entries))))

  (define (copy-file-simple src dst)
    "Copy a file from src to dst by reading and writing bytes."
    (let ((data (call-with-port (open-file-input-port src) get-bytevector-all)))
      (call-with-port (open-file-output-port dst
                        (file-options no-fail)
                        (buffer-mode block))
        (lambda (out) (put-bytevector out data)))))

  (define (run-external-command cmd-string cwd)
    "Run an external command string and return its stdout as a string.
     Returns the output string or empty string on failure."
    (guard (e [#t ""])
      (let-values (((to-stdin from-stdout from-stderr proc-id)
                    (open-process-ports
                      (string-append "cd " cwd " && " cmd-string)
                      (buffer-mode block)
                      (native-transcoder))))
        (close-port to-stdin)
        (let ((output (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (if (eof-object? output) "" output)))))

  (define (run-external-command-with-stdin cmd-string cwd stdin-text)
    "Run an external command with stdin input and return stdout."
    (guard (e [#t ""])
      (let-values (((to-stdin from-stdout from-stderr proc-id)
                    (open-process-ports
                      (string-append "cd " cwd " && " cmd-string)
                      (buffer-mode block)
                      (native-transcoder))))
        (put-string to-stdin stdin-text)
        (flush-output-port to-stdin)
        (close-port to-stdin)
        (let ((output (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (if (eof-object? output) "" output)))))

  ;;;==========================================================================
  ;;; ls formatting
  ;;;==========================================================================

  (define (eshell-format-ls dir show-long? show-all?)
    "Format ls output."
    (let* ((entries (directory-entries dir show-all?))
           (sorted (list-sort string<? entries)))
      (if show-long?
        ;; Long format
        (string-append
          (string-join
            (map (lambda (name)
                   (let ((full (string-append dir "/" name)))
                     (guard (e [#t (string-append "?????????? " name)])
                       (let* ((is-dir (file-directory? full))
                              (type-char (if is-dir #\d #\-))
                              (size-str "?"))
                         (string-append
                           (string type-char)
                           "rwxr-xr-x"  ; simplified permissions
                           " " size-str
                           "\t" name
                           (if is-dir "/" ""))))))
                 sorted)
            "\n")
          "\n")
        ;; Short format: names separated by spaces
        (string-append (string-join sorted "  ") "\n"))))

  ;;;==========================================================================
  ;;; Command line parsing
  ;;;==========================================================================

  (define (parse-command-line line)
    "Parse a command line into a list of tokens.
     Simple splitting on whitespace, respecting double quotes."
    (let loop ((chars (string->list line))
               (current "")
               (tokens '())
               (in-quote? #f))
      (cond
        ((null? chars)
         (reverse (if (string=? current "") tokens
                    (cons current tokens))))
        ((and (char=? (car chars) #\") (not in-quote?))
         (loop (cdr chars) current tokens #t))
        ((and (char=? (car chars) #\") in-quote?)
         (loop (cdr chars) current tokens #f))
        ((and (char-whitespace? (car chars)) (not in-quote?))
         (if (string=? current "")
           (loop (cdr chars) "" tokens #f)
           (loop (cdr chars) "" (cons current tokens) #f)))
        (else
         (loop (cdr chars) (string-append current (string (car chars)))
               tokens in-quote?)))))

  ;;;==========================================================================
  ;;; Environment and glob expansion
  ;;;==========================================================================

  (define (eshell-expand-env-vars str)
    "Expand $VAR and ${VAR} in a string."
    (let loop ((chars (string->list str)) (acc ""))
      (cond
        ((null? chars) acc)
        ((and (char=? (car chars) #\$)
              (pair? (cdr chars))
              (char=? (cadr chars) #\{))
         ;; ${VAR} form
         (let brace-loop ((rest (cddr chars)) (name ""))
           (cond
             ((null? rest) (loop rest (string-append acc "${" name)))
             ((char=? (car rest) #\})
              (let ((val (or (getenv name) "")))
                (loop (cdr rest) (string-append acc val))))
             (else (brace-loop (cdr rest) (string-append name (string (car rest))))))))
        ((and (char=? (car chars) #\$)
              (pair? (cdr chars))
              (or (char-alphabetic? (cadr chars)) (char=? (cadr chars) #\_)))
         ;; $VAR form
         (let var-loop ((rest (cdr chars)) (name ""))
           (if (and (pair? rest)
                    (let ((c (car rest)))
                      (or (char-alphabetic? c) (char-numeric? c) (char=? c #\_))))
             (var-loop (cdr rest) (string-append name (string (car rest))))
             (let ((val (or (getenv name) "")))
               (loop rest (string-append acc val))))))
        (else (loop (cdr chars) (string-append acc (string (car chars))))))))

  (define (eshell-expand-glob token cwd)
    "Expand a glob token. Returns list of matching filenames, or (list token) if no glob chars."
    (if (or (string-contains token "*") (string-contains token "?"))
      (let* ((rx-str (glob->regex token))
             (rx (guard (e [#t #f]) (pregexp rx-str))))
        (if (not rx)
          (list token)
          (let* ((entries (guard (e [#t '()])
                            (directory-entries cwd #f)))
                 (matches (filter (lambda (name) (pregexp-match rx name)) entries)))
            (if (null? matches) (list token)
              (list-sort string<? matches)))))
      (list token)))

  (define (eshell-expand-tokens tokens cwd)
    "Expand environment variables and globs in tokens."
    (let loop ((toks tokens) (acc '()))
      (if (null? toks) (reverse acc)
        (let* ((expanded (eshell-expand-env-vars (car toks)))
               (globbed (eshell-expand-glob expanded cwd)))
          (loop (cdr toks) (append (reverse globbed) acc))))))

  ;;;==========================================================================
  ;;; Redirection parsing
  ;;;==========================================================================

  (define (eshell-parse-redirection tokens)
    "Parse I/O redirection from tokens.
     Returns (values clean-tokens redirect-file append? input-file)."
    (let loop ((toks tokens) (acc '()) (redir #f) (append? #f) (input #f))
      (cond
        ((null? toks)
         (values (reverse acc) redir append? input))
        ((string=? (car toks) ">>")
         (if (pair? (cdr toks))
           (loop (cddr toks) acc (cadr toks) #t input)
           (loop (cdr toks) acc redir append? input)))
        ((string=? (car toks) ">")
         (if (pair? (cdr toks))
           (loop (cddr toks) acc (cadr toks) #f input)
           (loop (cdr toks) acc redir append? input)))
        ((string=? (car toks) "<")
         (if (pair? (cdr toks))
           (loop (cddr toks) acc redir append? (cadr toks))
           (loop (cdr toks) acc redir append? input)))
        ;; Handle >file (no space)
        ((and (> (string-length (car toks)) 1)
              (char=? (string-ref (car toks) 0) #\>))
         (let* ((tok (car toks))
                (is-append (and (> (string-length tok) 1)
                                (char=? (string-ref tok 1) #\>)))
                (file (substring tok (if is-append 2 1) (string-length tok))))
           (if (string=? file "")
             (if (pair? (cdr toks))
               (loop (cddr toks) acc (cadr toks) is-append input)
               (loop (cdr toks) acc redir is-append input))
             (loop (cdr toks) acc file is-append input))))
        ;; Handle <file (no space)
        ((and (> (string-length (car toks)) 1)
              (char=? (string-ref (car toks) 0) #\<))
         (let ((file (substring (car toks) 1 (string-length (car toks)))))
           (loop (cdr toks) acc redir append? file)))
        (else (loop (cdr toks) (cons (car toks) acc) redir append? input)))))

  ;;;==========================================================================
  ;;; Command substitution
  ;;;==========================================================================

  (define (eshell-expand-command-substitution line cwd)
    "Expand $(cmd) in a command line by executing cmd and inserting output."
    (let loop ((chars (string->list line)) (acc ""))
      (cond
        ((null? chars) acc)
        ((and (char=? (car chars) #\$)
              (pair? (cdr chars))
              (char=? (cadr chars) #\())
         ;; Find matching closing paren
         (let paren-loop ((rest (cddr chars)) (depth 1) (cmd ""))
           (cond
             ((null? rest) (string-append acc "$(" cmd))
             ((char=? (car rest) #\()
              (paren-loop (cdr rest) (+ depth 1) (string-append cmd "(")))
             ((and (char=? (car rest) #\)) (= depth 1))
              ;; Execute the command and get output
              (let-values (((output _) (eshell-execute-command cmd cwd)))
                (let ((trimmed-output
                       (if (and (string? output)
                                (> (string-length output) 0)
                                (char=? (string-ref output (- (string-length output) 1))
                                        #\newline))
                         (substring output 0 (- (string-length output) 1))
                         (if (string? output) output ""))))
                  (loop (cdr rest) (string-append acc trimmed-output)))))
             ((char=? (car rest) #\))
              (paren-loop (cdr rest) (- depth 1) (string-append cmd ")")))
             (else (paren-loop (cdr rest) depth (string-append cmd (string (car rest))))))))
        (else (loop (cdr chars) (string-append acc (string (car chars))))))))

  ;;;==========================================================================
  ;;; Expression evaluation
  ;;;==========================================================================

  (define (eshell-eval-expression expr cwd)
    "Evaluate a Scheme expression and return the result."
    (guard (e [#t
               (values (string-append "Error: "
                         (exception->string e)
                         "\n")
                       cwd)])
      (let* ((sexp (let ((p (open-input-string expr))) (read p)))
             (result (eval sexp))
             (output (call-with-string-output-port
                       (lambda (p) (write result p)))))
        (values (string-append output "\n") cwd))))

  ;;;==========================================================================
  ;;; External command execution
  ;;;==========================================================================

  (define (eshell-run-external cmd args cwd)
    "Run an external command."
    (guard (e [#t
               (values (string-append cmd ": "
                         (exception->string e)
                         "\n")
                       cwd)])
      (let* ((cmd-string (string-join (cons cmd args) " "))
             (output (run-external-command cmd-string cwd)))
        (values output cwd))))

  (define (eshell-run-external-with-stdin cmd args cwd stdin-text)
    "Run an external command with stdin input."
    (guard (e [#t
               (values (string-append cmd ": "
                         (exception->string e)
                         "\n")
                       cwd)])
      (let* ((cmd-string (string-join (cons cmd args) " "))
             (output (run-external-command-with-stdin cmd-string cwd stdin-text)))
        (values output cwd))))

  ;;;==========================================================================
  ;;; Command execution with redirection
  ;;;==========================================================================

  (define (eshell-execute-command line cwd)
    "Execute a single command (builtin or external) with expansion."
    (let* ((tokens (parse-command-line line))
           (expanded (eshell-expand-tokens tokens cwd))
           (cmd (if (null? expanded) "" (car expanded)))
           (args (if (null? expanded) '() (cdr expanded)))
           (builtin (builtin? cmd)))
      (if builtin
        (guard (e [#t
                   (values (string-append cmd ": "
                             (exception->string e)
                             "\n")
                           cwd)])
          (builtin args cwd))
        ;; External command
        (eshell-run-external cmd args cwd))))

  (define (eshell-execute-command-with-redirect line cwd)
    "Execute a command with env/glob expansion, input and output redirection."
    (let* ((tokens (parse-command-line line))
           (expanded (eshell-expand-tokens tokens cwd)))
      (let-values (((clean-tokens redir-file append? input-file)
                    (eshell-parse-redirection expanded)))
        (let* ((cmd (if (null? clean-tokens) "" (car clean-tokens)))
               (args (if (null? clean-tokens) '() (cdr clean-tokens)))
               (builtin (builtin? cmd))
               ;; If input redirection, read the file
               (stdin-text (and input-file
                             (let ((path (resolve-path input-file cwd)))
                               (if (file-exists? path)
                                 (read-file-contents path)
                                 #f)))))
          (if (and input-file (not stdin-text))
            (values (string-append "No such file: " input-file "\n") cwd)
            (let-values (((output new-cwd)
                          (if builtin
                            (guard (e [#t
                                       (values (string-append cmd ": "
                                                 (exception->string e)
                                                 "\n")
                                               cwd)])
                              (builtin args cwd))
                            ;; External command — pass stdin if input redirection
                            (if stdin-text
                              (eshell-run-external-with-stdin cmd args cwd stdin-text)
                              (eshell-run-external cmd args cwd)))))
              (if (and redir-file (string? output))
                ;; Write output to file
                (let ((path (resolve-path redir-file cwd)))
                  (guard (e [#t
                             (values (string-append "redirect error: "
                                       (exception->string e)
                                       "\n")
                                     new-cwd)])
                    (if append?
                      (let ((p (open-file-output-port path
                                 (file-options no-fail no-truncate)
                                 (buffer-mode block)
                                 (native-transcoder))))
                        (set-port-position! p (port-length p))
                        (put-string p output)
                        (close-port p))
                      (call-with-output-file path
                        (lambda (port) (display output port))))
                    (values "" new-cwd)))
                (values output new-cwd))))))))

  ;;;==========================================================================
  ;;; Pipeline processing
  ;;;==========================================================================

  (define (eshell-process-pipeline line cwd)
    "Process a pipeline: cmd1 | cmd2 | cmd3."
    (let* ((segments (map (lambda (s) (safe-string-trim-both s))
                          (pregexp-split "\\|" line)))
           ;; Execute first command
           (first-output
             (let-values (((out new-cwd) (eshell-execute-command (car segments) cwd)))
               (if (string? out) out ""))))
      ;; Pipe through remaining commands
      (let loop ((remaining (cdr segments)) (input first-output))
        (if (null? remaining)
          (values input cwd)
          (let* ((seg (car remaining))
                 (tokens (parse-command-line seg))
                 (cmd (if (null? tokens) "" (car tokens))))
            (if (builtin? cmd)
              ;; Can't easily pipe into builtins; just run them normally
              (let-values (((out new-cwd) (eshell-execute-command seg cwd)))
                (loop (cdr remaining) (if (string? out) out "")))
              ;; External: pipe via stdin
              (let* ((args (if (null? tokens) '() (cdr tokens)))
                     (output
                       (guard (e [#t input])
                         (run-external-command-with-stdin
                           (string-join tokens " ") cwd input))))
                (loop (cdr remaining) (if output output "")))))))))

  ;;;==========================================================================
  ;;; Input processing (main entry point)
  ;;;==========================================================================

  (define (eshell-process-input input cwd)
    "Process an eshell input line.
     Returns (values output new-cwd).
     output can be:
       - a string to display
       - 'clear to clear the buffer
       - 'exit to close the eshell"
    (let ((trimmed (safe-string-trim-both input)))
      (cond
        ;; Empty input
        ((string=? trimmed "")
         (values "" cwd))

        ;; Scheme expression (starts with open paren)
        ((char=? (string-ref trimmed 0) #\()
         (eshell-eval-expression trimmed cwd))

        ;; Pipeline (contains |)
        ((string-contains trimmed "|")
         (eshell-process-pipeline trimmed cwd))

        ;; Command substitution $(...)
        ((string-contains trimmed "$(")
         (eshell-execute-command-with-redirect
           (eshell-expand-command-substitution trimmed cwd) cwd))

        ;; Regular command (with env/glob expansion and redirection)
        (else
         (eshell-execute-command-with-redirect trimmed cwd)))))

  ;;;==========================================================================
  ;;; Register built-in commands
  ;;;==========================================================================

  ;; pwd
  (register-builtin! "pwd"
    (lambda (args cwd)
      (values (string-append cwd "\n") cwd)))

  ;; cd
  (register-builtin! "cd"
    (lambda (args cwd)
      (let* ((target (if (null? args)
                       (or (getenv "HOME") "/")
                       (car args)))
             (path (if (string-prefix? "/" target)
                     target
                     (string-append cwd "/" target))))
        (if (and (file-exists? path)
                 (file-directory? path))
          (values "" path)
          (values (string-append "cd: no such directory: " target "\n") cwd)))))

  ;; echo
  (register-builtin! "echo"
    (lambda (args cwd)
      (values (string-append (string-join args " ") "\n") cwd)))

  ;; cat
  (register-builtin! "cat"
    (lambda (args cwd)
      (if (null? args)
        (values "" cwd)
        (let ((output
               (string-join
                 (map (lambda (file)
                        (let ((path (resolve-path file cwd)))
                          (if (file-exists? path)
                            (read-file-contents path)
                            (string-append "cat: " file ": No such file\n"))))
                      args)
                 "")))
          (values output cwd)))))

  ;; ls
  (register-builtin! "ls"
    (lambda (args cwd)
      (let* ((show-long? (member "-l" args))
             (show-all? (member "-a" args))
             (dirs (filter (lambda (a) (not (string-prefix? "-" a))) args))
             (target (if (null? dirs) cwd
                       (let ((d (car dirs)))
                         (if (string-prefix? "/" d) d
                           (string-append cwd "/" d))))))
        (if (and (file-exists? target)
                 (file-directory? target))
          (let ((text (eshell-format-ls target show-long? show-all?)))
            (values text cwd))
          (values (string-append "ls: cannot access '"
                    target "': No such file or directory\n")
                  cwd)))))

  ;; mkdir
  (register-builtin! "mkdir"
    (lambda (args cwd)
      (if (null? args)
        (values "mkdir: missing operand\n" cwd)
        (begin
          (for-each
            (lambda (dir)
              (let ((path (resolve-path dir cwd)))
                (mkdir path)))
            args)
          (values "" cwd)))))

  ;; rm
  (register-builtin! "rm"
    (lambda (args cwd)
      (if (null? args)
        (values "rm: missing operand\n" cwd)
        (let ((output ""))
          (for-each
            (lambda (file)
              (let ((path (resolve-path file cwd)))
                (if (file-exists? path)
                  (guard (e [#t
                             (set! output (string-append output "rm: " file ": "
                                            (exception->string e) "\n"))])
                    (delete-file path))
                  (set! output (string-append output "rm: " file
                                 ": No such file\n")))))
            args)
          (values output cwd)))))

  ;; cp
  (register-builtin! "cp"
    (lambda (args cwd)
      (if (< (length args) 2)
        (values "cp: missing operand\n" cwd)
        (let* ((src-name (car args))
               (dst-name (cadr args))
               (src (resolve-path src-name cwd))
               (dst (resolve-path dst-name cwd)))
          (if (file-exists? src)
            (begin
              (copy-file-simple src dst)
              (values "" cwd))
            (values (string-append "cp: " src-name ": No such file\n") cwd))))))

  ;; mv
  (register-builtin! "mv"
    (lambda (args cwd)
      (if (< (length args) 2)
        (values "mv: missing operand\n" cwd)
        (let* ((src-name (car args))
               (dst-name (cadr args))
               (src (resolve-path src-name cwd))
               (dst (resolve-path dst-name cwd)))
          (if (file-exists? src)
            (begin
              (rename-file src dst)
              (values "" cwd))
            (values (string-append "mv: " src-name ": No such file\n") cwd))))))

  ;; wc (word count)
  (register-builtin! "wc"
    (lambda (args cwd)
      (if (null? args)
        (values "wc: missing operand\n" cwd)
        (let ((output
               (string-join
                 (map (lambda (file)
                        (let ((path (resolve-path file cwd)))
                          (if (file-exists? path)
                            (let* ((text (read-file-contents path))
                                   (lines (length (pregexp-split "\n" text)))
                                   (words (length (pregexp-split "\\s+" text)))
                                   (chars (string-length text)))
                              (string-append
                                (number->string lines) "\t"
                                (number->string words) "\t"
                                (number->string chars) "\t"
                                file))
                            (string-append "wc: " file ": No such file"))))
                      args)
                 "\n")))
          (values (string-append output "\n") cwd)))))

  ;; head
  (register-builtin! "head"
    (lambda (args cwd)
      (let* ((n-flag (member "-n" args))
             (n (if (and n-flag (pair? (cdr n-flag)))
                  (or (string->number (cadr n-flag)) 10)
                  10))
             (files (filter (lambda (a) (and (not (string=? a "-n"))
                                              (not (and n-flag
                                                        (pair? (cdr n-flag))
                                                        (equal? a (cadr n-flag))))
                                              (not (string-prefix? "-" a))))
                            args)))
        (if (null? files)
          (values "head: missing operand\n" cwd)
          (let ((path (resolve-path (car files) cwd)))
            (if (file-exists? path)
              (let* ((text (read-file-contents path))
                     (all-lines (pregexp-split "\n" text))
                     (taken (let loop ((ls all-lines) (i 0) (acc '()))
                              (if (or (null? ls) (>= i n))
                                (reverse acc)
                                (loop (cdr ls) (+ i 1) (cons (car ls) acc))))))
                (values (string-append (string-join taken "\n") "\n") cwd))
              (values (string-append "head: " (car files) ": No such file\n")
                      cwd)))))))

  ;; tail
  (register-builtin! "tail"
    (lambda (args cwd)
      (let* ((n-flag (member "-n" args))
             (n (if (and n-flag (pair? (cdr n-flag)))
                  (or (string->number (cadr n-flag)) 10)
                  10))
             (files (filter (lambda (a) (and (not (string=? a "-n"))
                                              (not (and n-flag
                                                        (pair? (cdr n-flag))
                                                        (equal? a (cadr n-flag))))
                                              (not (string-prefix? "-" a))))
                            args)))
        (if (null? files)
          (values "tail: missing operand\n" cwd)
          (let ((path (resolve-path (car files) cwd)))
            (if (file-exists? path)
              (let* ((text (read-file-contents path))
                     (all-lines (pregexp-split "\n" text))
                     (total (length all-lines))
                     (start (max 0 (- total n)))
                     (taken (let loop ((ls all-lines) (i 0) (acc '()))
                              (cond
                                ((null? ls) (reverse acc))
                                ((>= i start) (loop (cdr ls) (+ i 1)
                                                    (cons (car ls) acc)))
                                (else (loop (cdr ls) (+ i 1) acc))))))
                (values (string-append (string-join taken "\n") "\n") cwd))
              (values (string-append "tail: " (car files) ": No such file\n")
                      cwd)))))))

  ;; which
  (register-builtin! "which"
    (lambda (args cwd)
      (if (null? args)
        (values "which: missing argument\n" cwd)
        (let* ((name (car args))
               (path-dirs (pregexp-split ":" (or (getenv "PATH") "")))
               (found (let loop ((dirs path-dirs))
                        (if (null? dirs) #f
                          (let ((full (string-append (car dirs) "/" name)))
                            (if (file-exists? full) full
                              (loop (cdr dirs))))))))
          (if found
            (values (string-append found "\n") cwd)
            (values (string-append name " not found\n") cwd))))))

  ;; env
  (register-builtin! "env"
    (lambda (args cwd)
      (if (null? args)
        ;; Show some common env vars
        (let ((vars '("HOME" "PATH" "SHELL" "USER" "LANG" "TERM")))
          (values
            (let ((lines (filter values
                           (map (lambda (v)
                                  (let ((val (getenv v)))
                                    (and val (string-append v "=" val))))
                                vars))))
              (if (null? lines) ""
                (string-append (string-join lines "\n") "\n")))
            cwd))
        ;; Show specific var
        (let ((val (getenv (car args))))
          (if val
            (values (string-append val "\n") cwd)
            (values (string-append (car args) ": not set\n") cwd))))))

  ;; export (set env var)
  (register-builtin! "export"
    (lambda (args cwd)
      (if (null? args)
        (values "export: usage: export NAME=VALUE\n" cwd)
        (begin
          (for-each
            (lambda (arg)
              (let ((eq-pos (string-contains arg "=")))
                (when eq-pos
                  (let ((name (substring arg 0 eq-pos))
                        (val (substring arg (+ eq-pos 1) (string-length arg))))
                    (putenv name val)))))
            args)
          (values "" cwd)))))

  ;; clear
  (register-builtin! "clear"
    (lambda (args cwd)
      (values 'clear cwd)))

  ;; exit
  (register-builtin! "exit"
    (lambda (args cwd)
      (values 'exit cwd)))

  ;; grep
  (register-builtin! "grep"
    (lambda (args cwd)
      (if (< (length args) 2)
        (values "grep: usage: grep PATTERN FILE...\n" cwd)
        (let* ((pattern (car args))
               (files (cdr args))
               (rx (guard (e [#t #f])
                     (pregexp pattern))))
          (if (not rx)
            (values (string-append "grep: invalid pattern: " pattern "\n") cwd)
            (let ((output
                   (string-join
                     (filter values
                       (map
                         (lambda (file)
                           (let ((path (resolve-path file cwd)))
                             (if (file-exists? path)
                               (let* ((text (read-file-contents path))
                                      (lines (pregexp-split "\n" text))
                                      (matches (filter (lambda (line)
                                                         (pregexp-match rx line))
                                                       lines)))
                                 (if (null? matches) #f
                                   (string-join
                                     (map (lambda (line)
                                            (if (> (length files) 1)
                                              (string-append file ":" line)
                                              line))
                                          matches)
                                     "\n")))
                               (string-append "grep: " file ": No such file"))))
                         files))
                     "\n")))
              (values (if (string=? output "") ""
                        (string-append output "\n"))
                      cwd)))))))

  ;; find
  (register-builtin! "find"
    (lambda (args cwd)
      (let* ((dir (if (null? args) cwd
                    (let ((d (car args)))
                      (if (string-prefix? "/" d) d
                        (string-append cwd "/" d)))))
             (name-flag (member "-name" args))
             (name-pattern (and name-flag (pair? (cdr name-flag))
                                (cadr name-flag)))
             (results '()))
        (if (not (and (file-exists? dir)
                      (file-directory? dir)))
          (values (string-append "find: '" dir "': No such directory\n") cwd)
          (begin
            (walk-dir! dir
              (lambda (path)
                (if name-pattern
                  ;; Convert glob pattern to regex
                  (let* ((rx-str (glob->regex name-pattern))
                         (rx (pregexp rx-str))
                         (basename (path-strip-directory path)))
                    (when (pregexp-match rx basename)
                      (set! results (cons path results))))
                  (set! results (cons path results)))))
            (values (if (null? results) ""
                      (string-append
                        (string-join (list-sort string<? (reverse results)) "\n")
                        "\n"))
                    cwd))))))

) ;; end library
