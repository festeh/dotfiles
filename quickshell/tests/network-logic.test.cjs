const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const network = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../NetworkLogic.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), network);

const sample = overrides => ({
    available: true, ready: true, type: 'wifi', hasWifi: true,
    deviceState: 100, networkState: 70, networkingEnabled: true,
    wifiEnabled: true, wifiHardwareEnabled: true,
    signal: 0.76, frequency: 5180, name: 'Example Wi-Fi',
    phone: false, metered: 2, connectivity: 4,
    canCheckConnectivity: true, connectivityCheckEnabled: true,
    ...overrides,
});

test('startup and service loss never pretend to be connected', () => {
    for (const snapshot of [null, {}, sample({available: false}), sample({ready: false})]) {
        const result = network.describe(snapshot);
        assert.equal(result.state, 'unknown');
        assert.equal(result.marker, 'unknown');
        assert.doesNotMatch(result.tooltip, /Internet access|0%/);
    }
});

test('connected signal changes update strength levels and the compact tooltip', () => {
    for (const [signal, level] of [[0, 1], [0.33, 1], [1 / 3, 1], [0.34, 2], [0.66, 2], [2 / 3, 2], [0.67, 3], [1, 3]]) {
        const result = network.describe(sample({signal, name: ' Example\n  Wi-Fi '}));
        assert.equal(result.level, level);
        assert.equal(result.tooltip, `Wi-Fi · Example Wi-Fi · ${Math.round(signal * 100)}% · 5 GHz · Internet access`);
    }
    for (const signal of [-1, NaN, Infinity, undefined, 1.1]) {
        const result = network.describe(sample({signal}));
        assert.equal(result.marker, 'unknown');
        assert.match(result.tooltip, /Signal unavailable/);
        assert.doesNotMatch(result.tooltip, /\d+%/);
    }
});

test('metered Wi-Fi can use the accepted phone heuristic without changing connection type', () => {
    const result = network.describe(sample({phone: true, metered: 1}));
    assert.equal(result.kind, 'phone');
    assert.match(result.tooltip, /^Wi-Fi · .* · Metered · Internet access$/);
    assert.equal(network.describe(sample({phone: true, metered: 0})).kind, 'phone');
    assert.equal(network.describe(sample({type: 'wired', phone: true})).kind, 'wired');
});

test('hardware/software blocks, transitions, failures, and disconnects have distinct states', () => {
    for (const [overrides, state, tooltip] of [
        [{networkingEnabled: false}, 'disabled', 'Networking disabled'],
        [{wifiEnabled: false}, 'disabled', 'Wi-Fi off'],
        [{wifiHardwareEnabled: false}, 'disabled', 'Wi-Fi blocked by hardware switch'],
        [{deviceState: 120}, 'failed', 'Wi-Fi connection failed'],
        [{deviceState: 30, networkState: 20}, 'disconnected', 'Wi-Fi disconnected'],
        [{deviceState: 20, networkState: 30}, 'disconnected', 'Wi-Fi unavailable'],
        [{deviceState: 110}, 'disconnecting', 'Wi-Fi · Disconnecting · Example Wi-Fi'],
    ]) {
        const result = network.describe(sample(overrides));
        assert.equal(result.state, state);
        assert.equal(result.tooltip, tooltip);
    }
    for (const deviceState of [40, 50, 60, 70, 80, 90])
        assert.equal(network.describe(sample({deviceState})).state, 'connecting');
});

test('internet warnings require enabled connectivity checking, not just a stale result', () => {
    for (const [connectivity, text] of [[1, 'No internet'], [2, 'Sign-in required'], [3, 'Limited connectivity']]) {
        const result = network.describe(sample({connectivity}));
        assert.equal(result.marker, 'warning');
        assert.equal(result.severity, 'attention');
        assert.ok(result.tooltip.endsWith(text));
        for (const disabled of [{connectivityCheckEnabled: false}, {canCheckConnectivity: false}]) {
            const unchecked = network.describe(sample({connectivity, ...disabled}));
            assert.equal(unchecked.marker, '');
            assert.ok(unchecked.tooltip.endsWith('Connected'));
        }
    }
    assert.ok(network.describe(sample({connectivity: 0})).tooltip.endsWith('Internet status unknown'));
});

test('wired/other primary links remain usable with Wi-Fi disabled and omit wireless details', () => {
    for (const type of ['wired', 'other']) {
        const result = network.describe(sample({type, wifiEnabled: false, wifiHardwareEnabled: false}));
        assert.equal(result.state, 'connected');
        assert.equal(result.kind, type);
        assert.doesNotMatch(result.tooltip, /%|GHz/);
    }
});
