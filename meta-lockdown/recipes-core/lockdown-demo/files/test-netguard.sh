#!/bin/sh
# Netguard cgroup/connect4 demo: blocked 8080 must produce EPERM/EACCES;
# allowed 8081 must establish a real TCP connection to a local listener.
set -eu

TARGET="${1:-127.0.0.1}"
BLOCKED_PORT="${2:-8080}"
OPEN_PORT="${3:-8081}"
PROG_PIN="/sys/fs/bpf/netguard/netguard_connect4"
LISTENER_LOG="/tmp/lockdown-netguard-demo-listener.log"
LISTENER_PID=""
LOADER_STARTED=0

cleanup() {
    if [ -n "$LISTENER_PID" ]; then
        kill "$LISTENER_PID" 2>/dev/null || :
        wait "$LISTENER_PID" 2>/dev/null || :
    fi
    if [ "$LOADER_STARTED" -eq 1 ]; then
        systemctl stop netguard-load.service >/dev/null 2>&1 || :
    fi
}
trap cleanup 0
trap 'exit 130' 2
trap 'exit 143' 15

if [ "$TARGET" != "127.0.0.1" ]; then
    echo "FAIL: self-contained test requires TARGET=127.0.0.1" >&2
    exit 2
fi
if ! command -v systemd-socket-activate >/dev/null 2>&1; then
    echo "FAIL: systemd-socket-activate is unavailable" >&2
    exit 1
fi

systemctl start netguard-load.service
LOADER_STARTED=1
if [ ! -e "$PROG_PIN" ]; then
    echo "FAIL: netguard program not pinned at $PROG_PIN" >&2
    exit 1
fi

# Truncate first so stale log messages cannot falsely signal readiness.
: > "$LISTENER_LOG"
systemd-socket-activate -l "$TARGET:$OPEN_PORT" --inetd --accept /bin/cat \
    </dev/null >"$LISTENER_LOG" 2>&1 &
LISTENER_PID=$!
ready=0
for attempt in 1 2 3 4 5; do
    if grep -Fq "Listening on $TARGET:$OPEN_PORT " "$LISTENER_LOG"; then
        ready=1
        break
    fi
    if ! kill -0 "$LISTENER_PID" 2>/dev/null; then
        cat "$LISTENER_LOG" >&2
        echo "FAIL: TCP listener exited before readiness" >&2
        exit 1
    fi
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    cat "$LISTENER_LOG" >&2
    echo "FAIL: TCP listener was not ready" >&2
    exit 1
fi

echo "== blocked TCP port $BLOCKED_PORT: expect EPERM/EACCES =="
if blocked_output="$(systemd-run --wait --pipe \
        -p "BPFProgram=connect4:$PROG_PIN" \
        -- ld-connect "$TARGET" "$BLOCKED_PORT" 2>&1)"; then
    blocked_rc=0
else
    blocked_rc=$?
fi
printf '%s\n' "$blocked_output"
if [ "$blocked_rc" -ne 13 ] || \
   ! printf '%s\n' "$blocked_output" | grep -Eq '^errno=(1|13)[[:space:]]'; then
    echo "FAIL: blocked connection did not produce EPERM/EACCES" >&2
    exit 1
fi
echo "PASS: blocked connection denied by Netguard"

echo
echo "== allowed TCP port $OPEN_PORT: expect connected =="
if allowed_output="$(systemd-run --wait --pipe \
        -p "BPFProgram=connect4:$PROG_PIN" \
        -- ld-connect "$TARGET" "$OPEN_PORT" 2>&1)"; then
    allowed_rc=0
else
    allowed_rc=$?
fi
printf '%s\n' "$allowed_output"
if [ "$allowed_rc" -ne 0 ] || \
   ! printf '%s\n' "$allowed_output" | grep -qx 'connected'; then
    echo "FAIL: allowed port did not establish a TCP connection" >&2
    exit 1
fi
echo "PASS: allowed connection established"
