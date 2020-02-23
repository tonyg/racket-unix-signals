#lang racket/base

(require dynext/file
         dynext/link
         racket/file)

(provide pre-installer)

;; Used by "../info.rkt" (so this-collection-path is "..").

;; Heavily based on Sam Tobin-Hochstadt's bcrypt/private/install.rkt
;; https://github.com/samth/bcrypt.rkt

(define (pre-installer collections-top-path this-collection-path)
  (define unix-signals/private/
    (build-path this-collection-path "private"))
  (parameterize ([current-directory unix-signals/private/]
                 [current-use-mzdyn #f])
    (define racket_unix_signals.c
      (build-path unix-signals/private/ "racket_unix_signals.c"))
    (define libracket_unix_signals.so
      (build-path unix-signals/private/
                  "compiled"
                  "native"
                  (system-library-subpath #f)
                  (append-extension-suffix "libracket_unix_signals")))
    (when (file-exists? libracket_unix_signals.so)
      (delete-file libracket_unix_signals.so))
    (make-parent-directory* libracket_unix_signals.so)
    (link-extension #f ;; not quiet
                    (list racket_unix_signals.c)
                    libracket_unix_signals.so)))
