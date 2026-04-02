;;; -*- Gerbil -*-
;;; commands-aws.ss — AWS EC2 SSH mode for jemacs
;;;
;;; Emacs-like tabulated-list mode: browse EC2 instances across regions,
;;; filter/sort, and SSH into them via a terminal buffer.
;;;
;;; Uses the native jerboa-aws library for HTTPS API calls — no aws CLI needed.
;;;
;;; M-x aws-ec2-ssh     — Open the instance list
;;;
;;; Key bindings (in *AWS EC2 SSH* buffer):
;;;   n/p     — Next/previous line
;;;   RET     — SSH to instance (opens terminal)
;;;   g       — Refresh (uses cache)
;;;   G       — Force refresh (bypass cache)
;;;   /       — Filter by string
;;;   C       — Clear filter
;;;   s       — Sort by name
;;;   S       — Sort by region
;;;   q       — Quit

(export
  cmd-aws-ec2-ssh
  cmd-aws-ec2-ssh-connect
  cmd-aws-ec2-ssh-refresh
  cmd-aws-ec2-ssh-force-refresh
  cmd-aws-ec2-ssh-filter
  cmd-aws-ec2-ssh-clear-filter
  cmd-aws-ec2-ssh-sort-name
  cmd-aws-ec2-ssh-sort-region
  aws-ec2-ssh-setup-mode!)

(import
  :std/sugar
  :std/sort
  :std/srfi/13
  (only-in :std/misc/string string-empty?)
  (only-in :std/misc/ports read-file-lines)
  :chez-scintilla/constants
  :jerboa-emacs/core
  :jerboa-emacs/buffer
  :jerboa-emacs/tabulated-list
  :jerboa-emacs/terminal
  :jerboa-emacs/async
  :jerboa-emacs/echo
  :jerboa-emacs/qt/buffer
  :jerboa-emacs/qt/window
  :jerboa-emacs/qt/sci-shim
  :jerboa-emacs/qt/echo
  :jerboa-emacs/qt/commands-core
  (jerboa-aws ec2 api)
  (jerboa-aws ec2 instances))

;;; ============================================================================
;;; Configuration
;;; ============================================================================

(def *aws-ec2-ssh-config-file* "~/.aws-custom-ssh.yaml")
(def *aws-ec2-ssh-cache-ttl* 300)   ;; seconds
(def *aws-ec2-ssh-user* #f)         ;; SSH user, or #f for default

(def *aws-ec2-ssh-common-regions*
  '("us-east-1" "us-east-2" "us-west-1" "us-west-2"
    "eu-west-1" "eu-west-2" "eu-west-3" "eu-central-1" "eu-north-1"
    "ap-northeast-1" "ap-northeast-2" "ap-southeast-1" "ap-southeast-2"
    "ap-south-1" "sa-east-1" "ca-central-1"))

;;; ============================================================================
;;; Internal state
;;; ============================================================================

