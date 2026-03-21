#!chezscheme
(import (chezscheme))
(parameterize ((compile-imported-libraries #t))
  (compile-library "std/repl.sls"))
