pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config     // qmllint disable import

// Themed renderer for a tray item's DBusMenu (a QsMenuHandle). Ported from the
// retired legacy quickshell config's widgets/TrayMenu.qml. Replaces the
// unthemed native modelData.display(): we walk the menu tree with
// QsMenuOpener and draw the rows ourselves so right-click menus match the
// gruvbox bar. Submenus open as nested popups anchored to their row.
//
// Dismissal and exclusivity are owned by TrayPill, which mirrors "a menu is
// open" into the bar's OverlayController as "tray" (where the legacy version
// used a global BarState singleton): outside clicks land on the fullscreen
// TrayCatcher surface or Bar.qml's blank-band catcher, both of which close
// the controller, and opening any other overlay closes the menu for free.
// This root instance therefore doesn't grab Wayland focus
// (grabFocus: isSubmenu) so a right-click on another tray icon isn't
// swallowed by the popup grab; nested submenus DO grab so an outside click
// collapses the open flyout chain.
PopupWindow {
    id: root

    property var  menuHandle               // QsMenuHandle to render (item.menu, or a submenu entry)
    property Item anchorItem
    property int  anchorEdges:   Edges.Bottom
    property int  anchorGravity: Edges.Bottom
    property bool isSubmenu:     false
    property int  openSubmenu:   -1         // index of the child whose submenu is open (-1 = none)
    signal requestClose()                   // bubbles up so a leaf click closes the whole chain

    anchor.item:        anchorItem
    anchor.edges:       anchorEdges
    anchor.gravity:     anchorGravity
    anchor.margins.top: isSubmenu ? 0 : 6

    implicitWidth:  frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color:    "transparent"
    grabFocus: isSubmenu

    onVisibleChanged: if (!visible) openSubmenu = -1

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    Rectangle {
        id: frame
        width:  root.width
        height: root.height
        // Sized from the rows' natural widths (NOT col.implicitWidth: rows are
        // width-bound to col, so that never reflects their content). Clamped
        // to [160, 420]; labels beyond the cap elide.
        implicitWidth:  Math.min(Math.max(maxRowWidth + pad * 2, 160), 420)
        // Symmetric vertical padding (#75): with the old pad/2+2 top and 1 px
        // bottom, the last row's hover highlight poked past the 16 px corner.
        implicitHeight: col.implicitHeight + pad * 2

        readonly property int pad: 6
        property real maxRowWidth: 0

        function recalcWidth() {
            let m = 0
            for (let i = 0; i < rows.count; i++) {
                const it = rows.itemAt(i)
                if (it) m = Math.max(m, it.implicitWidth)
            }
            maxRowWidth = m
        }

        radius: Config.shape.overlayRadius
        color:  Theme.surface
        border.width: 1
        border.color: Theme.border

        Column {
            id: col
            x: frame.pad
            y: frame.pad
            width: frame.width - frame.pad * 2
            spacing: 2

            Repeater {
                id: rows
                model: opener.children
                onItemAdded: frame.recalcWidth()
                onItemRemoved: frame.recalcWidth()

                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index

                    width: col.width
                    // Natural width: margin + icon/check + label + chevron + margin.
                    // Derived from the label's unelided implicitWidth (independent of
                    // its bound width), so no loop with the elision width below.
                    readonly property real leadWidth: (checkGlyph.visible || iconImage.visible)
                                                          ? Config.shape.iconSize + 8 : 0
                    readonly property real trailWidth: entry.modelData.hasChildren
                                                          ? chevron.implicitWidth + 8 : 0
                    implicitWidth:  entry.modelData.isSeparator ? 0
                                        : (8 + leadWidth + labelText.implicitWidth + trailWidth + 8)
                    onImplicitWidthChanged: frame.recalcWidth()
                    implicitHeight: entry.modelData.isSeparator ? 9 : 30

                    // ---- separator ----
                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    // ---- normal / checkable / submenu row ----
                    MouseArea {
                        id: rowArea
                        visible: !entry.modelData.isSeparator
                        enabled: entry.modelData.enabled
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                root.openSubmenu = (root.openSubmenu === entry.index) ? -1 : entry.index
                            } else {
                                entry.modelData.triggered()
                                root.requestClose()
                            }
                        }
                        // Open submenus on hover too, mirroring native menu behaviour.
                        onContainsMouseChanged: {
                            if (containsMouse && entry.modelData.hasChildren)
                                root.openSubmenu = entry.index
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: (rowArea.enabled && (rowArea.containsMouse || root.openSubmenu === entry.index))
                                       ? Theme.surfaceAlt : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                        Row {
                            id: rowContent
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // checkbox / radio state, or app-provided icon
                            Text {
                                id: checkGlyph
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                width: visible ? Config.shape.iconSize : 0
                                text: entry.modelData.buttonType === QsMenuButtonType.RadioButton
                                          ? (entry.modelData.checkState === Qt.Checked ? "\u{f012f}" : "\u{f0130}")
                                          : (entry.modelData.checkState === Qt.Checked ? "\u{f0132}" : "\u{f0131}")
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: Config.shape.iconSize
                                color: entry.modelData.checkState === Qt.Checked ? Theme.accent : Theme.foregroundDim
                            }

                            Image {
                                id: iconImage
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entry.modelData.buttonType === QsMenuButtonType.None
                                         && entry.modelData.icon !== ""
                                width:  visible ? Config.shape.iconSize : 0
                                height: Config.shape.iconSize
                                source: entry.modelData.icon
                                sourceSize.width:  Config.shape.iconSize
                                sourceSize.height: Config.shape.iconSize
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                id: labelText
                                anchors.verticalCenter: parent.verticalCenter
                                // bounded by the row's actual width; elides at the cap
                                width: Math.max(0, Math.min(implicitWidth,
                                           entry.width - 16 - entry.leadWidth - entry.trailWidth))
                                elide: Text.ElideRight
                                text: entry.modelData.text
                                font.pixelSize: 12
                                color: rowArea.enabled ? Theme.foreground : Theme.foregroundDim
                            }
                        }

                        // submenu chevron
                        Text {
                            id: chevron
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entry.modelData.hasChildren
                            text: "\u{f0142}"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: Config.shape.iconSize
                            color: Theme.foregroundDim
                        }

                        // Nested flyout submenu. Loaded by URL (not as the TrayMenu type) so the
                        // engine doesn't see a static self-instantiation cycle and reject it.
                        Loader {
                            id: subLoader
                            active: entry.modelData.hasChildren
                            source: "TrayMenu.qml"
                            onLoaded: {
                                item.isSubmenu = true
                                item.anchorItem = rowArea
                                item.anchorEdges = Edges.Right | Edges.Top
                                item.anchorGravity = Edges.Right | Edges.Bottom
                                item.menuHandle = entry.modelData
                                item.requestClose.connect(root.requestClose)
                            }
                        }
                        Binding {
                            target: subLoader.item
                            property: "visible"
                            when: subLoader.item !== null
                            value: root.visible && root.openSubmenu === entry.index
                        }
                    }
                }
            }
        }
    }
}
