;;; -*- Gerbil -*-
;;; TCP REPL server for debugging a running jerboa-emacs instance.
;;;
;;; Supports TWO protocols:
;;;   1. Text mode (nc-compatible): connect with `nc 127.0.0.1 <port>`
;;;      Rich REPL commands: ,type, ,describe, ,apropos, ,complete, ,expand,
;;;      ,time, ,env, ,import, ,pp, ,table, ,json, ,help, etc.
;;;
;;;   2. S-expression protocol (editor integration):
;;;      Send `(id method . args)`, receive `(id :ok result)` or `(id :error msg)`.
;;;      Methods: eval, eval-region, complete, doc, apropos, expand, type,
;;;      describe, import, env, ping, memory, modules, version, shutdown.
;;;      Auto-detected when first input byte is `(`.
;;;
;;; SINGLE-THREAD DESIGN: Runs on the primordial thread via schedule-periodic!.
;;; All socket I/O is non-blocking (poll + read with EAGAIN).
;;; No background threads = no GC deadlock possibility.
;;;
;;; API:
;;;   (start-debug-repl! port)          -> actual-port
;;;   (start-debug-repl! port token)    -> actual-port  (optional auth token)
;;;   (stop-debug-repl!)                -> void
;;;   (debug-repl-port)                 -> port-number or #f

(export start-debug-repl!
        stop-debug-repl!
        debug-repl-port
        debug-repl-bind!)

(import :std/sugar
        :std/srfi/13
        (only-in :std/repl
          value->type-string describe-value
          repl-complete repl-doc repl-apropos)
        :jerboa/repl-socket
        :jerboa-emacs/async)

;;;============================================================================
;;; State
;;;============================================================================

