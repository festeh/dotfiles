pragma Singleton

import QtQuick
import Quickshell.Services.UPower
import "BatteryLogic.js" as BatteryLogic

QtObject {
    // One subscription shared by every output. UPower refreshes after resume.
    readonly property var status: BatteryLogic.describe(UPower.displayDevice, UPower.onBattery)
}
