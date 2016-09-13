#lang racket/base

(require make/setup-extension)

(provide pre-installer)

(define (pre-installer collections-top-path our-path)
  (pre-install our-path
	       (build-path our-path "private")
	       "unix-signals-extension.c"
	       "."
	       '()
	       '()
	       '()
	       '()
	       '()
	       '()
	       (lambda (thunk) (thunk))
	       #t))
