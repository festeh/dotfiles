pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "VolumeLogic.js" as VolumeLogic

PopupWindow {
    id: root
    required property Item anchorItem
    property var dragNode: null
    property var requestedOutput: null
    property string message: ""
    signal dismissed()

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 6
    grabFocus: true
    color: "transparent"
    implicitWidth: 340
    implicitHeight: column.implicitHeight + 28

    onVisibleChanged: if (!visible) dismissed()
    onBackingWindowVisibleChanged: if (backingWindowVisible) slider.forceActiveFocus(Qt.PopupFocusReason)

    function choose(output): void {
        if (output === VolumeState.node) return;
        message = "";
        if (VolumeState.selectOutput(output)) {
            requestedOutput = output;
            switchTimeout.restart();
        } else {
            message = "This output is no longer available.";
        }
    }
    Connections {
        target: VolumeState
        function onNodeChanged(): void {
            if (root.requestedOutput === VolumeState.node) {
                root.requestedOutput = null;
                switchTimeout.stop();
            }
        }
        function onOutputsChanged(): void {
            if (root.requestedOutput && !VolumeState.outputs.includes(root.requestedOutput)) {
                root.requestedOutput = null;
                root.message = "This output is no longer available.";
                switchTimeout.stop();
            }
        }
    }
    Timer {
        id: switchTimeout
        interval: 5000
        onTriggered: {
            root.requestedOutput = null;
            root.message = "The output did not become active. Try another output.";
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.surface
        border { width: 1; color: Theme.border }
    }
    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false
        Column {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 12

            RowLayout {
                width: parent.width
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: "Sound"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: 15; bold: true }
                }
                CalendarAction {
                    text: VolumeState.status.muted ? "Unmute" : "Mute"
                    enabled: VolumeState.status.known
                    opacity: enabled ? 1 : 0.4
                    onClicked: VolumeState.toggleMute()
                }
                CalendarAction { text: "×"; Accessible.name: "Close sound controls"; onClicked: root.visible = false }
            }
            Text {
                width: parent.width
                text: VolumeState.status.known ? VolumeState.status.name : VolumeState.status.tooltip
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.subtext
                font { family: Theme.fontFamily; pixelSize: 11 }
            }
            RowLayout {
                width: parent.width
                spacing: 12
                Slider {
                    id: slider
                    objectName: "volume-slider"
                    Layout.fillWidth: true
                    implicitHeight: 30
                    from: 0
                    to: 1
                    stepSize: 0.02
                    live: true
                    wheelEnabled: true
                    enabled: VolumeState.status.known
                    leftPadding: 6
                    rightPadding: 6
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: "Output volume"
                    onPressedChanged: root.dragNode = pressed ? VolumeState.node : null
                    onMoved: {
                        if (!pressed || root.dragNode === VolumeState.node)
                            VolumeState.setVolume(value, pressed ? root.dragNode : VolumeState.node);
                    }
                    background: Rectangle {
                        x: slider.leftPadding + 6
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: Math.max(0, slider.availableWidth - 12)
                        height: 4
                        radius: 2
                        color: Theme.base
                        Rectangle {
                            width: parent.width * slider.visualPosition
                            height: parent.height
                            radius: 2
                            color: VolumeState.status.muted ? Theme.muted : Theme.accent
                        }
                    }
                    handle: Rectangle {
                        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: 12
                        height: 12
                        radius: 6
                        color: slider.pressed ? Theme.text : VolumeState.status.muted ? Theme.subtext : Theme.accent
                        border { width: slider.visualFocus ? 2 : 0; color: Theme.text }
                    }
                    Binding {
                        target: slider
                        property: "value"
                        value: Math.max(0, Math.min(1, VolumeState.status.level))
                        when: !slider.pressed
                        restoreMode: Binding.RestoreNone
                    }
                }
                Text {
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                    text: VolumeState.status.label
                    color: VolumeState.status.muted ? Theme.subtext : Theme.text
                    font { family: Theme.fontFamily; pixelSize: 13 }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Text {
                text: "Output"
                color: Theme.subtext
                font { family: Theme.fontFamily; pixelSize: 11 }
            }
            ListView {
                id: outputs
                width: parent.width
                height: Math.min(contentHeight, 264)
                model: VolumeState.outputs
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    width: 4
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 4; implicitHeight: 24; radius: 2; color: Theme.border }
                    background: Item {}
                }
                delegate: Button {
                    id: output
                    required property var modelData
                    width: outputs.width - (outputs.contentHeight > outputs.height ? 8 : 0)
                    height: 40
                    padding: 0
                    leftInset: 0
                    rightInset: 0
                    topInset: 0
                    bottomInset: 0
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    enabled: VolumeState.ready
                    Accessible.name: VolumeLogic.name(modelData) + (modelData === VolumeState.node ? ", Current output" : "")
                    onClicked: root.choose(modelData)
                    background: Rectangle {
                        radius: 9
                        color: output.hovered || output.down || output.visualFocus ? Theme.hover
                            : output.modelData === VolumeState.node ? Theme.base : "transparent"
                        border.width: output.modelData === VolumeState.node || output.visualFocus ? 1 : 0
                        border.color: output.visualFocus ? Theme.accent : Theme.border
                    }
                    contentItem: Text {
                        text: VolumeLogic.name(output.modelData)
                        textFormat: Text.PlainText
                        leftPadding: 10
                        rightPadding: 10
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        color: output.modelData === VolumeState.node ? Theme.accent : Theme.text
                        font { family: Theme.fontFamily; pixelSize: 12 }
                    }
                }
            }
            Text {
                width: parent.width
                visible: VolumeState.outputs.length === 0
                text: VolumeState.ready ? "No audio outputs" : "Connecting to audio…"
                color: Theme.subtext
                font { family: Theme.fontFamily; pixelSize: 12 }
            }
            Text {
                width: parent.width
                visible: root.requestedOutput !== null || root.message.length > 0
                text: root.message || "Switching output…"
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Theme.subtext
                font { family: Theme.fontFamily; pixelSize: 11 }
            }
        }
    }
}
