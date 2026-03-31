import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services

/**
 * USBManagerPopout - Bar popout: device list, mount/eject/format/resize flows.
 */
PopoutComponent {
    id: popoutRoot
    function sendUsbNotification(title, message) {
        Quickshell.execDetached(["dms", "notify", title, message, "--icon", "usb", "--app", "DankMaterialShell", "--timeout", "5000"]);
    }

    function openInFileManager(mountpoint) {
        if (!mountpoint || mountpoint.length === 0)
            return;
        const safe = String(mountpoint).replace(/'/g, "'\\''");
        Quickshell.execDetached([
            "bash",
            "-c",
            "gio open '" + safe + "' >/dev/null 2>&1 || (command -v pcmanfm-qt >/dev/null 2>&1 && pcmanfm-qt '" + safe + "' >/dev/null 2>&1) || xdg-open '" + safe + "' >/dev/null 2>&1"
        ]);
    }

    // "list" | "format" | "resize"
    property string currentView: "list"
    property var activeDevice: null
    property string selectedFsType: "vfat"

    function goToFormat(device) {
        activeDevice = device;
        selectedFsType = "vfat";
        formatConfirmInput.text = "";
        currentView = "format";
    }

    function goToResize(device) {
        activeDevice = device;
        resizeSizeInput.text = "";
        resizeConfirmInput.text = "";
        currentView = "resize";
    }

    function backToList() {
        formatConfirmInput.text = "";
        resizeSizeInput.text = "";
        resizeConfirmInput.text = "";
        activeDevice = null;
        currentView = "list";
    }

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingS * 2
        x: Theme.spacingS
        y: Theme.spacingS
        spacing: Theme.spacingS

        // ── Header ──────────────────────────────────────
        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            DankActionButton {
                visible: popoutRoot.currentView !== "list"
                iconName: "arrow_back"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                tooltipText: "Back"
                tooltipSide: "bottom"
                onClicked: popoutRoot.backToList()
            }

            DankIcon {
                visible: popoutRoot.currentView === "list"
                name: "usb"
                size: Theme.iconSize + 2
                color: Theme.primary
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: popoutRoot.currentView === "format" ? "Format Drive"
                    : popoutRoot.currentView === "resize" ? "Resize Partition"
                    : "USB Drives"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            DankActionButton {
                visible: popoutRoot.currentView === "list"
                iconName: "refresh"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                tooltipText: "Refresh"
                tooltipSide: "bottom"
                onClicked: USBManagerService.refreshDevices()
            }
        }

        // ── List view ───────────────────────────────────
        StyledText {
            visible: popoutRoot.currentView === "list" && USBManagerService.isLoading
            text: "Loading..."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            visible: popoutRoot.currentView === "list" && !USBManagerService.isLoading && USBManagerService.devices.length === 0
            text: "No USB drives connected"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
        }

        ListView {
            visible: popoutRoot.currentView === "list" && !USBManagerService.isLoading && USBManagerService.devices.length > 0
            width: parent.width
            height: Math.min(200, Math.max(80, USBManagerService.devices.length * 82))
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
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter
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
                        anchors.verticalCenter: parent.verticalCenter

                        DankActionButton {
                            iconName: modelData.mountpoint && modelData.mountpoint.length > 0 ? "folder_open" : "usb"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            tooltipText: modelData.mountpoint && modelData.mountpoint.length > 0 ? "Open in file manager" : "Mount"
                            tooltipSide: "bottom"
                            onClicked: {
                                if (modelData.mountpoint && modelData.mountpoint.length > 0) {
                                    openInFileManager(modelData.mountpoint);
                                } else {
                                    const devPath = modelData.device;
                                    const devLabel = modelData.label || modelData.name || modelData.device;
                                    USBManagerService.mount(devPath, function(ok, out) {
                                        if (!ok) {
                                            const line = (out || "").trim().split("\n")[0];
                                            sendUsbNotification("USB Mount failed", line ? line : "No output");
                                            return;
                                        }
                                        function onRefreshed() {
                                            USBManagerService.devicesUpdated.disconnect(onRefreshed);
                                            const updated = USBManagerService.devices.find(d => d.device === devPath);
                                            if (updated && updated.mountpoint && updated.mountpoint.length > 0) {
                                                openInFileManager(updated.mountpoint);
                                            } else {
                                                sendUsbNotification("USB Mounted", devLabel);
                                            }
                                        }
                                        USBManagerService.devicesUpdated.connect(onRefreshed);
                                        USBManagerService.refreshDevices();
                                    });
                                }
                            }
                        }

                        DankActionButton {
                            iconName: "eject"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            tooltipText: "Eject"
                            tooltipSide: "bottom"
                            onClicked: USBManagerService.eject(modelData.device, function(ok, out) {
                                if (!ok) {
                                    const line = (out || "").trim().split("\n")[0];
                                    sendUsbNotification("USB Eject failed", line ? line : "No output");
                                } else {
                                    sendUsbNotification("USB Ejected", modelData.label || modelData.name || modelData.device);
                                }
                            })
                        }

                        DankActionButton {
                            iconName: "format_paint"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            tooltipText: "Format"
                            tooltipSide: "bottom"
                            onClicked: popoutRoot.goToFormat(modelData)
                        }

                        DankActionButton {
                            iconName: "aspect_ratio"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            tooltipText: "Resize"
                            tooltipSide: "bottom"
                            onClicked: popoutRoot.goToResize(modelData)
                        }
                    }
                }
            }
        }

        // ── Format form ─────────────────────────────────
        StyledText {
            visible: popoutRoot.currentView === "format" && popoutRoot.activeDevice !== null
            text: popoutRoot.activeDevice
                ? (popoutRoot.activeDevice.label || popoutRoot.activeDevice.name || popoutRoot.activeDevice.device) + "\nAll data will be erased!"
                : ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Row {
            visible: popoutRoot.currentView === "format"
            spacing: 4

            Repeater {
                model: [
                    { label: "FAT32", value: "vfat" },
                    { label: "exFAT", value: "exfat" },
                    { label: "ext4",  value: "ext4"  }
                ]
                delegate: DankButton {
                    text: modelData.label
                    buttonHeight: 32
                    backgroundColor: popoutRoot.selectedFsType === modelData.value
                        ? Theme.primaryContainer : Theme.buttonBg
                    textColor: popoutRoot.selectedFsType === modelData.value
                        ? Theme.primary : Theme.buttonText
                    onClicked: popoutRoot.selectedFsType = modelData.value
                }
            }
        }

        StyledText {
            visible: popoutRoot.currentView === "format"
            text: "Type FORMAT to confirm:"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DankTextField {
            id: formatConfirmInput
            visible: popoutRoot.currentView === "format"
            width: parent.width
            placeholderText: "FORMAT"
        }

        Row {
            visible: popoutRoot.currentView === "format"
            spacing: Theme.spacingS

            DankButton {
                text: "Cancel"
                buttonHeight: 36
                onClicked: popoutRoot.backToList()
            }

            DankButton {
                text: "Format"
                iconName: "format_paint"
                buttonHeight: 36
                enabled: formatConfirmInput.text === "FORMAT"
                onClicked: {
                    if (formatConfirmInput.text === "FORMAT" && popoutRoot.activeDevice) {
                        USBManagerService.formatDevice(popoutRoot.activeDevice.device, popoutRoot.selectedFsType, () => {});
                        popoutRoot.backToList();
                    }
                }
            }
        }

        // ── Resize form ─────────────────────────────────
        StyledText {
            visible: popoutRoot.currentView === "resize" && popoutRoot.activeDevice !== null
            text: popoutRoot.activeDevice
                ? (popoutRoot.activeDevice.label || popoutRoot.activeDevice.name || popoutRoot.activeDevice.device) + "\nThis can cause data loss!"
                : ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
            wrapMode: Text.WordWrap
            width: parent.width
        }

        StyledText {
            visible: popoutRoot.currentView === "resize"
            text: "New size (e.g. 16G, 100%, max):"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DankTextField {
            id: resizeSizeInput
            visible: popoutRoot.currentView === "resize"
            width: parent.width
            placeholderText: "max"
        }

        StyledText {
            visible: popoutRoot.currentView === "resize"
            text: "Type RESIZE to confirm:"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DankTextField {
            id: resizeConfirmInput
            visible: popoutRoot.currentView === "resize"
            width: parent.width
            placeholderText: "RESIZE"
        }

        Row {
            visible: popoutRoot.currentView === "resize"
            spacing: Theme.spacingS

            DankButton {
                text: "Cancel"
                buttonHeight: 36
                onClicked: popoutRoot.backToList()
            }

            DankButton {
                text: "Resize"
                iconName: "aspect_ratio"
                buttonHeight: 36
                enabled: resizeConfirmInput.text === "RESIZE" && resizeSizeInput.text.length > 0
                onClicked: {
                    if (resizeConfirmInput.text === "RESIZE" && resizeSizeInput.text.length > 0 && popoutRoot.activeDevice) {
                        USBManagerService.resizePartition(popoutRoot.activeDevice.device, resizeSizeInput.text, () => {});
                        popoutRoot.backToList();
                    }
                }
            }
        }
    }
}
