.pragma library

// Pure volume layers (#22). No Qt, no I/O: VolumeService keeps the state,
// saves it to ~/.local/state/quill/volumes.json, feeds reconcile() what
// PipeWire reports and carries out the writes it returns.
// tests/tst_volumes.qml exercises it.
//
// What you hear is a product of independent layers; each slider shows only
// its own layer:
//   device volume = master.level × output.level, mute = master || output
//   stream volume = app.level × tab.level,       mute = app || tab
//
// State (saved):  { version, master: { level, muted },
//                   outputs: { <node.name>: { level, muted } },
//                   apps: { <groupKey>: { level } } }
// Session (not):  { appMuted: { key: bool }, tabs: { uid: { level, muted } },
//                   last: { outputs: { name: Last }, streams: { uid: Last } } }
//   Last = { volume, muted, target } — what the node should read after the
//   previous pass, and the volume quill aimed for.
// Devices: [{ name, volume, muted }] (present hardware outputs).
// Streams: [{ id, uid, key, volume, muted }] (uid = object.serial).
//
// Rules (spec "Behaviour"):
//  - an observed volume within ECHO of `last.volume` is quill's own echo;
//  - otherwise it changed from outside: map it back onto the layer
//    (observed ÷ the layer above, capped at 1; left alone when that is 0)
//    and don't rewrite the node in that pass;
//  - a volume is written only when quill's target moved since the last pass,
//    or when the node has no `last` (quill start, reconnect: quill's saved
//    level wins) — so an outside value is never fought;
//  - mute is always enforced (an outside unmute under master mute is undone);
//  - nothing is written that is within SAME of what the node reads.
// Every function returns new objects and never mutates its inputs.

var VERSION = 1
var ECHO = 0.01
var SAME = 1e-3

function _clamp01(v) { return Math.max(0, Math.min(1, v)) }
function _isNum(v) { return typeof v === "number" && isFinite(v) }
function _obj(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }
function _copy(v) { return JSON.parse(JSON.stringify(v)) }

function emptyState() {
    return { version: VERSION, master: { level: 1, muted: false }, outputs: {}, apps: {} }
}

function newSession() {
    return { appMuted: {}, tabs: {}, last: { outputs: {}, streams: {} } }
}

// Never throws: anything unreadable is an empty state; bad entries drop.
function parse(text) {
    var raw
    try { raw = JSON.parse(text) } catch (e) { return emptyState() }
    if (!_obj(raw) || raw.version !== VERSION) return emptyState()
    var s = emptyState()
    if (_obj(raw.master)) {
        if (_isNum(raw.master.level)) s.master.level = _clamp01(raw.master.level)
        s.master.muted = !!raw.master.muted
    }
    if (_obj(raw.outputs))
        for (var n in raw.outputs) {
            var o = raw.outputs[n]
            if (_obj(o) && _isNum(o.level)) s.outputs[n] = { level: _clamp01(o.level), muted: !!o.muted }
        }
    if (_obj(raw.apps))
        for (var k in raw.apps) {
            var a = raw.apps[k]
            if (_obj(a) && _isNum(a.level)) s.apps[k] = { level: _clamp01(a.level) }
        }
    return s
}

function serialize(state) { return JSON.stringify(state) }

// --- master and outputs

function setMaster(state, v) {
    var s = _copy(state)
    s.master.level = _clamp01(v)
    s.master.muted = false
    return s
}

// Shown muted (master or the default output) → unmute both; else mute the
// master.
function toggleMasterMute(state, defaultName) {
    var s = _copy(state)
    var out = defaultName ? s.outputs[defaultName] : undefined
    if (s.master.muted || (out && out.muted)) {
        s.master.muted = false
        if (out) out.muted = false
    } else {
        s.master.muted = true
    }
    return s
}

function setOutput(state, name, v) {
    var s = _copy(state)
    s.outputs[name] = { level: _clamp01(v), muted: false }
    return s
}

function toggleOutputMute(state, name) {
    var s = _copy(state)
    var o = s.outputs[name] || { level: 1, muted: false }
    s.outputs[name] = { level: o.level, muted: !o.muted }
    return s
}

function masterShownMuted(state, defaultName) {
    var o = defaultName ? state.outputs[defaultName] : undefined
    return state.master.muted || !!(o && o.muted)
}

function outputLevel(state, name) {
    var o = state.outputs[name]
    return o ? o.level : 1
}

function outputMuted(state, name) {
    var o = state.outputs[name]
    return !!(o && o.muted)
}

// One node with no outside change: decide what to write. Volume only when
// quill's target moved (or the node has no `last`); mute always.
// Returns { write: { volume, muted } | null, last }.
function _node(obs, last, target, targetMuted) {
    var volWrite = Math.abs(obs.volume - target) >= SAME && (!last || Math.abs(target - last.target) >= SAME)
    var muteWrite = obs.muted !== targetMuted
    var write = volWrite || muteWrite ? { volume: volWrite ? target : obs.volume, muted: targetMuted } : null
    return { write: write, last: { volume: volWrite ? target : obs.volume, muted: targetMuted, target: target } }
}

function _outside(obs, last) { return !!last && Math.abs(obs.volume - last.volume) >= ECHO }

function _outputs(st, se, devices) {
    var writes = [], lastOut = {}
    var master = st.master
    var devs = (devices || []).slice().sort(function (a, b) { return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0) })
    for (var i = 0; i < devs.length; i++) {
        var dv = devs[i]
        var o = st.outputs[dv.name]
        var last = se.last.outputs[dv.name]
        var outside = false
        if (!o) {
            o = { level: master.level > 0 ? _clamp01(dv.volume / master.level) : 1, muted: dv.muted }
            st.outputs[dv.name] = o
        } else if (last) {
            outside = _outside(dv, last)
            if (outside && master.level > 0) o.level = _clamp01(dv.volume / master.level)
            if (dv.muted !== last.muted) o.muted = dv.muted
        }
        var target = master.level * o.level
        var r = outside ? { write: dv.muted !== (master.muted || o.muted)
                                    ? { volume: dv.volume, muted: master.muted || o.muted } : null,
                            last: { volume: dv.volume, muted: master.muted || o.muted, target: target } }
                        : _node(dv, last, target, master.muted || o.muted)
        if (r.write) writes.push({ name: dv.name, volume: r.write.volume, muted: r.write.muted })
        lastOut[dv.name] = r.last
    }
    se.last.outputs = lastOut
    return writes
}

function reconcile(state, session, devices, streams) {
    var st = _copy(state), se = _copy(session)
    var outWrites = _outputs(st, se, devices)
    return { state: st, session: se, writes: { outputs: outWrites, streams: [] } }
}
