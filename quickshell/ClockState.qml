pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property date now: clock.date
    readonly property string timeText: Qt.formatDateTime(now, "HH:mm")
    readonly property string fullDate: Qt.formatDate(now, "dddd, d MMMM yyyy")

    // One native clock shared by all outputs. No second timer or date process.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
    }

    function refresh(): void {
        clock.refresh();
    }
}
