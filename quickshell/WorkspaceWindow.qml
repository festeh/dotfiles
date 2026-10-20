pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Row {
    id: root
    required property var workspace
    required property var toplevel
    property bool keyboardNavigation: false
    readonly property var agents: TerminalState.agentsFor(toplevel)
    signal pointerInteraction()
    signal keyboardInteraction()
    signal revealRequested(var item)
    spacing: 2

    WorkspaceButton {
        workspace: root.workspace
        toplevel: root.toplevel
        windowButton: true
        agentPane: root.agents.length ? root.agents[0].pane : 0
        keyboardNavigation: root.keyboardNavigation
        onPointerInteraction: root.pointerInteraction()
        onKeyboardInteraction: root.keyboardInteraction()
        onRevealRequested: item => root.revealRequested(item)
    }
    Repeater {
        model: ScriptModel {
            values: root.agents.slice(1).map(agent => agent.pane)
            comparisonMode: ObjectComparison.Identity
        }
        delegate: WorkspaceButton {
            required property var modelData
            workspace: root.workspace
            toplevel: root.toplevel
            windowButton: true
            agentPane: modelData
            objectName: "workspace-agent-" + root.toplevel.address + "-" + agentPane
            keyboardNavigation: root.keyboardNavigation
            onPointerInteraction: root.pointerInteraction()
            onKeyboardInteraction: root.keyboardInteraction()
            onRevealRequested: item => root.revealRequested(item)
        }
    }
}
