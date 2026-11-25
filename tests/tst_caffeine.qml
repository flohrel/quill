import QtQuick
import QtTest
import "../services/caffeine.js" as Caffeine

TestCase {
    name: "caffeine"

    function test_toggled_flips_false_to_true() { compare(Caffeine.toggled(false), true) }
    function test_toggled_flips_true_to_false() { compare(Caffeine.toggled(true), false) }

    function test_normalized_true_stays_true() { compare(Caffeine.normalized(true), true) }
    function test_normalized_false_stays_false() { compare(Caffeine.normalized(false), false) }
    function test_normalized_coerces_truthy() { compare(Caffeine.normalized(1), true) }
    function test_normalized_coerces_falsy() { compare(Caffeine.normalized(undefined), false) }
}
