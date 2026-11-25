import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import

// Fullscreen power menu: blurred current-wallpaper backdrop + a 3+2 grid of
// keyboard-driven action cards. Window shell, controller wiring, and Esc /
// click-outside dismissal are inherited from the Spec A overlay. PowerActions
// and PowerButton are same-directory components (no import needed).
PanelWindow {
    id: overlay
    property var controller
    property var barScreen
    property int activeIndex: 0
    screen: barScreen

    visible: controller && controller.active === "power"
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive so the modal grabs the keyboard the moment it opens (the menu is
    // summoned by a click on the bar pill, a different surface) — Esc and the
    // L/S/R/P/Q hotkeys must work without first clicking into the overlay.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible) {
            overlay.activeIndex = 0
            Wallpaper.refresh()
        }
    }

    PowerActions { id: actions }

    Process { id: actionProc }
    function run(cmd) {
        actionProc.command = cmd
        actionProc.running = true
        overlay.controller.close()
    }

    // --- Backdrop: opaque base + blurred current wallpaper + dim ---
    // Opaque base so the real desktop (niri + the quill bar) can NEVER show
    // through, even where the blur's soft edges go transparent.
    Rectangle { anchors.fill: parent; color: Theme.background }

    // Pre-blurred wallpaper, rendered once per wallpaper by the Wallpaper
    // service. Drawn as a plain Image instead of a live MultiEffect blur:
    // layer-shell windows are destroyed and recreated on every visible toggle,
    // which forces the Image to reload on each open — the small cached file
    // decodes in ~15 ms (async), so the backdrop lands with the cards instead
    // of ~250 ms after them like the raw 18 MP wallpaper did.
    Image {
        id: wp
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: Wallpaper.blurredPath ? "file://" + Wallpaper.blurredPath : ""
        opacity: overlay.visible && status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }
    }
    Rectangle {                      // dim; also the click-outside catcher
        anchors.fill: parent
        color: Theme.background
        opacity: overlay.visible ? Config.power.dimOpacity : 0
        Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }
        MouseArea { anchors.fill: parent; onClicked: overlay.controller.close() }
    }

    // --- Keyboard: hotkeys, arrows, Enter, Esc ---
    Item {
        anchors.fill: parent
        focus: overlay.visible
        Keys.onEscapePressed: overlay.controller.close()
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Left)       { overlay.activeIndex = actions.navigate(overlay.activeIndex, "left");  event.accepted = true }
            else if (event.key === Qt.Key_Right) { overlay.activeIndex = actions.navigate(overlay.activeIndex, "right"); event.accepted = true }
            else if (event.key === Qt.Key_Up)    { overlay.activeIndex = actions.navigate(overlay.activeIndex, "up");    event.accepted = true }
            else if (event.key === Qt.Key_Down)  { overlay.activeIndex = actions.navigate(overlay.activeIndex, "down");  event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                overlay.run(actions.actions[overlay.activeIndex].command); event.accepted = true
            } else {
                var idx = actions.indexForKey(event.text)
                if (idx >= 0) { overlay.run(actions.actions[idx].command); event.accepted = true }
            }
        }
    }

    // --- Card cluster: 3 + 2 grid, fade + subtle scale in ---
    Column {
        anchors.centerIn: parent
        spacing: Config.power.gridSpacing
        opacity: overlay.visible ? 1 : 0
        scale: overlay.visible ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }
        Behavior on scale   { NumberAnimation { duration: Config.shape.animDuration } }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Config.power.gridSpacing
            Repeater {
                model: [0, 1, 2]
                delegate: PowerButton {
                    required property int modelData
                    glyph: actions.actions[modelData].glyph
                    label: actions.actions[modelData].label
                    keyhint: actions.actions[modelData].keyhint
                    active: overlay.activeIndex === modelData
                    onActivated: overlay.run(actions.actions[modelData].command)
                    onHovered: overlay.activeIndex = modelData
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Config.power.gridSpacing
            Repeater {
                model: [3, 4]
                delegate: PowerButton {
                    required property int modelData
                    glyph: actions.actions[modelData].glyph
                    label: actions.actions[modelData].label
                    keyhint: actions.actions[modelData].keyhint
                    active: overlay.activeIndex === modelData
                    onActivated: overlay.run(actions.actions[modelData].command)
                    onHovered: overlay.activeIndex = modelData
                }
            }
        }
    }
}
