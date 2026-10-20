import QtQuick

Item {
    id: root
    required property real level
    required property bool known
    required property string marker
    required property color foreground
    implicitWidth: 12
    implicitHeight: 20

    Rectangle {
        x: 0; y: 3
        width: 12; height: 17
        radius: 2
        color: "transparent"
        border { width: 1; color: root.foreground }
    }

    Rectangle {
        x: 3; y: 0
        width: 6; height: 2
        radius: 0.75
        color: root.foreground
    }

    Rectangle {
        x: 2; y: 5 + 13 * (1 - root.level)
        width: 8; height: 13 * root.level
        radius: 1
        color: root.foreground
        visible: root.known
    }

    Rectangle {
        x: 1; y: 5
        width: 10; height: 12
        radius: 2
        color: Theme.surface
        visible: root.marker === "plugged"

        Rectangle { x: 2; y: 1; width: 2; height: 4; color: root.foreground }
        Rectangle { x: 6; y: 1; width: 2; height: 4; color: root.foreground }
        Rectangle { x: 1; y: 4; width: 8; height: 4; radius: 1.5; color: root.foreground }
        Rectangle { x: 4; y: 7; width: 2; height: 4; color: root.foreground }
    }

    Text {
        x: 0; y: 3
        width: 12; height: 17
        visible: root.marker === "unknown"
        text: "?"
        color: root.foreground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font { family: Theme.fontFamily; pixelSize: 11 }
    }
}
