import QtQuick
import QtTest
import "../services/wallpaper.js" as WP

TestCase {
    name: "wallpaper"

    function test_parses_image_path() {
        var sample = "eDP-1: 1920x1080, scale: 1, currently displaying: image: /home/x/wall.jpg"
        compare(WP.parsePath(sample), "/home/x/wall.jpg")
    }
    function test_returns_empty_when_no_image() {
        compare(WP.parsePath("eDP-1: currently displaying: color: 1d2021ff"), "")
    }
    function test_handles_empty_input() {
        compare(WP.parsePath(""), "")
        compare(WP.parsePath(null), "")
    }
    function test_first_of_multiple_outputs() {
        var two = "eDP-1: x image: /a/one.jpg\nHDMI-1: x image: /b/two.jpg"
        compare(WP.parsePath(two), "/a/one.jpg")
    }
    function test_trims_trailing_whitespace() {
        compare(WP.parsePath("x image: /a/sp ace.jpg  "), "/a/sp ace.jpg")
    }
}
