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
    // Built-in cards describe every port as "<controller> <port>", which
    // elides to the same prefix: show the port (profile description) instead.
    function test_short_label_uses_port_on_builtin_card() {
        compare(AD.shortLabel(rec({ description: "Generic HD Audio Controller Speaker",
                                    profileDescription: "Speaker" })), "Speaker")
        compare(AD.shortLabel(rec({ description: "Generic HD Audio Controller Digital Microphone",
                                    profileDescription: "Digital Microphone" })), "Digital Microphone")
    }
    function test_short_label_keeps_name_for_generic_profiles() {
        compare(AD.shortLabel(rec({ description: "Acme USB Audio Analog Stereo",
                                    profileDescription: "Analog Stereo" })), "Acme USB Audio Analog Stereo")
        compare(AD.shortLabel(rec({ description: "Acme USB Audio Mono",
                                    profileDescription: "Mono" })), "Acme USB Audio Mono")
    }
    function test_short_label_without_profile() {
        compare(AD.shortLabel(rec({ description: "BT Speaker" })), "BT Speaker")
        compare(AD.shortLabel(rec({ description: "Speaker", profileDescription: "Speaker" })), "Speaker")
        compare(AD.shortLabel(rec({ description: "", nick: "Nick", profileDescription: "Speaker" })), "Nick")
    }
    function test_chip_and_list_use_short_label() {
        var r = rec({ mediaClass: "Audio/Sink", deviceId: "1", name: "s",
                      description: "Generic HD Audio Controller Speaker", profileDescription: "Speaker" })
        compare(AD.chipLabel(r, "output"), "Speaker")
        compare(AD.buildList([r], "output", "s")[0].label, "Speaker")
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
    // --- Port availability (pw-dump): a node whose active route reports
    // available "no" (jack mic with nothing plugged) is listed but dimmed.
    function dump() {
        return [
            { id: 52, type: "PipeWire:Interface:Device",
              info: { props: { "media.class": "Audio/Device" },
                      params: { Route: [ { device: 0, available: "unknown" },
                                         { device: 1, available: "no" },
                                         { device: 2, available: "yes" } ] } } },
            { id: 70, type: "PipeWire:Interface:Node",
              info: { props: { "node.name": "builtin-mic", "device.id": 52, "card.profile.device": 0 } } },
            { id: 71, type: "PipeWire:Interface:Node",
              info: { props: { "node.name": "jack-mic", "device.id": 52, "card.profile.device": 1 } } },
            { id: 72, type: "PipeWire:Interface:Node",
              info: { props: { "node.name": "jack-out", "device.id": 52, "card.profile.device": 2 } } },
            { id: 73, type: "PipeWire:Interface:Node",
              info: { props: { "node.name": "bt-out", "device.id": 99 } } }
        ]
    }
    function test_unavailable_from_routes() {
        var u = AD.unavailableNames(dump())
        compare(Object.keys(u), ["jack-mic"])
    }
    function test_unavailable_from_text_tolerates_garbage() {
        compare(Object.keys(AD.unavailableFromText(JSON.stringify(dump()))), ["jack-mic"])
        compare(Object.keys(AD.unavailableFromText("")), [])
        compare(Object.keys(AD.unavailableFromText("not json")), [])
        compare(Object.keys(AD.unavailableFromText("{}")), [])
        compare(Object.keys(AD.unavailableNames([{ type: "PipeWire:Interface:Device", info: null }])), [])
    }
    function test_list_marks_unavailable() {
        var rs = [rec({ mediaClass: "Audio/Source", deviceId: "52", name: "builtin-mic", description: "A" }),
                  rec({ mediaClass: "Audio/Source", deviceId: "52", name: "jack-mic", description: "B" })]
        var l = AD.buildList(rs, "input", "builtin-mic", { "jack-mic": true })
        compare(l.map(function (d) { return d.available }), [true, false])
        verify(AD.buildList(rs, "input", "").every(function (d) { return d.available }))   // no map → all available
    }
    function test_list_sig() {
        compare(AD.listSig([]), "")
        compare(AD.listSig([{ name: "a" }, { name: "b" }]), "a\nb")
    }
}
