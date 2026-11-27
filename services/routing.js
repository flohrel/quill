.pragma library
.import "audiodevices.js" as AD

// Pure per-app output routing (#20). No Qt, no I/O: MixerService keeps the
// table, writes it to ~/.local/state/quill/routes.json and runs the
// pw-metadata commands this file plans. tests/tst_routing.qml exercises it.
//
// Table:   { version: 1, routes: { <groupKey>: { device, label } } }
//          device = the sink's node.name; label = its label when picked
//          (shown while the device is away). No route = follow default.
// Devices: AudioService.outputs entries { name, label, glyph, isDefault,
//          available } (audiodevices.js buildList).
// Streams: [{ id, uid, key }], id = PipeWire node id (the pw-metadata
//          subject), uid = its object.serial (ids are reused, serials never
//          are), key = mixer group key. Ops carry both.
// PinState { pinned: { <uid>: device }, absent: { device: true } }: which
//          streams may carry a target (pinned by quill, or — after a quill
//          restart — possibly still pinned from before), and which routed
//          devices were unusable at the last plan (their return re-pins).
// Every function returns new objects and never mutates its inputs.

var VERSION = 1

function emptyTable() { return { version: VERSION, routes: {} } }

function _plainObject(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }

// Never throws: anything unreadable is an empty table; bad entries drop.
function parse(text) {
    var raw
    try { raw = JSON.parse(text) } catch (e) { return emptyTable() }
    if (!_plainObject(raw) || raw.version !== VERSION || !_plainObject(raw.routes)) return emptyTable()
    var t = emptyTable()
    for (var k in raw.routes) {
        var r = raw.routes[k]
        if (!_plainObject(r) || typeof r.device !== "string" || r.device === "") continue
        t.routes[k] = { device: r.device, label: typeof r.label === "string" && r.label !== "" ? r.label : r.device }
    }
    return t
}

function serialize(table) { return JSON.stringify(table) }

function routeFor(table, key) {
    var r = table && table.routes ? table.routes[key] : undefined
    return r ? { device: r.device, label: r.label } : null
}

function _copy(table) {
    var t = emptyTable()
    for (var k in table.routes) t.routes[k] = { device: table.routes[k].device, label: table.routes[k].label }
    return t
}

function setRoute(table, key, device, label) {
    var t = _copy(table)
    t.routes[key] = { device: device, label: label || device }
    return t
}

function clearRoute(table, key) {
    var t = _copy(table)
    delete t.routes[key]
    return t
}

function _find(devices, name) {
    for (var i = 0; i < (devices || []).length; i++) if (devices[i].name === name) return devices[i]
    return null
}

// Present and its port usable right now.
function usable(devices, name) {
    var d = _find(devices, name)
    return !!d && d.available !== false
}

function newPinState() { return { pinned: {}, absent: {} } }

// Which pw-metadata ops bring the streams in line with the table.
//  - no route: unpin anything that may carry a target;
//  - device missing: keep the target (WirePlumber plays the stream on the
//    default and moves it back on return), but remember it may be pinned so
//    a later clear still unpins — also right after a quill restart;
//  - device present but its port unavailable: unpin (WirePlumber would keep
//    the stream linked to the dead port), re-pin once it is usable;
//  - device usable: pin if not pinned there, or if it was unusable before.
function plan(streams, table, devices, st) {
    var ops = [], pinned = {}, absent = {}
    var prev = st || newPinState()
    for (var i = 0; i < streams.length; i++) {
        var s = streams[i]
        var r = routeFor(table, s.key)
        var want = r ? r.device : ""
        var have = prev.pinned[s.uid] || ""
        var d = want ? _find(devices, want) : null
        if (want === "") {
            if (have) ops.push({ op: "unpin", id: s.id, uid: s.uid })
        } else if (!d) {
            absent[want] = true
            if (have && have !== want) ops.push({ op: "unpin", id: s.id, uid: s.uid })
            else pinned[s.uid] = want
        } else if (d.available === false) {
            absent[want] = true
            if (have) ops.push({ op: "unpin", id: s.id, uid: s.uid })
        } else {
            if (have !== want || prev.absent[want]) ops.push({ op: "pin", id: s.id, uid: s.uid, device: want })
            pinned[s.uid] = want
        }
    }
    return { ops: ops, st: { pinned: pinned, absent: absent } }
}

function chip(route, devices) {
    if (!route) return { text: "→ Default", kind: "default" }
    if (usable(devices, route.device)) return { text: "→ " + _find(devices, route.device).label, kind: "pinned" }
    return { text: "→ " + route.label + " · unplugged", kind: "unplugged" }
}

// One row per known output; level -1 = no slider (unplugged).
function outputRows(route, devices, appVolume) {
    var pin = route ? route.device : ""
    var rows = (devices || []).map(function (d) {
        var state = d.available === false ? "unplugged" : (d.name === pin ? "pinned" : "off")
        return { name: d.name, label: d.label, glyph: d.glyph, state: state,
                 level: state === "pinned" ? appVolume : (state === "off" ? 0 : -1) }
    })
    if (pin && !_find(devices, pin))
        rows.push({ name: pin, label: route.label, glyph: AD.GLYPH_SPEAKER, state: "unplugged", level: -1 })
    return rows
}

function rowsSig(rows) { return rows.map(function (r) { return r.name }).join("\n") }
