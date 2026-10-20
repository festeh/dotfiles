const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const logic = vm.createContext({});
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../NotificationLogic.js'), 'utf8'), logic);
const plain = value => JSON.parse(JSON.stringify(value));

test('sender deadlines take precedence; missing timeouts use defaults', () => {
    for (const urgency of [0, 1]) {
        for (const expireTimeout of [-1, undefined, null, NaN])
            assert.equal(logic.deadline({urgency, expireTimeout}, 1234), 31234);
        for (const expireTimeout of [1, 5000, 90000])
            assert.equal(logic.deadline({urgency, expireTimeout}, 1234), 1234 + expireTimeout);
        assert.equal(logic.deadline({urgency, expireTimeout: 0}, 1234), 0);
    }
    assert.equal(logic.deadline({urgency: 2}, 1234), 0);
    assert.equal(logic.deadline({urgency: 2, expireTimeout: -1}, 1234), 0);
    assert.equal(logic.deadline({urgency: 2, expireTimeout: 0}, 1234), 0);
    assert.equal(logic.deadline({urgency: 2, expireTimeout: 5000}, 1234), 6234);
});

test('progress values and bounded literal text', () => {
    assert.equal(logic.progress({value: 150}), 100);
    assert.equal(logic.progress({value: -50}), 0);
    assert.equal(logic.progress({value: '30'}), -1);
    assert.equal(logic.progress({value: NaN}), -1);
    assert.equal(logic.text('<b>A & B</b>\nbody\x00', 100), '<b>A & B</b>\nbody');
    assert.equal(logic.text('x'.repeat(10000), 8000).length, 8000);
});

test('timeout border fills from empty to full, with no countdown on critical cards', () => {
    const entry = {arrived: 1000, deadline: 31000};
    assert.equal(logic.elapsed(entry, 0), 0);
    assert.equal(logic.elapsed(entry, 1000), 0);
    assert.equal(logic.elapsed(entry, 16000), 0.5);
    assert.equal(logic.elapsed(entry, 31000), 1);
    assert.equal(logic.elapsed(entry, 50000), 1);
    assert.equal(logic.elapsed({arrived: 1000, deadline: 0}, 16000), 0);
    assert.equal(logic.elapsed({arrived: 16000, deadline: 46000}, 16000), 0);
    assert.equal(logic.elapsed({arrived: 1000, deadline: 6000}, 3500), 0.5);
    assert.equal(logic.elapsed({arrived: 1000, deadline: 6000}, 6000), 1);
    assert.equal(logic.elapsed({arrived: 1000, deadline: 61000}, 31000), 0.5);
});

test('monitor routing, stack limits, critical priority and stable hovered stack', () => {
    const entries = [1, 2, 3, 4].map(id => ({id, sequence: id, monitor: 'eDP-1', critical: id === 4}));
    const ids = (screen, pinned, heights, height) => plain(logic.choose(entries, screen, pinned, heights, height)).map(entry => entry.id);
    assert.deepEqual(ids('eDP-1', [], {}, 1000), [4, 1, 2]);
    assert.deepEqual(ids('DP-1', [], {}, 1000), []);
    assert.deepEqual(ids('eDP-1', [1, 2, 3], {}, 1000), [1, 2, 3]);
    assert.deepEqual(ids('eDP-1', [], {4: 600, 1: 400}, 900), [4]);
    assert.deepEqual(ids('eDP-1', [], {}, 200), [4]);
});
