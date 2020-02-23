#lang racket/base

(require ffi/unsafe
         ffi/unsafe/port
         ffi/unsafe/define
         racket/port
         (rename-in racket/contract
                    [-> ->/c])
         (only-in racket/os getpid))

(provide lookup-signal-number
         lookup-signal-name
         getpid
         (contract-out
          ;; These may not do what you want,
          ;; but they shouldn't break invariants
          ;; of the runtime system:
          [next-signal-evt
           (evt/c byte?)]
           [read-signal
            (->/c byte?)])
         ;; These are unsafe:
         (protect-out
          (contract-out
           [capture-signal!
            (->/c (or/c symbol? fixnum?) boolean?)]
           [ignore-signal!
            (->/c (or/c symbol? fixnum?) boolean?)]
           [release-signal!
            (->/c (or/c symbol? fixnum?) boolean?)]
           [send-signal!
            (->/c fixnum? (or/c symbol? fixnum?) boolean?)])))

(define (local-lib-dirs)
  ;; FIXME: There's probably a better way to do this with
  ;; define-runtime-path and cross-system-library-subpath,
  ;; but this is what the bcrypt package is doing.
  (list (build-path (collection-path "unix-signals")
                    "private"
                    "compiled"
                    "native"
                    (system-library-subpath #f))))

(define libracket-unix-signals
  (ffi-lib "libracket_unix_signals" #:get-lib-dirs local-lib-dirs))

(define-ffi-definer define-unix libracket-unix-signals
  #:default-make-fail make-not-available)

;; TODO: should we be using #:lock-name, #:in-original-place?,
;; or other options for some of these _fun types?

(define-values [signals-by-name signals-by-number]
  (let ([signals-by-name #hasheq()]
        [signals-by-number #hasheq()])
    ;; "two fixnums that are `=` are also the same according to `eq?`"
    (define-unix racket_unix_signals_init
      (_fun -> _stdbool))
    (unless (racket_unix_signals_init)
      (error 'unix-signals "error initializing foreign library"))
    (define-unix prim_signal_names_for_each
      (_fun (_fun _symbol _fixint -> _void)
            -> _void))
    (prim_signal_names_for_each
     (λ (name num)
       (set! signals-by-name (hash-set signals-by-name name num))
       (set! signals-by-number (hash-set signals-by-number num name))))  
    (values signals-by-name signals-by-number)))

(define (lookup-signal-number sym)
  (hash-ref signals-by-name sym #f))
(define (lookup-signal-name num)
  (hash-ref signals-by-number num #f))


(define-values [read-signal next-signal-evt]
  (let ()
    (define-unix prim_get_signal_fd
      (_fun -> _int))
    (define signal-fd-in
      ;; NB: closing this port closes the file descriptor
      ;; (that was already true with scheme_make_fd_input_port)
      (unsafe-file-descriptor->port (prim_get_signal_fd)
                                    'signal-fd
                                    '(read)))
    (define (assert-not-eof who v)
      (if (eof-object? v)
          (raise (exn:fail:read:eof
                  (format "~a: internal error;\n unexpected eof" who)
                  (current-continuation-marks)
                  null))
          v))
    (define (read-signal)
      (assert-not-eof 'read-signal (read-byte signal-fd-in)))
    (values read-signal
            (wrap-evt (read-bytes-evt 1 signal-fd-in)
                      (λ (bs)
                        (assert-not-eof 'next-signal-evt bs)
                        (bytes-ref bs 0))))))

(define name->signum
  (case-lambda
    [(who sig)
     (name->signum who #f sig)]
    [(who ?pid sig)
     (cond
       [(fixnum? sig)
        sig]
       [(lookup-signal-number sig)]
       [else
        (error who
               "unknown signal name\n  given: ~e~a\n  known names...:~a"
               sig
               (if ?pid (format "\n  pid: ~e" ?pid) "")
               (apply string-append
                      (hash-map signals-by-name
                                (λ (name _num)
                                  (format "\n   ~e" name))
                                'ordered)))])]))

(define-unix prim_capture_signal
  (_fun _fixint _fixint -> _stdbool))

(define (capture-signal! sig)
  (prim_capture_signal (name->signum 'capture-signal! sig) 0))

(define (ignore-signal! sig)
  (prim_capture_signal (name->signum 'ignore-signal! sig) 1))

(define (release-signal! sig)
  (prim_capture_signal (name->signum 'release-signal! sig) 2))

(define-unix prim_send_signal
  (_fun _fixint _fixint -> _stdbool))

(define (send-signal! pid sig)
  (prim_send_signal pid (name->signum 'send-signal! pid sig)))
