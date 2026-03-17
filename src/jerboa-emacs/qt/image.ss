;;; -*- Gerbil -*-
;;; Image display for jerboa-emacs Qt (STUB)
(export qt-display-image! qt-image-buffer? *image-buffer-state*)
(import :std/sugar :jerboa-emacs/core)
(def *image-buffer-state* (make-hash-table))
(def (qt-display-image! editor buf file-path) (void))
(def (qt-image-buffer? buf) #f)
