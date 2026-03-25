#!chezscheme
;;; (std os landlock) — Static build stub (landlock available via jerboa-landlock.o)
(library (std os landlock)
  (export
    landlock-available?
    landlock-abi-version
    landlock-enforce!
    &landlock-error make-landlock-error landlock-error?
    landlock-error-reason)

  (import (chezscheme))

  (define-condition-type &landlock-error &error
    make-landlock-error landlock-error?
    (reason landlock-error-reason))

  (define (landlock-available?) #f)
  (define (landlock-abi-version) 0)
  (define (landlock-enforce! . rules) (void))

  ) ;; end library
