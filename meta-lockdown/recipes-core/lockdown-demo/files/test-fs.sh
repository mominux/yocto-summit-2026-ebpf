#!/bin/sh
# Built-in systemd RestrictFileSystems= BPF-LSM demonstration.
set -eu
echo "== Baseline: tmpfs write must succeed =="
systemd-run --wait --pipe -- sh -c 'echo ok > /dev/shm/lockdown-probe && rm -f /dev/shm/lockdown-probe'
echo "== With RestrictFileSystems=~tmpfs: tmpfs write must be denied =="
if output="$(systemd-run --wait --pipe -p 'RestrictFileSystems=~tmpfs' \
        -- sh -c 'echo denied > /dev/shm/lockdown-probe' 2>&1)"; then
    echo "FAIL: restricted tmpfs access succeeded" >&2
    rm -f /dev/shm/lockdown-probe
    exit 1
fi
printf '%s\n' "$output"
case "$output" in
    *"Operation not permitted"*|*"Permission denied"*) echo "PASS: access denied" ;;
    *) echo "FAIL: no access-denial evidence" >&2; exit 1 ;;
esac
