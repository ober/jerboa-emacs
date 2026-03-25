;;; -*- Gerbil -*-
;;; REPL subprocess management for jemacs
;;;
;;; Manages a Jerboa REPL subprocess: spawn, send input, read output, stop.
;;; Uses (std repl) with 40+ comma commands, value history, etc.
;;; No backend imports — shared between TUI and Qt.

(export
  (struct-out repl-state)
  repl-start!
  repl-send!
  repl-read-available
  repl-stop!
  repl-prompt)

(import :std/sugar
        :jerboa-emacs/core)

;;;============================================================================
;;; REPL state
;;;============================================================================

(defstruct repl-state
  (process       ; cons of (in-port . out-port) for the subprocess
   prompt-pos    ; integer: byte position where current input starts
   history)      ; list of previous inputs
  transparent: #t)

(def repl-prompt "jerboa> ")

;;;============================================================================
;;; Lifecycle
;;;============================================================================

(def (jerboa-lib-dir)
  "Find jerboa lib directory from current process library-directories."
  (let loop ((dirs (library-directories)))
    (if (null? dirs)
      ;; Fallback: try common locations
      (let ((home (or (getenv "HOME") "")))
        (let try ((candidates (list (string-append home "/mine/jerboa/lib")
                                    (string-append home "/.local/lib/jerboa")
                                    "/usr/local/lib/jerboa")))
          (if (null? candidates)
            #f
            (if (file-exists? (string-append (car candidates) "/std"))
              (car candidates)
              (try (cdr candidates))))))
      (let ((d (car (car dirs))))
        (if (and (string? d)
                 (> (string-length d) 4)
                 (file-exists? (string-append d "/std/repl.sls")))
          d
          (loop (cdr dirs)))))))

(def (repl-start!)
  "Spawn a Jerboa REPL subprocess and return a repl-state."
  ;; Build command with --libdirs for the jerboa stdlib
  (let* ((libdir (jerboa-lib-dir))
         (libdirs-arg
           (if libdir
             (string-append " --libdirs " libdir)
             ""))
         (cmd (string-append "scheme -q" libdirs-arg)))
    ;; Chez open-process-ports returns: (write-stdin read-stdout read-stderr pid)
    (let-values (((p-stdin p-stdout p-stderr pid)
                  (open-process-ports cmd (buffer-mode none) (native-transcoder))))
      (close-port p-stderr)
      (let ((rs (make-repl-state (cons p-stdout p-stdin) 0 '())))
        ;; Boot the jerboa REPL: import and start it
        (repl-send! rs "(import (std repl))")
        (repl-send! rs "(jerboa-repl)")
        ;; Disable ANSI colors — QScintilla/TUI can't render escape codes
        (repl-send! rs ",set color off")
        rs))))

;;;============================================================================
;;; ANSI escape code stripping
;;;============================================================================

(def esc-char (integer->char 27))  ;; ESC = 0x1B
(def bel-char (integer->char 7))   ;; BEL = 0x07

(def (strip-ansi str)
  "Remove ANSI escape sequences from a string.
   Handles CSI sequences (ESC [ ... final-byte) and OSC sequences."
  (let ((len (string-length str))
        (out (open-output-string)))
    (let loop ((i 0))
      (when (< i len)
        (let ((ch (string-ref str i)))
          (if (char=? ch esc-char)
            ;; Skip ESC sequence
            (if (< (+ i 1) len)
              (let ((next (string-ref str (+ i 1))))
                (cond
                  ;; CSI: ESC [ ... (ends at letter 0x40-0x7E)
                  ((char=? next #\[)
                   (let skip ((j (+ i 2)))
                     (if (>= j len)
                       (loop j)
                       (let ((c (string-ref str j)))
                         (if (and (char>=? c #\@) (char<=? c #\~))
                           (loop (+ j 1))
                           (skip (+ j 1)))))))
                  ;; OSC: ESC ] ... (ends at BEL or ST)
                  ((char=? next #\])
                   (let skip ((j (+ i 2)))
                     (if (>= j len)
                       (loop j)
                       (let ((c (string-ref str j)))
                         (if (or (char=? c bel-char)
                                 (char=? c esc-char))
                           (loop (+ j 1))
                           (skip (+ j 1)))))))
                  ;; Other ESC sequences (2 char)
                  (else (loop (+ i 2)))))
              (loop (+ i 1)))
            (begin
              (write-char ch out)
              (loop (+ i 1)))))))
    (get-output-string out)))

;;;============================================================================
;;; I/O
;;;============================================================================

(def (repl-send! rs input)
  "Send a line of input to the Jerboa REPL subprocess."
  (let ((out-port (cdr (repl-state-process rs))))
    (put-string out-port input)
    (put-char out-port #\newline)
    (flush-output-port out-port))
  ;; Add to history
  (set! (repl-state-history rs)
    (cons input (repl-state-history rs))))

(def (repl-read-available rs)
  "Read all available output from the Jerboa REPL subprocess (non-blocking).
   Strips ANSI escape codes. Returns a string, or #f if nothing available."
  (let ((in-port (car (repl-state-process rs))))
    (if (char-ready? in-port)
      (let ((out (open-output-string)))
        (let loop ()
          (when (char-ready? in-port)
            (let ((ch (read-char in-port)))
              (unless (eof-object? ch)
                (write-char ch out)
                (loop)))))
        (let ((s (strip-ansi (get-output-string out))))
          (if (string-empty? s) #f s)))
      #f)))

(def (repl-stop! rs)
  "Shut down the Jerboa REPL subprocess."
  (let ((in-port (car (repl-state-process rs)))
        (out-port (cdr (repl-state-process rs))))
    ;; Try graceful shutdown first
    (with-catch (lambda (_e) (void))
      (lambda ()
        (put-string out-port ",quit\n")
        (flush-output-port out-port)))
    (with-catch (lambda (_e) (void)) (lambda () (close-port out-port)))
    (with-catch (lambda (_e) (void)) (lambda () (close-port in-port)))))
