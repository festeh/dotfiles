const {test} = require('node:test');
const assert = require('node:assert/strict');
const {parse, summary, dateLabel, dayHeading, entries, details, step} = require('../SbTodayLogic.js');
const task = (title, extra={}) => ({path:`tasks/${title}.md`, title, project:'', overdue:false, due:null,
    doing:false, reminder:null, nag:false, ...extra});

test('snapshots keep well-formed tasks; errors carry their message; anything else is ignored', () => {
    const line = JSON.stringify({type:'snapshot', today:'2026-10-31',
        tasks:[task('Call the bank'), {title:'no path'}, null]});
    assert.deepEqual(parse(line), {type:'snapshot', today:'2026-10-31', tasks:[task('Call the bank')]});
    assert.deepEqual(parse('{"type":"error","message":"not a task: x"}'), {type:'error', message:'not a task: x'});
    assert.equal(parse('{"type":"hello"}'), null);
    assert.equal(parse('not json'), null);
    assert.equal(parse('{"type":"snapshot","tasks":"nope"}'), null);
});

test('summary splits overdue from today', () => {
    assert.deepEqual(summary([task('a', {overdue:true}), task('b'), task('c')]), {open:3, overdue:1, today:2});
    assert.deepEqual(summary([]), {open:0, overdue:0, today:0});
});

test('dates read like the app: month and day, the year only when it differs', () => {
    assert.equal(dateLabel('2026-10-28', '2026-10-31'), 'Oct 28');
    assert.equal(dateLabel('2025-12-30', '2026-01-02'), 'Dec 30 2025');
    assert.equal(dateLabel(null, '2026-10-31'), '');
    assert.equal(dayHeading('2026-10-31'), 'Sat Oct 31');
    assert.equal(dayHeading(''), '');
});

test('entries put a heading before each non-empty section and keep sb order indexes', () => {
    const tasks = [task('Old', {overdue:true}), task('Due'), task('Started', {doing:true})];
    assert.deepEqual(entries(tasks).map(entry => [entry.kind, entry.kind === 'task' ? entry.task.title : entry.title, entry.index]),
        [['heading','Overdue',-1], ['task','Old',0], ['heading','Today',-1], ['task','Due',1], ['task','Started',2]]);
    assert.deepEqual(entries([task('Due')]).map(entry => entry.kind), ['heading', 'task']);
    assert.deepEqual(entries([]), []);
});

test('details show the overdue date, reminder, progress and project in that order', () => {
    const late = task('Invoice', {overdue:true, due:'2026-10-29', reminder:'09:00', nag:true, doing:true, project:'work'});
    assert.deepEqual(details(late, '2026-10-31').map(part => part.text), ['due Oct 29', '09:00!', '● doing', 'work']);
    assert.deepEqual(details(task('Due', {due:'2026-10-31'}), '2026-10-31'), []);
});

test('keyboard selection stays inside the list', () => {
    assert.equal(step(0, 3, -1), 0);
    assert.equal(step(2, 3, 1), 2);
    assert.equal(step(1, 3, 1), 2);
    assert.equal(step(4, 0, 1), 0);
});
