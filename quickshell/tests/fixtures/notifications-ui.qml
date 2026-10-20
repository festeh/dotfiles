pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "NotificationLogic.js" as Logic

ShellRoot {
    id: root
    property int created: 0
    property var events: null
    property int watchedId: 0
    property real previousElapsed: 0
    property real peakElapsed: 0
    property var regressions: []
    function recordProgress(id, value): void {
        if (id !== watchedId) return;
        if (value + 0.000001 < previousElapsed)
            regressions.push({from: previousElapsed, to: value});
        previousElapsed = value;
        peakElapsed = Math.max(peakElapsed, value);
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const found = find(child, name);
            if (found) return found;
        }
        return null;
    }
    function card(id) {
        for (let i = 0; i < cards.count; ++i) {
            const value = cards.itemAt(i);
            if (value.entry.id === id) return value;
        }
        return null;
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 900
        implicitHeight: 900
        Column {
            x: 20; y: 20; spacing: 8
            Repeater {
                id: cards
                model: ScriptModel {
                    values: Logic.choose(NotificationState.entries, 'primary', [], {}, 850)
                    objectProp: "id"
                    comparisonMode: ObjectComparison.Identity
                }
                NotificationCard {
                    required property var modelData
                    property int serial: 0
                    entry: modelData
                    width: 360
                    onTimeoutProgressChanged: root.recordProgress(entry.id, timeoutProgress)
                    onHoverLeft: NotificationState.hoverLeft(entry.id)
                    onDismissRequested: NotificationState.dismiss(entry.id)
                    onActionRequested: identifier => NotificationState.invoke(entry.id, identifier)
                    Component.onCompleted: serial = ++root.created
                }
            }
        }
    }
    IpcHandler {
        target: "fixture"
        function status(): string {
            return JSON.stringify({count: NotificationState.count, created: root.created,
                rows: NotificationState.entries.map(entry => {
                    const card = root.card(entry.id);
                    return {id: entry.id, deadline: entry.deadline, arrived: entry.arrived,
                        critical: entry.critical, summary: entry.notification.summary,
                        serial: card ? card.serial : 0, height: card ? card.height : 0,
                        elapsed: card ? card.timeoutProgress : 0,
                        timeoutVisible: card ? root.find(card, 'notification-timeout').visible : false,
                        body: card ? card.body : '', progress: card ? card.progress : -1,
                        imageReady: card ? root.find(card, 'notification-image').status === Image.Ready : false};
                })});
        }
        function expireAt(now: real): void { NotificationState.reconcile(now); }
        function watch(id: int): void {
            root.watchedId = id;
            root.previousElapsed = root.card(id).timeoutProgress;
            root.peakElapsed = root.previousElapsed;
            root.regressions = [];
        }
        function trace(): string {
            return JSON.stringify({peak: root.peakElapsed, last: root.previousElapsed, backwards: root.regressions});
        }
        function finishAndResync(id: int): void {
            // Animation and wall-clock expiration can finish on different frames.
            const card = root.card(id);
            card.timeoutProgress = 1;
            card.syncTimeout();
        }
        function ui(id: int, action: string): void {
            const card = root.card(id);
            if (!card) throw new Error('Card missing');
            if (!root.events) root.events = Qt.createQmlObject('import QtTest; TestEvent {}', card, 'notification-events');
            if (action === 'leave') {
                root.events.mouseMove(card, 30, 20, 0, Qt.NoButton, Qt.NoModifier);
                root.events.mouseMove(window.contentItem, 880, 880, 0, Qt.NoButton, Qt.NoModifier);
                return;
            }
            const target = root.find(card, action === 'close' ? 'notification-close'
                : action === 'default' ? 'notification-message' : 'notification-action-0');
            if (!target) throw new Error('Click target missing');
            root.events.mouseClick(target, target.width / 2, target.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
        }
    }
}
