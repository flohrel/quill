pragma Singleton
import QtQuick
import Quickshell
import qs.config   // qmllint disable import
import "vpn.js" as Vpn

// VPN facade (#9). Loads the in-tree backends named in Config.vpn.backends
// (files under services/vpn/) and exposes VpnCore's merged state and
// one-at-a-time switching. UI binds ONLY to this service, never to a backend.
// External changes (terminal, NM autoconnect) are displayed, never enforced.
Singleton {
    id: root

    property var backends: []

    readonly property var pending: core.pending
    readonly property var groups: core.groups
    readonly property bool connected: core.connected
    readonly property bool hasProfiles: core.hasProfiles
    readonly property string hubStatus: core.hubStatus

    function toggle(backendId, id) { core.toggle(backendId, id) }
    function isPending(backendId, id) { return core.isPending(backendId, id) }
    function switchOn(backendId, id, state) { return core.switchOn(backendId, id, state) }

    VpnCore {
        id: core
        backends: root.backends
        switchTimeoutMs: Config.vpn.switchTimeoutMs
    }

    Component.onCompleted: {
        var loaded = []
        var names = Config.vpn.backends || []
        for (var i = 0; i < names.length; i++) {
            var url = Vpn.backendUrl(names[i])
            if (!url) { console.warn("VpnService: invalid backend name", names[i]); continue }
            var comp = Qt.createComponent(Qt.resolvedUrl(url))
            if (comp.status === Component.Error) {
                console.warn("VpnService: cannot load backend", names[i], comp.errorString())
                continue
            }
            var obj = comp.createObject(root)
            if (obj) loaded.push(obj)
            else console.warn("VpnService: cannot create backend", names[i])
        }
        backends = loaded
    }
}
