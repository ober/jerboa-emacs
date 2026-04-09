# TODO

## Static TUI binary

Add `make static-tui` target that produces a fully static `jemacs` TUI binary,
analogous to `make static-qt` / `jemacs-qt`.

**Status: Partially done**

- [x] `build-binary.ss` written (analogous to `build-binary-qt.ss` but for TUI)
- [x] `jemacs-main.c` exists and works (Linux memfd-based entry point)
- [x] `make binary` target — produces dynamic `./jemacs` (embeds all Scheme, links system libs)
  - Verified: `./jemacs --version` works
  - Requires `CHEZ_SCINTILLA_LIB` and `CHEZ_PCRE2_LIB` at runtime
- [ ] `make static-tui` — Docker-based Alpine musl static build
  - Target `linux-static-tui-docker` implemented in Makefile
  - Requires `jemacs-deps` Docker image (`make docker-deps`)
  - Scintilla/termbox/Lexilla archives rebuilt from source inside container
  - `SCI_VENDOR_SRC` must point to gerbil-scintilla vendor/ (default: auto-detected)

**To test `make static-tui`**: requires the `jemacs-deps` Docker image and
`SCI_VENDOR_SRC=$(HOME)/mine/gerbil-emacs/.gerbil/pkg/github.com/ober/gerbil-scintilla/vendor`.
