.pragma library

// Local noon avoids missing/repeated midnight hours around timezone transitions.
function dayAt(year, month, day) {
    return new Date(year, month, day, 12, 0, 0, 0);
}

function normalized(date) {
    return dayAt(date.getFullYear(), date.getMonth(), date.getDate());
}

function monthStart(date) {
    return dayAt(date.getFullYear(), date.getMonth(), 1);
}

function addDays(date, count) {
    return dayAt(date.getFullYear(), date.getMonth(), date.getDate() + count);
}

function addMonths(date, count) {
    var first = dayAt(date.getFullYear(), date.getMonth() + count, 1);
    var last = dayAt(first.getFullYear(), first.getMonth() + 1, 0).getDate();
    return dayAt(first.getFullYear(), first.getMonth(), Math.min(date.getDate(), last));
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
        && a.getMonth() === b.getMonth()
        && a.getDate() === b.getDate();
}

function monthCells(date) {
    var first = monthStart(date);
    var offset = (first.getDay() + 6) % 7;
    var cells = [];
    for (var i = 0; i < 42; ++i)
        cells.push(dayAt(first.getFullYear(), first.getMonth(), 1 - offset + i));
    return cells;
}
