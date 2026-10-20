pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "CalendarMath.js" as CalendarMath

PopupWindow {
    id: root
    required property Item anchorItem
    property date selectedDate: CalendarMath.normalized(ClockState.now)
    property date viewDate: CalendarMath.monthStart(selectedDate)
    signal dismissed()

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 6
    grabFocus: true
    color: "transparent"
    implicitWidth: 328
    implicitHeight: column.implicitHeight + 28

    onVisibleChanged: {
        if (visible)
            chooseToday();
        else
            dismissed();
    }
    onBackingWindowVisibleChanged: {
        if (backingWindowVisible)
            content.forceActiveFocus(Qt.PopupFocusReason);
    }

    function chooseDate(date: date): void {
        selectedDate = CalendarMath.normalized(date);
        viewDate = CalendarMath.monthStart(selectedDate);
        content.forceActiveFocus(Qt.OtherFocusReason);
    }

    function chooseToday(): void {
        ClockState.refresh();
        chooseDate(ClockState.now);
    }

    function stepMonth(amount: int): void {
        chooseDate(CalendarMath.addMonths(selectedDate, amount));
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.surface
        border { color: Theme.border; width: 1 }
    }

    FocusScope {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Escape)
                root.visible = false;
            else if (event.key === Qt.Key_Left)
                root.chooseDate(CalendarMath.addDays(root.selectedDate, -1));
            else if (event.key === Qt.Key_Right)
                root.chooseDate(CalendarMath.addDays(root.selectedDate, 1));
            else if (event.key === Qt.Key_Up)
                root.chooseDate(CalendarMath.addDays(root.selectedDate, -7));
            else if (event.key === Qt.Key_Down)
                root.chooseDate(CalendarMath.addDays(root.selectedDate, 7));
            else if (event.key === Qt.Key_PageUp)
                root.stepMonth(-1);
            else if (event.key === Qt.Key_PageDown)
                root.stepMonth(1);
            else if (event.key === Qt.Key_Home)
                root.chooseToday();
            else
                event.accepted = false;
        }

        Column {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 12

            RowLayout {
                width: parent.width
                spacing: 6

                CalendarAction {
                    text: "‹"
                    Accessible.name: "Previous month"
                    onClicked: root.stepMonth(-1)
                }

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: 15; bold: true }
                }

                CalendarAction {
                    text: "›"
                    Accessible.name: "Next month"
                    onClicked: root.stepMonth(1)
                }
            }

            Row {
                width: parent.width
                spacing: 4

                Repeater {
                    model: 7
                    Text {
                        required property int index
                        width: (column.width - 24) / 7
                        height: 20
                        text: Qt.locale().dayName(index + 1, Locale.ShortFormat)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.subtext
                        font { family: Theme.fontFamily; pixelSize: 11 }
                    }
                }
            }

            GridLayout {
                width: parent.width
                columns: 7
                rowSpacing: 4
                columnSpacing: 4

                Repeater {
                    model: CalendarMath.monthCells(root.viewDate)

                    CalendarAction {
                        id: day
                        required property date modelData
                        readonly property bool today: CalendarMath.sameDay(modelData, ClockState.now)
                        readonly property bool selected: CalendarMath.sameDay(modelData, root.selectedDate)
                        readonly property bool inMonth: modelData.getMonth() === root.viewDate.getMonth()
                        Layout.fillWidth: true
                        implicitWidth: 32
                        implicitHeight: 34
                        focusPolicy: Qt.NoFocus
                        Accessible.name: Qt.formatDate(modelData, "dddd, d MMMM yyyy")
                        onClicked: root.chooseDate(modelData)

                        background: Rectangle {
                            radius: 8
                            color: day.today ? Theme.accent : day.hovered || day.selected ? Theme.hover : "transparent"
                            border.width: day.selected && !day.today ? 1 : 0
                            border.color: Theme.accent
                        }

                        contentItem: Text {
                            text: day.modelData.getDate()
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: day.today ? Theme.base : day.inMonth ? Theme.text : Theme.muted
                            font { family: Theme.fontFamily; pixelSize: 13; bold: day.today }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hover
            }

            RowLayout {
                width: parent.width

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.selectedDate, "ddd, d MMM")
                    color: Theme.subtext
                    font { family: Theme.fontFamily; pixelSize: 12 }
                }

                CalendarAction {
                    text: "Today"
                    emphasized: true
                    onClicked: root.chooseToday()
                }
            }
        }
    }
}
