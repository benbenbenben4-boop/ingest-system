#!/bin/bash
# Wrapper script to trigger ingest with proper environment
# Only triggers if auto-scan is enabled

DEVICE="/dev/$1"
LOG_FILE="/var/log/ingest/trigger.log"
AUTO_SCAN_FLAG="/var/run/ingest/auto_scan_enabled"

echo "[$(date)] ========================================" >> "$LOG_FILE"
echo "[$(date)] USB device detected: $DEVICE" >> "$LOG_FILE"
echo "[$(date)] Raw parameter: $1" >> "$LOG_FILE"

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    echo "[$(date)] ERROR: Device $DEVICE does not exist!" >> "$LOG_FILE"
    exit 1
fi

# Check auto-scan flag
if [ -f "$AUTO_SCAN_FLAG" ]; then
    echo "[$(date)] Auto-scan enabled, starting ingest..." >> "$LOG_FILE"
    
    # Start ingest in background
    /usr/local/bin/ingest-drive.sh "$DEVICE" >> "$LOG_FILE" 2>&1 &
    
    echo "[$(date)] Ingest process started with PID: $!" >> "$LOG_FILE"
else
    echo "[$(date)] Auto-scan disabled, waiting for manual trigger..." >> "$LOG_FILE"
fi

echo "[$(date)] ========================================" >> "$LOG_FILE"

exit 0
