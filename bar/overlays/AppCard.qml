pragma ComponentBehavior: Bound
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/mixer.js" as M

// One app on the mixer page, "cards" layout (#18, #72): top line = icon,
// name over subtitle (track/tab title, or "2 tabs playing"), chevron when
// there are 2+ streams, mute button; then the app slider and % ("muted"
// when muted). Fold-out: one row per stream, each with its own mute button.
// `group` is a MixerService.groups entry.
Rectangle {
    id: card
    property var group
    property bool expanded: false
    signal toggleExpanded()

    readonly property bool muted: !!group && group.muted
    readonly property bool foldable: M.showFoldout(group, "cards")
    readonly property string subtitle: group ? group.subtitle : ""
    readonly property string streamSig: group ? group.streams.map(s => s.id).join(",") : ""
    // Fold-out rows diffed in place, like MixerPage's cards (see there).
    ListModel { id: streamModel }
    readonly property bool _showStreams: foldable && expanded
    function syncStreams() {
        M.syncListModel(streamModel, "sid", _showStreams && streamSig !== "" ? streamSig.split(",") : [])
    }
    onStreamSigChanged: syncStreams()
    on_ShowStreamsChanged: syncStreams()
    Component.onCompleted: syncStreams()
    readonly property int pad: Config.mixer.cardPadding

    implicitHeight: body.implicitHeight + pad * 2
    radius: Config.mixer.cardRadius
    color: Theme.surfaceAlt

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: card.pad
        spacing: 6

        // Top line: icon · name/subtitle · chevron · mute
        Item {
            width: parent.width
            height: 30

            AppIcon {
                id: icon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                group: card.group
                muted: card.muted
            }

            Column {
                anchors.left: icon.right; anchors.leftMargin: 8
                anchors.right: chev.visible ? chev.left : mute.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: card.group ? card.group.name : ""
                    elide: Text.ElideRight
                    font.pixelSize: 13
                    color: card.muted ? Theme.foregroundDim : Theme.foreground
                }
                Text {
                    width: parent.width
                    visible: card.subtitle !== ""
                    text: card.subtitle
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Theme.foregroundDim
                }
            }

            Text {
                id: chev
                anchors.right: mute.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 14; horizontalAlignment: Text.AlignHCenter
                visible: card.foldable
                text: card.expanded ? "\u{F077}" : "\u{F078}"   // chevron up / down
                font.family: "Symbols Nerd Font"; font.pixelSize: 11
                color: Theme.foregroundDim
                MouseArea {
                    anchors.fill: parent; anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.toggleExpanded()
                }
            }

            MuteButton {
                id: mute
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: 28
                muted: card.muted
                onToggled: MixerService.toggleGroupMute(card.group.key)
            }
        }

        // Slider line: slider · % (or "muted")
        Item {
            width: parent.width
            height: Config.controlcenter.sliderHeight

            ControlSlider {
                id: appSlider
                anchors.left: parent.left
                anchors.right: pct.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                glyph: ""
                trackColor: Theme.surface
                fillColor: card.muted ? Theme.border : Theme.accent
                knobColor: card.muted ? Theme.border : Theme.foreground
                value: card.group ? card.group.volume : 0
                onMoved: (v) => MixerService.setGroupVolume(card.group.key, v)
            }
            Text {
                id: pct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 40; horizontalAlignment: Text.AlignRight
                text: card.muted ? "muted" : (card.group ? M.percent(appSlider.shownValue) : "")
                font.pixelSize: 11; font.family: "monospace"
                color: card.muted ? Theme.urgent : Theme.foregroundDim
            }
        }

        // Fold-out: one row per stream
        Rectangle {
            width: parent.width; height: 1
            visible: card._showStreams
            color: Theme.border
        }
        // Stream ids drive streamModel (diffed in place): groups is rebuilt
        // on every volume change, so binding the streams array directly would
        // recreate the rows mid-drag.
        Repeater {
            model: streamModel
            delegate: Item {
                id: srow
                required property string sid
                readonly property var stream: card.group
                    ? (card.group.streams.find(s => String(s.id) === srow.sid)
                       || { id: -1, label: "", volume: 0, muted: false })
                    : { id: -1, label: "", volume: 0, muted: false }
                width: body.width
                height: Config.controlcenter.sliderHeight

                Text {
                    id: slabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Config.mixer.childLabelWidth
                    text: srow.stream.label
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: srow.stream.muted ? Theme.border : Theme.foregroundDim
                }
                ControlSlider {
                    id: sslider
                    anchors.left: slabel.right; anchors.leftMargin: 8
                    anchors.right: spct.left; anchors.rightMargin: 6
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
                    anchors.right: smute.left; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; horizontalAlignment: Text.AlignRight
                    text: srow.stream.muted ? "muted" : M.percent(sslider.shownValue)
                    font.pixelSize: 10; font.family: "monospace"
                    color: srow.stream.muted ? Theme.urgent : Theme.foregroundDim
                }
                MuteButton {
                    id: smute
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    muted: srow.stream.muted
                    onToggled: MixerService.toggleStreamMute(srow.stream.id)
                }
            }
        }
    }
}
