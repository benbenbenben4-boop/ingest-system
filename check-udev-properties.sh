#!/bin/bash

# Check USB device properties to debug udev rule matching

echo "=== USB Device Properties Checker ==="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# Find USB storage devices
DEVICES=$(lsblk -o NAME,TYPE -n | grep "part" | grep "sd" | awk '{print $1}' | sed 's/[^a-zA-Z0-9]//g')

if [ -z "$DEVICES" ]; then
    echo "No USB storage devices found!"
    echo "Please plug in a USB drive and try again."
    exit 1
fi

echo "Found USB device partitions:"
echo "$DEVICES"
echo ""

for DEV in $DEVICES; do
    echo "=========================================="
    echo "Device: /dev/$DEV"
    echo "=========================================="
    echo ""

    echo "Key properties for udev matching:"
    udevadm info --query=property --name=/dev/$DEV | grep -E "DEVNAME|DEVTYPE|ID_BUS|SUBSYSTEM|ACTION"

    echo ""
    echo "Full properties:"
    udevadm info --query=property --name=/dev/$DEV

    echo ""
    echo "Udev rule path:"
    udevadm info --query=path --name=/dev/$DEV

    echo ""
done

echo "=========================================="
echo "Current udev rule:"
echo "=========================================="
cat /etc/udev/rules.d/99-ingest-usb.rules
echo ""

echo "=========================================="
echo "Analysis:"
echo "=========================================="
echo ""
echo "The udev rule matches on:"
echo "  - ACTION==add"
echo "  - SUBSYSTEM==block"
echo "  - KERNEL==sd[a-z][0-9]*"
echo "  - ENV{ID_BUS}==usb"
echo ""
echo "Check if ID_BUS=usb is set above."
echo "If ID_BUS is NOT 'usb', the rule won't match!"
echo ""
echo "If ID_BUS is missing or different, try this alternative rule:"
echo ""
echo "ACTION==\"add\", SUBSYSTEM==\"block\", KERNEL==\"sd[a-z][0-9]*\", RUN+=\"/usr/local/bin/ingest-trigger.sh %k\""
echo ""
echo "(This removes the ID_BUS requirement)"
