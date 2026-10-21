pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "WorkspaceLogic.js" as Logic

QtObject {
    id: root
    // Share one worker and inventory across every monitor and workspace view.
    // Kitty owns per-pane labels so this worker can reload without losing them.
    // Codex and Claude supply session names through the existing terminal event stream.
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
    property var labelEditorOwner: null
    signal labelRenamed(string address, int pane, bool ok, string message)
    onClientSnapshotChanged: syncDelay.restart()

    function appFor(window): var {
        return window ? applications[Logic.address(window.address)] : undefined;
    }

    function statusFor(window): string {
        const terminal = appFor(window);
        return terminal ? terminal.agentState || "" : "";
    }

    function agentsFor(window): var {
        const terminal = appFor(window);
        return terminal && terminal.agents ? terminal.agents : [];
    }

    function agentFor(window, pane): var {
        return agentsFor(window).find(agent => agent.pane === pane) || null;
    }

    function describeAgent(agent): string {
        const states = {idle: "Idle", running: "Running", waiting: "Needs action"};
        const name = agent.fullLabel ? agent.fullLabel
            + (agent.project && agent.project !== agent.fullLabel ? " · " + agent.project : "") + " · " : "";
        return name + "Tab " + agent.tab + " · pane " + agent.pane + " · "
            + (states[agent.state] || "Status unavailable");
    }

    function renameAgent(window, pane, label): bool {
        if (!helper.running || !agentFor(window, pane)) return false;
        helper.write(JSON.stringify({rename: {address: Logic.address(window.address), pane: pane, label: label}}) + "\n");
        return true;
    }

    function activateAgent(window, pane): bool {
        if (!helper.running || !agentFor(window, pane)) return false;
        helper.write(JSON.stringify({activate: {address: Logic.address(window.address), pane: pane}}) + "\n");
        return true;
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
                    if (value.renamed) {
                        root.labelRenamed(value.renamed.address, value.renamed.pane, value.renamed.ok, value.renamed.error || "");
                        return;
                    }
                    if (value.activated) {
                        if (value.activated.ok) {
                            const window = Hyprland.toplevels.values.find(window =>
                                Logic.address(window.address) === value.activated.address);
                            if (window && root.agentFor(window, value.activated.pane))
                                WorkspaceState.activateWindow(window);
                        }
                        return;
                    }
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
