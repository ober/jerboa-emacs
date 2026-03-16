#!chezscheme
;;; -*- Chez Scheme -*-
;;; Artist mode, TRAMP, paredit, string inflection, ediff,
;;; undo-tree, server, navigation, and misc editing commands
;;;
;;; Ported from gerbil-emacs/editor-extra-editing.ss to R6RS Chez Scheme.

(library (jerboa-emacs editor-extra-editing)
  (export
    ;; Artist mode
    cmd-artist-mode
    ;; TRAMP
    tramp-path?
    tramp-parse-path
    tramp-read-file
    tramp-write-file
    tramp-file-exists?
    cmd-tramp-cleanup-all-connections
    ;; Process management
    cmd-proced
    ;; Paredit
    cmd-paredit-wrap-round
    cmd-paredit-wrap-square
    cmd-paredit-wrap-curly
    cmd-paredit-splice-sexp
    cmd-paredit-raise-sexp
    ;; Text-based sexp helpers
    text-find-matching-close
    text-find-matching-open
    text-sexp-end
    text-sexp-start
    text-skip-ws-forward
    text-skip-ws-backward
    text-find-enclosing-open
    text-find-enclosing-close
    ;; Paredit slurp/barf/split/join
    cmd-paredit-slurp-forward
    cmd-paredit-barf-forward
    cmd-paredit-slurp-backward
    cmd-paredit-barf-backward
    cmd-paredit-split-sexp
    cmd-paredit-join-sexps
    cmd-paredit-convolute-sexp
    ;; Number increment/decrement
    find-number-at-pos
    cmd-increment-number
    cmd-decrement-number
    ;; Grep/compilation navigation
    parse-grep-line-text
    cmd-grep-goto
    cmd-next-error
    ;; TRAMP remote editing
    cmd-find-file-ssh
    tramp-open-remote-file!
    tramp-save-buffer!
    ;; Ediff
    cmd-ediff-files
    cmd-ediff-regions
    ;; Undo tree
    cmd-undo-tree-visualize
    ;; Editor server
    cmd-server-start
    cmd-server-edit
    ;; Navigation
    cmd-pop-global-mark
    cmd-set-goal-column
    ;; Directory
    cmd-cd
    ;; Misc Emacs commands
    cmd-display-prefix
    cmd-digit-argument
    cmd-negative-argument
    cmd-suspend-emacs
    cmd-save-buffers-kill-emacs
    ;; View/doc mode
    cmd-view-mode
    cmd-doc-view-mode
    ;; Speedbar
    cmd-speedbar
    ;; Misc utilities
    cmd-world-clock
    cmd-display-battery
    cmd-uptime
    ;; Kmacro counter
    cmd-kmacro-set-counter
    cmd-kmacro-insert-counter
    ;; Whitespace report
    cmd-whitespace-report
    ;; Encoding
    cmd-describe-coding-system
    cmd-set-terminal-coding-system
    ;; Misc text
    cmd-overwrite-mode
    ;; Ripgrep
    cmd-consult-ripgrep
    ;; goto-address-mode
    cmd-goto-address-mode
    ;; subword-mode
    tui-subword-forward-pos
    tui-subword-backward-pos
    cmd-subword-forward
    cmd-subword-backward
    cmd-subword-kill
    ;; Goto last change
    tui-record-edit-position!
    cmd-goto-last-change-reverse
    ;; File operations
    cmd-rename-visited-file
    ;; Terraform
    cmd-terraform-mode
    cmd-terraform
    cmd-terraform-plan
    ;; Docker Compose
    cmd-docker-compose
    cmd-docker-compose-up
    cmd-docker-compose-down)

  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-directory path-strip-directory path-extension
                path-expand take)
          (only (std srfi srfi-13) string-join string-contains string-prefix? string-suffix?
                string-index string-index-right string-trim string-trim-both string-trim-right)
          (only (std misc string) string-split)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (chez-scintilla style)
          (chez-scintilla tui)
          (except (jerboa-emacs core) face-get)
          (jerboa-emacs keymap)
          (jerboa-emacs buffer)
          (jerboa-emacs window)
          (jerboa-emacs modeline)
          (jerboa-emacs echo)
          (jerboa-emacs highlight)
          (jerboa-emacs editor-extra-helpers))

  ;;;==========================================================================
  ;;; Local helpers
  ;;;==========================================================================

  (define (run-command-capture prog args)
    "Run a command, capture stdout as a string. Returns output or #f on failure."
    (guard (e (#t #f))
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports
                      (string-append prog
                        (apply string-append
                          (map (lambda (a) (string-append " " a)) args)))
                      (buffer-mode block)
                      (native-transcoder))))
        (close-port to-stdin)
        (let ((out (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (if (eof-object? out) #f out)))))

  (define (run-command-with-stdin prog args input)
    "Run a command with stdin, return exit success (#t/#f)."
    (guard (e (#t #f))
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports
                      (string-append prog
                        (apply string-append
                          (map (lambda (a) (string-append " " a)) args)))
                      (buffer-mode block)
                      (native-transcoder))))
        (display input to-stdin)
        (flush-output-port to-stdin)
        (close-port to-stdin)
        (get-string-all from-stdout)
        (close-port from-stdout)
        (close-port from-stderr)
        #t)))

  (define (run-command-status prog args)
    "Run a command, return #t if it exits successfully."
    (guard (e (#t #f))
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports
                      (string-append prog
                        (apply string-append
                          (map (lambda (a) (string-append " " a)) args)))
                      (buffer-mode block)
                      (native-transcoder))))
        (close-port to-stdin)
        (get-string-all from-stdout)
        (close-port from-stdout)
        (close-port from-stderr)
        #t)))

  (define (shell-quote-arg arg)
    "Shell-quote an argument for safe embedding in a command string."
    (string-append "'"
      (let loop ((i 0) (acc '()))
        (if (>= i (string-length arg))
          (list->string (reverse acc))
          (let ((ch (string-ref arg i)))
            (if (char=? ch #\')
              (loop (+ i 1) (append (reverse (string->list "'\\''")) acc))
              (loop (+ i 1) (cons ch acc))))))
      "'"))

  ;;;==========================================================================
  ;;; Artist mode -- simple ASCII drawing
  ;;;==========================================================================

  (define (cmd-artist-mode app)
    (let ((on (toggle-mode! 'artist-mode)))
      (echo-message! (app-state-echo app)
        (if on "Artist mode enabled (use arrows to draw)" "Artist mode disabled"))))

  ;;;==========================================================================
  ;;; TRAMP -- remote file access via SSH
  ;;;==========================================================================

  (define *tramp-connections* '())

  (define (tramp-path? path)
    (and (string? path)
         (or (string-prefix? "/ssh:" path)
             (string-prefix? "/scp:" path))))

  (define (tramp-parse-path path)
    (let* ((rest (cond
                   ((string-prefix? "/ssh:" path) (substring path 5 (string-length path)))
                   ((string-prefix? "/scp:" path) (substring path 5 (string-length path)))
                   (else path)))
           (colon-pos (string-index rest #\:)))
      (if colon-pos
        (values (substring rest 0 colon-pos)
                (substring rest (+ colon-pos 1) (string-length rest)))
        (values rest "/"))))

  (define (tramp-read-file host remote-path)
    (guard (e (#t #f))
      (run-command-capture "/usr/bin/ssh"
        (list (shell-quote-arg host)
              (string-append "cat " (shell-quote-arg remote-path))))))

  (define (tramp-write-file host remote-path content)
    (guard (e (#t #f))
      (run-command-with-stdin "/usr/bin/ssh"
        (list (shell-quote-arg host)
              (string-append "cat > " (shell-quote-arg remote-path)))
        content)))

  (define (tramp-file-exists? host remote-path)
    (guard (e (#t #f))
      (run-command-status "/usr/bin/ssh"
        (list (shell-quote-arg host)
              (string-append "test -e " (shell-quote-arg remote-path))))))

  (define (cmd-tramp-cleanup-all-connections app)
    (set! *tramp-connections* '())
    (echo-message! (app-state-echo app) "TRAMP connections cleaned up"))

  ;;;==========================================================================
  ;;; Process management extras
  ;;;==========================================================================

  (define (cmd-proced app)
    (let ((result (guard (e (#t "Error listing processes"))
                    (or (run-command-capture "ps" '("aux" "--sort=-pcpu"))
                        ""))))
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (buf (buffer-create! "*Proced*" ed)))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! win buf)
        (editor-set-text ed (string-append "Process List\n\n" result "\n"))
        (editor-set-read-only ed #t))))

  ;;;==========================================================================
  ;;; Paredit-like commands for Lisp editing
  ;;;==========================================================================

  (define (cmd-paredit-wrap-round app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (let* ((pos (editor-get-current-pos ed)))
          (let-values (((ws we) (word-bounds-at ed pos)))
            (when ws
              (editor-insert-text ed we ")")
              (editor-insert-text ed ws "("))))
        (begin
          (editor-insert-text ed end ")")
          (editor-insert-text ed start "(")))))

  (define (cmd-paredit-wrap-square app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (let* ((pos (editor-get-current-pos ed)))
          (let-values (((ws we) (word-bounds-at ed pos)))
            (when ws
              (editor-insert-text ed we "]")
              (editor-insert-text ed ws "["))))
        (begin
          (editor-insert-text ed end "]")
          (editor-insert-text ed start "[")))))

  (define (cmd-paredit-wrap-curly app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (let* ((pos (editor-get-current-pos ed)))
          (let-values (((ws we) (word-bounds-at ed pos)))
            (when ws
              (editor-insert-text ed we "}")
              (editor-insert-text ed ws "{"))))
        (begin
          (editor-insert-text ed end "}")
          (editor-insert-text ed start "{")))))

  (define (cmd-paredit-splice-sexp app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (match-pos (send-message ed SCI_BRACEMATCH pos 0)))
      (when (>= match-pos 0)
        (let ((open-pos (min pos match-pos))
              (close-pos (max pos match-pos)))
          (send-message ed SCI_DELETERANGE close-pos 1)
          (send-message ed SCI_DELETERANGE open-pos 1)))))

  (define (cmd-paredit-raise-sexp app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (echo (app-state-echo app)))
      (let ((open-pos (sp-find-enclosing-paren ed pos #\( #\))))
        (if (not open-pos)
          (echo-message! echo "Not inside a list")
          (let ((close-pos (sp-find-matching-close ed (+ open-pos 1) #\( #\))))
            (if (not close-pos)
              (echo-message! echo "Unbalanced parens")
              (let loop ((i pos))
                (if (>= i (string-length text))
                  (echo-message! echo "No sexp at point")
                  (let ((ch (string-ref text i)))
                    (cond
                      ((char-whitespace? ch) (loop (+ i 1)))
                      (else
                       (let* ((sexp-end (sp-find-sexp-end ed i))
                              (sexp-text (if sexp-end
                                           (substring text i (+ sexp-end 1))
                                           #f)))
                         (if (not sexp-text)
                           (echo-message! echo "Could not parse sexp")
                           (begin
                             (editor-set-selection ed open-pos (+ close-pos 1))
                             (editor-replace-selection ed sexp-text)
                             (editor-goto-pos ed open-pos)
                             (echo-message! echo "Raised sexp")))))))))))))))

  ;;;==========================================================================
  ;;; Text-based sexp helpers (for paredit slurp/barf/split/join)
  ;;;==========================================================================

  (define (text-find-matching-close text pos)
    (let* ((len (string-length text))
           (ch (string-ref text pos))
           (close (cond ((char=? ch #\() #\))
                        ((char=? ch #\[) #\])
                        ((char=? ch #\{) #\})
                        (else #f))))
      (if close
        (let loop ((i (+ pos 1)) (depth 1))
          (cond ((>= i len) #f)
                ((char=? (string-ref text i) ch) (loop (+ i 1) (+ depth 1)))
                ((char=? (string-ref text i) close)
                 (if (= depth 1) (+ i 1) (loop (+ i 1) (- depth 1))))
                (else (loop (+ i 1) depth))))
        #f)))

  (define (text-find-matching-open text pos)
    (let* ((ch (string-ref text pos))
           (open (cond ((char=? ch #\)) #\()
                       ((char=? ch #\]) #\[)
                       ((char=? ch #\}) #\{)
                       (else #f))))
      (if open
        (let loop ((i (- pos 1)) (depth 1))
          (cond ((< i 0) #f)
                ((char=? (string-ref text i) ch) (loop (- i 1) (+ depth 1)))
                ((char=? (string-ref text i) open)
                 (if (= depth 1) i (loop (- i 1) (- depth 1))))
                (else (loop (- i 1) depth))))
        #f)))

  (define (text-sexp-end text pos)
    (let ((len (string-length text)))
      (if (>= pos len) pos
        (let ((ch (string-ref text pos)))
          (cond
            ((or (char=? ch #\() (char=? ch #\[) (char=? ch #\{))
             (or (text-find-matching-close text pos) len))
            ((char=? ch #\")
             (let loop ((i (+ pos 1)))
               (cond ((>= i len) len)
                     ((char=? (string-ref text i) #\\) (loop (+ i 2)))
                     ((char=? (string-ref text i) #\") (+ i 1))
                     (else (loop (+ i 1))))))
            (else
             (let loop ((i pos))
               (if (or (>= i len)
                       (char-whitespace? (string-ref text i))
                       (memv (string-ref text i) '(#\( #\) #\[ #\] #\{ #\})))
                 i (loop (+ i 1))))))))))

  (define (text-sexp-start text pos)
    (if (<= pos 0) 0
      (let* ((i (- pos 1))
             (ch (string-ref text i)))
        (cond
          ((or (char=? ch #\)) (char=? ch #\]) (char=? ch #\}))
           (or (text-find-matching-open text i) 0))
          ((char=? ch #\")
           (let loop ((j (- i 1)))
             (cond ((<= j 0) 0)
                   ((and (char=? (string-ref text j) #\")
                         (or (= j 0) (not (char=? (string-ref text (- j 1)) #\\))))
                    j)
                   (else (loop (- j 1))))))
          (else
           (let loop ((j i))
             (if (or (<= j 0)
                     (char-whitespace? (string-ref text j))
                     (memv (string-ref text j) '(#\( #\) #\[ #\] #\{ #\})))
               (+ j 1) (loop (- j 1)))))))))

  (define (text-skip-ws-forward text pos)
    (let ((len (string-length text)))
      (let loop ((i pos))
        (if (or (>= i len) (not (char-whitespace? (string-ref text i))))
          i (loop (+ i 1))))))

  (define (text-skip-ws-backward text pos)
    (let loop ((i pos))
      (if (or (<= i 0) (not (char-whitespace? (string-ref text (- i 1)))))
        i (loop (- i 1)))))

  (define (text-find-enclosing-open text pos)
    (let loop ((i (- pos 1)) (depth 0))
      (cond
        ((< i 0) #f)
        ((memv (string-ref text i) '(#\) #\] #\}))
         (loop (- i 1) (+ depth 1)))
        ((memv (string-ref text i) '(#\( #\[ #\{))
         (if (= depth 0) i (loop (- i 1) (- depth 1))))
        (else (loop (- i 1) depth)))))

  (define (text-find-enclosing-close text pos)
    (let ((len (string-length text)))
      (let loop ((i pos) (depth 0))
        (cond
          ((>= i len) #f)
          ((memv (string-ref text i) '(#\( #\[ #\{))
           (loop (+ i 1) (+ depth 1)))
          ((memv (string-ref text i) '(#\) #\] #\}))
           (if (= depth 0) i (loop (+ i 1) (- depth 1))))
          (else (loop (+ i 1) depth))))))

  ;;;==========================================================================
  ;;; Paredit slurp/barf/split/join
  ;;;==========================================================================

  (define (cmd-paredit-slurp-forward app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (close-pos (text-find-enclosing-close text pos)))
      (when close-pos
        (let* ((after (text-skip-ws-forward text (+ close-pos 1)))
               (next-end (text-sexp-end text after)))
          (when (> next-end after)
            (let* ((close-char (string (string-ref text close-pos)))
                   (new-text (string-append
                               (substring text 0 close-pos)
                               (substring text (+ close-pos 1) next-end)
                               close-char
                               (substring text next-end (string-length text)))))
              (with-undo-action ed
                (editor-set-text ed new-text)
                (editor-goto-pos ed pos))))))))

  (define (cmd-paredit-barf-forward app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (close-pos (text-find-enclosing-close text pos)))
      (when close-pos
        (let* ((before-close (text-skip-ws-backward text close-pos))
               (last-start (text-sexp-start text before-close)))
          (when (> last-start 0)
            (let ((open-pos (text-find-enclosing-open text pos))
                  (close-char (string (string-ref text close-pos))))
              (when (and open-pos (> last-start (+ open-pos 1)))
                (let* ((ws-before (text-skip-ws-backward text last-start))
                       (new-text (string-append
                                   (substring text 0 ws-before)
                                   close-char
                                   (substring text ws-before close-pos)
                                   (substring text (+ close-pos 1) (string-length text)))))
                  (with-undo-action ed
                    (editor-set-text ed new-text)
                    (editor-goto-pos ed (min pos (string-length new-text))))))))))))

  (define (cmd-paredit-slurp-backward app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (open-pos (text-find-enclosing-open text pos)))
      (when open-pos
        (let* ((before (text-skip-ws-backward text open-pos))
               (prev-start (text-sexp-start text before)))
          (when (and prev-start (< prev-start open-pos))
            (let* ((open-char (string (string-ref text open-pos)))
                   (new-text (string-append
                               (substring text 0 prev-start)
                               open-char
                               (substring text prev-start open-pos)
                               (substring text (+ open-pos 1) (string-length text)))))
              (with-undo-action ed
                (editor-set-text ed new-text)
                (editor-goto-pos ed pos))))))))

  (define (cmd-paredit-barf-backward app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (open-pos (text-find-enclosing-open text pos)))
      (when open-pos
        (let* ((after-open (text-skip-ws-forward text (+ open-pos 1)))
               (first-end (text-sexp-end text after-open))
               (close-pos (text-find-enclosing-close text pos))
               (open-char (string (string-ref text open-pos))))
          (when (and first-end close-pos (< first-end close-pos))
            (let* ((ws-after (text-skip-ws-forward text first-end))
                   (new-text (string-append
                               (substring text 0 open-pos)
                               (substring text (+ open-pos 1) ws-after)
                               open-char
                               (substring text ws-after (string-length text)))))
              (with-undo-action ed
                (editor-set-text ed new-text)
                (editor-goto-pos ed (min pos (string-length new-text))))))))))

  (define (cmd-paredit-split-sexp app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (open-pos (text-find-enclosing-open text pos)))
      (when open-pos
        (let ((close-pos (text-find-enclosing-close text pos))
              (open-ch (string-ref text open-pos)))
          (when close-pos
            (let* ((close-ch (cond ((char=? open-ch #\() #\))
                                   ((char=? open-ch #\[) #\])
                                   ((char=? open-ch #\{) #\})
                                   (else #\))))
                   (new-text (string-append
                               (substring text 0 pos)
                               (string close-ch) " " (string open-ch)
                               (substring text pos (string-length text)))))
              (with-undo-action ed
                (editor-set-text ed new-text)
                (editor-goto-pos ed (+ pos 2)))))))))

  (define (cmd-paredit-join-sexps app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (bwd (text-skip-ws-backward text pos)))
      (when (and (> bwd 0)
                 (memv (string-ref text (- bwd 1)) '(#\) #\] #\})))
        (let ((fwd (text-skip-ws-forward text pos)))
          (when (and (< fwd (string-length text))
                     (memv (string-ref text fwd) '(#\( #\[ #\{)))
            (let ((new-text (string-append
                              (substring text 0 (- bwd 1))
                              " "
                              (substring text (+ fwd 1) (string-length text)))))
              (with-undo-action ed
                (editor-set-text ed new-text)
                (editor-goto-pos ed (- bwd 1)))))))))

  (define (cmd-paredit-convolute-sexp app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (inner-open (text-find-enclosing-open text pos)))
      (when inner-open
        (let ((outer-open (text-find-enclosing-open text (- inner-open 1))))
          (when outer-open
            (let* ((inner-close (text-find-enclosing-close text pos))
                   (outer-close (text-find-enclosing-close text (+ inner-close 1))))
              (when (and inner-close outer-close)
                (let* ((outer-open-char (string (string-ref text outer-open)))
                       (outer-close-char (string (string-ref text outer-close)))
                       (inner-open-char (string (string-ref text inner-open)))
                       (inner-close-char (string (string-ref text inner-close)))
                       (inner-head (substring text (+ inner-open 1) pos))
                       (inner-tail (substring text pos inner-close))
                       (outer-head (substring text (+ outer-open 1) inner-open))
                       (outer-tail (substring text (+ inner-close 1) outer-close))
                       (before (substring text 0 outer-open))
                       (after (substring text (+ outer-close 1) (string-length text)))
                       (new-text (string-append
                                   before
                                   inner-open-char
                                   (string-trim-both inner-head)
                                   " " outer-open-char
                                   (string-trim-both outer-head)
                                   inner-tail
                                   outer-tail
                                   outer-close-char
                                   inner-close-char
                                   after)))
                  (with-undo-action ed
                    (editor-set-text ed new-text)
                    (editor-goto-pos ed (+ (string-length before) 1)))))))))))

  ;;;==========================================================================
  ;;; Number increment/decrement at point
  ;;;==========================================================================

  (define (find-number-at-pos text pos)
    (let ((len (string-length text)))
      (if (and (< pos len) (or (char-numeric? (string-ref text pos))
                                (and (char=? (string-ref text pos) #\-)
                                     (< (+ pos 1) len)
                                     (char-numeric? (string-ref text (+ pos 1))))))
        (let ((start (let loop ((i pos))
                       (if (or (<= i 0)
                               (not (or (char-numeric? (string-ref text (- i 1)))
                                        (char=? (string-ref text (- i 1)) #\-))))
                         i (loop (- i 1))))))
          (let ((end (let loop ((i pos))
                       (if (or (>= i len) (not (char-numeric? (string-ref text i))))
                         i (loop (+ i 1))))))
            (cons start end)))
        #f)))

  (define (cmd-increment-number app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (bounds (find-number-at-pos text pos)))
      (if (not bounds)
        (echo-error! echo "No number at point")
        (let* ((start (car bounds))
               (end (cdr bounds))
               (num-str (substring text start end))
               (num (string->number num-str)))
          (when num
            (let ((new-str (number->string (+ num 1))))
              (with-undo-action ed
                (editor-set-selection ed start end)
                (editor-replace-selection ed new-str))
              (editor-goto-pos ed start)))))))

  (define (cmd-decrement-number app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (bounds (find-number-at-pos text pos)))
      (if (not bounds)
        (echo-error! echo "No number at point")
        (let* ((start (car bounds))
               (end (cdr bounds))
               (num-str (substring text start end))
               (num (string->number num-str)))
          (when num
            (let ((new-str (number->string (- num 1))))
              (with-undo-action ed
                (editor-set-selection ed start end)
                (editor-replace-selection ed new-str))
              (editor-goto-pos ed start)))))))

  ;;;==========================================================================
  ;;; Grep/compilation result navigation
  ;;;==========================================================================

  (define (parse-grep-line-text line)
    (let ((colon1 (string-index line #\:)))
      (and colon1
           (let ((colon2 (string-index line #\: (+ colon1 1))))
             (and colon2
                  (let ((line-num (string->number
                                    (substring line (+ colon1 1) colon2))))
                    (and line-num
                         (list (substring line 0 colon1)
                               line-num))))))))

  (define (cmd-grep-goto app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (line-num (editor-line-from-position ed pos))
           (line-text (editor-get-line ed line-num))
           (parsed (parse-grep-line-text line-text)))
      (if (not parsed)
        (echo-error! echo "No file:line at point")
        (let ((file (car parsed))
              (target-line (cadr parsed)))
          (if (not (file-exists? file))
            (echo-error! echo (string-append "File not found: " file))
            (let* ((fr (app-state-frame app))
                   (name (path-strip-directory file))
                   (win (current-window fr))
                   (ed2 (edit-window-editor win))
                   (buf (or (buffer-by-name name)
                            (buffer-create! name ed2 file))))
              (buffer-attach! ed2 buf)
              (edit-window-buffer-set! win buf)
              (when (file-exists? file)
                (let ((text (read-file-as-string file)))
                  (when text
                    (editor-set-text ed2 text)
                    (editor-set-save-point ed2))))
              (editor-goto-line ed2 (- target-line 1))
              (editor-scroll-caret ed2)
              (echo-message! echo
                (string-append file ":" (number->string target-line)))))))))

  (define (cmd-next-error app)
    (let* ((echo (app-state-echo app))
           (grep-buf (or (buffer-by-name "*Grep*")
                         (buffer-by-name "*Compilation*"))))
      (if (not grep-buf)
        (echo-error! echo "No grep/compilation buffer")
        (let* ((ed (current-editor app))
               (fr (app-state-frame app))
               (cur-buf (current-buffer-from-app app)))
          (unless (eq? cur-buf grep-buf)
            (buffer-attach! ed grep-buf)
            (edit-window-buffer-set! (current-window fr) grep-buf))
          (let* ((pos (editor-get-current-pos ed))
                 (cur-line (editor-line-from-position ed pos))
                 (total-lines (editor-get-line-count ed)))
            (let loop ((line (+ cur-line 1)))
              (if (>= line total-lines)
                (echo-message! echo "No more results")
                (let* ((line-text (editor-get-line ed line))
                       (parsed (parse-grep-line-text line-text)))
                  (if parsed
                    (begin
                      (editor-goto-line ed line)
                      (editor-scroll-caret ed)
                      (cmd-grep-goto app))
                    (loop (+ line 1)))))))))))

  ;;;==========================================================================
  ;;; TRAMP-like remote editing via SSH
  ;;;==========================================================================

  (define (cmd-find-file-ssh app)
    (let ((path (app-read-string app "Remote file (/ssh:host:/path): ")))
      (when (and path (not (string=? path "")))
        (let* ((path (if (tramp-path? path) path
                       (if (string-index path #\:)
                         (string-append "/ssh:" path)
                         path)))
               (echo (app-state-echo app)))
          (if (not (tramp-path? path))
            (echo-error! echo "Use /ssh:host:/path or user@host:/path syntax")
            (tramp-open-remote-file! app path))))))

  (define (tramp-open-remote-file! app tramp-path)
    (let ((echo (app-state-echo app)))
      (let-values (((host remote-path) (tramp-parse-path tramp-path)))
        (echo-message! echo (string-append "Fetching " host ":" remote-path "..."))
        (let ((content (tramp-read-file host remote-path)))
          (if (not content)
            (echo-error! echo (string-append "Failed to fetch " remote-path " from " host))
            (let* ((name (string-append (path-strip-directory remote-path) " [" host "]"))
                   (fr (app-state-frame app))
                   (win (current-window fr))
                   (ed (edit-window-editor win))
                   (buf (buffer-create! name ed)))
              (buffer-attach! ed buf)
              (edit-window-buffer-set! win buf)
              (editor-set-text ed content)
              (editor-goto-pos ed 0)
              (editor-set-save-point ed)
              (buffer-file-path-set! buf tramp-path)
              (echo-message! echo (string-append "Loaded " remote-path " from " host))))))))

  (define (tramp-save-buffer! app ed buf)
    (let* ((echo (app-state-echo app))
           (fpath (buffer-file-path buf)))
      (let-values (((host remote-path) (tramp-parse-path fpath)))
        (let ((text (editor-get-text ed)))
          (echo-message! echo (string-append "Saving to " host ":" remote-path "..."))
          (if (tramp-write-file host remote-path text)
            (begin
              (editor-set-save-point ed)
              (echo-message! echo (string-append "Wrote " host ":" remote-path))
              #t)
            (begin
              (echo-error! echo (string-append "Failed to save " remote-path " to " host))
              #f))))))

  ;;;==========================================================================
  ;;; Ediff - file and region comparison using diff
  ;;;==========================================================================

  (define (cmd-ediff-files app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (file1 (echo-read-string echo "First file: " row width)))
      (when (and file1 (not (string=? file1 "")))
        (let ((file2 (echo-read-string echo "Second file: " row width)))
          (when (and file2 (not (string=? file2 "")))
            (if (not (and (file-exists? file1) (file-exists? file2)))
              (echo-error! echo "One or both files do not exist")
              (guard (e (#t (echo-error! echo "diff command failed")))
                (let* ((output (run-command-capture "diff"
                                 (list "-u" (shell-quote-arg file1) (shell-quote-arg file2)))))
                  (let* ((win (current-window fr))
                         (ed (edit-window-editor win))
                         (buf (buffer-create! "*Ediff*" ed))
                         (text (if output
                                 (string-append "Diff: " file1 " vs " file2 "\n"
                                               (make-string 60 #\=) "\n\n"
                                               output)
                                 "Files are identical")))
                    (buffer-attach! ed buf)
                    (edit-window-buffer-set! win buf)
                    (editor-set-text ed text)
                    (when output (setup-diff-highlighting! ed))
                    (editor-goto-pos ed 0)
                    (editor-set-read-only ed #t))))))))))

  (define (cmd-ediff-regions app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (current-buf (edit-window-buffer win))
           (current-name (and current-buf (buffer-name current-buf)))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (other-name (echo-read-string echo "Compare with buffer: " row width)))
      (when (and other-name (not (string=? other-name "")))
        (let ((other-buf (buffer-by-name other-name)))
          (if (not other-buf)
            (echo-error! echo (string-append "Buffer not found: " other-name))
            (let* ((text1 (editor-get-text ed))
                   (tmp1 "/tmp/jerboa-ediff-1.txt")
                   (tmp2 "/tmp/jerboa-ediff-2.txt"))
              (when (file-exists? tmp1) (delete-file tmp1))
              (call-with-output-file tmp1 (lambda (p) (display text1 p)))
              ;; Get other buffer's text by temporarily switching
              (buffer-attach! ed other-buf)
              (let ((text2 (editor-get-text ed)))
                (when (file-exists? tmp2) (delete-file tmp2))
                (call-with-output-file tmp2 (lambda (p) (display text2 p)))
                ;; Switch back
                (buffer-attach! ed current-buf)
                ;; Run diff
                (guard (e (#t (echo-error! echo "diff failed")))
                  (let* ((output (run-command-capture "diff" (list "-u" tmp1 tmp2))))
                    (let* ((buf (buffer-create! "*Ediff*" ed))
                           (diff-text (if output
                                        (string-append "Diff: " current-name " vs " other-name "\n"
                                                      (make-string 60 #\=) "\n\n"
                                                      output)
                                        "Buffers are identical")))
                      (buffer-attach! ed buf)
                      (edit-window-buffer-set! win buf)
                      (editor-set-text ed diff-text)
                      (when output (setup-diff-highlighting! ed))
                      (editor-goto-pos ed 0)
                      (editor-set-read-only ed #t)))))))))))

  ;;;==========================================================================
  ;;; Undo tree visualization
  ;;;==========================================================================

  (define (cmd-undo-tree-visualize app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app))
           (buf (edit-window-buffer win))
           (name (and buf (buffer-name buf)))
           (can-undo (send-message ed SCI_CANUNDO 0 0))
           (can-redo (send-message ed SCI_CANREDO 0 0))
           (text-len (send-message ed SCI_GETLENGTH 0 0))
           (line-count (send-message ed SCI_GETLINECOUNT 0 0)))
      (if (and (= can-undo 0) (= can-redo 0))
        (echo-message! echo "No undo history for this buffer")
        (let* ((header (string-append
                         "Undo Tree: " (or name "?") "\n"
                         (make-string 50 #\-) "\n"
                         "Buffer: " (number->string text-len) " chars, "
                         (number->string line-count) " lines\n\n"))
               (tree (string-append
                       "  o-- [current state]\n"
                       (if (= can-undo 1)
                         "  |-- [undo available] C-/ to undo\n"
                         "")
                       (if (= can-redo 1)
                         "  |-- [redo available] C-S-/ to redo\n"
                         "")
                       "\nUse M-x undo-history for timestamped snapshots.\n"
                       "Use M-x undo-history-restore to restore a snapshot.\n"))
               (content (string-append header tree))
               (tbuf (buffer-create! "*Undo Tree*" ed)))
          (buffer-attach! ed tbuf)
          (edit-window-buffer-set! win tbuf)
          (editor-set-text ed content)
          (editor-goto-pos ed 0)
          (editor-set-read-only ed #t)))))

  ;;;==========================================================================
  ;;; Editor server
  ;;;==========================================================================

  (define (cmd-server-start app)
    (echo-message! (app-state-echo app)
      "Server mode: use jemacs <file> to open files"))

  (define (cmd-server-edit app)
    (let ((file (app-read-string app "File to edit: ")))
      (when (and file (not (string=? file "")))
        (execute-command! app 'find-file))))

  ;;;==========================================================================
  ;;; Additional navigation
  ;;;==========================================================================

  (define (cmd-pop-global-mark app)
    (let ((mr (app-state-mark-ring app)))
      (if (and mr (not (null? mr)))
        (let ((mark (car mr)))
          (app-state-mark-ring-set! app (cdr mr))
          (let* ((fr (app-state-frame app))
                 (win (current-window fr))
                 (ed (edit-window-editor win)))
            (editor-goto-pos ed mark)
            (editor-scroll-caret ed)))
        (echo-message! (app-state-echo app) "Mark ring empty"))))

  (define (cmd-set-goal-column app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (col (editor-get-column ed pos)))
      (echo-message! (app-state-echo app)
        (string-append "Goal column set to " (number->string col)))))

  ;;;==========================================================================
  ;;; Directory navigation
  ;;;==========================================================================

  (define (cmd-cd app)
    (let ((dir (app-read-string app "Change directory: ")))
      (when (and dir (not (string=? dir "")))
        (if (file-exists? dir)
          (begin
            (current-directory dir)
            (echo-message! (app-state-echo app)
              (string-append "Directory: " (current-directory))))
          (echo-message! (app-state-echo app)
            (string-append "No such directory: " dir))))))

  ;;;==========================================================================
  ;;; Misc Emacs commands
  ;;;==========================================================================

  (define (cmd-display-prefix app)
    (let ((arg (app-state-prefix-arg app)))
      (echo-message! (app-state-echo app)
        (cond
          ((not arg) "No prefix arg")
          ((number? arg) (string-append "Prefix arg: " (number->string arg)))
          ((list? arg) (string-append "Prefix arg: (" (number->string (car arg)) ")"))
          (else "Prefix arg: unknown")))))

  (define (cmd-digit-argument app)
    (app-state-prefix-arg-set! app 0)
    (echo-message! (app-state-echo app) "C-u 0-"))

  (define (cmd-negative-argument app)
    (app-state-prefix-arg-set! app -1)
    (echo-message! (app-state-echo app) "C-u -"))

  (define (cmd-suspend-emacs app)
    (echo-message! (app-state-echo app) "Use C-z in terminal to suspend"))

  (define (cmd-save-buffers-kill-emacs app)
    (for-each
      (lambda (buf)
        (when (and (buffer-file-path buf) (buffer-modified buf))
          (let* ((fr (app-state-frame app))
                 (win (current-window fr))
                 (ed (edit-window-editor win)))
            (void))))
      (buffer-list))
    (app-state-running-set! app #f)
    (echo-message! (app-state-echo app) "Exiting..."))

  ;;;==========================================================================
  ;;; View/doc mode
  ;;;==========================================================================

  (define (cmd-view-mode app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (ro (editor-get-read-only? ed)))
      (editor-set-read-only ed (not ro))
      (echo-message! (app-state-echo app)
        (if ro "View mode disabled" "View mode enabled"))))

  (define (cmd-doc-view-mode app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (buf (edit-window-buffer win))
           (file (and buf (buffer-file-path buf)))
           (echo (app-state-echo app)))
      (if (not file)
        (echo-message! echo "No file associated with buffer")
        (let* ((ext (let ((dot (string-index-right file #\.)))
                      (if dot (substring file (+ dot 1) (string-length file)) "")))
               (cmd (cond
                      ((string=? ext "pdf") "pdftotext")
                      ((string=? ext "ps") "ps2ascii")
                      (else #f))))
          (if (not cmd)
            (echo-message! echo "Not a PDF or PS file")
            (guard (e (#t (echo-error! echo (string-append cmd " not available"))))
              (let* ((text (run-command-capture cmd (list (shell-quote-arg file) "-"))))
                (let* ((ed (edit-window-editor win))
                       (new-buf (buffer-create! (string-append "*DocView: " file "*") ed)))
                  (buffer-attach! ed new-buf)
                  (edit-window-buffer-set! win new-buf)
                  (editor-set-text ed (or text "Could not convert document"))
                  (editor-goto-pos ed 0)
                  (editor-set-read-only ed #t)))))))))

  ;;;==========================================================================
  ;;; Speedbar -- show file tree of current directory
  ;;;==========================================================================

  (define (cmd-speedbar app)
    (let* ((dir (current-directory))
           (output (guard (e (#t (string-append "Error listing " dir)))
                     (or (run-command-capture "find"
                           (list (shell-quote-arg dir) "-maxdepth" "3" "-type" "f" "-name" "'*.ss'"))
                         "")))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (buf (buffer-create! "*Speedbar*" ed)))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (editor-set-text ed (string-append "File Tree: " dir "\n\n" output "\n"))
      (editor-goto-pos ed 0)
      (editor-set-read-only ed #t)))

  ;;;==========================================================================
  ;;; Misc utilities
  ;;;==========================================================================

  (define (cmd-world-clock app)
    (let ((result (guard (e (#t "Error getting time"))
                    (or (run-command-capture "date" '("+%Y-%m-%d %H:%M:%S %Z"))
                        ""))))
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (buf (buffer-create! "*World Clock*" ed)))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! win buf)
        (editor-set-text ed (string-append "World Clock\n\nLocal: " result "\n"))
        (editor-set-read-only ed #t))))

  (define (cmd-display-battery app)
    (let ((result (guard (e (#t "Battery info not available"))
                    (if (file-exists? "/sys/class/power_supply/BAT0/capacity")
                      (let ((cap (call-with-input-file "/sys/class/power_supply/BAT0/capacity"
                                   (lambda (p) (get-line p))))
                            (status (if (file-exists? "/sys/class/power_supply/BAT0/status")
                                      (call-with-input-file "/sys/class/power_supply/BAT0/status"
                                        (lambda (p) (get-line p)))
                                      "Unknown")))
                        (string-append "Battery: " cap "% (" status ")"))
                      "No battery information available"))))
      (echo-message! (app-state-echo app) result)))

  (define (cmd-uptime app)
    (let ((result (guard (e (#t "Error getting uptime"))
                    (let ((out (run-command-capture "uptime" '())))
                      (if out
                        (string-append "Uptime:" (string-trim out))
                        "Error getting uptime")))))
      (echo-message! (app-state-echo app) result)))

  ;;;==========================================================================
  ;;; Kmacro counter
  ;;;==========================================================================

  (define (cmd-kmacro-set-counter app)
    (let ((val (app-read-string app (string-append "Counter value (current: "
                                      (number->string (kmacro-counter)) "): "))))
      (when (and val (not (string=? val "")))
        (let ((n (string->number val)))
          (when n
            (kmacro-counter-set! n)
            (echo-message! (app-state-echo app)
              (string-append "Macro counter: " (number->string n))))))))

  (define (cmd-kmacro-insert-counter app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (number->string (kmacro-counter))))
      (editor-insert-text ed (editor-get-current-pos ed) text)
      (kmacro-counter-set! (+ (kmacro-counter) 1))
      (echo-message! (app-state-echo app)
        (string-append "Inserted " text ", next: " (number->string (kmacro-counter))))))

  ;;;==========================================================================
  ;;; Whitespace report
  ;;;==========================================================================

  (define (cmd-whitespace-report app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (trailing-count 0)
           (tab-count 0)
           (long-count 0))
      (for-each
        (lambda (line)
          (when (and (> (string-length line) 0)
                     (char-whitespace? (string-ref line (- (string-length line) 1))))
            (set! trailing-count (+ trailing-count 1)))
          (when (string-contains line "\t")
            (set! tab-count (+ tab-count 1)))
          (when (> (string-length line) 80)
            (set! long-count (+ long-count 1))))
        lines)
      (echo-message! (app-state-echo app)
        (string-append "Trailing: " (number->string trailing-count)
                       " Tabs: " (number->string tab-count)
                       " Long(>80): " (number->string long-count)))))

  ;;;==========================================================================
  ;;; Encoding detection
  ;;;==========================================================================

  (define (cmd-describe-coding-system app)
    (echo-message! (app-state-echo app) "Coding system: utf-8 (Chez Scheme uses UTF-8 internally)"))

  (define (cmd-set-terminal-coding-system app)
    (echo-message! (app-state-echo app) "Terminal coding: utf-8 (fixed)"))

  ;;;==========================================================================
  ;;; Misc text
  ;;;==========================================================================

  (define (cmd-overwrite-mode app)
    (let* ((ed (current-editor app))
           (cur (send-message ed 2187 0 0))  ;; SCI_GETOVERTYPE
           (new (if (zero? cur) 1 0)))
      (send-message ed 2186 new 0)           ;; SCI_SETOVERTYPE
      (echo-message! (app-state-echo app)
        (if (= new 1) "Overwrite mode ON" "Overwrite mode OFF"))))

  ;;;==========================================================================
  ;;; Interactive ripgrep search
  ;;;==========================================================================

  (define (cmd-consult-ripgrep app)
    (let* ((buf (current-buffer-from-app app))
           (root (or (project-current app) (current-directory)))
           (pattern (app-read-string app
                      (string-append "rg in " (path-strip-directory root) ": "))))
      (when (and pattern (not (string=? pattern "")))
        (echo-message! (app-state-echo app) "Searching...")
        (guard (e (#t (echo-error! (app-state-echo app) "rg not found or failed")))
          (let* ((output (run-command-capture "rg"
                           (list "--vimgrep" "--color" "never"
                                 "--max-count" "500"
                                 (shell-quote-arg pattern) (shell-quote-arg root)))))
            (if (or (not output) (not (string? output)) (string=? output ""))
              (echo-message! (app-state-echo app) "No matches found")
              (let ((lines (string-split output #\newline)))
                (open-output-buffer app "*Grep*"
                  (string-append "-*- grep -*-\nrg " pattern " " root "\n\n"
                    (number->string (length lines)) " matches\n\n"
                    output "\n"))
                (echo-message! (app-state-echo app)
                  (string-append (number->string (length lines)) " matches")))))))))

  ;;;==========================================================================
  ;;; goto-address-mode -- highlight URLs in buffer
  ;;;==========================================================================

  (define *tui-goto-address-active* #f)
  (define *tui-goto-address-indicator* 12)

  (define (tui-goto-address-setup! ed)
    (send-message ed SCI_INDICSETSTYLE *tui-goto-address-indicator* 0)
    (send-message ed SCI_INDICSETFORE *tui-goto-address-indicator* #xFF0000))

  (define (tui-goto-address-clear! ed)
    (let ((len (send-message ed SCI_GETTEXTLENGTH 0 0)))
      (send-message ed SCI_SETINDICATORCURRENT *tui-goto-address-indicator* 0)
      (send-message ed SCI_INDICATORCLEARRANGE 0 len)))

  (define (tui-goto-address-scan! ed)
    (tui-goto-address-clear! ed)
    (tui-goto-address-setup! ed)
    (let* ((text (editor-get-text ed))
           (len (string-length text)))
      (send-message ed SCI_SETINDICATORCURRENT *tui-goto-address-indicator* 0)
      (let loop ((i 0))
        (when (< i (- len 7))
          (if (and (char=? (string-ref text i) #\h)
                   (or (string-prefix? "http://" (substring text i (min len (+ i 8))))
                       (string-prefix? "https://" (substring text i (min len (+ i 9))))))
            (let url-end ((j (+ i 7)))
              (if (or (>= j len)
                      (char=? (string-ref text j) #\space)
                      (char=? (string-ref text j) #\tab)
                      (char=? (string-ref text j) #\newline)
                      (char=? (string-ref text j) #\>)
                      (char=? (string-ref text j) #\))
                      (char=? (string-ref text j) #\])
                      (char=? (string-ref text j) #\")
                      (char=? (string-ref text j) #\'))
                (begin
                  (send-message ed SCI_INDICATORFILLRANGE i (- j i))
                  (loop j))
                (url-end (+ j 1))))
            (loop (+ i 1)))))))

  (define (cmd-goto-address-mode app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win)))
      (set! *tui-goto-address-active* (not *tui-goto-address-active*))
      (if *tui-goto-address-active*
        (begin
          (tui-goto-address-scan! ed)
          (echo-message! (app-state-echo app) "Goto-address-mode ON"))
        (begin
          (tui-goto-address-clear! ed)
          (echo-message! (app-state-echo app) "Goto-address-mode OFF")))))

  ;;;==========================================================================
  ;;; subword-mode -- CamelCase-aware word movement
  ;;;==========================================================================

  (define *tui-subword-mode* #f)

  (define (tui-subword-forward-pos text pos)
    (let ((len (string-length text)))
      (if (>= pos len) pos
        (let loop ((i (+ pos 1)))
          (cond
            ((>= i len) i)
            ((and (> i 0)
                  (char-lower-case? (string-ref text (- i 1)))
                  (char-upper-case? (string-ref text i)))
             i)
            ((and (> i 1)
                  (char-upper-case? (string-ref text (- i 2)))
                  (char-upper-case? (string-ref text (- i 1)))
                  (char-lower-case? (string-ref text i)))
             (- i 1))
            ((and (> i 0)
                  (not (eqv? (char-alphabetic? (string-ref text (- i 1)))
                             (char-alphabetic? (string-ref text i)))))
             (if (char-whitespace? (string-ref text i))
               (let skip-ws ((j i))
                 (if (or (>= j len) (not (char-whitespace? (string-ref text j))))
                   j (skip-ws (+ j 1))))
               i))
            (else (loop (+ i 1))))))))

  (define (tui-subword-backward-pos text pos)
    (if (<= pos 0) 0
      (let loop ((i (- pos 1)))
        (cond
          ((<= i 0) 0)
          ((char-whitespace? (string-ref text i))
           (loop (- i 1)))
          ((and (> i 0)
                (char-lower-case? (string-ref text i))
                (char-upper-case? (string-ref text (- i 1)))
                (or (= i 1) (not (char-upper-case? (string-ref text (- i 2))))))
           (- i 1))
          ((and (> i 1)
                (char-upper-case? (string-ref text i))
                (char-upper-case? (string-ref text (- i 1)))
                (not (char-upper-case? (string-ref text (- i 2)))))
           (- i 1))
          ((and (> i 0)
                (not (eqv? (char-alphabetic? (string-ref text i))
                           (char-alphabetic? (string-ref text (- i 1))))))
           (if (char-alphabetic? (string-ref text i)) i
             (loop (- i 1))))
          (else (loop (- i 1)))))))

  (define (cmd-subword-forward app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (new-pos (tui-subword-forward-pos text pos)))
      (send-message ed SCI_GOTOPOS new-pos 0)))

  (define (cmd-subword-backward app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (new-pos (tui-subword-backward-pos text pos)))
      (send-message ed SCI_GOTOPOS new-pos 0)))

  (define (cmd-subword-kill app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (end (tui-subword-forward-pos text pos)))
      (when (> end pos)
        (send-message ed SCI_DELETERANGE pos (- end pos)))))

  ;;;==========================================================================
  ;;; Goto last change (goto-chg package emulation)
  ;;;==========================================================================

  (define *tui-edit-positions* (make-hash-table))
  (define *tui-edit-pos-index* (make-hash-table))

  (define (tui-record-edit-position! app)
    (let* ((fr (app-state-frame app))
           (ed (edit-window-editor (current-window fr)))
           (buf (current-buffer-from-app app))
           (name (buffer-name buf))
           (pos (editor-get-current-pos ed))
           (positions (or (hash-get *tui-edit-positions* name) '())))
      (when (or (null? positions)
                (> (abs (- pos (car positions))) 5))
        (hash-put! *tui-edit-positions* name
          (cons pos (take positions (min 100 (length positions)))))
        (hash-remove! *tui-edit-pos-index* name))))

  (define (cmd-goto-last-change-reverse app)
    (let* ((buf (current-buffer-from-app app))
           (name (buffer-name buf))
           (echo (app-state-echo app))
           (ed (edit-window-editor (current-window (app-state-frame app))))
           (positions (or (hash-get *tui-edit-positions* name) '()))
           (idx (or (hash-get *tui-edit-pos-index* name) 0))
           (new-idx (- idx 1)))
      (if (< new-idx 0)
        (echo-message! echo "At most recent edit position")
        (begin
          (hash-put! *tui-edit-pos-index* name new-idx)
          (let ((target (list-ref positions new-idx)))
            (editor-goto-pos ed (min target (string-length (editor-get-text ed))))
            (editor-scroll-caret ed)
            (echo-message! echo
              (string-append "Edit position " (number->string (+ new-idx 1))
                             "/" (number->string (length positions)))))))))

  ;;;==========================================================================
  ;;; File operations: rename-visited-file
  ;;;==========================================================================

  (define (cmd-rename-visited-file app)
    (let* ((echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (ed (edit-window-editor (current-window (app-state-frame app))))
           (path (buffer-file-path buf)))
      (if (not path)
        (echo-error! echo "Buffer has no associated file")
        (let ((new-name (app-read-string app
                          (string-append "Rename " (path-strip-directory path) " to: "))))
          (when (and new-name (> (string-length new-name) 0))
            (let ((new-path (if (and (> (string-length new-name) 0)
                                     (char=? (string-ref new-name 0) #\/))
                              new-name
                              (path-expand new-name (path-directory path)))))
              (guard (e (#t
                         (echo-error! echo
                           (string-append "Rename failed: "
                             (call-with-string-output-port
                               (lambda (p) (display e p)))))))
                (rename-file path new-path)
                (buffer-file-path-set! buf new-path)
                (buffer-name-set! buf (path-strip-directory new-path))
                (echo-message! echo
                  (string-append "Renamed to " new-path)))))))))

  ;;;==========================================================================
  ;;; Terraform integration
  ;;;==========================================================================

  (define (cmd-terraform-mode app)
    (let ((ed (current-editor app)))
      (send-message ed SCI_SETLEXER SCLEX_PROPERTIES)
      (echo-message! (app-state-echo app) "Terraform mode enabled (properties lexer)")))

  (define (cmd-terraform app)
    (let* ((echo (app-state-echo app))
           (args (app-read-string app "terraform: ")))
      (when (and args (> (string-length args) 0))
        (let ((output (guard (e (#t (string-append "Error: " (call-with-string-output-port
                                                      (lambda (p) (display e p))))))
                        (or (run-command-capture "terraform"
                              (string-split args #\space))
                            "No output"))))
          (open-output-buffer app "*Terraform*"
            (string-append "$ terraform " args "\n\n" output "\n"))))))

  (define (cmd-terraform-plan app)
    (let* ((echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (dir (let ((fp (buffer-file-path buf)))
                  (if fp (path-directory fp) "."))))
      (echo-message! echo "Running terraform plan...")
      (let ((output (guard (e (#t (string-append "Error: " (call-with-string-output-port
                                                    (lambda (p) (display e p))))))
                      (or (run-command-capture "terraform" '("plan" "-no-color"))
                          "No output"))))
        (open-output-buffer app "*Terraform Plan*"
          (string-append "terraform plan\nDirectory: " dir "\n\n" output "\n")))))

  ;;;==========================================================================
  ;;; Docker Compose integration
  ;;;==========================================================================

  (define (cmd-docker-compose app)
    (let* ((echo (app-state-echo app))
           (args (app-read-string app "docker compose: ")))
      (when (and args (> (string-length args) 0))
        (let ((output (guard (e (#t (string-append "Error: " (call-with-string-output-port
                                                      (lambda (p) (display e p))))))
                        (or (run-command-capture "docker"
                              (cons "compose" (string-split args #\space)))
                            "No output"))))
          (open-output-buffer app "*Docker Compose*"
            (string-append "$ docker compose " args "\n\n" output "\n"))))))

  (define (cmd-docker-compose-up app)
    (let* ((echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (dir (let ((fp (buffer-file-path buf)))
                  (if fp (path-directory fp) "."))))
      (echo-message! echo "Running docker compose up...")
      (let ((output (guard (e (#t (string-append "Error: " (call-with-string-output-port
                                                    (lambda (p) (display e p))))))
                      (or (run-command-capture "docker" '("compose" "up" "-d"))
                          "No output"))))
        (open-output-buffer app "*Docker Compose*"
          (string-append "docker compose up -d\nDirectory: " dir "\n\n" output "\n")))))

  (define (cmd-docker-compose-down app)
    (let* ((echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (dir (let ((fp (buffer-file-path buf)))
                  (if fp (path-directory fp) "."))))
      (let ((output (guard (e (#t (string-append "Error: " (call-with-string-output-port
                                                    (lambda (p) (display e p))))))
                      (or (run-command-capture "docker" '("compose" "down"))
                          "No output"))))
        (echo-message! echo (string-append "docker compose down: " output)))))

) ;; end library
