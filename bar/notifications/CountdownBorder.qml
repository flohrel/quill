import QtQuick
import QtQuick.Shapes
import "../../services/notifications.js" as N

// Border countdown look (#67): an accent stroke over the card's border that
// drains like a clock hand. The erased part grows clockwise from the top
// centre. The path is traced counterclockwise from the top centre, and a
// single dash of `fraction × perimeter` keeps the part not yet swept. Pure
// QtQuick so tests can load it.
Shape {
    id: root
    property real fraction: 0
    property real radius: 0
    property real strokeWidth: 1
    property color color: "white"

    // The stroke is centred on a rect inset by half its width.
    readonly property real _s: strokeWidth / 2
    readonly property real _w: Math.max(0, width - strokeWidth)
    readonly property real _h: Math.max(0, height - strokeWidth)
    readonly property real _r: Math.max(0, Math.min(radius - _s, _w / 2, _h / 2))
    readonly property real perimeter: N.roundedRectPerimeter(_w, _h, _r)

    visible: fraction > 0 && perimeter > 0
    // MSAA keeps the 16px corners smooth (GeometryRenderer is aliased alone).
    layer.enabled: true
    layer.samples: 4

    ShapePath {
        strokeColor: root.color
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.RoundJoin
        strokeStyle: ShapePath.DashLine
        // Units are stroke widths: one dash of the remaining length, then a
        // gap longer than the whole loop so it never repeats.
        dashPattern: [root.fraction * root.perimeter / root.strokeWidth,
                      root.perimeter / root.strokeWidth + 1]

        startX: root.width / 2; startY: root._s
        PathLine { x: root._s + root._r; y: root._s }
        PathArc { x: root._s; y: root._s + root._r; radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root._s; y: root.height - root._s - root._r }
        PathArc { x: root._s + root._r; y: root.height - root._s; radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root._s - root._r; y: root.height - root._s }
        PathArc { x: root.width - root._s; y: root.height - root._s - root._r; radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root._s; y: root._s + root._r }
        PathArc { x: root.width - root._s - root._r; y: root._s; radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root.width / 2; y: root._s }
    }
}
