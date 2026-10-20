pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

PopupWindow {
    id: root
    required property Item anchorItem
    required property string kind
    readonly property bool mail: kind === "gmail"
    readonly property var state: mail ? GoogleWorkState.gmail : GoogleWorkState.calendar
    readonly property var rows: mail ? state.rows || [] : GoogleWorkState.calendarView.rows
    signal dismissed()
    objectName: "work-popup-" + kind
    anchor.item: anchorItem
    // Qt's lint metadata loses the enum-flags type of this native bitwise expression.
    // qmllint disable incompatible-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable incompatible-type
    anchor.margins.top: 6
    grabFocus: true
    color: "transparent"
    implicitWidth: 440
    implicitHeight: Math.min(610, column.implicitHeight + 28)
    onVisibleChanged: if (!visible) dismissed()
    onBackingWindowVisibleChanged: if (backingWindowVisible) content.forceActiveFocus(Qt.PopupFocusReason)

    function openRow(row: var): void {
        GoogleWorkState.send({action: "open", kind: kind, id: row.id});
        visible = false;
    }
    function rowTime(row: var): string {
        const start = new Date(mail ? row.date : row.start);
        const today = new Date().toDateString() === start.toDateString();
        if (mail) return Qt.formatDateTime(start, today ? "HH:mm" : "d MMM");
        const prefix = today ? "Today" : Qt.formatDate(start, "ddd, d MMM");
        return prefix + " · " + (row.allDay ? "All day" : Qt.formatTime(start, "HH:mm")
            + "–" + Qt.formatTime(new Date(row.end), "HH:mm"));
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
            if (event.key === Qt.Key_Escape) {
                root.visible = false; event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) {
                list.currentIndex = Math.min(root.rows.length - 1, list.currentIndex + 1);
                list.positionViewAtIndex(list.currentIndex, ListView.Contain); event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) {
                list.currentIndex = Math.max(0, list.currentIndex - 1);
                list.positionViewAtIndex(list.currentIndex, ListView.Contain); event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.rows[list.currentIndex]) root.openRow(root.rows[list.currentIndex]);
                event.accepted = true;
            }
        }
        Column {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 12
            RowLayout {
                width: parent.width
                Text {
                    Layout.fillWidth: true
                    text: root.mail ? "" : "Work meetings"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: 15; bold: true }
                }
                CalendarAction {
                    objectName: "work-refresh"
                    implicitWidth: 28
                    implicitHeight: 28
                    Accessible.name: "Refresh work account"
                    onClicked: GoogleWorkState.refresh()
                    contentItem: Item {
                        implicitWidth: 14; implicitHeight: 14
                        IconImage { anchors.centerIn: parent; implicitSize: 14; source: Qt.resolvedUrl("assets/refresh.svg") }
                    }
                }
                CalendarAction {
                    implicitWidth: 28
                    implicitHeight: 28
                    Accessible.name: "Close work popup"
                    onClicked: root.visible = false
                    contentItem: Item {
                        implicitWidth: 14; implicitHeight: 14
                        IconImage { anchors.centerIn: parent; implicitSize: 14; source: Qt.resolvedUrl("assets/close.svg") }
                    }
                }
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: GoogleWorkState.transportError || (GoogleWorkState.snapshot.authorizing
                    ? "Finish connecting your work account in the browser…" : root.state.message || "")
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Theme.attention
                font { family: Theme.fontFamily; pixelSize: 11 }
            }
            CalendarAction {
                visible: root.state.status === "auth" || root.state.status === "setup"
                    || root.mail && !root.state.canMarkRead
                enabled: !GoogleWorkState.snapshot.authorizing
                text: root.mail && root.state.status !== "auth" ? "Enable Mark as read" : "Connect work account"
                onClicked: GoogleWorkState.send({action: "authorize"})
            }
            Text {
                width: parent.width
                visible: root.rows.length === 0
                text: root.state.status === "loading" || root.state.loading ? "Loading…"
                    : root.state.status === "ok" ? root.mail ? "Inbox caught up" : "No upcoming meetings"
                    : "Refresh or connect your work account."
                color: Theme.subtext
                font { family: Theme.fontFamily; pixelSize: 12 }
            }
            ListView {
                id: list
                objectName: "work-results"
                width: parent.width
                height: Math.min(contentHeight, 400)
                model: root.rows
                clip: true
                spacing: 6
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    width: 4
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 4; implicitHeight: 24; radius: 2; color: Theme.border }
                    background: Item {}
                }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool busy: (GoogleWorkState.gmail.busyIds || []).includes(modelData.id)
                    width: list.width - 8
                    height: root.mail ? 124 : 72
                    radius: 10
                    color: list.currentIndex === index ? Theme.surface : "transparent"
                    Button {
                        id: entry
                        objectName: "work-entry-" + row.index
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: root.mail ? 92 : parent.height
                        padding: 10
                        hoverEnabled: true
                        focusPolicy: Qt.NoFocus
                        Accessible.name: root.mail ? row.modelData.subject : row.modelData.title
                        onClicked: root.openRow(row.modelData)
                        background: Rectangle { radius: 10; color: entry.hovered ? Theme.hover : "transparent" }
                        contentItem: Column {
                            spacing: 5
                            Text {
                                width: parent.width
                                text: root.mail ? row.modelData.sender : row.modelData.title
                                textFormat: Text.PlainText
                                color: Theme.text
                                elide: Text.ElideRight
                                font { family: Theme.fontFamily; pixelSize: 12; bold: true }
                            }
                            Text {
                                width: parent.width
                                text: root.mail ? row.modelData.subject : root.rowTime(row.modelData)
                                textFormat: Text.PlainText
                                color: Theme.subtext
                                elide: Text.ElideRight
                                font { family: Theme.fontFamily; pixelSize: 11 }
                            }
                            Text {
                                width: parent.width
                                visible: root.mail
                                text: row.modelData.preview || ""
                                textFormat: Text.PlainText
                                color: Theme.subtext
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                font { family: Theme.fontFamily; pixelSize: 11 }
                            }
                        }
                    }
                    RowLayout {
                        visible: root.mail
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 6; bottomMargin: 4 }
                        Text {
                            Layout.fillWidth: true
                            text: root.rowTime(row.modelData) + (row.modelData.group ? " · " + row.modelData.group : "")
                            color: Theme.muted
                            elide: Text.ElideRight
                            font { family: Theme.fontFamily; pixelSize: 10 }
                        }
                        CalendarAction {
                            objectName: "work-read-" + row.index
                            implicitHeight: 26
                            enabled: GoogleWorkState.gmail.canMarkRead && !row.busy
                            opacity: enabled ? 1 : 0.5
                            text: row.busy ? "Saving…" : "Mark as read"
                            onClicked: GoogleWorkState.send({action: "read", id: row.modelData.id})
                        }
                    }
                }
            }
            CalendarAction {
                visible: root.mail && !!root.state.hasMore
                text: root.state.loading ? "Loading…" : "Load more"
                enabled: !root.state.loading
                onClicked: GoogleWorkState.send({action: "more"})
            }
        }
    }
}
