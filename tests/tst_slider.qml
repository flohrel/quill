import QtQuick
import QtTest
import "../bar/overlays/slider.js" as S

TestCase {
    name: "slider"
    function test_fraction_basic() {
        compare(S.fraction(0, 100), 0)
        compare(S.fraction(50, 100), 0.5)
        compare(S.fraction(100, 100), 1)
    }
    function test_fraction_clamps() {
        compare(S.fraction(150, 100), 1)
        compare(S.fraction(-10, 100), 0)
    }
    function test_zero_width_safe() {
        compare(S.fraction(50, 0), 0)
    }
    function test_fraction_inset_maps_inner_span() {
        compare(S.fraction(7, 114, 7), 0)
        compare(S.fraction(57, 114, 7), 0.5)
        compare(S.fraction(107, 114, 7), 1)
    }
    function test_fraction_inset_ends() {
        compare(S.fraction(0, 114, 7), 0)
        compare(S.fraction(3, 114, 7), 0)
        compare(S.fraction(114, 114, 7), 1)
        compare(S.fraction(111, 114, 7), 1)
    }
    function test_fraction_inset_degenerate() {
        compare(S.fraction(5, 10, 7), 0)
    }
    function test_fraction_default_inset_unchanged() {
        compare(S.fraction(50, 100), 0.5)
    }
    function test_knobCenter() {
        compare(S.knobCenter(0, 114, 7), 7)
        compare(S.knobCenter(1, 114, 7), 107)
        compare(S.knobCenter(0.5, 114, 7), 57)
        compare(S.knobCenter(2, 114, 7), 107)
    }
    function test_displayValue_holds_while_pressed() {
        compare(S.displayValue(true, 0.8, 0.3), 0.8)
    }
    function test_displayValue_follows_backend_when_released() {
        compare(S.displayValue(false, 0.8, 0.3), 0.3)
    }
    function test_displayValue_clamps() {
        compare(S.displayValue(true, 1.4, 0), 1)
        compare(S.displayValue(false, 0, -0.2), 0)
    }
}
