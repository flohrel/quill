.pragma library

// Pure VPN logic: nmcli terse parsing, backend group merging, hub/row labels
// and the one-at-a-time switch planner. No Qt, no I/O — unit-tested in
// tests/tst_vpn.qml. Spec: docs/superpowers/specs/quill-vpn-design.md.
// Never feed this nmcli output produced with --show-secrets.

var VPN_TYPES = { "vpn": true, "wireguard": true }

// nmcli -t NM state → quill profile state. Unlisted values are dropped.
var NM_STATES = { "activating": "connecting", "activated": "connected", "deactivating": "disconnecting" }

// Split one nmcli terse line on unescaped ':'; unescape '\:' and '\\'.
function splitTerse(line) {
    var out = [], cur = ""
    if (!line) return out
    for (var i = 0; i < line.length; i++) {
        var c = line[i]
        if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
        if (c === ":") { out.push(cur); cur = ""; continue }
        cur += c
    }
    out.push(cur)
    return out
}

function _lines(text) { return text ? String(text).split("\n") : [] }

// `nmcli -t -f NAME,UUID,TYPE connection show` → VPN-type profiles only.
function parseProfiles(text) {
    var out = []
    var lines = _lines(text)
    for (var i = 0; i < lines.length; i++) {
        var f = splitTerse(lines[i])
        if (f.length !== 3 || !f[1] || !VPN_TYPES[f[2]]) continue
        out.push({ id: f[1], name: f[0], type: f[2] })
    }
    // nmcli lists active profiles first; sort so rows never jump on connect.
    out.sort(function (a, b) { return a.name.localeCompare(b.name) || a.id.localeCompare(b.id) })
    return out
}

// `nmcli -t -f UUID,STATE connection show --active` → { uuid: state }.
function parseActive(text) {
    var out = {}
    var lines = _lines(text)
    for (var i = 0; i < lines.length; i++) {
        var f = splitTerse(lines[i])
        if (f.length !== 2 || !f[0]) continue
        var st = NM_STATES[f[1]]
        if (st) out[f[0]] = st
    }
    return out
}

// Profiles + live active map + failed set + in-flight overlay → [{ id, name, state }].
// Precedence: a down quill just issued ("disconnecting") > NM's live state >
// a connect quill just issued ("connecting") > failed > off. So a second quick
// toggle sees a profile busy before NM reports it, and the old switch drops
// the moment it's switched away from instead of after NM catches up.
function mergeState(profiles, activeMap, failedMap, inflightMap) {
    var active = activeMap || {}, failed = failedMap || {}, inflight = inflightMap || {}
    return (profiles || []).map(function (p) {
        var st = inflight[p.id] === "disconnecting" ? "disconnecting"
               : active[p.id] || inflight[p.id] || (failed[p.id] ? "failed" : "off")
        return { id: p.id, name: p.name, state: st }
    })
}

// ---- groups, claims, labels ----

// [{ backendId, displayName, profiles, claimedIds }] → [{ backendId, displayName, profiles }].
// A profile is hidden from group g when ANOTHER backend claims its id.
function mergeGroups(backends) {
    var bs = (backends || []).filter(function (b) { return !!b })
    return bs.map(function (b, i) {
        var claimedElsewhere = {}
        bs.forEach(function (o, j) {
            if (j !== i) (o.claimedIds || []).forEach(function (id) { claimedElsewhere[id] = true })
        })
        return {
            backendId: b.backendId,
            displayName: b.displayName,
            profiles: (b.profiles || []).filter(function (p) { return !claimedElsewhere[p.id] })
        }
    })
}

function allProfiles(groups) {
    var out = []
    ;(groups || []).forEach(function (g) {
        (g.profiles || []).forEach(function (p) {
            out.push({ backendId: g.backendId, id: p.id, name: p.name, state: p.state })
        })
    })
    return out
}

function hasProfiles(groups) { return allProfiles(groups).length > 0 }

function activeList(groups) {
    return allProfiles(groups)
        .filter(function (p) { return p.state === "connected" })
        .map(function (p) { return { backendId: p.backendId, id: p.id, name: p.name } })
}

