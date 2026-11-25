import QtQuick
import Quickshell
import Quickshell.Io
import qs.config   // qmllint disable import
import "../vpn.js" as Vpn

// NetworkManager VPN backend (#9): every NM profile of type `vpn` or
// `wireguard`, driven through nmcli because Quickshell.Networking has no VPN
// support. Implements the VpnService backend contract (spec "Backend
// contract"). Exclusivity is NOT enforced here — VpnService owns it.
//
// Never pass -s/--show-secrets and never request wireguard.* / vpn.secrets:
// only names, UUIDs, types and states leave nmcli.
Scope {
    id: root

    readonly property string backendId: "networkmanager"
    readonly property string displayName: "NetworkManager"
    property var profiles: []
    readonly property var claimedIds: []

    // id → true for profiles whose last `up` failed. Reassigned, never mutated.
    property var _failed: ({})
    // id → "connecting"|"disconnecting" for actions quill issued that NM may not
    // report yet. Kept until a refresh that STARTED after the action exited, so
    // a quick second toggle always sees the profile busy (final review #1).
    property var _inflight: ({})
    property var _settled: ({})     // exited actions awaiting a post-exit refresh
    property var _clearing: ({})    // snapshot of _settled owned by the running refresh
    property var _active: ({})
    property var _upActs: []        // running `up` processes; a `down` marks them cancelled (#55)
    property var _list: []
    property bool _refreshing: false
    property bool _dirty: false

    function _setFailed(id, on) {
        var f = Object.assign({}, _failed)
        if (on) f[id] = true; else delete f[id]
        _failed = f
    }
    function _setInflight(id, st) {
        var f = Object.assign({}, _inflight)
        if (st) f[id] = st; else delete f[id]
        _inflight = f
    }
    function _recompute() { profiles = Vpn.mergeState(_list, _active, _failed, _inflight) }
    function _nameOf(id) {
        for (var i = 0; i < _list.length; i++) if (_list[i].id === id) return _list[i].name
        return id
    }

    function refresh() {
        if (_refreshing) { _dirty = true; return }
        _refreshing = true
        _clearing = _settled
        _settled = ({})
        listProc.running = true
    }
    function _refreshDone() {
        _refreshing = false
        if (_dirty) { _dirty = false; refresh() }
    }

    function connect(id) { _run("up", id) }
    function disconnect(id) { _run("down", id) }
    function _run(op, id) {
        if (!id) return
        _setFailed(id, false)
        _setInflight(id, op === "up" ? "connecting" : "disconnecting")
        _recompute()
        if (op === "down")
            _upActs.forEach(function (a) { if (a.uuid === id) a.cancelled = true })
        var act = actionComp.createObject(root, { op: op, uuid: id })
        if (act && op === "up") _upActs = _upActs.concat([act])
    }

    Component.onCompleted: refresh()

    // 1) all profiles → keep VPN types
    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Non-zero exit (NM down): error text parses to [] — no onExited
                // handler, so the chain runs exactly once (final review #3).
                root._list = Vpn.parseProfiles(this.text)
                activeProc.running = true
            }
        }
    }

    // 2) active connections → merge live state
    Process {
        id: activeProc
        command: ["nmcli", "-t", "-f", "UUID,STATE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                var active = Vpn.parseActive(this.text)
                for (var k in active) if (root._failed[k]) root._setFailed(k, false)
                for (var c in root._clearing) root._setInflight(c, null)
                root._clearing = ({})
                root._active = active
                root._recompute()
                root._refreshDone()
            }
        }
    }

    // Live updates: any NM event → debounced re-list. No polling loop.
    Process {
        id: monitorProc
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser { onRead: (line) => debounce.restart() }
        onExited: (exitCode) => monitorRestart.start()
    }
    Timer { id: debounce; interval: Config.vpn.refreshDebounceMs; onTriggered: root.refresh() }
    Timer { id: monitorRestart; interval: 2000; onTriggered: monitorProc.running = true }

    // One short-lived process per up/down; destroyed when it exits.
    Component {
        id: actionComp
        Process {
            id: act
            property string op
            property string uuid
            property bool cancelled: false
            running: true
            command: ["nmcli", "--wait", String(Config.vpn.nmWaitSeconds), "connection", op, "uuid", uuid]
            onExited: (exitCode) => {
                // `down` on an inactive profile exits 10 ("not active"): not a failure.
                if (act.op === "up")
                    root._upActs = root._upActs.filter(function (a) { return a !== act })
                if (act.op === "up" && Vpn.upExitFailed(exitCode, act.cancelled)) {
                    root._setFailed(act.uuid, true)
                    console.warn("NetworkManagerBackend: failed to connect", root._nameOf(act.uuid))
                }
                var s = Object.assign({}, root._settled); s[act.uuid] = true; root._settled = s
                root.refresh()
                act.destroy()
            }
        }
    }
}
