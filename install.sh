#!/bin/bash

# Full Installation Script for Ingest System V2
# Sets up automated USB drive ingest system on Raspberry Pi

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================"
echo "  Ingest System V2 - Full Installation"
echo "  Automated USB Drive → NAS Ingest System"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check for setup.conf file
SETUP_CONF="$SCRIPT_DIR/setup.conf"
if [ -f "$SETUP_CONF" ]; then
    echo -e "${GREEN}Found setup.conf - loading configuration...${NC}"
    source "$SETUP_CONF"

    # Validate required fields are filled
    if [ -z "$NAS_HOST" ] || [ -z "$NAS_SHARE" ] || [ -z "$NAS_USER" ] || [ -z "$NAS_PASS" ] || [ -z "$DASH_USER" ] || [ -z "$DASH_PASS" ]; then
        echo -e "${RED}Error: setup.conf is incomplete!${NC}"
        echo "Please fill in all required fields in setup.conf:"
        echo "  - NAS_HOST, NAS_SHARE, NAS_USER, NAS_PASS"
        echo "  - DASH_USER, DASH_PASS"
        exit 1
    fi

    echo -e "${GREEN}✓ NAS: $NAS_USER@$NAS_HOST/$NAS_SHARE${NC}"
    echo -e "${GREEN}✓ Dashboard: $DASH_USER${NC}"
    echo ""
else
    echo -e "${YELLOW}No setup.conf found - using interactive mode${NC}"
    echo -e "${BLUE}Tip: Create setup.conf to skip prompts in future (see setup.conf.example)${NC}"
    echo ""

    # Get NAS configuration from user
    echo -e "${BLUE}NAS Configuration${NC}"
    echo "Please provide your NAS details:"
    read -p "NAS IP address or hostname: " NAS_HOST
    read -p "NAS share name (e.g., ingest): " NAS_SHARE
    read -p "NAS username: " NAS_USER
    read -sp "NAS password: " NAS_PASS
    echo ""
    echo ""

    # Get dashboard credentials
    echo -e "${BLUE}Dashboard Configuration${NC}"
    read -p "Dashboard username: " DASH_USER
    read -sp "Dashboard password: " DASH_PASS
    echo ""
    echo ""
fi

echo "================================================"
echo "  Starting Installation"
echo "================================================"
echo ""

# Step 1: Install required packages
echo -e "${GREEN}[1/12]${NC} Installing required packages..."
echo "This may take a few minutes..."
apt-get update
apt-get install -y \
    python3-pip \
    python3-flask \
    python3-flask-httpauth \
    apache2-utils \
    rsync \
    ntfs-3g \
    exfat-fuse \
    exfatprogs \
    cifs-utils \
    parted

echo -e "${GREEN}[2/12]${NC} Creating directory structure..."
mkdir -p /var/run/ingest
mkdir -p /var/log/ingest
mkdir -p /mnt/ingest
mkdir -p /mnt/usb_drive
mkdir -p /etc/ingest
mkdir -p /opt/ingest-dashboard
mkdir -p /opt/ingest-dashboard/templates

# Step 3: Install scripts and config
echo -e "${GREEN}[3/12]${NC} Installing ingest scripts..."
cp "$SCRIPT_DIR/ingest-drive.sh" /usr/local/bin/
cp "$SCRIPT_DIR/ingest-trigger.sh" /usr/local/bin/
cp "$SCRIPT_DIR/ingest-control.sh" /usr/local/bin/
chmod +x /usr/local/bin/ingest-drive.sh
chmod +x /usr/local/bin/ingest-trigger.sh
chmod +x /usr/local/bin/ingest-control.sh

# Install config file (don't overwrite if exists)
if [ ! -f /etc/ingest/ingest.conf ]; then
    cp "$SCRIPT_DIR/ingest.conf" /etc/ingest/

    # If WIPE_MODE was set in setup.conf, apply it
    if [ -n "$WIPE_MODE" ]; then
        sed -i "s/^SKIP_WIPE=.*/SKIP_WIPE=$WIPE_MODE/" /etc/ingest/ingest.conf
        echo -e "${GREEN}✓ Wipe mode set to: $WIPE_MODE${NC}"
    fi
fi

# Step 4: Install dashboard
echo -e "${GREEN}[4/12]${NC} Installing dashboard..."
cp "$SCRIPT_DIR/dashboard.py" /opt/ingest-dashboard/
cp "$SCRIPT_DIR/templates/index.html" /opt/ingest-dashboard/templates/
chmod +x /opt/ingest-dashboard/dashboard.py

# Step 5: Create dashboard credentials
echo -e "${GREEN}[5/12]${NC} Setting up dashboard authentication..."
htpasswd -cb /etc/ingest/dashboard.htpasswd "$DASH_USER" "$DASH_PASS"

