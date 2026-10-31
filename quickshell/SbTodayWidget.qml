pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

// Today's open tasks from sb: a checklist and a count, red while anything is
// overdue. Hidden when nothing is left and while sb is not running.
FocusScope {
    id: root
    property var monitor: null
    property bool keyboardNavigation: false
    readonly property var counts: SbTodayState.summary
    readonly property bool popupOpen: SbTodayState.popupOwner === root
    readonly property var popupItem: popupLoader.item
    readonly property bool highlighted: keyboardNavigation ? activeFocus : mouse.containsMouse
    readonly property string labelText: String(counts.open)
    readonly property bool overdue: counts.overdue > 0
    signal pointerInteraction()
    signal keyboardInteraction()
    objectName: "sb-today"
    visible: SbTodayState.available && counts.open > 0
    implicitWidth: content.implicitWidth + 20
    implicitHeight: Theme.buttonSize + 12
    activeFocusOnTab: visible
    Accessible.role: Accessible.Button
    Accessible.name: counts.open + (counts.open === 1 ? " task" : " tasks") + " today"
        + (overdue ? ", " + counts.overdue + " overdue" : "")
    Accessible.description: "Open today's tasks"
    Accessible.onPressAction: togglePopup()
    onVisibleChanged: if (!visible) SbTodayState.hide(root)

    function togglePopup(): void {
        if (popupOpen) SbTodayState.hide(root);
        else SbTodayState.show(root);
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.highlighted || root.popupOpen ? Theme.hover : Theme.surface
        border.width: root.keyboardNavigation && root.activeFocus ? 1 : 0
        border.color: Theme.accent
    }
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 18
            source: Qt.resolvedUrl("assets/sb-checklist.svg")
        }
        Text {
            objectName: "sb-today-count"
            anchors.verticalCenter: parent.verticalCenter
            text: root.labelText
            color: root.overdue ? Theme.critical : Theme.accent
            font { family: Theme.fontFamily; pixelSize: 13 }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: root.pointerInteraction()
        onClicked: event => {
            root.pointerInteraction();
            root.forceActiveFocus(Qt.MouseFocusReason);
            if (event.button === Qt.RightButton) {
                SbTodayState.hide(root);
                SbTodayState.openTasks();
            } else root.togglePopup();
        }
    }
    Keys.onPressed: event => {
        root.keyboardInteraction();
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space, Qt.Key_Down].includes(event.key)) {
            root.togglePopup(); event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            SbTodayState.hide(root); event.accepted = true;
        }
    }
    Connections {
        target: SbTodayState
        function onPopupRequested(): void {
            if (root.visible && Quickshell.screens[0] === root.monitor) SbTodayState.show(root);
        }
    }
    Loader {
        id: popupLoader
        active: root.popupOpen
        sourceComponent: SbTodayPopup {
            anchorItem: root
            visible: true
            onDismissed: SbTodayState.hide(root)
        }
    }
}
