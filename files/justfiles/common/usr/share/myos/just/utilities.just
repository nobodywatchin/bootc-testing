# vim: set ft=make :

uid := `id -u`
shell := `grep :$(id -u): /etc/passwd | cut -d: -f7`

# Regenerate GRUB config, useful in dual-boot scenarios where a second operating system isn't listed
regenerate-grub:
    if [ -d /sys/firmware/efi ]; then
      grub2-mkconfig -o /etc/grub2-efi.cfg
    else
      grub2-mkconfig -o /etc/grub2.cfg
    fi

# Clean up old up unused podman images, volumes, flatpak packages
clean-user:
    podman image prune -af
    podman volume prune -f
    flatpak uninstall --unused

# Check for local overrides
check-local-overrides:
    diff -r \
      --suppress-common-lines \
      --color="always" \
      --exclude "passwd*" \
      --exclude "group*" \
      --exclude="subgid*" \
      --exclude="subuid*" \
      --exclude="machine-id" \
      --exclude="adjtime" \
      --exclude="fstab" \
      --exclude="system-connections" \
      --exclude="shadow*" \
      --exclude="gshadow*" \
      --exclude="ssh_host*" \
      --exclude="cmdline" \
      --exclude="crypttab" \
      --exclude="hostname" \
      --exclude="localtime" \
      --exclude="locale*" \
      --exclude="*lock" \
      --exclude=".updated" \
      --exclude="*LOCK" \
      --exclude="vconsole*" \
      --exclude="00-keyboard.conf" \
      --exclude="grub" \
      --exclude="system.control*" \
      --exclude="cdi" \
      --exclude="default.target" \
      /usr/etc /etc 2>/dev/null | sed '/Binary\ files\ /d'

# Debug dump pastebin for issue reporting
debug-info:
    rpm_ostree_status=$(echo -e "=== Rpm-Ostree Status ===\n"; rpm-ostree status --verbose)
    sysinfo=$(echo -e "\n"; fpaste --sysinfo --printonly)
    flatpaks=$(echo "=== Flatpaks Installed ==="; flatpak list --columns=application,version,options)
    audit_results=$(echo -e "\n=== Audit Results ===\n"; ujust audit-secureblue)
    local_overrides=$(echo -e "\n=== Listing Local Overrides ===\n"; ujust check-local-overrides)
    recent_events=$(echo -e "\n=== Recent System Events ===\n"; journalctl -b -p err..alert --since "1 hour ago")
    failed_services=$(echo -e "\n=== Failed Services ===\n"; systemctl list-units --state=failed)
    content="$rpm_ostree_status$sysinfo$flatpaks$audit_results$local_overrides$recent_events$failed_services"
    echo "$content" | fpaste --confirm --private=1

# Returns the state of container domain user namespaces. (enabled/disabled)
check-container-userns-state:
    set -euo pipefail
    if [ "$(whoami)" = 'root' ]; then
        semodule -l | grep -q 'harden_container_userns' && echo 'disabled' || echo 'enabled'
    else
        podman unshare true &> /dev/null && echo 'enabled' || echo 'disabled'
    fi

# Returns the state of unconfined domain user namespaces. (enabled/disabled)
check-unconfined-userns-state:
    set -euo pipefail
    if [ "$(whoami)" = 'root' ]; then
        semodule -l | grep -q 'harden_userns' && echo 'disabled' || echo 'enabled'
    else
        unshare -U true &> /dev/null && echo 'enabled' || echo 'disabled'
    fi

# Setup USBGuard
setup-usbguard:
    @echo "Notice: This will generate a policy based on your existing connected USB devices."
    # shellcheck disable=SC2016
    run0 sh -c '
        mkdir -p /var/log/usbguard
        mkdir -p /etc/usbguard
        chmod 755 /etc/usbguard
        groupadd usbguard
        usermod -aG usbguard "$SUDO_USER"
        usbguard generate-policy > /etc/usbguard/rules.conf
        sed -i "/^IPCAllowedGroups=wheel/s/\$/ usbguard/" /etc/usbguard/usbguard-daemon.conf
        restorecon -vR /var/log/usbguard
        systemctl enable --now usbguard.service
        usbguard add-user "$SUDO_USER"
    '
    if ! rpm-ostree status | grep '●' | grep -q 'securecore'; then
        systemctl enable --user --now usbguard-notifier.service
    fi
