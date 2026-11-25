// SPDX-License-Identifier: MIT
// Load a demo BPF-LSM policy for one existing device configuration inode.
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
struct fileguard_rule {
    uint64_t ino;
    uint32_t dev;
    uint32_t enabled;
};
int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: fileguard-load <BPF_OBJECT> <EXISTING_FILE>\n");
        return 2;
    }
    struct stat st;
    if (stat(argv[2], &st) != 0 || !S_ISREG(st.st_mode)) {
        fprintf(stderr, "expected existing regular file: %s\n", argv[2]);
        return 1;
    }
    struct bpf_object *obj = bpf_object__open_file(argv[1], NULL);
    long err = libbpf_get_error(obj);
    if (err) {
        fprintf(stderr, "opening BPF object failed: %ld\n", err);
        return 1;
    }
    err = bpf_object__load(obj);
    if (err) {
        fprintf(stderr, "loading BPF object failed: %ld\n", err);
        goto out;
    }
    struct bpf_map *map = bpf_object__find_map_by_name(obj, "protected_file");
    struct bpf_program *prog = bpf_object__find_program_by_name(obj, "fileguard_open");
    if (!map || !prog) {
        err = -ENOENT;
        goto out;
    }
    struct fileguard_rule rule = {
        .ino = (uint64_t)st.st_ino,
        .dev = ((uint32_t)major(st.st_dev) << 20) | (uint32_t)minor(st.st_dev),
        .enabled = 1,
    };
    uint32_t key = 0;
    if (bpf_map_update_elem(bpf_map__fd(map), &key, &rule, BPF_ANY)) {
        err = -errno;
        fprintf(stderr, "setting fileguard policy failed: %s\n", strerror(errno));
        goto out;
    }
    struct bpf_link *link = bpf_program__attach_lsm(prog);
    err = libbpf_get_error(link);
    if (err) {
        fprintf(stderr, "attaching BPF-LSM failed: %ld\n", err);
        goto out;
    }
    err = bpf_link__pin(link, "/sys/fs/bpf/fileguard_link");
    if (err)
        fprintf(stderr, "pinning BPF-LSM link failed: %ld\n", err);
    else
        printf("Fileguard is protecting %s\n", argv[2]);
    bpf_link__destroy(link);
out:
    bpf_object__close(obj);
    return err ? 1 : 0;
}
