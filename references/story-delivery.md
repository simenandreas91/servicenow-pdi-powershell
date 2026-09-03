# ServiceNow Story Delivery

Load this reference only when the user supplies a story number, asks for story-style delivery, or uses `implement this story "<number>"`.

## Authority

Supplying a story number authorizes only the requested mode. An explicit implementation request authorizes ordinary implementation/validation in the identified DEV target. It does not authorize PROD writes, posting work notes/comments, changing story state, completing/exporting/promoting update sets, installing plugins, deleting records, bulk repair, or other high-impact actions.

For the exact shorthand `implement this story "<number>"`, use PROD as the read-only requirements source and DEV as the controlled implementation target. If those environments are unavailable or the story itself specifies another target, stop before writing and report the mismatch.

## Fast Path

For review or diagnosis, stop after the applicable read-only steps. Continue into update-set creation and implementation only when the user requested implementation.

1. Resolve the story in PROD by exact number. Read the full description and acceptance criteria plus only relevant attachments, linked requirements, dependencies, and related records. Do not infer requirements from the short description alone.
2. Convert the story into a compact acceptance matrix: criterion, controlling artifact/layer, test persona/channel, expected evidence, and unresolved dependency. This matrix is the execution checklist; do not repeatedly reload the story body.
3. In DEV, inspect the current OOTB capability and existing configuration. Resolve the owning scope/package and select the first viable supported solution.
4. Create a clearly named in-progress update set in the correct scope and make it current. On resume, reuse only the exact safe in-progress set by `sys_id`; never create a same-name duplicate. Use sibling sets for different application scopes.
5. Implement the smallest vertical slice. After each coherent slice, fresh-read the records and verify natural update capture before continuing.
6. Test every acceptance criterion in its real channel/persona. Include an unauthorized or false-condition case when security/logic is shared and one nearby regression case. Verify final async outcomes, not only trigger creation.
7. Audit the delivery: required changes present, expected application scope, no unrelated capture, no operational/task data masquerading as configuration, and manual data/dependency/activation steps recorded separately.
8. Restore developer preferences and account for test records, emails/events, flows, imports, and attachments.

Do not change the story state or write journal fields unless the user explicitly asks for that external mutation.

## Work Note

After implementation, end the handoff with `Work note (ready to paste)`. Draft a concise manual comment containing:

- implemented behavior and relevant artifacts;
- update set name(s) and application scope(s);
- acceptance tests and results;
- known limitation, dependency, or manual verification still required.

Use only verified facts and professional instance-ready language. Do not mention internal tooling or assistance. Prepare the comment for the user to publish; do not post it.

## Resumption Check

When resuming, re-read the story state/acceptance criteria, exact update set by `sys_id`, changed artifact versions, and current developer preferences. Reuse prior evidence only when the underlying record timestamp/content still matches. This prevents duplicate update sets and stale acceptance claims after context loss.
