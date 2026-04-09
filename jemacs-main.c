/*
 * jemacs-main.c — Custom entry point for jemacs (jerboa-emacs TUI).
 *
 * Chez Scheme's default main() steals flags like -c (interprets as --compact).
 * This custom main bypasses Chez's arg parsing: it saves all user args in
 * positional env vars (JEMACS_ARGC, JEMACS_ARG0, ...), then calls the
 * Chez runtime with no user args.
 *
 * Boot files (petite.boot, scheme.boot, jemacs.boot) are embedded as C byte
 * arrays and registered via Sregister_boot_file_bytes — no external files needed.
 *
 * Threading workaround: Programs embedded in boot files (via make-boot-file)
 * cannot create threads — fork-thread creates OS threads that block forever
 * on an internal GC futex. To fix this, we load only libraries via the boot
 * file and run the program separately via Sscheme_script, which preserves
 * full threading support.
 *
 * The program .so is embedded in the binary as a C byte array (jemacs_program.h)
 * and extracted to a memfd at runtime.
 *
 * FFI shims (chez_scintilla_shim, pcre2_shim) are compiled into the binary.
 * Their symbols are found by Chez's foreign-procedure via dlsym(RTLD_DEFAULT)
 * because we link with -rdynamic.  At runtime we set CHEZ_SCINTILLA_LIB and
 * CHEZ_PCRE2_LIB so the shim's load-shared-object call succeeds — we point
 * it at the binary itself via a /proc/self/exe symlink in a tmpdir, or just
 * let the shim load its own copy if CHEZ_SCINTILLA_LIB is already set.
 */

#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <libgen.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include "scheme.h"
#include "jemacs_program.h"      /* jemacs_program_data[], jemacs_program_size */
#include "jemacs_petite_boot.h"  /* petite_boot_data[], petite_boot_size */
#include "jemacs_scheme_boot.h"  /* scheme_boot_data[], scheme_boot_size */
#include "jemacs_jemacs_boot.h"  /* jemacs_boot_data[], jemacs_boot_size */

int main(int argc, char *argv[]) {
    /* Resolve real executable path */
    char exe_buf[4096];
    char exe_dir[4096];
    ssize_t len = readlink("/proc/self/exe", exe_buf, sizeof(exe_buf) - 1);
    if (len > 0) {
        exe_buf[len] = '\0';
        setenv("JEMACS_EXE", exe_buf, 1);
        /* dirname() may modify its argument, use a copy */
        strncpy(exe_dir, exe_buf, sizeof(exe_dir) - 1);
        exe_dir[sizeof(exe_dir) - 1] = '\0';
        char *dir = dirname(exe_dir);
        /* Set shim paths to the binary's directory (if not already set) */
        if (!getenv("CHEZ_SCINTILLA_LIB"))
            setenv("CHEZ_SCINTILLA_LIB", dir, 0);
        if (!getenv("CHEZ_PCRE2_LIB"))
            setenv("CHEZ_PCRE2_LIB", dir, 0);
    }

    /* Create memfd for embedded program .so */
    int fd = memfd_create("jemacs-program", MFD_CLOEXEC);
    if (fd < 0) {
        perror("memfd_create");
        return 1;
    }
    if (write(fd, jemacs_program_data, jemacs_program_size) != (ssize_t)jemacs_program_size) {
        perror("write memfd");
        close(fd);
        return 1;
    }
    char prog_path[64];
    snprintf(prog_path, sizeof(prog_path), "/proc/self/fd/%d", fd);

    /* Initialize Chez Scheme */
    Sscheme_init(NULL);

    /* Register embedded boot files (no external files needed) */
    Sregister_boot_file_bytes("petite", (void*)petite_boot_data, petite_boot_size);
    Sregister_boot_file_bytes("scheme", (void*)scheme_boot_data, scheme_boot_size);
    Sregister_boot_file_bytes("jemacs", (void*)jemacs_boot_data, jemacs_boot_size);

    /* Build heap from registered boot files (libraries only — no program) */
    Sbuild_heap(NULL, NULL);

#ifdef JEMACS_STATIC_BUILD
    /* Static builds: register FFI symbols compiled into the binary.
     * In musl static builds dlopen(NULL) is a stub, so foreign-procedure
     * can't find symbols by name at runtime. We pre-register them here. */
    extern void register_static_foreign_symbols(void);
    register_static_foreign_symbols();
#endif

    /* Run the program via Sscheme_script (NOT Sscheme_start).
     * This avoids the Chez bug where programs in boot files cannot
     * create threads (fork-thread threads block on internal GC futex).
     *
     * Pass full argv (argc, argv) so Sscheme_script treats argv[0] as the
     * program name and argv[1..] as arguments.  Then (command-line-arguments)
     * returns ("./jemacs" "--version" ...) and (member "--version" args) works.
     * Passing (argc-1, argv+1) was wrong: argv[0]="--version" became the
     * program name, leaving command-line-arguments empty. */
    int status = Sscheme_script(prog_path, argc, (const char **)argv);

    close(fd);
    Sscheme_deinit();
    return status;
}
