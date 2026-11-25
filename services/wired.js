.pragma library

// Pure helpers for the wired (ethernet) side of the network hub. Plain JS
// objects and lowercase state strings only (no Quickshell enums), so
// tests/tst_wired.qml runs without Quickshell.

var _virtualPrefixes = ["virbr", "docker", "br-", "veth", "vnet", "tun", "tap", "wg", "tailscale"]

// Bridges, veth, tunnels, libvirt/docker interfaces never count as ethernet.
function isVirtualIface(name) {
    if (!name) return false
    if (name === "lo") return true
    for (var i = 0; i < _virtualPrefixes.length; i++)
        if (name.indexOf(_virtualPrefixes[i]) === 0) return true
    return false
}

function physicalOnly(devs) {
    var out = []
    for (var i = 0; i < devs.length; i++)
        if (!isVirtualIface(devs[i].name)) out.push(devs[i])
    return out
}

// Link speed in Mb/s → "100 Mb/s" / "1 Gb/s" / "2.5 Gb/s"; "" when unknown.
function speedLabel(mbps) {
    if (!(mbps > 0)) return ""
    if (mbps < 1000) return mbps + " Mb/s"
    return (Math.round(mbps / 100) / 10) + " Gb/s"
}

// Aggregated Ethernet hub row over physical wired devices.
// devs: [{hasLink, state, linkSpeed}], state ∈ connected|connecting|
// disconnecting|disconnected|unknown.
function ethernetRow(devs) {
    if (!devs || devs.length === 0) return { visible: false, enabled: false, state: "" }
    var linked = devs.filter(function (d) { return d.hasLink })
    if (linked.length === 0) return { visible: true, enabled: false, state: "Disconnected" }
    var connected = linked.filter(function (d) { return d.state === "connected" })
    var state
    if (connected.length > 1) {
        state = "Connected · " + connected.length + " devices"
    } else if (connected.length === 1) {
        var speed = speedLabel(connected[0].linkSpeed)
        state = speed ? "Connected · " + speed : "Connected"
    } else if (linked.some(function (d) { return d.state === "connecting" })) {
        state = "Connecting…"
    } else {
        state = "Disconnected"
    }
    return { visible: true, enabled: true, state: state }
}

// Bar flag: is any physical wired device actually carrying an active
// connection? Requires the carrier (hasLink) as well as state "connected":
// NetworkManager keeps a device "connected" for a grace period after the
// cable is pulled, so trusting state alone leaves the pill showing ethernet
// for several seconds. Matches ethernetRow, which also checks hasLink first.
function anyConnected(devs) {
    if (!devs) return false
    return devs.some(function (d) { return d.hasLink && d.state === "connected" })
}

// Ethernet submenu switch position. "connecting" counts as on, so a click
// during a slow activation disconnects (cancels) instead of re-activating.
function switchOn(state) {
    return state === "connected" || state === "connecting"
}
