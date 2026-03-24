import QtQuick
import Quickshell.Io
import qs.Services
import qs.Modules.Plugins

/**
 * USBManager daemon - Background service + IPC for opening the UI panel.
 * Monitors udisksctl for USB add/remove events and sends notifications.
 * Opens main.qml (USBManagerPanel) when IPC "open" is called.
 */
PluginComponent {
    id: root

    Item {}

    Loader {
        id: panelLoader
        source: Qt.resolvedUrl("main.qml")
        asynchronous: false
    }

    IpcHandler {
        function open(): string {
            USBManagerService.refreshDevices();
            if (panelLoader.item) panelLoader.item.openPanel();
            return "USB_MANAGER_OPEN_SUCCESS";
        }

        function close(): string {
            if (panelLoader.item) panelLoader.item.closePanel();
            return "USB_MANAGER_CLOSE_SUCCESS";
        }

        function toggle(): string {
            if (panelLoader.item && panelLoader.item.visible) return close();
            return open();
        }

        target: "usbManager"
    }

    // Monitor udisksctl for add/remove events (only removable USB)
    Process {
        id: udisksMonitor
        command: ["udisksctl", "monitor"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                const l = line.trim();
                // Look for Added/Removed on block devices
                if (l.includes("Added") && l.includes("/org/freedesktop/UDisks2/block_devices/")) {
                    Qt.callLater(() => onDeviceAdded());
                } else if (l.includes("Removed") && l.includes("/org/freedesktop/UDisks2/block_devices/")) {
                    Qt.callLater(() => onDeviceRemoved());
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim()) console.warn("USBManager udisksctl:", line);
            }
        }

        onExited: exitCode => {
            console.warn("USBManager: udisksctl monitor exited with", exitCode);
            if (exitCode !== 0) Qt.callLater(() => { udisksMonitor.running = true; });
        }
    }

    function onDeviceAdded() {
        USBManagerService.refreshDevices();
        // Small delay so lsblk sees the new device
        delayNotify.restart();
    }

    Timer {
        id: delayNotify
        interval: 800
        repeat: false
        onTriggered: {
            Proc.runCommand("usbManager:lastAdded", ["bash", USBManagerService.pluginDir + "/helpers/usb_manager.sh", "last-added"], (output, exitCode) => {
                if (exitCode === 0 && output && output.trim()) {
                    try {
                        const d = JSON.parse(output);
                        const label = d.label || d.name || "USB Drive";
                        const size = d.size || "";
                        USBManagerService.sendNotification("USB Drive Connected", label + (size ? " (" + size + ")" : ""), "normal");
                    } catch (_) {
                        USBManagerService.sendNotification("USB Drive Connected", "New removable drive detected", "normal");
                    }
                }
            });
        }
    }

    function onDeviceRemoved() {
        USBManagerService.sendNotification("USB Drive Removed", "A USB drive was safely removed", "normal");
        USBManagerService.refreshDevices();
    }

    Component.onCompleted: {
        console.log("USBManager: Daemon started, monitoring USB devices");
        USBManagerService.refreshDevices();
    }

    Component.onDestruction: {
        console.log("USBManager: Daemon stopped");
    }
}
