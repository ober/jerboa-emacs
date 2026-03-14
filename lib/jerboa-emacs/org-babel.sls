#!chezscheme
;;; org-babel.sls — Org babel: code block execution, results, variables, tangle.
;;;
;;; Ported from gerbil-emacs/org-babel.ss
;;; Backend-agnostic (Scintilla API only, no Qt imports).

(library (jerboa-emacs org-babel)
  (export
    ;; Language registry
    *org-babel-lang-commands*

    ;; Sessions
    org-babel-session-key
    org-babel-get-session
    org-babel-session-execute
    org-babel-kill-session
    org-babel-kill-all-sessions

    ;; Source block parsing
    org-babel-find-src-block
    org-babel-parse-begin-line
    org-babel-parse-header-args
    org-babel-inside-src-block?

    ;; Code execution
    org-babel-execute
    org-babel-file-extension
    org-babel-collect-vars
    org-babel-resolve-var-ref
    org-babel-find-named-block-lang
    org-babel-find-named-table
    org-babel-parse-table-row
    org-babel-table-to-string
    org-babel-inject-variables
    org-babel-python-value
    org-babel-ruby-value

    ;; Result handling
    org-babel-format-result
    org-babel-insert-result

    ;; C-c C-c context
    org-ctrl-c-ctrl-c-context
    org-table-line-check?

    ;; Noweb
    org-babel-expand-noweb
    org-babel-find-named-block

    ;; Tangle
    org-babel-tangle
    org-babel-tangle-to-files
    expand-tangle-path)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (only (std srfi srfi-13)
                string-trim string-contains string-prefix? string-join
                string-pad-right string-index)
          (jerboa-emacs pregexp-compat)
          (only (std misc string) string-split)
          (std misc process)
          (chez-scintilla scintilla)
          (chez-scintilla constants)
          (jerboa-emacs core)
          (jerboa-emacs org-parse))

  ;;;============================================================================
  ;;; Local helpers
  ;;;============================================================================

  (def (read-all-as-string port)
    "Read all available text from a textual input port."
    (let lp ((chunks '()))
      (let ((buf (get-string-n port 4096)))
        (if (eof-object? buf)
          (if (null? chunks)
            ""
            (apply string-append (reverse chunks)))
          (lp (cons buf chunks))))))

  (def (filter-map f lst)
    "Map f over lst, filtering out #f results."
    (let loop ((l lst) (acc '()))
      (if (null? l)
        (reverse acc)
        (let ((r (f (car l))))
          (if r
            (loop (cdr l) (cons r acc))
            (loop (cdr l) acc))))))

  (def (path-directory path)
    "Return the directory part of a path, or \".\" if none."
    (let ((idx (let loop ((i (- (string-length path) 1)))
                 (cond ((< i 0) #f)
                       ((char=? (string-ref path i) #\/) i)
                       (else (loop (- i 1)))))))
      (if idx (substring path 0 idx) ".")))

  (def (create-directory* dir)
    "Create directory and all parents."
    (unless (or (string=? dir "") (string=? dir "/") (string=? dir "."))
      (let ((parent (path-directory dir)))
        (when (and (string? parent)
                   (not (string=? parent ""))
                   (not (string=? parent dir))
                   (not (file-exists? parent)))
          (create-directory* parent)))
      (unless (file-exists? dir)
        (mkdir dir))))

  ;;;============================================================================
  ;;; Language Executor Registry
  ;;;============================================================================

  (def *org-babel-lang-commands*
    '(("bash"    "/bin/bash"  file)
      ("sh"      "/bin/sh"    file)
      ("python"  "python3"    file)
      ("ruby"    "ruby"       file)
      ("node"    "node"       file)
      ("gerbil"  "gxi"        file)
      ("scheme"  "gxi"        file)
      ("perl"    "perl"       file)))

  ;; Active sessions: "lang:session-name" -> process-port-rec
  (def *org-babel-sessions* (make-hash-table))

  (def *babel-session-counter* 0)

  (def (org-babel-session-key lang session-name)
    "Create a session hash key from language and session name."
    (string-append lang ":" (or session-name "default")))

  (def (org-babel-get-session lang session-name)
    "Get or create a persistent session for lang. Returns process-port-rec."
    (let* ((key (org-babel-session-key lang session-name))
           (existing (hash-get *org-babel-sessions* key)))
      (if existing
        existing
        ;; Create new session
        (let* ((cmd-entry (assoc lang *org-babel-lang-commands*))
               (cmd (and cmd-entry (cadr cmd-entry)))
               (args (cond
                       ((or (string=? lang "python") (string=? lang "python3"))
                        '("-i" "-u"))  ;; interactive, unbuffered
                       ((or (string=? lang "bash") (string=? lang "sh"))
                        '("-i"))
                       ((string=? lang "node")
                        '("-i"))
                       ((or (string=? lang "gerbil") (string=? lang "scheme"))
                        '())
                       (else '())))
               (proc (open-process (cons cmd args))))
          (hash-put! *org-babel-sessions* key proc)
          proc))))

  (def (org-babel-session-execute lang code session-name)
    "Execute code in a persistent session. Returns output string."
    (with-catch
      (lambda (e)
        ;; Remove dead session so next call recreates
        (hash-remove! *org-babel-sessions*
                      (org-babel-session-key lang session-name))
        (string-append "Session error: " (format "~a" e)))
      (lambda ()
        (let* ((proc (org-babel-get-session lang session-name))
               (stdin-port (process-port-rec-stdin-port proc))
               (stdout-port (process-port-rec-stdout-port proc))
               ;; Use a unique sentinel to detect end of output
               (sentinel (begin (set! *babel-session-counter*
                                      (+ *babel-session-counter* 1))
                                (string-append "___BABEL_DONE_"
                                  (number->string *babel-session-counter*)
                                  "___")))
               ;; Send the code followed by a sentinel echo
               (sentinel-cmd
                 (cond
                   ((or (string=? lang "python") (string=? lang "python3"))
                    (string-append "print('" sentinel "')"))
                   ((or (string=? lang "bash") (string=? lang "sh"))
                    (string-append "echo '" sentinel "'"))
                   ((string=? lang "node")
                    (string-append "console.log('" sentinel "')"))
                   ((or (string=? lang "gerbil") (string=? lang "scheme"))
                    (string-append "(displayln \"" sentinel "\")"))
                   (else (string-append "echo '" sentinel "'")))))
          (put-string stdin-port code)
          (newline stdin-port)
          (put-string stdin-port sentinel-cmd)
          (newline stdin-port)
          (flush-output-port stdin-port)
          ;; Read lines until we see the sentinel
          (let loop ((lines '()))
            (let ((line (get-line stdout-port)))
              (cond
                ((eof-object? line)
                 (string-join (reverse lines) "\n"))
                ((string-contains line sentinel)
                 (string-join (reverse lines) "\n"))
                (else
                 (loop (cons line lines))))))))))

  (def (org-babel-kill-session lang session-name)
    "Kill a persistent session."
    (let* ((key (org-babel-session-key lang session-name))
           (proc (hash-get *org-babel-sessions* key)))
      (when proc
        (with-catch void
          (lambda ()
            (let ((stdin (process-port-rec-stdin-port proc)))
              (when stdin (close-port stdin)))
            (let ((stdout (process-port-rec-stdout-port proc)))
              (when stdout (close-port stdout)))
            (let ((stderr (process-port-rec-stderr-port proc)))
              (when stderr (close-port stderr)))))
        (hash-remove! *org-babel-sessions* key))))

  (def (org-babel-kill-all-sessions)
    "Kill all active babel sessions."
    (hash-for-each
      (lambda (key proc)
        (with-catch void
          (lambda ()
            (let ((stdin (process-port-rec-stdin-port proc)))
              (when stdin (close-port stdin)))
            (let ((stdout (process-port-rec-stdout-port proc)))
              (when stdout (close-port stdout)))
            (let ((stderr (process-port-rec-stderr-port proc)))
              (when stderr (close-port stderr))))))
      *org-babel-sessions*)
    (set! *org-babel-sessions* (make-hash-table)))

  ;;;============================================================================
  ;;; Source Block Parsing
  ;;;============================================================================

  (def (org-babel-find-src-block lines line-num)
    "Find src block surrounding line-num. Returns
     (values lang header-args body begin-line end-line name) or all #f."
    (let ((total (length lines)))
      ;; Walk backward to find #+BEGIN_SRC
      (let ((begin-line
              (let loop ((i line-num))
                (cond
                  ((< i 0) #f)
                  ((org-block-begin? (list-ref lines i)) i)
                  ((and (> i 0) (< i line-num)
                        (org-block-end? (list-ref lines i)))
                   #f)  ; found END before BEGIN — not inside a block
                  (else (loop (- i 1)))))))
        (if (not begin-line)
          (values #f #f #f #f #f #f)
          (let* ((begin-text (list-ref lines begin-line))
                 (parsed (org-babel-parse-begin-line begin-text)))
            (if (not parsed)
              (values #f #f #f #f #f #f)
              (let ((lang (car parsed))
                    (header-args (cdr parsed)))
                ;; Walk forward to find #+END_SRC
                (let ((end-line
                        (let loop ((i (+ begin-line 1)))
                          (cond
                            ((>= i total) #f)
                            ((org-block-end? (list-ref lines i)) i)
                            (else (loop (+ i 1)))))))
                  (if (not end-line)
                    (values #f #f #f #f #f #f)
                    ;; Extract body
                    (let ((body-lines
                            (let loop ((i (+ begin-line 1)) (acc '()))
                              (if (>= i end-line)
                                (reverse acc)
                                (loop (+ i 1) (cons (list-ref lines i) acc))))))
                      ;; Check for #+NAME: on previous line
                      (let ((name (and (> begin-line 0)
                                       (let ((prev (list-ref lines (- begin-line 1))))
                                         (let ((m (pregexp-match "^#\\+[Nn][Aa][Mm][Ee]:\\s*(.+)" prev)))
                                           (and m (string-trim (list-ref m 1))))))))
                        (values lang header-args
                                (string-join body-lines "\n")
                                begin-line end-line name))))))))))))

  (def (org-babel-parse-begin-line line)
    "Parse #+BEGIN_SRC line. Returns (lang . header-args-hash) or #f."
    (let ((m (pregexp-match "^#\\+[Bb][Ee][Gg][Ii][Nn]_[Ss][Rr][Cc]\\s+(\\S+)(.*)" line)))
      (if (not m)
        #f
        (let ((lang (list-ref m 1))
              (rest (string-trim (list-ref m 2))))
          (cons lang (org-babel-parse-header-args rest))))))

  (def (org-babel-parse-header-args str)
    "Parse ':key value :key2 value2' into a hash table."
    (let ((result (make-hash-table)))
      (let ((parts (string-split str #\space)))
        (let loop ((rest parts))
          (cond
            ((null? rest) result)
            ((and (pair? rest) (> (string-length (car rest)) 0)
                  (char=? (string-ref (car rest) 0) #\:))
             (let ((key (substring (car rest) 1 (string-length (car rest)))))
               (if (pair? (cdr rest))
                 (begin
                   (hash-put! result key (cadr rest))
                   (loop (cddr rest)))
                 (begin
                   (hash-put! result key "yes")
                   (loop (cdr rest))))))
            (else (loop (cdr rest))))))))

  (def (org-babel-inside-src-block? lines line-num)
    "Check if line-num is inside a src block."
    (let-values (((lang hargs body begin end name)
                  (org-babel-find-src-block lines line-num)))
      (and lang (> line-num begin) (< line-num end))))

  ;;;============================================================================
  ;;; Code Execution
  ;;;============================================================================

  (def (org-babel-execute lang code header-args . rest)
    "Execute code in the given language. Returns output string.
     Pass buffer-text as optional argument for :noweb expansion support.
     When :session header is present, uses persistent process."
    (let* ((buffer-text (if (pair? rest) (car rest) #f))
           (cmd-entry (assoc lang *org-babel-lang-commands*))
           (dir (or (hash-get header-args "dir") #f))
           (vars (org-babel-collect-vars header-args buffer-text))
           (noweb? (equal? (hash-get header-args "noweb") "yes"))
           (session-name (hash-get header-args "session"))
           (use-session? (and session-name (not (string=? session-name "none"))))
           (results-type (or (hash-get header-args "results") "output")))
      (if (not cmd-entry)
        (string-append "Error: unknown language '" lang "'")
        (let* ((cmd (cadr cmd-entry))
               ;; Expand noweb references if enabled
               (expanded-code (if (and noweb? buffer-text)
                                (org-babel-expand-noweb buffer-text code)
                                code))
               ;; Inject variable preamble
               (full-code (if (null? vars)
                            expanded-code
                            (string-append (org-babel-inject-variables lang vars) "\n" expanded-code))))
          (if use-session?
            ;; Use persistent session
            (string-trim (org-babel-session-execute lang full-code session-name))
            ;; One-shot execution via temp file
            (let* ((ext (org-babel-file-extension lang))
                   (tmp (string-append "/tmp/org-babel-" lang "." ext)))
              (call-with-output-file tmp
                (lambda (port) (display full-code port)))
              (with-catch
                (lambda (e)
                  (string-append "Error: " (format "~a" e)))
                (lambda ()
                  (let ((output (run-process
                                  (list cmd tmp)
                                  'directory: (or dir #f))))
                    (string-trim output))))))))))

  (def (org-babel-file-extension lang)
    "Get file extension for a language."
    (cond
      ((or (string=? lang "bash") (string=? lang "sh")) "sh")
      ((string=? lang "python") "py")
      ((string=? lang "ruby") "rb")
      ((string=? lang "node") "js")
      ((string=? lang "perl") "pl")
      ((or (string=? lang "gerbil") (string=? lang "scheme")) "ss")
      (else "txt")))

  (def (org-babel-collect-vars header-args . rest)
    "Extract :var declarations from header args. Returns list of (name . value).
     When buffer-text (optional arg) is provided, resolves named block/table references."
    (let ((buffer-text (if (pair? rest) (car rest) #f))
          (var-str (hash-get header-args "var")))
      (if (not var-str)
        '()
        ;; Parse "name=value"
        (let ((parts (string-split var-str #\,)))
          (filter-map
            (lambda (part)
              (let ((eq-pos (string-index (string-trim part) #\=)))
                (if eq-pos
                  (let* ((name (substring (string-trim part) 0 eq-pos))
                         (raw-val (substring (string-trim part) (+ eq-pos 1)
                                             (string-length (string-trim part))))
                         (val (if buffer-text
                                (org-babel-resolve-var-ref buffer-text raw-val)
                                raw-val)))
                    (cons name val))
                  #f)))
            parts)))))

  (def (org-babel-resolve-var-ref text ref-name)
    "Resolve a :var reference. If ref-name matches a #+NAME: src block,
     execute it and return output. If it matches a named table, convert
     to list format. Otherwise return ref-name as literal."
    ;; First check for a named src block
    (let ((block-body (org-babel-find-named-block text ref-name)))
      (if block-body
        ;; Found a named src block — find its language and execute
        (let ((block-lang (org-babel-find-named-block-lang text ref-name)))
          (if block-lang
            (let ((result (org-babel-execute block-lang block-body
                            (make-hash-table))))
              (string-trim result))
            ref-name))
        ;; Check for a named table
        (let ((table-data (org-babel-find-named-table text ref-name)))
          (if table-data
            table-data
            ref-name)))))

  (def (org-babel-find-named-block-lang text name)
    "Find the language of a named src block."
    (let* ((lines (string-split text #\newline))
           (total (length lines)))
      (let loop ((i 0))
        (cond
          ((>= i total) #f)
          ((let ((line (list-ref lines i)))
             (let ((m (pregexp-match "^#\\+[Nn][Aa][Mm][Ee]:\\s*(.+)" line)))
               (and m (string=? (string-trim (list-ref m 1)) name)
                    (< (+ i 1) total)
                    (org-block-begin? (list-ref lines (+ i 1))))))
           ;; Found it — parse the BEGIN_SRC line for language
           (let ((parsed (org-babel-parse-begin-line (list-ref lines (+ i 1)))))
             (and parsed (car parsed))))
          (else (loop (+ i 1)))))))

  (def (org-babel-find-named-table text name)
    "Find a named org table and convert to a language-appropriate string.
     Returns comma-separated rows with pipe-separated cells, or #f."
    (let* ((lines (string-split text #\newline))
           (total (length lines)))
      (let loop ((i 0))
        (cond
          ((>= i total) #f)
          ((let ((line (list-ref lines i)))
             (let ((m (pregexp-match "^#\\+[Nn][Aa][Mm][Ee]:\\s*(.+)" line)))
               (and m (string=? (string-trim (list-ref m 1)) name)
                    (< (+ i 1) total)
                    (org-table-line-check? (list-ref lines (+ i 1))))))
           ;; Found named table — collect rows
           (let table-loop ((j (+ i 1)) (rows '()))
             (if (or (>= j total)
                     (not (org-table-line-check? (list-ref lines j))))
               ;; Convert to data string: list of lists
               (org-babel-table-to-string (reverse rows))
               ;; Skip separator lines (|---|---|)
               (let ((line (list-ref lines j)))
                 (if (pregexp-match "^\\s*\\|[-+]+\\|" line)
                   (table-loop (+ j 1) rows)
                   (table-loop (+ j 1) (cons (org-babel-parse-table-row line) rows)))))))
          (else (loop (+ i 1)))))))

  (def (org-babel-parse-table-row line)
    "Parse '| a | b | c |' into list of trimmed cell strings."
    (let* ((trimmed (string-trim line))
           ;; Remove leading and trailing |
           (inner (if (and (> (string-length trimmed) 0)
                           (char=? (string-ref trimmed 0) #\|))
                    (substring trimmed 1 (string-length trimmed))
                    trimmed))
           (inner2 (if (and (> (string-length inner) 0)
                            (char=? (string-ref inner (- (string-length inner) 1)) #\|))
                     (substring inner 0 (- (string-length inner) 1))
                     inner)))
      (map string-trim (string-split inner2 #\|))))

  (def (org-babel-table-to-string rows)
    "Convert list of row-lists to a string suitable for variable injection.
     Format: [[\"a\",\"b\"],[\"c\",\"d\"]] for general use."
    (string-append
      "["
      (string-join
        (map (lambda (row)
               (string-append
                 "["
                 (string-join
                   (map (lambda (cell)
                          (if (pregexp-match "^-?\\d+\\.?\\d*$" cell)
                            cell
                            (string-append "\"" cell "\"")))
                        row)
                   ",")
                 "]"))
             rows)
        ",")
      "]"))

  (def (org-babel-inject-variables lang vars)
    "Generate variable preamble for the given language."
    (string-join
      (map (lambda (pair)
             (let ((name (car pair)) (val (cdr pair)))
               (cond
                 ((or (string=? lang "bash") (string=? lang "sh"))
                  (string-append name "='" val "'"))
                 ((string=? lang "python")
                  (string-append name " = " (org-babel-python-value val)))
                 ((string=? lang "ruby")
                  (string-append name " = " (org-babel-ruby-value val)))
                 ((or (string=? lang "gerbil") (string=? lang "scheme"))
                  (string-append "(def " name " " val ")"))
                 ((string=? lang "node")
                  (string-append "const " name " = " val ";"))
                 (else
                  (string-append "# " name " = " val)))))
           vars)
      "\n"))

  (def (org-babel-python-value val)
    "Format value for Python."
    (if (pregexp-match "^-?\\d+\\.?\\d*$" val)
      val  ; number
      (string-append "\"" val "\"")))

  (def (org-babel-ruby-value val)
    "Format value for Ruby."
    (if (pregexp-match "^-?\\d+\\.?\\d*$" val)
      val
      (string-append "\"" val "\"")))

  ;;;============================================================================
  ;;; Result Handling
  ;;;============================================================================

  (def (org-babel-format-result output results-type)
    "Format execution output according to results type."
    (cond
      ((string=? results-type "output")
       ;; Prefix each line with ": "
       (let ((lines (string-split output #\newline)))
         (string-join
           (map (lambda (l) (string-append ": " l)) lines)
           "\n")))
      ((string=? results-type "value")
       output)
      (else output)))

  (def (org-babel-insert-result ed end-line output results-type)
    "Insert or replace #+RESULTS: block after end-line."
    (let* ((total (editor-get-line-count ed))
           (formatted (org-babel-format-result output
                        (or results-type "output")))
           ;; Check if there's already a #+RESULTS: block
           (next-line (+ end-line 1))
           (has-results?
             (and (< next-line total)
                  (let ((l (editor-get-line ed next-line)))
                    (pregexp-match "^#\\+[Rr][Ee][Ss][Uu][Ll][Tt][Ss]:" l)))))
      (if has-results?
        ;; Replace existing results
        (let* ((results-start (editor-position-from-line ed next-line))
               ;; Find end of results block (lines starting with ": " or blank line)
               (results-end
                 (let loop ((i (+ next-line 1)))
                   (if (>= i total)
                     (editor-get-text-length ed)
                     (let ((l (editor-get-line ed i)))
                       (if (or (string-prefix? ": " l)
                               (string-prefix? ":" (string-trim l)))
                         (loop (+ i 1))
                         (editor-position-from-line ed i))))))
               (new-text (string-append "#+RESULTS:\n" formatted "\n")))
          (send-message ed SCI_SETTARGETSTART results-start)
          (send-message ed SCI_SETTARGETEND results-end)
          (send-message/string ed SCI_REPLACETARGET new-text))
        ;; Insert new results
        (let* ((insert-pos (send-message ed SCI_GETLINEENDPOSITION end-line))
               (new-text (string-append "\n#+RESULTS:\n" formatted)))
          (editor-insert-text ed insert-pos new-text)))))

  ;;;============================================================================
  ;;; C-c C-c Context Dispatch
  ;;;============================================================================

  (def (org-ctrl-c-ctrl-c-context lines line-num)
    "Determine context for C-c C-c. Returns a symbol:
     'src-block, 'table, 'checkbox, 'keyword, 'heading, or 'none."
    (let ((line (if (< line-num (length lines)) (list-ref lines line-num) "")))
      (cond
        ((org-babel-inside-src-block? lines line-num) 'src-block)
        ((org-table-line-check? line) 'table)
        ((string-contains line "[ ]") 'checkbox)
        ((string-contains line "[X]") 'checkbox)
        ((pregexp-match "^#\\+" line) 'keyword)
        ((org-heading-line? line) 'heading)
        (else 'none))))

  (def (org-table-line-check? line)
    "Quick check if line looks like a table row."
    (let ((trimmed (string-trim line)))
      (and (> (string-length trimmed) 0)
           (char=? (string-ref trimmed 0) #\|))))

  ;;;============================================================================
  ;;; Noweb Reference Expansion
  ;;;============================================================================

  (def (org-babel-expand-noweb text body)
    "Expand <<block-name>> references in body using named blocks from text.
     Max depth 10 to prevent infinite recursion."
    (org-babel-expand-noweb-depth text body 0))

  (def (org-babel-expand-noweb-depth text body depth)
    (if (> depth 10)
      body
      (let ((m (pregexp-match "<<([^>]+)>>" body)))
        (if (not m)
          body
          (let* ((ref-name (list-ref m 1))
                 (block-body (org-babel-find-named-block text ref-name))
                 (replacement (or block-body
                                  (string-append "<<" ref-name ">>"))))
            (org-babel-expand-noweb-depth
              text
              (pregexp-replace (string-append "<<" (pregexp-quote ref-name) ">>")
                               body replacement)
              (+ depth 1)))))))

  (def (org-babel-find-named-block text name)
    "Find a named src block in text and return its body."
    (let* ((lines (string-split text #\newline))
           (total (length lines)))
      (let loop ((i 0))
        (cond
          ((>= i total) #f)
          ((let ((line (list-ref lines i)))
             (let ((m (pregexp-match "^#\\+[Nn][Aa][Mm][Ee]:\\s*(.+)" line)))
               (and m (string=? (string-trim (list-ref m 1)) name)
                    (< (+ i 1) total)
                    (org-block-begin? (list-ref lines (+ i 1))))))
           ;; Found it — extract body
           (let ((begin-line (+ i 1)))
             (let body-loop ((j (+ begin-line 1)) (acc '()))
               (cond
                 ((>= j total) (string-join (reverse acc) "\n"))
                 ((org-block-end? (list-ref lines j))
                  (string-join (reverse acc) "\n"))
                 (else (body-loop (+ j 1) (cons (list-ref lines j) acc)))))))
          (else (loop (+ i 1)))))))

  ;;;============================================================================
  ;;; Tangle
  ;;;============================================================================

  (def (org-babel-tangle text)
    "Extract all :tangle blocks from text and return list of (file . content) pairs."
    (let* ((lines (string-split text #\newline))
           (total (length lines)))
      (let loop ((i 0) (result '()))
        (if (>= i total)
          result
          (let ((line (list-ref lines i)))
            (if (not (org-block-begin? line))
              (loop (+ i 1) result)
              ;; Parse begin line for :tangle
              (let ((parsed (org-babel-parse-begin-line line)))
                (if (not parsed)
                  (loop (+ i 1) result)
                  (let* ((hargs (cdr parsed))
                         (tangle-file (hash-get hargs "tangle")))
                    (if (or (not tangle-file) (string=? tangle-file "no"))
                      (loop (+ i 1) result)
                      ;; Extract body
                      (let body-loop ((j (+ i 1)) (acc '()))
                        (cond
                          ((>= j total)
                           (loop j (cons (cons tangle-file
                                               (string-join (reverse acc) "\n"))
                                         result)))
                          ((org-block-end? (list-ref lines j))
                           (loop (+ j 1)
                                 (cons (cons tangle-file
                                             (string-join (reverse acc) "\n"))
                                       result)))
                          (else
                           (body-loop (+ j 1) (cons (list-ref lines j) acc)))))))))))))))

  (def (org-babel-tangle-to-files text)
    "Tangle text and write to files. Returns list of files written."
    (let ((pairs (org-babel-tangle text)))
      ;; Merge multiple blocks going to same file
      (let ((merged (make-hash-table)))
        (for-each
          (lambda (pair)
            (let ((file (expand-tangle-path (car pair)))
                  (content (cdr pair)))
              (hash-put! merged file
                         (string-append (or (hash-get merged file) "")
                                        (if (hash-get merged file) "\n" "")
                                        content))))
          pairs)
        ;; Write files
        (let ((files '()))
          (hash-for-each
            (lambda (file content)
              (let ((dir (path-directory file)))
                (when (and (string? dir) (not (string=? dir ""))
                           (not (file-exists? dir)))
                  (create-directory* dir)))
              (call-with-output-file file
                (lambda (port) (display content port)))
              (set! files (cons file files)))
            merged)
          files))))

  (def (expand-tangle-path path)
    "Expand ~ in tangle path."
    (if (string-prefix? "~/" path)
      (string-append (or (getenv "HOME") "/tmp")
                     (substring path 1 (string-length path)))
      path))

  ) ;; end library
