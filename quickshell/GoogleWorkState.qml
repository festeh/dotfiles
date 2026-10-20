pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "GoogleWorkLogic.js" as WorkLogic

QtObject {
    id: root
    property var helperCommand: [Quickshell.shellPath("google-work")]
    property var snapshot: ({gmail: {status: "loading", unread: null, rows: [], busyIds: []},
                             calendar: {status: "loading", rows: []}, authorizing: false})
    readonly property var gmail: snapshot.gmail
    readonly property var calendar: snapshot.calendar
    property Item popupOwner: null
    property var calendarView: WorkLogic.calendar([], Date.now())
    property string transportError: ""
    signal popupRequested(string kind)

    function updateCalendar(): void {
        calendarView = WorkLogic.calendar(calendar.rows || [], Date.now());
        boundary.interval = Math.max(1, Math.min(86400000, calendarView.nextBoundary - Date.now() + 20));
        boundary.restart();
    }

    function send(value): void {
        if (helper.running) helper.write(JSON.stringify(value) + "\n");
    }

    function show(owner: var): void {
        popupOwner = owner;
        send({action: "show", kind: owner.kind});
    }

    function hide(owner: Item): void {
        if (popupOwner !== owner) return;
        popupOwner = null;
        send({action: "hide"});
    }

    function receive(line: string): void {
        if (!line.trim()) return;
        try {
            const value = JSON.parse(line);
            if (value.type === "snapshot") {
                snapshot = value;
                transportError = "";
                updateCalendar();
            }
        } catch (_) {
            transportError = "Work account data unavailable. Refresh to retry.";
        }
    }

    function refresh(): void {
        if (!helper.running) helper.running = true;
        else send({action: "refresh"});
    }

    readonly property Timer boundary: Timer { onTriggered: root.updateCalendar() }
    readonly property Connections clockEvents: Connections {
        target: ClockState
        function onNowChanged(): void { root.updateCalendar(); }
    }
    readonly property Process helper: Process {
        command: root.helperCommand
        stdinEnabled: true
        running: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        onExited: root.transportError = "Work account service stopped. Refresh to retry."
    }
    readonly property IpcHandler ipc: IpcHandler {
        target: "work"
        function refresh(): void { root.refresh(); }
        function authorize(): void { root.send({action: "authorize"}); }
        function open(kind: string): void { if (kind === "gmail" || kind === "calendar") root.popupRequested(kind); }
        function close(): void { if (root.popupOwner) root.hide(root.popupOwner); }
        function status(): string {
            return JSON.stringify({gmail: root.gmail.status, unread: root.gmail.unread,
                previews: (root.gmail.rows || []).length, canMarkRead: !!root.gmail.canMarkRead,
                calendar: root.calendar.status, meetings: (root.calendar.rows || []).length,
                authorizing: !!root.snapshot.authorizing, popupOpen: !!root.popupOwner,
                error: !!root.transportError});
        }
    }
}
