pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "nmcli.js" as Nmcli

// Read-only per-network detail sourced from nmcli (Quickshell.Networking exposes no
// ipv4/gateway/dns/metered/method). load(net) kicks off reads; clear() resets. Every
// field defaults to dash; a failed/empty read leaves the dash (mirrors Wallpaper.qml).
Singleton {
    id: root

    readonly property string dash: "—"   // —
    property var net: null
    property string _profile: ""

    property string security: dash
    property string signal: dash
    property string status: dash
    property string ip: dash
    property string gateway: dash
    property string dns: dash
    property string ipv4Method: dash
    property string autoconnect: dash
    property string metered: dash

    function clear() {
        net = null; _profile = ""
        security = dash; signal = dash; status = dash
        ip = dash; gateway = dash; dns = dash
        ipv4Method = dash; autoconnect = dash; metered = dash
    }

    function load(n) {
        clear()
        if (!n) return
        net = n
        // Live fields straight off the WifiNetwork — no nmcli needed.
        security = n.security === 0 ? "Open" : "Secured"   // refined by keyMgmt below
        signal = Nmcli.signalLabel(n.signalStrength) || dash
        status = n.connected ? "Connected" : (n.known ? "Saved" : "Available")
        resolveProc.running = true                          // → profile → saved settings
        if (n.connected) deviceProc.running = true          // live ip/gw/dns
    }

    // 1) list profiles → resolve the profile name for our SSID
    Process {
        id: resolveProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.net) return
                root._profile = Nmcli.resolveProfile(this.text, root.net.name)
                if (root._profile) connProc.running = true
            }
        }
    }

    // 2) read saved settings for the resolved profile
    Process {
        id: connProc
        command: ["nmcli", "-t", "-f",
                  "connection.autoconnect,connection.metered,ipv4.method,802-11-wireless-security.key-mgmt",
                  "connection", "show", root._profile]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.net) return
                var c = Nmcli.parseConnectionShow(this.text)
                root.autoconnect = Nmcli.autoconnectLabel(c.autoconnect) || root.dash
                root.metered = Nmcli.meteredLabel(c.metered) || root.dash
                root.ipv4Method = Nmcli.ipv4MethodLabel(c.ipv4Method) || root.dash
                var sec = Nmcli.keyMgmtLabel(c.keyMgmt)
                if (sec) root.security = sec               // refine Open/Secured → WPA2/…
            }
        }
    }

    // 3) live IP/gateway/DNS from the device (connected only)
    Process {
        id: deviceProc
        command: ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.STATE",
                  "device", "show",
                  (root.net && root.net.device) ? root.net.device.name : ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.net) return
                var d = Nmcli.parseDeviceShow(this.text)
                root.ip = d.ip || root.dash
                root.gateway = d.gateway || root.dash
                root.dns = d.dns || root.dash
            }
        }
    }
}
