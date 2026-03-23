#!chezscheme
;; Build a native jemacs-qt binary for jerboa-emacs (Qt frontend).
;;
;; Usage: cd jerboa-emacs && make binary-qt
;;
;; Produces: ./jemacs-qt (single ELF binary with embedded boot files + program)
;;
;; All boot files are embedded as C byte arrays via Sregister_boot_file_bytes.
;; FFI shims are compiled into the binary (pcre2_shim, qt_chez_shim).
;; libqt_shim.so (from gerbil-qt vendor) is loaded at runtime — it must
;; be in the same directory as the binary or on LD_LIBRARY_PATH.
;;
;; Qt system libraries (Qt6Widgets, Qt6Core, etc.) are linked dynamically
;; from the system install. The binary requires Qt6 to be installed.

(import (chezscheme))

;; --- Helper: generate C header from binary file ---
(define (file->c-header input-path output-path array-name size-name)
  (let* ((port (open-file-input-port input-path))
         (data (get-bytevector-all port))
         (size (bytevector-length data)))
    (close-port port)
    (call-with-output-file output-path
      (lambda (out)
        (fprintf out "/* Auto-generated — do not edit */~n")
        (fprintf out "static const unsigned char ~a[] = {~n" array-name)
        (let loop ((i 0))
          (when (< i size)
            (when (= 0 (modulo i 16)) (fprintf out "  "))
            (fprintf out "0x~2,'0x" (bytevector-u8-ref data i))
            (when (< (+ i 1) size) (fprintf out ","))
            (when (= 15 (modulo i 16)) (fprintf out "~n"))
            (loop (+ i 1))))
        (fprintf out "~n};~n")
        (fprintf out "static const unsigned int ~a = ~a;~n" size-name size))
      'replace)
    (printf "  ~a: ~a bytes~n" output-path size)))

;; --- Locate Chez install directory ---
(define chez-dir
  (or (getenv "CHEZ_DIR")
      (let* ((mt (symbol->string (machine-type)))
             (home (getenv "HOME"))
             (lib-dir (format "~a/.local/lib" home))
             (csv-dir
               (let lp ((dirs (guard (e (#t '())) (directory-list lib-dir))))
                 (cond
                   ((null? dirs) #f)
                   ((and (> (string-length (car dirs)) 3)
                         (string=? "csv" (substring (car dirs) 0 3)))
                    (format "~a/~a/~a" lib-dir (car dirs) mt))
                   (else (lp (cdr dirs)))))))
        (and csv-dir
             (file-exists? (format "~a/main.o" csv-dir))
             csv-dir))))

(unless chez-dir
  (display "Error: Cannot find Chez install dir. Set CHEZ_DIR.\n")
  (exit 1))

;; --- Locate dependent library directories ---
(define home (getenv "HOME"))
(define jerboa-dir
  (or (getenv "JERBOA_DIR")
      (format "~a/mine/jerboa/lib" home)))
(define gherkin-dir
  (or (getenv "GHERKIN_DIR")
      (format "~a/mine/gherkin/src" home)))
(define jsh-dir
  (or (getenv "JSH_DIR")
      (format "~a/mine/jerboa-emacs/vendor/jerboa-shell/src" home)))
(define pcre2-dir
  (or (getenv "CHEZ_PCRE2_DIR")
      (format "~a/mine/chez-pcre2" home)))
(define sci-dir
  (or (getenv "CHEZ_SCINTILLA_DIR")
      (format "~a/mine/chez-scintilla/src" home)))
(define qt-dir
  (or (getenv "CHEZ_QT_DIR")
      (format "~a/mine/chez-qt" home)))
(define qt-shim-dir
  (or (getenv "CHEZ_QT_SHIM_DIR")
      (format "~a/mine/gerbil-qt/vendor" home)))

(define coreutils-dir
  (or (getenv "COREUTILS_DIR")
      "/deps/coreutils"))

;; Static build detection (needed before dep checks)
(define jemacs-static?
  (let ((v (getenv "JEMACS_STATIC")))
    (and v (not (string=? v "0")) (not (string=? v "")))))

;; Check critical dependencies
;; For static builds, skip checks on .o files that this script compiles in step 5
;; (jemacs-qt-chez-shim.o, pcre2_shim.o). Only check pre-existing external deps.
(for-each
  (lambda (path label)
    (unless (file-exists? path)
      (printf "Error: ~a not found at ~a~n" label path)
      (exit 1)))
  (if jemacs-static?
    (list (format "~a/jerboa/core.so" jerboa-dir)
          (format "~a/libqt_shim.a" qt-shim-dir))
    (list (format "~a/jerboa/core.so" jerboa-dir)
          "qt_chez_shim.so"
          (format "~a/pcre2_shim.so" pcre2-dir)
          (format "~a/libqt_shim.so" qt-shim-dir)))
  (if jemacs-static?
    (list "jerboa core.so" "libqt_shim.a")
    (list "jerboa core.so" "qt_chez_shim.so" "pcre2_shim.so" "libqt_shim.so")))

(printf "Chez dir:      ~a~n" chez-dir)
(printf "Jerboa dir:    ~a~n" jerboa-dir)
(printf "Gherkin dir:   ~a~n" gherkin-dir)
(printf "jsh dir:       ~a~n" jsh-dir)
(printf "pcre2 dir:     ~a~n" pcre2-dir)
(printf "Sci dir:       ~a~n" sci-dir)
(printf "Qt dir:        ~a~n" qt-dir)
(printf "Qt shim dir:   ~a~n" qt-shim-dir)

;; --- Step 1: Compile all modules + entry point ---
(printf "~n[1/7] Compiling all modules (optimize-level 3, WPO)...~n")
(parameterize ((compile-imported-libraries #t)
               (optimize-level 3)
               (cp0-effort-limit 500)
               (cp0-score-limit 50)
               (cp0-outer-unroll-limit 1)
               (commonization-level 4)
               (enable-unsafe-application #t)
               (enable-unsafe-variable-reference #t)
               (enable-arithmetic-left-associative #t)
               (debug-level 0)
               (generate-inspector-information #f)
               (generate-wpo-files #t))
  (compile-program "qt-main.ss"))

;; --- Step 2: Whole-program optimization ---
(printf "[2/7] Running whole-program optimization...~n")
(let ((missing (compile-whole-program "qt-main.wpo" "jemacs-qt-all.so")))
  (unless (null? missing)
    (printf "  WPO: ~a libraries not incorporated (missing .wpo):~n" (length missing))
    (for-each (lambda (lib) (printf "    ~a~n" lib)) missing)))

;; --- Step 3: Make libs-only boot file ---
(printf "[3/7] Creating libs-only boot file...~n")
(define (existing-so-files paths)
  (filter file-exists? paths))
(apply make-boot-file "jemacs-qt.boot" '("scheme" "petite")
  (existing-so-files
  (append
    ;; Jerboa runtime (no deps on other jerboa libs)
    (map (lambda (m) (format "~a/~a.so" jerboa-dir m))
      '("jerboa/runtime"))
    ;; Jerboa stdlib
    (map (lambda (m) (format "~a/~a.so" jerboa-dir m))
      '("std/error"
        "std/format"
        "std/sort"
        "std/pregexp"
        "std/foreign"
        "std/misc/string"
        "std/misc/list"
        "std/misc/alist"
        "std/misc/thread"
        "std/os/path"
        "std/os/signal"
        "std/os/fdio"))
    ;; Jerboa core + sugar + repl
    (map (lambda (m) (format "~a/~a.so" jerboa-dir m))
      '("jerboa/core"
        "std/sugar"
        "std/repl"))
    ;; std/net/tcp and std/net/uri (compiled by step 1)
    (map (lambda (m) (format "~a/~a.so" jerboa-dir m))
      '("std/net/tcp"
        "std/net/uri"))
    ;; jerboa/repl-socket (non-blocking socket FFI for debug REPL + IPC)
    (list "lib/jerboa/repl-socket.so")
    ;; Gherkin MOP modules (WPO-missing, must be in boot file)
    (map (lambda (m) (format "~a/~a.so" gherkin-dir m))
      '("compat/types"
        "compat/gambit-compat"
        "runtime/util"
        "runtime/table"
        "runtime/c3"
        "runtime/mop"))
    ;; compat/gambit lives in jsh (not gherkin)
    (list (format "~a/compat/gambit.so" jsh-dir))
    ;; jsh modules (WPO-missing, all needed transitively)
    (map (lambda (m) (format "~a/jsh/~a.so" jsh-dir m))
      '("embed"
        "embed-data"
        "ffi"
        "static-compat"
        "pregexp-compat"
        "util"
        "arithmetic"
        "ast"
        "environment"
        "registry"
        "functions"
        "signals"
        "glob"
        "expander"
        "lexer"
        "parser"
        "redirect"
        "pipeline"
        "jobs"
        "builtins"
        "executor"
        "control"
        "script"
        "macros"
        "completion"
        "fuzzy"
        "fzf"
        "history"
        "prompt"
        "lineedit"
        "startup"
        "stage"
        "lib"))
    ;; chez-pcre2 (compiled by step 1)
    (map (lambda (m) (format "~a/chez-pcre2/~a.so" pcre2-dir m))
      '("ffi" "pcre2"))
    ;; std/net/request (WPO-missing)
    (list (format "~a/std/net/request.so" jerboa-dir))
    ;; chez-scintilla (all modules — WPO-missing)
    (map (lambda (m) (format "~a/chez-scintilla/~a.so" sci-dir m))
      '("ffi" "constants" "style" "lexer" "scintilla" "tui"))
    ;; chez-qt
    (map (lambda (m) (format "~a/chez-qt/~a.so" qt-dir m))
      '("ffi" "qt"))
    ;; jerboa-emacs shared modules (topological order)
    (map (lambda (m) (format "lib/jerboa-emacs/~a.so" m))
      '(;; Tier 0: no jerboa-emacs deps
        "customize" "themes" "pregexp-compat" "macros"
        "vtscreen" "pty" "ipc" "debug-repl" "snippets"
        ;; Tier 1: face
        "face"
        ;; Tier 2: core
        "core"
        ;; Tier 3: base editor modules
        "buffer" "echo" "keymap" "repl" "shell-history"
        "subprocess" "gsh-subprocess" "async" "chat"
        "highlight"
        ;; Tier 4: window system
        "window" "modeline" "persist"
        ;; Tier 5: org + shell
        "org-parse" "gsh-eshell" "eshell" "shell"
        "org-export" "org-highlight" "org-list" "org-table"
        "org-clock" "org-babel" "org-capture" "org-agenda"
        ;; Tier 6: helm + terminal
        "helm" "terminal"
        "helm-sources" "helm-tui"
        ;; Tier 7: helm commands + editor extras
        "helm-commands" "editor-extra-helpers"
        ;; Tier 8: editor core
        "editor-core"
        ;; Tier 9: editor UI
        "editor-ui" "editor-text"
        ;; Tier 10: advanced editor
        "editor-advanced"
        ;; Tier 11-13: editor commands
        "editor-cmds-a" "editor-cmds-b" "editor-cmds-c"
        ;; Tier 14+: editor extras chain
        "editor-extra-ai"
        "editor-extra-editing" "editor-extra-editing2"
        "editor-extra-media" "editor-extra-media2"
        "editor-extra-modes"
        "editor-extra-org"
        "editor-extra-regs" "editor-extra-regs2"
        "editor-extra-tools" "editor-extra-tools2"
        "editor-extra-vcs" "editor-extra-web"
        "editor-extra-final" "editor-extra"
        ;; TUI top-level (editor shared with Qt)
        "editor"))
    ;; Qt-specific modules
    (map (lambda (m) (format "lib/jerboa-emacs/qt/~a.so" m))
      '(;; Foundation
        "sci-shim" "keymap" "buffer" "echo"
        "image" "magit"
        "highlight" "modeline" "window"
        "lsp-client" "helm-qt"
        "snippets" "menubar"
        ;; Commands (pairs: base + extended)
        "commands-core" "commands-core2"
        "commands-edit" "commands-edit2"
        "commands-file" "commands-file2"
        "commands-search" "commands-search2"
        "commands-sexp" "commands-sexp2"
        "commands-shell" "commands-shell2"
        "commands-vcs" "commands-vcs2"
        "commands-ide" "commands-ide2"
        "commands-lsp"
        "commands-modes" "commands-modes2"
        "commands-parity" "commands-parity2"
        "commands-parity3" "commands-parity3b"
        "commands-parity4" "commands-parity5"
        "commands-config" "commands-config2"
        "commands-aliases" "commands-aliases2"
        "commands"
        ;; Qt app
        "app" "main")))))

;; --- Step 4: Generate C headers with embedded data ---
(printf "[4/7] Embedding boot files + program as C headers...~n")
(file->c-header "jemacs-qt-all.so"  "jemacs_qt_program.h"
                "jemacs_qt_program_data" "jemacs_qt_program_size")
(file->c-header (format "~a/petite.boot" chez-dir) "jemacs_qt_petite_boot.h"
                "petite_boot_data" "petite_boot_size")
(file->c-header (format "~a/scheme.boot" chez-dir) "jemacs_qt_scheme_boot.h"
                "scheme_boot_data" "scheme_boot_size")
(file->c-header "jemacs-qt.boot" "jemacs_qt_jemacs_qt_boot.h"
                "jemacs_qt_boot_data" "jemacs_qt_boot_size")

;; --- Helper: run a shell command and capture its first output line ---
(define (shell-output cmd default)
  (let ((tmpfile "/tmp/jemacs-qt-build-tmp.txt"))
    (system (format "~a > ~a 2>/dev/null; true" cmd tmpfile))
    (if (file-exists? tmpfile)
      (let* ((p (open-input-file tmpfile))
             (line (get-line p)))
        (close-port p)
        (delete-file tmpfile)
        (if (eof-object? line) default line))
      default)))

(when jemacs-static?
  (printf "Static build mode: JEMACS_STATIC=1~n"))

;; --- Step 5: Compile C sources ---
(printf "[5/7] Compiling C sources...~n")

;; pcre2 shim
(let* ((pcre2-cflags (shell-output "pkg-config --cflags libpcre2-8" "-I/usr/include"))
       (cmd (format "gcc -c -O2 -o jemacs-qt-pcre2-shim.o ~a/pcre2_shim.c ~a -Wall 2>&1"
                    pcre2-dir pcre2-cflags)))
  (unless (= 0 (system cmd))
    (display "Error: pcre2 shim compilation failed\n")
    (exit 1)))

;; qt_chez_shim — use jerboa-emacs deferred-callback version (avoids Sactivate_thread GC deadlock)
(let* ((qt-cflags (shell-output "pkg-config --cflags Qt6Widgets" "")))
  ;; Static .o for static builds
  (let ((cmd (format "gcc -c -O2 -DQT_SCINTILLA_AVAILABLE -o jemacs-qt-chez-shim.o vendor/qt_chez_shim.c -I~a ~a -Wall 2>&1"
                     qt-shim-dir qt-cflags)))
    (unless (= 0 (system cmd))
      (display "Error: qt_chez_shim compilation failed\n")
      (exit 1)))
  ;; Shared .so for dynamic builds
  (unless jemacs-static?
    (let ((cmd (format "gcc -shared -fPIC -O2 -DQT_SCINTILLA_AVAILABLE -o qt_chez_shim.so vendor/qt_chez_shim.c -I~a ~a -Wall 2>&1"
                       qt-shim-dir qt-cflags)))
      (unless (= 0 (system cmd))
        (display "Error: qt_chez_shim.so compilation failed\n")
        (exit 1)))))

;; Static: generate + compile foreign symbol registration table
;; (dlopen(NULL) is a stub in musl static builds, so we use Sforeign_symbol instead)
(when jemacs-static?
  ;; scheme.h lives in chez-dir (same dir as libkernel.a)
  (let* ((ffi-path (format "~a/chez-qt/ffi.ss" qt-dir))
         (pcre2-ffi-path (format "~a/chez-pcre2/ffi.ss" pcre2-dir))
         (include-dir chez-dir)
         ;; Generate the C file by scanning ALL FFI source files:
         ;;   chez-qt/ffi.ss, chez-pcre2/ffi.ss — specific files
         ;;   jsh-dir/, jerboa-dir/, lib/jerboa-emacs/ — recursive (catches all transitive deps)
         ;; Strip Scheme line comments (;; ...) before matching to avoid placeholder strings
         ;; like "c_name", "c_func", "c_function_name" that appear in macro doc comments.
         ;; Two patterns extracted:
         ;;   (foreign-procedure "name")    — direct Chez FFI
         ;;   define-foreign name "c-name"  — jsh macro (C name is the second string)
         (gen-cmd
           (format
             "{ { cat ~a ~a; find ~a ~a ~a lib/jerboa-emacs lib/jerboa vendor -name '*.sls' -o -name '*.ss' | xargs cat 2>/dev/null; cat ~a/jerboa-coreutils/top.sls 2>/dev/null; } | \
sed 's/;;.*//' | grep -oE '(foreign-procedure|foreign-entry\\?) \"[^\"]*\"' | sed 's/.* \"//;s/\"//'; \
{ cat ~a ~a; } | sed 's/;;.*//' | grep -o 'define-optional-ffi [^ ]* \"[^\"]*\"' | sed 's/.*define-optional-ffi [^ ]* \"//;s/\"//'; \
find ~a -name '*.sls' -o -name '*.ss' | \
  xargs grep -oh 'define-foreign [^ ]* \"[^\"]*\"' 2>/dev/null | \
  sed 's/.*define-foreign [^ ]* \"//;s/\".*//'; } | \
sort -u | grep -v '^$' | grep -v '^_NSGetExecutablePath$' | grep -v '^io_uring_' > /tmp/ffi_syms.txt && \
awk '\
BEGIN{ print \"/* Auto-generated — do not edit */\"; \
       print \"#include \\\"scheme.h\\\"\"; print \"\"; } \
{ print \"extern void \" $1 \"(void);\" } \
END{ print \"\"; print \"void register_static_foreign_symbols(void) {\"; } \
' /tmp/ffi_syms.txt > qt_static_symbols.c && \
awk '{ print \"    Sforeign_symbol(\\\"\" $1 \"\\\", (void*)\" $1 \");\" }' \
/tmp/ffi_syms.txt >> qt_static_symbols.c && \
echo \"}\" >> qt_static_symbols.c && \
rm /tmp/ffi_syms.txt && \
echo OK"
             ffi-path pcre2-ffi-path
             jsh-dir jerboa-dir sci-dir coreutils-dir
             ffi-path pcre2-ffi-path
             jsh-dir))
         (result (shell-output gen-cmd "")))
    (unless (string=? (string-downcase (substring result 0 (min 2 (string-length result)))) "ok")
      (printf "Error generating qt_static_symbols.c: ~a~n" result)
      (exit 1))
    (let* ((count-cmd "grep -c 'Sforeign_symbol' qt_static_symbols.c")
           (count (let ((s (shell-output count-cmd "0")))
                    ;; trim trailing newline
                    (if (and (> (string-length s) 0)
                             (char=? (string-ref s (- (string-length s) 1)) #\newline))
                        (substring s 0 (- (string-length s) 1))
                        s))))
      (printf "  Generated qt_static_symbols.c with ~a symbol registrations~n" count))
    (let* ((cmd (format "gcc -c -O2 -o qt_static_symbols.o qt_static_symbols.c -I~a -Wall 2>&1"
                        include-dir)))
      (unless (= 0 (system cmd))
        (display "Error: qt_static_symbols.c compilation failed\n")
        (exit 1)))))

;; jsh FFI shim (needed for static builds so ffi_* symbols are in the binary)
;; ffi-shim.c lives in the jsh root (parent of jsh-dir which is the src/ subdir)
(when jemacs-static?
  (let* ((jsh-root (path-parent jsh-dir))
         (cmd (format "gcc -c -O2 -o jemacs-qt-jsh-ffi.o ~a/ffi-shim.c -Wall 2>&1"
                      jsh-root)))
    (unless (= 0 (system cmd))
      (display "Error: jsh ffi-shim.c compilation failed\n")
      (exit 1))))

;; jsh embed-crypto (pure C crypto for embed encryption — no external deps)
(when jemacs-static?
  (let* ((jsh-root (path-parent jsh-dir))
         (cmd (format "gcc -c -O2 -o jemacs-qt-embed-crypto.o ~a/embed-crypto.c -I~a -Wall 2>&1"
                      jsh-root jsh-root)))
    (unless (= 0 (system cmd))
      (display "Error: embed-crypto.c compilation failed\n")
      (exit 1))))

;; jsh ssh-agent stub (chez_ssh_agent_stop referenced in main.sls but not needed for jemacs)
(when jemacs-static?
  (let ((stub-file "jemacs-qt-ssh-agent-stub.c"))
    (call-with-output-file stub-file
      (lambda (out)
        (fprintf out "/* Stub — jemacs doesn't use ssh-agent */~n")
        (fprintf out "void chez_ssh_agent_stop(void) {}~n")
        (fprintf out "int chez_ssh_agent_is_running(void) { return 0; }~n"))
      'replace)
    (let ((cmd (format "gcc -c -O2 -o jemacs-qt-ssh-agent-stub.o ~a -Wall 2>&1" stub-file)))
      (unless (= 0 (system cmd))
        (display "Error: ssh-agent stub compilation failed\n")
        (exit 1)))))

;; chez-scintilla stubs (TUI-only — Qt never calls these; stubs allow foreign-procedure defs)
(when jemacs-static?
  (let* ((cmd "gcc -c -O2 -o jemacs-qt-sci-stubs.o support/chez_scintilla_stubs.c -Wall 2>&1"))
    (unless (= 0 (system cmd))
      (display "Error: chez_scintilla_stubs.c compilation failed\n")
      (exit 1))))

;; pty shim (needed for static builds — pty_* symbols from support/pty_shim.c)
(when jemacs-static?
  (let* ((cmd "gcc -c -O2 -o jemacs-qt-pty-shim.o support/pty_shim.c -Wall 2>&1"))
    (unless (= 0 (system cmd))
      (display "Error: pty_shim.c compilation failed\n")
      (exit 1))))

;; vterm shim (libvterm FFI — jvt_* symbols from support/vterm_shim.c)
(when jemacs-static?
  (let* ((cmd "gcc -c -O2 -o jemacs-qt-vterm-shim.o support/vterm_shim.c -Wall 2>&1"))
    (unless (= 0 (system cmd))
      (display "Error: vterm_shim.c compilation failed\n")
      (exit 1))))

;; repl shim (poll/nanosleep/Sdeactivate wrappers for debug REPL in static builds)
(when jemacs-static?
  (let* ((cmd (format "gcc -c -O2 -o jemacs-qt-repl-shim.o support/repl_shim.c -I~a -Wall 2>&1"
                       chez-dir)))
    (unless (= 0 (system cmd))
      (display "Error: repl_shim.c compilation failed\n")
      (exit 1))))

;; jerboa landlock shim (jerboa_landlock_* symbols from jerboa/support/landlock-shim.c)
(when jemacs-static?
  (let* ((jerboa-root (path-parent jerboa-dir))
         (cmd (format "gcc -c -O2 -o jemacs-qt-jerboa-landlock.o ~a/support/landlock-shim.c -Wall 2>&1"
                      jerboa-root)))
    (unless (= 0 (system cmd))
      (display "Error: landlock-shim.c compilation failed\n")
      (exit 1))))

;; jemacs-qt-main.c
(let* ((static-flag (if jemacs-static? "-DJEMACS_STATIC_BUILD" ""))
       (cmd (format "gcc -c -O2 ~a -o jemacs-qt-main.o jemacs-qt-main.c -I~a -I. -Wall 2>&1"
                    static-flag chez-dir)))
  (unless (= 0 (system cmd))
    (display "Error: jemacs-qt-main.c compilation failed\n")
    (exit 1)))

;; --- Step 6: Link native binary ---
(printf "[6/7] Linking native binary...~n")
(if jemacs-static?
  ;; ─── Static link (Docker musl build) ───────────────────────────────────
  ;; -static: fully static binary (musl embeds dynamic linker, dlopen works)
  ;; -Wl,--export-dynamic: export main binary symbols so the embedded .so
  ;;   (loaded via Sscheme_script/dlopen from memfd) can find Chez kernel symbols
  ;; qt_static_plugins.o must be linked OUTSIDE archives (not in libqt_shim.a)
  ;;   because it contains Q_IMPORT_PLUGIN static constructors the linker drops from archives
  (let* ((pcre2-libs  (shell-output "pkg-config --static --libs libpcre2-8" "-lpcre2-8"))
         (qt-libs     (shell-output
                        "pkg-config --static --libs Qt6Widgets Qt6XcbPlugin QScintilla"
                        "-lQt6Widgets -lQt6Gui -lQt6Core"))
         (qt-plugins  (format "~a/qt_static_plugins.o" qt-shim-dir))
         (libqt-shim  (format "~a/libqt_shim.a" qt-shim-dir))
         (cmd (format "g++ -static -Wl,--export-dynamic -o jemacs-qt \
jemacs-qt-main.o jemacs-qt-chez-shim.o jemacs-qt-pcre2-shim.o jemacs-qt-jsh-ffi.o \
jemacs-qt-embed-crypto.o jemacs-qt-ssh-agent-stub.o \
jemacs-qt-pty-shim.o jemacs-qt-vterm-shim.o jemacs-qt-repl-shim.o jemacs-qt-jerboa-landlock.o jemacs-qt-sci-stubs.o \
qt_static_symbols.o \
~a ~a ~a ~a \
-L~a -lkernel -llz4 -lz \
-lvterm -lm -ldl -lpthread -luuid -lncurses -lstdc++ 2>&1"
                      libqt-shim qt-plugins qt-libs pcre2-libs
                      chez-dir)))
    (printf "  ~a~n" cmd)
    (unless (= 0 (system cmd))
      (display "Error: Static link failed\n")
      (exit 1)))
  ;; ─── Dynamic link (default local build) ────────────────────────────────
  (let* ((pcre2-libs (shell-output "pkg-config --libs libpcre2-8" "-lpcre2-8"))
         (qt-libs    (shell-output "pkg-config --libs Qt6Widgets" "-lQt6Widgets -lQt6Gui -lQt6Core"))
         ;; Link against ./libqt_shim.so (local copy with JEMACS_CHEZ_SMP)
         ;; rather than qt-shim-dir (gerbil-qt vendor — no Sdeactivate)
         (cmd (format "g++ -rdynamic -o jemacs-qt jemacs-qt-main.o jemacs-qt-chez-shim.o jemacs-qt-pcre2-shim.o ~a ~a -L~a -lkernel -llz4 -lz -lm -ldl -lpthread -luuid -lncurses -lstdc++ -L. -lqt_shim -lqscintilla2_qt6 -lvterm -Wl,-rpath,~a -Wl,-rpath,'$ORIGIN' 2>&1"
                      pcre2-libs qt-libs chez-dir chez-dir)))
    (printf "  ~a~n" cmd)
    (unless (= 0 (system cmd))
      (display "Error: Link failed\n")
      (exit 1))))

;; --- Step 7: Clean up intermediate files ---
(printf "[7/7] Cleaning up...~n")
(for-each (lambda (f)
            (when (file-exists? f) (delete-file f)))
  (append
    '("jemacs-qt-main.o" "jemacs-qt-chez-shim.o" "jemacs-qt-pcre2-shim.o"
      "jemacs_qt_program.h" "jemacs_qt_petite_boot.h"
      "jemacs_qt_scheme_boot.h" "jemacs_qt_jemacs_qt_boot.h"
      "jemacs-qt-all.so" "qt-main.so" "qt-main.wpo" "jemacs-qt.boot")
    (if jemacs-static?
        '("jemacs-qt-jsh-ffi.o" "jemacs-qt-embed-crypto.o"
          "jemacs-qt-ssh-agent-stub.o" "jemacs-qt-ssh-agent-stub.c"
          "jemacs-qt-pty-shim.o" "jemacs-qt-vterm-shim.o"
          "jemacs-qt-jerboa-landlock.o"
          "jemacs-qt-sci-stubs.o" "qt_static_symbols.o" "qt_static_symbols.c")
        '())))

(printf "~n========================================~n")
(printf "Build complete!~n~n")
(printf "  Binary: ./jemacs-qt  (~a KB)~n"
  (quotient (file-length (open-file-input-port "jemacs-qt")) 1024))
(if jemacs-static?
  (begin
    (printf "~nStatically linked — no runtime .so dependencies.~n")
    (printf "~nRun:~n")
    (printf "  ./jemacs-qt                # launch Qt editor~n")
    (printf "  ./jemacs-qt file.txt       # open file~n")
    (printf "~nInstall:~n")
    (printf "  cp jemacs-qt /usr/local/bin/~n"))
  (begin
    ;; Copy shim .so files alongside binary for dynamic builds
    (system (format "cp ~a/libqt_shim.so . 2>/dev/null; true" qt-shim-dir))
    ;; qt_chez_shim.so already built locally from vendor/qt_chez_shim.c
    (system (format "cp ~a/pcre2_shim.so . 2>/dev/null; true" pcre2-dir))
    (printf "~nBundle (keep these together):~n")
    (printf "  ./jemacs-qt~n")
    (printf "  ./libqt_shim.so~n")
    (printf "  ./qt_chez_shim.so~n")
    (printf "  ./pcre2_shim.so~n")
    (printf "  ./vterm_shim.so~n")
    (printf "~nRun:~n")
    (printf "  ./jemacs-qt                # launch Qt editor~n")
    (printf "  ./jemacs-qt file.txt       # open file~n")
    (printf "~nInstall:~n")
    (printf "  cp jemacs-qt libqt_shim.so qt_chez_shim.so pcre2_shim.so vterm_shim.so /usr/local/bin/~n")))
