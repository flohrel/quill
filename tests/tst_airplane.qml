import QtQuick
import QtTest
import "../services/airplane.js" as Air

TestCase {
    name: "airplane"

    property var off2: ({ wifi: false, bluetooth: false })
    function st(active, keepOn, saved) { return { active: active, keepOn: keepOn, saved: saved } }

    // ---- state shape / persistence ----
    function test_defaults() { compare(Air.defaults(), st(false, { wifi: false, bluetooth: false }, { wifi: true, bluetooth: true })) }
    function test_defaults_fresh_copy() { var a = Air.defaults(); a.keepOn.wifi = true; compare(Air.defaults().keepOn.wifi, false) }
    function test_normalize_garbage() {
        compare(Air.normalize(undefined), Air.defaults())
        compare(Air.normalize([1]), Air.defaults())
        compare(Air.normalize("x"), Air.defaults())
        compare(Air.normalize(null), Air.defaults())
    }
    function test_normalize_per_field() {
        var n = Air.normalize({ active: "yes", keepOn: { wifi: true }, saved: null })
        compare(n, st(false, { wifi: true, bluetooth: false }, { wifi: true, bluetooth: true }))
    }
    function test_normalize_roundtrip() {
        var s = st(true, { wifi: false, bluetooth: true }, { wifi: true, bluetooth: false })
        compare(Air.normalize(JSON.parse(JSON.stringify(s))), s)
    }

    // ---- enter ----
    function test_enter_snapshots_and_kills() {
        var r = Air.enter(Air.defaults(), { wifi: true, bluetooth: true })
        compare(r.state, st(true, off2, { wifi: true, bluetooth: true }))
        compare(r.commands, { wifi: false, bluetooth: false })
    }
    function test_enter_keeps_keepOn_radio() {
        var r = Air.enter(st(false, { wifi: false, bluetooth: true }, off2), { wifi: true, bluetooth: true })
        compare(r.commands, { wifi: false })
    }
    function test_enter_unavailable_saved_false() {
        var r = Air.enter(Air.defaults(), { wifi: null, bluetooth: true })
        compare(r.state.saved, { wifi: false, bluetooth: true })
        compare(r.commands, { bluetooth: false })
    }
    function test_enter_does_not_mutate() {
        var s = Air.defaults()
        Air.enter(s, { wifi: true, bluetooth: true })
        compare(s, Air.defaults())
    }

    // ---- exit ----
    function test_exit_restores_on_only() {
        var r = Air.exit(st(true, off2, { wifi: true, bluetooth: false }), { wifi: false, bluetooth: true })
        compare(r.state.active, false)
        compare(r.commands, { wifi: true })   // bluetooth left on, never commanded off
    }
    function test_exit_skips_unavailable() {
        compare(Air.exit(st(true, off2, { wifi: true, bluetooth: true }), { wifi: null, bluetooth: false }).commands,
                { bluetooth: true })
    }
    function test_exit_keeps_keepOn() {
        var k = { wifi: false, bluetooth: true }
        compare(Air.exit(st(true, k, off2), off2).state.keepOn, k)
    }

    function test_toggle_dispatches() {
        compare(Air.toggle(Air.defaults(), off2).state.active, true)
        compare(Air.toggle(st(true, off2, off2), off2).state.active, false)
    }

    // ---- manual changes during airplane mode ----
    function test_observed_records_during_airplane() {
        compare(Air.observed(st(true, off2, off2), "bluetooth", true, false).keepOn, { wifi: false, bluetooth: true })
    }
    function test_observed_ignored_flag() { compare(Air.observed(st(true, off2, off2), "wifi", true, true).keepOn, off2) }
    function test_observed_outside_airplane_noop() { compare(Air.observed(Air.defaults(), "wifi", true, false), Air.defaults()) }
    function test_observed_does_not_mutate() {
        var s = st(true, { wifi: false, bluetooth: false }, off2)
        Air.observed(s, "wifi", true, false)
        compare(s.keepOn.wifi, false)
    }

    // ---- readiness ----
    function test_onReady_applies_keepOn() {
        compare(Air.onReady(st(true, off2, off2), "wifi", true), { wifi: false })
        compare(Air.onReady(st(true, off2, off2), "wifi", false), {})
        compare(Air.onReady(Air.defaults(), "wifi", true), {})
        compare(Air.onReady(st(true, off2, off2), "wifi", null), {})
    }
    function test_pending_window() {
        var p = Air.markPending({}, ["wifi"], 1000, 1500)
        verify(Air.isPending(p, "wifi", 2499))
        verify(!Air.isPending(p, "wifi", 2500))
        verify(!Air.isPending(p, "bluetooth", 1000))
    }
    function test_markPending_does_not_mutate() {
        var p = {}
        Air.markPending(p, ["wifi"], 0, 1500)
        compare(p, {})
    }
    function test_ready_window_ignores_population() {
        // Startup with active: the ready-mark makes NM's late false→true an ignored change.
        var s = st(true, off2, off2), p = Air.markPending({}, ["wifi"], 0, 1500)
        compare(Air.observed(s, "wifi", true, Air.isPending(p, "wifi", 200)).keepOn, off2)
    }
    // ---- change routing: record, re-assert, or ignore ----
    function test_onChange_records_user_choice() {
        var r = Air.onChange(st(true, off2, off2), "bluetooth", true, false, false)
        compare(r.state.keepOn, { wifi: false, bluetooth: true }); compare(r.commands, {})
    }
    function test_onChange_ignored_or_unknown() {
        var s = st(true, off2, off2)
        compare(Air.onChange(s, "wifi", true, true, false), { state: s, commands: {} })
        compare(Air.onChange(s, "wifi", null, false, false), { state: s, commands: {} })
    }
    function test_onChange_settling_reasserts_not_records() {
        // Late adapter: AutoEnable powers it on after the ready window → push back to keepOn.
        var s = st(true, off2, off2), r = Air.onChange(s, "bluetooth", true, false, true)
        compare(r.state, s); compare(r.commands, { bluetooth: false })
    }
    function test_onChange_settling_matching_keepOn_noop() {
        var s = st(true, off2, off2)
        compare(Air.onChange(s, "bluetooth", false, false, true), { state: s, commands: {} })
    }
    function test_onChange_outside_airplane_noop() {
        var s = Air.defaults()
        compare(Air.onChange(s, "wifi", true, false, true), { state: s, commands: {} })
    }
    function test_refusal_resync_ignored() {
        // Exit commanded wifi on; hard block → latch resyncs to false at ~1000 ms, inside the 1500 ms window.
        var p = Air.markPending({}, ["wifi"], 0, 1500)
        verify(Air.isPending(p, "wifi", 1000))
    }
}
