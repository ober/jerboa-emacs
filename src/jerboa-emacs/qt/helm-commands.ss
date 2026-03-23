;;; -*- Gerbil -*-
;;; Helm commands for jemacs (Qt backend)
;;;
;;; Qt-specific helm command registration and overrides.
;;; cmd-helm-buffers-list is defined in commands-core.ss.
;;; cmd-helm-occur is defined here as the Qt-specific version.

(export
  qt-register-helm-commands!
  cmd-helm-occur)

(import :std/sugar
        :std/srfi/13
        :chez-scintilla/constants
        :jerboa-emacs/core
        :jerboa-emacs/qt/sci-shim
        :jerboa-emacs/qt/buffer
        :jerboa-emacs/qt/window
        :jerboa-emacs/qt/echo
        :jerboa-emacs/editor
        (only-in :jerboa-emacs/qt/commands-core current-qt-editor current-qt-buffer
                 cmd-helm-buffers-list))

;;;============================================================================
;;; Qt Helm Occur
;;;============================================================================

(def (cmd-helm-occur app)
  "Search lines in current buffer with Qt helm narrowing."
  (let* ((echo (app-state-echo app))
         (ed (current-qt-editor app))
         (pattern (qt-echo-read-string app "Helm occur pattern: ")))
    (when (and pattern (> (string-length pattern) 0))
      (let* ((text (qt-plain-text-edit-text ed))
             (lines (string-split text #\newline))
             (matches (filter (lambda (l) (string-contains l pattern)) lines)))
        (if (null? matches)
          (echo-message! echo "No matches")
          (let ((buf (qt-buffer-create! "*Helm Occur*" ed)))
            (qt-buffer-attach! ed buf)
            (qt-plain-text-edit-set-text! ed
              (string-append "Helm Occur: " pattern "\n\n"
                (string-join matches "\n") "\n"))))))))

;;;============================================================================
;;; Command registration
;;;============================================================================

(def (qt-register-helm-commands!)
  "Register Qt-specific helm command overrides."
  (register-command! 'helm-buffers-list cmd-helm-buffers-list)
  (register-command! 'helm-occur cmd-helm-occur))
