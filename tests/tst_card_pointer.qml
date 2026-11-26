import QtQuick
import QtTest
import "../bar/notifications"

// Notification card pointer surface (#17). Hover anywhere on the card must
// count as hovered (it pauses the countdown), including over children that
// take hover events themselves: StyledText bodies and action buttons.
// CardPointer is pure QtQuick, so it loads here without Quickshell.
Item {
    id: tc
    width: 400
    height: 300

    Component {
        id: cardC
        CardPointer {
            id: cp
            width: 300
            height: 160
            readonly property bool buttonHovered: button.containsMouse
            property int buttonClicks: 0
            Column {
                Text { width: 300; height: 40; text: "plain summary" }
                Text { width: 300; height: 40; text: "styled <b>body</b>"; textFormat: Text.StyledText }
                Rectangle {
                    width: 300
                    height: 40
                    MouseArea {
                        id: button
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: cp.buttonClicks++
                    }
                }
            }
        }
    }

    TestCase {
        name: "card_pointer"
        when: windowShown

        function makeCard() {
            var c = createTemporaryObject(cardC, tc)
            verify(c !== null)
            mouseMove(tc, 390, 290)   // start outside the card
            return c
        }

        function test_hover_empty_area() {
            var c = makeCard()
            mouseMove(c, 150, 140)
            tryCompare(c, "hovered", true)
        }
        function test_hover_plain_text() {
            var c = makeCard()
            mouseMove(c, 10, 20)
            tryCompare(c, "hovered", true)
        }
        function test_hover_styled_text() {
            var c = makeCard()
            mouseMove(c, 10, 60)
            tryCompare(c, "hovered", true)
        }
        function test_hover_action_button() {
            var c = makeCard()
            mouseMove(c, 10, 100)
            tryCompare(c, "buttonHovered", true)
            compare(c.hovered, true)
        }
        function test_hover_survives_moving_across_children() {
            var c = makeCard()
            var spy = createTemporaryObject(spyC, tc, {target: c})
            mouseMove(c, 150, 140)
            tryCompare(c, "hovered", true)
            mouseMove(c, 10, 60)    // styled body
            mouseMove(c, 10, 100)   // action button
            mouseMove(c, 10, 20)    // plain summary
            compare(c.hovered, true)
            compare(spy.count, 1)   // entered once, never left
        }
        function test_unhover_on_leave() {
            var c = makeCard()
            mouseMove(c, 10, 60)
            tryCompare(c, "hovered", true)
            mouseMove(tc, 390, 290)
            tryCompare(c, "hovered", false)
        }
        function test_clicks_reach_card_through_text() {
            var c = makeCard()
            var spy = createTemporaryObject(clickSpyC, tc, {target: c})
            mouseClick(c, 10, 60, Qt.LeftButton)
            mouseClick(c, 10, 20, Qt.RightButton)
            compare(spy.count, 2)
            compare(spy.signalArguments[0][0], Qt.LeftButton)
            compare(spy.signalArguments[1][0], Qt.RightButton)
        }
        function test_action_button_click_stays_with_button() {
            var c = makeCard()
            var spy = createTemporaryObject(clickSpyC, tc, {target: c})
            mouseClick(c, 10, 100, Qt.LeftButton)
            compare(c.buttonClicks, 1)
            compare(spy.count, 0)
        }

    }

    Component { id: spyC; SignalSpy { signalName: "hoveredChanged" } }
    Component { id: clickSpyC; SignalSpy { signalName: "clicked" } }
}
