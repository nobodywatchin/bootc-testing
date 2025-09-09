#!/bin/bash
set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"

# Only run once per kernel
if [[ -f "$MARK" ]]; then exit 0; fi

# Build the kmod RPM via akmods
/usr/sbin/akmods --kernels "$KVER" --akmod wl

# Find the freshly built RPM
RPM=$(ls -1 /var/cache/akmods/wl/kmod-wl-*.rpm | tail -n1)

# Extract and stage wl.ko(.xz) to /var
WORK=/var/lib/wl-spool
rm -rf "$WORK" && mkdir -p "$WORK"
cd "$WORK"
rpm2cpio "$RPM" | cpio -idmv

MOD=$(find "$WORK" -type f -regex '.*\/wl\.ko(\.xz)?$' | head -n1)
install -d -m 0755 "/var/lib/wl-extra/${KVER}/extra"
cp -f "$MOD" "/var/lib/wl-extra/${KVER}/extra/"

# Ensure the tmpfiles link exists
cat >/etc/tmpfiles.d/wl-extra.conf <<'EOF'
L+ /usr/lib/modules/%v/extra - - - - /var/lib/wl-extra/%v/extra
EOF
systemd-tmpfiles --create /etc/tmpfiles.d/wl-extra.conf

# Register and load
depmod -a "$KVER"
modprobe wl || true

# Mark as done
install -d -m 0755 /var/lib/wl-akmods
: > "$MARK"
