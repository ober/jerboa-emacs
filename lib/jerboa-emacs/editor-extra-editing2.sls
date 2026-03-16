#!chezscheme
;;; -*- Chez Scheme -*-
;;; Multi-cursor, occur, markdown, dired, diff, encoding, word count,
;;; comment-dwim, kill sentence/paragraph, and s-expression navigation.
;;; Split from editor-extra-editing.sls to keep files under 2000 lines.
;;;
;;; Ported from gerbil-emacs/editor-extra-editing2.ss to R6RS Chez Scheme.

(library (jerboa-emacs editor-extra-editing2)
  (export
    ;; Multi-cursor
    cmd-mc-real-add-next
    cmd-mc-real-add-all
    cmd-mc-skip-and-add-next
    cmd-mc-cursors-on-lines
    cmd-mc-unmark-last
    cmd-mc-rotate
    ;; Occur goto
    occur-parse-source-name
    cmd-occur-goto
    cmd-occur-next
    cmd-occur-prev
    ;; Markdown
    markdown-wrap-selection
    cmd-markdown-bold
    cmd-markdown-italic
    cmd-markdown-code
    cmd-markdown-code-block
    cmd-markdown-heading
    cmd-markdown-link
    cmd-markdown-image
    cmd-markdown-hr
    cmd-markdown-list-item
    cmd-markdown-checkbox
    cmd-markdown-toggle-checkbox
    cmd-markdown-table
    cmd-markdown-preview-outline
    ;; Dired
    cmd-dired-mark
    cmd-dired-unmark
    cmd-dired-unmark-all
    cmd-dired-delete-marked
    cmd-dired-refresh
    ;; Diff
    cmd-diff-two-files
    ;; Encoding
    cmd-set-buffer-encoding
    cmd-convert-line-endings
    ;; Statistics
    cmd-buffer-statistics
    ;; Batch 42 toggles
    cmd-toggle-auto-fill-comments
    cmd-toggle-electric-indent-mode
    cmd-toggle-truncate-partial-width-windows
    cmd-toggle-inhibit-startup-screen
    cmd-toggle-visible-cursor
    cmd-toggle-transient-mark-mode
    cmd-insert-form-feed
    cmd-toggle-global-whitespace-mode
    cmd-toggle-hide-ifdef-mode
    cmd-toggle-allout-mode
    ;; Batch 49 toggles
    cmd-toggle-indent-guide-global
    cmd-toggle-rainbow-delimiters-global
    cmd-toggle-global-display-fill-column
    cmd-toggle-global-flycheck
    cmd-toggle-global-company
    cmd-toggle-global-diff-hl
    cmd-toggle-global-git-gutter
    cmd-toggle-global-page-break-lines
    cmd-toggle-global-anzu
    ;; Batch 54 toggles
    cmd-toggle-global-visual-regexp
    cmd-toggle-global-move-dup
    cmd-toggle-global-expand-region
    cmd-toggle-global-multiple-cursors
    cmd-toggle-global-undo-propose
    cmd-toggle-global-goto-chg
    cmd-toggle-global-avy
    ;; Batch 63 toggles
    cmd-toggle-global-nyan-cat
    cmd-toggle-global-parrot
    cmd-toggle-global-zone
    cmd-toggle-global-fireplace
    cmd-toggle-global-snow
    cmd-toggle-global-power-mode
    cmd-toggle-global-animate-typing
    ;; Batch 72 toggles
    cmd-toggle-global-r-mode
    cmd-toggle-global-ess
    cmd-toggle-global-sql-mode
    cmd-toggle-global-ein
    cmd-toggle-global-conda
    cmd-toggle-global-pyvenv
    cmd-toggle-global-pipenv
    ;; Comment-dwim
    cmd-comment-dwim
    ;; Kill sentence/paragraph/subword
    tui-sentence-end-pos
    tui-sentence-start-pos
    cmd-kill-sentence
    cmd-backward-kill-sentence
    cmd-kill-paragraph
    cmd-kill-subword
    ;; S-expression navigation
    cmd-up-list
    cmd-down-list
    ;; Visual line mode
    cmd-visual-line-mode
    cmd-toggle-truncate-lines
    ;; Whitespace mode
    cmd-whitespace-mode
    cmd-toggle-show-trailing-whitespace
    cmd-delete-trailing-whitespace
    ;; Enriched mode
    cmd-enriched-mode
    cmd-facemenu-set-bold
    cmd-facemenu-set-italic
    ;; Picture mode
    cmd-picture-mode
    ;; Hungry delete
    cmd-hungry-delete-forward
    cmd-hungry-delete-backward
    ;; Isearch match count
    count-search-matches
    current-match-index
    isearch-count-message
    ;; Crux
    cmd-crux-move-beginning-of-line
    ;; Hydra
    cmd-hydra-define
    cmd-hydra-zoom
    cmd-hydra-window
    ;; Deadgrep
    cmd-deadgrep
    ;; String-edit
    cmd-string-edit-at-point
    ;; Hideshow
    cmd-hs-minor-mode
    cmd-hs-toggle-hiding
    cmd-hs-hide-all
    cmd-hs-show-all
    ;; Prescient
    prescient-record!
    prescient-sort
    cmd-prescient-mode
    ;; No-littering
    cmd-no-littering-mode
    ;; Benchmark/esup
    tui-fmt-bytes
    cmd-benchmark-init-show-durations
    cmd-esup
    ;; GCMH
    cmd-gcmh-mode
    ;; Ligature
    cmd-ligature-mode
    ;; Mixed-pitch
    cmd-mixed-pitch-mode
    cmd-variable-pitch-mode
    ;; Eldoc-box
    cmd-eldoc-box-help-at-point
    cmd-eldoc-box-mode
    ;; Color-rg
    cmd-color-rg-search-input
    cmd-color-rg-search-project
    ;; Ctrlf
    cmd-ctrlf-forward
    cmd-ctrlf-backward
    ;; Phi-search
    cmd-phi-search
    cmd-phi-search-backward
    ;; Toc-org
    cmd-toc-org-mode
    cmd-toc-org-insert-toc
    ;; Org-super-agenda
    cmd-org-super-agenda-mode
    ;; Nov.el
    cmd-nov-mode
    shell-quote
    ;; LSP-UI
    cmd-lsp-ui-mode
    cmd-lsp-ui-doc-show
    cmd-lsp-ui-peek-find-definitions
    cmd-lsp-ui-peek-find-references
    ;; Emojify
    cmd-emojify-mode
    cmd-emojify-insert-emoji
    ;; Ef/Modus themes
    cmd-ef-themes-select
    cmd-modus-themes-toggle
    ;; Circadian
    cmd-circadian-mode
    tui-circadian-apply!
    cmd-auto-dark-mode
    ;; Breadcrumb
    cmd-breadcrumb-mode
    ;; Sideline
    cmd-sideline-mode
    ;; Flycheck-inline
    cmd-flycheck-inline-mode
    ;; Zone
    cmd-zone
    ;; Fireplace
    cmd-fireplace
    ;; DAP-UI / poly-mode / company-box / impatient / modeline themes
    cmd-dap-ui-mode
    cmd-poly-mode
    cmd-company-box-mode
    cmd-impatient-mode
    cmd-mood-line-mode
    cmd-powerline-mode
    cmd-centaur-tabs-mode
    cmd-all-the-icons-dired-mode
    cmd-treemacs-icons-dired-mode
    cmd-nano-theme)

  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-directory path-extension)
          (only (std srfi srfi-13) string-join string-contains string-prefix?
                string-index string-trim string-trim-right)
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
          (jerboa-emacs editor-extra-helpers)
          (jerboa-emacs editor-extra-editing)
          (only (jerboa-emacs persist)
            enriched-mode enriched-mode-set!
            picture-mode picture-mode-set!))

  ;;;=========================================================================
  ;;; Local helpers
  ;;;=========================================================================

  ;; string-subst: replace all occurrences of old with new in str
  (define (string-subst str old new)
    (let ((olen (string-length old))
          (slen (string-length str)))
      (if (= olen 0) str
        (let loop ((i 0) (acc ""))
          (if (> (+ i olen) slen)
            (string-append acc (substring str i slen))
            (if (string=? (substring str i (+ i olen)) old)
              (loop (+ i olen) (string-append acc new))
              (loop (+ i 1) (string-append acc (string (string-ref str i))))))))))

  ;; Run a command and capture stdout as a string. Returns output or #f on failure.
  (define (run-command-capture prog args)
    (guard (e (#t #f))
      (let-values (((to-stdin from-stdout from-stderr pid)
                    (open-process-ports
                      (apply string-append prog
                        (map (lambda (a) (string-append " " a)) args))
                      (buffer-mode block)
                      (native-transcoder))))
        (close-port to-stdin)
        (let ((out (get-string-all from-stdout)))
          (close-port from-stdout)
          (close-port from-stderr)
          (if (eof-object? out) #f out)))))

  ;;;=========================================================================
  ;;; Real multi-selection commands (using Scintilla multi-selection API)
  ;;;=========================================================================

  (define (cmd-mc-real-add-next app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app)))
      (if (editor-selection-empty? ed)
        (echo-error! echo "Select text first, then mark next")
        (begin
          (send-message ed SCI_MULTIPLESELECTADDNEXT 0 0)
          (let ((n (send-message ed SCI_GETSELECTIONS 0 0)))
            (echo-message! echo
              (string-append (number->string n) " cursors")))))))

  (define (cmd-mc-real-add-all app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app)))
      (if (editor-selection-empty? ed)
        (echo-error! echo "Select text first, then mark all")
        (begin
          (send-message ed SCI_MULTIPLESELECTADDEACH 0 0)
          (let ((n (send-message ed SCI_GETSELECTIONS 0 0)))
            (echo-message! echo
              (string-append (number->string n) " cursors")))))))

  (define (cmd-mc-skip-and-add-next app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app)))
      (if (editor-selection-empty? ed)
        (echo-error! echo "Select text first")
        (let ((n (send-message ed SCI_GETSELECTIONS 0 0)))
          (when (> n 1)
            (let ((main (send-message ed SCI_GETMAINSELECTION 0 0)))
              (send-message ed SCI_DROPSELECTIONN main 0)))
          (send-message ed SCI_MULTIPLESELECTADDNEXT 0 0)
          (let ((n2 (send-message ed SCI_GETSELECTIONS 0 0)))
            (echo-message! echo
              (string-append (number->string n2) " cursors")))))))

  (define (cmd-mc-cursors-on-lines app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-start (editor-get-selection-start ed))
           (sel-end (editor-get-selection-end ed)))
      (if (= sel-start sel-end)
        (echo-error! echo "Select a region first")
        (let* ((start-line (editor-line-from-position ed sel-start))
               (end-line (editor-line-from-position ed sel-end))
               (num-lines (+ 1 (- end-line start-line))))
          (when (> num-lines 1)
            (let ((eol0 (editor-get-line-end-position ed start-line)))
              (send-message ed SCI_SETSELECTION eol0 eol0)
              (let loop ((line (+ start-line 1)))
                (when (<= line end-line)
                  (let ((eol (editor-get-line-end-position ed line)))
                    (send-message ed SCI_ADDSELECTION eol eol)
                    (loop (+ line 1)))))))
          (echo-message! echo
            (string-append (number->string num-lines)
                           " cursors on " (number->string num-lines) " lines"))))))

  (define (cmd-mc-unmark-last app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (n (send-message ed SCI_GETSELECTIONS 0 0)))
      (if (<= n 1)
        (echo-message! echo "Only one cursor")
        (begin
          (send-message ed SCI_DROPSELECTIONN (- n 1) 0)
          (echo-message! echo
            (string-append (number->string (- n 1)) " cursors"))))))

  (define (cmd-mc-rotate app)
    (let ((ed (current-editor app)))
      (send-message ed SCI_ROTATESELECTION 0 0)))

  ;;;=========================================================================
  ;;; Occur goto-occurrence (TUI)
  ;;;=========================================================================

  (define (occur-parse-source-name text)
    (let ((in-pos (string-contains text " in ")))
      (and in-pos
           (let* ((after-in (+ in-pos 4))
                  (colon-pos (string-index text #\: after-in)))
             (and colon-pos
                  (substring text after-in colon-pos))))))

  (define (cmd-occur-goto app)
    (let* ((buf (current-buffer-from-app app))
           (echo (app-state-echo app)))
      (if (not (string=? (buffer-name buf) "*Occur*"))
        (echo-error! echo "Not in *Occur* buffer")
        (let* ((ed (current-editor app))
               (full-text (editor-get-text ed))
               (source-name (occur-parse-source-name full-text)))
          (if (not source-name)
            (echo-error! echo "Cannot determine source buffer")
            (let* ((pos (editor-get-current-pos ed))
                   (line-num (editor-line-from-position ed pos))
                   (line-text (editor-get-line ed line-num)))
              (let ((colon-pos (string-index line-text #\:)))
                (if (not colon-pos)
                  (echo-error! echo "Not on an occur match line")
                  (let ((target-line (string->number
                                       (substring line-text 0 colon-pos))))
                    (if (not target-line)
                      (echo-error! echo "Not on an occur match line")
                      (let ((source (buffer-by-name source-name)))
                        (if (not source)
                          (echo-error! echo
                            (string-append "Source buffer '"
                                           source-name "' not found"))
                          (let ((fr (app-state-frame app)))
                            (buffer-attach! ed source)
                            (edit-window-buffer-set! (current-window fr) source)
                            (editor-goto-line ed (- target-line 1))
                            (editor-scroll-caret ed)
                            (echo-message! echo
                              (string-append "Line "
                                             (number->string
                                               target-line))))))))))))))))

  (define (cmd-occur-next app)
    (let* ((buf (current-buffer-from-app app))
           (echo (app-state-echo app)))
      (when (string=? (buffer-name buf) "*Occur*")
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed))
               (total-lines (send-message ed SCI_GETLINECOUNT 0 0))
               (cur-line (editor-line-from-position ed pos)))
          (let loop ((l (+ cur-line 1)))
            (when (< l total-lines)
              (let ((text (editor-get-line ed l)))
                (if (and (> (string-length text) 0)
                         (char-numeric? (string-ref text 0))
                         (string-index text #\:))
                  (begin
                    (editor-goto-line ed l)
                    (editor-scroll-caret ed))
                  (loop (+ l 1))))))))))

  (define (cmd-occur-prev app)
    (let* ((buf (current-buffer-from-app app))
           (echo (app-state-echo app)))
      (when (string=? (buffer-name buf) "*Occur*")
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed))
               (cur-line (editor-line-from-position ed pos)))
          (let loop ((l (- cur-line 1)))
            (when (>= l 0)
              (let ((text (editor-get-line ed l)))
                (if (and (> (string-length text) 0)
                         (char-numeric? (string-ref text 0))
                         (string-index text #\:))
                  (begin
                    (editor-goto-line ed l)
                    (editor-scroll-caret ed))
                  (loop (- l 1))))))))))

  ;;;=========================================================================
  ;;; Markdown mode commands
  ;;;=========================================================================

  (define (markdown-wrap-selection ed prefix suffix)
    (if (editor-selection-empty? ed)
      (let ((pos (editor-get-current-pos ed)))
        (editor-insert-text ed pos (string-append prefix suffix))
        (editor-goto-pos ed (+ pos (string-length prefix))))
      (let* ((start (editor-get-selection-start ed))
             (end (editor-get-selection-end ed))
             (text (editor-get-text ed))
             (sel (substring text start end)))
        (send-message ed SCI_SETTARGETSTART start 0)
        (send-message ed SCI_SETTARGETEND end 0)
        (send-message/string ed SCI_REPLACETARGET
          (string-append prefix sel suffix)))))

  (define (cmd-markdown-bold app)
    (let ((ed (current-editor app)))
      (markdown-wrap-selection ed "**" "**")))

  (define (cmd-markdown-italic app)
    (let ((ed (current-editor app)))
      (markdown-wrap-selection ed "*" "*")))

  (define (cmd-markdown-code app)
    (let ((ed (current-editor app)))
      (markdown-wrap-selection ed "`" "`")))

  (define (cmd-markdown-code-block app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (lang (app-read-string app "Language: ")))
      (editor-insert-text ed pos
        (string-append "```" (or lang "") "\n\n```\n"))
      (editor-goto-pos ed (+ pos 4 (string-length (or lang ""))))))

  (define (cmd-markdown-heading app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (line (send-message ed SCI_LINEFROMPOSITION
                   (editor-get-current-pos ed) 0))
           (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
           (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
           (line-text (if (< line-start line-end)
                        (substring text line-start line-end) "")))
      (let ((hashes (let loop ((i 0))
                      (if (and (< i (string-length line-text))
                               (char=? (string-ref line-text i) #\#))
                        (loop (+ i 1)) i))))
        (send-message ed SCI_SETTARGETSTART line-start 0)
        (send-message ed SCI_SETTARGETEND line-end 0)
        (cond
          ((= hashes 0)
           (send-message/string ed SCI_REPLACETARGET
             (string-append "# " line-text)))
          ((>= hashes 6)
           (let ((stripped (string-trim line-text)))
             (send-message/string ed SCI_REPLACETARGET
               (let loop ((s stripped))
                 (if (and (> (string-length s) 0)
                          (char=? (string-ref s 0) #\#))
                   (loop (substring s 1 (string-length s)))
                   (string-trim s))))))
          (else
           (send-message/string ed SCI_REPLACETARGET
             (string-append "#" line-text)))))))

  (define (cmd-markdown-link app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (sel-text (if (editor-selection-empty? ed) ""
                       (let* ((s (editor-get-selection-start ed))
                              (e (editor-get-selection-end ed))
                              (text (editor-get-text ed)))
                         (substring text s e))))
           (url (app-read-string app "URL: ")))
      (when (and url (not (string=? url "")))
        (let* ((text (if (string=? sel-text "") url sel-text))
               (link (string-append "[" text "](" url ")")))
          (if (editor-selection-empty? ed)
            (editor-insert-text ed (editor-get-current-pos ed) link)
            (let ((start (editor-get-selection-start ed))
                  (end (editor-get-selection-end ed)))
              (send-message ed SCI_SETTARGETSTART start 0)
              (send-message ed SCI_SETTARGETEND end 0)
              (send-message/string ed SCI_REPLACETARGET link)))))))

  (define (cmd-markdown-image app)
    (let* ((ed (current-editor app))
           (alt (or (app-read-string app "Alt text: ") ""))
           (url (app-read-string app "Image URL: ")))
      (when (and url (not (string=? url "")))
        (editor-insert-text ed (editor-get-current-pos ed)
          (string-append "![" alt "](" url ")")))))

  (define (cmd-markdown-hr app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "\n---\n")))

  (define (cmd-markdown-list-item app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (line (send-message ed SCI_LINEFROMPOSITION
                   (editor-get-current-pos ed) 0))
           (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
           (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
           (line-text (if (< line-start line-end)
                        (substring text line-start line-end) "")))
      (let ((marker (cond
                      ((string-prefix? "- " line-text) "- ")
                      ((string-prefix? "* " line-text) "* ")
                      ((string-prefix? "  - " line-text) "  - ")
                      ((string-prefix? "  * " line-text) "  * ")
                      (else "- "))))
        (editor-goto-pos ed line-end)
        (editor-insert-text ed line-end (string-append "\n" marker)))))

  (define (cmd-markdown-checkbox app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos "- [ ] ")))

  (define (cmd-markdown-toggle-checkbox app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (line (send-message ed SCI_LINEFROMPOSITION
                   (editor-get-current-pos ed) 0))
           (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
           (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
           (line-text (if (< line-start line-end)
                        (substring text line-start line-end) "")))
      (send-message ed SCI_SETTARGETSTART line-start 0)
      (send-message ed SCI_SETTARGETEND line-end 0)
      (cond
        ((string-contains line-text "[ ]")
         (send-message/string ed SCI_REPLACETARGET
           (string-subst line-text "[ ]" "[x]")))
        ((string-contains line-text "[x]")
         (send-message/string ed SCI_REPLACETARGET
           (string-subst line-text "[x]" "[ ]")))
        (else
         (echo-message! (app-state-echo app) "No checkbox on this line")))))

  (define (cmd-markdown-table app)
    (let* ((ed (current-editor app))
           (cols-str (or (app-read-string app "Columns (default 3): ") "3"))
           (cols (or (string->number cols-str) 3))
           (pos (editor-get-current-pos ed)))
      (let* ((header (string-join (make-list cols " Header ") "|"))
             (sep (string-join (make-list cols "--------") "|"))
             (row (string-join (make-list cols "        ") "|"))
             (table (string-append "| " header " |\n| " sep " |\n| " row " |\n")))
        (editor-insert-text ed pos table))))

  (define (cmd-markdown-preview-outline app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (headings
             (let loop ((ls lines) (n 0) (acc '()))
               (if (null? ls)
                 (reverse acc)
                 (let ((l (car ls)))
                   (if (and (> (string-length l) 0) (char=? (string-ref l 0) #\#))
                     (loop (cdr ls) (+ n 1) (cons (cons n l) acc))
                     (loop (cdr ls) (+ n 1) acc)))))))
      (if (null? headings)
        (echo-message! (app-state-echo app) "No headings found")
        (let ((buf-text (string-join
                          (map (lambda (h)
                                 (string-append (number->string (+ (car h) 1))
                                                ": " (cdr h)))
                               headings)
                          "\n")))
          (open-output-buffer app "*Markdown Outline*"
            (string-append "Headings\n\n" buf-text "\n"))))))

  ;;;=========================================================================
  ;;; Dired improvements -- mark and operate on files
  ;;;=========================================================================

  (define *dired-marks* (make-hash-table))

  (define (cmd-dired-mark app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (line (send-message ed SCI_LINEFROMPOSITION
                   (editor-get-current-pos ed) 0))
           (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
           (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
           (line-text (if (< line-start line-end)
                        (substring text line-start line-end) "")))
      (let ((trimmed (string-trim line-text)))
        (when (> (string-length trimmed) 0)
          (hash-put! *dired-marks* trimmed #t)
          (send-message ed SCI_SETTARGETSTART line-start 0)
          (send-message ed SCI_SETTARGETEND line-end 0)
          (if (string-prefix? "* " line-text)
            #f
            (send-message/string ed SCI_REPLACETARGET
              (string-append "* " line-text)))
          (send-message ed 2300 0 0)
          (echo-message! (app-state-echo app)
            (string-append "Marked: " trimmed))))))

  (define (cmd-dired-unmark app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (line (send-message ed SCI_LINEFROMPOSITION
                   (editor-get-current-pos ed) 0))
           (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
           (line-end (send-message ed SCI_GETLINEENDPOSITION line 0))
           (line-text (if (< line-start line-end)
                        (substring text line-start line-end) "")))
      (when (string-prefix? "* " line-text)
        (let ((fname (substring line-text 2 (string-length line-text))))
          (hash-remove! *dired-marks* (string-trim fname))
          (send-message ed SCI_SETTARGETSTART line-start 0)
          (send-message ed SCI_SETTARGETEND line-end 0)
          (send-message/string ed SCI_REPLACETARGET
            (substring line-text 2 (string-length line-text)))))
      (send-message ed 2300 0 0)))

  (define (cmd-dired-unmark-all app)
    (set! *dired-marks* (make-hash-table))
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (new-text (string-subst text "\n* " "\n")))
      (let ((new-text2 (if (string-prefix? "* " new-text)
                         (substring new-text 2 (string-length new-text))
                         new-text)))
        (editor-set-text ed new-text2)))
    (echo-message! (app-state-echo app) "All marks cleared"))

  (define (cmd-dired-delete-marked app)
    (let* ((marked (hash-keys *dired-marks*))
           (count (length marked))
           (echo (app-state-echo app)))
      (if (= count 0)
        (echo-error! echo "No marked files")
        (let ((confirm (app-read-string app
                         (string-append "Delete " (number->string count)
                                        " file(s)? (yes/no): "))))
          (when (and confirm (string=? confirm "yes"))
            (let ((deleted 0))
              (for-each
                (lambda (f)
                  (guard (e (#t #f))
                    (when (file-exists? f)
                      (delete-file f)
                      (set! deleted (+ deleted 1)))))
                marked)
              (set! *dired-marks* (make-hash-table))
              (let ((buf (current-buffer-from-app app)))
                (when (and buf (buffer-file-path buf))
                  (cmd-dired-refresh app)))
              (echo-message! echo
                (string-append "Deleted " (number->string deleted) " file(s)"))))))))

  (define (cmd-dired-refresh app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (dir (and buf (buffer-file-path buf))))
      (when dir
        (guard (e (#t (echo-error! (app-state-echo app) "Cannot read directory")))
          (let-values (((text _entries) (dired-format-listing dir)))
            (editor-set-read-only ed #f)
            (editor-set-text ed text)
            (editor-goto-pos ed 0)
            (editor-set-read-only ed #t))))))

  ;;;=========================================================================
  ;;; Diff commands
  ;;;=========================================================================

  (define (cmd-diff-two-files app)
    (let* ((echo (app-state-echo app))
           (file1 (app-read-string app "File A: "))
           (file2 (when file1 (app-read-string app "File B: "))))
      (when (and file1 file2
                 (not (string=? file1 "")) (not (string=? file2 "")))
        (let ((result (guard (e (#t (string-append "Error: "
                                      (call-with-string-output-port
                                        (lambda (p) (display-condition e p))))))
                        (let ((out (run-command-capture "diff" (list "-u" file1 file2))))
                          (or out "Files are identical")))))
          (open-output-buffer app "*Diff*" result)))))

  ;;;=========================================================================
  ;;; Buffer encoding commands
  ;;;=========================================================================

  (define (cmd-set-buffer-encoding app)
    (let* ((echo (app-state-echo app))
           (enc (app-read-string app "Encoding (utf-8/latin-1/ascii): ")))
      (when enc
        (echo-message! echo (string-append "Encoding set to: " enc
                                            " (note: internally UTF-8)")))))

  (define (cmd-convert-line-endings app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (choice (app-read-string app "Convert to (unix/dos/mac): ")))
      (when choice
        (let ((text (editor-get-text ed)))
          (cond
            ((string=? choice "unix")
             (let ((new-text (string-subst (string-subst text "\r\n" "\n") "\r" "\n")))
               (editor-set-text ed new-text)
               (echo-message! echo "Converted to Unix line endings (LF)")))
            ((string=? choice "dos")
             (let* ((clean (string-subst (string-subst text "\r\n" "\n") "\r" "\n"))
                    (new-text (string-subst clean "\n" "\r\n")))
               (editor-set-text ed new-text)
               (echo-message! echo "Converted to DOS line endings (CRLF)")))
            ((string=? choice "mac")
             (let ((new-text (string-subst (string-subst text "\r\n" "\r") "\n" "\r")))
               (editor-set-text ed new-text)
               (echo-message! echo "Converted to Mac line endings (CR)")))
            (else
             (echo-error! echo "Unknown format. Use unix, dos, or mac.")))))))

  ;;;=========================================================================
  ;;; Word count / statistics
  ;;;=========================================================================

  (define (cmd-buffer-statistics app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (len (string-length text))
           (lines (+ 1 (let loop ((i 0) (count 0))
                         (if (>= i len) count
                           (if (char=? (string-ref text i) #\newline)
                             (loop (+ i 1) (+ count 1))
                             (loop (+ i 1) count))))))
           (words (let loop ((i 0) (count 0) (in-word #f))
                    (if (>= i len) (if in-word (+ count 1) count)
                      (let ((c (string-ref text i)))
                        (if (or (char=? c #\space) (char=? c #\newline)
                                (char=? c #\tab) (char=? c #\return))
                          (loop (+ i 1) (if in-word (+ count 1) count) #f)
                          (loop (+ i 1) count #t))))))
           (paragraphs (let loop ((i 0) (count 0) (prev-newline #f))
                         (if (>= i len) (+ count 1)
                           (let ((c (string-ref text i)))
                             (if (char=? c #\newline)
                               (loop (+ i 1) (if prev-newline (+ count 1) count) #t)
                               (loop (+ i 1) count #f))))))
           (non-blank (let loop ((i 0) (count 0))
                        (if (>= i len) count
                          (if (or (char=? (string-ref text i) #\space)
                                  (char=? (string-ref text i) #\newline)
                                  (char=? (string-ref text i) #\tab))
                            (loop (+ i 1) count)
                            (loop (+ i 1) (+ count 1)))))))
      (echo-message! (app-state-echo app)
        (string-append "Lines: " (number->string lines)
                       "  Words: " (number->string words)
                       "  Chars: " (number->string len)
                       "  Non-blank: " (number->string non-blank)
                       "  Paragraphs: " (number->string paragraphs)))))

  ;; ---- batch 42: editing preferences and modes ----
  (define *auto-fill-comments* #f)
  (define *truncate-partial-width* #f)
  (define *inhibit-startup-screen* #f)
  (define *visible-cursor* #t)
  (define *transient-mark-mode* #t)
  (define *global-whitespace-mode* #f)
  (define *hide-ifdef-mode* #f)
  (define *allout-mode* #f)

  (define (cmd-toggle-auto-fill-comments app)
    (let ((echo (app-state-echo app)))
      (set! *auto-fill-comments* (not *auto-fill-comments*))
      (echo-message! echo (if *auto-fill-comments*
                            "Auto-fill comments ON" "Auto-fill comments OFF"))))

  (define (cmd-toggle-electric-indent-mode app)
    (let ((echo (app-state-echo app)))
      (electric-indent-mode-set! (not (electric-indent-mode?)))
      (echo-message! echo (if (electric-indent-mode?)
                            "Electric indent mode ON" "Electric indent mode OFF"))))

  (define (cmd-toggle-truncate-partial-width-windows app)
    (let ((echo (app-state-echo app)))
      (set! *truncate-partial-width* (not *truncate-partial-width*))
      (echo-message! echo (if *truncate-partial-width*
                            "Truncate partial-width ON" "Truncate partial-width OFF"))))

  (define (cmd-toggle-inhibit-startup-screen app)
    (let ((echo (app-state-echo app)))
      (set! *inhibit-startup-screen* (not *inhibit-startup-screen*))
      (echo-message! echo (if *inhibit-startup-screen*
                            "Inhibit startup screen ON" "Inhibit startup screen OFF"))))

  (define (cmd-toggle-visible-cursor app)
    (let ((echo (app-state-echo app)))
      (set! *visible-cursor* (not *visible-cursor*))
      (echo-message! echo (if *visible-cursor*
                            "Visible cursor ON" "Visible cursor OFF"))))

  (define (cmd-toggle-transient-mark-mode app)
    (let ((echo (app-state-echo app)))
      (set! *transient-mark-mode* (not *transient-mark-mode*))
      (echo-message! echo (if *transient-mark-mode*
                            "Transient mark mode ON" "Transient mark mode OFF"))))

  (define (cmd-insert-form-feed app)
    (let ((ed (current-editor app)))
      (editor-replace-selection ed (string (integer->char 12)))))

  (define (cmd-toggle-global-whitespace-mode app)
    (set! *global-whitespace-mode* (not *global-whitespace-mode*))
    (echo-message! (app-state-echo app)
      (if *global-whitespace-mode* "Global whitespace mode ON" "Global whitespace mode OFF")))

  (define (cmd-toggle-hide-ifdef-mode app)
    (let ((echo (app-state-echo app)))
      (set! *hide-ifdef-mode* (not *hide-ifdef-mode*))
      (echo-message! echo (if *hide-ifdef-mode*
                            "Hide-ifdef mode ON" "Hide-ifdef mode OFF"))))

  (define (cmd-toggle-allout-mode app)
    (let ((echo (app-state-echo app)))
      (set! *allout-mode* (not *allout-mode*))
      (echo-message! echo (if *allout-mode*
                            "Allout mode ON" "Allout mode OFF"))))

  ;; ---- batch 49: global minor mode toggles ----
  (define *indent-guide-global* #f)
  (define *rainbow-delimiters-global* #f)
  (define *global-display-fill-column* #f)
  (define *global-flycheck* #f)
  (define *global-company* #f)
  (define *global-diff-hl* #f)
  (define *global-git-gutter* #f)
  (define *global-page-break-lines* #f)
  (define *global-anzu* #f)

  (define (cmd-toggle-indent-guide-global app)
    (let ((echo (app-state-echo app)))
      (set! *indent-guide-global* (not *indent-guide-global*))
      (echo-message! echo (if *indent-guide-global*
                            "Indent guide global ON" "Indent guide global OFF"))))

  (define (cmd-toggle-rainbow-delimiters-global app)
    (let ((echo (app-state-echo app)))
      (set! *rainbow-delimiters-global* (not *rainbow-delimiters-global*))
      (echo-message! echo (if *rainbow-delimiters-global*
                            "Rainbow delimiters ON" "Rainbow delimiters OFF"))))

  (define (cmd-toggle-global-display-fill-column app)
    (let ((echo (app-state-echo app)))
      (set! *global-display-fill-column* (not *global-display-fill-column*))
      (echo-message! echo (if *global-display-fill-column*
                            "Fill column indicator ON" "Fill column indicator OFF"))))

  (define (cmd-toggle-global-flycheck app)
    (let ((echo (app-state-echo app)))
      (set! *global-flycheck* (not *global-flycheck*))
      (echo-message! echo (if *global-flycheck*
                            "Global flycheck ON" "Global flycheck OFF"))))

  (define (cmd-toggle-global-company app)
    (let ((echo (app-state-echo app)))
      (set! *global-company* (not *global-company*))
      (echo-message! echo (if *global-company*
                            "Global company ON" "Global company OFF"))))

  (define (cmd-toggle-global-diff-hl app)
    (let ((echo (app-state-echo app)))
      (set! *global-diff-hl* (not *global-diff-hl*))
      (echo-message! echo (if *global-diff-hl*
                            "Global diff-hl ON" "Global diff-hl OFF"))))

  (define (cmd-toggle-global-git-gutter app)
    (let ((echo (app-state-echo app)))
      (set! *global-git-gutter* (not *global-git-gutter*))
      (echo-message! echo (if *global-git-gutter*
                            "Global git-gutter ON" "Global git-gutter OFF"))))

  (define (cmd-toggle-global-page-break-lines app)
    (let ((echo (app-state-echo app)))
      (set! *global-page-break-lines* (not *global-page-break-lines*))
      (echo-message! echo (if *global-page-break-lines*
                            "Page break lines ON" "Page break lines OFF"))))

  (define (cmd-toggle-global-anzu app)
    (let ((echo (app-state-echo app)))
      (set! *global-anzu* (not *global-anzu*))
      (echo-message! echo (if *global-anzu*
                            "Global anzu ON" "Global anzu OFF"))))

  ;; ---- batch 54: navigation and editing enhancement toggles ----
  (define *global-visual-regexp* #f)
  (define *global-move-dup* #f)
  (define *global-expand-region* #f)
  (define *global-multiple-cursors* #f)
  (define *global-undo-propose* #f)
  (define *global-goto-chg* #f)
  (define *global-avy* #f)

  (define (cmd-toggle-global-visual-regexp app)
    (let ((echo (app-state-echo app)))
      (set! *global-visual-regexp* (not *global-visual-regexp*))
      (echo-message! echo (if *global-visual-regexp*
                            "Visual regexp ON" "Visual regexp OFF"))))

  (define (cmd-toggle-global-move-dup app)
    (let ((echo (app-state-echo app)))
      (set! *global-move-dup* (not *global-move-dup*))
      (echo-message! echo (if *global-move-dup*
                            "Move-dup ON" "Move-dup OFF"))))

  (define (cmd-toggle-global-expand-region app)
    (let ((echo (app-state-echo app)))
      (set! *global-expand-region* (not *global-expand-region*))
      (echo-message! echo (if *global-expand-region*
                            "Expand-region ON" "Expand-region OFF"))))

  (define (cmd-toggle-global-multiple-cursors app)
    (let ((echo (app-state-echo app)))
      (set! *global-multiple-cursors* (not *global-multiple-cursors*))
      (echo-message! echo (if *global-multiple-cursors*
                            "Multiple cursors ON" "Multiple cursors OFF"))))

  (define (cmd-toggle-global-undo-propose app)
    (let ((echo (app-state-echo app)))
      (set! *global-undo-propose* (not *global-undo-propose*))
      (echo-message! echo (if *global-undo-propose*
                            "Undo propose ON" "Undo propose OFF"))))

  (define (cmd-toggle-global-goto-chg app)
    (let ((echo (app-state-echo app)))
      (set! *global-goto-chg* (not *global-goto-chg*))
      (echo-message! echo (if *global-goto-chg*
                            "Goto-chg ON" "Goto-chg OFF"))))

  (define (cmd-toggle-global-avy app)
    (let ((echo (app-state-echo app)))
      (set! *global-avy* (not *global-avy*))
      (echo-message! echo (if *global-avy*
                            "Global avy ON" "Global avy OFF"))))

  ;;; ---- batch 63: fun and entertainment toggles ----

  (define *global-nyan-cat* #f)
  (define *global-parrot* #f)
  (define *global-zone* #f)
  (define *global-fireplace* #f)
  (define *global-snow* #f)
  (define *global-power-mode* #f)
  (define *global-animate-typing* #f)

  (define (cmd-toggle-global-nyan-cat app)
    (let ((echo (app-state-echo app)))
      (set! *global-nyan-cat* (not *global-nyan-cat*))
      (echo-message! echo (if *global-nyan-cat*
                            "Nyan cat ON" "Nyan cat OFF"))))

  (define (cmd-toggle-global-parrot app)
    (let ((echo (app-state-echo app)))
      (set! *global-parrot* (not *global-parrot*))
      (echo-message! echo (if *global-parrot*
                            "Party parrot ON" "Party parrot OFF"))))

  (define (cmd-toggle-global-zone app)
    (let ((echo (app-state-echo app)))
      (set! *global-zone* (not *global-zone*))
      (echo-message! echo (if *global-zone*
                            "Zone mode ON" "Zone mode OFF"))))

  (define (cmd-toggle-global-fireplace app)
    (let ((echo (app-state-echo app)))
      (set! *global-fireplace* (not *global-fireplace*))
      (echo-message! echo (if *global-fireplace*
                            "Fireplace ON" "Fireplace OFF"))))

  (define (cmd-toggle-global-snow app)
    (let ((echo (app-state-echo app)))
      (set! *global-snow* (not *global-snow*))
      (echo-message! echo (if *global-snow*
                            "Snow ON" "Snow OFF"))))

  (define (cmd-toggle-global-power-mode app)
    (let ((echo (app-state-echo app)))
      (set! *global-power-mode* (not *global-power-mode*))
      (echo-message! echo (if *global-power-mode*
                            "Power mode ON" "Power mode OFF"))))

  (define (cmd-toggle-global-animate-typing app)
    (let ((echo (app-state-echo app)))
      (set! *global-animate-typing* (not *global-animate-typing*))
      (echo-message! echo (if *global-animate-typing*
                            "Animate typing ON" "Animate typing OFF"))))

  ;;; ---- batch 72: data science and environment management toggles ----

  (define *global-r-mode* #f)
  (define *global-ess* #f)
  (define *global-sql-mode* #f)
  (define *global-ein* #f)
  (define *global-conda* #f)
  (define *global-pyvenv* #f)
  (define *global-pipenv* #f)

  (define (cmd-toggle-global-r-mode app)
    (let ((echo (app-state-echo app)))
      (set! *global-r-mode* (not *global-r-mode*))
      (echo-message! echo (if *global-r-mode*
                            "R mode ON" "R mode OFF"))))

  (define (cmd-toggle-global-ess app)
    (let ((echo (app-state-echo app)))
      (set! *global-ess* (not *global-ess*))
      (echo-message! echo (if *global-ess*
                            "ESS ON" "ESS OFF"))))

  (define (cmd-toggle-global-sql-mode app)
    (let ((echo (app-state-echo app)))
      (set! *global-sql-mode* (not *global-sql-mode*))
      (echo-message! echo (if *global-sql-mode*
                            "SQL mode ON" "SQL mode OFF"))))

  (define (cmd-toggle-global-ein app)
    (let ((echo (app-state-echo app)))
      (set! *global-ein* (not *global-ein*))
      (echo-message! echo (if *global-ein*
                            "EIN ON" "EIN OFF"))))

  (define (cmd-toggle-global-conda app)
    (let ((echo (app-state-echo app)))
      (set! *global-conda* (not *global-conda*))
      (echo-message! echo (if *global-conda*
                            "Conda ON" "Conda OFF"))))

  (define (cmd-toggle-global-pyvenv app)
    (let ((echo (app-state-echo app)))
      (set! *global-pyvenv* (not *global-pyvenv*))
      (echo-message! echo (if *global-pyvenv*
                            "Pyvenv ON" "Pyvenv OFF"))))

  (define (cmd-toggle-global-pipenv app)
    (let ((echo (app-state-echo app)))
      (set! *global-pipenv* (not *global-pipenv*))
      (echo-message! echo (if *global-pipenv*
                            "Pipenv ON" "Pipenv OFF"))))

  ;;;=========================================================================
  ;;; Comment-dwim (M-;) -- Do What I Mean with comments
  ;;;=========================================================================

  (define (cmd-comment-dwim app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (text (editor-get-text ed))
           (mark (buffer-mark buf)))
      (if mark
        ;; Region active: toggle comment on region lines
        (let* ((pos (editor-get-current-pos ed))
               (start (min pos mark))
               (end (max pos mark))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end)))
          (with-undo-action ed
            (let loop ((l end-line))
              (when (>= l start-line)
                (let* ((ls (editor-position-from-line ed l))
                       (le (editor-get-line-end-position ed l))
                       (lt (substring text ls le))
                       (trimmed (string-trim lt)))
                  (if (string-prefix? ";;" trimmed)
                    ;; Uncomment
                    (let ((off (string-contains lt ";;")))
                      (when off
                        (let ((del-len (if (and (< (+ off 2) (string-length lt))
                                                (char=? (string-ref lt (+ off 2)) #\space))
                                         3 2)))
                          (editor-delete-range ed (+ ls off) del-len))))
                    ;; Comment
                    (editor-insert-text ed ls ";; ")))
                (loop (- l 1)))))
          (buffer-mark-set! buf #f)
          (echo-message! (app-state-echo app)
            (string-append "Toggled " (number->string (+ 1 (- end-line start-line))) " lines")))
        ;; No region: check current line
        (let* ((pos (editor-get-current-pos ed))
               (line (editor-line-from-position ed pos))
               (ls (editor-position-from-line ed line))
               (le (editor-get-line-end-position ed line))
               (line-text (substring text ls le))
               (trimmed (string-trim line-text)))
          (cond
            ;; Blank line: insert comment
            ((string=? trimmed "")
             (with-undo-action ed
               (editor-insert-text ed ls ";; "))
             (editor-goto-pos ed (+ ls 3)))
            ;; Already commented: uncomment
            ((string-prefix? ";;" trimmed)
             (let ((off (string-contains line-text ";;")))
               (when off
                 (let ((del-len (if (and (< (+ off 2) (string-length line-text))
                                         (char=? (string-ref line-text (+ off 2)) #\space))
                                   3 2)))
                   (with-undo-action ed
                     (editor-delete-range ed (+ ls off) del-len))))))
            ;; Not commented: add comment prefix
            (else
             (with-undo-action ed
               (editor-insert-text ed ls ";; "))))))))

  ;;;=========================================================================
  ;;; Kill sentence / paragraph / subword
  ;;;=========================================================================

  (define (tui-sentence-end-pos text pos)
    (let ((len (string-length text)))
      (let loop ((i pos))
        (cond
          ((>= i len) len)
          ((memv (string-ref text i) '(#\. #\? #\!))
           (+ i 1))
          (else (loop (+ i 1)))))))

  (define (tui-sentence-start-pos text pos)
    (let loop ((i (- pos 1)))
      (cond
        ((<= i 0) 0)
        ((memv (string-ref text i) '(#\. #\? #\!))
         (let skip-ws ((j (+ i 1)))
           (if (and (< j pos) (char-whitespace? (string-ref text j)))
             (skip-ws (+ j 1))
             j)))
        (else (loop (- i 1))))))

  (define (cmd-kill-sentence app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (end (tui-sentence-end-pos text pos))
           (killed (substring text pos end)))
      (app-state-kill-ring-set! app (cons killed (app-state-kill-ring app)))
      (with-undo-action ed (editor-delete-range ed pos (- end pos)))))

  (define (cmd-backward-kill-sentence app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (start (tui-sentence-start-pos text pos))
           (killed (substring text start pos)))
      (app-state-kill-ring-set! app (cons killed (app-state-kill-ring app)))
      (with-undo-action ed (editor-delete-range ed start (- pos start)))))

  (define (cmd-kill-paragraph app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (len (string-length text)))
      (let loop ((i pos) (saw-text? #f))
        (let ((end (cond
                     ((>= i len) len)
                     ((char=? (string-ref text i) #\newline)
                      (if (and saw-text?
                               (or (>= (+ i 1) len)
                                   (char=? (string-ref text (+ i 1)) #\newline)))
                        (+ i 1) #f))
                     (else #f))))
          (if end
            (let ((killed (substring text pos end)))
              (app-state-kill-ring-set! app (cons killed (app-state-kill-ring app)))
              (with-undo-action ed (editor-delete-range ed pos (- end pos))))
            (loop (+ i 1) (or saw-text? (not (char=? (string-ref text i) #\newline)))))))))

  (define (cmd-kill-subword app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (len (string-length text)))
      (let loop ((i (+ pos 1)))
        (let ((at-boundary?
               (or (>= i len)
                   (memv (string-ref text i) '(#\_ #\- #\space #\tab #\newline))
                   (and (> i 0)
                        (char-lower-case? (string-ref text (- i 1)))
                        (char-upper-case? (string-ref text i))))))
          (if at-boundary?
            (let* ((end (min i len))
                   (killed (substring text pos end)))
              (app-state-kill-ring-set! app (cons killed (app-state-kill-ring app)))
              (with-undo-action ed (editor-delete-range ed pos (- end pos))))
            (loop (+ i 1)))))))

  ;;;=========================================================================
  ;;; S-expression list navigation: up-list, down-list
  ;;;=========================================================================

  (define (cmd-up-list app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed)))
      (let loop ((i (- pos 1)) (depth 0))
        (cond
          ((< i 0)
           (echo-message! (app-state-echo app) "At top level"))
          ((memv (string-ref text i) '(#\) #\] #\}))
           (loop (- i 1) (+ depth 1)))
          ((memv (string-ref text i) '(#\( #\[ #\{))
           (if (= depth 0)
             (begin (editor-goto-pos ed i) (editor-scroll-caret ed))
             (loop (- i 1) (- depth 1))))
          (else (loop (- i 1) depth))))))

  (define (cmd-down-list app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (len (string-length text)))
      (let loop ((i pos))
        (cond
          ((>= i len)
           (echo-message! (app-state-echo app) "No inner list found"))
          ((memv (string-ref text i) '(#\( #\[ #\{))
           (editor-goto-pos ed (+ i 1))
           (editor-scroll-caret ed))
          (else (loop (+ i 1)))))))

  ;;; --- Visual line mode (word wrap) ---
  (define *visual-line-mode* #f)

  (define (cmd-visual-line-mode app)
    (set! *visual-line-mode* (not *visual-line-mode*))
    (let ((ed (current-editor app)))
      (when ed
        (send-message ed 2268 (if *visual-line-mode* 1 0) 0)
        (send-message ed 2460 (if *visual-line-mode* 1 0) 0)))
    (echo-message! (app-state-echo app)
      (if *visual-line-mode* "Visual line mode enabled (word wrap)" "Visual line mode disabled")))

  (define (cmd-toggle-truncate-lines app)
    (cmd-visual-line-mode app))

  ;;; --- Whitespace mode (real Scintilla implementation) ---
  (define *whitespace-mode* #f)

  (define (cmd-whitespace-mode app)
    (set! *whitespace-mode* (not *whitespace-mode*))
    (let ((ed (current-editor app)))
      (when ed
        (send-message ed 2021 (if *whitespace-mode* 1 0) 0)
        (send-message ed 2356 (if *whitespace-mode* 1 0) 0)))
    (echo-message! (app-state-echo app)
      (if *whitespace-mode* "Whitespace mode enabled" "Whitespace mode disabled")))

  ;;; --- Show trailing whitespace ---
  (define *show-trailing-whitespace* #f)

  (define (cmd-toggle-show-trailing-whitespace app)
    (set! *show-trailing-whitespace* (not *show-trailing-whitespace*))
    (let ((ed (current-editor app)))
      (when ed
        (send-message ed 2021 (if *show-trailing-whitespace* 2 0) 0)))
    (echo-message! (app-state-echo app)
      (if *show-trailing-whitespace* "Showing trailing whitespace" "Hiding trailing whitespace")))

  ;;; --- Delete trailing whitespace ---
  (define (cmd-delete-trailing-whitespace app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (cleaned (map (lambda (line)
                          (string-trim-right line))
                        lines))
           (result (string-join cleaned "\n")))
      (unless (string=? text result)
        (let ((pos (editor-get-current-pos ed)))
          (editor-set-text ed result)
          (editor-goto-pos ed (min pos (string-length result)))
          (editor-scroll-caret ed)))
      (echo-message! (app-state-echo app) "Trailing whitespace deleted")))

  ;;;=========================================================================
  ;;; Enriched text mode (basic)
  ;;;=========================================================================

  (define (cmd-enriched-mode app)
    (enriched-mode-set! (not (enriched-mode)))
    (echo-message! (app-state-echo app)
      (if (enriched-mode) "Enriched mode enabled" "Enriched mode disabled")))

  (define (cmd-facemenu-set-bold app)
    (let* ((ed (current-editor app))
           (start (send-message ed SCI_GETSELECTIONSTART 0 0))
           (end   (send-message ed SCI_GETSELECTIONEND 0 0)))
      (if (= start end)
        (echo-message! (app-state-echo app) "No selection -- select text first")
        (begin
          (send-message ed SCI_STYLESETBOLD 1 1)
          (send-message ed 2032 start 0)
          (send-message ed 2033 (- end start) 1)
          (echo-message! (app-state-echo app) "Bold applied")))))

  (define (cmd-facemenu-set-italic app)
    (let* ((ed (current-editor app))
           (start (send-message ed SCI_GETSELECTIONSTART 0 0))
           (end   (send-message ed SCI_GETSELECTIONEND 0 0)))
      (if (= start end)
        (echo-message! (app-state-echo app) "No selection -- select text first")
        (begin
          (send-message ed SCI_STYLESETITALIC 2 1)
          (send-message ed 2032 start 0)
          (send-message ed 2033 (- end start) 2)
          (echo-message! (app-state-echo app) "Italic applied")))))

  ;;;=========================================================================
  ;;; Picture mode (overwrite with cursor movement)
  ;;;=========================================================================

  (define (cmd-picture-mode app)
    (picture-mode-set! (not (picture-mode)))
    (let ((ed (current-editor app)))
      (send-message ed 2186 (if (picture-mode) 1 0) 0)
      (echo-message! (app-state-echo app)
        (if (picture-mode)
          "Picture mode ON (overwrite, use arrows to draw)"
          "Picture mode OFF"))))

  ;;; ============================================================
  ;;; Hungry delete -- delete all consecutive whitespace
  ;;; ============================================================

  (define (cmd-hungry-delete-forward app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (>= pos len)
        (echo-message! (app-state-echo app) "End of buffer")
        (let loop ((i pos))
          (if (or (>= i len)
                  (not (char-whitespace? (string-ref text i))))
            (if (> i pos)
              (begin
                (send-message ed SCI_SETTARGETSTART pos 0)
                (send-message ed SCI_SETTARGETEND i 0)
                (send-message/string ed SCI_REPLACETARGET ""))
              (send-message ed 2180 0 0))
            (loop (+ i 1)))))))

  (define (cmd-hungry-delete-backward app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      (if (<= pos 0)
        (echo-message! (app-state-echo app) "Beginning of buffer")
        (let loop ((i (- pos 1)))
          (if (or (< i 0)
                  (not (char-whitespace? (string-ref text i))))
            (let ((del-start (+ i 1)))
              (if (< del-start pos)
                (begin
                  (send-message ed SCI_SETTARGETSTART del-start 0)
                  (send-message ed SCI_SETTARGETEND pos 0)
                  (send-message/string ed SCI_REPLACETARGET ""))
                (send-message ed 2326 0 0)))
            (loop (- i 1)))))))

  ;;; ============================================================
  ;;; Isearch match count (anzu-style N/M counter)
  ;;; ============================================================

  (define (count-search-matches ed pattern)
    (let* ((text (editor-get-text ed))
           (plen (string-length pattern)))
      (if (<= plen 0) 0
        (let loop ((start 0) (count 0))
          (let ((pos (string-contains text pattern start)))
            (if pos
              (loop (+ pos 1) (+ count 1))
              count))))))

  (define (current-match-index ed pattern pos)
    (let* ((text (editor-get-text ed))
           (plen (string-length pattern)))
      (if (<= plen 0) 0
        (let loop ((start 0) (n 1))
          (let ((found (string-contains text pattern start)))
            (if (not found) 0
              (if (= found pos) n
                (loop (+ found 1) (+ n 1)))))))))

  (define (isearch-count-message ed pattern pos)
    (let ((total (count-search-matches ed pattern))
          (current (current-match-index ed pattern pos)))
      (if (> total 0)
        (string-append "[" (number->string current) "/" (number->string total) "]")
        "[0/0]")))

  ;;; ============================================================
  ;;; crux-move-beginning-of-line -- smart BOL toggle
  ;;; ============================================================

  (define (cmd-crux-move-beginning-of-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line))
           (text (editor-get-text ed))
           (len (string-length text))
           (first-nonws
             (let loop ((i line-start))
               (if (or (>= i len)
                       (let ((ch (string-ref text i)))
                         (char=? ch #\newline)))
                 i
                 (if (char-whitespace? (string-ref text i))
                   (loop (+ i 1))
                   i)))))
      (if (= pos first-nonws)
        (editor-goto-pos ed line-start)
        (editor-goto-pos ed first-nonws))))

  ;;;=========================================================================
  ;;; Hydra -- extensible popup command menus
  ;;;=========================================================================

  (define *tui-hydra-heads* (make-hash-table))

  (define (cmd-hydra-define app)
    (let ((name (app-read-string app "Hydra name: ")))
      (when (and name (> (string-length name) 0))
        (hash-put! *tui-hydra-heads* (string->symbol name) '())
        (echo-message! (app-state-echo app) (string-append "Hydra '" name "' defined (empty)")))))

  (define (cmd-hydra-zoom app)
    (echo-message! (app-state-echo app) "Zoom hydra: + increase, - decrease, 0 reset, q quit")
    (let loop ()
      (let ((key (app-read-string app "Zoom [+/-/0/q]: ")))
        (when (and key (> (string-length key) 0))
          (let ((ch (string-ref key 0)))
            (cond
              ((eqv? ch #\+) (let ((cmd (find-command 'text-scale-increase)))
                               (when cmd (cmd app))) (loop))
              ((eqv? ch #\-) (let ((cmd (find-command 'text-scale-decrease)))
                               (when cmd (cmd app))) (loop))
              ((eqv? ch #\0) (let ((cmd (find-command 'text-scale-reset)))
                               (when cmd (cmd app))) (loop))
              ((eqv? ch #\q) (echo-message! (app-state-echo app) "Zoom hydra done"))))))))

  (define (cmd-hydra-window app)
    (echo-message! (app-state-echo app) "Window hydra: h/j/k/l, s split-h, v split-v, d delete, q quit")
    (let loop ()
      (let ((key (app-read-string app "Window [hjklsvdq]: ")))
        (when (and key (> (string-length key) 0))
          (let ((ch (string-ref key 0)))
            (cond
              ((eqv? ch #\h) (let ((c (find-command 'windmove-left))) (when c (c app))) (loop))
              ((eqv? ch #\l) (let ((c (find-command 'windmove-right))) (when c (c app))) (loop))
              ((eqv? ch #\k) (let ((c (find-command 'windmove-up))) (when c (c app))) (loop))
              ((eqv? ch #\j) (let ((c (find-command 'windmove-down))) (when c (c app))) (loop))
              ((eqv? ch #\s) (let ((c (find-command 'split-window-horizontally))) (when c (c app))) (loop))
              ((eqv? ch #\v) (let ((c (find-command 'split-window-vertically))) (when c (c app))) (loop))
              ((eqv? ch #\d) (let ((c (find-command 'delete-window))) (when c (c app))) (loop))
              ((eqv? ch #\q) (echo-message! (app-state-echo app) "Window hydra done"))))))))

  ;;;=========================================================================
  ;;; Deadgrep -- enhanced grep interface
  ;;;=========================================================================

  (define (cmd-deadgrep app)
    (let* ((echo (app-state-echo app))
           (pattern (app-read-string app "Deadgrep search: ")))
      (when (and pattern (not (string=? pattern "")))
        (let ((dir (or (let ((buf (current-buffer-from-app app)))
                         (and buf (buffer-file-path buf) (path-directory (buffer-file-path buf))))
                       (current-directory))))
          (let ((rg-out (run-command-capture "rg"
                          (list "--line-number" "--no-heading" "--color" "never" pattern dir))))
            (if (and rg-out (> (string-length rg-out) 0))
              (open-output-buffer app "*Deadgrep*" (string-append "Deadgrep: " pattern " in " dir "\n\n" rg-out))
              ;; Fall back to grep
              (let ((grep-out (run-command-capture "grep" (list "-rn" pattern dir))))
                (if (and grep-out (> (string-length grep-out) 0))
                  (open-output-buffer app "*Deadgrep*" (string-append "Deadgrep: " pattern "\n\n" grep-out))
                  (echo-message! echo "No matches found")))))))))

  ;;;=========================================================================
  ;;; String-edit -- edit string at point in separate buffer
  ;;;=========================================================================

  (define (cmd-string-edit-at-point app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (let* ((qchar (if (and (< pos len) (eqv? (string-ref text pos) #\")) #\"
                     (if (and (> pos 0) (eqv? (string-ref text (- pos 1)) #\")) #\"
                       #f))))
        (if (not qchar)
          (echo-error! (app-state-echo app) "No string at point")
          (echo-message! (app-state-echo app) "String editing: use query-replace for string edits")))))

  ;;;=========================================================================
  ;;; Hideshow -- code folding
  ;;;=========================================================================

  (define *tui-hideshow-mode* #f)

  (define (cmd-hs-minor-mode app)
    (set! *tui-hideshow-mode* (not *tui-hideshow-mode*))
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win)))
      (if *tui-hideshow-mode*
        (begin
          (send-message ed SCI_SETMARGINTYPEN 2 4)
          (send-message ed SCI_SETMARGINWIDTHN 2 16)
          (send-message ed SCI_SETMARGINMASKN 2 #xFE000000)
          (send-message ed SCI_SETMARGINSENSITIVEN 2 1)
          (send-message ed SCI_MARKERDEFINE SC_MARKNUM_FOLDEROPEN SC_MARK_BOXMINUS)
          (send-message ed SCI_MARKERDEFINE SC_MARKNUM_FOLDER SC_MARK_BOXPLUS)
          (send-message ed SCI_MARKERDEFINE SC_MARKNUM_FOLDERSUB SC_MARK_VLINE)
          (send-message ed SCI_MARKERDEFINE SC_MARKNUM_FOLDERTAIL SC_MARK_LCORNER)
          (send-message ed SCI_MARKERDEFINE SC_MARKNUM_FOLDEREND SC_MARK_BOXPLUSCONNECTED)
          (send-message ed SCI_MARKERDEFINE SC_MARKNUM_FOLDEROPENMID SC_MARK_BOXMINUSCONNECTED)
          (send-message ed SCI_MARKERDEFINE SC_MARKNUM_FOLDERMIDTAIL SC_MARK_TCORNER)
          (send-message ed SCI_SETAUTOMATICFOLD 7)
          (echo-message! (app-state-echo app) "HS minor mode: on (fold margin visible)"))
        (begin
          (send-message ed SCI_FOLDALL 1)
          (send-message ed SCI_SETMARGINWIDTHN 2 0)
          (echo-message! (app-state-echo app) "HS minor mode: off")))))

  (define (cmd-hs-toggle-hiding app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (line (send-message ed SCI_LINEFROMPOSITION (send-message ed SCI_GETCURRENTPOS)))
           (level (send-message ed SCI_GETFOLDLEVEL line)))
      (when (> (bitwise-and level SC_FOLDLEVELHEADERFLAG) 0)
        (send-message ed SCI_TOGGLEFOLD line))
      (echo-message! (app-state-echo app) "Toggled fold")))

  (define (cmd-hs-hide-all app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win)))
      (send-message ed SCI_FOLDALL 0)
      (echo-message! (app-state-echo app) "All blocks hidden")))

  (define (cmd-hs-show-all app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win)))
      (send-message ed SCI_FOLDALL 1)
      (echo-message! (app-state-echo app) "All blocks shown")))

  ;;;=========================================================================
  ;;; Prescient -- completion sorting by frequency
  ;;;=========================================================================

  (define *tui-prescient-mode* #f)
  (define *prescient-frequency* (make-hash-table))

  (define (prescient-record! cmd-name)
    (when *tui-prescient-mode*
      (let ((count (or (hash-get *prescient-frequency* cmd-name) 0)))
        (hash-put! *prescient-frequency* cmd-name (+ count 1)))))

  (define (prescient-sort completions)
    (if (not *tui-prescient-mode*)
      completions
      (list-sort
        (lambda (a b)
          (let ((fa (or (hash-get *prescient-frequency* (if (symbol? a) a (string->symbol a))) 0))
                (fb (or (hash-get *prescient-frequency* (if (symbol? b) b (string->symbol b))) 0)))
            (> fa fb)))
        completions)))

  (define (cmd-prescient-mode app)
    (set! *tui-prescient-mode* (not *tui-prescient-mode*))
    (echo-message! (app-state-echo app)
      (if *tui-prescient-mode*
        "Prescient mode enabled -- commands sorted by frequency"
        "Prescient mode disabled")))

  ;;;=========================================================================
  ;;; No-littering -- clean dotfile organization
  ;;;=========================================================================

  (define (cmd-no-littering-mode app)
    (echo-message! (app-state-echo app) "Jemacs uses ~/.jemacs-* files; no littering by default"))

  ;;;=========================================================================
  ;;; Benchmark-init / esup -- startup profiling
  ;;;=========================================================================

  (define (tui-fmt-bytes b)
    (cond
      ((>= b (* 1024 1024)) (string-append (number->string (quotient b (* 1024 1024))) " MB"))
      ((>= b 1024) (string-append (number->string (quotient b 1024)) " KB"))
      (else (string-append (number->string (exact (floor b))) " B"))))

  (define (cmd-benchmark-init-show-durations app)
    ;; Chez Scheme does not have Gambit's ##process-statistics; show basic info
    (let* ((ct (current-time))
           (secs (time-second ct))
           (out (string-append
                  "=== Jemacs Runtime Statistics ===\n\n"
                  "Runtime:         Chez Scheme " (scheme-version) "\n"
                  "Machine type:    " (symbol->string (machine-type)) "\n"
                  "Time:            " (number->string secs) " seconds since epoch\n"
                  "Note:            Detailed GC/heap stats require Gambit primitives\n"
                  "                 (not available in Chez Scheme)\n")))
      (open-output-buffer app "*Runtime Stats*" out)))

  (define (cmd-esup app)
    (cmd-benchmark-init-show-durations app))

  ;;;=========================================================================
  ;;; GCMH -- GC tuning mode
  ;;;=========================================================================

  (define *tui-gcmh-mode* #f)

  (define (cmd-gcmh-mode app)
    (set! *tui-gcmh-mode* (not *tui-gcmh-mode*))
    (if *tui-gcmh-mode*
      (begin
        (collect-request-handler (lambda () (collect 0)))
        (echo-message! (app-state-echo app) "GCMH: minimal GC (fewer pauses)"))
      (begin
        (collect-request-handler void)
        (echo-message! (app-state-echo app) "GCMH disabled: default GC restored"))))

  ;;;=========================================================================
  ;;; Ligature -- font ligature display
  ;;;=========================================================================

  (define *tui-ligature-mode* #f)

  (define (cmd-ligature-mode app)
    (set! *tui-ligature-mode* (not *tui-ligature-mode*))
    (echo-message! (app-state-echo app)
      (if *tui-ligature-mode* "Ligature mode enabled (terminal dependent)" "Ligature mode disabled")))

  ;;;=========================================================================
  ;;; Mixed-pitch / variable-pitch -- font mixing
  ;;;=========================================================================

  (define *tui-mixed-pitch* #f)

  (define (cmd-mixed-pitch-mode app)
    (set! *tui-mixed-pitch* (not *tui-mixed-pitch*))
    (echo-message! (app-state-echo app)
      (if *tui-mixed-pitch* "Mixed-pitch mode enabled (N/A in terminal)" "Mixed-pitch mode disabled")))

  (define (cmd-variable-pitch-mode app)
    (cmd-mixed-pitch-mode app))

  ;;;=========================================================================
  ;;; Eldoc-box -- eldoc in popup
  ;;;=========================================================================

  (define *tui-eldoc-box* #f)

  (define (cmd-eldoc-box-help-at-point app)
    (let ((cmd (find-command 'eldoc)))
      (if cmd (cmd app)
        (echo-message! (app-state-echo app) "No eldoc available"))))

  (define (cmd-eldoc-box-mode app)
    (set! *tui-eldoc-box* (not *tui-eldoc-box*))
    (echo-message! (app-state-echo app)
      (if *tui-eldoc-box* "Eldoc-box mode enabled" "Eldoc-box mode disabled")))

  ;;;=========================================================================
  ;;; Color-rg -- colored ripgrep interface
  ;;;=========================================================================

  (define (cmd-color-rg-search-input app)
    (let ((cmd (find-command 'rgrep)))
      (when cmd (cmd app))))

  (define (cmd-color-rg-search-project app)
    (let ((cmd (find-command 'project-grep)))
      (when cmd (cmd app))))

  ;;;=========================================================================
  ;;; Ctrlf -- better isearch
  ;;;=========================================================================

  (define (cmd-ctrlf-forward app)
    (let ((cmd (find-command 'isearch-forward)))
      (when cmd (cmd app))))

  (define (cmd-ctrlf-backward app)
    (let ((cmd (find-command 'isearch-backward)))
      (when cmd (cmd app))))

  ;;;=========================================================================
  ;;; Phi-search -- another isearch alternative
  ;;;=========================================================================

  (define (cmd-phi-search app)
    (let ((cmd (find-command 'isearch-forward)))
      (when cmd (cmd app))))

  (define (cmd-phi-search-backward app)
    (let ((cmd (find-command 'isearch-backward)))
      (when cmd (cmd app))))

  ;;;=========================================================================
  ;;; Toc-org -- auto-generate table of contents in org files
  ;;;=========================================================================

  (define *tui-toc-org-mode* #f)

  (define (cmd-toc-org-mode app)
    (set! *tui-toc-org-mode* (not *tui-toc-org-mode*))
    (echo-message! (app-state-echo app)
      (if *tui-toc-org-mode* "Toc-org mode enabled" "Toc-org mode disabled")))

  (define (cmd-toc-org-insert-toc app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (text (editor-get-text ed))
           (lines (string-split text #\newline))
           (headings (filter (lambda (line) (and (> (string-length line) 0) (eqv? (string-ref line 0) #\*)))
                       lines))
           (toc-lines (map (lambda (h)
                             (let* ((level (let loop ((i 0)) (if (and (< i (string-length h)) (eqv? (string-ref h i) #\*)) (loop (+ i 1)) i)))
                                    (title (string-trim (substring h level (string-length h))))
                                    (indent (make-string (* 2 (- level 1)) #\space)))
                               (string-append indent "- " title)))
                        headings))
           (toc (string-append ":PROPERTIES:\n:TOC: :include all\n:END:\n\n" (string-join toc-lines "\n") "\n"))
           (pos (editor-get-current-pos ed)))
      (editor-insert-text ed pos toc)
      (echo-message! (app-state-echo app) (string-append "Inserted TOC with " (number->string (length headings)) " headings"))))

  ;;;=========================================================================
  ;;; Org-super-agenda -- enhanced org agenda grouping
  ;;;=========================================================================

  (define *tui-org-super-agenda* #f)

  (define (cmd-org-super-agenda-mode app)
    (set! *tui-org-super-agenda* (not *tui-org-super-agenda*))
    (echo-message! (app-state-echo app)
      (if *tui-org-super-agenda* "Org-super-agenda enabled" "Org-super-agenda disabled")))

  ;;;=========================================================================
  ;;; Nov.el -- EPUB reader
  ;;;=========================================================================

  (define (shell-quote s)
    (string-append "'" (let loop ((i 0) (out ""))
      (if (>= i (string-length s)) out
        (let ((c (string-ref s i)))
          (if (eqv? c #\')
            (loop (+ i 1) (string-append out "'\"'\"'"))
            (loop (+ i 1) (string-append out (string c))))))) "'"))

  (define (cmd-nov-mode app)
    (let ((path (app-read-string app "EPUB file: ")))
      (when (and path (> (string-length path) 0))
        (if (not (file-exists? path))
          (echo-error! (app-state-echo app) "File not found")
          (let* ((result (guard (e (#t (cons 'error
                                         (call-with-string-output-port
                                           (lambda (p) (display-condition e p))))))
                           (let ((out (run-command-capture "/bin/sh"
                                        (list "-c" (string-append "unzip -p " (shell-quote path) " '*.html' '*.xhtml' 2>/dev/null | sed 's/<[^>]*>//g' | head -500")))))
                             (cons 'ok (or out "(empty)"))))))
            (if (eq? (car result) 'error)
              (echo-error! (app-state-echo app) (string-append "EPUB error: " (cdr result)))
              (let* ((fr (app-state-frame app))
                     (win (current-window fr))
                     (ed (edit-window-editor win))
                     (buf (or (buffer-by-name "*EPUB*") (buffer-create! "*EPUB*" ed))))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! win buf)
                (editor-set-text ed (cdr result))
                (editor-goto-pos ed 0))))))))

  ;;;=========================================================================
  ;;; LSP-UI -- LSP user interface enhancements
  ;;;=========================================================================

  (define *tui-lsp-ui-mode* #f)

  (define (cmd-lsp-ui-mode app)
    (set! *tui-lsp-ui-mode* (not *tui-lsp-ui-mode*))
    (echo-message! (app-state-echo app)
      (if *tui-lsp-ui-mode* "LSP-UI mode enabled" "LSP-UI mode disabled")))

  (define (cmd-lsp-ui-doc-show app)
    (let ((cmd (find-command 'lsp-describe-thing-at-point)))
      (if cmd (cmd app)
        (echo-message! (app-state-echo app) "No LSP documentation available"))))

  (define (cmd-lsp-ui-peek-find-definitions app)
    (let ((cmd (find-command 'xref-find-definitions)))
      (when cmd (cmd app))))

  (define (cmd-lsp-ui-peek-find-references app)
    (let ((cmd (find-command 'xref-find-references)))
      (when cmd (cmd app))))

  ;;;=========================================================================
  ;;; Emojify -- emoji display mode
  ;;;=========================================================================

  (define *tui-emojify-mode* #f)

  (define (cmd-emojify-mode app)
    (set! *tui-emojify-mode* (not *tui-emojify-mode*))
    (echo-message! (app-state-echo app)
      (if *tui-emojify-mode* "Emojify mode enabled" "Emojify mode disabled")))

  (define (cmd-emojify-insert-emoji app)
    (let ((name (app-read-string app "Emoji name: ")))
      (when (and name (> (string-length name) 0))
        (let* ((fr (app-state-frame app))
               (win (current-window fr))
               (ed (edit-window-editor win))
               (pos (editor-get-current-pos ed))
               (emoji (cond
                        ((equal? name "smile") "\x1F60A;")
                        ((equal? name "thumbsup") "\x1F44D;")
                        ((equal? name "heart") "\x2764;\xFE0F;")
                        ((equal? name "fire") "\x1F525;")
                        ((equal? name "rocket") "\x1F680;")
                        ((equal? name "star") "\x2B50;")
                        ((equal? name "check") "\x2705;")
                        ((equal? name "x") "\x274C;")
                        ((equal? name "warning") "\x26A0;\xFE0F;")
                        ((equal? name "bug") "\x1F41B;")
                        (else (string-append ":" name ":")))))
          (editor-insert-text ed pos emoji)
          (editor-goto-pos ed (+ pos (string-length emoji)))))))

  ;;;=========================================================================
  ;;; Ef-themes / modus-themes -- Emacs theme packs
  ;;;=========================================================================

  (define (cmd-ef-themes-select app)
    (let ((cmd (find-command 'customize-themes)))
      (when cmd (cmd app))))

  (define (cmd-modus-themes-toggle app)
    (let ((cmd (find-command 'load-theme)))
      (if cmd (cmd app)
        (echo-message! (app-state-echo app) "Use M-x load-theme to switch themes"))))

  ;;;=========================================================================
  ;;; Circadian / auto-dark -- automatic theme switching
  ;;;=========================================================================

  (define *tui-circadian-mode* #f)

  (define (cmd-circadian-mode app)
    (set! *tui-circadian-mode* (not *tui-circadian-mode*))
    (when *tui-circadian-mode*
      (tui-circadian-apply! app))
    (echo-message! (app-state-echo app)
      (if *tui-circadian-mode* "Circadian mode enabled (auto light/dark)" "Circadian mode disabled")))

  (define (tui-circadian-apply! app)
    (let* ((now (current-time))
           (secs (time-second now))
           (hour (mod (quotient secs 3600) 24))
           (is-day (and (>= hour 7) (< hour 19)))
           (theme-cmd (find-command (if is-day 'load-theme-light 'load-theme-dark))))
      (when theme-cmd (theme-cmd app))
      (echo-message! (app-state-echo app)
        (string-append "Circadian: " (if is-day "light" "dark") " (hour " (number->string hour) ")"))))

  (define (cmd-auto-dark-mode app)
    (tui-circadian-apply! app))

  ;;;=========================================================================
  ;;; Breadcrumb -- header line with code context
  ;;;=========================================================================

  (define *tui-breadcrumb-mode* #f)

  (define (cmd-breadcrumb-mode app)
    (set! *tui-breadcrumb-mode* (not *tui-breadcrumb-mode*))
    (echo-message! (app-state-echo app)
      (if *tui-breadcrumb-mode* "Breadcrumb mode enabled" "Breadcrumb mode disabled")))

  ;;;=========================================================================
  ;;; Sideline -- side information display
  ;;;=========================================================================

  (define *tui-sideline-mode* #f)

  (define (cmd-sideline-mode app)
    (set! *tui-sideline-mode* (not *tui-sideline-mode*))
    (echo-message! (app-state-echo app)
      (if *tui-sideline-mode* "Sideline mode enabled" "Sideline mode disabled")))

  ;;;=========================================================================
  ;;; Flycheck-inline -- inline error display
  ;;;=========================================================================

  (define *tui-flycheck-inline* #f)

  (define (cmd-flycheck-inline-mode app)
    (set! *tui-flycheck-inline* (not *tui-flycheck-inline*))
    (echo-message! (app-state-echo app)
      (if *tui-flycheck-inline* "Flycheck-inline mode enabled" "Flycheck-inline mode disabled")))

  ;;;=========================================================================
  ;;; Zone -- screen saver
  ;;;=========================================================================

  (define (cmd-zone app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (original (editor-get-text ed))
           (chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()")
           (clen (string-length chars))
           (len (min 2000 (string-length original)))
           (scrambled (make-string len)))
      (let loop ((i 0))
        (when (< i len)
          (let ((c (string-ref original i)))
            (if (eqv? c #\newline)
              (string-set! scrambled i #\newline)
              (string-set! scrambled i (string-ref chars (mod (+ i (* i 7) 13) clen)))))
          (loop (+ i 1))))
      (editor-set-text ed (substring scrambled 0 len))
      (echo-message! (app-state-echo app) "Zoning out... press q to restore")
      (let ((key (app-read-string app "Press q to unzone: ")))
        (editor-set-text ed original)
        (echo-message! (app-state-echo app) "Unzoned"))))

  ;;;=========================================================================
  ;;; Fireplace -- decorative fireplace
  ;;;=========================================================================

  (define (cmd-fireplace app)
    (let* ((fr (app-state-frame app))
           (win (current-window fr))
           (ed (edit-window-editor win))
           (buf (or (buffer-by-name "*Fireplace*") (buffer-create! "*Fireplace*" ed)))
           (fire (string-append
                   "    \x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\n"
                   "   \x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\n"
                   "  \x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\x1F525;\n"
                   " \x2554;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2557;\n"
                   " \x2551;       FIREPLACE       \x2551;\n"
                   " \x255A;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x2550;\x255D;\n"
                   "   \x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\x2591;\n")))
      (buffer-attach! ed buf)
      (edit-window-buffer-set! win buf)
      (editor-set-text ed fire)
      (editor-goto-pos ed 0)))

  ;;;=========================================================================
  ;;; DAP-UI / poly-mode / company-box / impatient / modeline themes
  ;;;=========================================================================

  (define *tui-dap-ui-mode* #f)
  (define (cmd-dap-ui-mode app)
    (set! *tui-dap-ui-mode* (not *tui-dap-ui-mode*))
    (echo-message! (app-state-echo app) (if *tui-dap-ui-mode* "DAP-UI enabled" "DAP-UI disabled")))

  (define *tui-poly-mode* #f)
  (define (cmd-poly-mode app)
    (set! *tui-poly-mode* (not *tui-poly-mode*))
    (echo-message! (app-state-echo app) (if *tui-poly-mode* "Poly-mode enabled" "Poly-mode disabled")))

  (define *tui-company-box* #f)
  (define (cmd-company-box-mode app)
    (set! *tui-company-box* (not *tui-company-box*))
    (echo-message! (app-state-echo app) (if *tui-company-box* "Company-box enabled" "Company-box disabled")))

  (define *tui-impatient-mode* #f)
  (define (cmd-impatient-mode app)
    (set! *tui-impatient-mode* (not *tui-impatient-mode*))
    (echo-message! (app-state-echo app) (if *tui-impatient-mode* "Impatient mode enabled" "Impatient mode disabled")))

  (define *tui-mood-line* #f)
  (define (cmd-mood-line-mode app)
    (set! *tui-mood-line* (not *tui-mood-line*))
    (echo-message! (app-state-echo app) (if *tui-mood-line* "Mood-line enabled" "Mood-line disabled")))

  (define *tui-powerline* #f)
  (define (cmd-powerline-mode app)
    (set! *tui-powerline* (not *tui-powerline*))
    (echo-message! (app-state-echo app) (if *tui-powerline* "Powerline enabled" "Powerline disabled")))

  (define *tui-centaur-tabs* #f)
  (define (cmd-centaur-tabs-mode app)
    (set! *tui-centaur-tabs* (not *tui-centaur-tabs*))
    (echo-message! (app-state-echo app) (if *tui-centaur-tabs* "Centaur-tabs enabled" "Centaur-tabs disabled")))

  (define (cmd-all-the-icons-dired-mode app)
    (echo-message! (app-state-echo app) "Icon display in dired: N/A in terminal"))

  (define (cmd-treemacs-icons-dired-mode app)
    (echo-message! (app-state-echo app) "Treemacs icons: N/A in terminal"))

  (define (cmd-nano-theme app)
    (let ((cmd (find-command 'load-theme))) (when cmd (cmd app))))

) ;; end library
