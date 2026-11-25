import QtQuick
import QtQuick.Controls
import Quickshell.Networking
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import

// Per-network detail page (level 3 of NetworkPopup). Read-only info from WifiDetails
// (nmcli), a display-only SETTINGS block, and Change-password / Forget actions.
Item {
    id: detail
    property var popup
    property var net
    readonly property bool secured: net && net.security !== WifiSecurityType.Open
    property bool askPsk: false

    implicitHeight: col.implicitHeight

    // A row of "Label    value" used by both blocks. `dim` greys the SETTINGS block
    // to signal it's display-only this cut.
    component InfoRow: Item {
        property string label: ""
        property string value: ""
        property bool dim: false
        width: col.width; height: 22
        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: label; font.pixelSize: 12
            color: Theme.foregroundDim          // labels always dim; only the value dims further for SETTINGS
        }
        Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: value; font.pixelSize: 12
            color: dim ? Theme.foregroundDim : Theme.foreground
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 6

        // header: back + SSID + lock
        Row {
            width: parent.width; spacing: 8
            Text {
                text: "\uF053"                       // back chevron (nf-fa-chevron_left)
                font.family: "Symbols Nerd Font"; font.pixelSize: 15
                color: Theme.foreground
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: detail.popup.closeDetail()
                }
            }
            Text {
                text: detail.net ? detail.net.name : ""
                color: Theme.foreground; font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: detail.secured
                text: "\uF023"                       // lock (nf-fa-lock)
                font.family: "Symbols Nerd Font"; font.pixelSize: 12
                color: Theme.foregroundDim
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.surfaceAlt }

        Text { text: "INFORMATION"; font.pixelSize: 10; color: Theme.foregroundDim; font.capitalization: Font.AllUppercase }
        InfoRow { label: "Security"; value: WifiDetails.security }
        InfoRow { label: "Signal";   value: WifiDetails.signal }
        InfoRow { label: "Status";   value: WifiDetails.status }
        InfoRow { label: "IP";       value: WifiDetails.ip }
        InfoRow { label: "Gateway";  value: WifiDetails.gateway }
        InfoRow { label: "DNS";      value: WifiDetails.dns }

        Text { text: "SETTINGS"; font.pixelSize: 10; color: Theme.foregroundDim; font.capitalization: Font.AllUppercase }
        InfoRow { label: "Auto-connect"; value: WifiDetails.autoconnect; dim: true }
        InfoRow { label: "IPv4 method";  value: WifiDetails.ipv4Method;  dim: true }
        InfoRow { label: "Metered";      value: WifiDetails.metered;     dim: true }

        // inline password entry for Change password (not a ListView delegate → no
        // recreate/vanish risk, so no holdList freeze needed)
        Row {
            width: parent.width; visible: detail.askPsk; spacing: 6
            Rectangle {
                width: parent.width - cpConnect.width - 8; height: 24; radius: 4
                color: Theme.background
                TextField {
                    id: cpField
                    anchors.fill: parent; anchors.margins: 2
                    echoMode: TextInput.Password
                    color: Theme.foreground; background: null
                    onPressed: forceActiveFocus()
                    Keys.onEscapePressed: detail.askPsk = false
                    onAccepted: { NetworkService.connectWithPsk(detail.net, cpField.text); detail.askPsk = false }
                }
            }
            Rectangle {
                id: cpConnect
                width: 60; height: 24; radius: 4; color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: "Save"; font.pixelSize: 11; color: Theme.background }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { NetworkService.connectWithPsk(detail.net, cpField.text); detail.askPsk = false } }
            }
        }

        // actions
        Row {
            width: parent.width; spacing: 8
            Rectangle {
                visible: detail.secured
                width: (parent.width - 8) / 2; height: 30; radius: 6
                color: Theme.surfaceAlt
                Text { anchors.centerIn: parent; text: "Change password"; font.pixelSize: 11; color: Theme.foreground }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { detail.askPsk = true; cpField.forceActiveFocus() } }
            }
            Rectangle {
                width: detail.secured ? (parent.width - 8) / 2 : parent.width; height: 30; radius: 6
                color: Theme.surfaceAlt
                visible: detail.net && detail.net.known
                Text { anchors.centerIn: parent; text: "Forget"; font.pixelSize: 11; color: Theme.error }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { NetworkService.forget(detail.net); detail.popup.closeDetail() } }
            }
        }
    }
}
