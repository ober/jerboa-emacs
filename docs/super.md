# Chez Scheme Superpowers in jemacs-qt

These are capabilities that Emacs Lisp **cannot do** — they exist only because jemacs runs on Chez Scheme, a world-class native-code Scheme compiler with SMP threads, first-class continuations, and a rich runtime.

---

## 1. True SMP Parallelism

**What**: Real OS threads via `make-thread` / `thread-start!` / `thread-join!`.

**Why it matters**: Emacs is single-threaded. When Emacs runs `grep` or `git status`, the entire editor freezes. In jemacs, blocking work runs in background threads while the UI stays responsive.

**Commands that use it**:
- `find-file-parallel` — glob + load files across threads simultaneously
- `magit-status-fast` — runs 4 git commands in parallel (status, branch, log, stash) instead of sequentially
- `parallel-grep` — shards file search across CPU cores
- `parallel-word-count` — counts words across all buffers concurrently
- `project-statistics` — tallies files/lines/words across a project in parallel
- `fan-out-search` — bounded worker pool (max 8 threads) for large file sets

---

## 2. Preemptive Engines (Time-Sliced Eval)

**What**: `make-engine` wraps any computation in a fuel-budgeted, preemptible container. Run it for N ticks; if it doesn't finish, get back a resumable engine.

**Why it matters**: Emacs `eval-expression` can hang the editor forever on an infinite loop. jemacs engines **guarantee** the UI never freezes — eval runs for a tiny slice per frame, yielding back to Qt between slices.

**Commands that use it**:
- `eval-region` — evaluates selected code via engine; UI stays responsive during long computations
- `fuel-eval` — explicit fuel budget; expression is preempted if it exceeds the budget
- `describe-symbol` — introspects symbols via engine-sliced eval

---

## 3. First-Class Continuations (call/cc)

**What**: `call/cc` captures the exact execution state. `dynamic-wind` ensures cleanup runs on any exit path.

**Why it matters**: Emacs `keyboard-quit` uses `throw`/`catch` which can only unwind — it can't capture arbitrary points. jemacs continuations enable instant, clean abort from any depth.

**Commands that use it**:
- `keyboard-quit-abort` — instantly aborts any running command via saved continuation
- `with-abortable-command` — wraps any command to make it cancellable
- Lazy file generator — closure-based generators that suspend/resume file reading

---

## 4. Software Transactional Memory (STM)

**What**: `make-tvar`, `atomically`, `tvar-read`, `tvar-write!`, `retry`, `or-else` — composable transactions over shared mutable state.

**Why it matters**: Emacs has no concurrent state management at all. STM lets multiple threads read/write shared variables without deadlocks or race conditions. Transactions compose — unlike locks, you can combine two STM operations into one atomic operation.

**Commands that use it**:
- `set-buffer-var` / `get-buffer-var` — per-buffer transactional variables, safe to read from any thread

---

## 5. Clojure-Style Atoms (Thread-Safe Reactive State)

**What**: `atom`, `atom-deref`, `atom-swap!`, `atom-compare-and-set!`, `atom-add-watch!` — mutable references with automatic watcher notification.

**Why it matters**: Emacs variables are global and unprotected. Atoms are thread-safe and reactive — when a value changes, all registered watchers fire automatically. No manual polling, no forgotten hook calls.

**Commands that use it**:
- `atom-set` / `atom-get` — editor-wide reactive variables
- `atom-watch` — attach a watcher that logs every change
- `atomic-counter` — zero-allocation thread-safe ID generation (`generate-id` command)
- File indexer and git watcher use atoms internally for state

---

## 6. Go-Style Channels

**What**: `make-channel`, `channel-put`, `channel-get`, `channel-try-get`, `channel-close` — bounded, typed message-passing between threads with backpressure.

**Why it matters**: Emacs has no inter-thread communication primitive. Channels enable the producer/consumer pattern: a background thread can push results to the UI thread safely, with automatic flow control when the consumer is slower than the producer.

**Commands that use it**:
- `channel-grep` — producer pushes grep matches through a channel pipeline
- The entire UI action queue (`ui-queue-push!` / `ui-queue-drain!`) is a channel
- Fan-out/fan-in pattern: work items distributed via channel, results gathered via channel

---

## 7. Priority Queue Scheduling

**What**: `make-pqueue`, `pqueue-push!`, `pqueue-pop!` — min-heap priority queue.

**Why it matters**: Emacs commands execute in FIFO order. jemacs can prioritize commands — urgent operations run first regardless of when they were queued.

**Commands that use it**:
- `schedule-command` — queue a command with a priority number
- `run-scheduled` — execute the highest-priority queued command
- `list-scheduled` — see all queued commands in priority order

---

## 8. Red-Black Tree Bookmarks

**What**: `make-rbtree`, `rbtree-put!`, `rbtree-ref`, `rbtree-for-each` — balanced binary search tree with O(log n) operations.

**Why it matters**: Emacs stores marks/bookmarks in a flat alist — O(n) lookup. jemacs uses a red-black tree keyed by buffer position — O(log n) insert, lookup, and ordered traversal. Bookmarks are always sorted by position automatically.

**Commands that use it**:
- `bookmark-set-rbtree` — set a named bookmark at cursor position
- `bookmark-list-rbtree` — list all bookmarks in position order (in-order traversal)
- `bookmark-jump-rbtree` — jump to a bookmark by name

---

## 9. Read-Write Locks

**What**: `make-rwlock`, `with-read-lock`, `with-write-lock` — multiple concurrent readers, exclusive writer.

