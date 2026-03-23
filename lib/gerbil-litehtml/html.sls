;;; Stub library for gerbil-litehtml/html
;;; Provides no-op implementations when litehtml is not installed.
;;; EWW browser will report errors at runtime instead of crashing at load time.

(library (gerbil-litehtml html)
  (export html-context-create
          html-container-create
          html-container-set-callbacks!
          html-container-set-viewport!
          html-container-set-media-type!
          html-container-set-media-color!
          html-document-create
          html-document-render!
          html-document-draw!
          html-document-destroy!
          html-container-destroy!)
  (import (chezscheme))

  (define (html-context-create . args) #f)
  (define (html-container-create . args) #f)
  (define (html-container-set-callbacks! . args) (void))
  (define (html-container-set-viewport! . args) (void))
  (define (html-container-set-media-type! . args) (void))
  (define (html-container-set-media-color! . args) (void))
  (define (html-document-create . args) #f)
  (define (html-document-render! . args) (void))
  (define (html-document-draw! . args) (void))
  (define (html-document-destroy! . args) (void))
  (define (html-container-destroy! . args) (void)))
