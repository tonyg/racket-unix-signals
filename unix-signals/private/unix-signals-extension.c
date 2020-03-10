#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <fcntl.h>
#include <unistd.h>
#include <signal.h>

#include <sys/types.h>

#include "escheme.h"

/* This implementation uses djb's "self-pipe trick".
 * See http://cr.yp.to/docs/selfpipe.html. */

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

Scheme_Object *prim_get_signal_fd(int argc, Scheme_Object **argv) {
  if (self_pipe_read_end == -1) {
    return scheme_false;
  } else {
    return scheme_make_fd_input_port(self_pipe_read_end, scheme_intern_symbol("signal-fd"), 0, 0);
  }
}

Scheme_Object *prim_get_signal_names(int argc, Scheme_Object **argv) {
  Scheme_Hash_Table *ht;

  ht = scheme_make_hash_table(SCHEME_hash_ptr);

#define ADD_SIGNAL_NAME(n) scheme_hash_set(ht, scheme_intern_symbol(#n), scheme_make_integer(n))

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
#if !defined(__APPLE__) && !defined(__FreeBSD__)
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

  return (Scheme_Object *) ht;
}

Scheme_Object *prim_capture_signal(int argc, Scheme_Object **argv) {
  int signum = SCHEME_INT_VAL(argv[0]);
  int code = SCHEME_INT_VAL(argv[1]);
  switch (code) {
    case 0:
      if (XFORM_HIDE_EXPR(signal(signum, signal_handler_fn) == SIG_ERR)) {
        perror("unix-signals-extension signal(2) install");
        return scheme_false;
      }
      break;
    case 1:
      if (XFORM_HIDE_EXPR(signal(signum, SIG_IGN) == SIG_ERR)) {
        perror("unix-signals-extension signal(2) ignore");
        return scheme_false;
      }
      break;
    case 2:
      if (XFORM_HIDE_EXPR(signal(signum, SIG_DFL) == SIG_ERR)) {
        perror("unix-signals-extension signal(2) default");
        return scheme_false;
      }
      break;
    default:
      return scheme_false;
  }
  return scheme_true;
}

Scheme_Object *prim_send_signal(int argc, Scheme_Object **argv) {
  pid_t pid = SCHEME_INT_VAL(argv[0]);
  int sig = SCHEME_INT_VAL(argv[1]);
  if (kill(pid, sig) == -1) {
    perror("unix-signals-extension kill(2)");
    return scheme_false;
  }
  return scheme_true;
}

Scheme_Object *scheme_reload(Scheme_Env *env) {
  Scheme_Env *module_env;
  Scheme_Object *proc;

  if (!self_pipe_initialized) {
    if (setup_self_pipe() == -1) {
      return scheme_false;
    }
    self_pipe_initialized = 1;
  }

  module_env = scheme_primitive_module(scheme_intern_symbol("unix-signals-extension"), env);

  proc = scheme_make_prim_w_arity(prim_get_signal_fd, "get-signal-fd", 0, 0);
  scheme_add_global("get-signal-fd", proc, module_env);

  proc = scheme_make_prim_w_arity(prim_get_signal_names, "get-signal-names", 0, 0);
  scheme_add_global("get-signal-names", proc, module_env);

  proc = scheme_make_prim_w_arity(prim_capture_signal, "set-signal-handler!", 2, 2);
  scheme_add_global("set-signal-handler!", proc, module_env);

  proc = scheme_make_prim_w_arity(prim_send_signal, "lowlevel-send-signal!", 2, 2);
  scheme_add_global("lowlevel-send-signal!", proc, module_env);

  scheme_finish_primitive_module(module_env);
  return scheme_void;
}

Scheme_Object *scheme_initialize(Scheme_Env *env) {
  return scheme_reload(env);
}

Scheme_Object *scheme_module_name() {
  return scheme_intern_symbol("unix-signals-extension");
}
