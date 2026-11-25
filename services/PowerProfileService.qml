pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Power-profile backend: wraps the PowerProfiles singleton from the native
// UPower binding. Exposes the current profile, whether Performance exists, and
// the ordered list of selectable profile ids for the BatteryPopup selector.
// Needs a power-profiles D-Bus service (e.g. power-profiles-daemon); when
// none is running the binding reports a default profile and setProfile is a
// no-op.
//
// Profile ids mirror PowerProfile.Enum: PowerSaver=0, Balanced=1, Performance=2.
Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile

    // Ordered selectable profiles; Performance only when the daemon offers it.
    readonly property var available: hasPerformanceProfile ? [0, 1, 2] : [0, 1]

    function setProfile(p) { PowerProfiles.profile = p }
}
