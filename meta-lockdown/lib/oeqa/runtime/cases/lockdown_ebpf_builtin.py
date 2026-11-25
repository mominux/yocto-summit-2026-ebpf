from oeqa.runtime.case import OERuntimeTestCase

class LockdownEbpfBuiltin(OERuntimeTestCase):
    def test_restrict_network_interfaces(self):
        status, output = self.target.run(
            "systemd-run --wait --pipe -p RestrictNetworkInterfaces=lo "
            "-- ping -c1 -w2 -I lo 127.0.0.1")
        self.assertEqual(status, 0, output)
        status, output = self.target.run(
            "systemd-run --wait --pipe -p RestrictNetworkInterfaces=lockdown-none0 "
            "-- ping -c1 -w2 -I lo 127.0.0.1")
        self.assertNotEqual(status, 0, output)
        # RestrictNetworkInterfaces= filters traffic; ping may report packet
        # loss rather than a socket-level EPERM/EACCES error. Requiring the
        # ping banner and precise counters rejects unrelated unit failures.
        self.assertIn("PING 127.0.0.1", output,
                      "Restricted ping was not executed: " + output)
        self.assertRegex(
            output,
            r"\b[1-9][0-9]* packets transmitted,\s*0 received,\s*100% packet loss\b",
            "Missing evidence of blocked ICMP replies: " + output)

    def test_restrict_filesystems(self):
        status, output = self.target.run(
            "systemd-run --wait --pipe -- sh -c 'echo ok > /dev/shm/ld-probe && rm /dev/shm/ld-probe'")
        self.assertEqual(status, 0, output)
        status, output = self.target.run(
            "systemd-run --wait --pipe -p RestrictFileSystems='~tmpfs' "
            "-- sh -c 'echo denied > /dev/shm/ld-probe'")
        self.target.run("rm -f /dev/shm/ld-probe")
        self.assertNotEqual(status, 0, output)
        self.assertTrue(
            "Permission denied" in output or "Operation not permitted" in output,
            "No access-denial evidence: " + output)
