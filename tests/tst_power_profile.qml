import QtQuick
import QtTest
import "../services/power.js" as Power

TestCase {
    name: "power_profile"

    function test_label_saver()   { compare(Power.profileLabel(0), "Power Saver") }
    function test_label_balanced(){ compare(Power.profileLabel(1), "Balanced") }
    function test_label_perf()    { compare(Power.profileLabel(2), "Performance") }
    function test_label_unknown() { compare(Power.profileLabel(9), "") }

    function test_desc_saver()    { compare(Power.profileDesc(0), "Maximum battery life") }
    function test_desc_balanced() { compare(Power.profileDesc(1), "Default, automatic tuning") }
    function test_desc_perf()     { compare(Power.profileDesc(2), "Maximum speed, more heat") }

    function test_glyph_saver()   { compare(Power.profileGlyph(0), "\u{F032A}") }
    function test_glyph_balanced(){ compare(Power.profileGlyph(1), "\u{F05D1}") }
    function test_glyph_perf()    { compare(Power.profileGlyph(2), "\u{F04C5}") }

    function test_constants()     { compare(Power.PowerSaver, 0); compare(Power.Balanced, 1); compare(Power.Performance, 2) }
}
