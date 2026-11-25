#!/bin/sh
# Fileguard use case: read a provisioned configuration; block new writable opens.
set -eu
file=/etc/lockdown-demo/device.conf
link=/sys/fs/bpf/fileguard_link
if [ -e "$link" ]; then
    echo "FAIL: Fileguard link already pinned; stop the prior demo first" >&2
    exit 1
fi
echo "== Baseline: read and write before loading policy must succeed =="
cat "$file"
printf '# baseline write\n' >> "$file"
systemctl start fileguard-load.service
trap 'systemctl stop fileguard-load.service' 0
test -e "$link" || { echo "FAIL: no pinned Fileguard link" >&2; exit 1; }
echo "== After attachment: read must still succeed =="
cat "$file"
echo "== After attachment: writable open should fail (EPERM/EACCES) =="
if result="$(sh -c 'echo tamper >> /etc/lockdown-demo/device.conf' 2>&1)"; then
    echo "FAIL: writable open was allowed" >&2
    exit 1
fi
printf '%s\n' "$result"
case "$result" in
    *"Operation not permitted"*|*"Permission denied"*)
        echo "PASS: writable open denied" ;;
    *) echo "FAIL: unrelated failure rather than permission denial" >&2; exit 1 ;;
esac
