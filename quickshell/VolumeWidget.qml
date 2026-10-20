pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: root
    property bool keyboardNavigation: false
    readonly property bool popupOpen: VolumeState.popupOwner === root
    readonly property bool highlighted: keyboardNavigation ? activeFocus : hover.hovered
    readonly property bool wantsTooltip: highlighted && !popupOpen
        && !contextMouse.pressed && !speaker.down && !decrease.down && !increase.down
    readonly property color foreground: !VolumeState.status.known ? Theme.muted
        : VolumeState.status.muted ? Theme.critical : Theme.text
    property bool tooltipReady: false
    signal pointerInteraction()
    signal keyboardInteraction()

    implicitWidth: controls.implicitWidth + 8
    implicitHeight: Theme.buttonSize + 12
    Accessible.role: Accessible.Grouping
    Accessible.name: "Volume"

    function togglePopup(): void {
        VolumeState.popupOwner = popupOpen ? null : root;
    }
    onWantsTooltipChanged: {
        tooltipReady = false;
        if (wantsTooltip) tooltipDelay.restart();
        else tooltipDelay.stop();
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.surface
    }
    Row {
        id: controls
        anchors.centerIn: parent
        spacing: 2
        VolumeAction {
            id: speaker
            objectName: "volume-mute"
            implicitWidth: 36
            emphasized: root.popupOpen
            keyboardNavigation: root.keyboardNavigation
            onKeyboardInteraction: root.keyboardInteraction()
            Accessible.name: VolumeState.status.tooltip
            Accessible.description: "Toggle mute. Right-click or press Down for sound controls."
            onClicked: VolumeState.toggleMute()
            contentItem: Item {
                VolumeIcon {
                    anchors.centerIn: parent
                    level: VolumeState.status.iconLevel
                    muted: VolumeState.status.muted
                    known: VolumeState.status.known
                    foreground: root.foreground
                }
            }
        }
        VolumeAction {
            id: decrease
            objectName: "volume-decrease"
            text: "−"
            keyboardNavigation: root.keyboardNavigation
            onKeyboardInteraction: root.keyboardInteraction()
            Accessible.name: "Decrease volume by 5%"
            enabled: VolumeState.status.known && VolumeState.status.level > 0
            onClicked: VolumeState.adjustVolume(-0.05)
        }
        VolumeAction {
            id: increase
            objectName: "volume-increase"
            text: "+"
            keyboardNavigation: root.keyboardNavigation
            onKeyboardInteraction: root.keyboardInteraction()
            Accessible.name: "Increase volume by 5%"
            enabled: VolumeState.status.known && VolumeState.status.level < 1
            onClicked: VolumeState.adjustVolume(0.05)
        }
    }
    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) root.pointerInteraction()
        onPointChanged: if (hovered) root.pointerInteraction()
    }
    MouseArea {
        id: contextMouse
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        onClicked: event => {
            root.pointerInteraction();
            speaker.forceActiveFocus(Qt.MouseFocusReason);
            if (event.button === Qt.RightButton) root.togglePopup();
            else VolumeState.toggleMute();
        }
    }
    WheelHandler {
        target: null
        onWheel: event => {
            const steps = event.angleDelta.y ? event.angleDelta.y / 120 : event.pixelDelta.y / 40;
            event.accepted = steps !== 0 && VolumeState.status.known;
            if (event.accepted) {
                root.pointerInteraction();
                VolumeState.adjustVolume(steps * 0.02);
            }
        }
    }
    Keys.onPressed: event => {
        root.keyboardInteraction();
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Menu
                || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            root.togglePopup();
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            VolumeState.toggleMute();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (root.popupOpen) VolumeState.popupOwner = null;
            root.focus = false;
            event.accepted = true;
        }
    }
    Timer { id: tooltipDelay; interval: 500; onTriggered: root.tooltipReady = true }
    TrayTooltip {
        anchorItem: root
        title: VolumeState.status.tooltip
        visible: root.wantsTooltip && root.tooltipReady
    }
    Loader {
        active: root.popupOpen
        sourceComponent: VolumePopup {
            anchorItem: root
            visible: true
            onDismissed: {
                if (VolumeState.popupOwner === root) VolumeState.popupOwner = null;
            }
        }
    }
}
