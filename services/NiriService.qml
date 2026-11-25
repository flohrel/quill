pragma Singleton
import Quickshell
import QtQuick
import Niri
import "../lib/workspaces.js" as Workspaces

// Thin wrapper over the vendored qml-niri plugin. The ONLY file that imports
// `Niri`, so the niri backend is swappable from here.
Singleton {
    id: root
    readonly property alias workspaces: niri.workspaces
    readonly property alias focusedWindow: niri.focusedWindow

    // wsId -> appId of that workspace's active window ("" = window without
    // an appId). No key = workspace has no windows. Rebuilt wholesale on
    // window open/close/move and focus changes; UI binds to this property.
    property var workspaceApps: ({})

    // wsId -> id of the window last focused there (session-local history;
    // stale ids fall back to the first window inside activeAppId).
    property var _lastFocused: ({})

    // Plain snapshots for lib/tray.js: [{id, appId, workspaceId}], plus the
    // focused workspace id and the "scratch" workspace id (-1 if absent).
    property var windowList: []
    property var focusedWorkspaceId: -1
    property var scratchWorkspaceId: -1
    // Output name of the focused workspace ("" until niri reports one).
    property string focusedOutput: ""

    function focusWorkspace(id) { niri.focusWorkspaceById(id) }
    function focusWindow(id) { niri.focusWindow(id) }

    function _recomputeWorkspaces() {
        var focused = -1, scratch = -1, output = "";
        for (var i = 0; i < workspaceMirror.count; i++) {
            var w = workspaceMirror.objectAt(i);
            if (!w) continue;
            if (w.isFocused) { focused = w.wsId; output = w.wsOutput; }
            if (w.wsName === "scratch") scratch = w.wsId;
        }
        root.focusedWorkspaceId = focused;
        root.scratchWorkspaceId = scratch;
        root.focusedOutput = output;
    }

    function _recomputeApps() {
        var list = [];
        for (var j = 0; j < windowMirror.count; j++) {
            var m = windowMirror.objectAt(j);
            if (m) list.push({ id: m.winId, appId: m.appId, workspaceId: m.wsId });
        }
        root.windowList = list;
        var byWs = {};  // wsId -> [{id, appId}] in model order
        for (var i = 0; i < windowMirror.count; i++) {
            var w = windowMirror.objectAt(i);
            if (!w || !w.wsId) continue;
            (byWs[w.wsId] || (byWs[w.wsId] = [])).push({ id: w.winId, appId: w.appId });
        }
        var apps = {};
        for (var ws in byWs) {
            var appId = Workspaces.activeAppId(byWs[ws], root._lastFocused[ws]);
            if (appId !== null) apps[ws] = appId;
        }
        root.workspaceApps = apps;
    }

    onFocusedWindowChanged: {
        var fw = root.focusedWindow;
        if (!fw || !fw.workspaceId) return;
        root._lastFocused[fw.workspaceId] = fw.id;
        root._recomputeApps();
    }

    // Mirrors the plugin's window model into plain objects so _recomputeApps
    // can iterate it (QAbstractListModel rows aren't reachable from JS).
    Instantiator {
        id: windowMirror
        model: niri.windows
        delegate: QtObject {
            required property var model
            readonly property var winId: model.id
            readonly property string appId: model.appId || ""
            readonly property var wsId: model.workspaceId
            // A focused window dragged to another workspace doesn't fire
            // onFocusedWindowChanged (same window object) — record the move
            // as that workspace's focus history before recomputing.
            onWsIdChanged: {
                if (model.isFocused && wsId) root._lastFocused[wsId] = winId;
                root._recomputeApps();
            }
        }
        onObjectAdded: (index, object) => root._recomputeApps()
        onObjectRemoved: (index, object) => root._recomputeApps()
    }

    // Same idea for workspaces: ids, names and focus as plain properties.
    Instantiator {
        id: workspaceMirror
        model: niri.workspaces
        delegate: QtObject {
            required property var model
            readonly property var wsId: model.id
            readonly property string wsName: model.name || ""
            readonly property bool isFocused: model.isFocused
            readonly property string wsOutput: model.output || ""
            onIsFocusedChanged: root._recomputeWorkspaces()
            onWsNameChanged: root._recomputeWorkspaces()
            onWsOutputChanged: root._recomputeWorkspaces()
        }
        onObjectAdded: (index, object) => root._recomputeWorkspaces()
        onObjectRemoved: (index, object) => root._recomputeWorkspaces()
    }

    Niri {
        id: niri
        Component.onCompleted: connect()
    }
}
