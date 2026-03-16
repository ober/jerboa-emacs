#!chezscheme
;;; -*- Chez Scheme -*-
;;; editor-text.sls — Text manipulation: sort, bookmarks, rectangles,
;;; paren match, join lines, case, fill paragraph, grep, dabbrev,
;;; keyboard macros, mark ring, registers, zap, transpose
;;;
;;; Ported from gerbil-emacs/editor-text.ss to R6RS Chez Scheme.

(library (jerboa-emacs editor-text)
  (export
    ;; Sort
    cmd-sort-lines

    ;; Bookmarks
    cmd-bookmark-set
    cmd-bookmark-jump
    cmd-bookmark-list

    ;; Rectangle operations
    get-region-lines
    cmd-kill-rectangle
    cmd-delete-rectangle
    cmd-yank-rectangle
    cmd-string-rectangle
    cmd-open-rectangle

    ;; Paren matching
    cmd-goto-matching-paren

    ;; Join / blank lines
    cmd-join-line
    cmd-delete-blank-lines

    ;; Indent region
    cmd-indent-region

    ;; Case region
    cmd-downcase-region
    cmd-upcase-region

    ;; Shell command
    cmd-shell-command

    ;; Fill paragraph
    cmd-fill-paragraph

    ;; Grep
    cmd-grep
    shell-quote

    ;; Narrow state
    *tui-narrow-state*

    ;; Insert file
    cmd-insert-file

    ;; Dynamic abbreviation
    collect-dabbrev-matches
    collect-dabbrev-from-other-buffers
    cmd-dabbrev-expand

    ;; Cursor position info
    cmd-what-cursor-position

    ;; Keyboard macros
    cmd-start-kbd-macro
    cmd-end-kbd-macro
    cmd-call-last-kbd-macro
    macro-record-step!
    cmd-name-last-kbd-macro
    cmd-call-named-kbd-macro
    cmd-list-kbd-macros
    cmd-save-kbd-macros
    cmd-load-kbd-macros

    ;; Mark ring
    cmd-pop-mark

    ;; Registers
    cmd-copy-to-register
    find-buffer-by-file-path
    jump-to-register-file!
    cmd-insert-register
    cmd-point-to-register
    cmd-jump-to-register

    ;; Kill word, zap, goto char
    cmd-backward-kill-word
    cmd-zap-to-char
    cmd-goto-char

    ;; Replace string
    cmd-replace-string

    ;; Transpose
    cmd-transpose-words
    cmd-transpose-lines

    ;; Just one space, repeat
    cmd-just-one-space
    cmd-repeat

    ;; Next/previous error
    cmd-next-error
    cmd-previous-error

    ;; Kill whole line, move line
    cmd-kill-whole-line
    cmd-move-line-up
    cmd-move-line-down

    ;; Pipe buffer, narrow/widen
    cmd-pipe-buffer
    cmd-narrow-to-region
    cmd-widen

    ;; Number lines, reverse region
    cmd-number-lines
    cmd-reverse-region

    ;; Flush/keep lines
    cmd-flush-lines
    cmd-keep-lines

    ;; Align regexp
    cmd-align-regexp

    ;; Sort fields
    cmd-sort-fields

    ;; Mark word/paragraph, paragraph navigation
    cmd-mark-word
    cmd-mark-paragraph
    cmd-forward-paragraph
    cmd-backward-paragraph

    ;; Indentation
    cmd-back-to-indentation
    cmd-delete-indentation

    ;; Whitespace
    cmd-cycle-spacing
    cmd-fixup-whitespace

    ;; Autocomplete
    cmd-complete-at-point

    ;; Calltips
    show-calltip!
    cancel-calltip!

    )

  (import (except (chezscheme) make-hash-table hash-table? iota 1+ 1- sort sort!
            path-extension)
          (jerboa core)
          (jerboa runtime)
          (only (jerboa prelude) path-directory path-strip-directory path-extension)
          (only (std srfi srfi-13) string-join string-contains string-prefix?
                string-suffix? string-index string-trim-both string-trim-right)
          (only (std misc string) string-split)
          (chez-scintilla constants)
          (chez-scintilla scintilla)
          (chez-scintilla style)
          (chez-scintilla tui)
          (chez-scintilla ffi)
          (jerboa-emacs core)
          (jerboa-emacs subprocess)
          (jerboa-emacs gsh-subprocess)
          (jerboa-emacs repl)
          (jerboa-emacs eshell)
          (jerboa-emacs shell)
          (jerboa-emacs keymap)
          (jerboa-emacs buffer)
          (jerboa-emacs window)
          (jerboa-emacs modeline)
          (jerboa-emacs echo)
          (jerboa-emacs highlight)
          (jerboa-emacs editor-core)
          (jerboa-emacs persist))

  ;; =========================================================================
  ;; Local helpers (would come from editor-core / editor-ui when ported)
  ;; =========================================================================

  (define (word-char? ch)
    (or (char-alphabetic? ch) (char-numeric? ch) (char=? ch #\_) (char=? ch #\-)))

  ;; string-trim that trims all whitespace (like Gerbil's default)
  (define (string-trim-whitespace s)
    (let ((len (string-length s)))
      (let lp ((i 0))
        (cond
          ((>= i len) "")
          ((char-whitespace? (string-ref s i)) (lp (+ i 1)))
          (else (substring s i len))))))

  ;; trim trailing chars matching a specific char
  (define (string-trim-right-char s ch)
    (string-trim-right s (lambda (c) (char=? c ch))))

  ;; Narrowing state: hashtable of buffer -> (full-text start end)
  (define *tui-narrow-state* (make-hash-table))

  ;; =========================================================================
  ;; Sort lines (M-^)
  ;; =========================================================================

  (define (cmd-sort-lines app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf))
           (text (editor-get-text ed)))
      (if mark
        ;; Sort region only
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (region (substring text start end))
               (lines (string-split region #\newline))
               (sorted (list-sort string<? lines))
               (result (string-join sorted "\n")))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (buffer-mark-set! buf #f)
          (echo-message! (app-state-echo app)
            (string-append "Sorted " (number->string (length sorted)) " lines")))
        ;; Sort whole buffer
        (let* ((lines (string-split text #\newline))
               (sorted (list-sort string<? lines))
               (result (string-join sorted "\n"))
               (pos (editor-get-current-pos ed)))
          (editor-set-text ed result)
          (editor-goto-pos ed (min pos (editor-get-text-length ed)))
          (echo-message! (app-state-echo app)
            (string-append "Sorted " (number->string (length sorted)) " lines"))))))

  ;; =========================================================================
  ;; Bookmarks
  ;; =========================================================================

  (define (cmd-bookmark-set app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (name (echo-read-string echo "Bookmark name: " row width)))
      (when (and name (> (string-length name) 0))
        (let* ((buf (current-buffer-from-app app))
               (ed (current-editor app))
               (pos (editor-get-current-pos ed)))
          (hash-put! (app-state-bookmarks app) name
                     (list (buffer-name buf) (buffer-file-path buf) pos))
          (echo-message! echo (string-append "Bookmark \"" name "\" set"))))))

  (define (cmd-bookmark-jump app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (bm-names (list-sort string<? (hash-keys (app-state-bookmarks app))))
           (name (echo-read-string-with-completion echo "Jump to bookmark: " bm-names row width)))
      (when (and name (> (string-length name) 0))
        (let ((bm (hash-get (app-state-bookmarks app) name)))
          (if bm
            (let* ((buf-name (if (list? bm) (car bm) (car bm)))
                   (fpath (if (list? bm) (cadr bm) #f))
                   (pos (if (list? bm) (caddr bm) (cdr bm)))
                   (buf (or (buffer-by-name buf-name)
                            ;; Try to find buffer by file path
                            (and fpath
                                 (let loop ((bufs (buffer-list)))
                                   (if (null? bufs) #f
                                     (let ((b (car bufs)))
                                       (if (and (buffer-file-path b)
                                                (string=? (buffer-file-path b) fpath))
                                         b (loop (cdr bufs))))))))))
              (if buf
                (let ((ed (current-editor app)))
                  (buffer-attach! ed buf)
                  (edit-window-buffer-set! (current-window fr) buf)
                  (editor-goto-pos ed pos)
                  (editor-scroll-caret ed)
                  (echo-message! echo (string-append "Jumped to \"" name "\"")))
                (echo-error! echo (string-append "Buffer gone: " (or fpath buf-name)))))
            (echo-error! echo (string-append "No bookmark: " name)))))))

  (define (cmd-bookmark-list app)
    (let* ((fr (app-state-frame app))
           (ed (current-editor app))
           (bms (app-state-bookmarks app))
           (entries '()))
      (hash-for-each
        (lambda (name val)
          (let* ((buf-name (if (list? val) (car val) (car val)))
                 (fpath (if (list? val) (cadr val) #f))
                 (pos (if (list? val) (caddr val) (cdr val))))
            (set! entries
              (cons (string-append "  " name "\t"
                                   (or fpath buf-name) " pos "
                                   (number->string pos))
                    entries))))
        bms)
      (let* ((sorted (list-sort string<? entries))
             (text (if (null? sorted)
                     "No bookmarks set.\n"
                     (string-append "Bookmarks:\n\n"
                                    (string-join sorted "\n")
                                    "\n")))
             (buf (or (buffer-by-name "*Bookmarks*")
                      (buffer-create! "*Bookmarks*" ed #f))))
        (buffer-attach! ed buf)
        (edit-window-buffer-set! (current-window fr) buf)
        (editor-set-text ed text)
        (editor-set-save-point ed)
        (editor-goto-pos ed 0)
        (echo-message! (app-state-echo app) "*Bookmarks*"))))

  ;; =========================================================================
  ;; Rectangle operations
  ;; =========================================================================

  (define (get-region-lines app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (values #f #f #f #f)
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (start-col (editor-get-column ed start))
               (end-col (editor-get-column ed end)))
          (values start-line start-col end-line end-col)))))

  (define (cmd-kill-rectangle app)
    (let ((echo (app-state-echo app)))
      (let-values (((start-line start-col end-line end-col) (get-region-lines app)))
        (if (not start-line)
          (echo-error! echo "No region (set mark first)")
          (let* ((ed (current-editor app))
                 (left-col (min start-col end-col))
                 (right-col (max start-col end-col))
                 (rect-lines '()))
            ;; Extract and delete rectangle, line by line from bottom to top
            (let loop ((line end-line))
              (when (>= line start-line)
                (let* ((line-start (editor-position-from-line ed line))
                       (line-end (editor-get-line-end-position ed line))
                       (line-text (editor-get-line ed line))
                       (line-len (string-length (string-trim-right-char line-text #\newline)))
                       (l (min left-col line-len))
                       (r (min right-col line-len))
                       (extracted (if (< l r)
                                    (substring (string-trim-right-char line-text #\newline) l r)
                                    "")))
                  (set! rect-lines (cons extracted rect-lines))
                  ;; Delete the rectangle portion of this line
                  (when (< l r)
                    (editor-delete-range ed (+ line-start l) (- r l)))
                  (loop (- line 1)))))
            ;; Store in rectangle kill ring
            (app-state-rect-kill-set! app rect-lines)
            (buffer-mark-set! (current-buffer-from-app app) #f)
            (echo-message! echo
              (string-append "Killed rectangle (" (number->string (length rect-lines)) " lines)")))))))

  (define (cmd-delete-rectangle app)
    (let ((echo (app-state-echo app)))
      (let-values (((start-line start-col end-line end-col) (get-region-lines app)))
        (if (not start-line)
          (echo-error! echo "No region (set mark first)")
          (let* ((ed (current-editor app))
                 (left-col (min start-col end-col))
                 (right-col (max start-col end-col)))
            (with-undo-action ed
              (let loop ((line end-line))
                (when (>= line start-line)
                  (let* ((line-start (editor-position-from-line ed line))
                         (line-text (editor-get-line ed line))
                         (line-len (string-length (string-trim-right-char line-text #\newline)))
                         (l (min left-col line-len))
                         (r (min right-col line-len)))
                    (when (< l r)
                      (editor-delete-range ed (+ line-start l) (- r l)))
                    (loop (- line 1))))))
            (buffer-mark-set! (current-buffer-from-app app) #f)
            (echo-message! echo "Rectangle deleted"))))))

  (define (cmd-yank-rectangle app)
    (let* ((echo (app-state-echo app))
           (rk (app-state-rect-kill app)))
      (if (null? rk)
        (echo-error! echo "No rectangle to yank")
        (let* ((ed (current-editor app))
               (pos (editor-get-current-pos ed))
               (line (editor-line-from-position ed pos))
               (col (editor-get-column ed pos)))
          (with-undo-action ed
            (let loop ((lines rk) (cur-line line))
              (when (pair? lines)
                (let* ((rect-text (car lines))
                       (line-start (editor-position-from-line ed cur-line))
                       (line-end (editor-get-line-end-position ed cur-line))
                       (line-len (- line-end line-start))
                       ;; Pad line if shorter than insertion column
                       (insert-pos (+ line-start (min col line-len))))
                  (when (< line-len col)
                    (editor-insert-text ed line-end
                      (make-string (- col line-len) #\space)))
                  (let ((actual-pos (+ line-start col)))
                    (editor-insert-text ed actual-pos rect-text)))
                (loop (cdr lines) (+ cur-line 1)))))
          (echo-message! echo "Rectangle yanked")))))

  ;; =========================================================================
  ;; Go to matching paren
  ;; =========================================================================

  (define (cmd-goto-matching-paren app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (ch-at (send-message ed SCI_GETCHARAT pos 0))
           (ch-before (if (> pos 0) (send-message ed SCI_GETCHARAT (- pos 1) 0) 0)))
      (cond
        ((brace-char? ch-at)
         (let ((match (send-message ed SCI_BRACEMATCH pos 0)))
           (if (>= match 0)
             (editor-goto-pos ed match)
             (echo-error! (app-state-echo app) "No matching paren"))))
        ((brace-char? ch-before)
         (let ((match (send-message ed SCI_BRACEMATCH (- pos 1) 0)))
           (if (>= match 0)
             (editor-goto-pos ed match)
             (echo-error! (app-state-echo app) "No matching paren"))))
        (else
         (echo-error! (app-state-echo app) "Not on a paren")))))

  ;; =========================================================================
  ;; Join line (M-j)
  ;; =========================================================================

  (define (cmd-join-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-end (editor-get-line-end-position ed line))
           (total (editor-get-line-count ed)))
      (when (< (+ line 1) total)
        ;; Get next line text to find leading whitespace
        (let* ((next-start (editor-position-from-line ed (+ line 1)))
               (text (editor-get-text ed))
               (next-ws-end next-start))
          ;; Skip whitespace at start of next line
          (let skip ((i next-start))
            (when (< i (string-length text))
              (let ((ch (string-ref text i)))
                (when (or (char=? ch #\space) (char=? ch #\tab))
                  (set! next-ws-end (+ i 1))
                  (skip (+ i 1))))))
          ;; Delete from end of current line to end of whitespace on next line
          ;; and insert a single space
          (with-undo-action ed
            (editor-delete-range ed line-end (- next-ws-end line-end))
            (editor-insert-text ed line-end " "))))))

  ;; =========================================================================
  ;; Delete blank lines (C-x C-o)
  ;; =========================================================================

  (define (cmd-delete-blank-lines app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (line (editor-line-from-position ed pos))
           (total (editor-get-line-count ed))
           ;; Check if current line is blank
           (line-text (editor-get-line ed line))
           (blank? (lambda (s) (string=? (string-trim-whitespace s) ""))))
      (if (blank? line-text)
        ;; Find range of blank lines around point
        (let find-start ((l line))
          (let ((start (if (and (> l 0) (blank? (editor-get-line ed (- l 1))))
                         (find-start (- l 1))
                         l)))
            (let find-end ((l line))
              (let ((end (if (and (< (+ l 1) total) (blank? (editor-get-line ed (+ l 1))))
                           (find-end (+ l 1))
                           l)))
                ;; Delete from start of first blank line to end of last + newline
                (let* ((del-start (editor-position-from-line ed start))
                       (del-end (if (< (+ end 1) total)
                                  (editor-position-from-line ed (+ end 1))
                                  (editor-get-text-length ed))))
                  ;; Keep one blank line
                  (editor-delete-range ed del-start (- del-end del-start))
                  (editor-insert-text ed del-start "\n")
                  (echo-message! (app-state-echo app) "Blank lines deleted"))))))
        (echo-message! (app-state-echo app) "Not on a blank line"))))

  ;; =========================================================================
  ;; Indent region
  ;; =========================================================================

  (define (cmd-indent-region app)
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region (set mark first)")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end)))
          (with-undo-action ed
            ;; Insert 2 spaces at beginning of each line, from bottom to top
            (let loop ((line end-line))
              (when (>= line start-line)
                (let ((line-pos (editor-position-from-line ed line)))
                  (editor-insert-text ed line-pos "  "))
                (loop (- line 1)))))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Region indented")))))

  ;; =========================================================================
  ;; Case region
  ;; =========================================================================

  (define (cmd-downcase-region app)
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (text (editor-get-text ed))
               (region (substring text start end))
               (lower (string-downcase region)))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start lower))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Region downcased")))))

  (define (cmd-upcase-region app)
    (let* ((echo (app-state-echo app))
           (ed (current-editor app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if (not mark)
        (echo-error! echo "No region")
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (text (editor-get-text ed))
               (region (substring text start end))
               (upper (string-upcase region)))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start upper))
          (buffer-mark-set! buf #f)
          (echo-message! echo "Region upcased")))))

  ;; =========================================================================
  ;; Shell command (M-!)
  ;; =========================================================================

  (define (cmd-shell-command app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (cmd (echo-read-string echo "Shell command: " row width)))
      (when (and cmd (> (string-length cmd) 0))
        (echo-message! echo (string-append "Running... (C-g to cancel)"))
        (frame-refresh! fr)
        (let-values (((output _status)
                      (gsh-run-command
                        cmd tui-peek-event tui-event-key? tui-event-key)))
          (let ((ed (current-editor app)))
            ;; If short output (1 line), show in echo area
            (if (not (string-contains output "\n"))
              (echo-message! echo output)
              ;; Multi-line: show in *Shell Output* buffer
              (let ((buf (or (buffer-by-name "*Shell Output*")
                             (buffer-create! "*Shell Output*" ed #f))))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! (current-window fr) buf)
                (editor-set-text ed output)
                (editor-set-save-point ed)
                (editor-goto-pos ed 0)
                (echo-message! echo "Shell command done"))))))))

  ;; =========================================================================
  ;; Fill paragraph (M-q) -- word wrap at fill-column (80)
  ;; =========================================================================

  (define (cmd-fill-paragraph app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Find paragraph boundaries (blank lines or start/end of buffer)
      (let* ((para-start
               (let loop ((i (- pos 1)))
                 (cond
                   ((< i 0) 0)
                   ((and (char=? (string-ref text i) #\newline)
                         (or (= i 0)
                             (and (> i 0) (char=? (string-ref text (- i 1)) #\newline))))
                    (+ i 1))
                   (else (loop (- i 1))))))
             (para-end
               (let loop ((i pos))
                 (cond
                   ((>= i len) len)
                   ((and (char=? (string-ref text i) #\newline)
                         (< (+ i 1) len)
                         (char=? (string-ref text (+ i 1)) #\newline))
                    i)
                   (else (loop (+ i 1))))))
             (para-text (substring text para-start para-end))
             ;; Collapse whitespace and split into words
             (words (let split ((s para-text) (acc '()))
                      (let ((trimmed (string-trim-whitespace s)))
                        (if (string=? trimmed "")
                          (reverse acc)
                          ;; Find next word boundary
                          (let find-end ((i 0))
                            (cond
                              ((>= i (string-length trimmed))
                               (reverse (cons trimmed acc)))
                              ((or (char=? (string-ref trimmed i) #\space)
                                   (char=? (string-ref trimmed i) #\newline)
                                   (char=? (string-ref trimmed i) #\tab))
                               (split (substring trimmed i (string-length trimmed))
                                      (cons (substring trimmed 0 i) acc)))
                              (else (find-end (+ i 1)))))))))
             ;; Rebuild with word wrap
             (filled (let loop ((ws words) (line "") (lines '()))
                       (if (null? ws)
                         (string-join (reverse (if (string=? line "") lines
                                                  (cons line lines)))
                                     "\n")
                         (let* ((word (car ws))
                                (new-line (if (string=? line "")
                                            word
                                            (string-append line " " word))))
                           (if (> (string-length new-line) fill-column)
                             ;; Wrap
                             (if (string=? line "")
                               ;; Single word longer than fill-column
                               (loop (cdr ws) "" (cons word lines))
                               (loop ws "" (cons line lines)))
                             (loop (cdr ws) new-line lines)))))))
        ;; Replace paragraph text
        (with-undo-action ed
          (editor-delete-range ed para-start (- para-end para-start))
          (editor-insert-text ed para-start filled))
        (echo-message! (app-state-echo app) "Paragraph filled"))))

  ;; =========================================================================
  ;; Grep (M-x grep)
  ;; =========================================================================

  (define (cmd-grep app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (pattern (echo-read-string echo "Grep: " row width)))
      (when (and pattern (> (string-length pattern) 0))
        (let* ((dir (echo-read-string echo "In directory: " row width))
               (search-dir (if (or (not dir) (string=? dir "")) "." dir)))
          (echo-message! echo (string-append "Searching... (C-g to cancel)"))
          (frame-refresh! fr)
          (let* ((ed (current-editor app))
                 (grep-cmd (string-append "grep -rn --include='*.ss' --include='*.scm' "
                                          "-- " (shell-quote pattern) " "
                                          (shell-quote search-dir) " 2>&1 || true")))
            (let-values (((output _status)
                          (gsh-run-command
                            grep-cmd tui-peek-event tui-event-key? tui-event-key)))
              (let* ((text (string-append "-*- Grep -*-\n"
                                          "Pattern: " pattern "\n"
                                          "Directory: " search-dir "\n"
                                          (make-string 60 #\-) "\n\n"
                                          output "\n"))
                     (buf (or (buffer-by-name "*Grep*")
                              (buffer-create! "*Grep*" ed #f))))
                (buffer-attach! ed buf)
                (edit-window-buffer-set! (current-window fr) buf)
                (editor-set-text ed text)
                (editor-set-save-point ed)
                (editor-goto-pos ed 0)
                (echo-message! echo "Grep done"))))))))

  (define (shell-quote s)
    (string-append "'" (let loop ((i 0) (acc ""))
                         (if (>= i (string-length s))
                           acc
                           (let ((ch (string-ref s i)))
                             (if (char=? ch #\')
                               (loop (+ i 1) (string-append acc "'\"'\"'"))
                               (loop (+ i 1) (string-append acc (string ch)))))))
                   "'"))

  ;; =========================================================================
  ;; Insert file (C-x i)
  ;; =========================================================================

  (define (cmd-insert-file app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (filename (echo-read-string echo "Insert file: " row width)))
      (when (and filename (> (string-length filename) 0))
        (if (file-exists? filename)
          (let* ((text (read-file-as-string filename))
                 (ed (current-editor app))
                 (pos (editor-get-current-pos ed)))
            (when text
              (editor-insert-text ed pos text)
              (echo-message! echo (string-append "Inserted " filename))))
          (echo-error! echo (string-append "File not found: " filename))))))

  ;; =========================================================================
  ;; Dynamic abbreviation (M-/)
  ;; =========================================================================

  (define (collect-dabbrev-matches text prefix pos)
    (let* ((plen (string-length prefix))
           (tlen (string-length text))
           (matches '()))
      ;; Scan the entire text for words matching the prefix
      (let loop ((i 0))
        (when (< i tlen)
          ;; Find start of word
          (if (or (char-alphabetic? (string-ref text i))
                  (char=? (string-ref text i) #\_)
                  (char=? (string-ref text i) #\-))
            (let find-end ((j (+ i 1)))
              (if (or (>= j tlen)
                      (not (or (char-alphabetic? (string-ref text j))
                               (char-numeric? (string-ref text j))
                               (char=? (string-ref text j) #\_)
                               (char=? (string-ref text j) #\-)
                               (char=? (string-ref text j) #\?)
                               (char=? (string-ref text j) #\!))))
                (let ((word (substring text i j)))
                  (when (and (> (string-length word) plen)
                             (string=? (substring word 0 plen) prefix)
                             (not (= i (- pos plen))))  ; Skip the prefix itself
                    (set! matches (cons (cons (abs (- i pos)) word) matches)))
                  (loop j))
                (find-end (+ j 1))))
            (loop (+ i 1)))))
      ;; Sort by distance from cursor, remove duplicates
      (let* ((sorted (list-sort (lambda (a b) (< (car a) (car b))) matches))
             (words (map cdr sorted)))
        ;; Remove duplicates keeping order
        (let dedup ((ws words) (seen '()) (acc '()))
          (if (null? ws) (reverse acc)
            (if (member (car ws) seen)
              (dedup (cdr ws) seen acc)
              (dedup (cdr ws) (cons (car ws) seen) (cons (car ws) acc))))))))

  (define (collect-dabbrev-from-other-buffers prefix seen)
    (let ((results '()))
      (for-each
        (lambda (buf)
          (let ((fp (buffer-file-path buf)))
            (when fp
              (guard (e (#t (void)))
                (when (file-exists? fp)
                  (let* ((file-text (call-with-input-file fp
                                      (lambda (p) (get-string-all p))))
                         (plen (string-length prefix))
                         (tlen (string-length file-text)))
                    (let loop ((i 0))
                      (when (< i tlen)
                        (if (or (char-alphabetic? (string-ref file-text i))
                                (eqv? (string-ref file-text i) #\_)
                                (eqv? (string-ref file-text i) #\-))
                          (let find-end ((j (+ i 1)))
                            (if (or (>= j tlen)
                                    (not (or (char-alphabetic? (string-ref file-text j))
                                             (char-numeric? (string-ref file-text j))
                                             (eqv? (string-ref file-text j) #\_)
                                             (eqv? (string-ref file-text j) #\-)
                                             (eqv? (string-ref file-text j) #\?)
                                             (eqv? (string-ref file-text j) #\!))))
                              (begin
                                (let ((word (substring file-text i j)))
                                  (when (and (> (string-length word) plen)
                                             (string=? (substring word 0 plen) prefix)
                                             (not (member word seen))
                                             (not (member word results)))
                                    (set! results (cons word results))))
                                (loop j))
                              (find-end (+ j 1))))
                          (loop (+ i 1)))))))))))
        (buffer-list))
      results))

  (define (cmd-dabbrev-expand app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (echo (app-state-echo app))
           (state (app-state-dabbrev-state app)))
      (if (and state (pair? state))
        ;; Continue cycling through matches
        (let* ((prefix (car state))
               (remaining (cadr state))
               (last-pos (caddr state))
               (last-len (cadddr state)))
          (if (null? remaining)
            (begin
              (app-state-dabbrev-state-set! app #f)
              (echo-message! echo "No more expansions"))
            (let* ((next (car remaining))
                   (expand-len (- (string-length next) (string-length prefix))))
              ;; Delete previous expansion
              (editor-delete-range ed (+ last-pos (string-length prefix))
                                  (- last-len (string-length prefix)))
              ;; Insert new expansion
              (editor-insert-text ed (+ last-pos (string-length prefix))
                                  (substring next (string-length prefix)
                                             (string-length next)))
              (editor-goto-pos ed (+ last-pos (string-length next)))
              (app-state-dabbrev-state-set! app
                (list prefix (cdr remaining) last-pos (string-length next))))))
        ;; First expansion: find prefix before cursor
        (let find-prefix ((i (- pos 1)) (count 0))
          (if (or (< i 0)
                  (not (or (char-alphabetic? (string-ref text i))
                           (char-numeric? (string-ref text i))
                           (char=? (string-ref text i) #\_)
                           (char=? (string-ref text i) #\-)
                           (char=? (string-ref text i) #\?)
                           (char=? (string-ref text i) #\!))))
            ;; Found prefix start
            (let* ((prefix-start (+ i 1))
                   (prefix (substring text prefix-start pos)))
              (if (= (string-length prefix) 0)
                (echo-message! echo "No prefix to expand")
                (let* ((local-matches (collect-dabbrev-matches text prefix pos))
                        (other-matches (collect-dabbrev-from-other-buffers prefix local-matches))
                        (matches (append local-matches other-matches)))
                  (if (null? matches)
                    (echo-message! echo "No expansion found")
                    (let* ((first-match (car matches))
                           (expand-text (substring first-match (string-length prefix)
                                                   (string-length first-match))))
                      (editor-insert-text ed pos expand-text)
                      (editor-goto-pos ed (+ pos (string-length expand-text)))
                      (app-state-dabbrev-state-set! app
                        (list prefix (cdr matches) prefix-start
                              (string-length first-match))))))))
            (find-prefix (- i 1) (+ count 1)))))))

  ;; =========================================================================
  ;; What cursor position (C-x =)
  ;; =========================================================================

  (define (cmd-what-cursor-position app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      (if (>= pos len)
        (echo-message! (app-state-echo app) "End of buffer")
        (let* ((ch (string-ref text pos))
               (code (char->integer ch))
               (line (+ 1 (editor-line-from-position ed pos)))
               (col (+ 1 (editor-get-column ed pos)))
               (pct (if (= len 0) 0 (quotient (* pos 100) len))))
          (echo-message! (app-state-echo app)
            (string-append "Char: " (string ch)
                           " (" (number->string code) ", #x"
                           (number->string code 16) ")"
                           "  point=" (number->string pos)
                           " of " (number->string len)
                           " (" (number->string pct) "%)"
                           "  line " (number->string line)
                           " col " (number->string col)))))))

  ;; =========================================================================
  ;; Keyboard macros
  ;; =========================================================================

  (define (cmd-start-kbd-macro app)
    (if (app-state-macro-recording app)
      (echo-error! (app-state-echo app) "Already recording")
      (begin
        (app-state-macro-recording-set! app '())
        (echo-message! (app-state-echo app) "Defining kbd macro..."))))

  (define (cmd-end-kbd-macro app)
    (if (not (app-state-macro-recording app))
      (echo-error! (app-state-echo app) "Not recording")
      (begin
        (app-state-macro-last-set! app
          (reverse (app-state-macro-recording app)))
        (app-state-macro-recording-set! app #f)
        (echo-message! (app-state-echo app)
          (string-append "Macro defined ("
                         (number->string (length (app-state-macro-last app)))
                         " steps)")))))

  (define (cmd-call-last-kbd-macro app)
    (let ((macro (app-state-macro-last app)))
      (if (or (not macro) (null? macro))
        (echo-error! (app-state-echo app) "No macro defined")
        (begin
          (for-each
            (lambda (step)
              (let ((action (car step))
                    (data (cdr step)))
                (case action
                  ((command) (execute-command! app data))
                  ;; self-insert: insert the character code
                  ((self-insert)
                   (let ((ch-str (string (integer->char data))))
                     (editor-insert-text (current-editor app)
                       (editor-get-current-pos (current-editor app)) ch-str))))))
            macro)
          (echo-message! (app-state-echo app) "Macro executed")))))

  (define (macro-record-step! app action data)
    (when (app-state-macro-recording app)
      (let ((step (cons action data)))
        (app-state-macro-recording-set! app
          (cons step (app-state-macro-recording app))))))

  (define (cmd-name-last-kbd-macro app)
    (let ((macro (app-state-macro-last app)))
      (if (or (not macro) (null? macro))
        (echo-error! (app-state-echo app) "No macro defined")
        (let* ((echo (app-state-echo app))
               (frame (app-state-frame app))
               (row (- (frame-height frame) 1))
               (width (frame-width frame))
               (name (echo-read-string echo "Name for macro: " row width)))
          (when (and name (> (string-length name) 0))
            (hash-put! (app-state-macro-named app) name macro)
            (echo-message! echo (string-append "Macro saved as '" name "'")))))))

  (define (cmd-call-named-kbd-macro app)
    (let* ((named (app-state-macro-named app))
           (names (map car (hash->list named))))
      (if (null? names)
        (echo-error! (app-state-echo app) "No named macros")
        (let* ((echo (app-state-echo app))
               (frame (app-state-frame app))
               (row (- (frame-height frame) 1))
               (width (frame-width frame))
               (name (echo-read-string echo "Macro name: " row width)))
          (when (and name (> (string-length name) 0))
            (let ((macro (hash-get named name)))
              (if macro
                (begin
                  (for-each
                    (lambda (step)
                      (case (car step)
                        ((command) (execute-command! app (cdr step)))
                        ((self-insert)
                         (let ((ch-str (string (integer->char (cdr step)))))
                           (editor-insert-text (current-editor app)
                             (editor-get-current-pos (current-editor app)) ch-str)))))
                    macro)
                  (echo-message! echo (string-append "Macro '" name "' executed")))
                (echo-error! echo (string-append "No macro named '" name "'")))))))))

  (define (cmd-list-kbd-macros app)
    (let* ((named (app-state-macro-named app))
           (names (list-sort string<? (map car (hash->list named)))))
      (if (null? names)
        (echo-message! (app-state-echo app) "No named macros")
        (echo-message! (app-state-echo app)
          (string-append "Macros: " (string-join names ", "))))))

  (define (cmd-save-kbd-macros app)
    (let ((named (app-state-macro-named app)))
      (if (= (hash-length named) 0)
        (echo-message! (app-state-echo app) "No macros to save")
        (guard (e (#t (echo-error! (app-state-echo app) "Error saving macros")))
          (call-with-output-file "~/.gemacs-macros"
            (lambda (port)
              (for-each
                (lambda (pair)
                  (write (cons (car pair) (cdr pair)) port)
                  (newline port))
                (hash->list named))))
          (echo-message! (app-state-echo app)
            (string-append "Saved " (number->string (hash-length named)) " macros"))))))

  (define (cmd-load-kbd-macros app)
    (guard (e (#t (echo-message! (app-state-echo app) "No saved macros found")))
      (let ((named (app-state-macro-named app)))
        (call-with-input-file "~/.gemacs-macros"
          (lambda (port)
            (let loop ()
              (let ((datum (read port)))
                (when (not (eof-object? datum))
                  (when (pair? datum)
                    (hash-put! named (car datum) (cdr datum)))
                  (loop))))))
        (echo-message! (app-state-echo app)
          (string-append "Loaded " (number->string (hash-length named)) " macros")))))

  ;; =========================================================================
  ;; Mark ring
  ;; =========================================================================

  (define (cmd-pop-mark app)
    (let ((ring (app-state-mark-ring app)))
      (if (null? ring)
        (echo-error! (app-state-echo app) "Mark ring empty")
        (let* ((entry (car ring))
               (buf-name (car entry))
               (pos (cdr entry))
               (buf (buffer-by-name buf-name))
               (fr (app-state-frame app)))
          (app-state-mark-ring-set! app (cdr ring))
          (if buf
            (let ((ed (current-editor app)))
              (buffer-attach! ed buf)
              (edit-window-buffer-set! (current-window fr) buf)
              (editor-goto-pos ed pos)
              (editor-scroll-caret ed)
              (echo-message! (app-state-echo app) "Mark popped"))
            (echo-error! (app-state-echo app)
              (string-append "Buffer gone: " buf-name)))))))

  ;; =========================================================================
  ;; Registers
  ;; =========================================================================

  (define (cmd-copy-to-register app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Copy to register: " row width)))
      (when (and input (> (string-length input) 0))
        (let* ((reg-char (string-ref input 0))
               (ed (current-editor app))
               (buf (current-buffer-from-app app))
               (mark (buffer-mark buf)))
          (if (not mark)
            (echo-error! echo "No mark set")
            (let* ((pos (editor-get-current-pos ed))
                   (start (min pos mark))
                   (end (max pos mark))
                   (text (substring (editor-get-text ed) start end)))
              (hash-put! (app-state-registers app) reg-char text)
              (echo-message! echo
                (string-append "Copied to register " (string reg-char)))))))))

  (define (find-buffer-by-file-path filepath)
    (let loop ((bufs (buffer-list)))
      (cond
        ((null? bufs) #f)
        ((let ((fp (buffer-file-path (car bufs))))
           (and fp (string=? fp filepath)))
         (car bufs))
        (else (loop (cdr bufs))))))

  (define (jump-to-register-file! app echo fr filepath pos)
    (let* ((ed (current-editor app))
           (existing-buf (find-buffer-by-file-path filepath)))
      (if existing-buf
        ;; Buffer already open -- switch to it
        (begin
          (buffer-attach! ed existing-buf)
          (edit-window-buffer-set! (current-window fr) existing-buf)
          (editor-goto-pos ed pos)
          (editor-scroll-caret ed)
          (echo-message! echo "Jumped to register"))
        ;; Not open -- open the file directly
        (if (file-exists? filepath)
          (let* ((name (uniquify-buffer-name filepath))
                 (buf (buffer-create! name ed filepath))
                 (content (guard (e (#t #f))
                            (read-file-as-string filepath))))
            (buffer-attach! ed buf)
            (edit-window-buffer-set! (current-window fr) buf)
            (when content
              (editor-set-text ed content))
            (editor-goto-pos ed pos)
            (editor-scroll-caret ed)
            (editor-set-save-point ed)
            ;; Set up highlighting
            (let ((lang (detect-file-language filepath)))
              (when lang
                (setup-highlighting-for-file! ed filepath)
                (send-message ed SCI_SETMARGINTYPEN 0 SC_MARGIN_NUMBER)
                (send-message ed SCI_SETMARGINWIDTHN 0 4)))
            (echo-message! echo
              (string-append "Opened and jumped to " filepath)))
          (echo-error! echo
            (string-append "File not found: " filepath))))))

  (define (cmd-insert-register app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Insert register: " row width)))
      (when (and input (> (string-length input) 0))
        (let* ((reg-char (string-ref input 0))
               (val (hash-get (app-state-registers app) reg-char)))
          (cond
            ((not val)
             (echo-error! echo
               (string-append "Register " (string reg-char) " is empty")))
            ((string? val)
             (let* ((ed (current-editor app))
                    (pos (editor-get-current-pos ed)))
               (editor-insert-text ed pos val)
               (echo-message! echo
                 (string-append "Inserted from register " (string reg-char)))))
            ;; File+position register -- jump to file
            ((and (pair? val) (eq? (car val) 'file) (pair? (cdr val)))
             (let ((filepath (cadr val))
                   (pos (cddr val)))
               (jump-to-register-file! app echo fr filepath pos)))
            ;; Buffer+position register -- jump instead
            ((pair? val)
             (let* ((buf-name (car val))
                    (reg-pos (cdr val))
                    (buf (buffer-by-name buf-name))
                    (fr (app-state-frame app)))
               (if buf
                 (let ((ed (current-editor app)))
                   (buffer-attach! ed buf)
                   (edit-window-buffer-set! (current-window fr) buf)
                   (editor-goto-pos ed reg-pos)
                   (editor-scroll-caret ed)
                   (echo-message! echo "Jumped to register"))
                 (echo-error! echo
                   (string-append "Buffer gone: " buf-name))))))))))

  (define (cmd-point-to-register app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Point to register: " row width)))
      (when (and input (> (string-length input) 0))
        (let* ((reg-char (string-ref input 0))
               (ed (current-editor app))
               (buf (current-buffer-from-app app))
               (pos (editor-get-current-pos ed))
               (mark (buffer-mark buf)))
          (if mark
            ;; Region active: save text
            (let* ((start (min pos mark))
                   (end (max pos mark))
                   (text (substring (editor-get-text ed) start end)))
              (hash-put! (app-state-registers app) reg-char text)
              (echo-message! echo
                (string-append "Region saved to register " (string reg-char))))
            ;; No region: save file-path + position (or buffer-name + position)
            (let ((fp (buffer-file-path buf)))
              (if fp
                ;; File-visiting buffer: save (file . (path . pos))
                (begin
                  (hash-put! (app-state-registers app) reg-char
                             (cons 'file (cons fp pos)))
                  (echo-message! echo
                    (string-append "File position saved to register " (string reg-char))))
                ;; Non-file buffer: save (buffer-name . pos)
                (begin
                  (hash-put! (app-state-registers app) reg-char
                             (cons (buffer-name buf) pos))
                  (echo-message! echo
                    (string-append "Position saved to register " (string reg-char)))))))))))

  (define (cmd-jump-to-register app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Jump to register: " row width)))
      (when (and input (> (string-length input) 0))
        (let* ((reg-char (string-ref input 0))
               (val (hash-get (app-state-registers app) reg-char)))
          (cond
            ((not val)
             (echo-error! echo
               (string-append "Register " (string reg-char) " is empty")))
            ;; File+position register: (file . (path . pos))
            ((and (pair? val) (eq? (car val) 'file) (pair? (cdr val)))
             (let ((filepath (cadr val))
                   (pos (cddr val)))
               (jump-to-register-file! app echo fr filepath pos)))
            ;; Buffer+position register: (buffer-name . pos)
            ((pair? val)
             (let* ((buf-name (car val))
                    (pos (cdr val))
                    (buf (buffer-by-name buf-name)))
               (if buf
                 (let ((ed (current-editor app)))
                   (buffer-attach! ed buf)
                   (edit-window-buffer-set! (current-window fr) buf)
                   (editor-goto-pos ed pos)
                   (editor-scroll-caret ed)
                   (echo-message! echo "Jumped to register"))
                 (echo-error! echo
                   (string-append "Buffer gone: " buf-name)))))
            ((string? val)
             ;; Text register -- insert it
             (let* ((ed (current-editor app))
                    (pos (editor-get-current-pos ed)))
               (editor-insert-text ed pos val)
               (echo-message! echo
                 (string-append "Inserted from register " (string reg-char))))))))))

  ;; =========================================================================
  ;; Backward kill word, zap to char, goto char
  ;; =========================================================================

  (define (cmd-backward-kill-word app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed)))
      (when (> pos 0)
        ;; Skip whitespace/non-word chars backward
        (let skip-space ((i (- pos 1)))
          (if (and (>= i 0) (not (word-char? (string-ref text i))))
            (skip-space (- i 1))
            ;; Now skip word chars backward
            (let skip-word ((j i))
              (if (and (>= j 0) (word-char? (string-ref text j)))
                (skip-word (- j 1))
                ;; j+1 is the start of the word
                (let* ((start (+ j 1))
                       (killed (substring text start pos)))
                  (when (> (string-length killed) 0)
                    (app-state-kill-ring-set! app
                      (cons killed (app-state-kill-ring app)))
                    (send-message ed SCI_DELETERANGE start (- pos start)))))))))))

  (define (cmd-zap-to-char app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Zap to char: " row width)))
      (when (and input (> (string-length input) 0))
        (let* ((target-char (string-ref input 0))
               (ed (current-editor app))
               (pos (editor-get-current-pos ed))
               (len (editor-get-text-length ed))
               ;; Search forward for the character
               (found-pos
                 (let loop ((i pos))
                   (cond
                     ((>= i len) #f)
                     ((let ((ch (send-message ed SCI_GETCHARAT i 0)))
                        (= ch (char->integer target-char)))
                      (+ i 1))  ; inclusive of the target char
                     (else (loop (+ i 1)))))))
          (if found-pos
            (let ((text (substring (editor-get-text ed) pos found-pos)))
              ;; Add to kill ring
              (app-state-kill-ring-set! app
                (cons text (app-state-kill-ring app)))
              ;; Delete the text
              (send-message ed SCI_DELETERANGE pos (- found-pos pos)))
            (echo-error! echo
              (string-append "Character '" (string target-char) "' not found")))))))

  (define (cmd-goto-char app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (input (echo-read-string echo "Goto char: " row width)))
      (when input
        (let ((n (string->number input)))
          (if n
            (let ((ed (current-editor app)))
              (editor-goto-pos ed (max 0 (inexact->exact (floor n))))
              (editor-scroll-caret ed))
            (echo-error! echo "Invalid position"))))))

  ;; =========================================================================
  ;; Replace string (non-interactive)
  ;; =========================================================================

  (define (cmd-replace-string app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (from-str (echo-read-string echo "Replace string: " row width)))
      (when (and from-str (> (string-length from-str) 0))
        (let ((to-str (echo-read-string echo
                        (string-append "Replace \"" from-str "\" with: ")
                        row width)))
          (when to-str
            (let* ((ed (current-editor app))
                   (count 0))
              (send-message ed SCI_BEGINUNDOACTION)
              ;; Search from beginning
              (send-message ed SCI_SETTARGETSTART 0 0)
              (send-message ed SCI_SETTARGETEND (editor-get-text-length ed) 0)
              (send-message ed SCI_SETSEARCHFLAGS 0 0)
              (let loop ()
                (let ((found (send-message/string ed SCI_SEARCHINTARGET from-str)))
                  (when (>= found 0)
                    (send-message/string ed SCI_REPLACETARGET to-str)
                    (set! count (+ count 1))
                    ;; Set target for next search
                    (let ((new-start (+ found (string-length to-str))))
                      (send-message ed SCI_SETTARGETSTART new-start 0)
                      (send-message ed SCI_SETTARGETEND (editor-get-text-length ed) 0)
                      (loop)))))
              (send-message ed SCI_ENDUNDOACTION)
              (echo-message! echo
                (string-append "Replaced " (number->string count)
                               " occurrences"))))))))

  ;; =========================================================================
  ;; Transpose words and lines
  ;; =========================================================================

  (define (cmd-transpose-words app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (len (string-length text)))
      ;; Find end of current word
      (let find-word2-end ((i pos))
        (if (and (< i len) (word-char? (string-ref text i)))
          (find-word2-end (+ i 1))
          ;; i is end of word2; find start of word2
          (let find-word2-start ((j (- i 1)))
            (if (and (>= j 0) (word-char? (string-ref text j)))
              (find-word2-start (- j 1))
              ;; j+1 is start of word2
              (let ((w2-start (+ j 1))
                    (w2-end i))
                ;; Find end of word1 (skip non-word chars backward from w2-start)
                (let find-word1-end ((k (- w2-start 1)))
                  (if (and (>= k 0) (not (word-char? (string-ref text k))))
                    (find-word1-end (- k 1))
                    ;; k is last char of word1
                    (when (>= k 0)
                      (let find-word1-start ((m k))
                        (if (and (>= m 0) (word-char? (string-ref text m)))
                          (find-word1-start (- m 1))
                          ;; m+1 is start of word1
                          (let* ((w1-start (+ m 1))
                                 (w1-end (+ k 1))
                                 (word1 (substring text w1-start w1-end))
                                 (word2 (substring text w2-start w2-end))
                                 (between (substring text w1-end w2-start))
                                 (new-text (string-append word2 between word1)))
                            (send-message ed SCI_BEGINUNDOACTION)
                            (send-message ed SCI_DELETERANGE w1-start (- w2-end w1-start))
                            (editor-insert-text ed w1-start new-text)
                            (editor-goto-pos ed w2-end)
                            (send-message ed SCI_ENDUNDOACTION))))))))))))))

  (define (cmd-transpose-lines app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (cur-line (editor-line-from-position ed pos)))
      (when (> cur-line 0)
        (let* ((text (editor-get-text ed))
               (cur-start (send-message ed SCI_POSITIONFROMLINE cur-line 0))
               (cur-end (send-message ed SCI_GETLINEENDPOSITION cur-line 0))
               (prev-start (send-message ed SCI_POSITIONFROMLINE (- cur-line 1) 0))
               (prev-end (send-message ed SCI_GETLINEENDPOSITION (- cur-line 1) 0))
               (cur-text (substring text cur-start cur-end))
               (prev-text (substring text prev-start prev-end)))
          (send-message ed SCI_BEGINUNDOACTION)
          ;; Replace current line with previous, and previous with current
          (send-message ed SCI_DELETERANGE prev-start (- cur-end prev-start))
          (let ((new-text (string-append cur-text "\n" prev-text)))
            (editor-insert-text ed prev-start new-text))
          ;; Move cursor to end of what was the current line
          (editor-goto-pos ed (+ prev-start (string-length cur-text) 1
                                 (string-length prev-text)))
          (send-message ed SCI_ENDUNDOACTION)))))

  ;; =========================================================================
  ;; Just one space, repeat command
  ;; =========================================================================

  (define (cmd-just-one-space app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (len (string-length text)))
      ;; Find extent of whitespace around point
      (let* ((start (let back ((i (- pos 1)))
                      (if (and (>= i 0)
                               (let ((ch (string-ref text i)))
                                 (or (char=? ch #\space) (char=? ch #\tab))))
                        (back (- i 1))
                        (+ i 1))))
             (end (let fwd ((i pos))
                    (if (and (< i len)
                             (let ((ch (string-ref text i)))
                               (or (char=? ch #\space) (char=? ch #\tab))))
                      (fwd (+ i 1))
                      i))))
        (when (> (- end start) 1)
          (send-message ed SCI_BEGINUNDOACTION)
          (send-message ed SCI_DELETERANGE start (- end start))
          (editor-insert-text ed start " ")
          (editor-goto-pos ed (+ start 1))
          (send-message ed SCI_ENDUNDOACTION)))))

  (define (cmd-repeat app)
    (let* ((last (app-state-last-command app))
           (count (abs (get-prefix-arg app))))
      (cond
       ((or (not last) (eq? last 'repeat))
        (echo-error! (app-state-echo app) "No command to repeat"))
       ((= count 0)
        (echo-error! (app-state-echo app) "Repeat count must be positive"))
       (else
        (let loop ((i 0))
          (when (< i count)
            (execute-command! app last)
            (loop (+ i 1))))))))

  ;; =========================================================================
  ;; Next/previous error (navigate search results)
  ;; =========================================================================

  (define (cmd-next-error app)
    (let* ((ed (current-editor app))
           (search (app-state-last-search app)))
      (if (not search)
        (echo-error! (app-state-echo app) "No previous search")
        (let* ((pos (editor-get-current-pos ed))
               (len (editor-get-text-length ed)))
          ;; Search forward from current position
          (send-message ed SCI_SETTARGETSTART (+ pos 1) 0)
          (send-message ed SCI_SETTARGETEND len 0)
          (send-message ed SCI_SETSEARCHFLAGS 0 0)
          (let ((found (send-message/string ed SCI_SEARCHINTARGET search)))
            (if (>= found 0)
              (begin
                (editor-goto-pos ed found)
                (editor-scroll-caret ed))
              ;; Wrap around
              (begin
                (send-message ed SCI_SETTARGETSTART 0 0)
                (send-message ed SCI_SETTARGETEND pos 0)
                (let ((found2 (send-message/string ed SCI_SEARCHINTARGET search)))
                  (if (>= found2 0)
                    (begin
                      (editor-goto-pos ed found2)
                      (editor-scroll-caret ed)
                      (echo-message! (app-state-echo app) "Wrapped"))
                    (echo-error! (app-state-echo app) "No more matches"))))))))))

  (define (cmd-previous-error app)
    (let* ((ed (current-editor app))
           (search (app-state-last-search app)))
      (if (not search)
        (echo-error! (app-state-echo app) "No previous search")
        (let* ((pos (editor-get-current-pos ed))
               (len (editor-get-text-length ed)))
          ;; Search backward: set target from pos-1 back to 0
          (send-message ed SCI_SETTARGETSTART (max 0 (- pos 1)) 0)
          (send-message ed SCI_SETTARGETEND 0 0)
          (send-message ed SCI_SETSEARCHFLAGS 0 0)
          (let ((found (send-message/string ed SCI_SEARCHINTARGET search)))
            (if (>= found 0)
              (begin
                (editor-goto-pos ed found)
                (editor-scroll-caret ed))
              ;; Wrap around from end
              (begin
                (send-message ed SCI_SETTARGETSTART len 0)
                (send-message ed SCI_SETTARGETEND pos 0)
                (let ((found2 (send-message/string ed SCI_SEARCHINTARGET search)))
                  (if (>= found2 0)
                    (begin
                      (editor-goto-pos ed found2)
                      (editor-scroll-caret ed)
                      (echo-message! (app-state-echo app) "Wrapped"))
                    (echo-error! (app-state-echo app) "No more matches"))))))))))

  ;; =========================================================================
  ;; Kill whole line, move line up/down
  ;; =========================================================================

  (define (cmd-kill-whole-line app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (send-message ed SCI_POSITIONFROMLINE line 0))
           (next-line-start (send-message ed SCI_POSITIONFROMLINE (+ line 1) 0))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; If last line (no next line), delete to end including preceding newline
      (if (= next-line-start 0)
        (let* ((del-start (if (and (> line-start 0)
                                   (char=? (string-ref text (- line-start 1)) #\newline))
                            (- line-start 1) line-start))
               (killed (substring text del-start len)))
          (app-state-kill-ring-set! app
            (cons killed (app-state-kill-ring app)))
          (send-message ed SCI_DELETERANGE del-start (- len del-start)))
        ;; Normal case: delete from line-start to next-line-start
        (let ((killed (substring text line-start next-line-start)))
          (app-state-kill-ring-set! app
            (cons killed (app-state-kill-ring app)))
          (send-message ed SCI_DELETERANGE line-start (- next-line-start line-start))))))

  (define (cmd-move-line-up app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (cur-line (editor-line-from-position ed pos)))
      (when (> cur-line 0)
        (let* ((text (editor-get-text ed))
               (cur-start (send-message ed SCI_POSITIONFROMLINE cur-line 0))
               (cur-end (send-message ed SCI_GETLINEENDPOSITION cur-line 0))
               (prev-start (send-message ed SCI_POSITIONFROMLINE (- cur-line 1) 0))
               (prev-end (send-message ed SCI_GETLINEENDPOSITION (- cur-line 1) 0))
               (cur-text (substring text cur-start cur-end))
               (prev-text (substring text prev-start prev-end))
               (col (- pos cur-start)))
          (send-message ed SCI_BEGINUNDOACTION)
          (send-message ed SCI_DELETERANGE prev-start (- cur-end prev-start))
          (editor-insert-text ed prev-start (string-append cur-text "\n" prev-text))
          ;; Put cursor on same column in moved line
          (editor-goto-pos ed (+ prev-start (min col (string-length cur-text))))
          (send-message ed SCI_ENDUNDOACTION)))))

  (define (cmd-move-line-down app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (cur-line (editor-line-from-position ed pos))
           (line-count (editor-get-line-count ed)))
      (when (< cur-line (- line-count 1))
        (let* ((text (editor-get-text ed))
               (cur-start (send-message ed SCI_POSITIONFROMLINE cur-line 0))
               (cur-end (send-message ed SCI_GETLINEENDPOSITION cur-line 0))
               (next-start (send-message ed SCI_POSITIONFROMLINE (+ cur-line 1) 0))
               (next-end (send-message ed SCI_GETLINEENDPOSITION (+ cur-line 1) 0))
               (cur-text (substring text cur-start cur-end))
               (next-text (substring text next-start next-end))
               (col (- pos cur-start)))
          (send-message ed SCI_BEGINUNDOACTION)
          (send-message ed SCI_DELETERANGE cur-start (- next-end cur-start))
          (editor-insert-text ed cur-start (string-append next-text "\n" cur-text))
          ;; Put cursor on same column in moved line (now on line below)
          (let ((new-line-start (+ cur-start (string-length next-text) 1)))
            (editor-goto-pos ed (+ new-line-start (min col (string-length cur-text)))))
          (send-message ed SCI_ENDUNDOACTION)))))

  ;; =========================================================================
  ;; Pipe buffer to shell, narrow/widen
  ;; =========================================================================

  (define (cmd-pipe-buffer app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (cmd (echo-read-string echo "Pipe buffer to: " row width)))
      (when (and cmd (> (string-length cmd) 0))
        (let* ((ed (current-editor app))
               (text (editor-get-text ed)))
          (guard (e (#t
                     (echo-error! echo (string-append "Error: "
                                          (call-with-string-output-port
                                            (lambda (p) (display e p)))))))
            (let-values (((to-stdin from-stdout from-stderr pid)
                          (open-process-ports
                            (string-append "/bin/sh -c " (shell-quote cmd))
                            (buffer-mode block)
                            (native-transcoder))))
              (display text to-stdin)
              (close-output-port to-stdin)
              (let ((output (get-string-all from-stdout)))
                (close-input-port from-stdout)
                (close-input-port from-stderr)
                ;; Show output in a new buffer
                (if (and (string? output) (> (string-length output) 0))
                  (let* ((buf-name "*Shell Output*")
                         (existing (buffer-by-name buf-name)))
                    (when existing
                      (buffer-list-remove! existing))
                    (let ((buf (buffer-create! buf-name ed #f)))
                      (buffer-attach! ed buf)
                      (edit-window-buffer-set! (current-window fr) buf)
                      (editor-set-text ed output)
                      (editor-goto-pos ed 0)
                      (echo-message! echo "Pipe complete")))
                  (echo-message! echo "No output")))))))))

  (define (cmd-narrow-to-region app)
    (let* ((ed (current-editor app))
           (fr (app-state-frame app))
           (buf (edit-window-buffer (current-window fr)))
           (mark (buffer-mark buf)))
      (if mark
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (text (editor-get-text ed))
               (region (substring text start end)))
          ;; Save full text and narrow bounds
          (hash-put! *tui-narrow-state* buf (list text start end))
          ;; Replace buffer text with region only
          (editor-set-text ed region)
          (editor-goto-pos ed 0)
          (editor-set-save-point ed)
          (buffer-mark-set! buf #f)
          (echo-message! (app-state-echo app) "Narrowed"))
        (echo-error! (app-state-echo app) "No mark set"))))

  (define (cmd-widen app)
    (let* ((fr (app-state-frame app))
           (buf (edit-window-buffer (current-window fr)))
           (state (hash-get *tui-narrow-state* buf)))
      (if state
        (let* ((ed (current-editor app))
               (full-text (car state))
               (start (cadr state))
               (end (caddr state))
               (narrow-text (editor-get-text ed))
               (new-text (string-append
                           (substring full-text 0 start)
                           narrow-text
                           (substring full-text end (string-length full-text)))))
          (editor-set-text ed new-text)
          (editor-goto-pos ed start)
          (editor-set-save-point ed)
          (hash-remove! *tui-narrow-state* buf)
          (echo-message! (app-state-echo app) "Widened"))
        (echo-error! (app-state-echo app) "Buffer is not narrowed"))))

  ;; =========================================================================
  ;; String rectangle, open rectangle
  ;; =========================================================================

  (define (cmd-string-rectangle app)
    (let ((echo (app-state-echo app)))
      (let-values (((start-line start-col end-line end-col) (get-region-lines app)))
        (if (not start-line)
          (echo-error! echo "No region (set mark first)")
          (let* ((fr (app-state-frame app))
                 (row (- (frame-height fr) 1))
                 (width (frame-width fr))
                 (str (echo-read-string echo "String rectangle: " row width)))
            (if (not str)
              (echo-message! echo "Cancelled")
              (let* ((ed (current-editor app))
                     (left-col (min start-col end-col))
                     (right-col (max start-col end-col)))
                (with-undo-action ed
                  ;; Process lines from bottom to top to preserve positions
                  (let loop ((line end-line))
                    (when (>= line start-line)
                      (let* ((line-start (editor-position-from-line ed line))
                             (line-text (editor-get-line ed line))
                             (line-len (string-length (string-trim-right-char line-text #\newline)))
                             (l (min left-col line-len))
                             (r (min right-col line-len)))
                        ;; Delete old rectangle portion and insert replacement
                        (when (< l r)
                          (editor-delete-range ed (+ line-start l) (- r l)))
                        (editor-insert-text ed (+ line-start l) str))
                      (loop (- line 1)))))
                (buffer-mark-set! (current-buffer-from-app app) #f)
                (echo-message! echo "String rectangle done"))))))))

  (define (cmd-open-rectangle app)
    (let ((echo (app-state-echo app)))
      (let-values (((start-line start-col end-line end-col) (get-region-lines app)))
        (if (not start-line)
          (echo-error! echo "No region (set mark first)")
          (let* ((ed (current-editor app))
                 (left-col (min start-col end-col))
                 (right-col (max start-col end-col))
                 (width (- right-col left-col)))
            (when (> width 0)
              (with-undo-action ed
                ;; Insert spaces from bottom to top
                (let loop ((line end-line))
                  (when (>= line start-line)
                    (let* ((line-start (editor-position-from-line ed line))
                           (line-text (editor-get-line ed line))
                           (line-len (string-length (string-trim-right-char line-text #\newline)))
                           (insert-pos (+ line-start (min left-col line-len))))
                      ;; Pad if line is shorter than left-col
                      (when (< line-len left-col)
                        (editor-insert-text ed (+ line-start line-len)
                          (make-string (- left-col line-len) #\space)))
                      (editor-insert-text ed (+ line-start (min left-col line-len))
                        (make-string width #\space)))
                    (loop (- line 1))))))
            (buffer-mark-set! (current-buffer-from-app app) #f)
            (echo-message! echo
              (string-append "Opened rectangle (" (number->string width) " cols)")))))))

  ;; =========================================================================
  ;; Number lines, reverse region
  ;; =========================================================================

  (define (cmd-number-lines app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if mark
        ;; Region
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (start-line (editor-line-from-position ed start))
               (end-line (editor-line-from-position ed end))
               (num-lines (+ (- end-line start-line) 1))
               (width (string-length (number->string num-lines))))
          (with-undo-action ed
            ;; Insert from bottom to top to preserve positions
            (let loop ((line end-line) (n num-lines))
              (when (>= line start-line)
                (let* ((line-start (editor-position-from-line ed line))
                       (prefix (string-append
                                 (let ((s (number->string n)))
                                   (string-append
                                     (make-string (- width (string-length s)) #\space)
                                     s))
                                 ": ")))
                  (editor-insert-text ed line-start prefix))
                (loop (- line 1) (- n 1)))))
          (buffer-mark-set! buf #f)
          (echo-message! echo
            (string-append "Numbered " (number->string num-lines) " lines")))
        ;; Whole buffer
        (let* ((total (editor-get-line-count ed))
               (width (string-length (number->string total))))
          (with-undo-action ed
            (let loop ((line (- total 1)) (n total))
              (when (>= line 0)
                (let* ((line-start (editor-position-from-line ed line))
                       (prefix (string-append
                                 (let ((s (number->string n)))
                                   (string-append
                                     (make-string (- width (string-length s)) #\space)
                                     s))
                                 ": ")))
                  (editor-insert-text ed line-start prefix))
                (loop (- line 1) (- n 1)))))
          (echo-message! echo
            (string-append "Numbered " (number->string total) " lines"))))))

  (define (cmd-reverse-region app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (buf (current-buffer-from-app app))
           (mark (buffer-mark buf)))
      (if mark
        ;; Region
        (let* ((pos (editor-get-current-pos ed))
               (start (min mark pos))
               (end (max mark pos))
               (region (substring (editor-get-text ed) start end))
               (lines (string-split region #\newline))
               (reversed (reverse lines))
               (result (string-join reversed "\n")))
          (with-undo-action ed
            (editor-delete-range ed start (- end start))
            (editor-insert-text ed start result))
          (buffer-mark-set! buf #f)
          (echo-message! echo
            (string-append "Reversed " (number->string (length reversed)) " lines")))
        ;; Whole buffer
        (let* ((text (editor-get-text ed))
               (lines (string-split text #\newline))
               (reversed (reverse lines))
               (result (string-join reversed "\n"))
               (pos (editor-get-current-pos ed)))
          (editor-set-text ed result)
          (editor-goto-pos ed (min pos (editor-get-text-length ed)))
          (echo-message! echo
            (string-append "Reversed " (number->string (length reversed)) " lines"))))))

  ;; =========================================================================
  ;; Flush lines, keep lines
  ;; =========================================================================

  (define (cmd-flush-lines app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (pattern (echo-read-string echo "Flush lines matching: " row width)))
      (if (not pattern)
        (echo-message! echo "Cancelled")
        (let* ((ed (current-editor app))
               (text (editor-get-text ed))
               (lines (string-split text #\newline))
               (original-count (length lines))
               (kept (filter (lambda (line) (not (string-contains line pattern))) lines))
               (removed (- original-count (length kept)))
               (result (string-join kept "\n"))
               (pos (editor-get-current-pos ed)))
          (editor-set-text ed result)
          (editor-goto-pos ed (min pos (editor-get-text-length ed)))
          (echo-message! echo
            (string-append "Flushed " (number->string removed) " lines"))))))

  (define (cmd-keep-lines app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (pattern (echo-read-string echo "Keep lines matching: " row width)))
      (if (not pattern)
        (echo-message! echo "Cancelled")
        (let* ((ed (current-editor app))
               (text (editor-get-text ed))
               (lines (string-split text #\newline))
               (original-count (length lines))
               (kept (filter (lambda (line) (string-contains line pattern)) lines))
               (removed (- original-count (length kept)))
               (result (string-join kept "\n"))
               (pos (editor-get-current-pos ed)))
          (editor-set-text ed result)
          (editor-goto-pos ed (min pos (editor-get-text-length ed)))
          (echo-message! echo
            (string-append "Kept " (number->string (length kept))
                           " lines, removed " (number->string removed)))))))

  ;; =========================================================================
  ;; Align regexp
  ;; =========================================================================

  (define (cmd-align-regexp app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (pattern (echo-read-string echo "Align on: " row width)))
      (if (not pattern)
        (echo-message! echo "Cancelled")
        (let* ((ed (current-editor app))
               (buf (current-buffer-from-app app))
               (mark (buffer-mark buf))
               (pos (editor-get-current-pos ed))
               (text (editor-get-text ed)))
          ;; Determine range
          (let-values (((start end)
                        (if mark
                          (values (min mark pos) (max mark pos))
                          (values 0 (string-length text)))))
            (let* ((region (substring text start end))
                   (lines (string-split region #\newline))
                   ;; Find max column position of the pattern
                   (positions (map (lambda (line)
                                    (let ((idx (string-contains line pattern)))
                                      (or idx -1)))
                                  lines))
                   (max-col (apply max (cons 0 (filter (lambda (x) (>= x 0)) positions)))))
              (if (= max-col 0)
                (echo-error! echo (string-append "Pattern not found: " pattern))
                (let* ((aligned
                         (map (lambda (line)
                                (let ((idx (string-contains line pattern)))
                                  (if idx
                                    (string-append
                                      (substring line 0 idx)
                                      (make-string (- max-col idx) #\space)
                                      (substring line idx (string-length line)))
                                    line)))
                              lines))
                       (result (string-join aligned "\n")))
                  (with-undo-action ed
                    (editor-delete-range ed start (- end start))
                    (editor-insert-text ed start result))
                  (when mark (buffer-mark-set! buf #f))
                  (echo-message! echo "Aligned")))))))))

  ;; =========================================================================
  ;; Sort fields
  ;; =========================================================================

  (define (cmd-sort-fields app)
    (let* ((echo (app-state-echo app))
           (fr (app-state-frame app))
           (row (- (frame-height fr) 1))
           (width (frame-width fr))
           (field-str (echo-read-string echo "Sort by field #: " row width)))
      (if (not field-str)
        (echo-message! echo "Cancelled")
        (let ((field-num (string->number field-str)))
          (if (not field-num)
            (echo-error! echo "Invalid field number")
            (let* ((ed (current-editor app))
                   (buf (current-buffer-from-app app))
                   (mark (buffer-mark buf))
                   (pos (editor-get-current-pos ed))
                   (text (editor-get-text ed)))
              (let-values (((start end)
                            (if mark
                              (values (min mark pos) (max mark pos))
                              (values 0 (string-length text)))))
                (let* ((region (substring text start end))
                       (lines (string-split region #\newline))
                       (field-idx (- field-num 1))  ; 1-based to 0-based
                       (get-field
                         (lambda (line)
                           (let ((fields (string-split line #\space)))
                             ;; Filter out empty strings from split
                             (let ((fs (filter (lambda (s) (not (string=? s ""))) fields)))
                               (if (< field-idx (length fs))
                                 (list-ref fs field-idx)
                                 "")))))
                       (sorted (list-sort
                                 (lambda (a b)
                                   (string<? (get-field a) (get-field b)))
                                 lines))
                       (result (string-join sorted "\n")))
                  (with-undo-action ed
                    (editor-delete-range ed start (- end start))
                    (editor-insert-text ed start result))
                  (when mark (buffer-mark-set! buf #f))
                  (echo-message! echo
                    (string-append "Sorted by field " field-str))))))))))

  ;; =========================================================================
  ;; Mark word, mark paragraph, paragraph navigation
  ;; =========================================================================

  (define (cmd-mark-word app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Set mark at current position if not already set
      (when (not (buffer-mark buf))
        (buffer-mark-set! buf pos))
      ;; Find end of word from current pos
      (let skip-nonword ((i pos))
        (if (and (< i len) (not (word-char? (string-ref text i))))
          (skip-nonword (+ i 1))
          (let find-end ((j i))
            (if (and (< j len) (word-char? (string-ref text j)))
              (find-end (+ j 1))
              (begin
                (editor-goto-pos ed j)
                (echo-message! (app-state-echo app) "Mark word"))))))))

  (define (cmd-mark-paragraph app)
    (let* ((ed (current-editor app))
           (buf (current-buffer-from-app app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Find start of paragraph (search backward for blank line or BOF)
      (let find-start ((i pos))
        (let ((start
                (cond
                  ((<= i 0) 0)
                  ;; Check if we're at start of a blank line
                  ((and (> i 1)
                        (char=? (string-ref text (- i 1)) #\newline)
                        (or (= i (string-length text))
                            (char=? (string-ref text i) #\newline)))
                   i)
                  (else (find-start (- i 1))))))
          ;; Find end of paragraph (search forward for blank line or EOF)
          (let find-end ((j pos))
            (let ((end
                    (cond
                      ((>= j len) len)
                      ;; Blank line = two consecutive newlines
                      ((and (char=? (string-ref text j) #\newline)
                            (< (+ j 1) len)
                            (char=? (string-ref text (+ j 1)) #\newline))
                       (+ j 1))
                      (else (find-end (+ j 1))))))
              (buffer-mark-set! buf start)
              (editor-goto-pos ed end)
              (echo-message! (app-state-echo app) "Mark paragraph")))))))

  (define (cmd-forward-paragraph app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed))
           (len (string-length text)))
      ;; Skip any blank lines at point
      (let skip-blank ((i pos))
        (if (and (< i len)
                 (char=? (string-ref text i) #\newline))
          (skip-blank (+ i 1))
          ;; Now find next blank line or EOF
          (let find-end ((j i))
            (cond
              ((>= j len) (editor-goto-pos ed len))
              ((and (char=? (string-ref text j) #\newline)
                    (< (+ j 1) len)
                    (char=? (string-ref text (+ j 1)) #\newline))
               (editor-goto-pos ed (+ j 1)))
              (else (find-end (+ j 1)))))))))

  (define (cmd-backward-paragraph app)
    (let* ((ed (current-editor app))
           (text (editor-get-text ed))
           (pos (editor-get-current-pos ed)))
      ;; Skip any blank lines at point
      (let skip-blank ((i (max 0 (- pos 1))))
        (if (and (> i 0)
                 (char=? (string-ref text i) #\newline))
          (skip-blank (- i 1))
          ;; Now find previous blank line or BOF
          (let find-start ((j i))
            (cond
              ((<= j 0) (editor-goto-pos ed 0))
              ((and (char=? (string-ref text j) #\newline)
                    (> j 0)
                    (char=? (string-ref text (- j 1)) #\newline))
               (editor-goto-pos ed (+ j 1)))
              (else (find-start (- j 1)))))))))

  ;; =========================================================================
  ;; Back to indentation, delete indentation
  ;; =========================================================================

  (define (cmd-back-to-indentation app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos))
           (line-start (editor-position-from-line ed line))
           (text (editor-get-text ed))
           (len (string-length text)))
      (let find-nonws ((i line-start))
        (if (and (< i len)
                 (let ((ch (string-ref text i)))
                   (and (not (char=? ch #\newline))
                        (or (char=? ch #\space) (char=? ch #\tab)))))
          (find-nonws (+ i 1))
          (editor-goto-pos ed i)))))

  (define (cmd-delete-indentation app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (line (editor-line-from-position ed pos)))
      (when (> line 0)
        ;; Go to beginning of current line
        (let* ((line-start (editor-position-from-line ed line))
               (prev-end (editor-get-line-end-position ed (- line 1)))
               (text (editor-get-text ed))
               ;; Find end of whitespace at start of current line
               (ws-end line-start))
          (let skip ((i line-start))
            (when (< i (string-length text))
              (let ((ch (string-ref text i)))
                (when (or (char=? ch #\space) (char=? ch #\tab))
                  (set! ws-end (+ i 1))
                  (skip (+ i 1))))))
          ;; Delete from end of previous line through whitespace, insert space
          (with-undo-action ed
            (editor-delete-range ed prev-end (- ws-end prev-end))
            (editor-insert-text ed prev-end " "))))))

  ;; =========================================================================
  ;; Whitespace navigation/cleanup
  ;; =========================================================================

  (define (cmd-cycle-spacing app)
    ;; Simplified: just collapse to single space (same as just-one-space)
    (cmd-just-one-space app))

  (define (cmd-fixup-whitespace app)
    (let* ((ed (current-editor app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Find whitespace range around point
      (let find-start ((i (- pos 1)))
        (let ((ws-start
                (if (and (>= i 0)
                         (let ((ch (string-ref text i)))
                           (or (char=? ch #\space) (char=? ch #\tab))))
                  (find-start (- i 1))
                  (+ i 1))))
          (let find-end ((j pos))
            (let ((ws-end
                    (if (and (< j len)
                             (let ((ch (string-ref text j)))
                               (or (char=? ch #\space) (char=? ch #\tab))))
                      (find-end (+ j 1))
                      j)))
              (when (> (- ws-end ws-start) 1)
                (with-undo-action ed
                  (editor-delete-range ed ws-start (- ws-end ws-start))
                  (editor-insert-text ed ws-start " ")))))))))

  ;; =========================================================================
  ;; Scintilla autocomplete popup
  ;; =========================================================================

  (define (cmd-complete-at-point app)
    (let* ((ed (current-editor app))
           (echo (app-state-echo app))
           (pos (editor-get-current-pos ed))
           (text (editor-get-text ed))
           (len (string-length text)))
      ;; Find prefix at cursor
      (let* ((prefix-start
               (let loop ((i (- pos 1)))
                 (if (or (< i 0)
                         (let ((ch (string-ref text i)))
                           (not (or (char-alphabetic? ch)
                                    (char-numeric? ch)
                                    (char=? ch #\_)
                                    (char=? ch #\-)
                                    (char=? ch #\?)
                                    (char=? ch #\!)))))
                   (+ i 1) (loop (- i 1)))))
             (prefix (substring text prefix-start pos))
             (plen (string-length prefix)))
        (if (= plen 0)
          (echo-message! echo "No prefix to complete")
          ;; Collect unique word candidates from buffer
          (let ((candidates (make-hash-table)))
            (let scan ((i 0))
              (when (< i len)
                ;; Skip non-word chars
                (let skip ((j i))
                  (if (or (>= j len)
                          (let ((ch (string-ref text j)))
                            (or (char-alphabetic? ch) (char-numeric? ch)
                                (char=? ch #\_) (char=? ch #\-)
                                (char=? ch #\?) (char=? ch #\!))))
                    ;; Found word start
                    (let word-end ((k j))
                      (if (or (>= k len)
                              (let ((ch (string-ref text k)))
                                (not (or (char-alphabetic? ch) (char-numeric? ch)
                                         (char=? ch #\_) (char=? ch #\-)
                                         (char=? ch #\?) (char=? ch #\!)))))
                        (begin
                          (when (> k j)
                            (let ((word (substring text j k)))
                              (when (and (> (string-length word) plen)
                                         (string-prefix? prefix word)
                                         (not (= j prefix-start)))
                                (hash-put! candidates word #t))))
                          (scan k))
                        (word-end (+ k 1))))
                    (skip (+ j 1))))))
            ;; Show popup if candidates found
            (let ((words (list-sort string<? (hash-keys candidates))))
              (if (null? words)
                (echo-message! echo (string-append "No completions for \"" prefix "\""))
                (begin
                  ;; Configure autocomplete
                  (send-message ed SCI_AUTOCSETSEPARATOR (char->integer #\newline) 0)
                  (send-message ed SCI_AUTOCSETIGNORECASE 0 0)
                  (send-message ed SCI_AUTOCSETMAXHEIGHT 10 0)
                  (send-message ed SCI_AUTOCSETDROPRESTOFWORD 1 0)
                  ;; SC_ORDER_PERFORMSORT=2 means we provide sorted list
                  (send-message ed SCI_AUTOCSETORDER 1 0)
                  ;; Build item list separated by newlines
                  (let ((item-list (string-join words "\n")))
                    ;; Use ffi-scintilla-send-message-string for custom wparam (prefix len)
                    (ffi-scintilla-send-message-string
                      (scintilla-editor-handle ed) SCI_AUTOCSHOW plen item-list))
                  (echo-message! echo
                    (string-append (number->string (length words)) " completions"))))))))))

  ;; =========================================================================
  ;; Calltip display (diagnostic tooltips, hover info)
  ;; =========================================================================

  (define (show-calltip! ed pos text . opts)
    (let ((bg (if (and (pair? opts) (pair? (cdr opts)))
                (cadr opts)
                #f))
          (fg (if (and (pair? opts) (pair? (cdr opts)) (pair? (cddr opts))
                       (pair? (cdddr opts)))
                (cadddr opts)
                #f)))
      (when bg (send-message ed SCI_CALLTIPSETBACK bg))
      (when fg (send-message ed SCI_CALLTIPSETFORE fg))
      ;; Use ffi-scintilla-send-message-string for custom wparam (position)
      (ffi-scintilla-send-message-string
        (scintilla-editor-handle ed) SCI_CALLTIPSHOW
        (max 0 pos) text)))

  (define (cancel-calltip! ed)
    (when (not (zero? (send-message ed SCI_CALLTIPACTIVE)))
      (send-message ed SCI_CALLTIPCANCEL)))

) ;; end library
