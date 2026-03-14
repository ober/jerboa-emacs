#!chezscheme
;;; persist.sls — Persistence for jemacs
;;;
;;; Ported from gerbil-emacs/persist.ss
;;; Backend-agnostic persistence: recent files, minibuffer history,
;;; desktop (session) save/restore. No Scintilla or Qt imports.

(library (jerboa-emacs persist)
  (export
    ;; Recent files
    recent-files
    recent-files-max
    recent-files-add!
    recent-files-save!
    recent-files-load!
    recent-files-cleanup!

    ;; Savehist (minibuffer history persistence)
    savehist-save!
    savehist-load!

    ;; M-x command history (frequency-sorted)
    mx-history
    mx-history-file
    mx-history-add!
    mx-history-save!
    mx-history-load!
    mx-history-ordered-candidates

    ;; Desktop (session persistence)
    desktop-save!
    desktop-load
    desktop-entry? desktop-entry-buffer-name desktop-entry-file-path
    desktop-entry-cursor-pos desktop-entry-major-mode
    make-desktop-entry

    ;; Buffer-local variables
    buffer-locals
    buffer-local-get
    buffer-local-set!
    buffer-local-delete!
    buffer-locals-for

    ;; Auto-mode-alist
    auto-mode-alist
    detect-major-mode

    ;; Which-key
    which-key-mode which-key-mode-set!
    which-key-delay which-key-delay-set!
    which-key-summary

    ;; Scroll margin
    scroll-margin scroll-margin-set!

    ;; Persistent scratch
    scratch-file
    scratch-save!
    scratch-load!

    ;; Theme and font persistence
    theme-settings-file
    theme-settings-save!
    theme-settings-load!

    ;; Custom face persistence
    custom-faces-file
    custom-faces
    custom-faces-save!
    custom-faces-load!
    record-face-customization!

    ;; Init file
    init-file-path
    init-file-load!

    ;; Save-place (remember cursor position per file)
    save-place-enabled save-place-enabled-set!
    save-place-alist
    save-place-remember!
    save-place-restore
    save-place-save!
    save-place-load!

    ;; Clean-on-save hooks
    delete-trailing-whitespace-on-save delete-trailing-whitespace-on-save-set!
    require-final-newline require-final-newline-set!

    ;; Centered cursor mode
    centered-cursor-mode centered-cursor-mode-set!

    ;; Auto-fill mode
    auto-fill-mode auto-fill-mode-set!
    fill-column fill-column-set!

    ;; Abbrev mode
    abbrev-table
    abbrev-mode-enabled abbrev-mode-enabled-set!

    ;; Enriched mode
    enriched-mode enriched-mode-set!

    ;; Picture mode
    picture-mode picture-mode-set!

    ;; Electric-pair mode
    electric-pair-mode electric-pair-mode-set!

    ;; Copilot (AI inline completion)
    copilot-mode copilot-mode-set!
    copilot-api-key
    copilot-model copilot-model-set!
    copilot-api-url
    copilot-suggestion copilot-suggestion-set!
    copilot-suggestion-pos copilot-suggestion-pos-set!

    ;; Persistence paths
    persist-path)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1-)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std srfi srfi-13)
          (only (std misc string) string-split)
          (only (jerboa prelude) path-strip-directory)
          (jerboa-emacs core)
          (jerboa-emacs customize)
          (jerboa-emacs face))

  ;;;============================================================================
  ;;; Persistence file paths
  ;;;============================================================================

  (def (persist-dir)
    (or (getenv "HOME") "."))

  (def (persist-path name)
    (string-append (persist-dir) "/" name))

  (def *recent-files-file* ".jemacs-recent-files")
  (def *savehist-file*     ".jemacs-history")
  (def *desktop-file*      ".jemacs-desktop")

  ;;;============================================================================
  ;;; Recent files
  ;;;============================================================================

  (def *recent-files* '())
  (def *recent-files-max* 50)

  (def (recent-files) *recent-files*)
  (def (recent-files-max) *recent-files-max*)

  (def (recent-files-add! path)
    (when (and (string? path) (> (string-length path) 0))
      (let ((abs-path (if (path-absolute? path) path
                          (string-append (current-directory) "/" path))))
        ;; Remove existing entry (move to front)
        (set! *recent-files*
          (cons abs-path
            (let loop ((files *recent-files*) (acc '()))
              (cond
                ((null? files) (reverse acc))
                ((string=? (car files) abs-path) (loop (cdr files) acc))
                (else (loop (cdr files) (cons (car files) acc)))))))
        ;; Trim to max size
        (when (> (length *recent-files*) *recent-files-max*)
          (set! *recent-files*
            (let loop ((files *recent-files*) (n 0) (acc '()))
              (if (or (null? files) (>= n *recent-files-max*))
                (reverse acc)
                (loop (cdr files) (+ n 1) (cons (car files) acc)))))))))

  (def (recent-files-save!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (call-with-output-file (persist-path *recent-files-file*)
          (lambda (port)
            (for-each (lambda (f)
                        (display f port)
                        (newline port))
                      *recent-files*))))))

  (def (recent-files-load!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let ((path (persist-path *recent-files-file*)))
          (when (file-exists? path)
            (set! *recent-files*
              (call-with-input-file path
                (lambda (port)
                  (let loop ((acc '()))
                    (let ((line (get-line port)))
                      (if (eof-object? line)
                        (reverse acc)
                        (if (> (string-length line) 0)
                          (loop (cons line acc))
                          (loop acc)))))))))))))

  (def (recent-files-cleanup!)
    (let* ((before (length *recent-files*))
           (cleaned (filter file-exists? *recent-files*))
           (removed (- before (length cleaned))))
      (set! *recent-files* cleaned)
      (recent-files-save!)
      removed))

  ;;;============================================================================
  ;;; Savehist (minibuffer history persistence)
  ;;;============================================================================

  (def (savehist-save! history)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (call-with-output-file (persist-path *savehist-file*)
          (lambda (port)
            (for-each (lambda (entry)
                        (display entry port)
                        (newline port))
                      history))))))

  (def (savehist-load!)
    (with-catch
      (lambda (e) '())
      (lambda ()
        (let ((path (persist-path *savehist-file*)))
          (if (file-exists? path)
            (call-with-input-file path
              (lambda (port)
                (let loop ((acc '()))
                  (let ((line (get-line port)))
                    (if (eof-object? line)
                      (reverse acc)
                      (if (> (string-length line) 0)
                        (loop (cons line acc))
                        (loop acc)))))))
            '())))))

  ;;;============================================================================
  ;;; M-x command history (frequency + recency sorted, persisted)
  ;;;============================================================================

  (def *mx-history* (make-hash-table))
  (def *mx-history-file*
    (string-append (or (getenv "HOME") "/tmp") "/.jemacs-mx-history"))

  (def (mx-history) *mx-history*)
  (def (mx-history-file) *mx-history-file*)

  (def (mx-history-add! name)
    (when (and (string? name) (> (string-length name) 0))
      (let ((count (hash-ref *mx-history* name 0)))
        (hash-put! *mx-history* name (+ count 1)))))

  (def (mx-history-save!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (when (> (hash-length *mx-history*) 0)
          (call-with-output-file *mx-history-file*
            (lambda (port)
              (hash-for-each
                (lambda (name count)
                  (display name port)
                  (display "\t" port)
                  (display count port)
                  (newline port))
                *mx-history*)))))))

  (def (mx-history-load!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (when (file-exists? *mx-history-file*)
          (call-with-input-file *mx-history-file*
            (lambda (port)
              (let loop ()
                (let ((line (get-line port)))
                  (unless (eof-object? line)
                    (let ((tab-pos (string-index line #\tab)))
                      (when tab-pos
                        (let* ((name (substring line 0 tab-pos))
                               (count-str (substring line (+ tab-pos 1) (string-length line)))
                               (count (with-catch (lambda (e) 1)
                                        (lambda () (string->number count-str)))))
                          (when (and (> (string-length name) 0) count)
                            (hash-put! *mx-history* name count)))))
                    (loop))))))))))

  (def (mx-history-ordered-candidates all-names)
    (let* ((with-count (map (lambda (n) (cons n (hash-ref *mx-history* n 0))) all-names))
           (frequent (filter (lambda (p) (> (cdr p) 0)) with-count))
           (rest (filter (lambda (p) (= (cdr p) 0)) with-count))
           (sorted-freq (list-sort (lambda (a b) (> (cdr a) (cdr b))) frequent)))
      (append (map car sorted-freq) (map car rest))))

  ;;;============================================================================
  ;;; Desktop (session persistence)
  ;;;============================================================================

  (defstruct desktop-entry (buffer-name file-path cursor-pos major-mode))

  (def (desktop-save! entries)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (call-with-output-file (persist-path *desktop-file*)
          (lambda (port)
            (for-each
              (lambda (entry)
                (let ((fp (or (desktop-entry-file-path entry) ""))
                      (pos (number->string (desktop-entry-cursor-pos entry)))
                      (name (desktop-entry-buffer-name entry))
                      (mode (let ((m (desktop-entry-major-mode entry)))
                              (if m (symbol->string m) ""))))
                  (display fp port) (display "\t" port)
                  (display pos port) (display "\t" port)
                  (display name port) (display "\t" port)
                  (display mode port) (newline port)))
              entries))))))

  (def (desktop-load)
    (with-catch
      (lambda (e) '())
      (lambda ()
        (let ((path (persist-path *desktop-file*)))
          (if (file-exists? path)
            (call-with-input-file path
              (lambda (port)
                (let loop ((acc '()))
                  (let ((line (get-line port)))
                    (if (eof-object? line)
                      (reverse acc)
                      (let ((parts (string-split line #\tab)))
                        (if (>= (length parts) 3)
                          (let ((fp (car parts))
                                (pos (string->number (cadr parts)))
                                (name (caddr parts))
                                (mode (if (>= (length parts) 4)
                                        (let ((m (cadddr parts)))
                                          (if (> (string-length m) 0)
                                            (string->symbol m)
                                            #f))
                                        #f)))
                            (loop (cons (make-desktop-entry
                                          name
                                          (if (string=? fp "") #f fp)
                                          (or pos 0)
                                          mode)
                                        acc)))
                          (loop acc))))))))
            '())))))

  ;;;============================================================================
  ;;; Buffer-local variables
  ;;;============================================================================

  (def *buffer-locals* (make-hash-table))

  (def (buffer-locals) *buffer-locals*)

  (def (buffer-local-get buf key . rest)
    (let ((default (if (pair? rest) (car rest) #f)))
      (let ((locals (hash-get *buffer-locals* buf)))
        (if locals
          (let ((val (hash-get locals key)))
            (if val val default))
          default))))

  (def (buffer-local-set! buf key value)
    (let ((locals (hash-get *buffer-locals* buf)))
      (unless locals
        (set! locals (make-hash-table))
        (hash-put! *buffer-locals* buf locals))
      (hash-put! locals key value)))

  (def (buffer-local-delete! buf)
    (hash-remove! *buffer-locals* buf))

  (def (buffer-locals-for buf)
    (hash-get *buffer-locals* buf))

  ;;;============================================================================
  ;;; Auto-mode-alist
  ;;;============================================================================

  (def *auto-mode-alist*
    '((".ss"    . scheme-mode)
      (".sls"   . scheme-mode)
      (".scm"   . scheme-mode)
      (".sld"   . scheme-mode)
      (".el"    . emacs-lisp-mode)
      (".clj"   . clojure-mode)
      (".lisp"  . lisp-mode)
      (".cl"    . lisp-mode)
      (".org"   . org-mode)
      (".md"    . markdown-mode)
      (".markdown" . markdown-mode)
      (".html"  . html-mode)
      (".htm"   . html-mode)
      (".css"   . css-mode)
      (".js"    . js-mode)
      (".jsx"   . js-mode)
      (".ts"    . typescript-mode)
      (".tsx"   . typescript-mode)
      (".json"  . json-mode)
      (".c"     . c-mode)
      (".h"     . c-mode)
      (".cpp"   . c++-mode)
      (".cc"    . c++-mode)
      (".cxx"   . c++-mode)
      (".hpp"   . c++-mode)
      (".java"  . java-mode)
      (".rs"    . rust-mode)
      (".go"    . go-mode)
      (".zig"   . zig-mode)
      (".py"    . python-mode)
      (".rb"    . ruby-mode)
      (".lua"   . lua-mode)
      (".pl"    . perl-mode)
      (".pm"    . perl-mode)
      (".sh"    . shell-mode)
      (".bash"  . shell-mode)
      (".zsh"   . shell-mode)
      (".fish"  . fish-mode)
      (".yml"   . yaml-mode)
      (".yaml"  . yaml-mode)
      (".toml"  . toml-mode)
      (".ini"   . conf-mode)
      (".cfg"   . conf-mode)
      (".conf"  . conf-mode)
      (".tex"   . latex-mode)
      (".bib"   . bibtex-mode)
      (".rst"   . rst-mode)
      (".xml"   . xml-mode)
      (".sql"   . sql-mode)
      (".csv"   . csv-mode)
      ("Makefile" . makefile-mode)
      ("makefile" . makefile-mode)
      ("GNUmakefile" . makefile-mode)
      ("Dockerfile" . dockerfile-mode)
      (".mk"    . makefile-mode)
      (".cmake" . cmake-mode)
      (".diff"  . diff-mode)
      (".patch" . diff-mode)
      (".erl"   . erlang-mode)
      (".ex"    . elixir-mode)
      (".exs"   . elixir-mode)
      (".hs"    . haskell-mode)
      (".ml"    . ocaml-mode)
      (".mli"   . ocaml-mode)
      (".nix"   . nix-mode)
      (".swift" . swift-mode)
      (".kt"    . kotlin-mode)
      (".scala" . scala-mode)
      (".r"     . r-mode)
      (".R"     . r-mode)
      (".rkt"   . racket-mode)))

  (def (auto-mode-alist) *auto-mode-alist*)

  (def (detect-major-mode filename)
    (when (and (string? filename) (> (string-length filename) 0))
      (let ((basename (path-strip-directory filename)))
        (let loop ((alist *auto-mode-alist*))
          (cond
            ((null? alist) #f)
            ((string=? basename (caar alist))
             (cdar alist))
            ((string-suffix? (caar alist) filename)
             (cdar alist))
            (else (loop (cdr alist))))))))

  ;;;============================================================================
  ;;; Which-key (prefix key hints)
  ;;;============================================================================

  (def *which-key-mode* #t)
  (def (which-key-mode) *which-key-mode*)
  (def (which-key-mode-set! v) (set! *which-key-mode* v))

  (def *which-key-delay* 0.5)
  (def (which-key-delay) *which-key-delay*)
  (def (which-key-delay-set! v) (set! *which-key-delay* v))

  (def (which-key-summary keymap . rest)
    (let ((max-entries (if (pair? rest) (car rest) 20)))
      (let* ((entries (hash->list keymap))
             (sorted (list-sort (lambda (a b) (string<? (car a) (car b))) entries))
             (items
               (let loop ((es sorted) (acc '()) (n 0))
                 (cond
                   ((null? es) (reverse acc))
                   ((>= n max-entries) (reverse (cons "..." acc)))
                   (else
                     (let* ((key (caar es))
                            (val (cdar es))
                            (desc (cond
                                    ((hash-table? val) "+prefix")
                                    ((symbol? val) (command-name->description val))
                                    (else "?"))))
                       (loop (cdr es)
                             (cons (string-append key " → " desc) acc)
                             (+ n 1))))))))
        (string-join items "  "))))

  ;;;============================================================================
  ;;; Scroll margin
  ;;;============================================================================

  (def *scroll-margin* 3)
  (def (scroll-margin) *scroll-margin*)
  (def (scroll-margin-set! v) (set! *scroll-margin* v))

  ;;;============================================================================
  ;;; Persistent scratch buffer
  ;;;============================================================================

  (def *scratch-file* ".jemacs-scratch")
  (def (scratch-file) *scratch-file*)

  (def (scratch-save! text)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (call-with-output-file (persist-path *scratch-file*)
          (lambda (port)
            (display text port))))))

  (def (scratch-load!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let ((path (persist-path *scratch-file*)))
          (if (file-exists? path)
            (call-with-input-file path
              (lambda (port)
                (get-string-all port)))
            #f)))))

  ;;;============================================================================
  ;;; Theme and Font Persistence
  ;;;============================================================================

  (def *theme-settings-file* ".jemacs-theme")
  (def (theme-settings-file) *theme-settings-file*)

  (def (theme-settings-save! theme-name font-family font-size)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (call-with-output-file (persist-path *theme-settings-file*)
          (lambda (port)
            (put-string port (string-append "theme:" (symbol->string theme-name)))
            (newline port)
            (put-string port (string-append "font-family:" font-family))
            (newline port)
            (put-string port (string-append "font-size:" (number->string font-size)))
            (newline port))))))

  (def (theme-settings-load!)
    (with-catch
      (lambda (e) (values #f #f #f))
      (lambda ()
        (let ((path (persist-path *theme-settings-file*)))
          (if (file-exists? path)
            (call-with-input-file path
              (lambda (port)
                (let* ((theme-line (get-line port))
                       (font-family-line (get-line port))
                       (font-size-line (get-line port))
                       (parse-line (lambda (line prefix)
                                     (and (string? line)
                                          (not (eof-object? line))
                                          (string-prefix? prefix line)
                                          (substring line (string-length prefix) (string-length line))))))
                  (values
                    (let ((theme-str (parse-line theme-line "theme:")))
                      (and theme-str (string->symbol theme-str)))
                    (parse-line font-family-line "font-family:")
                    (let ((size-str (parse-line font-size-line "font-size:")))
                      (and size-str (string->number size-str)))))))
            (values #f #f #f))))))

  ;;;============================================================================
  ;;; Custom Face Persistence
  ;;;============================================================================

  (def *custom-faces-file* ".jemacs-custom-faces")
  (def (custom-faces-file) *custom-faces-file*)
  (def *custom-faces* (make-hash-table-eq))
  (def (custom-faces) *custom-faces*)

  (def (custom-faces-save!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (call-with-output-file (persist-path *custom-faces-file*)
          (lambda (port)
            (hash-for-each
              (lambda (face-name customizations)
                (let ((line (symbol->string face-name)))
                  (when (hash-key? customizations 'fg)
                    (set! line (string-append line "\tfg:" (hash-get customizations 'fg))))
                  (when (hash-key? customizations 'bg)
                    (set! line (string-append line "\tbg:" (hash-get customizations 'bg))))
                  (when (hash-key? customizations 'bold)
                    (set! line (string-append line "\tbold:"
                                              (if (hash-get customizations 'bold) "true" "false"))))
                  (when (hash-key? customizations 'italic)
                    (set! line (string-append line "\titalic:"
                                              (if (hash-get customizations 'italic) "true" "false"))))
                  (put-string port line)
                  (newline port)))
              *custom-faces*))))))

  (def (custom-faces-load!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let ((path (persist-path *custom-faces-file*)))
          (when (file-exists? path)
            (call-with-input-file path
              (lambda (port)
                (let loop ()
                  (let ((line (get-line port)))
                    (unless (eof-object? line)
                      (let* ((parts (string-split line #\tab))
                             (face-name (and (pair? parts) (string->symbol (car parts))))
                             (attrs (cdr parts)))
                        (when face-name
                          (let ((customizations (make-hash-table-eq)))
                            (for-each
                              (lambda (attr-str)
                                (let ((colon-idx (string-index attr-str #\:)))
                                  (when colon-idx
                                    (let ((key (string->symbol (substring attr-str 0 colon-idx)))
                                          (val (substring attr-str (+ colon-idx 1) (string-length attr-str))))
                                      (cond
                                        ((eq? key 'fg) (hash-put! customizations 'fg val))
                                        ((eq? key 'bg) (hash-put! customizations 'bg val))
                                        ((eq? key 'bold) (hash-put! customizations 'bold (string=? val "true")))
                                        ((eq? key 'italic) (hash-put! customizations 'italic (string=? val "true"))))))))
                              attrs)
                            (hash-put! *custom-faces* face-name customizations)
                            ;; Apply customizations to the face
                            (when (hash-key? customizations 'fg)
                              (set-face-attribute! face-name 'fg (hash-get customizations 'fg)))
                            (when (hash-key? customizations 'bg)
                              (set-face-attribute! face-name 'bg (hash-get customizations 'bg)))
                            (when (hash-key? customizations 'bold)
                              (set-face-attribute! face-name 'bold (hash-get customizations 'bold)))
                            (when (hash-key? customizations 'italic)
                              (set-face-attribute! face-name 'italic (hash-get customizations 'italic))))))
                      (loop)))))))))))

  (def (record-face-customization! face-name . attrs)
    (let ((customizations (or (hash-get *custom-faces* face-name)
                              (let ((h (make-hash-table-eq)))
                                (hash-put! *custom-faces* face-name h)
                                h))))
      (let loop ((attrs attrs))
        (when (and (pair? attrs) (pair? (cdr attrs)))
          (let ((key (car attrs))
                (val (cadr attrs)))
            (cond
              ((eq? key 'fg) (hash-put! customizations 'fg val))
              ((eq? key 'bg) (hash-put! customizations 'bg val))
              ((eq? key 'bold) (hash-put! customizations 'bold val))
              ((eq? key 'italic) (hash-put! customizations 'italic val)))
            (loop (cddr attrs)))))))

  ;;;============================================================================
  ;;; Init file
  ;;;============================================================================

  (def *init-file-path*
    (string-append (or (getenv "HOME") ".") "/.jemacs-init"))

  (def (init-file-path) *init-file-path*)

  (def (init-file-load!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (when (file-exists? *init-file-path*)
          (call-with-input-file *init-file-path*
            (lambda (port)
              (let loop ()
                (let ((line (get-line port)))
                  (unless (eof-object? line)
                    (let ((trimmed (string-trim-both line)))
                      (when (and (> (string-length trimmed) 0)
                                 (not (char=? (string-ref trimmed 0) #\;))
                                 (not (char=? (string-ref trimmed 0) #\#)))
                        (let ((space-idx (string-index trimmed #\space)))
                          (when space-idx
                            (let ((key (substring trimmed 0 space-idx))
                                  (val (string-trim-both (substring trimmed (+ space-idx 1)
                                                                    (string-length trimmed)))))
                              (cond
                                ((string=? key "scroll-margin")
                                 (let ((n (string->number val)))
                                   (when (and n (>= n 0) (<= n 20))
                                     (custom-set! 'scroll-margin n))))
                                ((string=? key "save-place")
                                 (custom-set! 'save-place
                                   (or (string=? val "true") (string=? val "1"))))
                                ((string=? key "delete-trailing-whitespace-on-save")
                                 (custom-set! 'delete-trailing-whitespace-on-save
                                   (or (string=? val "true") (string=? val "1"))))
                                ((string=? key "require-final-newline")
                                 (custom-set! 'require-final-newline
                                   (or (string=? val "true") (string=? val "1"))))
                                ((string=? key "centered-cursor")
                                 (custom-set! 'centered-cursor
                                   (or (string=? val "true") (string=? val "1"))))
                                ((string=? key "bind")
                                 (let ((sp2 (string-index val #\space)))
                                   (when sp2
                                     (let ((key-str (substring val 0 sp2))
                                           (cmd-str (string-trim-both
                                                      (substring val (+ sp2 1) (string-length val)))))
                                       (when (> (string-length cmd-str) 0)
                                         (keymap-bind! *global-keymap* key-str
                                           (string->symbol cmd-str)))))))
                                ((string=? key "unbind")
                                 (when (> (string-length val) 0)
                                   (hash-remove! *global-keymap* val)))
                                ((string=? key "chord")
                                 (let ((sp2 (string-index val #\space)))
                                   (when sp2
                                     (let ((chord-str (substring val 0 sp2))
                                           (cmd-str (string-trim-both
                                                      (substring val (+ sp2 1) (string-length val)))))
                                       (when (and (= (string-length chord-str) 2)
                                                  (> (string-length cmd-str) 0))
                                         (key-chord-define-global chord-str
                                           (string->symbol cmd-str)))))))
                                ((string=? key "key-translate")
                                 (let ((sp2 (string-index val #\space)))
                                   (when sp2
                                     (let ((from-str (substring val 0 sp2))
                                           (to-str (string-trim-both
                                                     (substring val (+ sp2 1) (string-length val)))))
                                       (when (and (= (string-length from-str) 1)
                                                  (= (string-length to-str) 1))
                                         (key-translate! (string-ref from-str 0)
                                                         (string-ref to-str 0)))))))
                                ((string=? key "chord-mode")
                                 (custom-set! 'chord-mode
                                   (or (string=? val "true") (string=? val "1"))))
                                ((string=? key "chord-timeout")
                                 (let ((n (string->number val)))
                                   (when (and n (> n 0) (<= n 2000))
                                     (custom-set! 'chord-timeout n))))
                                ((string=? key "lsp-server-command")
                                 (when (> (string-length val) 0)
                                   (custom-set! 'lsp-server-command val)))))))))
                    (loop))))))))))

  ;;;============================================================================
  ;;; Save-place: remember cursor position per file
  ;;;============================================================================

  (def *save-place-enabled* #t)
  (def (save-place-enabled) *save-place-enabled*)
  (def (save-place-enabled-set! v) (set! *save-place-enabled* v))

  (def *save-place-file* ".jemacs-places")
  (def *save-place-alist* (make-hash-table))
  (def (save-place-alist) *save-place-alist*)
  (def *save-place-max* 500)

  (def (save-place-remember! file-path position)
    (when (and *save-place-enabled* (string? file-path) (> (string-length file-path) 0))
      (hash-put! *save-place-alist* file-path position)))

  (def (save-place-restore file-path)
    (when (and *save-place-enabled* (string? file-path))
      (hash-get *save-place-alist* file-path)))

  (def (save-place-save!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (call-with-output-file (persist-path *save-place-file*)
          (lambda (port)
            (let ((entries (hash->list *save-place-alist*))
                  (count 0))
              (for-each
                (lambda (pair)
                  (when (< count *save-place-max*)
                    (display (car pair) port)
                    (display "\t" port)
                    (display (number->string (cdr pair)) port)
                    (newline port)
                    (set! count (+ count 1))))
                entries)))))))

  (def (save-place-load!)
    (with-catch
      (lambda (e) #f)
      (lambda ()
        (let ((path (persist-path *save-place-file*)))
          (when (file-exists? path)
            (call-with-input-file path
              (lambda (port)
                (let loop ()
                  (let ((line (get-line port)))
                    (unless (eof-object? line)
                      (let ((tab-idx (string-index line #\tab)))
                        (when tab-idx
                          (let* ((fpath (substring line 0 tab-idx))
                                 (pos-str (substring line (+ tab-idx 1) (string-length line)))
                                 (pos (string->number pos-str)))
                            (when (and pos (> (string-length fpath) 0))
                              (hash-put! *save-place-alist* fpath pos)))))
                      (loop)))))))))))

  ;;;============================================================================
  ;;; Clean-on-save settings
  ;;;============================================================================

  (def *delete-trailing-whitespace-on-save* #t)
  (def (delete-trailing-whitespace-on-save) *delete-trailing-whitespace-on-save*)
  (def (delete-trailing-whitespace-on-save-set! v) (set! *delete-trailing-whitespace-on-save* v))

  (def *require-final-newline* #t)
  (def (require-final-newline) *require-final-newline*)
  (def (require-final-newline-set! v) (set! *require-final-newline* v))

  ;;;============================================================================
  ;;; Centered cursor mode
  ;;;============================================================================

  (def *centered-cursor-mode* #f)
  (def (centered-cursor-mode) *centered-cursor-mode*)
  (def (centered-cursor-mode-set! v) (set! *centered-cursor-mode* v))

  ;;;============================================================================
  ;;; Auto-fill mode
  ;;;============================================================================

  (def *auto-fill-mode* #f)
  (def (auto-fill-mode) *auto-fill-mode*)
  (def (auto-fill-mode-set! v) (set! *auto-fill-mode* v))

  (def *fill-column* 80)
  (def (fill-column) *fill-column*)
  (def (fill-column-set! v) (set! *fill-column* v))

  ;;;============================================================================
  ;;; Abbrev mode
  ;;;============================================================================

  (def *abbrev-table* (make-hash-table))
  (def (abbrev-table) *abbrev-table*)

  (def *abbrev-mode-enabled* #t)
  (def (abbrev-mode-enabled) *abbrev-mode-enabled*)
  (def (abbrev-mode-enabled-set! v) (set! *abbrev-mode-enabled* v))

  ;;;============================================================================
  ;;; Enriched text mode
  ;;;============================================================================

  (def *enriched-mode* #f)
  (def (enriched-mode) *enriched-mode*)
  (def (enriched-mode-set! v) (set! *enriched-mode* v))

  ;;;============================================================================
  ;;; Picture mode
  ;;;============================================================================

  (def *picture-mode* #f)
  (def (picture-mode) *picture-mode*)
  (def (picture-mode-set! v) (set! *picture-mode* v))

  ;;;============================================================================
  ;;; Electric-pair mode
  ;;;============================================================================

  (def *electric-pair-mode* #f)
  (def (electric-pair-mode) *electric-pair-mode*)
  (def (electric-pair-mode-set! v) (set! *electric-pair-mode* v))

  ;;;============================================================================
  ;;; Copilot (AI inline completion) settings
  ;;;============================================================================

  (def *copilot-mode* #f)
  (def (copilot-mode) *copilot-mode*)
  (def (copilot-mode-set! v) (set! *copilot-mode* v))

  (def *copilot-api-key* (or (getenv "OPENAI_API_KEY") ""))
  (def (copilot-api-key) *copilot-api-key*)

  (def *copilot-model* "gpt-4o-mini")
  (def (copilot-model) *copilot-model*)
  (def (copilot-model-set! v) (set! *copilot-model* v))

  (def *copilot-api-url* "https://api.openai.com/v1/chat/completions")
  (def (copilot-api-url) *copilot-api-url*)

  (def *copilot-suggestion* #f)
  (def (copilot-suggestion) *copilot-suggestion*)
  (def (copilot-suggestion-set! v) (set! *copilot-suggestion* v))

  (def *copilot-suggestion-pos* 0)
  (def (copilot-suggestion-pos) *copilot-suggestion-pos*)
  (def (copilot-suggestion-pos-set! v) (set! *copilot-suggestion-pos* v))

  ;;;============================================================================
  ;;; Module-level initialization expressions
  ;;; (R6RS requires all definitions before expressions)
  ;;;============================================================================

  (defvar! 'which-key-mode #t "Show available keybindings after prefix key delay"
           (lambda (v) (set! *which-key-mode* v))
           'boolean #f 'display)
  (defvar! 'which-key-delay 0.5 "Seconds to wait before showing prefix key hints"
           (lambda (v) (set! *which-key-delay* v))
           'number #f 'display)
  (defvar! 'scroll-margin 3 "Lines of margin at top/bottom when scrolling"
           (lambda (v) (set! *scroll-margin* v))
           'integer '(0 . 20) 'display)
  (defvar! 'save-place #t "Remember cursor position in previously visited files"
           (lambda (v) (set! *save-place-enabled* v))
           'boolean #f 'files)
  (defvar! 'delete-trailing-whitespace-on-save #t
           "Delete trailing whitespace when saving a file"
           (lambda (v) (set! *delete-trailing-whitespace-on-save* v))
           'boolean #f 'editing)
  (defvar! 'require-final-newline #t
           "Ensure files end with a newline when saving"
           (lambda (v) (set! *require-final-newline* v))
           'boolean #f 'editing)
  (defvar! 'centered-cursor #f "Keep cursor centered vertically in the window"
           (lambda (v) (set! *centered-cursor-mode* v))
           'boolean #f 'display)
  (defvar! 'auto-fill-mode #f "Automatically break lines at fill-column"
           (lambda (v) (set! *auto-fill-mode* v))
           'boolean #f 'editing)
  (defvar! 'fill-column 80 "Column at which auto-fill wraps text"
           (lambda (v) (set! *fill-column* v))
           'integer '(20 . 200) 'editing)
  (defvar! 'abbrev-mode #t "Enable abbreviation expansion"
           (lambda (v) (set! *abbrev-mode-enabled* v))
           'boolean #f 'editing)
  (defvar! 'enriched-mode #f "Enable basic text formatting (bold/italic)"
           (lambda (v) (set! *enriched-mode* v))
           'boolean #f 'editing)
  (defvar! 'picture-mode #f "Overwrite mode with directional cursor drawing"
           (lambda (v) (set! *picture-mode* v))
           'boolean #f 'editing)
  (defvar! 'electric-pair-mode #f "Auto-insert matching delimiters (parens, brackets, quotes)"
           (lambda (v) (set! *electric-pair-mode* v))
           'boolean #f 'editing)
  (defvar! 'copilot-mode #f "Enable AI inline code completion (requires OPENAI_API_KEY)"
           (lambda (v) (set! *copilot-mode* v))
           'boolean #f 'editing)
  (defvar! 'copilot-model "gpt-4o-mini" "OpenAI model for code completion"
           (lambda (v) (set! *copilot-model* v))
           'string #f 'editing)

  ) ;; end library
