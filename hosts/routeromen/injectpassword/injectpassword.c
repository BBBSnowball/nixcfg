// based on this code: https://serverfault.com/a/592941

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>

int __libc_start_main(
    int (*main) (int, char * *, char * *),
    int argc, char * * ubp_av,
    void (*init) (void),
    void (*fini) (void),
    void (*rtld_fini) (void),
    void (* stack_end)
  )
{
  int (*next)(
    int (*main) (int, char * *, char * *),
    int argc, char * * ubp_av,
    void (*init) (void),
    void (*fini) (void),
    void (*rtld_fini) (void),
    void (* stack_end)
  ) = dlsym(RTLD_NEXT, "__libc_start_main");

  // Can we use getenv and atoi here? Apparently yes but we are
  // unsure whether it is safe, to be honest. Well, better than
  // leaking the password.
  char* pwn = getenv("PWN");
  int n = pwn ? atoi(pwn) : argc-1;
  char* pw = getenv("PW");
  if (pw && argc > n)
    ubp_av[n] = pw;

  return next(main, argc, ubp_av, init, fini, rtld_fini, stack_end);
}

