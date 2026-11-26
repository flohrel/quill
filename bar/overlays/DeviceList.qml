pragma ComponentBehavior: Bound
import QtQuick
import qs.config   // qmllint disable import
import "../../services/mixer.js" as M
import "../../services/audiodevices.js" as AD

// Inline device list under the mixer page's chips (#5): one row per output
// (or input); the default is highlighted and tagged. Clicking a row emits
// picked(name). `devices` is an AudioService.outputs/inputs array.
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
                                           || { name: row.dname, label: "", glyph: "", isDefault: false }
                width: col.width
                height: 30
                radius: 8
                color: dev.isDefault ? Theme.surfaceAlt : (mouse.containsMouse ? Theme.surface : "transparent")

                Text {
                    id: ic
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; horizontalAlignment: Text.AlignHCenter
                    text: row.dev.glyph
                    font.family: "Symbols Nerd Font"; font.pixelSize: 12
                    color: Theme.foreground
                }
                Text {
                    anchors.left: ic.right; anchors.leftMargin: 8
                    anchors.right: tag.visible ? tag.left : parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.dev.label
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: Theme.foreground
                }
                Rectangle {
                    id: tag
                    visible: row.dev.isDefault
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: tagText.implicitWidth + 10; height: 16
                    radius: 4
                    color: Theme.accent
                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: "default"
                        font.pixelSize: 10
                        color: Theme.background
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.picked(row.dname)
                }
            }
        }
    }
}
