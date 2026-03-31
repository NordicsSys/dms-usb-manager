import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "usbManager"

    StyledText {
        text: "USB Manager"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Monitor USB drives, mount/unmount, format, and resize partitions. Open via: dms ipc call usbManager open"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Usage"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        text: "• Open panel: dms ipc call usbManager open\n• Toggle: dms ipc call usbManager toggle\n• Add to launcher or keybind for quick access"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Requirements"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        text: "• udisksctl, lsblk, udisks2\n• jq (optional, for better JSON)\n• pkexec for format/resize (sudo)"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }
}
