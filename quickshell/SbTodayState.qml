pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "SbTodayLogic.js" as Logic

// Today's tasks from sb, over the socket sb serves while it runs
// (app/src-tauri/src/widget.rs in the sb repository). Nothing here polls:
// sb's tray item appearing is the cue to connect, the socket closing is the
// cue to hide, and sb sends a new snapshot whenever today changes.
QtObject {
    id: root
    property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/sb/today.sock"
    // sb's StatusNotifierItem id.
    property string trayId: "sb"
    readonly property bool sbRunning: SystemTray.items.values.some(item => item.id === trayId)
    property var snapshot: null
    readonly property var tasks: snapshot ? snapshot.tasks : []
    readonly property string today: snapshot ? snapshot.today : ""
    readonly property var summary: Logic.summary(tasks)
    readonly property bool available: socket.connected && snapshot !== null
    // Paths sent as done and not yet gone from a snapshot.
    property var busyPaths: []
    property string error: ""
    property Item popupOwner: null
    property int attempts: 0
    signal popupRequested()

    function connect(): void {
        if (sbRunning && !socket.connected) socket.connected = true;
    }

    function receive(line: string): void {
        const message = Logic.parse(line);
        if (!message) return;
        if (message.type === "snapshot") {
            snapshot = message;
            busyPaths = busyPaths.filter(path => message.tasks.some(task => task.path === path));
        } else {
            error = message.message;
            busyPaths = [];
        }
    }

    function send(request: var): void {
        if (!socket.connected) {
            error = "sb is not running.";
            return;
        }
        socket.write(JSON.stringify(request) + "\n");
        socket.flush();
    }

    function complete(path: string): void {
        if (busyPaths.includes(path)) return;
        error = "";
        busyPaths = busyPaths.concat([path]);
        send({action: "done", path: path});
    }

    function add(title: string): void {
        error = "";
        send({action: "add", title: title});
    }

    function open(path: string): void { send({action: "open", path: path}); }
    function openTasks(): void { send({action: "tasks"}); }
    function isBusy(path: string): bool { return busyPaths.includes(path); }
    function show(owner: Item): void { popupOwner = owner; }
    function hide(owner: Item): void { if (popupOwner === owner) popupOwner = null; }

    onSbRunningChanged: {
        attempts = 0;
        if (sbRunning) connect();
        else socket.connected = false;
    }
    Component.onCompleted: connect()

    readonly property Socket socket: Socket {
        path: root.socketPath
        parser: SplitParser { onRead: data => root.receive(data) }
        onConnectedChanged: {
            if (connected) {
                root.attempts = 0;
                return;
            }
            root.snapshot = null;
            root.busyPaths = [];
            root.error = "";
        }
        // sb puts up its tray item and opens the socket at about the same
        // moment, so a refused first try gets a few short retries.
        onError: if (root.sbRunning && root.attempts < 5) retry.restart()
    }
    readonly property Timer retry: Timer {
        interval: 500 * (root.attempts + 1)
        onTriggered: {
            root.attempts += 1;
            root.connect();
        }
    }
    readonly property IpcHandler ipc: IpcHandler {
        target: "sb"
        // Counts only: task titles stay out of logs and shell history.
        function status(): string {
            return JSON.stringify({running: root.sbRunning, connected: root.socket.connected,
                open: root.summary.open, overdue: root.summary.overdue, error: root.error.length > 0});
        }
        function open(): void { root.popupRequested(); }
        function close(): void { if (root.popupOwner) root.hide(root.popupOwner); }
    }
}
