import QtQuick
import qs.config   // qmllint disable import

// One power action card: glyph + name + keybind chip. Resting = surface; active
// (keyboard-selected or hovered) = accent ring + lighter fill + accent glyph.
Rectangle {
    id: card
    property string glyph: ""
    property string label: ""
    property string keyhint: ""
    property bool active: false
    signal activated()
    signal hovered()

    implicitWidth: Config.power.cardSize
    implicitHeight: Config.power.cardSize
    radius: Config.power.cardRadius
    color: active ? Theme.surfaceAlt : Theme.surface
    border.width: active ? Config.power.ringWidth : 0
    border.color: Theme.accent

    Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: 34
            color: card.active ? Theme.accent : Theme.foreground
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.label
            font.pixelSize: 15
            color: Theme.foreground
        }
        Rectangle {   // keybind chip — bg0 so it contrasts on both surface + surfaceAlt
            anchors.horizontalCenter: parent.horizontalCenter
            width: 26; height: 20; radius: 6
            color: Theme.background
            Text {
                anchors.centerIn: parent
                text: card.keyhint
                font.pixelSize: 12
                color: Theme.foregroundDim
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: card.hovered()
        onClicked: card.activated()
    }
}
