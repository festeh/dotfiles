import QtQuick
import Quickshell
ShellRoot {
    id: root
    property int phase: 0
    property bool passed: false
    Item { id: anchor; width: 44; height: 40 }
    NetworkPopup { id: popup; anchorItem: anchor; helperCommand: ["python3", Qt.resolvedUrl("mock.py").toString().slice(7)] }
    function require(value, message): void { if (!value) throw new Error(message); }
    function findItem(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) { const result = findItem(child, name); if (result) return result; }
        return null;
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            try {
                let controller = null;
                for (let item of popup.data) if (item.objectName === "network-picker-controller") controller = item;
                root.require(controller, "Controller not found");
                if (controller.rows.length !== 2) return;
                const field = root.findItem(popup.contentItem, "network-password");
                root.require(field, "Password input not found");
                if (root.phase === 0) {
                    popup.pick(controller.rows[0]);
                    root.require(popup.passwordFor.id === "new", "Unsaved network did not prompt");
                    root.require(field.echoMode === TextInput.Password, "Password is not masked");
                    field.text = "example-password";
                    popup.submitPassword();
                    root.require(field.text === "" && popup.passwordFor === null, "Submitted password was retained");
                    root.phase = 1;
                } else if (root.phase === 1 && popup.passwordFor) {
                    root.require(popup.passwordFor.id === "new" && field.text === "", "Retry did not clear password");
                    popup.passwordFor = null;
                    popup.pick(controller.rows[1]);
                    root.phase = 2;
                } else if (root.phase === 2 && popup.passwordFor) {
                    root.require(popup.passwordFor.id === "saved" && field.text === "", "Saved-network retry did not prompt");
                    console.log("PICKER_MOCK_UI_PASSED");
                    root.passed = true;
                    Qt.quit();
                }
            } catch (error) { console.error("PICKER_MOCK_UI_FAILED", error.message); Qt.quit(); }
        }
    }
    Timer { interval: 6000; running: true; onTriggered: { console.error("PICKER_MOCK_UI_TIMEOUT"); Qt.quit(); } }
}
