#!/bin/bash

# Quick Setup for Auto-Ingest
# Installs just the essential components for auto USB detection

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================"
echo "  Quick Setup - Auto-Ingest USB Detection"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}[1/5]${NC} Creating directories..."
mkdir -p /var/run/ingest
mkdir -p /var/log/ingest
mkdir -p /mnt/usb_drive

echo -e "${BLUE}[2/5]${NC} Installing scripts..."
cp "$SCRIPT_DIR/ingest-drive.sh" /usr/local/bin/
cp "$SCRIPT_DIR/ingest-trigger.sh" /usr/local/bin/
cp "$SCRIPT_DIR/ingest-control.sh" /usr/local/bin/
chmod +x /usr/local/bin/ingest-drive.sh
chmod +x /usr/local/bin/ingest-trigger.sh
chmod +x /usr/local/bin/ingest-control.sh

echo -e "${BLUE}[3/5]${NC} Creating udev rule for USB detection..."
cat > /etc/udev/rules.d/99-ingest-usb.rules << 'EOF'
# Ingest System - Auto-trigger on USB storage devices
# Triggers when a USB storage partition is added
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]*", ENV{ID_BUS}=="usb", RUN+="/usr/local/bin/ingest-trigger.sh %k"
EOF

echo -e "${BLUE}[4/5]${NC} Reloading udev rules..."
udevadm control --reload-rules 2>/dev/null || echo "udevadm not available"
udevadm trigger --subsystem-match=block --action=add 2>/dev/null || true

echo -e "${BLUE}[5/5]${NC} Enabling auto-scan..."
touch /var/run/ingest/auto_scan_enabled

echo ""
echo "================================================"
echo -e "${GREEN}  Auto-Ingest Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Testing:"
echo "  1. Check auto-scan status:"
echo "     sudo /usr/local/bin/ingest-control.sh status-auto"
echo ""
echo "  2. View trigger log:"
echo "     sudo tail -f /var/log/ingest/trigger.log"
echo ""
echo "  3. Plug in a USB drive and watch the log!"
echo ""
echo "To disable auto-scan:"
echo "  sudo /usr/local/bin/ingest-control.sh disable-auto"
echo ""
echo "To enable auto-scan:"
echo "  sudo /usr/local/bin/ingest-control.sh enable-auto"
echo ""
