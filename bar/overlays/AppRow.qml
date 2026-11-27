pragma ComponentBehavior: Bound
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/mixer.js" as M

// One app on the mixer page, "rows" layout (#72, MacMix-style): a single
// 32 px line, icon · name · slider · % · mute · chevron, no card. Rows have
// no subtitle, so even a single titled stream folds out (#73) into an inset
// box below; routable apps fold out too (#20): the box starts with the route
// chip and ends with the Outputs section. Collapsed, a pinned route shows as
// a small dot before the mute button. Same interface as AppCard: `group`,
// `expanded`, `toggleExpanded()`.
Item {
    id: row
    property var group
    property bool expanded: false
    signal toggleExpanded()

    readonly property bool muted: !!group && group.muted
    readonly property bool foldable: M.showFoldout(group, "rows")
    readonly property string streamSig: group ? group.streams.map(s => s.id).join(",") : ""
    // Fold-out rows diffed in place, like MixerPage's list (see there).
    ListModel { id: streamModel }
    // Stream rows keep their own rule; routable groups fold out regardless.
    readonly property bool _showStreams: expanded && M.showFoldout({ streams: group ? group.streams : [] }, "rows")
    function syncStreams() {
        M.syncListModel(streamModel, "sid", _showStreams && streamSig !== "" ? streamSig.split(",") : [])
    }
    onStreamSigChanged: syncStreams()
    on_ShowStreamsChanged: syncStreams()
    Component.onCompleted: syncStreams()

    implicitHeight: body.implicitHeight

    Column {
        id: body
        width: parent.width
        spacing: 2

        Item {
            width: parent.width
            height: 32

            AppIcon {
                id: icon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                group: row.group
                muted: row.muted
            }
            Text {
                id: name
                anchors.left: icon.right; anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 66
                text: row.group ? row.group.name : ""
                elide: Text.ElideRight
                font.pixelSize: 13
                color: row.muted ? Theme.foregroundDim : Theme.foreground
            }
            ControlSlider {
                id: slider
                anchors.left: name.right; anchors.leftMargin: 8
                anchors.right: pct.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                glyph: ""
                trackColor: Theme.surfaceAlt
                fillColor: row.muted ? Theme.border : Theme.accent
                knobColor: row.muted ? Theme.border : Theme.foreground
                value: row.group ? row.group.volume : 0
                onMoved: (v) => MixerService.setGroupVolume(row.group.key, v)
            }
            Text {
                id: pct
                anchors.right: routeDot.visible ? routeDot.left : mute.left; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 36; horizontalAlignment: Text.AlignRight
                text: row.muted ? "muted" : (row.group ? M.percent(slider.shownValue) : "")
                font.pixelSize: 11; font.family: "monospace"
                color: row.muted ? Theme.urgent : Theme.foregroundDim
            }
            // Pinned (or pinned-but-unplugged) route, coloured like the chip.
            Rectangle {
                id: routeDot
                readonly property var info: row.group && row.group.routable
                    ? MixerService.routeChip(row.group.key) : ({ kind: "default" })
                visible: info.kind !== "default"
                anchors.right: mute.left; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: info.kind === "pinned" ? Theme.warning : Theme.border
            }
            MuteButton {
                id: mute
                anchors.right: chev.left; anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                size: 24
                muted: row.muted
                onToggled: MixerService.toggleGroupMute(row.group.key)
            }
            Text {
                id: chev
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 12; horizontalAlignment: Text.AlignHCenter
                text: row.expanded ? "\u{F077}" : "\u{F078}"   // chevron up / down
                opacity: row.foldable ? 1 : 0   // keeps its slot so rows align
                font.family: "Symbols Nerd Font"; font.pixelSize: 10
                color: Theme.foregroundDim
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    enabled: row.foldable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.toggleExpanded()
                }
            }
        }

        // Fold-out: inset box, one row per stream
        Rectangle {
            visible: row.expanded && row.foldable
            x: 30
            width: parent.width - 30
            height: streams.implicitHeight + 8
            radius: 8
            color: Theme.surfaceAlt

            Column {
                id: streams
                anchors.top: parent.top; anchors.topMargin: 4
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 6
                RouteChip {
                    group: row.group
                    maxWidth: streams.width
                }
                // Stream ids drive streamModel (diffed in place), so a volume
                // echo never recreates a row mid-drag.
                Repeater {
                    model: streamModel
                    delegate: Item {
                        id: srow
                        required property string sid
                        readonly property var stream: row.group
                            ? (row.group.streams.find(s => String(s.id) === srow.sid)
                               || { id: -1, label: "", volume: 0, muted: false })
                            : { id: -1, label: "", volume: 0, muted: false }
                        width: streams.width
                        height: 28

                        Text {
                            id: slabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 70
                            text: srow.stream.label
                            elide: Text.ElideRight
                            font.pixelSize: 11
                            color: srow.stream.muted ? Theme.border : Theme.foregroundDim
                        }
                        ControlSlider {
                            id: sslider
                            anchors.left: slabel.right; anchors.leftMargin: 6
                            anchors.right: spct.left; anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: ""
                            trackColor: Theme.surface
                            fillColor: srow.stream.muted ? Theme.border : Theme.accent
                            knobColor: srow.stream.muted ? Theme.border : Theme.foreground
                            value: srow.stream.volume
                            onMoved: (v) => MixerService.setStreamVolume(srow.stream.id, v)
                        }
                        Text {
                            id: spct
                            anchors.right: smute.left; anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34; horizontalAlignment: Text.AlignRight
                            text: srow.stream.muted ? "muted" : M.percent(sslider.shownValue)
                            font.pixelSize: 10; font.family: "monospace"
                            color: srow.stream.muted ? Theme.urgent : Theme.foregroundDim
                        }
                        MuteButton {
                            id: smute
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            size: 20
                            muted: srow.stream.muted
                            onToggled: MixerService.toggleStreamMute(srow.stream.id)
                        }
                    }
                }
                OutputsSection {
                    width: streams.width
                    visible: !!row.group && row.group.routable
                    group: row.group
                }
            }
        }
    }
}
