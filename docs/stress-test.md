# Stress Test & Crash Reporting Infrastructure

## Problem

jemacs-qt segfaults in production use. The static binary provides no diagnostic
information — it just dies. We need two things:

1. **Crash reporting** — when a segfault happens, capture useful diagnostics
   before dying (which FFI call, backtrace, editor state).
2. **Automated stress testing** — a burn-in harness that exercises the editor
   heavily and continuously until it crashes, without human interaction.

## Architecture Overview

```
┌─────────────────────┐     TCP (REPL)     ┌──────────────────────────┐
│  stress-test.ss     │ ────────────────── │  jemacs-qt --repl 9999  │
│  (controller)       │    eval commands   │  under gdb              │
│                     │ ◄────────────────  │                         │
│  Logs every command │    results/errors  │  SIGSEGV handler:       │
│  to stress.log      │                    │  - backtrace            │
└─────────────────────┘                    │  - FFI call ring buffer │
                                           │  - crash log file       │
                                           └──────────────────────────┘
```

## Part 1: SIGSEGV Crash Reporter (C++ shim)

### Design

Added to `vendor/qt_shim.cpp`, the crash reporter has three components:

#### 1. FFI Call Ring Buffer

A lock-free ring buffer (64 entries) records the name of every FFI function as it
enters and exits. When a segfault occurs, the last ~64 FFI calls are available
for inspection.

```c
#define CRASH_RING_SIZE 64
static struct {
    const char* func_name;
    int         entering;  // 1 = enter, 0 = exit
    uint64_t    timestamp; // CLOCK_MONOTONIC nanoseconds
} s_crash_ring[CRASH_RING_SIZE];
static atomic_int s_crash_ring_idx = 0;
```

Every FFI function entry/exit goes through:
```c
static inline void crash_ring_push(const char* fn, int entering) {
    int idx = atomic_fetch_add(&s_crash_ring_idx, 1) % CRASH_RING_SIZE;
    s_crash_ring[idx] = { fn, entering, now_ns() };
}
```

#### 2. SIGSEGV Handler

Installed at startup via `sigaction(SIGSEGV, ...)`. On crash:

1. Writes crash report to `~/.jemacs-crash.log` (using only async-signal-safe
   functions: `write()`, `open()`, no `fprintf`/`malloc`)
2. Captures native backtrace via `backtrace()` (glibc) — not strictly
   async-signal-safe but works in practice and we're dying anyway
3. Dumps the FFI call ring buffer showing what was happening
4. Re-raises SIGSEGV with default handler so gdb/core dump still works

#### 3. Integration with QT_VOID / QT_RETURN macros

The existing `QT_VOID` / `QT_RETURN` macros that marshal calls to the Qt thread
are augmented with `crash_ring_push()` calls, so every cross-thread FFI dispatch
is logged. Zero overhead when no crash occurs (just an atomic increment per call).

### What the crash log looks like

```
=== JEMACS CRASH REPORT ===
Signal: SIGSEGV (addr: 0x0000000000000018)
Time: 2026-03-31T15:42:07

FFI Call Ring (most recent last):
  [  0] ENTER qt_scintilla_set_text        +0.000ms
  [  1] EXIT  qt_scintilla_set_text        +0.152ms
  [  2] ENTER qt_scintilla_get_length      +0.003ms
  [  3] EXIT  qt_scintilla_get_length      +0.089ms
  [  4] ENTER qt_splitter_add_widget       +0.001ms  ← LAST ENTRY (still inside)

Native backtrace:
  #0  0x7f3a2b1c4e00 in QSplitter::insertWidget()
  #1  0x5555556789ab in qt_splitter_add_widget()
  #2  0x555555612345 in ...
  ...

Written to: /home/user/.jemacs-crash.log
```

### Why not full recovery?

We considered using `siglongjmp` to recover from segfaults and convert them to
Scheme exceptions. This is **unsafe** for mutating Qt calls because:

- C++ destructors won't run (RAII violations)
- Qt's internal widget tree may be in an inconsistent state
- Subsequent Qt calls would cascade into more crashes

For **read-only** FFI calls (getters), recovery would be safe but the
complexity isn't worth it yet. The crash log gives us what we need to fix the
root cause.

## Part 2: Stress Test Driver

### Design

`tests/stress-test.ss` is a Scheme script that connects to jemacs-qt's debug
REPL over TCP and drives random editor operations in a continuous loop.

#### Phases (run in rotation)

**Phase 1: Window Chaos**
- `split-window` / `split-window-right` / `split-window-below`
- `delete-window` / `delete-other-windows`
- `other-window` (cycle through splits)
- `balance-windows`
- `toggle-fullscreen`
- Random sequences of 5-15 operations

**Phase 2: Vterm Storm**
- Open 3-5 vterm buffers
- Send shell commands: `find /usr -ls`, `top -b -n 5`, `ls -laR /tmp`,
  `yes | head -10000`
- Let them run concurrently while doing other operations
- Kill vterm buffers randomly

