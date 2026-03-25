# 50 Features to Close the Gap with GNU Emacs

> **Target:** jerboa-emacs (Chez Scheme, Qt backend)
> **Current state:** ~4,650 registered commands, ~115K lines of source
> **Status:** Most features already implemented with real logic

## Status Legend

| Status | Meaning |
|--------|---------|
| **DONE** | Fully implemented with real logic |
| **NEW** | Implemented in this feature sprint |
| **PARTIAL** | Works but needs polish |

---

## Core Editing & Input

### 1. Real electric-pair-mode — DONE
Auto-insert matching delimiters, auto-delete empty pairs, skip closing delimiter.
Per-major-mode pair tables. Toggle with `M-x electric-pair-mode`.
*Location:* `qt/app.ss:989-1055`, `qt/commands-file.ss:1281-1284`

### 2. Undo-tree persistent storage — NEW
Save undo history snapshots (up to 20 per file) to `~/.jemacs-undo/`. Uses v2 format
with timestamped text snapshots. Commands: `undo-history-save`, `undo-history-load`.
*Location:* `editor-extra-helpers.ss:1053-1150`

### 3. Real repeat-mode with transient keymaps — DONE
`*qt-transient-maps*` hash table with 'window-resize', 'zoom' maps. After `C-x o`,
`o` repeats `other-window` without prefix.
*Location:* `qt/commands-shell2.ss:1099-1108`, `editor-extra.ss:761`

### 4. Universal argument for all commands — DONE
`C-u` sets prefix arg stored in app-state. `get-prefix-arg` reads it. All commands
honor it. Digit arguments supported.
*Location:* `core.ss:1354-1545`

---

## Navigation & Movement

### 5. Real avy-goto with overlay hints — DONE
Avy jump with character hints overlaid on buffer.
*Location:* `qt/commands-search.ss`

### 6. Imenu with sidebar panel — PARTIAL
Currently uses echo-area narrowing list. No persistent Qt QTreeWidget sidebar yet.
*Location:* `qt/commands-search.ss`

### 7. Xref backend with LSP integration — DONE
`M-.` (goto-definition) and `M-?` (find-references) via LSP `textDocument/definition`
and `textDocument/references`. Falls back to grep.
*Location:* `qt/commands-lsp.ss:584+`

### 8. Breadcrumb navigation bar — NEW
`M-x breadcrumb` shows file path > function at point in echo area. Scans backward for
def/define/defun/defclass/defstruct forms.
*Location:* `qt/commands-shell2.ss`

---

## Search & Replace

### 9. Real-time isearch match count — DONE
Shows `[N matches]` in echo area during isearch, updating live.
Uses `SCI_INDICATORFILLRANGE` for all-match highlighting.
*Location:* `qt/commands-edit.ss`

### 10. Isearch yank-word-or-char — DONE
`C-w` yanks word at point into search string. `C-y` yanks from kill ring.
*Location:* `qt/commands-edit.ss`

### 11. Multi-file search-and-replace — DONE
`project-query-replace` across all project files with interactive y/n/! replace per match.
Saves modified buffers.
*Location:* `qt/commands-shell2.ss:1310-1356`

---

## Completion & Minibuffer

### 12. Corfu/Company auto-popup at point — DONE
Completion popup via Scintilla autocomplete. Merges LSP completions with buffer words.
*Location:* `qt/commands-edit.ss`

### 13. Orderless completion style — DONE
Space-separated tokens match in any order in helm multi-match engine.
*Location:* `qt/commands-edit.ss`, helm framework

### 14. Marginalia annotations everywhere — DONE
Metadata annotations in completion candidates: keybindings in M-x, file sizes, modes.
*Location:* `editor-extra-modes.ss`

### 15. Embark context actions — DONE
`C-;` opens action menu for candidate at point with per-category dispatch.
*Location:* `qt/commands-parity.ss`

---

## Buffer & Window Management

### 16. Real ibuffer with filtering — DONE
Interactive buffer list with mark/unmark, filter by mode/name/size, sort, bulk operations.
*Location:* `qt/commands-parity.ss:1342-1362`

