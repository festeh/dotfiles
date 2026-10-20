pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

FocusScope {
    id: root
    required property string kind
    property var monitor: null
    property bool keyboardNavigation: false
    readonly property bool popupOpen: GoogleWorkState.popupOwner === root
    readonly property var popupItem: popupLoader.item
    readonly property var provider: kind === "gmail" ? GoogleWorkState.gmail : GoogleWorkState.calendar
    readonly property bool highlighted: keyboardNavigation ? activeFocus : mouse.containsMouse
    readonly property string labelText: kind === "gmail"
        ? Number(provider.unread) > 0 ? String(provider.unread) : "" : GoogleWorkState.calendarView.label
    readonly property string iconName: kind === "gmail" ? "mail" : GoogleWorkState.calendarView.icon
    readonly property bool attention: GoogleWorkState.transportError.length > 0
        || ["auth", "error", "setup", "stale"].includes(provider.status)
    readonly property string tooltip: attention ? GoogleWorkState.transportError || provider.message || "Work data is out of date" : kind === "gmail"
        ? provider.unread === null || provider.unread === undefined ? "Work Gmail" : provider.unread + " unread work messages"
        : GoogleWorkState.calendarView.tooltip
    property bool tooltipReady: false
    signal pointerInteraction()
    signal keyboardInteraction()
    objectName: "work-" + kind
    implicitWidth: content.implicitWidth + 20
    implicitHeight: Theme.buttonSize + 12
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Accessible.description: "Open " + (kind === "gmail" ? "message previews" : "meetings")
    Accessible.onPressAction: togglePopup()

    function togglePopup(): void {
        if (popupOpen) GoogleWorkState.hide(root);
        else GoogleWorkState.show(root);
    }

    onHighlightedChanged: {
        tooltipReady = false;
        if (highlighted) tooltipDelay.restart();
        else tooltipDelay.stop();
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
        spacing: root.labelText ? 6 : 0
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 18
            source: Qt.resolvedUrl("assets/work-" + root.iconName + ".svg")
            opacity: root.attention || root.provider.status === "loading" ? 0.5 : 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.labelText
            visible: text.length > 0
            color: root.attention ? Theme.attention : root.popupOpen
                || root.kind === "gmail" && Number(root.provider.unread) > 0
                || root.kind === "calendar" && GoogleWorkState.calendarView.active ? Theme.accent : Theme.text
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
                GoogleWorkState.hide(root);
                GoogleWorkState.send({action: "open", kind: root.kind});
            } else root.togglePopup();
        }
    }
    Keys.onPressed: event => {
        root.keyboardInteraction();
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space, Qt.Key_Down].includes(event.key)) {
            root.togglePopup(); event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            GoogleWorkState.hide(root); event.accepted = true;
        }
    }
    Connections {
        target: GoogleWorkState
        function onPopupRequested(kind: string): void {
            if (kind === root.kind && Quickshell.screens[0] === root.monitor)
                GoogleWorkState.show(root);
        }
    }
    Timer { id: tooltipDelay; interval: 500; onTriggered: root.tooltipReady = true }
    TrayTooltip {
        anchorItem: root
        title: root.tooltip
        visible: root.highlighted && root.tooltipReady && !root.popupOpen && !mouse.pressed
    }
    Loader {
        id: popupLoader
        active: root.popupOpen
        sourceComponent: GoogleWorkPopup {
            anchorItem: root
            kind: root.kind
            visible: true
            onDismissed: GoogleWorkState.hide(root)
        }
    }
}
