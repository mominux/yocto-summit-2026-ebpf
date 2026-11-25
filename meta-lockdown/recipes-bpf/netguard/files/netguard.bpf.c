// netguard.bpf.c
//
// meta-lockdown custom eBPF egress guard.
//
// A cgroup/connect4 hook that blocks outbound TCP connections to a single
// configurable destination port (default 8080). The port lives in a BPF array map so it
// can be changed at load time without recompiling. This is a clean-room example
// written for the talk; it uses only public libbpf / CO-RE conventions.
//
// Build: clang -O2 -g -target bpf -c netguard.bpf.c -o netguard.bpf.o
//
// Attach (via systemd): BPFProgram=connect4:/sys/fs/bpf/netguard/netguard_connect4

#include <vmlinux.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

// Single-entry config map: index 0 holds the blocked port (host byte order).
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, __u16);
} netguard_cfg SEC(".maps");

// Default blocked port if the map has not been populated.
#define NETGUARD_DEFAULT_PORT 8080
#define NETGUARD_IPPROTO_TCP 6

SEC("cgroup/connect4")
int netguard_connect4(struct bpf_sock_addr *ctx)
{
    if (ctx->protocol != NETGUARD_IPPROTO_TCP)
        return 1;

    __u32 key = 0;
    __u16 blocked = NETGUARD_DEFAULT_PORT;
    __u16 *cfg = bpf_map_lookup_elem(&netguard_cfg, &key);

    if (cfg && *cfg != 0)
        blocked = *cfg;

    // ctx->user_port is in network byte order.
    if (ctx->user_port == bpf_htons(blocked))
        return 0;   // deny the connect()

    return 1;       // allow everything else
}

char _license[] SEC("license") = "GPL";
