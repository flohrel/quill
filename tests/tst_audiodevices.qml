import QtQuick
import QtTest
import "../services/audiodevices.js" as AD

// Default output/input pickers (#5): pure device filtering, labels, glyphs
// and list building from services/audiodevices.js.
TestCase {
    name: "audiodevices"

    function rec(over) {
        var r = { id: 0, name: "", description: "", nick: "", mediaClass: "",
                  deviceId: "", bus: "", iconName: "", profileName: "",
                  profileDescription: "" }
        for (var k in over) r[k] = over[k]
        return r
    }

    function test_output_needs_device_id() {
        verify(AD.isOutput(rec({ mediaClass: "Audio/Sink", deviceId: "52" })))
        verify(!AD.isOutput(rec({ mediaClass: "Audio/Sink" })))                   // virtual / null sink
        verify(!AD.isOutput(rec({ mediaClass: "Audio/Source", deviceId: "52" })))
        verify(AD.isInput(rec({ mediaClass: "Audio/Source", deviceId: "52" })))
        verify(!AD.isInput(rec({ mediaClass: "Audio/Source" })))
    }
    function test_quill_helpers_never_devices() {
        verify(!AD.isOutput(rec({ mediaClass: "Audio/Sink", deviceId: "9", name: "quill.mix.spotify" })))
    }
    function test_hdmi_is_output() {
        verify(AD.isOutput(rec({ mediaClass: "Audio/Sink", deviceId: "50", profileName: "HiFi: HDMI1: sink" })))
    }
    function test_label_fallbacks() {
        compare(AD.label(rec({ description: "USB Audio", nick: "n", name: "x" })), "USB Audio")
        compare(AD.label(rec({ description: "  ", nick: "Nick", name: "x" })), "Nick")
        compare(AD.label(rec({ name: "alsa_output.x" })), "alsa_output.x")
    }
    function test_glyphs() {
        compare(AD.glyph(rec({ mediaClass: "Audio/Source" })), "\u{F036C}")                         // microphone
        compare(AD.glyph(rec({ mediaClass: "Audio/Sink", iconName: "audio-headphones" })), "\u{F02CB}")
        compare(AD.glyph(rec({ mediaClass: "Audio/Sink", profileName: "HiFi: Headphones: sink" })), "\u{F02CB}")
        compare(AD.glyph(rec({ mediaClass: "Audio/Sink", bus: "bluetooth" })), "\u{F09A2}")
        compare(AD.glyph(rec({ mediaClass: "Audio/Sink", name: "bluez_output.00_11_22_33_44_55.1" })), "\u{F09A2}")
        compare(AD.glyph(rec({ mediaClass: "Audio/Sink", profileName: "HiFi: HDMI1: sink" })), "\u{F0379}")
        compare(AD.glyph(rec({ mediaClass: "Audio/Sink", bus: "pci", profileDescription: "Speaker" })), "\u{F0322}")
        compare(AD.glyph(rec({ mediaClass: "Audio/Sink", bus: "usb" })), "\u{F04C3}")               // generic speaker
    }
    function test_list_filters_sorts_marks_default() {
        var rs = [rec({ id: 1, mediaClass: "Audio/Sink", deviceId: "1", name: "b", description: "speaker" }),
                  rec({ id: 2, mediaClass: "Audio/Sink", deviceId: "2", name: "a", description: "Alpha" }),
                  rec({ id: 3, mediaClass: "Audio/Source", deviceId: "1", name: "m", description: "Mic" }),
                  rec({ id: 4, mediaClass: "Audio/Sink", name: "null", description: "Null" })]
        var l = AD.buildList(rs, "output", "b")
        compare(l.map(function (d) { return d.name }), ["a", "b"])
        compare(l.map(function (d) { return d.isDefault }), [false, true])
        compare(l[0].label, "Alpha")
        compare(l[0].glyph, "\u{F04C3}")
        compare(AD.buildList(rs, "input", "").map(function (d) { return d.name }), ["m"])
    }
    function test_list_ties_sort_by_name() {
        var rs = [rec({ mediaClass: "Audio/Sink", deviceId: "1", name: "z", description: "Same" }),
                  rec({ mediaClass: "Audio/Sink", deviceId: "2", name: "y", description: "same" })]
        compare(AD.buildList(rs, "output", "").map(function (d) { return d.name }), ["y", "z"])
    }
    function test_list_default_not_in_list() {
        var rs = [rec({ mediaClass: "Audio/Sink", deviceId: "1", name: "b", description: "B" })]
        verify(AD.buildList(rs, "output", "virtual-sink").every(function (d) { return !d.isDefault }))
    }
    function test_chip_label_no_default() {
        compare(AD.chipLabel(null, "output"), "No output")
        compare(AD.chipLabel(null, "input"), "No input")
        compare(AD.chipLabel(rec({ description: "USB Audio" }), "output"), "USB Audio")
    }
    function test_list_sig() {
        compare(AD.listSig([]), "")
        compare(AD.listSig([{ name: "a" }, { name: "b" }]), "a\nb")
    }
}
