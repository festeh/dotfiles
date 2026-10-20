pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root
    required property string kind
    required property int level
    required property string marker
    required property color foreground
    property color background: Theme.surface
    implicitWidth: 20
    implicitHeight: 20

    Shape {
        visible: root.kind === "wifi"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 2.4
            strokeColor: root.level >= 3 ? root.foreground : Theme.muted
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 10; centerY: 17; radiusX: 12; radiusY: 12; startAngle: 225; sweepAngle: 90 }
        }
        ShapePath {
            strokeWidth: 2.4
            strokeColor: root.level >= 2 ? root.foreground : Theme.muted
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 10; centerY: 17; radiusX: 7; radiusY: 7; startAngle: 225; sweepAngle: 90 }
        }
    }
    Rectangle {
        x: 8.2; y: 15.2; width: 3.6; height: 3.6; radius: 1.8
        visible: root.kind === "wifi"
        color: root.foreground
    }

    Rectangle {
        x: 5; y: 1; width: 10; height: 18; radius: 2.5
        visible: root.kind === "phone"
        color: "transparent"
        border { color: root.foreground; width: 1.6 }
        Rectangle { x: 3.5; y: 13.5; width: 3; height: 1.5; radius: 0.75; color: root.foreground }
    }

    Shape {
        visible: root.kind === "wired"
        anchors.fill: parent
        ShapePath {
            strokeWidth: 1.6
            strokeColor: root.foreground
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: 3; startY: 3
            PathLine { x: 17; y: 3 }
            PathLine { x: 17; y: 12 }
            PathLine { x: 13; y: 12 }
            PathLine { x: 13; y: 17 }
            PathLine { x: 7; y: 17 }
            PathLine { x: 7; y: 12 }
            PathLine { x: 3; y: 12 }
            PathLine { x: 3; y: 3 }
        }
    }
    Row {
        x: 6; y: 5; spacing: 1.2
        visible: root.kind === "wired"
        Repeater { model: 4; Rectangle { width: 1.2; height: 4; color: root.foreground } }
    }

    Item {
        visible: root.kind === "other"
        anchors.fill: parent
        Rectangle { x: 8; y: 1; width: 5; height: 5; radius: 1; color: root.foreground }
        Rectangle { x: 9.5; y: 5; width: 1.5; height: 7; color: root.foreground }
        Rectangle { x: 3; y: 10; width: 14; height: 1.5; color: root.foreground }
        Rectangle { x: 1; y: 12; width: 5; height: 5; radius: 1; color: root.foreground }
        Rectangle { x: 14; y: 12; width: 5; height: 5; radius: 1; color: root.foreground }
    }

    Shape {
        visible: root.marker === "off"
        anchors.fill: parent
        ShapePath {
            strokeWidth: 3.8; strokeColor: root.background; capStyle: ShapePath.RoundCap
            startX: 3; startY: 3
            PathLine { x: 17; y: 18 }
        }
        ShapePath {
            strokeWidth: 1.6; strokeColor: root.foreground; capStyle: ShapePath.RoundCap
            startX: 3; startY: 3
            PathLine { x: 17; y: 18 }
        }
    }

    Rectangle {
        x: 13; y: 9; width: 8; height: 12; radius: 2
        visible: root.marker === "warning" || root.marker === "connecting" || root.marker === "unknown"
        color: root.background
        Text {
            anchors.centerIn: parent
            text: root.marker === "warning" ? "!" : root.marker === "connecting" ? "…" : "?"
            color: root.foreground
            font { family: Theme.fontFamily; pixelSize: 12; bold: true }
        }
    }
}
