import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config     // qmllint disable import
import "../notifications"

// Fullscreen click-catcher behind an open tray context menu. The menu itself
// is a PopupWindow child of the bar (see pills/TrayMenu.qml), so unlike the
// other overlays it has no fullscreen window of its own to catch outside
// clicks — this surface supplies one: any click on the desktop or over a
// regular window closes the menu via the controller.
//
// Layer choice is load-bearing: this must be WlrLayer.Top, NOT Overlay like
// the other popups. niri renders (front to back): Overlay-layer popups,
// Overlay-layer surfaces, Top-layer popups, Top-layer surfaces, windows —
// and hit-tests input in the same order. The tray menu is an xdg_popup of
// the Top-layer bar, so an Overlay-layer catcher would sit ON TOP of the
// menu and swallow clicks on its rows; a Top-layer catcher sits below every
// Top-layer popup (the menu stays clickable) but above all regular windows
// and the desktop (outside clicks still land here).
PanelWindow {
    id: catcher
    property var controller
    property var barScreen
    screen: barScreen

    visible: controller && controller.active === "tray"

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    // No keyboard focus: the menu is mouse-driven; unlike the typing popups
    // (wifi password etc.) there is nothing to type, so never take the
    // keyboard from the focused application.

    // Input region excludes the bar band so the pills stay clickable while
    // the menu is open (pill-to-pill switching, tray icon toggling). Blank
    // bar-band clicks are handled by Bar.qml's dismiss MouseArea, which is
    // enabled whenever the controller has anything open — including "tray".
    mask: Region {
        id: passRegion
        y: Config.shape.edgeGap + Config.shape.barHeight
        width: catcher.width
        height: catcher.height - passRegion.y
        NotificationHole { controller: catcher.controller; windowWidth: catcher.width }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: catcher.controller.close()
    }
}
