import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/wired.js" as Wired

// Ethernet submenu (level 1 of NetworkPopup): one section per physical wired
// device that has link — read-only details plus a disconnect/reconnect switch.
Item {
    id: page
    property var popup

    implicitHeight: col.implicitHeight

    // "Label    value" row, same look as WifiDetail's InfoRow.
    component InfoRow: Item {
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 0; height: 22
        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: label; font.pixelSize: 12; color: Theme.foregroundDim
        }
        Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: value; font.pixelSize: 12; color: Theme.foreground
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Config.wifi.sectionGap

        BackHeader { onBack: page.popup.back() }

        Text {
            height: 24; verticalAlignment: Text.AlignVCenter
            text: "Ethernet"; color: Theme.foreground; font.pixelSize: 15
        }

        Repeater {
            model: WiredService.linked
            Column {
                id: section
                required property var modelData
                readonly property var dev: modelData
                readonly property string st: WiredService.stateString(dev)
                width: col.width
                spacing: 4

                DeviceInfo { id: info; iface: section.dev.name }
                onStChanged: if (st === "connected") info.refresh()
                Component.onCompleted: if (st === "connected") info.refresh()

                Item {
                    width: parent.width; height: 24
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: section.dev.name; color: Theme.foreground; font.pixelSize: 13
                    }
                    ToggleSwitch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: Wired.switchOn(section.st)
                        onToggled: checked ? WiredService.disconnect(section.dev)
                                           : WiredService.reconnect(section.dev)
                    }
                }
                InfoRow { label: "Status"; value: section.st.charAt(0).toUpperCase() + section.st.slice(1) }
                InfoRow { label: "Speed"; value: Wired.speedLabel(section.dev.linkSpeed) || "—" }
                InfoRow { label: "IPv4"; value: section.st === "connected" ? info.ip : "—" }
                InfoRow { label: "Gateway"; value: section.st === "connected" ? info.gateway : "—" }
                InfoRow { label: "DNS"; value: section.st === "connected" ? info.dns : "—" }
            }
        }
    }
}
