import QtQuick
import QtTest
import "../services/mixer.js" as M

TestCase {
    name: "mixer"

    function rec(over) {
        var r = { id: 0, mediaClass: "Stream/Output/Audio", binary: "", appName: "",
                  iconName: "", mediaName: "", description: "", nodeName: "",
                  volume: 0.5, muted: false }
        for (var k in over) r[k] = over[k]
        return r
    }
    function keys(groups) { return groups.map(function (g) { return g.key }) }

    function test_isPlayback_filters_capture() {
        verify(!M.isPlayback(rec({ mediaClass: "Stream/Input/Audio" })))
        verify(M.isPlayback(rec({ mediaClass: "Stream/Output/Audio" })))
        var g = M.buildGroups([rec({ id: 1, binary: "a" }),
                               rec({ id: 2, binary: "b", mediaClass: "Stream/Input/Audio" })],
                              M.newOrderState())
        compare(g.length, 1)
        compare(g[0].key, "a")
    }

    function test_group_by_binary_over_name() {
        var g = M.buildGroups([rec({ id: 1, binary: "firefox", appName: "Firefox" }),
                               rec({ id: 2, binary: "firefox", appName: "Firefox Web Browser" })],
                              M.newOrderState())
        compare(g.length, 1)
        compare(g[0].key, "firefox")
        compare(g[0].name, "Firefox")
        compare(g[0].streams.map(function (s) { return s.id }), [1, 2])
    }

    function test_fallbacks_never_empty() {
        var bare = rec({ id: 7 })
        compare(M.groupKey(bare), "stream-7")
        compare(M.displayName(bare), "Unknown")
        compare(M.streamLabel(bare, 0), "Stream 1")
        var pw = rec({ id: 8, nodeName: "pw-play" })
        compare(M.groupKey(pw), "pw-play")
        compare(M.displayName(pw), "pw-play")
    }

    function test_stream_label_prefers_media_name() {
        compare(M.streamLabel(rec({ mediaName: "YouTube — Lo-fi", description: "Playback" }), 0),
                "YouTube — Lo-fi")
        compare(M.streamLabel(rec({ description: "Playback" }), 0), "Playback")
    }

    // --- #72/#73: subtitle + fold-out rules ---
    function test_label_meaningful_tab_title() {
        verify(M.isMeaningfulLabel(rec({ mediaName: "lofi beats — YouTube" }), "Firefox"))
    }
    function test_label_not_meaningful_app_name() {
        verify(!M.isMeaningfulLabel(rec({ mediaName: "Spotify" }), "Spotify"))
        verify(!M.isMeaningfulLabel(rec({ mediaName: "  spotify " }), "Spotify"))
    }
    function test_label_not_meaningful_blank_or_generic() {
        verify(!M.isMeaningfulLabel(rec({ mediaName: "   " }), "X"))
        verify(!M.isMeaningfulLabel(rec({ mediaName: "ALSA Playback" }), "X"))
        verify(!M.isMeaningfulLabel(rec({}), "X"))
    }
    function test_subtitle_single_tab() {
        var g = M.buildGroups([rec({ id: 1, binary: "firefox-bin", mediaName: "lofi beats — YouTube" })], M.newOrderState())
        compare(g[0].subtitle, "lofi beats — YouTube")
        verify(g[0].streams[0].meaningful)
    }
    function test_subtitle_empty_when_label_is_app_name() {
        var g = M.buildGroups([rec({ id: 1, binary: "spotify", appName: "Spotify", mediaName: "Spotify" })], M.newOrderState())
        compare(g[0].subtitle, "")
    }
    function test_subtitle_browser_count() {
        var g = M.buildGroups([rec({ id: 1, binary: "firefox-bin", mediaName: "a" }),
                               rec({ id: 2, binary: "firefox-bin", mediaName: "b" })], M.newOrderState())
        compare(g[0].subtitle, "2 tabs playing")
    }
    function test_subtitle_counts_generic_streams() {
        var g = M.buildGroups([rec({ id: 1, binary: "mpv" }), rec({ id: 2, binary: "mpv" })], M.newOrderState())
        compare(g[0].subtitle, "2 streams")
        compare(g[0].streams.map(function (s) { return s.label }), ["Stream 1", "Stream 2"])
    }
    function test_isBrowser() {
        verify(M.isBrowser("firefox-bin"))
        verify(M.isBrowser("Firefox"))
        verify(!M.isBrowser("spotify"))
    }
    function test_showFoldout_per_layout() {
        var one = { streams: [{ meaningful: true }] }, oneGeneric = { streams: [{ meaningful: false }] }
        var two = { streams: [{ meaningful: false }, { meaningful: false }] }
        verify(!M.showFoldout(one, "cards"))
        verify(M.showFoldout(one, "rows"))
        verify(!M.showFoldout(oneGeneric, "rows"))
        verify(M.showFoldout(two, "cards"))
        verify(M.showFoldout(two, "rows"))
    }

    function test_group_volume_is_max() {
        var g = M.buildGroups([rec({ id: 1, binary: "a", volume: 0.2 }),
                               rec({ id: 2, binary: "a", volume: 0.7 })], M.newOrderState())
        compare(g[0].volume, 0.7)
        compare(M.groupVolume([]), 0)
    }

    function test_group_muted_requires_all() {
        compare(M.groupMuted([{ muted: true }, { muted: true }]), true)
        compare(M.groupMuted([{ muted: true }, { muted: false }]), false)
        compare(M.groupMuted([]), false)
    }

    function test_order_stable_on_removal() {
        var st = M.newOrderState()
        var A = rec({ id: 1, binary: "a" }), B = rec({ id: 2, binary: "b" }), C = rec({ id: 3, binary: "c" })
        compare(keys(M.buildGroups([A, B, C], st, 0)), ["a", "b", "c"])
        compare(keys(M.buildGroups([A, C], st, 1000)), ["a", "c"])
        compare(keys(M.buildGroups([C, A, B], st, 1000 + M.REAPPEAR_GRACE_MS + 1)), ["a", "c", "b"])
    }

    function test_new_app_appends() {
        var st = M.newOrderState()
        M.buildGroups([rec({ id: 1, binary: "a" })], st)
        compare(keys(M.buildGroups([rec({ id: 2, binary: "b" }), rec({ id: 1, binary: "a" })], st)),
                ["a", "b"])
    }

    function test_stream_order_stable_within_group() {
        var st = M.newOrderState()
        M.buildGroups([rec({ id: 5, binary: "a" }), rec({ id: 3, binary: "a" })], st)
        var g = M.buildGroups([rec({ id: 3, binary: "a" }), rec({ id: 5, binary: "a" }),
                               rec({ id: 9, binary: "a" })], st)
        compare(g[0].streams.map(function (s) { return s.id }), [5, 3, 9])
    }

    function test_tileIndex_deterministic() {
        var i = M.tileIndex("firefox", 4)
        compare(M.tileIndex("firefox", 4), i)
        verify(i >= 0 && i <= 3)
        var e = M.tileIndex("", 4)
        verify(e >= 0 && e <= 3)
    }

    function test_percent() {
        compare(M.percent(0.456), "46%")
        compare(M.percent(1.3), "100%")
        compare(M.percent(-1), "0%")
    }

    function test_app_recreated_within_grace_keeps_slot() {
        var st = M.newOrderState()
        var A = rec({ id: 1, binary: "a" }), B = rec({ id: 2, binary: "b" }), C = rec({ id: 3, binary: "c" })
        M.buildGroups([A, B, C], st, 0)
        compare(keys(M.buildGroups([A, C], st, 100)), ["a", "c"])          // B's stream torn down
        var B2 = rec({ id: 9, binary: "b" })                                 // ...and recreated
        compare(keys(M.buildGroups([A, C, B2], st, 100 + M.REAPPEAR_GRACE_MS - 1)), ["a", "b", "c"])
    }
    function test_stable_group_not_reslotted_after_long_quiet() {
        var st = M.newOrderState()
        M.buildGroups([rec({ id: 1, binary: "a" }), rec({ id: 2, binary: "b" })], st, 0)
        compare(keys(M.buildGroups([rec({ id: 1, binary: "a" }), rec({ id: 2, binary: "b" })], st, 600000)),
                ["a", "b"])
    }

    // Applies syncOps output to a copy, the way MixerPage applies it to a ListModel.
    function apply(arr, ops) {
        var a = arr.slice()
        ops.forEach(function (o) {
            if (o.op === "remove") a.splice(o.index, 1)
            else if (o.op === "insert") a.splice(o.index, 0, o.key)
            else if (o.op === "move") { var x = a.splice(o.from, 1)[0]; a.splice(o.to, 0, x) }
        })
        return a
    }
    function test_syncOps_reaches_target() {
        var cases = [ [[], ["a"]], [["a", "b", "c"], ["a", "c"]], [["a", "c"], ["a", "b", "c"]],
                      [["a", "b"], ["b", "a"]], [["a", "b", "c"], []], [["x"], ["a", "b"]] ]
        cases.forEach(function (c) { compare(apply(c[0], M.syncOps(c[0], c[1])), c[1]) })
    }
    function test_syncOps_never_removes_survivors() {
        var ops = M.syncOps(["a", "b", "c", "d"], ["a", "c", "d", "e"])
        var removed = ops.filter(function (o) { return o.op === "remove" })
        compare(removed.length, 1)
        compare(removed[0].index, 1)
        compare(M.syncOps(["a", "b"], ["a", "b"]).length, 0)
    }

    // Apps on the ALSA compat plugin (e.g. a browser with an ALSA audio backend)
    // report application.name "PipeWire ALSA [<binary>]" and media.name "ALSA Playback".
    function alsaRec(over) {
        var o = { appName: "PipeWire ALSA [firefox-bin]", mediaName: "ALSA Playback",
                  description: "ALSA Playback [firefox-bin]", nodeName: "alsa_playback.firefox-bin" }
        for (var k in over) o[k] = over[k]
        return rec(o)
    }
    function test_alsa_plugin_unwrapped_for_key_and_name() {
        compare(M.groupKey(alsaRec({ id: 1 })), "firefox-bin")
        compare(M.displayName(alsaRec({ id: 1 })), "Firefox")
    }
    function test_alsa_streams_group_with_each_other() {
        var g = M.buildGroups([alsaRec({ id: 68 }), alsaRec({ id: 74 })], M.newOrderState())
        compare(g.length, 1)
        compare(g[0].name, "Firefox")
    }
    function test_generic_alsa_label_falls_back_to_stream_n() {
        var g = M.buildGroups([alsaRec({ id: 68 }), alsaRec({ id: 74 })], M.newOrderState())
        compare(g[0].streams.map(function (s) { return s.label }), ["Stream 1", "Stream 2"])
    }
    function test_real_binary_still_wins_over_alsa_wrapper() {
        compare(M.groupKey(alsaRec({ id: 1, binary: "librewolf" })), "librewolf")
    }
    function test_plain_names_unchanged() {
        compare(M.displayName(rec({ appName: "Spotify" })), "Spotify")
        compare(M.displayName(rec({ binary: "mpv-bin" })), "mpv-bin")   // only the ALSA path is prettified
    }

    // Icon lookup order: explicit icon-name, then names derived from the app.
    function test_icon_candidates_from_binary_and_name() {
        var g = M.buildGroups([rec({ id: 1, binary: "firefox-bin", appName: "Firefox" })], M.newOrderState())
        compare(g[0].iconCandidates, ["firefox-bin", "firefox"])
    }
    function test_icon_candidates_explicit_first() {
        var g = M.buildGroups([rec({ id: 1, appName: "mpv", iconName: "mpv" })], M.newOrderState())
        compare(g[0].iconCandidates, ["mpv"])
    }
    function test_icon_candidates_from_app_name_only() {
        var g = M.buildGroups([rec({ id: 1, appName: "Google Chrome" })], M.newOrderState())
        compare(g[0].iconCandidates, ["google-chrome"])
    }
    function test_icon_candidates_alsa_wrapped() {
        var g = M.buildGroups([alsaRec({ id: 1 })], M.newOrderState())
        compare(g[0].iconCandidates, ["firefox-bin", "firefox"])
    }
    function test_icon_candidates_empty_for_bare_stream() {
        var g = M.buildGroups([rec({ id: 7 })], M.newOrderState())
        compare(g[0].iconCandidates, [])
    }

    // --- routable groups (#20)
    function test_keySource_branches() {
        compare(M.keySource(rec({ id: 1, binary: "spotify" })), "binary")
        compare(M.keySource(rec({ id: 2, appName: "PipeWire ALSA [someplayer-bin]" })), "alsa")
        compare(M.keySource(rec({ id: 3, appName: "Some App" })), "appName")
        compare(M.keySource(rec({ id: 4, nodeName: "some.node" })), "nodeName")
        compare(M.keySource(rec({ id: 5 })), "id")
    }
    function test_isRoutableSource() {
        verify(M.isRoutableSource("binary"))
        verify(M.isRoutableSource("alsa"))
        verify(M.isRoutableSource("appName"))
        verify(!M.isRoutableSource("nodeName"))
        verify(!M.isRoutableSource("id"))
    }
    function test_group_routable_flag() {
        var g = M.buildGroups([rec({ id: 1, binary: "spotify" }), rec({ id: 2, nodeName: "x.node" }),
                               rec({ id: 3 })], M.newOrderState())
        compare(g.map(function (x) { return x.routable }), [true, false, false])
    }
    function test_showFoldout_routable_single_stream() {
        var one = { routable: true, streams: [{ id: 1, label: "Stream 1", meaningful: false }] }
        verify(M.showFoldout(one, "cards"))
        verify(M.showFoldout(one, "rows"))
    }
}
