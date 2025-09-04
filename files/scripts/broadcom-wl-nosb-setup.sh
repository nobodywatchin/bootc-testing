#!/usr/bin/env bash
set -euo pipefail

# Simple Broadcom wl (no Secure Boot) bootstrapper for EL10/Alma 10
# - Assumes akmods + akmod-wl + build deps are already installed.
# - Blacklists OSS drivers, ensures akmods runs at boot,
#   and auto-builds/loads wl after kernel updates.

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Please run as root." >&2
    exit 1
  fi
}

warn_if_secure_boot() {
  if command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state 2>/dev/null | grep -qiE 'SecureBoot\s*enabled'; then
      echo "WARNING: Secure Boot appears ENABLED; wl will not load without signing/MOK." >&2
      echo "Disable Secure Boot in firmware (or switch to the signed/MOK flow) and re-run." >&2
    fi
  fi
}

write_blacklist() {
  install -d /etc/modprobe.d
  cat >/etc/modprobe.d/blacklist-broadcom.conf <<'EOF'
blacklist bcma
blacklist b43
blacklist brcmsmac
blacklist ssb
EOF
}

enable_akmods() {
  systemctl enable akmods.service >/dev/null 2>&1 || true
}

main "$@"
