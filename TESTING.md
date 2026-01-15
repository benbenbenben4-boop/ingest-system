# Testing Checklist for Ingest System

Use this checklist to verify your ingest system is working correctly after installation.

## Pre-Installation Tests

- [ ] Raspberry Pi boots and accessible via SSH
- [ ] Network connectivity working
- [ ] NAS accessible on network (can ping NAS)
- [ ] NAS SMB share accessible (`smbclient -L //NAS_IP -U username`)
- [ ] Sufficient space available on NAS

## Installation Tests

- [ ] Installation script runs without errors
- [ ] All prompts answered correctly (NAS config, credentials)
- [ ] No error messages during installation
- [ ] Installation completes successfully

## Service Tests

### Dashboard Service

```bash
sudo systemctl status ingest-dashboard
```

- [ ] Service is active (running)
- [ ] Service is enabled (will start on boot)
- [ ] No error messages in status

### Monitor Service

```bash
sudo systemctl status ingest-monitor
```

- [ ] Service is active (running)
- [ ] Service is enabled (will start on boot)
- [ ] No error messages in status

### Dashboard Logs

```bash
sudo journalctl -u ingest-dashboard -n 50
```

- [ ] Dashboard started successfully
- [ ] No Python errors
- [ ] Flask is listening on port 4666
- [ ] Users loaded successfully

## Directory Tests

### Check Directory Structure

```bash
ls -la /var/run/ingest
ls -la /var/log/ingest
ls -la /mnt/ingest
ls -la /mnt/usb_drive
ls -la /etc/ingest
ls -la /opt/ingest-dashboard
```

- [ ] `/var/run/ingest` exists and writable
- [ ] `/var/log/ingest` exists and writable
- [ ] `/mnt/ingest` exists (NAS mount point)
- [ ] `/mnt/usb_drive` exists (USB mount point)
- [ ] `/etc/ingest` exists with credentials
- [ ] `/opt/ingest-dashboard` exists with dashboard files

### Check Scripts Installed

```bash
ls -la /usr/local/bin/ingest-*.sh
```

- [ ] `ingest-drive.sh` exists and executable
- [ ] `ingest-trigger.sh` exists and executable
- [ ] `ingest-control.sh` exists and executable

## NAS Mount Tests

### Check Mount

```bash
mount | grep /mnt/ingest
df -h | grep /mnt/ingest
```

- [ ] NAS is mounted at `/mnt/ingest`
- [ ] Mount type is `cifs`
- [ ] Can see available space

### Test Write Access

```bash
sudo touch /mnt/ingest/test-file.txt
ls -la /mnt/ingest/test-file.txt
sudo rm /mnt/ingest/test-file.txt
```

- [ ] Can create files on NAS
- [ ] Can delete files from NAS
- [ ] No permission errors

## Dashboard Access Tests

### Web Access

Open browser to: `http://[PI_IP]:4666` or `http://raspberrypi.local:4666`

- [ ] Dashboard loads successfully
- [ ] Login prompt appears
- [ ] Can login with credentials
- [ ] Dashboard UI displays correctly
- [ ] No JavaScript errors in browser console

### Dashboard UI Elements

- [ ] Header shows "Automated Ingest Dashboard"
- [ ] Auto-scan toggle visible
- [ ] Device selector dropdown visible
- [ ] Start Scan button visible
- [ ] Stop Transfer button visible
- [ ] System info cards show data (hostname, uptime, NAS status)
- [ ] Current Status card visible
- [ ] Recent Activity card visible
- [ ] Ingest History table visible

### System Info Display

- [ ] Hostname displayed correctly
- [ ] Uptime showing
- [ ] NAS Status shows "Mounted" with green indicator
- [ ] NAS Space shows available space

## Auto-Scan Tests

### Check Auto-Scan Flag

```bash
ls -la /var/run/ingest/auto_scan_enabled
```

- [ ] Auto-scan flag file exists (enabled by default)

### Dashboard Toggle

- [ ] Auto-scan toggle shows ON (enabled)
- [ ] Can toggle OFF - notification appears
- [ ] Flag file removed: `ls /var/run/ingest/auto_scan_enabled` returns "No such file"
- [ ] Can toggle ON again - notification appears
- [ ] Flag file created again

### Command Line Control

```bash
sudo /usr/local/bin/ingest-control.sh status-auto
sudo /usr/local/bin/ingest-control.sh disable-auto
sudo /usr/local/bin/ingest-control.sh status-auto
sudo /usr/local/bin/ingest-control.sh enable-auto
sudo /usr/local/bin/ingest-control.sh status-auto
```

- [ ] Status command shows "enabled" or "disabled"
- [ ] Can disable via command
- [ ] Can enable via command

