pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "NotificationLogic.js" as Logic

PanelWindow {
    id: root
    required property var monitor
    property var heights: ({})
    property var hovering: ({})
    property var pinned: []
    property var cardRegions: []
    readonly property int availableHeight: Math.max(160, monitor.height - 120)
    readonly property var records: Logic.choose(NotificationState.entries, monitor.name || "primary",
        pinned, heights, availableHeight)
    screen: monitor
    anchors { top: true; right: true }
    margins { top: 8; right: 12 }
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    implicitWidth: 360
    implicitHeight: Math.max(1, column.implicitHeight)
    visible: records.length > 0
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { regions: root.cardRegions }

    function syncRegions(): void {
        const regions = [];
        for (let i = 0; i < cards.count; ++i) {
            const card = cards.itemAt(i) as NotificationCard;
            if (card) regions.push(card.inputRegion);
        }
        cardRegions = regions;
    }

    function hoverChanged(id, hovered): void {
        const next = Object.assign({}, hovering);
        if (hovered) next[id] = true;
        else delete next[id];
        hovering = next;
        pinned = Object.keys(next).length ? records.map(entry => entry.id) : [];
    }

    function measure(id, height): void {
        if (heights[id] === height) return;
        const next = Object.assign({}, heights);
        next[id] = height;
        heights = next;
    }

    onRecordsChanged: Qt.callLater(syncRegions)

    function prune(): void {
        const ids = new Set(NotificationState.entries.map(entry => String(entry.id)));
        if (Object.keys(heights).some(id => !ids.has(id))) {
            const next = {};
            for (const id of Object.keys(heights)) if (ids.has(id)) next[id] = heights[id];
            heights = next;
        }
        if (Object.keys(hovering).some(id => !ids.has(id))) {
            const next = {};
            for (const id of Object.keys(hovering)) if (ids.has(id)) next[id] = true;
            hovering = next;
            pinned = Object.keys(next).length ? pinned.filter(id => ids.has(String(id))) : [];
        }
    }

    Connections {
        target: NotificationState
        function onEntriesChanged(): void { Qt.callLater(root.prune); }
    }

    Column {
        id: column
        width: parent.width
        spacing: 8
        Repeater {
            id: cards
            model: ScriptModel {
                values: root.records
                objectProp: "id"
                comparisonMode: ObjectComparison.Identity
            }
            NotificationCard {
                id: card
                required property var modelData
                entry: modelData
                width: column.width
                maximumHeight: root.availableHeight
                function reportHeight(): void { root.measure(entry.id, implicitHeight); }
                function reportHover(): void { root.hoverChanged(entry.id, hovered); }
                onImplicitHeightChanged: Qt.callLater(reportHeight)
                onHoveredChanged: Qt.callLater(reportHover)
                onHoverLeft: NotificationState.hoverLeft(entry.id)
                onDismissRequested: NotificationState.dismiss(entry.id)
                onActionRequested: identifier => NotificationState.invoke(entry.id, identifier)
                Component.onCompleted: { Qt.callLater(reportHeight); Qt.callLater(root.syncRegions); }
                Component.onDestruction: { Qt.callLater(root.prune); Qt.callLater(root.syncRegions); }
            }
        }
    }
}
