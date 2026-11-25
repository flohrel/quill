import QtQuick
import qs.config   // qmllint disable import
import "slider.js" as S

// Reusable control slider: left glyph + accent-filled draggable track.
// `value` reflects the backend (0..1) and `moved(v)` drives it live. While
// pressed the fill holds the drag position (S.displayValue) so late backend
// echoes can't jitter it. Empty `glyph` collapses the icon column;
// `showMore` adds a trailing chevron that emits `more()` (#18 mixer entry).
// A round knob sits on the fill's end (#72); the track is inset by half the
// knob so it never overhangs a clipping parent (the mixer list).
Item {
    id: root
    property string glyph: ""
    property real value: 0
    property color fillColor: Theme.accent
    property color trackColor: Theme.surfaceAlt
    property bool showMore: false
    property bool knob: true
    property color knobColor: Theme.foreground
    readonly property int knobSize: 14
    readonly property real _inset: knob ? knobSize / 2 : 0
    signal moved(real v)
    signal more()

    property real _dragValue: 0
    // What the fill shows (drag position while pressed) — bind % labels to
    // this so the number moves with the fill instead of lagging the echoes.
    readonly property real shownValue: S.displayValue(drag.pressed, _dragValue, value)

    implicitHeight: Config.controlcenter.sliderHeight
    implicitWidth: 200

    Text {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyph === "" ? 0 : Config.controlcenter.sliderIconWidth
        visible: root.glyph !== ""
        text: root.glyph
        font.family: "Symbols Nerd Font"
        font.pixelSize: Config.controlcenter.sliderIconSize
        color: Theme.foreground
    }

    Rectangle {
        id: track
        anchors.left: icon.right
        anchors.right: more.left
        anchors.rightMargin: root.showMore ? 8 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: Config.controlcenter.sliderTrackHeight
        radius: height / 2
        color: root.trackColor

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.knob ? S.knobCenter(root.shownValue, track.width, root._inset)
                             : parent.width * root.shownValue
            radius: parent.radius
            color: root.fillColor
        }

        Rectangle {   // knob
            visible: root.knob
            width: root.knobSize; height: root.knobSize
            radius: width / 2
            x: S.knobCenter(root.shownValue, track.width, root._inset) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.knobColor
            border.width: 1
            border.color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.5)
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            // Cover the knob's full height, not just the 6 px track.
            anchors.topMargin: -Math.max(0, (root.knobSize - track.height) / 2)
            anchors.bottomMargin: -Math.max(0, (root.knobSize - track.height) / 2)
            preventStealing: true   // a scrolling mixer list must not grab the drag
            function emit(x) { root._dragValue = S.fraction(x, width, root._inset); root.moved(root._dragValue) }
            onPressed: (m) => emit(m.x)
            onPositionChanged: (m) => { if (pressed) emit(m.x) }
        }
    }

    Text {
        id: more
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.showMore ? implicitWidth : 0
        visible: root.showMore
        text: "\u{F054}"   // nf-fa-chevron_right
        font.family: "Symbols Nerd Font"
        font.pixelSize: Config.controlcenter.sliderIconSize - 3
        color: Theme.foregroundDim

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: root.more()
        }
    }
}
