#!/bin/sh
# Built-in systemd RestrictNetworkInterfaces= BPF demonstration.
set -eu
iface="${1:-lo}"
echo "== Baseline: permitted interface $iface must work =="
systemd-run --wait --pipe -p "RestrictNetworkInterfaces=$iface" \
    -- ping -c1 -w2 -I "$iface" 127.0.0.1
echo "== Denied: allow only a nonexistent interface =="
if output="$(systemd-run --wait --pipe -p 'RestrictNetworkInterfaces=lockdown-none0' \
        -- ping -c1 -w2 -I "$iface" 127.0.0.1 2>&1)"; then
    echo "FAIL: restricted ping succeeded" >&2
    exit 1
fi
printf '%s\n' "$output"
# Packet filtering normally causes loss without a syscall error.
# Require evidence that ping actually ran, rather than accepting any failure
# from systemd-run or ping argument validation.
case "$output" in
    *"PING 127.0.0.1"* ) ;;
    *) echo "FAIL: restricted ping did not execute" >&2; exit 1 ;;
esac
case "$output" in
    *" packets transmitted, 0 received, 100% packet loss"*)
        echo "PASS: denied traffic caused complete ping packet loss" ;;
    *) echo "FAIL: no ping packet-loss evidence" >&2; exit 1 ;;
esac
