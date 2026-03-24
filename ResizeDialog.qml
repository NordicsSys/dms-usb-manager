import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

/**
 * ResizeDialog - Confirmation dialog for resizing a partition.
 * Requires user to type "RESIZE" to proceed.
 */
Rectangle {
    id: root

    property var device: null
    signal accepted(string newSize)
    signal rejected

    visible: false
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)

    function open() {
        sizeInput.text = "";
        confirmInput.text = "";
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
                text: "Resize Partition"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                visible: root.device
                text: (root.device ? (root.device.label || root.device.name || root.device.device) : "") + " — This can cause data loss!"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                wrapMode: Text.WordWrap
                width: parent.width - Theme.spacingL * 2
            }

            StyledText {
                text: "New size (e.g. 16G, 100%, max):"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: sizeInput
                width: parent.width - Theme.spacingL * 2
                placeholderText: "max"
            }

            StyledText {
                text: "Type RESIZE to confirm:"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankTextField {
                id: confirmInput
                width: parent.width - Theme.spacingL * 2
                placeholderText: "RESIZE"
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
                    text: "Resize"
                    iconName: "aspect_ratio"
                    enabled: confirmInput.text === "RESIZE" && sizeInput.text.length > 0
                    onClicked: {
                        if (confirmInput.text === "RESIZE" && sizeInput.text.length > 0) {
                            root.close();
                            root.accepted(sizeInput.text);
                        }
                    }
                }
            }
        }
    }
}
