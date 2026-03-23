;;; -*- Gerbil -*-
;;; Helm commands for jemacs (Qt backend)
;;;
;;; Qt-specific overrides for helm commands that need the Qt renderer.
;;; Overrides cmd-helm-buffers-list and cmd-helm-occur from the TUI version.

(export
  qt-register-helm-commands!
  cmd-helm-buffers-list
  cmd-helm-occur)

(import :std/sugar
        :std/sort
        :std/srfi/13
        :chez-scintilla/constants
        :jerboa-emacs/core
        :jerboa-emacs/qt/sci-shim
        :jerboa-emacs/qt/buffer
        :jerboa-emacs/qt/window
        :jerboa-emacs/qt/echo
        :jerboa-emacs/helm
        :jerboa-emacs/helm-sources
        :jerboa-emacs/qt/helm-qt
        :jerboa-emacs/editor)

;;;============================================================================
;;; Qt Helm Buffers List
;;;============================================================================

(def (cmd-helm-buffers-list app)
  "List and switch buffers with Qt helm narrowing."
  (let* ((src (helm-source-buffers app))
         (session (make-new-session (list src) "*helm buffers*"))
         (result (helm-qt-run! session app)))
    (when (and result (string? result))
      (let* ((buf-name (let ((star-pos (string-contains result " *")))
                         (if star-pos
                           (substring result 0 star-pos)
                           (let ((space-pos (string-contains result "  ")))
                             (if space-pos
                               (substring result 0 space-pos)
                               result)))))
             (buf (buffer-by-name buf-name)))
        (when buf
          (let* ((ed (current-qt-editor app))
                 (fr (app-state-frame app)))
            (qt-buffer-attach! ed buf)
            (set! (qt-edit-window-buffer (qt-current-window fr)) buf)
            (echo-message! (app-state-echo app)
              (string-append "Switched to: " buf-name))))))))

;;;============================================================================
;;; Qt Helm Occur
;;;============================================================================

(def (cmd-helm-occur app)
  "Search lines in current buffer with Qt helm narrowing."
  (let* ((ed (current-qt-editor app))
         (echo (app-state-echo app)))
    (when ed
      (let* ((text-fn (lambda () (qt-plain-text-edit-text ed)))
             (src (helm-source-occur app text-fn))
             (session (make-new-session (list src) "*helm occur*"))
             (result (helm-qt-run! session app)))
        (when (and result (string? result))
          ;; Extract line number and go to it
          (let ((colon-pos (string-index result #\:)))
            (when colon-pos
              (let ((line-num (string->number (substring result 0 colon-pos))))
                (when line-num
                  (let ((pos (sci-send ed SCI_POSITIONFROMLINE (- line-num 1))))
                    (sci-send ed SCI_GOTOPOS pos)
                    (echo-message! echo
                      (string-append "Line " (number->string line-num)))))))))))))

;;;============================================================================
;;; Command registration
;;;============================================================================

(def (qt-register-helm-commands!)
  "Register Qt-specific helm command overrides."
  (register-command! 'helm-buffers-list cmd-helm-buffers-list)
  (register-command! 'helm-occur cmd-helm-occur))
