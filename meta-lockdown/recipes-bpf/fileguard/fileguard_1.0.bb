SUMMARY = "Custom BPF-LSM file-open restriction demo"
LICENSE = "MIT & GPL-2.0-only"
LIC_FILES_CHKSUM = " \
    file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302 \
    file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6 \
"
# Compile against the shared kernel-derived header staged by lockdown-btf-header.
SRC_URI = "file://fileguard.bpf.c file://fileguard-load.c file://fileguard-open-probe.c file://fileguard-load.service"
S = "${WORKDIR}"
DEPENDS = "clang-native libbpf-native libbpf lockdown-btf-header"
inherit systemd pkgconfig
BPF_TARGET_ARCH ?= "${@'x86' if 'x86' in d.getVar('TARGET_ARCH') else 'arm64'}"
do_compile() {
    ${STAGING_BINDIR_NATIVE}/clang -O2 -g -Wall -target bpf -D__TARGET_ARCH_${BPF_TARGET_ARCH} \
        -ffile-prefix-map=${WORKDIR}=${TARGET_DBGSRC_DIR} \
        -ffile-prefix-map=${STAGING_DIR_NATIVE}= \
        -I${RECIPE_SYSROOT}${includedir}/lockdown \
        -I${STAGING_INCDIR_NATIVE} -I${STAGING_INCDIR_NATIVE}/bpf \
        -c ${WORKDIR}/fileguard.bpf.c -o ${B}/fileguard.bpf.o
    # The pkgconfig class provides the target-sysroot-aware pkg-config
    # executable in PATH; PKG_CONFIG is not defined here on Scarthgap.
    libbpf_cflags="$(pkg-config --cflags libbpf)" || bbfatal "libbpf cflags lookup failed"
    libbpf_libs="$(pkg-config --libs libbpf)" || bbfatal "libbpf linker flags lookup failed"
    test -n "$libbpf_libs" || bbfatal "libbpf pkg-config returned no linker flags"
    ${CC} ${CFLAGS} -O2 -Wall $libbpf_cflags \
        ${WORKDIR}/fileguard-load.c -o ${B}/fileguard-load \
        ${LDFLAGS} $libbpf_libs
    ${CC} ${CFLAGS} -O2 -Wall \
        ${WORKDIR}/fileguard-open-probe.c -o ${B}/fileguard-open-probe \
        ${LDFLAGS}
}
do_install() {
    install -d ${D}${libdir}/bpf ${D}${bindir} ${D}${systemd_system_unitdir}
    install -m 0644 ${B}/fileguard.bpf.o ${D}${libdir}/bpf/
    install -m 0755 ${B}/fileguard-load ${D}${bindir}/
    install -m 0755 ${B}/fileguard-open-probe ${D}${bindir}/
    sed -e "s|@LIBDIR@|${libdir}|g" \
        -e "s|@BINDIR@|${bindir}|g" \
        ${WORKDIR}/fileguard-load.service > ${D}${systemd_system_unitdir}/fileguard-load.service
}
SYSTEMD_SERVICE:${PN} = "fileguard-load.service"
SYSTEMD_AUTO_ENABLE:${PN} = "disable"
RDEPENDS:${PN} = "lockdown-demo"
FILES:${PN} += "${libdir}/bpf/fileguard.bpf.o"
