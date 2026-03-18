# jerboa-emacs

A Chez Scheme port of the jerboa-based Emacs-like text editor, featuring a TUI (terminal) backend and a Qt graphical frontend.

## Overview

jerboa-emacs is an Emacs-inspired editor built on top of:
- **[jerboa](https://github.com/jerboa-scheme)** — Chez Scheme runtime with Gerbil-compatible stdlib
- **[chez-scintilla](https://github.com/jafourni/chez-scintilla)** — Scintilla editor component FFI bindings
- **[jerboa-shell (jsh)](https://github.com/jafourni/jerboa-shell)** — POSIX shell interpreter
- **[chez-qt](https://github.com/jafourni/chez-qt)** — Qt 5/6 GUI bindings (Qt backend only)

The TUI backend runs in a terminal using Scintilla's text model. The Qt backend provides a full graphical interface.

## Dependencies

### Required (TUI backend)

| Dependency | Purpose | Location |
|------------|---------|----------|
| Chez Scheme ≥ 9.6 | Scheme runtime | system |
| jerboa | Gerbil-compat stdlib | `~/mine/jerboa` |
| jerboa-shell (jsh) | Shell interpreter | `~/mine/jerboa-shell` |
| gherkin | Scheme dialect library | `~/mine/gherkin` |
| chez-scintilla | Scintilla editor FFI | `~/mine/chez-scintilla` |
| chez-pcre2 | PCRE2 regex FFI | `~/mine/chez-pcre2` |

### Additional (Qt backend)

| Dependency | Purpose | Location |
|------------|---------|----------|
| Qt 5 or Qt 6 | GUI framework | system |
| QScintilla | Qt Scintilla widget | system |
| chez-qt | Qt FFI bindings | `~/mine/chez-qt` |

## Build

All commands run from the project root.

### Build library modules

```bash
make build
```

This runs `jerbuild` to translate `.ss` Gerbil-syntax source files in `src/` to Chez-compatible `.sls` library files in `lib/`. The build is incremental.

To force a full rebuild:

```bash
make rebuild
```

### Build the jerboa-shell (jsh) library

The shell interpreter must be compiled separately:

```bash
cd ~/mine/jerboa-shell
make jsh-compile
```

### Run (TUI mode)

```bash
make run
```

This builds and launches the terminal editor.

### Run (Qt mode)

```bash
make run-qt
```

Requires the Qt backend build (see below).

### Build Qt backend

```bash
make build-qt
```

The Qt backend consists of 45 modules in `src/jerboa-emacs/qt/` (~48,801 lines). All modules must be compiled after `make build`.

## Testing

### Run all standard tests

```bash
make test
```

This runs: test-tier0, test-tier2, test-tier3, test-tier4, test-tier5, test-org, test-extra.

### Run specific test suites

| Command | Description |
|---------|-------------|
| `make test-functional` | Functional dispatch chain tests (250 tests) |
| `make test-term-hang` | Subprocess/blocking behavior diagnostic (13 tests) |
| `make test-tier0` | Core data structures |
| `make test-tier2` | Buffer and window primitives |
| `make test-tier3` | Editor core operations |
| `make test-tier4` | Shell integration |
| `make test-tier5` | Full editor commands |
| `make test-org` | Org-mode subsystem |

### Environment for tests

The Makefile sets these automatically:

```
LD_LIBRARY_PATH = ~/mine/chez-pcre2:~/mine/chez-scintilla:~/mine/chez-qt:~/mine/jerboa-shell
CHEZ_SCINTILLA_LIB = ~/mine/chez-scintilla
CHEZ_PCRE2_LIB = ~/mine/chez-pcre2
```

## Source Layout

```
src/
  jerboa-emacs/
    core.ss           — App state, frame, window data types
    buffer.ss         — Buffer management
    editor-core.ss    — Core editor commands
    editor.ss         — Command registration
    editor-cmds-a.ss  — Commands A-M
    editor-cmds-b.ss  — Commands N-Z, git operations
    editor-cmds-c.ss  — Additional commands
    shell.ss          — Shell integration (jsh-based)
    subprocess.ss     — Non-blocking subprocess execution
    terminal.ss       — Terminal emulation
    keymap.ss         — Key binding system
    helm.ss           — Helm completion framework
    persist.ss        — Session persistence
    editor-extra-*.ss — Extended features (org, AI, VCS, media, etc.)
    qt/               — Qt graphical backend (45 modules)
lib/
  jerboa-emacs/       — Generated .sls files (DO NOT EDIT)
tests/
  test-functional.ss  — Dispatch chain integration tests
  test-term-hang.ss   — Subprocess blocking diagnostic
  test-tier*.ss       — Tiered unit tests
  test-org-*.ss       — Org-mode tests
```

## Architecture Notes

### jerbuild code generation

`.ss` files in `src/` use Gerbil-style syntax (`def`, `defstruct`, `:module/path` imports). The `jerbuild` tool (from jerboa) translates these to Chez Scheme `.sls` library files in `lib/`. **Never edit `.sls` files directly** — all changes go in `.ss` sources.

### Qt backend and port ordering

Chez Scheme's `open-process-ports` returns values in this order:

```scheme
(values write-stdin-port read-stdout-port read-stderr-port pid)
```

This differs from Gambit/Gerbil's `open-process`. All process I/O code uses this order.

### Shell integration

The `shell.ss` module embeds the `jsh` POSIX shell interpreter. The `subprocess.ss` module provides `run-process-interruptible` for non-blocking subprocess execution with C-g interrupt support — this is the recommended path for long-running commands.

Note: `gsh-capture` / `command-substitute` in jsh uses `open-output-file "/dev/fd/1"` which acquires a Chez port registry lock. Running this in a secondary thread can deadlock with Chez's scheduler. Use `run-process-interruptible` for subprocess output capture in threaded contexts.

### with-output-to-string

In Chez Scheme, `with-output-to-string` takes only a thunk:

```scheme
(with-output-to-string (lambda () (display-exception e)))
```

The Gerbil form `(with-output-to-string "" thunk)` is not valid in Chez.

## Key Variables (Makefile)

| Variable | Default | Description |
|----------|---------|-------------|
| `SCHEME` | `scheme` | Chez Scheme executable |
| `JERBOA` | `~/mine/jerboa` | jerboa library path |
| `JSH` | `~/mine/jerboa-shell/src` | jsh source path |
| `GHERKIN` | `~/mine/gherkin/src` | gherkin library path |

Override on the command line: `make SCHEME=/usr/local/bin/chez build`
