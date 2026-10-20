function timeLabel(timestamp) {
    const date = new Date(timestamp);
    return String(date.getHours()).padStart(2, "0") + ":" + String(date.getMinutes()).padStart(2, "0");
}

function calendar(events, now) {
    const date = new Date(now);
    const tomorrow = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime();
    const midnight = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
    const remaining = events.filter(row => row.end > now).slice()
        .sort((a, b) => a.start - b.start || a.end - b.end || String(a.id).localeCompare(String(b.id)));
    const today = remaining.filter(row => row.start < tomorrow && row.end > midnight);
    const absence = today.find(row => row.kind === "outOfOffice" && row.start <= now);
    const meeting = today.find(row => row.kind !== "outOfOffice" && !row.allDay && row.start <= now)
        || today.find(row => row.kind !== "outOfOffice" && !row.allDay);
    const nextAbsence = today.find(row => row.kind === "outOfOffice");
    const selected = absence || meeting || nextAbsence;
    const boundaries = [tomorrow];
    for (const row of today) {
        if (row.start > now) boundaries.push(row.start);
        if (row.end > now) boundaries.push(row.end);
    }
    return {icon: selected?.kind === "outOfOffice" ? "palm" : "meeting",
        label: selected && !selected.allDay ? timeLabel(selected.start) : "",
        active: !!selected && selected.start <= now && selected.end > now,
        tooltip: selected ? selected.title : "No more meetings today",
        nextBoundary: Math.min(...boundaries), rows: remaining};
}

if (typeof module !== "undefined") module.exports = {timeLabel, calendar};
