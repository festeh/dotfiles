pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "NotificationLogic.js" as Logic

Singleton {
    id: root
    property string focusedMonitorName: ""
    property var entries: []
    readonly property int count: entries.length
    readonly property var screenNames: Quickshell.screens.map(screen => screen.name || "primary")
    readonly property var savedRecords: JSON.parse(lifetimes.records)
    signal clockReconciled()

    // Only metadata survives a QML reload. No notification text or images go to disk.
    PersistentProperties {
        id: lifetimes
        reloadableId: "notification-lifetimes"
        // A string crosses QML engines safely; a var containing JS objects cannot.
        property string records: "{}"
        property int sequence: 0
    }

    function currentMonitor(): string {
        return screenNames.includes(focusedMonitorName) ? focusedMonitorName : screenNames[0] || "primary";
    }

    function find(id): var {
        return entries.find(entry => entry.id === Number(id));
    }

    function remember(entry): void {
        const records = Object.assign({}, savedRecords);
        records[entry.id] = {arrived: entry.arrived, deadline: entry.deadline,
            monitor: entry.monitor, sequence: entry.sequence};
        lifetimes.records = JSON.stringify(records);
    }

    function receive(notification): void {
        if (!notification || !notification.tracked || find(notification.id)) return;
        const now = Date.now();
        const saved = notification.lastGeneration ? savedRecords[notification.id] : null;
        const arrived = saved ? saved.arrived : now;
        const entry = {
            id: notification.id, notification: notification, critical: Logic.critical(notification),
            arrived: arrived,
            deadline: Logic.deadline(notification, arrived),
            monitor: saved && screenNames.includes(saved.monitor) ? saved.monitor : currentMonitor(),
            sequence: saved ? saved.sequence : ++lifetimes.sequence
        };
        // Bound ordinary bursts. Critical alerts are never silently discarded.
        if (!entry.critical && entries.filter(item => !item.critical).length >= 64) {
            notification.expire();
            return;
        }
        remember(entry);
        entries = entries.concat([entry]);
        reconcile();
    }

    function replaced(id): void {
        const previous = find(id);
        if (!previous) return;
        const now = Date.now();
        const entry = Object.assign({}, previous, {arrived: now,
            critical: Logic.critical(previous.notification),
            deadline: Logic.deadline(previous.notification, now)});
        remember(entry);
        entries = entries.map(item => item.id === entry.id ? entry : item);
        schedule();
    }

    function forget(id): void {
        entries = entries.filter(entry => entry.id !== Number(id));
        const records = Object.assign({}, savedRecords);
        delete records[id];
        lifetimes.records = JSON.stringify(records);
        schedule();
    }

    function dismiss(id): void {
        Qt.callLater(() => {
            const entry = find(id);
            if (entry && entry.notification && entry.notification.tracked) entry.notification.dismiss();
        });
    }

    function hoverLeft(id): void {
        const entry = find(id);
        if (entry && !entry.critical) dismiss(id);
    }

    function invoke(id, identifier): void {
        const entry = find(id);
        if (!entry || !entry.notification || !entry.notification.tracked) return;
        const action = entry.notification.actions.find(item => item.identifier === identifier);
        if (action) action.invoke();
    }

    function schedule(): void {
        expiry.stop();
        const deadlines = entries.filter(entry => entry.deadline > 0).map(entry => entry.deadline);
        if (!deadlines.length) return;
        expiry.interval = Math.max(1, Math.min(2147483647, Math.ceil(Math.min(...deadlines) - Date.now())));
        expiry.start();
    }

    function reconcile(now): void {
        const current = now === undefined ? Date.now() : now;
        for (const entry of entries.slice()) {
            if (entry.deadline > 0 && entry.deadline <= current && entry.notification && entry.notification.tracked)
                entry.notification.expire();
        }
        schedule();
        clockReconciled();
    }

    onScreenNamesChanged: {
        entries = entries.map(entry => {
            if (screenNames.includes(entry.monitor)) return entry;
            const moved = Object.assign({}, entry, {monitor: currentMonitor()});
            remember(moved);
            return moved;
        });
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        persistenceSupported: false
        inlineReplySupported: false
        onNotification: notification => {
            notification.tracked = true;
            // PersistentProperties finishes restoring before the deferred receive.
            Qt.callLater(() => root.receive(notification));
        }
    }

    Instantiator {
        model: server.trackedNotifications
        delegate: Connections {
            required property var modelData
            target: modelData
            function onUpdated(): void { root.replaced(modelData.id); }
            function onClosed(): void { root.forget(modelData.id); }
        }
    }

    Timer { id: expiry; onTriggered: root.reconcile() }

    // One event subscription, with no polling. A paused monotonic Qt timer alone
    // cannot enforce a wall-clock deadline across suspend.
    Process {
        id: resumeWatch
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (/PrepareForSleep\s*\(false,?\)/.test(line)) {
                    root.reconcile();
                    ClockState.refresh();
                }
            }
        }
    }

    Connections {
        target: ClockState
        function onNowChanged(): void { if (root.count) root.reconcile(); }
    }
}
