/*
 * jemacs-qt-main.c — Custom entry point for jemacs-qt (jerboa-emacs Qt frontend).
 *
 * Same threading workaround as jemacs-main.c:
 *   - Boot file contains only libraries (no program)
 *   - Program is loaded via Sscheme_script on a memfd
 *
 * The Qt event loop runs on its own pthread (created by qt-app-create in
 * qt_shim.cpp). That pthread registers via Sactivate_thread/Sdeactivate_thread
 * (implemented in qt_chez_shim.c) before invoking Chez foreign-callable
 * trampolines.  No special handling is needed here.
 *
 * The CHEZ_QT_LIB env var points qt_chez_shim to where qt_chez_shim.so
 * lives (for load-shared-object). We point it at the binary's own directory
 * since qt_chez_shim is compiled into the binary itself — but we still need
 * the libqt_shim.so (gerbil-qt vendor shim) to be loadable.
 * Set CHEZ_QT_SHIM_DIR to where libqt_shim.so lives (same dir as binary,
 * or let the rpath handle it).
 */

#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <libgen.h>
#include <sys/mman.h>
#include "scheme.h"
#include "jemacs_qt_program.h"         /* jemacs_qt_program_data[], jemacs_qt_program_size */
#include "jemacs_qt_petite_boot.h"     /* petite_boot_data[], petite_boot_size */
#include "jemacs_qt_scheme_boot.h"     /* scheme_boot_data[], scheme_boot_size */
#include "jemacs_qt_jemacs_qt_boot.h"  /* jemacs_qt_boot_data[], jemacs_qt_boot_size */

int main(int argc, char *argv[]) {
    /* Resolve real executable path */
    char exe_buf[4096];
    char exe_dir[4096];
    ssize_t len = readlink("/proc/self/exe", exe_buf, sizeof(exe_buf) - 1);
    if (len > 0) {
        exe_buf[len] = '\0';
        setenv("JEMACS_EXE", exe_buf, 1);
        strncpy(exe_dir, exe_buf, sizeof(exe_dir) - 1);
        exe_dir[sizeof(exe_dir) - 1] = '\0';
        char *dir = dirname(exe_dir);
        /* Point FFI shim loaders at the binary's directory.
         * The shims (qt_chez_shim, pcre2_shim) are compiled into the binary,
         * and libqt_shim.so must be alongside the binary (rpath or LD_LIBRARY_PATH). */
        if (!getenv("CHEZ_QT_LIB"))
            setenv("CHEZ_QT_LIB", dir, 0);
        if (!getenv("CHEZ_QT_SHIM_DIR"))
            setenv("CHEZ_QT_SHIM_DIR", dir, 0);
        if (!getenv("CHEZ_PCRE2_LIB"))
            setenv("CHEZ_PCRE2_LIB", dir, 0);
        if (!getenv("CHEZ_SCINTILLA_LIB"))
            setenv("CHEZ_SCINTILLA_LIB", dir, 0);
    }

    /* Create memfd for embedded program .so */
    int fd = memfd_create("jemacs-qt-program", MFD_CLOEXEC);
    if (fd < 0) {
        perror("memfd_create");
        return 1;
    }
    if (write(fd, jemacs_qt_program_data, jemacs_qt_program_size)
            != (ssize_t)jemacs_qt_program_size) {
        perror("write memfd");
        close(fd);
        return 1;
    }
    char prog_path[64];
    snprintf(prog_path, sizeof(prog_path), "/proc/self/fd/%d", fd);

    /* Initialize Chez Scheme */
    Sscheme_init(NULL);

    /* Register embedded boot files */
    Sregister_boot_file_bytes("petite",    (void*)petite_boot_data,     petite_boot_size);
    Sregister_boot_file_bytes("scheme",    (void*)scheme_boot_data,     scheme_boot_size);
    Sregister_boot_file_bytes("jemacs-qt", (void*)jemacs_qt_boot_data,  jemacs_qt_boot_size);

#ifdef JEMACS_STATIC_BUILD
    /* Tell Scheme libraries they are in a static build so they skip
     * load-shared-object calls (dlopen("file.so") fails in musl static).
     * Must be set before Sbuild_heap so library bodies see it. */
    setenv("JEMACS_STATIC", "1", 1);
#endif

    /* Build heap from libraries only — no program */
    Sbuild_heap(NULL, NULL);

#ifdef JEMACS_STATIC_BUILD
    /* Register all FFI symbols after heap is built.
     * Sforeign_symbol requires an initialized Scheme heap.
     * foreign-procedure in library bodies uses dlsym(RTLD_DEFAULT) first;
     * this call supplements that for any symbols missed by dlsym. */
    extern void register_static_foreign_symbols(void);
    register_static_foreign_symbols();
#endif

    /* Run via Sscheme_script so fork-thread works.
     * Pass full argv so argv[0]=binary name and argv[1..]=user args.
     * (command-line-arguments) returns ("./jemacs-qt" args...) — member checks work. */
    int status = Sscheme_script(prog_path, argc, (const char **)argv);

    close(fd);
    Sscheme_deinit();
    return status;
}
