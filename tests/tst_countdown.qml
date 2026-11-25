import QtQuick
import QtTest
import "../bar/notifications"
import "../services/notifications.js" as N

// Countdown indicator components (#67). They are pure QtQuick (no qs.*
// imports), so they load here without Quickshell.
TestCase {
    name: "countdown"
    when: windowShown

    Item { id: root; width: 400; height: 200 }
    Component { id: barC; CountdownBar {} }
    Component { id: fracC; CountdownFraction {} }
    Component { id: borderC; CountdownBorder {} }

    function test_bar_width() {
        var b = createTemporaryObject(barC, root, {width: 380, height: 80, fraction: 0.5, inset: 16})
        compare(b.fill.width, (380 - 32) * 0.5)
        compare(b.fill.x, 16)
        compare(b.fill.height, 2)
        compare(b.fill.y, 80 - 1 - 2)
    }
    function test_bar_hidden_at_zero() {
        var b = createTemporaryObject(barC, root, {width: 380, height: 80, fraction: 0, inset: 16})
        verify(!b.fill.visible)
    }
    function test_snap_up() {
        var f = createTemporaryObject(fracC, root, {target: 0.3})
        compare(f.value, 0.3)
        f.target = 1.0
        compare(f.value, 1.0)   // immediately, no animation
    }
    function test_animates_down() {
        var f = createTemporaryObject(fracC, root, {target: 1.0})
        f.target = 0.5
        verify(f.value > 0.5)
        tryCompare(f, "value", 0.5, 500)
    }

    // Border look: the inset rect is (w-1) x (h-1) with radius 16 - 0.5.
    function test_border_perimeter() {
        var s = createTemporaryObject(borderC, root, {width: 380, height: 80, radius: 16, fraction: 1})
        fuzzyCompare(s.perimeter, N.roundedRectPerimeter(379, 79, 15.5), 1e-6)
    }
    function test_border_dash_tracks_fraction() {
        var s = createTemporaryObject(borderC, root, {width: 380, height: 80, radius: 16, fraction: 0.25})
        fuzzyCompare(s.data[0].dashPattern[0], 0.25 * s.perimeter, 1e-6)
    }
    function test_border_hidden_at_zero() {
        var s = createTemporaryObject(borderC, root, {width: 380, height: 80, radius: 16, fraction: 0})
        verify(!s.visible)
    }
    function test_border_tracks_height() {
        var s = createTemporaryObject(borderC, root, {width: 380, height: 80, radius: 16, fraction: 1})
        var p = s.perimeter
        s.height = 140
        fuzzyCompare(s.perimeter, p + 120, 1e-6)
    }
}
