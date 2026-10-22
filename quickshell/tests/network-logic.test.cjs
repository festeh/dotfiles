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
    state: 'connected',
    wifiEnabled: true, wifiHardwareEnabled: true,
    signal: 0.76, name: 'Example Wi-Fi',
    phone: false, connectivity: 4,
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
        assert.equal(result.tooltip, `Wi-Fi · Example Wi-Fi · ${Math.round(signal * 100)}% · Internet access`);
    }
    for (const signal of [-1, NaN, Infinity, undefined, 1.1]) {
        const result = network.describe(sample({signal}));
        assert.equal(result.marker, 'unknown');
        assert.match(result.tooltip, /Signal unavailable/);
        assert.doesNotMatch(result.tooltip, /\d+%/);
    }
});

test('only explicitly tagged Wi-Fi profiles identify a mobile hotspot', () => {
    for (const settings of [null, {}, {user: {}}, {user: {data: {}}},
        {connection: {metered: 1}}, {user: {data: {'dotfiles.mobile-hotspot': 'false'}}}])
        assert.equal(network.isHotspot(settings), false);
    assert.equal(network.isHotspot({user: {data: {'dotfiles.mobile-hotspot': 'true'}}}), true);
    const result = network.describe(sample({phone: true}));
    assert.equal(result.kind, 'phone');
    assert.match(result.tooltip, /^Wi-Fi · .* · Mobile hotspot · Internet access$/);
    assert.equal(network.describe(sample({type: 'wired', phone: true})).kind, 'wired');
});

test('stock radio blocks and connection transitions have distinct descriptions', () => {
    for (const [overrides, state, tooltip] of [
        [{wifiEnabled: false}, 'disabled', 'Wi-Fi off'],
        [{wifiHardwareEnabled: false}, 'disabled', 'Wi-Fi blocked by hardware switch'],
        [{state: 'disconnected'}, 'disconnected', 'Wi-Fi disconnected'],
        [{state: 'disconnecting'}, 'disconnecting', 'Wi-Fi · Disconnecting · Example Wi-Fi'],
        [{state: 'connecting'}, 'connecting', 'Wi-Fi · Connecting · Example Wi-Fi'],
    ]) {
        const result = network.describe(sample(overrides));
        assert.equal(result.state, state);
        assert.equal(result.tooltip, tooltip);
    }
    assert.equal(network.describe(sample({state: 'unknown'})).state, 'unknown');
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

test('wired/other connections remain usable with Wi-Fi disabled and omit wireless details', () => {
    for (const type of ['wired', 'other']) {
        const result = network.describe(sample({type, wifiEnabled: false, wifiHardwareEnabled: false}));
        assert.equal(result.state, 'connected');
        assert.equal(result.kind, type);
        assert.doesNotMatch(result.tooltip, /%|GHz/);
    }
});
