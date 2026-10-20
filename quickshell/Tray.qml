pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: root
    readonly property int itemCount: items.count
    property bool keyboardNavigation: false
    signal pointerInteraction()
    signal keyboardInteraction()

    implicitWidth: row.implicitWidth + 24
    implicitHeight: Theme.buttonSize + 12
    radius: 10
    color: Theme.surface

    ScriptModel {
        id: sortedItems
        // Sort a copy: never mutate the service's list. Preserve delegate identity
        // when applications register, disappear, or update their properties.
        values: [...SystemTray.items.values].sort((a, b) => {
            const category = a.category - b.category;
            if (category !== 0)
                return category;
            const name = a.id.localeCompare(b.id);
            return name !== 0 ? name : a.title.localeCompare(b.title);
        })
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            id: items
            model: sortedItems

            TrayItem {
                id: entry
                required property SystemTrayItem modelData
                required property int index
                item: modelData
                keyboardNavigation: root.keyboardNavigation
                onPointerInteraction: root.pointerInteraction()
                onKeyboardInteraction: root.keyboardInteraction()
                onFocusStep: step => root.focusItem(entry.index + step)
                onFocusEdge: last => root.focusItem(last ? items.count - 1 : 0)
            }
        }
    }

    function focusItem(index: int): void {
        if (items.count === 0)
            return;
        const target = items.itemAt((index + items.count) % items.count);
        if (target)
            target.forceActiveFocus(Qt.TabFocusReason);
    }
}
