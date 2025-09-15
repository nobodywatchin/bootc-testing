# Toggle the cups service on/off
toggle-cups:
    if systemctl is-enabled --quiet cups; then
      firewall-cmd --permanent --remove-port=631/tcp
      firewall-cmd --permanent --remove-port=631/udp
      firewall-cmd --reload
      systemctl disable --now cups.socket
      systemctl mask cups.socket
      systemctl disable --now cups.service
      systemctl mask cups.service
      systemctl mask --now avahi-daemon.socket
      systemctl mask --now avahi-daemon.service
      systemctl daemon-reload
      echo "CUPS & avahi-daemon disabled"
    else
      firewall-cmd --permanent --add-port=631/tcp
      firewall-cmd --permanent --add-port=631/udp
      firewall-cmd --reload
      systemctl unmask cups.socket
      systemctl unmask cups.service
      systemctl enable --now cups.socket
      systemctl enable --now cups.service
      systemctl unmask avahi-daemon.service
      systemctl unmask avahi-daemon.socket
      systemctl daemon-reload
      echo "CUPS enabled."
      echo "avahi-daemon is unmasked & will be started as needed on an on-demand basis."
      echo "Note: cups-browsed, the printer discovery service, is still disabled for"
      echo "    security reasons. New network printers will need to be added manually."
      echo "    If you absolutely need network discovery, you can enable the cups-browsed"
      echo "    service at your own risk. Secureblue strongly recommends against this."
    fi

# disable the webcam kernel module
disable-webcam:
    WEBCAM_MOD_FILE="/etc/modprobe.d/99-disable-webcam.conf"
    if [ -e "$WEBCAM_MOD_FILE" ]; then
      echo "Webcam module is already disabled."
    else
      echo "install uvcvideo /bin/false" > "$WEBCAM_MOD_FILE" 
      chmod 644 "$WEBCAM_MOD_FILE"
      echo "Override created to disable the webcam module. Reboot to take effect."
    fi

# reset the webcam kernel module
reset-webcam:
    WEBCAM_MOD_FILE="/etc/modprobe.d/99-disable-webcam.conf"
    rm -f "$WEBCAM_MOD_FILE"
    echo "Webcam module reset."

# Toggle debug mode (requires restart)
toggle-debug-mode:
    if test -e /etc/sysctl.d/99-enable-coredump.conf; then
        cp /usr/etc/security/limits.d/60-disable-coredump.conf /etc/security/limits.d/60-disable-coredump.conf
        cp /usr/etc/systemd/system.conf.d/60-disable-coredump.conf /etc/systemd/system.conf.d/60-disable-coredump.conf
        cp /usr/etc/systemd/user.conf.d/60-disable-coredump.conf /etc/systemd/user.conf.d/60-disable-coredump.conf
        rm /etc/sysctl.d/99-enable-coredump.conf
        echo "Debug mode disabled."
    else
        rm /etc/security/limits.d/60-disable-coredump.conf
        rm /etc/systemd/system.conf.d/60-disable-coredump.conf
        rm /etc/systemd/user.conf.d/60-disable-coredump.conf
        echo "kernel.core_pattern = |/usr/lib/systemd/systemd-coredump %P %u %g %s %t %c %h" >/etc/sysctl.d/99-enable-coredump.conf
        echo "Debug mode enabled."
        if [[ $(</proc/sys/kernel/yama/ptrace_scope) != 1 ]]; then
            echo "ptrace is restricted in this session. Some debuggers may not work as intended. Use ujust toggle-ptrace-scope to manage ptrace."
        fi
    fi

alias toggle-ptrace-scope := toggle-anticheat-support

