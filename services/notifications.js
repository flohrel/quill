.pragma library

// Pure notification logic for NotificationService (#14). No Qt imports;
// array helpers return new arrays. Spec:
// docs/superpowers/specs/quill-notifications-design.md.

var DEFAULT_TIMEOUT_MS = { low: 3000, normal: 5000, critical: 0 }

// freedesktop urgency byte -> name. Unknown values are treated as normal.
function urgencyName(enumValue) {
    if (enumValue === 0) return "low"
    if (enumValue === 2) return "critical"
    return "normal"
}

// Effective timeout in ms; 0 means "never expires". freedesktop semantics,
// as common daemons: -1 (or any negative) -> urgency default, 0 -> never, >0 -> app value.
function resolveTimeoutMs(urgency, expireTimeoutMs) {
    if (expireTimeoutMs > 0) return expireTimeoutMs
    if (expireTimeoutMs === 0) return 0
    var d = DEFAULT_TIMEOUT_MS[urgency]
    return d === undefined ? DEFAULT_TIMEOUT_MS.normal : d
}

// Quickshell's Notification.expireTimeout -> ms for resolveTimeoutMs. It is
// already in ms (verified live, #14); any negative means "unset" (-1).
function appTimeoutMs(expireTimeout) {
    return expireTimeout < 0 ? -1 : expireTimeout
}

// Newest first. A re-sent (replaced) id keeps its slot.
function pushId(order, id) {
    if (order.indexOf(id) !== -1) return order.slice()
    return [id].concat(order)
}

function removeId(order, id) {
    return order.filter(function (x) { return x !== id })
}

function visibleIds(order, cap) {
    return order.slice(0, cap)
}

// `busctl --user status <name>` prints KEY=value lines; the owner's process
// name is on the Comm= line. No owner -> busctl fails with empty stdout.
function ownerFromBusctl(stdout) {
    var lines = (stdout || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        if (lines[i].indexOf("Comm=") === 0) return lines[i].slice(5).trim()
    }
    return ""
}

// Next reclaim step for the org.freedesktop.Notifications name. Quickshell's
// D-Bus server is process-wide and re-registers by itself whenever the owner
// leaves, so quill never recreates it: it only re-probes.
// A free name is transient (our server is about to grab it): retry, bounded.
// Another daemon owning the name is never touched: quill gives up and logs.
// No owner found after the retries (busctl missing, or our process listed
// under another name) is "unknown", not a foreign daemon.
function reclaimAction(owner, attempts, maxAttempts) {
    if (owner === "qs" || owner === "quickshell") return "done"
    if (owner !== "") return "giveup"
    if (attempts >= maxAttempts) return "unknown"
    return "retry"
}

// DND toggle + indicator only while quill is (or may be) the daemon.
function dndAvailable(enabled, gaveUp) { return !!enabled && !gaveUp }

// One countdown step over the service's remaining-ms map (id -> ms; ids that
// never expire are absent). Only visible, non-hovered ids tick. Returns a new
// map without the expired ids, plus the expired ids.
function tick(remaining, visible, hovered, elapsedMs) {
    var next = {}, expired = []
    for (var k in remaining) {
        var id = Number(k)
        var ms = remaining[k]
        if (visible.indexOf(id) !== -1 && !hovered[k]) ms -= elapsedMs
        if (ms <= 0) expired.push(id)
        else next[k] = ms
    }
    return { remaining: next, expired: expired }
}

// Which screen shows the popup stack: the focused output, else the first.
function popupScreen(focusedOutput, screenNames) {
    if (screenNames.indexOf(focusedOutput) !== -1) return focusedOutput
    return screenNames.length > 0 ? screenNames[0] : ""
}

// DND gate (#15): with do-not-disturb on, only critical notifications pop up.
function shouldPopup(urgency, dnd) {
    return !dnd || urgency === "critical"
}

// Timeout for a held (DND) notification (#15 review I1). Held ones have no
// card to dismiss, so they must always expire: a resolved 0 ("never") falls
// back to the urgency default; anything else is kept as is.
function heldTimeoutMs(urgency, resolvedMs) {
    return resolvedMs > 0 ? resolvedMs : resolveTimeoutMs(urgency, -1)
}

// Ids the shared ticker counts down: visible cards (capped) plus every held
// id (id -> true map; held ones have no card, so they are never hovered).
function tickingIds(order, cap, heldMap) {
    var ids = visibleIds(order, cap)
    for (var k in heldMap) {
        var id = Number(k)
        if (ids.indexOf(id) === -1) ids.push(id)
    }
    return ids
}

// ── #65 duplicate collapse ─────────────────────────────────────────────
// Identity of a notification for collapsing: exact app + summary + body +
// urgency. JSON array join so delimiters inside the text can't collide.
function dupKey(appName, summary, body, urgency) {
    function s(v) { return v === undefined || v === null ? "" : String(v) }
    return JSON.stringify([s(appName), s(summary), s(body), s(urgency)])
}

// Live id (other than excludeId) whose key matches, else -1. At most one
// live id per key: every collapse closes the older copy.
function findDuplicate(keysById, key, excludeId) {
    for (var id in keysById)
        if (Number(id) !== excludeId && keysById[id] === key) return Number(id)
    return -1
}

// Copies folded into one card so far, including the new one.
function foldCount(prevCount) { return (prevCount || 1) + 1 }

// How a repeat takes over: pop/hold follows the NEW copy's DND gate; a
// held repeat counts as missed only if the old copy wasn't already held.
function planCollapse(oldHeld, newPops) {
    return { pop: newPops, countHeld: !newPops && !oldHeld, unholdOld: oldHeld }
}

// --- Countdown indicator (#67). Spec:
// docs/superpowers/specs/quill-notification-countdown-design.md.

// Popup-model edits for a duplicate takeover (#70), given the model's nids in
// order. The old card's row is re-pointed at the new id (and moved to the
// top), never removed + re-inserted: that would destroy the card and build a
// new one (fade-in, icon reload) — the bump flicker. No card for the old id
// (it was held) → a plain insert at the top.
function takeoverOps(nids, oldId, newId) {
    var i = nids.indexOf(oldId)
    if (i === -1) return [{ op: "insert", index: 0, nid: newId }]
    var ops = [{ op: "set", index: i, nid: newId }]
    if (i > 0) ops.push({ op: "move", from: i, to: 0 })
    return ops
}

// Remaining share of the timeout, clamped to [0, 1]; 0 when it never expires.
function countdownFraction(remaining, total) {
    if (!(total > 0)) return 0
    var f = remaining / total
    if (!(f > 0)) return 0
    return f > 1 ? 1 : f
}

// Which indicator a card shows: the setting, unless the card is critical,
// never expires, or the setting is unknown -> "none".
function countdownStyle(setting, critical, total) {
    if (critical || !(total > 0)) return "none"
    return setting === "bar" || setting === "border" ? setting : "none"
}

// Perimeter of a w x h rectangle with corner radius r (clamped to fit).
function roundedRectPerimeter(w, h, r) {
    var rr = Math.max(0, Math.min(r, w / 2, h / 2))
    return 2 * (w + h) - 8 * rr + 2 * Math.PI * rr
}
