#!/bin/bash

# Upgrade Script for Ingest System V2
# Adds manual controls and auto-scan toggle

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo "  Ingest System V2 Upgrade"
echo "  Adding Manual Controls & Auto-Scan Toggle"
echo "================================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${GREEN}[1/6]${NC} Stopping services..."
systemctl stop ingest-dashboard
systemctl stop ingest-monitor

echo -e "${GREEN}[2/6]${NC} Backing up old files..."
mkdir -p /root/ingest-backup-$(date +%Y%m%d_%H%M%S)
cp /usr/local/bin/ingest-drive.sh /root/ingest-backup-$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
cp /usr/local/bin/ingest-trigger.sh /root/ingest-backup-$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
cp /opt/ingest-dashboard/dashboard.py /root/ingest-backup-$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true

echo -e "${GREEN}[3/6]${NC} Installing updated scripts..."
cp "$SCRIPT_DIR/ingest-drive.sh" /usr/local/bin/
cp "$SCRIPT_DIR/ingest-trigger.sh" /usr/local/bin/
cp "$SCRIPT_DIR/ingest-control.sh" /usr/local/bin/
chmod +x /usr/local/bin/ingest-drive.sh
chmod +x /usr/local/bin/ingest-trigger.sh
chmod +x /usr/local/bin/ingest-control.sh

echo -e "${GREEN}[4/6]${NC} Installing updated dashboard..."
cp "$SCRIPT_DIR/dashboard.py" /opt/ingest-dashboard/
cp "$SCRIPT_DIR/templates/index.html" /opt/ingest-dashboard/templates/

echo -e "${GREEN}[5/6]${NC} Enabling auto-scan by default..."
mkdir -p /var/run/ingest
touch /var/run/ingest/auto_scan_enabled

echo -e "${GREEN}[6/6]${NC} Starting services..."
systemctl start ingest-monitor
systemctl start ingest-dashboard

# Wait for services to start
sleep 2

echo ""
echo "================================================"
echo "  Upgrade Complete!"
echo "================================================"
echo ""

# Get IP address
IP_ADDR=$(hostname -I | awk '{print $1}')

echo "New Features:"
echo "  ✓ Auto-Scan toggle (enable/disable automatic ingesting)"
echo "  ✓ Manual scan button (scan specific drives on demand)"
echo "  ✓ Stop transfer button (cancel ongoing transfers)"
echo "  ✓ Delete folder button (remove ingests from NAS)"
echo "  ✓ Timestamp with time (folders named YYYY-MM-DD_HH-MM-SS)"
echo "  ✓ Trash exclusion (skips .Trashes, hidden files, system folders)"
echo ""
echo "Dashboard: http://$IP_ADDR:4666"
echo ""
echo "Auto-scan is ENABLED by default."
echo "Use the toggle in the dashboard to disable it."
echo ""
echo "================================================"
