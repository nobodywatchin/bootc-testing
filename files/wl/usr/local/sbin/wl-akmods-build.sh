#!/bin/bash
set -euo pipefail
KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"
[ -f "$MARK" ] && exit 0

# Build kmod RPM
/usr/sbin/akmods --kernels "$KVER" --akmod wl

# Extract wl.ko(.xz)
RPM=$(ls -1 /var/cache/akmods/wl/kmod-wl-*.rpm | tail -n1)
WORK=/var/lib/wl-spool
rm -rf "$WORK" && mkdir -p "$WORK"
cd "$WORK"
rpm2cpio "$RPM" | cpio -idmv

# Stage for bind-mount
install -d -m 0755 "/var/lib/wl-mount/${KVER}/updates/wl"
cp -f "lib/modules/${KVER}/extra/wl/wl.ko"* "/var/lib/wl-mount/${KVER}/updates/wl/"

# Bind-mount updates into /usr
UNIT="usr-lib-modules-${KVER//\//-}-updates.mount"
cat >"/etc/systemd/system/${UNIT}" <<EOF
[Unit]
Description=Bind-mount wl updates for kernel ${KVER}
After=local-fs.target
Requires=local-fs.target

[Mount]
What=/var/lib/wl-mount/${KVER}/updates
Where=/usr/lib/modules/${KVER}/updates
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "$UNIT"

# Try to insert deps + wl by path (no depmod writes)
LIB80211=$(find "/usr/lib/modules/${KVER}" -name 'lib80211.ko*' | head -n1 || true)
[ -n "${LIB80211:-}" ] && insmod "$LIB80211" || true

WLKO=$(find "/usr/lib/modules/${KVER}/updates" -name 'wl.ko*' | head -n1)
insmod "$WLKO" || true

# Mark done
install -d -m 0755 /var/lib/wl-akmods
: > "$MARK"
