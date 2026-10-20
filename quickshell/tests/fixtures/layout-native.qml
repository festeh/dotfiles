import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    FloatingWindow {
        visible: true
        implicitWidth: 90
        implicitHeight: 44
        Row {
            LayoutWidget {
                id: widget
                onPointerInteraction: keyboardNavigation = false
                onKeyboardInteraction: keyboardNavigation = true
                TestEvent { id: events }
            }
            BatteryIcon {
                level: 1
                known: true
                marker: "plugged"
                foreground: Theme.positive
            }
        }
    }
    IpcHandler {
        target: "layout-test"
        function state(): string {
            return JSON.stringify({status: LayoutState.status, error: LayoutState.error,
                visible: widget.visible, busy: LayoutState.snapshot.running,
                cycling: LayoutState.cycling, focused: widget.activeFocus});
        }
        function refresh(): void { LayoutState.refresh(); }
        function click(): bool { return events.mouseClick(widget, widget.width/2, widget.height/2, Qt.LeftButton, Qt.NoModifier, 0); }
        function key(code: int): bool {
            widget.forceActiveFocus(Qt.TabFocusReason);
            return events.keyClick(code, Qt.NoModifier, 0);
        }
    }
}
