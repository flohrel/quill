.pragma library

// Pure airplane-mode logic (Android-style): which radios to switch on enter,
// what to restore on exit, and what to remember when the user flips a radio
// mid-flight. No Qt, no I/O — unit-tested in tests/tst_airplane.qml.
// Spec: docs/superpowers/specs/quill-airplane-mode-design.md.
//
// State: { active, keepOn: {wifi, bluetooth}, saved: {wifi, bluetooth} }.
// Radio values passed in are true / false / null, where null means the radio
// can't be commanded right now (not ready, hard-blocked, no adapter).
// Commands are { radio: bool } maps the caller applies. Every function
// returns fresh objects and never mutates its inputs.

var RADIOS = ["wifi", "bluetooth"]

function defaults() {
    return { active: false,
             keepOn: { wifi: false, bluetooth: false },
             saved: { wifi: true, bluetooth: true } }
}

function _bools(raw, fallback) {
    var out = {}
    var ok = raw !== null && typeof raw === "object" && !Array.isArray(raw)
    for (var i = 0; i < RADIOS.length; i++) {
        var r = RADIOS[i]
        out[r] = (ok && typeof raw[r] === "boolean") ? raw[r] : fallback[r]
    }
    return out
}

function _copy(state) {
    return { active: state.active,
             keepOn: _bools(state.keepOn, state.keepOn),
             saved: _bools(state.saved, state.saved) }
}

// Anything (parsed JSON, garbage) → a valid State, field by field.
function normalize(raw) {
    var d = defaults()
    if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return d
    return { active: typeof raw.active === "boolean" ? raw.active : d.active,
             keepOn: _bools(raw.keepOn, d.keepOn),
             saved: _bools(raw.saved, d.saved) }
}

function enter(state, radios) {
    var s = _copy(state), commands = {}
    for (var i = 0; i < RADIOS.length; i++) {
        var r = RADIOS[i], v = radios[r]
        s.saved[r] = v === true                    // unavailable counts as off
        if (v !== null && v !== undefined && v !== s.keepOn[r]) commands[r] = s.keepOn[r]
    }
    s.active = true
    return { state: s, commands: commands }
}

// Restores the saved radios by switching them on; never commands a radio off.
function exit(state, radios) {
    var s = _copy(state), commands = {}
    for (var i = 0; i < RADIOS.length; i++) {
        var r = RADIOS[i]
        if (s.saved[r] && radios[r] === false) commands[r] = true
    }
    s.active = false
    return { state: s, commands: commands }
}

function toggle(state, radios) {
    return state.active ? exit(state, radios) : enter(state, radios)
}

// A radio just became commandable (startup, late adapter): bring it to keepOn.
function onReady(state, radio, value) {
    var commands = {}
    if (state.active && value !== null && value !== undefined && value !== state.keepOn[radio])
        commands[radio] = state.keepOn[radio]
    return commands
}

// A radio's value changed. Recorded as a keep-on choice only during airplane
// mode and only when the change isn't one of ours (ignored = pending/unknown).
function observed(state, radio, value, ignored) {
    if (!state.active || ignored) return state
    var s = _copy(state)
    s.keepOn[radio] = value === true
    return s
}

function markPending(pending, radios, now, windowMs) {
    var p = Object.assign({}, pending)
    for (var i = 0; i < radios.length; i++) p[radios[i]] = now + windowMs
    return p
}

function isPending(pending, radio, now) {
    return pending[radio] !== undefined && now < pending[radio]
}

// Route one observed radio change:
// - ignored (our own command, unknown value) → nothing;
// - settling (shortly after the radio became commandable, e.g. a late adapter
//   that bluetoothd AutoEnable powers on) → push it back to keepOn, don't record;
// - otherwise → record it as the user's keep-on choice (during airplane mode).
function onChange(state, radio, value, ignored, settling) {
    if (ignored || value === null || value === undefined) return { state: state, commands: {} }
    if (settling) return { state: state, commands: onReady(state, radio, value) }
    return { state: observed(state, radio, value, false), commands: {} }
}
