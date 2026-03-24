import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services

/**
 * USBManagerPopout - Device list shown in bar popout.
 */
Item {
    id: root

    property var formatDevice: null
    property var resizeDevice: null

    Column {
        id: contentColumn
        anchors.fill: parent
        spacing: Theme.spacingM

        Row {
            width: root.width - Theme.spacingM * 2
            spacing: Theme.spacingM

            DankIcon {
                name: "usb"
                size: Theme.iconSize + 4
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "USB Drives"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 1; Layout.fillWidth: true }

            DankActionButton {
                iconName: "refresh"
                iconSize: Theme.iconSize - 2
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
            width: root.width - Theme.spacingM * 2
            height: Math.min(320, USBManagerService.devices.length * 100)
            clip: true
            spacing: Theme.spacingS
            model: USBManagerService.devices

            delegate: Rectangle {
                width: ListView.view.width
                height: 96
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "sim_card"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSize - Theme.spacingM * 4 - actionRow.width

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
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        DankActionButton {
                            iconName: modelData.mountpoint ? "eject" : "folder_open"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: {
                                if (modelData.mountpoint) {
                                    USBManagerService.unmount(modelData.device);
                                } else {
                                    USBManagerService.mount(modelData.device);
                                }
                            }
                        }

                        DankActionButton {
                            iconName: "power_settings_new"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: USBManagerService.eject(modelData.device)
                        }

                        DankActionButton {
                            iconName: "format_paint"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.showFormatDialog(modelData)
                        }

                        DankActionButton {
                            iconName: "aspect_ratio"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.showResizeDialog(modelData)
                        }
                    }
                }
            }
        }
    }

    function showFormatDialog(device) {
        formatDevice = device;
        formatDialog.device = device;
        formatDialog.open();
    }

    function showResizeDialog(device) {
        resizeDevice = device;
        resizeDialog.device = device;
        resizeDialog.open();
    }

    FormatDialog {
        id: formatDialog
        anchors.fill: parent
        visible: false
        onAccepted: function(fsType) {
            if (formatDevice) {
                USBManagerService.formatDevice(formatDevice.device, fsType, () => {});
            }
            formatDevice = null;
        }
        onRejected: formatDevice = null
    }

    ResizeDialog {
        id: resizeDialog
        anchors.fill: parent
        visible: false
        onAccepted: function(newSize) {
            if (resizeDialog.device) {
                USBManagerService.resizePartition(resizeDialog.device.device, newSize, () => {});
            }
        }
    }
}
