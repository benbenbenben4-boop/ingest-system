#!/bin/bash

# Real USB Detection Test
# Run this to verify udev is actually triggering on USB events

echo "=== Real USB Detection Test ==="
echo ""
echo "This will help diagnose if udev is firing the trigger script."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

echo "1. Current setup:"
echo "   Auto-scan: $(/usr/local/bin/ingest-control.sh status-auto)"
echo "   Udev rule: $([ -f /etc/udev/rules.d/99-ingest-usb.rules ] && echo 'exists' || echo 'MISSING')"
echo ""

echo "2. Currently connected USB storage devices:"
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT,TYPE | grep -E "NAME|sd[a-z]"
echo ""

echo "3. Setting up monitoring..."
echo "   Watching: /var/log/ingest/trigger.log"
echo "   Press Ctrl+C to stop"
echo ""
echo "   >>> NOW UNPLUG YOUR USB DRIVE <<<"
echo "   >>> WAIT 5 SECONDS <<<"
echo "   >>> THEN PLUG IT BACK IN <<<"
echo ""
echo "   You should see activity below..."
echo ""
echo "----------------------------------------"

# Clear any old log entries from last 2 seconds
TIMESTAMP=$(date +%s)

# Monitor the log file for new entries
tail -f /var/log/ingest/trigger.log 2>/dev/null &
TAIL_PID=$!

# Also monitor udev events if available
if command -v udevadm &> /dev/null; then
    echo ""
    echo "Also monitoring udev events (raw):"
    echo ""
    udevadm monitor --kernel --subsystem-match=block &
    UDEV_PID=$!
else
    UDEV_PID=""
fi

# Wait for Ctrl+C
wait $TAIL_PID

# Cleanup
if [ -n "$UDEV_PID" ]; then
    kill $UDEV_PID 2>/dev/null
fi
