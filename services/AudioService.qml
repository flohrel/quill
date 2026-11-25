pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool sourceMuted: source && source.audio ? source.audio.muted : false

    // PipeWire node props are only valid while tracked.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    // Setting a volume also unmutes: a drag means "I want sound" (#72).
    function setVolume(v) {
        if (!sink || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(1, v))
        if (sink.audio.muted) sink.audio.muted = false
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted }
    function toggleSourceMute() { if (source && source.audio) source.audio.muted = !source.audio.muted }
}
