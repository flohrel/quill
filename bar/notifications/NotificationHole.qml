import Quickshell
import qs.config   // qmllint disable import

// Subtracts the notification stack from a fullscreen catcher's input mask
// (#14). Overlay catchers sit above the popup surface, so without this hole a
// click on a card would land on the catcher and close the overlay instead of
// reaching the card. Geometry comes from OverlayController.notifTop /
// notifHeight, published by this bar's NotificationPopups (0 height when the
// stack isn't shown on this output). Use as a child of the catcher's mask.
Region {
    required property var controller
    required property real windowWidth

    intersection: Intersection.Subtract
    x: windowWidth - Config.shape.edgeGap - Config.notifications.width
    y: controller ? controller.notifTop : 0
    width: Config.notifications.width
    height: controller ? controller.notifHeight : 0
}
