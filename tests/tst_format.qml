import QtQuick
import QtTest
import "../lib/format.js" as Format

TestCase {
    name: "format"

    function test_clock_pads() {
        compare(Format.clock(new Date(2026, 5, 19, 9, 4)), "09:04")
        compare(Format.clock(new Date(2026, 5, 19, 14, 32)), "14:32")
    }
    function test_date_label() {
        compare(Format.dateLabel(new Date(2026, 5, 19)), "Fri 19")
    }
    function test_battery_label() {
        compare(Format.batteryLabel(76, false), "76%")
        compare(Format.batteryLabel(76, true), "⚡76%")
    }
}
