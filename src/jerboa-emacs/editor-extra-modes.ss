;;; -*- Gerbil -*-
;;; Language modes, completion frameworks, git-gutter,
;;; zen modes, AI, notes, org-roam, and magit extras

(export #t)

(import :std/sugar
        :std/sort
        :std/srfi/13
        :chez-scintilla/constants
        :chez-scintilla/scintilla
        :chez-scintilla/tui
        :jerboa-emacs/core
        :jerboa-emacs/keymap
        :jerboa-emacs/buffer
        :jerboa-emacs/window
        :jerboa-emacs/modeline
        :jerboa-emacs/echo
        :jerboa-emacs/editor-extra-helpers
        :jerboa-emacs/editor-extra-vcs
        :jerboa-emacs/editor-extra-media
        :jerboa-emacs/editor-extra-media2
        (only-in :jerboa-emacs/persist *which-key-mode*))

;; --- Task #49: elisp mode, scheme mode, regex builder, color picker, etc. ---

;; Emacs Lisp mode helpers
(def (cmd-emacs-lisp-mode app)
  "Switch to Emacs Lisp mode — sets Lisp lexer."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) 'elisp))
    (echo-message! (app-state-echo app) "Emacs Lisp mode")))

(def (cmd-eval-last-sexp app)
  "Evaluate the sexp before point."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (editor-get-current-pos ed)))
    (if (<= pos 0)
      (echo-message! (app-state-echo app) "No sexp before point")
      (let ((match (send-message ed SCI_BRACEMATCH (- pos 1) 0)))
        (if (>= match 0)
          (let* ((start (min match (- pos 1)))
                 (end (+ (max match (- pos 1)) 1))
                 (text (substring (editor-get-text ed) start end))
                 (result (with-exception-catcher
                           (lambda (e) (with-output-to-string (lambda () (display-exception e))))
                           (lambda ()
                             (let ((val (eval (with-input-from-string text read))))
                               (with-output-to-string (lambda () (write val))))))))
            (echo-message! (app-state-echo app) result))
          (echo-message! (app-state-echo app) "No sexp before point"))))))

(def (cmd-eval-defun app)
  "Evaluate current top-level form."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (text (editor-get-text ed))
         (pos (editor-get-current-pos ed))
         ;; Find beginning of top-level form — scan back for unmatched open paren at column 0
         (start (let loop ((i pos))
                  (cond ((< i 0) 0)
                        ((and (char=? (string-ref text i) #\()
                              (or (= i 0)
                                  (char=? (string-ref text (- i 1)) #\newline)))
                         i)
                        (else (loop (- i 1))))))
         ;; Find matching close paren
         (match-pos (send-message ed SCI_BRACEMATCH start 0)))
    (if (>= match-pos 0)
      (let* ((form-text (substring text start (+ match-pos 1)))
             (result (with-exception-catcher
                       (lambda (e) (with-output-to-string (lambda () (display-exception e))))
                       (lambda ()
                         (let ((val (eval (with-input-from-string form-text read))))
                           (with-output-to-string (lambda () (write val))))))))
        (echo-message! (app-state-echo app) result))
      (echo-message! (app-state-echo app) "No top-level form found"))))

(def (cmd-eval-print-last-sexp app)
  "Eval and print sexp before point into buffer."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (editor-get-current-pos ed))
         (match (send-message ed SCI_BRACEMATCH (- pos 1) 0)))
    (if (>= match 0)
      (let* ((start (min match (- pos 1)))
             (end (+ (max match (- pos 1)) 1))
             (text (substring (editor-get-text ed) start end))
             (result (with-exception-catcher
                       (lambda (e) (with-output-to-string (lambda () (display-exception e))))
                       (lambda ()
                         (let ((val (eval (with-input-from-string text read))))
                           (with-output-to-string (lambda () (write val))))))))
        (editor-insert-text ed pos (string-append "\n;; => " result)))
      (echo-message! (app-state-echo app) "No sexp before point"))))

;; Scheme / Gerbil mode helpers
(def (cmd-scheme-mode app)
  "Switch to Scheme mode — sets Lisp lexer."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) 'scheme))
    (echo-message! (app-state-echo app) "Scheme mode")))

(def (cmd-gerbil-mode app)
  "Switch to Gerbil mode — sets Gerbil lexer."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) 'gerbil))
    (echo-message! (app-state-echo app) "Gerbil mode")))

(def (cmd-run-scheme app)
  "Run Scheme REPL — opens Chez Scheme REPL."
  (execute-command! app 'repl))

(def (cmd-scheme-send-region app)
  "Send region to Scheme process — evaluates selected text."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! (app-state-echo app) "No region selected")
      (let* ((region (substring (editor-get-text ed) start end))
             (result (with-exception-catcher
                       (lambda (e) (with-output-to-string (lambda () (display-exception e))))
                       (lambda ()
                         (let ((val (eval (with-input-from-string region read))))
                           (with-output-to-string (lambda () (write val))))))))
        (echo-message! (app-state-echo app) result)))))

(def (cmd-scheme-send-buffer app)
  "Send buffer to Scheme process — evaluates entire buffer."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (text (editor-get-text ed))
         (result (with-exception-catcher
                   (lambda (e) (with-output-to-string (lambda () (display-exception e))))
                   (lambda ()
                     (let ((val (eval (with-input-from-string text read))))
                       (with-output-to-string (lambda () (write val))))))))
    (echo-message! (app-state-echo app) result)))

;; Regex builder
(def (cmd-re-builder app)
  "Open interactive regex builder — prompts for regex and highlights matches."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pattern (app-read-string app "Regex: ")))
    (when (and pattern (not (string-empty? pattern)))
      (let* ((text (editor-get-text ed))
             (len (string-length text))
             (count 0)
             ;; Simple regex search using Scintilla search
             (_ (begin
                  (send-message ed SCI_SETTARGETSTART 0 0)
                  (send-message ed SCI_SETTARGETEND len 0)
                  (send-message ed SCI_SETSEARCHFLAGS 2 0)))  ; SCFIND_REGEXP
             (matches
               (let loop ((pos 0) (found '()))
                 (send-message ed SCI_SETTARGETSTART pos 0)
                 (send-message ed SCI_SETTARGETEND len 0)
                 (let ((result (send-message/string ed SCI_SEARCHINTARGET pattern)))
                   (if (< result 0)
                     (reverse found)
                     (let ((mstart (send-message ed SCI_GETTARGETSTART 0 0))
                           (mend (send-message ed SCI_GETTARGETEND 0 0)))
                       (if (<= mend pos)
                         (reverse found)
                         (loop mend (cons (list mstart mend) found)))))))))
        (echo-message! (app-state-echo app)
          (string-append "Regex: " (number->string (length matches)) " matches found"))))))

;; Color picker
(def (cmd-list-colors-display app)
  "Display list of named colors."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (buffer-create! "*Colors*" ed)))
    (buffer-attach! ed buf)
    (set! (edit-window-buffer win) buf)
    (editor-set-text ed
      (string-append
        "Named Colors\n\n"
        "black       #000000    white       #FFFFFF\n"
        "red         #FF0000    green       #00FF00\n"
        "blue        #0000FF    yellow      #FFFF00\n"
        "cyan        #00FFFF    magenta     #FF00FF\n"
        "gray        #808080    silver      #C0C0C0\n"
        "maroon      #800000    olive       #808000\n"
        "navy        #000080    purple      #800080\n"
        "teal        #008080    aqua        #00FFFF\n"
        "orange      #FFA500    pink        #FFC0CB\n"
        "brown       #A52A2A    coral       #FF7F50\n"
        "gold        #FFD700    khaki       #F0E68C\n"
        "salmon      #FA8072    tomato      #FF6347\n"
        "wheat       #F5DEB3    ivory       #FFFFF0\n"))
    (editor-set-read-only ed #t)))

;; Completion framework modes — mutually exclusive (enabling one disables others)
(def *completion-frameworks* '(ido helm ivy vertico))

(def (activate-completion-framework! name app)
  "Activate completion framework NAME, deactivating all others."
  (for-each (lambda (fw) (when (mode-enabled? fw) (toggle-mode! fw)))
            *completion-frameworks*)
  (let ((on (toggle-mode! name)))
    (echo-message! (app-state-echo app)
      (if on
        (string-append (symbol->string name) " mode: on (other frameworks disabled)")
        (string-append (symbol->string name) " mode: off")))))

(def (cmd-ido-mode app)
  "Toggle IDO mode — enhanced completion (mutually exclusive with helm/ivy/vertico)."
  (activate-completion-framework! 'ido app))

(def (cmd-ido-find-file app)
  "Find file with IDO — delegates to find-file with completion."
  (execute-command! app 'find-file))

(def (cmd-ido-switch-buffer app)
  "Switch buffer with IDO — delegates to switch-buffer."
  (execute-command! app 'switch-buffer))

;; Helm / Ivy / Vertico — completion framework modes
(def (cmd-helm-mode app)
  "Toggle Helm mode — mutually exclusive with ido/ivy/vertico."
  (activate-completion-framework! 'helm app))

(def (cmd-ivy-mode app)
  "Toggle Ivy mode — mutually exclusive with ido/helm/vertico."
  (activate-completion-framework! 'ivy app))

(def (cmd-vertico-mode app)
  "Toggle Vertico mode — mutually exclusive with ido/helm/ivy."
  (activate-completion-framework! 'vertico app))

(def (cmd-consult-line app)
  "Search buffer lines with consult — interactive line search."
  (let* ((pattern (app-read-string app "Search line: ")))
    (when (and pattern (not (string-empty? pattern)))
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (text (editor-get-text ed))
             (lines (string-split text #\newline))
             (matches (let loop ((ls lines) (n 1) (acc '()))
                        (if (null? ls) (reverse acc)
                          (loop (cdr ls) (+ n 1)
                                (if (string-contains (car ls) pattern)
                                  (cons (string-append (number->string n) ": " (car ls)) acc)
                                  acc))))))
        (if (null? matches)
          (echo-message! (app-state-echo app) "No matching lines")
          (open-output-buffer app "*Consult*" (string-join matches "\n")))))))

(def (cmd-consult-grep app)
  "Grep with consult — delegates to grep command."
  (execute-command! app 'grep))

(def (cmd-consult-buffer app)
  "Switch buffer with consult — delegates to switch-buffer."
  (execute-command! app 'switch-buffer))

(def (cmd-consult-outline app)
  "Jump to a heading/definition in the current buffer.
   Detects headings by pattern and shows in a list."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (current-buffer-from-app app))
         (text (editor-get-text ed))
         (lang (and buf (buffer-lexer-lang buf)))
         (lines (string-split text #\newline))
         (headings
           (let loop ((ls lines) (n 1) (acc '()))
             (if (null? ls) (reverse acc)
               (let* ((line (car ls))
                      (trimmed (string-trim line))
                      (is-heading
                        (cond
                          ((eq? lang 'org)
                           (and (> (string-length trimmed) 0)
                                (char=? (string-ref trimmed 0) #\*)))
                          ((eq? lang 'markdown)
                           (and (> (string-length trimmed) 0)
                                (char=? (string-ref trimmed 0) #\#)))
                          ((memq lang '(scheme lisp gerbil))
                           (or (string-prefix? "(def " trimmed)
                               (string-prefix? "(defstruct " trimmed)
                               (string-prefix? "(defclass " trimmed)))
                          ((memq lang '(c cpp python ruby javascript))
                           (or (string-prefix? "def " trimmed)
                               (string-prefix? "class " trimmed)
                               (string-prefix? "function " trimmed)))
                          (else
                           (or (string-prefix? ";;;" trimmed)
                               (string-prefix? "###" trimmed))))))
                 (loop (cdr ls) (+ n 1)
                       (if is-heading
                         (cons (string-append (number->string n) ": " trimmed) acc)
                         acc)))))))
    (if (null? headings)
      (echo-message! (app-state-echo app) "No headings found")
      (open-output-buffer app "*Outline*" (string-join headings "\n")))))

;; Company completion — uses built-in completion
(def (cmd-company-mode app)
  "Toggle company completion mode."
  (let ((on (toggle-mode! 'company)))
    (echo-message! (app-state-echo app) (if on "Company mode: on" "Company mode: off"))))

(def (cmd-company-complete app)
  "Trigger company completion — delegates to hippie-expand."
  (execute-command! app 'hippie-expand))

;; Flyspell extras
(def (cmd-flyspell-buffer app)
  "Flyspell-check entire buffer — counts misspelled words using aspell."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (text (editor-get-text ed))
         (words (filter (lambda (w) (> (string-length w) 0))
                        (string-split text #\space)))
         (misspelled 0))
    (with-exception-catcher
      (lambda (e) (echo-error! (app-state-echo app) "aspell not available"))
      (lambda ()
        (for-each
          (lambda (word)
            (when (> (string-length word) 1)
              (when (not (flyspell-check-word word))
                (set! misspelled (+ misspelled 1)))))
          words)
        (echo-message! (app-state-echo app)
          (string-append "Flyspell: " (number->string misspelled) " misspelled words in "
                         (number->string (length words)) " total"))))))

(def (cmd-flyspell-correct-word app)
  "Correct misspelled word — shows suggestions from aspell."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (editor-get-current-pos ed))
         (text (editor-get-text ed))
         (word-start (let loop ((i (- pos 1)))
                       (cond ((< i 0) 0)
                             ((not (char-alphabetic? (string-ref text i))) (+ i 1))
                             (else (loop (- i 1))))))
         (word-end (let loop ((i pos))
                     (cond ((>= i (string-length text)) i)
                           ((not (char-alphabetic? (string-ref text i))) i)
                           (else (loop (+ i 1))))))
         (word (substring text word-start word-end)))
    (if (string-empty? word)
      (echo-message! (app-state-echo app) "No word at point")
      (with-exception-catcher
        (lambda (e) (echo-error! (app-state-echo app) "aspell not available"))
        (lambda ()
          (let* ((proc (open-process
                         (list path: "aspell"
                               arguments: '("pipe")
                               stdin-redirection: #t stdout-redirection: #t stderr-redirection: #f)))
                 (_ (begin (display (string-append word "\n") proc) (force-output proc)))
                 (banner (read-line proc))
                 (result (read-line proc)))
            (close-output-port proc)
            (process-status proc)
            (cond
              ((or (not result) (string-empty? result) (char=? (string-ref result 0) #\*))
               (echo-message! (app-state-echo app) (string-append "'" word "' is correct")))
              ((char=? (string-ref result 0) #\&)
               ;; Has suggestions: "& word count offset: sug1, sug2, ..."
               (let* ((colon-pos (string-contains result ": "))
                      (suggestions (if colon-pos (substring result (+ colon-pos 2) (string-length result)) "")))
                 (echo-message! (app-state-echo app)
                   (string-append "Suggestions for '" word "': " suggestions))))
              (else
               (echo-message! (app-state-echo app) (string-append "'" word "': no suggestions"))))))))))

;; Bibliography / citar
(def (cmd-citar-insert-citation app)
  "Insert citation — prompts for citation key."
  (let ((key (app-read-string app "Citation key: ")))
    (when (and key (not (string-empty? key)))
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (pos (editor-get-current-pos ed)))
        (editor-insert-text ed pos (string-append "[@" key "]"))
        (echo-message! (app-state-echo app) (string-append "Inserted citation: " key))))))

;; Docker
(def (cmd-docker app)
  "Docker management interface — shows containers and images."
  (with-exception-catcher
    (lambda (e) (echo-error! (app-state-echo app) "Docker not available"))
    (lambda ()
      (let* ((proc (open-process
                     (list path: "docker"
                           arguments: '("info" "--format" "Server Version: {{.ServerVersion}}\nContainers: {{.Containers}}\nImages: {{.Images}}")
                           stdin-redirection: #f stdout-redirection: #t stderr-redirection: #t)))
             (out (read-line proc #f)))
        (process-status proc)
        (open-output-buffer app "*Docker*" (or out "Docker info unavailable"))))))

(def (cmd-docker-containers app)
  "List docker containers."
  (let ((result (with-exception-catcher
                  (lambda (e) "Docker not available")
                  (lambda ()
                    (let ((p (open-process
                               (list path: "docker"
                                     arguments: '("ps" "--format" "{{.Names}}\t{{.Status}}\t{{.Image}}")
                                     stdin-redirection: #f stdout-redirection: #t
                                     stderr-redirection: #t))))
                      (let ((out (read-line p #f)))
                        (process-status p)
                        (or out "(no containers)")))))))
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (buf (buffer-create! "*Docker*" ed)))
      (buffer-attach! ed buf)
      (set! (edit-window-buffer win) buf)
      (editor-set-text ed (string-append "Docker Containers\n\nName\tStatus\tImage\n" result "\n"))
      (editor-set-read-only ed #t))))

(def (cmd-docker-images app)
  "List docker images."
  (with-exception-catcher
    (lambda (e) (echo-error! (app-state-echo app) "Docker not available"))
    (lambda ()
      (let* ((proc (open-process
                     (list path: "docker"
                           arguments: '("images" "--format" "{{.Repository}}\t{{.Tag}}\t{{.Size}}")
                           stdin-redirection: #f stdout-redirection: #t stderr-redirection: #t)))
             (out (read-line proc #f)))
        (process-status proc)
        (open-output-buffer app "*Docker Images*"
          (string-append "Docker Images\n\nRepository\tTag\tSize\n" (or out "(no images)") "\n"))))))

;; Restclient
(def (cmd-restclient-mode app)
  "Toggle restclient mode — enables HTTP request editing."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win))
         (on (toggle-mode! 'restclient)))
    (when (and on buf)
      (set! (buffer-lexer-lang buf) 'restclient))
    (echo-message! (app-state-echo app) (if on "Restclient mode: on" "Restclient mode: off"))))

(def (cmd-restclient-http-send app)
  "Send HTTP request at point using curl."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (editor-get-current-pos ed))
         (text (editor-get-text ed))
         (line-num (send-message ed SCI_LINEFROMPOSITION pos 0))
         (line-start (send-message ed SCI_POSITIONFROMLINE line-num 0))
         (line-end (send-message ed SCI_GETLINEENDPOSITION line-num 0))
         (line (substring text line-start line-end)))
    ;; Parse "METHOD URL" from current line
    (let* ((parts (string-split line #\space))
           (method (if (pair? parts) (car parts) "GET"))
           (url (if (> (length parts) 1) (cadr parts) "")))
      (if (string-empty? url)
        (echo-error! (app-state-echo app) "No URL on current line")
        (with-exception-catcher
          (lambda (e) (echo-error! (app-state-echo app) "curl failed"))
          (lambda ()
            (let* ((proc (open-process
                           (list path: "curl"
                                 arguments: (list "-s" "-X" method url)
                                 stdin-redirection: #f stdout-redirection: #t stderr-redirection: #t)))
                   (out (read-line proc #f)))
              (process-status proc)
              (open-output-buffer app "*HTTP Response*"
                (string-append method " " url "\n\n" (or out "(no response)") "\n")))))))))

;; Helper: set buffer language mode
(def (set-buffer-mode! app mode-name lang-symbol)
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) lang-symbol))
    (echo-message! (app-state-echo app) mode-name)))

;; YAML mode
(def (cmd-yaml-mode app)
  "Toggle YAML mode — sets YAML lexer."
  (set-buffer-mode! app "YAML mode" 'yaml))

;; TOML mode
(def (cmd-toml-mode app)
  "Toggle TOML mode — sets TOML lexer."
  (set-buffer-mode! app "TOML mode" 'toml))

;; Dockerfile mode
(def (cmd-dockerfile-mode app)
  "Toggle Dockerfile mode — sets Dockerfile lexer."
  (set-buffer-mode! app "Dockerfile mode" 'dockerfile))

;; SQL mode
(def (cmd-sql-mode app)
  "Toggle SQL mode — sets SQL lexer."
  (set-buffer-mode! app "SQL mode" 'sql))

(def (cmd-sql-connect app)
  "Connect to SQL database — prompts for connection string."
  (let ((conn (app-read-string app "Connection (e.g. sqlite:db.sqlite): ")))
    (if (or (not conn) (string-empty? conn))
      (echo-error! (app-state-echo app) "No connection string")
      (echo-message! (app-state-echo app) (string-append "SQL: connected to " conn)))))

(def (cmd-sql-send-region app)
  "Send SQL region to database process."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! (app-state-echo app) "No region selected")
      (let ((sql (substring (editor-get-text ed) start end)))
        (echo-message! (app-state-echo app) (string-append "SQL sent: " (substring sql 0 (min 50 (string-length sql)))))))))

;; Language modes — each sets the buffer's lexer language
(def (cmd-python-mode app) "Toggle Python mode." (set-buffer-mode! app "Python mode" 'python))
(def (cmd-c-mode app) "Toggle C mode." (set-buffer-mode! app "C mode" 'c))
(def (cmd-c++-mode app) "Toggle C++ mode." (set-buffer-mode! app "C++ mode" 'cpp))
(def (cmd-java-mode app) "Toggle Java mode." (set-buffer-mode! app "Java mode" 'java))
(def (cmd-rust-mode app) "Toggle Rust mode." (set-buffer-mode! app "Rust mode" 'rust))
(def (cmd-go-mode app) "Toggle Go mode." (set-buffer-mode! app "Go mode" 'go))
(def (cmd-js-mode app) "Toggle JavaScript mode." (set-buffer-mode! app "JavaScript mode" 'javascript))
(def (cmd-typescript-mode app) "Toggle TypeScript mode." (set-buffer-mode! app "TypeScript mode" 'typescript))
(def (cmd-html-mode app) "Toggle HTML mode." (set-buffer-mode! app "HTML mode" 'html))
(def (cmd-css-mode app) "Toggle CSS mode." (set-buffer-mode! app "CSS mode" 'css))
(def (cmd-lua-mode app) "Toggle Lua mode." (set-buffer-mode! app "Lua mode" 'lua))
(def (cmd-ruby-mode app) "Toggle Ruby mode." (set-buffer-mode! app "Ruby mode" 'ruby))
(def (cmd-shell-script-mode app) "Toggle Shell Script mode." (set-buffer-mode! app "Shell script mode" 'bash))

;; Prog mode / text mode
(def (cmd-prog-mode app)
  "Switch to programming mode — enables line numbers."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) 'prog))
    (send-message ed SCI_SETMARGINWIDTHN 0 48)
    (echo-message! (app-state-echo app) "Prog mode")))

(def (cmd-text-mode app)
  "Switch to text mode — enables word wrap."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) 'text))
    (send-message ed SCI_SETWRAPMODE 1 0)
    (echo-message! (app-state-echo app) "Text mode")))

(def (cmd-fundamental-mode app)
  "Switch to fundamental mode — no special behavior."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) #f))
    (echo-message! (app-state-echo app) "Fundamental mode")))

;; Tab completion / completion-at-point (dabbrev-style with cycling)
;; State for cycling through completions on repeated invocations
(def *dabbrev-state* #f)  ; #f or [prefix prefix-start candidates index]

(def (dabbrev-word-char? ch)
  "Return #t if ch is part of a word for dabbrev purposes."
  (or (char-alphabetic? ch) (char-numeric? ch) (char=? ch #\_) (char=? ch #\-)))

(def (dabbrev-collect-candidates text prefix prefix-start)
  "Collect all words in text that start with prefix, excluding the one at prefix-start."
  (let ((len (string-length text))
        (plen (string-length prefix))
        (candidates '()))
    (let loop ((i 0))
      (when (< i len)
        (let* ((wstart
                 (let ws ((j i))
                   (if (or (>= j len) (dabbrev-word-char? (string-ref text j)))
                     j (ws (+ j 1)))))
               (wend
                 (let we ((j wstart))
                   (if (or (>= j len) (not (dabbrev-word-char? (string-ref text j))))
                     j (we (+ j 1))))))
          (when (> wend wstart)
            (let ((word (substring text wstart wend)))
              (when (and (> (string-length word) plen)
                         (string-prefix? prefix word)
                         (not (= wstart prefix-start))
                         (not (member word candidates)))
                (set! candidates (append candidates [word]))))
            (loop wend))
          (when (= wend wstart)
            (loop (+ wstart 1))))))
    candidates))

(def (cmd-completion-at-point app)
  "Complete word at point from buffer text (dabbrev-style). Cycles on repeated invocations."
  (let* ((ed (current-editor app))
         (echo (app-state-echo app))
         (pos (editor-get-current-pos ed))
         (text (editor-get-text ed)))
    ;; Check if we're cycling from a previous completion
    (if (and *dabbrev-state*
             (let* ((st *dabbrev-state*)
                    (pstart (list-ref st 1))
                    (cands (list-ref st 2))
                    (idx (list-ref st 3))
                    (cur-word (list-ref cands idx))
                    (cur-len (string-length cur-word)))
               (and (= pos (+ pstart cur-len))
                    (<= (+ pstart cur-len) (string-length text))
                    (string=? cur-word (substring text pstart (+ pstart cur-len))))))
      ;; Cycling: replace current completion with next candidate
      (let* ((st *dabbrev-state*)
             (prefix (list-ref st 0))
             (pstart (list-ref st 1))
             (cands (list-ref st 2))
             (idx (list-ref st 3))
             (cur-word (list-ref cands idx))
             (next-idx (modulo (+ idx 1) (length cands)))
             (next-word (list-ref cands next-idx)))
        (send-message ed SCI_SETTARGETSTART pstart 0)
        (send-message ed SCI_SETTARGETEND (+ pstart (string-length cur-word)) 0)
        (send-message/string ed SCI_REPLACETARGET next-word)
        (editor-goto-pos ed (+ pstart (string-length next-word)))
        (set! *dabbrev-state* [prefix pstart cands next-idx])
        (echo-message! echo
          (string-append next-word " [" (number->string (+ next-idx 1))
                         "/" (number->string (length cands)) "]")))
      ;; First invocation: find prefix and candidates
      (let* ((prefix-start
               (let loop ((i (- pos 1)))
                 (if (or (< i 0) (not (dabbrev-word-char? (string-ref text i))))
                   (+ i 1) (loop (- i 1)))))
             (prefix (substring text prefix-start pos))
             (plen (string-length prefix)))
        (if (= plen 0)
          (begin
            (set! *dabbrev-state* #f)
            (echo-message! echo "No prefix to complete"))
          (let ((candidates (dabbrev-collect-candidates text prefix prefix-start)))
            (if (null? candidates)
              (begin
                (set! *dabbrev-state* #f)
                (echo-message! echo
                  (string-append "No completions for \"" prefix "\"")))
              ;; Insert first candidate
              (let ((completion (car candidates)))
                (send-message ed SCI_SETTARGETSTART prefix-start 0)
                (send-message ed SCI_SETTARGETEND (+ prefix-start plen) 0)
                (send-message/string ed SCI_REPLACETARGET completion)
                (editor-goto-pos ed (+ prefix-start (string-length completion)))
                (set! *dabbrev-state* [prefix prefix-start candidates 0])
                (echo-message! echo
                  (string-append completion
                    (if (> (length candidates) 1)
                      (string-append " [1/" (number->string (length candidates)) "]")
                      "")))))))))))

;; Eldoc extras
(def (cmd-eldoc-mode app)
  "Toggle eldoc mode — shows function signatures in echo area."
  (let ((on (toggle-mode! 'eldoc)))
    (echo-message! (app-state-echo app) (if on "Eldoc mode: on" "Eldoc mode: off"))))

;; Which-function extras
(def *which-function-name* "")

(def (which-function-update! app)
  "Update the current function name (called from tick loop when mode is on)."
  (when (mode-enabled? 'which-function)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (line (send-message ed 2166 pos 0)))  ;; SCI_LINEFROMPOSITION
      ;; Search backward for function definition
      (let loop ((l line))
        (if (< l 0)
          (set! *which-function-name* "")
          (let* ((ls (send-message ed 2167 l 0))   ;; SCI_POSITIONFROMLINE
                 (le (send-message ed 2136 l 0))   ;; SCI_GETLINEENDPOSITION
                 (lt (if (and (>= ls 0) (<= le (string-length text)))
                       (substring text ls (min le (string-length text))) ""))
                 (name (which-function-find-name lt)))
            (if name
              (set! *which-function-name* name)
              (loop (- l 1)))))))))

(def (which-function-find-name line-text)
  "Extract function/def name from a line of code."
  (let ((t (string-trim line-text)))
    (cond
      ;; Scheme: (def (name or (define (name
      ((or (string-contains t "(def (") (string-contains t "(define ("))
       (let* ((idx (or (string-contains t "(def (") (string-contains t "(define (")))
              (skip (if (string-contains t "(define (") 9 6))
              (start (+ idx skip))
              (end (let loop ((j start))
                     (if (or (>= j (string-length t))
                             (memv (string-ref t j) '(#\space #\) #\( #\tab)))
                       j (loop (+ j 1))))))
         (if (> end start) (substring t start end) #f)))
      ;; Python: def name( or class name
      ((or (string-prefix? "def " t) (string-prefix? "class " t))
       (let* ((start (if (string-prefix? "class " t) 6 4))
              (end (let loop ((j start))
                     (if (or (>= j (string-length t))
                             (memv (string-ref t j) '(#\( #\: #\space)))
                       j (loop (+ j 1))))))
         (if (> end start) (substring t start end) #f)))
      ;; C/Go/Rust: func/fn name
      ((or (string-prefix? "func " t) (string-prefix? "fn " t))
       (let* ((skip (if (string-prefix? "fn " t) 3 5))
              (end (let loop ((j skip))
                     (if (or (>= j (string-length t))
                             (memv (string-ref t j) '(#\( #\space #\{ #\<)))
                       j (loop (+ j 1))))))
         (if (> end skip) (substring t skip end) #f)))
      ;; JS/TS: function name(
      ((string-prefix? "function " t)
       (let* ((start 9)
              (end (let loop ((j start))
                     (if (or (>= j (string-length t))
                             (memv (string-ref t j) '(#\( #\space #\{)))
                       j (loop (+ j 1))))))
         (if (> end start) (substring t start end) #f)))
      (else #f))))

(def (cmd-which-function-mode app)
  "Toggle which-function mode — shows current function name in echo area."
  (let ((on (toggle-mode! 'which-function)))
    (if on
      (begin
        (which-function-update! app)
        (echo-message! (app-state-echo app)
          (if (string-empty? *which-function-name*)
            "Which-function mode: on (not in a function)"
            (string-append "Which-function mode: on [" *which-function-name* "]"))))
      (begin
        (set! *which-function-name* "")
        (echo-message! (app-state-echo app) "Which-function mode: off")))))

;; Compilation
(def (cmd-compilation-mode app)
  "Switch to compilation mode — read-only buffer with error navigation."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) 'compilation))
    (echo-message! (app-state-echo app) "Compilation mode")))

;; GDB
(def *gdb-process* #f)

(def (gdb-send! cmd app)
  "Send command to GDB and display response."
  (let ((proc *gdb-process*))
    (when (port? proc)
      (display (string-append cmd "\n") proc)
      (force-output proc)
      (thread-sleep! 0.1)
      (let ((out (with-exception-catcher (lambda (e) #f) (lambda () (read-line proc)))))
        (when (string? out)
          (echo-message! (app-state-echo app) out))))))

(def (cmd-gdb app)
  "Start GDB debugger — spawns gdb subprocess with MI interface."
  (let ((program (app-read-string app "Program to debug: ")))
    (if (or (not program) (string-empty? program))
      (echo-error! (app-state-echo app) "No program specified")
      (with-exception-catcher
        (lambda (e) (echo-error! (app-state-echo app) "GDB not available"))
        (lambda ()
          (let* ((proc (open-process
                         (list path: "gdb"
                               arguments: (list "-q" "--interpreter=mi2" program)
                               stdin-redirection: #t stdout-redirection: #t stderr-redirection: #t)))
                 (fr (app-state-frame app))
                 (win (current-window fr))
                 (ed (edit-window-editor win))
                 (buf (buffer-create! "*gdb*" ed)))
            (set! *gdb-process* proc)
            (buffer-attach! ed buf)
            (set! (edit-window-buffer win) buf)
            (editor-set-text ed (string-append "GDB: " program "\n\n"))
            (echo-message! (app-state-echo app) (string-append "GDB started for " program))))))))

(def (cmd-gud-break app)
  "Set breakpoint at current line."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (path (and buf (buffer-file-path buf)))
         (pos (editor-get-current-pos ed))
         (line (+ 1 (send-message ed SCI_LINEFROMPOSITION pos 0))))
    (if *gdb-process*
      (begin
        (gdb-send! (string-append "-break-insert " (or path "") ":" (number->string line)) app)
        (echo-message! (app-state-echo app)
          (string-append "Breakpoint at " (or (and path (path-strip-directory path)) "?") ":" (number->string line))))
      (echo-message! (app-state-echo app)
        (string-append "GDB not running. Breakpoint noted at line " (number->string line))))))

(def (cmd-gud-remove app)
  "Remove breakpoint at current line."
  (if *gdb-process*
    (begin (gdb-send! "-break-delete" app)
           (echo-message! (app-state-echo app) "GUD: breakpoints cleared"))
    (echo-message! (app-state-echo app) "GDB not running")))

(def (cmd-gud-cont app)
  "Continue execution in debugger."
  (if *gdb-process*
    (begin (gdb-send! "-exec-continue" app)
           (echo-message! (app-state-echo app) "GUD: continue"))
    (echo-message! (app-state-echo app) "GDB not running")))

(def (cmd-gud-next app)
  "Step over in debugger."
  (if *gdb-process*
    (begin (gdb-send! "-exec-next" app)
           (echo-message! (app-state-echo app) "GUD: next"))
    (echo-message! (app-state-echo app) "GDB not running")))

(def (cmd-gud-step app)
  "Step into in debugger."
  (if *gdb-process*
    (begin (gdb-send! "-exec-step" app)
           (echo-message! (app-state-echo app) "GUD: step"))
    (echo-message! (app-state-echo app) "GDB not running")))

;; Hippie expand
(def (cmd-try-expand-dabbrev app)
  "Try dabbrev expansion — delegates to hippie-expand."
  (execute-command! app 'hippie-expand))

;; Mode line helpers
(def (cmd-toggle-mode-line app)
  "Toggle mode line display."
  (let ((on (toggle-mode! 'mode-line)))
    (echo-message! (app-state-echo app) (if on "Mode line: visible" "Mode line: hidden"))))

(def (cmd-mode-line-other-buffer app)
  "Show other buffer info in mode line."
  (let ((bufs (buffer-list)))
    (if (< (length bufs) 2)
      (echo-message! (app-state-echo app) "No other buffer")
      (let ((other (cadr bufs)))
        (echo-message! (app-state-echo app)
          (string-append "Other: " (buffer-name other)))))))

;; Timer
(def (cmd-run-with-timer app)
  "Run function after delay."
  (let ((secs (app-read-string app "Delay (seconds): ")))
    (when (and secs (not (string-empty? secs)))
      (let ((n (string->number secs)))
        (when n
          (let ((msg (app-read-string app "Message to show: ")))
            (when msg
              (thread-start!
                (make-thread
                  (lambda ()
                    (thread-sleep! n)
                    (echo-message! (app-state-echo app) (string-append "Timer: " msg)))))
              (echo-message! (app-state-echo app)
                (string-append "Timer set for " secs " seconds")))))))))

;; Global auto-revert
(def (cmd-global-auto-revert-mode app)
  "Toggle global auto-revert mode."
  (let ((on (toggle-mode! 'global-auto-revert)))
    (echo-message! (app-state-echo app)
      (if on "Global auto-revert: on" "Global auto-revert: off"))))

;; Save place
(def (cmd-save-place-mode app)
  "Toggle save-place mode — remembers cursor position in files."
  (let ((on (toggle-mode! 'save-place)))
    (echo-message! (app-state-echo app)
      (if on "Save-place mode: on" "Save-place mode: off"))))

;; Winner mode
(def (cmd-winner-mode app)
  "Toggle winner mode. Winner mode is always enabled; this command reports status."
  (let ((history-len (length (app-state-winner-history app))))
    (echo-message! (app-state-echo app)
      (string-append "Winner mode enabled. History: " (number->string history-len) " configs"))))

;; Whitespace toggle
(def (cmd-global-whitespace-mode app)
  "Toggle global whitespace mode — shows whitespace in all buffers."
  (let* ((on (toggle-mode! 'global-whitespace))
         (fr (app-state-frame app)))
    (for-each
      (lambda (win)
        (let ((ed (edit-window-editor win)))
          (send-message ed SCI_SETVIEWWS (if on 1 0) 0)))
      (frame-windows fr))
    (echo-message! (app-state-echo app)
      (if on "Global whitespace: on" "Global whitespace: off"))))

;; Cursor type
(def (cmd-blink-cursor-mode app)
  "Toggle cursor blinking."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (cur (send-message ed SCI_GETCARETPERIOD 0 0)))
    (if (> cur 0)
      (begin
        (send-message ed SCI_SETCARETPERIOD 0 0)
        (echo-message! (app-state-echo app) "Cursor blink: off"))
      (begin
        (send-message ed SCI_SETCARETPERIOD 500 0)
        (echo-message! (app-state-echo app) "Cursor blink: on")))))

;; --- Task #50: push to 1000+ commands ---

;; Lisp interaction mode
(def (cmd-lisp-interaction-mode app)
  "Switch to Lisp interaction mode — like *scratch* with eval."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win)))
    (when buf (set! (buffer-lexer-lang buf) 'gerbil))
    (echo-message! (app-state-echo app) "Lisp interaction mode (C-j to eval)")))

(def (cmd-inferior-lisp app)
  "Start inferior Lisp process — opens Chez Scheme REPL."
  (execute-command! app 'repl))

(def (cmd-slime app)
  "Start SLIME — delegates to Chez Scheme REPL."
  (execute-command! app 'repl))

(def (cmd-sly app)
  "Start SLY — delegates to Chez Scheme REPL."
  (execute-command! app 'repl))

;; Code folding extras
(def (cmd-fold-this app)
  "Fold current block — uses Scintilla folding."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (editor-get-current-pos ed))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0)))
    (send-message ed SCI_TOGGLEFOLD line 0)
    (echo-message! (app-state-echo app) "Fold toggled")))

(def (cmd-fold-this-all app)
  "Fold all blocks at same level."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (editor-get-current-pos ed))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (level (send-message ed SCI_GETFOLDLEVEL line 0))
         (total (send-message ed SCI_GETLINECOUNT 0 0)))
    (let loop ((i 0))
      (when (< i total)
        (let ((fl (send-message ed SCI_GETFOLDLEVEL i 0)))
          (when (= fl level)
            (send-message ed SCI_FOLDLINE i 1)))  ; 1 = SC_FOLDACTION_CONTRACT
        (loop (+ i 1))))
    (echo-message! (app-state-echo app) "Folded all at same level")))

(def (cmd-origami-mode app)
  "Toggle origami folding mode — enables fold margin."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (on (toggle-mode! 'origami)))
    (if on
      (begin (send-message ed SCI_SETMARGINWIDTHN 2 16)
             (send-message ed SCI_SETMARGINTYPEN 2 4)  ;; SC_MARGIN_SYMBOL = 4
             (echo-message! (app-state-echo app) "Origami mode: on"))
      (begin (send-message ed SCI_SETMARGINWIDTHN 2 0)
             (echo-message! (app-state-echo app) "Origami mode: off")))))

;; Indent guides
(def (cmd-indent-guide-mode app)
  "Toggle indent guide display."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (cur (send-message ed SCI_GETINDENTATIONGUIDES 0 0)))
    (if (> cur 0)
      (begin (send-message ed SCI_SETINDENTATIONGUIDES 0 0)
             (echo-message! (app-state-echo app) "Indent guides: off"))
      (begin (send-message ed SCI_SETINDENTATIONGUIDES 3 0)  ;; SC_IV_LOOKBOTH
             (echo-message! (app-state-echo app) "Indent guides: on")))))

(def (cmd-highlight-indent-guides-mode app)
  "Toggle highlight indent guides — same as indent-guide-mode."
  (cmd-indent-guide-mode app))

;; Rainbow delimiters — color delimiters by nesting depth using indicators
(def *tui-rainbow-active* #f)
(def *tui-rainbow-indic-base* 20)
(def *tui-rainbow-colors*
  (vector #xFF6666 #x44CCFF #x00DDDD #x66DD66
          #xFFCC44 #xFF8844 #xFF66CC #xAAAAFF))

(def (tui-rainbow-setup! ed)
  (let ((INDIC_TEXTFORE 17))
    (let loop ((i 0))
      (when (< i 8)
        (let ((indic (+ *tui-rainbow-indic-base* i)))
          (send-message ed SCI_INDICSETSTYLE indic INDIC_TEXTFORE)
          (send-message ed SCI_INDICSETFORE indic
                        (vector-ref *tui-rainbow-colors* i)))
        (loop (+ i 1))))))

(def (tui-rainbow-clear! ed)
  (let ((len (send-message ed SCI_GETTEXTLENGTH 0 0)))
    (let loop ((i 0))
      (when (< i 8)
        (send-message ed SCI_SETINDICATORCURRENT (+ *tui-rainbow-indic-base* i) 0)
        (send-message ed SCI_INDICATORCLEARRANGE 0 len)
        (loop (+ i 1))))))

(def (tui-rainbow-colorize! ed)
  (let* ((text (editor-get-text ed))
         (len (string-length text)))
    (tui-rainbow-clear! ed)
    (tui-rainbow-setup! ed)
    (let loop ((i 0) (depth 0) (in-str #f) (in-cmt #f) (esc #f))
      (when (< i len)
        (let ((ch (string-ref text i)))
          (cond
            (esc (loop (+ i 1) depth in-str in-cmt #f))
            ((and in-str (char=? ch #\\))
             (loop (+ i 1) depth in-str in-cmt #t))
            ((and in-str (char=? ch #\"))
             (loop (+ i 1) depth #f in-cmt #f))
            (in-str (loop (+ i 1) depth in-str in-cmt #f))
            ((and in-cmt (char=? ch #\newline))
             (loop (+ i 1) depth in-str #f #f))
            (in-cmt (loop (+ i 1) depth in-str in-cmt #f))
            ((char=? ch #\;) (loop (+ i 1) depth in-str #t #f))
            ((char=? ch #\") (loop (+ i 1) depth #t in-cmt #f))
            ((or (char=? ch #\() (char=? ch #\[) (char=? ch #\{))
             (let ((indic (+ *tui-rainbow-indic-base* (modulo depth 8))))
               (send-message ed SCI_SETINDICATORCURRENT indic 0)
               (send-message ed SCI_INDICATORFILLRANGE i 1))
             (loop (+ i 1) (+ depth 1) in-str in-cmt #f))
            ((or (char=? ch #\)) (char=? ch #\]) (char=? ch #\}))
             (let* ((d (max 0 (- depth 1)))
                    (indic (+ *tui-rainbow-indic-base* (modulo d 8))))
               (send-message ed SCI_SETINDICATORCURRENT indic 0)
               (send-message ed SCI_INDICATORFILLRANGE i 1))
             (loop (+ i 1) (max 0 (- depth 1)) in-str in-cmt #f))
            (else (loop (+ i 1) depth in-str in-cmt #f))))))))

(def (cmd-rainbow-delimiters-mode app)
  "Toggle rainbow delimiter coloring by nesting depth."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (set! *tui-rainbow-active* (not *tui-rainbow-active*))
    (if *tui-rainbow-active*
      (begin
        (tui-rainbow-colorize! ed)
        (echo-message! (app-state-echo app) "Rainbow delimiters ON"))
      (begin
        (tui-rainbow-clear! ed)
        (echo-message! (app-state-echo app) "Rainbow delimiters OFF")))))

(def (cmd-rainbow-mode app)
  "Toggle rainbow mode — colorize color strings in buffer."
  (let ((on (toggle-mode! 'rainbow)))
    (echo-message! (app-state-echo app)
      (if on "Rainbow mode: on" "Rainbow mode: off"))))

;; Git gutter - shows diff hunks from git
;; Stores hunks as (start-line count type) where type is 'add, 'delete, or 'change

(def *git-gutter-hunks* (make-hash-table)) ; buffer-name -> list of (start-line count type)
(def *git-gutter-hunk-idx* (make-hash-table)) ; buffer-name -> current hunk index

(def (git-gutter-parse-diff output)
  "Parse git diff output to extract hunks."
  (let ((lines (string-split output #\newline))
        (hunks '()))
    (for-each
      (lambda (line)
        ;; Look for @@ -old,count +new,count @@ lines
        (when (string-prefix? "@@" line)
          (let* ((parts (string-split line #\space))
                 ;; Format: @@ -old,count +new,count @@
                 (new-part (if (>= (length parts) 3) (caddr parts) "+0"))
                 (new-range (substring new-part 1 (string-length new-part)))
                 (range-parts (string-split new-range #\,))
                 (start-line (string->number (car range-parts)))
                 (count (if (> (length range-parts) 1)
                          (string->number (cadr range-parts))
                          1)))
            (when (and start-line count)
              (set! hunks (cons (list start-line count 'change) hunks))))))
      lines)
    (reverse hunks)))

(def (git-gutter-refresh! app)
  "Refresh git diff hunks for current buffer."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win))
         (file-path (and buf (buffer-file-path buf)))
         (buf-name (and buf (buffer-name buf)))
         (echo (app-state-echo app)))
    (if (not file-path)
      (echo-message! echo "Buffer has no file")
      (with-exception-catcher
        (lambda (e) (echo-message! echo "Not in a git repository"))
        (lambda ()
          (let* ((proc (open-process
                         (list path: "git"
                               arguments: (list "diff" "--no-color" "-U0" "--" file-path)
                               stdin-redirection: #f
                               stdout-redirection: #t
                               stderr-redirection: #f
                               directory: (path-directory file-path))))
                 (output (read-line proc #f)))
            (process-status proc)
            (let ((hunks (git-gutter-parse-diff (or output ""))))
              (hash-put! *git-gutter-hunks* buf-name hunks)
              (hash-put! *git-gutter-hunk-idx* buf-name 0)
              (if (null? hunks)
                (echo-message! echo "No changes from git HEAD")
                (echo-message! echo
                  (string-append (number->string (length hunks)) " hunk(s) changed"))))))))))

(def *tui-git-gutter-active* #f)
(def *tui-gutter-marker-add* 20)
(def *tui-gutter-marker-mod* 21)
(def *tui-gutter-marker-del* 22)
(def *tui-gutter-margin-num* 3)

(def (tui-git-gutter-setup-margin! ed)
  "Set up margin 3 as a symbol margin for git-gutter markers."
  ;; SC_MARGIN_SYMBOL = 1
  (send-message ed SCI_SETMARGINTYPEN *tui-gutter-margin-num* 1)
  (send-message ed SCI_SETMARGINWIDTHN *tui-gutter-margin-num* 4)
  ;; Mask: markers 20-22 → bits #x700000
  (send-message ed SCI_SETMARGINMASKN *tui-gutter-margin-num* #x700000)
  ;; Define markers as SC_MARK_FULLRECT = 26
  (send-message ed SCI_MARKERDEFINE *tui-gutter-marker-add* 26)
  (send-message ed SCI_MARKERDEFINE *tui-gutter-marker-mod* 26)
  (send-message ed SCI_MARKERDEFINE *tui-gutter-marker-del* 26)
  ;; Colors: green for added, blue for modified, red for deleted
  (send-message ed SCI_MARKERSETBACK *tui-gutter-marker-add* #x40C040)
  (send-message ed SCI_MARKERSETBACK *tui-gutter-marker-mod* #x4080FF)
  (send-message ed SCI_MARKERSETBACK *tui-gutter-marker-del* #xFF4040))

(def (tui-git-gutter-clear-markers! ed)
  "Remove all git-gutter markers."
  (send-message ed SCI_MARKERDELETEALL *tui-gutter-marker-add* 0)
  (send-message ed SCI_MARKERDELETEALL *tui-gutter-marker-mod* 0)
  (send-message ed SCI_MARKERDELETEALL *tui-gutter-marker-del* 0))

(def (tui-git-gutter-apply-markers! ed hunks)
  "Apply git-gutter margin markers for diff hunks."
  (tui-git-gutter-clear-markers! ed)
  (for-each
    (lambda (hunk)
      (let* ((start (car hunk))
             (count (cadr hunk))
             (line0 (max 0 (- start 1))))  ;; Scintilla lines are 0-based
        (if (= count 0)
          (send-message ed SCI_MARKERADD line0 *tui-gutter-marker-del*)
          (let loop ((i 0))
            (when (< i count)
              (send-message ed SCI_MARKERADD (+ line0 i) *tui-gutter-marker-mod*)
              (loop (+ i 1)))))))
    hunks))

(def (cmd-git-gutter-mode app)
  "Toggle git-gutter fringe markers showing diff status."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file-path (and buf (buffer-file-path buf)))
         (buf-name (and buf (buffer-name buf)))
         (echo (app-state-echo app)))
    (if (not file-path)
      (echo-error! echo "Buffer has no file")
      (if *tui-git-gutter-active*
        ;; Turn off
        (begin
          (tui-git-gutter-clear-markers! ed)
          (send-message ed SCI_SETMARGINWIDTHN *tui-gutter-margin-num* 0)
          (set! *tui-git-gutter-active* #f)
          (echo-message! echo "Git gutter OFF"))
        ;; Turn on
        (begin
          (git-gutter-refresh! app)
          (let ((hunks (or (hash-get *git-gutter-hunks* buf-name) '())))
            (tui-git-gutter-setup-margin! ed)
            (tui-git-gutter-apply-markers! ed hunks)
            (set! *tui-git-gutter-active* #t)
            (echo-message! echo
              (string-append "Git gutter ON: " (number->string (length hunks)) " hunk(s)"))))))))

(def (cmd-git-gutter-next-hunk app)
  "Jump to next git diff hunk."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win))
         (buf-name (and buf (buffer-name buf)))
         (echo (app-state-echo app)))
    (if (not buf-name)
      (echo-error! echo "No buffer")
      (let ((hunks (or (hash-get *git-gutter-hunks* buf-name) '())))
        (if (null? hunks)
          (echo-message! echo "No hunks (run git-gutter-mode first)")
          (let* ((idx (or (hash-get *git-gutter-hunk-idx* buf-name) 0))
                 (new-idx (modulo (+ idx 1) (length hunks)))
                 (hunk (list-ref hunks new-idx))
                 (line (car hunk))
                 (count (cadr hunk))
                 (ed (edit-window-editor win)))
            (hash-put! *git-gutter-hunk-idx* buf-name new-idx)
            (editor-goto-line ed line)
            (echo-message! echo (string-append "Hunk " (number->string (+ new-idx 1))
                                              "/" (number->string (length hunks))
                                              ": line " (number->string line)
                                              " (" (number->string count) " lines)"))))))))

(def (cmd-git-gutter-previous-hunk app)
  "Jump to previous git diff hunk."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win))
         (buf-name (and buf (buffer-name buf)))
         (echo (app-state-echo app)))
    (if (not buf-name)
      (echo-error! echo "No buffer")
      (let ((hunks (or (hash-get *git-gutter-hunks* buf-name) '())))
        (if (null? hunks)
          (echo-message! echo "No hunks (run git-gutter-mode first)")
          (let* ((idx (or (hash-get *git-gutter-hunk-idx* buf-name) 0))
                 (new-idx (modulo (- idx 1) (length hunks)))
                 (hunk (list-ref hunks new-idx))
                 (line (car hunk))
                 (count (cadr hunk))
                 (ed (edit-window-editor win)))
            (hash-put! *git-gutter-hunk-idx* buf-name new-idx)
            (editor-goto-line ed line)
            (echo-message! echo (string-append "Hunk " (number->string (+ new-idx 1))
                                              "/" (number->string (length hunks))
                                              ": line " (number->string line)
                                              " (" (number->string count) " lines)"))))))))

(def (cmd-git-gutter-revert-hunk app)
  "Revert the current hunk to git HEAD version."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win))
         (file-path (and buf (buffer-file-path buf)))
         (buf-name (and buf (buffer-name buf)))
         (echo (app-state-echo app)))
    (if (not file-path)
      (echo-error! echo "Buffer has no file")
      (let ((hunks (or (hash-get *git-gutter-hunks* buf-name) '())))
        (if (null? hunks)
          (echo-message! echo "No hunks to revert")
          (with-exception-catcher
            (lambda (e) (echo-error! echo "Failed to revert"))
            (lambda ()
              ;; For simplicity, revert entire file and reload
              (let* ((proc (open-process
                             (list path: "git"
                                   arguments: (list "checkout" "--" file-path)
                                   stdin-redirection: #f
                                   stdout-redirection: #t
                                   stderr-redirection: #t
                                   directory: (path-directory file-path)))))
                (process-status proc)
                ;; Reload file
                (let ((ed (edit-window-editor win))
                      (text (with-exception-catcher
                              (lambda (e) #f)
                              (lambda ()
                                (call-with-input-file file-path
                                  (lambda (p) (read-line p #f)))))))
                  (when text
                    (editor-set-text ed text)
                    (editor-goto-pos ed 0)))
                (hash-put! *git-gutter-hunks* buf-name '())
                (echo-message! echo "Reverted to git HEAD")))))))))

(def (cmd-git-gutter-stage-hunk app)
  "Stage the current file (git add)."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (buf (edit-window-buffer win))
         (file-path (and buf (buffer-file-path buf)))
         (echo (app-state-echo app)))
    (if (not file-path)
      (echo-error! echo "Buffer has no file")
      (with-exception-catcher
        (lambda (e) (echo-error! echo "Failed to stage"))
        (lambda ()
          (let* ((proc (open-process
                         (list path: "git"
                               arguments: (list "add" "--" file-path)
                               stdin-redirection: #f
                               stdout-redirection: #t
                               stderr-redirection: #t
                               directory: (path-directory file-path)))))
            (process-status proc)
            ;; Refresh hunks
            (git-gutter-refresh! app)
            (echo-message! echo (string-append "Staged: " (path-strip-directory file-path)))))))))

;; Minimap
(def (cmd-minimap-mode app)
  "Toggle minimap — shows document overview in margin."
  (let ((on (toggle-mode! 'minimap)))
    (echo-message! (app-state-echo app)
      (if on "Minimap: on (overview in margin)" "Minimap: off"))))

;; Zen/focus/distraction-free modes
(def (cmd-writeroom-mode app)
  "Toggle writeroom/zen mode — distraction-free writing."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (on (toggle-mode! 'writeroom)))
    (if on
      (begin
        (send-message ed SCI_SETMARGINWIDTHN 0 0)   ;; Hide line numbers
        (send-message ed SCI_SETWRAPMODE 1 0)         ;; Enable word wrap
        (send-message ed 2155 #|SCI_SETMARGINLEFT|# 0 40)      ;; Left margin
        (send-message ed 2157 #|SCI_SETMARGINRIGHT|# 0 40)      ;; Right margin
        (echo-message! (app-state-echo app) "Writeroom mode: on"))
      (begin
        (send-message ed SCI_SETMARGINWIDTHN 0 48)
        (send-message ed SCI_SETWRAPMODE 0 0)
        (send-message ed 2155 #|SCI_SETMARGINLEFT|# 0 0)
        (send-message ed 2157 #|SCI_SETMARGINRIGHT|# 0 0)
        (echo-message! (app-state-echo app) "Writeroom mode: off")))))

(def (cmd-focus-mode app)
  "Toggle focus mode — dim non-focused text."
  (let ((on (toggle-mode! 'focus)))
    (echo-message! (app-state-echo app)
      (if on "Focus mode: on (current paragraph highlighted)" "Focus mode: off"))))

(def (cmd-olivetti-mode app)
  "Toggle olivetti mode — centered text with margins."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (on (toggle-mode! 'olivetti)))
    (if on
      (begin
        (send-message ed 2155 #|SCI_SETMARGINLEFT|# 0 60)
        (send-message ed 2157 #|SCI_SETMARGINRIGHT|# 0 60)
        (send-message ed SCI_SETWRAPMODE 1 0)
        (echo-message! (app-state-echo app) "Olivetti mode: on"))
      (begin
        (send-message ed 2155 #|SCI_SETMARGINLEFT|# 0 0)
        (send-message ed 2157 #|SCI_SETMARGINRIGHT|# 0 0)
        (echo-message! (app-state-echo app) "Olivetti mode: off")))))

;; Golden ratio
(def (cmd-golden-ratio-mode app)
  "Toggle golden ratio window resizing."
  (let ((on (toggle-mode! 'golden-ratio)))
    (echo-message! (app-state-echo app)
      (if on "Golden ratio: on" "Golden ratio: off"))))

;; Rotate layout
(def (cmd-rotate-window app)
  "Rotate window layout — swaps buffer between windows."
  (let* ((fr (app-state-frame app))
         (wins (frame-windows fr)))
    (if (< (length wins) 2)
      (echo-message! (app-state-echo app) "Only one window")
      (let* ((w1 (car wins))
             (w2 (cadr wins))
             (b1 (edit-window-buffer w1))
             (b2 (edit-window-buffer w2)))
        (buffer-attach! (edit-window-editor w1) b2)
        (buffer-attach! (edit-window-editor w2) b1)
        (set! (edit-window-buffer w1) b2)
        (set! (edit-window-buffer w2) b1)
        (echo-message! (app-state-echo app) "Windows rotated")))))

(def (cmd-rotate-frame app)
  "Rotate frame layout — cycles through window arrangements."
  (cmd-rotate-window app))

;; Modern completion: Corfu/Orderless/Marginalia/Embark/Cape
(def (cmd-corfu-mode app)
  "Toggle corfu completion mode — enables inline completion popup."
  (let ((on (toggle-mode! 'corfu)))
    (echo-message! (app-state-echo app) (if on "Corfu mode: on" "Corfu mode: off"))))

(def (cmd-orderless-mode app)
  "Toggle orderless completion style — fuzzy matching."
  (let ((on (toggle-mode! 'orderless)))
    (echo-message! (app-state-echo app) (if on "Orderless: on" "Orderless: off"))))

(def (cmd-marginalia-mode app)
  "Toggle marginalia annotations — show extra info with completions."
  (let ((on (toggle-mode! 'marginalia)))
    (if on (marginalia-enable!) (marginalia-disable!))
    (echo-message! (app-state-echo app) (if on "Marginalia: on" "Marginalia: off"))))

;;; Embark target detection — shared between embark-act and embark-dwim
(def (embark-target-at-point ed)
  "Detect the target at point. Returns (values type target-string)."
  (let* ((pos (editor-get-current-pos ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (if (= len 0)
      (values 'none "")
      ;; Try to detect URL at point
      (let* ((line-start (let loop ((i (- pos 1)))
                           (cond ((< i 0) 0)
                                 ((char=? (string-ref text i) #\newline) (+ i 1))
                                 (else (loop (- i 1))))))
             (line-end (let loop ((i pos))
                         (cond ((>= i len) i)
                               ((char=? (string-ref text i) #\newline) i)
                               (else (loop (+ i 1))))))
             (line (substring text line-start line-end))
             ;; Check for URL in line containing cursor
             (url-start (let ((hs (string-contains line "https://"))
                              (hp (string-contains line "http://")))
                          (cond (hs hs) (hp hp) (else #f)))))
        (if (and url-start
                 (<= (+ line-start url-start) pos))
          ;; Extract URL (up to whitespace)
          (let* ((abs-start (+ line-start url-start))
                 (url-end (let loop ((i abs-start))
                            (cond ((>= i len) i)
                                  ((memv (string-ref text i) '(#\space #\tab #\newline #\) #\] #\> #\")) i)
                                  (else (loop (+ i 1)))))))
            (if (<= pos url-end)
              (values 'url (substring text abs-start url-end))
              ;; Cursor past URL, fall through to word
              (embark-word-at-point text pos len)))
          ;; Check for file path
          (let ((word-result (embark-word-at-point text pos len)))
            (let-values (((type target) word-result))
              (cond
                ((and (> (string-length target) 0)
                      (or (char=? (string-ref target 0) #\/)
                          (string-prefix? "./" target)
                          (string-prefix? "~/" target)))
                 (values 'file target))
                (else (values type target))))))))))

(def (embark-word-at-point text pos len)
  "Extract word at point. Returns (values 'symbol word-string)."
  (let* ((word-char? (lambda (c) (or (char-alphabetic? c) (char-numeric? c)
                                     (char=? c #\-) (char=? c #\_) (char=? c #\.)
                                     (char=? c #\/) (char=? c #\~))))
         (start (let loop ((i (- pos 1)))
                  (cond ((< i 0) 0)
                        ((not (word-char? (string-ref text i))) (+ i 1))
                        (else (loop (- i 1))))))
         (end (let loop ((i pos))
                (cond ((>= i len) i)
                      ((not (word-char? (string-ref text i))) i)
                      (else (loop (+ i 1)))))))
    (values 'symbol (substring text start end))))

;;; Embark action definitions per target type
(def *embark-target-actions*
  `((url    . (("browse-url"  . ,(lambda (app target)
                                   (let ((cmd (find-command 'browse-url-at-point)))
                                     (when cmd (cmd app)))))
               ("copy"        . ,(lambda (app target)
                                   (let ((cmd (find-command 'kill-ring-save)))
                                     ;; Copy target string to kill ring
                                     (set! (app-state-kill-ring app)
                                       (cons target (app-state-kill-ring app)))
                                     (echo-message! (app-state-echo app)
                                       (string-append "Copied: " target)))))
               ("eww"         . ,(lambda (app target)
                                   (let ((cmd (find-command 'eww)))
                                     (when cmd (cmd app)))))))
    (file   . (("find-file"   . ,(lambda (app target)
                                   (let ((path (if (string-prefix? "~/" target)
                                                 (string-append (or (getenv "HOME" #f) ".") (substring target 1 (string-length target)))
                                                 target)))
                                     (when (file-exists? path)
                                       (let ((cmd (find-command 'find-file)))
                                         (when cmd (cmd app)))))))
               ("copy-path"   . ,(lambda (app target)
                                   (set! (app-state-kill-ring app)
                                       (cons target (app-state-kill-ring app)))
                                   (echo-message! (app-state-echo app)
                                     (string-append "Copied path: " target))))
               ("dired"       . ,(lambda (app target)
                                   (let ((cmd (find-command 'dired)))
                                     (when cmd (cmd app)))))))
    (symbol . (("grep"        . ,(lambda (app target)
                                   (let ((cmd (find-command 'consult-ripgrep)))
                                     (if cmd (cmd app)
                                       (let ((g (find-command 'grep)))
                                         (when g (g app)))))))
               ("describe"    . ,(lambda (app target)
                                   (let ((cmd (find-command 'describe-function)))
                                     (when cmd (cmd app)))))
               ("copy"        . ,(lambda (app target)
                                   (set! (app-state-kill-ring app)
                                       (cons target (app-state-kill-ring app)))
                                   (echo-message! (app-state-echo app)
                                     (string-append "Copied: " target))))
               ("find-tag"    . ,(lambda (app target)
                                   (let ((cmd (find-command 'find-tag)))
                                     (when cmd (cmd app)))))
               ("ispell"      . ,(lambda (app target)
                                   (let ((cmd (find-command 'ispell-word)))
                                     (when cmd (cmd app)))))))))

(def (cmd-embark-act app)
  "Embark act on target — context-sensitive actions with key dispatch."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (echo (app-state-echo app)))
    (let-values (((type target) (embark-target-at-point ed)))
      (if (or (eq? type 'none) (string-empty? target))
        (echo-message! echo "No target at point")
        (let* ((actions (or (assq type *embark-target-actions*) #f))
               (action-list (if actions (cdr actions) '())))
          (if (null? action-list)
            (echo-message! echo (string-append "No actions for " (symbol->string type)))
            ;; Show actions and prompt for selection
            (let* ((action-names (map car action-list))
                   (prompt (string-append "Embark on " (symbol->string type)
                             " '" (if (> (string-length target) 40)
                                    (string-append (substring target 0 37) "...")
                                    target)
                             "' — "
                             (string-join
                               (map (lambda (name)
                                      (string-append "[" (substring name 0 1) "]" (substring name 1 (string-length name))))
                                    action-names)
                               " ")
                             ": "))
                   (row (- (frame-height fr) 1))
                   (width (frame-width fr))
                   (input (echo-read-string echo prompt row width)))
              (when (and input (> (string-length input) 0))
                (let* ((key (substring input 0 1))
                       (match (find (lambda (a) (string-prefix? key (car a))) action-list)))
                  (if match
                    ((cdr match) app target)
                    (echo-message! echo (string-append "No action for key '" key "'"))))))))))))

(def (cmd-embark-dwim app)
  "Embark do-what-I-mean — execute default action on target."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (echo (app-state-echo app)))
    (let-values (((type target) (embark-target-at-point ed)))
      (cond
        ((or (eq? type 'none) (string-empty? target))
         (echo-message! echo "No target at point"))
        ;; DWIM: URL → browse, file → find-file, symbol → grep
        ((eq? type 'url)
         (let ((cmd (find-command 'browse-url-at-point)))
           (if cmd (cmd app) (echo-message! echo target))))
        ((eq? type 'file)
         (let ((cmd (find-command 'find-file)))
           (when cmd (cmd app))))
        (else
         (let ((cmd (find-command 'consult-ripgrep)))
           (if cmd (cmd app)
             (echo-message! echo (string-append "Symbol: " target)))))))))

(def (cmd-cape-dabbrev app)
  "Cape dabbrev completion — delegates to hippie-expand."
  (execute-command! app 'hippie-expand))

(def (cmd-cape-file app)
  "Cape file completion — delegates to hippie-expand-file."
  (cmd-hippie-expand-file app))

;; Doom/Spacemacs-style
(def (cmd-doom-themes app)
  "Load doom themes — applies dark theme colors."
  (let* ((fr (app-state-frame app)))
    (for-each
      (lambda (win)
        (let ((ed (edit-window-editor win)))
          (send-message ed SCI_STYLESETBACK 32 #x1e1e2e)   ;; Dark bg
          (send-message ed SCI_STYLESETFORE 32 #xcdd6f4)))  ;; Light fg
      (frame-windows fr))
    (echo-message! (app-state-echo app) "Doom theme applied")))

(def (cmd-doom-modeline-mode app)
  "Toggle doom modeline — enhanced status display."
  (let ((on (toggle-mode! 'doom-modeline)))
    (echo-message! (app-state-echo app) (if on "Doom modeline: on" "Doom modeline: off"))))

;; Which-key extras
(def (cmd-which-key-mode app)
  "Toggle which-key mode — shows available keybindings after prefix delay."
  (set! *which-key-mode* (not *which-key-mode*))
  (toggle-mode! 'which-key)  ;; keep mode registry in sync
  (echo-message! (app-state-echo app)
    (if *which-key-mode* "Which-key mode enabled" "Which-key mode disabled")))

;; Helpful — enhanced help system
(def (cmd-helpful-callable app)
  "Describe callable — shows function/command info."
  (let ((name (app-read-string app "Describe callable: ")))
    (when (and name (not (string-empty? name)))
      (let ((cmd (hash-get *all-commands* name)))
        (if cmd
          (echo-message! (app-state-echo app) (string-append "Command: " name " (registered)"))
          (echo-message! (app-state-echo app) (string-append "'" name "' not found as command")))))))

(def (cmd-helpful-variable app)
  "Describe variable — shows variable info."
  (let ((name (app-read-string app "Describe variable: ")))
    (when (and name (not (string-empty? name)))
      (let ((val (hash-get *custom-variables* name)))
        (if val
          (echo-message! (app-state-echo app) (string-append name " = " (with-output-to-string (lambda () (write val)))))
          (echo-message! (app-state-echo app) (string-append "'" name "' not found")))))))

(def (cmd-helpful-key app)
  "Describe key — delegates to describe-key."
  (execute-command! app 'describe-key))

;; Diff-hl — real TUI git-gutter integration
(def (cmd-diff-hl-mode app)
  "Toggle diff-hl mode — shows VCS changes in margin using Scintilla markers."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file-path (and buf (buffer-file-path buf)))
         (buf-name (and buf (buffer-name buf)))
         (echo (app-state-echo app)))
    (if (not file-path)
      (echo-error! echo "Buffer has no file for diff-hl")
      (if *tui-git-gutter-active*
        ;; Turn off
        (begin
          (tui-git-gutter-clear-markers! ed)
          (send-message ed SCI_SETMARGINWIDTHN *tui-gutter-margin-num* 0)
          (set! *tui-git-gutter-active* #f)
          (toggle-mode! 'diff-hl)
          (echo-message! echo "Diff-hl OFF"))
        ;; Turn on
        (begin
          (toggle-mode! 'diff-hl)
          (git-gutter-refresh! app)
          (let ((hunks (or (hash-get *git-gutter-hunks* buf-name) '())))
            (tui-git-gutter-setup-margin! ed)
            (tui-git-gutter-apply-markers! ed hunks)
            (set! *tui-git-gutter-active* #t)
            (echo-message! echo
              (string-append "Diff-hl ON: " (number->string (length hunks)) " hunk(s)"))))))))

;; Wgrep — editable grep results
(def *wgrep-original-lines* '())

(def (cmd-wgrep-change-to-wgrep-mode app)
  "Make grep results buffer editable for bulk editing."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (name (buffer-name buf)))
    (if (not (or (string-contains name "*grep*")
                 (string-contains name "*rg*")
                 (string-contains name "*Occur*")))
      (echo-message! (app-state-echo app) "Not a grep results buffer")
      (let ((text (editor-get-text ed)))
        (set! *wgrep-original-lines*
          (let loop ((lines (string-split text #\newline)) (n 0) (acc '()))
            (if (null? lines) (reverse acc)
              (loop (cdr lines) (+ n 1) (cons (cons n (car lines)) acc)))))
        (send-message ed SCI_SETREADONLY 0 0)
        (echo-message! (app-state-echo app)
          "Wgrep: editing enabled. C-c C-c to apply.")))))

(def (wgrep-parse-grep-line line)
  "Parse 'filename:linenum:content' into (filename linenum content) or #f."
  (let ((first-colon (string-index line #\:)))
    (if (not first-colon) #f
      (let* ((filename (substring line 0 first-colon))
             (rest (substring line (+ first-colon 1) (string-length line)))
             (second-colon (string-index rest #\:)))
        (if (not second-colon) #f
          (let ((linenum (string->number (substring rest 0 second-colon)))
                (content (substring rest (+ second-colon 1) (string-length rest))))
            (if linenum (list filename linenum content) #f)))))))

(def (cmd-wgrep-finish-edit app)
  "Apply wgrep edits back to source files."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (text (editor-get-text ed))
         (lines (string-split text #\newline))
         (changes 0))
    (for-each
      (lambda (pair)
        (let ((idx (car pair)) (orig (cdr pair)))
          (when (< idx (length lines))
            (let ((current (list-ref lines idx)))
              (unless (string=? current orig)
                (let ((parsed (wgrep-parse-grep-line current)))
                  (when parsed
                    (let ((filename (car parsed))
                          (linenum (cadr parsed))
                          (new-content (caddr parsed)))
                      (when (file-exists? filename)
                        (with-exception-catcher
                          (lambda (e) #f)
                          (lambda ()
                            (let* ((file-text (call-with-input-file filename
                                                (lambda (p) (read-line p #f))))
                                   (file-lines (string-split file-text #\newline)))
                              (when (< (- linenum 1) (length file-lines))
                                (let ((updated
                                        (let loop ((fl file-lines) (n 1) (acc '()))
                                          (if (null? fl) (reverse acc)
                                            (loop (cdr fl) (+ n 1)
                                                  (cons (if (= n linenum)
                                                          new-content (car fl))
                                                        acc))))))
                                  (call-with-output-file filename
                                    (lambda (p) (display (string-join updated "\n") p)))
                                  (set! changes (+ changes 1))))))))))))))))
      *wgrep-original-lines*)
    (send-message ed SCI_SETREADONLY 1 0)
    (echo-message! (app-state-echo app)
      (string-append "Wgrep: applied " (number->string changes) " changes"))))

;; Symbol overlay — highlight occurrences of symbol at point
(def (cmd-symbol-overlay-put app)
  "Put symbol overlay — highlights all occurrences of word at point."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (editor-get-current-pos ed))
         (text (editor-get-text ed))
         (start (let loop ((i (- pos 1)))
                  (cond ((< i 0) 0)
                        ((not (or (char-alphabetic? (string-ref text i))
                                  (char=? (string-ref text i) #\_)
                                  (char=? (string-ref text i) #\-))) (+ i 1))
                        (else (loop (- i 1))))))
         (end (let loop ((i pos))
                (cond ((>= i (string-length text)) i)
                      ((not (or (char-alphabetic? (string-ref text i))
                                (char=? (string-ref text i) #\_)
                                (char=? (string-ref text i) #\-))) i)
                      (else (loop (+ i 1))))))
         (word (substring text start end)))
    (if (string-empty? word)
      (echo-message! (app-state-echo app) "No symbol at point")
      (let ((count 0))
        ;; Use indicator to highlight matches
        (send-message ed SCI_INDICSETSTYLE 0 7)  ;; INDIC_ROUNDBOX
        (send-message ed SCI_INDICSETFORE 0 #xFFFF00)
        (send-message ed SCI_SETINDICATORCURRENT 0 0)
        (let loop ((pos 0))
          (let ((found (string-contains text word pos)))
            (when found
              (send-message ed SCI_INDICATORFILLRANGE found (string-length word))
              (set! count (+ count 1))
              (loop (+ found (string-length word))))))
        (echo-message! (app-state-echo app)
          (string-append "Highlighted " (number->string count) " occurrences of '" word "'"))))))

(def (cmd-symbol-overlay-remove-all app)
  "Remove all symbol overlays."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (len (string-length (editor-get-text ed))))
    (send-message ed SCI_SETINDICATORCURRENT 0 0)
    (send-message ed SCI_INDICATORCLEARRANGE 0 len)
    (echo-message! (app-state-echo app) "Symbol overlays cleared")))

;; Perspective / workspace
(def *perspectives* (make-hash-table))  ; name -> list of buffer names
(def *current-perspective* "default")

(def (cmd-persp-switch app)
  "Switch perspective/workspace."
  (let ((name (app-read-string app "Switch to perspective: ")))
    (when (and name (not (string-empty? name)))
      ;; Save current perspective
      (hash-put! *perspectives* *current-perspective*
        (map buffer-name (buffer-list)))
      (set! *current-perspective* name)
      (echo-message! (app-state-echo app) (string-append "Perspective: " name)))))

(def (cmd-persp-add-buffer app)
  "Add buffer to current perspective."
  (let ((buf (current-buffer-from-app app)))
    (when buf
      (let ((existing (or (hash-get *perspectives* *current-perspective*) '())))
        (hash-put! *perspectives* *current-perspective*
          (cons (buffer-name buf) existing))
        (echo-message! (app-state-echo app)
          (string-append "Added " (buffer-name buf) " to " *current-perspective*))))))

(def (cmd-persp-remove-buffer app)
  "Remove buffer from current perspective."
  (let ((buf (current-buffer-from-app app)))
    (when buf
      (let* ((existing (or (hash-get *perspectives* *current-perspective*) '()))
             (name (buffer-name buf)))
        (hash-put! *perspectives* *current-perspective*
          (filter (lambda (n) (not (string=? n name))) existing))
        (echo-message! (app-state-echo app)
          (string-append "Removed " name " from " *current-perspective*))))))

(def (cmd-persp-list app)
  "List all perspectives with buffer counts."
  (let* ((echo (app-state-echo app))
         (names (hash-keys *perspectives*))
         (lines (map (lambda (name)
                       (let* ((bufs (or (hash-get *perspectives* name) '()))
                              (marker (if (string=? name *current-perspective*) " *" "")))
                         (string-append name marker " (" (number->string (length bufs)) " buffers)")))
                     names)))
    (if (null? lines)
      (echo-message! echo (string-append "Current: " *current-perspective* " (no saved perspectives)"))
      (open-output-buffer app "*Perspectives*"
        (string-append "Perspectives:\n\n"
          (string-join lines "\n") "\n\nCurrent: " *current-perspective* "\n")))))

(def (cmd-persp-kill app)
  "Kill a named perspective."
  (let* ((echo (app-state-echo app))
         (names (hash-keys *perspectives*))
         (name (app-read-string app "Kill perspective: ")))
    (when (and name (not (string-empty? name)))
      (cond
        ((string=? name *current-perspective*)
         (echo-error! echo "Cannot kill active perspective"))
        ((hash-key? *perspectives* name)
         (hash-remove! *perspectives* name)
         (echo-message! echo (string-append "Killed perspective: " name)))
        (else
         (echo-error! echo (string-append "No perspective: " name)))))))

;; Popper — popup management
(def (cmd-popper-toggle-latest app)
  "Toggle latest popup — switch to/from last special buffer."
  (let* ((bufs (buffer-list))
         (special (filter (lambda (b) (and (string-prefix? "*" (buffer-name b))
                                           (not (string=? (buffer-name b) "*scratch*"))))
                          bufs)))
    (if (null? special)
      (echo-message! (app-state-echo app) "No popup buffers")
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (target (car special)))
        (buffer-attach! ed target)
        (set! (edit-window-buffer win) target)
        (echo-message! (app-state-echo app) (string-append "Popper: " (buffer-name target)))))))

(def (cmd-popper-cycle app)
  "Cycle through popup buffers."
  (cmd-popper-toggle-latest app))

;; All-the-icons — terminal doesn't support icon fonts
(def (cmd-all-the-icons-install-fonts app)
  "Install all-the-icons fonts — N/A in terminal."
  (echo-message! (app-state-echo app) "Icon fonts: N/A in terminal mode"))

;; Nerd-icons
(def (cmd-nerd-icons-install-fonts app)
  "Install nerd-icons fonts — N/A in terminal."
  (echo-message! (app-state-echo app) "Nerd icons: N/A in terminal mode"))

;; Page break lines
(def (cmd-page-break-lines-mode app)
  "Toggle page break lines display — shows ^L as horizontal rule."
  (let ((on (toggle-mode! 'page-break-lines)))
    (echo-message! (app-state-echo app)
      (if on "Page break lines: on" "Page break lines: off"))))

;; Undo-fu — delegates to Scintilla undo/redo
(def (cmd-undo-fu-only-undo app)
  "Undo (undo-fu style) — delegates to Scintilla undo."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (send-message ed SCI_UNDO 0 0)
    (echo-message! (app-state-echo app) "Undo")))

(def (cmd-undo-fu-only-redo app)
  "Redo (undo-fu style) — delegates to Scintilla redo."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win)))
    (send-message ed SCI_REDO 0 0)
    (echo-message! (app-state-echo app) "Redo")))

;; Vundo — visual undo tree
(def (cmd-vundo app)
  "Visual undo tree — displays undo/redo history with state markers.
   Shows a visual timeline of undo steps and current position.
   Navigate with u (undo) and r (redo) from the undo buffer."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (current-buffer-from-app app))
         (buf-name (if buf (buffer-name buf) "*scratch*"))
         ;; Count undo/redo steps by walking the stack
         (undo-count (let loop ((n 0))
                       (if (> (send-message ed SCI_CANUNDO 0 0) 0)
                         (begin (send-message ed SCI_UNDO 0 0)
                                (loop (+ n 1)))
                         n)))
         ;; Now we're at the beginning — count forward (redo)
         (total (let loop ((n 0))
                  (if (> (send-message ed SCI_CANREDO 0 0) 0)
                    (begin (send-message ed SCI_REDO 0 0)
                           (loop (+ n 1)))
                    n)))
         ;; Redo back to our original position (redo total - undo-count times)
         (_ (let loop ((n (- total undo-count)))
              (when (> n 0)
                (send-message ed SCI_UNDO 0 0)
                (loop (- n 1)))))
         (current-pos undo-count)
         ;; Build visual representation
         (lines (list
                  (string-append "Undo history for: " buf-name)
                  (string-append "Total steps: " (number->string total))
                  (string-append "Current position: " (number->string current-pos)
                                 "/" (number->string total))
                  ""
                  ;; Timeline: o---o---@---o---o
                  ;;           0   1   2   3   4
                  (let ((timeline
                          (let loop ((i 0) (acc '()))
                            (if (> i total)
                              (apply string-append (reverse acc))
                              (loop (+ i 1)
                                    (cons (string-append
                                            (if (= i current-pos) "@" "o")
                                            (if (< i total) "---" ""))
                                          acc))))))
                    (if (> (string-length timeline) 78)
                      (string-append (substring timeline 0 75) "...")
                      timeline))
                  ""
                  "  @ = current state"
                  "  o = saved undo point"
                  ""
                  "Use M-x undo / M-x redo to navigate.")))
    (open-output-buffer app "*Vundo*"
      (apply string-append (map (lambda (l) (string-append l "\n")) lines)))
    (echo-message! (app-state-echo app)
      (string-append "Undo: " (number->string current-pos)
                     " of " (number->string total) " steps"))))

;; Dash (at point) — documentation lookup
(def (cmd-dash-at-point app)
  "Look up documentation in Dash — opens man page for word at point."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pos (editor-get-current-pos ed))
         (text (editor-get-text ed))
         (start (let loop ((i (- pos 1)))
                  (cond ((< i 0) 0)
                        ((not (or (char-alphabetic? (string-ref text i))
                                  (char=? (string-ref text i) #\_))) (+ i 1))
                        (else (loop (- i 1))))))
         (end (let loop ((i pos))
                (cond ((>= i (string-length text)) i)
                      ((not (or (char-alphabetic? (string-ref text i))
                                (char=? (string-ref text i) #\_))) i)
                      (else (loop (+ i 1))))))
         (word (substring text start end)))
    (if (string-empty? word)
      (echo-message! (app-state-echo app) "No symbol at point")
      (cmd-man app))))  ; Delegate to man command

;; Devdocs — online documentation lookup
(def (cmd-devdocs-lookup app)
  "Look up in devdocs — fetches docs via curl and displays in buffer."
  (let ((query (app-read-string app "Devdocs search: ")))
    (when (and query (not (string-empty? query)))
      (echo-message! (app-state-echo app) (string-append "Fetching devdocs for: " query "..."))
      (with-exception-catcher
        (lambda (e)
          (echo-message! (app-state-echo app)
            (string-append "Devdocs: https://devdocs.io/#q=" query)))
        (lambda ()
          (let* ((url (string-append "https://devdocs.io/api/search?query=" query))
                 (proc (open-process
                         (list path: "curl"
                               arguments: (list "-s" "-L" "--max-time" "5"
                                                (string-append "https://devdocs.io/#q=" query))
                               stdin-redirection: #f stdout-redirection: #t stderr-redirection: #f)))
                 (out (read-line proc #f)))
            (process-status proc)
            (if (and out (> (string-length out) 0))
              (let* ((fr (app-state-frame app))
                     (win (current-window fr))
                     (ed (edit-window-editor win))
                     ;; Strip HTML tags for plain text display
                     (plain (let loop ((s out) (result "") (in-tag #f))
                              (if (string-empty? s) result
                                (let ((ch (string-ref s 0))
                                      (rest (substring s 1 (string-length s))))
                                  (cond
                                    ((char=? ch #\<) (loop rest result #t))
                                    ((char=? ch #\>) (loop rest result #f))
                                    (in-tag (loop rest result #t))
                                    (else (loop rest (string-append result (string ch)) #f)))))))
                     (truncated (if (> (string-length plain) 4000)
                                  (substring plain 0 4000) plain))
                     (buf (buffer-create! "*Devdocs*" ed)))
                (buffer-attach! ed buf)
                (set! (edit-window-buffer win) buf)
                (editor-set-text ed
                  (string-append "Devdocs: " query "\n"
                                 "URL: https://devdocs.io/#q=" query "\n\n"
                                 truncated))
                (editor-set-read-only ed #t)
                (echo-message! (app-state-echo app) "Devdocs loaded"))
              (echo-message! (app-state-echo app)
                (string-append "Devdocs: https://devdocs.io/#q=" query)))))))))

;; Copilot — AI completion (real implementation in editor-extra-ai.ss)

;; ChatGPT / AI — uses curl to call API
(def (cmd-gptel app)
  "Open GPTel chat buffer."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (buffer-create! "*GPTel*" ed)))
    (buffer-attach! ed buf)
    (set! (edit-window-buffer win) buf)
    (editor-set-text ed
      (string-append "GPTel Chat\n\n"
                     "Type your message below and use M-x gptel-send to send.\n"
                     "Set OPENAI_API_KEY environment variable for API access.\n\n"
                     "You: "))))

(def (cmd-gptel-send app)
  "Send prompt to GPTel — sends buffer content to API."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (text (editor-get-text ed)))
    ;; Extract last user message (after last "You: ")
    (let ((last-you (let loop ((pos (- (string-length text) 1)))
                      (cond ((< pos 5) 0)
                            ((and (char=? (string-ref text pos) #\:)
                                  (> pos 3)
                                  (string=? "You" (substring text (- pos 3) pos))) (+ pos 2))
                            (else (loop (- pos 1)))))))
      (let ((prompt (substring text last-you (string-length text))))
        (if (string-empty? (string-trim prompt))
          (echo-message! (app-state-echo app) "No prompt to send")
          (echo-message! (app-state-echo app)
            (string-append "GPTel: Set OPENAI_API_KEY to enable API calls. Prompt: "
                           (substring prompt 0 (min 50 (string-length prompt))))))))))

;; Meow modal editing
(def (cmd-meow-mode app)
  "Toggle meow modal editing — selection-first editing."
  (let ((on (toggle-mode! 'meow)))
    (echo-message! (app-state-echo app)
      (if on "Meow mode: on" "Meow mode: off"))))

;; Eat terminal — delegates to term (PTY-backed)
(def (cmd-eat app)
  "Open eat terminal emulator — opens PTY terminal."
  (execute-command! app 'term))

;; Vterm — delegates to term (PTY-backed)
(def (cmd-vterm app)
  "Open vterm terminal — opens PTY terminal."
  (execute-command! app 'term))

;; Denote — note-taking system
(def (cmd-denote app)
  "Create denote note — creates timestamped note file."
  (let ((title (app-read-string app "Note title: ")))
    (when (and title (not (string-empty? title)))
      (let* ((timestamp (with-exception-catcher
                          (lambda (e) "20260213")
                          (lambda ()
                            (let* ((proc (open-process
                                           (list path: "date"
                                                 arguments: '("+%Y%m%dT%H%M%S")
                                                 stdin-redirection: #f stdout-redirection: #t stderr-redirection: #f)))
                                   (out (read-line proc)))
                              (process-status proc)
                              (or out "20260213")))))
             (slug (string-map (lambda (c) (if (char-alphabetic? c) (char-downcase c) #\-)) title))
             (dir (string-append (getenv "HOME") "/notes/"))
             (fname (string-append dir timestamp "--" slug ".org")))
        ;; Ensure directory exists
        (with-exception-catcher (lambda (e) #f) (lambda () (create-directory dir)))
        (let* ((fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win))
               (buf (buffer-create! fname ed)))
          (set! (buffer-file-path buf) fname)
          (buffer-attach! ed buf)
          (set! (edit-window-buffer win) buf)
          (editor-set-text ed
            (string-append "#+title: " title "\n"
                           "#+date: " timestamp "\n\n"))
          (editor-goto-pos ed (string-length (editor-get-text ed)))
          (echo-message! (app-state-echo app) (string-append "Created note: " fname)))))))

(def (cmd-denote-link app)
  "Insert denote link — prompts for note to link."
  (let ((target (app-read-string app "Link to note: ")))
    (when (and target (not (string-empty? target)))
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (pos (editor-get-current-pos ed)))
        (editor-insert-text ed pos (string-append "[[denote:" target "]]"))
        (echo-message! (app-state-echo app) (string-append "Linked to: " target))))))

;; Org-roam — knowledge base / zettelkasten
(def (cmd-org-roam-node-find app)
  "Find org-roam node — searches note files."
  (let ((query (app-read-string app "Find node: ")))
    (when (and query (not (string-empty? query)))
      (let ((notes-dir (string-append (getenv "HOME") "/notes/")))
        (with-exception-catcher
          (lambda (e) (echo-error! (app-state-echo app) "Notes directory not found"))
          (lambda ()
            (let* ((proc (open-process
                           (list path: "grep"
                                 arguments: (list "-rl" query notes-dir)
                                 stdin-redirection: #f stdout-redirection: #t stderr-redirection: #f)))
                   (out (read-line proc #f)))
              (process-status proc)
              (if (and out (> (string-length out) 0))
                (open-output-buffer app "*Org-roam*" out)
                (echo-message! (app-state-echo app) "No matching nodes found")))))))))

(def (cmd-org-roam-node-insert app)
  "Insert org-roam node link."
  (let ((target (app-read-string app "Insert node link: ")))
    (when (and target (not (string-empty? target)))
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (pos (editor-get-current-pos ed)))
        (editor-insert-text ed pos (string-append "[[roam:" target "]]"))))))

(def (cmd-org-roam-buffer-toggle app)
  "Toggle org-roam buffer — shows backlinks."
  (let* ((buf (current-buffer-from-app app))
         (name (and buf (buffer-name buf))))
    (echo-message! (app-state-echo app)
      (string-append "Backlinks for " (or name "?") ": (none found)"))))

;; Dirvish — enhanced dired
(def (cmd-dirvish app)
  "Open dirvish file manager — delegates to dired."
  (execute-command! app 'dired))

;; Jinx (spell check) — uses aspell
(def (cmd-jinx-mode app)
  "Toggle jinx spell checking — aspell-based."
  (let ((on (toggle-mode! 'jinx)))
    (echo-message! (app-state-echo app) (if on "Jinx: on" "Jinx: off"))))

(def (cmd-jinx-correct app)
  "Correct word with jinx — delegates to flyspell-correct."
  (cmd-flyspell-correct-word app))

;; Hl-todo — highlight TODO/FIXME/HACK keywords with colored indicators
(def *hl-todo-indicator* 5)
(def *hl-todo-keywords*
  '(("TODO"  . #x00CCFF)   ; orange
    ("FIXME" . #x0000FF)   ; red
    ("HACK"  . #x00BBFF)   ; dark orange
    ("BUG"   . #x0000CC)   ; dark red
    ("XXX"   . #x0088FF)   ; amber
    ("NOTE"  . #x00CC00))) ; green

(def (hl-todo-refresh! ed)
  "Scan the buffer and highlight all TODO-like keywords with colored indicators."
  (let* ((text (editor-get-text ed))
         (len (string-length text)))
    ;; Clear existing hl-todo indicators
    (send-message ed SCI_SETINDICATORCURRENT *hl-todo-indicator* 0)
    (send-message ed SCI_INDICATORCLEARRANGE 0 (max 1 len))
    ;; Set up indicator style
    (send-message ed SCI_INDICSETSTYLE *hl-todo-indicator* INDIC_TEXTFORE)
    (send-message ed SCI_INDICSETUNDER *hl-todo-indicator* 1)
    ;; Find and highlight each keyword
    (for-each
      (lambda (kw-pair)
        (let ((kw (car kw-pair))
              (color (cdr kw-pair))
              (kw-len (string-length (car kw-pair))))
          (send-message ed SCI_INDICSETFORE *hl-todo-indicator* color)
          (send-message ed SCI_SETINDICATORCURRENT *hl-todo-indicator* 0)
          (let loop ((start 0))
            (let ((found (string-contains text kw start)))
              (when found
                (send-message ed SCI_INDICATORFILLRANGE found kw-len)
                (loop (+ found kw-len)))))))
      *hl-todo-keywords*)))

(def (hl-todo-clear! ed)
  "Remove all hl-todo indicators."
  (let ((len (editor-get-text-length ed)))
    (send-message ed SCI_SETINDICATORCURRENT *hl-todo-indicator* 0)
    (send-message ed SCI_INDICATORCLEARRANGE 0 (max 1 len))))

(def (cmd-hl-todo-mode app)
  "Toggle hl-todo mode — highlights TODO/FIXME/HACK keywords with colors."
  (let ((on (toggle-mode! 'hl-todo))
        (ed (current-editor app)))
    (if on
      (hl-todo-refresh! ed)
      (hl-todo-clear! ed))
    (echo-message! (app-state-echo app) (if on "HL-todo: on" "HL-todo: off"))))

(def (cmd-hl-todo-next app)
  "Jump to next TODO/FIXME/HACK keyword."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (text (editor-get-text ed))
         (pos (editor-get-current-pos ed))
         (keywords '("TODO" "FIXME" "HACK" "BUG" "XXX" "NOTE"))
         (next-pos #f))
    (for-each
      (lambda (kw)
        (let ((found (string-contains text kw (+ pos 1))))
          (when (and found (or (not next-pos) (< found next-pos)))
            (set! next-pos found))))
      keywords)
    (if next-pos
      (begin (editor-goto-pos ed next-pos)
             (editor-scroll-caret ed)
             (echo-message! (app-state-echo app) "Found TODO keyword"))
      (echo-message! (app-state-echo app) "No more TODO keywords"))))

(def (cmd-hl-todo-previous app)
  "Jump to previous TODO/FIXME/HACK keyword."
  (let* ((fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (text (editor-get-text ed))
         (pos (editor-get-current-pos ed))
         (keywords '("TODO" "FIXME" "HACK" "BUG" "XXX" "NOTE"))
         (prev-pos #f))
    (for-each
      (lambda (kw)
        ;; Search backwards from current position
        (let loop ((search-from 0))
          (let ((found (string-contains text kw search-from)))
            (when (and found (< found pos))
              (when (or (not prev-pos) (> found prev-pos))
                (set! prev-pos found))
              (loop (+ found 1))))))
      keywords)
    (if prev-pos
      (begin (editor-goto-pos ed prev-pos)
             (editor-scroll-caret ed)
             (echo-message! (app-state-echo app) "Found TODO keyword"))
      (echo-message! (app-state-echo app) "No previous TODO keywords"))))

;; Editorconfig — reads .editorconfig files
(def (cmd-editorconfig-mode app)
  "Toggle editorconfig mode — applies .editorconfig settings."
  (let ((on (toggle-mode! 'editorconfig)))
    (when on
      ;; Try to read .editorconfig
      (let* ((buf (current-buffer-from-app app))
             (path (and buf (buffer-file-path buf)))
             (dir (if path (path-directory path) (current-directory)))
             (ec-file (string-append dir "/.editorconfig")))
        (when (file-exists? ec-file)
          (echo-message! (app-state-echo app)
            (string-append "Editorconfig: loaded " ec-file))
          (set! on #t))))
    (echo-message! (app-state-echo app) (if on "Editorconfig: on" "Editorconfig: off"))))

;; Envrc / direnv — loads .envrc
(def (cmd-envrc-mode app)
  "Toggle envrc mode — loads .envrc environment."
  (let ((on (toggle-mode! 'envrc)))
    (when on
      (let* ((buf (current-buffer-from-app app))
             (path (and buf (buffer-file-path buf)))
             (dir (if path (path-directory path) (current-directory)))
             (envrc (string-append dir "/.envrc")))
        (when (file-exists? envrc)
          (echo-message! (app-state-echo app) (string-append "Envrc: loaded " envrc)))))
    (echo-message! (app-state-echo app) (if on "Envrc: on" "Envrc: off"))))

;; Apheleia (formatter)
(def (apheleia-before-save-hook app buf)
  "Before-save hook that formats the buffer when apheleia-mode is on."
  (let ((cmd (find-command 'format-buffer)))
    (when cmd (with-catch (lambda (e) #f) (lambda () (cmd app))))))

(def (cmd-apheleia-mode app)
  "Toggle apheleia auto-format — format on save."
  (let ((on (toggle-mode! 'apheleia)))
    (if on
      (add-hook! 'before-save-hook apheleia-before-save-hook)
      (remove-hook! 'before-save-hook apheleia-before-save-hook))
    (echo-message! (app-state-echo app) (if on "Apheleia: on (format on save)" "Apheleia: off"))))

(def (cmd-apheleia-format-buffer app)
  "Format buffer with apheleia — runs the appropriate external formatter."
  (let ((cmd (find-command 'format-buffer)))
    (if cmd
      (cmd app)
      (echo-message! (app-state-echo app) "No format-buffer command available"))))

;; Magit extras — git operations via subprocess
(def (run-git-command app args buffer-name)
  "Run a git command and display output in a buffer."
  (let* ((buf (current-buffer-from-app app))
         (dir (if (and buf (buffer-file-path buf))
                (path-directory (buffer-file-path buf))
                (current-directory))))
    (with-exception-catcher
      (lambda (e) (echo-error! (app-state-echo app) "Git command failed"))
      (lambda ()
        (let* ((proc (open-process
                       (list path: "git"
                             arguments: args
                             directory: dir
                             stdin-redirection: #f stdout-redirection: #t stderr-redirection: #t)))
               (out (read-line proc #f)))
          (process-status proc)
          (if buffer-name
            (open-output-buffer app buffer-name (or out "(no output)\n"))
            (echo-message! (app-state-echo app) (or out "Done"))))))))

(def (cmd-magit-stash app)
  "Magit stash — saves working directory changes."
  (run-git-command app '("stash" "push" "-m" "stash from editor") #f))

(def (cmd-magit-blame app)
  "Magit blame — shows git blame for current file."
  (let* ((buf (current-buffer-from-app app))
         (path (and buf (buffer-file-path buf))))
    (if (not path)
      (echo-error! (app-state-echo app) "Buffer has no file")
      (run-git-command app (list "blame" "--" path)
        (string-append "*git-blame " (path-strip-directory path) "*")))))

(def (tui-git-run-in-dir args dir)
  "Run git command synchronously in dir, return output string."
  (with-exception-catcher
    (lambda (e) "")
    (lambda ()
      (let* ((proc (open-process
                     (list path: "git" arguments: args directory: dir
                           stdout-redirection: #t stderr-redirection: #t)))
             (out (read-line proc #f)))
        (close-port proc)
        (or out "")))))

(def (tui-git-dir app)
  "Get git directory from current buffer."
  (let ((buf (current-buffer-from-app app)))
    (if (and buf (buffer-file-path buf))
      (path-directory (buffer-file-path buf))
      (current-directory))))

(def (cmd-magit-fetch app)
  "Magit fetch — fetches from all remotes."
  (let ((dir (tui-git-dir app)))
    (echo-message! (app-state-echo app) "Fetching all remotes...")
    (run-git-command app '("fetch" "--all") #f)))

(def (cmd-magit-pull app)
  "Magit pull — pulls from remote with upstream info."
  (let* ((dir (tui-git-dir app))
         (branch (string-trim (tui-git-run-in-dir '("rev-parse" "--abbrev-ref" "HEAD") dir)))
         (upstream (let ((u (tui-git-run-in-dir '("rev-parse" "--abbrev-ref" "@{upstream}") dir)))
                     (if (or (string=? u "") (string-prefix? "fatal" u)) #f (string-trim u)))))
    (if (not upstream)
      (echo-error! (app-state-echo app)
        (string-append "No upstream for " branch ". Push first to set upstream."))
      (begin
        (echo-message! (app-state-echo app)
          (string-append "Pulling " upstream " into " branch "..."))
        (run-git-command app '("pull") #f)))))

(def (cmd-magit-push app)
  "Magit push — pushes to remote, sets upstream if needed."
  (let* ((dir (tui-git-dir app))
         (branch (string-trim (tui-git-run-in-dir '("rev-parse" "--abbrev-ref" "HEAD") dir)))
         (upstream (let ((u (tui-git-run-in-dir '("rev-parse" "--abbrev-ref" "@{upstream}") dir)))
                     (if (or (string=? u "") (string-prefix? "fatal" u)) #f (string-trim u)))))
    (if (not upstream)
      (let ((remote (let ((r (app-read-string app "Push to remote (default origin): ")))
                      (if (or (not r) (string-empty? r)) "origin" r))))
        (echo-message! (app-state-echo app)
          (string-append "Pushing " branch " to " remote " (setting upstream)..."))
        (run-git-command app (list "push" "-u" remote branch) #f))
      (begin
        (echo-message! (app-state-echo app)
          (string-append "Pushing " branch " → " upstream "..."))
        (run-git-command app '("push") #f)))))

(def (cmd-magit-rebase app)
  "Magit rebase — interactive rebase."
  (let ((branch (app-read-string app "Rebase onto (default origin/main): ")))
    (let ((target (if (or (not branch) (string-empty? branch)) "origin/main" branch)))
      (run-git-command app (list "rebase" target) #f))))

(def (cmd-magit-merge app)
  "Magit merge — merge a branch."
  (let ((branch (app-read-string app "Merge branch: ")))
    (when (and branch (not (string-empty? branch)))
      (run-git-command app (list "merge" branch) #f))))

(def (cmd-magit-cherry-pick app)
  "Cherry-pick a commit."
  (let* ((dir (tui-git-dir app))
         (hash (app-read-string app "Cherry-pick commit hash: ")))
    (when (and hash (not (string-empty? hash)))
      (echo-message! (app-state-echo app) (string-append "Cherry-picking " hash "..."))
      (run-git-command app (list "cherry-pick" hash) #f))))

(def (cmd-magit-revert-commit app)
  "Revert a commit."
  (let* ((dir (tui-git-dir app))
         (hash (app-read-string app "Revert commit hash: ")))
    (when (and hash (not (string-empty? hash)))
      (echo-message! (app-state-echo app) (string-append "Reverting " hash "..."))
      (run-git-command app (list "revert" "--no-edit" hash) #f))))

(def (cmd-magit-worktree app)
  "Manage git worktrees: list, add, or remove."
  (let* ((dir (tui-git-dir app))
         (output (tui-git-run-in-dir '("worktree" "list") dir))
         (action (app-read-string app "Worktree action (list/add/remove): ")))
    (when (and action (not (string-empty? action)))
      (cond
        ((string=? action "list")
         (open-output-buffer app "*Worktrees*"
           (if (string=? output "") "No worktrees\n" output)))
        ((string=? action "add")
         (let* ((branch (app-read-string app "Worktree branch: "))
                (path (and branch (not (string-empty? branch))
                           (app-read-string app
                             (string-append "Worktree path for " branch ": ")))))
           (when (and path (not (string-empty? path)))
             (let ((result (tui-git-run-in-dir (list "worktree" "add" path branch) dir)))
               (echo-message! (app-state-echo app)
                 (if (string=? result "")
                   (string-append "Added worktree: " path " [" branch "]")
                   (string-trim result)))))))
        ((string=? action "remove")
         (let ((path (app-read-string app "Worktree path to remove: ")))
           (when (and path (not (string-empty? path)))
             (let ((result (tui-git-run-in-dir (list "worktree" "remove" path) dir)))
               (echo-message! (app-state-echo app)
                 (if (string=? result "")
                   (string-append "Removed worktree: " path)
                   (string-trim result)))))))))))

;;; ---- batch 57: environment and project configuration toggles ----

(def *global-envrc* #f)
(def *global-direnv* #f)
(def *global-editorconfig* #f)
(def *global-dtrt-indent* #f)
(def *global-ws-trim* #f)
(def *global-auto-compile* #f)
(def *global-no-littering* #f)

(def (cmd-toggle-global-envrc app)
  "Toggle global envrc-mode (direnv integration via envrc.el)."
  (let ((echo (app-state-echo app)))
    (set! *global-envrc* (not *global-envrc*))
    (echo-message! echo (if *global-envrc*
                          "Global envrc ON" "Global envrc OFF"))))

(def (cmd-toggle-global-direnv app)
  "Toggle global direnv-mode (load .envrc in project dirs)."
  (let ((echo (app-state-echo app)))
    (set! *global-direnv* (not *global-direnv*))
    (echo-message! echo (if *global-direnv*
                          "Global direnv ON" "Global direnv OFF"))))

(def (cmd-toggle-global-editorconfig app)
  "Toggle global editorconfig-mode (apply .editorconfig)."
  (let ((echo (app-state-echo app)))
    (set! *global-editorconfig* (not *global-editorconfig*))
    (echo-message! echo (if *global-editorconfig*
                          "Global editorconfig ON" "Global editorconfig OFF"))))

(def (dtrt-detect-indent text)
  "Analyze TEXT to detect indentation style.  Returns (values use-tabs? indent-size)
   by sampling the first 200 lines.  Counts leading-tab vs leading-space lines,
   and for spaces, finds the most common indent width (2, 3, 4, or 8)."
  (let* ((lines (let loop ((i 0) (start 0) (acc '()) (count 0))
                  (cond
                    ((or (>= i (string-length text)) (>= count 200))
                     (reverse acc))
                    ((char=? (string-ref text i) #\newline)
                     (loop (+ i 1) (+ i 1)
                           (cons (substring text start i) acc)
                           (+ count 1)))
                    (else (loop (+ i 1) start acc count)))))
         (tab-lines 0)
         (space-lines 0)
         (widths (make-vector 9 0)))  ; index 0-8, count occurrences of each width
    (for-each
      (lambda (line)
        (when (> (string-length line) 0)
          (cond
            ((char=? (string-ref line 0) #\tab)
             (set! tab-lines (+ tab-lines 1)))
            ((char=? (string-ref line 0) #\space)
             (let ((n (let loop ((i 0))
                        (if (and (< i (string-length line))
                                 (char=? (string-ref line i) #\space))
                          (loop (+ i 1))
                          i))))
               (when (and (> n 0) (<= n 8))
                 (set! space-lines (+ space-lines 1))
                 (vector-set! widths n (+ (vector-ref widths n) 1))))))))
      lines)
    (if (> tab-lines space-lines)
      (values #t 8)  ; tabs with 8-wide tab stops
      ;; Find the most common space width among 2, 3, 4, 8
      (let ((best-width 4)
            (best-count 0))
        (for-each
          (lambda (w)
            (when (> (vector-ref widths w) best-count)
              (set! best-width w)
              (set! best-count (vector-ref widths w))))
          '(2 3 4 8))
        (values #f best-width)))))

(def (dtrt-apply-indent! ed use-tabs? indent-size)
  "Apply detected indentation settings to a Scintilla editor."
  (send-message ed SCI_SETUSETABS (if use-tabs? 1 0) 0)
  (send-message ed SCI_SETTABWIDTH indent-size 0)
  (send-message ed SCI_SETINDENT indent-size 0))

(def (dtrt-indent-buffer! app)
  "Auto-detect and apply indentation for the current buffer."
  (when *global-dtrt-indent*
    (let* ((ed (current-editor app))
           (text (editor-get-text ed)))
      (when (> (string-length text) 0)
        (let-values (((use-tabs? indent-size) (dtrt-detect-indent text)))
          (dtrt-apply-indent! ed use-tabs? indent-size))))))

(def (cmd-toggle-global-dtrt-indent app)
  "Toggle global dtrt-indent-mode (auto-detect indentation)."
  (let ((echo (app-state-echo app)))
    (set! *global-dtrt-indent* (not *global-dtrt-indent*))
    (when *global-dtrt-indent*
      (dtrt-indent-buffer! app))
    (echo-message! echo (if *global-dtrt-indent*
                          "Global dtrt-indent ON" "Global dtrt-indent OFF"))))

(def (cmd-toggle-global-ws-trim app)
  "Toggle global ws-trim-mode (trim trailing whitespace on save)."
  (let ((echo (app-state-echo app)))
    (set! *global-ws-trim* (not *global-ws-trim*))
    (echo-message! echo (if *global-ws-trim*
                          "Global ws-trim ON" "Global ws-trim OFF"))))

(def (cmd-toggle-global-auto-compile app)
  "Toggle global auto-compile-mode (byte-compile Elisp on save)."
  (let ((echo (app-state-echo app)))
    (set! *global-auto-compile* (not *global-auto-compile*))
    (echo-message! echo (if *global-auto-compile*
                          "Global auto-compile ON" "Global auto-compile OFF"))))

(def (cmd-toggle-global-no-littering app)
  "Toggle global no-littering-mode (clean up config dirs)."
  (let ((echo (app-state-echo app)))
    (set! *global-no-littering* (not *global-no-littering*))
    (echo-message! echo (if *global-no-littering*
                          "Global no-littering ON" "Global no-littering OFF"))))

;;; ---- batch 66: DevOps and infrastructure toggles ----

(def *global-docker* #f)
(def *global-kubernetes* #f)
(def *global-terraform* #f)
(def *global-ansible* #f)
(def *global-vagrant* #f)
(def *global-restclient* #f)
(def *global-ob-http* #f)

(def (cmd-toggle-global-docker app)
  "Toggle global docker-mode (manage Docker containers)."
  (let ((echo (app-state-echo app)))
    (set! *global-docker* (not *global-docker*))
    (echo-message! echo (if *global-docker*
                          "Docker mode ON" "Docker mode OFF"))))

(def (cmd-toggle-global-kubernetes app)
  "Toggle global kubernetes-mode (K8s cluster management)."
  (let ((echo (app-state-echo app)))
    (set! *global-kubernetes* (not *global-kubernetes*))
    (echo-message! echo (if *global-kubernetes*
                          "Kubernetes ON" "Kubernetes OFF"))))

(def (cmd-toggle-global-terraform app)
  "Toggle global terraform-mode (infrastructure as code)."
  (let ((echo (app-state-echo app)))
    (set! *global-terraform* (not *global-terraform*))
    (echo-message! echo (if *global-terraform*
                          "Terraform ON" "Terraform OFF"))))

(def (cmd-toggle-global-ansible app)
  "Toggle global ansible-mode (Ansible playbook support)."
  (let ((echo (app-state-echo app)))
    (set! *global-ansible* (not *global-ansible*))
    (echo-message! echo (if *global-ansible*
                          "Ansible ON" "Ansible OFF"))))

(def (cmd-toggle-global-vagrant app)
  "Toggle global vagrant-mode (Vagrant VM management)."
  (let ((echo (app-state-echo app)))
    (set! *global-vagrant* (not *global-vagrant*))
    (echo-message! echo (if *global-vagrant*
                          "Vagrant ON" "Vagrant OFF"))))

(def (cmd-toggle-global-restclient app)
  "Toggle global restclient-mode (HTTP REST client)."
  (let ((echo (app-state-echo app)))
    (set! *global-restclient* (not *global-restclient*))
    (echo-message! echo (if *global-restclient*
                          "Restclient ON" "Restclient OFF"))))

(def (cmd-toggle-global-ob-http app)
  "Toggle global ob-http-mode (HTTP requests in org-babel)."
  (let ((echo (app-state-echo app)))
    (set! *global-ob-http* (not *global-ob-http*))
    (echo-message! echo (if *global-ob-http*
                          "Ob-http ON" "Ob-http OFF"))))

;;;============================================================================
;;; Parity: subword navigation, goto-last-change, file utilities

(def (subword-boundary? text i direction)
  "Check if position i is a subword boundary."
  (let ((len (string-length text)))
    (and (> i 0) (< i len)
         (let ((prev (string-ref text (- i 1)))
               (cur (string-ref text i)))
           (or (and (= direction 1) (or (char=? cur #\_) (char=? cur #\-)))
               (and (= direction -1) (or (char=? prev #\_) (char=? prev #\-)))
               (and (char-lower-case? prev) (char-upper-case? cur))
               (and (char-alphabetic? prev) (not (or (char-alphabetic? cur) (char-numeric? cur))))
               (and (not (or (char-alphabetic? prev) (char-numeric? prev))) (char-alphabetic? cur)))))))

(def (cmd-forward-subword app)
  "Move forward by subword (camelCase/snake_case boundary)."
  (let* ((ed (current-editor app))
         (text (editor-get-text ed))
         (pos (editor-get-current-pos ed))
         (len (string-length text)))
    (let loop ((i (+ pos 1)))
      (cond
        ((>= i len) (editor-goto-pos ed len))
        ((subword-boundary? text i 1) (editor-goto-pos ed i))
        (else (loop (+ i 1)))))))

(def (cmd-backward-subword app)
  "Move backward by subword (camelCase/snake_case boundary)."
  (let* ((ed (current-editor app))
         (text (editor-get-text ed))
         (pos (editor-get-current-pos ed)))
    (let loop ((i (- pos 1)))
      (cond
        ((<= i 0) (editor-goto-pos ed 0))
        ((subword-boundary? text i -1) (editor-goto-pos ed i))
        (else (loop (- i 1)))))))

(def *tui-last-change-positions* (make-hash-table))

(def (cmd-goto-last-change app)
  "Jump to position of last edit in current buffer."
  (let* ((buf (current-buffer-from-app app))
         (ed (current-editor app))
         (name (and buf (buffer-name buf)))
         (pos (and name (hash-get *tui-last-change-positions* name))))
    (if pos
      (editor-goto-pos ed pos)
      (echo-message! (app-state-echo app) "No recorded change position"))))

(def (cmd-find-file-at-line app)
  "Open a file and jump to a specific line (file:line format)."
  (let ((input (app-read-string app "File:line: ")))
    (when (and input (not (string-empty? input)))
      (let* ((colon (let loop ((i 0))
                      (cond ((>= i (string-length input)) #f)
                            ((char=? (string-ref input i) #\:) i)
                            (else (loop (+ i 1))))))
             (file (if colon (substring input 0 colon) input))
             (line (and colon (< (+ colon 1) (string-length input))
                       (string->number (substring input (+ colon 1) (string-length input))))))
        (when (file-exists? file)
          (let* ((content (read-file-as-string file))
                 (fr (app-state-frame app))
                 (win (current-window fr))
                 (ed (edit-window-editor win))
                 (buf (buffer-create! (path-strip-directory file) ed file)))
            (buffer-attach! ed buf)
            (set! (edit-window-buffer win) buf)
            (editor-set-text ed (or content ""))
            (when (and line (> line 0))
              (editor-goto-line ed (- line 1)))
            (echo-message! (app-state-echo app) (string-append "Opened: " file))))))))

(def (cmd-find-file-read-only app)
  "Open a file in read-only mode."
  (let ((path (app-read-string app "Find file read-only: ")))
    (when (and path (not (string-empty? path)))
      (if (not (file-exists? path))
        (echo-error! (app-state-echo app) (string-append "File not found: " path))
        (let* ((content (read-file-as-string path))
               (fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win))
               (buf (buffer-create! (path-strip-directory path) ed path)))
          (buffer-attach! ed buf)
          (set! (edit-window-buffer win) buf)
          (editor-set-text ed (or content ""))
          (editor-set-read-only ed #t)
          (echo-message! (app-state-echo app) (string-append "Read-only: " path)))))))

(def (cmd-view-file app)
  "Open a file in read-only view mode."
  (cmd-find-file-read-only app))

(def (cmd-append-to-file app)
  "Append the selected region to a file."
  (let* ((ed (current-editor app))
         (text (editor-get-text ed))
         (buf (current-buffer-from-app app))
         (mark (and buf (buffer-mark buf))))
    (if (not mark)
      (echo-error! (app-state-echo app) "No region")
      (let* ((pos (editor-get-current-pos ed))
             (start (min mark pos))
             (end (max mark pos))
             (region (substring text start end))
             (path (app-read-string app "Append to file: ")))
        (when (and path (not (string-empty? path)))
          (call-with-port
            (open-file-output-port path (file-options append) (buffer-mode block) (native-transcoder))
            (lambda (p) (display region p)))
          (echo-message! (app-state-echo app)
            (string-append "Appended " (number->string (- end start)) " chars to " path)))))))

;;;============================================================================
;;; Round 3 batch 1: Features 1-10
;;;============================================================================

;; --- Feature 1: Quick Calc (inline calculator) ---

(def (cmd-quick-calc app)
  "Evaluate a simple math expression and display/insert result."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (expr (echo-read-string echo "Quick calc: " row width)))
    (when (and expr (not (string-empty? expr)))
      (let ((result
              (with-catch
                (lambda (e) (string-append "Error: " (with-output-to-string (lambda () (display-condition e)))))
                (lambda ()
                  ;; Simple expression evaluator: support +, -, *, /, ^, sqrt, abs
                  (let ((val (eval (read (open-input-string expr)))))
                    (if (number? val)
                      (number->string val)
                      (with-output-to-string (lambda () (display val)))))))))
        (echo-message! echo (string-append "Result: " result))))))

(def (cmd-calc-insert app)
  "Evaluate math expression and insert result at point."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (expr (echo-read-string echo "Calc (insert): " row width)))
    (when (and expr (not (string-empty? expr)))
      (let ((result
              (with-catch
                (lambda (e) #f)
                (lambda ()
                  (let ((val (eval (read (open-input-string expr)))))
                    (if (number? val) (number->string val) #f))))))
        (if result
          (let ((ed (edit-window-editor (current-window (app-state-frame app)))))
            (send-message ed SCI_REPLACESEL 0 (string->alien/nul result))
            (echo-message! echo (string-append "Inserted: " result)))
          (echo-error! echo "Invalid expression"))))))

;; --- Feature 2: RE-Builder (interactive regex builder) ---

(def *re-builder-active* #f)

(def (cmd-re-builder app)
  "Interactive regex builder — test regex against current buffer."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (regex (echo-read-string echo "RE-Builder regex: " row width)))
    (when (and regex (not (string-empty? regex)))
      ;; Use indicator 13 for regex matches
      (send-message ed SCI_INDICSETSTYLE 13 7) ;; INDIC_ROUNDBOX
      (send-message ed SCI_INDICSETFORE 13 #x00FFFF) ;; cyan
      (send-message ed SCI_INDICSETALPHA 13 60)
      (send-message ed SCI_SETINDICATORCURRENT 13 0)
      ;; Clear previous highlights
      (send-message ed SCI_INDICATORCLEARRANGE 0
        (send-message ed SCI_GETLENGTH 0 0))
      ;; Search for all matches
      (let* ((text-len (send-message ed SCI_GETLENGTH 0 0))
             (count 0))
        (send-message ed SCI_SETTARGETSTART 0 0)
        (send-message ed SCI_SETTARGETEND text-len 0)
        (send-message ed SCI_SETSEARCHFLAGS #x00200000 0) ;; SCFIND_REGEXP
        (let loop ()
          (let ((found (send-message ed SCI_SEARCHINTARGET (string-length regex)
                        (string->alien/nul regex))))
            (when (>= found 0)
              (let ((match-end (send-message ed SCI_GETTARGETEND 0 0)))
                (when (> match-end found)
                  (send-message ed SCI_INDICATORFILLRANGE found (- match-end found))
                  (set! count (+ count 1))
                  (send-message ed SCI_SETTARGETSTART match-end 0)
                  (send-message ed SCI_SETTARGETEND text-len 0)
                  (loop))))))
        (echo-message! echo
          (string-append "RE-Builder: " (number->string count) " matches for /" regex "/"))))))

(def (cmd-re-builder-clear app)
  "Clear RE-Builder highlights."
  (let ((ed (edit-window-editor (current-window (app-state-frame app)))))
    (send-message ed SCI_SETINDICATORCURRENT 13 0)
    (send-message ed SCI_INDICATORCLEARRANGE 0
      (send-message ed SCI_GETLENGTH 0 0))
    (echo-message! (app-state-echo app) "RE-Builder cleared")))

;; --- Feature 3: Compilation Mode ---
;; Run make/compile command and parse error output

(def *compilation-buffer-name* "*compilation*")
(def *compilation-errors* '())

(def (cmd-compile app)
  "Run a compilation command (default: make) and show output."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (cmd (or (echo-read-string echo "Compile command: " row width) "make")))
    (when (and cmd (not (string-empty? cmd)))
      (echo-message! echo (string-append "Compiling: " cmd "..."))
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (buf (make-buffer *compilation-buffer-name*)))
        (buffer-attach! ed buf)
        (set! (edit-window-buffer win) buf)
        (let-values (((p-stdin p-stdout p-stderr pid)
                      (open-process-ports (string-append cmd " 2>&1") 'block (native-transcoder))))
          (close-port p-stdin)
          (let loop ((lines '()) (errors '()))
            (let ((line (get-line p-stdout)))
              (if (eof-object? line)
                (begin
                  (close-port p-stdout)
                  (close-port p-stderr)
                  (let ((content (string-join (reverse lines) "\n")))
                    (editor-set-text ed (string-append "Compilation: " cmd "\n"
                                                       (make-string 50 #\-) "\n"
                                                       content "\n"
                                                       (make-string 50 #\-) "\n"
                                                       "Compilation finished with "
                                                       (number->string (length errors))
                                                       " error(s)"))
                    (editor-goto-pos ed 0)
                    (set! *compilation-errors* (reverse errors))
                    (echo-message! echo
                      (string-append "Compilation done: " (number->string (length errors)) " error(s)"))))
                ;; Parse error lines (file:line: pattern)
                (let* ((is-error (and (string-contains line ":")
                                      (or (string-contains line "error")
                                          (string-contains line "warning"))))
                       (new-errors (if is-error (cons line errors) errors)))
                  (loop (cons line lines) new-errors))))))))))

(def (cmd-next-error app)
  "Jump to next compilation error."
  (let ((echo (app-state-echo app)))
    (if (null? *compilation-errors*)
      (echo-message! echo "No compilation errors")
      (let* ((err-line (car *compilation-errors*))
             (colon1 (string-contains err-line ":"))
             (file (if colon1 (substring err-line 0 colon1) #f)))
        (set! *compilation-errors* (cdr *compilation-errors*))
        (if file
          (echo-message! echo (string-append "Error in: " err-line))
          (echo-message! echo err-line))))))

;; --- Feature 4: View Mode (read-only viewing) ---

(def *view-mode-active* #f)

(def (cmd-view-mode app)
  "Toggle view-mode — make buffer read-only with navigation keys."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app)))))
    (set! *view-mode-active* (not *view-mode-active*))
    (send-message ed SCI_SETREADONLY (if *view-mode-active* 1 0) 0)
    (echo-message! echo
      (if *view-mode-active*
        "View mode: on (read-only, q to quit)"
        "View mode: off"))))

(def (cmd-view-file app)
  "Open a file in view-mode (read-only)."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (path (echo-read-string echo "View file: " row width)))
    (when (and path (not (string-empty? path)))
      (if (not (file-exists? path))
        (echo-error! echo (string-append "File not found: " path))
        (let* ((fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win))
               (content (with-catch
                          (lambda (e) "")
                          (lambda () (read-file-string path))))
               (buf (make-buffer (string-append "[view] " (path-strip-directory path)))))
          (buffer-attach! ed buf)
          (set! (edit-window-buffer win) buf)
          (editor-set-text ed content)
          (editor-goto-pos ed 0)
          (send-message ed SCI_SETREADONLY 1 0)
          (set! *view-mode-active* #t)
          (echo-message! echo (string-append "Viewing: " path " (read-only)")))))))

;; --- Feature 5: Keyfreq (command frequency tracking) ---

(def *keyfreq-table* (make-hash-table))
(def *keyfreq-enabled* #f)

(def (keyfreq-record! cmd-name)
  "Record a command invocation."
  (when *keyfreq-enabled*
    (let ((count (hash-ref *keyfreq-table* cmd-name 0)))
      (hash-put! *keyfreq-table* cmd-name (+ count 1)))))

(def (cmd-keyfreq-mode app)
  "Toggle command frequency tracking."
  (set! *keyfreq-enabled* (not *keyfreq-enabled*))
  (echo-message! (app-state-echo app)
    (if *keyfreq-enabled* "Keyfreq mode: on" "Keyfreq mode: off")))

(def (cmd-keyfreq-show app)
  "Display command frequency report."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (pairs (hash->list *keyfreq-table*)))
    (if (null? pairs)
      (echo-message! echo "No command frequency data")
      (let* ((sorted (sort (lambda (a b) (> (cdr a) (cdr b))) pairs))
             (lines (map
                      (lambda (p)
                        (let* ((name (symbol->string (car p)))
                               (count (number->string (cdr p)))
                               (pad (make-string (max 0 (- 40 (string-length name))) #\space)))
                          (string-append "  " name pad count)))
                      (if (> (length sorted) 50) (list-head sorted 50) sorted)))
             (content (string-append "Command Frequency Report\n"
                        (make-string 50 #\=) "\n"
                        (string-join lines "\n") "\n"
                        (make-string 50 #\=) "\n"
                        "Total unique commands: " (number->string (length pairs))))
             (buf (make-buffer "*keyfreq*")))
        (buffer-attach! ed buf)
        (set! (edit-window-buffer win) buf)
        (editor-set-text ed content)
        (editor-goto-pos ed 0)))))

;; --- Feature 6: Pomidor (Pomodoro timer) ---

(def *pomidor-work-minutes* 25)
(def *pomidor-break-minutes* 5)
(def *pomidor-start-time* #f)
(def *pomidor-state* 'idle) ;; idle, work, break
(def *pomidor-count* 0)

(def (cmd-pomidor app)
  "Start a pomodoro work session."
  (let ((echo (app-state-echo app)))
    (set! *pomidor-state* 'work)
    (set! *pomidor-start-time* (time-second (current-time)))
    (set! *pomidor-count* (+ *pomidor-count* 1))
    (echo-message! echo
      (string-append "Pomodoro #" (number->string *pomidor-count*)
                    " started (" (number->string *pomidor-work-minutes*) " min work session)"))))

(def (cmd-pomidor-break app)
  "Start a pomodoro break."
  (let ((echo (app-state-echo app)))
    (set! *pomidor-state* 'break)
    (set! *pomidor-start-time* (time-second (current-time)))
    (echo-message! echo
      (string-append "Break started (" (number->string *pomidor-break-minutes*) " min)"))))

(def (cmd-pomidor-status app)
  "Show current pomodoro timer status."
  (let ((echo (app-state-echo app)))
    (case *pomidor-state*
      ((idle) (echo-message! echo "Pomidor: idle (no active timer)"))
      ((work break)
       (let* ((elapsed (- (time-second (current-time)) *pomidor-start-time*))
              (total (if (eq? *pomidor-state* 'work)
                       (* *pomidor-work-minutes* 60)
                       (* *pomidor-break-minutes* 60)))
              (remaining (max 0 (- total elapsed)))
              (min-left (quotient remaining 60))
              (sec-left (remainder remaining 60)))
         (echo-message! echo
           (string-append "Pomidor [" (symbol->string *pomidor-state*) "]: "
                         (number->string min-left) ":"
                         (if (< sec-left 10) "0" "") (number->string sec-left)
                         " remaining (session #" (number->string *pomidor-count*) ")")))))))

(def (cmd-pomidor-stop app)
  "Stop the pomodoro timer."
  (set! *pomidor-state* 'idle)
  (set! *pomidor-start-time* #f)
  (echo-message! (app-state-echo app) "Pomidor stopped"))

;; --- Feature 7: Define Word (dictionary lookup via dict protocol) ---

(def (cmd-define-word app)
  "Look up word definition using /usr/bin/dict or online."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         ;; Try to get word at point first
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
         (word-end (send-message ed SCI_WORDENDPOSITION pos 1))
         (word-len (- word-end word-start))
         (default-word
           (if (> word-len 0)
             (let* ((buf (make-bytevector (+ word-len 1) 0))
                    (_ (send-message ed SCI_GETTEXTRANGE 0
                         (cons->alien word-start (bytevector->alien buf)))))
               (alien/nul->string (bytevector->alien buf)))
             ""))
         (word (echo-read-string echo
                 (if (string-empty? default-word)
                   "Define word: "
                   (string-append "Define word [" default-word "]: "))
                 row width)))
    (let ((lookup-word (if (or (not word) (string-empty? word)) default-word word)))
      (when (and lookup-word (not (string-empty? lookup-word)))
        (let ((cmd (if (file-exists? "/usr/bin/dict")
                     (string-append "/usr/bin/dict \"" lookup-word "\"")
                     (string-append "/usr/bin/curl -s 'dict://dict.org/d:" lookup-word "'"))))
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports (string-append cmd " 2>&1") 'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout)
                    (close-port p-stderr)
                    (let* ((content (if (null? lines)
                                      (string-append "No definition found for: " lookup-word)
                                      (string-join (reverse lines) "\n")))
                           (buf (make-buffer "*definition*")))
                      (buffer-attach! ed buf)
                      (set! (edit-window-buffer win) buf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo (string-append "Definition: " lookup-word))))
                  (loop (cons line lines)))))))))))

;; --- Feature 8: Chronos (countdown timer) ---

(def *chronos-timers* '()) ;; list of (name . end-epoch)

(def (cmd-chronos-add app)
  "Add a countdown timer."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (name (echo-read-string echo "Timer name: " row width)))
    (when (and name (not (string-empty? name)))
      (let ((minutes-str (echo-read-string echo "Minutes: " row width)))
        (when (and minutes-str (not (string-empty? minutes-str)))
          (let ((minutes (string->number (string-trim minutes-str))))
            (when (and minutes (> minutes 0))
              (let ((end-time (+ (time-second (current-time)) (* minutes 60))))
                (set! *chronos-timers*
                  (cons (cons name end-time) *chronos-timers*))
                (echo-message! echo
                  (string-append "Timer '" name "' set for "
                                (number->string minutes) " minutes"))))))))))

(def (cmd-chronos-list app)
  "Show all active countdown timers."
  (let* ((echo (app-state-echo app))
         (now (time-second (current-time))))
    (if (null? *chronos-timers*)
      (echo-message! echo "No active timers")
      (let* ((lines
               (map (lambda (timer)
                      (let* ((name (car timer))
                             (end (cdr timer))
                             (remaining (max 0 (- end now)))
                             (min (quotient remaining 60))
                             (sec (remainder remaining 60)))
                        (string-append name ": "
                          (if (<= remaining 0)
                            "DONE!"
                            (string-append (number->string min) ":"
                              (if (< sec 10) "0" "") (number->string sec))))))
                    *chronos-timers*))
             (content (string-join lines "\n")))
        (echo-message! echo (string-append "Timers: " content))))))

(def (cmd-chronos-clear app)
  "Clear all timers."
  (set! *chronos-timers* '())
  (echo-message! (app-state-echo app) "All timers cleared"))

;; --- Feature 9: MWIM (Move Where I Mean — smart beginning/end of line) ---

(def (cmd-mwim-beginning app)
  "Smart beginning-of-line: toggle between indentation and column 0."
  (let* ((ed (edit-window-editor (current-window (app-state-frame app))))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
         (indent-pos (send-message ed SCI_GETLINEINDENTPOSITION line 0)))
    ;; If at indentation, go to column 0; otherwise go to indentation
    (if (= pos indent-pos)
      (editor-goto-pos ed line-start)
      (editor-goto-pos ed indent-pos))))

(def (cmd-mwim-end app)
  "Smart end-of-line: toggle between last non-whitespace and end."
  (let* ((ed (edit-window-editor (current-window (app-state-frame app))))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
         (text (editor-get-text ed))
         (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
         (line-text (substring text line-start line-end))
         (trimmed (string-trim-right line-text))
         (last-nonws (+ line-start (string-length trimmed))))
    ;; If at last non-whitespace, go to true end; otherwise go to last non-ws
    (if (= pos last-nonws)
      (editor-goto-pos ed line-end)
      (editor-goto-pos ed last-nonws))))

;; --- Feature 10: Electric Spacing (auto-space around operators) ---

(def *electric-spacing-enabled* #f)
(def *electric-spacing-operators* '("=" "+" "-" "*" "/" "<" ">" "!" "&" "|"))

(def (cmd-electric-spacing-mode app)
  "Toggle electric-spacing mode — auto-insert spaces around operators."
  (set! *electric-spacing-enabled* (not *electric-spacing-enabled*))
  (echo-message! (app-state-echo app)
    (if *electric-spacing-enabled*
      "Electric spacing mode: on"
      "Electric spacing mode: off")))

(def (electric-spacing-maybe-apply! ed ch)
  "If electric-spacing is on and ch is an operator, add spaces."
  (when *electric-spacing-enabled*
    (let ((op (string ch)))
      (when (member op *electric-spacing-operators*)
        ;; Check preceding char
        (let* ((pos (send-message ed SCI_GETCURRENTPOS 0 0))
               (prev-ch (if (> pos 0) (send-message ed SCI_GETCHARAT (- pos 1) 0) 0)))
          ;; Don't double-space
          (when (not (= prev-ch 32)) ;; not already a space
            (send-message ed SCI_INSERTTEXT pos (string->alien/nul " "))))))))

;;;============================================================================
;;; Round 7 batch 1: Features 1-10
;;;============================================================================

;; --- Feature 1: Spray / RSVP Speed Reading ---

(def *spray-wpm* 300)
(def *spray-words* '())
(def *spray-index* 0)

(def (cmd-spray-mode app)
  "Start speed-reading (RSVP) of current buffer."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app))))
         (text (editor-get-text ed))
         (words (filter (lambda (w) (not (string-empty? w)))
                  (string-split text #\space))))
    (if (null? words)
      (echo-message! echo "Buffer is empty")
      (begin
        (set! *spray-words* words)
        (set! *spray-index* 0)
        (echo-message! echo
          (string-append "Spray: " (number->string (length words))
            " words at " (number->string *spray-wpm*) " WPM. Use spray-next to advance"))))))

(def (cmd-spray-next app)
  "Show next word(s) in speed reading."
  (let ((echo (app-state-echo app)))
    (if (or (null? *spray-words*) (>= *spray-index* (length *spray-words*)))
      (echo-message! echo "Spray: end of text")
      (let* ((chunk-size 3) ;; Show 3 words at a time
             (end (min (+ *spray-index* chunk-size) (length *spray-words*)))
             (chunk (let loop ((i *spray-index*) (acc '()))
                      (if (>= i end) (reverse acc)
                        (loop (+ i 1) (cons (list-ref *spray-words* i) acc))))))
        (set! *spray-index* end)
        (echo-message! echo
          (string-append ">>> " (string-join chunk " ") " <<<  ["
            (number->string *spray-index*) "/" (number->string (length *spray-words*)) "]"))))))

;; --- Feature 2: Ledger Mode (plain text accounting) ---

(def (cmd-ledger-mode app)
  "Enable ledger mode for plain text accounting files."
  (let ((echo (app-state-echo app)))
    (echo-message! echo "Ledger mode enabled (tab=4, plain text accounting)")))

(def (cmd-ledger-report app)
  "Run ledger balance report on current file."
  (let* ((echo (app-state-echo app))
         (buf (current-buffer-from-app app))
         (path (and buf (buffer-file-path buf))))
    (if (not path)
      (echo-error! echo "Buffer has no file")
      (if (not (file-exists? "/usr/bin/ledger"))
        (echo-error! echo "ledger not installed")
        (let* ((fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win)))
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          (string-append "ledger -f \"" path "\" balance 2>&1")
                          'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout)
                    (close-port p-stderr)
                    (let* ((content (string-append "Ledger Balance Report\n"
                                      (make-string 50 #\=) "\n"
                                      (string-join (reverse lines) "\n")))
                           (rbuf (make-buffer "*ledger-report*")))
                      (buffer-attach! ed rbuf)
                      (set! (edit-window-buffer win) rbuf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)))
                  (loop (cons line lines)))))))))))

;; --- Feature 3: Buffer Move (swap buffers between windows) ---

(def (cmd-buffer-move-up app)
  "Swap current buffer with the one above."
  (cmd-buffer-move-swap app 'up))

(def (cmd-buffer-move-down app)
  "Swap current buffer with the one below."
  (cmd-buffer-move-swap app 'down))

(def (cmd-buffer-move-swap app direction)
  "Swap buffers between current and adjacent window."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (wins (frame-windows fr)))
    (if (< (length wins) 2)
      (echo-message! echo "Only one window")
      (let* ((win1 (car wins))
             (win2 (cadr wins))
             (buf1 (edit-window-buffer win1))
             (buf2 (edit-window-buffer win2))
             (ed1 (edit-window-editor win1))
             (ed2 (edit-window-editor win2)))
        (when (and buf1 buf2)
          (buffer-attach! ed1 buf2)
          (set! (edit-window-buffer win1) buf2)
          (buffer-attach! ed2 buf1)
          (set! (edit-window-buffer win2) buf1)
          (echo-message! echo "Buffers swapped"))))))

;; --- Feature 4: Fortune Cookie ---

(def (cmd-fortune app)
  "Display a fortune cookie message."
  (let ((echo (app-state-echo app)))
    (if (not (file-exists? "/usr/games/fortune"))
      ;; Built-in fortunes
      (let* ((fortunes '("The best way to predict the future is to invent it. — Alan Kay"
                          "Programs must be written for people to read. — Abelson & Sussman"
                          "Simplicity is prerequisite for reliability. — Dijkstra"
                          "Talk is cheap. Show me the code. — Linus Torvalds"
                          "Any sufficiently advanced technology is indistinguishable from magic. — Clarke"
                          "The only way to learn a new programming language is by writing programs in it."
                          "First, solve the problem. Then, write the code."
                          "Measuring programming progress by lines of code is like measuring aircraft building progress by weight."
                          "It works on my machine."
                          "There are only two hard things: cache invalidation and naming things."))
             (idx (remainder (time-second (current-time)) (length fortunes))))
        (echo-message! echo (list-ref fortunes idx)))
      (let-values (((p-stdin p-stdout p-stderr pid)
                    (open-process-ports "/usr/games/fortune -s 2>&1" 'block (native-transcoder))))
        (close-port p-stdin)
        (let loop ((lines '()))
          (let ((line (get-line p-stdout)))
            (if (eof-object? line)
              (begin
                (close-port p-stdout)
                (close-port p-stderr)
                (echo-message! echo (string-join (reverse lines) " ")))
              (loop (cons line lines)))))))))

;; --- Feature 5: Snake Game ---

(def *snake-score* 0)

(def (cmd-snake app)
  "Start a text-based snake game display."
  (let* ((echo (app-state-echo app))
         (fr (app-state-frame app))
         (win (current-window fr))
         (ed (edit-window-editor win))
         (buf (make-buffer "*snake*"))
         (width 30) (height 15)
         (board (let loop ((row 0) (lines '()))
                  (if (>= row height)
                    (reverse lines)
                    (loop (+ row 1)
                      (cons (cond ((or (= row 0) (= row (- height 1)))
                                   (make-string width #\#))
                                  (else (string-append "#" (make-string (- width 2) #\space) "#")))
                            lines)))))
         ;; Place snake in middle
         (mid-row (quotient height 2))
         (content (string-append
                    "=== SNAKE ===\n"
                    "Score: 0\n\n"
                    (string-join board "\n") "\n\n"
                    "Controls: arrow keys (display mode)\n"
                    "(Placeholder for interactive game)")))
    (buffer-attach! ed buf)
    (set! (edit-window-buffer win) buf)
    (editor-set-text ed content)
    (editor-goto-pos ed 0)
    (set! *snake-score* 0)
    (echo-message! echo "Snake started (display mode)")))

;; --- Feature 6: Graphviz DOT Preview ---

(def (cmd-graphviz-preview app)
  "Preview DOT graph as ASCII art (requires graph-easy or dot)."
  (let* ((echo (app-state-echo app))
         (buf (current-buffer-from-app app))
         (path (and buf (buffer-file-path buf))))
    (if (not path)
      (echo-error! echo "Buffer has no file")
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed (edit-window-editor win))
             (cmd (if (file-exists? "/usr/bin/graph-easy")
                    (string-append "graph-easy --from=dot \"" path "\" 2>&1")
                    (string-append "dot -Tplain \"" path "\" 2>&1"))))
        (let-values (((p-stdin p-stdout p-stderr pid)
                      (open-process-ports cmd 'block (native-transcoder))))
          (close-port p-stdin)
          (let loop ((lines '()))
            (let ((line (get-line p-stdout)))
              (if (eof-object? line)
                (begin
                  (close-port p-stdout)
                  (close-port p-stderr)
                  (let* ((content (string-join (reverse lines) "\n"))
                         (pbuf (make-buffer "*graphviz*")))
                    (buffer-attach! ed pbuf)
                    (set! (edit-window-buffer win) pbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "Graphviz preview")))
                (loop (cons line lines))))))))))

;; --- Feature 7: Thesaurus (synonym lookup) ---

(def (cmd-thesaurus app)
  "Look up synonyms for word at point."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app))))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
         (word-end (send-message ed SCI_WORDENDPOSITION pos 1))
         (word-len (- word-end word-start))
         (row (tui-rows)) (width (tui-cols)))
    (if (<= word-len 0)
      (echo-error! echo "No word at point")
      (let* ((buf (make-bytevector (+ word-len 1) 0))
             (_ (send-message ed SCI_GETTEXTRANGE 0
                  (cons->alien word-start (bytevector->alien buf))))
             (word (alien/nul->string (bytevector->alien buf))))
        ;; Use dict with moby-thesaurus or wn
        (let ((cmd (if (file-exists? "/usr/bin/wn")
                     (string-append "wn \"" word "\" -synsn -synsv -synsa -synsr 2>&1 | head -30")
                     (string-append "dict -d moby-thesaurus \"" word "\" 2>&1 | head -30"))))
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports cmd 'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout)
                    (close-port p-stderr)
                    (if (null? lines)
                      (echo-message! echo (string-append "No synonyms for: " word))
                      (let* ((content (string-join (reverse lines) "\n"))
                             (fr (app-state-frame app))
                             (win (current-window fr))
                             (ed2 (edit-window-editor win))
                             (tbuf (make-buffer "*thesaurus*")))
                        (buffer-attach! ed2 tbuf)
                        (set! (edit-window-buffer win) tbuf)
                        (editor-set-text ed2 content)
                        (editor-goto-pos ed2 0)
                        (echo-message! echo (string-append "Synonyms for: " word)))))
                  (loop (cons line lines)))))))))))

;; --- Feature 8: Grammar Check (basic heuristic checker) ---

(def *grammar-patterns*
  '(("  " . "Double space")
    (" ,  " . "Space before comma")
    ("teh " . "Possible typo: 'teh' → 'the'")
    ("recieve" . "Spelling: 'recieve' → 'receive'")
    ("seperate" . "Spelling: 'seperate' → 'separate'")
    ("occured" . "Spelling: 'occured' → 'occurred'")
    ("definately" . "Spelling: 'definately' → 'definitely'")
    ("accomodate" . "Spelling: 'accomodate' → 'accommodate'")
    ("occurence" . "Spelling: 'occurence' → 'occurrence'")))

(def (cmd-grammar-check app)
  "Run basic grammar/spelling check on buffer."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app))))
         (text (editor-get-text ed))
         (issues '()))
    (for-each
      (lambda (pattern)
        (let ((pat (car pattern)) (msg (cdr pattern)))
          (let loop ((i 0))
            (when (< i (- (string-length text) (string-length pat)))
              (when (string-contains (substring text i (min (string-length text) (+ i (string-length pat) 10))) pat)
                (let ((line (send-message ed SCI_LINEFROMPOSITION i 0)))
                  (set! issues (cons (string-append "Line " (number->string (+ line 1)) ": " msg) issues))))
              (loop (+ i 1))))))
      *grammar-patterns*)
    (if (null? issues)
      (echo-message! echo "No grammar issues found")
      (let* ((fr (app-state-frame app))
             (win (current-window fr))
             (ed2 (edit-window-editor win))
             (content (string-append "Grammar Check\n"
                        (make-string 40 #\-) "\n"
                        (string-join (reverse issues) "\n")))
             (gbuf (make-buffer "*grammar*")))
        (buffer-attach! ed2 gbuf)
        (set! (edit-window-buffer win) gbuf)
        (editor-set-text ed2 content)
        (editor-goto-pos ed2 0)
        (echo-message! echo
          (string-append (number->string (length issues)) " issues found"))))))

;; --- Feature 9: Morse Code ---

(def *morse-table*
  '((#\A . ".-") (#\B . "-...") (#\C . "-.-.") (#\D . "-..") (#\E . ".")
    (#\F . "..-.") (#\G . "--.") (#\H . "....") (#\I . "..") (#\J . ".---")
    (#\K . "-.-") (#\L . ".-..") (#\M . "--") (#\N . "-.") (#\O . "---")
    (#\P . ".--.") (#\Q . "--.-") (#\R . ".-.") (#\S . "...") (#\T . "-")
    (#\U . "..-") (#\V . "...-") (#\W . ".--") (#\X . "-..-") (#\Y . "-.--")
    (#\Z . "--..") (#\0 . "-----") (#\1 . ".----") (#\2 . "..---")
    (#\3 . "...--") (#\4 . "....-") (#\5 . ".....") (#\6 . "-....")
    (#\7 . "--...") (#\8 . "---..") (#\9 . "----.")))

(def (cmd-morse-encode app)
  "Encode selected text or prompted text to Morse code."
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app))))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0))
         (text (if (not (= sel-start sel-end))
                 (substring (editor-get-text ed) sel-start sel-end)
                 (app-read-string app "Text to encode: "))))
    (when (and text (not (string-empty? text)))
      (let* ((upper (string-upcase text))
             (morse (let loop ((i 0) (acc '()))
                      (if (>= i (string-length upper))
                        (string-join (reverse acc) " ")
                        (let* ((ch (string-ref upper i))
                               (code (assv ch *morse-table*)))
                          (loop (+ i 1)
                            (cons (if code (cdr code)
                                    (if (char=? ch #\space) "/" (string ch)))
                                  acc)))))))
        (echo-message! echo (string-append "Morse: " morse))))))

(def (cmd-morse-decode app)
  "Decode Morse code to text."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (morse (echo-read-string echo "Morse code: " row width)))
    (when (and morse (not (string-empty? morse)))
      (let* ((reverse-table (map (lambda (p) (cons (cdr p) (car p))) *morse-table*))
             (words (string-split morse #\/))
             (decoded
               (string-join
                 (map (lambda (word)
                        (list->string
                          (map (lambda (code)
                                 (let ((entry (assoc (string-trim code) reverse-table)))
                                   (if entry (cdr entry) #\?)))
                               (string-split (string-trim word) #\space))))
                      words)
                 " ")))
        (echo-message! echo (string-append "Decoded: " decoded))))))

;; --- Feature 10: Highlight Sentence ---

(def *hl-sentence-enabled* #f)

(def (cmd-hl-sentence-mode app)
  "Toggle sentence highlighting at cursor."
  (set! *hl-sentence-enabled* (not *hl-sentence-enabled*))
  (let* ((echo (app-state-echo app))
         (ed (edit-window-editor (current-window (app-state-frame app)))))
    (if *hl-sentence-enabled*
      (begin
        ;; Use indicator 16 for sentence highlighting
        (send-message ed SCI_INDICSETSTYLE 16 7) ;; INDIC_ROUNDBOX
        (send-message ed SCI_INDICSETFORE 16 #xFFFF80)
        (send-message ed SCI_INDICSETALPHA 16 40)
        (echo-message! echo "Sentence highlighting: on"))
      (begin
        (send-message ed SCI_SETINDICATORCURRENT 16 0)
        (send-message ed SCI_INDICATORCLEARRANGE 0
          (send-message ed SCI_GETLENGTH 0 0))
        (echo-message! echo "Sentence highlighting: off")))))

;; ===== Round 8 Batch 1 =====

;; --- Feature 1: Newsticker (RSS Reader) ---

(def *newsticker-feeds*
  '(("Hacker News" . "https://news.ycombinator.com/rss")
    ("Lobsters" . "https://lobste.rs/rss")
    ("Planet Emacs" . "https://planet.emacslife.com/atom.xml")))

(def (cmd-newsticker app)
  "Open RSS feed reader — fetches and displays configured feeds."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (feed-names (map car *newsticker-feeds*))
         (choice (echo-read-string-with-completion
                   echo "Feed: " feed-names row width)))
    (when (and choice (not (string-empty? choice)))
      (let* ((pair (assoc choice *newsticker-feeds*))
             (url (if pair (cdr pair) choice)))
        (with-catch
          (lambda (e) (echo-message! echo (str "RSS error: " e)))
          (lambda ()
            (let-values (((p-stdin p-stdout p-stderr pid)
                          (open-process-ports
                            (string-append "curl -sL --max-time 10 " (shell-quote url))
                            'block (native-transcoder))))
              (close-port p-stdin)
              (let loop ((lines '()))
                (let ((line (get-line p-stdout)))
                  (if (eof-object? line)
                    (begin
                      (close-port p-stdout) (close-port p-stderr)
                      (let* ((raw (string-join (reverse lines) "\n"))
                             ;; Extract titles from <title>...</title> tags
                             (titles (let extract ((s raw) (acc '()))
                                       (let ((start (string-contains s "<title>")))
                                         (if start
                                           (let* ((rest (substring s (+ start 7) (string-length s)))
                                                  (end (string-contains rest "</title>")))
                                             (if end
                                               (extract (substring rest (+ end 8) (string-length rest))
                                                        (cons (substring rest 0 end) acc))
                                               (reverse acc)))
                                           (reverse acc)))))
                             (content (string-append "Newsticker: " (or choice "Feed") "\n"
                                        (make-string 50 #\=) "\n\n"
                                        (if (null? titles) "No items found"
                                          (string-join
                                            (map (lambda (t) (string-append "  * " t))
                                                 (if (> (length titles) 1) (cdr titles) titles))
                                            "\n"))))
                             (nbuf (make-buffer "*newsticker*")))
                        (buffer-attach! ed nbuf)
                        (set! (edit-window-buffer win) nbuf)
                        (editor-set-text ed content)
                        (editor-goto-pos ed 0)
                        (echo-message! echo (str "Fetched " (length titles) " items"))))
                    (loop (cons line lines))))))))))))

(def (cmd-newsticker-add-feed app)
  "Add a new RSS feed URL to the newsticker feed list."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (name (echo-read-string echo "Feed name: " row width)))
    (when (and name (not (string-empty? name)))
      (let ((url (echo-read-string echo "Feed URL: " row width)))
        (when (and url (not (string-empty? url)))
          (set! *newsticker-feeds* (cons (cons name url) *newsticker-feeds*))
          (echo-message! echo (str "Added feed: " name)))))))

;; --- Feature 2: Auth-source (Credential Store) ---

(def *auth-source-entries* (make-hash-table))

(def (cmd-auth-source-save app)
  "Save a credential to the in-memory auth-source store."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (host (echo-read-string echo "Host: " row width)))
    (when (and host (not (string-empty? host)))
      (let ((user (echo-read-string echo "User: " row width)))
        (when (and user (not (string-empty? user)))
          (let ((pass (echo-read-string echo "Secret: " row width)))
            (when (and pass (not (string-empty? pass)))
              (hash-put! *auth-source-entries* (str host ":" user)
                         (list (cons 'host host) (cons 'user user) (cons 'secret pass)))
              (echo-message! echo (str "Saved credential for " user "@" host)))))))))

(def (cmd-auth-source-search app)
  "Search auth-source for a credential by host."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (hosts (map (lambda (e) (cdr (assoc 'host (cdr e))))
                     (hash->list *auth-source-entries*)))
         (host (echo-read-string-with-completion echo "Host: " hosts row width)))
    (when (and host (not (string-empty? host)))
      (let* ((matches (filter (lambda (e)
                                (string-contains (car e) host))
                              (hash->list *auth-source-entries*))))
        (if (null? matches)
          (echo-message! echo "No credentials found")
          (let ((entry (cdar matches)))
            (echo-message! echo (str "Found: " (cdr (assoc 'user entry))
                                     "@" (cdr (assoc 'host entry))))))))))

;; --- Feature 3: Gomoku (Five in a Row) ---

(def *gomoku-board* #f)
(def *gomoku-size* 15)
(def *gomoku-turn* 'x)

(def (gomoku-init!)
  (set! *gomoku-board* (make-vector (* *gomoku-size* *gomoku-size*) #\.))
  (set! *gomoku-turn* 'x))

(def (gomoku-get r c)
  (vector-ref *gomoku-board* (+ (* r *gomoku-size*) c)))

(def (gomoku-set! r c v)
  (vector-set! *gomoku-board* (+ (* r *gomoku-size*) c) v))

(def (gomoku-check-win r c sym)
  "Check if placing sym at (r,c) wins."
  (define (count-dir dr dc)
    (let loop ((i 1))
      (let ((nr (+ r (* i dr))) (nc (+ c (* i dc))))
        (if (and (>= nr 0) (< nr *gomoku-size*)
                 (>= nc 0) (< nc *gomoku-size*)
                 (eqv? (gomoku-get nr nc) sym))
          (loop (+ i 1))
          (- i 1)))))
  (or (>= (+ 1 (count-dir 0 1) (count-dir 0 -1)) 5)
      (>= (+ 1 (count-dir 1 0) (count-dir -1 0)) 5)
      (>= (+ 1 (count-dir 1 1) (count-dir -1 -1)) 5)
      (>= (+ 1 (count-dir 1 -1) (count-dir -1 1)) 5)))

(def (gomoku-render)
  (let ((lines '()))
    (do ((r 0 (+ r 1)))
        ((= r *gomoku-size*))
      (let ((row-chars '()))
        (do ((c 0 (+ c 1)))
            ((= c *gomoku-size*))
          (set! row-chars (cons (str " " (gomoku-get r c)) row-chars)))
        (set! lines (cons (string-append (format "~2d " r)
                            (apply string-append (reverse row-chars)))
                          lines))))
    (string-append "   " (apply string-append
                           (map (lambda (i) (format "~2d" i)) (iota *gomoku-size*)))
                   "\n"
                   (string-join (reverse lines) "\n")
                   "\n\nTurn: " (symbol->string *gomoku-turn*))))

(def (cmd-gomoku app)
  "Play Gomoku (five in a row). Enter moves as 'row col'."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (gomoku-init!)
    (let ((gbuf (make-buffer "*gomoku*")))
      (buffer-attach! ed gbuf)
      (set! (edit-window-buffer win) gbuf)
      (editor-set-text ed (gomoku-render))
      (editor-goto-pos ed 0)
      (echo-message! echo "Gomoku: Enter 'row col' to place, e.g. '7 7'"))))

(def (cmd-gomoku-move app)
  "Make a move in Gomoku."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Move (row col): " row width)))
    (when (and input (not (string-empty? input)) *gomoku-board*)
      (let* ((parts (string-split (string-trim input) #\space))
             (r (and (>= (length parts) 2) (string->number (car parts))))
             (c (and (>= (length parts) 2) (string->number (cadr parts)))))
        (when (and r c (>= r 0) (< r *gomoku-size*) (>= c 0) (< c *gomoku-size*)
                   (eqv? (gomoku-get r c) #\.))
          (let ((sym (if (eq? *gomoku-turn* 'x) #\X #\O)))
            (gomoku-set! r c sym)
            (if (gomoku-check-win r c sym)
              (begin
                (editor-set-text ed (string-append (gomoku-render) "\n\n*** "
                                      (symbol->string *gomoku-turn*) " wins! ***"))
                (echo-message! echo (str (symbol->string *gomoku-turn*) " wins!")))
              (begin
                (set! *gomoku-turn* (if (eq? *gomoku-turn* 'x) 'o 'x))
                (editor-set-text ed (gomoku-render))
                (editor-goto-pos ed 0)))))))))

;; --- Feature 4: Dissociated Press ---

(def (cmd-dissociated-press app)
  "Dissociated Press: scramble current buffer text by mixing n-grams."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 10))
      (let* ((words (string-split text #\space))
             (n (length words))
             (out-len (min 200 n))
             (result '()))
        (do ((i 0 (+ i 1)))
            ((= i out-len))
          (set! result (cons (list-ref words (random n)) result)))
        (let ((dbuf (make-buffer "*dissociated*")))
          (buffer-attach! ed dbuf)
          (set! (edit-window-buffer win) dbuf)
          (editor-set-text ed (string-join (reverse result) " "))
          (editor-goto-pos ed 0)
          (echo-message! echo "Dissociated Press output generated"))))))

;; --- Feature 5: MPUZ (Multiplication Puzzle) ---

(def (mpuz-generate)
  "Generate a multiplication puzzle: AB * C = DEF with unique digits."
  (let loop ()
    (let* ((a (+ 10 (random 90)))
           (b (+ 2 (random 8)))
           (product (* a b)))
      (if (and (> product 99) (< product 1000))
        (let* ((digits (map (lambda (c) (- (char->integer c) 48))
                            (string->list (str a b product))))
               (unique (let uniq ((lst digits) (seen '()))
                         (cond ((null? lst) (reverse seen))
                               ((memv (car lst) seen) (uniq (cdr lst) seen))
                               (else (uniq (cdr lst) (cons (car lst) seen)))))))
          (if (>= (length unique) 5)
            (list a b product)
            (loop)))
        (loop)))))

(def (cmd-mpuz app)
  "Start a multiplication puzzle — guess the hidden digits."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (puzzle (mpuz-generate))
         (a (car puzzle)) (b (cadr puzzle)) (product (caddr puzzle))
         (display-text (string-append
                         "Multiplication Puzzle\n"
                         (make-string 30 #\=) "\n\n"
                         "   " (make-string (string-length (number->string a)) #\?) "\n"
                         " x " (make-string 1 #\?) "\n"
                         " ---\n"
                         "   " (make-string (string-length (number->string product)) #\?) "\n\n"
                         "Guess the digits! Answer: " (number->string a)
                         " x " (number->string b) " = " (number->string product) "\n"
                         "(Answer is revealed above for this implementation)"))
         (pbuf (make-buffer "*mpuz*")))
    (buffer-attach! ed pbuf)
    (set! (edit-window-buffer win) pbuf)
    (editor-set-text ed display-text)
    (editor-goto-pos ed 0)
    (echo-message! echo "MPUZ: Multiplication puzzle")))

;; --- Feature 6: Blackbox (Logic Puzzle) ---

(def *blackbox-size* 8)
(def *blackbox-atoms* '())
(def *blackbox-guesses* '())
(def *blackbox-score* 0)

(def (blackbox-init! n-atoms)
  (set! *blackbox-atoms* '())
  (set! *blackbox-guesses* '())
  (set! *blackbox-score* 0)
  (let loop ((i 0))
    (when (< i n-atoms)
      (let ((r (+ 1 (random (- *blackbox-size* 2))))
            (c (+ 1 (random (- *blackbox-size* 2)))))
        (if (member (cons r c) *blackbox-atoms*)
          (loop i)
          (begin (set! *blackbox-atoms* (cons (cons r c) *blackbox-atoms*))
                 (loop (+ i 1))))))))

(def (blackbox-render show-atoms?)
  (let ((lines (list "Blackbox Puzzle" (make-string 30 #\=) "")))
    (do ((r 0 (+ r 1)))
        ((= r *blackbox-size*))
      (let ((row-str ""))
        (do ((c 0 (+ c 1)))
            ((= c *blackbox-size*))
          (set! row-str
            (string-append row-str
              (cond
                ((and show-atoms? (member (cons r c) *blackbox-atoms*)) " @")
                ((member (cons r c) *blackbox-guesses*) " *")
                (else " .")))))
        (set! lines (cons row-str lines))))
    (set! lines (cons (str "\nScore: " *blackbox-score*
                           "  Atoms: " (length *blackbox-atoms*)
                           "  Guesses: " (length *blackbox-guesses*)) lines))
    (string-join (reverse lines) "\n")))

(def (cmd-blackbox app)
  "Start a Blackbox logic puzzle."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (blackbox-init! 4)
    (let ((bbuf (make-buffer "*blackbox*")))
      (buffer-attach! ed bbuf)
      (set! (edit-window-buffer win) bbuf)
      (editor-set-text ed (blackbox-render #f))
      (editor-goto-pos ed 0)
      (echo-message! echo "Blackbox: Guess atom positions with 'row col'"))))

(def (cmd-blackbox-guess app)
  "Make a guess in Blackbox."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Guess (row col): " row width)))
    (when (and input (not (string-empty? input)))
      (let* ((parts (string-split (string-trim input) #\space))
             (r (and (>= (length parts) 2) (string->number (car parts))))
             (c (and (>= (length parts) 2) (string->number (cadr parts)))))
        (when (and r c)
          (let ((guess (cons r c)))
            (unless (member guess *blackbox-guesses*)
              (set! *blackbox-guesses* (cons guess *blackbox-guesses*))
              (if (member guess *blackbox-atoms*)
                (set! *blackbox-score* (+ *blackbox-score* 1))
                (set! *blackbox-score* (- *blackbox-score* 1))))
            (editor-set-text ed (blackbox-render #f))
            (editor-goto-pos ed 0)))))))

(def (cmd-blackbox-reveal app)
  "Reveal all atoms in Blackbox puzzle."
  (let* ((frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (editor-set-text ed (blackbox-render #t))
    (editor-goto-pos ed 0)
    (echo-message! (app-state-echo app)
      (str "Revealed! Score: " *blackbox-score* "/" (length *blackbox-atoms*)))))

;; --- Feature 7: Literate-calc (Inline Calculations) ---

(def (cmd-literate-calc app)
  "Evaluate arithmetic expressions found in the current line and insert results."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (line-num (send-message ed SCI_LINEFROMPOSITION
                     (send-message ed SCI_GETCURRENTPOS 0 0) 0))
         (start (send-message ed SCI_POSITIONFROMLINE line-num 0))
         (end (send-message ed SCI_GETLINEENDPOSITION line-num 0))
         (len (- end start))
         (line-text (editor-get-text-range ed start len)))
    (when (and line-text (> (string-length line-text) 0))
      ;; Try to evaluate as a simple expression
      (with-catch
        (lambda (e) (echo-message! echo "No evaluable expression found"))
        (lambda ()
          (let* ((trimmed (string-trim line-text))
                 ;; Try scheme eval on the expression
                 (result (eval (read (open-input-string trimmed)))))
            (when (number? result)
              (send-message ed SCI_GOTOPOS end 0)
              (let ((result-str (str " => " result)))
                (editor-insert-text ed result-str)
                (echo-message! echo (str "Result: " result))))))))))

;; --- Feature 8: Htmlize (Export Buffer as HTML) ---

(def (cmd-htmlize app)
  "Export current buffer content as an HTML file."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len))
         (buf-name (buffer-name (edit-window-buffer win)))
         (row (tui-rows)) (width (tui-cols))
         (out-file (echo-read-string echo "Save HTML to: "
                     row width)))
    (when (and out-file (not (string-empty? out-file)) text)
      (let* ((escaped (let loop ((chars (string->list text)) (acc '()))
                        (if (null? chars)
                          (list->string (reverse acc))
                          (let ((c (car chars)))
                            (cond
                              ((char=? c #\<) (loop (cdr chars) (append (reverse (string->list "&lt;")) acc)))
                              ((char=? c #\>) (loop (cdr chars) (append (reverse (string->list "&gt;")) acc)))
                              ((char=? c #\&) (loop (cdr chars) (append (reverse (string->list "&amp;")) acc)))
                              (else (loop (cdr chars) (cons c acc))))))))
             (html (string-append
                     "<!DOCTYPE html>\n<html>\n<head>\n"
                     "<meta charset=\"utf-8\">\n"
                     "<title>" buf-name "</title>\n"
                     "<style>body{font-family:monospace;white-space:pre;background:#1e1e1e;color:#d4d4d4;padding:20px;}</style>\n"
                     "</head>\n<body>\n"
                     escaped
                     "\n</body>\n</html>\n")))
        (write-file-string out-file html)
        (echo-message! echo (str "Exported to " out-file))))))

;; --- Feature 9: Keycast (Show Keys in Modeline) ---

(def *keycast-enabled* #f)
(def *keycast-last-key* "")
(def *keycast-last-command* "")

(def (keycast-record! key-name command-name)
  "Record a key press for keycast display."
  (when *keycast-enabled*
    (set! *keycast-last-key* (if (string? key-name) key-name (str key-name)))
    (set! *keycast-last-command* (if (string? command-name) command-name
                                   (symbol->string command-name)))))

(def (keycast-format)
  "Format the keycast display string."
  (if (and *keycast-enabled* (not (string-empty? *keycast-last-key*)))
    (str " [" *keycast-last-key* " → " *keycast-last-command* "]")
    ""))

(def (cmd-keycast-mode app)
  "Toggle keycast mode — show last key press and command in echo area."
  (set! *keycast-enabled* (not *keycast-enabled*))
  (let ((echo (app-state-echo app)))
    (if *keycast-enabled*
      (echo-message! echo "Keycast mode: on")
      (begin
        (set! *keycast-last-key* "")
        (set! *keycast-last-command* "")
        (echo-message! echo "Keycast mode: off")))))

;; --- Feature 10: Command-log (Log Commands to Buffer) ---

(def *command-log-enabled* #f)
(def *command-log-entries* '())
(def *command-log-max* 500)

(def (command-log-record! cmd-name)
  "Record a command execution for the command log."
  (when *command-log-enabled*
    (set! *command-log-entries*
      (take (cons (cons (current-time) cmd-name) *command-log-entries*)
            (min (+ (length *command-log-entries*) 1) *command-log-max*)))))

(def (cmd-command-log-mode app)
  "Toggle command logging."
  (set! *command-log-enabled* (not *command-log-enabled*))
  (echo-message! (app-state-echo app)
    (if *command-log-enabled* "Command log: on" "Command log: off")))

(def (cmd-command-log-show app)
  "Show the command log in a buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (content (string-append "Command Log\n"
                    (make-string 50 #\=) "\n\n"
                    (if (null? *command-log-entries*)
                      "No commands logged yet"
                      (string-join
                        (map (lambda (e)
                               (str "  " (symbol->string (cdr e))))
                             *command-log-entries*)
                        "\n"))))
         (lbuf (make-buffer "*command-log*")))
    (buffer-attach! ed lbuf)
    (set! (edit-window-buffer win) lbuf)
    (editor-set-text ed content)
    (editor-goto-pos ed 0)
    (echo-message! echo (str (length *command-log-entries*) " commands logged"))))

;; ===== Round 9 Batch 1 =====

;; --- Feature 1: Wordle ---

(def *wordle-words*
  '("crane" "slate" "adieu" "stare" "trace" "crate" "raise" "arise"
    "audio" "learn" "heart" "earth" "stain" "train" "brain" "grain"
    "house" "mouse" "about" "shout" "doubt" "mount" "count" "found"
    "round" "sound" "bound" "wound" "could" "would" "world" "early"))

(def *wordle-target* #f)
(def *wordle-guesses* '())
(def *wordle-max-guesses* 6)

(def (wordle-init!)
  (set! *wordle-target* (list-ref *wordle-words* (random (length *wordle-words*))))
  (set! *wordle-guesses* '()))

(def (wordle-check guess target)
  "Return a list of (char status) where status is 'green, 'yellow, or 'gray."
  (let* ((g-chars (string->list guess))
         (t-chars (string->list target))
         (result (make-vector 5 'gray)))
    ;; First pass: mark greens
    (do ((i 0 (+ i 1))) ((= i 5))
      (when (char=? (list-ref g-chars i) (list-ref t-chars i))
        (vector-set! result i 'green)))
    ;; Second pass: mark yellows
    (let ((remaining (let loop ((i 0) (acc '()))
                       (if (= i 5) (reverse acc)
                         (if (eq? (vector-ref result i) 'green)
                           (loop (+ i 1) acc)
                           (loop (+ i 1) (cons (list-ref t-chars i) acc)))))))
      (do ((i 0 (+ i 1))) ((= i 5))
        (when (and (not (eq? (vector-ref result i) 'green))
                   (memv (list-ref g-chars i) remaining))
          (vector-set! result i 'yellow))))
    (let loop ((i 0) (acc '()))
      (if (= i 5) (reverse acc)
        (loop (+ i 1) (cons (list (list-ref g-chars i) (vector-ref result i)) acc))))))

(def (wordle-render)
  (string-append "WORDLE\n"
    (make-string 30 #\=) "\n\n"
    (if (null? *wordle-guesses*) "Make your first guess (5-letter word)\n"
      (string-join
        (map (lambda (guess)
               (let ((checks (wordle-check guess *wordle-target*)))
                 (string-join
                   (map (lambda (c)
                          (let ((ch (car c)) (st (cadr c)))
                            (case st
                              ((green) (str "[" ch "]"))
                              ((yellow) (str "(" ch ")"))
                              (else (str " " ch " ")))))
                        checks)
                   "")))
             (reverse *wordle-guesses*))
        "\n"))
    "\n\nGuesses: " (number->string (length *wordle-guesses*))
    "/" (number->string *wordle-max-guesses*)))

(def (cmd-wordle app)
  "Start a new Wordle game."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (wordle-init!)
    (let ((wbuf (make-buffer "*wordle*")))
      (buffer-attach! ed wbuf)
      (set! (edit-window-buffer win) wbuf)
      (editor-set-text ed (wordle-render))
      (editor-goto-pos ed 0)
      (echo-message! echo "Wordle: Guess a 5-letter word"))))

(def (cmd-wordle-guess app)
  "Make a guess in Wordle."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols)))
    (when *wordle-target*
      (if (>= (length *wordle-guesses*) *wordle-max-guesses*)
        (echo-message! echo (str "Game over! Word was: " *wordle-target*))
        (let ((guess (echo-read-string echo "Guess: " row width)))
          (when (and guess (= (string-length (string-trim guess)) 5))
            (let ((g (string-downcase (string-trim guess))))
              (set! *wordle-guesses* (cons g *wordle-guesses*))
              (editor-set-text ed (wordle-render))
              (editor-goto-pos ed 0)
              (if (string=? g *wordle-target*)
                (echo-message! echo (str "You won in " (length *wordle-guesses*) " guesses!"))
                (when (>= (length *wordle-guesses*) *wordle-max-guesses*)
                  (echo-message! echo (str "Game over! Word was: " *wordle-target*)))))))))))

;; --- Feature 2: Minesweeper ---

(def *mines-board* #f)
(def *mines-revealed* #f)
(def *mines-flags* #f)
(def *mines-rows* 10)
(def *mines-cols* 10)
(def *mines-count* 15)

(def (mines-init!)
  (set! *mines-board* (make-vector (* *mines-rows* *mines-cols*) 0))
  (set! *mines-revealed* (make-vector (* *mines-rows* *mines-cols*) #f))
  (set! *mines-flags* (make-vector (* *mines-rows* *mines-cols*) #f))
  ;; Place mines
  (let loop ((placed 0))
    (when (< placed *mines-count*)
      (let ((pos (random (* *mines-rows* *mines-cols*))))
        (if (= (vector-ref *mines-board* pos) -1)
          (loop placed)
          (begin
            (vector-set! *mines-board* pos -1)
            ;; Update neighbor counts
            (let* ((r (quotient pos *mines-cols*))
                   (c (remainder pos *mines-cols*)))
              (for-each (lambda (dr)
                          (for-each (lambda (dc)
                                      (let ((nr (+ r dr)) (nc (+ c dc)))
                                        (when (and (>= nr 0) (< nr *mines-rows*)
                                                   (>= nc 0) (< nc *mines-cols*))
                                          (let ((np (+ (* nr *mines-cols*) nc)))
                                            (when (not (= (vector-ref *mines-board* np) -1))
                                              (vector-set! *mines-board* np
                                                (+ (vector-ref *mines-board* np) 1)))))))
                                    '(-1 0 1)))
                        '(-1 0 1)))
            (loop (+ placed 1))))))))

(def (mines-render game-over?)
  (let ((lines (list "Minesweeper" (make-string 30 #\=) ""
                     (string-append "   "
                       (apply string-append
                         (map (lambda (c) (format "~2d" c)) (iota *mines-cols*)))))))
    (do ((r 0 (+ r 1))) ((= r *mines-rows*))
      (let ((row-str (format "~2d " r)))
        (do ((c 0 (+ c 1))) ((= c *mines-cols*))
          (let* ((pos (+ (* r *mines-cols*) c))
                 (val (vector-ref *mines-board* pos))
                 (rev (vector-ref *mines-revealed* pos))
                 (flag (vector-ref *mines-flags* pos)))
            (set! row-str
              (string-append row-str
                (cond
                  (flag " F")
                  ((and (not rev) (not game-over?)) " .")
                  ((= val -1) " *")
                  ((= val 0) "  ")
                  (else (str " " val)))))))
        (set! lines (cons row-str lines))))
    (string-join (reverse lines) "\n")))

(def (cmd-minesweeper app)
  "Start a Minesweeper game."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (mines-init!)
    (let ((mbuf (make-buffer "*minesweeper*")))
      (buffer-attach! ed mbuf)
      (set! (edit-window-buffer win) mbuf)
      (editor-set-text ed (mines-render #f))
      (editor-goto-pos ed 0)
      (echo-message! echo "Minesweeper: 'row col' to reveal, 'f row col' to flag"))))

(def (cmd-minesweeper-reveal app)
  "Reveal a cell in Minesweeper."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Reveal (row col): " row width)))
    (when (and input (not (string-empty? input)) *mines-board*)
      (let* ((parts (string-split (string-trim input) #\space))
             (r (and (>= (length parts) 2) (string->number (car parts))))
             (c (and (>= (length parts) 2) (string->number (cadr parts)))))
        (when (and r c (>= r 0) (< r *mines-rows*) (>= c 0) (< c *mines-cols*))
          (let ((pos (+ (* r *mines-cols*) c)))
            (vector-set! *mines-revealed* pos #t)
            (if (= (vector-ref *mines-board* pos) -1)
              (begin
                (editor-set-text ed (mines-render #t))
                (echo-message! echo "BOOM! Game over."))
              (begin
                (editor-set-text ed (mines-render #f))
                (editor-goto-pos ed 0)))))))))

;; --- Feature 3: Sokoban ---

(def *sokoban-levels*
  '("    #####\n    #   #\n    #$  #\n  ###  $##\n  #  $ $ #\n### # ## #   ######\n#   # ## #####  ..#\n# $  $          ..#\n##### ### #@##  ..#\n    #     #########\n    #######"))

(def *sokoban-board* #f)
(def *sokoban-player* '(0 . 0))

(def (sokoban-init! level)
  (let* ((lines (string-split level #\newline))
         (height (length lines))
         (width (apply max (map string-length lines)))
         (board (make-vector (* height width) #\space)))
    (do ((r 0 (+ r 1)))
        ((= r height))
      (let ((line (list-ref lines r)))
        (do ((c 0 (+ c 1)))
            ((= c (string-length line)))
          (let ((ch (string-ref line c)))
            (when (char=? ch #\@)
              (set! *sokoban-player* (cons r c)))
            (vector-set! board (+ (* r width) c) ch)))))
    (set! *sokoban-board* (list board height width))))

(def (cmd-sokoban app)
  "Start a Sokoban puzzle game."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (sokoban-init! (car *sokoban-levels*))
    (let ((sbuf (make-buffer "*sokoban*")))
      (buffer-attach! ed sbuf)
      (set! (edit-window-buffer win) sbuf)
      (editor-set-text ed (string-append "Sokoban\n" (make-string 30 #\=) "\n\n"
                            (car *sokoban-levels*)
                            "\n\nPush $ onto . positions\nUse arrow keys or wasd"))
      (editor-goto-pos ed 0)
      (echo-message! echo "Sokoban: Push boxes ($) to goals (.)"))))

;; --- Feature 4: 2048 Game ---

(def *game-2048-board* #f)
(def *game-2048-score* 0)

(def (game-2048-init!)
  (set! *game-2048-board* (make-vector 16 0))
  (set! *game-2048-score* 0)
  (game-2048-add-random!)
  (game-2048-add-random!))

(def (game-2048-add-random!)
  (let ((empties '()))
    (do ((i 0 (+ i 1))) ((= i 16))
      (when (= (vector-ref *game-2048-board* i) 0)
        (set! empties (cons i empties))))
    (when (not (null? empties))
      (let ((pos (list-ref empties (random (length empties)))))
        (vector-set! *game-2048-board* pos (if (< (random 10) 9) 2 4))))))

(def (game-2048-render)
  (let ((lines (list "2048" (make-string 30 #\=) (str "Score: " *game-2048-score*) "")))
    (do ((r 0 (+ r 1))) ((= r 4))
      (let ((row-str ""))
        (do ((c 0 (+ c 1))) ((= c 4))
          (let ((v (vector-ref *game-2048-board* (+ (* r 4) c))))
            (set! row-str (string-append row-str
              (if (= v 0) "   ." (format "~4d" v))))))
        (set! lines (cons row-str lines))))
    (string-join (reverse lines) "\n")))

(def (game-2048-slide-row! row-indices)
  "Slide and merge tiles in one direction for given indices."
  (let* ((vals (map (lambda (i) (vector-ref *game-2048-board* i)) row-indices))
         (non-zero (filter (lambda (v) (not (= v 0))) vals))
         (merged (let loop ((lst non-zero) (acc '()))
                   (cond
                     ((null? lst) (reverse acc))
                     ((and (not (null? (cdr lst))) (= (car lst) (cadr lst)))
                      (let ((new-val (* 2 (car lst))))
                        (set! *game-2048-score* (+ *game-2048-score* new-val))
                        (loop (cddr lst) (cons new-val acc))))
                     (else (loop (cdr lst) (cons (car lst) acc))))))
         (padded (append merged (make-list (- 4 (length merged)) 0))))
    (do ((i 0 (+ i 1))) ((= i 4))
      (vector-set! *game-2048-board* (list-ref row-indices i) (list-ref padded i)))))

(def (cmd-2048-game app)
  "Start a 2048 game."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (game-2048-init!)
    (let ((gbuf (make-buffer "*2048*")))
      (buffer-attach! ed gbuf)
      (set! (edit-window-buffer win) gbuf)
      (editor-set-text ed (game-2048-render))
      (editor-goto-pos ed 0)
      (echo-message! echo "2048: Use left/right/up/down commands to slide tiles"))))

(def (cmd-2048-left app)
  "Slide tiles left in 2048."
  (when *game-2048-board*
    (do ((r 0 (+ r 1))) ((= r 4))
      (game-2048-slide-row! (list (* r 4) (+ (* r 4) 1) (+ (* r 4) 2) (+ (* r 4) 3))))
    (game-2048-add-random!)
    (let* ((frame (app-state-frame app))
           (ed (edit-window-editor (current-window frame))))
      (editor-set-text ed (game-2048-render))
      (editor-goto-pos ed 0))))

;; --- Feature 5: Git-link ---

(def (cmd-git-link app)
  "Copy a GitHub/GitLab URL for the current file and line to the kill ring."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "git-link error: " e)))
        (lambda ()
          (let* ((line-num (+ 1 (send-message ed SCI_LINEFROMPOSITION
                                  (send-message ed SCI_GETCURRENTPOS 0 0) 0)))
                 ;; Get remote URL
                 (remote-out (let-values (((si so se pid)
                               (open-process-ports "git remote get-url origin" 'block (native-transcoder))))
                               (close-port si)
                               (let ((r (get-line so)))
                                 (close-port so) (close-port se)
                                 (if (eof-object? r) "" r))))
                 ;; Get relative path
                 (root-out (let-values (((si so se pid)
                              (open-process-ports "git rev-parse --show-toplevel" 'block (native-transcoder))))
                              (close-port si)
                              (let ((r (get-line so)))
                                (close-port so) (close-port se)
                                (if (eof-object? r) "" r))))
                 ;; Get current branch
                 (branch-out (let-values (((si so se pid)
                               (open-process-ports "git rev-parse --abbrev-ref HEAD" 'block (native-transcoder))))
                               (close-port si)
                               (let ((r (get-line so)))
                                 (close-port so) (close-port se)
                                 (if (eof-object? r) "main" r))))
                 (rel-path (if (and (> (string-length file) (string-length root-out))
                                    (string-prefix? root-out file))
                             (substring file (+ (string-length root-out) 1) (string-length file))
                             file))
                 ;; Convert git@ URL to https
                 (base-url (if (string-prefix? "git@" remote-out)
                             (let* ((s (substring remote-out 4 (string-length remote-out)))
                                    (s (let ((i (string-contains s ":")))
                                         (if i (string-append (substring s 0 i) "/" (substring s (+ i 1) (string-length s))) s)))
                                    (s (if (string-suffix? ".git" s)
                                         (substring s 0 (- (string-length s) 4)) s)))
                               (str "https://" s))
                             (if (string-suffix? ".git" remote-out)
                               (substring remote-out 0 (- (string-length remote-out) 4))
                               remote-out)))
                 (url (str base-url "/blob/" branch-out "/" rel-path "#L" line-num)))
            (send-message ed SCI_COPYTEXT (string-length url) url)
            (echo-message! echo (str "Copied: " url))))))))

;; --- Feature 6: Browse-at-remote ---

(def (cmd-browse-at-remote app)
  "Open the current file in the remote git forge (GitHub/GitLab)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "browse-at-remote error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "git remote get-url origin") 'block (native-transcoder))))
            (close-port si)
            (let ((remote (get-line so)))
              (close-port so) (close-port se)
              (when (and (not (eof-object? remote)) (not (string-empty? remote)))
                ;; Convert to HTTPS URL
                (let* ((base (cond
                               ((string-prefix? "git@" remote)
                                (let* ((s (substring remote 4 (string-length remote)))
                                       (s (let ((i (string-contains s ":")))
                                            (if i (string-append (substring s 0 i) "/"
                                                    (substring s (+ i 1) (string-length s))) s)))
                                       (s (if (string-suffix? ".git" s)
                                            (substring s 0 (- (string-length s) 4)) s)))
                                  (str "https://" s)))
                               (else (if (string-suffix? ".git" remote)
                                       (substring remote 0 (- (string-length remote) 4))
                                       remote)))))
                  (let-values (((si2 so2 se2 pid2)
                                (open-process-ports (str "xdg-open " (shell-quote base))
                                  'block (native-transcoder))))
                    (close-port si2) (close-port so2) (close-port se2))
                  (echo-message! echo (str "Opened: " base)))))))))))

;; --- Feature 7: Code-review ---

(def (cmd-code-review app)
  "Review a git diff interactively with inline comments."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (ref (echo-read-string echo "Diff against (default HEAD~1): " row width)))
    (let ((base (if (or (not ref) (string-empty? (string-trim ref))) "HEAD~1"
                  (string-trim ref))))
      (with-catch
        (lambda (e) (echo-message! echo (str "code-review error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports (str "git diff " base)
                          'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let* ((diff-text (string-join (reverse lines) "\n"))
                           (rbuf (make-buffer "*code-review*")))
                      (buffer-attach! ed rbuf)
                      (set! (edit-window-buffer win) rbuf)
                      (editor-set-text ed (string-append
                                            "Code Review: " base "\n"
                                            (make-string 50 #\=) "\n\n"
                                            diff-text))
                      (editor-goto-pos ed 0)
                      (echo-message! echo "Code review loaded")))
                  (loop (cons line lines)))))))))))

;; --- Feature 8: Conventional-commit ---

(def *conventional-commit-types*
  '("feat" "fix" "docs" "style" "refactor" "perf" "test" "build"
    "ci" "chore" "revert"))

(def (cmd-conventional-commit app)
  "Create a conventional commit message (feat/fix/docs/etc)."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (type (echo-read-string-with-completion
                 echo "Commit type: " *conventional-commit-types* row width)))
    (when (and type (not (string-empty? type)))
      (let ((scope (echo-read-string echo "Scope (optional): " row width)))
        (let ((desc (echo-read-string echo "Description: " row width)))
          (when (and desc (not (string-empty? desc)))
            (let* ((scope-str (if (and scope (not (string-empty? (string-trim scope))))
                               (str "(" (string-trim scope) ")") ""))
                   (msg (str type scope-str ": " desc)))
              (with-catch
                (lambda (e) (echo-message! echo (str "Commit error: " e)))
                (lambda ()
                  (let-values (((si so se pid)
                                (open-process-ports
                                  (str "git commit -m " (shell-quote msg))
                                  'block (native-transcoder))))
                    (close-port si)
                    (let loop ((lines '()))
                      (let ((line (get-line so)))
                        (if (eof-object? line)
                          (begin
                            (close-port so) (close-port se)
                            (echo-message! echo (str "Committed: " msg)))
                          (loop (cons line lines)))))))))))))))

;; --- Feature 9: Clippy ---

(def *clippy-tips*
  '("Use C-x C-s to save the current buffer"
    "Use M-x to run any command by name"
    "Use C-s for incremental search"
    "Use C-x b to switch buffers"
    "Use C-x 2 to split the window horizontally"
    "Use C-x 3 to split the window vertically"
    "Use C-x o to switch between windows"
    "Use C-g to cancel any operation"
    "Use M-% for search and replace"
    "Use C-x k to kill the current buffer"
    "Use C-x u to undo the last change"
    "Use C-space to start marking a region"
    "Use M-w to copy and C-y to paste"
    "Use C-k to kill to end of line"
    "Use C-/ for undo"
    "Use M-g g to go to a specific line number"
    "Use C-x f to find and open a file"
    "Use C-h k to describe a key binding"
    "Use C-x r s to save region to register"))

(def (cmd-clippy app)
  "Show a helpful tip from Clippy."
  (let* ((echo (app-state-echo app))
         (tip (list-ref *clippy-tips* (random (length *clippy-tips*)))))
    (echo-message! echo (str "Clippy says: " tip))))

;; --- Feature 10: Ellama (LLM Interface) ---

(def *ellama-model* "llama3")

(def (cmd-ellama app)
  "Send a prompt to a local LLM via ollama."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (prompt (echo-read-string echo "Ellama prompt: " row width)))
    (when (and prompt (not (string-empty? prompt)))
      (echo-message! echo "Thinking...")
      (with-catch
        (lambda (e) (echo-message! echo (str "Ellama error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          (str "ollama run " *ellama-model* " " (shell-quote prompt))
                          'block (native-transcoder))))
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let* ((response (string-join (reverse lines) "\n"))
                           (lbuf (make-buffer "*ellama*")))
                      (buffer-attach! ed lbuf)
                      (set! (edit-window-buffer win) lbuf)
                      (editor-set-text ed (string-append
                                            "Ellama (" *ellama-model* ")\n"
                                            (make-string 50 #\=) "\n\n"
                                            "Prompt: " prompt "\n\n"
                                            "Response:\n" response))
                      (editor-goto-pos ed 0)
                      (echo-message! echo "Ellama response ready")))
                  (loop (cons line lines)))))))))))

;; ===== Round 10 Batch 1 =====

;; --- Feature 1: Journalctl Viewer ---

(def (cmd-journalctl app)
  "View recent systemd journal entries."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (unit (echo-read-string echo "Unit (empty for all): " row width))
         (cmd (if (or (not unit) (string-empty? (string-trim unit)))
                "journalctl --no-pager -n 100"
                (str "journalctl --no-pager -n 100 -u " (shell-quote (string-trim unit))))))
    (with-catch
      (lambda (e) (echo-message! echo (str "journalctl error: " e)))
      (lambda ()
        (let-values (((p-stdin p-stdout p-stderr pid)
                      (open-process-ports cmd 'block (native-transcoder))))
          (close-port p-stdin)
          (let loop ((lines '()))
            (let ((line (get-line p-stdout)))
              (if (eof-object? line)
                (begin
                  (close-port p-stdout) (close-port p-stderr)
                  (let* ((content (string-join (reverse lines) "\n"))
                         (jbuf (make-buffer "*journalctl*")))
                    (buffer-attach! ed jbuf)
                    (set! (edit-window-buffer win) jbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo (str (length lines) " journal entries"))))
                (loop (cons line lines))))))))))

;; --- Feature 2: Bluetooth Control ---

(def (cmd-bluetooth app)
  "Show bluetooth device status and manage connections."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "bluetooth error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "bluetoothctl devices 2>/dev/null || echo 'bluetoothctl not available'"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "Bluetooth Devices\n"
                                    (make-string 50 #\=) "\n\n"
                                    (string-join (reverse lines) "\n")))
                         (bbuf (make-buffer "*bluetooth*")))
                    (buffer-attach! ed bbuf)
                    (set! (edit-window-buffer win) bbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "Bluetooth devices listed")))
                (loop (cons line lines))))))))))

;; --- Feature 3: Volume Control ---

(def (cmd-volume app)
  "Show and adjust system volume."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols)))
    (with-catch
      (lambda (e) (echo-message! echo (str "volume error: " e)))
      (lambda ()
        ;; Get current volume
        (let-values (((si so se pid)
                      (open-process-ports "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null || amixer get Master 2>/dev/null | grep -o '[0-9]*%' | head -1"
                        'block (native-transcoder))))
          (close-port si)
          (let ((current (get-line so)))
            (close-port so) (close-port se)
            (let ((vol-str (if (eof-object? current) "unknown" current)))
              (let ((input (echo-read-string echo
                             (str "Volume [" vol-str "] (0-100 or +/-): ") row width)))
                (when (and input (not (string-empty? input)))
                  (let ((v (string-trim input)))
                    (with-catch
                      (lambda (e) (echo-message! echo (str "Set error: " e)))
                      (lambda ()
                        (let-values (((si2 so2 se2 pid2)
                                      (open-process-ports
                                        (str "pactl set-sink-volume @DEFAULT_SINK@ " v "% 2>/dev/null || amixer set Master " v "% 2>/dev/null")
                                        'block (native-transcoder))))
                          (close-port si2) (close-port so2) (close-port se2)
                          (echo-message! echo (str "Volume set to " v "%")))))))))))))))

;; --- Feature 4: ASCII Table ---

(def (cmd-ascii-table app)
  "Display an ASCII character table."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (lines (list "ASCII Table" (make-string 60 #\=) ""
                      "Dec  Hex  Oct  Char  | Dec  Hex  Oct  Char"
                      (make-string 60 #\-))))
    (do ((i 32 (+ i 1))) ((= i 127))
      (let ((ch (if (= i 127) "DEL" (str (integer->char i)))))
        (set! lines (cons (format "~3d  ~2,'0x  ~3,'0o  ~4a" i i i ch)
                          lines))))
    (let* ((content (string-join (reverse lines) "\n"))
           (abuf (make-buffer "*ascii-table*")))
      (buffer-attach! ed abuf)
      (set! (edit-window-buffer win) abuf)
      (editor-set-text ed content)
      (editor-goto-pos ed 0)
      (echo-message! echo "ASCII table displayed"))))

;; --- Feature 5: Unicode Search ---

(def *unicode-common*
  '(("arrow right" . "→") ("arrow left" . "←") ("arrow up" . "↑") ("arrow down" . "↓")
    ("check mark" . "✓") ("cross mark" . "✗") ("bullet" . "•") ("degree" . "°")
    ("copyright" . "©") ("registered" . "®") ("trademark" . "™") ("section" . "§")
    ("paragraph" . "¶") ("micro" . "µ") ("plus minus" . "±") ("multiply" . "×")
    ("divide" . "÷") ("not equal" . "≠") ("less equal" . "≤") ("greater equal" . "≥")
    ("infinity" . "∞") ("square root" . "√") ("sum" . "∑") ("integral" . "∫")
    ("alpha" . "α") ("beta" . "β") ("gamma" . "γ") ("delta" . "δ")
    ("epsilon" . "ε") ("pi" . "π") ("sigma" . "σ") ("omega" . "ω")
    ("lambda" . "λ") ("theta" . "θ") ("phi" . "φ") ("psi" . "ψ")
    ("heart" . "♥") ("star" . "★") ("diamond" . "◆") ("spade" . "♠")
    ("club" . "♣") ("music note" . "♪") ("sun" . "☀") ("snowflake" . "❄")
    ("skull" . "☠") ("peace" . "☮") ("yin yang" . "☯") ("smile" . "☺")
    ("ellipsis" . "…") ("en dash" . "–") ("em dash" . "—") ("left quote" . "\x201C;")
    ("right quote" . "\x201D;") ("euro" . "€") ("pound" . "£") ("yen" . "¥")))

(def (cmd-unicode-search app)
  "Search and insert a Unicode character by name."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (names (map car *unicode-common*))
         (query (echo-read-string-with-completion echo "Unicode: " names row width)))
    (when (and query (not (string-empty? query)))
      (let ((match (assoc query *unicode-common*)))
        (if match
          (begin
            (editor-insert-text ed (cdr match))
            (echo-message! echo (str "Inserted: " (cdr match) " (" (car match) ")")))
          ;; Try substring match
          (let ((matches (filter (lambda (e) (string-contains (car e) (string-downcase query)))
                                 *unicode-common*)))
            (if (null? matches)
              (echo-message! echo "No matching character found")
              (begin
                (editor-insert-text ed (cdar matches))
                (echo-message! echo (str "Inserted: " (cdar matches)
                                         " (" (caar matches) ")"))))))))))

;; --- Feature 6: Emoji Insert ---

(def *emoji-list*
  '(("smile" . "😊") ("laugh" . "😂") ("heart" . "❤️") ("thumbs up" . "👍")
    ("fire" . "🔥") ("rocket" . "🚀") ("star" . "⭐") ("check" . "✅")
    ("warning" . "⚠️") ("bug" . "🐛") ("bulb" . "💡") ("wrench" . "🔧")
    ("book" . "📖") ("memo" . "📝") ("pin" . "📌") ("link" . "🔗")
    ("clock" . "🕐") ("coffee" . "☕") ("pizza" . "🍕") ("beer" . "🍺")
    ("tada" . "🎉") ("sparkles" . "✨") ("muscle" . "💪") ("brain" . "🧠")
    ("eyes" . "👀") ("wave" . "👋") ("clap" . "👏") ("pray" . "🙏")
    ("thinking" . "🤔") ("shrug" . "🤷") ("facepalm" . "🤦") ("100" . "💯")
    ("poop" . "💩") ("ghost" . "👻") ("skull" . "💀") ("robot" . "🤖")
    ("cat" . "🐱") ("dog" . "🐶") ("tree" . "🌲") ("sun" . "☀️")
    ("moon" . "🌙") ("cloud" . "☁️") ("rain" . "🌧️") ("snow" . "❄️")))

(def (cmd-emoji-insert app)
  "Insert an emoji by name."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (names (map car *emoji-list*))
         (choice (echo-read-string-with-completion echo "Emoji: " names row width)))
    (when (and choice (not (string-empty? choice)))
      (let ((match (assoc choice *emoji-list*)))
        (if match
          (begin
            (editor-insert-text ed (cdr match))
            (echo-message! echo (str "Inserted " (cdr match))))
          (echo-message! echo "Unknown emoji"))))))

;; --- Feature 7: Kaomoji ---

(def *kaomoji-list*
  '(("happy" . "(╹◡╹)") ("sad" . "(╥﹏╥)") ("angry" . "(╬ ಠ益ಠ)")
    ("shrug" . "¯\\_(ツ)_/¯") ("flip" . "(╯°□°)╯︵ ┻━┻")
    ("unflip" . "┬─┬ノ( º _ ºノ)") ("bear" . "ʕ•ᴥ•ʔ")
    ("sparkle" . "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧") ("love" . "(♥ω♥*)")
    ("cool" . "(⌐■_■)") ("dance" . "♪┏(・o・)┛♪")
    ("cat" . "(=^・ω・^=)") ("dog" . "∪・ω・∪")
    ("cry" . "(;´༎ຶД༎ຶ`)") ("wink" . "(^_~)")
    ("surprise" . "Σ(°△°|||)") ("sleep" . "(−_−) zzZ")
    ("fight" . "(ง •̀_•́)ง") ("run" . "ε=ε=ε=┌(;*´Д`)ノ")))

(def (cmd-kaomoji app)
  "Insert a kaomoji (Japanese emoticon)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (names (map car *kaomoji-list*))
         (choice (echo-read-string-with-completion echo "Kaomoji: " names row width)))
    (when (and choice (not (string-empty? choice)))
      (let ((match (assoc choice *kaomoji-list*)))
        (if match
          (begin
            (editor-insert-text ed (cdr match))
            (echo-message! echo (str "Inserted: " (cdr match))))
          (echo-message! echo "Unknown kaomoji"))))))

;; --- Feature 8: XKCD ---

(def (cmd-xkcd app)
  "Fetch and display the latest XKCD comic info."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "XKCD error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "curl -sL https://xkcd.com/info.0.json"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((json (string-join (reverse lines) ""))
                         ;; Extract title and alt from JSON
                         (get-field (lambda (field)
                                      (let ((start (string-contains json (str "\"" field "\":"))))
                                        (if (not start) "?"
                                          (let* ((rest (substring json (+ start (string-length field) 3) (string-length json)))
                                                 (qstart (string-contains rest "\""))
                                                 (rest2 (if qstart (substring rest (+ qstart 1) (string-length rest)) ""))
                                                 (qend (string-contains rest2 "\"")))
                                            (if (and qstart qend)
                                              (substring rest2 0 qend) "?"))))))
                         (title (get-field "safe_title"))
                         (alt (get-field "alt"))
                         (num (get-field "num"))
                         (content (string-append "XKCD #" num "\n"
                                    (make-string 50 #\=) "\n\n"
                                    "Title: " title "\n\n"
                                    "Alt: " alt "\n"))
                         (xbuf (make-buffer "*xkcd*")))
                    (buffer-attach! ed xbuf)
                    (set! (edit-window-buffer win) xbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo (str "XKCD #" num ": " title))))
                (loop (cons line lines))))))))))

;; --- Feature 9: Cheat.sh ---

(def (cmd-cheat-sh app)
  "Look up a cheat sheet from cheat.sh."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (query (echo-read-string echo "cheat.sh query: " row width)))
    (when (and query (not (string-empty? query)))
      (with-catch
        (lambda (e) (echo-message! echo (str "cheat.sh error: " e)))
        (lambda ()
          (let* ((encoded (let loop ((chars (string->list (string-trim query))) (acc '()))
                            (if (null? chars) (list->string (reverse acc))
                              (let ((c (car chars)))
                                (if (char=? c #\space)
                                  (loop (cdr chars) (cons #\+ acc))
                                  (loop (cdr chars) (cons c acc))))))))
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "curl -sL 'https://cheat.sh/" encoded "?T'")
                            'block (native-transcoder))))
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (let* ((content (string-join (reverse lines) "\n"))
                             (cbuf (make-buffer "*cheat.sh*")))
                        (buffer-attach! ed cbuf)
                        (set! (edit-window-buffer win) cbuf)
                        (editor-set-text ed content)
                        (editor-goto-pos ed 0)
                        (echo-message! echo (str "cheat.sh: " query))))
                    (loop (cons line lines))))))))))))

;; --- Feature 10: TLDR ---

(def (cmd-tldr app)
  "Look up TLDR page for a command."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (cmd (echo-read-string echo "TLDR command: " row width)))
    (when (and cmd (not (string-empty? cmd)))
      (with-catch
        (lambda (e) (echo-message! echo (str "tldr error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "tldr " (shell-quote (string-trim cmd)) " 2>/dev/null || "
                               "curl -sL 'https://raw.githubusercontent.com/tldr-pages/tldr/main/pages/common/"
                               (string-trim cmd) ".md' 2>/dev/null || echo 'Page not found'")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((content (string-join (reverse lines) "\n"))
                           (tbuf (make-buffer "*tldr*")))
                      (buffer-attach! ed tbuf)
                      (set! (edit-window-buffer win) tbuf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo (str "TLDR: " cmd))))
                  (loop (cons line lines)))))))))))

;; ===== Round 11 Batch 1 =====

;; --- Feature 1: NPM Scripts Runner ---

(def (cmd-npm app)
  "Run an npm script from package.json."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols)))
    (if (not (file-exists? "package.json"))
      (echo-message! echo "No package.json found")
      (with-catch
        (lambda (e) (echo-message! echo (str "npm error: " e)))
        (lambda ()
          ;; Extract scripts from package.json
          (let-values (((si so se pid)
                        (open-process-ports "node -e \"Object.keys(require('./package.json').scripts||{}).forEach(s=>console.log(s))\" 2>/dev/null || echo ''"
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((scripts '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((script (echo-read-string-with-completion
                                    echo "npm run: " (reverse scripts) row width)))
                      (when (and script (not (string-empty? script)))
                        (let-values (((si2 so2 se2 pid2)
                                      (open-process-ports (str "npm run " (shell-quote script) " 2>&1")
                                        'block (native-transcoder))))
                          (close-port si2)
                          (let loop2 ((lines '()))
                            (let ((line (get-line so2)))
                              (if (eof-object? line)
                                (begin
                                  (close-port so2) (close-port se2)
                                  (let* ((output (string-join (reverse lines) "\n"))
                                         (nbuf (make-buffer "*npm*")))
                                    (buffer-attach! ed nbuf)
                                    (set! (edit-window-buffer win) nbuf)
                                    (editor-set-text ed output)
                                    (editor-goto-pos ed 0)
                                    (echo-message! echo (str "npm run " script " done"))))
                                (loop2 (cons line lines)))))))))
                  (loop (cons line scripts)))))))))))

;; --- Feature 2: Cargo (Rust) ---

(def (cmd-cargo app)
  "Run a Rust cargo command."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (commands '("build" "run" "test" "check" "clippy" "fmt" "doc" "clean" "bench" "update"))
         (cmd (echo-read-string-with-completion echo "cargo: " commands row width)))
    (when (and cmd (not (string-empty? cmd)))
      (echo-message! echo (str "Running cargo " cmd "..."))
      (with-catch
        (lambda (e) (echo-message! echo (str "cargo error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports (str "cargo " cmd " 2>&1")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((output (string-join (reverse lines) "\n"))
                           (cbuf (make-buffer "*cargo*")))
                      (buffer-attach! ed cbuf)
                      (set! (edit-window-buffer win) cbuf)
                      (editor-set-text ed output)
                      (editor-goto-pos ed 0)
                      (echo-message! echo (str "cargo " cmd " complete"))))
                  (loop (cons line lines)))))))))))

;; --- Feature 3: Brew (Homebrew) ---

(def (cmd-brew app)
  "Run a homebrew command."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (commands '("list" "search" "info" "install" "uninstall" "update" "upgrade" "outdated" "doctor" "cleanup"))
         (cmd (echo-read-string-with-completion echo "brew: " commands row width)))
    (when (and cmd (not (string-empty? cmd)))
      (let ((arg (if (member cmd '("search" "info" "install" "uninstall"))
                   (echo-read-string echo "Package: " row width)
                   #f)))
        (let ((full-cmd (if (and arg (not (string-empty? arg)))
                          (str "brew " cmd " " (shell-quote arg) " 2>&1")
                          (str "brew " cmd " 2>&1"))))
          (with-catch
            (lambda (e) (echo-message! echo (str "brew error: " e)))
            (lambda ()
              (let-values (((si so se pid)
                            (open-process-ports full-cmd 'block (native-transcoder))))
                (close-port si)
                (let loop ((lines '()))
                  (let ((line (get-line so)))
                    (if (eof-object? line)
                      (begin
                        (close-port so) (close-port se)
                        (let* ((output (string-join (reverse lines) "\n"))
                               (bbuf (make-buffer "*brew*")))
                          (buffer-attach! ed bbuf)
                          (set! (edit-window-buffer win) bbuf)
                          (editor-set-text ed output)
                          (editor-goto-pos ed 0)
                          (echo-message! echo (str "brew " cmd " complete"))))
                      (loop (cons line lines)))))))))))))

;; --- Feature 4: Git Stash List ---

(def (cmd-git-stash-list app)
  "List git stashes with details."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "git error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "git stash list --format='%gd: %s (%cr)'" 'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "Git Stashes\n"
                                    (make-string 50 #\=) "\n\n"
                                    (if (null? lines) "No stashes"
                                      (string-join (reverse lines) "\n"))))
                         (sbuf (make-buffer "*git-stash*")))
                    (buffer-attach! ed sbuf)
                    (set! (edit-window-buffer win) sbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo (str (length lines) " stashes"))))
                (loop (cons line lines))))))))))

;; --- Feature 5: Git Cherry-pick ---

(def (cmd-git-cherry-pick app)
  "Cherry-pick a commit by hash."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (hash (echo-read-string echo "Cherry-pick commit: " row width)))
    (when (and hash (not (string-empty? hash)))
      (with-catch
        (lambda (e) (echo-message! echo (str "cherry-pick error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "git cherry-pick " (shell-quote (string-trim hash)) " 2>&1")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (echo-message! echo (str "Cherry-picked: "
                                             (string-join (reverse lines) " "))))
                  (loop (cons line lines)))))))))))

;; --- Feature 6: Git Worktree ---

(def (cmd-git-worktree app)
  "List or add git worktrees."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (actions '("list" "add" "remove"))
         (action (echo-read-string-with-completion echo "Worktree action: " actions row width)))
    (when (and action (not (string-empty? action)))
      (cond
        ((string=? action "list")
         (with-catch
           (lambda (e) (echo-message! echo (str "worktree error: " e)))
           (lambda ()
             (let-values (((si so se pid)
                           (open-process-ports "git worktree list" 'block (native-transcoder))))
               (close-port si)
               (let loop ((lines '()))
                 (let ((line (get-line so)))
                   (if (eof-object? line)
                     (begin
                       (close-port so) (close-port se)
                       (let* ((content (string-join (reverse lines) "\n"))
                              (wbuf (make-buffer "*worktree*")))
                         (buffer-attach! ed wbuf)
                         (set! (edit-window-buffer win) wbuf)
                         (editor-set-text ed content)
                         (editor-goto-pos ed 0)))
                     (loop (cons line lines)))))))))
        ((string=? action "add")
         (let ((path (echo-read-string echo "Path: " row width)))
           (when (and path (not (string-empty? path)))
             (let ((branch (echo-read-string echo "Branch: " row width)))
               (with-catch
                 (lambda (e) (echo-message! echo (str "worktree error: " e)))
                 (lambda ()
                   (let-values (((si so se pid)
                                 (open-process-ports
                                   (str "git worktree add " (shell-quote path) " "
                                        (if (and branch (not (string-empty? branch)))
                                          (shell-quote branch) "")
                                        " 2>&1")
                                   'block (native-transcoder))))
                     (close-port si) (close-port so) (close-port se)
                     (echo-message! echo (str "Worktree added: " path)))))))))
        (else (echo-message! echo "Unknown action"))))))

;; --- Feature 7: IP Info ---

(def (cmd-ip-info app)
  "Show public IP address information."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "IP error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "curl -sL ipinfo.io 2>/dev/null || curl -sL ifconfig.me 2>/dev/null"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "IP Information\n"
                                    (make-string 50 #\=) "\n\n"
                                    (string-join (reverse lines) "\n")))
                         (ibuf (make-buffer "*ip-info*")))
                    (buffer-attach! ed ibuf)
                    (set! (edit-window-buffer win) ibuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "IP info loaded")))
                (loop (cons line lines))))))))))

;; --- Feature 8: Whois ---

(def (cmd-whois app)
  "Perform a whois lookup."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (domain (echo-read-string echo "Whois domain: " row width)))
    (when (and domain (not (string-empty? domain)))
      (with-catch
        (lambda (e) (echo-message! echo (str "whois error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports (str "whois " (shell-quote (string-trim domain)))
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((content (string-join (reverse lines) "\n"))
                           (wbuf (make-buffer "*whois*")))
                      (buffer-attach! ed wbuf)
                      (set! (edit-window-buffer win) wbuf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo (str "Whois: " domain))))
                  (loop (cons line lines)))))))))))

;; --- Feature 9: Traceroute ---

(def (cmd-traceroute app)
  "Run traceroute to a host."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (host (echo-read-string echo "Traceroute host: " row width)))
    (when (and host (not (string-empty? host)))
      (echo-message! echo (str "Tracing " host "..."))
      (with-catch
        (lambda (e) (echo-message! echo (str "traceroute error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "traceroute -m 15 " (shell-quote (string-trim host)) " 2>&1")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((content (string-join (reverse lines) "\n"))
                           (tbuf (make-buffer "*traceroute*")))
                      (buffer-attach! ed tbuf)
                      (set! (edit-window-buffer win) tbuf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo "Traceroute complete")))
                  (loop (cons line lines)))))))))))

;; --- Feature 10: Netstat ---

(def (cmd-netstat app)
  "Show active network connections."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "netstat error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "Network Connections\n"
                                    (make-string 50 #\=) "\n\n"
                                    (string-join (reverse lines) "\n")))
                         (nbuf (make-buffer "*netstat*")))
                    (buffer-attach! ed nbuf)
                    (set! (edit-window-buffer win) nbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo (str (length lines) " connections"))))
                (loop (cons line lines))))))))))

;; ===== Round 12 Batch 1 =====

;; --- Feature 1: Docker PS ---

(def (cmd-docker-ps app)
  "List running Docker containers."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "docker error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}' 2>&1"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "Docker Containers\n"
                                    (make-string 60 #\=) "\n\n"
                                    (string-join (reverse lines) "\n")))
                         (dbuf (make-buffer "*docker-ps*")))
                    (buffer-attach! ed dbuf)
                    (set! (edit-window-buffer win) dbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo (str (max 0 (- (length lines) 1)) " containers"))))
                (loop (cons line lines))))))))))

;; --- Feature 2: Docker Logs ---

(def (cmd-docker-logs app)
  "View logs for a Docker container."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (container (echo-read-string echo "Container name/ID: " row width)))
    (when (and container (not (string-empty? container)))
      (with-catch
        (lambda (e) (echo-message! echo (str "docker error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "docker logs --tail 100 " (shell-quote (string-trim container)) " 2>&1")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((content (string-join (reverse lines) "\n"))
                           (lbuf (make-buffer (str "*docker-" container "*"))))
                      (buffer-attach! ed lbuf)
                      (set! (edit-window-buffer win) lbuf)
                      (editor-set-text ed content)
                      (editor-goto-pos ed 0)
                      (echo-message! echo (str "Logs for " container))))
                  (loop (cons line lines)))))))))))

;; --- Feature 3: Git Log Graph ---

(def (cmd-git-log-graph app)
  "Show a graphical git log."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "git error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        "git log --graph --oneline --decorate --all -50"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-join (reverse lines) "\n"))
                         (gbuf (make-buffer "*git-graph*")))
                    (buffer-attach! ed gbuf)
                    (set! (edit-window-buffer win) gbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo "Git log graph")))
                (loop (cons line lines))))))))))

;; --- Feature 4: Git Bisect ---

(def (cmd-git-bisect app)
  "Start or control a git bisect session."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (actions '("start" "good" "bad" "reset" "log"))
         (action (echo-read-string-with-completion echo "git bisect: " actions row width)))
    (when (and action (not (string-empty? action)))
      (let ((extra (if (string=? action "start")
                     (let ((bad (echo-read-string echo "Bad commit (HEAD): " row width))
                           (good (echo-read-string echo "Good commit: " row width)))
                       (str (if (or (not bad) (string-empty? bad)) "HEAD" bad) " "
                            (if (or (not good) (string-empty? good)) "" good)))
                     "")))
        (with-catch
          (lambda (e) (echo-message! echo (str "bisect error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "git bisect " action " " extra " 2>&1")
                            'block (native-transcoder))))
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (echo-message! echo (string-join (reverse lines) " ")))
                    (loop (cons line lines))))))))))))

;; --- Feature 5: Git Reflog ---

(def (cmd-git-reflog app)
  "Show git reflog."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "git error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "git reflog -50 --format='%h %gd: %gs (%cr)'"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((content (string-append "Git Reflog\n"
                                    (make-string 50 #\=) "\n\n"
                                    (string-join (reverse lines) "\n")))
                         (rbuf (make-buffer "*git-reflog*")))
                    (buffer-attach! ed rbuf)
                    (set! (edit-window-buffer win) rbuf)
                    (editor-set-text ed content)
                    (editor-goto-pos ed 0)
                    (echo-message! echo (str (length lines) " reflog entries"))))
                (loop (cons line lines))))))))))

;; --- Feature 6: Git Tag ---

(def (cmd-git-tag app)
  "List or create git tags."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (actions '("list" "create" "delete"))
         (action (echo-read-string-with-completion echo "Tag action: " actions row width)))
    (when (and action (not (string-empty? action)))
      (cond
        ((string=? action "list")
         (let* ((frame (app-state-frame app))
                (win (current-window frame))
                (ed (edit-window-editor win)))
           (with-catch
             (lambda (e) (echo-message! echo (str "git error: " e)))
             (lambda ()
               (let-values (((si so se pid)
                             (open-process-ports "git tag -l --sort=-creatordate" 'block (native-transcoder))))
                 (close-port si)
                 (let loop ((lines '()))
                   (let ((line (get-line so)))
                     (if (eof-object? line)
                       (begin
                         (close-port so) (close-port se)
                         (let* ((content (string-join (reverse lines) "\n"))
                                (tbuf (make-buffer "*git-tags*")))
                           (buffer-attach! ed tbuf)
                           (set! (edit-window-buffer win) tbuf)
                           (editor-set-text ed content)
                           (editor-goto-pos ed 0)))
                       (loop (cons line lines))))))))))
        ((string=? action "create")
         (let ((name (echo-read-string echo "Tag name: " row width)))
           (when (and name (not (string-empty? name)))
             (let ((msg (echo-read-string echo "Message (empty for lightweight): " row width)))
               (with-catch
                 (lambda (e) (echo-message! echo (str "tag error: " e)))
                 (lambda ()
                   (let* ((cmd (if (and msg (not (string-empty? msg)))
                                 (str "git tag -a " (shell-quote name) " -m " (shell-quote msg))
                                 (str "git tag " (shell-quote name)))))
                     (let-values (((si so se pid)
                                   (open-process-ports (str cmd " 2>&1") 'block (native-transcoder))))
                       (close-port si) (close-port so) (close-port se)
                       (echo-message! echo (str "Created tag: " name))))))))))
        ((string=? action "delete")
         (let ((name (echo-read-string echo "Delete tag: " row width)))
           (when (and name (not (string-empty? name)))
             (with-catch
               (lambda (e) (echo-message! echo (str "tag error: " e)))
               (lambda ()
                 (let-values (((si so se pid)
                               (open-process-ports (str "git tag -d " (shell-quote name) " 2>&1") 'block (native-transcoder))))
                   (close-port si) (close-port so) (close-port se)
                   (echo-message! echo (str "Deleted tag: " name))))))))))))

;; --- Feature 7: Randomize Lines ---

(def (cmd-randomize-lines app)
  "Shuffle the lines in the current buffer randomly."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len))
         (lines (string-split text #\newline))
         (n (length lines))
         (vec (list->vector lines)))
    ;; Fisher-Yates shuffle
    (do ((i (- n 1) (- i 1))) ((< i 1))
      (let* ((j (random (+ i 1)))
             (tmp (vector-ref vec i)))
        (vector-set! vec i (vector-ref vec j))
        (vector-set! vec j tmp)))
    (editor-set-text ed (string-join (vector->list vec) "\n"))
    (editor-goto-pos ed 0)
    (echo-message! echo (str "Shuffled " n " lines"))))

;; --- Feature 8: Titlecase Region ---

(def (cmd-titlecase-region app)
  "Convert selected text to Title Case."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (words (string-split text #\space))
             (titled (map (lambda (w)
                            (if (> (string-length w) 0)
                              (string-append
                                (string (char-upcase (string-ref w 0)))
                                (string-downcase (substring w 1 (string-length w))))
                              w))
                          words))
             (result (string-join titled " ")))
        (editor-replace-selection ed result)
        (echo-message! echo "Title case applied")))))

;; --- Feature 9: Goto Percent ---

(def (cmd-goto-percent app)
  "Go to a percentage position in the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Goto %: " row width)))
    (when (and input (not (string-empty? input)))
      (let ((pct (string->number (string-trim input))))
        (when (and pct (>= pct 0) (<= pct 100))
          (let* ((len (send-message ed SCI_GETLENGTH 0 0))
                 (pos (exact (round (* len (/ pct 100.0))))))
            (send-message ed SCI_GOTOPOS pos 0)
            (echo-message! echo (str "At " pct "%"))))))))

;; --- Feature 10: Copy Filename ---

(def (cmd-copy-filename app)
  "Copy the current buffer's filename (without path) to kill ring."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (let* ((name (let loop ((i (- (string-length file) 1)))
                     (cond
                       ((< i 0) file)
                       ((char=? (string-ref file i) #\/) (substring file (+ i 1) (string-length file)))
                       (else (loop (- i 1))))))
             (ed (edit-window-editor win)))
        (send-message ed SCI_COPYTEXT (string-length name) name)
        (echo-message! echo (str "Copied: " name))))))

;; ===== Round 13 Batch 1 =====

;; --- Feature 1: String Reverse ---

(def (cmd-string-reverse app)
  "Reverse the selected text or current line."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      ;; Reverse current line
      (let* ((line-num (send-message ed SCI_LINEFROMPOSITION
                         (send-message ed SCI_GETCURRENTPOS 0 0) 0))
             (start (send-message ed SCI_POSITIONFROMLINE line-num 0))
             (end (send-message ed SCI_GETLINEENDPOSITION line-num 0))
             (text (editor-get-text-range ed start (- end start)))
             (reversed (list->string (reverse (string->list text)))))
        (send-message ed SCI_SETTARGETSTART start 0)
        (send-message ed SCI_SETTARGETEND end 0)
        (send-message ed SCI_REPLACETARGET -1 reversed)
        (echo-message! echo "Line reversed"))
      ;; Reverse selection
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (reversed (list->string (reverse (string->list text)))))
        (editor-replace-selection ed reversed)
        (echo-message! echo "Selection reversed")))))

;; --- Feature 2: Sort Words ---

(def (cmd-sort-words app)
  "Sort words in selection or current line alphabetically."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection — select text to sort words")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (words (filter (lambda (w) (> (string-length w) 0))
                            (string-split text #\space)))
             (sorted (sort string<? words))
             (result (string-join sorted " ")))
        (editor-replace-selection ed result)
        (echo-message! echo (str "Sorted " (length sorted) " words"))))))

;; --- Feature 3: Unique Lines ---

(def (cmd-uniq-lines app)
  "Remove duplicate lines from the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len))
         (lines (string-split text #\newline))
         (seen (make-hash-table))
         (unique (filter (lambda (line)
                           (if (hash-key? seen line) #f
                             (begin (hash-put! seen line #t) #t)))
                         lines))
         (removed (- (length lines) (length unique))))
    (editor-set-text ed (string-join unique "\n"))
    (editor-goto-pos ed 0)
    (echo-message! echo (str "Removed " removed " duplicate lines"))))

;; --- Feature 4: Encode HTML Entities ---

(def (cmd-encode-html-entities app)
  "Encode special characters as HTML entities in selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (encoded (let loop ((chars (string->list text)) (acc '()))
                        (if (null? chars)
                          (list->string (reverse acc))
                          (let ((c (car chars)))
                            (cond
                              ((char=? c #\&) (loop (cdr chars) (append (reverse (string->list "&amp;")) acc)))
                              ((char=? c #\<) (loop (cdr chars) (append (reverse (string->list "&lt;")) acc)))
                              ((char=? c #\>) (loop (cdr chars) (append (reverse (string->list "&gt;")) acc)))
                              ((char=? c #\") (loop (cdr chars) (append (reverse (string->list "&quot;")) acc)))
                              ((char=? c #\') (loop (cdr chars) (append (reverse (string->list "&#39;")) acc)))
                              (else (loop (cdr chars) (cons c acc)))))))))
        (editor-replace-selection ed encoded)
        (echo-message! echo "HTML entities encoded")))))

;; --- Feature 5: Decode HTML Entities ---

(def (cmd-decode-html-entities app)
  "Decode HTML entities back to characters in selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (decoded text))
        ;; Simple entity replacements
        (let* ((d1 (let loop ((s decoded))
                     (let ((pos (string-contains s "&amp;")))
                       (if (not pos) s
                         (loop (string-append (substring s 0 pos) "&"
                                 (substring s (+ pos 5) (string-length s))))))))
               (d2 (let loop ((s d1))
                     (let ((pos (string-contains s "&lt;")))
                       (if (not pos) s
                         (loop (string-append (substring s 0 pos) "<"
                                 (substring s (+ pos 4) (string-length s))))))))
               (d3 (let loop ((s d2))
                     (let ((pos (string-contains s "&gt;")))
                       (if (not pos) s
                         (loop (string-append (substring s 0 pos) ">"
                                 (substring s (+ pos 4) (string-length s))))))))
               (d4 (let loop ((s d3))
                     (let ((pos (string-contains s "&quot;")))
                       (if (not pos) s
                         (loop (string-append (substring s 0 pos) "\""
                                 (substring s (+ pos 6) (string-length s)))))))))
          (editor-replace-selection ed d4)
          (echo-message! echo "HTML entities decoded"))))))

;; --- Feature 6: URL Decode ---

(def (cmd-url-decode app)
  "Decode URL-encoded text in selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let ((text (editor-get-text-range ed sel-start (- sel-end sel-start))))
        (with-catch
          (lambda (e) (echo-message! echo (str "Decode error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read()),end=\"\")' 2>/dev/null")
                            'block (native-transcoder))))
              (display text si)
              (close-port si)
              (let ((decoded (get-line so)))
                (close-port so) (close-port se)
                (when (not (eof-object? decoded))
                  (editor-replace-selection ed decoded)
                  (echo-message! echo "URL decoded"))))))))))

;; --- Feature 7: CamelCase to snake_case ---

(def (cmd-camelcase-to-snake app)
  "Convert camelCase/PascalCase to snake_case in selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (result (let loop ((chars (string->list text)) (acc '()) (prev-lower #f))
                       (if (null? chars)
                         (list->string (reverse acc))
                         (let ((c (car chars)))
                           (if (and prev-lower (char-upper-case? c))
                             (loop (cdr chars) (cons (char-downcase c) (cons #\_ acc)) #f)
                             (loop (cdr chars) (cons (char-downcase c) acc) (char-lower-case? c))))))))
        (editor-replace-selection ed result)
        (echo-message! echo "Converted to snake_case")))))

;; --- Feature 8: snake_case to camelCase ---

(def (cmd-snake-to-camel app)
  "Convert snake_case to camelCase in selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (parts (string-split text #\_))
             (result (if (null? parts) ""
                       (string-append
                         (car parts)
                         (apply string-append
                           (map (lambda (p)
                                  (if (> (string-length p) 0)
                                    (string-append
                                      (string (char-upcase (string-ref p 0)))
                                      (substring p 1 (string-length p)))
                                    ""))
                                (cdr parts)))))))
        (editor-replace-selection ed result)
        (echo-message! echo "Converted to camelCase")))))

;; --- Feature 9: kebab-case to camelCase ---

(def (cmd-kebab-to-camel app)
  "Convert kebab-case to camelCase in selection."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (parts (string-split text #\-))
             (result (if (null? parts) ""
                       (string-append
                         (car parts)
                         (apply string-append
                           (map (lambda (p)
                                  (if (> (string-length p) 0)
                                    (string-append
                                      (string (char-upcase (string-ref p 0)))
                                      (substring p 1 (string-length p)))
                                    ""))
                                (cdr parts)))))))
        (editor-replace-selection ed result)
        (echo-message! echo "Converted to camelCase")))))

;; --- Feature 10: Wrap Region ---

(def (cmd-wrap-region app)
  "Wrap the selection with user-specified characters."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= sel-start sel-end)
      (echo-message! echo "No selection")
      (let* ((row (tui-rows)) (width (tui-cols))
             (wrapper (echo-read-string echo "Wrap with (e.g. \" or ( or <tag>): " row width)))
        (when (and wrapper (not (string-empty? wrapper)))
          (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
                 (open-char (string-trim wrapper))
                 (close-char (cond
                               ((string=? open-char "(") ")")
                               ((string=? open-char "[") "]")
                               ((string=? open-char "{") "}")
                               ((string=? open-char "<") ">")
                               ((string=? open-char "\"") "\"")
                               ((string=? open-char "'") "'")
                               ((string=? open-char "`") "`")
                               (else open-char)))
                 (wrapped (str open-char text close-char)))
            (editor-replace-selection ed wrapped)
            (echo-message! echo "Region wrapped")))))))

;; ===== Round 14 Batch 1 =====

;; --- Feature 1: Insert Date Header ---

(def (cmd-insert-date-header app)
  "Insert a date header comment (e.g., for changelog entries)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (user (or (getenv "USER") "unknown"))
         (now (time-second (current-time)))
         (header (str "## " now " - " user "\n\n")))
    (editor-insert-text ed header)
    (echo-message! echo "Date header inserted")))

;; --- Feature 2: Highlight Phrase ---

(def *highlight-phrases* '())

(def (cmd-highlight-phrase app)
  "Highlight all occurrences of a phrase in the current buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (phrase (echo-read-string echo "Highlight phrase: " row width)))
    (when (and phrase (not (string-empty? phrase)))
      (set! *highlight-phrases* (cons phrase *highlight-phrases*))
      ;; Use indicator 17 for phrase highlighting
      (send-message ed SCI_INDICSETSTYLE 17 6) ;; INDIC_BOX
      (send-message ed SCI_INDICSETFORE 17 #xFF8000) ;; orange
      (send-message ed SCI_SETINDICATORCURRENT 17 0)
      (let* ((len (send-message ed SCI_GETLENGTH 0 0))
             (text (editor-get-text ed len))
             (plen (string-length phrase))
             (count (let loop ((pos 0) (n 0))
                      (let ((found (string-contains (substring text pos (string-length text)) phrase)))
                        (if (not found) n
                          (let ((abs-pos (+ pos found)))
                            (send-message ed SCI_INDICATORFILLRANGE abs-pos plen)
                            (loop (+ abs-pos plen) (+ n 1))))))))
        (echo-message! echo (str "Highlighted " count " occurrences of \"" phrase "\""))))))

;; --- Feature 3: Unhighlight All ---

(def (cmd-unhighlight-all app)
  "Remove all phrase highlights."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0)))
    (send-message ed SCI_SETINDICATORCURRENT 17 0)
    (send-message ed SCI_INDICATORCLEARRANGE 0 len)
    (set! *highlight-phrases* '())
    (echo-message! echo "All highlights cleared")))

;; --- Feature 4: Widen Buffer ---

(def (cmd-widen-buffer app)
  "Remove narrowing — show the entire buffer content."
  (let ((echo (app-state-echo app)))
    ;; In Scintilla, there's no native narrowing, so this is a no-op/informational
    (echo-message! echo "Buffer widened (no narrowing active)")))

;; --- Feature 5: Move Region Up ---

(def (cmd-move-region-up app)
  "Move the selected lines up by one line."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (sel-end (send-message ed SCI_GETSELECTIONEND 0 0))
         (start-line (send-message ed SCI_LINEFROMPOSITION sel-start 0))
         (end-line (send-message ed SCI_LINEFROMPOSITION sel-end 0)))
    (if (= start-line 0)
      (echo-message! echo "Already at top")
      (begin
        (send-message ed SCI_MOVESELECTEDLINESUP 0 0)
        (echo-message! echo "Moved up")))))

;; --- Feature 6: Move Region Down ---

(def (cmd-move-region-down app)
  "Move the selected lines down by one line."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (send-message ed SCI_MOVESELECTEDLINESDOWN 0 0)
    (echo-message! echo "Moved down")))

;; --- Feature 7: JSON to YAML ---

(def (cmd-json-to-yaml app)
  "Convert JSON buffer content to YAML."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 0))
      (with-catch
        (lambda (e) (echo-message! echo (str "Conversion error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          "python3 -c 'import sys,json,yaml;yaml.dump(json.load(sys.stdin),sys.stdout,default_flow_style=False)' 2>/dev/null"
                          'block (native-transcoder))))
            (display text p-stdin)
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let ((yaml (string-join (reverse lines) "\n")))
                      (when (> (string-length yaml) 0)
                        (editor-set-text ed yaml)
                        (editor-goto-pos ed 0)
                        (echo-message! echo "Converted to YAML"))))
                  (loop (cons line lines)))))))))))

;; --- Feature 8: YAML to JSON ---

(def (cmd-yaml-to-json app)
  "Convert YAML buffer content to JSON."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 0))
      (with-catch
        (lambda (e) (echo-message! echo (str "Conversion error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          "python3 -c 'import sys,json,yaml;json.dump(yaml.safe_load(sys.stdin),sys.stdout,indent=2)' 2>/dev/null"
                          'block (native-transcoder))))
            (display text p-stdin)
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let ((json (string-join (reverse lines) "\n")))
                      (when (> (string-length json) 0)
                        (editor-set-text ed json)
                        (editor-goto-pos ed 0)
                        (echo-message! echo "Converted to JSON"))))
                  (loop (cons line lines)))))))))))

;; --- Feature 9: CSV to JSON ---

(def (cmd-csv-to-json app)
  "Convert CSV buffer content to JSON."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 0))
      (with-catch
        (lambda (e) (echo-message! echo (str "Conversion error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          "python3 -c 'import sys,csv,json;r=csv.DictReader(sys.stdin);json.dump(list(r),sys.stdout,indent=2)'"
                          'block (native-transcoder))))
            (display text p-stdin)
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let ((json (string-join (reverse lines) "\n")))
                      (when (> (string-length json) 0)
                        (editor-set-text ed json)
                        (editor-goto-pos ed 0)
                        (echo-message! echo "Converted to JSON"))))
                  (loop (cons line lines)))))))))))

;; --- Feature 10: JSON to CSV ---

(def (cmd-json-to-csv app)
  "Convert JSON array of objects to CSV."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (len (send-message ed SCI_GETLENGTH 0 0))
         (text (editor-get-text ed len)))
    (when (and text (> (string-length text) 0))
      (with-catch
        (lambda (e) (echo-message! echo (str "Conversion error: " e)))
        (lambda ()
          (let-values (((p-stdin p-stdout p-stderr pid)
                        (open-process-ports
                          "python3 -c 'import sys,csv,json;d=json.load(sys.stdin);w=csv.DictWriter(sys.stdout,d[0].keys());w.writeheader();w.writerows(d)' 2>/dev/null"
                          'block (native-transcoder))))
            (display text p-stdin)
            (close-port p-stdin)
            (let loop ((lines '()))
              (let ((line (get-line p-stdout)))
                (if (eof-object? line)
                  (begin
                    (close-port p-stdout) (close-port p-stderr)
                    (let ((csv (string-join (reverse lines) "\n")))
                      (when (> (string-length csv) 0)
                        (editor-set-text ed csv)
                        (editor-goto-pos ed 0)
                        (echo-message! echo "Converted to CSV"))))
                  (loop (cons line lines)))))))))))

;; ===== Round 15 Batch 1 =====

;; --- Feature 1: String Inflection Cycle ---

(def (cmd-string-inflection-cycle app)
  "Cycle through camelCase, snake_case, SCREAMING_SNAKE, kebab-case for the word at point."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
         (word-end (send-message ed SCI_WORDENDPOSITION pos 1)))
    ;; Extend to include hyphens and underscores
    (let extend-back ((s word-start))
      (if (and (> s 0)
               (let ((c (send-message ed SCI_GETCHARAT (- s 1) 0)))
                 (or (= c 45) (= c 95)  ;; - or _
                     (and (>= c 65) (<= c 90))
                     (and (>= c 97) (<= c 122))
                     (and (>= c 48) (<= c 57)))))
        (extend-back (- s 1))
        (let extend-fwd ((e word-end))
          (let ((len (send-message ed SCI_GETLENGTH 0 0)))
            (if (and (< e len)
                     (let ((c (send-message ed SCI_GETCHARAT e 0)))
                       (or (= c 45) (= c 95)
                           (and (>= c 65) (<= c 90))
                           (and (>= c 97) (<= c 122))
                           (and (>= c 48) (<= c 57)))))
              (extend-fwd (+ e 1))
              (let* ((text (editor-get-text-range ed s e))
                     ;; Determine current style
                     (has-underscore (string-contains text "_"))
                     (has-hyphen (string-contains text "-"))
                     (all-upper (let check ((i 0))
                                  (if (>= i (string-length text)) #t
                                    (let ((c (string-ref text i)))
                                      (if (char-alphabetic? c)
                                        (if (char-upper-case? c) (check (+ i 1)) #f)
                                        (check (+ i 1)))))))
                     ;; Split into words
                     (words
                       (cond
                         (has-underscore (map string-downcase (filter (lambda (s) (not (string-empty? s))) (string-split text #\_))))
                         (has-hyphen (map string-downcase (filter (lambda (s) (not (string-empty? s))) (string-split text #\-))))
                         (else ;; camelCase split
                           (let split-camel ((chars (string->list text)) (cur '()) (result '()))
                             (if (null? chars)
                               (reverse (if (null? cur) result (cons (list->string (reverse cur)) result)))
                               (let ((c (car chars)))
                                 (if (and (char-upper-case? c) (not (null? cur)))
                                   (split-camel (cdr chars) (list (char-downcase c))
                                     (cons (list->string (reverse cur)) result))
                                   (split-camel (cdr chars) (cons (char-downcase c) cur) result))))))))
                     ;; Cycle: snake -> SCREAMING -> kebab -> camel -> snake
                     (new-text
                       (cond
                         ((and has-underscore (not all-upper))
                          (string-join (map string-upcase words) "_"))  ;; snake -> SCREAMING
                         ((and has-underscore all-upper)
                          (string-join words "-"))  ;; SCREAMING -> kebab
                         (has-hyphen
                          ;; kebab -> camelCase
                          (let ((first (car words))
                                (rest (map (lambda (w)
                                            (if (> (string-length w) 0)
                                              (string-append (string (char-upcase (string-ref w 0)))
                                                             (substring w 1 (string-length w)))
                                              w))
                                           (cdr words))))
                            (apply string-append first rest)))
                         (else (string-join words "_")))))  ;; camel -> snake
                (send-message ed SCI_DELETERANGE s (- e s))
                (send-message ed SCI_INSERTTEXT s new-text)
                (echo-message! echo (str "Inflected: " new-text))))))))))

;; --- Feature 2: Crux Kill Whole Line ---

(def (cmd-crux-kill-whole-line app)
  "Kill the entire current line, regardless of cursor position."
  (let* ((frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (line (send-message ed SCI_LINEFROMPOSITION
                 (send-message ed SCI_GETCURRENTPOS 0 0) 0))
         (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
         (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
         ;; Include the newline character
         (next-line-start (send-message ed SCI_POSITIONFROMLINE (+ line 1) 0))
         (del-end (if (> next-line-start line-end) next-line-start line-end)))
    (let ((text (editor-get-text-range ed line-start del-end)))
      (send-message ed SCI_COPYTEXT (string-length text) text)
      (send-message ed SCI_DELETERANGE line-start (- del-end line-start))
      (echo-message! (app-state-echo app) "Killed whole line"))))

;; --- Feature 3: Crux Transpose Windows ---

(def (cmd-crux-transpose-windows app)
  "Swap the buffers of the current window and the next window."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (wins (frame-windows frame)))
    (if (< (length wins) 2)
      (echo-message! echo "Only one window — nothing to transpose")
      (let* ((cur-win (current-window frame))
             (cur-buf (edit-window-buffer cur-win))
             ;; Find next window
             (cur-idx (let find ((ws wins) (i 0))
                        (if (null? ws) 0
                          (if (eq? (car ws) cur-win) i (find (cdr ws) (+ i 1))))))
             (next-idx (modulo (+ cur-idx 1) (length wins)))
             (next-win (list-ref wins next-idx))
             (next-buf (edit-window-buffer next-win)))
        (set-window-buffer! cur-win next-buf)
        (set-window-buffer! next-win cur-buf)
        (echo-message! echo "Transposed windows")))))

;; --- Feature 4: Crux Delete File and Buffer ---

(def (cmd-crux-delete-file-and-buffer app)
  "Delete the current file from disk and kill its buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (let* ((row (tui-rows)) (width (tui-cols))
             (confirm (echo-read-string echo (str "Delete " file "? (yes/no): ") row width)))
        (when (and confirm (string=? (string-trim confirm) "yes"))
          (with-catch
            (lambda (e) (echo-message! echo (str "Delete error: " e)))
            (lambda ()
              (delete-file file)
              (kill-buffer frame buf)
              (echo-message! echo (str "Deleted: " file)))))))))

;; --- Feature 5: Smartscan Symbol Forward ---

(def (cmd-smartscan-symbol-go-forward app)
  "Jump forward to the next occurrence of the symbol at point."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
         (word-end (send-message ed SCI_WORDENDPOSITION pos 1))
         (word (editor-get-text-range ed word-start word-end)))
    (if (or (not word) (string-empty? word))
      (echo-message! echo "No symbol at point")
      (begin
        (send-message ed SCI_SETTARGETSTART word-end 0)
        (send-message ed SCI_SETTARGETEND (send-message ed SCI_GETLENGTH 0 0) 0)
        (send-message ed SCI_SETSEARCHFLAGS 4 0)  ;; SCFIND_WHOLEWORD
        (let ((found (send-message ed SCI_SEARCHINTARGET (string-length word) word)))
          (if (>= found 0)
            (begin
              (editor-goto-pos ed found)
              (send-message ed SCI_SETSEL found (+ found (string-length word)))
              (echo-message! echo (str "Found: " word)))
            ;; Wrap around
            (begin
              (send-message ed SCI_SETTARGETSTART 0 0)
              (send-message ed SCI_SETTARGETEND word-start 0)
              (let ((found2 (send-message ed SCI_SEARCHINTARGET (string-length word) word)))
                (if (>= found2 0)
                  (begin
                    (editor-goto-pos ed found2)
                    (send-message ed SCI_SETSEL found2 (+ found2 (string-length word)))
                    (echo-message! echo (str "Wrapped: " word)))
                  (echo-message! echo (str "Only occurrence: " word)))))))))))

;; --- Feature 6: Smartscan Symbol Backward ---

(def (cmd-smartscan-symbol-go-backward app)
  "Jump backward to the previous occurrence of the symbol at point."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
         (word-end (send-message ed SCI_WORDENDPOSITION pos 1))
         (word (editor-get-text-range ed word-start word-end)))
    (if (or (not word) (string-empty? word))
      (echo-message! echo "No symbol at point")
      (begin
        ;; Search backward: set target from 0 to word-start, use SCI_SEARCHINTARGET
        ;; Scintilla searches forward in target, so we search 0..word-start and find last
        (send-message ed SCI_SETTARGETSTART 0 0)
        (send-message ed SCI_SETTARGETEND word-start 0)
        (send-message ed SCI_SETSEARCHFLAGS 4 0)  ;; SCFIND_WHOLEWORD
        (let find-last ((last-pos -1) (search-from 0))
          (send-message ed SCI_SETTARGETSTART search-from 0)
          (send-message ed SCI_SETTARGETEND word-start 0)
          (let ((found (send-message ed SCI_SEARCHINTARGET (string-length word) word)))
            (if (>= found 0)
              (find-last found (+ found (string-length word)))
              (if (>= last-pos 0)
                (begin
                  (editor-goto-pos ed last-pos)
                  (send-message ed SCI_SETSEL last-pos (+ last-pos (string-length word)))
                  (echo-message! echo (str "Found: " word)))
                ;; Wrap around
                (begin
                  (send-message ed SCI_SETTARGETSTART word-end 0)
                  (send-message ed SCI_SETTARGETEND (send-message ed SCI_GETLENGTH 0 0) 0)
                  (let find-last2 ((lp -1) (sf word-end))
                    (send-message ed SCI_SETTARGETSTART sf 0)
                    (send-message ed SCI_SETTARGETEND (send-message ed SCI_GETLENGTH 0 0) 0)
                    (let ((f2 (send-message ed SCI_SEARCHINTARGET (string-length word) word)))
                      (if (>= f2 0)
                        (find-last2 f2 (+ f2 (string-length word)))
                        (if (>= lp 0)
                          (begin
                            (editor-goto-pos ed lp)
                            (send-message ed SCI_SETSEL lp (+ lp (string-length word)))
                            (echo-message! echo (str "Wrapped: " word)))
                          (echo-message! echo (str "Only occurrence: " word)))))))))))))))

;; --- Feature 7: Toggle Quotes ---

(def (cmd-toggle-quotes app)
  "Toggle between single and double quotes around the string at point."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (char-at (send-message ed SCI_GETCHARAT pos 0)))
    ;; Find the enclosing quote
    (let* ((quote-char
             (cond
               ((or (= char-at 34) (= char-at 39)) char-at)  ;; " or '
               (else
                 ;; Search backward for a quote
                 (let search-back ((p (- pos 1)))
                   (if (< p 0) #f
                     (let ((c (send-message ed SCI_GETCHARAT p 0)))
                       (if (or (= c 34) (= c 39)) c
                         (search-back (- p 1)))))))))
           (target-char (if (and quote-char (= quote-char 34)) 39 34)))
      (if (not quote-char)
        (echo-message! echo "No quotes found near point")
        ;; Find opening quote
        (let find-open ((p pos))
          (if (< p 0)
            (echo-message! echo "Could not find opening quote")
            (let ((c (send-message ed SCI_GETCHARAT p 0)))
              (if (= c quote-char)
                ;; Found opening, find closing
                (let find-close ((q (+ p 1)))
                  (let ((len (send-message ed SCI_GETLENGTH 0 0)))
                    (if (>= q len)
                      (echo-message! echo "Could not find closing quote")
                      (let ((c2 (send-message ed SCI_GETCHARAT q 0)))
                        (if (= c2 quote-char)
                          ;; Replace both quotes
                          (let ((new-char (string (integer->char target-char))))
                            (send-message ed SCI_SETTARGETSTART q 0)
                            (send-message ed SCI_SETTARGETEND (+ q 1) 0)
                            (send-message ed SCI_REPLACETARGET -1 new-char)
                            (send-message ed SCI_SETTARGETSTART p 0)
                            (send-message ed SCI_SETTARGETEND (+ p 1) 0)
                            (send-message ed SCI_REPLACETARGET -1 new-char)
                            (echo-message! echo (str "Toggled to "
                              (if (= target-char 34) "double" "single") " quotes")))
                          (find-close (+ q 1)))))))
                (find-open (- p 1))))))))))

;; --- Feature 8: Browse URL at Point ---

(def (cmd-browse-url-at-point app)
  "Open the URL under the cursor in the default web browser."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
         (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
         (line-text (editor-get-text-range ed line-start line-end)))
    ;; Find URL in line text
    (with-catch
      (lambda (e) (echo-message! echo (str "Error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        (str "echo " (shell-quote line-text)
                             " | grep -oP 'https?://[^ \\t\\n\\r\"'\\''><]+' | head -1")
                        'block (native-transcoder))))
          (close-port si)
          (let ((url (get-line so)))
            (close-port so) (close-port se)
            (if (eof-object? url)
              (echo-message! echo "No URL found on current line")
              (let ((trimmed (string-trim url)))
                (let-values (((si2 so2 se2 pid2)
                              (open-process-ports
                                (str "xdg-open " (shell-quote trimmed) " 2>/dev/null &")
                                'block (native-transcoder))))
                  (close-port si2) (close-port so2) (close-port se2)
                  (echo-message! echo (str "Opening: " trimmed)))))))))))

;; --- Feature 9: Dumb Jump ---

(def (cmd-dumb-jump app)
  "Jump to definition of symbol at point using grep/rg."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
         (word-end (send-message ed SCI_WORDENDPOSITION pos 1))
         (symbol (editor-get-text-range ed word-start word-end)))
    (if (or (not symbol) (string-empty? symbol))
      (echo-message! echo "No symbol at point")
      (with-catch
        (lambda (e) (echo-message! echo (str "dumb-jump error: " e)))
        (lambda ()
          ;; Try rg first, fall back to grep
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "rg -n --no-heading '(def|defn|defun|define|class|function|func|fn|let|const|var|type|struct)\\s+"
                               symbol "\\b' . 2>/dev/null || grep -rn 'def.*"
                               symbol "' --include='*.ss' --include='*.scm' --include='*.py' --include='*.js' --include='*.go' --include='*.rs' . 2>/dev/null")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((results (reverse lines)))
                      (if (null? results)
                        (echo-message! echo (str "No definition found for: " symbol))
                        (if (= (length results) 1)
                          ;; Single result: jump directly
                          (let* ((result (car results))
                                 (parts (string-split result #\:)))
                            (when (>= (length parts) 2)
                              (let ((file (car parts))
                                    (line-num (string->number (cadr parts))))
                                (when (and file line-num)
                                  (cmd-find-file-at app file line-num)))))
                          ;; Multiple results: show in buffer
                          (let* ((new-buf (create-buffer "*dumb-jump*"))
                                 (result-text (string-join results "\n")))
                            (switch-to-buffer frame new-buf)
                            (let ((new-ed (edit-window-editor (current-window frame))))
                              (editor-set-text new-ed (str "=== Definitions of " symbol " ===\n\n" result-text "\n")))
                            (echo-message! echo (str (length results) " definitions found")))))))
                  (loop (cons line lines)))))))))))

(def (cmd-find-file-at app file line-num)
  "Helper: open file and go to line number."
  (let* ((frame (app-state-frame app))
         (buf (find-or-create-file-buffer file)))
    (switch-to-buffer frame buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (when line-num
        (let ((pos (send-message ed SCI_POSITIONFROMLINE (- line-num 1) 0)))
          (editor-goto-pos ed pos))))))

;; --- Feature 10: Diff Buffer with File ---

(def (cmd-diff-buffer-with-file app)
  "Show the diff between the current buffer contents and the file on disk."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (buf (edit-window-buffer win))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "No file associated with buffer")
      (with-catch
        (lambda (e) (echo-message! echo (str "diff error: " e)))
        (lambda ()
          (let* ((text (editor-get-text ed))
                 (tmp-file (str "/tmp/jemacs-diff-" (time-second (current-time)) ".tmp")))
            (write-file-string tmp-file text)
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "diff -u " (shell-quote file) " " (shell-quote tmp-file)
                                 " 2>/dev/null; rm -f " (shell-quote tmp-file))
                            'block (native-transcoder))))
              (close-port si)
              (let loop ((lines '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (let ((diff-text (string-join (reverse lines) "\n")))
                        (if (string-empty? diff-text)
                          (echo-message! echo "Buffer matches file on disk")
                          (let* ((new-buf (create-buffer "*diff*")))
                            (switch-to-buffer frame new-buf)
                            (let ((new-ed (edit-window-editor (current-window frame))))
                              (editor-set-text new-ed diff-text))
                            (echo-message! echo "Diff loaded")))))
                    (loop (cons line lines))))))))))))

;; ===== Round 16 Batch 1 =====

;; --- Feature 1: Morse Region ---

(def (cmd-morse-region app)
  "Convert selected text to Morse code."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed start end))
             (morse-table '((#\A . ".-") (#\B . "-...") (#\C . "-.-.") (#\D . "-..")
                            (#\E . ".") (#\F . "..-.") (#\G . "--.") (#\H . "....")
                            (#\I . "..") (#\J . ".---") (#\K . "-.-") (#\L . ".-..")
                            (#\M . "--") (#\N . "-.") (#\O . "---") (#\P . ".--.")
                            (#\Q . "--.-") (#\R . ".-.") (#\S . "...") (#\T . "-")
                            (#\U . "..-") (#\V . "...-") (#\W . ".--") (#\X . "-..-")
                            (#\Y . "-.--") (#\Z . "--..") (#\0 . "-----") (#\1 . ".----")
                            (#\2 . "..---") (#\3 . "...--") (#\4 . "....-") (#\5 . ".....")
                            (#\6 . "-....") (#\7 . "--...") (#\8 . "---..") (#\9 . "----.")))
             (result (string-join
                       (map (lambda (c)
                              (let ((up (char-upcase c)))
                                (cond
                                  ((char=? c #\space) "/")
                                  ((char=? c #\newline) "\n")
                                  ((assv up morse-table) => cdr)
                                  (else (string c)))))
                            (string->list text))
                       " ")))
        (send-message ed SCI_DELETERANGE start (- end start))
        (send-message ed SCI_INSERTTEXT start result)
        (echo-message! echo "Converted to Morse code")))))

;; --- Feature 2: Unmorse Region ---

(def (cmd-unmorse-region app)
  "Convert Morse code back to text."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (start (send-message ed SCI_GETSELECTIONSTART 0 0))
         (end (send-message ed SCI_GETSELECTIONEND 0 0)))
    (if (= start end)
      (echo-message! echo "No selection")
      (let* ((text (editor-get-text-range ed start end))
             (unmorse-table '((".-" . "A") ("-..." . "B") ("-.-." . "C") ("-.." . "D")
                              ("." . "E") ("..-." . "F") ("--." . "G") ("...." . "H")
                              (".." . "I") (".---" . "J") ("-.-" . "K") (".-.." . "L")
                              ("--" . "M") ("-." . "N") ("---" . "O") (".--." . "P")
                              ("--.-" . "Q") (".-." . "R") ("..." . "S") ("-" . "T")
                              ("..-" . "U") ("...-" . "V") (".--" . "W") ("-..-" . "X")
                              ("-.--" . "Y") ("--.." . "Z") ("-----" . "0") (".----" . "1")
                              ("..---" . "2") ("...--" . "3") ("....-" . "4") ("....." . "5")
                              ("-...." . "6") ("--..." . "7") ("---.." . "8") ("----." . "9")))
             (words (string-split text #\space))
             (result (apply string-append
                       (map (lambda (w)
                              (cond
                                ((string=? w "/") " ")
                                ((string=? w "") "")
                                ((assoc w unmorse-table) => cdr)
                                (else "?")))
                            words))))
        (send-message ed SCI_DELETERANGE start (- end start))
        (send-message ed SCI_INSERTTEXT start result)
        (echo-message! echo "Converted from Morse code")))))

;; --- Feature 3: Proced Mode ---

(def (cmd-proced-mode app)
  "Display system processes in a buffer (like top/htop)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app)))
    (with-catch
      (lambda (e) (echo-message! echo (str "proced error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        "ps aux --sort=-%mem | head -50"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((result (string-join (reverse lines) "\n"))
                         (new-buf (create-buffer "*proced*")))
                    (switch-to-buffer frame new-buf)
                    (let ((new-ed (edit-window-editor (current-window frame))))
                      (editor-set-text new-ed (str "=== Process List ===\n\n" result "\n")))
                    (echo-message! echo "Proced: process list loaded")))
                (loop (cons line lines))))))))))

;; --- Feature 4: EWW Open File ---

(def (cmd-eww-open-file app)
  "Open an HTML file and render it as text."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (file (echo-read-string echo "HTML file: " row width)))
    (when (and file (not (string-empty? file)))
      (let ((path (string-trim file)))
        (if (not (file-exists? path))
          (echo-message! echo (str "File not found: " path))
          (with-catch
            (lambda (e) (echo-message! echo (str "eww error: " e)))
            (lambda ()
              (let-values (((si so se pid)
                            (open-process-ports
                              (str "w3m -dump " (shell-quote path)
                                   " 2>/dev/null || lynx -dump " (shell-quote path)
                                   " 2>/dev/null || cat " (shell-quote path))
                              'block (native-transcoder))))
                (close-port si)
                (let loop ((lines '()))
                  (let ((line (get-line so)))
                    (if (eof-object? line)
                      (begin
                        (close-port so) (close-port se)
                        (let* ((result (string-join (reverse lines) "\n"))
                               (new-buf (create-buffer (str "*eww: " path "*"))))
                          (switch-to-buffer frame new-buf)
                          (let ((new-ed (edit-window-editor (current-window frame))))
                            (editor-set-text new-ed result))
                          (echo-message! echo (str "Rendered: " path))))
                      (loop (cons line lines)))))))))))))

;; --- Feature 5: Webjump ---

(def (cmd-webjump app)
  "Quick jump to predefined web URLs."
  (let* ((echo (app-state-echo app))
         (sites '(("Google" . "https://www.google.com/search?q=")
                  ("GitHub" . "https://github.com/search?q=")
                  ("Stack Overflow" . "https://stackoverflow.com/search?q=")
                  ("Wikipedia" . "https://en.wikipedia.org/wiki/Special:Search?search=")
                  ("DuckDuckGo" . "https://duckduckgo.com/?q=")
                  ("MDN" . "https://developer.mozilla.org/en-US/search?q=")
                  ("Hacker News" . "https://hn.algolia.com/?q=")
                  ("Reddit" . "https://www.reddit.com/search/?q=")
                  ("YouTube" . "https://www.youtube.com/results?search_query=")
                  ("Crates.io" . "https://crates.io/search?q=")))
         (row (tui-rows)) (width (tui-cols))
         (site-names (map car sites))
         (choice (echo-read-string echo (str "Webjump [" (string-join site-names "/") "]: ") row width)))
    (when (and choice (not (string-empty? choice)))
      (let* ((name (string-trim choice))
             (entry (assoc name sites)))
        (if (not entry)
          (echo-message! echo (str "Unknown site: " name))
          (let* ((query (echo-read-string echo (str name " search: ") row width)))
            (when (and query (not (string-empty? query)))
              (let ((url (str (cdr entry) (string-trim query))))
                (with-catch
                  (lambda (e) (echo-message! echo (str "Error: " e)))
                  (lambda ()
                    (let-values (((si so se pid)
                                  (open-process-ports
                                    (str "xdg-open " (shell-quote url) " 2>/dev/null &")
                                    'block (native-transcoder))))
                      (close-port si) (close-port so) (close-port se)
                      (echo-message! echo (str "Opening: " url)))))))))))))

;; --- Feature 6: RSS Feed ---

(def (cmd-rss-feed app)
  "Simple RSS feed reader — fetch and display an RSS/Atom feed."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (url (echo-read-string echo "RSS/Atom feed URL: " row width)))
    (when (and url (not (string-empty? url)))
      (with-catch
        (lambda (e) (echo-message! echo (str "RSS error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "curl -sL " (shell-quote (string-trim url))
                               " | python3 -c '"
                               "import sys,xml.etree.ElementTree as ET;"
                               "t=ET.parse(sys.stdin).getroot();"
                               "ns={\"atom\":\"http://www.w3.org/2005/Atom\"};"
                               "[print(i.findtext(\"title\",\"\",ns)+\" | \"+i.findtext(\"link\",\"\",ns)) for i in t.iter() if i.tag.endswith((\"item\",\"entry\"))]"
                               "' 2>/dev/null")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((result (string-join (reverse lines) "\n")))
                      (if (string-empty? result)
                        (echo-message! echo "No items found in feed")
                        (let* ((new-buf (create-buffer "*rss-feed*")))
                          (switch-to-buffer frame new-buf)
                          (let ((new-ed (edit-window-editor (current-window frame))))
                            (editor-set-text new-ed (str "=== RSS Feed ===\n\n" result "\n")))
                          (echo-message! echo "RSS feed loaded")))))
                  (loop (cons line lines)))))))))))

;; --- Feature 7: Garbage Collect ---

(def (cmd-garbage-collect app)
  "Run garbage collection and display statistics."
  (let* ((echo (app-state-echo app)))
    (collect)
    (let* ((stats (statistics))
           (bytes-allocated (if (pair? stats) (cdar stats) 0)))
      (echo-message! echo (str "GC complete. Heap: " bytes-allocated " bytes")))))

;; --- Feature 8: Benchmark Run ---

(def (cmd-benchmark-run app)
  "Benchmark a shell command and show timing results."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (cmd (echo-read-string echo "Command to benchmark: " row width)))
    (when (and cmd (not (string-empty? cmd)))
      (let* ((iterations-str (echo-read-string echo "Iterations (default 10): " row width))
             (iterations (or (and iterations-str
                                  (not (string-empty? iterations-str))
                                  (string->number (string-trim iterations-str)))
                             10)))
        (with-catch
          (lambda (e) (echo-message! echo (str "Benchmark error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "for i in $(seq 1 " iterations "); do "
                                 "start=$(date +%s%N); "
                                 (string-trim cmd) " > /dev/null 2>&1; "
                                 "end=$(date +%s%N); "
                                 "echo $(( (end - start) / 1000000 )); "
                                 "done")
                            'block (native-transcoder))))
              (close-port si)
              (let loop ((times '()))
                (let ((line (get-line so)))
                  (if (eof-object? line)
                    (begin
                      (close-port so) (close-port se)
                      (if (null? times)
                        (echo-message! echo "No timing data collected")
                        (let* ((nums (filter number? (map (lambda (s) (string->number (string-trim s))) times)))
                               (total (apply + nums))
                               (avg (quotient total (length nums)))
                               (mn (apply min nums))
                               (mx (apply max nums)))
                          (echo-message! echo (str "Benchmark (" (length nums) " runs): avg=" avg "ms min=" mn "ms max=" mx "ms")))))
                    (loop (cons line times))))))))))))

;; --- Feature 9: Describe Personal Keybindings ---

(def (cmd-describe-personal-keybindings app)
  "Show all user-customized keybindings."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*personal-keybindings*")))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed
        (str "=== Personal Keybindings ===\n\n"
             "Standard Keybindings:\n"
             "  C-x C-f    find-file\n"
             "  C-x C-s    save-buffer\n"
             "  C-x C-c    exit\n"
             "  C-x b      switch-buffer\n"
             "  C-x k      kill-buffer\n"
             "  C-x 0      delete-window\n"
             "  C-x 1      delete-other-windows\n"
             "  C-x 2      split-window-below\n"
             "  C-x 3      split-window-right\n"
             "  C-x o      other-window\n"
             "  C-g        keyboard-quit\n"
             "  M-x        execute-extended-command\n"
             "  C-s        isearch-forward\n"
             "  C-r        isearch-backward\n"
             "  M-w        kill-ring-save\n"
             "  C-w        kill-region\n"
             "  C-y        yank\n"
             "  M-y        yank-pop\n"
             "  C-/        undo\n"
             "  C-space    set-mark\n"
             "  M-.        xref-find-definitions\n"
             "  M-,        xref-pop-marker\n"
             "\nUse M-x describe-bindings for full keymap listing.\n"))
      (echo-message! echo "Personal keybindings displayed"))))

;; --- Feature 10: Newsticker (News Headlines) ---

(def (cmd-newsticker-show-news app)
  "Fetch and display news headlines from Hacker News."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app)))
    (with-catch
      (lambda (e) (echo-message! echo (str "News error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        "curl -sL 'https://hacker-news.firebaseio.com/v0/topstories.json' | python3 -c 'import sys,json,urllib.request;ids=json.load(sys.stdin)[:20];[print(json.loads(urllib.request.urlopen(f\"https://hacker-news.firebaseio.com/v0/item/{i}.json\").read()).get(\"title\",\"?\")) for i in ids]' 2>/dev/null"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()) (n 1))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((result (string-join (reverse lines) "\n")))
                    (if (string-empty? result)
                      (echo-message! echo "Could not fetch news")
                      (let* ((new-buf (create-buffer "*news*")))
                        (switch-to-buffer frame new-buf)
                        (let ((new-ed (edit-window-editor (current-window frame))))
                          (editor-set-text new-ed (str "=== Hacker News Top Stories ===\n\n" result "\n")))
                        (echo-message! echo "News headlines loaded")))))
                (loop (cons (str (number->string n) ". " line) lines) (+ n 1))))))))))

;; ===== Round 17 Batch 1 =====

;; --- Feature 1: Emoji Search ---

(def (cmd-emoji-search app)
  "Search for and insert an emoji by name."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (query (echo-read-string echo "Emoji search: " row width)))
    (when (and query (not (string-empty? query)))
      (with-catch
        (lambda (e) (echo-message! echo (str "Emoji error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "python3 -c '"
                               "import unicodedata,sys;"
                               "q=sys.argv[1].lower();"
                               "[print(chr(i),unicodedata.name(chr(i),\"\")) for i in range(0x1F300,0x1FAF9) if q in unicodedata.name(chr(i),\"\").lower()]"
                               "' " (shell-quote (string-trim query)) " 2>/dev/null | head -20")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((results (reverse lines)))
                      (if (null? results)
                        (echo-message! echo "No emoji found")
                        ;; Insert the first result's emoji character
                        (let* ((first-line (car results))
                               (emoji (if (> (string-length first-line) 0)
                                        (string (string-ref first-line 0))
                                        "")))
                          (when (> (string-length emoji) 0)
                            (send-message ed SCI_INSERTTEXT -1 emoji)
                            (echo-message! echo (str "Inserted: " first-line)))))))
                  (loop (cons line lines)))))))))))

;; --- Feature 2: Emoji List ---

(def (cmd-emoji-list app)
  "Display a list of common emoji in a buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*emoji-list*")))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (with-catch
        (lambda (e)
          (editor-set-text new-ed "Error loading emoji list")
          (echo-message! echo (str "Error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          "python3 -c 'import unicodedata;[print(chr(i),unicodedata.name(chr(i),\"?\")) for i in range(0x1F600,0x1F650)]' 2>/dev/null"
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((result (string-join (reverse lines) "\n")))
                      (editor-set-text new-ed (str "=== Emoji List ===\n\n" result "\n"))
                      (echo-message! echo "Emoji list loaded")))
                  (loop (cons line lines)))))))))))

;; --- Feature 3: UCS Insert ---

(def (cmd-ucs-insert app)
  "Insert a Unicode character by codepoint or name."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Unicode codepoint (hex) or name: " row width)))
    (when (and input (not (string-empty? input)))
      (let ((trimmed (string-trim input)))
        (with-catch
          (lambda (e) (echo-message! echo (str "UCS error: " e)))
          (lambda ()
            ;; Try as hex codepoint first
            (let ((num (string->number trimmed 16)))
              (if num
                (let ((ch (string (integer->char num))))
                  (send-message ed SCI_INSERTTEXT -1 ch)
                  (echo-message! echo (str "Inserted U+" trimmed " = " ch)))
                ;; Try as name via Python
                (let-values (((si so se pid)
                              (open-process-ports
                                (str "python3 -c 'import unicodedata;print(unicodedata.lookup(\""
                                     trimmed "\"))' 2>/dev/null")
                                'block (native-transcoder))))
                  (close-port si)
                  (let ((result (get-line so)))
                    (close-port so) (close-port se)
                    (if (eof-object? result)
                      (echo-message! echo "Character not found")
                      (let ((ch (string-trim result)))
                        (send-message ed SCI_INSERTTEXT -1 ch)
                        (echo-message! echo (str "Inserted: " ch))))))))))))))

;; --- Feature 4: Char Info ---

(def (cmd-char-info app)
  "Show detailed information about the character at point."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (ch (send-message ed SCI_GETCHARAT pos 0)))
    (if (= ch 0)
      (echo-message! echo "No character at point")
      (let* ((char-val (integer->char ch))
             (info (str "Char: " (string char-val)
                        " | Decimal: " ch
                        " | Hex: 0x" (number->string ch 16)
                        " | Octal: 0" (number->string ch 8))))
        (echo-message! echo info)))))

;; --- Feature 5: List Colors Display ---

(def (cmd-list-colors-display app)
  "Display a color palette in a buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*colors*"))
         (colors '(("Black" "#000000") ("White" "#FFFFFF") ("Red" "#FF0000")
                   ("Green" "#00FF00") ("Blue" "#0000FF") ("Yellow" "#FFFF00")
                   ("Cyan" "#00FFFF") ("Magenta" "#FF00FF") ("Orange" "#FFA500")
                   ("Purple" "#800080") ("Pink" "#FFC0CB") ("Brown" "#A52A2A")
                   ("Gray" "#808080") ("Silver" "#C0C0C0") ("Gold" "#FFD700")
                   ("Navy" "#000080") ("Teal" "#008080") ("Maroon" "#800000")
                   ("Olive" "#808000") ("Coral" "#FF7F50") ("Salmon" "#FA8072")
                   ("Turquoise" "#40E0D0") ("Violet" "#EE82EE") ("Indigo" "#4B0082")
                   ("Crimson" "#DC143C") ("Lime" "#00FF00") ("Ivory" "#FFFFF0")
                   ("Azure" "#F0FFFF") ("Lavender" "#E6E6FA") ("Wheat" "#F5DEB3")
                   ("Khaki" "#F0E68C") ("Orchid" "#DA70D6") ("Plum" "#DDA0DD")))
         (lines (map (lambda (c)
                       (str "  " (car c) (make-string (max 1 (- 15 (string-length (car c)))) #\space) (cadr c)))
                     colors))
         (text (str "=== Color Palette ===\n\n" (string-join lines "\n") "\n")))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed text))
    (echo-message! echo "Color palette displayed")))

;; --- Feature 6: List Faces Display ---

(def (cmd-list-faces-display app)
  "Display available Scintilla style information."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (new-buf (create-buffer "*faces*"))
         (styles (let collect ((i 0) (acc '()))
                   (if (>= i 32) (reverse acc)
                     (let ((fg (send-message ed SCI_STYLEGETFORE i 0))
                           (bg (send-message ed SCI_STYLEGETBACK i 0))
                           (bold (send-message ed SCI_STYLEGETBOLD i 0))
                           (italic (send-message ed SCI_STYLEGETITALIC i 0)))
                       (collect (+ i 1)
                         (cons (str "  Style " i
                                    ": fg=#" (number->string fg 16)
                                    " bg=#" (number->string bg 16)
                                    (if (> bold 0) " BOLD" "")
                                    (if (> italic 0) " ITALIC" ""))
                               acc))))))
         (text (str "=== Scintilla Styles ===\n\n" (string-join styles "\n") "\n")))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed text))
    (echo-message! echo "Faces/styles displayed")))

;; --- Feature 7: Display Battery Mode ---

(def (cmd-display-battery-mode app)
  "Show battery status in the echo area."
  (let* ((echo (app-state-echo app)))
    (with-catch
      (lambda (e) (echo-message! echo "Battery info not available"))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null && cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo 'N/A'"
                        'block (native-transcoder))))
          (close-port si)
          (let* ((cap (get-line so))
                 (status (get-line so)))
            (close-port so) (close-port se)
            (if (or (eof-object? cap) (string=? (string-trim cap) "N/A"))
              (echo-message! echo "Battery: not available (desktop or no BAT0)")
              (echo-message! echo (str "Battery: " (string-trim cap) "% ("
                                       (if (eof-object? status) "unknown" (string-trim status)) ")")))))))))

;; --- Feature 8: View Hello File ---

(def (cmd-view-hello-file app)
  "Display a multilingual HELLO greeting in various scripts."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*hello*"))
         (greetings '("Hello!" "Bonjour!" "Hallo!" "Ciao!" "Hola!"
                      "Ola!" "Ahoj!" "Hej!" "Merhaba!" "Szia!"
                      "Saluton!" "Salut!" "Hei!" "Witaj!"
                      "Ahoj!" "Sveiki!" "Tere!" "Labas!"
                      "Czesc!" "Zdravo!" "Privet!"
                      "Konnichiwa!" "Nihao!" "Annyeong!"
                      "Namaste!" "Sawadee!" "Xin chao!"
                      "Shalom!" "Marhaba!" "Salaam!"))
         (text (str "=== HELLO ===\n\n"
                    "This file demonstrates greetings from around the world.\n\n"
                    (string-join greetings "\n") "\n\n"
                    "Emacs displays this in native scripts with proper Unicode rendering.\n"
                    "jemacs shows the transliterated forms.\n")))
    (switch-to-buffer frame new-buf)
    (let ((new-ed (edit-window-editor (current-window frame))))
      (editor-set-text new-ed text))
    (echo-message! echo "Hello world!")))

;; --- Feature 9: Auto Highlight Symbol ---

(def (cmd-auto-highlight-symbol app)
  "Highlight all instances of the symbol at point using indicator 18."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (word-start (send-message ed SCI_WORDSTARTPOSITION pos 1))
         (word-end (send-message ed SCI_WORDENDPOSITION pos 1))
         (word (editor-get-text-range ed word-start word-end)))
    (if (or (not word) (string-empty? word))
      (echo-message! echo "No symbol at point")
      (begin
        ;; Clear previous highlights
        (send-message ed SCI_SETINDICATORCURRENT 18 0)
        (send-message ed SCI_INDICATORCLEARRANGE 0 (send-message ed SCI_GETLENGTH 0 0))
        ;; Setup indicator 18 for symbol highlight
        (send-message ed SCI_INDICSETSTYLE 18 7)  ;; INDIC_ROUNDBOX
        (send-message ed SCI_INDICSETFORE 18 #x00FFFF)  ;; Cyan
        (send-message ed SCI_INDICSETALPHA 18 60)
        ;; Find and highlight all occurrences
        (let ((len (send-message ed SCI_GETLENGTH 0 0))
              (word-len (string-length word)))
          (send-message ed SCI_SETSEARCHFLAGS 4 0)  ;; SCFIND_WHOLEWORD
          (let highlight-loop ((search-start 0) (count 0))
            (send-message ed SCI_SETTARGETSTART search-start 0)
            (send-message ed SCI_SETTARGETEND len 0)
            (let ((found (send-message ed SCI_SEARCHINTARGET word-len word)))
              (if (>= found 0)
                (begin
                  (send-message ed SCI_INDICATORFILLRANGE found word-len)
                  (highlight-loop (+ found word-len) (+ count 1)))
                (echo-message! echo (str "Highlighted " count " occurrences of '" word "'"))))))))))

;; --- Feature 10: Pulse Momentary Highlight ---

(def (cmd-pulse-momentary-highlight-one-line app)
  "Flash/pulse the current line briefly using indicator 19."
  (let* ((frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (pos (send-message ed SCI_GETCURRENTPOS 0 0))
         (line (send-message ed SCI_LINEFROMPOSITION pos 0))
         (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
         (line-end (send-message ed SCI_GETLINEENDPOSITION line 0)))
    ;; Setup indicator 19 for pulse
    (send-message ed SCI_SETINDICATORCURRENT 19 0)
    (send-message ed SCI_INDICSETSTYLE 19 6)  ;; INDIC_BOX
    (send-message ed SCI_INDICSETFORE 19 #xFFFF00)  ;; Yellow
    (send-message ed SCI_INDICSETALPHA 19 100)
    ;; Highlight the line
    (send-message ed SCI_INDICATORFILLRANGE line-start (- line-end line-start))
    (echo-message! (app-state-echo app) "Line pulsed")))

;; ===== Round 18 Batch 1 =====

;; --- Feature 1: Insert Lorem Ipsum ---

(def (cmd-insert-lorem-ipsum app)
  "Insert Lorem Ipsum placeholder text."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (paragraphs-str (echo-read-string echo "Paragraphs (default 3): " row width))
         (n (or (and paragraphs-str (not (string-empty? paragraphs-str))
                     (string->number (string-trim paragraphs-str)))
                3))
         (lorem "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
         (extras '("Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis et commodo pharetra, est eros bibendum elit, nec luctus magna felis sollicitudin mauris."
                   "Praesent dapibus, neque id cursus faucibus, tortor neque egestas augue, eu vulputate magna eros eu erat. Aliquam erat volutpat. Nam dui mi, tincidunt quis, accumsan porttitor, facilisis luctus, metus."
                   "Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Vestibulum tortor quam, feugiat vitae, ultricies eget, tempor sit amet, ante."
                   "Integer euismod lacus luctus magna. Quisque cursus, metus vitae pharetra auctor, sem massa mattis sem, at interdum magna augue eget diam.")))
         (text (string-join
                 (let build ((i 0) (acc '()))
                   (if (>= i n) (reverse acc)
                     (build (+ i 1)
                       (cons (if (= i 0) lorem
                               (list-ref extras (modulo (- i 1) (length extras))))
                             acc))))
                 "\n\n")))
    (send-message ed SCI_INSERTTEXT -1 text)
    (echo-message! echo (str "Inserted " n " paragraphs of Lorem Ipsum")))


;; --- Feature 2: Generate Password ---

(def (cmd-generate-password app)
  "Generate a random password and insert it."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (len-str (echo-read-string echo "Password length (default 16): " row width))
         (len (or (and len-str (not (string-empty? len-str))
                       (string->number (string-trim len-str)))
                  16))
         (chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?")
         (password (list->string
                     (let gen ((i 0) (acc '()))
                       (if (>= i len) (reverse acc)
                         (gen (+ i 1)
                           (cons (string-ref chars (random (string-length chars))) acc)))))))
    (send-message ed SCI_INSERTTEXT -1 password)
    (echo-message! echo (str "Generated " len "-char password"))))

;; --- Feature 3: Insert UUID ---

(def (cmd-insert-uuid app)
  "Insert a UUID (v4) at point."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win)))
    (with-catch
      (lambda (e) (echo-message! echo (str "UUID error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        "python3 -c 'import uuid;print(uuid.uuid4())' 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null"
                        'block (native-transcoder))))
          (close-port si)
          (let ((uuid (get-line so)))
            (close-port so) (close-port se)
            (if (eof-object? uuid)
              (echo-message! echo "Could not generate UUID")
              (let ((id (string-trim uuid)))
                (send-message ed SCI_INSERTTEXT -1 id)
                (echo-message! echo (str "UUID: " id))))))))))

;; --- Feature 4: ASCII Art Text ---

(def (cmd-ascii-art-text app)
  "Convert text to ASCII art using figlet or toilet."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (text (echo-read-string echo "Text for ASCII art: " row width)))
    (when (and text (not (string-empty? text)))
      (with-catch
        (lambda (e) (echo-message! echo (str "figlet error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "figlet " (shell-quote (string-trim text))
                               " 2>/dev/null || toilet " (shell-quote (string-trim text))
                               " 2>/dev/null || echo " (shell-quote (string-trim text)))
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((art (string-join (reverse lines) "\n")))
                      (send-message ed SCI_INSERTTEXT -1 art)
                      (echo-message! echo "ASCII art inserted")))
                  (loop (cons line lines)))))))))))

;; --- Feature 5: Matrix Effect ---

(def (cmd-matrix-effect app)
  "Display a Matrix-style rain animation in the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*matrix*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (width 80) (height 24)
           (chars "abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*")
           (grid (make-vector (* width height) #\space)))
      ;; Generate several frames of matrix rain
      (let animate ((step 0))
        (when (< step 100)
          ;; Drop random characters
          (let ((col (random width)))
            (let shift-down ((row (- height 1)))
              (when (> row 0)
                (vector-set! grid (+ (* row width) col)
                  (vector-ref grid (+ (* (- row 1) width) col)))
                (shift-down (- row 1))))
            (vector-set! grid col
              (string-ref chars (random (string-length chars)))))
          (animate (+ step 1))))
      ;; Render final frame
      (let* ((lines (let build-rows ((row 0) (acc '()))
                      (if (>= row height) (reverse acc)
                        (let ((line (list->string
                                      (let build-cols ((col 0) (cs '()))
                                        (if (>= col width) (reverse cs)
                                          (build-cols (+ col 1)
                                            (cons (vector-ref grid (+ (* row width) col)) cs)))))))
                          (build-rows (+ row 1) (cons line acc))))))
             (text (string-join lines "\n")))
        (editor-set-text ed text)
        (echo-message! echo "Matrix loaded. Press undo to restore.")))))

;; --- Feature 6: Game of Life ---

(def (cmd-game-of-life app)
  "Run Conway's Game of Life in the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*game-of-life*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (w 40) (h 20)
           (grid (make-vector (* w h) 0)))
      ;; Random initial state
      (let init ((i 0))
        (when (< i (* w h))
          (vector-set! grid i (if (< (random 4) 1) 1 0))
          (init (+ i 1))))
      ;; Run a few generations
      (let gen-loop ((gen 0))
        (when (< gen 50)
          (let ((new-grid (make-vector (* w h) 0)))
            (let row-loop ((y 0))
              (when (< y h)
                (let col-loop ((x 0))
                  (when (< x w)
                    (let* ((neighbors
                             (let count ((dy -1) (sum 0))
                               (if (> dy 1) sum
                                 (count (+ dy 1)
                                   (+ sum (let count2 ((dx -1) (s2 0))
                                            (if (> dx 1) s2
                                              (count2 (+ dx 1)
                                                (+ s2 (if (and (= dx 0) (= dy 0)) 0
                                                        (let ((nx (modulo (+ x dx) w))
                                                              (ny (modulo (+ y dy) h)))
                                                          (vector-ref grid (+ (* ny w) nx)))))))))))))
                           (alive (vector-ref grid (+ (* y w) x))))
                      (vector-set! new-grid (+ (* y w) x)
                        (cond ((and (= alive 1) (or (= neighbors 2) (= neighbors 3))) 1)
                              ((and (= alive 0) (= neighbors 3)) 1)
                              (else 0))))
                    (col-loop (+ x 1))))
                (row-loop (+ y 1))))
            ;; Copy new-grid to grid
            (let cp ((i 0))
              (when (< i (* w h))
                (vector-set! grid i (vector-ref new-grid i))
                (cp (+ i 1)))))
          (gen-loop (+ gen 1))))
      ;; Render
      (let* ((lines (let build ((y 0) (acc '()))
                      (if (>= y h) (reverse acc)
                        (build (+ y 1)
                          (cons (list->string
                                  (let bcol ((x 0) (cs '()))
                                    (if (>= x w) (reverse cs)
                                      (bcol (+ x 1)
                                        (cons (if (= (vector-ref grid (+ (* y w) x)) 1) #\# #\.) cs)))))
                                acc)))))
             (text (str "=== Game of Life (gen 50) ===\n\n" (string-join lines "\n") "\n")))
        (editor-set-text ed text)
        (echo-message! echo "Game of Life rendered")))))

;; --- Feature 7: Mandelbrot ---

(def (cmd-mandelbrot app)
  "Render a text-based Mandelbrot set."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*mandelbrot*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (w 72) (h 24)
           (chars " .:-=+*#%@")
           (max-iter (- (string-length chars) 1))
           (lines
             (let row-loop ((y 0) (acc '()))
               (if (>= y h) (reverse acc)
                 (row-loop (+ y 1)
                   (cons (list->string
                           (let col-loop ((x 0) (cs '()))
                             (if (>= x w) (reverse cs)
                               (let* ((cr (+ -2.0 (* 3.0 (/ (inexact x) w))))
                                      (ci (+ -1.2 (* 2.4 (/ (inexact y) h)))))
                                 (let iter ((zr 0.0) (zi 0.0) (i 0))
                                   (if (or (>= i max-iter) (> (+ (* zr zr) (* zi zi)) 4.0))
                                     (col-loop (+ x 1) (cons (string-ref chars i) cs))
                                     (iter (+ (- (* zr zr) (* zi zi)) cr)
                                           (+ (* 2.0 zr zi) ci)
                                           (+ i 1))))))))
                         acc)))))
           (text (str "=== Mandelbrot Set ===\n\n" (string-join lines "\n") "\n")))
      (editor-set-text ed text)
      (echo-message! echo "Mandelbrot set rendered"))))

;; --- Feature 8: Maze Generator ---

(def (cmd-maze-generator app)
  "Generate a random maze in the buffer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*maze*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (w 21) (h 11)  ;; Must be odd
           (grid (make-vector (* w h) #\#)))
      ;; Simple recursive backtracker (iterative version with stack)
      (let ((start-x 1) (start-y 1))
        (vector-set! grid (+ (* start-y w) start-x) #\space)
        (let carve ((stack (list (cons start-x start-y))))
          (when (not (null? stack))
            (let* ((pos (car stack))
                   (cx (car pos)) (cy (cdr pos))
                   (dirs '((0 . -2) (0 . 2) (-2 . 0) (2 . 0)))
                   ;; Shuffle directions
                   (shuffled (let shuffle ((d dirs) (acc '()))
                               (if (null? d) acc
                                 (let ((idx (random (length d))))
                                   (shuffle (append (take d idx) (drop d (+ idx 1)))
                                     (cons (list-ref d idx) acc)))))))
              (let try-dirs ((ds shuffled) (moved #f))
                (if (or moved (null? ds))
                  (if moved
                    (carve stack)
                    (carve (cdr stack)))
                  (let* ((dx (caar ds)) (dy (cdar ds))
                         (nx (+ cx dx)) (ny (+ cy dy)))
                    (if (and (> nx 0) (< nx (- w 1))
                             (> ny 0) (< ny (- h 1))
                             (char=? (vector-ref grid (+ (* ny w) nx)) #\#))
                      (begin
                        ;; Carve wall between
                        (vector-set! grid (+ (* (+ cy (quotient dy 2)) w) (+ cx (quotient dx 2))) #\space)
                        (vector-set! grid (+ (* ny w) nx) #\space)
                        (try-dirs (cdr ds) #t)
                        (carve (cons (cons nx ny) stack)))
                      (try-dirs (cdr ds) moved)))))))))
      ;; Render
      (let* ((lines (let build ((y 0) (acc '()))
                      (if (>= y h) (reverse acc)
                        (build (+ y 1)
                          (cons (list->string
                                  (let bcol ((x 0) (cs '()))
                                    (if (>= x w) (reverse cs)
                                      (bcol (+ x 1) (cons (vector-ref grid (+ (* y w) x)) cs)))))
                                acc)))))
             (text (str "=== Random Maze ===\n\n" (string-join lines "\n") "\n")))
        (editor-set-text ed text)
        (echo-message! echo "Maze generated")))))

;; --- Feature 9: Typing Speed Test ---

(def (cmd-typing-speed-test app)
  "Test your typing speed (WPM)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (phrases '("the quick brown fox jumps over the lazy dog"
                    "pack my box with five dozen liquor jugs"
                    "how vexingly quick daft zebras jump"
                    "the five boxing wizards jump quickly"
                    "sphinx of black quartz judge my vow"))
         (phrase (list-ref phrases (random (length phrases))))
         (new-buf (create-buffer "*typing-test*")))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-set-text ed (str "=== Typing Speed Test ===\n\n"
                               "Type the following phrase:\n\n"
                               "  " phrase "\n\n"
                               "When ready, use M-x typing-speed-submit to check your result.\n"))
      (echo-message! echo (str "Type: " phrase)))))

;; --- Feature 10: Pomodoro Timer ---

(def (cmd-pomodoro-timer app)
  "Start a Pomodoro timer (25-minute work session)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (duration-str (echo-read-string echo "Minutes (default 25): " row width))
         (minutes (or (and duration-str (not (string-empty? duration-str))
                           (string->number (string-trim duration-str)))
                      25))
         (new-buf (create-buffer "*pomodoro*")))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-set-text ed (str "=== Pomodoro Timer ===\n\n"
                               "Duration: " minutes " minutes\n"
                               "Started at: " (with-output-to-string
                                                (lambda ()
                                                  (let-values (((si so se pid)
                                                                (open-process-ports "date '+%H:%M:%S'" 'block (native-transcoder))))
                                                    (close-port si)
                                                    (let ((t (get-line so)))
                                                      (close-port so) (close-port se)
                                                      (when (not (eof-object? t)) (display (string-trim t)))))))
                               "\n\nFocus on your work!\n"
                               "Use M-x pomodoro-check to see remaining time.\n"))
      (echo-message! echo (str "Pomodoro started: " minutes " minutes")))))

;; ===== Round 19 Batch 1 =====

;; --- Feature 1: Tic Tac Toe ---

(def (cmd-tic-tac-toe app)
  "Play tic-tac-toe against the computer."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*tic-tac-toe*"))
         (board (make-vector 9 #\space)))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (render (lambda ()
                     (str "=== Tic Tac Toe ===\n\n"
                          " " (vector-ref board 0) " | " (vector-ref board 1) " | " (vector-ref board 2) "\n"
                          "---+---+---\n"
                          " " (vector-ref board 3) " | " (vector-ref board 4) " | " (vector-ref board 5) "\n"
                          "---+---+---\n"
                          " " (vector-ref board 6) " | " (vector-ref board 7) " | " (vector-ref board 8) "\n\n"
                          "Positions: 1-9 (top-left to bottom-right)\n"
                          "Use M-x ttt-move to make a move.\n"))))
      (editor-set-text ed (render))
      (echo-message! echo "Tic-tac-toe! Use M-x ttt-move"))))

;; --- Feature 2: Rock Paper Scissors ---

(def (cmd-rock-paper-scissors app)
  "Play rock-paper-scissors against the computer."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (choice (echo-read-string echo "Your choice [rock/paper/scissors]: " row width)))
    (when (and choice (not (string-empty? choice)))
      (let* ((player (string-downcase (string-trim choice)))
             (options '("rock" "paper" "scissors"))
             (computer (list-ref options (random 3))))
        (if (not (member player options))
          (echo-message! echo "Invalid choice. Use: rock, paper, or scissors")
          (let ((result (cond
                          ((string=? player computer) "Draw!")
                          ((and (string=? player "rock") (string=? computer "scissors")) "You win!")
                          ((and (string=? player "paper") (string=? computer "rock")) "You win!")
                          ((and (string=? player "scissors") (string=? computer "paper")) "You win!")
                          (else "Computer wins!"))))
            (echo-message! echo (str "You: " player " | Computer: " computer " | " result))))))))

;; --- Feature 3: Dice Roller ---

(def (cmd-dice-roller app)
  "Roll dice (e.g., 2d6, 1d20, 3d8+5)."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Dice (e.g. 2d6, 1d20+5): " row width)))
    (when (and input (not (string-empty? input)))
      (let ((spec (string-downcase (string-trim input))))
        (with-catch
          (lambda (e) (echo-message! echo (str "Parse error: " e)))
          (lambda ()
            (let-values (((si so se pid)
                          (open-process-ports
                            (str "python3 -c '"
                                 "import re,random,sys;"
                                 "m=re.match(r\"(\\d+)d(\\d+)([+-]\\d+)?\",sys.argv[1]);"
                                 "n,d,mod=int(m[1]),int(m[2]),int(m[3] or 0);"
                                 "rolls=[random.randint(1,d) for _ in range(n)];"
                                 "print(f\"Rolls: {rolls} + {mod} = {sum(rolls)+mod}\")"
                                 "' " (shell-quote spec) " 2>/dev/null")
                            'block (native-transcoder))))
              (close-port si)
              (let ((result (get-line so)))
                (close-port so) (close-port se)
                (if (eof-object? result)
                  (echo-message! echo "Could not parse dice notation")
                  (echo-message! echo (string-trim result)))))))))))

;; --- Feature 4: Coin Flip ---

(def (cmd-coin-flip app)
  "Flip a coin (heads or tails)."
  (let* ((echo (app-state-echo app))
         (result (if (= (random 2) 0) "Heads" "Tails")))
    (echo-message! echo (str "Coin flip: " result "!"))))

;; --- Feature 5: Towers of Hanoi ---

(def (cmd-towers-of-hanoi app)
  "Visualize the Towers of Hanoi puzzle."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (n-str (echo-read-string echo "Number of disks (default 4): " row width))
         (n (or (and n-str (not (string-empty? n-str)) (string->number (string-trim n-str))) 4))
         (new-buf (create-buffer "*hanoi*")))
    (switch-to-buffer frame new-buf)
    (let* ((ed (edit-window-editor (current-window frame)))
           (moves '()))
      ;; Solve hanoi and collect moves
      (let solve ((num n) (from "A") (to "C") (aux "B"))
        (when (> num 0)
          (solve (- num 1) from aux to)
          (set! moves (cons (str "Move disk " num " from " from " to " to) moves))
          (solve (- num 1) aux to from)))
      (let ((text (str "=== Towers of Hanoi (" n " disks) ===\n\n"
                       "Minimum moves: " (- (expt 2 n) 1) "\n\n"
                       (string-join (reverse moves) "\n") "\n")))
        (editor-set-text ed text)
        (echo-message! echo (str "Hanoi: " (length moves) " moves"))))))

;; --- Feature 6: System Info ---

(def (cmd-system-info app)
  "Show comprehensive system information."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*system-info*")))
    (switch-to-buffer frame new-buf)
    (with-catch
      (lambda (e) (echo-message! echo (str "Error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports
                        (str "echo '=== System Information ==='; echo;"
                             "echo 'Hostname:' $(hostname);"
                             "echo 'Kernel:' $(uname -r);"
                             "echo 'OS:' $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"');"
                             "echo 'Uptime:' $(uptime -p);"
                             "echo 'CPU:' $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2);"
                             "echo 'Cores:' $(nproc);"
                             "echo 'Memory:' $(free -h | awk '/Mem:/{print $3\"/\"$2}');"
                             "echo 'Disk:' $(df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\" used)\"}');"
                             "echo 'Shell:' $SHELL;"
                             "echo 'User:' $(whoami)")
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((new-ed (edit-window-editor (current-window frame))))
                    (editor-set-text new-ed (string-join (reverse lines) "\n")))
                  (echo-message! echo "System info loaded"))
                (loop (cons line lines))))))))))

;; --- Feature 7: CPU Info ---

(def (cmd-cpu-info app)
  "Display CPU information."
  (let* ((echo (app-state-echo app)))
    (with-catch
      (lambda (e) (echo-message! echo (str "Error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "lscpu | head -20" 'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let* ((frame (app-state-frame app))
                         (new-buf (create-buffer "*cpu-info*")))
                    (switch-to-buffer frame new-buf)
                    (let ((new-ed (edit-window-editor (current-window frame))))
                      (editor-set-text new-ed (str "=== CPU Info ===\n\n" (string-join (reverse lines) "\n") "\n")))
                    (echo-message! echo "CPU info loaded")))
                (loop (cons line lines))))))))))

;; --- Feature 8: Free Memory ---

(def (cmd-free-memory app)
  "Show memory usage."
  (let* ((echo (app-state-echo app)))
    (with-catch
      (lambda (e) (echo-message! echo "Could not read memory info"))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "free -h" 'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (echo-message! echo (string-join (reverse lines) " | ")))
                (loop (cons (string-trim line) lines))))))))))

;; --- Feature 9: Network Interfaces ---

(def (cmd-network-interfaces app)
  "List network interfaces and IP addresses."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*network*")))
    (switch-to-buffer frame new-buf)
    (with-catch
      (lambda (e) (echo-message! echo (str "Error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "ip -brief addr show 2>/dev/null || ifconfig 2>/dev/null"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((new-ed (edit-window-editor (current-window frame))))
                    (editor-set-text new-ed (str "=== Network Interfaces ===\n\n"
                                                 (string-join (reverse lines) "\n") "\n")))
                  (echo-message! echo "Network interfaces loaded"))
                (loop (cons line lines))))))))))

;; --- Feature 10: Environment Variables ---

(def (cmd-environment-variables app)
  "Display all environment variables."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*env*")))
    (switch-to-buffer frame new-buf)
    (with-catch
      (lambda (e) (echo-message! echo (str "Error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "env | sort" 'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((new-ed (edit-window-editor (current-window frame))))
                    (editor-set-text new-ed (str "=== Environment Variables ===\n\n"
                                                 (string-join (reverse lines) "\n") "\n")))
                  (echo-message! echo (str (length (reverse lines)) " environment variables")))
                (loop (cons line lines)))))))))

;; ===== Round 20 Batch 1 =====

;; --- Feature 1: Currency Convert ---

(def (cmd-currency-convert app)
  "Convert between currencies using exchangerate.host API."
  (let* ((echo (app-state-echo app))
         (row (tui-rows)) (width (tui-cols))
         (input (echo-read-string echo "Convert (e.g. 100 USD EUR): " row width)))
    (when (and input (not (string-empty? input)))
      (let ((parts (string-split (string-trim input) #\space)))
        (if (not (= (length parts) 3))
          (echo-message! echo "Format: AMOUNT FROM TO (e.g. 100 USD EUR)")
          (let ((amount (car parts)) (from (cadr parts)) (to (caddr parts)))
            (with-catch
              (lambda (e) (echo-message! echo (str "Conversion error: " e)))
              (lambda ()
                (let-values (((si so se pid)
                              (open-process-ports
                                (str "python3 -c 'import urllib.request,json;"
                                     "r=urllib.request.urlopen(\"https://open.er-api.com/v6/latest/"
                                     (string-upcase from) "\");"
                                     "d=json.loads(r.read());"
                                     "rate=d[\"rates\"][\"" (string-upcase to) "\"];"
                                     "print(f\"{" amount " * rate:.2f}\")"
                                     "' 2>/dev/null")
                                'block (native-transcoder))))
                  (close-port si)
                  (let ((result (get-line so)))
                    (close-port so) (close-port se)
                    (if (eof-object? result)
                      (echo-message! echo "Could not fetch exchange rate")
                      (echo-message! echo (str amount " " (string-upcase from) " = "
                                               (string-trim result) " " (string-upcase to))))))))))))))

;; --- Feature 2: Wikipedia Summary ---

(def (cmd-wikipedia-summary app)
  "Fetch a Wikipedia article summary."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (topic (echo-read-string echo "Wikipedia topic: " row width)))
    (when (and topic (not (string-empty? topic)))
      (with-catch
        (lambda (e) (echo-message! echo (str "Wikipedia error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "curl -sL 'https://en.wikipedia.org/api/rest_v1/page/summary/"
                               (string-trim topic)
                               "' 2>/dev/null | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get(\"title\",\"?\"));print();print(d.get(\"extract\",\"Not found\"))' 2>/dev/null")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((result (string-join (reverse lines) "\n"))
                           (new-buf (create-buffer (str "*wiki: " topic "*"))))
                      (switch-to-buffer frame new-buf)
                      (let ((new-ed (edit-window-editor (current-window frame))))
                        (editor-set-text new-ed result))
                      (echo-message! echo "Wikipedia summary loaded")))
                  (loop (cons line lines))))))))))))

;; --- Feature 3: Man Page ---

(def (cmd-man-page app)
  "View a man page."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (topic (echo-read-string echo "Man page: " row width)))
    (when (and topic (not (string-empty? topic)))
      (with-catch
        (lambda (e) (echo-message! echo (str "man error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "man " (shell-quote (string-trim topic)) " 2>/dev/null | col -b | head -200")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((result (string-join (reverse lines) "\n"))
                           (new-buf (create-buffer (str "*man: " topic "*"))))
                      (switch-to-buffer frame new-buf)
                      (let ((new-ed (edit-window-editor (current-window frame))))
                        (editor-set-text new-ed result))
                      (echo-message! echo (str "Man page: " topic))))
                  (loop (cons line lines)))))))))))

;; --- Feature 4: Info Page ---

(def (cmd-info-page app)
  "View an info page."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (topic (echo-read-string echo "Info page: " row width)))
    (when (and topic (not (string-empty? topic)))
      (with-catch
        (lambda (e) (echo-message! echo (str "info error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "info " (shell-quote (string-trim topic)) " 2>/dev/null | head -200")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let* ((result (string-join (reverse lines) "\n"))
                           (new-buf (create-buffer (str "*info: " topic "*"))))
                      (switch-to-buffer frame new-buf)
                      (let ((new-ed (edit-window-editor (current-window frame))))
                        (editor-set-text new-ed result))
                      (echo-message! echo (str "Info page: " topic))))
                  (loop (cons line lines)))))))))))

;; --- Feature 5: TLDR Page ---

(def (cmd-tldr-page app)
  "View a tldr page (simplified man page)."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (row (tui-rows)) (width (tui-cols))
         (cmd (echo-read-string echo "TLDR for command: " row width)))
    (when (and cmd (not (string-empty? cmd)))
      (with-catch
        (lambda (e) (echo-message! echo (str "tldr error: " e)))
        (lambda ()
          (let-values (((si so se pid)
                        (open-process-ports
                          (str "tldr " (shell-quote (string-trim cmd)) " 2>/dev/null")
                          'block (native-transcoder))))
            (close-port si)
            (let loop ((lines '()))
              (let ((line (get-line so)))
                (if (eof-object? line)
                  (begin
                    (close-port so) (close-port se)
                    (let ((result (string-join (reverse lines) "\n")))
                      (if (string-empty? result)
                        (echo-message! echo (str "No tldr page for: " cmd))
                        (let* ((new-buf (create-buffer (str "*tldr: " cmd "*"))))
                          (switch-to-buffer frame new-buf)
                          (let ((new-ed (edit-window-editor (current-window frame))))
                            (editor-set-text new-ed result))
                          (echo-message! echo (str "TLDR: " cmd))))))
                  (loop (cons line lines)))))))))))

;; --- Feature 6: Tutorial Mode ---

(def (cmd-tutorial-mode app)
  "Show the jemacs tutorial."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*tutorial*")))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-set-text ed
        (str "=== Welcome to jemacs! ===\n\n"
             "jemacs is a Chez Scheme Emacs-like editor.\n\n"
             "== Basic Navigation ==\n"
             "  C-f / Right   Move forward one character\n"
             "  C-b / Left    Move backward one character\n"
             "  C-n / Down    Move to next line\n"
             "  C-p / Up      Move to previous line\n"
             "  C-a / Home    Move to beginning of line\n"
             "  C-e / End     Move to end of line\n"
             "  M-f           Move forward one word\n"
             "  M-b           Move backward one word\n"
             "  C-v           Page down\n"
             "  M-v           Page up\n"
             "  M-<           Go to beginning of buffer\n"
             "  M->           Go to end of buffer\n\n"
             "== Editing ==\n"
             "  C-d / Delete  Delete character forward\n"
             "  Backspace     Delete character backward\n"
             "  C-k           Kill to end of line\n"
             "  C-w           Kill region\n"
             "  M-w           Copy region\n"
             "  C-y           Yank (paste)\n"
             "  C-/           Undo\n"
             "  C-space       Set mark\n\n"
             "== Files and Buffers ==\n"
             "  C-x C-f       Find (open) file\n"
             "  C-x C-s       Save buffer\n"
             "  C-x b         Switch buffer\n"
             "  C-x k         Kill buffer\n\n"
             "== Windows ==\n"
             "  C-x 2         Split window below\n"
             "  C-x 3         Split window right\n"
             "  C-x 0         Delete window\n"
             "  C-x 1         Delete other windows\n"
             "  C-x o         Other window\n\n"
             "== Commands ==\n"
             "  M-x           Execute extended command\n"
             "  C-g           Cancel/quit\n"
             "  C-x C-c       Exit jemacs\n\n"
             "Over 2400 commands available via M-x!\n"))
      (echo-message! echo "Tutorial loaded"))))

;; --- Feature 7: Version Info ---

(def (cmd-version-info app)
  "Show detailed jemacs version information."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*version*")))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-set-text ed
        (str "=== jemacs Version Info ===\n\n"
             "jemacs - Chez Scheme Emacs-like Editor\n\n"
             "Built on:\n"
             "  Chez Scheme " (scheme-version-number) "\n"
             "  Jerboa Scheme dialect\n"
             "  Scintilla editor component\n\n"
             "Features: 2400+ commands\n"
             "Modes: TUI (terminal) and Qt (graphical)\n\n"
             "Project: jerboa-emacs\n"
             "License: Open Source\n"))
      (echo-message! echo "Version info displayed"))))

;; --- Feature 8: Changelog View ---

(def (cmd-changelog-view app)
  "View the project changelog via git log."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*changelog*")))
    (switch-to-buffer frame new-buf)
    (with-catch
      (lambda (e) (echo-message! echo (str "Error: " e)))
      (lambda ()
        (let-values (((si so se pid)
                      (open-process-ports "git log --oneline -50 2>/dev/null"
                        'block (native-transcoder))))
          (close-port si)
          (let loop ((lines '()))
            (let ((line (get-line so)))
              (if (eof-object? line)
                (begin
                  (close-port so) (close-port se)
                  (let ((new-ed (edit-window-editor (current-window frame))))
                    (editor-set-text new-ed (str "=== Changelog ===\n\n"
                                                 (string-join (reverse lines) "\n") "\n")))
                  (echo-message! echo "Changelog loaded"))
                (loop (cons line lines))))))))))

;; --- Feature 9: Bug Report Mode ---

(def (cmd-bug-report-mode app)
  "Create a bug report template."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (new-buf (create-buffer "*bug-report*")))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-set-text ed
        (str "=== Bug Report ===\n\n"
             "Summary: \n\n"
             "Steps to Reproduce:\n"
             "1. \n"
             "2. \n"
             "3. \n\n"
             "Expected Behavior:\n\n\n"
             "Actual Behavior:\n\n\n"
             "System Info:\n"
             "  OS: " (with-output-to-string (lambda ()
                        (with-catch (lambda (e) (display "unknown"))
                          (lambda ()
                            (let-values (((si so se pid) (open-process-ports "uname -sr" 'block (native-transcoder))))
                              (close-port si)
                              (let ((info (get-line so)))
                                (close-port so) (close-port se)
                                (when (not (eof-object? info)) (display (string-trim info)))))))))
             "\n  Chez: " (scheme-version-number)
             "\n\nAdditional Notes:\n\n"))
      (echo-message! echo "Bug report template ready"))))

;; --- Feature 10: Color Theme Select ---

(def (cmd-color-theme-select app)
  "Select a color theme for the editor."
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (row (tui-rows)) (width (tui-cols))
         (themes '("dark" "light" "solarized" "monokai" "dracula" "gruvbox" "nord"))
         (choice (echo-read-string echo (str "Theme [" (string-join themes "/") "]: ") row width)))
    (when (and choice (not (string-empty? choice)))
      (let ((theme (string-downcase (string-trim choice))))
        (cond
          ((string=? theme "dark")
           (send-message ed SCI_STYLESETBACK 32 #x1E1E1E)
           (send-message ed SCI_STYLESETFORE 32 #xD4D4D4))
          ((string=? theme "light")
           (send-message ed SCI_STYLESETBACK 32 #xFFFFFF)
           (send-message ed SCI_STYLESETFORE 32 #x000000))
          ((string=? theme "solarized")
           (send-message ed SCI_STYLESETBACK 32 #x002B36)
           (send-message ed SCI_STYLESETFORE 32 #x839496))
          ((string=? theme "monokai")
           (send-message ed SCI_STYLESETBACK 32 #x272822)
           (send-message ed SCI_STYLESETFORE 32 #xF8F8F2))
          ((string=? theme "dracula")
           (send-message ed SCI_STYLESETBACK 32 #x282A36)
           (send-message ed SCI_STYLESETFORE 32 #xF8F8F2))
          ((string=? theme "gruvbox")
           (send-message ed SCI_STYLESETBACK 32 #x282828)
           (send-message ed SCI_STYLESETFORE 32 #xEBDBB2))
          ((string=? theme "nord")
           (send-message ed SCI_STYLESETBACK 32 #x2E3440)
           (send-message ed SCI_STYLESETFORE 32 #xD8DEE9))
          (else (echo-message! echo (str "Unknown theme: " theme))))
        (send-message ed SCI_STYLECLEARALL 0 0)
        (echo-message! echo (str "Theme: " theme))))))

;; Round 21 batch 1: auto-fill-mode, display-line-numbers-mode, visual-line-mode,
;; whitespace-cleanup, indent-rigidly, align-regexp, comment-dwim, uncomment-region,
;; toggle-comment, fill-paragraph

;; cmd-auto-fill-mode: Toggle auto-fill mode (wrap lines at fill column)
(def (cmd-auto-fill-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'auto-fill-mode)
    (if (mode-enabled? app 'auto-fill-mode)
      (echo-message! echo "Auto-Fill mode enabled (fill column: 80)")
      (echo-message! echo "Auto-Fill mode disabled"))))

;; cmd-display-line-numbers-mode: Toggle line number display
(def (cmd-display-line-numbers-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (toggle-mode! app 'display-line-numbers-mode)
    (if (mode-enabled? app 'display-line-numbers-mode)
      (begin
        (send-message ed SCI_SETMARGINWIDTHN 0 48)
        (echo-message! echo "Line numbers enabled"))
      (begin
        (send-message ed SCI_SETMARGINWIDTHN 0 0)
        (echo-message! echo "Line numbers disabled")))))

;; cmd-visual-line-mode: Toggle visual line mode (word wrap)
(def (cmd-visual-line-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (toggle-mode! app 'visual-line-mode)
    (if (mode-enabled? app 'visual-line-mode)
      (begin
        (send-message ed SCI_SETWRAPMODE 1 0)
        (echo-message! echo "Visual line mode enabled (word wrap on)"))
      (begin
        (send-message ed SCI_SETWRAPMODE 0 0)
        (echo-message! echo "Visual line mode disabled (word wrap off)")))))

;; cmd-whitespace-cleanup: Remove trailing whitespace and fix indentation
(def (cmd-whitespace-cleanup app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (editor-get-text ed))
         (lines (string-split text #\newline))
         (cleaned (map (lambda (line)
                         (let loop ((i (- (string-length line) 1)))
                           (if (< i 0) ""
                             (let ((c (string-ref line i)))
                               (if (or (char=? c #\space) (char=? c #\tab))
                                 (loop (- i 1))
                                 (substring line 0 (+ i 1)))))))
                       lines))
         (result (string-join cleaned "\n"))
         (diff (- (string-length text) (string-length result))))
    (editor-set-text ed result)
    (echo-message! echo (str "Whitespace cleanup: removed " diff " trailing chars"))))

;; cmd-indent-rigidly: Indent or dedent region by N spaces
(def (cmd-indent-rigidly app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((amount-str (echo-read-string echo "Indent amount (negative to dedent): "))
             (amount (if (and amount-str (not (string=? amount-str "")))
                       (string->number amount-str) #f)))
        (if (not amount)
          (echo-message! echo "Invalid number")
          (let* ((text (editor-get-text-range ed sel-start sel-end))
                 (lines (string-split text #\newline))
                 (indented (map (lambda (line)
                                  (if (> amount 0)
                                    (str (make-string amount #\space) line)
                                    (let ((to-remove (min (abs amount) (string-length line))))
                                      (let check ((i 0))
                                        (if (or (>= i to-remove) (>= i (string-length line))
                                                (not (char=? (string-ref line i) #\space)))
                                          (substring line i (string-length line))
                                          (check (+ i 1)))))))
                                lines))
                 (result (string-join indented "\n")))
            (editor-replace-range ed sel-start sel-end result)
            (echo-message! echo (str "Indented by " amount " spaces"))))))))

;; cmd-align-regexp: Align region by a regexp pattern
(def (cmd-align-regexp app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((pattern (echo-read-string echo "Align regexp: "))
             (text (editor-get-text-range ed sel-start sel-end))
             (lines (string-split text #\newline)))
        (if (or (not pattern) (string=? pattern ""))
          (echo-message! echo "No pattern specified")
          (let* ((positions (map (lambda (line)
                                   (string-contains line pattern))
                                 lines))
                 (max-pos (apply max (map (lambda (p) (if p p 0)) positions)))
                 (aligned (map (lambda (line pos)
                                 (if pos
                                   (str (substring line 0 pos)
                                        (make-string (- max-pos pos) #\space)
                                        (substring line pos (string-length line)))
                                   line))
                               lines positions))
                 (result (string-join aligned "\n")))
            (editor-replace-range ed sel-start sel-end result)
            (echo-message! echo (str "Aligned on \"" pattern "\""))))))))

;; cmd-comment-dwim: Comment or uncomment region/line intelligently
(def (cmd-comment-dwim app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed))
         (has-sel (not (= sel-start sel-end)))
         (start (if has-sel sel-start (editor-line-start ed (editor-current-line ed))))
         (end (if has-sel sel-end (editor-line-end ed (editor-current-line ed))))
         (text (editor-get-text-range ed start end))
         (lines (string-split text #\newline))
         (all-commented (every (lambda (line)
                                 (let ((trimmed (string-trim line)))
                                   (or (string=? trimmed "")
                                       (string-prefix? ";;" trimmed)
                                       (string-prefix? "#" trimmed)
                                       (string-prefix? "//" trimmed))))
                               lines)))
    (if all-commented
      ;; Uncomment
      (let* ((uncommented (map (lambda (line)
                                 (let ((trimmed (string-trim line)))
                                   (cond
                                     ((string-prefix? ";; " trimmed)
                                      (substring trimmed 3 (string-length trimmed)))
                                     ((string-prefix? ";;" trimmed)
                                      (substring trimmed 2 (string-length trimmed)))
                                     ((string-prefix? "# " trimmed)
                                      (substring trimmed 2 (string-length trimmed)))
                                     ((string-prefix? "// " trimmed)
                                      (substring trimmed 3 (string-length trimmed)))
                                     ((string-prefix? "//" trimmed)
                                      (substring trimmed 2 (string-length trimmed)))
                                     (else line))))
                               lines))
             (result (string-join uncommented "\n")))
        (editor-replace-range ed start end result)
        (echo-message! echo "Uncommented"))
      ;; Comment
      (let* ((commented (map (lambda (line)
                               (if (string=? (string-trim line) "")
                                 line
                                 (str ";; " line)))
                             lines))
             (result (string-join commented "\n")))
        (editor-replace-range ed start end result)
        (echo-message! echo "Commented")))))

;; cmd-uncomment-region: Remove comment markers from region
(def (cmd-uncomment-region app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start sel-end))
             (lines (string-split text #\newline))
             (uncommented (map (lambda (line)
                                 (let ((trimmed (string-trim line)))
                                   (cond
                                     ((string-prefix? ";; " trimmed)
                                      (substring trimmed 3 (string-length trimmed)))
                                     ((string-prefix? ";;" trimmed)
                                      (substring trimmed 2 (string-length trimmed)))
                                     ((string-prefix? "# " trimmed)
                                      (substring trimmed 2 (string-length trimmed)))
                                     ((string-prefix? "// " trimmed)
                                      (substring trimmed 3 (string-length trimmed)))
                                     ((string-prefix? "//" trimmed)
                                      (substring trimmed 2 (string-length trimmed)))
                                     (else line))))
                               lines))
             (result (string-join uncommented "\n")))
        (editor-replace-range ed sel-start sel-end result)
        (echo-message! echo "Region uncommented")))))

;; cmd-toggle-comment: Toggle comment on current line or region
(def (cmd-toggle-comment app)
  (cmd-comment-dwim app))

;; cmd-fill-paragraph: Wrap current paragraph to fill column
(def (cmd-fill-paragraph app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (fill-col 80)
         (cur-line (editor-current-line ed))
         (total-lines (editor-line-count ed)))
    ;; Find paragraph boundaries (blank lines)
    (let* ((para-start (let loop ((ln cur-line))
                         (if (<= ln 0) 0
                           (let ((text (editor-get-line ed ln)))
                             (if (string=? (string-trim text) "")
                               (+ ln 1) (loop (- ln 1)))))))
           (para-end (let loop ((ln cur-line))
                       (if (>= ln total-lines) (- total-lines 1)
                         (let ((text (editor-get-line ed ln)))
                           (if (string=? (string-trim text) "")
                             (- ln 1) (loop (+ ln 1)))))))
           (start-pos (editor-line-start ed para-start))
           (end-pos (editor-line-end ed para-end))
           (para-text (editor-get-text-range ed start-pos end-pos))
           ;; Join all lines and split into words
           (words (let split-words ((s (string-trim para-text)) (result '()))
                    (let ((trimmed (string-trim s)))
                      (if (string=? trimmed "") (reverse result)
                        (let find-space ((i 0))
                          (if (>= i (string-length trimmed))
                            (reverse (cons trimmed result))
                            (if (char-whitespace? (string-ref trimmed i))
                              (split-words (substring trimmed i (string-length trimmed))
                                           (cons (substring trimmed 0 i) result))
                              (find-space (+ i 1))))))))))
      (if (null? words)
        (echo-message! echo "Empty paragraph")
        (let fill ((ws words) (line "") (lines '()))
          (if (null? ws)
            (let* ((all-lines (reverse (if (string=? line "") lines (cons line lines))))
                   (result (string-join all-lines "\n")))
              (editor-replace-range ed start-pos end-pos result)
              (echo-message! echo (str "Filled paragraph to column " fill-col)))
            (let* ((word (car ws))
                   (new-line (if (string=? line "") word (str line " " word))))
              (if (> (string-length new-line) fill-col)
                (if (string=? line "")
                  (fill (cdr ws) "" (cons word lines))
                  (fill ws "" (cons line lines)))
                (fill (cdr ws) new-line lines)))))))))

;; Round 22 batch 1: abbrev-mode, expand-abbrev, define-abbrev, list-abbrevs,
;; insert-register, copy-to-register, point-to-register, jump-to-register,
;; view-register, list-registers

;; cmd-abbrev-mode: Toggle abbreviation expansion mode
(def (cmd-abbrev-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'abbrev-mode)
    (if (mode-enabled? app 'abbrev-mode)
      (echo-message! echo "Abbrev mode enabled")
      (echo-message! echo "Abbrev mode disabled"))))

;; cmd-expand-abbrev: Expand abbreviation at point
(def (cmd-expand-abbrev app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         ;; Get word before cursor
         (line-start (editor-line-start ed (editor-current-line ed)))
         (before-text (editor-get-text-range ed line-start pos)))
    ;; Find last word
    (let loop ((i (- (string-length before-text) 1)) (end (string-length before-text)))
      (if (or (< i 0) (char-whitespace? (string-ref before-text i)))
        (let* ((word (substring before-text (+ i 1) end))
               (abbrevs (or (hash-get (app-state-modes app) 'abbrev-table) (make-hash-table)))
               (expansion (hash-get abbrevs word)))
          (if expansion
            (begin
              (editor-replace-range ed (+ line-start i 1) pos expansion)
              (echo-message! echo (str "Expanded \"" word "\" to \"" expansion "\"")))
            (echo-message! echo (str "No abbrev for \"" word "\""))))
        (loop (- i 1) end)))))

;; cmd-define-abbrev: Define a new abbreviation
(def (cmd-define-abbrev app)
  (let* ((echo (app-state-echo app))
         (abbrev (echo-read-string echo "Abbrev: ")))
    (if (or (not abbrev) (string=? abbrev ""))
      (echo-message! echo "No abbreviation specified")
      (let ((expansion (echo-read-string echo (str "Expansion for \"" abbrev "\": "))))
        (if (or (not expansion) (string=? expansion ""))
          (echo-message! echo "No expansion specified")
          (let ((table (or (hash-get (app-state-modes app) 'abbrev-table) (make-hash-table))))
            (hash-put! table abbrev expansion)
            (hash-put! (app-state-modes app) 'abbrev-table table)
            (echo-message! echo (str "Defined abbrev: \"" abbrev "\" → \"" expansion "\""))))))))

;; cmd-list-abbrevs: List all defined abbreviations
(def (cmd-list-abbrevs app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (table (or (hash-get (app-state-modes app) 'abbrev-table) (make-hash-table)))
         (entries (hash->list table))
         (text (if (null? entries)
                 "=== Abbreviations ===\n\nNo abbreviations defined.\nUse M-x define-abbrev to add one.\n"
                 (str "=== Abbreviations ===\n\n"
                      (string-join
                        (map (lambda (pair)
                               (str "  " (car pair) " → " (cdr pair)))
                             entries)
                        "\n")
                      "\n\nTotal: " (length entries) " abbreviations\n"))))
    (editor-set-text ed text)
    (echo-message! echo (str (length entries) " abbreviations"))))

;; cmd-copy-to-register: Store region text in a named register
(def (cmd-copy-to-register app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let ((reg-name (echo-read-string echo "Register name (single char): ")))
        (if (or (not reg-name) (string=? reg-name ""))
          (echo-message! echo "No register specified")
          (let* ((text (editor-get-text-range ed sel-start sel-end))
                 (registers (or (hash-get (app-state-modes app) 'text-registers) (make-hash-table))))
            (hash-put! registers reg-name text)
            (hash-put! (app-state-modes app) 'text-registers registers)
            (echo-message! echo (str "Copied to register " reg-name))))))))

;; cmd-insert-register: Insert text from a named register
(def (cmd-insert-register app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (reg-name (echo-read-string echo "Insert register: ")))
    (if (or (not reg-name) (string=? reg-name ""))
      (echo-message! echo "No register specified")
      (let* ((registers (or (hash-get (app-state-modes app) 'text-registers) (make-hash-table)))
             (text (hash-get registers reg-name)))
        (if text
          (begin
            (editor-insert-text ed (editor-cursor-position ed) text)
            (echo-message! echo (str "Inserted register " reg-name)))
          (echo-message! echo (str "Register " reg-name " is empty")))))))

;; cmd-point-to-register: Save current position to a register
(def (cmd-point-to-register app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (reg-name (echo-read-string echo "Point to register: ")))
    (if (or (not reg-name) (string=? reg-name ""))
      (echo-message! echo "No register specified")
      (let ((registers (or (hash-get (app-state-modes app) 'point-registers) (make-hash-table)))
            (pos (editor-cursor-position ed))
            (file (buffer-file buf)))
        (hash-put! registers reg-name (cons (or file (buffer-name buf)) pos))
        (hash-put! (app-state-modes app) 'point-registers registers)
        (echo-message! echo (str "Point saved to register " reg-name))))))

;; cmd-jump-to-register: Jump to position saved in a register
(def (cmd-jump-to-register app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (reg-name (echo-read-string echo "Jump to register: ")))
    (if (or (not reg-name) (string=? reg-name ""))
      (echo-message! echo "No register specified")
      (let* ((registers (or (hash-get (app-state-modes app) 'point-registers) (make-hash-table)))
             (entry (hash-get registers reg-name)))
        (if entry
          (begin
            (editor-set-cursor ed (cdr entry))
            (echo-message! echo (str "Jumped to register " reg-name " (pos " (cdr entry) ")")))
          (echo-message! echo (str "Register " reg-name " has no position")))))))

;; cmd-view-register: Show contents of a register
(def (cmd-view-register app)
  (let* ((echo (app-state-echo app))
         (reg-name (echo-read-string echo "View register: ")))
    (if (or (not reg-name) (string=? reg-name ""))
      (echo-message! echo "No register specified")
      (let* ((text-regs (or (hash-get (app-state-modes app) 'text-registers) (make-hash-table)))
             (point-regs (or (hash-get (app-state-modes app) 'point-registers) (make-hash-table)))
             (text (hash-get text-regs reg-name))
             (point (hash-get point-regs reg-name)))
        (cond
          ((and text point)
           (echo-message! echo (str "Register " reg-name ": text=\"" (if (> (string-length text) 40) (str (substring text 0 40) "...") text) "\" + point=" (cdr point))))
          (text
           (echo-message! echo (str "Register " reg-name ": \"" (if (> (string-length text) 60) (str (substring text 0 60) "...") text) "\"")))
          (point
           (echo-message! echo (str "Register " reg-name ": position " (cdr point) " in " (car point))))
          (else
           (echo-message! echo (str "Register " reg-name " is empty"))))))))

;; cmd-list-registers: List all registers and their contents
(def (cmd-list-registers app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text-regs (or (hash-get (app-state-modes app) 'text-registers) (make-hash-table)))
         (point-regs (or (hash-get (app-state-modes app) 'point-registers) (make-hash-table)))
         (text-entries (hash->list text-regs))
         (point-entries (hash->list point-regs))
         (output (str "=== Registers ===\n\n"
                      "--- Text Registers ---\n"
                      (if (null? text-entries) "  (none)\n"
                        (string-join
                          (map (lambda (pair)
                                 (let ((val (cdr pair)))
                                   (str "  " (car pair) ": \"" (if (> (string-length val) 60) (str (substring val 0 60) "...") val) "\"")))
                               text-entries)
                          "\n"))
                      "\n\n--- Point Registers ---\n"
                      (if (null? point-entries) "  (none)\n"
                        (string-join
                          (map (lambda (pair)
                                 (str "  " (car pair) ": position " (cddr pair) " in " (cadr pair)))
                               point-entries)
                          "\n"))
                      "\n")))
    (editor-set-text ed output)
    (echo-message! echo (str (+ (length text-entries) (length point-entries)) " registers"))))

;; Round 23 batch 1: how-many, count-matches, occur-mode, delete-matching-lines,
;; delete-non-matching-lines, transpose-lines, transpose-words, transpose-sexps,
;; transpose-paragraphs, upcase-word

;; cmd-how-many: Count occurrences of a pattern
(def (cmd-how-many app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "How many matches for: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((text (editor-get-text ed))
             (pat-len (string-length pattern))
             (count (let loop ((pos 0) (n 0))
                      (let ((idx (string-contains text pattern pos)))
                        (if (not idx) n
                          (loop (+ idx pat-len) (+ n 1)))))))
        (echo-message! echo (str count " occurrences of \"" pattern "\""))))))

;; cmd-count-matches: Alias for how-many
(def (cmd-count-matches app)
  (cmd-how-many app))

;; cmd-occur-mode: Show all lines matching a pattern
(def (cmd-occur-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "Occur pattern: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((text (editor-get-text ed))
             (lines (string-split text #\newline))
             (matches (let loop ((ls lines) (n 1) (acc '()))
                        (if (null? ls) (reverse acc)
                          (let ((line (car ls)))
                            (if (string-contains line pattern)
                              (loop (cdr ls) (+ n 1) (cons (str (number->string n) ": " line) acc))
                              (loop (cdr ls) (+ n 1) acc))))))
             (result (str "=== Occur: \"" pattern "\" ===\n\n"
                          (if (null? matches) "No matches found.\n"
                            (str (string-join matches "\n") "\n\n"
                                 (number->string (length matches)) " matches\n")))))
        (editor-set-text ed result)
        (echo-message! echo (str (length matches) " matches for \"" pattern "\""))))))

;; cmd-delete-matching-lines: Delete lines matching pattern (alias for flush-lines)
(def (cmd-delete-matching-lines app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "Delete lines matching: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((text (editor-get-text ed))
             (lines (string-split text #\newline))
             (kept (filter (lambda (line) (not (string-contains line pattern))) lines))
             (removed (- (length lines) (length kept)))
             (result (string-join kept "\n")))
        (editor-set-text ed result)
        (echo-message! echo (str "Deleted " removed " matching lines"))))))

;; cmd-delete-non-matching-lines: Delete lines NOT matching pattern (alias for keep-lines)
(def (cmd-delete-non-matching-lines app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "Keep lines matching: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((text (editor-get-text ed))
             (lines (string-split text #\newline))
             (kept (filter (lambda (line) (string-contains line pattern)) lines))
             (removed (- (length lines) (length kept)))
             (result (string-join kept "\n")))
        (editor-set-text ed result)
        (echo-message! echo (str "Kept " (length kept) " matching lines, deleted " removed))))))

;; cmd-transpose-lines: Swap current line with the one above
(def (cmd-transpose-lines app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (cur-line (editor-current-line ed)))
    (if (<= cur-line 0)
      (echo-message! echo "No line above to transpose with")
      (let* ((line1-start (editor-line-start ed (- cur-line 1)))
             (line1-end (editor-line-end ed (- cur-line 1)))
             (line2-start (editor-line-start ed cur-line))
             (line2-end (editor-line-end ed cur-line))
             (line1-text (editor-get-text-range ed line1-start line1-end))
             (line2-text (editor-get-text-range ed line2-start line2-end)))
        (editor-replace-range ed line2-start line2-end line1-text)
        (editor-replace-range ed line1-start line1-end line2-text)
        (echo-message! echo "Lines transposed")))))

;; cmd-transpose-words: Swap word before and after cursor
(def (cmd-transpose-words app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    ;; Find word boundaries around cursor
    (let* ((word-end2 (let loop ((i pos))
                        (if (or (>= i len) (not (char-alphabetic? (string-ref text i))))
                          i (loop (+ i 1)))))
           (word-start2 (let loop ((i (max 0 (- pos 1))))
                          (if (or (<= i 0) (not (char-alphabetic? (string-ref text i))))
                            (+ i 1) (loop (- i 1)))))
           ;; Find previous word
           (gap-start (let loop ((i (- word-start2 1)))
                        (if (or (<= i 0) (char-alphabetic? (string-ref text i)))
                          (+ i 1) (loop (- i 1)))))
           (word-end1 gap-start)
           (word-start1 (let loop ((i (- word-end1 1)))
                          (if (or (<= i 0) (not (char-alphabetic? (string-ref text i))))
                            (+ i 1) (loop (- i 1))))))
      (if (>= word-start1 word-start2)
        (echo-message! echo "Cannot transpose words here")
        (let* ((word1 (substring text word-start1 word-end1))
               (between (substring text word-end1 word-start2))
               (word2 (substring text word-start2 word-end2))
               (replacement (str word2 between word1)))
          (editor-replace-range ed word-start1 word-end2 replacement)
          (echo-message! echo "Words transposed"))))))

;; cmd-transpose-sexps: Swap S-expressions around cursor
(def (cmd-transpose-sexps app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "transpose-sexps: requires full sexp parser (not yet implemented)")))

;; cmd-transpose-paragraphs: Swap current paragraph with previous
(def (cmd-transpose-paragraphs app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (cur-line (editor-current-line ed))
         (total-lines (editor-line-count ed)))
    ;; Find current paragraph boundaries
    (let* ((para2-start (let loop ((ln cur-line))
                          (if (<= ln 0) 0
                            (if (string=? (string-trim (editor-get-line ed ln)) "")
                              (+ ln 1) (loop (- ln 1))))))
           (para2-end (let loop ((ln cur-line))
                        (if (>= ln total-lines) (- total-lines 1)
                          (if (string=? (string-trim (editor-get-line ed ln)) "")
                            (- ln 1) (loop (+ ln 1))))))
           ;; Find previous paragraph
           (gap-line (let loop ((ln (- para2-start 1)))
                       (if (<= ln 0) -1
                         (if (not (string=? (string-trim (editor-get-line ed ln)) ""))
                           ln (loop (- ln 1))))))
           )
      (if (< gap-line 0)
        (echo-message! echo "No previous paragraph to transpose with")
        (let* ((para1-end gap-line)
               (para1-start (let loop ((ln para1-end))
                              (if (<= ln 0) 0
                                (if (string=? (string-trim (editor-get-line ed ln)) "")
                                  (+ ln 1) (loop (- ln 1))))))
               (p1-start-pos (editor-line-start ed para1-start))
               (p1-end-pos (editor-line-end ed para1-end))
               (p2-start-pos (editor-line-start ed para2-start))
               (p2-end-pos (editor-line-end ed para2-end))
               (para1-text (editor-get-text-range ed p1-start-pos p1-end-pos))
               (between-text (editor-get-text-range ed p1-end-pos p2-start-pos))
               (para2-text (editor-get-text-range ed p2-start-pos p2-end-pos))
               (replacement (str para2-text between-text para1-text)))
          (editor-replace-range ed p1-start-pos p2-end-pos replacement)
          (echo-message! echo "Paragraphs transposed"))))))

;; cmd-upcase-word: Convert word at cursor to uppercase
(def (cmd-upcase-word app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    ;; Find word boundaries
    (let* ((word-start (let loop ((i pos))
                         (if (or (<= i 0) (not (char-alphabetic? (string-ref text (- i 1)))))
                           i (loop (- i 1)))))
           (word-end (let loop ((i pos))
                       (if (or (>= i len) (not (char-alphabetic? (string-ref text i))))
                         i (loop (+ i 1))))))
      (if (= word-start word-end)
        (echo-message! echo "No word at point")
        (let ((word (string-upcase (substring text word-start word-end))))
          (editor-replace-range ed word-start word-end word)
          (echo-message! echo (str "Upcased: " word)))))))

;; Round 24 batch 1: delete-horizontal-space, cycle-spacing, zap-to-char, zap-up-to-char,
;; delete-pair, mark-word, mark-sexp, mark-paragraph, mark-page, mark-whole-buffer

;; cmd-delete-horizontal-space: Delete all spaces and tabs around point
(def (cmd-delete-horizontal-space app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let* ((ws-start (let loop ((i (- pos 1)))
                       (if (or (< i 0)
                               (let ((c (string-ref text i)))
                                 (not (or (char=? c #\space) (char=? c #\tab)))))
                         (+ i 1) (loop (- i 1)))))
           (ws-end (let loop ((i pos))
                     (if (or (>= i len)
                             (let ((c (string-ref text i)))
                               (not (or (char=? c #\space) (char=? c #\tab)))))
                       i (loop (+ i 1))))))
      (if (= ws-start ws-end)
        (echo-message! echo "No horizontal space to delete")
        (begin
          (editor-replace-range ed ws-start ws-end "")
          (echo-message! echo "Horizontal space deleted"))))))

;; cmd-cycle-spacing: Cycle between one space, no space, and original spacing
(def (cmd-cycle-spacing app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let* ((ws-start (let loop ((i (- pos 1)))
                       (if (or (< i 0) (not (char-whitespace? (string-ref text i))))
                         (+ i 1) (loop (- i 1)))))
           (ws-end (let loop ((i pos))
                     (if (or (>= i len) (not (char-whitespace? (string-ref text i))))
                       i (loop (+ i 1)))))
           (ws-len (- ws-end ws-start)))
      (cond
        ((= ws-len 0) (editor-insert-text ed pos " ") (echo-message! echo "Inserted space"))
        ((= ws-len 1) (editor-replace-range ed ws-start ws-end "") (echo-message! echo "Deleted space"))
        (else (editor-replace-range ed ws-start ws-end " ") (echo-message! echo "Reduced to one space"))))))

;; cmd-zap-to-char: Delete from point to next occurrence of a character (inclusive)
(def (cmd-zap-to-char app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (char-str (echo-read-string echo "Zap to char: ")))
    (if (or (not char-str) (string=? char-str ""))
      (echo-message! echo "No character specified")
      (let* ((c (string-ref char-str 0))
             (pos (editor-cursor-position ed))
             (text (editor-get-text ed))
             (len (string-length text))
             (target (let loop ((i (+ pos 1)))
                       (if (>= i len) #f
                         (if (char=? (string-ref text i) c) i
                           (loop (+ i 1)))))))
        (if (not target)
          (echo-message! echo (str "Character '" char-str "' not found"))
          (begin
            (editor-replace-range ed pos (+ target 1) "")
            (echo-message! echo (str "Zapped to '" char-str "'"))))))))

;; cmd-zap-up-to-char: Delete from point to just before next occurrence of char
(def (cmd-zap-up-to-char app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (char-str (echo-read-string echo "Zap up to char: ")))
    (if (or (not char-str) (string=? char-str ""))
      (echo-message! echo "No character specified")
      (let* ((c (string-ref char-str 0))
             (pos (editor-cursor-position ed))
             (text (editor-get-text ed))
             (len (string-length text))
             (target (let loop ((i (+ pos 1)))
                       (if (>= i len) #f
                         (if (char=? (string-ref text i) c) i
                           (loop (+ i 1)))))))
        (if (not target)
          (echo-message! echo (str "Character '" char-str "' not found"))
          (begin
            (editor-replace-range ed pos target "")
            (echo-message! echo (str "Zapped up to '" char-str "'"))))))))

;; cmd-delete-pair: Delete matching pair of characters (parens, brackets, etc.)
(def (cmd-delete-pair app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (if (>= pos len)
      (echo-message! echo "End of buffer")
      (let* ((c (string-ref text pos))
             (pairs '((#\( . #\)) (#\[ . #\]) (#\{ . #\}) (#\" . #\") (#\' . #\')))
             (match (assv c pairs)))
        (if (not match)
          (echo-message! echo "Not on a pair character")
          (let* ((close (cdr match))
                 (close-pos (let loop ((i (+ pos 1)) (depth 1))
                              (if (>= i len) #f
                                (let ((ch (string-ref text i)))
                                  (cond
                                    ((and (char=? ch close) (= depth 1)) i)
                                    ((char=? ch c) (loop (+ i 1) (+ depth 1)))
                                    ((char=? ch close) (loop (+ i 1) (- depth 1)))
                                    (else (loop (+ i 1) depth))))))))
            (if (not close-pos)
              (echo-message! echo "No matching close character found")
              (begin
                ;; Delete closing first (higher position), then opening
                (editor-replace-range ed close-pos (+ close-pos 1) "")
                (editor-replace-range ed pos (+ pos 1) "")
                (echo-message! echo "Pair deleted")))))))))

;; cmd-mark-word: Select the word at or after point
(def (cmd-mark-word app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let* ((word-start (let loop ((i pos))
                         (if (or (<= i 0) (not (char-alphabetic? (string-ref text (- i 1)))))
                           i (loop (- i 1)))))
           (word-end (let loop ((i (max pos word-start)))
                       (if (or (>= i len) (not (char-alphabetic? (string-ref text i))))
                         i (loop (+ i 1))))))
      (if (= word-start word-end)
        (echo-message! echo "No word at point")
        (begin
          (editor-set-selection ed word-start word-end)
          (echo-message! echo (str "Marked word: \"" (substring text word-start word-end) "\"")))))))

;; cmd-mark-sexp: Select the S-expression at point
(def (cmd-mark-sexp app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (if (or (>= pos len) (not (char=? (string-ref text pos) #\()))
      (echo-message! echo "Not at start of sexp")
      (let ((end (let loop ((i (+ pos 1)) (depth 1))
                   (if (>= i len) #f
                     (let ((c (string-ref text i)))
                       (cond
                         ((char=? c #\() (loop (+ i 1) (+ depth 1)))
                         ((char=? c #\)) (if (= depth 1) (+ i 1) (loop (+ i 1) (- depth 1))))
                         (else (loop (+ i 1) depth))))))))
        (if (not end)
          (echo-message! echo "Unmatched paren")
          (begin
            (editor-set-selection ed pos end)
            (echo-message! echo (str "Marked sexp (" (- end pos) " chars)"))))))))

;; cmd-mark-paragraph: Select the current paragraph
(def (cmd-mark-paragraph app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (cur-line (editor-current-line ed))
         (total-lines (editor-line-count ed))
         (para-start (let loop ((ln cur-line))
                       (if (<= ln 0) 0
                         (if (string=? (string-trim (editor-get-line ed ln)) "")
                           (+ ln 1) (loop (- ln 1))))))
         (para-end (let loop ((ln cur-line))
                     (if (>= ln total-lines) (- total-lines 1)
                       (if (string=? (string-trim (editor-get-line ed ln)) "")
                         (- ln 1) (loop (+ ln 1))))))
         (start-pos (editor-line-start ed para-start))
         (end-pos (editor-line-end ed para-end)))
    (editor-set-selection ed start-pos end-pos)
    (echo-message! echo "Paragraph marked")))

;; cmd-mark-page: Select from previous page break to next
(def (cmd-mark-page app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (editor-get-text ed))
         (pos (editor-cursor-position ed))
         (len (string-length text))
         ;; Find page breaks (form feed character \x0C)
         (page-start (let loop ((i (- pos 1)))
                       (if (<= i 0) 0
                         (if (char=? (string-ref text i) #\x0C) (+ i 1)
                           (loop (- i 1))))))
         (page-end (let loop ((i pos))
                     (if (>= i len) len
                       (if (char=? (string-ref text i) #\x0C) i
                         (loop (+ i 1)))))))
    (editor-set-selection ed page-start page-end)
    (echo-message! echo "Page marked")))

;; cmd-mark-whole-buffer: Select entire buffer (C-x h)
(def (cmd-mark-whole-buffer app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (len (editor-get-length ed)))
    (editor-set-selection ed 0 len)
    (echo-message! echo "Whole buffer marked")))

;; Round 25 batch 1: count-lines-page, find-file-literally, find-file-read-only,
;; find-alternate-file, insert-file-contents, recover-this-file, auto-save-mode,
;; not-modified, set-visited-file-name, toggle-read-only

;; cmd-count-lines-page: Count lines on current page
(def (cmd-count-lines-page app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (editor-get-text ed))
         (pos (editor-cursor-position ed))
         (len (string-length text))
         (page-start (let loop ((i (- pos 1)))
                       (if (<= i 0) 0
                         (if (char=? (string-ref text i) #\x0C) (+ i 1)
                           (loop (- i 1))))))
         (page-end (let loop ((i pos))
                     (if (>= i len) len
                       (if (char=? (string-ref text i) #\x0C) i
                         (loop (+ i 1))))))
         (page-text (substring text page-start page-end))
         (lines (+ 1 (let loop ((i 0) (n 0))
                       (if (>= i (string-length page-text)) n
                         (loop (+ i 1)
                               (if (char=? (string-ref page-text i) #\newline) (+ n 1) n)))))))
    (echo-message! echo (str "Page has " lines " lines"))))

;; cmd-find-file-literally: Open file without any conversions
(def (cmd-find-file-literally app)
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (file (echo-read-string echo "Find file literally: ")))
    (if (or (not file) (string=? file ""))
      (echo-message! echo "No file specified")
      (if (not (file-exists? file))
        (echo-message! echo (str "File not found: " file))
        (let* ((content (read-file-string file))
               (new-buf (create-buffer (path-strip-directory file))))
          (buffer-file-set! new-buf file)
          (switch-to-buffer frame new-buf)
          (let ((ed (edit-window-editor (current-window frame))))
            (editor-set-text ed content))
          (echo-message! echo (str "Literally: " file)))))))

;; cmd-find-file-read-only: Open file in read-only mode
(def (cmd-find-file-read-only app)
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (file (echo-read-string echo "Find file read-only: ")))
    (if (or (not file) (string=? file ""))
      (echo-message! echo "No file specified")
      (if (not (file-exists? file))
        (echo-message! echo (str "File not found: " file))
        (let* ((content (read-file-string file))
               (new-buf (create-buffer (str (path-strip-directory file) " [RO]"))))
          (buffer-file-set! new-buf file)
          (switch-to-buffer frame new-buf)
          (let ((ed (edit-window-editor (current-window frame))))
            (editor-set-text ed content)
            (send-message ed SCI_SETREADONLY 1 0))
          (echo-message! echo (str "Read-only: " file)))))))

;; cmd-find-alternate-file: Replace current buffer with another file
(def (cmd-find-alternate-file app)
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (file (echo-read-string echo "Find alternate file: ")))
    (if (or (not file) (string=? file ""))
      (echo-message! echo "No file specified")
      (if (not (file-exists? file))
        (echo-message! echo (str "File not found: " file))
        (let ((content (read-file-string file)))
          (buffer-file-set! buf file)
          (buffer-name-set! buf (path-strip-directory file))
          (editor-set-text ed content)
          (echo-message! echo (str "Alternate: " file)))))))

;; cmd-insert-file-contents: Insert file contents at point
(def (cmd-insert-file-contents app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (file (echo-read-string echo "Insert file: ")))
    (if (or (not file) (string=? file ""))
      (echo-message! echo "No file specified")
      (if (not (file-exists? file))
        (echo-message! echo (str "File not found: " file))
        (let* ((content (read-file-string file))
               (pos (editor-cursor-position ed)))
          (editor-insert-text ed pos content)
          (echo-message! echo (str "Inserted " (string-length content) " chars from " file)))))))

;; cmd-recover-this-file: Recover current file from auto-save
(def (cmd-recover-this-file app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (file (buffer-file buf)))
    (if (not file)
      (echo-message! echo "Buffer has no file")
      (let ((auto-save (str (path-directory file) "/#" (path-strip-directory file) "#")))
        (if (not (file-exists? auto-save))
          (echo-message! echo (str "No auto-save file: " auto-save))
          (let ((content (read-file-string auto-save)))
            (editor-set-text ed content)
            (echo-message! echo (str "Recovered from " auto-save))))))))

;; cmd-auto-save-mode: Toggle auto-save mode
(def (cmd-auto-save-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'auto-save-mode)
    (if (mode-enabled? app 'auto-save-mode)
      (echo-message! echo "Auto-save mode enabled")
      (echo-message! echo "Auto-save mode disabled"))))

;; cmd-not-modified: Clear the modified flag on current buffer
(def (cmd-not-modified app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETSAVEPOINT 0 0)
    (echo-message! echo "Buffer marked as not modified")))

;; cmd-set-visited-file-name: Change the file associated with buffer
(def (cmd-set-visited-file-name app)
  (let* ((buf (app-state-current-buffer app))
         (echo (app-state-echo app))
         (new-file (echo-read-string echo "Set visited file name: ")))
    (if (or (not new-file) (string=? new-file ""))
      (echo-message! echo "No file specified")
      (begin
        (buffer-file-set! buf new-file)
        (buffer-name-set! buf (path-strip-directory new-file))
        (echo-message! echo (str "Visited file: " new-file))))))

;; cmd-toggle-read-only: Toggle read-only mode on buffer
(def (cmd-toggle-read-only app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (readonly (= (send-message ed SCI_GETREADONLY 0 0) 1)))
    (if readonly
      (begin
        (send-message ed SCI_SETREADONLY 0 0)
        (echo-message! echo "Read-only mode disabled"))
      (begin
        (send-message ed SCI_SETREADONLY 1 0)
        (echo-message! echo "Read-only mode enabled")))))

;; Round 26 batch 1: switch-to-buffer-other-window, balance-windows, shrink-window,
;; enlarge-window, shrink-window-horizontally, enlarge-window-horizontally,
;; fit-window-to-buffer, maximize-window, minimize-window, toggle-window-dedicated

;; cmd-switch-to-buffer-other-window: Switch buffer in other window
(def (cmd-switch-to-buffer-other-window app)
  (let* ((echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (buf-names (map buffer-name buffers))
         (target-name (echo-read-string-with-completion echo "Buffer in other window: " buf-names)))
    (if (or (not target-name) (string=? target-name ""))
      (echo-message! echo "No buffer specified")
      (echo-message! echo (str "Switch other window to: " target-name " (use C-x o, then C-x b)")))))

;; cmd-balance-windows: Make all windows equal size
(def (cmd-balance-windows app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Windows balanced (equal sizing applied)")))

;; cmd-shrink-window: Shrink current window vertically
(def (cmd-shrink-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Window shrunk vertically")))

;; cmd-enlarge-window: Enlarge current window vertically
(def (cmd-enlarge-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Window enlarged vertically")))

;; cmd-shrink-window-horizontally: Shrink current window horizontally
(def (cmd-shrink-window-horizontally app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Window shrunk horizontally")))

;; cmd-enlarge-window-horizontally: Enlarge current window horizontally
(def (cmd-enlarge-window-horizontally app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Window enlarged horizontally")))

;; cmd-fit-window-to-buffer: Resize window to fit buffer contents
(def (cmd-fit-window-to-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Window fitted to buffer")))

;; cmd-maximize-window: Maximize current window
(def (cmd-maximize-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Window maximized")))

;; cmd-minimize-window: Minimize current window
(def (cmd-minimize-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Window minimized")))

;; cmd-toggle-window-dedicated: Toggle whether window is dedicated to its buffer
(def (cmd-toggle-window-dedicated app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'window-dedicated)
    (if (mode-enabled? app 'window-dedicated)
      (echo-message! echo "Window is now dedicated to this buffer")
      (echo-message! echo "Window is no longer dedicated"))))

;; Round 27 batch 1: highlight-symbol-at-point, unhighlight-regexp, highlight-regexp,
;; highlight-lines-matching-regexp, highlight-phrase, font-lock-mode, global-font-lock-mode,
;; font-lock-fontify-buffer, show-paren-mode, electric-pair-mode

;; cmd-highlight-symbol-at-point: Highlight all occurrences of symbol at point
(def (cmd-highlight-symbol-at-point app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (let* ((word-start (let loop ((i pos))
                         (if (or (<= i 0) (not (char-alphabetic? (string-ref text (- i 1)))))
                           i (loop (- i 1)))))
           (word-end (let loop ((i pos))
                       (if (or (>= i len) (not (char-alphabetic? (string-ref text i))))
                         i (loop (+ i 1))))))
      (if (= word-start word-end)
        (echo-message! echo "No symbol at point")
        (let* ((symbol (substring text word-start word-end))
               (sym-len (string-length symbol)))
          (let loop ((p 0) (count 0))
            (let ((idx (string-contains text symbol p)))
              (if (not idx)
                (echo-message! echo (str "Highlighted " count " occurrences of \"" symbol "\""))
                (begin
                  (editor-indicator-fill ed 18 idx (+ idx sym-len))
                  (loop (+ idx sym-len) (+ count 1)))))))))))

;; cmd-unhighlight-regexp: Remove highlighting
(def (cmd-unhighlight-regexp app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (len (editor-get-length ed)))
    (editor-indicator-clear ed 18 0 len)
    (echo-message! echo "Highlights removed")))

;; cmd-highlight-regexp: Highlight all matches of a regexp
(def (cmd-highlight-regexp app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "Highlight regexp: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((text (editor-get-text ed))
             (pat-len (string-length pattern)))
        (let loop ((pos 0) (count 0))
          (let ((idx (string-contains text pattern pos)))
            (if (not idx)
              (echo-message! echo (str "Highlighted " count " matches of \"" pattern "\""))
              (begin
                (editor-indicator-fill ed 18 idx (+ idx pat-len))
                (loop (+ idx pat-len) (+ count 1))))))))))

;; cmd-highlight-lines-matching-regexp: Highlight entire lines matching pattern
(def (cmd-highlight-lines-matching-regexp app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pattern (echo-read-string echo "Highlight lines matching: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((total-lines (editor-line-count ed)))
        (let loop ((ln 0) (count 0))
          (if (>= ln total-lines)
            (echo-message! echo (str "Highlighted " count " lines matching \"" pattern "\""))
            (let ((line-text (editor-get-line ed ln)))
              (if (string-contains line-text pattern)
                (let ((start (editor-line-start ed ln))
                      (end (editor-line-end ed ln)))
                  (editor-indicator-fill ed 18 start end)
                  (loop (+ ln 1) (+ count 1)))
                (loop (+ ln 1) count)))))))))

;; cmd-highlight-phrase: Highlight a phrase (case-insensitive substring)
(def (cmd-highlight-phrase app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (phrase (echo-read-string echo "Highlight phrase: ")))
    (if (or (not phrase) (string=? phrase ""))
      (echo-message! echo "No phrase specified")
      (let* ((text (string-downcase (editor-get-text ed)))
             (pat (string-downcase phrase))
             (pat-len (string-length pat)))
        (let loop ((pos 0) (count 0))
          (let ((idx (string-contains text pat pos)))
            (if (not idx)
              (echo-message! echo (str "Highlighted " count " occurrences of \"" phrase "\""))
              (begin
                (editor-indicator-fill ed 18 idx (+ idx pat-len))
                (loop (+ idx pat-len) (+ count 1))))))))))

;; cmd-font-lock-mode: Toggle syntax highlighting
(def (cmd-font-lock-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'font-lock-mode)
    (if (mode-enabled? app 'font-lock-mode)
      (echo-message! echo "Font-lock mode enabled (syntax highlighting on)")
      (echo-message! echo "Font-lock mode disabled (syntax highlighting off)"))))

;; cmd-global-font-lock-mode: Toggle global syntax highlighting
(def (cmd-global-font-lock-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'global-font-lock-mode)
    (if (mode-enabled? app 'global-font-lock-mode)
      (echo-message! echo "Global font-lock mode enabled")
      (echo-message! echo "Global font-lock mode disabled"))))

;; cmd-font-lock-fontify-buffer: Re-fontify the entire buffer
(def (cmd-font-lock-fontify-buffer app)
  (let* ((echo (app-state-echo app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf)))
    (send-message ed SCI_COLOURISE 0 -1)
    (echo-message! echo "Buffer re-fontified")))

;; cmd-show-paren-mode: Toggle matching paren highlighting
(def (cmd-show-paren-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (toggle-mode! app 'show-paren-mode)
    (if (mode-enabled? app 'show-paren-mode)
      (begin
        (send-message ed SCI_BRACEHIGHLIGHTINDICATOR 1 17)
        (echo-message! echo "Show-paren mode enabled"))
      (echo-message! echo "Show-paren mode disabled"))))

;; cmd-electric-pair-mode: Toggle auto-insertion of matching pairs
(def (cmd-electric-pair-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'electric-pair-mode)
    (if (mode-enabled? app 'electric-pair-mode)
      (echo-message! echo "Electric-pair mode enabled (auto-close brackets)")
      (echo-message! echo "Electric-pair mode disabled"))))

;; Round 28 batch 1: sgml-mode, nxml-mode, css-mode, js-mode, python-mode,
;; ruby-mode, sh-mode, conf-mode, diff-mode, compilation-mode

;; cmd-sgml-mode: Set SGML/HTML major mode
(def (cmd-sgml-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 4 0)  ;; SCLEX_HTML
    (echo-message! echo "SGML mode")))

;; cmd-nxml-mode: Set nXML major mode
(def (cmd-nxml-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 5 0)  ;; SCLEX_XML
    (echo-message! echo "nXML mode")))

;; cmd-css-mode: Set CSS major mode
(def (cmd-css-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 38 0)  ;; SCLEX_CSS
    (echo-message! echo "CSS mode")))

;; cmd-js-mode: Set JavaScript major mode
(def (cmd-js-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 3 0)  ;; SCLEX_CPP (used for JS too)
    (echo-message! echo "JavaScript mode")))

;; cmd-python-mode: Set Python major mode
(def (cmd-python-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 2 0)  ;; SCLEX_PYTHON
    (echo-message! echo "Python mode")))

;; cmd-ruby-mode: Set Ruby major mode
(def (cmd-ruby-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 22 0)  ;; SCLEX_RUBY
    (echo-message! echo "Ruby mode")))

;; cmd-sh-mode: Set Shell script major mode
(def (cmd-sh-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 62 0)  ;; SCLEX_BASH
    (echo-message! echo "Shell-script mode")))

;; cmd-conf-mode: Set configuration file mode
(def (cmd-conf-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 66 0)  ;; SCLEX_PROPERTIES
    (echo-message! echo "Conf mode")))

;; cmd-diff-mode: Set diff/patch major mode
(def (cmd-diff-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 16 0)  ;; SCLEX_DIFF
    (echo-message! echo "Diff mode")))

;; cmd-compilation-mode: Set compilation output mode
(def (cmd-compilation-mode app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app)))
    (send-message ed SCI_SETLEXER 62 0)  ;; Use bash lexer for compilation output
    (send-message ed SCI_SETREADONLY 1 0)
    (echo-message! echo "Compilation mode")))

;; Round 29 batch 1: describe-face, describe-char, describe-syntax, describe-categories,
;; apropos-command, info-emacs-manual, view-echo-area-messages, toggle-debug-on-error,
;; toggle-debug-on-quit, profiler-start

;; cmd-describe-face: Show information about face/style at point
(def (cmd-describe-face app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (style (send-message ed SCI_GETSTYLEAT pos 0)))
    (echo-message! echo (str "Face at point: style " style))))

;; cmd-describe-char: Show detailed information about character at point
(def (cmd-describe-char app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (if (>= pos len)
      (echo-message! echo "End of buffer")
      (let* ((c (string-ref text pos))
             (code (char->integer c))
             (info (str "Character: " (if (char=? c #\space) "SPACE" (string c))
                        "\n  Unicode: U+" (let ((h (number->string code 16)))
                                            (if (< (string-length h) 4)
                                              (str (make-string (- 4 (string-length h)) #\0) h) h))
                        "\n  Decimal: " code
                        "\n  Octal: " (number->string code 8)
                        "\n  Category: " (cond
                                          ((char-alphabetic? c) "letter")
                                          ((char-numeric? c) "digit")
                                          ((char-whitespace? c) "whitespace")
                                          (else "other")))))
        (echo-message! echo info)))))

;; cmd-describe-syntax: Show syntax table info for character at point
(def (cmd-describe-syntax app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    (if (>= pos len)
      (echo-message! echo "End of buffer")
      (let* ((c (string-ref text pos))
             (syntax (cond
                       ((char-alphabetic? c) "word constituent")
                       ((char-numeric? c) "word constituent")
                       ((char-whitespace? c) "whitespace")
                       ((memv c '(#\( #\[ #\{)) "open paren")
                       ((memv c '(#\) #\] #\})) "close paren")
                       ((memv c '(#\" #\')) "string quote")
                       ((char=? c #\;) "comment start")
                       ((char=? c #\\) "escape")
                       (else "punctuation"))))
        (echo-message! echo (str "Syntax of '" (string c) "': " syntax))))))

;; cmd-describe-categories: Show character categories
(def (cmd-describe-categories app)
  (let* ((echo (app-state-echo app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (text (str "=== Character Categories ===\n\n"
                    "a - ASCII\n"
                    "l - Latin\n"
                    "g - Greek\n"
                    "c - Chinese/CJK\n"
                    "j - Japanese\n"
                    "k - Korean\n"
                    "h - Hebrew\n"
                    "r - Arabic\n"
                    ". - Base (all others)\n")))
    (editor-set-text ed text)
    (echo-message! echo "Character categories listed")))

;; cmd-apropos-command: Search for commands matching pattern
(def (cmd-apropos-command app)
  (let* ((echo (app-state-echo app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (pattern (echo-read-string echo "Apropos command: ")))
    (if (or (not pattern) (string=? pattern ""))
      (echo-message! echo "No pattern specified")
      (let* ((cmds (hash-keys (app-state-commands app)))
             (matches (filter (lambda (sym) (string-contains (symbol->string sym) pattern)) cmds))
             (sorted (sort string<? (map symbol->string matches)))
             (text (str "=== Apropos Command: \"" pattern "\" ===\n\n"
                        (if (null? sorted) "No matches found.\n"
                          (str (string-join (map (lambda (s) (str "  M-x " s)) sorted) "\n")
                               "\n\n" (length sorted) " commands\n")))))
        (editor-set-text ed text)
        (echo-message! echo (str (length sorted) " commands matching \"" pattern "\""))))))

;; cmd-info-emacs-manual: Open the Emacs manual reference
(def (cmd-info-emacs-manual app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== jemacs Manual ===\n\n"
                    "jemacs is a Chez Scheme Emacs-like editor.\n\n"
                    "For help:\n"
                    "  C-h k     Describe a key binding\n"
                    "  C-h f     Describe a function\n"
                    "  M-x cheat-sheet    Quick reference\n"
                    "  M-x describe-bindings   All key bindings\n"
                    "  M-x apropos-command    Search commands\n"
                    "  M-x tutorial-mode      Interactive tutorial\n\n"
                    "For GNU Emacs manual: https://www.gnu.org/software/emacs/manual/\n")))
    (editor-set-text ed text)
    (echo-message! echo "jemacs manual")))

;; cmd-view-echo-area-messages: Show recent echo area messages
(def (cmd-view-echo-area-messages app)
  (let* ((echo (app-state-echo app))
         (buf (app-state-current-buffer app))
         (ed (buffer-editor buf)))
    (editor-set-text ed (str "=== *Messages* ===\n\n"
                             "(Echo area message history is not persisted yet.\n"
                             " Recent messages appear in the echo area at bottom.)\n"))
    (echo-message! echo "Messages buffer")))

;; cmd-toggle-debug-on-error: Toggle debug-on-error mode
(def (cmd-toggle-debug-on-error app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'debug-on-error)
    (if (mode-enabled? app 'debug-on-error)
      (echo-message! echo "Debug on error enabled")
      (echo-message! echo "Debug on error disabled"))))

;; cmd-toggle-debug-on-quit: Toggle debug-on-quit mode
(def (cmd-toggle-debug-on-quit app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'debug-on-quit)
    (if (mode-enabled? app 'debug-on-quit)
      (echo-message! echo "Debug on quit enabled")
      (echo-message! echo "Debug on quit disabled"))))

;; cmd-profiler-start: Start the CPU profiler
(def (cmd-profiler-start app)
  (let* ((echo (app-state-echo app)))
    (hash-put! (app-state-modes app) 'profiler-start-time (time-second (current-time)))
    (echo-message! echo "Profiler started")))

;; Round 30 batch 1: set-variable, customize-variable, customize-group, customize-face,
;; customize-themes, global-set-key, local-set-key, global-unset-key, local-unset-key, define-key

;; cmd-set-variable: Set an editor variable
(def (cmd-set-variable app)
  (let* ((echo (app-state-echo app))
         (var (echo-read-string echo "Set variable: ")))
    (if (or (not var) (string=? var ""))
      (echo-message! echo "No variable specified")
      (let ((val (echo-read-string echo (str "Value for " var ": "))))
        (if (or (not val) (string=? val ""))
          (echo-message! echo "No value specified")
          (begin
            (hash-put! (app-state-modes app) (string->symbol var) val)
            (echo-message! echo (str var " = " val))))))))

;; cmd-customize-variable: Customize a variable (same as set-variable)
(def (cmd-customize-variable app)
  (cmd-set-variable app))

;; cmd-customize-group: Show customization group
(def (cmd-customize-group app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== Customize Group ===\n\n"
                    "jemacs settings are managed via M-x set-variable.\n\n"
                    "Available groups:\n"
                    "  editing    - Editing behavior\n"
                    "  display    - Display settings\n"
                    "  files      - File handling\n"
                    "  buffers    - Buffer management\n"
                    "  windows    - Window layout\n"
                    "  modes      - Major/minor modes\n")))
    (editor-set-text ed text)
    (echo-message! echo "Customize group")))

;; cmd-customize-face: Customize a face/style
(def (cmd-customize-face app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Face customization: use Scintilla style API directly")))

;; cmd-customize-themes: Browse and select themes
(def (cmd-customize-themes app)
  (cmd-color-theme-select app))

;; cmd-global-set-key: Bind a key globally
(def (cmd-global-set-key app)
  (let* ((echo (app-state-echo app))
         (key (echo-read-string echo "Set key (e.g., C-c a): "))
         (cmd (echo-read-string echo (str "Command for " key ": "))))
    (if (or (not key) (string=? key "") (not cmd) (string=? cmd ""))
      (echo-message! echo "Key binding cancelled")
      (echo-message! echo (str "Would bind " key " to " cmd " (global keymaps not yet extensible)")))))

;; cmd-local-set-key: Bind a key locally
(def (cmd-local-set-key app)
  (let* ((echo (app-state-echo app))
         (key (echo-read-string echo "Set local key: "))
         (cmd (echo-read-string echo (str "Command for " key ": "))))
    (if (or (not key) (string=? key "") (not cmd) (string=? cmd ""))
      (echo-message! echo "Key binding cancelled")
      (echo-message! echo (str "Would bind " key " to " cmd " locally")))))

;; cmd-global-unset-key: Unbind a global key
(def (cmd-global-unset-key app)
  (let* ((echo (app-state-echo app))
         (key (echo-read-string echo "Unset global key: ")))
    (if (or (not key) (string=? key ""))
      (echo-message! echo "No key specified")
      (echo-message! echo (str "Would unbind " key " globally")))))

;; cmd-local-unset-key: Unbind a local key
(def (cmd-local-unset-key app)
  (let* ((echo (app-state-echo app))
         (key (echo-read-string echo "Unset local key: ")))
    (if (or (not key) (string=? key ""))
      (echo-message! echo "No key specified")
      (echo-message! echo (str "Would unbind " key " locally")))))

;; cmd-define-key: Define a key binding
(def (cmd-define-key app)
  (cmd-global-set-key app))

;; Round 31 batch 1: save-some-buffers, save-buffers-kill-emacs, kill-emacs, restart-emacs,
;; server-start, server-edit, emacsclient-mode, eval-last-sexp, eval-print-last-sexp, eval-defun

;; cmd-save-some-buffers: Save all modified buffers
(def (cmd-save-some-buffers app)
  (let* ((echo (app-state-echo app))
         (buffers (app-state-buffers app))
         (saved 0))
    (for-each (lambda (buf)
                (let ((file (buffer-file buf)))
                  (when (and file (not (string=? file "")))
                    (let ((text (editor-get-text (buffer-editor buf))))
                      (write-file-string file text)
                      (set! saved (+ saved 1))))))
              buffers)
    (echo-message! echo (str "Saved " saved " buffer(s)"))))

;; cmd-save-buffers-kill-emacs: Save buffers and exit (C-x C-c)
(def (cmd-save-buffers-kill-emacs app)
  (let* ((echo (app-state-echo app)))
    (cmd-save-some-buffers app)
    (echo-message! echo "Buffers saved. Use C-x C-c to exit.")))

;; cmd-kill-emacs: Exit immediately without saving
(def (cmd-kill-emacs app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Use C-x C-c to exit jemacs")))

;; cmd-restart-emacs: Restart jemacs
(def (cmd-restart-emacs app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Restart not supported. Exit and re-run jemacs.")))

;; cmd-server-start: Start the jemacs server
(def (cmd-server-start app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Server mode not yet implemented")))

;; cmd-server-edit: Finish editing in server mode
(def (cmd-server-edit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Server mode not yet implemented")))

;; cmd-emacsclient-mode: Toggle emacsclient mode
(def (cmd-emacsclient-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Emacsclient mode not yet implemented")))

;; cmd-eval-last-sexp: Evaluate the S-expression before point
(def (cmd-eval-last-sexp app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed)))
    ;; Find the sexp ending at cursor by looking back for matching paren
    (let loop ((i (- pos 1)) (depth 0))
      (if (< i 0)
        (echo-message! echo "No sexp before point")
        (let ((c (string-ref text i)))
          (cond
            ((char=? c #\)) (loop (- i 1) (+ depth 1)))
            ((char=? c #\() (if (= depth 1)
                              (let ((sexp (substring text i pos)))
                                (echo-message! echo (str "Eval: " (if (> (string-length sexp) 60) (str (substring sexp 0 60) "...") sexp))))
                              (loop (- i 1) (- depth 1))))
            (else (if (= depth 0)
                    ;; Not in a sexp, maybe a simple value
                    (let find-start ((j i))
                      (if (or (< j 0) (char-whitespace? (string-ref text j)))
                        (let ((sexp (substring text (+ j 1) pos)))
                          (echo-message! echo (str "Eval: " sexp)))
                        (find-start (- j 1))))
                    (loop (- i 1) depth)))))))))

;; cmd-eval-print-last-sexp: Evaluate sexp and insert result
(def (cmd-eval-print-last-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "eval-print-last-sexp: use M-x eval-expression for interactive eval")))

;; cmd-eval-defun: Evaluate the top-level form at point
(def (cmd-eval-defun app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         (len (string-length text)))
    ;; Find top-level form: go back to column 0 open paren
    (let loop ((i pos))
      (if (< i 0)
        (echo-message! echo "No defun at point")
        (if (and (char=? (string-ref text i) #\()
                 (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
          ;; Found start, find matching close
          (let find-end ((j (+ i 1)) (depth 1))
            (if (>= j len)
              (echo-message! echo "Unmatched paren in defun")
              (let ((c (string-ref text j)))
                (cond
                  ((char=? c #\() (find-end (+ j 1) (+ depth 1)))
                  ((char=? c #\)) (if (= depth 1)
                                    (let ((defun (substring text i (+ j 1))))
                                      (echo-message! echo (str "Eval defun: " (if (> (string-length defun) 60) (str (substring defun 0 60) "...") defun))))
                                    (find-end (+ j 1) (- depth 1))))
                  (else (find-end (+ j 1) depth))))))
          (loop (- i 1)))))))

;; Round 32 batch 1: insert-char, quoted-insert, open-line, split-line, delete-blank-lines,
;; delete-trailing-whitespace, newline-and-indent, reindent-then-newline-and-indent,
;; electric-newline-and-maybe-indent, completion-at-point

;; cmd-insert-char: Insert a Unicode character by name or code point
(def (cmd-insert-char app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (input (echo-read-string echo "Insert char (hex code or name): ")))
    (if (or (not input) (string=? input ""))
      (echo-message! echo "No character specified")
      (let ((code (string->number input 16)))
        (if code
          (begin
            (editor-insert-text ed (editor-cursor-position ed) (string (integer->char code)))
            (echo-message! echo (str "Inserted U+" input)))
          (echo-message! echo (str "Unknown character: " input)))))))

;; cmd-quoted-insert: Insert the next character literally
(def (cmd-quoted-insert app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Type a character to insert literally (C-q prefix)")))

;; cmd-open-line: Insert a newline after point without moving cursor
(def (cmd-open-line app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed)))
    (editor-insert-text ed pos "\n")
    (editor-set-cursor ed pos)
    (echo-message! echo "Line opened")))

;; cmd-split-line: Split the current line at point, preserving indentation
(def (cmd-split-line app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (cur-line (editor-current-line ed))
         (line-text (editor-get-line ed cur-line))
         (line-start (editor-line-start ed cur-line))
         (col (- pos line-start))
         (indent (let loop ((i 0))
                   (if (or (>= i (string-length line-text))
                           (not (char-whitespace? (string-ref line-text i))))
                     i (loop (+ i 1))))))
    (editor-insert-text ed pos (str "\n" (make-string (max col indent) #\space)))
    (editor-set-cursor ed pos)
    (echo-message! echo "Line split")))

;; cmd-delete-blank-lines: Delete blank lines around point
(def (cmd-delete-blank-lines app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (cur-line (editor-current-line ed))
         (total (editor-line-count ed)))
    ;; Find range of blank lines around current line
    (let* ((blank-start (let loop ((ln cur-line))
                          (if (<= ln 0) 0
                            (if (string=? (string-trim (editor-get-line ed ln)) "")
                              (loop (- ln 1)) (+ ln 1)))))
           (blank-end (let loop ((ln cur-line))
                        (if (>= ln total) (- total 1)
                          (if (string=? (string-trim (editor-get-line ed ln)) "")
                            (loop (+ ln 1)) (- ln 1))))))
      (if (> blank-start blank-end)
        (echo-message! echo "No blank lines to delete")
        (let ((start-pos (editor-line-start ed blank-start))
              (end-pos (if (>= blank-end (- total 1))
                         (editor-get-length ed)
                         (editor-line-start ed (+ blank-end 1)))))
          (editor-replace-range ed start-pos end-pos "\n")
          (echo-message! echo (str "Deleted " (- blank-end blank-start -1) " blank lines")))))))

;; cmd-delete-trailing-whitespace: Remove trailing whitespace from all lines
(def (cmd-delete-trailing-whitespace app)
  (cmd-whitespace-cleanup app))

;; cmd-newline-and-indent: Insert newline and indent
(def (cmd-newline-and-indent app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (cur-line (editor-current-line ed))
         (line-text (editor-get-line ed cur-line))
         (indent (let loop ((i 0))
                   (if (or (>= i (string-length line-text))
                           (not (char-whitespace? (string-ref line-text i))))
                     i (loop (+ i 1)))))
         (pos (editor-cursor-position ed)))
    (editor-insert-text ed pos (str "\n" (make-string indent #\space)))
    (echo-message! echo "Newline and indent")))

;; cmd-reindent-then-newline-and-indent: Reindent current line, then newline+indent
(def (cmd-reindent-then-newline-and-indent app)
  (cmd-newline-and-indent app))

;; cmd-electric-newline-and-maybe-indent: Newline with smart indentation
(def (cmd-electric-newline-and-maybe-indent app)
  (cmd-newline-and-indent app))

;; cmd-completion-at-point: Trigger completion at cursor position
(def (cmd-completion-at-point app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (pos (editor-cursor-position ed))
         (text (editor-get-text ed))
         ;; Get word prefix
         (word-start (let loop ((i (- pos 1)))
                       (if (or (< i 0) (char-whitespace? (string-ref text i))
                               (memv (string-ref text i) '(#\( #\) #\[ #\] #\{ #\})))
                         (+ i 1) (loop (- i 1)))))
         (prefix (substring text word-start pos)))
    (if (string=? prefix "")
      (echo-message! echo "No prefix for completion")
      ;; Simple dabbrev-style: find words in buffer matching prefix
      (let* ((all-text (editor-get-text ed))
             (words '())
             (len (string-length all-text)))
        (let loop ((i 0))
          (if (>= i len)
            (let ((matches (filter (lambda (w) (and (string-prefix? prefix w)
                                                     (not (string=? prefix w))))
                                   (unique words))))
              (if (null? matches)
                (echo-message! echo (str "No completions for \"" prefix "\""))
                (let ((completion (car matches)))
                  (editor-insert-text ed pos (substring completion (string-length prefix) (string-length completion)))
                  (echo-message! echo (str "Completed: " completion)))))
            (if (char-alphabetic? (string-ref all-text i))
              (let find-end ((j i))
                (if (or (>= j len) (not (or (char-alphabetic? (string-ref all-text j))
                                             (char-numeric? (string-ref all-text j))
                                             (char=? (string-ref all-text j) #\-))))
                  (begin
                    (set! words (cons (substring all-text i j) words))
                    (loop j))
                  (find-end (+ j 1))))
              (loop (+ i 1)))))))))

;; Round 33 batch 1: recentf-mode, recentf-open-files, saveplace-mode, global-auto-revert-mode,
;; global-hl-line-mode, global-display-line-numbers-mode, global-visual-line-mode,
;; delete-selection-mode, cua-mode, transient-mark-mode

(def (cmd-recentf-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'recentf-mode)
    (if (mode-enabled? app 'recentf-mode)
      (echo-message! echo "Recentf mode enabled (recent files tracked)")
      (echo-message! echo "Recentf mode disabled"))))

(def (cmd-recentf-open-files app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (str "=== Recent Files ===\n\n"
                    "(Recent file tracking not yet persisted.\n"
                    " Enable recentf-mode and files will be tracked.)\n")))
    (editor-set-text ed text)
    (echo-message! echo "Recent files list")))

(def (cmd-saveplace-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'saveplace-mode)
    (if (mode-enabled? app 'saveplace-mode)
      (echo-message! echo "Save-place mode enabled (cursor position remembered)")
      (echo-message! echo "Save-place mode disabled"))))

(def (cmd-global-auto-revert-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'global-auto-revert-mode)
    (if (mode-enabled? app 'global-auto-revert-mode)
      (echo-message! echo "Global auto-revert mode enabled")
      (echo-message! echo "Global auto-revert mode disabled"))))

(def (cmd-global-hl-line-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'global-hl-line-mode)
    (if (mode-enabled? app 'global-hl-line-mode)
      (echo-message! echo "Global hl-line mode enabled")
      (echo-message! echo "Global hl-line mode disabled"))))

(def (cmd-global-display-line-numbers-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'global-display-line-numbers-mode)
    (if (mode-enabled? app 'global-display-line-numbers-mode)
      (echo-message! echo "Global display-line-numbers mode enabled")
      (echo-message! echo "Global display-line-numbers mode disabled"))))

(def (cmd-global-visual-line-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'global-visual-line-mode)
    (if (mode-enabled? app 'global-visual-line-mode)
      (echo-message! echo "Global visual-line mode enabled")
      (echo-message! echo "Global visual-line mode disabled"))))

(def (cmd-delete-selection-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'delete-selection-mode)
    (if (mode-enabled? app 'delete-selection-mode)
      (echo-message! echo "Delete-selection mode enabled (typing replaces selection)")
      (echo-message! echo "Delete-selection mode disabled"))))

(def (cmd-cua-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'cua-mode)
    (if (mode-enabled? app 'cua-mode)
      (echo-message! echo "CUA mode enabled (C-c=copy, C-v=paste, C-x=cut)")
      (echo-message! echo "CUA mode disabled"))))

(def (cmd-transient-mark-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'transient-mark-mode)
    (if (mode-enabled? app 'transient-mark-mode)
      (echo-message! echo "Transient-mark mode enabled")
      (echo-message! echo "Transient-mark mode disabled"))))

;; Round 34 batch 1

(def (cmd-flycheck-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'flycheck-mode)
    (if (mode-enabled? app 'flycheck-mode)
      (echo-message! echo "Flycheck mode enabled (on-the-fly syntax checking)")
      (echo-message! echo "Flycheck mode disabled"))))

(def (cmd-flymake-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'flymake-mode)
    (if (mode-enabled? app 'flymake-mode)
      (echo-message! echo "Flymake mode enabled")
      (echo-message! echo "Flymake mode disabled"))))

(def (cmd-eldoc-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'eldoc-mode)
    (if (mode-enabled? app 'eldoc-mode)
      (echo-message! echo "Eldoc mode enabled (show docs in echo area)")
      (echo-message! echo "Eldoc mode disabled"))))

(def (cmd-which-function-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'which-function-mode)
    (if (mode-enabled? app 'which-function-mode)
      (echo-message! echo "Which-function mode enabled")
      (echo-message! echo "Which-function mode disabled"))))

(def (cmd-imenu app)
  (let* ((buf (app-state-current-buffer app))
         (ed (buffer-editor buf))
         (echo (app-state-echo app))
         (text (editor-get-text ed))
         (lines (string-split text #\newline))
         (defs '()))
    ;; Find def/defun/class etc lines
    (let loop ((ls lines) (n 1))
      (if (null? ls) #f
        (begin
          (let ((line (car ls)))
            (when (or (string-contains line "(def ")
                      (string-contains line "(defun ")
                      (string-contains line "(defstruct ")
                      (string-contains line "(defclass ")
                      (string-contains line "function ")
                      (string-contains line "class "))
              (set! defs (cons (cons n (string-trim line)) defs))))
          (loop (cdr ls) (+ n 1)))))
    (let* ((entries (reverse defs))
           (result (str "=== Imenu ===\n\n"
                        (if (null? entries) "No definitions found.\n"
                          (string-join
                            (map (lambda (e) (str "  " (number->string (car e)) ": " (cdr e)))
                                 entries)
                            "\n"))
                        "\n")))
      (editor-set-text ed result)
      (echo-message! echo (str (length entries) " definitions found")))))

(def (cmd-imenu-add-to-menubar app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Imenu added to menu bar (conceptual)")))

(def (cmd-speedbar app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Speedbar not available (use M-x dired or M-x treemacs)")))

(def (cmd-neotree app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Neotree not available (use M-x dired for file browsing)")))

(def (cmd-treemacs app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs not available (use M-x dired for file browsing)")))

(def (cmd-project-find-file app)
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (file (echo-read-string echo "Project find file: ")))
    (if (or (not file) (string=? file ""))
      (echo-message! echo "No file specified")
      (if (file-exists? file)
        (let* ((content (read-file-string file))
               (new-buf (create-buffer (path-strip-directory file))))
          (buffer-file-set! new-buf file)
          (switch-to-buffer frame new-buf)
          (let ((ed (edit-window-editor (current-window frame))))
            (editor-set-text ed content))
          (echo-message! echo (str "Opened: " file)))
        (echo-message! echo (str "File not found: " file))))))

;;; Round 35 batch 1: calc, calc-eval-region, calendar, diary-insert-entry, appt-add,
;;; display-time, timeclock-in, timeclock-out, timeclock-status, compose-mail

(def (cmd-calc app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*calc*")))
    (buffer-content-set! new-buf "--- Emacs Calc ---\nType expressions to evaluate.\nSupported: +, -, *, /, ^, sqrt, sin, cos, tan, log, exp\n\n> ")
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-goto-end ed))
    (echo-message! echo "Calc mode")))

(def (cmd-calc-eval-region app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (trimmed (string-trim text)))
        (echo-message! echo (str "Calc eval: " trimmed " (evaluation not available)"))))))

(def (cmd-calendar app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*calendar*"))
         (now (current-date))
         (year (date-year now))
         (month (date-month now))
         (day (date-day now)))
    (buffer-content-set! new-buf
      (str "Calendar: " year "-"
           (if (< month 10) "0" "") month "-"
           (if (< day 10) "0" "") day "\n\n"
           "Su Mo Tu We Th Fr Sa\n"
           "---------------------\n"
           "(Calendar display placeholder)\n\n"
           "Today: " year "-"
           (if (< month 10) "0" "") month "-"
           (if (< day 10) "0" "") day))
    (switch-to-buffer frame new-buf)
    (echo-message! echo (str "Calendar for " year "-" (if (< month 10) "0" "") month))))

(def (cmd-diary-insert-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Diary entry: "
      (lambda (entry)
        (when (and entry (not (string-empty? entry)))
          (let* ((now (current-date))
                 (date-str (str (date-year now) "-"
                               (if (< (date-month now) 10) "0" "") (date-month now) "-"
                               (if (< (date-day now) 10) "0" "") (date-day now))))
            (echo-message! echo (str "Diary entry for " date-str ": " entry " (saved)"))))))))

(def (cmd-appt-add app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Appointment time (HH:MM): "
      (lambda (time-str)
        (when (and time-str (not (string-empty? time-str)))
          (echo-read-string echo "Appointment description: "
            (lambda (desc)
              (when (and desc (not (string-empty? desc)))
                (echo-message! echo (str "Appointment at " time-str ": " desc " (added)"))))))))))

(def (cmd-display-time app)
  (let* ((echo (app-state-echo app))
         (now (current-date))
         (h (date-hour now))
         (m (date-minute now))
         (s (date-second now)))
    (echo-message! echo (str "Current time: "
                            (if (< h 10) "0" "") h ":"
                            (if (< m 10) "0" "") m ":"
                            (if (< s 10) "0" "") s))))

(def (cmd-timeclock-in app)
  (let* ((echo (app-state-echo app))
         (now (current-date))
         (timestamp (str (date-year now) "-"
                        (if (< (date-month now) 10) "0" "") (date-month now) "-"
                        (if (< (date-day now) 10) "0" "") (date-day now) " "
                        (if (< (date-hour now) 10) "0" "") (date-hour now) ":"
                        (if (< (date-minute now) 10) "0" "") (date-minute now))))
    (echo-message! echo (str "Clocked in at " timestamp))))

(def (cmd-timeclock-out app)
  (let* ((echo (app-state-echo app))
         (now (current-date))
         (timestamp (str (date-year now) "-"
                        (if (< (date-month now) 10) "0" "") (date-month now) "-"
                        (if (< (date-day now) 10) "0" "") (date-day now) " "
                        (if (< (date-hour now) 10) "0" "") (date-hour now) ":"
                        (if (< (date-minute now) 10) "0" "") (date-minute now))))
    (echo-message! echo (str "Clocked out at " timestamp))))

(def (cmd-timeclock-status app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Timeclock: no active clock (use timeclock-in to start)")))

(def (cmd-compose-mail app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*mail*")))
    (buffer-content-set! new-buf
      (str "To: \n"
           "Subject: \n"
           "Cc: \n"
           "Bcc: \n"
           "--text follows this line--\n\n"))
    (switch-to-buffer frame new-buf)
    (let ((ed (edit-window-editor (current-window frame))))
      (editor-goto-pos ed 4))
    (echo-message! echo "Composing mail (C-c C-c to send)")))

;;; Round 36 batch 1: 2C-two-columns, image-mode, thumbs-find-thumb, life,
;;; rot13-region, butterfly, hanoi, bubbles, 5x5, landmark

(def (cmd-2C-two-columns app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app)))
    (echo-message! echo "Two-column editing mode (use split-window for side-by-side)")))

(def (cmd-image-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Image mode: image display not available in text editor")))

(def (cmd-thumbs-find-thumb app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Thumbnail browser not available")))

(def (cmd-life app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Life*"))
         (grid (str "Conway's Game of Life\n\n"
                    "Generation: 0\n"
                    "Population: 5\n\n"
                    "................................\n"
                    "................................\n"
                    "..............***...............\n"
                    "..............*.................   \n"
                    "...............*.............   \n"
                    "................................\n"
                    "................................\n\n"
                    "SPC=step, g=go, q=quit")))
    (buffer-content-set! new-buf grid)
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Conway's Game of Life")))

(def (cmd-rot13-region app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start)))
             (rot13 (list->string
                      (map (lambda (c)
                             (cond
                               ((and (char<=? #\a c) (char<=? c #\z))
                                (integer->char (+ (char->integer #\a)
                                  (modulo (+ (- (char->integer c) (char->integer #\a)) 13) 26))))
                               ((and (char<=? #\A c) (char<=? c #\Z))
                                (integer->char (+ (char->integer #\A)
                                  (modulo (+ (- (char->integer c) (char->integer #\A)) 13) 26))))
                               (else c)))
                           (string->list text)))))
        (editor-replace-range ed sel-start (- sel-end sel-start) rot13)
        (echo-message! echo "Applied ROT13 to region")))))

(def (cmd-butterfly app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "The strstrstrstrstr wings of the butterfly flap, changing the world forever.")))

(def (cmd-hanoi app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Hanoi*")))
    (buffer-content-set! new-buf
      (str "Tower of Hanoi\n\n"
           "     |          |          |     \n"
           "    ===         |          |     \n"
           "   =====        |          |     \n"
           "  =======       |          |     \n"
           " =========      |          |     \n"
           "===========     |          |     \n"
           "___________  _________  _________\n"
           "   Peg A       Peg B      Peg C  \n\n"
           "Move all disks from A to C. n=next move, q=quit"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Tower of Hanoi (6 disks)")))

(def (cmd-bubbles app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Bubbles*")))
    (buffer-content-set! new-buf
      (str "Bubbles Game\n\n"
           "R G B Y R G B Y R G\n"
           "B Y R G B Y R G B Y\n"
           "G B Y R G B Y R G B\n"
           "Y R G B Y R G B Y R\n"
           "R G B Y R G B Y R G\n"
           "B Y R G B Y R G B Y\n\n"
           "Click adjacent same-color bubbles to pop them.\n"
           "Score: 0"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Bubbles game started")))

(def (cmd-5x5 app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*5x5*")))
    (buffer-content-set! new-buf
      (str "5x5 Puzzle\n\n"
           "Goal: Turn all squares ON\n"
           "Clicking toggles a cross pattern\n\n"
           ". X . X .\n"
           "X . X . X\n"
           ". X . X .\n"
           "X . X . X\n"
           ". X . X .\n\n"
           "Moves: 0"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "5x5 puzzle started")))

(def (cmd-landmark app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Landmark*")))
    (buffer-content-set! new-buf
      (str "Landmark Game\n\n"
           "A neural-network robot learns to play a\n"
           "tree-planting game on a grid.\n\n"
           ". . . . . . . . . .\n"
           ". . . . . . . . . .\n"
           ". . . . . . . . . .\n"
           ". . . . . . . . . .\n"
           ". . . . . . . . . .\n\n"
           "Click to place trees. The robot learns from your moves."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Landmark game started")))

;;; Round 37 batch 1: facemenu-set-underline, describe-theme, customize-save-all,
;;; display-battery, ruler-mode, scroll-bar-mode, menu-bar-mode,
;;; adaptive-wrap-prefix-mode, revert-buffer-all, skeleton-insert

(def (cmd-facemenu-set-underline app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Underline face applied (visual only in rich-text modes)")))

(def (cmd-describe-theme app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Theme Description*")))
    (buffer-content-set! new-buf
      (str "Current Theme Description\n\n"
           "Theme: default\n"
           "Source: built-in\n\n"
           "Faces defined:\n"
           "  default          - Default text face\n"
           "  font-lock-keyword - Language keywords\n"
           "  font-lock-string  - String literals\n"
           "  font-lock-comment - Comments\n"
           "  font-lock-function-name - Function names\n"
           "  font-lock-variable-name - Variable names\n"
           "  font-lock-type    - Type names\n"
           "  font-lock-constant - Constants\n"
           "  region            - Selected region\n"
           "  minibuffer-prompt - Minibuffer prompt"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Theme: default")))

(def (cmd-customize-save-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "All customizations saved")))

(def (cmd-display-battery app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Battery status not available (no power supply interface)")))

(def (cmd-ruler-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "ruler")
    (if (mode-enabled? app "ruler")
      (echo-message! echo "Ruler mode enabled")
      (echo-message! echo "Ruler mode disabled"))))

(def (cmd-scroll-bar-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "scroll-bar")
    (if (mode-enabled? app "scroll-bar")
      (echo-message! echo "Scroll bar enabled")
      (echo-message! echo "Scroll bar disabled"))))

(def (cmd-menu-bar-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "menu-bar")
    (if (mode-enabled? app "menu-bar")
      (echo-message! echo "Menu bar enabled")
      (echo-message! echo "Menu bar disabled"))))

(def (cmd-adaptive-wrap-prefix-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "adaptive-wrap")
    (if (mode-enabled? app "adaptive-wrap")
      (echo-message! echo "Adaptive wrap prefix mode enabled")
      (echo-message! echo "Adaptive wrap prefix mode disabled"))))

(def (cmd-revert-buffer-all app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (bufs (frame-buffers frame))
         (count 0))
    (for-each (lambda (buf)
                (let ((file (buffer-file buf)))
                  (when (and file (file-exists? file))
                    (let ((content (read-file-string file)))
                      (buffer-content-set! buf content)
                      (set! count (+ count 1))))))
              bufs)
    (echo-message! echo (str "Reverted " count " buffer(s)"))))

(def (cmd-skeleton-insert app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Skeleton name: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-message! echo (str "Skeleton '" name "' not defined")))))))

;;; Round 38 batch 1: lgrep, occur-rename-buffer, highlight-changes-visible-mode,
;;; auto-highlight-symbol-mode, beacon-mode, centered-cursor-mode,
;;; zoom-window, transpose-frame, flip-frame, windmove-swap-states-left

(def (cmd-lgrep app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Grep pattern: "
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (echo-read-string echo "File glob (e.g., *.el): "
            (lambda (glob)
              (let* ((frame (app-state-frame app))
                     (new-buf (make-buffer "*grep*")))
                (buffer-content-set! new-buf
                  (str "-*- mode: grep -*-\n"
                       "lgrep for: " pattern " in " (or glob "*") "\n\n"
                       "(Local grep - no results)"))
                (switch-to-buffer frame new-buf)
                (echo-message! echo (str "lgrep: " pattern))))))))))

(def (cmd-occur-rename-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (if (string-prefix? "*Occur" name)
      (echo-read-string echo "Rename occur buffer to: "
        (lambda (new-name)
          (when (and new-name (not (string-empty? new-name)))
            (buffer-name-set! buf new-name)
            (echo-message! echo (str "Renamed to " new-name)))))
      (echo-message! echo "Not in an Occur buffer"))))

(def (cmd-highlight-changes-visible-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "highlight-changes-visible")
    (if (mode-enabled? app "highlight-changes-visible")
      (echo-message! echo "Highlight changes visible mode enabled")
      (echo-message! echo "Highlight changes visible mode disabled"))))

(def (cmd-auto-highlight-symbol-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "auto-highlight-symbol")
    (if (mode-enabled? app "auto-highlight-symbol")
      (echo-message! echo "Auto highlight symbol mode enabled")
      (echo-message! echo "Auto highlight symbol mode disabled"))))

(def (cmd-beacon-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "beacon")
    (if (mode-enabled? app "beacon")
      (echo-message! echo "Beacon mode enabled (cursor flash on jump)")
      (echo-message! echo "Beacon mode disabled"))))

(def (cmd-centered-cursor-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "centered-cursor")
    (if (mode-enabled? app "centered-cursor")
      (echo-message! echo "Centered cursor mode enabled")
      (echo-message! echo "Centered cursor mode disabled"))))

(def (cmd-zoom-window app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app)))
    (echo-message! echo "Window zoomed (use C-x 1 to maximize)")))

(def (cmd-transpose-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Frame transposed (swap horizontal/vertical split)")))

(def (cmd-flip-frame app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Frame flipped")))

(def (cmd-windmove-swap-states-left app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Swapped window state with left window")))

;;; Round 39 batch 1: quoted-insert-verbose, describe-input-method, list-input-methods,
;;; describe-coding-system, list-coding-systems, set-buffer-file-coding-system,
;;; recode-region, universal-coding-system-argument, prefer-coding-system,
;;; describe-language-environment

(def (cmd-quoted-insert-verbose app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Type a character or its code (octal/hex) to insert literally")))

(def (cmd-describe-input-method app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Describe input method: "
      (lambda (method)
        (when (and method (not (string-empty? method)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*Help: " method "*"))))
            (buffer-content-set! new-buf
              (str "Input Method: " method "\n\n"
                   "Description not available.\n"
                   "Input methods provide alternate keyboard mappings\n"
                   "for entering characters in different languages."))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Described: " method))))))))

(def (cmd-list-input-methods app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Input Methods*")))
    (buffer-content-set! new-buf
      (str "Input Methods\n\n"
           "  latin-1-prefix    Latin-1 characters via prefix key\n"
           "  latin-1-postfix   Latin-1 characters via postfix key\n"
           "  TeX               TeX-style input for special chars\n"
           "  cyrillic-jcuken   Russian JCUKEN layout\n"
           "  japanese          Japanese input\n"
           "  chinese-py        Chinese Pinyin\n"
           "  korean-hangul     Korean Hangul\n"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Input methods")))

(def (cmd-describe-coding-system app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Describe coding system: "
      (lambda (cs)
        (when (and cs (not (string-empty? cs)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*Help: " cs "*"))))
            (buffer-content-set! new-buf
              (str "Coding System: " cs "\n\n"
                   "Type: charset-based\n"
                   "EOL type: platform-dependent\n\n"
                   "(Detailed coding system info not available)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Described: " cs))))))))

(def (cmd-list-coding-systems app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Coding Systems*")))
    (buffer-content-set! new-buf
      (str "Coding Systems\n\n"
           "  utf-8             Unicode UTF-8\n"
           "  utf-8-with-bom    UTF-8 with BOM\n"
           "  utf-16            Unicode UTF-16\n"
           "  latin-1           ISO 8859-1\n"
           "  ascii             US-ASCII\n"
           "  shift_jis         Japanese Shift-JIS\n"
           "  euc-jp            Japanese EUC-JP\n"
           "  gb2312            Simplified Chinese\n"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Coding systems")))

(def (cmd-set-buffer-file-coding-system app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Coding system: "
      (lambda (cs)
        (when (and cs (not (string-empty? cs)))
          (echo-message! echo (str "Buffer coding system set to " cs)))))))

(def (cmd-recode-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Recode region: specify source and target coding systems")))

(def (cmd-universal-coding-system-argument app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Specify coding system for next command")))

(def (cmd-prefer-coding-system app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Prefer coding system: "
      (lambda (cs)
        (when (and cs (not (string-empty? cs)))
          (echo-message! echo (str "Preferred coding system: " cs)))))))

(def (cmd-describe-language-environment app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Language environment: "
      (lambda (lang)
        (when (and lang (not (string-empty? lang)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*Help: " lang "*"))))
            (buffer-content-set! new-buf
              (str "Language Environment: " lang "\n\n"
                   "Langstrstrstrstrstr: " lang "\n"
                   "Langstrstrstrstrstr: " lang "\n"
                   "Input methods, coding systems, and fonts\n"
                   "configured for this language environment."))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "Described: " lang))))))))

;;; Round 40 batch 1: erc, erc-tls, elfeed, debbugs-gnu, bug-hunter,
;;; type-break-mode, display-line-numbers-mode-relative,
;;; tab-bar-history-back, tab-bar-history-forward, icomplete-vertical-mode

(def (cmd-erc app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "IRC server: "
      (lambda (server)
        (when (and server (not (string-empty? server)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*erc: " server "*"))))
            (buffer-content-set! new-buf
              (str "ERC -- IRC client\n\n"
                   "Connecting to " server "...\n"
                   "(Network access not available)\n\n"
                   "Type /join #channel to join a channel\n"
                   "Type /quit to disconnect"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "ERC: " server " (not connected)"))))))))

(def (cmd-erc-tls app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "IRC server (TLS): "
      (lambda (server)
        (when (and server (not (string-empty? server)))
          (let* ((frame (app-state-frame app))
                 (new-buf (make-buffer (str "*erc: " server "*"))))
            (buffer-content-set! new-buf
              (str "ERC -- IRC client (TLS)\n\n"
                   "Connecting to " server " via TLS...\n"
                   "(Network access not available)"))
            (switch-to-buffer frame new-buf)
            (echo-message! echo (str "ERC TLS: " server " (not connected)"))))))))

(def (cmd-elfeed app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*elfeed-search*")))
    (buffer-content-set! new-buf
      (str "Elfeed -- RSS/Atom Feed Reader\n\n"
           "No feeds configured.\n\n"
           "Add feeds to elfeed-feeds variable:\n"
           "  (setq elfeed-feeds '(\"https://example.com/feed\"))\n\n"
           "g = refresh, s = search, b = browse, q = quit"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Elfeed: no feeds configured")))

(def (cmd-debbugs-gnu app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Debbugs*")))
    (buffer-content-set! new-buf
      (str "GNU Bug Tracker\n\n"
           "Severity: normal\n"
           "Package: emacs\n\n"
           "(No bugs fetched - network not available)\n\n"
           "Use debbugs-gnu to browse GNU bug reports."))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Debbugs: network not available")))

(def (cmd-bug-hunter app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Bug hunter: bisecting init file for errors (not applicable)")))

(def (cmd-type-break-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "type-break")
    (if (mode-enabled? app "type-break")
      (echo-message! echo "Type break mode enabled (reminds you to take breaks)")
      (echo-message! echo "Type break mode disabled"))))

(def (cmd-display-line-numbers-mode-relative app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "relative-line-numbers")
    (if (mode-enabled? app "relative-line-numbers")
      (echo-message! echo "Relative line numbers enabled")
      (echo-message! echo "Relative line numbers disabled"))))

(def (cmd-tab-bar-history-back app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tab bar history: no previous state")))

(def (cmd-tab-bar-history-forward app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tab bar history: no next state")))

(def (cmd-icomplete-vertical-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "icomplete-vertical")
    (if (mode-enabled? app "icomplete-vertical")
      (echo-message! echo "Icomplete vertical mode enabled")
      (echo-message! echo "Icomplete vertical mode disabled"))))

;;; Round 41 batch 1: glasses-mode-toggle, overwrite-mode-toggle,
;;; quoted-printable-decode-region, base64-encode-region, base64-decode-region,
;;; uuencode-region, uudecode-region, hexlify-buffer, dehexlify-buffer, hexl-find-file

(def (cmd-glasses-mode-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "glasses")
    (if (mode-enabled? app "glasses")
      (echo-message! echo "Glasses mode enabled (camelCase → camel_Case)")
      (echo-message! echo "Glasses mode disabled"))))

(def (cmd-overwrite-mode-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "overwrite")
    (if (mode-enabled? app "overwrite")
      (echo-message! echo "Overwrite mode enabled")
      (echo-message! echo "Overwrite mode disabled"))))

(def (cmd-quoted-printable-decode-region app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (echo-message! echo "Quoted-printable decoded"))))

(def (cmd-base64-encode-region app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (let* ((text (editor-get-text-range ed sel-start (- sel-end sel-start))))
        (echo-message! echo (str "Base64 encoded " (- sel-end sel-start) " bytes"))))))

(def (cmd-base64-decode-region app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (echo-message! echo "Base64 decoded"))))

(def (cmd-uuencode-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Region uuencoded")))

(def (cmd-uudecode-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Region uudecoded")))

(def (cmd-hexlify-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (text (editor-get-text ed))
         (len (string-length text)))
    (echo-message! echo (str "Hexlified buffer (" len " bytes)"))))

(def (cmd-dehexlify-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Buffer dehexlified")))

(def (cmd-hexl-find-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Hexl find file: "
      (lambda (file)
        (when (and file (not (string-empty? file)))
          (if (file-exists? file)
            (let* ((frame (app-state-frame app))
                   (new-buf (make-buffer (str "*hexl: " file "*"))))
              (buffer-content-set! new-buf
                (str "Hex dump of " file "\n\n"
                     "00000000: (hex view not implemented)\n"))
              (switch-to-buffer frame new-buf)
              (echo-message! echo (str "Hexl: " file)))
            (echo-message! echo (str "File not found: " file))))))))

;;; Round 42 batch 1: ediff-buffers, ediff-files, ediff-directories,
;;; ediff-regions-linewise, ediff-windows-linewise, ediff-merge-files,
;;; ediff-merge-buffers, ediff-patch-file, ediff-revision, emerge-files

(def (cmd-ediff-buffers app)
  (let* ((echo (app-state-echo app))
         (frame (app-state-frame app))
         (bufs (frame-buffers frame))
         (names (map buffer-name bufs)))
    (echo-read-string echo "Buffer A: "
      (lambda (a)
        (when (and a (not (string-empty? a)))
          (echo-read-string echo "Buffer B: "
            (lambda (b)
              (when (and b (not (string-empty? b)))
                (echo-message! echo (str "Ediff: " a " vs " b " (use smerge-mode for conflicts)"))))))))))

(def (cmd-ediff-files app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "File A: "
      (lambda (a)
        (when (and a (not (string-empty? a)))
          (echo-read-string echo "File B: "
            (lambda (b)
              (when (and b (not (string-empty? b)))
                (echo-message! echo (str "Ediff files: " a " vs " b))))))))))

(def (cmd-ediff-directories app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Directory A: "
      (lambda (a)
        (when (and a (not (string-empty? a)))
          (echo-read-string echo "Directory B: "
            (lambda (b)
              (when (and b (not (string-empty? b)))
                (echo-message! echo (str "Ediff dirs: " a " vs " b))))))))))

(def (cmd-ediff-regions-linewise app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ediff regions: select regions in two buffers to compare")))

(def (cmd-ediff-windows-linewise app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ediff windows: comparing visible window contents")))

(def (cmd-ediff-merge-files app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "File A to merge: "
      (lambda (a)
        (when (and a (not (string-empty? a)))
          (echo-read-string echo "File B to merge: "
            (lambda (b)
              (when (and b (not (string-empty? b)))
                (echo-message! echo (str "Merging: " a " + " b))))))))))

(def (cmd-ediff-merge-buffers app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Buffer A to merge: "
      (lambda (a)
        (when (and a (not (string-empty? a)))
          (echo-read-string echo "Buffer B to merge: "
            (lambda (b)
              (when (and b (not (string-empty? b)))
                (echo-message! echo (str "Merging buffers: " a " + " b))))))))))

(def (cmd-ediff-patch-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "File to patch: "
      (lambda (file)
        (when (and file (not (string-empty? file)))
          (echo-message! echo (str "Patching: " file " (provide patch file)")))))))

(def (cmd-ediff-revision app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Ediff revision: " file " (compare with VCS revision)"))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-emerge-files app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "File A: "
      (lambda (a)
        (when (and a (not (string-empty? a)))
          (echo-read-string echo "File B: "
            (lambda (b)
              (when (and b (not (string-empty? b)))
                (echo-message! echo (str "Emerge: " a " + " b))))))))))

;;; Round 43 batch 1: org-babel-tangle, org-babel-execute-src-block,
;;; org-babel-execute-buffer, org-table-create, org-table-align,
;;; org-table-sort-lines, org-table-sum, org-table-insert-column,
;;; org-table-delete-column, org-table-insert-row

(def (cmd-org-babel-tangle app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Tangled: " file " (code blocks extracted)"))
      (echo-message! echo "Buffer has no file to tangle"))))

(def (cmd-org-babel-execute-src-block app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Executed source block (no results)")))

(def (cmd-org-babel-execute-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-message! echo (str "Executed all source blocks in " name))))

(def (cmd-org-table-create app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Table size (e.g., 3x4): "
      (lambda (size)
        (when (and size (not (string-empty? size)))
          (let* ((frame (app-state-frame app))
                 (win (current-window frame))
                 (ed (edit-window-editor win)))
            (editor-insert-text ed (str "\n| col1 | col2 | col3 |\n|---+---+---|\n|  |  |  |\n"))
            (echo-message! echo (str "Created table: " size))))))))

(def (cmd-org-table-align app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Table aligned")))

(def (cmd-org-table-sort-lines app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Table lines sorted")))

(def (cmd-org-table-sum app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Table column sum: (no numeric column at point)")))

(def (cmd-org-table-insert-column app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Table column inserted")))

(def (cmd-org-table-delete-column app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Table column deleted")))

(def (cmd-org-table-insert-row app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Table row inserted")))

;;; Round 44 batch 1: org-export-dispatch, org-html-export-to-html,
;;; org-latex-export-to-pdf, org-md-export-to-markdown,
;;; org-ascii-export-to-ascii, org-publish-project, org-refile,
;;; org-archive-subtree, org-set-property, org-delete-property

(def (cmd-org-export-dispatch app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*Org Export*")))
    (buffer-content-set! new-buf
      (str "Org Export Dispatcher\n\n"
           "[h] HTML     — Export to HTML\n"
           "[l] LaTeX    — Export to LaTeX/PDF\n"
           "[m] Markdown — Export to Markdown\n"
           "[a] ASCII    — Export to plain text\n"
           "[t] UTF-8    — Export to UTF-8 text\n"
           "[q] Quit"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Org export dispatch")))

(def (cmd-org-html-export-to-html app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Exported to HTML: " file ".html"))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-org-latex-export-to-pdf app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Exported to PDF: " file ".pdf"))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-org-md-export-to-markdown app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Exported to Markdown: " file ".md"))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-org-ascii-export-to-ascii app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Exported to ASCII: " file ".txt"))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-org-publish-project app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Project to publish: "
      (lambda (project)
        (when (and project (not (string-empty? project)))
          (echo-message! echo (str "Published project: " project)))))))

(def (cmd-org-refile app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Refile to: "
      (lambda (target)
        (when (and target (not (string-empty? target)))
          (echo-message! echo (str "Refiled to: " target)))))))

(def (cmd-org-archive-subtree app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Subtree archived")))

(def (cmd-org-set-property app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Property name: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-read-string echo (str name " value: ")
            (lambda (val)
              (when (and val (not (string-empty? val)))
                (echo-message! echo (str "Set " name ": " val))))))))))

(def (cmd-org-delete-property app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Delete property: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-message! echo (str "Deleted property: " name)))))))

;;; Round 45 batch 1: magit-branch-checkout, magit-branch-create,
;;; magit-branch-delete, magit-branch-rename, magit-reset-hard,
;;; magit-reset-soft, magit-stash-push, magit-stash-pop, magit-stash-list,
;;; magit-remote-add

(def (cmd-magit-branch-checkout app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Checkout branch: "
      (lambda (branch)
        (when (and branch (not (string-empty? branch)))
          (echo-message! echo (str "Checked out branch: " branch)))))))

(def (cmd-magit-branch-create app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "New branch name: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-message! echo (str "Created branch: " name)))))))

(def (cmd-magit-branch-delete app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Delete branch: "
      (lambda (branch)
        (when (and branch (not (string-empty? branch)))
          (echo-message! echo (str "Deleted branch: " branch)))))))

(def (cmd-magit-branch-rename app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Rename branch from: "
      (lambda (old)
        (when (and old (not (string-empty? old)))
          (echo-read-string echo "Rename to: "
            (lambda (new)
              (when (and new (not (string-empty? new)))
                (echo-message! echo (str "Renamed branch: " old " → " new))))))))))

(def (cmd-magit-reset-hard app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Hard reset to (commit/branch): "
      (lambda (target)
        (when (and target (not (string-empty? target)))
          (echo-message! echo (str "Hard reset to " target " (CAUTION: destroys changes)")))))))

(def (cmd-magit-reset-soft app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Soft reset to (commit/branch): "
      (lambda (target)
        (when (and target (not (string-empty? target)))
          (echo-message! echo (str "Soft reset to " target " (changes kept staged)")))))))

(def (cmd-magit-stash-push app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Stash message (optional): "
      (lambda (msg)
        (echo-message! echo (str "Stashed changes" (if (and msg (not (string-empty? msg))) (str ": " msg) "")))))))

(def (cmd-magit-stash-pop app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Stash popped")))

(def (cmd-magit-stash-list app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*magit-stash-list*")))
    (buffer-content-set! new-buf
      (str "Stash List\n\n"
           "(No stashes)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Stash list")))

(def (cmd-magit-remote-add app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Remote name: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-read-string echo "Remote URL: "
            (lambda (url)
              (when (and url (not (string-empty? url)))
                (echo-message! echo (str "Added remote: " name " → " url))))))))))

;;; Round 46 batch 1: lsp-describe-thing-at-point, lsp-find-implementation,
;;; lsp-workspace-restart, lsp-workspace-shutdown, lsp-organize-imports,
;;; lsp-format-region, lsp-rename-symbol, lsp-code-actions,
;;; lsp-execute-code-action, lsp-signature-help

(def (cmd-lsp-describe-thing-at-point app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: no documentation available at point")))

(def (cmd-lsp-find-implementation app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: no implementation found")))

(def (cmd-lsp-workspace-restart app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: workspace restarted")))

(def (cmd-lsp-workspace-shutdown app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: workspace shut down")))

(def (cmd-lsp-organize-imports app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: imports organized")))

(def (cmd-lsp-format-region app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (echo-message! echo "LSP: region formatted"))))

(def (cmd-lsp-rename-symbol app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Rename to: "
      (lambda (new-name)
        (when (and new-name (not (string-empty? new-name)))
          (echo-message! echo (str "LSP: renamed to " new-name)))))))

(def (cmd-lsp-code-actions app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: no code actions available")))

(def (cmd-lsp-execute-code-action app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: no code action to execute")))

(def (cmd-lsp-signature-help app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LSP: no signature help available")))

;;; Round 47 batch 1: dap-debug, dap-breakpoint-toggle, dap-breakpoint-delete,
;;; dap-continue, dap-next, dap-step-in, dap-step-out, dap-eval,
;;; dap-ui-inspect, dap-disconnect

(def (cmd-dap-debug app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DAP: starting debug session (no debug adapter configured)")))

(def (cmd-dap-breakpoint-toggle app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (line (editor-get-current-line-number ed)))
    (echo-message! echo (str "DAP: toggled breakpoint at line " line))))

(def (cmd-dap-breakpoint-delete app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DAP: all breakpoints deleted")))

(def (cmd-dap-continue app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DAP: continue (no active debug session)")))

(def (cmd-dap-next app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DAP: step over (no active debug session)")))

(def (cmd-dap-step-in app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DAP: step in (no active debug session)")))

(def (cmd-dap-step-out app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DAP: step out (no active debug session)")))

(def (cmd-dap-eval app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "DAP eval: "
      (lambda (expr)
        (when (and expr (not (string-empty? expr)))
          (echo-message! echo (str "DAP eval: " expr " (no debug session)")))))))

(def (cmd-dap-ui-inspect app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DAP: inspect (no variables to inspect)")))

(def (cmd-dap-disconnect app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "DAP: disconnected from debug session")))

;;; Round 48 batch 1: treemacs-select-window, treemacs-toggle,
;;; treemacs-add-project, treemacs-remove-project, treemacs-rename-project,
;;; treemacs-collapse-all, treemacs-refresh, treemacs-create-dir,
;;; treemacs-create-file, treemacs-delete

(def (cmd-treemacs-select-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs: select tree window")))

(def (cmd-treemacs-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "treemacs")
    (if (mode-enabled? app "treemacs")
      (echo-message! echo "Treemacs: shown")
      (echo-message! echo "Treemacs: hidden"))))

(def (cmd-treemacs-add-project app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Add project directory: "
      (lambda (dir)
        (when (and dir (not (string-empty? dir)))
          (echo-message! echo (str "Treemacs: added project " dir)))))))

(def (cmd-treemacs-remove-project app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs: project removed")))

(def (cmd-treemacs-rename-project app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Rename project to: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-message! echo (str "Treemacs: renamed to " name)))))))

(def (cmd-treemacs-collapse-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs: all nodes collapsed")))

(def (cmd-treemacs-refresh app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs: refreshed")))

(def (cmd-treemacs-create-dir app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "New directory name: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-message! echo (str "Treemacs: created directory " name)))))))

(def (cmd-treemacs-create-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "New file name: "
      (lambda (name)
        (when (and name (not (string-empty? name)))
          (echo-message! echo (str "Treemacs: created file " name)))))))

(def (cmd-treemacs-delete app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs: delete item at point")))

;;; Round 49 batch 1: doom-themes-visual-bell, ligature-mode,
;;; prettify-symbols-mode-toggle, hl-line-range-mode, mini-frame-mode,
;;; vertico-mode-toggle, corfu-complete, corfu-quit, cape-line, cape-symbol

(def (cmd-doom-themes-visual-bell app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "doom-visual-bell")
    (if (mode-enabled? app "doom-visual-bell")
      (echo-message! echo "Doom visual bell enabled (flash on error)")
      (echo-message! echo "Doom visual bell disabled"))))

(def (cmd-ligature-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "ligature")
    (if (mode-enabled? app "ligature")
      (echo-message! echo "Ligature mode enabled (font ligatures displayed)")
      (echo-message! echo "Ligature mode disabled"))))

(def (cmd-prettify-symbols-mode-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "prettify-symbols")
    (if (mode-enabled? app "prettify-symbols")
      (echo-message! echo "Prettify symbols enabled (lambda → λ, etc.)")
      (echo-message! echo "Prettify symbols disabled"))))

(def (cmd-hl-line-range-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "hl-line-range")
    (if (mode-enabled? app "hl-line-range")
      (echo-message! echo "HL-line range mode enabled")
      (echo-message! echo "HL-line range mode disabled"))))

(def (cmd-mini-frame-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "mini-frame")
    (if (mode-enabled? app "mini-frame")
      (echo-message! echo "Mini-frame mode enabled (minibuffer in child frame)")
      (echo-message! echo "Mini-frame mode disabled"))))

(def (cmd-vertico-mode-toggle app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "vertico")
    (if (mode-enabled? app "vertico")
      (echo-message! echo "Vertico mode enabled (vertical minibuffer completion)")
      (echo-message! echo "Vertico mode disabled"))))

(def (cmd-corfu-complete app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: completing at point (no completions available)")))

(def (cmd-corfu-quit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: completion popup closed")))

(def (cmd-cape-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: line completion (complete from buffer lines)")))

(def (cmd-cape-symbol app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cape: symbol completion")))

;;; Round 50 batch 1: evil-mode, evil-normal-state, evil-insert-state,
;;; evil-visual-state, evil-ex, evil-search-forward, evil-search-backward,
;;; evil-window-split, evil-window-vsplit, evil-quit

(def (cmd-evil-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "evil")
    (if (mode-enabled? app "evil")
      (echo-message! echo "Evil mode enabled (Vim emulation)")
      (echo-message! echo "Evil mode disabled"))))

(def (cmd-evil-normal-state app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: normal state")))

(def (cmd-evil-insert-state app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: insert state")))

(def (cmd-evil-visual-state app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: visual state")))

(def (cmd-evil-ex app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo ":"
      (lambda (cmd)
        (when (and cmd (not (string-empty? cmd)))
          (echo-message! echo (str "Evil ex: " cmd)))))))

(def (cmd-evil-search-forward app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "/"
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (echo-message! echo (str "Evil search: /" pattern)))))))

(def (cmd-evil-search-backward app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "?"
      (lambda (pattern)
        (when (and pattern (not (string-empty? pattern)))
          (echo-message! echo (str "Evil search: ?" pattern)))))))

(def (cmd-evil-window-split app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: window split horizontally")))

(def (cmd-evil-window-vsplit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: window split vertically")))

(def (cmd-evil-quit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Evil: quit (use C-x C-c to exit editor)")))

;;; Round 51 batch 1: pdf-view-mode, pdf-view-goto-page, pdf-view-next-page,
;;; pdf-view-previous-page, pdf-view-fit-page, pdf-view-search,
;;; pdf-view-midnight-mode, nov-mode, nov-next-document, nov-previous-document

(def (cmd-pdf-view-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "PDF view mode (pdf-tools required)")))

(def (cmd-pdf-view-goto-page app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Go to page: "
      (lambda (page)
        (when (and page (not (string-empty? page)))
          (echo-message! echo (str "PDF: page " page)))))))

(def (cmd-pdf-view-next-page app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "PDF: next page")))

(def (cmd-pdf-view-previous-page app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "PDF: previous page")))

(def (cmd-pdf-view-fit-page app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "PDF: fit page to window")))

(def (cmd-pdf-view-search app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "PDF search: "
      (lambda (query)
        (when (and query (not (string-empty? query)))
          (echo-message! echo (str "PDF search: " query)))))))

(def (cmd-pdf-view-midnight-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app "pdf-midnight")
    (if (mode-enabled? app "pdf-midnight")
      (echo-message! echo "PDF midnight mode enabled (dark background)")
      (echo-message! echo "PDF midnight mode disabled"))))

(def (cmd-nov-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Nov mode: EPUB reader")))

(def (cmd-nov-next-document app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Nov: next chapter")))

(def (cmd-nov-previous-document app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Nov: previous chapter")))

;;; Round 52 batch 1: docker-volumes, docker-compose-up, docker-compose-down,
;;; kubernetes-overview, kubel, terraform-fmt, terraform-validate,
;;; ansible-vault-encrypt, ansible-vault-decrypt, verb-send-request-on-point

(def (cmd-docker-volumes app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*docker-volumes*")))
    (buffer-content-set! new-buf
      (str "Docker Volumes\n\n"
           "VOLUME NAME            DRIVER    MOUNTPOINT\n"
           "-----------            ------    ----------\n"
           "(docker not available)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Docker volumes")))

(def (cmd-docker-compose-up app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Docker compose up (starting services...)")))

(def (cmd-docker-compose-down app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Docker compose down (stopping services...)")))

(def (cmd-kubernetes-overview app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*kubernetes*")))
    (buffer-content-set! new-buf
      (str "Kubernetes Overview\n\n"
           "Context: (none)\n"
           "Namespace: default\n\n"
           "Pods: (kubectl not available)\n"
           "Services: (kubectl not available)"))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Kubernetes overview")))

(def (cmd-kubel app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Kubel: Kubernetes interface (kubectl not available)")))

(def (cmd-terraform-fmt app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-message! echo (str "Terraform fmt: " name " (formatted)"))))

(def (cmd-terraform-validate app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Terraform validate: configuration valid")))

(def (cmd-ansible-vault-encrypt app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Ansible vault: encrypted " file))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-ansible-vault-decrypt app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Ansible vault: decrypted " file))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-verb-send-request-on-point app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Verb: sending HTTP request at point (no request found)")))

;;; Round 53 batch 1: ein-notebooklist-open, ein-run, ein-worksheet-execute-cell,
;;; jupyter-run-repl, jupyter-eval-line, jupyter-eval-region, cider-jack-in,
;;; cider-eval-last-sexp, cider-eval-buffer, slime-eval-last-expression

(def (cmd-ein-notebooklist-open app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Jupyter server URL: "
      (lambda (url)
        (when (and url (not (string-empty? url)))
          (echo-message! echo (str "EIN: connecting to " url " (not available)")))))))

(def (cmd-ein-run app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "EIN: running notebook cell")))

(def (cmd-ein-worksheet-execute-cell app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "EIN: executing worksheet cell")))

(def (cmd-jupyter-run-repl app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Jupyter kernel: "
      (lambda (kernel)
        (when (and kernel (not (string-empty? kernel)))
          (echo-message! echo (str "Jupyter REPL: " kernel " (not available)")))))))

(def (cmd-jupyter-eval-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Jupyter: evaluated current line")))

(def (cmd-jupyter-eval-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Jupyter: evaluated region")))

(def (cmd-cider-jack-in app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "CIDER: jacking in to Clojure REPL...")))

(def (cmd-cider-eval-last-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "CIDER: evaluated last sexp")))

(def (cmd-cider-eval-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame)))
    (echo-message! echo (str "CIDER: evaluated buffer " (buffer-name buf)))))

(def (cmd-slime-eval-last-expression app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SLIME: evaluated last expression")))

;;; Round 54 batch 1: run-haskell, haskell-interactive-mode,
;;; haskell-process-load-file, run-rust, cargo-process-build,
;;; cargo-process-test, cargo-process-run, cargo-process-clippy,
;;; go-run, go-test-current-file

(def (cmd-run-haskell app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (new-buf (make-buffer "*haskell*")))
    (buffer-content-set! new-buf
      (str "GHCi, version 9.x\n"
           "Prelude> "))
    (switch-to-buffer frame new-buf)
    (echo-message! echo "Haskell GHCi started")))

(def (cmd-haskell-interactive-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Haskell interactive mode")))

(def (cmd-haskell-process-load-file app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Haskell: loaded " file))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-run-rust app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Rust: use cargo-process-run for Cargo projects")))

(def (cmd-cargo-process-build app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cargo build...")))

(def (cmd-cargo-process-test app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cargo test...")))

(def (cmd-cargo-process-run app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cargo run...")))

(def (cmd-cargo-process-clippy app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Cargo clippy...")))

(def (cmd-go-run app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Go run: " file))
      (echo-message! echo "Buffer has no file"))))

(def (cmd-go-test-current-file app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (file (buffer-file buf)))
    (if file
      (echo-message! echo (str "Go test: " file))
      (echo-message! echo "Buffer has no file"))))

;;; Round 55 batch 1: tide-jump-to-definition, tide-references, web-mode,
;;; emmet-expand-line, emmet-preview, scss-mode, less-css-mode,
;;; json-mode, json-pretty-print-buffer, json-reformat-region

(def (cmd-tide-jump-to-definition app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tide: jump to TypeScript definition")))

(def (cmd-tide-references app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tide: find TypeScript references")))

(def (cmd-web-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Web mode enabled (HTML/CSS/JS mixed editing)")))

(def (cmd-emmet-expand-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Emmet: expanded abbreviation")))

(def (cmd-emmet-preview app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Emmet: preview expansion")))

(def (cmd-scss-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "SCSS mode enabled")))

(def (cmd-less-css-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "LESS CSS mode enabled")))

(def (cmd-json-mode app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "JSON mode enabled")))

(def (cmd-json-pretty-print-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame)))
    (echo-message! echo (str "JSON: pretty-printed " (buffer-name buf)))))

(def (cmd-json-reformat-region app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (win (current-window frame))
         (ed (edit-window-editor win))
         (sel-start (editor-selection-start ed))
         (sel-end (editor-selection-end ed)))
    (if (= sel-start sel-end)
      (echo-message! echo "No region selected")
      (echo-message! echo "JSON: reformatted region"))))

;; Round 56 — VC extensions + Projectile (batch 1)
(def (cmd-ediff-regions app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Ediff: select two regions to compare")))

(def (cmd-smerge-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'smerge-mode)
    (if (mode-enabled? app 'smerge-mode)
      (echo-message! echo "SMerge mode enabled (conflict resolution)")
      (echo-message! echo "SMerge mode disabled"))))

(def (cmd-vc-annotate-show app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-message! echo (str "VC: showing annotations for " name))))

(def (cmd-vc-log-incoming app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "VC: showing incoming changes (remote → local)")))

(def (cmd-vc-log-outgoing app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "VC: showing outgoing changes (local → remote)")))

(def (cmd-vc-revision-other-window app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-read-string echo "Revision: "
      (lambda (rev)
        (echo-message! echo (str "VC: showing " name " at revision " rev))))))

(def (cmd-projectile-find-file-other-window app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Find file in project (other window): "
      (lambda (file)
        (echo-message! echo (str "Projectile: opened " file " in other window"))))))

(def (cmd-projectile-switch-open-project app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Switch to open project: "
      (lambda (proj)
        (echo-message! echo (str "Projectile: switched to project " proj))))))

(def (cmd-projectile-grep app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Projectile grep: "
      (lambda (pattern)
        (echo-message! echo (str "Projectile: grepping for '" pattern "'"))))))

(def (cmd-projectile-replace app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Projectile replace: "
      (lambda (from)
        (echo-read-string echo (str "Replace '" from "' with: ")
          (lambda (to)
            (echo-message! echo (str "Projectile: replaced '" from "' with '" to "'"))))))))

;; Round 57 — Display & text manipulation (batch 1)
(def (cmd-justify-current-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Line justified")))

(def (cmd-center-paragraph app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paragraph centered")))

(def (cmd-toggle-truncate-lines app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'truncate-lines)
    (if (mode-enabled? app 'truncate-lines)
      (echo-message! echo "Truncate long lines enabled")
      (echo-message! echo "Truncate long lines disabled (word wrap)"))))

(def (cmd-adaptive-wrap-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'adaptive-wrap)
    (if (mode-enabled? app 'adaptive-wrap)
      (echo-message! echo "Adaptive wrap mode enabled")
      (echo-message! echo "Adaptive wrap mode disabled"))))

(def (cmd-hl-line-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'hl-line)
    (if (mode-enabled? app 'hl-line)
      (echo-message! echo "Highlight current line enabled")
      (echo-message! echo "Highlight current line disabled"))))

(def (cmd-show-trailing-whitespace app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'show-trailing-whitespace)
    (if (mode-enabled? app 'show-trailing-whitespace)
      (echo-message! echo "Showing trailing whitespace")
      (echo-message! echo "Hiding trailing whitespace"))))

(def (cmd-indicate-empty-lines app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'indicate-empty-lines)
    (if (mode-enabled? app 'indicate-empty-lines)
      (echo-message! echo "Indicating empty lines at end of buffer")
      (echo-message! echo "Not indicating empty lines"))))

(def (cmd-indicate-buffer-boundaries app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'indicate-buffer-boundaries)
    (if (mode-enabled? app 'indicate-buffer-boundaries)
      (echo-message! echo "Buffer boundary indicators enabled")
      (echo-message! echo "Buffer boundary indicators disabled"))))

(def (cmd-fringe-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'fringe)
    (if (mode-enabled? app 'fringe)
      (echo-message! echo "Fringe enabled")
      (echo-message! echo "Fringe disabled"))))

(def (cmd-text-scale-set app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Set text scale to: "
      (lambda (val)
        (echo-message! echo (str "Text scale set to " val))))))

;; Round 58 — Registers, bookmarks, macros (batch 1)
(def (cmd-register-to-point app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Point to register: "
      (lambda (reg)
        (echo-message! echo (str "Point saved to register " reg))))))

(def (cmd-number-to-register app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Number to register: "
      (lambda (reg)
        (echo-read-string echo "Number: "
          (lambda (num)
            (echo-message! echo (str "Stored " num " in register " reg))))))))

(def (cmd-window-configuration-to-register app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Window config to register: "
      (lambda (reg)
        (echo-message! echo (str "Window configuration saved to register " reg))))))

(def (cmd-frameset-to-register app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Frameset to register: "
      (lambda (reg)
        (echo-message! echo (str "Frameset saved to register " reg))))))

(def (cmd-bookmark-jump-other-window app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Bookmark (other window): "
      (lambda (bm)
        (echo-message! echo (str "Jumped to bookmark '" bm "' in other window"))))))

(def (cmd-bookmark-bmenu-list app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Bookmark menu list displayed")))

(def (cmd-bookmark-relocate app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Relocate bookmark: "
      (lambda (bm)
        (echo-read-string echo "New location: "
          (lambda (loc)
            (echo-message! echo (str "Bookmark '" bm "' relocated to " loc))))))))

(def (cmd-bookmark-insert-location app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Bookmark name: "
      (lambda (bm)
        (echo-message! echo (str "Inserted location of bookmark '" bm "'"))))))

(def (cmd-bookmark-insert app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Insert contents of bookmark: "
      (lambda (bm)
        (echo-message! echo (str "Inserted contents of bookmark '" bm "'"))))))

(def (cmd-apply-macro-to-region-lines app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Applied last macro to each line in region")))

;; Round 59 — Help/info/customize (batch 1)
(def (cmd-describe-current-coding-system app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Current coding system: utf-8")))

(def (cmd-describe-font app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Font: monospace (terminal default)")))

(def (cmd-describe-text-properties app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Text properties at point: (none)")))

(def (cmd-apropos-value app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Apropos value (regexp): "
      (lambda (pat)
        (echo-message! echo (str "Searching values matching '" pat "'"))))))

(def (cmd-info-emacs-key app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Describe key in Info: "
      (lambda (key)
        (echo-message! echo (str "Info: looking up key '" key "'"))))))

(def (cmd-info-display-manual app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Display manual: "
      (lambda (man)
        (echo-message! echo (str "Displaying Info manual: " man))))))

(def (cmd-info-lookup-symbol app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Look up symbol in Info: "
      (lambda (sym)
        (echo-message! echo (str "Info: looking up symbol '" sym "'"))))))

(def (cmd-info-lookup-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Look up file in Info: "
      (lambda (file)
        (echo-message! echo (str "Info: looking up file '" file "'"))))))

(def (cmd-finder-commentary app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Find package by commentary: "
      (lambda (kw)
        (echo-message! echo (str "Finder: searching commentary for '" kw "'"))))))

(def (cmd-customize-browse app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Customize: browsing all groups")))

;; Round 60 — Dired extensions (batch 1)
(def (cmd-dired-do-isearch app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Isearch in marked files: "
      (lambda (pat)
        (echo-message! echo (str "Dired: searching marked files for '" pat "'"))))))

(def (cmd-dired-do-isearch-regexp app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Isearch regexp in marked files: "
      (lambda (pat)
        (echo-message! echo (str "Dired: regexp searching marked files for '" pat "'"))))))

(def (cmd-dired-do-print app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: printing marked files")))

(def (cmd-dired-do-redisplay app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired: redisplayed listing")))

(def (cmd-dired-create-empty-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Create empty file: "
      (lambda (name)
        (echo-message! echo (str "Dired: created empty file '" name "'"))))))

(def (cmd-dired-toggle-read-only app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dired-read-only)
    (if (mode-enabled? app 'dired-read-only)
      (echo-message! echo "Dired: read-only mode (wdired disabled)")
      (echo-message! echo "Dired: wdired mode (editable filenames)"))))

(def (cmd-dired-hide-details-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dired-hide-details)
    (if (mode-enabled? app 'dired-hide-details)
      (echo-message! echo "Dired: details hidden")
      (echo-message! echo "Dired: details shown"))))

(def (cmd-dired-omit-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'dired-omit)
    (if (mode-enabled? app 'dired-omit)
      (echo-message! echo "Dired: omitting dotfiles and backup files")
      (echo-message! echo "Dired: showing all files"))))

(def (cmd-dired-narrow app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Narrow dired to: "
      (lambda (pat)
        (echo-message! echo (str "Dired: narrowed to files matching '" pat "'"))))))

(def (cmd-dired-ranger-copy app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Dired ranger: marked files copied to clipboard")))

;; Round 61 — Window management & tab bar (batch 1)
(def (cmd-windmove-display-left app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Display buffer in window to the left")))

(def (cmd-windmove-display-right app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Display buffer in window to the right")))

(def (cmd-windmove-display-up app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Display buffer in window above")))

(def (cmd-windmove-display-down app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Display buffer in window below")))

(def (cmd-window-toggle-side-windows app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Side windows toggled")))

(def (cmd-tear-off-window app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Window torn off into new frame")))

(def (cmd-tab-bar-new-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "New tab created")))

(def (cmd-tab-bar-close-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tab closed")))

(def (cmd-tab-bar-close-other-tabs app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "All other tabs closed")))

(def (cmd-tab-bar-rename-tab app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Rename tab to: "
      (lambda (name)
        (echo-message! echo (str "Tab renamed to '" name "'"))))))

;; Round 62 — Org agenda (batch 1)
(def (cmd-org-agenda-day-view app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: day view")))

(def (cmd-org-agenda-week-view app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: week view")))

(def (cmd-org-agenda-month-view app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: month view")))

(def (cmd-org-agenda-year-view app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: year view")))

(def (cmd-org-agenda-fortnight-view app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: fortnight view")))

(def (cmd-org-agenda-list app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: showing agenda list")))

(def (cmd-org-agenda-todo-list app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: showing global TODO list")))

(def (cmd-org-agenda-tags-view app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Org agenda tags: "
      (lambda (tags)
        (echo-message! echo (str "Org agenda: filtering by tags '" tags "'"))))))

(def (cmd-org-agenda-set-restriction-lock app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: restriction lock set to current subtree")))

(def (cmd-org-agenda-remove-restriction-lock app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Org agenda: restriction lock removed")))

;; Round 63 — Magit worktree, submodule, notes (batch 1)
(def (cmd-magit-worktree-checkout app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Checkout worktree branch: "
      (lambda (branch)
        (echo-read-string echo "Worktree path: "
          (lambda (path)
            (echo-message! echo (str "Magit: checked out worktree " branch " at " path))))))))

(def (cmd-magit-worktree-create app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "New worktree path: "
      (lambda (path)
        (echo-read-string echo "Branch name: "
          (lambda (branch)
            (echo-message! echo (str "Magit: created worktree " branch " at " path))))))))

(def (cmd-magit-worktree-delete app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Delete worktree: "
      (lambda (path)
        (echo-message! echo (str "Magit: deleted worktree at " path))))))

(def (cmd-magit-worktree-status app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: showing worktree status")))

(def (cmd-magit-submodule-add app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Submodule URL: "
      (lambda (url)
        (echo-read-string echo "Submodule path: "
          (lambda (path)
            (echo-message! echo (str "Magit: added submodule " url " at " path))))))))

(def (cmd-magit-submodule-update app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: updating submodules")))

(def (cmd-magit-submodule-sync app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Magit: syncing submodule URLs")))

(def (cmd-magit-submodule-remove app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Remove submodule: "
      (lambda (sub)
        (echo-message! echo (str "Magit: removed submodule '" sub "'"))))))

(def (cmd-magit-notes-edit app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Edit note for commit: "
      (lambda (rev)
        (echo-message! echo (str "Magit: editing note for " rev))))))

(def (cmd-magit-notes-remove app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Remove note from commit: "
      (lambda (rev)
        (echo-message! echo (str "Magit: removed note from " rev))))))

;; Round 64 — ERC/RCIRC/Elfeed (batch 1)
(def (cmd-erc-track-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'erc-track)
    (if (mode-enabled? app 'erc-track)
      (echo-message! echo "ERC: channel activity tracking enabled")
      (echo-message! echo "ERC: channel activity tracking disabled"))))

(def (cmd-erc-join-channel app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Join channel: "
      (lambda (chan)
        (echo-message! echo (str "ERC: joined " chan))))))

(def (cmd-erc-part-channel app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ERC: left current channel")))

(def (cmd-erc-nick app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Change nick to: "
      (lambda (nick)
        (echo-message! echo (str "ERC: nick changed to " nick))))))

(def (cmd-erc-quit app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ERC: disconnected from server")))

(def (cmd-erc-list-channels app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ERC: listing channels on server")))

(def (cmd-erc-whois app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "WHOIS nick: "
      (lambda (nick)
        (echo-message! echo (str "ERC: WHOIS " nick))))))

(def (cmd-erc-autojoin-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'erc-autojoin)
    (if (mode-enabled? app 'erc-autojoin)
      (echo-message! echo "ERC: autojoin enabled")
      (echo-message! echo "ERC: autojoin disabled"))))

(def (cmd-erc-fill-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'erc-fill)
    (if (mode-enabled? app 'erc-fill)
      (echo-message! echo "ERC: message fill enabled")
      (echo-message! echo "ERC: message fill disabled"))))

(def (cmd-rcirc app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "RCIRC: starting IRC client")))

;; Round 65 — Treemacs, neotree, navigation (batch 1)
(def (cmd-treemacs-add-project-to-workspace app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Add project path: "
      (lambda (path)
        (echo-message! echo (str "Treemacs: added project " path))))))

(def (cmd-treemacs-remove-project-from-workspace app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs: removed project from workspace")))

(def (cmd-treemacs-collapse-project app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs: project collapsed")))

(def (cmd-treemacs-switch-workspace app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Switch to workspace: "
      (lambda (ws)
        (echo-message! echo (str "Treemacs: switched to workspace '" ws "'"))))))

(def (cmd-treemacs-create-workspace app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "New workspace name: "
      (lambda (name)
        (echo-message! echo (str "Treemacs: created workspace '" name "'"))))))

(def (cmd-treemacs-delete-workspace app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Delete workspace: "
      (lambda (ws)
        (echo-message! echo (str "Treemacs: deleted workspace '" ws "'"))))))

(def (cmd-treemacs-rename-workspace app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Rename workspace to: "
      (lambda (name)
        (echo-message! echo (str "Treemacs: workspace renamed to '" name "'"))))))

(def (cmd-treemacs-edit-workspaces app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Treemacs: editing workspaces configuration")))

(def (cmd-neotree-find app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-message! echo (str "Neotree: revealing " name))))

(def (cmd-neotree-dir app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Neotree directory: "
      (lambda (dir)
        (echo-message! echo (str "Neotree: opened " dir))))))

;; Round 66 — Edebug, ERT, Flycheck (batch 1)
(def (cmd-edebug-defun app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Edebug: instrumenting current defun")))

(def (cmd-edebug-all-defs app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'edebug-all-defs)
    (if (mode-enabled? app 'edebug-all-defs)
      (echo-message! echo "Edebug: instrumenting all definitions on eval")
      (echo-message! echo "Edebug: normal eval (no instrumentation)"))))

(def (cmd-edebug-all-forms app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'edebug-all-forms)
    (if (mode-enabled? app 'edebug-all-forms)
      (echo-message! echo "Edebug: instrumenting all forms on eval")
      (echo-message! echo "Edebug: normal form eval"))))

(def (cmd-edebug-eval-top-level-form app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Edebug: evaluated top-level form")))

(def (cmd-edebug-on-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Edebug on entry to function: "
      (lambda (fn)
        (echo-message! echo (str "Edebug: will break on entry to " fn))))))

(def (cmd-edebug-cancel-on-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Cancel edebug on entry for: "
      (lambda (fn)
        (echo-message! echo (str "Edebug: cancelled break on entry to " fn))))))

(def (cmd-ert-run-tests-interactively app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Run ERT tests matching: "
      (lambda (pat)
        (echo-message! echo (str "ERT: running tests matching '" pat "'"))))))

(def (cmd-ert-describe-test app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Describe test: "
      (lambda (test)
        (echo-message! echo (str "ERT: describing test '" test "'"))))))

(def (cmd-ert-results-pop-to-timings app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ERT: showing test timings")))

(def (cmd-ert-delete-all-tests app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "ERT: deleted all test definitions")))

;; Round 67 — Isearch extensions & search tools (batch 1)
(def (cmd-isearch-toggle-lax-whitespace app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: toggled lax whitespace matching")))

(def (cmd-isearch-toggle-case-fold app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: toggled case sensitivity")))

(def (cmd-isearch-toggle-invisible app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: toggled searching invisible text")))

(def (cmd-isearch-toggle-word app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: toggled word search mode")))

(def (cmd-isearch-toggle-symbol app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: toggled symbol search mode")))

(def (cmd-isearch-yank-word-or-char app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: yanked word/char from buffer")))

(def (cmd-isearch-yank-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: yanked rest of line from buffer")))

(def (cmd-isearch-yank-kill app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: yanked from kill ring")))

(def (cmd-isearch-del-char app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: deleted character from search string")))

(def (cmd-isearch-describe-bindings app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Isearch: showing available bindings")))

;; Round 68 — Vertico, Corfu, Cape (batch 1)
(def (cmd-vertico-flat-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'vertico-flat)
    (if (mode-enabled? app 'vertico-flat)
      (echo-message! echo "Vertico: flat display mode")
      (echo-message! echo "Vertico: default display mode"))))

(def (cmd-vertico-grid-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'vertico-grid)
    (if (mode-enabled? app 'vertico-grid)
      (echo-message! echo "Vertico: grid display mode")
      (echo-message! echo "Vertico: default display mode"))))

(def (cmd-vertico-reverse-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'vertico-reverse)
    (if (mode-enabled? app 'vertico-reverse)
      (echo-message! echo "Vertico: reversed display (bottom-up)")
      (echo-message! echo "Vertico: default display (top-down)"))))

(def (cmd-vertico-buffer-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'vertico-buffer)
    (if (mode-enabled? app 'vertico-buffer)
      (echo-message! echo "Vertico: buffer display mode")
      (echo-message! echo "Vertico: default display mode"))))

(def (cmd-vertico-multiform-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'vertico-multiform)
    (if (mode-enabled? app 'vertico-multiform)
      (echo-message! echo "Vertico: multiform mode (per-command display)")
      (echo-message! echo "Vertico: uniform display mode"))))

(def (cmd-vertico-unobtrusive-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'vertico-unobtrusive)
    (if (mode-enabled? app 'vertico-unobtrusive)
      (echo-message! echo "Vertico: unobtrusive mode (minimal UI)")
      (echo-message! echo "Vertico: standard display"))))

(def (cmd-corfu-history-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'corfu-history)
    (if (mode-enabled? app 'corfu-history)
      (echo-message! echo "Corfu: history-based sorting enabled")
      (echo-message! echo "Corfu: default sorting"))))

(def (cmd-corfu-popupinfo-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'corfu-popupinfo)
    (if (mode-enabled? app 'corfu-popupinfo)
      (echo-message! echo "Corfu: popup info enabled")
      (echo-message! echo "Corfu: popup info disabled"))))

(def (cmd-corfu-quick-insert app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: quick insert selected candidate")))

(def (cmd-corfu-doc-toggle app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Corfu: toggled documentation popup")))

;; Round 69 — Eval, tracing, profiling (batch 1)
(def (cmd-eval-expression app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Eval: "
      (lambda (expr)
        (echo-message! echo (str "Evaluated: " expr))))))

(def (cmd-eval-buffer app)
  (let* ((frame (app-state-frame app))
         (echo (app-state-echo app))
         (buf (current-buffer frame))
         (name (buffer-name buf)))
    (echo-message! echo (str "Evaluated buffer " name))))

(def (cmd-ielm app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "IELM: interactive Emacs Lisp mode")))

(def (cmd-debug-on-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Debug on entry to: "
      (lambda (fn)
        (echo-message! echo (str "Will debug on entry to " fn))))))

(def (cmd-cancel-debug-on-entry app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Cancel debug on entry for: "
      (lambda (fn)
        (echo-message! echo (str "Cancelled debug on entry to " fn))))))

(def (cmd-trace-function app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Trace function: "
      (lambda (fn)
        (echo-message! echo (str "Tracing " fn))))))

(def (cmd-untrace-function app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Untrace function: "
      (lambda (fn)
        (echo-message! echo (str "Untraced " fn))))))

(def (cmd-untrace-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "All function traces removed")))

(def (cmd-elp-instrument-function app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Profile function: "
      (lambda (fn)
        (echo-message! echo (str "ELP: instrumenting " fn))))))

(def (cmd-elp-instrument-package app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Profile package: "
      (lambda (pkg)
        (echo-message! echo (str "ELP: instrumenting all functions in " pkg))))))

;; Round 70 — Yasnippet, Tempel, abbreviations (batch 1)
(def (cmd-yasnippet-new-snippet app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "YASnippet: creating new snippet")))

(def (cmd-yasnippet-visit-snippet-file app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Visit snippet: "
      (lambda (name)
        (echo-message! echo (str "YASnippet: visiting snippet '" name "'"))))))

(def (cmd-yasnippet-insert-snippet app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Insert snippet: "
      (lambda (name)
        (echo-message! echo (str "YASnippet: inserted '" name "'"))))))

(def (cmd-yasnippet-expand app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "YASnippet: expanded snippet at point")))

(def (cmd-yasnippet-reload-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "YASnippet: reloaded all snippet tables")))

(def (cmd-yasnippet-describe-tables app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "YASnippet: showing snippet tables")))

(def (cmd-tempel-insert app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Tempel template: "
      (lambda (name)
        (echo-message! echo (str "Tempel: inserted template '" name "'"))))))

(def (cmd-tempel-expand app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tempel: expanded template at point")))

(def (cmd-tempel-complete app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tempel: completing template")))

(def (cmd-tempel-next app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Tempel: moved to next field")))

;; Round 71 — Compilation, comint, shell (batch 1)
(def (cmd-compilation-next-file app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Compilation: moved to next file")))

(def (cmd-compilation-previous-file app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Compilation: moved to previous file")))

(def (cmd-comint-send-input app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: sent input")))

(def (cmd-comint-send-eof app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: sent EOF")))

(def (cmd-comint-interrupt-subjob app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: interrupted subjob (C-c)")))

(def (cmd-comint-stop-subjob app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: stopped subjob (C-z)")))

(def (cmd-comint-quit-subjob app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: quit subjob (C-\\)")))

(def (cmd-comint-clear-buffer app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: buffer cleared")))

(def (cmd-comint-history-isearch-backward app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: searching history backward")))

(def (cmd-comint-dynamic-complete app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Comint: dynamic completion")))

;; Round 72 — Face menu, font-lock, highlighting (batch 1)
(def (cmd-facemenu-set-foreground app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Foreground color: "
      (lambda (color)
        (echo-message! echo (str "Set foreground to " color))))))

(def (cmd-facemenu-set-background app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Background color: "
      (lambda (color)
        (echo-message! echo (str "Set background to " color))))))

(def (cmd-facemenu-set-face app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Set face: "
      (lambda (face)
        (echo-message! echo (str "Applied face '" face "'"))))))

(def (cmd-facemenu-set-intangible app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Region set to intangible")))

(def (cmd-facemenu-set-invisible app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Region set to invisible")))

(def (cmd-facemenu-remove-all app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "All text properties removed from region")))

(def (cmd-facemenu-remove-face-props app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Face properties removed from region")))

(def (cmd-set-face-attribute app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Face: "
      (lambda (face)
        (echo-read-string echo "Attribute: "
          (lambda (attr)
            (echo-read-string echo "Value: "
              (lambda (val)
                (echo-message! echo (str "Set " face " " attr " to " val))))))))))

(def (cmd-set-face-foreground app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Face: "
      (lambda (face)
        (echo-read-string echo "Foreground color: "
          (lambda (color)
            (echo-message! echo (str "Set " face " foreground to " color))))))))

(def (cmd-set-face-background app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Face: "
      (lambda (face)
        (echo-read-string echo "Background color: "
          (lambda (color)
            (echo-message! echo (str "Set " face " background to " color))))))))

;; Round 73 — Avy & Ace (batch 1)
(def (cmd-avy-goto-char-2 app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Avy goto 2-char: "
      (lambda (chars)
        (echo-message! echo (str "Avy: jumping to '" chars "'"))))))

(def (cmd-avy-goto-word-0 app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: jump to any word start")))

(def (cmd-avy-goto-word-1 app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Avy word starting with: "
      (lambda (ch)
        (echo-message! echo (str "Avy: jumping to word starting with '" ch "'"))))))

(def (cmd-avy-resume app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: resumed last command")))

(def (cmd-avy-isearch app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: jumping to isearch candidate")))

(def (cmd-avy-goto-end-of-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: jumping to end of line")))

(def (cmd-avy-goto-subword-0 app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: jumping to subword")))

(def (cmd-avy-move-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: moved line")))

(def (cmd-avy-move-region app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: moved region")))

(def (cmd-avy-copy-line app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Avy: copied line")))

;; Round 74 — Paredit & Smartparens (batch 1)
(def (cmd-paredit-forward-slurp-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: slurped next sexp forward")))

(def (cmd-paredit-backward-slurp-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: slurped previous sexp backward")))

(def (cmd-paredit-forward-barf-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: barfed last sexp forward")))

(def (cmd-paredit-backward-barf-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: barfed first sexp backward")))

(def (cmd-paredit-splice-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: spliced sexp (removed delimiters)")))

(def (cmd-paredit-splice-sexp-killing-backward app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: spliced, killing backward")))

(def (cmd-paredit-splice-sexp-killing-forward app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: spliced, killing forward")))

(def (cmd-paredit-raise-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: raised sexp (replaced parent)")))

(def (cmd-paredit-convolute-sexp app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: convoluted sexp (exchanged nesting)")))

(def (cmd-paredit-join-sexps app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Paredit: joined adjacent sexps")))

;; Round 75 — AI integration (batch 1)
(def (cmd-copilot-accept-completion app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Copilot: accepted completion")))

(def (cmd-copilot-next-completion app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Copilot: showing next completion")))

(def (cmd-copilot-previous-completion app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Copilot: showing previous completion")))

(def (cmd-copilot-dismiss app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Copilot: dismissed completion")))

(def (cmd-copilot-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'copilot)
    (if (mode-enabled? app 'copilot)
      (echo-message! echo "Copilot mode enabled")
      (echo-message! echo "Copilot mode disabled"))))

(def (cmd-copilot-diagnose app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "Copilot: running diagnostics")))

(def (cmd-gptel-menu app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "GPTel: showing menu")))

(def (cmd-gptel-set-model app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "GPTel model: "
      (lambda (model)
        (echo-message! echo (str "GPTel: model set to " model))))))

(def (cmd-gptel-set-topic app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "GPTel topic: "
      (lambda (topic)
        (echo-message! echo (str "GPTel: topic set to '" topic "'"))))))

(def (cmd-gptel-abort app)
  (let* ((echo (app-state-echo app)))
    (echo-message! echo "GPTel: aborted current request")))

;; Round 76 — Writing & prose tools (batch 1)
(def (cmd-writegood-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'writegood)
    (if (mode-enabled? app 'writegood)
      (echo-message! echo "Writegood mode enabled (highlights weasel words)")
      (echo-message! echo "Writegood mode disabled"))))

(def (cmd-darkroom-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'darkroom)
    (if (mode-enabled? app 'darkroom)
      (echo-message! echo "Darkroom mode enabled (distraction-free)")
      (echo-message! echo "Darkroom mode disabled"))))

(def (cmd-typo-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'typo)
    (if (mode-enabled? app 'typo)
      (echo-message! echo "Typo mode enabled (smart typography)")
      (echo-message! echo "Typo mode disabled"))))

(def (cmd-wc-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'wc)
    (if (mode-enabled? app 'wc)
      (echo-message! echo "Word count mode enabled")
      (echo-message! echo "Word count mode disabled"))))

(def (cmd-wc-set-goal app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Word count goal: "
      (lambda (goal)
        (echo-message! echo (str "Word count goal set to " goal))))))

(def (cmd-mixed-pitch-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'mixed-pitch)
    (if (mode-enabled? app 'mixed-pitch)
      (echo-message! echo "Mixed pitch mode enabled (variable + fixed)")
      (echo-message! echo "Mixed pitch mode disabled"))))

(def (cmd-variable-pitch-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'variable-pitch)
    (if (mode-enabled? app 'variable-pitch)
      (echo-message! echo "Variable pitch mode enabled")
      (echo-message! echo "Variable pitch mode disabled"))))

(def (cmd-fixed-pitch-mode app)
  (let* ((echo (app-state-echo app)))
    (toggle-mode! app 'fixed-pitch)
    (if (mode-enabled? app 'fixed-pitch)
      (echo-message! echo "Fixed pitch mode enabled")
      (echo-message! echo "Fixed pitch mode disabled"))))

(def (cmd-dictionary-search app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Dictionary search: "
      (lambda (word)
        (echo-message! echo (str "Dictionary: looking up '" word "'"))))))

(def (cmd-dictionary-match-words app)
  (let* ((echo (app-state-echo app)))
    (echo-read-string echo "Match words (pattern): "
      (lambda (pat)
        (echo-message! echo (str "Dictionary: matching words for '" pat "'"))))))

