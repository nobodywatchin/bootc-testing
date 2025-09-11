# Update System Flatpaks and OS Image
update-system:
  sudo bootc upgrade
  #!/usr/bin/bash
  echo "Reboot to apply System updates"

# Update Podman Containers
update-podman:
  podman image prune -f
  podman auto-update --authfile ~/.config/containers/auth.json

# Update Firmware
update-firmware:
  sudo fwupdmgr refresh --force
  sudo fwupdmgr update -y

# Update Everything
update-all:
  just update-system
  just update-podman
  just update-firmware
