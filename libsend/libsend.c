
#include <sys/socket.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <errno.h>
#include <string.h>
#include <stdarg.h>

#include "config.h"

static int lib_initialized = 0;
static ssize_t (*orig_send)(int, const void *, size_t, int) = 0;
static FILE *log = 0;

void die(char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args);
  va_end(args);
  fprintf(stderr, "\n");
  fflush(stderr);
  exit(-1);
}

void log_msg(char *fmt, ...) {
  va_list args;
  time_t t;
  char *tstr, *c;

  time(&t);
  tstr = strdup(ctime(&t));
  for(c=tstr; (*c!='\n')&&(*c!=0); c++);
  if(*c=='\n'){*c=0;}
  fprintf(log, "%s: ", tstr);
  free(tstr);

  va_start(args, fmt);
  vfprintf(log, fmt, args);
  va_end(args);

  fflush(log);
}

void lib_init() {
  void *libhdl;
  char *dlerr;
  char *logfile, default_log[]="/tmp/wrapper.log";

  if (lib_initialized) return;

  if (!(libhdl=dlopen(SOCKET_LIB, RTLD_LAZY)))
    die("Failed to patch library calls: %s", dlerror());

  orig_send = dlsym(libhdl, "send");
  if ((dlerr=dlerror()) != NULL)
    die("Failed to patch send() library call: %s", dlerr);

  if (!(logfile=getenv("WRAPPER_LOG"))) {
    logfile = default_log;
  }

  if (!(log = fopen(logfile, "a")))
    die("Failed to open log file (%s): %s", logfile, strerror(errno));

  lib_initialized = 1;
}


int send (int s, const void *buf, size_t len, int flags)
{
  lib_init();
  log_msg("SENT %s\n", (char *) buf);
  return orig_send(s, buf, len, flags);
}

