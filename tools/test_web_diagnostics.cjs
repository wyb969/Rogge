const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const helper = fs.readFileSync(path.join(__dirname, '../script/web_diagnostics.js'), 'utf8');
let disk = null;
let writes = 0;
const idle = [];
const listeners = {};
const browser = {
  localStorage: {
    getItem() { return disk; },
    setItem(key, value) { disk = value; writes++; }
  },
  requestIdleCallback(callback) { idle.push(callback); },
  addEventListener(name, listener) { listeners[name] = listener; },
  navigator: {}
};
vm.runInNewContext(helper, browser);
const diagnostics = browser.RoggeDiagnostics;
function send(id, values, state = 'active') {
  return diagnostics.updateJSON(JSON.stringify({session_id: id, state, samples: values}), 60);
}
assert.equal(send('first', [0]), true);
assert.equal(writes, 1);
for (let i = 1; i <= 70; i++) send('first', [i]);
assert.equal(idle.length, 1);
assert.equal(writes, 1);
assert.deepEqual(JSON.parse(diagnostics.latestJSON()).samples, Array.from({length:60}, (_, i) => i + 11));
listeners.pagehide();
assert.equal(JSON.parse(disk).browser_events.at(-1).kind, 'pagehide');
assert.equal(JSON.parse(disk).samples.at(-1), 70);
idle.shift()();
send('first', [], 'ended');
assert.equal(JSON.parse(disk).state, 'ended');
const reopened = {...browser, RoggeDiagnostics: null};
vm.runInNewContext(helper, reopened);
assert.equal(JSON.parse(reopened.RoggeDiagnostics.previousJSON()).session_id, 'first');
send('second', [0]);
assert.deepEqual(JSON.parse(disk).samples, [0]);
browser.localStorage.setItem = () => {throw Error('quota');};
assert.equal(send('third', [1]), false);
assert.equal(JSON.parse(diagnostics.latestJSON()).samples[0], 1);
console.log('WEB DIAGNOSTICS OK: incremental ring, coalesced writes, pagehide, export, reload, session reset and storage fallback');
