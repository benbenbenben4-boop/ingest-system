#!/bin/bash

# Diagnostic Script for Auto-Ingest Issues
# Checks all components needed for automatic USB detection

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo "  Auto-Ingest Diagnostic Tool"
echo "================================================"
echo ""

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check 1: Scripts installed
echo "Checking scripts..."
if [ -f /usr/local/bin/ingest-drive.sh ] && [ -x /usr/local/bin/ingest-drive.sh ]; then
    check_pass "ingest-drive.sh is installed and executable"
else
    check_fail "ingest-drive.sh is missing or not executable"
fi

if [ -f /usr/local/bin/ingest-trigger.sh ] && [ -x /usr/local/bin/ingest-trigger.sh ]; then
    check_pass "ingest-trigger.sh is installed and executable"
else
    check_fail "ingest-trigger.sh is missing or not executable"
fi

if [ -f /usr/local/bin/ingest-control.sh ] && [ -x /usr/local/bin/ingest-control.sh ]; then
    check_pass "ingest-control.sh is installed and executable"
else
    check_fail "ingest-control.sh is missing or not executable"
fi

echo ""

# Check 2: Udev rule
echo "Checking udev rule..."
if [ -f /etc/udev/rules.d/99-ingest-usb.rules ]; then
    check_pass "Udev rule exists: /etc/udev/rules.d/99-ingest-usb.rules"
    echo "   Rule content:"
    cat /etc/udev/rules.d/99-ingest-usb.rules | sed 's/^/   /'
else
    check_fail "Udev rule is missing: /etc/udev/rules.d/99-ingest-usb.rules"
fi

echo ""

# Check 3: Auto-scan flag
echo "Checking auto-scan status..."
if [ -f /var/run/ingest/auto_scan_enabled ]; then
    check_pass "Auto-scan is ENABLED"
else
    check_warn "Auto-scan is DISABLED (manual mode)"
    echo "   Enable with: sudo /usr/local/bin/ingest-control.sh enable-auto"
fi

echo ""

# Check 4: Directories
echo "Checking directories..."
if [ -d /var/run/ingest ]; then
    check_pass "/var/run/ingest exists"
else
    check_fail "/var/run/ingest is missing"
fi

if [ -d /var/log/ingest ]; then
    check_pass "/var/log/ingest exists"
else
    check_fail "/var/log/ingest is missing"
fi

if [ -d /mnt/usb_drive ]; then
    check_pass "/mnt/usb_drive exists"
else
    check_fail "/mnt/usb_drive is missing"
fi

if [ -d /mnt/ingest ]; then
    check_pass "/mnt/ingest exists"
    if mountpoint -q /mnt/ingest; then
        check_pass "NAS is mounted"
    else
        check_warn "NAS is not mounted"
    fi
else
    check_warn "/mnt/ingest is missing"
fi

echo ""

# Check 5: Recent logs
echo "Checking recent logs..."
if [ -f /var/log/ingest/trigger.log ]; then
    check_pass "Trigger log exists"
    echo ""
    echo "Last 5 trigger events:"
    tail -5 /var/log/ingest/trigger.log 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
else
    check_warn "No trigger log yet (no USB events detected)"
fi

echo ""

# Check 6: USB devices
echo "Checking for USB storage devices..."
USB_DEVICES=$(lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT 2>/dev/null | grep -E "sd[a-z]" || echo "")
if [ -n "$USB_DEVICES" ]; then
    check_pass "USB devices detected:"
    echo "$USB_DEVICES" | sed 's/^/   /'
else
    check_warn "No USB storage devices currently connected"
fi

echo ""
echo "================================================"
echo "  Recommendations"
echo "================================================"
echo ""

# Provide recommendations
ISSUES=0

if [ ! -f /usr/local/bin/ingest-drive.sh ]; then
    echo "→ Install scripts: sudo ./quick-setup.sh"
    ISSUES=1
fi

if [ ! -f /etc/udev/rules.d/99-ingest-usb.rules ]; then
    echo "→ Create udev rule: sudo ./quick-setup.sh"
    ISSUES=1
fi

if [ ! -f /var/run/ingest/auto_scan_enabled ]; then
    echo "→ Enable auto-scan: sudo /usr/local/bin/ingest-control.sh enable-auto"
    ISSUES=1
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "To test:"
    echo "  1. Monitor logs: sudo tail -f /var/log/ingest/trigger.log"
    echo "  2. Plug in a USB drive"
    echo "  3. Watch for auto-detection messages"
    echo ""
    echo "If USB detection still doesn't work:"
    echo "  - Check kernel messages: sudo dmesg | tail -20"
    echo "  - Monitor udev events: sudo udevadm monitor"
    echo "  - Test trigger manually: sudo /usr/local/bin/ingest-trigger.sh sda1"
fi

echo ""
