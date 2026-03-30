# Jemacs vs GNU Emacs — Feature Comparison

> **Last updated:** 2026-03-27
> **Jemacs version:** features (87a8177)
> **Compared against:** GNU Emacs 29.x / 30.x feature set
> **Command parity:** 2268+ commands registered in both TUI and Qt layers (zero gap)

## Status Legend

| Symbol              | Meaning                                                              |
|---------------------|----------------------------------------------------------------------|
| :white_check_mark:  | **Full** — Feature-complete, comparable to Emacs                     |
| :large_blue_circle: | **Substantial** — Most functionality works, some gaps                |
| :yellow_circle:     | **Partial** — Core works, significant gaps remain                    |
| :orange_circle:     | **Minimal** — Basic scaffolding, limited use                         |
| :red_circle:        | **Stub/Missing** — Registered but non-functional, or absent entirely |

---

## Table of Contents

1. [Core Editing](#1-core-editing)
2. [Navigation](#2-navigation)
3. [Search & Replace](#3-search--replace)
4. [Kill, Yank & Clipboard](#4-kill-yank--clipboard)
5. [Undo System](#5-undo-system)
6. [Marks & Regions](#6-marks--regions)
7. [Registers & Bookmarks](#7-registers--bookmarks)
8. [Rectangle Operations](#8-rectangle-operations)
9. [Keyboard Macros](#9-keyboard-macros)
10. [Minibuffer & Completion](#10-minibuffer--completion)
11. [Buffer Management](#11-buffer-management)
12. [Window Management](#12-window-management)
13. [Frame / Display Management](#13-frame--display-management)
14. [File Operations](#14-file-operations)
15. [Dired (Directory Editor)](#15-dired-directory-editor)
16. [Version Control / Magit](#16-version-control--magit)
17. [Org-mode](#17-org-mode)
18. [Programming Support](#18-programming-support)
19. [LSP (Language Server Protocol)](#19-lsp-language-server-protocol)
20. [Syntax Highlighting & Themes](#20-syntax-highlighting--themes)
21. [Completion Frameworks](#21-completion-frameworks)
22. [Shell & Terminal](#22-shell--terminal)
23. [Spell Checking](#23-spell-checking)
24. [Text Transformation & Formatting](#24-text-transformation--formatting)
25. [S-expression / Paredit](#25-s-expression--paredit)
26. [Diff & Ediff](#26-diff--ediff)
27. [Project Management](#27-project-management)
28. [Help System](#28-help-system)
29. [Customization & Configuration](#29-customization--configuration)
30. [Package Management & Extensibility](#30-package-management--extensibility)
31. [Remote Editing (TRAMP)](#31-remote-editing-tramp)
32. [EWW (Web Browser)](#32-eww-web-browser)
33. [Calendar & Diary](#33-calendar--diary)
34. [Email (Gnus / mu4e / notmuch)](#34-email)
35. [IRC / Chat](#35-irc--chat)
36. [PDF / Document Viewing](#36-pdf--document-viewing)
37. [Treemacs / File Tree](#37-treemacs--file-tree)
38. [Multiple Cursors / iedit](#38-multiple-cursors--iedit)
39. [Snippets (YASnippet)](#39-snippets-yasnippet)
40. [Tab Bar & Workspaces](#40-tab-bar--workspaces)
41. [Accessibility](#41-accessibility)
42. [Performance & Large Files](#42-performance--large-files)
43. [AI / LLM Integration](#43-ai--llm-integration)
44. [Multi-Terminal (vterm)](#44-multi-terminal-vterm)
45. [Key Input Remapping](#45-key-input-remapping)
46. [DevOps / Infrastructure Modes](#46-devops--infrastructure-modes)
47. [Helm / Narrowing Framework](#47-helm--narrowing-framework)
48. [Personal Workflow Gap Analysis](#personal-workflow-gap-analysis)

---

## 1. Core Editing

| Feature                        | Status              | Notes                                           |
|--------------------------------|---------------------|-------------------------------------------------|
| Self-insert characters         | :white_check_mark:  | Full Unicode support via Scintilla              |
| Delete / Backspace             | :white_check_mark:  | `C-d`, `DEL`, `C-h`                             |
| Kill line (`C-k`)              | :white_check_mark:  | Kill to EOL, empty line kills newline           |
| Open line (`C-o`)              | :white_check_mark:  |                                                 |
| Newline & indent (`C-j`)       | :white_check_mark:  |                                                 |
| Transpose chars (`C-t`)        | :white_check_mark:  |                                                 |
| Transpose words (`M-t`)        | :white_check_mark:  |                                                 |
| Transpose lines (`C-x C-t`)    | :white_check_mark:  |                                                 |
| Transpose sexps                | :white_check_mark:  |                                                 |
| Join line (`M-j` / `M-^`)      | :white_check_mark:  |                                                 |
| Quoted insert (`C-q`)          | :white_check_mark:  |                                                 |
| Overwrite mode                 | :white_check_mark:  | Toggle via `<insert>`                           |
| Auto-fill mode                 | :white_check_mark:  | Automatic line wrapping at fill-column          |
| Electric pair mode             | :large_blue_circle: | Auto-pairing brackets/quotes, toggleable        |
| Indent line / region           | :white_check_mark:  | TAB dispatches: indent, complete, or org-expand |
| Aggressive indent mode         | :white_check_mark:  | Auto-reindent on closing delimiters and newlines |
| Universal argument (`C-u`)     | :white_check_mark:  | Numeric prefix for repeat/modify commands       |
| Digit arguments (`M-0`..`M-9`) | :white_check_mark:  |                                                 |
| Negative argument (`M--`)      | :white_check_mark:  |                                                 |
| Repeat (`C-x z`)               | :white_check_mark:  |                                                 |
| Repeat-mode (transient maps)   | :large_blue_circle: | 6 maps: window, buffer, error, undo, page, resize |

**Summary:** Core editing is feature-complete. All standard Emacs editing primitives work.

---

## 2. Navigation

| Feature                     | Status              | Notes                                        |
|-----------------------------|---------------------|----------------------------------------------|
| Char/word/line movement     | :white_check_mark:  | `C-f/b/n/p`, `M-f/b`, arrows                 |
| Beginning/end of line       | :white_check_mark:  | `C-a/e`, `Home/End`                          |
| Beginning/end of buffer     | :white_check_mark:  | `M-<`, `M->`                                 |
| Page up/down                | :white_check_mark:  | `C-v`, `M-v`, PgUp/PgDn                      |
| Scroll other window         | :white_check_mark:  | `M-g v`, `M-g V`                             |
| Recenter (`C-l`)            | :white_check_mark:  | Cycles top/center/bottom                     |
| Goto line (`M-g g`)         | :white_check_mark:  |                                              |
| Goto char (`M-g c`)         | :white_check_mark:  |                                              |
| Goto column                 | :white_check_mark:  |                                              |
| Goto matching paren         | :white_check_mark:  | `M-g m`                                      |
| Goto percent                | :white_check_mark:  | `M-g %` — jump to N% of buffer               |
| Forward/backward sentence   | :white_check_mark:  | `M-a`, `M-e`                                 |
| Forward/backward paragraph  | :white_check_mark:  | `M-{`, `M-}`                                 |
| Forward/backward sexp       | :white_check_mark:  | `M-g f/b`                                    |
| Back to indentation (`M-m`) | :white_check_mark:  |                                              |
| Imenu symbol navigation     | :large_blue_circle: | Works for many languages, no sidebar         |
| Which-function-mode         | :large_blue_circle: | Multi-language: Scheme, Python, C, Go, Rust, JS/TS |
| Avy jump (char/line/word)   | :large_blue_circle: | `avy-goto-char`, `avy-goto-line`             |
| Xref go-to-definition       | :large_blue_circle: | Works via grep fallback; LSP backend partial |
| Xref find references        | :large_blue_circle: | Grep-based                                   |
| Next/previous error         | :white_check_mark:  | `M-g n/p` navigates compilation errors       |
| Ace-window                  | :large_blue_circle: | Jump to window by label                      |
| Pop mark / mark ring        | :large_blue_circle: | Mark stack navigation                        |

**Summary:** Navigation is comprehensive. All standard movement commands plus extras like avy and ace-window.

---

## 3. Search & Replace

| Feature                       | Status             | Notes                                      |
|-------------------------------|--------------------|--------------------------------------------|
| Isearch forward/backward      | :white_check_mark: | `C-s`, `C-r` with wrap-around              |
| Isearch regexp                | :white_check_mark: | `C-M-s`                                    |
| Query replace                 | :white_check_mark: | `M-%` with y/n/!/q responses               |
| Query replace regexp          | :white_check_mark: | `C-M-%`                                    |
| Replace all (non-interactive) | :white_check_mark: |                                            |
| Occur                         | :white_check_mark: | `M-s o` — results buffer with line numbers |
| Multi-file occur              | :white_check_mark: |                                            |
| Grep (project-wide)           | :white_check_mark: | `rgrep`, `project-grep`, `counsel-grep`    |
| Grep results buffer           | :white_check_mark: | With next/prev error navigation            |
| Wgrep (edit grep results)     | :white_check_mark: | Edit matches in-place, save back to files  |
| Keep/flush lines              | :white_check_mark: | `M-s k`, `M-s f`                           |
| Count matches                 | :white_check_mark: | `M-s c`                                    |
| Isearch word mode             | :large_blue_circle: | `isearch-forward-word` searches for word at point |
| Isearch symbol mode           | :large_blue_circle: | `isearch-forward-symbol` searches for symbol at point |
| Search highlight all matches  | :green_circle:     | Qt: highlights all matches during isearch (current=cyan, others=yellow) |

**Summary:** Search is strong. Isearch with live multi-match highlighting, query-replace, occur, grep, and wgrep all work well.

---

## 4. Kill, Yank & Clipboard

| Feature | Status | Notes |
|---------|--------|-------|
| Kill line / region / word | :white_check_mark: | Full kill ring integration |
| Kill ring | :white_check_mark: | Stores history of kills |
| Yank (`C-y`) | :white_check_mark: | |
| Yank pop (`M-y`) | :white_check_mark: | Cycle through kill ring |
| Kill ring save (`M-w`) | :white_check_mark: | Copy without killing |
| Append next kill | :white_check_mark: | |
| Browse kill ring | :white_check_mark: | Interactive selection |
| System clipboard integration | :large_blue_circle: | Qt layer has clipboard; TUI limited |
| Zap to char (`M-z`) | :white_check_mark: | |
| Zap up to char | :white_check_mark: | |
| Kill whole line | :white_check_mark: | |
| Copy from above/below | :white_check_mark: | Copy character from line above/below |

**Summary:** Kill/yank system is complete with kill ring cycling and browsing.

---

## 5. Undo System

| Feature | Status | Notes |
|---------|--------|-------|
| Undo (`C-/`, `C-_`) | :white_check_mark: | |
| Redo (`M-_`) | :white_check_mark: | Linear redo |
| Undo grouping | :white_check_mark: | Consecutive edits grouped |
| Undo boundaries | :white_check_mark: | Commands create boundaries |
| Undo tree visualization | :white_check_mark: | `M-x undo-tree-visualize` with snapshot history |
| Persistent undo (across sessions) | :white_check_mark: | `undo-history-save` / `undo-history-load` to `~/.jemacs-undo/` |
| Selective undo (region) | :white_check_mark: | Undo within region, falls back to normal undo |

**Summary:** Undo/redo with tree visualization (`M-x undo-tree-visualize`), timestamped snapshots (`M-x undo-history`), and snapshot restore. No persistent undo or selective region undo.

---

## 6. Marks & Regions

| Feature | Status | Notes |
|---------|--------|-------|
| Set mark (`C-SPC`) | :white_check_mark: | |
| Exchange point and mark (`C-x C-x`) | :white_check_mark: | |
| Mark word / paragraph / defun / sexp | :white_check_mark: | |
| Select all (`C-x h`) | :white_check_mark: | |
| Narrow to region / widen | :white_check_mark: | |
| Transient mark mode | :large_blue_circle: | Region highlighting |
| Pop mark | :large_blue_circle: | Mark ring navigation |
| Rectangle mark mode | :white_check_mark: | Toggle with `C-x SPC` |

**Summary:** Mark and region system is solid.

---

## 7. Registers & Bookmarks

| Feature | Status | Notes |
|---------|--------|-------|
| Text to register | :white_check_mark: | `C-x r s` / `C-x r i` |
| Point to register / jump | :white_check_mark: | `C-x r SPC` / `C-x r j` |
| Window config to register | :white_check_mark: | Full multi-window state save/restore |
| Rectangle to register | :white_check_mark: | |
| Number registers (increment) | :white_check_mark: | `C-x r +` |
| Append/prepend to register | :white_check_mark: | |
| File to register | :large_blue_circle: | Save file path to register, jump back with `jump-to-register` |
| List registers | :large_blue_circle: | |
| Bookmark set / jump | :white_check_mark: | `C-x r m` / `C-x r b` |
| Bookmark list | :white_check_mark: | |
| Bookmark persistence | :white_check_mark: | `~/.jemacs-bookmarks` |
| Bookmark delete / rename | :white_check_mark: | |

**Summary:** Registers and bookmarks are comprehensive. All core types work including window configurations.

---

## 8. Rectangle Operations

| Feature | Status | Notes |
|---------|--------|-------|
| Kill rectangle | :white_check_mark: | `C-x r k` |
| Delete rectangle | :white_check_mark: | `C-x r d` |
| Yank rectangle | :white_check_mark: | `C-x r y` |
| Open rectangle | :white_check_mark: | `C-x r o` |
| String rectangle | :white_check_mark: | `C-x r t` — fill column with text |
| Number lines | :white_check_mark: | `C-x r n` |
| Clear rectangle | :white_check_mark: | |
| Rectangle to register | :white_check_mark: | |

**Summary:** Rectangle operations are feature-complete.

---

## 9. Keyboard Macros

| Feature | Status | Notes |
|---------|--------|-------|
| Start recording (`F3` / `C-x (`) | :white_check_mark: | |
| Stop recording (`F4` / `C-x )`) | :white_check_mark: | |
| Execute last macro (`F4` / `C-x e`) | :white_check_mark: | |
| Named macros | :white_check_mark: | `M-x name-last-kbd-macro`, `M-x call-named-kbd-macro` with narrowing |
| Macro counter | :white_check_mark: | `M-x kbd-macro-counter-insert` / `kbd-macro-counter-set` |
| Edit macro | :large_blue_circle: | `M-x edit-kbd-macro` shows macro events in buffer (TUI) |
| Save macros to file | :white_check_mark: | `M-x save-kbd-macros` / `load-kbd-macros` persists to `~/.jemacs-macros` |
| Execute with count prefix | :large_blue_circle: | `C-u` prefix arg for navigation (char/word/line), `universal-argument`, digit arguments |

**Summary:** Feature-rich macro system: recording/playback, named macros with save/load persistence, counter insert/set, macro viewer. Qt uses narrowing for macro selection.

---

## 10. Minibuffer & Completion

| Feature | Status | Notes |
|---------|--------|-------|
| M-x (execute-extended-command) | :white_check_mark: | Fuzzy matching command names |
| File name completion | :white_check_mark: | Tab completion in find-file |
| Buffer name completion | :white_check_mark: | Fuzzy matching in switch-buffer |
| Minibuffer history | :white_check_mark: | `M-p` / `M-n` in minibuffer |
| Recursive minibuffer | :white_check_mark: | `toggle-enable-recursive-minibuffers` flag |
| Vertico / Selectrum | :white_check_mark: | Mode toggles, uses narrowing framework for vertical completion |
| Orderless matching | :large_blue_circle: | Multi-match engine: space-separated AND tokens, `!` negation, `^` prefix |
| Marginalia (annotations) | :white_check_mark: | Annotator registry with `marginalia-annotate!`, command/buffer/file categories |
| Embark (actions on candidates) | :white_check_mark: | Action registry with `embark-define-action!`, describe/execute/find-file actions |
| Consult (enhanced commands) | :large_blue_circle: | `consult-ripgrep` (M-s r, narrowing), `consult-line`, `consult-buffer`, `consult-bookmark` |
| Icomplete / Fido mode | :white_check_mark: | `icomplete-mode` / `fido-mode` toggles |
| Savehist (persist history) | :large_blue_circle: | `~/.jemacs-history` |

**Summary:** Full completion framework: fuzzy matching, Vertico/Selectrum vertical modes, Marginalia annotations, Embark actions, Icomplete/Fido. Uses narrowing framework for candidate selection.

---

## 11. Buffer Management

| Feature | Status | Notes |
|---------|--------|-------|
| Switch buffer (`C-x b`) | :white_check_mark: | With fuzzy matching |
| Kill buffer (`C-x k`) | :white_check_mark: | Prompts to save modified |
| List buffers (`C-x C-b`) | :white_check_mark: | |
| Next/previous buffer | :white_check_mark: | `C-x <left>/<right>` |
| Bury buffer | :white_check_mark: | |
| Rename buffer | :white_check_mark: | |
| Clone buffer | :white_check_mark: | |
| Scratch buffer | :white_check_mark: | |
| Messages buffer | :white_check_mark: | `*Messages*` equivalent |
| ibuffer (advanced list) | :large_blue_circle: | Interactive: mark/delete/save/execute, filter by name, sort, goto buffer |
| Uniquify buffer names | :white_check_mark: | Emacs-style `filename<dir>` — renames both old and new same-name buffers |
| Indirect buffers | :large_blue_circle: | `clone-indirect-buffer` creates text copy with `<clone>` suffix |
| Buffer-local variables | :large_blue_circle: | `buffer-local-set!/get` per-buffer hash, used for major-mode, dir-locals, org settings |

**Summary:** Core buffer management works well. IBBuffer provides interactive mark/execute/filter/sort.

---

## 12. Window Management

| Feature | Status | Notes |
|---------|--------|-------|
| Split horizontal (`C-x 2`) | :white_check_mark: | |
| Split vertical (`C-x 3`) | :white_check_mark: | |
| Delete window (`C-x 0`) | :white_check_mark: | |
| Delete other windows (`C-x 1`) | :white_check_mark: | |
| Other window (`C-x o`) | :white_check_mark: | |
| Balance windows (`C-x +`) | :white_check_mark: | |
| Resize windows (`C-x ^`, `C-x {`, `C-x }`) | :white_check_mark: | |
| Windmove (directional) | :white_check_mark: | `S-left/right/up/down` arrow key navigation between windows |
| Winner mode (undo/redo) | :white_check_mark: | `winner-undo`, `winner-redo` |
| Ace-window (jump by label) | :large_blue_circle: | |
| Swap buffers between windows | :white_check_mark: | |
| Golden ratio mode | :white_check_mark: | Auto-resize focused window |
| Dedicated windows | :white_check_mark: | `M-x toggle-window-dedicated` prevents buffer replacement |
| Side windows | :white_check_mark: | Toggle side panel via split (display-buffer-in-side-window) |
| Window purpose | :white_check_mark: | `set-window-dedicated`, `toggle-window-dedicated` with buffer-type dedication |
| Follow mode | :white_check_mark: | Synchronized scrolling across windows |

**Summary:** Window management is strong. Splitting, resizing, winner-mode, ace-window, window purpose/dedication all work.

---

## 13. Frame / Display Management

| Feature | Status | Notes |
|---------|--------|-------|
| Single frame (Qt window) | :white_check_mark: | |
| Multiple frames | :large_blue_circle: | Virtual frame management: `make-frame`/`delete-frame`/`other-frame`/`suspend-frame`, frame count tracking |
| Fullscreen toggle | :large_blue_circle: | Real toggle via window-state detection (fullscreen ↔ normal) |
| Font size (zoom) | :white_check_mark: | `C-=`, `C--`, `C-x C-0` |
| Font family selection | :large_blue_circle: | Configurable |
| Menu bar | :large_blue_circle: | Qt menu bar with File/Edit/View/etc |
| Tool bar | :yellow_circle: | `tool-bar-mode` registered; uses M-x for commands |
| Scroll bar | :large_blue_circle: | Real toggle via Scintilla SCI_SETVSCROLLBAR/SCI_SETHSCROLLBAR |
| Mode line (status bar) | :white_check_mark: | Shows mode, file, position, modified status |
| Tab bar | :green_circle: | Qt visual buffer tab bar + workspace tabs (both layers) |
| Header line | :white_check_mark: | Toggle header line display (file path breadcrumb) |
| Fringe indicators | :large_blue_circle: | Git-gutter fringe markers (green=add, blue=mod, red=del) via Scintilla margin, both TUI + Qt |
| Display tables | :white_check_mark: | `set-display-table-entry` / `describe-display-table` |
| Fill-column indicator | :white_check_mark: | Visual vertical line via Scintilla edge mode (TUI + Qt) |
| Goto-address-mode | :white_check_mark: | URL detection and highlighting with Scintilla indicators (TUI + Qt) |
| Subword-mode | :white_check_mark: | CamelCase-aware word navigation: forward, backward, kill (TUI + Qt) |
| Rainbow delimiters | :white_check_mark: | Color-coded parentheses/brackets via Scintilla indicators |
| Pulse-on-jump | :white_check_mark: | Auto-flash landing line after >5-line jumps (INDIC_FULLBOX), toggleable |
| Visual-line-mode | :white_check_mark: | Word wrap via Scintilla SCI_SETWRAPMODE (TUI + Qt) |
| Whitespace-mode | :white_check_mark: | Show/hide whitespace and EOL markers via Scintilla (TUI + Qt) |
| Which-key mode | :white_check_mark: | Shows available keybindings after prefix key delay (TUI + Qt) |

**Summary:** Single-frame Qt application. No multi-frame support. Display features work well including fill-column indicator, URL highlighting, pulse-on-jump, visual-line-mode, whitespace display, and which-key hints.

---

## 14. File Operations

| Feature | Status | Notes |
|---------|--------|-------|
| Find file (`C-x C-f`) | :white_check_mark: | With completion |
| Find file other window (`C-x 4 f`) | :white_check_mark: | |
| Save buffer (`C-x C-s`) | :white_check_mark: | |
| Save as (`C-x C-w`) | :white_check_mark: | |
| Save some buffers (`C-x s`) | :white_check_mark: | Prompts for each modified |
| Revert buffer | :white_check_mark: | Reload from disk |
| Auto-revert mode | :white_check_mark: | Auto-reverts unmodified buffers when files change on disk |
| Auto-save mode | :white_check_mark: | 30s timer writes to `#file#`, per-buffer toggle, recover-file |
| Backup files | :large_blue_circle: | Creates `file~` backup on first save, toggle with `M-x toggle-backup-files` |
| Recent files (`C-x C-r`) | :white_check_mark: | |
| Find file at point | :white_check_mark: | |
| Find alternate file | :white_check_mark: | |
| Insert file | :white_check_mark: | |
| Copy/rename file | :white_check_mark: | |
| Sudo write | :white_check_mark: | Write as root |
| File local variables | :large_blue_circle: | Dir-locals via `.jemacs-config` |
| Find file literally | :large_blue_circle: | Opens file with syntax highlighting disabled (SCLEX_NULL) |
| File encoding detection | :large_blue_circle: | UTF-8 default; `set-buffer-file-coding-system` with 15 encodings, `revert-buffer-with-coding-system`, per-buffer encoding storage |
| Line ending conversion | :white_check_mark: | Unix/DOS/Mac detection and conversion |
| Desktop save/restore | :white_check_mark: | Persist and restore session (open buffers, positions) across restarts |

**Summary:** File operations are comprehensive. Find, save, revert, auto-revert, recent files, desktop save/restore all work.

---

## 15. Dired (Directory Editor)

| Feature | Status | Notes |
|---------|--------|-------|
| Directory listing | :white_check_mark: | File metadata, permissions, sizes |
| Open file/directory | :white_check_mark: | Enter to open |
| Navigate up (`^`) | :white_check_mark: | |
| Create directory | :white_check_mark: | |
| Mark / unmark files | :white_check_mark: | Mark by regexp |
| Delete single file | :white_check_mark: | With confirmation |
| Rename single file | :white_check_mark: | |
| Copy single file | :white_check_mark: | |
| Chmod | :white_check_mark: | |
| Sort toggle | :white_check_mark: | Name/date |
| Hide details | :white_check_mark: | |
| Hide dotfiles | :white_check_mark: | |
| Refresh | :white_check_mark: | |
| Batch delete (marked) | :white_check_mark: | Delete all marked files with confirmation |
| Batch rename (marked) | :white_check_mark: | Move/rename marked files to destination |
| Batch copy (marked) | :white_check_mark: | Copy marked files to destination |
| Mark by regexp | :white_check_mark: | Mark files matching pattern |
| Shell command on file | :large_blue_circle: | Runs command, shows output in buffer |
| Wdired (edit filenames) | :white_check_mark: | Edit mode with rename-on-commit |
| Image thumbnails | :white_check_mark: | `image-dired-display-thumbnail` / `image-dired-show-all-thumbnails` |
| Dired-x extensions | :large_blue_circle: | `find-dired` (custom args), `find-name-dired` (by filename pattern) — real `find` subprocess |
| Async operations | :white_check_mark: | `dired-async-copy`, `dired-async-move` |
| Virtual dired | :white_check_mark: | `virtual-dired` from file list, `dired-from-find` from glob |
| Dired subtree | :white_check_mark: | `M-x dired-subtree-toggle` for inline expansion |

**Summary:** Dired is **substantially complete**. Full listing with permissions/sizes, single-file and batch operations on marked files, wdired for inline renaming, find integration, inline subtree expansion, async copy/move. Missing: image thumbnails.

---

## 16. Version Control / Magit

| Feature | Status | Notes |
|---------|--------|-------|
| Git status display | :large_blue_circle: | Interactive status with inline diffs per file |
| Stage / unstage hunks | :large_blue_circle: | Hunk-level staging via `git apply --cached` |
| Stage / unstage files | :white_check_mark: | `s` to stage, `u` to unstage in status buffer |
| Commit with message | :large_blue_circle: | Dedicated `*Magit: Commit*` buffer with diff preview, C-c C-c / C-c C-k |
| Amend commit | :large_blue_circle: | `a` in magit opens commit buffer pre-filled with previous message |
| Push / pull | :large_blue_circle: | Upstream detection, auto-set with `-u`, remote selection via narrowing |
| Log viewing | :large_blue_circle: | Interactive log with date/author, Enter shows commit diff |
| Diff viewing | :large_blue_circle: | Shows staged + unstaged diffs for file at point |
| Branch operations | :large_blue_circle: | Checkout/create/delete with narrowing selection |
| Tag management | :large_blue_circle: | Create/list/delete/push tags with completion |
| Stash | :large_blue_circle: | Stash create + list + pop + show diff |
| Blame | :large_blue_circle: | `magit-blame`, `show-git-blame`, `vc-annotate` — real `git blame` with async output |
| Interactive rebase | :large_blue_circle: | Rebase with narrowing branch selection |
| Merge UI | :large_blue_circle: | Merge with narrowing branch selection |
| Cherry-pick | :large_blue_circle: | Interactive commit selection with narrowing |
| Revert commit | :large_blue_circle: | Interactive commit selection, `--no-edit` |
| Forge (PR/issue management) | :large_blue_circle: | List/view PRs and issues, create PRs via `gh` CLI |
| Diff-hl (gutter marks) | :large_blue_circle: | Git diff gutter indicators |
| Wgrep on grep results | :white_check_mark: | Edit and save back |
| Magit keymap | :white_check_mark: | 20 bindings: s/S/u/c/d/l/g/n/p/q/b/B/f/F/P/r/m/z/Z/k |
| VC generic backend | :white_check_mark: | Git backend: real `vc-annotate` (blame), `vc-diff-head`, `vc-log-file` (--follow), `vc-stash`/`vc-stash-pop`, `vc-revert`, `vc-dir` |

**Summary:** Magit has been significantly enhanced. The status buffer shows **inline diffs** per file. **Hunk-level staging/unstaging** works via `git apply --cached`. Branch operations (checkout, merge, rebase) use the **narrowing framework** for interactive selection. 20+ single-key bindings in the magit keymap. **Commit composition** uses a dedicated `*Magit: Commit*` buffer with diff preview and `C-c C-c`/`C-c C-k` keybindings. **Interactive log** shows date/author/subject with graph; pressing Enter shows the full commit diff with highlighting. Forge integration provides PR/issue listing and creation via `gh` CLI.

---

## 17. Org-mode

| Feature | Status | Notes |
|---------|--------|-------|
| Heading hierarchy | :white_check_mark: | `* / ** / ***` levels |
| Heading folding / cycling | :white_check_mark: | TAB cycles visibility |
| TODO states | :white_check_mark: | TODO/DONE cycling, custom keywords |
| Priority (`[#A]`, `[#B]`, `[#C]`) | :white_check_mark: | Set and cycle priorities |
| Tags | :white_check_mark: | Per-heading tags |
| Timestamps | :white_check_mark: | Active/inactive, SCHEDULED/DEADLINE |
| Properties | :white_check_mark: | Property drawers |
| Lists (ordered, unordered) | :large_blue_circle: | |
| Checkboxes | :white_check_mark: | Toggle `[ ]`/`[X]` |
| Links | :white_check_mark: | `[[url][description]]` format |
| Footnotes | :large_blue_circle: | `org-footnote-new` (insert ref+def), `org-footnote-goto-definition` (jump between ref/def) |
| **Tables** | :white_check_mark: | Create, align, row/col operations, sort, sum |
| Table formulas | :large_blue_circle: | Basic recalculate |
| Table CSV import/export | :white_check_mark: | |
| **Agenda** | :large_blue_circle: | Daily/weekly views, date filtering, tag search |
| Agenda interactive commands | :large_blue_circle: | Jump to source, toggle TODO from agenda |
| **Capture** | :large_blue_circle: | Templates with `%?/%U/%T/%f`, template selection, `*Org Capture*` buffer |
| Capture buffer (C-c C-c / C-c C-k) | :white_check_mark: | Interactive capture with finalize/abort keybindings |
| Refile | :large_blue_circle: | `M-x org-refile` with narrowing target selection (Qt) |
| **Babel** (code blocks) | :large_blue_circle: | 8 languages, execution, tangling |
| Babel session persistence | :white_check_mark: | `:session name` keeps persistent process, sentinel-based I/O |
| Babel :var evaluation | :white_check_mark: | Resolves named src blocks (executes) and tables (converts to data) |
| Babel :noweb expansion | :white_check_mark: | `<<block-name>>` refs expanded when `:noweb yes` |
| **Export** | :large_blue_circle: | HTML, Markdown, LaTeX, ASCII |
| Export footnotes/cross-refs | :white_check_mark: | `[fn:name]` refs, `<<target>>`/`[[#target]]` cross-refs, all 4 backends |
| Custom export backends | :white_check_mark: | Register via `org-export-register-backend!`, list with `org-export-list-backends` |
| **Clock tracking** | :large_blue_circle: | Clock-in/out, goto |
| Org-crypt | :large_blue_circle: | GPG symmetric encrypt/decrypt of org entry bodies (`org-encrypt-entry`, `org-decrypt-entry`) |
| Org-sort | :white_check_mark: | Sort child headings alphabetically under current heading |
| Heading promote/demote | :white_check_mark: | |
| Move subtree up/down | :white_check_mark: | |
| Template expansion (`<s TAB`) | :white_check_mark: | Source block templates |
| Sparse tree | :white_check_mark: | Regexp search, shows matching headings + parents |
| Column view | :white_check_mark: | Tabular display of heading level, title, TODO, priority |

**Summary:** Org-mode is one of jemacs's strongest features with substantial coverage of the core: headings, TODO, tables, babel, export, agenda, column view. Interactive agenda supports jump-to-source and TODO toggling. Refile with narrowing target selection. Sparse tree with regexp matching.

---

## 18. Programming Support

| Feature | Status | Notes |
|---------|--------|-------|
| Syntax highlighting | :white_check_mark: | Via Scintilla lexers |
| Auto-indentation | :large_blue_circle: | Language-aware for Lisp; basic for others |
| Code folding | :white_check_mark: | Toggle/fold-all/unfold-all |
| Show matching paren | :white_check_mark: | Highlight matching delimiter |
| Comment/uncomment | :white_check_mark: | `M-;`, `F11`/`F12` |
| S-expression navigation | :white_check_mark: | Forward/backward/up/down sexp |
| Compile command | :white_check_mark: | `C-x d` runs compile |
| Error navigation | :white_check_mark: | Next/prev error in compilation buffer |
| Flycheck (syntax checking) | :white_check_mark: | Multi-language: Chez Scheme (scheme), Python, JS/TS (eslint), Go, Shell (shellcheck), C/C++ (gcc), Ruby |
| Flymake | :large_blue_circle: | Delegates to flycheck; multi-language support |
| Eldoc (function signatures) | :large_blue_circle: | Echo area display |
| Xref (definitions) | :large_blue_circle: | Grep-based fallback |
| Xref (references) | :large_blue_circle: | Grep-based |
| Tags (ctags/etags) | :white_check_mark: | `visit-tags-table`, `find-tag` (M-.), `tags-apropos`, `pop-tag-mark` (M-*) |
| Imenu (symbol index) | :large_blue_circle: | Works for structured languages |
| Which-function mode | :large_blue_circle: | Multi-language: Scheme, Python, C, Go, Rust, JS/TS |
| Semantic analysis | :yellow_circle: | `semantic-mode` toggle in both layers |
| Tree-sitter integration | :yellow_circle: | `tree-sitter-mode` toggle — grammar-based parsing scaffolded |
| DAP (debug adapter) | :large_blue_circle: | Real GDB/MI integration: spawn, breakpoints, step-over/in/out, continue, REPL in both layers |
| Prog-mode hooks | :large_blue_circle: | `prog-mode-hook` fires for 14 languages, per-language hooks (e.g. `python-mode-hook`), `after-change-major-mode-hook` |
| Electric indent | :large_blue_circle: | Smart newline indentation |

**Summary:** Programming support covers the basics well (highlighting, folding, compilation, error nav, real GDB/MI debugger). Missing Tree-sitter and deep semantic analysis.

---

## 19. LSP (Language Server Protocol)

| Feature | Status | Notes |
|---------|--------|-------|
| JSON-RPC transport | :white_check_mark: | Content-Length framing, background thread |
| Server lifecycle | :white_check_mark: | Start/stop/restart with auto-start on file open |
| Document sync | :white_check_mark: | didOpen/didChange/didSave/didClose |
| Diagnostics display | :white_check_mark: | Scintilla indicators + margin markers + modeline |
| Completion | :white_check_mark: | QCompleter popup, auto-complete on idle, Tab merge |
| Hover (tooltip) | :white_check_mark: | Echo area display on `C-c l h` |
| Go-to-definition | :white_check_mark: | `M-.` with smart dispatch, `M-,` to pop back |
| Find references | :white_check_mark: | `C-c l r` shows in compilation buffer |
| Rename refactoring | :white_check_mark: | `C-c l R` with echo prompt |
| Code actions | :white_check_mark: | `C-c l a` with selection popup |
| Formatting | :white_check_mark: | `C-c l f` format buffer/region |
| Semantic tokens | :white_check_mark: | Toggle with `lsp-semantic-tokens`, indicator-based highlighting |
| Call hierarchy | :white_check_mark: | `lsp-incoming-calls` / `lsp-outgoing-calls` with navigation |
| Type hierarchy | :white_check_mark: | `lsp-supertypes` / `lsp-subtypes` with navigation buffer |
| Inlay hints | :white_check_mark: | Toggle with `lsp-inlay-hints`, shows in echo area on idle |
| Workspace symbols | :white_check_mark: | `C-c l s` with completion |
| Multi-server support | :white_check_mark: | `lsp-set-server` / `lsp-list-servers` with per-language registry |

**Summary:** LSP is fully functional — auto-starts on file open, provides completion (auto + Tab + C-M-i), diagnostics with inline indicators, go-to-definition (M-.), hover, references, rename, code actions, formatting, workspace symbols, semantic tokens, call hierarchy, type hierarchy, and inlay hints. All under `C-c l` prefix. Only missing multi-server support.
5. Wire find-references to results buffer

---

## 20. Syntax Highlighting & Themes

| Feature | Status | Notes |
|---------|--------|-------|
| Scintilla lexer system | :white_check_mark: | Many built-in lexers |
| Chez Scheme/Scheme highlighting | :white_check_mark: | Custom keyword lists |
| C/C++ highlighting | :white_check_mark: | Via Scintilla |
| Python highlighting | :white_check_mark: | Via Scintilla |
| JavaScript highlighting | :white_check_mark: | Via Scintilla |
| HTML/CSS highlighting | :white_check_mark: | Via Scintilla |
| Markdown highlighting | :white_check_mark: | Via Scintilla |
| Org-mode highlighting | :large_blue_circle: | Custom lexer |
| Theme system | :white_check_mark: | 8 built-in themes |
| Custom face definitions | :white_check_mark: | Foreground, background, bold, italic |
| Per-buffer lexer | :white_check_mark: | Based on file extension |
| Font-lock (regex-based) | :white_check_mark: | `font-lock-mode` toggles Scintilla lexer on/off; re-applies language highlighting |
| Tree-sitter highlighting | :yellow_circle: | `tree-sitter-highlight-mode` toggle — uses Scintilla lexers as backend |
| Rainbow delimiters | :green_circle: | Depth-based coloring via indicators (8 colors, both layers) |

**Built-in Themes:**
1. Dark (default)
2. Light
3. Solarized
4. Monokai
5. Gruvbox
6. Dracula
7. Nord
8. Zenburn

**Summary:** Highlighting works well via Scintilla's lexer system. Good theme selection. Missing tree-sitter for more accurate highlighting.

---

## 21. Completion Frameworks

| Feature | Status | Notes |
|---------|--------|-------|
| Dabbrev (dynamic abbrev) | :white_check_mark: | `M-/` word completion from buffer |
| Hippie-expand | :large_blue_circle: | Delegates to dabbrev-expand (buffer word completion), `M-/` keybinding |
| Complete at point | :white_check_mark: | `C-M-i` — Scintilla native autocomplete popup with buffer-local word candidates |
| Company mode | :large_blue_circle: | Scintilla autocomplete popup with buffer words + LSP merged |
| Corfu mode | :large_blue_circle: | Scintilla autocomplete popup (500ms idle trigger) |
| Cape (completion extensions) | :white_check_mark: | `cape-dabbrev`, `cape-file`, `cape-history`, `cape-keyword` |
| File path completion | :white_check_mark: | In minibuffer |
| Symbol completion | :white_check_mark: | Buffer words + LSP merged on Tab |
| LSP completion | :white_check_mark: | Auto-complete on idle + C-M-i + Tab merge |
| Snippet completion | :large_blue_circle: | TAB expands snippet triggers; `M-x snippet-insert` for browsing |
| Copilot/AI completion | :large_blue_circle: | Real OpenAI API integration, copilot-complete/accept/dismiss |

**Summary:** Full completion framework: QCompleter popup with buffer words + LSP merged, auto-triggers on idle. Cape backends (dabbrev, file, history, keyword), Copilot mode toggle with accept/next. AI inline suggestions and code explain/refactor scaffolded.

---

## 22. Shell & Terminal

| Feature | Status | Notes |
|---------|--------|-------|
| Shell command (`M-!`) | :white_check_mark: | Run command, show output |
| Shell command on region (`M-\|`) | :white_check_mark: | Pipe region to command |
| Async shell command (`M-&`) | :white_check_mark: | |
| Eshell | :large_blue_circle: | Built-in commands (cd, ls, cat, echo, grep, find, wc, head, tail), pipelines, output redirect (`>`, `>>`), glob expansion (`*.txt`), env var expansion (`$HOME`), Scheme eval |
| Terminal (term/ansi-term) | :large_blue_circle: | PTY support, ANSI colors, signals |
| Vterm | :large_blue_circle: | Full PTY terminal; `vterm-copy-mode` in Qt; multi-vterm support |
| Shell mode | :large_blue_circle: | External shell buffer |
| Compilation mode | :white_check_mark: | Error parsing, navigation, ANSI color rendering |
| Comint (process interaction) | :large_blue_circle: | Full PTY terminal with async/sync I/O, ANSI colors, signals |
| Process sentinels/filters | :white_check_mark: | `set-process-sentinel!`, `set-process-filter!` API |

**Summary:** Shell command execution works well. Terminal mode provides full PTY with ANSI support. Vterm with copy-mode and multi-vterm. Eshell with pipelines, redirects, and glob expansion. Process sentinels and filters.

---

## 23. Spell Checking

| Feature | Status | Notes |
|---------|--------|-------|
| Ispell word | :large_blue_circle: | Check word at point with suggestions |
| Ispell region | :large_blue_circle: | Scan region for misspellings |
| Ispell buffer | :large_blue_circle: | Whole-buffer check |
| Suggestion menu | :white_check_mark: | Interactive selection from ispell output |
| Flyspell (on-the-fly) | :white_check_mark: | `flyspell-mode` with aspell backend; both TUI and Qt use red squiggly underline indicators (Scintilla INDIC_SQUIGGLE); `toggle-flyspell` works in both layers |
| Personal dictionary | :large_blue_circle: | Supported via ispell |
| Language selection | :white_check_mark: | `ispell-change-dictionary` with narrowing (Qt) or prompt (TUI) |
| Aspell/Hunspell backend | :large_blue_circle: | Uses ispell subprocess |

**Summary:** Interactive spell-checking works via ispell with language selection. Flyspell mode provides on-demand buffer spell-checking with visual indicators (TUI) and word-list reporting (Qt) using aspell backend.

---

## 24. Text Transformation & Formatting

| Feature | Status | Notes |
|---------|--------|-------|
| Upcase/downcase word | :white_check_mark: | `M-u`, `M-l` |
| Capitalize word | :white_check_mark: | `M-c` |
| Upcase/downcase region | :white_check_mark: | `C-x C-u`, `C-x C-l` |
| Sort lines | :white_check_mark: | Alphabetic, numeric, reverse, case-fold |
| Sort fields | :white_check_mark: | Sort by nth field |
| Sort columns | :white_check_mark: | Sort region by column range |
| Sort regexp fields | :white_check_mark: | Sort region by regexp match |
| Align regexp | :white_check_mark: | Column alignment |
| Fill paragraph | :white_check_mark: | Reflow to fill-column |
| Unfill paragraph | :white_check_mark: | Join into single line |
| Center region | :white_check_mark: | |
| Tabify / untabify | :white_check_mark: | |
| Delete trailing whitespace | :white_check_mark: | |
| Base64 encode/decode | :white_check_mark: | |
| ROT13 | :white_check_mark: | |
| Hex dump (hexl-mode) | :white_check_mark: | |
| Checksum (SHA256) | :white_check_mark: | |
| UUID generation | :white_check_mark: | |
| Camel/snake case conversion | :white_check_mark: | |
| Duplicate line/region | :white_check_mark: | |
| Reverse region/chars | :white_check_mark: | |
| Delete duplicate lines | :white_check_mark: | |
| Word frequency | :white_check_mark: | |
| Count words/chars/lines | :white_check_mark: | |

**Summary:** Text transformation is feature-complete. All standard Emacs text operations are present.

---

## 25. S-expression / Paredit

| Feature | Status | Notes |
|---------|--------|-------|
| Forward/backward sexp | :white_check_mark: | |
| Up/down list | :white_check_mark: | |
| Kill sexp | :white_check_mark: | |
| Mark sexp | :white_check_mark: | |
| Indent sexp | :white_check_mark: | |
| Slurp forward | :white_check_mark: | Extend sexp to include next |
| Barf forward | :white_check_mark: | Move last element out |
| Wrap in parens/brackets/braces | :white_check_mark: | |
| Splice sexp | :white_check_mark: | Remove delimiters, keep contents |
| Raise sexp | :white_check_mark: | Replace parent with child |
| Split sexp | :white_check_mark: | Break at point |
| Join sexps | :white_check_mark: | Merge adjacent |
| Backward slurp/barf | :white_check_mark: | `paredit-slurp-backward`, `paredit-barf-backward` |
| Convolute sexp | :white_check_mark: | `M-x paredit-convolute-sexp` swaps inner/outer |
| Paredit strict mode | :white_check_mark: | Prevents deleting delimiters that would unbalance; allows empty pair deletion |
| Smartparens | :large_blue_circle: | Aliased to paredit strict mode |

**Summary:** Complete paredit: forward and backward slurp/barf, wrap, splice, raise, split, join, convolute, strict mode.

---

## 26. Diff & Ediff

| Feature | Status | Notes |
|---------|--------|-------|
| Diff buffer vs file | :white_check_mark: | `C-c d` |
| Unified diff display | :large_blue_circle: | |
| Ediff two buffers | :large_blue_circle: | Side-by-side diff display |
| Ediff files | :large_blue_circle: | Compare two files from disk |
| Ediff directories | :large_blue_circle: | Recursive directory comparison |
| Ediff regions | :large_blue_circle: | Compare buffer regions |
| Ediff merge | :large_blue_circle: | Two-file merge comparison |
| Ediff three-way merge | :white_check_mark: | `diff3 -m` mine/base/theirs with conflict markers |
| Refine hunks | :white_check_mark: | Word-level diff via `M-x diff-refine-hunk` |
| Smerge mode | :white_check_mark: | Full conflict marker resolution |
| Smerge navigate (n/p) | :white_check_mark: | Jump between `<<<<<<<` markers |
| Smerge keep mine/other/both | :white_check_mark: | Resolve conflicts interactively |
| Smerge conflict count | :white_check_mark: | Shows total conflicts in buffer |

**Summary:** Diff display and smerge conflict resolution fully working. Ediff provides file/buffer/directory/three-way merge comparison. Word-level hunk refinement via `diff-refine-hunk`.

---

## 27. Project Management

| Feature | Status | Notes |
|---------|--------|-------|
| Project detection (.git, etc.) | :white_check_mark: | Auto-detect project root |
| Project file find | :white_check_mark: | Find file in project |
| Project grep/search | :white_check_mark: | Grep across project |
| Project compile | :white_check_mark: | |
| Project switch | :large_blue_circle: | Switch between projects |
| Project shell/eshell | :large_blue_circle: | Shell in project root |
| Project dired | :large_blue_circle: | Dired at project root |
| Project-aware buffer list | :large_blue_circle: | |
| Per-project settings | :large_blue_circle: | `.jemacs-config` directory-local settings (applied on file open) |
| Project-specific keymaps | :white_check_mark: | Load `.jemacs-keys` from project root |
| Projectile integration | :large_blue_circle: | Narrowing find-file, grep, switch-buffer, switch-project |
| project.el features | :large_blue_circle: | `C-x p` prefix map: f/g/c/b/d/e/s/p/k/t |

**Summary:** Project management works well. `C-x p` keybindings, narrowing popups for all project commands. Per-project settings via `.jemacs-config` dir-locals.

---

## 28. Help System

| Feature | Status | Notes |
|---------|--------|-------|
| Describe key (`C-h k`) | :white_check_mark: | Intercepts next keypress, shows binding + help in `*Help*` buffer (TUI + Qt) |
| Describe command (`C-h f`) | :white_check_mark: | |
| Describe variable (`C-h v`) | :large_blue_circle: | Narrowing selection, shows value and docs in `*Help*` |
| List all bindings (`C-h b`) | :white_check_mark: | |
| Where is (`C-h w`) | :white_check_mark: | Find key for command |
| Apropos (`C-h a`) | :white_check_mark: | Search commands by keyword |
| View lossage (`C-h l`) | :white_check_mark: | Last 300 keystrokes |
| Command history | :white_check_mark: | |
| Info reader | :white_check_mark: | GNU Info subprocess reader (TUI + Qt), topic prompting, built-in jemacs help |
| Emacs tutorial | :white_check_mark: | Built-in tutorial with navigation, editing, files, search, windows, org mode |
| Built-in documentation browser | :white_check_mark: | `jemacs-doc` with topic browsing (getting-started, keybindings, commands, org-mode) |

**Summary:** Help system is complete with describe-key, describe-function, apropos, Info reader, documentation browser, and tutorial.

---

## 29. Customization & Configuration

| Feature | Status | Notes |
|---------|--------|-------|
| Init file (`~/.jemacs-init`) | :white_check_mark: | Chez Scheme init file |
| Dir-locals (`.jemacs-config`) | :large_blue_circle: | Directory-local variable settings |
| Key binding customization | :white_check_mark: | Programmatic and via custom-keys |
| Key-chord bindings | :white_check_mark: | Two-key chord system |
| Theme selection | :white_check_mark: | 8 built-in + custom |
| Font customization | :white_check_mark: | Family, size |
| Fill column | :white_check_mark: | Configurable |
| Tab width | :white_check_mark: | |
| Indent style (tabs/spaces) | :white_check_mark: | |
| Scroll margin | :white_check_mark: | |
| M-x customize UI | :white_check_mark: | `M-x customize` shows settings buffer, `M-x set-variable` to change |
| Custom variables (defcustom) | :white_check_mark: | Customizable variables with getters/setters |
| Custom groups | :white_check_mark: | `customize-group` with editing/display/files categories |
| Face customization UI | :white_check_mark: | `customize-face`, `set-face-attribute` for face properties |
| Mode-specific hooks | :large_blue_circle: | Per-language mode hooks, `prog-mode-hook`, `text-mode-hook`, `after-change-major-mode-hook`, `after-init-hook` |

**Summary:** Configuration via init file and `M-x customize` interactive buffer. `set-variable` for runtime changes.

---

## 30. Package Management & Extensibility

| Feature | Status | Notes |
|---------|--------|-------|
| Elisp scripting | :large_blue_circle: | **Chez Scheme instead** — different paradigm, not a gap |
| package.el / MELPA | :large_blue_circle: | N/A — Chez Scheme package system (`jerboa pkg`) instead |
| use-package | :large_blue_circle: | N/A — `~/.jemacs-init.ss` Chez Scheme config instead |
| straight.el | :large_blue_circle: | N/A — Git-based package management via `jerboa pkg` |
| Plugin/package system | :white_check_mark: | `load-plugin`, `list-plugins`, `~/.jemacs-plugins/` directory |
| User-defined commands | :large_blue_circle: | Via `~/.jemacs-init` Chez Scheme code |
| Advice system | :white_check_mark: | `advice-add!`/`advice-remove!` with before/after, `describe-advice` |
| Hook system | :large_blue_circle: | Real `add-hook!/remove-hook!/run-hooks!` — `before-save-hook`, `after-save-hook`, `find-file-hook`, `kill-buffer-hook`. Interactive `M-x add-hook/remove-hook/list-hooks` |
| Autoload system | :white_check_mark: | `autoload!` to register, `list-autoloads` to view |
| Dynamic module loading | :white_check_mark: | `load-module` / `list-modules` for runtime Chez Scheme module loading |

**Summary:** Jemacs uses Chez Scheme, not Emacs Lisp — the MELPA ecosystem is unavailable. But has a plugin system (`~/.jemacs-plugins/` with `load-plugin`/`list-plugins`) and init file extensibility.

---

## 31. Remote Editing (TRAMP)

| Feature | Status | Notes |
|---------|--------|-------|
| SSH file editing | :large_blue_circle: | `tramp-ssh-edit` fetches remote file via ssh, `tramp-ssh-save` writes back |
| TRAMP sudo | :large_blue_circle: | `sudo-write` saves as root, `sudo-edit`/`find-file-sudo` opens file as root via `sudo cat` |
| Docker container editing | :large_blue_circle: | `tramp-docker-edit` fetches file via `docker exec cat`, with highlighting |
| Remote shell | :large_blue_circle: | `tramp-remote-shell` runs SSH session, displays output in buffer |
| Remote compilation | :large_blue_circle: | `tramp-remote-compile` runs command on remote host via SSH, shows in compilation buffer |

**Summary:** Full remote editing support: SSH edit/save, Docker edit, sudo read/write, remote shell, remote compilation.

---

## 32. EWW (Web Browser)

| Feature | Status | Notes |
|---------|--------|-------|
| URL fetching (HTTP/HTTPS) | :white_check_mark: | |
| HTML to text conversion | :large_blue_circle: | Full litehtml rendering with CSS layout, positioning, font styles |
| Navigation history | :white_check_mark: | Back/forward |
| Link display | :yellow_circle: | Shows URLs, no clickable links |
| Form submission | :large_blue_circle: | `eww-submit-form` parses `[field: value]` form fields from buffer |
| CSS rendering | :yellow_circle: | `eww-toggle-css` mode toggle |
| Image display | :yellow_circle: | `eww-toggle-images` mode toggle |
| JavaScript | :yellow_circle: | Not implemented (no JS engine) |
| Bookmarks | :white_check_mark: | `eww-add-bookmark` / `eww-list-bookmarks`, persisted to `~/.jemacs-eww-bookmarks` |

**Summary:** Basic text-mode web browsing. Fetches pages and strips HTML. Not usable for modern web pages.

---

## 33. Calendar & Diary

| Feature | Status | Notes |
|---------|--------|-------|
| Calendar display | :large_blue_circle: | 3-month grid, p/n navigation, holidays, diary integration, org entries |
| Today highlighting | :white_check_mark: | |
| Navigate months/years | :white_check_mark: | |
| Diary integration | :white_check_mark: | `diary-insert-entry` adds to `~/.jemacs-diary`, `diary-view-entries` shows entries |
| Holiday display | :white_check_mark: | US holidays shown on calendar, `calendar-holidays` command |
| Appointment reminders | :white_check_mark: | `appt-check` scans org deadlines + diary for next 15 min |
| Org-agenda integration | :white_check_mark: | Calendar footer shows org DEADLINE/SCHEDULED items for month |

**Summary:** Calendar with 3-month grid, navigation, holiday display, diary integration, org-agenda items in calendar, and appointment reminders.

---

## 34. Email

| Feature | Status | Notes |
|---------|--------|-------|
| Gnus | :large_blue_circle: | RSS/Atom feed reader via `curl`, extracts titles from feeds |
| mu4e | :large_blue_circle: | Checks for `mu` installation, displays latest messages from maildir |
| notmuch | :large_blue_circle: | Checks for `notmuch` installation, displays search results |
| message-mode (compose) | :large_blue_circle: | `compose-mail` prompts To/Subject, creates mail buffer with headers; `message-send` (C-c C-c) sends via msmtp/sendmail |

**Summary:** Mail composition via msmtp/sendmail. Gnus as RSS reader. mu4e/notmuch integration when installed.

---

## 35. IRC / Chat

| Feature | Status | Notes |
|---------|--------|-------|
| ERC (IRC) | :large_blue_circle: | TCP connection to IRC server, NICK/USER/JOIN, displays channel messages |
| rcirc | :large_blue_circle: | Delegates to ERC |

**Summary:** IRC client via ERC with TCP connection, NICK/USER/JOIN, and channel display.

---

## 36. PDF / Document Viewing

| Feature | Status | Notes |
|---------|--------|-------|
| PDF viewing (pdf-tools) | :large_blue_circle: | `pdf-view-mode` with `pdftotext` extraction, page navigation (next/prev/goto), both TUI and Qt |
| DocView | :large_blue_circle: | `doc-view-mode` converts PDF/PS to text via `pdftotext`/`ps2ascii`, both TUI and Qt |
| Image viewing | :large_blue_circle: | Image buffers in Qt layer |

**Summary:** PDF viewing via `pdftotext` extraction with page navigation. DocView converts PDF/PS to text. Image display in Qt layer.

---

## 37. Treemacs / File Tree

| Feature | Status | Notes |
|---------|--------|-------|
| File tree sidebar | :white_check_mark: | `M-x project-tree` with expand/collapse |
| Project tree | :white_check_mark: | Tree view with depth limit, hidden file filtering |
| Git status in tree | :white_check_mark: | Shows M/A/?/D/R status per file in project tree |
| File operations in tree | :white_check_mark: | Create, delete, rename files in project tree |

**Summary:** Project tree sidebar is fully featured with directory structure, git status indicators, and file operations (create, delete, rename).

---

## 38. Multiple Cursors / iedit

| Feature | Status | Notes |
|---------|--------|-------|
| mc-mark-next | :white_check_mark: | Mark next occurrence of selection |
| mc-mark-all | :white_check_mark: | Mark all occurrences |
| mc-edit-lines | :white_check_mark: | Add cursor to each line in region |
| mc-skip-and-mark-next | :white_check_mark: | Skip current, mark next |
| mc-unmark-last | :white_check_mark: | Remove last cursor |
| mc-rotate | :white_check_mark: | Rotate between cursors |
| iedit (edit all occurrences) | :white_check_mark: | Rename symbol at point across buffer |
| Symbol highlighting + edit | :white_check_mark: | `highlight-symbol` + iedit |
| Multi-cursor typing | :white_check_mark: | Scintilla multi-selection support for simultaneous typing at all cursors |

**Summary:** Full multiple cursors and iedit support in both TUI and Qt layers. Multi-cursor typing via Scintilla multi-selection. Keybindings: `C-c m n`, `C-c m a`.

---

## 39. Snippets (YASnippet)

| Feature | Status | Notes |
|---------|--------|-------|
| Snippet expansion | :white_check_mark: | TAB expands trigger → template with field navigation |
| Snippet library | :large_blue_circle: | 100+ built-in snippets across 9 languages |
| Snippet creation | :white_check_mark: | `M-x define-snippet` interactive definition |
| Tabstop navigation | :white_check_mark: | TAB/$1→$2→...→$0 field jumping |
| Default field values | :large_blue_circle: | `${1:default}` syntax supported |
| Snippet browsing | :white_check_mark: | `M-x snippet-insert` with narrowing |
| File-based snippets | :large_blue_circle: | Load from `~/.jemacs-snippets/<lang>/` |
| Mirror fields | :large_blue_circle: | Same $N tracked at all positions; TAB visits each |

**Built-in snippet languages:** Scheme/Chez Scheme, Python, JavaScript, C/C++, Go, Rust, HTML, Shell/Bash, Markdown, plus global snippets.

**Summary:** Full snippet system with TAB-triggered expansion, field navigation ($1→$2→$0), default values, mirror field tracking, 100+ built-in snippets, file-based loading, and narrowing-based browsing. Both TUI and Qt. Mirror fields track all positions of the same $N for TAB navigation (auto-sync on edit not yet implemented).

---

## 40. Tab Bar & Workspaces

| Feature | Status | Notes |
|---------|--------|-------|
| Tab bar mode | :green_circle: | Qt: visual buffer tab bar with click-to-switch; TUI: workspace tabs |
| Create/close tabs | :green_circle: | `tab-new`, `tab-close` (both layers) |
| Switch tabs | :green_circle: | `tab-next`, `tab-previous` with wrap-around (both layers) |
| Rename tabs | :green_circle: | `tab-rename` (both layers) |
| Move tabs | :green_circle: | `tab-move` with prefix arg direction (both layers) |
| Tab-line (per-window) | :yellow_circle: | Qt has visual buffer tab bar; no per-window tab line |
| Workspace/perspective | :white_check_mark: | Workspace tabs + real persp-mode buffer groups with switch/add/remove |
| Named workspaces | :green_circle: | Tabs have names, renameable via `tab-rename` |

**Summary:** Full workspace tab system with create/close/switch/rename/move. Qt has visual buffer tab bar (clickable buttons). Both layers save/restore window buffer configurations per workspace tab. Emacs aliases (`tab-bar-new-tab`, `tab-bar-close-tab`, `tab-bar-switch-to-tab`) registered.

---

## 41. Accessibility

| Feature | Status | Notes |
|---------|--------|-------|
| Keyboard-only operation | :white_check_mark: | All features keyboard-accessible |
| Screen reader support | :yellow_circle: | `screen-reader-mode` toggle registered |
| High contrast themes | :large_blue_circle: | Dark/light themes available |
| Font scaling | :white_check_mark: | Zoom in/out/reset |
| Blink cursor | :white_check_mark: | Toggleable |
| Long-line handling (so-long) | :white_check_mark: | Auto-disable features on long lines |

**Summary:** Keyboard-first design but no screen reader integration.

---

## 42. Performance & Large Files

| Feature | Status | Notes |
|---------|--------|-------|
| Large file handling | :large_blue_circle: | Scintilla handles large files well |
| Long line handling | :white_check_mark: | So-long mode, truncate lines |
| Incremental display | :white_check_mark: | Scintilla viewport rendering |
| Background process | :large_blue_circle: | LSP reader thread |
| Garbage collection tuning | :large_blue_circle: | Chez Scheme/Chez GC; `memory-usage` shows detailed stats (heap, GC count, timing, allocation) in *Memory* buffer |
| Native compilation | :white_check_mark: | `native-compile-file` runs `scheme -S` on current file; `native-compile-async` via compilation buffer |

**Summary:** Good performance characteristics thanks to Scintilla's native text handling.

---

## Critical Feature Gap Summary

### Tier 1 — Dealbreakers for Daily Use

No remaining Tier 1 gaps. All core editing, completion, and navigation features are functional.

### Tier 2 — Expected by Power Users

| Gap | Impact | Effort |
|-----|--------|--------|
| **Modern completion (Vertico/Orderless)** | Vertico/Selectrum modes, Cape backends, fuzzy matching — Done | Low |
| ~~Multiple cursors / iedit~~ | ~~Can't edit multiple occurrences simultaneously~~ Implemented: iedit-mode with highlight + edit all | ~~Medium~~ Done |
| ~~Snippet system (YASnippet)~~ | ~~No template expansion~~ Implemented: 100+ snippets, tabstops | ~~Medium~~ Done |
| ~~Ediff / Smerge~~ | ~~Can't resolve merge conflicts~~ Implemented: smerge-mode with keep-mine/other/both | ~~Medium~~ Done |
| ~~Flyspell (on-the-fly spell)~~ | ~~No background spell checking~~ Implemented: flyspell-mode with aspell, squiggle indicators | ~~Small~~ Done |
| ~~Undo tree~~ | ~~Linear undo only~~ Implemented: undo-history with timestamped snapshots, restore by number | ~~Medium~~ Done |
| ~~Interactive agenda~~ | ~~Can't act on agenda items~~ Implemented: goto source, toggle TODO | ~~Medium~~ Done |

### Tier 3 — Nice to Have

| Gap | Impact | Effort |
|-----|--------|--------|
| ~~TRAMP (remote editing)~~ | ~~Can't edit files over SSH/Docker~~ Implemented: SSH/Docker file fetching, remote shell, remote compile, sudo-edit | ~~Large~~ Done |
| ~~Tab bar / workspaces~~ | ~~No visual workspace management~~ Implemented: workspace tabs (create/close/switch/rename/move), Qt visual buffer tab bar | ~~Medium~~ Done |
| **Tree-sitter highlighting** | Less accurate highlighting than modern Emacs | Large |
| ~~Package/plugin system~~ | ~~Users can't extend jemacs easily~~ Implemented: `~/.jemacs-plugins/`, `load-plugin`/`list-plugins`, dynamic module loading | ~~Large~~ Done |
| ~~Org capture buffer~~ | ~~No interactive capture~~ Implemented: template selection, `*Org Capture*` buffer, C-c C-c / C-c C-k | ~~Small~~ Done |
| ~~Named keyboard macros~~ | ~~Only last-recorded macro~~ Implemented: name, call, save/load | ~~Small~~ Done |
| ~~Info reader~~ | ~~Can't browse GNU documentation~~ Implemented: `info-reader` with node navigation | ~~Medium~~ Done |
| ~~PDF viewing~~ | ~~No document viewer~~ Implemented: `pdf-view-mode` with pdftotext, page navigation, DocView | ~~Large~~ Done |

### Tier 4 — Emacs-Specific (Low Priority)

| Gap | Impact | Effort |
|-----|--------|--------|
| ~~Email (Gnus/mu4e)~~ | ~~Most users use dedicated email clients~~ Implemented: compose-mail (msmtp/sendmail), Gnus RSS, mu4e/notmuch | ~~Very Large~~ Done |
| ~~IRC (ERC)~~ | ~~Most users use dedicated chat clients~~ Implemented: ERC IRC with TCP, NICK/USER/JOIN | ~~Large~~ Done |
| ~~M-x customize UI~~ | ~~Programmatic config is fine for power users~~ Implemented: `customize`, `set-variable`, custom groups, face editor | ~~Medium~~ Done |
| Elisp compatibility | Fundamental architecture choice (Chez Scheme vs Elisp) | N/A |

---

## What Jemacs Does Well (Relative to Emacs)

| Strength | Detail |
|----------|--------|
| **Qt6 GUI** | Native GUI with proper font rendering, unlike Emacs's X11/GTK layer |
| **Scintilla backend** | Battle-tested text component with excellent large-file performance |
| **Dual-layer architecture** | Same commands work in TUI and Qt |
| **Org-mode** | Surprisingly complete for a non-Emacs implementation |
| **Wgrep** | Full edit-grep-results workflow |
| **Rectangle operations** | Feature-complete |
| **Text transforms** | Comprehensive set of text operations |
| **Register system** | All register types including window configurations |
| **Paredit** | Solid s-expression editing |
| **Startup time** | Faster than Emacs (no Elisp initialization) |
| **Chez Scheme** | Modern Scheme with actors, contracts, and better concurrency than Elisp |

---

---

## 43. AI / LLM Integration

| Feature | Status | Notes |
|---------|--------|-------|
| Copilot (code completion) | :large_blue_circle: | Mode toggle, accept/next commands, real OpenAI API integration |
| GPTel / LLM chat | :white_check_mark: | `M-x claude-chat` — streaming chat via `claude -p` |
| Claude shell / chat | :white_check_mark: | `*AI Chat*` buffer with `--continue` for context |
| Inline AI suggestions | :large_blue_circle: | `ai-inline-suggest` mode toggle with API provider |
| Code explanation / refactor via AI | :white_check_mark: | `ai-code-explain`, `ai-code-refactor` — real OpenAI API calls (both TUI and Qt) |

**Summary:** Full AI integration — Claude CLI chat (streaming), OpenAI API for code explain/refactor (real HTTP requests with JSON parsing), copilot completion mode. Set `OPENAI_API_KEY` env var or `M-x copilot-mode` to configure. Both TUI and Qt.

---

## 44. Multi-Terminal (vterm)

| Feature | Status | Notes |
|---------|--------|-------|
| Vterm (libvterm) | :large_blue_circle: | Full PTY terminal with ANSI colors, signals, async I/O (no libvterm, uses built-in) |
| Multi-vterm (multiple terminals) | :white_check_mark: | `term-list`, `term-next`, `term-prev` commands |
| Vterm copy mode | :white_check_mark: | Terminal copy mode with `C-c C-k` / `C-c C-j` |
| Terminal per-project | :white_check_mark: | `M-x project-term` opens/switches to project terminal |
| Term / ansi-term | :large_blue_circle: | Basic PTY terminal with ANSI support |

**Summary:** Multi-terminal management works — create, list, cycle, copy mode, and per-project terminals. Uses PTY instead of libvterm but functionally equivalent for most workflows.

---

## 45. Key Input Remapping

| Feature | Status | Notes |
|---------|--------|-------|
| Key-chord bindings | :white_check_mark: | Two-key simultaneous chords |
| Key translation table | :white_check_mark: | Character remapping |
| Swap brackets/parens | :white_check_mark: | `M-x toggle-bracket-paren-swap` and `M-x key-translation-list` |
| Super/Hyper key mapping | :white_check_mark: | `toggle-super-key-mode` (super → meta), `key-translate` |
| Per-mode keymaps | :large_blue_circle: | Mode keymaps for dired, magit, compilation, grep, ibuffer, calendar, eww, org, help; auto-lookup by lexer-lang or buffer name |
| Global key remap (input-decode-map) | :white_check_mark: | `key-translate` + `describe-key-translations` |

**Summary:** Key-chord system works well. Bracket/paren swap via key-translate system. Missing super-to-meta mapping.

---

## 46. DevOps / Infrastructure Modes

| Feature | Status | Notes |
|---------|--------|-------|
| Docker mode | :white_check_mark: | `docker`, `docker-containers`, `docker-images`, `dockerfile-mode` |
| Docker Compose | :white_check_mark: | `docker-compose`, `docker-compose-up`, `docker-compose-down` |
| Terraform mode | :white_check_mark: | `terraform-mode` (HCL lexer), `terraform`, `terraform-plan` |
| Ansible mode | :white_check_mark: | `ansible-mode` (YAML lexer), `ansible-playbook` (syntax-check) |
| Systemd unit files | :white_check_mark: | `systemd-mode` (properties lexer) |
| YAML mode | :large_blue_circle: | Syntax highlighting via Scintilla |
| Kubernetes / k8s | :white_check_mark: | `kubernetes-mode` (YAML lexer), `kubectl` (interactive CLI) |
| SSH management | :white_check_mark: | `ssh-config-mode` (properties lexer) |

**Summary:** Full DevOps CLI integration: Docker (info/containers/images/compose up/down), Terraform (plan/interactive), Ansible (playbook syntax-check), Kubernetes (kubectl), all with output buffers. Both TUI and Qt.

---

## 47. Helm / Narrowing Framework

| Feature                   | Status       | Notes                                        |
|---------------------------|--------------|----------------------------------------------|
| Helm core framework       | :white_check_mark: | Multi-source composition, session management, action dispatch |
| Multi-match engine        | :white_check_mark: | Space-separated AND tokens, `!` negation, `^` prefix, fuzzy per-source |
| Helm M-x                  | :white_check_mark: | Real-time filtered candidate list, command + keybinding display |
| Helm mini                 | :white_check_mark: | Multi-source: buffers + recent files combined |
| Helm buffers              | :white_check_mark: | MRU-ordered buffer list with modified indicator |
| Helm find-files           | :white_check_mark: | Full helm file browser in both TUI and Qt |
| Helm occur                | :white_check_mark: | Live narrowing of buffer lines, goto-line on select |
| Helm imenu                | :white_check_mark: | Navigate definitions (def/defstruct/defclass/define/defmethod/defrule) |
| Helm show-kill-ring       | :white_check_mark: | Browse and insert from kill ring |
| Helm bookmarks            | :white_check_mark: | Browse bookmarks with narrowing |
| Helm mark-ring            | :white_check_mark: | Browse mark ring positions |
| Helm register             | :white_check_mark: | Browse registers |
| Helm apropos              | :white_check_mark: | Multi-source: commands + variables with descriptions |
| Helm grep                 | :white_check_mark: | Volatile source using `rg` (fallback `grep`), pattern as search query |
| Helm man                  | :white_check_mark: | Cached `man -k` results with fuzzy filtering |
| Helm resume               | :white_check_mark: | Restore last session with pattern and candidates |
| Helm mode toggle          | :white_check_mark: | Rebinds M-x, C-x b, C-x C-b, M-y, C-x r b |
| Helm dash (documentation) | :white_check_mark: | `helm-dash` docset search                    |
| Helm C-yasnippet          | :white_check_mark: | `helm-c-yasnippet` delegates to snippet-insert |
| Follow mode               | :white_check_mark: | C-c C-f toggle, auto-preview on C-n/C-p navigation |
| Action menu / marking     | :white_check_mark: | TAB action menu, C-SPC mark/unmark, M-a mark-all |
| Match highlighting        | :white_check_mark: | Matched chars in yellow, brighter when selected |
| Auto-resize               | :white_check_mark: | Helm window grows/shrinks 4–12 rows based on candidates |
| Source headers             | :white_check_mark: | Styled `─── Source Name ───` separator lines |

**Summary:** Full Helm narrowing framework: dedicated core (`helm.ss`), multi-match engine (AND tokens, `!` negation, `^` prefix, fuzzy), 14 built-in sources, TUI and Qt renderers, 16 registered commands, session resume, helm-mode keybinding override, follow mode, action menu with marking, match character highlighting, auto-resize, and styled source headers. All features have TUI and Qt parity.

---

## Personal Workflow Gap Analysis

> *Based on review of the user's Doom Emacs configuration at `~/mine/emacs/`*

### What the User Actually Uses Daily

| Feature                                                 | Emacs Status     | Jemacs Status                | Gap Severity                             |
|---------------------------------------------------------|------------------|------------------------------|------------------------------------------|
| **Key-chords** (30+ bindings: AS, ZX, BV, FG, KB, etc.) | Extensive        | :white_check_mark: Works     | None — key-chord system exists           |
| **Helm** (M-x, buffers, files, grep)                    | Primary UI       | :white_check_mark: Complete | **None** — 16 commands, 14 sources, follow mode, action menu, highlighting |
| **Magit + Forge** (staging, commit, PR review)          | Daily driver     | :white_check_mark: Works     | None — hunk staging, inline diffs, forge PR/issue |
| **Multi-vterm** (multiple terminals, copy mode)         | Heavy use        | :white_check_mark: Works     | None — term-list/next/prev + copy mode   |
| **Eglot / LSP** (completion, hover, goto-def, refs)     | Working          | :white_check_mark: Works     | None — full UI wiring with keybindings   |
| **Copilot / AI** (gptel, claude-shell, copilot)         | Active           | :white_check_mark: Works     | **None** — real OpenAI API integration + Claude chat |
| **Corfu** (completion-at-point popup)                   | Active           | :white_check_mark: Popup     | **None** — Scintilla native autocomplete popup + LSP completion |
| **Org tables + export**                                 | Heavy use        | :white_check_mark: Works     | None                                     |
| **Org folding + TODO**                                  | Heavy use        | :white_check_mark: Works     | None                                     |
| **Golden ratio** (window auto-sizing)                   | Enabled          | :white_check_mark: Works     | None                                     |
| **Browse kill ring**                                    | Installed        | :white_check_mark: Works     | None                                     |
| **Bracket/paren swap** (`[`↔`(`)                        | Configured       | :white_check_mark: Works     | None — key-translate system              |
| **iedit** (edit occurrences)                            | Installed        | :white_check_mark: Works     | None — M-x iedit-mode                    |
| **expand-region**                                       | Installed        | :white_check_mark: Works     | None — C-= expand, C-- shrink            |
| **Snippets** (yasnippet + file-templates)               | Active           | :large_blue_circle: Substantial | **Low** — 100+ snippets, TAB expand, field nav, file loading |
| **Dired extensions** (dired-k, dired-imenu, etc.)       | Enhanced         | :large_blue_circle: Substantial | **Low** — batch ops, wdired, find-dired work |
| **Chez Scheme mode + LSP** (custom chez-scheme-mode.el)           | Custom written   | :large_blue_circle: Built-in | Low — jemacs IS the Chez Scheme editor        |
| **Flycheck + Flyspell**                                 | Both active      | :large_blue_circle: Both work | **None** — flycheck via LSP, flyspell via aspell |
| **EditorConfig**                                        | Installed        | :white_check_mark: Works     | None — auto-applied on file open         |
| **GitLab issue tracking** (28 custom modes)             | Extensive custom | :yellow_circle: Custom        | **Low** — very personal workflow         |

### The User's Unique Patterns

1. **Key-chord power user**: 30+ two-key simultaneous bindings for common actions. Jemacs already supports this.

2. **Helm-centric workflow**: Everything goes through Helm — M-x, buffers, files, grep, docs. Jemacs has a full Helm framework with 16 commands, 14 sources, multi-match engine, session resume, follow mode, action menu, match highlighting, and TUI+Qt renderers. No remaining gaps.

3. **Multi-terminal workflow**: Uses multi-vterm with key-chords (`MT` = new terminal, `LK` = copy mode, `JK` = exit copy mode). Terminal management is core to their workflow.

4. **AI-assisted coding**: Has copilot, gptel, claude-shell, ellama, chatgpt-shell. AI completion and chat are expected features.

5. **DevOps toolchain**: Docker, Terraform, Ansible, AWS — needs syntax highlighting and basic mode support at minimum.

6. **Custom tool builder**: Wrote 28 custom Elisp modes. Will want to write equivalent Chez Scheme modes — needs a good extension API.

7. **No Paredit**: Despite being a Lisp user, doesn't use paredit/smartparens. Jemacs's paredit is a bonus.

---

## Recently Added Popular Package Support (2026-03-09)

| Package | Status | Notes |
|---------|--------|-------|
| Swiper / Counsel / Ivy | :white_check_mark: | Wrappers to built-in occur, M-x, rgrep, recentf, bookmarks |
| God mode | :white_check_mark: | Ctrl-free command execution toggle |
| Beacon mode | :white_check_mark: | Cursor flash on large movements |
| Volatile highlights | :white_check_mark: | Flash edited regions toggle |
| Smartparens | :white_check_mark: | Delegates to paredit/auto-pair |
| Dimmer | :white_check_mark: | Dim non-active windows toggle |
| Nyan mode | :white_check_mark: | Fun position indicator toggle |
| Centered cursor | :white_check_mark: | Keep cursor vertically centered |
| Format-all | :white_check_mark: | Real formatter integration (black, prettier, gofmt, rustfmt, clang-format, jq, shfmt) |
| Visual regexp | :white_check_mark: | Delegates to query-replace-regexp |
| Anzu | :white_check_mark: | Search match count toggle |
| Popwin | :white_check_mark: | Popup window management |
| Easy-kill | :white_check_mark: | Copy word at point without moving |
| Crux extras | :white_check_mark: | open-with, duplicate-line, swap-windows, cleanup-buffer |
| Hydra | :white_check_mark: | Interactive popup menus (zoom, window) |
| Deadgrep | :white_check_mark: | Real `rg`/`grep` search with results buffer and fallback |
| Hideshow (hs-minor-mode) | :white_check_mark: | Real Scintilla folding (SCI_TOGGLEFOLD/FOLDALL) |
| Prescient | :white_check_mark: | Real frequency tracking and sorted completions |
| GCMH | :white_check_mark: | Adaptive GC threshold toggle |
| Ligature mode | :white_check_mark: | Font ligature display toggle |
| Mixed-pitch / variable-pitch | :white_check_mark: | Proportional font mode |
| Eldoc-box | :white_check_mark: | Eldoc in popup mode |
| Color-rg | :white_check_mark: | Colored ripgrep (delegates to rgrep) |
| Ctrlf / phi-search | :white_check_mark: | Alternative isearch wrappers |
| Toc-org | :white_check_mark: | Auto-generate org TOC with heading extraction |
| Org-super-agenda | :white_check_mark: | Enhanced agenda grouping toggle |
| Nov.el (EPUB reader) | :white_check_mark: | Real EPUB text extraction via unzip pipeline |
| LSP-UI | :white_check_mark: | Mode toggle, doc-show, peek-find-definitions/references |
| Emojify | :white_check_mark: | Emoji mode + insert-by-name (10 built-in) |
| Ef-themes / modus-themes | :white_check_mark: | Theme pack selection and toggle |
| Circadian / auto-dark | :white_check_mark: | Time-based and OS-based theme switching |
| Breadcrumb / sideline | :white_check_mark: | Code context and side info display |
| Flycheck-inline | :white_check_mark: | Inline error display toggle |
| Zone / fireplace | :white_check_mark: | Screen saver and decorative fireplace |
| DAP-UI | :white_check_mark: | Debugger UI panels toggle |
| Poly-mode | :white_check_mark: | Multiple major modes toggle |
| Company-box | :white_check_mark: | Fancy completion popup toggle |
| Impatient mode | :white_check_mark: | Live HTML preview toggle |
| Mood-line / powerline | :white_check_mark: | Modeline theme toggles |
| Centaur-tabs | :white_check_mark: | Tab bar for buffer groups toggle |
| use-package / straight | :white_check_mark: | Informational stubs (all packages built-in) |
| EMMS (music player) | :white_check_mark: | Real mpv playback, playlist management, play file/directory |
| Perspectives (persp-mode) | :white_check_mark: | Real buffer group management, switch/add/remove perspectives |
| Org-roam | :white_check_mark: | Real grep-based note search in ~/notes/, node find/insert with backlinks |
| Sort-columns / sort-regexp-fields | :white_check_mark: | Real column-range and regex-based line sorting |

---

## Recently Added Features (2026-03-27, Rounds 7–11)

| Package / Feature | Status | Notes |
|---------|--------|-------|
| Spray (RSVP speed reading) | :orange_circle: | Speed reading mode with configurable WPM |
| Ledger-mode | :orange_circle: | Ledger file report via external `ledger` command |
| Buffer-move | :orange_circle: | Swap buffer positions (up/down) |
| Fortune | :orange_circle: | Display fortune cookie from `fortune` command |
| Snake game | :orange_circle: | Text-based snake game in buffer |
| Graphviz preview | :orange_circle: | Render DOT files via `dot` command |
| Thesaurus | :orange_circle: | Word synonym lookup via API |
| Grammar-check | :orange_circle: | Grammar checking via `languagetool` CLI |
| Morse code encode/decode | :orange_circle: | Convert text to/from Morse code |
| Highlight-sentence | :orange_circle: | Highlight current sentence with indicator overlay |
| Mastodon client | :orange_circle: | Post to Mastodon via `toot` CLI |
| QR code generator | :orange_circle: | Generate QR codes via `qrencode` |
| Keychain status | :orange_circle: | SSH/GPG keychain status and add keys |
| Eyebrowse (workspace switch) | :orange_circle: | Named workspace switching with save/restore |
| Chess | :orange_circle: | Chess game in buffer with text board |
| Sudoku | :orange_circle: | Sudoku puzzle generator and solver |
| Pong | :orange_circle: | Classic pong game in buffer |
| Org-pomodoro | :orange_circle: | Pomodoro timer with org-mode integration |
| LanguageTool check | :orange_circle: | Grammar/style checking via LanguageTool CLI |
| Newsticker (RSS) | :orange_circle: | RSS feed reader with configurable feeds, title extraction |
| Auth-source | :orange_circle: | In-memory credential store (save/search) |
| Gomoku | :orange_circle: | Five-in-a-row game with win detection |
| Dissociated Press | :orange_circle: | Scramble buffer text by random word mixing |
| MPUZ | :orange_circle: | Multiplication puzzle game |
| Blackbox | :orange_circle: | Logic puzzle game with guess/reveal |
| Literate-calc | :orange_circle: | Evaluate arithmetic expressions inline |
| Htmlize | :orange_circle: | Export buffer content as styled HTML file |
| Keycast mode | :orange_circle: | Show last key press and command name |
| Command-log | :orange_circle: | Log executed commands to a reviewable buffer |
| Macrostep | :orange_circle: | Expand Scheme macro at point and display |
| Eat (terminal toggle) | :orange_circle: | Toggle dedicated terminal buffer |
| Envrc (direnv) | :orange_circle: | Load `.envrc` environment via direnv |
| Org-present | :orange_circle: | Slide-based presentation from org headings |
| Denote (simple notes) | :orange_circle: | Timestamp-based note creation and search in ~/notes/ |
| Detached processes | :orange_circle: | Run background processes, list sessions |
| Inheritenv | :orange_circle: | Refresh process environment from login shell |
| Calc-grab-region | :orange_circle: | Evaluate selected text as numeric expression |
| Coterm | :orange_circle: | Run shell commands with output in buffer, history |
| Atomic-chrome | :orange_circle: | Browser text editing setup (GhostText compatible) |
| Wordle | :orange_circle: | 5-letter word guessing game with color feedback |
| Minesweeper | :orange_circle: | Minesweeper game with reveal and flag |
| Sokoban | :orange_circle: | Box-pushing puzzle game |
| 2048 game | :orange_circle: | Tile sliding number game |
| Git-link | :orange_circle: | Copy GitHub/GitLab URL for current file+line |
| Browse-at-remote | :orange_circle: | Open current file in remote forge browser |
| Code-review | :orange_circle: | Interactive git diff review in buffer |
| Conventional-commit | :orange_circle: | Guided conventional commit (feat/fix/docs/etc) |
| Clippy | :orange_circle: | Random helpful editor tips |
| Ellama (LLM) | :orange_circle: | Query local LLM via `ollama` |
| Hacker News client | :orange_circle: | Fetch top HN stories via Firebase API |
| Biblio (bibliography) | :orange_circle: | Academic paper search via CrossRef API |
| EPA encrypt/decrypt | :orange_circle: | GPG symmetric encryption/decryption of files |
| Typit (typing test) | :orange_circle: | Typing accuracy and speed test |
| Diff-at-point | :orange_circle: | Show git diff for current file |
| Magit-delta | :orange_circle: | Pretty diff via `delta` or colored git diff |
| Figlet | :orange_circle: | Convert text to ASCII art via `figlet` |
| Cowsay | :orange_circle: | Insert cowsay ASCII art |
| Habit tracker | :orange_circle: | Track daily habit completions with report |
| Ement (Matrix chat) | :orange_circle: | Matrix chat via `matrix-commander` |
| Journalctl viewer | :orange_circle: | View systemd journal entries by unit |
| Bluetooth control | :orange_circle: | List bluetooth devices via `bluetoothctl` |
| Volume control | :orange_circle: | Show/adjust system volume via PulseAudio/ALSA |
| ASCII table | :orange_circle: | Display full ASCII character reference table |
| Unicode search | :orange_circle: | Search and insert Unicode characters by name (50+ symbols) |
| Emoji insert | :orange_circle: | Insert emoji by name with completion (44 emoji) |
| Kaomoji | :orange_circle: | Insert Japanese emoticons by mood (19 kaomoji) |
| XKCD viewer | :orange_circle: | Fetch and display latest XKCD comic info |
| Cheat.sh | :orange_circle: | Look up cheat sheets from cheat.sh |
| TLDR pages | :orange_circle: | TLDR command reference lookup |
| HTTP stat | :orange_circle: | HTTP request timing statistics via curl |
| JWT decode | :orange_circle: | Decode JWT tokens (header + payload) |
| XML format | :orange_circle: | Pretty-print XML via xmllint/python |
| CSV sort | :orange_circle: | Sort CSV data by column |
| Markdown TOC | :orange_circle: | Generate table of contents from markdown headings |
| Focus mode | :orange_circle: | Minimal UI mode (hide margins/line numbers) |
| Typewriter mode | :orange_circle: | Keep cursor centered vertically |
| Matrix rain | :orange_circle: | Matrix-style digital rain animation |
| WiFi status | :orange_circle: | Show WiFi networks via nmcli/iwconfig |
| Screenshot | :orange_circle: | Take screenshot via import/scrot/gnome-screenshot |
| NPM scripts | :orange_circle: | Run npm scripts from package.json with completion |
| Cargo (Rust) | :orange_circle: | Run cargo commands with completion |
| Brew (Homebrew) | :orange_circle: | Run homebrew commands with package completion |
| Git stash list | :orange_circle: | List git stashes with details |
| Git cherry-pick | :orange_circle: | Cherry-pick commits by hash |
| Git worktree | :orange_circle: | List/add/remove git worktrees |
| IP info | :orange_circle: | Show public IP information via ipinfo.io |
| Whois lookup | :orange_circle: | Whois domain lookup |
| Traceroute | :orange_circle: | Network route tracing |
| Netstat | :orange_circle: | Show active network connections via ss/netstat |
| Crontab editor | :orange_circle: | View user crontab in buffer |
| Htop (process list) | :orange_circle: | Top processes by memory usage |
| Disk usage summary | :orange_circle: | Directory disk usage sorted by size |
| File permissions | :orange_circle: | Show file permissions and ownership |
| Compress | :orange_circle: | Compress files (tar.gz/bz2/xz/zip) |
| Extract | :orange_circle: | Extract archives (tar/zip/gz/bz2/xz) |
| Diff buffers | :orange_circle: | Diff two named buffers |
| Sort lines by field | :orange_circle: | Sort buffer lines by whitespace-delimited field |
| Vagrant | :orange_circle: | Run vagrant commands with completion |
| Pip (Python) | :orange_circle: | Run pip commands with package completion |
| Docker PS | :orange_circle: | List running Docker containers with formatted output |
| Docker logs | :orange_circle: | View container logs by name/ID |
| Git log graph | :orange_circle: | Graphical git log with branch visualization |
| Git bisect | :orange_circle: | Interactive git bisect (start/good/bad/reset) |
| Git reflog | :orange_circle: | View git reflog with timestamps |
| Git tag | :orange_circle: | List/create/delete git tags |
| Randomize lines | :orange_circle: | Fisher-Yates shuffle of buffer lines |
| Titlecase region | :orange_circle: | Convert selection to Title Case |
| Goto percent | :orange_circle: | Jump to percentage position in buffer |
| Copy filename | :orange_circle: | Copy current buffer's filename to kill ring |
| Copy filepath | :orange_circle: | Copy current buffer's full path to kill ring |
| Hex to decimal | :orange_circle: | Convert hex values to decimal |
| Decimal to hex | :orange_circle: | Convert decimal values to hex |
| Binary to decimal | :orange_circle: | Convert binary values to decimal/hex |
| String to hex | :orange_circle: | Show hex representation of text |
| ROT47 | :orange_circle: | ROT47 encoding/decoding of text |
| SHA256 hash | :orange_circle: | Compute SHA256 hash of text via sha256sum |
| MD5 hash | :orange_circle: | Compute MD5 hash of text via md5sum |
| Word frequency | :orange_circle: | Word frequency analysis with top-50 display |
| Text statistics | :orange_circle: | Characters, words, lines, sentences, reading time |
| String reverse | :orange_circle: | Reverse selected text or current line |
| Sort words | :orange_circle: | Alphabetically sort words in selection |
| Unique lines | :orange_circle: | Remove duplicate lines from buffer |
| Encode HTML entities | :orange_circle: | Encode &<>"' as HTML entities |
| Decode HTML entities | :orange_circle: | Decode HTML entities back to characters |
| URL decode | :orange_circle: | Decode URL-encoded text via Python |
| CamelCase to snake_case | :orange_circle: | Case conversion for identifiers |
| snake_case to camelCase | :orange_circle: | Case conversion for identifiers |
| kebab-case to camelCase | :orange_circle: | Case conversion for identifiers |
| Wrap region | :orange_circle: | Wrap selection with user-specified chars |
| Unwrap region | :orange_circle: | Remove outermost wrapping characters |
| Quote region | :orange_circle: | Prefix each line with > |
| Strip comments | :orange_circle: | Remove comment lines (#, //, ;) |
| Insert file header | :orange_circle: | Auto-detect comment style, insert header template |
| Insert license | :orange_circle: | MIT, Apache, GPL, BSD, Unlicense templates |
| Insert shebang | :orange_circle: | Shebang lines for bash, python, ruby, node, etc. |
| Open in external app | :orange_circle: | Open file with xdg-open |
| Copy line number | :orange_circle: | Copy current line number to kill ring |
| Rename file and buffer | :orange_circle: | Rename file on disk and update buffer |
| Sudo edit | :orange_circle: | Re-open file with sudo privileges |
| Insert date header | :orange_circle: | Insert formatted date/time header at point |
| Highlight phrase | :orange_circle: | Highlight all occurrences of a phrase (indicator overlay) |
| Unhighlight all | :orange_circle: | Clear all phrase highlights |
| Widen buffer | :orange_circle: | Remove narrowing, show full buffer |
| Move region up | :orange_circle: | Move selected lines up |
| Move region down | :orange_circle: | Move selected lines down |
| JSON to YAML | :orange_circle: | Convert JSON to YAML via Python |
| YAML to JSON | :orange_circle: | Convert YAML to JSON via Python |
| CSV to JSON | :orange_circle: | Convert CSV to JSON via Python |
| JSON to CSV | :orange_circle: | Convert JSON array to CSV via Python |
| Hex to RGB | :orange_circle: | Convert hex color (#FF8800) to rgb() format |
| RGB to hex | :orange_circle: | Convert rgb() color to hex format |
| Unix timestamp | :orange_circle: | Insert/convert Unix timestamps (now, from-date, to-date) |
| Format JSON | :orange_circle: | Pretty-print JSON via python3 json.tool |
| Minify JSON | :orange_circle: | Compact JSON to single line |
| File info | :orange_circle: | Show file size, permissions, owner, type, line count |
| Git contributors | :orange_circle: | Show top contributors via git shortlog |
| Git file history | :orange_circle: | Show git log for current file |
| Copy git branch | :orange_circle: | Copy current git branch name to kill ring |
| Eval and replace | :orange_circle: | Evaluate selection as shell/bc expression, replace with result |
| String inflection cycle | :orange_circle: | Cycle camelCase/snake_case/SCREAMING_SNAKE/kebab-case |
| Crux kill whole line | :orange_circle: | Kill entire line regardless of cursor position |
| Crux transpose windows | :orange_circle: | Swap buffers between current and next window |
| Crux delete file and buffer | :orange_circle: | Delete file from disk and kill its buffer |
| Smartscan symbol forward | :orange_circle: | Jump to next occurrence of symbol at point |
| Smartscan symbol backward | :orange_circle: | Jump to previous occurrence of symbol at point |
| Toggle quotes | :orange_circle: | Toggle between single and double quotes |
| Browse URL at point | :orange_circle: | Open URL under cursor in web browser |
| Dumb jump | :orange_circle: | Jump to definition using grep/rg (no LSP needed) |
| Diff buffer with file | :orange_circle: | Show diff between buffer and file on disk |
| Copy as format | :orange_circle: | Copy selection as markdown/org/html/slack/jira code block |
| Edit indirect | :orange_circle: | Edit selected region in a separate buffer |
| Crux indent defun | :orange_circle: | Re-indent entire function/defun |
| Crux cleanup buffer | :orange_circle: | Remove trailing whitespace, blank lines, cleanup |
| Recover file | :orange_circle: | Recover file from auto-save backup |
| Hexl mode | :orange_circle: | View/edit buffer in hexadecimal via xxd |
| Zone | :orange_circle: | Screensaver-like text melt animation |
| Doctor | :orange_circle: | Eliza psychotherapist session |
| Animate string | :orange_circle: | Animate text dropping from top of buffer |
| Tetris | :orange_circle: | Classic Tetris game in editor buffer |
| Morse region | :orange_circle: | Convert text to Morse code |
| Unmorse region | :orange_circle: | Convert Morse code back to text |
| Proced mode | :orange_circle: | Process viewer/manager (ps aux) |
| EWW open file | :orange_circle: | Render HTML file as text via w3m/lynx |
| Webjump | :orange_circle: | Quick jump to configured search engines |
| RSS feed | :orange_circle: | Simple RSS/Atom feed reader |
| Garbage collect | :orange_circle: | Run GC and display heap statistics |
| Benchmark run | :orange_circle: | Benchmark a shell command with timing stats |
| Describe personal keybindings | :orange_circle: | Show user-customized keybindings |
| Newsticker show news | :orange_circle: | Fetch Hacker News top headlines |
| Local set key | :orange_circle: | Set a local keybinding for session |
| Unbind key | :orange_circle: | Unbind a key sequence |
| Align entire | :orange_circle: | Align entire buffer by separator character |
| Studlify region | :orange_circle: | StUdLiFy text (alternating case) |
| Compile goto error | :orange_circle: | Jump to file:line from compile error |
| Signal process | :orange_circle: | Send signal to process by PID |
| Kill process | :orange_circle: | Kill process by PID or name |
| Text scale adjust | :orange_circle: | Interactive text zoom +/-/0 |
| Memory use counts | :orange_circle: | Display Chez Scheme memory statistics |
| Execute named kbd macro | :orange_circle: | Execute/list named keyboard macros |
| Emoji search | :orange_circle: | Search and insert emoji by name |
| Emoji list | :orange_circle: | Display emoji in a buffer |
| UCS insert | :orange_circle: | Insert Unicode character by codepoint or name |
| Char info | :orange_circle: | Show character details (decimal, hex, octal) |
| List colors display | :orange_circle: | Display named color palette |
| List faces display | :orange_circle: | Display Scintilla style information |
| Display battery mode | :orange_circle: | Show battery status from sysfs |
| View hello file | :orange_circle: | Multilingual HELLO greetings |
| Auto highlight symbol | :orange_circle: | Highlight all instances of symbol at point |
| Pulse momentary highlight | :orange_circle: | Flash/pulse current line (indicator overlay) |
| Prettier mode | :orange_circle: | Format code via prettier |
| Clang format | :orange_circle: | Format C/C++ via clang-format |
| Eglot format | :orange_circle: | Format buffer via detected formatter |
| Reformatter | :orange_circle: | Format with custom formatter command |
| Nav flash show | :orange_circle: | Flash line after navigation jump |
| Describe symbol | :orange_circle: | Look up Scheme symbol documentation |
| Apropos variable | :orange_circle: | Search variables by name pattern |
| Locate library | :orange_circle: | Find library file path |
| Load library | :orange_circle: | Load a Scheme library file |
| Finder by keyword | :orange_circle: | Find commands by keyword search |
| Insert Lorem Ipsum | :orange_circle: | Generate Lorem Ipsum placeholder text |
| Generate password | :orange_circle: | Generate random password (configurable length) |
| Insert UUID | :orange_circle: | Insert UUID v4 at point |
| ASCII art text | :orange_circle: | Convert text to ASCII art via figlet |
| Matrix effect | :orange_circle: | Matrix-style rain animation |
| Game of Life | :orange_circle: | Conway's Game of Life simulation |
| Mandelbrot | :orange_circle: | Text-based Mandelbrot set rendering |
| Maze generator | :orange_circle: | Random maze via recursive backtracker |
| Typing speed test | :orange_circle: | WPM typing speed test |
| Pomodoro timer | :orange_circle: | 25-minute work session timer |
| Stopwatch | :orange_circle: | Simple stopwatch |
| Countdown timer | :orange_circle: | Countdown timer with configurable duration |
| Snow effect | :orange_circle: | Animated snowfall in buffer |
| Hangman | :orange_circle: | Hangman word game |
| Image to ASCII | :orange_circle: | Convert image to ASCII art via jp2a |
| Buffer menu | :orange_circle: | Enhanced buffer list with modification status |
| Fire effect | :orange_circle: | Animated fire simulation |
| Lolcat | :orange_circle: | Rainbow text simulation |
| Toggle narrow to region | :orange_circle: | Toggle narrowing to selected region |
| Password store | :orange_circle: | Interact with pass password manager |
| Tic-tac-toe | :orange_circle: | Two-player tic-tac-toe game |
| Rock paper scissors | :orange_circle: | Play against the computer |
| Dice roller | :orange_circle: | Roll dice with notation (2d6, 1d20+5) |
| Coin flip | :orange_circle: | Flip a coin (heads/tails) |
| Towers of Hanoi | :orange_circle: | Hanoi puzzle visualization with solution |
| System info | :orange_circle: | Comprehensive system information |
| CPU info | :orange_circle: | Display CPU details via lscpu |
| Free memory | :orange_circle: | Show memory usage via free |
| Network interfaces | :orange_circle: | List network interfaces and IPs |
| Environment variables | :orange_circle: | Display sorted env vars |
| Kernel info | :orange_circle: | Show kernel information via uname |
| Hostname info | :orange_circle: | Show hostname and domain |
| List processes tree | :orange_circle: | Process tree visualization via pstree |
| Systemd status | :orange_circle: | Show systemd service status |
| Journal log | :orange_circle: | View journalctl logs |
| Dmesg view | :orange_circle: | View kernel dmesg messages |
| Installed packages | :orange_circle: | List installed packages (dpkg/rpm/pacman) |
| Apt search | :orange_circle: | Search apt packages |
| Connect Four | :orange_circle: | Connect Four board game |
| Fifteen puzzle | :orange_circle: | 15-puzzle sliding tile game |
| Currency convert | :orange_circle: | Currency conversion via Python |
| Wikipedia summary | :orange_circle: | Fetch Wikipedia article summaries |
| Man page | :orange_circle: | View man pages in buffer |
| Info page | :orange_circle: | View info pages in buffer |
| TLDR page | :orange_circle: | View tldr simplified man pages |
| Tutorial mode | :orange_circle: | Built-in jemacs tutorial |
| Version info | :orange_circle: | Display jemacs version info |
| Changelog view | :orange_circle: | View git changelog in buffer |
| Bug report mode | :orange_circle: | Generate bug report template |
| Color theme select | :orange_circle: | Theme selector with preview |
| Paredit mode | :orange_circle: | Paredit structural editing reference |
| Hi-lock mode | :orange_circle: | Highlight pattern occurrences |
| Syntax highlight region | :orange_circle: | Region syntax statistics |
| Stack Overflow search | :orange_circle: | Stack Overflow search helper |
| Cheat sheet | :orange_circle: | Editor keybinding cheat sheet |
| Apropos documentation | :orange_circle: | Search commands by keyword |
| Scratch message | :orange_circle: | Insert default *scratch* message |
| Geiser mode | :orange_circle: | Geiser Scheme interaction reference |
| SLY mode | :orange_circle: | SLY Common Lisp IDE reference |
| SLIME mode | :orange_circle: | SLIME Common Lisp IDE reference |
| Auto-fill mode | :orange_circle: | Toggle auto line wrapping at fill column |
| Display line numbers mode | :orange_circle: | Toggle line number margin |
| Visual line mode | :orange_circle: | Toggle word wrap display |
| Whitespace cleanup | :orange_circle: | Remove trailing whitespace |
| Indent rigidly | :orange_circle: | Indent/dedent region by N spaces |
| Align regexp | :orange_circle: | Align region on a pattern |
| Comment DWIM | :orange_circle: | Smart comment/uncomment line or region |
| Uncomment region | :orange_circle: | Remove comment markers from region |
| Toggle comment | :orange_circle: | Toggle comment on line/region |
| Fill paragraph | :orange_circle: | Wrap paragraph to fill column |
| Fill region | :orange_circle: | Wrap all paragraphs in region |
| Justify paragraph | :orange_circle: | Right-justify paragraph text |
| Center line | :orange_circle: | Center current line in fill column |
| Set fill column | :orange_circle: | Set the fill column width |
| Auto-revert mode | :orange_circle: | Toggle auto-refresh from disk |
| Revert buffer quick | :orange_circle: | Reload buffer from disk without confirm |
| Rename visited file | :orange_circle: | Rename file and update buffer |
| Make directory | :orange_circle: | Create a new directory |
| Delete directory | :orange_circle: | Delete a directory recursively |
| Copy directory | :orange_circle: | Copy a directory recursively |
| Abbrev mode | :orange_circle: | Toggle abbreviation expansion |
| Expand abbrev | :orange_circle: | Expand abbreviation at point |
| Define abbrev | :orange_circle: | Define a new abbreviation |
| List abbrevs | :orange_circle: | List all defined abbreviations |
| Insert register | :orange_circle: | Insert text from named register |
| Copy to register | :orange_circle: | Store region in named register |
| Point to register | :orange_circle: | Save cursor position to register |
| Jump to register | :orange_circle: | Jump to saved position in register |
| View register | :orange_circle: | Show contents of a register |
| List registers | :orange_circle: | List all registers and contents |
| Append to buffer | :orange_circle: | Append region to another buffer |
| Prepend to buffer | :orange_circle: | Prepend region to another buffer |
| Copy to buffer | :orange_circle: | Replace buffer contents with region |
| Insert buffer | :orange_circle: | Insert another buffer at point |
| Append to file | :orange_circle: | Append region to a file |
| Write region | :orange_circle: | Write region to a file |
| Print buffer | :orange_circle: | Send buffer to printer via lpr |
| LPR buffer | :orange_circle: | Print buffer (lpr alias) |
| Flush lines | :orange_circle: | Delete lines matching pattern |
| Keep lines | :orange_circle: | Keep only lines matching pattern |
| How many | :orange_circle: | Count occurrences of a pattern |
| Count matches | :orange_circle: | Count pattern matches (alias) |
| Occur mode | :orange_circle: | Show all lines matching pattern |
| Delete matching lines | :orange_circle: | Delete lines matching pattern |
| Delete non-matching lines | :orange_circle: | Keep only matching lines |
| Transpose lines | :orange_circle: | Swap current and previous line |
| Transpose words | :orange_circle: | Swap words around cursor |
| Transpose sexps | :orange_circle: | Swap S-expressions (placeholder) |
| Transpose paragraphs | :orange_circle: | Swap current and previous paragraph |
| Upcase word | :orange_circle: | Convert word to uppercase |
| Downcase word | :orange_circle: | Convert word to lowercase |
| Capitalize word | :orange_circle: | Capitalize word at cursor |
| Upcase initials | :orange_circle: | Upcase first letter of each word |
| Tabify | :orange_circle: | Convert spaces to tabs in region |
| Untabify | :orange_circle: | Convert tabs to spaces in region |
| Indent region | :orange_circle: | Indent all lines in region |
| Back to indentation | :orange_circle: | Move to first non-whitespace on line |
| Delete indentation | :orange_circle: | Join line with previous |
| Fixup whitespace | :orange_circle: | Collapse whitespace around point |
| Just one space | :orange_circle: | Replace whitespace with single space |
| Delete horizontal space | :orange_circle: | Delete spaces/tabs around point |
| Cycle spacing | :orange_circle: | Cycle between one/no/original spacing |
| Zap to char | :orange_circle: | Delete to next char occurrence (inclusive) |
| Zap up to char | :orange_circle: | Delete up to next char occurrence |
| Delete pair | :orange_circle: | Delete matching pair characters |
| Mark word | :orange_circle: | Select word at point |
| Mark sexp | :orange_circle: | Select S-expression at point |
| Mark paragraph | :orange_circle: | Select current paragraph |
| Mark page | :orange_circle: | Select current page |
| Mark whole buffer | :orange_circle: | Select entire buffer |
| Narrow to page | :orange_circle: | Narrow buffer to current page |
| Widen | :orange_circle: | Restore buffer from narrowing |
| Goto char | :orange_circle: | Go to character position |
| Goto line relative | :orange_circle: | Go to line relative to current |
| Set goal column | :orange_circle: | Set/clear goal column for movement |
| What line | :orange_circle: | Show current line number |
| What page | :orange_circle: | Show current page number |
| What cursor position | :orange_circle: | Show detailed cursor position info |
| Count words region | :orange_circle: | Count words in region or buffer |
| Count lines region | :orange_circle: | Count lines in region or buffer |
| Count lines page | :orange_circle: | Count lines on current page |
| Find file literally | :orange_circle: | Open file without conversions |
| Find file read-only | :orange_circle: | Open file in read-only mode |
| Find alternate file | :orange_circle: | Replace buffer with another file |
| Insert file contents | :orange_circle: | Insert file contents at point |
| Recover this file | :orange_circle: | Recover from auto-save file |
| Auto-save mode | :orange_circle: | Toggle auto-save mode |
| Not modified | :orange_circle: | Clear buffer modified flag |
| Set visited file name | :orange_circle: | Change file associated with buffer |
| Toggle read-only | :orange_circle: | Toggle read-only mode |
| Rename buffer | :orange_circle: | Rename current buffer |
| Clone buffer | :orange_circle: | Create copy of current buffer |
| Clone indirect buffer | :orange_circle: | Create indirect buffer copy |
| Bury buffer | :orange_circle: | Move buffer to end of list |
| Unbury buffer | :orange_circle: | Switch to least recently used buffer |
| Previous buffer | :orange_circle: | Switch to previous buffer |
| Next buffer | :orange_circle: | Switch to next buffer |
| List buffers | :orange_circle: | Show all buffers (C-x C-b) |
| IBuffer | :orange_circle: | Interactive buffer list |
| Display buffer | :orange_circle: | Display buffer in other window |
| Switch to buffer other window | :orange_circle: | Switch buffer in other window |
| Balance windows | :orange_circle: | Make all windows equal size |
| Shrink window | :orange_circle: | Shrink window vertically |
| Enlarge window | :orange_circle: | Enlarge window vertically |
| Shrink window horizontally | :orange_circle: | Shrink window horizontally |
| Enlarge window horizontally | :orange_circle: | Enlarge window horizontally |
| Fit window to buffer | :orange_circle: | Resize window to fit buffer |
| Maximize window | :orange_circle: | Maximize current window |
| Minimize window | :orange_circle: | Minimize current window |
| Toggle window dedicated | :orange_circle: | Dedicate window to buffer |
| Scroll other window | :orange_circle: | Scroll other window down |
| Scroll other window down | :orange_circle: | Scroll other window up |
| Recenter other window | :orange_circle: | Recenter other window |
| Follow mode | :orange_circle: | Synchronized scrolling mode |
| Winner undo | :orange_circle: | Undo window configuration |
| Winner redo | :orange_circle: | Redo window configuration |
| Windmove left | :orange_circle: | Move to left window |
| Windmove right | :orange_circle: | Move to right window |
| Windmove up | :orange_circle: | Move to window above |
| Windmove down | :orange_circle: | Move to window below |
| Highlight symbol at point | :orange_circle: | Highlight all occurrences of symbol |
| Unhighlight regexp | :orange_circle: | Remove regexp highlights |
| Highlight regexp | :orange_circle: | Highlight all regexp matches |
| Highlight lines matching regexp | :orange_circle: | Highlight matching lines |
| Highlight phrase | :orange_circle: | Highlight phrase (case-insensitive) |
| Font-lock mode | :orange_circle: | Toggle syntax highlighting |
| Global font-lock mode | :orange_circle: | Toggle global syntax highlighting |
| Font-lock fontify buffer | :orange_circle: | Re-fontify buffer |
| Show-paren mode | :orange_circle: | Toggle matching paren highlight |
| Electric-pair mode | :orange_circle: | Toggle auto-close brackets |
| Electric-indent mode | :orange_circle: | Toggle auto-indent on newline |
| Auto-composition mode | :orange_circle: | Toggle character composition |
| Auto-encryption mode | :orange_circle: | Toggle file encryption/decryption |
| Auto-compression mode | :orange_circle: | Toggle transparent .gz/.bz2 |
| Prettify-symbols mode | :orange_circle: | Toggle symbol prettification |
| Subword mode | :orange_circle: | Treat camelCase as separate words |
| Superword mode | :orange_circle: | Treat symbol_name as one word |
| Overwrite mode | :orange_circle: | Toggle overwrite/insert mode |
| Binary overwrite mode | :orange_circle: | Toggle binary overwrite |
| Enriched mode | :orange_circle: | Toggle rich text editing |
| SGML mode | :orange_circle: | HTML/SGML syntax highlighting |
| nXML mode | :orange_circle: | XML syntax highlighting |
| CSS mode | :orange_circle: | CSS syntax highlighting |
| JS mode | :orange_circle: | JavaScript syntax highlighting |
| Python mode | :orange_circle: | Python syntax highlighting |
| Ruby mode | :orange_circle: | Ruby syntax highlighting |
| Shell-script mode | :orange_circle: | Shell syntax highlighting |
| Conf mode | :orange_circle: | Config file syntax highlighting |
| Diff mode | :orange_circle: | Diff/patch syntax highlighting |
| Compilation mode | :orange_circle: | Compilation output mode |
| Grep mode | :orange_circle: | Grep output mode |
| Occur-edit mode | :orange_circle: | Make occur buffer editable |
| Compile command | :orange_circle: | Run compile command, show output |
| Next error | :orange_circle: | Jump to next error |
| Previous error | :orange_circle: | Jump to previous error |
| First error | :orange_circle: | Jump to first error |
| Describe variable | :orange_circle: | Show variable information |
| Describe key briefly | :orange_circle: | Show key's command |
| Describe bindings | :orange_circle: | Show all key bindings |
| Describe mode | :orange_circle: | Show current modes |
| Describe face | :orange_circle: | Show face/style at point |
| Describe char | :orange_circle: | Show character details at point |
| Describe syntax | :orange_circle: | Show syntax class of char at point |
| Describe categories | :orange_circle: | Show character categories |
| Apropos command | :orange_circle: | Search commands by pattern |
| Info/Emacs manual | :orange_circle: | Show jemacs manual reference |
| View echo area messages | :orange_circle: | Show message history |
| Toggle debug on error | :orange_circle: | Toggle debug-on-error |
| Toggle debug on quit | :orange_circle: | Toggle debug-on-quit |
| Profiler start | :orange_circle: | Start CPU profiler |
| Profiler stop | :orange_circle: | Stop CPU profiler |
| Profiler report | :orange_circle: | Show profiler report |
| Memory report | :orange_circle: | Show memory usage |
| Emacs uptime | :orange_circle: | Show session uptime |
| Emacs version | :orange_circle: | Show jemacs version |
| Emacs init time | :orange_circle: | Show init time |
| List packages | :orange_circle: | List available packages |
| Package install | :orange_circle: | Install package (placeholder) |
| Package delete | :orange_circle: | Delete package (placeholder) |
| Package refresh contents | :orange_circle: | Refresh packages (placeholder) |
| Set variable | :orange_circle: | Set an editor variable |
| Customize variable | :orange_circle: | Customize a variable |
| Customize group | :orange_circle: | Browse customization group |
| Customize face | :orange_circle: | Customize a face/style |
| Customize themes | :orange_circle: | Browse and select themes |
| Global set key | :orange_circle: | Bind a key globally |
| Local set key | :orange_circle: | Bind a key locally |
| Global unset key | :orange_circle: | Unbind a global key |
| Local unset key | :orange_circle: | Unbind a local key |
| Define key | :orange_circle: | Define a key binding |
| Keyboard quit | :orange_circle: | Cancel current operation (C-g) |
| Keyboard escape quit | :orange_circle: | Escape from context |
| Suspend frame | :orange_circle: | Suspend editor |
| Iconify frame | :orange_circle: | Minimize frame |
| Delete frame | :orange_circle: | Delete current frame |
| Make frame | :orange_circle: | Create new frame |
| Select frame | :orange_circle: | Select a frame |
| Other frame | :orange_circle: | Switch to other frame |
| Toggle frame fullscreen | :orange_circle: | Toggle fullscreen mode |
| Toggle frame maximized | :orange_circle: | Toggle maximized frame |
| Save some buffers | :orange_circle: | Save all modified buffers |
| Save buffers kill emacs | :orange_circle: | Save and exit (C-x C-c) |
| Kill emacs | :orange_circle: | Exit without saving |
| Restart emacs | :orange_circle: | Restart jemacs |
| Server start | :orange_circle: | Start server mode (placeholder) |
| Server edit | :orange_circle: | Finish server edit (placeholder) |
| Emacsclient mode | :orange_circle: | Toggle emacsclient (placeholder) |
| Eval last sexp | :orange_circle: | Evaluate S-expression before point |
| Eval print last sexp | :orange_circle: | Eval and insert result |
| Eval defun | :orange_circle: | Evaluate top-level form |
| Eval region | :orange_circle: | Evaluate selected region |
| Eval current buffer | :orange_circle: | Evaluate entire buffer |
| Load library | :orange_circle: | Load a Scheme library file |
| Load theme | :orange_circle: | Load a color theme |
| Disable theme | :orange_circle: | Disable current theme |
| Enable theme | :orange_circle: | Enable a theme |
| Repeat | :orange_circle: | Repeat last command |
| Repeat complex command | :orange_circle: | Repeat with editing |
| Command history | :orange_circle: | Show command history |
| View lossage | :orange_circle: | View recent keystrokes |
| Insert char | :orange_circle: | Insert Unicode char by code |
| Quoted insert | :orange_circle: | Insert next char literally |
| Open line | :orange_circle: | Insert newline without moving cursor |
| Split line | :orange_circle: | Split line preserving indentation |
| Delete blank lines | :orange_circle: | Delete blank lines around point |
| Delete trailing whitespace | :orange_circle: | Remove trailing whitespace |
| Newline and indent | :orange_circle: | Newline with auto-indentation |
| Reindent then newline | :orange_circle: | Reindent + newline + indent |
| Electric newline | :orange_circle: | Smart newline with indent |
| Completion at point | :orange_circle: | Trigger completion at cursor |
| Dabbrev expand | :orange_circle: | Dynamic abbreviation expansion |
| Dabbrev completion | :orange_circle: | Show dabbrev completions |
| Hippie expand | :orange_circle: | Multi-method expansion |
| Company mode | :orange_circle: | Toggle completion framework |
| Auto-complete mode | :orange_circle: | Toggle auto-complete |
| Ido mode | :orange_circle: | Toggle interactive completion |
| Icomplete mode | :orange_circle: | Toggle incremental completion |
| Fido mode | :orange_circle: | Toggle fido completion |
| Fido vertical mode | :orange_circle: | Toggle fido vertical display |
| Savehist mode | :orange_circle: | Toggle history persistence |
| Recentf mode | :orange_circle: | Toggle recent files tracking |
| Recentf open files | :orange_circle: | Show recent files list |
| Saveplace mode | :orange_circle: | Remember cursor position per file |
| Global auto-revert mode | :orange_circle: | Toggle global auto-revert |
| Global hl-line mode | :orange_circle: | Toggle global line highlighting |
| Global display line numbers | :orange_circle: | Toggle global line numbers |
| Global visual-line mode | :orange_circle: | Toggle global word wrap |
| Delete-selection mode | :orange_circle: | Typing replaces selection |
| CUA mode | :orange_circle: | CUA keybindings (C-c/v/x) |
| Transient-mark mode | :orange_circle: | Toggle transient mark |
| Shift-select mode | :orange_circle: | Toggle shift-select |
| Set mark command | :orange_circle: | Set mark at point |
| Exchange point and mark | :orange_circle: | Swap cursor and mark |
| Pop mark | :orange_circle: | Pop mark from ring |
| Pop global mark | :orange_circle: | Pop from global mark ring |
| Push mark | :orange_circle: | Push mark to ring |
| Mark ring max | :orange_circle: | Show mark ring limit |
| Set mark command repeat | :orange_circle: | Set mark (repeatable) |
| Mark defun | :orange_circle: | Select top-level form |
| Narrow to defun | :orange_circle: | Narrow to top-level form |
| Flycheck mode | :orange_circle: | On-the-fly syntax checking |
| Flymake mode | :orange_circle: | Built-in syntax checking |
| Eldoc mode | :orange_circle: | Show docs in echo area |
| Which-function mode | :orange_circle: | Show current function name |
| Imenu | :orange_circle: | Navigate definitions in buffer |
| Imenu add to menubar | :orange_circle: | Add imenu to menu bar |
| Speedbar | :orange_circle: | File/code browser (placeholder) |
| Neotree | :orange_circle: | Tree file browser (placeholder) |
| Treemacs | :orange_circle: | Project tree browser (placeholder) |
| Project find file | :orange_circle: | Open file in project |
| Project switch to buffer | :orange_circle: | Switch project buffer |
| Project find regexp | :orange_circle: | Grep in project files |
| Project compile | :orange_circle: | Compile project |
| Project switch project | :orange_circle: | Switch to another project |
| Xref find definitions | :orange_circle: | Jump to definition |
| Xref find references | :orange_circle: | Find all references |
| Xref pop marker stack | :orange_circle: | Go back in xref history |
| Xref go back | :orange_circle: | Return from definition |
| Tags search | :orange_circle: | Search TAGS (placeholder) |
| Tags query replace | :orange_circle: | Replace in TAGS (placeholder) |

### Round 35

| Feature | Status | Notes |
|---------|--------|-------|
| Calc | :orange_circle: | Calculator buffer with expression input |
| Calc eval region | :orange_circle: | Evaluate selected region as calc expression |
| Calendar | :orange_circle: | Display calendar with current date |
| Diary insert entry | :orange_circle: | Add diary entry for today |
| Appt add | :orange_circle: | Add appointment with time and description |
| Display time | :orange_circle: | Show current time in echo area |
| Timeclock in | :orange_circle: | Clock in with timestamp |
| Timeclock out | :orange_circle: | Clock out with timestamp |
| Timeclock status | :orange_circle: | Show timeclock status |
| Compose mail | :orange_circle: | Open mail composition buffer |
| Rmail | :orange_circle: | Read mail client |
| Gnus | :orange_circle: | Usenet/mail reader |
| EWW | :orange_circle: | Emacs Web Wowser browser (placeholder) |
| EWW browse URL | :orange_circle: | Browse URL at point |
| SX search | :orange_circle: | StackExchange search |
| List processes | :orange_circle: | Display running processes |
| Serial term | :orange_circle: | Serial port terminal (placeholder) |
| Doc view mode | :orange_circle: | Document viewing mode (placeholder) |
| Dunnet | :orange_circle: | Text adventure game |
| Snake mode | :orange_circle: | Snake game |

### Round 36

| Feature | Status | Notes |
|---------|--------|-------|
| 2C-two-columns | :orange_circle: | Two-column editing mode |
| Image mode | :orange_circle: | Image display (placeholder) |
| Thumbs find thumb | :orange_circle: | Thumbnail browser (placeholder) |
| Life | :orange_circle: | Conway's Game of Life |
| ROT13 region | :orange_circle: | Apply ROT13 cipher to region |
| Butterfly | :orange_circle: | Butterfly command (easter egg) |
| Hanoi | :orange_circle: | Tower of Hanoi game |
| Bubbles | :orange_circle: | Bubbles puzzle game |
| 5x5 | :orange_circle: | 5x5 toggle puzzle |
| Landmark | :orange_circle: | Neural-net tree-planting game |
| Solitaire | :orange_circle: | Peg solitaire game |
| Cookie | :orange_circle: | Fortune cookie messages |
| Yow | :orange_circle: | Random Zippy quotes |
| Spook | :orange_circle: | Random surveillance keywords |
| Decipher | :orange_circle: | Substitution cipher analysis |
| Phases of moon | :orange_circle: | Current lunar phase |
| Sunrise sunset | :orange_circle: | Sunrise/sunset times |
| Lunar phases | :orange_circle: | Lunar phase cycle display |
| Facemenu set bold | :orange_circle: | Apply bold face |
| Facemenu set italic | :orange_circle: | Apply italic face |

### Round 37

| Feature | Status | Notes |
|---------|--------|-------|
| Facemenu set underline | :orange_circle: | Apply underline face |
| Describe theme | :orange_circle: | Show current theme details |
| Customize save all | :orange_circle: | Save all customizations |
| Display battery | :orange_circle: | Show battery status (placeholder) |
| Ruler mode | :orange_circle: | Toggle ruler display |
| Scroll bar mode | :orange_circle: | Toggle scroll bar |
| Menu bar mode | :orange_circle: | Toggle menu bar |
| Adaptive wrap prefix mode | :orange_circle: | Toggle adaptive line wrapping |
| Revert buffer all | :orange_circle: | Revert all file-visiting buffers |
| Skeleton insert | :orange_circle: | Insert named skeleton template |
| Auto insert mode | :orange_circle: | Auto-insert templates for new files |
| Copyright update | :orange_circle: | Update copyright year in buffer |
| Elint current buffer | :orange_circle: | Lint Emacs Lisp buffer |
| Checkdoc | :orange_circle: | Check documentation style |
| Package lint current buffer | :orange_circle: | Lint package conventions |
| Flymake goto next error | :orange_circle: | Jump to next Flymake error |
| Flymake goto prev error | :orange_circle: | Jump to previous Flymake error |
| Recompile | :orange_circle: | Repeat last compilation |
| Kill compilation | :orange_circle: | Kill running compilation |
| Grep find | :orange_circle: | Grep with find integration |

### Round 38

| Feature | Status | Notes |
|---------|--------|-------|
| Lgrep | :orange_circle: | Local grep with file glob |
| Occur rename buffer | :orange_circle: | Rename occur buffer |
| Highlight changes visible mode | :orange_circle: | Toggle change highlight visibility |
| Auto highlight symbol mode | :orange_circle: | Auto-highlight symbol at point |
| Beacon mode | :orange_circle: | Flash cursor on jump |
| Centered cursor mode | :orange_circle: | Keep cursor centered vertically |
| Zoom window | :orange_circle: | Zoom current window |
| Transpose frame | :orange_circle: | Swap horizontal/vertical splits |
| Flip frame | :orange_circle: | Flip window arrangement |
| Windmove swap states left | :orange_circle: | Swap window state leftward |
| Windmove swap states right | :orange_circle: | Swap window state rightward |
| Windmove swap states up | :orange_circle: | Swap window state upward |
| Windmove swap states down | :orange_circle: | Swap window state downward |
| Ace window | :orange_circle: | Quick window selection by number |
| Avy goto char | :orange_circle: | Jump to character with avy |
| Avy goto line | :orange_circle: | Jump to line with avy |
| Avy goto word | :orange_circle: | Jump to word with avy |
| Emacs version verbose | :orange_circle: | Detailed version information |
| Insert char by name | :orange_circle: | Insert Unicode character by name |
| Set input method | :orange_circle: | Set keyboard input method |

### Round 39

| Feature | Status | Notes |
|---------|--------|-------|
| Quoted insert verbose | :orange_circle: | Insert literal character by code |
| Describe input method | :orange_circle: | Describe an input method |
| List input methods | :orange_circle: | List available input methods |
| Describe coding system | :orange_circle: | Describe a coding system |
| List coding systems | :orange_circle: | List available coding systems |
| Set buffer file coding system | :orange_circle: | Set coding for current buffer |
| Recode region | :orange_circle: | Recode region between coding systems |
| Universal coding system argument | :orange_circle: | Specify coding for next command |
| Prefer coding system | :orange_circle: | Set preferred coding system |
| Describe language environment | :orange_circle: | Describe language environment |
| What cursor position verbose | :orange_circle: | Detailed character info at point |
| Display local help | :orange_circle: | Show help for thing at point |
| Info apropos | :orange_circle: | Search info documentation |
| Woman | :orange_circle: | Man page viewer (pure Lisp) |
| Shortdoc display group | :orange_circle: | Quick function reference by group |
| Find library | :orange_circle: | Find library file |
| List packages no fetch | :orange_circle: | List cached packages |
| Package autoremove | :orange_circle: | Remove unused packages |
| Package refresh no confirm | :orange_circle: | Refresh package archives |
| Report emacs bug | :orange_circle: | Compose bug report |

### Round 40

| Feature | Status | Notes |
|---------|--------|-------|
| ERC | :orange_circle: | IRC client |
| ERC TLS | :orange_circle: | IRC client with TLS |
| Elfeed | :orange_circle: | RSS/Atom feed reader |
| Debbugs GNU | :orange_circle: | GNU bug tracker browser |
| Bug hunter | :orange_circle: | Bisect init file for errors |
| Type break mode | :orange_circle: | Typing break reminders |
| Display line numbers relative | :orange_circle: | Relative line number display |
| Tab bar history back | :orange_circle: | Navigate tab history backward |
| Tab bar history forward | :orange_circle: | Navigate tab history forward |
| Icomplete vertical mode | :orange_circle: | Vertical minibuffer completion |
| Savehist mode toggle | :orange_circle: | Toggle minibuffer history saving |
| Winner undo redo | :orange_circle: | Undo/redo window configurations |
| Emacsclient mail | :orange_circle: | Compose mail via emacsclient |
| TRAMP cleanup all connections | :orange_circle: | Clean all remote connections |
| TRAMP cleanup this connection | :orange_circle: | Clean current remote connection |
| Auto save visited mode | :orange_circle: | Auto-save to visited file |
| Delete auto save files | :orange_circle: | Delete auto-save files |
| Make frame on monitor | :orange_circle: | Create frame on specific monitor |
| Clone frame | :orange_circle: | Clone current frame |
| Undelete frame | :orange_circle: | Restore deleted frame |

### Round 41

| Feature | Status | Notes |
|---------|--------|-------|
| Glasses mode toggle | :orange_circle: | Toggle camelCase separator display |
| Overwrite mode toggle | :orange_circle: | Toggle overwrite/insert mode |
| Quoted printable decode region | :orange_circle: | Decode quoted-printable encoding |
| Base64 encode region | :orange_circle: | Base64 encode selected region |
| Base64 decode region | :orange_circle: | Base64 decode selected region |
| Uuencode region | :orange_circle: | Uuencode selected region |
| Uudecode region | :orange_circle: | Uudecode selected region |
| Hexlify buffer | :orange_circle: | Convert buffer to hex representation |
| Dehexlify buffer | :orange_circle: | Convert hex back to text |
| Hexl find file | :orange_circle: | Open file in hex editor mode |
| Archive mode | :orange_circle: | View/extract archive contents |
| Tar mode | :orange_circle: | View/extract tar archives |
| Image dired | :orange_circle: | Browse image thumbnails (placeholder) |
| Thumbs dired | :orange_circle: | Thumbnail browser for dired |
| Dired do compress | :orange_circle: | Compress marked dired files |
| Dired do compress to | :orange_circle: | Compress marked files to target |
| Dired do async shell command | :orange_circle: | Async shell on marked files |
| Dired do find regexp | :orange_circle: | Search marked files by regexp |
| Dired do find regexp and replace | :orange_circle: | Search/replace in marked files |
| Dired do touch | :orange_circle: | Update timestamps on marked files |

### Round 42

| Feature | Status | Notes |
|---------|--------|-------|
| Ediff buffers | :orange_circle: | Compare two buffers |
| Ediff files | :orange_circle: | Compare two files |
| Ediff directories | :orange_circle: | Compare two directories |
| Ediff regions linewise | :orange_circle: | Compare regions line by line |
| Ediff windows linewise | :orange_circle: | Compare visible windows |
| Ediff merge files | :orange_circle: | Three-way merge of files |
| Ediff merge buffers | :orange_circle: | Three-way merge of buffers |
| Ediff patch file | :orange_circle: | Apply patch to file |
| Ediff revision | :orange_circle: | Compare file with VCS revision |
| Emerge files | :orange_circle: | Alternative merge tool |
| VC annotate show log | :orange_circle: | Show log from annotate |
| VC create tag | :orange_circle: | Create VCS tag |
| VC retrieve tag | :orange_circle: | Retrieve VCS tag |
| VC delete file | :orange_circle: | Delete file under version control |
| VC rename file | :orange_circle: | Rename file under version control |
| VC ignore | :orange_circle: | Add pattern to .gitignore |
| VC root diff | :orange_circle: | Diff from repository root |
| VC root log | :orange_circle: | Log from repository root |
| VC dir mark | :orange_circle: | Mark file in VC directory |
| VC dir unmark | :orange_circle: | Unmark file in VC directory |

### Round 43

| Feature | Status | Notes |
|---------|--------|-------|
| Org babel tangle | :orange_circle: | Extract code blocks to files |
| Org babel execute src block | :orange_circle: | Execute source block at point |
| Org babel execute buffer | :orange_circle: | Execute all source blocks |
| Org table create | :orange_circle: | Create new org table |
| Org table align | :orange_circle: | Align org table columns |
| Org table sort lines | :orange_circle: | Sort table rows |
| Org table sum | :orange_circle: | Sum numeric table column |
| Org table insert column | :orange_circle: | Insert table column |
| Org table delete column | :orange_circle: | Delete table column |
| Org table insert row | :orange_circle: | Insert table row |
| Org table kill row | :orange_circle: | Delete table row |
| Org clock in | :orange_circle: | Start time tracking |
| Org clock out | :orange_circle: | Stop time tracking |
| Org clock report | :orange_circle: | Generate clock report |
| Org timer start | :orange_circle: | Start countdown timer |
| Org timer stop | :orange_circle: | Stop timer |
| Org timer pause or continue | :orange_circle: | Pause/resume timer |
| Org agenda file to front | :orange_circle: | Add file to agenda list |
| Org agenda remove file | :orange_circle: | Remove file from agenda list |
| Org capture finalize | :orange_circle: | Finalize capture template |

### Round 44

| Feature | Status | Notes |
|---------|--------|-------|
| Org export dispatch | :orange_circle: | Export dispatcher menu |
| Org HTML export | :orange_circle: | Export org to HTML |
| Org LaTeX export to PDF | :orange_circle: | Export org to PDF via LaTeX |
| Org Markdown export | :orange_circle: | Export org to Markdown |
| Org ASCII export | :orange_circle: | Export org to plain text |
| Org publish project | :orange_circle: | Publish org project |
| Org refile | :orange_circle: | Refile heading to target |
| Org archive subtree | :orange_circle: | Archive completed subtree |
| Org set property | :orange_circle: | Set heading property |
| Org delete property | :orange_circle: | Delete heading property |
| Org columns | :orange_circle: | Column view of properties |
| Org insert link | :orange_circle: | Insert org link |
| Org store link | :orange_circle: | Store link to current location |
| Org open at point | :orange_circle: | Open link at point |
| Org toggle link display | :orange_circle: | Toggle link description display |
| Org footnote new | :orange_circle: | Insert new footnote |
| Org footnote action | :orange_circle: | Jump to footnote definition |
| Org sort | :orange_circle: | Sort org entries |
| Org sparse tree | :orange_circle: | Create sparse tree from search |
| Org match sparse tree | :orange_circle: | Sparse tree from tag/property match |

### Round 45

| Feature | Status | Notes |
|---------|--------|-------|
| Magit branch checkout | :orange_circle: | Checkout git branch |
| Magit branch create | :orange_circle: | Create new branch |
| Magit branch delete | :orange_circle: | Delete branch |
| Magit branch rename | :orange_circle: | Rename branch |
| Magit reset hard | :orange_circle: | Hard reset to commit |
| Magit reset soft | :orange_circle: | Soft reset to commit |
| Magit stash push | :orange_circle: | Stash current changes |
| Magit stash pop | :orange_circle: | Pop stashed changes |
| Magit stash list | :orange_circle: | List all stashes |
| Magit remote add | :orange_circle: | Add git remote |
| Magit remote remove | :orange_circle: | Remove git remote |
| Magit fetch all | :orange_circle: | Fetch from all remotes |
| Magit push current | :orange_circle: | Push current branch |
| Magit pull from upstream | :orange_circle: | Pull from upstream |
| Magit log current | :orange_circle: | Log for current branch |
| Magit log all | :orange_circle: | Log for all branches |
| Magit bisect start | :orange_circle: | Start git bisect |
| Magit bisect good | :orange_circle: | Mark commit as good |
| Magit bisect bad | :orange_circle: | Mark commit as bad |
| Magit bisect reset | :orange_circle: | Reset bisect session |

### Round 46

| Feature | Status | Notes |
|---------|--------|-------|
| LSP describe thing at point | :orange_circle: | Show LSP documentation |
| LSP find implementation | :orange_circle: | Jump to implementation |
| LSP workspace restart | :orange_circle: | Restart LSP server |
| LSP workspace shutdown | :orange_circle: | Shutdown LSP server |
| LSP organize imports | :orange_circle: | Auto-organize imports |
| LSP format region | :orange_circle: | Format selected region |
| LSP rename symbol | :orange_circle: | Rename symbol across project |
| LSP code actions | :orange_circle: | Show available code actions |
| LSP execute code action | :orange_circle: | Execute a code action |
| LSP signature help | :orange_circle: | Show function signature |
| LSP hover | :orange_circle: | Show hover information |
| LSP document highlight | :orange_circle: | Highlight symbol occurrences |
| LSP goto type definition | :orange_circle: | Jump to type definition |
| LSP treemacs symbols | :orange_circle: | Show symbols in tree view |
| LSP UI doc show | :orange_circle: | Show documentation popup |
| LSP UI peek find references | :orange_circle: | Peek at references |
| LSP headerline breadcrumb | :orange_circle: | Toggle breadcrumb display |
| LSP lens mode | :orange_circle: | Toggle code lens annotations |
| LSP diagnostics list | :orange_circle: | List all diagnostics |
| LSP toggle on type formatting | :orange_circle: | Toggle format-as-you-type |

### Round 47

| Feature | Status | Notes |
|---------|--------|-------|
| DAP debug | :orange_circle: | Start debug session |
| DAP breakpoint toggle | :orange_circle: | Toggle breakpoint at line |
| DAP breakpoint delete | :orange_circle: | Delete all breakpoints |
| DAP continue | :orange_circle: | Continue execution |
| DAP next | :orange_circle: | Step over |
| DAP step in | :orange_circle: | Step into function |
| DAP step out | :orange_circle: | Step out of function |
| DAP eval | :orange_circle: | Evaluate expression in debug |
| DAP UI inspect | :orange_circle: | Inspect variable |
| DAP disconnect | :orange_circle: | Disconnect debugger |
| DAP UI REPL | :orange_circle: | Debug REPL buffer |
| Next error follow minor mode | :orange_circle: | Auto-follow next-error |
| Flymake show buffer diagnostics | :orange_circle: | List buffer diagnostics |
| Flymake show project diagnostics | :orange_circle: | List project diagnostics |
| Flycheck list errors | :orange_circle: | List all flycheck errors |
| Flycheck next error | :orange_circle: | Jump to next error |
| Flycheck previous error | :orange_circle: | Jump to previous error |
| Flycheck verify setup | :orange_circle: | Verify checker configuration |
| Flycheck select checker | :orange_circle: | Select syntax checker |
| Flycheck describe checker | :orange_circle: | Describe checker details |

### Round 48

| Feature | Status | Notes |
|---------|--------|-------|
| Treemacs select window | :orange_circle: | Select treemacs window |
| Treemacs toggle | :orange_circle: | Toggle tree view |
| Treemacs add project | :orange_circle: | Add project to workspace |
| Treemacs remove project | :orange_circle: | Remove project from workspace |
| Treemacs rename project | :orange_circle: | Rename project |
| Treemacs collapse all | :orange_circle: | Collapse all tree nodes |
| Treemacs refresh | :orange_circle: | Refresh tree view |
| Treemacs create dir | :orange_circle: | Create directory |
| Treemacs create file | :orange_circle: | Create file |
| Treemacs delete | :orange_circle: | Delete item at point |
| NeoTree toggle | :orange_circle: | Toggle NeoTree |
| NeoTree show | :orange_circle: | Show NeoTree |
| NeoTree hide | :orange_circle: | Hide NeoTree |
| NeoTree refresh | :orange_circle: | Refresh NeoTree |
| NeoTree change root | :orange_circle: | Change NeoTree root |
| Centaur tabs mode | :orange_circle: | Toggle centaur tabs |
| Centaur tabs forward | :orange_circle: | Next tab |
| Centaur tabs backward | :orange_circle: | Previous tab |
| Centaur tabs forward group | :orange_circle: | Next tab group |
| Centaur tabs backward group | :orange_circle: | Previous tab group |

### Round 49

| Feature | Status | Notes |
|---------|--------|-------|
| Doom themes visual bell | :orange_circle: | Flash modeline on error |
| Ligature mode | :orange_circle: | Display font ligatures |
| Prettify symbols mode toggle | :orange_circle: | Replace symbols with Unicode |
| HL line range mode | :orange_circle: | Highlight line range |
| Mini frame mode | :orange_circle: | Minibuffer in child frame |
| Vertico mode toggle | :orange_circle: | Vertical completion UI |
| Corfu complete | :orange_circle: | Complete at point with corfu |
| Corfu quit | :orange_circle: | Close corfu popup |
| Cape line | :orange_circle: | Complete from buffer lines |
| Cape symbol | :orange_circle: | Complete symbols |
| Consult ripgrep | :orange_circle: | Search with ripgrep |
| Consult find | :orange_circle: | Find files with consult |
| Consult imenu | :orange_circle: | Browse imenu with consult |
| Consult bookmark | :orange_circle: | Browse bookmarks with consult |
| Consult recent file | :orange_circle: | Browse recent files |
| Consult yank pop | :orange_circle: | Browse kill ring |
| Consult theme | :orange_circle: | Switch theme with preview |
| Consult man | :orange_circle: | Browse man pages |
| Consult info | :orange_circle: | Browse info nodes |
| Embark collect | :orange_circle: | Collect candidates into buffer |

### Round 50

| Feature | Status | Notes |
|---------|--------|-------|
| Evil mode | :orange_circle: | Vim emulation layer |
| Evil normal state | :orange_circle: | Enter normal state |
| Evil insert state | :orange_circle: | Enter insert state |
| Evil visual state | :orange_circle: | Enter visual state |
| Evil ex | :orange_circle: | Ex command line |
| Evil search forward | :orange_circle: | Vim-style forward search |
| Evil search backward | :orange_circle: | Vim-style backward search |
| Evil window split | :orange_circle: | Horizontal window split |
| Evil window vsplit | :orange_circle: | Vertical window split |
| Evil quit | :orange_circle: | Vim-style quit |
| Evil local mode | :orange_circle: | Buffer-local evil mode |
| God mode | :orange_circle: | Modal editing without modifiers |
| God mode all | :orange_circle: | Global god mode |
| Boon mode | :orange_circle: | Ergonomic modal editing |
| Xah Fly Keys mode | :orange_circle: | Xah Fly Keys modal editing |
| Hydra zoom | :orange_circle: | Hydra-based zoom control |
| Transient append suffix | :orange_circle: | Add command to transient prefix |
| Which key show major mode | :orange_circle: | Show major mode bindings |
| General define key | :orange_circle: | Define key with general.el |
| Use package report | :orange_circle: | Report loaded packages |

### Round 51

| Feature | Status | Notes |
|---------|--------|-------|
| PDF view mode | :orange_circle: | PDF document viewer |
| PDF view goto page | :orange_circle: | Jump to specific page |
| PDF view next page | :orange_circle: | Next PDF page |
| PDF view previous page | :orange_circle: | Previous PDF page |
| PDF view fit page | :orange_circle: | Fit page to window |
| PDF view search | :orange_circle: | Search within PDF |
| PDF view midnight mode | :orange_circle: | Dark mode for PDF viewing |
| Nov mode | :orange_circle: | EPUB reader |
| Nov next document | :orange_circle: | Next EPUB chapter |
| Nov previous document | :orange_circle: | Previous EPUB chapter |
| DjVu mode | :orange_circle: | DjVu document viewer |
| Notmuch search | :orange_circle: | Search notmuch mail |
| Notmuch show | :orange_circle: | Show notmuch message |
| Notmuch tree | :orange_circle: | Threaded mail view |
| Wanderlust | :orange_circle: | Mail/news reader |
| Mew | :orange_circle: | Mail environment |
| VM visit folder | :orange_circle: | Visit VM mail folder |
| BBDB | :orange_circle: | Contact database |
| BBDB search | :orange_circle: | Search contacts |
| EBDB | :orange_circle: | Enhanced contact database |

### Round 52

| Feature | Status | Notes |
|---------|--------|-------|
| Docker volumes | :orange_circle: | List Docker volumes |
| Docker compose up | :orange_circle: | Start Docker Compose services |
| Docker compose down | :orange_circle: | Stop Docker Compose services |
| Kubernetes overview | :orange_circle: | K8s cluster overview |
| Kubel | :orange_circle: | Kubernetes interface |
| Terraform fmt | :orange_circle: | Format Terraform files |
| Terraform validate | :orange_circle: | Validate Terraform config |
| Ansible vault encrypt | :orange_circle: | Encrypt with Ansible Vault |
| Ansible vault decrypt | :orange_circle: | Decrypt with Ansible Vault |
| Verb send request | :orange_circle: | Send HTTP request at point |
| SQL SQLite | :orange_circle: | Connect to SQLite database |
| SQL PostgreSQL | :orange_circle: | Connect to PostgreSQL |
| SQL MySQL | :orange_circle: | Connect to MySQL |
| Eshell command | :orange_circle: | Run eshell command |
| Async shell command no window | :orange_circle: | Async command without buffer |
| Direnv update environment | :orange_circle: | Update env from .envrc |
| Nix mode | :orange_circle: | Nix expression editing |
| Nix REPL | :orange_circle: | Interactive Nix REPL |
| Guix mode | :orange_circle: | GNU Guix editing |
| Vagrant up | :orange_circle: | Start Vagrant VM |

### Round 53

| Feature | Status | Notes |
|---------|--------|-------|
| EIN notebooklist open | :orange_circle: | Open Jupyter notebook list |
| EIN run | :orange_circle: | Run notebook cell |
| EIN worksheet execute cell | :orange_circle: | Execute worksheet cell |
| Jupyter run REPL | :orange_circle: | Start Jupyter REPL |
| Jupyter eval line | :orange_circle: | Evaluate current line |
| Jupyter eval region | :orange_circle: | Evaluate selected region |
| CIDER jack in | :orange_circle: | Connect to Clojure REPL |
| CIDER eval last sexp | :orange_circle: | Evaluate last s-expression |
| CIDER eval buffer | :orange_circle: | Evaluate entire buffer |
| SLIME eval last expression | :orange_circle: | Evaluate last CL expression |
| SLIME compile defun | :orange_circle: | Compile current defun |
| SLY eval last expression | :orange_circle: | Evaluate last CL expression (SLY) |
| SLY compile defun | :orange_circle: | Compile current defun (SLY) |
| Geiser | :orange_circle: | Scheme interaction REPL |
| Geiser eval last sexp | :orange_circle: | Evaluate last Scheme sexp |
| Geiser eval buffer | :orange_circle: | Evaluate entire Scheme buffer |
| Run Python | :orange_circle: | Start Python shell |
| Python shell send region | :orange_circle: | Send region to Python |
| Run Ruby | :orange_circle: | Start Ruby IRB |
| Inf Ruby | :orange_circle: | Inferior Ruby process |

### Round 54

| Feature | Status | Notes |
|---------|--------|-------|
| Run Haskell | :orange_circle: | Start GHCi REPL |
| Haskell interactive mode | :orange_circle: | Haskell interaction |
| Haskell process load file | :orange_circle: | Load file into GHCi |
| Run Rust | :orange_circle: | Run Rust project |
| Cargo process build | :orange_circle: | Cargo build |
| Cargo process test | :orange_circle: | Cargo test |
| Cargo process run | :orange_circle: | Cargo run |
| Cargo process clippy | :orange_circle: | Cargo clippy linter |
| Go run | :orange_circle: | Run Go file |
| Go test current file | :orange_circle: | Test current Go file |
| Go test current function | :orange_circle: | Test current Go function |
| Elixir mode | :orange_circle: | Elixir editing mode |
| Alchemist IEx run | :orange_circle: | Start Elixir IEx REPL |
| Mix compile | :orange_circle: | Compile Elixir project |
| Erlang shell | :orange_circle: | Start Erlang shell |
| LFE mode | :orange_circle: | Lisp Flavoured Erlang |
| Tuareg run OCaml | :orange_circle: | Start OCaml toplevel |
| Merlin locate | :orange_circle: | OCaml definition lookup |
| Proof General | :orange_circle: | Theorem prover interface |
| Coq compile | :orange_circle: | Compile Coq file |

### Round 55

| Feature | Status | Notes |
|---------|--------|-------|
| Tide jump to definition | :orange_circle: | TypeScript definition jump |
| Tide references | :orange_circle: | TypeScript references |
| Web mode | :orange_circle: | HTML/CSS/JS mixed editing |
| Emmet expand line | :orange_circle: | Expand Emmet abbreviation |
| Emmet preview | :orange_circle: | Preview Emmet expansion |
| SCSS mode | :orange_circle: | SCSS editing |
| LESS CSS mode | :orange_circle: | LESS CSS editing |
| JSON mode | :orange_circle: | JSON editing |
| JSON pretty print buffer | :orange_circle: | Pretty-print JSON buffer |
| JSON reformat region | :orange_circle: | Reformat JSON region |
| GraphQL mode | :orange_circle: | GraphQL editing |
| Protobuf mode | :orange_circle: | Protocol Buffers editing |
| CMake mode | :orange_circle: | CMake editing |
| Meson mode | :orange_circle: | Meson build editing |
| Bazel mode | :orange_circle: | Bazel build editing |
| Zig mode | :orange_circle: | Zig language editing |
| Swift mode | :orange_circle: | Swift editing |
| Kotlin mode | :orange_circle: | Kotlin editing |
| Scala mode | :orange_circle: | Scala editing |
| Groovy mode | :orange_circle: | Groovy editing |

### Round 56 — VC Extensions & Projectile

| Feature | Status | Notes |
|---|---|---|
| ediff-regions | :orange_circle: | Compare two selected regions |
| smerge-mode | :orange_circle: | Merge conflict resolution mode |
| vc-annotate-show | :orange_circle: | Show file annotations (blame) |
| vc-log-incoming | :orange_circle: | Show incoming remote changes |
| vc-log-outgoing | :orange_circle: | Show outgoing local changes |
| vc-revision-other-window | :orange_circle: | View file at specific revision |
| projectile-find-file-other-window | :orange_circle: | Open project file in other window |
| projectile-switch-open-project | :orange_circle: | Switch between open projects |
| projectile-grep | :orange_circle: | Grep across project files |
| projectile-replace | :orange_circle: | Find and replace across project |
| projectile-run-shell | :orange_circle: | Shell in project root |
| projectile-compile-project | :orange_circle: | Compile project with command |
| projectile-test-project | :orange_circle: | Run project tests |
| projectile-regenerate-tags | :orange_circle: | Regenerate TAGS file |
| projectile-find-tag | :orange_circle: | Jump to tag definition |
| projectile-kill-buffers | :orange_circle: | Kill all project buffers |
| projectile-invalidate-cache | :orange_circle: | Invalidate project cache |
| projectile-recentf | :orange_circle: | Recent project files |

### Round 57 — Display & Text Manipulation

| Feature | Status | Notes |
|---|---|---|
| justify-current-line | :orange_circle: | Justify text on current line |
| center-paragraph | :orange_circle: | Center all lines in paragraph |
| toggle-truncate-lines | :orange_circle: | Toggle line truncation vs wrapping |
| adaptive-wrap-mode | :orange_circle: | Smart visual line wrapping |
| hl-line-mode | :orange_circle: | Highlight current line |
| show-trailing-whitespace | :orange_circle: | Visualize trailing whitespace |
| indicate-empty-lines | :orange_circle: | Mark empty lines at buffer end |
| indicate-buffer-boundaries | :orange_circle: | Show buffer boundary indicators |
| fringe-mode | :orange_circle: | Toggle fringe display |
| text-scale-set | :orange_circle: | Set text scale to specific value |
| subword-transpose | :orange_circle: | Transpose subwords in camelCase |
| capitalize-dwim | :orange_circle: | Smart capitalize (DWIM) |
| upcase-dwim | :orange_circle: | Smart upcase (DWIM) |
| downcase-dwim | :orange_circle: | Smart downcase (DWIM) |
| pulse-momentary-highlight-region | :orange_circle: | Flash highlight on region |
| cursor-sensor-mode | :orange_circle: | React to cursor entering/leaving text |
| cua-selection-mode | :orange_circle: | CUA-style C-x/C-c/C-v selection |
| rectangle-mark-mode | :orange_circle: | Rectangular region selection |
| auto-revert-tail-mode | :orange_circle: | Tail file like tail -f |
| sgml-tag | :orange_circle: | Insert matched SGML/HTML tags |
| reveal-mode | :orange_circle: | Show invisible text at point |
| glasses-separator | :orange_circle: | Set glasses mode separator character |

### Round 58 — Registers, Bookmarks & Keyboard Macros

| Feature | Status | Notes |
|---|---|---|
| register-to-point | :orange_circle: | Save point position to register |
| number-to-register | :orange_circle: | Store number in register |
| window-configuration-to-register | :orange_circle: | Save window layout to register |
| frameset-to-register | :orange_circle: | Save frameset to register |
| bookmark-jump-other-window | :orange_circle: | Jump to bookmark in other window |
| bookmark-bmenu-list | :orange_circle: | Display bookmark menu |
| bookmark-relocate | :orange_circle: | Relocate bookmark to new file |
| bookmark-insert-location | :orange_circle: | Insert bookmark's file location |
| bookmark-insert | :orange_circle: | Insert bookmark's file contents |
| apply-macro-to-region-lines | :orange_circle: | Run macro on each line in region |
| name-last-kbd-macro | :orange_circle: | Name the last keyboard macro |
| edit-last-kbd-macro | :orange_circle: | Edit last keyboard macro |
| call-last-kbd-macro | :orange_circle: | Execute last keyboard macro |
| kmacro-set-counter | :orange_circle: | Set macro counter value |
| kmacro-add-counter | :orange_circle: | Add to macro counter |
| kmacro-set-format | :orange_circle: | Set macro counter format string |
| kmacro-cycle-ring-next | :orange_circle: | Cycle to next macro in ring |
| kmacro-cycle-ring-previous | :orange_circle: | Cycle to previous macro in ring |
| kmacro-edit-lossage | :orange_circle: | Edit recent keystrokes as macro |
| kmacro-step-edit-macro | :orange_circle: | Step through macro interactively |

### Round 59 — Help, Info & Customize System

| Feature | Status | Notes |
|---|---|---|
| describe-current-coding-system | :orange_circle: | Show current coding system |
| describe-font | :orange_circle: | Describe current font |
| describe-text-properties | :orange_circle: | Show text properties at point |
| apropos-value | :orange_circle: | Search by variable values |
| info-emacs-key | :orange_circle: | Look up key in Info manual |
| info-display-manual | :orange_circle: | Display a specific Info manual |
| info-lookup-symbol | :orange_circle: | Look up symbol in Info |
| info-lookup-file | :orange_circle: | Look up file in Info |
| finder-commentary | :orange_circle: | Search packages by commentary |
| customize-browse | :orange_circle: | Browse all customization groups |
| customize-changed | :orange_circle: | Show changed options |
| customize-saved | :orange_circle: | Show saved options |
| customize-rogue | :orange_circle: | Show options set outside customize |
| customize-apropos | :orange_circle: | Search customization options |
| customize-option | :orange_circle: | Customize a specific option |
| customize-face-other-window | :orange_circle: | Customize face in other window |
| customize-set-variable | :orange_circle: | Set variable value |
| customize-mark-to-save | :orange_circle: | Mark settings for saving |
| customize-save-customized | :orange_circle: | Save all customized settings |
| customize-unsaved | :orange_circle: | Show unsaved options |
| customize-set-value | :orange_circle: | Set option value directly |

### Round 60 — Dired Extensions

| Feature | Status | Notes |
|---|---|---|
| dired-do-isearch | :orange_circle: | Isearch in marked files |
| dired-do-isearch-regexp | :orange_circle: | Regexp isearch in marked files |
| dired-do-print | :orange_circle: | Print marked files |
| dired-do-redisplay | :orange_circle: | Refresh dired listing |
| dired-create-empty-file | :orange_circle: | Create new empty file |
| dired-toggle-read-only | :orange_circle: | Toggle wdired editable mode |
| dired-hide-details-mode | :orange_circle: | Toggle file detail visibility |
| dired-omit-mode | :orange_circle: | Hide dotfiles and backups |
| dired-narrow | :orange_circle: | Filter dired by pattern |
| dired-ranger-copy | :orange_circle: | Ranger-style copy to clipboard |
| dired-ranger-paste | :orange_circle: | Ranger-style paste from clipboard |
| dired-ranger-move | :orange_circle: | Ranger-style move from clipboard |
| dired-collapse-mode | :orange_circle: | Collapse single-child directories |
| dired-git-info-mode | :orange_circle: | Show git info in dired listing |
| dired-do-eww | :orange_circle: | Open marked files in EWW browser |
| dired-preview-mode | :orange_circle: | Preview files on cursor movement |
| dired-rsync | :orange_circle: | Rsync marked files to destination |
| dired-du-mode | :orange_circle: | Show directory sizes |
| dired-filter-mode | :orange_circle: | Interactive file filtering |
| dired-recent | :orange_circle: | Show recently visited directories |

### Round 61 — Window Management & Tab Bar

| Feature | Status | Notes |
|---|---|---|
| windmove-display-left | :orange_circle: | Display buffer in left window |
| windmove-display-right | :orange_circle: | Display buffer in right window |
| windmove-display-up | :orange_circle: | Display buffer in upper window |
| windmove-display-down | :orange_circle: | Display buffer in lower window |
| window-toggle-side-windows | :orange_circle: | Toggle side windows |
| tear-off-window | :orange_circle: | Move window to new frame |
| tab-bar-new-tab | :orange_circle: | Create new tab |
| tab-bar-close-tab | :orange_circle: | Close current tab |
| tab-bar-close-other-tabs | :orange_circle: | Close all other tabs |
| tab-bar-rename-tab | :orange_circle: | Rename current tab |
| tab-bar-move-tab | :orange_circle: | Move tab to position |
| tab-bar-select-tab | :orange_circle: | Select tab by number |
| tab-bar-switch-to-next-tab | :orange_circle: | Switch to next tab |
| tab-bar-switch-to-prev-tab | :orange_circle: | Switch to previous tab |
| tab-bar-undo-close-tab | :orange_circle: | Restore last closed tab |
| tab-bar-detach-tab | :orange_circle: | Detach tab to new frame |
| tab-bar-move-tab-to-frame | :orange_circle: | Move tab to another frame |

### Round 62 — Org Agenda

| Feature | Status | Notes |
|---|---|---|
| org-agenda-day-view | :orange_circle: | Single day agenda view |
| org-agenda-week-view | :orange_circle: | Week agenda view |
| org-agenda-month-view | :orange_circle: | Month agenda view |
| org-agenda-year-view | :orange_circle: | Year agenda view |
| org-agenda-fortnight-view | :orange_circle: | Two-week agenda view |
| org-agenda-list | :orange_circle: | Show agenda list |
| org-agenda-todo-list | :orange_circle: | Global TODO list |
| org-agenda-tags-view | :orange_circle: | Filter by tags |
| org-agenda-set-restriction-lock | :orange_circle: | Restrict agenda to subtree |
| org-agenda-remove-restriction-lock | :orange_circle: | Remove restriction lock |
| org-agenda-redo | :orange_circle: | Refresh agenda |
| org-agenda-filter-by-tag | :orange_circle: | Filter by tag |
| org-agenda-filter-by-category | :orange_circle: | Filter by category |
| org-agenda-filter-by-effort | :orange_circle: | Filter by effort estimate |
| org-agenda-filter-by-regexp | :orange_circle: | Filter by regexp |
| org-agenda-clockreport-mode | :orange_circle: | Toggle clock report |
| org-agenda-log-mode | :orange_circle: | Toggle log mode |
| org-agenda-entry-text-mode | :orange_circle: | Toggle entry text display |
| org-agenda-follow-mode | :orange_circle: | Toggle follow mode |
| org-agenda-columns | :orange_circle: | Toggle column view |

### Round 63 — Magit: Worktrees, Submodules, Notes & Patches

| Feature | Status | Notes |
|---|---|---|
| magit-worktree-checkout | :orange_circle: | Checkout branch in worktree |
| magit-worktree-create | :orange_circle: | Create new worktree |
| magit-worktree-delete | :orange_circle: | Delete worktree |
| magit-worktree-status | :orange_circle: | Show worktree status |
| magit-submodule-add | :orange_circle: | Add git submodule |
| magit-submodule-update | :orange_circle: | Update submodules |
| magit-submodule-sync | :orange_circle: | Sync submodule URLs |
| magit-submodule-remove | :orange_circle: | Remove submodule |
| magit-notes-edit | :orange_circle: | Edit git note on commit |
| magit-notes-remove | :orange_circle: | Remove git note |
| magit-cherry | :orange_circle: | Show cherry commits |
| magit-cherry-apply | :orange_circle: | Apply cherry commit |
| magit-reflog | :orange_circle: | Show reflog for ref |
| magit-reflog-head | :orange_circle: | Show HEAD reflog |
| magit-reflog-other | :orange_circle: | Show reflog for other ref |
| magit-patch-create | :orange_circle: | Create patch from range |
| magit-patch-apply | :orange_circle: | Apply patch file |
| magit-bundle-create | :orange_circle: | Create git bundle |
| magit-remote-prune | :orange_circle: | Prune stale remote branches |

### Round 64 — ERC, RCIRC & Elfeed

| Feature | Status | Notes |
|---|---|---|
| erc-track-mode | :orange_circle: | Track channel activity |
| erc-join-channel | :orange_circle: | Join IRC channel |
| erc-part-channel | :orange_circle: | Leave IRC channel |
| erc-nick | :orange_circle: | Change IRC nickname |
| erc-quit | :orange_circle: | Disconnect from server |
| erc-list-channels | :orange_circle: | List server channels |
| erc-whois | :orange_circle: | WHOIS query |
| erc-autojoin-mode | :orange_circle: | Auto-join channels on connect |
| erc-fill-mode | :orange_circle: | Fill/wrap messages |
| rcirc | :orange_circle: | Start RCIRC client |
| rcirc-connect | :orange_circle: | Connect to IRC server |
| rcirc-track-mode | :orange_circle: | Track RCIRC activity |
| newsticker-treeview | :orange_circle: | Tree view of news feeds |
| elfeed-search | :orange_circle: | Browse feed entries |
| elfeed-update | :orange_circle: | Update all feeds |
| elfeed-add-feed | :orange_circle: | Add RSS/Atom feed |
| elfeed-show-entry | :orange_circle: | Show feed entry |
| elfeed-tag | :orange_circle: | Tag feed entry |
| elfeed-untag | :orange_circle: | Remove tag from entry |
| elfeed-search-set-filter | :orange_circle: | Set search filter |

### Round 65 — Treemacs, Neotree & Navigation

| Feature | Status | Notes |
|---|---|---|
| treemacs-add-project-to-workspace | :orange_circle: | Add project to treemacs workspace |
| treemacs-remove-project-from-workspace | :orange_circle: | Remove project from workspace |
| treemacs-collapse-project | :orange_circle: | Collapse project tree |
| treemacs-switch-workspace | :orange_circle: | Switch treemacs workspace |
| treemacs-create-workspace | :orange_circle: | Create new workspace |
| treemacs-delete-workspace | :orange_circle: | Delete workspace |
| treemacs-rename-workspace | :orange_circle: | Rename workspace |
| treemacs-edit-workspaces | :orange_circle: | Edit workspace config |
| neotree-find | :orange_circle: | Reveal current file in neotree |
| neotree-dir | :orange_circle: | Open directory in neotree |
| neotree-hidden-file-toggle | :orange_circle: | Toggle hidden files |
| imenu-list | :orange_circle: | Show buffer symbols list |
| imenu-list-smart-toggle | :orange_circle: | Toggle imenu list |
| speedbar-toggle | :orange_circle: | Toggle speedbar |
| speedbar-get-focus | :orange_circle: | Focus speedbar |
| speedbar-update | :orange_circle: | Update speedbar |
| all-the-icons-dired-mode | :orange_circle: | Icons in dired |
| all-the-icons-ibuffer-mode | :orange_circle: | Icons in ibuffer |
| nerd-icons-dired-mode | :orange_circle: | Nerd font icons in dired |

### Round 66 — Edebug, ERT, Flycheck & Package Tools

| Feature | Status | Notes |
|---|---|---|
| edebug-defun | :orange_circle: | Instrument defun for debugging |
| edebug-all-defs | :orange_circle: | Instrument all defs on eval |
| edebug-all-forms | :orange_circle: | Instrument all forms on eval |
| edebug-eval-top-level-form | :orange_circle: | Eval top-level form with edebug |
| edebug-on-entry | :orange_circle: | Break on function entry |
| edebug-cancel-on-entry | :orange_circle: | Cancel break on entry |
| ert-run-tests-interactively | :orange_circle: | Run ERT tests interactively |
| ert-describe-test | :orange_circle: | Describe ERT test |
| ert-results-pop-to-timings | :orange_circle: | Show test timings |
| ert-delete-all-tests | :orange_circle: | Delete all test definitions |
| buttercup-run-at-point | :orange_circle: | Run Buttercup test at point |
| package-reinstall | :orange_circle: | Reinstall a package |
| package-recompile | :orange_circle: | Recompile a package |
| flycheck-compile | :orange_circle: | Run checker as compilation |
| flycheck-explain-error-at-point | :orange_circle: | Explain error at point |
| flycheck-disable-checker | :orange_circle: | Disable a checker |
| flycheck-set-checker-executable | :orange_circle: | Set checker executable path |
| flycheck-copy-errors-as-kill | :orange_circle: | Copy errors to kill ring |
| flycheck-buffer | :orange_circle: | Check current buffer |
| flycheck-clear | :orange_circle: | Clear all errors |

### Round 67 — Isearch Extensions & Search Tools

| Feature | Status | Notes |
|---|---|---|
| isearch-toggle-lax-whitespace | :orange_circle: | Toggle lax whitespace matching |
| isearch-toggle-case-fold | :orange_circle: | Toggle case sensitivity |
| isearch-toggle-invisible | :orange_circle: | Toggle invisible text search |
| isearch-toggle-word | :orange_circle: | Toggle word search mode |
| isearch-toggle-symbol | :orange_circle: | Toggle symbol search mode |
| isearch-yank-word-or-char | :orange_circle: | Yank word/char into search |
| isearch-yank-line | :orange_circle: | Yank rest of line into search |
| isearch-yank-kill | :orange_circle: | Yank kill ring into search |
| isearch-del-char | :orange_circle: | Delete char from search string |
| isearch-describe-bindings | :orange_circle: | Show isearch bindings |
| occur-mode-goto-occurrence | :orange_circle: | Jump to occur match |
| multi-occur-in-matching-buffers | :orange_circle: | Multi-occur in matching buffers |
| wgrep-abort-changes | :orange_circle: | Abort wgrep changes |
| wgrep-save-all-buffers | :orange_circle: | Save all wgrep buffers |
| deadgrep | :orange_circle: | Fast ripgrep-based search |
| visual-regexp | :orange_circle: | Visual regexp highlighting |
| visual-regexp-mc | :orange_circle: | Visual regexp with multiple cursors |
| anzu-query-replace | :orange_circle: | Anzu search-and-replace |
| anzu-replace-at-cursor-thing | :orange_circle: | Replace symbol at cursor |
| color-rg-search-input | :orange_circle: | Color-rg interactive search |

### Round 68 — Vertico, Corfu, Cape & Consult Extensions

| Feature | Status | Notes |
|---|---|---|
| vertico-flat-mode | :orange_circle: | Flat completion display |
| vertico-grid-mode | :orange_circle: | Grid completion display |
| vertico-reverse-mode | :orange_circle: | Bottom-up completion |
| vertico-buffer-mode | :orange_circle: | Buffer-based completion |
| vertico-multiform-mode | :orange_circle: | Per-command display styles |
| vertico-unobtrusive-mode | :orange_circle: | Minimal completion UI |
| corfu-history-mode | :orange_circle: | History-based completion sorting |
| corfu-popupinfo-mode | :orange_circle: | Popup info for completions |
| corfu-quick-insert | :orange_circle: | Quick insert completion |
| corfu-doc-toggle | :orange_circle: | Toggle documentation popup |
| cape-keyword | :orange_circle: | Complete programming keywords |
| cape-abbrev | :orange_circle: | Complete abbreviations |
| cape-dict | :orange_circle: | Complete from dictionary |
| cape-elisp-block | :orange_circle: | Complete Elisp in org blocks |
| cape-tex | :orange_circle: | Complete TeX symbols |
| cape-sgml | :orange_circle: | Complete SGML entities |
| consult-line-multi | :orange_circle: | Search lines across buffers |
| consult-keep-lines | :orange_circle: | Keep matching lines |
| consult-focus-lines | :orange_circle: | Focus on matching lines |

### Round 69 — Eval, Tracing, Profiling & Dev Tools

| Feature | Status | Notes |
|---|---|---|
| eval-expression | :orange_circle: | Evaluate expression interactively |
| eval-buffer | :orange_circle: | Evaluate entire buffer |
| ielm | :orange_circle: | Interactive Emacs Lisp mode |
| debug-on-entry | :orange_circle: | Break on function entry |
| cancel-debug-on-entry | :orange_circle: | Cancel debug on entry |
| trace-function | :orange_circle: | Trace function calls |
| untrace-function | :orange_circle: | Stop tracing function |
| untrace-all | :orange_circle: | Remove all traces |
| elp-instrument-function | :orange_circle: | Profile a function |
| elp-instrument-package | :orange_circle: | Profile a package |
| elp-reset-all | :orange_circle: | Reset profiling data |
| benchmark-run-compiled | :orange_circle: | Benchmark compiled expression |
| macrostep-expand | :orange_circle: | Step through macro expansion |
| highlight-defined-mode | :orange_circle: | Highlight defined symbols |
| nameless-mode | :orange_circle: | Hide package prefix in code |
| suggest | :orange_circle: | Suggest functions for transformation |
| aggressive-completion-mode | :orange_circle: | Auto-complete aggressively |
| pp-eval-expression | :orange_circle: | Pretty-print eval result |
| pp-eval-last-sexp | :orange_circle: | Pretty-print last sexp |
| pp-macroexpand-last-sexp | :orange_circle: | Pretty-print macro expansion |

### Round 70 — YASnippet, Tempel & Abbreviations

| Feature | Status | Notes |
|---|---|---|
| yasnippet-new-snippet | :orange_circle: | Create new snippet |
| yasnippet-visit-snippet-file | :orange_circle: | Visit snippet source file |
| yasnippet-insert-snippet | :orange_circle: | Insert snippet by name |
| yasnippet-expand | :orange_circle: | Expand snippet at point |
| yasnippet-reload-all | :orange_circle: | Reload all snippet tables |
| yasnippet-describe-tables | :orange_circle: | Show snippet tables |
| tempel-insert | :orange_circle: | Insert Tempel template |
| tempel-expand | :orange_circle: | Expand template at point |
| tempel-complete | :orange_circle: | Complete template name |
| tempel-next | :orange_circle: | Next template field |
| tempel-previous | :orange_circle: | Previous template field |
| tempo-forward-mark | :orange_circle: | Jump to next tempo mark |
| tempo-backward-mark | :orange_circle: | Jump to previous tempo mark |
| edit-abbrevs | :orange_circle: | Edit abbreviation table |
| write-abbrev-file | :orange_circle: | Write abbrevs to file |
| read-abbrev-file | :orange_circle: | Read abbrevs from file |
| inverse-add-global-abbrev | :orange_circle: | Add global abbrev inversely |
| inverse-add-mode-abbrev | :orange_circle: | Add mode abbrev inversely |
| insert-abbrevs | :orange_circle: | Insert abbrev table into buffer |
| kill-all-abbrevs | :orange_circle: | Remove all abbreviations |

### Round 71 — Compilation, Comint & Shell

| Feature | Status | Notes |
|---|---|---|
| compilation-next-file | :orange_circle: | Next file in compilation output |
| compilation-previous-file | :orange_circle: | Previous file in compilation output |
| comint-send-input | :orange_circle: | Send input to subprocess |
| comint-send-eof | :orange_circle: | Send EOF to subprocess |
| comint-interrupt-subjob | :orange_circle: | Interrupt subprocess (C-c) |
| comint-stop-subjob | :orange_circle: | Stop subprocess (C-z) |
| comint-quit-subjob | :orange_circle: | Quit subprocess (C-\) |
| comint-clear-buffer | :orange_circle: | Clear comint buffer |
| comint-history-isearch-backward | :orange_circle: | Search history backward |
| comint-dynamic-complete | :orange_circle: | Dynamic completion |
| comint-previous-matching-input | :orange_circle: | Previous matching input |
| comint-next-matching-input | :orange_circle: | Next matching input |
| comint-run | :orange_circle: | Run command in comint buffer |
| comint-show-output | :orange_circle: | Show last output |
| shell-resync-dirs | :orange_circle: | Resync directory tracking |
| shell-dirtrack-mode | :orange_circle: | Shell directory tracking |
| dirtrack-mode | :orange_circle: | Directory tracking mode |
| comint-truncate-buffer | :orange_circle: | Truncate comint buffer |
| comint-write-output | :orange_circle: | Write output to file |

### Round 72 — Face Menu, Font-Lock & Highlighting

| Feature | Status | Notes |
|---|---|---|
| facemenu-set-foreground | :orange_circle: | Set text foreground color |
| facemenu-set-background | :orange_circle: | Set text background color |
| facemenu-set-face | :orange_circle: | Apply named face to region |
| facemenu-set-intangible | :orange_circle: | Make region intangible |
| facemenu-set-invisible | :orange_circle: | Make region invisible |
| facemenu-remove-all | :orange_circle: | Remove all text properties |
| facemenu-remove-face-props | :orange_circle: | Remove face properties |
| set-face-attribute | :orange_circle: | Set face attribute |
| set-face-foreground | :orange_circle: | Set face foreground |
| set-face-background | :orange_circle: | Set face background |
| set-face-bold-p | :orange_circle: | Toggle face bold |
| set-face-italic-p | :orange_circle: | Toggle face italic |
| color-name-to-rgb | :orange_circle: | Convert color name to RGB |
| highlight-parentheses-mode | :orange_circle: | Highlight surrounding parens |
| prism-mode | :orange_circle: | Depth-based code coloring |
| prism-whitespace-mode | :orange_circle: | Prism for whitespace |
| fontify-face-mode | :orange_circle: | Show face names in color |
| font-lock-studio | :orange_circle: | Interactive font-lock debugger |
| font-lock-profiler | :orange_circle: | Profile font-lock performance |
| ov-highlight-mode | :orange_circle: | Overlay-based highlighting |

### Round 73 — Avy & Ace Navigation

| Feature | Status | Notes |
|---|---|---|
| avy-goto-char-2 | :orange_circle: | Jump to 2-character sequence |
| avy-goto-word-0 | :orange_circle: | Jump to any word start |
| avy-goto-word-1 | :orange_circle: | Jump to word by first char |
| avy-resume | :orange_circle: | Resume last avy command |
| avy-isearch | :orange_circle: | Jump to isearch candidate |
| avy-goto-end-of-line | :orange_circle: | Jump to end of any line |
| avy-goto-subword-0 | :orange_circle: | Jump to subword |
| avy-move-line | :orange_circle: | Move line via avy |
| avy-move-region | :orange_circle: | Move region via avy |
| avy-copy-line | :orange_circle: | Copy line via avy |
| avy-copy-region | :orange_circle: | Copy region via avy |
| avy-kill-whole-line | :orange_circle: | Kill whole line via avy |
| avy-kill-region | :orange_circle: | Kill region via avy |
| avy-kill-ring-save-whole-line | :orange_circle: | Save line to kill ring via avy |
| avy-kill-ring-save-region | :orange_circle: | Save region to kill ring via avy |
| ace-swap-window | :orange_circle: | Swap windows via ace |
| ace-delete-window | :orange_circle: | Delete window via ace |
| ace-maximize-window | :orange_circle: | Maximize window via ace |
| ace-select-window | :orange_circle: | Select window via ace |
| ace-display-buffer | :orange_circle: | Display buffer in ace window |

### Round 74 — Paredit & Smartparens

| Feature | Status | Notes |
|---|---|---|
| paredit-forward-slurp-sexp | :orange_circle: | Slurp next sexp into current |
| paredit-backward-slurp-sexp | :orange_circle: | Slurp previous sexp into current |
| paredit-forward-barf-sexp | :orange_circle: | Barf last sexp out forward |
| paredit-backward-barf-sexp | :orange_circle: | Barf first sexp out backward |
| paredit-splice-sexp | :orange_circle: | Remove surrounding delimiters |
| paredit-splice-sexp-killing-backward | :orange_circle: | Splice, kill backward |
| paredit-splice-sexp-killing-forward | :orange_circle: | Splice, kill forward |
| paredit-raise-sexp | :orange_circle: | Replace parent with inner sexp |
| paredit-convolute-sexp | :orange_circle: | Exchange nesting levels |
| paredit-join-sexps | :orange_circle: | Join adjacent sexps |
| paredit-split-sexp | :orange_circle: | Split sexp at point |
| paredit-wrap-round | :orange_circle: | Wrap sexp in () |
| paredit-wrap-square | :orange_circle: | Wrap sexp in [] |
| paredit-wrap-curly | :orange_circle: | Wrap sexp in {} |
| sp-unwrap-sexp | :orange_circle: | Unwrap sexp |
| sp-rewrap-sexp | :orange_circle: | Rewrap with different delimiters |
| sp-forward-sexp | :orange_circle: | Move forward one sexp |
| sp-backward-sexp | :orange_circle: | Move backward one sexp |
| sp-select-next-thing | :orange_circle: | Select next thing |
| sp-select-previous-thing | :orange_circle: | Select previous thing |

### Round 75 — AI Integration (Copilot, GPTel, Ellama)

| Feature | Status | Notes |
|---|---|---|
| copilot-accept-completion | :orange_circle: | Accept AI completion |
| copilot-next-completion | :orange_circle: | Show next completion |
| copilot-previous-completion | :orange_circle: | Show previous completion |
| copilot-dismiss | :orange_circle: | Dismiss completion |
| copilot-mode | :orange_circle: | Toggle Copilot mode |
| copilot-diagnose | :orange_circle: | Run Copilot diagnostics |
| gptel-menu | :orange_circle: | GPTel options menu |
| gptel-set-model | :orange_circle: | Set GPTel model |
| gptel-set-topic | :orange_circle: | Set conversation topic |
| gptel-abort | :orange_circle: | Abort GPTel request |
| chatgpt-shell | :orange_circle: | Open ChatGPT shell |
| chatgpt-shell-send-region | :orange_circle: | Send region to ChatGPT |
| ellama-chat | :orange_circle: | Chat with local LLM |
| ellama-summarize | :orange_circle: | Summarize text |
| ellama-translate | :orange_circle: | Translate text |
| ellama-code-review | :orange_circle: | AI code review |
| ellama-code-complete | :orange_circle: | AI code completion |
| ellama-ask-about | :orange_circle: | Ask about topic |
| ellama-improve-grammar | :orange_circle: | Improve grammar |
| ellama-define-word | :orange_circle: | Define a word |

### Round 76 — Writing & Prose Tools

| Feature | Status | Notes |
|---|---|---|
| writegood-mode | :orange_circle: | Highlight weasel words and passive voice |
| darkroom-mode | :orange_circle: | Distraction-free writing |
| typo-mode | :orange_circle: | Smart typography (quotes, dashes) |
| wc-mode | :orange_circle: | Word count in modeline |
| wc-set-goal | :orange_circle: | Set word count goal |
| mixed-pitch-mode | :orange_circle: | Mix variable and fixed pitch |
| variable-pitch-mode | :orange_circle: | Variable pitch font |
| fixed-pitch-mode | :orange_circle: | Fixed pitch font |
| dictionary-search | :orange_circle: | Search dictionary |
| dictionary-match-words | :orange_circle: | Match words by pattern |
| powerthesaurus-lookup-word | :orange_circle: | Thesaurus lookup |
| synosaurus-lookup | :orange_circle: | Synonym lookup |
| langtool-check | :orange_circle: | LanguageTool grammar check |
| langtool-correct-buffer | :orange_circle: | Apply LanguageTool corrections |
| langtool-check-done | :orange_circle: | Clear LanguageTool results |
| vale-mode | :orange_circle: | Vale prose linting |
| jinx-languages | :orange_circle: | Set Jinx spell-check languages |
| titlecase-dwim | :orange_circle: | Smart title case |
| logos-focus-mode | :orange_circle: | Page-based focused reading |

### Round 77 — Notmuch & mu4e Mail

| Feature | Status | Notes |
|---|---|---|
| notmuch | :orange_circle: | Open Notmuch mail client |
| notmuch-mua-send | :orange_circle: | Send message via Notmuch |
| notmuch-mua-new-mail | :orange_circle: | Compose new mail |
| notmuch-hello | :orange_circle: | Notmuch hello screen |
| mu4e | :orange_circle: | Open mu4e mail client |
| mu4e-compose-new | :orange_circle: | Compose new mu4e message |
| mu4e-headers-search | :orange_circle: | Search mail headers |
| mu4e-update-mail-and-index | :orange_circle: | Fetch and index mail |
| mu4e-compose-reply | :orange_circle: | Reply to message |
| mu4e-compose-forward | :orange_circle: | Forward message |
| mu4e-mark-for-trash | :orange_circle: | Mark for trash |
| mu4e-mark-for-move | :orange_circle: | Mark for move to maildir |
| mu4e-mark-for-delete | :orange_circle: | Mark for deletion |
| mu4e-mark-execute-all | :orange_circle: | Execute all marks |
| mu4e-view-attachment | :orange_circle: | View attachment |
| mu4e-search-bookmark | :orange_circle: | Search by bookmark |
| mu4e-headers-toggle-threading | :orange_circle: | Toggle message threading |
| mu4e-headers-mark-for-flag | :orange_circle: | Flag message |
| mu4e-view-save-attachment | :orange_circle: | Save attachment to file |

---

### Round 78 — Eshell & Terminal (vterm/eat)

| Emacs Command | Status | Description |
|---|---|---|
| eshell-toggle | :orange_circle: | Toggle eshell buffer |
| eshell-here | :orange_circle: | Open eshell in current directory |
| eshell-up | :orange_circle: | Navigate to parent directory in eshell |
| eshell-z | :orange_circle: | Jump to frecent directory in eshell |
| eshell-syntax-highlighting-mode | :orange_circle: | Toggle syntax highlighting in eshell |
| eshell-prompt-extras | :orange_circle: | Enhanced eshell prompt display |
| eshell-bookmark-jump | :orange_circle: | Jump to eshell bookmark |
| eshell-history-previous | :orange_circle: | Previous eshell history entry |
| eshell-history-next | :orange_circle: | Next eshell history entry |
| eshell-send-eof-to-process | :orange_circle: | Send EOF to eshell subprocess |
| eat-mode | :orange_circle: | Toggle Emulate A Terminal mode |
| eat-semi-char-mode | :orange_circle: | Toggle eat semi-char mode |
| eat-char-mode | :orange_circle: | Toggle eat char mode |
| vterm-send-next-key | :orange_circle: | Send next key directly to vterm |
| vterm-send-C-c | :orange_circle: | Send C-c to vterm process |
| vterm-send-C-z | :orange_circle: | Send C-z to vterm process |
| vterm-clear | :orange_circle: | Clear vterm screen |
| vterm-clear-scrollback | :orange_circle: | Clear vterm scrollback buffer |
| vterm-toggle | :orange_circle: | Toggle vterm buffer |
| vterm-other-window | :orange_circle: | Open vterm in other window |

---

### Round 79 — Calendar/Diary, Tree-sitter, Symbol Overlay

| Emacs Command | Status | Description |
|---|---|---|
| calendar-mark-today | :orange_circle: | Mark today's date in calendar |
| calendar-forward-month | :orange_circle: | Move calendar forward one month |
| calendar-backward-month | :orange_circle: | Move calendar backward one month |
| calendar-forward-year | :orange_circle: | Move calendar forward one year |
| calendar-backward-year | :orange_circle: | Move calendar backward one year |
| diary-view-entries | :orange_circle: | View diary entries for selected date |
| appt-delete | :orange_circle: | Delete an appointment |
| holidays | :orange_circle: | Display holidays for current period |
| list-holidays | :orange_circle: | List holidays for a given year |
| calendar-set-mark | :orange_circle: | Set mark in calendar |
| calendar-exchange-point-and-mark | :orange_circle: | Exchange point and mark in calendar |
| treesit-explore | :orange_circle: | Open tree-sitter syntax tree explorer |
| treesit-inspect | :orange_circle: | Inspect tree-sitter node at point |
| xref-find-apropos | :orange_circle: | Search xref by pattern |
| eldoc-box-hover | :orange_circle: | Show eldoc in hover box |
| symbol-overlay-put | :orange_circle: | Highlight symbol at point |
| symbol-overlay-remove-all | :orange_circle: | Remove all symbol overlays |
| symbol-overlay-jump-next | :orange_circle: | Jump to next symbol occurrence |
| symbol-overlay-jump-prev | :orange_circle: | Jump to previous symbol occurrence |
| color-identifiers-mode | :orange_circle: | Toggle color identifiers mode |

---

### Round 80 — Display & Visual Enhancement

| Emacs Command | Status | Description |
|---|---|---|
| rainbow-identifiers-mode | :orange_circle: | Color each identifier uniquely |
| highlight-escape-sequences-mode | :orange_circle: | Highlight escape sequences in strings |
| auto-dim-other-buffers-mode | :orange_circle: | Dim non-focused buffers |
| pulsar-pulse-line | :orange_circle: | Pulse current line |
| pulsar-highlight-dwim | :orange_circle: | Highlight region or line |
| buffer-face-mode | :orange_circle: | Toggle buffer-local face |
| text-scale-increase | :orange_circle: | Increase text scale |
| text-scale-decrease | :orange_circle: | Decrease text scale |
| global-text-scale-adjust | :orange_circle: | Adjust global text scale |
| face-remap-add-relative | :orange_circle: | Add relative face remapping |
| face-remap-remove-relative | :orange_circle: | Remove face remapping |
| visual-fill-column-mode | :orange_circle: | Soft-wrap at fill column |
| writeroom-mode | :orange_circle: | Distraction-free writing mode |
| olivetti-mode | :orange_circle: | Center text in buffer |
| solaire-mode | :orange_circle: | Distinct background for file buffers |
| page-break-lines-mode | :orange_circle: | Display page breaks as lines |
| form-feed-mode | :orange_circle: | Render form-feed characters |
| display-fill-column-indicator-mode | :orange_circle: | Show fill column indicator |
| nano-theme-toggle | :orange_circle: | Toggle nano theme |
| minions-mode | :orange_circle: | Show minor modes in menu |

---

### Round 81 — Diff, Smerge & Ediff

| Emacs Command | Status | Description |
|---|---|---|
| diff-goto-source | :orange_circle: | Jump to source from diff |
| diff-apply-hunk | :orange_circle: | Apply diff hunk |
| diff-reverse-direction | :orange_circle: | Reverse diff direction |
| diff-split-hunk | :orange_circle: | Split diff hunk at point |
| diff-hunk-next | :orange_circle: | Move to next diff hunk |
| diff-hunk-prev | :orange_circle: | Move to previous diff hunk |
| diff-file-next | :orange_circle: | Move to next file in diff |
| diff-file-prev | :orange_circle: | Move to previous file in diff |
| smerge-next | :orange_circle: | Move to next merge conflict |
| smerge-prev | :orange_circle: | Move to previous merge conflict |
| smerge-keep-mine | :orange_circle: | Keep upper/mine version |
| smerge-keep-other | :orange_circle: | Keep lower/other version |
| smerge-keep-all | :orange_circle: | Keep all conflict versions |
| smerge-resolve-all | :orange_circle: | Auto-resolve all conflicts |
| smerge-keep-base | :orange_circle: | Keep base version |
| emerge-buffers | :orange_circle: | Merge two buffers |
| patch-buffer | :orange_circle: | Apply patch to buffer |
| ediff-show-registry | :orange_circle: | Show ediff session registry |
| ediff-toggle-wide-display | :orange_circle: | Toggle ediff wide display |
| ediff-swap-buffers | :orange_circle: | Swap ediff buffer positions |

---

### Round 82 — Project, Envrc, Nix & DevOps

| Emacs Command | Status | Description |
|---|---|---|
| project-find-dir | :orange_circle: | Find directory in project |
| project-or-external-find-file | :orange_circle: | Find file in project or externally |
| project-kill-buffers | :orange_circle: | Kill all project buffers |
| project-async-shell-command | :orange_circle: | Run async shell in project |
| envrc-mode | :orange_circle: | Toggle envrc mode |
| envrc-allow | :orange_circle: | Allow .envrc file |
| envrc-deny | :orange_circle: | Deny .envrc file |
| envrc-reload | :orange_circle: | Reload envrc environment |
| direnv-mode | :orange_circle: | Toggle direnv integration |
| nix-build | :orange_circle: | Run nix build |
| nix-shell | :orange_circle: | Enter nix shell |
| nix-flake-check | :orange_circle: | Run nix flake check |
| nix-flake-show | :orange_circle: | Show nix flake outputs |
| guix-packages | :orange_circle: | List Guix packages |
| guix-generations | :orange_circle: | List Guix generations |
| docker-images | :orange_circle: | List Docker images |
| docker-containers | :orange_circle: | List Docker containers |
| docker-networks | :orange_circle: | List Docker networks |
| kubel-get-pods | :orange_circle: | List Kubernetes pods |
| kubel-describe-pod | :orange_circle: | Describe a Kubernetes pod |

---

### Round 83 — SQL & Org Babel Execution

| Emacs Command | Status | Description |
|---|---|---|
| sql-mode | :orange_circle: | Toggle SQL editing mode |
| sql-connect | :orange_circle: | Connect to SQL database |
| sql-send-region | :orange_circle: | Send region to SQL process |
| sql-send-buffer | :orange_circle: | Send buffer to SQL process |
| sql-set-product | :orange_circle: | Set SQL product type |
| sql-interactive-mode | :orange_circle: | Start SQL interactive session |
| sql-show-sqli-buffer | :orange_circle: | Show SQL interactive buffer |
| pgcli-mode | :orange_circle: | Toggle PGCli mode |
| ob-sql-execute | :orange_circle: | Execute org babel SQL block |
| ob-python-execute | :orange_circle: | Execute org babel Python block |
| ob-shell-execute | :orange_circle: | Execute org babel shell block |
| ob-lisp-execute | :orange_circle: | Execute org babel Lisp block |
| ob-js-execute | :orange_circle: | Execute org babel JavaScript block |
| ob-ruby-execute | :orange_circle: | Execute org babel Ruby block |
| ob-go-execute | :orange_circle: | Execute org babel Go block |
| ob-rust-execute | :orange_circle: | Execute org babel Rust block |
| ob-haskell-execute | :orange_circle: | Execute org babel Haskell block |
| ob-c-execute | :orange_circle: | Execute org babel C block |
| ob-java-execute | :orange_circle: | Execute org babel Java block |
| ob-clojure-execute | :orange_circle: | Execute org babel Clojure block |

---

### Round 84 — PDF, Image & Doc-view

| Emacs Command | Status | Description |
|---|---|---|
| pdf-view-scroll-up | :orange_circle: | Scroll PDF up |
| pdf-view-scroll-down | :orange_circle: | Scroll PDF down |
| pdf-view-fit-width | :orange_circle: | Fit PDF to width |
| pdf-view-fit-height | :orange_circle: | Fit PDF to height |
| pdf-annot-add-highlight | :orange_circle: | Add PDF highlight annotation |
| pdf-annot-add-text | :orange_circle: | Add PDF text annotation |
| pdf-annot-list-annotations | :orange_circle: | List PDF annotations |
| pdf-occur | :orange_circle: | Search in PDF document |
| pdf-outline | :orange_circle: | Show PDF outline |
| nov-goto-toc | :orange_circle: | Go to epub table of contents |
| image-next-file | :orange_circle: | Next image file |
| image-previous-file | :orange_circle: | Previous image file |
| image-transform-rotate | :orange_circle: | Rotate image |
| image-transform-fit-both | :orange_circle: | Fit image to both dimensions |
| image-increase-size | :orange_circle: | Increase image size |
| image-decrease-size | :orange_circle: | Decrease image size |
| doc-view-toggle-display | :orange_circle: | Toggle doc-view display mode |
| doc-view-search | :orange_circle: | Search in doc-view |
| pdf-view-auto-slice-mode | :orange_circle: | Toggle PDF auto-slice mode |
| pdf-view-themed-minor-mode | :orange_circle: | Toggle PDF themed mode |

---

### Round 85 — System Monitor, Session & Debug

| Emacs Command | Status | Description |
|---|---|---|
| debug-on-variable-change | :orange_circle: | Debug when variable changes |
| proced-send-signal | :orange_circle: | Send signal to process |
| proced-filter-interactive | :orange_circle: | Filter process list |
| proced-sort-interactive | :orange_circle: | Sort process list |
| system-monitor-mode | :orange_circle: | Open system monitor |
| top-mode | :orange_circle: | Process viewer (top) |
| htop-mode | :orange_circle: | Interactive process viewer (htop) |
| disk-usage-here | :orange_circle: | Analyze disk usage in current dir |
| battery-mode | :orange_circle: | Show battery in mode line |
| fancy-battery-mode | :orange_circle: | Enhanced battery display |
| symon-mode | :orange_circle: | System monitor in mode line |
| uptimes | :orange_circle: | Show Emacs uptime history |
| desktop-clear | :orange_circle: | Clear desktop session |
| desktop-remove | :orange_circle: | Remove desktop session file |
| desktop-change-dir | :orange_circle: | Change desktop directory |
| recentf-save-list | :orange_circle: | Save recent files list |
| midnight-mode | :orange_circle: | Auto-clean buffers at midnight |
| clean-buffer-list | :orange_circle: | Clean stale buffers |
| lock-file-mode | :orange_circle: | Toggle file locking |
| backup-walker | :orange_circle: | Browse file backups |

---

### Round 86 — Package Management

| Emacs Command | Status | Description |
|---|---|---|
| package-list-packages | :orange_circle: | List all packages |
| package-upgrade | :orange_circle: | Upgrade a package |
| package-upgrade-all | :orange_circle: | Upgrade all packages |
| straight-pull-all | :orange_circle: | Pull all straight.el packages |
| straight-rebuild-all | :orange_circle: | Rebuild all straight.el packages |
| straight-freeze-versions | :orange_circle: | Freeze straight.el versions |
| el-get-install | :orange_circle: | Install package via el-get |
| el-get-remove | :orange_circle: | Remove package via el-get |
| el-get-update | :orange_circle: | Update package via el-get |
| quelpa-upgrade | :orange_circle: | Upgrade package via quelpa |
| quelpa-self-upgrade | :orange_circle: | Self-upgrade quelpa |
| package-vc-install | :orange_circle: | Install package from VC |
| package-vc-update | :orange_circle: | Update VC packages |
| borg-assimilate | :orange_circle: | Assimilate package via borg |
| borg-build | :orange_circle: | Build package via borg |
| borg-activate | :orange_circle: | Activate all borg drones |
| auto-package-update-now | :orange_circle: | Auto-update packages now |
| auto-package-update-maybe | :orange_circle: | Check if package update needed |
| paradox-list-packages | :orange_circle: | List packages with ratings |
| paradox-upgrade-packages | :orange_circle: | Upgrade all via paradox |

---

### Round 87 — CIDER, Sly, Geiser & Racket

| Emacs Command | Status | Description |
|---|---|---|
| cider-eval-defun | :orange_circle: | Evaluate defun at point (CIDER) |
| cider-find-var | :orange_circle: | Find var definition (CIDER) |
| cider-doc | :orange_circle: | Show documentation (CIDER) |
| cider-test-run-test | :orange_circle: | Run test at point (CIDER) |
| cider-repl-set-ns | :orange_circle: | Set REPL namespace (CIDER) |
| cider-inspect | :orange_circle: | Inspect expression (CIDER) |
| cider-refresh | :orange_circle: | Refresh loaded namespaces (CIDER) |
| sly-eval-defun | :orange_circle: | Evaluate defun at point (Sly) |
| sly-eval-buffer | :orange_circle: | Evaluate buffer (Sly) |
| sly-describe-symbol | :orange_circle: | Describe symbol (Sly) |
| sly-who-calls | :orange_circle: | Show callers (Sly) |
| sly-who-references | :orange_circle: | Show references (Sly) |
| geiser-eval-definition | :orange_circle: | Evaluate definition (Geiser) |
| geiser-doc-symbol | :orange_circle: | Show doc for symbol (Geiser) |
| geiser-connect | :orange_circle: | Connect to Scheme REPL (Geiser) |
| racket-run | :orange_circle: | Run current Racket file |
| racket-test | :orange_circle: | Run Racket tests |
| racket-describe | :orange_circle: | Describe Racket symbol |
| racket-repl | :orange_circle: | Start Racket REPL |

---

### Round 88 — Rust (rustic), Go & Python Testing

| Emacs Command | Status | Description |
|---|---|---|
| rustic-cargo-build | :orange_circle: | Run cargo build |
| rustic-cargo-run | :orange_circle: | Run cargo run |
| rustic-cargo-test | :orange_circle: | Run cargo test |
| rustic-cargo-clippy | :orange_circle: | Run cargo clippy |
| rustic-format-buffer | :orange_circle: | Format buffer with rustfmt |
| rustic-cargo-add | :orange_circle: | Add cargo dependency |
| rustic-cargo-bench | :orange_circle: | Run cargo bench |
| rustic-cargo-doc | :orange_circle: | Generate cargo docs |
| rustic-cargo-check | :orange_circle: | Run cargo check |
| rustic-cargo-fmt | :orange_circle: | Run cargo fmt |
| go-mode | :orange_circle: | Toggle Go mode |
| gofmt | :orange_circle: | Format Go buffer |
| go-test-current-test | :orange_circle: | Run current Go test |
| go-import-add | :orange_circle: | Add Go import |
| go-goto-function | :orange_circle: | Navigate to Go function |
| go-fill-struct | :orange_circle: | Fill Go struct with zero values |
| lsp-go-generate | :orange_circle: | Run go generate via LSP |
| python-pytest | :orange_circle: | Run pytest |
| python-pytest-file | :orange_circle: | Run pytest on current file |
| python-pytest-function | :orange_circle: | Run pytest on current function |

---

### Round 89 — Web, Config & Language Modes

| Emacs Command | Status | Description |
|---|---|---|
| typescript-mode | :orange_circle: | Toggle TypeScript mode |
| tsx-mode | :orange_circle: | Toggle TSX mode |
| emmet-wrap-with-markup | :orange_circle: | Wrap selection with emmet markup |
| prettier-js | :orange_circle: | Format buffer with Prettier |
| sass-mode | :orange_circle: | Toggle Sass mode |
| css-eldoc-function | :orange_circle: | Show CSS property docs |
| json-navigator | :orange_circle: | Navigate JSON tree |
| json-mode-beautify | :orange_circle: | Beautify JSON buffer |
| yaml-lint | :orange_circle: | Lint YAML buffer |
| toml-mode | :orange_circle: | Toggle TOML mode |
| docker-compose-mode | :orange_circle: | Toggle Docker Compose mode |
| nginx-mode | :orange_circle: | Toggle Nginx config mode |
| apache-mode | :orange_circle: | Toggle Apache config mode |
| ini-mode | :orange_circle: | Toggle INI file mode |
| csv-mode | :orange_circle: | Toggle CSV mode |
| dotenv-mode | :orange_circle: | Toggle dotenv mode |
| pkgbuild-mode | :orange_circle: | Toggle PKGBUILD mode |
| lua-mode | :orange_circle: | Toggle Lua mode |
| mermaid-mode | :orange_circle: | Toggle Mermaid diagram mode |
| just-mode | :orange_circle: | Toggle Justfile mode |

---

### Round 90 — LSP Extensions

| Emacs Command | Status | Description |
|---|---|---|
| lsp-treemacs-references | :orange_circle: | Show references in treemacs |
| lsp-treemacs-implementations | :orange_circle: | Show implementations in treemacs |
| lsp-treemacs-call-hierarchy | :orange_circle: | Show call hierarchy in treemacs |
| lsp-treemacs-type-hierarchy | :orange_circle: | Show type hierarchy in treemacs |
| lsp-treemacs-errors-list | :orange_circle: | Show errors in treemacs |
| lsp-ui-sideline-mode | :orange_circle: | Toggle LSP UI sideline |
| lsp-ui-peek-find-implementation | :orange_circle: | Peek at implementation |
| lsp-inlay-hints-mode | :orange_circle: | Toggle inlay hints |
| lsp-semantic-tokens-mode | :orange_circle: | Toggle semantic tokens |
| lsp-modeline-diagnostics-mode | :orange_circle: | Toggle modeline diagnostics |
| lsp-modeline-code-actions-mode | :orange_circle: | Toggle modeline code actions |
| lsp-signature-mode | :orange_circle: | Toggle signature help |
| lsp-toggle-symbol-highlight | :orange_circle: | Toggle symbol highlight |
| lsp-workspace-folders-add | :orange_circle: | Add workspace folder |
| lsp-workspace-folders-remove | :orange_circle: | Remove workspace folder |
| lsp-describe-session | :orange_circle: | Describe LSP session |
| lsp-disconnect | :orange_circle: | Disconnect from LSP server |
| lsp-toggle-trace-io | :orange_circle: | Toggle LSP I/O tracing |
| lsp-avy-lens | :orange_circle: | Jump to LSP code lens via avy |
| lsp-ivy-workspace-symbol | :orange_circle: | Search workspace symbols |

---

### Round 91 — DAP & Debugger

| Emacs Command | Status | Description |
|---|---|---|
| dap-breakpoint-delete-all | :orange_circle: | Delete all breakpoints |
| dap-restart-frame | :orange_circle: | Restart current frame |
| dap-ui-locals | :orange_circle: | Show local variables |
| dap-ui-breakpoints | :orange_circle: | Show breakpoints panel |
| dap-ui-sessions | :orange_circle: | Show debug sessions |
| dap-hydra | :orange_circle: | Open debug hydra menu |
| dap-ui-expressions-add | :orange_circle: | Add watch expression |
| dap-tooltip-at-point | :orange_circle: | Show value at point |
| dap-switch-stack-frame | :orange_circle: | Switch stack frame |
| dap-switch-thread | :orange_circle: | Switch debug thread |
| dap-toggle-breakpoint-condition | :orange_circle: | Set conditional breakpoint |
| realgud-gdb | :orange_circle: | Debug with GDB (RealGUD) |
| realgud-pdb | :orange_circle: | Debug with PDB (RealGUD) |
| realgud-node-inspect | :orange_circle: | Debug with Node inspector |
| realgud-lldb | :orange_circle: | Debug with LLDB (RealGUD) |
| gdb-many-windows | :orange_circle: | GDB many-windows layout |
| gud-gdb | :orange_circle: | Start GDB via GUD |
| gud-break | :orange_circle: | Set GUD breakpoint |
| gud-remove | :orange_circle: | Remove GUD breakpoint |
| gud-step | :orange_circle: | GUD step into |

---

### Round 92 — Web Browsing

| Emacs Command | Status | Description |
|---|---|---|
| eww-reload | :orange_circle: | Reload EWW page |
| eww-back-url | :orange_circle: | EWW navigate back |
| eww-forward-url | :orange_circle: | EWW navigate forward |
| eww-download | :orange_circle: | Download current EWW page |
| eww-copy-page-url | :orange_circle: | Copy EWW page URL |
| eww-list-bookmarks | :orange_circle: | List EWW bookmarks |
| eww-add-bookmark | :orange_circle: | Add EWW bookmark |
| eww-search-words | :orange_circle: | Search web via EWW |
| eww-open-in-new-buffer | :orange_circle: | Open URL in new EWW buffer |
| w3m-browse-url | :orange_circle: | Browse URL in w3m |
| w3m-search | :orange_circle: | Search via w3m |
| w3m-bookmark-view | :orange_circle: | View w3m bookmarks |
| shr-browse-url | :orange_circle: | Open URL at point in browser |
| browse-url-firefox | :orange_circle: | Open URL in Firefox |
| browse-url-chromium | :orange_circle: | Open URL in Chromium |
| browse-url-default-browser | :orange_circle: | Open URL in default browser |
| xwidget-webkit-browse-url | :orange_circle: | Browse URL in xwidget webkit |
| xwidget-webkit-back | :orange_circle: | Xwidget webkit back |
| xwidget-webkit-forward | :orange_circle: | Xwidget webkit forward |
| xwidget-webkit-reload | :orange_circle: | Xwidget webkit reload |

---

### Round 93 — TRAMP & Remote Access

| Emacs Command | Status | Description |
|---|---|---|
| tramp-cleanup-all-buffers | :orange_circle: | Clean up all remote buffers |
| tramp-rename-files | :orange_circle: | Rename remote files |
| tramp-revert-buffer-with-sudo | :orange_circle: | Reopen buffer with sudo |
| find-file-as-root | :orange_circle: | Open file as root |
| tramp-change-syntax | :orange_circle: | Change TRAMP syntax |
| ssh-deploy-remote-changes | :orange_circle: | Check remote changes |
| ssh-deploy-upload-handler | :orange_circle: | Upload file to remote |
| ssh-deploy-diff | :orange_circle: | Diff with remote file |
| ssh-deploy-delete | :orange_circle: | Delete remote file |
| rsync-mode | :orange_circle: | Toggle rsync mode |
| rsync-file | :orange_circle: | Rsync file to destination |
| scp-file | :orange_circle: | SCP file to destination |
| tramp-term | :orange_circle: | Open terminal on remote host |
| tramp-open-shell | :orange_circle: | Open shell on remote host |
| tramp-archive-cleanup | :orange_circle: | Clean up archive connections |
| tramp-list-connections | :orange_circle: | List active TRAMP connections |
| tramp-list-remote-buffers | :orange_circle: | List remote buffers |
| tramp-toggle-read-only | :orange_circle: | Toggle read-only on remote file |
| tramp-set-connection-local-variables | :orange_circle: | Set connection-local variables |

---

### Round 94 — Org Drill, Flashcards, Dailies & Journal

| Emacs Command | Status | Description |
|---|---|---|
| org-drill | :orange_circle: | Start org drill review session |
| org-drill-cram | :orange_circle: | Org drill cram mode |
| org-drill-resume | :orange_circle: | Resume org drill session |
| org-fc-review | :orange_circle: | Start flashcard review |
| org-fc-type-normal-init | :orange_circle: | Initialize normal flashcard |
| org-fc-dashboard | :orange_circle: | Open flashcard dashboard |
| org-fc-suspend-card | :orange_circle: | Suspend flashcard |
| org-fc-unsuspend-card | :orange_circle: | Unsuspend flashcard |
| org-anki-sync | :orange_circle: | Sync with Anki |
| org-anki-delete-all | :orange_circle: | Delete all synced Anki notes |
| org-roam-dailies-capture-today | :orange_circle: | Capture today's daily note |
| org-roam-dailies-goto-today | :orange_circle: | Go to today's daily note |
| org-roam-dailies-goto-yesterday | :orange_circle: | Go to yesterday's daily note |
| org-roam-dailies-goto-tomorrow | :orange_circle: | Go to tomorrow's daily note |
| org-roam-dailies-goto-date | :orange_circle: | Go to daily note by date |
| org-roam-dailies-capture-date | :orange_circle: | Capture daily note for date |
| org-journal-new-entry | :orange_circle: | Create new journal entry |
| org-journal-open-current | :orange_circle: | Open current journal |
| org-journal-search | :orange_circle: | Search journal entries |
| org-journal-list | :orange_circle: | List all journal entries |

---

### Round 95 — Denote, Citar & BibTeX

| Emacs Command | Status | Description |
|---|---|---|
| denote-link | :orange_circle: | Insert denote link |
| denote-backlinks | :orange_circle: | Show denote backlinks |
| denote-rename-file | :orange_circle: | Rename denote file |
| denote-keywords-add | :orange_circle: | Add denote keywords |
| denote-keywords-remove | :orange_circle: | Remove denote keywords |
| denote-open-or-create | :orange_circle: | Open or create denote note |
| denote-link-find-file | :orange_circle: | Find linked denote file |
| denote-link-find-backlink | :orange_circle: | Find backlinked denote file |
| denote-subdirectory | :orange_circle: | Set denote subdirectory |
| citar-open | :orange_circle: | Open citation reference |
| citar-insert-citation | :orange_circle: | Insert citation |
| citar-insert-reference | :orange_circle: | Insert reference |
| citar-open-notes | :orange_circle: | Open notes for reference |
| citar-open-files | :orange_circle: | Open files for reference |
| bibtex-mode | :orange_circle: | Toggle BibTeX mode |
| bibtex-clean-entry | :orange_circle: | Clean BibTeX entry |
| bibtex-fill-entry | :orange_circle: | Fill BibTeX entry |
| bibtex-reformat | :orange_circle: | Reformat BibTeX buffer |
| biblio-lookup | :orange_circle: | Look up bibliography |
| biblio-arxiv-lookup | :orange_circle: | Search ArXiv |

---

### Round 96 — Eglot & Cape Extensions

| Emacs Command | Status | Description |
|---|---|---|
| eglot-code-action-organize-imports | :orange_circle: | Organize imports via eglot |
| eglot-code-action-quickfix | :orange_circle: | Apply quickfix via eglot |
| eglot-code-action-extract | :orange_circle: | Extract code via eglot |
| eglot-events-buffer | :orange_circle: | Show eglot events buffer |
| eglot-signal-didChangeConfiguration | :orange_circle: | Signal config change to eglot |
| eglot-signal-didSave | :orange_circle: | Signal save to eglot |
| eglot-inlay-hints-mode | :orange_circle: | Toggle eglot inlay hints |
| eglot-show-workspace-configuration | :orange_circle: | Show eglot workspace config |
| eglot-clear-status | :orange_circle: | Clear eglot status |
| consult-eglot-symbols | :orange_circle: | Search eglot symbols |
| eglot-find-declaration | :orange_circle: | Find declaration via eglot |
| eglot-find-implementation | :orange_circle: | Find implementation via eglot |
| eglot-find-typeDefinition | :orange_circle: | Find type definition via eglot |
| eglot-hierarchy | :orange_circle: | Show eglot hierarchy |
| eglot-format-buffer | :orange_circle: | Format buffer via eglot |
| eglot-code-action-rewrite | :orange_circle: | Rewrite code via eglot |
| eglot-code-action-inline | :orange_circle: | Inline code via eglot |
| eglot-stderr-buffer | :orange_circle: | Show eglot stderr buffer |
| cape-eglot | :orange_circle: | Cape eglot completion |
| cape-dabbrev | :orange_circle: | Cape dabbrev completion |

---

### Round 97 — Terminal & Detached Sessions

| Emacs Command | Status | Description |
|---|---|---|
| eat-project | :orange_circle: | Open eat terminal in project root |
| eat-eshell-mode | :orange_circle: | Toggle eat eshell mode |
| eat-line-mode | :orange_circle: | Switch eat to line mode |
| eat-char-mode2 | :orange_circle: | Switch eat to char mode 2 |
| multi-term | :orange_circle: | Create new multi-term terminal |
| multi-term-next | :orange_circle: | Switch to next multi-term |
| multi-term-prev | :orange_circle: | Switch to previous multi-term |
| multi-term-dedicated-toggle | :orange_circle: | Toggle dedicated multi-term |
| multi-term-dedicated-select | :orange_circle: | Select dedicated multi-term |
| term-line-mode | :orange_circle: | Switch term to line mode |
| term-char-mode | :orange_circle: | Switch term to char mode |
| term-send-raw-string | :orange_circle: | Send raw string to term |
| term-toggle-mode | :orange_circle: | Toggle term line/char mode |
| comint-redirect-send-command | :orange_circle: | Redirect comint command output |
| detached-compile | :orange_circle: | Compile in detached session |
| detached-open-session | :orange_circle: | Open detached session |
| detached-list-sessions | :orange_circle: | List detached sessions |
| detached-view-session | :orange_circle: | View detached session output |
| detached-attach | :orange_circle: | Attach to detached session |
| detached-delete-session | :orange_circle: | Delete detached session |

---

### Round 98 — Transient & Hydra

| Emacs Command | Status | Description |
|---|---|---|
| transient-prefix | :orange_circle: | Invoke transient prefix |
| transient-suffix | :orange_circle: | Invoke transient suffix |
| transient-toggle | :orange_circle: | Toggle transient option |
| transient-switches | :orange_circle: | Cycle transient switches |
| transient-resume | :orange_circle: | Resume previous transient |
| transient-quit-all | :orange_circle: | Quit all transient levels |
| transient-quit-one | :orange_circle: | Quit one transient level |
| transient-save | :orange_circle: | Save transient values |
| transient-set | :orange_circle: | Set transient values |
| hydra-default-pre | :orange_circle: | Hydra default pre-command |
| hydra-keyboard-quit | :orange_circle: | Quit hydra |
| hydra-text-scale | :orange_circle: | Hydra text scale menu |
| hydra-buffer | :orange_circle: | Hydra buffer menu |
| hydra-git | :orange_circle: | Hydra git menu |
| hydra-project | :orange_circle: | Hydra project menu |
| hydra-org | :orange_circle: | Hydra org menu |
| hydra-flycheck | :orange_circle: | Hydra flycheck menu |
| hydra-lsp | :orange_circle: | Hydra LSP menu |
| hydra-smerge | :orange_circle: | Hydra smerge menu |
| hydra-rectangle | :orange_circle: | Hydra rectangle menu |

### Round 99 — Evil Extensions

| Command | Status | Description |
|---------|--------|-------------|
| evil-window-delete | :orange_circle: | Evil delete current window |
| evil-window-next | :orange_circle: | Evil cycle to next window |
| evil-surround-region | :orange_circle: | Evil surround visual selection |
| evil-surround-change | :orange_circle: | Evil change surrounding delimiters |
| evil-surround-delete | :orange_circle: | Evil delete surrounding delimiters |
| evil-commentary | :orange_circle: | Evil toggle comment operator |
| evil-commentary-line | :orange_circle: | Evil comment current line |
| evil-exchange | :orange_circle: | Evil exchange operator |
| evil-exchange-cancel | :orange_circle: | Evil cancel pending exchange |
| evil-numbers-increment | :orange_circle: | Evil increment number at point |
| evil-numbers-decrement | :orange_circle: | Evil decrement number at point |
| evil-matchit | :orange_circle: | Evil jump to matching delimiter |
| evil-lion-left | :orange_circle: | Evil align operator (left) |
| evil-lion-right | :orange_circle: | Evil align operator (right) |
| evil-snipe-f | :orange_circle: | Evil 2-char forward find |
| evil-snipe-F | :orange_circle: | Evil 2-char backward find |
| evil-snipe-s | :orange_circle: | Evil 2-char forward seek |
| evil-snipe-S | :orange_circle: | Evil 2-char backward seek |
| evil-collection-init | :orange_circle: | Evil keybinding collection setup |
| evil-owl-goto-mark | :orange_circle: | Evil visual mark navigation |

### Round 100 — Consult Framework

| Command | Status | Description |
|---------|--------|-------------|
| consult-line | :orange_circle: | Search lines in current buffer |
| consult-buffer | :orange_circle: | Enhanced buffer switching |
| consult-outline | :orange_circle: | Navigate buffer outline headings |
| consult-goto-line | :orange_circle: | Jump to line with preview |
| consult-register | :orange_circle: | Browse and access registers |
| consult-kmacro | :orange_circle: | Select keyboard macro from ring |
| consult-compile-error | :orange_circle: | Navigate compilation errors |
| consult-flymake | :orange_circle: | Navigate flymake diagnostics |
| consult-history | :orange_circle: | Browse minibuffer history |
| consult-minor-mode-menu | :orange_circle: | Toggle minor modes via menu |
| consult-org-heading | :orange_circle: | Navigate org headings |
| consult-org-agenda | :orange_circle: | Browse org agenda items |
| consult-locate | :orange_circle: | Find files via locate |
| consult-project-buffer | :orange_circle: | Switch project-scoped buffers |
| consult-fd | :orange_circle: | Find files via fd |
| consult-multi | :orange_circle: | Multi-source search |
| consult-isearch-history | :orange_circle: | Browse isearch history |
| consult-narrow | :orange_circle: | Narrow consult to single source |
| consult-widen | :orange_circle: | Widen consult to all sources |
| consult-mark | :orange_circle: | Navigate mark ring |

### Round 101 — Vertico/Corfu Completion Framework

| Command | Status | Description |
|---------|--------|-------------|
| vertico-mode | :orange_circle: | Toggle Vertico vertical completion |
| vertico-next | :orange_circle: | Move to next Vertico candidate |
| vertico-previous | :orange_circle: | Move to previous Vertico candidate |
| vertico-first | :orange_circle: | Jump to first candidate |
| vertico-last | :orange_circle: | Jump to last candidate |
| vertico-scroll-up | :orange_circle: | Scroll candidates up |
| vertico-scroll-down | :orange_circle: | Scroll candidates down |
| vertico-exit | :orange_circle: | Exit Vertico completion |
| vertico-insert | :orange_circle: | Insert current candidate |
| corfu-mode | :orange_circle: | Toggle Corfu in-buffer completion |
| corfu-next | :orange_circle: | Next Corfu completion candidate |
| corfu-previous | :orange_circle: | Previous Corfu completion candidate |
| corfu-insert | :orange_circle: | Insert Corfu completion |
| corfu-show-documentation | :orange_circle: | Show candidate documentation |
| corfu-show-location | :orange_circle: | Show candidate source location |
| corfu-info-documentation | :orange_circle: | Open docs in separate buffer |
| corfu-info-location | :orange_circle: | Open source in separate buffer |
| corfu-popupinfo-toggle | :orange_circle: | Toggle popup info display |
| vertico-directory-up | :orange_circle: | Move up one directory level |
| vertico-directory-enter | :orange_circle: | Enter directory in completion |

### Round 102 — Emacs Lisp Development & Debugging

| Command | Status | Description |
|---------|--------|-------------|
| edebug-step-mode | :orange_circle: | Edebug step mode (stop at every expression) |
| edebug-next-mode | :orange_circle: | Edebug next mode (stop after each expression) |
| edebug-go-mode | :orange_circle: | Edebug go mode (run until breakpoint) |
| edebug-continue-mode | :orange_circle: | Edebug continue mode |
| edebug-trace-mode | :orange_circle: | Edebug trace mode (show execution trace) |
| edebug-set-breakpoint | :orange_circle: | Set breakpoint at point |
| edebug-unset-breakpoint | :orange_circle: | Remove breakpoint at point |
| edebug-eval-expression | :orange_circle: | Evaluate expression in edebug context |
| edebug-where | :orange_circle: | Show current edebug stop point |
| edebug-bounce-point | :orange_circle: | Bounce to current point and back |
| edebug-top-level-nonstop | :orange_circle: | Exit to top level nonstop |
| ert-results-rerun-test | :orange_circle: | Rerun ERT test at point |
| elisp-refs-function | :orange_circle: | Find references to function |
| elisp-refs-macro | :orange_circle: | Find references to macro |
| elisp-refs-variable | :orange_circle: | Find references to variable |
| elisp-refs-symbol | :orange_circle: | Find all references to symbol |
| eldoc-print-current-symbol-info | :orange_circle: | Display eldoc for symbol at point |
| ielm-send-input | :orange_circle: | Send IELM input for evaluation |
| ielm-return | :orange_circle: | IELM newline or send |
| ielm-clear-buffer | :orange_circle: | Clear IELM interaction buffer |

### Round 103 — Org-mode Advanced (Babel, Tables, Attachments)

| Command | Status | Description |
|---------|--------|-------------|
| org-babel-detangle | :orange_circle: | Detangle source blocks back to org |
| org-babel-tangle-file | :orange_circle: | Tangle a specific org file |
| org-babel-load-file | :orange_circle: | Load and evaluate org file |
| org-babel-sha1-hash | :orange_circle: | Compute SHA1 hash of source block |
| org-babel-check-src-block | :orange_circle: | Check source block for errors |
| org-babel-switch-to-session | :orange_circle: | Switch to babel session buffer |
| org-babel-result-hide-all | :orange_circle: | Hide all babel results |
| org-table-create-with-table-el | :orange_circle: | Create table.el table |
| org-table-recalculate | :orange_circle: | Recalculate current table field |
| org-table-recalculate-buffer-tables | :orange_circle: | Recalculate all tables in buffer |
| org-table-transpose-table-at-point | :orange_circle: | Transpose table at point |
| org-table-toggle-formula-debugger | :orange_circle: | Toggle formula debugger |
| org-table-field-info | :orange_circle: | Show field info at point |
| org-attach-attach | :orange_circle: | Attach file to org heading |
| org-attach-open | :orange_circle: | Open attachment |
| org-attach-reveal | :orange_circle: | Reveal attachment directory |
| org-attach-sync | :orange_circle: | Synchronize attachments |
| org-attach-delete-one | :orange_circle: | Delete one attachment |
| org-attach-delete-all | :orange_circle: | Delete all attachments |
| org-attach-set-directory | :orange_circle: | Set attachment directory |

### Round 104 — Magit Advanced (Subtrees, Submodules, Patches)

| Command | Status | Description |
|---------|--------|-------------|
| magit-branch-reset | :orange_circle: | Reset branch to target |
| magit-branch-spin-off | :orange_circle: | Spin off new branch from current |
| magit-remote-rename | :orange_circle: | Rename a remote |
| magit-tag-create | :orange_circle: | Create a git tag |
| magit-tag-delete | :orange_circle: | Delete a git tag |
| magit-tag-release | :orange_circle: | Create a release tag |
| magit-notes-merge | :orange_circle: | Merge git notes refs |
| magit-bisect-run | :orange_circle: | Run bisect with script |
| magit-subtree-add | :orange_circle: | Add a subtree |
| magit-subtree-merge | :orange_circle: | Merge a subtree |
| magit-subtree-pull | :orange_circle: | Pull a subtree |
| magit-subtree-push | :orange_circle: | Push a subtree |
| magit-subtree-split | :orange_circle: | Split a subtree |
| magit-submodule-populate | :orange_circle: | Populate submodules |
| magit-submodule-synchronize | :orange_circle: | Synchronize submodule URLs |
| magit-submodule-unpopulate | :orange_circle: | Unpopulate submodules |
| magit-am-apply-patches | :orange_circle: | Apply patches via git am |
| magit-am-continue | :orange_circle: | Continue patch application |
| magit-am-abort | :orange_circle: | Abort patch application |
| magit-format-patch | :orange_circle: | Format patches for range |

### Round 105 — Text Manipulation & Editing Helpers

| Command | Status | Description |
|---------|--------|-------------|
| unexpand-abbrev | :orange_circle: | Undo last abbreviation expansion |
| define-global-abbrev | :orange_circle: | Define a global abbreviation |
| define-mode-abbrev | :orange_circle: | Define a mode-specific abbreviation |
| abbrev-prefix-mark | :orange_circle: | Mark position for abbreviation prefix |
| compose-mail-other-window | :orange_circle: | Compose mail in other window |
| compose-mail-other-frame | :orange_circle: | Compose mail in other frame |
| mail-send | :orange_circle: | Send the current mail message |
| mail-send-and-exit | :orange_circle: | Send mail and close buffer |
| set-justification-left | :orange_circle: | Set left justification |
| set-justification-right | :orange_circle: | Set right justification |
| set-justification-center | :orange_circle: | Set center justification |
| set-justification-full | :orange_circle: | Set full justification |
| set-justification-none | :orange_circle: | Remove justification |
| picture-mode-exit | :orange_circle: | Exit picture mode |
| picture-movement-right | :orange_circle: | Set picture movement to right |
| picture-movement-left | :orange_circle: | Set picture movement to left |
| picture-movement-up | :orange_circle: | Set picture movement to up |
| picture-movement-down | :orange_circle: | Set picture movement to down |
| picture-clear-column | :orange_circle: | Clear column in picture mode |
| picture-clear-line | :orange_circle: | Clear line in picture mode |

### Round 106 — Help & Info System

| Command | Status | Description |
|---------|--------|-------------|
| info-index | :orange_circle: | Look up index entry in Info |
| info-index-next | :orange_circle: | Next index match |
| info-next-reference | :orange_circle: | Move to next cross-reference |
| info-prev-reference | :orange_circle: | Move to previous cross-reference |
| info-follow-reference | :orange_circle: | Follow a cross-reference |
| info-history | :orange_circle: | Show Info history |
| info-history-back | :orange_circle: | Navigate back in Info history |
| info-history-forward | :orange_circle: | Navigate forward in Info history |
| info-toc | :orange_circle: | Show Info table of contents |
| info-top-node | :orange_circle: | Go to top Info node |
| info-final-node | :orange_circle: | Go to final Info node |
| info-up | :orange_circle: | Navigate up one Info level |
| info-nth-menu-item | :orange_circle: | Select nth menu item |
| shortdoc | :orange_circle: | Display shortdoc function group |
| help-with-tutorial-spec-language | :orange_circle: | Open tutorial in specific language |
| view-order-manuals | :orange_circle: | View manual ordering info |
| view-emacs-FAQ | :orange_circle: | View Emacs FAQ |
| view-emacs-problems | :orange_circle: | View known Emacs problems |
| view-emacs-debugging | :orange_circle: | View Emacs debugging info |
| view-emacs-news | :orange_circle: | View Emacs news |

### Round 107 — Dired Advanced (Filters, Subtrees, Operations)

| Command | Status | Description |
|---------|--------|-------------|
| dired-do-chgrp | :orange_circle: | Change group of marked files |
| dired-do-hardlink | :orange_circle: | Create hard links for marked files |
| dired-do-relsymlink | :orange_circle: | Create relative symlinks |
| dired-hide-all | :orange_circle: | Toggle hiding all subdirectories |
| dired-hide-subdir | :orange_circle: | Toggle hiding current subdirectory |
| dired-narrow-regexp | :orange_circle: | Narrow dired by regexp |
| dired-narrow-fuzzy | :orange_circle: | Narrow dired by fuzzy match |
| dired-subtree-insert | :orange_circle: | Insert subdirectory as subtree |
| dired-subtree-remove | :orange_circle: | Remove subtree listing |
| dired-filter-by-name | :orange_circle: | Filter by file name |
| dired-filter-by-regexp | :orange_circle: | Filter by regexp |
| dired-filter-by-extension | :orange_circle: | Filter by file extension |
| dired-filter-by-directory | :orange_circle: | Filter to directories only |
| dired-filter-by-dot-files | :orange_circle: | Filter dot files |
| dired-filter-by-size | :orange_circle: | Filter by file size |
| dired-filter-by-date | :orange_circle: | Filter by modification date |
| dired-filter-pop | :orange_circle: | Pop last filter |
| dired-filter-pop-all | :orange_circle: | Remove all filters |
| dired-avfs-open | :orange_circle: | Open via AVFS virtual filesystem |
| dired-open-file | :orange_circle: | Open with external application |

### Round 108 — EWW, RSS & Web Browsing

| Command | Status | Description |
|---------|--------|-------------|
| eww-readable | :orange_circle: | Toggle readable view in EWW |
| eww-toggle-fonts | :orange_circle: | Toggle font rendering in EWW |
| eww-toggle-colors | :orange_circle: | Toggle color rendering in EWW |
| eww-list-histories | :orange_circle: | List EWW browsing history |
| elfeed-search-update | :orange_circle: | Update elfeed search results |
| elfeed-search-browse-url | :orange_circle: | Open entry URL in browser |
| elfeed-search-tag-all | :orange_circle: | Tag all visible entries |
| elfeed-search-untag-all | :orange_circle: | Untag all visible entries |
| elfeed-search-live-filter | :orange_circle: | Set live filter for elfeed |
| elfeed-db-compact | :orange_circle: | Compact elfeed database |
| elfeed-goodies-setup | :orange_circle: | Setup elfeed goodies enhancements |
| elfeed-org | :orange_circle: | Load feeds from org file |
| elfeed-search-yank | :orange_circle: | Yank entry URL to kill ring |
| newsticker-start | :orange_circle: | Start fetching news |
| newsticker-stop | :orange_circle: | Stop fetching news |
| newsticker-plainview | :orange_circle: | Show newsticker plain view |
| newsticker-add-url | :orange_circle: | Add a feed URL |
| shr-copy-url | :orange_circle: | Copy URL at point |
| shr-next-link | :orange_circle: | Move to next SHR link |
| shr-previous-link | :orange_circle: | Move to previous SHR link |

### Round 109 — Calendar, Diary & Timeclock

| Command | Status | Description |
|---------|--------|-------------|
| calendar-forward-day | :orange_circle: | Move forward one day |
| calendar-backward-day | :orange_circle: | Move backward one day |
| calendar-forward-week | :orange_circle: | Move forward one week |
| calendar-backward-week | :orange_circle: | Move backward one week |
| calendar-beginning-of-week | :orange_circle: | Move to beginning of week |
| calendar-end-of-week | :orange_circle: | Move to end of week |
| calendar-beginning-of-month | :orange_circle: | Move to beginning of month |
| calendar-end-of-month | :orange_circle: | Move to end of month |
| calendar-goto-date | :orange_circle: | Jump to specific date |
| calendar-unmark | :orange_circle: | Clear all calendar marks |
| calendar-phases-of-moon | :orange_circle: | Show moon phases |
| calendar-print-day-of-year | :orange_circle: | Show day of year |
| timeclock-change | :orange_circle: | Change timeclock project |
| timeclock-status-string | :orange_circle: | Show timeclock status |
| timeclock-reread-log | :orange_circle: | Reread timeclock log |
| timeclock-workday-remaining | :orange_circle: | Show remaining workday time |
| calendar-count-days-region | :orange_circle: | Count days in region |
| calendar-goto-iso-date | :orange_circle: | Jump to ISO date |
| calendar-goto-hebrew-date | :orange_circle: | Jump to Hebrew date |
| calendar-goto-islamic-date | :orange_circle: | Jump to Islamic date |

### Round 110 — VC (Version Control) Extended

| Command | Status | Description |
|---------|--------|-------------|
| vc-print-branch-log | :orange_circle: | Show log for specific branch |
| vc-log-search | :orange_circle: | Search version control log |
| vc-merge | :orange_circle: | Merge a branch |
| vc-root-version-diff | :orange_circle: | Diff entire repository |
| vc-edit-next-command | :orange_circle: | Edit next VC command before run |
| vc-switch-backend | :orange_circle: | Switch VC backend |
| vc-dir-mark-all-files | :orange_circle: | Mark all files in VC dir |
| vc-dir-unmark-all-files | :orange_circle: | Unmark all files in VC dir |
| vc-dir-toggle-mark | :orange_circle: | Toggle mark on current file |
| vc-dir-query-replace-regexp | :orange_circle: | Query replace in marked files |
| vc-dir-search | :orange_circle: | Search in marked files |
| vc-dir-isearch | :orange_circle: | Incremental search in marked files |
| vc-dir-isearch-regexp | :orange_circle: | Regexp isearch in marked files |
| vc-dir-hide-state | :orange_circle: | Hide files by state |
| vc-dir-show-fileentry | :orange_circle: | Show file entry details |
| vc-dir-kill-line | :orange_circle: | Remove entry from listing |
| vc-dir-clean-directory | :orange_circle: | Clean untracked files |
| vc-dir-find-file-other-window | :orange_circle: | Open file in other window |
| vc-dir-previous-directory | :orange_circle: | Move to previous directory |
| vc-dir-next-directory | :orange_circle: | Move to next directory |

### Round 111 — C/C++, Python & Java Programming

| Command | Status | Description |
|---------|--------|-------------|
| c-toggle-auto-newline | :orange_circle: | Toggle C auto-newline mode |
| c-toggle-hungry-state | :orange_circle: | Toggle C hungry-delete mode |
| c-toggle-electric-state | :orange_circle: | Toggle C electric state |
| c-set-style | :orange_circle: | Set C indentation style |
| c-set-offset | :orange_circle: | Set C offset for syntactic symbol |
| c-indent-defun | :orange_circle: | Indent current C function |
| c-mark-function | :orange_circle: | Mark current C function |
| c-beginning-of-defun | :orange_circle: | Move to beginning of C function |
| c-end-of-defun | :orange_circle: | Move to end of C function |
| c-backward-conditional | :orange_circle: | Move to previous preprocessor conditional |
| c-forward-conditional | :orange_circle: | Move to next preprocessor conditional |
| c-up-conditional | :orange_circle: | Move up to enclosing #if |
| python-shell-send-defun | :orange_circle: | Send function to Python shell |
| python-shell-send-buffer | :orange_circle: | Send buffer to Python shell |
| python-shell-send-file | :orange_circle: | Send file to Python shell |
| python-shell-send-string | :orange_circle: | Evaluate string in Python shell |
| python-check | :orange_circle: | Run Python syntax checker |
| python-describe-at-point | :orange_circle: | Describe Python symbol at point |
| python-eldoc-at-point | :orange_circle: | Show eldoc for Python symbol |
| java-mode | :orange_circle: | Activate Java major mode |

### Round 112 — Compilation & GDB Debugging

| Command | Status | Description |
|---------|--------|-------------|
| compilation-next-error | :orange_circle: | Move to next compilation error |
| compilation-previous-error | :orange_circle: | Move to previous compilation error |
| previous-error-no-select | :orange_circle: | Previous error without selecting |
| gdb | :orange_circle: | Start GDB debugger |
| gdb-restore-windows | :orange_circle: | Restore GDB window layout |
| gud-tbreak | :orange_circle: | Set temporary breakpoint |
| gud-next | :orange_circle: | Step over (next line) |
| gud-cont | :orange_circle: | Continue execution |
| gud-finish | :orange_circle: | Run until function returns |
| gud-until | :orange_circle: | Continue until current line |
| gud-print | :orange_circle: | Print expression at point |
| gud-pstar | :orange_circle: | Print dereferenced expression |
| gud-run | :orange_circle: | Start program execution |
| gud-stepi | :orange_circle: | Step one instruction |
| gud-nexti | :orange_circle: | Next instruction (step over) |
| gud-jump | :orange_circle: | Jump to current line |
| gud-up | :orange_circle: | Move up one stack frame |
| gud-down | :orange_circle: | Move down one stack frame |
| gud-refresh | :orange_circle: | Refresh GUD display |
| gdb-display-disassembly-buffer | :orange_circle: | Display disassembly buffer |

### Round 113 — TRAMP, System Tools & Calc

| Command | Status | Description |
|---------|--------|-------------|
| tramp-append-tramp-buffers | :orange_circle: | Append TRAMP debug buffers |
| tramp-revert-buffer-check | :orange_circle: | Check remote buffer for changes |
| tramp-rename-these-files | :orange_circle: | Rename TRAMP files |
| make-serial-process | :orange_circle: | Connect to serial port |
| proced-mark | :orange_circle: | Mark process in proced |
| proced-unmark | :orange_circle: | Unmark process in proced |
| proced-toggle-tree | :orange_circle: | Toggle proced tree view |
| proced-renice | :orange_circle: | Change process priority |
| proced-refine | :orange_circle: | Refine proced listing |
| list-system-processes | :orange_circle: | List all system processes |
| battery | :orange_circle: | Display battery status |
| disk-usage-by-types | :orange_circle: | Show disk usage by file types |
| net-utils-run-simple | :orange_circle: | Run simple network utility |
| nslookup-host | :orange_circle: | DNS lookup for host |
| route | :orange_circle: | Display routing table |
| display-time-world | :orange_circle: | Show world clock |
| time-stamp | :orange_circle: | Update timestamp in buffer |
| calc-trail-display | :orange_circle: | Display calc trail buffer |
| calc-keypad | :orange_circle: | Open calculator keypad |
| calc-embedded | :orange_circle: | Toggle calc embedded mode |

### Round 114 — Byte Compilation, Checkdoc & Misc

| Command | Status | Description |
|---------|--------|-------------|
| byte-compile-file | :orange_circle: | Byte compile a file |
| byte-recompile-directory | :orange_circle: | Recompile all files in directory |
| batch-byte-compile | :orange_circle: | Batch byte compilation |
| disassemble | :orange_circle: | Disassemble a function |
| emacs-lisp-byte-compile | :orange_circle: | Byte compile current buffer |
| emacs-lisp-byte-compile-and-load | :orange_circle: | Byte compile and load buffer |
| native-compile | :orange_circle: | Native compile a file |
| native-compile-async | :orange_circle: | Async native compilation |
| checkdoc-current-buffer | :orange_circle: | Check docstrings in buffer |
| checkdoc-defun | :orange_circle: | Check docstring of current defun |
| checkdoc-ispell | :orange_circle: | Spell-check docstrings |
| package-quickstart-refresh | :orange_circle: | Refresh package quickstart |
| package-vc-install-from-checkout | :orange_circle: | Install package from checkout |
| package-vc-rebuild | :orange_circle: | Rebuild VC-installed package |
| package-report-bug | :orange_circle: | Report bug for package |
| finder-list-keywords | :orange_circle: | List all finder keywords |
| load-theme-buffer-local | :orange_circle: | Load theme for current buffer |
| cua-set-rectangle-mark | :orange_circle: | Set CUA rectangle mark |
| cua-toggle-global-mark | :orange_circle: | Toggle CUA global mark |
| speedbar-toggle-show-all-files | :orange_circle: | Toggle speedbar all files |

### Round 115 — LaTeX, AUCTeX & RefTeX

| Command | Status | Description |
|---------|--------|-------------|
| latex-mode | :orange_circle: | Activate LaTeX major mode |
| latex-close-block | :orange_circle: | Close current LaTeX block |
| latex-insert-block | :orange_circle: | Insert a LaTeX block |
| latex-insert-environment | :orange_circle: | Insert begin/end environment |
| latex-insert-item | :orange_circle: | Insert \\item |
| TeX-command-master | :orange_circle: | Run TeX on master file |
| TeX-command-region | :orange_circle: | Run TeX on region |
| TeX-command-buffer | :orange_circle: | Run TeX on buffer |
| TeX-view | :orange_circle: | View compiled output |
| TeX-next-error | :orange_circle: | Move to next TeX error |
| TeX-previous-error | :orange_circle: | Move to previous TeX error |
| TeX-clean | :orange_circle: | Clean auxiliary files |
| TeX-kill-job | :orange_circle: | Kill running TeX job |
| TeX-recenter-output-buffer | :orange_circle: | Recenter TeX output buffer |
| LaTeX-environment | :orange_circle: | Insert LaTeX environment |
| LaTeX-section | :orange_circle: | Insert LaTeX section |
| LaTeX-fill-environment | :orange_circle: | Fill current environment |
| LaTeX-close-environment | :orange_circle: | Close current environment |
| LaTeX-insert-item | :orange_circle: | Insert item in list |
| reftex-mode | :orange_circle: | Toggle RefTeX mode |

### Round 116 — ERC (IRC) & RCIRC Communication

| Command | Status | Description |
|---------|--------|-------------|
| erc-select | :orange_circle: | Connect to IRC server |
| erc-join | :orange_circle: | Join IRC channel |
| erc-part | :orange_circle: | Part current channel |
| erc-msg | :orange_circle: | Send private message |
| erc-away | :orange_circle: | Set away status |
| erc-cmd-TOPIC | :orange_circle: | Set channel topic |
| erc-match-mode | :orange_circle: | Toggle ERC match highlighting |
| erc-log-mode | :orange_circle: | Toggle ERC logging |
| erc-button-mode | :orange_circle: | Toggle ERC clickable buttons |
| erc-spelling-mode | :orange_circle: | Toggle ERC spell checking |
| erc-notifications-mode | :orange_circle: | Toggle ERC notifications |
| erc-image-mode | :orange_circle: | Toggle ERC inline images |
| rcirc-cmd-join | :orange_circle: | RCIRC join channel |
| rcirc-cmd-part | :orange_circle: | RCIRC part channel |
| rcirc-cmd-nick | :orange_circle: | RCIRC change nickname |
| rcirc-cmd-whois | :orange_circle: | RCIRC whois lookup |
| rcirc-cmd-msg | :orange_circle: | RCIRC send private message |
| rcirc-cmd-quit | :orange_circle: | RCIRC disconnect |
| rcirc-cmd-topic | :orange_circle: | RCIRC set topic |
| rcirc-cmd-away | :orange_circle: | RCIRC set away |

### Round 117 — Markdown Mode

| Command | Status | Description |
|---------|--------|-------------|
| markdown-mode | :orange_circle: | Activate Markdown mode |
| markdown-export | :orange_circle: | Export to HTML |
| markdown-live-preview-mode | :orange_circle: | Toggle live preview |
| markdown-insert-header-atx-1 | :orange_circle: | Insert # heading |
| markdown-insert-header-atx-2 | :orange_circle: | Insert ## heading |
| markdown-insert-link | :orange_circle: | Insert link |
| markdown-insert-image | :orange_circle: | Insert image |
| markdown-insert-code | :orange_circle: | Insert code block |
| markdown-insert-blockquote | :orange_circle: | Insert blockquote |
| markdown-insert-list-item | :orange_circle: | Insert list item |
| markdown-insert-footnote | :orange_circle: | Insert footnote |
| markdown-insert-hr | :orange_circle: | Insert horizontal rule |
| markdown-toggle-markup-hiding | :orange_circle: | Toggle markup hiding |
| markdown-toggle-fontify-code-blocks-natively | :orange_circle: | Toggle native code fontification |
| markdown-move-up | :orange_circle: | Move element up |
| markdown-move-down | :orange_circle: | Move element down |
| markdown-outline-previous | :orange_circle: | Move to previous heading |
| markdown-outline-next | :orange_circle: | Move to next heading |
| markdown-insert-header-atx-3 | :orange_circle: | Insert ### heading |
| markdown-insert-bold | :orange_circle: | Insert bold markup |

### Round 118 — DevOps Modes (YAML, Docker, Terraform, Ansible)

| Command | Status | Description |
|---------|--------|-------------|
| yaml-indent-line | :orange_circle: | Indent YAML line |
| yaml-fill-paragraph | :orange_circle: | Fill YAML paragraph |
| dockerfile-build-buffer | :orange_circle: | Build Docker image from buffer |
| docker-pull | :orange_circle: | Pull Docker image |
| terraform-format-buffer | :orange_circle: | Format Terraform buffer |
| terraform-init | :orange_circle: | Initialize Terraform |
| terraform-apply | :orange_circle: | Apply Terraform changes |
| ansible-doc | :orange_circle: | Show Ansible module documentation |
| terraform-destroy | :orange_circle: | Destroy Terraform infrastructure |
| terraform-output | :orange_circle: | Show Terraform outputs |
| terraform-state-list | :orange_circle: | List Terraform state resources |
| ansible-lint | :orange_circle: | Lint Ansible playbook |
| ansible-playbook-run | :orange_circle: | Run Ansible playbook |
| ansible-inventory-list | :orange_circle: | List Ansible inventory |
| docker-run | :orange_circle: | Run Docker container |
| docker-stop | :orange_circle: | Stop Docker container |
| docker-restart | :orange_circle: | Restart Docker container |
| docker-exec | :orange_circle: | Execute in Docker container |
| docker-inspect | :orange_circle: | Inspect Docker object |
| docker-kill | :orange_circle: | Kill Docker container |

### Round 119 — SQL & Database Modes

| Command | Status | Description |
|---------|--------|-------------|
| sql-send-paragraph | :orange_circle: | Send current paragraph to SQL process |
| sql-send-string | :orange_circle: | Send string to SQL process |
| sql-send-line-and-next | :orange_circle: | Send line and move to next |
| sql-product-interactive | :orange_circle: | Start interactive SQL session |
| sql-set-sqli-buffer | :orange_circle: | Set SQLi buffer |
| sql-toggle-pop-to-buffer-after-send-region | :orange_circle: | Toggle pop to buffer after send |
| sql-highlight-ansi-keywords | :orange_circle: | Highlight ANSI SQL keywords |
| sql-highlight-oracle-keywords | :orange_circle: | Highlight Oracle keywords |
| sql-highlight-postgres-keywords | :orange_circle: | Highlight PostgreSQL keywords |
| sql-highlight-mysql-keywords | :orange_circle: | Highlight MySQL keywords |
| sql-list-all | :orange_circle: | List all database objects |
| sql-list-table | :orange_circle: | List table columns |
| sql-rename-buffer | :orange_circle: | Rename SQL buffer |
| sql-copy-column | :orange_circle: | Copy column to kill ring |
| sql-beginning-of-statement | :orange_circle: | Move to beginning of statement |
| sql-end-of-statement | :orange_circle: | Move to end of statement |
| sql-magic-go | :orange_circle: | Send batch via 'go' command |
| sql-magic-semicolon | :orange_circle: | Insert semicolon and send |
| sql-redirect | :orange_circle: | Redirect SQL output to file |
| sql-accumulate-and-indent | :orange_circle: | Accumulate and indent SQL |

### Round 120 — Semantic/CEDET & Senator

| Command | Status | Description |
|---------|--------|-------------|
| semantic-mode | :orange_circle: | Toggle Semantic mode |
| semantic-complete-analyze-inline | :orange_circle: | Inline completion analysis |
| semantic-complete-jump | :orange_circle: | Jump to completion target |
| semantic-complete-self-insert | :orange_circle: | Self-insert with completion |
| semantic-decoration-include-visit | :orange_circle: | Visit included file |
| semantic-ia-describe-class | :orange_circle: | Describe class at point |
| semantic-ia-fast-jump | :orange_circle: | Fast jump to definition |
| semantic-ia-show-doc | :orange_circle: | Show documentation |
| semantic-ia-show-summary | :orange_circle: | Show summary |
| semantic-mrub-switch-tags | :orange_circle: | Switch MRU bookmark tags |
| semantic-symref | :orange_circle: | Find symbol references |
| semantic-symref-symbol | :orange_circle: | Find references to symbol |
| senator-next-tag | :orange_circle: | Move to next tag |
| senator-previous-tag | :orange_circle: | Move to previous tag |
| senator-go-to-up-reference | :orange_circle: | Move to parent reference |
| senator-copy-tag | :orange_circle: | Copy tag |
| senator-kill-tag | :orange_circle: | Kill tag |
| senator-yank-tag | :orange_circle: | Yank tag |
| senator-fold-tag | :orange_circle: | Fold tag |
| senator-unfold-tag | :orange_circle: | Unfold tag |

---

### Round 121 — Gnus Newsreader

| Command | Status | Description |
|---------|--------|-------------|
| gnus-group-get-new-news | :orange_circle: | Check for new news in all groups |
| gnus-group-read-group | :orange_circle: | Enter a newsgroup |
| gnus-group-list-all-groups | :orange_circle: | List all available groups |
| gnus-group-list-groups | :orange_circle: | List subscribed groups |
| gnus-group-subscribe-by-regexp | :orange_circle: | Subscribe to groups matching regexp |
| gnus-group-unsubscribe-group | :orange_circle: | Unsubscribe from current group |
| gnus-summary-next-article | :orange_circle: | Go to next article |
| gnus-summary-prev-article | :orange_circle: | Go to previous article |
| gnus-summary-next-unread-article | :orange_circle: | Go to next unread article |
| gnus-summary-scroll-up | :orange_circle: | Scroll article up |
| gnus-summary-mark-as-read-forward | :orange_circle: | Mark article as read and advance |
| gnus-summary-mark-as-unread | :orange_circle: | Mark article as unread |
| gnus-summary-catchup | :orange_circle: | Mark all articles as read |
| gnus-summary-catchup-and-exit | :orange_circle: | Catchup and exit group |
| gnus-summary-followup | :orange_circle: | Post a followup |
| gnus-summary-reply | :orange_circle: | Reply to article |
| gnus-summary-reply-with-original | :orange_circle: | Reply with original text quoted |
| gnus-summary-mail-forward | :orange_circle: | Forward article by mail |
| gnus-summary-save-article | :orange_circle: | Save article to file |
| gnus-summary-tick-article-forward | :orange_circle: | Tick article and advance |

---

### Round 122 — Speedbar, Flyspell, Bookmarks, Crux

| Command | Status | Description |
|---------|--------|-------------|
| speedbar-expand-line | :orange_circle: | Expand speedbar line |
| speedbar-contract-line | :orange_circle: | Contract speedbar line |
| speedbar-refresh | :orange_circle: | Refresh speedbar |
| speedbar-update-contents | :orange_circle: | Update speedbar contents |
| flyspell-auto-correct-previous-word | :orange_circle: | Auto-correct previous misspelled word |
| flyspell-correct-word-before-point | :orange_circle: | Correct word before point |
| bookmark-bmenu-search | :orange_circle: | Search bookmark list |
| bookmark-bmenu-rename | :orange_circle: | Rename bookmark |
| bookmark-bmenu-delete | :orange_circle: | Delete bookmark |
| bookmark-bmenu-save | :orange_circle: | Save bookmark list |
| symbol-overlay-next | :orange_circle: | Jump to next symbol overlay |
| symbol-overlay-prev | :orange_circle: | Jump to previous symbol overlay |
| symbol-overlay-mode | :orange_circle: | Toggle symbol overlay mode |
| move-dup-move-lines-up | :orange_circle: | Move lines up |
| move-dup-move-lines-down | :orange_circle: | Move lines down |
| move-dup-duplicate-up | :orange_circle: | Duplicate lines up |
| move-dup-duplicate-down | :orange_circle: | Duplicate lines down |
| crux-smart-open-line | :orange_circle: | Smart open line below |
| crux-smart-open-line-above | :orange_circle: | Smart open line above |
| crux-top-join-line | :orange_circle: | Join line with previous |

---

### Round 123 — Profiler, Mail, Charset, Image, Frame

| Command | Status | Description |
|---------|--------|-------------|
| profiler-reset | :orange_circle: | Reset profiler data |
| proced-mark-all | :orange_circle: | Mark all processes |
| zones-mode | :orange_circle: | Toggle zones mode |
| global-auto-composition-mode | :orange_circle: | Toggle global auto-composition |
| list-charset-chars | :orange_circle: | List characters in charset |
| list-character-sets | :orange_circle: | List available character sets |
| mail-cc | :orange_circle: | Set mail CC field |
| mail-bcc | :orange_circle: | Set mail BCC field |
| mail-subject | :orange_circle: | Set mail subject |
| mail-to | :orange_circle: | Set mail To field |
| mail-text | :orange_circle: | Move to mail text body |
| mail-signature | :orange_circle: | Insert mail signature |
| browse-url-of-file | :orange_circle: | Open file in browser |
| eww-browse-with-external-browser | :orange_circle: | Open URL in external browser |
| image-mode-fit-frame | :orange_circle: | Fit image to frame |
| image-transform-reset | :orange_circle: | Reset image transform |
| view-emacs-todo | :orange_circle: | View Emacs TODO list |
| view-external-packages | :orange_circle: | View external packages |
| package-install-selected-packages | :orange_circle: | Install selected packages |
| select-frame-by-name | :orange_circle: | Select frame by name |

---

### Round 124 — Registers, Hi-Lock, Fill, Web-mode

| Command | Status | Description |
|---------|--------|-------------|
| register-read-with-preview | :orange_circle: | Read register with preview |
| register-list | :orange_circle: | Display register list |
| copy-rectangle-as-kill | :orange_circle: | Copy rectangle as kill |
| rectangle-number-lines | :orange_circle: | Number lines in rectangle |
| delete-whitespace-rectangle | :orange_circle: | Delete whitespace in rectangle |
| buffer-face-set | :orange_circle: | Set buffer face |
| global-display-fill-column-indicator-mode | :orange_circle: | Toggle global fill column indicator |
| fill-nonuniform-paragraphs | :orange_circle: | Fill nonuniform paragraphs |
| repunctuate-sentences | :orange_circle: | Repunctuate sentences |
| align-newline-and-indent | :orange_circle: | Align newline and indent |
| loccur | :orange_circle: | Show lines matching regexp |
| hi-lock-write-interactive-patterns | :orange_circle: | Write hi-lock patterns to buffer |
| hi-lock-find-patterns | :orange_circle: | Find hi-lock patterns in buffer |
| hi-lock-revert-buffer | :orange_circle: | Revert hi-lock buffer patterns |
| nxml-finish-element | :orange_circle: | Finish NXML element |
| nxml-balanced-close-start-tag-block | :orange_circle: | Balanced close start tag block |
| css-cycle-color-format | :orange_circle: | Cycle CSS color format |
| js-find-symbol | :orange_circle: | Find JavaScript symbol |
| web-mode-element-close | :orange_circle: | Close web-mode element |
| web-mode-tag-match | :orange_circle: | Jump to matching tag |

---

### Round 125 — Eglot, Tab-bar, Treesit, Devdocs, Helpful

| Command | Status | Description |
|---------|--------|-------------|
| project-shell-command | :orange_circle: | Run shell command in project |
| xref-query-replace-in-results | :orange_circle: | Query replace in xref results |
| eglot-shutdown-all | :orange_circle: | Shut down all Eglot servers |
| eglot-signal-didOpen | :orange_circle: | Signal didOpen to LSP server |
| eglot-hierarchy-call-hierarchy | :orange_circle: | Show call hierarchy |
| eglot-hierarchy-type-hierarchy | :orange_circle: | Show type hierarchy |
| tab-bar-select-tab-by-name | :orange_circle: | Select tab by name |
| tab-bar-move-tab-to | :orange_circle: | Move tab to position |
| tab-bar-switch-to-recent-tab | :orange_circle: | Switch to most recent tab |
| treesit-beginning-of-defun | :orange_circle: | Move to beginning of defun (treesit) |
| treesit-end-of-defun | :orange_circle: | Move to end of defun (treesit) |
| treesit-transpose-sexps | :orange_circle: | Transpose sexps (treesit) |
| devdocs-install | :orange_circle: | Install devdocs documentation |
| devdocs-search | :orange_circle: | Search devdocs |
| devdocs-peruse | :orange_circle: | Browse devdocs |
| helpful-at-point | :orange_circle: | Help for symbol at point |
| helpful-symbol | :orange_circle: | Help for symbol |
| helpful-macro | :orange_circle: | Help for macro |
| helpful-command | :orange_circle: | Help for command |
| helpful-function | :orange_circle: | Help for function |

---

### Round 126 — Transient, Doom, Spacemacs, Ivy

| Command | Status | Description |
|---------|--------|-------------|
| transient-suspend | :orange_circle: | Suspend transient |
| transient-toggle-common | :orange_circle: | Toggle common transient commands |
| transient-reset | :orange_circle: | Reset transient to defaults |
| hydra-pause-resume | :orange_circle: | Pause/resume hydra |
| ace-window-display-mode | :orange_circle: | Toggle ace-window display mode |
| avy-goto-subword-1 | :orange_circle: | Jump to subword by char |
| avy-transpose-lines-in-region | :orange_circle: | Transpose lines in region via avy |
| doom-reload | :orange_circle: | Reload Doom configuration |
| doom-doctor | :orange_circle: | Run Doom doctor diagnostics |
| doom-info | :orange_circle: | Display Doom system info |
| doom-upgrade | :orange_circle: | Upgrade Doom packages |
| doom-env | :orange_circle: | Regenerate Doom env file |
| spacemacs-home | :orange_circle: | Show Spacemacs home buffer |
| spacemacs-purpose | :orange_circle: | Show Spacemacs purpose config |
| ivy-switch-buffer-other-window | :orange_circle: | Switch buffer in other window via Ivy |
| ivy-push-view | :orange_circle: | Push Ivy view |
| ivy-pop-view | :orange_circle: | Pop Ivy view |
| ivy-switch-view | :orange_circle: | Switch Ivy view |
| ivy-dispatching-done | :orange_circle: | Ivy dispatching done |
| ivy-avy | :orange_circle: | Ivy avy selection |

---

### Round 127 — Counsel, Ivy, Swiper Extended

| Command | Status | Description |
|---------|--------|-------------|
| ivy-call | :orange_circle: | Call action without exiting Ivy |
| ivy-immediate-done | :orange_circle: | Use exact input in Ivy |
| ivy-partial-or-done | :orange_circle: | Partial completion or done |
| ivy-alt-done | :orange_circle: | Alternate done action |
| ivy-occur | :orange_circle: | Open Ivy occur buffer |
| ivy-occur-read-action | :orange_circle: | Read action from occur |
| counsel-colors-emacs | :orange_circle: | Browse Emacs colors |
| counsel-colors-web | :orange_circle: | Browse web colors |
| counsel-command-history | :orange_circle: | Browse command history |
| counsel-evil-registers | :orange_circle: | Browse evil registers |
| counsel-faces | :orange_circle: | Browse faces |
| counsel-file-jump | :orange_circle: | Jump to file |
| counsel-fzf | :orange_circle: | FZF file search |
| counsel-linux-app | :orange_circle: | Launch Linux application |
| counsel-minor | :orange_circle: | Browse minor modes |
| counsel-org-capture | :orange_circle: | Org capture template selection |
| counsel-org-tag | :orange_circle: | Org tag selection |
| counsel-org-file | :orange_circle: | Browse org files |
| counsel-outline | :orange_circle: | Browse outline headings |
| counsel-package | :orange_circle: | Browse packages |

---

### Round 128 — Counsel/Swiper, Windmove, Buffer-move, Eyebrowse

| Command | Status | Description |
|---------|--------|-------------|
| counsel-set-variable | :orange_circle: | Set variable via Counsel |
| counsel-yank-pop | :orange_circle: | Browse kill ring via Counsel |
| swiper-isearch-thing-at-point | :orange_circle: | Swiper isearch thing at point |
| swiper-thing-at-point | :orange_circle: | Swiper search thing at point |
| eval-minibuffer | :orange_circle: | Evaluate expression in minibuffer |
| custom-theme-visit-theme | :orange_circle: | Visit custom theme |
| package-menu-mark-upgrades | :orange_circle: | Mark package upgrades |
| windmove-delete-left | :orange_circle: | Delete window to the left |
| windmove-delete-right | :orange_circle: | Delete window to the right |
| windmove-delete-up | :orange_circle: | Delete window above |
| windmove-delete-down | :orange_circle: | Delete window below |
| buf-move-left | :orange_circle: | Move buffer left |
| buf-move-right | :orange_circle: | Move buffer right |
| buf-move-up | :orange_circle: | Move buffer up |
| buf-move-down | :orange_circle: | Move buffer down |
| flop-frame | :orange_circle: | Flop frame vertically |
| rotate-frame-clockwise | :orange_circle: | Rotate frame clockwise |
| rotate-frame-anticlockwise | :orange_circle: | Rotate frame anticlockwise |
| eyebrowse-switch-to-window-config-1 | :orange_circle: | Switch to eyebrowse config 1 |
| eyebrowse-switch-to-window-config-2 | :orange_circle: | Switch to eyebrowse config 2 |

---

### Round 129 — Eyebrowse, Native-compile, Eshell

| Command | Status | Description |
|---------|--------|-------------|
| eyebrowse-create-window-config | :orange_circle: | Create eyebrowse window config |
| eyebrowse-close-window-config | :orange_circle: | Close eyebrowse window config |
| eyebrowse-rename-window-config | :orange_circle: | Rename eyebrowse window config |
| consult-buffer-other-frame | :orange_circle: | Open buffer in other frame via Consult |
| native-comp-speed | :orange_circle: | Set native compilation speed |
| emacs-lisp-native-compile-and-load | :orange_circle: | Native compile and load |
| macroexpand-1 | :orange_circle: | Expand macro one level |
| eshell-previous-input | :orange_circle: | Previous eshell input |
| eshell-next-input | :orange_circle: | Next eshell input |
| eshell-previous-matching-input | :orange_circle: | Previous matching eshell input |
| eshell-next-matching-input | :orange_circle: | Next matching eshell input |
| eshell-send-input | :orange_circle: | Send eshell input |
| eshell-interrupt-process | :orange_circle: | Interrupt eshell process |
| eshell-kill-process | :orange_circle: | Kill eshell process |
| eshell-quit-process | :orange_circle: | Quit eshell process |
| eshell-show-output | :orange_circle: | Show last eshell output |
| eshell-show-maximum-output | :orange_circle: | Show maximum eshell output |
| eshell-clear-buffer | :orange_circle: | Clear eshell buffer |
| eshell-toggle-cd | :orange_circle: | Toggle eshell cd |
| eshell-pcomplete | :orange_circle: | Eshell programmable completion |

---

### Round 130 — Eshell/Comint/Term, Treemacs Extended

| Command | Status | Description |
|---------|--------|-------------|
| eshell-list-history | :orange_circle: | List eshell command history |
| eshell-previous-prompt | :orange_circle: | Move to previous eshell prompt |
| eshell-next-prompt | :orange_circle: | Move to next eshell prompt |
| comint-previous-matching-input-from-input | :orange_circle: | Previous matching comint input |
| comint-next-matching-input-from-input | :orange_circle: | Next matching comint input |
| term-send-raw | :orange_circle: | Send raw character in term |
| term-send-raw-meta | :orange_circle: | Send raw meta character in term |
| term-pager-toggle | :orange_circle: | Toggle term pager |
| treemacs-expand-project | :orange_circle: | Expand treemacs project |
| treemacs-display-current-project-exclusively | :orange_circle: | Display only current project |
| treemacs-toggle-show-dotfiles | :orange_circle: | Toggle showing dotfiles |
| treemacs-copy-project-path-at-point | :orange_circle: | Copy project path |
| treemacs-copy-file-path-at-point | :orange_circle: | Copy file path |
| treemacs-copy-absolute-path-at-point | :orange_circle: | Copy absolute path |
| treemacs-copy-relative-path-at-point | :orange_circle: | Copy relative path |
| treemacs-move-project-up | :orange_circle: | Move project up in tree |
| treemacs-move-project-down | :orange_circle: | Move project down in tree |
| treemacs-visit-node-default | :orange_circle: | Visit node (default) |
| treemacs-visit-node-ace | :orange_circle: | Visit node via ace |
| treemacs-peek-mode | :orange_circle: | Toggle treemacs peek mode |

---

### Round 131 — Org-roam, Org-journal, Org-noter

| Command | Status | Description |
|---------|--------|-------------|
| org-roam-capture | :orange_circle: | Capture new org-roam note |
| org-roam-dailies-capture-yesterday | :orange_circle: | Capture yesterday's daily |
| org-roam-dailies-capture-tomorrow | :orange_circle: | Capture tomorrow's daily |
| org-roam-graph | :orange_circle: | Display knowledge graph |
| org-roam-ui-mode | :orange_circle: | Toggle org-roam UI mode |
| org-roam-ui-open | :orange_circle: | Open org-roam UI in browser |
| org-journal-open-current-journal-file | :orange_circle: | Open current journal file |
| org-journal-search-forever | :orange_circle: | Search all journal entries |
| org-journal-new-date-entry | :orange_circle: | New journal entry for date |
| org-journal-new-scheduled-entry | :orange_circle: | New scheduled journal entry |
| org-noter | :orange_circle: | Start org-noter session |
| org-noter-insert-note | :orange_circle: | Insert note at location |
| org-noter-sync-current-note | :orange_circle: | Sync to current note |
| org-noter-sync-prev-note | :orange_circle: | Sync to previous note |
| org-noter-sync-next-note | :orange_circle: | Sync to next note |
| org-noter-create-skeleton | :orange_circle: | Create skeleton from document |
| org-noter-kill-session | :orange_circle: | Kill noter session |
| org-download-clipboard | :orange_circle: | Paste image from clipboard |
| org-download-screenshot | :orange_circle: | Capture screenshot |
| org-download-yank | :orange_circle: | Yank image from URL |

---

### Round 132 — LSP Extended, DAP, AI Tools

| Command | Status | Description |
|---------|--------|-------------|
| lsp-find-declaration | :orange_circle: | Find declaration via LSP |
| lsp-find-type-definition | :orange_circle: | Find type definition via LSP |
| lsp-signature-activate | :orange_circle: | Activate signature help |
| lsp-signature-toggle-full-docs | :orange_circle: | Toggle full signature docs |
| lsp-ui-doc-hide | :orange_circle: | Hide LSP UI doc popup |
| lsp-ui-doc-focus-frame | :orange_circle: | Focus LSP UI doc frame |
| lsp-ui-imenu | :orange_circle: | LSP UI imenu |
| dap-ui-show-many-windows | :orange_circle: | Show DAP debug windows |
| copilot-accept-completion-by-word | :orange_circle: | Accept Copilot completion by word |
| copilot-accept-completion-by-line | :orange_circle: | Accept Copilot completion by line |
| copilot-clear-overlay | :orange_circle: | Clear Copilot overlay |
| dall-e-shell | :orange_circle: | Open DALL-E shell |
| codeium-completion-at-point | :orange_circle: | Codeium completion at point |
| codeium-mode | :orange_circle: | Toggle Codeium mode |
| tabnine-accept-completion | :orange_circle: | Accept TabNine completion |
| tabnine-mode | :orange_circle: | Toggle TabNine mode |
| ellama-ask | :orange_circle: | Ask Ellama AI |
| ellama-code-add | :orange_circle: | Generate code with Ellama |
| ellama-code-edit | :orange_circle: | Edit code with Ellama |
| minions-minor-modes-menu | :orange_circle: | Show minions minor modes menu |

---

### Round 133 — Paredit, Smartparens, Lispy Extended

| Command | Status | Description |
|---------|--------|-------------|
| paredit-add-to-next-list | :orange_circle: | Add sexp to next list |
| paredit-add-to-previous-list | :orange_circle: | Add sexp to previous list |
| paredit-join-with-next-list | :orange_circle: | Join with next list |
| paredit-join-with-previous-list | :orange_circle: | Join with previous list |
| sp-swap-enclosing | :orange_circle: | Swap enclosing delimiters |
| sp-splice-sexp-killing-around | :orange_circle: | Splice killing around |
| sp-emit-sexp | :orange_circle: | Emit sexp |
| sp-absorb-sexp | :orange_circle: | Absorb sexp |
| sp-convolute-sexp | :orange_circle: | Convolute sexp |
| sp-transpose-sexp | :orange_circle: | Transpose sexps |
| sp-split-sexp | :orange_circle: | Split sexp |
| sp-join-sexp | :orange_circle: | Join sexps |
| sp-select-next-thing-exchange | :orange_circle: | Select next thing (exchange) |
| sp-highlight-current-sexp | :orange_circle: | Highlight current sexp |
| sp-show-enclosing-pair | :orange_circle: | Show enclosing pair |
| lispy-ace-paren | :orange_circle: | Ace jump to paren |
| lispy-ace-char | :orange_circle: | Ace jump to char |
| lispy-ace-symbol | :orange_circle: | Ace jump to symbol |
| lispy-ace-subword | :orange_circle: | Ace jump to subword |
| lispy-different | :orange_circle: | Jump to different position |

---

### Round 134 — Lispy, Sly, Geiser, CIDER

| Command | Status | Description |
|---------|--------|-------------|
| lispy-flow | :orange_circle: | Flow to next sexp |
| lispy-knight | :orange_circle: | Knight move |
| lispy-eval | :orange_circle: | Evaluate sexp |
| lispy-eval-and-insert | :orange_circle: | Evaluate and insert result |
| lispy-goto-first | :orange_circle: | Jump to first sexp |
| lispy-goto-last | :orange_circle: | Jump to last sexp |
| lispy-beginning-of-defun | :orange_circle: | Move to beginning of defun |
| sly-connect | :orange_circle: | Connect to Sly server |
| sly-compile-and-load-file | :orange_circle: | Compile and load file via Sly |
| sly-documentation-lookup | :orange_circle: | Look up Sly documentation |
| sly-inspect | :orange_circle: | Inspect via Sly |
| sly-stickers-toggle-break-on-stickers | :orange_circle: | Toggle break on stickers |
| geiser-eval-region | :orange_circle: | Evaluate region via Geiser |
| geiser-doc-module | :orange_circle: | Show Geiser module docs |
| geiser-expand-current-form | :orange_circle: | Expand current form |
| geiser-expand-region | :orange_circle: | Expand region |
| geiser-set-scheme | :orange_circle: | Set Scheme implementation |
| geiser-compile-current-buffer | :orange_circle: | Compile current buffer |
| cider-connect | :orange_circle: | Connect to CIDER |
| cider-eval-defun-at-point | :orange_circle: | Evaluate defun at point via CIDER |

---

### Round 135 — PDF-tools, Elfeed, Mu4e

| Command | Status | Description |
|---------|--------|-------------|
| pdf-view-first-page | :orange_circle: | Jump to first PDF page |
| pdf-view-last-page | :orange_circle: | Jump to last PDF page |
| pdf-view-fit-page-to-window | :orange_circle: | Fit PDF page to window |
| pdf-view-fit-width-to-window | :orange_circle: | Fit PDF width to window |
| pdf-view-fit-height-to-window | :orange_circle: | Fit PDF height to window |
| pdf-view-midnight-minor-mode | :orange_circle: | Toggle PDF midnight mode |
| pdf-view-auto-slice-minor-mode | :orange_circle: | Toggle PDF auto-slice mode |
| pdf-annot-add-highlight-markup-annotation | :orange_circle: | Add PDF highlight annotation |
| pdf-annot-add-underline-markup-annotation | :orange_circle: | Add PDF underline annotation |
| pdf-annot-add-text-annotation | :orange_circle: | Add PDF text annotation |
| pdf-annot-delete | :orange_circle: | Delete PDF annotation |
| elfeed-search-clear-filter | :orange_circle: | Clear Elfeed search filter |
| elfeed-search-tag-all-unread | :orange_circle: | Tag all as unread |
| elfeed-search-untag-all-unread | :orange_circle: | Untag all unread |
| elfeed-show-tag | :orange_circle: | Add tag to entry |
| elfeed-show-untag | :orange_circle: | Remove tag from entry |
| mu4e-search | :orange_circle: | Search mail via Mu4e |
| mu4e-headers-next | :orange_circle: | Next Mu4e header |
| mu4e-headers-prev | :orange_circle: | Previous Mu4e header |
| mu4e-view-action | :orange_circle: | Mu4e view action |

---

### Round 136 — Notmuch, Wanderlust, BBDB, Ledger

| Command | Status | Description |
|---------|--------|-------------|
| notmuch-mua-reply | :orange_circle: | Reply to Notmuch message |
| notmuch-mua-forward-message | :orange_circle: | Forward Notmuch message |
| notmuch-tag | :orange_circle: | Apply tag changes |
| notmuch-refresh-this-buffer | :orange_circle: | Refresh Notmuch buffer |
| notmuch-show-archive-message-then-next | :orange_circle: | Archive and next message |
| wl | :orange_circle: | Start Wanderlust |
| wl-summary-next | :orange_circle: | Next Wanderlust message |
| wl-summary-prev | :orange_circle: | Previous Wanderlust message |
| wl-summary-reply | :orange_circle: | Reply in Wanderlust |
| wl-summary-forward | :orange_circle: | Forward in Wanderlust |
| wl-draft-send-and-exit | :orange_circle: | Send draft and exit |
| bbdb-create | :orange_circle: | Create BBDB record |
| bbdb-complete-mail | :orange_circle: | Complete mail address via BBDB |
| ledger-reconcile | :orange_circle: | Reconcile Ledger account |
| ledger-add-transaction | :orange_circle: | Add Ledger transaction |
| ledger-toggle-current | :orange_circle: | Toggle current transaction |
| ledger-copy-transaction-at-point | :orange_circle: | Copy transaction |
| ledger-delete-current-transaction | :orange_circle: | Delete current transaction |
| ledger-mode-clean-buffer | :orange_circle: | Clean Ledger buffer |
| ledger-check-buffer | :orange_circle: | Check Ledger buffer for errors |

---

### Round 137 — Rust, Go, Haskell, Elixir Modes

| Command | Status | Description |
|---------|--------|-------------|
| rust-run | :orange_circle: | Run Rust project |
| rust-compile | :orange_circle: | Compile Rust project |
| rust-test | :orange_circle: | Run Rust tests |
| rust-check | :orange_circle: | Check Rust project |
| rust-clippy | :orange_circle: | Run Rust clippy |
| rust-format-buffer | :orange_circle: | Format buffer with rustfmt |
| cargo-process-bench | :orange_circle: | Run Cargo benchmarks |
| go-remove-unused-imports | :orange_circle: | Remove unused Go imports |
| go-goto-imports | :orange_circle: | Jump to Go imports |
| haskell-process-reload | :orange_circle: | Reload in GHCi |
| haskell-interactive-switch | :orange_circle: | Switch to Haskell interactive |
| haskell-navigate-imports | :orange_circle: | Navigate to Haskell imports |
| haskell-sort-imports | :orange_circle: | Sort Haskell imports |
| haskell-align-imports | :orange_circle: | Align Haskell imports |
| elixir-format | :orange_circle: | Format Elixir buffer |
| elixir-mode-open-docs-at-point | :orange_circle: | Open Elixir docs at point |
| mix-test | :orange_circle: | Run Mix tests |
| mix-run | :orange_circle: | Run Mix project |
| mix-deps-get | :orange_circle: | Get Mix dependencies |
| alchemist-eval-current-line | :orange_circle: | Evaluate current Elixir line |

---

### Round 138 — Scala, Kotlin, OCaml, Erlang, Zig Modes

| Command | Status | Description |
|---------|--------|-------------|
| scala-run | :orange_circle: | Run Scala project |
| scala-compile | :orange_circle: | Compile Scala project |
| sbt-command | :orange_circle: | Run SBT command |
| sbt-run-previous-command | :orange_circle: | Re-run previous SBT command |
| sbt-switch-to-active-sbt-buffer | :orange_circle: | Switch to SBT buffer |
| ensime-connect | :orange_circle: | Connect to ENSIME server |
| ensime-inspect-type-at-point | :orange_circle: | Inspect type at point |
| kotlin-send-buffer | :orange_circle: | Send Kotlin buffer to REPL |
| kotlin-repl | :orange_circle: | Start Kotlin REPL |
| tuareg-eval-region | :orange_circle: | Evaluate OCaml region |
| tuareg-eval-buffer | :orange_circle: | Evaluate OCaml buffer |
| tuareg-eval-phrase | :orange_circle: | Evaluate OCaml phrase |
| merlin-type-enclosing | :orange_circle: | Show type of enclosing expression |
| merlin-destruct | :orange_circle: | Destruct OCaml pattern |
| merlin-error-next | :orange_circle: | Jump to next Merlin error |
| erlang-compile | :orange_circle: | Compile Erlang module |
| erlang-shell-display | :orange_circle: | Display Erlang shell |
| erlang-next-error | :orange_circle: | Jump to next Erlang error |
| erlang-man-function | :orange_circle: | Show Erlang man page |
| zig-compile | :orange_circle: | Compile Zig project |

---

### Round 139 — Zig, Nim, Julia, R/ESS, Ruby Modes

| Command | Status | Description |
|---------|--------|-------------|
| zig-test-buffer | :orange_circle: | Test Zig buffer |
| zig-run | :orange_circle: | Run Zig project |
| zig-format-buffer | :orange_circle: | Format Zig buffer |
| nim-compile | :orange_circle: | Compile Nim project |
| nim-run | :orange_circle: | Run Nim project |
| nim-suggest-at-point | :orange_circle: | Nim suggestion at point |
| julia-repl | :orange_circle: | Start Julia REPL |
| julia-repl-send-region-or-line | :orange_circle: | Send region/line to Julia REPL |
| ess-eval-region | :orange_circle: | Evaluate R region |
| ess-eval-buffer | :orange_circle: | Evaluate R buffer |
| ess-eval-function | :orange_circle: | Evaluate R function |
| ess-help | :orange_circle: | Show R help |
| ess-describe-object-at-point | :orange_circle: | Describe R object at point |
| ess-rdired | :orange_circle: | Open R object browser |
| ess-load-file | :orange_circle: | Load file into R |
| ruby-send-region | :orange_circle: | Send Ruby region to IRB |
| ruby-send-buffer | :orange_circle: | Send Ruby buffer to IRB |
| ruby-switch-to-inf | :orange_circle: | Switch to Ruby inferior process |
| robe-start | :orange_circle: | Start Robe server |
| robe-jump | :orange_circle: | Jump to Ruby definition |

---

### Round 140 — Ruby/Rspec, Swift, Dart/Flutter, Lua, PHP

| Command | Status | Description |
|---------|--------|-------------|
| robe-doc | :orange_circle: | Show Ruby documentation |
| rspec-verify | :orange_circle: | Verify current RSpec file |
| rspec-verify-all | :orange_circle: | Verify all RSpec specs |
| rspec-verify-single | :orange_circle: | Verify single RSpec spec |
| swift-mode-run | :orange_circle: | Run Swift project |
| swift-mode-send-region | :orange_circle: | Send Swift region to REPL |
| swift-mode-repl | :orange_circle: | Start Swift REPL |
| dart-format | :orange_circle: | Format Dart buffer |
| flutter-run | :orange_circle: | Run Flutter app |
| flutter-hot-reload | :orange_circle: | Flutter hot reload |
| flutter-hot-restart | :orange_circle: | Flutter hot restart |
| flutter-test | :orange_circle: | Run Flutter tests |
| flutter-pub-get | :orange_circle: | Flutter pub get |
| lua-send-buffer | :orange_circle: | Send Lua buffer |
| lua-send-region | :orange_circle: | Send Lua region |
| lua-send-current-line | :orange_circle: | Send current Lua line |
| lua-start-process | :orange_circle: | Start Lua process |
| php-mode-test | :orange_circle: | Run PHP test |
| php-format-buffer | :orange_circle: | Format PHP buffer |
| phpunit-current-test | :orange_circle: | Run current PHPUnit test |

---

### Round 141 — GraphQL, Terraform, Kubernetes, Nix, Restclient

| Command | Status | Description |
|---------|--------|-------------|
| graphql-send-query | :orange_circle: | Send GraphQL query |
| graphql-select-endpoint | :orange_circle: | Select GraphQL endpoint |
| terraform-workspace-show | :orange_circle: | Show Terraform workspace |
| terraform-workspace-select | :orange_circle: | Select Terraform workspace |
| kubernetes-describe-pod | :orange_circle: | Describe Kubernetes pod |
| kubernetes-logs | :orange_circle: | Show pod logs |
| kubernetes-exec-into | :orange_circle: | Exec into pod |
| kubernetes-delete-pod | :orange_circle: | Delete pod |
| kubernetes-scale | :orange_circle: | Scale deployment |
| nix-format-buffer | :orange_circle: | Format Nix buffer |
| nix-flake-update | :orange_circle: | Update Nix flake inputs |
| nixos-rebuild | :orange_circle: | Rebuild NixOS system |
| nixpkgs-search | :orange_circle: | Search Nix packages |
| restclient-http-send-current | :orange_circle: | Send current HTTP request |
| restclient-http-send-current-raw | :orange_circle: | Send current request (raw) |
| restclient-copy-curl-command | :orange_circle: | Copy as curl command |
| restclient-narrow-to-current | :orange_circle: | Narrow to current request |
| restclient-mark-current | :orange_circle: | Mark current request |
| ob-restclient | :orange_circle: | Execute restclient org block |
| verb-show-request | :orange_circle: | Show Verb HTTP request |

---

### Round 142 — Denote, Citar, Org-ref, BibTeX, Ebib

| Command | Status | Description |
|---------|--------|-------------|
| denote-link-backlinks | :orange_circle: | Show Denote backlinks |
| denote-dired | :orange_circle: | Open Denote notes in dired |
| denote-sort-dired | :orange_circle: | Sort Denote dired by date |
| denote-journal-extras-new-entry | :orange_circle: | New Denote journal entry |
| denote-menu-list-notes | :orange_circle: | List all Denote notes |
| citar-copy-reference | :orange_circle: | Copy citation reference |
| org-ref-insert-link | :orange_circle: | Insert org-ref citation |
| org-ref-cite-hydra | :orange_circle: | Open org-ref citation hydra |
| zotero-browser | :orange_circle: | Open Zotero browser |
| bibtex-sort-buffer | :orange_circle: | Sort BibTeX buffer |
| bibtex-validate | :orange_circle: | Validate BibTeX buffer |
| bibtex-count-entries | :orange_circle: | Count BibTeX entries |
| bibtex-find-entry | :orange_circle: | Find BibTeX entry |
| bibtex-search-entry | :orange_circle: | Search BibTeX entries |
| bibtex-entry-update-timestamp | :orange_circle: | Update BibTeX timestamp |
| parsebib-parse-bib-buffer | :orange_circle: | Parse bib buffer |
| ebib | :orange_circle: | Start Ebib bibliography manager |
| ebib-open | :orange_circle: | Open bib file in Ebib |
| ebib-import-file | :orange_circle: | Import file into Ebib |
| ebib-push-citation | :orange_circle: | Push Ebib citation to buffer |

### Round 388 — Figma ext, Sketch ext, Zeplin ext, Storybook/Chromatic ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Figma files | — | `figma-files` | :orange_circle: Scaffolded |
| Figma components | — | `figma-components` | :orange_circle: Scaffolded |
| Figma styles | — | `figma-styles` | :orange_circle: Scaffolded |
| Figma variables | — | `figma-variables` | :orange_circle: Scaffolded |
| Sketch documents | — | `sketch-documents` | :orange_circle: Scaffolded |
| Sketch symbols | — | `sketch-symbols` | :orange_circle: Scaffolded |
| Sketch libraries | — | `sketch-libraries` | :orange_circle: Scaffolded |
| Sketch prototypes | — | `sketch-prototypes` | :orange_circle: Scaffolded |
| Zeplin projects | — | `zeplin-projects` | :orange_circle: Scaffolded |
| Zeplin screens | — | `zeplin-screens` | :orange_circle: Scaffolded |
| Zeplin styleguide | — | `zeplin-styleguide` | :orange_circle: Scaffolded |
| Zeplin components | — | `zeplin-components` | :orange_circle: Scaffolded |
| Storybook stories | — | `storybook-stories` | :orange_circle: Scaffolded |
| Storybook docs | — | `storybook-docs` | :orange_circle: Scaffolded |
| Storybook addons | — | `storybook-addons` | :orange_circle: Scaffolded |
| Storybook tests | — | `storybook-tests` | :orange_circle: Scaffolded |
| Chromatic builds | — | `chromatic-builds` | :orange_circle: Scaffolded |
| Chromatic snapshots | — | `chromatic-snapshots` | :orange_circle: Scaffolded |
| Chromatic reviews | — | `chromatic-reviews` | :orange_circle: Scaffolded |
| Chromatic baselines | — | `chromatic-baselines` | :orange_circle: Scaffolded |

### Round 387 — Snyk ext, SonarQube ext, Checkmarx ext, Veracode/Semgrep ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Snyk container scan | — | `snyk-container` | :orange_circle: Scaffolded |
| Snyk IaC scan | — | `snyk-iac` | :orange_circle: Scaffolded |
| Snyk SBOM generation | — | `snyk-sbom` | :orange_circle: Scaffolded |
| Snyk Log4Shell scan | — | `snyk-log4shell` | :orange_circle: Scaffolded |
| SonarQube analysis | — | `sonarqube-analyze` | :orange_circle: Scaffolded |
| SonarQube projects | — | `sonarqube-projects` | :orange_circle: Scaffolded |
| SonarQube rules | — | `sonarqube-rules` | :orange_circle: Scaffolded |
| SonarQube quality gates | — | `sonarqube-gates` | :orange_circle: Scaffolded |
| Checkmarx scan | — | `checkmarx-scan` | :orange_circle: Scaffolded |
| Checkmarx projects | — | `checkmarx-projects` | :orange_circle: Scaffolded |
| Checkmarx results | — | `checkmarx-results` | :orange_circle: Scaffolded |
| Checkmarx policies | — | `checkmarx-policies` | :orange_circle: Scaffolded |
| Veracode scan | — | `veracode-scan` | :orange_circle: Scaffolded |
| Veracode applications | — | `veracode-apps` | :orange_circle: Scaffolded |
| Veracode findings | — | `veracode-findings` | :orange_circle: Scaffolded |
| Veracode policies | — | `veracode-policies` | :orange_circle: Scaffolded |
| Semgrep scan | — | `semgrep-scan` | :orange_circle: Scaffolded |
| Semgrep rules | — | `semgrep-rules` | :orange_circle: Scaffolded |
| Semgrep deploy rules | — | `semgrep-deploy` | :orange_circle: Scaffolded |
| Semgrep findings | — | `semgrep-findings` | :orange_circle: Scaffolded |

### Round 386 — Backstage ext, Port ext, Cortex ext, OpsLevel/Compass ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Backstage catalog | — | `backstage-catalog` | :orange_circle: Scaffolded |
| Backstage templates | — | `backstage-templates` | :orange_circle: Scaffolded |
| Backstage APIs | — | `backstage-apis` | :orange_circle: Scaffolded |
| Backstage TechDocs | — | `backstage-techdocs` | :orange_circle: Scaffolded |
| Port entities | — | `port-entities` | :orange_circle: Scaffolded |
| Port blueprints | — | `port-blueprints` | :orange_circle: Scaffolded |
| Port self-service actions | — | `port-actions` | :orange_circle: Scaffolded |
| Port scorecards | — | `port-scorecards` | :orange_circle: Scaffolded |
| Cortex services | — | `cortex-services` | :orange_circle: Scaffolded |
| Cortex scorecards | — | `cortex-scorecards` | :orange_circle: Scaffolded |
| Cortex catalogs | — | `cortex-catalogs` | :orange_circle: Scaffolded |
| Cortex initiatives | — | `cortex-initiatives` | :orange_circle: Scaffolded |
| OpsLevel services | — | `opslevel-services` | :orange_circle: Scaffolded |
| OpsLevel checks | — | `opslevel-checks` | :orange_circle: Scaffolded |
| OpsLevel rubrics | — | `opslevel-rubrics` | :orange_circle: Scaffolded |
| OpsLevel maturity | — | `opslevel-maturity` | :orange_circle: Scaffolded |
| Compass components | — | `compass-components` | :orange_circle: Scaffolded |
| Compass scorecards | — | `compass-scorecards` | :orange_circle: Scaffolded |
| Compass metrics | — | `compass-metrics` | :orange_circle: Scaffolded |
| Compass teams | — | `compass-teams` | :orange_circle: Scaffolded |

### Round 385 — Temporal ext, Cadence ext, Inngest ext, Trigger.dev/Windmill ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Temporal workflows | — | `temporal-workflows` | :orange_circle: Scaffolded |
| Temporal activities | — | `temporal-activities` | :orange_circle: Scaffolded |
| Temporal schedules | — | `temporal-schedules` | :orange_circle: Scaffolded |
| Temporal namespaces | — | `temporal-namespaces` | :orange_circle: Scaffolded |
| Cadence workflows | — | `cadence-workflows` | :orange_circle: Scaffolded |
| Cadence domains | — | `cadence-domains` | :orange_circle: Scaffolded |
| Cadence task lists | — | `cadence-tasks` | :orange_circle: Scaffolded |
| Cadence history | — | `cadence-history` | :orange_circle: Scaffolded |
| Inngest functions | — | `inngest-functions` | :orange_circle: Scaffolded |
| Inngest events | — | `inngest-events` | :orange_circle: Scaffolded |
| Inngest runs | — | `inngest-runs` | :orange_circle: Scaffolded |
| Inngest event keys | — | `inngest-keys` | :orange_circle: Scaffolded |
| Trigger.dev workflows | — | `trigger-workflows` | :orange_circle: Scaffolded |
| Trigger.dev jobs | — | `trigger-jobs` | :orange_circle: Scaffolded |
| Trigger.dev schedules | — | `trigger-schedules` | :orange_circle: Scaffolded |
| Trigger.dev events | — | `trigger-events` | :orange_circle: Scaffolded |
| Windmill scripts | — | `windmill-scripts` | :orange_circle: Scaffolded |
| Windmill flows | — | `windmill-flows` | :orange_circle: Scaffolded |
| Windmill schedules | — | `windmill-schedules` | :orange_circle: Scaffolded |
| Windmill resources | — | `windmill-resources` | :orange_circle: Scaffolded |

### Round 384 — Ollama ext, vLLM ext, TGI ext, LiteLLM/Replicate ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Ollama run model | — | `ollama-run` | :orange_circle: Scaffolded |
| Ollama list models | — | `ollama-list` | :orange_circle: Scaffolded |
| Ollama pull model | — | `ollama-pull` | :orange_circle: Scaffolded |
| Ollama create model | — | `ollama-create` | :orange_circle: Scaffolded |
| vLLM serve | — | `vllm-serve` | :orange_circle: Scaffolded |
| vLLM models | — | `vllm-models` | :orange_circle: Scaffolded |
| vLLM generate | — | `vllm-generate` | :orange_circle: Scaffolded |
| vLLM benchmark | — | `vllm-benchmark` | :orange_circle: Scaffolded |
| TGI serve | — | `tgi-serve` | :orange_circle: Scaffolded |
| TGI health | — | `tgi-health` | :orange_circle: Scaffolded |
| TGI generate | — | `tgi-generate` | :orange_circle: Scaffolded |
| TGI metrics | — | `tgi-metrics` | :orange_circle: Scaffolded |
| LiteLLM models | — | `litellm-models` | :orange_circle: Scaffolded |
| LiteLLM proxy | — | `litellm-proxy` | :orange_circle: Scaffolded |
| LiteLLM budget | — | `litellm-budget` | :orange_circle: Scaffolded |
| LiteLLM API keys | — | `litellm-keys` | :orange_circle: Scaffolded |
| Replicate run | — | `replicate-run` | :orange_circle: Scaffolded |
| Replicate models | — | `replicate-models` | :orange_circle: Scaffolded |
| Replicate predictions | — | `replicate-predictions` | :orange_circle: Scaffolded |
| Replicate collections | — | `replicate-collections` | :orange_circle: Scaffolded |

### Round 383 — LangChain ext, LlamaIndex ext, OpenAI ext, Anthropic/HuggingFace ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| LangChain chains | — | `langchain-chains` | :orange_circle: Scaffolded |
| LangChain agents | — | `langchain-agents` | :orange_circle: Scaffolded |
| LangChain memory | — | `langchain-memory` | :orange_circle: Scaffolded |
| LangChain tools | — | `langchain-tools` | :orange_circle: Scaffolded |
| LlamaIndex indexes | — | `llamaindex-index` | :orange_circle: Scaffolded |
| LlamaIndex query | — | `llamaindex-query` | :orange_circle: Scaffolded |
| LlamaIndex ingest | — | `llamaindex-ingest` | :orange_circle: Scaffolded |
| LlamaIndex retriever | — | `llamaindex-retriever` | :orange_circle: Scaffolded |
| OpenAI chat | — | `openai-chat` | :orange_circle: Scaffolded |
| OpenAI embeddings | — | `openai-embeddings` | :orange_circle: Scaffolded |
| OpenAI fine-tune | — | `openai-finetune` | :orange_circle: Scaffolded |
| OpenAI models | — | `openai-models` | :orange_circle: Scaffolded |
| Anthropic messages | — | `anthropic-messages` | :orange_circle: Scaffolded |
| Anthropic completions | — | `anthropic-completions` | :orange_circle: Scaffolded |
| Anthropic models | — | `anthropic-models` | :orange_circle: Scaffolded |
| Anthropic usage | — | `anthropic-usage` | :orange_circle: Scaffolded |
| HuggingFace models | — | `huggingface-models` | :orange_circle: Scaffolded |
| HuggingFace datasets | — | `huggingface-datasets` | :orange_circle: Scaffolded |
| HuggingFace Spaces | — | `huggingface-spaces` | :orange_circle: Scaffolded |
| HuggingFace inference | — | `huggingface-inference` | :orange_circle: Scaffolded |

### Round 382 — Pinecone ext, Weaviate ext, Qdrant ext, Milvus/Chroma ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Pinecone indexes | — | `pinecone-index` | :orange_circle: Scaffolded |
| Pinecone query | — | `pinecone-query` | :orange_circle: Scaffolded |
| Pinecone upsert | — | `pinecone-upsert` | :orange_circle: Scaffolded |
| Pinecone collections | — | `pinecone-collections` | :orange_circle: Scaffolded |
| Weaviate schema | — | `weaviate-schema` | :orange_circle: Scaffolded |
| Weaviate query | — | `weaviate-query` | :orange_circle: Scaffolded |
| Weaviate objects | — | `weaviate-objects` | :orange_circle: Scaffolded |
| Weaviate tenants | — | `weaviate-tenants` | :orange_circle: Scaffolded |
| Qdrant collections | — | `qdrant-collections` | :orange_circle: Scaffolded |
| Qdrant points | — | `qdrant-points` | :orange_circle: Scaffolded |
| Qdrant search | — | `qdrant-search` | :orange_circle: Scaffolded |
| Qdrant snapshots | — | `qdrant-snapshots` | :orange_circle: Scaffolded |
| Milvus collections | — | `milvus-collections` | :orange_circle: Scaffolded |
| Milvus search | — | `milvus-search` | :orange_circle: Scaffolded |
| Milvus insert | — | `milvus-insert` | :orange_circle: Scaffolded |
| Milvus partitions | — | `milvus-partitions` | :orange_circle: Scaffolded |
| Chroma collections | — | `chroma-collections` | :orange_circle: Scaffolded |
| Chroma query | — | `chroma-query` | :orange_circle: Scaffolded |
| Chroma add docs | — | `chroma-add` | :orange_circle: Scaffolded |
| Chroma delete docs | — | `chroma-delete` | :orange_circle: Scaffolded |

### Round 381 — Upstash ext, Turso ext, Fauna ext, DynamoDB/CosmosDB ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Upstash Redis | — | `upstash-redis` | :orange_circle: Scaffolded |
| Upstash Kafka | — | `upstash-kafka` | :orange_circle: Scaffolded |
| Upstash QStash | — | `upstash-qstash` | :orange_circle: Scaffolded |
| Upstash Vector | — | `upstash-vector` | :orange_circle: Scaffolded |
| Turso databases | — | `turso-databases` | :orange_circle: Scaffolded |
| Turso groups | — | `turso-groups` | :orange_circle: Scaffolded |
| Turso tokens | — | `turso-tokens` | :orange_circle: Scaffolded |
| Turso replicas | — | `turso-replicas` | :orange_circle: Scaffolded |
| Fauna databases | — | `fauna-databases` | :orange_circle: Scaffolded |
| Fauna collections | — | `fauna-collections` | :orange_circle: Scaffolded |
| Fauna indexes | — | `fauna-indexes` | :orange_circle: Scaffolded |
| Fauna functions | — | `fauna-functions` | :orange_circle: Scaffolded |
| DynamoDB tables | — | `dynamo-tables` | :orange_circle: Scaffolded |
| DynamoDB query | — | `dynamo-query` | :orange_circle: Scaffolded |
| DynamoDB scan | — | `dynamo-scan` | :orange_circle: Scaffolded |
| DynamoDB streams | — | `dynamo-streams` | :orange_circle: Scaffolded |
| CosmosDB databases | — | `cosmos-databases` | :orange_circle: Scaffolded |
| CosmosDB containers | — | `cosmos-containers` | :orange_circle: Scaffolded |
| CosmosDB SQL query | — | `cosmos-queries` | :orange_circle: Scaffolded |
| CosmosDB throughput | — | `cosmos-throughput` | :orange_circle: Scaffolded |

### Round 380 — Supabase ext, PlanetScale ext, Neon ext, CockroachDB/TiDB ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Supabase auth users | — | `supabase-auth` | :orange_circle: Scaffolded |
| Supabase storage | — | `supabase-storage` | :orange_circle: Scaffolded |
| Supabase edge functions | — | `supabase-functions` | :orange_circle: Scaffolded |
| Supabase migrations | — | `supabase-migrations` | :orange_circle: Scaffolded |
| PlanetScale branches | — | `planetscale-branches` | :orange_circle: Scaffolded |
| PlanetScale deploy | — | `planetscale-deploy` | :orange_circle: Scaffolded |
| PlanetScale schema | — | `planetscale-schema` | :orange_circle: Scaffolded |
| PlanetScale insights | — | `planetscale-insights` | :orange_circle: Scaffolded |
| Neon branches | — | `neon-branches` | :orange_circle: Scaffolded |
| Neon databases | — | `neon-databases` | :orange_circle: Scaffolded |
| Neon compute endpoints | — | `neon-endpoints` | :orange_circle: Scaffolded |
| Neon operations | — | `neon-operations` | :orange_circle: Scaffolded |
| CockroachDB zones | — | `cockroachdb-zones` | :orange_circle: Scaffolded |
| CockroachDB jobs | — | `cockroachdb-jobs` | :orange_circle: Scaffolded |
| CockroachDB statements | — | `cockroachdb-statements` | :orange_circle: Scaffolded |
| CockroachDB changefeeds | — | `cockroachdb-changefeeds` | :orange_circle: Scaffolded |
| TiDB clusters | — | `tidb-clusters` | :orange_circle: Scaffolded |
| TiDB backups | — | `tidb-backups` | :orange_circle: Scaffolded |
| TiDB imports | — | `tidb-imports` | :orange_circle: Scaffolded |
| TiDB monitoring | — | `tidb-monitoring` | :orange_circle: Scaffolded |

### Round 379 — Firebase ext, Vercel ext, Netlify ext, Cloudflare/Fly.io ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Firebase auth users | — | `firebase-auth` | :orange_circle: Scaffolded |
| Firebase Firestore | — | `firebase-firestore` | :orange_circle: Scaffolded |
| Firebase functions | — | `firebase-functions` | :orange_circle: Scaffolded |
| Firebase hosting | — | `firebase-hosting` | :orange_circle: Scaffolded |
| Vercel domains | — | `vercel-domains` | :orange_circle: Scaffolded |
| Vercel env vars | — | `vercel-env` | :orange_circle: Scaffolded |
| Vercel deploy logs | — | `vercel-logs` | :orange_circle: Scaffolded |
| Vercel projects | — | `vercel-projects` | :orange_circle: Scaffolded |
| Netlify sites | — | `netlify-sites` | :orange_circle: Scaffolded |
| Netlify functions | — | `netlify-functions` | :orange_circle: Scaffolded |
| Netlify forms | — | `netlify-forms` | :orange_circle: Scaffolded |
| Netlify plugins | — | `netlify-plugins` | :orange_circle: Scaffolded |
| Cloudflare Workers | — | `cloudflare-workers` | :orange_circle: Scaffolded |
| Cloudflare Pages | — | `cloudflare-pages` | :orange_circle: Scaffolded |
| Cloudflare DNS | — | `cloudflare-dns` | :orange_circle: Scaffolded |
| Cloudflare WAF | — | `cloudflare-waf` | :orange_circle: Scaffolded |
| Fly.io deploy | — | `flyio-deploy` | :orange_circle: Scaffolded |
| Fly.io machines | — | `flyio-machines` | :orange_circle: Scaffolded |
| Fly.io volumes | — | `flyio-volumes` | :orange_circle: Scaffolded |
| Fly.io secrets | — | `flyio-secrets` | :orange_circle: Scaffolded |

### Round 378 — Twilio ext, SendGrid ext, Mailgun ext, SES/Postmark ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Twilio send SMS | — | `twilio-sms` | :orange_circle: Scaffolded |
| Twilio list calls | — | `twilio-calls` | :orange_circle: Scaffolded |
| Twilio phone numbers | — | `twilio-numbers` | :orange_circle: Scaffolded |
| Twilio verification | — | `twilio-verify` | :orange_circle: Scaffolded |
| SendGrid send email | — | `sendgrid-send` | :orange_circle: Scaffolded |
| SendGrid templates | — | `sendgrid-templates` | :orange_circle: Scaffolded |
| SendGrid contacts | — | `sendgrid-contacts` | :orange_circle: Scaffolded |
| SendGrid stats | — | `sendgrid-stats` | :orange_circle: Scaffolded |
| Mailgun send email | — | `mailgun-send` | :orange_circle: Scaffolded |
| Mailgun domains | — | `mailgun-domains` | :orange_circle: Scaffolded |
| Mailgun routes | — | `mailgun-routes` | :orange_circle: Scaffolded |
| Mailgun logs | — | `mailgun-logs` | :orange_circle: Scaffolded |
| SES send email | — | `ses-send` | :orange_circle: Scaffolded |
| SES templates | — | `ses-templates` | :orange_circle: Scaffolded |
| SES identities | — | `ses-identities` | :orange_circle: Scaffolded |
| SES sending stats | — | `ses-stats` | :orange_circle: Scaffolded |
| Postmark send email | — | `postmark-send` | :orange_circle: Scaffolded |
| Postmark templates | — | `postmark-templates` | :orange_circle: Scaffolded |
| Postmark servers | — | `postmark-servers` | :orange_circle: Scaffolded |
| Postmark delivery stats | — | `postmark-stats` | :orange_circle: Scaffolded |

### Round 377 — Stripe ext, PayPal ext, Braintree ext, Square/Adyen ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Stripe charges | — | `stripe-charges` | :orange_circle: Scaffolded |
| Stripe customers | — | `stripe-customers` | :orange_circle: Scaffolded |
| Stripe invoices | — | `stripe-invoices` | :orange_circle: Scaffolded |
| Stripe subscriptions | — | `stripe-subscriptions` | :orange_circle: Scaffolded |
| PayPal transactions | — | `paypal-transactions` | :orange_circle: Scaffolded |
| PayPal invoices | — | `paypal-invoices` | :orange_circle: Scaffolded |
| PayPal disputes | — | `paypal-disputes` | :orange_circle: Scaffolded |
| PayPal payouts | — | `paypal-payouts` | :orange_circle: Scaffolded |
| Braintree transactions | — | `braintree-transactions` | :orange_circle: Scaffolded |
| Braintree customers | — | `braintree-customers` | :orange_circle: Scaffolded |
| Braintree plans | — | `braintree-plans` | :orange_circle: Scaffolded |
| Braintree disputes | — | `braintree-disputes` | :orange_circle: Scaffolded |
| Square payments | — | `square-payments` | :orange_circle: Scaffolded |
| Square customers | — | `square-customers` | :orange_circle: Scaffolded |
| Square invoices | — | `square-invoices` | :orange_circle: Scaffolded |
| Square catalog | — | `square-catalog` | :orange_circle: Scaffolded |
| Adyen payments | — | `adyen-payments` | :orange_circle: Scaffolded |
| Adyen refunds | — | `adyen-refunds` | :orange_circle: Scaffolded |
| Adyen payouts | — | `adyen-payouts` | :orange_circle: Scaffolded |
| Adyen reports | — | `adyen-reports` | :orange_circle: Scaffolded |

### Round 376 — dbt ext, Fivetran ext, Airbyte ext, Stitch/Singer ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| dbt run models | — | `dbt-run` | :orange_circle: Scaffolded |
| dbt run tests | — | `dbt-test` | :orange_circle: Scaffolded |
| dbt compile | — | `dbt-compile` | :orange_circle: Scaffolded |
| dbt generate docs | — | `dbt-docs` | :orange_circle: Scaffolded |
| Fivetran connectors | — | `fivetran-connectors` | :orange_circle: Scaffolded |
| Fivetran trigger sync | — | `fivetran-sync` | :orange_circle: Scaffolded |
| Fivetran sync status | — | `fivetran-status` | :orange_circle: Scaffolded |
| Fivetran sync logs | — | `fivetran-logs` | :orange_circle: Scaffolded |
| Airbyte connections | — | `airbyte-connections` | :orange_circle: Scaffolded |
| Airbyte trigger sync | — | `airbyte-sync` | :orange_circle: Scaffolded |
| Airbyte sources | — | `airbyte-sources` | :orange_circle: Scaffolded |
| Airbyte destinations | — | `airbyte-destinations` | :orange_circle: Scaffolded |
| Stitch integrations | — | `stitch-integrations` | :orange_circle: Scaffolded |
| Stitch recent loads | — | `stitch-loads` | :orange_circle: Scaffolded |
| Stitch sources | — | `stitch-sources` | :orange_circle: Scaffolded |
| Stitch schemas | — | `stitch-schemas` | :orange_circle: Scaffolded |
| Singer taps | — | `singer-taps` | :orange_circle: Scaffolded |
| Singer targets | — | `singer-targets` | :orange_circle: Scaffolded |
| Singer catalog | — | `singer-catalog` | :orange_circle: Scaffolded |
| Singer state | — | `singer-state` | :orange_circle: Scaffolded |

### Round 375 — MLflow ext, W&B ext, Kubeflow ext, SageMaker/Ray ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| MLflow experiments | — | `mlflow-experiments` | :orange_circle: Scaffolded |
| MLflow runs | — | `mlflow-runs` | :orange_circle: Scaffolded |
| MLflow models | — | `mlflow-models` | :orange_circle: Scaffolded |
| MLflow model registry | — | `mlflow-registry` | :orange_circle: Scaffolded |
| W&B runs | — | `wandb-runs` | :orange_circle: Scaffolded |
| W&B sweeps | — | `wandb-sweeps` | :orange_circle: Scaffolded |
| W&B artifacts | — | `wandb-artifacts` | :orange_circle: Scaffolded |
| W&B reports | — | `wandb-reports` | :orange_circle: Scaffolded |
| Kubeflow pipelines | — | `kubeflow-pipelines` | :orange_circle: Scaffolded |
| Kubeflow experiments | — | `kubeflow-experiments` | :orange_circle: Scaffolded |
| Kubeflow notebooks | — | `kubeflow-notebooks` | :orange_circle: Scaffolded |
| Kubeflow models | — | `kubeflow-models` | :orange_circle: Scaffolded |
| SageMaker endpoints | — | `sagemaker-endpoints` | :orange_circle: Scaffolded |
| SageMaker training | — | `sagemaker-training` | :orange_circle: Scaffolded |
| SageMaker models | — | `sagemaker-models` | :orange_circle: Scaffolded |
| SageMaker pipelines | — | `sagemaker-pipelines` | :orange_circle: Scaffolded |
| Ray jobs | — | `ray-jobs` | :orange_circle: Scaffolded |
| Ray clusters | — | `ray-clusters` | :orange_circle: Scaffolded |
| Ray Serve deployments | — | `ray-serve` | :orange_circle: Scaffolded |
| Ray Tune trials | — | `ray-tune` | :orange_circle: Scaffolded |

### Round 374 — Airflow ext, Spark ext, Flink ext, Dagster/Prefect ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Airflow list DAGs | — | `airflow-dags` | :orange_circle: Scaffolded |
| Airflow list tasks | — | `airflow-tasks` | :orange_circle: Scaffolded |
| Airflow DAG runs | — | `airflow-runs` | :orange_circle: Scaffolded |
| Airflow connections | — | `airflow-connections` | :orange_circle: Scaffolded |
| Spark submit | — | `spark-submit` | :orange_circle: Scaffolded |
| Spark app status | — | `spark-status` | :orange_circle: Scaffolded |
| Spark driver logs | — | `spark-logs` | :orange_circle: Scaffolded |
| Spark configuration | — | `spark-config` | :orange_circle: Scaffolded |
| Flink list jobs | — | `flink-jobs` | :orange_circle: Scaffolded |
| Flink savepoints | — | `flink-savepoints` | :orange_circle: Scaffolded |
| Flink checkpoints | — | `flink-checkpoints` | :orange_circle: Scaffolded |
| Flink metrics | — | `flink-metrics` | :orange_circle: Scaffolded |
| Dagster runs | — | `dagster-runs` | :orange_circle: Scaffolded |
| Dagster assets | — | `dagster-assets` | :orange_circle: Scaffolded |
| Dagster schedules | — | `dagster-schedules` | :orange_circle: Scaffolded |
| Dagster sensors | — | `dagster-sensors` | :orange_circle: Scaffolded |
| Prefect flows | — | `prefect-flows` | :orange_circle: Scaffolded |
| Prefect deployments | — | `prefect-deployments` | :orange_circle: Scaffolded |
| Prefect flow runs | — | `prefect-runs` | :orange_circle: Scaffolded |
| Prefect agents | — | `prefect-agents` | :orange_circle: Scaffolded |

### Round 373 — ClickHouse ext, BigQuery ext, Snowflake ext, Redshift/DuckDB ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| ClickHouse merges | — | `clickhouse-merges` | :orange_circle: Scaffolded |
| ClickHouse replicas | — | `clickhouse-replicas` | :orange_circle: Scaffolded |
| ClickHouse mutations | — | `clickhouse-mutations` | :orange_circle: Scaffolded |
| ClickHouse dictionaries | — | `clickhouse-dictionaries` | :orange_circle: Scaffolded |
| BigQuery SQL query | — | `bigquery-query` | :orange_circle: Scaffolded |
| BigQuery list tables | — | `bigquery-tables` | :orange_circle: Scaffolded |
| BigQuery list datasets | — | `bigquery-datasets` | :orange_circle: Scaffolded |
| BigQuery list jobs | — | `bigquery-jobs` | :orange_circle: Scaffolded |
| Snowflake SQL query | — | `snowflake-query` | :orange_circle: Scaffolded |
| Snowflake warehouses | — | `snowflake-warehouses` | :orange_circle: Scaffolded |
| Snowflake databases | — | `snowflake-databases` | :orange_circle: Scaffolded |
| Snowflake stages | — | `snowflake-stages` | :orange_circle: Scaffolded |
| Redshift SQL query | — | `redshift-query` | :orange_circle: Scaffolded |
| Redshift list tables | — | `redshift-tables` | :orange_circle: Scaffolded |
| Redshift clusters | — | `redshift-clusters` | :orange_circle: Scaffolded |
| Redshift schemas | — | `redshift-schemas` | :orange_circle: Scaffolded |
| DuckDB SQL query | — | `duckdb-query` | :orange_circle: Scaffolded |
| DuckDB list tables | — | `duckdb-tables` | :orange_circle: Scaffolded |
| DuckDB export data | — | `duckdb-export` | :orange_circle: Scaffolded |
| DuckDB import data | — | `duckdb-import` | :orange_circle: Scaffolded |

### Round 372 — Splunk ext, Elasticsearch ext, Sumo Logic ext, Loki/Tempo ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Splunk SPL search | — | `splunk-search` | :orange_circle: Scaffolded |
| Splunk list indexes | — | `splunk-index` | :orange_circle: Scaffolded |
| Splunk dashboards | — | `splunk-dashboards` | :orange_circle: Scaffolded |
| Splunk saved alerts | — | `splunk-alerts` | :orange_circle: Scaffolded |
| Elasticsearch search | — | `elastic-search` | :orange_circle: Scaffolded |
| Elasticsearch indices | — | `elastic-index` | :orange_circle: Scaffolded |
| Elasticsearch mappings | — | `elastic-mappings` | :orange_circle: Scaffolded |
| Elasticsearch cluster | — | `elastic-cluster` | :orange_circle: Scaffolded |
| Sumo Logic search | — | `sumo-search` | :orange_circle: Scaffolded |
| Sumo Logic collectors | — | `sumo-collectors` | :orange_circle: Scaffolded |
| Sumo Logic dashboards | — | `sumo-dashboards` | :orange_circle: Scaffolded |
| Sumo Logic monitors | — | `sumo-monitors` | :orange_circle: Scaffolded |
| Loki recording rules | — | `loki-rules` | :orange_circle: Scaffolded |
| Loki ingestion stats | — | `loki-stats` | :orange_circle: Scaffolded |
| Loki log deletion | — | `loki-delete` | :orange_circle: Scaffolded |
| Loki ruler config | — | `loki-ruler` | :orange_circle: Scaffolded |
| Tempo list services | — | `tempo-services` | :orange_circle: Scaffolded |
| Tempo fetch trace | — | `tempo-traces` | :orange_circle: Scaffolded |
| Tempo query spansets | — | `tempo-spansets` | :orange_circle: Scaffolded |
| Tempo configuration | — | `tempo-config` | :orange_circle: Scaffolded |

### Round 371 — Sentry ext, Datadog ext, NewRelic ext, PagerDuty/OpsGenie ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| Sentry list issues | — | `sentry-issues` | :orange_circle: Scaffolded |
| Sentry list events | — | `sentry-events` | :orange_circle: Scaffolded |
| Sentry list releases | — | `sentry-releases` | :orange_circle: Scaffolded |
| Sentry list projects | — | `sentry-projects` | :orange_circle: Scaffolded |
| Datadog log search | — | `datadog-logs` | :orange_circle: Scaffolded |
| Datadog traces | — | `datadog-traces` | :orange_circle: Scaffolded |
| Datadog APM overview | — | `datadog-apm` | :orange_circle: Scaffolded |
| Datadog RUM | — | `datadog-rum` | :orange_circle: Scaffolded |
| New Relic NRQL query | — | `newrelic-nrql` | :orange_circle: Scaffolded |
| New Relic entities | — | `newrelic-entities` | :orange_circle: Scaffolded |
| New Relic workloads | — | `newrelic-workloads` | :orange_circle: Scaffolded |
| New Relic Nerdpacks | — | `newrelic-nerdpacks` | :orange_circle: Scaffolded |
| PagerDuty incidents | — | `pagerduty-incidents` | :orange_circle: Scaffolded |
| PagerDuty services | — | `pagerduty-services` | :orange_circle: Scaffolded |
| PagerDuty on-call | — | `pagerduty-oncall` | :orange_circle: Scaffolded |
| PagerDuty schedules | — | `pagerduty-schedules` | :orange_circle: Scaffolded |
| OpsGenie alerts | — | `opsgenie-alerts` | :orange_circle: Scaffolded |
| OpsGenie teams | — | `opsgenie-teams` | :orange_circle: Scaffolded |
| OpsGenie schedules | — | `opsgenie-schedules` | :orange_circle: Scaffolded |
| OpsGenie alert policies | — | `opsgenie-policies` | :orange_circle: Scaffolded |

### Round 370 — OpenAPI ext, Swagger ext, Postman ext, Insomnia/HTTPie ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| OpenAPI spec diff | — | `openapi-diff` | :orange_circle: Scaffolded |
| OpenAPI mock server | — | `openapi-mock` | :orange_circle: Scaffolded |
| OpenAPI merge specs | — | `openapi-merge` | :orange_circle: Scaffolded |
| OpenAPI bundle refs | — | `openapi-bundle` | :orange_circle: Scaffolded |
| Swagger UI preview | — | `swagger-ui` | :orange_circle: Scaffolded |
| Swagger editor | — | `swagger-editor` | :orange_circle: Scaffolded |
| Swagger code generation | — | `swagger-codegen` | :orange_circle: Scaffolded |
| Swagger mock server | — | `swagger-mock` | :orange_circle: Scaffolded |
| Postman import | — | `postman-import` | :orange_circle: Scaffolded |
| Postman export | — | `postman-export` | :orange_circle: Scaffolded |
| Postman run collection | — | `postman-run` | :orange_circle: Scaffolded |
| Postman environments | — | `postman-env` | :orange_circle: Scaffolded |
| Insomnia import | — | `insomnia-import` | :orange_circle: Scaffolded |
| Insomnia export | — | `insomnia-export` | :orange_circle: Scaffolded |
| Insomnia run requests | — | `insomnia-run` | :orange_circle: Scaffolded |
| Insomnia environments | — | `insomnia-env` | :orange_circle: Scaffolded |
| HTTPie send request | — | `httpie-send` | :orange_circle: Scaffolded |
| HTTPie sessions | — | `httpie-sessions` | :orange_circle: Scaffolded |
| HTTPie plugins | — | `httpie-plugins` | :orange_circle: Scaffolded |
| HTTPie auth config | — | `httpie-auth` | :orange_circle: Scaffolded |

### Round 369 — GraphQL ext, gRPC ext, Protobuf ext, Avro/Serialization ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| GraphQL display schema | `graphql-mode` | `graphql-schema` | :orange_circle: Scaffolded |
| GraphQL subscribe | — | `graphql-subscribe` | :orange_circle: Scaffolded |
| GraphQL federation check | — | `graphql-federation` | :orange_circle: Scaffolded |
| GraphQL persisted queries | — | `graphql-persisted` | :orange_circle: Scaffolded |
| gRPC list services | `grpc-mode` | `grpc-list` | :orange_circle: Scaffolded |
| gRPC describe service | — | `grpc-describe` | :orange_circle: Scaffolded |
| gRPC health check | — | `grpc-health` | :orange_circle: Scaffolded |
| gRPC server reflection | — | `grpc-reflect` | :orange_circle: Scaffolded |
| Protobuf breaking changes | `buf` | `protobuf-breaking` | :orange_circle: Scaffolded |
| Protobuf generate stubs | — | `protobuf-generate` | :orange_circle: Scaffolded |
| Protobuf dependencies | — | `protobuf-deps` | :orange_circle: Scaffolded |
| Protobuf schema registry | — | `protobuf-registry` | :orange_circle: Scaffolded |
| Avro display schema | — | `avro-schema` | :orange_circle: Scaffolded |
| Avro encode data | — | `avro-encode` | :orange_circle: Scaffolded |
| Avro decode data | — | `avro-decode` | :orange_circle: Scaffolded |
| Avro schema registry | — | `avro-registry` | :orange_circle: Scaffolded |
| Cap'n Proto decode | — | `capnproto-decode` | :orange_circle: Scaffolded |
| Cap'n Proto encode | — | `capnproto-encode` | :orange_circle: Scaffolded |
| Amazon Ion encode | — | `ion-encode` | :orange_circle: Scaffolded |
| Amazon Ion decode | — | `ion-decode` | :orange_circle: Scaffolded |

### Round 368 — MQTT ext, AMQP ext, NSQ ext, RabbitMQ/ActiveMQ ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| MQTT retained messages | — | `mqtt-retain` | :orange_circle: Scaffolded |
| MQTT last will config | — | `mqtt-will` | :orange_circle: Scaffolded |
| MQTT QoS level | — | `mqtt-qos` | :orange_circle: Scaffolded |
| MQTT bridge config | — | `mqtt-bridge` | :orange_circle: Scaffolded |
| AMQP publish | — | `amqp-publish` | :orange_circle: Scaffolded |
| AMQP consume | — | `amqp-consume` | :orange_circle: Scaffolded |
| AMQP declare queue | — | `amqp-declare` | :orange_circle: Scaffolded |
| AMQP bind queue | — | `amqp-bind` | :orange_circle: Scaffolded |
| Pulsar functions | — | `pulsar-functions` | :orange_circle: Scaffolded |
| Pulsar sinks | — | `pulsar-sinks` | :orange_circle: Scaffolded |
| NSQ publish | — | `nsq-publish` | :orange_circle: Scaffolded |
| NSQ consume | — | `nsq-consume` | :orange_circle: Scaffolded |
| NSQ list topics | — | `nsq-topics` | :orange_circle: Scaffolded |
| NSQ list channels | — | `nsq-channels` | :orange_circle: Scaffolded |
| RabbitMQ bindings | — | `rabbitmq-bindings` | :orange_circle: Scaffolded |
| RabbitMQ shovel | — | `rabbitmq-shovel` | :orange_circle: Scaffolded |
| RabbitMQ federation | — | `rabbitmq-federation` | :orange_circle: Scaffolded |
| RabbitMQ tracing | — | `rabbitmq-trace` | :orange_circle: Scaffolded |
| ActiveMQ queues | — | `activemq-queues` | :orange_circle: Scaffolded |
| ActiveMQ topics | — | `activemq-topics` | :orange_circle: Scaffolded |

### Round 367 — OAuth ext, SAML ext, OIDC ext, Kerberos/PAM/NTLM ext

| Feature | Emacs | jemacs | Status |
|---|---|---|---|
| OAuth authorize flow | `oauth2-auth` | `oauth-authorize` | :orange_circle: Scaffolded |
| OAuth refresh token | `oauth2-refresh-access` | `oauth-refresh` | :orange_circle: Scaffolded |
| OAuth revoke token | `oauth2-token-revoke` | `oauth-revoke` | :orange_circle: Scaffolded |
| OAuth introspect token | — | `oauth-introspect` | :orange_circle: Scaffolded |
| SAML fetch metadata | — | `saml-metadata` | :orange_circle: Scaffolded |
| SAML SSO login | — | `saml-login` | :orange_circle: Scaffolded |
| SAML single logout | — | `saml-logout` | :orange_circle: Scaffolded |
| SAML validate assertion | — | `saml-validate` | :orange_circle: Scaffolded |
| OIDC discover endpoints | — | `oidc-discover` | :orange_circle: Scaffolded |
| OIDC fetch userinfo | — | `oidc-userinfo` | :orange_circle: Scaffolded |
| OIDC request token | — | `oidc-token` | :orange_circle: Scaffolded |
| OIDC fetch JWKS keys | — | `oidc-jwks` | :orange_circle: Scaffolded |
| Kerberos kvno lookup | — | `kerberos-kvno` | :orange_circle: Scaffolded |
| PAM test auth | — | `pam-auth` | :orange_circle: Scaffolded |
| PAM check config | — | `pam-check` | :orange_circle: Scaffolded |
| NTLM compute hash | — | `ntlm-hash` | :orange_circle: Scaffolded |
| NTLM negotiate handshake | — | `ntlm-negotiate` | :orange_circle: Scaffolded |
| RADIUS authentication | — | `radius-auth` | :orange_circle: Scaffolded |
| RADIUS accounting | — | `radius-acct` | :orange_circle: Scaffolded |
| RADIUS server status | — | `radius-status` | :orange_circle: Scaffolded |

### Round 366 — Vault-SSH ext, CertManager ext, SPIFFE ext, ACME ext, Keycloak ext

| Feature | Status | Notes |
|---|---|---|
| vault-ssh-sign | :orange_circle: | Vault SSH: sign public key |
| vault-ssh-verify | :orange_circle: | Vault SSH: verify certificate |
| vault-ssh-role | :orange_circle: | Vault SSH: show role |
| vault-ssh-ca | :orange_circle: | Vault SSH: show CA key |
| certmanager-certs | :orange_circle: | CertManager: list certificates |
| certmanager-issuers | :orange_circle: | CertManager: list issuers |
| certmanager-orders | :orange_circle: | CertManager: list orders |
| certmanager-challenges | :orange_circle: | CertManager: list challenges |
| spiffe-entries | :orange_circle: | SPIFFE: list entries |
| spiffe-agents | :orange_circle: | SPIFFE: list agents |
| spiffe-bundles | :orange_circle: | SPIFFE: list trust bundles |
| spiffe-health | :orange_circle: | SPIFFE: server health |
| acme-register | :orange_circle: | ACME: register account |
| acme-issue | :orange_circle: | ACME: issue certificate |
| acme-renew | :orange_circle: | ACME: renew certificate |
| acme-revoke | :orange_circle: | ACME: revoke certificate |
| keycloak-realms | :orange_circle: | Keycloak: list realms |
| keycloak-users | :orange_circle: | Keycloak: list users |
| keycloak-clients | :orange_circle: | Keycloak: list clients |
| keycloak-roles | :orange_circle: | Keycloak: list roles |

### Round 365 — ETCD ext, ZooKeeper ext, Patroni ext, Stolon ext, PGBouncer ext

| Feature | Status | Notes |
|---|---|---|
| etcd-get | :orange_circle: | ETCD: get key |
| etcd-put | :orange_circle: | ETCD: put key |
| etcd-members | :orange_circle: | ETCD: list members |
| etcd-health | :orange_circle: | ETCD: check health |
| zookeeper-stat | :orange_circle: | ZooKeeper: server stats |
| zookeeper-ls | :orange_circle: | ZooKeeper: list path |
| zookeeper-get | :orange_circle: | ZooKeeper: get node |
| zookeeper-set | :orange_circle: | ZooKeeper: set node |
| patroni-list | :orange_circle: | Patroni: list members |
| patroni-switchover | :orange_circle: | Patroni: switchover |
| patroni-failover | :orange_circle: | Patroni: failover |
| patroni-history | :orange_circle: | Patroni: failover history |
| stolon-status | :orange_circle: | Stolon: cluster status |
| stolon-clusterdata | :orange_circle: | Stolon: cluster data |
| stolon-update | :orange_circle: | Stolon: update spec |
| stolon-init | :orange_circle: | Stolon: initialize cluster |
| pgbouncer-show-pools | :orange_circle: | PGBouncer: connection pools |
| pgbouncer-show-stats | :orange_circle: | PGBouncer: statistics |
| pgbouncer-show-databases | :orange_circle: | PGBouncer: databases |
| pgbouncer-reload | :orange_circle: | PGBouncer: reload config |

### Round 364 — MinIO ext, SeaweedFS ext, Ceph ext, GlusterFS ext, LongHorn ext

| Feature | Status | Notes |
|---|---|---|
| minio-ls | :orange_circle: | MinIO: list objects |
| minio-cp | :orange_circle: | MinIO: copy objects |
| minio-mb | :orange_circle: | MinIO: make bucket |
| minio-admin | :orange_circle: | MinIO: admin info |
| seaweedfs-master | :orange_circle: | SeaweedFS: master status |
| seaweedfs-volume | :orange_circle: | SeaweedFS: list volumes |
| seaweedfs-filer | :orange_circle: | SeaweedFS: filer status |
| seaweedfs-mount | :orange_circle: | SeaweedFS: mount filesystem |
| ceph-status | :orange_circle: | Ceph: cluster status |
| ceph-osd | :orange_circle: | Ceph: list OSDs |
| ceph-pool | :orange_circle: | Ceph: list pools |
| ceph-health | :orange_circle: | Ceph: health detail |
| glusterfs-volume | :orange_circle: | GlusterFS: list volumes |
| glusterfs-peer | :orange_circle: | GlusterFS: list peers |
| glusterfs-info | :orange_circle: | GlusterFS: volume info |
| glusterfs-heal | :orange_circle: | GlusterFS: heal volume |
| longhorn-volume | :orange_circle: | Longhorn: list volumes |
| longhorn-backup | :orange_circle: | Longhorn: list backups |
| longhorn-engine | :orange_circle: | Longhorn: engine status |
| longhorn-replica | :orange_circle: | Longhorn: list replicas |

### Round 363 — Velero ext, Restic ext, Borgbackup ext, Duplicity ext, Rclone ext

| Feature | Status | Notes |
|---|---|---|
| velero-backup | :orange_circle: | Velero: create backup |
| velero-restore | :orange_circle: | Velero: restore from backup |
| velero-schedule | :orange_circle: | Velero: list schedules |
| velero-get | :orange_circle: | Velero: list backups |
| restic-backup | :orange_circle: | Restic: backup path |
| restic-restore | :orange_circle: | Restic: restore snapshot |
| restic-snapshots | :orange_circle: | Restic: list snapshots |
| restic-check | :orange_circle: | Restic: check integrity |
| borg-create | :orange_circle: | Borg: create archive |
| borg-list | :orange_circle: | Borg: list archives |
| borg-extract | :orange_circle: | Borg: extract archive |
| borg-prune | :orange_circle: | Borg: prune archives |
| duplicity-backup | :orange_circle: | Duplicity: backup |
| duplicity-restore | :orange_circle: | Duplicity: restore |
| duplicity-verify | :orange_circle: | Duplicity: verify backup |
| duplicity-status | :orange_circle: | Duplicity: collection status |
| rclone-copy | :orange_circle: | Rclone: copy files |
| rclone-sync | :orange_circle: | Rclone: sync files |
| rclone-ls | :orange_circle: | Rclone: list remote |
| rclone-config | :orange_circle: | Rclone: show configuration |

### Round 362 — Telepresence ext, Kubevela ext, Knative ext, Dapr ext, KEDA ext

| Feature | Status | Notes |
|---|---|---|
| telepresence-connect | :orange_circle: | Telepresence: connect to cluster |
| telepresence-intercept | :orange_circle: | Telepresence: intercept service |
| telepresence-status | :orange_circle: | Telepresence: show status |
| telepresence-quit | :orange_circle: | Telepresence: disconnect |
| kubevela-up | :orange_circle: | KubeVela: deploy application |
| kubevela-status | :orange_circle: | KubeVela: application status |
| kubevela-show | :orange_circle: | KubeVela: show application |
| kubevela-delete | :orange_circle: | KubeVela: delete application |
| knative-service | :orange_circle: | Knative: list services |
| knative-revision | :orange_circle: | Knative: list revisions |
| knative-route | :orange_circle: | Knative: list routes |
| knative-domain | :orange_circle: | Knative: list domain mappings |
| dapr-run | :orange_circle: | Dapr: run application |
| dapr-stop | :orange_circle: | Dapr: stop application |
| dapr-list | :orange_circle: | Dapr: list running apps |
| dapr-invoke | :orange_circle: | Dapr: invoke method |
| keda-scalers | :orange_circle: | KEDA: list scalers |
| keda-status | :orange_circle: | KEDA: show status |
| keda-triggers | :orange_circle: | KEDA: list triggers |
| keda-version | :orange_circle: | KEDA: show version |

### Round 361 — Tilt ext, DevSpace ext, Skaffold ext, Garden ext, Okteto ext

| Feature | Status | Notes |
|---|---|---|
| tilt-up | :orange_circle: | Tilt: start dev environment |
| tilt-down | :orange_circle: | Tilt: tear down environment |
| tilt-ci | :orange_circle: | Tilt: run in CI mode |
| tilt-trigger | :orange_circle: | Tilt: trigger resource |
| devspace-dev | :orange_circle: | DevSpace: start dev mode |
| devspace-deploy | :orange_circle: | DevSpace: deploy |
| devspace-purge | :orange_circle: | DevSpace: purge deployment |
| devspace-logs | :orange_circle: | DevSpace: show logs |
| skaffold-dev | :orange_circle: | Skaffold: start dev loop |
| skaffold-run | :orange_circle: | Skaffold: build and deploy |
| skaffold-build | :orange_circle: | Skaffold: build artifacts |
| skaffold-render | :orange_circle: | Skaffold: render manifests |
| garden-deploy | :orange_circle: | Garden: deploy |
| garden-test | :orange_circle: | Garden: run tests |
| garden-dev | :orange_circle: | Garden: start dev mode |
| garden-logs | :orange_circle: | Garden: show logs |
| okteto-up | :orange_circle: | Okteto: activate dev env |
| okteto-down | :orange_circle: | Okteto: deactivate dev env |
| okteto-deploy | :orange_circle: | Okteto: deploy application |
| okteto-status | :orange_circle: | Okteto: show status |

### Round 360 — Gleam ext, Roc ext, Haxe ext, Janet ext, Fennel ext

| Feature | Status | Notes |
|---|---|---|
| gleam-build | :orange_circle: | Gleam: build project |
| gleam-test | :orange_circle: | Gleam: run tests |
| gleam-run | :orange_circle: | Gleam: run project |
| gleam-add | :orange_circle: | Gleam: add package |
| roc-build | :orange_circle: | Roc: build file |
| roc-run | :orange_circle: | Roc: run file |
| roc-test | :orange_circle: | Roc: run tests |
| roc-check | :orange_circle: | Roc: check file |
| haxe-build | :orange_circle: | Haxe: build project |
| haxe-run | :orange_circle: | Haxe: run project |
| haxe-test | :orange_circle: | Haxe: run tests |
| haxe-init | :orange_circle: | Haxe: initialize project |
| janet-run | :orange_circle: | Janet: run file |
| janet-build | :orange_circle: | Janet: build project |
| janet-test | :orange_circle: | Janet: run tests |
| janet-repl | :orange_circle: | Janet: start REPL |
| fennel-compile | :orange_circle: | Fennel: compile file |
| fennel-eval | :orange_circle: | Fennel: evaluate expression |
| fennel-repl | :orange_circle: | Fennel: start REPL |
| fennel-lint | :orange_circle: | Fennel: lint file |

### Round 359 — Poetry ext, UV ext, Rye ext, PDM ext, Hatch ext

| Feature | Status | Notes |
|---|---|---|
| poetry-install | :orange_circle: | Poetry: install dependencies |
| poetry-add | :orange_circle: | Poetry: add package |
| poetry-lock | :orange_circle: | Poetry: update lock file |
| poetry-show | :orange_circle: | Poetry: show packages |
| uv-pip-install | :orange_circle: | UV: pip install |
| uv-pip-compile | :orange_circle: | UV: compile requirements |
| uv-venv | :orange_circle: | UV: create virtual env |
| uv-run | :orange_circle: | UV: run command |
| rye-sync | :orange_circle: | Rye: sync dependencies |
| rye-add | :orange_circle: | Rye: add package |
| rye-pin | :orange_circle: | Rye: pin Python version |
| rye-show | :orange_circle: | Rye: show project info |
| pdm-install | :orange_circle: | PDM: install dependencies |
| pdm-add | :orange_circle: | PDM: add package |
| pdm-lock | :orange_circle: | PDM: update lock file |
| pdm-run | :orange_circle: | PDM: run command |
| hatch-build | :orange_circle: | Hatch: build project |
| hatch-test | :orange_circle: | Hatch: run tests |
| hatch-version | :orange_circle: | Hatch: show version |
| hatch-env | :orange_circle: | Hatch: manage environments |

### Round 358 — Conan ext, Vcpkg ext, Cargo ext, GoMod ext, Pip ext

| Feature | Status | Notes |
|---|---|---|
| conan-install | :orange_circle: | Conan: install package |
| conan-create | :orange_circle: | Conan: create package |
| conan-search | :orange_circle: | Conan: search packages |
| conan-remote | :orange_circle: | Conan: list remotes |
| vcpkg-install | :orange_circle: | Vcpkg: install package |
| vcpkg-search | :orange_circle: | Vcpkg: search packages |
| vcpkg-list | :orange_circle: | Vcpkg: list installed |
| vcpkg-integrate | :orange_circle: | Vcpkg: integrate with project |
| cargo-check | :orange_circle: | Cargo: check project |
| cargo-clippy | :orange_circle: | Cargo: run clippy lints |
| cargo-doc | :orange_circle: | Cargo: generate docs |
| cargo-bench | :orange_circle: | Cargo: run benchmarks |
| gomod-tidy | :orange_circle: | Go mod: tidy dependencies |
| gomod-graph | :orange_circle: | Go mod: dependency graph |
| gomod-download | :orange_circle: | Go mod: download deps |
| gomod-verify | :orange_circle: | Go mod: verify deps |
| pip-install | :orange_circle: | Pip: install package |
| pip-freeze | :orange_circle: | Pip: show installed |
| pip-search | :orange_circle: | Pip: search packages |
| pip-check | :orange_circle: | Pip: check consistency |

### Round 357 — LLVM ext, Clang ext, GCC ext, Meson ext, CMake ext

| Feature | Status | Notes |
|---|---|---|
| llvm-dis | :orange_circle: | LLVM: disassemble bitcode |
| llvm-as | :orange_circle: | LLVM: assemble IR |
| llvm-link | :orange_circle: | LLVM: link bitcode files |
| llvm-opt | :orange_circle: | LLVM: optimize bitcode |
| clang-ast-dump | :orange_circle: | Clang: dump AST |
| clang-tidy | :orange_circle: | Clang-Tidy: check code |
| clang-check | :orange_circle: | Clang-Check: analyze code |
| clang-query | :orange_circle: | Clang-Query: run matcher |
| gcc-dump | :orange_circle: | GCC: compiler dump |
| gcc-specs | :orange_circle: | GCC: compiler specs |
| gcc-machine | :orange_circle: | GCC: target machine |
| gcc-version | :orange_circle: | GCC: show version |
| meson-setup | :orange_circle: | Meson: setup build |
| meson-compile | :orange_circle: | Meson: compile project |
| meson-test | :orange_circle: | Meson: run tests |
| meson-install | :orange_circle: | Meson: install project |
| cmake-gui | :orange_circle: | CMake: open GUI |
| cmake-cache | :orange_circle: | CMake: show cache |
| cmake-test | :orange_circle: | CMake: run CTest |
| cmake-presets | :orange_circle: | CMake: list presets |

### Round 356 — Wasm ext, Wasmer ext, Wasmtime ext, WasmEdge ext, Emscripten ext

| Feature | Status | Notes |
|---|---|---|
| wasm-validate | :orange_circle: | Wasm: validate module |
| wasm-objdump | :orange_circle: | Wasm: dump module |
| wasm-strip | :orange_circle: | Wasm: strip module |
| wasm-decompile | :orange_circle: | Wasm: decompile module |
| wasmer-run | :orange_circle: | Wasmer: run module |
| wasmer-compile | :orange_circle: | Wasmer: compile module |
| wasmer-inspect | :orange_circle: | Wasmer: inspect module |
| wasmer-create-exe | :orange_circle: | Wasmer: create executable |
| wasmtime-run | :orange_circle: | Wasmtime: run module |
| wasmtime-compile | :orange_circle: | Wasmtime: compile module |
| wasmtime-explore | :orange_circle: | Wasmtime: explore module |
| wasmtime-settings | :orange_circle: | Wasmtime: show settings |
| wasmedge-run | :orange_circle: | WasmEdge: run module |
| wasmedge-compile | :orange_circle: | WasmEdge: compile module |
| wasmedge-version | :orange_circle: | WasmEdge: show version |
| wasmedge-plugins | :orange_circle: | WasmEdge: list plugins |
| emscripten-compile | :orange_circle: | Emscripten: compile file |
| emscripten-link | :orange_circle: | Emscripten: link output |
| emscripten-run | :orange_circle: | Emscripten: run file |
| emscripten-ports | :orange_circle: | Emscripten: list ports |

### Round 355 — Dagger ext, Earthly ext, Mise ext, Asdf ext, Direnv ext

| Feature | Status | Notes |
|---|---|---|
| dagger-call | :orange_circle: | Dagger: call a function |
| dagger-functions | :orange_circle: | Dagger: list functions |
| dagger-shell | :orange_circle: | Dagger: interactive shell |
| dagger-run | :orange_circle: | Dagger: run command |
| earthly-build | :orange_circle: | Earthly: build target |
| earthly-targets | :orange_circle: | Earthly: list targets |
| earthly-secrets | :orange_circle: | Earthly: list secrets |
| earthly-ls | :orange_circle: | Earthly: list artifacts |
| mise-install | :orange_circle: | Mise: install tool |
| mise-use | :orange_circle: | Mise: use tool version |
| mise-list | :orange_circle: | Mise: list installed tools |
| mise-env | :orange_circle: | Mise: show environment |
| asdf-install | :orange_circle: | Asdf: install plugin version |
| asdf-current | :orange_circle: | Asdf: show current versions |
| asdf-list | :orange_circle: | Asdf: list installed versions |
| asdf-plugin | :orange_circle: | Asdf: manage plugin |
| direnv-reload | :orange_circle: | Direnv: reload environment |
| direnv-deny | :orange_circle: | Direnv: deny .envrc |
| direnv-status | :orange_circle: | Direnv: show status |
| direnv-edit | :orange_circle: | Direnv: edit .envrc |

### Round 354 — Crossplane ext, Kustomize ext, Jsonnet ext, CUE ext, Dhall ext

| Feature | Status | Notes |
|---|---|---|
| crossplane-xrd | :orange_circle: | Crossplane: list XRDs |
| crossplane-composition | :orange_circle: | Crossplane: list compositions |
| crossplane-claim | :orange_circle: | Crossplane: list claims |
| crossplane-provider | :orange_circle: | Crossplane: list providers |
| kustomize-build | :orange_circle: | Kustomize: build overlay |
| kustomize-edit | :orange_circle: | Kustomize: edit kustomization |
| kustomize-create | :orange_circle: | Kustomize: create kustomization |
| kustomize-cfg | :orange_circle: | Kustomize: run cfg function |
| jsonnet-eval | :orange_circle: | Jsonnet: evaluate file |
| jsonnet-fmt | :orange_circle: | Jsonnet: format file |
| jsonnet-lint | :orange_circle: | Jsonnet: lint file |
| jsonnet-deps | :orange_circle: | Jsonnet: show dependencies |
| cue-eval | :orange_circle: | CUE: evaluate expression |
| cue-fmt | :orange_circle: | CUE: format files |
| cue-vet | :orange_circle: | CUE: validate data |
| cue-export | :orange_circle: | CUE: export to JSON/YAML |
| dhall-format | :orange_circle: | Dhall: format files |
| dhall-lint | :orange_circle: | Dhall: lint files |
| dhall-type | :orange_circle: | Dhall: show type |
| dhall-freeze | :orange_circle: | Dhall: freeze imports |

### Round 353 — Cosign ext, Sigstore ext, Notary ext, OPA ext, Kyverno ext

| Feature | Status | Notes |
|---|---|---|
| cosign-sign | :orange_circle: | Cosign: sign container image |
| cosign-verify | :orange_circle: | Cosign: verify image signature |
| cosign-attach | :orange_circle: | Cosign: attach attestation |
| cosign-tree | :orange_circle: | Cosign: supply chain tree |
| sigstore-sign | :orange_circle: | Sigstore: sign artifact |
| sigstore-verify | :orange_circle: | Sigstore: verify artifact |
| sigstore-inspect | :orange_circle: | Sigstore: inspect bundle |
| sigstore-bundle | :orange_circle: | Sigstore: show bundle info |
| notary-sign | :orange_circle: | Notary: sign artifact |
| notary-verify | :orange_circle: | Notary: verify artifact |
| notary-list | :orange_circle: | Notary: list signatures |
| notary-inspect | :orange_circle: | Notary: inspect artifact |
| opa-eval | :orange_circle: | OPA: evaluate query |
| opa-test | :orange_circle: | OPA: run tests |
| opa-check | :orange_circle: | OPA: check policy |
| opa-build | :orange_circle: | OPA: build policy bundle |
| kyverno-apply | :orange_circle: | Kyverno: apply policy |
| kyverno-test | :orange_circle: | Kyverno: run policy tests |
| kyverno-validate | :orange_circle: | Kyverno: validate resource |
| kyverno-policies | :orange_circle: | Kyverno: list policies |

### Round 352 — Sonarqube ext, Snyk ext, Trivy ext, Grype ext, Syft ext

| Feature | Status | Notes |
|---|---|---|
| sonarqube-scan | :orange_circle: | SonarQube: run analysis |
| sonarqube-quality-gate | :orange_circle: | SonarQube: check quality gate |
| sonarqube-issues | :orange_circle: | SonarQube: list issues |
| sonarqube-measures | :orange_circle: | SonarQube: project measures |
| snyk-test | :orange_circle: | Snyk: test vulnerabilities |
| snyk-monitor | :orange_circle: | Snyk: monitor project |
| snyk-fix | :orange_circle: | Snyk: apply fixes |
| snyk-code | :orange_circle: | Snyk: scan code |
| trivy-image | :orange_circle: | Trivy: scan container image |
| trivy-filesystem | :orange_circle: | Trivy: scan filesystem |
| trivy-repo | :orange_circle: | Trivy: scan repository |
| trivy-sbom | :orange_circle: | Trivy: generate SBOM |
| grype-scan | :orange_circle: | Grype: scan for vulnerabilities |
| grype-db-update | :orange_circle: | Grype: update database |
| grype-db-status | :orange_circle: | Grype: database status |
| grype-config | :orange_circle: | Grype: show configuration |
| syft-scan | :orange_circle: | Syft: scan for packages |
| syft-packages | :orange_circle: | Syft: list packages |
| syft-cataloger | :orange_circle: | Syft: list catalogers |
| syft-convert | :orange_circle: | Syft: convert SBOM format |

### Round 351 — ArgoCD ext, FluxCD ext, Tekton ext, Spinnaker ext, Jenkins ext

| Feature | Status | Notes |
|---|---|---|
| argocd-app-list | :orange_circle: | ArgoCD: list applications |
| argocd-app-sync | :orange_circle: | ArgoCD: sync application |
| argocd-app-get | :orange_circle: | ArgoCD: show application |
| argocd-repo-list | :orange_circle: | ArgoCD: list repositories |
| fluxcd-sources | :orange_circle: | FluxCD: list sources |
| fluxcd-kustomizations | :orange_circle: | FluxCD: list kustomizations |
| fluxcd-helmreleases | :orange_circle: | FluxCD: list helm releases |
| fluxcd-reconcile | :orange_circle: | FluxCD: reconcile resource |
| tekton-pipelines | :orange_circle: | Tekton: list pipelines |
| tekton-tasks | :orange_circle: | Tekton: list tasks |
| tekton-runs | :orange_circle: | Tekton: list pipeline runs |
| tekton-logs | :orange_circle: | Tekton: show run logs |
| spinnaker-apps | :orange_circle: | Spinnaker: list applications |
| spinnaker-pipelines | :orange_circle: | Spinnaker: list pipelines |
| spinnaker-executions | :orange_circle: | Spinnaker: list executions |
| spinnaker-deploy | :orange_circle: | Spinnaker: deploy pipeline |
| jenkins-jobs | :orange_circle: | Jenkins: list jobs |
| jenkins-build | :orange_circle: | Jenkins: build a job |
| jenkins-console | :orange_circle: | Jenkins: show console output |
| jenkins-queue | :orange_circle: | Jenkins: show build queue |

### Round 350 — Istio ext, Linkerd ext, Cilium ext, Calico ext, Flannel ext

| Feature | Status | Notes |
|---|---|---|
| istio-proxy-status | :orange_circle: | Istio: proxy sync status |
| istio-analyze | :orange_circle: | Istio: analyze configuration |
| istio-dashboard | :orange_circle: | Istio: open dashboard |
| istio-version | :orange_circle: | Istio: show version info |
| linkerd-check | :orange_circle: | Linkerd: health check |
| linkerd-stat | :orange_circle: | Linkerd: show stats |
| linkerd-tap | :orange_circle: | Linkerd: tap traffic |
| linkerd-dashboard | :orange_circle: | Linkerd: open dashboard |
| cilium-status | :orange_circle: | Cilium: agent status |
| cilium-endpoint | :orange_circle: | Cilium: list endpoints |
| cilium-policy | :orange_circle: | Cilium: list policies |
| cilium-monitor | :orange_circle: | Cilium: monitor events |
| calico-node | :orange_circle: | Calico: node status |
| calico-ippool | :orange_circle: | Calico: list IP pools |
| calico-policy | :orange_circle: | Calico: list policies |
| calico-status | :orange_circle: | Calico: cluster status |
| flannel-status | :orange_circle: | Flannel: show status |
| flannel-subnet | :orange_circle: | Flannel: subnet allocation |
| flannel-config | :orange_circle: | Flannel: show configuration |
| flannel-routes | :orange_circle: | Flannel: show routes |

### Round 349 — Wireguard ext, OpenVPN ext, StrongSwan ext, Tailscale ext, Nebula ext

| Feature | Status | Notes |
|---|---|---|
| wireguard-peers | :orange_circle: | Wireguard: list peers |
| wireguard-transfer | :orange_circle: | Wireguard: transfer stats |
| wireguard-allowedips | :orange_circle: | Wireguard: show allowed IPs |
| wireguard-endpoint | :orange_circle: | Wireguard: show endpoints |
| openvpn-connect | :orange_circle: | OpenVPN: connect |
| openvpn-disconnect | :orange_circle: | OpenVPN: disconnect |
| openvpn-log | :orange_circle: | OpenVPN: connection log |
| openvpn-routes | :orange_circle: | OpenVPN: pushed routes |
| strongswan-list | :orange_circle: | StrongSwan: list SAs |
| strongswan-up | :orange_circle: | StrongSwan: bring up connection |
| strongswan-down | :orange_circle: | StrongSwan: bring down connection |
| strongswan-leases | :orange_circle: | StrongSwan: show IP leases |
| tailscale-status | :orange_circle: | Tailscale: network status |
| tailscale-peers | :orange_circle: | Tailscale: list peers |
| tailscale-ip | :orange_circle: | Tailscale: show IP addresses |
| tailscale-up | :orange_circle: | Tailscale: connect to network |
| nebula-status | :orange_circle: | Nebula: overlay status |
| nebula-peers | :orange_circle: | Nebula: list peers |
| nebula-config | :orange_circle: | Nebula: show configuration |
| nebula-cert | :orange_circle: | Nebula: certificate info |

### Round 348 — Nginx ext, HAProxy ext, Envoy ext, Traefik ext, Caddy ext

| Feature | Status | Notes |
|---|---|---|
| nginx-status | :orange_circle: | Nginx: show stub status |
| nginx-config | :orange_circle: | Nginx: show configuration |
| nginx-reload | :orange_circle: | Nginx: reload configuration |
| nginx-test | :orange_circle: | Nginx: test configuration |
| haproxy-stats | :orange_circle: | HAProxy: show statistics |
| haproxy-info | :orange_circle: | HAProxy: show info |
| haproxy-backends | :orange_circle: | HAProxy: list backends |
| haproxy-servers | :orange_circle: | HAProxy: list servers |
| envoy-clusters | :orange_circle: | Envoy: list clusters |
| envoy-listeners | :orange_circle: | Envoy: list listeners |
| envoy-routes | :orange_circle: | Envoy: list routes |
| envoy-stats | :orange_circle: | Envoy: show statistics |
| traefik-routers | :orange_circle: | Traefik: list routers |
| traefik-services | :orange_circle: | Traefik: list services |
| traefik-middlewares | :orange_circle: | Traefik: list middlewares |
| traefik-entrypoints | :orange_circle: | Traefik: list entrypoints |
| caddy-config | :orange_circle: | Caddy: show configuration |
| caddy-reload | :orange_circle: | Caddy: reload configuration |
| caddy-reverse-proxy | :orange_circle: | Caddy: reverse proxy setup |
| caddy-adapt | :orange_circle: | Caddy: adapt Caddyfile to JSON |

### Round 347 — PostgreSQL ext, MySQL ext, ClickHouse ext, ScyllaDB ext, TiDB ext

| Feature | Status | Notes |
|---|---|---|
| postgresql-databases | :orange_circle: | PostgreSQL: list databases |
| postgresql-tables | :orange_circle: | PostgreSQL: list tables |
| postgresql-users | :orange_circle: | PostgreSQL: list users/roles |
| postgresql-activity | :orange_circle: | PostgreSQL: active connections |
| mysql-databases | :orange_circle: | MySQL: list databases |
| mysql-tables | :orange_circle: | MySQL: list tables |
| mysql-users | :orange_circle: | MySQL: list users |
| mysql-processlist | :orange_circle: | MySQL: show process list |
| clickhouse-databases | :orange_circle: | ClickHouse: list databases |
| clickhouse-tables | :orange_circle: | ClickHouse: list tables |
| clickhouse-query | :orange_circle: | ClickHouse: execute SQL |
| clickhouse-parts | :orange_circle: | ClickHouse: show parts info |
| scylladb-status | :orange_circle: | ScyllaDB: cluster status |
| scylladb-nodetool | :orange_circle: | ScyllaDB: run nodetool |
| scylladb-cqlsh | :orange_circle: | ScyllaDB: execute CQL |
| scylladb-repair | :orange_circle: | ScyllaDB: run repair |
| tidb-status | :orange_circle: | TiDB: cluster status |
| tidb-regions | :orange_circle: | TiDB: list regions |
| tidb-stores | :orange_circle: | TiDB: list TiKV stores |
| tidb-tables | :orange_circle: | TiDB: list tables |

### Round 346 — RabbitMQ ext, Kafka ext, NATS ext, Redis ext, Memcached ext

| Feature | Status | Notes |
|---|---|---|
| rabbitmq-policies | :orange_circle: | RabbitMQ: list policies |
| rabbitmq-users | :orange_circle: | RabbitMQ: list users |
| rabbitmq-connections | :orange_circle: | RabbitMQ: list connections |
| rabbitmq-vhosts | :orange_circle: | RabbitMQ: list virtual hosts |
| kafka-acls | :orange_circle: | Kafka: list ACLs |
| kafka-consumers | :orange_circle: | Kafka: describe consumer group |
| kafka-groups | :orange_circle: | Kafka: list consumer groups |
| kafka-describe | :orange_circle: | Kafka: describe topic |
| nats-pub | :orange_circle: | NATS: publish to subject |
| nats-sub | :orange_circle: | NATS: subscribe to subject |
| nats-stream | :orange_circle: | NATS: list JetStream streams |
| nats-server | :orange_circle: | NATS: show server info |
| redis-info | :orange_circle: | Redis: show server info |
| redis-dbsize | :orange_circle: | Redis: show database size |
| redis-monitor | :orange_circle: | Redis: monitor commands |
| redis-slowlog | :orange_circle: | Redis: show slow log |
| memcached-version | :orange_circle: | Memcached: show version |
| memcached-slabs | :orange_circle: | Memcached: slab stats |
| memcached-items | :orange_circle: | Memcached: item stats |
| memcached-connections | :orange_circle: | Memcached: connection stats |

### Round 345 — Elasticsearch ext, Kibana ext, Fluentd ext, Logstash ext, Beats ext

| Feature | Status | Notes |
|---|---|---|
| elasticsearch-search | :orange_circle: | Elasticsearch: search query |
| elasticsearch-mapping | :orange_circle: | Elasticsearch: show index mapping |
| elasticsearch-cluster | :orange_circle: | Elasticsearch: cluster health |
| elasticsearch-nodes | :orange_circle: | Elasticsearch: list nodes |
| kibana-spaces | :orange_circle: | Kibana: list spaces |
| kibana-saved-objects | :orange_circle: | Kibana: list saved objects |
| kibana-rules | :orange_circle: | Kibana: list alert rules |
| kibana-discover | :orange_circle: | Kibana: open discover view |
| fluentd-status | :orange_circle: | Fluentd: show status |
| fluentd-plugins | :orange_circle: | Fluentd: list plugins |
| fluentd-config | :orange_circle: | Fluentd: show configuration |
| fluentd-buffers | :orange_circle: | Fluentd: show buffer status |
| logstash-pipelines | :orange_circle: | Logstash: list pipelines |
| logstash-stats | :orange_circle: | Logstash: show statistics |
| logstash-plugins | :orange_circle: | Logstash: list plugins |
| logstash-reload | :orange_circle: | Logstash: reload configuration |
| beats-status | :orange_circle: | Beats: show status |
| beats-modules | :orange_circle: | Beats: list modules |
| beats-setup | :orange_circle: | Beats: run setup |
| beats-keystore | :orange_circle: | Beats: manage keystore |

### Round 344 — Jaeger ext, Zipkin ext, OpenTelemetry ext, Datadog ext, NewRelic ext

| Feature | Status | Notes |
|---|---|---|
| jaeger-traces | :orange_circle: | Jaeger: list traces for service |
| jaeger-services | :orange_circle: | Jaeger: list services |
| jaeger-operations | :orange_circle: | Jaeger: list operations |
| jaeger-dependencies | :orange_circle: | Jaeger: service dependencies |
| zipkin-traces | :orange_circle: | Zipkin: list traces |
| zipkin-services | :orange_circle: | Zipkin: list services |
| zipkin-spans | :orange_circle: | Zipkin: show spans |
| zipkin-dependencies | :orange_circle: | Zipkin: service dependencies |
| otel-status | :orange_circle: | OpenTelemetry: collector status |
| otel-config | :orange_circle: | OpenTelemetry: collector config |
| otel-receivers | :orange_circle: | OpenTelemetry: list receivers |
| otel-exporters | :orange_circle: | OpenTelemetry: list exporters |
| datadog-monitors | :orange_circle: | Datadog: list monitors |
| datadog-dashboards | :orange_circle: | Datadog: list dashboards |
| datadog-events | :orange_circle: | Datadog: list events |
| datadog-metrics | :orange_circle: | Datadog: query metrics |
| newrelic-apps | :orange_circle: | NewRelic: list applications |
| newrelic-alerts | :orange_circle: | NewRelic: list alert policies |
| newrelic-dashboards | :orange_circle: | NewRelic: list dashboards |
| newrelic-synthetics | :orange_circle: | NewRelic: list synthetic monitors |

### Round 343 — Thanos ext, Grafana ext, Alertmanager ext, Loki ext, Tempo ext

| Feature | Status | Notes |
|---|---|---|
| thanos-query | :orange_circle: | Thanos: PromQL query |
| thanos-store | :orange_circle: | Thanos: store gateway status |
| thanos-compact | :orange_circle: | Thanos: compactor status |
| thanos-rule | :orange_circle: | Thanos: ruler rules |
| grafana-dashboards | :orange_circle: | Grafana: list dashboards |
| grafana-datasources | :orange_circle: | Grafana: list data sources |
| grafana-annotations | :orange_circle: | Grafana: list annotations |
| grafana-alerts | :orange_circle: | Grafana: list alert rules |
| alertmanager-status | :orange_circle: | Alertmanager: show status |
| alertmanager-alerts | :orange_circle: | Alertmanager: active alerts |
| alertmanager-silence | :orange_circle: | Alertmanager: create silence |
| alertmanager-receivers | :orange_circle: | Alertmanager: list receivers |
| loki-query | :orange_circle: | Loki: LogQL query |
| loki-labels | :orange_circle: | Loki: list labels |
| loki-series | :orange_circle: | Loki: query series |
| loki-tail | :orange_circle: | Loki: tail logs |
| tempo-search | :orange_circle: | Tempo: search traces |
| tempo-trace | :orange_circle: | Tempo: fetch trace by ID |
| tempo-tags | :orange_circle: | Tempo: list tag names |
| tempo-metrics | :orange_circle: | Tempo: metrics summary |

### Round 342 — Ansible ext, Salt ext, Chef ext, Puppet ext, CFEngine ext

| Feature | Status | Notes |
|---|---|---|
| ansible-config | :orange_circle: | Ansible: show configuration |
| ansible-inventory | :orange_circle: | Ansible: load inventory |
| ansible-galaxy | :orange_circle: | Ansible: install Galaxy role |
| ansible-vault | :orange_circle: | Ansible: edit vault file |
| salt-call | :orange_circle: | Salt: call a function |
| salt-key | :orange_circle: | Salt: list minion keys |
| salt-master | :orange_circle: | Salt: master status |
| salt-minion | :orange_circle: | Salt: minion status |
| chef-run | :orange_circle: | Chef: run a recipe |
| chef-generate | :orange_circle: | Chef: generate cookbook/recipe |
| chef-show-policy | :orange_circle: | Chef: show policy group |
| chef-search | :orange_circle: | Chef: search index |
| puppet-module | :orange_circle: | Puppet: install module |
| puppet-resource | :orange_circle: | Puppet: show resource |
| puppet-facts | :orange_circle: | Puppet: show system facts |
| puppet-catalog | :orange_circle: | Puppet: compile catalog |
| cfengine-run | :orange_circle: | CFEngine: run agent |
| cfengine-promises | :orange_circle: | CFEngine: check promises |
| cfengine-report | :orange_circle: | CFEngine: compliance report |
| cfengine-hub | :orange_circle: | CFEngine: hub status |

### Round 341 — Pulumi ext, Packer ext, Boundary ext, Consul ext, Nomad ext

| Feature | Status | Notes |
|---|---|---|
| pulumi-up | :orange_circle: | Pulumi: deploy stack |
| pulumi-preview | :orange_circle: | Pulumi: preview changes |
| pulumi-destroy | :orange_circle: | Pulumi: destroy stack |
| pulumi-stack | :orange_circle: | Pulumi: show stack info |
| packer-build | :orange_circle: | Packer: build image |
| packer-validate | :orange_circle: | Packer: validate template |
| packer-inspect | :orange_circle: | Packer: inspect template |
| packer-fmt | :orange_circle: | Packer: format templates |
| boundary-connect | :orange_circle: | Boundary: connect to target |
| boundary-authenticate | :orange_circle: | Boundary: authenticate |
| boundary-targets | :orange_circle: | Boundary: list targets |
| boundary-sessions | :orange_circle: | Boundary: list sessions |
| consul-members | :orange_circle: | Consul: list cluster members |
| consul-services | :orange_circle: | Consul: list services |
| consul-kv-get | :orange_circle: | Consul: get KV value |
| consul-kv-put | :orange_circle: | Consul: put KV value |
| nomad-status | :orange_circle: | Nomad: cluster status |
| nomad-job-run | :orange_circle: | Nomad: run a job |
| nomad-job-stop | :orange_circle: | Nomad: stop a job |
| nomad-alloc | :orange_circle: | Nomad: show allocation |

### Round 340 — Helm ext, Kubectl ext, Minikube ext, Kind ext, K3s ext

| Feature | Status | Notes |
|---|---|---|
| helm-install | :orange_circle: | Helm: install a release |
| helm-upgrade | :orange_circle: | Helm: upgrade a release |
| helm-list | :orange_circle: | Helm: list releases |
| helm-repo-add | :orange_circle: | Helm: add a repo |
| kubectl-get | :orange_circle: | Kubectl: get resources |
| kubectl-describe | :orange_circle: | Kubectl: describe a resource |
| kubectl-logs | :orange_circle: | Kubectl: show pod logs |
| kubectl-exec | :orange_circle: | Kubectl: exec into pod |
| minikube-start | :orange_circle: | Minikube: start cluster |
| minikube-stop | :orange_circle: | Minikube: stop cluster |
| minikube-status | :orange_circle: | Minikube: show status |
| minikube-dashboard | :orange_circle: | Minikube: open dashboard |
| kind-create | :orange_circle: | Kind: create cluster |
| kind-delete | :orange_circle: | Kind: delete cluster |
| kind-load | :orange_circle: | Kind: load image |
| kind-export | :orange_circle: | Kind: export logs |
| k3s-start | :orange_circle: | K3s: start server |
| k3s-stop | :orange_circle: | K3s: stop server |
| k3s-status | :orange_circle: | K3s: show status |
| k3s-kubectl | :orange_circle: | K3s: run kubectl command |

### Round 339 — Podman ext, Buildah ext, Skopeo ext, Crictl ext, Crun ext

| Feature | Status | Notes |
|---|---|---|
| podman-ps | :orange_circle: | Podman: list running containers |
| podman-images | :orange_circle: | Podman: list images |
| podman-run | :orange_circle: | Podman: run a container |
| podman-build | :orange_circle: | Podman: build an image |
| buildah-from | :orange_circle: | Buildah: create container from image |
| buildah-run | :orange_circle: | Buildah: run command in container |
| buildah-commit | :orange_circle: | Buildah: commit container |
| buildah-images | :orange_circle: | Buildah: list images |
| skopeo-copy | :orange_circle: | Skopeo: copy image |
| skopeo-inspect | :orange_circle: | Skopeo: inspect image |
| skopeo-list | :orange_circle: | Skopeo: list tags |
| skopeo-delete | :orange_circle: | Skopeo: delete image |
| crictl-pods | :orange_circle: | Crictl: list pods |
| crictl-containers | :orange_circle: | Crictl: list containers |
| crictl-images | :orange_circle: | Crictl: list images |
| crictl-stats | :orange_circle: | Crictl: container stats |
| crun-spec | :orange_circle: | Crun: generate OCI spec |
| crun-run | :orange_circle: | Crun: run container |
| crun-list | :orange_circle: | Crun: list containers |
| crun-state | :orange_circle: | Crun: show container state |

### Round 338 — Cgroups ext, Namespaces ext, Systemd-nspawn ext, Firejail ext, Bubblewrap ext

| Feature | Status | Notes |
|---|---|---|
| cgroups-list | :orange_circle: | Cgroups: list control groups |
| cgroups-tree | :orange_circle: | Cgroups: show cgroup tree |
| cgroups-create | :orange_circle: | Cgroups: create a cgroup |
| cgroups-move | :orange_circle: | Cgroups: move PID to cgroup |
| namespaces-list | :orange_circle: | Namespaces: list all namespaces |
| namespaces-enter | :orange_circle: | Namespaces: enter a namespace |
| namespaces-create | :orange_circle: | Namespaces: create a namespace |
| namespaces-pid | :orange_circle: | Namespaces: show for PID |
| nspawn-boot | :orange_circle: | Nspawn: boot container |
| nspawn-directory | :orange_circle: | Nspawn: run in directory |
| nspawn-image | :orange_circle: | Nspawn: boot from image |
| nspawn-network | :orange_circle: | Nspawn: configure networking |
| firejail-run | :orange_circle: | Firejail: run sandboxed command |
| firejail-profile | :orange_circle: | Firejail: use a profile |
| firejail-list | :orange_circle: | Firejail: list sandboxed processes |
| firejail-join | :orange_circle: | Firejail: join a sandbox |
| bubblewrap-run | :orange_circle: | Bubblewrap: run sandboxed command |
| bubblewrap-bind | :orange_circle: | Bubblewrap: bind a path |
| bubblewrap-network | :orange_circle: | Bubblewrap: enable network |
| bubblewrap-tmpfs | :orange_circle: | Bubblewrap: mount tmpfs |

### Round 337 — Ftrace ext, Irqbalance ext, Chrt ext, Ionice ext, Tuna ext

| Feature | Status | Notes |
|---|---|---|
| ftrace-enable | :orange_circle: | Ftrace: enable function tracer |
| ftrace-disable | :orange_circle: | Ftrace: disable tracer |
| ftrace-events | :orange_circle: | Ftrace: list available events |
| ftrace-filter | :orange_circle: | Ftrace: set function filter |
| irqbalance-status | :orange_circle: | Irqbalance: show status |
| irqbalance-oneshot | :orange_circle: | Irqbalance: one-shot balance |
| irqbalance-ban | :orange_circle: | Irqbalance: ban an IRQ |
| irqbalance-debug | :orange_circle: | Irqbalance: debug mode output |
| chrt-show | :orange_circle: | Chrt: show scheduling policy |
| chrt-fifo | :orange_circle: | Chrt: set FIFO priority |
| chrt-rr | :orange_circle: | Chrt: set round-robin priority |
| chrt-batch | :orange_circle: | Chrt: set SCHED_BATCH policy |
| ionice-get | :orange_circle: | Ionice: get I/O class for PID |
| ionice-set | :orange_circle: | Ionice: set I/O class |
| ionice-class | :orange_circle: | Ionice: list scheduling classes |
| ionice-idle | :orange_circle: | Ionice: set idle I/O class |
| tuna-show | :orange_circle: | Tuna: show IRQ/thread affinities |
| tuna-irqs | :orange_circle: | Tuna: list IRQ affinities |
| tuna-threads | :orange_circle: | Tuna: list thread affinities |
| tuna-isolate | :orange_circle: | Tuna: isolate a CPU |

### Round 336 — Perf ext, Strace ext, Ltrace ext, Sysdig ext, Bpftrace ext

| Feature | Status | Notes |
|---|---|---|
| perf-annotate | :orange_circle: | Perf: annotate source with profiling data |
| perf-diff | :orange_circle: | Perf: diff between perf.data files |
| perf-script | :orange_circle: | Perf: script output from perf.data |
| perf-bench | :orange_circle: | Perf: run benchmark suite |
| strace-process | :orange_circle: | Strace: trace a process by PID |
| strace-syscall | :orange_circle: | Strace: filter by syscall |
| strace-summary | :orange_circle: | Strace: syscall summary |
| strace-follow | :orange_circle: | Strace: follow child processes |
| ltrace-process | :orange_circle: | Ltrace: trace a process |
| ltrace-demangle | :orange_circle: | Ltrace: demangle C++ symbols |
| ltrace-summary | :orange_circle: | Ltrace: library call summary |
| ltrace-count | :orange_circle: | Ltrace: count library calls |
| sysdig-capture | :orange_circle: | Sysdig: capture events to file |
| sysdig-chisel | :orange_circle: | Sysdig: run a chisel |
| sysdig-filter | :orange_circle: | Sysdig: apply event filter |
| sysdig-live | :orange_circle: | Sysdig: live event stream |
| bpftrace-probe | :orange_circle: | BPFtrace: attach a probe |
| bpftrace-script | :orange_circle: | BPFtrace: run a script |
| bpftrace-histogram | :orange_circle: | BPFtrace: generate histogram |
| bpftrace-oneliners | :orange_circle: | BPFtrace: common one-liners |

### Round 335 — Hwinfo ext, Inxi ext, Lstopo ext, Likwid ext, Mcelog ext

| Feature | Status | Notes |
|---|---|---|
| hwinfo-all | :orange_circle: | Hwinfo: show all hardware info |
| hwinfo-cpu | :orange_circle: | Hwinfo: CPU information |
| hwinfo-disk | :orange_circle: | Hwinfo: disk information |
| hwinfo-network | :orange_circle: | Hwinfo: network information |
| inxi-system | :orange_circle: | Inxi: system summary |
| inxi-cpu | :orange_circle: | Inxi: CPU details |
| inxi-graphics | :orange_circle: | Inxi: graphics information |
| inxi-audio | :orange_circle: | Inxi: audio information |
| lstopo-show | :orange_circle: | Lstopo: show hardware topology |
| lstopo-text | :orange_circle: | Lstopo: text topology output |
| lstopo-xml | :orange_circle: | Lstopo: XML topology output |
| lstopo-png | :orange_circle: | Lstopo: PNG topology output |
| likwid-topology | :orange_circle: | Likwid: CPU topology |
| likwid-perfctr | :orange_circle: | Likwid: performance counters |
| likwid-pin | :orange_circle: | Likwid: pin threads to CPUs |
| likwid-bench | :orange_circle: | Likwid: run benchmarks |
| mcelog-show | :orange_circle: | Mcelog: show machine check events |
| mcelog-daemon | :orange_circle: | Mcelog: daemon status |
| mcelog-client | :orange_circle: | Mcelog: client query |
| mcelog-triggers | :orange_circle: | Mcelog: showing trigger scripts |

### Round 334 — Lscpu ext, Lspci ext, Lsusb ext, Lshw ext, Dmidecode ext

| Feature | Status | Notes |
|---------|--------|-------|
| `lscpu-show` | :orange_circle: | Show CPU architecture |
| `lscpu-json` | :orange_circle: | CPU info as JSON |
| `lscpu-extended` | :orange_circle: | Extended CPU info |
| `lscpu-caches` | :orange_circle: | CPU cache info |
| `lspci-show` | :orange_circle: | List PCI devices |
| `lspci-verbose` | :orange_circle: | Verbose PCI listing |
| `lspci-kernel` | :orange_circle: | Show kernel drivers |
| `lspci-tree` | :orange_circle: | PCI device tree |
| `lsusb-show` | :orange_circle: | List USB devices |
| `lsusb-verbose` | :orange_circle: | Verbose USB listing |
| `lsusb-tree` | :orange_circle: | USB device tree |
| `lsusb-device` | :orange_circle: | Show specific device |
| `lshw-show` | :orange_circle: | Show hardware info |
| `lshw-short` | :orange_circle: | Short hardware listing |
| `lshw-class` | :orange_circle: | Filter by class |
| `lshw-json` | :orange_circle: | Hardware as JSON |
| `dmidecode-show` | :orange_circle: | Show DMI table |
| `dmidecode-type` | :orange_circle: | Show by DMI type |
| `dmidecode-string` | :orange_circle: | Show string keyword |
| `dmidecode-keyword` | :orange_circle: | List keywords |

### Round 333 — Lsof-ext ext, Fuser ext, Lsns ext, Lsipc ext, Lsmem ext

| Feature | Status | Notes |
|---------|--------|-------|
| `lsof-network` | :orange_circle: | Show network connections |
| `lsof-process` | :orange_circle: | Files by PID |
| `lsof-file` | :orange_circle: | Processes using file |
| `lsof-user` | :orange_circle: | Files by user |
| `fuser-file` | :orange_circle: | Processes using file |
| `fuser-mount` | :orange_circle: | Processes on mount |
| `fuser-signal` | :orange_circle: | Signal processes |
| `fuser-verbose` | :orange_circle: | Verbose file usage |
| `lsns-show` | :orange_circle: | List namespaces |
| `lsns-type` | :orange_circle: | List by type |
| `lsns-pid` | :orange_circle: | Namespaces by PID |
| `lsns-json` | :orange_circle: | JSON output |
| `lsipc-show` | :orange_circle: | Show IPC facilities |
| `lsipc-semaphore` | :orange_circle: | Show semaphores |
| `lsipc-shared` | :orange_circle: | Show shared memory |
| `lsipc-message` | :orange_circle: | Show message queues |
| `lsmem-show` | :orange_circle: | Show memory ranges |
| `lsmem-json` | :orange_circle: | JSON output |
| `lsmem-summary` | :orange_circle: | Memory summary |
| `lsmem-ranges` | :orange_circle: | All memory ranges |

### Round 332 — Slabtop ext, Pmap ext, Smem ext, Fincore ext, Lslocks ext

| Feature | Status | Notes |
|---------|--------|-------|
| `slabtop-show` | :orange_circle: | Show kernel slab cache |
| `slabtop-once` | :orange_circle: | One-shot slab display |
| `slabtop-sort` | :orange_circle: | Sort slab output |
| `slabtop-delay` | :orange_circle: | Set refresh delay |
| `pmap-show` | :orange_circle: | Show memory map |
| `pmap-extended` | :orange_circle: | Extended memory map |
| `pmap-device` | :orange_circle: | Device format map |
| `pmap-quiet` | :orange_circle: | Quiet format map |
| `smem-show` | :orange_circle: | Show memory usage |
| `smem-process` | :orange_circle: | Per-process memory |
| `smem-user` | :orange_circle: | Per-user memory |
| `smem-system` | :orange_circle: | System-wide memory |
| `fincore-show` | :orange_circle: | Show cached pages |
| `fincore-file` | :orange_circle: | File cache info |
| `fincore-summary` | :orange_circle: | Cache summary |
| `fincore-json` | :orange_circle: | JSON output |
| `lslocks-show` | :orange_circle: | Show file locks |
| `lslocks-json` | :orange_circle: | Locks as JSON |
| `lslocks-noheading` | :orange_circle: | Locks without header |
| `lslocks-pid` | :orange_circle: | Locks by PID |

### Round 331 — Collectl ext, Atop ext, Glances ext, Htop-ext ext, Btop ext

| Feature | Status | Notes |
|---------|--------|-------|
| `collectl-cpu` | :orange_circle: | CPU statistics |
| `collectl-disk` | :orange_circle: | Disk statistics |
| `collectl-network` | :orange_circle: | Network statistics |
| `collectl-memory` | :orange_circle: | Memory statistics |
| `atop-show` | :orange_circle: | System overview |
| `atop-process` | :orange_circle: | Process view |
| `atop-disk` | :orange_circle: | Disk view |
| `atop-memory` | :orange_circle: | Memory view |
| `glances-show` | :orange_circle: | System monitor |
| `glances-export` | :orange_circle: | Export data |
| `glances-web` | :orange_circle: | Web interface |
| `glances-alert` | :orange_circle: | Show alerts |
| `htop-process` | :orange_circle: | Process list |
| `htop-tree` | :orange_circle: | Process tree |
| `htop-filter` | :orange_circle: | Filter processes |
| `htop-sort` | :orange_circle: | Sort processes |
| `btop-show` | :orange_circle: | System monitor |
| `btop-theme` | :orange_circle: | Set theme |
| `btop-filter` | :orange_circle: | Filter view |
| `btop-export` | :orange_circle: | Export data |

### Round 330 — Perf-sched ext, Numastat ext, Vmstat ext, Dstat ext, Nmon ext

| Feature | Status | Notes |
|---------|--------|-------|
| `perf-sched-record` | :orange_circle: | Record scheduling events |
| `perf-sched-latency` | :orange_circle: | Show scheduling latency |
| `perf-sched-map` | :orange_circle: | Show scheduling map |
| `perf-sched-replay` | :orange_circle: | Replay scheduling events |
| `numastat-show` | :orange_circle: | Show NUMA statistics |
| `numastat-process` | :orange_circle: | Process NUMA stats |
| `numastat-node` | :orange_circle: | Node NUMA stats |
| `numastat-detail` | :orange_circle: | Detailed NUMA stats |
| `vmstat-show` | :orange_circle: | Show VM statistics |
| `vmstat-disk` | :orange_circle: | Show disk statistics |
| `vmstat-slab` | :orange_circle: | Show slab info |
| `vmstat-active` | :orange_circle: | Show active/inactive memory |
| `dstat-cpu` | :orange_circle: | CPU statistics |
| `dstat-mem` | :orange_circle: | Memory statistics |
| `dstat-disk` | :orange_circle: | Disk statistics |
| `dstat-net` | :orange_circle: | Network statistics |
| `nmon-interactive` | :orange_circle: | Interactive monitor |
| `nmon-report` | :orange_circle: | Generate report |
| `nmon-csv` | :orange_circle: | Export CSV |
| `nmon-snapshot` | :orange_circle: | Take system snapshot |

### Round 329 — Pam ext, Sssd ext, Kerberos ext, Ldap ext, Nss ext

| Feature | Status | Notes |
|---------|--------|-------|
| `pam-auth-config` | :orange_circle: | Show PAM auth config |
| `pam-test` | :orange_circle: | Test PAM service |
| `pam-modules` | :orange_circle: | List PAM modules |
| `pam-limits` | :orange_circle: | Show PAM limits |
| `sssd-status` | :orange_circle: | Show SSSD status |
| `sssd-cache` | :orange_circle: | Clear SSSD cache |
| `sssd-domains` | :orange_circle: | List SSSD domains |
| `sssd-debug` | :orange_circle: | Set SSSD debug level |
| `kerberos-kinit` | :orange_circle: | Initialize ticket |
| `kerberos-klist` | :orange_circle: | List tickets |
| `kerberos-kdestroy` | :orange_circle: | Destroy tickets |
| `kerberos-kpasswd` | :orange_circle: | Change password |
| `ldap-whoami` | :orange_circle: | Show bound identity |
| `ldap-passwd` | :orange_circle: | Change LDAP password |
| `ldap-compare` | :orange_circle: | Compare attribute |
| `ldap-url` | :orange_circle: | Query LDAP URL |
| `nss-getent` | :orange_circle: | Get NSS entry |
| `nss-hosts` | :orange_circle: | Look up host |
| `nss-passwd` | :orange_circle: | Look up user |
| `nss-group` | :orange_circle: | Look up group |

### Round 328 — Auditctl ext, Ausearch ext, Aureport ext, Aulast ext, Autrace ext

| Feature | Status | Notes |
|---------|--------|-------|
| `auditctl-list` | :orange_circle: | List audit rules |
| `auditctl-add` | :orange_circle: | Add audit rule |
| `auditctl-delete` | :orange_circle: | Delete audit rule |
| `auditctl-status` | :orange_circle: | Show audit status |
| `ausearch-event` | :orange_circle: | Search by event ID |
| `ausearch-user` | :orange_circle: | Search by user |
| `ausearch-file` | :orange_circle: | Search by file |
| `ausearch-syscall` | :orange_circle: | Search by syscall |
| `aureport-summary` | :orange_circle: | Show summary report |
| `aureport-auth` | :orange_circle: | Authentication report |
| `aureport-login` | :orange_circle: | Login report |
| `aureport-file` | :orange_circle: | File access report |
| `aulast-show` | :orange_circle: | Show last logins |
| `aulast-user` | :orange_circle: | Last logins by user |
| `aulast-host` | :orange_circle: | Last logins by host |
| `aulast-tty` | :orange_circle: | Last logins by TTY |
| `autrace-run` | :orange_circle: | Trace command |
| `autrace-analyze` | :orange_circle: | Analyze trace |
| `autrace-report` | :orange_circle: | Generate trace report |
| `autrace-delete` | :orange_circle: | Delete trace rules |

### Round 327 — Fstrim ext, Swapctl ext, Inotify ext, Fanotify ext, Dnotify ext

| Feature | Status | Notes |
|---------|--------|-------|
| `fstrim-all` | :orange_circle: | Trim all filesystems |
| `fstrim-device` | :orange_circle: | Trim specific mount |
| `fstrim-dryrun` | :orange_circle: | Dry run trim |
| `fstrim-verbose` | :orange_circle: | Verbose trim |
| `swapon-show` | :orange_circle: | Show swap areas |
| `swapon-enable` | :orange_circle: | Enable swap device |
| `swapoff-disable` | :orange_circle: | Disable swap device |
| `swap-priority` | :orange_circle: | Set swap priority |
| `inotifywait-watch` | :orange_circle: | Watch path |
| `inotifywait-monitor` | :orange_circle: | Monitor path |
| `inotifywait-recursive` | :orange_circle: | Recursive watch |
| `inotifywait-event` | :orange_circle: | Filter events |
| `fanotify-mark` | :orange_circle: | Mark path |
| `fanotify-monitor` | :orange_circle: | Monitor FS events |
| `fanotify-global` | :orange_circle: | Global monitoring |
| `fanotify-permission` | :orange_circle: | Permission events |
| `dnotify-watch` | :orange_circle: | Watch directory |
| `dnotify-recursive` | :orange_circle: | Recursive watch |
| `dnotify-event` | :orange_circle: | Filter event mask |
| `dnotify-background` | :orange_circle: | Background watch |

### Round 326 — Mount ext, Umount ext, Findmnt ext, Lsblk ext, Losetup ext

| Feature | Status | Notes |
|---------|--------|-------|
| `mount-device` | :orange_circle: | Mount device |
| `mount-bind` | :orange_circle: | Bind mount |
| `mount-tmpfs` | :orange_circle: | Mount tmpfs |
| `mount-overlay` | :orange_circle: | Mount overlay |
| `umount-device` | :orange_circle: | Unmount device |
| `umount-lazy` | :orange_circle: | Lazy unmount |
| `umount-force` | :orange_circle: | Force unmount |
| `umount-all` | :orange_circle: | Unmount all |
| `findmnt-show` | :orange_circle: | Show mount table |
| `findmnt-source` | :orange_circle: | Find by source |
| `findmnt-target` | :orange_circle: | Find by target |
| `findmnt-type` | :orange_circle: | Find by type |
| `lsblk-show` | :orange_circle: | Show block devices |
| `lsblk-json` | :orange_circle: | Show as JSON |
| `lsblk-paths` | :orange_circle: | Show full paths |
| `lsblk-discard` | :orange_circle: | Show discard info |
| `losetup-list` | :orange_circle: | List loop devices |
| `losetup-attach` | :orange_circle: | Attach loop device |
| `losetup-detach` | :orange_circle: | Detach loop device |
| `losetup-info` | :orange_circle: | Show loop device info |

### Round 325 — Mkfs ext, Fsck ext, Tune2fs ext, Xfs-admin ext, Resize2fs ext

| Feature | Status | Notes |
|---------|--------|-------|
| `mkfs-vfat` | :orange_circle: | Create VFAT filesystem |
| `mkfs-f2fs` | :orange_circle: | Create F2FS filesystem |
| `mkfs-ntfs` | :orange_circle: | Create NTFS filesystem |
| `mkfs-swap` | :orange_circle: | Create swap space |
| `fsck-check` | :orange_circle: | Check filesystem |
| `fsck-repair` | :orange_circle: | Repair filesystem |
| `fsck-ext4` | :orange_circle: | Check ext4 |
| `fsck-xfs` | :orange_circle: | Check XFS |
| `tune2fs-show` | :orange_circle: | Show ext2/3/4 info |
| `tune2fs-set` | :orange_circle: | Set ext2/3/4 options |
| `tune2fs-journal` | :orange_circle: | Manage journal |
| `tune2fs-label` | :orange_circle: | Set filesystem label |
| `xfs-info` | :orange_circle: | Show XFS info |
| `xfs-repair` | :orange_circle: | Repair XFS |
| `xfs-growfs` | :orange_circle: | Grow XFS filesystem |
| `xfs-freeze` | :orange_circle: | Freeze XFS |
| `resize2fs-grow` | :orange_circle: | Grow ext filesystem |
| `resize2fs-shrink` | :orange_circle: | Shrink ext filesystem |
| `resize2fs-info` | :orange_circle: | Show resize info |
| `resize2fs-check` | :orange_circle: | Check before resize |

### Round 324 — Parted ext, Fdisk ext, Gdisk ext, Sfdisk ext, Blkid ext

| Feature | Status | Notes |
|---------|--------|-------|
| `parted-print` | :orange_circle: | Print partition table |
| `parted-mkpart` | :orange_circle: | Create partition |
| `parted-rm` | :orange_circle: | Remove partition |
| `parted-align` | :orange_circle: | Check alignment |
| `fdisk-info` | :orange_circle: | Show disk info |
| `fdisk-create` | :orange_circle: | Create partition |
| `fdisk-delete` | :orange_circle: | Delete partition |
| `fdisk-type` | :orange_circle: | Set partition type |
| `gdisk-print` | :orange_circle: | Print GPT table |
| `gdisk-create` | :orange_circle: | Create GPT partition |
| `gdisk-delete` | :orange_circle: | Delete GPT partition |
| `gdisk-verify` | :orange_circle: | Verify GPT |
| `sfdisk-dump` | :orange_circle: | Dump partition table |
| `sfdisk-restore` | :orange_circle: | Restore partition table |
| `sfdisk-list` | :orange_circle: | List partitions |
| `sfdisk-delete` | :orange_circle: | Delete partition |
| `blkid-show` | :orange_circle: | Show block devices |
| `blkid-probe` | :orange_circle: | Probe device |
| `blkid-cache` | :orange_circle: | Show blkid cache |
| `blkid-uuid` | :orange_circle: | Look up UUID |

### Round 323 — Grub ext, Efibootmgr ext, Mokutil ext, Sbsign ext, Fwupd ext

| Feature | Status | Notes |
|---------|--------|-------|
| `grub-install` | :orange_circle: | Install GRUB bootloader |
| `grub-mkconfig` | :orange_circle: | Generate GRUB config |
| `grub-editenv` | :orange_circle: | Edit GRUB environment |
| `grub-probe` | :orange_circle: | Probe device info |
| `efibootmgr-list` | :orange_circle: | List EFI boot entries |
| `efibootmgr-create` | :orange_circle: | Create EFI boot entry |
| `efibootmgr-delete` | :orange_circle: | Delete EFI boot entry |
| `efibootmgr-order` | :orange_circle: | Set EFI boot order |
| `mokutil-list` | :orange_circle: | List MOK keys |
| `mokutil-import` | :orange_circle: | Import MOK key |
| `mokutil-enroll` | :orange_circle: | Enroll MOK key |
| `mokutil-status` | :orange_circle: | Show Secure Boot status |
| `sbsign-sign` | :orange_circle: | Sign binary |
| `sbsign-verify` | :orange_circle: | Verify signature |
| `sbsign-hash` | :orange_circle: | Hash binary |
| `sbsign-remove` | :orange_circle: | Remove signature |
| `fwupd-list` | :orange_circle: | List firmware devices |
| `fwupd-update` | :orange_circle: | Update firmware |
| `fwupd-history` | :orange_circle: | Show update history |
| `fwupd-security` | :orange_circle: | Show security attributes |

### Round 322 — Sysctl ext, Procfs ext, Sysfs ext, Devtmpfs ext, Udevadm ext

| Feature | Status | Notes |
|---------|--------|-------|
| `sysctl-show` | :orange_circle: | Show sysctl parameter |
| `sysctl-all` | :orange_circle: | Show all parameters |
| `sysctl-pattern` | :orange_circle: | Match parameters by pattern |
| `sysctl-search` | :orange_circle: | Search parameters |
| `procfs-meminfo` | :orange_circle: | Show /proc/meminfo |
| `procfs-cpuinfo` | :orange_circle: | Show /proc/cpuinfo |
| `procfs-loadavg` | :orange_circle: | Show /proc/loadavg |
| `procfs-mounts` | :orange_circle: | Show /proc/mounts |
| `sysfs-list` | :orange_circle: | List sysfs entries |
| `sysfs-search` | :orange_circle: | Search sysfs attributes |
| `sysfs-attribute` | :orange_circle: | Read sysfs attribute |
| `sysfs-driver` | :orange_circle: | Show driver info |
| `devtmpfs-list` | :orange_circle: | List /dev entries |
| `devtmpfs-create` | :orange_circle: | Create device node |
| `devtmpfs-remove` | :orange_circle: | Remove device node |
| `devtmpfs-permissions` | :orange_circle: | Show device permissions |
| `udevadm-info` | :orange_circle: | Show device info |
| `udevadm-trigger` | :orange_circle: | Trigger udev events |
| `udevadm-settle` | :orange_circle: | Wait for queue to settle |
| `udevadm-monitor` | :orange_circle: | Monitor udev events |

### Round 321 — Kmod ext, Modprobe ext, Dkms ext, Dracut ext, Mkinitcpio ext

| Feature | Status | Notes |
|---------|--------|-------|
| `kmod-list` | :orange_circle: | List loaded modules |
| `kmod-info` | :orange_circle: | Show module info |
| `kmod-load` | :orange_circle: | Load kernel module |
| `kmod-unload` | :orange_circle: | Unload kernel module |
| `modprobe-show` | :orange_circle: | Show module config |
| `modprobe-config` | :orange_circle: | Show modprobe configuration |
| `modprobe-blacklist` | :orange_circle: | Blacklist module |
| `modprobe-dependencies` | :orange_circle: | Show module dependencies |
| `dkms-status` | :orange_circle: | Show DKMS status |
| `dkms-add` | :orange_circle: | Add DKMS module |
| `dkms-build` | :orange_circle: | Build DKMS module |
| `dkms-install` | :orange_circle: | Install DKMS module |
| `dracut-generate` | :orange_circle: | Generate initramfs |
| `dracut-list` | :orange_circle: | List dracut modules |
| `dracut-config` | :orange_circle: | Show dracut config |
| `dracut-rebuild` | :orange_circle: | Rebuild initramfs |
| `mkinitcpio-generate` | :orange_circle: | Generate initramfs |
| `mkinitcpio-list` | :orange_circle: | List hooks |
| `mkinitcpio-preset` | :orange_circle: | Use preset |
| `mkinitcpio-hooks` | :orange_circle: | Show available hooks |

### Round 320 — Bpftool ext, Bpftrace ext, Xdp ext, Tc-bpf ext, Libbpf ext

| Feature | Status | Notes |
|---------|--------|-------|
| `bpftool-prog-list` | :orange_circle: | List BPF programs |
| `bpftool-map-list` | :orange_circle: | List BPF maps |
| `bpftool-link-list` | :orange_circle: | List BPF links |
| `bpftool-net-list` | :orange_circle: | List network BPF programs |
| `bpftrace-list` | :orange_circle: | List available probes |
| `bpftrace-run` | :orange_circle: | Run bpftrace script |
| `bpftrace-oneliner` | :orange_circle: | Run bpftrace one-liner |
| `bpftrace-attach` | :orange_circle: | Attach to probe |
| `xdp-load` | :orange_circle: | Load XDP program |
| `xdp-unload` | :orange_circle: | Unload XDP program |
| `xdp-status` | :orange_circle: | Show XDP status |
| `xdp-stats` | :orange_circle: | Show XDP statistics |
| `tc-bpf-attach` | :orange_circle: | Attach TC BPF program |
| `tc-bpf-detach` | :orange_circle: | Detach TC BPF program |
| `tc-bpf-show` | :orange_circle: | Show TC BPF programs |
| `tc-bpf-list` | :orange_circle: | List all TC BPF programs |
| `libbpf-compile` | :orange_circle: | Compile BPF source |
| `libbpf-load` | :orange_circle: | Load BPF object |
| `libbpf-skeleton` | :orange_circle: | Generate BPF skeleton |
| `libbpf-debug` | :orange_circle: | Debug BPF program |

### Round 319 — Unshare ext, Setns ext, Prlimit ext, Chroot ext, Pivot-root ext

| Feature | Status | Notes |
|---------|--------|-------|
| `unshare-pid` | :orange_circle: | Create PID namespace |
| `unshare-net` | :orange_circle: | Create network namespace |
| `unshare-mount` | :orange_circle: | Create mount namespace |
| `unshare-user` | :orange_circle: | Create user namespace |
| `setns-pid` | :orange_circle: | Join PID namespace |
| `setns-net` | :orange_circle: | Join network namespace |
| `setns-mount` | :orange_circle: | Join mount namespace |
| `setns-user` | :orange_circle: | Join user namespace |
| `prlimit-show` | :orange_circle: | Show process limits |
| `prlimit-set` | :orange_circle: | Set process limits |
| `prlimit-nofile` | :orange_circle: | Set max open files |
| `prlimit-nproc` | :orange_circle: | Set max processes |
| `chroot-enter` | :orange_circle: | Enter chroot |
| `chroot-setup` | :orange_circle: | Set up chroot |
| `chroot-bind` | :orange_circle: | Bind mount in chroot |
| `chroot-copy` | :orange_circle: | Copy file to chroot |
| `pivot-root-new` | :orange_circle: | Set new root |
| `pivot-root-old` | :orange_circle: | Set old root dir |
| `pivot-root-move` | :orange_circle: | Move root filesystem |
| `pivot-root-cleanup` | :orange_circle: | Clean up old root |

### Round 318 — Cgroups ext, Cgroupfs ext, Systemd-cgtop ext, Systemd-run ext, Nsenter ext

| Feature | Status | Notes |
|---------|--------|-------|
| `cgroup-delete` | :orange_circle: | Delete cgroup |
| `cgroup-freeze` | :orange_circle: | Freeze cgroup |
| `cgroup-thaw` | :orange_circle: | Thaw cgroup |
| `cgroup-stat` | :orange_circle: | Show cgroup stats |
| `cgroupfs-mount` | :orange_circle: | Mount cgroup filesystem |
| `cgroupfs-umount` | :orange_circle: | Unmount cgroup filesystem |
| `cgroupfs-list` | :orange_circle: | List cgroup controllers |
| `cgroupfs-info` | :orange_circle: | Show controller info |
| `systemd-cgtop-show` | :orange_circle: | Show control group top |
| `systemd-cgtop-depth` | :orange_circle: | Set cgtop depth |
| `systemd-cgtop-sort` | :orange_circle: | Sort cgtop output |
| `systemd-cgtop-batch` | :orange_circle: | Cgtop batch mode |
| `systemd-run-transient` | :orange_circle: | Run transient unit |
| `systemd-run-scope` | :orange_circle: | Run in scope |
| `systemd-run-slice` | :orange_circle: | Run in slice |
| `systemd-run-shell` | :orange_circle: | Launch shell in unit |
| `nsenter-pid` | :orange_circle: | Enter PID namespace |
| `nsenter-mount` | :orange_circle: | Enter mount namespace |
| `nsenter-net` | :orange_circle: | Enter network namespace |
| `nsenter-user` | :orange_circle: | Enter user namespace |

### Round 317 — Ipmitool ext, Lm-sensors ext, Turbostat ext, Cpupower ext, Numactl ext

| Feature | Status | Notes |
|---------|--------|-------|
| `ipmitool-sensor` | :orange_circle: | List IPMI sensor readings |
| `ipmitool-sdr` | :orange_circle: | Show SDR repository |
| `ipmitool-sel` | :orange_circle: | Show system event log |
| `ipmitool-chassis` | :orange_circle: | Show chassis status |
| `lm-sensors-detect` | :orange_circle: | Detect hardware monitors |
| `lm-sensors-show` | :orange_circle: | Show all sensor readings |
| `lm-sensors-fan` | :orange_circle: | Show fan speeds |
| `lm-sensors-temp` | :orange_circle: | Show temperatures |
| `turbostat-show` | :orange_circle: | Show CPU frequency/power |
| `turbostat-interval` | :orange_circle: | Monitor at interval |
| `turbostat-summary` | :orange_circle: | Show turbostat summary |
| `turbostat-package` | :orange_circle: | Show package stats |
| `cpupower-frequency` | :orange_circle: | Show frequency info |
| `cpupower-info` | :orange_circle: | Show CPU power info |
| `cpupower-governor` | :orange_circle: | Set CPU governor |
| `cpupower-idle` | :orange_circle: | Show idle state info |
| `numactl-show` | :orange_circle: | Show NUMA policy |
| `numactl-hardware` | :orange_circle: | Show NUMA topology |
| `numactl-bind` | :orange_circle: | Bind to NUMA node |
| `numactl-interleave` | :orange_circle: | Interleave across nodes |

### Round 316 — Smartctl ext, Hdparm ext, Sdparm ext, Nvme ext, Fio ext

| Feature | Status | Notes |
|---------|--------|-------|
| `smartctl-attributes` | :orange_circle: | Show SMART attributes |
| `smartctl-capabilities` | :orange_circle: | Show SMART capabilities |
| `smartctl-error-log` | :orange_circle: | Show SMART error log |
| `smartctl-selftest` | :orange_circle: | Run SMART self-test |
| `hdparm-settings` | :orange_circle: | Show drive settings |
| `hdparm-security` | :orange_circle: | Show drive security |
| `hdparm-acoustic` | :orange_circle: | Acoustic management |
| `hdparm-readonly` | :orange_circle: | Toggle read-only mode |
| `sdparm-inquiry` | :orange_circle: | SCSI device inquiry |
| `sdparm-list` | :orange_circle: | List SCSI parameters |
| `sdparm-set` | :orange_circle: | Set SCSI parameter |
| `sdparm-get` | :orange_circle: | Get SCSI parameter |
| `nvme-list` | :orange_circle: | List NVMe devices |
| `nvme-smart` | :orange_circle: | Show NVMe SMART log |
| `nvme-identify` | :orange_circle: | Identify NVMe device |
| `nvme-format` | :orange_circle: | Format NVMe device |
| `fio-run` | :orange_circle: | Run fio benchmark |
| `fio-parse` | :orange_circle: | Parse fio output |
| `fio-generate` | :orange_circle: | Generate fio job file |
| `fio-compare` | :orange_circle: | Compare fio results |

### Round 315 — Sysstat ext, Iostat ext, Sar ext, Pidstat ext, Mpstat ext

| Feature | Status | Notes |
|---------|--------|-------|
| `sysstat-collect` | :orange_circle: | Collect system activity data |
| `sysstat-summary` | :orange_circle: | Show sysstat summary |
| `sysstat-graph` | :orange_circle: | Generate sysstat graph |
| `sysstat-report` | :orange_circle: | Generate sysstat report |
| `iostat-show` | :orange_circle: | Show I/O statistics |
| `iostat-extended` | :orange_circle: | Show extended I/O stats |
| `iostat-device` | :orange_circle: | Show device I/O stats |
| `iostat-cpu` | :orange_circle: | Show CPU utilization |
| `sar-cpu` | :orange_circle: | Show CPU usage history |
| `sar-memory` | :orange_circle: | Show memory usage history |
| `sar-disk` | :orange_circle: | Show disk activity history |
| `sar-network` | :orange_circle: | Show network stats history |
| `pidstat-show` | :orange_circle: | Show process statistics |
| `pidstat-cpu` | :orange_circle: | Show process CPU stats |
| `pidstat-memory` | :orange_circle: | Show process memory stats |
| `pidstat-io` | :orange_circle: | Show process I/O stats |
| `tapestat-show` | :orange_circle: | Show tape statistics |
| `tapestat-extended` | :orange_circle: | Show extended tape stats |
| `mpstat-show` | :orange_circle: | Show processor statistics |
| `mpstat-per-cpu` | :orange_circle: | Show per-CPU statistics |

### Round 314 — LVM ext, MDADM ext, Cryptsetup ext, Dmsetup ext, Multipath ext

| Feature | Status | Notes |
|---------|--------|-------|
| `lvm-pvdisplay` | :orange_circle: | Display physical volumes |
| `lvm-vgdisplay` | :orange_circle: | Display volume groups |
| `lvm-lvdisplay` | :orange_circle: | Display logical volumes |
| `lvm-lvcreate` | :orange_circle: | Create logical volume |
| `mdadm-detail` | :orange_circle: | Show RAID array detail |
| `mdadm-examine` | :orange_circle: | Examine RAID device |
| `mdadm-assemble` | :orange_circle: | Assemble RAID array |
| `mdadm-monitor` | :orange_circle: | Monitor RAID arrays |
| `cryptsetup-status` | :orange_circle: | Show LUKS status |
| `cryptsetup-open` | :orange_circle: | Open encrypted device |
| `cryptsetup-close` | :orange_circle: | Close encrypted device |
| `cryptsetup-luksdump` | :orange_circle: | Dump LUKS header |
| `dmsetup-table` | :orange_circle: | Show device-mapper table |
| `dmsetup-info` | :orange_circle: | Show device-mapper info |
| `dmsetup-status` | :orange_circle: | Show device-mapper status |
| `dmsetup-ls` | :orange_circle: | List device-mapper devices |
| `multipath-show` | :orange_circle: | Show multipath topology |
| `multipath-flush` | :orange_circle: | Flush multipath map |
| `multipath-resize` | :orange_circle: | Resize multipath map |
| `multipath-list` | :orange_circle: | List multipath maps |

### Round 313 — Nftables ext, Iproute2 ext, Ethtool ext, Btrfs ext, Zfs ext

| Feature | Status | Notes |
|---------|--------|-------|
| `nft-list-ruleset` | :orange_circle: | List nftables ruleset |
| `nft-add-rule` | :orange_circle: | Add nftables rule |
| `nft-delete-rule` | :orange_circle: | Delete nftables rule |
| `nft-flush-ruleset` | :orange_circle: | Flush nftables ruleset |
| `ip-rule-show` | :orange_circle: | Show routing rules |
| `ip-tunnel-show` | :orange_circle: | Show tunnels |
| `ip-maddr-show` | :orange_circle: | Show multicast addresses |
| `ip-neigh-show` | :orange_circle: | Show neighbor table |
| `ethtool-show` | :orange_circle: | Show interface settings |
| `ethtool-features` | :orange_circle: | Show interface features |
| `ethtool-driver` | :orange_circle: | Show driver info |
| `ethtool-pause` | :orange_circle: | Show pause parameters |
| `btrfs-subvolume-list` | :orange_circle: | List btrfs subvolumes |
| `btrfs-subvolume-create` | :orange_circle: | Create btrfs subvolume |
| `btrfs-subvolume-delete` | :orange_circle: | Delete btrfs subvolume |
| `btrfs-filesystem-show` | :orange_circle: | Show btrfs filesystem info |
| `zfs-send` | :orange_circle: | Send ZFS snapshot |
| `zfs-receive` | :orange_circle: | Receive ZFS dataset |
| `zfs-get` | :orange_circle: | Get ZFS properties |
| `zfs-set` | :orange_circle: | Set ZFS property |

### Round 312 — Resolvectl ext, Bootctl ext, Homectl ext, Oomctl ext, Systemd-analyze ext

| Feature | Status | Notes |
|---------|--------|-------|
| `resolvectl-monitor` | :orange_circle: | Monitor DNS resolutions |
| `resolvectl-log-level` | :orange_circle: | Set resolver log level |
| `resolvectl-reset` | :orange_circle: | Reset server features |
| `bootctl-status` | :orange_circle: | Show boot loader status |
| `bootctl-list` | :orange_circle: | List boot entries |
| `bootctl-install` | :orange_circle: | Install boot loader |
| `bootctl-update` | :orange_circle: | Update boot loader |
| `homectl-list` | :orange_circle: | List home directories |
| `homectl-create` | :orange_circle: | Create home directory |
| `homectl-remove` | :orange_circle: | Remove home directory |
| `homectl-inspect` | :orange_circle: | Inspect home directory |
| `oomctl-dump` | :orange_circle: | Dump OOM killer state |
| `oomctl-status` | :orange_circle: | Show systemd-oomd status |
| `systemd-analyze-blame` | :orange_circle: | Show unit startup blame |
| `systemd-analyze-critical` | :orange_circle: | Show critical chain |
| `systemd-analyze-plot` | :orange_circle: | Generate boot plot |
| `systemd-analyze-dot` | :orange_circle: | Generate dependency graph |
| `systemd-analyze-security` | :orange_circle: | Security audit unit |
| `systemd-analyze-unit` | :orange_circle: | Show unit paths |
| `systemd-analyze-verify` | :orange_circle: | Verify unit file |

### Round 311 — Coredumpctl ext, Busctl ext, Networkctl ext, Portablectl ext, Userdbctl ext

| Feature | Status | Notes |
|---------|--------|-------|
| `coredumpctl-list` | :orange_circle: | List coredumps |
| `coredumpctl-info` | :orange_circle: | Show coredump info |
| `coredumpctl-dump` | :orange_circle: | Extract coredump |
| `coredumpctl-gdb` | :orange_circle: | Debug coredump with GDB |
| `busctl-list` | :orange_circle: | List D-Bus services |
| `busctl-monitor` | :orange_circle: | Monitor D-Bus traffic |
| `busctl-call` | :orange_circle: | Call D-Bus method |
| `busctl-introspect` | :orange_circle: | Introspect D-Bus object |
| `networkctl-list` | :orange_circle: | List network links |
| `networkctl-status` | :orange_circle: | Show network status |
| `networkctl-up` | :orange_circle: | Bring interface up |
| `networkctl-down` | :orange_circle: | Bring interface down |
| `portablectl-list` | :orange_circle: | List portable services |
| `portablectl-attach` | :orange_circle: | Attach portable image |
| `portablectl-detach` | :orange_circle: | Detach portable image |
| `portablectl-inspect` | :orange_circle: | Inspect portable image |
| `userdbctl-user` | :orange_circle: | Show user info |
| `userdbctl-group` | :orange_circle: | Show group info |
| `userdbctl-members` | :orange_circle: | List group members |
| `userdbctl-services` | :orange_circle: | List userdb services |

### Round 310 — Loginctl ext, Machinectl ext, Hostnamectl ext, Timedatectl ext, Localectl ext

| Command | Status | Description |
|---------|--------|-------------|
| loginctl-list | :orange_circle: | List login sessions |
| loginctl-user | :orange_circle: | Show user info |
| loginctl-session | :orange_circle: | Show session info |
| loginctl-seat | :orange_circle: | List seats |
| machinectl-list | :orange_circle: | List machines |
| machinectl-login | :orange_circle: | Login to machine |
| machinectl-start | :orange_circle: | Start machine |
| machinectl-stop | :orange_circle: | Stop machine |
| hostnamectl-show | :orange_circle: | Show hostname info |
| hostnamectl-set | :orange_circle: | Set hostname |
| hostnamectl-icon | :orange_circle: | Set icon name |
| hostnamectl-chassis | :orange_circle: | Set chassis type |
| timedatectl-show | :orange_circle: | Show time/date |
| timedatectl-set | :orange_circle: | Set time/date |
| timedatectl-ntp | :orange_circle: | Toggle NTP |
| timedatectl-timezone | :orange_circle: | Set timezone |
| localectl-status | :orange_circle: | Show locale status |
| localectl-set-locale | :orange_circle: | Set locale |
| localectl-set-keymap | :orange_circle: | Set keymap |
| localectl-list-keymaps | :orange_circle: | List keymaps |

### Round 309 — Power Profiles ext, CPUFreq ext, Thermal ext, TLP ext, PowerTOP ext

| Command | Status | Description |
|---------|--------|-------------|
| power-profiles | :orange_circle: | List power profiles |
| power-save | :orange_circle: | Switch to power-save |
| power-balance | :orange_circle: | Switch to balanced |
| power-performance | :orange_circle: | Switch to performance |
| cpufreq-info | :orange_circle: | Show CPU freq info |
| cpufreq-set | :orange_circle: | Set CPU frequency |
| cpufreq-governor | :orange_circle: | Set CPU governor |
| cpufreq-policy | :orange_circle: | Show CPU policy |
| thermald-status | :orange_circle: | Show thermald status |
| thermald-config | :orange_circle: | View thermald config |
| thermal-zones | :orange_circle: | List thermal zones |
| thermal-cooling | :orange_circle: | List cooling devices |
| tlp-status | :orange_circle: | Show TLP status |
| tlp-config | :orange_circle: | View TLP config |
| tlp-stats | :orange_circle: | Show TLP stats |
| tlp-bat | :orange_circle: | Battery info |
| powertop-report | :orange_circle: | Generate report |
| powertop-auto | :orange_circle: | Auto-tune power |
| powertop-calibrate | :orange_circle: | Calibrate |
| powertop-html | :orange_circle: | HTML report |

### Round 308 — CUPS ext, Lp ext, Avahi ext, Resolvectl ext, Ethtool ext

| Command | Status | Description |
|---------|--------|-------------|
| cups-list | :orange_circle: | List printers |
| cups-add | :orange_circle: | Add printer |
| cups-remove | :orange_circle: | Remove printer |
| cups-status | :orange_circle: | Show CUPS status |
| lp-print | :orange_circle: | Print file |
| lp-queue | :orange_circle: | Show print queue |
| lp-cancel | :orange_circle: | Cancel print job |
| lp-status | :orange_circle: | Printer status |
| avahi-browse | :orange_circle: | Browse mDNS services |
| avahi-resolve | :orange_circle: | Resolve hostname |
| avahi-publish | :orange_circle: | Publish service |
| avahi-daemon | :orange_circle: | Daemon status |
| resolvectl-status | :orange_circle: | DNS resolver status |
| resolvectl-query | :orange_circle: | Query DNS |
| resolvectl-flush | :orange_circle: | Flush DNS cache |
| resolvectl-statistics | :orange_circle: | DNS statistics |
| ethtool-info | :orange_circle: | Show NIC info |
| ethtool-stats | :orange_circle: | Show NIC stats |
| ethtool-speed | :orange_circle: | Show NIC speed |
| ethtool-ring | :orange_circle: | Show ring params |

### Round 307 — NetworkManager ext, Nmcli ext, WPA Supplicant ext, Iw ext, Hostapd ext

| Command | Status | Description |
|---------|--------|-------------|
| networkmanager-list | :orange_circle: | List NM connections |
| networkmanager-connect | :orange_circle: | Connect NM |
| networkmanager-disconnect | :orange_circle: | Disconnect NM |
| networkmanager-wifi-scan | :orange_circle: | Scan WiFi |
| nmcli-device | :orange_circle: | List nmcli devices |
| nmcli-connection | :orange_circle: | List nmcli connections |
| nmcli-general | :orange_circle: | Nmcli general status |
| nmcli-radio | :orange_circle: | Nmcli radio status |
| wpa-supplicant-scan | :orange_circle: | WPA scan networks |
| wpa-supplicant-connect | :orange_circle: | WPA connect |
| wpa-supplicant-status | :orange_circle: | WPA status |
| wpa-supplicant-disconnect | :orange_circle: | WPA disconnect |
| iw-scan | :orange_circle: | Iw WiFi scan |
| iw-link | :orange_circle: | Iw link status |
| iw-info | :orange_circle: | Iw interface info |
| iw-station | :orange_circle: | Iw station info |
| hostapd-start | :orange_circle: | Start hostapd |
| hostapd-stop | :orange_circle: | Stop hostapd |
| hostapd-status | :orange_circle: | Show hostapd status |
| hostapd-config | :orange_circle: | View hostapd config |

### Round 306 — PulseAudio ext, PipeWire ext, ALSA ext, JACK ext, Bluez ext

| Command | Status | Description |
|---------|--------|-------------|
| pulseaudio-list | :orange_circle: | List audio sinks/sources |
| pulseaudio-volume | :orange_circle: | Set PulseAudio volume |
| pulseaudio-mute | :orange_circle: | Toggle PulseAudio mute |
| pulseaudio-default | :orange_circle: | Set default sink |
| pipewire-list | :orange_circle: | List PipeWire nodes |
| pipewire-info | :orange_circle: | Show node info |
| pipewire-link | :orange_circle: | Link PipeWire nodes |
| pipewire-unlink | :orange_circle: | Unlink PipeWire nodes |
| alsa-list | :orange_circle: | List ALSA cards |
| alsa-volume | :orange_circle: | Set ALSA volume |
| alsa-mute | :orange_circle: | Toggle ALSA mute |
| alsa-card | :orange_circle: | Show card info |
| jack-list | :orange_circle: | List JACK ports |
| jack-connect | :orange_circle: | Connect JACK ports |
| jack-disconnect | :orange_circle: | Disconnect JACK port |
| jack-monitor | :orange_circle: | Monitor JACK |
| bluez-list | :orange_circle: | List Bluetooth devices |
| bluez-pair | :orange_circle: | Pair device |
| bluez-connect | :orange_circle: | Connect device |
| bluez-disconnect | :orange_circle: | Disconnect device |

### Round 305 — Xrandr ext, Xinput ext, Xdotool ext, Xset ext, Xmodmap ext

| Command | Status | Description |
|---------|--------|-------------|
| xrandr-list | :orange_circle: | List display outputs |
| xrandr-mode | :orange_circle: | Set display mode |
| xrandr-rotate | :orange_circle: | Rotate display |
| xrandr-brightness | :orange_circle: | Set brightness |
| xrandr-primary | :orange_circle: | Set primary output |
| xinput-list | :orange_circle: | List input devices |
| xinput-enable | :orange_circle: | Enable input device |
| xinput-disable | :orange_circle: | Disable input device |
| xinput-props | :orange_circle: | Show device properties |
| xdotool-key | :orange_circle: | Send key event |
| xdotool-type | :orange_circle: | Type text |
| xdotool-click | :orange_circle: | Click mouse button |
| xdotool-move | :orange_circle: | Move mouse |
| xset-dpms | :orange_circle: | Toggle DPMS |
| xset-bell | :orange_circle: | Set bell volume |
| xset-rate | :orange_circle: | Set key rate |
| xset-font | :orange_circle: | Set font path |
| xmodmap-list | :orange_circle: | List key mappings |
| xmodmap-load | :orange_circle: | Load key map |
| xmodmap-expr | :orange_circle: | Run xmodmap expression |

### Round 304 — Polkit ext, DBus ext, Udev ext, Tmpfiles ext, Sysfs ext

| Command | Status | Description |
|---------|--------|-------------|
| polkit-list | :orange_circle: | List polkit actions |
| polkit-action | :orange_circle: | Show polkit action |
| polkit-authority | :orange_circle: | Show authority |
| polkit-check | :orange_circle: | Check authorization |
| dbus-list | :orange_circle: | List DBus services |
| dbus-monitor | :orange_circle: | Monitor DBus |
| dbus-call | :orange_circle: | Call DBus method |
| dbus-introspect | :orange_circle: | Introspect service |
| udev-monitor | :orange_circle: | Monitor udev events |
| udev-info | :orange_circle: | Show device info |
| udev-trigger | :orange_circle: | Trigger udev events |
| udev-settle | :orange_circle: | Wait for udev settle |
| udev-rule-add | :orange_circle: | Add udev rule |
| udev-rule-remove | :orange_circle: | Remove udev rule |
| tmpfiles-create | :orange_circle: | Create tmpfiles |
| tmpfiles-clean | :orange_circle: | Clean tmpfiles |
| tmpfiles-remove | :orange_circle: | Remove tmpfiles |
| tmpfiles-list | :orange_circle: | List tmpfiles config |
| sysfs-read | :orange_circle: | Read /sys entry |
| sysfs-write | :orange_circle: | Write /sys entry |

### Round 303 — XDG ext, Dconf ext, GSettings ext, GConf ext, Alternatives ext

| Command | Status | Description |
|---------|--------|-------------|
| xdg-open | :orange_circle: | Open with default app |
| xdg-mime | :orange_circle: | Query MIME type |
| xdg-settings | :orange_circle: | Show XDG settings |
| xdg-desktop | :orange_circle: | Show desktop dirs |
| xdg-icon | :orange_circle: | Find icon |
| xdg-menu | :orange_circle: | Show menu entries |
| dconf-list | :orange_circle: | List dconf keys |
| dconf-read | :orange_circle: | Read dconf value |
| dconf-write | :orange_circle: | Write dconf value |
| dconf-reset | :orange_circle: | Reset dconf key |
| gsettings-list | :orange_circle: | List gsettings |
| gsettings-get | :orange_circle: | Get gsettings value |
| gsettings-set | :orange_circle: | Set gsettings value |
| gsettings-reset | :orange_circle: | Reset gsettings |
| gconf-list | :orange_circle: | List gconf keys |
| gconf-get | :orange_circle: | Get gconf value |
| gconf-set | :orange_circle: | Set gconf value |
| gconf-unset | :orange_circle: | Unset gconf key |
| update-alternatives-list | :orange_circle: | List alternatives |
| update-alternatives-set | :orange_circle: | Set alternative |

### Round 302 — COPR ext, DNF ext, Zypper ext, Emerge ext, Portage ext

| Command | Status | Description |
|---------|--------|-------------|
| copr-enable | :orange_circle: | Enable COPR repo |
| copr-disable | :orange_circle: | Disable COPR repo |
| copr-list | :orange_circle: | List COPR repos |
| copr-search | :orange_circle: | Search COPR |
| dnf-install | :orange_circle: | Install DNF package |
| dnf-remove | :orange_circle: | Remove DNF package |
| dnf-update | :orange_circle: | Update all packages |
| dnf-search | :orange_circle: | Search DNF packages |
| zypper-install | :orange_circle: | Install zypper package |
| zypper-remove | :orange_circle: | Remove zypper package |
| zypper-search | :orange_circle: | Search zypper packages |
| zypper-info | :orange_circle: | Show zypper info |
| emerge-install | :orange_circle: | Install emerge package |
| emerge-remove | :orange_circle: | Remove emerge package |
| emerge-search | :orange_circle: | Search emerge packages |
| emerge-info | :orange_circle: | Show emerge info |
| portage-sync | :orange_circle: | Sync portage tree |
| portage-world | :orange_circle: | Update world set |
| portage-depclean | :orange_circle: | Clean dependencies |
| portage-info | :orange_circle: | Show portage info |

### Round 301 — Snap ext, Flatpak ext, AppImage ext, Nix ext, Brew ext

| Command | Status | Description |
|---------|--------|-------------|
| snap-list | :orange_circle: | List installed snaps |
| snap-install | :orange_circle: | Install snap |
| snap-remove | :orange_circle: | Remove snap |
| snap-info | :orange_circle: | Show snap info |
| flatpak-list | :orange_circle: | List flatpak apps |
| flatpak-install | :orange_circle: | Install flatpak |
| flatpak-remove | :orange_circle: | Remove flatpak |
| flatpak-info | :orange_circle: | Show flatpak info |
| appimage-run | :orange_circle: | Run AppImage |
| appimage-extract | :orange_circle: | Extract AppImage |
| appimage-info | :orange_circle: | Show AppImage info |
| appimage-update | :orange_circle: | Update AppImage |
| nix-install | :orange_circle: | Install nix package |
| nix-remove | :orange_circle: | Remove nix package |
| nix-info | :orange_circle: | Show nix package info |
| nix-profile | :orange_circle: | Show nix profile |
| brew-search | :orange_circle: | Search brew packages |
| brew-install | :orange_circle: | Install brew formula |
| brew-remove | :orange_circle: | Remove brew formula |
| brew-info | :orange_circle: | Show brew info |

### Round 300 — Dpkg ext, Apt ext, RPM ext, Yum ext, Pacman ext

| Command | Status | Description |
|---------|--------|-------------|
| dpkg-list | :orange_circle: | List installed packages |
| dpkg-install | :orange_circle: | Install deb package |
| dpkg-remove | :orange_circle: | Remove deb package |
| dpkg-info | :orange_circle: | Show package info |
| apt-show | :orange_circle: | Show apt package |
| apt-depends | :orange_circle: | Show dependencies |
| apt-rdepends | :orange_circle: | Show reverse deps |
| apt-policy | :orange_circle: | Show apt policy |
| rpm-list | :orange_circle: | List RPM packages |
| rpm-install | :orange_circle: | Install RPM package |
| rpm-remove | :orange_circle: | Remove RPM package |
| rpm-info | :orange_circle: | Show RPM info |
| yum-search | :orange_circle: | Search yum packages |
| yum-info | :orange_circle: | Show yum package info |
| yum-depends | :orange_circle: | Show yum deps |
| yum-history | :orange_circle: | Show yum history |
| pacman-search | :orange_circle: | Search pacman packages |
| pacman-info | :orange_circle: | Show pacman info |
| pacman-files | :orange_circle: | List package files |
| pacman-orphans | :orange_circle: | List orphaned packages |

### Round 299 — Ar ext, Pkg-config ext, Ldconfig ext, Locale ext, Timezone ext

| Command | Status | Description |
|---------|--------|-------------|
| ar-create | :orange_circle: | Create archive |
| ar-extract | :orange_circle: | Extract archive |
| ar-list | :orange_circle: | List archive contents |
| ar-add | :orange_circle: | Add to archive |
| ranlib-index | :orange_circle: | Index archive |
| pkg-config-list | :orange_circle: | List packages |
| pkg-config-cflags | :orange_circle: | Show cflags |
| pkg-config-libs | :orange_circle: | Show libs |
| pkg-config-modversion | :orange_circle: | Show version |
| ldconfig-list | :orange_circle: | List libraries |
| ldconfig-rebuild | :orange_circle: | Rebuild cache |
| ldconfig-cache | :orange_circle: | Show cache |
| ldconfig-print | :orange_circle: | Print library path |
| locale-list | :orange_circle: | List locales |
| locale-gen | :orange_circle: | Generate locale |
| locale-set | :orange_circle: | Set locale |
| locale-info | :orange_circle: | Show locale info |
| timezone-list | :orange_circle: | List timezones |
| timezone-set | :orange_circle: | Set timezone |
| timezone-info | :orange_circle: | Show timezone info |

### Round 298 — Objdump ext, Readelf ext, Nm ext, Ldd ext, Strip ext

| Command | Status | Description |
|---------|--------|-------------|
| objdump-disasm | :orange_circle: | Disassemble binary |
| objdump-headers | :orange_circle: | Show binary headers |
| objdump-symbols | :orange_circle: | Show binary symbols |
| objdump-reloc | :orange_circle: | Show relocations |
| readelf-headers | :orange_circle: | Show ELF headers |
| readelf-sections | :orange_circle: | Show ELF sections |
| readelf-symbols | :orange_circle: | Show ELF symbols |
| readelf-dynamic | :orange_circle: | Show dynamic section |
| nm-list | :orange_circle: | List symbols |
| nm-defined | :orange_circle: | Show defined symbols |
| nm-undefined | :orange_circle: | Show undefined symbols |
| nm-sort | :orange_circle: | Sort symbols by size |
| ldd-check | :orange_circle: | Check shared libs |
| ldd-tree | :orange_circle: | Show dependency tree |
| ldd-unused | :orange_circle: | Find unused deps |
| ldd-all | :orange_circle: | Show all deps |
| strip-binary | :orange_circle: | Strip binary |
| strip-debug | :orange_circle: | Strip debug info |
| strip-symbols | :orange_circle: | Strip symbols |
| strip-all | :orange_circle: | Strip everything |

### Round 297 — Strace ext, Ltrace ext, Perf ext, Valgrind ext, GDB ext

| Command | Status | Description |
|---------|--------|-------------|
| strace-attach | :orange_circle: | Attach strace to PID |
| strace-run | :orange_circle: | Run command under strace |
| strace-filter | :orange_circle: | Filter strace syscalls |
| strace-count | :orange_circle: | Count syscalls |
| ltrace-attach | :orange_circle: | Attach ltrace to PID |
| ltrace-run | :orange_circle: | Run command under ltrace |
| ltrace-filter | :orange_circle: | Filter ltrace calls |
| ltrace-library | :orange_circle: | Trace specific library |
| perf-stat | :orange_circle: | Perf stat counters |
| perf-record | :orange_circle: | Record perf data |
| perf-report | :orange_circle: | Show perf report |
| perf-top | :orange_circle: | Live perf profiling |
| valgrind-memcheck | :orange_circle: | Valgrind memcheck |
| valgrind-callgrind | :orange_circle: | Valgrind callgrind |
| valgrind-cachegrind | :orange_circle: | Valgrind cachegrind |
| valgrind-massif | :orange_circle: | Valgrind massif |
| gdb-attach | :orange_circle: | Attach GDB to PID |
| gdb-run | :orange_circle: | Run program in GDB |
| gdb-backtrace | :orange_circle: | Show GDB backtrace |
| gdb-breakpoint | :orange_circle: | Set GDB breakpoint |

### Round 296 — Tcpdump ext, Tshark ext, Iftop ext, Nethogs ext, Vnstat ext, Iperf3 ext

| Command | Status | Description |
|---------|--------|-------------|
| tcpdump-capture | :orange_circle: | Tcpdump capture |
| tcpdump-filter | :orange_circle: | Set tcpdump filter |
| tcpdump-read | :orange_circle: | Read PCAP file |
| tcpdump-write | :orange_circle: | Write PCAP file |
| tshark-capture | :orange_circle: | Tshark capture |
| tshark-filter | :orange_circle: | Set tshark filter |
| tshark-decode | :orange_circle: | Decode PCAP |
| tshark-stats | :orange_circle: | Show tshark stats |
| iftop-monitor | :orange_circle: | Monitor bandwidth |
| iftop-interface | :orange_circle: | Monitor interface |
| nethogs-monitor | :orange_circle: | Per-process bandwidth |
| nethogs-pid | :orange_circle: | Monitor PID bandwidth |
| bmon-monitor | :orange_circle: | Bmon bandwidth monitor |
| bmon-interface | :orange_circle: | Bmon interface monitor |
| vnstat-show | :orange_circle: | Show traffic summary |
| vnstat-daily | :orange_circle: | Daily traffic stats |
| vnstat-monthly | :orange_circle: | Monthly traffic stats |
| vnstat-live | :orange_circle: | Live traffic monitor |
| iperf3-server | :orange_circle: | Start iperf3 server |
| iperf3-client | :orange_circle: | Run iperf3 client |

### Round 295 — Nmap ext, Masscan ext, Zmap ext, Netcat ext, Socat ext

| Command | Status | Description |
|---------|--------|-------------|
| nmap-scan | :orange_circle: | Nmap port scan |
| nmap-service | :orange_circle: | Nmap service detection |
| nmap-os | :orange_circle: | Nmap OS detection |
| nmap-vuln | :orange_circle: | Nmap vulnerability scan |
| masscan-scan | :orange_circle: | Masscan scan |
| masscan-rate | :orange_circle: | Set Masscan rate |
| masscan-ports | :orange_circle: | Set Masscan ports |
| masscan-output | :orange_circle: | Set Masscan output |
| zmap-scan | :orange_circle: | Zmap scan |
| zmap-probe | :orange_circle: | Set Zmap probe |
| zmap-output | :orange_circle: | Set Zmap output |
| zmap-bandwidth | :orange_circle: | Set Zmap bandwidth |
| netcat-listen | :orange_circle: | Netcat listen |
| netcat-connect | :orange_circle: | Netcat connect |
| netcat-scan | :orange_circle: | Netcat port scan |
| netcat-transfer | :orange_circle: | Netcat file transfer |
| socat-listen | :orange_circle: | Socat listen |
| socat-connect | :orange_circle: | Socat connect |
| socat-proxy | :orange_circle: | Socat proxy |
| socat-relay | :orange_circle: | Socat relay |

### Round 294 — OpenVPN ext, StrongSwan ext, IPsec ext, PPTP ext, L2TP ext

| Command | Status | Description |
|---------|--------|-------------|
| openvpn-start | :orange_circle: | Start OpenVPN |
| openvpn-stop | :orange_circle: | Stop OpenVPN |
| openvpn-status | :orange_circle: | Show OpenVPN status |
| openvpn-config | :orange_circle: | View OpenVPN config |
| strongswan-start | :orange_circle: | Start StrongSwan |
| strongswan-stop | :orange_circle: | Stop StrongSwan |
| strongswan-status | :orange_circle: | Show StrongSwan status |
| strongswan-reload | :orange_circle: | Reload StrongSwan |
| ipsec-status | :orange_circle: | Show IPsec status |
| ipsec-up | :orange_circle: | Bring up IPsec conn |
| ipsec-down | :orange_circle: | Bring down IPsec conn |
| ipsec-list | :orange_circle: | List IPsec SAs |
| pptp-connect | :orange_circle: | Connect PPTP |
| pptp-disconnect | :orange_circle: | Disconnect PPTP |
| pptp-status | :orange_circle: | Show PPTP status |
| l2tp-connect | :orange_circle: | Connect L2TP |
| l2tp-disconnect | :orange_circle: | Disconnect L2TP |
| l2tp-status | :orange_circle: | Show L2TP status |
| l2tp-tunnel-list | :orange_circle: | List L2TP tunnels |
| l2tp-session-list | :orange_circle: | List L2TP sessions |

### Round 293 — VLAN ext, Bond ext, MacVLAN ext, VXLAN ext, WireGuard ext

| Command | Status | Description |
|---------|--------|-------------|
| vlan-list | :orange_circle: | List VLANs |
| vlan-add | :orange_circle: | Add VLAN |
| vlan-remove | :orange_circle: | Remove VLAN |
| vlan-info | :orange_circle: | Show VLAN info |
| bond-list | :orange_circle: | List bond interfaces |
| bond-create | :orange_circle: | Create bond |
| bond-add-slave | :orange_circle: | Add bond slave |
| bond-remove-slave | :orange_circle: | Remove bond slave |
| macvlan-create | :orange_circle: | Create MacVLAN |
| macvlan-delete | :orange_circle: | Delete MacVLAN |
| ipvlan-create | :orange_circle: | Create IPVLAN |
| ipvlan-delete | :orange_circle: | Delete IPVLAN |
| vxlan-create | :orange_circle: | Create VXLAN tunnel |
| vxlan-delete | :orange_circle: | Delete VXLAN tunnel |
| vxlan-list | :orange_circle: | List VXLAN tunnels |
| wireguard-genkey | :orange_circle: | Generate WireGuard key |
| wireguard-show | :orange_circle: | Show WireGuard interfaces |
| wireguard-peer-add | :orange_circle: | Add WireGuard peer |
| wireguard-peer-remove | :orange_circle: | Remove WireGuard peer |
| wireguard-status | :orange_circle: | Show WireGuard status |

### Round 292 — TC ext, IP Rule ext, IP Route ext, IP Link ext, Bridge ext

| Command | Status | Description |
|---------|--------|-------------|
| tc-qdisc-list | :orange_circle: | List TC qdiscs |
| tc-qdisc-add | :orange_circle: | Add TC qdisc |
| tc-class-list | :orange_circle: | List TC classes |
| tc-class-add | :orange_circle: | Add TC class |
| tc-filter-list | :orange_circle: | List TC filters |
| tc-filter-add | :orange_circle: | Add TC filter |
| ip-rule-list | :orange_circle: | List IP rules |
| ip-rule-add | :orange_circle: | Add IP rule |
| ip-route-show | :orange_circle: | Show IP routes |
| ip-route-add | :orange_circle: | Add IP route |
| ip-neigh-list | :orange_circle: | List IP neighbors |
| ip-neigh-flush | :orange_circle: | Flush neighbor cache |
| ip-link-show | :orange_circle: | Show network links |
| ip-link-set | :orange_circle: | Set link properties |
| ip-addr-show | :orange_circle: | Show IP addresses |
| ip-addr-add | :orange_circle: | Add IP address |
| bridge-list | :orange_circle: | List bridges |
| bridge-add | :orange_circle: | Create bridge |
| bridge-fdb | :orange_circle: | Show bridge FDB |
| bridge-vlan | :orange_circle: | Show bridge VLANs |

### Round 291 — SMART ext, Hdparm ext, Blkid ext, Fdisk ext, Mkfs ext

| Command | Status | Description |
|---------|--------|-------------|
| smartctl-info | :orange_circle: | Show SMART info |
| smartctl-test | :orange_circle: | Run SMART test |
| smartctl-health | :orange_circle: | Check disk health |
| smartctl-log | :orange_circle: | Show SMART log |
| hdparm-info | :orange_circle: | Show disk parameters |
| hdparm-benchmark | :orange_circle: | Benchmark disk |
| hdparm-power | :orange_circle: | Disk power management |
| hdparm-cache | :orange_circle: | Disk cache settings |
| blkid-list | :orange_circle: | List block devices |
| blkid-info | :orange_circle: | Show device info |
| lsblk-tree | :orange_circle: | Tree view of devices |
| lsblk-detail | :orange_circle: | Detailed device list |
| fdisk-list | :orange_circle: | List partitions |
| fdisk-partition | :orange_circle: | Partition device |
| parted-list | :orange_circle: | List partitions (parted) |
| parted-resize | :orange_circle: | Resize partition |
| mkfs-ext4 | :orange_circle: | Create ext4 filesystem |
| mkfs-xfs | :orange_circle: | Create XFS filesystem |
| mkfs-btrfs | :orange_circle: | Create Btrfs filesystem |
| tune2fs-info | :orange_circle: | Show ext filesystem info |

### Round 290 — Dmesg ext, Kernel Log ext, Modprobe ext, Sysctl ext, Procfs ext

| Command | Status | Description |
|---------|--------|-------------|
| dmesg-filter | :orange_circle: | Filter dmesg output |
| dmesg-follow | :orange_circle: | Follow dmesg live |
| dmesg-clear | :orange_circle: | Clear dmesg buffer |
| dmesg-level | :orange_circle: | Filter by log level |
| kern-log-view | :orange_circle: | View kernel log |
| kern-log-search | :orange_circle: | Search kernel log |
| kern-log-tail | :orange_circle: | Tail kernel log |
| kern-log-level | :orange_circle: | Set kernel log level |
| modprobe-load | :orange_circle: | Load kernel module |
| modprobe-remove | :orange_circle: | Remove kernel module |
| modprobe-list | :orange_circle: | List loaded modules |
| modprobe-info | :orange_circle: | Show module info |
| lsmod-list | :orange_circle: | List kernel modules |
| depmod-rebuild | :orange_circle: | Rebuild module deps |
| sysctl-list | :orange_circle: | List sysctl parameters |
| sysctl-get | :orange_circle: | Get sysctl value |
| sysctl-set | :orange_circle: | Set sysctl value |
| sysctl-reload | :orange_circle: | Reload sysctl config |
| procfs-read | :orange_circle: | Read /proc entry |
| procfs-write | :orange_circle: | Write /proc entry |

### Round 289 — User mgmt ext, Group mgmt ext, Login ext, Faillock ext, Getent ext

| Command | Status | Description |
|---------|--------|-------------|
| useradd-create | :orange_circle: | Create user account |
| userdel-remove | :orange_circle: | Remove user account |
| usermod-modify | :orange_circle: | Modify user account |
| passwd-change | :orange_circle: | Change user password |
| groupadd-create | :orange_circle: | Create group |
| groupdel-remove | :orange_circle: | Remove group |
| groupmod-modify | :orange_circle: | Modify group |
| chage-info | :orange_circle: | Show password aging info |
| chage-set | :orange_circle: | Set password expiry |
| login-list | :orange_circle: | List active sessions |
| login-history | :orange_circle: | Show login history |
| who-list | :orange_circle: | List logged-in users |
| w-list | :orange_circle: | Show user activity |
| last-logins | :orange_circle: | Show recent logins |
| lastb-failures | :orange_circle: | Show failed logins |
| faillock-status | :orange_circle: | Show faillock status |
| faillock-reset | :orange_circle: | Reset faillock |
| getent-passwd | :orange_circle: | Query passwd database |
| getent-group | :orange_circle: | Query group database |
| getent-hosts | :orange_circle: | Query hosts database |

### Round 288 — Cron ext, At ext, Systemd Timer ext, Anacron ext, Incron ext

| Command | Status | Description |
|---------|--------|-------------|
| cron-list | :orange_circle: | List crontab entries |
| cron-add | :orange_circle: | Add cron job |
| cron-remove | :orange_circle: | Remove cron job |
| cron-edit | :orange_circle: | Edit crontab |
| at-schedule | :orange_circle: | Schedule at job |
| at-list | :orange_circle: | List pending at jobs |
| at-remove | :orange_circle: | Remove at job |
| at-view | :orange_circle: | View at job details |
| systemd-timer-list | :orange_circle: | List systemd timers |
| systemd-timer-create | :orange_circle: | Create systemd timer |
| systemd-timer-enable | :orange_circle: | Enable systemd timer |
| systemd-timer-disable | :orange_circle: | Disable systemd timer |
| anacron-list | :orange_circle: | List anacron jobs |
| anacron-run | :orange_circle: | Run pending anacron jobs |
| anacron-config | :orange_circle: | View anacron config |
| anacron-status | :orange_circle: | Show anacron status |
| incron-list | :orange_circle: | List incron watches |
| incron-add | :orange_circle: | Add incron watch |
| incron-remove | :orange_circle: | Remove incron watch |
| incron-status | :orange_circle: | Show incron status |

### Round 287 — ACL ext, Xattr ext, Chattr ext, Quota ext, Fstab ext

| Command | Status | Description |
|---------|--------|-------------|
| acl-get | :orange_circle: | Get file ACL |
| acl-set | :orange_circle: | Set file ACL |
| acl-remove | :orange_circle: | Remove file ACL |
| acl-default | :orange_circle: | Set default ACL |
| xattr-list | :orange_circle: | List extended attributes |
| xattr-get | :orange_circle: | Get extended attribute |
| xattr-set | :orange_circle: | Set extended attribute |
| xattr-remove | :orange_circle: | Remove extended attribute |
| chown-recursive | :orange_circle: | Recursive chown |
| chmod-recursive | :orange_circle: | Recursive chmod |
| chattr-set | :orange_circle: | Set file attributes |
| chattr-get | :orange_circle: | Get file attributes |
| quota-check | :orange_circle: | Check disk quotas |
| quota-set | :orange_circle: | Set user quota |
| quota-report | :orange_circle: | Generate quota report |
| quota-status | :orange_circle: | Show quota status |
| fstab-list | :orange_circle: | List fstab entries |
| fstab-add | :orange_circle: | Add fstab entry |
| fstab-remove | :orange_circle: | Remove fstab entry |
| fstab-check | :orange_circle: | Check fstab syntax |

### Round 286 — PAM ext, SSHD ext, GPG ext, SSL ext, Vault ext

| Command | Status | Description |
|---------|--------|-------------|
| pam-status | :orange_circle: | Show PAM status |
| pam-config | :orange_circle: | View PAM configuration |
| pam-module-list | :orange_circle: | List PAM modules |
| pam-auth-test | :orange_circle: | Test PAM authentication |
| sshd-config | :orange_circle: | View SSHD configuration |
| sshd-restart | :orange_circle: | Restart SSHD service |
| sshd-keygen | :orange_circle: | Generate SSH key |
| sshd-authorized-keys | :orange_circle: | List authorized keys |
| gpg-list-keys | :orange_circle: | List GPG keys |
| gpg-import | :orange_circle: | Import GPG key |
| gpg-export | :orange_circle: | Export GPG key |
| gpg-sign-file | :orange_circle: | Sign file with GPG |
| ssl-cert-info | :orange_circle: | Show certificate info |
| ssl-cert-verify | :orange_circle: | Verify certificate |
| ssl-cert-generate | :orange_circle: | Generate SSL certificate |
| ssl-cert-expiry | :orange_circle: | Check certificate expiry |
| vault-status | :orange_circle: | Show Vault status |
| vault-seal | :orange_circle: | Seal Vault |
| vault-unseal | :orange_circle: | Unseal Vault |
| vault-read | :orange_circle: | Read Vault secret |

### Round 285 — Cgroup ext, Namespace ext, Seccomp ext, Capabilities ext, Ulimit ext

| Command | Status | Description |
|---------|--------|-------------|
| cgroup-list | :orange_circle: | List cgroups |
| cgroup-create | :orange_circle: | Create cgroup |
| cgroup-move | :orange_circle: | Move process to cgroup |
| cgroup-limit | :orange_circle: | Set cgroup resource limit |
| namespace-list | :orange_circle: | List namespaces |
| namespace-create | :orange_circle: | Create namespace |
| namespace-enter | :orange_circle: | Enter namespace |
| namespace-delete | :orange_circle: | Delete namespace |
| seccomp-status | :orange_circle: | Show seccomp status |
| seccomp-profile | :orange_circle: | Load seccomp profile |
| seccomp-audit | :orange_circle: | View seccomp audit log |
| seccomp-list | :orange_circle: | List syscall filters |
| capabilities-list | :orange_circle: | List process capabilities |
| capabilities-add | :orange_circle: | Add capability |
| capabilities-drop | :orange_circle: | Drop capability |
| capabilities-show | :orange_circle: | Show PID capabilities |
| ulimit-list | :orange_circle: | List ulimits |
| ulimit-set | :orange_circle: | Set ulimit value |
| ulimit-hard | :orange_circle: | Show hard limits |
| ulimit-soft | :orange_circle: | Show soft limits |

### Round 284 — LVM ext, ZFS ext, Btrfs ext, MDADM ext, LUKS ext

| Command | Status | Description |
|---------|--------|-------------|
| lvm-list | :orange_circle: | List LVM volumes |
| lvm-create | :orange_circle: | Create LVM volume |
| lvm-extend | :orange_circle: | Extend LVM volume |
| lvm-reduce | :orange_circle: | Reduce LVM volume |
| zfs-list | :orange_circle: | List ZFS datasets |
| zfs-create | :orange_circle: | Create ZFS dataset |
| zfs-snapshot | :orange_circle: | Create ZFS snapshot |
| zfs-destroy | :orange_circle: | Destroy ZFS dataset |
| btrfs-list | :orange_circle: | List Btrfs subvolumes |
| btrfs-snapshot | :orange_circle: | Create Btrfs snapshot |
| btrfs-balance | :orange_circle: | Start Btrfs balance |
| btrfs-scrub | :orange_circle: | Start Btrfs scrub |
| mdadm-status | :orange_circle: | Show RAID array status |
| mdadm-create | :orange_circle: | Create RAID array |
| mdadm-add | :orange_circle: | Add device to array |
| mdadm-remove | :orange_circle: | Remove device from array |
| luks-open | :orange_circle: | Open LUKS volume |
| luks-close | :orange_circle: | Close LUKS volume |
| luks-status | :orange_circle: | Show LUKS status |
| luks-format | :orange_circle: | Format LUKS device |

### Round 283 — SELinux ext, AppArmor ext, Firewalld ext, Nftables ext, Iptables ext

| Command | Status | Description |
|---------|--------|-------------|
| selinux-status | :orange_circle: | Show SELinux status |
| selinux-toggle | :orange_circle: | Toggle SELinux mode |
| selinux-audit | :orange_circle: | View SELinux audit log |
| selinux-context | :orange_circle: | Show file SELinux context |
| apparmor-status | :orange_circle: | Show AppArmor status |
| apparmor-enforce | :orange_circle: | Set profile to enforce |
| apparmor-complain | :orange_circle: | Set profile to complain |
| apparmor-disable | :orange_circle: | Disable AppArmor profile |
| firewalld-status | :orange_circle: | Show firewalld status |
| firewalld-add-rule | :orange_circle: | Add firewalld rule |
| firewalld-remove-rule | :orange_circle: | Remove firewalld rule |
| firewalld-list-zones | :orange_circle: | List firewalld zones |
| nftables-list | :orange_circle: | List nftables ruleset |
| nftables-add | :orange_circle: | Add nftables rule |
| nftables-flush | :orange_circle: | Flush nftables ruleset |
| nftables-save | :orange_circle: | Save nftables ruleset |
| iptables-list | :orange_circle: | List iptables rules |
| iptables-add | :orange_circle: | Add iptables rule |
| iptables-delete | :orange_circle: | Delete iptables rule |
| iptables-save | :orange_circle: | Save iptables rules |

### Round 282 — Syslog ext, Journalctl ext, Logrotate ext, Rsyslog ext, Auditd ext

| Command | Status | Description |
|---------|--------|-------------|
| syslog-view | :orange_circle: | View system log |
| syslog-filter | :orange_circle: | Filter syslog by pattern |
| syslog-tail | :orange_circle: | Tail syslog live |
| syslog-search | :orange_circle: | Search syslog entries |
| journalctl-view | :orange_circle: | View systemd journal |
| journalctl-filter | :orange_circle: | Filter journal entries |
| journalctl-priority | :orange_circle: | Filter by priority level |
| journalctl-since | :orange_circle: | Show entries since time |
| logrotate-status | :orange_circle: | Show logrotate status |
| logrotate-force | :orange_circle: | Force log rotation |
| rsyslog-config | :orange_circle: | View rsyslog configuration |
| rsyslog-restart | :orange_circle: | Restart rsyslog service |
| auditd-status | :orange_circle: | Show auditd status |
| auditd-report | :orange_circle: | Generate audit report |
| auditd-rules | :orange_circle: | List audit rules |
| syslog-priority | :orange_circle: | Set syslog priority |
| syslog-facility | :orange_circle: | Set syslog facility |
| syslog-remote | :orange_circle: | Configure remote syslog |
| syslog-archive | :orange_circle: | Archive syslog files |
| journalctl-export | :orange_circle: | Export journal entries |

### Round 281 — DNS ext, LDAP ext, SNMP ext, NTP ext, DHCP ext

| Command | Status | Description |
|---------|--------|-------------|
| dns-lookup | :orange_circle: | DNS lookup for hostname |
| dns-reverse | :orange_circle: | Reverse DNS lookup |
| dns-mx | :orange_circle: | Query DNS MX records |
| dns-ns | :orange_circle: | Query DNS NS records |
| ldap-bind | :orange_circle: | Bind to LDAP server |
| ldap-modify | :orange_circle: | Modify LDAP entry |
| ldap-add | :orange_circle: | Add LDAP entry |
| ldap-delete | :orange_circle: | Delete LDAP entry |
| snmp-get | :orange_circle: | SNMP GET request |
| snmp-walk | :orange_circle: | SNMP walk OID tree |
| snmp-set | :orange_circle: | SNMP SET request |
| snmp-trap | :orange_circle: | Send SNMP trap |
| ntp-query | :orange_circle: | Query NTP server |
| ntp-peers | :orange_circle: | Show NTP peers |
| ntp-status | :orange_circle: | Show NTP status |
| ntp-sync | :orange_circle: | Sync with NTP server |
| dhcp-discover | :orange_circle: | DHCP discover broadcast |
| dhcp-lease-list | :orange_circle: | List DHCP leases |
| dhcp-release | :orange_circle: | Release DHCP lease |
| dhcp-renew | :orange_circle: | Renew DHCP lease |

### Round 280 — MQTT ext, WebSocket ext, SSE ext, HTTP/2 ext, QUIC ext

| Command | Status | Description |
|---------|--------|-------------|
| mqtt-publish | :orange_circle: | Publish to MQTT topic |
| mqtt-subscribe | :orange_circle: | Subscribe to MQTT topic |
| mqtt-topics | :orange_circle: | List MQTT topics |
| mqtt-broker-status | :orange_circle: | Check MQTT broker status |
| websocket-connect | :orange_circle: | Connect to WebSocket |
| websocket-send | :orange_circle: | Send WebSocket message |
| websocket-close | :orange_circle: | Close WebSocket connection |
| websocket-listen | :orange_circle: | Listen for WebSocket messages |
| sse-connect | :orange_circle: | Connect to SSE stream |
| sse-subscribe | :orange_circle: | Subscribe to SSE events |
| sse-send | :orange_circle: | Send SSE event |
| sse-close | :orange_circle: | Close SSE connection |
| http2-request | :orange_circle: | Make HTTP/2 request |
| http2-push | :orange_circle: | HTTP/2 server push |
| http2-stream | :orange_circle: | Open HTTP/2 stream |
| http2-settings | :orange_circle: | Show HTTP/2 settings |
| quic-connect | :orange_circle: | Connect via QUIC |
| quic-send | :orange_circle: | Send QUIC data |
| quic-stream | :orange_circle: | Open QUIC stream |
| quic-close | :orange_circle: | Close QUIC connection |

### Round 279 — Kafka ext, RabbitMQ ext, NATS ext, Pulsar ext, ZeroMQ ext

| Command | Status | Description |
|---------|--------|-------------|
| kafka-produce | :orange_circle: | Produce to Kafka topic |
| kafka-consume | :orange_circle: | Consume from Kafka topic |
| kafka-topics | :orange_circle: | List Kafka topics |
| kafka-consumer-groups | :orange_circle: | List Kafka consumer groups |
| rabbitmq-publish | :orange_circle: | Publish to RabbitMQ queue |
| rabbitmq-consume | :orange_circle: | Consume from RabbitMQ queue |
| rabbitmq-queues | :orange_circle: | List RabbitMQ queues |
| rabbitmq-exchanges | :orange_circle: | List RabbitMQ exchanges |
| nats-publish | :orange_circle: | Publish to NATS subject |
| nats-subscribe | :orange_circle: | Subscribe to NATS subject |
| nats-streams | :orange_circle: | List NATS streams |
| nats-consumers | :orange_circle: | List NATS consumers |
| pulsar-produce | :orange_circle: | Produce to Pulsar topic |
| pulsar-consume | :orange_circle: | Consume from Pulsar topic |
| pulsar-topics | :orange_circle: | List Pulsar topics |
| pulsar-subscriptions | :orange_circle: | List Pulsar subscriptions |
| zeromq-send | :orange_circle: | Send ZeroMQ message |
| zeromq-receive | :orange_circle: | Receive ZeroMQ message |
| zeromq-monitor | :orange_circle: | Monitor ZeroMQ socket |
| zeromq-proxy | :orange_circle: | Start ZeroMQ proxy |

### Round 278 — Neo4j ext, InfluxDB ext, TimescaleDB ext, CockroachDB ext, DynamoDB ext

| Command | Status | Description |
|---------|--------|-------------|
| neo4j-query | :orange_circle: | Execute Neo4j Cypher query |
| neo4j-browse | :orange_circle: | Browse Neo4j graph |
| neo4j-schema | :orange_circle: | Show Neo4j schema |
| neo4j-stats | :orange_circle: | Show Neo4j database stats |
| influxdb-query | :orange_circle: | Execute InfluxDB query |
| influxdb-databases | :orange_circle: | List InfluxDB databases |
| influxdb-measurements | :orange_circle: | List InfluxDB measurements |
| influxdb-write | :orange_circle: | Write InfluxDB data point |
| timescaledb-query | :orange_circle: | Execute TimescaleDB query |
| timescaledb-hypertables | :orange_circle: | List TimescaleDB hypertables |
| timescaledb-continuous-aggregates | :orange_circle: | List TimescaleDB continuous aggregates |
| timescaledb-compression | :orange_circle: | Show TimescaleDB compression status |
| cockroachdb-query | :orange_circle: | Execute CockroachDB query |
| cockroachdb-nodes | :orange_circle: | List CockroachDB nodes |
| cockroachdb-databases | :orange_circle: | List CockroachDB databases |
| cockroachdb-ranges | :orange_circle: | List CockroachDB ranges |
| dynamodb-scan | :orange_circle: | Scan DynamoDB table |
| dynamodb-query | :orange_circle: | Query DynamoDB table |
| dynamodb-tables | :orange_circle: | List DynamoDB tables |
| dynamodb-describe | :orange_circle: | Describe DynamoDB table |

### Round 277 — Redis ext, Memcached ext, Elasticsearch ext, MongoDB ext, Cassandra ext

| Command | Status | Description |
|---------|--------|-------------|
| redis-cli | :orange_circle: | Start Redis CLI |
| redis-get | :orange_circle: | Redis GET key |
| redis-set | :orange_circle: | Redis SET key |
| redis-keys | :orange_circle: | Redis KEYS pattern |
| memcached-get | :orange_circle: | Memcached get key |
| memcached-set | :orange_circle: | Memcached set key |
| memcached-stats | :orange_circle: | Show Memcached stats |
| memcached-flush | :orange_circle: | Flush all Memcached data |
| elasticsearch-index | :orange_circle: | Inspect Elasticsearch index |
| elasticsearch-mappings | :orange_circle: | Show Elasticsearch mappings |
| elasticsearch-cluster-health | :orange_circle: | Check Elasticsearch cluster health |
| elasticsearch-cat-indices | :orange_circle: | List Elasticsearch indices |
| mongodb-collections | :orange_circle: | List MongoDB collections |
| mongodb-stats | :orange_circle: | Show MongoDB database stats |
| mongodb-databases | :orange_circle: | List MongoDB databases |
| mongodb-aggregate | :orange_circle: | Run MongoDB aggregation |
| cassandra-query | :orange_circle: | Execute Cassandra CQL query |
| cassandra-describe | :orange_circle: | Describe Cassandra keyspace |
| cassandra-tables | :orange_circle: | List Cassandra tables |
| cassandra-cluster-status | :orange_circle: | Show Cassandra cluster status |

### Round 276 — Arrow ext, HDF5 ext, NetCDF ext, FITS ext, SQLite ext

| Command | Status | Description |
|---------|--------|-------------|
| arrow-inspect | :orange_circle: | Inspect Arrow file |
| arrow-schema | :orange_circle: | Show Arrow schema |
| arrow-to-csv | :orange_circle: | Convert Arrow to CSV |
| arrow-stats | :orange_circle: | Show Arrow statistics |
| hdf5-inspect | :orange_circle: | Inspect HDF5 file |
| hdf5-datasets | :orange_circle: | List HDF5 datasets |
| hdf5-attributes | :orange_circle: | Show HDF5 attributes |
| hdf5-dump | :orange_circle: | Dump HDF5 data |
| netcdf-inspect | :orange_circle: | Inspect NetCDF file |
| netcdf-variables | :orange_circle: | List NetCDF variables |
| netcdf-dimensions | :orange_circle: | List NetCDF dimensions |
| netcdf-dump | :orange_circle: | Dump NetCDF data |
| fits-inspect | :orange_circle: | Inspect FITS file |
| fits-header | :orange_circle: | Show FITS header |
| fits-data | :orange_circle: | View FITS data |
| fits-info | :orange_circle: | Show FITS file info |
| sqlite-open | :orange_circle: | Open SQLite database |
| sqlite-tables | :orange_circle: | List SQLite tables |
| sqlite-schema | :orange_circle: | Show SQLite schema |
| sqlite-vacuum | :orange_circle: | Vacuum SQLite database |

### Round 275 — FlatBuffers ext, MessagePack ext, CBOR ext, BSON ext, Parquet ext

| Command | Status | Description |
|---------|--------|-------------|
| flatbuffers-compile | :orange_circle: | Compile FlatBuffers schema |
| flatbuffers-validate | :orange_circle: | Validate FlatBuffers schema |
| flatbuffers-generate | :orange_circle: | Generate FlatBuffers code |
| flatbuffers-format | :orange_circle: | Format FlatBuffers schema |
| msgpack-encode | :orange_circle: | Encode MessagePack data |
| msgpack-decode | :orange_circle: | Decode MessagePack data |
| msgpack-validate | :orange_circle: | Validate MessagePack data |
| msgpack-pretty-print | :orange_circle: | Pretty-print MessagePack data |
| cbor-encode | :orange_circle: | Encode CBOR data |
| cbor-decode | :orange_circle: | Decode CBOR data |
| cbor-validate | :orange_circle: | Validate CBOR data |
| cbor-inspect | :orange_circle: | Inspect CBOR structure |
| bson-encode | :orange_circle: | Encode BSON data |
| bson-decode | :orange_circle: | Decode BSON data |
| bson-validate | :orange_circle: | Validate BSON data |
| bson-pretty-print | :orange_circle: | Pretty-print BSON data |
| parquet-inspect | :orange_circle: | Inspect Parquet file |
| parquet-schema | :orange_circle: | Show Parquet schema |
| parquet-to-json | :orange_circle: | Convert Parquet to JSON |
| parquet-stats | :orange_circle: | Show Parquet statistics |

### Round 274 — OpenAPI ext, AsyncAPI ext, JSON Schema ext, Avro ext, Cap'n Proto ext

| Command | Status | Description |
|---------|--------|-------------|
| openapi-validate | :orange_circle: | Validate OpenAPI specification |
| openapi-preview | :orange_circle: | Preview OpenAPI documentation |
| openapi-generate | :orange_circle: | Generate OpenAPI client |
| openapi-lint | :orange_circle: | Lint OpenAPI specification |
| asyncapi-validate | :orange_circle: | Validate AsyncAPI specification |
| asyncapi-preview | :orange_circle: | Preview AsyncAPI documentation |
| asyncapi-generate | :orange_circle: | Generate AsyncAPI code |
| asyncapi-lint | :orange_circle: | Lint AsyncAPI specification |
| jsonschema-validate | :orange_circle: | Validate JSON Schema document |
| jsonschema-generate | :orange_circle: | Generate JSON Schema |
| jsonschema-format | :orange_circle: | Format JSON Schema |
| jsonschema-lint | :orange_circle: | Lint JSON Schema |
| avro-compile | :orange_circle: | Compile Avro schema |
| avro-validate | :orange_circle: | Validate Avro schema |
| avro-generate | :orange_circle: | Generate code from Avro schema |
| avro-format | :orange_circle: | Format Avro schema |
| capnproto-compile | :orange_circle: | Compile Cap'n Proto schema |
| capnproto-validate | :orange_circle: | Validate Cap'n Proto schema |
| capnproto-generate | :orange_circle: | Generate Cap'n Proto code |
| capnproto-format | :orange_circle: | Format Cap'n Proto schema |

### Round 273 — SPARQL ext, GraphQL ext, gRPC ext, Protocol Buffers ext, Thrift ext

| Command | Status | Description |
|---------|--------|-------------|
| sparql-query | :orange_circle: | Execute SPARQL query |
| sparql-describe | :orange_circle: | Describe SPARQL resource |
| sparql-construct | :orange_circle: | Execute SPARQL CONSTRUCT |
| sparql-endpoint | :orange_circle: | Set SPARQL endpoint |
| graphql-query | :orange_circle: | Execute GraphQL query |
| graphql-mutation | :orange_circle: | Execute GraphQL mutation |
| graphql-introspect | :orange_circle: | Introspect GraphQL schema |
| graphql-format | :orange_circle: | Format GraphQL query |
| grpc-call | :orange_circle: | Call gRPC method |
| grpc-list-services | :orange_circle: | List gRPC services |
| grpc-describe-service | :orange_circle: | Describe gRPC service |
| grpc-stream | :orange_circle: | Start gRPC stream |
| protobuf-compile | :orange_circle: | Compile Protocol Buffers |
| protobuf-lint | :orange_circle: | Lint Protocol Buffers |
| protobuf-format | :orange_circle: | Format Protocol Buffers |
| protobuf-validate | :orange_circle: | Validate Protobuf schema |
| thrift-compile | :orange_circle: | Compile Thrift files |
| thrift-lint | :orange_circle: | Lint Thrift files |
| thrift-generate | :orange_circle: | Generate Thrift code |
| thrift-validate | :orange_circle: | Validate Thrift schema |

### Round 272 — TLA+ ext, Alloy ext, Z3 ext, miniKanren ext, Datalog ext

| Command | Status | Description |
|---------|--------|-------------|
| tlaplus-check | :orange_circle: | Check TLA+ specification |
| tlaplus-run-model | :orange_circle: | Run TLA+ model checker |
| tlaplus-parse | :orange_circle: | Parse TLA+ specification |
| tlaplus-translate | :orange_circle: | Translate TLA+ to PlusCal |
| alloy-run | :orange_circle: | Run Alloy analysis |
| alloy-check | :orange_circle: | Check Alloy assertions |
| alloy-show | :orange_circle: | Show Alloy instance |
| alloy-evaluate | :orange_circle: | Evaluate Alloy expression |
| z3-check | :orange_circle: | Check Z3 satisfiability |
| z3-eval | :orange_circle: | Evaluate Z3 expression |
| z3-prove | :orange_circle: | Prove Z3 theorem |
| z3-model | :orange_circle: | Show Z3 model |
| minikanren-run | :orange_circle: | Run miniKanren query |
| minikanren-test | :orange_circle: | Run miniKanren tests |
| minikanren-eval | :orange_circle: | Evaluate miniKanren expression |
| minikanren-trace | :orange_circle: | Trace miniKanren execution |
| datalog-load | :orange_circle: | Load Datalog program |
| datalog-query | :orange_circle: | Query Datalog |
| datalog-run | :orange_circle: | Run Datalog program |
| datalog-compile | :orange_circle: | Compile Datalog program |

### Round 271 — Lean ext, Agda ext, Idris ext, Isabelle ext, HOL ext

| Command | Status | Description |
|---------|--------|-------------|
| lean-check | :orange_circle: | Check Lean file |
| lean-goal | :orange_circle: | Show Lean goal at point |
| lean-hole | :orange_circle: | Fill Lean hole at point |
| lean-restart | :orange_circle: | Restart Lean server |
| agda-compile | :orange_circle: | Compile Agda file |
| agda-next-goal | :orange_circle: | Move to next Agda goal |
| agda-solve-constraints | :orange_circle: | Solve Agda constraints |
| agda-show-goals | :orange_circle: | Show all Agda goals |
| idris-load | :orange_circle: | Load Idris file |
| idris-type-check | :orange_circle: | Type-check Idris at point |
| idris-generate-def | :orange_circle: | Generate Idris definition |
| idris-doc-at-point | :orange_circle: | Show Idris doc at point |
| isabelle-process | :orange_circle: | Process Isabelle theory |
| isabelle-go-back | :orange_circle: | Go back one Isabelle step |
| isabelle-cancel | :orange_circle: | Cancel Isabelle processing |
| isabelle-sorry | :orange_circle: | Insert Isabelle sorry |
| hol-eval | :orange_circle: | Evaluate HOL expression |
| hol-load | :orange_circle: | Load HOL theory |
| hol-type-of | :orange_circle: | Show HOL type at point |
| hol-print-thm | :orange_circle: | Print HOL theorem |

### Round 270 — Octave ext, Maxima ext, SageMath ext, GAP ext, Coq ext

| Command | Status | Description |
|---------|--------|-------------|
| octave-eval-buffer | :orange_circle: | Evaluate Octave buffer |
| octave-eval-region | :orange_circle: | Evaluate Octave region |
| octave-shell | :orange_circle: | Start Octave shell |
| octave-doc | :orange_circle: | Show Octave documentation |
| maxima-eval-buffer | :orange_circle: | Evaluate Maxima buffer |
| maxima-eval-region | :orange_circle: | Evaluate Maxima region |
| maxima-shell | :orange_circle: | Start Maxima shell |
| maxima-doc | :orange_circle: | Show Maxima documentation |
| sage-eval-buffer | :orange_circle: | Evaluate SageMath buffer |
| sage-eval-region | :orange_circle: | Evaluate SageMath region |
| sage-shell | :orange_circle: | Start SageMath shell |
| sage-doc | :orange_circle: | Show SageMath documentation |
| gap-eval-buffer | :orange_circle: | Evaluate GAP buffer |
| gap-eval-region | :orange_circle: | Evaluate GAP region |
| gap-shell | :orange_circle: | Start GAP shell |
| gap-doc | :orange_circle: | Show GAP documentation |
| coq-next-step | :orange_circle: | Process next Coq step |
| coq-prev-step | :orange_circle: | Undo previous Coq step |
| coq-goto-end | :orange_circle: | Process Coq to end of buffer |
| coq-assert-next | :orange_circle: | Assert next Coq sentence |

### Round 269 — Assembly ext, MATLAB ext, R ext, Julia ext, Wolfram ext

| Command | Status | Description |
|---------|--------|-------------|
| asm-compile | :orange_circle: | Compile assembly code |
| asm-run | :orange_circle: | Run assembly program |
| asm-disassemble | :orange_circle: | Disassemble binary |
| asm-link | :orange_circle: | Link assembly object files |
| matlab-run-buffer | :orange_circle: | Run MATLAB buffer |
| matlab-run-region | :orange_circle: | Run MATLAB region |
| matlab-shell | :orange_circle: | Start MATLAB shell |
| matlab-doc | :orange_circle: | Show MATLAB documentation |
| r-eval-buffer | :orange_circle: | Evaluate R buffer |
| r-eval-region | :orange_circle: | Evaluate R region |
| r-shell | :orange_circle: | Start R shell |
| r-install-package | :orange_circle: | Install R package |
| julia-eval-buffer | :orange_circle: | Evaluate Julia buffer |
| julia-eval-region | :orange_circle: | Evaluate Julia region |
| julia-doc | :orange_circle: | Show Julia documentation |
| julia-run-tests | :orange_circle: | Run Julia tests |
| wolfram-eval-buffer | :orange_circle: | Evaluate Wolfram buffer |
| wolfram-eval-region | :orange_circle: | Evaluate Wolfram region |
| wolfram-kernel | :orange_circle: | Start Wolfram kernel |
| wolfram-doc | :orange_circle: | Show Wolfram documentation |

### Round 268 — Verilog ext, VHDL ext, SystemVerilog ext, Tcl ext, Forth ext

| Command | Status | Description |
|---------|--------|-------------|
| verilog-compile | :orange_circle: | Compile Verilog code |
| verilog-simulate | :orange_circle: | Run Verilog simulation |
| verilog-lint | :orange_circle: | Lint Verilog code |
| verilog-auto | :orange_circle: | Run Verilog AUTO expansion |
| vhdl-compile | :orange_circle: | Compile VHDL code |
| vhdl-simulate | :orange_circle: | Run VHDL simulation |
| vhdl-lint | :orange_circle: | Lint VHDL code |
| vhdl-template | :orange_circle: | Insert VHDL template |
| systemverilog-compile | :orange_circle: | Compile SystemVerilog code |
| systemverilog-lint | :orange_circle: | Lint SystemVerilog code |
| systemverilog-format | :orange_circle: | Format SystemVerilog code |
| systemverilog-check | :orange_circle: | Check SystemVerilog syntax |
| tcl-eval-buffer | :orange_circle: | Evaluate Tcl buffer |
| tcl-eval-region | :orange_circle: | Evaluate Tcl region |
| tcl-repl | :orange_circle: | Start Tcl REPL |
| tcl-check | :orange_circle: | Check Tcl syntax |
| forth-eval-buffer | :orange_circle: | Evaluate Forth buffer |
| forth-load-file | :orange_circle: | Load Forth file |
| forth-repl | :orange_circle: | Start Forth REPL |
| forth-see | :orange_circle: | Decompile Forth word |

### Round 267 — Ada ext, Fortran ext, COBOL ext, Pascal ext, Prolog ext

| Command | Status | Description |
|---------|--------|-------------|
| ada-compile | :orange_circle: | Compile Ada code |
| ada-run | :orange_circle: | Run Ada program |
| ada-check | :orange_circle: | Check Ada syntax |
| ada-format | :orange_circle: | Format Ada code |
| fortran-compile | :orange_circle: | Compile Fortran code |
| fortran-run | :orange_circle: | Run Fortran program |
| fortran-check | :orange_circle: | Check Fortran syntax |
| fortran-indent-region | :orange_circle: | Indent Fortran region |
| cobol-compile | :orange_circle: | Compile COBOL code |
| cobol-run | :orange_circle: | Run COBOL program |
| cobol-check | :orange_circle: | Check COBOL syntax |
| cobol-format | :orange_circle: | Format COBOL code |
| pascal-compile | :orange_circle: | Compile Pascal code |
| pascal-run | :orange_circle: | Run Pascal program |
| pascal-check | :orange_circle: | Check Pascal syntax |
| pascal-indent | :orange_circle: | Indent Pascal code |
| prolog-consult | :orange_circle: | Consult Prolog file |
| prolog-run | :orange_circle: | Run Prolog query |
| prolog-trace | :orange_circle: | Enable Prolog trace mode |
| prolog-debug | :orange_circle: | Enable Prolog debug mode |

### Round 266 — Nim ext, Zig ext, Crystal ext, V lang ext, D lang ext

| Command | Status | Description |
|---------|--------|-------------|
| nim-doc | :orange_circle: | Show Nim symbol documentation |
| nim-build-doc | :orange_circle: | Build Nim documentation |
| nim-doc-search | :orange_circle: | Search Nim documentation |
| zig-fmt | :orange_circle: | Format Zig code |
| zig-check | :orange_circle: | Check Zig code |
| zig-doc | :orange_circle: | Generate Zig documentation |
| zig-clean | :orange_circle: | Clean Zig build artifacts |
| crystal-build | :orange_circle: | Build Crystal project |
| crystal-run | :orange_circle: | Run Crystal program |
| crystal-spec | :orange_circle: | Run Crystal specs |
| crystal-format | :orange_circle: | Format Crystal code |
| crystal-tool-format | :orange_circle: | Run Crystal tool format |
| crystal-playground | :orange_circle: | Open Crystal playground |
| crystal-doc | :orange_circle: | Generate Crystal documentation |
| vlang-fmt | :orange_circle: | Format V code |
| vlang-repl | :orange_circle: | Start V REPL |
| dlang-build | :orange_circle: | Build D project |
| dlang-run | :orange_circle: | Run D program |
| dlang-test | :orange_circle: | Run D tests |
| dlang-format | :orange_circle: | Format D code |

### Round 265 — Elixir ext, Erlang ext, OCaml ext, F# ext, Scala ext

| Command | Status | Description |
|---------|--------|-------------|
| elixir-eval-buffer | :orange_circle: | Evaluate Elixir buffer |
| elixir-eval-region | :orange_circle: | Evaluate Elixir region |
| elixir-iex | :orange_circle: | Start Elixir IEx shell |
| elixir-mix-test | :orange_circle: | Run Elixir mix test |
| elixir-mix-compile | :orange_circle: | Run Elixir mix compile |
| erlang-man | :orange_circle: | Show Erlang module manual |
| erlang-find-tag | :orange_circle: | Find Erlang tag at point |
| erlang-run-tests | :orange_circle: | Run Erlang tests |
| erlang-edoc | :orange_circle: | Generate Erlang EDoc |
| ocaml-eval-buffer | :orange_circle: | Evaluate OCaml buffer |
| ocaml-eval-region | :orange_circle: | Evaluate OCaml region |
| ocaml-toplevel | :orange_circle: | Start OCaml toplevel |
| ocaml-type-at-point | :orange_circle: | Show OCaml type at point |
| fsharp-eval-buffer | :orange_circle: | Evaluate F# buffer |
| fsharp-eval-region | :orange_circle: | Evaluate F# region |
| fsharp-repl | :orange_circle: | Start F# REPL |
| fsharp-compile | :orange_circle: | Compile F# project |
| scala-eval-buffer | :orange_circle: | Evaluate Scala buffer |
| scala-eval-region | :orange_circle: | Evaluate Scala region |
| scala-repl | :orange_circle: | Start Scala REPL |

### Round 264 — Leiningen ext, Boot ext, Clojure ext, Racket ext, Guile ext

| Command | Status | Description |
|---------|--------|-------------|
| lein-repl | :orange_circle: | Start Leiningen REPL |
| lein-deps | :orange_circle: | List Leiningen dependencies |
| lein-jar | :orange_circle: | Build Leiningen JAR |
| lein-uberjar | :orange_circle: | Build Leiningen uberjar |
| boot-build | :orange_circle: | Build with Boot |
| boot-test | :orange_circle: | Test with Boot |
| boot-repl | :orange_circle: | Start Boot REPL |
| boot-dev | :orange_circle: | Start Boot dev environment |
| clojure-eval-buffer | :orange_circle: | Evaluate Clojure buffer |
| clojure-eval-region | :orange_circle: | Evaluate Clojure region |
| clojure-find-def | :orange_circle: | Find Clojure definition |
| clojure-doc-at-point | :orange_circle: | Show Clojure doc at point |
| racket-doc | :orange_circle: | Show Racket documentation |
| racket-expand-macro | :orange_circle: | Expand Racket macro |
| racket-profile | :orange_circle: | Profile Racket buffer |
| racket-check-syntax | :orange_circle: | Check Racket syntax |
| guile-eval-buffer | :orange_circle: | Evaluate Guile buffer |
| guile-repl | :orange_circle: | Start Guile REPL |
| guile-load-file | :orange_circle: | Load Guile file |
| guile-compile-file | :orange_circle: | Compile Guile file |

### Round 263 — Gradle ext, Maven ext, sbt ext, Mill ext, Leiningen ext

| Command | Status | Description |
|---------|--------|-------------|
| gradle-run | :orange_circle: | Run Gradle task |
| gradle-clean | :orange_circle: | Clean Gradle project |
| gradle-dependencies | :orange_circle: | List Gradle dependencies |
| gradle-publish | :orange_circle: | Publish Gradle artifacts |
| maven-compile | :orange_circle: | Compile with Maven |
| maven-test | :orange_circle: | Test with Maven |
| maven-package | :orange_circle: | Package with Maven |
| maven-install | :orange_circle: | Install to local Maven repo |
| maven-deploy | :orange_circle: | Deploy Maven artifacts |
| sbt-compile | :orange_circle: | Compile with sbt |
| sbt-test | :orange_circle: | Test with sbt |
| sbt-run | :orange_circle: | Run sbt main class |
| sbt-clean | :orange_circle: | Clean sbt project |
| sbt-publish | :orange_circle: | Publish sbt artifacts |
| mill-compile | :orange_circle: | Compile with Mill |
| mill-test | :orange_circle: | Test with Mill |
| mill-run | :orange_circle: | Run Mill main class |
| mill-clean | :orange_circle: | Clean Mill project |
| lein-run | :orange_circle: | Run Leiningen project |
| lein-test | :orange_circle: | Test with Leiningen |

### Round 262 — Turborepo ext, Nx ext, Buck2 ext, Pants ext, Gradle ext

| Command | Status | Description |
|---------|--------|-------------|
| turbo-run | :orange_circle: | Run Turborepo task |
| turbo-prune | :orange_circle: | Prune Turborepo for package |
| turbo-graph | :orange_circle: | Generate Turborepo task graph |
| turbo-lint | :orange_circle: | Lint Turborepo packages |
| nx-run | :orange_circle: | Run Nx target |
| nx-graph | :orange_circle: | Generate Nx dependency graph |
| nx-affected | :orange_circle: | List Nx affected projects |
| nx-migrate | :orange_circle: | Run Nx migrations |
| buck2-build | :orange_circle: | Build with Buck2 |
| buck2-test | :orange_circle: | Test with Buck2 |
| buck2-run | :orange_circle: | Run Buck2 target |
| buck2-targets | :orange_circle: | List Buck2 targets |
| pants-run | :orange_circle: | Run Pants target |
| pants-test | :orange_circle: | Run Pants tests |
| pants-fmt | :orange_circle: | Format code with Pants |
| pants-lint | :orange_circle: | Lint code with Pants |
| pants-check | :orange_circle: | Type-check with Pants |
| pants-package | :orange_circle: | Package artifacts with Pants |
| gradle-build | :orange_circle: | Build with Gradle |
| gradle-test | :orange_circle: | Test with Gradle |

### Round 261 — Railway ext, Render ext, Deno ext, Bun ext, pnpm ext

| Command | Status | Description |
|---------|--------|-------------|
| railway-deploy | :orange_circle: | Deploy to Railway |
| railway-logs | :orange_circle: | View Railway deployment logs |
| railway-status | :orange_circle: | Show Railway project status |
| railway-env-list | :orange_circle: | List Railway environment variables |
| render-deploy | :orange_circle: | Deploy to Render |
| render-services-list | :orange_circle: | List Render services |
| render-env-list | :orange_circle: | List Render environment variables |
| render-logs | :orange_circle: | View Render service logs |
| deno-run | :orange_circle: | Run Deno script |
| deno-test | :orange_circle: | Run Deno tests |
| deno-lint | :orange_circle: | Lint Deno code |
| deno-fmt | :orange_circle: | Format Deno code |
| deno-compile | :orange_circle: | Compile Deno to executable |
| bun-run | :orange_circle: | Run script with Bun |
| bun-test | :orange_circle: | Run Bun tests |
| bun-install | :orange_circle: | Install dependencies with Bun |
| bun-build | :orange_circle: | Build project with Bun |
| pnpm-install | :orange_circle: | Install dependencies with pnpm |
| pnpm-run | :orange_circle: | Run pnpm script |
| pnpm-add | :orange_circle: | Add package with pnpm |

### Round 260 — Cloudflare ext, Firebase ext, Supabase ext, PlanetScale ext, Fly.io ext

| Command | Status | Description |
|---------|--------|-------------|
| cloudflare-workers-list | :orange_circle: | List Cloudflare Workers |
| cloudflare-pages-list | :orange_circle: | List Cloudflare Pages projects |
| cloudflare-dns-list | :orange_circle: | List Cloudflare DNS records |
| cloudflare-zones-list | :orange_circle: | List Cloudflare zones |
| firebase-deploy | :orange_circle: | Deploy Firebase project |
| firebase-auth-list | :orange_circle: | List Firebase auth users |
| firebase-functions-list | :orange_circle: | List Firebase Cloud Functions |
| firebase-hosting-list | :orange_circle: | List Firebase hosting sites |
| supabase-db-push | :orange_circle: | Push Supabase database migrations |
| supabase-functions-list | :orange_circle: | List Supabase edge functions |
| supabase-migration-new | :orange_circle: | Create new Supabase migration |
| supabase-status | :orange_circle: | Show Supabase project status |
| planetscale-branch-list | :orange_circle: | List PlanetScale branches |
| planetscale-deploy-request | :orange_circle: | Create PlanetScale deploy request |
| planetscale-db-list | :orange_circle: | List PlanetScale databases |
| planetscale-connect | :orange_circle: | Connect to PlanetScale database |
| fly-deploy | :orange_circle: | Deploy to Fly.io |
| fly-status | :orange_circle: | Show Fly.io app status |
| fly-logs | :orange_circle: | View Fly.io logs |
| fly-scale | :orange_circle: | Scale Fly.io instances |

### Round 259 — Azure ext, DigitalOcean, Heroku ext, Vercel ext, Netlify ext

| Command | Status | Description |
|---------|--------|-------------|
| azure-webapp-list | :orange_circle: | List Azure web apps |
| azure-function-list | :orange_circle: | List Azure functions |
| azure-keyvault-list | :orange_circle: | List Azure key vaults |
| azure-cosmos-list | :orange_circle: | List Azure Cosmos DB accounts |
| digitalocean-droplet-list | :orange_circle: | List DigitalOcean droplets |
| digitalocean-database-list | :orange_circle: | List DigitalOcean databases |
| digitalocean-domain-list | :orange_circle: | List DigitalOcean domains |
| digitalocean-spaces-list | :orange_circle: | List DigitalOcean Spaces |
| heroku-app-list | :orange_circle: | List Heroku apps |
| heroku-logs | :orange_circle: | View Heroku app logs |
| heroku-run | :orange_circle: | Run command on Heroku |
| heroku-config-list | :orange_circle: | List Heroku config vars |
| vercel-deploy | :orange_circle: | Deploy to Vercel |
| vercel-env-list | :orange_circle: | List Vercel environment variables |
| vercel-project-list | :orange_circle: | List Vercel projects |
| vercel-domains-list | :orange_circle: | List Vercel domains |
| netlify-deploy | :orange_circle: | Deploy to Netlify |
| netlify-sites-list | :orange_circle: | List Netlify sites |
| netlify-env-list | :orange_circle: | List Netlify environment variables |
| netlify-functions-list | :orange_circle: | List Netlify functions |

### Round 258 — Prometheus ext, Grafana ext, AWS ext, GCP ext, Azure ext

| Command | Status | Description |
|---------|--------|-------------|
| prometheus-alerts | :orange_circle: | List active Prometheus alerts |
| prometheus-rules | :orange_circle: | List Prometheus rules |
| prometheus-graph | :orange_circle: | Graph a PromQL query |
| grafana-panel-view | :orange_circle: | View a Grafana panel |
| grafana-alert-rules | :orange_circle: | List Grafana alert rules |
| grafana-datasource-list | :orange_circle: | List Grafana datasources |
| grafana-annotation-add | :orange_circle: | Add a Grafana annotation |
| aws-cloudwatch-logs | :orange_circle: | View AWS CloudWatch logs |
| aws-iam-list-users | :orange_circle: | List AWS IAM users |
| aws-sns-list-topics | :orange_circle: | List AWS SNS topics |
| aws-sqs-list-queues | :orange_circle: | List AWS SQS queues |
| aws-rds-list-instances | :orange_circle: | List AWS RDS instances |
| aws-ecs-list-clusters | :orange_circle: | List AWS ECS clusters |
| gcp-compute-list | :orange_circle: | List GCP compute instances |
| gcp-storage-list | :orange_circle: | List GCP storage buckets |
| gcp-pubsub-topics | :orange_circle: | List GCP Pub/Sub topics |
| gcp-functions-list | :orange_circle: | List GCP Cloud Functions |
| gcp-iam-roles | :orange_circle: | List GCP IAM roles |
| azure-vm-list | :orange_circle: | List Azure virtual machines |
| azure-storage-list | :orange_circle: | List Azure storage accounts |

### Round 257 — Chef ext, Salt ext, Nix ext, Guix ext

| Command | Status | Description |
|---------|--------|-------------|
| chef-apply | :orange_circle: | Apply current Chef recipe |
| chef-run-recipe | :orange_circle: | Run a Chef recipe |
| chef-knife-status | :orange_circle: | Show Chef knife status |
| chef-cookbook-upload | :orange_circle: | Upload Chef cookbook |
| chef-role-edit | :orange_circle: | Edit a Chef role |
| salt-apply | :orange_circle: | Apply Salt state |
| salt-ping | :orange_circle: | Ping Salt minions |
| salt-highstate | :orange_circle: | Run Salt highstate |
| salt-pillar-get | :orange_circle: | Get Salt pillar value |
| salt-grains-items | :orange_circle: | List Salt grains |
| nix-search-packages | :orange_circle: | Search Nix packages |
| nix-derivation-show | :orange_circle: | Show Nix derivation |
| nix-profile-list | :orange_circle: | List Nix profile packages |
| nix-develop | :orange_circle: | Enter Nix develop shell |
| guix-package-install | :orange_circle: | Install a Guix package |
| guix-package-remove | :orange_circle: | Remove a Guix package |
| guix-shell | :orange_circle: | Open Guix shell environment |
| guix-system-shepherd-status | :orange_circle: | Show Shepherd service status |
| guix-size | :orange_circle: | Show Guix package size |
| guix-describe | :orange_circle: | Describe current Guix profile |

### Round 256 — Kubernetes ext, Vagrant ext, Puppet ext, systemd, Ansible ext

| Command | Status | Description |
|---------|--------|-------------|
| kubernetes-get-pods | :orange_circle: | List Kubernetes pods |
| kubernetes-get-services | :orange_circle: | List Kubernetes services |
| kubernetes-get-deployments | :orange_circle: | List Kubernetes deployments |
| kubernetes-get-namespaces | :orange_circle: | List Kubernetes namespaces |
| kubernetes-exec | :orange_circle: | Exec into a Kubernetes pod |
| puppet-apply | :orange_circle: | Apply Puppet manifest |
| vagrant-provision | :orange_circle: | Provision Vagrant VM |
| vagrant-reload | :orange_circle: | Reload Vagrant VM |
| vagrant-status | :orange_circle: | Show Vagrant VM status |
| vagrant-box-list | :orange_circle: | List Vagrant boxes |
| systemd-list-units | :orange_circle: | List systemd units |
| systemd-start-unit | :orange_circle: | Start a systemd unit |
| systemd-stop-unit | :orange_circle: | Stop a systemd unit |
| systemd-restart-unit | :orange_circle: | Restart a systemd unit |
| systemd-enable-unit | :orange_circle: | Enable a systemd unit |
| systemd-disable-unit | :orange_circle: | Disable a systemd unit |
| systemd-status-unit | :orange_circle: | Check systemd unit status |
| systemd-reload-daemon | :orange_circle: | Reload systemd daemon |
| ansible-vault-encrypt | :orange_circle: | Encrypt Ansible vault file |
| ansible-vault-decrypt | :orange_circle: | Decrypt Ansible vault file |

### Round 255 — Web-mode ext, YAML ext, TOML, Terraform ext

| Command | Status | Description |
|---------|--------|-------------|
| web-mode-element-wrap | :orange_circle: | Wrap element with tag |
| web-mode-element-kill | :orange_circle: | Kill HTML element |
| web-mode-element-select | :orange_circle: | Select HTML element |
| web-mode-element-parent | :orange_circle: | Navigate to parent element |
| web-mode-element-children | :orange_circle: | Show element children |
| web-mode-fold-or-unfold | :orange_circle: | Toggle element folding |
| web-mode-comment-or-uncomment | :orange_circle: | Toggle HTML comment |
| web-mode-indent-buffer | :orange_circle: | Indent entire buffer |
| web-mode-whitespaces-show | :orange_circle: | Show whitespace |
| web-mode-set-engine | :orange_circle: | Set template engine |
| yaml-narrow-to-block | :orange_circle: | Narrow to YAML block |
| toml-mode-goto-section | :orange_circle: | Jump to TOML section |
| terraform-workspace-list | :orange_circle: | List Terraform workspaces |
| terraform-state-show | :orange_circle: | Show Terraform resource state |
| terraform-import | :orange_circle: | Import Terraform resource |
| terraform-taint | :orange_circle: | Taint Terraform resource |
| terraform-untaint | :orange_circle: | Untaint Terraform resource |
| terraform-refresh | :orange_circle: | Refresh Terraform state |
| terraform-console | :orange_circle: | Open Terraform console |
| terraform-graph | :orange_circle: | Generate Terraform graph |

### Round 254 — LaTeX ext, SQL ext, Org ext, Markdown ext

| Command | Status | Description |
|---------|--------|-------------|
| latex-close-environment | :orange_circle: | Close LaTeX environment |
| latex-insert-section | :orange_circle: | Insert LaTeX section |
| latex-next-section | :orange_circle: | Next LaTeX section |
| latex-previous-section | :orange_circle: | Previous LaTeX section |
| latex-fill-paragraph | :orange_circle: | Fill LaTeX paragraph |
| latex-indent-line | :orange_circle: | Indent LaTeX line |
| latex-mark-environment | :orange_circle: | Mark LaTeX environment |
| latex-narrow-to-environment | :orange_circle: | Narrow to LaTeX environment |
| sql-send-region-and-keep | :orange_circle: | Send SQL region (keep active) |
| ielm-change-working-buffer | :orange_circle: | Change IELM working buffer |
| org-babel-remove-result | :orange_circle: | Remove org-babel result |
| org-babel-remove-result-one-or-many | :orange_circle: | Remove one or many results |
| markdown-insert-gfm-code-block | :orange_circle: | Insert GFM code block |
| markdown-insert-wiki-link | :orange_circle: | Insert wiki link |
| markdown-toggle-url-hiding | :orange_circle: | Toggle URL hiding |
| markdown-toggle-inline-images | :orange_circle: | Toggle inline images |
| markdown-insert-reference-link | :orange_circle: | Insert reference link |
| markdown-cleanup-list-numbers | :orange_circle: | Clean up list numbers |
| markdown-complete-buffer | :orange_circle: | Complete markdown buffer |
| markdown-insert-foldable-block | :orange_circle: | Insert foldable block |
| markdown-edit-code-block | :orange_circle: | Edit code block in indirect buffer |

### Round 253 — PHP ext, Perl ext, Julia, Nim, Dart, Swift

| Command | Status | Description |
|---------|--------|-------------|
| php-mode-goto-definition | :orange_circle: | Go to PHP definition |
| php-run-builtin-web-server | :orange_circle: | Start PHP built-in web server |
| php-insert-doc-block | :orange_circle: | Insert PHP doc block |
| cperl-perldoc | :orange_circle: | Show Perl documentation |
| cperl-indent-command | :orange_circle: | Indent Perl code |
| ess-display-help-on-object | :orange_circle: | Show R help on object |
| julia-repl-send-region | :orange_circle: | Send region to Julia REPL |
| julia-repl-send-buffer | :orange_circle: | Send buffer to Julia REPL |
| julia-repl-send-line | :orange_circle: | Send line to Julia REPL |
| julia-latexsub-or-indent | :orange_circle: | Julia LaTeX substitution |
| julia-repl-doc | :orange_circle: | Show Julia documentation |
| julia-repl-edit | :orange_circle: | Edit Julia function |
| nim-suggest-def | :orange_circle: | Jump to Nim definition |
| nim-eldoc-at-point | :orange_circle: | Show Nim eldoc at point |
| dart-server-goto-definition | :orange_circle: | Go to Dart definition |
| dart-server-find-references | :orange_circle: | Find Dart references |
| dart-run-flutter | :orange_circle: | Run Flutter |
| dart-server-edit-organize-directives | :orange_circle: | Organize Dart directives |
| swift-mode-send-buffer | :orange_circle: | Send buffer to Swift REPL |
| swift-mode-fill-paragraph | :orange_circle: | Fill Swift paragraph |

### Round 252 — Haskell ext, Elixir ext, CIDER ext, Ensime

| Command | Status | Description |
|---------|--------|-------------|
| haskell-process-type | :orange_circle: | Show type of Haskell expression |
| haskell-check | :orange_circle: | Check current Haskell file |
| haskell-compile | :orange_circle: | Compile Haskell project |
| haskell-session-change | :orange_circle: | Change Haskell session |
| elixir-mode-goto-definition | :orange_circle: | Go to Elixir definition |
| alchemist-mix-run | :orange_circle: | Run Elixir mix task |
| alchemist-mix-test | :orange_circle: | Run Elixir mix tests |
| alchemist-compile-this-buffer | :orange_circle: | Compile Elixir buffer |
| cider-find-dwim | :orange_circle: | CIDER find-dwim at point |
| ensime-edit-definition | :orange_circle: | Jump to Scala definition |
| ensime-type-at-point | :orange_circle: | Show Scala type at point |
| ensime-import-type-at-point | :orange_circle: | Import Scala type at point |
| ensime-search | :orange_circle: | Search Scala project |
| ensime-show-hierarchy | :orange_circle: | Show Scala type hierarchy |
| ensime-refactor-rename | :orange_circle: | Rename Scala symbol |
| ensime-refactor-organize-imports | :orange_circle: | Organize Scala imports |
| ensime-refactor-extract-method | :orange_circle: | Extract Scala method |
| ensime-refactor-inline-local | :orange_circle: | Inline Scala local variable |
| ensime-refactor-extract-local | :orange_circle: | Extract Scala local variable |
| ensime-expand-selection | :orange_circle: | Expand Scala selection |

### Round 251 — Semantic ext, Python ext, Ruby ext, JS/TS/Go guru

| Command | Status | Description |
|---------|--------|-------------|
| semantic-analyze-possible-completions | :orange_circle: | Analyze possible completions |
| python-indent-dedent-line | :orange_circle: | Dedent current Python line |
| python-mark-defun | :orange_circle: | Mark Python defun |
| ruby-find-library-file | :orange_circle: | Find Ruby library file |
| js-comint-send-region | :orange_circle: | Send region to JS REPL |
| js-comint-send-buffer | :orange_circle: | Send buffer to JS REPL |
| js-comint-send-last-sexp | :orange_circle: | Send last sexp to JS REPL |
| typescript-format-buffer | :orange_circle: | Format TypeScript buffer |
| typescript-compile | :orange_circle: | Compile TypeScript |
| go-guru-describe | :orange_circle: | Go guru describe expression |
| go-guru-definition | :orange_circle: | Go guru jump to definition |
| go-guru-callers | :orange_circle: | Go guru find callers |
| go-guru-callees | :orange_circle: | Go guru find callees |
| go-guru-implements | :orange_circle: | Go guru find implementations |
| go-guru-referrers | :orange_circle: | Go guru find referrers |
| go-guru-pointsto | :orange_circle: | Go guru points-to analysis |
| go-guru-freevars | :orange_circle: | Go guru find free variables |
| go-guru-whicherrs | :orange_circle: | Go guru which errors |
| go-guru-peers | :orange_circle: | Go guru find channel peers |
| go-guru-set-scope | :orange_circle: | Go guru set analysis scope |

### Round 250 — Treesitter ext, Native-compile, Eglot ext, JSONRPC

| Command | Status | Description |
|---------|--------|-------------|
| treesit-font-lock-recompute-features | :orange_circle: | Recompute treesit font-lock features |
| native-comp-speed-set | :orange_circle: | Set native compilation speed |
| package-recompile-all | :orange_circle: | Recompile all packages |
| package-isolate | :orange_circle: | Isolate a package for testing |
| loaddefs-generate | :orange_circle: | Generate autoload definitions |
| batch-native-compile | :orange_circle: | Batch native compile files |
| restart-emacs-start-new-emacs | :orange_circle: | Restart in new Emacs instance |
| multisession-edit-value | :orange_circle: | Edit multisession variable |
| multisession-delete | :orange_circle: | Delete multisession variable |
| connection-local-set-profile-variables | :orange_circle: | Set connection-local profile vars |
| hack-connection-local-variables | :orange_circle: | Apply connection-local variables |
| jsonrpc-request | :orange_circle: | Send JSONRPC request |
| jsonrpc-notify | :orange_circle: | Send JSONRPC notification |
| jsonrpc-shutdown | :orange_circle: | Shutdown JSONRPC connection |
| eglot-list-connections | :orange_circle: | List active Eglot connections |
| eglot-forget-pending-continuations | :orange_circle: | Forget pending continuations |
| eglot-signal-didClose | :orange_circle: | Signal didClose to server |
| eglot-signal-didChangeWatchedFiles | :orange_circle: | Signal watched files changed |
| eglot-reconnect-all | :orange_circle: | Reconnect all Eglot servers |
| eglot-boosts-enable | :orange_circle: | Toggle Eglot boosts |

### Round 249 — CUA ext, Password-store, EPA

| Command | Status | Description |
|---------|--------|-------------|
| cua-rectangle-mark-mode | :orange_circle: | Toggle CUA rectangle mark mode |
| cua-paste-pop | :orange_circle: | Cycle through kill ring (CUA) |
| thing-at-point-url-at-point | :orange_circle: | Extract URL at point |
| browse-url-of-region | :orange_circle: | Browse region as URL |
| url-retrieve-synchronously | :orange_circle: | Retrieve URL synchronously |
| url-copy-file | :orange_circle: | Download URL to file |
| shr-toggle-images | :orange_circle: | Toggle SHR image display |
| password-store-copy | :orange_circle: | Copy password from store |
| password-store-generate | :orange_circle: | Generate new password |
| password-store-insert | :orange_circle: | Insert password entry |
| password-store-remove | :orange_circle: | Remove password entry |
| password-store-edit | :orange_circle: | Edit password entry |
| password-store-rename | :orange_circle: | Rename password entry |
| password-store-url | :orange_circle: | Open URL for password entry |
| epa-sign-file | :orange_circle: | Sign file with GPG |
| epa-verify-file | :orange_circle: | Verify GPG signature |
| epa-encrypt-region | :orange_circle: | Encrypt region with GPG |
| epa-decrypt-region | :orange_circle: | Decrypt region with GPG |
| epa-import-keys | :orange_circle: | Import GPG keys |
| epa-export-keys | :orange_circle: | Export GPG keys |

### Round 248 — Xref ext, Project.el ext, Flymake ext, Eldoc ext

| Command | Status | Description |
|---------|--------|-------------|
| xref-find-references-at-point | :orange_circle: | Find references at point |
| xref-go-forward | :orange_circle: | Navigate xref forward |
| xref-find-definitions-other-window | :orange_circle: | Find definitions in other window |
| xref-find-definitions-other-frame | :orange_circle: | Find definitions in other frame |
| project-dired | :orange_circle: | Open dired in project root |
| project-find-regexp-in-files | :orange_circle: | Search regexp in project files |
| flymake-show-diagnostic | :orange_circle: | Show diagnostic at point |
| eldoc-doc-buffer | :orange_circle: | Show eldoc documentation buffer |
| eldoc-toggle-display | :orange_circle: | Toggle eldoc display |
| tab-bar-move-tab-backward | :orange_circle: | Move tab backward |
| tab-bar-move-tab-forward | :orange_circle: | Move tab forward |
| pixel-scroll-interpolate-up | :orange_circle: | Smooth scroll interpolate up |
| pixel-scroll-interpolate-down | :orange_circle: | Smooth scroll interpolate down |
| scroll-bar-toolkit-scroll | :orange_circle: | Toolkit scroll bar action |
| global-so-long-mode | :orange_circle: | Toggle global so-long mode |
| completing-read-default | :orange_circle: | Default completing read style |
| read-extended-command-predicate | :orange_circle: | Extended command predicate filter |
| use-package-autoload-keymap | :orange_circle: | Autoload keymap for package |
| sqlite-mode-open-file | :orange_circle: | Open SQLite file in sqlite-mode |
| image-dired-tag-files | :orange_circle: | Tag image files in image-dired |

### Round 247 — Final gerbil-emacs parity (Quickrun, String-edit)

| Command | Status | Description |
|---------|--------|-------------|
| quickrun | :orange_circle: | Execute current buffer |
| quickrun-with | :orange_circle: | Execute with specific command |
| string-edit-commit | :orange_circle: | Commit string edit changes |

### Round 246 — Surround, Writeroom, Rainbow, Mode toggles (gerbil-emacs parity)

| Command | Status | Description |
|---------|--------|-------------|
| surround-add | :orange_circle: | Add surrounding characters |
| surround-change | :orange_circle: | Change surrounding characters |
| surround-delete | :orange_circle: | Delete surrounding characters |
| writeroom-mode-real | :orange_circle: | Toggle writeroom distraction-free mode |
| rainbow-mode-real | :orange_circle: | Toggle rainbow color highlighting |
| rainbow-refresh | :orange_circle: | Refresh rainbow highlights |
| persistent-scratch-mode | :orange_circle: | Toggle persistent scratch mode |
| persistent-scratch-save | :orange_circle: | Save persistent scratch |
| persistent-scratch-restore | :orange_circle: | Restore persistent scratch |
| ligature-mode-real | :orange_circle: | Toggle ligature display mode |
| marginalia-mode-real | :orange_circle: | Toggle marginalia annotations |
| marginalia-describe-commands | :orange_circle: | Describe commands with marginalia |
| minimap-mode-real | :orange_circle: | Toggle minimap display |
| nano-theme-real | :orange_circle: | Apply nano theme |
| orderless-mode-real | :orange_circle: | Toggle orderless completion |
| orderless-filter-demo | :orange_circle: | Demo orderless filtering |
| olivetti-mode-real | :orange_circle: | Toggle olivetti centered text |
| page-break-lines-real | :orange_circle: | Toggle page break line display |
| pixel-scroll-precision-mode-real | :orange_circle: | Toggle pixel scroll precision |
| save-place-mode-real | :orange_circle: | Toggle save place mode |

### Round 245 — Deft, Dictionary, Pomodoro, Chronometer, Misc (gerbil-emacs parity)

| Command | Status | Description |
|---------|--------|-------------|
| deft | :orange_circle: | Open Deft notes browser |
| deft-new | :orange_circle: | Create new note |
| deft-search | :orange_circle: | Search notes |
| dictionary | :orange_circle: | Look up word in dictionary |
| dictionary-at-point | :orange_circle: | Look up word at point |
| pomodoro-break | :orange_circle: | Take a Pomodoro break |
| pomodoro-reset | :orange_circle: | Reset Pomodoro timer |
| chronometer-start | :orange_circle: | Start chronometer |
| chronometer-stop | :orange_circle: | Stop chronometer |
| chronometer-lap | :orange_circle: | Record chronometer lap |
| chronometer-status | :orange_circle: | Show chronometer status |
| dice-roll | :orange_circle: | Roll dice |
| dice-roll-insert | :orange_circle: | Roll dice and insert result |
| doctor-submit | :orange_circle: | Submit input to Eliza doctor |
| figlet-comment | :orange_circle: | Create figlet ASCII comment |
| morse-encode | :orange_circle: | Encode text to morse code |
| morse-decode | :orange_circle: | Decode morse code to text |
| eros-mode | :orange_circle: | Toggle Eros inline eval mode |
| doom-modeline-real | :orange_circle: | Toggle Doom modeline |
| envrc-mode-real | :orange_circle: | Toggle envrc/direnv mode |

### Round 244 — Mode toggles, Gomoku, HL-todo, Focus, Outline (gerbil-emacs parity)

| Command | Status | Description |
|---------|--------|-------------|
| hl-todo-highlight | :orange_circle: | Highlight TODO keywords |
| hl-todo-occur | :orange_circle: | Show all TODO occurrences |
| hl-todo-refresh | :orange_circle: | Refresh HL-todo highlights |
| focus-mode-real | :orange_circle: | Toggle focus mode (dim unfocused) |
| focus-refresh | :orange_circle: | Refresh focus region |
| focus-set-range | :orange_circle: | Set focus range |
| gomoku-down | :orange_circle: | Move down in Gomoku |
| gomoku-left | :orange_circle: | Move left in Gomoku |
| gomoku-place | :orange_circle: | Place stone in Gomoku |
| gomoku-right | :orange_circle: | Move right in Gomoku |
| gomoku-up | :orange_circle: | Move up in Gomoku |
| outline-fold-all | :orange_circle: | Fold all outline sections |
| outline-toggle-children | :orange_circle: | Toggle children visibility |
| outline-unfold-all | :orange_circle: | Unfold all outline sections |
| golden-ratio-mode-real | :orange_circle: | Toggle golden ratio window sizing |
| crosshair-mode | :orange_circle: | Toggle crosshair cursor display |
| goto-last-change-reverse | :orange_circle: | Navigate changes in reverse |
| context-menu | :orange_circle: | Open context menu |
| context-menu-mode-real | :orange_circle: | Toggle context menu mode |
| corfu-mode-real | :orange_circle: | Toggle Corfu completion mode |

### Round 243 — Git ext, Calc ext (gerbil-emacs parity)

| Command | Status | Description |
|---------|--------|-------------|
| git-bisect-start | :orange_circle: | Start git bisect |
| git-bisect-good | :orange_circle: | Mark commit as good |
| git-bisect-bad | :orange_circle: | Mark commit as bad |
| git-bisect-reset | :orange_circle: | Reset git bisect |
| git-bisect-log | :orange_circle: | Show bisect log |
| git-diff-buffer | :orange_circle: | Diff current buffer |
| git-diff-stat | :orange_circle: | Show diff stat |
| git-shortlog | :orange_circle: | Show git shortlog |
| git-submodule-status | :orange_circle: | Show submodule status |
| git-submodule-update | :orange_circle: | Update git submodules |
| git-timemachine-blame | :orange_circle: | Show blame in timemachine |
| git-timemachine-copy-hash | :orange_circle: | Copy commit hash |
| git-timemachine-goto | :orange_circle: | Go to specific revision |
| git-timemachine-quit | :orange_circle: | Quit timemachine |
| git-timemachine-show-diff | :orange_circle: | Show diff in timemachine |
| git-worktree-add | :orange_circle: | Add git worktree |
| git-worktree-list | :orange_circle: | List git worktrees |
| git-worktree-remove | :orange_circle: | Remove git worktree |
| calc-eval-line | :orange_circle: | Evaluate current line in calc |
| calc-sum-region | :orange_circle: | Sum numbers in region |

### Round 242 — Org-roam, Artist-mode (gerbil-emacs parity)

| Command | Status | Description |
|---------|--------|-------------|
| org-roam-buffer-toggle | :orange_circle: | Toggle org-roam backlinks buffer |
| org-roam-dailies-today | :orange_circle: | Open today's daily note |
| org-roam-db-sync | :orange_circle: | Sync org-roam database |
| org-roam-find-file | :orange_circle: | Find org-roam file |
| org-roam-node-find | :orange_circle: | Find org-roam node |
| org-roam-node-insert | :orange_circle: | Insert org-roam node link |
| org-roam-set-directory | :orange_circle: | Set org-roam directory |
| artist-draw-arrow | :orange_circle: | Draw arrow in artist mode |
| artist-draw-ellipse | :orange_circle: | Draw ellipse in artist mode |
| artist-draw-line | :orange_circle: | Draw line in artist mode |
| artist-draw-rectangle | :orange_circle: | Draw rectangle in artist mode |
| artist-draw-text | :orange_circle: | Place text in artist mode |
| artist-erase-rect | :orange_circle: | Erase rectangle in artist mode |
| artist-select-tool | :orange_circle: | Select artist mode tool |
| artist-set-char | :orange_circle: | Set drawing character |
| auto-dim-other-buffers | :orange_circle: | Toggle dimming of other buffers |
| bug-reference-goto | :orange_circle: | Go to bug reference at point |
| bug-reference-list | :orange_circle: | List all bug references |
| bug-reference-set-project | :orange_circle: | Set bug reference project |
| bug-reference-set-url-format | :orange_circle: | Set bug reference URL format |

### Round 241 — Ido ext, Smex, Ibuffer ext

| Command | Status | Description |
|---------|--------|-------------|
| ido-switch-buffer-other-window | :orange_circle: | Switch buffer in other window via Ido |
| ido-switch-buffer-other-frame | :orange_circle: | Switch buffer in other frame via Ido |
| ido-find-file-other-window | :orange_circle: | Find file in other window via Ido |
| ido-find-file-other-frame | :orange_circle: | Find file in other frame via Ido |
| ido-insert-file | :orange_circle: | Insert file contents via Ido |
| ido-write-file | :orange_circle: | Write file via Ido |
| ido-dired | :orange_circle: | Open dired via Ido |
| ido-kill-buffer | :orange_circle: | Kill buffer via Ido |
| ido-fallback-command | :orange_circle: | Fall back to default completion |
| ido-toggle-case | :orange_circle: | Toggle case sensitivity in Ido |
| smex-major-mode-commands | :orange_circle: | Show major mode commands via Smex |
| smex-show-unbound-commands | :orange_circle: | Show unbound commands via Smex |
| ibuffer-mark-by-mode | :orange_circle: | Mark buffers by mode |
| ibuffer-mark-by-file-name-regexp | :orange_circle: | Mark buffers by filename regexp |
| ibuffer-mark-read-only-buffers | :orange_circle: | Mark read-only buffers |
| ibuffer-mark-special-buffers | :orange_circle: | Mark special buffers |
| ibuffer-mark-dired-buffers | :orange_circle: | Mark dired buffers |
| ibuffer-unmark-all-marks | :orange_circle: | Unmark all ibuffer marks |
| ibuffer-mark-compressed-file-buffers | :orange_circle: | Mark compressed file buffers |
| ibuffer-mark-help-buffers | :orange_circle: | Mark help buffers |

### Round 240 — Eshell ext, Comint ext, Compilation ext, Debugger ext

| Command | Status | Description |
|---------|--------|-------------|
| eshell-repeat-last-argument | :orange_circle: | Repeat last Eshell argument |
| comint-copy-old-input | :orange_circle: | Copy old input in Comint |
| comint-accumulate | :orange_circle: | Accumulate input in Comint |
| comint-show-maximum-output | :orange_circle: | Show maximum Comint output |
| comint-dynamic-list-completions | :orange_circle: | List dynamic completions |
| term-previous-prompt | :orange_circle: | Move to previous prompt |
| term-next-prompt | :orange_circle: | Move to next prompt |
| compilation-display-error | :orange_circle: | Display compilation error |
| compilation-first-error | :orange_circle: | Jump to first error |
| compilation-last-error | :orange_circle: | Jump to last error |
| debugger-toggle-locals | :orange_circle: | Toggle locals display |
| debugger-eval-expression | :orange_circle: | Evaluate expression in debugger |
| debugger-record-expression | :orange_circle: | Record expression in debugger |
| debugger-frame-clear | :orange_circle: | Clear debugger frame |
| debugger-list-functions | :orange_circle: | List functions in debugger |
| compilation-shell-minor-mode | :orange_circle: | Toggle compilation shell minor mode |
| compilation-toggle-ansi-color | :orange_circle: | Toggle ANSI color in compilation |
| compilation-start | :orange_circle: | Start compilation |
| compilation-filter-hook | :orange_circle: | Configure compilation filter hook |
| compilation-auto-jump-to-first-error | :orange_circle: | Toggle auto-jump to first error |

### Round 239 — w3m, EAF, EXWM

| Command | Status | Description |
|---------|--------|-------------|
| w3m-goto-url | :orange_circle: | Open URL in w3m browser |
| w3m-bookmark-add | :orange_circle: | Add w3m bookmark |
| w3m-download | :orange_circle: | Download current page |
| w3m-view-source | :orange_circle: | View page source |
| w3m-reload | :orange_circle: | Reload current page |
| w3m-next-anchor | :orange_circle: | Move to next anchor |
| w3m-previous-anchor | :orange_circle: | Move to previous anchor |
| w3m-copy-buffer | :orange_circle: | Copy w3m buffer |
| eaf-open-browser | :orange_circle: | Open EAF browser |
| eaf-open-terminal | :orange_circle: | Open EAF terminal |
| eaf-open-file-manager | :orange_circle: | Open EAF file manager |
| eaf-open-pdf-viewer | :orange_circle: | Open EAF PDF viewer |
| eaf-open-video-player | :orange_circle: | Open EAF video player |
| exwm-workspace-switch | :orange_circle: | Switch EXWM workspace |
| exwm-workspace-add | :orange_circle: | Add EXWM workspace |
| exwm-workspace-delete | :orange_circle: | Delete EXWM workspace |
| exwm-input-toggle-keyboard | :orange_circle: | Toggle keyboard passthrough |
| exwm-layout-toggle-fullscreen | :orange_circle: | Toggle fullscreen layout |
| exwm-floating-toggle-floating | :orange_circle: | Toggle floating window |
| exwm-layout-toggle-mode-line | :orange_circle: | Toggle mode line in EXWM |

### Round 238 — Consult ext, Vertico ext, Speedbar ext, Neotree ext

| Command | Status | Description |
|---------|--------|-------------|
| consult-complex-command | :orange_circle: | Browse complex command history |
| consult-completing-read-multiple | :orange_circle: | Complete multiple items |
| consult-preview-at-point | :orange_circle: | Preview candidate at point |
| vertico-repeat-last | :orange_circle: | Repeat last Vertico completion |
| vertico-sort-alpha | :orange_circle: | Sort candidates alphabetically |
| vertico-sort-history | :orange_circle: | Sort candidates by history |
| vertico-sort-length | :orange_circle: | Sort candidates by length |
| embark-cycle | :orange_circle: | Cycle through Embark targets |
| calc-grab-rectangle | :orange_circle: | Grab rectangle into Calc |
| calc-embedded-word | :orange_circle: | Calc embedded word mode |
| bookmark-bmenu-edit-annotation | :orange_circle: | Edit bookmark annotation |
| speedbar-edit-line | :orange_circle: | Edit current Speedbar line |
| speedbar-item-info | :orange_circle: | Show Speedbar item info |
| speedbar-item-copy | :orange_circle: | Copy Speedbar item |
| speedbar-item-delete | :orange_circle: | Delete Speedbar item |
| speedbar-item-rename | :orange_circle: | Rename Speedbar item |
| speedbar-create-directory | :orange_circle: | Create directory in Speedbar |
| neotree-collapse-all | :orange_circle: | Collapse all Neotree nodes |
| neotree-copy-filepath-to-yank-ring | :orange_circle: | Copy filepath to kill ring |
| neotree-select-up-node | :orange_circle: | Select parent node in Neotree |

### Round 237 — Helm ext, Counsel ext

| Command | Status | Description |
|---------|--------|-------------|
| helm-semantic-or-imenu | :orange_circle: | Helm semantic/imenu browser |
| helm-colors | :orange_circle: | Helm color browser |
| helm-calcul-expression | :orange_circle: | Helm expression calculator |
| helm-top | :orange_circle: | Helm system process viewer |
| helm-select-xfont | :orange_circle: | Helm font selector |
| helm-run-external-command | :orange_circle: | Run external command via Helm |
| helm-regexp | :orange_circle: | Helm regexp search |
| helm-surfraw | :orange_circle: | Helm surfraw web search |
| helm-info | :orange_circle: | Helm info browser |
| helm-man-woman | :orange_circle: | Helm man page browser |
| counsel-git-log | :orange_circle: | Browse git log via Counsel |
| counsel-mark-ring | :orange_circle: | Browse mark ring via Counsel |
| counsel-org-goto | :orange_circle: | Navigate org headings via Counsel |
| counsel-locate | :orange_circle: | Locate files via Counsel |
| counsel-compile | :orange_circle: | Compile via Counsel |
| counsel-world-clock | :orange_circle: | World clock via Counsel |
| counsel-descbinds | :orange_circle: | Describe bindings via Counsel |
| counsel-rhythmbox | :orange_circle: | Rhythmbox browser via Counsel |
| counsel-switch-to-shell-buffer | :orange_circle: | Switch to shell buffer via Counsel |
| counsel-imenu | :orange_circle: | Imenu browser via Counsel |

### Round 236 — BBDB ext, Gnus ext, SLIME ext

| Command | Status | Description |
|---------|--------|-------------|
| bbdb-display-all | :orange_circle: | Display all BBDB records |
| bbdb-delete-record | :orange_circle: | Delete current BBDB record |
| bbdb-edit-field | :orange_circle: | Edit field in BBDB record |
| bbdb-save | :orange_circle: | Save BBDB database |
| gnus-summary-prev-unread-article | :orange_circle: | Previous unread article |
| gnus-summary-move-article | :orange_circle: | Move article to group |
| gnus-article-toggle-headers | :orange_circle: | Toggle article headers |
| slime-who-binds | :orange_circle: | Find who binds a variable |
| slime-who-sets | :orange_circle: | Find who sets a variable |
| slime-list-threads | :orange_circle: | List Lisp threads |
| slime-interrupt | :orange_circle: | Interrupt current evaluation |
| slime-restart-inferior-lisp | :orange_circle: | Restart inferior Lisp |
| slime-toggle-trace-fdefinition | :orange_circle: | Toggle trace on function |
| slime-undefine-function | :orange_circle: | Undefine a function |
| slime-export-symbol | :orange_circle: | Export symbol from package |
| slime-unexport-symbol | :orange_circle: | Unexport symbol from package |
| slime-sync-package-and-default-directory | :orange_circle: | Sync package and directory |
| slime-toggle-fancy-trace | :orange_circle: | Toggle fancy trace output |
| slime-profile-package | :orange_circle: | Profile a package |
| slime-profiled-functions | :orange_circle: | List profiled functions |

### Round 235 — Wanderlust, mu4e ext

| Command | Status | Description |
|---------|--------|-------------|
| wl-summary-goto-folder | :orange_circle: | Switch to Wanderlust folder |
| wl-summary-sync-current-folder | :orange_circle: | Sync current folder |
| wl-summary-mark-as-read | :orange_circle: | Mark message as read |
| wl-summary-mark-as-unread | :orange_circle: | Mark message as unread |
| wl-summary-delete | :orange_circle: | Delete message |
| wl-summary-refile | :orange_circle: | Refile message to folder |
| wl-summary-reply-with-citation | :orange_circle: | Reply with citation |
| wl-draft-send | :orange_circle: | Send current draft |
| wl-draft-save | :orange_circle: | Save current draft |
| wl-draft-kill | :orange_circle: | Kill current draft |
| mu4e-compose-attach | :orange_circle: | Attach file to email |
| mu4e-view-save-attachments | :orange_circle: | Save email attachments |
| mu4e-headers-toggle-include-related | :orange_circle: | Toggle include related messages |
| mu4e-context-switch | :orange_circle: | Switch mu4e context |
| mu4e-update-index | :orange_circle: | Update mu4e mail index |
| mu4e-headers-query-prev | :orange_circle: | Previous search query |
| mu4e-headers-query-next | :orange_circle: | Next search query |
| mu4e-view-open-attachment | :orange_circle: | Open email attachment |
| mu4e-headers-mark-for-trash | :orange_circle: | Mark message for trash |
| mu4e-headers-mark-for-refile | :orange_circle: | Mark message for refile |

### Round 234 — Ement.el ext, Telega.el

| Command | Status | Description |
|---------|--------|-------------|
| ement-room-send-message | :orange_circle: | Send message in Matrix room |
| ement-room-invite-user | :orange_circle: | Invite user to Matrix room |
| ement-room-leave | :orange_circle: | Leave current Matrix room |
| ement-room-join | :orange_circle: | Join a Matrix room |
| ement-room-toggle-favorite | :orange_circle: | Toggle room as favorite |
| ement-room-set-notification-state | :orange_circle: | Set room notification level |
| ement-list-members | :orange_circle: | List members in current room |
| ement-room-send-reaction | :orange_circle: | Send emoji reaction to message |
| ement-room-send-file | :orange_circle: | Send file in Matrix room |
| ement-room-send-image | :orange_circle: | Send image in Matrix room |
| ement-room-edit-message | :orange_circle: | Edit a sent message |
| ement-room-delete-message | :orange_circle: | Delete a sent message |
| ement-room-scroll-up | :orange_circle: | Scroll up in room history |
| ement-room-scroll-down | :orange_circle: | Scroll down in room history |
| telega-chat-with | :orange_circle: | Open Telegram chat with user |
| telega-browse-url | :orange_circle: | Browse URL in Telegram |
| telega-chatbuf-attach-photo | :orange_circle: | Attach photo to Telegram chat |
| telega-chatbuf-attach-file | :orange_circle: | Attach file to Telegram chat |
| telega-chatbuf-attach-sticker | :orange_circle: | Attach sticker to Telegram chat |
| telega-chat-pin-message | :orange_circle: | Pin message in Telegram chat |

### Round 233 — Mastodon.el

| Command | Status | Description |
|---------|--------|-------------|
| mastodon-toot | :orange_circle: | Compose a new Mastodon toot |
| mastodon-tl-update | :orange_circle: | Update current Mastodon timeline |
| mastodon-tl-next-tab-item | :orange_circle: | Move to next tab item in timeline |
| mastodon-tl-previous-tab-item | :orange_circle: | Move to previous tab item in timeline |
| mastodon-search | :orange_circle: | Search Mastodon for users/tags/statuses |
| mastodon-notifications-get | :orange_circle: | Show Mastodon notifications |
| mastodon-tl-thread | :orange_circle: | Show thread for current toot |
| mastodon-tl-toggle-spoiler-text | :orange_circle: | Toggle content warning visibility |
| mastodon-toot-bookmark-toot | :orange_circle: | Bookmark current toot |
| mastodon-toot-pin-toot | :orange_circle: | Pin current toot to profile |
| mastodon-tl-follow-user | :orange_circle: | Follow a Mastodon user |
| mastodon-tl-unfollow-user | :orange_circle: | Unfollow a Mastodon user |
| mastodon-tl-mute-user | :orange_circle: | Mute a Mastodon user |
| mastodon-tl-unmute-user | :orange_circle: | Unmute a Mastodon user |
| mastodon-tl-block-user | :orange_circle: | Block a Mastodon user |
| mastodon-tl-unblock-user | :orange_circle: | Unblock a Mastodon user |
| mastodon-tl-follow-tag | :orange_circle: | Follow a Mastodon hashtag |
| mastodon-tl-home | :orange_circle: | Show home timeline |
| mastodon-tl-local | :orange_circle: | Show local timeline |
| mastodon-tl-federated | :orange_circle: | Show federated timeline |

### Round 232 — Detached ext, Envrc ext

| Command | Status | Description |
|---------|--------|-------------|
| detached-attach-session | :orange_circle: | Attach to detached session |
| detached-rerun-session | :orange_circle: | Re-run session |
| detached-diff-session | :orange_circle: | Diff session output |
| detached-shell-command | :orange_circle: | Run shell command detached |
| detached-open-output | :orange_circle: | Open session output |
| detached-kill-session | :orange_circle: | Kill session |
| detached-initialize-session | :orange_circle: | Initialize session |
| detached-copy-session-command | :orange_circle: | Copy session command |
| detached-insert-session-command | :orange_circle: | Insert session command |
| detached-describe-session | :orange_circle: | Describe session |
| detached-session-exit-code-mode | :orange_circle: | Toggle exit code mode |
| envrc-show-log | :orange_circle: | Show envrc log |
| envrc-allow-file | :orange_circle: | Allow .envrc file |
| envrc-deny-file | :orange_circle: | Deny .envrc file |
| envrc-copy | :orange_circle: | Copy environment |
| envrc-block-list-add | :orange_circle: | Add to block list |
| envrc-block-list-remove | :orange_circle: | Remove from block list |
| envrc-global-mode | :orange_circle: | Toggle envrc global mode |
| envrc-override-mode | :orange_circle: | Override mode |
| envrc-show-env | :orange_circle: | Show environment |

### Round 231 — Dirvish ext

| Command | Status | Description |
|---------|--------|-------------|
| dirvish-dwim | :orange_circle: | Dirvish DWIM action |
| dirvish-history-go-backward | :orange_circle: | Go backward in history |
| dirvish-narrow | :orange_circle: | Narrow file list |
| dirvish-peek-mode | :orange_circle: | Toggle peek mode |
| dirvish-quicksort | :orange_circle: | Quick sort files |
| dirvish-quit | :orange_circle: | Quit Dirvish |
| dirvish-ls-switches | :orange_circle: | Set ls switches |
| dirvish-file-info-menu | :orange_circle: | File info menu |
| dirvish-show-history | :orange_circle: | Show navigation history |
| dirvish-mark-menu | :orange_circle: | Mark menu |
| dirvish-copy-remote-path | :orange_circle: | Copy remote path |
| dirvish-rename-file | :orange_circle: | Rename file |
| dirvish-chxxx-menu | :orange_circle: | Chmod/chown menu |
| dirvish-roam | :orange_circle: | Roam mode |
| dirvish-extras | :orange_circle: | Extras menu |
| dirvish-media-properties | :orange_circle: | Show media properties |
| dirvish-total-file-size | :orange_circle: | Show total file size |
| dirvish-vc-info-menu | :orange_circle: | VC info menu |
| dirvish-collapse-mode | :orange_circle: | Toggle collapse mode |
| dirvish-side-follow-mode | :orange_circle: | Toggle side follow mode |

### Round 230 — Activities ext, Bufler ext

| Command | Status | Description |
|---------|--------|-------------|
| activities-list | :orange_circle: | List activities |
| activities-rename | :orange_circle: | Rename activity |
| activities-revert | :orange_circle: | Revert activity |
| activities-discard | :orange_circle: | Discard activity |
| activities-save-all | :orange_circle: | Save all activities |
| activities-tabs-mode | :orange_circle: | Toggle activities tabs mode |
| activities-bookmark-set | :orange_circle: | Set activity bookmark |
| activities-bookmark-jump | :orange_circle: | Jump to activity bookmark |
| activities-define | :orange_circle: | Define new activity |
| activities-set | :orange_circle: | Set activity state |
| activities-switch-buffer | :orange_circle: | Switch buffer in activity |
| activities-mode | :orange_circle: | Toggle activities mode |
| activities-tabs-bar-mode | :orange_circle: | Toggle tabs bar mode |
| activities-next | :orange_circle: | Switch to next activity |
| activities-previous | :orange_circle: | Switch to previous activity |
| bufler | :orange_circle: | Open Bufler buffer manager |
| bufler-workspace-frame-set | :orange_circle: | Set workspace frame |
| bufler-workspace-focus-buffer | :orange_circle: | Focus buffer in workspace |
| bufler-defauto-group | :orange_circle: | Define auto group |
| bufler-workspace-mode | :orange_circle: | Toggle Bufler workspace mode |

### Round 229 — Nov ext, Djvu ext, Calibredb

| Command | Status | Description |
|---------|--------|-------------|
| nov-browse-url | :orange_circle: | Browse URL in epub |
| nov-render-title | :orange_circle: | Render epub title |
| nov-search | :orange_circle: | Search in epub |
| nov-history-back | :orange_circle: | Navigate back in epub |
| nov-history-forward | :orange_circle: | Navigate forward in epub |
| djvu-goto-page | :orange_circle: | Goto DjVu page |
| djvu-next-page | :orange_circle: | Next DjVu page |
| djvu-prev-page | :orange_circle: | Previous DjVu page |
| djvu-continuous-mode | :orange_circle: | Toggle continuous DjVu mode |
| djvu-occur | :orange_circle: | Search in DjVu |
| djvu-outline | :orange_circle: | Show DjVu outline |
| djvu-find-file | :orange_circle: | Find DjVu file |
| calibredb-list | :orange_circle: | List Calibre books |
| calibredb-add | :orange_circle: | Add book to Calibre |
| calibredb-remove | :orange_circle: | Remove book from Calibre |
| calibredb-search | :orange_circle: | Search Calibre library |
| calibredb-find-counsel | :orange_circle: | Find via counsel |
| calibredb-set-metadata | :orange_circle: | Set book metadata |
| calibredb-open-file-with-default-tool | :orange_circle: | Open with default tool |
| calibredb-fetch-metadata | :orange_circle: | Fetch metadata |

### Round 228 — Spell-fu ext, Crux ext

| Command | Status | Description |
|---------|--------|-------------|
| spell-fu-goto-next-error | :orange_circle: | Goto next spelling error |
| spell-fu-goto-previous-error | :orange_circle: | Goto previous spelling error |
| spell-fu-reset | :orange_circle: | Reset spell-fu |
| crux-move-beginning-of-line | :orange_circle: | Smart move to beginning of line |
| crux-kill-line-backwards | :orange_circle: | Kill line backwards |
| crux-kill-and-join-forward | :orange_circle: | Kill and join forward |
| crux-duplicate-current-line-or-region | :orange_circle: | Duplicate line or region |
| crux-duplicate-and-comment-current-line-or-region | :orange_circle: | Duplicate and comment |
| crux-rename-file-and-buffer | :orange_circle: | Rename file and buffer |
| crux-view-url | :orange_circle: | View URL |
| crux-switch-to-previous-buffer | :orange_circle: | Switch to previous buffer |
| crux-reopen-as-root | :orange_circle: | Reopen file as root |
| crux-find-user-init-file | :orange_circle: | Find user init file |
| crux-find-shell-init-file | :orange_circle: | Find shell init file |
| crux-ispell-word-then-abbrev | :orange_circle: | Ispell word then abbrev |
| crux-upcase-region | :orange_circle: | Upcase region |
| crux-downcase-region | :orange_circle: | Downcase region |
| crux-capitalize-region | :orange_circle: | Capitalize region |
| crux-other-window-or-switch-buffer | :orange_circle: | Other window or switch buffer |
| crux-sudo-edit | :orange_circle: | Edit with sudo |

### Round 227 — Ement (Matrix client)

| Command | Status | Description |
|---------|--------|-------------|
| ement-connect | :orange_circle: | Connect to Matrix server |
| ement-disconnect | :orange_circle: | Disconnect from server |
| ement-list-rooms | :orange_circle: | List rooms |
| ement-create-room | :orange_circle: | Create room |
| ement-join-room | :orange_circle: | Join room |
| ement-leave-room | :orange_circle: | Leave room |
| ement-invite-user | :orange_circle: | Invite user to room |
| ement-send-message | :orange_circle: | Send message |
| ement-send-emote | :orange_circle: | Send emote |
| ement-send-file | :orange_circle: | Send file |
| ement-room-set-topic | :orange_circle: | Set room topic |
| ement-room-list | :orange_circle: | Show room list |
| ement-view-room | :orange_circle: | View room |
| ement-describe-room | :orange_circle: | Describe room |
| ement-room-tag | :orange_circle: | Tag room |
| ement-notifications | :orange_circle: | Show notifications |
| ement-direct-message | :orange_circle: | Send direct message |
| ement-ignore-user | :orange_circle: | Ignore user |
| ement-unignore-user | :orange_circle: | Unignore user |
| ement-room-toggle-space | :orange_circle: | Toggle space for room |

### Round 226 — Nix ext, Guix ext

| Command | Status | Description |
|---------|--------|-------------|
| nix-flake | :orange_circle: | Nix flake operations |
| nix-indent-line | :orange_circle: | Indent Nix line |
| nix-drv-mode | :orange_circle: | Nix derivation mode |
| nix-update-fetch | :orange_circle: | Update fetch hash |
| nix-env-uninstall | :orange_circle: | Uninstall Nix package |
| guix-build | :orange_circle: | Build Guix package |
| guix-edit | :orange_circle: | Edit Guix package definition |
| guix-lint | :orange_circle: | Lint Guix package |
| guix-graph | :orange_circle: | Show dependency graph |
| guix-hash | :orange_circle: | Compute hash |
| guix-refresh | :orange_circle: | Refresh package |
| guix-download | :orange_circle: | Download URL |
| guix-environment | :orange_circle: | Enter dev environment |
| guix-deploy | :orange_circle: | Deploy system |
| guix-import | :orange_circle: | Import package |
| guix-pack | :orange_circle: | Create pack |
| guix-gc | :orange_circle: | Garbage collect store |
| guix-substitute | :orange_circle: | Manage substitutes |
| guix-archive | :orange_circle: | Archive store items |
| guix-copy | :orange_circle: | Copy store items |

### Round 225 — Transient ext, Cape ext, Tempel ext, Corfu ext

| Command | Status | Description |
|---------|--------|-------------|
| transient-quit-seq | :orange_circle: | Quit transient sequence |
| transient-show | :orange_circle: | Show transient |
| transient-help | :orange_circle: | Show transient help |
| cape-wrap-nonexclusive | :orange_circle: | Wrap capf as nonexclusive |
| cape-wrap-silent | :orange_circle: | Wrap capf silently |
| cape-wrap-case-fold | :orange_circle: | Wrap capf with case folding |
| cape-wrap-noninterruptible | :orange_circle: | Wrap capf as noninterruptible |
| cape-wrap-prefix-length | :orange_circle: | Wrap capf with prefix length |
| cape-wrap-inside-code | :orange_circle: | Wrap capf for inside code |
| cape-capf-inside-comment | :orange_circle: | Capf inside comment |
| tempel-guess | :orange_circle: | Guess template |
| tempel-include | :orange_circle: | Include template |
| tempel-kill | :orange_circle: | Kill template field |
| corfu-popupinfo-scroll-up | :orange_circle: | Scroll popup info up |
| corfu-popupinfo-scroll-down | :orange_circle: | Scroll popup info down |
| corfu-popupinfo-beginning | :orange_circle: | Popup info beginning |
| corfu-popupinfo-end | :orange_circle: | Popup info end |
| corfu-move-to-minibuffer | :orange_circle: | Move completion to minibuffer |
| corfu-reset | :orange_circle: | Reset completion |
| corfu-prompt-end | :orange_circle: | Move to prompt end |

### Round 224 — GPTel ext, Copilot ext, Ellama ext

| Command | Status | Description |
|---------|--------|-------------|
| gptel-send | :orange_circle: | Send prompt to LLM |
| gptel-add | :orange_circle: | Add region to context |
| gptel-add-file | :orange_circle: | Add file to context |
| gptel-context-add | :orange_circle: | Add context item |
| gptel-context-remove | :orange_circle: | Remove context item |
| gptel-org-set-properties | :orange_circle: | Set Org properties for GPTel |
| copilot-login | :orange_circle: | Log in to Copilot |
| copilot-logout | :orange_circle: | Log out of Copilot |
| ellama-improve-wording | :orange_circle: | Improve wording via LLM |
| ellama-make-list | :orange_circle: | Convert text to list |
| ellama-make-table | :orange_circle: | Convert text to table |
| ellama-change-format | :orange_circle: | Change text format |
| ellama-render | :orange_circle: | Render content |
| ellama-ask-line | :orange_circle: | Ask about current line |
| ellama-ask-selection | :orange_circle: | Ask about selection |
| ellama-generate-commit-message | :orange_circle: | Generate commit message |
| ellama-provider-select | :orange_circle: | Select LLM provider |
| ellama-session-switch | :orange_circle: | Switch Ellama session |
| ellama-session-remove | :orange_circle: | Remove Ellama session |
| ellama-context-add-buffer | :orange_circle: | Add buffer to context |

### Round 223 — Eat ext, Vterm ext

| Command | Status | Description |
|---------|--------|-------------|
| eat-reload | :orange_circle: | Reload Eat terminal |
| eat-kill-process | :orange_circle: | Kill Eat process |
| eat-toggle-char-mode | :orange_circle: | Toggle Eat char mode |
| eat-input-char | :orange_circle: | Input character to Eat |
| vterm-send-C-a | :orange_circle: | Send C-a to vterm |
| vterm-send-C-d | :orange_circle: | Send C-d to vterm |
| vterm-send-escape | :orange_circle: | Send Escape to vterm |
| vterm-send-return | :orange_circle: | Send Return to vterm |
| vterm-send-tab | :orange_circle: | Send Tab to vterm |
| vterm-send-next | :orange_circle: | Send Page Down to vterm |
| vterm-send-prior | :orange_circle: | Send Page Up to vterm |
| vterm-send-delete | :orange_circle: | Send Delete to vterm |
| vterm-send-backspace | :orange_circle: | Send Backspace to vterm |
| vterm-send-meta-dot | :orange_circle: | Send M-. to vterm |
| vterm-send-meta-comma | :orange_circle: | Send M-, to vterm |
| vterm-send-ctrl-slash | :orange_circle: | Send C-/ to vterm |
| vterm-yank | :orange_circle: | Yank from kill ring to vterm |
| vterm-yank-pop | :orange_circle: | Yank-pop in vterm |
| vterm-undo | :orange_circle: | Undo in vterm |
| vterm-send-up | :orange_circle: | Send Up arrow to vterm |

### Round 222 — Denote ext, Avy ext, Ace ext

| Command | Status | Description |
|---------|--------|-------------|
| denote-create-note | :orange_circle: | Create a new Denote note |
| denote-explore-keywords | :orange_circle: | Explore Denote keywords |
| denote-org-extras-link-to-heading | :orange_circle: | Link to Org heading |
| denote-journal-extras-new-or-existing-entry | :orange_circle: | New or existing journal entry |
| denote-link-dired-marked-notes | :orange_circle: | Link dired marked notes |
| denote-backlinks-mode | :orange_circle: | Toggle backlinks mode |
| denote-link-after-creating | :orange_circle: | Link after creating note |
| consult-dir | :orange_circle: | Directory selection |
| consult-dir-jump-file | :orange_circle: | Jump to file in directory |
| avy-goto-whitespace-end | :orange_circle: | Goto whitespace end |
| avy-goto-symbol-1-above | :orange_circle: | Goto symbol-1 above |
| avy-goto-symbol-1-below | :orange_circle: | Goto symbol-1 below |
| ace-delete-other-windows | :orange_circle: | Delete other windows via ace |
| ace-window-one | :orange_circle: | Select window one |
| ace-window-two | :orange_circle: | Select window two |
| ace-link-org | :orange_circle: | Follow Org link via ace |
| ace-link-info | :orange_circle: | Follow Info link via ace |
| ace-link-eww | :orange_circle: | Follow EWW link via ace |
| ace-link-help | :orange_circle: | Follow Help link via ace |
| ace-link-compilation | :orange_circle: | Follow compilation link via ace |

### Round 221 — Tags/Citre/ggtags

| Command | Status | Description |
|---------|--------|-------------|
| counsel-etags-find-tag | :orange_circle: | Find tag via counsel |
| counsel-etags-find-tag-at-point | :orange_circle: | Find tag at point |
| counsel-etags-list-tag | :orange_circle: | List tags |
| counsel-etags-recent-tag | :orange_circle: | Recent tags |
| counsel-etags-grep | :orange_circle: | Grep via counsel-etags |
| counsel-etags-virtual-update-tags | :orange_circle: | Virtually update tags |
| citre-jump | :orange_circle: | Jump to definition |
| citre-peek | :orange_circle: | Peek definition |
| citre-ace-peek | :orange_circle: | Ace peek definition |
| citre-jump-back | :orange_circle: | Jump back |
| citre-update-this-tags-file | :orange_circle: | Update tags file |
| citre-create-tags-file | :orange_circle: | Create tags file |
| citre-edit-tags-file-recipe | :orange_circle: | Edit tags recipe |
| citre-global-find-reference | :orange_circle: | Find references via global |
| citre-global-find-definition | :orange_circle: | Find definition via global |
| citre-global-update-database | :orange_circle: | Update global database |
| ggtags-find-tag-dwim | :orange_circle: | Find tag DWIM |
| ggtags-find-reference | :orange_circle: | Find references |
| ggtags-find-definition | :orange_circle: | Find definition |
| ggtags-create-tags | :orange_circle: | Create tags |

### Round 220 — EMMS ext

| Command | Status | Description |
|---------|--------|-------------|
| emms-play-file | :orange_circle: | Play audio file |
| emms-play-directory | :orange_circle: | Play directory |
| emms-play-url | :orange_circle: | Play URL stream |
| emms-pause | :orange_circle: | Toggle pause |
| emms-stop | :orange_circle: | Stop playback |
| emms-next | :orange_circle: | Next track |
| emms-previous | :orange_circle: | Previous track |
| emms-volume-raise | :orange_circle: | Raise volume |
| emms-volume-lower | :orange_circle: | Lower volume |
| emms-shuffle | :orange_circle: | Shuffle playlist |
| emms-sort | :orange_circle: | Sort playlist |
| emms-show | :orange_circle: | Show current track |
| emms-playlist-mode-go | :orange_circle: | Open playlist buffer |
| emms-smart-browse | :orange_circle: | Smart browse library |
| emms-toggle-repeat-playlist | :orange_circle: | Toggle repeat playlist |
| emms-toggle-repeat-track | :orange_circle: | Toggle repeat track |
| emms-playlist-clear | :orange_circle: | Clear playlist |
| emms-playlist-save | :orange_circle: | Save playlist |
| emms-metaplaylist-mode-go | :orange_circle: | Open metaplaylist |
| emms-cache-set-from-mpd-all | :orange_circle: | Cache from MPD |

### Round 219 — SLY ext

| Command | Status | Description |
|---------|--------|-------------|
| sly-mrepl | :orange_circle: | Open SLY MREPL |
| sly-compile-region | :orange_circle: | Compile region |
| sly-eval-region | :orange_circle: | Evaluate region |
| sly-describe-function | :orange_circle: | Describe function |
| sly-apropos | :orange_circle: | Apropos search |
| sly-hyperspec-lookup | :orange_circle: | HyperSpec lookup |
| sly-who-macroexpands | :orange_circle: | Who macroexpands |
| sly-stickers-dwim | :orange_circle: | Stickers DWIM |
| sly-stickers-replay | :orange_circle: | Replay stickers |
| sly-stickers-fetch | :orange_circle: | Fetch stickers |
| sly-stickers-clear-defun-stickers | :orange_circle: | Clear defun stickers |
| sly-stickers-clear-buffer-stickers | :orange_circle: | Clear buffer stickers |
| sly-trace-dialog | :orange_circle: | Open trace dialog |
| sly-trace-dialog-toggle-trace | :orange_circle: | Toggle trace |
| sly-mrepl-sync | :orange_circle: | Sync MREPL package |
| sly-mrepl-clear-repl | :orange_circle: | Clear MREPL |
| sly-mrepl-indent-and-complete-symbol | :orange_circle: | Indent and complete symbol |
| sly-db-continue | :orange_circle: | Debugger continue |
| sly-db-restarts | :orange_circle: | Show debugger restarts |
| sly-db-step | :orange_circle: | Debugger step |

### Round 218 — ERC ext, Elfeed ext

| Command | Status | Description |
|---------|--------|-------------|
| erc-track-list-channels | :orange_circle: | List tracked ERC channels |
| erc-timestamp-mode | :orange_circle: | Toggle ERC timestamp mode |
| erc-hl-nicks-mode | :orange_circle: | Toggle ERC highlight nicks |
| erc-scrolltobottom-mode | :orange_circle: | Toggle ERC scroll-to-bottom |
| erc-nickbar-mode | :orange_circle: | Toggle ERC nickbar |
| erc-list | :orange_circle: | List channels on server |
| erc-status-sidebar-open | :orange_circle: | Open ERC status sidebar |
| elfeed-search-show-entry | :orange_circle: | Show entry from search |
| elfeed-show-save-enclosure | :orange_circle: | Save enclosure |
| elfeed-show-visit | :orange_circle: | Visit entry in browser |
| elfeed-show-next | :orange_circle: | Show next entry |
| elfeed-show-prev | :orange_circle: | Show previous entry |
| elfeed-show-new-live-search | :orange_circle: | New live search from show |
| elfeed-search-first-entry | :orange_circle: | Jump to first entry |
| elfeed-search-last-entry | :orange_circle: | Jump to last entry |
| elfeed-goodies-toggle-header | :orange_circle: | Toggle goodies header |
| elfeed-tube-fetch | :orange_circle: | Fetch tube content |
| elfeed-tube-show | :orange_circle: | Show tube content |
| elfeed-score-enable | :orange_circle: | Enable entry scoring |
| elfeed-score-print-entry-score | :orange_circle: | Print entry score |

### Round 217 — Notmuch ext

| Command | Status | Description |
|---------|--------|-------------|
| notmuch-search-archive-thread | :orange_circle: | Archive thread in search |
| notmuch-search-tag | :orange_circle: | Tag thread in search |
| notmuch-search-filter | :orange_circle: | Filter search results |
| notmuch-search-filter-by-tag | :orange_circle: | Filter search by tag |
| notmuch-show-save-attachments | :orange_circle: | Save message attachments |
| notmuch-show-view-raw-message | :orange_circle: | View raw message |
| notmuch-show-toggle-visibility-headers | :orange_circle: | Toggle header visibility |
| notmuch-poll-and-refresh-this-buffer | :orange_circle: | Poll mail and refresh |
| notmuch-tag-jump | :orange_circle: | Jump to tag operations |
| notmuch-show-stash-cc | :orange_circle: | Stash CC field |
| notmuch-show-stash-from | :orange_circle: | Stash From field |
| notmuch-show-stash-to | :orange_circle: | Stash To field |
| notmuch-show-stash-subject | :orange_circle: | Stash Subject field |
| notmuch-show-stash-message-id | :orange_circle: | Stash Message-ID |
| notmuch-show-stash-date | :orange_circle: | Stash Date field |
| notmuch-show-stash-tags | :orange_circle: | Stash tags |
| notmuch-show-stash-filename | :orange_circle: | Stash filename |
| notmuch-search-stash-thread-id | :orange_circle: | Stash thread ID |
| notmuch-show-next-thread-show | :orange_circle: | Show next thread |
| notmuch-show-pipe-message | :orange_circle: | Pipe message to command |

### Round 216 — CIDER ext

| Command | Status | Description |
|---------|--------|-------------|
| cider-connect-clj | :orange_circle: | Connect to CLJ nREPL |
| cider-connect-cljs | :orange_circle: | Connect to CLJS nREPL |
| cider-jack-in-clj | :orange_circle: | Jack in CLJ REPL |
| cider-jack-in-cljs | :orange_circle: | Jack in CLJS REPL |
| cider-eval-last-sexp-to-repl | :orange_circle: | Eval last sexp to REPL |
| cider-eval-region | :orange_circle: | Eval region |
| cider-eval-ns-form | :orange_circle: | Eval namespace form |
| cider-load-buffer | :orange_circle: | Load current buffer |
| cider-load-file | :orange_circle: | Load file |
| cider-switch-to-repl-buffer | :orange_circle: | Switch to REPL buffer |
| cider-javadoc | :orange_circle: | Show Javadoc |
| cider-test-run-ns-tests | :orange_circle: | Run namespace tests |
| cider-test-run-project-tests | :orange_circle: | Run project tests |
| cider-inspect-last-result | :orange_circle: | Inspect last result |
| cider-macroexpand-1 | :orange_circle: | Macroexpand-1 |
| cider-macroexpand-all | :orange_circle: | Macroexpand all |
| cider-ns-reload | :orange_circle: | Reload namespace |
| cider-ns-reload-all | :orange_circle: | Reload all namespaces |
| cider-repl-clear-buffer | :orange_circle: | Clear REPL buffer |
| cider-format-buffer | :orange_circle: | Format buffer |

### Round 215 — Docker ext

| Command | Status | Description |
|---------|--------|-------------|
| docker-container-start | :orange_circle: | Start Docker container |
| docker-container-stop | :orange_circle: | Stop Docker container |
| docker-container-restart | :orange_circle: | Restart Docker container |
| docker-container-pause | :orange_circle: | Pause Docker container |
| docker-container-unpause | :orange_circle: | Unpause Docker container |
| docker-container-rm | :orange_circle: | Remove Docker container |
| docker-container-kill | :orange_circle: | Kill Docker container |
| docker-image-pull | :orange_circle: | Pull Docker image |
| docker-image-push | :orange_circle: | Push Docker image |
| docker-image-rm | :orange_circle: | Remove Docker image |
| docker-volume-create | :orange_circle: | Create Docker volume |
| docker-volume-rm | :orange_circle: | Remove Docker volume |
| docker-network-create | :orange_circle: | Create Docker network |
| docker-network-rm | :orange_circle: | Remove Docker network |
| docker-compose-restart | :orange_circle: | Restart Compose services |
| docker-compose-push | :orange_circle: | Push Compose images |
| docker-compose-stop | :orange_circle: | Stop Compose services |
| docker-compose-start | :orange_circle: | Start Compose services |
| docker-compose-rm | :orange_circle: | Remove stopped Compose containers |
| docker-compose-exec | :orange_circle: | Execute command in Compose service |

### Round 214 — PDF-tools ext

| Command | Status | Description |
|---------|--------|-------------|
| pdf-view-scroll-up-or-next-page | :orange_circle: | Scroll up or go to next page |
| pdf-view-scroll-down-or-previous-page | :orange_circle: | Scroll down or go to previous page |
| pdf-view-enlarge | :orange_circle: | Enlarge PDF view |
| pdf-view-shrink | :orange_circle: | Shrink PDF view |
| pdf-view-rotate | :orange_circle: | Rotate PDF page |
| pdf-annot-add-strikeout-markup-annotation | :orange_circle: | Add strikeout annotation |
| pdf-view-extract-region-to-string | :orange_circle: | Extract region to string |
| pdf-view-set-slice-from-bounding-box | :orange_circle: | Set slice from bounding box |
| pdf-view-reset-slice | :orange_circle: | Reset page slice |
| pdf-occur-revert | :orange_circle: | Revert occur results |
| pdf-isearch-minor-mode | :orange_circle: | Toggle PDF isearch mode |
| pdf-sync-forward-search | :orange_circle: | Forward sync to source |
| pdf-sync-backward-search | :orange_circle: | Backward sync to PDF |
| pdf-outline-follow-link | :orange_circle: | Follow outline link |
| pdf-links-action-perform | :orange_circle: | Perform link action |
| pdf-links-isearch-link | :orange_circle: | Isearch for link |
| pdf-history-backward | :orange_circle: | Navigate backward in history |
| pdf-history-forward | :orange_circle: | Navigate forward in history |
| pdf-annot-attachment-dired | :orange_circle: | Open attachment in dired |
| pdf-view-continuous-scroll-mode | :orange_circle: | Toggle continuous scroll mode |

### Round 213 — Forge (Magit GitHub/GitLab)

| Command | Status | Description |
|---------|--------|-------------|
| forge-list-pullreqs | :orange_circle: | List pull requests |
| forge-list-issues | :orange_circle: | List issues |
| forge-list-notifications | :orange_circle: | List notifications |
| forge-list-repositories | :orange_circle: | List repositories |
| forge-list-topics | :orange_circle: | List topics |
| forge-pull-pullreq | :orange_circle: | Pull PR data from remote |
| forge-pull-topic | :orange_circle: | Pull topic data from remote |
| forge-create-pullreq | :orange_circle: | Create new pull request |
| forge-create-issue | :orange_circle: | Create new issue |
| forge-create-post | :orange_circle: | Create new post/comment |
| forge-edit-post | :orange_circle: | Edit post/comment |
| forge-delete-post | :orange_circle: | Delete post/comment |
| forge-merge | :orange_circle: | Merge pull request |
| forge-fork | :orange_circle: | Fork repository |
| forge-browse-pullreq | :orange_circle: | Browse PR in browser |
| forge-browse-issue | :orange_circle: | Browse issue in browser |
| forge-browse-commit | :orange_circle: | Browse commit in browser |
| forge-browse-remote | :orange_circle: | Browse remote in browser |
| forge-copy-url-at-point | :orange_circle: | Copy URL at point |
| forge-visit-pullreq | :orange_circle: | Visit pull request |

### Round 212 — Evil extensions

| Command | Status | Description |
|---------|--------|-------------|
| evil-collection-translate-key | :orange_circle: | Translate key in evil collection |
| evil-collection-swap-key | :orange_circle: | Swap keys in evil collection |
| evil-surround-edit | :orange_circle: | Edit surround pair |
| evil-commentary-yank-line | :orange_circle: | Yank and comment line |
| evil-matchit-jump | :orange_circle: | Jump to matching item |
| evil-matchit-jump-items | :orange_circle: | Jump between matching items |
| evil-numbers-increase | :orange_circle: | Increase number at point |
| evil-numbers-decrease | :orange_circle: | Decrease number at point |
| evil-owl-goto-char | :orange_circle: | Owl goto char with hints |
| evil-owl-goto-char-2 | :orange_circle: | Owl goto 2-char with hints |
| evil-textobj-tree-sitter-goto-node | :orange_circle: | Goto tree-sitter node |
| evil-textobj-tree-sitter-select-node | :orange_circle: | Select tree-sitter node |
| evil-args-forward | :orange_circle: | Move to next argument |
| evil-args-backward | :orange_circle: | Move to previous argument |
| evil-args-insert | :orange_circle: | Insert argument |
| evil-args-delete | :orange_circle: | Delete argument |
| evil-indent-plus-indent | :orange_circle: | Indent at same level |
| evil-indent-plus-indent-up | :orange_circle: | Indent at upper level |
| evil-quick-diff | :orange_circle: | Start quick diff |
| evil-quick-diff-cancel | :orange_circle: | Cancel quick diff |

### Round 211 — Treemacs ext

| Command | Status | Description |
|---------|--------|-------------|
| treemacs-visit-node-no-split | :orange_circle: | Visit node without splitting |
| treemacs-visit-node-close-treemacs | :orange_circle: | Visit node and close treemacs |
| treemacs-visit-node-in-most-recently-used-window | :orange_circle: | Visit node in MRU window |
| treemacs-toggle-fixed-width | :orange_circle: | Toggle fixed width mode |
| treemacs-set-width | :orange_circle: | Set treemacs window width |
| treemacs-narrow-to-current-file | :orange_circle: | Narrow view to current file |
| treemacs-cleanup-litter | :orange_circle: | Clean up litter files |
| treemacs-resort | :orange_circle: | Resort tree entries |
| treemacs-fit-window-width | :orange_circle: | Fit window width to content |
| treemacs-gap-between-roots-toggle | :orange_circle: | Toggle gap between root nodes |
| treemacs-fringe-indicator-mode | :orange_circle: | Toggle fringe indicator |
| treemacs-git-commit-diff-mode | :orange_circle: | Toggle git commit diff display |
| treemacs-indicate-top-scroll-mode | :orange_circle: | Toggle top scroll indicator |
| treemacs-tag-follow-mode | :orange_circle: | Toggle tag follow mode |
| treemacs-project-follow-mode | :orange_circle: | Toggle project follow mode |
| treemacs-add-bookmark | :orange_circle: | Add bookmark at point |
| treemacs-next-workspace | :orange_circle: | Switch to next workspace |
| treemacs-previous-workspace | :orange_circle: | Switch to previous workspace |
| treemacs-remove-workspace | :orange_circle: | Remove current workspace |
| treemacs-finish-edit | :orange_circle: | Finish workspace edit |

### Round 210 — DAP-mode ext, LSP-UI ext

| Command | Status | Description |
|---------|--------|-------------|
| dap-debug-edit-template | :orange_circle: | Edit DAP debug template |
| dap-debug-restart | :orange_circle: | Restart debug session |
| dap-debug-last | :orange_circle: | Re-run last debug configuration |
| dap-breakpoint-condition | :orange_circle: | Set conditional breakpoint |
| dap-breakpoint-log-message | :orange_circle: | Set breakpoint log message |
| dap-breakpoint-hit-condition | :orange_circle: | Set breakpoint hit count |
| dap-eval-thing-at-point | :orange_circle: | Evaluate expression at point in debugger |
| lsp-ui-doc-glance | :orange_circle: | Glance documentation at point |
| lsp-ui-doc-unfocus-frame | :orange_circle: | Unfocus documentation frame |
| lsp-ui-sideline-toggle-symbols-info | :orange_circle: | Toggle sideline symbols info |
| lsp-ui-sideline-apply-code-actions | :orange_circle: | Apply sideline code actions |
| lsp-ui-peek-find-workspace-symbol | :orange_circle: | Peek workspace symbol |
| lsp-lens-show | :orange_circle: | Show code lenses |
| lsp-lens-hide | :orange_circle: | Hide code lenses |
| dap-ui-inspect-thing-at-point | :orange_circle: | Inspect thing at point in debugger |
| dap-delete-session | :orange_circle: | Delete current debug session |
| dap-delete-all-sessions | :orange_circle: | Delete all debug sessions |
| dap-ui-expressions-remove | :orange_circle: | Remove watch expression |
| lsp-ui-flycheck-list | :orange_circle: | Show flycheck error list |
| lsp-ui-peek-jump-forward | :orange_circle: | Jump forward in peek history |

### Round 209 — Marginalia-ext, Consult-ext, Vertico-ext, Embark-ext

| Feature | Status | Notes |
|---|---|---|
| marginalia-classify-symbol | :orange_circle: | Classify symbol annotation |
| consult-project-extra-find | :orange_circle: | Find in project (extra) |
| consult-register-window | :orange_circle: | Show register window |
| consult-narrow-help | :orange_circle: | Show narrow help |
| consult-preview-at-point-mode | :orange_circle: | Toggle preview at point |
| vertico-quick-exit | :orange_circle: | Quick exit Vertico |
| vertico-repeat-select | :orange_circle: | Repeat select in Vertico |
| vertico-directory-delete-word | :orange_circle: | Delete directory word |
| vertico-suspend | :orange_circle: | Suspend Vertico session |
| vertico-truncate | :orange_circle: | Toggle Vertico truncation |
| consult-customize | :orange_circle: | Customize Consult options |
| consult-buffer-filter | :orange_circle: | Filter Consult buffers |
| consult-fd-args | :orange_circle: | Consult fd with args |
| consult-grep-args | :orange_circle: | Consult grep with args |
| embark-verbose-indicator | :orange_circle: | Set verbose indicator |
| embark-minimal-indicator | :orange_circle: | Set minimal indicator |
| embark-mixed-indicator | :orange_circle: | Set mixed indicator |
| embark-consult-preview-minor-mode | :orange_circle: | Toggle Embark-consult preview |
| marginalia-reset | :orange_circle: | Reset Marginalia annotations |
| embark-bindings-in-keymap | :orange_circle: | Show Embark bindings in keymap |

### Round 208 — Doom-modeline-ext, Modus-themes-ext, Nano, General, Elpaca, ESUP

| Feature | Status | Notes |
|---|---|---|
| doom-modeline-set-modeline | :orange_circle: | Set Doom modeline style |
| doom-modeline-env-setup-python | :orange_circle: | Setup Python env display |
| doom-modeline-env-setup-ruby | :orange_circle: | Setup Ruby env display |
| modus-themes-wide-deuteranopia | :orange_circle: | Wide deuteranopia support |
| nano-modeline-mode | :orange_circle: | Toggle Nano modeline |
| spacemacs-buffer-goto-link | :orange_circle: | Jump to Spacemacs link |
| spacemacs-toggle-menu | :orange_circle: | Spacemacs toggle menu |
| general-describe-keybindings | :orange_circle: | Describe General keybindings |
| general-override-mode | :orange_circle: | Toggle General override mode |
| use-package-compute-statistics | :orange_circle: | Compute use-package stats |
| use-package-jump-to-package-form | :orange_circle: | Jump to package form |
| straight-thaw-versions | :orange_circle: | Thaw straight.el versions |
| elpaca-browse-package | :orange_circle: | Browse Elpaca package |
| elpaca-update-all | :orange_circle: | Update all Elpaca packages |
| elpaca-delete | :orange_circle: | Delete Elpaca package |
| elpaca-rebuild | :orange_circle: | Rebuild Elpaca package |
| elpaca-log | :orange_circle: | Show Elpaca log |
| quelpa-upgrade-all | :orange_circle: | Upgrade all Quelpa packages |
| benchmark-init-show-durations-tree | :orange_circle: | Show init durations tree |
| esup-run | :orange_circle: | Profile startup with ESUP |

### Round 207 — Treesit-ext, Combobulate, Expreg, Puni

| Feature | Status | Notes |
|---|---|---|
| treesit-inspect-mode | :orange_circle: | Toggle treesit inspect mode |
| combobulate-navigate-up | :orange_circle: | Navigate up in AST |
| combobulate-navigate-down | :orange_circle: | Navigate down in AST |
| combobulate-navigate-next | :orange_circle: | Navigate to next sibling |
| combobulate-navigate-previous | :orange_circle: | Navigate to previous sibling |
| combobulate-drag-up | :orange_circle: | Drag node up |
| combobulate-drag-down | :orange_circle: | Drag node down |
| combobulate-splice-up | :orange_circle: | Splice up in AST |
| combobulate-vanish | :orange_circle: | Vanish node |
| combobulate-envelop | :orange_circle: | Envelop node |
| expreg-expand | :orange_circle: | Expand region by expression |
| expreg-contract | :orange_circle: | Contract region by expression |
| puni-kill-active-region | :orange_circle: | Kill active region (Puni) |
| puni-squeeze | :orange_circle: | Squeeze (Puni) |
| puni-slurp-forward | :orange_circle: | Slurp forward (Puni) |
| puni-barf-forward | :orange_circle: | Barf forward (Puni) |
| puni-raise | :orange_circle: | Raise (Puni) |
| puni-convolute | :orange_circle: | Convolute (Puni) |
| puni-split | :orange_circle: | Split (Puni) |
| puni-transpose | :orange_circle: | Transpose (Puni) |

### Round 206 — Corfu-ext, Cape-ext, Company-ext, Hippie-ext, Pabbrev, Abbrev-suggest

| Feature | Status | Notes |
|---|---|---|
| corfu-quick-complete | :orange_circle: | Quick complete with Corfu |
| corfu-indexed-mode | :orange_circle: | Toggle Corfu indexed mode |
| corfu-separator-insert | :orange_circle: | Insert Corfu separator |
| cape-wrap-buster | :orange_circle: | Cape cache buster wrapper |
| cape-wrap-super | :orange_circle: | Cape super completion wrapper |
| cape-wrap-purify | :orange_circle: | Cape purify wrapper |
| cape-interactive | :orange_circle: | Cape interactive completion |
| kind-icon-margin-formatter | :orange_circle: | Configure kind-icon formatter |
| nerd-icons-corfu-formatter | :orange_circle: | Configure nerd-icons Corfu formatter |
| company-show-doc-buffer | :orange_circle: | Show Company documentation |
| company-search-candidates | :orange_circle: | Search Company candidates |
| company-filter-candidates | :orange_circle: | Filter Company candidates |
| company-select-next-or-abort | :orange_circle: | Select next or abort Company |
| company-complete-common-or-cycle | :orange_circle: | Complete common or cycle Company |
| company-yasnippet | :orange_circle: | Company yasnippet backend |
| hippie-expand-undo | :orange_circle: | Undo hippie expansion |
| dabbrev-expand-all | :orange_circle: | Expand from all buffers |
| pabbrev-mode | :orange_circle: | Toggle predictive abbreviation |
| abbrev-suggest-mode | :orange_circle: | Toggle abbreviation suggestions |
| corfu-candidate-overlay-mode | :orange_circle: | Toggle Corfu candidate overlay |

### Round 205 — Evil-ext, Meow, Boon, God-mode-ext, Transient-ext, Casual

| Feature | Status | Notes |
|---|---|---|
| evil-ex-nohighlight | :orange_circle: | Clear Evil search highlight |
| evil-show-marks | :orange_circle: | Show Evil marks |
| evil-show-registers | :orange_circle: | Show Evil registers |
| meow-block | :orange_circle: | Select block in Meow |
| meow-join | :orange_circle: | Join selection in Meow |
| meow-grab | :orange_circle: | Grab selection in Meow |
| meow-pop-grab | :orange_circle: | Pop grab in Meow |
| meow-swap-grab | :orange_circle: | Swap with grab in Meow |
| boon-set-command-state | :orange_circle: | Enter Boon command state |
| boon-set-insert-state | :orange_circle: | Enter Boon insert state |
| boon-set-special-state | :orange_circle: | Enter Boon special state |
| boon-navigate-backward | :orange_circle: | Navigate backward in Boon |
| boon-navigate-forward | :orange_circle: | Navigate forward in Boon |
| god-toggle-on-overwrite | :orange_circle: | Toggle God-mode on overwrite |
| transient-show-common-commands | :orange_circle: | Show common transient commands |
| casual-calc-tmenu | :orange_circle: | Casual calc transient menu |
| casual-info-tmenu | :orange_circle: | Casual info transient menu |
| casual-isearch-tmenu | :orange_circle: | Casual isearch transient menu |
| casual-avy-tmenu | :orange_circle: | Casual avy transient menu |
| casual-bookmarks-tmenu | :orange_circle: | Casual bookmarks transient menu |

### Round 204 — Vterm-ext, Compile-multi, Envrc, Exec-path, Guix, Apheleia, Format-all, Olivetti

| Feature | Status | Notes |
|---|---|---|
| vterm-toggle-insert | :orange_circle: | Toggle VTerm insert mode |
| comint-watch-for-password-prompt | :orange_circle: | Watch for password prompts |
| compile-multi | :orange_circle: | Show compile targets |
| compile-multi-all-projects | :orange_circle: | Show all project targets |
| envrc-reload-all | :orange_circle: | Reload all envrc environments |
| inheritenv-add-var | :orange_circle: | Add variable to inherit |
| exec-path-from-shell-initialize | :orange_circle: | Initialize PATH from shell |
| exec-path-from-shell-copy-env | :orange_circle: | Copy env var from shell |
| direnv-update-directory-environment | :orange_circle: | Update direnv environment |
| guix-repl | :orange_circle: | Start Guix REPL |
| guix-packages-by-name | :orange_circle: | Search Guix packages |
| apheleia-format-buffer | :orange_circle: | Format buffer with Apheleia |
| apheleia-mode | :orange_circle: | Toggle format on save |
| format-all-mode | :orange_circle: | Toggle format-all mode |
| format-all-region | :orange_circle: | Format region |
| reformatter-define | :orange_circle: | Define new formatter |
| indent-guide-mode | :orange_circle: | Toggle indent guide mode |
| truncate-lines-mode | :orange_circle: | Toggle line truncation |
| visual-line-fill-column-mode | :orange_circle: | Toggle visual line fill column |
| olivetti-set-width | :orange_circle: | Set Olivetti body width |

### Round 203 — Dirvish-ext, Dired-hacks, Diredfl, OpenWith, Dired-launch

| Feature | Status | Notes |
|---|---|---|
| dirvish-fd-ask | :orange_circle: | Dirvish fd file search |
| dirvish-history-go-back | :orange_circle: | Go back in Dirvish history |
| dirvish-history-go-forward | :orange_circle: | Go forward in Dirvish history |
| dirvish-yank-menu | :orange_circle: | Dirvish yank menu |
| dirvish-setup-menu | :orange_circle: | Dirvish setup menu |
| dired-rainbow-define | :orange_circle: | Define Dired rainbow color rule |
| dired-avfs | :orange_circle: | Open file via AVFS |
| dired-quick-sort | :orange_circle: | Quick sort directory listing |
| diredfl-mode | :orange_circle: | Toggle Diredfl extra highlighting |
| dired-atool-do-unpack | :orange_circle: | Unpack archive with atool |
| dired-atool-do-pack | :orange_circle: | Pack files with atool |
| dired-hide-details-plus | :orange_circle: | Toggle hide details plus |
| dired-open-xdg | :orange_circle: | Open with XDG handler |
| dired-recent-open | :orange_circle: | Open recent directory |
| casual-dired-tmenu | :orange_circle: | Casual Dired transient menu |
| openwith-mode | :orange_circle: | Toggle OpenWith mode |
| runner-run | :orange_circle: | Run file with associated program |
| dired-launch-command | :orange_circle: | Launch file with default handler |
| dired-launch-with-prompt-command | :orange_circle: | Launch file with prompted program |
| dired-efap-mode | :orange_circle: | Edit filenames at point |

### Round 202 — Dictionary, Thesaurus, Translation, Spell-fu, Flyspell-correct

| Feature | Status | Notes |
|---|---|---|
| dictionary-lookup-definition | :orange_circle: | Look up word definition |
| thesaurus-lookup-word | :orange_circle: | Look up word in thesaurus |
| powerthesaurus-lookup-synonyms | :orange_circle: | PowerThesaurus synonyms |
| powerthesaurus-lookup-antonyms | :orange_circle: | PowerThesaurus antonyms |
| google-translate-at-point | :orange_circle: | Google Translate at point |
| google-translate-at-point-reverse | :orange_circle: | Reverse translate at point |
| google-translate-buffer | :orange_circle: | Translate entire buffer |
| deepl-translate | :orange_circle: | DeepL translate text |
| deepl-translate-region | :orange_circle: | DeepL translate region |
| go-translate-echo-area | :orange_circle: | Translate in echo area |
| immersive-translate-mode | :orange_circle: | Toggle immersive translate |
| langtool-server-start | :orange_circle: | Start LanguageTool server |
| langtool-server-stop | :orange_circle: | Stop LanguageTool server |
| flyspell-correct-wrapper | :orange_circle: | Show correction options |
| flyspell-correct-at-point | :orange_circle: | Correct word at point |
| flyspell-correct-move | :orange_circle: | Move to next misspelling |
| spell-fu-mode | :orange_circle: | Toggle spell-fu mode |
| spell-fu-word-add | :orange_circle: | Add word to dictionary |
| spell-fu-word-remove | :orange_circle: | Remove word from dictionary |
| spell-fu-dictionary-add | :orange_circle: | Add dictionary |

### Round 201 — Notmuch-ext, Mu4e-ext, Message-ext, SMTP, MML

| Feature | Status | Notes |
|---|---|---|
| notmuch-show-apply-tag-macro | :orange_circle: | Apply tag macro |
| notmuch-show-stash-mlarchive-link | :orange_circle: | Stash mailing list archive link |
| notmuch-tree-archive-message-then-next | :orange_circle: | Archive and move to next |
| notmuch-unthreaded | :orange_circle: | Unthreaded search |
| mu4e-compose-wide-reply | :orange_circle: | Compose wide reply |
| mu4e-compose-supersede | :orange_circle: | Compose supersede message |
| mu4e-action-view-in-browser | :orange_circle: | View message in browser |
| mu4e-action-retag-message | :orange_circle: | Retag message |
| message-elide-region | :orange_circle: | Elide region in message |
| message-caesar-buffer-body | :orange_circle: | ROT13 message body |
| message-fill-yanked-message | :orange_circle: | Fill yanked message |
| smtpmail-send-it | :orange_circle: | Send via SMTP |
| mail-source-fetch | :orange_circle: | Fetch from mail source |
| mail-abbrevs-setup | :orange_circle: | Set up mail abbreviations |
| supercite-cite-original | :orange_circle: | Cite original with Supercite |
| mml-attach-file | :orange_circle: | Attach file to message |
| mml-insert-multipart | :orange_circle: | Insert multipart section |
| mml-preview | :orange_circle: | Preview MIME message |
| mml-secure-message-sign | :orange_circle: | Sign message |
| mml-secure-message-encrypt | :orange_circle: | Encrypt message |

### Round 200 — Pomodoro, Focus, Activities, Burly, Bufler, IBuffer-ext

| Feature | Status | Notes |
|---|---|---|
| pomodoro-start | :orange_circle: | Start Pomodoro timer |
| pomodoro-stop | :orange_circle: | Stop Pomodoro timer |
| pomodoro-pause | :orange_circle: | Pause Pomodoro timer |
| pomodoro-resume | :orange_circle: | Resume Pomodoro timer |
| pomodoro-status | :orange_circle: | Show Pomodoro status |
| focus-pin-buffer | :orange_circle: | Pin buffer in focus mode |
| focus-unpin-buffer | :orange_circle: | Unpin buffer from focus mode |
| activities-new | :orange_circle: | Create new activity |
| activities-resume | :orange_circle: | Resume an activity |
| activities-suspend | :orange_circle: | Suspend current activity |
| activities-switch | :orange_circle: | Switch to activity |
| activities-kill | :orange_circle: | Kill current activity |
| burly-bookmark-frames | :orange_circle: | Bookmark frames |
| bufler-list | :orange_circle: | Show Bufler buffer list |
| bufler-switch-buffer | :orange_circle: | Switch buffer with Bufler |
| ibuffer-filter-by-process | :orange_circle: | Filter by process |
| ibuffer-filter-by-used-mode | :orange_circle: | Filter by used mode |
| ibuffer-filter-by-predicate | :orange_circle: | Filter by predicate |
| ibuffer-decompose-filter | :orange_circle: | Decompose filter group |
| ibuffer-nesting-filter-groups | :orange_circle: | Nest filter groups |

### Round 199 — Denote-ext, Org-roam-ext, Citar-ext, Biblio-ext, Org-ql, Org-sidebar

| Feature | Status | Notes |
|---|---|---|
| denote-rename-file-using-front-matter | :orange_circle: | Rename using front matter |
| denote-link-or-create | :orange_circle: | Link to or create note |
| denote-find-link | :orange_circle: | Find links from current note |
| denote-find-backlink | :orange_circle: | Find backlinks to current note |
| denote-explore-network | :orange_circle: | Explore note network |
| denote-journal-entry | :orange_circle: | Create journal entry |
| org-roam-extract-subtree | :orange_circle: | Extract subtree to new note |
| citar-open-links | :orange_circle: | Open citation links |
| citar-insert-bibtex | :orange_circle: | Insert BibTeX entry |
| citar-export-local-bib | :orange_circle: | Export local bibliography |
| biblio-download-entry | :orange_circle: | Download bibliography entry |
| biblio-crossref-lookup | :orange_circle: | Search CrossRef |
| biblio-dblp-lookup | :orange_circle: | Search DBLP |
| org-ql-search | :orange_circle: | Search with org-ql query |
| org-ql-view | :orange_circle: | Show org-ql saved view |
| org-sidebar-toggle | :orange_circle: | Toggle org sidebar |
| org-sidebar-tree-toggle | :orange_circle: | Toggle org sidebar tree |
| org-edna-mode | :orange_circle: | Toggle org-edna mode |
| org-depend-mode | :orange_circle: | Toggle org-depend mode |
| org-fancy-priorities-mode | :orange_circle: | Toggle fancy priorities mode |

### Round 198 — ERC-ext, EMMS, Bongo

| Feature | Status | Notes |
|---|---|---|
| erc-track-switch-buffer | :orange_circle: | Switch to tracked ERC buffer |
| emms-play-playlist | :orange_circle: | Play EMMS playlist |
| emms-play-directory-tree | :orange_circle: | Play directory tree |
| emms-toggle-random-playlist | :orange_circle: | Toggle random playlist |
| emms-seek-forward | :orange_circle: | Seek forward in track |
| emms-seek-backward | :orange_circle: | Seek backward in track |
| emms-browser | :orange_circle: | Open EMMS browser |
| emms-metaplaylist-mode | :orange_circle: | Toggle metaplaylist mode |
| emms-bookmarks-add | :orange_circle: | Add EMMS bookmark |
| emms-bookmarks-next | :orange_circle: | Jump to next EMMS bookmark |
| emms-lyrics-mode | :orange_circle: | Toggle EMMS lyrics mode |
| emms-tag-editor-edit | :orange_circle: | Edit track tags |
| emms-streams | :orange_circle: | Show EMMS streams |
| emms-mark-all | :orange_circle: | Mark all tracks |
| emms-score-up-playing | :orange_circle: | Score up current track |
| emms-history-save | :orange_circle: | Save EMMS play history |
| bongo-start | :orange_circle: | Start Bongo playback |
| bongo-stop | :orange_circle: | Stop Bongo playback |
| bongo-pause-resume | :orange_circle: | Toggle Bongo pause/resume |
| bongo-next | :orange_circle: | Play next Bongo track |

### Round 197 — Copilot-ext, GPTel-ext, LLM, Aider, Codeium, Sourcegraph, ChatGPT, Whisper

| Feature | Status | Notes |
|---|---|---|
| copilot-accept-completion-by-paragraph | :orange_circle: | Accept completion by paragraph |
| copilot-panel-complete | :orange_circle: | Show Copilot panel completions |
| gptel-send-region | :orange_circle: | Send region to LLM |
| gptel-rewrite | :orange_circle: | Rewrite region with LLM |
| llm-chat-streaming | :orange_circle: | Streaming LLM chat |
| llm-embedding | :orange_circle: | Compute LLM embedding |
| llm-summarize-region | :orange_circle: | Summarize region with LLM |
| aider-add-file | :orange_circle: | Add file to Aider context |
| aider-ask | :orange_circle: | Ask Aider a question |
| aider-architect | :orange_circle: | Aider architect mode |
| codeium-accept-completion | :orange_circle: | Accept Codeium completion |
| codeium-next-completion | :orange_circle: | Next Codeium completion |
| codeium-previous-completion | :orange_circle: | Previous Codeium completion |
| tabnine-restart-server | :orange_circle: | Restart TabNine server |
| sourcegraph-search | :orange_circle: | Search Sourcegraph |
| sourcegraph-open-in-browser | :orange_circle: | Open in Sourcegraph browser |
| chatgpt-shell-prompt | :orange_circle: | ChatGPT shell prompt |
| dall-e-shell-prompt | :orange_circle: | DALL-E image generation prompt |
| whisper-transcribe | :orange_circle: | Transcribe audio with Whisper |
| org-ai-prompt | :orange_circle: | Org-AI prompt |

### Round 196 — MQTT, Redis, MongoDB, Elasticsearch, Prometheus, Grafana, AWS, Azure, GCP

| Feature | Status | Notes |
|---|---|---|
| mqtt-publish-message | :orange_circle: | Publish MQTT message |
| mqtt-subscribe-topic | :orange_circle: | Subscribe to MQTT topic |
| mqtt-disconnect | :orange_circle: | Disconnect from MQTT broker |
| redis-send-command | :orange_circle: | Send Redis command |
| redis-send-region | :orange_circle: | Send region to Redis |
| redis-cli-mode | :orange_circle: | Toggle Redis CLI mode |
| mongodb-find | :orange_circle: | Run MongoDB find query |
| mongodb-insert | :orange_circle: | Insert MongoDB document |
| mongodb-shell-mode | :orange_circle: | Toggle MongoDB shell mode |
| elasticsearch-query | :orange_circle: | Run Elasticsearch query |
| elasticsearch-index-list | :orange_circle: | List Elasticsearch indices |
| prometheus-query | :orange_circle: | Execute PromQL query |
| prometheus-targets | :orange_circle: | List Prometheus targets |
| grafana-dashboard-list | :orange_circle: | List Grafana dashboards |
| grafana-dashboard-open | :orange_circle: | Open Grafana dashboard |
| aws-ec2-list-instances | :orange_circle: | List AWS EC2 instances |
| aws-s3-list-buckets | :orange_circle: | List AWS S3 buckets |
| aws-lambda-list-functions | :orange_circle: | List AWS Lambda functions |
| azure-resource-list | :orange_circle: | List Azure resources |
| gcp-project-list | :orange_circle: | List GCP projects |

### Round 195 — Docker-ext, Docker-compose-ext, Kubernetes-ext, Vagrant-ext, Puppet-ext, Chef-ext, Saltstack-ext

| Feature | Status | Notes |
|---|---|---|
| docker-container-logs | :orange_circle: | Show container logs |
| docker-container-inspect | :orange_circle: | Inspect container |
| docker-container-diff | :orange_circle: | Show container filesystem diff |
| docker-image-inspect | :orange_circle: | Inspect Docker image |
| docker-image-tag | :orange_circle: | Tag Docker image |
| docker-network-inspect | :orange_circle: | Inspect Docker network |
| docker-volume-inspect | :orange_circle: | Inspect Docker volume |
| docker-compose-logs | :orange_circle: | Show Compose logs |
| docker-compose-build | :orange_circle: | Build Compose services |
| docker-compose-pull | :orange_circle: | Pull Compose images |
| kubernetes-logs-follow | :orange_circle: | Follow pod logs |
| kubernetes-apply-buffer | :orange_circle: | Apply buffer manifest |
| kubernetes-delete-resource | :orange_circle: | Delete Kubernetes resource |
| vagrant-halt | :orange_circle: | Halt Vagrant VM |
| vagrant-destroy | :orange_circle: | Destroy Vagrant VM |
| vagrant-ssh | :orange_circle: | SSH into Vagrant VM |
| puppet-validate | :orange_circle: | Validate Puppet manifest |
| puppet-lint | :orange_circle: | Lint Puppet manifest |
| chef-resource-lookup | :orange_circle: | Look up Chef resource |
| saltstack-apply | :orange_circle: | Apply Saltstack state |

### Round 194 — Python-ext, Ruby-ext, Perl-ext, Lua-ext, PHP-ext, Haskell-ext, Kotlin-ext, Swift-ext

| Feature | Status | Notes |
|---|---|---|
| python-fill-paragraph | :orange_circle: | Fill Python paragraph/docstring |
| ruby-send-block | :orange_circle: | Send Ruby block to process |
| ruby-send-definition | :orange_circle: | Send Ruby definition to process |
| ruby-toggle-block | :orange_circle: | Toggle block style (do/end vs {}) |
| inf-ruby-console-auto | :orange_circle: | Auto-detect Ruby console type |
| perl-find-pod | :orange_circle: | Find Perl POD documentation |
| cperl-find-pod | :orange_circle: | Find CPerl POD documentation |
| lua-send-defun | :orange_circle: | Send Lua function to process |
| lua-search-documentation | :orange_circle: | Search Lua documentation |
| php-send-region | :orange_circle: | Send PHP region to process |
| php-search-documentation | :orange_circle: | Search PHP documentation |
| php-current-class | :orange_circle: | Show current PHP class |
| php-current-namespace | :orange_circle: | Show current PHP namespace |
| haskell-interactive-mode-return | :orange_circle: | Evaluate in Haskell REPL |
| haskell-mode-jump-to-def | :orange_circle: | Jump to Haskell definition |
| haskell-mode-show-type-at | :orange_circle: | Show Haskell type at point |
| scala-run-main-class | :orange_circle: | Run Scala main class |
| kotlin-send-region | :orange_circle: | Send Kotlin region to REPL |
| kotlin-send-line | :orange_circle: | Send Kotlin line to REPL |
| swift-mode-beginning-of-defun | :orange_circle: | Move to Swift function beginning |

### Round 193 — Org-babel-ext, Markdown-ext, AUCTeX, TeX-ext

| Feature | Status | Notes |
|---|---|---|
| org-babel-load-in-session | :orange_circle: | Load org-babel block in session |
| org-babel-open-src-block-result | :orange_circle: | Open source block result |
| org-table-toggle-coordinate-overlays | :orange_circle: | Toggle table coordinate overlays |
| markdown-toggle-url-hidden | :orange_circle: | Toggle URL hidden display |
| markdown-insert-gfm-checkbox | :orange_circle: | Insert GFM checkbox |
| markdown-toggle-gfm-checkbox | :orange_circle: | Toggle GFM checkbox |
| markdown-table-align | :orange_circle: | Align markdown table |
| markdown-table-sort-lines | :orange_circle: | Sort markdown table lines |
| markdown-footnote-goto-text | :orange_circle: | Jump to footnote text |
| auctex-insert-macro | :orange_circle: | Insert TeX macro |
| auctex-insert-environment | :orange_circle: | Insert TeX environment |
| auctex-font-bold | :orange_circle: | Apply bold formatting |
| auctex-font-italic | :orange_circle: | Apply italic formatting |
| auctex-compile | :orange_circle: | Compile TeX document |
| auctex-view | :orange_circle: | View compiled document |
| auctex-master-file | :orange_circle: | Set master file |
| tex-compile | :orange_circle: | Compile TeX file |
| tex-bibtex-file | :orange_circle: | Run BibTeX |
| tex-view | :orange_circle: | View TeX output |
| tex-print | :orange_circle: | Print TeX output |

### Round 192 — Ediff-ext, Smerge-ext, VC-ext, Diff-ext, Compilation-ext, Highlight-ext, Windmove-ext

| Feature | Status | Notes |
|---|---|---|
| ediff-backup | :orange_circle: | Compare with backup file |
| ediff-show-diff-output | :orange_circle: | Show raw diff output |
| ediff-toggle-multiframe | :orange_circle: | Toggle multiframe display |
| smerge-diff-base-lower | :orange_circle: | Diff between base and lower |
| smerge-diff-base-upper | :orange_circle: | Diff between base and upper |
| vc-annotate-toggle-annotation-visibility | :orange_circle: | Toggle annotation visibility |
| diff-restrict-view | :orange_circle: | Restrict view to current hunk |
| diff-ignore-whitespace-hunk | :orange_circle: | Ignore whitespace in hunk |
| compilation-next-error-function | :orange_circle: | Jump to next compilation error |
| compilation-set-skip-threshold | :orange_circle: | Set compilation skip threshold |
| recompile-with-input | :orange_circle: | Recompile with custom command |
| next-error-select-buffer | :orange_circle: | Select buffer for next-error |
| highlight-regexp-unique-match | :orange_circle: | Highlight unique regexp matches |
| highlight-lines-matching-regexp-toggle | :orange_circle: | Toggle line highlight for regexp |
| unhighlight-regexp-all | :orange_circle: | Remove all regexp highlights |
| winner-undo-more | :orange_circle: | Undo more window configurations |
| windmove-display-default-keybindings | :orange_circle: | Set windmove display keybindings |
| windmove-swap-states-default-keybindings | :orange_circle: | Set windmove swap keybindings |
| quail-define-rules | :orange_circle: | Define Quail input method rules |
| prettify-symbols-unprettify-at-point | :orange_circle: | Show unprettified symbol at point |

### Round 191 — Browse-url-ext, SHR-ext, URL-ext, Calc-ext, Eglot-ext, Electric-ext

| Feature | Status | Notes |
|---|---|---|
| browse-url-with-browser-kind | :orange_circle: | Open URL with preferred browser |
| shr-browse-image | :orange_circle: | Browse image at point in SHR |
| url-cookie-list | :orange_circle: | List URL cookies |
| url-handler-mode | :orange_circle: | Toggle URL handler mode |
| browse-url-handlers | :orange_circle: | List configured URL handlers |
| url-retrieve-synchronously-display | :orange_circle: | Retrieve and display URL |
| calc-trail-next | :orange_circle: | Move to next calc trail entry |
| calc-trail-previous | :orange_circle: | Move to previous calc trail entry |
| calc-undo-history | :orange_circle: | Show calc undo history |
| zone-when-idle | :orange_circle: | Activate zone after idle time |
| list-packages-by-status | :orange_circle: | List packages filtered by status |
| package-browse-url | :orange_circle: | Open package homepage |
| native-compile-prune-cache | :orange_circle: | Prune native compilation cache |
| emacs-lock-mode | :orange_circle: | Toggle buffer lock protection |
| consult-ripgrep-all | :orange_circle: | Ripgrep across all file types |
| xref-find-references-and-replace | :orange_circle: | Find references and replace |
| project-prompt-project-dir | :orange_circle: | Prompt for project directory |
| eglot-rename-symbol | :orange_circle: | Rename symbol via LSP |
| eglot-format-region | :orange_circle: | Format region via LSP |
| electric-pair-local-mode | :orange_circle: | Toggle electric pair local mode |

### Round 190 — CUA-ext, Repeat, Pulse, Whitespace-ext, Pixel-scroll, Context-menu, Describe-ext

| Feature | Status | Notes |
|---|---|---|
| cua-exchange-point-and-mark | :orange_circle: | Exchange point and mark in CUA mode |
| repeat-mode | :orange_circle: | Toggle repeat mode |
| pulse-momentary-highlight-one-line-at-point | :orange_circle: | Pulse highlight current line |
| whitespace-cleanup-region | :orange_circle: | Clean up whitespace in region |
| whitespace-report | :orange_circle: | Generate whitespace report for buffer |
| whitespace-report-region | :orange_circle: | Generate whitespace report for region |
| auto-revert-set-timer | :orange_circle: | Set auto-revert timer interval |
| so-long-revert | :orange_circle: | Revert so-long mode optimizations |
| pixel-scroll-precision-mode | :orange_circle: | Toggle pixel scroll precision mode |
| pixel-scroll-up | :orange_circle: | Pixel-precise scroll up |
| pixel-scroll-down | :orange_circle: | Pixel-precise scroll down |
| context-menu-mode | :orange_circle: | Toggle context menu mode |
| tab-bar-rename-tab-by-name | :orange_circle: | Rename tab by name |
| file-name-shadow-mode | :orange_circle: | Toggle file name shadow mode |
| read-only-mode-toggle-readonly | :orange_circle: | Toggle read-only state |
| describe-keymap | :orange_circle: | Describe a keymap |
| list-threads | :orange_circle: | List active threads |
| emoji-recent | :orange_circle: | Show recent emojis |
| elisp-eval-region-and-replace | :orange_circle: | Eval region and replace with result |
| checkdoc-minor-mode | :orange_circle: | Toggle checkdoc minor mode |

### Round 189 — Jinx-ext, Flyspell-ext, Langtool-ext, Wcheck

| Feature | Status | Notes |
|---|---|---|
| jinx-misspelled-first | :orange_circle: | Jump to first misspelling |
| jinx-misspelled-last | :orange_circle: | Jump to last misspelling |
| jinx-autocorrect | :orange_circle: | Auto-correct misspelled word |
| flyspell-check-previous-highlighted-word | :orange_circle: | Check previous highlighted word |
| flyspell-lazy-mode | :orange_circle: | Toggle lazy flyspell mode |
| flyspell-prog-mode | :orange_circle: | Flyspell for programming modes |
| flyspell-region | :orange_circle: | Spell-check region |
| langtool-check-buffer | :orange_circle: | Check buffer with LanguageTool |
| langtool-check-region | :orange_circle: | Check region with LanguageTool |
| langtool-correct-at-point | :orange_circle: | Correct error at point |
| langtool-show-message-at-point | :orange_circle: | Show LanguageTool message at point |
| wcheck-mode | :orange_circle: | Toggle wcheck mode |
| wcheck-jump-forward | :orange_circle: | Jump to next wcheck match |
| wcheck-jump-backward | :orange_circle: | Jump to previous wcheck match |
| wcheck-actions | :orange_circle: | Show wcheck actions |
| wcheck-change-language | :orange_circle: | Change wcheck language |
| wcheck-buffer | :orange_circle: | Check entire buffer with wcheck |
| guess-language-mode | :orange_circle: | Toggle language guessing mode |
| guess-language-mark-lines | :orange_circle: | Mark lines by language |
| guess-language-set-language | :orange_circle: | Set buffer language |

### Round 188 — Emmet, Web-mode-ext, Prettier, Tailwind

| Feature | Status | Notes |
|---|---|---|
| emmet-expand-yas | :orange_circle: | Expand Emmet with yasnippet |
| emmet-next-edit-point | :orange_circle: | Move to next edit point |
| emmet-prev-edit-point | :orange_circle: | Move to previous edit point |
| emmet-merge-lines | :orange_circle: | Merge Emmet lines |
| web-mode-element-clone | :orange_circle: | Clone HTML element |
| web-mode-element-vanish | :orange_circle: | Remove tag, keep children |
| web-mode-element-rename | :orange_circle: | Rename HTML element tag |
| web-mode-element-content-select | :orange_circle: | Select element content |
| web-mode-element-mute-blanks | :orange_circle: | Mute blanks in element |
| web-mode-tag-attributes-sort | :orange_circle: | Sort tag attributes |
| web-mode-dom-errors-show | :orange_circle: | Show DOM errors |
| web-mode-navigate | :orange_circle: | Navigate to matching tag |
| prettier-prettify | :orange_circle: | Format buffer with Prettier |
| prettier-prettify-region | :orange_circle: | Format region with Prettier |
| prettier-restart | :orange_circle: | Restart Prettier |
| tailwindcss-mode | :orange_circle: | Toggle TailwindCSS mode |
| tailwindcss-sort-classes | :orange_circle: | Sort Tailwind classes |
| tailwindcss-lookup | :orange_circle: | Lookup Tailwind class |
| tailwindcss-complete | :orange_circle: | Complete Tailwind class |
| tailwindcss-toggle-prefix | :orange_circle: | Toggle Tailwind prefix |

### Round 187 — Pass, Auth-source, Keychain, Pinentry

| Feature | Status | Notes |
|---|---|---|
| pass-mode | :orange_circle: | Toggle pass mode |
| pass-view | :orange_circle: | View pass entry |
| pass-copy | :orange_circle: | Copy pass entry to clipboard |
| pass-insert | :orange_circle: | Insert new pass entry |
| pass-generate | :orange_circle: | Generate password |
| pass-remove | :orange_circle: | Remove pass entry |
| pass-rename | :orange_circle: | Rename pass entry |
| pass-edit | :orange_circle: | Edit pass entry |
| pass-otp-append | :orange_circle: | Append OTP to entry |
| pass-otp-copy | :orange_circle: | Copy OTP token |
| pass-copy-username | :orange_circle: | Copy username from entry |
| auth-source-forget | :orange_circle: | Forget cached credentials |
| auth-source-save-behavior | :orange_circle: | Toggle save behavior |
| keychain-unlock | :orange_circle: | Unlock keychain |
| keychain-lock | :orange_circle: | Lock keychain |
| keychain-list | :orange_circle: | List keychain entries |
| keychain-refresh | :orange_circle: | Refresh keychain |
| pinentry-start | :orange_circle: | Start pinentry |
| pinentry-stop | :orange_circle: | Stop pinentry |
| pinentry-prompt | :orange_circle: | Show pinentry prompt |

### Round 186 — Systemd, Journalctl, Proced-ext, Auditd

| Feature | Status | Notes |
|---|---|---|
| systemd-start | :orange_circle: | Start systemd unit |
| systemd-stop | :orange_circle: | Stop systemd unit |
| systemd-restart | :orange_circle: | Restart systemd unit |
| systemd-enable | :orange_circle: | Enable systemd unit |
| systemd-disable | :orange_circle: | Disable systemd unit |
| systemd-reload | :orange_circle: | Systemd daemon-reload |
| systemd-journal | :orange_circle: | Open systemd journal |
| journalctl-mode | :orange_circle: | Toggle journalctl mode |
| journalctl-follow | :orange_circle: | Follow journal output |
| journalctl-boot | :orange_circle: | Show current boot log |
| journalctl-unit | :orange_circle: | Show logs for unit |
| journalctl-grep | :orange_circle: | Grep journal entries |
| proced-send-signal-with-args | :orange_circle: | Send signal with arguments |
| proced-mark-children | :orange_circle: | Mark child processes |
| proced-mark-parents | :orange_circle: | Mark parent processes |
| proced-filter-parents | :orange_circle: | Filter to parent processes |
| proced-filter-children | :orange_circle: | Filter to child processes |
| auditd-mode | :orange_circle: | Toggle auditd mode |
| auditd-search | :orange_circle: | Search audit log |
| auditd-filter | :orange_circle: | Filter audit entries |

### Round 185 — Mermaid, PlantUML-ext, Graphviz, D2, Ditaa, Gnuplot

| Feature | Status | Notes |
|---|---|---|
| mermaid-compile | :orange_circle: | Compile Mermaid diagram |
| mermaid-open-browser | :orange_circle: | Open Mermaid in browser |
| mermaid-open-doc | :orange_circle: | Open Mermaid documentation |
| plantuml-preview-buffer | :orange_circle: | Preview PlantUML buffer |
| plantuml-preview-region | :orange_circle: | Preview PlantUML region |
| plantuml-complete-symbol | :orange_circle: | Complete PlantUML symbol |
| plantuml-set-output-type | :orange_circle: | Set PlantUML output type |
| graphviz-dot-mode | :orange_circle: | Toggle Graphviz-dot mode |
| graphviz-dot-preview | :orange_circle: | Preview Graphviz graph |
| graphviz-compile | :orange_circle: | Compile Graphviz graph |
| graphviz-set-layout | :orange_circle: | Set Graphviz layout engine |
| d2-mode | :orange_circle: | Toggle D2 diagram mode |
| d2-compile | :orange_circle: | Compile D2 diagram |
| d2-open-browser | :orange_circle: | Open D2 in browser |
| d2-set-theme | :orange_circle: | Set D2 theme |
| ditaa-mode | :orange_circle: | Toggle Ditaa mode |
| ditaa-compile | :orange_circle: | Compile Ditaa diagram |
| gnuplot-mode | :orange_circle: | Toggle Gnuplot mode |
| gnuplot-send-buffer | :orange_circle: | Send buffer to Gnuplot |
| gnuplot-send-region | :orange_circle: | Send region to Gnuplot |

### Round 184 — Geiser, SLIME-ext, Cider-ext, Sly

| Feature | Status | Notes |
|---|---|---|
| geiser-doc-symbol-at-point | :orange_circle: | Geiser docs at point |
| geiser-expand-definition | :orange_circle: | Expand Geiser definition |
| geiser-squarify | :orange_circle: | Toggle square brackets |
| geiser-add-to-load-path | :orange_circle: | Add to Geiser load path |
| slime-apropos | :orange_circle: | SLIME apropos search |
| slime-hyperspec-lookup | :orange_circle: | HyperSpec lookup |
| slime-who-calls | :orange_circle: | Find callers of function |
| slime-who-references | :orange_circle: | Find references to symbol |
| slime-inspect | :orange_circle: | SLIME inspector |
| slime-who-macroexpands | :orange_circle: | Find macroexpansions |
| slime-disassemble-symbol | :orange_circle: | Disassemble symbol |
| cider-classpath | :orange_circle: | Show CIDER classpath |
| cider-browse-ns | :orange_circle: | Browse Clojure namespace |
| cider-browse-spec | :orange_circle: | Browse Clojure spec |
| cider-enlighten-mode | :orange_circle: | CIDER enlighten mode |
| cider-toggle-trace-var | :orange_circle: | Toggle var tracing |
| cider-toggle-trace-ns | :orange_circle: | Toggle namespace tracing |
| sly-stickers-toggle | :orange_circle: | Toggle Sly sticker |
| sly-mrepl-new | :orange_circle: | Open new Sly MREPL |
| sly-db-abort | :orange_circle: | Abort Sly debugger |

### Round 183 — Idris, PureScript, Elm, F#

| Feature | Status | Notes |
|---|---|---|
| idris-mode | :orange_circle: | Toggle Idris mode |
| idris-load-file | :orange_circle: | Load Idris file |
| idris-type-at-point | :orange_circle: | Show type at point |
| idris-case-split | :orange_circle: | Case split on variable |
| idris-add-clause | :orange_circle: | Add initial clause |
| idris-proof-search | :orange_circle: | Search for proof |
| purescript-mode | :orange_circle: | Toggle PureScript mode |
| purescript-build | :orange_circle: | Build PureScript project |
| purescript-repl | :orange_circle: | Start PureScript REPL |
| purescript-goto-definition | :orange_circle: | Go to definition |
| elm-mode | :orange_circle: | Toggle Elm mode |
| elm-compile-buffer | :orange_circle: | Compile Elm buffer |
| elm-format-buffer | :orange_circle: | Format Elm buffer |
| elm-test-project | :orange_circle: | Run Elm project tests |
| elm-repl | :orange_circle: | Start Elm REPL |
| fsharp-mode | :orange_circle: | Toggle F# mode |
| fsharp-build | :orange_circle: | Build F# project |
| fsharp-run | :orange_circle: | Run F# project |
| fsharp-format-buffer | :orange_circle: | Format F# buffer |
| fsharp-send-region | :orange_circle: | Send region to F# REPL |

### Round 182 — Proof-general, Coq, Lean, Agda

| Feature | Status | Notes |
|---|---|---|
| proof-general-mode | :orange_circle: | Toggle Proof General mode |
| proof-assert-next-command | :orange_circle: | Assert next proof command |
| proof-undo-last-successful-command | :orange_circle: | Undo last successful proof step |
| proof-goto-point | :orange_circle: | Process proof to point |
| proof-process-buffer | :orange_circle: | Process entire proof buffer |
| proof-retract-buffer | :orange_circle: | Retract proof buffer |
| coq-about | :orange_circle: | Coq About query |
| coq-check | :orange_circle: | Coq Check query |
| coq-print | :orange_circle: | Coq Print query |
| coq-search | :orange_circle: | Coq Search query |
| lean4-mode | :orange_circle: | Toggle Lean4 mode |
| lean4-execute | :orange_circle: | Execute Lean4 file |
| lean4-toggle-info | :orange_circle: | Toggle Lean4 info view |
| lean4-refresh-file-dependencies | :orange_circle: | Refresh Lean4 file deps |
| lean4-lake-build | :orange_circle: | Build with Lake |
| agda-mode | :orange_circle: | Toggle Agda mode |
| agda-load | :orange_circle: | Load Agda file |
| agda-give | :orange_circle: | Give solution for Agda hole |
| agda-refine | :orange_circle: | Refine Agda hole |
| agda-auto | :orange_circle: | Auto-solve Agda hole |

### Round 181 — Zig, Odin, Nim, V-lang modes

| Feature | Status | Notes |
|---|---|---|
| zig-build | :orange_circle: | Build Zig project |
| zig-test | :orange_circle: | Run Zig tests |
| zig-doc-at-point | :orange_circle: | Show Zig docs at point |
| odin-mode | :orange_circle: | Toggle Odin mode |
| odin-build | :orange_circle: | Build Odin project |
| odin-run | :orange_circle: | Run Odin project |
| odin-test | :orange_circle: | Run Odin tests |
| odin-format-buffer | :orange_circle: | Format Odin buffer |
| odin-doc-at-point | :orange_circle: | Show Odin docs at point |
| nim-mode | :orange_circle: | Toggle Nim mode |
| nim-check | :orange_circle: | Check Nim project |
| nim-suggest | :orange_circle: | Nim code suggestions |
| nim-format-buffer | :orange_circle: | Format Nim buffer |
| vlang-mode | :orange_circle: | Toggle V-lang mode |
| vlang-build | :orange_circle: | Build V-lang project |
| vlang-run | :orange_circle: | Run V-lang project |
| vlang-test | :orange_circle: | Run V-lang tests |
| vlang-format-buffer | :orange_circle: | Format V-lang buffer |
| vlang-doc | :orange_circle: | Show V-lang documentation |
| vlang-vet | :orange_circle: | Run V-lang vet linter |

### Round 180 — Nix, Guix, Bazel, CMake

| Feature | Status | Notes |
|---|---|---|
| nix-search | :orange_circle: | Search Nix packages |
| nix-flake-init | :orange_circle: | Initialize Nix flake |
| nix-store-gc | :orange_circle: | Nix store garbage collection |
| nix-env-install | :orange_circle: | Install Nix package |
| nix-env-remove | :orange_circle: | Remove Nix package |
| guix-profiles | :orange_circle: | Show Guix profiles |
| guix-installed-packages | :orange_circle: | List Guix installed packages |
| guix-available-packages | :orange_circle: | List Guix available packages |
| guix-system-reconfigure | :orange_circle: | Reconfigure Guix system |
| guix-pull | :orange_circle: | Pull Guix channel updates |
| bazel-build | :orange_circle: | Build Bazel target |
| bazel-test | :orange_circle: | Test Bazel target |
| bazel-run | :orange_circle: | Run Bazel target |
| bazel-query | :orange_circle: | Query Bazel workspace |
| bazel-clean | :orange_circle: | Clean Bazel artifacts |
| bazel-info | :orange_circle: | Show Bazel workspace info |
| cmake-configure | :orange_circle: | Configure CMake project |
| cmake-build | :orange_circle: | Build CMake project |
| cmake-build-current | :orange_circle: | Build current CMake target |
| cmake-install | :orange_circle: | Install CMake project |

### Round 179 — Restclient, Verb, Plz, Request

| Feature | Status | Notes |
|---|---|---|
| restclient-mode | :orange_circle: | Toggle restclient mode |
| restclient-http-send-current-stay-in-window | :orange_circle: | Send request, stay in window |
| restclient-jump-next | :orange_circle: | Jump to next request |
| restclient-jump-prev | :orange_circle: | Jump to previous request |
| restclient-toggle-body-visibility | :orange_circle: | Toggle body visibility |
| restclient-show-info | :orange_circle: | Show request info |
| restclient-outline-mode | :orange_circle: | Toggle restclient outline mode |
| verb-send-request-on-point-other-window | :orange_circle: | Send verb request, other window |
| verb-kill-all-response-buffers | :orange_circle: | Kill all verb response buffers |
| verb-export-request-on-point | :orange_circle: | Export verb request as curl |
| verb-set-var | :orange_circle: | Set verb variable |
| plz-get | :orange_circle: | HTTP GET with plz |
| plz-post | :orange_circle: | HTTP POST with plz |
| plz-put | :orange_circle: | HTTP PUT with plz |
| plz-delete | :orange_circle: | HTTP DELETE with plz |
| plz-head | :orange_circle: | HTTP HEAD with plz |
| plz-patch | :orange_circle: | HTTP PATCH with plz |
| request-response-header | :orange_circle: | Show response headers |
| request-abort | :orange_circle: | Abort current request |
| request-log-buffer | :orange_circle: | Show request log buffer |

### Round 178 — EUDC, LDAP, BBDB-ext, Org-contacts

| Feature | Status | Notes |
|---|---|---|
| eudc-query-form | :orange_circle: | Open EUDC query form |
| eudc-expand-inline | :orange_circle: | Expand inline EUDC query |
| eudc-get-phone | :orange_circle: | Look up phone number |
| eudc-get-email | :orange_circle: | Look up email address |
| eudc-set-server | :orange_circle: | Set EUDC server |
| eudc-hotlist-add-server | :orange_circle: | Add server to hotlist |
| eudc-hotlist-delete-server | :orange_circle: | Delete server from hotlist |
| eudc-display-records | :orange_circle: | Display EUDC records |
| ldap-search | :orange_circle: | Search LDAP directory |
| ldap-host-query | :orange_circle: | Query LDAP host |
| ldap-add-entry | :orange_circle: | Add LDAP entry |
| bbdb-mail-aliases | :orange_circle: | Show BBDB mail aliases |
| bbdb-toggle-records-layout | :orange_circle: | Toggle BBDB records layout |
| bbdb-display-current-record | :orange_circle: | Display current BBDB record |
| bbdb-copy-records-as-kill | :orange_circle: | Copy BBDB records to kill ring |
| org-contacts-find | :orange_circle: | Find org contact |
| org-contacts-complete-name | :orange_circle: | Complete contact name |
| org-contacts-export-vcard | :orange_circle: | Export contacts as vCard |
| org-contacts-import-vcard | :orange_circle: | Import vCard contacts |
| org-contacts-anniversary-list | :orange_circle: | Show anniversary list |

### Round 177 — SES, Forms-mode, Enriched-text

| Feature | Status | Notes |
|---|---|---|
| ses-mode | :orange_circle: | Toggle SES spreadsheet mode |
| ses-recalculate-all | :orange_circle: | Recalculate all SES cells |
| ses-insert-row | :orange_circle: | Insert row in SES |
| ses-insert-column | :orange_circle: | Insert column in SES |
| ses-delete-row | :orange_circle: | Delete row in SES |
| ses-delete-column | :orange_circle: | Delete column in SES |
| ses-export-tsv | :orange_circle: | Export SES as TSV |
| ses-import-tsv | :orange_circle: | Import TSV into SES |
| ses-set-cell-formula | :orange_circle: | Set cell formula |
| ses-jump-to-cell | :orange_circle: | Jump to named cell |
| forms-mode | :orange_circle: | Toggle forms editing mode |
| forms-next-record | :orange_circle: | Move to next record |
| forms-prev-record | :orange_circle: | Move to previous record |
| forms-first-record | :orange_circle: | Move to first record |
| forms-last-record | :orange_circle: | Move to last record |
| forms-search-forward | :orange_circle: | Search records forward |
| forms-insert-record | :orange_circle: | Insert new record |
| forms-delete-record | :orange_circle: | Delete record |
| enriched-toggle-markup | :orange_circle: | Toggle enriched markup display |
| enriched-set-face | :orange_circle: | Set face in enriched text |

### Round 176 — PDF-tools, DocView, Image-mode, Thumbs

| Feature | Status | Notes |
|---|---|---|
| pdf-view-printer-minor-mode | :orange_circle: | Toggle PDF printer mode |
| pdf-annot-add-highlight-markup | :orange_circle: | Add highlight annotation |
| pdf-annot-add-underline-markup | :orange_circle: | Add underline annotation |
| pdf-annot-add-strikeout-markup | :orange_circle: | Add strikeout annotation |
| pdf-annot-add-squiggly-markup | :orange_circle: | Add squiggly annotation |
| pdf-annot-edit-contents | :orange_circle: | Edit annotation contents |
| pdf-view-extract-region-image | :orange_circle: | Extract region as image |
| doc-view-continuous-mode | :orange_circle: | Toggle continuous scrolling |
| doc-view-presentation | :orange_circle: | Enter presentation mode |
| doc-view-set-slice | :orange_circle: | Set document view slice |
| doc-view-reset-slice | :orange_circle: | Reset document view slice |
| doc-view-fit-height-to-window | :orange_circle: | Fit doc height to window |
| doc-view-fit-width-to-window | :orange_circle: | Fit doc width to window |
| image-flip-horizontally | :orange_circle: | Flip image horizontally |
| image-flip-vertically | :orange_circle: | Flip image vertically |
| image-transform-set-rotation | :orange_circle: | Set image rotation angle |
| image-transform-set-scale | :orange_circle: | Set image scale factor |
| thumbs-dired-setroot | :orange_circle: | Set image as wallpaper |
| thumbs-rename-images | :orange_circle: | Batch rename images |
| thumbs-mark | :orange_circle: | Mark image in thumbs |

### Round 175 — Notmuch, Mu4e-ext, Wanderlust, Gnus-ext

| Feature | Status | Notes |
|---|---|---|
| notmuch-tree-from-search-thread | :orange_circle: | Tree view from search thread |
| notmuch-jump-search | :orange_circle: | Jump to saved search |
| notmuch-address-harvest | :orange_circle: | Harvest addresses from messages |
| notmuch-draft-save | :orange_circle: | Save notmuch draft |
| notmuch-draft-resume | :orange_circle: | Resume notmuch draft |
| notmuch-poll | :orange_circle: | Poll for new mail |
| notmuch-tag-undo | :orange_circle: | Undo last tag operation |
| mu4e-compose-edit | :orange_circle: | Edit message as new |
| mu4e-compose-resend | :orange_circle: | Resend message |
| mu4e-headers-action | :orange_circle: | Perform action on headers |
| wanderlust-goto-folder | :orange_circle: | Go to Wanderlust folder |
| wanderlust-check-all | :orange_circle: | Check all folders for new mail |
| wanderlust-draft-send | :orange_circle: | Send Wanderlust draft |
| wanderlust-summary-mark-read | :orange_circle: | Mark message as read |
| wanderlust-summary-refile | :orange_circle: | Refile message to folder |
| wanderlust-summary-delete | :orange_circle: | Mark message for deletion |
| gnus-group-catchup-current | :orange_circle: | Catch up current Gnus group |
| gnus-group-catchup-all | :orange_circle: | Catch up all Gnus groups |
| gnus-group-toggle-subscription | :orange_circle: | Toggle group subscription |
| gnus-group-make-rss-group | :orange_circle: | Create RSS group |

### Round 174 — Elfeed, Pocket-reader, Wallabag, Nov.el

| Feature | Status | Notes |
|---|---|---|
| elfeed-search-fetch | :orange_circle: | Fetch all elfeed feeds |
| elfeed-show-refresh | :orange_circle: | Refresh elfeed entry |
| elfeed-export-opml | :orange_circle: | Export feeds as OPML |
| elfeed-import-opml | :orange_circle: | Import feeds from OPML |
| pocket-reader-add-link | :orange_circle: | Add URL to Pocket |
| pocket-reader-delete | :orange_circle: | Delete Pocket item |
| pocket-reader-archive | :orange_circle: | Archive Pocket item |
| pocket-reader-favorite | :orange_circle: | Toggle Pocket favorite |
| pocket-reader-search | :orange_circle: | Search Pocket items |
| pocket-reader-open-url | :orange_circle: | Open Pocket URL in browser |
| pocket-reader-tag-add | :orange_circle: | Add tag to Pocket item |
| pocket-reader-tag-remove | :orange_circle: | Remove tag from Pocket item |
| wallabag-add-entry | :orange_circle: | Add URL to Wallabag |
| wallabag-search | :orange_circle: | Search Wallabag entries |
| wallabag-show-entry | :orange_circle: | Show Wallabag entry |
| wallabag-full-entry | :orange_circle: | Show full Wallabag content |
| wallabag-delete-entry | :orange_circle: | Delete Wallabag entry |
| nov-bookmark-jump | :orange_circle: | Jump to EPUB bookmark |
| nov-render-document | :orange_circle: | Render EPUB document |
| nov-copy-url | :orange_circle: | Copy EPUB URL |

### Round 173 — Treemacs, Neotree, Dired-sidebar

| Feature | Status | Notes |
|---|---|---|
| treemacs-find-file | :orange_circle: | Find current file in treemacs |
| treemacs-find-tag | :orange_circle: | Find current tag in treemacs |
| treemacs-show-changelog | :orange_circle: | Show treemacs changelog |
| treemacs-bookmark | :orange_circle: | Bookmark treemacs node |
| treemacs-rename-file | :orange_circle: | Rename file in treemacs |
| treemacs-delete-file | :orange_circle: | Delete file in treemacs |
| treemacs-move-file | :orange_circle: | Move file in treemacs |
| treemacs-copy-file | :orange_circle: | Copy file in treemacs |
| treemacs-copy-path | :orange_circle: | Copy path to clipboard |
| treemacs-copy-project-path | :orange_circle: | Copy project path to clipboard |
| treemacs-collapse-all-projects | :orange_circle: | Collapse all treemacs projects |
| neotree-stretch-toggle | :orange_circle: | Toggle neotree window width |
| neotree-create-node | :orange_circle: | Create node in neotree |
| neotree-delete-node | :orange_circle: | Delete node in neotree |
| neotree-rename-node | :orange_circle: | Rename node in neotree |
| neotree-copy-node | :orange_circle: | Copy node in neotree |
| neotree-enter | :orange_circle: | Enter node in neotree |
| dired-sidebar-show-sidebar | :orange_circle: | Show dired sidebar |
| dired-sidebar-follow-file | :orange_circle: | Follow current file in sidebar |
| dired-sidebar-jump | :orange_circle: | Jump to current dir in sidebar |

### Round 172 — Helpful, Elisp-refs, Macrostep, Inspector

| Feature | Status | Notes |
|---|---|---|
| helpful-callable | :orange_circle: | Show help for callable symbol |
| helpful-key | :orange_circle: | Show help for key binding |
| helpful-variable | :orange_circle: | Show help for variable |
| helpful-update | :orange_circle: | Update helpful buffer |
| helpful-visit-reference | :orange_circle: | Visit reference at point |
| elisp-refs-special | :orange_circle: | Find references to special form |
| elisp-refs-read | :orange_circle: | Find read references to symbol |
| elisp-refs-widget | :orange_circle: | Find widget references |
| macrostep-collapse | :orange_circle: | Collapse macro expansion |
| macrostep-prev-macro | :orange_circle: | Move to previous macro |
| macrostep-next-macro | :orange_circle: | Move to next macro |
| macrostep-mode | :orange_circle: | Toggle macrostep mode |
| macrostep-environment | :orange_circle: | Show expansion environment |
| inspector-inspect | :orange_circle: | Inspect an object |
| inspector-pop | :orange_circle: | Pop to previous inspected object |
| inspector-quit | :orange_circle: | Quit inspector |
| inspector-next-reference | :orange_circle: | Move to next reference |
| inspector-inspect-expression | :orange_circle: | Inspect arbitrary expression |
| inspector-inspect-last-sexp | :orange_circle: | Inspect last sexp |
| inspector-copy-down | :orange_circle: | Copy inspected object down |

### Round 171 — Selectrum, Icomplete-ext, Mct, Ivy-posframe

| Feature | Status | Notes |
|---|---|---|
| selectrum-prescient-mode | :orange_circle: | Prescient scoring in Selectrum |
| selectrum-cycle | :orange_circle: | Cycle Selectrum candidates |
| selectrum-toggle-display | :orange_circle: | Toggle Selectrum display style |
| selectrum-repeat | :orange_circle: | Repeat last Selectrum selection |
| icomplete-toggle-prefix | :orange_circle: | Toggle prefix display in icomplete |
| icomplete-force-complete | :orange_circle: | Force icomplete completion |
| icomplete-minibuffer-setup | :orange_circle: | Setup icomplete in minibuffer |
| mct-mode | :orange_circle: | Toggle Mct completion mode |
| mct-minibuffer-mode | :orange_circle: | Mct in minibuffer only |
| mct-region-mode | :orange_circle: | Mct in region completion |
| mct-toggle-completions | :orange_circle: | Toggle Mct completions display |
| ivy-posframe-mode | :orange_circle: | Show Ivy in posframe popup |
| ivy-posframe-display-at-frame-center | :orange_circle: | Posframe at frame center |
| ivy-posframe-display-at-point | :orange_circle: | Posframe at point |
| ivy-posframe-display-at-window-center | :orange_circle: | Posframe at window center |
| mini-frame-show-parameters | :orange_circle: | Show mini-frame parameters |
| ivy-rich-mode | :orange_circle: | Rich annotations in Ivy |
| ivy-rich-modify-columns | :orange_circle: | Modify Ivy-rich columns |
| ivy-rich-set-display-transformer | :orange_circle: | Set Ivy-rich display transformer |
| all-the-icons-ivy-rich-mode | :orange_circle: | Icons in Ivy-rich annotations |

### Round 170 — Marginalia, Orderless, Prescient, Hotfuzz

| Feature | Status | Notes |
|---|---|---|
| marginalia-mode | :orange_circle: | Toggle rich annotations in minibuffer |
| marginalia-cycle | :orange_circle: | Cycle marginalia annotation style |
| marginalia-classify-by-command-name | :orange_circle: | Classify candidates by command name |
| marginalia-classify-by-prompt | :orange_circle: | Classify candidates by prompt text |
| orderless-define-completion-style | :orange_circle: | Define orderless completion style |
| orderless-compile | :orange_circle: | Compile orderless pattern |
| orderless-highlight-matches | :orange_circle: | Highlight orderless matches |
| orderless-filter | :orange_circle: | Filter candidates with orderless |
| prescient-persist-mode | :orange_circle: | Persist prescient frequency data |
| prescient-toggle-fuzzy | :orange_circle: | Toggle fuzzy matching in prescient |
| prescient-sort-full-match | :orange_circle: | Sort by full match in prescient |
| prescient-reset-frequency | :orange_circle: | Reset prescient frequency data |
| hotfuzz-mode | :orange_circle: | Toggle hotfuzz completion |
| hotfuzz-highlight | :orange_circle: | Highlight hotfuzz matches |
| hotfuzz-all-completions | :orange_circle: | Compute all hotfuzz completions |
| hotfuzz-filter | :orange_circle: | Filter with hotfuzz algorithm |
| fussy-mode | :orange_circle: | Toggle fussy completion scoring |
| fussy-score | :orange_circle: | Compute fussy score |
| flx-score | :orange_circle: | Compute flx flex score |
| flx-ido-mode | :orange_circle: | Toggle flx scoring in ido |

### Round 169 — Nerd-icons, All-the-icons, SVG-lib, Ligature

| Feature | Status | Notes |
|---|---|---|
| nerd-icons-install-fonts | :orange_circle: | Install Nerd Font icon fonts |
| nerd-icons-insert | :orange_circle: | Insert a Nerd Font icon by name |
| nerd-icons-icon-for-mode | :orange_circle: | Get icon for a given major mode |
| nerd-icons-icon-for-file | :orange_circle: | Get icon for a given filename |
| nerd-icons-icon-for-dir | :orange_circle: | Get icon for a given directory |
| nerd-icons-icon-for-buffer | :orange_circle: | Get icon for current buffer |
| all-the-icons-icon-for-mode | :orange_circle: | Get all-the-icons icon for mode |
| all-the-icons-icon-for-file | :orange_circle: | Get all-the-icons icon for file |
| all-the-icons-icon-for-dir | :orange_circle: | Get all-the-icons icon for dir |
| all-the-icons-icon-for-buffer | :orange_circle: | Get all-the-icons icon for buffer |
| all-the-icons-insert | :orange_circle: | Insert an all-the-icons icon |
| svg-lib-tag | :orange_circle: | Create SVG tag element |
| svg-lib-progress-bar | :orange_circle: | Create SVG progress bar |
| svg-lib-icon | :orange_circle: | Create SVG icon element |
| ligature-set-ligatures | :orange_circle: | Configure ligature mappings |
| text-scale-mode | :orange_circle: | Toggle text scaling mode |
| nerd-icons-completion-mode | :orange_circle: | Nerd icons in completion UI |
| nerd-icons-ibuffer-mode | :orange_circle: | Nerd icons in ibuffer |
| all-the-icons-completion-mode | :orange_circle: | All-the-icons in completion UI |
| global-ligature-mode | :orange_circle: | Toggle global ligature display |

### Round 168 — Tempel, Yasnippet Extended, Auto-yasnippet

| Feature | Status | Notes |
|---|---|---|
| `tempel-abort` | :orange_circle: | Abort template |
| `tempel-done` | :orange_circle: | Done with template |
| `yas-tryout-snippet` | :orange_circle: | Try snippet in scratch |
| `yas-describe-tables` | :orange_circle: | Describe snippet tables |
| `yas-load-snippet-buffer` | :orange_circle: | Load from buffer |
| `yas-load-snippet-buffer-and-close` | :orange_circle: | Load and close |
| `yas-skip-and-clear-field` | :orange_circle: | Skip and clear field |
| `yas-clear-field` | :orange_circle: | Clear current field |
| `yas-exit-all-snippets` | :orange_circle: | Exit all snippets |
| `yas-abort-snippet` | :orange_circle: | Abort snippet |
| `yas-minor-mode` | :orange_circle: | YAS minor mode |
| `auto-yasnippet-create` | :orange_circle: | Create auto-snippet |
| `auto-yasnippet-expand` | :orange_circle: | Expand auto-snippet |
| `auto-yasnippet-persist` | :orange_circle: | Persist auto-snippet |
| `yas-recompile-all` | :orange_circle: | Recompile all |
| `yas-reload-all` | :orange_circle: | Reload all snippets |
| `yas-activate-extra-mode` | :orange_circle: | Activate extra mode |
| `yas-deactivate-extra-mode` | :orange_circle: | Deactivate extra mode |
| `yas-visit-snippet-file` | :orange_circle: | Visit snippet file |
| `yas-compile-directory` | :orange_circle: | Compile directory |

### Round 167 — Dirvish, Peep-dired, Fd-dired, Wdired

| Feature | Status | Notes |
|---|---|---|
| `dirvish` | :orange_circle: | Directory browser |
| `dirvish-side` | :orange_circle: | Side panel |
| `dirvish-fd` | :orange_circle: | Fd search |
| `dirvish-dispatch` | :orange_circle: | Dispatch menu |
| `dirvish-quick-access` | :orange_circle: | Quick access |
| `dirvish-history-jump` | :orange_circle: | History jump |
| `dirvish-layout-toggle` | :orange_circle: | Toggle layout |
| `dirvish-layout-switch` | :orange_circle: | Switch layout |
| `dirvish-emerge` | :orange_circle: | Emerge session |
| `dirvish-emerge-mode` | :orange_circle: | Emerge mode |
| `dirvish-yank` | :orange_circle: | Yank files |
| `dirvish-copy-file-path` | :orange_circle: | Copy file path |
| `dirvish-copy-file-name` | :orange_circle: | Copy file name |
| `dirvish-subtree-toggle` | :orange_circle: | Toggle subtree |
| `peep-dired` | :orange_circle: | Preview mode |
| `peep-dired-scroll-page-down` | :orange_circle: | Scroll preview down |
| `peep-dired-scroll-page-up` | :orange_circle: | Scroll preview up |
| `fd-dired` | :orange_circle: | fd search in dired |
| `fd-find-dired` | :orange_circle: | fd find-dired |
| `wdired-abort-changes` | :orange_circle: | Abort wdired changes |

### Round 166 — Pulsar, Lin, Modus/Ef/Doom Themes

| Feature | Status | Notes |
|---|---|---|
| `pulsar-highlight-line` | :orange_circle: | Highlight current line |
| `pulsar-recenter-top` | :orange_circle: | Recenter top + pulse |
| `pulsar-recenter-middle` | :orange_circle: | Recenter middle + pulse |
| `lin-mode` | :orange_circle: | Enhanced hl-line mode |
| `lin-global-mode` | :orange_circle: | Global lin mode |
| `modus-themes-select` | :orange_circle: | Select modus theme |
| `modus-themes-preview-colors` | :orange_circle: | Preview colors |
| `modus-themes-list-colors` | :orange_circle: | List colors |
| `ef-themes-toggle` | :orange_circle: | Toggle light/dark |
| `ef-themes-preview-colors` | :orange_circle: | Preview colors |
| `ef-themes-list-colors` | :orange_circle: | List colors |
| `doom-themes-treemacs-config` | :orange_circle: | Treemacs theming |
| `doom-themes-org-config` | :orange_circle: | Org-mode theming |
| `doom-themes-visual-bell-config` | :orange_circle: | Visual bell config |
| `doom-themes-neotree-config` | :orange_circle: | Neotree theming |
| `doom-themes-set-faces` | :orange_circle: | Set custom faces |
| `circadian-setup` | :orange_circle: | Time-based theme switching |
| `heaven-and-hell-toggle-theme` | :orange_circle: | Toggle light/dark |
| `theme-buffet-timer-mode` | :orange_circle: | Auto-rotate themes |
| `theme-buffet-a-la-carte` | :orange_circle: | Select theme by period |

### Round 165 — CUA Rectangles, Picture Mode, Artist Mode

| Feature | Status | Notes |
|---|---|---|
| `cua-sequence-rectangle` | :orange_circle: | Sequence rectangle |
| `cua-fill-char-rectangle` | :orange_circle: | Fill rectangle with char |
| `cua-incr-rectangle` | :orange_circle: | Increment rectangle values |
| `cua-replace-in-rectangle` | :orange_circle: | Replace in rectangle |
| `cua-rotate-rectangle` | :orange_circle: | Rotate rectangle |
| `cua-open-rectangle` | :orange_circle: | Open rectangle |
| `cua-close-rectangle` | :orange_circle: | Close rectangle |
| `cua-copy-rectangle` | :orange_circle: | Copy rectangle |
| `cua-cut-rectangle` | :orange_circle: | Cut rectangle |
| `cua-paste-rectangle` | :orange_circle: | Paste rectangle |
| `picture-forward-column` | :orange_circle: | Forward column |
| `picture-backward-column` | :orange_circle: | Backward column |
| `picture-open-line` | :orange_circle: | Open line |
| `artist-mode` | :orange_circle: | ASCII drawing mode |
| `artist-select-op-line` | :orange_circle: | Draw line |
| `artist-select-op-rectangle` | :orange_circle: | Draw rectangle |
| `artist-select-op-ellipse` | :orange_circle: | Draw ellipse |
| `artist-select-op-circle` | :orange_circle: | Draw circle |
| `artist-select-op-text` | :orange_circle: | Insert text |
| `artist-select-op-spray-can` | :orange_circle: | Spray can |

### Round 164 — Abbrev, Skeleton, Tempo, Auto-insert, BS

| Feature | Status | Notes |
|---|---|---|
| `add-global-abbrev` | :orange_circle: | Add global abbrev |
| `add-mode-abbrev` | :orange_circle: | Add mode-specific abbrev |
| `skeleton-pair-insert-maybe` | :orange_circle: | Insert matching pair |
| `define-skeleton` | :orange_circle: | Define new skeleton |
| `tempo-complete-tag` | :orange_circle: | Complete tempo tag |
| `tempo-define-template` | :orange_circle: | Define tempo template |
| `tempo-insert-template` | :orange_circle: | Insert tempo template |
| `tempo-use-tag-list` | :orange_circle: | Use tag list |
| `auto-insert` | :orange_circle: | Auto-insert template |
| `define-auto-insert` | :orange_circle: | Define auto-insert rule |
| `hippie-expand-try-functions-list` | :orange_circle: | Show try-functions |
| `insert-abbrev-table-description` | :orange_circle: | Insert table description |
| `abbrev-table-name` | :orange_circle: | Show table name |
| `clear-abbrev-table` | :orange_circle: | Clear abbrev table |
| `msb-mode` | :orange_circle: | Mouse select buffer mode |
| `bs-show` | :orange_circle: | Buffer selection |
| `bs-cycle-next` | :orange_circle: | Next buffer |
| `bs-cycle-previous` | :orange_circle: | Previous buffer |
| `buffer-menu-other-window` | :orange_circle: | Buffer menu other window |
| `electric-buffer-list` | :orange_circle: | Electric buffer list |

### Round 163 — Icomplete, Minibuffer, Recentf Extended

| Feature | Status | Notes |
|---|---|---|
| `icomplete-fido-mode` | :orange_circle: | Fido completion mode |
| `icomplete-fido-vertical-mode` | :orange_circle: | Fido vertical mode |
| `minibuffer-complete` | :orange_circle: | Complete in minibuffer |
| `minibuffer-complete-word` | :orange_circle: | Complete word |
| `minibuffer-completion-help` | :orange_circle: | Show completion help |
| `minibuffer-force-complete` | :orange_circle: | Force complete |
| `minibuffer-force-complete-and-exit` | :orange_circle: | Force complete and exit |
| `minibuffer-beginning-of-buffer` | :orange_circle: | Beginning of minibuffer |
| `minibuffer-keyboard-quit` | :orange_circle: | Keyboard quit |
| `exit-minibuffer` | :orange_circle: | Exit minibuffer |
| `minibuffer-electric-default-mode` | :orange_circle: | Electric default mode |
| `minibuffer-depth-indicate-mode` | :orange_circle: | Depth indicate mode |
| `minibuffer-next-completion` | :orange_circle: | Next completion |
| `recentf-open-more-files` | :orange_circle: | Show more recent files |
| `recentf-load-list` | :orange_circle: | Load file list |
| `recentf-edit-list` | :orange_circle: | Edit file list |
| `recentf-dialog` | :orange_circle: | Open recentf dialog |
| `recentf-track-opened-file` | :orange_circle: | Track opened file |
| `read-extended-command` | :orange_circle: | Read extended command |
| `execute-extended-command-for-buffer` | :orange_circle: | Execute for buffer |

### Round 162 — Origami, Vimish-fold, Yafolding, Indirect-buffer

| Feature | Status | Notes |
|---|---|---|
| `origami-previous-fold` | :orange_circle: | Previous fold |
| `origami-undo` | :orange_circle: | Undo fold action |
| `origami-redo` | :orange_circle: | Redo fold action |
| `origami-reset` | :orange_circle: | Reset all folds |
| `yafolding-toggle-all` | :orange_circle: | Toggle all folds |
| `yafolding-toggle-element` | :orange_circle: | Toggle element fold |
| `yafolding-show-all` | :orange_circle: | Show all folds |
| `yafolding-hide-all` | :orange_circle: | Hide all folds |
| `vimish-fold` | :orange_circle: | Create fold from region |
| `vimish-fold-unfold` | :orange_circle: | Unfold at point |
| `vimish-fold-unfold-all` | :orange_circle: | Unfold all |
| `vimish-fold-delete` | :orange_circle: | Delete fold |
| `vimish-fold-delete-all` | :orange_circle: | Delete all folds |
| `vimish-fold-toggle` | :orange_circle: | Toggle fold |
| `vimish-fold-toggle-all` | :orange_circle: | Toggle all folds |
| `vimish-fold-next-fold` | :orange_circle: | Next fold |
| `vimish-fold-previous-fold` | :orange_circle: | Previous fold |
| `vimish-fold-avy` | :orange_circle: | Avy jump to fold |
| `clone-indirect-buffer-other-window` | :orange_circle: | Clone indirect buffer |
| `make-indirect-buffer` | :orange_circle: | Make indirect buffer |

### Round 161 — Ediff, Emerge, Compare-windows Extended

| Feature | Status | Notes |
|---|---|---|
| `ediff-files3` | :orange_circle: | 3-way file comparison |
| `ediff-buffers3` | :orange_circle: | 3-way buffer comparison |
| `ediff-directories3` | :orange_circle: | 3-way directory comparison |
| `ediff-regions-wordwise` | :orange_circle: | Word-by-word region compare |
| `ediff-patch-buffer` | :orange_circle: | Patch buffer |
| `ediff-merge-files-with-ancestor` | :orange_circle: | Merge with ancestor |
| `ediff-merge-revisions` | :orange_circle: | Merge revisions |
| `ediff-documentation` | :orange_circle: | Ediff documentation |
| `ediff-version` | :orange_circle: | Ediff version |
| `ediff-toggle-autorefine` | :orange_circle: | Toggle auto-refine |
| `ediff-toggle-hilit` | :orange_circle: | Toggle highlighting |
| `ediff-toggle-skip-similar-regions` | :orange_circle: | Toggle skip similar |
| `ediff-next-difference` | :orange_circle: | Next difference |
| `ediff-previous-difference` | :orange_circle: | Previous difference |
| `ediff-jump-to-difference` | :orange_circle: | Jump to difference # |
| `ediff-copy-A-to-B` | :orange_circle: | Copy region A to B |
| `ediff-copy-B-to-A` | :orange_circle: | Copy region B to A |
| `emerge-files-with-ancestor` | :orange_circle: | Emerge with ancestor |
| `compare-windows` | :orange_circle: | Compare visible windows |
| `diff-latest-backup-file` | :orange_circle: | Diff with latest backup |

### Round 160 — Outline, Origami Folding

| Feature | Status | Notes |
|---|---|---|
| `outline-minor-mode` | :orange_circle: | Outline minor mode |
| `outline-hide-entry` | :orange_circle: | Hide entry body |
| `outline-show-entry` | :orange_circle: | Show entry body |
| `outline-hide-leaves` | :orange_circle: | Hide leaves |
| `outline-show-branches` | :orange_circle: | Show branches |
| `outline-hide-other` | :orange_circle: | Hide everything else |
| `outline-show-children` | :orange_circle: | Show direct children |
| `outline-mark-subtree` | :orange_circle: | Mark subtree |
| `outline-move-subtree-up` | :orange_circle: | Move subtree up |
| `outline-move-subtree-down` | :orange_circle: | Move subtree down |
| `outline-promote` | :orange_circle: | Promote heading |
| `outline-demote` | :orange_circle: | Demote heading |
| `origami-toggle-node` | :orange_circle: | Toggle fold |
| `origami-toggle-all-nodes` | :orange_circle: | Toggle all folds |
| `origami-close-node` | :orange_circle: | Close fold |
| `origami-open-node` | :orange_circle: | Open fold |
| `origami-close-all-nodes` | :orange_circle: | Close all folds |
| `origami-open-all-nodes` | :orange_circle: | Open all folds |
| `origami-show-only-node` | :orange_circle: | Show only current |
| `origami-next-fold` | :orange_circle: | Next fold |

### Round 159 — Magit, Git-link, Blamer, Smerge Extended

| Feature | Status | Notes |
|---|---|---|
| `magit-merge` | :orange_circle: | Merge branch |
| `magit-merge-abort` | :orange_circle: | Abort merge |
| `magit-merge-squash` | :orange_circle: | Squash merge |
| `git-link-commit` | :orange_circle: | Copy commit URL |
| `git-link-homepage` | :orange_circle: | Copy repo homepage URL |
| `git-messenger-popup-message` | :orange_circle: | Show commit message for line |
| `git-messenger-popup-diff` | :orange_circle: | Show diff for commit |
| `git-messenger-popup-show` | :orange_circle: | Show full commit info |
| `blamer-mode` | :orange_circle: | Inline git blame mode |
| `blamer-show-commit-info` | :orange_circle: | Show commit info |
| `blamer-show-posframe-commit-info` | :orange_circle: | Show in posframe |
| `magit-delta-mode` | :orange_circle: | Syntax highlighting in diffs |
| `magit-todos-mode` | :orange_circle: | Show TODOs in magit |
| `magit-todos-list` | :orange_circle: | List all TODOs |
| `git-auto-commit-mode` | :orange_circle: | Auto-commit on save |
| `smerge-resolve` | :orange_circle: | Resolve conflict |
| `smerge-ediff` | :orange_circle: | Ediff for conflict |
| `smerge-combine-with-next` | :orange_circle: | Combine with next conflict |
| `smerge-refine` | :orange_circle: | Word-level diff |
| `smerge-auto-leave` | :orange_circle: | Auto-leave when resolved |

### Round 158 — Jinx, Flycheck, Flymake, Langtool, Writegood

| Feature | Status | Notes |
|---|---|---|
| `jinx-mode` | :orange_circle: | Jinx spell-checking mode |
| `jinx-correct` | :orange_circle: | Correct at point |
| `jinx-correct-all` | :orange_circle: | Correct all misspellings |
| `jinx-correct-nearest` | :orange_circle: | Correct nearest |
| `jinx-correct-word` | :orange_circle: | Correct word at point |
| `jinx-next` | :orange_circle: | Next misspelling |
| `jinx-previous` | :orange_circle: | Previous misspelling |
| `jinx-add-to-dictionary` | :orange_circle: | Add to dictionary |
| `jinx-ignore` | :orange_circle: | Ignore word |
| `flycheck-first-error` | :orange_circle: | First error |
| `flycheck-last-error` | :orange_circle: | Last error |
| `flycheck-version` | :orange_circle: | Show version |
| `flycheck-manual` | :orange_circle: | Open manual |
| `flycheck-display-error-explanation` | :orange_circle: | Error explanation |
| `flycheck-mode-line-status-text` | :orange_circle: | Mode line status |
| `flymake-running-backends` | :orange_circle: | Running backends |
| `flymake-reporting-backends` | :orange_circle: | Reporting backends |
| `langtool-switch-default-language` | :orange_circle: | Switch language |
| `writegood-grade-level` | :orange_circle: | Compute grade level |
| `writegood-reading-ease` | :orange_circle: | Compute reading ease |

### Round 157 — Org-babel, Org-present, Org-tree-slide, Org-reveal, Org-download

| Feature | Status | Notes |
|---|---|---|
| `org-babel-insert-header-arg` | :orange_circle: | Insert header argument |
| `org-babel-view-src-block-info` | :orange_circle: | View source block info |
| `org-babel-demarcate-block` | :orange_circle: | Demarcate/split block |
| `org-babel-goto-named-src-block` | :orange_circle: | Go to named block |
| `org-babel-goto-named-result` | :orange_circle: | Go to named result |
| `org-present-beginning` | :orange_circle: | First slide |
| `org-present-end` | :orange_circle: | Last slide |
| `org-present-big` | :orange_circle: | Increase text size |
| `org-present-small` | :orange_circle: | Decrease text size |
| `org-tree-slide-mode` | :orange_circle: | Tree-slide presentation mode |
| `org-tree-slide-move-next-tree` | :orange_circle: | Next tree/slide |
| `org-tree-slide-move-previous-tree` | :orange_circle: | Previous tree/slide |
| `org-tree-slide-content` | :orange_circle: | Content overview |
| `org-tree-slide-play-with-timer` | :orange_circle: | Auto-play with timer |
| `org-reveal-export-to-html` | :orange_circle: | Export to reveal.js |
| `org-download-delete` | :orange_circle: | Delete downloaded file |
| `org-download-rename-at-point` | :orange_circle: | Rename downloaded file |
| `org-download-edit` | :orange_circle: | Edit image at point |
| `org-download-enable` | :orange_circle: | Enable drag-and-drop |
| `org-download-image` | :orange_circle: | Download image from URL |

### Round 156 — Popper, Shackle, Hydra, Transient Extended

| Feature | Status | Notes |
|---|---|---|
| `popper-toggle-latest` | :orange_circle: | Toggle latest popup |
| `popper-cycle` | :orange_circle: | Cycle popups |
| `popper-toggle-type` | :orange_circle: | Toggle popup type |
| `popper-kill-latest-popup` | :orange_circle: | Kill latest popup |
| `popper-raise-popup` | :orange_circle: | Raise popup to window |
| `popper-lower-popup` | :orange_circle: | Lower window to popup |
| `shackle-mode` | :orange_circle: | Window rule enforcement |
| `shackle-last-popup-buffer` | :orange_circle: | Show last popup buffer |
| `ace-popup-menu-mode` | :orange_circle: | Ace popup menu mode |
| `hydra-zoom/body` | :orange_circle: | Zoom hydra menu |
| `hydra-window/body` | :orange_circle: | Window hydra menu |
| `hydra-navigate/body` | :orange_circle: | Navigation hydra menu |
| `hydra-toggle/body` | :orange_circle: | Toggle hydra menu |
| `hydra-apropos/body` | :orange_circle: | Apropos hydra menu |
| `hydra-buffer-menu/body` | :orange_circle: | Buffer hydra menu |
| `transient-history-prev` | :orange_circle: | Previous transient history |
| `transient-history-next` | :orange_circle: | Next transient history |
| `transient-suffix-put` | :orange_circle: | Modify suffix property |
| `transient-toggle-level-limit` | :orange_circle: | Toggle level limit |
| `transient-set-level` | :orange_circle: | Set transient level |

### Round 155 — Embark, Consult, Vertico, Corfu, Cape Extended

| Feature | Status | Notes |
|---|---|---|
| `embark-dwim` | :orange_circle: | Do-what-I-mean action |
| `embark-export` | :orange_circle: | Export candidates to buffer |
| `embark-live` | :orange_circle: | Live updating collect |
| `embark-become` | :orange_circle: | Become different command |
| `embark-select` | :orange_circle: | Select candidate |
| `embark-prefix-help-command` | :orange_circle: | Prefix key help |
| `consult-grep` | :orange_circle: | Grep with consult |
| `consult-git-grep` | :orange_circle: | Git-grep with consult |
| `consult-register-store` | :orange_circle: | Store to register |
| `consult-register-load` | :orange_circle: | Load from register |
| `vertico-indexed-mode` | :orange_circle: | Indexed candidate mode |
| `vertico-mouse-mode` | :orange_circle: | Mouse support |
| `vertico-quick-jump` | :orange_circle: | Quick jump to candidate |
| `vertico-quick-insert` | :orange_circle: | Quick insert candidate |
| `corfu-echo-mode` | :orange_circle: | Echo area completion info |
| `cape-file` | :orange_circle: | File name completion |
| `cape-elisp-symbol` | :orange_circle: | Elisp symbol completion |
| `cape-rfc1345` | :orange_circle: | RFC 1345 char completion |
| `cape-emoji` | :orange_circle: | Emoji completion |
| `cape-ispell` | :orange_circle: | Ispell completion |

### Round 154 — Dired-subtree, Dired-filter, Dired Extensions

| Feature | Status | Notes |
|---|---|---|
| `dired-subtree-cycle` | :orange_circle: | Cycle subtree visibility |
| `dired-subtree-up` | :orange_circle: | Move to parent |
| `dired-subtree-down` | :orange_circle: | Move to first child |
| `dired-subtree-beginning` | :orange_circle: | Beginning of subtree |
| `dired-subtree-end` | :orange_circle: | End of subtree |
| `dired-subtree-mark-subtree` | :orange_circle: | Mark all in subtree |
| `dired-subtree-unmark-subtree` | :orange_circle: | Unmark all in subtree |
| `dired-ranger-bookmark` | :orange_circle: | Bookmark directory |
| `dired-ranger-bookmark-visit` | :orange_circle: | Visit bookmark |
| `dired-filter-by-mode` | :orange_circle: | Filter by mode |
| `dired-filter-by-symlink` | :orange_circle: | Filter by symlinks |
| `dired-filter-by-git-ignored` | :orange_circle: | Filter git-ignored |
| `dired-filter-save-filters` | :orange_circle: | Save filters |
| `dired-filter-load-saved-filters` | :orange_circle: | Load saved filters |
| `dired-rsync-transient` | :orange_circle: | Rsync transient menu |
| `dired-preview-global-mode` | :orange_circle: | Global preview mode |
| `dired-icon-mode` | :orange_circle: | File icons mode |
| `dired-rainbow-mode` | :orange_circle: | Colorize by extension |
| `dired-recent-mode` | :orange_circle: | Recent directories |
| `dired-sidebar-toggle-sidebar` | :orange_circle: | Toggle sidebar |

### Round 153 — Eshell, Shell-pop, Vterm, Eat, Coterm

| Feature | Status | Notes |
|---|---|---|
| `eshell-search-input` | :orange_circle: | Search eshell history |
| `eshell-bol` | :orange_circle: | Move to beginning of input |
| `eshell-mark-output` | :orange_circle: | Mark last output |
| `eshell-kill-output` | :orange_circle: | Kill last output |
| `eshell-insert-envvar` | :orange_circle: | Insert environment variable |
| `eshell-toggle-direct-send` | :orange_circle: | Toggle direct send |
| `eshell-repeat-argument` | :orange_circle: | Repeat last argument |
| `eshell-life-is-too-much` | :orange_circle: | Kill eshell buffer |
| `eshell-intercept-commands` | :orange_circle: | Intercept commands mode |
| `eshell-delete-process` | :orange_circle: | Delete background process |
| `shell-pop-universal-key` | :orange_circle: | Toggle shell popup |
| `shell-pop-eshell` | :orange_circle: | Toggle eshell popup |
| `shell-pop-vterm` | :orange_circle: | Toggle vterm popup |
| `vterm-copy-mode-done` | :orange_circle: | Exit vterm copy mode |
| `vterm-reset-cursor-point` | :orange_circle: | Reset cursor to prompt |
| `eat-other-window` | :orange_circle: | Eat terminal in other window |
| `eat-emacs-mode` | :orange_circle: | Eat Emacs mode |
| `coterm-mode` | :orange_circle: | Coterm mode |
| `coterm-auto-char-mode` | :orange_circle: | Coterm auto-char mode |
| `coterm-char-mode` | :orange_circle: | Coterm char mode |

### Round 152 — Evil Extended, Viper, Meow, Boon

| Feature | Status | Notes |
|---|---|---|
| `evil-replace-state` | :orange_circle: | Enter replace state |
| `evil-emacs-state` | :orange_circle: | Enter Emacs state |
| `evil-motion-state` | :orange_circle: | Enter motion state |
| `evil-operator-state` | :orange_circle: | Enter operator-pending state |
| `evil-jump-forward` | :orange_circle: | Jump forward in jump list |
| `evil-jump-backward` | :orange_circle: | Jump backward in jump list |
| `evil-record-macro` | :orange_circle: | Record macro to register |
| `evil-execute-macro` | :orange_circle: | Execute macro from register |
| `evil-open-above` | :orange_circle: | Open line above |
| `evil-open-below` | :orange_circle: | Open line below |
| `evil-join` | :orange_circle: | Join lines |
| `evil-shift-left` | :orange_circle: | Shift region left |
| `evil-shift-right` | :orange_circle: | Shift region right |
| `evil-indent` | :orange_circle: | Indent region |
| `evil-toggle-fold` | :orange_circle: | Toggle fold |
| `evil-scroll-up` | :orange_circle: | Scroll up half page |
| `viper-mode` | :orange_circle: | Vi emulation mode |
| `meow-normal-mode` | :orange_circle: | Meow normal mode |
| `meow-insert-mode` | :orange_circle: | Meow insert mode |
| `boon-command-state` | :orange_circle: | Boon command state |

### Round 151 — Avy Extended, Wgrep, Deadgrep, Color-rg

| Feature | Status | Notes |
|---|---|---|
| `avy-goto-char-timer` | :orange_circle: | Avy jump with timer |
| `avy-goto-word-or-subword-1` | :orange_circle: | Jump to word/subword |
| `avy-goto-line-above` | :orange_circle: | Jump to line above |
| `avy-goto-line-below` | :orange_circle: | Jump to line below |
| `avy-org-goto-heading-timer` | :orange_circle: | Jump to org heading |
| `wgrep-change-to-wgrep-mode` | :orange_circle: | Writable grep mode |
| `wgrep-finish-edit` | :orange_circle: | Apply wgrep edits |
| `wgrep-mark-deletion` | :orange_circle: | Mark for deletion |
| `wgrep-remove-change` | :orange_circle: | Remove change at point |
| `wgrep-remove-all-change` | :orange_circle: | Remove all changes |
| `wgrep-toggle-readonly-area` | :orange_circle: | Toggle readonly |
| `deadgrep-edit-mode` | :orange_circle: | Deadgrep edit mode |
| `deadgrep-kill-process` | :orange_circle: | Kill search process |
| `deadgrep-restart` | :orange_circle: | Restart search |
| `deadgrep-toggle-file-results` | :orange_circle: | Toggle file results |
| `deadgrep-directory` | :orange_circle: | Set search directory |
| `deadgrep-search-term` | :orange_circle: | Set search term |
| `color-rg-search-symbol` | :orange_circle: | Search symbol at point |
| `color-rg-search-input-in-project` | :orange_circle: | Search in project |
| `color-rg-search-input-in-current-file` | :orange_circle: | Search in current file |

### Round 150 — AUCTeX, RefTeX, CDLaTeX, Preview-latex

| Feature | Status | Notes |
|---|---|---|
| `TeX-insert-macro` | :orange_circle: | Insert TeX macro |
| `TeX-insert-quote` | :orange_circle: | Smart quote insertion |
| `TeX-font` | :orange_circle: | Apply font command |
| `LaTeX-fill-paragraph` | :orange_circle: | Fill LaTeX paragraph |
| `LaTeX-mark-section` | :orange_circle: | Mark section |
| `LaTeX-mark-environment` | :orange_circle: | Mark environment |
| `reftex-citation` | :orange_circle: | Insert citation |
| `reftex-reference` | :orange_circle: | Insert reference |
| `reftex-label` | :orange_circle: | Insert label |
| `reftex-toc` | :orange_circle: | Table of contents |
| `reftex-index` | :orange_circle: | Insert index entry |
| `reftex-view-crossref` | :orange_circle: | View cross-reference |
| `cdlatex-mode` | :orange_circle: | CDLaTeX minor mode |
| `cdlatex-tab` | :orange_circle: | CDLaTeX tab expansion |
| `cdlatex-environment` | :orange_circle: | Insert environment |
| `preview-buffer` | :orange_circle: | Preview buffer |
| `preview-region` | :orange_circle: | Preview region |
| `preview-at-point` | :orange_circle: | Preview at point |
| `preview-clearout` | :orange_circle: | Clear previews |
| `preview-document` | :orange_circle: | Preview entire document |

### Round 149 — Semantic, CEDET, EDE, Senator

| Feature | Status | Notes |
|---|---|---|
| `semantic-ia-complete-symbol` | :orange_circle: | Complete symbol at point |
| `semantic-decoration-mode` | :orange_circle: | Tag decoration mode |
| `semantic-highlight-func-mode` | :orange_circle: | Highlight current function |
| `semantic-stickyfunc-mode` | :orange_circle: | Sticky function header |
| `semantic-idle-summary-mode` | :orange_circle: | Idle summary in echo area |
| `semantic-idle-completions-mode` | :orange_circle: | Idle completions |
| `semantic-force-refresh` | :orange_circle: | Force-refresh tags |
| `semantic-chart-database-size` | :orange_circle: | Chart database size |
| `semantic-adebug-bovinate` | :orange_circle: | Debug parse tree |
| `senator-jump` | :orange_circle: | Jump to tag |
| `senator-transpose-tags` | :orange_circle: | Transpose tags |
| `senator-fold-tag-toggle` | :orange_circle: | Toggle tag fold |
| `ede-new` | :orange_circle: | Create new EDE project |
| `ede-compile-project` | :orange_circle: | Compile project |
| `ede-debug-target` | :orange_circle: | Debug target |
| `ede-make-dist` | :orange_circle: | Create distribution |
| `ede-find-file` | :orange_circle: | Find file in project |
| `ede-edit-file-target` | :orange_circle: | Edit file's target |
| `ede-add-file` | :orange_circle: | Add file to target |
| `ede-remove-file` | :orange_circle: | Remove file from target |

### Round 148 — CC-mode, Python, SQL Extended

| Feature | Status | Notes |
|---|---|---|
| `c-toggle-syntactic-indentation` | :orange_circle: | Toggle syntactic indentation |
| `c-indent-line-or-region` | :orange_circle: | Indent line or region |
| `c-fill-paragraph` | :orange_circle: | Fill paragraph/comment |
| `c-context-line-break` | :orange_circle: | Context-aware line break |
| `c-macro-expand` | :orange_circle: | Expand macro at point |
| `c-backslash-region` | :orange_circle: | Align backslashes |
| `c-down-conditional` | :orange_circle: | Move to nested conditional |
| `c-indent-exp` | :orange_circle: | Indent balanced expression |
| `c-show-syntactic-information` | :orange_circle: | Show syntactic info |
| `python-shell-switch-to-shell` | :orange_circle: | Switch to Python shell |
| `python-shell-completion-native-turn-on` | :orange_circle: | Enable native completion |
| `python-indent-shift-left` | :orange_circle: | Shift region left |
| `python-indent-shift-right` | :orange_circle: | Shift region right |
| `python-nav-backward-defun` | :orange_circle: | Navigate backward defun |
| `python-nav-forward-defun` | :orange_circle: | Navigate forward defun |
| `python-nav-backward-up-list` | :orange_circle: | Navigate backward up list |
| `python-skeleton-class` | :orange_circle: | Insert class skeleton |
| `python-skeleton-def` | :orange_circle: | Insert def skeleton |
| `python-skeleton-for` | :orange_circle: | Insert for skeleton |
| `python-skeleton-if` | :orange_circle: | Insert if skeleton |

### Round 147 — ELP, Trace, Debugger, Edebug, ERT, Testcover

| Feature | Status | Notes |
|---|---|---|
| `elp-restore-all` | :orange_circle: | Restore all ELP-instrumented functions |
| `trace-function-foreground` | :orange_circle: | Trace function in foreground |
| `trace-function-background` | :orange_circle: | Trace function in background |
| `cancel-edebug-on-entry` | :orange_circle: | Cancel edebug-on-entry |
| `cancel-debug-on-variable-change` | :orange_circle: | Cancel variable watch |
| `backtrace-toggle-locals` | :orange_circle: | Toggle locals in backtrace |
| `debugger-step-through` | :orange_circle: | Step through in debugger |
| `debugger-continue` | :orange_circle: | Continue execution |
| `debugger-return-value` | :orange_circle: | Return value from frame |
| `debugger-frame` | :orange_circle: | Show current frame |
| `ert-run-tests-batch` | :orange_circle: | Run ERT tests in batch |
| `ert-results-rerun-test-at-point` | :orange_circle: | Rerun test at point |
| `testcover-start` | :orange_circle: | Start testcover instrumentation |
| `testcover-mark-all` | :orange_circle: | Mark all uncovered forms |
| `testcover-next-mark` | :orange_circle: | Next uncovered mark |
| `benchmark-progn` | :orange_circle: | Benchmark expression |
| `debug-on-message` | :orange_circle: | Break on matching message |
| `edebug-remove-instrumentation` | :orange_circle: | Remove edebug instrumentation |
| `edebug-next-breakpoint` | :orange_circle: | Next edebug breakpoint |
| `edebug-step-in` | :orange_circle: | Step into function |

### Round 146 — ERC Extended, Rcirc, SX, Debbugs, Bug-hunter, Misc

| Feature | Status | Notes |
|---|---|---|
| `erc-stamp-mode` | :orange_circle: | ERC timestamp mode |
| `erc-services-mode` | :orange_circle: | NickServ auto-identify |
| `erc-truncate-mode` | :orange_circle: | Truncate long buffers |
| `erc-netsplit-mode` | :orange_circle: | Netsplit detection |
| `erc-ring-mode` | :orange_circle: | Input history ring |
| `erc-pcomplete-mode` | :orange_circle: | Programmable completion |
| `erc-move-to-prompt-mode` | :orange_circle: | Auto-move to prompt |
| `erc-noncommands-mode` | :orange_circle: | Hide non-commands |
| `erc-readonly-mode` | :orange_circle: | Read-only channel buffers |
| `erc-irccontrols-mode` | :orange_circle: | IRC control codes |
| `rcirc-track-minor-mode` | :orange_circle: | Track rcirc activity |
| `rcirc-multiline-minor-mode` | :orange_circle: | Multiline input |
| `sx-ask` | :orange_circle: | Ask on Stack Exchange |
| `sx-inbox` | :orange_circle: | SX inbox notifications |
| `debbugs-gnu-search` | :orange_circle: | Search GNU bug tracker |
| `bug-hunter-init-file` | :orange_circle: | Bisect init file |
| `bug-hunter-file` | :orange_circle: | Bisect arbitrary file |
| `explain-pause-mode` | :orange_circle: | Profile slow commands |
| `explain-pause-top` | :orange_circle: | Show top slow commands |
| `clm-open-command-log-buffer` | :orange_circle: | Open command log buffer |

### Round 145 — BBDB, Message Mode, Newsticker, SMTP

| Feature | Status | Notes |
|---|---|---|
| `bbdb-search-name` | :orange_circle: | Search BBDB by name |
| `bbdb-search-organization` | :orange_circle: | Search BBDB by organization |
| `bbdb-search-mail` | :orange_circle: | Search BBDB by email |
| `bbdb-search-phone` | :orange_circle: | Search BBDB by phone |
| `bbdb-search-notes` | :orange_circle: | Search BBDB by notes |
| `bbdb-display-all-records` | :orange_circle: | Display all BBDB records |
| `bbdb-mail` | :orange_circle: | Compose mail to BBDB record |
| `bbdb-merge-records` | :orange_circle: | Merge duplicate records |
| `bbdb-delete-field-or-record` | :orange_circle: | Delete field or record |
| `message-send` | :orange_circle: | Send message |
| `message-send-and-exit` | :orange_circle: | Send and kill buffer |
| `message-kill-buffer` | :orange_circle: | Kill message buffer |
| `message-cite-original` | :orange_circle: | Cite original message |
| `message-insert-signature` | :orange_circle: | Insert signature |
| `message-mark-inserted-region` | :orange_circle: | Mark inserted region |
| `message-tab` | :orange_circle: | Tab completion in message |
| `newsticker-mark-item-at-point-as-read` | :orange_circle: | Mark news item as read |
| `newsticker-browse-url` | :orange_circle: | Browse news item URL |
| `smtp-send-it` | :orange_circle: | Send via SMTP |
| `smtpmail-send-queued-mail` | :orange_circle: | Send queued mail |

### Round 144 — EWW, SHR, Browse-url, Tramp, Net-utils

| Feature | Status | Notes |
|---|---|---|
| `eww-list-buffers` | :orange_circle: | List EWW buffers |
| `eww-view-source` | :orange_circle: | View page source |
| `eww-switch-to-buffer` | :orange_circle: | Switch to EWW buffer |
| `shr-save-contents` | :orange_circle: | Save rendered contents |
| `shr-tag-img` | :orange_circle: | Render image tag |
| `shr-render-buffer` | :orange_circle: | Render buffer as HTML |
| `shr-insert-image` | :orange_circle: | Insert image from URL |
| `shr-zoom-image` | :orange_circle: | Zoom image |
| `browse-url-of-buffer` | :orange_circle: | Open buffer URL in browser |
| `browse-url-of-dired-file` | :orange_circle: | Open dired file in browser |
| `browse-url-emacs` | :orange_circle: | Open URL in EWW |
| `browse-url-xdg-open` | :orange_circle: | Open URL with xdg-open |
| `browse-url-generic` | :orange_circle: | Open URL with generic browser |
| `browse-url-kde` | :orange_circle: | Open URL with KDE browser |
| `tramp-archive-cleanup-hash` | :orange_circle: | Clean up TRAMP archive hash |
| `tramp-version` | :orange_circle: | Show TRAMP version |
| `tramp-bug` | :orange_circle: | Prepare TRAMP bug report |
| `ftp` | :orange_circle: | FTP client |
| `dig` | :orange_circle: | DNS lookup with dig |
| `iwconfig` | :orange_circle: | Wireless configuration |

### Round 143 — Calc Extended, Prodigy, Forge, Games/Fun

| Feature | Status | Notes |
|---|---|---|
| `calc-algebraic-mode` | :orange_circle: | Toggle algebraic entry mode in Calc |
| `calc-radix-mode` | :orange_circle: | Set display radix (2/8/10/16) |
| `calc-graph-fast` | :orange_circle: | Quick graph of expression |
| `calc-convert-units` | :orange_circle: | Unit conversion in Calc |
| `calc-undo` | :orange_circle: | Undo last Calc operation |
| `calc-redo` | :orange_circle: | Redo last Calc operation |
| `calc-last-args` | :orange_circle: | Recall last arguments |
| `calc-store` | :orange_circle: | Store to variable |
| `calc-recall` | :orange_circle: | Recall from variable |
| `calc-reset` | :orange_circle: | Reset Calc stack |
| `prodigy` | :orange_circle: | Prodigy service manager |
| `prodigy-start` | :orange_circle: | Start a service |
| `prodigy-stop` | :orange_circle: | Stop a service |
| `prodigy-restart` | :orange_circle: | Restart a service |
| `prodigy-browse` | :orange_circle: | Browse service in browser |
| `forge-pull` | :orange_circle: | Pull forge notifications |
| `forge-browse-issues` | :orange_circle: | Browse issues in browser |
| `animate-birthday-present` | :orange_circle: | Birthday animation |
| `nato-region` | :orange_circle: | NATO phonetic alphabet |
| `fortune-message` | :orange_circle: | Display a fortune |

---

## Recommended Development Roadmap

> *Reprioritized based on the user's actual Emacs workflow*

### Phase 1: Core Interaction (Make Jemacs Feel Right)
1. **Completion popup (Corfu equivalent)** — Inline completion overlay at point. The user uses Corfu in Emacs. Without this, code editing is painful.
2. **LSP UI wiring** — Connect the existing LSP transport to: completion (popup), hover (echo area), goto-definition, find-references, diagnostics display. The user has eglot working in Emacs for Chez Scheme.
3. ~~Narrowing framework (Helm-like)~~ — ~~A candidate selection UI for M-x, switch-buffer, find-file, grep results.~~ Done: Full Helm framework with 14 commands, multi-match engine (AND tokens, `!` negation, `^` prefix), 10 built-in sources, TUI+Qt renderers, session resume, helm-mode toggle.

### Phase 2: Development Workflow
4. **Magit interactive status** — The user runs Magit daily. At minimum: status buffer with file-level staging/unstaging, commit composition, diff viewing with hunk navigation.
5. **Multi-terminal** — Multi-vterm equivalent: create/switch/close terminals, copy mode. The user has key-chords for this (MT, LK, JK).
6. **iedit / edit occurrences** — Select symbol, edit all occurrences in buffer. The user has iedit installed.
7. **expand-region** — Incrementally expand selection (word → sexp → defun → buffer). The user has this installed.
8. ~~Dired batch operations~~ — ~~Operate on marked files (delete, rename, copy). Currently single-file only.~~ Done: mark/unmark, batch delete/copy/rename, mark-by-regexp, toggle-marks, wdired.

### Phase 3: Polish & Power Features
9. **AI integration** — Copilot mode, inline suggestions, code explain/refactor all scaffolded. Needs API key configuration for real AI provider connection.
10. **Snippet system** — YASnippet equivalent with tabstop navigation. The user has snippets + file-templates enabled.
11. ~~Flyspell~~ — ~~Background spell checking.~~ Done: `flyspell-mode` with aspell backend, squiggle indicators (TUI), word-list reporting (Qt).
12. ~~Bracket/paren swap~~ — ~~Input-level key remapping.~~ Done: `toggle-bracket-paren-swap` uses key-translate system in both TUI and Qt.
13. ~~DevOps syntax modes~~ — ~~At minimum: Terraform, Ansible, Docker highlighting via Scintilla lexers.~~ Done: Terraform/HCL (`.tf`, `.tfvars`, `.hcl`) via C lexer; Docker/Ansible already covered (bash/YAML).
14. ~~EditorConfig support~~ — ~~Read `.editorconfig` files for indent style/size.~~ Done: auto-applied on `find-file` in Qt, manual `editorconfig-apply` in TUI.

### Phase 4: Ecosystem
15. **Extension API** — A well-documented API for users to write custom modes in Chez Scheme. The user wrote 28 custom Elisp modes; they'll want to do the same in Chez Scheme.
16. ~~Interactive ediff~~ — ~~Hunk navigation and merge resolution.~~ Done: smerge-mode with conflict marker resolution.
17. ~~Tab bar / workspaces~~ — ~~Named workspaces (the user has DOOM workspaces enabled).~~ Done: workspace tabs with create/close/switch/rename/move in both layers.
18. **TRAMP-like remote editing** — SSH/Docker file editing.
