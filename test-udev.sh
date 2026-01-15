#!/bin/bash

# USB Device Detection Debugger
# Run this to see what's happening with USB detection

echo "=== USB Device Detection Debugger ==="
echo ""

echo "1. Current USB devices detected by lsblk:"
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT,TYPE | grep -E "sd[a-z]|NAME"
echo ""

echo "2. Checking udev rule..."
if [ -f /etc/udev/rules.d/99-ingest-usb.rules ]; then
    echo "   Rule exists:"
    cat /etc/udev/rules.d/99-ingest-usb.rules
else
    echo "   ✗ Rule file missing!"
fi
echo ""

echo "3. Checking auto-scan status..."
/usr/local/bin/ingest-control.sh status-auto
echo ""

echo "4. Test manual trigger (simulating USB event)..."
echo "   Testing with first available USB device..."

# Find first USB storage device
USB_DEV=$(lsblk -o NAME,TYPE | grep "part" | grep "sd" | head -1 | awk '{print $1}')

if [ -n "$USB_DEV" ]; then
    echo "   Found device: $USB_DEV"
    echo "   Triggering manually..."
    /usr/local/bin/ingest-trigger.sh "$USB_DEV"
    echo ""
    echo "   Check trigger log:"
    tail -5 /var/log/ingest/trigger.log
else
    echo "   No USB devices found to test with"
fi
echo ""

echo "5. Real-time udev monitoring (press Ctrl+C to stop):"
echo "   Unplug your USB drive, then plug it back in..."
echo ""

# Only run udevadm if it exists
if command -v udevadm &> /dev/null; then
    udevadm monitor --kernel --property --subsystem-match=block
else
    echo "   udevadm not available (might be in container)"
    echo ""
    echo "   On Raspberry Pi, run this to monitor USB events:"
    echo "   sudo udevadm monitor --kernel --property --subsystem-match=block"
fi
