import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/vpn.js" as Vpn

// One VPN profile on the VpnPage (#9): glyph, name over an optional status
// sub-line, and a switch. The switch shows the planner's view (on while
// connecting or pending); VpnService decides what a flip actually does.
Item {
    id: row
    property string backendId: ""
    property var profile: ({ id: "", name: "", state: "off" })
    readonly property string subline: Vpn.rowSubline(profile.state, VpnService.isPending(backendId, profile.id))

    implicitHeight: 36

    Text {
        id: icon
        anchors.left: parent.left; anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0582}"
        font.family: "Symbols Nerd Font"; font.pixelSize: 16
        color: row.profile.state === "connected" ? Theme.accent : Theme.foregroundDim
    }
    Column {
        anchors.left: icon.right; anchors.leftMargin: 10
        anchors.right: toggle.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
            width: parent.width; elide: Text.ElideRight
            text: row.profile.name; font.pixelSize: 13; color: Theme.foreground
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            visible: row.subline !== ""
            text: row.subline; font.pixelSize: 10
            color: row.profile.state === "failed" ? Theme.error : Theme.foregroundDim
        }
    }
    ToggleSwitch {
        id: toggle
        anchors.right: parent.right; anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        checked: VpnService.switchOn(row.backendId, row.profile.id, row.profile.state)
        onToggled: VpnService.toggle(row.backendId, row.profile.id)
    }
}
