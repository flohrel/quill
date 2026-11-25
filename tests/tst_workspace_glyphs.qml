import QtQuick
import QtTest
import "../lib/workspaces.js" as Workspaces

TestCase {
    name: "workspace_glyphs"

    readonly property var wsGlyphs: ({ "code": "\u{F121}", "web": "\u{F0AC}" })
    readonly property var appGlyphs: ({ "foot": "\u{F120}", "firefox": "\u{F269}" })

    // glyphFor: named workspaces
    function test_named_hit_returns_glyph() {
        var r = Workspaces.glyphFor("code", true, "foot", wsGlyphs, appGlyphs)
        compare(r.kind, "glyph")
        compare(r.text, "\u{F121}")
    }
    function test_named_miss_falls_back_to_label() {
        var r = Workspaces.glyphFor("mail", false, "", wsGlyphs, appGlyphs)
        compare(r.kind, "label")
        compare(r.text, "mail")
    }

    // glyphFor: dynamic workspaces
    function test_dynamic_recognized_app() {
        var r = Workspaces.glyphFor("", true, "foot", wsGlyphs, appGlyphs)
        compare(r.kind, "glyph")
        compare(r.text, "\u{F120}")
    }
    function test_dynamic_appid_case_insensitive() {
        var r = Workspaces.glyphFor("", true, "Firefox", wsGlyphs, appGlyphs)
        compare(r.text, "\u{F269}")
    }
    function test_dynamic_unrecognized_app_generic_glyph() {
        var r = Workspaces.glyphFor("", true, "gimp", wsGlyphs, appGlyphs)
        compare(r.kind, "glyph")
        compare(r.text, "\u{F2D0}")
    }
    function test_dynamic_empty_appid_generic_glyph() {
        var r = Workspaces.glyphFor("", true, "", wsGlyphs, appGlyphs)
        compare(r.kind, "glyph")
        compare(r.text, "\u{F2D0}")
    }
    function test_empty_workspace_dot() {
        var r = Workspaces.glyphFor("", false, "", wsGlyphs, appGlyphs)
        compare(r.kind, "dot")
    }

    // activeAppId
    function test_active_no_windows_returns_null() {
        compare(Workspaces.activeAppId([], 5), null)
        compare(Workspaces.activeAppId(null, 5), null)
    }
    function test_active_last_focused_wins() {
        var wins = [{ id: 1, appId: "foot" }, { id: 2, appId: "firefox" }]
        compare(Workspaces.activeAppId(wins, 2), "firefox")
    }
    function test_active_stale_id_falls_back_to_first() {
        var wins = [{ id: 1, appId: "foot" }, { id: 2, appId: "firefox" }]
        compare(Workspaces.activeAppId(wins, 99), "foot")
    }
    function test_active_missing_appid_is_empty_string() {
        compare(Workspaces.activeAppId([{ id: 1, appId: "" }], 1), "")
    }
}
