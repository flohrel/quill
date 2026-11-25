.pragma library

// Backlight device selection (no hardcoded vendor path): the first entry of
// `ls /sys/class/backlight`, sorted, or "" when the machine has none.

function pickDevice(lsOutput) {
    var names = String(lsOutput || "").split("\n")
        .map(function (s) { return s.trim() })
        .filter(function (s) { return s !== "" })
        .sort()
    return names.length ? names[0] : ""
}

function brightnessPath(device) { return device ? "/sys/class/backlight/" + device + "/brightness" : "" }
function maxPath(device) { return device ? "/sys/class/backlight/" + device + "/max_brightness" : "" }
