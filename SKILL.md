---
name: servicenow-pdi
description: Develop, diagnose, validate, and deliver ServiceNow changes in Simen's approved environments. Includes PowerShell API helpers and playbooks for scripts/flows, scoped apps, update sets, Workspace/Portal, integrations, and platform configuration. Excludes generic development with no ServiceNow runtime or metadata.
---

# ServiceNow PDI

## Scope and authority

- Resolve the target environment, artifact, application scope, channel/persona, acceptance criteria, and delivery model from the request and available evidence. Review/diagnosis is read-only unless a fix is requested.
- Read `references/environment-routing.md` before connecting; verify returned instance and user. PDI defaults only to demonstrations/safe reproduction. PROD requires explicit authorization for the exact write; DEV/PDI authority never transfers.
- When Simen requests `PDI_2`, use `-Profile pdi_2` with this skill folder's `.env` explicitly for all live helpers. It is a separate instance from `pdi`; never substitute the original PDI or assume its installed capabilities are shared.
- Read `references/safety-checklists.md` before production writes, deletes, bulk repair/import, ACL/role changes, credentials/SSO/OAuth/MID changes, plugins, real external side effects, or edits to ServiceNow-owned artifacts. Establish targets, blast radius, rollback, and stopping condition.
- Resolve write targets live by stable keys. Reference sys_ids are historical observations, not portable constants. Preserve unrelated work and developer preferences.
- Exclude secrets and unnecessary sensitive data from output, caches, source, and delivery artifacts. Keep instance-visible text professional and free of Codex/tooling/authorship provenance; legitimate product terms such as "AI Agent" are allowed.
- Verify release/build, installed capability, schema, roles, and matching official documentation before relying on release-sensitive behavior.

## Execution

1. Read only matching references below. For long files, locate relevant headings with `rg -n '^#{1,3} '` and read that section plus applicable prerequisites.
2. Run `Get-ServiceNowPdiHealth.ps1` for substantial live work, resumed/uncertain context, or unexpected API failure; skip routine preflight for a known-record read.
3. Inspect the relevant fields, ownership, dependencies, and before-values. Reproduce the issue when diagnosing. Prefer existing OOTB configuration, then additive configuration/Flow, reusable Script Include, supported extension/clone, and finally custom table/API/UI.
4. Before writing, establish scope, update set/source project, expected capture, side effects, test, and rollback. Implement one coherent slice using existing conventions; prefer inactive/additive-first changes where activation has fan-out.
5. Re-read changed records fresh; verify capture and the final behavior in the requested channel/persona. Test allow/deny as a non-admin when access matters and an adjacent/false-condition case for shared logic. A save, HTTP 2xx, queued event, or started flow is not outcome evidence.
6. Account for test data and async side effects; restore preferences. Report verified changes, delivery vehicle, test evidence, rollback, and any untested layer with its manual check. Distinguish facts from hypotheses in diagnosis.

## Tools

- **Exact reads/CRUD:** `Invoke-ServiceNowTable.ps1`; narrow fields/query/limit, exclude reference-link noise.
- **Server semantics or API-blocked metadata:** `Invoke-ServiceNowXploreScript.ps1`; Background Script only as fallback. Both execute as admin: bound queries, use self-contained probes, emit compact JSON, and never turn a read probe into a mutation.
- **Existing source ownership:** healthy SN Utils/sn-scriptsync files, or SDK/Fluent + Git for SDK-managed artifacts. Reconcile before switching ownership paths.
- **Rendered/builder-only behavior:** browser in the actual channel/persona; locate owning records with API/index first.
- **Broad repeated discovery:** inventory/index/graph; verify candidates live before editing.

Use PowerShell 7 (`pwsh -NoProfile`). Resolve scripts relative to this skill; inspect `Get-Command <helper> -Syntax`. Read `references/toolkit.md` for helper contracts, `references/examples.md` for syntax. Prefer splatting, Table `-AsObject`, and `-BodyPath`/`-ScriptPath`. Python is useful for offline exports/indexes; keep connection routing in shared helpers.

Cache discovery; use `-Refresh` for stale discovery and `-NoCache` for sensitive reads, permission changes, and post-write proof. Fetch at least two matches to detect ambiguous targets. Limited results do not establish completeness: page with server next-page metadata and a budget, even through ACL-filtered short pages. Invalid query fields can be ignored; verify schema before deriving write candidates. Inspect state and side effects after an uncertain write/script result before replaying it.

## Development and delivery

- Default new custom apps to scoped development unless the contract requires Global. Prefer supported configuration/extensions over base-artifact edits.
- Keep Business Rules conditioned and thin; reusable logic belongs in a Script Include. Set `current` fields in `before`; do not call `current.update()` from a Business Rule.
- Enforce access server-side with `GlideRecordSecure` or explicit access checks. UI hiding/user criteria are not ACLs. Prefer GlideAjax over client GlideRecord; use selective queries, aggregates, and bounded work.
- Make integrations/retryable automation idempotent; keep secrets in credential/connection records and define timeout, error, retry, and duplicate behavior.
- Follow existing delivery ownership: SDK/Fluent + Git/Application Repository for source-managed apps; update sets for Global and established update-set work. Operational data, activation, and setup are separate from configuration capture.

