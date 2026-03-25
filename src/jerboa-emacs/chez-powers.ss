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
  make-wg wg? wg-add wg-done wg-wait)

(import :std/sugar
        :std/stm
        :std/engine
        :std/misc/lru-cache
        :std/misc/wg)
