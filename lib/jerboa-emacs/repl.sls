#!chezscheme
;;; repl.sls — REPL subprocess management for jemacs
;;;
;;; Ported from gerbil-emacs/repl.ss
;;; Manages a scheme subprocess: spawn, send input, read output, stop.
;;; No backend imports — shared between TUI and Qt.

(library (jerboa-emacs repl)
  (export
    repl-state? repl-state-process repl-state-prompt-pos
    repl-state-prompt-pos-set! repl-state-history repl-state-history-set!
    make-repl-state
    repl-start!
    repl-send!
    repl-read-available
    repl-stop!
    repl-prompt)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std misc process))

  ;;;============================================================================
  ;;; REPL state
  ;;;============================================================================

  (defstruct repl-state (process prompt-pos history))

  (def repl-prompt "scheme> ")

  ;;;============================================================================
  ;;; Lifecycle
  ;;;============================================================================

  (def (repl-start!)
    (let ((pp (open-process (list "scheme"))))
      (make-repl-state pp 0 '())))

  (def (repl-send! rs input)
    (let* ((pp (repl-state-process rs))
           (stdin (process-port-rec-stdin-port pp)))
      (put-string stdin input)
      (newline stdin)
      (flush-output-port stdin))
    ;; Add to history
    (repl-state-history-set! rs
      (cons input (repl-state-history rs))))

  (def (repl-read-available rs)
    (let* ((pp (repl-state-process rs))
           (stdout (process-port-rec-stdout-port pp)))
      (if (input-port-ready? stdout)
        (let ((out (open-output-string)))
          (let loop ()
            (when (input-port-ready? stdout)
              (let ((ch (read-char stdout)))
                (unless (eof-object? ch)
                  (write-char ch out)
                  (loop)))))
          (let ((s (get-output-string out)))
            (if (string=? s "") #f s)))
        #f)))

  (def (repl-stop! rs)
    (let ((pp (repl-state-process rs)))
      (with-catch void
        (lambda ()
          (let ((stdin (process-port-rec-stdin-port pp)))
            (when stdin (close-port stdin)))))
      (with-catch void
        (lambda ()
          (let ((stdout (process-port-rec-stdout-port pp)))
            (when stdout (close-port stdout)))))))

  ) ;; end library
