//@ pragma IconTheme QuickshellWorkspaceTest
//@ pragma Env QT_QPA_PLATFORMTHEME = gtk3

import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root
    FloatingWindow {
        visible: true
        implicitWidth: 620
        implicitHeight: 44
        WorkspaceStrip {
            id: strip
            width: 620
            onPointerInteraction: keyboardNavigation = false
            onKeyboardInteraction: keyboardNavigation = true
            TestEvent { id: events }
        }
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) {
            const result = find(child, name);
            if (result) return result;
        }
        return null;
    }
    function agentButton(window, index, pane) {
        return root.find(strip, index === 0 ? "workspace-window-" + window.address
            : "workspace-agent-" + window.address + "-" + pane);
    }
    IpcHandler {
        target: "workspace-test"
        function state(): string {
            return JSON.stringify({lua: Hyprland.usingLua, terminalReady: TerminalState.ready,
                themedIconAvailable: Quickshell.hasThemeIcon("org.example.Themed"),
                width: strip.width, implicitWidth: strip.implicitWidth,
                scrollX: root.find(strip, "workspace-scroll").contentX,
                groups: WorkspaceState.workspaces.map(ws => ({id: ws.id, name: ws.name, address: ws.address,
                    focused: WorkspaceState.workspaceFocused(ws), active: WorkspaceState.workspaceActive(ws),
                    delegate: String(root.find(strip, 'workspace-number-' + ws.address)),
                    windows: WorkspaceState.windowsFor(ws).map(w => ({address: w.address, title: w.title,
                        focused: WorkspaceState.isFocused(w), info: WorkspaceState.info(w),
                        delegate: String(root.find(strip, 'workspace-window-' + w.address)),
                        agentState: TerminalState.statusFor(w),
                        agents: TerminalState.agentsFor(w).map((agent, index) => ({pane: agent.pane,
                            source: root.agentButton(w, index, agent.pane).app.source,
                            selected: root.agentButton(w, index, agent.pane).selected,
                            state: root.agentButton(w, index, agent.pane).agentState,
                            delegate: String(root.agentButton(w, index, agent.pane)),
                            color: String(root.find(root.agentButton(w, index, agent.pane), 'agent-status-overline').color)})),
                        overlineVisible: root.find(root.find(strip, 'workspace-window-' + w.address), 'agent-status-overline').visible,
                        overlineColor: String(root.find(root.find(strip, 'workspace-window-' + w.address), 'agent-status-overline').color),
                        overlineWidth: root.find(root.find(strip, 'workspace-window-' + w.address), 'agent-status-overline').width,
                        underlineWidth: root.find(root.find(strip, 'workspace-window-' + w.address), 'window-focus-underline').width}))}))});
        }
        function click(name: string): bool {
            const button = root.find(strip, name);
            return button ? events.mouseClick(button, button.width/2, button.height/2, Qt.LeftButton, Qt.NoModifier, 0) : false;
        }
        function narrow(): void { strip.width = 120; }
        function terminal(address: string, programs: string): void {
            const state = Object.assign({}, TerminalState.applications);
            if (programs === "-") delete state[address];
            else state[address] = {kitty: true, programs: programs ? programs.split(",") : []};
            TerminalState.applications = state;
        }
        function agents(address: string, status: string): void {
            const state = Object.assign({}, TerminalState.applications);
            state[address] = {kitty: true, programs: ["codex"], agentState: status,
                agents: status ? [{agent: "codex", pane: 1, tab: 2, state: status, active: true}] : []};
            TerminalState.applications = state;
        }
        function agentPanes(address: string, payload: string): void {
            const state = Object.assign({}, TerminalState.applications);
            state[address] = {kitty: true, programs: ["codex"], agents: JSON.parse(Qt.atob(payload))};
            TerminalState.applications = state;
        }
        function reveal(name: string): bool {
            const button = root.find(strip, name);
            if (!button) return false;
            button.forceActiveFocus(Qt.TabFocusReason);
            return true;
        }
        function key(code: int): bool { return events.keyClick(code, Qt.NoModifier, 0); }
        function capture(path: string): void { strip.grabToImage(result => result.saveToFile(path)); }
    }
}
