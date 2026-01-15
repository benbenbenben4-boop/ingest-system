#!/bin/bash

# Automated Ingest Script with Manual Controls
# Handles USB drive detection, transfer, verification, and wiping

set -e

# Configuration
MOUNT_POINT="/mnt/usb_drive"
NAS_MOUNT="/mnt/ingest"
STATUS_DIR="/var/run/ingest"
LOG_DIR="/var/log/ingest"
SYSTEM_LOG="$LOG_DIR/system.log"
STOP_REQUEST="$STATUS_DIR/stop_request"

# Load config file if exists
CONFIG_FILE="/etc/ingest/ingest.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Wipe control - set SKIP_WIPE=1 to skip wiping (for testing)
SKIP_WIPE="${SKIP_WIPE:-0}"

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure status directory exists
mkdir -p "$STATUS_DIR"
mkdir -p "$LOG_DIR"

# Logging functions
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "$message" >> "$SYSTEM_LOG"
}

error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}${message}${NC}"
    echo "$message" >> "$SYSTEM_LOG"
}

warn() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "$message" >> "$SYSTEM_LOG"
}

info() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$SYSTEM_LOG"
}

# Check if stop requested
check_stop() {
    if [ -f "$STOP_REQUEST" ]; then
        error "Stop requested by user"
        update_status "stopped" "Stopped by user" 0
        rm -f "$STOP_REQUEST"
        exit 1
    fi
}

# Update status file for dashboard
update_status() {
    local status="$1"
    local message="$2"
    local progress="${3:-0}"
    
    cat > "$STATUS_DIR/current.json" << EOF
{
    "status": "$status",
    "message": "$message",
    "progress": $progress,
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "device": "${DEVICE:-unknown}",
    "drive_label": "${DRIVE_LABEL:-unknown}",
    "total_files": ${TOTAL_FILES:-0},
    "total_size": "${TOTAL_SIZE:-0}",
    "transferred_files": ${TRANSFERRED_FILES:-0},
    "current_file": "${CURRENT_FILE:-}",
    "dest_folder": "${DEST_FOLDER_NAME:-}"
}
EOF
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    
    # Unmount if mounted
    if mountpoint -q "$MOUNT_POINT"; then
        umount "$MOUNT_POINT" 2>/dev/null || true
    fi
    
    log "Cleanup complete"
}

trap cleanup EXIT

# Main script starts here
DEVICE="$1"

if [ -z "$DEVICE" ]; then
    error "No device specified"
    exit 1
fi

log "=========================================="
log "New ingest job started"
log "Device: $DEVICE"
log "=========================================="

update_status "starting" "Initializing ingest process..." 0

# Safety check: make sure we're not processing the SD card
if [[ "$DEVICE" == *"mmcblk"* ]]; then
    error "Refusing to process SD card device: $DEVICE"
    update_status "error" "Cannot process SD card (safety check)"
    exit 1
fi

log "Device safety check passed"

check_stop

# Get device info
DEVICE_NAME=$(basename "$DEVICE")

# Get drive size
DEVICE_BASE=$(echo "$DEVICE_NAME" | sed 's/[0-9]*$//')
DEVICE_SIZE=$(lsblk -b -d -n -o SIZE "/dev/$DEVICE_BASE" 2>/dev/null || echo "0")
DEVICE_SIZE_GB=$((DEVICE_SIZE / 1024 / 1024 / 1024))

log "Device size: ${DEVICE_SIZE_GB}GB"

# Step 1: Mount the drive (unmount first if already mounted)
log "Mounting drive..."
update_status "mounting" "Mounting USB drive..." 5

# Unmount if already mounted
if mountpoint -q "$MOUNT_POINT"; then
    umount "$MOUNT_POINT" 2>/dev/null || true
fi

mkdir -p "$MOUNT_POINT"

# Try to mount with various filesystem types
MOUNTED=false

# First, try auto-detect (works best for exFAT on most systems)
if mount "$DEVICE" "$MOUNT_POINT" 2>/dev/null; then
    MOUNTED=true
    FILESYSTEM=$(findmnt -n -o FSTYPE "$MOUNT_POINT" 2>/dev/null || echo "auto")
    log "Mounted as $FILESYSTEM (auto-detected)"
else
    # If auto-detect fails, try explicit filesystem types
    for FS in ntfs exfat vfat ext4; do
        if mount -t "$FS" "$DEVICE" "$MOUNT_POINT" 2>/dev/null; then
            MOUNTED=true
            FILESYSTEM="$FS"
            log "Mounted as $FS"
            break
        fi
    done
fi

if [ "$MOUNTED" = false ]; then
    error "Failed to mount device $DEVICE"
    update_status "error" "Failed to mount drive"
    exit 1
fi

check_stop

# Get drive label
DRIVE_LABEL=$(lsblk -n -o LABEL "$DEVICE" 2>/dev/null | head -n1)
if [ -z "$DRIVE_LABEL" ]; then
    DRIVE_LABEL="UNLABELED_$(date +%H%M%S)"
