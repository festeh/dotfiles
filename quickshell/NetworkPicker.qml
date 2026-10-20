import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    objectName: "network-picker-controller"
    property var command: ["python3", Quickshell.shellPath("network_picker.py")]
    property var snapshot: ({ready: false, available: false, wifiEnabled: false,
        hardwareEnabled: false, hasWifi: false, managed: false, busy: false, scanning: false, rows: [], message: ""})
    readonly property var rows: snapshot.rows
    property string transportError: ""
    signal passwordRequested(var row, bool retry)

    function send(message): void {
        if (helper.running)
            helper.write(JSON.stringify(message) + "\n");
    }

    function receive(line: string): void {
        try {
            const message = JSON.parse(line);
            if (message.type === "snapshot") {
                snapshot = message;
            } else if (message.type === "password") {
                const row = rows.find(row => row.id === message.id);
                if (row)
                    passwordRequested(row, message.retry === true);
            }
        } catch (_) {
            transportError = "Network data unavailable. Close and reopen to retry.";
        }
    }

    readonly property Process helper: Process {
        command: root.command
        stdinEnabled: true
        running: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        onExited: (exitCode, exitStatus) => {
            root.transportError = "Network picker stopped. Close and reopen to retry.";
        }
    }
}
