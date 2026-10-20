.pragma library

function number(value) {
    return typeof value === "number" && isFinite(value);
}

function clean(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function name(node) {
    return node ? clean(node.nickname) || clean(node.description) || clean(node.name) || "Audio output" : "No audio output";
}

function peak(volumes) {
    if (!volumes || !volumes.length)
        return null;
    var result = 0;
    for (var i = 0; i < volumes.length; ++i) {
        if (!number(volumes[i]) || volumes[i] < 0)
            return null;
        result = Math.max(result, volumes[i]);
    }
    return result;
}

function ratios(volumes) {
    var maximum = peak(volumes);
    if (maximum === null || maximum === 0)
        return null;
    return Array.from(volumes, value => value / maximum);
}

function scaled(volumes, target, remembered, allowBoostedDecrease) {
    var maximum = peak(volumes);
    if (maximum === null || !number(target))
        return null;
    // External amplification remains readable. Wheel-down can reduce it
    // gradually; none of our controls can increase it beyond 100%.
    var ceiling = allowBoostedDecrease && target <= maximum ? Math.max(1, maximum) : 1;
    target = Math.max(0, Math.min(ceiling, target));
    var balance = ratios(volumes);
    if (!balance && remembered && remembered.length === volumes.length && peak(remembered) === 1)
        balance = remembered;
    if (!balance)
        balance = Array.from(volumes, () => 1);
    return balance.map(value => value * target);
}

function adjusted(current, delta) {
    if (!number(current) || !number(delta))
        return null;
    if (delta > 0 && current >= 1)
        return current;
    return Math.max(0, delta > 0 ? Math.min(1, current + delta) : current + delta);
}

function describe(node, ready) {
    var result = {known: false, muted: false, level: 0, iconLevel: 0,
        name: name(node), label: "—", tooltip: ready && !node ? "No audio output" : "Loading audio output"};
    if (!ready || !node || !node.ready || !node.audio)
        return result;
    var maximum = peak(node.audio.volumes);
    if (maximum === null) {
        result.tooltip = result.name + " · Volume unavailable";
        return result;
    }
    result.known = true;
    result.muted = node.audio.muted;
    result.level = maximum;
    result.label = Math.round(maximum * 100) + "%";
    result.iconLevel = maximum > 0 ? Math.min(3, Math.ceil(maximum * 3)) : 0;
    result.tooltip = result.name + " · " + (result.muted ? "Muted · " : "") + result.label;
    return result;
}
