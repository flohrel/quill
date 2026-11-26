pragma ComponentBehavior: Bound
import QtQuick
import qs.config   // qmllint disable import
import "../../services/mixer.js" as M
import "../../services/audiodevices.js" as AD

// Inline device list under the mixer page's chips (#5): one row per output
// (or input); the default is highlighted and tagged. Clicking a row emits
// picked(name). `devices` is an AudioService.outputs/inputs array. A port
// that can't be used right now (available: false, e.g. a jack mic with
// nothing plugged in) shows a dim label and an "unplugged" tag, no hover,
// an arrow cursor, and can't be picked.
Rectangle {
    id: list
    property var devices: []
    property string emptyText: ""
    signal picked(string name)

    implicitHeight: col.implicitHeight + 12
    radius: 10
    color: Theme.background
    border.width: 1; border.color: Theme.border

    // Rows are keyed by device name and diffed in place (M.syncListModel):
    // AudioService rebuilds `devices` on every node property change, and a
    // fresh array would recreate every row.
    readonly property string sig: AD.listSig(devices || [])
    ListModel { id: rows }
    function sync() { M.syncListModel(rows, "dname", sig === "" ? [] : sig.split("\n")) }
    onSigChanged: sync()
    Component.onCompleted: sync()

    Column {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.margins: 6

        Text {
            visible: list.sig === ""
            height: 30; verticalAlignment: Text.AlignVCenter
            leftPadding: 6
            text: list.emptyText
            font.pixelSize: 12
            color: Theme.foregroundDim
        }

        Repeater {
            model: rows
            delegate: Rectangle {
                id: row
                required property string dname
                readonly property var dev: (list.devices || []).find(d => d.name === row.dname)
                                           || { name: row.dname, label: "", glyph: "", isDefault: false, available: false }
                width: col.width
                height: 30
                radius: 8
                color: row.dev.isDefault ? Theme.surfaceAlt
                     : (mouse.containsMouse && row.dev.available ? Theme.surface : "transparent")

                Text {
                    id: ic
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; horizontalAlignment: Text.AlignHCenter
                    text: row.dev.glyph
                    font.family: "Symbols Nerd Font"; font.pixelSize: 12
                    color: row.dev.available ? Theme.foreground : Theme.foregroundDim
                }
                Text {
                    anchors.left: ic.right; anchors.leftMargin: 8
                    anchors.right: tag.visible ? tag.left : parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.dev.label
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: row.dev.available ? Theme.foreground : Theme.foregroundDim
                }
                // "default" (filled) or "unplugged" (outlined); default wins.
                Rectangle {
                    id: tag
                    visible: row.dev.isDefault || !row.dev.available
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: tagText.implicitWidth + 10; height: 16
                    radius: 4
                    color: row.dev.isDefault ? Theme.accent : "transparent"
                    border.width: row.dev.isDefault ? 0 : 1
                    border.color: Theme.border
                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: row.dev.isDefault ? "default" : "unplugged"
                        font.pixelSize: 10
                        color: row.dev.isDefault ? Theme.background : Theme.foregroundDim
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    // Stays enabled (a disabled MouseArea still sets its
                    // cursor); unavailable rows get an arrow and ignore clicks.
                    cursorShape: row.dev.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (row.dev.available) list.picked(row.dname)
                }
            }
        }
    }
}
