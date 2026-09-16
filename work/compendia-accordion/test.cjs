const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const context = {Class: {create: () => function () {}}};
vm.createContext(context);
vm.runInContext(JSON.parse(fs.readFileSync(__dirname + '/vaar_dev-after.json', 'utf8').replace(/^\uFEFF/, '')).script, context);
const sync = Object.create(context.VECompendiaKnowledgeSync.prototype);
const marker = title => `<div data-collapse-title="${title}" class="collapsable"> </div>`;
const a = marker('Leave of absence');
const b = marker('Holiday');
const cases = [
  [a + '\n' + a, a + '\n'],
  [a + a + a, a],
  [a + '<p>Body</p>' + a, a + '<p>Body</p>' + a],
  [a + b, a + b],
  [a + '<div></div>' + a, a + '<div></div>' + a],
  ['<div class="collapsable" data-collapse-title="A">Text</div>', '<div class="collapsable" data-collapse-title="A">Text</div>'],
  [a + '<div class="collapsable" id="isPasted" data-collapse-title="Leave of absence"> </div>', a],
  ['<p>Unrelated</p>', '<p>Unrelated</p>']
];
for (const [input, expected] of cases) {
  assert.equal(sync.removeDuplicateCollapseMarkers(input), expected);
  assert.equal(sync.removeDuplicateCollapseMarkers(expected), expected);
}
const body = a+a+'<p>First body</p>'+b+b+'<p>Second body</p>';
const output = sync.formatCollapsibles(body);
assert.equal((output.match(/<summary/g)||[]).length, 2);
assert.ok(output.includes('First body') && output.includes('Second body'));
console.log('Passed 8 marker cases, idempotency, and complete formatting/body preservation.');
