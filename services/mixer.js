.pragma library

// Pure per-app mixer logic (#18). No Qt, no I/O — MixerService builds the
// records from PipeWire nodes; tests/tst_mixer.qml exercises this directly.
//
// Record: { id, mediaClass, binary, appName, iconName, mediaName,
//           description, nodeName, volume, muted } — missing strings are "".
// Group:  { key, name, subtitle, iconName, iconCandidates,
//           streams: [{ id, label, meaningful, volume, muted }], routable,
//           volume, muted } — routable: the key is stable enough to route.
//
// buildGroups() MUTATES the order state in place (assigns first-seen
// sequence numbers, prunes what disappeared). Callers keep one state object
// and never reassign it, so a binding over buildGroups can't loop on it.
// An app whose streams all vanish keeps its slot for REAPPEAR_GRACE_MS:
// players often tear a stream down before creating the next one (next
// track / next video), and that must not send the card to the bottom.

var REAPPEAR_GRACE_MS = 2000

function isPlayback(rec) { return rec.mediaClass === "Stream/Output/Audio" }

// Apps playing through PipeWire's ALSA compat plugin (e.g. browsers whose
// audio backend is ALSA) report application.name "PipeWire ALSA [<bin>]"
// and a generic media.name/description "ALSA Playback…". Unwrap the
// binary; treat those labels as no label at all.
function alsaBinary(rec) {
    var m = /^PipeWire ALSA \[(.+)\]$/.exec(rec.appName)
    return m ? m[1] : ""
}

// Blank labels count as generic too, so "   " never shows as a title.
function _generic(label) { return /^ALSA Playback/.test(label) || /^\s*$/.test(label) }

// "firefox-bin" → "Firefox": drop the packaging suffix, capitalise.
function _prettyBinary(b) {
    var n = b.replace(/-bin$/, "")
    return n.charAt(0).toUpperCase() + n.slice(1)
}

// Icon names to try, in order: the explicit icon-name, then names derived
// from the binary ("-bin" stripped) and the app name ("Google Chrome" →
// "google-chrome"). The UI takes the first that resolves, else a letter tile.
function iconCandidates(rec) {
    var bin = rec.binary || alsaBinary(rec)
    var app = alsaBinary(rec) ? "" : rec.appName.toLowerCase().replace(/\s+/g, "-")
    var out = []
    ;[rec.iconName, bin, bin.replace(/-bin$/, ""), app].forEach(function (c) {
        if (c && out.indexOf(c) < 0) out.push(c)
    })
    return out
}

// Which property produced the group key. Only stable sources (the binary,
// the ALSA-unwrapped binary, the app name) can carry a per-app route (#20);
// node names and stream ids change between runs.
function keySource(rec) {
    if (rec.binary) return "binary"
    if (alsaBinary(rec)) return "alsa"
    if (rec.appName) return "appName"
    if (rec.nodeName) return "nodeName"
    return "id"
}

function isRoutableSource(src) { return src === "binary" || src === "alsa" || src === "appName" }

function groupKey(rec) {
    switch (keySource(rec)) {
    case "binary": return rec.binary
    case "alsa": return alsaBinary(rec)
    case "appName": return rec.appName
    case "nodeName": return rec.nodeName
    default: return "stream-" + rec.id
    }
}

function displayName(rec) {
    var alsa = alsaBinary(rec)
    if (alsa) return _prettyBinary(alsa)
    return rec.appName || rec.binary || rec.description || rec.nodeName || "Unknown"
}

// Browsers get "N tabs playing" as a multi-stream subtitle (#72); keys are
// lower-cased with any packaging "-bin" suffix stripped before matching.
var BROWSERS = ["librewolf", "firefox", "chromium", "chrome", "google-chrome", "brave"]

function isBrowser(key) {
    return BROWSERS.indexOf(String(key).toLowerCase().replace(/-bin$/, "")) >= 0
}

// The label streamLabel would pick (media name, else description), or "" if
// it would fall back to "Stream N".
function _realLabel(rec) {
    if (rec.mediaName && !_generic(rec.mediaName)) return rec.mediaName
    if (rec.description && !_generic(rec.description)) return rec.description
    return ""
}

// A label worth showing as a subtitle: real, and not just the app's own
// name again (Spotify reports media.name "Spotify").
function isMeaningfulLabel(rec, appName) {
    var l = _realLabel(rec).trim().toLowerCase()
    return l !== "" && l !== String(appName || "").trim().toLowerCase()
}

function subtitleFor(key, streams) {
    if (streams.length === 1) return streams[0].meaningful ? streams[0].label : ""
    if (streams.length > 1) return streams.length + (isBrowser(key) ? " tabs playing" : " streams")
    return ""
}

// Fold-out: every routable group folds out (its Outputs section, #20).
// Otherwise per-stream rows only: cards fold out for 2+ streams (a single
// title is the subtitle); rows have no subtitle, so a single titled stream
// folds out too.
function showFoldout(group, layout) {
    if (group && group.routable) return true
    var n = group && group.streams ? group.streams.length : 0
    if (n > 1) return true
    return layout === "rows" && n === 1 && !!group.streams[0].meaningful
}

