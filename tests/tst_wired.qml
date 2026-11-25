import QtQuick
import QtTest
import "../services/wired.js" as Wired

TestCase {
    name: "wired"

    function test_virtual_filtered() {
        var out = Wired.physicalOnly([{name:"enp4s0"},{name:"virbr0"},{name:"lo"},
            {name:"docker0"},{name:"veth12ab"},{name:"enp2s0f0"},{name:"wg0"}])
        compare(out.map(function(d){return d.name}), ["enp4s0","enp2s0f0"])
    }
    function test_speedLabel() {
        compare(Wired.speedLabel(0), ""); compare(Wired.speedLabel(undefined), "")
        compare(Wired.speedLabel(100), "100 Mb/s"); compare(Wired.speedLabel(1000), "1 Gb/s")
        compare(Wired.speedLabel(2500), "2.5 Gb/s"); compare(Wired.speedLabel(10000), "10 Gb/s")
    }
    function test_row_no_devices_hidden() {
        compare(Wired.ethernetRow([]).visible, false)
    }
    function test_row_unplugged_greyed() {
        var r = Wired.ethernetRow([{hasLink:false, state:"disconnected", linkSpeed:0},
                                   {hasLink:false, state:"unknown", linkSpeed:0}])
        compare(r.visible, true); compare(r.enabled, false); compare(r.state, "Disconnected")
    }
    function test_row_one_connected_with_speed() {
        var r = Wired.ethernetRow([{hasLink:true, state:"connected", linkSpeed:1000},
                                   {hasLink:false, state:"disconnected", linkSpeed:0}])
        compare(r.enabled, true); compare(r.state, "Connected · 1 Gb/s")
    }
    function test_row_connected_unknown_speed() {
        compare(Wired.ethernetRow([{hasLink:true, state:"connected", linkSpeed:0}]).state, "Connected")
    }
    function test_row_several_connected() {
        compare(Wired.ethernetRow([{hasLink:true, state:"connected", linkSpeed:1000},
            {hasLink:true, state:"connected", linkSpeed:100}]).state, "Connected · 2 devices")
    }
    function test_row_link_but_soft_disconnected_stays_clickable() {
        var r = Wired.ethernetRow([{hasLink:true, state:"disconnected", linkSpeed:1000}])
        compare(r.enabled, true); compare(r.state, "Disconnected")
    }
    function test_row_connecting() {
        var r = Wired.ethernetRow([{hasLink:true, state:"connecting", linkSpeed:1000}])
        compare(r.enabled, true); compare(r.state, "Connecting…")
    }

    function test_anyConnected_requires_carrier_and_connected() {
        compare(Wired.anyConnected([{hasLink:true, state:"connected"}]), true)
        compare(Wired.anyConnected([{hasLink:false, state:"disconnected"},
                                    {hasLink:true, state:"connected"}]), true)
    }
    function test_anyConnected_cable_pulled_drops_before_nm_deactivates() {
        // NM keeps state "connected" for a grace period after carrier loss;
        // the pill must go optimistic on hasLink instead of waiting it out.
        compare(Wired.anyConnected([{hasLink:false, state:"connected"}]), false)
    }
    function test_anyConnected_link_without_activation_is_not_connected() {
        compare(Wired.anyConnected([{hasLink:true, state:"disconnected"}]), false)
        compare(Wired.anyConnected([{hasLink:true, state:"connecting"}]), false)
        compare(Wired.anyConnected([]), false)
        compare(Wired.anyConnected(undefined), false)
    }

    function test_switchOn_connecting_counts_as_on_so_click_cancels() {
        compare(Wired.switchOn("connecting"), true)
        compare(Wired.switchOn("connected"), true)
        compare(Wired.switchOn("disconnected"), false)
        compare(Wired.switchOn("disconnecting"), false)
        compare(Wired.switchOn("unknown"), false)
    }
}
