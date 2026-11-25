pragma Singleton
import Quickshell
import QtQuick

// Semantic color roles. Modules reference ONLY these. `provider` is the active
// palette; swap it (future theme switcher) without touching any module.
Singleton {
    id: root
    property QtObject provider: GruvboxMaterial {}

    readonly property color background:    provider.background
    readonly property color surface:       provider.surface
    readonly property color surfaceAlt:    provider.surfaceAlt
    readonly property color foreground:    provider.foreground
    readonly property color foregroundDim: provider.foregroundDim
    readonly property color accent:        provider.accent
    readonly property color urgent:        provider.urgent
    readonly property color success:       provider.success
    readonly property color warning:       provider.warning
    readonly property color error:         provider.error
    readonly property color border:        provider.border
}