**Why it matters**: Emacs is single-threaded so it doesn't need locking. jemacs has real threads, so buffer metadata needs protection. Read-write locks allow many threads to read metadata simultaneously while ensuring writes are exclusive.

**Commands that use it**:
- `set-metadata` / `get-metadata` — write-locked set, read-locked get for buffer metadata

---

## 10. Completion Tokens (Async Futures)

**What**: `make-completion`, `completion-post!`, `completion-wait!` — one-shot synchronization primitive.

**Why it matters**: Like Java's `CompletableFuture` or Go's single-use result channel. Start a computation, continue doing other work, then wait for the result only when you need it.

**Commands that use it**:
- `future-eval` — evaluate in background, get result when ready
- `timed-eval` — evaluate with a 5-second wall-clock timeout using competing completion posts (computation vs timeout thread)

---

## 11. LRU Cache

**What**: `make-lru-cache`, `lru-cache-get`, `lru-cache-put!` — bounded, thread-safe memoization with automatic eviction.

**Why it matters**: Emacs caches either leak memory forever or need manual pruning timers. jemacs LRU caches have a fixed capacity — when full, the least-recently-used entry is evicted automatically.

**Commands that use it**:
- `cached-read-file` — file content cache (64 entries max)
- `clear-file-cache` / `file-cache-stats` — cache management

---

## 12. Weak-Key Hashtables

**What**: `make-weak-eq-hashtable` — hash table where keys are weakly held.

**Why it matters**: When a buffer or window object is garbage-collected, its cache entries disappear automatically. No memory leaks from stale references. Emacs has no weak references.

**Used by**: Buffer metadata caches, parsed AST caches, any per-object memoization.

---

## 13. Guardians (GC-Triggered Cleanup)

**What**: `make-guardian` — register objects for notification when they're garbage-collected.

**Why it matters**: When a buffer holding a PTY file descriptor is GC'd without explicit cleanup, the fd leaks. Guardians catch this — the master timer drains collected objects and runs their cleanup thunks.

**Used by**: `register-for-cleanup!` / `drain-guardians!` — called every master timer tick.

---

## 14. JIT Compilation

**What**: `(compile expr)` — compile a Scheme expression to native x86-64 machine code at runtime.

**Why it matters**: Emacs `eval` interprets bytecode. Chez `compile` generates native code — user-defined commands run at C speed.

**Commands that use it**:
- `eval-expression-compiled` — JIT compile before eval
- `define-command` — user-defined commands are compiled to native code

---

## 15. Disassembly

**What**: `(disassemble proc)` — show the x86-64 assembly generated by Chez for any procedure.

**Why it matters**: You can see exactly what machine code Chez generated. No other editor can show you the assembly of its own commands.

**Commands that use it**:
- `disassemble` — view native assembly for any procedure

---

## 16. Nondeterministic Search (amb)

**What**: `begin-amb`, `amb`, `amb-assert`, `amb-collect` — automatic backtracking search.

**Why it matters**: The `amb` operator picks values nondeterministically and backtracks on failure. It's Scheme's answer to Prolog — you describe constraints and the system finds solutions. Emacs has no backtracking search.

**Commands that use it**:
- `amb-eval` — find one solution to a constraint problem
- `amb-find-all` — find all solutions via `amb-collect`

---

## 17. Lazy Evaluation

**What**: `delay`, `force`, `lazy` — promises with proper tail recursion and memoization.

**Why it matters**: Compute values only when needed. The result is cached — subsequent `force` calls return instantly. Enables infinite data structures and demand-driven computation.

**Commands that use it**:
- `lazy-eval` — demonstrate memoized lazy promises
- `view-file-lazy` / `view-file-next-page` — lazy file viewer, O(1) memory

---

## 18. Runtime Introspection

**What**: `(statistics)`, `(scheme-version)`, `(procedure-arity-mask)`, `(inspect/object)`, `environment-symbols`, `(profile-dump-html)`.

**Why it matters**: Chez exposes deep runtime information — GC counts, memory allocation, procedure arities, object structure, symbol tables. Emacs introspection is limited to its Lisp layer.

**Commands that use it**:
- `runtime-stats` / `runtime-stats-buffer` — GC/memory/CPU statistics
- `benchmark-expression` — precise timing with `(statistics)` before/after
- `profile-buffer` — HTML profiling report
- `describe-symbol` — live arity/type introspection
- `inspect-expression` — deep structural inspector
- `apropos` — live symbol search across all environments
- `expand-macro` — full macro expansion via `(expand)`

---

## 19. Sandboxed Eval

**What**: `(copy-environment)` — create an isolated copy of the Scheme environment.

**Why it matters**: Evaluate user code in a sandbox that can't affect the editor's state. Reset the sandbox anytime. Emacs `eval` runs in the global environment with no isolation.

**Commands that use it**:
- `eval-in-sandbox` — evaluate in an isolated environment
- `sandbox-reset` — reset the sandbox to a clean state

---

## The Architecture

All of these integrate through a single pattern:

```
Background threads (SMP)  →  Channel (UI queue)  →  Master timer (primordial thread)  →  Qt widgets
```

1. Blocking work spawns in background threads via `spawn-worker`
2. Results are posted to the UI queue via `ui-queue-push!` (a Go-style channel)
3. The master timer (16ms interval) drains the queue on the primordial thread
4. Qt widget updates happen safely on the primordial thread

The master timer also:
- Drains GC'd objects via guardians
- Runs periodic tasks (file indexer, git watcher, flycheck)
- Ticks engine-sliced eval (50000 Chez ticks per frame)

This is a **real concurrent editor** — not a single-threaded event loop with cooperative yielding like Emacs.
