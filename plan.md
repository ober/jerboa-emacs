# Jerboa-Emacs Feature Parity Plan

**Goal:** Bring jerboa-emacs (Chez Scheme port) to full feature parity with gerbil-emacs (Gerbil Scheme original).

**Date:** 2026-03-17

---

## Executive Summary

| Category | gerbil-emacs | jerboa-emacs | Gap |
|----------|-------------|--------------|-----|
| Core modules | 65 files | 65 files | ✅ Complete |
| Qt backend | 46 files (~50k lines) | 0 files | ❌ Missing |
| Test files | 30 files | 27 files | ⚠️ Partial |
| Total lines | ~88k | ~65k | ~23k lines |

The TUI (terminal) backend is complete. The primary gap is the **Qt graphical frontend** (~50k lines across 46 modules).

---

## Phase 1: Qt Backend Infrastructure (Priority: High)

### 1.1 Create Qt Directory Structure

```bash
mkdir -p src/jerboa-emacs/qt
```

### 1.2 Port Core Qt Modules (in order)

These modules must be ported first as others depend on them:

| Module | Lines | Description | Dependencies |
|--------|-------|-------------|--------------|
| `qt/sci-shim.ss` | 536 | QScintilla compatibility layer | chez-qt, chez-scintilla |
| `qt/keymap.ss` | ~200 | Qt-specific key handling | sci-shim |
| `qt/buffer.ss` | 65 | Qt buffer wrapper | sci-shim |
| `qt/window.ss` | 567 | Qt window management | buffer, keymap |
| `qt/modeline.ss` | ~150 | Qt modeline widget | window |
| `qt/echo.ss` | ~200 | Qt echo area/minibuffer | window |
| `qt/highlight.ss` | ~300 | Qt syntax highlighting | sci-shim |

**Porting Instructions:**

1. Copy the Gerbil source file from `~/mine/gerbil-emacs/qt/`
2. Convert Gerbil syntax to Chez Scheme:
   - `def` → `define` (or keep with `(std sugar)`)
   - `defstruct` → `define-record-type` or use jerboa macros
   - `:module/path` imports → `(module path)` library imports
   - `begin-ffi` blocks → `foreign-procedure` with C shim .so files
   - `displayln` → `(display ...) (newline)`
   - `with-catch` → `guard` or `with-exception-handler`
3. Update library declaration: `(library (jerboa-emacs qt module-name) ...)`
4. Test compilation: `scheme --libdirs lib --script test-file.ss`

### 1.3 Port Command Modules (~35 files)

These implement editor commands for the Qt backend:

```
commands-core.ss, commands-core2.ss     # Basic editing
commands-edit.ss, commands-edit2.ss     # Text manipulation
commands-search.ss, commands-search2.ss # Search/replace
commands-file.ss, commands-file2.ss     # File operations
commands-sexp.ss, commands-sexp2.ss     # S-expression editing
commands-shell.ss, commands-shell2.ss   # Shell integration
commands-vcs.ss, commands-vcs2.ss       # Git/VCS integration
commands-ide.ss, commands-ide2.ss       # IDE features
commands-modes.ss, commands-modes2.ss   # Major/minor modes
commands-config.ss, commands-config2.ss # Configuration
commands-aliases.ss, commands-aliases2.ss
commands-parity.ss through commands-parity5.ss
commands-lsp.ss                         # LSP protocol
commands.ss                             # Facade module
```

### 1.4 Port Specialized Qt Modules

| Module | Lines | Description |
|--------|-------|-------------|
| `qt/lsp-client.ss` | 595 | Language Server Protocol client |
| `qt/magit.ss` | ~800 | Git interface (magit-like) |
| `qt/image.ss` | ~300 | Image display support |
| `qt/helm-qt.ss` | ~400 | Helm framework for Qt |
| `qt/helm-commands.ss` | ~300 | Helm command definitions |
| `qt/snippets.ss` | ~200 | Code snippets |
| `qt/menubar.ss` | ~400 | Qt menubar integration |
| `qt/app.ss` | 1289 | Qt application lifecycle |
| `qt/main.ss` | ~100 | Qt executable entry point |

