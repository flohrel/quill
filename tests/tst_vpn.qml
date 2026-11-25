import QtQuick
import QtTest
import "../services/vpn.js" as Vpn

TestCase {
    name: "vpn"

    // ---- nmcli terse parsing ----
    function test_splitTerse_plain() { compare(Vpn.splitTerse("a:b:c"), ["a", "b", "c"]) }
    function test_splitTerse_escapes() { compare(Vpn.splitTerse("my\\:vpn:1234:vpn"), ["my:vpn", "1234", "vpn"]) }
    function test_splitTerse_backslash() { compare(Vpn.splitTerse("a\\\\b:x"), ["a\\b", "x"]) }

    function test_parseProfiles_filters_types() {
        var t = "wg-b-3:u1:wireguard\nHome:u2:802-11-wireless\nlo:u3:loopback\nwork:u4:vpn\nvirbr0:u5:bridge\n"
        compare(Vpn.parseProfiles(t), [{ id: "u1", name: "wg-b-3", type: "wireguard" },
                                       { id: "u4", name: "work", type: "vpn" }])
    }
    function test_parseProfiles_colon_in_name() {
        compare(Vpn.parseProfiles("a\\:b:u9:wireguard")[0], { id: "u9", name: "a:b", type: "wireguard" })
    }
    function test_parseProfiles_empty_and_garbage() {
        compare(Vpn.parseProfiles(""), [])
        compare(Vpn.parseProfiles(undefined), [])
        compare(Vpn.parseProfiles("Error: NetworkManager is not running."), [])
    }

    function test_parseActive_maps_states() {
        compare(Vpn.parseActive("u1:activated\nu2:activating\nu3:deactivating\nu4:deactivated\n"),
                { u1: "connected", u2: "connecting", u3: "disconnecting" })
    }

    function test_mergeState() {
        var p = [{ id: "u1", name: "A", type: "wireguard" }, { id: "u2", name: "B", type: "wireguard" },
                 { id: "u3", name: "C", type: "vpn" }]
        compare(Vpn.mergeState(p, { u1: "connected" }, { u2: true }),
                [{ id: "u1", name: "A", state: "connected" }, { id: "u2", name: "B", state: "failed" },
                 { id: "u3", name: "C", state: "off" }])
    }
    function test_mergeState_active_beats_failed() {
        compare(Vpn.mergeState([{ id: "u1", name: "A" }], { u1: "connecting" }, { u1: true })[0].state, "connecting")
    }

    // ---- groups, claims, labels ----
    function g(id, name, state) { return { id: id, name: name, state: state } }

    function test_mergeGroups_claims_hide_across_backends() {
        var gs = Vpn.mergeGroups([
            { backendId: "nm", displayName: "NetworkManager", claimedIds: [], profiles: [g("u1","A","off"), g("u2","B","off")] },
            { backendId: "example", displayName: "Example", claimedIds: ["u2"], profiles: [g("p1","EX","off")] }])
        compare(gs.length, 2)
        compare(gs[0].profiles.map(function (p) { return p.id }), ["u1"])
        compare(gs[1].profiles.map(function (p) { return p.id }), ["p1"])
        compare(gs[0].backendId, "nm"); compare(gs[0].displayName, "NetworkManager")
    }
    function test_mergeGroups_own_claims_dont_hide_self() {
        var gs = Vpn.mergeGroups([{ backendId: "x", displayName: "X", claimedIds: ["u1"], profiles: [g("u1","A","off")] }])
        compare(gs[0].profiles.length, 1)
    }
    function test_mergeGroups_keeps_empty_groups() {
        compare(Vpn.mergeGroups([{ backendId: "x", displayName: "X", claimedIds: [], profiles: [] }]).length, 1)
    }
    function test_mergeGroups_skips_null() { compare(Vpn.mergeGroups([null, undefined]).length, 0) }

    function test_allProfiles_and_activeList() {
        var gs = [{ backendId: "nm", profiles: [g("a","A","connected"), g("b","B","off")] },
                  { backendId: "pr", profiles: [g("p","P","connecting")] }]
        compare(Vpn.allProfiles(gs).length, 3)
        compare(Vpn.allProfiles(gs)[2], { backendId: "pr", id: "p", name: "P", state: "connecting" })
        compare(Vpn.activeList(gs), [{ backendId: "nm", id: "a", name: "A" }])
        verify(Vpn.hasProfiles(gs)); verify(!Vpn.hasProfiles([{ backendId: "nm", profiles: [] }]))
    }

    function test_hubStatus_no_profiles() { compare(Vpn.hubStatus([], null), "No profiles") }
    function test_hubStatus_off() { compare(Vpn.hubStatus([{ profiles: [g("u1","A","off")] }], null), "Off") }
    function test_hubStatus_connected() {
        compare(Vpn.hubStatus([{ profiles: [g("u1","wg-b-3","connected")] }], null), "Connected \u00b7 wg-b-3")
    }
    function test_hubStatus_two_up() {
        compare(Vpn.hubStatus([{ profiles: [g("u1","A","connected")] }, { profiles: [g("p1","B","connected")] }], null),
                "Connected \u00b7 A +1")
    }
    function test_hubStatus_connecting() { compare(Vpn.hubStatus([{ profiles: [g("u1","A","connecting")] }], null), "Connecting\u2026") }
    function test_hubStatus_pending_counts_as_connecting() {
        compare(Vpn.hubStatus([{ profiles: [g("u1","A","disconnecting"), g("u2","B","off")] }], { backendId: "nm", id: "u2" }),
                "Connecting\u2026")
    }

    function test_rowSubline() {
        compare(Vpn.rowSubline("off"), ""); compare(Vpn.rowSubline("connected"), "Connected")
        compare(Vpn.rowSubline("connecting"), "Connecting\u2026"); compare(Vpn.rowSubline("disconnecting"), "Disconnecting\u2026")
        compare(Vpn.rowSubline("failed"), "Failed")
    }

    function test_backendUrl() {
        compare(Vpn.backendUrl("NetworkManagerBackend"), "vpn/NetworkManagerBackend.qml")
        compare(Vpn.backendUrl("../evil"), ""); compare(Vpn.backendUrl(""), ""); compare(Vpn.backendUrl("lower"), "")
        compare(Vpn.backendUrl(undefined), "")
    }

    // ---- one-at-a-time planner ----
    function grp(b, ps) { return { backendId: b, displayName: b, profiles: ps } }
    function nm(id) { return { backendId: "nm", id: id } }

    function test_plan_nothing_up_connects() {
        var p = Vpn.planToggle([grp("nm", [g("a","A","off"), g("b","B","off")])], null, "nm", "b")
        compare(p.actions, [{ op: "connect", backendId: "nm", id: "b" }]); compare(p.pending, null)
    }
    function test_plan_same_up_disconnects() {
        var p = Vpn.planToggle([grp("nm", [g("a","A","connected")])], null, "nm", "a")
        compare(p.actions, [{ op: "disconnect", backendId: "nm", id: "a" }]); compare(p.pending, null)
    }
    function test_plan_disconnect_keeps_unrelated_pending() {
        var p = Vpn.planToggle([grp("nm", [g("a","A","connected"), g("b","B","off")])], nm("b"), "nm", "a")
        compare(p.actions, [{ op: "disconnect", backendId: "nm", id: "a" }]); compare(p.pending, nm("b"))
    }
    function test_plan_switch_disconnects_then_pends() {
        var p = Vpn.planToggle([grp("nm", [g("a","B-3","connected"), g("b","AA-1","off")])], null, "nm", "b")
        compare(p.actions, [{ op: "disconnect", backendId: "nm", id: "a" }]); compare(p.pending, nm("b"))
    }
    function test_plan_switch_across_backends() {
        var p = Vpn.planToggle([grp("nm", [g("a","A","connected")]), grp("example", [g("p","P","off")])], null, "example", "p")
        compare(p.actions, [{ op: "disconnect", backendId: "nm", id: "a" }])
        compare(p.pending, { backendId: "example", id: "p" })
    }
    function test_plan_same_id_other_backend_is_distinct() {
        var p = Vpn.planToggle([grp("nm", [g("x","A","connected")]), grp("pr", [g("x","B","off")])], null, "pr", "x")
        compare(p.actions, [{ op: "disconnect", backendId: "nm", id: "x" }]); compare(p.pending, { backendId: "pr", id: "x" })
    }
    function test_plan_last_intent_wins() {
        var p = Vpn.planToggle([grp("nm", [g("a","A","disconnecting"), g("b","B","off"), g("c","C","off")])], nm("b"), "nm", "c")
        compare(p.actions, []); compare(p.pending, nm("c"))
    }
    function test_plan_toggle_pending_cancels() {
        var p = Vpn.planToggle([grp("nm", [g("a","A","disconnecting"), g("b","B","off")])], nm("b"), "nm", "b")
        compare(p.actions, []); compare(p.pending, null)
    }
    function test_plan_cancel_connecting() {
        compare(Vpn.planToggle([grp("nm", [g("a","A","connecting")])], null, "nm", "a").actions,
                [{ op: "disconnect", backendId: "nm", id: "a" }])
    }
    function test_plan_failed_reconnects() {
        compare(Vpn.planToggle([grp("nm", [g("a","A","failed")])], null, "nm", "a").actions,
                [{ op: "connect", backendId: "nm", id: "a" }])
    }
    function test_plan_two_external_up_both_disconnected_on_switch() {
        var p = Vpn.planToggle([grp("nm", [g("a","A","connected"), g("b","B","connected"), g("c","C","off")])], null, "nm", "c")
        compare(p.actions, [{ op: "disconnect", backendId: "nm", id: "a" }, { op: "disconnect", backendId: "nm", id: "b" }])
        compare(p.pending, nm("c"))
    }
    function test_plan_waits_for_disconnecting_other() {
        var p = Vpn.planToggle([grp("nm", [g("a","A","disconnecting"), g("b","B","off")])], null, "nm", "b")
        compare(p.actions, []); compare(p.pending, nm("b"))
    }

    function test_step_connects_when_clear() {
        compare(Vpn.planStep([grp("nm", [g("a","A","off"), g("b","B","off")])], nm("b")),
                { pending: null, actions: [{ op: "connect", backendId: "nm", id: "b" }] })
    }
    function test_step_waits_while_disconnecting() {
        var p = Vpn.planStep([grp("nm", [g("a","A","disconnecting"), g("b","B","off")])], nm("b"))
        compare(p.actions, []); compare(p.pending, nm("b"))
    }
    function test_step_drops_vanished_pending() {
        compare(Vpn.planStep([grp("nm", [g("a","A","off")])], nm("gone")), { pending: null, actions: [] })
    }
    function test_step_noop_without_pending() { compare(Vpn.planStep([grp("nm", [])], null), { pending: null, actions: [] }) }

    function test_switchOn() {
        verify(Vpn.switchOn("connected", false)); verify(Vpn.switchOn("connecting", false))
        verify(Vpn.switchOn("off", true)); verify(!Vpn.switchOn("failed", false))
        verify(!Vpn.switchOn("disconnecting", false)); verify(!Vpn.switchOn("off", false))
    }

    // ---- final-review fixes ----
    // #1: a just-issued action must read as busy before NM reports it.
    function test_mergeState_inflight_overlays_off() {
        var p = [{ id: "a", name: "A" }, { id: "b", name: "B" }]
        compare(Vpn.mergeState(p, {}, {}, { a: "connecting", b: "disconnecting" }).map(function (x) { return x.state }),
                ["connecting", "disconnecting"])
    }
    function test_mergeState_active_beats_inflight_and_inflight_beats_failed() {
        var p = [{ id: "a", name: "A" }, { id: "b", name: "B" }]
        compare(Vpn.mergeState(p, { a: "connected" }, { b: true }, { a: "connecting", b: "connecting" })
                    .map(function (x) { return x.state }), ["connected", "connecting"])
    }
    function test_plan_second_quick_toggle_waits_for_inflight_connect() {
        // A was just issued (in-flight overlay → "connecting"); B must not connect alongside it.
        var gs = [grp("nm", Vpn.mergeState([{ id: "a", name: "A" }, { id: "b", name: "B" }], {}, {}, { a: "connecting" }))]
        var p = Vpn.planToggle(gs, null, "nm", "b")
        compare(p.actions, [{ op: "disconnect", backendId: "nm", id: "a" }]); compare(p.pending, nm("b"))
    }
    // #2: timeout only forces the connect when nothing else is still up.
    function test_timeout_connects_when_other_stuck_disconnecting() {
        compare(Vpn.planTimeout([grp("nm", [g("a","A","disconnecting"), g("b","B","off")])], nm("b")),
                { pending: null, actions: [{ op: "connect", backendId: "nm", id: "b" }] })
    }
    function test_timeout_drops_pending_when_other_still_connected() {
        compare(Vpn.planTimeout([grp("nm", [g("a","A","connected"), g("b","B","off")])], nm("b")),
                { pending: null, actions: [] })
    }
    function test_timeout_drops_vanished_or_null_pending() {
        compare(Vpn.planTimeout([grp("nm", [g("a","A","off")])], nm("gone")), { pending: null, actions: [] })
        compare(Vpn.planTimeout([grp("nm", [])], null), { pending: null, actions: [] })
    }

    // ---- live checkpoint fixes ----
    // nmcli lists active profiles first; rows must not jump when one connects.
    function test_parseProfiles_sorted_by_name_not_activity() {
        var t = "wg-ab-2:u2:wireguard\nwg-aa-1:u1:wireguard\nwg-b-3:u3:wireguard\n"
        compare(Vpn.parseProfiles(t).map(function (p) { return p.name }),
                ["wg-aa-1", "wg-ab-2", "wg-b-3"])
    }
    // A down quill just issued must show at once, even while NM still says activated.
    function test_mergeState_inflight_disconnect_beats_stale_connected() {
        compare(Vpn.mergeState([{ id: "a", name: "A" }], { a: "connected" }, {}, { a: "disconnecting" })[0].state,
                "disconnecting")
    }
    function test_mergeState_inflight_disconnect_beats_stale_connecting() {
        compare(Vpn.mergeState([{ id: "a", name: "A" }], { a: "connecting" }, {}, { a: "disconnecting" })[0].state,
                "disconnecting")
    }

    // Pending row (queued behind a switch) says so instead of a blank sub-line.
    function test_rowSubline_pending_says_waiting() {
        compare(Vpn.rowSubline("off", true), "Waiting\u2026")
        compare(Vpn.rowSubline("failed", true), "Waiting\u2026")
        compare(Vpn.rowSubline("off", false), "")
        compare(Vpn.rowSubline("connected"), "Connected")
    }

    // #55: an `up` that quill itself cancelled (down issued mid-connect) is not a failure.
    function test_upExitFailed() {
        verify(!Vpn.upExitFailed(0, false))
        verify(Vpn.upExitFailed(4, false))      // genuine activation failure
        verify(!Vpn.upExitFailed(4, true))      // cancelled by quill's own down
        verify(!Vpn.upExitFailed(0, true))
    }
}
