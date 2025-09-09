#!/bin/bash
set -euo pipefail

KVER="$(uname -r)"
MARK="/var/lib/wl-akmods/done-${KVER}"

# Safety: if the marker somehow exists, exit
if [[ -f "$MARK" ]]; then
  exit 0
fi

echo "[wl-akmods] Building wl for ${KVER}"
/usr/sbin/akmods --kernels "$KVER" --akmod wl
/usr/sbin/depmod -a "$KVER"

# Load the module (don’t fail the build if insert fails—SB, etc.)
/usr/sbin/modprobe wl || true

# Create the per-kernel marker
install -d -m 0755 /var/lib/wl-akmods
: > "$MARK"
echo "[wl-akmods] Done; marked ${MARK}"
