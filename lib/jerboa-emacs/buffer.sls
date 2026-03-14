#!chezscheme
(library (jerboa-emacs buffer)
  (export
    buffer-create!
    buffer-create-from-editor!
    buffer-kill!
    buffer-attach!)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (jerboa-emacs core)
          (chez-scintilla constants)
          (chez-scintilla scintilla))

  (define buffer-create!
    (case-lambda
      ((name editor)
       (buffer-create! name editor #f))
      ((name editor file-path)
       (let* ((doc (send-message editor SCI_CREATEDOCUMENT 0 0))
              (buf (make-buffer name file-path doc #f #f #f #f)))
         (buffer-list-add! buf)
         buf))))

  (define (buffer-create-from-editor! name editor)
    (let ((doc (send-message editor SCI_GETDOCPOINTER)))
      (send-message editor SCI_ADDREFDOCUMENT 0 doc)
      (let ((buf (make-buffer name #f doc #f #f #f #f)))
        (buffer-list-add! buf)
        buf)))

  (define (buffer-kill! editor buf)
    (send-message editor SCI_RELEASEDOCUMENT 0 (buffer-doc-pointer buf))
    (buffer-list-remove! buf))

  (define (buffer-attach! editor buf)
    (send-message editor SCI_SETDOCPOINTER 0 (buffer-doc-pointer buf))
    (run-hooks! 'post-buffer-attach-hook editor buf))

) ;; end library
