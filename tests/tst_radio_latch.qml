import QtQuick
import QtTest
import "../services" as Services

TestCase {
    name: "radio_latch"

    Component {
        id: latchFactory
        Services.RadioLatch { settleMs: 80 }
    }
    property var latch: null
    function init() { latch = createTemporaryObject(latchFactory, this) }

    function test_follows_backend_when_idle() {
        compare(latch.value, false)
        latch.backendValue = true
        compare(latch.value, true)
        latch.backendValue = false
        compare(latch.value, false)
    }
    function test_request_is_optimistic() {
        latch.request(true)
        compare(latch.value, true)
    }
    function test_ignores_backend_bounce_during_settle() {
        // NM enable bounce: quickshell sets true locally, NM re-notifies the
        // stale false ~280ms later, then the real true ~1ms after that.
        latch.request(true)
        latch.backendValue = true    // quickshell's optimistic local set
        latch.backendValue = false   // NM stale re-notify — must not blink
        compare(latch.value, true)
        latch.backendValue = true    // NM real confirmation
        compare(latch.value, true)
    }
    function test_ignores_bounce_on_disable_too() {
        latch.backendValue = true
        latch.request(false)
        latch.backendValue = false
        latch.backendValue = true    // hypothetical stale re-notify
        compare(latch.value, false)
        latch.backendValue = false
        compare(latch.value, false)
    }
    function test_resyncs_to_backend_after_settle() {
        // Backend never confirms (e.g. hard rfkill): converge to backend truth.
        latch.request(true)
        compare(latch.value, true)
        tryCompare(latch, "value", false)
    }
    function test_tracks_backend_again_after_settle() {
        latch.request(true)
        latch.backendValue = true
        wait(200)                    // let the settle window expire
        latch.backendValue = false   // external change (nmcli, rfkill) tracks
        compare(latch.value, false)
    }
}
