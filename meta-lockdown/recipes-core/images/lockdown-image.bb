SUMMARY = "Minimal eBPF security demonstration image"
LICENSE = "MIT"
inherit core-image
IMAGE_INSTALL:append = " systemd systemd-analyze bpftool iputils-ping netguard fileguard lockdown-demo"
IMAGE_FEATURES:append = " debug-tweaks"
IMAGE_LINGUAS = ""

# Frame the exact five-row banner with terminal blank lines in the image,
# without modifying the original source artwork used by the demo package.
install_demo_issue() {
    issue_source="${IMAGE_ROOTFS}${datadir}/lockdown-demo/issue"
    issue_target="${IMAGE_ROOTFS}${sysconfdir}/issue"
    {
        printf '\n\n'
        cat "$issue_source"
        printf '\n\n'
    } > "$issue_target"
    chmod 0644 "$issue_target"
}
ROOTFS_POSTPROCESS_COMMAND += "install_demo_issue;"
# The function is invoked indirectly by its name; track its body in the task hash.
# Without this, editing its body can leave do_rootfs marked up to date.
do_rootfs[vardeps] += "install_demo_issue"
