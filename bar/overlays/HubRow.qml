import QtQuick
import qs.config   // qmllint disable import

// One connection-type row in the NetworkPopup hub: glyph, name over a dim
// status line, chevron. Uses Item.enabled: a disabled row is greyed and its
// MouseArea inherits enabled=false, so it is not clickable.
Rectangle {
    id: row
    property string glyph: ""
    property string name: ""
    property string status: ""
    signal clicked()

    implicitHeight: 44
    radius: 8
    color: hover.containsMouse && row.enabled ? Theme.surfaceAlt : "transparent"
    opacity: row.enabled ? 1 : 0.5

    Text {
        id: icon
        anchors.left: parent.left; anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: row.glyph
        font.family: "Symbols Nerd Font"; font.pixelSize: 16
        color: row.enabled ? Theme.accent : Theme.foregroundDim
    }
    Column {
        anchors.left: icon.right; anchors.leftMargin: 10
        anchors.right: chevron.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width; elide: Text.ElideRight
            text: row.name; font.pixelSize: 13
            color: row.enabled ? Theme.foreground : Theme.foregroundDim
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: row.status; font.pixelSize: 11; color: Theme.foregroundDim
        }
    }
    Text {
        id: chevron
        anchors.right: parent.right; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0142}"
        font.family: "Symbols Nerd Font"; font.pixelSize: 16
        color: Theme.foregroundDim
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.enabled
        cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.clicked()
    }
}
