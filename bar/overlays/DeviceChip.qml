import QtQuick
import qs.config   // qmllint disable import

// Mixer page header chip (#5): glyph · device label · chevron. Shows the
// current default output or input; clicking toggles that kind's DeviceList.
Rectangle {
    id: chip
    property string glyph: ""
    property string label: ""
    property bool open: false
    property int maxWidth: 140
    signal clicked()

    implicitHeight: 22
    implicitWidth: Math.min(maxWidth, row.implicitWidth + 12)
    radius: 6
    color: open || mouse.containsMouse ? Theme.surfaceAlt : Theme.surface

    Row {
        id: row
        anchors.left: parent.left; anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text {
            id: ic
            anchors.verticalCenter: parent.verticalCenter
            text: chip.glyph
            font.family: "Symbols Nerd Font"; font.pixelSize: 11
            color: Theme.foreground
        }
        Text {
            id: lbl
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, chip.maxWidth - 12 - ic.implicitWidth - chev.implicitWidth - 8)
            text: chip.label
            elide: Text.ElideRight
            font.pixelSize: 11
            color: chip.open ? Theme.foreground : Theme.foregroundDim
        }
        Text {
            id: chev
            anchors.verticalCenter: parent.verticalCenter
            text: chip.open ? "\u{F077}" : "\u{F078}"   // chevron up / down
            font.family: "Symbols Nerd Font"; font.pixelSize: 9
            color: Theme.foregroundDim
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
