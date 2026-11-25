.pragma library

// Nerd Font glyph for a BlueZ device `icon` name (e.g. "audio-headset").
// All glyphs use the \u{...} code-point escape (works for BMP and
// supplementary-plane chars alike) instead of literal PUA chars, since the
// editing tools used to author this file are unreliable with literal PUA.
function deviceIconGlyph(bluezIcon) {
    switch (bluezIcon) {
    case "audio-headset":
    case "audio-headphones":
        return "\u{F025}"             // nf-fa-headphones
    case "input-mouse":
        return "\u{F037D}"            // nf-md-mouse
    case "input-keyboard":
        return "\u{F030C}"            // nf-md-keyboard
    case "input-gaming":
        return "\u{F11B}"             // nf-fa-gamepad
    case "phone":
        return "\u{F095}"             // nf-fa-phone
    case "audio-card":
    case "audio-speakers":
        return "\u{F028}"             // nf-fa-volume_up
    case "computer":
        return "\u{F109}"             // nf-fa-laptop
    default:
        return "\u{F293}"             // nf-fa-bluetooth
    }
}

// Status caption for a device row. BluetoothDeviceState.Connecting === 3
// (Disconnected=0, Connected=1, Disconnecting=2, Connecting=3) — the pure
// helper has no QML import, so the numeric value is used directly; it's the
// same value the live device.state property holds.
// `pairingAddress` (optional): address of a device being paired externally
// via bluetoothctl (see BluetoothService.pair) — device.pairing only tracks
// the native pair() call, so out-of-process pairing is matched by address.
function statusLabel(device, pairingAddress) {
    if (!device) return ""
    if (device.pairing) return "pairing…"
    if (pairingAddress && device.address === pairingAddress) return "pairing…"
    if (device.state === 3) return "connecting…"
    if (device.connected) return "connected"
    if (device.paired) return "paired"
    return ""
}

// "80%" when the device reports battery, else "". Tolerates both a 0..1
// fraction and a 0..100 percentage from the binding.
function batteryLabel(device) {
    if (!device || !device.batteryAvailable) return ""
    var b = device.battery
    var pct = b <= 1 ? b * 100 : b
    return Math.round(pct) + "%"
}

// Split a flat device list into paired (paired || bonded) and available.
function partitionDevices(devices) {
    var paired = []
    var available = []
    for (var i = 0; i < devices.length; i++) {
        var d = devices[i]
        if (d.paired || d.bonded) paired.push(d)
        else available.push(d)
    }
    return { paired: paired, available: available }
}

// Connected first, then by name (case-insensitive).
function sortDevices(list) {
    var out = list.slice()
    out.sort(function (a, b) {
        if (a.connected !== b.connected) return a.connected ? -1 : 1
        var an = (a.name || "").toLowerCase()
        var bn = (b.name || "").toLowerCase()
        if (an < bn) return -1
        if (an > bn) return 1
        return 0
    })
    return out
}

// True when two device lists hold the same set of addresses (order ignored).
// The churn guard: lets the service keep its existing array across discovery
// ticks that only update RSSI/properties, so the view never recreates
// delegates (which would collapse an open expand strip).
function sameDeviceSet(a, b) {
    if (a.length !== b.length) return false
    var seen = {}
    for (var i = 0; i < a.length; i++) seen[a[i].address] = true
    for (var j = 0; j < b.length; j++) if (!seen[b[j].address]) return false
    return true
}
