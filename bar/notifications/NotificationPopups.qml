import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/notifications.js" as N

// Per-bar notification popup surface (#14). Every bar has one; only the bar on
// the focused output (N.popupScreen) shows the shared stack from
// NotificationService. Never takes keyboard focus; the input region is masked
// to the cards so clicks elsewhere reach the windows below. Independent of
// OverlayController: popups don't open or close overlays.
PanelWindow {
    id: popups
    property var controller
    property var barScreen
    screen: barScreen

    readonly property bool isPopupScreen: barScreen !== undefined && barScreen !== null
        && N.popupScreen(NiriService.focusedOutput, Quickshell.screens.map(s => s.name)) === barScreen.name
    readonly property var visible5: N.visibleIds(NotificationService.order, Config.notifications.maxVisible)

    visible: isPopupScreen && NotificationService.order.length > 0
    color: "transparent"
    // Fixed full-height surface: sizing it to the (animated) stack resized the
    // layer surface every frame, which made the slide laggy. The mask keeps
    // input limited to the cards.
    anchors { top: true; bottom: true; right: true }
    implicitWidth: Config.notifications.width + Config.shape.edgeGap
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: stack }

    // Publish the stack's geometry so overlay catchers can let clicks through.
    Binding { target: popups.controller; property: "notifTop"; value: stack.y; when: popups.controller !== undefined && popups.controller !== null }
    Binding { target: popups.controller; property: "notifHeight"; value: popups.visible ? stack.height : 0; when: popups.controller !== undefined && popups.controller !== null }

    Column {
        id: stack
        x: 0
        // Below an open right-column overlay, else just under the bar (#14).
        y: popups.controller && popups.controller.rightPanelBottom > 0
            ? popups.controller.rightPanelBottom + Config.shape.overlayMargin
            : Config.shape.edgeGap + Config.shape.barHeight + Config.shape.overlayMargin
        Behavior on y { NumberAnimation { duration: Config.shape.animDuration } }
        spacing: Config.notifications.spacing

        Repeater {
            model: NotificationService.popupModel
            delegate: NotificationCard {
                required property int nid
                notifId: nid
                visible: popups.visible5.indexOf(nid) !== -1
            }
        }
    }
}
