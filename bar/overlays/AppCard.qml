pragma ComponentBehavior: Bound
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/mixer.js" as M

// One app on the mixer page, "cards" layout (#18, #72): top line = icon,
// name over subtitle (track/tab title, or "2 tabs playing"), chevron when
// there are 2+ streams, mute button; then the app slider and % ("muted"
// when muted). Fold-out: one row per stream (2+ streams), each with its own
// mute button, then the Outputs section (#20) for routable apps; the route
// chip sits left of the chevron. `group` is a MixerService.groups entry.
Rectangle {
    id: card
    property var group
    property bool expanded: false
    signal toggleExpanded()

    readonly property bool muted: !!group && VolumeService.appMuted(group.key)
    readonly property bool foldable: M.showFoldout(group, "cards")
    readonly property string subtitle: group ? group.subtitle : ""
    readonly property string streamSig: group ? group.streams.map(s => s.id).join(",") : ""
    // Fold-out rows diffed in place, like MixerPage's cards (see there).
    ListModel { id: streamModel }
    // Stream rows keep their own rule (2+ streams); routable single-stream
    // cards fold out for the Outputs section only.
    readonly property bool _showStreams: expanded && M.showFoldout({ streams: group ? group.streams : [] }, "cards")
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
                anchors.right: route.visible ? route.left : (chev.visible ? chev.left : mute.left)
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

            RouteChip {
                id: route
                anchors.right: chev.visible ? chev.left : mute.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                group: card.group
                maxWidth: 110
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
                onToggled: VolumeService.toggleAppMute(card.group.key)
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
                value: card.group ? VolumeService.appLevel(card.group.key) : 0
                onMoved: (v) => VolumeService.setAppLevel(card.group.key, v)
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

        // Fold-out: one row per stream, then Outputs
        Rectangle {
            width: parent.width; height: 1
            visible: card.expanded && card.foldable
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
                    color: VolumeService.tabMuted(srow.stream.id) ? Theme.border : Theme.foregroundDim
                }
                ControlSlider {
                    id: sslider
                    anchors.left: slabel.right; anchors.leftMargin: 8
                    anchors.right: spct.left; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: ""
                    trackColor: Theme.surface
                    fillColor: VolumeService.tabMuted(srow.stream.id) ? Theme.border : Theme.accent
                    knobColor: VolumeService.tabMuted(srow.stream.id) ? Theme.border : Theme.foreground
                    value: VolumeService.tabLevel(srow.stream.id)
                    onMoved: (v) => VolumeService.setTabLevel(srow.stream.id, v)
                }
                Text {
                    id: spct
                    anchors.right: smute.left; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; horizontalAlignment: Text.AlignRight
                    text: VolumeService.tabMuted(srow.stream.id) ? "muted" : M.percent(sslider.shownValue)
                    font.pixelSize: 10; font.family: "monospace"
                    color: VolumeService.tabMuted(srow.stream.id) ? Theme.urgent : Theme.foregroundDim
                }
                MuteButton {
                    id: smute
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    muted: VolumeService.tabMuted(srow.stream.id)
                    onToggled: VolumeService.toggleTabMute(srow.stream.id)
                }
            }
        }

        OutputsSection {
            width: parent.width
            visible: card.expanded && !!card.group && card.group.routable
            group: card.group
        }
    }
}