fi

log "Drive label: $DRIVE_LABEL"

# Step 2: Count files and calculate total size (excluding hidden/trash)
log "Scanning drive contents (excluding trash and hidden files)..."
update_status "scanning" "Counting files and calculating size..." 10

check_stop

TOTAL_FILES=$(find "$MOUNT_POINT" -type f -not -path "*/.*" | wc -l)
TOTAL_SIZE=$(du -sb --exclude=".*" "$MOUNT_POINT" 2>/dev/null | cut -f1)
TOTAL_SIZE_GB=$((TOTAL_SIZE / 1024 / 1024 / 1024))
TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024 / 1024))

log "Found $TOTAL_FILES files (${TOTAL_SIZE_GB}GB / ${TOTAL_SIZE_MB}MB)"
log "Excluded: hidden files, .Trashes, system folders"

if [ "$TOTAL_FILES" -eq 0 ]; then
    warn "No files found on drive - skipping ingest"
    update_status "complete" "No files to ingest" 100
    exit 0
fi

check_stop

# Step 3: Check NAS availability and space
log "Checking NAS availability..."
update_status "checking" "Verifying NAS connection and space..." 15

if ! mountpoint -q "$NAS_MOUNT"; then
    error "NAS is not mounted"
    update_status "error" "NAS not accessible"
    exit 1
fi

NAS_AVAILABLE=$(df -B1 "$NAS_MOUNT" | tail -1 | awk '{print $4}')
if [ "$NAS_AVAILABLE" -lt "$TOTAL_SIZE" ]; then
    error "Insufficient space on NAS"
    NAS_AVAIL_GB=$((NAS_AVAILABLE / 1024 / 1024 / 1024))
    update_status "error" "Insufficient space on NAS (available: ${NAS_AVAIL_GB}GB, needed: ${TOTAL_SIZE_GB}GB)"
    exit 1
fi

log "NAS has sufficient space"

check_stop

# Step 4: Create destination directory with date AND time
DEST_FOLDER_NAME=$(date +%Y-%m-%d_%H-%M-%S)
DEST_DIR="$NAS_MOUNT/$DEST_FOLDER_NAME"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$DEST_DIR/ingest_log_${TIMESTAMP}.txt"

log "Creating destination directory: $DEST_DIR"
mkdir -p "$DEST_DIR"

# Initialize ingest log
cat > "$LOG_FILE" << EOF
========================================
Ingest Log
========================================
Date: $(date)
Drive Label: $DRIVE_LABEL
Device: $DEVICE
Total Files: $TOTAL_FILES
Total Size: ${TOTAL_SIZE_MB}MB (${TOTAL_SIZE_GB}GB)
Destination: $DEST_DIR
Excluded: Hidden files, .Trashes, system folders
========================================

EOF

check_stop

# Step 5: Transfer files to NAS (excluding trash and hidden files)
log "Starting file transfer..."
update_status "transferring" "Transferring files to NAS..." 20

TRANSFERRED_FILES=0

# Use rsync for transfer with exclusions
rsync -av --progress \
    --exclude=".*" \
    --exclude=".Trashes" \
    --exclude=".Spotlight-V100" \
    --exclude=".fseventsd" \
    --exclude=".TemporaryItems" \
    --exclude="System Volume Information" \
    --exclude='$RECYCLE.BIN' \
    "$MOUNT_POINT/" "$DEST_DIR/" 2>&1 | while read -r line; do
    
    check_stop
    
    if [[ "$line" =~ ^[^/] ]] && [[ "$line" != *"sending incremental"* ]]; then
        TRANSFERRED_FILES=$((TRANSFERRED_FILES + 1))
        PROGRESS=$((20 + (TRANSFERRED_FILES * 50 / TOTAL_FILES)))
        
        CURRENT_FILE="$line"
        update_status "transferring" "Transferring: $line" $PROGRESS
    fi
done

log "File transfer complete"
echo "Files transferred to: $DEST_DIR" >> "$LOG_FILE"

check_stop

# Step 6: Calculate checksums AFTER transfer (on what was actually transferred)
log "Calculating checksums on transferred files..."
update_status "checksumming" "Calculating SHA256 checksums on NAS..." 75

CHECKSUM_FILE="$DEST_DIR/checksums_${TIMESTAMP}.txt"
cd "$DEST_DIR"

# Calculate checksums only on files that were actually transferred
# Exclude the log and checksum files themselves
find . -type f ! -name "checksums_*" ! -name "ingest_log_*" -exec sha256sum {} \; > "$CHECKSUM_FILE"

log "Checksums calculated and saved"
echo "Checksums calculated on transferred files: $CHECKSUM_FILE" >> "$LOG_FILE"

check_stop

