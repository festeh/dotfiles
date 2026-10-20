pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "WorkspaceLogic.js" as Logic

QtObject {
    id: root
    objectName: "kitty-app-icons"
    readonly property var clients: Hyprland.toplevels.values.map(window => ({
        address: Logic.address(window.address),
        pid: window.lastIpcObject.pid || 0,
        appId: window.lastIpcObject.class || ""
    })).filter(client => client.pid > 0)
    property var applications: ({})
    property var titleKeys: ({})
    property bool ready: false
    onClientsChanged: syncDelay.restart()

    function appFor(window): var {
        return window ? applications[Logic.address(window.address)] : undefined;
    }

    function send(message): void {
        if (helper.running) helper.write(JSON.stringify(message) + "\n");
    }

    function refresh(address): void {
        const client = clients.find(client => client.address === Logic.address(address));
        if (client) send({refresh: client.pid});
    }

    function sync(): void {
        const present = new Set();
        for (const window of Hyprland.toplevels.values) {
            const address = Logic.address(window.address);
            present.add(address);
            if (titleKeys[address] === undefined) titleKeys[address] = Logic.terminalTitleKey(window.title);
        }
        for (const address of Object.keys(titleKeys)) {
            if (!present.has(address)) delete titleKeys[address];
        }
        send({windows: clients});
    }

    function titleChanged(address, title): void {
        address = Logic.address(address);
        const key = Logic.terminalTitleKey(title);
        const previous = titleKeys[address];
        titleKeys[address] = key;
        if (key !== previous) refresh(address);
    }

    readonly property Timer syncDelay: Timer {
        interval: 40
        onTriggered: root.sync()
    }

    readonly property Process helper: Process {
        command: ["python3", Quickshell.shellPath("kitty_apps.py")]
        stdinEnabled: true
        running: true
        onStarted: root.sync()
        onExited: { root.applications = ({}); root.ready = false; }
        stdout: SplitParser {
            onRead: line => {
                try { root.applications = JSON.parse(line).windows; root.ready = true; }
                catch (_) { root.applications = ({}); }
            }
        }
    }

    readonly property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "windowtitlev2") {
                const fields = event.parse(2);
                root.titleChanged(fields[0], fields[1]);
            }
            else if (event.name === "activewindowv2") root.refresh(event.data);
            else if (event.name === "closewindow") delete root.titleKeys[Logic.address(event.data)];
        }
    }
}
