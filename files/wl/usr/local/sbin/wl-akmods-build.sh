#!/usr/bin/env bash
set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"
WORK="/var/lib/wl-spool"
SRC_BASE="/var/lib/wl-mount/${KVER}/updates"
SRC_WL="${SRC_BASE}/wl"
DST="/usr/lib/modules/${KVER}/updates"
UNIT="$(systemd-escape --path --suffix=mount "${DST}")"   # e.g. usr-lib-modules-<...>-updates.mount

ensure_mount_unit() {
  # Create the bind-mount unit whose *name* matches the Where= path (must match or systemd refuses it)
  install -d -m 0755 "${SRC_WL}"
  install -d -m 0755 "${DST}" || true

  cat >/etc/systemd/system/"${UNIT}" <<EOF
[Unit]
Description=Bind-mount wl updates for kernel ${KVER}

[Mount]
Where=${DST}
What=${SRC_BASE}
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${UNIT}"
}

blacklist_conf() {
  install -d -m 0755 /run/modprobe.d
  cat >/run/modprobe.d/wl-blacklist.conf <<'EOF'
# block in-kernel Broadcom drivers that conflict with wl
blacklist b43
blacklist bcma
blacklist brcmsmac
EOF
}

try_insmod() {
  # cfg80211 may be needed; lib80211 is built-in on many EL kernels
  local cfg
  cfg="$(find "/usr/lib/modules/${KVER}" -name 'cfg80211.ko*' -print -quit || true)"
  [[ -n "${cfg}" ]] && insmod "${cfg}" || true

  insmod "${DST}/wl/wl.ko" || true
  modprobe wl || true
}

# ──────────────────────────────────────────────────────────────────────────────
# 0) If mark exists but wl is actually missing (e.g., after a base update),
#    clear the mark so we rebuild/re-stage.
if [[ -f "${MARK}" && ! -e "${DST}/wl/wl.ko" && ! -e "${SRC_WL}/wl.ko" ]]; then
  rm -f "${MARK}"
fi

# 1) If we’ve already done this for this kernel, ensure the mount is up and try load.
if [[ -f "${MARK}" ]]; then
  ensure_mount_unit
  blacklist_conf
  # depmod is a no-op on ostree /lib; we rely on direct insmod+modprobe
  try_insmod
  exit 0
fi

# 2) If wl.ko is already present (staged or mounted), just mount+load and mark done.
if [[ -e "${DST}/wl/wl.ko" || -e "${SRC_WL}/wl.ko" ]]; then
  ensure_mount_unit
  blacklist_conf
  try_insmod
  install -d -m 0755 /var/lib/wl-akmods
  : > "${MARK}"
  echo "[wl-akmods] used existing wl.ko for ${KVER}"
  exit 0
fi

# 3) No wl.ko yet: try akmods to (build → rpm), then extract wl.ko from the kmod RPM.
install -d -m 0755 /var/log/akmods || true
/usr/sbin/akmods --kernels "${KVER}" --akmod wl || true

RPM="$(ls -1t /var/cache/akmods/wl/kmod-wl-${KVER%%.*}-*.x86_64.rpm 2>/dev/null | head -n1 || true)"
if [[ -z "${RPM}" || ! -f "${RPM}" ]]; then
  echo "[wl-akmods] ERROR: no kmod-wl RPM produced for ${KVER}"
  exit 1
fi

rm -rf "${WORK}"
install -d -m 0755 "${WORK}"
pushd "${WORK}" >/dev/null
rpm2cpio "${RPM}" | cpio -idmv
FOUND="$(find "${WORK}" -type f \( -name 'wl.ko' -o -name 'wl.ko.xz' \) -print -quit || true)"
popd >/dev/null

if [[ -z "${FOUND}" ]]; then
  echo "[wl-akmods] ERROR: wl.ko(.xz) not found in ${RPM}"
  exit 1
fi

# Decompress if necessary and stage to the writable mount source
if [[ "${FOUND}" == *.xz ]]; then
  xz -df "${FOUND}"
  FOUND="${FOUND%.xz}"
fi

install -d -m 0755 "${SRC_WL}"
install -m 0644 "${FOUND}" "${SRC_WL}/wl.ko"

# 4) Bind-mount -> blacklist -> load -> mark
ensure_mount_unit
blacklist_conf
try_insmod

install -d -m 0755 /var/lib/wl-akmods
: > "${MARK}"
echo "[wl-akmods] wl staged/mounted for ${KVER}"