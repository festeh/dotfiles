pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import "NotificationLogic.js" as Logic

Rectangle {
    id: root
    required property var entry
    property int maximumHeight: 500
    readonly property var notification: entry.notification
    readonly property string appName: Logic.text(notification.appName || notification.desktopEntry || "Notification", 120)
    readonly property string title: Logic.text(notification.summary || appName, 500)
    readonly property string body: Logic.text(notification.body, 8000)
    readonly property var defaultAction: notification.actions.find(action => action.identifier === "default")
    readonly property var actions: notification.actions.filter(action => action.identifier !== "default" && action.text.trim())
    readonly property real progress: Logic.progress(notification.hints)
    readonly property bool hovered: hover.hovered
    property real timeoutProgress: 0
    property real timeoutDeadline: -1
    readonly property Region inputRegion: Region { item: root; radius: root.radius }
    signal hoverLeft()
    signal dismissRequested()
    signal actionRequested(string identifier)
    objectName: "notification-card-" + entry.id
    implicitWidth: 360
    implicitHeight: Math.min(column.implicitHeight + 28, maximumHeight)
    radius: 12
    color: hovered ? Theme.hover : Theme.surface
    border { width: 1; color: hovered ? Theme.border : "#45475a" }
    Accessible.role: Accessible.Pane
    Accessible.name: appName + ": " + title
    Accessible.description: body

    function syncTimeout(): void {
        const now = Date.now();
        const elapsed = Logic.elapsed(entry, now);
        // Qt's animation clock and the expiration clock can finish on different
        // frames. Reconciliation must never rewind or restart a completed lap.
        // A replacement has a new deadline and deliberately starts a new lap.
        const position = entry.deadline === timeoutDeadline ? Math.max(timeoutProgress, elapsed) : elapsed;
        timeoutFill.stop();
        timeoutProgress = position;
        timeoutDeadline = entry.deadline;
        if (entry.deadline > now && position < 1) {
            timeoutFill.from = timeoutProgress;
            timeoutFill.duration = Math.max(1, Math.ceil(entry.deadline - now));
            timeoutFill.start();
        }
    }
    onEntryChanged: Qt.callLater(syncTimeout)
    Component.onCompleted: syncTimeout()
    NumberAnimation {
        id: timeoutFill
        target: root
        property: "timeoutProgress"
        to: 1
    }
    Connections {
        target: NotificationState
        function onClockReconciled(): void { root.syncTimeout(); }
    }
    Shape {
        id: timeoutBorder
        objectName: "notification-timeout"
        anchors.fill: parent
        z: 1
        readonly property real inset: 0.75
        readonly property real corner: root.radius - inset
        preferredRendererType: Shape.CurveRenderer
        visible: root.entry.deadline > 0
        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            // Native path trimming follows distance around the rounded border.
            // Begin at the top center and complete one lap at the deadline.
            trim.end: root.timeoutProgress
            startX: root.width / 2
            startY: timeoutBorder.inset
            PathLine { x: root.width - root.radius; y: timeoutBorder.inset }
            PathArc {
                x: root.width - timeoutBorder.inset; y: root.radius
                radiusX: timeoutBorder.corner; radiusY: timeoutBorder.corner
            }
            PathLine { x: root.width - timeoutBorder.inset; y: root.height - root.radius }
            PathArc {
                x: root.width - root.radius; y: root.height - timeoutBorder.inset
                radiusX: timeoutBorder.corner; radiusY: timeoutBorder.corner
            }
            PathLine { x: root.radius; y: root.height - timeoutBorder.inset }
            PathArc {
                x: timeoutBorder.inset; y: root.height - root.radius
                radiusX: timeoutBorder.corner; radiusY: timeoutBorder.corner
            }
            PathLine { x: timeoutBorder.inset; y: root.radius }
            PathArc {
                x: root.radius; y: timeoutBorder.inset
                radiusX: timeoutBorder.corner; radiusY: timeoutBorder.corner
            }
            PathLine { x: root.width / 2; y: timeoutBorder.inset }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: { if (!hovered) root.hoverLeft(); }
    }

    Flickable {
        anchors { fill: parent; margins: 14 }
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: column
            width: parent.width
            spacing: 8

            RowLayout {
                width: parent.width
                spacing: 8
                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    readonly property string icon: {
                        const value = String(root.notification.appIcon || "");
                        if (value.startsWith("/")) return "file://" + value;
                        if (value.startsWith("file:") || value.startsWith("image:")) return value;
                        return value ? Quickshell.iconPath(value, true) : "";
                    }
                    IconImage {
                        id: appIcon
                        anchors.centerIn: parent
                        implicitSize: 24
                        source: parent.icon
                        visible: status === Image.Ready
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 20
                        source: Qt.resolvedUrl("assets/notification.svg")
                        visible: appIcon.status !== Image.Ready
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.appName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.subtext
                    font { family: Theme.fontFamily; pixelSize: 11 }
                }
                Rectangle {
                    visible: root.entry.critical
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.critical
                    Accessible.name: "Critical notification"
                }
                Text {
                    text: Logic.age(root.entry.arrived, ClockState.now.getTime())
                    textFormat: Text.PlainText
                    color: Theme.muted
                    font { family: Theme.fontFamily; pixelSize: 10 }
                }
                Button {
                    id: close
                    objectName: "notification-close"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    padding: 0
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    Accessible.name: "Dismiss notification"
                    onClicked: root.dismissRequested()
                    background: Rectangle { radius: 7; color: close.hovered ? Theme.border : "transparent" }
                    contentItem: Item {
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 14
                            source: Qt.resolvedUrl("assets/close.svg")
                            opacity: close.hovered ? 1 : 0.65
                        }
                    }
                }
            }

            Column {
                id: message
                width: parent.width
                spacing: 6
                objectName: "notification-message"
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: { if (root.defaultAction) root.actionRequested(root.defaultAction.identifier); }
                }
                HoverHandler { cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor }

                Text {
                    width: parent.width
                    text: root.title
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: 14; bold: true }
                }
                Text {
                    width: parent.width
                    visible: root.body.length > 0
                    text: root.body
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.notification.image ? 3 : 5
                    elide: Text.ElideRight
                    color: Theme.subtext
                    font { family: Theme.fontFamily; pixelSize: 12 }
                }
                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 3
                    visible: root.progress >= 0
                    color: Theme.border
                    Rectangle {
                        width: parent.width * Math.max(0, root.progress) / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.entry.critical ? Theme.critical : Theme.accent
                    }
                }
                Image {
                    id: picture
                    objectName: "notification-image"
                    width: parent.width
                    height: visible ? 110 : 0
                    visible: status === Image.Ready
                    // Native image-data URLs and local files; never fetch remote content.
                    source: root.notification.image.startsWith("/") ? "file://" + root.notification.image
                        : /^(file:|image:)/.test(root.notification.image) ? root.notification.image : ""
                    sourceSize { width: 664; height: 220 }
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                }
            }

            Flow {
                id: actionFlow
                width: parent.width
                spacing: 6
                visible: root.actions.length > 0
                Repeater {
                    model: ScriptModel {
                        values: root.actions
                        comparisonMode: ObjectComparison.Identity
                    }
                    Button {
                        id: actionButton
                        required property var modelData
                        required property int index
                        readonly property string actionIcon: root.notification.hasActionIcons
                            ? Quickshell.iconPath(modelData.identifier, true) : ""
                        objectName: "notification-action-" + index
                        width: (actionFlow.width - 6) / 2
                        height: 32
                        padding: 8
                        hoverEnabled: true
                        focusPolicy: Qt.NoFocus
                        Accessible.name: modelData.text
                        onClicked: root.actionRequested(modelData.identifier)
                        background: Rectangle { radius: 7; color: actionButton.hovered ? Theme.border : Theme.hover }
                        contentItem: RowLayout {
                            spacing: 6
                            IconImage {
                                Layout.preferredWidth: 15
                                Layout.preferredHeight: 15
                                visible: actionButton.actionIcon.length > 0
                                source: actionButton.actionIcon
                            }
                            Text {
                                Layout.fillWidth: true
                                text: actionButton.modelData.text
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: actionButton.hovered ? Theme.accent : Theme.text
                                font { family: Theme.fontFamily; pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }
    }
}
