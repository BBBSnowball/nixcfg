#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <dlfcn.h>
#include <stdio.h>

int getaddrinfo(const char *node, const char *service,
                const struct addrinfo *hints,
                struct addrinfo **res) {
    static int (*real_getaddrinfo)(const char *, const char *,
                            const struct addrinfo *,
                            struct addrinfo **) = NULL;
    if (!real_getaddrinfo)
        real_getaddrinfo = dlsym(RTLD_NEXT, "getaddrinfo");

    //fprintf(stderr, "DEBUG: ai_family = 0x%04x\n", hints->ai_family);

    struct addrinfo hints2 = *hints;
    if (hints2.ai_family == AF_UNSPEC || hints2.ai_family == AF_INET6)
        hints2.ai_family = AF_INET;  // downgrade to IPv4

    return real_getaddrinfo(node, service, &hints2, res);
}

