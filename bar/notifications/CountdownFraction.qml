import QtQuick

// Smoothed countdown fraction (#67). `value` follows `target`: it animates
// linearly over ~one service tick when the time left shrinks, and jumps at
// once when it grows (a duplicate re-armed the timeout) so a refreshed card
// reads "full" immediately. Hover needs nothing: `target` simply stops moving.
QtObject {
    id: root
    property real target: 0
    property int duration: 100
    readonly property real value: _v

    property real _v: 0
    property NumberAnimation _anim: NumberAnimation {
        target: root
        property: "_v"
        easing.type: Easing.Linear
    }

    onTargetChanged: {
        _anim.stop()
        if (target >= _v) {
            _v = target
        } else {
            _anim.from = _v
            _anim.to = target
            _anim.duration = duration
            _anim.start()
        }
    }
}
