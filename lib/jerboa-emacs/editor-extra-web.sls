#!chezscheme
;;; editor-extra-web.sls — EWW browser, windmove, winner, tab-bar,
;;; URL encode/decode, JSON format, HTML entities, CSV, markdown, and
;;; miscellaneous editing/display toggle commands.
;;;
;;; Ported from gerbil-emacs/editor-extra-web.ss to R6RS Chez Scheme.

(library (jerboa-emacs editor-extra-web)
  (export
    ;; EWW state
    ;; EWW functions
    eww-ensure-context!
    eww-fetch-html
    eww-render-html
    eww-assemble-text-runs
    eww-fetch-url
    eww-display-page
    cmd-eww
    cmd-eww-browse-url
    cmd-browse-url-at-point
    ;; Windmove
    cmd-windmove-left
    cmd-windmove-right
    cmd-windmove-up
    cmd-windmove-down
    ;; Winner mode
    winner-save-config!
    winner-restore-config!
    cmd-winner-undo
    cmd-winner-redo
    ;; Tab bar
    tab-save-current!
    tab-restore!
    cmd-tab-new
    cmd-tab-close
    cmd-tab-next
    cmd-tab-previous
    cmd-tab-rename
    cmd-tab-move
    ;; URL encode/decode
    url-encode
    hex-digit-value
    url-decode
    cmd-url-encode-region
    cmd-url-decode-region
    ;; JSON format/minify
    json-pretty-print
    cmd-json-format-buffer
    cmd-json-minify-buffer
    ;; HTML entities
    html-decode-entities
    html-encode-entities
    cmd-html-encode-region
    cmd-html-decode-region
    ;; Backup
    create-backup-file!
    ;; Large/binary file checks
    large-file?
    binary-file?
    cmd-find-file-with-warnings
    ;; Encoding detection
    detect-file-encoding
    cmd-detect-encoding
    ;; JSON sort keys
    cmd-json-sort-keys
    ;; CSV
    csv-split-line
    cmd-csv-align-columns
    ;; Epoch
    cmd-epoch-to-date
    ;; jq
    cmd-jq-filter
    ;; Line manipulation
    editor-text-range
    reverse-lines-in-string
    cmd-reverse-lines
    cmd-shuffle-lines
    ;; Calc eval
    cmd-calc-eval-region
    ;; Table
    cmd-table-insert
    ;; Timers
    cmd-list-timers
    ;; Aggressive indent
    cmd-toggle-aggressive-indent
    ;; Smart open line
    cmd-smart-open-line-above
    cmd-smart-open-line-below
    ;; Quick run
    file-extension
    cmd-quick-run
    ;; WS-butler
    ws-butler-mark-line-dirty!
    ws-butler-clean!
    cmd-toggle-ws-butler-mode
    ;; Copy formatted
    cmd-copy-as-formatted
    ;; Wrap/unwrap
    cmd-wrap-region-with
    cmd-unwrap-region
    ;; Quote toggle
    cmd-toggle-quotes
    ;; Word frequency
    cmd-word-frequency-analysis
    ;; Selection info
    cmd-selection-info
    ;; Hex increment
    cmd-increment-hex-at-point
    ;; Describe char
    cmd-describe-char
    ;; Narrow/widen
    cmd-narrow-to-region-simple
    cmd-widen-simple
    ;; Read-only toggle
    cmd-toggle-buffer-read-only
    ;; Batch 38 toggles
    cmd-toggle-auto-compression
    cmd-toggle-image-mode
    cmd-toggle-save-silently
    cmd-toggle-confirm-kill-emacs
    cmd-toggle-auto-window-vscroll
    cmd-toggle-fast-but-imprecise-scrolling
    cmd-toggle-mouse-avoidance
    cmd-toggle-make-backup-files
    cmd-toggle-version-control
    cmd-toggle-lock-file-create
    cmd-toggle-auto-encryption
    ;; Batch 46 toggles
    cmd-insert-date-time-stamp
    cmd-toggle-auto-rename-tag
    cmd-toggle-global-prettify-symbols
    cmd-toggle-global-subword
    cmd-toggle-global-superword
    cmd-toggle-delete-by-moving-to-trash
    cmd-toggle-create-lockfiles
    cmd-toggle-mode-line-compact
    cmd-toggle-use-file-dialog
    cmd-toggle-xterm-mouse-mode
    ;; Batch 58: window management toggles
    cmd-toggle-global-golden-ratio
    cmd-toggle-global-zoom-window
    cmd-toggle-global-shackle
    cmd-toggle-global-popwin
    cmd-toggle-global-popper
    cmd-toggle-global-posframe
    cmd-toggle-global-childframe
    ;; Batch 67: programming language mode toggles
    cmd-toggle-global-rustic
    cmd-toggle-global-go-mode
    cmd-toggle-global-python-black
    cmd-toggle-global-elpy
    cmd-toggle-global-js2-mode
    cmd-toggle-global-typescript-mode
    cmd-toggle-global-web-mode
    ;; Follow mode
    cmd-follow-mode
    ;; Recentf
    cmd-recentf-open-files
    ;; Markdown
    tui-get-current-line
    tui-md-heading-level
    cmd-markdown-promote
    cmd-markdown-demote
    cmd-markdown-insert-heading
    tui-markdown-toggle-wrap
    cmd-markdown-toggle-bold
    cmd-markdown-toggle-italic
    cmd-markdown-toggle-code
    cmd-markdown-next-heading
    cmd-markdown-prev-heading)

  (import
    (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
    (jerboa core)
    (jerboa runtime)
    (only (jerboa prelude) path-expand take)
    (std sugar)
    (only (std srfi srfi-13)
      string-join string-prefix? string-suffix? string-contains
      string-trim-both string-trim-right string-pad string-tokenize
      string-index-right)
    (only (std misc string) string-split)
    (std misc process)
    (std text json)
    (chez-scintilla constants)
    (chez-scintilla scintilla)
    (chez-scintilla tui)
    (except (jerboa-emacs core) face-get)
    (jerboa-emacs keymap)
    (jerboa-emacs buffer)
    (jerboa-emacs window)
    (jerboa-emacs modeline)
    (jerboa-emacs echo)
    (jerboa-emacs editor-extra-helpers))


  ;; ---- Local helpers ----

  ;; string-subst: replace all occurrences of old with new in str
  (define (string-subst str old new)
    (let ((old-len (string-length old))
          (new-str new))
      (if (= old-len 0) str
        (let loop ((s str))
          (let ((idx (string-contains s old)))
            (if (not idx) s
              (loop (string-append (substring s 0 idx)
                                   new-str
                                   (substring s (+ idx old-len)
                                              (string-length s))))))))))

  ;; Simple Fisher-Yates shuffle for lists
  (define (shuffle lst)
    (let ((v (list->vector lst)))
      (let ((n (vector-length v)))
        (let loop ((i (- n 1)))
          (when (> i 0)
            (let ((j (random (+ i 1))))
              (let ((tmp (vector-ref v i)))
                (vector-set! v i (vector-ref v j))
                (vector-set! v j tmp))
              (loop (- i 1)))))
        (vector->list v))))

  ;; Filter text through an external process
  (define (filter-with-process-text cmd-string input-text)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let-values (((to-stdin from-stdout from-stderr pid)
                      (open-process-ports cmd-string
                        (buffer-mode block)
                        (native-transcoder))))
          (display input-text to-stdin)
          (close-port to-stdin)
          (let ((out (get-string-all from-stdout)))
            (close-port from-stdout)
            (close-port from-stderr)
            out)))))


  ;; =========================================================================
  ;; EWW browser — text-mode web browser using litehtml for HTML rendering
  ;; Maintains history for back/forward navigation
  ;; =========================================================================

  (define *eww-history* '())
  (define *eww-history-idx* 0)
  (define *eww-current-url* #f)

  ;; Shared litehtml context (holds master CSS, reused across documents)
  (define *eww-lh-context* #f)

  (define (eww-ensure-context!)
    "Lazily create the shared litehtml context."
    ;; Stub — litehtml not yet ported to Chez
    (void))

  (define (eww-fetch-html url)
    "Fetch raw HTML from URL using curl. Returns HTML string or #f."
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let-values (((to-stdin from-stdout from-stderr pid)
                      (open-process-ports
                        (string-append "curl -sL -A 'Mozilla/5.0' --max-time 30 '"
                                       url "'")
                        (buffer-mode block)
                        (native-transcoder))))
          (close-port to-stdin)
          (let ((html (get-string-all from-stdout)))
            (close-port from-stdout)
            (close-port from-stderr)
            html)))))

  (define (eww-render-html html-string width)
    "Render HTML to text using litehtml. Returns rendered text string.
     Stub — returns tag-stripped HTML until litehtml is ported."
    (eww-ensure-context!)
    (let ((out (open-output-string))
          (len (string-length html-string)))
      (let loop ((i 0) (in-tag #f))
        (if (>= i len)
          (get-output-string out)
          (let ((ch (string-ref html-string i)))
            (cond
              ((char=? ch #\<) (loop (+ i 1) #t))
              ((char=? ch #\>) (loop (+ i 1) #f))
              (in-tag (loop (+ i 1) #t))
              (else (write-char ch out) (loop (+ i 1) #f))))))))

  (define (eww-assemble-text-runs runs width)
    "Assemble draw_text output into a text string.
     Each run is (text x y font-handle). We sort by y then x,
     fill gaps with spaces, and join lines with newlines."
    (if (null? runs)
      ""
      (let* ((sorted (list-sort (lambda (a b)
                       (let ((ya (caddr a)) (yb (caddr b)))
                         (if (= ya yb)
                           (< (cadr a) (cadr b))
                           (< ya yb)))) runs))
             (lines (make-hash-table))
             (max-y 0))
        ;; Collect runs per line
        (for-each
          (lambda (run)
            (let ((text (car run))
                  (x (cadr run))
                  (y (caddr run)))
              (when (> y max-y) (set! max-y y))
              (hash-update! lines y
                (lambda (existing) (cons (cons x text) existing))
                '())))
          sorted)
        ;; Build output
        (let ((out (open-output-string)))
          (let loop ((y 0))
            (when (<= y max-y)
              (let ((line-runs (list-sort (lambda (a b) (< (car a) (car b)))
                                          (or (hash-get lines y) '()))))
                (let fill ((runs line-runs) (col 0))
                  (if (null? runs)
                    (newline out)
                    (let* ((run (car runs))
                           (x (car run))
                           (text (cdr run))
                           (gap (max 0 (- x col))))
                      ;; Fill gap with spaces
                      (when (> gap 0)
                        (display (make-string gap #\space) out))
                      (display text out)
                      (fill (cdr runs) (+ (max x col) (string-length text)))))))
              (loop (+ y 1))))
          (get-output-string out)))))

  (define (eww-fetch-url url)
    "Fetch URL and render HTML to text via litehtml. Returns text or #f."
    (let ((html (eww-fetch-html url)))
      (and html (eww-render-html html 80))))

  (define (eww-display-page app url content)
    "Display web content in EWW buffer."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (buf (or (buffer-by-name "*EWW*")
                    (buffer-create! "*EWW*" ed)))
           (text (string-append "URL: " url "\n"
                               (make-string 60 #\-) "\n\n"
                               (or content "Failed to fetch page")
                               "\n\n[q: quit, g: goto URL, b: back, f: forward]")))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (editor-set-text ed text)
      (editor-goto-pos ed 0)
      (set! *eww-current-url* url)))

  (define (cmd-eww app)
    "Open EWW web browser."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (url (echo-read-string echo "URL: " row width)))
      (when (and url (not (string=? url "")))
        ;; Add http:// if no protocol
        (let ((full-url (if (or (string-prefix? "http://" url)
                                (string-prefix? "https://" url))
                          url
                          (string-append "https://" url))))
          (echo-message! echo (string-append "Fetching: " full-url))
          (let ((html (eww-fetch-html full-url)))
            (if html
              (begin
                ;; Update history
                (set! *eww-history* (cons full-url *eww-history*))
                (set! *eww-history-idx* 0)
                ;; Render HTML via litehtml
                (let ((rendered (eww-render-html html width)))
                  (eww-display-page app full-url rendered)))
              (echo-error! echo "Failed to fetch URL")))))))

  (define (cmd-eww-browse-url app)
    "Browse URL with EWW."
    (cmd-eww app))

  (define (cmd-browse-url-at-point app)
    "Browse URL at point."
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (echo (app-state-echo app)))
      ;; Find URL-like text around point
      (let loop ((start pos))
        (if (or (< start 0) (char-whitespace? (string-ref text start)))
          (let find-end ((end (+ pos 1)))
            (if (or (>= end (string-length text))
                    (char-whitespace? (string-ref text end)))
              ;; Extract potential URL
              (let* ((url-text (substring text (+ start 1) end)))
                (if (or (string-prefix? "http://" url-text)
                        (string-prefix? "https://" url-text)
                        (string-contains url-text ".com")
                        (string-contains url-text ".org")
                        (string-contains url-text ".net"))
                  (begin
                    (echo-message! echo (string-append "Opening: " url-text))
                    ;; Use xdg-open or browser
                    (with-catch
                      (lambda (e) (echo-error! echo "Failed to open URL"))
                      (lambda ()
                        (let-values (((to-stdin from-stdout from-stderr pid)
                                      (open-process-ports
                                        (string-append "xdg-open '" url-text "'")
                                        (buffer-mode block)
                                        (native-transcoder))))
                          (close-port to-stdin)
                          (close-port from-stdout)
                          (close-port from-stderr)
                          (echo-message! echo "Opened in browser")))))
                  (echo-message! echo "No URL at point")))
              (find-end (+ end 1))))
          (loop (- start 1))))))


  ;; =========================================================================
  ;; Windmove
  ;; =========================================================================

  (define (cmd-windmove-left app)
    "Move to window on the left (alias for other-window reverse)."
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (active (current-window fr)))
      (when (> (length wins) 1)
        (let ((idx (let loop ((ws wins) (i 0))
                     (cond ((null? ws) 0)
                           ((eq? (car ws) active) i)
                           (else (loop (cdr ws) (+ i 1)))))))
          (let ((prev-idx (modulo (- idx 1) (length wins))))
            (frame-current-idx-set! fr prev-idx))))))

  (define (cmd-windmove-right app)
    "Move to window on the right."
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (active (current-window fr)))
      (when (> (length wins) 1)
        (let ((idx (let loop ((ws wins) (i 0))
                     (cond ((null? ws) 0)
                           ((eq? (car ws) active) i)
                           (else (loop (cdr ws) (+ i 1)))))))
          (let ((next-idx (modulo (+ idx 1) (length wins))))
            (frame-current-idx-set! fr next-idx))))))

  (define (cmd-windmove-up app)
    "Move to window above (same as windmove-left in vertical layout)."
    (cmd-windmove-left app))

  (define (cmd-windmove-down app)
    "Move to window below (same as windmove-right in vertical layout)."
    (cmd-windmove-right app))


  ;; =========================================================================
  ;; Winner mode (window configuration undo/redo)
  ;; =========================================================================

  (define *winner-max-history* 50)

  (define (winner-save-config! app)
    "Save current window configuration to winner history."
    (let* ((fr (app-state-frame app))
           (wins (frame-windows fr))
           (num-wins (length wins))
           (current-idx (frame-current-idx fr))
           (buffers (map (lambda (w)
                           (let ((buf (edit-window-buffer w)))
                             (if buf (buffer-name buf) "*scratch*")))
                         wins))
           (config (list num-wins current-idx buffers))
           (history (app-state-winner-history app)))
      ;; Don't save duplicate consecutive configs
      (unless (and (not (null? history))
                   (equal? config (car history)))
        ;; Truncate future (redo) history when adding new config
        (let ((idx (app-state-winner-history-idx app)))
          (when (> idx 0)
            (set! history (list-tail history idx))
            (app-state-winner-history-idx-set! app 0)))
        ;; Add new config, limit size
        (let ((new-history (cons config history)))
          (app-state-winner-history-set! app
            (if (> (length new-history) *winner-max-history*)
              (take new-history *winner-max-history*)
              new-history))))))

  (define (winner-restore-config! app config)
    "Restore a window configuration from winner history."
    (let* ((target-num-wins (car config))
           (target-idx (cadr config))
           (target-buffers (caddr config))
           (fr (app-state-frame app))
           (current-wins (length (frame-windows fr))))
      ;; Adjust number of windows
      (cond
        ((> target-num-wins current-wins)
         (let loop ((n (- target-num-wins current-wins)))
           (when (> n 0)
             (frame-split! fr)
             (loop (- n 1)))))
        ((< target-num-wins current-wins)
         (let loop ((n (- current-wins target-num-wins)))
           (when (and (> n 0) (> (length (frame-windows fr)) 1))
             (frame-delete-window! fr)
             (loop (- n 1))))))
      ;; Set current window index
      (let ((max-idx (- (length (frame-windows fr)) 1)))
        (frame-current-idx-set! fr (min target-idx max-idx)))
      ;; Restore buffers to windows (by name)
      (let ((wins (frame-windows fr)))
        (for-each
          (lambda (win buf-name)
            (let ((buf (buffer-by-name buf-name)))
              (when buf
                (let ((ed (edit-window-editor win)))
                  (buffer-attach! ed buf)
                  (edit-window-buffer-set! win buf)))))
          wins
          (take target-buffers (length wins))))
      ;; Relayout
      (frame-layout! fr)))

  (define (cmd-winner-undo app)
    "Undo window configuration change."
    (let* ((history (app-state-winner-history app))
           (idx (app-state-winner-history-idx app))
           (echo (app-state-echo app)))
      (if (>= (+ idx 1) (length history))
        (echo-message! echo "No earlier window configuration")
        (begin
          (when (= idx 0)
            (winner-save-config! app))
          (let ((new-idx (+ idx 1)))
            (app-state-winner-history-idx-set! app new-idx)
            (let ((config (list-ref (app-state-winner-history app) new-idx)))
              (winner-restore-config! app config)
              (echo-message! echo
                (string-append "Winner: restored config "
                              (number->string (- (length history) new-idx))
                              "/" (number->string (length history))))))))))

  (define (cmd-winner-redo app)
    "Redo window configuration change."
    (let* ((idx (app-state-winner-history-idx app))
           (echo (app-state-echo app)))
      (if (<= idx 0)
        (echo-message! echo "No later window configuration")
        (begin
          (let ((new-idx (- idx 1)))
            (app-state-winner-history-idx-set! app new-idx)
            (let* ((history (app-state-winner-history app))
                   (config (list-ref history new-idx)))
              (winner-restore-config! app config)
              (echo-message! echo
                (string-append "Winner: restored config "
                              (number->string (- (length history) new-idx))
                              "/" (number->string (length history))))))))))


  ;; =========================================================================
  ;; Tab-bar commands
  ;; =========================================================================

  (define (tab-save-current! app)
    "Save current window state to current tab."
    (let* ((tabs (app-state-tabs app))
           (idx (app-state-current-tab-idx app))
           (fr (app-state-frame app))
           (wins (frame-windows fr))
           (buffers (map (lambda (w)
                           (let ((buf (edit-window-buffer w)))
                             (if buf (buffer-name buf) "*scratch*")))
                         wins))
           (win-idx (frame-current-idx fr)))
      (when (< idx (length tabs))
        (let* ((old-tab (list-ref tabs idx))
               (name (car old-tab))
               (new-tab (list name buffers win-idx)))
          (app-state-tabs-set! app
            (append (take tabs idx)
                    (list new-tab)
                    (if (< (+ idx 1) (length tabs))
                      (list-tail tabs (+ idx 1))
                      '())))))))

  (define (tab-restore! app tab)
    "Restore window state from a tab."
    (let* ((name (car tab))
           (buffers (cadr tab))
           (win-idx (caddr tab))
           (fr (app-state-frame app))
           (wins (frame-windows fr)))
      ;; Restore buffers to windows
      (for-each
        (lambda (win buf-name)
          (let ((buf (buffer-by-name buf-name)))
            (when buf
              (let ((ed (edit-window-editor win)))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! win buf)))))
        wins
        (take buffers (min (length buffers) (length wins))))
      ;; Set current window
      (let ((max-idx (- (length wins) 1)))
        (frame-current-idx-set! fr (min win-idx max-idx)))))

  (define (cmd-tab-new app)
    "Create a new tab with current buffer."
    (let* ((echo (app-state-echo app))
           (tabs (app-state-tabs app))
           (fr (app-state-frame app))
           (win (current-window fr))
           (buf (edit-window-buffer win))
           (buf-name (if buf (buffer-name buf) "*scratch*"))
           (new-tab-num (+ (length tabs) 1))
           (new-tab-name (string-append "Tab " (number->string new-tab-num)))
           (new-tab (list new-tab-name (list buf-name) 0)))
      ;; Save current tab state first
      (tab-save-current! app)
      ;; Add new tab
      (app-state-tabs-set! app (append tabs (list new-tab)))
      (app-state-current-tab-idx-set! app (- (length (app-state-tabs app)) 1))
      (echo-message! echo (string-append "Created " new-tab-name))))

  (define (cmd-tab-close app)
    "Close current tab."
    (let* ((echo (app-state-echo app))
           (tabs (app-state-tabs app))
           (idx (app-state-current-tab-idx app)))
      (if (<= (length tabs) 1)
        (echo-message! echo "Cannot close last tab")
        (let* ((tab-name (car (list-ref tabs idx)))
               (new-tabs (append (take tabs idx)
                                 (if (< (+ idx 1) (length tabs))
                                   (list-tail tabs (+ idx 1))
                                   '())))
               (new-idx (min idx (- (length new-tabs) 1))))
          (app-state-tabs-set! app new-tabs)
          (app-state-current-tab-idx-set! app new-idx)
          (tab-restore! app (list-ref new-tabs new-idx))
          (echo-message! echo (string-append "Closed " tab-name))))))

  (define (cmd-tab-next app)
    "Switch to next tab."
    (let* ((echo (app-state-echo app))
           (tabs (app-state-tabs app))
           (idx (app-state-current-tab-idx app)))
      (if (<= (length tabs) 1)
        (echo-message! echo "Only one tab")
        (begin
          (tab-save-current! app)
          (let ((new-idx (modulo (+ idx 1) (length tabs))))
            (app-state-current-tab-idx-set! app new-idx)
            (let ((tab (list-ref tabs new-idx)))
              (tab-restore! app tab)
              (echo-message! echo (string-append "Tab: " (car tab)
                                                " [" (number->string (+ new-idx 1))
                                                "/" (number->string (length tabs)) "]"))))))))

  (define (cmd-tab-previous app)
    "Switch to previous tab."
    (let* ((echo (app-state-echo app))
           (tabs (app-state-tabs app))
           (idx (app-state-current-tab-idx app)))
      (if (<= (length tabs) 1)
        (echo-message! echo "Only one tab")
        (begin
          (tab-save-current! app)
          (let ((new-idx (modulo (- idx 1) (length tabs))))
            (app-state-current-tab-idx-set! app new-idx)
            (let ((tab (list-ref tabs new-idx)))
              (tab-restore! app tab)
              (echo-message! echo (string-append "Tab: " (car tab)
                                                " [" (number->string (+ new-idx 1))
                                                "/" (number->string (length tabs)) "]"))))))))

  (define (cmd-tab-rename app)
    "Rename current tab."
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (tabs (app-state-tabs app))
           (idx (app-state-current-tab-idx app))
           (old-name (car (list-ref tabs idx)))
           (new-name (echo-read-string echo "Rename tab to: " row width)))
      (when (and new-name (not (string=? new-name "")))
        (let* ((old-tab (list-ref tabs idx))
               (new-tab (cons new-name (cdr old-tab))))
          (app-state-tabs-set! app
            (append (take tabs idx)
                    (list new-tab)
                    (if (< (+ idx 1) (length tabs))
                      (list-tail tabs (+ idx 1))
                      '())))
          (echo-message! echo (string-append "Renamed to: " new-name))))))

  (define (cmd-tab-move app)
    "Move current tab left or right (with prefix arg for direction)."
    (let* ((echo (app-state-echo app))
           (tabs (app-state-tabs app))
           (idx (app-state-current-tab-idx app))
           (n (get-prefix-arg app 1)))
      (if (<= (length tabs) 1)
        (echo-message! echo "Only one tab")
        (let* ((new-idx (modulo (+ idx n) (length tabs)))
               (tab (list-ref tabs idx))
               (tabs-without (append (take tabs idx)
                                     (if (< (+ idx 1) (length tabs))
                                       (list-tail tabs (+ idx 1))
                                       '())))
               (new-tabs (append (take tabs-without new-idx)
                                 (list tab)
                                 (list-tail tabs-without new-idx))))
          (app-state-tabs-set! app new-tabs)
          (app-state-current-tab-idx-set! app new-idx)
          (echo-message! echo (string-append "Moved tab to position "
                                            (number->string (+ new-idx 1))))))))


  ;; =========================================================================
  ;; URL encode/decode
  ;; =========================================================================

  (define (url-encode str)
    "Percent-encode a string for URLs."
    (let ((out (open-output-string)))
      (let loop ((i 0))
        (when (< i (string-length str))
          (let ((ch (string-ref str i)))
            (cond
              ((or (char-alphabetic? ch) (char-numeric? ch)
                   (memv ch '(#\- #\_ #\. #\~)))
               (write-char ch out))
              ((char=? ch #\space)
               (write-char #\+ out))
              (else
               (let ((b (char->integer ch)))
                 (display "%" out)
                 (when (< b 16) (write-char #\0 out))
                 (display (number->string b 16) out)))))
          (loop (+ i 1))))
      (get-output-string out)))

  (define (hex-digit-value ch)
    "Convert hex digit char to integer value."
    (cond
      ((and (char>=? ch #\0) (char<=? ch #\9))
       (- (char->integer ch) (char->integer #\0)))
      ((and (char>=? ch #\a) (char<=? ch #\f))
       (+ 10 (- (char->integer ch) (char->integer #\a))))
      ((and (char>=? ch #\A) (char<=? ch #\F))
       (+ 10 (- (char->integer ch) (char->integer #\A))))
      (else #f)))

  (define (url-decode str)
    "Decode a percent-encoded URL string."
    (let ((out (open-output-string))
          (len (string-length str)))
      (let loop ((i 0))
        (when (< i len)
          (let ((ch (string-ref str i)))
            (cond
              ((and (char=? ch #\%) (< (+ i 2) len))
               (let ((h1 (hex-digit-value (string-ref str (+ i 1))))
                     (h2 (hex-digit-value (string-ref str (+ i 2)))))
                 (if (and h1 h2)
                   (begin
                     (write-char (integer->char (+ (* h1 16) h2)) out)
                     (loop (+ i 3)))
                   (begin (write-char ch out) (loop (+ i 1))))))
              ((char=? ch #\+)
               (write-char #\space out)
               (loop (+ i 1)))
              (else
               (write-char ch out)
               (loop (+ i 1)))))))
      (get-output-string out)))

  (define (cmd-url-encode-region app)
    "URL-encode the selected region."
    (let* ((ed (current-editor app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (echo-error! (app-state-echo app) "No region selected")
        (let* ((text (editor-get-text ed))
               (region (substring text start end))
               (encoded (url-encode region)))
          (editor-set-selection ed start end)
          (send-message/string ed 2170 encoded) ;; SCI_REPLACESEL
          (echo-message! (app-state-echo app) "URL encoded")))))

  (define (cmd-url-decode-region app)
    "URL-decode the selected region."
    (let* ((ed (current-editor app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (echo-error! (app-state-echo app) "No region selected")
        (let* ((text (editor-get-text ed))
               (region (substring text start end))
               (decoded (url-decode region)))
          (editor-set-selection ed start end)
          (send-message/string ed 2170 decoded) ;; SCI_REPLACESEL
          (echo-message! (app-state-echo app) "URL decoded")))))


  ;; =========================================================================
  ;; JSON format / minify
  ;; =========================================================================

  (define (json-pretty-print obj indent)
    "Pretty-print a JSON value with indentation."
    (let ((out (open-output-string)))
      (let pp ((val obj) (level 0))
        (let ((prefix (make-string (* level indent) #\space)))
          (cond
            ((hash-table? val)
             (display "{\n" out)
             (let ((keys (list-sort string<? (hash-keys val)))
                   (first #t))
               (for-each
                 (lambda (k)
                   (unless first (display ",\n" out))
                   (display (make-string (* (+ level 1) indent) #\space) out)
                   (write k out)
                   (display ": " out)
                   (pp (hash-get val k) (+ level 1))
                   (set! first #f))
                 keys))
             (display "\n" out)
             (display prefix out)
             (display "}" out))
            ((list? val)
             (if (null? val)
               (display "[]" out)
               (begin
                 (display "[\n" out)
                 (let ((first #t))
                   (for-each
                     (lambda (item)
                       (unless first (display ",\n" out))
                       (display (make-string (* (+ level 1) indent) #\space) out)
                       (pp item (+ level 1))
                       (set! first #f))
                     val))
                 (display "\n" out)
                 (display prefix out)
                 (display "]" out))))
            ((string? val) (write val out))
            ((number? val) (display val out))
            ((boolean? val) (display (if val "true" "false") out))
            ((not val) (display "null" out))
            (else (write val out)))))
      (get-output-string out)))

  (define (cmd-json-format-buffer app)
    "Pretty-print JSON in the current buffer."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed)))
      (with-catch
        (lambda (e) (echo-error! echo "Invalid JSON"))
        (lambda ()
          (let* ((port (open-input-string text))
                 (obj (read-json port))
                 (formatted (json-pretty-print obj 2))
                 (pos (editor-get-current-pos ed)))
            (editor-set-text ed (string-append formatted "\n"))
            (editor-goto-pos ed (min pos (string-length formatted)))
            (echo-message! echo "JSON formatted"))))))

  (define (cmd-json-minify-buffer app)
    "Minify JSON in the current buffer (remove whitespace)."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed)))
      (with-catch
        (lambda (e) (echo-error! echo "Invalid JSON"))
        (lambda ()
          (let* ((port (open-input-string text))
                 (obj (read-json port))
                 (minified (call-with-string-output-port
                             (lambda (p) (write-json obj p))))
                 (pos (editor-get-current-pos ed)))
            (editor-set-text ed minified)
            (editor-goto-pos ed (min pos (string-length minified)))
            (echo-message! echo
              (string-append "JSON minified ("
                (number->string (string-length minified)) " bytes)")))))))


  ;; =========================================================================
  ;; HTML entity encode/decode
  ;; =========================================================================

  (define *html-entities*
    '(("&amp;" . "&") ("&lt;" . "<") ("&gt;" . ">")
      ("&quot;" . "\"") ("&#39;" . "'") ("&apos;" . "'")
      ("&nbsp;" . " ") ("&copy;" . "(c)") ("&reg;" . "(R)")
      ("&ndash;" . "-") ("&mdash;" . "--") ("&hellip;" . "...")
      ("&laquo;" . "<<") ("&raquo;" . ">>")))

  (define (html-decode-entities str)
    "Decode common HTML entities in a string."
    (let ((result str))
      (for-each
        (lambda (pair)
          (set! result (string-subst result (car pair) (cdr pair))))
        *html-entities*)
      result))

  (define (html-encode-entities str)
    "Encode special characters as HTML entities."
    (let ((result str))
      (set! result (string-subst result "&" "&amp;"))
      (set! result (string-subst result "<" "&lt;"))
      (set! result (string-subst result ">" "&gt;"))
      (set! result (string-subst result "\"" "&quot;"))
      result))

  (define (cmd-html-encode-region app)
    "Encode HTML entities in the selected region."
    (let* ((ed (current-editor app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (echo-error! (app-state-echo app) "No region selected")
        (let* ((text (editor-get-text ed))
               (region (substring text start end))
               (encoded (html-encode-entities region)))
          (editor-set-selection ed start end)
          (send-message/string ed 2170 encoded)
          (echo-message! (app-state-echo app) "HTML encoded")))))

  (define (cmd-html-decode-region app)
    "Decode HTML entities in the selected region."
    (let* ((ed (current-editor app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed)))
      (if (= start end)
        (echo-error! (app-state-echo app) "No region selected")
        (let* ((text (editor-get-text ed))
               (region (substring text start end))
               (decoded (html-decode-entities region)))
          (editor-set-selection ed start end)
          (send-message/string ed 2170 decoded)
          (echo-message! (app-state-echo app) "HTML decoded")))))


  ;; =========================================================================
  ;; Backup file before save
  ;; =========================================================================

  (define (create-backup-file! path)
    "Create a backup of a file."
    (when (and *make-backup-files* (file-exists? path))
      (with-catch
        (lambda (e) (void))
        (lambda ()
          (if *version-control*
            ;; Numbered backups: file.~1~, file.~2~, etc.
            (let loop ((n 1))
              (let ((vpath (string-append path ".~" (number->string n) "~")))
                (if (file-exists? vpath)
                  (loop (+ n 1))
                  (run-process/batch (list "cp" "-p" path vpath)))))
            ;; Simple backup: file~
            (run-process/batch (list "cp" "-p" path (string-append path "~"))))))))


  ;; =========================================================================
  ;; Large file and binary file warnings
  ;; =========================================================================

  (define *large-file-threshold* (* 1024 1024)) ;; 1 MB

  (define (large-file? path)
    "Check if a file exceeds the large file threshold."
    (and (file-exists? path)
         (with-catch
           (lambda (e) #f)
           (lambda ()
             (> (file-length path) *large-file-threshold*)))))

  (define (binary-file? path)
    "Heuristic: check if a file appears to be binary (has null bytes in first 8KB)."
    (and (file-exists? path)
         (with-catch
           (lambda (e) #f)
           (lambda ()
             (call-with-input-file path
               (lambda (port)
                 (let loop ((i 0))
                   (if (>= i 8192) #f
                     (let ((ch (read-char port)))
                       (cond
                         ((eof-object? ch) #f)
                         ((= (char->integer ch) 0) #t)
                         (else (loop (+ i 1)))))))))))))

  (define (cmd-find-file-with-warnings app)
    "Open file with warnings for large or binary files."
    (let* ((echo (app-state-echo app))
           (fpath (app-read-string app "Find file: ")))
      (when (and fpath (> (string-length fpath) 0))
        (let ((expanded (path-expand fpath)))
          (cond
            ((large-file? expanded)
             (echo-message! echo
               (string-append "Warning: Large file ("
                 (number->string (quotient (file-length expanded) 1024))
                 " KB). Opening anyway..."))
             (execute-command! app 'find-file))
            ((binary-file? expanded)
             (echo-message! echo "Warning: Binary file detected. Opening in hex view may be better."))
            (else
             (execute-command! app 'find-file)))))))


  ;; =========================================================================
  ;; Encoding detection
  ;; =========================================================================

  (define (detect-file-encoding path)
    "Detect file encoding using heuristics. Returns encoding name string."
    (if (not (file-exists? path)) "unknown"
      (with-catch
        (lambda (e) "utf-8")
        (lambda ()
          (let ((port (open-file-input-port path)))
            (let ((b1 (get-u8 port))
                  (b2 (get-u8 port))
                  (b3 (get-u8 port)))
              (close-port port)
              (cond
                ;; UTF-8 BOM
                ((and (eqv? b1 #xEF) (eqv? b2 #xBB) (eqv? b3 #xBF))
                 "utf-8-bom")
                ;; UTF-16 LE BOM
                ((and (eqv? b1 #xFF) (eqv? b2 #xFE))
                 "utf-16-le")
                ;; UTF-16 BE BOM
                ((and (eqv? b1 #xFE) (eqv? b2 #xFF))
                 "utf-16-be")
                ;; Default: assume UTF-8
                (else "utf-8"))))))))

  (define (cmd-detect-encoding app)
    "Show the detected encoding of the current file."
    (let* ((buf (current-buffer-from-app app))
           (path (and buf (buffer-file-path buf)))
           (echo (app-state-echo app)))
      (if (not path)
        (echo-error! echo "Buffer has no file")
        (echo-message! echo
          (string-append "Encoding: " (detect-file-encoding path))))))


  ;; =========================================================================
  ;; Sort JSON keys
  ;; =========================================================================

  (define (cmd-json-sort-keys app)
    "Sort all JSON object keys alphabetically."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed)))
      (with-catch
        (lambda (e) (echo-error! echo "Invalid JSON"))
        (lambda ()
          (let* ((port (open-input-string text))
                 (obj (read-json port))
                 (sorted (json-pretty-print obj 2))
                 (pos (editor-get-current-pos ed)))
            (editor-set-text ed (string-append sorted "\n"))
            (editor-goto-pos ed (min pos (string-length sorted)))
            (echo-message! echo "JSON keys sorted"))))))


  ;; =========================================================================
  ;; CSV mode helpers
  ;; =========================================================================

  (define (csv-split-line line)
    "Split a CSV line into fields (handles simple cases)."
    (let ((fields '())
          (current (open-output-string))
          (in-quotes #f)
          (len (string-length line)))
      (let loop ((i 0))
        (if (>= i len)
          (reverse (cons (get-output-string current) fields))
          (let ((ch (string-ref line i)))
            (cond
              ((and (char=? ch (integer->char 34)) (not in-quotes))
               (set! in-quotes #t)
               (loop (+ i 1)))
              ((and (char=? ch (integer->char 34)) in-quotes)
               (set! in-quotes #f)
               (loop (+ i 1)))
              ((and (char=? ch #\,) (not in-quotes))
               (set! fields (cons (get-output-string current) fields))
               (set! current (open-output-string))
               (loop (+ i 1)))
              (else
               (write-char ch current)
               (loop (+ i 1)))))))))

  (define (cmd-csv-align-columns app)
    "Align CSV columns for better readability."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (rows (map csv-split-line (filter (lambda (l) (> (string-length l) 0)) lines))))
      (if (null? rows)
        (echo-message! echo "No CSV data")
        ;; Calculate max width for each column
        (let* ((num-cols (apply max (map length rows)))
               (widths (let loop ((col 0) (acc '()))
                         (if (>= col num-cols)
                           (reverse acc)
                           (loop (+ col 1)
                                 (cons (apply max
                                         (map (lambda (row)
                                                (if (< col (length row))
                                                  (string-length (list-ref row col))
                                                  0))
                                              rows))
                                       acc))))))
          ;; Build aligned output
          (let ((out (open-output-string)))
            (for-each
              (lambda (row)
                (let field-loop ((i 0) (fields row))
                  (unless (null? fields)
                    (when (> i 0) (display " | " out))
                    (let* ((field (car fields))
                           (width (if (< i (length widths))
                                    (list-ref widths i) 0))
                           (pad (max 0 (- width (string-length field)))))
                      (display field out)
                      (display (make-string pad #\space) out))
                    (field-loop (+ i 1) (cdr fields))))
                (newline out))
              rows)
            (let ((result (get-output-string out))
                  (pos (editor-get-current-pos ed)))
              (editor-set-text ed result)
              (editor-goto-pos ed (min pos (string-length result)))
              (echo-message! echo
                (string-append "Aligned " (number->string (length rows))
                  " rows, " (number->string num-cols) " columns"))))))))


  ;; =========================================================================
  ;; Epoch timestamp conversion
  ;; =========================================================================

  (define (cmd-epoch-to-date app)
    "Convert Unix epoch timestamp at point or in region to human-readable date."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (start (editor-get-selection-start ed))
           (end (editor-get-selection-end ed))
           (text (editor-get-text ed)))
      (let ((num-str (if (= start end)
                       ;; No selection: try to find number at point
                       (let ((pos (editor-get-current-pos ed)))
                         (let loop ((s pos))
                           (if (or (< s 0) (not (char-numeric? (string-ref text s))))
                             (let loop2 ((e (+ s 1)))
                               (if (or (>= e (string-length text))
                                       (not (char-numeric? (string-ref text e))))
                                 (substring text (+ s 1) e)
                                 (loop2 (+ e 1))))
                             (loop (- s 1)))))
                       (substring text start end))))
        (let ((ts (string->number num-str)))
          (if (not ts)
            (echo-error! echo "No timestamp at point")
            (with-catch
              (lambda (e) (echo-error! echo "Invalid timestamp"))
              (lambda ()
                (let ((output (run-process
                                (list "date" "-d"
                                  (string-append "@" (number->string (inexact->exact (floor ts))))
                                  "+%Y-%m-%d %H:%M:%S %Z"))))
                  (echo-message! echo
                    (string-append (number->string (inexact->exact (floor ts)))
                      " = " (string-trim-both output)))))))))))


  ;; =========================================================================
  ;; Pipe buffer through jq
  ;; =========================================================================

  (define (cmd-jq-filter app)
    "Run jq filter on current buffer's JSON content."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (filter-str (app-read-string app "jq filter (e.g. '.key'): ")))
      (when (and filter-str (> (string-length filter-str) 0))
        (let ((text (editor-get-text ed)))
          (with-catch
            (lambda (e) (echo-error! echo "jq error (is jq installed?)"))
            (lambda ()
              (let ((output (filter-with-process-text
                              (string-append "jq " filter-str)
                              text)))
                (when (and output (> (string-length output) 0))
                  (let ((pos (editor-get-current-pos ed)))
                    (editor-set-text ed output)
                    (editor-goto-pos ed (min pos (string-length output)))
                    (echo-message! echo "jq filter applied"))))))))))


  ;; =========================================================================
  ;; Line manipulation, calc-eval, table, smart-open, quick-run, etc.
  ;; =========================================================================

  (define (editor-text-range ed start end)
    "Extract text between positions start and end."
    (let ((text (editor-get-text ed)))
      (substring text (min start (string-length text))
                      (min end (string-length text)))))

  ;; --- Reverse lines ---

  (define (reverse-lines-in-string text)
    "Reverse the order of lines in a string."
    (let* ((lines (string-split text #\newline))
           (reversed (reverse lines)))
      (string-join reversed "\n")))

  (define (cmd-reverse-lines app)
    "Reverse the order of lines in region or entire buffer."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (let* ((text (editor-get-text ed))
               (result (reverse-lines-in-string text)))
          (editor-set-text ed result)
          (editor-goto-pos ed 0)
          (echo-message! echo "Reversed all lines"))
        (let* ((line-start (editor-line-from-position ed sel-start))
               (line-end (editor-line-from-position ed sel-end))
               (pos-start (editor-position-from-line ed line-start))
               (pos-end (editor-get-line-end-position ed line-end))
               (text (editor-text-range ed pos-start pos-end))
               (result (reverse-lines-in-string text)))
          (send-message ed SCI_SETTARGETSTART pos-start 0)
          (send-message ed SCI_SETTARGETEND pos-end 0)
          (send-message/string ed SCI_REPLACETARGET result)
          (echo-message! echo
            (string-append "Reversed " (number->string (+ 1 (- line-end line-start)))
              " lines"))))))

  ;; --- Shuffle lines ---

  (define (cmd-shuffle-lines app)
    "Randomly shuffle lines in region or entire buffer."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (let* ((text (editor-get-text ed))
               (lines (string-split text #\newline))
               (shuffled (shuffle lines))
               (result (string-join shuffled "\n")))
          (editor-set-text ed result)
          (editor-goto-pos ed 0)
          (echo-message! echo "Shuffled all lines"))
        (let* ((line-start (editor-line-from-position ed sel-start))
               (line-end (editor-line-from-position ed sel-end))
               (pos-start (editor-position-from-line ed line-start))
               (pos-end (editor-get-line-end-position ed line-end))
               (text (editor-text-range ed pos-start pos-end))
               (lines (string-split text #\newline))
               (shuffled (shuffle lines))
               (result (string-join shuffled "\n")))
          (send-message ed SCI_SETTARGETSTART pos-start 0)
          (send-message ed SCI_SETTARGETEND pos-end 0)
          (send-message/string ed SCI_REPLACETARGET result)
          (echo-message! echo
            (string-append "Shuffled " (number->string (length lines))
              " lines"))))))

  ;; --- Evaluate math expression in region ---

  (define (cmd-calc-eval-region app)
    "Evaluate the selected text as a math expression and replace with result."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! echo "No selection - select a math expression first")
        (let* ((expr-text (editor-text-range ed sel-start sel-end)))
          (with-catch
            (lambda (e)
              (echo-error! echo (string-append "Eval error: "
                (call-with-string-output-port (lambda (p) (display-condition e p))))))
            (lambda ()
              (let ((result (eval (read (open-input-string expr-text)))))
                (send-message ed SCI_SETTARGETSTART sel-start 0)
                (send-message ed SCI_SETTARGETEND sel-end 0)
                (let ((result-str (call-with-string-output-port
                                    (lambda (p) (display result p)))))
                  (send-message/string ed SCI_REPLACETARGET result-str)
                  (echo-message! echo
                    (string-append expr-text " = " result-str))))))))))

  ;; --- Insert text table ---

  (define (cmd-table-insert app)
    "Insert a formatted text table at point."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (cols-str (app-read-string app "Number of columns: "))
           (rows-str (and cols-str (app-read-string app "Number of rows: "))))
      (when (and cols-str rows-str)
        (with-catch
          (lambda (e) (echo-error! echo "Invalid number"))
          (lambda ()
            (let* ((cols (string->number cols-str))
                   (rows (string->number rows-str))
                   (col-width 12)
                   (separator (string-append "+"
                     (string-join
                       (let loop ((i 0) (acc '()))
                         (if (>= i cols) (reverse acc)
                           (loop (+ i 1) (cons (make-string col-width #\-) acc))))
                       "+")
                     "+\n"))
                   (data-row (string-append "|"
                     (string-join
                       (let loop ((i 0) (acc '()))
                         (if (>= i cols) (reverse acc)
                           (loop (+ i 1) (cons (make-string col-width #\space) acc))))
                       "|")
                     "|\n"))
                   (table (call-with-string-output-port
                            (lambda (p)
                              (display separator p)
                              (let loop ((r 0))
                                (when (< r rows)
                                  (display data-row p)
                                  (display separator p)
                                  (loop (+ r 1))))))))
              (let ((pos (editor-get-current-pos ed)))
                (editor-insert-text ed pos table)
                (echo-message! echo
                  (string-append "Inserted " (number->string rows) "x"
                    (number->string cols) " table")))))))))

  ;; --- List active timers ---

  (define (cmd-list-timers app)
    "Show a buffer listing active system timers."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (info (call-with-string-output-port
                   (lambda (p)
                     (display "Active Timers:\n" p)
                     (display (make-string 60 #\-) p)
                     (display "\n" p)
                     (display "  Auto-save timer:     30s interval (saves modified buffers)\n" p)
                     (display "  File-check timer:     5s interval (detects external changes)\n" p)
                     (display "  GC timer:           periodic (garbage collection)\n" p)
                     (display (make-string 60 #\-) p)
                     (display "\n" p)
                     (display "Total: 3 system timers configured\n" p)))))
      (editor-set-text ed info)
      (editor-goto-pos ed 0)
      (echo-message! echo "Timer list displayed")))

  ;; --- Aggressive indent mode ---

  (define *aggressive-indent-mode* #f)

  (define (cmd-toggle-aggressive-indent app)
    "Toggle aggressive auto-indent mode."
    (set! *aggressive-indent-mode* (not *aggressive-indent-mode*))
    (echo-message! (app-state-echo app)
      (if *aggressive-indent-mode*
        "Aggressive indent mode enabled"
        "Aggressive indent mode disabled")))

  ;; --- Smart open line ---

  (define (cmd-smart-open-line-above app)
    "Open a new line above, respecting indentation of current line."
    (let* ((ed (current-editor app))
           (line (editor-line-from-position ed
                   (editor-get-current-pos ed)))
           (line-text (editor-get-line ed line))
           (indent (let loop ((i 0))
                     (if (and (< i (string-length line-text))
                              (or (char=? (string-ref line-text i) #\space)
                                  (char=? (string-ref line-text i) #\tab)))
                       (loop (+ i 1))
                       i)))
           (indent-str (substring line-text 0 indent))
           (pos (editor-position-from-line ed line)))
      (editor-insert-text ed pos (string-append indent-str "\n"))
      (editor-goto-pos ed (+ pos indent))))

  (define (cmd-smart-open-line-below app)
    "Open a new line below, respecting indentation of current line."
    (let* ((ed (current-editor app))
           (line (editor-line-from-position ed
                   (editor-get-current-pos ed)))
           (line-text (editor-get-line ed line))
           (indent (let loop ((i 0))
                     (if (and (< i (string-length line-text))
                              (or (char=? (string-ref line-text i) #\space)
                                  (char=? (string-ref line-text i) #\tab)))
                       (loop (+ i 1))
                       i)))
           (indent-str (substring line-text 0 indent))
           (eol (editor-get-line-end-position ed line)))
      (editor-insert-text ed eol (string-append "\n" indent-str))
      (editor-goto-pos ed (+ eol 1 indent))))

  ;; --- Quick-run current buffer ---

  (define *file-runners*
    (hash
      ("py" "python3")
      ("rb" "ruby")
      ("js" "node")
      ("ts" "ts-node")
      ("sh" "bash")
      ("pl" "perl")
      ("lua" "lua")
      ("php" "php")
      ("go" "go run")
      ("rs" "rustc -o /tmp/gemacs-run && /tmp/gemacs-run")
      ("ss" "gxi")
      ("scm" "gxi")
      ("el" "emacs --script")
      ("awk" "awk -f")))

  (define (file-extension path)
    "Get the file extension from a path."
    (let ((dot-pos (string-index-right path #\.)))
      (if dot-pos
        (substring path (+ dot-pos 1) (string-length path))
        "")))

  (define (cmd-quick-run app)
    "Run the current buffer's file with an appropriate interpreter."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (filepath (buffer-file-path buf)))
      (if (not filepath)
        (echo-message! echo "Buffer has no file - save first")
        (let* ((ext (file-extension filepath))
               (runner (hash-get *file-runners* ext)))
          (if (not runner)
            (echo-message! echo (string-append "No runner configured for ." ext))
            (let ((cmd (string-append runner " " filepath)))
              (with-catch
                (lambda (e)
                  (echo-error! echo (string-append "Run error: "
                    (call-with-string-output-port (lambda (p) (display-condition e p))))))
                (lambda ()
                  (let ((output (filter-with-process-text
                                  (string-append "bash -c '" cmd "'")
                                  "")))
                    (let* ((text (or output "")))
                      (editor-set-text ed text)
                      (editor-goto-pos ed 0)
                      (echo-message! echo
                        (string-append "Ran: " cmd))))))))))))

  ;; --- WS-butler mode ---

  (define *ws-butler-mode* #f)
  (define *ws-butler-dirty-lines* (make-hash-table))

  (define (ws-butler-mark-line-dirty! ed)
    "Mark the current line as dirty for ws-butler cleanup."
    (when *ws-butler-mode*
      (let ((line (editor-line-from-position ed
                    (editor-get-current-pos ed))))
        (hash-put! *ws-butler-dirty-lines* line #t))))

  (define (ws-butler-clean! ed)
    "Clean trailing whitespace on dirty lines only."
    (let ((lines (hash-keys *ws-butler-dirty-lines*)))
      (for-each
        (lambda (line)
          (let* ((start (editor-position-from-line ed line))
                 (end (editor-get-line-end-position ed line))
                 (text (editor-text-range ed start end)))
            (when (> (string-length text) 0)
              (let ((trimmed (string-trim-right text)))
                (when (not (string=? text trimmed))
                  (send-message ed SCI_SETTARGETSTART start 0)
                  (send-message ed SCI_SETTARGETEND end 0)
                  (send-message/string ed SCI_REPLACETARGET trimmed))))))
        (list-sort < lines))
      (set! *ws-butler-dirty-lines* (make-hash-table))))

  (define (cmd-toggle-ws-butler-mode app)
    "Toggle ws-butler mode."
    (set! *ws-butler-mode* (not *ws-butler-mode*))
    (set! *ws-butler-dirty-lines* (make-hash-table))
    (echo-message! (app-state-echo app)
      (if *ws-butler-mode*
        "ws-butler mode enabled (trailing whitespace cleaned on save for edited lines)"
        "ws-butler mode disabled")))

  ;; --- Copy buffer contents as formatted code ---

  (define (cmd-copy-as-formatted app)
    "Copy buffer text with line numbers prepended to each line."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (width (string-length (number->string (length lines))))
           (numbered (let loop ((ls lines) (n 1) (acc '()))
                       (if (null? ls) (reverse acc)
                         (loop (cdr ls) (+ n 1)
                           (cons (string-append
                                   (string-pad (number->string n) width)
                                   ": " (car ls))
                             acc))))))
      (let ((result (string-join numbered "\n")))
        (app-state-kill-ring-set! app (cons result (app-state-kill-ring app)))
        (echo-message! echo
          (string-append "Copied " (number->string (length lines))
            " lines with line numbers")))))

  ;; --- Wrap region in delimiter pairs ---

  (define (cmd-wrap-region-with app)
    "Wrap selected text with specified delimiters."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! echo "No selection to wrap")
        (let ((wrapper (app-read-string app "Wrap with (e.g. \" or ( or [ or { or <): ")))
          (when (and wrapper (> (string-length wrapper) 0))
            (let* ((open-ch (string-ref wrapper 0))
                   (close-ch (cond
                               ((char=? open-ch #\() #\))
                               ((char=? open-ch #\[) #\])
                               ((char=? open-ch #\{) #\})
                               ((char=? open-ch #\<) #\>)
                               (else open-ch)))
                   (text (editor-text-range ed sel-start sel-end))
                   (wrapped (string-append (string open-ch) text (string close-ch))))
              (send-message ed SCI_SETTARGETSTART sel-start 0)
              (send-message ed SCI_SETTARGETEND sel-end 0)
              (send-message/string ed SCI_REPLACETARGET wrapped)
              (echo-message! echo
                (string-append "Wrapped with "
                  (string open-ch) "..." (string close-ch)))))))))

  ;; --- Remove wrapping delimiters ---

  (define (cmd-unwrap-region app)
    "Remove surrounding delimiters from selection."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (< (- sel-end sel-start) 2)
        (echo-message! echo "Selection too short to unwrap")
        (let* ((text (editor-text-range ed sel-start sel-end))
               (first-ch (string-ref text 0))
               (last-ch (string-ref text (- (string-length text) 1)))
               (matching? (or (and (char=? first-ch #\() (char=? last-ch #\)))
                              (and (char=? first-ch #\[) (char=? last-ch #\]))
                              (and (char=? first-ch #\{) (char=? last-ch #\}))
                              (and (char=? first-ch #\<) (char=? last-ch #\>))
                              (char=? first-ch last-ch))))
          (if (not matching?)
            (echo-message! echo "Selection doesn't appear to be wrapped in matching delimiters")
            (let ((inner (substring text 1 (- (string-length text) 1))))
              (send-message ed SCI_SETTARGETSTART sel-start 0)
              (send-message ed SCI_SETTARGETEND sel-end 0)
              (send-message/string ed SCI_REPLACETARGET inner)
              (echo-message! echo "Unwrapped delimiters")))))))

  ;; --- Quote style conversion ---

  (define (cmd-toggle-quotes app)
    "Toggle between single and double quotes around the string at point."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (let find-quote ((i pos))
        (if (< i 0)
          (echo-message! echo "Not inside a quoted string")
          (let ((ch (string-ref text i)))
            (if (or (char=? ch (integer->char 34))   ; double quote
                    (char=? ch (integer->char 39)))   ; single quote
              (let ((quote-ch ch)
                    (other-ch (if (char=? ch (integer->char 34))
                                (integer->char 39)
                                (integer->char 34))))
                (let find-close ((j (+ i 1)))
                  (if (>= j len)
                    (echo-message! echo "Unmatched quote")
                    (if (char=? (string-ref text j) quote-ch)
                      (begin
                        (send-message ed SCI_SETTARGETSTART j 0)
                        (send-message ed SCI_SETTARGETEND (+ j 1) 0)
                        (send-message/string ed SCI_REPLACETARGET (string other-ch))
                        (send-message ed SCI_SETTARGETSTART i 0)
                        (send-message ed SCI_SETTARGETEND (+ i 1) 0)
                        (send-message/string ed SCI_REPLACETARGET (string other-ch))
                        (echo-message! echo
                          (string-append "Toggled to "
                            (if (char=? other-ch (integer->char 34)) "double" "single")
                            " quotes")))
                      (find-close (+ j 1))))))
              (find-quote (- i 1))))))))

  ;; --- Frequency analysis of words ---

  (define (cmd-word-frequency-analysis app)
    "Show word frequency analysis of buffer content."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (text (editor-get-text ed))
           (words (string-tokenize text))
           (freq (make-hash-table))
           (_ (for-each (lambda (w)
                (let ((lw (string-downcase w)))
                  (hash-put! freq lw (+ 1 (or (hash-get freq lw) 0)))))
                words))
           (pairs (hash->list freq))
           (sorted (list-sort (lambda (a b) (> (cdr a) (cdr b))) pairs))
           (top (let loop ((ls sorted) (n 0) (acc '()))
                  (if (or (null? ls) (>= n 30)) (reverse acc)
                    (loop (cdr ls) (+ n 1) (cons (car ls) acc)))))
           (report (call-with-string-output-port
                     (lambda (p)
                       (display "Word Frequency Analysis:\n" p)
                       (display (make-string 40 #\-) p)
                       (display "\n" p)
                       (for-each
                         (lambda (pr)
                           (display (string-pad (number->string (cdr pr)) 6) p)
                           (display "  " p)
                           (display (car pr) p)
                           (display "\n" p))
                         top)
                       (display (make-string 40 #\-) p)
                       (display "\n" p)
                       (display "Total unique words: " p)
                       (display (number->string (length pairs)) p)
                       (display "\n" p)
                       (display "Total words: " p)
                       (display (number->string (length words)) p)
                       (display "\n" p)))))
      (editor-set-text ed report)
      (editor-goto-pos ed 0)
      (echo-message! echo
        (string-append (number->string (length pairs)) " unique words analyzed"))))

  ;; --- Selection statistics ---

  (define (cmd-selection-info app)
    "Display information about the current selection."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! echo "No selection")
        (let* ((text (editor-text-range ed sel-start sel-end))
               (chars (string-length text))
               (lines (length (string-split text #\newline)))
               (words (length (string-tokenize text)))
               (bytes chars))
          (echo-message! echo
            (string-append "Selection: " (number->string chars) " chars, "
              (number->string words) " words, "
              (number->string lines) " lines"))))))

  ;; --- Increment hex at point ---

  (define (cmd-increment-hex-at-point app)
    "Increment a hexadecimal number at point."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (let find-start ((i pos))
        (if (or (< i 0) (and (> (- pos i) 20)))
          (echo-message! echo "No hex number at point")
          (if (and (> i 0)
                   (char=? (string-ref text i) #\x)
                   (char=? (string-ref text (- i 1)) #\0))
            (let* ((hex-start (+ i 1))
                   (hex-end (let loop ((j hex-start))
                              (if (and (< j len)
                                       (let ((c (string-ref text j)))
                                         (or (char-numeric? c)
                                             (and (char>=? c #\a) (char<=? c #\f))
                                             (and (char>=? c #\A) (char<=? c #\F)))))
                                (loop (+ j 1))
                                j)))
                   (hex-str (substring text hex-start hex-end))
                   (val (string->number hex-str 16)))
              (if (not val)
                (echo-message! echo "Invalid hex number")
                (let* ((new-val (+ val 1))
                       (new-hex (number->string new-val 16))
                       (padded (if (< (string-length new-hex) (string-length hex-str))
                                 (string-append
                                   (make-string (- (string-length hex-str) (string-length new-hex)) #\0)
                                   new-hex)
                                 new-hex)))
                  (send-message ed SCI_SETTARGETSTART hex-start 0)
                  (send-message ed SCI_SETTARGETEND hex-end 0)
                  (send-message/string ed SCI_REPLACETARGET padded)
                  (echo-message! echo
                    (string-append "0x" hex-str " -> 0x" padded)))))
            (find-start (- i 1)))))))

  ;; --- Describe char at point ---

  (define (cmd-describe-char app)
    "Show detailed info about the character at point."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      (if (>= pos (string-length text))
        (echo-message! echo "End of buffer")
        (let* ((ch (string-ref text pos))
               (code (char->integer ch))
               (name (cond
                       ((char=? ch #\space) "SPACE")
                       ((char=? ch #\tab) "TAB")
                       ((char=? ch #\newline) "NEWLINE")
                       ((char=? ch #\return) "CARRIAGE RETURN")
                       ((< code 32) (string-append "CONTROL-" (string (integer->char (+ code 64)))))
                       (else (string ch)))))
          (echo-message! echo
            (string-append name " (U+"
              (let ((hex (number->string code 16)))
                (if (< (string-length hex) 4)
                  (string-append (make-string (- 4 (string-length hex)) #\0) hex)
                  hex))
              ", decimal " (number->string code)
              ", octal " (number->string code 8) ")"))))))

  ;; --- Narrow to region ---

  (define *narrow-original-text* #f)
  (define *narrow-offset* 0)

  (define (cmd-narrow-to-region-simple app)
    "Narrow buffer to show only the selected region."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-message! echo "No region selected for narrowing")
        (begin
          (set! *narrow-original-text* (editor-get-text ed))
          (set! *narrow-offset* sel-start)
          (let ((region-text (editor-text-range ed sel-start sel-end)))
            (editor-set-text ed region-text)
            (editor-goto-pos ed 0)
            (echo-message! echo "Narrowed to region (use widen to restore)"))))))

  (define (cmd-widen-simple app)
    "Widen buffer to show full content after narrowing."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app)))
      (if (not *narrow-original-text*)
        (echo-message! echo "Buffer is not narrowed")
        (let ((narrowed-text (editor-get-text ed)))
          (let ((result (string-append
                          (substring *narrow-original-text* 0 *narrow-offset*)
                          narrowed-text
                          (substring *narrow-original-text*
                            (+ *narrow-offset* (string-length narrowed-text))
                            (string-length *narrow-original-text*)))))
            (editor-set-text ed result)
            (editor-goto-pos ed *narrow-offset*)
            (set! *narrow-original-text* #f)
            (set! *narrow-offset* 0)
            (echo-message! echo "Buffer widened"))))))

  ;; --- Toggle read-only ---

  (define (cmd-toggle-buffer-read-only app)
    "Toggle the read-only flag on the current buffer."
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (current (if (editor-get-read-only? ed) 1 0)))
      (editor-set-read-only ed (= current 0))
      (echo-message! echo
        (if (= current 0)
          "Buffer is now read-only"
          "Buffer is now editable"))))


  ;; =========================================================================
  ;; Batch 38: auto-compression, image mode, save silently, backups, etc.
  ;; =========================================================================

  (define *auto-compression-mode* #t)
  (define *image-mode* #f)
  (define *save-silently* #f)
  (define *confirm-kill-emacs* #t)
  (define *auto-window-vscroll* #t)
  (define *fast-but-imprecise-scrolling* #f)
  (define *mouse-avoidance-mode* #f)
  (define *make-backup-files* #t)
  (define *version-control* #f)
  (define *lock-file-create* #t)
  (define *auto-encryption-mode* #t)

  (define (cmd-toggle-auto-compression app)
    "Toggle auto-compression-mode."
    (let ((echo (app-state-echo app)))
      (set! *auto-compression-mode* (not *auto-compression-mode*))
      (echo-message! echo (if *auto-compression-mode*
                            "Auto-compression ON"
                            "Auto-compression OFF"))))

  (define (cmd-toggle-image-mode app)
    "Toggle image display mode."
    (let ((echo (app-state-echo app)))
      (set! *image-mode* (not *image-mode*))
      (echo-message! echo (if *image-mode*
                            "Image mode ON"
                            "Image mode OFF"))))

  (define (cmd-toggle-save-silently app)
    "Toggle silent saving."
    (let ((echo (app-state-echo app)))
      (set! *save-silently* (not *save-silently*))
      (echo-message! echo (if *save-silently*
                            "Save silently ON"
                            "Save silently OFF"))))

  (define (cmd-toggle-confirm-kill-emacs app)
    "Toggle confirmation prompt before exiting."
    (let ((echo (app-state-echo app)))
      (set! *confirm-kill-emacs* (not *confirm-kill-emacs*))
      (echo-message! echo (if *confirm-kill-emacs*
                            "Confirm kill ON"
                            "Confirm kill OFF"))))

  (define (cmd-toggle-auto-window-vscroll app)
    "Toggle automatic vertical scrolling."
    (let ((echo (app-state-echo app)))
      (set! *auto-window-vscroll* (not *auto-window-vscroll*))
      (echo-message! echo (if *auto-window-vscroll*
                            "Auto window vscroll ON"
                            "Auto window vscroll OFF"))))

  (define (cmd-toggle-fast-but-imprecise-scrolling app)
    "Toggle fast-but-imprecise scrolling."
    (let ((echo (app-state-echo app)))
      (set! *fast-but-imprecise-scrolling* (not *fast-but-imprecise-scrolling*))
      (echo-message! echo (if *fast-but-imprecise-scrolling*
                            "Fast scrolling ON"
                            "Fast scrolling OFF"))))

  (define (cmd-toggle-mouse-avoidance app)
    "Toggle mouse-avoidance-mode."
    (let ((echo (app-state-echo app)))
      (set! *mouse-avoidance-mode* (not *mouse-avoidance-mode*))
      (echo-message! echo (if *mouse-avoidance-mode*
                            "Mouse avoidance ON"
                            "Mouse avoidance OFF"))))

  (define (cmd-toggle-make-backup-files app)
    "Toggle creation of backup files."
    (let ((echo (app-state-echo app)))
      (set! *make-backup-files* (not *make-backup-files*))
      (echo-message! echo (if *make-backup-files*
                            "Backup files ON"
                            "Backup files OFF"))))

  (define (cmd-toggle-version-control app)
    "Toggle numbered backups."
    (set! *version-control* (not *version-control*))
    (echo-message! (app-state-echo app)
      (if *version-control* "Numbered backups ON" "Numbered backups OFF (simple file~)")))

  (define (cmd-toggle-lock-file-create app)
    "Toggle creation of lock files."
    (let ((echo (app-state-echo app)))
      (set! *lock-file-create* (not *lock-file-create*))
      (echo-message! echo (if *lock-file-create*
                            "Lock files ON"
                            "Lock files OFF"))))

  (define (cmd-toggle-auto-encryption app)
    "Toggle auto-encryption-mode."
    (let ((echo (app-state-echo app)))
      (set! *auto-encryption-mode* (not *auto-encryption-mode*))
      (echo-message! echo (if *auto-encryption-mode*
                            "Auto-encryption ON"
                            "Auto-encryption OFF"))))


  ;; =========================================================================
  ;; Batch 46: file handling and display preferences
  ;; =========================================================================

  (define *auto-rename-tag* #f)
  (define *global-prettify-symbols* #f)
  (define *global-subword-mode* #f)
  (define *global-superword-mode* #f)
  (define *delete-by-moving-to-trash* #f)
  (define *create-lockfiles* #t)
  (define *mode-line-compact* #f)
  (define *use-file-dialog* #f)
  (define *xterm-mouse-mode* #f)

  (define (cmd-insert-date-time-stamp app)
    "Insert current date and time at point."
    (let* ((ed (current-editor app))
           (stamp (string-trim-right
                   (run-process (list "date" "+%Y-%m-%d %H:%M:%S")))))
      (editor-replace-selection ed stamp)))

  (define (cmd-toggle-auto-rename-tag app)
    "Toggle auto-rename-tag."
    (let ((echo (app-state-echo app)))
      (set! *auto-rename-tag* (not *auto-rename-tag*))
      (echo-message! echo (if *auto-rename-tag*
                            "Auto-rename tag ON" "Auto-rename tag OFF"))))

  (define (cmd-toggle-global-prettify-symbols app)
    "Toggle global-prettify-symbols-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-prettify-symbols* (not *global-prettify-symbols*))
      (echo-message! echo (if *global-prettify-symbols*
                            "Prettify symbols ON" "Prettify symbols OFF"))))

  (define (cmd-toggle-global-subword app)
    "Toggle global-subword-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-subword-mode* (not *global-subword-mode*))
      (echo-message! echo (if *global-subword-mode*
                            "Global subword mode ON" "Global subword mode OFF"))))

  (define (cmd-toggle-global-superword app)
    "Toggle global-superword-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-superword-mode* (not *global-superword-mode*))
      (echo-message! echo (if *global-superword-mode*
                            "Global superword mode ON" "Global superword mode OFF"))))

  (define (cmd-toggle-delete-by-moving-to-trash app)
    "Toggle delete-by-moving-to-trash."
    (let ((echo (app-state-echo app)))
      (set! *delete-by-moving-to-trash* (not *delete-by-moving-to-trash*))
      (echo-message! echo (if *delete-by-moving-to-trash*
                            "Delete to trash ON" "Delete to trash OFF"))))

  (define (cmd-toggle-create-lockfiles app)
    "Toggle creation of lock files."
    (let ((echo (app-state-echo app)))
      (set! *create-lockfiles* (not *create-lockfiles*))
      (echo-message! echo (if *create-lockfiles*
                            "Lock files ON" "Lock files OFF"))))

  (define (cmd-toggle-mode-line-compact app)
    "Toggle compact mode-line display."
    (let ((echo (app-state-echo app)))
      (set! *mode-line-compact* (not *mode-line-compact*))
      (echo-message! echo (if *mode-line-compact*
                            "Mode-line compact ON" "Mode-line compact OFF"))))

  (define (cmd-toggle-use-file-dialog app)
    "Toggle use of file dialogs."
    (let ((echo (app-state-echo app)))
      (set! *use-file-dialog* (not *use-file-dialog*))
      (echo-message! echo (if *use-file-dialog*
                            "File dialog ON" "File dialog OFF"))))

  (define (cmd-toggle-xterm-mouse-mode app)
    "Toggle xterm-mouse-mode."
    (let ((echo (app-state-echo app)))
      (set! *xterm-mouse-mode* (not *xterm-mouse-mode*))
      (echo-message! echo (if *xterm-mouse-mode*
                            "Xterm mouse mode ON" "Xterm mouse mode OFF"))))


  ;; =========================================================================
  ;; Batch 58: window management and popup framework toggles
  ;; =========================================================================

  (define *global-golden-ratio* #f)
  (define *global-zoom-window* #f)
  (define *global-shackle* #f)
  (define *global-popwin* #f)
  (define *global-popper* #f)
  (define *global-posframe* #f)
  (define *global-childframe* #f)

  (define (cmd-toggle-global-golden-ratio app)
    "Toggle global golden-ratio-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-golden-ratio* (not *global-golden-ratio*))
      (echo-message! echo (if *global-golden-ratio*
                            "Golden ratio ON" "Golden ratio OFF"))))

  (define (cmd-toggle-global-zoom-window app)
    "Toggle global zoom-window-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-zoom-window* (not *global-zoom-window*))
      (echo-message! echo (if *global-zoom-window*
                            "Zoom window ON" "Zoom window OFF"))))

  (define (cmd-toggle-global-shackle app)
    "Toggle global shackle-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-shackle* (not *global-shackle*))
      (echo-message! echo (if *global-shackle*
                            "Global shackle ON" "Global shackle OFF"))))

  (define (cmd-toggle-global-popwin app)
    "Toggle global popwin-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-popwin* (not *global-popwin*))
      (echo-message! echo (if *global-popwin*
                            "Global popwin ON" "Global popwin OFF"))))

  (define (cmd-toggle-global-popper app)
    "Toggle global popper-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-popper* (not *global-popper*))
      (echo-message! echo (if *global-popper*
                            "Global popper ON" "Global popper OFF"))))

  (define (cmd-toggle-global-posframe app)
    "Toggle global posframe-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-posframe* (not *global-posframe*))
      (echo-message! echo (if *global-posframe*
                            "Global posframe ON" "Global posframe OFF"))))

  (define (cmd-toggle-global-childframe app)
    "Toggle global childframe-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-childframe* (not *global-childframe*))
      (echo-message! echo (if *global-childframe*
                            "Global childframe ON" "Global childframe OFF"))))


  ;; =========================================================================
  ;; Batch 67: programming language mode toggles
  ;; =========================================================================

  (define *global-rustic* #f)
  (define *global-go-mode* #f)
  (define *global-python-black* #f)
  (define *global-elpy* #f)
  (define *global-js2-mode* #f)
  (define *global-typescript-mode* #f)
  (define *global-web-mode* #f)

  (define (cmd-toggle-global-rustic app)
    "Toggle global rustic-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-rustic* (not *global-rustic*))
      (echo-message! echo (if *global-rustic*
                            "Rustic ON" "Rustic OFF"))))

  (define (cmd-toggle-global-go-mode app)
    "Toggle global go-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-go-mode* (not *global-go-mode*))
      (echo-message! echo (if *global-go-mode*
                            "Go mode ON" "Go mode OFF"))))

  (define (cmd-toggle-global-python-black app)
    "Toggle global python-black-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-python-black* (not *global-python-black*))
      (echo-message! echo (if *global-python-black*
                            "Python black ON" "Python black OFF"))))

  (define (cmd-toggle-global-elpy app)
    "Toggle global elpy-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-elpy* (not *global-elpy*))
      (echo-message! echo (if *global-elpy*
                            "Elpy ON" "Elpy OFF"))))

  (define (cmd-toggle-global-js2-mode app)
    "Toggle global js2-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-js2-mode* (not *global-js2-mode*))
      (echo-message! echo (if *global-js2-mode*
                            "JS2 mode ON" "JS2 mode OFF"))))

  (define (cmd-toggle-global-typescript-mode app)
    "Toggle global typescript-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-typescript-mode* (not *global-typescript-mode*))
      (echo-message! echo (if *global-typescript-mode*
                            "TypeScript mode ON" "TypeScript mode OFF"))))

  (define (cmd-toggle-global-web-mode app)
    "Toggle global web-mode."
    (let ((echo (app-state-echo app)))
      (set! *global-web-mode* (not *global-web-mode*))
      (echo-message! echo (if *global-web-mode*
                            "Web mode ON" "Web mode OFF"))))


  ;; =========================================================================
  ;; Follow-mode (synchronized scrolling toggle)
  ;; =========================================================================

  (define *tui-follow-mode* #f)

  (define (cmd-follow-mode app)
    "Toggle follow-mode: synchronized scrolling across split windows."
    (set! *tui-follow-mode* (not *tui-follow-mode*))
    (echo-message! (app-state-echo app)
      (if *tui-follow-mode* "Follow mode ON" "Follow mode OFF")))


  ;; =========================================================================
  ;; Recentf-open-files
  ;; =========================================================================

  (define *recent-files* '())

  (define (cmd-recentf-open-files app)
    "Show recent files in a numbered buffer for easy selection."
    (let* ((fr (app-state-frame app))
           (ed (current-editor app))
           (recents *recent-files*)
           (lines (let loop ((fs recents) (i 1) (acc '()))
                    (if (null? fs) (reverse acc)
                      (loop (cdr fs) (+ i 1)
                            (cons (string-append "  " (number->string i) ". " (car fs))
                                  acc)))))
           (text (string-append "Recent Files:\n\n"
                                (if (null? lines) "  (no recent files)"
                                  (string-join lines "\n"))))
           (buf-name "*Recent Files*")
           (buf (or (buffer-by-name buf-name)
                    (buffer-create! buf-name ed #f))))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! (current-window fr) buf)
      (editor-set-text ed text)
      (editor-set-save-point ed)
      (editor-goto-pos ed 0)
      (echo-message! (app-state-echo app)
        (string-append (number->string (length recents)) " recent files"))))


  ;; =========================================================================
  ;; Markdown editing parity from Qt
  ;; =========================================================================

  (define (tui-get-current-line ed)
    "Get current line text, start pos, end pos for TUI editor."
    (let* ((pos (editor-get-current-pos ed))
           (line-num (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line-num))
           (line-end (editor-get-line-end-position ed line-num))
           (text (editor-get-text ed))
           (ls (min line-start (string-length text)))
           (le (min line-end (string-length text))))
      (values (substring text ls le) ls le)))

  (define (tui-md-heading-level line)
    "Count leading # chars in a markdown heading."
    (let loop ((i 0))
      (if (and (< i (string-length line)) (char=? (string-ref line i) #\#))
        (loop (+ i 1))
        (if (and (> i 0) (< i (string-length line)) (char=? (string-ref line i) #\space))
          i 0))))

  (define (cmd-markdown-promote app)
    "Decrease heading level (remove a #)."
    (let* ((ed (current-editor app)))
      (let-values (((line line-start line-end) (tui-get-current-line ed)))
        (let ((level (tui-md-heading-level line)))
          (if (<= level 1)
            (echo-error! (app-state-echo app) "Cannot promote further")
            (let ((new-line (substring line 1 (string-length line))))
              (send-message ed SCI_SETTARGETSTART line-start 0)
              (send-message ed SCI_SETTARGETEND line-end 0)
              (send-message/string ed SCI_REPLACETARGET new-line)))))))

  (define (cmd-markdown-demote app)
    "Increase heading level (add a #)."
    (let* ((ed (current-editor app)))
      (let-values (((line line-start line-end) (tui-get-current-line ed)))
        (let ((level (tui-md-heading-level line)))
          (cond
            ((= level 0)
             (let ((new-line (string-append "# " line)))
               (send-message ed SCI_SETTARGETSTART line-start 0)
               (send-message ed SCI_SETTARGETEND line-end 0)
               (send-message/string ed SCI_REPLACETARGET new-line)))
            ((>= level 6)
             (echo-error! (app-state-echo app) "Cannot demote further (max level 6)"))
            (else
             (let ((new-line (string-append "#" line)))
               (send-message ed SCI_SETTARGETSTART line-start 0)
               (send-message ed SCI_SETTARGETEND line-end 0)
               (send-message/string ed SCI_REPLACETARGET new-line))))))))

  (define (cmd-markdown-insert-heading app)
    "Insert a heading at the same level as the current one."
    (let* ((ed (current-editor app)))
      (let-values (((line line-start line-end) (tui-get-current-line ed)))
        (let* ((level (tui-md-heading-level line))
               (prefix (if (> level 0) (string-append (make-string level #\#) " ") "## "))
               (insert-text (string-append "\n" prefix)))
          (editor-insert-text ed line-end insert-text)
          (editor-goto-pos ed (+ line-end (string-length insert-text)))
          (editor-scroll-caret ed)))))

  ;; Markdown toggle and navigation
  (define (tui-markdown-toggle-wrap ed prefix)
    (if (editor-selection-empty? ed)
      (let ((pos (editor-get-current-pos ed)))
        (editor-insert-text ed pos (string-append prefix prefix))
        (editor-goto-pos ed (+ pos (string-length prefix))))
      (let* ((s (editor-get-selection-start ed)) (e (editor-get-selection-end ed))
             (text (editor-get-text ed)) (sel (substring text s e)) (plen (string-length prefix))
             (already (and (>= (string-length sel) (* 2 plen)) (string-prefix? prefix sel) (string-suffix? prefix sel)))
             (rep (if already (substring sel plen (- (string-length sel) plen)) (string-append prefix sel prefix))))
        (send-message ed SCI_SETTARGETSTART s 0) (send-message ed SCI_SETTARGETEND e 0)
        (send-message/string ed SCI_REPLACETARGET rep))))

  (define (cmd-markdown-toggle-bold app) (tui-markdown-toggle-wrap (current-editor app) "**"))
  (define (cmd-markdown-toggle-italic app) (tui-markdown-toggle-wrap (current-editor app) "*"))
  (define (cmd-markdown-toggle-code app) (tui-markdown-toggle-wrap (current-editor app) "`"))

  (define (cmd-markdown-next-heading app)
    "Jump to next heading."
    (let* ((ed (current-editor app)) (text (editor-get-text ed)) (pos (editor-get-current-pos ed)) (len (string-length text))
           (start (let lp ((i pos)) (if (or (>= i len) (char=? (string-ref text i) #\newline)) (+ i 1) (lp (+ i 1))))))
      (let lp ((i start))
        (cond ((>= i len) (echo-message! (app-state-echo app) "No more headings"))
              ((and (char=? (string-ref text i) #\#) (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
               (editor-goto-pos ed i) (editor-scroll-caret ed))
              (else (lp (+ i 1)))))))

  (define (cmd-markdown-prev-heading app)
    "Jump to previous heading."
    (let* ((ed (current-editor app)) (text (editor-get-text ed)) (pos (editor-get-current-pos ed))
           (start (let lp ((i pos)) (if (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)) (- i 1) (lp (- i 1))))))
      (let lp ((i (max 0 start)))
        (cond ((< i 0) (echo-message! (app-state-echo app) "No previous heading"))
              ((and (char=? (string-ref text i) #\#) (or (= i 0) (char=? (string-ref text (- i 1)) #\newline)))
               (editor-goto-pos ed i) (editor-scroll-caret ed))
              (else (lp (- i 1)))))))

) ;; end library
