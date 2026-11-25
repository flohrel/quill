import QtQuick
import QtTest
import "../services/nmcli.js" as Nmcli

TestCase {
    name: "nmcli"

    function test_parseDeviceShow_extracts_and_strips_cidr() {
        var t = "IP4.ADDRESS[1]:192.168.1.42/24\n"
              + "IP4.GATEWAY:192.168.1.1\n"
              + "IP4.DNS[1]:1.1.1.1\n"
              + "IP4.DNS[2]:1.0.0.1\n"
              + "GENERAL.STATE:100 (connected)\n"
        var d = Nmcli.parseDeviceShow(t)
        compare(d.ip, "192.168.1.42")     // CIDR stripped
        compare(d.gateway, "192.168.1.1")
        compare(d.dns, "1.1.1.1")          // first DNS only
    }
    function test_parseDeviceShow_missing_fields_empty() {
        var d = Nmcli.parseDeviceShow("GENERAL.STATE:30 (disconnected)\n")
        compare(d.ip, "")
        compare(d.gateway, "")
        compare(d.dns, "")
    }
    function test_parseDeviceShow_empty_safe() {
        var d = Nmcli.parseDeviceShow("")
        compare(d.ip, ""); compare(d.gateway, ""); compare(d.dns, "")
    }
    function test_parseConnectionShow_extracts() {
        var t = "connection.autoconnect:yes\n"
              + "connection.metered:unknown\n"
              + "ipv4.method:auto\n"
              + "802-11-wireless-security.key-mgmt:wpa-psk\n"
        var c = Nmcli.parseConnectionShow(t)
        compare(c.autoconnect, "yes")
        compare(c.metered, "unknown")
        compare(c.ipv4Method, "auto")
        compare(c.keyMgmt, "wpa-psk")
    }
    function test_resolveProfile_matches_ssid_skips_wired() {
        var t = "home-5G:802-11-wireless\n"
              + "Wired connection 1:802-3-ethernet\n"
        compare(Nmcli.resolveProfile(t, "home-5G"), "home-5G")
        compare(Nmcli.resolveProfile(t, "nope"), "")
    }
    function test_resolveProfile_unescapes_colon() {
        var t = "cafe\\:guest:802-11-wireless\n"
        compare(Nmcli.resolveProfile(t, "cafe:guest"), "cafe:guest")
    }
    function test_signalLabel_buckets() {
        compare(Nmcli.signalLabel(0.9), "Excellent")
        compare(Nmcli.signalLabel(0.6), "Good")
        compare(Nmcli.signalLabel(0.3), "Fair")
        compare(Nmcli.signalLabel(0.1), "Weak")
        compare(Nmcli.signalLabel(0), "")
        compare(Nmcli.signalLabel(80), "Excellent")   // 0..100 normalized
    }
    function test_label_helpers() {
        compare(Nmcli.autoconnectLabel("yes"), "On")
        compare(Nmcli.autoconnectLabel("no"), "Off")
        compare(Nmcli.autoconnectLabel(""), "")
        compare(Nmcli.meteredLabel("yes"), "On")
        compare(Nmcli.meteredLabel("no"), "Off")
        compare(Nmcli.meteredLabel("unknown"), "Auto")
        compare(Nmcli.meteredLabel(""), "")
        compare(Nmcli.ipv4MethodLabel("auto"), "DHCP")
        compare(Nmcli.ipv4MethodLabel("manual"), "Manual")
        compare(Nmcli.keyMgmtLabel("wpa-psk"), "WPA2")
        compare(Nmcli.keyMgmtLabel("sae"), "WPA3")
        compare(Nmcli.keyMgmtLabel("wpa-eap"), "802.1X")
        compare(Nmcli.keyMgmtLabel("none"), "WEP")
        compare(Nmcli.keyMgmtLabel(""), "")
    }
    function test_parseConnectionShow_empty_safe() {
        var c = Nmcli.parseConnectionShow("")
        compare(c.autoconnect, ""); compare(c.metered, "")
        compare(c.ipv4Method, ""); compare(c.keyMgmt, "")
    }
}
