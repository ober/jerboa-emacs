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
        /* Child process — close inherited fds (except 0/1/2 which forkpty set up).
         * This prevents children from holding the debug REPL socket and other
         * parent resources open. */
        for (int fd = 3; fd < 1024; fd++) {
            close(fd);  /* harmless if fd not open */
        }

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

        /* Change to the shell's working directory (PWD from env).
         * Without this, cd in the in-process shell updates PWD but the
         * next PTY child still inherits the parent process's original cwd. */
        const char *pwd = getenv("PWD");
        if (pwd && pwd[0]) {
            if (chdir(pwd) != 0) { /* ignore error, fall through to exec */ }
        }

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

/* Last errno from pty_read, for debugging */
static int g_last_errno = 0;

int pty_last_errno(void) { return g_last_errno; }

/*
 * Non-blocking read from PTY master fd.
 * Returns:
 *   >0  — bytes read
 *    0  — EAGAIN/EWOULDBLOCK/EIO/ENXIO (no data yet, retry)
 *   -1  — EOF (read returned 0)
 *   -2  — fatal error (check pty_last_errno())
 *
 * EIO is common on PTY masters when the slave does certain ioctls
 * (e.g. during terminal setup).  ENXIO can occur briefly before the
 * slave side is fully opened.  Treating both as EAGAIN prevents the
 * reader thread from prematurely entering waitpid.
 */
int pty_read(int fd, char *buf, int maxlen) {
    int n = read(fd, buf, maxlen);
    if (n < 0) {
        g_last_errno = errno;
        if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EIO || errno == ENXIO)
            return 0;
        return -2;  /* fatal — caller should check pty_last_errno() */
    }
    if (n == 0)
        return -1;  /* true EOF */
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
