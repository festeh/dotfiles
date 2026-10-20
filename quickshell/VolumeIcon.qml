import QtQuick
import QtQuick.Shapes

Item {
    id: root
    required property int level
    required property bool muted
    required property bool known
    required property color foreground
    implicitWidth: 20
    implicitHeight: 20

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 2
            strokeColor: root.foreground
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: 1.5; startY: 7
            PathLine { x: 4.5; y: 7 }
            PathLine { x: 8.5; y: 3.5 }
            PathLine { x: 8.5; y: 16.5 }
            PathLine { x: 4.5; y: 13 }
            PathLine { x: 1.5; y: 13 }
            PathLine { x: 1.5; y: 7 }
        }
        ShapePath {
            strokeWidth: 2
            strokeColor: root.known && !root.muted && root.level >= 1 ? root.foreground : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 8; centerY: 10; radiusX: 4; radiusY: 4; startAngle: 315; sweepAngle: 90 }
        }
        ShapePath {
            strokeWidth: 2
            strokeColor: root.known && !root.muted && root.level >= 2 ? root.foreground : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 8; centerY: 10; radiusX: 7; radiusY: 7; startAngle: 315; sweepAngle: 90 }
        }
        ShapePath {
            strokeWidth: 2
            strokeColor: root.known && !root.muted && root.level >= 3 ? root.foreground : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 8; centerY: 10; radiusX: 10; radiusY: 10; startAngle: 315; sweepAngle: 90 }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.known && root.muted
        ShapePath {
            strokeWidth: 2; strokeColor: root.foreground; capStyle: ShapePath.RoundCap
            startX: 12.5; startY: 7
            PathLine { x: 18.5; y: 13 }
        }
        ShapePath {
            strokeWidth: 2; strokeColor: root.foreground; capStyle: ShapePath.RoundCap
            startX: 12.5; startY: 13
            PathLine { x: 18.5; y: 7 }
        }
    }
    Text {
        x: 12; y: 3; width: 8; height: 14
        visible: !root.known
        text: "?"
        color: root.foreground
        font { family: Theme.fontFamily; pixelSize: 12; bold: true }
    }
}
