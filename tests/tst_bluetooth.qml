import QtQuick
import QtTest
import "../services/bluetooth.js" as Bt

TestCase {
    name: "bluetooth"

    function test_deviceIconGlyph_maps_known_icons() {
        compare(Bt.deviceIconGlyph("audio-headset"), "\u{F025}")
        compare(Bt.deviceIconGlyph("audio-headphones"), "\u{F025}")
        compare(Bt.deviceIconGlyph("input-mouse"), "\u{F037D}")
        compare(Bt.deviceIconGlyph("input-keyboard"), "\u{F030C}")
        compare(Bt.deviceIconGlyph("input-gaming"), "\u{F11B}")
        compare(Bt.deviceIconGlyph("phone"), "\u{F095}")
        compare(Bt.deviceIconGlyph("audio-card"), "\u{F028}")
        compare(Bt.deviceIconGlyph("audio-speakers"), "\u{F028}")
        compare(Bt.deviceIconGlyph("computer"), "\u{F109}")
    }
    function test_deviceIconGlyph_falls_back_to_generic_bluetooth() {
        compare(Bt.deviceIconGlyph("unknown-thing"), "\u{F293}")
        compare(Bt.deviceIconGlyph(""), "\u{F293}")
        compare(Bt.deviceIconGlyph(undefined), "\u{F293}")
    }

    function test_statusLabel_connecting() {
        compare(Bt.statusLabel({ state: 3, pairing: false, paired: true, connected: false }), "connecting…")
    }
    function test_statusLabel_connected() {
        compare(Bt.statusLabel({ state: 1, pairing: false, paired: true, connected: true }), "connected")
    }
    function test_statusLabel_pairing() {
        compare(Bt.statusLabel({ state: 0, pairing: true, paired: false, connected: false }), "pairing…")
    }
    function test_statusLabel_paired_idle() {
        compare(Bt.statusLabel({ state: 0, pairing: false, paired: true, connected: false }), "paired")
    }
    function test_statusLabel_unpaired_idle_is_empty() {
        compare(Bt.statusLabel({ state: 0, pairing: false, paired: false, connected: false }), "")
    }
    function test_statusLabel_null_device_is_empty() {
        compare(Bt.statusLabel(null), "")
    }
    function test_statusLabel_pairing_takes_priority_over_connecting() {
        compare(Bt.statusLabel({ state: 3, pairing: true, paired: false, connected: false }), "pairing…")
    }
    function test_statusLabel_external_pairing_address_match() {
        compare(Bt.statusLabel({ address: "aa", state: 0, pairing: false, paired: false, connected: false }, "aa"), "pairing…")
    }
    function test_statusLabel_external_pairing_other_device_unaffected() {
        compare(Bt.statusLabel({ address: "bb", state: 0, pairing: false, paired: true, connected: false }, "aa"), "paired")
    }
    function test_statusLabel_external_pairing_empty_address_ignored() {
        compare(Bt.statusLabel({ address: "aa", state: 0, pairing: false, paired: false, connected: false }, ""), "")
    }

    function test_batteryLabel_fraction_scale() {
        compare(Bt.batteryLabel({ batteryAvailable: true, battery: 0.8 }), "80%")
    }
    function test_batteryLabel_percentage_scale() {
        compare(Bt.batteryLabel({ batteryAvailable: true, battery: 80 }), "80%")
    }
    function test_batteryLabel_one_is_full_fraction() {
        compare(Bt.batteryLabel({ batteryAvailable: true, battery: 1 }), "100%")
    }
    function test_batteryLabel_unavailable_is_empty() {
        compare(Bt.batteryLabel({ batteryAvailable: false, battery: 0.8 }), "")
    }
    function test_batteryLabel_null_device_is_empty() {
        compare(Bt.batteryLabel(null), "")
    }
    function test_batteryLabel_rounds() {
        compare(Bt.batteryLabel({ batteryAvailable: true, battery: 0.333 }), "33%")
    }

    function test_partitionDevices_splits_on_paired_or_bonded() {
        var out = Bt.partitionDevices([
            { address: "a", paired: true,  bonded: false },
            { address: "b", paired: false, bonded: true },
            { address: "c", paired: false, bonded: false }
        ])
        compare(out.paired.length, 2)
        compare(out.available.length, 1)
        compare(out.paired[0].address, "a")
        compare(out.paired[1].address, "b")
        compare(out.available[0].address, "c")
    }
    function test_partitionDevices_empty_safe() {
        var out = Bt.partitionDevices([])
        compare(out.paired.length, 0)
        compare(out.available.length, 0)
    }

    function test_sortDevices_connected_first_then_name() {
        var out = Bt.sortDevices([
            { name: "Zebra", connected: false },
            { name: "alpha", connected: false },
            { name: "Mouse", connected: true }
        ])
        compare(out.length, 3)
        compare(out[0].name, "Mouse")    // connected first
        compare(out[1].name, "alpha")    // then case-insensitive name
        compare(out[2].name, "Zebra")
    }
    function test_sortDevices_empty_safe() {
        compare(Bt.sortDevices([]).length, 0)
    }
    function test_sortDevices_does_not_mutate_input() {
        var input = [{ name: "b", connected: false }, { name: "a", connected: false }]
        Bt.sortDevices(input)
        compare(input[0].name, "b")   // original order untouched
    }

    function test_sameDeviceSet_order_insensitive() {
        var a = [{ address: "aa" }, { address: "bb" }]
        var b = [{ address: "bb" }, { address: "aa" }]
        compare(Bt.sameDeviceSet(a, b), true)
    }
    function test_sameDeviceSet_detects_add_remove() {
        var base = [{ address: "aa" }, { address: "bb" }]
        compare(Bt.sameDeviceSet(base, [{ address: "aa" }, { address: "bb" }, { address: "cc" }]), false) // added
        compare(Bt.sameDeviceSet(base, [{ address: "aa" }]), false)                                       // removed
        compare(Bt.sameDeviceSet(base, [{ address: "aa" }, { address: "cc" }]), false)                    // swapped, same length
    }
    function test_sameDeviceSet_empty() {
        compare(Bt.sameDeviceSet([], []), true)
    }
    function test_sameDeviceSet_identical() {
        var a = [{ address: "aa" }, { address: "bb" }]
        compare(Bt.sameDeviceSet(a, a), true)
    }
}
