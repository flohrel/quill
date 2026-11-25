.pragma library

// PowerProfile enum mirror (Quickshell.Services.UPower PowerProfile.Enum).
// JS resources can't import QML enums, so the numeric ids are used directly —
// same approach as bluetooth.js using the numeric device.state value.
var PowerSaver = 0;
var Balanced = 1;
var Performance = 2;

function profileLabel(p) {
    switch (p) {
    case 0: return "Power Saver";
    case 1: return "Balanced";
    case 2: return "Performance";
    default: return "";
    }
}

function profileDesc(p) {
    switch (p) {
    case 0: return "Maximum battery life";
    case 1: return "Default, automatic tuning";
    case 2: return "Maximum speed, more heat";
    default: return "";
    }
}

// nf-md glyphs as \u{...} escapes (no literal PUA). Lower-confidence code
// points than the battery set — eyeball-verify they render in the running bar
// and correct any that don't (glyph choice is cosmetic).
function profileGlyph(p) {
    switch (p) {
    case 0: return "\u{F032A}";  // nf-md-leaf
    case 1: return "\u{F05D1}";  // nf-md-scale-balance
    case 2: return "\u{F04C5}";  // nf-md-speedometer
    default: return "";
    }
}
