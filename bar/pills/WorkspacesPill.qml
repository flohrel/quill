import QtQuick
import qs.config     // qmllint disable import
import qs.services   // qmllint disable import
import "../../lib/workspaces.js" as Workspaces

// Left pill: niri workspaces on this screen as icon chips — named role
// workspaces get a Config glyph (text-label fallback for unmapped names),
// dynamic ones show their active window's app glyph (generic window glyph
// when unrecognized, classic dot when empty). Focused chip = accent capsule.
// "scratch" is filtered out by design (focusing it shows no accent anywhere
// — expected).
Rectangle {
    id: pill
    property var screen
    implicitWidth: row.width + Config.workspaceChips.pillPaddingH * 2
    implicitHeight: Config.shape.barHeight
    radius: Config.shape.pillRadius
    color: Theme.surface

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Config.workspaceChips.spacing
        Repeater {
            model: NiriService.workspaces
            delegate: Rectangle {
                id: entry
                required property var model
                readonly property var chip: Workspaces.glyphFor(
                    model.name || "",
                    NiriService.workspaceApps[model.id] !== undefined,
                    NiriService.workspaceApps[model.id] || "",
                    Config.workspaceChips.glyphs,
                    Config.workspaceChips.appGlyphs)
                readonly property bool isDot: chip.kind === "dot"
                readonly property Item content: chip.kind === "label" ? labelText : glyphText
                visible: (!pill.screen || !model.output || model.output === pill.screen.name)
                         && model.name !== "scratch"
                anchors.verticalCenter: parent.verticalCenter
                width: Config.workspaceChips.paddingH * 2 + (isDot ? Config.shape.dotSize : content.width)
                height: Config.workspaceChips.paddingV * 2 + (isDot ? Config.shape.dotSize : content.height)
                // Dots share the chips' padding box, so they render as small
                // capsules (user-tuned); height/2 is the true capsule radius.
                radius: isDot ? height / 2 : Config.workspaceChips.radius
                color: model.isFocused ? Theme.accent
                                       : (isDot ? Theme.surfaceAlt : "transparent")

                // Role or app glyph, dark-on-accent when focused.
                Text {
                    id: glyphText
                    visible: entry.chip.kind === "glyph"
                    anchors.centerIn: parent
                    text: entry.chip.kind === "glyph" ? entry.chip.text : ""
                    font.family: "Symbols Nerd Font Mono" // Mono variant: uniform glyph advance keeps chip widths even
                    font.pixelSize: Config.workspaceChips.fontSize
                    color: entry.model.isFocused ? Theme.background : Theme.foregroundDim
                }

                // Fallback for a named workspace with no glyph mapping.
                Text {
                    id: labelText
                    visible: entry.chip.kind === "label"
                    anchors.centerIn: parent
                    text: entry.chip.kind === "label" ? entry.chip.text : ""
                    font.pixelSize: Config.workspaceChips.fontSize - 2
                    color: entry.model.isFocused ? Theme.background : Theme.foregroundDim
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriService.focusWorkspace(entry.model.id)
                }
            }
        }
    }
}
