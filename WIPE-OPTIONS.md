# Drive Wiping Options

The ingest system securely wipes USB drives after successful verification. This document explains the wiping process and how to control it.

## Default Behavior

By default, after files are:
1. Transferred to NAS
2. Checksums verified
3. Integrity confirmed

The system will:
- Unmount the USB drive
- Overwrite the entire drive with zeros using `dd`
- Display progress as it wipes

## Wiping Time Estimates

Wipe times depend on drive size and write speed (~30MB/s typical):

| Drive Size | Approximate Time |
|------------|------------------|
| 8GB        | 4-5 minutes      |
| 16GB       | 8-10 minutes     |
| 32GB       | 15-20 minutes    |
| 64GB       | 30-40 minutes    |
| 128GB      | 60-90 minutes    |
| 256GB      | 2-3 hours        |
| 512GB      | 4-6 hours        |
| 1TB        | 8-10 hours       |

**The system is NOT frozen** - wiping large drives simply takes a long time.

## Checking Wipe Progress

### From Dashboard
- Real-time progress shown in Current Status
- Progress bar updates
- Shows GB wiped / Total GB

### From Command Line

```bash
# Check system log
sudo tail -f /var/log/ingest/system.log

# Check status JSON
watch -n 1 cat /var/run/ingest/current.json

# See dd process
ps aux | grep "dd if=/dev/zero"

# Monitor disk I/O
sudo iotop -o
# or
iostat -x 2

# Check progress directly
sudo pkill -USR1 dd  # Causes dd to print current progress
```

## Skip Wiping (For Testing)

During testing, you may want to skip the slow wiping step.

### Method 1: Config File (Persistent)

Edit the config file:
```bash
sudo nano /etc/ingest/ingest.conf
```

Change:
```bash
SKIP_WIPE=0
```

To:
```bash
SKIP_WIPE=1
```

This affects all future ingests until you change it back.

**WARNING:** With `SKIP_WIPE=1`, drives will NOT be wiped! Files remain on the USB drive.

### Method 2: Environment Variable (One-Time)

For a single ingest, skip wiping with:
```bash
SKIP_WIPE=1 sudo /usr/local/bin/ingest-drive.sh /dev/sda1
```

This only affects that single run.

### Method 3: Stop Before Wipe

You can also use the "Stop Transfer" button in the dashboard:
- Transfer completes
- Checksums verified
- Before wiping starts, click "Stop Transfer"
- Drive will NOT be wiped

## Verifying Skip Mode

When wipe skipping is enabled, you'll see:

**In system log:**
```
[2026-01-15 12:34:56] SKIPPING drive wipe (SKIP_WIPE=1)
```

**In ingest log:**
```
⚠ Drive wipe skipped (testing mode)
```

**In dashboard:**
```
Status: Skipping wipe (test mode)...
```

## Production vs Testing

### For Testing
```bash
# Enable skip mode
sudo nano /etc/ingest/ingest.conf
# Set SKIP_WIPE=1
```

Test your workflow without waiting for wipes.

### For Production
```bash
# Disable skip mode (default)
sudo nano /etc/ingest/ingest.conf
# Set SKIP_WIPE=0
```

Always wipe drives after ingest for security.

## Safety Notes

- **Wipe only happens after successful verification**
- If checksums fail, drive is NOT wiped (safety feature)
- If you stop the transfer early, drive is NOT wiped
- Wiping uses single-pass overwrite (sufficient for most use cases)
- For high-security needs, consider multi-pass tools like `shred` or `nwipe`

## Monitoring Long Wipes

For large drives (256GB+), you may want to:

### 1. Run in Screen/Tmux

```bash
# Start screen session
screen -S ingest

# Monitor logs
sudo tail -f /var/log/ingest/system.log

# Detach: Ctrl+A, then D
# Reattach: screen -r ingest
```

### 2. Check via Dashboard

The dashboard updates in real-time:
- Open `http://raspberrypi.local:4666`
- Current Status shows live progress
- Refresh every 5 seconds automatically

### 3. Email/Notifications (Future Feature)

Consider adding notifications when wipe completes:
```bash
# Add to ingest-drive.sh after wipe completes
echo "Ingest complete for $DRIVE_LABEL" | mail -s "Ingest Complete" you@example.com
```

## Troubleshooting

### Wipe Seems Stuck

Check if it's actually working:
```bash
# See dd process
ps aux | grep "dd if=/dev/zero"

# Check disk activity
sudo iotop -o
```

If you see the dd process and disk writes, it's working - just slow.

### Wipe Taking Forever

Large drives simply take time. Options:
1. **Wait it out** - Safer, proper wipe
2. **Stop transfer** - Use dashboard "Stop Transfer" button
3. **Skip wipe** - Set `SKIP_WIPE=1` for testing only

### Wipe Failed

If wiping fails:
- Check system log: `sudo tail -50 /var/log/ingest/system.log`
- Drive may be write-protected
- Check device permissions
- Verify device path is correct

### Want Faster Wipes

Wiping is I/O bound - limited by USB write speed. Options:
1. Use USB 3.0 ports and drives (faster than USB 2.0)
2. Skip wiping for testing (not recommended for production)
3. Use quick format instead (less secure, not implemented)

## Alternative: External Wiping

If you prefer to wipe drives separately:

1. Enable `SKIP_WIPE=1`
2. Ingest drives normally (no wipe)
3. Batch wipe drives later with dedicated tools:
   - `nwipe` (multi-pass, GUI)
   - `shred -vfz -n 3 /dev/sdX` (3-pass)
   - Hardware disk destroyer

## Security Considerations

### Single-Pass Wipe (Default)
- Overwrites with zeros once
- Sufficient for most use cases
- Data not recoverable with normal tools
- Fast (relatively)

### When Single-Pass Is Enough
- Regular business data
- Personal photos/videos
- Non-sensitive content
- Compliance with basic data policies

### When Multi-Pass May Be Needed
- Highly sensitive data
- Government/military standards
- Regulatory compliance (HIPAA, etc.)
- Financial records
- Personal identifiable information (PII)

For multi-pass wiping, consider using `shred` or `nwipe` externally.

---

**Remember:** During testing, use `SKIP_WIPE=1`. For production, use `SKIP_WIPE=0` (default).
