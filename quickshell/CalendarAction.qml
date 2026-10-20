import QtQuick
import QtQuick.Controls

Button {
    id: root
    property bool emphasized: false
    implicitWidth: Math.max(30, contentItem.implicitWidth + 18)
    implicitHeight: 30
    padding: 0
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        radius: 7
        color: root.down ? Theme.border : root.hovered || root.visualFocus || root.emphasized ? Theme.hover : "transparent"
        border.width: root.visualFocus ? 1 : 0
        border.color: Theme.accent
    }

    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        color: root.hovered || root.visualFocus ? Theme.accent : Theme.text
        font { family: Theme.fontFamily; pixelSize: 13 }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
