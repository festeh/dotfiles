pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "LayoutLogic.js" as Logic

QtObject {
    id: root
    property var keyboard: null
    readonly property var status: Logic.describe(keyboard)
    readonly property bool cycling: switcher.running
    property string error: ""
    property int eventSerial: 0
    property int snapshotSerial: 0
    property var layoutEvents: ({})
    property bool refreshPending: false
    property int retries: 0

    function refresh(): void {
        retries = 0;
        retryDelay.stop();
        refreshPending = true;
        refreshDelay.restart();
    }

    function readDevices(): void {
        if (snapshot.running) return;
        refreshPending = false;
        snapshotSerial = eventSerial;
        snapshotTimeout.restart();
        snapshot.running = true;
    }

    function finishSnapshot(exitCode): void {
        snapshotTimeout.stop();
        let selected = null;
        let valid = false;
        try {
            const data = JSON.parse(snapshotOutput.text);
            valid = exitCode === 0 && Array.isArray(data.keyboards);
            if (valid) selected = Logic.primary(data);
        } catch (_) {}
        if (valid) {
            const update = selected ? layoutEvents[selected.name] : null;
            if (update && update.serial > snapshotSerial)
                selected = Logic.withLayout(selected, update.name);
            keyboard = selected;
            error = "";
            retries = 0;
        } else {
            keyboard = null;
            error = "Keyboard layout unavailable";
            // Only bounded startup/transient retries, with no idle polling.
            if (retries < 2) {
                retries++;
                refreshPending = true;
                retryDelay.restart();
            }
        }
        if (refreshPending && !retryDelay.running) refreshDelay.restart();
    }

    function layoutChanged(device, name): void {
        device = Logic.clean(device);
        name = Logic.clean(name);
        if (!device || !name || !Logic.physical(device)) return;
        const updates = Object.assign({}, layoutEvents);
        updates[device] = {name: name, serial: ++eventSerial};
        layoutEvents = updates;
        if (keyboard && keyboard.name === device) {
            keyboard = Logic.withLayout(keyboard, name);
            error = "";
        } else refresh();
    }

    function cycle(): bool {
        if (switcher.running) return false;
        const command = Logic.cycleCommand(keyboard);
        if (!command.length) return false;
        error = "";
        switcher.command = command;
        switchTimeout.restart();
        switcher.running = true;
        return true;
    }

    readonly property Timer refreshDelay: Timer {
        interval: 40
        running: true
        onTriggered: root.readDevices()
    }
    readonly property Timer retryDelay: Timer {
        interval: 350
        onTriggered: root.readDevices()
    }
    readonly property Timer snapshotTimeout: Timer {
        interval: 2000
        onTriggered: root.snapshot.signal(9)
    }
    readonly property Timer switchTimeout: Timer {
        interval: 2000
        onTriggered: root.switcher.signal(9)
    }
    readonly property Process snapshot: Process {
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector { id: snapshotOutput }
        onExited: (exitCode, exitStatus) => root.finishSnapshot(exitCode)
        onRunningChanged: if (!running && root.snapshotTimeout.running) root.finishSnapshot(-1)
    }
    readonly property Process switcher: Process {
        stdout: StdioCollector { id: switchOutput }
        onExited: (exitCode, exitStatus) => {
            root.switchTimeout.stop();
            if (exitCode !== 0 || switchOutput.text.trim() !== "ok")
                root.error = "Could not switch keyboard layout";
            else root.refresh();
        }
        onRunningChanged: if (!running && root.switchTimeout.running) {
            root.switchTimeout.stop();
            root.error = "Could not switch keyboard layout";
        }
    }
    readonly property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "activelayout") {
                const fields = event.parse(2);
                root.layoutChanged(fields[0], fields[1]);
            } else if (event.name === "configreloaded") root.refresh();
        }
    }
}
