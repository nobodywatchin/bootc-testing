#!/bin/bash
set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"
SRC_BASE="/var/lib/wl-mount/${KVER}/updates"
SRC_WL="${SRC_BASE}/wl"
DST="/usr/lib/modules/${KVER}/updates"

# Run only once per kernel
if [[ -f "$MARK" ]]; then
  exit 0
fi

# Build the kmod RPM for this kernel
/usr/sbin/akmods --kernels "$KVER" --akmod wl

# Pick the newest built wl kmod RPM
RPM="$(ls -1t /var/cache/akmods/wl/kmod-wl-*.rpm | head -n1)"

# Extract and locate wl.ko(.xz)
WORK="/var/lib/wl-spool"
rm -rf "$WORK" && mkdir -p "$WORK"
cd "$WORK"
rpm2cpio "$RPM" | cpio -idmv

MOD="$(find "$WORK" -type f -regex '.*\/wl\.ko(\.xz)?$' | head -n1)"
if [[ -z "${MOD:-}" ]]; then
  echo "[wl-akmods] ERROR: wl.ko(.xz) not found in $RPM"
  exit 1
fi

# Stage for bind-mount
install -d -m 0755 "$SRC_WL"
cp -f "$MOD" "$SRC_WL/"

# Create a correctly-named .mount unit for the destination
UNIT="$(systemd-escape --path --suffix=mount "$DST")"
cat >"/etc/systemd/system/${UNIT}" <<EOF
[Unit]
Description=Bind-mount wl updates for kernel ${KVER}
After=local-fs.target
Requires=local-fs.target

[Mount]
What=${SRC_BASE}
Where=${DST}
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF

# Activate the bind mount
systemctl daemon-reload
systemctl enable --now "${UNIT}"

# Load dependencies if they exist as modules (may be built-in)
LIB80211="$(find "/usr/lib/modules/${KVER}" -name 'lib80211.ko*' -print -quit || true)"
[[ -n "${LIB80211}" ]] && insmod "${LIB80211}" || true
CFG80211="$(find "/usr/lib/modules/${KVER}" -name 'cfg80211.ko*' -print -quit || true)"
[[ -n "${CFG80211}" ]] && insmod "${CFG80211}" || true

# Insert wl by absolute path (bypasses modules.dep writes on read-only /usr)
WLKO="$(find "${DST}" -name 'wl.ko*' -print -quit)"
if [[ -z "${WLKO:-}" ]]; then
  echo "[wl-akmods] ERROR: wl.ko not visible at ${DST}"
  exit 1
fi
insmod "${WLKO}" || true

# Mark done for this kernel
install -d -m 0755 /var/lib/wl-akmods
: > "$MARK"

echo "[wl-akmods] Staged and loaded wl for ${KVER}"
