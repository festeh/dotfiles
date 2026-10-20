pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    required property Item anchorItem
    property var helperCommand: ["python3", Quickshell.shellPath("network_picker.py")]
    property var passwordFor: null
    property bool revealPassword: false
    property string selectedId: ""
    property string localMessage: ""
    readonly property bool connected: picker.rows.some(row => row.connected)
    signal dismissed()

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 6
    grabFocus: true
    color: "transparent"
    implicitWidth: 388
    implicitHeight: column.implicitHeight + 28

    onVisibleChanged: {
        if (!visible) {
            password.clear();
            dismissed();
        }
    }
    onBackingWindowVisibleChanged: {
        if (backingWindowVisible)
            networks.forceActiveFocus(Qt.PopupFocusReason);
    }

    function selectIndex(index: int): void {
        if (index >= 0 && index < picker.rows.length) {
            selectedId = picker.rows[index].id;
            networks.positionViewAtIndex(index, ListView.Contain);
        }
    }

    function prompt(row): void {
        password.clear();
        revealPassword = false;
        passwordFor = row;
        password.forceActiveFocus(Qt.OtherFocusReason);
    }

    function pick(row): void {
        if (!row || picker.snapshot.busy || row.connected)
            return;
        localMessage = "";
        passwordFor = null;
        password.clear();
        if (!row.supported) {
            localMessage = "This network needs a configured NetworkManager profile.";
        } else if (row.personal && !row.known) {
            prompt(row);
        } else {
            picker.send({action: "connect", id: row.id});
        }
    }

    function submitPassword(): void {
        if (!passwordFor || !password.text.length || picker.snapshot.busy)
            return;
        picker.send({action: "connect", id: passwordFor.id, password: password.text});
        password.clear();
        passwordFor = null;
        networks.forceActiveFocus(Qt.OtherFocusReason);
    }

    NetworkPicker {
        id: picker
        command: root.helperCommand
        onPasswordRequested: (row, retry) => root.prompt(row)
        onRowsChanged: {
            if (root.passwordFor && !rows.some(row => row.id === root.passwordFor.id)) {
                root.passwordFor = null;
                password.clear();
                root.localMessage = "This network is no longer available.";
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.surface
        border { color: Theme.border; width: 1 }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: event => {
            if (root.passwordFor) {
                root.passwordFor = null;
                password.clear();
                networks.forceActiveFocus(Qt.OtherFocusReason);
            } else {
                root.visible = false;
            }
            event.accepted = true;
        }

        Column {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                width: parent.width
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: 15; bold: true }
                }
                CalendarAction {
                    text: picker.snapshot.wifiEnabled ? "Turn off" : "Turn on"
                    enabled: picker.snapshot.available && picker.snapshot.hasWifi
                        && picker.snapshot.hardwareEnabled && !picker.snapshot.busy
                    opacity: enabled ? 1 : 0.4
                    onClicked: {
                        root.passwordFor = null;
                        password.clear();
                        root.localMessage = "";
                        picker.send({action: "wifi", enabled: !picker.snapshot.wifiEnabled});
                    }
                }
                CalendarAction {
                    text: picker.snapshot.scanning ? "Scanning…" : "Refresh"
                    enabled: picker.snapshot.wifiEnabled && picker.snapshot.hardwareEnabled
                        && picker.snapshot.managed && !picker.snapshot.scanning && !picker.snapshot.busy
                    opacity: enabled ? 1 : 0.4
                    onClicked: { root.localMessage = ""; picker.send({action: "scan"}); }
                }
                CalendarAction {
                    text: "×"
                    Accessible.name: "Close Wi-Fi picker"
                    onClicked: root.visible = false
                }
            }

            Text {
                width: parent.width
                visible: picker.rows.length === 0
                text: !picker.snapshot.ready ? "Loading networks…"
                    : !picker.snapshot.available ? "NetworkManager unavailable"
                    : !picker.snapshot.hasWifi ? "No Wi-Fi adapter"
                    : !picker.snapshot.hardwareEnabled ? "Wi-Fi blocked by hardware switch"
                    : !picker.snapshot.wifiEnabled ? "Wi-Fi is off"
                    : !picker.snapshot.managed ? "Wi-Fi is unmanaged"
                    : picker.snapshot.scanning ? "Looking for networks…" : "No networks found. Refresh to scan again."
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Theme.subtext
                font { family: Theme.fontFamily; pixelSize: 12 }
                topPadding: 12
                bottomPadding: 12
            }

            ListView {
                id: networks
                width: parent.width
                height: Math.min(312, contentHeight)
                model: picker.rows
                spacing: 4
                clip: true
                focus: true
                keyNavigationEnabled: false
                currentIndex: Math.max(0, picker.rows.findIndex(row => row.id === root.selectedId))
                boundsBehavior: Flickable.StopAtBounds
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                        root.selectIndex(Math.max(0, Math.min(count - 1, currentIndex + (event.key === Qt.Key_Down ? 1 : -1))));
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                        root.selectIndex(event.key === Qt.Key_Home ? 0 : count - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.pick(picker.rows[currentIndex]);
                        event.accepted = true;
                    }
                }
                ScrollBar.vertical: ScrollBar {
                    width: 4
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Theme.border; implicitWidth: 4; implicitHeight: 24 }
                    background: Item {}
                }
                delegate: Button {
                    id: row
                    required property var modelData
                    required property int index
                    width: networks.width - 8
                    height: 48
                    padding: 0
                    topInset: 0
                    bottomInset: 0
                    leftInset: 0
                    rightInset: 0
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    enabled: !picker.snapshot.busy
                    Accessible.name: modelData.name + ", " + (modelData.connected ? "Connected" : modelData.security)
                    onClicked: {
                        root.selectIndex(index);
                        networks.forceActiveFocus(Qt.MouseFocusReason);
                        root.pick(modelData);
                    }
                    background: Rectangle {
                        radius: 9
                        color: row.down || row.hovered || (networks.activeFocus && row.ListView.isCurrentItem)
                            ? Theme.hover : row.modelData.connected ? Theme.base : "transparent"
                        border.width: row.modelData.connected || (networks.activeFocus && row.ListView.isCurrentItem) ? 1 : 0
                        border.color: row.modelData.connected ? Theme.border : Theme.accent
                    }
                    contentItem: RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 10
                        NetworkIcon {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            kind: row.modelData.connected && NetworkState.status.kind === "phone" ? "phone" : "wifi"
                            level: Math.max(1, Math.ceil(row.modelData.signal * 3 / 100))
                            marker: ""
                            foreground: row.modelData.connected ? Theme.accent : Theme.text
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name.replace(/\s+/g, " ")
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: 13 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.connected ? "Connected" : row.modelData.connecting ? "Connecting…"
                                    : row.modelData.security + (row.modelData.known ? " · Saved" : "")
                                elide: Text.ElideRight
                                color: Theme.subtext
                                font { family: Theme.fontFamily; pixelSize: 10 }
                            }
                        }
                        Text {
                            visible: row.modelData.connecting && !row.modelData.connected
                            text: "…"
                            color: Theme.subtext
                            font { family: Theme.fontFamily; pixelSize: 12 }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                visible: root.passwordFor !== null
                spacing: 8
                Text {
                    width: parent.width
                    text: "Password for " + (root.passwordFor ? root.passwordFor.name.replace(/\s+/g, " ") : "")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: 12 }
                }
                RowLayout {
                    width: parent.width
                    spacing: 6
                    TextField {
                        id: password
                        objectName: "network-password"
                        Layout.fillWidth: true
                        implicitHeight: 34
                        placeholderText: "Password"
                        echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
                        color: Theme.text
                        placeholderTextColor: Theme.muted
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.base
                        leftPadding: 10
                        rightPadding: 10
                        font { family: Theme.fontFamily; pixelSize: 13 }
                        background: Rectangle {
                            radius: 7
                            color: Theme.base
                            border { width: 1; color: password.activeFocus ? Theme.accent : Theme.border }
                        }
                        onAccepted: root.submitPassword()
                    }
                    CalendarAction {
                        text: root.revealPassword ? "Hide" : "Show"
                        onClicked: root.revealPassword = !root.revealPassword
                    }
                }
                RowLayout {
                    width: parent.width
                    Item { Layout.fillWidth: true }
                    CalendarAction {
                        text: "Cancel"
                        onClicked: { root.passwordFor = null; password.clear(); networks.forceActiveFocus(Qt.OtherFocusReason); }
                    }
                    CalendarAction {
                        text: "Connect"
                        emphasized: true
                        enabled: password.text.length > 0 && !picker.snapshot.busy
                        opacity: enabled ? 1 : 0.4
                        onClicked: root.submitPassword()
                    }
                }
            }

            Text {
                width: parent.width
                text: picker.transportError || root.localMessage || picker.snapshot.message
                visible: text.length > 0
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Theme.subtext
                font { family: Theme.fontFamily; pixelSize: 11 }
            }

            CalendarAction {
                visible: root.connected
                text: "Disconnect"
                enabled: !picker.snapshot.busy
                opacity: enabled ? 1 : 0.4
                onClicked: picker.send({action: "disconnect"})
            }
        }
    }
}
