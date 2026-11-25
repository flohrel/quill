import QtQuick
import Quickshell.Io
import "nmcli.js" as Nmcli

// Live IPv4/gateway/DNS for one interface, read from nmcli (Quickshell.Networking
// exposes none of these). Set `iface`, call refresh(). A failed or empty read
// leaves the dash — same convention as WifiDetails.
Item {
    id: root

    readonly property string dash: "—"
    property string iface: ""
    property string ip: dash
    property string gateway: dash
    property string dns: dash

    function refresh() {
        if (!iface) { ip = dash; gateway = dash; dns = dash; return }
        proc.running = true
    }

    Process {
        id: proc
        command: ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", root.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = Nmcli.parseDeviceShow(this.text)
                root.ip = d.ip || root.dash
                root.gateway = d.gateway || root.dash
                root.dns = d.dns || root.dash
            }
        }
    }
}
