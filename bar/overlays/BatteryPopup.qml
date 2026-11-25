import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../lib/format.js" as Format
import "../../services/power.js" as Power
import "../notifications"

// Battery manager popup. Summoned by the ControlsPill battery icon. Two-page
// slide pager (modeled on NetworkPopup/WifiDetail): page 1 shows charge/state/time
// + a tappable "Power profile" row; page 2 is the Saver/Balanced/Performance
// selector. Exclusive keyboard focus even though mouse-driven: with OnDemand,
// niri consumes the click that pulls focus off the layer surface, so the first
// bar-band click would be eaten instead of switching popups.
PanelWindow {
    id: popup
    property var controller
    property var barScreen
    screen: barScreen

    // page navigation: false = battery page, true = profile page
    property bool showProfile: false

    visible: controller && controller.active === "battery"
    onVisibleChanged: if (!visible) popup.showProfile = false   // never reopen onto page 2

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Input region excludes the bar band so the pills stay clickable while
    // this popup is open (popup-to-popup switching). Blank-band clicks are
    // handled by Bar.qml's dismiss MouseArea.
    mask: Region {
        id: passRegion
        y: Config.shape.edgeGap + Config.shape.barHeight
        width: popup.width
        height: popup.height - passRegion.y
        NotificationHole { controller: popup.controller; windowWidth: popup.width }
    }

    MouseArea { anchors.fill: parent; onClicked: popup.controller.close() }
    Item { anchors.fill: parent; focus: popup.visible; Keys.onEscapePressed: popup.controller.close() }

    // Push the notification stack below this panel while open (#14).
    Binding {
        target: popup.controller
        property: "rightPanelBottom"
        value: panel.y + panel.height
        when: popup.visible && popup.controller !== undefined && popup.controller !== null
        restoreMode: Binding.RestoreNone
    }

    Rectangle {
        id: panel
        width: Config.battery.popupWidth
        height: (popup.showProfile ? profilePage.implicitHeight : batteryPage.implicitHeight)
                + Config.battery.padding * 2
        anchors.right: parent.right
        anchors.rightMargin: Config.shape.edgeGap
        y: Config.shape.edgeGap + Config.shape.barHeight + Config.shape.overlayMargin
        radius: Config.shape.overlayRadius
        color: Theme.surface
        clip: true

        Behavior on height { NumberAnimation { duration: Config.battery.profileAnimDuration } }

        MouseArea { anchors.fill: parent }   // swallow clicks on the panel

        Item {
            id: pager
            width: parent.width * 2
            height: parent.height
            x: popup.showProfile ? -Config.battery.popupWidth : 0
            Behavior on x { NumberAnimation { duration: Config.battery.profileAnimDuration; easing.type: Easing.OutCubic } }

            // ---- page 1: battery ----
            Column {
                id: batteryPage
                width: Config.battery.popupWidth - Config.battery.padding * 2
                anchors { top: parent.top; left: parent.left; margins: Config.battery.padding }
                spacing: Config.battery.sectionGap

                Text {
                    text: "Battery"; color: Theme.foreground; font.pixelSize: 15
                }
                Text {
                    width: parent.width
                    text: Format.batteryStat(BatteryService.percent, BatteryService.state,
                                             BatteryService.timeToEmpty, BatteryService.timeToFull)
                    color: Theme.foregroundDim; font.pixelSize: 12
                }

                Rectangle { width: parent.width; height: 1; color: Theme.surfaceAlt }

                // tappable "Power profile" row -> page 2
                Item {
                    width: parent.width; height: 40
                    Text {
                        id: ppGlyph
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: Power.profileGlyph(PowerProfileService.profile)
                        font.family: "Symbols Nerd Font"; font.pixelSize: 16
                        color: Theme.foreground
                    }
                    Column {
                        anchors.left: ppGlyph.right; anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "POWER PROFILE"; font.pixelSize: 10; color: Theme.foregroundDim
                            font.capitalization: Font.AllUppercase
                        }
                        Text {
                            text: Power.profileLabel(PowerProfileService.profile)
                            font.pixelSize: 13; color: Theme.foreground
                        }
                    }
                    Text {   // chevron-right
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F054}"; font.family: "Symbols Nerd Font"; font.pixelSize: 13
                        color: Theme.foregroundDim
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.showProfile = true
                    }
                }
            }

            // ---- page 2: profile selector ----
            Column {
                id: profilePage
                width: Config.battery.popupWidth - Config.battery.padding * 2
                anchors { top: parent.top; left: parent.left
                          leftMargin: Config.battery.popupWidth + Config.battery.padding
                          topMargin: Config.battery.padding }
                spacing: Config.battery.sectionGap

                // header: back chevron + title
                Row {
                    width: parent.width; spacing: 8
                    Text {
                        text: "\u{F053}"   // back chevron (nf-fa-chevron_left)
                        font.family: "Symbols Nerd Font"; font.pixelSize: 15
                        color: Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.showProfile = false
                        }
                    }
                    Text {
                        text: "Power Profile"; color: Theme.foreground; font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.surfaceAlt }

                // one row per available profile
                Repeater {
                    model: PowerProfileService.available
                    delegate: Rectangle {
                        required property var modelData          // profile id (0/1/2)
                        readonly property bool selected: PowerProfileService.profile === modelData
                        width: profilePage.width
                        height: 48
                        radius: 10
                        color: selected ? Theme.surfaceAlt : "transparent"
                        border.width: selected ? 1 : 0
                        border.color: Theme.accent

                        Text {
                            id: rowGlyph
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Power.profileGlyph(parent.modelData)
                            font.family: "Symbols Nerd Font"; font.pixelSize: 16
                            color: parent.selected ? Theme.accent : Theme.foreground
                        }
                        Column {
                            anchors.left: rowGlyph.right; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: Power.profileLabel(modelData)
                                font.pixelSize: 13
                                color: selected ? Theme.accent : Theme.foreground
                            }
                            Text {
                                text: Power.profileDesc(modelData)
                                font.pixelSize: 10; color: Theme.foregroundDim
                            }
                        }
                        Text {   // selected indicator ● / ○
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: selected ? "●" : "○"
                            font.pixelSize: 13
                            color: selected ? Theme.accent : Theme.foregroundDim
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // apply immediately, stay on page 2 so the highlight moves
                            onClicked: PowerProfileService.setProfile(modelData)
                        }
                    }
                }
            }
        }

        opacity: popup.visible ? 1 : 0
        transform: Translate { y: popup.visible ? 0 : -6 }
        Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }
    }
}
