import QtQuick
import QtQuick.Controls
import Quickshell.Networking
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/network.js" as Net

// One wifi network row. Signal strength is drawn as 4 bars (no glyph). Lock /
// eye glyphs are byte-injected; gear is  escape. Tap behavior:
//   connected → disconnect; known/open → connect; new+secured → inline password.
Item {
    id: row
    property var net
    readonly property bool secured: net && net.security !== WifiSecurityType.Open
    readonly property bool busy: net && (net.stateChanging || net.state === ConnectionState.Connecting)
    property bool askPsk: false
    property bool failed: false
    property bool attempted: false

    signal configRequested(var net)

    implicitHeight: body.implicitHeight   // pskRow lives in body; Column already counts it when visible

    function activate() {
        if (!net) return
        switch (Net.rowAction(row.askPsk, net.connected, net.known, secured)) {
        case "collapse":                        // second click hides the field; focus loss releases the hold
            row.askPsk = false; row.failed = false; row.attempted = false; return
        case "disconnect": NetworkService.disconnect(net); return
        case "connect":    NetworkService.connect(net); return
        default:           row.askPsk = true    // new secured → reveal field
        }
    }

    // Re-prompt / failure feedback driven by the live network's signals.
    Connections {
        target: row.net
        function onRequestConnectWithPsk(psk) { row.askPsk = true; if (row.attempted) row.failed = true }
        function onConnectionFailed(reason) { if (row.attempted) row.failed = true }
        function onConnectedChanged() { if (row.net && row.net.connected) { row.askPsk = false; row.failed = false; row.attempted = false } }
    }

    Column {
        id: body
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 28

            Row {   // signal bars
                id: bars
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        width: 3
                        height: 4 + index * 3
                        anchors.bottom: parent.bottom
                        radius: 1
                        color: index < Net.signalLevel(row.net ? row.net.signalStrength : 0)
                               ? ((row.net && row.net.connected) ? Theme.accent : Theme.foreground)
                               : Theme.surfaceAlt
                    }
                }
            }

            Text {
                anchors.left: bars.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: (row.net ? row.net.name : "") + (row.secured ? "  " : "")
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                color: (row.net && row.net.connected) ? Theme.accent : Theme.foreground
                elide: Text.ElideRight
                width: parent.width - bars.width - gear.width - 80
            }

            Text {   // state / feedback
                anchors.right: gear.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.busy ? "connecting…"
                      : row.failed ? "wrong password"
                      : (row.net && row.net.connected) ? "connected" : ""
                font.pixelSize: 10
                color: row.failed ? Theme.error : Theme.foregroundDim
            }

            Text {   // gear → open detail (known or connected only)
                id: gear
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.net && (row.net.known || row.net.connected)
                text: "\uF013"                       // nf-fa-cog
                font.family: "Symbols Nerd Font"
                font.pixelSize: 13
                color: Theme.foregroundDim
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -(Config.wifi.gearHitSize - parent.height) / 2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.configRequested(row.net)
                }
            }

            MouseArea {   // tap the row body (not the gear)
                anchors.fill: parent
                anchors.rightMargin: gear.visible ? gear.width + 12 : 0
                cursorShape: Qt.PointingHandCursor
                onClicked: row.activate()
            }
        }

        Row {   // inline password field (new secured)
            id: pskRow
            width: parent.width
            visible: row.askPsk
            spacing: 6

            Rectangle {
                width: parent.width - showBtn.width - connectBtn.width - 12
                height: 24
                radius: 4
                color: Theme.background
                TextField {
                    id: psk
                    anchors.fill: parent
                    anchors.margins: 2
                    echoMode: showBtn.shown ? TextInput.Normal : TextInput.Password
                    color: Theme.foreground
                    background: null
                    onPressed: forceActiveFocus()           // OnDemand-focus path
                    // Freeze the network list while typing so a scan tick can't
                    // recreate this delegate and wipe the half-typed password.
                    onActiveFocusChanged: NetworkService.setHold(activeFocus)
                    Keys.onEscapePressed: row.askPsk = false   // cancel entry; focus loss releases the hold
                    onAccepted: { NetworkService.connectWithPsk(row.net, psk.text); row.attempted = true; row.failed = false }
                }
            }
            Text {
                id: showBtn
                property bool shown: false
                anchors.verticalCenter: parent.verticalCenter
                text: shown ? "" : ""
                font.family: "Symbols Nerd Font"
                font.pixelSize: 13
                color: Theme.foregroundDim
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: showBtn.shown = !showBtn.shown }
            }
            Rectangle {
                id: connectBtn
                width: 60; height: 24; radius: 4
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: 11; color: Theme.background }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { NetworkService.connectWithPsk(row.net, psk.text); row.attempted = true; row.failed = false } }
            }
        }
    }
}
