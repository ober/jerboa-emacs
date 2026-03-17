#!chezscheme
;;; emacsclient.ss — Open files in a running jerboa-emacs session.
;;; Analogous to Emacs's emacsclient.

(import (chezscheme)
        (std net tcp)
        (jerboa-emacs ipc))

(include "manifest.ss")

;;; ========================================================================
;;; Helpers
;;; ========================================================================

(define (string-prefix? prefix str)
  (and (>= (string-length str) (string-length prefix))
       (string=? (substring str 0 (string-length prefix)) prefix)))

(define (string-trim-right s)
  (let loop ([i (string-length s)])
    (if (and (> i 0)
             (let ([c (string-ref s (- i 1))])
               (or (char=? c #\space) (char=? c #\return) (char=? c #\tab))))
      (loop (- i 1))
      (substring s 0 i))))

(define (path-expand file)
  "Make FILE an absolute path relative to the current directory."
  (if (and (> (string-length file) 0)
           (char=? (string-ref file 0) #\/))
    file
    (string-append (current-directory) "/" file)))

;;; ========================================================================
;;; Server file reading
;;; ========================================================================

(define (read-server-file)
  "Read the server file and return (host . port) or #f."
  (if (file-exists? *ipc-server-file*)
    (guard (exn [else #f])
      (let ([content (call-with-input-file *ipc-server-file*
                       (lambda (p) (get-line p)))])
        (if (eof-object? content)
          #f
          (let loop ([i (- (string-length content) 1)])
            (if (< i 0)
              #f
              (if (char=? (string-ref content i) #\:)
                (cons (substring content 0 i)
                      (string->number
                       (substring content (+ i 1) (string-length content))))
                (loop (- i 1))))))))
    #f))

;;; ========================================================================
;;; File sending
;;; ========================================================================

(define (send-files! files)
  "Connect to the running server and send file paths."
  (let ([server-info (read-server-file)])
    (unless server-info
      (display "jerboa-client: no server running (missing ")
      (display *ipc-server-file*)
      (display ")")
      (newline)
      (exit 1))
    (let ([host (car server-info)]
          [port-num (cdr server-info)])
      (let-values ([(in-port out-port)
                    (guard (exn [else
                                 (display "jerboa-client: cannot connect to ")
                                 (display host)
                                 (display ":")
                                 (display port-num)
                                 (newline)
                                 (exit 1)])
                      (tcp-connect host port-num))])
        (dynamic-wind
          (lambda () (void))
          (lambda ()
            (for-each
              (lambda (file)
                (let ([abs-path (path-expand file)])
                  (display abs-path out-port)
                  (newline out-port)
                  (flush-output-port out-port)
                  (let ([response (get-line in-port)])
                    (when (or (eof-object? response)
                              (not (string=? (string-trim-right response) "OK")))
                      (display "jerboa-client: unexpected response for ")
                      (display abs-path)
                      (newline)))))
              files))
          (lambda ()
            (close-port in-port)
            (close-port out-port)))))))

;;; ========================================================================
;;; Entry point
;;; ========================================================================

(define (main . args)
  (cond
    [(member "--version" args)
     (display "jerboa-client ")
     (display (cdar version-manifest))
     (newline)]
    [(or (member "--help" args) (member "-h" args))
     (display "Usage: jerboa-client [OPTIONS] FILE...")
     (newline)
     (display "Open files in a running jerboa-emacs session.")
     (newline)
     (newline)
     (display "Options:")
     (newline)
     (display "  --version   Show version information")
     (newline)
     (display "  --help, -h  Show this help message")
     (newline)]
    [(null? args)
     (display "jerboa-client: no files specified")
     (newline)
     (display "Usage: jerboa-client FILE...")
     (newline)
     (exit 1)]
    [else
     (let ([files (filter (lambda (a) (not (string-prefix? "-" a))) args)])
       (when (null? files)
         (display "jerboa-client: no files specified")
         (newline)
         (exit 1))
       (send-files! files))]))

(apply main (command-line-arguments))
