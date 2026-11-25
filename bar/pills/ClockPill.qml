import QtQuick
import qs.config   // qmllint disable import
import "../../lib/format.js" as Format

// Center pill: HH:MM · Day DD. Click toggles the calendar overlay.
Rectangle {
    id: pill
    property var controller
    implicitWidth: row.width + Config.shape.pillPaddingH * 2
    implicitHeight: Config.shape.barHeight
    radius: Config.shape.pillRadius
    color: Theme.surface

    property var now: new Date()
    Timer {
        interval: Config.intervals.clock; running: true; repeat: true
        onTriggered: pill.now = new Date()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text { text: Format.clock(pill.now); color: Theme.foreground; font.pixelSize: 12 }
        Text { text: "·"; color: Theme.foregroundDim; font.pixelSize: 12 }
        Text { text: Format.dateLabel(pill.now); color: Theme.foregroundDim; font.pixelSize: 12 }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (pill.controller) pill.controller.toggle("calendar")
    }
}
