import QtQuick
import Quickshell
import qs.config     // qmllint disable import
import "../../services/mixer.js" as M

// An app's icon on the mixer (#18, #72), shared by AppCard and AppRow:
// first icon-theme candidate that resolves, then a matching desktop entry's
// icon, else a coloured letter tile. Dimmed when muted. Not clickable:
// muting has its own MuteButton.
Item {
    id: root
    property var group
    property bool muted: false
    width: Config.mixer.iconSize
    height: Config.mixer.iconSize
    opacity: muted ? 0.45 : 1

    Image {
        id: img
        anchors.fill: parent
        sourceSize.width: width; sourceSize.height: height
        // Spotify's icon is "spotify-client"; only its .desktop knows that.
        // heuristicLookup isn't reactive and desktop entries load async: a
        // card created before they arrive resolved nothing and never retried
        // (#71). Reading the entry count makes the binding re-run on load.
        source: {
            void DesktopEntries.applications.values.length
            const cands = root.group ? root.group.iconCandidates : []
            for (let i = 0; i < cands.length; i++) {
                const p = Quickshell.iconPath(cands[i], true)
                if (p) return p
            }
            for (let j = 0; j < cands.length; j++) {
                const e = DesktopEntries.heuristicLookup(cands[j])
                const q = e && e.icon ? Quickshell.iconPath(e.icon, true) : ""
                if (q) return q
            }
            return ""
        }
        visible: status === Image.Ready
    }
    Rectangle {   // letter tile when there's no usable icon
        anchors.fill: parent
        visible: !img.visible
        radius: Config.mixer.iconRadius
        color: root.group
               ? [Theme.accent, Theme.success, Theme.warning, Theme.urgent][M.tileIndex(root.group.key, 4)]
               : Theme.border
        Text {
            anchors.centerIn: parent
            text: root.group ? root.group.name.charAt(0).toUpperCase() : "?"
            font.pixelSize: 11; font.bold: true
            color: Theme.background
        }
    }
}
