#!/usr/bin/env bash
# Resize a partition on a removable USB device. Called via pkexec for root.
# Usage: resize.sh <partition_device> <new_size>
# new_size: e.g. 16G, 100%, max
# SAFETY: Only allows removable devices.

# Route stderr into stdout so callers (DMS Proc.runCommand) capture the full error text.
exec 2>&1

set -e

DEV="${1:?Missing device}"
NEWSIZE="${2:?Missing new size}"

# Block system disks
if [[ ! "$DEV" =~ ^/dev/(sd[a-z][0-9]+|nvme[0-9]+n[0-9]+p[0-9]+|mmcblk[0-9]+p[0-9]+)$ ]]; then
    echo "Error: Invalid or non-removable device: $DEV"
    exit 1
fi

# Verify removable (sda1->sda, nvme0n1p1->nvme0n1, mmcblk0p1->mmcblk0)
PARENT=$(echo "${DEV##*/}" | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')
PARENT="/sys/block/$PARENT"
PARENT_DISK="$(basename "$PARENT")"

# Safety: require USB transport on the parent disk.
TRAN_PARENT="$(lsblk -o TRAN -n "/dev/$PARENT_DISK" 2>/dev/null | awk 'NF{print; exit}' | xargs)"
if [[ ! "$TRAN_PARENT" =~ ^usb ]]; then
    echo "Error: Refusing to resize non-USB disk /dev/$PARENT_DISK (transport: ${TRAN_PARENT:-unknown}). Only USB devices are allowed."
    exit 1
fi
if [[ -f "$PARENT/removable" ]]; then
    REM=$(cat "$PARENT/removable" 2>/dev/null)
    if [[ "$REM" != "1" ]]; then
        echo "Error: Device $DEV is not marked as removable. Refusing to resize."
        exit 1
    fi
else
    echo "Error: Cannot verify removable status for $DEV (sysfs entry missing). Refusing to resize."
    exit 1
fi

# Unmount first
umount "$DEV" 2>/dev/null || true
udisksctl unmount -b "$DEV" 2>/dev/null || true

# Get partition number and disk
DISK=$(lsblk -no PKNAME "$DEV" 2>/dev/null | head -1)
[[ -n "$DISK" ]] || DISK="$PARENT_DISK"
DISK="/dev/$DISK"
# Extract partition number: sda1->1, nvme0n1p1->1, mmcblk0p1->1
PARTNUM=$(echo "${DEV##*/}" | grep -oE '[0-9]+$' | head -1)

# Use parted to resize; capture output to give user a readable error.
PARTED_OUT=""
if [[ "$NEWSIZE" == "max" ]] || [[ "$NEWSIZE" == "100%" ]]; then
    PARTED_OUT=$(parted -s "$DISK" resizepart "$PARTNUM" 100% 2>&1) || {
        if echo "$PARTED_OUT" | grep -qi "overlapping"; then
            echo "Error: Cannot resize — another partition is blocking the free space. Check the partition layout of $DISK."
        else
            echo "Error resizing partition: $PARTED_OUT"
        fi
        exit 1
    }
else
    PARTED_OUT=$(parted -s "$DISK" resizepart "$PARTNUM" "$NEWSIZE" 2>&1) || {
        if echo "$PARTED_OUT" | grep -qi "overlapping"; then
            echo "Error: Cannot resize — another partition is blocking. Try a smaller size."
        else
            echo "Error resizing partition: $PARTED_OUT"
        fi
        exit 1
    }
fi

# Expand the filesystem to fill the new partition size.
FSTYPE=$(lsblk -o FSTYPE -n "$DEV" 2>/dev/null | tail -1)
if [[ "$FSTYPE" == "ext4" ]]; then
    resize2fs "$DEV" 2>&1 || { echo "Error: Partition resized but filesystem resize failed."; exit 1; }
elif [[ "$FSTYPE" == "vfat" ]]; then
    if command -v fatresize >/dev/null 2>&1; then
        fatresize -s max "$DEV" 2>&1 || echo "Warning: Partition resized but FAT32 filesystem resize failed. You may need to reformat."
    else
        echo "Warning: Partition resized but fatresize is not installed. The FAT32 filesystem was not expanded — reformat to use the full space."
    fi
elif [[ -n "$FSTYPE" && "$FSTYPE" != "exfat" ]]; then
    echo "Warning: Partition resized but automatic filesystem resize is not supported for $FSTYPE."
else
    [[ "$FSTYPE" == "exfat" ]] && echo "Warning: Partition resized but exFAT does not support in-place resize. Reformat to use the full space."
fi

echo "Resize complete: $DEV"
