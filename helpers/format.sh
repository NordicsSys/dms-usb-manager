#!/usr/bin/env bash
# Format a removable USB device. Called via pkexec for root.
# Usage: format.sh <device> <fstype>
# fstype: vfat | exfat | ext4
# SAFETY: Only allows /dev/sdX, /dev/nvmeXnXpX, /dev/mmcblkXpX

# Route stderr into stdout so callers (DMS Proc.runCommand) capture the full error text.
exec 2>&1

set -e

DEV="${1:?Missing device}"
FSTYPE="${2:?Missing filesystem type}"

# Block system disks - only allow removable-looking devices
if [[ ! "$DEV" =~ ^/dev/(sd[a-z][0-9]+|nvme[0-9]+n[0-9]+p[0-9]+|mmcblk[0-9]+p[0-9]+)$ ]]; then
    echo "Error: Invalid or non-removable device: $DEV"
    exit 1
fi

# Verify removable
PARENT="/sys/block/$(echo "${DEV##*/}" | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')"
PARENT_DISK="$(basename "$PARENT")"

# Safety: require USB transport on the parent disk.
TRAN_PARENT="$(lsblk -o TRAN -n "/dev/$PARENT_DISK" 2>/dev/null | awk 'NF{print; exit}' | xargs)"
if [[ ! "$TRAN_PARENT" =~ ^usb ]]; then
    echo "Error: Refusing to format non-USB disk /dev/$PARENT_DISK (transport: ${TRAN_PARENT:-unknown}). Only USB devices are allowed."
    exit 1
fi
if [[ -f "$PARENT/removable" ]]; then
    REM=$(cat "$PARENT/removable" 2>/dev/null)
    if [[ "$REM" != "1" ]]; then
        echo "Error: Device $DEV is not marked as removable. Refusing to format."
        exit 1
    fi
else
    echo "Error: Cannot verify removable status for $DEV (sysfs entry missing). Refusing to format."
    exit 1
fi

# Unmount first
umount "$DEV" 2>/dev/null || true
udisksctl unmount -b "$DEV" 2>/dev/null || true

case "$FSTYPE" in
    vfat)
        mkfs.vfat -F 32 -n "USB" "$DEV"
        ;;
    exfat)
        mkfs.exfat -n "USB" "$DEV"
        ;;
    ext4)
        mkfs.ext4 -L "USB" "$DEV"
        ;;
    *)
        echo "Error: Unsupported filesystem: $FSTYPE (use vfat, exfat, ext4)"
        exit 1
        ;;
esac

echo "Format complete: $DEV as $FSTYPE"
