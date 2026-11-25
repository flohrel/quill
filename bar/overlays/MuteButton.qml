import QtQuick
import qs.config   // qmllint disable import

// Round mute toggle for the mixer (#72): a dedicated, visibly clickable
// button instead of "click the app icon". Muted = red glyph on a red tint.
Rectangle {
    id: root
    property bool muted: false
    property int size: 28
    signal toggled()

    width: size; height: size
    radius: size / 2
    color: mouse.containsMouse ? Theme.border
         : muted ? Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.15)
         : Theme.surface

    Text {
        anchors.centerIn: parent
        text: root.muted ? "\u{EEE8}" : "\u{EFCF}"   // muted / sound on
        font.family: "Symbols Nerd Font"
        font.pixelSize: Math.round(root.size * 0.5)
        color: root.muted ? Theme.urgent : Theme.foreground
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
