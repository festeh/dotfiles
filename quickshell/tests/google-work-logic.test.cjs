const {test} = require('node:test');
const assert = require('node:assert/strict');
const {calendar} = require('../GoogleWorkLogic.js');
const stamp = value => new Date(value).getTime();
const event = (id, start, end, extra={}) => ({id, title:id, start:stamp(start), end:stamp(end), kind:'default', allDay:false, ...extra});

test('bar shows only today current or next meeting, then clears at end', () => {
    const rows = [event('later','2026-10-20T14:00:00','2026-10-20T15:00:00'),
        event('tomorrow','2026-10-21T09:00:00','2026-10-21T10:00:00')];
    assert.equal(calendar(rows, stamp('2026-10-20T12:00:00')).label, '14:00');
    assert.equal(calendar(rows, stamp('2026-10-20T14:00:00')).active, true);
    assert.equal(calendar(rows, stamp('2026-10-20T15:00:00')).label, '');
    assert.equal(calendar(rows, stamp('2026-10-21T00:00:00')).label, '09:00');
});
test('outOfOffice replaces meeting icon with palm, including all-day events', () => {
    const rows = [event('meeting','2026-10-20T14:00:00','2026-10-20T15:00:00'),
        event('away','2026-10-20T00:00:00','2026-10-21T00:00:00',{kind:'outOfOffice',allDay:true})];
    const state = calendar(rows, stamp('2026-10-20T12:00:00'));
    assert.equal(state.icon, 'palm');
    assert.equal(state.label, '');
    assert.equal(state.tooltip, 'away');
    assert.equal(calendar(rows, stamp('2026-10-21T00:00:00')).icon, 'meeting');
});
test('local boundary timer follows start and end without waiting for API sync', () => {
    const rows = [event('meeting','2026-10-20T14:00:15','2026-10-20T15:00:30')];
    assert.equal(calendar(rows, stamp('2026-10-20T12:00:00')).nextBoundary, rows[0].start);
    assert.equal(calendar(rows, rows[0].start).nextBoundary, rows[0].end);
    assert.equal(calendar(rows, rows[0].end).rows.length, 0);
});
