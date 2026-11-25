.pragma library

function pad2(n) { return (n < 10 ? "0" : "") + n; }

function clock(date) {
    return pad2(date.getHours()) + ":" + pad2(date.getMinutes());
}

var DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
function dateLabel(date) {
    return DAYS[date.getDay()] + " " + pad2(date.getDate());
}

function batteryLabel(percent, charging) {
    return (charging ? "⚡" : "") + Math.round(percent) + "%";
}

// Seconds -> "3h 18m" / "45m" / "" (empty when unknown/zero). When hours > 0
// the minutes are always shown, including zero ("2h 0m").
function timeRemaining(seconds) {
    if (!seconds || seconds <= 0) return "";
    var mins = Math.round(seconds / 60);
    var h = Math.floor(mins / 60);
    var m = mins % 60;
    if (h > 0) return h + "h " + m + "m";
    return m + "m";
}

// nf-md battery glyph bucketed by charge level. Code points are the \u{...}
// escapes (literal PUA is unreliable in the editing tools — see bluetooth.js).
// Discharging: battery / battery-90..battery-10 / battery-alert.
// Charging: the MDI charging set omits the 10/50/70 steps, so map to the
// nearest available variant.
function batteryGlyph(percent, charging) {
    var p = percent;
    if (charging) {
        if (p >= 95) return "\u{F0085}";  // battery-charging-100
        if (p >= 85) return "\u{F008B}";  // battery-charging-90
        if (p >= 75) return "\u{F008A}";  // battery-charging-80
        if (p >= 55) return "\u{F0089}";  // battery-charging-60
        if (p >= 35) return "\u{F0088}";  // battery-charging-40
        if (p >= 25) return "\u{F0087}";  // battery-charging-30
        if (p >= 15) return "\u{F0086}";  // battery-charging-20
        return "\u{F0084}";               // battery-charging (generic)
    }
    if (p >= 95) return "\u{F0079}";  // battery (full)
    if (p >= 85) return "\u{F0082}";  // battery-90
    if (p >= 75) return "\u{F0081}";  // battery-80
    if (p >= 65) return "\u{F0080}";  // battery-70
    if (p >= 55) return "\u{F007F}";  // battery-60
    if (p >= 45) return "\u{F007E}";  // battery-50
    if (p >= 35) return "\u{F007D}";  // battery-40
    if (p >= 25) return "\u{F007C}";  // battery-30
    if (p >= 15) return "\u{F007B}";  // battery-20
    if (p >= 5)  return "\u{F007A}";  // battery-10
    return "\u{F0083}";               // battery-alert (<5%)
}

// UPowerDeviceState (Unknown=0, Charging=1, Discharging=2, Empty=3,
// FullyCharged=4, PendingCharge=5, PendingDischarge=6) -> caption word.
function batteryStateLabel(state) {
    switch (state) {
    case 1: case 5: return "Charging";
    case 2: case 6: return "Discharging";
    case 4: return "Charged";
    case 3: return "Empty";
    default: return "";
    }
}

// Popup stat line: "68% · Discharging · 3h 18m until empty". Picks the time
// source by charge direction and omits the time clause when unknown or full.
function batteryStat(percent, state, timeToEmpty, timeToFull) {
    var parts = [Math.round(percent) + "%"];
    var word = batteryStateLabel(state);
    if (word !== "") parts.push(word);
    var charging = (state === 1 || state === 5);
    var t = timeRemaining(charging ? timeToFull : timeToEmpty);
    if (t !== "" && state !== 4) {
        parts.push(t + (charging ? " until full" : " until empty"));
    }
    return parts.join(" · ");
}

// True when the battery is low enough to warrant the warning color and not
// charging. Threshold passed in (Config.battery.lowThreshold) to stay pure.
function lowBattery(percent, charging, threshold) {
    return !charging && percent < threshold;
}
