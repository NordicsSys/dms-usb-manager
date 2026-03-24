import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

/**
 * USBManager widget - Bar pill + popout with device list + notifications.
 */
PluginComponent {
    id: root

    // Compact bar pill; keep popout usable but not huge.
    popoutWidth: 280
    popoutHeight: 260

    horizontalBarPill: Component {
        // Icon-only pill to keep the widget compact (~square in the bar).
        DankIcon {
            name: "usb"
            color: USBManagerService.devices.length > 0 ? Theme.primary : Theme.surfaceVariantText
            size: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    verticalBarPill: Component {
        // Icon-only vertical pill.
        DankIcon {
            name: "usb"
            color: USBManagerService.devices.length > 0 ? Theme.primary : Theme.surfaceVariantText
            size: root.iconSize
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    popoutContent: Component {
        PopoutComponent {
            width: popoutWidth
            height: popoutHeight - Theme.spacingS * 2

            Column {
                id: contentColumn
                width: parent.width - Theme.spacingS * 2
                height: parent.height - Theme.spacingS * 2
                x: Theme.spacingS
                y: Theme.spacingS
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "usb"
                        size: Theme.iconSize + 2
                        color: Theme.primary
                    }

                    StyledText {
                        text: "USB Drives"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Item { width: 1 }

                    DankActionButton {
                        iconName: "refresh"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: USBManagerService.refreshDevices()
                    }
                }

                StyledText {
                    visible: USBManagerService.isLoading
                    text: "Loading..."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    visible: !USBManagerService.isLoading && USBManagerService.devices.length === 0
                    text: "No USB drives connected"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }

                ListView {
                    visible: !USBManagerService.isLoading && USBManagerService.devices.length > 0
                    width: parent.width
                    height: Math.max(80, USBManagerService.devices.length * 82)
                    clip: true
                    spacing: Theme.spacingS
                    model: USBManagerService.devices

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 80
                        radius: Math.max(2, Theme.cornerRadius - 2)
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 0.6

                        Row {
                            width: parent.width - Theme.spacingS * 2
                            height: parent.height - Theme.spacingS * 2
                            x: Theme.spacingS
                            y: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "sim_card"
                                size: Theme.iconSize
                                color: Theme.primary
                            }

                            Column {
                                spacing: 1
                                width: parent.width - Theme.iconSize - Theme.spacingS * 4 - actionRow.width

                                StyledText {
                                    text: modelData.label || modelData.name || modelData.device || "USB Drive"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                StyledText {
                                    text: (modelData.size || "") + (modelData.mountpoint ? " · " + modelData.mountpoint : "")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            Row {
                                id: actionRow
                                spacing: 3

                                DankActionButton {
                                    // "Folder" button: if mounted -> open file manager, else -> mount
                                    iconName: "folder_open"
                                    iconSize: Theme.iconSize - 4
                                    iconColor: Theme.surfaceText
                                    onClicked: {
                                        if (modelData.mountpoint && modelData.mountpoint.length > 0) {
                                            openInFileManager(modelData.mountpoint);
                                        } else {
                                            USBManagerService.mount(modelData.device, function(ok, out) {
                                                if (!ok) {
                                                    const line = (out || "").trim().split("\n")[0];
                                                    sendUsbNotification("USB Mount failed", line ? line : "No output");
                                                    return;
                                                }
                                                // After mount, refresh list and open the new mountpoint.
                                                USBManagerService.refreshDevices();
                                                Qt.callLater(() => {
                                                    const updated = USBManagerService.devices.find(d => d.device === modelData.device);
                                                    if (updated && updated.mountpoint && updated.mountpoint.length > 0) {
                                                        openInFileManager(updated.mountpoint);
                                                    } else {
                                                        sendUsbNotification("USB Mounted", modelData.label || modelData.name || modelData.device);
                                                    }
                                                });
                                            });
                                        }
                                    }
                                }

                                DankActionButton {
                                    iconName: "power_settings_new"
                                    iconSize: Theme.iconSize - 4
                                    iconColor: Theme.surfaceText
                                    onClicked: USBManagerService.eject(modelData.device, function(ok, out) {
                                        if (!ok) {
                                            const line = (out || "").trim().split("\n")[0];
                                            sendUsbNotification("USB Eject failed", line ? line : "No output");
                                        } else {
                                            sendUsbNotification("USB Ejected", modelData.label || modelData.name || modelData.device);
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: udisksMonitor
        command: ["udisksctl", "monitor"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                const l = line.trim();
                if ((l.includes("Added") || l.includes("InterfacesAdded")) && (l.includes("block_devices") || l.includes("Block"))) {
                    Qt.callLater(() => onDeviceAdded());
                } else if ((l.includes("Removed") || l.includes("InterfacesRemoved")) && (l.includes("block_devices") || l.includes("Block"))) {
                    Qt.callLater(() => onDeviceRemoved());
                }
            }
        }

        stderr: SplitParser {
            onRead: line => { if (line.trim()) console.warn("USBManager monitor:", line); }
        }

        onExited: exitCode => {
            if (exitCode !== 0) Qt.callLater(() => { udisksMonitor.running = true; });
        }
    }

    function onDeviceAdded() {
        USBManagerService.refreshDevices();
    }

    function onDeviceRemoved() {
        USBManagerService.refreshDevices();
    }

    function sendUsbNotification(title, message) {
        // Use DMS notifier because notify-send might not be installed.
        Quickshell.execDetached(["dms", "notify", title, message, "--icon", "usb", "--app", "DankMaterialShell", "--timeout", "5000"]);
    }

    function openInFileManager(mountpoint) {
        if (!mountpoint || mountpoint.length === 0)
            return;
        // Opens the default file manager at the USB mount path.
        // We try `gio open` first (works well on desktop), then fallback to `pcmanfm-qt`, then `xdg-open`.
        const safe = String(mountpoint).replace(/'/g, "'\\''");
        Quickshell.execDetached([
            "bash",
            "-c",
            "gio open '" + safe + "' >/dev/null 2>&1 || (command -v pcmanfm-qt >/dev/null 2>&1 && pcmanfm-qt '" + safe + "' >/dev/null 2>&1) || xdg-open '" + safe + "' >/dev/null 2>&1"
        ]);
    }

    function revealWidget() {
        // Show the widget popout automatically on USB connect.
        Quickshell.execDetached(["dms", "ipc", "widget", "reveal", "usbManager"]);
    }

    property var _devicePaths: []
    property bool _initialized: false
    Connections {
        target: USBManagerService
        function onDevicesUpdated() {
            const devices = USBManagerService.devices;
            const newPaths = devices.map(d => d.device);

            if (!root._initialized) {
                root._devicePaths = newPaths;
                root._initialized = true;
                return;
            }

            const prevPaths = root._devicePaths;
            const added = devices.filter(d => prevPaths.indexOf(d.device) === -1);
            const removed = prevPaths.filter(p => newPaths.indexOf(p) === -1);

            if (added.length > 0) {
                const d = added[0];
                const label = d.label || d.name || "USB Drive";
                const size = d.size || "";
                sendUsbNotification("USB Drive Connected", label + (size ? " (" + size + ")" : ""));
                revealWidget();
            } else if (removed.length > 0) {
                sendUsbNotification("USB Drive Removed", "A USB drive was safely removed");
            }

            root._devicePaths = newPaths;
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: USBManagerService.refreshDevices()
    }

    Component.onCompleted: {
        USBManagerService.refreshDevices();
    }
}
