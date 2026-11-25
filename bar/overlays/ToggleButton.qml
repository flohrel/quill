import QtQuick
import qs.config   // qmllint disable import

// Reusable control-center toggle card: glyph + label, accent fill when active.
// available: false renders a dimmed, inert card (e.g. no Bluetooth adapter)
// so a missing device never looks like a dead "off" button.
Rectangle {
    id: card
    property string glyph: ""
    property string label: ""
    property bool active: false
    property bool available: true
    readonly property bool lit: active && available
    signal clicked()

    implicitWidth: Config.controlcenter.toggleSize
    implicitHeight: Config.controlcenter.toggleSize
    radius: Config.controlcenter.toggleRadius
    color: lit ? Theme.accent : Theme.surfaceAlt
    opacity: available ? 1.0 : 0.4

    Column {
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: Config.controlcenter.toggleIconSize
            color: card.lit ? Theme.background : Theme.foregroundDim
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.label
            font.pixelSize: 11
            color: card.lit ? Theme.background : Theme.foregroundDim
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: card.available
        hoverEnabled: true
        cursorShape: card.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.clicked()
    }
}
