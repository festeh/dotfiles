const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const calendar = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../CalendarMath.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), calendar);
const key = date => `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;

test('the month grid starts on Monday and includes adjacent months', () => {
    const cells = calendar.monthCells(calendar.dayAt(2026, 9, 19));
    assert.equal(cells.length, 42);
    assert.equal(cells[0].getDay(), 1);
    assert.equal(key(cells[0]), '2026-9-28');
    assert.equal(key(cells[41]), '2026-11-8');
    assert.equal(cells.filter(date => date.getMonth() === 9).length, 31);
});

test('month navigation clamps the selected date in leap and non-leap years', () => {
    assert.equal(key(calendar.addMonths(calendar.dayAt(2024, 0, 31), 1)), '2024-2-29');
    assert.equal(key(calendar.addMonths(calendar.dayAt(2025, 0, 31), 1)), '2025-2-28');
    assert.equal(key(calendar.addMonths(calendar.dayAt(2026, 2, 31), -1)), '2026-2-28');
    assert.equal(key(calendar.addMonths(calendar.dayAt(2026, 11, 31), 1)), '2027-1-31');
    assert.equal(key(calendar.addMonths(calendar.dayAt(2026, 0, 1), -1)), '2025-12-1');
});

test('day navigation crosses year boundaries and leap day', () => {
    assert.equal(key(calendar.addDays(calendar.dayAt(2026, 0, 1), -1)), '2025-12-31');
    assert.equal(key(calendar.addDays(calendar.dayAt(2024, 1, 28), 1)), '2024-2-29');
    assert.equal(key(calendar.addDays(calendar.dayAt(2024, 1, 29), 1)), '2024-3-1');
});

test('DST months contain consecutive civil dates without skipping or duplicating a day', () => {
    for (const month of [2, 9, 10]) {
        const cells = calendar.monthCells(calendar.dayAt(2026, month, 1));
        for (let i = 0; i < cells.length; ++i) {
            assert.equal(cells[i].getHours(), 12);
            if (i > 0) {
                const a = cells[i - 1];
                const b = cells[i];
                const days = (Date.UTC(b.getFullYear(), b.getMonth(), b.getDate())
                    - Date.UTC(a.getFullYear(), a.getMonth(), a.getDate())) / 86400000;
                assert.equal(days, 1);
            }
        }
    }
});

test('today comparison ignores the time of day', () => {
    const morning = new Date(2026, 9, 19, 0, 1);
    const evening = new Date(2026, 9, 19, 23, 59);
    assert.equal(calendar.sameDay(morning, evening), true);
    assert.equal(calendar.sameDay(morning, new Date(2026, 9, 20)), false);
});
