#!chezscheme
;;; -*- Chez Scheme -*-
;;; AI inline code completion (Copilot-style) using OpenAI API.
;;; TUI implementation: shows suggestions in the echo area.
;;;
;;; Ported from gerbil-emacs/editor-extra-ai.ss to R6RS Chez Scheme.

(library (jerboa-emacs editor-extra-ai)
  (export
    ;; Copilot helpers
    copilot-get-context
    copilot-get-suffix
    copilot-detect-language
    copilot-request-completion
    ;; Copilot commands
    cmd-copilot-mode
    cmd-copilot-complete
    cmd-copilot-accept
    cmd-copilot-dismiss
    cmd-copilot-accept-completion
    cmd-copilot-next-completion
    ;; String inflection
    tui-inflection-split-to-tokens
    tui-tokens->snake
    tui-tokens->upper
    tui-tokens->kebab
    tui-tokens->camel
    tui-tokens->pascal
    tui-inflection-detect-style
    tui-inflection-next-style
    tui-inflection-apply
    tui-inflection-replace!
    tui-current-editor
    cmd-string-inflection-cycle
    cmd-string-inflection-snake-case
    cmd-string-inflection-camelcase
    cmd-string-inflection-upcase
    ;; Occur edit mode
    cmd-occur-edit-mode
    cmd-occur-commit-edits
    ;; wdired mode
    tui-dired-line?
    tui-dired-line-filename
    cmd-wdired-mode
    cmd-wdired-finish-edit
    cmd-wdired-abort
    ;; Project query-replace
    tui-pqr-grep-files
    tui-str-replace-all
    cmd-project-query-replace)

  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-directory path-strip-directory path-extension
                path-expand)
          (only (std srfi srfi-13) string-join string-contains string-prefix?
                string-index string-trim-both string-trim)
          (only (std misc string) string-split)
          (only (std text json)
            json-object->string read-json string->json-object)
          (only (std net request)
            http-post request-status request-text request-close)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (except (jerboa-emacs core) face-get)
          (jerboa-emacs buffer)
          (jerboa-emacs window)
          (jerboa-emacs echo)
          (only (jerboa-emacs persist)
            copilot-mode copilot-mode-set!
            copilot-api-key
            copilot-model copilot-model-set!
            copilot-api-url
            copilot-suggestion copilot-suggestion-set!
            copilot-suggestion-pos copilot-suggestion-pos-set!)
          (jerboa-emacs editor-extra-helpers))

  ;;;; ---- Local helper: occur-parse-source-name ----
  ;;;; (editor-extra-editing2 not yet ported, so define locally)

  (define (occur-parse-source-name text)
    "Parse source buffer name from *Occur* header: 'N matches for \"pat\" in NAME:'"
    (let ((in-pos (string-contains text " in ")))
      (and in-pos
           (let* ((after-in (+ in-pos 4))
                  (colon-pos (string-index text #\: after-in)))
             (and colon-pos
                  (substring text after-in colon-pos))))))

  ;;;==========================================================================
  ;;; Copilot helper: call OpenAI chat completions API
  ;;;==========================================================================

  (define (copilot-get-context ed max-chars)
    "Get buffer text before cursor (up to max-chars) as completion context."
    (let* ((pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (start (max 0 (- pos max-chars))))
      (if (> pos 0)
        (substring text start pos)
        "")))

  (define (copilot-get-suffix ed max-chars)
    "Get buffer text after cursor (up to max-chars) for suffix context."
    (let* ((pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text))
           (end (min len (+ pos max-chars))))
      (if (< pos len)
        (substring text pos end)
        "")))

  (define (copilot-detect-language app)
    "Detect programming language from the current buffer's filename."
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
            ((member ext '(".rb")) "Ruby")
            ((member ext '(".lua")) "Lua")
            ((member ext '(".java")) "Java")
            ((member ext '(".sh" ".bash")) "Shell/Bash")
            ((member ext '(".html" ".htm")) "HTML")
            ((member ext '(".css")) "CSS")
            ((member ext '(".sql")) "SQL")
            ((member ext '(".md" ".markdown")) "Markdown")
            ((member ext '(".org")) "Org-mode")
            (else "code")))
        "code")))

  (define (copilot-request-completion prefix suffix language)
    "Call OpenAI API for code completion. Returns suggestion string or #f."
    (when (string=? (copilot-api-key) "")
      (error 'copilot-request-completion "OPENAI_API_KEY not set"))
    (let* ((system-prompt
             (string-append
               "You are a code completion engine for " language ". "
               "Given the code context, provide ONLY the completion text that should "
               "be inserted at the cursor position. Do NOT repeat the existing code. "
               "Do NOT add explanations or markdown formatting. "
               "Provide a short, natural continuation (1-3 lines max). "
               "If no completion makes sense, respond with an empty string."))
           (user-msg
             (string-append
               "Complete the code at the cursor position [CURSOR]:\n\n"
               prefix "[CURSOR]" suffix))
           (body (json-object->string
                   (list->hash-table
                     (list
                       (cons "model" (copilot-model))
                       (cons "messages"
                             (list (list->hash-table
                                     (list (cons "role" "system")
                                           (cons "content" system-prompt)))
                                   (list->hash-table
                                     (list (cons "role" "user")
                                           (cons "content" user-msg)))))
                       (cons "max_tokens" 150)
                       (cons "temperature" 0.2)
                       (cons "stop" (list "\n\n\n"))))))
           (resp (http-post (copilot-api-url)
                   (list (cons "Content-Type" "application/json")
                         (cons "Authorization" (string-append "Bearer " (copilot-api-key))))
                   body)))
      (if (= (request-status resp) 200)
        (let* ((json-str (request-text resp))
               (result (call-with-port (open-input-string json-str) read-json))
               (choices (or (hash-get result "choices") (list)))
               (first-choice (and (pair? choices) (car choices)))
               (message (and first-choice (hash-get first-choice "message")))
               (content (and message (or (hash-get message "content") ""))))
          (request-close resp)
          (if (and content (string? content) (> (string-length (string-trim-both content)) 0))
            (string-trim-both content)
            #f))
        (begin
          (request-close resp)
          #f))))

  ;;;==========================================================================
  ;;; TUI Copilot commands
  ;;;==========================================================================

  (define (cmd-copilot-mode app)
    "Toggle copilot mode - AI-assisted code completion."
    (copilot-mode-set! (not (copilot-mode)))
    ;; Clear any pending suggestion when toggling off
    (unless (copilot-mode)
      (copilot-suggestion-set! #f))
    (echo-message! (app-state-echo app)
      (if (copilot-mode)
        (if (string=? (copilot-api-key) "")
          "Copilot mode: on (WARNING: OPENAI_API_KEY not set!)"
          (string-append "Copilot mode: on (model: " (copilot-model) ")"))
        "Copilot mode: off")))

  (define (cmd-copilot-complete app)
    "Request AI code completion at point. Shows suggestion in echo area."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app)))
      (cond
        ((string=? (copilot-api-key) "")
         (echo-message! echo "Copilot: set OPENAI_API_KEY environment variable"))
        (else
         (echo-message! echo "Copilot: requesting completion...")
         (guard (e (#t
                    (copilot-suggestion-set! #f)
                    (echo-message! echo
                      (string-append "Copilot error: "
                        (call-with-string-output-port
                          (lambda (p) (display-condition e p)))))))
           (let* ((prefix (copilot-get-context ed 2000))
                  (suffix (copilot-get-suffix ed 500))
                  (language (copilot-detect-language app))
                  (suggestion (copilot-request-completion prefix suffix language)))
             (if suggestion
               (begin
                 (copilot-suggestion-set! suggestion)
                 (copilot-suggestion-pos-set! (editor-get-current-pos ed))
                 ;; Show in echo area (TUI cannot do inline ghost text)
                 (let* ((preview (if (> (string-length suggestion) 80)
                                   (string-append (substring suggestion 0 77) "...")
                                   suggestion))
                        ;; Replace newlines with visible markers for echo display
                        (display-text (string-join
                                        (string-split preview #\newline)
                                        "\\n")))
                   (echo-message! echo
                     (string-append "Copilot> " display-text "  [TAB=accept, C-g=dismiss]"))))
               (begin
                 (copilot-suggestion-set! #f)
                 (echo-message! echo "Copilot: no suggestion")))))))))

  (define (cmd-copilot-accept app)
    "Accept the current copilot suggestion and insert it at point."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app)))
      (if (copilot-suggestion)
        (let ((suggestion (copilot-suggestion)))
          (copilot-suggestion-set! #f)
          ;; Insert at current position
          (let ((pos (editor-get-current-pos ed)))
            (editor-insert-text ed pos suggestion)
            (editor-goto-pos ed (+ pos (string-length suggestion))))
          (echo-message! echo "Copilot: suggestion accepted"))
        (echo-message! echo "Copilot: no pending suggestion"))))

  (define (cmd-copilot-dismiss app)
    "Dismiss the current copilot suggestion."
    (let ((echo (app-state-echo app)))
      (if (copilot-suggestion)
        (begin
          (copilot-suggestion-set! #f)
          (echo-message! echo "Copilot: suggestion dismissed"))
        (echo-message! echo "Copilot: no pending suggestion"))))

  (define (cmd-copilot-accept-completion app)
    "Accept copilot suggestion (alias for copilot-accept)."
    (cmd-copilot-accept app))

  (define (cmd-copilot-next-completion app)
    "Request next copilot suggestion (re-requests completion)."
    (cmd-copilot-complete app))

  ;;;==========================================================================
  ;;; String inflection - cycle naming conventions (TUI)
  ;;;==========================================================================

  (define (tui-inflection-split-to-tokens word)
    "Split a word into lowercase tokens: handles snake_case, UPPER_CASE, CamelCase, kebab-case."
    (let loop ((chars (string->list word)) (cur "") (tokens (list)))
      (cond
        ((null? chars)
         (if (> (string-length cur) 0)
           (reverse (cons (string-downcase cur) tokens))
           (reverse tokens)))
        ((or (char=? (car chars) #\_) (char=? (car chars) #\-))
         (if (> (string-length cur) 0)
           (loop (cdr chars) "" (cons (string-downcase cur) tokens))
           (loop (cdr chars) "" tokens)))
        ((and (char-upper-case? (car chars))
              (> (string-length cur) 0)
              (char-lower-case? (string-ref cur (- (string-length cur) 1))))
         (loop (cdr chars) (string (char-downcase (car chars)))
               (cons (string-downcase cur) tokens)))
        ((and (char-upper-case? (car chars))
              (> (string-length cur) 0)
              (char-upper-case? (string-ref cur (- (string-length cur) 1)))
              (not (null? (cdr chars)))
              (char-lower-case? (cadr chars)))
         (loop (cdr chars) (string (char-downcase (car chars)))
               (cons (string-downcase cur) tokens)))
        (else
         (loop (cdr chars) (string-append cur (string (char-downcase (car chars)))) tokens)))))

  (define (tui-tokens->snake ts)  (string-join ts "_"))
  (define (tui-tokens->upper ts)  (string-upcase (string-join ts "_")))
  (define (tui-tokens->kebab ts)  (string-join ts "-"))
  (define (tui-tokens->camel ts)
    (if (null? ts) ""
      (apply string-append (car ts)
             (map (lambda (t)
                    (if (= (string-length t) 0) ""
                      (string-append (string (char-upcase (string-ref t 0)))
                                     (substring t 1 (string-length t)))))
                  (cdr ts)))))
  (define (tui-tokens->pascal ts)
    (apply string-append
           (map (lambda (t)
                  (if (= (string-length t) 0) ""
                    (string-append (string (char-upcase (string-ref t 0)))
                                   (substring t 1 (string-length t)))))
                ts)))

  (define (tui-inflection-detect-style word)
    (cond
      ((string-contains word "_")
       (if (string=? word (string-upcase word)) 'upper 'snake))
      ((string-contains word "-") 'kebab)
      ((and (> (string-length word) 0)
            (char-upper-case? (string-ref word 0))) 'pascal)
      (else 'camel)))

  (define (tui-inflection-next-style current)
    (case current
      ((snake)  'camel)
      ((camel)  'pascal)
      ((pascal) 'upper)
      ((upper)  'kebab)
      ((kebab)  'snake)
      (else     'camel)))

  (define (tui-inflection-apply tokens style)
    (case style
      ((snake)  (tui-tokens->snake tokens))
      ((upper)  (tui-tokens->upper tokens))
      ((kebab)  (tui-tokens->kebab tokens))
      ((camel)  (tui-tokens->camel tokens))
      ((pascal) (tui-tokens->pascal tokens))
      (else     (tui-tokens->snake tokens))))

  (define (tui-inflection-replace! ed ws we new-word)
    "Replace text in editor from ws to we with new-word using Scintilla target API."
    (send-message ed SCI_SETTARGETSTART ws 0)
    (send-message ed SCI_SETTARGETEND we 0)
    (send-message/string ed SCI_REPLACETARGET new-word)
    (send-message ed SCI_GOTOPOS (+ ws (string-length new-word)) 0))

  (define (tui-current-editor app)
    "Get current editor from TUI app state."
    (edit-window-editor (current-window (app-state-frame app))))

  (define (cmd-string-inflection-cycle app)
    "Cycle word at point through naming conventions: snake->camel->PascalCase->UPPER->kebab."
    (let* ((ed   (tui-current-editor app))
           (echo (app-state-echo app))
           (pos  (editor-get-current-pos ed)))
      (let-values (((ws we) (word-bounds-at ed pos)))
        (if (not ws)
          (echo-error! echo "No word at point")
          (let* ((text  (editor-get-text ed))
                 (word  (substring text ws we))
                 (tokens (tui-inflection-split-to-tokens word))
                 (style  (tui-inflection-detect-style word))
                 (next   (tui-inflection-next-style style))
                 (new-word (tui-inflection-apply tokens next)))
            (tui-inflection-replace! ed ws we new-word)
            (echo-message! echo
              (string-append word " -> " new-word " (" (symbol->string next) ")")))))))

  (define (cmd-string-inflection-snake-case app)
    "Convert word at point to snake_case."
    (let* ((ed (tui-current-editor app)) (echo (app-state-echo app))
           (pos (editor-get-current-pos ed)))
      (let-values (((ws we) (word-bounds-at ed pos)))
        (if (not ws) (echo-error! echo "No word at point")
          (let* ((text (editor-get-text ed))
                 (word (substring text ws we))
                 (new-word (tui-tokens->snake (tui-inflection-split-to-tokens word))))
            (tui-inflection-replace! ed ws we new-word)
            (echo-message! echo (string-append word " -> " new-word)))))))

  (define (cmd-string-inflection-camelcase app)
    "Convert word at point to camelCase."
    (let* ((ed (tui-current-editor app)) (echo (app-state-echo app))
           (pos (editor-get-current-pos ed)))
      (let-values (((ws we) (word-bounds-at ed pos)))
        (if (not ws) (echo-error! echo "No word at point")
          (let* ((text (editor-get-text ed))
                 (word (substring text ws we))
                 (new-word (tui-tokens->camel (tui-inflection-split-to-tokens word))))
            (tui-inflection-replace! ed ws we new-word)
            (echo-message! echo (string-append word " -> " new-word)))))))

  (define (cmd-string-inflection-upcase app)
    "Convert word at point to UPPER_CASE."
    (let* ((ed (tui-current-editor app)) (echo (app-state-echo app))
           (pos (editor-get-current-pos ed)))
      (let-values (((ws we) (word-bounds-at ed pos)))
        (if (not ws) (echo-error! echo "No word at point")
          (let* ((text (editor-get-text ed))
                 (word (substring text ws we))
                 (new-word (tui-tokens->upper (tui-inflection-split-to-tokens word))))
            (tui-inflection-replace! ed ws we new-word)
            (echo-message! echo (string-append word " -> " new-word)))))))

  ;;;==========================================================================
  ;;; Occur edit mode (TUI) - make *Occur* buffer editable
  ;;;==========================================================================

  (define *tui-occur-edit-originals* (make-hash-table)) ; line-num -> original-text

  (define (cmd-occur-edit-mode app)
    "Enable editing in *Occur* buffer. C-c C-c commits changes back to source buffer."
    (let* ((buf  (current-buffer-from-app app))
           (echo (app-state-echo app))
           (ed   (current-editor app)))
      (if (not (string=? (buffer-name buf) "*Occur*"))
        (echo-error! echo "Not in *Occur* buffer")
        (begin
          (let* ((text  (editor-get-text ed))
                 (lines (string-split text #\newline)))
            (hashtable-clear! *tui-occur-edit-originals*)
            (for-each
              (lambda (line)
                (let ((colon (string-index line #\:)))
                  (when (and colon (> colon 0)
                             (char-numeric? (string-ref line 0)))
                    (let ((lnum (string->number (substring line 0 colon))))
                      (when lnum
                        (hash-put! *tui-occur-edit-originals* lnum
                          (if (< (+ colon 1) (string-length line))
                            (substring line (+ colon 1) (string-length line))
                            "")))))))
              lines)
            (editor-set-read-only ed #f)
            (echo-message! echo
              "Occur edit ON - edit lines then C-c C-c to commit"))))))

  (define (cmd-occur-commit-edits app)
    "Commit *Occur* edits back to source buffer."
    (let* ((buf    (current-buffer-from-app app))
           (echo   (app-state-echo app))
           (ed     (current-editor app)))
      (if (not (string=? (buffer-name buf) "*Occur*"))
        (echo-error! echo "Not in *Occur* buffer")
        (let* ((full-text   (editor-get-text ed))
               (source-name (occur-parse-source-name full-text))
               (source      (and source-name (buffer-by-name source-name))))
          (if (not source)
            (echo-error! echo "Source buffer not found")
            (let* ((occur-lines (string-split full-text #\newline))
                   (changes
                    (let loop ((ls occur-lines) (acc (list)))
                      (if (null? ls) (reverse acc)
                        (let* ((line (car ls))
                               (colon (string-index line #\:)))
                          (if (and colon (> colon 0)
                                   (char-numeric? (string-ref line 0)))
                            (let ((lnum (string->number (substring line 0 colon))))
                              (if lnum
                                (let* ((new-text (if (< (+ colon 1) (string-length line))
                                                   (substring line (+ colon 1) (string-length line))
                                                   ""))
                                       (orig (hash-get *tui-occur-edit-originals* lnum)))
                                  (if (and orig (not (string=? new-text orig)))
                                    (loop (cdr ls) (cons (cons lnum new-text) acc))
                                    (loop (cdr ls) acc)))
                                (loop (cdr ls) acc)))
                            (loop (cdr ls) acc)))))))
              (if (null? changes)
                (begin
                  (editor-set-read-only ed #t)
                  (echo-message! echo "No changes to commit"))
                (begin
                  (buffer-attach! ed source)
                  (edit-window-buffer-set! (current-window (app-state-frame app)) source)
                  (let* ((src-text  (editor-get-text ed))
                         (src-lines (list->vector (string-split src-text #\newline)))
                         (n-lines   (vector-length src-lines)))
                    (for-each
                      (lambda (change)
                        (when (and (> (car change) 0) (<= (car change) n-lines))
                          (vector-set! src-lines (- (car change) 1) (cdr change))))
                      changes)
                    (let ((new-src (string-join (vector->list src-lines) "\n")))
                      (editor-set-read-only ed #f)
                      (editor-set-text ed new-src)))
                  (echo-message! echo
                    (string-append (number->string (length changes))
                                   " change(s) applied to " source-name))))))))))

  ;;;==========================================================================
  ;;; wdired mode (TUI) - edit filenames in dired buffer
  ;;;==========================================================================

  (define *tui-wdired-originals* (make-hash-table)) ; buffer-name -> vector of original lines

  (define (tui-dired-line? str)
    (and (>= (string-length str) 10)
         (or (char=? (string-ref str 0) #\-)
             (char=? (string-ref str 0) #\d)
             (char=? (string-ref str 0) #\l))
         (or (char=? (string-ref str 1) #\r)
             (char=? (string-ref str 1) #\-))))

  (define (tui-dired-line-filename str)
    "Extract filename from dired listing line (after 8 space-separated fields)."
    (let loop ((i 0) (fields 0) (in-ws #t))
      (cond
        ((>= i (string-length str)) #f)
        ((char=? (string-ref str i) #\space) (loop (+ i 1) fields #t))
        (in-ws (if (= fields 8)
                 (substring str i (string-length str))
                 (loop (+ i 1) (+ fields 1) #f)))
        (else (loop (+ i 1) fields #f)))))

  (define (cmd-wdired-mode app)
    "Enable wdired: make filenames in dired buffer editable. C-c C-c commits."
    (let* ((buf  (current-buffer-from-app app))
           (echo (app-state-echo app))
           (name (buffer-name buf)))
      (if (not (or (string=? name "*Dired*")
                   (string-prefix? "*dired:" name)))
        (echo-error! echo "Not in a dired buffer")
        (let* ((ed   (current-editor app))
               (text (editor-get-text ed)))
          (hash-put! *tui-wdired-originals* name
            (list->vector (string-split text #\newline)))
          (editor-set-read-only ed #f)
          (echo-message! echo
            "wdired: edit filenames, C-c C-c to commit, C-c C-k to abort")))))

  (define (cmd-wdired-finish-edit app)
    "Commit wdired renames."
    (let* ((buf  (current-buffer-from-app app))
           (echo (app-state-echo app))
           (name (buffer-name buf)))
      (if (not (hash-get *tui-wdired-originals* name))
        (echo-error! echo "Not in wdired mode")
        (let* ((ed        (current-editor app))
               (text      (editor-get-text ed))
               (cur-lines (string-split text #\newline))
               (orig-vec  (hash-get *tui-wdired-originals* name))
               (renames   (list)))
          (let loop ((cur cur-lines) (i 0) (renames (list)))
            (if (or (null? cur) (>= i (vector-length orig-vec)))
              (let ((renames (reverse renames)))
                (if (null? renames)
                  (begin
                    (hash-remove! *tui-wdired-originals* name)
                    (editor-set-read-only ed #t)
                    (echo-message! echo "wdired: no renames"))
                  (let* ((dir-line (if (> (length cur-lines) 0) (car cur-lines) ""))
                         (dir      (string-trim dir-line))
                         (ok-count 0) (err-count 0))
                    (for-each
                      (lambda (rename)
                        (let* ((old-f (string-append dir "/" (car rename)))
                               (new-f (string-append dir "/" (cdr rename)))
                               (result
                                (guard (e (#t #f))
                                  (let-values (((to-stdin from-stdout from-stderr pid)
                                                (open-process-ports
                                                  (string-append "mv -- " old-f " " new-f)
                                                  (buffer-mode block)
                                                  (native-transcoder))))
                                    (close-port to-stdin)
                                    (close-port from-stdout)
                                    (close-port from-stderr)
                                    #t))))
                          (if result
                            (set! ok-count (+ ok-count 1))
                            (set! err-count (+ err-count 1)))))
                      renames)
                    (hash-remove! *tui-wdired-originals* name)
                    (editor-set-read-only ed #t)
                    (echo-message! echo
                      (string-append "wdired: " (number->string ok-count)
                                     " rename(s), " (number->string err-count) " error(s)")))))
              (let* ((cl (car cur))
                     (ol (vector-ref orig-vec i)))
                (if (and (tui-dired-line? ol) (tui-dired-line? cl))
                  (let ((old-name (tui-dired-line-filename ol))
                        (new-name (tui-dired-line-filename cl)))
                    (if (and old-name new-name (not (string=? old-name new-name)))
                      (loop (cdr cur) (+ i 1) (cons (cons old-name new-name) renames))
                      (loop (cdr cur) (+ i 1) renames)))
                  (loop (cdr cur) (+ i 1) renames)))))))))

  (define (cmd-wdired-abort app)
    "Abort wdired: restore original dired buffer."
    (let* ((buf  (current-buffer-from-app app))
           (echo (app-state-echo app))
           (name (buffer-name buf)))
      (if (not (hash-get *tui-wdired-originals* name))
        (echo-error! echo "Not in wdired mode")
        (let* ((ed   (current-editor app))
               (orig (hash-get *tui-wdired-originals* name))
               (text (string-join (vector->list orig) "\n")))
          (editor-set-read-only ed #f)
          (editor-set-text ed text)
          (editor-set-read-only ed #t)
          (hash-remove! *tui-wdired-originals* name)
          (editor-set-read-only ed #t)
          (echo-message! echo "wdired: aborted")))))

  ;;;==========================================================================
  ;;; project-query-replace (TUI): replace-all across all project files
  ;;;==========================================================================

  (define (tui-pqr-grep-files root pattern)
    "Use grep to find all project files containing pattern. Returns list of paths."
    (guard (e (#t '()))
      (let* ((cmd (string-append "grep -rli " pattern " " root
                    " --include='*.ss' --include='*.scm'"
                    " --include='*.py' --include='*.js' --include='*.ts'"
                    " --include='*.go' --include='*.rs'"
                    " --include='*.c' --include='*.h'"
                    " --include='*.cpp' --include='*.hpp'"
                    " --include='*.rb' --include='*.java'"
                    " --include='*.md' --include='*.txt' 2>/dev/null"))
             (output (let-values (((to-stdin from-stdout from-stderr pid)
                                   (open-process-ports cmd (buffer-mode block) (native-transcoder))))
                       (close-port to-stdin)
                       (let ((out (get-string-all from-stdout)))
                         (close-port from-stdout)
                         (close-port from-stderr)
                         (if (eof-object? out) #f out)))))
        (if output
          (filter (lambda (s) (> (string-length s) 0))
                  (string-split output #\newline))
          '()))))

  (define (tui-str-replace-all str from to)
    "Replace all case-insensitive occurrences of from with to in str."
    (let ((from-lower (string-downcase from))
          (from-len   (string-length from)))
      (let loop ((pos 0) (acc ""))
        (let* ((rest (substring str pos (string-length str)))
               (idx  (string-contains (string-downcase rest) from-lower)))
          (if (not idx)
            (string-append acc rest)
            (loop (+ pos idx from-len)
                  (string-append acc
                                 (substring rest 0 idx)
                                 to)))))))

  (define (cmd-project-query-replace app)
    "Replace string across all project files (TUI: replace-all, no per-match interaction)."
    (let* ((fr   (app-state-frame app))
           (echo (app-state-echo app))
           (row  (- (frame-height fr) 1))
           (w    (frame-width fr))
           (from-str (echo-read-string echo "Project replace: " row w)))
      (when (and from-str (> (string-length from-str) 0))
        (let ((to-str (echo-read-string echo
                        (string-append "Replace \"" from-str "\" with: ") row w)))
          (when to-str
            (let* ((root (guard (e (#t (current-directory)))
                           (project-find-root (current-directory))))
                   (_ (echo-message! echo (string-append "Searching " root " ...")))
                   (files (tui-pqr-grep-files root from-str))
                   (file-count 0))
              (if (null? files)
                (echo-message! echo (string-append "No matches for: " from-str))
                (begin
                  (for-each
                    (lambda (file-path)
                      (guard (e (#t (void)))
                        (let* ((p       (open-input-file file-path))
                               (content (get-string-all p)))
                          (close-port p)
                          (when content
                            (let ((new-content (tui-str-replace-all content from-str to-str)))
                              (when (not (string=? content new-content))
                                (call-with-output-file file-path
                                  (lambda (p) (display new-content p)))
                                (set! file-count (+ file-count 1))))))))
                    files)
                  (echo-message! echo
                    (string-append "Replaced in " (number->string file-count)
                                   " of " (number->string (length files))
                                   " file(s)"))))))))))

) ;; end library
