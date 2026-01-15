# Installation Instructions - Ingest System V2

Complete guide to set up the automated USB drive ingest system on your Raspberry Pi.

## Requirements

- **Hardware:**
  - Raspberry Pi 4 (recommended) or Pi 3B+
  - MicroSD card (16GB minimum)
  - Network connection (Ethernet recommended)
  - USB ports for drives

- **Network:**
  - NAS/SMB share accessible on the network
  - Static IP recommended for both Pi and NAS

- **Software:**
  - Raspberry Pi OS (Lite or Desktop)
  - Root access (sudo)

## Quick Start

### 1. Clone or Copy Files

```bash
# SSH into your Raspberry Pi
ssh pi@raspberrypi.local

# Copy the ingest-system folder to your Pi
# (Use scp, git clone, or USB transfer)
cd ~
```

### 2. Run Installation Script

```bash
cd ingest-system
chmod +x install.sh
sudo ./install.sh
```

The installer will ask you for:
- **NAS IP/hostname** (e.g., `192.168.1.100` or `nas.local`)
- **NAS share name** (e.g., `ingest`)
- **NAS username and password**
- **Dashboard username and password**

### 3. Access Dashboard

Once installed, open your browser:
```
http://raspberrypi.local:4666
```

Or use the IP address:
```
http://[YOUR_PI_IP]:4666
```

## What the Installer Does

The installation script automatically:

1. ✓ Installs required packages (Python, Flask, rsync, filesystem tools)
2. ✓ Creates directory structure
3. ✓ Installs ingest scripts to `/usr/local/bin/`
4. ✓ Sets up web dashboard in `/opt/ingest-dashboard/`
5. ✓ Creates authentication for dashboard
6. ✓ Configures NAS mount in `/etc/fstab`
7. ✓ Creates udev rule for automatic USB detection
8. ✓ Sets up systemd services (auto-start on boot)
9. ✓ Enables auto-scan by default
10. ✓ Starts all services

## Post-Installation

### Verify Services Are Running

```bash
# Check dashboard service
sudo systemctl status ingest-dashboard

# Check monitor service
sudo systemctl status ingest-monitor

# View real-time logs
sudo journalctl -u ingest-dashboard -f
```

### Verify NAS Mount

```bash
# Check if NAS is mounted
df -h | grep ingest

# Or
mount | grep /mnt/ingest

# Manual mount if needed
sudo mount /mnt/ingest
```

### Test with a USB Drive

1. Plug in a USB drive
2. Check logs: `sudo tail -f /var/log/ingest/trigger.log`
3. Watch dashboard: `http://raspberrypi.local:4666`

### Configure Static IP (Recommended)

Edit `/etc/dhcpcd.conf`:
```bash
sudo nano /etc/dhcpcd.conf
```

Add at the end:
```
interface eth0
static ip_address=192.168.1.50/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
```

Reboot:
```bash
sudo reboot
```

## Manual Controls

### Enable/Disable Auto-Scan

```bash
# Enable auto-scan (automatic ingesting when drives are plugged in)
sudo /usr/local/bin/ingest-control.sh enable-auto

# Disable auto-scan (require manual trigger from dashboard)
sudo /usr/local/bin/ingest-control.sh disable-auto

# Check status
sudo /usr/local/bin/ingest-control.sh status-auto
```

### Manual Scan

```bash
# List connected USB devices
sudo /usr/local/bin/ingest-control.sh list-devices

# Start manual scan on specific device
sudo /usr/local/bin/ingest-control.sh manual-scan /dev/sda1
```

### Stop Transfer

```bash
# Stop current ingest process
sudo /usr/local/bin/ingest-control.sh stop
```

### Delete Folder

```bash
# Delete an ingest folder from NAS
sudo /usr/local/bin/ingest-control.sh delete-folder 2026-01-15_13-30-45
```

## Directory Structure

```
/usr/local/bin/
  ├── ingest-drive.sh       # Main ingest script
  ├── ingest-trigger.sh     # USB detection trigger
  └── ingest-control.sh     # Control commands

/opt/ingest-dashboard/
  ├── dashboard.py          # Flask web app
  └── templates/
      └── index.html        # Dashboard UI

/etc/ingest/
  ├── dashboard.htpasswd    # Dashboard credentials
  └── nas-credentials       # NAS mount credentials

/var/run/ingest/
  ├── auto_scan_enabled     # Auto-scan flag file
  ├── current.json          # Current status
  ├── stop_request          # Stop signal file
  └── manual_scan_request   # Manual scan signal

/var/log/ingest/
  ├── system.log            # System log
  └── trigger.log           # USB detection log

/mnt/ingest/                # NAS mount point (ingest destination)
/mnt/usb_drive/             # USB drive mount point (temporary)
```

## Troubleshooting

### Dashboard Not Accessible

```bash
# Check if service is running
sudo systemctl status ingest-dashboard

# Restart service
sudo systemctl restart ingest-dashboard

# Check logs
sudo journalctl -u ingest-dashboard -n 50

# Check if port is listening
sudo netstat -tlnp | grep 4666
```

### NAS Not Mounting

