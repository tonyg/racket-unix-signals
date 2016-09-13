#lang scribble/manual

@(require scriblib/footnote
	  (for-label racket unix-signals racket/os))

@title{unix-signals}
@author[(author+email "Tony Garnock-Jones" "tonyg@leastfixedpoint.com")]

If you find that this library lacks some feature you need, or you have
a suggestion for improving it, please don't hesitate to
@link["mailto:tonyg@leastfixedpoint.com"]{get in touch with me}!

@section{Introduction}

This library provides a means of sending and receiving Unix signals to
Racket programs.

Be warned that attempting to receive certain signals used by the
Racket runtime is dangerous, as the code here will conflict with the
code in Racket itself.

@section{What to require}

All the functionality below can be accessed with a single
@racket[require]:

@(defmodule unix-signals)

This library represents signal names as symbols all in upper-case;
for example, @racket['SIGUSR1] and @racket['SIGKILL].

@subsection{Waiting for a signal}

To receive Unix signals using this library, call
@racket[capture-signal!] once for each signal of interest, and then
use @racket[next-signal-evt] or @racket[read-signal]. Use
@racket[ignore-signal!] and @racket[release-signal!] to ignore a
signal (@tt{SIG_IGN}) or to install the default
signal-handler (@tt{SIG_DFL}), respectively.

@racketblock[
(require unix-signals)
(capture-signal! 'SIGUSR1)
(capture-signal! 'SIGUSR2)
(printf "Try 'kill -USR1 ~a' and 'kill -USR2 ~a'\n" (getpid) (getpid))
(let loop ()
  (define signum (read-signal))
  (printf "Received signal ~v (name ~v)\n" signum (lookup-signal-name signum))
  (loop))]

Calls to @racket[capture-signal!] and friends have @emph{global} effect
within the Racket process. Likewise, use of @racket[next-signal-evt]
and @racket[read-signal] have global side-effects on the state of the
Racket process.

@defproc[(capture-signal! [sig (or/c fixnum? symbol?)]) boolean?]{
Installs a signal handler for the given signal. When the given signal
is received by the process, its signal number will be returned by uses
of @racket[next-signal-evt] and/or @racket[read-signal]. }

@defproc[(ignore-signal! [sig (or/c fixnum? symbol?)]) boolean?]{
Causes the given signal to be ignored (@tt{SIG_IGN}) by the process. }

@defproc[(release-signal! [sig (or/c fixnum? symbol?)]) boolean?]{
Installs the default handler (@tt{SIG_DFL}) for the given signal. }

@defthing[next-signal-evt evt?]{ @tech[#:doc
'(lib "scribblings/reference/reference.scrbl")]{Synchronizable event} which
becomes ready when a signal previously registered with
@racket[capture-signal!] is received, at which point it returns the
number of the received signal as its synchronization result by
yielding the result of a call to @racket[read-signal]. }

@defproc[(read-signal) fixnum?]{ Blocks until a signal previously
registered with @racket[capture-signal!] is received. Returns the
number of the received signal. Signals are buffered internally using
the @link["http://cr.yp.to/docs/selfpipe.html"]{self-pipe trick}, and
are therefore delivered in order of receipt. }

@subsection{Sending a signal}

This library provides @racket[getpid] from @racketmodname[racket/os]
for convenience.

@defproc[(send-signal! [pid fixnum?] [sig (or/c fixnum? symbol?)])
boolean?]{ Calls @tt{kill(2)} to deliver the given signal to the
given process ID. All special cases for @racket[pid] from the
@tt{kill(2)} manpage apply. }

@subsection{Mapping between signal names and signal numbers}

@defproc[(lookup-signal-number [sym symbol?]) (opt/c fixnum?)]{
Returns a fixnum if the symbol name is defined, or @racket[#f] if not. }

@defproc[(lookup-signal-name [num fixnum?]) (opt/c symbol?)]{ Returns
a symbol naming the given signal number, if one is defined, or
@racket[#f] if not. Note that in cases where multiple C identifiers
map to a given signal number, an arbitrary choice among the
possibilities is returned. }
