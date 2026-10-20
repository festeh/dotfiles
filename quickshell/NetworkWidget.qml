pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: root
    property bool keyboardNavigation: false
    readonly property bool pickerOpen: NetworkState.pickerOwner === root
    readonly property bool highlighted: keyboardNavigation ? activeFocus : mouse.containsMouse
    readonly property bool wantsTooltip: highlighted && !pickerOpen && !mouse.pressed
    readonly property var status: NetworkState.status
    readonly property color foreground: status.severity === "critical" ? Theme.critical
        : status.severity === "attention" ? Theme.attention
        : status.severity === "accent" ? Theme.accent
        : status.severity === "muted" ? Theme.muted : Theme.text
    property bool tooltipReady: false
    signal pointerInteraction()
    signal keyboardInteraction()

    implicitWidth: 44
    implicitHeight: Theme.buttonSize + 12
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: status.tooltip
    Accessible.description: "Open Wi-Fi picker"
    Accessible.onPressAction: togglePicker()

    function togglePicker(): void {
        NetworkState.pickerOwner = pickerOpen ? null : root;
    }

    onWantsTooltipChanged: {
        tooltipReady = false;
        if (wantsTooltip)
            tooltipDelay.restart();
        else
            tooltipDelay.stop();
    }

    Rectangle {
        id: pillBackground
        anchors.fill: parent
        radius: 10
        color: root.highlighted || root.pickerOpen ? Theme.hover : Theme.surface
        border.width: root.keyboardNavigation && root.activeFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    NetworkIcon {
        anchors.centerIn: parent
        kind: root.status.kind
        level: root.status.level
        marker: root.status.marker
        foreground: root.foreground
        background: pillBackground.color
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
            root.togglePicker();
        }
    }

    Keys.onPressed: event => {
        root.keyboardInteraction();
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            root.togglePicker();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (root.pickerOpen)
                NetworkState.pickerOwner = null;
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
        title: root.status.tooltip
        visible: root.wantsTooltip && root.tooltipReady
    }

    Loader {
        active: root.pickerOpen
        sourceComponent: NetworkPopup {
            anchorItem: root
            visible: true
            onDismissed: {
                if (NetworkState.pickerOwner === root)
                    NetworkState.pickerOwner = null;
            }
        }
    }
}
