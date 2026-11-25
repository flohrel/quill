import QtQuick
import QtTest
import "../services/backlight.js" as B

TestCase {
    name: "backlight"
    // `ls /sys/class/backlight` output -> the device to drive (no hardcoded vendor path)
    function test_single_device() { compare(B.pickDevice("intel_backlight\n"), "intel_backlight") }
    function test_first_sorted_when_several() { compare(B.pickDevice("nvidia_0\nacpi_video0\n"), "acpi_video0") }
    function test_none() { compare(B.pickDevice(""), ""); compare(B.pickDevice("\n  \n"), "") }
    function test_paths() {
        compare(B.brightnessPath("intel_backlight"), "/sys/class/backlight/intel_backlight/brightness")
        compare(B.maxPath("intel_backlight"), "/sys/class/backlight/intel_backlight/max_brightness")
        compare(B.brightnessPath(""), "")
        compare(B.maxPath(""), "")
    }
}
