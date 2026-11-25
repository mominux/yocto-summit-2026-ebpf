from oeqa.runtime.case import OERuntimeTestCase

CONF = "/etc/lockdown-demo/device.conf"
LINK = "/sys/fs/bpf/fileguard_link"

class LockdownFileguard(OERuntimeTestCase):
    @classmethod
    def setUpClass(cls):
        status, output = cls.tc.target.run("test ! -e %s" % LINK)
        if status:
            raise RuntimeError("Stale Fileguard link; clear the old policy before testing")
        status, output = cls.tc.target.run(
            "sh -c 'printf \"# oeqa pre-attach write\\n\" >> %s'" % CONF)
        if status:
            raise RuntimeError("Baseline write must succeed before attachment: " + output)
        status, output = cls.tc.target.run("systemctl start fileguard-load.service")
        if status:
            raise RuntimeError(output)
        status, output = cls.tc.target.run("test -e %s" % LINK)
        if status:
            raise RuntimeError("Fileguard link not pinned: " + output)

    @classmethod
    def tearDownClass(cls):
        cls.tc.target.run("systemctl stop fileguard-load.service")

    def test_read_allowed(self):
        status, output = self.target.run("cat %s" % CONF)
        self.assertEqual(status, 0, output)
        self.assertIn("device_id=", output)

    def test_truncation_denied(self):
        status, output = self.target.run("fileguard-open-probe %s" % CONF)
        self.assertEqual(status, 13, output)
        self.assertRegex(output, r"errno=(1|13)\s", output)

        status, output = self.target.run("cat %s" % CONF)
        self.assertEqual(status, 0, output)
        self.assertIn("device_id=", output)

    def test_write_denied(self):
        status, output = self.target.run("sh -c 'echo tamper >> %s'" % CONF)
        self.assertNotEqual(status, 0, output)
        self.assertTrue(
            "Permission denied" in output or "Operation not permitted" in output,
            "Write failed without EACCES/EPERM evidence: " + output)
