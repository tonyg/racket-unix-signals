#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include <fcntl.h>
#include <unistd.h>
#include <signal.h>

#include <sys/types.h>

/* This implementation uses djb's "self-pipe trick".
 * See http://cr.yp.to/docs/selfpipe.html. */

/* TODO: Communicate errno to Racket rather than using `perror`.
 * See Racket's `saved-errno` and `lookup-errno`. */

static int self_pipe_initialized = 0;
static int self_pipe_read_end = -1;
static int self_pipe_write_end = -1;

static int setup_self_pipe(void) {
  {
    int pipefd[2];
    if (pipe(pipefd) == -1) {
      perror("unix-signals-extension pipe(2)");
      goto error;
    }
    self_pipe_read_end = pipefd[0];
    self_pipe_write_end = pipefd[1];
  }

  {
    int flags = fcntl(self_pipe_write_end, F_GETFL, 0);
    if (flags == -1) {
      perror("unix-signals-extension F_GETFL");
      goto error;
    }
    if (fcntl(self_pipe_write_end, F_SETFL, flags | O_NONBLOCK) == -1) {
      perror("unix-signals-extension F_SETFL");
      goto error;
    }
  }

  return 0;

 error:
  if (self_pipe_write_end != -1) {
    int tmp = self_pipe_write_end;
    self_pipe_write_end = -1;
    close(tmp);
  }
  if (self_pipe_read_end != -1) {
    int tmp = self_pipe_read_end;
    self_pipe_read_end = -1;
    close(tmp);
  }
  return -1;
}

static void signal_handler_fn(int signum) {
  if (self_pipe_write_end == -1) {
    return;
  }

  {
    uint8_t b;
    b = (uint8_t) (signum & 0xff);
    if (write(self_pipe_write_end, &b, 1) == -1) {
      perror("unix-signals-extension write");
    }
  }
}

int prim_get_signal_fd(void) {
    return self_pipe_read_end;
}

void prim_signal_names_for_each(void (*callback)(char*, int)) {

#define ADD_SIGNAL_NAME(n) callback(#n, n)

  /* POSIX.1-1990 */
  ADD_SIGNAL_NAME(SIGHUP);
  ADD_SIGNAL_NAME(SIGINT);
  ADD_SIGNAL_NAME(SIGQUIT);
  ADD_SIGNAL_NAME(SIGILL);
  ADD_SIGNAL_NAME(SIGABRT);
  ADD_SIGNAL_NAME(SIGFPE);
  ADD_SIGNAL_NAME(SIGKILL);
  ADD_SIGNAL_NAME(SIGSEGV);
  ADD_SIGNAL_NAME(SIGPIPE);
  ADD_SIGNAL_NAME(SIGALRM);
  ADD_SIGNAL_NAME(SIGTERM);
  ADD_SIGNAL_NAME(SIGUSR1);
  ADD_SIGNAL_NAME(SIGUSR2);
  ADD_SIGNAL_NAME(SIGCHLD);
  ADD_SIGNAL_NAME(SIGCONT);
  ADD_SIGNAL_NAME(SIGSTOP);
  ADD_SIGNAL_NAME(SIGTSTP);
  ADD_SIGNAL_NAME(SIGTTIN);
  ADD_SIGNAL_NAME(SIGTTOU);

  /* Not POSIX.1-1990, but SUSv2 and POSIX.1-2001 */
  ADD_SIGNAL_NAME(SIGBUS);
#if !defined(__APPLE__)
  ADD_SIGNAL_NAME(SIGPOLL);
#endif
  ADD_SIGNAL_NAME(SIGPROF);
  ADD_SIGNAL_NAME(SIGSYS);
  ADD_SIGNAL_NAME(SIGTRAP);
  ADD_SIGNAL_NAME(SIGURG);
  ADD_SIGNAL_NAME(SIGVTALRM);
  ADD_SIGNAL_NAME(SIGXCPU);
  ADD_SIGNAL_NAME(SIGXFSZ);

  /* Misc, that we hope are widely-supported enough not to have to
     bother with a feature test. */
  ADD_SIGNAL_NAME(SIGIO);
  ADD_SIGNAL_NAME(SIGWINCH);

#undef ADD_SIGNAL_NAME


}

bool prim_capture_signal(int signum, int code) {
  switch (code) {
    case 0:
      if (signal(signum, signal_handler_fn) == SIG_ERR) {
        perror("unix-signals-extension signal(2) install");
        return false;
      }
      break;
    case 1:
      if (signal(signum, SIG_IGN) == SIG_ERR) {
        perror("unix-signals-extension signal(2) ignore");
        return false;
      }
      break;
    case 2:
      if (signal(signum, SIG_DFL) == SIG_ERR) {
        perror("unix-signals-extension signal(2) default");
        return false;
      }
      break;
    default:
      return false;
  }
  return true;
}

bool prim_send_signal(pid_t pid, int sig) {
  if (kill(pid, sig) == -1) {
    perror("unix-signals-extension kill(2)");
    return false;
  }
  return true;
}

bool racket_unix_signals_init(void) {

  if (!self_pipe_initialized) {
    if (setup_self_pipe() == -1) {
      return false;
    }
    self_pipe_initialized = 1;
  }

  return true;
}
