import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import

// Read-only month grid, lifted from spec-1 CalendarTile. Borderless.
// Calendar depth (navigation, synced events) is reserved for Spec 2.
Rectangle {
    id: view
    implicitWidth: 215; implicitHeight: 180
    radius: Config.shape.overlayRadius
    color: Theme.surface

    readonly property var today: new Date()
    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth()
    readonly property int firstDow: new Date(year, month, 1).getDay()
    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()

    Column {
        anchors.fill: parent; anchors.margins: Config.shape.overlayPadding; spacing: 6
        Text {
            text: Qt.formatDate(view.today, "MMMM yyyy")
            color: Theme.foreground; font.pixelSize: 13; font.bold: true
        }
        Grid {
            columns: 7; rowSpacing: 2; columnSpacing: 2
            Repeater {
                model: ["S","M","T","W","T","F","S"]
                delegate: Text {
                    required property string modelData
                    width: 25; horizontalAlignment: Text.AlignHCenter
                    text: modelData; color: Theme.foregroundDim; font.pixelSize: 9
                }
            }
            Repeater {
                model: view.firstDow + view.daysInMonth
                delegate: Item {
                    required property int index
                    width: 25; height: 20
                    readonly property int day: index - view.firstDow + 1
                    readonly property bool isDay: index >= view.firstDow
                    readonly property bool isToday: isDay && day === view.today.getDate()
                    readonly property bool hasEvent: isDay &&
                        CalendarService.eventsFor(new Date(view.year, view.month, day),
                                                  new Date(view.year, view.month, day, 23, 59)).length > 0
                    Rectangle {
                        anchors.centerIn: parent; width: 18; height: 18; radius: 9
                        visible: parent.isToday; color: Theme.accent
                    }
                    Text {
                        anchors.centerIn: parent; visible: parent.isDay
                        text: parent.day
                        color: parent.isToday ? Theme.background : Theme.foreground
                        font.pixelSize: 10
                    }
                    Rectangle {  // event marker dot
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                        width: 3; height: 3; radius: 2; visible: parent.hasEvent && !parent.isToday
                        color: Theme.warning
                    }
                }
            }
        }
    }
}
