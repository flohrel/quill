import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../services/notifications.js" as N

// One notification popup in the bar's card style. Left-click runs the default
// action (or dismisses), right-click dismisses, hovering pauses the timeout
// (pointer input via CardPointer, which stays hovered over text and buttons).
// The countdown itself lives in NotificationService (shared across outputs);
// the card only reports hover, and draws `remaining`/`total` as a countdown
// (#67) in the look chosen by Config.notifications.countdown.
Rectangle {
    id: card
    required property int notifId

    readonly property var notif: NotificationService.byId(notifId)
    readonly property bool critical: NotificationService.urgency(notifId) === "critical"
    readonly property int total: NotificationService.timeoutMs(notifId)
    readonly property int remaining: NotificationService.remaining[notifId] || 0
    readonly property int repeats: NotificationService.repeatCount(notifId)
    readonly property string countdownStyle: N.countdownStyle(Config.notifications.countdown, critical, total)

    CountdownFraction {
        id: countdown
        target: N.countdownFraction(card.remaining, card.total)
    }

    readonly property string iconSource: {
        if (!notif) return ""
        if (notif.image) return notif.image
        var a = notif.appIcon || ""
        if (a === "") return ""
        if (a.indexOf("/") === 0) return "file://" + a
        if (a.indexOf("file:") === 0 || a.indexOf("image:") === 0) return a
        return Quickshell.iconPath(a, true)
    }

    width: Config.notifications.width
    implicitHeight: content.implicitHeight + Config.notifications.padding * 2
    radius: Config.shape.overlayRadius
    color: Theme.surface
    border.width: 1
    border.color: critical ? Theme.urgent : Theme.border
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: Config.shape.animDuration } }

    CardPointer {
        anchors.fill: parent
        onHoveredChanged: NotificationService.setHovered(card.notifId, hovered)
        onClicked: button => {
            if (button === Qt.RightButton) NotificationService.dismiss(card.notifId)
            else NotificationService.activate(card.notifId)
        }

        Row {
            id: content
            x: Config.notifications.padding
            y: Config.notifications.padding
            width: card.width - Config.notifications.padding * 2
            spacing: Config.notifications.padding

            IconImage {
                id: icon
                visible: card.iconSource !== ""
                source: card.iconSource
                implicitSize: Config.notifications.iconSize
            }

            Column {
                width: content.width - (icon.visible ? icon.width + content.spacing : 0)
                spacing: 4

                Item {   // summary + ×N repeat chip (#65); summary elides first
                    width: parent.width
                    height: summary.implicitHeight
                    Text {
                        id: summary
                        anchors.left: parent.left
                        width: parent.width - (chip.visible ? chip.implicitWidth + 6 : 0)
                        text: card.notif ? card.notif.summary : ""
                        font.bold: true
                        font.pixelSize: 14
                        color: card.critical ? Theme.urgent : Theme.foreground
                        elide: Text.ElideRight
                    }
                    Text {
                        id: chip
                        anchors.right: parent.right
                        anchors.baseline: summary.baseline
                        visible: card.repeats > 1
                        text: "\u00D7" + card.repeats
                        font.pixelSize: 12
                        font.family: "monospace"
                        color: Theme.foregroundDim
                    }
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: card.notif ? card.notif.body : ""
                    textFormat: Text.StyledText
                    font.pixelSize: 13
                    color: Theme.foregroundDim
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
                Row {
                    spacing: 6
                    visible: actionRepeater.count > 0
                    Repeater {
                        id: actionRepeater
                        model: card.notif ? card.notif.actions.filter(a => a.identifier !== "default") : []
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: label.implicitWidth + 20
                            implicitHeight: label.implicitHeight + 10
                            radius: 8
                            color: actionArea.containsMouse ? Theme.border : Theme.surfaceAlt
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: parent.modelData.text
                                font.pixelSize: 12
                                color: Theme.foreground
                            }
                            MouseArea {
                                id: actionArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }

    // Countdown overlay (#67): above the content, never takes the mouse.
    Loader {
        anchors.fill: parent
        z: 1
        enabled: false
        sourceComponent: card.countdownStyle === "bar" ? barComponent
                       : card.countdownStyle === "border" ? borderComponent : null
    }
    Component {
        id: barComponent
        CountdownBar {
            fraction: countdown.value
            inset: card.radius
            color: Theme.accent
        }
    }
    Component {
        id: borderComponent
        CountdownBorder {
            fraction: countdown.value
            radius: card.radius
            strokeWidth: card.border.width
            color: Theme.accent
        }
    }
}
