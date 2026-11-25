.pragma library

// Pure parsers for read-only `nmcli -t … show` output + display-label helpers.
// No Qt, no I/O — unit-tested in tests/tst_nmcli.qml. Empty/missing → "".

function _terse(text) {
    // Split terse "key:value" lines into [key, value] pairs (first ':' only).
    var out = []
    if (!text) return out
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (!line) continue
        var idx = line.indexOf(":")
        if (idx < 0) continue
        out.push([line.substring(0, idx), line.substring(idx + 1).trim()])
    }
    return out
}

function parseDeviceShow(text) {
    var out = { ip: "", gateway: "", dns: "" }
    var rows = _terse(text)
    for (var i = 0; i < rows.length; i++) {
        var k = rows[i][0], v = rows[i][1]
        if (k.indexOf("IP4.ADDRESS") === 0 && !out.ip) out.ip = v.split("/")[0]
        else if (k === "IP4.GATEWAY" && v) out.gateway = v
        else if (k.indexOf("IP4.DNS") === 0 && !out.dns) out.dns = v
    }
    return out
}

function parseConnectionShow(text) {
    var out = { autoconnect: "", metered: "", ipv4Method: "", keyMgmt: "" }
    var rows = _terse(text)
    for (var i = 0; i < rows.length; i++) {
        var k = rows[i][0], v = rows[i][1]
        if (k === "connection.autoconnect") out.autoconnect = v
        else if (k === "connection.metered") out.metered = v
        else if (k === "ipv4.method") out.ipv4Method = v
        else if (k === "802-11-wireless-security.key-mgmt") out.keyMgmt = v
    }
    return out
}

function resolveProfile(text, ssid) {
    if (!text || !ssid) return ""
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (!line) continue
        var sep = line.lastIndexOf(":")            // -f NAME,TYPE → name may contain \:
        if (sep < 0) continue
        var name = line.substring(0, sep).replace(/\\:/g, ":")
        var type = line.substring(sep + 1)
        if (type === "802-11-wireless" && name === ssid) return name
    }
    return ""
}

function signalLabel(strength) {
    var s = strength
    if (s > 1) s = s / 100                          // normalize 0..100 → 0..1
    if (s <= 0) return ""
    if (s <= 0.25) return "Weak"
    if (s <= 0.5) return "Fair"
    if (s <= 0.75) return "Good"
    return "Excellent"
}

function autoconnectLabel(v) { return v === "yes" ? "On" : v === "no" ? "Off" : "" }
function meteredLabel(v) {
    return v === "yes" ? "On" : v === "no" ? "Off" : v === "unknown" ? "Auto" : ""
}
function ipv4MethodLabel(v) {
    return v === "auto" ? "DHCP" : v === "manual" ? "Manual" : (v ? v : "")
}
function keyMgmtLabel(v) {
    if (v === "sae") return "WPA3"
    if (v === "wpa-psk") return "WPA2"
    if (v === "wpa-eap") return "802.1X"
    if (v === "none") return "WEP"
    if (v === "") return ""
    return v
}
