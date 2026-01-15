#!/bin/bash

# Ingest Control Script
# Manages manual scanning and auto-scan state

CONTROL_DIR="/var/run/ingest"
AUTO_SCAN_FLAG="$CONTROL_DIR/auto_scan_enabled"
MANUAL_SCAN_REQUEST="$CONTROL_DIR/manual_scan_request"
STOP_REQUEST="$CONTROL_DIR/stop_request"

# Ensure control directory exists
mkdir -p "$CONTROL_DIR"

case "$1" in
    enable-auto)
        touch "$AUTO_SCAN_FLAG"
        echo "Auto-scan enabled"
        ;;
    disable-auto)
        rm -f "$AUTO_SCAN_FLAG"
        echo "Auto-scan disabled"
        ;;
    status-auto)
        if [ -f "$AUTO_SCAN_FLAG" ]; then
            echo "enabled"
        else
            echo "disabled"
        fi
        ;;
    manual-scan)
        DEVICE="$2"
        if [ -z "$DEVICE" ]; then
            echo "Error: Device required"
            exit 1
        fi
        echo "$DEVICE" > "$MANUAL_SCAN_REQUEST"
        /usr/local/bin/ingest-drive.sh "$DEVICE" &
        echo "Manual scan started for $DEVICE"
        ;;
    stop)
        touch "$STOP_REQUEST"
        pkill -f ingest-drive.sh
        echo "Stop requested"
        sleep 1
        rm -f "$STOP_REQUEST"
        ;;
    delete-folder)
        FOLDER="$2"
        if [ -z "$FOLDER" ]; then
            echo "Error: Folder name required"
            exit 1
        fi
        FOLDER_PATH="/mnt/ingest/$FOLDER"
        if [ -d "$FOLDER_PATH" ]; then
            rm -rf "$FOLDER_PATH"
            echo "Deleted: $FOLDER"
        else
            echo "Error: Folder not found: $FOLDER"
            exit 1
        fi
        ;;
    list-devices)
        # List all connected USB storage devices
        lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT | grep -E "sd[a-z]"
        ;;
    *)
        echo "Usage: $0 {enable-auto|disable-auto|status-auto|manual-scan DEVICE|stop|delete-folder FOLDER|list-devices}"
        exit 1
        ;;
esac
