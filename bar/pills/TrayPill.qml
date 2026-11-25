import QtQuick
import Quickshell.Services.SystemTray
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import

// System tray pill: hosts third-party StatusNotifierItems (nm-applet,
// blueman, chat apps, ...) via Quickshell's built-in SystemTray module. Using
// SystemTray.items at all is what makes Quickshell provide the
// org.kde.StatusNotifierWatcher host on the session bus -- this pill is the
// only thing standing between "nothing owns that name" and a working tray.
//
// Ported from the retired legacy quickshell config's SystemTray.qml (same
// activate/secondaryActivate/context-menu logic), adapted to quill's
// Theme/pill conventions. Collapses to zero width when there are no tray
// items rather than leaving a gap in the bar.
Rectangle {
    id: pill

    property var controller
    readonly property var trayItems: SystemTray.items.values
    // Index of the tray icon whose context menu is open, or -1. WHICH icon's
    // menu is open stays local (the controller's `active` is one string per
    // overlay), but whether ANY tray menu is open is mirrored into the
    // controller as "tray" so the menu joins the bar's shared dismissal
    // machinery: Bar.qml's blank-band click-catcher (enabled while
    // overlay.isOpen), TrayCatcher's fullscreen outside-click surface, and
    // mutual exclusion with the other overlays (opening wifi closes the
    // menu and vice versa).
    property int openMenuIndex: -1

    onOpenMenuIndexChanged: {
        if (!controller)
            return
        if (openMenuIndex >= 0)
            controller.open("tray")
        else if (controller.active === "tray")
            controller.close()
    }

    // Anything else claiming the controller (another pill's overlay, a
    // dismissal via catcher / blank bar-band click) closes the open menu.
    Connections {
        target: pill.controller
        function onActiveChanged() {
            if (pill.controller.active !== "tray")
                pill.openMenuIndex = -1
        }
    }

    // If the open item's SNI vanishes (app quit), don't leave a stale index
    // pointing past the end of the model.
    onTrayItemsChanged: if (openMenuIndex >= trayItems.length) openMenuIndex = -1

    visible: trayItems.length > 0
    implicitWidth: visible ? row.implicitWidth + Config.shape.pillPaddingH * 2 : 0
    implicitHeight: Config.shape.barHeight
    radius: Config.shape.pillRadius
    color: Theme.surface
    clip: true

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: pill.trayItems

            delegate: MouseArea {
                id: iconArea
                required property var modelData
                required property int index

                // Full-height target with a little horizontal padding so the small glyph is
                // easy to hit; clicks in the dead space around it fall through to the bar.
                implicitWidth: 24
                implicitHeight: Config.shape.barHeight
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                function toggleMenu() {
                    pill.openMenuIndex = (pill.openMenuIndex === iconArea.index) ? -1 : iconArea.index
                }

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        // Some apps (nm-applet, blueman) have no left-click action; fall back to menu.
                        // Everything else goes through the niri-aware router (#39).
                        if (iconArea.modelData.onlyMenu)
                            iconArea.toggleMenu()
                        else
                            TrayService.activateItem(iconArea.modelData)
                    } else if (mouse.button === Qt.MiddleButton) {
                        iconArea.modelData.secondaryActivate()
                    } else if (mouse.button === Qt.RightButton) {
                        iconArea.toggleMenu()
                    }
                }

                Image {
                    anchors.centerIn: parent
                    source: iconArea.modelData.icon
                    sourceSize.width: 18
                    sourceSize.height: 18
                    width: 18
                    height: 18
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                // Themed right-click menu, anchored under this icon. Replaces the unthemed
                // native modelData.display() so the menu matches the gruvbox bar. Visibility
                // is a plain binding on pill.openMenuIndex, which also gives free mutual
                // exclusion across icons (opening one closes any other).
                TrayMenu {
                    id: trayMenu
                    menuHandle: iconArea.modelData.menu
                    anchorItem: iconArea
                    visible: pill.openMenuIndex === iconArea.index
                    onRequestClose: pill.openMenuIndex = -1
                }
            }
        }
    }
}
