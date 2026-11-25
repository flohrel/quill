import QtQuick

// Debounces a radio-enable flag mirrored from an async backend. NM re-notifies
// the stale old WirelessEnabled value ~280ms after a Set, ~1ms before the real
// one (captured 2026-07-04: PropertiesChanged false then true, back to back),
// so anything bound straight to Networking.wifiEnabled blinks once per toggle.
// request() latches the locally requested value through a settle window during
// which contradicting backend updates are ignored; on expiry `value` resyncs to
// the backend so a genuine refusal (e.g. hard rfkill) still lands. Backend
// changes outside the window (nmcli, rfkill switch) track immediately.
QtObject {
    id: latch
    property bool backendValue: false
    property int settleMs: 1000
    property bool value: backendValue        // broken on first request(); kept in sync manually after
    onBackendValueChanged: if (!settleTimer.running) value = backendValue

    function request(on) {
        value = on
        settleTimer.restart()
    }

    readonly property Timer settleTimer: Timer {
        interval: latch.settleMs
        onTriggered: latch.value = latch.backendValue
    }
}
