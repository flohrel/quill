import QtQuick
import qs.config      // qmllint disable import
import qs.services    // qmllint disable import
import "../../services/network.js" as Net
import "../../lib/format.js" as Format

// Right pill: control-center then power (power outermost). Active = accent.
Rectangle {
    id: pill
    property var controller
    implicitWidth: row.width + Config.shape.pillPaddingH * 2
    implicitHeight: Config.shape.barHeight
    radius: Config.shape.pillRadius
    color: Theme.surface

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Config.shape.iconSpacing

        Item {  // do-not-disturb: bell-off glyph + held-notification badge
            id: dndItem
            anchors.verticalCenter: parent.verticalCenter
            visible: NotificationService.dndAvailable && NotificationService.dnd
            implicitWidth: dndRow.implicitWidth
            implicitHeight: dndRow.implicitHeight
            Row {
                id: dndRow
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F009B}"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: Config.shape.iconSize
                    color: Theme.foreground
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NotificationService.heldCount > 0
                    text: NotificationService.heldCount
                    font.pixelSize: 12
                    color: Theme.accent
                }
            }
        }
        Item {  // battery: glyph + percentage; always visible when a battery is present
            id: batt
            anchors.verticalCenter: parent.verticalCenter
            visible: BatteryService.present
            implicitWidth: battRow.implicitWidth
            implicitHeight: battRow.implicitHeight
            readonly property bool low: Format.lowBattery(
                BatteryService.percent, BatteryService.charging, Config.battery.lowThreshold)
            readonly property color tint: low ? Theme.urgent
                : ((pill.controller && pill.controller.active === "battery") ? Theme.accent : Theme.foreground)
            Row {
                id: battRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Format.batteryGlyph(BatteryService.percent, BatteryService.charging)
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: Config.shape.iconSize
                    color: batt.tint
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: BatteryService.percent + "%"
                    font.pixelSize: 12
                    color: batt.tint
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (pill.controller) pill.controller.toggle("battery")
            }
        }
        Text {  // bluetooth (dynamic; visible only when a radio is on)
            anchors.verticalCenter: parent.verticalCenter
            visible: BluetoothService.available && BluetoothService.enabled
            text: BluetoothService.connectedCount > 0 ? "\u{F00B1}" : "\u{F00AF}"
            font.family: "Symbols Nerd Font"
            font.pixelSize: Config.shape.iconSize
            color: (pill.controller && pill.controller.active === "bluetooth")
                   ? Theme.accent : Theme.foreground
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (pill.controller) pill.controller.toggle("bluetooth")
            }
        }
        Item {  // network group: one icon per active connection, never empty → opens the hub
            id: netGroup
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: netRow.implicitWidth
            implicitHeight: netRow.implicitHeight
            readonly property string wifiState: Net.wifiIconState(
                NetworkService.wifiEnabled, NetworkService.connected,
                NetworkService.activeNetwork ? NetworkService.activeNetwork.signalStrength : 0)
            readonly property color tint: (pill.controller && pill.controller.active === "network")
                                          ? Theme.accent : Theme.foreground
            function glyph(kind) {
                if (kind === "ethernet") return "\u{F0C9D}"
                if (kind === "offline") return "\u{F0551}"
                if (kind === "vpn") return "\u{F0582}"
                if (kind === "airplane") return "\u{F001D}"
                var st = wifiState
                return st === "l4" ? "\u{F0928}"
                     : st === "l3" ? "\u{F0925}"
                     : st === "l2" ? "\u{F0922}"
                     : st === "l1" ? "\u{F091F}"
                     : "\u{F092A}"
            }
            Row {
                id: netRow
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: Net.networkGroup(WiredService.anyConnected, NetworkService.wifiEnabled, VpnService.connected, AirplaneService.active)
                    Text {
                        required property string modelData
                        text: netGroup.glyph(modelData)
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: Config.shape.iconSize
                        color: netGroup.tint
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (pill.controller) pill.controller.toggle("network")
            }
        }
        Text {  // control center (nf-fa-sliders)
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            font.family: "Symbols Nerd Font"
            font.pixelSize: Config.shape.iconSize
            color: (pill.controller && pill.controller.active === "controlcenter")
                   ? Theme.accent : Theme.foreground
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (pill.controller) pill.controller.toggle("controlcenter")
            }
        }
        Text {  // power (nf-fa-power_off)
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            font.family: "Symbols Nerd Font"
            font.pixelSize: Config.shape.iconSize
            color: (pill.controller && pill.controller.active === "power")
                   ? Theme.accent : Theme.foreground
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (pill.controller) pill.controller.toggle("power")
            }
        }
    }
}