(def *aws-region-domain-map* '())  ;; alist: region -> domain
(def *aws-cache* #f)               ;; cached instance list (list of (region . native-hash))
(def *aws-cache-expiry* 0)         ;; epoch seconds

;; Columns for the tabulated list
(def *aws-columns*
  (list (make-tl-column "Name" 25)
        (make-tl-column "State" 10)
        (make-tl-column "Type" 14)
        (make-tl-column "Private IP" 16)
        (make-tl-column "Region" 14)
        (make-tl-column "SSH Target" 40)))

;;; ============================================================================
;;; Config file parsing (simple YAML: "key: value" per line)
;;; ============================================================================

(def (aws-load-config!)
  "Load region->domain mappings from config file."
  (let ((path (path-expand *aws-ec2-ssh-config-file*)))
    (if (file-exists? path)
      (begin
        (set! *aws-region-domain-map*
          (with-catch
            (lambda (e) '())
            (lambda ()
              (let ((lines (read-file-lines path)))
                (filter-map
                  (lambda (line)
                    (let ((trimmed (string-trim line)))
                      (and (> (string-length trimmed) 0)
                           (not (string-prefix? "#" trimmed))
                           (string-contains trimmed ":")
                           (let* ((idx (string-contains trimmed ":"))
                                  (key (string-trim (substring trimmed 0 idx)))
                                  (val (string-trim (substring trimmed (+ idx 1)
                                                               (string-length trimmed)))))
                             (and (> (string-length key) 0)
                                  (> (string-length val) 0)
                                  (cons key val))))))
                  lines)))))
        (length *aws-region-domain-map*))
      (begin
        (set! *aws-region-domain-map* '())
        0))))

(def (aws-get-domain region)
  "Get domain suffix for REGION from config, or #f."
  (let ((pair (assoc region *aws-region-domain-map*)))
    (and pair (cdr pair))))

;;; ============================================================================
;;; Cache
;;; ============================================================================

(def (aws-cache-valid?)
  (and *aws-cache*
       (> *aws-cache-expiry* (time-second (current-time)))))

(def (aws-cache-put! instances)
  (set! *aws-cache* instances)
  (set! *aws-cache-expiry* (+ (time-second (current-time)) *aws-ec2-ssh-cache-ttl*)))

(def (aws-cache-clear!)
  (set! *aws-cache* #f)
  (set! *aws-cache-expiry* 0))

;;; ============================================================================
;;; Native EC2 response parsing
;;; Instance data: (cons region native-chez-hashtable)
;;; Keys in native hashtable are symbols matching EC2 XML element names.
;;; ============================================================================

(def (native-ht-ref ht key default)
  "Hashtable-ref for native Chez symbol-keyed hashtables from jerboa-aws."
  (if (hashtable? ht)
    (hashtable-ref ht key default)
    default))

(def (native-instance-state inst)
  "Get state name (running, stopped, etc.) from native instance hash."
  (let ((state (native-ht-ref inst 'instanceState #f)))
    (if state
      (or (native-ht-ref state 'name #f) "-")
      "-")))

(def (native-instance-name inst)
  "Get Name tag value from native instance hash."
  (let ((tags (native-ht-ref inst 'tagSet '())))
    (if (list? tags)
      (let loop ((ts tags))
        (if (null? ts) ""
          (let ((tag (car ts)))
            (if (and (hashtable? tag)
                     (equal? (native-ht-ref tag 'key #f) "Name"))
              (or (native-ht-ref tag 'value #f) "")
              (loop (cdr ts))))))
      "")))

(def (native-parse-instances response region)
  "Parse describe-instances response hash into list of (cons region instance-hash).
   Only returns running instances."
  (with-catch
    (lambda (e) '())
    (lambda ()
      (let ((reservations (or (native-ht-ref response 'reservationSet #f) '())))
        (apply append
          (map (lambda (reservation)
                 (if (hashtable? reservation)
                   (let ((instances (or (native-ht-ref reservation 'instancesSet #f) '())))
                     (if (list? instances)
                       (filter-map
                         (lambda (inst)
                           (and (hashtable? inst)
                                (string=? (native-instance-state inst) "running")
                                (cons region inst)))
                         instances)
                       '()))
                   '()))
               (if (list? reservations) reservations '())))))))

(def (native-instance->entry region inst)
  "Convert native instance hash + region to a tabulated-list entry."
  (let* ((id      (or (native-ht-ref inst 'instanceId #f) ""))
         (name    (native-instance-name inst))
         (state   (native-instance-state inst))
         (type    (or (native-ht-ref inst 'instanceType #f) "-"))
         (ip      (or (native-ht-ref inst 'privateIpAddress #f) "-"))
         (domain  (aws-get-domain region))
         (ssh-target (if (and (> (string-length name) 0) domain)
                       (string-append name "." domain)
                       "-")))
    (cons id (vector name state type ip region ssh-target))))

;;; ============================================================================
;;; Multi-region async fetch via native jerboa-aws
;;; ============================================================================

(def *aws-pending-regions* 0)
(def *aws-pending-instances* '())
(def *aws-pending-errors* 0)
(def *aws-pending-callback* #f)

(def (aws-fetch-all-regions! callback)
  "Fetch instances from all configured regions asynchronously via native API.
   Spawns one worker thread per region; results are merged on the UI thread."
  (let ((regions *aws-ec2-ssh-common-regions*))
    (set! *aws-pending-regions* (length regions))
    (set! *aws-pending-instances* '())
    (set! *aws-pending-errors* 0)
    (set! *aws-pending-callback* callback)
    (for-each
      (lambda (region)
        (spawn-worker 'aws-fetch-region
          (lambda ()
            (with-catch
              (lambda (e)
                (ui-queue-push!
                  (lambda ()
                    (set! *aws-pending-errors* (+ *aws-pending-errors* 1))
                    (set! *aws-pending-regions* (- *aws-pending-regions* 1))
                    (aws-check-fetch-complete!))))
              (lambda ()
                (let* ((client (EC2Client 'region: region))
                       (result (describe-instances client))
                       (running (native-parse-instances result region)))
                  (ui-queue-push!
                    (lambda ()
                      (set! *aws-pending-instances*
                        (append *aws-pending-instances* running))
                      (set! *aws-pending-regions* (- *aws-pending-regions* 1))
                      (aws-check-fetch-complete!))))))))
      regions))))

(def (aws-check-fetch-complete!)
  "Check if all region fetches are done; fire callback when complete."
  (when (= *aws-pending-regions* 0)
    (let ((instances *aws-pending-instances*)
          (cb *aws-pending-callback*))
      (aws-cache-put! instances)
      (when cb (cb instances)))))

;;; ============================================================================
;;; Mode keymap setup
;;; ============================================================================

(def (aws-ec2-ssh-setup-mode!)
  "Register the AWS EC2 SSH mode keymap and buffer-name mapping."
  (hash-put! *buffer-name-mode-map* "*AWS EC2 SSH*" 'aws-ec2-ssh)
  (let ((km (make-keymap)))
    (for-each (lambda (p) (keymap-bind! km (car p) (cdr p)))
      '(("n"   . next-line)
        ("p"   . previous-line)
        ("RET" . aws-ec2-ssh-connect)
        ("g"   . aws-ec2-ssh-refresh)
        ("G"   . aws-ec2-ssh-force-refresh)
        ("/"   . aws-ec2-ssh-filter)
        ("C"   . aws-ec2-ssh-clear-filter)
        ("s"   . aws-ec2-ssh-sort-name)
        ("S"   . aws-ec2-ssh-sort-region)
        ("q"   . kill-buffer-cmd)))
    (mode-keymap-set! 'aws-ec2-ssh km)))

;;; ============================================================================
;;; Buffer rendering
;;; ============================================================================

(def (aws-refresh-buffer! app instances)
  "Populate the *AWS EC2 SSH* buffer with instance data.
   INSTANCES is a list of (cons region native-hash)."
  (let* ((buf (buffer-by-name "*AWS EC2 SSH*"))
         (ed (current-qt-editor app))
         (fr (app-state-frame app)))
    (when buf
      (let* ((entries (map (lambda (pair)
                             (native-instance->entry (car pair) (cdr pair)))
                           instances))
             (sorted (sort (lambda (a b)
                             (string<? (vector-ref (cdr a) 0)
                                       (vector-ref (cdr b) 0)))
                           entries)))
        (tabulated-list-set-entries! buf sorted)
        (let ((text (tabulated-list-refresh! buf)))
          (when text
            (sci-send ed SCI_SETREADONLY 0)
            (qt-plain-text-edit-set-text! ed text)
            (qt-text-document-set-modified! (buffer-doc-pointer buf) #f)
            (sci-send ed SCI_SETREADONLY 1)
            (let ((pos (sci-send ed SCI_POSITIONFROMLINE tabulated-list-header-lines 0)))
              (qt-plain-text-edit-set-cursor-position! ed pos))
            (sci-send ed SCI_SETCARETLINEBACK (rgb->sci #x2a #x2a #x4a))))))))

(def (aws-re-render! app)
  "Re-render the current tabulated list state (after filter/sort change)."
  (let* ((buf (buffer-by-name "*AWS EC2 SSH*"))
         (ed (current-qt-editor app))
         (line (qt-plain-text-edit-cursor-line ed)))
    (when buf
      (let ((text (tabulated-list-refresh! buf)))
        (when text
          (sci-send ed SCI_SETREADONLY 0)
          (qt-plain-text-edit-set-text! ed text)
          (qt-text-document-set-modified! (buffer-doc-pointer buf) #f)
          (sci-send ed SCI_SETREADONLY 1)
          (let* ((count (tabulated-list-entry-count buf))
                 (max-line (+ tabulated-list-header-lines (max 0 (- count 1))))
                 (target (min line max-line))
                 (pos (sci-send ed SCI_POSITIONFROMLINE (max target tabulated-list-header-lines) 0)))
            (qt-plain-text-edit-set-cursor-position! ed pos)))))))

;;; ============================================================================
;;; Commands
;;; ============================================================================

(def (cmd-aws-ec2-ssh app)
  "Browse EC2 instances and SSH to them.
M-x aws-ec2-ssh
Keys: n/p=navigate, RET=ssh, g=refresh, G=force-refresh, /=filter, q=quit"
  (let* ((config-count (aws-load-config!))
         (fr (app-state-frame app))
         (ed (current-qt-editor app))
         (echo (app-state-echo app))
         (buf-name "*AWS EC2 SSH*")
         (buf (or (buffer-by-name buf-name)
                  (qt-buffer-create! buf-name ed #f))))
    ;; Switch to buffer
    (qt-buffer-attach! ed buf)
    (set! (qt-edit-window-buffer (qt-current-window fr)) buf)
    ;; Initialize tabulated list state if not already
    (unless (tabulated-list-get-state buf)
      (tabulated-list-init! buf *aws-columns*))
    ;; Show loading message
    (sci-send ed SCI_SETREADONLY 0)
    (qt-plain-text-edit-set-text! ed "  Fetching EC2 instances...")
    (sci-send ed SCI_SETREADONLY 1)
    ;; Check cache
    (if (aws-cache-valid?)
      (begin
        (aws-refresh-buffer! app *aws-cache*)
        (echo-message! echo
          (string-append "Loaded " (number->string (length *aws-cache*))
                         " instances from cache")))
      ;; Fetch asynchronously
      (begin
        (echo-message! echo
          (string-append "Fetching instances from "
                         (number->string (length *aws-ec2-ssh-common-regions*))
                         " regions..."))
        (aws-fetch-all-regions!
          (lambda (instances)
            (aws-refresh-buffer! app instances)
            (echo-message! echo
              (string-append "Loaded " (number->string (length instances))
                             " running instances from "
                             (number->string (length *aws-ec2-ssh-common-regions*))
                             " regions"))))))))

(def (cmd-aws-ec2-ssh-refresh app)
  "Refresh instance list (uses cache if valid)."
  (let ((echo (app-state-echo app)))
    (if (aws-cache-valid?)
      (begin
        (aws-refresh-buffer! app *aws-cache*)
        (echo-message! echo "Refreshed from cache"))
      (begin
        (echo-message! echo "Fetching instances...")
        (aws-fetch-all-regions!
          (lambda (instances)
            (aws-refresh-buffer! app instances)
            (echo-message! echo
              (string-append "Loaded " (number->string (length instances)) " instances"))))))))

(def (cmd-aws-ec2-ssh-force-refresh app)
  "Force refresh instance list (bypass cache)."
  (aws-cache-clear!)
  (let ((echo (app-state-echo app)))
    (echo-message! echo "Force fetching instances...")
    (aws-fetch-all-regions!
      (lambda (instances)
        (aws-refresh-buffer! app instances)
        (echo-message! echo
          (string-append "Loaded " (number->string (length instances)) " instances"))))))

(def (cmd-aws-ec2-ssh-connect app)
  "SSH to the instance at point.
Opens a terminal buffer and types the SSH command, then executes it."
  (let* ((buf (current-qt-buffer app))
         (ed (current-qt-editor app))
         (echo (app-state-echo app))
         (line (qt-plain-text-edit-cursor-line ed))
         (entry (tabulated-list-get-entry-at-line buf line)))
    (if (not entry)
      (echo-message! echo "No instance on this line")
      (let* ((vals (cdr entry))
             (name (vector-ref vals 0))
             (state (vector-ref vals 1))
             (ssh-target (vector-ref vals 5)))
        (cond
          ((string-empty? name)
           (echo-message! echo "Instance has no Name tag"))
          ((not (string=? state "running"))
           (echo-message! echo (string-append "Instance is not running (state: " state ")")))
          ((string=? ssh-target "-")
           (echo-message! echo "No SSH target configured for this region"))
          (else
           (let ((ssh-cmd (if *aws-ec2-ssh-user*
                            (string-append "ssh " *aws-ec2-ssh-user* "@" ssh-target)
                            (string-append "ssh " ssh-target))))
             ;; Open a terminal buffer
             (execute-command! app 'term)
             ;; Insert ssh command at the prompt and execute via terminal-send
             (let* ((term-ed (current-qt-editor app))
                    (term-buf (current-qt-buffer app))
                    (ts (and term-buf (hash-get *terminal-state* term-buf))))
               (when ts
                 (qt-plain-text-edit-move-cursor! term-ed QT_CURSOR_END)
                 (qt-plain-text-edit-insert-text! term-ed ssh-cmd)
                 (execute-command! app 'terminal-send)
                 (echo-message! echo (string-append "SSH: " ssh-target)))))))))))

(def (cmd-aws-ec2-ssh-filter app)
  "Filter instances by string."
  (let* ((buf (current-qt-buffer app))
         (query (qt-echo-read-string app "Filter: ")))
    (when query
      (tabulated-list-filter! buf query)
      (aws-re-render! app)
      (echo-message! (app-state-echo app)
        (if (string-empty? query)
          "Filter cleared"
          (string-append "Filter: " query " ("
                         (number->string (tabulated-list-entry-count buf))
                         " matches)"))))))

(def (cmd-aws-ec2-ssh-clear-filter app)
  "Clear the instance filter."
  (let ((buf (current-qt-buffer app)))
    (tabulated-list-clear-filter! buf)
    (aws-re-render! app)
    (echo-message! (app-state-echo app) "Filter cleared")))

(def (cmd-aws-ec2-ssh-sort-name app)
  "Sort instances by name."
  (let ((buf (current-qt-buffer app)))
    (tabulated-list-sort! buf 0)  ;; column 0 = Name
    (aws-re-render! app)
    (echo-message! (app-state-echo app) "Sorted by name")))

(def (cmd-aws-ec2-ssh-sort-region app)
  "Sort instances by region."
  (let ((buf (current-qt-buffer app)))
    (tabulated-list-sort! buf 4)  ;; column 4 = Region
    (aws-re-render! app)
    (echo-message! (app-state-echo app) "Sorted by region")))