### 17. Winner-mode with real state tracking — DONE
`winner-undo`/`winner-redo` saves and restores window configurations with config history.
*Location:* `qt/commands-core.ss:135-157`

### 18. Tab-bar with visual buffer tabs — DONE
Qt tab bar with `*tab-bar-widget*`, buffer tabs, toggle command.
*Location:* `qt/app.ss:416-419`

### 19. Dedicated window display rules — NEW
`display-buffer-alist` equivalent with configurable rules (same-window, other-window,
bottom-window). Default rules for compilation, help, grep, magit.
Commands: `display-buffer-add-rule`, `display-buffer-list-rules`.
*Location:* `qt/commands-shell2.ss`

---

## File Operations

### 20. Auto-revert with file-notify — DONE
File change detection with auto-revert for unmodified buffers.
*Location:* `qt/commands.ss`

### 21. Project-aware find-file with fd — DONE
`project-find-file` using `fd` for fast recursive discovery. Fuzzy matching on
relative paths. Excludes `.git/`, `node_modules/`.
*Location:* `qt/commands-search.ss`

### 22. Sudo-edit with privilege escalation — DONE
`cmd-sudo-write` via `sudo tee`, `cmd-sudo-edit` via `sudo cat`. Real file operations.
*Location:* `editor-advanced.ss:1275+`

### 23. EditorConfig real support — DONE
Parses `.editorconfig` files and applies indent_style, indent_size, tab_width,
end_of_line, trim_trailing_whitespace, insert_final_newline.
*Location:* `qt/commands.ss:248-260`

---

## Dired (Directory Editor)

### 24. Dired async file operations — DONE
`cmd-dired-async-copy`, `cmd-dired-async-move` for background file operations.
*Location:* `qt/commands.ss:1768-1769`

### 25. Dired image thumbnails — DONE
Image file detection, Qt `QPixmap` inline display for image files in dired.
*Location:* `qt/commands-edit.ss:1006-1020`, `editor-extra-helpers.ss:1155+`

---

## Version Control / Magit

### 26. Magit hunk-level staging with diff display — DONE
Inline diffs per file in magit status, navigate hunks with `n/p`, stage individual
hunks with `s` via `git apply --cached`.
*Location:* `qt/commands-ide.ss:483-550`

### 27. Magit commit buffer with diff preview — DONE
`c c` opens `*Magit: Commit*` buffer with staged diff visible below.
`C-c C-c` commits, `C-c C-k` aborts. Shows diff stats in header.
*Location:* `qt/commands-ide.ss:554-670`

### 28. Magit log with graph — NEW
`git log --graph --oneline --decorate --all -50` with visual graph rendering.
*Location:* `qt/commands-ide.ss:415-417`

### 29. Git-gutter real-time indicators — DONE
Added/modified/deleted line indicators in left margin via Scintilla markers.
*Location:* `qt/commands-vcs.ss`

### 30. Forge: PR review and creation — DONE
Browse GitHub PRs/issues via `gh` CLI. List PRs, view details, create PRs.
Qt-specific: `forge-browse-pr` with async diff display, `forge-pr-diff` with
syntax-highlighted diff view, `forge-browse-pr-at-point` opens in browser.
*Location:* `editor-extra-regs.ss:2183+`, `qt/commands-shell2.ss` (NEW Qt versions)

---

## Org-mode

### 31. Org-agenda with interactive commands — DONE
Daily/weekly agenda scanning SCHEDULED/DEADLINE timestamps. Navigate entries,
toggle TODO, jump to source.
*Location:* `org-agenda.ss` (439 lines)

### 32. Org-capture with template selection — DONE
`C-c c` shows template list, fill capture buffer, `C-c C-c` files to target.
Supports `%?`, `%U`, `%f` template escapes.
*Location:* `qt/commands-parity.ss:193-245`

### 33. Org-babel execute with real output — DONE
`C-c C-c` on source block executes code and inserts `#+RESULTS:`.
Supports shell, python, scheme.
*Location:* `qt/commands-parity.ss:733+`

### 34. Org table spreadsheet formulas — DONE
`#+TBLFM:` with column formulas. Table parsing, cell navigation,
`org-table-parse-tblfm`, `org-table-eval-formula`.
*Location:* `org-table.ss` (670 lines)

