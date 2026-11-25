import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import

// VPN submenu (level 1 of NetworkPopup, #9): one captioned group per enabled
// backend, each listing its profiles with a switch. Binds only to VpnService.
Item {
    id: page
    property var popup

    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Config.wifi.sectionGap

        BackHeader { onBack: page.popup.back() }

        Text {
            height: 24; verticalAlignment: Text.AlignVCenter
            text: "VPN"; color: Theme.foreground; font.pixelSize: 15
        }

        Repeater {
            model: VpnService.groups
            Column {
                id: group
                required property var modelData
                width: col.width
                spacing: 2

                Text {
                    text: group.modelData.displayName
                    font.pixelSize: 10; color: Theme.foregroundDim
                    font.capitalization: Font.AllUppercase
                }
                Repeater {
                    model: group.modelData.profiles
                    VpnRow {
                        required property var modelData
                        width: group.width
                        backendId: group.modelData.backendId
                        profile: modelData
                    }
                }
            }
        }
    }
}
