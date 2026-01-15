# Ingest System V2 - Manual Controls Update

## What's New in V2

### 🎮 Manual Controls
- **Auto-Scan Toggle**: Enable/disable automatic ingesting when drives are plugged in
- **Manual Scan Button**: Select a specific drive and start ingesting on demand
- **Stop Transfer Button**: Cancel ongoing transfers at any time
- **Delete Folder Button**: Remove ingest folders directly from the dashboard

### 📁 Better File Organization
- **Timestamp with Time**: Folders now named `YYYY-MM-DD_HH-MM-SS` (e.g., `2026-01-15_13-30-45`)
- **Trash Exclusion**: Automatically skips:
  - Hidden files (anything starting with `.`)
  - `.Trashes` folders
  - `.Spotlight-V100`
  - `.fseventsd`
  - System Volume Information
  - `$RECYCLE.BIN`

### 🛡️ Improved Safety
- **SD Card Protection**: Won't process the Raspberry Pi's SD card
- **Stop Capability**: Can safely stop transfers mid-process
- **Removable Check Bypass**: Works with SATA-to-USB adapters

---

## Installation

### For New Installs
Follow the original README.md instructions from the main ingest-system folder.

### For Existing Installs (Upgrade from V1)

```bash
# SSH into your Pi
ssh pi@ingest-pi.local

# Copy the V2 files to your Pi
scp -r ingest-system-v2 pi@ingest-pi.local:~/

# Run the upgrade script
cd ~/ingest-system-v2
chmod +x upgrade.sh
sudo ./upgrade.sh
```

The upgrade script will:
1. Stop existing services
2. Backup old files
3. Install updated scripts
4. Install new dashboard
5. Enable auto-scan by default
6. Restart services

---

## Using the New Features

### Auto-Scan Toggle

**When ENABLED** (default):
- Plug in any USB drive → automatic ingest starts immediately
- Works like the original system

**When DISABLED**:
- Plug in USB drives → nothing happens automatically
- You must manually select the drive and click "Start Scan"
- Useful when you want to plug in drives without processing them

### Manual Scan

1. Plug in your USB drive
2. Open dashboard: `http://ingest-pi.local:4666`
3. Select the drive from the dropdown
4. Click "Start Scan"

The dropdown shows all connected USB drives with their labels and sizes.

### Stop Transfer

Click the "Stop Transfer" button at any time to cancel an ongoing ingest.

**Important**: The drive will NOT be wiped if you stop the transfer. This is a safety feature.

### Delete Folder

In the Ingest History table, each row has a "Delete" button.

Click it to permanently remove that ingest folder from your NAS.

**Warning**: This cannot be undone!

---

## Folder Naming

Old system: `2026-01-15`
New system: `2026-01-15_13-30-45`

This allows multiple ingests per day and makes it easier to track when each ingest happened.

---

## What Files Are Excluded

The system now automatically skips:

### Hidden Files
- Any file or folder starting with `.` (dot)

### Mac System Files
- `.Trashes` - Mac trash folders
- `.Spotlight-V100` - Mac search index
- `.fseventsd` - Mac filesystem events
- `.TemporaryItems` - Mac temp files

### Windows System Files
- `System Volume Information` - Windows system data
- `$RECYCLE.BIN` - Windows recycle bin

This means cleaner transfers with only your actual content!

---

## Dashboard Controls Overview

```
┌─────────────────────────────────────────────────┐
│ 🔄 Automated Ingest Dashboard                   │
│                                                  │
│ [Auto-Scan: ON/OFF] [Select Drive ▼] [Start]   │
│ [Stop Transfer]                                  │
│                                                  │
│ System Info: Hostname | Uptime | NAS | Space   │
└─────────────────────────────────────────────────┘

┌─────────────────┐  ┌─────────────────┐
│ Current Status  │  │ Recent Activity │
│                 │  │                 │
│ Progress: 45%   │  │ 2026-01-15 ✓   │
│ Files: 150      │  │ 2026-01-14 ✓   │
│ Device: sda1    │  │ 2026-01-13 ✓   │
└─────────────────┘  └─────────────────┘

┌─────────────────────────────────────────────────┐
│ Ingest History                                   │
│                                                  │
│ Date/Time       | Files | Size | [View] [Delete]│
│ 2026-01-15_13.. | 150   | 5GB  | [View] [Delete]│
│ 2026-01-14_09.. | 200   | 8GB  | [View] [Delete]│
└─────────────────────────────────────────────────┘
```

