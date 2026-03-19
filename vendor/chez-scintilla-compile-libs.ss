;;; compile-libs.ss — Compile chez-scintilla libraries for static build
;;; Only constants is actually needed (ffi is compiled to ensure static-build? check works)
(import (chez-scintilla ffi) (chez-scintilla constants))
