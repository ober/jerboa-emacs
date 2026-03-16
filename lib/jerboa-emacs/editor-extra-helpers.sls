#!chezscheme
;;; editor-extra-helpers.sls — Shared helpers for editor-extra sub-modules
;;;
;;; Ported from gerbil-emacs/editor-extra-helpers.ss

(library (jerboa-emacs editor-extra-helpers)
  (export
    ;; Helpers
    current-editor
    current-buffer-from-app
    open-output-buffer
    app-read-string
    extra-word-char?
    word-bounds-at
    directory-exists?
    editor-replace-selection
    app-state-mark-pos
    toggle-mode!
    mode-enabled?

    ;; S-expression helpers
    sp-find-enclosing-paren
    sp-find-matching-close
    sp-find-sexp-end

    ;; Project helpers
    project-find-root
    project-current

    ;; Spell-check
    flyspell-check-word

    ;; Batch 13 commands
    cmd-set-visited-file-name
    cmd-sort-columns
    cmd-sort-regexp-fields
    cmd-insert-tab

    ;; Smerge mode
    smerge-find-conflict
    smerge-count-conflicts
    smerge-extract-mine
    smerge-extract-other
    cmd-smerge-next
    cmd-smerge-prev
    cmd-smerge-keep-mine
    cmd-smerge-keep-other
    cmd-smerge-keep-both
    cmd-smerge-mode

    ;; Org agenda
    agenda-parse-line
    cmd-org-agenda-goto
    cmd-org-agenda-todo

    ;; Flyspell
    flyspell-is-word-char?
    flyspell-extract-words
    cmd-flyspell-mode

    ;; Custom groups
    custom-group-add!
    *custom-variables*

    ;; Face customization
    face-set!
    face-get

    ;; Advice system
    advice-add!
    advice-remove!
    run-advice-before
    run-advice-after
    cmd-describe-advice

    ;; Autoload system
    autoload!
    autoload-resolve
    cmd-list-autoloads

    ;; Dynamic module loading
    cmd-load-module
    cmd-list-modules

    ;; Icomplete / Fido
    cmd-icomplete-mode
    cmd-fido-mode

    ;; Marginalia
    marginalia-annotate!

    ;; Embark
    embark-define-action!

    ;; Persistent undo
    persistent-undo-file-for
    cmd-undo-history-save
    cmd-undo-history-load

    ;; Image dired
    image-file?
    cmd-image-dired-display-thumbnail
    cmd-image-dired-show-all-thumbnails

    ;; Virtual dired
    cmd-virtual-dired
    cmd-dired-from-find

    ;; Key mapping
    cmd-key-translate
    cmd-toggle-super-key-mode
    cmd-describe-key-translations

    ;; Display tables
    display-table-set!
    display-table-get
    cmd-set-display-table-entry
    cmd-describe-display-table

    ;; LSP
    lsp-server-register!
    lsp-server-for
    cmd-lsp-set-server
    cmd-lsp-list-servers

    ;; DevOps
    cmd-ansible-mode
    cmd-ansible-playbook
    cmd-systemd-mode
    cmd-kubernetes-mode
    cmd-kubectl
    cmd-ssh-config-mode

    ;; Helm
    cmd-helm-occur
    cmd-helm-dash

    ;; Completion / AI / TRAMP
    cmd-selectrum-mode
    cmd-cape-history
    cmd-cape-keyword
    cmd-ai-inline-suggest
    tui-ai-detect-language
    tui-ai-request
    cmd-ai-code-explain
    cmd-ai-code-refactor
    cmd-tramp-ssh-edit
    cmd-tramp-docker-edit
    cmd-tramp-remote-shell
    cmd-tramp-remote-compile
    cmd-helm-c-yasnippet

    ;; Parity stubs
    cmd-tree-sitter-mode
    cmd-tree-sitter-highlight-mode
    cmd-tool-bar-mode
    cmd-mu4e
    cmd-notmuch
    cmd-rcirc
    cmd-eww-submit-form
    cmd-eww-toggle-css
    cmd-eww-toggle-images
    cmd-screen-reader-mode

    ;; Org-crypt
    tui-org-find-entry-bounds
    cmd-org-encrypt-entry
    cmd-org-decrypt-entry

    ;; Kmacro counter accessors
    kmacro-counter
    kmacro-counter-set!)

  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (only (jerboa prelude) path-directory path-strip-directory path-extension)
          (only (std srfi srfi-13) string-join string-contains string-prefix?
                string-suffix? string-index string-trim string-trim-both)
          (only (std misc string) string-split)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (chez-scintilla tui)
          (except (jerboa-emacs core) face-get)
          (jerboa-emacs keymap)
          (jerboa-emacs buffer)
          (jerboa-emacs window)
          (jerboa-emacs modeline)
          (jerboa-emacs echo)
          (jerboa-emacs persist))

  ;;;============================================================================
  ;;; Internal helpers
  ;;;============================================================================

  (define (run-process-capture cmd args)
    "Run a command and capture stdout as a string. Returns output or #f on error."
    (guard (e [#t #f])
      (let-values (((to-stdin from-stdout from-stderr proc-id)
                    (open-process-ports
                      (string-append cmd " " (string-join args " "))
                      (buffer-mode block)
                      (native-transcoder))))
        (let ((output (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (close-port to-stdin)
          (if (eof-object? output) "" output)))))

  (define (run-process-with-input cmd args input-text)
    "Run a command, write input-text to stdin, capture stdout. Returns output or #f."
    (guard (e [#t #f])
      (let-values (((to-stdin from-stdout from-stderr proc-id)
                    (open-process-ports
                      (string-append cmd " " (string-join args " "))
                      (buffer-mode block)
                      (native-transcoder))))
        (display input-text to-stdin)
        (flush-output-port to-stdin)
        (close-port to-stdin)
        (let ((output (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (if (eof-object? output) "" output)))))

  (define (create-directory* dir)
    "Create directory, ignoring errors if it already exists."
    (guard (e [#t (void)])
      (create-directory* (path-directory dir))
      (guard (e2 [#t (void)])
        (mkdir dir))))

  (define (safe-display-exception e)
    "Convert an exception to a display string."
    (call-with-string-output-port
      (lambda (p) (display e p))))

  (define (take lst n)
    "Take at most N elements from LST."
    (let loop ((l lst) (n n) (acc '()))
      (if (or (null? l) (<= n 0))
        (reverse acc)
        (loop (cdr l) (- n 1) (cons (car l) acc)))))

  ;;;============================================================================
  ;;; Helpers
  ;;;============================================================================

  (define (current-editor app)
    (edit-window-editor (current-window (app-state-frame app))))

  (define (current-buffer-from-app app)
    (edit-window-buffer (current-window (app-state-frame app))))

  (define (open-output-buffer app name text)
    (let* ((ed (current-editor app))
           (fr (app-state-frame app))
           (buf (or (buffer-by-name name)
                    (buffer-create! name ed #f))))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (editor-set-text ed text)
      (editor-set-save-point ed)
      (editor-goto-pos ed 0)))

  (define (app-read-string app prompt)
    "Convenience wrapper: read a string from the echo area.
     In tests, dequeues from test-echo-responses if non-empty."
    (if (pair? (test-echo-responses))
      (let ((r (car (test-echo-responses))))
        (test-echo-responses-set! (cdr (test-echo-responses)))
        r)
      (let* ((echo (app-state-echo app))
             (fr (app-state-frame app))
             (row (- (frame-height fr) 1))
             (width (frame-width fr)))
        (echo-read-string echo prompt row width))))

  (define (extra-word-char? ch)
    (or (char-alphabetic? ch) (char-numeric? ch) (char=? ch #\_) (char=? ch #\-)))

  (define (word-bounds-at ed pos)
    "Find word boundaries around POS. Returns (values start end) or (values #f #f)."
    (let* ((text (editor-get-text ed))
           (len (string-length text)))
      (if (or (>= pos len) (< pos 0) (not (extra-word-char? (string-ref text pos))))
        ;; Not in a word - try char before pos
        (if (and (> pos 0) (extra-word-char? (string-ref text (- pos 1))))
          (let ((p (- pos 1)))
            (let find-start ((i p))
              (if (and (> i 0) (extra-word-char? (string-ref text (- i 1))))
                (find-start (- i 1))
                (let find-end ((j (+ p 1)))
                  (if (and (< j len) (extra-word-char? (string-ref text j)))
                    (find-end (+ j 1))
                    (values i j))))))
          (values #f #f))
        ;; In a word - scan backward then forward
        (let find-start ((i pos))
          (if (and (> i 0) (extra-word-char? (string-ref text (- i 1))))
            (find-start (- i 1))
            (let find-end ((j (+ pos 1)))
              (if (and (< j len) (extra-word-char? (string-ref text j)))
                (find-end (+ j 1))
                (values i j))))))))

  ;;;============================================================================
  ;;; Global mode flags
  ;;;============================================================================

  (define (directory-exists? path)
    (and (file-exists? path)
         (file-directory? path)))

  (define (editor-replace-selection ed text)
    "Replace the current selection with text. SCI_REPLACESEL=2170."
    (send-message/string ed 2170 text))

  (define *mode-flags* (make-hash-table))
  (define *recent-files* '())
  (define *last-compile-proc* #f)
  (define *kmacro-counter* 0)
  (define *kmacro-counter-format* "%d")
  (define *custom-variables* (make-hash-table))

  (define (kmacro-counter) *kmacro-counter*)
  (define (kmacro-counter-set! v) (set! *kmacro-counter* v))

  (define (app-state-mark-pos app)
    "Get the mark position from the current buffer."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (buf (edit-window-buffer win)))
      (buffer-mark buf)))

  (define (toggle-mode! name)
    "Toggle a named mode flag. Returns the new state."
    (let ((current (hash-get *mode-flags* name)))
      (hash-put! *mode-flags* name (not current))
      (not current)))

  (define (mode-enabled? name)
    (hash-get *mode-flags* name))

  ;;;============================================================================
  ;;; Shared s-expression helpers
  ;;;============================================================================

  (define (sp-find-enclosing-paren ed pos open-char close-char)
    "Find the position of the enclosing open paren before pos."
    (let ((text (editor-get-text ed)))
      (let loop ((i (- pos 1)) (depth 0))
        (if (< i 0)
          #f
          (let ((ch (string-ref text i)))
            (cond
              ((char=? ch close-char) (loop (- i 1) (+ depth 1)))
              ((char=? ch open-char)
               (if (= depth 0) i (loop (- i 1) (- depth 1))))
              (else (loop (- i 1) depth))))))))

  (define (sp-find-matching-close ed pos open-char close-char)
    "Find the position of the matching close paren after pos."
    (let* ((text (editor-get-text ed))
           (len (string-length text)))
      (let loop ((i pos) (depth 1))
        (if (>= i len)
          #f
          (let ((ch (string-ref text i)))
            (cond
              ((char=? ch open-char) (loop (+ i 1) (+ depth 1)))
              ((char=? ch close-char)
               (if (= depth 1) i (loop (+ i 1) (- depth 1))))
              (else (loop (+ i 1) depth))))))))

  (define (sp-find-sexp-end ed pos)
    "Find the end of the sexp starting at or after pos."
    (let* ((text (editor-get-text ed))
           (len (string-length text)))
      ;; Skip whitespace
      (let skip ((i pos))
        (if (>= i len)
          #f
          (let ((ch (string-ref text i)))
            (cond
              ((char-whitespace? ch) (skip (+ i 1)))
              ((char=? ch #\() (sp-find-matching-close ed (+ i 1) #\( #\)))
              ((char=? ch #\[) (sp-find-matching-close ed (+ i 1) #\[ #\]))
              ((char=? ch #\{) (sp-find-matching-close ed (+ i 1) #\{ #\}))
              ;; Symbol/atom - find end
              (else
               (let find-end ((j i))
                 (if (>= j len)
                   (- j 1)
                   (let ((c (string-ref text j)))
                     (if (or (char-whitespace? c)
                             (memv c '(#\( #\) #\[ #\] #\{ #\})))
                       (- j 1)
                       (find-end (+ j 1)))))))))))))

  ;;;============================================================================
  ;;; Shared project helpers
  ;;;============================================================================

  (define *project-markers* '(".git" ".hg" ".svn" ".project" "Makefile" "package.json"
                           "Cargo.toml" "go.mod" "build.ss" "gerbil.pkg"))
  (define *project-history* '())

  (define (project-find-root dir)
    "Find project root by looking for project markers. Returns root or #f."
    (let loop ((d dir))
      (if (or (string=? d "/") (string=? d ""))
        #f
        (if (exists (lambda (marker)
                      (let ((path (string-append d "/" marker)))
                        (or (file-exists? path)
                            (directory-exists? path))))
                    *project-markers*)
          d
          (loop (path-directory d))))))

  (define (project-current app)
    "Get current project root based on current buffer's file."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (buf (edit-window-buffer win))
           (file (and buf (buffer-file-path buf))))
      (if file
        (project-find-root (path-directory file))
        (project-find-root (current-directory)))))

  ;;;============================================================================
  ;;; Shared spell-check helper
  ;;;============================================================================

  (define (flyspell-check-word word)
    "Check a word with aspell. Returns list of suggestions or #f if correct."
    (guard (e [#t #f])
      (let* ((output (run-process-with-input
                       "aspell" '("pipe")
                       (string-append "^" word "\n")))
             (lines (if output (string-split output #\newline) '()))
             ;; Skip header line, get result
             (result (if (> (length lines) 1) (list-ref lines 1) "")))
        (cond
          ((or (string=? result "") (eof-object? result)) #f)
          ((char=? (string-ref result 0) #\*) #f)
          ((char=? (string-ref result 0) #\&)
           (let* ((parts (string-split result #\:))
                  (suggestions (if (>= (length parts) 2)
                                 (map (lambda (s) (string-trim-both s))
                                      (string-split (list-ref parts 1) #\,))
                                 '())))
             suggestions))
          ((char=? (string-ref result 0) #\#) '())
          (else #f)))))

  ;;;============================================================================
  ;;; Batch 13: New commands
  ;;;============================================================================

  (define (cmd-set-visited-file-name app)
    "Change the file name associated with the current buffer."
    (let* ((fr (app-state-frame app))
           (buf (edit-window-buffer (current-window fr)))
           (old (and buf (buffer-file-path buf)))
           (prompt (if old (string-append "New file name (was " old "): ") "File name: "))
           (new-name (app-read-string app prompt)))
      (if (and new-name (not (string=? new-name "")))
        (begin
          (buffer-file-path-set! buf new-name)
          (buffer-name-set! buf (path-strip-directory new-name))
          (buffer-modified-set! buf #t)
          (echo-message! (app-state-echo app) (string-append "File name set to " new-name)))
        (echo-message! (app-state-echo app) "Cancelled"))))

  (define (cmd-sort-columns app)
    "Sort lines in region by a column range."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app))
           (col-str (app-read-string app "Sort by column (start-end): ")))
      (when (and col-str (not (string=? col-str "")))
        (let* ((parts (string-split col-str #\-))
               (start-col (and (pair? parts) (string->number (car parts))))
               (end-col (and (> (length parts) 1) (string->number (cadr parts)))))
          (if (not start-col)
            (echo-message! echo "Invalid column spec -- use start-end (e.g., 10-20)")
            (let* ((text (editor-get-text ed))
                   (lines (string-split text #\newline))
                   (end-c (or end-col 999))
                   (extract (lambda (line)
                              (if (>= (string-length line) start-col)
                                (substring line (- start-col 1) (min end-c (string-length line)))
                                "")))
                   (sorted (list-sort (lambda (a b) (string<? (extract a) (extract b))) lines))
                   (result (string-join sorted "\n")))
              (editor-set-text ed result)
              (echo-message! echo (string-append "Sorted " (number->string (length lines)) " lines by columns "
                                                 (number->string start-col) "-" (number->string end-c)))))))))

  (define (cmd-sort-regexp-fields app)
    "Sort lines in region by regex match."
    (let* ((echo (app-state-echo app))
           (pattern (app-read-string app "Sort by regexp: ")))
      (when (and pattern (not (string=? pattern "")))
        (let* ((fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win))
               (text (editor-get-text ed))
               (lines (string-split text #\newline))
               (extract (lambda (line)
                          (let ((m (string-contains line pattern)))
                            (if m (substring line m (string-length line)) line))))
               (sorted (list-sort (lambda (a b) (string<? (extract a) (extract b))) lines))
               (result (string-join sorted "\n")))
          (editor-set-text ed result)
          (echo-message! echo (string-append "Sorted " (number->string (length lines)) " lines by /" pattern "/"))))))

  ;;; Batch 15: insert-tab (TUI)
  (define (cmd-insert-tab app)
    "Insert a literal tab character at point."
    (let ((ed (current-editor app)))
      (editor-replace-selection ed "\t")))

  ;;;============================================================================
  ;;; Smerge mode: Git conflict marker resolution (TUI)
  ;;;============================================================================

  (define *smerge-mine-marker*  "<<<<<<<")
  (define *smerge-sep-marker*   "=======")
  (define *smerge-other-marker* ">>>>>>>")

  (define (smerge-find-conflict text pos direction)
    "Find the next/prev conflict starting from POS.
     DIRECTION is 'next or 'prev.
     Returns (values mine-start sep-start other-end) or (values #f #f #f)."
    (let ((len (string-length text)))
      (if (eq? direction 'next)
        ;; Search forward from pos for <<<<<<<
        (let loop ((i pos))
          (if (>= i len)
            (values #f #f #f)
            (if (and (<= (+ i 7) len)
                     (string=? (substring text i (+ i 7)) *smerge-mine-marker*)
                     (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
              ;; Found <<<<<<< - now find ======= and >>>>>>>
              (let ((mine-start i))
                (let find-sep ((j (+ i 7)))
                  (if (>= j len)
                    (values #f #f #f)
                    (if (and (<= (+ j 7) len)
                             (string=? (substring text j (+ j 7)) *smerge-sep-marker*)
                             (or (= j 0) (char=? (string-ref text (- j 1)) #\newline)))
                      (let ((sep-start j))
                        (let find-other ((k (+ j 7)))
                          (if (>= k len)
                            (values #f #f #f)
                            (if (and (<= (+ k 7) len)
                                     (string=? (substring text k (+ k 7)) *smerge-other-marker*)
                                     (or (= k 0) (char=? (string-ref text (- k 1)) #\newline)))
                              ;; Find end of >>>>>>> line
                              (let find-eol ((e (+ k 7)))
                                (if (or (>= e len) (char=? (string-ref text e) #\newline))
                                  (values mine-start sep-start (min (+ e 1) len))
                                  (find-eol (+ e 1))))
                              (find-other (+ k 1))))))
                      (find-sep (+ j 1))))))
              (loop (+ i 1)))))
        ;; Search backward: find <<<<<<< before pos
        (let loop ((i (min pos (- len 1))))
          (if (< i 0)
            (values #f #f #f)
            (if (and (<= (+ i 7) len)
                     (string=? (substring text i (+ i 7)) *smerge-mine-marker*)
                     (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
              ;; Found <<<<<<< before pos - verify it has ======= and >>>>>>>
              (let ((mine-start i))
                (let find-sep ((j (+ i 7)))
                  (if (>= j len)
                    (loop (- i 1))
                    (if (and (<= (+ j 7) len)
                             (string=? (substring text j (+ j 7)) *smerge-sep-marker*)
                             (or (= j 0) (char=? (string-ref text (- j 1)) #\newline)))
                      (let ((sep-start j))
                        (let find-other ((k (+ j 7)))
                          (if (>= k len)
                            (loop (- i 1))
                            (if (and (<= (+ k 7) len)
                                     (string=? (substring text k (+ k 7)) *smerge-other-marker*)
                                     (or (= k 0) (char=? (string-ref text (- k 1)) #\newline)))
                              ;; Found complete conflict
                              (let find-eol ((e (+ k 7)))
                                (if (or (>= e len) (char=? (string-ref text e) #\newline))
                                  (values mine-start sep-start (min (+ e 1) len))
                                  (find-eol (+ e 1))))
                              (find-other (+ k 1))))))
                      (find-sep (+ j 1))))))
              (loop (- i 1))))))))

  (define (smerge-count-conflicts text)
    "Count total conflict markers in text."
    (let ((len (string-length text)))
      (let loop ((i 0) (count 0))
        (if (>= i len)
          count
          (if (and (<= (+ i 7) len)
                   (string=? (substring text i (+ i 7)) *smerge-mine-marker*)
                   (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
            (loop (+ i 1) (+ count 1))
            (loop (+ i 1) count))))))

  (define (smerge-extract-mine text mine-start sep-start)
    "Extract 'mine' content between <<<<<<< and =======."
    (let ((mine-line-end
            (let find-eol ((i (+ mine-start 7)))
              (if (or (>= i (string-length text)) (char=? (string-ref text i) #\newline))
                (min (+ i 1) (string-length text))
                (find-eol (+ i 1))))))
      (substring text mine-line-end sep-start)))

  (define (smerge-extract-other text sep-start other-end)
    "Extract 'other' content between ======= and >>>>>>>."
    (let* ((sep-line-end
             (let find-eol ((i (+ sep-start 7)))
               (if (or (>= i (string-length text)) (char=? (string-ref text i) #\newline))
                 (min (+ i 1) (string-length text))
                 (find-eol (+ i 1)))))
           ;; Find start of >>>>>>> line
           (other-line-start
             (let find-marker ((k sep-line-end))
               (if (>= k other-end) other-end
                 (if (and (<= (+ k 7) (string-length text))
                          (string=? (substring text k (+ k 7)) *smerge-other-marker*)
                          (or (= k 0) (char=? (string-ref text (- k 1)) #\newline)))
                   k
                   (find-marker (+ k 1)))))))
      (substring text sep-line-end other-line-start)))

  ;;; TUI smerge commands

  (define (cmd-smerge-next app)
    "Jump to the next merge conflict marker."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (+ (editor-get-current-pos ed) 1)))
      (let-values (((mine sep other) (smerge-find-conflict text pos 'next)))
        (if mine
          (begin
            (editor-goto-pos ed mine)
            (let ((total (smerge-count-conflicts text)))
              (echo-message! echo (string-append "Conflict (" (number->string total) " total)"))))
          (echo-message! echo "No more conflicts")))))

  (define (cmd-smerge-prev app)
    "Jump to the previous merge conflict marker."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (max 0 (- (editor-get-current-pos ed) 1))))
      (let-values (((mine sep other) (smerge-find-conflict text pos 'prev)))
        (if mine
          (begin
            (editor-goto-pos ed mine)
            (let ((total (smerge-count-conflicts text)))
              (echo-message! echo (string-append "Conflict (" (number->string total) " total)"))))
          (echo-message! echo "No previous conflict")))))

  (define (cmd-smerge-keep-mine app)
    "Keep 'mine' (upper) side of the current conflict."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed)))
      ;; Find conflict containing pos: search backward for <<<<<<<
      (let-values (((mine sep other) (smerge-find-conflict text pos 'prev)))
        ;; Also check if pos is inside the conflict
        (if (and mine (<= mine pos) (< pos other))
          (let* ((content (smerge-extract-mine text mine sep))
                 (before (substring text 0 mine))
                 (after (substring text other (string-length text)))
                 (new-text (string-append before content after)))
            (editor-set-text ed new-text)
            (editor-goto-pos ed mine)
            (echo-message! echo "Kept mine"))
          ;; Try forward search
          (let-values (((mine2 sep2 other2) (smerge-find-conflict text pos 'next)))
            (if mine2
              (let* ((content (smerge-extract-mine text mine2 sep2))
                     (before (substring text 0 mine2))
                     (after (substring text other2 (string-length text)))
                     (new-text (string-append before content after)))
                (editor-set-text ed new-text)
                (editor-goto-pos ed mine2)
                (echo-message! echo "Kept mine"))
              (echo-message! echo "No conflict at point")))))))

  (define (cmd-smerge-keep-other app)
    "Keep 'other' (lower) side of the current conflict."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed)))
      (let-values (((mine sep other) (smerge-find-conflict text pos 'prev)))
        (if (and mine (<= mine pos) (< pos other))
          (let* ((content (smerge-extract-other text sep other))
                 (before (substring text 0 mine))
                 (after (substring text other (string-length text)))
                 (new-text (string-append before content after)))
            (editor-set-text ed new-text)
            (editor-goto-pos ed mine)
            (echo-message! echo "Kept other"))
          (let-values (((mine2 sep2 other2) (smerge-find-conflict text pos 'next)))
            (if mine2
              (let* ((content (smerge-extract-other text mine2 sep2))
                     (before (substring text 0 mine2))
                     (after (substring text other2 (string-length text)))
                     (new-text (string-append before content after)))
                (editor-set-text ed new-text)
                (editor-goto-pos ed mine2)
                (echo-message! echo "Kept other"))
              (echo-message! echo "No conflict at point")))))))

  (define (cmd-smerge-keep-both app)
    "Keep both sides of the current conflict (remove markers only)."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed)))
      (let-values (((mine sep other) (smerge-find-conflict text pos 'prev)))
        (if (and mine (<= mine pos) (< pos other))
          (let* ((mine-content (smerge-extract-mine text mine sep))
                 (other-content (smerge-extract-other text sep other))
                 (before (substring text 0 mine))
                 (after (substring text other (string-length text)))
                 (new-text (string-append before mine-content other-content after)))
            (editor-set-text ed new-text)
            (editor-goto-pos ed mine)
            (echo-message! echo "Kept both"))
          (let-values (((mine2 sep2 other2) (smerge-find-conflict text pos 'next)))
            (if mine2
              (let* ((mine-content (smerge-extract-mine text mine2 sep2))
                     (other-content (smerge-extract-other text sep2 other2))
                     (before (substring text 0 mine2))
                     (after (substring text other2 (string-length text)))
                     (new-text (string-append before mine-content other-content after)))
                (editor-set-text ed new-text)
                (editor-goto-pos ed mine2)
                (echo-message! echo "Kept both"))
              (echo-message! echo "No conflict at point")))))))

  ;;;============================================================================
  ;;; Interactive Org Agenda commands (TUI)
  ;;;============================================================================

  (define *agenda-items* (make-hash-table))

  (define (agenda-parse-line text line-num)
    "Parse an agenda line 'bufname:linenum: text' -> (buf-name src-line) or #f."
    (let* ((lines (string-split text #\newline))
           (len (length lines)))
      (if (or (< line-num 0) (>= line-num len))
        #f
        (let* ((line (list-ref lines line-num))
               (trimmed (string-trim line)))
          ;; Format: "bufname:NUM: rest"
          (let ((colon1 (string-contains trimmed ":")))
            (if (not colon1)
              #f
              (let* ((buf-name (substring trimmed 0 colon1))
                     (rest (substring trimmed (+ colon1 1) (string-length trimmed)))
                     (colon2 (string-contains rest ":")))
                (if (not colon2)
                  #f
                  (let* ((num-str (substring rest 0 colon2))
                         (src-line (string->number num-str)))
                    (if src-line
                      (list buf-name src-line)
                      #f))))))))))

  (define (cmd-org-agenda-goto app)
    "Jump to the source of the agenda item on the current line."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (line-num (editor-line-from-position ed pos))
           (parsed (agenda-parse-line text line-num)))
      (if (not parsed)
        (echo-message! echo "No agenda item on this line")
        (let* ((buf-name (car parsed))
               (src-line (cadr parsed))
               (target-buf (buffer-by-name buf-name)))
          (if target-buf
            ;; Buffer exists - switch to it and go to line
            (let* ((fr (app-state-frame app))
                   (win (current-window fr)))
              (buffer-attach! ed target-buf)
              (edit-window-buffer-set! win target-buf)
              (editor-goto-line ed (- src-line 1))
              (echo-message! echo (string-append "Jumped to " buf-name ":" (number->string src-line))))
            ;; Buffer doesn't exist - try to find file
            (let ((fp (let search ((bufs (buffer-list)))
                        (if (null? bufs) #f
                          (let ((b (car bufs)))
                            (if (string=? (buffer-name b) buf-name)
                              (buffer-file-path b)
                              (search (cdr bufs))))))))
              (if fp
                (begin
                  (let* ((content (guard (e [#t #f])
                                    (call-with-input-file fp
                                      (lambda (p) (get-string-all p)))))
                         (fr (app-state-frame app))
                         (win (current-window fr))
                         (buf (buffer-create! buf-name ed #f)))
                    (when content
                      (buffer-attach! ed buf)
                      (edit-window-buffer-set! win buf)
                      (buffer-file-path-set! buf fp)
                      (editor-set-text ed content)
                      (editor-goto-line ed (- src-line 1))
                      (echo-message! echo (string-append "Opened " fp ":" (number->string src-line))))))
                (echo-message! echo (string-append "Buffer not found: " buf-name)))))))))

  (define (cmd-org-agenda-todo app)
    "Toggle TODO state of the agenda item on the current line."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (line-num (editor-line-from-position ed pos))
           (parsed (agenda-parse-line text line-num)))
      (if (not parsed)
        (echo-message! echo "No agenda item on this line")
        (let* ((buf-name (car parsed))
               (src-line (cadr parsed))
               (target-buf (buffer-by-name buf-name)))
          (if (not target-buf)
            (echo-message! echo (string-append "Buffer not found: " buf-name))
            ;; Find the target buffer's file and toggle TODO
            (let ((fp (buffer-file-path target-buf)))
              (if (not fp)
                (echo-message! echo "Buffer has no file")
                (guard (e [#t (echo-message! echo "Error toggling TODO")])
                  (let* ((content (call-with-input-file fp
                                    (lambda (p) (get-string-all p))))
                         (lines (string-split content #\newline))
                         (idx (- src-line 1)))
                    (when (and (>= idx 0) (< idx (length lines)))
                      (let* ((line (list-ref lines idx))
                             (new-line
                               (cond
                                 ((string-contains line "TODO ")
                                  (let ((i (string-contains line "TODO ")))
                                    (string-append (substring line 0 i) "DONE "
                                                   (substring line (+ i 5) (string-length line)))))
                                 ((string-contains line "DONE ")
                                  (let ((i (string-contains line "DONE ")))
                                    (string-append (substring line 0 i) "TODO "
                                                   (substring line (+ i 5) (string-length line)))))
                                 (else line)))
                             (new-lines (let loop ((ls lines) (n 0) (acc '()))
                                          (if (null? ls) (reverse acc)
                                            (loop (cdr ls) (+ n 1)
                                                  (cons (if (= n idx) new-line (car ls)) acc)))))
                             (new-content (string-join new-lines "\n")))
                        (call-with-output-file fp
                          (lambda (p) (display new-content p))
                          'truncate)
                        ;; Update the agenda line in place
                        (let* ((agenda-text (editor-get-text ed))
                               (agenda-lines (string-split agenda-text #\newline))
                               (new-agenda-lines
                                 (let loop ((ls agenda-lines) (n 0) (acc '()))
                                   (if (null? ls) (reverse acc)
                                     (loop (cdr ls) (+ n 1)
                                           (cons (if (= n line-num)
                                                   (string-append "  " buf-name ":"
                                                                  (number->string src-line) ": "
                                                                  (string-trim new-line))
                                                   (car ls))
                                                 acc)))))
                               (new-agenda (string-join new-agenda-lines "\n")))
                          (editor-set-read-only ed #f)
                          (editor-set-text ed new-agenda)
                          (editor-set-read-only ed #t))
                        (echo-message! echo
                          (if (string-contains new-line "DONE")
                            "TODO -> DONE"
                            "DONE -> TODO")))))))))))))

  (define (cmd-smerge-mode app)
    "Toggle smerge mode -- report conflict count in current buffer."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (count (smerge-count-conflicts text)))
      (if (> count 0)
        (begin
          (echo-message! echo
            (string-append "Smerge: " (number->string count) " conflict"
                           (if (> count 1) "s" "") " found. "
                           "n/p=navigate, m=mine, o=other, b=both"))
          ;; Jump to first conflict
          (let-values (((mine sep other) (smerge-find-conflict text 0 'next)))
            (when mine (editor-goto-pos ed mine))))
        (echo-message! echo "No merge conflicts found"))))

  ;;;============================================================================
  ;;; Flyspell mode
  ;;;============================================================================

  (define *flyspell-active* #f)
  (define *flyspell-indicator* 1)

  (define (flyspell-is-word-char? ch)
    "Check if character is part of a word for spell-checking."
    (or (char-alphabetic? ch) (char=? ch #\')))

  (define (flyspell-extract-words text)
    "Extract word positions from text. Returns list of (word start end)."
    (let ((len (string-length text)))
      (let loop ((i 0) (words '()))
        (if (>= i len)
          (reverse words)
          (if (flyspell-is-word-char? (string-ref text i))
            ;; Found word start
            (let find-end ((j (+ i 1)))
              (if (or (>= j len) (not (flyspell-is-word-char? (string-ref text j))))
                ;; Word is text[i..j)
                (let ((word (substring text i j)))
                  (if (> (string-length word) 1)
                    (loop j (cons (list word i j) words))
                    (loop j words)))
                (find-end (+ j 1))))
            (loop (+ i 1) words))))))

  (define (cmd-flyspell-mode app)
    "Toggle flyspell mode: check buffer and underline misspelled words."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if *flyspell-active*
        ;; Turn off: clear indicators
        (begin
          (set! *flyspell-active* #f)
          (send-message ed SCI_SETINDICATORCURRENT *flyspell-indicator* 0)
          (send-message ed SCI_INDICATORCLEARRANGE 0 len)
          (echo-message! echo "Flyspell mode OFF"))
        ;; Turn on: scan and underline
        (begin
          (set! *flyspell-active* #t)
          ;; Setup indicator: INDIC_SQUIGGLE = 1, red color
          (send-message ed SCI_INDICSETSTYLE *flyspell-indicator* 1)
          (send-message ed SCI_INDICSETFORE *flyspell-indicator* #x0000FF)
          (send-message ed SCI_SETINDICATORCURRENT *flyspell-indicator* 0)
          ;; Clear old indicators
          (send-message ed SCI_INDICATORCLEARRANGE 0 len)
          ;; Check each word
          (let* ((words (flyspell-extract-words text))
                 (misspelled 0))
            (for-each
              (lambda (entry)
                (let ((word (car entry))
                      (start (cadr entry))
                      (end (caddr entry)))
                  (let ((suggestions (flyspell-check-word word)))
                    (when suggestions
                      (set! misspelled (+ misspelled 1))
                      (send-message ed SCI_INDICATORFILLRANGE start (- end start))))))
              words)
            (echo-message! echo
              (string-append "Flyspell: " (number->string misspelled) " misspelled in "
                             (number->string (length words)) " words")))))))

  ;;;============================================================================
  ;;; Custom groups
  ;;;============================================================================

  (define *custom-groups* (make-hash-table))

  (define (custom-group-add! group var-name)
    "Add a variable to a custom group."
    (let ((vars (or (hash-get *custom-groups* group) '())))
      (unless (member var-name vars)
        (hash-put! *custom-groups* group (cons var-name vars)))))

  ;;;============================================================================
  ;;; Face customization UI
  ;;;============================================================================

  (define *face-definitions* (make-hash-table))

  (define (face-set! name . props)
    "Define or update a face with properties."
    (hash-put! *face-definitions* name props))

  (define (face-get name)
    "Get face properties."
    (hash-get *face-definitions* name))

  ;;;============================================================================
  ;;; Advice system
  ;;;============================================================================

  (define *advice-before* (make-hash-table))
  (define *advice-after*  (make-hash-table))

  (define (advice-add! symbol where fn advice-name)
    "Add advice to a command symbol. WHERE is 'before or 'after."
    (let ((table (if (eq? where 'before) *advice-before* *advice-after*))
          (entry (cons fn advice-name)))
      (let ((existing (or (hash-get table symbol) '())))
        (hash-put! table symbol (cons entry existing)))))

  (define (advice-remove! symbol advice-name)
    "Remove named advice from a command symbol."
    (for-each
      (lambda (table)
        (let ((existing (or (hash-get table symbol) '())))
          (hash-put! table symbol
            (filter (lambda (e) (not (equal? (cdr e) advice-name))) existing))))
      (list *advice-before* *advice-after*)))

  (define (run-advice-before symbol app)
    "Run all before-advice for SYMBOL."
    (let ((advices (hash-get *advice-before* symbol)))
      (when advices
        (for-each (lambda (entry) ((car entry) app)) (reverse advices)))))

  (define (run-advice-after symbol app)
    "Run all after-advice for SYMBOL."
    (let ((advices (hash-get *advice-after* symbol)))
      (when advices
        (for-each (lambda (entry) ((car entry) app)) (reverse advices)))))

  (define (cmd-describe-advice app)
    "Show all active advice on commands."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (ed (current-editor app))
           (win (current-window fr))
           (buf (buffer-create! "*Advice*" ed))
           (lines (list "Command Advice"
                        "=============="
                        "")))
      (hash-for-each
        (lambda (sym advices)
          (for-each
            (lambda (entry)
              (set! lines (cons
                (string-append "  :before " (symbol->string sym) " -- " (cdr entry))
                lines)))
            advices))
        *advice-before*)
      (hash-for-each
        (lambda (sym advices)
          (for-each
            (lambda (entry)
              (set! lines (cons
                (string-append "  :after  " (symbol->string sym) " -- " (cdr entry))
                lines)))
            advices))
        *advice-after*)
      (when (= (length lines) 3)
        (set! lines (cons "  (no active advice)" lines)))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (editor-set-text ed (string-join (reverse lines) "\n"))
      (editor-goto-pos ed 0)
      (editor-set-read-only ed #t)))

  ;;;============================================================================
  ;;; Autoload system
  ;;;============================================================================

  (define *autoloads* (make-hash-table))

  (define (autoload! symbol file-path)
    "Register SYMBOL to be loaded from FILE-PATH on first use."
    (hash-put! *autoloads* symbol file-path))

  (define (autoload-resolve symbol)
    "If SYMBOL has an autoload, load the file and return #t, else #f."
    (let ((path (hash-get *autoloads* symbol)))
      (when path
        (hash-remove! *autoloads* symbol)
        (with-catch
          (lambda (e) #f)
          (lambda ()
            (load path)
            #t)))))

  (define (cmd-list-autoloads app)
    "Show registered autoloads."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (ed (current-editor app))
           (win (current-window fr))
           (buf (buffer-create! "*Autoloads*" ed))
           (lines (list "Registered Autoloads"
                        "===================="
                        "")))
      (hash-for-each
        (lambda (sym path)
          (set! lines (cons
            (string-append "  " (symbol->string sym) " -> " path)
            lines)))
        *autoloads*)
      (when (= (length lines) 3)
        (set! lines (cons "  (no autoloads registered)" lines)))
      (set! lines (append (reverse lines)
        (list "" "Use (autoload! 'symbol \"path.ss\") in ~/.jemacs-init to register.")))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (editor-set-text ed (string-join lines "\n"))
      (editor-goto-pos ed 0)
      (editor-set-read-only ed #t)))

  ;;;============================================================================
  ;;; Dynamic module loading
  ;;;============================================================================

  (define *loaded-modules* '())

  (define (cmd-load-module app)
    "Load a compiled module (.so or .ss) at runtime."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (path (echo-read-string echo "Load module: " row width)))
      (when (and path (> (string-length path) 0))
        (if (not (file-exists? path))
          (echo-error! echo (string-append "Module not found: " path))
          (with-catch
            (lambda (e)
              (echo-error! echo (string-append "Load error: " (safe-display-exception e))))
            (lambda ()
              (load path)
              (set! *loaded-modules* (cons path *loaded-modules*))
              (echo-message! echo (string-append "Loaded module: "
                (path-strip-directory path)))))))))

  (define (cmd-list-modules app)
    "Show loaded dynamic modules."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (ed (current-editor app))
           (win (current-window fr))
           (buf (buffer-create! "*Modules*" ed))
           (text (string-append
                   "Loaded Modules\n"
                   "==============\n\n"
                   (if (null? *loaded-modules*)
                     "  (none)\n"
                     (string-join (map (lambda (m) (string-append "  " m)) *loaded-modules*) "\n"))
                   "\n\nUse M-x load-module to load a module.\n")))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (editor-set-text ed text)
      (editor-goto-pos ed 0)
      (editor-set-read-only ed #t)))

  ;;;============================================================================
  ;;; Icomplete / Fido mode
  ;;;============================================================================

  (define *icomplete-mode* #f)

  (define (cmd-icomplete-mode app)
    "Toggle icomplete-mode (inline completion display)."
    (let ((echo (app-state-echo app)))
      (set! *icomplete-mode* (not *icomplete-mode*))
      (echo-message! echo (if *icomplete-mode*
                            "Icomplete mode ON (inline completions)"
                            "Icomplete mode OFF"))))

  (define (cmd-fido-mode app)
    "Toggle fido-mode (flex matching + icomplete)."
    (let ((echo (app-state-echo app)))
      (set! *icomplete-mode* (not *icomplete-mode*))
      (echo-message! echo (if *icomplete-mode*
                            "Fido mode ON (flex matching)"
                            "Fido mode OFF"))))

  ;;;============================================================================
  ;;; Marginalia (annotations in completions)
  ;;;============================================================================

  (define *marginalia-annotators* (make-hash-table))

  (define (marginalia-annotate! category annotator)
    "Register an annotator function for a completion CATEGORY."
    (hash-put! *marginalia-annotators* category annotator))

  ;;;============================================================================
  ;;; Embark action registry
  ;;;============================================================================

  (define *embark-actions* (make-hash-table))

  (define (embark-define-action! category name fn)
    "Register an action for completion candidates of CATEGORY."
    (let ((existing (or (hash-get *embark-actions* category) '())))
      (hash-put! *embark-actions* category (cons (cons name fn) existing))))

  ;;;============================================================================
  ;;; Persistent undo across sessions
  ;;;============================================================================

  (define *persistent-undo-dir*
    (string-append (or (getenv "HOME") ".") "/.jemacs-undo/"))

  (define (persistent-undo-file-for path)
    "Return the undo save file path for a given file path."
    (string-append *persistent-undo-dir*
      (let ((s (if (> (string-length path) 0) (substring path 1 (string-length path)) "unknown")))
        (list->string (map (lambda (c) (if (char=? c #\/) #\_ c)) (string->list s))))
      ".undo"))

  (define (cmd-undo-history-save app)
    "Save undo history for the current buffer to disk."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (buf (current-buffer-from-app app))
           (file (buffer-file-path buf)))
      (if (not file)
        (echo-message! echo "Buffer has no file -- cannot save undo history")
        (let ((undo-file (persistent-undo-file-for file))
              (text (editor-get-text ed)))
          (with-catch
            (lambda (e) (echo-message! echo (string-append "Error saving undo: " (safe-display-exception e))))
            (lambda ()
              (create-directory* *persistent-undo-dir*)
              (call-with-output-file undo-file
                (lambda (port)
                  (write (list 'undo-v1 file (string-length text)) port)
                  (newline port))
                'truncate)
              (echo-message! echo (string-append "Undo history saved: " undo-file))))))))

  (define (cmd-undo-history-load app)
    "Load undo history for the current buffer from disk."
    (let* ((echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (file (buffer-file-path buf)))
      (if (not file)
        (echo-message! echo "Buffer has no file -- cannot load undo history")
        (let ((undo-file (persistent-undo-file-for file)))
          (if (not (file-exists? undo-file))
            (echo-message! echo "No saved undo history for this file")
            (with-catch
              (lambda (e) (echo-message! echo (string-append "Error loading undo: " (safe-display-exception e))))
              (lambda ()
                (let ((data (call-with-input-file undo-file read)))
                  (echo-message! echo (string-append "Undo history loaded from: " undo-file))))))))))

  ;;;============================================================================
  ;;; Image thumbnails in dired
  ;;;============================================================================

  (define *image-extensions* '("png" "jpg" "jpeg" "gif" "bmp" "svg" "webp" "ico" "tiff"))

  (define (image-file? path)
    "Return #t if path has an image file extension."
    (let ((ext (string-downcase (path-extension path))))
      (member ext *image-extensions*)))

  (define (cmd-image-dired-display-thumbnail app)
    "Display thumbnail info for image under cursor in dired."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (buf (current-buffer-from-app app))
           (name (buffer-name buf)))
      (if (not (string-suffix? " [dired]" name))
        (echo-message! echo "Not in a dired buffer")
        (let* ((pos (editor-get-current-pos ed))
               (line (editor-get-line ed (editor-line-from-position ed pos)))
               (trimmed (safe-string-trim-both line)))
          (if (image-file? trimmed)
            (echo-message! echo (string-append "Image: " trimmed " [thumbnail view not available in TUI]"))
            (echo-message! echo "Not an image file"))))))

  (define (cmd-image-dired-show-all-thumbnails app)
    "List all image files in the current dired directory."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (buf (current-buffer-from-app app))
           (name (buffer-name buf)))
      (if (not (string-suffix? " [dired]" name))
        (echo-message! echo "Not in a dired buffer")
        (let* ((text (editor-get-text ed))
               (lines (string-split text #\newline))
               (images (filter (lambda (l) (image-file? (safe-string-trim-both l)))
                               lines)))
          (if (null? images)
            (echo-message! echo "No image files in this directory")
            (let ((listing (string-join (map (lambda (s) (safe-string-trim-both s)) images) "\n")))
              (echo-message! echo
                (string-append "Images (" (number->string (length images)) "): "
                  (string-join (map (lambda (s) (safe-string-trim-both s))
                                    (take images (min 5 (length images)))) ", ")
                  (if (> (length images) 5) "..." "")))))))))

  ;;;============================================================================
  ;;; Virtual dired
  ;;;============================================================================

  (define (cmd-virtual-dired app)
    "Create a virtual dired buffer from a list of file paths."
    (let* ((echo (app-state-echo app))
           (input (app-read-string app "Virtual dired files (space-separated): ")))
      (when (and input (> (string-length input) 0))
        (let* ((files (string-split input #\space))
               (content (string-join
                          (map (lambda (f)
                                 (string-append "  " (path-strip-directory f) "  -> " f))
                               files)
                          "\n")))
          (open-output-buffer app "*Virtual Dired*"
            (string-append "Virtual Dired:\n\n" content "\n"))
          (echo-message! echo (string-append "Virtual dired: " (number->string (length files)) " files"))))))

  (define (cmd-dired-from-find app)
    "Create a virtual dired from find command results."
    (let* ((echo (app-state-echo app))
           (pattern (app-read-string app "Find pattern (glob): ")))
      (when (and pattern (> (string-length pattern) 0))
        (let* ((buf (current-buffer-from-app app))
               (dir (or (and buf (buffer-file-path buf) (path-directory (buffer-file-path buf)))
                        (current-directory))))
          (guard (e [#t (echo-error! echo "find command failed")])
            (let ((out (run-process-capture "find" (list dir "-name" pattern "-type" "f"))))
              (if (and out (> (string-length out) 0))
                (open-output-buffer app (string-append dir " [find:" pattern "]")
                  (string-append "  " dir " (find: " pattern "):\n\n" out "\n"))
                (echo-message! echo (string-append "No files matching: " pattern)))))))))

  ;;;============================================================================
  ;;; Super/Hyper key mapping and global key remap
  ;;;============================================================================

  (define (cmd-key-translate app)
    "Define a key translation (input-decode-map equivalent)."
    (let* ((echo (app-state-echo app))
           (from (app-read-string app "Translate from key: ")))
      (when (and from (> (string-length from) 0))
        (let* ((to (app-read-string app "Translate to key: "))
               (from-ch (if (= (string-length from) 1) (string-ref from 0) #f))
               (to-ch (if (and to (= (string-length to) 1)) (string-ref to 0) #f)))
          (when (and from-ch to-ch)
            (key-translate! from-ch to-ch)
            (echo-message! echo (string-append "Key translation: " from " -> " to)))))))

  (define *super-key-mode* #f)

  (define (cmd-toggle-super-key-mode app)
    "Toggle super key mode (treat super as meta)."
    (let ((echo (app-state-echo app)))
      (set! *super-key-mode* (not *super-key-mode*))
      (echo-message! echo (if *super-key-mode*
                            "Super-key-mode enabled (super -> meta)"
                            "Super-key-mode disabled"))))

  (define (cmd-describe-key-translations app)
    "Show all active key translations."
    (let ((echo (app-state-echo app)))
      (echo-message! echo "Key translations: use key-translate to define")))

  ;;;============================================================================
  ;;; Display tables
  ;;;============================================================================

  (define *display-table* (make-hash-table))

  (define (display-table-set! char replacement)
    "Set a display table entry: show REPLACEMENT instead of CHAR."
    (hash-put! *display-table* char replacement))

  (define (display-table-get char)
    "Look up display table entry for CHAR."
    (hash-get *display-table* char))

  (define (cmd-set-display-table-entry app)
    "Set a display table entry to map one character to another."
    (let* ((echo (app-state-echo app))
           (from (app-read-string app "Display char (single): ")))
      (when (and from (= (string-length from) 1))
        (let ((to (app-read-string app "Display as: ")))
          (when (and to (> (string-length to) 0))
            (display-table-set! (string-ref from 0) to)
            (echo-message! echo (string-append "Display: " from " -> " to)))))))

  (define (cmd-describe-display-table app)
    "Show current display table entries."
    (let* ((echo (app-state-echo app))
           (entries (hash->list *display-table*)))
      (if (null? entries)
        (echo-message! echo "Display table: empty (default rendering)")
        (echo-message! echo
          (string-append "Display table: "
            (string-join
              (map (lambda (p) (string-append (string (car p)) " -> " (cdr p)))
                   entries)
              ", "))))))

  ;;;============================================================================
  ;;; Multi-server LSP support
  ;;;============================================================================

  (define *lsp-servers* (make-hash-table))

  (define (lsp-server-register! lang-id command)
    "Register an LSP server command for a language."
    (hash-put! *lsp-servers* lang-id command))

  (define (lsp-server-for lang-id)
    "Look up registered LSP server for a language."
    (hash-get *lsp-servers* lang-id))

  (define (cmd-lsp-set-server app)
    "Set LSP server command for a language."
    (let* ((echo (app-state-echo app))
           (lang (app-read-string app "Language ID: ")))
      (when (and lang (> (string-length lang) 0))
        (let ((cmd (app-read-string app "Server command: ")))
          (when (and cmd (> (string-length cmd) 0))
            (lsp-server-register! lang cmd)
            (echo-message! echo (string-append "LSP server for " lang ": " cmd)))))))

  (define (cmd-lsp-list-servers app)
    "List registered LSP servers."
    (let* ((echo (app-state-echo app))
           (entries (hash->list *lsp-servers*)))
      (if (null? entries)
        (echo-message! echo "No LSP servers registered")
        (let ((listing (string-join
                         (map (lambda (p) (string-append (car p) ": " (cdr p)))
                              entries)
                         ", ")))
          (echo-message! echo (string-append "LSP servers: " listing))))))

  ;;;============================================================================
  ;;; DevOps modes
  ;;;============================================================================

  (define (cmd-ansible-mode app)
    "Enable Ansible YAML mode -- sets YAML highlighting and provides ansible commands."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app)))
      (send-message ed SCI_SETLEXER SCLEX_YAML)
      (echo-message! echo "Ansible mode enabled (YAML lexer)")))

  (define (cmd-ansible-playbook app)
    "Run ansible-playbook on the current file."
    (let* ((buf (current-buffer-from-app app))
           (fp (buffer-file-path buf))
           (echo (app-state-echo app)))
      (if (not fp)
        (echo-message! echo "Buffer has no file")
        (let ((output (with-catch
                        (lambda (e) (string-append "Error: " (safe-display-exception e)))
                        (lambda ()
                          (or (run-process-capture "ansible-playbook" (list "--syntax-check" fp))
                              "No output")))))
          (open-output-buffer app "*Ansible*"
            (string-append "ansible-playbook --syntax-check " fp "\n\n" output "\n"))))))

  (define (cmd-systemd-mode app)
    "Enable systemd unit file mode -- conf-style highlighting."
    (let ((ed (current-editor app)))
      (send-message ed SCI_SETLEXER SCLEX_PROPERTIES)
      (echo-message! (app-state-echo app) "Systemd mode enabled (properties lexer)")))

  (define (cmd-kubernetes-mode app)
    "Enable Kubernetes manifest mode -- YAML highlighting with kubectl integration."
    (let ((ed (current-editor app)))
      (send-message ed SCI_SETLEXER SCLEX_YAML)
      (echo-message! (app-state-echo app) "Kubernetes mode enabled (YAML lexer)")))

  (define (cmd-kubectl app)
    "Run kubectl command interactively."
    (let* ((echo (app-state-echo app))
           (args (app-read-string app "kubectl: ")))
      (when (and args (> (string-length args) 0))
        (let ((output (with-catch
                        (lambda (e) (string-append "Error: " (safe-display-exception e)))
                        (lambda ()
                          (or (run-process-capture "kubectl" (string-split args #\space))
                              "No output")))))
          (open-output-buffer app "*Kubectl*"
            (string-append "$ kubectl " args "\n\n" output "\n"))))))

  (define (cmd-ssh-config-mode app)
    "Enable SSH config file mode -- conf-style highlighting."
    (let ((ed (current-editor app)))
      (send-message ed SCI_SETLEXER SCLEX_PROPERTIES)
      (echo-message! (app-state-echo app) "SSH config mode enabled (properties lexer)")))

  ;;;============================================================================
  ;;; Helm-style occur and dash documentation
  ;;;============================================================================

  (define (cmd-helm-occur app)
    "Helm-style occur: filter lines matching pattern interactively."
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (pattern (app-read-string app "Helm occur pattern: ")))
      (when (and pattern (> (string-length pattern) 0))
        (let* ((text (editor-get-text ed))
               (lines (string-split text #\newline))
               (matches (filter (lambda (l) (string-contains l pattern)) lines)))
          (if (null? matches)
            (echo-message! echo "No matches")
            (open-output-buffer app "*Helm Occur*"
              (string-append "Helm Occur: " pattern "\n\n"
                (string-join matches "\n") "\n")))))))

  (define (cmd-helm-dash app)
    "Search documentation -- uses man pages and apropos."
    (let* ((echo (app-state-echo app))
           (query (app-read-string app "Dash search: ")))
      (when (and query (> (string-length query) 0))
        (let* ((fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win))
               (output (or (run-process-capture "/usr/bin/man" (list "-k" query))
                           "(No results found)\n")))
          (let ((buf (buffer-create! (string-append "*Dash: " query "*") ed)))
            (buffer-attach! ed buf)
            (edit-window-buffer-set! win buf)
            (editor-set-text ed
              (string-append "Documentation Search: " query "\n"
                             "========================================\n\n"
                             output
                             "\n\nUse M-x man to view a specific man page.\n"))
            (echo-message! echo (string-append "Dash: found results for '" query "'")))))))

  ;;; Batch 14: Completion, AI, TRAMP/Remote

  ;; Selectrum mode
  (define (cmd-selectrum-mode app)
    "Toggle Selectrum mode -- alternative vertical completion."
    (let ((on (toggle-mode! 'selectrum)))
      (echo-message! (app-state-echo app)
        (if on "Selectrum mode: on (using narrowing)" "Selectrum mode: off"))))

  ;; Cape additional completion sources
  (define (cmd-cape-history app)
    "Cape history completion -- complete from minibuffer history."
    (let* ((echo (app-state-echo app))
           (choice (app-read-string app "History: ")))
      (if (and choice (> (string-length choice) 0))
        (echo-message! echo (string-append "Cape history: " choice))
        (echo-message! echo "No history selection"))))

  (define (cmd-cape-keyword app)
    "Cape keyword completion -- insert language keyword at point."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (buf (edit-window-buffer win))
           (ext (let ((fp (buffer-file-path buf))) (if fp (path-extension fp) "")))
           (keywords
             (cond
               ((member ext '(".ss" ".scm" ".sld" ".sls"))
                '("define" "lambda" "let" "let*" "letrec" "if" "cond" "case" "begin" "when"
                  "unless" "do" "and" "or" "not" "set!" "import" "export" "def" "defstruct"
                  "defclass" "defrule" "defsyntax" "match" "with" "try" "catch" "finally" "spawn"))
               ((member ext '(".py"))
                '("def" "class" "if" "elif" "else" "for" "while" "return" "import" "from"
                  "try" "except" "finally" "raise" "with" "as" "yield" "async" "await" "lambda"
                  "pass" "break" "continue" "global" "nonlocal" "assert" "del"))
               ((member ext '(".js" ".ts" ".jsx" ".tsx"))
                '("function" "const" "let" "var" "if" "else" "for" "while" "return" "import"
                  "export" "class" "extends" "new" "this" "super" "async" "await" "try" "catch"
                  "finally" "throw" "switch" "case" "default" "break" "continue"))
               ((member ext '(".go"))
                '("func" "var" "const" "type" "if" "else" "for" "range" "return" "struct"
                  "interface" "package" "import" "defer" "go" "chan" "select" "switch" "case"
                  "default" "break" "continue" "map" "make" "append" "len" "cap"))
               ((member ext '(".rs"))
                '("fn" "let" "mut" "if" "else" "for" "while" "loop" "match" "return"
                  "struct" "enum" "impl" "trait" "pub" "mod" "use" "crate" "self" "super"
                  "async" "await" "move" "ref" "where" "type" "const" "static" "unsafe"))
               ((member ext '(".c" ".h" ".cpp" ".hpp"))
                '("if" "else" "for" "while" "do" "switch" "case" "break" "continue" "return"
                  "struct" "union" "enum" "typedef" "const" "static" "extern" "volatile"
                  "sizeof" "void" "int" "char" "float" "double" "long" "short" "unsigned"))
               (else '()))))
      (if (null? keywords)
        (echo-message! echo "No keywords for this file type")
        (let ((choice (app-read-string app "Keyword: ")))
          (when (and choice (> (string-length choice) 0)
                     (member choice keywords))
            (let ((pos (editor-get-current-pos ed)))
              (editor-insert-text ed pos choice)))))))

  ;; AI features -- stubbed out (no JSON/HTTP modules available)

  (define (cmd-ai-inline-suggest app)
    "Toggle inline AI suggestions -- ghost text completion."
    (let ((on (toggle-mode! 'ai-inline)))
      (echo-message! (app-state-echo app)
        (if on "AI inline suggestions: on" "AI inline suggestions: off"))))

  (define (tui-ai-detect-language app)
    "Detect language from buffer file extension."
    (let* ((buf (current-buffer-from-app app))
           (file (and buf (buffer-file-path buf))))
      (if (and file (string? file))
        (let ((ext (path-extension file)))
          (cond
            ((member ext '(".ss" ".scm" ".sld" ".sls")) "Scheme")
            ((member ext '(".py")) "Python")
            ((member ext '(".rs")) "Rust")
            ((member ext '(".go")) "Go")
            ((member ext '(".c" ".h")) "C")
            ((member ext '(".cpp" ".cc" ".hpp")) "C++")
            ((member ext '(".js" ".jsx")) "JavaScript")
            ((member ext '(".ts" ".tsx")) "TypeScript")
            ((member ext '(".sh" ".bash")) "Shell/Bash")
            (else "code")))
        "code")))

  (define (tui-ai-request prompt code language)
    "Call AI API. Returns response string or #f.
     Stubbed: JSON/HTTP not available in this port."
    (echo-message! (make-initial-echo-state) "AI features not available (no HTTP/JSON modules)")
    #f)

  (define (cmd-ai-code-explain app)
    "Explain code at point or region using AI."
    (let ((echo (app-state-echo app)))
      (if (string=? (copilot-api-key) "")
        (echo-message! echo "Set OPENAI_API_KEY first (M-x copilot-mode)")
        (begin
          (echo-message! echo "AI: requesting explanation...")
          (with-catch
            (lambda (e)
              (echo-message! echo (string-append "AI error: " (safe-display-exception e))))
            (lambda ()
              (let* ((ed (current-editor app))
                     (text (editor-get-text ed))
                     (lang (tui-ai-detect-language app))
                     (response (tui-ai-request
                                 "Explain this code clearly and concisely."
                                 text lang)))
                (if response
                  (open-output-buffer app "*AI Explain*"
                    (string-append "Code Explanation (" lang ")\n"
                      (make-string 50 #\=) "\n\n" response "\n"))
                  (echo-message! echo "AI: no response received (not available)")))))))))

  (define (cmd-ai-code-refactor app)
    "Suggest refactoring for code at point or region using AI."
    (let ((echo (app-state-echo app)))
      (if (string=? (copilot-api-key) "")
        (echo-message! echo "Set OPENAI_API_KEY first (M-x copilot-mode)")
        (begin
          (echo-message! echo "AI: requesting refactoring suggestions...")
          (with-catch
            (lambda (e)
              (echo-message! echo (string-append "AI error: " (safe-display-exception e))))
            (lambda ()
              (let* ((ed (current-editor app))
                     (text (editor-get-text ed))
                     (lang (tui-ai-detect-language app))
                     (response (tui-ai-request
                                 "Suggest refactoring improvements. Show refactored code with explanations."
                                 text lang)))
                (if response
                  (open-output-buffer app "*AI Refactor*"
                    (string-append "Refactoring Suggestions (" lang ")\n"
                      (make-string 50 #\=) "\n\n" response "\n"))
                  (echo-message! echo "AI: no response received (not available)")))))))))

  ;; TRAMP/Remote editing

  (define (cmd-tramp-ssh-edit app)
    "Edit file via SSH. Fetches remote file content."
    (let* ((echo (app-state-echo app))
           (path (app-read-string app "SSH path (/ssh:host:path): ")))
      (when (and path (> (string-length path) 0))
        (cond
          ((string-prefix? "/ssh:" path)
           (let* ((rest (substring path 5 (string-length path)))
                  (colon (string-index rest #\:))
                  (host (if colon (substring rest 0 colon) rest))
                  (rpath (if colon (substring rest (+ colon 1) (string-length rest)) "~")))
             (echo-message! echo (string-append "SSH: fetching " host ":" rpath " ..."))
             (with-catch
               (lambda (e)
                 (echo-message! echo (string-append "SSH failed: " (safe-display-exception e))))
               (lambda ()
                 (let ((content (run-process-capture "ssh" (list host "cat" rpath))))
                   (if (or (not content) (string=? content ""))
                     (echo-message! echo (string-append "Could not read " host ":" rpath))
                     (let* ((name (string-append "[ssh:" host "]"
                                    (path-strip-directory rpath)))
                            (fr (app-state-frame app))
                            (win (current-window fr))
                            (ed (edit-window-editor win))
                            (buf (buffer-create! name ed #f)))
                       (buffer-attach! ed buf)
                       (edit-window-buffer-set! win buf)
                       (editor-set-text ed content)
                       (editor-goto-pos ed 0)
                       (echo-message! echo
                         (string-append "Opened " host ":" rpath)))))))))
          (else
           (echo-message! echo "Use format: /ssh:hostname:/path/to/file"))))))

  (define (cmd-tramp-docker-edit app)
    "Edit file in Docker container via docker exec cat."
    (let* ((echo (app-state-echo app))
           (path (app-read-string app "Docker path (/docker:name:path): ")))
      (when (and path (> (string-length path) 0))
        (cond
          ((string-prefix? "/docker:" path)
           (let* ((rest (substring path 8 (string-length path)))
                  (colon (string-index rest #\:))
                  (container (if colon (substring rest 0 colon) rest))
                  (rpath (if colon (substring rest (+ colon 1) (string-length rest)) "/")))
             (echo-message! echo (string-append "Docker: fetching " container ":" rpath " ..."))
             (with-catch
               (lambda (e)
                 (echo-message! echo (string-append "Docker failed: " (safe-display-exception e))))
               (lambda ()
                 (let ((content (run-process-capture "docker" (list "exec" container "cat" rpath))))
                   (if (or (not content) (string=? content ""))
                     (echo-message! echo (string-append "Could not read " container ":" rpath))
                     (let* ((name (string-append "[docker:" container "]"
                                    (path-strip-directory rpath)))
                            (fr (app-state-frame app))
                            (win (current-window fr))
                            (ed (edit-window-editor win))
                            (buf (buffer-create! name ed #f)))
                       (buffer-attach! ed buf)
                       (edit-window-buffer-set! win buf)
                       (editor-set-text ed content)
                       (editor-goto-pos ed 0)
                       (echo-message! echo
                         (string-append "Opened " container ":" rpath)))))))))
          (else
           (echo-message! echo "Use format: /docker:container:/path/to/file"))))))

  (define (cmd-tramp-remote-shell app)
    "Open remote shell via SSH -- runs ssh and displays session output."
    (let* ((echo (app-state-echo app))
           (host (app-read-string app "Remote host: ")))
      (when (and host (> (string-length host) 0))
        (echo-message! echo (string-append "Connecting to " host "..."))
        (with-catch
          (lambda (e)
            (echo-error! echo (string-append "SSH failed: " (safe-display-exception e))))
          (lambda ()
            (let ((output (or (run-process-capture "ssh" (list "-t" host)) "")))
              (let* ((ed (current-editor app))
                     (fr (app-state-frame app))
                     (buf-name (string-append "*ssh:" host "*"))
                     (buf (or (buffer-by-name buf-name)
                              (buffer-create! buf-name ed #f))))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! (current-window fr) buf)
                (editor-set-read-only ed #f)
                (editor-set-text ed
                  (string-append "-*- SSH: " host " -*-\n"
                    (make-string 60 #\-) "\n\n"
                    output
                    "\n" (make-string 60 #\-) "\n"
                    "Connection closed.\n"))
                (editor-set-save-point ed)
                (editor-goto-pos ed 0)
                (editor-set-read-only ed #t)
                (echo-message! echo (string-append "SSH session to " host " ended")))))))))

  (define (cmd-tramp-remote-compile app)
    "Run compilation command on remote host via SSH."
    (let* ((echo (app-state-echo app))
           (host (app-read-string app "Remote host: "))
           (cmd (and host (> (string-length host) 0)
                     (app-read-string app (string-append "Command on " host ": ")))))
      (when (and cmd (> (string-length cmd) 0))
        (echo-message! echo (string-append "Compiling on " host ": " cmd))
        (with-catch
          (lambda (e)
            (echo-error! echo (string-append "Remote compile failed: " (safe-display-exception e))))
          (lambda ()
            (let* ((quoted-cmd (string-append "'"
                                 (string-join (string-split cmd #\') "'\\''") "'"))
                   (output (or (run-process-capture "ssh" (list host quoted-cmd)) "")))
              (let* ((ed (current-editor app))
                     (fr (app-state-frame app))
                     (buf (or (buffer-by-name "*compilation*")
                              (buffer-create! "*compilation*" ed #f)))
                     (result-text (string-append
                                    "-*- Compilation (remote: " host ") -*-\n"
                                    "Command: ssh " host " " cmd "\n"
                                    (make-string 60 #\-) "\n\n"
                                    output
                                    "\n" (make-string 60 #\-) "\n"
                                    "Compilation finished\n")))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! (current-window fr) buf)
                (editor-set-read-only ed #f)
                (editor-set-text ed result-text)
                (editor-set-save-point ed)
                (editor-goto-pos ed 0)
                (editor-set-read-only ed #t)
                (echo-message! echo "Compilation finished"))))))))

  ;; Helm C-yasnippet
  (define (cmd-helm-c-yasnippet app)
    "Helm-style snippet browser with preview."
    (let* ((echo (app-state-echo app)))
      (echo-message! echo "Helm C-yasnippet: use M-x snippet-insert for snippet browsing")))

  ;;; Batch 15: Parity stubs

  (define (cmd-tree-sitter-mode app)
    "Toggle tree-sitter mode -- incremental parsing."
    (let ((on (toggle-mode! 'tree-sitter)))
      (echo-message! (app-state-echo app) (if on "Tree-sitter mode: on" "Tree-sitter mode: off"))))

  (define (cmd-tree-sitter-highlight-mode app)
    "Toggle tree-sitter highlighting -- uses language grammars."
    (let ((on (toggle-mode! 'tree-sitter-highlight)))
      (echo-message! (app-state-echo app) (if on "Tree-sitter highlighting: on" "Tree-sitter highlighting: off"))))

  (define (cmd-tool-bar-mode app)
    "Toggle tool bar display."
    (echo-message! (app-state-echo app) "Tool bar: N/A in terminal mode"))

  (define (cmd-mu4e app)
    "Launch mu4e email -- checks for mu installation."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (output (or (run-process-capture "/bin/sh"
                         (list "-c" "which mu 2>/dev/null && mu find --fields='d f s' --sortfield=date --reverse --maxnum=20 '' 2>/dev/null || echo 'mu not installed. Install with: apt install maildir-utils'"))
                       "mu not installed")))
      (let ((buf (buffer-create! "*mu4e*" ed)))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! win buf)
        (editor-set-text ed (string-append "mu4e -- Mail\n============\n" output "\n"))
        (echo-message! echo "mu4e: loaded"))))

  (define (cmd-notmuch app)
    "Launch notmuch search -- checks for notmuch installation."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (output (or (run-process-capture "/bin/sh"
                         (list "-c" "which notmuch 2>/dev/null && notmuch search --limit=20 --sort=newest-first '*' 2>/dev/null || echo 'notmuch not installed. Install with: apt install notmuch'"))
                       "notmuch not installed")))
      (let ((buf (buffer-create! "*notmuch*" ed)))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! win buf)
        (editor-set-text ed (string-append "notmuch -- Search\n============\n" output "\n"))
        (echo-message! echo "notmuch: loaded"))))

  (define (cmd-rcirc app)
    "Launch rcirc IRC client."
    (let* ((echo (app-state-echo app))
           (server (app-read-string app "IRC server (default: irc.libera.chat): ")))
      (when (and server (not (string=? server "")))
        (let* ((srv (if (string=? server "") "irc.libera.chat" server))
               (nick (or (app-read-string app "Nick: ") "jemacs-user"))
               (fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win))
               (buf (buffer-create! (string-append "*rcirc:" srv "*") ed)))
          (buffer-attach! ed buf)
          (edit-window-buffer-set! win buf)
          (editor-set-text ed
            (string-append "rcirc -- " srv "\n"
                           "================\n\n"
                           "Connecting to " srv ":6667 as " nick " ...\n\n"
                           "Note: Full IRC requires a dedicated client.\n"
                           "Use M-x compose-mail for email.\n"
                           "Use M-x shell for IRC via irssi/weechat.\n"))
          (editor-set-read-only ed #t)
          (echo-message! echo (string-append "Connected to " srv " as " nick))))))

  (define (cmd-eww-submit-form app)
    "Submit form in current EWW buffer. Parses [field: value] lines."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (editor-get-text ed)))
      (let loop ((lines (string-split text #\newline)) (fields '()))
        (if (null? lines)
          (if (null? fields)
            (echo-message! echo "No form fields found in buffer")
            (let ((params (string-join
                            (map (lambda (pair)
                                   (string-append (car pair) "=" (cdr pair)))
                                 fields) "&")))
              (echo-message! echo (string-append "Form data: " params))))
          (let ((line (car lines)))
            (if (and (> (string-length line) 4)
                     (char=? (string-ref line 0) #\[)
                     (string-contains line ": "))
              (let* ((inner (substring line 1 (- (string-length line) 1)))
                     (colon (string-contains inner ": "))
                     (name (substring inner 0 colon))
                     (val (substring inner (+ colon 2) (string-length inner))))
                (loop (cdr lines) (cons (cons name val) fields)))
              (loop (cdr lines) fields)))))))

  (define (cmd-eww-toggle-css app)
    "Toggle CSS rendering in EWW."
    (let ((on (toggle-mode! 'eww-css)))
      (echo-message! (app-state-echo app) (if on "EWW CSS: on" "EWW CSS: off"))))

  (define (cmd-eww-toggle-images app)
    "Toggle image display in EWW."
    (let ((on (toggle-mode! 'eww-images)))
      (echo-message! (app-state-echo app) (if on "EWW images: on" "EWW images: off"))))

  (define (cmd-screen-reader-mode app)
    "Toggle screen reader support."
    (let ((on (toggle-mode! 'screen-reader)))
      (echo-message! (app-state-echo app) (if on "Screen reader: on" "Screen reader: off"))))

  ;;;============================================================================
  ;;; Org-crypt -- encrypt/decrypt org entries with GPG
  ;;;============================================================================

  (define (tui-org-find-entry-bounds text pos)
    "Find the start and end of the org entry at POS.
     Returns (values start end heading-end)."
    (let* ((lines (string-split text #\newline))
           (len (string-length text)))
      (let loop ((i 0) (offset 0) (entry-start 0) (heading-end 0) (level 0))
        (if (>= i (length lines))
          (values entry-start len heading-end)
          (let* ((line (list-ref lines i))
                 (line-end (+ offset (string-length line) 1)))
            (cond
              ((and (> (string-length line) 0) (char=? (string-ref line 0) #\*))
               (let ((line-level (let count ((j 0))
                                   (if (and (< j (string-length line))
                                            (char=? (string-ref line j) #\*))
                                     (count (+ j 1)) j))))
                 (if (<= offset pos)
                   (loop (+ i 1) line-end offset line-end line-level)
                   (if (<= line-level level)
                     (values entry-start offset heading-end)
                     (loop (+ i 1) line-end entry-start heading-end level)))))
              (else
               (loop (+ i 1) line-end entry-start heading-end level))))))))

  (define (cmd-org-encrypt-entry app)
    "Encrypt the current org entry body with GPG (symmetric)."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed)))
      (let-values (((entry-start entry-end heading-end)
                    (tui-org-find-entry-bounds text pos)))
        (let ((body (substring text heading-end entry-end)))
          (if (or (string=? (safe-string-trim-both body) "")
                  (string-contains body "-----BEGIN PGP MESSAGE-----"))
            (echo-message! echo "Entry is empty or already encrypted")
            (with-catch
              (lambda (e)
                (echo-error! echo (string-append "Encryption failed: " (safe-display-exception e))))
              (lambda ()
                (let* ((fr (app-state-frame app))
                       (row (- (frame-height fr) 1))
                       (width (frame-width fr))
                       (pass (echo-read-string echo "Passphrase: " row width)))
                  (when (and pass (> (string-length pass) 0))
                    (let ((encrypted (run-process-with-input
                                      "gpg"
                                      '("--symmetric" "--armor"
                                        "--batch" "--yes"
                                        "--passphrase-fd" "0")
                                      (string-append pass "\n" body))))
                      (when (and encrypted (string-contains encrypted "BEGIN PGP"))
                        (let ((new-text (string-append
                                          (substring text 0 heading-end)
                                          "\n" encrypted "\n"
                                          (if (< entry-end (string-length text))
                                            (substring text entry-end (string-length text))
                                            ""))))
                          (editor-set-text ed new-text)
                          (editor-goto-pos ed pos)
                          (echo-message! echo "Entry encrypted")))))))))))))

  (define (cmd-org-decrypt-entry app)
    "Decrypt the current org entry body (GPG symmetric)."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed)))
      (let-values (((entry-start entry-end heading-end)
                    (tui-org-find-entry-bounds text pos)))
        (let ((body (substring text heading-end entry-end)))
          (if (not (string-contains body "-----BEGIN PGP MESSAGE-----"))
            (echo-message! echo "Entry is not encrypted")
            (with-catch
              (lambda (e)
                (echo-error! echo (string-append "Decryption failed: " (safe-display-exception e))))
              (lambda ()
                (let* ((pgp-start (string-contains body "-----BEGIN PGP MESSAGE-----"))
                       (pgp-end-marker "-----END PGP MESSAGE-----")
                       (pgp-end-pos (string-contains body pgp-end-marker))
                       (pgp-block (if pgp-end-pos
                                    (substring body pgp-start
                                      (+ pgp-end-pos (string-length pgp-end-marker)))
                                    (substring body pgp-start (string-length body))))
                       (fr (app-state-frame app))
                       (row (- (frame-height fr) 1))
                       (width (frame-width fr))
                       (pass (echo-read-string echo "Passphrase: " row width)))
                  (when (and pass (> (string-length pass) 0))
                    (let ((decrypted (run-process-with-input
                                      "gpg"
                                      '("--decrypt" "--batch" "--yes"
                                        "--passphrase-fd" "0")
                                      (string-append pass "\n" pgp-block))))
                      (when decrypted
                        (let ((new-text (string-append
                                          (substring text 0 heading-end)
                                          "\n" decrypted "\n"
                                          (if (< entry-end (string-length text))
                                            (substring text entry-end (string-length text))
                                            ""))))
                          (editor-set-text ed new-text)
                          (editor-goto-pos ed pos)
                          (echo-message! echo "Entry decrypted")))))))))))))

  ;;;============================================================================
  ;;; Initialization — top-level expressions wrapped in (let () ...)
  ;;;============================================================================

  (let ()
    ;; Initialize default custom groups
    (custom-group-add! "editing" "tab-width")
    (custom-group-add! "editing" "indent-tabs-mode")
    (custom-group-add! "editing" "require-final-newline")
    (custom-group-add! "display" "scroll-margin")
    (custom-group-add! "display" "show-paren-mode")
    (custom-group-add! "files" "global-auto-revert-mode")
    (custom-group-add! "files" "delete-trailing-whitespace-on-save")

    ;; Define some default faces
    (face-set! "default" 'fg: "white" 'bg: "black")
    (face-set! "region" 'bg: "blue")
    (face-set! "modeline" 'fg: "black" 'bg: "white")
    (face-set! "minibuffer" 'fg: "white" 'bg: "black")
    (face-set! "comment" 'fg: "gray" 'style: "italic")
    (face-set! "string" 'fg: "green")
    (face-set! "keyword" 'fg: "cyan" 'style: "bold")
    (face-set! "error" 'fg: "red" 'style: "bold")
    (face-set! "warning" 'fg: "yellow")
    (face-set! "success" 'fg: "green")

    ;; Marginalia annotators
    (marginalia-annotate! 'command
      (lambda (name)
        (let ((cmd (find-command (string->symbol name))))
          (if cmd " [command]" ""))))

    (marginalia-annotate! 'buffer
      (lambda (name)
        (let ((buf (buffer-by-name name)))
          (if buf
            (let ((file (buffer-file-path buf)))
              (if file (string-append " " file) " [no file]"))
            ""))))

    ;; Embark actions
    (embark-define-action! 'command "describe"
      (lambda (app candidate)
        (echo-message! (app-state-echo app)
          (string-append "Command: " candidate))))

    (embark-define-action! 'command "execute"
      (lambda (app candidate)
        (let ((cmd (find-command (string->symbol candidate))))
          (when cmd (cmd app)))))

    (embark-define-action! 'file "find-file"
      (lambda (app candidate)
        (echo-message! (app-state-echo app)
          (string-append "Would open: " candidate))))

    (embark-define-action! 'file "delete"
      (lambda (app candidate)
        (echo-message! (app-state-echo app)
          (string-append "Would delete: " candidate))))

    ;; Default LSP server registrations
    (lsp-server-register! "python" "pylsp")
    (lsp-server-register! "javascript" "typescript-language-server --stdio")
    (lsp-server-register! "typescript" "typescript-language-server --stdio")
    (lsp-server-register! "rust" "rust-analyzer")
    (lsp-server-register! "go" "gopls")
    (lsp-server-register! "c" "clangd")
    (lsp-server-register! "cpp" "clangd")

    (void))

) ;; end library
