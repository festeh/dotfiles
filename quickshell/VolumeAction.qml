import QtQuick
import QtQuick.Controls

Button {
    id: root
    property bool emphasized: false
    property bool keyboardNavigation: false
    readonly property color symbolColor: hovered || (keyboardNavigation && activeFocus) ? Theme.accent : Theme.text
    signal keyboardInteraction()
    implicitWidth: 32
    implicitHeight: 32
    padding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : 0.4
    Keys.onPressed: event => {
        root.keyboardInteraction();
        event.accepted = false;
    }
    background: Rectangle {
        radius: 7
        color: root.down ? Theme.border
            : root.hovered || root.emphasized
                || (root.keyboardNavigation && root.activeFocus) ? Theme.hover : "transparent"
        border.width: root.keyboardNavigation && root.activeFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    // Match AGS's 16px symbolic icons: 14px bars with a 2px stroke.
    contentItem: Item {
        implicitWidth: 16
        implicitHeight: 16
        Rectangle {
            anchors.centerIn: parent
            width: 14
            height: 2
            color: root.symbolColor
        }
        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: 14
            color: root.symbolColor
            visible: root.text === "+"
        }
    }
}
