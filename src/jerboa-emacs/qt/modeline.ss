;;; -*- Gerbil -*-
;;; Qt status bar modeline for jerboa-emacs

(export qt-modeline-update!
        detect-eol-from-text
        *buffer-eol-cache*
        *lsp-modeline-provider*
        *modeline-overwrite-provider*
        *modeline-narrow-provider*)

(import :std/sugar
        (only-in :std/misc/memo memo/ttl)
        :jerboa-emacs/qt/sci-shim
        :jerboa-emacs/core
        :jerboa-emacs/qt/window)

(def git-branch-for-dir
  (memo/ttl 5.0
    (lambda (dir)
      (with-catch
        (lambda (e) #f)
        (lambda ()
          (let* ((proc (open-process
                          (list path: "/usr/bin/git"
                                arguments: ["rev-parse" "--abbrev-ref" "HEAD"]
                                directory: dir
                                stdin-redirection: #f
                                stdout-redirection: #t
                                stderr-redirection: #t)))
                 (result (read-line proc)))
            ;; Omit process-status (Qt SIGCHLD race)
            (close-port proc)
            (if (string? result) result #f)))))))

(def (git-branch-for-file file-path)
  (if (not file-path) #f
    (git-branch-for-dir (path-directory file-path))))

(def (mode-name-for-buffer buf)
  (let ((lang (buffer-lexer-lang buf)))
    (case lang
      ((scheme gerbil) "Gerbil")
      ((lisp) "Lisp")
      ((python) "Python")
      ((c) "C")
      ((cpp) "C++")
      ((javascript) "JS")
      ((markdown) "Markdown")
      ((org) "Org")
      ((json) "JSON")
      (else "Text"))))

(def *buffer-eol-cache* (make-hash-table))

(def (detect-eol-from-text text)
  (let loop ((i 0))
    (if (>= i (string-length text))
      "LF"
      (let ((ch (string-ref text i)))
        (cond
          ((char=? ch #\return)
           (if (and (< (+ i 1) (string-length text))
                    (char=? (string-ref text (+ i 1)) #\newline))
             "CRLF"
             "CR"))
          ((char=? ch #\newline) "LF")
          (else (loop (+ i 1))))))))

(def (buffer-eol-indicator buf)
  (or (hash-get *buffer-eol-cache* (buffer-name buf)) "LF"))

(def *lsp-modeline-provider* (box #f))
(def *modeline-overwrite-provider* (box #f))
(def *modeline-narrow-provider* (box #f))

(def (qt-modeline-update! app)
  (let* ((fr (app-state-frame app))
         (win (qt-current-window fr))
         (ed (qt-edit-window-editor win))
         (buf (qt-edit-window-buffer win))
         (line (+ 1 (qt-plain-text-edit-cursor-line ed)))
         (col  (+ 1 (qt-plain-text-edit-cursor-column ed)))
         (total-lines (qt-plain-text-edit-line-count ed))
         (mod? (qt-text-document-modified? (buffer-doc-pointer buf)))
         (ro? (qt-plain-text-edit-read-only? ed))
         (pct (cond
                ((<= total-lines 1) "All")
                ((= line 1) "Top")
                ((= line total-lines) "Bot")
                (else (string-append
                        (number->string
                          (inexact->exact (round (* 100 (/ (- line 1)
                                                           (max 1 (- total-lines 1)))))))
                        "%"))))
         (state-str (cond
                      ((and ro? mod?) "%*")
                      (ro? "%%")
                      (mod? "**")
                      (else "--")))
         (mode (mode-name-for-buffer buf))
         (eol (buffer-eol-indicator buf))
         (branch (git-branch-for-file (buffer-file-path buf)))
         (lsp-provider (unbox *lsp-modeline-provider*))
         (lsp-str (if lsp-provider (lsp-provider) #f))
         (ovr-provider (unbox *modeline-overwrite-provider*))
         (ovr? (and ovr-provider (ovr-provider)))
         (nar-provider (unbox *modeline-narrow-provider*))
         (nar? (and nar-provider (nar-provider buf)))
         (info (string-append
                 "-U:" state-str "-  "
                 (if nar? "Narrow " "")
                 (buffer-name buf) "    "
                 "L" (number->string line)
                 " C" (number->string col)
                 "  " pct
                 "  (" mode
                 (if ovr? " Ovwrt" "")
                 " " eol ")"
                 (if branch
                   (string-append "  " branch)
                   "")
                 (if lsp-str
                   (string-append "  " lsp-str)
                   ""))))
    (qt-main-window-set-status-bar-text! (qt-frame-main-win fr) info)))
