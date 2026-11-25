pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import "network.js" as Net

// Wifi backend: wraps Quickshell.Networking (native NetworkManager binding).
// Resolves the WifiDevice from Networking.devices and exposes a sorted network
// list + radio + scan + per-network actions for the control-center wifi panel.
Singleton {
    id: root

    readonly property var wifiDevice: {
        var ds = Networking.devices ? Networking.devices.values : []
        for (var i = 0; i < ds.length; i++)
            if (ds[i].type === DeviceType.Wifi) return ds[i]
        return null
    }

    // NM re-notifies the stale WirelessEnabled value mid-toggle (false→true
    // bounce ~280ms after enable), so the UI binds to the latched value, not
    // Networking.wifiEnabled directly. See RadioLatch.
    readonly property bool wifiEnabled: wifiLatch.value
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    RadioLatch { id: wifiLatch; backendValue: Networking.wifiEnabled }

    // Sorted snapshot of nearby networks (live WifiNetwork objects).
    // Rebuilt imperatively ONLY when the device's network *membership* changes
    // (networks.valuesChanged), NOT as a binding over each network's live
    // signalStrength. A signalStrength-dependent binding re-evaluates ~2x/sec
    // while scanning, handing the ListView a fresh array each tick → it destroys
    // and recreates every delegate, wiping the inline password field + its typed
    // text + focus mid-entry. Membership changes are rare, so delegates persist.
    property var networks: []

    // While a password field is focused we must NOT hand the ListView a new
    // array: that recreates every delegate and wipes the half-typed password.
    // A focused row sets holdList; the latest list is stashed and applied once
    // focus leaves. Exactly one TextField holds focus at a time, so no races.
    property bool holdList: false
    property var pendingNetworks: null
    function setHold(on) {
        holdList = on
        if (!on && pendingNetworks !== null) {
            networks = pendingNetworks
            pendingNetworks = null
        }
    }
    function rebuildNetworks() {
        var ns = (wifiDevice && wifiDevice.networks) ? wifiDevice.networks.values : []
        var next = Net.sortNetworks(ns)
        if (Net.sameNetworkSet(next, networks)) return   // same SSID set → keep array, preserve delegates
        if (holdList) { pendingNetworks = next; return }  // typing in progress → defer the swap
        networks = next
    }
    onWifiDeviceChanged: rebuildNetworks()
    Component.onCompleted: rebuildNetworks()
    Connections {
        target: root.wifiDevice ? root.wifiDevice.networks : null
        function onValuesChanged() { root.rebuildNetworks() }
    }
    readonly property var activeNetwork: {
        var ns = networks
        for (var i = 0; i < ns.length; i++) if (ns[i].connected) return ns[i]
        return null
    }
    readonly property bool connected: activeNetwork !== null
    readonly property string activeSsid: activeNetwork ? activeNetwork.name : ""

    function setWifiEnabled(on) {
        wifiLatch.request(on)
        Networking.wifiEnabled = on
    }
    function startScan() { if (wifiDevice) wifiDevice.scannerEnabled = true }
    function stopScan() { if (wifiDevice) wifiDevice.scannerEnabled = false }
    function connect(net) {
        if (!net) return
        var cur = activeNetwork
        if (cur && cur !== net) cur.disconnect()   // free the radio before switching
        net.connect()
    }
    function disconnect(net) { if (net) net.disconnect() }
    function connectWithPsk(net, psk) {
        if (!net) return
        var cur = activeNetwork
        if (cur && cur !== net) cur.disconnect()   // free the radio before switching (same as connect)
        net.connectWithPsk(psk)
    }
    function forget(net) { if (net) net.forget() }
}