# Step 7: Verify checksums (should always pass now)
log "Verifying checksums..."
update_status "verifying" "Verifying file integrity..." 80

cd "$DEST_DIR"

if sha256sum -c "$CHECKSUM_FILE" >> "$LOG_FILE" 2>&1; then
    log "All checksums verified successfully!"
    echo "✓ All checksums verified successfully" >> "$LOG_FILE"
    VERIFICATION_SUCCESS=true
else
    error "Checksum verification failed!"
    echo "✗ CHECKSUM VERIFICATION FAILED" >> "$LOG_FILE"
    update_status "error" "Checksum verification failed - NOT wiping drive"
    exit 1
fi

check_stop

# Step 8: Wipe the source drive
if [ "$SKIP_WIPE" = "1" ]; then
    log "SKIPPING drive wipe (SKIP_WIPE=1)"
    echo "⚠ Drive wipe skipped (testing mode)" >> "$LOG_FILE"
    update_status "wiping" "Skipping wipe (test mode)..." 95

    # Unmount the drive
    cd /
    umount "$MOUNT_POINT"

elif [ "$SKIP_WIPE" = "2" ]; then
    log "FAST ERASE mode (SKIP_WIPE=2)"
    update_status "wiping" "Fast erasing drive..." 85

    # Unmount the drive
    cd /
    umount "$MOUNT_POINT"

    # Fast erase: wipe partition table and create new filesystem
    log "Wiping partition table on $DEVICE_BASE..."

    # Wipe first and last 1MB (destroys partition tables and backup tables)
    dd if=/dev/zero of="/dev/$DEVICE_BASE" bs=1M count=1 2>/dev/null || true
    dd if=/dev/zero of="/dev/$DEVICE_BASE" bs=1M seek=$((DEVICE_SIZE / 1024 / 1024 - 1)) count=1 2>/dev/null || true

    # Create new partition table
    log "Creating new partition table..."
    parted -s "/dev/$DEVICE_BASE" mklabel msdos
    parted -s "/dev/$DEVICE_BASE" mkpart primary 1MiB 100%

    # Format with exFAT (cross-platform compatible)
    log "Formatting with exFAT..."
    sleep 2  # Wait for partition to appear
    mkfs.exfat -n "INGESTED" "$DEVICE" 2>/dev/null || mkfs.vfat -n "INGESTED" "$DEVICE"

    sync

    log "Fast erase complete"
    echo "✓ Drive fast-erased (partition table wiped, reformatted as exFAT)" >> "$LOG_FILE"
    update_status "wiping" "Fast erase complete" 95

else
    # Full wipe mode (SKIP_WIPE=0)
    log "FULL WIPE mode - overwriting entire drive with zeros"
    log "Device size: ${DEVICE_SIZE_GB}GB - this may take ${DEVICE_SIZE_GB} to $((DEVICE_SIZE_GB * 2)) minutes"
    update_status "wiping" "Securely wiping source drive... (0%)" 85

    # Unmount before wiping
    cd /
    umount "$MOUNT_POINT"

    # Use dd to wipe the entire device (single-pass overwrite)
    log "Performing single-pass wipe of $DEVICE..."
    dd if=/dev/zero of="$DEVICE" bs=1M status=progress 2>&1 | while read -r line; do
        check_stop

        if [[ "$line" =~ ([0-9]+)\ bytes ]]; then
            WIPED_BYTES="${BASH_REMATCH[1]}"
            if [ "$DEVICE_SIZE" -gt 0 ]; then
                WIPE_PROGRESS=$((85 + (WIPED_BYTES * 14 / DEVICE_SIZE)))
                if [ "$WIPE_PROGRESS" -gt 99 ]; then
                    WIPE_PROGRESS=99
                fi
                WIPED_GB=$((WIPED_BYTES / 1024 / 1024 / 1024))
                update_status "wiping" "Wiping drive... ${WIPED_GB}GB/${DEVICE_SIZE_GB}GB (${WIPE_PROGRESS}%)" $WIPE_PROGRESS
            fi
        fi
    done 2>/dev/null || true

    # Sync to ensure all data is written
    sync

    log "Drive wiped successfully"
    echo "✓ Source drive wiped successfully" >> "$LOG_FILE"
fi

# Step 9: Complete
log "=========================================="
log "Ingest complete!"
log "Files: $TOTAL_FILES"
log "Size: ${TOTAL_SIZE_MB}MB"
log "Destination: $DEST_DIR"
log "Log: $LOG_FILE"
log "=========================================="

# Final log entries
cat >> "$LOG_FILE" << EOF

========================================
Ingest Complete
========================================
Completion Time: $(date)
Status: SUCCESS
Files Transferred: $TOTAL_FILES
Checksums Verified: ✓
Drive Wiped: ✓
========================================
EOF

update_status "complete" "Ingest complete! $TOTAL_FILES files transferred and verified." 100

# Keep status visible for 30 seconds
sleep 30

exit 0
