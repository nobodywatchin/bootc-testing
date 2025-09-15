# Toggle unconfined domain userns creation
toggle-unconfined-domain-userns-creation:
    #! /bin/run0 /bin/bash
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
    #! /bin/run0 /bin/bash
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

# Toggle debug mode (requires restart)
toggle-debug-mode:
    #! /bin/run0 /bin/bash
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