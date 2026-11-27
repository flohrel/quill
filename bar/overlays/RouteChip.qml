pragma ComponentBehavior: Bound
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import

// Where an app's sound goes (#20): "→ Default", "→ <device>" (pinned,
// yellow) or "→ <device> · unplugged" (grey, the app is on the default
// until the device returns). `group` is a MixerService.groups entry; only
// routable groups show a chip.
Rectangle {
    id: chip
    property var group
    property real maxWidth: 120
    readonly property var info: group ? MixerService.routeChip(group.key) : ({ text: "", kind: "default" })
    readonly property color textColor: info.kind === "pinned" ? Theme.warning
                                     : (info.kind === "unplugged" ? Theme.border : Theme.foregroundDim)

    visible: !!group && group.routable
    implicitWidth: Math.min(label.implicitWidth + 12, maxWidth)
    implicitHeight: 18
    radius: 6
    color: Theme.surface

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: 6
        width: chip.width - 12
        text: chip.info.text
        elide: Text.ElideRight
        font.pixelSize: 11
        color: chip.textColor
    }
}
