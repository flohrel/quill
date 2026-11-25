pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import "wired.js" as Wired

// Wired backend: physical ethernet devices from Quickshell.Networking
// (virtual interfaces filtered out by wired.js), aggregated into the hub's
// single Ethernet row and the bar's "any wired connected" flag.
Singleton {
    id: root

    readonly property var devices: {
        var ds = Networking.devices ? Networking.devices.values : []
        var wired = []
        for (var i = 0; i < ds.length; i++)
            if (ds[i].type === DeviceType.Wired) wired.push(ds[i])
        return Wired.physicalOnly(wired)
    }

    readonly property var linked: devices.filter(function (d) { return d.hasLink })

    function stateString(dev) {
        if (!dev) return "unknown"
        switch (dev.state) {
        case ConnectionState.Connecting:    return "connecting"
        case ConnectionState.Connected:     return "connected"
        case ConnectionState.Disconnecting: return "disconnecting"
        case ConnectionState.Disconnected:  return "disconnected"
        default:                            return "unknown"
        }
    }

    // Plain snapshots; reading hasLink/state/linkSpeed here makes the binding
    // track each device (few devices, rare changes — unlike the wifi scan list).
    readonly property var _snapshots: devices.map(function (d) {
        return { hasLink: d.hasLink, state: root.stateString(d), linkSpeed: d.linkSpeed }
    })
    readonly property var row: Wired.ethernetRow(_snapshots)
    readonly property bool anyConnected: Wired.anyConnected(_snapshots)

    function disconnect(dev) { if (dev) dev.disconnect() }
    function reconnect(dev) {
        if (!dev) return
        if (dev.network) dev.network.connect()
        else dev.autoconnect = true
    }
}
