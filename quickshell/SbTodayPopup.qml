pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "SbTodayLogic.js" as Logic

// Today's tasks: overdue, then today, each with a checkbox that completes it
// in sb. A title opens the task in sb; the field at the bottom adds a task
// due today. Up/Down select, Space completes, Enter opens, Tab reaches the
// field, Escape closes.
PopupWindow {
    id: root
    required property Item anchorItem
    readonly property var tasks: SbTodayState.tasks
    readonly property var entries: Logic.entries(tasks)
    readonly property var counts: SbTodayState.summary
    property int selected: 0
    signal dismissed()
    objectName: "sb-today-popup"
    anchor.item: anchorItem
    // Qt's lint metadata loses the enum-flags type of this native bitwise expression.
    // qmllint disable incompatible-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable incompatible-type
    anchor.margins.top: 6
    grabFocus: true
    color: "transparent"
    implicitWidth: 420
    implicitHeight: Math.min(610, column.implicitHeight + 28)
    onVisibleChanged: if (!visible) dismissed()
    onBackingWindowVisibleChanged: if (backingWindowVisible) content.forceActiveFocus(Qt.PopupFocusReason)
    onTasksChanged: selected = Logic.step(selected, tasks.length, 0)

    function openTask(task: var): void {
        SbTodayState.open(task.path);
        visible = false;
    }
    function select(delta: int): void {
        selected = Logic.step(selected, tasks.length, delta);
        const at = entries.findIndex(entry => entry.index === selected);
        if (at >= 0) list.positionViewAtIndex(at, ListView.Contain);
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.base
        border { color: Theme.border; width: 1 }
    }
    FocusScope {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const task = root.tasks[root.selected];
            if (event.key === Qt.Key_Escape) {
                root.visible = false; event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) {
                root.select(1); event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) {
                root.select(-1); event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                if (task) SbTodayState.complete(task.path);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (task) root.openTask(task);
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                addField.forceActiveFocus(Qt.TabFocusReason); event.accepted = true;
            }
        }
        Column {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10
            RowLayout {
                width: parent.width
                spacing: 8
                Text {
                    text: "Today"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: 15; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    text: Logic.dayHeading(SbTodayState.today)
                    color: Theme.muted
                    font { family: Theme.fontFamily; pixelSize: 11 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    objectName: "sb-today-overdue-count"
                    visible: root.counts.overdue > 0
                    text: root.counts.overdue + " overdue"
                    color: Theme.critical
                    font { family: Theme.fontFamily; pixelSize: 11 }
                }
                Text {
                    visible: root.counts.overdue > 0 && root.counts.today > 0
                    text: "·"
                    color: Theme.muted
                    font { family: Theme.fontFamily; pixelSize: 11 }
                }
                Text {
                    visible: root.counts.today > 0
                    text: root.counts.today + " today"
                    color: Theme.subtext
                    font { family: Theme.fontFamily; pixelSize: 11 }
                }
            }
            Text {
                objectName: "sb-today-error"
                width: parent.width
                visible: text.length > 0
                text: SbTodayState.error
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Theme.attention
                font { family: Theme.fontFamily; pixelSize: 11 }
            }
            ListView {
                id: list
                objectName: "sb-today-list"
                width: parent.width
                height: Math.min(contentHeight, 400)
                model: root.entries
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    width: 4
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 4; implicitHeight: 24; radius: 2; color: Theme.border }
                    background: Item {}
                }
                delegate: Item {
                    id: entry
                    required property var modelData
                    readonly property bool heading: modelData.kind === "heading"
                    readonly property var task: heading ? null : modelData.task
                    readonly property bool busy: !heading && SbTodayState.isBusy(task.path)
                    width: list.width - 8
                    height: heading ? 26 : 46
                    Text {
                        visible: entry.heading
                        anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom; bottomMargin: 4 }
                        text: entry.heading ? entry.modelData.title.toUpperCase() : ""
                        color: entry.heading && entry.modelData.overdue ? Theme.critical : Theme.subtext
                        font { family: Theme.fontFamily; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
                    }
                    Rectangle {
                        objectName: entry.heading ? "" : "sb-today-row-" + entry.modelData.index
                        visible: !entry.heading
                        anchors.fill: parent
                        radius: 8
                        color: rowMouse.containsMouse ? Theme.hover
                            : root.selected === entry.modelData.index ? Theme.surface : "transparent"
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (entry.task) root.openTask(entry.task)
                        }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 10
                            Rectangle {
                                id: box
                                objectName: entry.heading ? "" : "sb-today-done-" + entry.modelData.index
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 5
                                color: entry.busy ? Theme.positive : "transparent"
                                border { width: entry.busy ? 0 : 1.5; color: boxMouse.containsMouse ? Theme.positive : Theme.border }
                                Accessible.role: Accessible.CheckBox
                                Accessible.name: "Done: " + (entry.task ? entry.task.title : "")
                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 12
                                    visible: entry.busy || boxMouse.containsMouse
                                    source: Qt.resolvedUrl(entry.busy ? "assets/sb-check-done.svg" : "assets/sb-check.svg")
                                }
                                MouseArea {
                                    id: boxMouse
                                    anchors { fill: parent; margins: -6 }
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (entry.task) SbTodayState.complete(entry.task.path)
                                }
                            }
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: entry.task ? entry.task.title : ""
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: entry.busy ? Theme.muted : Theme.text
                                    font { family: Theme.fontFamily; pixelSize: 12; weight: Font.DemiBold; strikeout: entry.busy }
                                }
                                Row {
                                    spacing: 10
                                    visible: details.count > 0
                                    Repeater {
                                        id: details
                                        model: entry.task ? Logic.details(entry.task, SbTodayState.today) : []
                                        delegate: Row {
                                            id: part
                                            required property var modelData
                                            spacing: 3
                                            IconImage {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: part.modelData.kind === "reminder"
                                                implicitSize: 10
                                                source: Qt.resolvedUrl("assets/sb-bell.svg")
                                            }
                                            Text {
                                                text: part.modelData.text
                                                textFormat: Text.PlainText
                                                color: part.modelData.kind === "due" ? Theme.critical
                                                    : part.modelData.kind === "reminder" ? Theme.subtext
                                                    : part.modelData.kind === "doing" ? Theme.running : Theme.muted
                                                font { family: Theme.fontFamily; pixelSize: 10 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            TextField {
                id: addField
                objectName: "sb-today-add"
                width: parent.width
                placeholderText: "+ Add a task for today"
                placeholderTextColor: Theme.muted
                color: Theme.text
                font { family: Theme.fontFamily; pixelSize: 12 }
                padding: 8
                background: Rectangle {
                    radius: 8
                    color: Theme.surface
                    border { width: addField.activeFocus ? 1 : 0; color: Theme.accent }
                }
                onAccepted: {
                    const title = text.trim();
                    if (!title) return;
                    SbTodayState.add(title);
                    text = "";
                }
                Keys.onEscapePressed: root.visible = false
                Keys.onTabPressed: content.forceActiveFocus(Qt.TabFocusReason)
                Keys.onBacktabPressed: content.forceActiveFocus(Qt.BacktabFocusReason)
            }
        }
    }
}
