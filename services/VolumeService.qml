pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services   // qmllint disable import
import "volumes.js" as V

// Volume layers (#22): master × output → device volume, app × tab → stream
// volume. The rules are pure (volumes.js); this singleton keeps the layer
// state, saves it to ~/.local/state/quill/volumes.json, runs V.reconcile
// whenever PipeWire reports a change, and carries out the writes it returns
// through AudioService (devices) and MixerService (streams). Views bind
// only to the properties and functions below for volume and mute.
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quill"
    // Reassigned, never mutated (volumes.js returns copies).
    property var state: V.emptyState()
    // startedAt enables the startup grace: streams already playing when quill
    // starts are adopted as they are.
    property var session: V.newSession(Date.now())

    readonly property string defaultName: AudioService.sink ? String(AudioService.sink.name || "") : ""
    readonly property real masterLevel: state.master.level
    readonly property bool masterShownMuted: V.masterShownMuted(state, defaultName)

    // --- master
    function setMasterLevel(v) { _apply(V.setMaster(state, v), session) }
    function masterStep(delta) { setMasterLevel(Math.max(0, Math.min(1, state.master.level + delta))) }
    function toggleMasterMute() { _apply(V.toggleMasterMute(state, defaultName), session) }

    // --- outputs (by node.name)
    function outputLevel(name) { return V.outputLevel(state, name) }
    function outputMuted(name) { return V.outputMuted(state, name) }
    function setOutputLevel(name, v) { _apply(V.setOutput(state, name, v), session) }
    function toggleOutputMute(name) { _apply(V.toggleOutputMute(state, name), session) }

    // --- apps (by group key)
    function appLevel(key) { return V.appLevel(state, key) }
    function appMuted(key) { return V.appMuted(session, key) }
    function setAppLevel(key, v) {
        const r = V.setApp(state, session, key, v)
        _apply(r.state, r.session)
    }
    function toggleAppMute(key) { _apply(state, V.toggleAppMute(session, key)) }

    // --- tabs (by stream id; resolved to the stream's serial)
    function _uid(id) {
        const s = MixerService.streamRefs.find(x => x.id === id)
        return s ? s.uid : ""
    }
    function tabLevel(id) { return V.tabLevel(session, _uid(id)) }
    function tabMuted(id) { return V.tabMuted(session, _uid(id)) }
    function setTabLevel(id, v) {
        const u = _uid(id)
        if (u !== "") _apply(state, V.setTab(session, u, v))
    }
    function toggleTabMute(id) {
        const u = _uid(id)
        if (u !== "") _apply(state, V.toggleTabMute(session, u))
    }

    IpcHandler {
        target: "audio"
        function masterStep(delta: real): void { root.masterStep(delta) }
        function toggleMasterMute(): void { root.toggleMasterMute() }
    }

    // --- reconcile
    // A user action applies at once; a PipeWire change re-runs reconcile via
    // Qt.callLater (never from the onChanged of its own inputs).
    function _apply(st, se) {
        state = st
        session = se
        _reconcile()
    }

    readonly property string _sig: JSON.stringify(AudioService.outputLevels) + "|"
        + MixerService.streamRefs.map(s => s.uid + ":" + s.key + ":" + s.volume.toFixed(3) + ":" + s.muted).join(",")
    on_SigChanged: Qt.callLater(root._reconcile)

    function _reconcile() {
        // Echoes of quill's own writes, stale ones included, are recognised
        // inside V.reconcile (recent-write window), so observations go in raw.
        const lv = AudioService.outputLevels
        const devices = Object.keys(lv).map(n => ({ name: n, volume: lv[n].volume, muted: lv[n].muted }))
        const r = V.reconcile(state, session, devices, MixerService.streamRefs, Date.now())
        state = r.state
        session = r.session
        r.writes.outputs.forEach(w => {
            AudioService.setOutputVolume(w.name, w.volume)
            AudioService.setOutputMuted(w.name, w.muted)
        })
        r.writes.streams.forEach(w => MixerService.writeStream(w.id, w.volume, w.muted))
        const text = V.serialize(state)
        if (text !== _savedText) saveTimer.restart()
    }

    // ---- persistence: ~/.local/state/quill/volumes.json
    property string _savedText: ""
    FileView {
        id: file
        path: root.stateDir + "/volumes.json"
        blockLoading: true
        blockAllReads: true
        atomicWrites: true
        printErrors: false
    }
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            const text = V.serialize(root.state)
            file.setText(text)
            root._savedText = text
        }
    }
    Process { id: mkdirProc; command: ["mkdir", "-p", root.stateDir] }
    Component.onCompleted: {
        mkdirProc.running = true
        try { state = V.parse(file.text()) } catch (e) { state = V.emptyState() }
        _savedText = V.serialize(state)
        Qt.callLater(root._reconcile)
    }
}
