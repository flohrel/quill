pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config   // qmllint disable import
import "backlight.js" as B

Singleton {
    id: root
    property int max: 1
    property int current: 0
    readonly property real fraction: max > 0 ? current / max : 0
    // First device under /sys/class/backlight (B.pickDevice); "" = none, the
    // slider then stays at 0 and brightnessctl does nothing harmful.
    property string device: ""
    readonly property bool available: device !== ""

    Process {
        running: true
        command: ["ls", "/sys/class/backlight"]
        stdout: StdioCollector { onStreamFinished: { root.device = B.pickDevice(this.text); root.refresh() } }
    }

    // blockAllReads (not just blockLoading): reload() is async, so without it
    // text() right after reload() returns the PREVIOUS content and every
    // refresh publishes a value one event behind.
    FileView { id: curFile; path: B.brightnessPath(root.device); blockLoading: true; blockAllReads: true }
    FileView { id: maxFile; path: B.maxPath(root.device); blockLoading: true; blockAllReads: true }

    function refresh() {
        if (!root.available) return
        curFile.reload(); maxFile.reload()
        root.max = parseInt(maxFile.text().trim()) || 1
        root.current = parseInt(curFile.text().trim()) || 0
    }

    function setFraction(f) {
        var pct = Math.round(Math.max(0, Math.min(1, f)) * 100)
        setProc.command = ["brightnessctl", "set", pct + "%"]
        setProc.running = true
    }

    Process { id: setProc; onExited: root.refresh() }

    // The kernel backlight core emits a KOBJ_CHANGE uevent on every brightness
    // write — including the brightnessctl runs spawned by niri's XF86MonBrightness
    // binds — so refresh on events instead of waiting out the poll. stdbuf forces
    // line-buffering so events arrive immediately through the pipe. The timer
    // below stays as a fallback in case this process dies.
    Process {
        running: true
        command: ["stdbuf", "-oL", "udevadm", "monitor", "-k", "-s", "backlight"]
        stdout: SplitParser { onRead: (line) => { if (line.includes("change")) root.refresh() } }
    }

    Timer { interval: Config.intervals.brightness; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
