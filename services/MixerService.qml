pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "mixer.js" as M

// Per-app mixer backend (#18). Maps PipeWire stream nodes to plain records
// and hands them to the pure grouping logic in mixer.js. The UI binds only
// to `groups` and the setters below — never to PipeWire nodes.
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
}
