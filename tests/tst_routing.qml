import QtQuick
import QtTest
import "../services/routing.js" as R

// Per-app output routing (#20): route table, its file format, the pin
// planner, chip text and Outputs rows from services/routing.js.
TestCase {
    name: "routing"

    readonly property string spk: "alsa_output.pci-0000_00_1f.3.HiFi__Speaker__sink"
    readonly property string bt: "bluez_output.00_11_22_33_44_55.1"

    function dev(name, label, available) {
        return { name: name, label: label, glyph: "g", isDefault: false, available: available }
    }

    function test_parse_rejects_garbage() {
        compare(R.parse("not json"), R.emptyTable())
        compare(R.parse(""), R.emptyTable())
        compare(R.parse('{"version":2,"routes":{}}'), R.emptyTable())
        compare(R.parse('{"version":1,"routes":[]}'), R.emptyTable())
        compare(R.parse('{"version":1,"routes":null}'), R.emptyTable())
        compare(R.parse('null'), R.emptyTable())
        compare(R.parse('{"version":1,"routes":{"a":{"label":"x"},"b":{"device":"' + bt + '"},'
                        + '"c":{"device":""},"d":"str"}}'),
                { version: 1, routes: { b: { device: bt, label: bt } } })
    }
    function test_roundtrip_and_immutability() {
        var t0 = R.emptyTable()
        var t1 = R.setRoute(t0, "spotify", bt, "Speaker BT")
        compare(t0.routes, {})
        compare(R.routeFor(R.parse(R.serialize(t1)), "spotify"), { device: bt, label: "Speaker BT" })
        var t2 = R.clearRoute(t1, "spotify")
        compare(R.routeFor(t2, "spotify"), null)
        compare(R.routeFor(t1, "spotify"), { device: bt, label: "Speaker BT" })
        compare(R.routeFor(t0, "nope"), null)
    }
    function test_usable() {
        var d = [dev(spk, "Speaker", false), dev(bt, "BT", true)]
        verify(R.usable(d, bt))
        verify(!R.usable(d, spk))
        verify(!R.usable(d, "missing"))
    }
    function test_plan_pins_routed_streams() {
        var t = R.setRoute(R.emptyTable(), "spotify", bt, "BT")
        var st0 = R.newPinState()
        var r = R.plan([{ id: 10, key: "spotify" }, { id: 11, key: "other" }], t, [dev(bt, "BT", true)], st0)
        compare(r.ops, [{ op: "pin", id: 10, device: bt }])
        compare(r.st.pinned, { 10: bt })
        compare(st0.pinned, {})
    }
    function test_plan_new_stream_only() {
        var t = R.setRoute(R.emptyTable(), "firefox", bt, "BT"), d = [dev(bt, "BT", true)]
        var r1 = R.plan([{ id: 1, key: "firefox" }], t, d, R.newPinState())
        var r2 = R.plan([{ id: 1, key: "firefox" }, { id: 2, key: "firefox" }], t, d, r1.st)
        compare(r2.ops, [{ op: "pin", id: 2, device: bt }])
        compare(R.plan([{ id: 1, key: "firefox" }, { id: 2, key: "firefox" }], t, d, r2.st).ops, [])
    }
    function test_plan_absent_then_present() {
        var t = R.setRoute(R.emptyTable(), "spotify", bt, "BT"), s = [{ id: 10, key: "spotify" }]
        var r1 = R.plan(s, t, [dev(spk, "Speaker", true)], R.newPinState())
        compare(r1.ops, [])
        var r2 = R.plan(s, t, [dev(spk, "Speaker", true), dev(bt, "BT", true)], r1.st)
        compare(r2.ops, [{ op: "pin", id: 10, device: bt }])
    }
    function test_plan_repins_on_return() {
        var t = R.setRoute(R.emptyTable(), "spotify", bt, "BT"), s = [{ id: 10, key: "spotify" }]
        var on = [dev(bt, "BT", true)], off = []
        var r1 = R.plan(s, t, on, R.newPinState())
        var r2 = R.plan(s, t, off, r1.st)
        compare(r2.ops, [])
        var r3 = R.plan(s, t, on, r2.st)
        compare(r3.ops, [{ op: "pin", id: 10, device: bt }])
        compare(R.plan(s, t, on, r3.st).ops, [])
    }
    function test_plan_switch_device_repins() {
        var d = [dev(spk, "Speaker", true), dev(bt, "BT", true)], s = [{ id: 10, key: "spotify" }]
        var r1 = R.plan(s, R.setRoute(R.emptyTable(), "spotify", bt, "BT"), d, R.newPinState())
        var r2 = R.plan(s, R.setRoute(R.emptyTable(), "spotify", spk, "Speaker"), d, r1.st)
        compare(r2.ops, [{ op: "pin", id: 10, device: spk }])
    }
    function test_plan_unpin_while_absent() {
        var t = R.setRoute(R.emptyTable(), "spotify", bt, "BT"), s = [{ id: 10, key: "spotify" }]
        var r1 = R.plan(s, t, [dev(bt, "BT", true)], R.newPinState())
        var r2 = R.plan(s, R.clearRoute(t, "spotify"), [], r1.st)
        compare(r2.ops, [{ op: "unpin", id: 10 }])
        compare(r2.st.pinned, {})
    }
    function test_plan_unpins_stale_pin_to_other_absent_device() {
        var d = [dev(spk, "Speaker", true), dev(bt, "BT", true)], s = [{ id: 10, key: "spotify" }]
        var r1 = R.plan(s, R.setRoute(R.emptyTable(), "spotify", spk, "Speaker"), d, R.newPinState())
        var r2 = R.plan(s, R.setRoute(R.emptyTable(), "spotify", bt, "BT"), [dev(spk, "Speaker", true)], r1.st)
        compare(r2.ops, [{ op: "unpin", id: 10 }])
        compare(r2.st.pinned, {})
    }
    function test_plan_forgets_vanished_streams() {
        var t = R.setRoute(R.emptyTable(), "spotify", bt, "BT"), d = [dev(bt, "BT", true)]
        var r1 = R.plan([{ id: 10, key: "spotify" }], t, d, R.newPinState())
        compare(R.plan([], t, d, r1.st).st.pinned, {})
    }
    function test_unavailable_counts_as_unplugged() {
        var t = R.setRoute(R.emptyTable(), "mpv", spk, "Speaker")
        var d = [dev(spk, "Speaker", false)]
        compare(R.plan([{ id: 3, key: "mpv" }], t, d, R.newPinState()).ops, [])
        compare(R.chip(R.routeFor(t, "mpv"), d), { text: "→ Speaker · unplugged", kind: "unplugged" })
        var rows = R.outputRows(R.routeFor(t, "mpv"), d, 0.5)
        compare(rows.length, 1)
        compare(rows[0].state, "unplugged")
        compare(rows[0].level, -1)
    }
    function test_chip_texts() {
        var d = [dev(bt, "Live BT label", true)]
        compare(R.chip(null, d), { text: "→ Default", kind: "default" })
        compare(R.chip({ device: bt, label: "Saved" }, d), { text: "→ Live BT label", kind: "pinned" })
        compare(R.chip({ device: bt, label: "Saved" }, []), { text: "→ Saved · unplugged", kind: "unplugged" })
    }
    function test_outputRows_states_and_levels() {
        var d = [dev(spk, "Speaker", true), dev(bt, "BT", true)]
        var rows = R.outputRows({ device: bt, label: "BT" }, d, 0.7)
        compare(rows.map(function (x) { return x.state }), ["off", "pinned"])
        compare(rows.map(function (x) { return x.level }), [0, 0.7])
        compare(rows[0].glyph, "g")
        compare(R.outputRows(null, d, 0.7).map(function (x) { return x.state }), ["off", "off"])
    }
    function test_outputRows_appends_absent_pinned() {
        var rows = R.outputRows({ device: bt, label: "Saved BT" }, [dev(spk, "Speaker", true)], 0.4)
        compare(rows.length, 2)
        compare(rows[1].name, bt)
        compare(rows[1].label, "Saved BT")
        compare(rows[1].state, "unplugged")
        compare(rows[1].level, -1)
        verify(rows[1].glyph !== "")
        compare(R.rowsSig(rows), spk + "\n" + bt)
    }
}
