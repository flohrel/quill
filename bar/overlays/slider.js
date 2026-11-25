.pragma library

function clamp01(v) { return Math.max(0, Math.min(1, v)) }

// Map a pointer x within a track of width w to a 0..1 fraction, clamped.
// `inset` (px, default 0) keeps a knob inside the track: the usable span is
// [inset, w - inset], so the knob's centre never leaves the track (#72).
function fraction(x, w, inset) {
    var i = inset || 0
    var span = w - 2 * i
    if (span <= 0) return 0
    return clamp01((x - i) / span)
}

// Knob centre x for `value` on a track of width w with the same inset.
function knobCenter(value, w, inset) {
    var i = inset || 0
    return i + clamp01(value) * Math.max(0, w - 2 * i)
}

// Value the fill shows: the user's drag position while pressed (so late
// backend echoes can't make the handle jitter), the backend otherwise.
function displayValue(pressed, dragValue, backendValue) {
    return clamp01(pressed ? dragValue : backendValue)
}