For update-set work:

- Resolve scope, then use `Set-ServiceNowUpdateSetContext.ps1` with a new recovery snapshot. Resume by `-UpdateSetSysId`; `-Name` creates a set.
- Use one cohesive in-progress set per scope. No Default, casual scope mixing, `clean/final` duplicates, reopening completed sets, or moving `sys_update_xml` to disguise a context mistake. Correct context and recapture.
- Check each slice with `Confirm-ServiceNowUpdateCapture.ps1` or `Get-ServiceNowUpdateSetSummary.ps1`. Force capture with `Save-ServiceNowCustomerUpdate.ps1` only after diagnosing missed natural capture for a legitimate application file.
- `Remove-ServiceNowArtifactWithDeleteCapture.ps1` requires an explicitly approved deletion of a proven customer artifact. Backout does not reverse runtime data.
- Complete/export/promote only when requested. Read `references/update-set-promotion.md` before promotion; resolve preview conflicts and retest on the target.

## Reference router

Paths below are under `references/`. Choose by task; do not bulk-load adjacent handbooks.

| Task | References |
| --- | --- |
| Connection, commands, research | `environment-routing.md`; `toolkit.md`; `examples.md`; `official-docs.md`; `snprotips.md` only for secondary heuristics |
| Scripts/widgets/APIs; multi-artifact patterns; new app | `development.md`; `golden-paths.md`; `custom-scoped-apps.md` respectively |
| Story delivery; promotion | `story-delivery.md`; `update-set-promotion.md` |
| Synced files or `.vscode/sn-agent-port.json`; `now.config.json` or SDK work | `sn-scriptsync.md`; `servicenow-sdk.md` respectively |
| ACL/visibility/cross-scope/Restricted Caller Access; high-impact gates | `debugging.md`; `safety-checklists.md` |
| Workspace pages/routes/forms/lists; actions/modals; failures/deployment | `workspace-configuration.md`; `workspace-actions.md`; `workspace-debugging.md` respectively. Add `lessons-sow.md` or `lessons-workspace-modals.md` for those patterns |
| Visual/frontend; custom components | `servicenow-ui-design.md`; `ui-builder-custom-components.md`. For backend event mappings add `ui-builder-event-automation.md`; for its pro-code example add `ui-builder-custom-component-example.md` |
| ServiceNow-hosted React/Vite/WebGL/3D | `servicenow-react-3d-frontends.md` |
| HRSD COE/table selection; service/producer/task; Journey/Lifecycle; Workspace | `hrsd-coe-selection.md`; `hrsd-development-guide.md`; `hrsd-lifecycle.md`; `hr-agent-workspace-configuration.md` respectively |
| Table anchors; Portal/Employee Center; UI16; catalog; incident | `tables.md`; `lessons-portal.md`; `lessons-ui16.md`; `lessons-catalog.md`; `lessons-incident.md` respectively |
| Integrations/imports | `integrations.md`; `lessons-integrations.md` for local findings; `vaar-energi-compendia-runbook.md` only for Compendia |
| CMDB/CSDM architecture | `cmdb-csdm.md` |
| CMDB administration/IRE/health/remediation/Discovery/Service Mapping | Relevant sections of `cmdb-admin-development.md` and `cmdb-csdm.md`; `cmdb-query-library.md` for executable probes. `cmdb-data-foundations-lab.md` only for that PDI lab |
| SLM design/engine/repair/delivery | `sla.md`; `sla-query-library.md` for executable probes |
| Platform Analytics; Store Success Dashboard | `lessons-platform-analytics.md`; `success-dashboard.md` respectively |
| Now Assist/AI Search/agents/governance | `now-assist.md`; `australia-ai-platform.md` for Australia-specific notes; `external-mcp-evaluation.md` only for MCP evaluation |
| Instance indexes; dependency graphs | `service-now-indexing.md`; `servicenow-graph-mapping.md` |
| FFI applications | Matching `lessons-personellsikkerhet.md`, `lessons-besoksregistrering.md`, or `lessons-eba-fdv.md` |
| Vår implementation/design | `vaar-energi-lessons.md`; `vaar-energi-design.md` |
| Vår assigned-story monitoring/approval or substantive work on a resolved story | `vaar-energi-operations.md`; approval applies only to the exact plan in Vår DEV |

## Local conventions

`implement this story "<number>"`: PROD supplies requirements; implement/validate in DEV and prepare the final work note. It does not authorize posting notes, state changes, PROD writes, completion/export/deployment, plugin installation, deletion, or other high-impact work. Follow `story-delivery.md`.

After ordinary work, edit this skill only for an evidence-backed, reusable lesson that changes future decisions; consolidate rather than append history. Exclude secrets, customer data, transient IDs, and one-off outcomes. Validate changed skill/helpers. Skill maintenance does not authorize instance writes, publishing, commits, pushes, or installation.

When explicitly asked to publish this skill, inspect status/diff, stage intended files, commit tersely, and push `main` to `https://github.com/simenandreas91/servicenow-pdi-powershell.git`; create a PR only if requested.
