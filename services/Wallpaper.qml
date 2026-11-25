pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "wallpaper.js" as WP

// Current wallpaper path, sourced from swww. Used by the power-menu backdrop
// (reusable by later wallpaper features). refresh() re-queries on demand.
//
// Also pre-renders a screen-sized, heavily blurred copy of the wallpaper to
// the cache dir (once per wallpaper, via ImageMagick). The power menu draws
// that file directly instead of blurring live: quickshell recreates layer-shell
// windows on every visible toggle, which forces their Images to reload on each
// open — decoding the raw wallpaper there costs ~250 ms per open (18 MP JPEG),
// the pre-blurred file ~15 ms.
Singleton {
    id: root
    property string currentPath: ""
    property string blurredPath: ""    // "" until the blur cache is ready

    function refresh() { queryProc.running = true }

    // Pre-warm at startup so the power menu's first open doesn't wait for the
    // swww round-trip + blur generation before its backdrop can appear.
    Component.onCompleted: refresh()

    Process {
        id: queryProc
        command: ["swww", "query"]
        stdout: StdioCollector {
            // Only adopt a real path; a transient query failure (empty output)
            // keeps the last known wallpaper rather than blanking the backdrop.
            onStreamFinished: {
                var p = WP.parsePath(this.text)
                if (p) {
                    root.currentPath = p
                    root.generateBlur(p)
                }
            }
        }
    }

    // Cache file is keyed by the wallpaper path (md5), so a wallpaper change
    // produces a new file name — the overlay's Image sees a new source and
    // reloads, and previous wallpapers stay cached. Delete the "power-blur-*"
    // files (or bump the size/sigma in the command) to force regeneration.
    property string pendingBlurPath: ""
    function generateBlur(src) {
        var out = Quickshell.cachePath("power-blur-" + Qt.md5(src) + ".jpg")
        if (root.blurredPath === out || root.pendingBlurPath === out) return
        root.pendingBlurPath = out
        blurProc.command = ["sh", "-c",
            '[ -f "$1" ] || magick "$0" -resize 384x216^ -gravity center -extent 384x216 -blur 0x8 -resize 1920x1080! -quality 90 "$1"',
            src, out]
        blurProc.running = true
    }

    Process {
        id: blurProc
        onExited: (exitCode) => {
            if (exitCode === 0) root.blurredPath = root.pendingBlurPath
            root.pendingBlurPath = ""
        }
    }
}
