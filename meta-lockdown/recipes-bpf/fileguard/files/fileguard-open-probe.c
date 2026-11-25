// SPDX-License-Identifier: MIT
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: fileguard-open-probe <FILE>\n");
        return 2;
    }

    int fd = open(argv[1], O_RDONLY | O_TRUNC);
    if (fd < 0) {
        int err = errno;
        fprintf(stderr, "errno=%d %s\n", err, strerror(err));
        if (err == EPERM || err == EACCES)
            return 13;
        return 1;
    }

    close(fd);
    puts("opened");
    return 0;
}
