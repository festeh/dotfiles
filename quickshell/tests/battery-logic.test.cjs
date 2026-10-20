const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const battery = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../BatteryLogic.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), battery);

const sample = overrides => ({
    ready: true,
    isPresent: true,
    isLaptopBattery: true,
    percentage: 0.65,
    state: battery.Discharging,
    timeToEmpty: 30600,
    timeToFull: 0,
    changeRate: 4.045,
    ...overrides,
});

test('startup never masquerades as a flat battery; absent and peripheral batteries are hidden', () => {
    for (const device of [null, sample({ready: false})]) {
        const status = battery.describe(device, true);
        assert.equal(status.label, '—');
        assert.equal(status.known, false);
        assert.equal(status.severity, 'normal');
    }
    assert.equal(battery.describe(sample({isPresent: false}), true).visible, false);
    assert.equal(battery.describe(sample({isLaptopBattery: false}), true).visible, false);
});

test('invalid percentages stay unknown, while a genuine zero is a critical empty battery', () => {
    for (const percentage of [NaN, Infinity, undefined, null, -0.01, 1.01, 65]) {
        const status = battery.describe(sample({percentage}), true);
        assert.equal(status.known, false);
        assert.equal(status.label, '—');
        assert.equal(status.level, 0);
        assert.equal(status.severity, 'normal');
    }
    const empty = battery.describe(sample({percentage: 0, state: battery.Empty}), true);
    assert.equal(empty.known, true);
    assert.equal(empty.label, '0%');
    assert.equal(empty.severity, 'critical');
});

test('low and critical colors match the 20% and 5% boundaries and require battery discharge', () => {
    for (const [percentage, severity] of [[1, 'normal'], [0.201, 'normal'], [0.20, 'low'], [0.051, 'low'], [0.05, 'critical']]) {
        assert.equal(battery.describe(sample({percentage}), true).severity, severity);
    }
    for (const state of [battery.Charging, battery.FullyCharged, battery.PendingCharge, battery.PendingDischarge, battery.Unknown]) {
        assert.equal(battery.describe(sample({percentage: 0.04, state}), true).severity, 'normal');
    }
    assert.equal(battery.describe(sample({percentage: 0.04}), false).severity, 'normal');
});

test('the tooltip uses the estimate for the current direction and describes rate without trusting its sign', () => {
    const discharge = battery.describe(sample(), true);
    assert.equal(discharge.label, '65%');
    assert.equal(discharge.level, 0.65);
    assert.equal(discharge.tooltip, 'Not charging · ~8h 30m remaining · 4.0 W');
    for (const changeRate of [-12.3, 12.3]) {
        const charge = battery.describe(sample({state: battery.Charging, timeToFull: 5400, changeRate}), false);
        assert.equal(charge.marker, 'charging');
        assert.equal(charge.tooltip, 'Charging · ~1h 30m until full · 12.3 W');
    }
});

test('paused and complete charging keep the actual percentage and omit stale discharge estimates', () => {
    const paused = battery.describe(sample({state: battery.PendingCharge, percentage: 0.80}), false);
    assert.equal(paused.marker, 'plugged');
    assert.equal(paused.tooltip, 'Plugged in · Charging paused');
    const complete = battery.describe(sample({state: battery.FullyCharged, percentage: 0.80}), false);
    assert.equal(complete.label, '80%');
    assert.equal(complete.tooltip, 'Charge complete');
});

test('unknown estimates and rates are omitted instead of claiming zero remaining', () => {
    for (const value of [0, -1, NaN, Infinity, undefined]) {
        const status = battery.describe(sample({timeToEmpty: value, changeRate: NaN}), true);
        assert.equal(status.tooltip, 'Not charging');
    }
    assert.equal(battery.describe(sample({timeToEmpty: 0, changeRate: 0}), true).tooltip, 'Not charging');
    assert.equal(battery.duration(3599), '1h');
    assert.equal(battery.duration(30), '1m');
});
