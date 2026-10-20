pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "WorkspaceLogic.js" as Logic

QtObject {
    id: root
    // Share one worker and inventory across every monitor and workspace view.
    readonly property var clients: Hyprland.toplevels.values.map(window => ({
        address: Logic.address(window.address), pid: window.lastIpcObject.pid || 0,
        appId: window.lastIpcObject.class || ""
    })).filter(client => client.pid > 0)
    readonly property string clientSnapshot: JSON.stringify({windows: clients})
    property string sentSnapshot: ""
    property var applications: ({})
    property var health: ({})
    property bool ready: false
    property int restarts: 0
    onClientSnapshotChanged: syncDelay.restart()

    function appFor(window): var {
        return window ? applications[Logic.address(window.address)] : undefined;
    }

    function statusFor(window): string {
        const terminal = appFor(window);
        return terminal ? terminal.agentState || "" : "";
    }

    function agentDescription(window): string {
        const terminal = appFor(window);
        if (!terminal || !terminal.agents) return "";
        const names = {codex: "Codex", claude: "Claude", kimi: "Kimi"};
        const states = {idle: "Idle", running: "Running", waiting: "Needs action"};
        return terminal.agents.map(agent => (names[agent.agent] || agent.agent)
            + " · tab " + agent.tab + " · " + (states[agent.state] || "Status unavailable")).join("; ");
    }

    function sync(): void {
        if (helper.running && clientSnapshot !== sentSnapshot) {
            helper.write(clientSnapshot + "\n");
            sentSnapshot = clientSnapshot;
        }
    }

    readonly property Timer syncDelay: Timer { interval: 40; onTriggered: root.sync() }
    readonly property Timer retry: Timer {
        interval: 500
        onTriggered: root.helper.running = true
    }
    readonly property Process helper: Process {
        command: ["python3", Quickshell.shellPath("terminal_tracker.py")]
        stdinEnabled: true
        running: true
        onStarted: { root.sentSnapshot = ""; root.sync(); }
        onExited: {
            root.applications = ({});
            root.health = ({});
            root.ready = false;
            if (++root.restarts <= 3) root.retry.restart();
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const value = JSON.parse(line);
                    root.applications = value.windows;
                    root.health = value.health;
                    root.ready = true;
                    root.restarts = 0;
                } catch (_) { root.applications = ({}); }
            }
        }
    }
    readonly property IpcHandler ipc: IpcHandler {
        target: "terminals"
        function status(): string { return JSON.stringify(root.health); }
    }
}
