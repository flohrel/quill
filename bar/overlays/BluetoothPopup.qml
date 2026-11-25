import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../notifications"

// Dedicated Bluetooth manager popup. Summoned by the ControlsPill bluetooth
// icon. Single-page (no pager/detail — per-device info/actions live inline
// in BluetoothRow's expand strip, unlike NetworkPopup's slide-in detail page).
// Exclusive keyboard focus matches NetworkPopup for consistency, even though
// there's no text field to protect here.
PanelWindow {
    id: popup
    property var controller
    property var barScreen
    screen: barScreen

    visible: controller && controller.active === "bluetooth"
    onVisibleChanged: {
        if (visible) {
            BluetoothService.startScan()
        } else {
            BluetoothService.stopScan()
        }
    }
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
        width: Config.bluetooth.popupWidth
        height: listCol.implicitHeight + Config.bluetooth.padding * 2
        anchors.right: parent.right
        anchors.rightMargin: Config.shape.edgeGap
        y: Config.shape.edgeGap + Config.shape.barHeight + Config.shape.overlayMargin
        radius: Config.shape.overlayRadius
        color: Theme.surface
        clip: true

        Behavior on height { NumberAnimation { duration: Config.bluetooth.expandAnimDuration } }

        MouseArea { anchors.fill: parent }   // swallow clicks on the panel

        Column {
            id: listCol
            width: Config.bluetooth.popupWidth - Config.bluetooth.padding * 2
            anchors { top: parent.top; left: parent.left; margins: Config.bluetooth.padding }
            spacing: Config.bluetooth.sectionGap

            // header: title + Turn-off pill
            Item {
                width: parent.width; height: 24
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth"; color: Theme.foreground; font.pixelSize: 15
                }
                Rectangle {
                    id: turnOff
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: turnOffLabel.implicitWidth + 18; height: 22; radius: 11
                    color: Theme.surfaceAlt
                    Text {
                        id: turnOffLabel
                        anchors.centerIn: parent
                        text: "Turn off"; color: Theme.foregroundDim; font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { BluetoothService.setEnabled(false); popup.controller.close() }
                    }
                }
            }

            Text {
                text: "PAIRED"; font.pixelSize: 10; color: Theme.foregroundDim
                font.capitalization: Font.AllUppercase
                visible: BluetoothService.pairedDevices.length > 0
            }
            Column {
                width: parent.width
                spacing: 2
                Repeater {
                    model: BluetoothService.pairedDevices
                    delegate: BluetoothRow {
                        width: listCol.width
                        device: modelData
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 1; color: Theme.surfaceAlt
                visible: BluetoothService.pairedDevices.length > 0
            }

            Text {
                text: "AVAILABLE"; font.pixelSize: 10; color: Theme.foregroundDim
                font.capitalization: Font.AllUppercase
            }
            ListView {
                width: parent.width
                height: Math.min(contentHeight, Config.bluetooth.listHeight)
                clip: true
                spacing: 2
                model: BluetoothService.availableDevices
                delegate: BluetoothRow {
                    width: ListView.view.width
                    device: modelData
                }
            }

            Text {   // footer hint
                width: parent.width
                text: "tap = connect/pair · chevron = options"
                color: Theme.foregroundDim; font.pixelSize: 9
                horizontalAlignment: Text.AlignHCenter
            }
        }

        opacity: popup.visible ? 1 : 0
        transform: Translate { y: popup.visible ? 0 : -6 }
        Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }
    }
}