# Step 6: Create NAS mount credentials
echo -e "${GREEN}[6/12]${NC} Configuring NAS connection..."
cat > /etc/ingest/nas-credentials << EOF
username=$NAS_USER
password=$NAS_PASS
EOF
chmod 600 /etc/ingest/nas-credentials

# Step 7: Configure NAS mount in fstab
echo -e "${GREEN}[7/12]${NC} Adding NAS to fstab..."
# Remove any existing ingest mount entry
sed -i '/\/mnt\/ingest/d' /etc/fstab

# Add new mount entry
echo "//$NAS_HOST/$NAS_SHARE /mnt/ingest cifs credentials=/etc/ingest/nas-credentials,uid=0,gid=0,file_mode=0777,dir_mode=0777,iocharset=utf8,_netdev 0 0" >> /etc/fstab

# Try to mount NAS
echo "Testing NAS connection..."
if mount /mnt/ingest 2>/dev/null; then
    echo -e "${GREEN}✓ NAS mounted successfully${NC}"
else
    echo -e "${YELLOW}⚠ Could not mount NAS now (it will be mounted on boot)${NC}"
fi

# Step 8: Create udev rule
echo -e "${GREEN}[8/12]${NC} Creating udev rule for automatic USB detection..."
cat > /etc/udev/rules.d/99-ingest-usb.rules << 'EOF'
# Ingest System - Auto-trigger on USB storage devices
# Triggers when a USB storage partition is added
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]*", ENV{ID_BUS}=="usb", RUN+="/usr/local/bin/ingest-trigger.sh %k"
EOF

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules 2>/dev/null || echo "udevadm not available"

# Trigger events for already-connected devices
echo "Triggering events for existing USB devices..."
udevadm trigger --subsystem-match=block --action=add 2>/dev/null || echo "udevadm trigger not available"

# Step 9: Create systemd service for dashboard
echo -e "${GREEN}[9/12]${NC} Creating systemd service for dashboard..."
cat > /etc/systemd/system/ingest-dashboard.service << 'EOF'
[Unit]
Description=Ingest Dashboard Web Interface
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ingest-dashboard
ExecStart=/usr/bin/python3 /opt/ingest-dashboard/dashboard.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Step 10: Create systemd service for monitoring
echo -e "${GREEN}[10/12]${NC} Creating systemd service for USB monitoring..."
cat > /etc/systemd/system/ingest-monitor.service << 'EOF'
[Unit]
Description=Ingest USB Monitor Service
After=multi-user.target

[Service]
Type=simple
ExecStart=/bin/bash -c "while true; do sleep 60; done"
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Step 11: Enable and start services
echo -e "${GREEN}[11/12]${NC} Enabling and starting services..."
systemctl daemon-reload
systemctl enable ingest-dashboard
systemctl enable ingest-monitor
systemctl start ingest-dashboard
systemctl start ingest-monitor

# Step 12: Enable auto-scan by default
echo -e "${GREEN}[12/12]${NC} Enabling auto-scan by default..."
touch /var/run/ingest/auto_scan_enabled

# Wait for services to start
sleep 2

echo ""
echo "================================================"
echo "  Installation Complete! ✓"
echo "================================================"
echo ""

# Get IP address
IP_ADDR=$(hostname -I | awk '{print $1}')

echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  IP Address: $IP_ADDR"
echo ""
echo "Dashboard Access:"
echo "  URL: http://$IP_ADDR:4666"
echo "  URL: http://$(hostname).local:4666"
echo "  Username: $DASH_USER"
echo "  Password: [hidden]"
echo ""
echo "Features Enabled:"
echo "  ✓ Auto-Scan (plug and go)"
echo "  ✓ Manual scan controls"
echo "  ✓ Stop transfer capability"
echo "  ✓ Delete folder controls"
echo "  ✓ Real-time progress tracking"
echo "  ✓ Checksum verification"
echo "  ✓ Secure drive wiping"
echo "  ✓ Trash file exclusion"
echo ""
echo "NAS Configuration:"
echo "  Host: $NAS_HOST"
echo "  Share: $NAS_SHARE"
echo "  Mount: /mnt/ingest"
echo ""
echo "How to Use:"
echo "  1. Plug in a USB drive"
echo "  2. System will automatically detect and start ingesting"
echo "  3. Monitor progress at http://$IP_ADDR:4666"
echo "  4. Toggle auto-scan on/off from the dashboard"
echo "  5. Use manual controls to scan specific drives"
echo ""
echo "Service Status:"
systemctl status ingest-dashboard --no-pager -l | grep Active
systemctl status ingest-monitor --no-pager -l | grep Active
echo ""
echo "Logs Location:"
echo "  System: /var/log/ingest/system.log"
echo "  Trigger: /var/log/ingest/trigger.log"
echo "  Dashboard: sudo journalctl -u ingest-dashboard -f"
echo ""
echo "================================================"
echo ""
echo -e "${GREEN}Ready to ingest!${NC}"
echo ""
