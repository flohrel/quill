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
// quill's own writes stay "recent" this long: PipeWire can report an older
// drag value after a newer one (Quickshell updates its local value at once,
// the server's acknowledgement of an earlier write arrives later), and that
// stale value must count as an echo, not an outside change.
var RECENT_MS = 1000
// Streams already playing when quill starts (restart, hot reload) are
// adopted as they are; only streams created after this window start at
// tab 100%.
var STARTUP_GRACE_MS = 3000

function _clamp01(v) { return Math.max(0, Math.min(1, v)) }
function _isNum(v) { return typeof v === "number" && isFinite(v) }
function _obj(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }
function _copy(v) { return JSON.parse(JSON.stringify(v)) }

function emptyState() {
    return { version: VERSION, master: { level: 1, muted: false }, outputs: {}, apps: {} }
}

// startedAt (ms, optional): when quill started; enables the startup grace.
function newSession(startedAt) {
    return { appMuted: {}, tabs: {}, last: { outputs: {}, streams: {} }, recent: {},
             startedAt: startedAt === undefined ? null : startedAt }
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

// One node: decide what to write. Volume only when there was no outside
// change and quill's target moved (or the node has no `last`); mute always.
// A stale echo leaves `last.volume` at what quill expects.
// Returns { write: { volume, muted } | null, last }.
function _node(obs, last, seen, target, targetMuted) {
    var volWrite = !seen.outside && Math.abs(obs.volume - target) >= SAME
                   && (!last || Math.abs(target - last.target) >= SAME)
    var muteWrite = obs.muted !== targetMuted
    var write = volWrite || muteWrite ? { volume: volWrite ? target : obs.volume, muted: targetMuted } : null
    var lastVol = volWrite ? target : (seen.stale ? last.volume : obs.volume)
    return { write: write, last: { volume: lastVol, muted: targetMuted, target: target } }
}

// How an observation relates to quill's writes: an echo of the last one, a
// stale echo of a recent one, or an outside change (volume / mute).
function _seen(obs, last, recent) {
    var out = { outside: false, stale: false, muteOutside: false }
    if (!last) return out
    if (Math.abs(obs.volume - last.volume) >= ECHO) {
        if (recent.some(function (r) { return Math.abs(obs.volume - r.volume) < ECHO })) out.stale = true
        else out.outside = true
    }
    out.muteOutside = obs.muted !== last.muted && !recent.some(function (r) { return r.muted === obs.muted })
    return out
}

function _recent(se, key) { return se.recent[key] || [] }
function _remember(se, key, write, now) {
    (se.recent[key] = se.recent[key] || []).push({ volume: write.volume, muted: write.muted, at: now })
}
// Drop writes older than RECENT_MS and keys of nodes that are gone.
function _pruneRecent(se, now, live) {
    var out = {}
    for (var k in se.recent) {
        if (!live[k]) continue
        var kept = se.recent[k].filter(function (r) { return now - r.at <= RECENT_MS })
        if (kept.length) out[k] = kept
    }
    se.recent = out
}

function _outputs(st, se, devices, now) {
    var writes = [], lastOut = {}
    var master = st.master
    var devs = (devices || []).slice().sort(function (a, b) { return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0) })
    for (var i = 0; i < devs.length; i++) {
        var dv = devs[i]
        var o = st.outputs[dv.name]
        var last = se.last.outputs[dv.name]
        var seen = _seen(dv, last, _recent(se, "o:" + dv.name))
        if (!o) {
            o = { level: master.level > 0 ? _clamp01(dv.volume / master.level) : 1, muted: dv.muted }
            st.outputs[dv.name] = o
        } else if (last) {
            if (seen.outside && master.level > 0) o.level = _clamp01(dv.volume / master.level)
            if (seen.muteOutside) o.muted = dv.muted
        }
        var r = _node(dv, last, seen, master.level * o.level, master.muted || o.muted)
        if (r.write) {
            writes.push({ name: dv.name, volume: r.write.volume, muted: r.write.muted })
            _remember(se, "o:" + dv.name, r.write, now)
        }
        lastOut[dv.name] = r.last
    }
    se.last.outputs = lastOut
    return writes
}

// --- apps and tabs

function setApp(state, session, key, v) {
    var st = _copy(state), se = _copy(session)
    st.apps[key] = { level: _clamp01(v) }
    delete se.appMuted[key]
    return { state: st, session: se }
}

