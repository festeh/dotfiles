import QtQuick
import Quickshell

ShellRoot {
    id: root
    property var notificationState: NotificationState
    property real frozenAt: 0
    property int resumeUpdates: 0
    property bool frozen: false
    property bool waitingForMinute: false
    property real minuteBefore: 0
    property bool finished: false

    function require(value, message): void {
        if (!value) throw new Error(message);
    }
    function fail(message): void {
        console.error("CLOCK_STATE_FAILED", message);
        Qt.quit();
    }
    function finish(): void {
        root.finished = true;
        console.log("CLOCK_STATE_PASSED");
        Qt.quit();
    }

    Component.onCompleted: Qt.callLater(() => {
        try {
            root.require(typeof ClockState.clock.refresh === "undefined", "Runtime still has the custom native refresh API");
            root.require(ClockState.clock.enabled, "Clock starts disabled");
            root.require(ClockState.clock.precision === SystemClock.Minutes, "Clock starts at the wrong precision");
            root.require(ClockState.now.getSeconds() === 0, "Minute clock includes seconds");
            // Use seconds only in this private fixture so a paused timestamp can
            // become stale without waiting a full minute or changing host time.
            ClockState.clock.precision = SystemClock.Seconds;
            ClockState.clock.enabled = false;
            root.frozenAt = ClockState.now.getTime();
            root.frozen = true;
        } catch (error) { root.fail(error.message); }
    })

    Connections {
        target: ClockState
        function onNowChanged(): void {
            if (root.frozen) ++root.resumeUpdates;
            if (!root.waitingForMinute || root.finished) return;
            try {
                root.require(ClockState.now.getTime() === root.minuteBefore + 60000, "Native clock skipped the next minute");
                root.require(Math.abs(Date.now() - ClockState.now.getTime()) < 1500, "Native minute rollover was late");
                root.require(ClockState.now.getSeconds() === 0, "Native minute rollover lost precision");
                root.finish();
            } catch (error) { root.fail(error.message); }
        }
    }

    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (!root.frozen || root.finished) return;
            try {
                if (!ClockState.clock.enabled) {
                    root.require(ClockState.now.getTime() === root.frozenAt && root.resumeUpdates === 0,
                        "Paused clock changed before the resume event");
                    return;
                }
                // NotificationState's production parser has received the mock
                // PrepareForSleep(false) event and called ClockState.refresh().
                root.require(Date.now() - root.frozenAt >= 1000, "Fixture did not leave a stale timestamp");
                root.require(root.resumeUpdates === 1, "Resume did not update the paused clock once");
                root.require(Math.abs(Date.now() - ClockState.now.getTime()) < 1000, "Resume retained a stale timestamp");
                root.frozen = false;
                ClockState.clock.precision = SystemClock.Minutes;
                ClockState.refresh();
                ClockState.refresh();
                root.require(ClockState.clock.enabled && ClockState.now.getSeconds() === 0,
                    "Refresh did not leave an enabled minute clock");
                root.require(ClockState.timeText === Qt.formatDateTime(ClockState.now, "HH:mm"), "Time text is stale");
                root.require(ClockState.fullDate === Qt.formatDate(ClockState.now, "dddd, d MMMM yyyy"), "Date text is stale");
                if (Quickshell.env("QS_CLOCK_CHECK_MINUTE") === "1") {
                    root.minuteBefore = ClockState.now.getTime();
                    root.waitingForMinute = true;
                } else {
                    root.finish();
                }
            } catch (error) { root.fail(error.message); }
        }
    }
    Timer {
        interval: Quickshell.env("QS_CLOCK_CHECK_MINUTE") === "1" ? 70000 : 7000
        running: true
        onTriggered: root.fail("Timed out waiting for the resume event or minute rollover")
    }
}
