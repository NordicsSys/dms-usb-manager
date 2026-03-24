#!/usr/bin/env bash
# USB Manager helper - list removable USB drives using lsblk
# Only returns devices where RM=1 (removable)
# Usage: usb_manager.sh list | last-added

list_devices() {
    # IMPORTANT:
    # - For partitions (e.g. sda1), `lsblk -o TRAN` is often blank.
    # - So we filter using the parent disk transport instead.
    #
    # Returns a JSON array of partition nodes representing "removable USB drives".
    local result="["
    local first=1

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        NAME="" RM="" SIZE="" MOUNTPOINT="" LABEL=""
        eval "$line"

        # Keep only removable nodes.
        [[ "$RM" == "1" ]] || continue
        [[ -b "/dev/$NAME" ]] || continue

        # Keep only partitions.
        [[ "$NAME" =~ [0-9]+$ ]] || continue
        [[ "$NAME" =~ ^(loop|ram) ]] && continue

        parent_disk="$(echo "$NAME" | sed 's/[0-9]*$//')"
        [[ -n "$parent_disk" ]] || continue

        # Only allow real USB transport (from parent disk).
        parent_tran="$(lsblk -o TRAN -n "/dev/$parent_disk" 2>/dev/null | awk 'NF{print; exit}' | xargs)"
        [[ "$parent_tran" == usb* ]] || continue

        # JSON-escape.
        label="${LABEL//\\/\\\\}"
        label="${label//\"/\\\"}"
        mountpoint="${MOUNTPOINT//\\/\\\\}"
        mountpoint="${mountpoint//\"/\\\"}"
        size="${SIZE//\\/\\\\}"

        [[ $first -eq 0 ]] && result+=","
        first=0
        result+="{\"device\":\"/dev/$NAME\",\"name\":\"$NAME\",\"label\":\"$label\",\"size\":\"$size\",\"mountpoint\":\"$mountpoint\"}"
    done < <(lsblk -o NAME,RM,SIZE,MOUNTPOINT,LABEL -P 2>/dev/null)

    result+="]"
    echo "$result"
}

last_added() {
    local last=""
    local last_time=0
    for dev in /dev/sd[a-z][0-9]* /dev/nvme[0-9]n[0-9]p[0-9]* /dev/mmcblk[0-9]p[0-9]*; do
        [[ -b "$dev" ]] || continue
        base="${dev##*/}"
        parent="${base%%[0-9]*}"
        [[ -f "/sys/block/$parent/removable" ]] || continue
        [[ "$(cat "/sys/block/$parent/removable" 2>/dev/null)" == "1" ]] || continue
        # TRAN is often blank on partitions, so check the parent disk.
        tran=$(lsblk -o TRAN -n "/dev/$parent" 2>/dev/null | awk 'NF{print; exit}' | xargs)
        [[ "$tran" == usb* ]] || continue
        t=$(stat -c %Y "$dev" 2>/dev/null || echo 0)
        [[ $t -le $last_time ]] && continue
        last_time=$t
        label=$(lsblk -o LABEL -n "$dev" 2>/dev/null | tail -1 | xargs)
        size=$(lsblk -o SIZE -n "$dev" 2>/dev/null | tail -1 | xargs)
        last="{\"device\":\"$dev\",\"name\":\"$base\",\"label\":\"$label\",\"size\":\"$size\"}"
    done
    echo "$last"
}

case "${1:-list}" in
    list)   list_devices ;;
    last-added) last_added ;;
    *)      echo "[]" ;;
esac
