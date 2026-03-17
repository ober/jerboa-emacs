;;; -*- Gerbil -*-
;;; Qt echo area/minibuffer for jerboa-emacs
;;;
;;; Ported from gerbil-emacs/qt/echo.ss (STUB VERSION)
;;; Full implementation: 692 lines - to be completed in later sprint

(export qt-echo-init!
        qt-echo-message!
        qt-echo-clear!
        qt-echo-read-string
        qt-echo-read-file
        qt-echo-read-buffer
        qt-echo-yes-or-no?
        qt-echo-completing-read)

(import :std/sugar
        :jerboa-emacs/qt/sci-shim
        :jerboa-emacs/core)

;; STUB: Echo area operations
(def (qt-echo-init! frame)
  (void))

(def (qt-echo-message! app msg)
  (displayln msg))

(def (qt-echo-clear! app)
  (void))

(def (qt-echo-read-string app prompt (initial ""))
  initial)

(def (qt-echo-read-file app prompt (default #f))
  default)

(def (qt-echo-read-buffer app prompt)
  "")

(def (qt-echo-yes-or-no? app prompt)
  #t)

(def (qt-echo-completing-read app prompt candidates)
  (if (null? candidates) "" (car candidates)))
