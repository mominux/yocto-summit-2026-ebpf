# Existing recipe location: only eBPF kernel config and BTF build requirements.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://lockdown-bpf.cfg"
DEPENDS:append = " pahole-native"
EXTRA_OEMAKE:append = " PAHOLE=${STAGING_BINDIR_NATIVE}/pahole"

# Export only the built kernel's BTF section for a shared generated header.
# do_shared_workdir depends on kernel compilation and publishes the artifact
# consumed by lockdown-btf-header:do_compile.
do_shared_workdir:append() {
    test -s "${B}/vmlinux" || \
        bbfatal "Kernel vmlinux is missing"

    ${KERNEL_OBJCOPY} \
        --dump-section .BTF=${STAGING_KERNEL_BUILDDIR}/vmlinux.btf \
        "${B}/vmlinux"

    test -s "${STAGING_KERNEL_BUILDDIR}/vmlinux.btf" || \
        bbfatal "Kernel .BTF section export failed"
}
