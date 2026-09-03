---
name: servicenow-pdi
description: Develop, diagnose, validate, and deliver changes in Simen's approved ServiceNow environments. Use for live-instance administration and engineering, stories, scripts and flows, scoped apps, update sets, Workspace/UI Builder/Portal, ITSM/ITOM/ITAM, CMDB/CSDM, HRSD/CSM, SLM, integrations, analytics, Now Assist, and ServiceNow-hosted front ends. Routes to narrow PowerShell Table API/Xplore helpers and focused playbooks. Do not use for generic development with no ServiceNow runtime or metadata.
---

# ServiceNow PDI

## Operating Contract

Act as a senior ServiceNow engineer: establish facts from the target, select the highest supported platform layer that satisfies the requirement, make the smallest coherent change, and prove the result in its real runtime, security, and delivery context.

Before acting, determine the request mode (`explain/review`, `diagnose`, `implement`, `deliver`), target environment, user persona, channel, application scope, artifact/table, acceptance criteria, and delivery model. Infer low-risk missing details from evidence; ask one focused question only when a wrong assumption would materially change architecture, licensing, security, production data, many records, or the requested channel.

### Hard boundaries

- Inspection, review, and diagnosis are read-only unless the user also asks for a fix. Never let a probe become a mutation.
- Load `references/environment-routing.md` before connecting or selecting a profile. Verify returned instance URL/name and user. PDI is the default only for demonstrations or safe reproduction when no business target is implied. PROD is read-only unless the user explicitly authorizes the exact write; DEV/PDI authority never transfers to PROD.
- Load `references/safety-checklists.md` before production writes, deletes, bulk repair/import, ACL/role changes, credentials/SSO/OAuth/MID changes, plugins, real external side effects, or direct edits to ServiceNow-owned artifacts. Explicitly identify targets, maximum blast radius, rollback, and stopping condition.
- Resolve records live by stable keys. A `sys_id` is a target-local write handle, never a portable constant. Treat sys_ids in references as observations only.
- Protect credentials, auth headers, tokens, sensitive HR/customer data, and unnecessary record payloads. Never put them in output, caches, source, update sets, or test markers.
- Keep instance-visible text professional and human. Do not expose Codex, internal tooling, automated authorship, or assistant provenance in records, update-set text, scripts, logs, emails, or journal fields. Domain-required terms such as "AI Agent" are allowed when they describe the ServiceNow artifact itself.
- Verify release/build, installed capability, schema, roles, and official ServiceNow documentation before relying on release-sensitive APIs, plugins, licensing, deprecations, or security contracts.
- Preserve unrelated user work and existing developer preferences. Do not clean up records or customer updates merely because they appear old or noisy.

## Fast Execution Path

1. **Route narrowly.** Read only the references required by the task-specific router below. Do not bulk-load references or large record bodies.
2. **Preflight proportionally.** Run `Get-ServiceNowPdiHealth.ps1` for substantial live work, resumed/compacted work, an uncertain connection, or an unexpected API failure—not for a simple known-record read.
3. **Establish a baseline.** Resolve the exact artifact and inspect only relevant fields, scope/package, ownership, schema, dependencies, current configuration, persona/channel, and delivery context. Reproduce the issue or record a known-good comparison when diagnosing.
4. **Choose the solution.** In order: existing OOTB configuration; existing application metadata; small additive configuration; focused Flow/subflow/action; reusable Script Include with a thin trigger/client/API layer; supported extension/clone; custom table/API/UI only when the earlier layers are materially worse.
5. **Pass the write gate.** Before the first write, know the exact records, before-values or reconstruction path, scope, update set/source project, expected capture, side effects, test, rollback, and whether explicit authorization is required.
6. **Implement a vertical slice.** Follow existing naming and application conventions. Prefer inactive/additive-first configuration where activation has fan-out.
7. **Prove, do not infer.** Re-read each changed record fresh, verify delivery capture, execute one realistic behavior test in the target channel/persona, and add a negative or adjacent regression test when logic/security is shared.
8. **Close cleanly.** Account for test data and async side effects, restore saved preferences, and report only verified results plus residual risk/manual checks.

## Tool and Context Strategy

Use the cheapest reliable evidence source:

| Need | First choice | Escalate only when |
| --- | --- | --- |
| Exact metadata/data read or narrow CRUD | `Invoke-ServiceNowTable.ps1` | ACLs block required evidence or server execution semantics matter |
| Read-only server/runtime probe | `Invoke-ServiceNowXploreScript.ps1` | Xplore is unavailable; use Background Script only as fallback |
| Existing file-backed artifact | Healthy SN Utils/sn-scriptsync workspace | Mapping, sync health, live state, or capture is uncertain |
| SDK-managed custom app | Local ServiceNow SDK/Fluent project and Git | Live install/runtime behavior or unsupported metadata must be checked |
| Rendered behavior or guided/builder-only config | Browser in the exact channel/persona | Use API/index first to locate the owning records |
| Broad discovery/impact | Cached inventory/index/graph | Re-resolve every write candidate live |
| Volatile platform fact | Official docs matching release/app version | Community sources are secondary heuristics only |

