/* getifaddrs/freeifaddrs for a resident sandbox whose network namespace holds only loopback.
 *
 * The sandbox refuses every AF_NETLINK socket (seccomp/resident-web.policy), so glibc's getifaddrs, which
 * enumerates through NETLINK_ROUTE, cannot work there. libzmq 4.0.x resolves an interface name through
 * getifaddrs before it parses a literal address and aborts the process when the call fails
 * (tcp_address.cpp errno_assert), which kills IPython's kernel on its first loopback bind.
 *
 * This returns what the namespace actually holds, nothing invented: interface "lo", 127.0.0.1/8 and ::1/128,
 * flags UP|LOOPBACK|RUNNING. It is loaded with LD_PRELOAD for the packages named in
 * src/sandbox.rs (PACKAGES_NEEDING_IFADDRS_SHIM), compiled by build.rs and carried in the spk-host binary.
 * It uses only GLIBC_2.2.5 symbols so it loads under the oldest userland an SPK ships. */
#define _GNU_SOURCE
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>

/* One allocation, so freeifaddrs releases the whole list through its head. */
struct block {
    struct ifaddrs v4, v6;
    struct sockaddr_in a4, m4;
    struct sockaddr_in6 a6, m6;
    char name[4];
};

int getifaddrs(struct ifaddrs **out) {
    struct block *b = calloc(1, sizeof *b);
    if (!b) return -1;
    memcpy(b->name, "lo", 3);
    const unsigned flags = IFF_UP | IFF_LOOPBACK | IFF_RUNNING;
    b->a4.sin_family = AF_INET;   b->a4.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    b->m4.sin_family = AF_INET;   b->m4.sin_addr.s_addr = htonl(0xff000000u);
    b->a6.sin6_family = AF_INET6; b->a6.sin6_addr = in6addr_loopback;
    b->m6.sin6_family = AF_INET6; memset(&b->m6.sin6_addr, 0xff, sizeof b->m6.sin6_addr);
    b->v4 = (struct ifaddrs){ .ifa_next = &b->v6, .ifa_name = b->name, .ifa_flags = flags,
                              .ifa_addr = (struct sockaddr *)&b->a4, .ifa_netmask = (struct sockaddr *)&b->m4 };
    b->v6 = (struct ifaddrs){ .ifa_next = NULL, .ifa_name = b->name, .ifa_flags = flags,
                              .ifa_addr = (struct sockaddr *)&b->a6, .ifa_netmask = (struct sockaddr *)&b->m6 };
    *out = &b->v4;
    return 0;
}

void freeifaddrs(struct ifaddrs *ifa) { free(ifa); }
