;;; -*- Gerbil -*-
;;; Chez Scheme Power Features for jerboa-emacs
;;;
;;; Re-exports advanced Chez capabilities from jerboa's stdlib.
;;; Emacs Lisp has none of these. They're Chez superpowers.

(export
  ;; STM: transactional variables for safe concurrent state
  make-tvar tvar? tvar-ref atomically tvar-read tvar-write! retry or-else

  ;; Structured engines with higher-level API
  make-eval-engine engine-run engine-result engine-expired? timed-eval fuel-eval

  ;; LRU cache: bounded, thread-safe memoization
  make-lru-cache lru-cache? lru-cache-get lru-cache-put! lru-cache-delete!
  lru-cache-clear! lru-cache-size lru-cache-capacity lru-cache-stats

  ;; WaitGroup: barrier sync for parallel operations
  make-wg wg? wg-add wg-done wg-wait

  ;; Go-style channels: message passing between threads
  make-channel channel? channel-put channel-try-put
  channel-get channel-try-get channel-close channel-closed?
  channel-length channel-empty? channel-select

  ;; Clojure-style atoms: thread-safe mutable references
  ;; NOTE: atom? excluded — conflicts with Chez Scheme's built-in atom?
  atom atom-deref atom-reset! atom-swap! atom-update!

  ;; Priority queue: binary heap for scheduling
  make-pqueue pqueue? pqueue-push! pqueue-pop! pqueue-peek
  pqueue-empty? pqueue-length pqueue->list pqueue-for-each pqueue-clear!

  ;; Red-black trees: O(log n) ordered maps
  make-rbtree rbtree? rbtree-insert rbtree-lookup rbtree-delete
  rbtree-contains? rbtree-min rbtree-max rbtree-fold
  rbtree->list rbtree-size rbtree-empty?

  ;; Read-write locks: concurrent reads, exclusive writes
  make-rwlock rwlock? read-lock! read-unlock!
  write-lock! write-unlock! with-read-lock with-write-lock

  ;; Completions: one-shot synchronization tokens
  make-completion completion? completion-ready?
  completion-post! completion-error! completion-wait!

  ;; Barriers: cyclic multi-party synchronization
  make-barrier barrier? barrier-wait!
  barrier-reset! barrier-parties barrier-waiting

  ;; Nondeterministic search: amb operator
  amb amb-assert amb-fail amb-find amb-collect)

(import :std/sugar
        :std/stm
        :std/engine
        :std/misc/lru-cache
        :std/misc/wg
        :std/misc/channel
        (except-in :std/misc/atom atom?)
        :std/misc/pqueue
        :std/misc/rbtree
        :std/misc/rwlock
        :std/misc/completion
        :std/misc/barrier
        :std/amb)
