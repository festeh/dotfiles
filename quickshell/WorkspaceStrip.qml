pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root
    property bool keyboardNavigation: false
    signal pointerInteraction()
    signal keyboardInteraction()
    implicitWidth: groups.implicitWidth
    implicitHeight: 40

    function reveal(item): void {
        const x = item.mapToItem(groups, 0, 0).x;
        if (x < scroll.contentX) scroll.contentX = x;
        else if (x + item.width > scroll.contentX + scroll.width)
            scroll.contentX = x + item.width - scroll.width;
        scroll.contentX = Math.max(0, Math.min(scroll.contentX, Math.max(0, scroll.contentWidth - scroll.width)));
    }
    Flickable {
        id: scroll
        objectName: "workspace-scroll"
        anchors.fill: parent
        clip: true
        contentWidth: groups.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        Row {
            id: groups
            spacing: 6
            Repeater {
                model: ScriptModel {
                    values: WorkspaceState.workspaces
                    comparisonMode: ObjectComparison.Identity
                }
                delegate: WorkspaceGroup {
                    required property var modelData
                    workspace: modelData
                    keyboardNavigation: root.keyboardNavigation
                    onPointerInteraction: root.pointerInteraction()
                    onKeyboardInteraction: root.keyboardInteraction()
                    onRevealRequested: item => root.reveal(item)
                }
            }
        }
        WheelHandler {
            target: null
            onWheel: event => {
                event.accepted = scroll.contentWidth > scroll.width;
                if (event.accepted) {
                    root.pointerInteraction();
                    const delta = event.pixelDelta.x || event.pixelDelta.y
                        || (event.angleDelta.x || event.angleDelta.y) / 120 * 48;
                    scroll.contentX = Math.max(0, Math.min(scroll.contentX - delta, scroll.contentWidth - scroll.width));
                }
            }
        }
    }
}
