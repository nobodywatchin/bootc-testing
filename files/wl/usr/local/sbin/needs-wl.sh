#!/bin/bash
# Exit 0 if this machine likely needs the proprietary wl driver, else 1.
set -eo pipefail

# Fast path: Broadcom PCI vendor (14e4) present?
if ! lspci -n | awk '{print $3}' | grep -qi '^14e4:'; then
  exit 1
fi

# Known wl-only NICs (expandable):
#   BCM4360 14e4:43a0, BCM4352 14e4:43b1, BCM4331 14e4:4331, BCM43228 14e4:4359, etc.
NEED_IDS='
14e4:43a0
14e4:43b1
14e4:4331
14e4:4359
14e4:432b
14e4:432a
14e4:4338
14e4:43aa
'
if lspci -n | awk '{print $3}' | grep -F -qi "$(echo "$NEED_IDS" | tr '[:upper:]' '[:lower:]' | tr '\n' '|')"; then
  exit 0
fi

# Fallback heuristic:
# If Broadcom Wi-Fi exists AND the in-kernel brcm* drivers are not binding, prefer wl.
if lspci | grep -qi 'broadcom.*network controller' ; then
  # If any brcm driver is already bound, wl likely not needed.
  if lsmod | egrep -q '(^| )brcmfmac|(^| )b43|(^| )brcmsmac' ; then
    exit 1
  fi
  exit 0
fi

exit 1