# Toggle anticheat support by changing ptrace scope (requires restart)
toggle-anticheat-support:
    SYSCTL_HARDENING_FILE="/etc/sysctl.d/60-hardening.conf"
    if grep -q '^kernel.yama.ptrace_scope = 3' "$SYSCTL_HARDENING_FILE"; then
        sed -i 's/^kernel.yama.ptrace_scope =.*/kernel.yama.ptrace_scope = 1/' "$SYSCTL_HARDENING_FILE"
        echo "Anticheat support enabled. ptrace_scope set to 1."
    elif grep -q 'kernel.yama.ptrace_scope = 1' "$SYSCTL_HARDENING_FILE"; then
        sed -i 's/^kernel.yama.ptrace_scope =.*/kernel.yama.ptrace_scope = 3/' "$SYSCTL_HARDENING_FILE"
        echo "Anticheat support disabled. ptrace_scope set back to 3."
    else
        echo "The sysctl hardening file is missing the ptrace_scope setting."
    fi

# Toggle unconfined domain userns creation
toggle-unconfined-domain-userns-creation:
    set -euo pipefail
    MODULE_NAME="harden_userns"

    if semodule -l | grep -q "$MODULE_NAME"; then
        echo "Module $MODULE_NAME is currently enabled. Disabling the hardening, enabling unconfined domain userns (e.g. for bubblejail)."
        semodule --disable="$MODULE_NAME"
        echo "Module $MODULE_NAME disabled. Unconfined domain userns enabled."
    else
        echo "Module $MODULE_NAME is not currently enabled. Enabling the hardening, disabling unconfined domain userns (e.g. for bubblejail)."
        semodule --enable="$MODULE_NAME"
        echo "Module $MODULE_NAME enabled. Unconfined domain userns disabled."
    fi

# Toggle container domain userns creation
toggle-container-domain-userns-creation:
    set -euo pipefail
    MODULE_NAME="harden_container_userns"

    if semodule -l | grep -q "$MODULE_NAME"; then
        echo "Module $MODULE_NAME is currently enabled. Disabling the hardening, enabling container domain userns (e.g. for distrobox)."
        semodule --disable="$MODULE_NAME"
        echo "Module $MODULE_NAME disabled. Container domain userns enabled."
    else
        echo "Module $MODULE_NAME is not currently enabled. Enabling the hardening, disabling container domain userns (e.g. for distrobox)."

        echo 'Warning: This will stop ALL containers and shut down podman.'
        read -rp 'Are you sure you want to do this? (y/N) ' proceed
        if ! [[ "$proceed" == [Yy]* ]]; then
            echo "Aborting..."
            exit 0
        fi

        semodule --enable="$MODULE_NAME"
        echo "Module $MODULE_NAME enabled. Container domain userns disabled."

        echo 'Stopping all containers and shutting down podman...'
        run0 --user="$SUDO_USER" podman stop --all > /dev/null
        killall -u "$SUDO_USER" catatonit || true
        echo 'podman has been shut down.'

        if pgrep -u root -a -x catatonit &> /dev/null; then
            echo 'WARNING: Catatonit running as root detected, reboot your machine to reset podman state.'
        fi
    fi

# Toggle MAC Randomization
toggle-mac-randomization:
    RAND_MAC_FILE="/etc/NetworkManager/conf.d/rand_mac.conf"

    if test -e $RAND_MAC_FILE; then
        rm -f $RAND_MAC_FILE
        echo "MAC randomization disabled."
        systemctl restart NetworkManager
    else
        echo "MAC randomization can be stable (persisting the same random MAC per access point across disconnects/reboots),"
        echo "or it can be randomized per-connection (every time it connects to the same access point it uses a new MAC)."
        randomization_choice=""
        read -rp "Do you want to use per-connection Wi-Fi MAC address randomization? [y/N] " randomization_choice

        if [[ "$randomization_choice" == [Yy]* ]]; then
            randomization_level=random
            echo "Selected state: per-connection"
        else
            randomization_level=stable
            echo "Selected state: per-network (stable)"
        fi
        cat <<EOL > $RAND_MAC_FILE
    [device-mac-randomization]
    # "yes" is already the default for scanning
    wifi.scan-rand-mac-address=yes

    [connection-mac-randomization]
    # Generate a random MAC for each Network and associate the two permanently.
    ethernet.cloned-mac-address=stable
    wifi.cloned-mac-address=$randomization_level
    EOL
        chmod 644 $RAND_MAC_FILE
        echo "MAC randomization enabled."
        systemctl restart NetworkManager
    fi
