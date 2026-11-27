import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../notifications"

// Control-center dropdown: 7 toggles (sound/mic/caffeine/wi-fi/bluetooth/airplane/do-not-disturb) over brightness +
// volume sliders. Window shell, controller wiring, and Esc / click-outside
// dismissal are inherited from the Spec-A overlay. ToggleButton and
// ControlSlider are same-directory components (no import). Exclusive keyboard
// focus even though mouse-driven: with OnDemand, niri consumes the click that
// pulls focus off the layer surface, so the first bar-band click would be
// eaten instead of switching popups. The Wi-Fi card is a pure radio
// toggle; network management lives in the dedicated NetworkPopup (right-pill network group).
PanelWindow {
    id: overlay
    property var controller
    property var barScreen
    screen: barScreen

    // Pages (#18): "main" (toggles + sliders) | "mixer" (per-app volumes).
    // Always reopens on "main"; fold-outs start closed each time the
    // mixer opens.
    property string page: "main"
    function openPage(name) { if (name === "mixer") mixerPage.reset(); page = name }
    function back() { page = "main" }
    function resetPages() { page = "main" }
    onVisibleChanged: if (!visible) resetPages()

    visible: controller && controller.active === "controlcenter"
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

    MouseArea { anchors.fill: parent; onClicked: overlay.controller.close() }
    Item { anchors.fill: parent; focus: overlay.visible; Keys.onEscapePressed: overlay.controller.close() }

    // Push the notification stack below this panel while open (#14).
    Binding {
        target: overlay.controller
        property: "rightPanelBottom"
        value: panel.y + panel.height
        when: overlay.visible && overlay.controller !== undefined && overlay.controller !== null
        restoreMode: Binding.RestoreNone
    }

    Rectangle {
        id: panel
        width: Config.controlcenter.width
        height: (overlay.page === "mixer" ? mixerPage.implicitHeight : col.implicitHeight)
                + Config.controlcenter.padding * 2
        Behavior on height { NumberAnimation { duration: Config.shape.animDuration } }
        clip: true   // content switches instantly; don't draw past the animating edge
        anchors.right: parent.right
        anchors.rightMargin: Config.shape.edgeGap
        y: Config.shape.edgeGap + Config.shape.barHeight + Config.shape.overlayMargin
        radius: Config.shape.overlayRadius
        color: Theme.surface

        MouseArea { anchors.fill: parent }   // swallow clicks on the panel

        Column {
            id: col
            visible: overlay.page === "main"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Config.controlcenter.padding
            spacing: Config.controlcenter.sectionSpacing

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                rowSpacing: Config.controlcenter.toggleGap
                columnSpacing: Config.controlcenter.toggleGap
                ToggleButton {
                    glyph: VolumeService.masterShownMuted ? "\u{F026}" : "\u{F028}"
                    label: "Sound"
                    active: !VolumeService.masterShownMuted
                    onClicked: VolumeService.toggleMasterMute()
                }
                ToggleButton {
                    glyph: AudioService.sourceMuted ? "" : ""
                    label: "Mic"
                    active: !AudioService.sourceMuted
                    onClicked: AudioService.toggleSourceMute()
                }
                ToggleButton {
                    glyph: ""
                    label: "Caffeine"
                    active: CaffeineService.active
                    onClicked: CaffeineService.toggle()
                }
                ToggleButton {
                    glyph: ""
                    label: "Wi-Fi"
                    active: NetworkService.wifiEnabled
                    onClicked: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
                }
                ToggleButton {
                    glyph: "\u{F293}"
                    label: BluetoothService.available ? "Bluetooth" : "No adapter"
                    active: BluetoothService.enabled
                    available: BluetoothService.available
                    onClicked: BluetoothService.setEnabled(!BluetoothService.enabled)
                }
                ToggleButton {
                    glyph: "\u{F001D}"
                    label: "Airplane"
                    active: AirplaneService.active
                    onClicked: AirplaneService.toggle()
                }
                ToggleButton {
                    glyph: "\u{F009B}"
                    label: "Do not disturb"
                    active: NotificationService.dnd
                    visible: NotificationService.dndAvailable
                    onClicked: NotificationService.toggleDnd()
                }
            }

            ControlSlider {
                width: parent.width
                glyph: ""
                value: BrightnessService.fraction
                onMoved: (v) => BrightnessService.setFraction(v)
            }
            ControlSlider {
                width: parent.width
                glyph: VolumeService.masterShownMuted ? "\u{F026}" : "\u{F028}"
                fillColor: VolumeService.masterShownMuted ? Theme.border : Theme.accent
                knobColor: VolumeService.masterShownMuted ? Theme.border : Theme.foreground
                value: VolumeService.masterLevel
                onMoved: (v) => VolumeService.setMasterLevel(v)
                showMore: true
                onMore: overlay.openPage("mixer")
            }
        }

        MixerPage {
            id: mixerPage
            visible: overlay.page === "mixer"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Config.controlcenter.padding
            onBack: overlay.back()
        }

        opacity: overlay.visible ? 1 : 0
        transform: Translate { y: overlay.visible ? 0 : -6 }
        Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }
    }
}
