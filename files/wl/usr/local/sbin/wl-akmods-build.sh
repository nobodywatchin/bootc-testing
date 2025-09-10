#!/bin/bash
set -euo pipefail

# -------- Config / paths --------
KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"
WORK="/var/lib/wl-spool"
SRC_BASE="/var/lib/wl-mount/${KVER}/updates"
SRC_WL="${SRC_BASE}/wl"
DST="/usr/lib/modules/${KVER}/updates"
WL_DST="${DST}/wl/wl.ko"

log() { echo "[wl-akmods] $*"; }
die() { echo "[wl-akmods][ERROR] $*" >&2; exit 1; }

is_staged() {
  [[ -f "$WL_DST" ]] && modinfo "$WL_DST" >/dev/null 2>&1
}

# -------- Guard: only skip if truly staged --------
if [[ -f "$MARK" ]]; then
  if is_staged; then
    log "mark + wl.ko present; nothing to do for ${KVER}"
    exit 0
  else
    log "mark exists but wl.ko missing or unreadable; repairing…"
    rm -f "$MARK"
  fi
fi

# -------- Ensure logging dir for akmods on ostree --------
install -d -m 0755 /var/log/akmods

# -------- 1) Build via akmods (best-effort; we’ll still try to use any produced RPM) --------
/usr/sbin/akmods --kernels "${KVER}" --akmod wl || true

# -------- 2) Find a kmod RPM for this kernel --------
RPM="$(ls -1t /var/cache/akmods/wl/kmod-wl-*.x86_64.rpm 2>/dev/null | head -n1 || true)"
[[ -n "$RPM" ]] || die "No kmod-wl RPM found under /var/cache/akmods/wl; check akmods logs."

# -------- 3) Extract wl.ko(.xz) safely --------
rm -rf "${WORK}"
install -d -m 0755 "${WORK}"
pushd "${WORK}" >/dev/null

rpm2cpio "${RPM}" | cpio -idmv >/dev/null 2>&1 || die "Failed to extract ${RPM}"

FOUND="$(find "${WORK}" -type f \( -name 'wl.ko' -o -name 'wl.ko.xz' \) -print -quit || true)"
[[ -n "$FOUND" ]] || die "wl.ko(.xz) not found inside ${RPM}"

WLKO="$FOUND"
if [[ "$WLKO" == *.xz ]]; then
  xz -df "$WLKO"
  WLKO="${WLKO%.xz}"
fi
[[ -f "$WLKO" ]] || die "Decompression failed; ${WLKO} missing."

# -------- 4) Secure Boot: sign if enabled and key exists --------
if mokutil --sb-state 2>/dev/null | grep -qi enabled; then
  PRIV="$(ls -1t /etc/pki/akmods/private/*.priv 2>/dev/null | head -n1 || true)"
  CERT="$(ls -1t /etc/pki/akmods/certs/*.der   2>/dev/null | head -n1 || true)"
  SIGN="/usr/lib/modules/${KVER}/build/scripts/sign-file"
  if [[ -n "$PRIV" && -n "$CERT" && -x "$SIGN" ]]; then
    "$SIGN" sha256 "$PRIV" "$CERT" "$WLKO" || die "Secure Boot signing failed."
    log "signed wl.ko (SB enabled)"
  else
    log "WARNING: SB enabled but sign prerequisites missing; the module may not load."
  fi
fi

popd >/dev/null

# -------- 5) Stage into /var and bind-mount into /usr (ostree-safe) --------
install -d -m 0755 "${SRC_WL}"
install -m 0644 "${WLKO}" "${SRC_WL}/wl.ko"

UNIT="$(systemd-escape --path --suffix=mount "${DST}")"
UNIT_PATH="/etc/systemd/system/${UNIT}"

# Build a correct .mount: filename MUST reflect Where= path
cat > "${UNIT_PATH}" <<EOF
[Unit]
Description=Bind-mount wl updates for kernel ${KVER}
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target

[Mount]
What=${SRC_BASE}
Where=${DST}
Type=none
Options=bind,ro

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${UNIT}"

# -------- 6) Validate mount and staged file --------
systemctl -q is-active "${UNIT}" || die "mount unit ${UNIT} not active."
is_staged || die "wl.ko not visible at ${WL_DST} after mount."

# -------- 7) Try to load dependencies if present (harmless if built-in) --------
CFG80211="$(find "/usr/lib/modules/${KVER}" -name 'cfg80211.ko*' -print -quit || true)"
[[ -n "$CFG80211" ]] && insmod "$CFG80211" || true
LIB80211="$(find "/usr/lib/modules/${KVER}" -name 'lib80211.ko*' -print -quit || true)"
[[ -n "$LIB80211" ]] && insmod "$LIB80211" || true

# -------- 8) Load wl --------
if ! modprobe wl 2>/dev/null; then
  insmod "${WL_DST}" || die "Failed to load wl."
fi

# -------- 9) Mark done (now that the mount+file are good) --------
install -d -m 0755 /var/lib/wl-akmods
: > "${MARK}"
log "wl staged/mounted for ${KVER}"
