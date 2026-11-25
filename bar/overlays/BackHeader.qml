import QtQuick
import qs.config   // qmllint disable import

// "‹ Network" back link at the top of a NetworkPopup submenu.
Item {
    id: hdr
    property string label: "Network"
    signal back()

    implicitWidth: row.implicitWidth
    implicitHeight: 20

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F053}"   // nf-fa-chevron_left, same as WifiDetail's back
            font.family: "Symbols Nerd Font"; font.pixelSize: 12
            color: Theme.foregroundDim
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: hdr.label; font.pixelSize: 12; color: Theme.foregroundDim
        }
    }
    MouseArea {
        anchors.fill: parent; anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: hdr.back()
    }
}
