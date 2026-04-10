#!chezscheme
;;; (std net tls-rustls) — static stub for jemacs TUI build
;;;
;;; The TUI binary does not use TLS. This stub exports the correct interface
;;; but raises an error if any function is actually called at runtime.
;;; It avoids foreign-procedure so the static binary does not need the
;;; Rust rustls library (libjerboa_native).

(library (std net tls-rustls)
  (export
    rustls-server-ctx-new
    rustls-server-ctx-new-mtls
    rustls-server-ctx-free
    rustls-accept
    rustls-connect
    rustls-connect-pinned
    rustls-connect-mtls
    rustls-read
    rustls-write
    rustls-flush
    rustls-close
    rustls-set-nonblock
    rustls-get-fd)

  (import (chezscheme))

  (define (tls-not-available who . args)
    (error who "TLS not available in static jemacs build"))

  (define (rustls-server-ctx-new cert-path key-path)
    (tls-not-available 'rustls-server-ctx-new))
  (define (rustls-server-ctx-new-mtls cert-path key-path client-ca-path)
    (tls-not-available 'rustls-server-ctx-new-mtls))
  (define (rustls-server-ctx-free handle)
    (tls-not-available 'rustls-server-ctx-free))
  (define (rustls-accept server-ctx tcp-fd)
    (tls-not-available 'rustls-accept))
  (define (rustls-connect host port)
    (tls-not-available 'rustls-connect))
  (define (rustls-connect-pinned host port pin-sha256)
    (tls-not-available 'rustls-connect-pinned))
  (define (rustls-connect-mtls host port cert-path key-path ca-cert-path)
    (tls-not-available 'rustls-connect-mtls))
  (define (rustls-read handle buf max-len)
    (tls-not-available 'rustls-read))
  (define (rustls-write handle buf len)
    (tls-not-available 'rustls-write))
  (define (rustls-flush handle)
    (tls-not-available 'rustls-flush))
  (define (rustls-close handle)
    (tls-not-available 'rustls-close))
  (define (rustls-set-nonblock handle nonblock?)
    (tls-not-available 'rustls-set-nonblock))
  (define (rustls-get-fd handle)
    (tls-not-available 'rustls-get-fd))

  ) ;; end library
