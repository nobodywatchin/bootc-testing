#!/usr/bin/env bash
set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"
WORK="/var/lib/wl-spool"
SRC_BASE="/var/lib/wl-mount/${KVER}/updates"
SRC_WL="${SRC_BASE}/wl"
DST="/usr/lib/modules/${KVER}/updates"
UNIT="$(systemd-escape --path --suffix=mount "${DST}")"   # usr-lib-modules-...-updates.mount

ensure_mount_unit() {
  install -d -m 0755 "${SRC_WL}"
  # /usr is read-only under ostree; it's fine if this fails:
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

restore_label() {
  # prefer restorecon; fall back to chcon
  if command -v restorecon >/dev/null 2>&1; then
    restorecon -Rv "$1" || true
  else
    chcon -R -t modules_object_t "$1" || true
  fi
}

try_insmod() {
  # cfg80211 may be separate; lib80211 is often built-in on EL10
  local cfg
  cfg="$(find "/usr/lib/modules/${KVER}" -name 'cfg80211.ko*' -print -quit || true)"
  [[ -n "${cfg}" ]] && insmod "${cfg}" || true

  # load the staged module and then resolve softdeps
  insmod "${DST}/wl/wl.ko" || true
  modprobe wl || true
}

# ──────────────────────────────────────────────────────────────────────────────
# 0) If mark exists but wl is missing (e.g., base flip), clear the mark.
if [[ -f "${MARK}" && ! -e "${DST}/wl/wl.ko" && ! -e "${SRC_WL}/wl.ko" ]]; then
  rm -f "${MARK}"
fi

# 1) If already done for this kernel, ensure the mount and try load.
if [[ -f "${MARK}" ]]; then
  ensure_mount_unit
  blacklist_conf
  try_insmod
  exit 0
fi

# 2) If wl.ko already exists (staged or mounted), mount+label+load and mark done.
if [[ -e "${DST}/wl/wl.ko" || -e "${SRC_WL}/wl.ko" ]]; then
  ensure_mount_unit
  # make sure correct SELinux labels exist on both sides
  restore_label "${SRC_BASE}"
  if mountpoint -q "${DST}"; then restore_label "${DST}"; fi
  blacklist_conf
  try_insmod
  install -d -m 0755 /var/lib/wl-akmods
  : > "${MARK}"
  echo "[wl-akmods] used existing wl.ko for ${KVER}"
  exit 0
fi

# 3) Build via akmods → extract wl.ko from the kmod RPM.
install -d -m 0755 /var/log/akmods || true
/usr/sbin/akmods --kernels "${KVER}" --akmod wl || true

# Figure out the kmod-wl RPM name for this kernel series (X.Y.Z-NN).
SERIES="$(echo "${KVER}" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+).*/\1-\2/')"
RPM="$(ls -1t /var/cache/akmods/wl/kmod-wl-${SERIES}.el10_*x86_64.rpm 2>/dev/null | head -n1 || true)"
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

# Decompress if necessary, then stage
[[ "${FOUND}" == *.xz ]] && xz -df "${FOUND}" && FOUND="${FOUND%.xz}"

install -d -m 0755 "${SRC_WL}"
install -m 0644 "${FOUND}" "${SRC_WL}/wl.ko"

# 4) Bind-mount → label (source & destination) → blacklist → load → mark
ensure_mount_unit
restore_label "${SRC_BASE}"
if mountpoint -q "${DST}"; then restore_label "${DST}"; fi
blacklist_conf
try_insmod

install -d -m 0755 /var/lib/wl-akmods
: > "${MARK}"
echo "[wl-akmods] wl staged/mounted for ${KVER}"
