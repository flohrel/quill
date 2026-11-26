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
// List entry: { name, label, glyph, isDefault }

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
function buildList(records, kind, defaultName) {
    var keep = kind === "input" ? isInput : isOutput
    return records.filter(keep).map(function (r) {
        return { name: r.name, label: label(r), glyph: glyph(r), isDefault: r.name === defaultName }
    }).sort(function (a, b) {
        var la = a.label.toLowerCase(), lb = b.label.toLowerCase()
        if (la !== lb) return la < lb ? -1 : 1
        return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)
    })
}

function chipLabel(defaultRec, kind) {
    if (!defaultRec) return kind === "input" ? "No input" : "No output"
    return label(defaultRec)
}

function listSig(list) {
    return list.map(function (d) { return d.name }).join("\n")
}
