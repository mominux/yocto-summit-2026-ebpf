#!/bin/sh
# Restore the provisioned demo configuration without changing its inode.
# Refuse while Fileguard may still protect the file.
set -eu

config=/etc/lockdown-demo/device.conf
baseline=/usr/share/lockdown-demo/device.conf
link=/sys/fs/bpf/fileguard_link

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || fail 'run as root'
state="$(systemctl is-active fileguard-load.service 2>/dev/null || :)"
[ "$state" = inactive ] || fail "Fileguard must be inactive (state: ${state:-unknown})"
[ ! -e "$link" ] || fail 'Fileguard BPF link is still pinned'
[ -f "$config" ] && [ ! -L "$config" ] || fail 'existing regular demo config not found'
[ -f "$baseline" ] && [ ! -L "$baseline" ] || fail 'packaged baseline config not found'
command -v cmp >/dev/null 2>&1 || fail 'cmp utility not available'

# Truncate and write the existing inode: do not rm/mv/replace device.conf.
cat "$baseline" > "$config" || fail 'could not restore demo config'
cmp -s "$baseline" "$config" || fail 'restored content differs from baseline'
printf 'PASS: demo config restored in place (%s)\n' "$config"
