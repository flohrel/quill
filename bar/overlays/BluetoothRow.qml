import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/bluetooth.js" as Bt

// One Bluetooth device row. Layout: device-type glyph + name on the left; a
// status/battery caption; on paired rows a right-side chevron toggling an
// inline expand strip (battery, address, Trusted toggle, Forget). Available
// (unpaired) rows are tap-to-pair only — no expand strip, nothing to manage
// before pairing. Tap behavior on the row body:
//   connected → disconnect; paired+disconnected → connect;
//   unpaired → pair (the service chains trust + connect once pairing lands).
Item {
    id: row
    property var device
    readonly property bool isPaired: row.device && (row.device.paired || row.device.bonded)
    property bool expanded: false

    implicitHeight: body.implicitHeight   // strip lives in body; Column already counts it when visible

    function activate() {
        var d = row.device
        if (!d) return
        if (d.connected) { BluetoothService.disconnect(d); return }
        if (row.isPaired) { BluetoothService.connect(d); return }
        BluetoothService.pair(d)
    }

    // statusLabel's static "paired" idle label is less useful than the
    // battery reading when one's available; active states (connecting/
    // pairing/connected) always take priority over it.
    readonly property string caption: {
        var label = Bt.statusLabel(row.device, BluetoothService.pairingAddress)
        if (label === "paired") {
            var b = Bt.batteryLabel(row.device)
            if (b !== "") return b
        }
        return label
    }

    Column {
        id: body
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 28

            Text {   // device-type glyph
                id: glyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Bt.deviceIconGlyph(row.device ? row.device.icon : "")
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: (row.device && row.device.connected) ? Theme.accent : Theme.foreground
            }

            Text {
                anchors.left: glyph.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.device ? (row.device.name || row.device.deviceName) : ""
                font.pixelSize: 12
                color: (row.device && row.device.connected) ? Theme.accent : Theme.foreground
                elide: Text.ElideRight
                width: parent.width - glyph.width - 8 - chevron.width - 90
            }

            Text {   // status / battery caption
                anchors.right: chevron.visible ? chevron.left : parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.caption
                font.pixelSize: 10
                color: Theme.foregroundDim
            }

            Text {   // chevron → toggle expand strip (paired rows only)
                id: chevron
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.isPaired
                text: row.expanded ? "\u{F077}" : "\u{F078}"   // nf-fa-chevron_up / nf-fa-chevron_down
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                color: Theme.foregroundDim
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -(Config.bluetooth.chevronHitSize - parent.height) / 2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.expanded = !row.expanded
                }
            }

            MouseArea {   // tap the row body (not the chevron)
                anchors.fill: parent
                anchors.rightMargin: chevron.visible ? chevron.width + 12 : 0
                cursorShape: Qt.PointingHandCursor
                onClicked: row.activate()
            }
        }

        Column {   // inline expand strip (paired rows only)
            id: strip
            width: parent.width
            visible: row.isPaired && row.expanded
            spacing: 6
            topPadding: 4

            Text {
                text: "Battery " + (Bt.batteryLabel(row.device) || "—")
                font.pixelSize: 10
                color: Theme.foregroundDim
            }
            Text {
                text: "Address " + (row.device ? row.device.address : "")
                font.pixelSize: 10
                color: Theme.foregroundDim
            }

            Item {   // Trusted toggle
                width: parent.width
                height: 20
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Trusted"
                    font.pixelSize: 11
                    color: Theme.foreground
                }
                Rectangle {
                    id: trustedTrack
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 16; radius: 8
                    color: (row.device && row.device.trusted) ? Theme.accent : Theme.surfaceAlt
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        x: (row.device && row.device.trusted) ? parent.width - width - 2 : 2
                        color: Theme.background
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (row.device) BluetoothService.setTrusted(row.device, !row.device.trusted)
                    }
                }
            }

            Rectangle {   // Forget (explicit click only, no inline confirm)
                width: parent.width; height: 24; radius: 4
                color: Theme.error
                Text {
                    anchors.centerIn: parent
                    text: "Forget"
                    font.pixelSize: 11
                    color: Theme.background
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (row.device) BluetoothService.forget(row.device)
                }
            }
        }
    }
}
