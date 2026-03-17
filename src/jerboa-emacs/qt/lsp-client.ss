;;; -*- Gerbil -*-
;;; LSP client for jerboa-emacs Qt (STUB)
(export lsp-start! lsp-stop! lsp-send-request! lsp-buffer-active?)
(import :std/sugar :jerboa-emacs/core)
(def (lsp-start! buf cmd) (void))
(def (lsp-stop! buf) (void))
(def (lsp-send-request! buf method params) #f)
(def (lsp-buffer-active? buf) #f)
