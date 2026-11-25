# Scarthgap: enable the built-in systemd eBPF framework.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
# Existing tested fix for native clang picking up host includes.
SRC_URI:append = " file://0002-meson-bpf-drop-host-leaking-isystem-idirafter.patch"
PACKAGECONFIG[bpf-framework] = "-Dbpf-framework=true,-Dbpf-framework=false,clang-native bpftool-native libbpf,libbpf"
PACKAGECONFIG:append = " bpf-framework cgroupv2"
export CCC_OVERRIDE_OPTIONS = "^--sysroot=${STAGING_DIR_TARGET}"
