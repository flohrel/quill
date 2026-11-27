import QtQuick
import QtTest
import "../services/volumes.js" as V

// Volume layers (#22): master × output → device volume, app × tab → stream
// volume; adoption, read-back of outside changes, echo tolerance, and quill
// winning on restart/reconnect — services/volumes.js.
TestCase {
    name: "volumes"

    readonly property string spk: "alsa_output.pci-0000_00_1f.3.HiFi__Speaker__sink"
    readonly property string bt: "bluez_output.00_11_22_33_44_55.1"
    readonly property string usb: "alsa_output.usb-Generic_USB_Audio-00.analog-stereo"

    function d(name, volume, muted) { return { name: name, volume: volume, muted: muted } }
    function run(st, se, devs) { return V.reconcile(st, se, devs, []) }
    function w(r, name) { return r.writes.outputs.find(function (x) { return x.name === name }) }

    // --- master and outputs
    function test_parse_defaults_and_garbage() {
        compare(V.parse("x"), V.emptyState())
        compare(V.parse(""), V.emptyState())
        compare(V.parse('{"version":2}'), V.emptyState())
        var s = V.parse('{"version":1,"master":{"level":1.7,"muted":1},"outputs":{"a":{"level":"no"},"b":{"level":0.5}},"apps":{"k":{"level":0.25},"j":{}}}')
        compare(s.master, { level: 1, muted: true })
        compare(s.outputs, { b: { level: 0.5, muted: false } })
        compare(s.apps, { k: { level: 0.25 } })
    }
    function test_first_run_adopts_device_levels_no_writes() {
        var r = run(V.emptyState(), V.newSession(), [d(spk, 0.8, false), d(bt, 0.45, false)])
        compare(r.state.outputs[spk].level, 0.8)
        compare(r.state.outputs[bt].level, 0.45)
        compare(r.writes.outputs, [])
    }
    function test_master_scales_every_output() {
        var devs = [d(spk, 0.8, false), d(bt, 0.45, false)]
        var r = run(V.emptyState(), V.newSession(), devs)
        var r2 = run(V.setMaster(r.state, 0.5), r.session, devs)
        compare(r2.writes.outputs.map(function (x) { return x.name }), [spk, bt].sort())
        fuzzyCompare(w(r2, spk).volume, 0.4, 1e-9)
        fuzzyCompare(w(r2, bt).volume, 0.225, 1e-9)
        compare(r2.state.outputs[spk].level, 0.8)
    }
    function test_echo_within_tolerance_ignored() {
        var r = run(V.setMaster(V.emptyState(), 0.5), V.newSession(), [d(spk, 0.4, false)])
        fuzzyCompare(r.state.outputs[spk].level, 0.8, 1e-9)
        var r2 = run(r.state, r.session, [d(spk, 0.405, false)])
        compare(r2.state.outputs[spk].level, r.state.outputs[spk].level)
        compare(r2.writes.outputs, [])
    }
    function test_outside_change_reads_back() {
        var r = run(V.setMaster(V.emptyState(), 0.5), V.newSession(), [d(spk, 0.4, false)])
        var r2 = run(r.state, r.session, [d(spk, 0.3, false)])
        fuzzyCompare(r2.state.outputs[spk].level, 0.6, 1e-9)
        compare(r2.state.master.level, 0.5)
        compare(r2.writes.outputs, [])
    }
    function test_outside_change_master_zero_left_alone() {
        var r = run(V.setMaster(V.emptyState(), 0), V.newSession(), [d(spk, 0, false)])
        var r2 = run(r.state, r.session, [d(spk, 0.3, false)])
        compare(r2.state.outputs[spk].level, r.state.outputs[spk].level)
        compare(r2.writes.outputs, [])
        // and the echo of that outside value doesn't start a fight either
        compare(run(r2.state, r2.session, [d(spk, 0.3, false)]).writes.outputs, [])
    }
    function test_outside_above_caps_at_one() {
        var r = run(V.setMaster(V.emptyState(), 0.5), V.newSession(), [d(spk, 0.4, false)])
        var r2 = run(r.state, r.session, [d(spk, 0.8, false)])
        compare(r2.state.outputs[spk].level, 1)
        compare(r2.writes.outputs, [])
    }
    function test_reconnect_quill_wins() {
        var r = run(V.emptyState(), V.newSession(), [d(bt, 0.45, false)])
        var gone = run(r.state, r.session, [])
        compare(gone.session.last.outputs, {})
        var back = run(gone.state, gone.session, [d(bt, 0.9, false)])
        compare(back.writes.outputs, [{ name: bt, volume: 0.45, muted: false }])
        compare(back.state.outputs[bt].level, 0.45)
    }
    function test_restart_quill_wins() {
        var saved = V.parse(V.serialize(run(V.emptyState(), V.newSession(), [d(bt, 0.45, false)]).state))
        var r = run(saved, V.newSession(), [d(bt, 0.9, false)])
        compare(r.writes.outputs, [{ name: bt, volume: 0.45, muted: false }])
    }
    function test_output_seen_later_adopts() {
        var r = run(V.setMaster(V.emptyState(), 0.5), V.newSession(), [d(spk, 0.4, false)])
        var r2 = run(r.state, r.session, [d(spk, 0.4, false), d(usb, 0.3, false)])
        fuzzyCompare(r2.state.outputs[usb].level, 0.6, 1e-9)
        compare(r2.writes.outputs, [])
    }
    function test_mute_layers_and_indicator() {
        var devs = [d(spk, 0.5, false), d(bt, 0.5, false)]
        var r = run(V.emptyState(), V.newSession(), devs)
        var m = run(V.toggleMasterMute(r.state, spk), r.session, devs)
        compare(m.writes.outputs.map(function (x) { return x.muted }), [true, true])
        verify(V.masterShownMuted(m.state, spk))
        verify(!V.toggleMasterMute(m.state, spk).master.muted)
        var om = V.toggleOutputMute(r.state, spk)
        verify(V.masterShownMuted(om, spk))
        verify(!om.master.muted)
        var both = V.toggleMasterMute(om, spk)
        verify(!both.master.muted)
        verify(!both.outputs[spk].muted)
    }
    function test_outside_unmute_recorded_while_master_muted() {
        var r = run(V.emptyState(), V.newSession(), [d(spk, 0.5, false)])
        var m = run(V.toggleMasterMute(r.state, spk), r.session, [d(spk, 0.5, false)])
        var o = run(m.state, m.session, [d(spk, 0.5, false)])
        compare(o.state.outputs[spk].muted, false)
        compare(o.writes.outputs, [{ name: spk, volume: 0.5, muted: true }])
    }
    function test_setters_unmute_their_layer() {
        var s = V.toggleOutputMute(V.toggleMasterMute(V.emptyState(), ""), spk)
        compare(s.outputs[spk], { level: 1, muted: true })
        verify(!V.setMaster(s, 0.3).master.muted)
        verify(!V.setOutput(s, spk, 0.3).outputs[spk].muted)
        verify(V.setOutput(s, spk, 0.3).master.muted)
        compare(V.outputLevel(V.emptyState(), "nope"), 1)
    }
    function test_actions_do_not_mutate() {
        var s0 = V.emptyState()
        V.setMaster(s0, 0.2)
        V.toggleOutputMute(s0, spk)
        compare(s0, V.emptyState())
    }
}
