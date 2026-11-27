pragma ComponentBehavior: Bound
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/mixer.js" as M
import "../../services/routing.js" as R

// Outputs section of an app's fold-out (#20): "Follow default (<default>)"
// or "Choose output", then one row per known output. Single choice in this
// step: the pinned row's slider is the app's volume, raising an "off" row
// (or tapping its name) moves the app there, unplugged rows are greyed with
// no slider. Same in AppCard and AppRow. `group` is a MixerService.groups
// entry; only routable groups show the section.
Column {
    id: sec
    property var group
    readonly property string key: group ? group.key : ""
    readonly property bool pinned: key !== "" && MixerService.isPinned(key)
    // "Choose output" tapped with no usable default to start from: rows
    // show, no route yet.
    property bool choosing: false
    onKeyChanged: choosing = false
    readonly property bool showRows: pinned || choosing

    readonly property var rows: key !== "" ? MixerService.outputRows(key) : []
    // Rows keyed by device name and diffed in place (M.syncListModel): rows
    // is a fresh array on every volume change and must not recreate a row
    // mid-drag.
    readonly property string sig: showRows ? R.rowsSig(rows) : ""
    ListModel { id: rowModel }
    function sync() { M.syncListModel(rowModel, "oname", sig === "" ? [] : sig.split("\n")) }
    onSigChanged: sync()
    Component.onCompleted: sync()

    visible: !!group && group.routable

    component Radio: Item {
        id: radio
        property bool on: false
        property string label: ""
        signal tapped()
        width: parent ? parent.width : 0
        height: 24
        Rectangle {
            id: ring
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12; radius: 6
            color: "transparent"
            border.width: 2
            border.color: radio.on ? Theme.accent : Theme.foregroundDim
            Rectangle {
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                visible: radio.on
                color: Theme.accent
            }
        }
        Text {
            anchors.left: ring.right; anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: radio.label
            elide: Text.ElideRight
            font.pixelSize: 12
            color: radio.on ? Theme.foreground : Theme.foregroundDim
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: radio.tapped()
        }
    }

    Text {
        height: 22
        verticalAlignment: Text.AlignVCenter
        text: "Outputs"
        font.pixelSize: 11
        color: Theme.foregroundDim
    }

    Radio {
        on: !sec.showRows
        label: "Follow default (" + MixerService.defaultOutputLabel + ")"
        onTapped: {
            sec.choosing = false
            MixerService.followDefault(sec.key)
        }
    }
    Radio {
        on: sec.showRows
        label: "Choose output"
        onTapped: {
            sec.choosing = true
            MixerService.chooseOutput(sec.key)
        }
    }

    Repeater {
        model: rowModel
        delegate: Item {
            id: orow
            required property string oname
            readonly property var r: sec.rows.find(x => x.name === orow.oname)
                                     || { name: orow.oname, label: "", glyph: "", state: "unplugged", level: -1 }
            readonly property bool live: r.state !== "unplugged"
            width: sec.width
            height: Config.controlcenter.sliderHeight

            Text {
                id: oglyph
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 16; horizontalAlignment: Text.AlignHCenter
                text: orow.r.glyph
                font.family: "Symbols Nerd Font"; font.pixelSize: 11
                color: orow.r.state === "pinned" ? Theme.accent
                     : (orow.live ? Theme.foregroundDim : Theme.border)
            }
            Text {
                id: olabel
                anchors.left: oglyph.right; anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: Config.mixer.childLabelWidth - 20
                text: orow.r.label
                elide: Text.ElideRight
                font.pixelSize: 11
                color: orow.r.state === "pinned" ? Theme.foreground
                     : (orow.live ? Theme.foregroundDim : Theme.border)
                MouseArea {
                    anchors.fill: parent
                    enabled: orow.r.state === "off"
                    cursorShape: orow.r.state === "off" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: MixerService.pinOutput(sec.key, orow.oname)
                }
            }
            ControlSlider {
                id: oslider
                visible: orow.live
                anchors.left: olabel.right; anchors.leftMargin: 8
                anchors.right: opct.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                glyph: ""
                trackColor: Theme.surface
                fillColor: orow.r.state === "pinned" ? Theme.accent : Theme.border
                knobColor: orow.r.state === "pinned" ? Theme.foreground : Theme.border
                value: orow.r.state === "pinned" ? orow.r.level : 0
                onMoved: (v) => MixerService.setOutputLevel(sec.key, orow.oname, v)
            }
            Text {
                id: opct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 64; horizontalAlignment: Text.AlignRight
                text: orow.r.state === "pinned" || oslider.shownValue > 0
                      ? M.percent(oslider.shownValue) : orow.r.state
                font.pixelSize: 10; font.family: "monospace"
                color: orow.live ? Theme.foregroundDim : Theme.border
            }
        }
    }
}
