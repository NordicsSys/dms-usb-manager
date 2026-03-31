pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Common
import qs.Services

/**
 * USBManagerService - Singleton for USB device state and operations.
 * Uses helpers/usb_manager.sh to list removable USB drives.
 * Only exposes devices where RM=1 (removable).
 */
Singleton {
    id: root

    property var devices: []
    property bool isLoading: false
    signal devicesUpdated()

    // Resolved at startup: DMS installs to ~/.config/DankMaterialShell/plugins/<id> (usbManager).
    // Fall back to USBManager for older/case-mismatched checkouts on case-sensitive filesystems.
    property string pluginDir: ""
    property bool _pluginDirReady: false

    function refreshDevices() {
        if (!_pluginDirReady || !pluginDir)
            return;
        isLoading = true;
        Proc.runCommand("usbManager:list", ["bash", pluginDir + "/helpers/usb_manager.sh", "list"], (output, exitCode) => {
            isLoading = false;
            if (exitCode !== 0) {
                console.error("USBManager: list failed:", output);
                ToastService.showError("USB Manager", "Failed to list USB devices.");
                return;
            }
            try {
                const arr = JSON.parse(output || "[]");
                root.devices = arr;
                root.devicesUpdated();
            } catch (e) {
                console.error("USBManager: parse error", e);
                root.devices = [];
            }
        });
    }

    function mount(devicePath, callback) {
        // Use udisksctl directly so it can rely on normal polkit rules/caching.
        Proc.runCommand(null, ["udisksctl", "mount", "-b", devicePath], (out, code) => {
            if (callback) callback(code === 0, out);
            if (code === 0) {
                ToastService.showInfo("USB Manager", "Mounted successfully");
                refreshDevices();
            } else {
                ToastService.showError("USB Manager", out || "Mount failed");
            }
        });
    }

    function unmount(devicePath, callback) {
        // Use udisksctl directly so it can rely on normal polkit rules/caching.
        Proc.runCommand(null, ["udisksctl", "unmount", "-b", devicePath], (out, code) => {
            if (callback) callback(code === 0, out);
            if (code === 0) {
                ToastService.showInfo("USB Manager", "Unmounted successfully");
                refreshDevices();
            } else {
                ToastService.showError("USB Manager", out || "Unmount failed");
            }
        });
    }

    function eject(devicePath, callback) {
        // For partitions, udisksctl "power-off" should usually target the parent block device.
        // Flow: unmount partition -> power-off parent disk.
        Proc.runCommand(null, ["lsblk", "-no", "PKNAME", devicePath], (pkOut, pkCode) => {
            const pkname = (pkOut || "").trim();
            const parentDevice = pkname ? ("/dev/" + pkname) : devicePath;

            // Unmount partition first (ignore errors; might already be unmounted).
            Proc.runCommand(null, ["udisksctl", "unmount", "-b", devicePath], (unOut, unCode) => {
                Proc.runCommand(null, ["udisksctl", "power-off", "-b", parentDevice], (out, code) => {
                    const msg = out || ((code !== 0) ? ("Eject failed (exit code " + code + ")") : "");
                    if (callback) callback(code === 0, msg);
                    if (code === 0) {
                        ToastService.showInfo("USB Manager", "Ejected successfully");
                        refreshDevices();
                    } else {
                        ToastService.showError("USB Manager", msg || "Eject failed");
                    }
                });
            });
        });
    }

    function formatDevice(devicePath, fsType, callback) {
        Proc.runCommand(null, ["pkexec", "bash", pluginDir + "/helpers/format.sh", devicePath, fsType], (out, code) => {
            if (callback) callback(code === 0, out);
            if (code === 0) {
                ToastService.showInfo("USB Manager", "Format completed successfully");
                refreshDevices();
            } else {
                ToastService.showError("USB Manager", out || "Format failed");
            }
        });
    }

    function resizePartition(devicePath, newSize, callback) {
        Proc.runCommand(null, ["pkexec", "bash", pluginDir + "/helpers/resize.sh", devicePath, newSize], (out, code) => {
            if (callback) callback(code === 0, out);
            if (code === 0) {
                ToastService.showInfo("USB Manager", "Resize completed successfully");
                refreshDevices();
            } else {
                ToastService.showError("USB Manager", out || "Resize failed");
            }
        });
    }

    Component.onCompleted: {
        const resolveSh =
            'base="$HOME/.config/DankMaterialShell/plugins"\n' +
            'for n in usbManager USBManager; do\n' +
            '  if [ -f "$base/$n/helpers/usb_manager.sh" ]; then\n' +
            '    printf %s "$base/$n"\n' +
            '    exit 0\n' +
            '  fi\n' +
            'done\n' +
            'printf %s "$base/usbManager"\n';
        Proc.runCommand("usbManager:resolveDir", ["bash", "-c", resolveSh], (output, exitCode) => {
            const home = Quickshell.env("HOME");
            const fallback = home + "/.config/DankMaterialShell/plugins/usbManager";
            const resolved = (output || "").trim();
            root.pluginDir = resolved.length > 0 ? resolved : fallback;
            root._pluginDirReady = true;
            refreshDevices();
        });
    }
}
