# Unix signal sending and handling for Racket

A small example:

```racket
(require unix-signals)

(capture-signal! 'SIGUSR1)
(capture-signal! 'SIGUSR2)
(printf "Try 'kill -USR1 ~a' and 'kill -USR2 ~a'\n" (getpid) (getpid))
(let loop ()
  (define signum (read-signal))
  (printf "Received signal ~v (name ~v)\n" signum (lookup-signal-name signum))
  (loop))
```

Be warned: Don't try to capture `SIGSEGV`, `SIGBUS` or other signals
that Racket already treats specially.

## Licence

Copyright (c) 2016 [Tony Garnock-Jones](https://github.com/tonyg)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this program (see the files "lgpl.txt" and
"gpl.txt"). If not, see <http://www.gnu.org/licenses/>.
