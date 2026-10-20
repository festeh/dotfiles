pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "LauncherLogic.js" as Search

Scope {
    id: root
    property var helperCommand: ["python3", Quickshell.shellPath("launcher_backend.py")]
    property bool opened: false
    property string category: "apps"
    property string query: ""
    property string message: ""
    property string previousWindow: ""
    property var selectedScreen: null
    property var catalogs: ({})
    property var metadata: ({})
    property var coverSources: ({})
    property var pendingAction: null
    property bool transportReady: false
    property bool testMode: false
    property bool reopenOnActionError: false
    readonly property var windowItem: window
    property alias currentIndex: resultsView.currentIndex
    readonly property var categories: [
        {id: "apps", title: "Apps", icon: "view-grid-symbolic"},
        {id: "books", title: "Books", icon: "accessories-ebook-reader"},
        {id: "clipboard", title: "Clipboard", icon: "edit-paste"},
        {id: "power", title: "Power", icon: "system-shutdown"},
        {id: "shortcuts", title: "Shortcuts", icon: "preferences-desktop-keyboard-shortcuts"},
        {id: "widgets", title: "Widgets", icon: "preferences-system"}
    ]
    readonly property var currentCategory: categories.find(item => item.id === category) || categories[0]
    readonly property var results: category === "widgets" ? catalogs.widgets || [] : Search.rank(catalogs[category] || [], query)
    readonly property var currentMeta: metadata[category] || ({loading: !transportReady, message: ""})

    function send(command): void {
        if (helper.running) helper.write(JSON.stringify(command) + "\n");
    }

    function focusInput(): void {
        if (category === "widgets") page.forceActiveFocus();
        else search.forceActiveFocus();
    }

    function open(requested: string): void {
        if (!categories.some(item => item.id === requested)) requested = "apps";
        if (!helper.running) helper.running = true;
        if (opened && category === requested) { close(); return; }
        if (!opened) {
            previousWindow = Hyprland.activeToplevel ? "0x" + Hyprland.activeToplevel.address.replace(/^0x/, "") : "";
            const monitor = Hyprland.focusedMonitor;
            selectedScreen = Quickshell.screens.find(screen => monitor && screen.name === monitor.name)
                || Quickshell.screens[0];
            query = "";
            search.text = "";
        }
        pendingAction = null;
        reopenOnActionError = false;
        category = requested;
        message = "";
        opened = true;
        window.visible = true;
        send({action: "show", category: category});
        resultsView.currentIndex = results.length ? 0 : -1;
        Qt.callLater(() => { focusInput(); grab.active = !testMode; });
    }

    function close(): void {
        reopenOnActionError = false;
        opened = false;
        send({action: "hide"});
        grab.active = false;
        window.visible = false;
    }

    function switchCategory(delta: int): void {
        const index = categories.findIndex(item => item.id === category);
        category = categories[(index + delta + categories.length) % categories.length].id;
        message = "";
        resultsView.currentIndex = results.length ? 0 : -1;
        send({action: "show", category: category});
        focusInput();
    }

    function moveSelection(delta: int): void {
        if (!results.length) return;
        resultsView.currentIndex = (Math.max(0, resultsView.currentIndex) + delta + results.length) % results.length;
        resultsView.positionViewAtIndex(resultsView.currentIndex, ListView.Contain);
    }

    function activate(row: var, paste: bool): void {
        if (!row || row.enabled === false) return;
        if (category === "widgets" && row.id.startsWith("idle:") && row.selected) return;
        const action = {action: "activate", category: category, id: row.id,
            paste: paste && category === "clipboard", target: previousWindow};
        if (category === "widgets") send(action);
        else { pendingAction = action; close(); reopenOnActionError = true; }
    }

    function dispatchPending(): void {
        if (!pendingAction) return;
        const action = pendingAction;
        pendingAction = null;
        send(action);
    }

    function handleKey(event: var): void {
        const control = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key === Qt.Key_Escape) close();
        else if (control && event.key === Qt.Key_J || event.key === Qt.Key_Down) moveSelection(1);
        else if (control && event.key === Qt.Key_K || event.key === Qt.Key_Up) moveSelection(-1);
        else if (control && event.key === Qt.Key_H) switchCategory(-1);
        else if (control && event.key === Qt.Key_L) switchCategory(1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            activate(results[resultsView.currentIndex], (event.modifiers & Qt.ShiftModifier) !== 0);
        else if (event.key === Qt.Key_F5) send({action: "refresh"});
        else { event.accepted = false; return; }
        event.accepted = true;
    }

    function receive(line: string): void {
        try {
            const value = JSON.parse(line);
            if (value.type === "catalog") {
                transportReady = true;
                const selected = resultsView.currentIndex >= 0 ? results[resultsView.currentIndex]?.id : "";
                const next = Object.assign({}, catalogs);
                next[value.category] = Search.prepare(value.rows);
                catalogs = next;
                if (value.category === "books") coverSources = ({});
                const state = Object.assign({}, metadata);
                state[value.category] = {loading: value.loading, message: value.message};
                metadata = state;
                if (value.category === category) {
                    const index = results.findIndex(row => row.id === selected);
                    resultsView.currentIndex = results.length ? Math.max(0, index) : -1;
                    coverDelay.restart();
                }
            } else if (value.type === "cover") {
                const next = Object.assign({}, coverSources);
                next[value.id] = value.source;
                coverSources = next;
            } else if (value.type === "error") {
                message = value.message;
                if (!opened && selectedScreen && reopenOnActionError) {
                    reopenOnActionError = false;
                    opened = true;
                    window.visible = true;
                    Qt.callLater(() => { focusInput(); grab.active = !testMode; });
                }
            }
        } catch (_) { message = "Launcher data unavailable. Reopen to retry."; }
    }

    function iconFor(row: var): string {
        if (row.clipboardKind === "text") return Qt.resolvedUrl("assets/clipboard-text.svg");
        if (row.clipboardKind === "image") return Qt.resolvedUrl("assets/clipboard-image.svg");
        if (coverSources[row.id] || row.cover) return coverSources[row.id] || row.cover;
        const id = row.id.startsWith("app:") ? row.id.slice(4).replace(/\.desktop$/, "") : row.icon;
        const override = WorkspaceState.overrideInfo([id || ""]);
        if (override) return override.source;
        if (row.id.startsWith("app:")) {
            const app = WorkspaceState.applicationInfo([id], WorkspaceState.desktopEntry([id]));
            if (app.source) return app.source;
        }
        if (row.icon && row.icon.startsWith("/")) return "file://" + row.icon;
        return row.icon ? Quickshell.iconPath(row.icon, true) : "";
    }

    onResultsChanged: {
        resultsView.currentIndex = results.length ? 0 : -1;
        coverDelay.restart();
    }
    onQueryChanged: message = ""

    Process {
        id: helper
        command: root.helperCommand
        stdinEnabled: true
        running: true
        onStarted: if (root.opened) root.send({action: "show", category: root.category})
        onExited: {
            root.transportReady = false;
            root.message = "Launcher service stopped. Reopen to retry.";
        }
        stdout: SplitParser { onRead: data => root.receive(data) }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.opened
        onActivated: root.close()
    }

    IpcHandler {
        target: "launcher"
        function open(category: string): void { root.open(category); }
        function close(): void { root.close(); }
        function status(): string {
            return JSON.stringify({visible: root.opened, category: root.category,
                count: root.results.length, queryLength: root.query.length,
                ready: root.transportReady, error: !!root.message, grabbed: grab.active,
                activeProfile: (root.catalogs.widgets || []).find(row => row.id.startsWith("profile:") && row.selected)?.id || "",
                keepAwake: !!(root.catalogs.widgets || []).find(row => row.id === "idle:awake")?.selected});
        }
    }

    Timer {
        id: coverDelay
        interval: 100
        onTriggered: {
            if (!root.opened || root.category !== "books") return;
            const first = Math.max(0, Math.floor(resultsView.contentY / 62));
            root.send({action: "covers", ids: root.results.slice(first, first + 14).map(row => row.id)});
        }
    }

    // The Wayland backend supplies this factory type at runtime.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: window
        visible: false
        screen: root.selectedScreen
        implicitWidth: Math.min(960, (screen ? screen.width : 1200) - 48)
        implicitHeight: Math.min(590, (screen ? screen.height : 800) - 100)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onBackingWindowVisibleChanged: {
            if (backingWindowVisible) {
                root.focusInput();
                grab.active = !root.testMode;
            } else root.dispatchPending();
        }

        HyprlandFocusGrab {
            id: grab
            windows: [window]
            onCleared: if (root.opened) root.close()
        }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Theme.base
            border { color: Theme.hover; width: 1 }
        }

        FocusScope {
            id: page
            anchors { fill: parent; margins: 1 }
            focus: true
            Keys.onPressed: event => root.handleKey(event)

            Rectangle {
                id: sidebar
                width: 180
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 10 }
                radius: 12
                color: Theme.surface

                Text {
                    x: 18; y: 19
                    text: "LAUNCHER"
                    color: Theme.muted
                    font { family: Theme.fontFamily; pixelSize: 11; letterSpacing: 2; bold: true }
                }

                Column {
                    x: 8; y: 61; width: parent.width - 16
                    spacing: 6
                    Repeater {
                        model: root.categories
                        delegate: Button {
                            id: categoryButton
                            required property var modelData
                            objectName: "launcher-category-" + modelData.id
                            width: parent.width; height: 44
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            padding: 0
                            Accessible.name: modelData.title
                            background: Rectangle {
                                radius: 8
                                color: categoryButton.hovered ? Theme.hover
                                    : root.category === categoryButton.modelData.id ? Qt.alpha(Theme.accent, 0.10) : "transparent"
                            }
                            contentItem: Row {
                                leftPadding: 13
                                spacing: 12
                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 18
                                    source: Quickshell.iconPath(categoryButton.modelData.icon, true)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: categoryButton.modelData.title
                                    color: root.category === categoryButton.modelData.id ? Theme.accent : Theme.subtext
                                    font { family: Theme.fontFamily; pixelSize: 13; bold: root.category === categoryButton.modelData.id }
                                }
                            }
                            onClicked: {
                                if (root.category !== modelData.id) {
                                    root.category = modelData.id;
                                    root.message = "";
                                    root.send({action: "show", category: root.category});
                                }
                                root.focusInput();
                            }
                        }
                    }
                }

                Text {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 18 }
                    text: "Ctrl H / L\nchange category"
                    lineHeight: 1.6
                    color: Theme.muted
                    font { family: Theme.fontFamily; pixelSize: 10 }
                }
            }

            ColumnLayout {
                anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom;
                    leftMargin: 22; rightMargin: 22; topMargin: 20; bottomMargin: 16 }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root.currentCategory.title
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: 18; bold: true }
                    }
                    CalendarAction {
                        objectName: "launcher-refresh"
                        Accessible.name: "Refresh"
                        Accessible.description: "Refresh this category (F5)"
                        contentItem: Item {
                            implicitWidth: 16
                            implicitHeight: 16
                            IconImage {
                                objectName: "launcher-refresh-icon"
                                anchors.centerIn: parent
                                implicitSize: 16
                                source: Qt.resolvedUrl("assets/refresh.svg")
                            }
                        }
                        onClicked: { root.send({action: "refresh"}); root.focusInput(); }
                    }
                }

                TextField {
                    id: search
                    visible: root.category !== "widgets"
                    objectName: "launcher-search"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    placeholderText: "Search " + root.currentCategory.title.toLowerCase() + "…"
                    color: Theme.text
                    placeholderTextColor: Theme.muted
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.base
                    font { family: Theme.fontFamily; pixelSize: 15 }
                    leftPadding: 14; rightPadding: 14
                    background: Rectangle {
                        radius: 10
                        color: Theme.surface
                        border { width: 1; color: search.activeFocus ? Qt.alpha(Theme.accent, 0.6) : Theme.hover }
                    }
                    onTextChanged: root.query = text
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => root.handleKey(event)
                }

                ListView {
                    id: resultsView
                    visible: root.category !== "widgets"
                    objectName: "launcher-results"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: root.results
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: count ? 0 : -1
                    onContentYChanged: coverDelay.restart()
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Button {
                        id: resultButton
                        required property var modelData
                        required property int index
                        width: resultsView.width
                        height: 60
                        padding: 0
                        hoverEnabled: true
                        focusPolicy: Qt.NoFocus
                        enabled: modelData.enabled !== false
                        opacity: enabled ? 1 : 0.45
                        Accessible.name: modelData.title
                        Accessible.description: modelData.detail || ""
                        background: Rectangle {
                            radius: 9
                            color: resultButton.down ? Theme.hover
                                : resultsView.currentIndex === resultButton.index ? Theme.surface
                                : resultButton.hovered ? Qt.alpha(Theme.surface, 0.65) : "transparent"
                        }
                        contentItem: RowLayout {
                            spacing: 13
                            Item {
                                Layout.leftMargin: 13
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 42
                                IconImage {
                                    id: resultIcon
                                    anchors.centerIn: parent
                                    implicitSize: resultButton.modelData.cover || root.coverSources[resultButton.modelData.id] ? 38 : 27
                                    source: root.iconFor(resultButton.modelData)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18; height: 18; radius: 5
                                    color: "transparent"
                                    border { width: 1; color: Theme.muted }
                                    visible: resultIcon.status !== Image.Ready
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    Layout.fillWidth: true
                                    text: resultButton.modelData.title
                                    textFormat: Text.PlainText
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: 13 }
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: resultButton.modelData.detail || ""
                                    visible: text.length > 0
                                    textFormat: Text.PlainText
                                    color: Theme.subtext
                                    font { family: Theme.fontFamily; pixelSize: 10 }
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                            Text {
                                Layout.rightMargin: 14
                                visible: !!resultButton.modelData.selected && !resultButton.modelData.toggle
                                text: "Active"
                                color: Theme.accent
                                font { family: Theme.fontFamily; pixelSize: 10 }
                            }
                            Rectangle {
                                Layout.rightMargin: 14
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 19
                                visible: resultButton.modelData.toggle === true
                                radius: 10
                                color: resultButton.modelData.selected ? Theme.accent : Theme.hover
                                Rectangle {
                                    x: resultButton.modelData.selected ? 17 : 3
                                    y: 3; width: 13; height: 13; radius: 7
                                    color: resultButton.modelData.selected ? Theme.base : Theme.subtext
                                }
                            }
                        }
                        onClicked: { resultsView.currentIndex = index; root.activate(modelData, false); }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 50
                        visible: resultsView.count === 0
                        text: root.currentMeta.loading ? "Loading…" : root.currentMeta.message
                            || (root.query.length ? "No matches" : "Nothing here yet")
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Theme.subtext
                        font { family: Theme.fontFamily; pixelSize: 13 }
                    }
                }

                ColumnLayout {
                    id: widgetCards
                    visible: root.category === "widgets"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: profilesColumn.implicitHeight + 36
                        radius: 14
                        color: Theme.surface
                        ColumnLayout {
                            id: profilesColumn
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                            spacing: 14
                            Text {
                                text: "Power profile"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: 15; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Choose how your laptop balances power, noise and speed."
                                color: Theme.subtext
                                wrapMode: Text.WordWrap
                                font { family: Theme.fontFamily; pixelSize: 11 }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 10; rowSpacing: 10
                                Repeater {
                                    model: (root.catalogs.widgets || []).filter(row => row.id.startsWith("profile:"))
                                    delegate: Button {
                                        id: profileChoice
                                        required property var modelData
                                        readonly property int resultIndex: root.results.findIndex(row => row.id === modelData.id)
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 58
                                        enabled: modelData.enabled !== false
                                        hoverEnabled: true
                                        focusPolicy: Qt.NoFocus
                                        opacity: enabled ? 1 : 0.5
                                        padding: 14
                                        Accessible.name: modelData.title
                                        Accessible.description: modelData.selected ? "Current power profile" : "Set power profile"
                                        background: Rectangle {
                                            radius: 10
                                            color: profileChoice.hovered ? Theme.hover : Theme.base
                                            border { width: 1; color: profileChoice.modelData.selected ? Theme.accent
                                                : root.currentIndex === profileChoice.resultIndex ? Theme.border : "transparent" }
                                        }
                                        contentItem: RowLayout {
                                            Text {
                                                Layout.fillWidth: true
                                                text: profileChoice.modelData.title
                                                color: profileChoice.modelData.selected ? Theme.accent : Theme.text
                                                font { family: Theme.fontFamily; pixelSize: 12 }
                                            }
                                            IconImage {
                                                implicitSize: 20
                                                source: Qt.resolvedUrl("assets/power-" + profileChoice.modelData.id.slice(8) + ".svg")
                                                opacity: profileChoice.modelData.selected ? 1 : 0.7
                                            }
                                        }
                                        onClicked: {
                                            root.currentIndex = resultIndex;
                                            root.activate(modelData, false);
                                            root.focusInput();
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: (root.catalogs.widgets || []).length > 0
                                    && !(root.catalogs.widgets || []).some(row => row.id.startsWith("profile:"))
                                text: "Power profiles are unavailable on this system."
                                color: Theme.muted
                                font { family: Theme.fontFamily; pixelSize: 11 }
                            }
                        }
                    }

                    Rectangle {
                        id: sleepCard
                        objectName: "launcher-sleep-behavior"
                        readonly property var choices: (root.catalogs.widgets || []).filter(row => row.id.startsWith("idle:"))
                        readonly property var awakeMode: choices.find(row => row.id === "idle:awake") || ({})
                        readonly property var chosenMode: choices.find(row => row.selected)
                        Layout.fillWidth: true
                        implicitHeight: sleepColumn.implicitHeight + 36
                        radius: 14
                        color: Theme.surface
                        ColumnLayout {
                            id: sleepColumn
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                            spacing: 12
                            Text {
                                text: "Sleep behavior"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: 15; bold: true }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Repeater {
                                    model: sleepCard.choices
                                    delegate: Button {
                                        id: sleepChoice
                                        required property var modelData
                                        readonly property int resultIndex: root.results.findIndex(row => row.id === modelData.id)
                                        objectName: "launcher-sleep-" + modelData.id.slice(5)
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        Layout.preferredHeight: 48
                                        enabled: modelData.enabled !== false
                                        opacity: enabled ? 1 : 0.5
                                        hoverEnabled: true
                                        focusPolicy: Qt.NoFocus
                                        padding: 14
                                        Accessible.name: modelData.title
                                        Accessible.description: modelData.detail
                                        Accessible.role: Accessible.RadioButton
                                        Accessible.checkable: true
                                        Accessible.checked: !!modelData.selected
                                        background: Rectangle {
                                            radius: 10
                                            color: sleepChoice.hovered ? Theme.hover : Theme.base
                                            border { width: 1; color: sleepChoice.modelData.selected ? Theme.accent
                                                : root.currentIndex === sleepChoice.resultIndex ? Theme.border : "transparent" }
                                        }
                                        contentItem: Text {
                                            text: sleepChoice.modelData.title
                                            color: sleepChoice.modelData.selected ? Theme.accent : Theme.text
                                            font { family: Theme.fontFamily; pixelSize: 12 }
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: {
                                            root.currentIndex = resultIndex;
                                            root.activate(modelData, false);
                                            root.focusInput();
                                        }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: !sleepCard.choices.length ? "Reading sleep state…"
                                    : !sleepCard.awakeMode.known ? "Sleep status unavailable"
                                    : sleepCard.chosenMode ? sleepCard.chosenMode.detail : "Reading sleep state…"
                                color: Theme.subtext
                                wrapMode: Text.WordWrap
                                font { family: Theme.fontFamily; pixelSize: 11 }
                            }
                            Text {
                                objectName: "launcher-sleep-external"
                                Layout.fillWidth: true
                                visible: sleepCard.awakeMode.known === true && sleepCard.awakeMode.blockedByOther === true
                                text: "Automatic sleep is currently paused by another app."
                                color: Theme.attention
                                wrapMode: Text.WordWrap
                                font { family: Theme.fontFamily; pixelSize: 11 }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.message || root.currentMeta.message || ""
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    color: root.message ? Theme.critical : Theme.attention
                    font { family: Theme.fontFamily; pixelSize: 11 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Ctrl J / K select"
                        color: Theme.muted
                        font { family: Theme.fontFamily; pixelSize: 10 }
                    }
                }
            }
        }
    }
}
