pragma ComponentBehavior: Bound
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/mixer.js" as M
import "../../services/audiodevices.js" as AD

// Output levels under the mixer's master (#22, layout B): one row per known
// output — glyph · name · slider · % (or "muted") · mute. Each slider is
// that device's own layer (the device plays at master × this level). The
// default is highlighted; an idle output (not the default, no live pinned
// app) is dimmed but adjustable; an unavailable port is greyed with no
// slider. Rows are keyed by device name and diffed in place.
Column {
    id: levels
    spacing: 0

    readonly property var devices: AudioService.outputs
    readonly property string sig: AD.listSig(devices || [])
    ListModel { id: rows }
    function sync() { M.syncListModel(rows, "dname", sig === "" ? [] : sig.split("\n")) }
    onSigChanged: sync()
    Component.onCompleted: sync()

    Repeater {
        model: rows
        delegate: Rectangle {
            id: row
            required property string dname
            readonly property var dev: (levels.devices || []).find(d => d.name === row.dname)
                                       || { name: row.dname, label: "", glyph: "", isDefault: false, available: false }
            readonly property bool idle: !dev.isDefault && !MixerService.liveRouteDevices[dname]
            readonly property bool muted: VolumeService.outputMuted(dname)
            readonly property color textColor: !dev.available ? Theme.border
                                             : (idle ? Theme.foregroundDim : Theme.foreground)
            width: levels.width
            height: Config.controlcenter.sliderHeight
            radius: 8
            color: dev.isDefault ? Theme.surfaceAlt : "transparent"

            Text {
                id: ic
                anchors.left: parent.left; anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 16; horizontalAlignment: Text.AlignHCenter
                text: row.dev.glyph
                font.family: "Symbols Nerd Font"; font.pixelSize: 12
                color: row.textColor
            }
            Text {
                id: name
                anchors.left: ic.right; anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 92
                text: row.dev.label
                elide: Text.ElideRight
                font.pixelSize: 12
                color: row.textColor
            }
            ControlSlider {
                id: slider
                visible: row.dev.available
                anchors.left: name.right; anchors.leftMargin: 8
                anchors.right: pct.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                glyph: ""
                trackColor: Theme.surface
                fillColor: row.muted ? Theme.border : (row.idle ? Theme.foregroundDim : Theme.accent)
                knobColor: row.muted ? Theme.border : Theme.foreground
                value: VolumeService.outputLevel(row.dname)
                onMoved: (v) => VolumeService.setOutputLevel(row.dname, v)
            }
            Text {
                id: pct
                anchors.right: mute.left; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 58; horizontalAlignment: Text.AlignRight
                text: !row.dev.available ? "unplugged" : (row.muted ? "muted" : M.percent(slider.shownValue))
                font.pixelSize: 10; font.family: "monospace"
                color: row.muted && row.dev.available ? Theme.urgent : Theme.foregroundDim
            }
            MuteButton {
                id: mute
                visible: row.dev.available
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                muted: row.muted
                onToggled: VolumeService.toggleOutputMute(row.dname)
            }
        }
    }
}
