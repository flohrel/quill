pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "audiodevices.js" as AD

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool sourceMuted: source && source.audio ? source.audio.muted : false

    // PipeWire node props are only valid while tracked.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    // --- Devices (#5): plain records for the mixer's output/input pickers.
    // Every non-stream node is tracked (filtered on isStream alone, as in
    // MixerService: props are only valid while tracked, so gating tracking
    // on them could never start); audiodevices.js picks the real devices.
    readonly property var deviceNodes: Pipewire.nodes.values.filter(n => n && !n.isStream)
    PwObjectTracker { objects: root.deviceNodes }

    function _str(v) { return v === undefined || v === null ? "" : String(v) }
    function toRecord(n) {
        const p = n.properties || {}
        return {
            id: n.id,
            name: _str(n.name),
            description: _str(n.description),
            nick: _str(n.nickname),
            mediaClass: _str(p["media.class"]),
            deviceId: _str(p["device.id"]),
            bus: _str(p["device.bus"]),
            iconName: _str(p["device.icon_name"]),
            profileName: _str(p["device.profile.name"]),
            profileDescription: _str(p["device.profile.description"])
        }
    }
    readonly property var records: deviceNodes.map(root.toRecord)

    // Port availability (jack mic with nothing plugged in): Quickshell doesn't
    // expose device routes, so a one-shot pw-dump is parsed by
    // AD.unavailableFromText. Re-run when the device set changes (plugging
    // the jack switches the card profile, which swaps nodes) and whenever a
    // picker list opens (refreshAvailability).
    property var _unavailable: ({})
    readonly property string _deviceSig: records.map(r => r.name).join("\n")
    on_DeviceSigChanged: availDebounce.restart()
    Component.onCompleted: refreshAvailability()
    function refreshAvailability() { if (!dumpProc.running) dumpProc.running = true }
    Timer { id: availDebounce; interval: 300; onTriggered: root.refreshAvailability() }
    Process {
        id: dumpProc
        command: ["pw-dump"]
        stdout: StdioCollector { onStreamFinished: root._unavailable = AD.unavailableFromText(this.text) }
    }

    readonly property var outputs: AD.buildList(records, "output", sink ? _str(sink.name) : "", _unavailable)
    readonly property var inputs: AD.buildList(records, "input", source ? _str(source.name) : "", _unavailable)
    readonly property var _sinkRec: sink ? toRecord(sink) : null
    readonly property var _sourceRec: source ? toRecord(source) : null
    readonly property string outputLabel: AD.chipLabel(_sinkRec, "output")
    readonly property string inputLabel: AD.chipLabel(_sourceRec, "input")
    readonly property string outputGlyph: _sinkRec ? AD.glyph(_sinkRec) : AD.GLYPH_SPEAKER
    readonly property string inputGlyph: AD.GLYPH_MIC

    function _deviceNode(name, isKind) {
        if (_unavailable[name]) return null
        return deviceNodes.find(n => _str(n.name) === name && isKind(toRecord(n))) || null
    }
    // No-op for a stale/unknown or unavailable name. Always writes the preferred default,
    // even when the device is already the active one: the configured default
    // may be an absent device WirePlumber fell back from, and an explicit
    // pick must stop it taking over again when it reconnects.
    function setDefaultOutput(name) {
        const n = _deviceNode(name, AD.isOutput)
        if (n) Pipewire.preferredDefaultAudioSink = n
    }
    function setDefaultInput(name) {
        const n = _deviceNode(name, AD.isInput)
        if (n) Pipewire.preferredDefaultAudioSource = n
    }

    // --- Raw per-output levels (#22) for VolumeService, keyed by node.name:
    // hardware outputs only (AD.isOutput), and only nodes whose volume is
    // known: `ready` alone isn't enough for nodes that take their volume from
    // the card's route (ALSA, Bluetooth) — until the channels arrive the
    // volume reads 0 and writes are dropped. The setters never unmute.
    function _hasVolume(n) { return !!n && n.ready && !!n.audio && n.audio.channels.length > 0 }
    readonly property var outputLevels: {
        const out = {}
        deviceNodes.forEach(n => {
            if (root._hasVolume(n) && AD.isOutput(toRecord(n)))
                out[_str(n.name)] = { volume: n.audio.volume, muted: n.audio.muted }
        })
        return out
    }
    function _outputNode(name) {
        return deviceNodes.find(n => _hasVolume(n) && _str(n.name) === name && AD.isOutput(toRecord(n))) || null
    }
    function setOutputVolume(name, v) {
        const n = _outputNode(name)
        if (n) n.audio.volume = Math.max(0, Math.min(1, v))
    }
    function setOutputMuted(name, m) {
        const n = _outputNode(name)
        if (n) n.audio.muted = !!m
    }

    // Setting a volume also unmutes: a drag means "I want sound" (#72).
    function setVolume(v) {
        if (!sink || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(1, v))
        if (sink.audio.muted) sink.audio.muted = false
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted }
    function toggleSourceMute() { if (source && source.audio) source.audio.muted = !source.audio.muted }
}
