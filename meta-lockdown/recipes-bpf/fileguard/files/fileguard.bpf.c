// SPDX-License-Identifier: GPL-2.0-only
// Demonstration only: deny writable opens of one existing, provisioned inode.
// Not a complete file-integrity policy (rename, unlink and pre-opened FDs excluded).
#include <vmlinux.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>
#define DEMO_EPERM 1
#define DEMO_O_ACCMODE 3
#define DEMO_O_TRUNC 01000
struct fileguard_rule {
    __u64 ino;
    __u32 dev;
    __u32 enabled;
};
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct fileguard_rule);
} protected_file SEC(".maps");

SEC("lsm/file_open")
int BPF_PROG(fileguard_open, struct file *file, int ret)
{
    if (ret)
        return ret;
    __u32 key = 0;
    struct fileguard_rule *rule = bpf_map_lookup_elem(&protected_file, &key);
    if (!rule || !rule->enabled)
        return 0;
    unsigned int flags = BPF_CORE_READ(file, f_flags);
    if (!(flags & DEMO_O_ACCMODE) && !(flags & DEMO_O_TRUNC))
        return 0; // read-only open: allowed
    struct inode *ino = BPF_CORE_READ(file, f_inode);
    if (!ino)
        return 0;
    __u64 inode_num = BPF_CORE_READ(ino, i_ino);
    __u32 device_num = BPF_CORE_READ(ino, i_sb, s_dev);
    if (rule->ino == inode_num && rule->dev == device_num)
        return -DEMO_EPERM;
    return 0;
}
char LICENSE[] SEC("license") = "GPL";
