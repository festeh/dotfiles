//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
//@ pragma Env QS_FALLBACK_ICON_THEME = Adwaita
//@ pragma Env QS_SYMBOLIC_ICON_COLOR = #cdd6f4
//@ pragma Env QT_QPA_PLATFORMTHEME = gtk3
//@ pragma Env GTK_THEME = Adwaita:dark
//@ pragma Env QT_IM_MODULE = compose
//@ pragma Env QT_NO_XDG_DESKTOP_PORTAL = 1
//@ pragma Env QS_WIDGET_STYLE_SHEET = menu.qss
//@ pragma Env QS_HIDE_MISSING_ICONS = 1

import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: Theme.panelHeight
            color: "transparent"

            // Normal exclusion respects AGS's reserved space, including height changes.
            // Reserve our own row so maximized windows remain below the preview.
            exclusiveZone: implicitHeight
            WlrLayershell.namespace: "quickshell-tray-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            mask: Region {
                Region { item: workspaceStrip }
                Region { item: statusRow }
            }

            WorkspaceStrip {
                id: workspaceStrip
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: 4
                width: Math.max(0, Math.min(implicitWidth, statusRow.x - 16))
                keyboardNavigation: statusRow.keyboardNavigation
                onPointerInteraction: statusRow.keyboardNavigation = false
                onKeyboardInteraction: statusRow.keyboardNavigation = true
            }

            Row {
                id: statusRow
                property bool keyboardNavigation: false
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.rightMargin: 4
                spacing: 8

                LayoutWidget {
                    keyboardNavigation: statusRow.keyboardNavigation
                    onPointerInteraction: statusRow.keyboardNavigation = false
                    onKeyboardInteraction: statusRow.keyboardNavigation = true
                }

                VolumeWidget {
                    keyboardNavigation: statusRow.keyboardNavigation
                    onPointerInteraction: statusRow.keyboardNavigation = false
                    onKeyboardInteraction: statusRow.keyboardNavigation = true
                }

                NetworkWidget {
                    keyboardNavigation: statusRow.keyboardNavigation
                    onPointerInteraction: statusRow.keyboardNavigation = false
                    onKeyboardInteraction: statusRow.keyboardNavigation = true
                }

                BatteryWidget {
                    keyboardNavigation: statusRow.keyboardNavigation
                    onPointerInteraction: statusRow.keyboardNavigation = false
                    onKeyboardInteraction: statusRow.keyboardNavigation = true
                }

                ClockWidget {
                    keyboardNavigation: statusRow.keyboardNavigation
                    onPointerInteraction: statusRow.keyboardNavigation = false
                    onKeyboardInteraction: statusRow.keyboardNavigation = true
                }

                Tray {
                    id: tray
                    visible: itemCount > 0
                    keyboardNavigation: statusRow.keyboardNavigation
                    onPointerInteraction: statusRow.keyboardNavigation = false
                    onKeyboardInteraction: statusRow.keyboardNavigation = true
                }
            }
        }
    }
}
