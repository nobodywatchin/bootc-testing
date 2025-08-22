#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/myos"

# Ensure only the USER has 'flathub' named remote
flatpak remote-delete --user flathub 2>/dev/null || true
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak --user update --appstream -y || true

touch "$HOME/.config/myos/flatpak-setup-done"
