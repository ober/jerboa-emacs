#!chezscheme
;;; editor-extra-media.sls — EWW extras, EMMS, PDF tools, calc, avy,
;;; expand-region, smartparens, project, JSON/XML, games, and more
;;;
;;; Ported from gerbil-emacs/editor-extra-media.ss to R6RS Chez Scheme.

(library (jerboa-emacs editor-extra-media)
  (export
    ;; EWW web browser operations
    cmd-eww-back
    cmd-eww-forward
    cmd-eww-reload
    cmd-eww-download
    cmd-eww-copy-page-url
    ;; EMMS commands
    emms-find-player
    cmd-emms
    cmd-emms-play-file
    cmd-emms-pause
    cmd-emms-stop
    emms-play-track!
    cmd-emms-next
    cmd-emms-previous
    ;; PDF tools commands
    pdf-get-page-count
    pdf-extract-page
    pdf-display-page
    cmd-pdf-view-mode
    cmd-pdf-view-next-page
    cmd-pdf-view-previous-page
    cmd-pdf-view-goto-page
    ;; Calc
    cmd-calc-push
    cmd-calc-pop
    cmd-calc-dup
    cmd-calc-swap
    tui-calc-show!
    tui-calc-binary-op!
    tui-calc-unary-op!
    cmd-calc-add
    cmd-calc-sub
    cmd-calc-mul
    cmd-calc-div
    cmd-calc-mod
    cmd-calc-pow
    cmd-calc-neg
    cmd-calc-abs
    cmd-calc-sqrt
    cmd-calc-log
    cmd-calc-exp
    cmd-calc-sin
    cmd-calc-cos
    cmd-calc-tan
    cmd-calc-floor
    cmd-calc-ceiling
    cmd-calc-round
    cmd-calc-clear
    ;; Avy navigation
    avy-find-all-matches
    cmd-avy-goto-char
    cmd-avy-goto-word
    cmd-avy-goto-line
    ;; Expand-region
    expand-find-word
    expand-find-quotes
    expand-find-parens
    expand-find-line
    cmd-expand-region
    cmd-contract-region
    ;; Smartparens
    cmd-sp-forward-slurp-sexp
    cmd-sp-forward-barf-sexp
    cmd-sp-backward-slurp-sexp
    cmd-sp-backward-barf-sexp
    ;; Project
    cmd-project-switch-project
    cmd-project-find-regexp
    cmd-project-shell
    cmd-project-dired
    cmd-project-eshell
    ;; JSON/XML formatting
    cmd-json-pretty-print
    cmd-xml-format
    ;; Notifications
    cmd-notifications-list
    ;; Profiler
    cmd-profiler-report
    ;; Narrowing extras
    cmd-narrow-to-page)

  (import
    (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
    (jerboa core)
    (jerboa runtime)
    (only (jerboa prelude) path-strip-directory path-extension path-expand)
    (std sugar)
    (only (std srfi srfi-13)
      string-join string-prefix? string-trim string-contains)
    (only (std misc string) string-split)
    (chez-scintilla constants)
    (chez-scintilla scintilla)
    (chez-scintilla tui)
    (except (jerboa-emacs core) face-get)
    (only (jerboa-emacs editor-core)
      auto-save-enabled? auto-save-enabled-set! make-auto-save-path)
    (jerboa-emacs keymap)
    (jerboa-emacs buffer)
    (jerboa-emacs window)
    (jerboa-emacs modeline)
    (jerboa-emacs echo)
    (jerboa-emacs editor-extra-helpers))

  ;; Local take helper (srfi-1 not available in jerboa)
  (define (take lst n)
    (if (or (<= n 0) (null? lst)) '()
        (cons (car lst) (take (cdr lst) (- n 1)))))

  ;; --- Local stubs for not-yet-ported modules ---
  ;; editor-extra-web: EWW state and functions
  (define *eww-history* '())
  (define *eww-history-idx* 0)
  (define *eww-current-url* #f)

  (define (eww-fetch-url url)
    "Stub: fetch URL content. Returns #f until editor-extra-web is ported."
    #f)

  (define (eww-display-page app url content)
    "Stub: display EWW page. No-op until editor-extra-web is ported."
    (void))

  ;; editor-extra-web: project history
  (define *project-history* '())

  ;; editor-extra-editing2 stubs
  (define *dired-marks* '())

  (define (cmd-dired-refresh app)
    "Stub: refresh dired. No-op until editor-extra-editing2 is ported."
    (void))

  ;; --- Helper: run shell command and capture stdout ---
  (define (run-cmd-capture cmd-str . args)
    "Run a command with arguments, capture stdout. Returns string or #f."
    (guard (e [#t #f])
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports
                      (string-append cmd-str
                        (apply string-append
                          (map (lambda (a) (string-append " " a)) args)))
                      'block
                      (native-transcoder))))
        (close-port to-stdin)
        (let ((result (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (if (eof-object? result) #f result)))))

  (define (run-cmd-capture/input cmd-str input-text)
    "Run a command, feed input-text to stdin, capture stdout. Returns string or #f."
    (guard (e [#t #f])
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports cmd-str 'block (native-transcoder))))
        (display input-text to-stdin)
        (close-port to-stdin)
        (let ((result (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (if (eof-object? result) #f result)))))

  (define (run-cmd-fire-and-forget cmd-str)
    "Run a command without capturing output."
    (guard (e [#t (void)])
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports cmd-str 'block (native-transcoder))))
        (close-port to-stdin)
        (close-port from-stdout)
        (close-port from-stderr))))

  ;; --- Helper: list delete (remove first match) ---
  (define (list-delete item lst)
    (remp (lambda (x) (equal? x item)) lst))

  ;; --- Task #48: EWW, EMMS, PDF tools, Calc, ace-jump, expand-region, etc. ---

  ;; EWW web browser operations
  (define (cmd-eww-back app)
    "Go back in EWW history."
    (let ((echo (app-state-echo app)))
      (if (>= (+ *eww-history-idx* 1) (length *eww-history*))
        (echo-message! echo "No previous page")
        (let* ((new-idx (+ *eww-history-idx* 1))
               (url (list-ref *eww-history* new-idx)))
          (set! *eww-history-idx* new-idx)
          (let ((content (eww-fetch-url url)))
            (if content
              (eww-display-page app url content)
              (echo-error! echo "Failed to fetch page")))))))

  (define (cmd-eww-forward app)
    "Go forward in EWW history."
    (let ((echo (app-state-echo app)))
      (if (<= *eww-history-idx* 0)
        (echo-message! echo "No next page")
        (let* ((new-idx (- *eww-history-idx* 1))
               (url (list-ref *eww-history* new-idx)))
          (set! *eww-history-idx* new-idx)
          (let ((content (eww-fetch-url url)))
            (if content
              (eww-display-page app url content)
              (echo-error! echo "Failed to fetch page")))))))

  (define (cmd-eww-reload app)
    "Reload current EWW page."
    (let ((echo (app-state-echo app)))
      (if (not *eww-current-url*)
        (echo-message! echo "No page to reload")
        (begin
          (echo-message! echo (string-append "Reloading: " *eww-current-url*))
          (let ((content (eww-fetch-url *eww-current-url*)))
            (if content
              (eww-display-page app *eww-current-url* content)
              (echo-error! echo "Failed to reload page")))))))

  (define (cmd-eww-download app)
    "Download file from URL."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (url (echo-read-string echo "Download URL: " row width)))
      (when (and url (not (string=? url "")))
        (let ((filename (path-strip-directory url)))
          (echo-message! echo (string-append "Downloading: " filename))
          (guard (e [#t (echo-error! echo "Download failed")])
            (run-cmd-fire-and-forget
              (string-append "curl -sLO " url))
            (echo-message! echo (string-append "Downloaded: " filename)))))))

  (define (cmd-eww-copy-page-url app)
    "Copy current EWW page URL to kill ring."
    (let ((echo (app-state-echo app)))
      (if (not *eww-current-url*)
        (echo-message! echo "No URL to copy")
        (begin
          ;; Add to kill ring
          (let ((kill-ring (app-state-kill-ring app)))
            (app-state-kill-ring-set! app (cons *eww-current-url* kill-ring)))
          (echo-message! echo (string-append "Copied: " *eww-current-url*))))))

  ;; EMMS (Emacs Multimedia System) - uses mpv or mplayer
  (define *emms-player-process* #f)  ; current player process
  (define *emms-current-file* #f)    ; current playing file
  (define *emms-paused* #f)          ; paused state
  (define *emms-playlist* '())       ; list of file paths
  (define *emms-playlist-idx* 0)     ; current index into playlist

  (define (emms-find-player)
    "Find available media player."
    (cond
      ((file-exists? "/usr/bin/mpv") "mpv")
      ((file-exists? "/usr/bin/mplayer") "mplayer")
      ((file-exists? "/usr/bin/ffplay") "ffplay")
      (else #f)))

  (define (cmd-emms app)
    "Open EMMS player - show playlist or current track info."
    (let ((echo (app-state-echo app)))
      (if *emms-current-file*
        (echo-message! echo (string-append "Now playing: " (path-strip-directory *emms-current-file*)
                                          (if *emms-paused* " [PAUSED]" "")))
        (echo-message! echo "No track playing. Use emms-play-file to start."))))

  (define (emms-stop-existing!)
    "Stop any existing player process."
    (when *emms-player-process*
      (guard (e [#t #f])
        (close-port *emms-player-process*))))

  (define (emms-start-player! player file)
    "Start a new player process for the given file."
    (guard (e [#t #f])
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports
                      (string-append player " --quiet " file)
                      'block
                      (native-transcoder))))
        ;; We don't need to interact with it, just close our ends
        (close-port to-stdin)
        (close-port from-stdout)
        (close-port from-stderr)
        pid)))

  (define (cmd-emms-play-file app)
    "Play a media file using mpv or mplayer."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (player (emms-find-player))
           (file (echo-read-string echo "Media file: " row width)))
      (if (not player)
        (echo-error! echo "No media player found (mpv, mplayer, or ffplay)")
        (when (and file (not (string=? file "")))
          (if (not (file-exists? file))
            (echo-error! echo "File not found")
            (begin
              ;; Stop any existing playback
              (emms-stop-existing!)
              ;; Start new playback
              (set! *emms-player-process* (emms-start-player! player file))
              (set! *emms-current-file* file)
              (set! *emms-paused* #f)
              ;; Add to playlist if not already present
              (unless (member file *emms-playlist*)
                (set! *emms-playlist* (append *emms-playlist* (list file))))
              ;; Update playlist index
              (let loop ((i 0) (pl *emms-playlist*))
                (when (pair? pl)
                  (if (equal? (car pl) file)
                    (set! *emms-playlist-idx* i)
                    (loop (+ i 1) (cdr pl)))))
              (echo-message! echo (string-append "Playing: " (path-strip-directory file)))))))))

  (define (cmd-emms-pause app)
    "Pause/resume playback (sends signal to player)."
    (let ((echo (app-state-echo app)))
      (if (not *emms-player-process*)
        (echo-message! echo "No track playing")
        (begin
          (set! *emms-paused* (not *emms-paused*))
          (echo-message! echo (if *emms-paused* "Paused" "Resumed"))))))

  (define (cmd-emms-stop app)
    "Stop playback."
    (let ((echo (app-state-echo app)))
      (when *emms-player-process*
        (emms-stop-existing!)
        (set! *emms-player-process* #f)
        (set! *emms-current-file* #f)
        (set! *emms-paused* #f))
      (echo-message! echo "Stopped")))

  (define (emms-play-track! app file)
    "Play a specific track file, updating state."
    (let ((echo (app-state-echo app))
          (player (emms-find-player)))
      (if (not player)
        (echo-error! echo "No media player found")
        (begin
          ;; Stop existing
          (emms-stop-existing!)
          ;; Start new
          (set! *emms-player-process* (emms-start-player! player file))
          (set! *emms-current-file* file)
          (set! *emms-paused* #f)
          (echo-message! echo (string-append "Playing: " (path-strip-directory file)))))))

  (define (cmd-emms-next app)
    "Play the next track in the playlist."
    (let ((echo (app-state-echo app)))
      (if (null? *emms-playlist*)
        (echo-message! echo "Playlist is empty. Use emms-play-file to add tracks.")
        (begin
          (set! *emms-playlist-idx*
            (modulo (+ *emms-playlist-idx* 1) (length *emms-playlist*)))
          (emms-play-track! app (list-ref *emms-playlist* *emms-playlist-idx*))))))

  (define (cmd-emms-previous app)
    "Play the previous track in the playlist."
    (let ((echo (app-state-echo app)))
      (if (null? *emms-playlist*)
        (echo-message! echo "Playlist is empty. Use emms-play-file to add tracks.")
        (begin
          (set! *emms-playlist-idx*
            (modulo (- *emms-playlist-idx* 1) (length *emms-playlist*)))
          (emms-play-track! app (list-ref *emms-playlist* *emms-playlist-idx*))))))

  ;; PDF tools - basic PDF viewing using pdftotext
  (define *pdf-current-file* #f)  ; current PDF file
  (define *pdf-current-page* 1)   ; current page number
  (define *pdf-total-pages* 1)    ; total pages

  (define (pdf-get-page-count file)
    "Get total pages in a PDF file."
    (guard (e [#t 1])
      (let ((output (run-cmd-capture "pdfinfo" file)))
        (if output
          ;; Find "Pages:" line
          (let* ((lines (string-split output #\newline))
                 (pages-line (find (lambda (l) (string-prefix? "Pages:" l)) lines)))
            (if pages-line
              (let ((num (string->number (string-trim (substring pages-line 6 (string-length pages-line))))))
                (or num 1))
              1))
          1))))

  (define (pdf-extract-page file page)
    "Extract text from a specific page of a PDF."
    (guard (e [#t #f])
      (run-cmd-capture "pdftotext"
        (string-append "-f " (number->string page)
                       " -l " (number->string page)
                       " -layout " file " -"))))

  (define (pdf-display-page app)
    "Display current PDF page."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (content (pdf-extract-page *pdf-current-file* *pdf-current-page*))
           (text (string-append "PDF: " (path-strip-directory *pdf-current-file*)
                               " - Page " (number->string *pdf-current-page*)
                               "/" (number->string *pdf-total-pages*) "\n"
                               (make-string 60 #\-) "\n\n"
                               (or content "Could not extract text from page")
                               "\n\n[n: next, p: previous, g: goto, q: quit]")))
      (let ((buf (or (buffer-by-name "*PDF View*")
                     (buffer-create! "*PDF View*" ed))))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! win buf)
        (editor-set-text ed text)
        (editor-goto-pos ed 0)
        (editor-set-read-only ed #t))))

  (define (cmd-pdf-view-mode app)
    "Open a PDF file for viewing."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (file (echo-read-string echo "PDF file: " row width)))
      (when (and file (not (string=? file "")))
        (if (not (file-exists? file))
          (echo-error! echo "File not found")
          (begin
            (set! *pdf-current-file* file)
            (set! *pdf-current-page* 1)
            (set! *pdf-total-pages* (pdf-get-page-count file))
            (pdf-display-page app))))))

  (define (cmd-pdf-view-next-page app)
    "Go to next page in PDF."
    (let ((echo (app-state-echo app)))
      (if (not *pdf-current-file*)
        (echo-message! echo "No PDF open")
        (if (>= *pdf-current-page* *pdf-total-pages*)
          (echo-message! echo "Already at last page")
          (begin
            (set! *pdf-current-page* (+ *pdf-current-page* 1))
            (pdf-display-page app))))))

  (define (cmd-pdf-view-previous-page app)
    "Go to previous page in PDF."
    (let ((echo (app-state-echo app)))
      (if (not *pdf-current-file*)
        (echo-message! echo "No PDF open")
        (if (<= *pdf-current-page* 1)
          (echo-message! echo "Already at first page")
          (begin
            (set! *pdf-current-page* (- *pdf-current-page* 1))
            (pdf-display-page app))))))

  (define (cmd-pdf-view-goto-page app)
    "Go to specific PDF page."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if (not *pdf-current-file*)
        (echo-message! echo "No PDF open")
        (let* ((input (echo-read-string echo (string-append "Go to page (1-" (number->string *pdf-total-pages*) "): ") row width))
               (page (and input (string->number input))))
          (if (and page (> page 0) (<= page *pdf-total-pages*))
            (begin
              (set! *pdf-current-page* page)
              (pdf-display-page app))
            (echo-error! echo "Invalid page number"))))))

  ;; Calc stack operations
  (define *calc-stack* '())

  (define (cmd-calc-push app)
    "Push value onto calc stack."
    (let ((val (app-read-string app "Push value: ")))
      (when (and val (not (string=? val "")))
        (let ((num (string->number val)))
          (if num
            (begin
              (set! *calc-stack* (cons num *calc-stack*))
              (echo-message! (app-state-echo app)
                (string-append "Stack: "
                  (string-join (map (lambda (n) (number->string n))
                                 (if (> (length *calc-stack*) 5) (take *calc-stack* 5) *calc-stack*))
                               " "))))
            (echo-message! (app-state-echo app) "Not a number"))))))

  (define (cmd-calc-pop app)
    "Pop value from calc stack."
    (if (null? *calc-stack*)
      (echo-message! (app-state-echo app) "Stack empty")
      (let ((val (car *calc-stack*)))
        (set! *calc-stack* (cdr *calc-stack*))
        (echo-message! (app-state-echo app) (string-append "Popped: " (number->string val))))))

  (define (cmd-calc-dup app)
    "Duplicate top of calc stack."
    (if (null? *calc-stack*)
      (echo-message! (app-state-echo app) "Stack empty")
      (begin
        (set! *calc-stack* (cons (car *calc-stack*) *calc-stack*))
        (echo-message! (app-state-echo app) (string-append "Duplicated: " (number->string (car *calc-stack*)))))))

  (define (cmd-calc-swap app)
    "Swap top two calc stack items."
    (if (or (null? *calc-stack*) (null? (cdr *calc-stack*)))
      (echo-message! (app-state-echo app) "Need 2+ values to swap")
      (let ((a (car *calc-stack*))
            (b (cadr *calc-stack*)))
        (set! *calc-stack* (cons b (cons a (cddr *calc-stack*))))
        (echo-message! (app-state-echo app)
          (string-append "Swapped: " (number->string b) " <-> " (number->string a))))))

  ;;; TUI Calc arithmetic and math operations

  (define (tui-calc-show! app)
    (let* ((echo (app-state-echo app))
           (top5 (if (> (length *calc-stack*) 5) (take *calc-stack* 5) *calc-stack*)))
      (if (null? top5)
        (echo-message! echo "Stack: (empty)")
        (echo-message! echo (string-append "Stack: "
          (string-join (map (lambda (n)
                              (call-with-string-output-port
                                (lambda (p) (display n p))))
                            top5) " "))))))

  (define (tui-calc-binary-op! app label op-fn)
    (let* ((echo (app-state-echo app)) (st *calc-stack*))
      (if (< (length st) 2)
        (echo-error! echo (string-append "calc-" label ": need 2 values"))
        (let* ((b (car st)) (a (cadr st)) (rest (cddr st))
               (result (guard (e [#t #f]) (op-fn a b))))
          (if result
            (begin (set! *calc-stack* (cons result rest)) (tui-calc-show! app))
            (echo-error! echo (string-append "calc-" label ": error")))))))

  (define (tui-calc-unary-op! app label op-fn)
    (let* ((echo (app-state-echo app)) (st *calc-stack*))
      (if (null? st)
        (echo-error! echo (string-append "calc-" label ": stack empty"))
        (let* ((a (car st)) (rest (cdr st))
               (result (guard (e [#t #f]) (op-fn a))))
          (if result
            (begin (set! *calc-stack* (cons result rest)) (tui-calc-show! app))
            (echo-error! echo (string-append "calc-" label ": error")))))))

  (define (cmd-calc-add     app) (tui-calc-binary-op! app "+" +))
  (define (cmd-calc-sub     app) (tui-calc-binary-op! app "-" -))
  (define (cmd-calc-mul     app) (tui-calc-binary-op! app "*" *))
  (define (cmd-calc-div     app) (tui-calc-binary-op! app "/" /))
  (define (cmd-calc-mod     app) (tui-calc-binary-op! app "mod" modulo))
  (define (cmd-calc-pow     app) (tui-calc-binary-op! app "pow" expt))
  (define (cmd-calc-neg     app) (tui-calc-unary-op! app "neg" (lambda (a) (- a))))
  (define (cmd-calc-abs     app) (tui-calc-unary-op! app "abs" abs))
  (define (cmd-calc-sqrt    app) (tui-calc-unary-op! app "sqrt" sqrt))
  (define (cmd-calc-log     app) (tui-calc-unary-op! app "log" log))
  (define (cmd-calc-exp     app) (tui-calc-unary-op! app "exp" exp))
  (define (cmd-calc-sin     app) (tui-calc-unary-op! app "sin" sin))
  (define (cmd-calc-cos     app) (tui-calc-unary-op! app "cos" cos))
  (define (cmd-calc-tan     app) (tui-calc-unary-op! app "tan" tan))
  (define (cmd-calc-floor   app) (tui-calc-unary-op! app "floor" floor))
  (define (cmd-calc-ceiling app) (tui-calc-unary-op! app "ceiling" ceiling))
  (define (cmd-calc-round   app) (tui-calc-unary-op! app "round" round))
  (define (cmd-calc-clear   app)
    (set! *calc-stack* '())
    (echo-message! (app-state-echo app) "Stack: (empty \x2014; cleared)"))

  ;; Ace-jump / Avy navigation - quick cursor movement
  ;; Simplified implementation: searches for matches in visible text and jumps

  (define (avy-find-all-matches ed char-or-pattern)
    "Find all positions matching char or pattern in editor text."
    (let* ((text (editor-get-text ed))
           (len (string-length text))
           (pattern (if (char? char-or-pattern)
                      (string char-or-pattern)
                      char-or-pattern)))
      (let loop ((i 0) (matches '()))
        (if (>= i len)
          (reverse matches)
          (if (and (< (+ i (string-length pattern)) len)
                   (string-ci=? (substring text i (+ i (string-length pattern))) pattern))
            (loop (+ i 1) (cons i matches))
            (loop (+ i 1) matches))))))

  (define (cmd-avy-goto-char app)
    "Jump to character - prompts for char, finds all occurrences, jumps to selected one."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Jump to char: " row width)))
      (when (and input (> (string-length input) 0))
        (let* ((ch (string-ref input 0))
               (matches (avy-find-all-matches ed ch)))
          (if (null? matches)
            (echo-message! echo "No matches found")
            (if (= (length matches) 1)
              ;; Single match - jump directly
              (begin
                (editor-goto-pos ed (car matches))
                (echo-message! echo "Jumped!"))
              ;; Multiple matches - jump to first for now
              (begin
                (editor-goto-pos ed (car matches))
                (echo-message! echo (string-append "Jumped to first of "
                                                  (number->string (length matches))
                                                  " matches (use search for more)")))))))))

  (define (cmd-avy-goto-word app)
    "Jump to word - prompts for word prefix, finds matches, jumps."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (prefix (echo-read-string echo "Jump to word starting with: " row width)))
      (when (and prefix (not (string=? prefix "")))
        ;; Find word boundaries and match prefix
        (let* ((text (editor-get-text ed))
               (len (string-length text))
               (plen (string-length prefix)))
          (let loop ((i 0) (in-word #f) (matches '()))
            (if (>= i len)
              (if (null? matches)
                (echo-message! echo "No matching words found")
                (begin
                  (editor-goto-pos ed (car (reverse matches)))
                  (echo-message! echo (string-append "Jumped to first of "
                                                    (number->string (length matches)) " matches"))))
              (let ((ch (string-ref text i)))
                (cond
                  ((and (not in-word) (char-alphabetic? ch))
                   ;; Word start - check prefix
                   (if (and (<= (+ i plen) len)
                            (string-ci=? (substring text i (+ i plen)) prefix))
                     (loop (+ i 1) #t (cons i matches))
                     (loop (+ i 1) #t matches)))
                  ((and in-word (not (char-alphabetic? ch)))
                   (loop (+ i 1) #f matches))
                  (else
                   (loop (+ i 1) in-word matches))))))))))

  (define (cmd-avy-goto-line app)
    "Jump to line - prompts for line number."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Jump to line: " row width)))
      (when (and input (not (string=? input "")))
        (let ((line (string->number input)))
          (if (and line (> line 0))
            (begin
              (editor-goto-line ed line)
              (echo-message! echo (string-append "Line " (number->string line))))
            (echo-error! echo "Invalid line number"))))))

  ;; Expand-region - progressively expand selection
  ;; Expansion order: word -> symbol -> quotes -> parens -> line -> paragraph

  (define *expand-region-history* '())  ; stack of (start . end) for contract

  (define (expand-find-word ed pos text)
    "Find word boundaries around pos."
    (let* ((len (string-length text))
           (start (let loop ((i pos))
                    (if (or (< i 0)
                            (not (or (char-alphabetic? (string-ref text i))
                                     (char-numeric? (string-ref text i))
                                     (char=? (string-ref text i) #\_))))
                      (+ i 1)
                      (loop (- i 1)))))
           (end (let loop ((i pos))
                  (if (or (>= i len)
                          (not (or (char-alphabetic? (string-ref text i))
                                   (char-numeric? (string-ref text i))
                                   (char=? (string-ref text i) #\_))))
                    i
                    (loop (+ i 1))))))
      (if (< start end) (cons start end) #f)))

  (define (expand-find-quotes ed pos text)
    "Find enclosing quotes around pos."
    (let* ((len (string-length text))
           ;; Look backwards for opening quote
           (start (let loop ((i (- pos 1)))
                    (if (< i 0)
                      #f
                      (let ((ch (string-ref text i)))
                        (if (memv ch '(#\" #\' #\`))
                          i
                          (loop (- i 1)))))))
           ;; Look forwards for closing quote
           (end (and start
                     (let ((quote-char (string-ref text start)))
                       (let loop ((i (+ pos 1)))
                         (if (>= i len)
                           #f
                           (let ((ch (string-ref text i)))
                             (if (char=? ch quote-char)
                               (+ i 1)
                               (loop (+ i 1))))))))))
      (if (and start end) (cons start end) #f)))

  (define (expand-find-parens ed pos text)
    "Find enclosing parens around pos."
    (let ((open (sp-find-enclosing-paren ed pos #\( #\))))
      (if open
        (let ((close (sp-find-matching-close ed (+ open 1) #\( #\))))
          (if close (cons open (+ close 1)) #f))
        #f)))

  (define (expand-find-line ed pos text)
    "Find line boundaries around pos."
    (let* ((len (string-length text))
           (start (let loop ((i pos))
                    (if (or (< i 0) (char=? (string-ref text i) #\newline))
                      (+ i 1)
                      (loop (- i 1)))))
           (end (let loop ((i pos))
                  (if (or (>= i len) (char=? (string-ref text i) #\newline))
                    i
                    (loop (+ i 1))))))
      (cons start end)))

  (define (cmd-expand-region app)
    "Expand selection region progressively."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed))
           (text (editor-get-text ed)))
      ;; Save current selection for contract
      (when (not (= sel-start sel-end))
        (set! *expand-region-history* (cons (cons sel-start sel-end) *expand-region-history*)))
      ;; Try expanding in order
      (let ((current-size (- sel-end sel-start)))
        (let try-expand ((expansions (list
                                       (expand-find-word ed pos text)
                                       (expand-find-quotes ed pos text)
                                       (expand-find-parens ed pos text)
                                       (expand-find-line ed pos text))))
          (if (null? expansions)
            (echo-message! echo "Cannot expand further")
            (let ((exp (car expansions)))
              (if (and exp (> (- (cdr exp) (car exp)) current-size))
                (begin
                  (editor-set-selection ed (car exp) (cdr exp))
                  (echo-message! echo "Expanded"))
                (try-expand (cdr expansions)))))))))

  (define (cmd-contract-region app)
    "Contract selection to previous size."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win)))
      (if (null? *expand-region-history*)
        (begin
          (editor-set-selection ed (editor-get-current-pos ed) (editor-get-current-pos ed))
          (echo-message! echo "Selection cleared"))
        (let ((prev (car *expand-region-history*)))
          (set! *expand-region-history* (cdr *expand-region-history*))
          (editor-set-selection ed (car prev) (cdr prev))
          (echo-message! echo "Contracted")))))

  ;; Smartparens - structural editing for s-expressions
  ;; These commands manipulate parentheses around expressions

  (define (cmd-sp-forward-slurp-sexp app)
    "Slurp the next sexp into the current list. (|a b) c -> (|a b c)"
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (echo (app-state-echo app)))
      ;; Find the closing paren of enclosing list
      (let ((open-pos (sp-find-enclosing-paren ed pos #\( #\))))
        (if (not open-pos)
          (echo-message! echo "Not inside a list")
          (let ((close-pos (sp-find-matching-close ed (+ open-pos 1) #\( #\))))
            (if (not close-pos)
              (echo-message! echo "Unbalanced parens")
              ;; Find the next sexp after the close paren
              (let ((next-end (sp-find-sexp-end ed (+ close-pos 1))))
                (if (not next-end)
                  (echo-message! echo "Nothing to slurp")
                  (begin
                    ;; Delete the close paren
                    (editor-set-selection ed close-pos (+ close-pos 1))
                    (editor-replace-selection ed "")
                    ;; Insert close paren after the slurped sexp
                    (editor-insert-text ed next-end ")")
                    (echo-message! echo "Slurped forward"))))))))))

  (define (cmd-sp-forward-barf-sexp app)
    "Barf the last sexp out of the current list. (a b| c) -> (a b|) c"
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
              ;; Find the last sexp before the close paren
              (let loop ((i (- close-pos 1)))
                (if (<= i open-pos)
                  (echo-message! echo "Nothing to barf")
                  (let ((ch (string-ref text i)))
                    (cond
                      ((char-whitespace? ch) (loop (- i 1)))
                      (else
                       ;; Found end of last sexp, find its start
                       (let find-start ((j i))
                         (if (<= j open-pos)
                           (echo-message! echo "Nothing to barf")
                           (let ((c (string-ref text j)))
                             (cond
                               ((char=? c #\))
                                (let ((match (sp-find-enclosing-paren ed (+ j 1) #\( #\))))
                                  (if match
                                    (begin
                                      ;; Delete close paren, insert before sexp
                                      (editor-set-selection ed close-pos (+ close-pos 1))
                                      (editor-replace-selection ed "")
                                      (editor-insert-text ed match ")")
                                      (echo-message! echo "Barfed forward"))
                                    (echo-message! echo "Parse error"))))
                               ((char-whitespace? c) (find-start (- j 1)))
                               (else
                                ;; At end of atom, scan back
                                (let scan-atom ((k j))
                                  (if (<= k open-pos)
                                    (begin
                                      (editor-set-selection ed close-pos (+ close-pos 1))
                                      (editor-replace-selection ed "")
                                      (editor-insert-text ed (+ open-pos 1) ")")
                                      (echo-message! echo "Barfed forward"))
                                    (let ((cc (string-ref text k)))
                                      (if (or (char-whitespace? cc)
                                              (memv cc '(#\( #\))))
                                        (begin
                                          (editor-set-selection ed close-pos (+ close-pos 1))
                                          (editor-replace-selection ed "")
                                          (editor-insert-text ed (+ k 1) ")")
                                          (echo-message! echo "Barfed forward"))
                                        (scan-atom (- k 1))))))))))))))))))))))

  (define (cmd-sp-backward-slurp-sexp app)
    "Slurp the previous sexp into the current list. a (|b c) -> (a |b c)"
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (echo (app-state-echo app)))
      (let ((open-pos (sp-find-enclosing-paren ed pos #\( #\))))
        (if (not open-pos)
          (echo-message! echo "Not inside a list")
          ;; Find the sexp before the open paren
          (let find-prev ((i (- open-pos 1)))
            (if (< i 0)
              (echo-message! echo "Nothing to slurp")
              (let ((ch (string-ref text i)))
                (cond
                  ((char-whitespace? ch) (find-prev (- i 1)))
                  ((char=? ch #\))
                   ;; End of sexp, find its start
                   (let ((match (sp-find-enclosing-paren ed (+ i 1) #\( #\))))
                     (if match
                       (begin
                         ;; Delete the open paren, insert before the sexp
                         (editor-set-selection ed open-pos (+ open-pos 1))
                         (editor-replace-selection ed "")
                         (editor-insert-text ed match "(")
                         (echo-message! echo "Slurped backward"))
                       (echo-message! echo "Parse error"))))
                  (else
                   ;; Atom, find its start
                   (let scan-back ((j i))
                     (if (< j 0)
                       (begin
                         (editor-set-selection ed open-pos (+ open-pos 1))
                         (editor-replace-selection ed "")
                         (editor-insert-text ed 0 "(")
                         (echo-message! echo "Slurped backward"))
                       (let ((c (string-ref text j)))
                         (if (or (char-whitespace? c)
                                 (memv c '(#\( #\))))
                           (begin
                             (editor-set-selection ed open-pos (+ open-pos 1))
                             (editor-replace-selection ed "")
                             (editor-insert-text ed (+ j 1) "(")
                             (echo-message! echo "Slurped backward"))
                           (scan-back (- j 1)))))))))))))))

  (define (cmd-sp-backward-barf-sexp app)
    "Barf the first sexp out of the current list. (a |b c) -> a (|b c)"
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (echo (app-state-echo app)))
      (let ((open-pos (sp-find-enclosing-paren ed pos #\( #\))))
        (if (not open-pos)
          (echo-message! echo "Not inside a list")
          ;; Find the first sexp after the open paren
          (let find-first ((i (+ open-pos 1)))
            (if (>= i (string-length text))
              (echo-message! echo "Nothing to barf")
              (let ((ch (string-ref text i)))
                (cond
                  ((char-whitespace? ch) (find-first (+ i 1)))
                  (else
                   ;; Found start of first sexp, find its end
                   (let ((sexp-end (sp-find-sexp-end ed i)))
                     (if (not sexp-end)
                       (echo-message! echo "Parse error")
                       (begin
                         ;; Delete open paren, insert after first sexp
                         (editor-set-selection ed open-pos (+ open-pos 1))
                         (editor-replace-selection ed "")
                         (editor-insert-text ed sexp-end "(")
                         (echo-message! echo "Barfed backward")))))))))))))

  ;; Project.el - project detection and navigation
  ;; Projects are detected by presence of .git, .hg, .svn, or project markers

  (define (cmd-project-switch-project app)
    "Switch to another project from history or prompt for directory."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if (null? *project-history*)
        ;; No history - prompt for directory
        (let ((dir (echo-read-string echo "Project directory: " row width)))
          (when (and dir (directory-exists? dir))
            (let ((root (project-find-root dir)))
              (if root
                (begin
                  (set! *project-history* (cons root (list-delete root *project-history*)))
                  (current-directory root)
                  (echo-message! echo (string-append "Project: " root)))
                (echo-message! echo "No project found at that location")))))
        ;; Show project history
        (let* ((win (current-window fr))
               (ed (edit-window-editor win))
               (buf (buffer-create! "*Projects*" ed))
               (text (string-append "Known projects:\n\n"
                       (string-join
                         (map (lambda (p) (string-append "  " p)) *project-history*)
                         "\n")
                       "\n\nPress Enter on a line to switch to that project.")))
          (buffer-attach! ed buf)
          (edit-window-buffer-set! win buf)
          (editor-set-text ed text)
          (editor-goto-pos ed 0)
          (editor-set-read-only ed #t)))))

  (define (cmd-project-find-regexp app)
    "Find regexp in project files using grep."
    (let* ((echo (app-state-echo app))
           (root (project-current app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr)))
      (if (not root)
        (echo-message! echo "Not in a project")
        (let ((pattern (echo-read-string echo "Project grep: " row width)))
          (when (and pattern (not (string=? pattern "")))
            (guard (e [#t (echo-error! echo "grep failed")])
              (let* ((output (run-cmd-capture
                               (string-append "grep -rn '" pattern "' " root
                                 " --include='*.ss' --include='*.scm'"
                                 " --include='*.py' --include='*.js'"
                                 " --include='*.go' --include='*.rs'"
                                 " --include='*.c' --include='*.h'"
                                 " --include='*.cpp' --include='*.hpp'"
                                 " --include='*.md' --include='*.txt'")))
                     (win (current-window fr))
                     (ed (edit-window-editor win))
                     (buf (buffer-create! (string-append "*Project grep: " pattern "*") ed))
                     (text (if output
                             (string-append "Project grep results for: " pattern "\n\n" output)
                             "No matches found.")))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! win buf)
                (editor-set-text ed text)
                (editor-goto-pos ed 0)
                (editor-set-read-only ed #t))))))))

  (define (cmd-project-shell app)
    "Open shell in project root."
    (let* ((echo (app-state-echo app))
           (root (project-current app)))
      (if (not root)
        (echo-message! echo "Not in a project")
        (begin
          (current-directory root)
          ;; Add to project history
          (set! *project-history* (cons root (list-delete root *project-history*)))
          ;; Open shell
          (execute-command! app 'shell)
          (echo-message! echo (string-append "Shell in project: " root))))))

  (define (cmd-project-dired app)
    "Open dired at project root."
    (let* ((echo (app-state-echo app))
           (root (project-current app)))
      (if (not root)
        (echo-message! echo "Not in a project")
        (begin
          ;; Add to project history
          (set! *project-history* (cons root (list-delete root *project-history*)))
          (execute-command! app 'dired)))))

  (define (cmd-project-eshell app)
    "Open eshell in project root."
    (let* ((echo (app-state-echo app))
           (root (project-current app)))
      (if (not root)
        (echo-message! echo "Not in a project")
        (begin
          (current-directory root)
          ;; Add to project history
          (set! *project-history* (cons root (list-delete root *project-history*)))
          ;; Open eshell
          (execute-command! app 'eshell)
          (echo-message! echo (string-append "Eshell in project: " root))))))

  ;; JSON formatting
  (define (cmd-json-pretty-print app)
    "Pretty-print JSON in region or buffer."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (echo-message! (app-state-echo app) "Select JSON region first")
        (let* ((text (substring (editor-get-text ed) start end))
               (result (run-cmd-capture/input "python3 -m json.tool" text)))
          (if result
            (begin
              (send-message ed SCI_SETTARGETSTART start 0)
              (send-message ed SCI_SETTARGETEND end 0)
              (send-message/string ed SCI_REPLACETARGET result)
              (echo-message! (app-state-echo app) "JSON formatted"))
            (echo-message! (app-state-echo app) "JSON format failed"))))))

  ;; XML formatting -- uses xmllint if available
  (define (cmd-xml-format app)
    "Format XML in region or buffer using xmllint."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (editor-get-text ed)))
      (guard (e [#t (echo-error! (app-state-echo app) "xmllint not available")])
        (let ((result (run-cmd-capture/input "xmllint --format -" text)))
          (if (and result (> (string-length result) 0))
            (begin (editor-set-text ed result)
                   (echo-message! (app-state-echo app) "XML formatted"))
            (echo-error! (app-state-echo app) "XML format failed"))))))

  ;; Desktop notifications
  (define (cmd-notifications-list app)
    "List desktop notifications using notify-send or dunstctl."
    (guard (e [#t (echo-message! (app-state-echo app) "No notification daemon available")])
      (let ((out (run-cmd-capture "dunstctl" "history")))
        (if out
          (open-output-buffer app "*Notifications*" out)
          (echo-message! (app-state-echo app) "No notifications")))))

  ;; Profiler
  (define (cmd-profiler-report app)
    "Show profiler report -- displays GC and memory statistics."
    (let* ((stats (call-with-string-output-port
                    (lambda (p)
                      (display "Profiler Report\n\n" p)
                      (display "GC Statistics:\n" p)
                      (collect)
                      (let ((info (statistics)))
                        (display (string-append "  Bytes allocated: "
                                   (number->string (bytes-allocated)) "\n") p)
                        (display (string-append "  Collections:     "
                                   (number->string (collections)) "\n") p)
                        (display (string-append "  CPU time:        "
                                   (number->string (cpu-time)) "ms\n") p)
                        (display (string-append "  Real time:       "
                                   (number->string (real-time)) "ms\n") p))))))
      (open-output-buffer app "*Profiler*" stats)))

  ;; Narrowing extras
  (define (cmd-narrow-to-page app)
    "Narrow to current page -- finds page delimiters (form feeds)."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (len (string-length text))
           (page-start (let loop ((i (- pos 1)))
                         (cond ((< i 0) 0)
                               ((char=? (string-ref text i) #\page) (+ i 1))
                               (else (loop (- i 1))))))
           (page-end (let loop ((i pos))
                       (cond ((>= i len) len)
                             ((char=? (string-ref text i) #\page) i)
                             (else (loop (+ i 1)))))))
      (echo-message! (app-state-echo app)
        (string-append "Page: " (number->string page-start) "-" (number->string page-end)))))

) ;; end library
