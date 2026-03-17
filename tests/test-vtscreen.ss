#!chezscheme
;;; test-vtscreen.ss — Tests for vtscreen VT100 emulator and gsh-eshell ANSI stripping
;;; Ported from gerbil-emacs/vtscreen-test.ss

(import (except (chezscheme)
          make-hash-table hash-table? iota 1+ 1-)
        (jerboa core)
        (jerboa runtime)
        (jerboa-emacs vtscreen)
        (jerboa-emacs gsh-eshell)
        (std srfi srfi-13))

(define pass-count 0)
(define fail-count 0)

(define-syntax check
  (syntax-rules (=>)
    ((_ expr => expected)
     (let ((result expr) (exp expected))
       (if (equal? result exp)
         (set! pass-count (+ pass-count 1))
         (begin
           (set! fail-count (+ fail-count 1))
           (display "FAIL: ")
           (write 'expr)
           (display " => ")
           (write result)
           (display " expected ")
           (write exp)
           (newline)))))))

(define-syntax check-true
  (syntax-rules ()
    ((_ expr)
     (check (and expr #t) => #t))))

;; Helper: feed a string to a vtscreen
(define (feed-string! vt str)
  (vtscreen-feed! vt str))

;; Helper: get text of a row from vtscreen render output
(define (vt-row-text vt row)
  (let* ((rendered (vtscreen-render vt))
         (lines (let loop ([i 0] [start 0] [result '()])
                  (cond
                    [(= i (string-length rendered))
                     (reverse (if (> i start)
                                (cons (substring rendered start i) result)
                                result))]
                    [(char=? (string-ref rendered i) #\newline)
                     (loop (+ i 1) (+ i 1)
                           (cons (substring rendered start i) result))]
                    [else (loop (+ i 1) start result)]))))
    (if (< row (length lines))
      (list-ref lines row)
      "")))

;;; ========================================================================
;;; vtscreen: basic text rendering
;;; ========================================================================

(display "--- vtscreen-basic ---\n")

(let ((vt (new-vtscreen 24 80)))
  (feed-string! vt "Hello, World!")
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "Hello, World!") => 0)))

(let ((vt (new-vtscreen 24 80)))
  (feed-string! vt "Line1\r\nLine2")
  (let ((row0 (vt-row-text vt 0))
        (row1 (vt-row-text vt 1)))
    (check (string-contains row0 "Line1") => 0)
    (check (string-contains row1 "Line2") => 0)))

;;; ========================================================================
;;; vtscreen: charset designation ESC(B
;;; ========================================================================

(display "--- vtscreen-charset ---\n")

(let ((vt (new-vtscreen 24 80)))
  (feed-string! vt (string (integer->char 27) #\( #\B))
  (feed-string! vt "Hello")
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "Hello") => 0)
    (check (string-contains row0 "BHello") => #f)))

(let ((vt (new-vtscreen 24 80))
      (esc-b (string (integer->char 27) #\( #\B)))
  (feed-string! vt esc-b)
  (feed-string! vt "top")
  (feed-string! vt esc-b)
  (feed-string! vt " - ")
  (feed-string! vt esc-b)
  (feed-string! vt "12:00")
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "top - 12:00") => 0)
    (check (string-contains row0 "B") => #f)))

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt (string esc #\) #\B))
  (feed-string! vt (string esc #\* #\0))
  (feed-string! vt (string esc #\+ #\A))
  (feed-string! vt "OK")
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "OK") => 0)
    (check (string-contains row0 "BOK") => #f)
    (check (string-contains row0 "0OK") => #f)
    (check (string-contains row0 "AOK") => #f)))

;;; ========================================================================
;;; vtscreen: SGR color sequences
;;; ========================================================================

(display "--- vtscreen-sgr ---\n")

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt (string-append (string esc) "[38;5;33m"))
  (feed-string! vt "colored")
  (feed-string! vt (string-append (string esc) "[0m"))
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "colored") => 0)
    (check (string-contains row0 "[") => #f)))

;;; ========================================================================
;;; vtscreen: alt-screen detection
;;; ========================================================================

(display "--- vtscreen-alt-screen ---\n")

(let ((vt (new-vtscreen 24 80)))
  (check (vtscreen-alt-screen? vt) => #f))

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt (string-append (string esc) "[2J"))
  (check (vtscreen-alt-screen? vt) => #t))

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt (string-append (string esc) "[?1049h"))
  (check (vtscreen-alt-screen? vt) => #t))

;;; ========================================================================
;;; vtscreen: cursor movement
;;; ========================================================================

(display "--- vtscreen-cursor ---\n")

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt "XXXX")
  (feed-string! vt (string-append (string esc) "[H"))
  (feed-string! vt "YY")
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "YYXX") => 0)))

;;; ========================================================================
;;; vtscreen: LF implies CR (newline mode)
;;; ========================================================================

(display "--- vtscreen-lf-cr ---\n")

(let ((vt (new-vtscreen 24 80)))
  (feed-string! vt "AAAA\nBBBB")
  (let ((row0 (vt-row-text vt 0))
        (row1 (vt-row-text vt 1)))
    (check (string-contains row0 "AAAA") => 0)
    (check (string-contains row1 "BBBB") => 0)))

;;; ========================================================================
;;; vtscreen: VT220 features
;;; ========================================================================

(display "--- vtscreen-vt220 ---\n")

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt "X")
  (feed-string! vt (string-append (string esc) "[5b"))
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "XXXXXX") => 0)))

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt "    Hello")
  (feed-string! vt (string-append (string esc) "[1E"))
  (feed-string! vt "World")
  (let ((row1 (vt-row-text vt 1)))
    (check (string-contains row1 "World") => 0)))

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt (string-append (string esc) "P" "junk data" (string esc) "\\"))
  (feed-string! vt "OK")
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "OK") => 0)
    (check (string-contains row0 "junk") => #f)))

(let ((vt (new-vtscreen 24 80))
      (esc (integer->char 27)))
  (feed-string! vt "Hello World")
  (feed-string! vt (string-append (string esc) "c"))
  (feed-string! vt "Reset")
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "Reset") => 0)
    (check (string-contains row0 "Hello") => #f)))

(let ((vt (new-vtscreen 24 80)))
  (feed-string! vt "ABCDE")
  (feed-string! vt (string (integer->char #x9B) #\2 #\D))
  (feed-string! vt "XY")
  (let ((row0 (vt-row-text vt 0)))
    (check (string-contains row0 "ABCXY") => 0)))

;;; ========================================================================
;;; gsh-eshell-strip-ansi: ANSI escape removal
;;; ========================================================================

(display "--- strip-ansi ---\n")

(check (gsh-eshell-strip-ansi "hello world") => "hello world")

(let ((esc (integer->char 27)))
  (check (gsh-eshell-strip-ansi
           (string-append (string esc) "[38;5;33m" "user"
                          (string esc) "[0m"))
         => "user"))

(let ((esc (integer->char 27)))
  (check (gsh-eshell-strip-ansi
           (string-append (string esc) "(B" "text"))
         => "text"))

(let ((esc (integer->char 27))
      (bel (integer->char 7)))
  (check (gsh-eshell-strip-ansi
           (string-append (string esc) "]0;window title" (string bel) "visible"))
         => "visible"))

(let ((soh (integer->char 1))
      (stx (integer->char 2)))
  (check (gsh-eshell-strip-ansi
           (string-append (string soh) "hidden" (string stx) "visible"))
         => "hiddenvisible"))

(check (gsh-eshell-strip-ansi "hello\rworld") => "helloworld")

(let ((esc (integer->char 27)))
  (let ((prompt (string-append
                  (string esc) "[38;5;33m" "user"
                  (string esc) "(B" (string esc) "[m"
                  "@"
                  (string esc) "[38;5;208m" "host"
                  (string esc) "(B" (string esc) "[m")))
    (check (gsh-eshell-strip-ansi prompt) => "user@host")))

;;; ========================================================================
;;; interactive-command? detection
;;; ========================================================================

(display "--- interactive-command ---\n")

(check (not (not (interactive-command? "top"))) => #t)
(check (not (not (interactive-command? "vim file.txt"))) => #t)
(check (not (not (interactive-command? "htop"))) => #t)
(check (interactive-command? "ls -la") => #f)
(check (interactive-command? "grep pattern file") => #f)
(check (not (not (interactive-command? "  top"))) => #t)
(check (interactive-command? "") => #f)

;;; ========================================================================
;;; Summary
;;; ========================================================================

(newline)
(display "========================================\n")
(display (string-append "vtscreen Tests: "
  (number->string pass-count) " passed, "
  (number->string fail-count) " failed\n"))
(display "========================================\n")
(when (> fail-count 0) (exit 1))
