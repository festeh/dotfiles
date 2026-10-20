pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import "WorkspaceLogic.js" as Logic

Button {
    id: root
    required property var workspace
    property var toplevel: null
    property bool windowButton: false
    property int agentPane: 0
    property bool emptyWorkspace: false
    property bool keyboardNavigation: false
    readonly property var agent: agentPane ? TerminalState.agentFor(toplevel, agentPane) : null
    readonly property bool selected: windowButton
        ? WorkspaceState.isFocused(toplevel) && (!agentPane || !!agent && agent.active)
        : workspace && WorkspaceState.workspaceFocused(workspace)
    readonly property var app: agent ? WorkspaceState.programInfo(agent.agent)
        : windowButton ? WorkspaceState.info(toplevel) : ({name: "", source: ""})
    readonly property string agentState: agent ? agent.state : ""
    readonly property string agentDescription: agent ? TerminalState.describeAgent(agent) : ""
    readonly property string caption: Logic.label(workspace)
    readonly property string tooltip: agent ? app.name : windowButton
        ? app.name + (toplevel && Logic.clean(toplevel.title) ? " · " + Logic.clean(toplevel.title) : "")
        : "Workspace " + caption + (workspace && workspace.name !== caption ? " · " + Logic.clean(workspace.name) : "")
    readonly property bool interactionHighlighted: keyboardNavigation ? activeFocus : hovered
    readonly property bool wantsTooltip: interactionHighlighted && !down
    property bool tooltipReady: false
    signal pointerInteraction()
    signal keyboardInteraction()
    signal revealRequested(var item)

    objectName: windowButton ? "workspace-window-" + (toplevel ? toplevel.address : "")
        : "workspace-number-" + (workspace ? workspace.address : "")
    implicitWidth: windowButton ? 28 : Math.max(12, Math.min(90, captionMetrics.advanceWidth + 4))
    implicitHeight: 32
    padding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: tooltip
    Accessible.description: (windowButton ? "Focus this window" : "Activate this workspace")
        + (agentDescription ? " · " + agentDescription : "")
    onHoveredChanged: if (hovered) root.pointerInteraction()
    onActiveFocusChanged: if (activeFocus) root.revealRequested(root)
    onClicked: agentPane ? TerminalState.activateAgent(toplevel, agentPane)
        : windowButton ? WorkspaceState.activateWindow(toplevel) : WorkspaceState.activateWorkspace(workspace)
    Keys.onPressed: event => {
        root.keyboardInteraction();
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked();
            event.accepted = true;
        } else event.accepted = false;
    }
    onWantsTooltipChanged: {
        tooltipReady = false;
        if (wantsTooltip) tooltipDelay.restart();
        else tooltipDelay.stop();
    }

    TextMetrics {
        id: captionMetrics
        text: root.caption
        font { family: Theme.fontFamily; pixelSize: 12; bold: true }
    }
    background: Rectangle {
        radius: 6
        color: root.down || root.interactionHighlighted ? Theme.hover : "transparent"
        border.width: root.keyboardNavigation && root.activeFocus ? 1 : 0
        border.color: Theme.accent
    }
    contentItem: Item {
        Text {
            id: captionText
            anchors { fill: parent; leftMargin: 2; rightMargin: 2 }
            visible: !root.windowButton
            text: root.caption
            textFormat: Text.PlainText
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Theme.subtext
            font { family: Theme.fontFamily; pixelSize: 12; bold: root.selected }
        }
        IconImage {
            id: icon
            anchors.centerIn: parent
            implicitSize: 18
            source: root.app.source
            visible: root.windowButton && status === Image.Ready
        }
        IconImage {
            id: fallbackIcon
            anchors.centerIn: parent
            implicitSize: 18
            source: root.app.fallbackSource || ""
            visible: root.windowButton && icon.status !== Image.Ready && status === Image.Ready
        }
        Rectangle {
            anchors.centerIn: parent
            width: 14; height: 12; radius: 2
            visible: root.windowButton && icon.status !== Image.Ready && fallbackIcon.status !== Image.Ready
            color: "transparent"
            border { width: 1.5; color: Theme.subtext }
            Rectangle { x: 1; y: 3; width: parent.width - 2; height: 1; color: Theme.subtext }
        }
        Rectangle {
            objectName: "agent-status-overline"
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: 18; height: 2; radius: 1
            color: root.agentState === "waiting" ? Theme.attention
                : root.agentState === "running" ? Theme.running : Theme.positive
            visible: root.agentState.length > 0
        }
        Rectangle {
            objectName: "window-focus-underline"
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 18; height: 2; radius: 1
            color: Theme.accent
            visible: root.selected && (root.windowButton || root.emptyWorkspace)
        }
    }
    HoverHandler { onPointChanged: if (hovered) root.pointerInteraction() }
    Timer { id: tooltipDelay; interval: 500; onTriggered: root.tooltipReady = true }
    TrayTooltip {
        anchorItem: root
        title: root.tooltip
        description: root.agentDescription
        visible: root.wantsTooltip && root.tooltipReady
    }
}
