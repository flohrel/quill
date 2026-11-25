pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../lib/tray.js" as Tray

// Niri-aware tray left-click (#39). The decision lives in lib/tray.js
// (resolveTrayAction / pendingOutcome); this singleton only executes it:
//   activate   -> item.activate()               (SNI default)
//   focus      -> NiriService.focusWindow(id)
//   scratchpad -> niri-scratchpad argv            (toggle here <-> scratch)
//   reopen     -> trigger the app's own DBusMenu entry (e.g. "Show Spotify"),
//                 then wait up to 5 s for its window and either summon it
//                 with `niri-scratchpad --show` or focus it.
// Quickshell instantiates singletons lazily (first click), so a click that
// arrives before the niri-scratchpad probe has answered is queued, not
// resolved with scriptAvailable=false.
Singleton {
    id: root

    property bool scriptAvailable: false
    property bool _probed: false
    property var _queued: null      // SystemTrayItem clicked before the probe finished

    // In-flight DBusMenu lookup (reopen).
    property var _menuItem: null
    property string _menuLabel: ""
    property var _menuPending: null // {appId, argv} to record once the entry fired

    // Reopen follow-up: {appId, argv} waiting for the app's window to appear.
    property var _pending: null

    function activateItem(item) {
        if (!item) return
        if (!root._probed) { root._queued = item; return }
        root._dispatch(item)
    }

    function _dispatch(item) {
        var r = Tray.resolveTrayAction(item.id, NiriService.windowList,
                                       NiriService.focusedWorkspaceId,
                                       NiriService.scratchWorkspaceId, {
            aliases: Config.tray.aliases,
            scratchpads: Config.tray.scratchpads,
            reopenMenu: Config.tray.reopenMenu,
            excluded: Config.tray.excluded,
            scriptAvailable: root.scriptAvailable
        })
        if (r.kind === "scratchpad") Quickshell.execDetached(r.argv)
        else if (r.kind === "focus") NiriService.focusWindow(r.windowId)
        else if (r.kind === "reopen") root._reopen(item, r.menuLabel, { appId: r.appId, argv: r.argv })
        else item.activate()
    }

    function _reopen(item, label, pending) {
        if (!item.menu) {
            item.activate()
            root._recordPending(pending)
            return
        }
        // A new click replaces any lookup still waiting on its menu.
        root._menuItem = item
        root._menuLabel = label
        root._menuPending = pending
        menuOpener.menu = item.menu
        menuTimer.restart()
        root._tryTrigger()      // children are usually already loaded (TrayMenu holds the menu open)
    }

    // Called on children (re)population; fires once the top-level entries exist.
    function _tryTrigger() {
        if (!root._menuItem) return
        var model = menuOpener.children
        var entries = model ? model.values : []
        if (!entries || entries.length === 0) return
        var entry = Tray.findMenuEntry(entries, root._menuLabel)
        var item = root._menuItem
        var pending = root._menuPending
        root._endMenuLookup()
        if (entry) entry.triggered()
        else item.activate()
        root._recordPending(pending)
    }

    function _endMenuLookup() {
        menuTimer.stop()
        root._menuItem = null
        root._menuLabel = ""
        root._menuPending = null
        // Release the menu outside the children-changed emission we may be in.
        Qt.callLater(function() { if (!root._menuItem) menuOpener.menu = null })
    }

    function _recordPending(pending) {
        root._pending = pending
        pendingTimer.restart()
        root._checkPending()    // in case the window appeared while we waited on the menu
    }

    function _checkPending() {
        if (!root._pending) return
        var o = Tray.pendingOutcome(root._pending, NiriService.windowList, NiriService.scratchWorkspaceId)
        if (o === null) return
        root._pending = null
        pendingTimer.stop()
        if (o.kind === "exec") Quickshell.execDetached(o.argv)
        else if (o.kind === "focus") NiriService.focusWindow(o.windowId)
    }

    QsMenuOpener {
        id: menuOpener
        onChildrenChanged: root._tryTrigger()
    }
    Connections {
        target: menuOpener.children
        function onValuesChanged() { root._tryTrigger() }
    }
    // Menu never populated: fall back to the SNI default action.
    Timer {
        id: menuTimer
        interval: 1500
        onTriggered: {
            if (!root._menuItem) return
            var item = root._menuItem
            var pending = root._menuPending
            root._endMenuLookup()
            item.activate()
            root._recordPending(pending)
        }
    }

    Connections {
        target: NiriService
        function onWindowListChanged() { root._checkPending() }
    }
    Timer {
        id: pendingTimer
        interval: 5000
        onTriggered: root._pending = null
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v niri-scratchpad"]
        running: true
        onExited: (exitCode) => {
            root.scriptAvailable = exitCode === 0
            root._probed = true
            var q = root._queued
            root._queued = null
            if (q) root._dispatch(q)
        }
    }
}
