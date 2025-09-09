#!/bin/bash
set -euo pipefail
KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"
[ -f "$MARK" ] && exit 0

# Build kmod RPM
/usr/sbin/akmods --kernels "$KVER" --akmod wl

# Take the newest wl kmod RPM
RPM=$(ls -1 /var/cache/akmods/wl/kmod-wl-*.rpm | tail -n1)

# Extract and stage for this exact kernel
WORK=/var/lib/wl-spool
rm -rf "$WORK" && mkdir -p "$WORK"
cd "$WORK"
rpm2cpio "$RPM" | cpio -idmv

install -d -m 0755 "/var/lib/wl-extra/${KVER}/extra"
cp -f "lib/modules/${KVER}/extra/wl/wl.ko"* "/var/lib/wl-extra/${KVER}/extra/"

# Expose via tmpfiles link
cat >/etc/tmpfiles.d/wl-extra.conf <<'EOF'
L+ /usr/lib/modules/%v/extra - - - - /var/lib/wl-extra/%v/extra
EOF
systemd-tmpfiles --create /etc/tmpfiles.d/wl-extra.conf

# Register & load
depmod -a "$KVER"
modprobe lib80211 || true
modprobe wl || true

# Mark done for this kernel
install -d -m 0755 /var/lib/wl-akmods
: > "$MARK"
