;;; -*- Gerbil -*-
;;; Executable entry point for jemacs Qt backend

(export main)
(import (only-in :jerboa-emacs/qt/app qt-main))

;; Version manifest (inlined to avoid include path issues in compiled builds)
(def version-manifest
  '(("" . "jerboa-emacs")
    ("Jerboa" . "master")
    ("Chez Scheme" . "10.x")))

(def (main . args)
  (cond
    ((member "--version" args)
     (displayln "jemacs " (cdar version-manifest))
     (for-each (lambda (p)
                 (when (not (string=? (car p) ""))
                   (displayln (car p) " " (cdr p))))
               (cdr version-manifest)))
    ((member "--help" args)
     (displayln "Usage: jemacs-qt [OPTIONS] [FILES...]")
     (displayln "Options:")
     (displayln "  --version        Show version information")
     (displayln "  --help           Show this help message")
     (displayln "  --verbose        Log all Qt calls and commands to ~/.jemacs-verbose.log")
     (displayln "  --repl <port>    Start TCP debug REPL on given port (0=auto)"))
    (else
     (apply qt-main args))))
