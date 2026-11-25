import QtQuick
import QtTest
import "../services/network.js" as Net

TestCase {
    name: "network"

    function test_signalLevel_buckets() {
        compare(Net.signalLevel(0), 0)
        compare(Net.signalLevel(0.1), 1)
        compare(Net.signalLevel(0.3), 2)
        compare(Net.signalLevel(0.6), 3)
        compare(Net.signalLevel(0.9), 4)
    }
    function test_signalLevel_normalizes_and_clamps() {
        compare(Net.signalLevel(80), 4)   // 0..100 scale → 0.8
        compare(Net.signalLevel(40), 2)   // → 0.4
        compare(Net.signalLevel(-5), 0)
        compare(Net.signalLevel(999), 4)
    }
    function test_sort_connected_then_known_then_signal() {
        var out = Net.sortNetworks([
            { name: "weak",  connected: false, known: false, signalStrength: 0.2 },
            { name: "known", connected: false, known: true,  signalStrength: 0.1 },
            { name: "strong",connected: false, known: false, signalStrength: 0.9 },
            { name: "active",connected: true,  known: true,  signalStrength: 0.5 }
        ])
        compare(out.length, 4)
        compare(out[0].name, "active")  // connected first
        compare(out[1].name, "known")   // then known
        compare(out[2].name, "strong")  // then by signal desc
        compare(out[3].name, "weak")
    }
    function test_sort_dedupes_by_name_keeping_strongest() {
        var out = Net.sortNetworks([
            { name: "Dup", connected: false, known: false, signalStrength: 0.2 },
            { name: "Dup", connected: false, known: false, signalStrength: 0.8 }
        ])
        compare(out.length, 1)
        compare(out[0].signalStrength, 0.8)
    }
    function test_sort_dedupe_prefers_connected_over_stronger() {
        // multi-BSSID: connected on the weaker AP must survive the dedup,
        // otherwise activeNetwork goes null while we're actually online.
        var out = Net.sortNetworks([
            { name: "Dup", connected: false, known: false, signalStrength: 0.9 },
            { name: "Dup", connected: true,  known: true,  signalStrength: 0.2 }
        ])
        compare(out.length, 1)
        compare(out[0].connected, true)
        compare(out[0].signalStrength, 0.2)
    }
    function test_sameNetworkSet_order_insensitive() {
        var a = [{ name: "x" }, { name: "y" }]
        var b = [{ name: "y" }, { name: "x" }]
        compare(Net.sameNetworkSet(a, b), true)
    }
    function test_sameNetworkSet_detects_add_remove() {
        var base = [{ name: "x" }, { name: "y" }]
        compare(Net.sameNetworkSet(base, [{ name: "x" }, { name: "y" }, { name: "z" }]), false) // added
        compare(Net.sameNetworkSet(base, [{ name: "x" }]), false)                                // removed
        compare(Net.sameNetworkSet(base, [{ name: "x" }, { name: "z" }]), false)                 // swapped, same length
    }
    function test_sameNetworkSet_empty() {
        compare(Net.sameNetworkSet([], []), true)
    }
    function test_empty_safe() {
        compare(Net.sortNetworks([]).length, 0)
    }
    function test_wifiIconState_hidden_when_off() {
        compare(Net.wifiIconState(false, false, 0.9), "hidden")
        compare(Net.wifiIconState(false, true, 0.9), "hidden")
    }
    function test_wifiIconState_searching_when_on_disconnected() {
        compare(Net.wifiIconState(true, false, 0.9), "searching")
    }
    function test_wifiIconState_levels_when_connected() {
        compare(Net.wifiIconState(true, true, 0.9), "l4")
        compare(Net.wifiIconState(true, true, 0.6), "l3")
        compare(Net.wifiIconState(true, true, 0.3), "l2")
        compare(Net.wifiIconState(true, true, 0.1), "l1")
    }
    function test_wifiIconState_connected_clamps_to_l1() {
        compare(Net.wifiIconState(true, true, 0), "l1")
    }

    function test_group_wired_only()   { compare(Net.networkGroup(true, false), ["ethernet"]) }
    function test_group_both()         { compare(Net.networkGroup(true, true), ["ethernet", "wifi"]) }
    function test_group_wifi_only()    { compare(Net.networkGroup(false, true), ["wifi"]) }
    function test_group_offline()      { compare(Net.networkGroup(false, false), ["offline"]) }
    function test_group_vpn_appended()  { compare(Net.networkGroup(true, true, true), ["ethernet", "wifi", "vpn"]) }
    function test_group_vpn_wifi()      { compare(Net.networkGroup(false, true, true), ["wifi", "vpn"]) }
    function test_group_vpn_offline()   { compare(Net.networkGroup(false, false, true), ["offline", "vpn"]) }
    function test_group_no_vpn_unchanged() { compare(Net.networkGroup(true, false, false), ["ethernet"]) }
    function test_group_airplane_alone()    { compare(Net.networkGroup(false, false, false, true), ["airplane"]) }
    function test_group_airplane_wifi()     { compare(Net.networkGroup(false, true, false, true), ["airplane", "wifi"]) }
    function test_group_airplane_ethernet() { compare(Net.networkGroup(true, false, false, true), ["airplane", "ethernet"]) }
    function test_group_airplane_vpn()      { compare(Net.networkGroup(true, false, true, true), ["airplane", "ethernet", "vpn"]) }
    function test_group_airplane_off_unchanged() { compare(Net.networkGroup(false, false, false, false), ["offline"]) }

    function test_rowAction_second_click_collapses_password_field() {
        compare(Net.rowAction(true, false, false, true), "collapse")
    }
    function test_rowAction_new_secured_asks_for_password() {
        compare(Net.rowAction(false, false, false, true), "ask")
    }
    function test_rowAction_known_or_open_connects() {
        compare(Net.rowAction(false, false, true, true), "connect")
        compare(Net.rowAction(false, false, false, false), "connect")
    }
    function test_rowAction_connected_disconnects() {
        compare(Net.rowAction(false, true, true, true), "disconnect")
    }
}
