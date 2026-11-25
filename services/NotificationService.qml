pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config   // qmllint disable import
import "notifications.js" as N

// quill's notification daemon (#14). Owns org.freedesktop.Notifications while
// quill runs. If another daemon already holds the name, quill leaves it alone
// and logs once; any D-Bus-activatable daemon remains the fallback while qs
// is down.
//
// How Quickshell 0.3.2 works (read from its source, #14 review): the D-Bus
// server is a process-wide singleton that registers the name once and
// re-registers by itself (QDBusServiceWatcher) whenever the current owner
// leaves. The QML NotificationServer is only a listener attached to it on
// reload. So the listener must ALWAYS exist while enabled (otherwise quill
// holds the name and drops everything, e.g. after a hot reload), and reclaim
// is just: probe the owner, retry briefly while the name is free, give up
// (with a warning) if another daemon holds it.
// Config.notifications.enabled=false turns quill's daemon off entirely.
Singleton {
    id: root

    // DND state that must survive a hot reload (#15 review I3). On a reload the
    // server re-emits live notifications into the new generation's singleton;
    // without this, dnd fell back to false and held ones popped as cards.
    // Quickshell 0.3.2 (src/core/persistentprops.cpp, reload.cpp, generation.cpp):
    // the old values are copied in during the generation's reload phase, which
    // runs before NotificationServer re-emits (PostReloadHook, after the old
    // generation is destroyed). A Singleton is a Scope (ReloadPropagator) and
    // matches its direct children to the old generation's BY INDEX, not by
    // reloadableId, so keep this the FIRST child object. Survives reloads only:
    // a full qs restart starts fresh (DND stays session-only, as specced).
    // heldIds is a list<int> (not a JS map) so no JS value crosses engines.
    PersistentProperties {
        id: persist
        reloadableId: "notificationsDnd"
        property bool dnd: false
        property int heldCount: 0
        property list<int> heldIds: []
    }

    // Live popup ids, newest first (N.pushId / N.removeId).
    property var order: []
    // True while another daemon shows notifications instead of quill: the
    // daemon is disabled in Config, or reclaim gave up.
    readonly property bool fallbackActive: !Config.notifications.enabled || root._gaveUp
    property bool _gaveUp: false
    // DND toggle/indicator are shown only while quill is (or may be) the daemon.
    readonly property bool dndAvailable: N.dndAvailable(Config.notifications.enabled, root._gaveUp)
    readonly property bool serverUp: serverLoader.status === Loader.Ready && serverLoader.item !== null

    // Same ids as `order`, as a ListModel ({ nid }) so popup Repeaters keep
    // their card delegates when the list changes.
    property ListModel popupModel: ListModel {}

    // Countdown state lives here, not per card (spec: one shared stack and
    // timers), so every output's copy of a card shows the same countdown.
    // id -> remaining ms; ids that never expire are absent.
    property var remaining: ({})
    property var _hovered: ({})

    signal replaced(int id)

    property var _byId: ({})
    property var _timeouts: ({})

    // Duplicate collapse (#65): id -> N.dupKey, and id -> copies folded into
    // its card (absent = 1). An exact repeat of a live notification takes
    // over the older one's card (which is expire()d), re-topped, with ×N.
    property var _keys: ({})
    property var count: ({})
    function repeatCount(id) { return root.count[id] || 1 }
    function _keyOf(n) { return N.dupKey(n.appName, n.summary, n.body, N.urgencyName(n.urgency)) }
    function _setKey(id, key) { var k = Object.assign({}, root._keys); k[id] = key; root._keys = k }

    // Do-not-disturb (#15), session-only. While on, non-critical notifications
    // are held: tracked and counted down (so they expire normally) but never
    // shown. Turning it off does not replay them. A held one stays held unless
    // it is replaced in place with an urgency that now pops (then it gets a card).
    property alias dnd: persist.dnd
    // Notifications held during this DND session. Deliberately not decremented
    // when a held one expires or closes; reset by turning DND off.
    property alias heldCount: persist.heldCount
    // Held ids as an id -> true map (for N.tickingIds / lookups).
    readonly property var _held: {
        var h = {}, a = persist.heldIds
        for (var i = 0; i < a.length; i++) h[a[i]] = true
        return h
    }
    function _isHeld(id) { return root._held[id] === true }
    function _hold(id) {
        if (root._isHeld(id)) return
        var a = [], cur = persist.heldIds
        for (var i = 0; i < cur.length; i++) a.push(cur[i])
        a.push(id)
        persist.heldIds = a
    }
    function _unhold(id) {
        if (!root._isHeld(id)) return
        var a = [], cur = persist.heldIds
        for (var i = 0; i < cur.length; i++) if (cur[i] !== id) a.push(cur[i])
        persist.heldIds = a
    }
    function setDnd(on) {
        root.dnd = on
        if (!on) root.heldCount = 0
    }
    function toggleDnd() { root.setDnd(!root.dnd) }

    IpcHandler {
        target: "notifications"
        function toggleDnd(): void { root.toggleDnd() }
    }
    property int _attempts: 0

    function byId(id) { return root._byId[id] || null }
    function timeoutMs(id) { var t = root._timeouts[id]; return t === undefined ? 0 : t }
    function urgency(id) { var n = byId(id); return n ? N.urgencyName(n.urgency) : "normal" }

    function dismiss(id) { var n = byId(id); if (n) n.dismiss() }
    function expire(id) { var n = byId(id); if (n) n.expire() }
    function activate(id) {
        var n = byId(id)
        if (!n) return
        var acts = n.actions
        for (var i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default") { acts[i].invoke(); return }
        }
        n.dismiss()
    }

    // A card reports hover so the shared countdown pauses for that id.
    function setHovered(id, on) {
        var h = Object.assign({}, root._hovered)
        if (on) h[id] = true; else delete h[id]
        root._hovered = h
    }

    function _timeoutFor(n) {
        return N.resolveTimeoutMs(N.urgencyName(n.urgency), N.appTimeoutMs(n.expireTimeout))
    }

    // (Re)start an id's countdown from its full resolved timeout.
    function _arm(id, ms) {
        var t = Object.assign({}, root._timeouts); t[id] = ms; root._timeouts = t
        var r = Object.assign({}, root.remaining)
        if (ms > 0) r[id] = ms; else delete r[id]
        root.remaining = r
    }

    function _onNotification(n) {
        n.tracked = true
        var id = n.id
        // Re-emitted on a reload generation switch (keepOnReload): same object.
        if (root._byId[id] !== undefined) return

        var m = Object.assign({}, root._byId)
        m[id] = n
        root._byId = m
        var urg = N.urgencyName(n.urgency)
        var key = _keyOf(n)
        var old = root._isHeld(id) ? -1 : N.findDuplicate(root._keys, key, id)
        _setKey(id, key)
        if (old !== -1) {
            // Takeover (#65). All state moves to the new id BEFORE the old
            // copy is expired: its `closed` may fire synchronously, and its
            // _forget only touches entries still keyed by `old`.
            var plan = N.planCollapse(root._isHeld(old), N.shouldPopup(urg, root.dnd))
            var c = Object.assign({}, root.count); c[id] = N.foldCount(root.count[old]); root.count = c
            if (plan.pop) {
                _arm(id, _timeoutFor(n))
                root.order = N.pushId(N.removeId(root.order, old), id)
                // Re-point the old card's row at the new id (and move it to
                // the top) instead of remove + insert (#70): the card survives,
                // so the bump is a counter tick + countdown refill, not a
                // destroy/fade-in flicker.
                var nids = []
                for (var i = 0; i < root.popupModel.count; i++) nids.push(root.popupModel.get(i).nid)
                N.takeoverOps(nids, old, id).forEach(function (o) {
                    if (o.op === "set") root.popupModel.setProperty(o.index, "nid", o.nid)
                    else if (o.op === "move") root.popupModel.move(o.from, o.to, 1)
                    else root.popupModel.insert(o.index, { nid: o.nid })
                })
                // Same card, same MouseArea: if it's hovered, keep the new id
                // paused too. Its exit will clear the flag under the new id
                // (the card's notifId is already the new one), so no freeze.
                if (root._hovered[old]) root.setHovered(id, true)
            } else {
                _arm(id, N.heldTimeoutMs(urg, _timeoutFor(n)))
                root._hold(id)
                if (plan.countHeld) root.heldCount++
            }
            if (plan.unholdOld) root._unhold(old)
        } else if (root._isHeld(id)) {
            // Held before a hot reload (persisted set): stays held, already counted.
            _arm(id, N.heldTimeoutMs(urg, _timeoutFor(n)))
        } else if (N.shouldPopup(urg, root.dnd)) {
            _arm(id, _timeoutFor(n))
            root.order = N.pushId(root.order, id)
            root.popupModel.insert(0, { nid: id })
        } else {
            // Held ones have no card, so they always expire (N.heldTimeoutMs).
            _arm(id, N.heldTimeoutMs(urg, _timeoutFor(n)))
            root._hold(id)
            root.heldCount++
        }
        // Quickshell never re-emits `notification` for a replaces_id: it updates
        // this object in place. Any changed field restarts the countdown (an OSD
        // that only changes a hint value must not expire mid-adjustment).
        var refresh = function () { root._refresh(n) }
        n.summaryChanged.connect(root, refresh)
        n.bodyChanged.connect(root, refresh)
        n.hintsChanged.connect(root, refresh)
        n.urgencyChanged.connect(root, refresh)
        n.expireTimeoutChanged.connect(root, refresh)
        n.appIconChanged.connect(root, refresh)
        n.imageChanged.connect(root, refresh)
        n.actionsChanged.connect(root, refresh)
        n.closed.connect(root, function () { root._forget(id) })
        if (old !== -1) { var o = root.byId(old); if (o) o.expire() }
    }

    function _refresh(n) {
        var id = n.id
        if (root._byId[id] === undefined) return
        _setKey(id, _keyOf(n))   // an in-place update is not a repeat: no collapse
        var urg = N.urgencyName(n.urgency)
        var ms = _timeoutFor(n)
        if (root._isHeld(id) && N.shouldPopup(urg, root.dnd)) {
            // Replaced in place into a pop-eligible urgency (critical): promote
            // the held one to a card. heldCount is left as is.
            root._unhold(id)
            _arm(id, ms)
            root.order = N.pushId(root.order, id)
            root.popupModel.insert(0, { nid: id })
        } else if (root._isHeld(id)) {
            _arm(id, N.heldTimeoutMs(urg, ms))
        } else {
            _arm(id, ms)
        }
        root.replaced(id)
    }

    function _forget(id) {
        root.order = N.removeId(root.order, id)
        for (var i = 0; i < root.popupModel.count; i++) {
            if (root.popupModel.get(i).nid === id) { root.popupModel.remove(i); break }
        }
        var m = Object.assign({}, root._byId); delete m[id]; root._byId = m
        var t = Object.assign({}, root._timeouts); delete t[id]; root._timeouts = t
        var r = Object.assign({}, root.remaining); delete r[id]; root.remaining = r
        var k = Object.assign({}, root._keys); delete k[id]; root._keys = k
        var c = Object.assign({}, root.count); delete c[id]; root.count = c
        root._unhold(id)
        root.setHovered(id, false)
    }

    // One shared ticker over the visible, non-hovered cards (N.tick).
    Timer {
        id: ticker
        interval: 100
        repeat: true
        running: Object.keys(root.remaining).length > 0
        onTriggered: {
            var res = N.tick(root.remaining,
                N.tickingIds(root.order, Config.notifications.maxVisible, root._held),
                root._hovered, interval)
            root.remaining = res.remaining
            for (var i = 0; i < res.expired.length; i++) root.expire(res.expired[i])
        }
    }

    // The listener. Never torn down while enabled (see header).
    Loader {
        id: serverLoader
        active: Config.notifications.enabled
        sourceComponent: Component {
            NotificationServer {
                keepOnReload: true
                bodySupported: true
                bodyMarkupSupported: true
                actionsSupported: true
                imageSupported: true
                persistenceSupported: false
                inlineReplySupported: false
                onNotification: n => root._onNotification(n)
            }
        }
        onLoaded: probe.running = true
    }

    // ---- reclaim: probe the name owner, decide via N.reclaimAction
    Process {
        id: probe
        command: ["busctl", "--user", "--auto-start=no", "status", "org.freedesktop.Notifications"]
        stdout: StdioCollector { onStreamFinished: root._onProbe(this.text) }
    }

    Timer {
        id: retry
        interval: Config.notifications.reclaimIntervalMs
        onTriggered: probe.running = true
    }

    // While another daemon owns the name, re-check now and then: if it exits,
    // Quickshell re-registers the name and quill becomes the daemon again.
    Timer {
        interval: 30000
        repeat: true
        running: root._gaveUp
        onTriggered: probe.running = true
    }

    function _onProbe(out) {
        var owner = N.ownerFromBusctl(out)
        var act = N.reclaimAction(owner, root._attempts, Config.notifications.reclaimMaxAttempts)
        if (act === "retry") {
            root._attempts++
            retry.restart()
        } else if (act === "done") {
            console.info("notifications: quill owns org.freedesktop.Notifications")
            root._gaveUp = false
        } else if (act === "unknown") {
            // No owner seen (busctl missing, or our process under another
            // name): assume quill's server holds the name; don't hide DND.
            console.info("notifications: could not determine the org.freedesktop.Notifications owner")
        } else if (!root._gaveUp) {
            root._gaveUp = true
            console.warn("notifications: another daemon owns org.freedesktop.Notifications ("
                         + owner + "); quill is not taking over")
        }
    }
}
