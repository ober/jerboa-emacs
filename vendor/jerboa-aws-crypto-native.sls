#!chezscheme
;;; (jerboa-aws crypto) — SHA256/HMAC via std/crypto/native (no subprocess)
;;; Replaces the default jerboa-aws/crypto which shells out to openssl CLI.
;;; Used in jemacs static builds where there is no external openssl binary.

(library (jerboa-aws crypto)
  (export sha256 hex-encode hmac-sha256 bytevector-append)
  (import (chezscheme)
          (std crypto native))

  ;; SHA256: returns raw 32-byte bytevector (same contract as original)
  (define (sha256 data)
    (native-digest 'sha256 (if (string? data) (string->utf8 data) data)))

  ;; Hex-encode a bytevector to a lowercase hex string
  (define (hex-encode bv)
    (let* ([len (bytevector-length bv)]
           [hex (make-string (* len 2))])
      (do ([i 0 (+ i 1)])
          ((= i len) hex)
        (let* ([b (bytevector-u8-ref bv i)]
               [hi (fxsra b 4)]
               [lo (fxand b #xf)])
          (string-set! hex (* i 2) (string-ref "0123456789abcdef" hi))
          (string-set! hex (+ (* i 2) 1) (string-ref "0123456789abcdef" lo))))))

  ;; HMAC-SHA256: returns raw 32-byte bytevector
  (define (hmac-sha256 key data)
    (let ([key-bv (if (string? key) (string->utf8 key) key)]
          [data-bv (if (string? data) (string->utf8 data) data)])
      (native-hmac-sha256 key-bv data-bv)))

  ;; Append bytevectors
  (define (bytevector-append . bvs)
    (let* ([total (apply + (map bytevector-length bvs))]
           [result (make-bytevector total)])
      (let loop ([bvs bvs] [offset 0])
        (if (null? bvs) result
          (let ([bv (car bvs)])
            (bytevector-copy! bv 0 result offset (bytevector-length bv))
            (loop (cdr bvs) (+ offset (bytevector-length bv))))))))

  ) ;; end library
