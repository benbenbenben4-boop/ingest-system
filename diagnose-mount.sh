#!/bin/bash

# Diagnose why a device won't mount

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0 DEVICE"
    exit 1
fi

DEVICE="${1:-/dev/sda1}"

echo "=== Mount Diagnostics for $DEVICE ==="
echo ""

echo "1. Device exists?"
if [ -b "$DEVICE" ]; then
    echo "   ✓ Yes"
else
    echo "   ✗ No - device doesn't exist!"
    exit 1
fi
echo ""

echo "2. Device info:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DEVICE"
echo ""

echo "3. Filesystem type:"
FSTYPE=$(lsblk -n -o FSTYPE "$DEVICE")
echo "   Type: $FSTYPE"
echo ""

echo "4. Currently mounted?"
if mount | grep -q "$DEVICE"; then
    echo "   ✓ Already mounted:"
    mount | grep "$DEVICE"
    echo ""
    echo "   Solution: Unmount first with:"
    echo "   sudo umount $DEVICE"
else
    echo "   ✗ Not mounted"
fi
echo ""

echo "5. Filesystem check:"
if [ "$FSTYPE" = "ntfs" ]; then
    echo "   NTFS filesystem detected"
    echo "   Checking if ntfs-3g is installed..."
    if command -v ntfs-3g &> /dev/null; then
        echo "   ✓ ntfs-3g is installed"
    else
        echo "   ✗ ntfs-3g is NOT installed"
        echo "   Install with: sudo apt-get install ntfs-3g"
    fi
elif [ "$FSTYPE" = "exfat" ]; then
    echo "   exFAT filesystem detected"
    echo "   Checking if exfat support is installed..."
    if command -v mount.exfat &> /dev/null || command -v mount.exfat-fuse &> /dev/null; then
        echo "   ✓ exFAT support is installed"
    else
        echo "   ✗ exFAT support is NOT installed"
        echo "   Install with: sudo apt-get install exfat-fuse exfatprogs"
    fi
elif [ "$FSTYPE" = "vfat" ]; then
    echo "   FAT32 filesystem detected (should work)"
elif [ -z "$FSTYPE" ]; then
    echo "   ⚠ No filesystem detected - device might be unformatted or corrupted"
else
    echo "   Filesystem: $FSTYPE"
fi
echo ""

echo "6. Try manual mount:"
MOUNT_POINT="/mnt/usb_drive"
mkdir -p "$MOUNT_POINT"

echo "   Attempting to mount $DEVICE to $MOUNT_POINT..."
if mount "$DEVICE" "$MOUNT_POINT" 2>&1; then
    echo "   ✓ Mount successful!"
    echo ""
    echo "   Mounted at: $MOUNT_POINT"
    echo "   Contents:"
    ls -la "$MOUNT_POINT" | head -10
    echo ""
    echo "   Unmounting..."
    umount "$MOUNT_POINT"
    echo "   ✓ Ready for auto-ingest"
else
    echo ""
    echo "   ✗ Mount failed"
    echo ""
    echo "   Detailed error:"
    mount -v "$DEVICE" "$MOUNT_POINT" 2>&1 || true
    echo ""
    echo "   Possible solutions:"
    echo "   1. Check filesystem: sudo fsck $DEVICE"
    echo "   2. Check kernel messages: sudo dmesg | tail -20"
    echo "   3. Install filesystem tools:"
    echo "      sudo apt-get install ntfs-3g exfat-fuse exfatprogs"
fi
echo ""

echo "7. Kernel messages (recent):"
dmesg | tail -10
echo ""
