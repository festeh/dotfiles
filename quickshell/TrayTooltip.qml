import QtQuick
import Quickshell

PopupWindow {
    id: root
    required property Item anchorItem
    required property string title
    property string description: ""
    readonly property string singleLineTitle: title.replace(/\s+/g, " ").trim()
    readonly property string singleLineDescription: description.replace(/\s+/g, " ").trim()

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 4
    color: "transparent"
    implicitWidth: Math.min(600, Math.ceil(metrics.advanceWidth) + 12)
    implicitHeight: Math.ceil(metrics.height) + 6

    // Measure independently of the elided label's assigned width.
    TextMetrics {
        id: metrics
        font: label.font
        text: label.text
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border { color: Theme.border; width: 1 }
        radius: 6

        Text {
            id: label
            anchors { fill: parent; leftMargin: 6; rightMargin: 6; topMargin: 3; bottomMargin: 3 }
            text: root.singleLineDescription.length > 0 && root.singleLineDescription !== root.singleLineTitle
                ? root.singleLineTitle + " · " + root.singleLineDescription
                : root.singleLineTitle
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: Theme.text
            font { family: Theme.fontFamily; pixelSize: 12 }
        }
    }
}
