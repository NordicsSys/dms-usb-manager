#!/usr/bin/env bash
# Resize a partition on a removable USB device. Called via pkexec for root.
# Usage: resize.sh <partition_device> <new_size>
# new_size: e.g. 16G, 100%, max
# SAFETY: Only allows removable devices.

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

# Safety: refuse obvious internal disks misreported as removable.
# We only allow if the transport looks like USB.
TRAN_PARENT="$(lsblk -o TRAN -n "/dev/$PARENT_DISK" 2>/dev/null | awk 'NF{print; exit}' | xargs)"
if [[ "$PARENT_DISK" == "sda" && ! "$TRAN_PARENT" =~ ^usb ]]; then
    echo "Error: Refusing to resize system/internal disk /dev/$PARENT_DISK ($DEV)"
    exit 1
fi
if [[ -f "$PARENT/removable" ]]; then
    REM=$(cat "$PARENT/removable" 2>/dev/null)
    if [[ "$REM" != "1" ]]; then
        echo "Error: Device $DEV is not marked as removable. Refusing to resize."
        exit 1
    fi
fi

# Unmount first
umount "$DEV" 2>/dev/null || true
udisksctl unmount -b "$DEV" 2>/dev/null || true

# Get partition number and disk
DISK=$(lsblk -no PKNAME "$DEV" 2>/dev/null | head -1)
[[ -n "$DISK" ]] || DISK="${DEV%%[0-9]*}"
DISK="/dev/$DISK"
# Extract partition number: sda1->1, nvme0n1p1->1, mmcblk0p1->1
PARTNUM=$(echo "${DEV##*/}" | grep -oE '[0-9]+$' | head -1)

# Use parted to resize
if [[ "$NEWSIZE" == "max" ]] || [[ "$NEWSIZE" == "100%" ]]; then
    parted -s "$DISK" resizepart "$PARTNUM" 100%
else
    parted -s "$DISK" resizepart "$PARTNUM" "$NEWSIZE"
fi

# If ext4, run resize2fs
FSTYPE=$(lsblk -o FSTYPE -n "$DEV" 2>/dev/null | tail -1)
if [[ "$FSTYPE" == "ext4" ]]; then
    resize2fs "$DEV"
fi

echo "Resize complete: $DEV"
