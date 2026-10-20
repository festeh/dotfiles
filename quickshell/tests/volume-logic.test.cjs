const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const volume = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../VolumeLogic.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), volume);

const node = overrides => ({ready: true, description: ' Example\n speakers ',
    audio: {volumes: [0.25, 0.75], muted: false}, ...overrides});

test('loading, missing outputs and unknown channels do not pretend to be zero volume', () => {
    for (const [output, ready] of [[null, false], [null, true], [node({ready: false}), true],
        [node({audio: null}), true], [node({audio: {volumes: []}}), true],
        [node({audio: {volumes: [NaN]}}), true]]) {
        const status = volume.describe(output, ready);
        assert.equal(status.known, false);
        assert.equal(status.label, '—');
    }
    assert.equal(volume.describe(null, true).tooltip, 'No audio output');
});

test('short device labels keep outputs distinguishable when hardware descriptions share a long prefix', () => {
    const prefix = 'Core Ultra 200V Series Processors HD Audio ';
    assert.equal(volume.name({nickname: ' HDMI\n 1 ', description: prefix + 'HDMI / DisplayPort 1 Output (Stereo)'}), 'HDMI 1');
    assert.equal(volume.name({nickname: 'Speaker', description: prefix + 'Speaker'}), 'Speaker');
    assert.equal(volume.name({nickname: ' ', description: ' USB\n headphones '}), 'USB headphones');
    assert.equal(volume.name({name: 'fallback-sink'}), 'fallback-sink');
});

test('the loudest channel sets the displayed level and mute stays distinct from zero', () => {
    const status = volume.describe(node(), true);
    assert.equal(status.label, '75%');
    assert.equal(status.name, 'Example speakers');
    assert.equal(status.tooltip, 'Example speakers · 75%');
    for (const muted of [false, true]) {
        const zero = volume.describe(node({audio: {volumes: [0, 0], muted}}), true);
        assert.equal(zero.label, '0%');
        assert.equal(zero.known, true);
        assert.equal(zero.iconLevel, 0);
        assert.equal(zero.muted, muted);
    }
    const boosted = volume.describe(node({audio: {volumes: [0.8, 1.25], muted: true}}), true);
    assert.equal(boosted.label, '125%');
    assert.equal(boosted.tooltip, 'Example speakers · Muted · 125%');
});

test('icons have three strength levels plus a genuine zero', () => {
    for (const [level, iconLevel] of [[0, 0], [0.2, 1], [1 / 3, 1], [0.5, 2], [2 / 3, 2], [0.8, 3], [1.5, 3]])
        assert.equal(volume.describe(node({audio: {volumes: [level], muted: false}}), true).iconLevel, iconLevel);
});

test('volume changes preserve channel proportions and remember balance through silence', () => {
    const original = Object.freeze([0.2, 0.8]);
    const memory = volume.ratios(original);
    assert.deepEqual(Array.from(volume.scaled(original, 0.5)), [0.125, 0.5]);
    assert.deepEqual(Array.from(volume.scaled(original, 0)), [0, 0]);
    assert.deepEqual(Array.from(volume.scaled([0, 0], 0.4, memory)), [0.1, 0.4]);
    assert.deepEqual(Array.from(volume.scaled([0, 0], 0.4, [1])), [0.4, 0.4]);
});

test('absolute controls cap every channel at 100%, while external boost can decrease gradually', () => {
    assert.deepEqual(Array.from(volume.scaled([0.25, 0.5], 4)), [0.5, 1]);
    assert.deepEqual(Array.from(volume.scaled([0.25, 0.5], -1)), [0, 0]);
    assert.equal(volume.adjusted(0.99, 0.02), 1);
    assert.equal(volume.adjusted(1.2, 0.02), 1.2);
    assert.equal(volume.adjusted(1.2, -0.02), 1.18);
    assert.equal(volume.adjusted(0, -0.02), 0);
    assert.deepEqual(Array.from(volume.scaled([0.6, 1.2], 1.18, null, true)), [0.59, 1.18]);
    assert.deepEqual(Array.from(volume.scaled([0.6, 1.2], 1.5, null, true)), [0.5, 1]);
});

test('invalid values cause no write', () => {
    for (const values of [null, [], [Infinity], [-0.1], ['0.5']])
        assert.equal(volume.scaled(values, 0.5), null);
    assert.equal(volume.scaled([0.5], NaN), null);
    assert.equal(volume.adjusted(NaN, 0.02), null);
});
