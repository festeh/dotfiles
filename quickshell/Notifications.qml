import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    Binding {
        target: NotificationState
        property: "focusedMonitorName"
        value: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }
    Variants {
        model: Quickshell.screens
        NotificationPopups {
            required property var modelData
            monitor: modelData
        }
    }
    IpcHandler {
        target: "notifications"
        function status(): string {
            return JSON.stringify({active: NotificationState.count,
                critical: NotificationState.entries.filter(entry => entry.critical).length});
        }
    }
}
