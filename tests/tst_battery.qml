import QtQuick
import QtTest
import "../lib/format.js" as Format

TestCase {
    name: "battery"

    // timeRemaining
    function test_timeRemaining_zero_is_empty() { compare(Format.timeRemaining(0), "") }
    function test_timeRemaining_negative_is_empty() { compare(Format.timeRemaining(-10), "") }
    function test_timeRemaining_minutes_only() { compare(Format.timeRemaining(2700), "45m") }
    function test_timeRemaining_hours_and_minutes() { compare(Format.timeRemaining(11880), "3h 18m") }
    function test_timeRemaining_exact_hour_keeps_zero_minutes() { compare(Format.timeRemaining(7200), "2h 0m") }

    // batteryGlyph — discharging buckets
    function test_glyph_full_discharging() { compare(Format.batteryGlyph(100, false), "\u{F0079}") }
    function test_glyph_68_discharging() { compare(Format.batteryGlyph(68, false), "\u{F0080}") }  // battery-70 bucket
    function test_glyph_15_discharging() { compare(Format.batteryGlyph(15, false), "\u{F007B}") }   // battery-20 bucket
    function test_glyph_4_discharging_is_alert() { compare(Format.batteryGlyph(4, false), "\u{F0083}") }
    // batteryGlyph — charging buckets
    function test_glyph_full_charging() { compare(Format.batteryGlyph(100, true), "\u{F0085}") }
    function test_glyph_60_charging_uses_60_variant() { compare(Format.batteryGlyph(60, true), "\u{F0089}") }
    function test_glyph_10_charging_uses_generic() { compare(Format.batteryGlyph(10, true), "\u{F0084}") }

    // batteryStateLabel
    function test_stateLabel_charging() { compare(Format.batteryStateLabel(1), "Charging") }
    function test_stateLabel_discharging() { compare(Format.batteryStateLabel(2), "Discharging") }
    function test_stateLabel_fully_charged() { compare(Format.batteryStateLabel(4), "Charged") }
    function test_stateLabel_pending_charge_is_charging() { compare(Format.batteryStateLabel(5), "Charging") }
    function test_stateLabel_unknown_empty() { compare(Format.batteryStateLabel(0), "") }

    // batteryStat
    function test_stat_discharging_with_time() {
        compare(Format.batteryStat(68, 2, 11880, 0), "68% · Discharging · 3h 18m until empty")
    }
    function test_stat_charging_with_time() {
        compare(Format.batteryStat(80, 1, 0, 2700), "80% · Charging · 45m until full")
    }
    function test_stat_fully_charged_no_time_clause() {
        compare(Format.batteryStat(100, 4, 0, 0), "100% · Charged")
    }
    function test_stat_unknown_time_omits_clause() {
        compare(Format.batteryStat(55, 2, 0, 0), "55% · Discharging")
    }

    // lowBattery
    function test_low_below_threshold_discharging() { verify(Format.lowBattery(19, false, 20)) }
    function test_low_at_threshold_is_false() { verify(!Format.lowBattery(20, false, 20)) }
    function test_low_above_threshold_false() { verify(!Format.lowBattery(21, false, 20)) }
    function test_low_charging_suppresses() { verify(!Format.lowBattery(5, true, 20)) }
}
