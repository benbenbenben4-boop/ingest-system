#!/bin/bash

# Fix udev rule to be less strict
# Removes ID_BUS requirement which might not be set on all systems

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

echo "=== Fixing Udev Rule ==="
echo ""

echo "Creating more permissive udev rule..."
echo "(Removes ENV{ID_BUS}==usb requirement)"
echo ""

cat > /etc/udev/rules.d/99-ingest-usb.rules << 'EOF'
# Ingest System - Auto-trigger on USB storage devices
# Less strict rule - matches all sd* partitions
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]*", RUN+="/usr/local/bin/ingest-trigger.sh %k"
EOF

echo "New rule installed:"
cat /etc/udev/rules.d/99-ingest-usb.rules
echo ""

echo "Reloading udev rules..."
udevadm control --reload-rules

echo "Triggering events for connected devices..."
udevadm trigger --subsystem-match=block --action=add

echo ""
echo "✓ Done!"
echo ""
echo "Now monitor the log and replug your USB drive:"
echo "  tail -f /var/log/ingest/trigger.log"
echo ""