```bash
# Check NAS connectivity
ping [NAS_IP]

# Test SMB connection
smbclient -L //[NAS_IP] -U [username]

# Check credentials
cat /etc/ingest/nas-credentials

# Try manual mount
sudo mount -t cifs //[NAS_IP]/[share] /mnt/ingest -o credentials=/etc/ingest/nas-credentials

# Check fstab entry
grep ingest /etc/fstab
```

### USB Drive Not Auto-Detected

```bash
# Check udev rule
cat /etc/udev/rules.d/99-ingest-usb.rules

# Reload udev rules
sudo udevadm control --reload-rules

# Test udev rule (plug in USB, then run)
sudo udevadm monitor --environment --udev

# Check trigger log
sudo tail -f /var/log/ingest/trigger.log
```

### Auto-Scan Not Working

```bash
# Check if auto-scan is enabled
ls -la /var/run/ingest/auto_scan_enabled

# Enable it manually
sudo touch /var/run/ingest/auto_scan_enabled

# Check trigger script
sudo /usr/local/bin/ingest-trigger.sh sda1
```

### Ingest Process Stuck

```bash
# Check running processes
ps aux | grep ingest

# Stop manually
sudo pkill -f ingest-drive.sh

# Remove stop request file if stuck
sudo rm -f /var/run/ingest/stop_request

# Check system log
sudo tail -50 /var/log/ingest/system.log
```

### Permissions Issues

```bash
# Fix permissions on directories
sudo chmod 755 /var/run/ingest
sudo chmod 755 /var/log/ingest
sudo chmod 777 /mnt/ingest
sudo chmod 755 /mnt/usb_drive

# Fix script permissions
sudo chmod +x /usr/local/bin/ingest-*.sh
```

## Upgrade from V1

If you're upgrading from an existing V1 installation:

```bash
cd ingest-system
chmod +x upgrade.sh
sudo ./upgrade.sh
```

The upgrade script will:
- Backup old files
- Install new versions
- Keep your existing configuration
- Enable auto-scan by default

## Uninstall

To completely remove the ingest system:

```bash
# Stop services
sudo systemctl stop ingest-dashboard
sudo systemctl stop ingest-monitor

# Disable services
sudo systemctl disable ingest-dashboard
sudo systemctl disable ingest-monitor

# Remove service files
sudo rm /etc/systemd/system/ingest-dashboard.service
sudo rm /etc/systemd/system/ingest-monitor.service
sudo systemctl daemon-reload

# Remove scripts
sudo rm /usr/local/bin/ingest-*.sh

# Remove dashboard
sudo rm -rf /opt/ingest-dashboard

# Remove udev rule
sudo rm /etc/udev/rules.d/99-ingest-usb.rules
sudo udevadm control --reload-rules

# Remove fstab entry
sudo sed -i '/\/mnt\/ingest/d' /etc/fstab

# Remove directories (CAREFUL: this will delete logs)
sudo rm -rf /var/run/ingest
sudo rm -rf /var/log/ingest
sudo rm -rf /etc/ingest

# Unmount NAS
sudo umount /mnt/ingest
```

## Security Notes

- Dashboard uses HTTP basic authentication
- NAS credentials stored in `/etc/ingest/nas-credentials` (mode 600)
- Dashboard password file in `/etc/ingest/dashboard.htpasswd`
- All scripts run as root (required for mounting/wiping drives)
- Consider using HTTPS reverse proxy (nginx/apache) for production

## Advanced Configuration

### Change Dashboard Port

Edit `/etc/systemd/system/ingest-dashboard.service` and modify `dashboard.py` to use a different port, then:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ingest-dashboard
```

### Change NAS Mount

Edit `/etc/fstab` and `/etc/ingest/nas-credentials`, then:
```bash
sudo umount /mnt/ingest
sudo mount /mnt/ingest
```

### Customize Ingest Scripts

Edit scripts in `/usr/local/bin/`:
- `ingest-drive.sh` - Main logic
- `ingest-trigger.sh` - Auto-trigger behavior
- `ingest-control.sh` - Control commands

After editing:
```bash
sudo systemctl restart ingest-monitor
```

## Support

For issues, check:
1. System logs: `/var/log/ingest/system.log`
2. Trigger logs: `/var/log/ingest/trigger.log`
3. Dashboard logs: `sudo journalctl -u ingest-dashboard -n 50`
4. Service status: `sudo systemctl status ingest-*`

## Features

### Auto-Scan Toggle
Enable/disable automatic ingesting when drives are plugged in

### Manual Scan
Select specific drives and start ingesting on demand

### Stop Transfer
Cancel ongoing transfers at any time (drive will NOT be wiped)

### Delete Folder
Remove ingest folders directly from the dashboard

### Trash Exclusion
Automatically skips hidden files, .Trashes, and system folders

### SD Card Protection
Refuses to process the Raspberry Pi's SD card

### Real-time Progress
Live progress tracking with file counts and percentages

### SHA256 Verification
Checksums calculated and verified before wiping

### Secure Wiping
Single-pass overwrite with zeros after successful verification

---

**Enjoy your automated ingest system!** 🚀
