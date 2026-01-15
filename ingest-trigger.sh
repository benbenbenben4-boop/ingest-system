#!/bin/bash
# Wrapper script to trigger ingest with proper environment
# Only triggers if auto-scan is enabled

DEVICE="/dev/$1"
LOG_FILE="/var/log/ingest/trigger.log"
AUTO_SCAN_FLAG="/var/run/ingest/auto_scan_enabled"

echo "[$(date)] USB device detected: $DEVICE" >> "$LOG_FILE"

# Only auto-start if auto-scan is enabled
if [ -f "$AUTO_SCAN_FLAG" ]; then
    echo "[$(date)] Auto-scan enabled, starting ingest..." >> "$LOG_FILE"
    /usr/local/bin/ingest-drive.sh "$DEVICE" &
else
    echo "[$(date)] Auto-scan disabled, waiting for manual trigger..." >> "$LOG_FILE"
fi

exit 0
