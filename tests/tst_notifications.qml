import QtQuick
import QtTest
import "../services/notifications.js" as N

TestCase {
    name: "notifications"

    function test_urgency_mapping() { compare(N.urgencyName(0), "low"); compare(N.urgencyName(1), "normal"); compare(N.urgencyName(2), "critical"); compare(N.urgencyName(7), "normal") }
    function test_timeout_defaults() { compare(N.resolveTimeoutMs("low", -1), 3000); compare(N.resolveTimeoutMs("normal", -1), 5000); compare(N.resolveTimeoutMs("critical", -1), 0) }
    function test_timeout_zero_means_never() { compare(N.resolveTimeoutMs("normal", 0), 0); compare(N.resolveTimeoutMs("low", 0), 0) }
    function test_timeout_app_value_wins() { compare(N.resolveTimeoutMs("normal", 8000), 8000); compare(N.resolveTimeoutMs("critical", 2000), 2000) }
    // Quickshell's Notification.expireTimeout is already in ms (live check, #14:
    // notify-send -t 4000 reported 4000). Regression: it was multiplied by 1000.
    function test_app_timeout_is_ms() { compare(N.appTimeoutMs(4000), 4000); compare(N.appTimeoutMs(0), 0); compare(N.appTimeoutMs(-1), -1); compare(N.appTimeoutMs(-5), -1) }
    function test_resolve_app_timeout_end_to_end() { compare(N.resolveTimeoutMs("normal", N.appTimeoutMs(4000)), 4000) }
    function test_stack_newest_first() { compare(N.pushId(N.pushId([], 1), 2), [2, 1]) }
    function test_stack_replace_keeps_position() { compare(N.pushId([3, 2, 1], 2), [3, 2, 1]) }
    function test_stack_remove() { compare(N.removeId([3, 2, 1], 2), [3, 1]); compare(N.removeId([1], 9), [1]) }
    function test_stack_cap_hides_oldest() { compare(N.visibleIds([6, 5, 4, 3, 2, 1], 5), [6, 5, 4, 3, 2]) }
    function test_stack_cap_slot_frees() { compare(N.visibleIds(N.removeId([6, 5, 4, 3, 2, 1], 4), 5), [6, 5, 3, 2, 1]) }
    function test_owner_parse() { compare(N.ownerFromBusctl("BusName=:1.4\nComm=dunst\nPID=12\n"), "dunst"); compare(N.ownerFromBusctl(""), "") }
    // Quickshell's process-wide server re-registers by itself when the owner
    // leaves, so a free name is transient: probe again, bounded (#14 review C1).
    function test_reclaim_free_name_retries() { compare(N.reclaimAction("", 0, 5), "retry") }
    // No owner found after max probes (busctl missing, or our process shows
    // under another name): unknown, NOT "another daemon owns it".
    function test_reclaim_free_name_unknown_after_max() { compare(N.reclaimAction("", 5, 5), "unknown") }
    // DND UI only makes sense while quill is (or may be) the daemon.
    function test_dnd_available() {
        verify(N.dndAvailable(true, false))
        verify(!N.dndAvailable(true, true))
        verify(!N.dndAvailable(false, false))
    }
    function test_reclaim_never_kills_another_daemon() {
        compare(N.reclaimAction("dunst", 0, 5), "giveup")
        compare(N.reclaimAction("other-daemon", 0, 5), "giveup")
    }
    function test_reclaim_gives_up_after_max() { compare(N.reclaimAction("dunst", 5, 5), "giveup") }
    function test_reclaim_ours_is_done() { compare(N.reclaimAction("qs", 0, 5), "done"); compare(N.reclaimAction("quickshell", 0, 5), "done") }
    function test_reclaim_never_kills_stranger() { compare(N.reclaimAction("dunst", 0, 5), "giveup") }
    // Service-side countdown (#14 review I1): one ticker over the visible,
    // non-hovered ids; 0-timeout (never) ids are not in the map.
    function test_tick_counts_down_visible() { var r = N.tick({1: 3000, 2: 5000}, [1, 2], {}, 100); compare(r.remaining, {1: 2900, 2: 4900}); compare(r.expired, []) }
    function test_tick_skips_hovered() { var r = N.tick({1: 3000}, [1], {1: true}, 100); compare(r.remaining, {1: 3000}) }
    function test_tick_skips_hidden_beyond_cap() { var r = N.tick({1: 3000, 2: 3000}, [2], {}, 100); compare(r.remaining, {1: 3000, 2: 2900}) }
    function test_tick_reports_expired() { var r = N.tick({1: 50, 2: 5000}, [1, 2], {}, 100); compare(r.expired, [1]); compare(r.remaining[2], 4900); verify(r.remaining[1] === undefined) }
    function test_tick_ignores_untimed_visible() { var r = N.tick({}, [7], {}, 100); compare(r.remaining, {}); compare(r.expired, []) }
    function test_popup_screen_focused() { compare(N.popupScreen("DP-1", ["eDP-1", "DP-1"]), "DP-1") }
    function test_popup_screen_fallback() { compare(N.popupScreen("", ["eDP-1", "DP-1"]), "eDP-1"); compare(N.popupScreen("HDMI-9", ["eDP-1"]), "eDP-1"); compare(N.popupScreen("", []), "") }
    // DND gate (#15): critical breaks through; the rest is held.
    function test_dnd_off_everything_pops() { verify(N.shouldPopup("low", false)); verify(N.shouldPopup("normal", false)); verify(N.shouldPopup("critical", false)) }
    function test_dnd_on_holds_low_normal() { verify(!N.shouldPopup("low", true)); verify(!N.shouldPopup("normal", true)) }
    function test_dnd_on_critical_breaks_through() { verify(N.shouldPopup("critical", true)) }
    // Held (DND) notifications must always expire (#15 review I1): an app
    // timeout of 0 ("never") falls back to the urgency default while held.
    function test_held_timeout_zero_uses_default() { compare(N.heldTimeoutMs("normal", 0), 5000); compare(N.heldTimeoutMs("low", 0), 3000) }
    function test_held_timeout_keeps_resolved() { compare(N.heldTimeoutMs("normal", 8000), 8000); compare(N.heldTimeoutMs("low", 3000), 3000) }
    // Shared ticker set (#15 review M2): visible cards plus held ids.
    function test_ticking_ids_include_held() { compare(N.tickingIds([3, 2, 1], 5, {9: true}), [3, 2, 1, 9]) }
    function test_ticking_ids_respect_cap() { var t = N.tickingIds([6, 5, 4, 3, 2, 1], 5, {}); verify(t.indexOf(1) === -1); compare(t, [6, 5, 4, 3, 2]) }
    function test_ticking_ids_no_duplicates() { compare(N.tickingIds([2, 1], 5, {1: true}), [2, 1]) }

    // #65 duplicate collapse
    function test_dupKey_equal_for_identical() {
        compare(N.dupKey("Build Tool", "Build Tool", "Waiting", "normal"),
                N.dupKey("Build Tool", "Build Tool", "Waiting", "normal"))
    }
    function test_dupKey_differs_per_field() {
        var k = N.dupKey("a", "s", "b", "normal")
        verify(N.dupKey("x", "s", "b", "normal") !== k)
        verify(N.dupKey("a", "x", "b", "normal") !== k)
        verify(N.dupKey("a", "s", "x", "normal") !== k)
        verify(N.dupKey("a", "s", "b", "critical") !== k)
    }
    function test_dupKey_delimiter_safe() {
        verify(N.dupKey("a|b", "c", "", "normal") !== N.dupKey("a", "b|c", "", "normal"))
    }
    function test_dupKey_nullish() {
        compare(N.dupKey(undefined, null, "", "low"), N.dupKey("", "", "", "low"))
    }
    function test_findDuplicate() {
        var k = N.dupKey("a", "s", "b", "normal"), k2 = N.dupKey("z", "s", "b", "normal")
        var m = { 3: k, 5: k2 }
        compare(N.findDuplicate(m, k, 9), 3)
        compare(N.findDuplicate(m, k, 3), -1)
        compare(N.findDuplicate(m, "x", 9), -1)
    }
    function test_foldCount() {
        compare(N.foldCount(undefined), 2)
        compare(N.foldCount(2), 3)
    }
    function test_planCollapse_card_to_card() {
        compare(N.planCollapse(false, true), { pop: true, countHeld: false, unholdOld: false })
    }
    function test_planCollapse_held_to_held() {
        compare(N.planCollapse(true, false), { pop: false, countHeld: false, unholdOld: true })
    }
    function test_planCollapse_card_to_held() {
        compare(N.planCollapse(false, false), { pop: false, countHeld: true, unholdOld: false })
    }
    function test_planCollapse_held_to_card() {
        compare(N.planCollapse(true, true), { pop: true, countHeld: false, unholdOld: true })
    }
    // Countdown indicator (#67).
    function test_fraction_basic() { compare(N.countdownFraction(2500, 5000), 0.5) }
    function test_fraction_clamped() { compare(N.countdownFraction(6000, 5000), 1); compare(N.countdownFraction(-10, 5000), 0); compare(N.countdownFraction(0, 5000), 0) }
    function test_fraction_never_expires() { compare(N.countdownFraction(100, 0), 0) }
    function test_style_passthrough() { compare(N.countdownStyle("bar", false, 5000), "bar"); compare(N.countdownStyle("border", false, 5000), "border"); compare(N.countdownStyle("none", false, 5000), "none") }
    function test_style_unknown_is_none() { compare(N.countdownStyle("ring", false, 5000), "none"); compare(N.countdownStyle(undefined, false, 5000), "none") }
    function test_style_never_expires() { compare(N.countdownStyle("bar", false, 0), "none") }
    function test_style_critical_with_timeout() { compare(N.countdownStyle("border", true, 2000), "none") }
    function test_perimeter() { fuzzyCompare(N.roundedRectPerimeter(100, 50, 0), 300, 1e-9); fuzzyCompare(N.roundedRectPerimeter(100, 50, 10), 300 - 80 + 20 * Math.PI, 1e-9) }
    function test_perimeter_radius_clamped() { fuzzyCompare(N.roundedRectPerimeter(40, 20, 50), N.roundedRectPerimeter(40, 20, 10), 1e-9) }

    // #70: a duplicate takeover re-points the existing card's row instead of
    // removing + inserting it, so the card (delegate) survives the bump.
    function test_takeover_retargets_row_in_place() {
        compare(N.takeoverOps([7, 4, 2], 4, 9), [{ op: "set", index: 1, nid: 9 }, { op: "move", from: 1, to: 0 }])
    }
    function test_takeover_top_row_needs_no_move() {
        compare(N.takeoverOps([4, 2], 4, 9), [{ op: "set", index: 0, nid: 9 }])
    }
    function test_takeover_never_removes_the_card() {
        var ops = N.takeoverOps([7, 4, 2], 4, 9)
        verify(ops.every(function (o) { return o.op !== "remove" && o.op !== "insert" }))
    }
    function test_takeover_old_without_card_inserts() {
        compare(N.takeoverOps([7, 2], 4, 9), [{ op: "insert", index: 0, nid: 9 }])
    }
}
