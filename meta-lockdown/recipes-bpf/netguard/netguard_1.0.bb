SUMMARY = "netguard — custom cgroup/connect4 eBPF egress-port guard"
DESCRIPTION = "Compiles a small CO-RE eBPF program that blocks outbound IPv4 \
connections to a configurable destination port, plus a systemd loader that pins it for \
attachment via BPFProgram=connect4:."
LICENSE = "MIT & GPL-2.0-only"
LIC_FILES_CHKSUM = " \
    file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302 \
    file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6 \
"

SRC_URI = " \
    file://netguard.bpf.c \
    file://netguard-load.service \
    file://ld-connect.c \
"
S = "${WORKDIR}"

# Native clang BPF compilation does not inherit Yocto target DEBUG_PREFIX_MAP.
# Keep -g for BTF/CO-RE, but avoid embedding absolute WORKDIR/sysroot paths.
# The pinned Scarthgap DEBUG_PREFIX_MAP contains -fcanon-prefix-map,
# which clang-native does not accept; use its -ffile-prefix-map instead.
BPF_CLANG_PREFIX_MAP = " \
    -ffile-prefix-map=${WORKDIR}=${TARGET_DBGSRC_DIR} \
    -ffile-prefix-map=${STAGING_DIR_NATIVE}= \
"

# Build the BPF object at recipe build time using the native clang toolchain.
# CO-RE: compile against the header staged by lockdown-btf-header and native
# libbpf headers, not target UAPI headers. No checked-in vmlinux.h is consumed.
DEPENDS = "clang-native libbpf-native lockdown-btf-header"
inherit systemd

BPF_TARGET_ARCH ?= "${@'x86' if 'x86' in d.getVar('TARGET_ARCH') else 'arm64'}"

do_compile() {
    ${STAGING_BINDIR_NATIVE}/clang -O2 -g -Wall \
        ${BPF_CLANG_PREFIX_MAP} \
        -target bpf -D__TARGET_ARCH_${BPF_TARGET_ARCH} \
        -I${RECIPE_SYSROOT}${includedir}/lockdown \
        -I${STAGING_INCDIR_NATIVE} \
        -I${STAGING_INCDIR_NATIVE}/bpf \
        -c ${WORKDIR}/netguard.bpf.c -o ${B}/netguard.bpf.o

    # Small target-native connect() probe used by the demo and oeqa tests.
    ${CC} ${CFLAGS} -O2 -Wall \
        ${WORKDIR}/ld-connect.c -o ${B}/ld-connect ${LDFLAGS}
}

do_install() {
    install -d ${D}${libdir}/bpf
    install -m 0644 ${B}/netguard.bpf.o ${D}${libdir}/bpf/netguard.bpf.o

    install -d ${D}${bindir}
    install -m 0755 ${B}/ld-connect ${D}${bindir}/ld-connect

    install -d ${D}${systemd_system_unitdir}
    sed -e "s|@LIBDIR@|${libdir}|g" \
        -e "s|@SBINDIR@|${sbindir}|g" \
        ${WORKDIR}/netguard-load.service > ${D}${systemd_system_unitdir}/netguard-load.service
}

SYSTEMD_SERVICE:${PN} = "netguard-load.service"
SYSTEMD_AUTO_ENABLE:${PN} = "disable"
RDEPENDS:${PN} = "bpftool"
FILES:${PN} = " \
    ${libdir}/bpf/netguard.bpf.o \
    ${bindir}/ld-connect \
    ${systemd_system_unitdir}/netguard-load.service \
"
