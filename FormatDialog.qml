import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

/**
 * FormatDialog - Confirmation dialog for formatting a USB drive.
 * Requires user to type "FORMAT" to proceed.
 */
Rectangle {
    id: root

    property var device: null
    signal accepted(string fsType)
    signal rejected

    property string selectedFsType: "vfat"

    visible: false
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)

    function open() {
        confirmInput.text = "";
        selectedFsType = "vfat";
        visible = true;
    }

    function close() {
        visible = false;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: { /* block click-through */ }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 340
        height: contentCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

        Column {
            id: contentCol
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Format USB Drive"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                visible: root.device
                text: (root.device ? (root.device.label || root.device.name || root.device.device) : "") + " — All data will be lost!"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                wrapMode: Text.WordWrap
                width: parent.width - Theme.spacingL * 2
            }

            Row {
                spacing: Theme.spacingS
                StyledText {
                    text: "Filesystem:"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: [
                            { text: "FAT32", value: "vfat" },
                            { text: "exFAT", value: "exfat" },
                            { text: "ext4", value: "ext4" }
                        ]
                        delegate: DankButton {
                            text: modelData.text
                            font.pixelSize: Theme.fontSizeSmall
                            onClicked: root.selectedFsType = modelData.value
                        }
                    }
                }
            }

            StyledText {
                text: "Type FORMAT to confirm:"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: confirmInput
                width: parent.width - Theme.spacingL * 2
                placeholderText: "FORMAT"
            }

            Row {
                spacing: Theme.spacingS
                DankButton {
                    text: "Cancel"
                    onClicked: {
                        root.close();
                        root.rejected();
                    }
                }
                DankButton {
                    text: "Format"
                    iconName: "format_paint"
                    enabled: confirmInput.text === "FORMAT"
                    onClicked: {
                        if (confirmInput.text === "FORMAT") {
                            root.close();
                            root.accepted(root.selectedFsType);
                        }
                    }
                }
            }
        }
    }
}
