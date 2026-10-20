.pragma library

// UPower's stable Device.State values. This module also accepts plain snapshots
// so transitions can be checked without changing the laptop's battery or power.
var Unknown = 0;
var Charging = 1;
var Discharging = 2;
var Empty = 3;
var FullyCharged = 4;
var PendingCharge = 5;
var PendingDischarge = 6;

function validNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function duration(seconds) {
    if (!validNumber(seconds) || seconds <= 0)
        return "";
    var minutes = Math.max(1, Math.round(seconds / 60));
    if (minutes < 60)
        return minutes + "m";
    var hours = Math.floor(minutes / 60);
    var remainder = minutes % 60;
    return hours + "h" + (remainder ? " " + remainder + "m" : "");
}

function describe(device, onBattery) {
    var result = {
        visible: true,
        known: false,
        level: 0,
        label: "—",
        severity: "normal",
        marker: "unknown",
        tooltip: "Battery data unavailable"
    };

    if (!device || !device.ready)
        return result;
    if (!device.isLaptopBattery || !device.isPresent) {
        result.visible = false;
        return result;
    }

    result.known = validNumber(device.percentage)
        && device.percentage >= 0 && device.percentage <= 1;
    if (result.known) {
        result.level = device.percentage;
        result.label = Math.round(device.percentage * 100) + "%";
    }

    var state = device.state;
    var discharging = state === Discharging || state === Empty;
    var charging = state === Charging;
    result.marker = charging ? "charging" : (!onBattery ? "plugged" : "");
    if (!result.known)
        result.marker = "unknown";

    if (result.known && onBattery && discharging) {
        if (device.percentage <= 0.05)
            result.severity = "critical";
        else if (device.percentage <= 0.20)
            result.severity = "low";
    }

    var parts = [];
    switch (state) {
    case Charging: parts.push("Charging"); break;
    case Discharging:
        parts.push(onBattery ? "Not charging" : "Plugged in · Not charging");
        break;
    case Empty: parts.push("Battery empty"); break;
    case FullyCharged: parts.push("Charge complete"); break;
    case PendingCharge:
        parts.push(onBattery ? "Charging paused" : "Plugged in · Charging paused");
        break;
    case PendingDischarge:
        parts.push(onBattery ? "On battery · Discharge paused" : "Plugged in · Discharge paused");
        break;
    default:
        parts.push(onBattery ? "On battery · Status unavailable" : "Plugged in · Status unavailable");
    }

    var estimate = duration(charging ? device.timeToFull : (discharging ? device.timeToEmpty : 0));
    if (estimate)
        parts.push("~" + estimate + (charging ? " until full" : " remaining"));

    // Direction comes from State: backend rate-sign conventions differ.
    if ((charging || discharging) && validNumber(device.changeRate) && Math.abs(device.changeRate) >= 0.05)
        parts.push(Math.abs(device.changeRate).toFixed(1) + " W");
    if (!result.known)
        parts.push("Charge level unavailable");

    result.tooltip = parts.join(" · ");
    return result;
}
