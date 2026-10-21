pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    required property Item anchorItem
    required property var toplevel
    required property int pane
    readonly property var agent: TerminalState.agentFor(toplevel, pane)
    property bool pending: false
    property string message: ""
    property alias text: field.text
    signal dismissed()

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 6
    grabFocus: true
    color: "transparent"
    implicitWidth: 280
    implicitHeight: column.implicitHeight + 24

    onVisibleChanged: if (!visible) dismissed()
    onAgentChanged: if (!agent) visible = false
    onBackingWindowVisibleChanged: if (backingWindowVisible) {
        field.text = agent ? agent.fullLabel || agent.project || "" : "";
        field.forceActiveFocus(Qt.PopupFocusReason);
        field.selectAll();
    }
    function save(value: string): void {
        if (pending) return;
        message = "";
        pending = TerminalState.renameAgent(toplevel, pane, value);
        if (!pending) message = "This agent is no longer available.";
    }
    Connections {
        target: TerminalState
        function onLabelRenamed(address: string, pane: int, ok: bool, message: string): void {
            if (!root.pending || address !== root.toplevel.address || pane !== root.pane) return;
            root.pending = false;
            if (ok) root.visible = false;
            else root.message = message;
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.surface
        border { width: 1; color: Theme.border }
    }
    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false
        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Rename label"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: 13; bold: true }
                }
                CalendarAction {
                    text: "×"
                    Accessible.name: "Close label editor"
                    onClicked: root.visible = false
                }
            }
            TextField {
                id: field
                objectName: "agent-label-input"
                Layout.fillWidth: true
                implicitHeight: 34
                maximumLength: 48
                enabled: !root.pending
                selectByMouse: true
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.base
                font { family: Theme.fontFamily; pixelSize: 12 }
                Accessible.name: "Agent label"
                placeholderText: root.agent ? root.agent.project : "Label"
                placeholderTextColor: Theme.muted
                background: Rectangle {
                    radius: 7
                    color: Theme.base
                    border { width: 1; color: field.activeFocus ? Theme.accent : Theme.border }
                }
                onAccepted: root.save(text)
                Keys.onEscapePressed: root.visible = false
            }
            Text {
                Layout.fillWidth: true
                text: root.message || (root.agent ? root.agent.project : "")
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                color: root.message ? Theme.attention : Theme.subtext
                font { family: Theme.fontFamily; pixelSize: 11 }
            }
            RowLayout {
                Layout.fillWidth: true
                CalendarAction {
                    text: "Use automatic name"
                    enabled: !root.pending
                    onClicked: root.save("")
                }
                Item { Layout.fillWidth: true }
                CalendarAction {
                    text: root.pending ? "Saving…" : "Save"
                    enabled: !root.pending
                    onClicked: root.save(field.text)
                }
            }
        }
    }
}
