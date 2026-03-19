#!/usr/bin/env scheme-script
#!chezscheme
;;; main.ss — Executable entry point for jemacs (jerboa-emacs)

(import (except (chezscheme) make-hash-table hash-table? iota 1+ 1-
                getenv path-extension path-absolute? thread?
                make-mutex mutex? mutex-name)
        (jerboa core)
        (jerboa runtime)
        (std sugar)
        (jerboa-emacs editor)
        (jerboa-emacs window)
        (chez-scintilla tui)
        (except (jerboa-emacs app) main)
        (jerboa-emacs editor-extra-org)
        (jerboa-emacs ipc)
        (jerboa-emacs debug-repl))

;;; Version manifest
(define version-manifest
  '(("" . "jerboa-emacs")
    ("Jerboa" . "master")
    ("Chez Scheme" . "10.x")))

(define (parse-repl-port args)
  "Return (port-num . filtered-args) if --repl <port> is present, else #f."
  (let loop ((rest args) (acc '()))
    (cond
      ((null? rest) #f)
      ((and (string=? (car rest) "--repl")
            (pair? (cdr rest))
            (string->number (cadr rest)))
       (cons (string->number (cadr rest))
             (append (reverse acc) (cddr rest))))
      (else (loop (cdr rest) (cons (car rest) acc))))))

(define (main . args)
  (cond
    ((member "--version" args)
     (display (string-append "jemacs " (cdr (car version-manifest)))) (newline)
     (for-each (lambda (p)
                 (when (not (string=? (car p) ""))
                   (display (string-append (car p) " " (cdr p))) (newline)))
               (cdr version-manifest)))
    ((member "--help" args)
     (display "Usage: jemacs [OPTIONS] [FILES...]") (newline)
     (display "Options:") (newline)
     (display "  --version        Show version information") (newline)
     (display "  --help           Show this help message") (newline)
     (display "  --repl <port>    Start TCP debug REPL on given port (0=auto)") (newline))
    (else
     (let* ((repl-port-env (getenv "JEMACS_REPL_PORT"))
            (repl-info     (or (parse-repl-port args)
                               (and repl-port-env
                                    (cons (string->number repl-port-env) args))))
            (clean-args    (if repl-info (cdr repl-info) args))
            (app           (app-init! clean-args)))
       (when repl-info
         (start-debug-repl! (car repl-info)))
       (try
         (app-run! app)
         (finally
           (when *desktop-save-mode* (tui-session-save! app))
           (when repl-info (stop-debug-repl!))
           (stop-ipc-server!)
           (frame-shutdown! (app-state-frame app))
           (tui-shutdown!)))))))

(apply main (command-line-arguments))
