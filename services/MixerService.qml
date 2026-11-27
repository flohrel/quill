pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services   // qmllint disable import
import "mixer.js" as M
import "routing.js" as R

// Per-app mixer backend (#18). Maps PipeWire stream nodes to plain records
// and hands them to the pure grouping logic in mixer.js. The UI binds only
// to `groups` and the setters below — never to PipeWire nodes.
// Per-app output routing (#20): a route table (routing.js) persisted in
// ~/.local/state/quill/routes.json; streams of a routed app are pinned with
// `pw-metadata <id> target.object <node.name>`. While a pinned device is
// away WirePlumber plays the app on the default; it moves back on return.
Singleton {
    id: root

    // Every stream node (playback + capture; mixer.js keeps playback only).
    // Filtered on isStream alone, not on `audio`: node props are only valid
    // while tracked, so gating tracking on them could never start.
    readonly property var streamNodes: Pipewire.nodes.values.filter(n => n && n.isStream)

    PwObjectTracker { objects: root.streamNodes }

    // Order state: mutated in place by M.buildGroups, NEVER reassigned —
    // reassigning would re-trigger the `groups` binding (binding loop).
    readonly property var _state: M.newOrderState()

    readonly property var groups: M.buildGroups(
        streamNodes.filter(n => n.audio).map(root.toRecord), _state)

    function _str(v) { return v === undefined || v === null ? "" : String(v) }

    function toRecord(n) {
        const p = n.properties || {}
        return {
            id: n.id,
            mediaClass: _str(p["media.class"]),
            binary: _str(p["application.process.binary"]),
            appName: _str(p["application.name"]),
            iconName: _str(p["application.icon-name"]),
            mediaName: _str(p["media.name"]),
            description: _str(n.description),
            nodeName: _str(n.name),
            volume: n.audio ? n.audio.volume : 0,
            muted: n.audio ? n.audio.muted : false
        }
    }

    function _node(id) {
        return streamNodes.find(n => n.id === id && n.audio) || null
    }
    function _group(key) {
        return groups.find(g => g.key === key) || null
    }

    // Dragging a slider means "I want sound": setting a volume also clears
    // that stream's mute (#72). setGroupVolume goes through here.
    function setStreamVolume(id, v) {
        const n = _node(id)
        if (!n) return
        n.audio.volume = M.clamp01(v)
        if (n.audio.muted) n.audio.muted = false
    }
    function setGroupVolume(key, v) {
        const g = _group(key)
        if (g) g.streams.forEach(s => setStreamVolume(s.id, v))
    }
    function toggleStreamMute(id) {
        const n = _node(id)
        if (n) n.audio.muted = !n.audio.muted
    }
    function toggleGroupMute(key) {
        const g = _group(key)
        if (!g) return
        const target = !g.muted
        g.streams.forEach(s => { const n = _node(s.id); if (n) n.audio.muted = target })
    }
    // --- Per-app output routing (#20)
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quill"
    // Reassigned on every change, never mutated (routing.js returns copies).
    property var routeTable: R.emptyTable()
    readonly property var _outputs: AudioService.outputs
    readonly property string defaultOutputLabel: AudioService.outputLabel

    function routeChip(key) { return R.chip(R.routeFor(routeTable, key), _outputs) }
    function outputRows(key) {
        const g = _group(key)
        return R.outputRows(R.routeFor(routeTable, key), _outputs, g ? g.volume : 0)
    }
    function isPinned(key) { return R.routeFor(routeTable, key) !== null }
    function _pinnedTo(key, name) {
        const r = R.routeFor(routeTable, key)
        return !!r && r.device === name
    }
    function _setTable(t) {
        routeTable = t
        routesFile.setText(R.serialize(t))
    }
    function followDefault(key) {
        if (isPinned(key)) _setTable(R.clearRoute(routeTable, key))
    }
    function pinOutput(key, name) {
        const g = _group(key)
        if (!g || !g.routable || !R.usable(_outputs, name) || _pinnedTo(key, name)) return
        const d = _outputs.find(o => o.name === name)
        _setTable(R.setRoute(routeTable, key, name, d ? d.label : name))
    }
    // "Choose output" from Follow default: pin to the device the app is
    // already playing on (the default), so one output is always selected.
    function chooseOutput(key) {
        if (isPinned(key)) return
        const name = R.defaultOutput(_outputs)
        if (name !== "") pinOutput(key, name)
    }
    // A row's slider: on the pinned device it is the app volume; raising an
    // "off" device pins the app there at the dragged level.
    function setOutputLevel(key, name, v) {
        if (_pinnedTo(key, name)) { setGroupVolume(key, v); return }
        if (v <= 0) return
        pinOutput(key, name)
        if (_pinnedTo(key, name)) setGroupVolume(key, v)
    }

    // --- For VolumeService (#22): every live playback stream with its
    // group key and serial (uid), ready nodes only; a raw writer that never
    // unmutes on its own; and the devices live pinned apps play on.
    readonly property var streamRefs: {
        const out = []
        groups.forEach(g => g.streams.forEach(s => {
            const n = root._node(s.id)
            if (n && n.ready)
                out.push({ id: s.id, uid: root._serial(s.id) || ("id" + s.id), key: g.key,
                           volume: s.volume, muted: s.muted })
        }))
        return out
    }
    function writeStream(id, volume, muted) {
        const n = _node(id)
        if (!n) return
        n.audio.volume = M.clamp01(volume)
        n.audio.muted = !!muted
    }
    readonly property var liveRouteDevices: {
        const out = {}
        groups.forEach(g => {
            const r = g.routable ? R.routeFor(routeTable, g.key) : null
            if (r && R.usable(_outputs, r.device)) out[r.device] = true
        })
        return out
    }

    // Planner: any change to streams, routes or device availability re-plans
    // after a short debounce (never from an onChanged of its own inputs).
    property var _pinState: R.newPinState()
    // object.serial: PipeWire reuses node ids, serials are never reused, so
    // a new stream on a recycled id still counts as new.
    function _serial(id) {
        const n = _node(id)
        return n && n.properties ? _str(n.properties["object.serial"]) : ""
    }
    readonly property var _planStreams: {
        const out = []
        groups.forEach(g => g.streams.forEach(s => out.push({ id: s.id, uid: root._serial(s.id) || ("id" + s.id), key: g.key })))
        return out
    }
    readonly property string _planSig: _planStreams.map(s => s.uid + ":" + s.key).join(",")
        + "|" + R.serialize(routeTable)
        + "|" + _outputs.map(o => o.name + ":" + o.available).join(",")
    on_PlanSigChanged: planTimer.restart()
    Timer { id: planTimer; interval: 150; onTriggered: root._runPlan() }
    function _runPlan() {
        const r = R.plan(_planStreams, routeTable, _outputs, _pinState)
        _pinState = r.st
        r.ops.forEach(op => _enqueue(op))
    }

    // Runner: one pw-metadata call at a time; a newer op for the same stream
    // replaces a queued one.
    property var _queue: []
    property var _current: null
    function _enqueue(op) {
        _queue = _queue.filter(q => q.uid !== op.uid).concat([op])
        _next()
    }
    function _next() {
        if (_current) return
        // Skip ops whose stream is gone, or whose id now belongs to a newer
        // stream (the planner sees that one separately).
        let op = null
        while (_queue.length > 0 && !op) {
            const q = _queue[0]
            _queue = _queue.slice(1)
            if (_node(q.id) && (_serial(q.id) || ("id" + q.id)) === q.uid) op = q
        }
        if (!op) return
        _current = op
        pinProc.command = op.op === "pin"
            ? ["pw-metadata", String(op.id), "target.object", op.device]
            : ["pw-metadata", "-d", String(op.id), "target.object"]
        pinProc.running = true
    }
    Process {
        id: pinProc
        onExited: (exitCode) => {
            const op = root._current
            root._current = null
            if (exitCode !== 0 && op) {
                console.warn("mixer: pw-metadata failed", exitCode, JSON.stringify(op))
                // Forget a failed pin so the next plan retries it (no timer retries).
                if (op.op === "pin" && root._node(op.id)) {
                    const pinned = Object.assign({}, root._pinState.pinned)
                    delete pinned[op.uid]
                    root._pinState = { pinned: pinned, absent: root._pinState.absent }
                }
            }
            Qt.callLater(root._next)
        }
    }

    // ---- persistence: ~/.local/state/quill/routes.json
    FileView {
        id: routesFile
        path: root.stateDir + "/routes.json"
        blockLoading: true
        blockAllReads: true
        atomicWrites: true
        printErrors: false
    }
    Process { id: mkdirProc; command: ["mkdir", "-p", root.stateDir] }
    Component.onCompleted: {
        mkdirProc.running = true
        try { routeTable = R.parse(routesFile.text()) } catch (e) { routeTable = R.emptyTable() }
    }
}
