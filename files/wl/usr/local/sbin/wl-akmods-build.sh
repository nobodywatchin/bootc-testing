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

# Ensure akmods can log on ostree
install -d -m 0755 /var/log/akmods

# 1) Build the kmod for this kernel
/usr/sbin/akmods --kernels "$KVER" --akmod wl || true

# 2) Pick newest kmod RPM if present (akmods may still return failed.log but leave a usable RPM)
RPM="$(ls -1t /var/cache/akmods/wl/kmod-wl-*.rpm 2>/dev/null | head -n1 || true)"
if [[ -z "${RPM:-}" || ! -f "$RPM" ]]; then
  echo "[wl-akmods] ERROR: no kmod-wl RPM in /var/cache/akmods/wl"
  exit 1
fi

# 3) Extract it and find wl.ko or wl.ko.xz (no regex; use -name)
rm -rf "$WORK" && install -d -m 0755 "$WORK"
( cd "$WORK" && rpm2cpio "$RPM" | cpio -idmv )

FOUND="$(find "$WORK" -type f \( -name 'wl.ko' -o -name 'wl.ko.xz' \) -print -quit || true)"
if [[ -z "${FOUND:-}" ]]; then
  echo "[wl-akmods] ERROR: wl.ko(.xz) not found in $RPM"
  exit 1
fi

# 4) Decompress if needed (insmod can't load .xz)
WLKO="$FOUND"
if [[ "$WLKO" = *.xz ]]; then
  xz -df "$WLKO"
  WLKO="${WLKO%.xz}"
fi
[[ -f "$WLKO" ]] || { echo "[wl-akmods] ERROR: wl.ko missing after decompression"; exit 1; }

# 5) Stage in /var for bind-mount
install -d -m 0755 "$SRC_WL"
install -m 0644 "$WLKO" "$SRC_WL/wl.ko"

# 6) Create the correctly-named .mount unit for the destination
UNIT="$(systemd-escape --path --suffix=mount "$DST")"
cat >"/etc/systemd/system/${UNIT}" <<EOF2
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
EOF2

# 7) Activate the mount
systemctl daemon-reload
systemctl enable --now "${UNIT}"

# 8) Load deps if they exist as modules (often built-in on EL10; ignore failures)
LIB80211="$(find "/usr/lib/modules/${KVER}" -name 'lib80211.ko*' -print -quit || true)"
[[ -n "${LIB80211}" ]] && insmod "${LIB80211}" || true
CFG80211="$(find "/usr/lib/modules/${KVER}" -name 'cfg80211.ko*' -print -quit || true)"
[[ -n "${CFG80211}" ]] && insmod "${CFG80211}" || true

# 9) Insert wl by absolute path; ignore if it errors (you can modprobe later)
insmod "${DST}/wl/wl.ko" || true

# 10) Mark done for this kernel
install -d -m 0755 /var/lib/wl-akmods
: > "$MARK"
echo "[wl-akmods] wl staged/mounted for ${KVER}"