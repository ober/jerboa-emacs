;;; -*- Gerbil -*-
;;; AI Chat mode: interact with Claude CLI from a buffer
;;;
;;; Spawns `claude -p` in print mode for each prompt and streams
;;; the response into the chat buffer. Uses --continue for follow-up
;;; messages to maintain conversation context.

(export chat-buffer?
        *chat-state*
        (struct-out chat-state)
        chat-start!
        chat-send!
        chat-read-available
        chat-stop!
        chat-busy?)

(import :std/sugar
        :std/srfi/13
        :jerboa-emacs/core)

;;;============================================================================
;;; Chat state
;;;============================================================================

(def (chat-buffer? buf)
  "Check if this buffer is an AI chat buffer."
  (eq? (buffer-lexer-lang buf) 'chat))

;; Maps chat buffers to their chat-state structs
(def *chat-state* (make-hash-table-eq))

(defstruct chat-state
  (process      ; cons of (in-port . out-port) or #f when idle
   prompt-pos   ; integer: byte position where current input starts
   busy?        ; #t when waiting for AI response
   continue?    ; #t after first message (use --continue)
   cwd)         ; working directory for claude CLI context
  transparent: #t)

;;;============================================================================
;;; Chat operations
;;;============================================================================

(def (chat-start! cwd)
  "Create a new chat state (no subprocess yet — spawned per prompt)."
  (make-chat-state #f 0 #f #f (or cwd (current-directory))))

(def (chat-busy? cs)
  "Check if chat is waiting for a response."
  (chat-state-busy? cs))

(def (chat-send! cs input)
  "Send a prompt to Claude CLI. Spawns claude -p as a subprocess."
  (when (and (not (chat-state-busy? cs))
             (> (string-length (string-trim input)) 0))
    (let* ((args (if (chat-state-continue? cs)
                   ["-p" "--continue" "--output-format" "text"
                    "--no-session-persistence" input]
                   ["-p" "--output-format" "text"
                    "--no-session-persistence" input]))
           (cmd (string-append
                  "cd \"" (chat-state-cwd cs) "\" && claude "
                  (string-join args " ")))
           (in-port (let-values (((in-port out-port err-port pid)
                                  (open-process-ports cmd (buffer-mode none) (native-transcoder))))
                      (close-port out-port)
                      (close-port err-port)
                      in-port)))
      (set! (chat-state-process cs) in-port)
      (set! (chat-state-busy? cs) #t)
      (set! (chat-state-continue? cs) #t))))

(def (chat-read-available cs)
  "Read all available output from the claude process (non-blocking).
   Returns a string chunk, 'done if process finished, or #f if nothing available."
  (let ((in-port (chat-state-process cs)))
    (if (and in-port (chat-state-busy? cs))
      (if (char-ready? in-port)
        (let ((out (open-output-string)))
          (let loop ()
            (when (char-ready? in-port)
              (let ((ch (read-char in-port)))
                (if (eof-object? ch)
                  ;; Process finished
                  (begin
                    (with-catch (lambda (_e) (void)) (lambda () (close-port in-port)))
                    (set! (chat-state-process cs) #f)
                    (set! (chat-state-busy? cs) #f))
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
                  ;; Got final chunk + EOF in same read
                  (cons s 'done))))))
        #f)
      #f)))

(def (chat-stop! cs)
  "Stop any running claude process."
  (let ((in-port (chat-state-process cs)))
    (when in-port
      (with-catch (lambda (_e) (void)) (lambda () (close-port in-port)))
      (set! (chat-state-process cs) #f)
      (set! (chat-state-busy? cs) #f))))
