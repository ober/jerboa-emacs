#!chezscheme
;;; subprocess.sls — Interruptible subprocess execution for jemacs
;;;
;;; Ported from gerbil-emacs/subprocess.ss
;;; Provides non-blocking process I/O that can be interrupted by C-g.

(library (jerboa-emacs subprocess)
  (export run-process-interruptible
          active-subprocess
          kill-active-subprocess!)
  (import (except (chezscheme)
            make-hash-table hash-table? iota 1+ 1- sort sort!)
          (jerboa core)
          (jerboa runtime)
          (std sugar)
          (std misc process)
          (only (std misc thread) thread-sleep!)
          (jerboa-emacs core))

  ;;;============================================================================
  ;;; Active subprocess tracking
  ;;;============================================================================

  (def *active-subprocess* #f)
  (def (active-subprocess) *active-subprocess*)

  (def (kill-active-subprocess!)
    (when *active-subprocess*
      (with-catch void
        (lambda ()
          (let ((pp *active-subprocess*))
            (when (process-port? pp)
              (let ((stdin (process-port-rec-stdin-port pp)))
                (when stdin (close-port stdin)))
              (let ((stdout (process-port-rec-stdout-port pp)))
                (when stdout (close-port stdout)))
              (let ((stderr (process-port-rec-stderr-port pp)))
                (when stderr (close-port stderr)))))))
      (set! *active-subprocess* #f)))

  ;;;============================================================================
  ;;; Interruptible process runner
  ;;;============================================================================

  (def (run-process-interruptible cmd peek-event event-key? event-key . rest)
    (let ((stdin-text (if (pair? rest) (car rest) #f))
          (poll-ms (if (and (pair? rest) (pair? (cdr rest))) (cadr rest) 50)))
      (let ((pp (open-process (list "/bin/sh" "-c" cmd))))
        (dynamic-wind
          (lambda () (set! *active-subprocess* pp))
          (lambda ()
            (let ((stdin-port (process-port-rec-stdin-port pp))
                  (stdout-port (process-port-rec-stdout-port pp)))
              ;; Write stdin if provided
              (when stdin-text
                (put-string stdin-port stdin-text)
                (flush-output-port stdin-port)
                (close-port stdin-port))
              ;; Poll loop: check for C-g, drain output, repeat
              (let ((out (open-output-string)))
                (let loop ()
                  ;; Check for C-g via peek-event
                  (let ((ev (peek-event poll-ms)))
                    (when (and ev (event-key? ev) (= (event-key ev) 7))
                      (kill-active-subprocess!)
                      (raise (make-keyboard-quit-exception))))
                  ;; Try to read available data
                  (let ((chunk (with-catch
                                 (lambda (e) #f)
                                 (lambda ()
                                   (if (input-port-ready? stdout-port)
                                     (let read-loop ((acc '()))
                                       (if (input-port-ready? stdout-port)
                                         (let ((ch (read-char stdout-port)))
                                           (if (eof-object? ch)
                                             (begin
                                               (for-each (lambda (c) (write-char c out))
                                                         (reverse acc))
                                               'eof)
                                             (read-loop (cons ch acc))))
                                         (begin
                                           (for-each (lambda (c) (write-char c out))
                                                     (reverse acc))
                                           'more)))
                                     'more)))))
                    (if (eq? chunk 'eof)
                      ;; Process finished
                      (begin
                        (close-port stdout-port)
                        (values (get-output-string out) #f))
                      ;; Not done yet — loop
                      (begin
                        (thread-sleep! (/ poll-ms 1000.0))
                        (loop))))))))
          (lambda () (set! *active-subprocess* #f))))))

  ) ;; end library
