import QtQuick

// Per-bar overlay coordinator. At most one overlay open at a time.
// Replaces the spec-1 IslandController. `active` names the open surface
// ("" when nothing is open); overlays bind their visibility to it and
// pills toggle it.
QtObject {
    property string active: ""   // "" | "calendar" | "controlcenter" | "power" | "network" | "bluetooth" | "battery" | "tray"
    readonly property bool isOpen: active !== ""

    // Bottom edge (window y) of the open right-column panel, so the
    // notification stack can sit below it; 0 when none is open. Each
    // right-column overlay writes it via a Binding while visible
    // (RestoreNone: with several Bindings on one property, restoring would
    // race on popup-to-popup switches), and it resets here otherwise.
    readonly property var rightPanels: ["controlcenter", "network", "bluetooth", "battery"]
    property real rightPanelBottom: 0
    onActiveChanged: if (rightPanels.indexOf(active) === -1) rightPanelBottom = 0

    // Notification stack geometry on this bar's output (window y + height;
    // height 0 when not shown here). Written by NotificationPopups, read by
    // NotificationHole to punch the stack out of the catchers' input masks.
    property real notifTop: 0
    property real notifHeight: 0

    function open(name)   { active = name }
    function close()      { active = "" }
    function toggle(name) { active = (active === name) ? "" : name }
}
