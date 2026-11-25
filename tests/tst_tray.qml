import QtQuick
import QtTest
import "../lib/tray.js" as Tray

TestCase {
    name: "tray"

    readonly property var spotifyArgv: ["niri-scratchpad", "--size", "70x75", "--pos", "center", "Spotify", "spotify"]

    function cfg(scriptAvailable) {
        return {
            aliases: { "spotify-client": "Spotify" },
            scratchpads: { "spotify": spotifyArgv },
            reopenMenu: { "spotify-client": "Show Spotify", "steam": "Library" },
            excluded: ["secrets-app"],
            scriptAvailable: scriptAvailable !== false
        }
    }
    function resolve(id, wins, c) {
        return Tray.resolveTrayAction(id, wins, 1, 4, c || cfg())
    }

    function test_case_insensitive_match() {
        var r = resolve("Steam", [{ id: 7, appId: "steam", workspaceId: 3 }])
        compare(r.kind, "focus")
        compare(r.windowId, 7)
    }
    function test_alias_scratchpad_hit() {
        var r = resolve("spotify-client", [{ id: 2, appId: "Spotify", workspaceId: 4 }])
        compare(r.kind, "scratchpad")
        compare(r.argv, spotifyArgv)
    }
    function test_scratchpad_on_both_workspaces() {
        var r = resolve("spotify-client", [{ id: 2, appId: "Spotify", workspaceId: 4 },
                                            { id: 3, appId: "Spotify", workspaceId: 1 }])
        compare(r.kind, "scratchpad")
    }
    function test_scratchpad_no_window_reopens() {
        var r = resolve("spotify-client", [])
        compare(r.kind, "reopen")
        compare(r.menuLabel, "Show Spotify")
        compare(r.appId, "spotify")
        compare(r.argv[1], "--show")
    }
    function test_scratchpad_no_window_script_missing() {
        var r = resolve("spotify-client", [], cfg(false))
        compare(r.kind, "reopen")
        compare(r.argv, null)
    }
    function test_nonscratch_no_window_reopens() {
        var r = resolve("steam", [])
        compare(r.kind, "reopen")
        compare(r.menuLabel, "Library")
        compare(r.argv, null)
    }
    function test_script_missing_scratch_window() {
        var r = resolve("spotify-client", [{ id: 2, appId: "Spotify", workspaceId: 4 }], cfg(false))
        compare(r.kind, "activate")
    }
    function test_unconfigured_only_on_scratch() {
        compare(resolve("notes-app", [{ id: 2, appId: "notes-app", workspaceId: 4 }]).kind, "activate")
    }
    function test_prefers_focused_workspace() {
        var r = resolve("steam", [{ id: 5, appId: "steam", workspaceId: 3 },
                                   { id: 9, appId: "steam", workspaceId: 1 }])
        compare(r.kind, "focus")
        compare(r.windowId, 9)
    }
    function test_prefers_highest_id() {
        var r = resolve("steam", [{ id: 5, appId: "steam", workspaceId: 3 },
                                   { id: 9, appId: "steam", workspaceId: 2 }])
        compare(r.windowId, 9)
    }
    function test_no_window_no_reopen_entry_activate() {
        compare(resolve("qbittorrent", []).kind, "activate")
    }
    function test_unknown_id_activate() {
        compare(resolve("nothing", [{ id: 1, appId: "foot", workspaceId: 1 }]).kind, "activate")
    }
    function test_excluded_activate() {
        compare(resolve("Secrets-App", [{ id: 1, appId: "secrets-app", workspaceId: 1 }]).kind, "activate")
    }
    function test_empty_id_activate() {
        compare(resolve("", []).kind, "activate")
        compare(resolve(undefined, []).kind, "activate")
    }
    function test_empty_appid_never_matches() {
        compare(resolve("x", [{ id: 3, appId: "", workspaceId: 1 }]).kind, "activate")
    }
    function test_withShow_inserts_and_idempotent() {
        var once = Tray.withShow(["niri-scratchpad", "a", "b"])
        compare(once, ["niri-scratchpad", "--show", "a", "b"])
        compare(Tray.withShow(once), once)
    }

    // --- reopen follow-up helpers ---
    function test_findMenuEntry_exact_label() {
        var entries = [{ text: "Show Spotify" }, { text: "Minimize to Tray" }, { text: "Exit" }]
        compare(Tray.findMenuEntry(entries, "Exit"), entries[2])
        compare(Tray.findMenuEntry(entries, "exit"), null)
        compare(Tray.findMenuEntry([], "Exit"), null)
        compare(Tray.findMenuEntry(null, "Exit"), null)
    }
    function test_pendingOutcome_waits_without_window() {
        var p = { appId: "spotify", argv: null }
        compare(Tray.pendingOutcome(p, [{ id: 1, appId: "foot", workspaceId: 1 }], 4), null)
    }
    function test_pendingOutcome_argv_shows() {
        var argv = ["niri-scratchpad", "--show", "Spotify", "spotify"]
        var r = Tray.pendingOutcome({ appId: "spotify", argv: argv },
                                    [{ id: 2, appId: "Spotify", workspaceId: 1 }], 4)
        compare(r.kind, "exec")
        compare(r.argv, argv)
    }
    function test_pendingOutcome_focuses_case_insensitive() {
        var r = Tray.pendingOutcome({ appId: "steam", argv: null },
                                    [{ id: 6, appId: "Steam", workspaceId: 3 }], 4)
        compare(r.kind, "focus")
        compare(r.windowId, 6)
    }
    function test_pendingOutcome_on_scratch_does_nothing() {
        var r = Tray.pendingOutcome({ appId: "steam", argv: null },
                                    [{ id: 6, appId: "steam", workspaceId: 4 }], 4)
        compare(r.kind, "none")
    }
}
