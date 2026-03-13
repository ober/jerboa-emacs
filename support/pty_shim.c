/*
 * pty_shim.c — PTY (pseudo-terminal) subprocess support via forkpty(3).
 *
 * Extracted from gerbil-emacs/pty.ss begin-ffi block.
 * Compile: cc -shared -fPIC -o pty_shim.so pty_shim.c -lutil
 */

#include <pty.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/wait.h>

/* Per-call state (single PTY spawn at a time from Scheme) */
static int    g_master_fd  = -1;
static pid_t  g_child_pid  = -1;
static int    g_wait_status = 0;

/*
 * Spawn a child process in a new PTY.
 * cmd:  shell command string (passed to /bin/sh -c)
 * envp: environment as "KEY=VALUE\n..." string (newline-separated)
 *       Empty string or NULL means inherit parent environment.
 * rows, cols: initial terminal size
 * Returns: child PID on success, -errno on failure.
 */
int pty_spawn(const char *cmd, const char *envp, int rows, int cols) {
    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    ws.ws_row = rows;
    ws.ws_col = cols;

    g_master_fd = -1;
    g_child_pid = forkpty(&g_master_fd, NULL, NULL, &ws);

    if (g_child_pid < 0) {
        int err = errno;
        g_master_fd = -1;
        return -err;
    }

    if (g_child_pid == 0) {
        /* Child process */
        if (envp && envp[0]) {
            clearenv();
            const char *p = envp;
            while (*p) {
                const char *nl = strchr(p, '\n');
                if (!nl) nl = p + strlen(p);
                int len = nl - p;
                if (len > 0) {
                    char *entry = (char *)alloca(len + 1);
                    memcpy(entry, p, len);
                    entry[len] = '\0';
                    char *eq = strchr(entry, '=');
                    if (eq) {
                        *eq = '\0';
                        setenv(entry, eq + 1, 1);
                    }
                }
                p = *nl ? nl + 1 : nl;
            }
        }

        if (!getenv("TERM"))
            setenv("TERM", "xterm-256color", 1);

        execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
        _exit(127);
    }

    /* Parent: make master fd non-blocking */
    int flags = fcntl(g_master_fd, F_GETFL, 0);
    if (flags >= 0)
        fcntl(g_master_fd, F_SETFL, flags | O_NONBLOCK);

    return g_child_pid;
}

int pty_get_master_fd(void) { return g_master_fd; }
int pty_get_child_pid(void) { return g_child_pid; }

/*
 * Non-blocking read from PTY master fd.
 * Returns bytes read (>0), 0 if EAGAIN (no data), -1 on EOF/error.
 */
int pty_read(int fd, char *buf, int maxlen) {
    int n = read(fd, buf, maxlen);
    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return 0;
        return -1;
    }
    if (n == 0)
        return -1;
    return n;
}

/*
 * Write to PTY master fd (sends data to child's stdin).
 */
int pty_write(int fd, const char *data, int len) {
    return write(fd, data, len);
}

void pty_close(int fd) {
    if (fd >= 0) close(fd);
}

int pty_kill(int pid, int sig) {
    if (pid > 0) return kill(-pid, sig);
    return -1;
}

int pty_resize(int fd, int rows, int cols) {
    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    ws.ws_row = rows;
    ws.ws_col = cols;
    return ioctl(fd, TIOCSWINSZ, &ws);
}

int pty_waitpid(int pid, int nohang) {
    g_wait_status = 0;
    return waitpid(pid, &g_wait_status, nohang ? WNOHANG : 0);
}

int pty_get_wait_status(void) {
    if (WIFEXITED(g_wait_status))
        return WEXITSTATUS(g_wait_status);
    if (WIFSIGNALED(g_wait_status))
        return 128 + WTERMSIG(g_wait_status);
    return -1;
}
