import QtQuick
import QtTest
import "../bar/overlays" as Overlays

TestCase {
    name: "power_actions"
    Overlays.PowerActions { id: pa }

    function test_five_actions_in_order() {
        compare(pa.actions.length, 5)
        compare(pa.actions[0].label, "Lock")
        compare(pa.actions[1].label, "Sleep")
        compare(pa.actions[2].label, "Restart")
        compare(pa.actions[3].label, "Shutdown")
        compare(pa.actions[4].label, "Logout")
    }
    function test_keyhints() {
        compare(pa.actions[0].keyhint, "L")
        compare(pa.actions[1].keyhint, "S")
        compare(pa.actions[2].keyhint, "R")
        compare(pa.actions[3].keyhint, "P")
        compare(pa.actions[4].keyhint, "Q")
    }
    function test_commands_are_machine_correct() {
        compare(JSON.stringify(pa.actions[0].command), JSON.stringify(["swaylock", "-f"]))
        compare(JSON.stringify(pa.actions[1].command), JSON.stringify(["loginctl", "suspend"]))
        compare(JSON.stringify(pa.actions[2].command), JSON.stringify(["loginctl", "reboot"]))
        compare(JSON.stringify(pa.actions[3].command), JSON.stringify(["loginctl", "poweroff"]))
        compare(JSON.stringify(pa.actions[4].command), JSON.stringify(["niri", "msg", "action", "quit", "--skip-confirmation"]))
    }
    function test_glyph_codepoints() {
        compare(pa.actions[0].glyph.charCodeAt(0), 0xF023)
        compare(pa.actions[1].glyph.charCodeAt(0), 0xF186)
        compare(pa.actions[2].glyph.charCodeAt(0), 0xF021)
        compare(pa.actions[3].glyph.charCodeAt(0), 0xF011)
        compare(pa.actions[4].glyph.charCodeAt(0), 0xF08B)
    }
    function test_indexForKey() {
        compare(pa.indexForKey("L"), 0)
        compare(pa.indexForKey("s"), 1)
        compare(pa.indexForKey("Q"), 4)
        compare(pa.indexForKey("z"), -1)
        compare(pa.indexForKey(""), -1)
    }
    function test_navigate_horizontal_clamps() {
        compare(pa.navigate(0, "left"), 0)
        compare(pa.navigate(0, "right"), 1)
        compare(pa.navigate(2, "right"), 3)
        compare(pa.navigate(4, "right"), 4)
    }
    function test_navigate_vertical_grid() {
        compare(pa.navigate(0, "down"), 3)
        compare(pa.navigate(1, "down"), 4)
        compare(pa.navigate(2, "down"), 4)
        compare(pa.navigate(3, "up"), 0)
        compare(pa.navigate(4, "up"), 1)
        compare(pa.navigate(0, "up"), 0)    // top row, no-op
        compare(pa.navigate(3, "down"), 3)  // bottom row, no-op
        compare(pa.navigate(4, "down"), 4)
    }
}