function hubStatus(groups, pending) {
    var all = allProfiles(groups)
    if (all.length === 0) return "No profiles"
    var up = activeList(groups)
    if (up.length > 0)
        return "Connected · " + up[0].name + (up.length > 1 ? " +" + (up.length - 1) : "")
    if (pending || all.some(function (p) { return p.state === "connecting" })) return "Connecting…"
    return "Off"
}

var SUBLINES = { "connected": "Connected", "connecting": "Connecting…",
                 "disconnecting": "Disconnecting…", "failed": "Failed" }
// A profile queued behind a switch-over reads "Waiting…" (its switch is on
// via switchOn, so a blank sub-line would look like a stuck connect).
function rowSubline(state, isPending) { return isPending ? "Waiting\u2026" : (SUBLINES[state] || "") }

// Backend file basename → URL relative to services/. Rejects anything that
// isn't a plain CamelCase identifier (no paths, no lowercase-only names).
function backendUrl(name) {
    return (typeof name === "string" && /^[A-Z][A-Za-z0-9]*$/.test(name)) ? "vpn/" + name + ".qml" : ""
}

// ---- one-at-a-time planner (spec goal 4, calls 8–10) ----
// pending: { backendId, id } | null — the single profile waiting to connect
// once everything else is down (last intent wins: a new target replaces it).
// Plan: { pending, actions: [{ op: "connect"|"disconnect", backendId, id }] }.
// Only applied to quill's own toggles; external changes are never enforced.

function _same(a, backendId, id) { return !!a && a.backendId === backendId && a.id === id }
function _up(state) { return state === "connected" || state === "connecting" }
function _busy(state) { return _up(state) || state === "disconnecting" }
function _act(op, p) { return { op: op, backendId: p.backendId, id: p.id } }

function planToggle(groups, pending, backendId, id) {
    if (_same(pending, backendId, id)) return { pending: null, actions: [] }
    var all = allProfiles(groups)
    var target = null
    for (var i = 0; i < all.length; i++) if (_same(all[i], backendId, id)) target = all[i]
    if (target && _up(target.state))
        return { pending: pending, actions: [_act("disconnect", target)] }

    var others = all.filter(function (p) { return !_same(p, backendId, id) })
    var actions = others.filter(function (p) { return _up(p.state) })
                        .map(function (p) { return _act("disconnect", p) })
    var blocked = others.some(function (p) { return _busy(p.state) })
    if (!blocked) return { pending: null, actions: [{ op: "connect", backendId: backendId, id: id }] }
    return { pending: { backendId: backendId, id: id }, actions: actions }
}

function planStep(groups, pending) {
    if (!pending) return { pending: null, actions: [] }
    var all = allProfiles(groups)
    if (!all.some(function (p) { return _same(p, pending.backendId, pending.id) }))
        return { pending: null, actions: [] }
    var blocked = all.some(function (p) { return !_same(p, pending.backendId, pending.id) && _busy(p.state) })
    if (blocked) return { pending: pending, actions: [] }
    return { pending: null, actions: [{ op: "connect", backendId: pending.backendId, id: pending.id }] }
}

function switchOn(state, isPending) { return !!isPending || _up(state) }

// Switch timeout (spec call 8): force the pending connect only when nothing
// else is still connected/connecting — i.e. the old tunnel is stuck in
// "disconnecting". If a `down` failed outright, drop the switch instead of
// bringing up a second tunnel.
function planTimeout(groups, pending) {
    if (!pending) return { pending: null, actions: [] }
    var all = allProfiles(groups)
    if (!all.some(function (p) { return _same(p, pending.backendId, pending.id) }))
        return { pending: null, actions: [] }
    var stillUp = all.some(function (p) { return !_same(p, pending.backendId, pending.id) && _up(p.state) })
    if (stillUp) return { pending: null, actions: [] }
    return { pending: null, actions: [{ op: "connect", backendId: pending.backendId, id: pending.id }] }
}

// An `nmcli connection up` exit counts as a failure only if quill didn't
// cancel it itself (a `down` issued while it was still running) — #55.
function upExitFailed(exitCode, cancelledByQuill) { return exitCode !== 0 && !cancelledByQuill }
