pragma Singleton
import QtQuick
import Quickshell
import "caffeine.js" as Caffeine

// Caffeine: keep the session awake on demand. Holds a single `active` flag; the
// bar binds a Quickshell.Wayland.IdleInhibitor to it (see Bar.qml), so while
// active the compositor (niri) sees an inhibited surface over
// zwp_idle_inhibit_manager_v1. niri in turn suppresses its ext-idle-notify-v1
// stream, so swayidle's dim/lock/power-off timeouts never fire. No external
// process, no signals, nothing to leave stuck if quill exits.
Singleton {
    id: root
    property bool active: false

    function setActive(on) { root.active = Caffeine.normalized(on) }
    function toggle() { root.active = Caffeine.toggled(root.active) }
}
