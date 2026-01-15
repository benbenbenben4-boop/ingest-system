# Troubleshooting USB Auto-Detection

If the dashboard sees your USB drive but auto-ingest doesn't trigger, follow these steps.

## Quick Diagnosis

Run the test script:
```bash
sudo ./test-udev.sh
```

This will show you:
- What USB devices are connected
- If the udev rule exists
- If auto-scan is enabled
- Real-time USB event monitoring

## Common Issues

### Issue 1: Udev Rule Not Firing

**Symptom:** Dashboard shows the drive, but trigger log is empty

**Solution:**
```bash
# Reload udev rules
sudo udevadm control --reload-rules

# Trigger events for already-connected devices
sudo udevadm trigger --subsystem-match=block --action=add

# Monitor udev events (unplug/replug drive while this runs)
sudo udevadm monitor --kernel --property --subsystem-match=block
```

You should see events like:
```
KERNEL[123.456] add /devices/platform/.../block/sda/sda1 (block)
```

If you DON'T see events, the issue is with udev configuration.

### Issue 2: Wrong Device Pattern

**Symptom:** Some drives work, others don't

**Check device names:**
```bash
lsblk -o NAME,TYPE
```

Your drives should show as `sda1`, `sdb1`, etc.

If you see different patterns (like `mmcblk0p1`), you need to adjust the udev rule.

**Update the rule:**
```bash
sudo nano /etc/udev/rules.d/99-ingest-usb.rules
```

Change:
```
KERNEL=="sd[a-z][0-9]*"
```

To match your devices (or use `*` for all):
```
KERNEL=="*"
```

Then reload:
```bash
sudo udevadm control --reload-rules
```

### Issue 3: Auto-Scan Disabled

**Check status:**
```bash
sudo /usr/local/bin/ingest-control.sh status-auto
```

If it says "disabled":
```bash
sudo /usr/local/bin/ingest-control.sh enable-auto
```

### Issue 4: Scripts Not Executable

**Check permissions:**
```bash
ls -la /usr/local/bin/ingest-*.sh
```

All should show `-rwxr-xr-x` (executable).

If not:
```bash
sudo chmod +x /usr/local/bin/ingest-*.sh
```

### Issue 5: Udev Rule Path Wrong

**Verify trigger script exists:**
```bash
ls -la /usr/local/bin/ingest-trigger.sh
```

**Check udev rule points to correct path:**
```bash
cat /etc/udev/rules.d/99-ingest-usb.rules
```

Should show:
```
RUN+="/usr/local/bin/ingest-trigger.sh %k"
```

## Manual Testing

### Test the Trigger Script Directly

```bash
# Find your USB device name
lsblk | grep sd

# Test trigger manually (example: sda1)
sudo /usr/local/bin/ingest-trigger.sh sda1

# Check the log
cat /var/log/ingest/trigger.log
```

If this works, the problem is with udev, not the scripts.

### Test with Real-Time Monitoring

In one terminal:
```bash
tail -f /var/log/ingest/trigger.log
```

In another terminal:
```bash
# Unplug drive
# Wait 5 seconds
# Plug drive back in
```

Watch the first terminal for activity.

## Alternative: Force Trigger on Already-Connected Drives

If you want to trigger ingest for drives that are already plugged in:

```bash
# List connected USB drives
lsblk | grep sd

# Trigger udev events for all block devices
sudo udevadm trigger --subsystem-match=block --action=add
```

This simulates plugging in all drives again.

## Debug Mode: Verbose Udev Rule

For debugging, you can add logging to the udev rule:

```bash
sudo nano /etc/udev/rules.d/99-ingest-usb.rules
```

Change to:
```
# Log all USB block device events
ACTION=="add", SUBSYSTEM=="block", ENV{ID_BUS}=="usb", RUN+="/bin/sh -c 'echo [$(date)] USB ADD: %k >> /var/log/ingest/udev-debug.log'"

# Then trigger ingest
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]*", ENV{ID_BUS}=="usb", RUN+="/usr/local/bin/ingest-trigger.sh %k"
```

Reload and test:
```bash
sudo udevadm control --reload-rules
# Unplug/replug drive
cat /var/log/ingest/udev-debug.log
```

## Check System Logs

```bash
# View recent system messages
sudo dmesg | tail -50

# View udev logs
sudo journalctl -u systemd-udevd -n 50

# Search for USB messages
sudo dmesg | grep -i usb
```

## Nuclear Option: Reinstall Everything

```bash
cd ~/ingest-system
git pull origin claude/auto-ingest-setup-21VvE
sudo ./quick-setup.sh
```

This recreates everything from scratch.

## Still Not Working?

### Verify Udev is Running

```bash
systemctl status systemd-udevd
```

Should show "active (running)".

If not:
```bash
sudo systemctl start systemd-udevd
```

### Check for Conflicting Rules

```bash
ls -la /etc/udev/rules.d/
```

Look for other rules that might be catching USB events first.

### Permissions Issues

```bash
# Ensure trigger log is writable
sudo chmod 666 /var/log/ingest/trigger.log

# Ensure script can write to log directory
sudo chmod 777 /var/log/ingest
```

## Working Configuration Reference

**Confirmed working udev rule:**
```
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]*", ENV{ID_BUS}=="usb", RUN+="/usr/local/bin/ingest-trigger.sh %k"
```

**Auto-scan enabled:**
```bash
$ sudo /usr/local/bin/ingest-control.sh status-auto
enabled
```

**Scripts installed:**
```bash
$ ls -la /usr/local/bin/ingest-*.sh
-rwxr-xr-x 1 root root 2333 /usr/local/bin/ingest-control.sh
-rwxr-xr-x 1 root root 11939 /usr/local/bin/ingest-drive.sh
-rwxr-xr-x 1 root root 1036 /usr/local/bin/ingest-trigger.sh
```

**Expected behavior:**
1. Plug in USB drive
2. Within 1-2 seconds, see entry in `/var/log/ingest/trigger.log`
3. Ingest process starts automatically
4. Dashboard shows progress

---

**Need more help?** Run `sudo ./test-udev.sh` and share the output!
