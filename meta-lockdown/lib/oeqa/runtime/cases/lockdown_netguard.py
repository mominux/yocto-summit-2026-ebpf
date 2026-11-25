from oeqa.runtime.case import OERuntimeTestCase
import shlex

ATTACH = "-p BPFProgram=connect4:/sys/fs/bpf/netguard/netguard_connect4"


class LockdownNetguard(OERuntimeTestCase):
    @classmethod
    def setUpClass(cls):
        status, output = cls.tc.target.run("systemctl start netguard-load.service")
        if status:
            raise RuntimeError(output)
        status, output = cls.tc.target.run(
            "test -e /sys/fs/bpf/netguard/netguard_connect4")
        if status:
            cls.tc.target.run("systemctl stop netguard-load.service")
            raise RuntimeError("Netguard program pin is missing: " + output)

    @classmethod
    def tearDownClass(cls):
        cls.tc.target.run("systemctl stop netguard-load.service")

    def test_blocked_port(self):
        status, output = self.target.run(
            "systemd-run --wait --pipe %s -- ld-connect 127.0.0.1 8080" % ATTACH)
        self.assertEqual(status, 13, output)
        self.assertRegex(output, r"errno=(1|13)\s", output)

    def test_invalid_port_rejected(self):
        for port in ("0", "65536", "abc", "80junk"):
            status, output = self.target.run(
                "ld-connect 127.0.0.1 " + shlex.quote(port))
            self.assertEqual(status, 2, output)
            self.assertIn("invalid port", output)

    def test_allowed_port(self):
        # Start/stop the listener in the same remote shell as the probe.
        listener_and_probe = """
set -eu
log=/tmp/lockdown-netguard-oeqa-listener.log
: > "$log"
systemd-socket-activate -l 127.0.0.1:8081 --inetd --accept /bin/cat \
    </dev/null >"$log" 2>&1 &
listener_pid=$!
trap 'kill "$listener_pid" 2>/dev/null || :; wait "$listener_pid" 2>/dev/null || :' 0
trap 'exit 130' 2
trap 'exit 143' 15
ready=0
for attempt in 1 2 3 4 5; do
    if grep -Fq 'Listening on 127.0.0.1:8081 ' "$log"; then
        ready=1
        break
    fi
    if ! kill -0 "$listener_pid" 2>/dev/null; then
        cat "$log"
        exit 1
    fi
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    cat "$log"
    exit 1
fi
systemd-run --wait --pipe %s -- ld-connect 127.0.0.1 8081
""" % ATTACH
        status, output = self.target.run("sh -c " + shlex.quote(listener_and_probe))
        self.assertEqual(status, 0, output)
        self.assertRegex(output, r"(?m)^connected\r?$", output)

    def test_udp_port_allowed(self):
        status, output = self.target.run(
            "systemd-run --wait --pipe %s -- ld-connect 127.0.0.1 8080 udp" % ATTACH)
        self.assertEqual(status, 0, output)
        self.assertRegex(output, r"(?m)^connected\r?$", output)
