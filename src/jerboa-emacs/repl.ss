;;; -*- Gerbil -*-
;;; REPL subprocess management for jemacs
;;;
;;; Manages a gxi subprocess: spawn, send input, read output, stop.
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

(def repl-prompt "gerbil> ")

;;;============================================================================
;;; Lifecycle
;;;============================================================================

(def (repl-start!)
  "Spawn a gxi subprocess and return a repl-state."
  ;; Chez open-process-ports returns: (write-stdin read-stdout read-stderr pid)
  (let-values (((p-stdin p-stdout p-stderr pid)
                (open-process-ports "gxi" (buffer-mode none) (native-transcoder))))
    (close-port p-stderr)
    ;; Store as (read-port . write-port) per struct contract
    (make-repl-state (cons p-stdout p-stdin) 0 '())))

(def (repl-send! rs input)
  "Send a line of input to the gxi process."
  (let ((out-port (cdr (repl-state-process rs))))
    (put-string out-port input)
    (put-char out-port #\newline)
    (flush-output-port out-port))
  ;; Add to history
  (set! (repl-state-history rs)
    (cons input (repl-state-history rs))))

(def (repl-read-available rs)
  "Read all available output from the gxi process (non-blocking).
   Returns a string, or #f if nothing available."
  (let ((in-port (car (repl-state-process rs))))
    (if (char-ready? in-port)
      (let ((out (open-output-string)))
        (let loop ()
          (when (char-ready? in-port)
            (let ((ch (read-char in-port)))
              (unless (eof-object? ch)
                (write-char ch out)
                (loop)))))
        (let ((s (get-output-string out)))
          (if (string-empty? s) #f s)))
      #f)))

(def (repl-stop! rs)
  "Shut down the gxi subprocess."
  (let ((in-port (car (repl-state-process rs)))
        (out-port (cdr (repl-state-process rs))))
    (with-catch (lambda (_e) (void)) (lambda () (close-port out-port)))
    (with-catch (lambda (_e) (void)) (lambda () (close-port in-port)))))
