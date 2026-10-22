.pragma library

// Presentation of the stock Quickshell networking service.
function validNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function clean(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function isHotspot(settings) {
    var data = settings && settings.user && settings.user.data;
    return !!data && data["dotfiles.mobile-hotspot"] === "true";
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
    if (result.kind === "wifi" && (s.wifiEnabled === false || s.wifiHardwareEnabled === false)) {
        result.state = "disabled";
        result.marker = "off";
        result.tooltip = s.wifiHardwareEnabled === false ? "Wi-Fi blocked by hardware switch" : "Wi-Fi off";
        return result;
    }
    if (s.state === "connecting" || s.state === "disconnecting") {
        result.state = s.state;
        result.marker = "connecting";
        result.severity = "accent";
        result.tooltip = connectionType + " · " + (result.state === "disconnecting" ? "Disconnecting" : "Connecting");
        if (clean(s.name)) result.tooltip += " · " + clean(s.name);
        return result;
    }
    if (s.state === "unknown")
        return result;
    if (s.state !== "connected") {
        result.state = "disconnected";
        result.marker = "off";
        result.tooltip = connectionType + " disconnected";
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
    }
    if (result.kind === "phone")
        parts.push("Mobile hotspot");

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