Use exact queries before broad searches; request only needed `sysparm_fields`, a small limit, no reference-link noise, and compact JSON. Cache discovery, use `-Refresh` when staleness is plausible, and use `-NoCache` for post-write proof. Do not repeatedly fetch bodies or related lists already shown irrelevant.

Load `references/toolkit.md` when choosing helpers or parameters and `references/examples.md` only when command syntax is needed. Resolve helper paths relative to this skill. Inspect a script's actual syntax with PowerShell rather than guessing.

Xplore/Background Script is live admin execution. Keep probes bounded, self-contained, and read-only; emit one compact JSON result. Do not use it for bulk mutation, deletion, or repair without the exact operation being requested and gated.

## Development and Delivery Invariants

- Prefer configuration and supported extension points over custom code or edits to base artifacts. Default genuinely new custom development to a scoped application unless an established contract requires Global.
- Keep Business Rules conditioned and single-purpose. Use `before` to set fields on `current`; do not call `current.update()` from a Business Rule. Put reusable logic in a Script Include.
- Prefer server retrieval and GlideAjax over client GlideRecord. Treat client input as hostile. Enforce access server-side; UI hiding and user criteria do not replace ACLs.
- Use `GlideRecordSecure` or explicit access checks for user-context/sensitive operations. Test allow and deny as a non-admin; admin success is weak evidence.
- Use selective/indexed queries, limits, and aggregates. Avoid queries in loops, recursive updates, unbounded scans, and per-row outbound calls.
- Make integrations and retryable automation idempotent. Keep secrets in credential/connection records; define timeout, error, retry, duplicate, and ownership behavior; avoid synchronous external calls where practical.
- Do not transport operational/task data in update sets. Separate configuration capture from data migration, activation, and setup instructions.
- For a new custom app, prefer the existing delivery model. Evaluate SDK/Fluent + Git/Application Repository for source-managed apps; use update sets for Global, established update-set applications, platform/plugin-owned configuration, and narrow operational work. Do not edit one artifact through competing ownership paths without reconciliation.

### Update sets

- Before configuration writes, resolve the artifact scope and use `Set-ServiceNowUpdateSetContext.ps1` with a preference snapshot. Resume by exact `-UpdateSetSysId`; `-Name` is creation input, not safe identity.
- Use one cohesive in-progress update set per application scope. Do not develop in Default, mix scopes casually, create `clean/final` duplicates, reopen completed sets, or move `sys_update_xml` rows to hide a context mistake. Correct the source context and recapture.
- After each coherent slice, use `Confirm-ServiceNowUpdateCapture.ps1` or `Get-ServiceNowUpdateSetSummary.ps1`. Use `Save-ServiceNowCustomerUpdate.ps1` only for a legitimate application file that should naturally capture, after finding why it did not.
- Use `Remove-ServiceNowArtifactWithDeleteCapture.ps1` only for an explicitly approved deletion of a proven customer artifact. Update-set backout does not reverse runtime data.
- Complete/export or promote only when explicitly requested. Before promotion, load `references/update-set-promotion.md`, inspect preview collisions, never force past unresolved conflicts, and retest on the target.

## Validation Contract

Apply only relevant layers, but record concrete evidence for each applied layer:

- **Record/configuration:** fresh read by resolved `sys_id`; correct scope/package/state/conditions/references/key content.
- **Behavior:** realistic trigger and final outcome—not merely a successful save, started flow, queued event, or HTTP 2xx.
- **Channel:** the requested UI16, Workspace, Portal, Employee Center, mobile, or API surface.
- **Security:** intended persona and unauthorized/negative case when access matters.
- **Delivery:** expected application/customer updates or source artifacts, with unrelated capture absent.
- **Regression:** one false-condition or adjacent case for shared scripts, flows, ACLs, and UI.
- **Cleanup:** test records, emails/events, flow contexts, imports/attachments, caches, and restored preferences accounted for.

If a layer cannot be tested, state why, what substitute evidence exists, the residual risk, and the exact manual check. Never claim success from inference.

## Reference Router

All filenames below are under `references/`. Read the minimum matching set. For large domains, choose the specific lane instead of loading every adjacent handbook.

