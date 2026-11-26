import QtQuick

// Pointer input for a notification card (#17): `hovered` (pauses the
// countdown) and `clicked(button)`. Children go in `content`, above the click
// area.
//
// Hover comes from a HoverHandler on this item, not MouseArea.containsMouse:
// children that accept hover events themselves (a Text with StyledText, the
// action buttons' hover MouseAreas) stop hover reaching a MouseArea behind
// them, so containsMouse went false while the pointer was still on the card
// and the countdown resumed. A non-blocking HoverHandler on the ancestor stays
// hovered over every child. Pure QtQuick so tests/tst_card_pointer.qml can
// load it.
Item {
    id: root
    default property alias content: inner.data
    readonly property bool hovered: hover.hovered
    signal clicked(int button)

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => root.clicked(mouse.button)
    }
    Item {
        id: inner
        anchors.fill: parent
    }
}
