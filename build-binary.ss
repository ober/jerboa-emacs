#!chezscheme
;; Build a native jemacs binary for jerboa-emacs (TUI frontend).
;;
;; Usage: cd jerboa-emacs && make binary
;;
;; Produces: ./jemacs (ELF binary with embedded boot files + program)
;;
;; All boot files are embedded as C byte arrays via Sregister_boot_file_bytes.
;; FFI shims (pcre2, scintilla, jsh) are:
;;   - Static build (JEMACS_STATIC=1): compiled into the binary
;;   - Dynamic build (default): loaded at runtime via load-shared-object
;;
;; Unlike jemacs-qt, the TUI binary links against ncurses + libScintilla
;; instead of Qt. No Qt shims or Qt-static-plugin registration needed.

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

;; --- Helper: run a shell command and capture its first output line ---
(define (shell-output cmd default)
  (let ((tmpfile "/tmp/jemacs-tui-build-tmp.txt"))
    (system (format "~a > ~a 2>/dev/null; true" cmd tmpfile))
    (if (file-exists? tmpfile)
      (let* ((p (open-input-file tmpfile))
             (line (get-line p)))
        (close-port p)
        (delete-file tmpfile)
        (if (eof-object? line) default line))
      default)))

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
;; gerbil-scintilla vendor dir: contains scintilla.a, liblexilla.a, termbox.a
;; and the C header files needed to compile chez_scintilla_shim.c
(define sci-vendor-dir
  (or (getenv "SCI_VENDOR_DIR")
      (format "~a/mine/gerbil-emacs/.gerbil/pkg/github.com/ober/gerbil-scintilla/vendor" home)))

;; Static build detection
(define jemacs-static?
  (let ((v (getenv "JEMACS_STATIC")))
    (and v (not (string=? v "0")) (not (string=? v "")))))

;; Check critical dependencies
(for-each
  (lambda (path label)
    (unless (file-exists? path)
      (printf "Error: ~a not found at ~a~n" label path)
      (exit 1)))
  (if jemacs-static?
    (list (format "~a/jerboa/core.so" jerboa-dir)
          (format "~a/scintilla/bin/scintilla.a" sci-vendor-dir)
          (format "~a/lexilla/bin/liblexilla.a" sci-vendor-dir))
    (list (format "~a/jerboa/core.so" jerboa-dir)))
  (if jemacs-static?
    (list "jerboa core.so" "scintilla.a" "liblexilla.a")
    (list "jerboa core.so")))

(printf "Chez dir:      ~a~n" chez-dir)
(printf "Jerboa dir:    ~a~n" jerboa-dir)
(printf "Gherkin dir:   ~a~n" gherkin-dir)
(printf "jsh dir:       ~a~n" jsh-dir)
(printf "pcre2 dir:     ~a~n" pcre2-dir)
(printf "Sci dir:       ~a~n" sci-dir)
(when jemacs-static?
  (printf "Sci vendor:    ~a~n" sci-vendor-dir)
  (printf "Static build mode: JEMACS_STATIC=1~n"))

;; --- Step 1: Compile all modules + entry point ---
(printf "~n[1/6] Compiling all modules (optimize-level 3, WPO)...~n")
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
  (compile-program "main.ss"))

;; --- Step 2: Whole-program optimization ---
(printf "[2/6] Running whole-program optimization...~n")
(let ((missing (compile-whole-program "main.wpo" "jemacs-all.so")))
  (unless (null? missing)
    (printf "  WPO: ~a libraries not incorporated (missing .wpo):~n" (length missing))
    (for-each (lambda (lib) (printf "    ~a~n" lib)) missing)))

;; --- Step 3: Make libs-only boot file ---
(printf "[3/6] Creating libs-only boot file...~n")
(define (existing-so-files paths)
  (filter file-exists? paths))
