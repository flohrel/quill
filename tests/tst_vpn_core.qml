import QtQuick
import QtTest
import "../services/vpn.js" as Vpn
import "../services"

// Drives VpnCore with fake backends that behave like NetworkManagerBackend:
// connect()/disconnect() synchronously mark the profile in-flight and
// recompute `profiles`; nm() simulates the later nmcli refresh.
TestCase {
    name: "vpn_core"

    Component {
        id: fakeComp
        QtObject {
            id: fb
            property string backendId: "nm"
            property string displayName: "NetworkManager"
            property var claimedIds: []
            property var names: ["A", "B", "C"]
            property var active: ({})
            property var inflight: ({})
            property var calls: []
            property var profiles: []
            function recompute() {
                profiles = Vpn.mergeState(names.map(function (n) { return { id: n, name: n } }), active, {}, inflight)
            }
            function _set(map, id, st) { var m = Object.assign({}, map); if (st) m[id] = st; else delete m[id]; return m }
            function connect(id) { calls = calls.concat(["up " + id]); inflight = _set(inflight, id, "connecting"); recompute() }
            function disconnect(id) { calls = calls.concat(["down " + id]); inflight = _set(inflight, id, "disconnecting"); recompute() }
            // NM reports id's real state and the in-flight mark is cleared.
            function nm(id, st) { active = _set(active, id, st); inflight = _set(inflight, id, null); recompute() }
            Component.onCompleted: recompute()
        }
    }
    Component { id: coreComp; VpnCore {} }

    function make() {
        var fb = createTemporaryObject(fakeComp, this)
        var core = createTemporaryObject(coreComp, this, { backends: [fb] })
        return { fb: fb, core: core }
    }
    function upCount(core) {
        return Vpn.allProfiles(core.groups).filter(function (p) {
            return p.state === "connected" || p.state === "connecting" }).length
    }

    function test_switch_then_quick_third_toggle_never_two_tunnels() {
        var t = make(), fb = t.fb, core = t.core
        fb.nm("A", "connected")
        core.toggle("nm", "B")                 // A down, B pending
        compare(fb.calls, ["down A"])
        fb.nm("A", null)                       // A reported off → planner connects B
        tryCompare(fb, "calls", ["down A", "up B"])
        // groups must already show B busy, or the next toggle connects alongside it
        tryVerify(function () { return upCount(core) === 1 }, 500, "groups stale: B not shown connecting")
        core.toggle("nm", "C")                 // must take B down first, not connect C now
        compare(fb.calls, ["down A", "up B", "down B"])
        compare(core.pending, { backendId: "nm", id: "C" })
    }

    function test_no_binding_loop_on_planner_step() {
        var t = make(), fb = t.fb, core = t.core
        fb.nm("A", "connected")
        core.toggle("nm", "B")
        failOnWarning(/Binding loop/)
        fb.nm("A", null)
        tryCompare(fb, "calls", ["down A", "up B"])
    }
}
