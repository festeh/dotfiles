const {test} = require('node:test');
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const {prepare, rank} = require('../LauncherLogic.js');

test('exact and prefix matches beat a frequently used loose subsequence', () => {
    const rows = prepare([{id:'a', title:'Firefox', usage:0}, {id:'b', title:'File Browser', usage:1000}]);
    assert.equal(rank(rows, 'fire')[0].id, 'a');
    assert.equal(rank(rows, 'ffx')[0].id, 'a');
});
test('multiple words search metadata, accents and Cyrillic without markup interpretation', () => {
    const rows = prepare([{id:'a', title:'Café Reader', detail:'Author / Fiction · epub'},
        {id:'b', title:'Пример книги', detail:'Автор'}]);
    assert.deepEqual(rank(rows, 'cafe fiction').map(row=>row.id), ['a']);
    assert.deepEqual(rank(rows, 'ПРМКН').map(row=>row.id), ['b']);
    assert.deepEqual(rank(rows, '<script>'), []);
    assert.equal(rank(rows, '').length, 2);
});
test('usage orders close ties while empty query preserves provider order', () => {
    const rows = prepare([{id:'a', title:'Editor One', usage:0}, {id:'b', title:'Editor Two', usage:8}]);
    assert.equal(rank(rows, 'editor')[0].id, 'b');
    assert.equal(rank(rows, '')[0].id, 'a');
});
test('search benchmark over 5000 cached records', () => {
    const rows = prepare(Array.from({length:5000}, (_,i)=>({id:String(i), title:`Example book ${i}`, detail:'Author · Fiction · epub'})));
    const start=performance.now();
    for (let n=0;n<20;n++) rank(rows, 'exbk 42');
    const elapsed=(performance.now()-start)/20;
    console.log(`5000 rows: ${elapsed.toFixed(2)}ms per query`);
    assert.ok(elapsed<100, `Unexpectedly slow search: ${elapsed}ms`);
});
