import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "pills"
import "overlays"
import "notifications"

// Per-output bar: transparent window, three floating pills, one overlay
// coordinator, three overlay surfaces. Exclusive zone reserves the pill strip.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Config.shape.edgeGap + Config.shape.barHeight
    exclusiveZone: Config.shape.edgeGap + Config.shape.barHeight
    color: "transparent"

    OverlayController { id: overlay }

    // Volume layers (#22) must run from launch, not from the first time a
    // volume view opens: new streams start at their app's level, outside
    // changes are read back, and the `audio` IPC target is live. A singleton
    // starts on first reference, so reference it here.
    readonly property bool _volumeLayersLive: VolumeService.masterLevel >= 0

    // Caffeine: while CaffeineService.active, hold an idle inhibitor on this
    // always-visible bar surface. niri then reports the seat inhibited and stops
    // its ext-idle-notify-v1 stream, so swayidle's dim/lock/power-off timeouts
    // pause. One inhibitor per output (harmless): any visible bar inhibits the seat.
    IdleInhibitor {
        window: bar
        enabled: CaffeineService.active
    }

    // While an overlay is open its catcher masks out the bar band, so clicks
    // on blank bar space land on this window — keep them dismissing.
    MouseArea {
        anchors.fill: parent
        enabled: overlay.isOpen
        onClicked: overlay.close()
    }

    // Pill strip, floating below the top edge.
    Item {
        id: strip
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: Config.shape.edgeGap
            leftMargin: Config.shape.edgeGap
            rightMargin: Config.shape.edgeGap
        }
        height: Config.shape.barHeight

        WorkspacesPill {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.modelData
        }
        ClockPill {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            controller: overlay
        }
        ControlsPill {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            controller: overlay
        }
        TrayPill {
            id: tray
            anchors.right: controls.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            controller: overlay
        }
    }

    // Overlay surfaces (each its own fullscreen catcher window).
    CalendarOverlay      { controller: overlay; barScreen: bar.modelData }
    ControlCenterOverlay { controller: overlay; barScreen: bar.modelData }
    PowerOverlay         { controller: overlay; barScreen: bar.modelData }
    NetworkPopup         { controller: overlay; barScreen: bar.modelData }
    BluetoothPopup       { controller: overlay; barScreen: bar.modelData }
    BatteryPopup         { controller: overlay; barScreen: bar.modelData }
    // Outside-click dismissal for the tray context menu (which is a popup of
    // the bar itself, not a fullscreen window like the surfaces above).
    TrayCatcher          { controller: overlay; barScreen: bar.modelData }
    // Notification popups (#14): only the focused output's bar shows the stack.
    NotificationPopups   { controller: overlay; barScreen: bar.modelData }
}
