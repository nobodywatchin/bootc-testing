#!/bin/bash
set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"
WORK="/var/lib/wl-spool"
SRC_BASE="/var/lib/wl-mount/${KVER}/updates"
SRC_WL="${SRC_BASE}/wl"
DST="/usr/lib/modules/${KVER}/updates"

# Run only once per kernel
[[ -f "$MARK" ]] && exit 0

# akmods likes to log here; ensure it exists on ostree
install -d -m 0755 /var/log/akmods

# 1) Build kmod RPM for this kernel
/usr/sbin/akmods --kernels "$KVER" --akmod wl

# 2) Pick newest built wl kmod RPM
RPM="$(ls -1t /var/cache/akmods/wl/kmod-wl-*.rpm | head -n1)"
if [[ -z "${RPM:-}" || ! -f "$RPM" ]]; then
  echo "[wl-akmods] ERROR: no kmod-wl RPM found in /var/cache/akmods/wl"
  exit 1
fi

# 3) Extract and locate wl.ko(.xz) ANYWHERE in the RPM
rm -rf "$WORK" && install -d -m 0755 "$WORK"
( cd "$WORK" && rpm2cpio "$RPM" | cpio -idmv )

FOUND="$(find "$WORK" -type f -regex '.*\/wl\.ko(\.xz)?$' | head -n1 || true )"
if [[ -z "${FOUND:-}" ]]; then
  echo "[wl-akmods] ERROR: wl.ko(.xz) not found in $RPM"
  exit 1
fi

# 4) If compressed, decompress to a .ko (insmod cannot load .xz)
WLKO="$FOUND"
if [[ "$WLKO" = *.xz ]]; then
  xz -df "$WLKO"     # leaves .../wl.ko
  WLKO="${WLKO%.xz}"
fi
if [[ ! -f "$WLKO" ]]; then
  echo "[wl-akmods] ERROR: wl.ko missing after decompression"
  exit 1
fi

# 5) Stage into /var for bind-mount exposure
install -d -m 0755 "$SRC_WL"
install -m 0644 "$WLKO" "$SRC_WL/wl.ko"

# 6) Create CORRECTLY-NAMED .mount unit for ${DST}
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

# 7) Activate the bind mount
systemctl daemon-reload
systemctl enable --now "${UNIT}"

# 8) Load deps if they exist as modules (may be built-in on EL10)
LIB80211="$(find "/usr/lib/modules/${KVER}" -name 'lib80211.ko*' -print -quit || true)"
[[ -n "${LIB80211}" ]] && insmod "${LIB80211}" || true
CFG80211="$(find "/usr/lib/modules/${KVER}" -name 'cfg80211.ko*' -print -quit || true)"
[[ -n "${CFG80211}" ]] && insmod "${CFG80211}" || true

# 9) Insert wl by absolute path (avoids depmod writes on read-only /usr)
insmod "${DST}/wl/wl.ko" || true

# 10) Mark done for this kernel
install -d -m 0755 /var/lib/wl-akmods
: > "$MARK"

echo "[wl-akmods] wl staged, mounted, and (attempted) loaded for ${KVER}"
