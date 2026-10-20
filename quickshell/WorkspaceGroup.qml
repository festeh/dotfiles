pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Rectangle {
    id: root
    required property var workspace
    property bool keyboardNavigation: false
    signal pointerInteraction()
    signal keyboardInteraction()
    signal revealRequested(var item)
    implicitWidth: row.implicitWidth + 8
    implicitHeight: 40
    radius: 8
    color: Theme.surface
    border.width: workspace && WorkspaceState.workspaceActive(workspace) && !WorkspaceState.workspaceFocused(workspace) ? 1 : 0
    border.color: Theme.border

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        WorkspaceButton {
            id: number
            workspace: root.workspace
            emptyWorkspace: windowButtons.count === 0
            keyboardNavigation: root.keyboardNavigation
            onPointerInteraction: root.pointerInteraction()
            onKeyboardInteraction: root.keyboardInteraction()
            onRevealRequested: item => root.revealRequested(item)
        }
        Repeater {
            id: windowButtons
            model: ScriptModel {
                values: WorkspaceState.windowsFor(root.workspace)
                comparisonMode: ObjectComparison.Identity
            }
            // Show every agent pane belonging to each terminal window.
            delegate: WorkspaceWindow {
                required property var modelData
                workspace: root.workspace
                toplevel: modelData
                keyboardNavigation: root.keyboardNavigation
                onPointerInteraction: root.pointerInteraction()
                onKeyboardInteraction: root.keyboardInteraction()
                onRevealRequested: item => root.revealRequested(item)
            }
        }
    }
    readonly property bool focused: WorkspaceState.workspaceFocused(workspace)
    onFocusedChanged: if (focused) root.revealRequested(number)
}
