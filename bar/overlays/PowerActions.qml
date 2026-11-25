import QtQuick

// Power-menu data + pure navigation logic (no UI), so it is unit-testable.
// `actions` is the single source of truth: order, labels, hotkeys, glyphs, and
// the machine-specific shell commands. Glyphs are Symbols Nerd Font PUA chars,
// byte-injected (see plan) because the file tools strip PUA codepoints.
QtObject {
    readonly property var actions: [
        { "label": "Lock",     "keyhint": "L", "glyph": "",     "command": ["swaylock", "-f"] },
        { "label": "Sleep",    "keyhint": "S", "glyph": "",    "command": ["loginctl", "suspend"] },
        { "label": "Restart",  "keyhint": "R", "glyph": "",  "command": ["loginctl", "reboot"] },
        { "label": "Shutdown", "keyhint": "P", "glyph": "", "command": ["loginctl", "poweroff"] },
        { "label": "Logout",   "keyhint": "Q", "glyph": "",   "command": ["niri", "msg", "action", "quit", "--skip-confirmation"] }
    ]

    // Case-insensitive hotkey letter -> action index, or -1.
    function indexForKey(key) {
        if (!key) return -1
        var k = key.toLowerCase()
        for (var i = 0; i < actions.length; i++)
            if (actions[i].keyhint.toLowerCase() === k) return i
        return -1
    }

    // 3+2 grid navigation. Indices 0,1,2 = top row; 3,4 = bottom row.
    function navigate(i, dir) {
        if (dir === "left")  return Math.max(0, i - 1)
        if (dir === "right") return Math.min(4, i + 1)
        if (dir === "down")  return (i === 0) ? 3 : ((i === 1 || i === 2) ? 4 : i)
        if (dir === "up")    return (i === 3) ? 0 : ((i === 4) ? 1 : i)
        return i
    }
}
