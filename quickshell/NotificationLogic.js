// Pure presentation/lifetime helpers. Notification content always stays plain text.
function critical(notification) {
    return Number(notification.urgency) === 2;
}

function timeoutMs(notification) {
    // The native service exposes the D-Bus timeout in milliseconds: -1 means
    // server default, zero means no expiration, positive values are explicit.
    const value = notification.expireTimeout;
    if (typeof value === "number" && Number.isFinite(value) && value >= 0) return value;
    return critical(notification) ? 0 : 30000;
}

function deadline(notification, now) {
    const duration = timeoutMs(notification);
    return duration > 0 ? now + duration : 0;
}

function elapsed(entry, now) {
    const duration = entry.deadline - entry.arrived;
    return entry.deadline > 0 && duration > 0
        ? Math.max(0, Math.min(1, (now - entry.arrived) / duration)) : 0;
}

function text(value, limit) {
    return String(value || "").replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, "").slice(0, limit);
}

function progress(hints) {
    const value = hints && hints.value;
    return typeof value === "number" && Number.isFinite(value)
        ? Math.max(0, Math.min(100, value)) : -1;
}

function age(time, now) {
    const minutes = Math.max(0, Math.floor((now - time) / 60000));
    return minutes < 1 ? "now" : minutes < 60 ? minutes + "m"
        : minutes < 1440 ? Math.floor(minutes / 60) + "h" : Math.floor(minutes / 1440) + "d";
}

function choose(entries, screen, pinned, heights, availableHeight) {
    const candidates = entries.filter(entry => entry.monitor === screen);
    // Preserve the stack under the pointer. Otherwise, critical alerts get priority.
    candidates.sort((a, b) => {
        const ai = pinned.indexOf(a.id), bi = pinned.indexOf(b.id);
        if (ai >= 0 || bi >= 0) return ai < 0 ? 1 : bi < 0 ? -1 : ai - bi;
        return Number(b.critical) - Number(a.critical) || a.sequence - b.sequence;
    });
    const chosen = [];
    let height = 0;
    for (const entry of candidates) {
        const nextHeight = Math.min(heights[entry.id] || 320, availableHeight);
        if (chosen.length && height + nextHeight + 8 > availableHeight) break;
        chosen.push(entry);
        height += nextHeight + 8;
        if (chosen.length === 3) break;
    }
    return chosen;
}
