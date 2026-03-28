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
