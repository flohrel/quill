.pragma library

// Pure decision layer for tray-icon left-clicks (#39): given an SNI item id
// and the current niri windows, decide what a click should do. No I/O.

// Copy of a niri-scratchpad argv with "--show" right after the program name.
// Idempotent.
function withShow(argv) {
    if (argv.indexOf("--show") !== -1) return argv.slice();
    var out = argv.slice();
    out.splice(1, 0, "--show");
    return out;
}

// itemId: SNI id; windows: [{id, appId, workspaceId}];
// config: {aliases, scratchpads, reopenMenu, excluded, scriptAvailable}
// (all keys lowercase SNI ids / appIds).
// -> {kind:"activate"} | {kind:"focus", windowId} | {kind:"scratchpad", argv}
//  | {kind:"reopen", menuLabel, appId, argv}
function resolveTrayAction(itemId, windows, focusedWorkspaceId, scratchWorkspaceId, config) {
    var id = (itemId || "").toLowerCase();
    if (id === "" || config.excluded.indexOf(id) !== -1) return { kind: "activate" };

    var target = (config.aliases[id] || id).toLowerCase();
    var matches = [];
    for (var i = 0; i < windows.length; i++) {
        var a = windows[i].appId;
        if (a && a.toLowerCase() === target) matches.push(windows[i]);
    }

    var pad = config.scratchpads[target];
    var usable = !!pad && config.scriptAvailable;

    if (matches.length === 0) {
        var label = config.reopenMenu[id];
        if (!label) return { kind: "activate" };
        return { kind: "reopen", menuLabel: label, appId: target,
                 argv: usable ? withShow(pad) : null };
    }
    if (usable) return { kind: "scratchpad", argv: pad };

    var best = null;
    for (var j = 0; j < matches.length; j++) {
        var w = matches[j];
        if (w.workspaceId === scratchWorkspaceId) continue;
        if (best === null) { best = w; continue; }
        var wf = w.workspaceId === focusedWorkspaceId;
        var bf = best.workspaceId === focusedWorkspaceId;
        if (wf !== bf ? wf : w.id > best.id) best = w;
    }
    return best === null ? { kind: "activate" } : { kind: "focus", windowId: best.id };
}

// Top-level DBusMenu entry whose text is exactly `label`, or null.
// entries: array-like of {text} (QsMenuOpener.children.values).
function findMenuEntry(entries, label) {
    if (!entries) return null;
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (e && e.text === label) return e;
    }
    return null;
}

// Follow-up for a pending "reopen" ({appId, argv}) once niri's window list
// changes. -> null (no window with that appId yet: keep waiting)
//  | {kind:"exec", argv} | {kind:"focus", windowId} | {kind:"none"}
//    (window landed on the scratch workspace: leave it there).
function pendingOutcome(pending, windows, scratchWorkspaceId) {
    var target = (pending.appId || "").toLowerCase();
    if (target === "") return null;
    for (var i = 0; i < windows.length; i++) {
        var w = windows[i];
        if (!w.appId || w.appId.toLowerCase() !== target) continue;
        if (pending.argv) return { kind: "exec", argv: pending.argv };
        if (w.workspaceId === scratchWorkspaceId) return { kind: "none" };
        return { kind: "focus", windowId: w.id };
    }
    return null;
}
