SUMMARY = "Small eBPF demo scripts, example configuration and login banner"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
SRC_URI = " \
    file://test-netif.sh \
    file://test-fs.sh \
    file://test-netguard.sh \
    file://test-fileguard.sh \
    file://reset-demo.sh \
    file://device.conf \
    file://issue \
"
S = "${WORKDIR}"
DEMO_DIR = "${datadir}/lockdown-demo"
do_install() {
    install -d ${D}${DEMO_DIR} ${D}${sysconfdir}/lockdown-demo
    for s in test-netif test-fs test-netguard test-fileguard reset-demo; do
        install -m 0755 ${WORKDIR}/$s.sh ${D}${DEMO_DIR}/$s.sh
    done
    install -m 0644 ${WORKDIR}/device.conf ${D}${sysconfdir}/lockdown-demo/device.conf
    # Keep the canonical baseline separate from the writable runtime conffile.
    install -m 0644 ${WORKDIR}/device.conf ${D}${DEMO_DIR}/device.conf
    install -m 0644 ${WORKDIR}/issue ${D}${DEMO_DIR}/issue
}
CONFFILES:${PN} += "${sysconfdir}/lockdown-demo/device.conf"
RDEPENDS:${PN} = "systemd iputils-ping"
