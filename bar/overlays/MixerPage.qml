pragma ComponentBehavior: Bound
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/mixer.js" as M

// Control Center → Mixer page (#18): back header, master row, then one
// AppCard per app with an open output stream (scrolls past
// Config.mixer.maxVisibleCards). BackHeader, ControlSlider and AppCard are
// same-directory components.
Column {
    id: page
    signal back()
    spacing: 12

    // Fold-out state per group key. Reassigned (copy + toggle), never
    // mutated in place, so the cards' `expanded` bindings update.
    property var expandedKeys: ({})
    function reset() { expandedKeys = ({}); list.positionViewAtBeginning() }
    function toggle(key) {
        const next = Object.assign({}, expandedKeys)
        if (next[key]) delete next[key]; else next[key] = true
        expandedKeys = next
    }

    // keySig only changes when the set/order of apps does (volume echoes
    // rebuild groups but leave it equal), and keyModel follows it.
    readonly property string keySig: MixerService.groups.map(g => g.key).join("\n")
    // Rows are diffed in place (M.syncListModel), never reassigned, so a
    // card that survives an app appearing/quitting keeps its delegate — and
    // any drag in progress on it.
    ListModel { id: keyModel }
    function syncKeys() { M.syncListModel(keyModel, "gkey", keySig === "" ? [] : keySig.split("\n")) }
    onKeySigChanged: syncKeys()
    Component.onCompleted: syncKeys()
    // Collapsed height of one entry, per Config.mixer.layout (#72). Cards:
    // padding + 30 px top line (name over subtitle) + 6 px + slider line.
    // Rows: one 32 px line.
    readonly property bool rows: Config.mixer.layout === "rows"
    readonly property int collapsedCardHeight: rows ? 32
        : Config.mixer.cardPadding * 2 + 30 + 6 + Config.controlcenter.sliderHeight
    readonly property int entryGap: rows ? 2 : Config.mixer.cardGap

    BackHeader { label: "Mixer"; onBack: page.back() }

    // Master row: mute button · slider · % (or "muted")
    Item {
        width: parent.width
        height: Config.controlcenter.sliderHeight

        MuteButton {
            id: spk
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            size: 24
            muted: AudioService.muted
            onToggled: AudioService.toggleMute()
        }
        ControlSlider {
            id: masterSlider
            anchors.left: spk.right; anchors.leftMargin: 8
            anchors.right: mpct.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            glyph: ""
            fillColor: AudioService.muted ? Theme.border : Theme.accent
            knobColor: AudioService.muted ? Theme.border : Theme.foreground
            value: AudioService.volume
            onMoved: (v) => AudioService.setVolume(v)
        }
        Text {
            id: mpct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40; horizontalAlignment: Text.AlignRight
            text: AudioService.muted ? "muted" : M.percent(masterSlider.shownValue)
            font.pixelSize: 11; font.family: "monospace"
            color: AudioService.muted ? Theme.urgent : Theme.foregroundDim
        }
    }

    Rectangle { width: parent.width; height: 1; color: Theme.surfaceAlt }

    Text {
        visible: page.keySig === ""
        text: "Nothing playing"
        font.pixelSize: 12
        color: Theme.foregroundDim
    }

    ListView {
        id: list
        visible: page.keySig !== ""
        width: parent.width
        clip: true
        spacing: page.entryGap
        readonly property int cap: Config.mixer.maxVisibleCards * page.collapsedCardHeight
                                   + (Config.mixer.maxVisibleCards - 1) * page.entryGap
        height: Math.min(contentHeight, cap)
        interactive: contentHeight > cap
        boundsBehavior: Flickable.StopAtBounds
        model: keyModel
        // One Loader per app picks the layout. The list model is keyed by
        // group key (above), so volume echoes never recreate a Loader.
        delegate: Loader {
            id: entry
            required property string gkey
            width: list.width
            sourceComponent: page.rows ? rowComp : cardComp

            Component {
                id: cardComp
                AppCard {
                    group: MixerService.groups.find(g => g.key === entry.gkey) || null
                    expanded: !!page.expandedKeys[entry.gkey]
                    onToggleExpanded: page.toggle(entry.gkey)
                }
            }
            Component {
                id: rowComp
                AppRow {
                    group: MixerService.groups.find(g => g.key === entry.gkey) || null
                    expanded: !!page.expandedKeys[entry.gkey]
                    onToggleExpanded: page.toggle(entry.gkey)
                }
            }
        }
    }
}
