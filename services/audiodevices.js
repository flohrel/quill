.pragma library

// Pure audio-device logic (#5). No Qt, no I/O — AudioService builds the
// records from PipeWire nodes; tests/tst_audiodevices.qml exercises this
// directly.
//
// Record: { id, name, description, nick, mediaClass, deviceId, bus, iconName,
//           profileName, profileDescription } — strings ("" when missing)
//           except id. They map to node.name, node.description, node.nick,
//           media.class, device.id, device.bus, device.icon_name,
//           device.profile.name, device.profile.description.
// List entry: { name, label, glyph, isDefault, available }

// Only hardware-backed nodes are devices: a sink/source without device.id is
// virtual (null sink, loopback), and quill's own helpers never count.
function _hardware(rec) {
    return rec.deviceId !== "" && rec.name.indexOf("quill.mix.") !== 0
}
function isOutput(rec) { return rec.mediaClass === "Audio/Sink" && _hardware(rec) }
function isInput(rec) { return rec.mediaClass === "Audio/Source" && _hardware(rec) }

function _blank(s) { return !s || /^\s*$/.test(s) }

function label(rec) {
    if (!_blank(rec.description)) return rec.description
    if (!_blank(rec.nick)) return rec.nick
    return rec.name
}

// Profile descriptions that only name a channel layout ("Analog Stereo"):
// too generic to stand in for the device name.
var GENERIC_PROFILE = /^((analog|digital) )?(stereo|mono|surround\b.*)$|^pro\b|^multichannel\b/i

// Compact label for chips and rows. Built-in cards describe every port as
// "<controller> <port>", which elides to the same prefix; when the
// description ends with a specific port name, show just that port.
function shortLabel(rec) {
    var pd = rec.profileDescription
    var d = rec.description
    if (!_blank(pd) && !GENERIC_PROFILE.test(pd) && !_blank(d)
            && d.length > pd.length && d.slice(-pd.length) === pd)
        return pd
    return label(rec)
}

var GLYPH_MIC = "\u{F036C}"
var GLYPH_HEADPHONES = "\u{F02CB}"
var GLYPH_BT_SPEAKER = "\u{F09A2}"
var GLYPH_MONITOR = "\u{F0379}"
var GLYPH_LAPTOP = "\u{F0322}"
var GLYPH_SPEAKER = "\u{F04C3}"

function glyph(rec) {
    if (rec.mediaClass === "Audio/Source") return GLYPH_MIC
    var icon = rec.iconName.toLowerCase()
    var profile = rec.profileName.toLowerCase()
    if (/headphone|headset/.test(icon) || /headphone|headset/.test(profile)) return GLYPH_HEADPHONES
    if (rec.bus === "bluetooth" || rec.name.indexOf("bluez_") === 0) return GLYPH_BT_SPEAKER
    if (profile.indexOf("hdmi") >= 0) return GLYPH_MONITOR
    if (rec.bus === "pci" && rec.profileDescription === "Speaker") return GLYPH_LAPTOP
    return GLYPH_SPEAKER
}

// Devices of one kind ("output" | "input"), sorted by label
// (case-insensitive), then name; isDefault marks defaultName's entry.
// `unavailable` ({ nodeName: true }, optional) marks ports that can't be
// used right now (available: false).
function buildList(records, kind, defaultName, unavailable) {
    var keep = kind === "input" ? isInput : isOutput
    var off = unavailable || {}
    return records.filter(keep).map(function (r) {
        return { name: r.name, label: shortLabel(r), glyph: glyph(r),
                 isDefault: r.name === defaultName, available: !off[r.name] }
    }).sort(function (a, b) {
        var la = a.label.toLowerCase(), lb = b.label.toLowerCase()
        if (la !== lb) return la < lb ? -1 : 1
        return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)
    })
}

function chipLabel(defaultRec, kind) {
    if (!defaultRec) return kind === "input" ? "No input" : "No output"
    return shortLabel(defaultRec)
}

function listSig(list) {
    return list.map(function (d) { return d.name }).join("\n")
}

// Port availability, from a parsed `pw-dump` array. Quickshell doesn't expose
// device routes, so AudioService runs pw-dump. A node is unavailable when the
// active route of its card profile device (node prop card.profile.device on
// device device.id) reports available "no" — e.g. a jack mic with nothing
// plugged in. Returns { nodeName: true }.
function unavailableNames(objects) {
    var routes = {}   // "<deviceId>:<profileDevice>" -> available
    var out = {}
    if (!Array.isArray(objects)) return out
    objects.forEach(function (o) {
        if (!o || !o.info || String(o.type).indexOf("Interface:Device") < 0) return
        var rs = (o.info.params && o.info.params.Route) || []
        rs.forEach(function (r) { if (r) routes[o.id + ":" + r.device] = r.available })
    })
    objects.forEach(function (o) {
        if (!o || !o.info || String(o.type).indexOf("Interface:Node") < 0) return
        var p = o.info.props || {}
        if (p["device.id"] === undefined || p["card.profile.device"] === undefined) return
        if (routes[p["device.id"] + ":" + p["card.profile.device"]] === "no") out[p["node.name"]] = true
    })
    return out
}

function unavailableFromText(text) {
    try { return unavailableNames(JSON.parse(text)) } catch (e) { return {} }
}
