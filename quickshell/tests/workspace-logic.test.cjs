const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const logic = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../WorkspaceLogic.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), logic);

test('special workspaces are excluded without hiding normal named workspaces', () => {
    assert.equal(logic.normal({id: -1337, name: 'dev'}), true);
    assert.equal(logic.normal({id: -99, name: 'special:scratch'}), false);
    assert.equal(logic.normal({id: -99, name: 'special'}), false);
    assert.equal(logic.normal(null), null);
});

test('numeric sorting and readable labels survive workspace renaming', () => {
    const workspaces = [{id: 10, name: 'ten'}, {id: -1337, name: 'dev'}, {id: 2, name: 'two'}, {id: 1, name: '1'}];
    assert.deepEqual(workspaces.sort(logic.compare).map(logic.label), ['1', '2', '10', 'dev']);
    assert.equal(logic.clean('a\n b\t c'), 'a b c');
});

test('terminal title comparison ignores activity prefixes and preserves meaningful changes', () => {
    for (const frame of ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏', '◐', '◓', '✳', '✳️', '✻', '·', ''])
        assert.equal(logic.terminalTitleKey(` ${frame}  Editor, file `), 'Editor, file');
    assert.notEqual(logic.terminalTitleKey('⠋ First tab'), logic.terminalTitleKey('⠙ Second tab'));
    assert.equal(logic.terminalTitleKey('/usr/bin/nvim'), '/usr/bin/nvim');
    assert.equal(logic.terminalTitleKey('-option | /path'), '-option | /path');
    assert.notEqual(logic.terminalTitleKey('file ⠋'), logic.terminalTitleKey('file ⠙'));
    assert.equal(logic.terminalTitleKey(null), '');
});

test('workspace identity and activation use IDs even when names are identical', () => {
    for (const id of [1, 2]) {
        const workspace = {id, address: String(id), name: 'shared'};
        assert.equal(logic.workspaceKey(workspace), String(id));
        assert.equal(logic.workspaceKey({id, name: 'shared'}), String(id));
        assert.equal(logic.workspaceRequest(workspace, true), `hl.dsp.focus({ workspace = ${id} })`);
        assert.equal(logic.workspaceRequest(workspace, false), `workspace ${id}`);
    }
    assert.equal(logic.workspaceKey(null), '');
    assert.equal(logic.workspaceRequest({id: -1337, name: 'dev'}, true),
        'hl.dsp.focus({ workspace = "name:dev" })');
    assert.equal(logic.workspaceRequest({id: -1337, name: 'dev'}, false), 'workspace name:dev');
    assert.equal(logic.workspaceRequest({id: -1337, name: 'a"\\\nb'}, true),
        'hl.dsp.focus({ workspace = "name:a\\034\\092\\010b" })');
    assert.equal(logic.workspaceRequest({id: -99, name: 'special:scratch'}, true), '');
});

test('exact desktop IDs take priority over StartupWMClass, with ambiguous classes rejected', () => {
    const editor = {id: 'org.example.Editor', startupClass: 'editor', icon: 'editor', name: 'Editor'};
    const other = {id: 'org.example.Other', startupClass: 'shared', icon: '', name: 'Other'};
    const duplicate = {id: 'org.example.Duplicate', startupClass: 'shared', icon: '', name: 'Duplicate'};
    const catalog = logic.index([editor, other, duplicate]);
    assert.equal(logic.resolve(['ORG.EXAMPLE.EDITOR.desktop'], catalog), editor);
    assert.equal(logic.resolve(['EDITOR'], catalog), editor);
    assert.equal(logic.resolve(['shared'], catalog), null);
    assert.equal(logic.resolve(['unknown', 'org.example.Other'], catalog), other);
    assert.equal(logic.resolve(['missing'], catalog), null);
});

test('window dispatch targets an exact validated address in Lua or legacy mode', () => {
    assert.equal(logic.focusRequest('0xAB12', true), 'hl.dsp.focus({ window = "address:0xab12" })');
    assert.equal(logic.focusRequest('ab12', false), 'focuswindow address:0xab12');
    for (const invalid of ['', '0', '0x0', '0xfoo', 'a1" }); evil()', '../socket'])
        assert.equal(logic.focusRequest(invalid, true), '');
});

test('tray matching uses unique exact app identifiers and rejects ambiguous registrations', () => {
    const tray = {id: 'org.example.Editor', icon: 'image://tray/live'};
    const other = {id: 'OtherEditor', title: 'org.example.Editor', icon: 'other'};
    assert.equal(logic.trayItem(['ORG.EXAMPLE.EDITOR.desktop'], [other, tray]), tray);
    assert.equal(logic.trayItem(['missing', 'org.example.Editor'], [tray]), tray);
    assert.equal(logic.trayItem(['org.example.Editor'], [other]), null);
    assert.equal(logic.trayItem([], [tray]), null);
    assert.equal(logic.trayItem(['org.example.Editor'], [tray, {...tray}]), null);
    assert.equal(logic.trayItem(['org.example.Editor', 'OtherEditor'], [tray, other]), null);
    assert.equal(logic.trayItem(['org.example.Editor'], []), null);
});

test('terminal programs match unambiguous desktop executable names', () => {
    const editor = {id: 'org.example.Editor', startupClass: '', command: ['/usr/bin/env', 'MODE=cli', '/usr/bin/editor-cli', '%F']};
    const other = {id: 'org.example.Other', startupClass: '', command: ['/usr/bin/shared-cli']};
    const duplicate = {id: 'org.example.Duplicate', startupClass: '', command: ['shared-cli', '--other']};
    const catalog = logic.index([editor, other, duplicate]);
    assert.equal(logic.resolveProgram(['editor-cli'], catalog), editor);
    assert.equal(logic.resolveProgram(['org.example.Editor'], catalog), editor);
    assert.equal(logic.resolveProgram(['shared-cli'], catalog), null);
    assert.equal(logic.commandExecutable(['env', '--unset', 'TOKEN', 'editor-cli']), '');
    assert.equal(logic.resolveProgram(['missing-cli'], catalog), null);
});

test('theme lookup preserves app identities and defers absolute bundled artwork', () => {
    assert.deepEqual(Array.from(logic.themeIconNames(['dev.example.Editor', 'dev.example.Editor.desktop'],
        'dev.example.Editor', '/opt/editor/icon.png')),
        ['dev.example.Editor', 'dev.example.Editor.desktop']);
    assert.deepEqual(Array.from(logic.themeIconNames(['editor'], 'org.example.Editor', 'editor-icon')),
        ['editor-icon', 'org.example.Editor', 'editor']);
    assert.deepEqual(Array.from(logic.themeIconNames(['../icon', 'file:///tmp/icon.svg'], '', '')),
        []);
    assert.deepEqual(Array.from(logic.themeIconNames(['org.telegram.desktop'], 'org.telegram.desktop', '')),
        ['org.telegram.desktop', 'org.telegram']);
});
