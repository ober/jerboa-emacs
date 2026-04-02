#!chezscheme
;;; (chez-ssl) — static build variant: guards load-shared-object for JEMACS_STATIC.
;;; Copied from ~/mine/chez-ssl/src/chez-ssl.sls with the only change being
;;; that load-shared-object calls are skipped when JEMACS_STATIC=1 (the
;;; symbols are registered at link time via Sforeign_symbol instead).

(library (chez-ssl)
  (export ssl-init! ssl-cleanup!
          ;; Client-side TLS
          ssl-connect ssl-write ssl-write-string
          ssl-read ssl-read-all ssl-close
          ssl-connection?
          ;; Plain TCP
          tcp-connect tcp-listen tcp-accept tcp-close
          tcp-read tcp-write tcp-read-all tcp-write-string
          tcp-set-timeout
          ;; Server-side TLS
          ssl-server-ctx ssl-server-ctx-free ssl-server-accept
          ;; Unified connection (works for both plain TCP and TLS)
          conn-wrap conn-write conn-write-string conn-read)
  (import (chezscheme))

  (define load-libs
    (let ([static (getenv "JEMACS_STATIC")])
      (if (and static (not (string=? static "")) (not (string=? static "0")))
        (void)  ;; static build: symbols registered via Sforeign_symbol
        (begin
          (load-shared-object "libssl.so")
          (load-shared-object "libcrypto.so")
          (load-shared-object "chez_ssl_shim.so")))))

  ;; ================================================================
  ;; C FFI bindings — Client
  ;; ================================================================

  (define c-ssl-init     (foreign-procedure "chez_ssl_init" () void))
  (define c-ssl-cleanup  (foreign-procedure "chez_ssl_cleanup" () void))
  (define c-ssl-connect  (foreign-procedure "chez_ssl_connect" (string int u8* int) void*))
  (define c-ssl-write    (foreign-procedure "chez_ssl_write" (void* u8* int) int))
  (define c-ssl-read     (foreign-procedure "chez_ssl_read" (void* u8* int) int))
  (define c-ssl-read-all (foreign-procedure "chez_ssl_read_all" (void* void*) void*))
  (define c-ssl-close    (foreign-procedure "chez_ssl_close" (void*) void))
  (define c-ssl-free-buf (foreign-procedure "chez_ssl_free_buf" (void*) void))
  (define c-ssl-memcpy   (foreign-procedure "chez_ssl_memcpy" (u8* void* size_t) void))

  ;; ================================================================
  ;; C FFI bindings — Plain TCP
  ;; ================================================================

  (define c-tcp-connect   (foreign-procedure "chez_tcp_connect" (string int u8* int) int))
  (define c-tcp-listen    (foreign-procedure "chez_tcp_listen" (int int u8* int) int))
  (define c-tcp-accept    (foreign-procedure "chez_tcp_accept" (int u8* int u8* int) int))
  (define c-tcp-close     (foreign-procedure "chez_tcp_close" (int) void))
  (define c-tcp-read      (foreign-procedure "chez_tcp_read" (int u8* int) int))
  (define c-tcp-write     (foreign-procedure "chez_tcp_write" (int u8* int) int))
  (define c-tcp-read-all  (foreign-procedure "chez_tcp_read_all" (int void*) void*))
  (define c-tcp-set-timeout (foreign-procedure "chez_tcp_set_timeout" (int int int) int))

  ;; ================================================================
  ;; C FFI bindings — Server TLS
  ;; ================================================================

  (define c-ssl-server-ctx
    (foreign-procedure "chez_ssl_server_ctx" (string string u8* int) void*))
  (define c-ssl-server-accept
    (foreign-procedure "chez_ssl_server_accept" (void* int u8* int) void*))
  (define c-ssl-server-ctx-free
    (foreign-procedure "chez_ssl_server_ctx_free" (void*) void))

  ;; ================================================================
  ;; C FFI bindings — Unified connection
  ;; ================================================================

  (define c-tcp-conn-wrap (foreign-procedure "chez_tcp_conn_wrap" (int) void*))
  (define c-conn-write    (foreign-procedure "chez_conn_write" (void* u8* int) int))
  (define c-conn-read     (foreign-procedure "chez_conn_read" (void* u8* int) int))

  ;; ================================================================
  ;; Connection tracking
  ;; ================================================================

  (define *live-connections* '())

  (define (ssl-connection? obj)
    (and (memq obj *live-connections*) #t))

  ;; ================================================================
  ;; SSL init/cleanup
  ;; ================================================================

  (define (ssl-init!) (c-ssl-init))
  (define (ssl-cleanup!) (c-ssl-cleanup))

  ;; ================================================================
  ;; Client-side TLS
  ;; ================================================================

  (define (ssl-connect hostname port)
    (let ([err-buf (make-bytevector 256 0)])
      (let ([conn (c-ssl-connect hostname port err-buf 256)])
        (if (zero? conn)
            (error 'ssl-connect
                   (utf8->string (bytevector-trim-nuls err-buf))
                   hostname port)
            (begin
              (set! *live-connections* (cons conn *live-connections*))
              conn)))))

  (define (ssl-write conn bv)
    (let ([rc (c-ssl-write conn bv (bytevector-length bv))])
      (unless (= rc 0)
        (error 'ssl-write "write failed"))))

  (define (ssl-write-string conn str)
    (ssl-write conn (string->utf8 str)))

  (define (ssl-read conn buf len)
    (c-ssl-read conn buf len))

  (define (ssl-read-all conn)
    (let ([len-buf (foreign-alloc 8)])
      (let ([ptr (c-ssl-read-all conn len-buf)])
        (if (zero? ptr)
            (begin (foreign-free len-buf)
                   (error 'ssl-read-all "read failed"))
            (let* ([len (foreign-ref 'size_t len-buf 0)]
                   [result (make-bytevector len)])
              (c-ssl-memcpy result ptr len)
              (c-ssl-free-buf ptr)
              (foreign-free len-buf)
              result)))))

  (define (ssl-close conn)
    (set! *live-connections* (remq conn *live-connections*))
    (c-ssl-close conn))

  ;; ================================================================
  ;; Plain TCP
  ;; ================================================================

  (define (tcp-connect hostname port)
    (let ([err-buf (make-bytevector 256 0)])
      (let ([fd (c-tcp-connect hostname port err-buf 256)])
        (when (< fd 0)
          (error 'tcp-connect
                 (utf8->string (bytevector-trim-nuls err-buf))
                 hostname port))
        fd)))

  (define (tcp-listen port . args)
    (let ([backlog (if (null? args) 128 (car args))])
      (let ([err-buf (make-bytevector 256 0)])
        (let ([fd (c-tcp-listen port backlog err-buf 256)])
          (when (< fd 0)
            (error 'tcp-listen
                   (utf8->string (bytevector-trim-nuls err-buf))
                   port))
          fd))))

  (define (tcp-accept listen-fd)
    (let ([addr-buf (make-bytevector 128 0)]
          [err-buf  (make-bytevector 256 0)])
      (let ([fd (c-tcp-accept listen-fd addr-buf 128 err-buf 256)])
        (cond
          [(= fd -2) (values #f #f)]
          [(< fd 0)
           (error 'tcp-accept
                  (utf8->string (bytevector-trim-nuls err-buf)))]
          [else
           (values fd (utf8->string (bytevector-trim-nuls addr-buf)))]))))

  (define (tcp-close fd) (c-tcp-close fd))

  (define (tcp-read fd buf len) (c-tcp-read fd buf len))

  (define (tcp-write fd bv)
    (let ([rc (c-tcp-write fd bv (bytevector-length bv))])
      (unless (= rc 0) (error 'tcp-write "write failed"))))

  (define (tcp-write-string fd str) (tcp-write fd (string->utf8 str)))

  (define (tcp-set-timeout fd read-secs write-secs)
    (c-tcp-set-timeout fd read-secs write-secs))

  (define (tcp-read-all fd)
    (let ([len-buf (foreign-alloc 8)])
      (let ([ptr (c-tcp-read-all fd len-buf)])
        (if (zero? ptr)
            (begin (foreign-free len-buf)
                   (error 'tcp-read-all "read failed"))
            (let* ([len (foreign-ref 'size_t len-buf 0)]
                   [result (make-bytevector len)])
              (c-ssl-memcpy result ptr len)
              (c-ssl-free-buf ptr)
              (foreign-free len-buf)
              result)))))

  ;; ================================================================
  ;; Server-side TLS
  ;; ================================================================

  (define (ssl-server-ctx cert-file key-file)
    (let ([err-buf (make-bytevector 256 0)])
      (let ([ctx (c-ssl-server-ctx cert-file key-file err-buf 256)])
        (when (zero? ctx)
          (error 'ssl-server-ctx
                 (utf8->string (bytevector-trim-nuls err-buf))
                 cert-file key-file))
        ctx)))

  (define (ssl-server-ctx-free ctx) (c-ssl-server-ctx-free ctx))

  (define (ssl-server-accept ctx client-fd)
    (let ([err-buf (make-bytevector 256 0)])
      (let ([conn (c-ssl-server-accept ctx client-fd err-buf 256)])
        (when (zero? conn)
          (error 'ssl-server-accept
                 (utf8->string (bytevector-trim-nuls err-buf))))
        (set! *live-connections* (cons conn *live-connections*))
        conn)))

  ;; ================================================================
  ;; Unified connection
  ;; ================================================================

  (define (conn-wrap fd)
    (let ([conn (c-tcp-conn-wrap fd)])
      (when (zero? conn) (error 'conn-wrap "malloc failed"))
      (set! *live-connections* (cons conn *live-connections*))
      conn))

  (define (conn-write conn bv)
    (let ([rc (c-conn-write conn bv (bytevector-length bv))])
      (unless (= rc 0) (error 'conn-write "write failed"))))

  (define (conn-write-string conn str) (conn-write conn (string->utf8 str)))

  (define (conn-read conn buf len) (c-conn-read conn buf len))

  ;; ================================================================
  ;; Helpers
  ;; ================================================================

  (define (bytevector-trim-nuls bv)
    (let loop ([i 0])
      (if (or (= i (bytevector-length bv))
              (= (bytevector-u8-ref bv i) 0))
          (let ([result (make-bytevector i)])
            (bytevector-copy! bv 0 result 0 i)
            result)
          (loop (+ i 1)))))

  ) ;; end library
