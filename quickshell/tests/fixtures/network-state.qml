import QtQuick
import Quickshell
import Quickshell.Networking

ShellRoot {
    id: root
    property int phase: 0

    QtObject {
        id: profile
        property var metadata: ({user: {data: {"unrelated.key": "preserved"}}})
        function read() { return metadata; }
        signal loaded()
        signal settingsChanged(var settings)
    }
    QtObject {
        id: wifiNetwork
        property string name: "Example Wi-Fi"
        property int state: wifi.state
        readonly property bool connected: state === ConnectionState.Connected
        readonly property bool stateChanging: state === ConnectionState.Connecting || state === ConnectionState.Disconnecting
        property real signalStrength: 0.36
        property var nmSettings: [profile]
    }
    QtObject {
        id: wifi
        property int type: DeviceType.Wifi
        property int state: ConnectionState.Connected
        property var networks: QtObject { property var values: [wifiNetwork] }
    }
    QtObject {
        id: wiredNetwork
        property string name: "Example Ethernet"
        readonly property bool connected: wired.state === ConnectionState.Connected
        property bool stateChanging: false
        property var nmSettings: []
    }
    QtObject {
        id: wired
        property int type: DeviceType.Wired
        property int state: ConnectionState.Disconnected
        property var networks: QtObject { property var values: [wiredNetwork] }
    }
    QtObject {
        id: service
        property int backend: NetworkBackendType.NetworkManager
        property var devices: QtObject { property var values: [wired, wifi] }
        property bool wifiEnabled: true
        property bool wifiHardwareEnabled: true
        property int connectivity: NetworkConnectivity.Full
        property bool canCheckConnectivity: true
        property bool connectivityCheckEnabled: true
    }
    Component.onCompleted: NetworkState.service = service

    function require(value, message): void {
        if (!value) throw new Error(message);
    }
    Timer {
        interval: 40; running: true; repeat: true
        onTriggered: {
            try {
                const status = NetworkState.status;
                switch (root.phase++) {
                case 0:
                    root.require(status.kind === "wifi" && status.state === "connected" && status.level === 2,
                        "Native device/network models did not select connected Wi-Fi");
                    root.require(status.tooltip === "Wi-Fi · Example Wi-Fi · 36% · Internet access", "Unexpected tooltip");
                    wifiNetwork.signalStrength = 0.9;
                    break;
                case 1:
                    root.require(status.level === 3 && status.tooltip.includes("90%"), "Signal update was not reactive");
                    profile.metadata.user.data["dotfiles.mobile-hotspot"] = "true";
                    profile.settingsChanged(profile.metadata);
                    break;
                case 2:
                    root.require(status.kind === "phone" && status.tooltip.includes("Mobile hotspot"), "Hotspot tag update was missed");
                    profile.metadata.user.data["dotfiles.mobile-hotspot"] = "false";
                    profile.settingsChanged(profile.metadata);
                    break;
                case 3:
                    root.require(status.kind === "wifi", "Removed hotspot tag remained active");
                    service.connectivity = NetworkConnectivity.Portal;
                    break;
                case 4:
                    root.require(status.marker === "warning" && status.tooltip.includes("Sign-in required"), "Captive portal was missed");
                    service.connectivityCheckEnabled = false;
                    break;
                case 5:
                    root.require(status.marker === "" && status.tooltip.endsWith("Connected"), "Disabled checks retained a warning");
                    wifi.state = ConnectionState.Disconnected;
                    break;
                case 6:
                    root.require(status.state === "disconnected" && status.kind === "wifi", "Disconnect retained a connected icon");
                    wifi.state = ConnectionState.Connecting;
                    break;
                case 7:
                    root.require(status.state === "connecting", "Connecting state was missed");
                    profile.metadata.user.data["dotfiles.mobile-hotspot"] = "true";
                    wifi.state = ConnectionState.Connected;
                    break;
                case 8:
                    root.require(status.kind === "phone", "Reconnect did not restore the hotspot tag");
                    wired.state = ConnectionState.Connected;
                    service.wifiEnabled = false;
                    break;
                case 9:
                    root.require(status.kind === "wired" && status.state === "connected" && !status.tooltip.includes("%"),
                        "Connected Ethernet was hidden by a disabled Wi-Fi radio");
                    wired.state = ConnectionState.Disconnected;
                    break;
                case 10:
                    root.require(status.state === "disabled", "Software radio block was missed");
                    service.wifiEnabled = true;
                    service.wifiHardwareEnabled = false;
                    break;
                case 11:
                    root.require(status.tooltip === "Wi-Fi blocked by hardware switch", "Hardware radio block was missed");
                    service.backend = NetworkBackendType.None;
                    break;
                case 12:
                    root.require(status.state === "unknown", "Missing backend retained a connected icon");
                    console.log("NETWORK_STATE_PASSED");
                    Qt.quit();
                }
            } catch (error) {
                console.error("NETWORK_STATE_FAILED", error.message);
                Qt.quit();
            }
        }
    }
}
