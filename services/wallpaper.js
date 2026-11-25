.pragma library

// Extract the wallpaper image path from `swww query` output. Each output line:
//   eDP-1: 1920x1080, scale: 1, currently displaying: image: /path/to.jpg
// Returns the first image path found, or "" if none (e.g. a solid color).
function parsePath(text) {
    var lines = (text || "").split("\n")
    var marker = "image: "
    for (var i = 0; i < lines.length; i++) {
        var idx = lines[i].indexOf(marker)
        if (idx >= 0) return lines[i].substring(idx + marker.length).trim()
    }
    return ""
}
