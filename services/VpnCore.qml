import QtQuick
import "vpn.js" as Vpn

// VpnService's state machine without any Quickshell dependency, so
// tests/tst_vpn_core.qml can drive it with fake backends. Merges backend
// groups, owns `pending`, and applies the one-at-a-time planner.
QtObject {
    id: core

    property var backends: []
    property int switchTimeoutMs: 25000
    property var pending: null   // { backendId, id } waiting for the others to go down

    readonly property var groups: Vpn.mergeGroups(backends.map(function (b) {
        return { backendId: b.backendId, displayName: b.displayName,
                 profiles: b.profiles, claimedIds: b.claimedIds }
    }))
    readonly property bool connected: Vpn.activeList(groups).length > 0
    readonly property bool hasProfiles: Vpn.hasProfiles(groups)
    readonly property string hubStatus: Vpn.hubStatus(groups, pending)

    function toggle(backendId, id) { _apply(Vpn.planToggle(groups, pending, backendId, id)) }
    function isPending(backendId, id) {
        return !!pending && pending.backendId === backendId && pending.id === id
    }
    function switchOn(backendId, id, state) { return Vpn.switchOn(state, isPending(backendId, id)) }

    function _backend(backendId) {
        for (var i = 0; i < backends.length; i++) if (backends[i].backendId === backendId) return backends[i]
        return null
    }
    function _apply(plan) {
        pending = plan.pending
        plan.actions.forEach(function (a) {
            var b = core._backend(a.backendId)
            if (!b) return
            if (a.op === "connect") b.connect(a.id); else b.disconnect(a.id)
        })
    }
    function _step() { if (pending) _apply(Vpn.planStep(groups, pending)) }

    // A backend's connect() synchronously marks the profile in-flight, which
    // changes `groups`. Doing that from inside groupsChanged re-enters the
    // `groups` binding: QML reports a binding loop and DROPS the update, so the
    // planner later sees the just-connected profile as "off" and a third toggle
    // brings up a second tunnel (live checkpoint 2026-11-06). Defer the step.
    onGroupsChanged: if (pending) Qt.callLater(_step)
    onPendingChanged: pending ? switchTimer.restart() : switchTimer.stop()

    // Spec call 8: if the old tunnel is stuck disconnecting, try the new one
    // anyway — but never while another is still up (final review #2).
    property Timer switchTimer: Timer {
        interval: core.switchTimeoutMs
        onTriggered: {
            var plan = Vpn.planTimeout(core.groups, core.pending)
            if (core.pending && plan.actions.length === 0)
                console.warn("VpnService: switch abandoned, previous VPN still up")
            core._apply(plan)
        }
    }
}
