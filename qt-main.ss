#!/usr/bin/env scheme-script
#!chezscheme
;;; qt-main.ss — Qt executable entry point for jerboa-emacs

(import (except (chezscheme) make-hash-table hash-table? iota 1+ 1-
                getenv path-extension path-absolute? thread?
                make-mutex mutex? mutex-name)
        (jerboa core)
        (std sugar)
        (jerboa-emacs core)
        (jerboa-emacs qt/app)
        (jerboa-emacs qt/main))

;;; Entry point
(define (main args)
  (displayln "Starting jerboa-emacs Qt...")
  (let ((exit-code (qt-main args)))
    (displayln (string-append "jerboa-emacs Qt exited with code: " 
                              (number->string exit-code)))
    exit-code))

;;; Run
(exit (main (command-line)))
