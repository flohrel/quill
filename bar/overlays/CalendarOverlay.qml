import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config   // qmllint disable import
import "../notifications"

// Fullscreen transparent catcher. Click-outside / Esc dismiss; the calendar
// floats centered just below the bar and animates in. CalendarView is a
// same-directory component (bar/overlays/), so it needs no import.
// Exclusive keyboard focus even though mouse-driven: with OnDemand, niri
// consumes the click that pulls focus off the layer surface, so the first
// bar-band click would be eaten instead of switching popups.
PanelWindow {
    id: overlay
    property var controller
    property var barScreen
    screen: barScreen

    visible: controller && controller.active === "calendar"
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Input region excludes the bar band so the pills stay clickable while
    // this overlay is open (popup-to-popup switching). Blank-band clicks are
    // handled by Bar.qml's dismiss MouseArea.
    mask: Region {
        id: passRegion
        y: Config.shape.edgeGap + Config.shape.barHeight
        width: overlay.width
        height: overlay.height - passRegion.y
        NotificationHole { controller: overlay.controller; windowWidth: overlay.width }
    }

    // Click anywhere on the catcher (outside the calendar) closes.
    MouseArea {
        anchors.fill: parent
        onClicked: overlay.controller.close()
    }

    // Esc closes.
    Item {
        anchors.fill: parent
        focus: overlay.visible
        Keys.onEscapePressed: overlay.controller.close()
    }

    CalendarView {
        id: cal
        anchors.horizontalCenter: parent.horizontalCenter
        y: Config.shape.edgeGap + Config.shape.barHeight + Config.shape.overlayMargin
        // swallow clicks on the calendar itself so they don't dismiss
        MouseArea { anchors.fill: parent }
        // animate in: fade + slight slide
        opacity: overlay.visible ? 1 : 0
        transform: Translate { y: overlay.visible ? 0 : -6 }
        Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }
    }
}
