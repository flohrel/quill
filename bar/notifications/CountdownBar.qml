import QtQuick

// Bar countdown look (#67): a thin line just inside the card's bottom border,
// spanning only the straight edge between the rounded corners (`inset`), and
// shrinking from the right. Pure QtQuick so tests can load it.
Item {
    id: root
    property real fraction: 0
    property real inset: 0
    property real thickness: 2
    property color color: "white"
    readonly property alias fill: fill

    Rectangle {
        id: fill
        x: root.inset
        y: root.height - 1 - root.thickness
        width: root.fraction * Math.max(0, root.width - 2 * root.inset)
        height: root.thickness
        radius: root.thickness / 2
        color: root.color
        visible: root.fraction > 0
    }
}
