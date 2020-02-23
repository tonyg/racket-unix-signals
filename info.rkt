#lang info
(define pkg-name 'unix-signals)
(define collection 'multi)
(define deps
  '(["base" #:version "6.12"]
    "dynext-lib"))
(define build-deps
  '("racket-doc"
    "scribble-lib"))
(define homepage
  "https://github.com/tonyg/racket-unix-signals")