---

## Typical Workflows

### Workflow 1: Automatic Mode (Default)
1. Leave auto-scan enabled
2. Plug in drive
3. Walk away
4. Check dashboard later to confirm success

### Workflow 2: Manual Mode
1. Disable auto-scan toggle
2. Plug in multiple drives
3. Select each drive one by one
4. Click "Start Scan" for each
5. Drives won't auto-start until you tell them to

### Workflow 3: Batch Processing
1. Disable auto-scan
2. Plug in 3-4 drives
3. All drives appear in dropdown
4. Process them one at a time manually

### Workflow 4: Review Before Process
1. Disable auto-scan
2. Plug in drive
3. Browse files on the drive
4. When ready, select it and click "Start Scan"

---

## Troubleshooting

### Auto-scan toggle doesn't work
```bash
# Check the flag file
ls -la /var/run/ingest/auto_scan_enabled

# Enable manually
sudo touch /var/run/ingest/auto_scan_enabled

# Disable manually
sudo rm /var/run/ingest/auto_scan_enabled
```

### Drive doesn't appear in dropdown
```bash
# List USB devices manually
lsblk | grep sd

# Check if ingest-control works
sudo /usr/local/bin/ingest-control.sh list-devices
```

### Stop button doesn't work
```bash
# Manually stop
sudo pkill -f ingest-drive.sh

# Check if it stopped
ps aux | grep ingest-drive
```

### Can't delete folder
```bash
# Manually delete
sudo rm -rf /mnt/ingest/2026-01-15_13-30-45

# Check permissions
ls -la /mnt/ingest/
```

---

## API Endpoints (for advanced users)

The dashboard now has these control endpoints:

```bash
# Enable auto-scan
curl -X POST http://ingest-pi.local:4666/api/control/auto-scan \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"action": "enable"}'

# Start manual scan
curl -X POST http://ingest-pi.local:4666/api/control/manual-scan \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"device": "/dev/sda1"}'

# Stop transfer
curl -X POST http://ingest-pi.local:4666/api/control/stop \
  -u username:password

# Delete folder
curl -X POST http://ingest-pi.local:4666/api/control/delete-folder \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"folder": "2026-01-15_13-30-45"}'

# List devices
curl http://ingest-pi.local:4666/api/devices \
  -u username:password
```

---

## Configuration Files

### Control Flag
- Location: `/var/run/ingest/auto_scan_enabled`
- Exists = auto-scan enabled
- Doesn't exist = auto-scan disabled

### Stop Request
- Location: `/var/run/ingest/stop_request`
- Created when stop is requested
- Deleted after stop completes

### Status File
- Location: `/var/run/ingest/current.json`
- Updated in real-time during ingests
- Includes new `dest_folder` field

---

## Compatibility

- Works with all V1 ingests on your NAS
- Old date-only folders (2026-01-15) still work
- New timestamp folders (2026-01-15_13-30-45) have more detail
- Dashboard shows both formats

---

## What Stays the Same

- SHA256 checksum verification
- Secure drive wiping
- NAS mounting via SMB
- Log files saved to NAS
- systemd services (ingest-monitor, ingest-dashboard)
- User authentication
- Same dashboard port (4666)

---

## Files Changed in V2

- `ingest-drive.sh` - Added timestamp, trash exclusion, stop capability
- `ingest-trigger.sh` - Added auto-scan flag check
- `dashboard.py` - Added control API endpoints and device listing
- `templates/index.html` - Added control UI elements
- New: `ingest-control.sh` - Control script for manual operations

---

## Support

If you have issues:
1. Check service logs: `sudo journalctl -u ingest-dashboard -n 50`
2. Check system logs: `sudo tail -50 /var/log/ingest/system.log`
3. Verify services are running: `sudo systemctl status ingest-monitor ingest-dashboard`

---

**Enjoy your upgraded ingest system!** 🚀