(apply make-boot-file "jemacs.boot" '("scheme" "petite")
  (existing-so-files
  (append
    ;; Jerboa runtime (no deps on other jerboa libs)
    (map (lambda (m) (format "~a/~a.so" jerboa-dir m))
      '("jerboa/runtime"))
    ;; Jerboa stdlib — include all available .so modules (existing-so-files filters missing ones)
    (map (lambda (m) (format "~a/~a.so" jerboa-dir m))
      '("std/error"
        "std/format"
        "std/sort"
        "std/pregexp"
        "std/foreign"
        "std/iter"
        "std/log"
        "std/string"
        "std/misc/string"
        "std/misc/list"
        "std/misc/alist"
        "std/misc/thread"
        "std/misc/fmt"
        "std/misc/atom"
        "std/misc/channel"
        "std/misc/completion"
        "std/misc/memo"
        "std/misc/number"
        "std/misc/process"
        "std/misc/rwlock"
        "std/misc/shuffle"
        "std/misc/uuid"
        "std/os/path"
        "std/os/env"
        "std/os/signal"
        "std/os/fdio"
        "std/misc/custodian"
        "std/misc/config"
        "std/misc/memoize"
        "std/misc/terminal"
        "std/misc/trie"
        "std/misc/lru-cache"
        "std/misc/ports"
        "std/srfi/srfi-1"
        "std/srfi/srfi-13"
        "std/srfi/srfi-19"
        "std/text/base64"
        "std/text/diff"
        "std/text/glob"
        "std/text/hex"
        "std/text/json"
        "std/actor/mpsc"
        "std/actor/core"
        "std/actor/transport"
        "std/crypto/digest"
        "std/crypto/native"
        "std/crypto/random"
        "std/os/sandbox"
        "std/os/landlock"
        "std/security/capsicum"))
    ;; Jerboa core + sugar + repl + dependencies
    (map (lambda (m) (format "~a/~a.so" jerboa-dir m))
      '("std/result"
        "std/typed"
        "jerboa/core"
        "std/sugar"
        "std/repl"))
    ;; std/net modules (for IPC + debug REPL)
    (map (lambda (m) (format "~a/~a.so" jerboa-dir m))
      '("std/net/tcp"
        "std/net/tcp-raw"
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
        "recording-index"
        "recorder"
        "player"
        "conditions"
        "config"
        "sandbox"
        "lib"))
    ;; std/net/request (WPO-missing)
    (list (format "~a/std/net/request.so" jerboa-dir))
    ;; chez-pcre2 (compiled by step 1)
    (map (lambda (m) (format "~a/chez-pcre2/~a.so" pcre2-dir m))
      '("ffi" "pcre2"))
    ;; chez-scintilla TUI modules (real — not stubs)
    (map (lambda (m) (format "~a/chez-scintilla/~a.so" sci-dir m))
      '("ffi" "constants" "style" "lexer" "scintilla" "tui"))
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
        ;; TUI top-level
        "editor"
        "app")))))

;; --- Step 4: Generate C headers with embedded data ---
(printf "[4/6] Embedding boot files + program as C headers...~n")
(file->c-header "jemacs-all.so"  "jemacs_program.h"
                "jemacs_program_data" "jemacs_program_size")
(file->c-header (format "~a/petite.boot" chez-dir) "jemacs_petite_boot.h"
                "petite_boot_data" "petite_boot_size")
(file->c-header (format "~a/scheme.boot" chez-dir) "jemacs_scheme_boot.h"
                "scheme_boot_data" "scheme_boot_size")
(file->c-header "jemacs.boot" "jemacs_jemacs_boot.h"
                "jemacs_boot_data" "jemacs_boot_size")

;; --- Step 5: Compile C sources ---
(printf "[5/6] Compiling C sources...~n")

;; pcre2 shim
(let* ((pcre2-cflags (shell-output "pkg-config --cflags libpcre2-8" "-I/usr/include"))
       (cmd (format "gcc -c -O2 -o jemacs-pcre2-shim.o ~a/pcre2_shim.c ~a -Wall 2>&1"
                    pcre2-dir pcre2-cflags)))
  (unless (= 0 (system cmd))
    (display "Error: pcre2 shim compilation failed\n")
    (exit 1)))

