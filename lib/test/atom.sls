#!chezscheme
(library (test atom)
  (export test-it)
  (import (chezscheme)
          (std misc atom))
  (define (test-it) (atom? (atom 42))))
