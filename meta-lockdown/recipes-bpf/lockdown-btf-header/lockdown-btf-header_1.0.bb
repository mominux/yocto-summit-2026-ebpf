SUMMARY = "BTF-derived kernel header for lockdown eBPF programs"
DESCRIPTION = "Generates vmlinux.h from the Yocto-built kernel BTF"

# CLOSED is not an assertion about upstream BTF or Linux header licenses.
LICENSE = "CLOSED"

PACKAGE_ARCH = "${MACHINE_ARCH}"
S = "${WORKDIR}"
B = "${WORKDIR}/build"

DEPENDS = "bpftool-native"

# Explicit dependency ensures fresh kernel BTF export precedes generation.
do_compile[depends] += "virtual/kernel:do_shared_workdir"

do_compile() {
    test -s "${STAGING_KERNEL_BUILDDIR}/vmlinux.btf" || \
        bbfatal "Kernel BTF artifact is missing"

    install -d "${B}"

    ${STAGING_SBINDIR_NATIVE}/bpftool btf dump \
        file "${STAGING_KERNEL_BUILDDIR}/vmlinux.btf" \
        format c > "${B}/vmlinux.h"

    test -s "${B}/vmlinux.h" || \
        bbfatal "Generated vmlinux.h is empty"
}

do_install() {
    install -d "${D}${includedir}/lockdown"
    install -m 0644 "${B}/vmlinux.h" \
        "${D}${includedir}/lockdown/vmlinux.h"
}
