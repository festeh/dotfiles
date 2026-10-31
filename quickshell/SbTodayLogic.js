// Pure helpers for the sb today widget. sb decides which tasks are today's,
// their order and which are overdue (app/src-tauri/src/widget.rs in the sb
// repository); this file only reads its messages and words them.

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

function validTask(task) {
    return !!task && typeof task.path === "string" && task.path.length > 0
        && typeof task.title === "string";
}

// One line from sb, or null when it is not a message this widget knows.
function parse(line) {
    let value;
    try {
        value = JSON.parse(line);
    } catch (_) {
        return null;
    }
    if (!value || typeof value !== "object") return null;
    if (value.type === "snapshot" && Array.isArray(value.tasks))
        return {type: "snapshot", today: String(value.today || ""), tasks: value.tasks.filter(validTask)};
    if (value.type === "error") return {type: "error", message: String(value.message || "sb could not do that")};
    return null;
}

function summary(tasks) {
    const overdue = tasks.filter(task => task.overdue).length;
    return {open: tasks.length, overdue: overdue, today: tasks.length - overdue};
}

// "2026-10-28" → "Oct 28"; the year is added when it is not today's.
function dateLabel(date, today) {
    const match = DATE.exec(date || "");
    if (!match) return "";
    const label = MONTHS[Number(match[2]) - 1] + " " + Number(match[3]);
    const year = DATE.exec(today || "");
    return year && year[1] !== match[1] ? label + " " + match[1] : label;
}

// "2026-10-31" → "Sat Oct 31".
function dayHeading(today) {
    const match = DATE.exec(today || "");
    if (!match) return "";
    const weekday = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3])).getDay();
    return WEEKDAYS[weekday] + " " + MONTHS[Number(match[2]) - 1] + " " + Number(match[3]);
}

// The popup's list: a heading before each section that has tasks. `index` is
// the task's place in sb's order, which keyboard selection follows.
function entries(tasks) {
    const rows = [];
    const section = (title, overdue) => {
        const members = tasks.map((task, index) => ({task: task, index: index}))
            .filter(entry => !!entry.task.overdue === overdue);
        if (!members.length) return;
        rows.push({kind: "heading", title: title, overdue: overdue, index: -1});
        for (const member of members) rows.push({kind: "task", task: member.task, index: member.index});
    };
    section("Overdue", true);
    section("Today", false);
    return rows;
}

// A task row's second line, in display order.
function details(task, today) {
    const parts = [];
    if (task.overdue && task.due) parts.push({kind: "due", text: "due " + dateLabel(task.due, today)});
    if (task.reminder) parts.push({kind: "reminder", text: task.reminder + (task.nag ? "!" : "")});
    if (task.doing) parts.push({kind: "doing", text: "● doing"});
    if (task.project) parts.push({kind: "project", text: task.project});
    return parts;
}

// Keyboard selection walks sb's order; entries() lists overdue first, which
// is also sb's order, so the two agree.
function step(selected, count, delta) {
    if (count <= 0) return 0;
    return Math.max(0, Math.min(count - 1, selected + delta));
}

if (typeof module !== "undefined")
    module.exports = {parse, summary, dateLabel, dayHeading, entries, details, step};
