.pragma library

// Normalize a 0..1 (or 0..100) signal strength to a 0..4 bar level.
function signalLevel(strength) {
    var s = strength > 1 ? strength / 100 : strength
    if (s <= 0) return 0
    if (s < 0.25) return 1
    if (s < 0.5) return 2
    if (s < 0.75) return 3
    return 4
}

// Dedupe by SSID (keep strongest), then order: connected, known, signal desc.
function sortNetworks(list) {
    var byName = {}
    for (var i = 0; i < list.length; i++) {
        var n = list[i]
        var prev = byName[n.name]
        // Dedupe same-SSID APs (multi-BSSID). Keep the connected one if any,
        // else the strongest — never let a stronger sibling hide the AP we're
        // actually on, which would null out activeNetwork.
        if (!prev || n.connected
                  || (!prev.connected && n.signalStrength > prev.signalStrength))
            byName[n.name] = n
    }
    var out = []
    for (var k in byName) out.push(byName[k])
    out.sort(function (a, b) {
        if (a.connected !== b.connected) return a.connected ? -1 : 1
        if (a.known !== b.known) return a.known ? -1 : 1
        return b.signalStrength - a.signalStrength
    })
    return out
}

// True when two network lists hold the same set of SSIDs (order ignored).
// Lets the service keep its existing array across scan ticks that only update
// signal strengths, so the ListView never recreates delegates (which would
// wipe an in-progress inline password field).
function sameNetworkSet(a, b) {
    if (a.length !== b.length) return false
    var seen = {}
    for (var i = 0; i < a.length; i++) seen[a[i].name] = true
    for (var j = 0; j < b.length; j++) if (!seen[b[j].name]) return false
    return true
}

// Pill-icon state for the right-bar wifi glyph.
// "hidden" when radio off; "searching" when on but not connected;
// "l1".."l4" by signal level when connected (connected => at least l1).
function wifiIconState(enabled, connected, strength) {
    if (!enabled) return "hidden"
    if (!connected) return "searching"
    var lvl = signalLevel(strength)
    if (lvl < 1) lvl = 1
    return "l" + lvl
}

// Bar network group: one entry per active connection, never empty.
// Ethernet when any physical wired device is connected; wifi whenever the
// radio is on (its glyph shows signal or disconnected); "offline" otherwise.
// Airplane mode (#11) leads the group and replaces the offline fallback.
function networkGroup(wiredConnected, wifiEnabled, vpnConnected, airplane) {
    var out = []
    if (airplane) out.push("airplane")
    if (wiredConnected) out.push("ethernet")
    if (wifiEnabled) out.push("wifi")
    if (out.length === 0) out.push("offline")
    if (vpnConnected) out.push("vpn")      // NM state, truthful even with no link (#9)
    return out
}

// What a click on a wifi NetworkRow does. A second click while the password
// field is open collapses it instead of re-asking.
function rowAction(askPsk, connected, known, secured) {
    if (askPsk) return "collapse"
    if (connected) return "disconnect"
    if (known || !secured) return "connect"
    return "ask"
}
