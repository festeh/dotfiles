const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const layout = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../LayoutLogic.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), layout);

const keyboard = overrides => ({name: 'usb-keyboard', main: true, layout: 'us,ru',
    active_keymap: 'English (US)', active_layout_index: 0, ...overrides});

test('selects the main real keyboard without choosing a virtual main device or hardcoding its name', () => {
    const primary = keyboard({name: 'bluetooth-keyboard'});
    assert.equal(layout.primary({keyboards: [keyboard({name: 'wtype-virtual-keyboard'}),
        keyboard({name: 'power-button', main: false}), primary]}), primary);
    assert.equal(layout.primary({keyboards: [keyboard({main: false})]}).name, 'usb-keyboard');
    assert.equal(layout.primary({keyboards: [keyboard({main: false}), keyboard({name: 'other', main: false})]}), null);
    assert.equal(layout.primary({keyboards: []}), null);
    assert.equal(layout.describe(null).ready, false);
});

test('recognizes Russian variants and event updates cannot retain a stale Russian index', () => {
    for (const name of ['Russian', 'Russian (typewriter)', 'Russian, phonetic']) {
        assert.equal(layout.describe(layout.withLayout(keyboard(), name)).russian, true);
    }
    const russian = keyboard({active_keymap: 'Localized Russian name', active_layout_index: 1});
    assert.equal(layout.describe(russian).russian, true);
    const english = layout.withLayout(russian, 'English (US)');
    assert.equal(layout.describe(english).russian, false);
    assert.equal(layout.describe(english).name, 'English (US)');
    assert.equal(russian.active_layout_index, 1);
});

test('switches the identified keyboard with separate arguments and rejects ambiguous command names', () => {
    assert.deepEqual(Array.from(layout.cycleCommand(keyboard())), ['hyprctl', 'switchxkblayout', 'usb-keyboard', 'next']);
    for (const name of ['bad name', 'all; dispatch exit', 'name\nnext']) {
        assert.equal(layout.cycleCommand(keyboard({name})).length, 0);
    }
    const single = layout.describe(keyboard({layout: 'ru', active_keymap: 'Russian'}));
    assert.equal(single.russian, true);
    assert.equal(single.canCycle, false);
    assert.equal(single.tooltip, 'Russian');
});