**Phase 3: File Churn**
- Create temp files with random content
- Open them with `find-file` (via eval, bypassing echo-area prompts)
- Insert large text blocks, navigate around
- Copy/paste between buffers (kill-region + yank in another)
- Save, revert, kill buffers

**Phase 4: Navigation Stress**
- Rapid cursor movement: forward-char, next-line, scroll-up/down
- goto-line to random positions
- beginning-of-buffer / end-of-buffer
- mark-whole-buffer, kill-region, undo

**Phase 5: EWW (Web Browser)**
- Open `eww` with simple URLs (localhost, file:// paths)
- Navigate, switch between eww and editor buffers

**Phase 6: Combined Chaos**
- All phases interleaved randomly
- Random delays between 0ms and 500ms
- Window splits + vterms + file edits simultaneously

#### Controller Architecture

```scheme
;; Connect to REPL
(def conn (tcp-connect "127.0.0.1" repl-port))

;; Send command and log it
(def (stress-cmd! cmd)
  (log! cmd)
  (send-eval conn (format "(execute-command! *app* '~a)" cmd))
  (read-response conn))

;; Send raw eval (for commands that need arguments)
(def (stress-eval! expr)
  (log! expr)
  (send-eval conn expr)
  (read-response conn))

;; Main loop
(def (stress-loop!)
  (let loop ((cycle 0))
    (displayln "=== Cycle " cycle " ===")
    (phase-window-chaos!)
    (phase-vterm-storm!)
    (phase-file-churn!)
    (phase-navigation-stress!)
    (phase-eww!)
    (phase-combined-chaos!)
    (loop (+ cycle 1))))
```

#### Command Execution Strategy

Commands that normally prompt for user input (like `find-file`) can't be used
directly through `execute-command!` since there's no one to answer the
minibuffer prompt. Instead, we eval the underlying operations directly:

```scheme
;; Instead of (execute-command! *app* 'find-file) which prompts:
(stress-eval! "(let ((path \"/tmp/stress-test-1.txt\"))
                 (write-file-string path \"test content\")
                 (qt-open-file! *app* path))")

;; Instead of vterm which might prompt:
(stress-eval! "(cmd-vterm *app*)")
```

#### Logging

Every command sent is logged with timestamp to `stress-test.log`:

```
[2026-03-31T15:42:07.123] SEND: (execute-command! *app* 'split-window-right)
[2026-03-31T15:42:07.125] RECV: ok
[2026-03-31T15:42:07.200] SEND: (execute-command! *app* 'vterm)
[2026-03-31T15:42:07.450] RECV: ok
[2026-03-31T15:42:07.451] SEND: (execute-command! *app* 'other-window)
...
[2026-03-31T15:42:12.891] SEND: (execute-command! *app* 'delete-window)
[2026-03-31T15:42:12.892] CONNECTION LOST — jemacs-qt likely crashed
```

When the connection drops, the last N commands in the log show what triggered
the crash. Combined with the crash report in `~/.jemacs-crash.log`, this gives
a complete picture.

## Part 3: Running the Stress Test

### Quick start

```bash
# Terminal 1: Run jemacs-qt under gdb
make stress-run

# Terminal 2: Run the stress test driver
make stress-test
```

### Makefile targets

```makefile
# Launch jemacs-qt under gdb with REPL enabled, virtual display
stress-run:
    xvfb-run -a gdb -ex run \
        -ex 'handle SIGALRM nostop noprint' \
        -ex 'bt' -ex 'thread apply all bt' \
        --args ./jemacs-qt --repl 9999

# Run the stress test driver (connects to running jemacs-qt)
stress-test:
    scheme --libdirs lib:... --script tests/stress-test.ss --port 9999

# All-in-one: launch jemacs-qt in background, run stress test
stress-burn:
    # Launches both, runs until crash, prints diagnostics
```

### Under gdb

When the segfault hits, gdb catches it and you get:
1. **gdb backtrace** — full native stack trace with debug symbols
2. **~/.jemacs-crash.log** — FFI call ring buffer showing which Scheme→C
   boundary was active
3. **stress-test.log** — the exact sequence of editor commands that triggered it

### Iterative debugging workflow

1. Run `make stress-burn`
2. Wait for crash (minutes to hours)
3. Examine crash log + gdb backtrace + stress log
4. Fix the bug
5. `make static-qt` to rebuild
6. Repeat from step 1

Over time, the stress test becomes a regression suite — crashes that took
minutes to find initially should never reappear.

## Part 4: Future Enhancements

- **Crash log viewer** — `M-x jemacs-crash-report` to view last crash in-editor
- **Minimizer** — binary-search the stress log to find minimal repro sequence
- **Coverage tracking** — track which commands have been exercised, bias toward
  under-tested ones
- **Deterministic replay** — seed the PRNG so crash sequences are reproducible
- **Memory sanitizer** — run under ASan/UBSan for the dynamic build to catch
  issues before they become segfaults
