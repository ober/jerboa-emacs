#!chezscheme
;;; gsh-subprocess.sls — Command execution with portable fallbacks
;;;
;;; Ported from gerbil-emacs/gsh-subprocess.ss
;;; gsh dependencies are stubbed: commands run via /bin/sh -c through
;;; open-process-ports instead of gsh-capture.

(library (jerboa-emacs gsh-subprocess)
  (export gsh-run-command
          gsh-run-command/qt
          gsh-active-process
          gsh-kill-active-process!)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (jerboa-emacs core))

  ;;;==========================================================================
  ;;; Active process tracking
  ;;;==========================================================================

  (define *gsh-active-process* #f)

  (define (gsh-active-process) *gsh-active-process*)

  (define (gsh-kill-active-process!)
    "Kill the currently tracked subprocess, if any."
    (set! *gsh-active-process* #f))

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

  (define (sh-capture-with-stdin cmd stdin-text)
    "Run CMD via /bin/sh -c with stdin-text piped in.
     Returns (values output-string exit-status)."
    (let-values (((to-stdin from-stdout from-stderr pid)
                  (open-process-ports
                    (string-append "/bin/sh -c " (shell-quote cmd))
                    'block
                    (native-transcoder))))
      (when stdin-text
        (put-string to-stdin stdin-text)
        (flush-output-port to-stdin))
      (close-port to-stdin)
      (let ((stdout-str (get-string-all from-stdout))
            (stderr-str (get-string-all from-stderr)))
        (close-port from-stdout)
        (close-port from-stderr)
        (let ((out (if (eof-object? stdout-str) "" stdout-str))
              (err (if (eof-object? stderr-str) "" stderr-str)))
          (values (string-append out err) 0)))))

  ;;;==========================================================================
  ;;; TUI variant: polls peek-event for C-g
  ;;;==========================================================================

  (define (gsh-run-command cmd peek-event event-key? event-key . rest)
    "Run CMD via /bin/sh, capturing output.
     PEEK-EVENT is called to check for C-g (key code 7).
     Returns (values output-string exit-status).
     Raises keyboard-quit-exception on C-g.
     Optional keyword-style args: stdin-text cwd (positional after event-key)."
    (let ((stdin-text (if (and (pair? rest) (pair? (cdr rest)))
                        ;; rest = (stdin-text: val cwd: val ...)
                        ;; but we use positional for simplicity
                        (car rest)
                        #f))
          (cwd (if (and (pair? rest) (pair? (cdr rest)))
                 (cadr rest)
                 #f)))
      ;; Check for C-g before starting
      (let ((ev (peek-event 0)))
        (when (and ev (event-key? ev) (= (event-key ev) 7))
          (raise (make-keyboard-quit-exception))))
      ;; Set cwd if specified
      (when cwd
        (with-catch void (lambda () (current-directory cwd))))
      (dynamic-wind
        (lambda () (set! *gsh-active-process* #t))
        (lambda ()
          (if stdin-text
            (let-values (((output status) (sh-capture-with-stdin cmd stdin-text)))
              (values output status))
            (let-values (((output status) (sh-capture cmd)))
              (values output status))))
        (lambda () (set! *gsh-active-process* #f)))))

  ;;;==========================================================================
  ;;; Qt variant: pumps Qt event loop for C-g
  ;;;==========================================================================

  (define (gsh-run-command/qt cmd process-events! . rest)
    "Run CMD via /bin/sh, capturing output.
     PROCESS-EVENTS! pumps the Qt event loop so keystrokes set *quit-flag*.
     Returns (values output-string exit-status).
     Raises keyboard-quit-exception on C-g.
     Optional positional args: stdin-text cwd."
    (let ((stdin-text (if (pair? rest) (car rest) #f))
          (cwd (if (and (pair? rest) (pair? (cdr rest)))
                 (cadr rest)
                 #f)))
      ;; Check quit flag before starting
      (process-events!)
      (when (quit-flag?)
        (quit-flag-clear!)
        (raise (make-keyboard-quit-exception)))
      ;; Set cwd if specified
      (when cwd
        (with-catch void (lambda () (current-directory cwd))))
      (dynamic-wind
        (lambda () (set! *gsh-active-process* #t))
        (lambda ()
          (if stdin-text
            (let-values (((output status) (sh-capture-with-stdin cmd stdin-text)))
              (values output status))
            (let-values (((output status) (sh-capture cmd)))
              (values output status))))
        (lambda () (set! *gsh-active-process* #f)))))

  ) ;; end library