## USB Detection Tests

### Check Udev Rule

```bash
cat /etc/udev/rules.d/99-ingest-usb.rules
```

- [ ] Udev rule file exists
- [ ] Rule triggers on USB storage devices
- [ ] Rule calls `ingest-trigger.sh`

### Monitor Udev Events

```bash
# In one terminal, monitor udev
sudo udevadm monitor --environment --udev

# In another terminal, plug in USB drive
# Watch for ADD events with KERNEL=sd[a-z][0-9]
```

- [ ] Udev detects USB drive when plugged in
- [ ] See ADD event for `sd[a-z][0-9]` device
- [ ] ENV variables show USB device type

### Check Trigger Log

```bash
# Enable auto-scan first
sudo touch /var/run/ingest/auto_scan_enabled

# Plug in USB drive

# Check logs
sudo tail -f /var/log/ingest/trigger.log
```

- [ ] Trigger log shows device detection
- [ ] Shows device path (e.g., `/dev/sda1`)
- [ ] Shows "Auto-scan enabled, starting ingest..."
- [ ] Shows process started with PID

## Device Listing Tests

### Dashboard Device List

- [ ] Plug in USB drive
- [ ] Wait 5 seconds (auto-refresh)
- [ ] Device appears in dropdown
- [ ] Shows device label and size
- [ ] Shows correct device path

### Command Line Device List

```bash
sudo /usr/local/bin/ingest-control.sh list-devices
```

- [ ] Lists connected USB devices
- [ ] Shows device names (sda1, sdb1, etc.)
- [ ] Shows sizes and labels

## Manual Scan Tests

### From Dashboard

- [ ] Disable auto-scan
- [ ] Plug in USB drive (should not auto-start)
- [ ] Device appears in dropdown
- [ ] Select device
- [ ] Click "Start Scan"
- [ ] Notification appears: "Manual scan started"
- [ ] Progress appears in Current Status card
- [ ] Can watch progress in real-time

### From Command Line

```bash
sudo /usr/local/bin/ingest-control.sh manual-scan /dev/sda1
```

- [ ] Command starts scan
- [ ] Shows "Manual scan started"
- [ ] Can see process running: `ps aux | grep ingest-drive`

## Ingest Process Tests

### Progress Monitoring

During an active ingest:

- [ ] Status badge changes (MOUNTING → SCANNING → TRANSFERRING → VERIFYING → WIPING → COMPLETE)
- [ ] Progress bar updates
- [ ] File count increases
- [ ] Current file name updates
- [ ] Destination folder shows timestamp format (YYYY-MM-DD_HH-MM-SS)

### System Log

```bash
sudo tail -f /var/log/ingest/system.log
```

During ingest:

- [ ] Shows "New ingest job started"
- [ ] Shows device information
- [ ] Shows mounting progress
- [ ] Shows file counting
- [ ] Shows transfer progress
- [ ] Shows checksum calculation
- [ ] Shows verification
- [ ] Shows wiping progress
- [ ] Shows "Ingest complete!"

### Status File

```bash
cat /var/run/ingest/current.json
```

During ingest:

- [ ] JSON file exists and valid
- [ ] Shows current status
- [ ] Shows progress percentage
- [ ] Shows device info
- [ ] Shows file counts

## Stop Transfer Tests

### From Dashboard

- [ ] Start an ingest (manual or auto)
- [ ] Click "Stop Transfer" button
- [ ] Confirm the action
- [ ] Notification appears: "Transfer stopped"
- [ ] Process stops (check with `ps aux | grep ingest-drive`)
- [ ] Status shows "stopped"
- [ ] USB drive NOT wiped (can verify by checking drive)

### From Command Line

```bash
sudo /usr/local/bin/ingest-control.sh stop
```

- [ ] Command stops the ingest
- [ ] Shows "Stop requested"
- [ ] Process terminated

## Completion Tests

### Successful Ingest

After a complete ingest:

- [ ] New folder created on NAS with timestamp name
- [ ] Folder contains all files from USB drive
- [ ] Checksum file created (`checksums_*.txt`)
- [ ] Log file created (`ingest_log_*.txt`)
- [ ] Log shows "SUCCESS"
- [ ] USB drive is wiped (appears as unformatted)

### Ingest History

- [ ] New entry appears in History table
- [ ] Shows correct date/time
- [ ] Shows drive label
- [ ] Shows file count
- [ ] Shows total size
- [ ] Status indicator is green (success)
- [ ] "View Log" button works
- [ ] "Delete" button works

### View Log

- [ ] Click "View Log" button
- [ ] Modal opens with log content
- [ ] Log shows complete ingest details
- [ ] Can scroll through log
- [ ] Can close modal

