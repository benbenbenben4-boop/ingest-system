# Quick Start Guide

Get your ingest system up and running in 5 minutes!

## Installation (Choose One)

### Option A: With Setup File (Recommended)

No repeated prompts - configure once, use forever!

```bash
cd ~/ingest-system

# Create setup file
cp setup.conf.example setup.conf
nano setup.conf  # Fill in your NAS and dashboard details
chmod 600 setup.conf

# Install automatically
sudo ./install.sh
```

### Option B: Interactive Install

Answer prompts during installation:

```bash
cd ~/ingest-system
chmod +x install.sh
sudo ./install.sh
```

You'll be asked for:
1. NAS IP/hostname
2. NAS share name
3. NAS username/password
4. Dashboard username/password

## Access Dashboard

```
http://raspberrypi.local:4666
```

## How It Works

### Automatic Mode (Default)
1. Plug in USB drive → Auto-scan starts immediately
2. Files copied to NAS
3. Checksums verified
4. Drive wiped securely
5. Done!

### Manual Mode
1. Toggle "Auto-Scan" OFF in dashboard
2. Plug in USB drives (nothing happens yet)
3. Select drive from dropdown
4. Click "Start Scan"

## Common Commands

```bash
# Check if services are running
sudo systemctl status ingest-dashboard ingest-monitor

# View live logs
sudo journalctl -u ingest-dashboard -f
sudo tail -f /var/log/ingest/trigger.log

# Enable/disable auto-scan
sudo /usr/local/bin/ingest-control.sh enable-auto
sudo /usr/local/bin/ingest-control.sh disable-auto

# List USB devices
sudo /usr/local/bin/ingest-control.sh list-devices

# Manual scan
sudo /usr/local/bin/ingest-control.sh manual-scan /dev/sda1

# Stop current transfer
sudo /usr/local/bin/ingest-control.sh stop

# Check NAS mount
df -h | grep ingest
```

## Troubleshooting

### Can't access dashboard?
```bash
sudo systemctl restart ingest-dashboard
```

### NAS not mounted?
```bash
sudo mount /mnt/ingest
```

### USB not auto-detected?
```bash
# Check auto-scan is enabled
ls /var/run/ingest/auto_scan_enabled

# Enable it
sudo touch /var/run/ingest/auto_scan_enabled

# Check logs
sudo tail -f /var/log/ingest/trigger.log
```

### Transfer stuck?
```bash
# Stop it manually
sudo pkill -f ingest-drive.sh
```

## File Locations

- **Ingested files:** `/mnt/ingest/YYYY-MM-DD_HH-MM-SS/`
- **System logs:** `/var/log/ingest/system.log`
- **Trigger logs:** `/var/log/ingest/trigger.log`
- **Scripts:** `/usr/local/bin/ingest-*.sh`
- **Dashboard:** `/opt/ingest-dashboard/`

## Features

✓ **Auto-Scan Toggle** - Enable/disable automatic mode
✓ **Manual Controls** - Select and scan specific drives
✓ **Stop Transfer** - Cancel at any time
✓ **Delete Folders** - Remove ingests from dashboard
✓ **Real-time Progress** - Live file counts and percentages
✓ **Trash Exclusion** - Skips hidden files and .Trashes
✓ **SHA256 Verification** - Checksums before wiping
✓ **Secure Wipe** - Overwrites with zeros after verification

## What Gets Excluded?

- Hidden files (anything starting with `.`)
- `.Trashes` (Mac trash)
- `.Spotlight-V100` (Mac search index)
- `.fseventsd` (Mac filesystem events)
- `System Volume Information` (Windows)
- `$RECYCLE.BIN` (Windows recycle bin)

## Safety Features

- **SD Card Protection** - Won't process Pi's SD card
- **Space Check** - Verifies NAS has enough space
- **Verification First** - Only wipes after successful checksum
- **Stop Without Wipe** - Stopped transfers don't wipe the drive

## Workflows

### Workflow 1: Set and Forget
1. Leave auto-scan enabled
2. Plug in drives
3. Walk away

### Workflow 2: Review Before Ingest
1. Disable auto-scan
2. Plug in drive
3. Browse files on drive
4. Start scan from dashboard when ready

### Workflow 3: Batch Processing
1. Disable auto-scan
2. Plug in multiple drives
3. Process them one by one from dashboard

## API Access (Advanced)

```bash
# Enable auto-scan
curl -X POST http://raspberrypi.local:4666/api/control/auto-scan \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"action": "enable"}'

# Start manual scan
curl -X POST http://raspberrypi.local:4666/api/control/manual-scan \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"device": "/dev/sda1"}'

# Stop transfer
curl -X POST http://raspberrypi.local:4666/api/control/stop \
  -u username:password

# Get status
curl http://raspberrypi.local:4666/api/status -u username:password
```

## Need Help?

Full documentation: `INSTALL.md`

Check logs:
```bash
sudo journalctl -u ingest-dashboard -n 100
sudo tail -50 /var/log/ingest/system.log
```

---

**Happy ingesting!** 🚀