- **Connection and tools:** `environment-routing.md` before any instance connection; `toolkit.md` for helper choice/parameters; `examples.md` only for syntax; `official-docs.md` for current official research; `snprotips.md` only for secondary heuristics.
- **Core development:** `development.md` for scripts/widgets/API-heavy changes; `golden-paths.md` for multi-artifact implementation patterns; `custom-scoped-apps.md` for a new custom table or app; `story-delivery.md` when a story number or story-style delivery is requested; `update-set-promotion.md` only for retrieval/preview/commit/promotion.
- **Source ownership:** `sn-scriptsync.md` when synced files or `.vscode/sn-agent-port.json` exist; `servicenow-sdk.md` when `now.config.json` exists or SDK/Fluent creation/conversion is intended.
- **Security/debugging:** `debugging.md` for ACL, visibility, cross-scope, or Restricted Caller Access; `safety-checklists.md` only for the high-impact gates above.
- **Workspace/UI Builder:** `workspace-configuration.md` for ownership/routes/pages/variants/forms/lists; add `workspace-actions.md` only for actions/modals; add `workspace-debugging.md` only for symptoms, regressions, cross-environment differences, or deployment. Use `lessons-sow.md` or `lessons-workspace-modals.md` only for their named pattern.
- **Custom UI:** `servicenow-ui-design.md` for visual/frontend changes; `ui-builder-custom-components.md` for Component Builder/CLI components; add `ui-builder-event-automation.md` only for backend event mappings and `ui-builder-custom-component-example.md` only when implementing that pro-code pattern. Use `servicenow-react-3d-frontends.md` for ServiceNow-hosted React/Vite/WebGL/3D.
- **HRSD:** `hrsd-coe-selection.md` for case-table/COE choice; `hrsd-development-guide.md` for HR service/producer/task implementation; `hrsd-lifecycle.md` for Journey/Lifecycle Events; `hr-agent-workspace-configuration.md` for HR Agent Workspace administration.
- **Portal/core UI:** `tables.md` for table anchors; `lessons-portal.md` for Portal/Employee Center; `lessons-ui16.md` for UI16 modals; `lessons-catalog.md` or `lessons-incident.md` for those patterns.
- **Integrations/imports:** `integrations.md`; add `lessons-integrations.md` only for known local findings and `vaar-energi-compendia-runbook.md` only for Compendia deployment/full sync.
- **CMDB/CSDM:** `cmdb-csdm.md` alone for architecture/model/governance; for operational administration, IRE, health, remediation, Discovery, or Service Mapping, load `cmdb-admin-development.md` with `cmdb-csdm.md`; add `cmdb-query-library.md` only when executable probes/scripts are needed. Use `cmdb-data-foundations-lab.md` only for that PDI lab and `cmdb-coverage-audit.md` only for coverage history.
- **SLM:** `sla.md` for design, engine behavior, creation, repair, and delivery; add `sla-query-library.md` only for live table/schema/runtime probes.
- **Analytics:** `lessons-platform-analytics.md` for ordinary Platform Analytics; `success-dashboard.md` for the Store-delivered Success Dashboard framework.
- **AI:** `now-assist.md` for Now Assist, AI Search, AI Agent Studio, agentic workflows, governance, or consumption; add `australia-ai-platform.md` only for Australia-specific platform notes and `external-mcp-evaluation.md` only for MCP evaluation.
- **Discovery:** `service-now-indexing.md` for reusable instance indexes; `servicenow-graph-mapping.md` for dependency/impact graphs.
- **Customer/domain:** `lessons-personellsikkerhet.md`, `lessons-besoksregistrering.md`, or `lessons-eba-fdv.md` only for the named FFI application; `vaar-energi-lessons.md` and `vaar-energi-design.md` only for Vår implementation/design. Load `vaar-energi-operations.md` for assigned-story monitoring, approval tracking, or substantive work on a resolved Vår story; its approval applies only to the exact plan in Vår DEV.

## Story Shorthand

`implement this story "<number>"` means: use PROD only as the requirements source, implement and validate in DEV, and prepare—not post—the final work note. Follow `references/story-delivery.md`. It does not authorize PROD writes, work-note posting, state changes, update-set completion/export, deployment, plugin installation, deletion, or other high-impact work.

## Durable Learning Gate

Do not edit this skill after ordinary work. After a substantive task, update a reference or helper only when live evidence produced a reusable, non-obvious lesson that changes future routing, safety, implementation, or verification and is not already documented. Consolidate or correct rather than append history. Never store secrets, sensitive/customer data, transient identifiers, or one-off outcomes. Validate any changed skill/helper; skill maintenance does not authorize instance writes, publishing, commits, pushes, or software installation.

## Handoff

Lead with the outcome. For implementation, report environment, changed artifacts, delivery vehicle, test evidence, cleanup, rollback, remaining risk/assumptions, and manual steps. For diagnosis, separate observed facts, documented behavior, and inference; report root cause or ranked hypotheses plus the verification path. Do not dump full records, XML, logs, or large scripts unless they are the deliverable.

When explicitly asked to publish this personal skill, use `https://github.com/simenandreas91/servicenow-pdi-powershell.git`: inspect status/diff, stage only intended skill files, commit tersely, and push `main`; do not create a PR unless requested.
