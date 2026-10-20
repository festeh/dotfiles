import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

FocusScope {
    id: root
    required property SystemTrayItem item
    property bool keyboardNavigation: false
    readonly property string label: item.tooltipTitle || item.title || item.id || "Application"
    readonly property bool needsAttention: item.status === Status.NeedsAttention
    readonly property bool hovered: !keyboardNavigation && mouse.containsMouse
    readonly property bool keyboardFocused: keyboardNavigation && activeFocus
    readonly property bool wantsTooltip: (hovered || keyboardFocused) && !menu.visible && !mouse.pressed
    property bool tooltipReady: false
    signal pointerInteraction()
    signal keyboardInteraction()
    signal focusStep(int step)
    signal focusEdge(bool last)

    implicitWidth: Theme.buttonSize
    implicitHeight: Theme.buttonSize
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: needsAttention ? "Needs attention" : "System tray application"
    Accessible.onPressAction: activatePrimary()

    onWantsTooltipChanged: {
        tooltipReady = false;
        if (wantsTooltip)
            tooltipDelay.restart();
        else
            tooltipDelay.stop();
    }

    function openMenu(): void {
        if (!item.hasMenu)
            return;
        if (menu.visible)
            menu.close();
        else
            menu.open();
    }

    function activatePrimary(): void {
        if (item.onlyMenu)
            openMenu();
        else
            item.activate();
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.hovered || root.keyboardFocused || menu.visible ? Theme.hover : "transparent"
        border.width: root.keyboardFocused || root.needsAttention ? 1 : 0
        border.color: root.needsAttention ? Theme.attention : Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    IconImage {
        id: icon
        anchors.centerIn: parent
        implicitSize: Theme.iconSize
        source: root.item.icon
        visible: status === Image.Ready
    }

    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
        width: 5
        height: 5
        radius: 3
        color: Theme.attention
        visible: root.needsAttention
    }

    QsMenuAnchor {
        id: menu
        menu: root.item.menu
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onEntered: root.pointerInteraction()
        onPositionChanged: root.pointerInteraction()
        onClicked: event => {
            root.pointerInteraction();
            root.forceActiveFocus(Qt.MouseFocusReason);
            if (event.button === Qt.LeftButton)
                root.activatePrimary();
            else if (event.button === Qt.MiddleButton)
                root.item.secondaryActivate();
            else if (event.button === Qt.RightButton)
                root.openMenu();
        }

        onWheel: event => {
            root.pointerInteraction();
            // Forward the native SNI delta, including smooth touchpad increments.
            if (event.angleDelta.y !== 0)
                root.item.scroll(event.angleDelta.y, false);
            if (event.angleDelta.x !== 0)
                root.item.scroll(event.angleDelta.x, true);
            event.accepted = true;
        }
    }

    Keys.onPressed: event => {
        root.keyboardInteraction();
        event.accepted = true;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
            root.activatePrimary();
        else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)))
            root.openMenu();
        else if (event.key === Qt.Key_Right)
            root.focusStep(1);
        else if (event.key === Qt.Key_Left)
            root.focusStep(-1);
        else if (event.key === Qt.Key_Home)
            root.focusEdge(false);
        else if (event.key === Qt.Key_End)
            root.focusEdge(true);
        else if (event.key === Qt.Key_Escape) {
            if (menu.visible)
                menu.close();
            root.focus = false;
        } else
            event.accepted = false;
    }

    Timer {
        id: tooltipDelay
        interval: 500
        onTriggered: root.tooltipReady = true
    }

    TrayTooltip {
        anchorItem: root
        title: root.label
        description: root.item.tooltipDescription
        visible: root.wantsTooltip && root.tooltipReady
    }
}
