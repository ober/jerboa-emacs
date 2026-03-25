#!chezscheme
;;; (std security capsicum) — Static build stub (capsicum not available)
(library (std security capsicum)
  (export
    capsicum-enter!
    capsicum-available?
    capsicum-in-capability-mode?
    capsicum-limit-fd!
    capsicum-compute-only-preset
    capsicum-io-only-preset
    capsicum-apply-preset!
    capsicum-open-path
    capsicum-right-read
    capsicum-right-write
    capsicum-right-seek
    capsicum-right-mmap
    capsicum-right-event
    capsicum-right-fcntl
    capsicum-right-ioctl
    capsicum-right-fstat
    capsicum-right-ftruncate
    capsicum-right-fsync
    capsicum-right-lookup)

  (import (chezscheme))

  (define (capsicum-available?) #f)
  (define (capsicum-enter!) (void))
  (define (capsicum-in-capability-mode?) #f)
  (define (capsicum-limit-fd! fd rights) (void))
  (define (capsicum-compute-only-preset) '())
  (define (capsicum-io-only-preset) '())
  (define (capsicum-apply-preset! fd preset) (void))
  (define (capsicum-open-path path flags) -1)
  (define capsicum-right-read 0)
  (define capsicum-right-write 0)
  (define capsicum-right-seek 0)
  (define capsicum-right-mmap 0)
  (define capsicum-right-event 0)
  (define capsicum-right-fcntl 0)
  (define capsicum-right-ioctl 0)
  (define capsicum-right-fstat 0)
  (define capsicum-right-ftruncate 0)
  (define capsicum-right-fsync 0)
  (define capsicum-right-lookup 0)

  ) ;; end library