---

## Phase 2: Dependencies (Priority: High)

### 2.1 Required Chez Scheme Packages

The Qt backend requires Chez Scheme ports of these Gerbil packages:

| Gerbil Package | Chez Port Needed | Status |
|----------------|------------------|--------|
| `gerbil-qt` | `chez-qt` | Check if exists |
| `gerbil-scintilla` | `chez-scintilla` | ✅ Exists (referenced in Makefile) |
| `gerbil-litehtml` | `chez-litehtml` | Needed for HTML rendering |

**Action:** Verify `chez-qt` exists at `~/mine/chez-qt` or port it.

### 2.2 FFI Shim Libraries

Create C shim libraries for Qt FFI (similar to `support/pty_shim.c`):

```bash
# In support/ directory:
qt_shim.c      # Qt widget bindings
sci_shim.c     # QScintilla bindings (may exist in chez-scintilla)
litehtml_shim.c # litehtml bindings
```

---

## Phase 3: Build System Updates (Priority: Medium)

### 3.1 Update Makefile

Add Qt build targets:

```makefile
# Add to Makefile
QT_MODULES = qt/sci-shim qt/keymap qt/buffer qt/window qt/modeline \
             qt/echo qt/highlight qt/app qt/main ...

build-qt: build
	$(JERBUILD) src/jerboa-emacs/qt/ lib/jerboa-emacs/qt/

run-qt: build-qt
	$(SCHEME) $(LIBDIRS) --script qt-main.ss

test-qt-functional:
	$(SCHEME) $(LIBDIRS) --script tests/test-qt-functional.ss
```

### 3.2 Add Qt Library Dependencies

Update `LIBDIRS` in Makefile:

```makefile
CHEZ_QT = $(HOME)/mine/chez-qt/src
LIBDIRS = --libdirs lib:...:$(CHEZ_QT)
export LD_LIBRARY_PATH := ...:$(HOME)/mine/chez-qt:$(LD_LIBRARY_PATH)
```

### 3.3 Create manifest.ss

```scheme
;; manifest.ss
(define version-manifest
  '(("" . "0.1.0")
    ("Jerboa" . "master")
    ("Chez Scheme" . "10.x")))
```

---

## Phase 4: Test Porting (Priority: Medium)

### 4.1 Missing Test Files

Port these test files from gerbil-emacs:

| Test File | Status in jerboa-emacs |
|-----------|------------------------|
| `emacs-test.ss` | Missing - port to `tests/test-emacs.ss` |
| `functional-test.ss` | Missing - port to `tests/test-functional.ss` |
| `lsp-functional-test.ss` | Missing - needs Qt backend first |
| `lsp-protocol-test.ss` | Missing - needs LSP client first |
| `qt-functional-test.ss` | Missing - needs Qt backend first |
| `qt-highlight-test.ss` | Missing - needs Qt backend first |
| `term-hang-test.ss` | Missing - port for terminal testing |

### 4.2 Test Naming Convention

jerboa-emacs uses `test-*.ss` prefix; gerbil-emacs uses `*-test.ss` suffix.
Maintain jerboa-emacs convention when porting.

---

## Phase 5: Documentation (Priority: Low)

### 5.1 Update README.md

Add:
- Qt backend installation instructions
- Dependencies list
- Build instructions for both TUI and Qt modes

### 5.2 Create CLAUDE.md

Add development guidance file (like gerbil-emacs has).

---

## Implementation Order

### Sprint 1: Foundation (Week 1-2)
1. [ ] Verify/create chez-qt package
2. [ ] Port `qt/sci-shim.ss` 
3. [ ] Port `qt/keymap.ss`
4. [ ] Port `qt/buffer.ss`
5. [ ] Update Makefile with Qt targets

### Sprint 2: Window System (Week 3-4)
1. [ ] Port `qt/window.ss`
2. [ ] Port `qt/modeline.ss`
3. [ ] Port `qt/echo.ss`
4. [ ] Port `qt/highlight.ss`
5. [ ] Basic Qt window test

