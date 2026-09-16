# Update Set Promotion

Use this runbook to promote a completed update set from DEV to TEST or from TEST to PROD. It applies to direct update-set retrieval from an Update Source and to the CI/CD Update Set API. Load `safety-checklists.md` for PROD or another high-impact gate. Consult the Update Sets section of `development.md` only when source capture, scope, or packaging is unresolved.

## Guardrails

- Confirm the exact source and target instances, current user, release/build, application scope, source update-set `sys_id`, target Update Source `sys_id`, and authorization before writing.
- Vår Energi DEV, TEST, and PROD currently share the credentials stored in the approved private `.env`. Select the environment with `vaar_dev`, `vaar_test`, or `vaar_prod` and an exact instance URL/key; never infer TEST or PROD from `SN_OTHER_INSTANCE`, and never print credentials.
- PROD is read-only without exact production-write authorization, an approved change window/process, a validation owner, and a rollback decision.
- Complete and transport configuration metadata only. Operational/task data does not move in an update set. A Fix Script record may be transported without being executed; running it in the target is a separate bulk-data action that needs its own approval, preview/count, limit, logging, and validation.
- Do not force a preview or commit. Resolve every preview problem first. Do not delete and re-retrieve an existing remote set merely to retry without approval.
- Never reconstruct part of the package directly in the target before committing the retrieved set. Local target edits can create `local update newer than remote` conflicts and an ambiguous source of truth.

## 1. Audit And Complete The Source

1. Resolve the local `sys_update_set` by exact `sys_id` and confirm name, application, scope, state, parent/base relationship, description, and source story.
2. Inventory `sys_update_xml` by type, action, application, target name, and update set. Investigate mixed scope, unrelated capture, DELETE actions, suspicious payloads, missing dependencies, secrets, credentials, or operational data before completion. For previously authorized draft-cleanup deletions, verify the exact deleted targets and their target-instance existence; an absent target is not a new deletion requiring the same approval again.
3. Confirm the update set contains every intended record. User Criteria and many-to-many audience records such as `kb_uc_can_read_mtom` are separate customer updates; verify both the criteria and their links explicitly.
4. Run the applicable configuration, behavior, security, regression, and packaging tests in the source.
5. Set the source update set to `complete` only after the audit passes, then re-read its state and update count.

For several sets, build one cached manifest of set ownership, capture names/actions, dependencies and payloads. Group duplicate update names across sets and compare their record timestamps and substantive fields before choosing commit order. A later-created set need not contain the latest version of every record. Keep the intended winning version explicit; do not repackage or move captures merely to remove overlaps. Reuse existing source test evidence when the records have not changed, and reserve fresh behavior tests for the target. Keep portable archive copies separate from the original delivery sets to avoid deploying the same component twice.

## 2. Verify The Target Update Source

Resolve `sys_update_set_source` in the target by its source URL, then verify the exact `sys_id`, active flag and type. Normalize a trailing slash when comparing HTTPS origins and require one matching active source. Do not rely on a historical source ID: a clone or refresh can replace it. If the named connection profile lacks an instance URL but the authorized target is known, pass that exact origin with `-Instance` and verify health; do not change credentials or substitute an environment.

Search `sys_remote_update_set` for the source update-set `remote_sys_id` and Update Source before retrieving. ServiceNow skips update sets that already exist in the target. If one exists, inspect its state and history instead of creating a duplicate.

## 3. Retrieve And Preview

### CI/CD Update Set API

Prefer the supported API when `com.glide.continuousdelivery` is active and the caller has `sn_cicd.sys_ci_automation` or the required equivalent access.

Check the plugin and effective role directly. An empty `sys_ws_definition` search does not establish that this API is unavailable. Use the shared connection resolver for REST calls, with a verified target origin and no automatic retries of mutations.

1. Retrieve the exact completed source set:

   `POST /api/sn_cicd/update_set/retrieve?update_set_id=<source-local-sys-id>&update_source_id=<target-update-source-sys-id>`

2. Treat response and progress shapes as release-dependent. On Australia, the progress ID was returned at `result.links.progress.id`; the completed response supplied `result.remote_update_set_id` or `result.local_update_set_id`. Persist these identifiers immediately for resumable work. Poll `GET /api/sn_cicd/progress/<progress-id>` only with a scalar identifier. Do not stringify an entire result object into the progress URL. Use bounded polling with backoff and compact state changes; perform independent dependency checks while workers run, but keep dependent commits sequential.
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
- For each problem, classify missing dependency, collision/local-newer update, scope mismatch, skipped record, unsafe edit, or data/configuration issue. Compare actual local and remote payloads, then resolve through supported preview actions, correct the source package and retrieve a new version when appropriate, or ask the user. Retain the newer intended version when an earlier committed set already supplied it; do not accept an older remote copy merely to clear an error.
- After an Accept/Skip action, re-read the problem disposition and update disposition. Do not automatically re-preview unchanged content: on Australia this recreated the problem with a new ID and cleared the resolution. Re-preview when dependencies or content changed, then review the resulting problems anew. Commit requires zero unresolved problems, not necessarily zero historical problem rows. Reconcile each intentionally skipped capture with the final installed version and expected committed count.
- Prefer the native UI for preview actions unless a supported programmatic contract is established. Calling `GlidePreviewProblemAction(null, record).skipUpdate()` changed the disposition but then threw a null-action exception. Do not adopt that as a reusable resolution method, and inspect state before retrying any action that reports an exception.
- For a batch, preview and commit the base update set in dependency order. Do not commit children independently unless the relationship and order are proven.

