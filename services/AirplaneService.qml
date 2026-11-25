pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services   // qmllint disable import
import "airplane.js" as Air

// Airplane mode (#11), Android-style: entering turns the radios off except the
// ones the user kept on last time; flipping a radio mid-flight is remembered;
// leaving restores (switches back on) what was on before. The bookkeeping is
// pure (airplane.js); this singleton wires it to NetworkService /
// BluetoothService, persists it, and exposes a toggle over IPC
// (`qs ipc call airplane toggle`) for a compositor key bind.
Singleton {
    id: root

    readonly property int pendingMs: 1500      // > RadioLatch.settleMs (1000)
    readonly property int settleMs: 5000       // after a ready edge: re-assert keepOn, don't record
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quill"

    property var state: Air.defaults()
    property var pending: ({})
    property var settling: ({})
    readonly property bool active: state.active

    function toggle() {
        var r = Air.toggle(state, radios())
        state = r.state
        apply(r.commands)
        save()
    }

    IpcHandler {
        target: "airplane"
        function toggle(): void { root.toggle() }
    }

    // ---- radios: null = can't be commanded (not ready / hard-blocked / no adapter)
    readonly property bool wifiCommandable: NetworkService.wifiDevice !== null && NetworkService.wifiHardwareEnabled
    readonly property bool btCommandable: BluetoothService.available

    function value(r) {
        if (r === "wifi") return wifiCommandable ? NetworkService.wifiEnabled : null
        return btCommandable ? BluetoothService.enabled : null
    }
    function radios() { return { wifi: value("wifi"), bluetooth: value("bluetooth") } }

    function apply(commands) {
        var rs = Object.keys(commands)
        if (rs.length === 0) return
        // Mark BEFORE calling the setters: the latched value changes
        // synchronously inside them, and that change must read as ours.
        pending = Air.markPending(pending, rs, Date.now(), pendingMs)
        for (var i = 0; i < rs.length; i++) {
            if (rs[i] === "wifi") NetworkService.setWifiEnabled(commands.wifi)
            else BluetoothService.setEnabled(commands.bluetooth)
        }
    }

    function changed(r) {
        var now = Date.now()
        var res = Air.onChange(state, r, value(r), Air.isPending(pending, r, now), Air.isPending(settling, r, now))
        if (res.state !== state) { state = res.state; save() }
        apply(res.commands)
    }

    // A radio became commandable (startup, NM/BlueZ populating, late adapter,
    // hard-unblock): ignore its first values for a window, then bring it to keepOn.
    function readyEdge(r) {
        var now = Date.now()
        pending = Air.markPending(pending, [r], now, pendingMs)
        settling = Air.markPending(settling, [r], now, settleMs)
        ;(r === "wifi" ? wifiReadyTimer : btReadyTimer).restart()
    }
    onWifiCommandableChanged: if (wifiCommandable) readyEdge("wifi")
    onBtCommandableChanged: if (btCommandable) readyEdge("bluetooth")
    Timer { id: wifiReadyTimer; interval: root.pendingMs; onTriggered: root.apply(Air.onReady(root.state, "wifi", root.value("wifi"))) }
    Timer { id: btReadyTimer; interval: root.pendingMs; onTriggered: root.apply(Air.onReady(root.state, "bluetooth", root.value("bluetooth"))) }

    Connections {
        target: NetworkService
        function onWifiEnabledChanged() { root.changed("wifi") }
    }
    Connections {
        target: BluetoothService
        function onEnabledChanged() { root.changed("bluetooth") }
    }

    // ---- persistence: ~/.local/state/quill/airplane.json
    FileView {
        id: file
        path: root.stateDir + "/airplane.json"
        blockLoading: true
        blockAllReads: true
        atomicWrites: true
        printErrors: false
    }
    function load() {
        try { return Air.normalize(JSON.parse(file.text())) }
        catch (e) { return Air.defaults() }
    }
    function save() { file.setText(JSON.stringify(state)) }
    Process { id: mkdirProc; command: ["mkdir", "-p", root.stateDir] }

    Component.onCompleted: {
        mkdirProc.running = true
        state = load()
        if (wifiCommandable) readyEdge("wifi")
        if (btCommandable) readyEdge("bluetooth")
    }
}
