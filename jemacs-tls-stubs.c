/* Stub — jemacs TUI doesn't use rustls TLS */
#include <stddef.h>
#include <stdint.h>
uint64_t jerboa_tls_server_new(const char *c, const char *k) { return 0; }
uint64_t jerboa_tls_server_new_mtls(const char *c, const char *k, const char *ca) { return 0; }
void jerboa_tls_server_free(uint64_t s) {}
uint64_t jerboa_tls_accept(uint64_t s, int fd) { return 0; }
uint64_t jerboa_tls_connect(const char *h, int p) { return 0; }
uint64_t jerboa_tls_connect_pinned(const char *h, int p, const uint8_t *fp, size_t fplen) { return 0; }
uint64_t jerboa_tls_connect_mtls(const char *h, int p, const char *c, const char *k, const char *ca) { return 0; }
int jerboa_tls_read(uint64_t s, uint8_t *buf, uint64_t len) { return -1; }
int jerboa_tls_write(uint64_t s, const uint8_t *buf, uint64_t len) { return -1; }
int jerboa_tls_flush(uint64_t s) { return -1; }
void jerboa_tls_close(uint64_t s) {}
int jerboa_tls_set_nonblock(uint64_t s, int nb) { return -1; }
int jerboa_tls_get_fd(uint64_t s) { return -1; }
size_t jerboa_last_error(uint8_t *buf, size_t len) { return 0; }
