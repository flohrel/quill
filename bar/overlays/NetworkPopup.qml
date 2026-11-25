import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../notifications"

// Network hub popup. Summoned by the ControlsPill network group. A plain menu
// of connection types (level 0); each row slides to its submenu (level 1:
// Wi-Fi or Ethernet); the Wi-Fi gear slides to a per-network detail (level 2).
// Exclusive keyboard focus so the NetworkRow password field can be typed
// (the OnDemand inline-panel approach lost focus). Esc / click-outside dismiss.
PanelWindow {
    id: popup
    property var controller
    property var barScreen
    screen: barScreen

    // navigation state: page = "hub" | "wifi" | "ethernet" | "vpn"; detailNet → level 2
    property string page: "hub"
    property var detailNet: null
    readonly property int level: detailNet ? 2 : (page === "hub" ? 0 : 1)
    function openPage(name) { page = name }
    function openDetail(net) { detailNet = net; WifiDetails.load(net) }
    function closeDetail() { detailNet = null; WifiDetails.clear() }
    function back() { if (detailNet) closeDetail(); else page = "hub" }
    function resetPages() { closeDetail(); page = "hub" }

    // Cable pulled while the Ethernet submenu is open → back to the hub
    // (the row there is now greyed), never a stale page with a dead switch.
    Connections {
        target: WiredService
        function onLinkedChanged() {
            if (popup.page === "ethernet" && WiredService.linked.length === 0) popup.back()
        }
    }

    visible: controller && controller.active === "network"
    onVisibleChanged: {
        if (visible) {
            NetworkService.startScan()
        } else {
            NetworkService.stopScan()
            NetworkService.setHold(false)
            popup.resetPages()               // always reopen on the hub
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
        width: Config.wifi.popupWidth
        height: (popup.level === 2 ? detailPage.implicitHeight
                 : popup.level === 1 ? (popup.page === "ethernet" ? ethernetPage.implicitHeight
                                        : popup.page === "vpn" ? vpnPage.implicitHeight
                                                               : listCol.implicitHeight)
                 : hubCol.implicitHeight)
                + Config.wifi.padding * 2
        anchors.right: parent.right
        anchors.rightMargin: Config.shape.edgeGap
        y: Config.shape.edgeGap + Config.shape.barHeight + Config.shape.overlayMargin
        radius: Config.shape.overlayRadius
        color: Theme.surface
        clip: true

        Behavior on height { NumberAnimation { duration: Config.wifi.detailAnimDuration } }

        MouseArea { anchors.fill: parent }   // swallow clicks on the panel

        Item {
            id: pager
            width: parent.width * 3
            height: parent.height
            x: -popup.level * Config.wifi.popupWidth
            Behavior on x { NumberAnimation { duration: Config.wifi.detailAnimDuration; easing.type: Easing.OutCubic } }

            // ---- level 0: the hub ----
            Column {
                id: hubCol
                width: Config.wifi.popupWidth - Config.wifi.padding * 2
                anchors { top: parent.top; left: parent.left; margins: Config.wifi.padding }
                spacing: 2

                Text {
                    height: 24; verticalAlignment: Text.AlignVCenter
                    text: "Network"; color: Theme.foreground; font.pixelSize: 15
                }
                HubRow {
                    id: ethernetRow
                    width: parent.width
                    visible: WiredService.row.visible
                    enabled: WiredService.row.enabled
                    status: WiredService.row.state
                    glyph: "\u{F0C9D}"
                    name: "Ethernet"
                    onClicked: popup.openPage("ethernet")
                }
                HubRow {
                    width: parent.width
                    glyph: "\u{F0928}"
                    name: "Wi-Fi"
                    status: NetworkService.connected ? NetworkService.activeSsid
                          : NetworkService.wifiEnabled ? "Not connected" : "Off"
                    onClicked: popup.openPage("wifi")
                }
                HubRow {
                    width: parent.width
                    glyph: "\u{F0582}"
                    name: "VPN"
                    enabled: VpnService.hasProfiles
                    status: VpnService.hubStatus
                    onClicked: popup.openPage("vpn")
                }
            }

            // ---- level 1: Wi-Fi submenu ----
            Column {
                id: listCol
                visible: popup.page === "wifi"
                width: Config.wifi.popupWidth - Config.wifi.padding * 2
                anchors { top: parent.top; left: parent.left; topMargin: Config.wifi.padding
                          leftMargin: Config.wifi.popupWidth + Config.wifi.padding }
                spacing: Config.wifi.sectionGap

                BackHeader { onBack: popup.back() }

                // header: title + radio switch (stays open; the latch keeps the switch steady)
                Item {
                    width: parent.width; height: 24
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "Wi-Fi"; color: Theme.foreground; font.pixelSize: 15
                    }
                    ToggleSwitch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: NetworkService.wifiEnabled
                        onToggled: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
                    }
                }

                Text {
                    text: "CONNECTED"; font.pixelSize: 10; color: Theme.foregroundDim
                    font.capitalization: Font.AllUppercase
                    visible: NetworkService.activeNetwork !== null
                }
                NetworkRow {
                    width: parent.width
                    visible: NetworkService.activeNetwork !== null
                    net: NetworkService.activeNetwork
                    onConfigRequested: popup.openDetail(net)
                }

                Rectangle {
                    width: parent.width; height: 1; color: Theme.surfaceAlt
                    visible: NetworkService.activeNetwork !== null
                }

                Text {
                    text: "AVAILABLE NETWORKS"; font.pixelSize: 10; color: Theme.foregroundDim
                    font.capitalization: Font.AllUppercase
                }
                ListView {
                    width: parent.width
                    height: Math.min(contentHeight, Config.wifi.listHeight)
                    clip: true
                    spacing: 2
                    model: NetworkService.networks
                    delegate: NetworkRow {
                        width: ListView.view.width
                        net: modelData
                        visible: !modelData.connected
                        height: visible ? implicitHeight : 0
                        onConfigRequested: popup.openDetail(net)
                    }
                }

                Text {   // footer hint
                    width: parent.width
                    text: "tap row = connect/disconnect · gear = config"
                    color: Theme.foregroundDim; font.pixelSize: 9
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // ---- level 1: Ethernet submenu ----
            EthernetPage {
                id: ethernetPage
                visible: popup.page === "ethernet"
                popup: popup
                width: Config.wifi.popupWidth - Config.wifi.padding * 2
                anchors { top: parent.top; left: parent.left; topMargin: Config.wifi.padding
                          leftMargin: Config.wifi.popupWidth + Config.wifi.padding }
            }

            // ---- level 1: VPN submenu ----
            VpnPage {
                id: vpnPage
                visible: popup.page === "vpn"
                popup: popup
                width: Config.wifi.popupWidth - Config.wifi.padding * 2
                anchors { top: parent.top; left: parent.left; topMargin: Config.wifi.padding
                          leftMargin: Config.wifi.popupWidth + Config.wifi.padding }
            }

            // ---- level 2: Wi-Fi network detail ----
            WifiDetail {
                id: detailPage
                width: Config.wifi.popupWidth - Config.wifi.padding * 2
                anchors { top: parent.top; left: parent.left; leftMargin: Config.wifi.popupWidth * 2 + Config.wifi.padding; topMargin: Config.wifi.padding }
                popup: popup
                net: popup.detailNet
            }
        }

        opacity: popup.visible ? 1 : 0
        transform: Translate { y: popup.visible ? 0 : -6 }
        Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }
    }
}
