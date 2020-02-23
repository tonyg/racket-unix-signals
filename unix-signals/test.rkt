#!/usr/bin/env racket
#lang racket/base

(module test '#%kernel)

(require unix-signals)

(module+ main
  (capture-signal! 'SIGUSR1)
  (capture-signal! 'SIGUSR2)
  (printf "Try 'kill -USR1 ~a' and 'kill -USR2 ~a'\n" (getpid) (getpid))
  (let loop ([mode #t])
    (define signum
      (if mode
          (read-signal)
          (sync next-signal-evt)))
    (printf "Received signal ~v (name ~v)\n" signum (lookup-signal-name signum))
    (loop (not mode))))
