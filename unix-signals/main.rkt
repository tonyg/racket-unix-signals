#lang racket/base

(provide next-signal-evt
         read-signal
         lookup-signal-number
         lookup-signal-name
         capture-signal!
         ignore-signal!
         release-signal!
         getpid
         send-signal!)

(require (only-in racket/os getpid))
(require "private/unix-signals-extension.rkt")

(define signal-fd (get-signal-fd))

(define next-signal-evt
  (handle-evt signal-fd (lambda (_) (read-signal))))

(define (read-signal) (read-byte signal-fd))

(define signals-by-name (get-signal-names))
(define signals-by-number
  (for/hash [((name number) (in-hash signals-by-name))] (values number name)))

(define (lookup-signal-number sym) (hash-ref signals-by-name sym #f))
(define (lookup-signal-name num) (hash-ref signals-by-number num #f))

(define (name->signum who n)
  (cond
    [(symbol? n) (or (lookup-signal-number n)
                     (error who "Unknown signal name ~a" n))]
    [(fixnum? n) n]
    [else (error who "Expects signal name symbol or signal number; got ~v" n)]))

(define (capture-signal! sig)
  (set-signal-handler! (name->signum 'capture-signal! sig) 0))

(define (ignore-signal! sig)
  (set-signal-handler! (name->signum 'capture-signal! sig) 1))

(define (release-signal! sig)
  (set-signal-handler! (name->signum 'capture-signal! sig) 2))

(define (send-signal! pid sig)
  (when (not (fixnum? pid)) (error 'send-signal! "Expected fixnum pid; got ~v" pid))
  (lowlevel-send-signal! pid (name->signum 'send-signal! sig)))
