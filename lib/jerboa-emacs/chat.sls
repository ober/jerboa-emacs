#!chezscheme
;;; chat.sls — AI Chat mode: interact with Claude CLI from a buffer
;;;
;;; Ported from gerbil-emacs/chat.ss
;;; Spawns `claude -p` in print mode for each prompt and streams
;;; the response into the chat buffer.

(library (jerboa-emacs chat)
  (export chat-buffer?
          chat-state-map
          chat-state? chat-state-process chat-state-process-set!
          chat-state-prompt-pos chat-state-prompt-pos-set!
          chat-state-busy? chat-state-busy?-set!
          chat-state-continue? chat-state-continue?-set!
          chat-state-cwd
          make-chat-state
          chat-start!
          chat-send!
          chat-read-available
          chat-stop!
          chat-busy?)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std srfi srfi-13)
          (std misc process)
          (jerboa-emacs core))

  ;;;============================================================================
  ;;; Chat state
  ;;;============================================================================

  (def (chat-buffer? buf)
    (eq? (buffer-lexer-lang buf) 'chat))

  (def *chat-state* (make-hash-table-eq))
  (def (chat-state-map) *chat-state*)

  (defstruct chat-state (process prompt-pos busy? continue? cwd))

  ;;;============================================================================
  ;;; Chat operations
  ;;;============================================================================

  (def (chat-start! cwd)
    (make-chat-state #f 0 #f #f (or cwd (current-directory))))

  (def (chat-busy? cs)
    (chat-state-busy? cs))

  (def (chat-send! cs input)
    (when (and (not (chat-state-busy? cs))
               (> (string-length (string-trim input)) 0))
      (let* ((args (if (chat-state-continue? cs)
                     (list "claude" "-p" "--continue" "--output-format" "text"
                           "--no-session-persistence" input)
                     (list "claude" "-p" "--output-format" "text"
                           "--no-session-persistence" input)))
             (pp (open-process args)))
        ;; Close stdin immediately — claude -p reads prompt from args
        (let ((stdin (process-port-rec-stdin-port pp)))
          (when stdin (close-port stdin)))
        (chat-state-process-set! cs pp)
        (chat-state-busy?-set! cs #t)
        (chat-state-continue?-set! cs #t))))

  (def (chat-read-available cs)
    (let ((pp (chat-state-process cs)))
      (if (and pp (chat-state-busy? cs))
        (let ((stdout (process-port-rec-stdout-port pp)))
          (if (input-port-ready? stdout)
            (let ((out (open-output-string)))
              (let loop ()
                (when (input-port-ready? stdout)
                  (let ((ch (read-char stdout)))
                    (if (eof-object? ch)
                      ;; Process finished
                      (begin
                        (with-catch void (lambda () (close-port stdout)))
                        (chat-state-process-set! cs #f)
                        (chat-state-busy?-set! cs #f))
                      (begin
                        (write-char ch out)
                        (loop))))))
              (let ((s (get-output-string out)))
                (if (and (string=? s "") (not (chat-state-busy? cs)))
                  'done
                  (if (string=? s "")
                    #f
                    (if (chat-state-busy? cs)
                      s
                      (cons s 'done))))))
            #f))
        #f)))

  (def (chat-stop! cs)
    (let ((pp (chat-state-process cs)))
      (when pp
        (with-catch void
          (lambda ()
            (let ((stdin (process-port-rec-stdin-port pp)))
              (when stdin (close-port stdin)))))
        (with-catch void
          (lambda ()
            (let ((stdout (process-port-rec-stdout-port pp)))
              (when stdout (close-port stdout)))))
        (chat-state-process-set! cs #f)
        (chat-state-busy?-set! cs #f))))

  ) ;; end library
