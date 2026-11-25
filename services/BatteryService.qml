pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery backend: wraps the native UPower binding (Quickshell.Services.UPower),
// reading the aggregate displayDevice reactively — same pattern as
// BluetoothService wrapping Quickshell.Bluetooth. Exposes charge/charging/state
// + time-to-empty/full for the ControlsPill battery icon and BatteryPopup.
// (Replaces the old sysfs FileView+Timer poller, which nothing consumed.)
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev ? dev.isPresent : false
    // Quickshell's UPowerDevice.percentage is a 0..1 FRACTION (the binding
    // multiplies UPower's 0..100 DBus value by 0.01), NOT a 0..100 percent —
    // same fraction/percent gotcha noted in bluetooth.js. Scale back to 0..100
    // here so every consumer (pill %, batteryGlyph, lowBattery, batteryStat)
    // gets the 0..100 value it expects.
    readonly property int percent: dev ? Math.round(dev.percentage * 100) : 0
    readonly property int state: dev ? dev.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
                                     || state === UPowerDeviceState.PendingCharge
    readonly property int timeToEmpty: dev ? dev.timeToEmpty : 0
    readonly property int timeToFull: dev ? dev.timeToFull : 0
}
