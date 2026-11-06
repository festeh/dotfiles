pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: root
    property bool keepAwake: false
    property bool keyboardNavigation: false
    readonly property bool highlighted: keyboardNavigation ? activeFocus : mouse.containsMouse
    readonly property bool wantsTooltip: highlighted && !mouse.pressed
    property bool tooltipReady: false
    signal activated()
    signal pointerInteraction()
    signal keyboardInteraction()

    objectName: "keep-awake-widget"
    visible: keepAwake
    implicitWidth: 40
    implicitHeight: Theme.buttonSize + 12
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Stay awake is on. Automatic sleep is paused."
    Accessible.description: "Open sleep behavior settings"
    Accessible.onPressAction: root.activated()

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
        width: 22
        height: 22
        source: "assets/keep-awake.svg"
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
            root.activated();
        }
    }
    Keys.onPressed: event => {
        root.keyboardInteraction();
        if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
            root.activated();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.focus = false;
            event.accepted = true;
        }
    }
    Timer { id: tooltipDelay; interval: 500; onTriggered: root.tooltipReady = true }
    TrayTooltip {
        anchorItem: root
        title: root.Accessible.name
        visible: root.visible && root.wantsTooltip && root.tooltipReady
    }
}
