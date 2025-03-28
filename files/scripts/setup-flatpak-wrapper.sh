#!/bin/bash

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Step 1: Copy /usr/bin/flatpak to /usr/bin/flatpak.real
echo "Copying /usr/bin/flatpak to /usr/bin/flatpak.real..."
cp /usr/bin/flatpak /usr/bin/flatpak.real

# Step 2: Replace /usr/bin/flatpak with the wrapper script entirely
echo "Replacing /usr/bin/flatpak with the wrapper script..."

cat > /usr/bin/flatpak << 'EOF'
#!/bin/bash
# If a system operation is requested, block it.
if [[ "$@" == *"--system"* ]]; then
    echo "System-wide Flatpak installations are disabled."
    exit 1
fi

# Pass all other arguments to the real flatpak command
/usr/bin/flatpak.real "$@"
EOF

# Step 3: Make the wrapper script executable
echo "Making the wrapper script executable..."
chmod +x /usr/bin/flatpak

# Confirm the changes
echo "Flatpak wrapper script has been set up successfully!"