.pragma library

// NetworkManager's stable D-Bus state values. Keep presentation independent
// of the service so transitions can be checked without changing connections.
function validNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function clean(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function describe(snapshot) {
    var s = snapshot || {};
    var result = {
        kind: s.type === "wired" ? "wired" : s.type === "wifi" || (!s.type && s.hasWifi) ? "wifi" : "other",
        state: "unknown",
        level: 0,
        marker: "unknown",
        severity: "muted",
        tooltip: s.available ? "Reading network status" : "NetworkManager unavailable"
    };
    if (!s.available || !s.ready)
        return result;

    var connectionType = result.kind === "wifi" ? "Wi-Fi" : result.kind === "wired" ? "Ethernet" : "Network";
    if (s.networkingEnabled === false) {
        result.state = "disabled";
        result.marker = "off";
        result.tooltip = "Networking disabled";
        return result;
    }
    if (result.kind === "wifi" && (s.wifiEnabled === false || s.wifiHardwareEnabled === false)) {
        result.state = "disabled";
        result.marker = "off";
        result.tooltip = s.wifiHardwareEnabled === false ? "Wi-Fi blocked by hardware switch" : "Wi-Fi off";
        return result;
    }
    if (s.deviceState === 120) {
        result.state = "failed";
        result.marker = "warning";
        result.severity = "critical";
        result.tooltip = connectionType + " connection failed";
        return result;
    }
    if ((s.deviceState >= 40 && s.deviceState <= 90) || s.networkState === 40 || s.deviceState === 110) {
        result.state = s.deviceState === 110 ? "disconnecting" : "connecting";
        result.marker = "connecting";
        result.severity = "accent";
        result.tooltip = connectionType + " · " + (result.state === "disconnecting" ? "Disconnecting" : "Connecting");
        if (clean(s.name)) result.tooltip += " · " + clean(s.name);
        return result;
    }
    if (s.deviceState !== 100 && !(s.type === "other" && s.networkState >= 50)) {
        result.state = "disconnected";
        result.marker = "off";
        result.tooltip = connectionType + (s.deviceState === 10 ? " unmanaged"
            : s.deviceState === 20 ? " unavailable" : " disconnected");
        return result;
    }

    result.state = "connected";
    result.marker = "";
    result.severity = "normal";
    if (s.type === "wifi" && s.phone)
        result.kind = "phone";

    var parts = [connectionType];
    var name = clean(s.name);
    if (name) parts.push(name);
    if (s.type === "wifi") {
        if (validNumber(s.signal) && s.signal >= 0 && s.signal <= 1) {
            result.level = Math.max(1, Math.ceil(s.signal * 3));
            parts.push(Math.round(s.signal * 100) + "%");
        } else {
            result.marker = "unknown";
            parts.push("Signal unavailable");
        }
        if (validNumber(s.frequency) && s.frequency >= 2400) {
            var band = s.frequency < 2500 ? "2.4 GHz" : s.frequency >= 5925 ? "6 GHz"
                : s.frequency >= 4900 && s.frequency < 5925 ? "5 GHz" : "";
            if (band) parts.push(band);
        }
    }
    if (s.metered === 1 || s.metered === 3)
        parts.push("Metered");

    // A link does not prove internet access. Never turn disabled/unknown
    // connectivity checks into a false "no internet" warning.
    if (s.canCheckConnectivity && s.connectivityCheckEnabled) {
        if (s.connectivity === 2 || s.connectivity === 3 || s.connectivity === 1) {
            result.marker = "warning";
            result.severity = "attention";
            parts.push(s.connectivity === 2 ? "Sign-in required"
                : s.connectivity === 3 ? "Limited connectivity" : "No internet");
        } else {
            parts.push(s.connectivity === 4 ? "Internet access" : "Connected · Internet status unknown");
        }
    } else {
        parts.push("Connected");
    }
    result.tooltip = parts.join(" · ");
    return result;
}
