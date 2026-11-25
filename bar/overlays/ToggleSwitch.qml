import QtQuick
import qs.config   // qmllint disable import

// Small pill switch. Purely presentational: emits toggled(); the owner flips
// the backing state (so latched/async backends stay the source of truth).
Rectangle {
    id: sw
    property bool checked: false
    signal toggled()

    implicitWidth: 32; implicitHeight: 18
    radius: height / 2
    color: checked ? Theme.accent : Theme.border
    Behavior on color { ColorAnimation { duration: Config.shape.animDuration } }

    Rectangle {
        width: parent.height - 4; height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? sw.width - width - 2 : 2
        color: sw.checked ? Theme.surface : Theme.foregroundDim
        Behavior on x { NumberAnimation { duration: Config.shape.animDuration } }
    }
    MouseArea {
        anchors.fill: parent; anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
