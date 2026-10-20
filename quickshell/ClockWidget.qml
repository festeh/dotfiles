pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: root
    property bool keyboardNavigation: false
    property bool calendarOpen: false
    readonly property bool highlighted: keyboardNavigation ? activeFocus : mouse.containsMouse
    readonly property bool wantsTooltip: highlighted && !calendarOpen && !mouse.pressed
    property bool tooltipReady: false
    signal pointerInteraction()
    signal keyboardInteraction()

    implicitWidth: Math.ceil(metrics.advanceWidth) + 24
    implicitHeight: Theme.buttonSize + 12
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: ClockState.timeText + ", " + ClockState.fullDate
    Accessible.description: "Open calendar"
    Accessible.onPressAction: toggleCalendar()

    function toggleCalendar(): void {
        ClockState.refresh();
        calendarOpen = !calendarOpen;
    }

    onWantsTooltipChanged: {
        tooltipReady = false;
        if (wantsTooltip)
            tooltipDelay.restart();
        else
            tooltipDelay.stop();
    }

    TextMetrics {
        id: metrics
        text: ClockState.timeText
        font: label.font
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.highlighted || root.calendarOpen ? Theme.hover : Theme.surface
        border.width: root.keyboardNavigation && root.activeFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: ClockState.timeText
            color: root.calendarOpen ? Theme.accent : Theme.text
            font { family: Theme.fontFamily; pixelSize: 14 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.pointerInteraction()
        onPositionChanged: root.pointerInteraction()
        onClicked: {
            root.pointerInteraction();
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.toggleCalendar();
        }
    }

    Keys.onPressed: event => {
        root.keyboardInteraction();
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            root.toggleCalendar();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.calendarOpen = false;
            root.focus = false;
            event.accepted = true;
        }
    }

    Timer {
        id: tooltipDelay
        interval: 500
        onTriggered: root.tooltipReady = true
    }

    TrayTooltip {
        anchorItem: root
        title: ClockState.fullDate
        visible: root.wantsTooltip && root.tooltipReady
    }

    // Create the calendar only while it is open.
    Loader {
        active: root.calendarOpen
        sourceComponent: CalendarPopup {
            anchorItem: root
            visible: true
            onDismissed: root.calendarOpen = false
        }
    }
}