### Sprint 3: Commands Part 1 (Week 5-6)
1. [ ] Port `qt/commands-core.ss` and `qt/commands-core2.ss`
2. [ ] Port `qt/commands-edit.ss` and `qt/commands-edit2.ss`
3. [ ] Port `qt/commands-file.ss` and `qt/commands-file2.ss`
4. [ ] Port `qt/commands-search.ss` and `qt/commands-search2.ss`

### Sprint 4: Commands Part 2 (Week 7-8)
1. [ ] Port remaining command modules
2. [ ] Port `qt/commands.ss` (facade)
3. [ ] Port `qt/helm-qt.ss` and `qt/helm-commands.ss`

### Sprint 5: Advanced Features (Week 9-10)
1. [ ] Port `qt/lsp-client.ss`
2. [ ] Port `qt/commands-lsp.ss`
3. [ ] Port `qt/magit.ss`
4. [ ] Port `qt/image.ss`

### Sprint 6: Application (Week 11-12)
1. [ ] Port `qt/menubar.ss`
2. [ ] Port `qt/app.ss`
3. [ ] Port `qt/main.ss`
4. [ ] Integration testing
5. [ ] Port Qt test files

---

## Syntax Conversion Reference

### Import Statements

```scheme
;; Gerbil
(import :gemacs/core
        :gerbil-qt/qt
        (only-in :gemacs/buffer buffer-name))

;; Chez Scheme (jerboa-emacs)
(import (jerboa-emacs core)
        (chez-qt qt)
        (only (jerboa-emacs buffer) buffer-name))
```

### Function Definitions

```scheme
;; Gerbil
(def (my-function arg1 arg2)
  (body ...))

;; Chez Scheme - keep def with (std sugar)
(def (my-function arg1 arg2)
  (body ...))
```

### Struct Definitions

```scheme
;; Gerbil
(defstruct point (x y))

;; Chez Scheme - use jerboa macros or define-record-type
(defstruct point (x y))  ; if (std sugar) provides it
;; OR
(define-record-type point
  (fields x y))
```

### Error Handling

```scheme
;; Gerbil
(with-catch
  (lambda (e) (handle-error e))
  (lambda () (risky-operation)))

;; Chez Scheme
(guard (e [else (handle-error e)])
  (risky-operation))
;; OR with jerboa compatibility
(with-catch (lambda (e) (handle-error e))
  (lambda () (risky-operation)))
```

### FFI Bindings

```scheme
;; Gerbil (begin-ffi block)
(begin-ffi (func-name)
  (c-declare "...")
  (define-c-lambda func-name (int string) int "c_func"))

;; Chez Scheme (separate .c file + foreign-procedure)
;; In support/module_shim.c:
;;   int c_func(int arg1, const char* arg2) { ... }
;; In .sls file:
(load-shared-object "support/module_shim.so")
(define func-name
  (foreign-procedure "c_func" (int string) int))
```

---

## Verification Checklist

For each ported module:

- [ ] File compiles without errors
- [ ] All exports are defined
- [ ] Imports resolve correctly
- [ ] FFI bindings work (if applicable)
- [ ] Unit tests pass (if tests exist)
- [ ] Integration with dependent modules works

---

## Notes for Implementers

1. **Start with sci-shim.ss** - It's the foundation for all Qt modules
2. **Test incrementally** - Compile and test each module before moving on
3. **Preserve API compatibility** - Function signatures should match gerbil-emacs
4. **Check chez-scintilla** - Many FFI bindings may already exist there
5. **Use existing patterns** - Look at `lib/jerboa-emacs/pty.sls` for FFI patterns
6. **Keep lib structure** - Generated .sls files go in `lib/jerboa-emacs/qt/`

---

## File Counts Summary

| Component | Files | Lines | Priority |
|-----------|-------|-------|----------|
| Qt core (sci-shim, window, buffer, etc.) | 10 | ~3,000 | P0 |
| Qt commands | 30 | ~35,000 | P1 |
| Qt advanced (LSP, magit, image) | 6 | ~12,000 | P2 |
| Tests | 8 | ~2,000 | P3 |
| **Total** | **54** | **~52,000** | |
