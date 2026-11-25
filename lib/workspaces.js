.pragma library

// Generic fallback for windows whose appId has no mapping
// (nf-fa-window_maximize). Kept here, not Config, following the
// format.js precedent of glyph constants living beside their logic.
var GENERIC_WINDOW = "\u{F2D0}";

// Pick the appId a workspace chip represents. `windows` is that workspace's
// windows as [{id, appId}] in model order; `lastFocusedId` is the id of the
// window last focused there (may be stale or undefined — falls back to the
// first window). -> appId string ("" = window without an appId), or null
// when the workspace has no windows.
function activeAppId(windows, lastFocusedId) {
    if (!windows || windows.length === 0) return null;
    for (var i = 0; i < windows.length; i++) {
        if (windows[i].id === lastFocusedId) return windows[i].appId || "";
    }
    return windows[0].appId || "";
}

// Resolve what a workspace chip renders.
// name: workspace name ("" for dynamic); hasWindows: whether any window is
// on it; appId: active window's appId ("" when none); maps come from Config.
// -> {kind: "glyph"|"label"|"dot", text}. Named workspaces missing from the
// map fall back to a text label so a rename never breaks the bar.
function glyphFor(name, hasWindows, appId, workspaceGlyphs, appGlyphs) {
    if (name !== "") {
        var g = workspaceGlyphs[name];
        return g ? { kind: "glyph", text: g } : { kind: "label", text: name };
    }
    if (!hasWindows) return { kind: "dot", text: "" };
    var a = appId === "" ? undefined : appGlyphs[appId.toLowerCase()];
    return { kind: "glyph", text: a || GENERIC_WINDOW };
}
