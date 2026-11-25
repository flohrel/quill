import QtQuick

// gruvbox-material (dark, hard). Keep in sync by hand with the palette your
// terminal and compositor use. Role -> color; the ONLY place literal hex
// lives. A future switcher swaps in another provider object.
QtObject {
    readonly property color background:    "#1d2021"  // bg0 (hard)
    readonly property color surface:       "#282828"  // bg1
    readonly property color surfaceAlt:    "#32302f"  // bg2
    readonly property color foreground:    "#d4be98"  // fg0
    readonly property color foregroundDim: "#928374"  // grey1
    readonly property color accent:        "#7daea3"  // blue (system active/highlight color)
    readonly property color urgent:        "#ea6962"  // red
    readonly property color success:       "#a9b665"  // green
    readonly property color warning:       "#d8a657"  // yellow
    readonly property color error:         "#ea6962"  // red
    readonly property color border:        "#504945"  // bg5
}
