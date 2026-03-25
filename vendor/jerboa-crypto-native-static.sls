#!chezscheme
;;; (std crypto native) — Static build stub
;;; Crypto not available in static builds (no OpenSSL linked).
;;; All functions error with "libcrypto not available".

(library (std crypto native)
  (export
    native-md5 native-sha1 native-sha256 native-sha384 native-sha512
    native-digest
    native-random-bytes
    native-random-bytes!
    native-hmac-sha256
    native-crypto-memcmp)

  (import (chezscheme))

  (define (not-available who)
    (error who "libcrypto not available in static build"))

  (define (native-md5 data) (not-available 'native-md5))
  (define (native-sha1 data) (not-available 'native-sha1))
  (define (native-sha256 data) (not-available 'native-sha256))
  (define (native-sha384 data) (not-available 'native-sha384))
  (define (native-sha512 data) (not-available 'native-sha512))
  (define (native-digest algo data) (not-available 'native-digest))
  (define (native-random-bytes n) (not-available 'native-random-bytes))
  (define (native-random-bytes! bv) (not-available 'native-random-bytes!))
  (define (native-hmac-sha256 key data) (not-available 'native-hmac-sha256))
  (define (native-crypto-memcmp a b) (not-available 'native-crypto-memcmp))

  ) ;; end library
