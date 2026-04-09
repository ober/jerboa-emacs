#!chezscheme
;; Compile chez-ssl library
(import (chezscheme))
(compile-imported-libraries #t)
(import (chez-ssl))