function streamLabel(rec, index) {
    return _realLabel(rec) || ("Stream " + (index + 1))
}

function newOrderState() { return { seq: 0, groups: {}, streams: {} } }

function clamp01(v) { return Math.max(0, Math.min(1, v)) }

function groupVolume(streams) {
    var m = 0
    for (var i = 0; i < streams.length; i++) m = Math.max(m, streams[i].volume)
    return m
}

function groupMuted(streams) {
    if (streams.length === 0) return false
    for (var i = 0; i < streams.length; i++) if (!streams[i].muted) return false
    return true
}

function _seqOf(map, k, state) {
    if (!(k in map)) map[k] = state.seq++
    return map[k]
}

// Group slots: { seq, present, absentSince }. A group present in the last
// build keeps its seq however long ago that build was; an absent one keeps
// it only while it's been gone <= REAPPEAR_GRACE_MS.
function _touchGroups(state, liveKeys, now) {
    var g = state.groups
    for (var k in g) {
        var e = g[k]
        if (k in liveKeys) {
            if (!e.present && now - e.absentSince > REAPPEAR_GRACE_MS) e.seq = state.seq++
            e.present = true
        } else if (e.present) {
            e.present = false
            e.absentSince = now
        } else if (now - e.absentSince > REAPPEAR_GRACE_MS) {
            delete g[k]
        }
    }
    for (var key in liveKeys)
        if (!(key in g)) g[key] = { seq: state.seq++, present: true, absentSince: 0 }
}

function _prune(map, live) {
    for (var k in map) if (!(k in live)) delete map[k]
}

function buildGroups(records, state, now) {
    if (now === undefined) now = Date.now()
    var byKey = {}, liveKeys = {}, liveIds = {}
    for (var i = 0; i < records.length; i++) {
        var r = records[i]
        if (!isPlayback(r)) continue
        var k = groupKey(r)
        liveKeys[k] = true
        liveIds[r.id] = true
        _seqOf(state.streams, r.id, state)
        if (!byKey[k]) byKey[k] = []
        byKey[k].push(r)
    }
    _touchGroups(state, liveKeys, now)
    _prune(state.streams, liveIds)

    var out = []
    for (var key in byKey) {
        var recs = byKey[key].slice().sort(function (a, b) {
            return state.streams[a.id] - state.streams[b.id]
        })
        var icon = ""
        for (var j = 0; j < recs.length && !icon; j++) icon = recs[j].iconName
        var cands = iconCandidates(recs[0])
        if (icon && cands.indexOf(icon) < 0) cands.unshift(icon)
        var name = displayName(recs[0])
        var streams = recs.map(function (s, idx) {
            return { id: s.id, label: streamLabel(s, idx), meaningful: isMeaningfulLabel(s, name),
                     volume: s.volume, muted: s.muted }
        })
        out.push({ key: key, name: name, subtitle: subtitleFor(key, streams), iconName: icon,
                   iconCandidates: cands, streams: streams,
                   routable: isRoutableSource(keySource(recs[0])),
                   volume: groupVolume(streams), muted: groupMuted(streams) })
    }
    out.sort(function (a, b) { return state.groups[a.key].seq - state.groups[b.key].seq })
    return out
}

function tileIndex(key, n) {
    var h = 0
    for (var i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) | 0
    return Math.abs(h) % n
}

function percent(v) { return Math.round(clamp01(v) * 100) + "%" }

// Minimal in-place edit list turning `cur` into `next` (arrays of unique
// keys), applied in order: removes (descending index), then per target
// position a move (key exists later) or an insert. Survivors are never
// removed, so ListModel rows — and the delegates holding a drag — live on.
function syncOps(cur, next) {
    var ops = [], a = cur.slice(), want = {}
    for (var i = 0; i < next.length; i++) want[next[i]] = true
    for (var r = a.length - 1; r >= 0; r--)
        if (!want[a[r]]) { ops.push({ op: "remove", index: r }); a.splice(r, 1) }
    for (var t = 0; t < next.length; t++) {
        if (a[t] === next[t]) continue
        var j = a.indexOf(next[t], t + 1)
        if (j >= 0) { ops.push({ op: "move", from: j, to: t }); a.splice(t, 0, a.splice(j, 1)[0]) }
        else { ops.push({ op: "insert", index: t, key: next[t] }); a.splice(t, 0, next[t]) }
    }
    return ops
}

// Apply syncOps to a ListModel whose rows are { <role>: key-string }.
function syncListModel(model, role, next) {
    var cur = []
    for (var i = 0; i < model.count; i++) cur.push(model.get(i)[role])
    syncOps(cur, next).forEach(function (o) {
        if (o.op === "remove") model.remove(o.index, 1)
        else if (o.op === "move") model.move(o.from, o.to, 1)
        else { var row = {}; row[role] = o.key; model.insert(o.index, row) }
    })
}
