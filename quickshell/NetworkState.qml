pragma Singleton

import QtQuick
import Quickshell.Networking
import "NetworkLogic.js" as NetworkLogic

QtObject {
    property Item pickerOwner: null
    // One native D-Bus subscription shared by all outputs. Observing status
    // does not enable radios, request scans, or run connectivity probes.
    readonly property var status: NetworkLogic.describe(NetworkStatus.snapshot)
}
