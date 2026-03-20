/* repl_shim.c — GC-safe wrappers for Chez SMP threading.
 *
 * Problem: Chez SMP GC uses stop-the-world rendezvous.  All threads must
 * deactivate (via Sdeactivate_thread) before GC can proceed.  Threads
 * blocked in foreign calls (read, poll, popen) stay ACTIVE, preventing GC.
 *
 * Solution: These wrappers bracket blocking C calls with
 * Sdeactivate_thread/Sactivate_thread so GC doesn't wait for blocked threads.
 *
 * In musl static binaries, dlsym(RTLD_DEFAULT, "poll") fails because
 * poll is not in the dynamic symbol table.  These wrappers, compiled as
 * separate .o files, are linked with --export-dynamic and thus visible.
 */
#include <poll.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Forward declarations for Chez runtime (from scheme.h) */
extern int Sactivate_thread(void);
extern void Sdeactivate_thread(void);

/* ========== Low-level wrappers ========== */

/* Exported as "repl_poll" — wraps poll() for Chez FFI */
int repl_poll(struct pollfd *fds, unsigned int nfds, int timeout) {
    return poll(fds, nfds, timeout);
}

/* Exported as "repl_nanosleep" — wraps nanosleep() for Chez FFI */
int repl_nanosleep(const struct timespec *req, struct timespec *rem) {
    return nanosleep(req, rem);
}

/* Exported wrappers so Chez foreign-procedure can find them */
void repl_deactivate_thread(void) {
    Sdeactivate_thread();
}

int repl_activate_thread(void) {
    return Sactivate_thread();
}

/* ========== GC-safe subprocess capture ========== */

/*
 * repl_capture_command — Run a shell command, capture all stdout.
 *
 * Deactivates the Chez thread during the blocking popen/fread so GC
 * can proceed without waiting for this thread.  Reactivates before
 * returning so the caller can safely create Scheme objects from the result.
 *
 * Uses thread-local storage for the output buffer (safe for multiple
 * concurrent workers).  Buffer is reused across calls from the same thread.
 *
 * Returns: pointer to null-terminated output string (TLS buffer).
 *          Empty string on error.  Valid until next call from same thread.
 */
static __thread char *tls_cmd_buf = NULL;
static __thread size_t tls_cmd_cap = 0;

const char *repl_capture_command(const char *cmd) {
    /* Ensure TLS buffer exists */
    if (!tls_cmd_buf) {
        tls_cmd_cap = 8192;
        tls_cmd_buf = (char *)malloc(tls_cmd_cap);
        if (!tls_cmd_buf) return "";
    }

    /* Deactivate: tell GC we won't touch Scheme heap during blocking I/O */
    Sdeactivate_thread();

    FILE *fp = popen(cmd, "r");
    if (!fp) {
        Sactivate_thread();
        tls_cmd_buf[0] = '\0';
        return tls_cmd_buf;
    }

    size_t len = 0;
    size_t n;
    /* Read in chunks for efficiency */
    while ((n = fread(tls_cmd_buf + len, 1, tls_cmd_cap - len - 1, fp)) > 0) {
        len += n;
        if (len + 1 >= tls_cmd_cap) {
            tls_cmd_cap *= 2;
            tls_cmd_buf = (char *)realloc(tls_cmd_buf, tls_cmd_cap);
            if (!tls_cmd_buf) {
                pclose(fp);
                Sactivate_thread();
                tls_cmd_cap = 0;
                return "";
            }
        }
    }
    tls_cmd_buf[len] = '\0';

    pclose(fp);

    /* Reactivate: safe to create Scheme objects now */
    Sactivate_thread();

    return tls_cmd_buf;
}

/* ========== GC-safe file read ========== */

/*
 * repl_read_file — Read entire file contents, GC-safe.
 *
 * Same deactivate/activate pattern as repl_capture_command.
 * Returns pointer to file contents (TLS buffer), empty string on error.
 */
const char *repl_read_file(const char *path) {
    if (!tls_cmd_buf) {
        tls_cmd_cap = 8192;
        tls_cmd_buf = (char *)malloc(tls_cmd_cap);
        if (!tls_cmd_buf) return "";
    }

    Sdeactivate_thread();

    FILE *fp = fopen(path, "r");
    if (!fp) {
        Sactivate_thread();
        tls_cmd_buf[0] = '\0';
        return tls_cmd_buf;
    }

    size_t len = 0;
    size_t n;
    while ((n = fread(tls_cmd_buf + len, 1, tls_cmd_cap - len - 1, fp)) > 0) {
        len += n;
        if (len + 1 >= tls_cmd_cap) {
            tls_cmd_cap *= 2;
            tls_cmd_buf = (char *)realloc(tls_cmd_buf, tls_cmd_cap);
            if (!tls_cmd_buf) {
                fclose(fp);
                Sactivate_thread();
                tls_cmd_cap = 0;
                return "";
            }
        }
    }
    tls_cmd_buf[len] = '\0';

    fclose(fp);
    Sactivate_thread();

    return tls_cmd_buf;
}

/* ========== GC-safe file write ========== */

/*
 * repl_write_file — Write string to file, GC-safe.
 * Returns 0 on success, -1 on error.
 */
int repl_write_file(const char *path, const char *content, size_t len) {
    Sdeactivate_thread();

    FILE *fp = fopen(path, "w");
    if (!fp) {
        Sactivate_thread();
        return -1;
    }

    size_t written = fwrite(content, 1, len, fp);
    fclose(fp);

    Sactivate_thread();

    return (written == len) ? 0 : -1;
}