### Delete Folder

- [ ] Click "Delete" button on an entry
- [ ] Confirmation prompt appears
- [ ] Confirm deletion
- [ ] Notification appears: "Folder deleted"
- [ ] Entry removed from history
- [ ] Folder removed from NAS

## Trash Exclusion Tests

### Create Test USB Drive

Create a USB drive with:
- Regular files (e.g., `photo.jpg`, `video.mp4`)
- Hidden files (e.g., `.hidden_file`)
- `.Trashes` folder
- `.Spotlight-V100` folder
- `.DS_Store` file

### Run Ingest

- [ ] Start ingest with test drive
- [ ] Check destination folder on NAS
- [ ] Regular files copied
- [ ] Hidden files NOT copied
- [ ] `.Trashes` folder NOT copied
- [ ] `.Spotlight-V100` NOT copied
- [ ] `.DS_Store` NOT copied

## Safety Tests

### SD Card Protection

```bash
# Try to ingest the SD card (should be rejected)
sudo /usr/local/bin/ingest-control.sh manual-scan /dev/mmcblk0p1
```

- [ ] Command rejects SD card
- [ ] Error message: "Cannot process SD card"
- [ ] No ingest starts

### Space Check

Create a USB drive with more data than available on NAS:

- [ ] Ingest starts
- [ ] Space check fails
- [ ] Error status shows
- [ ] Error message about insufficient space
- [ ] USB drive NOT wiped

### Verification Failure

(This is hard to test without corruption)

Expected behavior:
- [ ] If checksums don't match
- [ ] Error status shows
- [ ] Error message about verification failure
- [ ] USB drive NOT wiped (safety feature)

## Reboot Tests

### Persistence After Reboot

```bash
sudo reboot
```

After reboot:

- [ ] Services start automatically
- [ ] Dashboard accessible
- [ ] NAS auto-mounted
- [ ] Auto-scan state preserved
- [ ] Can plug in USB and auto-ingest works

## API Tests

### Status API

```bash
curl -u username:password http://localhost:4666/api/status
```

- [ ] Returns JSON status
- [ ] Shows current state
- [ ] Authentication required

### System API

```bash
curl -u username:password http://localhost:4666/api/system
```

- [ ] Returns system info
- [ ] Shows hostname, uptime, NAS status
- [ ] Authentication required

### History API

```bash
curl -u username:password http://localhost:4666/api/history
```

- [ ] Returns ingest history
- [ ] Shows past ingests
- [ ] Authentication required

### Devices API

```bash
curl -u username:password http://localhost:4666/api/devices
```

- [ ] Returns list of USB devices
- [ ] Shows device info
- [ ] Authentication required

### Control APIs

```bash
# Enable auto-scan
curl -X POST http://localhost:4666/api/control/auto-scan \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"action": "enable"}'

# Start manual scan
curl -X POST http://localhost:4666/api/control/manual-scan \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"device": "/dev/sda1"}'

# Stop
curl -X POST http://localhost:4666/api/control/stop \
  -u username:password
```

- [ ] Auto-scan control works
- [ ] Manual scan control works
- [ ] Stop control works
- [ ] Returns JSON responses
- [ ] Authentication required

## Performance Tests

### Large File Transfer

Test with a large file (> 1GB):

- [ ] Transfer completes successfully
- [ ] Progress updates smoothly
- [ ] No timeout errors
- [ ] Checksum verification works
- [ ] Wiping completes

### Many Small Files

Test with many small files (> 1000 files):

- [ ] All files transferred
- [ ] File count accurate
- [ ] Progress updates
- [ ] Checksum verification works
- [ ] No performance issues

## Final Verification

- [ ] All services running
- [ ] Dashboard accessible
- [ ] Auto-ingest working
- [ ] Manual controls working
- [ ] Logs being written
- [ ] NAS mounted and accessible
- [ ] No error messages in logs
- [ ] System ready for production use

---

## Issue Reporting

If any tests fail, collect the following information:

```bash
# System info
cat /etc/os-release
uname -a

# Service status
sudo systemctl status ingest-dashboard ingest-monitor

# Logs
sudo journalctl -u ingest-dashboard -n 100
sudo tail -50 /var/log/ingest/system.log
sudo tail -50 /var/log/ingest/trigger.log

# File structure
ls -laR /var/run/ingest
ls -laR /var/log/ingest
ls -la /usr/local/bin/ingest-*.sh

# NAS mount
mount | grep ingest
df -h | grep ingest

# Udev
cat /etc/udev/rules.d/99-ingest-usb.rules
```

Include this information when reporting issues.

---

**Testing complete? Ready for production!** ✓
