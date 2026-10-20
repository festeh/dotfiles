pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: root
    property bool keyboardNavigation: false
    readonly property bool highlighted: keyboardNavigation ? activeFocus : mouse.containsMouse
    readonly property bool wantsTooltip: highlighted && !mouse.pressed
    property bool tooltipReady: false
    signal pointerInteraction()
    signal keyboardInteraction()

    objectName: "layout-widget"
    visible: LayoutState.status.ready && LayoutState.status.russian
    implicitWidth: 44
    implicitHeight: Theme.buttonSize + 12
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Keyboard layout: " + LayoutState.status.name
    Accessible.description: "Switch to the next keyboard layout"
    Accessible.onPressAction: LayoutState.cycle()

    onWantsTooltipChanged: {
        tooltipReady = false;
        if (wantsTooltip) tooltipDelay.restart();
        else tooltipDelay.stop();
    }
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.highlighted ? Theme.hover : Theme.surface
        border.width: root.keyboardNavigation && root.activeFocus ? 1 : 0
        border.color: Theme.accent
    }
    Image {
        anchors.centerIn: parent
        width: 24; height: 18
        source: "assets/lettermarks/ru.svg"
        fillMode: Image.PreserveAspectFit
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
            LayoutState.cycle();
        }
    }
    Keys.onPressed: event => {
        root.keyboardInteraction();
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            LayoutState.cycle();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.focus = false;
            event.accepted = true;
        }
    }
    Timer { id: tooltipDelay; interval: 500; onTriggered: root.tooltipReady = true }
    TrayTooltip {
        anchorItem: root
        title: LayoutState.error || LayoutState.status.tooltip
        visible: root.wantsTooltip && root.tooltipReady
    }
}
