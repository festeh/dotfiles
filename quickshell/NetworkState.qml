pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell.Networking
import "NetworkLogic.js" as NetworkLogic

QtObject {
    id: root
    property Item pickerOwner: null
    // Shared native service; its Wi-Fi scanner stays disabled while observing.
    property var service: Networking
    readonly property var device: {
        const devices = service.devices.values;
        return devices.find(device => device.state === ConnectionState.Connected)
            || devices.find(device => device.state === ConnectionState.Connecting)
            || devices.find(device => device.state === ConnectionState.Disconnecting)
            || devices.find(device => device.type === DeviceType.Wifi)
            || devices[0] || null;
    }
    readonly property var network: {
        const networks = device ? device.networks.values : [];
        return networks.find(network => network.connected)
            || networks.find(network => network.stateChanging) || null;
    }
    property int profileRevision: 0
    readonly property bool phone: {
        // read() returns cached settings; subscribe explicitly to their updates.
        root.profileRevision;
        return !!network && network.connected
            && network.nmSettings.some(profile => NetworkLogic.isHotspot(profile.read()));
    }
    readonly property var status: NetworkLogic.describe({
        available: service.backend !== NetworkBackendType.None,
        ready: !!device,
        type: !device ? "" : device.type === DeviceType.Wifi ? "wifi"
            : device.type === DeviceType.Wired ? "wired" : "other",
        hasWifi: service.devices.values.some(device => device.type === DeviceType.Wifi),
        state: device ? ConnectionState.toString(device.state).toLowerCase() : "unknown",
        name: network ? network.name : "",
        signal: network && device.type === DeviceType.Wifi ? network.signalStrength : -1,
        phone: root.phone,
        wifiEnabled: service.wifiEnabled,
        wifiHardwareEnabled: service.wifiHardwareEnabled,
        connectivity: service.connectivity,
        canCheckConnectivity: service.canCheckConnectivity,
        connectivityCheckEnabled: service.connectivityCheckEnabled
    })

    readonly property Instantiator profileWatch: Instantiator {
        model: root.network ? root.network.nmSettings : []
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLoaded(): void { root.profileRevision++; }
            function onSettingsChanged(): void { root.profileRevision++; }
        }
    }
}
