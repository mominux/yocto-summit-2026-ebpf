/* ld-connect.c — deterministic TCP/UDP connect() probe for Netguard tests/demo.
 *
 * Attempts a single connect() to <ip> <port> [tcp|udp] and exits with a code
 * that tells the caller *why* it failed:
 *
 *   0   connect() succeeded
 *   13  EPERM / EACCES  — the connect syscall was denied (guard blocked it)
 *   111 ECONNREFUSED    — TCP syscall allowed; no listener on that port
 *   2   usage / bad address / invalid port or protocol
 *   1   any other error
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>

int main(int argc, char **argv)
{
    if (argc < 3 || argc > 4) {
        fprintf(stderr, "usage: ld-connect <ipv4> <port> [tcp|udp]\n");
        return 2;
    }

    char *end;
    errno = 0;
    long port = strtol(argv[2], &end, 10);
    if (errno == ERANGE || end == argv[2] || *end != '\0' ||
        port < 1 || port > 65535) {
        fprintf(stderr, "ld-connect: invalid port %s\n", argv[2]);
        return 2;
    }

    int socket_type = SOCK_STREAM;
    int protocol = IPPROTO_TCP;
    if (argc == 4) {
        if (strcmp(argv[3], "tcp") == 0) {
            socket_type = SOCK_STREAM;
            protocol = IPPROTO_TCP;
        } else if (strcmp(argv[3], "udp") == 0) {
            socket_type = SOCK_DGRAM;
            protocol = IPPROTO_UDP;
        } else {
            fprintf(stderr, "ld-connect: invalid protocol %s\n", argv[3]);
            return 2;
        }
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)port);
    if (inet_pton(AF_INET, argv[1], &addr.sin_addr) != 1) {
        fprintf(stderr, "ld-connect: invalid address %s\n", argv[1]);
        return 2;
    }

    int fd = socket(AF_INET, socket_type, protocol);
    if (fd < 0) {
        perror("socket");
        return 1;
    }

    int rc = connect(fd, (struct sockaddr *)&addr, sizeof(addr));
    int err = errno;
    close(fd);

    if (rc == 0) {
        printf("connected\n");
        return 0;
    }

    printf("errno=%d %s\n", err, strerror(err));
    if (err == EPERM || err == EACCES)
        return 13;
    if (err == ECONNREFUSED)
        return 111;
    return 1;
}