function toggleAppMute(session, key) {
    var se = _copy(session)
    se.appMuted[key] = !se.appMuted[key]
    return se
}

function setTab(session, uid, v) {
    var se = _copy(session)
    se.tabs[uid] = { level: _clamp01(v), muted: false }
    return se
}

function toggleTabMute(session, uid) {
    var se = _copy(session)
    var t = se.tabs[uid] || { level: 1, muted: false }
    se.tabs[uid] = { level: t.level, muted: !t.muted }
    return se
}

function appLevel(state, key) {
    var a = state.apps[key]
    return a ? a.level : 1
}

function appMuted(session, key) { return !!session.appMuted[key] }

function tabLevel(session, uid) {
    var t = session.tabs[uid]
    return t ? t.level : 1
}

function tabMuted(session, uid) {
    var t = session.tabs[uid]
    return !!(t && t.muted)
}

// First-seen app: its level is its loudest stream and each tab keeps its
// share, so the current mix doesn't change. A known app's new stream starts
// at tab 100% (it plays at the app level).
function _streams(st, se, streams, now) {
    var writes = [], lastS = {}, tabs = {}, byKey = {}
    var list = (streams || []).slice().sort(function (a, b) { return a.id - b.id })
    list.forEach(function (x) { (byKey[x.key] = byKey[x.key] || []).push(x) })
    for (var key in byKey) {
        if (st.apps[key]) continue
        var level = 0
        byKey[key].forEach(function (x) { level = Math.max(level, x.volume) })
        // An app first seen silent starts at 100% (like an output under a
        // master at 0), so it isn't saved — and later streams forced — at 0.
        if (!(level > 0)) level = 1
        st.apps[key] = { level: _clamp01(level) }
        byKey[key].forEach(function (x) {
            se.tabs[x.uid] = { level: level > 0 ? _clamp01(x.volume / level) : 1, muted: x.muted }
        })
    }
    for (var i = 0; i < list.length; i++) {
        var x = list[i]
        var app = st.apps[x.key]
        var tab = se.tabs[x.uid]
        var last = se.last.streams[x.uid]
        var single = byKey[x.key].length === 1
        var seen = _seen(x, last, _recent(se, "s:" + x.uid))
        if (!tab) {
            var adopting = se.startedAt !== null && now - se.startedAt <= STARTUP_GRACE_MS
            tab = adopting ? { level: app.level > 0 ? _clamp01(x.volume / app.level) : 1, muted: x.muted }
                           : { level: 1, muted: false }
        } else if (last) {
            if (seen.outside && single) { if (tab.level > 0) app.level = _clamp01(x.volume / tab.level) }
            else if (seen.outside && app.level > 0) tab.level = _clamp01(x.volume / app.level)
            if (seen.muteOutside) {
                if (single) se.appMuted[x.key] = x.muted
                else tab.muted = x.muted
            }
        }
        // One stream left: its tab has no row in the cards layout, so fold
        // the tab's level and mute into the app layer (audibly unchanged).
        if (single && (tab.level !== 1 || tab.muted)) {
            app.level = _clamp01(app.level * tab.level)
            if (tab.muted) se.appMuted[x.key] = true
            tab = { level: 1, muted: false }
        }
        tabs[x.uid] = tab
        var r = _node(x, last, seen, app.level * tab.level, !!se.appMuted[x.key] || tab.muted)
        if (r.write) {
            writes.push({ id: x.id, uid: x.uid, volume: r.write.volume, muted: r.write.muted })
            _remember(se, "s:" + x.uid, r.write, now)
        }
        lastS[x.uid] = r.last
    }
    se.tabs = tabs
    se.last.streams = lastS
    return writes
}

// now: ms timestamp of this pass (recent-write window, startup grace).
function reconcile(state, session, devices, streams, now) {
    if (now === undefined) now = 0
    var st = _copy(state), se = _copy(session)
    if (!se.recent) se.recent = {}
    if (se.startedAt === undefined) se.startedAt = null
    var live = {}
    ;(devices || []).forEach(function (x) { live["o:" + x.name] = true })
    ;(streams || []).forEach(function (x) { live["s:" + x.uid] = true })
    _pruneRecent(se, now, live)
    var outWrites = _outputs(st, se, devices, now)
    var streamWrites = _streams(st, se, streams, now)
    return { state: st, session: se, writes: { outputs: outWrites, streams: streamWrites } }
}
