# TODO

## Static TUI binary

Add a `make static-tui` target that produces a fully static `jemacs` TUI binary,
analogous to `make static-qt` / `jemacs-qt`.

- Write `build-binary.ss` (analogous to `build-binary-qt.ss` but for TUI/ncurses)
- Add `make binary` target that runs `build-binary.ss` once the file exists
- Add `make static-tui` using the same Docker-based Alpine musl build as `static-qt`
- Output: `./jemacs` statically linked, no runtime `.so` dependencies
- Should work the same as `make run` but as a portable single binary

Note: `build-binary.ss` does not exist yet — `make binary` has been removed from
the Makefile until it is implemented.
