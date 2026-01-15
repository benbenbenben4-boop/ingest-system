#!/bin/bash

# Simple verification script for Raspberry Pi
# Run this on your Pi to check if auto-ingest is ready

echo "=== Checking Auto-Ingest Setup ==="
echo ""

# Check 1: Directories
echo "1. Checking directories..."
if [ -d /var/log/ingest ] && [ -d /var/run/ingest ]; then
    echo "   ✓ Directories exist"
else
    echo "   ✗ Creating directories..."
    mkdir -p /var/log/ingest /var/run/ingest /mnt/usb_drive
    echo "   ✓ Directories created"
fi
echo ""

# Check 2: Scripts
echo "2. Checking scripts..."
if [ -f /usr/local/bin/ingest-trigger.sh ]; then
    echo "   ✓ Scripts installed"
else
    echo "   ✗ Scripts NOT installed - run: sudo ./install.sh"
fi
echo ""

# Check 3: Udev rule
echo "3. Checking udev rule..."
if [ -f /etc/udev/rules.d/99-ingest-usb.rules ]; then
    echo "   ✓ Udev rule exists"
else
    echo "   ✗ Udev rule missing - run: sudo ./install.sh"
fi
echo ""

# Check 4: Auto-scan enabled
echo "4. Checking auto-scan..."
if [ -f /var/run/ingest/auto_scan_enabled ]; then
    echo "   ✓ Auto-scan ENABLED"
else
    echo "   ✗ Auto-scan DISABLED"
    echo "   Enable with: sudo /usr/local/bin/ingest-control.sh enable-auto"
fi
echo ""

# Check 5: Create trigger log if missing
echo "5. Checking trigger log..."
if [ -f /var/log/ingest/trigger.log ]; then
    echo "   ✓ Log file exists"
    echo ""
    echo "   Last 5 entries:"
    tail -5 /var/log/ingest/trigger.log | sed 's/^/     /'
else
    echo "   ℹ Log file doesn't exist yet (normal - created on first USB event)"
    echo ""
    echo "   Creating test entry..."
    touch /var/log/ingest/trigger.log
    echo "[$(date)] System initialized - waiting for USB devices..." >> /var/log/ingest/trigger.log
    echo "   ✓ Log file created"
fi
echo ""

echo "=== Next Steps ==="
echo ""
echo "Monitor for USB events:"
echo "  tail -f /var/log/ingest/trigger.log"
echo ""
echo "Then plug in a USB drive!"
echo ""
