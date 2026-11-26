pragma Singleton
import QtQuick
import Quickshell
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

    readonly property var outputs: AD.buildList(records, "output", sink ? _str(sink.name) : "")
    readonly property var inputs: AD.buildList(records, "input", source ? _str(source.name) : "")
    readonly property var _sinkRec: sink ? toRecord(sink) : null
    readonly property var _sourceRec: source ? toRecord(source) : null
    readonly property string outputLabel: AD.chipLabel(_sinkRec, "output")
    readonly property string inputLabel: AD.chipLabel(_sourceRec, "input")
    readonly property string outputGlyph: _sinkRec ? AD.glyph(_sinkRec) : AD.GLYPH_SPEAKER
    readonly property string inputGlyph: AD.GLYPH_MIC

    function _deviceNode(name, isKind) {
        return deviceNodes.find(n => _str(n.name) === name && isKind(toRecord(n))) || null
    }
    // No-op for a stale/unknown name or the current default.
    function setDefaultOutput(name) {
        const n = _deviceNode(name, AD.isOutput)
        if (n && n !== sink) Pipewire.preferredDefaultAudioSink = n
    }
    function setDefaultInput(name) {
        const n = _deviceNode(name, AD.isInput)
        if (n && n !== source) Pipewire.preferredDefaultAudioSource = n
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
