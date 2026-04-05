/*
 * jemacs-qt-main.c — Custom entry point for jemacs-qt (jerboa-emacs Qt frontend).
 *
 *   - Boot file contains only libraries (no program)
 *   - Program is loaded via Sscheme_script from an in-memory file
 *     (memfd on Linux, temp file on macOS)
 *
 * On macOS, Qt runs on the main thread (Cocoa requirement). The event loop
 * is driven by repeated processEvents() calls from the Scheme polling loop.
 */

#ifdef __APPLE__
#include <mach-o/dyld.h>
#else
#define _GNU_SOURCE
#include <sys/mman.h>
#endif

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <libgen.h>
#include <fcntl.h>
#include "scheme.h"
#include "jemacs_qt_program.h"         /* jemacs_qt_program_data[], jemacs_qt_program_size */
#include "jemacs_qt_petite_boot.h"     /* petite_boot_data[], petite_boot_size */
#include "jemacs_qt_scheme_boot.h"     /* scheme_boot_data[], scheme_boot_size */
#include "jemacs_qt_jemacs_qt_boot.h"  /* jemacs_qt_boot_data[], jemacs_qt_boot_size */

int main(int argc, char *argv[]) {
    /* Resolve real executable path */
    char exe_buf[4096];
    char exe_dir[4096];
    int got_exe = 0;

#ifdef __APPLE__
    uint32_t exe_size = sizeof(exe_buf);
    if (_NSGetExecutablePath(exe_buf, &exe_size) == 0) {
        got_exe = 1;
    }
#else
    ssize_t len = readlink("/proc/self/exe", exe_buf, sizeof(exe_buf) - 1);
    if (len > 0) {
        exe_buf[len] = '\0';
        got_exe = 1;
    }
#endif

    if (got_exe) {
        setenv("JEMACS_EXE", exe_buf, 1);
        strncpy(exe_dir, exe_buf, sizeof(exe_dir) - 1);
        exe_dir[sizeof(exe_dir) - 1] = '\0';
        char *dir = dirname(exe_dir);
        /* Point FFI shim loaders at the binary's directory */
        if (!getenv("CHEZ_QT_LIB"))
            setenv("CHEZ_QT_LIB", dir, 0);
        if (!getenv("CHEZ_QT_SHIM_DIR"))
            setenv("CHEZ_QT_SHIM_DIR", dir, 0);
        if (!getenv("CHEZ_PCRE2_LIB"))
            setenv("CHEZ_PCRE2_LIB", dir, 0);
        if (!getenv("CHEZ_SCINTILLA_LIB"))
            setenv("CHEZ_SCINTILLA_LIB", dir, 0);
    }

    /* Write embedded program .so to a file Chez can dlopen */
    char prog_path[256];
    int fd;

#ifdef __APPLE__
    /* macOS: no memfd — write to a temp file */
    snprintf(prog_path, sizeof(prog_path), "/tmp/jemacs-qt-program.XXXXXX");
    fd = mkstemp(prog_path);
    if (fd < 0) {
        perror("mkstemp");
        return 1;
    }
    /* Rename to add .so extension so dlopen recognises it as a shared lib */
    char prog_path_so[256];
    snprintf(prog_path_so, sizeof(prog_path_so), "%s.so", prog_path);
    if (rename(prog_path, prog_path_so) != 0) {
        perror("rename");
        close(fd);
        return 1;
    }
    close(fd);
    fd = open(prog_path_so, O_WRONLY | O_CREAT | O_TRUNC, 0700);
    if (fd < 0) {
        perror("open prog_path_so");
        return 1;
    }
    strncpy(prog_path, prog_path_so, sizeof(prog_path) - 1);
#else
    /* Linux: memfd — anonymous in-memory file */
    fd = memfd_create("jemacs-qt-program", MFD_CLOEXEC);
    if (fd < 0) {
        perror("memfd_create");
        return 1;
    }
    snprintf(prog_path, sizeof(prog_path), "/proc/self/fd/%d", fd);
#endif

    if (write(fd, jemacs_qt_program_data, jemacs_qt_program_size)
            != (ssize_t)jemacs_qt_program_size) {
        perror("write prog");
        close(fd);
        return 1;
    }
#ifdef __APPLE__
    close(fd);  /* file is on disk — close write fd before dlopen */
#endif

    /* Initialize Chez Scheme */
    Sscheme_init(NULL);

    /* Register embedded boot files */
    Sregister_boot_file_bytes("petite",    (void*)petite_boot_data,     petite_boot_size);
    Sregister_boot_file_bytes("scheme",    (void*)scheme_boot_data,     scheme_boot_size);
    Sregister_boot_file_bytes("jemacs-qt", (void*)jemacs_qt_boot_data,  jemacs_qt_boot_size);

#ifdef JEMACS_STATIC_BUILD
    setenv("JEMACS_STATIC", "1", 1);
#endif

    /* Build heap from libraries only — no program */
    Sbuild_heap(NULL, NULL);

#if defined(JEMACS_STATIC_BUILD) || defined(__APPLE__)
    extern void register_static_foreign_symbols(void);
    register_static_foreign_symbols();
#endif

    int status = Sscheme_script(prog_path, argc, (const char **)argv);

#ifdef __APPLE__
    unlink(prog_path);  /* clean up temp file */
#else
    close(fd);
#endif
    Sscheme_deinit();
    return status;
}