;; Static-only C sources
(when jemacs-static?
  ;; jsh FFI shim
  (let* ((jsh-root (path-parent jsh-dir))
         (cmd (format "gcc -c -O2 -o jemacs-jsh-ffi.o ~a/ffi-shim.c -Wall 2>&1"
                      jsh-root)))
    (unless (= 0 (system cmd))
      (display "Error: jsh ffi-shim.c compilation failed\n")
      (exit 1)))

  ;; libcoreutils.c (terminal/raw-mode symbols)
  (let* ((jsh-root (path-parent jsh-dir))
         (cmd (format "gcc -c -O2 -o jemacs-libcoreutils.o ~a/libcoreutils.c -Wall 2>&1"
                      jsh-root)))
    (unless (= 0 (system cmd))
      (display "Error: libcoreutils.c compilation failed\n")
      (exit 1)))

  ;; jsh coreutils stubs (Rust uutils symbols — stubs for static binary)
  (let* ((cmd "gcc -c -O2 -o jemacs-jsh-coreutils-stubs.o support/jsh_coreutils_stubs.c -Wall 2>&1"))
    (unless (= 0 (system cmd))
      (display "Error: jsh_coreutils_stubs.c compilation failed\n")
      (exit 1)))

  ;; embed-crypto
  (let* ((jsh-root (path-parent jsh-dir))
         (cmd (format "gcc -c -O2 -o jemacs-embed-crypto.o ~a/embed-crypto.c -I~a -Wall 2>&1"
                      jsh-root jsh-root)))
    (unless (= 0 (system cmd))
      (display "Error: embed-crypto.c compilation failed\n")
      (exit 1)))

  ;; ssh-agent stub
  (let ((stub-file "jemacs-ssh-agent-stub.c"))
    (call-with-output-file stub-file
      (lambda (out)
        (fprintf out "/* Stub — jemacs doesn't use ssh-agent */~n")
        (fprintf out "void chez_ssh_agent_stop(void) {}~n")
        (fprintf out "int chez_ssh_agent_is_running(void) { return 0; }~n"))
      'replace)
    (let ((cmd "gcc -c -O2 -o jemacs-ssh-agent-stub.o jemacs-ssh-agent-stub.c -Wall 2>&1"))
      (unless (= 0 (system cmd))
        (display "Error: ssh-agent stub compilation failed\n")
        (exit 1))))

  ;; pty shim
  (let* ((cmd "gcc -c -O2 -o jemacs-pty-shim.o support/pty_shim.c -Wall 2>&1"))
    (unless (= 0 (system cmd))
      (display "Error: pty_shim.c compilation failed\n")
      (exit 1)))

  ;; vterm shim
  (let* ((cmd "gcc -c -O2 -o jemacs-vterm-shim.o support/vterm_shim.c -Wall 2>&1"))
    (unless (= 0 (system cmd))
      (display "Error: vterm_shim.c compilation failed\n")
      (exit 1)))

  ;; repl shim
  (let* ((cmd (format "gcc -c -O2 -o jemacs-repl-shim.o support/repl_shim.c -I~a -Wall 2>&1"
                       chez-dir)))
    (unless (= 0 (system cmd))
      (display "Error: repl_shim.c compilation failed\n")
      (exit 1)))

  ;; jerboa landlock shim
  (let* ((jerboa-root (path-parent jerboa-dir))
         (cmd (format "gcc -c -O2 -o jemacs-jerboa-landlock.o ~a/support/landlock-shim.c -Wall 2>&1"
                      jerboa-root)))
    (unless (= 0 (system cmd))
      (display "Error: landlock-shim.c compilation failed\n")
      (exit 1)))

  ;; chez-scintilla real shim (not stubs — TUI needs actual scintilla symbols)
  ;; Compiled against the static scintilla headers from sci-vendor-dir
  (let* ((sci-include (format "-I~a/scintilla/include -I~a/scintilla/src -I~a/scintilla/termbox -I~a/scintilla/termbox/termbox_next/src -I~a/lexilla/include"
                               sci-vendor-dir sci-vendor-dir sci-vendor-dir sci-vendor-dir sci-vendor-dir))
         (sci-shim-c  (format "~a/../chez_scintilla_shim.c" sci-dir))
         (cmd (format "gcc -c -O2 -o jemacs-sci-shim.o ~a ~a -Wall 2>&1"
                      sci-shim-c sci-include)))
    (unless (= 0 (system cmd))
      (display "Error: chez_scintilla_shim.c compilation failed\n")
      (exit 1)))

  ;; Generate FFI symbol registration table
  ;; Scans Scheme sources for foreign-procedure calls, generates tui_static_symbols.c
  (let* ((ffi-path (format "~a/chez-pcre2/ffi.ss" pcre2-dir))
         (include-dir chez-dir)
         (gen-cmd
           (format
             "{ { cat ~a; find ~a ~a/jerboa ~a/std/os ~a/std/net ~a/std/crypto ~a/std/security ~a/chez-scintilla lib/jerboa-emacs lib/jerboa vendor -path '*/qt/*' -prune -o -name '*.sls' -print -o -name '*.ss' -print | xargs cat 2>/dev/null; } | \
sed 's/;;.*//' | grep -oE '(foreign-procedure|foreign-entry\\?) \"[^\"]*\"' | sed 's/.* \"//;s/\"//'; \
{ cat ~a; } | sed 's/;;.*//' | grep -o 'define-optional-ffi [^ ]* \"[^\"]*\"' | sed 's/.*define-optional-ffi [^ ]* \"//;s/\"//'; \
find ~a -name '*.sls' -o -name '*.ss' | \
  xargs cat 2>/dev/null | tr '\\n' ' ' | \
  grep -oE 'define-foreign [^ ]+ +\"[^\"]+\"' | \
  sed 's/.*define-foreign [^ ]* *\"//;s/\".*//'; } | \
sort -u | grep -v '^$' | grep -v '^_NSGetExecutablePath$' | grep -v '^io_uring_' | \
grep -v '^jerboa_' | grep -v '^SSL_' | grep -v '^TLS_' | grep -v '^EVP_' | \
grep -v '^CRYPTO_' | grep -v '^PKCS5_' | grep -v '^RAND_' | \
grep -v '^QRcode_' | grep -v '^embed_encrypt$' | grep -v '^embed_random_bytes$' | \
grep -v '^kqueue$' | grep -v '^kevent$' | grep -v '^sandbox_' | \
grep -v '^__error$' | grep -v '^ts_shim_' | grep -v '^ts_parser_' | grep -v '^ts_tree_' | grep -v '^ts_node_' | \
grep -v '^ts_query_' | grep -v '^ts_language_' | grep -v '^tree_sitter_' | \
grep -v '^qt_' | grep -v '^QRcode_' | grep -v '^chez_tcp_' | grep -v '^chez_ssl_' | grep -v '^chez_qt_' | grep -v '^chez_conn_' > /tmp/tui_ffi_syms.txt && \
awk '\
BEGIN{ print \"/* Auto-generated — do not edit */\"; \
       print \"#include \\\"scheme.h\\\"\"; print \"\"; } \
{ print \"extern void \" $1 \"(void);\" } \
END{ print \"\"; print \"void register_static_foreign_symbols(void) {\"; } \
' /tmp/tui_ffi_syms.txt > tui_static_symbols.c && \
awk '{ print \"    Sforeign_symbol(\\\"\" $1 \"\\\", (void*)\" $1 \");\" }' \
/tmp/tui_ffi_syms.txt >> tui_static_symbols.c && \
echo \"}\" >> tui_static_symbols.c && \
rm /tmp/tui_ffi_syms.txt && \
echo OK"
             ffi-path
             jsh-dir jerboa-dir jerboa-dir jerboa-dir jerboa-dir jerboa-dir sci-dir
             ffi-path
             jsh-dir))
         (result (shell-output gen-cmd "")))
    (unless (string=? (string-downcase (substring result 0 (min 2 (string-length result)))) "ok")
      (printf "Error generating tui_static_symbols.c: ~a~n" result)
      (exit 1))
    (let* ((count (shell-output "grep -c 'Sforeign_symbol' tui_static_symbols.c" "0")))
      (printf "  Generated tui_static_symbols.c with ~a symbol registrations~n" count))
    (let* ((cmd (format "gcc -c -O2 -o tui_static_symbols.o tui_static_symbols.c -I~a -Wall 2>&1"
                        include-dir)))
      (unless (= 0 (system cmd))
        (display "Error: tui_static_symbols.c compilation failed\n")
        (exit 1)))))

;; Dynamic build: compile all C shims so their symbols are in the binary.
;; Linked with -rdynamic so foreign-procedure finds them via dlopen(NULL).
(when (not jemacs-static?)
  ;; repl shim (repl_poll, repl_nanosleep, etc.)
  (let* ((cmd (format "gcc -c -O2 -o jemacs-repl-shim.o support/repl_shim.c -I~a -Wall 2>&1"
                       chez-dir)))
    (unless (= 0 (system cmd))
      (display "Error: repl_shim.c (dynamic) compilation failed\n")
      (exit 1)))
  ;; jsh FFI shim (ffi_file_type, ffi_*, etc.)
  (let* ((jsh-root (path-parent jsh-dir))
         (cmd (format "gcc -c -O2 -o jemacs-jsh-ffi.o ~a/ffi-shim.c -Wall 2>&1"
                      jsh-root)))
    (unless (= 0 (system cmd))
      (display "Error: jsh ffi-shim.c (dynamic) compilation failed\n")
      (exit 1)))
  ;; libcoreutils (coreutils_raw_mode_*, coreutils_terminal_*, etc.)
  (let* ((jsh-root (path-parent jsh-dir))
         (cmd (format "gcc -c -O2 -o jemacs-libcoreutils.o ~a/libcoreutils.c -Wall 2>&1"
                      jsh-root)))
    (unless (= 0 (system cmd))
      (display "Error: libcoreutils.c (dynamic) compilation failed\n")
      (exit 1)))
  ;; embed-crypto (embed_* symbols)
  (let* ((jsh-root (path-parent jsh-dir))
         (cmd (format "gcc -c -O2 -o jemacs-embed-crypto.o ~a/embed-crypto.c -I~a -Wall 2>&1"
                      jsh-root jsh-root)))
    (unless (= 0 (system cmd))
      (display "Error: embed-crypto.c (dynamic) compilation failed\n")
      (exit 1)))
  ;; ssh-agent stub
  (let ((stub-file "jemacs-ssh-agent-stub.c"))
    (call-with-output-file stub-file
      (lambda (out)
        (fprintf out "/* Stub — jemacs doesn't use ssh-agent */~n")
        (fprintf out "void chez_ssh_agent_stop(void) {}~n")
        (fprintf out "int chez_ssh_agent_is_running(void) { return 0; }~n"))
      'replace)
    (let ((cmd "gcc -c -O2 -o jemacs-ssh-agent-stub.o jemacs-ssh-agent-stub.c -Wall 2>&1"))
      (unless (= 0 (system cmd))
        (display "Error: ssh-agent stub (dynamic) compilation failed\n")
        (exit 1))))
  ;; jsh coreutils stubs (jsh_* Rust uutils symbols)
  (let* ((cmd "gcc -c -O2 -o jemacs-jsh-coreutils-stubs.o support/jsh_coreutils_stubs.c -Wall 2>&1"))
    (unless (= 0 (system cmd))
      (display "Error: jsh_coreutils_stubs.c (dynamic) compilation failed\n")
      (exit 1)))
  ;; TLS rustls stubs (jerboa_tls_* Rust FFI symbols — jemacs TUI doesn't use HTTPS)
  (let ((stub-file "jemacs-tls-stubs.c"))
    (call-with-output-file stub-file
      (lambda (out)
        (fprintf out "/* Stub — jemacs TUI doesn't use rustls TLS */~n")
        (fprintf out "#include <stddef.h>~n#include <stdint.h>~n")
        (fprintf out "uint64_t jerboa_tls_server_new(const char *c, const char *k) { return 0; }~n")
        (fprintf out "uint64_t jerboa_tls_server_new_mtls(const char *c, const char *k, const char *ca) { return 0; }~n")
        (fprintf out "void jerboa_tls_server_free(uint64_t s) {}~n")
        (fprintf out "uint64_t jerboa_tls_accept(uint64_t s, int fd) { return 0; }~n")
        (fprintf out "uint64_t jerboa_tls_connect(const char *h, int p) { return 0; }~n")
        (fprintf out "uint64_t jerboa_tls_connect_pinned(const char *h, int p, const uint8_t *fp, size_t fplen) { return 0; }~n")
        (fprintf out "uint64_t jerboa_tls_connect_mtls(const char *h, int p, const char *c, const char *k, const char *ca) { return 0; }~n")
        (fprintf out "int jerboa_tls_read(uint64_t s, uint8_t *buf, uint64_t len) { return -1; }~n")
        (fprintf out "int jerboa_tls_write(uint64_t s, const uint8_t *buf, uint64_t len) { return -1; }~n")
        (fprintf out "int jerboa_tls_flush(uint64_t s) { return -1; }~n")
        (fprintf out "void jerboa_tls_close(uint64_t s) {}~n")
        (fprintf out "int jerboa_tls_set_nonblock(uint64_t s, int nb) { return -1; }~n")
        (fprintf out "int jerboa_tls_get_fd(uint64_t s) { return -1; }~n")
        (fprintf out "size_t jerboa_last_error(uint8_t *buf, size_t len) { return 0; }~n"))
      'replace)
    (let ((cmd "gcc -c -O2 -o jemacs-tls-stubs.o jemacs-tls-stubs.c -Wall 2>&1"))
      (unless (= 0 (system cmd))
        (display "Error: TLS stubs compilation failed\n")
        (exit 1)))))

;; jemacs-main.c
(let* ((static-flag (if jemacs-static? "-DJEMACS_STATIC_BUILD" ""))
       (cmd (format "gcc -c -O2 ~a -o jemacs-main.o jemacs-main.c -I~a -I. -Wall 2>&1"
                    static-flag chez-dir)))
  (unless (= 0 (system cmd))
    (display "Error: jemacs-main.c compilation failed\n")
    (exit 1)))

;; --- Step 6: Link native binary ---
(printf "[6/6] Linking native binary...~n")
(if jemacs-static?
  ;; ─── Static link (Docker musl build) ───────────────────────────────────
  (let* ((pcre2-libs  (shell-output "pkg-config --static --libs libpcre2-8" "-lpcre2-8"))
         (ncurses-libs (shell-output "pkg-config --static --libs ncurses" "-lncurses"))
         (vterm-libs   (shell-output "pkg-config --static --libs vterm" "-lvterm"))
         (sci-a   (format "~a/scintilla/bin/scintilla.a" sci-vendor-dir))
         (lex-a   (format "~a/lexilla/bin/liblexilla.a" sci-vendor-dir))
         (tbx-a   (format "~a/scintilla/termbox/termbox_next/bin/termbox.a" sci-vendor-dir))
         (jsh-coreutils-lib (or (getenv "JSH_COREUTILS_LIB") ""))
         (cmd (format "g++ -static -Wl,--export-dynamic -o jemacs \
jemacs-main.o jemacs-pcre2-shim.o jemacs-jsh-ffi.o \
jemacs-libcoreutils.o jemacs-jsh-coreutils-stubs.o \
jemacs-embed-crypto.o jemacs-ssh-agent-stub.o \
jemacs-pty-shim.o jemacs-vterm-shim.o jemacs-repl-shim.o \
jemacs-jerboa-landlock.o jemacs-sci-shim.o \
tui_static_symbols.o \
~a \
-L~a -lkernel -llz4 -lz \
-Wl,--whole-archive ~a ~a ~a -Wl,--no-whole-archive \
~a ~a ~a \
-lm -ldl -lpthread -luuid -lstdc++ 2>&1"
                      jsh-coreutils-lib
                      chez-dir
                      sci-a lex-a tbx-a
                      pcre2-libs ncurses-libs vterm-libs)))
    (printf "  ~a~n" cmd)
    (unless (= 0 (system cmd))
      (display "Error: Static link failed\n")
      (exit 1)))
  ;; ─── Dynamic link (default local build) ────────────────────────────────
  ;; -rdynamic: export all compiled-in symbols to dlsym(RTLD_DEFAULT) so
  ;; Chez's foreign-procedure finds them via dlopen(NULL)/dlopen("").
  (let* ((pcre2-libs   (shell-output "pkg-config --libs libpcre2-8" "-lpcre2-8"))
         (ncurses-libs (shell-output "pkg-config --libs ncurses" "-lncurses"))
         (cmd (format "gcc -rdynamic -o jemacs \
jemacs-main.o jemacs-pcre2-shim.o jemacs-repl-shim.o \
jemacs-jsh-ffi.o jemacs-libcoreutils.o jemacs-embed-crypto.o \
jemacs-ssh-agent-stub.o jemacs-jsh-coreutils-stubs.o \
jemacs-tls-stubs.o \
-L~a -lkernel -llz4 -lz \
~a ~a \
-lm -ldl -lpthread 2>&1"
                      chez-dir pcre2-libs ncurses-libs)))
    (printf "  ~a~n" cmd)
    (unless (= 0 (system cmd))
      (display "Error: Dynamic link failed\n")
      (exit 1))))

(printf "~nDone! Binary: ./jemacs~n")
