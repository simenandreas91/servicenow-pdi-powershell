# Update Set Promotion

Use this runbook to promote a completed update set from DEV to TEST or from TEST to PROD. It applies to direct update-set retrieval from an Update Source and to the CI/CD Update Set API. Load `references/development.md` and `references/safety-checklists.md` as well.

## Guardrails

- Confirm the exact source and target instances, current user, release/build, application scope, source update-set `sys_id`, target Update Source `sys_id`, and authorization before writing.
- Vår Energi DEV, TEST, and PROD currently share the credentials stored in the approved private `.env`. Select the environment with `vaar_dev`, `vaar_test`, or `vaar_prod` and an exact instance URL/key; never infer TEST or PROD from `SN_OTHER_INSTANCE`, and never print credentials.
- PROD is read-only without exact production-write authorization, an approved change window/process, a validation owner, and a rollback decision.
- Complete and transport configuration metadata only. Operational/task data does not move in an update set. A Fix Script record may be transported without being executed; running it in the target is a separate bulk-data action that needs its own approval, preview/count, limit, logging, and validation.
- Do not force a preview or commit. Resolve every preview problem first. Do not delete and re-retrieve an existing remote set merely to retry without approval.
- Never reconstruct part of the package directly in the target before committing the retrieved set. Local target edits can create `local update newer than remote` conflicts and an ambiguous source of truth.

## 1. Audit And Complete The Source

1. Resolve the local `sys_update_set` by exact `sys_id` and confirm name, application, scope, state, parent/base relationship, description, and source story.
2. Inventory `sys_update_xml` by type, action, application, target name, and update set. Stop for mixed scope, unrelated capture, DELETE actions, suspicious payloads, missing dependencies, secrets, credentials, or operational data.
3. Confirm the update set contains every intended record. User Criteria and many-to-many audience records such as `kb_uc_can_read_mtom` are separate customer updates; verify both the criteria and their links explicitly.
4. Run the applicable configuration, behavior, security, regression, and packaging tests in the source.
5. Set the source update set to `complete` only after the audit passes, then re-read its state and update count.

## 2. Verify The Target Update Source

Resolve `sys_update_set_source` in the target by exact `sys_id`. Confirm it is active, its type is appropriate, and its URL is the intended source instance. For Vår Energi TEST, the known DEV Update Source observed on 2026-08-19 was `a72fd8938f09cf50e63a9a764da575cd`; treat that value as dated evidence and re-read it before each promotion.

Search `sys_remote_update_set` for the source update-set `remote_sys_id` and Update Source before retrieving. ServiceNow skips update sets that already exist in the target. If one exists, inspect its state and history instead of creating a duplicate.

## 3. Retrieve And Preview

### CI/CD Update Set API

Prefer the supported API when `com.glide.continuousdelivery` is active and the caller has `sn_cicd.sys_ci_automation` or the required equivalent access.

1. Retrieve the exact completed source set:

   `POST /api/sn_cicd/update_set/retrieve?update_set_id=<source-local-sys-id>&update_source_id=<target-update-source-sys-id>`

2. Treat response and progress shapes as release-dependent. Persist only sanitized identifiers/status text in the task output. Poll `GET /api/sn_cicd/progress/<progress-id>` only when the response contains a scalar progress identifier. Do not stringify an entire result object into the progress URL.
3. Resolve the target `sys_remote_update_set` by `remote_sys_id=<source-local-sys-id>` plus `update_source=<target-update-source-sys-id>`. Retrieval may also preview the set; inspect the actual remote state rather than assuming it.
4. If the remote state is not `previewed`, run:

   `POST /api/sn_cicd/update_set/preview/<remote-update-set-sys-id>`

5. Poll only a returned scalar progress identifier, then re-read the remote set.

### UI fallback

If the CI/CD API/plugin/role is unavailable, open the verified Update Source and run **Retrieve Completed Update Sets**. Open the exact row under **Retrieved Update Sets**, run **Preview Update Set**, and wait for the worker to finish. Use the UI only for the unsupported part of the workflow; keep record inspection and evidence collection narrow.

## 4. Inspect Preview Evidence

Do not infer a clean preview from the button completing.

- Confirm `sys_remote_update_set.state=previewed`.
- Query `sys_update_preview_problem` with `remote_update_set=<remote-sys-id>`. Zero rows is the clean case.
- Inventory `sys_update_xml` with `remote_update_set=<remote-sys-id>` and compare the count, types, actions, application, and target names with the audited source.
- Inspect `sys_update_preview_xml` when the instance creates comparison rows. Confirm proposed actions and dispositions; absence of rows can be normal when there are no comparisons/problems.
- For each problem, classify missing dependency, collision/local-newer update, scope mismatch, skipped record, unsafe edit, or data/configuration issue. Resolve it through supported preview actions, correct the source package and retrieve a new version when appropriate, or ask the user. Re-preview until there are no unresolved problems.
- For a batch, preview and commit the base update set in dependency order. Do not commit children independently unless the relationship and order are proven.

## 5. Commit Without Force

Commit only after the clean preview is evidenced and the intended count matches.

- API: `POST /api/sn_cicd/update_set/commit/<remote-update-set-sys-id>` with `force_commit=false`.
- UI fallback: use **Commit Update Set** on the exact previewed remote set.
- If the API returns a scalar progress identifier, poll it. If it returns a synchronous/release-specific status object with no scalar identifier, do not manufacture one; verify the authoritative records instead.
- Confirm `sys_remote_update_set.state=committed` and capture its update time.
- Resolve the resulting local `sys_update_set` and query `sys_update_set_log`. Require no Error/Warning entries or unsafe-edit warnings; inspect the full commit log, not just the last message.
- Compare the resulting local customer-update count/types with the source package.

## 6. Validate The Target

1. Re-read every installed configuration record by stable natural key and then resolved `sys_id`. Confirm scope, active/state, scripts/conditions, references, and many-to-many links.
2. Verify target-only properties, credentials, connection aliases, schedules, groups, users, and roles separately. Never transport secrets in the update set.
3. Run the real target behavior and negative/security persona tests. Missing target test data is a limitation, not a pass; record the exact missing prerequisite and required UAT step.
4. Verify operational data was not silently changed. If a transported Fix Script or migration must run, obtain separate approval, run a dry count with a hard ceiling, execute it once, and reconcile changed/unchanged/error counts.
5. Inspect logs and one adjacent regression path. Account for any test records, attachments, outbound calls, emails, events, imports, or queued work.
6. Record the source set, target remote/local set identifiers, preview outcome, commit outcome, validation evidence, limitations, and rollback plan in the story/change record without mentioning tools or automation.

## Rollback

Back Out reverses transported configuration metadata; it is not a rollback for operational data modified by scripts, imports, flows, or integrations. Before promotion, decide whether configuration backout is supported and how any target data mutation will be reconciled or restored. Do not back out a committed set without explicit approval and impact analysis.

## Official References

- [Retrieve an update set](https://www.servicenow.com/docs/r/application-development/system-update-sets/t_RetrieveAnUpdateSet.html)
- [Preview a remote update set](https://www.servicenow.com/docs/r/application-development/system-update-sets/t_PreviewARemoteUpdateSet.html)
- [Commit an update set](https://www.servicenow.com/docs/r/application-development/system-update-sets/t_CommitAnUpdateSet.html)
- [CI/CD Update Set API](https://www.servicenow.com/docs/r/api-reference/rest-apis/cicd-update-set-api.html)
