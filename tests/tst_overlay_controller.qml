import QtQuick
import QtTest
import "../bar" as Bar

TestCase {
    name: "overlay_controller"
    Bar.OverlayController { id: c }

    function init() { c.close() }

    function test_default_is_closed() {
        compare(c.active, "")
        verify(!c.isOpen)
    }
    function test_open_sets_active() {
        c.open("calendar")
        compare(c.active, "calendar")
        verify(c.isOpen)
    }
    function test_open_replaces_active() {
        c.open("calendar")
        c.open("power")
        compare(c.active, "power")
    }
    function test_toggle_opens_then_closes() {
        c.toggle("calendar"); compare(c.active, "calendar")
        c.toggle("calendar"); compare(c.active, "")
    }
    function test_toggle_switches_between_surfaces() {
        c.open("calendar")
        c.toggle("power")
        compare(c.active, "power")
    }
    function test_close_clears() {
        c.open("controlcenter")
        c.close()
        compare(c.active, "")
    }
}