### 35. Org-export to HTML/PDF/Markdown — DONE
Export dispatcher with html, markdown, latex, text backends.
Inline markup conversion, block structure, heading hierarchy.
*Location:* `org-export.ss` (695 lines)

---

## Programming Support

### 36. Tree-sitter real integration — DONE
Full FFI bindings to tree-sitter C library. Incremental parsing, highlight capture,
per-buffer parser state. 19 style IDs mapped from capture names.
*Location:* `treesitter.ss` (486 lines), `qt/highlight.ss`

### 37. Flycheck with real linter subprocess — DONE
Runs language-specific linters with squiggly underline display via Scintilla indicators.
*Location:* `qt/commands-lsp.ss`

### 38. Compilation error navigation — DONE
`M-g n`/`M-g p` jump to next/previous error. Parses `file:line:col` patterns,
jumps to source, highlights error line.
*Location:* `qt/commands-search.ss`

### 39. DAP debugger with real GDB/MI — PARTIAL
Debug REPL exists for interactive debugging. GDB/MI protocol support present but
not a full DAP framework yet.
*Location:* `debug-repl.ss`

### 40. Eldoc with real function signatures — DONE
LSP `signatureHelp` displayed in echo area on cursor movement.
*Location:* `qt/commands-lsp.ss:875+`

---

## LSP (Language Server Protocol)

### 41. LSP semantic token highlighting — DONE
`textDocument/semanticTokens` with token-type-specific Scintilla indicators.
*Location:* `qt/commands-lsp.ss`

### 42. LSP code actions quick-fix — DONE
Shows available code actions, apply workspace edits.
*Location:* `qt/commands-lsp.ss`

### 43. LSP rename with preview — DONE
`textDocument/rename` with prompt for new name, applies text edits.
*Location:* `qt/commands-lsp.ss:584+`

---

## Shell & Terminal

### 44. Vterm with full ANSI/xterm emulation — DONE
Real terminal emulator: 256 colors, cursor positioning, alternate screen buffer.
*Location:* `terminal.ss`, `qt/commands-shell.ss`

### 45. Multi-vterm with per-project terminals — NEW
`project-vterm` creates project-associated terminal buffers. `project-vterm-toggle`
cycles between project terminals. Buffer names: `*term:project-name*`.
*Location:* `qt/commands-shell2.ss`, `qt/commands-config.ss` (existing multi-term)

### 46. Shell command on region with output — DONE
`M-|` pipes region through shell command. Replace mode available.
*Location:* `qt/commands-search.ss:1309+`

---

## AI Integration

### 47. Claude chat with streaming — DONE
`M-x claude-chat` opens `*AI Chat*` buffer. Spawns `claude -p` subprocess,
streams responses incrementally via char-ready polling. `--continue` for context.
*Location:* `chat.ss` (118 lines), `qt/commands-edit.ss:904-952`

### 48. Copilot inline suggestions — DONE
OpenAI API integration for code completion. `cmd-copilot-complete`, `cmd-copilot-accept`.
Language detection from file extension. Shows in echo area (TUI) or inline (Qt).
*Location:* `editor-extra-ai.ss` (634 lines)

---

## Themes & Display

### 49. Real theme engine with face definitions — DONE
Named faces with foreground/background/bold/italic/underline. Theme files.
`M-x load-theme` applies globally via Scintilla style abstraction layer.
*Location:* `qt/commands-shell2.ss` (theme system), `persist.ss`

### 50. Modeline with rich status — DONE
Encoding, line ending, cursor position, buffer %, major mode, minor mode indicators
(LSP, flycheck errors, git branch).
*Location:* `qt/modeline.ss`

---

## Summary

| Status | Count | Features |
|--------|-------|----------|
| **DONE** | 42 | Already fully implemented |
| **NEW** | 6 | Implemented in features sprint: #2, #8, #19, #28, #30 (Qt), #45 |
| **PARTIAL** | 2 | #6 (imenu sidebar), #39 (DAP debugger) |

**Total: 48/50 features fully working, 2 partial.**
