pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: root
    property bool keyboardNavigation: false
    readonly property bool highlighted: keyboardNavigation ? activeFocus : mouse.containsMouse
    readonly property color foreground: !BatteryState.status.known ? Theme.subtext
        : BatteryState.status.marker === "charging" || BatteryState.status.marker === "plugged" ? Theme.positive
        : BatteryState.status.severity === "critical" ? Theme.critical
        : BatteryState.status.severity === "low" && BatteryState.status.level <= 0.10 ? Theme.warning
        : BatteryState.status.severity === "low" ? Theme.attention : Theme.text
    property bool tooltipReady: false
    signal pointerInteraction()
    signal keyboardInteraction()

    visible: BatteryState.status.visible
    implicitWidth: 24 + icon.implicitWidth
    implicitHeight: Theme.buttonSize + 12
    activeFocusOnTab: true
    Accessible.role: Accessible.StaticText
    Accessible.name: "Battery " + BatteryState.status.label + ", " + BatteryState.status.tooltip

    onHighlightedChanged: {
        tooltipReady = false;
        if (highlighted)
            tooltipDelay.restart();
        else
            tooltipDelay.stop();
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.highlighted ? Theme.hover : Theme.surface
        border.width: root.keyboardNavigation && root.activeFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    BatteryIcon {
        id: icon
        anchors.centerIn: parent
        level: BatteryState.status.marker === "plugged" ? 1 : BatteryState.status.level
        known: BatteryState.status.known
        marker: BatteryState.status.marker
        foreground: root.foreground
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.pointerInteraction()
        onPositionChanged: root.pointerInteraction()
    }

    Keys.onPressed: event => {
        root.keyboardInteraction();
        if (event.key === Qt.Key_Escape) {
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
        title: BatteryState.status.known
            ? BatteryState.status.label + " · " + BatteryState.status.tooltip
            : BatteryState.status.tooltip
        visible: root.highlighted && root.tooltipReady
    }
}
