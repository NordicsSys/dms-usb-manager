import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

/**
 * USBManagerPanel - Main UI modal for USB drive management.
 * Lists connected USB drives with Mount/Unmount, Eject, Format, Resize actions.
 */
DankModal {
    id: root

    layerNamespace: "dms:plugins:usbManager"
    keepPopoutsOpen: true

    property var formatDevice: null
    property var resizeDevice: null

    function openPanel() {
        backgroundOpacity = 0.5;
        open();
        USBManagerService.refreshDevices();
    }

    function closePanel() {
        close();
    }

    shouldBeVisible: false
    width: 420
    height: 480
    enableShadow: true
    positioning: "center"
    onBackgroundClicked: () => close()

    content: Component {
        Item {
            anchors.fill: parent
            implicitHeight: contentColumn.implicitHeight + Theme.spacingL * 2

            Column {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "usb"
                        size: Theme.iconSize + 4
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: "USB Drives"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    DankActionButton {
                        iconName: "refresh"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.surfaceText
                        onClicked: USBManagerService.refreshDevices()
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.surfaceText
                        onClicked: closePanel()
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

                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
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
                                        iconName: modelData.mountpoint ? "folder_open" : "usb"
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
            }
        }
    }

    function showFormatDialog(device) {
        formatDevice = device;
        formatDialog.open();
    }

    function showResizeDialog(device) {
        root.resizeDevice = device;
        resizeDialog.device = device;
        resizeDialog.open();
    }

    FormatDialog {
        id: formatDialog
        device: root.formatDevice
        onAccepted: function(fsType) {
            if (root.formatDevice) {
                USBManagerService.formatDevice(root.formatDevice.device, fsType, () => {});
            }
            root.formatDevice = null;
        }
        onRejected: root.formatDevice = null
    }

    ResizeDialog {
        id: resizeDialog
        device: root.resizeDevice
        onAccepted: function(newSize) {
            if (resizeDialog.device) {
                USBManagerService.resizePartition(resizeDialog.device.device, newSize, () => {});
            }
        }
    }
}