(def *repl-listen-fd* #f)       ;; listen socket fd (non-blocking)
(def *repl-client-fd* #f)       ;; connected client fd (non-blocking), or #f
(def *repl-line-buf*  "")       ;; partial line accumulator
(def *repl-actual-port* #f)     ;; port number we're listening on
(def *repl-token* #f)           ;; auth token (or #f for no auth)
(def *repl-authed* #f)          ;; #t after successful auth (or if no token)
(def *repl-prompted* #f)        ;; #t if we've sent the prompt for current line
(def *repl-protocol* 'unknown)  ;; 'unknown, 'text, or 'sexpr
(def *repl-port-file*
  (string-append (getenv "HOME") "/.jerboa-repl-port"))
(def *repl-env* (interaction-environment))

(def (debug-repl-bind! name value)
  "Register a binding in the debug REPL environment so it's accessible via IPC.
   Uses Chez's define-top-level-value to inject the value directly."
  (define-top-level-value name value *repl-env*))

;;;============================================================================
;;; Port file
;;;============================================================================

(def ffi-chmod (foreign-procedure "chmod" (string int) int))

(def (write-repl-port-file! port-num)
  (delete-repl-port-file!)
  (call-with-output-file *repl-port-file*
    (lambda (p)
      (display "PORT=" p)
      (display port-num p)
      (newline p)))
  ;; Restrict to owner-only (mode 600) — contains REPL port info
  (ffi-chmod *repl-port-file* #o600))

(def (delete-repl-port-file!)
  (when (file-exists? *repl-port-file*)
    (with-catch (lambda _ (void))
      (lambda () (delete-file *repl-port-file*)))))

;;;============================================================================
;;; Low-level I/O helpers
;;;============================================================================

(def (repl-send! str)
  "Send a string to the connected client.  No-op if no client."
  (when *repl-client-fd*
    (unless (repl-socket-write *repl-client-fd* str)
      (repl-disconnect!))))

(def (repl-disconnect!)
  "Close the client connection and reset state for next accept."
  (when *repl-client-fd*
    (with-catch (lambda _ (void))
      (lambda () (repl-socket-close *repl-client-fd*))))
  (set! *repl-client-fd* #f)
  (set! *repl-line-buf* "")
  (set! *repl-authed* #f)
  (set! *repl-prompted* #f)
  (set! *repl-protocol* 'unknown))

;;;============================================================================
;;; Evaluation helpers (shared by both protocols)
;;;============================================================================

(def (capture-eval expr-str)
  "Evaluate expression string, capturing stdout. Returns (list status result stdout).
   Handles expressions that return multiple values by formatting all of them.
   Returns a LIST (not values) to avoid multi-value issues with with-catch's call/cc."
  (with-catch
    (lambda (e)
      (list 'error
            (with-catch (lambda _ "unknown error")
              (lambda ()
                (with-output-to-string
                  (lambda () (display-condition e (current-output-port))))))
            ""))
    (lambda ()
      (let* ((stdout-capture (open-output-string))
             (results (parameterize ((current-output-port stdout-capture))
                        (call-with-values
                          (lambda () (eval (read (open-input-string expr-str))
                                          *repl-env*))
                          list)))
             (stdout-str (get-output-string stdout-capture)))
        (list 'ok
              (if (= (length results) 1)
                (format "~s" (car results))
                (let loop ((rs results) (acc ""))
                  (if (null? rs) acc
                    (loop (cdr rs)
                          (string-append acc
                            (if (string=? acc "") "" "\n")
                            (format "~s" (car rs)))))))
              stdout-str)))))

(def (capture-eval-region str)
  "Evaluate multiple forms, return last result.
   Returns a LIST (not values) to avoid multi-value issues with with-catch's call/cc."
  (with-catch
    (lambda (e)
      (list 'error
            (with-catch (lambda _ "unknown error")
              (lambda ()
                (with-output-to-string
                  (lambda () (display-condition e (current-output-port))))))
            ""))
    (lambda ()
      (let* ((stdout-capture (open-output-string))
             (p (open-input-string str))
             (results
              (parameterize ((current-output-port stdout-capture))
                (let loop ((last (list (void))))
                  (let ((form (read p)))
                    (if (eof-object? form)
                      last
                      (loop (call-with-values
                              (lambda () (eval form *repl-env*))
                              list)))))))
             (stdout-str (get-output-string stdout-capture)))
        (list 'ok
              (if (= (length results) 1)
                (format "~s" (car results))
                (let loop ((rs results) (acc ""))
                  (if (null? rs) acc
                    (loop (cdr rs)
                          (string-append acc
                            (if (string=? acc "") "" "\n")
                            (format "~s" (car rs)))))))
              stdout-str)))))

(def (safe-format-value val)
  "Format a value to string, safely handling errors."
  (with-catch
    (lambda _ "#<unprintable>")
    (lambda ()
      (let ((out (open-output-string)))
        (write val out)
        (get-output-string out)))))

(def (safe-pp-value val)
  "Pretty-print a value to string."
  (with-catch
    (lambda _ (safe-format-value val))
    (lambda ()
      (with-output-to-string
        (lambda () (pretty-print val))))))

;;;============================================================================
;;; S-expression protocol handler
;;;============================================================================

(def (handle-sexpr-request req)
  "Handle an s-expression protocol request.
   req: (id method . args)
   Returns: (id :ok result) or (id :error message)"
  (with-catch
    (lambda (e)
      (let ((id (if (pair? req) (car req) 0)))
        (list id ':error
              (with-catch (lambda _ "unknown error")
                (lambda ()
                  (with-output-to-string
                    (lambda () (display-condition e (current-output-port)))))))))
    (lambda ()
      (let ((id (car req))
            (method (cadr req))
            (args (cddr req)))
        (case method
          ((ping)
           (list id ':ok "pong"))

          ((eval)
           (let* ((res (capture-eval (car args)))
                  (status (car res)) (result (cadr res)) (stdout (caddr res)))
             (if (eq? status 'ok)
               (list id ':ok (list ':value result ':stdout stdout))
               (list id ':error result))))

          ((eval-region)
           (let* ((res (capture-eval-region (car args)))
                  (status (car res)) (result (cadr res)) (stdout (caddr res)))
             (if (eq? status 'ok)
               (list id ':ok (list ':value result ':stdout stdout))
               (list id ':error result))))

          ((complete)
           (let* ((prefix (car args))
                  (completions (repl-complete prefix *repl-env*))
                  (strs (map symbol->string completions)))
             (list id ':ok strs)))

          ((doc)
           (let ((sym (if (symbol? (car args)) (car args)
                         (string->symbol (car args)))))
             (list id ':ok (repl-doc sym))))

          ((apropos)
           (let* ((query (car args))
                  (results (repl-apropos query *repl-env*))
                  (limited (take-up-to results 50))
                  (strs (map (lambda (s)
                               (list (symbol->string s)
                                     (with-catch (lambda _ "?")
                                       (lambda ()
                                         (value->type-string
                                           (eval s *repl-env*))))))
                             limited)))
             (list id ':ok strs)))

          ((expand)
           (let* ((expr (read (open-input-string (car args))))
                  (expanded (expand expr *repl-env*))
                  (result (with-output-to-string
                            (lambda () (pretty-print expanded)))))
             (list id ':ok result)))

          ((expand1)
           (let* ((expr (read (open-input-string (car args))))
                  (expanded (sc-expand expr))
                  (result (with-output-to-string
                            (lambda () (pretty-print expanded)))))
             (list id ':ok result)))

          ((type)
           (let* ((expr (read (open-input-string (car args))))
                  (val (eval expr *repl-env*)))
             (list id ':ok (value->type-string val))))

          ((describe)
           (let* ((expr (read (open-input-string (car args))))
                  (val (eval expr *repl-env*))
                  (desc (with-output-to-string
                          (lambda () (describe-value val)))))
             (list id ':ok desc)))

          ((import)
           (let ((mod-expr (if (string? (car args))
                             (read (open-input-string (car args)))
                             (car args))))
             (eval (list 'import mod-expr) *repl-env*)
             (list id ':ok "imported")))

          ((load)
           (load (car args) (lambda (x) (eval x *repl-env*)))
           (list id ':ok (string-append "loaded " (car args))))

          ((env)
           (let* ((pattern (if (null? args) "" (car args)))
                  (syms (environment-symbols *repl-env*))
                  (filtered (if (string=? pattern "")
                              syms
                              (filter (lambda (s)
                                        (string-contains-ci
                                          (symbol->string s) pattern))
                                      syms)))
                  (sorted (sort (lambda (a b)
                                  (string<? (symbol->string a) (symbol->string b)))
                                filtered))
                  (result (map symbol->string (take-up-to sorted 200))))
             (list id ':ok result)))

          ((pwd)
           (list id ':ok (current-directory)))

          ((cd)
           (current-directory (car args))
           (list id ':ok (current-directory)))

          ((memory)
           (let* ((before (bytes-allocated))
                  (_ (collect (collect-maximum-generation)))
                  (after (bytes-allocated)))
             (list id ':ok
                   (list ':bytes-before before
                         ':bytes-after after
                         ':freed (- before after)
                         ':max-generation (collect-maximum-generation)))))

          ((modules)
           (let ((libs (map (lambda (l) (format "~s" l))
                           (library-list))))
             (list id ':ok libs)))

          ((find-source)
           (let* ((sym (if (symbol? (car args)) (car args)
                          (string->symbol (car args))))
                  (val (with-catch (lambda _ #f) (lambda () (eval sym *repl-env*)))))
             (if (and val (procedure? val))
               (let ((name (with-catch (lambda _ #f)
                             (lambda () (#%$code-name (#%$closure-code val))))))
                 (list id ':ok (list ':name (if name (format "~a" name) (format "~a" sym))
                                     ':type "Procedure")))
               (list id ':ok (list ':name (format "~a" sym)
                                   ':type (if val (value->type-string val) "unbound"))))))

          ((version)
           (list id ':ok (list ':scheme (scheme-version)
                               ':jerboa "1.0"
                               ':protocol "1.0")))

          ((shutdown)
           (list id ':ok "shutting down"))

          ((threads)
           (list id ':ok (list ':note "thread listing not available in stock Chez")))

          ((list-directory)
           (let* ((path (if (null? args) (current-directory) (car args)))
                  (entries (sort string<? (directory-list path)))
                  (result (map (lambda (e)
                                (let ((full (string-append path "/" e)))
                                  (list e (if (file-directory? full) "dir" "file"))))
                              entries)))
             (list id ':ok result)))

          (else
           (list id ':error (string-append "unknown method: " (symbol->string method)))))))))

;;;============================================================================
;;; Text mode — rich command processing
;;;============================================================================

(def help-text
  "  Inspection & Exploration:
  ,type <expr>      Show type of expression result
  ,describe <expr>  Deep inspection of value
  ,apropos <str>    Search for symbols matching string
  ,doc <sym>        Show documentation
  ,complete <pfx>   Show completions for a symbol prefix
  ,who <sym>        Show binding info for a symbol

  Evaluation & Debugging:
  ,expand <expr>    Show macro expansion
  ,expand1 <expr>   One-step macro expansion
  ,pp <expr>        Pretty-print value

  Performance:
  ,time <expr>      Measure evaluation time
  ,alloc <expr>     Show memory allocation

  Module System:
  ,import (mod ...) Import a module
  ,load <path>      Load a file
  ,cd [path]        Change/show current directory
  ,pwd              Show current directory
  ,ls [path]        List directory contents

  Data Inspection:
  ,json <expr>      Display value as JSON
  ,count <expr>     Count items in collection
  ,env [pattern]    List environment symbols

  Session:
  ,state            Show state summary
  ,gc               Force GC and show stats
  ,modules          List loaded libraries
  ,memory           Show memory stats
  ,help             This help message
  ,quit             Close this REPL connection
  <expr>            Evaluate arbitrary Chez Scheme expression
")

(def (text-split-first-word str)
  "Split string into (first-word . rest)."
  (let* ((n (string-length str))
         (sp (let loop ((i 0))
               (if (or (= i n) (char-whitespace? (string-ref str i)))
                 i
                 (loop (+ i 1))))))
    (cons (substring str 0 sp)
          (if (= sp n)
            ""
            (string-trim-both (substring str sp n))))))

(def (process-repl-line! line)
  "Process one REPL command line.  Returns #t to continue, #f to disconnect."
  (let ((cmd (string-trim-both line)))
    (cond
      ((string=? cmd "")
       #t)
      ((string=? cmd ",quit")
       (repl-send! "Connection closed.\n")
       #f)
      ((string=? cmd ",help")
       (repl-send! help-text)
       #t)

      ;; ---- Inspection ----
      ((string-prefix? ",type " cmd)
       (let ((rest (string-trim-both (substring cmd 6 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let* ((expr (read (open-input-string rest)))
                    (val (eval expr *repl-env*)))
               (repl-send! (string-append (value->type-string val) "\n"))))))
       #t)

      ((string-prefix? ",describe " cmd)
       (let ((rest (string-trim-both (substring cmd 10 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let* ((expr (read (open-input-string rest)))
                    (val (eval expr *repl-env*))
                    (desc (with-output-to-string
                            (lambda () (describe-value val)))))
               (repl-send! desc)))))
       #t)

      ((string-prefix? ",apropos " cmd)
       (let ((query (string-trim-both (substring cmd 9 (string-length cmd)))))
         (let* ((results (repl-apropos query *repl-env*))
                (sorted (sort (lambda (a b)
                                (string<? (symbol->string a) (symbol->string b)))
                              results))
                (limited (take-up-to sorted 30)))
           (if (null? limited)
             (repl-send! "  (no matches)\n")
             (begin
               (repl-send! (string-append "  " (number->string (length sorted)) " matches:\n"))
               (for-each
                 (lambda (s)
                   (let ((type-str (with-catch (lambda _ "?")
                                     (lambda () (value->type-string (eval s *repl-env*))))))
                     (repl-send! (string-append "  " (symbol->string s)
                                                " : " type-str "\n"))))
                 limited)
               (when (> (length sorted) 30)
                 (repl-send! (string-append "  ... and "
                                            (number->string (- (length sorted) 30))
                                            " more\n")))))))
       #t)

      ((string-prefix? ",doc " cmd)
       (let* ((sym-str (string-trim-both (substring cmd 5 (string-length cmd))))
              (sym (string->symbol sym-str)))
         (repl-send! (string-append (repl-doc sym) "\n")))
       #t)

      ((string-prefix? ",complete " cmd)
       (let* ((prefix (string-trim-both (substring cmd 10 (string-length cmd))))
              (completions (repl-complete prefix *repl-env*))
              (limited (take-up-to completions 40)))
         (if (null? limited)
           (repl-send! "  (no completions)\n")
           (begin
             (for-each
               (lambda (s)
                 (repl-send! (string-append "  " (symbol->string s) "\n")))
               limited)
             (when (> (length completions) 40)
               (repl-send! (string-append "  ... " (number->string (- (length completions) 40))
                                          " more\n"))))))
       #t)

      ((string-prefix? ",who " cmd)
       (let* ((sym-str (string-trim-both (substring cmd 5 (string-length cmd))))
              (sym (string->symbol sym-str)))
         (with-catch
           (lambda _ (repl-send! (string-append "  " sym-str " is not bound\n")))
           (lambda ()
             (let* ((val (eval sym *repl-env*))
                    (type (value->type-string val)))
               (repl-send! (string-append "  " sym-str " : " type "\n"))
               (when (procedure? val)
                 (let ((name (with-catch (lambda _ #f)
                               (lambda () (#%$code-name (#%$closure-code val))))))
                   (when name
                     (repl-send! (string-append "  procedure-name: "
                                                (format "~a" name) "\n")))))))))
       #t)

      ;; ---- Evaluation & Debugging ----
      ((string-prefix? ",expand " cmd)
       (let ((rest (string-trim-both (substring cmd 8 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let* ((expr (read (open-input-string rest)))
                    (expanded (expand expr *repl-env*))
                    (result (with-output-to-string
                              (lambda () (pretty-print expanded)))))
               (repl-send! result)))))
       #t)

      ((string-prefix? ",expand1 " cmd)
       (let ((rest (string-trim-both (substring cmd 9 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let* ((expr (read (open-input-string rest)))
                    (expanded (sc-expand expr))
                    (result (with-output-to-string
                              (lambda () (pretty-print expanded)))))
               (repl-send! result)))))
       #t)

      ((string-prefix? ",pp " cmd)
       (let ((rest (string-trim-both (substring cmd 4 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let* ((expr (read (open-input-string rest)))
                    (val (eval expr *repl-env*)))
               (repl-send! (safe-pp-value val))))))
       #t)

      ;; ---- Performance ----
      ((string-prefix? ",time " cmd)
       (let ((rest (string-trim-both (substring cmd 6 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let* ((expr (read (open-input-string rest)))
                    (t0 (current-time-ms))
                    (result (eval expr *repl-env*))
                    (t1 (current-time-ms))
                    (ms (- t1 t0)))
               (repl-send! (string-append (safe-format-value result) "\n"
                                          ";; " (number->string ms) "ms\n"))))))
       #t)

      ((string-prefix? ",alloc " cmd)
       (let ((rest (string-trim-both (substring cmd 7 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (collect (collect-maximum-generation))
             (let* ((expr (read (open-input-string rest)))
                    (before (bytes-allocated))
                    (result (eval expr *repl-env*))
                    (after (bytes-allocated))
                    (delta (- after before)))
               (repl-send! (string-append (safe-format-value result) "\n"
                                          ";; allocated: " (number->string delta) " bytes\n"))))))
       #t)

      ;; ---- Module System ----
      ((string-prefix? ",import " cmd)
       (let ((rest (string-trim-both (substring cmd 8 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let ((mod-expr (read (open-input-string rest))))
               (eval (list 'import mod-expr) *repl-env*)
               (repl-send! (string-append ";; imported " (format "~s" mod-expr) "\n"))))))
       #t)

      ((string-prefix? ",load " cmd)
       (let ((path (string-trim-both (substring cmd 6 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (load path (lambda (x) (eval x *repl-env*)))
             (repl-send! (string-append ";; loaded " path "\n")))))
       #t)

      ((or (string=? cmd ",cd") (string-prefix? ",cd " cmd))
       (let ((path (if (> (string-length cmd) 3)
                     (string-trim-both (substring cmd 4 (string-length cmd)))
                     "")))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (if (string=? path "")
               (current-directory (or (getenv "HOME") "/"))
               (current-directory path))
             (repl-send! (string-append (current-directory) "\n")))))
       #t)

      ((string=? cmd ",pwd")
       (repl-send! (string-append (current-directory) "\n"))
       #t)

      ((or (string=? cmd ",ls") (string-prefix? ",ls " cmd))
       (let ((path (if (> (string-length cmd) 3)
                     (string-trim-both (substring cmd 4 (string-length cmd)))
                     (current-directory))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let ((entries (sort string<? (directory-list path))))
               (for-each
                 (lambda (e)
                   (let ((full (string-append path "/" e)))
                     (repl-send! (string-append
                                   (if (file-directory? full)
                                     (string-append e "/")
                                     e)
                                   "  "))))
                 entries)
               (repl-send! "\n")))))
       #t)

      ;; ---- Data Inspection ----
      ((string-prefix? ",json " cmd)
       (let ((rest (string-trim-both (substring cmd 6 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let* ((expr (read (open-input-string rest)))
                    (val (eval expr *repl-env*)))
               (repl-send! (string-append (value->json val) "\n"))))))
       #t)

      ((string-prefix? ",count " cmd)
       (let ((rest (string-trim-both (substring cmd 7 (string-length cmd)))))
         (with-catch
           (lambda (e) (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
           (lambda ()
             (let* ((expr (read (open-input-string rest)))
                    (val (eval expr *repl-env*)))
               (repl-send!
                 (cond
                   ((list? val) (string-append (number->string (length val)) " items\n"))
                   ((vector? val) (string-append (number->string (vector-length val)) " elements\n"))
                   ((string? val) (string-append (number->string (string-length val)) " characters\n"))
                   ((bytevector? val) (string-append (number->string (bytevector-length val)) " bytes\n"))
                   ((hashtable? val) (string-append (number->string (hashtable-size val)) " entries\n"))
                   (else "  not a collection\n")))))))
       #t)

      ((or (string=? cmd ",env") (string-prefix? ",env " cmd))
       (let ((pattern (if (> (string-length cmd) 4)
                        (string-trim-both (substring cmd 5 (string-length cmd)))
                        "")))
         (let* ((syms (environment-symbols *repl-env*))
                (filtered (if (string=? pattern "")
                            syms
                            (filter (lambda (s)
                                      (string-contains-ci (symbol->string s) pattern))
                                    syms)))
                (sorted (sort (lambda (a b)
                                (string<? (symbol->string a) (symbol->string b)))
                              filtered))
                (limited (take-up-to sorted 60)))
           (for-each
             (lambda (s)
               (let ((type-str (with-catch (lambda _ "?")
                                 (lambda () (value->type-string (eval s *repl-env*))))))
                 (repl-send! (string-append "  " (symbol->string s)
                                            " : " type-str "\n"))))
             limited)
           (when (> (length sorted) 60)
             (repl-send! (string-append "  ... " (number->string (- (length sorted) 60))
                                        " more\n")))))
       #t)

      ;; ---- Session ----
      ((string=? cmd ",state")
       (repl-send!
         (string-append
           "  listen-fd: " (number->string (or *repl-listen-fd* -1))
           "\n  client-fd: " (number->string (or *repl-client-fd* -1))
           "\n  protocol: " (symbol->string *repl-protocol*)
           "\n  bytes-allocated: " (number->string (bytes-allocated))
           "\n"))
       #t)

      ((string=? cmd ",gc")
       (with-catch
         (lambda (e) (repl-send! "  (error reading GC stats)\n"))
         (lambda ()
           (let ((before (bytes-allocated)))
             (collect (collect-maximum-generation))
             (let ((after (bytes-allocated)))
               (repl-send!
                 (string-append
                   "  bytes-before: " (number->string before)
                   "\n  bytes-after: " (number->string after)
                   "\n  freed: " (number->string (- before after))
                   "\n  collections: " (number->string (collections))
                   "\n  max-generation: " (number->string (collect-maximum-generation))
                   "\n"))))))
       #t)

      ((string=? cmd ",modules")
       (let ((libs (library-list)))
         (for-each
           (lambda (l)
             (repl-send! (string-append "  " (format "~s" l) "\n")))
           libs))
       #t)

      ((string=? cmd ",memory")
       (let ((before (bytes-allocated)))
         (collect (collect-maximum-generation))
         (let ((after (bytes-allocated)))
           (repl-send!
             (string-append
               "  bytes-allocated: " (number->string after)
               "\n  freed-by-gc: " (number->string (- before after))
               "\n  max-gen: " (number->string (collect-maximum-generation))
               "\n"))))
       #t)

      ;; ---- Fallthrough: evaluate expression ----
      (else
       (if (and (> (string-length cmd) 0)
                (char=? #\, (string-ref cmd 0)))
         ;; Unknown comma command
         (begin
           (repl-send! (string-append "  unknown command: " cmd " (try ,help)\n"))
           #t)
         ;; Evaluate as Chez Scheme expression
         (begin
           (with-catch
             (lambda (e)
               (repl-send! (string-append "ERROR: " (fmt-error e) "\n")))
             (lambda ()
               (let* ((res (capture-eval cmd))
                      (status (car res)) (result (cadr res)) (stdout (caddr res)))
                 (when (and (string? stdout) (> (string-length stdout) 0))
                   (repl-send! stdout))
                 (if (eq? status 'ok)
                   (repl-send! (string-append result "\n"))
                   (repl-send! (string-append "ERROR: " result "\n"))))))
           #t))))))

;;;============================================================================
;;; Utility helpers
;;;============================================================================

(def (fmt-error e)
  "Format an error/condition to string."
  (with-catch (lambda _ "unknown error")
    (lambda ()
      (with-output-to-string
        (lambda () (display-condition e (current-output-port)))))))

(def (take-up-to lst n)
  "Take up to n elements from lst."
  (if (or (<= n 0) (null? lst)) '()
    (cons (car lst) (take-up-to (cdr lst) (- n 1)))))

;; string-contains-ci is provided by :std/srfi/13

(def (value->json val)
  "Simple JSON serialization."
  (cond
    ((eq? val #t) "true")
    ((eq? val #f) "false")
    ((null? val) "[]")
    ((eq? val (void)) "null")
    ((number? val) (number->string (inexact val)))
    ((string? val)
     (string-append "\"" (json-escape val) "\""))
    ((symbol? val)
     (string-append "\"" (json-escape (symbol->string val)) "\""))
    ((and (list? val) (pair? val) (pair? (car val))
          (not (list? (car val))))
     ;; Alist -> object
     (string-append "{"
       (string-join
         (map (lambda (p)
                (string-append "\"" (json-escape (format "~a" (car p))) "\": "
                               (value->json (cdr p))))
              val)
         ", ")
       "}"))
    ((list? val)
     (string-append "["
       (string-join (map value->json val) ", ")
       "]"))
    ((vector? val)
     (value->json (vector->list val)))
    ((hashtable? val)
     (let-values (((keys vals) (hashtable-entries val)))
       (string-append "{"
         (string-join
           (let loop ((i 0) (acc '()))
             (if (= i (vector-length keys))
               (reverse acc)
               (loop (+ i 1)
                     (cons (string-append
                             "\"" (json-escape (format "~a" (vector-ref keys i)))
                             "\": " (value->json (vector-ref vals i)))
                           acc))))
           ", ")
         "}")))
    (else (format "~s" val))))

(def (json-escape s)
  "Escape a string for JSON."
  (let ((out (open-output-string)))
    (string-for-each
      (lambda (c)
        (cond
          ((char=? c #\") (display "\\\"" out))
          ((char=? c #\\) (display "\\\\" out))
          ((char=? c #\newline) (display "\\n" out))
          ((char=? c #\tab) (display "\\t" out))
          ((char=? c #\return) (display "\\r" out))
          (else (display c out))))
      s)
    (get-output-string out)))

;; string-join is provided by :std/srfi/13

;;;============================================================================
;;; S-expression protocol: balanced paren detection
;;;============================================================================

(def (sexpr-balanced? str)
  "Check if a string contains a complete s-expression (balanced parens)."
  (let ((len (string-length str)))
    (let loop ((i 0) (depth 0) (in-string #f) (escape #f))
      (cond
        ((>= i len) (and (= depth 0) (not in-string) (> len 0)))
        (else
         (let ((c (string-ref str i)))
           (cond
             (escape
              (loop (+ i 1) depth in-string #f))
             ((char=? c #\\)
              (loop (+ i 1) depth in-string #t))
             (in-string
              (if (char=? c #\")
                (loop (+ i 1) depth #f #f)
                (loop (+ i 1) depth #t #f)))
             ((char=? c #\")
              (loop (+ i 1) depth #t #f))
             ((char=? c #\;)
              ;; Skip to end of line
              (let skip ((j (+ i 1)))
                (cond
                  ((>= j len) (and (= depth 0)))
                  ((char=? (string-ref str j) #\newline)
                   (loop (+ j 1) depth #f #f))
                  (else (skip (+ j 1))))))
             ((or (char=? c #\() (char=? c #\[))
              (loop (+ i 1) (+ depth 1) #f #f))
             ((or (char=? c #\)) (char=? c #\]))
              (if (= depth 1)
                #t  ;; Complete!
                (loop (+ i 1) (- depth 1) #f #f)))
             (else
              (loop (+ i 1) depth #f #f)))))))))

;;;============================================================================
;;; Tick — called from master timer every 50ms
;;;============================================================================

(def (debug-repl-tick!)
  "Non-blocking REPL poll.  Called from the master timer on the primordial thread."
  (when *repl-listen-fd*
    (with-catch
      (lambda (e) (void))
      (lambda ()
        (cond
          ;; No client — try to accept one
          ((not *repl-client-fd*)
           (let ((cfd (repl-socket-accept *repl-listen-fd*)))
             (when cfd
               (set! *repl-client-fd* cfd)
               (set! *repl-line-buf* "")
               (set! *repl-prompted* #f)
               (set! *repl-protocol* 'unknown)
               (if *repl-token*
                 (begin
                   (set! *repl-authed* #f)
                   (repl-send! "token: "))
                 (begin
                   (set! *repl-authed* #t)
                   ;; Don't send banner yet — wait to detect protocol
                   )))))

          ;; Client connected — try to read data
          (*repl-client-fd*
           ;; Detect protocol from first data
           (when (and *repl-authed* (eq? *repl-protocol* 'unknown)
                      (string=? *repl-line-buf* ""))
             ;; No data yet and protocol unknown — peek at first byte
             ;; For now, send text banner; if first input is `(`, switch to sexpr
             (repl-send! "jerboa REPL v2 — ,help for commands  |  s-expr protocol: (id method args...)\n")
             (set! *repl-protocol* 'text))

           ;; Send prompt if needed (text mode only)
           (when (and *repl-authed* (not *repl-prompted*)
                      (eq? *repl-protocol* 'text))
             (repl-send! "jerboa> ")
             (set! *repl-prompted* #t))

           ;; Non-blocking read
           (let ((data (repl-socket-read *repl-client-fd*)))
             (cond
               ((string? data)
                (set! *repl-line-buf* (string-append *repl-line-buf* data))
                ;; Auto-detect protocol on first data
                (when (eq? *repl-protocol* 'text)
                  (let ((trimmed (string-trim-both *repl-line-buf*)))
                    (when (and (> (string-length trimmed) 0)
                               (char=? (string-ref trimmed 0) #\())
                      ;; Check if this looks like (id method ...) — an s-expr request
                      ;; Heuristic: starts with ( and first element is a number
                      (with-catch (lambda _ #f)
                        (lambda ()
                          (let* ((p (open-input-string trimmed))
                                 (expr (read p)))
                            (when (and (pair? expr) (number? (car expr))
                                       (>= (length expr) 2) (symbol? (cadr expr)))
                              (set! *repl-protocol* 'sexpr))))))))
                (if (eq? *repl-protocol* 'sexpr)
                  (repl-process-sexprs!)
                  (repl-process-lines!)))
               ((eq? data 'eof)
                (repl-disconnect!))))))))))

;;;============================================================================
;;; S-expression protocol: process complete requests
;;;============================================================================

(def (repl-process-sexprs!)
  "Extract and process complete s-expressions from *repl-line-buf*."
  (let loop ()
    (let ((trimmed (string-trim-both *repl-line-buf*)))
      (when (and (> (string-length trimmed) 0)
                 (sexpr-balanced? trimmed))
        ;; Try to read one s-expr
        (with-catch
          (lambda (e)
            ;; Parse error — send error response and clear buffer
            (repl-send! (string-append
                          "(:push :error \"parse error: "
                          (json-escape (fmt-error e))
                          "\")\n"))
            (set! *repl-line-buf* ""))
          (lambda ()
            (let* ((p (open-input-string trimmed))
                   (req (read p))
                   ;; Remaining text after the first s-expr
                   (pos (let ((remaining (get-string-all p)))
                          (if (eof-object? remaining) "" remaining))))
              (set! *repl-line-buf* pos)
              ;; Handle the request
              (if (and (pair? req) (>= (length req) 2))
                (let ((response (handle-sexpr-request req)))
                  (repl-send! (string-append (format "~s" response) "\n"))
                  ;; Check for shutdown
                  (when (eq? (cadr req) 'shutdown)
                    (repl-disconnect!)))
                (repl-send! (string-append "(:push :error \"malformed request\")\n")))
              (loop))))))))

;; get-string-all is provided by Chez Scheme (rnrs io ports)

;;;============================================================================
;;; Text mode: process complete lines
;;;============================================================================

(def (repl-process-lines!)
  "Extract and process complete lines from *repl-line-buf*."
  (let loop ()
    (let ((nl (repl-string-index *repl-line-buf* #\newline)))
      (when nl
        (let ((line (substring *repl-line-buf* 0 nl))
              (rest (substring *repl-line-buf* (+ nl 1)
                               (string-length *repl-line-buf*))))
          (set! *repl-line-buf* rest)
          (let ((line (if (and (> (string-length line) 0)
                               (char=? (string-ref line (- (string-length line) 1)) #\return))
                       (substring line 0 (- (string-length line) 1))
                       line)))
            (if *repl-authed*
              (let ((continue? (process-repl-line! line)))
                (if continue?
                  (begin
                    (set! *repl-prompted* #f)
                    (loop))
                  (repl-disconnect!)))
              (let ((tok (string-trim-both line)))
                (if (string=? tok *repl-token*)
                  (begin
                    (set! *repl-authed* #t)
                    (set! *repl-protocol* 'unknown)
                    (set! *repl-prompted* #f)
                    (loop))
                  (begin
                    (repl-send! "Access denied.\n")
                    (repl-disconnect!)))))))))))

(def (repl-string-index str ch)
  "Return the index of the first occurrence of ch in str, or #f."
  (let ((len (string-length str)))
    (let loop ((i 0))
      (cond
        ((>= i len) #f)
        ((char=? (string-ref str i) ch) i)
        (else (loop (+ i 1)))))))

;;;============================================================================
;;; Public API
;;;============================================================================

(def (start-debug-repl! port-num . args)
  "Start the TCP debug REPL on 127.0.0.1:port-num.
   Optional second argument: token string for authentication.
   Runs on primordial thread via schedule-periodic! — no GC deadlock.

   Supports two protocols:
     1. Text mode (nc): rich REPL with ,type, ,describe, ,apropos, etc.
     2. S-expression protocol: send (id method . args), get (id :ok result).
   Protocol is auto-detected from the first input."
  (stop-debug-repl!)
  (let ((token (if (null? args) #f (car args))))
    (let-values (((fd actual-port) (repl-socket-listen "127.0.0.1" port-num)))
      (set! *repl-listen-fd* fd)
      (set! *repl-actual-port* actual-port)
      (set! *repl-token* token)
      (set! *repl-authed* (not token))
      (set! *repl-client-fd* #f)
      (set! *repl-line-buf* "")
      (set! *repl-prompted* #f)
      (set! *repl-protocol* 'unknown)
      (write-repl-port-file! actual-port)
      (schedule-periodic! 'debug-repl 50 debug-repl-tick!)
      actual-port)))

(def (stop-debug-repl!)
  "Stop the debug REPL server and clean up."
  (repl-disconnect!)
  (when *repl-listen-fd*
    (with-catch (lambda _ (void))
      (lambda () (repl-socket-close *repl-listen-fd*)))
    (set! *repl-listen-fd* #f)
    (set! *repl-actual-port* #f))
  (delete-repl-port-file!))

(def (debug-repl-port)
  "Return the actual port number the debug REPL is listening on, or #f if stopped."
  *repl-actual-port*)
