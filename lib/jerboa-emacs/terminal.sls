#!chezscheme
;;; terminal.sls — Terminal mode: ANSI color rendering
;;;
;;; Ported from gerbil-emacs/terminal.ss
;;; The gsh (Gerbil shell) integration is stubbed — terminal-start!
;;; creates a simple subprocess-backed terminal instead.
;;; ANSI escape sequence parsing and Scintilla styling are fully ported.

(library (jerboa-emacs terminal)
  (export terminal-buffer?
          terminal-state? make-terminal-state
          terminal-state-env terminal-state-env-set!
          terminal-state-prompt-pos terminal-state-prompt-pos-set!
          terminal-state-fg-color terminal-state-fg-color-set!
          terminal-state-bold? terminal-state-bold?-set!
          terminal-state-pty-master terminal-state-pty-master-set!
          terminal-state-pty-pid terminal-state-pty-pid-set!
          terminal-state-pty-channel terminal-state-pty-channel-set!
          terminal-state-pty-thread terminal-state-pty-thread-set!
          terminal-state-vtscreen terminal-state-vtscreen-set!
          terminal-state-pre-pty-text terminal-state-pre-pty-text-set!
          *terminal-state*
          terminal-start!
          terminal-execute!
          terminal-execute-async!
          terminal-poll-output
          terminal-interrupt!
          terminal-resize!
          terminal-send-input!
          terminal-pty-busy?
          terminal-cleanup-pty!
          terminal-prompt
          terminal-prompt-raw
          terminal-stop!
          setup-terminal-styles!
          parse-ansi-segments
          SCI_STARTSTYLING
          SCI_SETSTYLING
          terminal-insert-styled!
          color-to-style
          text-segment? make-text-segment
          text-segment-text text-segment-fg-color text-segment-bold?
          *term-style-base*)

  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (jerboa-emacs core)
          (jerboa-emacs pty)
          (jerboa-emacs vtscreen)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (only (std misc channel) make-channel channel-put channel-try-get channel-close)
          (only (std misc thread) thread-sleep!))

  ;;=========================================================================
  ;; Scintilla styling message IDs (not in constants.ss)
  ;;=========================================================================

  (define SCI_STARTSTYLING 2032)
  (define SCI_SETSTYLING   2033)

  ;;=========================================================================
  ;; Terminal ANSI color palette (standard 16 colors)
  ;;=========================================================================

  ;; Styles 64-79 reserved for terminal colors
  (define *term-style-base* 64)

  ;; Standard terminal colors (dark theme)
  (define *term-colors*
    (vector
     ;; Normal colors (0-7)
     #x000000  ; 0 black
     #xcc6666  ; 1 red
     #xb5bd68  ; 2 green
     #xf0c674  ; 3 yellow
     #x81a2be  ; 4 blue
     #xb294bb  ; 5 magenta
     #x8abeb7  ; 6 cyan
     #xc5c8c6  ; 7 white (light gray)
     ;; Bright colors (8-15)
     #x969896  ; 8 bright black (dark gray)
     #xde935f  ; 9 bright red
     #xa3be8c  ; 10 bright green
     #xebcb8b  ; 11 bright yellow
     #x5f819d  ; 12 bright blue
     #x85678f  ; 13 bright magenta
     #x5e8d87  ; 14 bright cyan
     #xffffff  ; 15 bright white
     ))

  ;;=========================================================================
  ;; Terminal state
  ;;=========================================================================

  (define (terminal-buffer? buf)
    "Check if this buffer is a terminal buffer."
    (eq? (buffer-lexer-lang buf) 'terminal))

  ;; Maps terminal buffers to their terminal-state structs
  (define *terminal-state* (make-hash-table))

  (defstruct terminal-state
    (env         ; environment alist or #f
     prompt-pos  ; character position where current input starts (after prompt)
     fg-color    ; current ANSI foreground color index (0-15, or -1 for default)
     bold?       ; ANSI bold/bright flag (shifts color index +8)
     ;; Async PTY fields
     pty-master  ; master fd (int) or #f when no PTY child running
     pty-pid     ; child PID or #f
     pty-channel ; channel for reader thread -> UI communication, or #f
     pty-thread  ; reader thread or #f
     ;; VT100 screen buffer for full-screen programs
     vtscreen    ; vtscreen struct or #f
     ;; Text before PTY command started
     pre-pty-text)) ; string or #f

  ;;=========================================================================
  ;; Text segment for ANSI-colored output
  ;;=========================================================================

  (defstruct text-segment
    (text      ; string
     fg-color  ; 0-15 or -1 (default)
     bold?))   ; boolean

  ;;=========================================================================
  ;; Terminal style setup
  ;;=========================================================================

  (define (setup-terminal-styles! ed)
    "Configure Scintilla styles 64-79 for terminal ANSI colors."
    (let loop ((i 0))
      (when (< i 16)
        (let ((style (+ *term-style-base* i))
              (color (vector-ref *term-colors* i)))
          (send-message ed SCI_STYLESETFORE style color)
          (send-message ed SCI_STYLESETBACK style #x181818))
        (loop (+ i 1)))))

  ;;=========================================================================
  ;; ANSI escape sequence parsing
  ;;=========================================================================

  (define (parse-ansi-segments str)
    "Parse ANSI SGR escape sequences from a string.
     Returns a list of text-segment structs."
    (let ((len (string-length str))
          (esc (integer->char 27))
          (bel (integer->char 7)))
      (let loop ((i 0) (fg -1) (bold? #f) (text-acc '()) (segments '()))
        (if (>= i len)
          ;; Flush remaining text
          (let ((final-text (list->string (reverse text-acc))))
            (reverse
              (if (string=? final-text "")
                segments
                (cons (make-text-segment final-text fg bold?) segments))))
          (let ((ch (string-ref str i)))
            (cond
              ;; Skip carriage returns
              ((char=? ch #\return)
               (loop (+ i 1) fg bold? text-acc segments))

              ;; ESC sequence
              ((char=? ch esc)
               ;; Flush current text
               (let* ((current-text (list->string (reverse text-acc)))
                      (new-segments
                        (if (string=? current-text "")
                          segments
                          (cons (make-text-segment current-text fg bold?) segments))))
                 (if (< (+ i 1) len)
                   (let ((next (string-ref str (+ i 1))))
                     (cond
                       ;; CSI: ESC[
                       ((char=? next #\[)
                        (let-values (((new-i new-fg new-bold?)
                                      (parse-csi str (+ i 2) len fg bold?)))
                          (loop new-i new-fg new-bold? '() new-segments)))
                       ;; OSC: ESC] ... BEL
                       ((char=? next #\])
                        (let skip ((j (+ i 2)))
                          (if (>= j len) (loop j fg bold? '() new-segments)
                            (if (char=? (string-ref str j) bel)
                              (loop (+ j 1) fg bold? '() new-segments)
                              (skip (+ j 1))))))
                       ;; Character set designation: ESC ( X, ESC ) X, etc. (3 bytes)
                       ((and (memv next '(#\( #\) #\* #\+))
                             (< (+ i 2) len))
                        (loop (+ i 3) fg bold? '() new-segments))
                       ;; Other: ESC + single char (skip)
                       (else (loop (+ i 2) fg bold? '() new-segments))))
                   (loop (+ i 1) fg bold? '() new-segments))))

              ;; Regular character
              (else
               (loop (+ i 1) fg bold? (cons ch text-acc) segments))))))))

  (define (parse-csi str i len fg bold?)
    "Parse a CSI sequence (ESC[ already consumed)."
    (let collect-params ((j i) (params '()) (current ""))
      (if (>= j len)
        (values j fg bold?)
        (let ((ch (string-ref str j)))
          (cond
            ;; Parameter digit
            ((and (char>=? ch #\0) (char<=? ch #\9))
             (collect-params (+ j 1) params (string-append current (string ch))))
            ;; Semicolon separator
            ((char=? ch #\;)
             (collect-params (+ j 1)
                             (cons (if (string=? current "") 0
                                     (or (string->number current) 0))
                                   params)
                             ""))
            ;; Final byte (determines command)
            ((and (char>=? ch #\@) (char<=? ch #\~))
             (let ((final-params
                     (reverse
                       (cons (if (string=? current "") 0
                               (or (string->number current) 0))
                             params))))
               (if (char=? ch #\m)
                 ;; SGR - Select Graphic Rendition
                 (let-values (((new-fg new-bold?) (apply-sgr-params final-params fg bold?)))
                   (values (+ j 1) new-fg new-bold?))
                 ;; Non-SGR CSI: skip
                 (values (+ j 1) fg bold?))))
            ;; Intermediate byte or unknown
            (else
             (collect-params (+ j 1) params current)))))))

  (define (apply-sgr-params params fg bold?)
    "Apply SGR parameters to current state."
    (let loop ((ps params) (fg fg) (bold? bold?))
      (if (null? ps)
        (values fg bold?)
        (let ((p (car ps)))
          (cond
            ((= p 0)   (loop (cdr ps) -1 #f))
            ((= p 1)   (loop (cdr ps) fg #t))
            ((= p 22)  (loop (cdr ps) fg #f))
            ((and (>= p 30) (<= p 37))
             (loop (cdr ps) (- p 30) bold?))
            ((= p 39)  (loop (cdr ps) -1 bold?))
            ((and (>= p 90) (<= p 97))
             (loop (cdr ps) (+ (- p 90) 8) bold?))
            (else       (loop (cdr ps) fg bold?)))))))

  ;;=========================================================================
  ;; Compute style index from color state
  ;;=========================================================================

  (define (color-to-style fg bold?)
    "Map ANSI color state to a Scintilla style index."
    (cond
      ((= fg -1)
       (if bold?
         (+ *term-style-base* 15)  ; bright white for bold default
         0))                       ; STYLE_DEFAULT for normal default
      (else
       (let ((idx (if (and bold? (< fg 8)) (+ fg 8) fg)))
         (+ *term-style-base* idx)))))

  ;;=========================================================================
  ;; Strip ANSI codes
  ;;=========================================================================

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
                    ((and (memv next '(#\( #\) #\* #\+))
                          (< (+ i 2) len))
                     (loop (+ i 3) acc))
                    (else (loop (+ i 2) acc))))
                (loop (+ i 1) acc))
              (if (or (char=? ch #\return)
                      (char=? ch (integer->char 1))
                      (char=? ch (integer->char 2)))
                (loop (+ i 1) acc)
                (loop (+ i 1) (cons ch acc)))))))))

  ;;=========================================================================
  ;; Terminal lifecycle (subprocess-backed, no gsh)
  ;;=========================================================================

  (define (terminal-start!)
    "Create a subprocess-backed terminal and return a terminal-state.
     Note: gsh integration is not available in jerboa — uses simple
     subprocess execution instead."
    (let ((env '()))
      (make-terminal-state env 0 -1 #f #f #f #f #f #f #f)))

  (define (terminal-prompt-raw ts)
    "Return the raw prompt string."
    (let ((user (or (getenv "USER") "user"))
          (host (or (getenv "HOSTNAME") "localhost"))
          (cwd (or (getenv "PWD") (current-directory))))
      (string-append user "@" host ":" cwd "$ ")))

  (define (terminal-prompt ts)
    "Return the prompt string (ANSI stripped)."
    (strip-ansi-codes (terminal-prompt-raw ts)))

  (define (terminal-execute! input ts)
    "Execute a command via subprocess, return (values output-string new-cwd)."
    (let ((trimmed (safe-string-trim-both input)))
      (cond
        ((string=? trimmed "")
         (values "" (current-directory)))
        ((string=? trimmed "clear")
         (values 'clear (current-directory)))
        ((string=? trimmed "exit")
         (values 'exit (current-directory)))
        (else
         (guard (e [#t (values (string-append "Error: "
                                 (call-with-string-output-port
                                   (lambda (p) (display-condition e p)))
                                 "\n")
                               (current-directory))])
           (let-values (((to-stdin from-stdout from-stderr proc-id)
                         (open-process-ports
                           (string-append "/bin/sh -c " (shell-quote trimmed))
                           (buffer-mode block)
                           (native-transcoder))))
             (close-port to-stdin)
             (let ((stdout (get-string-all from-stdout))
                   (stderr (get-string-all from-stderr)))
               (close-port from-stdout)
               (close-port from-stderr)
               (values (string-append
                         (if (eof-object? stdout) "" stdout)
                         (if (eof-object? stderr) "" stderr))
                       (current-directory)))))))))

  (define (shell-quote str)
    "Simple shell quoting."
    (string-append "'" (let loop ((i 0) (acc '()))
      (if (>= i (string-length str))
        (list->string (reverse acc))
        (let ((ch (string-ref str i)))
          (if (char=? ch #\')
            (loop (+ i 1) (append '(#\' #\\ #\' #\') acc))
            (loop (+ i 1) (cons ch acc)))))) "'"))

  ;;=========================================================================
  ;; Terminal text insertion with styling
  ;;=========================================================================

  (define (terminal-insert-styled! ed segments start-pos)
    "Insert text segments into editor at end, applying ANSI styles."
    (let loop ((segs segments) (pos start-pos) (total 0))
      (if (null? segs)
        total
        (let* ((seg (car segs))
               (text (text-segment-text seg))
               (fg (text-segment-fg-color seg))
               (bold? (text-segment-bold? seg))
               (style (color-to-style fg bold?))
               (text-len (string-length text)))
          ;; Insert the text
          (editor-append-text ed text)
          ;; Apply style if not default
          (when (> style 0)
            (send-message ed SCI_STARTSTYLING pos 0)
            (send-message ed SCI_SETSTYLING text-len style))
          (loop (cdr segs) (+ pos text-len) (+ total text-len))))))

  ;;=========================================================================
  ;; Async PTY execution
  ;;=========================================================================

  (define (pty-waitpid-status pid nohang?)
    "Wait for child and return just the exit status integer."
    (let-values (((status exited?) (pty-waitpid pid nohang?)))
      status))

  (define (pty-reader-loop mfd pid ch)
    "Reader thread body: poll PTY output and post to channel."
    (guard (e [#t
               (jemacs-log! "PTY reader error: "
                 (call-with-string-output-port
                   (lambda (p) (display-condition e p))))
               (channel-put ch (cons 'done -1))])
      (let loop ()
        (thread-sleep! 0.01)
        (let ((data (pty-read mfd)))
          (cond
            ((string? data)
             (channel-put ch (cons 'data data))
             (loop))
            ((eq? data 'eof)
             (let ((status (pty-waitpid-status pid #f)))
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
                      (let ((status (pty-waitpid-status pid #t)))
                        (channel-put ch (cons 'done status))))))))))))))

  (define terminal-execute-async!
    (case-lambda
      ((input ts) (terminal-execute-async! input ts 24 80))
      ((input ts pty-rows pty-cols)
       (let ((trimmed (safe-string-trim-both input)))
         (cond
           ((string=? trimmed "")
            (values 'sync "" (current-directory)))
           ((string=? trimmed "clear")
            (values 'special 'clear #f))
           ((string=? trimmed "exit")
            (values 'special 'exit #f))
           (else
            ;; Spawn PTY subprocess (async)
            (let ((env-alist '()))
              (guard (e [#t
                         ;; forkpty failed, fall back to sync
                         (let-values (((output cwd) (terminal-execute! trimmed ts)))
                           (values 'sync output cwd))])
                (let-values (((mfd pid) (pty-spawn trimmed env-alist pty-rows pty-cols)))
                  (if (and mfd pid)
                    (let ((ch (make-channel)))
                      ;; Store PTY state
                      (terminal-state-pty-master-set! ts mfd)
                      (terminal-state-pty-pid-set! ts pid)
                      (terminal-state-pty-channel-set! ts ch)
                      ;; Create VT100 screen buffer
                      (terminal-state-vtscreen-set! ts (new-vtscreen pty-rows pty-cols))
                      ;; Spawn reader thread
                      (let ((thread (fork-thread (lambda () (pty-reader-loop mfd pid ch)))))
                        (terminal-state-pty-thread-set! ts thread)
                        (values 'async #f #f)))
                    ;; forkpty failed, fall back to sync
                    (let-values (((output cwd) (terminal-execute! trimmed ts)))
                      (values 'sync output cwd))))))))))))

  (define (terminal-poll-output ts)
    "Non-blocking check for PTY output."
    (let ((ch (terminal-state-pty-channel ts)))
      (and ch (channel-try-get ch))))

  (define (terminal-pty-busy? ts)
    "Check if a PTY command is currently running."
    (and (terminal-state-pty-pid ts) #t))

  (define (terminal-interrupt! ts)
    "Send SIGINT to the PTY child process group."
    (let ((pid (terminal-state-pty-pid ts)))
      (when pid
        (pty-kill! pid 2))))

  (define (terminal-resize! ts rows cols)
    "Notify PTY child of window size change."
    (let ((master (terminal-state-pty-master ts)))
      (when master
        (pty-resize! master rows cols))))

  (define (terminal-send-input! ts str)
    "Send keystrokes to PTY child's stdin."
    (let ((master (terminal-state-pty-master ts)))
      (when master
        (pty-write master str))))

  (define (terminal-cleanup-pty! ts)
    "Clean up PTY resources."
    (let ((master (terminal-state-pty-master ts))
          (pid (terminal-state-pty-pid ts))
          (ch (terminal-state-pty-channel ts)))
      (when (and master pid)
        (pty-close! master pid))
      (when ch
        (guard (e [#t (void)]) (channel-close ch)))
      (terminal-state-pty-master-set! ts #f)
      (terminal-state-pty-pid-set! ts #f)
      (terminal-state-pty-channel-set! ts #f)
      (terminal-state-pty-thread-set! ts #f)
      (terminal-state-vtscreen-set! ts #f)
      (terminal-state-pre-pty-text-set! ts #f)))

  (define (terminal-stop! ts)
    "Clean up the terminal state."
    (terminal-cleanup-pty! ts))

) ;; end library
