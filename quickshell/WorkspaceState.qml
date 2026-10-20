pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import "WorkspaceLogic.js" as Logic

QtObject {
    id: root
    readonly property var workspaces: Hyprland.workspaces.values.filter(Logic.normal).sort(Logic.compare)
    readonly property var windows: Hyprland.toplevels.values
    readonly property var catalog: Logic.index(DesktopEntries.applications.values)
    // Explicit user overrides take priority over tray and desktop icons.
    readonly property var iconOverrides: [{
        appId: /^(codex|book-codex-.+)$/,
        name: "Codex",
        source: Qt.resolvedUrl("assets/codex.svg")
    }, {
        appId: /^claude$/,
        name: "Claude",
        source: Qt.resolvedUrl("assets/claude.svg")
    }, {
        appId: /^(kitty|net\.kovidgoyal\.kitty)$/,
        name: "Kitty",
        source: Qt.resolvedUrl("assets/whitesur/terminal.svg")
    }, {
        appId: /^(com\.github\.johnfactotum\.foliate|foliate)$/,
        name: "Foliate",
        source: Qt.resolvedUrl("assets/phosphor/book-open-duotone.svg")
    }]
    property var iconCache: ({})
    property var classHints: ({})
    property bool focusObserved: false
    property string focusedAddress: ""
    property var movedWindows: ({})
    property var activeByMonitor: ({})
    property bool refreshMonitorMetadata: true

    onCatalogChanged: iconCache = ({})

    function windowsFor(workspace): var {
        // Native workspace pointers are resolved by name, which is ambiguous
        // when numbered workspaces have identical names. Use IPC identities.
        return windows.filter(window => windowWorkspaceKey(window) === Logic.workspaceKey(workspace)
                && Logic.address(window.address))
            .sort((a, b) => a.address.localeCompare(b.address));
    }

    function windowWorkspaceKey(window): string {
        const moved = movedWindows[Logic.address(window.address)];
        return moved !== undefined ? moved : Logic.workspaceKey(window.lastIpcObject.workspace);
    }

    function monitorWorkspaceKey(monitor): string {
        if (!monitor) return "";
        const active = activeByMonitor[monitor.name];
        return active !== undefined ? active : Logic.workspaceKey(monitor.lastIpcObject.activeWorkspace);
    }

    function workspaceFocused(workspace): bool {
        return Logic.workspaceKey(workspace) === monitorWorkspaceKey(Hyprland.focusedMonitor);
    }

    function workspaceActive(workspace): bool {
        return Hyprland.monitors.values.some(monitor => Logic.workspaceKey(workspace) === monitorWorkspaceKey(monitor));
    }

    function requestMetadata(monitors): void {
        refreshMonitorMetadata = refreshMonitorMetadata || monitors === true;
        metadataRefresh.restart();
    }

    readonly property Timer metadataRefresh: Timer {
        interval: 40
        running: true
        onTriggered: {
            Hyprland.refreshToplevels();
            if (root.refreshMonitorMetadata) {
                root.refreshMonitorMetadata = false;
                root.activeByMonitor = ({});
                Hyprland.refreshMonitors();
            }
        }
    }

    function overrideInfo(candidates): var {
        const override = iconOverrides.find(rule => candidates.some(candidate => rule.appId.test(Logic.key(candidate))));
        return override ? {name: override.name, source: override.source} : null;
    }

    function desktopEntry(candidates): var {
        let entry = null;
        for (const candidate of candidates) {
            if (!candidate) continue;
            entry = DesktopEntries.byId(candidate.replace(/\.desktop$/i, ""));
            if (entry) break;
        }
        return entry || Logic.resolve(candidates, catalog);
    }

    function iconSource(icon): string {
        let source = icon ? iconCache[icon] : "";
        if (icon && source === undefined) {
            source = Quickshell.iconPath(icon, true);
            // A missing icon is not cached permanently.
            if (source) iconCache[icon] = source;
        }
        return source || "";
    }

    function applicationInfo(candidates, entry): var {
        const name = entry ? Logic.clean(entry.name) : candidates.map(Logic.clean).find(value => value) || "Window";
        const tray = Logic.trayItem(entry ? [...candidates, entry.id, entry.startupClass] : candidates,
            SystemTray.items.values);
        // Use the same live source as the tray, including pixmaps and updates.
        if (tray && tray.icon) return {name: name, source: tray.icon};
        const icon = entry ? entry.icon : "";
        for (const themed of Logic.themeIconNames(candidates, entry ? entry.id : "", icon)) {
            const source = iconSource(themed);
            if (source) return {name: name, source: source};
        }
        return {name: name, source: iconSource(icon)};
    }

    function programInfo(program): var {
        const app = applicationInfo([program], Logic.resolveProgram([program], catalog));
        if (app.source) return app;
        return overrideInfo([program]) || {name: Logic.clean(program) || "Terminal",
            source: (overrideInfo(["kitty"]) || {source: ""}).source};
    }

    function info(window): var {
        if (!window) return {name: "Window", source: ""};
        const terminal = TerminalState.appFor(window);
        if (terminal && terminal.kitty) {
            // Foreground identities take precedence over Kitty's app ID, even
            // when a launcher keeps a custom ID after the command exits.
            const fallback = overrideInfo(["kitty"]) || applicationInfo(["kitty"], desktopEntry(["kitty"]));
            for (const program of terminal.programs) {
                const app = applicationInfo([program], Logic.resolveProgram([program], catalog));
                if (app.source) return {name: app.name, source: app.source, fallbackSource: fallback.source};
                const override = overrideInfo([program]);
                if (override) return {name: override.name, source: override.source, fallbackSource: fallback.source};
            }
            return fallback;
        }
        const candidates = [window.wayland ? window.wayland.appId : "",
            classHints[Logic.address(window.address)] || "",
            window.lastIpcObject.class || "", window.lastIpcObject.initialClass || ""];
        return overrideInfo(candidates) || applicationInfo(candidates, desktopEntry(candidates));
    }

    function isFocused(window): bool {
        if (!window) return false;
        if (focusObserved) return Logic.address(window.address) === focusedAddress;
        return window.wayland ? window.wayland.activated : window.activated;
    }

    function activateWorkspace(workspace): bool {
        if (!workspace || !workspaces.includes(workspace)) return false;
        const request = Logic.workspaceRequest(workspace, Hyprland.usingLua);
        if (!request) return false;
        Hyprland.dispatch(request);
        return true;
    }

    function activateWindow(window): bool {
        if (!window || !windows.includes(window)
                || !workspaces.some(workspace => Logic.workspaceKey(workspace) === windowWorkspaceKey(window))) return false;
        // The Wayland method silently returns if Qt has no lastInputDevice.
        // Native IPC works for mouse, keyboard, and accessibility activation.
        const request = Logic.focusRequest(window.address, Hyprland.usingLua);
        if (!request) return false;
        Hyprland.dispatch(request);
        return true;
    }

    readonly property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event): void {
            // Copy values immediately: the native event object is reused.
            if (event.name === "activewindowv2") {
                root.focusedAddress = Logic.address(event.data);
                root.focusObserved = true;
            } else if (event.name === "openwindow") {
                const fields = event.parse(4);
                const hints = Object.assign({}, root.classHints);
                hints[Logic.address(fields[0])] = fields[2];
                root.classHints = hints;
                // openwindow contains a workspace name, not its unique ID.
                // Coalesce one snapshot for the burst; never infer from the name.
                root.requestMetadata(false);
            } else if (event.name === "movewindowv2") {
                const fields = event.parse(3);
                const moved = Object.assign({}, root.movedWindows);
                moved[Logic.address(fields[0])] = fields[1];
                root.movedWindows = moved;
            } else if (event.name === "workspacev2") {
                const monitor = Hyprland.focusedMonitor;
                if (monitor) {
                    const active = Object.assign({}, root.activeByMonitor);
                    active[monitor.name] = event.parse(2)[0];
                    root.activeByMonitor = active;
                }
            } else if (["monitoraddedv2", "monitorremoved", "moveworkspacev2", "configreloaded"].includes(event.name)) {
                root.requestMetadata(true);
            } else if (event.name === "closewindow") {
                const hints = Object.assign({}, root.classHints);
                delete hints[Logic.address(event.data)];
                root.classHints = hints;
                const moved = Object.assign({}, root.movedWindows);
                delete moved[Logic.address(event.data)];
                root.movedWindows = moved;
            }
        }
    }
}
