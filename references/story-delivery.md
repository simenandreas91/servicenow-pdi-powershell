# ServiceNow Story Delivery

Load this reference only when the user supplies a story number, asks for story-style delivery, or uses `implement this story "<number>"`.

## Authority

Supplying a story number authorizes only the requested mode. Review, diagnosis, and planning remain read-only. For environments other than Vår Energi, an implementation request defaults to DEV implementation/validation and preparation of a work note; external handoff and deployment require a request.

**Standing Vår Energi instruction:** once Simen requests or approves story implementation, carry it through DEV validation, completion of all related update sets, retrieval/preview/commit in TEST, TEST validation, and the source PROD story handoff below. This includes posting a short `work_notes` entry with one or two screenshots, setting Ready for testing, and assigning the story to its creator. No further routine confirmation is needed for those steps. Explicit narrower instructions, such as DEV-only work or a restricted approved plan, take precedence.

This authorization covers the exact story's delivery metadata and TEST configuration deployment. It does not authorize configuration deployment to PROD, public comments, plugin installation, security grants, bulk repair, or unrelated production writes. Use PROD for source requirements and DEV for implementation; verify the configured `vaar_prod`, `vaar_dev`, and `vaar_test` origins. If an environment is unavailable or the story specifies another target, resolve the mismatch before dependent writes.

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

For approved Vår Energi implementation, continue through the following handoff. For other environments or narrower requests, stop at the authorized boundary and prepare the work note for the user.

## Vår Energi TEST Delivery And Story Handoff

1. After DEV tests and capture audit pass, complete every related update set, including sibling scopes. Follow `update-set-promotion.md`: verify the TEST Update Source, retrieve the exact sets, preview and inspect problems and payload counts, and commit in dependency order without force. Reuse existing retrieved/committed sets on resume rather than duplicating them.
2. Confirm every TEST remote set is committed, inspect its resulting local commit log, compare installed configuration with the validated DEV version, and retest the relevant channels/personas and negative cases. Clean up temporary test data and restore preferences/impersonation. A successful commit alone is not acceptance evidence.
3. Attach one or two useful screenshots to the exact source PROD `rm_story`. Prefer TEST evidence; label DEV evidence explicitly when reused. Show the behavior or saved outcome, avoid unnecessary sensitive data, and verify attachment names, ownership, and file content. Check for existing evidence before retrying an uncertain upload.
4. Post one short implementation note in `work_notes`, using the format below. Include the TEST delivery/validation result and any remaining business acceptance step. Preserve requirements and acceptance criteria; use `comments` only when explicitly requested. Inspect the journal before retrying an uncertain write so the note is not duplicated.
5. Resolve the active story creator live from `sys_created_by` to an exact `sys_user.user_name`; use `opened_by` as corroborating evidence rather than assuming it is the creator. Resolve the live state choice labelled **Ready for testing** (or the instance's equivalent **Ready for Test**); never assume a numeric value is portable. Save before-values, re-read current state/assignment to detect concurrent changes, then set that state and `assigned_to` to the creator. If the creator is missing, ambiguous, or inactive, resolve that blocker rather than guessing a substitute.
6. Fresh-read the story to verify state, creator assignment, journal entry, and attachments. Report TEST deployment and technical validation separately from the creator's pending business acceptance testing.

Do not mark the story Ready for testing when a required set failed to commit, a preview problem remains unresolved, or required technical validation failed. Resolve the blocker within the authorized scope; if it cannot be resolved, report the exact remaining work without claiming delivery is complete.

## Work Note

Keep the note short: normally three to six sentences, plus a compact update-set list when several scopes make that clearer. Include:

- implemented behavior and relevant artifacts;
- update set name(s) and application scope(s);
- acceptance tests and results;
- known limitation, dependency, or manual verification still required.

Use only verified facts and professional instance-ready language. Do not mention internal tooling or assistance. For the Vår Energi workflow, post the note to the source story and attach the screenshots; include concise update-set names/scopes and TEST links when useful. For a draft-only handoff, end with `Work note (ready to paste)` and leave publication to the user.

## Resumption Check

When resuming, re-read the story state/acceptance criteria, exact update set by `sys_id`, changed artifact versions, and current developer preferences. Reuse prior evidence only when the underlying record timestamp/content still matches. This prevents duplicate update sets and stale acceptance claims after context loss.
