# USB Manager (DankMaterialShell)

Bar widget for removable USB drives: list devices, mount/unmount, eject, format (FAT32 / exFAT / ext4), and resize partitions. A background daemon watches `udisksctl` and shows connect/disconnect notifications.

## Requirements

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) with plugin support
- `udisks2` (`udisksctl`), `lsblk`, `bash`
- For format/resize: `parted`, `mkfs.vfat` / `mkfs.exfat` / `mkfs.ext4`, `resize2fs` (ext4), Polkit/agent for privileged operations

## Install

### DMS Plugins UI

Settings (e.g. **Mod+,**) → **Plugins** → **Browse** → install **USB Manager** once it appears in the registry.

### Manual

```bash
git clone https://github.com/NordicsSys/dms-usb-manager.git \
  ~/.config/DankMaterialShell/plugins/USBManager
dms restart   # or reload your session
```

Enable **USB Manager** and its daemon in plugin settings.

## Repository layout

| Path | Role |
|------|------|
| `plugin.json` | Plugin manifest |
| `USBManager.qml` | Bar widget |
| `daemon.qml` | Background monitor + notifications |
| `main.qml` | Panel UI |
| `helpers/*.sh` | List/mount/format/resize helpers |

## License

See [LICENSE](LICENSE).
