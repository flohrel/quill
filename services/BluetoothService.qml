pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import "bluetooth.js" as Bt

// Bluetooth backend: wraps Quickshell.Bluetooth (native BlueZ binding).
// Exposes the radio + scan + paired/available device lists for the
// control-center toggle, the pill icon, and the Bluetooth popup.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null

    // Latched like NetworkService.wifiEnabled so airplane mode (#11) observes
    // a debounced value. Whether BlueZ actually bounces Powered the way NM
    // bounces WirelessEnabled is unverified; the latch is cheap either way.
    readonly property bool enabled: btLatch.value
    function setEnabled(on) {
        if (!adapter) return
        btLatch.request(on)
        adapter.enabled = on
    }
    RadioLatch { id: btLatch; backendValue: root.adapter ? root.adapter.enabled : false }

    readonly property bool discovering: adapter ? adapter.discovering : false
    function startScan() { if (adapter) adapter.discovering = true }
    function stopScan() { if (adapter) adapter.discovering = false }

    // Sorted, partitioned snapshots of Bluetooth.devices (live BluetoothDevice
    // objects). Rebuilt imperatively ONLY when each sub-list's address *set*
    // changes (sameDeviceSet-guarded), NOT as a binding over the flat model.
    // Bluetooth.devices.valuesChanged fires repeatedly during discovery as
    // RSSI/properties update; handing the views a fresh array each tick would
    // destroy and recreate every delegate, collapsing an open expand strip on
    // a paired row. Membership changes (pair/forget/discover) are rare, so
    // delegates persist across the noisy ticks.
    property var pairedDevices: []
    property var availableDevices: []

    function rebuildDevices() {
        var all = Bluetooth.devices ? Bluetooth.devices.values : []
        var parts = Bt.partitionDevices(Bt.sortDevices(all))
        if (!Bt.sameDeviceSet(parts.paired, pairedDevices)) pairedDevices = parts.paired
        if (!Bt.sameDeviceSet(parts.available, availableDevices)) availableDevices = parts.available
    }
    onAdapterChanged: rebuildDevices()
    Component.onCompleted: rebuildDevices()
    Connections {
        target: Bluetooth.devices
        function onValuesChanged() { root.rebuildDevices() }
    }

    readonly property int connectedCount: {
        var n = 0
        for (var i = 0; i < pairedDevices.length; i++) if (pairedDevices[i].connected) n++
        return n
    }

    function connect(d) { if (d) d.connect() }
    function disconnect(d) { if (d) d.disconnect() }
    function forget(d) { if (d) d.forget() }
    function setTrusted(d, on) { if (d) d.trusted = on }

    // Pairing runs through a one-shot `bluetoothctl pair` instead of the
    // native BluetoothDevice.pair(): Quickshell 0.3.0 registers no BlueZ
    // pairing agent (no org.bluez.Agent1), so the native call completes
    // just-works pairing WITHOUT a link key — BlueZ reports Paired but
    // Bonded stays false, the A2DP connect then fails with
    // br-connection-key-missing and BlueZ drops the temporary device (the
    // "connected for a second, then gone from the list" symptom).
    // bluetoothctl brings its own agent, producing a real bond. Trust and
    // profile-connect run in the same shell chain: the native
    // device.connect() refuses while the bare ACL link from pairing is
    // still up ("Device is already connected"), so the A2DP profiles never
    // come up and the bond is purged when the link drops. bluetoothctl
    // connect (BlueZ Device1.Connect) brings profiles up regardless.
    readonly property string pairingAddress: pairProc.running ? pairProc.address : ""

    function pair(d) {
        if (!d || pairProc.running) return
        // Pairable maps to the kernel's bondable flag; with it off, pairing
        // "succeeds" but the link key is flagged No Bonding and never stored
        // (Bonded stays false, the pairing evaporates on disconnect). It has
        // been observed off at runtime with no known setter, so assert it.
        if (adapter && !adapter.pairable) adapter.pairable = true
        pairProc.address = d.address
        pairProc.running = true
    }

    Process {
        id: pairProc
        property string address: ""
        // coreutils timeout, not bluetoothctl --timeout: the latter makes
        // bluetoothctl linger the FULL duration even after the command
        // completes. External timeout exits with bluetoothctl on success
        // and kills a hung step.
        command: ["sh", "-c",
            "timeout 30 bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && timeout 30 bluetoothctl connect \"$1\"",
            "pair-chain", address]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("bluetooth pair chain failed for", address, "exit code", exitCode)
        }
    }
}
