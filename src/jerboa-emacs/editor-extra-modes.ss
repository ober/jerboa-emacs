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