## 5. Commit Without Force

Commit only after the clean preview is evidenced and the intended count matches.

- API: `POST /api/sn_cicd/update_set/commit/<remote-update-set-sys-id>` with `force_commit=false`.
- UI fallback: use **Commit Update Set** on the exact previewed remote set.
- If the API returns a scalar progress identifier, poll it. If it returns a synchronous/release-specific status object with no scalar identifier, do not manufacture one; verify the authoritative records instead.
- Confirm `sys_remote_update_set.state=committed` and capture its update time.
- Resolve the resulting local `sys_update_set` and query `sys_update_set_log` by that local ID, not the retrieved remote ID. On Australia the useful fields are `update_set,status,log` (not `level,message,type`). Inspect the full commit log, requiring no unresolved Error/Warning entries or unsafe-edit warnings. Missing fields in a restricted-field response do not prove a clean log; inspect one full record or the dictionary when the schema is uncertain.
- Compare the resulting local customer-update count/types with the source package.
- After a successful PROD commit and validation, set the exact resulting local PROD `sys_update_set.state` to `ignore` so a later clone does not make the completed set eligible for transfer or reapplication. Keep the retrieved `sys_remote_update_set` in `committed`; do not use Ignore as a substitute for preview, commit, validation, or rollback. For a batch, follow the platform rule to Ignore only the parent and leave its children Complete so the hierarchy is preserved.

## 6. Validate The Target

1. Re-read every installed configuration record by stable natural key and then resolved `sys_id`. Confirm scope, active/state, scripts/conditions, references, and many-to-many links.
2. Verify target-only properties, credentials, connection aliases, schedules, groups, users, and roles separately. Never transport secrets in the update set.
3. Run the real target behavior and negative/security persona tests. Missing target test data is a limitation, not a pass; record the exact missing prerequisite and required UAT step.
4. Verify operational data was not silently changed. If a transported Fix Script or migration must run, obtain separate approval, run a dry count with a hard ceiling, execute it once, and reconcile changed/unchanged/error counts.
5. Inspect logs and one adjacent regression path. Account for any test records, attachments, outbound calls, emails, events, imports, or queued work.
6. Prepare a concise story/change note with source set, target remote/local set identifiers, preview and commit outcomes, validation evidence, limitations, and rollback. Write it to the record only when the user explicitly requested that external update; never mention internal tools or automation.

For efficient verification, compare the final intended version of each record once, with captured choices/layouts and related links accounted for separately. Normalize XML `true/false` against GlideRecord `1/0`. Reference IDs can legitimately remap: verify their natural keys (for example table name or username), rather than reporting every ID difference as corruption. Inspect platform-added dictionary attributes separately; never normalize away a real script, condition or security difference. In PowerShell XML parsing, use `LocalName` for element names: the XML adapter's `.Name` can resolve a child `<name>` value instead of the table tag.

Check setup dependencies that update sets may not carry, particularly group-role assignments. Match the approved source assignment to the target's resolved group and role, then verify effective inherited access; do not infer assignment from the role definition's successful import. Preserve the user's testing arrangement: a rendered form and configuration checks are a deployment smoke test, not a successful submission or end-to-end UAT.

## Rollback

Back Out reverses transported configuration metadata; it is not a rollback for operational data modified by scripts, imports, flows, or integrations. Before promotion, decide whether configuration backout is supported and how any target data mutation will be reconciled or restored. Do not back out a committed set without explicit approval and impact analysis.

## Official References

- [Retrieve an update set](https://www.servicenow.com/docs/r/application-development/system-update-sets/t_RetrieveAnUpdateSet.html)
- [Preview a remote update set](https://www.servicenow.com/docs/r/application-development/system-update-sets/t_PreviewARemoteUpdateSet.html)
- [Commit an update set](https://www.servicenow.com/docs/r/application-development/system-update-sets/t_CommitAnUpdateSet.html)
- [CI/CD Update Set API](https://www.servicenow.com/docs/r/api-reference/rest-apis/cicd-update-set-api.html)
