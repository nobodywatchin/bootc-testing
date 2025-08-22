#!/usr/bin/env bash
set -euo pipefail
mkdir -p /var/lib/myos
if flatpak --system remotes --columns=name | grep -qx org-system; then
  flatpak --system remote-modify --no-enumerate org-system
fi
touch /var/lib/myos/org-system-hidden
