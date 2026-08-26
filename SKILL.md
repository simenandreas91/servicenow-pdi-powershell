---
name: servicenow-pdi
description: Perform senior-level ServiceNow analysis, configuration, development, debugging, validation, and delivery against Simen's PDI and approved ServiceNow environments. Use for Now Assist, AI Agent Studio, AI agents, agentic workflows, Skill Kit, AI Control Tower, CMDB, CSDM, Service Graph, IRE, Discovery, Service Mapping, ITOM/ITAM, ITSM, Service Level Management, SLA/OLA/underpinning contracts, HRSD, CSM, Catalog, Flow Designer, IntegrationHub, ACLs, notifications, Platform Analytics dashboards and data visualizations, reports, imports, integrations, scoped apps, Service Portal, Employee Center, Workspace, UI Builder and custom Next Experience components, UI16, update sets, stories, instance inspection, and ServiceNow-hosted front ends. Provides narrow Table API and Xplore helpers, update-set controls, environment routing, domain playbooks, and safe OOTB-first implementation workflows.
---

# ServiceNow PDI

## Mission

Operate as a senior ServiceNow engineer. Establish facts from the target instance, choose the most native supported solution, make the smallest coherent change, prove it in the real execution channel, and leave a clean delivery and rollback trail.

Use the bundled helpers for narrow, repeatable instance work. Prefer synced local files when a healthy SN Utils/sn-scriptsync workspace already represents the artifact. Use the browser for rendered behavior, guided builders, or UI-only configuration—not for metadata discovery that an API can answer faster.

## Golden Rules

- Inspect before proposing or changing. Confirm the environment, release/build, scope, artifact, schema, existing configuration, dependencies, user/roles, channel, and current update set.
- Prefer OOTB configuration and supported extension points. Customize only when native options cannot meet a material requirement.
- Diagnose read-only. Do not implement a fix unless the request includes implementation or the user approves the fix.
- Resolve records live by stable keys. Use `sys_id` as a resolved write handle, never as a portable assumption. Do not embed instance-specific sys_ids in deliverables; use properties, aliases, natural keys, or setup records.
- Check official ServiceNow documentation for release-sensitive behavior, APIs, deprecations, plugins, licensing, security contracts, or any uncertain platform fact.
- Select the correct application scope and delivery context before configuration writes. Keep unrelated work and application scopes separate.
- Make writes narrow, reversible, and observable. Never turn an exploratory query into a broad mutation.
- Treat production as read-only unless the user explicitly authorizes the exact write. Authorization for DEV or PDI never implies authorization for PROD.
- Enforce security server-side. UI hiding, client scripts, and user criteria are not substitutes for ACLs or protected server logic.
- Validate every change at the record, behavior, channel, security, and packaging layers that apply. A successful save, API response, or Xplore run is not end-to-end proof.
- Protect secrets and sensitive data. Never expose passwords, tokens, auth headers, credential records, HR data, or unnecessary record payloads.
- Keep instance-visible text professional and human. Never mention Codex, AI, agents, bots, or automation in work notes, descriptions, update-set text, logs, emails, journal fields, or test markers.
- Ask at most one focused question when evidence cannot resolve an ambiguity and a wrong choice would materially affect architecture, security, licensing, production data, many records, or the required user channel. Otherwise proceed with a stated, low-risk assumption.

## Default Operating Loop

1. Frame the outcome: business requirement, acceptance criteria, artifact/table, target environment, user persona, UI/runtime channel, and whether the request is analysis, diagnosis, implementation, or delivery.
2. Classify risk:
   - **Read-only:** inspection, explanation, design, or diagnosis.
   - **Controlled change:** narrow configuration or code in PDI/DEV with clear validation and rollback.
   - **High impact:** production, deletes, bulk data, ACL/role changes, credentials, plugins, imports, external calls, or widely triggered automation.
3. Inspect the smallest useful surface. For substantial work or resumed context, run `Get-ServiceNowPdiHealth.ps1`; then use targeted artifact, scope, schema, and dependency queries.
4. Reproduce or establish a baseline before editing. Record the exact user, record, state, input, channel, and observed result.
5. Choose the first viable option in **Solution Ladder**. State the tradeoff only when architecture or upgradeability is non-obvious.
6. Before a controlled change, identify exact records, intended scope/delivery vehicle, expected capture, test, side effects, and rollback. Snapshot developer preferences before switching them.
7. Implement one small vertical slice using existing naming, application, package, and code conventions.
8. Re-read changed records without cache, verify update capture, and execute behavior-level tests in the actual channel and persona.
9. Remove only throwaway data and accidental updates created by this task. Restore developer preferences unless the user asks to retain the context.
10. Before handoff, complete the mandatory **Recursive Skill Improvement** pass for substantive work and validate the resulting skill change.
11. Report outcome, evidence, changed artifacts, delivery vehicle, cleanup, rollback, remaining risk, assumptions, manual steps, and the skill improvement made.

Do not add process overhead to a simple read. Apply each control only when its layer is relevant.

## Recursive Skill Improvement

Treat this skill as a living engineering system. After every substantive ServiceNow task that required meaningful investigation, experimentation, debugging, implementation, or validation, make at least one concrete, durable improvement to this skill before the final handoff. The user does not need to request the update. A blocked or unsuccessful task still requires an update when the effort produced a reusable lesson about diagnosis, tooling, validation, safety, or a failure mode. Trivial lookups and simple explanations that produce no new operational knowledge do not trigger forced edits.

- Distill the improvement into the right artifact: put universal routing and guardrails in `SKILL.md`, domain-specific knowledge in the relevant reference, repeated mechanics in a helper script, and observable checks in tests or validation guidance. Improving or removing weak, conflicting, or obsolete guidance counts; avoid append-only accumulation.
- Make the update evidence-backed and useful beyond the current record. Preserve the causal lesson, decision rule, command pattern, or verification method—not a chronological task log or a copy of the delivered solution.
- Never store secrets, sensitive customer data, instance-specific sys_ids, transient record state, private payloads, or unnecessary customer details. Generalize examples and resolve live identifiers at runtime.
- Inspect the existing worktree and integrate narrowly with user-owned changes. Edit only relevant skill resources. Skill maintenance does not broaden authority to write to ServiceNow, publish, commit, push, install software, or change another environment.
- Validate the update proportionately: run the skill validator, run syntax or focused tests for changed helpers, confirm every new reference is discoverable, and inspect the final diff for contradictions and accidental edits.
- State at handoff what was improved and why it will make the next similar task faster, safer, or more reliable. Do not silently skip the recursive pass after substantive work.

## Solution Ladder

Use the first option that satisfies the requirement cleanly:

1. Existing OOTB feature or configuration: property, role, ACL, dictionary setting, template, assignment/data rule, SLA, notification, report/dashboard, state model, catalog configuration, or supported UI setting.
2. Existing application metadata: Flow/subflow/action, UI or data policy, decision table, user criteria, catalog/HRSD/Journey model, Workspace UX/declarative action, portal options/composition, or IntegrationHub spoke/action.
3. Small additive configuration in the supported model.
4. A focused Flow/subflow/action when visual ownership, approvals, retries, orchestration, or integration operations benefit from it.
5. A reusable Script Include with a thin Business Rule, UI Action, Client Script/GlideAjax, Scripted REST wrapper, or Flow action when scripting is justified.
6. A supported extension or clone of a ServiceNow-owned UI artifact, with the upgrade cost documented.
7. A custom table, API, UI, or ServiceNow-hosted SPA only when native patterns are materially worse.

Reject a design that duplicates OOTB behavior, edits base artifacts unnecessarily, bypasses access controls, depends on fragile identifiers, creates an avoidable synchronous transaction, cannot be packaged predictably, or has no practical verification path.

## ServiceNow Development Standards

- Default new custom development to a scoped application unless an existing application or platform contract requires Global.
- Keep Business Rules small, conditioned, and single-purpose. Use a before rule to set fields on `current`; never call `current.update()` from a Business Rule. Put reusable logic in a Script Include.
- Prefer server-side data retrieval and GlideAjax over client-side GlideRecord. Treat all client inputs as untrusted.
- Use `GlideRecordSecure` or explicit access checks for user-context or sensitive operations. Test ACL behavior as a non-admin; admin success proves little.
- Query narrowly with encoded conditions, indexed/selective fields, `setLimit`, and aggregates. Avoid queries inside loops, unbounded scans, recursive updates, and per-row outbound calls.
- Make integrations and retryable automation idempotent. Prefer connection aliases/auth profiles and IntegrationHub or REST Message records over credentials or endpoints in scripts.
- Keep external calls out of synchronous record transactions when practical. Define timeout, error, retry, and duplicate-handling behavior.
- Preserve upgradeability: configure or extend before cloning; clone only artifacts designed for it or when the documented benefit outweighs skipped upgrades.
- Follow the existing deployment model. For a new custom scoped application, evaluate ServiceNow SDK/Fluent with Git and the Application Repository as the preferred source-based path. Use update sets for Global, operational, hotfix, plugin-owned, and established update-set work. Do not mix delivery mechanisms casually.
- Do not use update sets to transport operational/task data. Use an approved import, migration, or idempotent data script with explicit reconciliation.
- For every new custom table intended for forms or Workspace, create and save a usable **Default view** after the fields exist. Before Workspace selection, verify that the table has a Default-view `sys_ui_section`; App Engine Studio excludes tables without one even when scope, application access, and ACLs are correct. Follow `references/custom-scoped-apps.md` for the UI-first creation and verification pattern.

## Now Assist And Agentic AI Standards

Load `references/now-assist.md` for every Now Assist, AI Agent Studio, AI agent, agentic workflow, Skill Kit, Now Assist panel, Guardian, AI Control Tower, AI Search/Genius Results, agentic evaluation, AI consumption, or MCP-for-AI task.

- Start with the least-agentic solution that satisfies the outcome: deterministic Flow/configuration first, then a packaged or custom skill for one bounded generation task, a single AI agent for tool-selecting work, and an agentic workflow only for adaptive coordination across genuinely distinct specialists.
- Verify the instance family/patch, Store app versions, entitlements, plugins, model/provider availability, regional restrictions, and actual guided-setup options before designing. Australia documentation changes across patches and Store app versions.
- Define the business outcome, success/failure states, user persona, record context, channel, interactive versus non-interactive mode, trigger, maximum side effects, human-approval points, and assist budget before authoring instructions.
- Make each AI agent a narrow worker with a non-overlapping role. Write its List of steps as an operational algorithm with explicit tool names, inputs, decision conditions, outputs, stop conditions, retries, and an honest `insufficient evidence` path. The platform Orchestrator coordinates workers; do not create a fake custom orchestrator agent.
- Give every tool one purpose and a precise contract. Prefer a tested Flow action or subflow for consequential writes, approvals, retries, integrations, and multi-record transactions; use bounded record operations for simple CRUD; use scripts only when supported declarative tools cannot express the requirement.
- Treat invocation ACLs, runtime identity, role masking, downstream tool ACLs, table/field ACLs, domain separation, and data policies as separate controls. Default to Dynamic user plus the smallest approved-role intersection. Use an AI user only for a documented service-identity need, and never treat an AI user as a shortcut around user authorization.
- Keep irreversible, high-impact, ambiguous, sensitive, external, or bulk actions in Supervised mode. Design mutating tools to validate inputs, authorize server-side, be idempotent, return durable record identifiers, and distinguish `already complete`, `not authorized`, `not found`, `validation failed`, and transient errors.
- Test the active instruction version manually, inspect the execution plan/decision log/tool calls, run Test access for allowed and denied personas, execute dataset-based agentic evaluations, and test the real channel. Verify final records and downstream effects, not just conversational output.
- Transport triggers inactive because they contain instance-specific data. Re-resolve dependencies on the target, test access and behavior there, then activate agents/workflows/channels before triggers. Duplicate packaged assets when customization requires it unless the installed version explicitly supports the intended edit.
- Monitor executions, failures, latency, tool count, assist tier/consumption, Guardian logs, and user feedback. Keep the Australia Patch 3 runaway-trigger kill switch configured, use narrow trigger conditions, and retain an operational deactivation path.

## CMDB and CSDM Standards

Load both `references/cmdb-csdm.md` and `references/cmdb-admin-development.md` for CMDB, CSDM, Service Graph, IRE, Discovery, Service Mapping, CMDB Health, Data Manager, service modeling, CI migration, or AI-service modeling work. Load `references/cmdb-query-library.md` when the task needs table inspection, diagnosis, scripts, imports, remediation, or validation. Load `references/cmdb-data-foundations-lab.md` for repeatable PDI exercises of the Ingest, Govern, and Insight pillars. The architecture guide defines the model; the admin/developer guide defines the operating decisions; the query library supplies bounded probes and implementation patterns.

- Treat CMDB as an operational graph product scoped to business outcomes, principal CI classes, and one or two pilot services—not as a universal inventory dump.
- Treat CSDM as prescriptive conceptual and physical modeling guidance, not a product to install. Verify the target release, live table/class, Store app, plugin, licensing, UI, IRE, health, lifecycle, and product support before relying on a CSDM entity.
- Route automated CI creates and updates through IRE. Prefer Discovery and certified Service Graph Connectors, then IntegrationHub ETL, then an explicitly IRE-aware custom integration. Do not use direct/coalesced CMDB writes as an identity strategy.
- For each CMDB request, identify the target class, business consumer, source, identity rule, attribute authority, relationship direction, health scope, lifecycle behavior, and rollback before proposing a write. Give exact tables, encoded queries or bounded scripts, expected evidence, and stop conditions; do not answer with dashboard navigation alone.
- Resolve release-sensitive tables and fields live through `sys_db_object` and `sys_dictionary` before scripting. Treat workspace cards as views over governed records, not as the source of truth. Never invent an internal table name when official documentation exposes only a UI label.
- Diagnose in this order: source/run health -> payload and target class -> identification decision -> reconciliation/provenance decision -> relationship/dependency processing -> health/lifecycle consumers. Fix the earliest broken contract and then remediate existing data.
- Inspect the target class in CI Class Manager before population or extension. Define identification, reconciliation, dependent relationships, required/recommended fields, health, ownership, freshness, and retirement behavior together.
- Use prescribed CSDM relationships and direction. For manual infrastructure modeling, match what Discovery would produce. Add only relationships that support a named workflow, control, report, or identification need.
- Keep Business Application, Service Instance/Application Service, discovered Application, Business Service, Technology Management Service, and offerings semantically distinct. Do not use a Business Application as the operational CI for Incident, Problem, or Change.
- Fix duplicate/stale root causes at the source, mapping, IRE, or lifecycle layer before bulk remediation. Use De-duplication tools and CMDB Data Manager with preview, exclusions, approvals, dependent-CI analysis, and rollback/recovery planning.
- Scope CMDB Health and Data Foundations to principal classes and critical services. Report denominators, exclusions, refresh time, remediation age, and operational outcomes rather than a single global percentage.
- For AI agents and Workflow Data Fabric, preserve CMDB/CSDM as the governed service context. Apply least privilege, evaluations, IRE, human approval for consequential writes, and explicit contracts before joining external data or automating remediation.

## Service Level Management Standards

Load both `references/sla.md` and `references/sla-query-library.md` for SLA definitions, Task SLAs, OLAs, underpinning contracts, service commitments, SLA schedules/time zones, SLA flows or notifications, SLA Timeline, SLA repair, SLA breakdowns, or SLA timer work. The runbook defines the design and delivery decisions; the query library supplies bounded inspection and validation patterns. Also load the applicable product/customer reference, such as `references/vaar-energi-lessons.md` for a Vår Energi HR SLA.

- Separate the service promise from the timer configuration. Define the consumer, target, success event, duration semantics, schedule, time-zone authority, start/cancel/pause/resume/stop/reset behavior, exclusions, escalation, and reporting outcome before creating `contract_sla` metadata.
- Treat `contract_sla` as the definition and `task_sla` as runtime evidence. Never create or repair Task SLA rows directly. Let the SLA engine attach and transition them from a real task update; use supported SLA Repair only after a bounded preview and approval.
- Remember that Type (`SLA`, `OLA`, or underpinning contract) and Target (`response` or `resolution`) are reporting classifications. They do not implement response or resolution behavior; the conditions do.
- Model duration as hours of SLA-running time. A Duration value of one day is 24 hours, so on an eight-hour weekday schedule it consumes three working days. Convert a business-day promise to scheduled hours deliberately and prove the planned end time across a weekend/holiday boundary.
- Prefer a fixed user-specified duration for elapsed service commitments. Use a relative duration only for a real future deadline/cutoff rule; relative durations do not support pause conditions.
- Resolve the schedule source and time-zone source explicitly. Inspect schedule spans, holidays, task/CI/caller location fallbacks, and daylight-saving boundary behavior instead of assuming instance or user time.
- Design conditions as a state machine and account for precedence: stop can prevent attachment and completes an existing Task SLA; reset plus start reattaches; cancel semantics depend on `When to cancel`; pause/resume apply only while active. Avoid frequently changing dot-walked fields because Timeline and Repair replay task history, not historical values on referenced records.
- Inspect all active definitions on the target table and ancestors before adding one. Prove that exactly the intended definitions attach; overlapping generic and service-specific SLAs are a configuration defect unless concurrent commitments are explicitly required.
- For new notification/escalation requirements, prefer an SLA flow in Workflow Studio. Since Yokohama, ServiceNow recommends flows for new SLM work; do not configure both Flow and Workflow on one definition. Resolve the default flow by stable name rather than carrying its sys_id between instances.
- Create definitions inactive-first where the installed form/API supports it, in the correct application scope and update set or SDK-managed application. Validate with SLA Timeline and a real non-production task before activation. Test attach, negative/no-attach, pause, resume, stop, cancel/reset when used, breach/planned-end calculation, overlap, flow side effects, security, and packaging.
- Do not change engine-wide properties, enable async processing, run bulk repair, or activate plugins merely to make one SLA pass. Diagnose the definition/task first. Synchronous 2011-engine processing is the documented default and preferred experience; asynchronous mode is a performance exception that introduces attachment delay.

## HR Agent Workspace Standards

Load `references/hr-agent-workspace-configuration.md` for Agent Workspace for HR Case Management configuration, HR Agent Workspace properties, Page Configurations, UX page properties, lists/audiences, At a Glance, contextual sidebar, Activity Stream, highlighted values, `Workspace UIB` form metadata, or migration diagnosis from Classic HR Agent Workspace.

- Identify the product before configuring it: current Agent Workspace for HR Case Management uses `com.sn_hr_agent_ws` and typically `/now/hr/agent`; deprecated Classic uses `com.sn_hr_agent_workspace` and commonly `/now/hr/workspace`. Never apply `sn_hr_ws` properties to the configurable workspace without proving the target is Classic.
- Prefer the workspace settings icon and documented Page Configurations over UI Builder or direct UX metadata edits. Treat the installed `propertySettings` schema as read-only discovery; update only a resolved supported property's value, and never create a missing page property to imitate another Store-app version.
- Resolve target-local references for Agent Assist, response templates, list configuration, highlighted values, and email templates on every environment. Do not transport remembered `sys_id` values inside JSON or string properties.
- Use `sys_ux_list_menu_config`, `sys_ux_list_category`, `sys_ux_list`, `sys_ux_applicability`, and `sys_ux_applicability_m2m_list` for centrally governed lists and audience visibility. UI visibility does not replace ACLs.
- Treat global properties for rich text, stacked journals, reflow, live lists, form personalization, or script editors as high-blast-radius changes. Prefer the narrow experience/page control when available and test another workspace plus accessibility behavior.
- Validate with a fresh workspace session, the intended HR persona and a denied persona, the affected base and extension tables, correct update capture, and a reversible before-value snapshot.

## Platform Analytics Standards

Load `references/lessons-platform-analytics.md` for Platform Analytics dashboards, data visualizations, filters, indicators, dashboard migration, dashboard embedding, or `par_*` artifact work.

- On Australia and later, default new analytics content to a Platform Analytics in-line dashboard. Use a technical dashboard only when UI Builder scripting, data binding, custom events, or components are materially required; use Core UI responsive dashboards only for a documented legacy constraint.
- Prefer the supported in-line editor and Visualization Designer for authoring. Use scripted `par_*` creation only for repeatable non-production automation after inspecting a known-good dashboard on the same release/build, and validate the result in the editor. Treat saved `component_props`, macroponent IDs, and internal record graphs as release-sensitive implementation details.
- When scripted `par_*` maintenance is justified, distinguish the script execution scope from record ownership. Run Xplore in **Global** for Global `par_*` tables, keep the intended application/update-set preferences selected, and set `sys_scope`/`sys_package` explicitly on new app-owned records. Running the same writes from a custom application scope can create allowed cross-scope privilege records and update-set noise while inserts still fail; inspect those security artifacts after any mistaken scoped attempt and never delete or deny them without authorization.
- Choose table data for current, persona-aware operational views and indicators for governed historical trends, targets, breakdowns, or scheduled snapshots. Do not place Core UI reports or PA widgets on a Platform Analytics dashboard; create data visualizations instead.
- Select the application scope before editing, define owner and target audience, and test sharing separately from underlying table/field ACLs. Editing a shared dashboard changes it for all viewers, and dashboard edit rights do not automatically grant library-visualization edit rights.
- Make filter behavior explicit per visualization or metric. Test default values, clear/reset, incompatible table/indicator sources, drilldowns, and the intended viewer; do not assume that a dashboard filter safely applies to every widget.
- Choose one freshness strategy deliberately. Scheduled repetition and dashboard data caching are mutually exclusive; real-time or refresh-after-away settings override caching for that visualization. Validate load time, freshness, and query cost with representative data.
- For promotion, use **Unload Dashboard** from the `par_dashboard` record after the in-line dashboard is complete; tabs are not captured automatically by ordinary edits. Ensure referenced saved visualizations and filters exist in the same update set or already on the target. Technical dashboards are not supported by this update-set transport path, and migrated Core UI content must be migrated in each environment through Migration Center rather than transported as migrated output.

## Inspection and Debugging

Debug from evidence, not from the most plausible story:

1. Reproduce with the affected persona, record, channel, and inputs. Compare with one known-good case when possible.
2. Inspect the visible layer: route/page, component/widget, form/list configuration, action, client script, UI policy, browser console, and network request.
3. Trace the server layer: ACL/application access, query/business rules, Script Includes, data policies, flows/events, integrations, and generated records.
4. Inspect runtime evidence: transaction/application logs, flow context and step errors, events, emails, outbound HTTP/import logs, audit/history, and timestamps.
5. Isolate one layer at a time with the smallest read-only probe. Use Xplore for concise server checks, not speculative repair.
6. Verify the cause by changing one controlled variable or by proving the expected condition fails. Distinguish root cause from downstream symptoms.
7. After a fix, repeat the original reproduction and a nearby negative/regression case.

For visibility problems, distinguish ACLs, application access, domain separation, before-query rules, user criteria, filters, route configuration, and UI hiding. For asynchronous behavior, a started flow or processed event is not proof of the final task, email, or integration outcome.

## Safe Change and Rollback Rules

- Before writing, capture identifiers and before-values for every target record. For complex metadata, retain a record/XML snapshot or a precise reconstruction path.
- Define rollback before implementation. A rollback may be a configuration revert, a follow-up update set, source revision, restored preference snapshot, deactivation, or a bounded data reversal. Do not imply that update-set backout reverses runtime data.
- Prefer additive or inactive-first changes when activation could affect many transactions. Activate only after configuration-level checks pass.
- For bulk data work, first run a read-only count and sample; state the maximum affected rows; use stable selection, idempotency, batching, before-value capture, and post-run reconciliation. Do not run it without explicit approval.
- For parent-child demo seeds, confirm the live reference target and display fields, resolve or insert each parent by a deterministic business key, and write the parent's resolved `sys_id` into each child. Reconcile exact parent and child totals, the expected child count per parent, key uniqueness, required field completeness, and zero orphan references; never use a display label as the reference value.
- For ACL changes, preserve an admin recovery path and test allow and deny cases. Never disable security to make a feature appear to work.
- For flows, notifications, scheduled jobs, imports, and integrations, prevent accidental fan-out. Use a safe record/payload, controlled activation, and inspect generated side effects.
- Never delete or overwrite unrelated user work. Never clean records merely because they look noisy or stale.

Stop and obtain explicit authorization before production writes; deletes; Fix Scripts or broad repairs; mass role/group/security changes; imports against production-like data; credential/OAuth/SSO/MID/connection changes; Store/plugin installs; external calls with real side effects; direct edits to ServiceNow-owned artifacts; or completion/commit/export of a suspicious update set.

Load `references/safety-checklists.md` before any of these high-impact operations.

## Update Sets and Delivery

- Before configuration writes, select the intended scope and in-progress update set with `Set-ServiceNowUpdateSetContext.ps1`; snapshot existing preferences and restore them at handoff.
- When resuming an existing update set, resolve it live and pass `-UpdateSetSysId`. Treat `-Name` as creation input rather than lookup input; reusing an existing name can create an empty duplicate instead of selecting the prior set.
- Use a clear story/change name. Default to one in-progress update set for the same cohesive change and application scope, including iterative fixes; do not create successive `clean`, `final`, or per-revision sets. Start another set only for a different application scope, unrelated change, explicit release isolation, or when the existing set is completed or unsafe to continue. Use separate child sets per application scope and a parent batch only when coordinated delivery requires it.
- Do not develop in the Default update set. Do not delete update sets, back out Default, reopen a completed set, or manually change `sys_update_xml.update_set` to move a customer update.
- Never add or misuse the `update_synch` dictionary attribute to make data travel in update sets.
- Confirm natural capture after each coherent slice with `Confirm-ServiceNowUpdateCapture.ps1` or `Get-ServiceNowUpdateSetSummary.ps1`. Use `Save-ServiceNowCustomerUpdate.ps1` only for a legitimate application file that should have captured but did not, after understanding why.
- Treat mixed application, unexpected types, broad form/layout changes, duplicate names, or unrelated customer updates as warnings. Do not move suspicious rows to another set; recapture the source record correctly in the intended context.
- Complete/export only when explicitly requested and the summary is clean. Preview and resolve collisions on the target before commit; test after deployment. Record manual data/setup steps separately.

## Tool Routing and Cost Discipline

Choose the cheapest tool that can produce reliable evidence:

| Need | First choice | Escalate when |
| --- | --- | --- |
| Exact metadata/data read or narrow write | `Invoke-ServiceNowTable.ps1` | API ACLs block necessary evidence or behavior must execute server-side |
| Server API/runtime probe | `Invoke-ServiceNowXploreScript.ps1` | Xplore is unavailable or comparison with Scripts - Background is explicitly required |
| Existing file-backed source | Synced local files + sn-scriptsync | Mapping is incomplete, sync is unhealthy, or live metadata/capture must be inspected |
| New or converted source-based custom app | ServiceNow SDK/Fluent project + Git | The artifact is unsupported in Fluent, the app is not SDK-managed, or live platform behavior must be verified |
| Portal, Employee Center, Workspace, or custom UI design | Existing component/theme and customer design system + rendered browser inspection | Use `gpt-taste` only as an ideation layer for an explicitly premium landing page or bespoke frontend |
| Rendered UI or builder-only behavior | In-app browser | Use API first to locate records and avoid manual navigation |
| Release-sensitive platform behavior | Official ServiceNow docs matching the instance release | Use community material only as secondary context |
| Broad discovery/impact mapping | Cached inventory/index or graph mapping | Verify every edit candidate live before writing |

Use `sysparm_fields`, selective encoded queries, small limits, `-ExcludeReferenceLink`, and compact result objects. Query exact records before broadening. Use cache for discovery, `-Refresh` when freshness is uncertain, and `-NoCache` for post-write verification. Do not repeatedly fetch bodies or large related lists already established as irrelevant.

### Helper sequence

- `Get-ServiceNowPdiHealth.ps1`: substantial-task preflight and context recovery.
- `Find-ServiceNowArtifact.ps1`: named artifact/event/script search.
- `Get-ServiceNowScopeInventory.ps1`: application inventory.
- `Get-ServiceNowTableShape.ps1`: unfamiliar tables, choices, references, and ACL summary before writes.
- `Export-ServiceNowDelta.ps1`: resume work since a known timestamp.
- `Build-ServiceNowInstanceIndex.ps1`, `Find-ServiceNowIndexedArtifact.ps1`, `Get-ServiceNowIndexedImpact.ps1`: broad local discovery only; verify live.
- `Test-ServiceNowNotification.ps1`: event/notification inspection and controlled triggering.
- `Get-ServiceNowUpdateSetSummary.ps1` and `Confirm-ServiceNowUpdateCapture.ps1`: packaging proof.
- `Get-ServiceNowCompendiaSyncStatus.ps1`: read-only Vår Energi Compendia reconciliation across articles, staging, attachments, properties, and the scheduled job.
- `Manage-VaarEnergiStoryMonitor.ps1`: maintain the private baseline and reviewed-story state used to deduplicate assigned-story monitoring notifications.
- `Manage-VaarEnergiStoryWorkLog.ps1`: idempotently record daily Vår Energi story work and build/mark the weekly email report.
- `Restore-ServiceNowPreferenceSnapshot.ps1`: handoff cleanup. Store intentionally retained preference snapshots under `snapshots/`; remove transient snapshots after a successful restore.

See `references/toolkit.md` and `references/examples.md` for parameters and commands. Locate helpers relative to this skill instead of assuming a fixed installation path.

### SN Utils/sn-scriptsync

When the workspace already contains a clear synced representation and `.vscode/sn-agent-port.json` identifies a healthy local Agent API:

1. Inspect the local source and the live record metadata. Treat each instance folder as a separate environment; do not propagate changes across them unless requested.
2. Edit the split source files with normal code tools and keep any aggregate record file consistent with the workspace convention.
3. Run local syntax/static checks.
4. Call `sync_now`, then require `get_sync_status` to show no pending writes.
5. Re-read the live record, confirm update-set capture, and test the rendered/runtime behavior.

Never print or persist the Agent API token. If local and live content disagree or ownership is unclear, stop writing and establish the source of truth. Use Table API/Xplore for record metadata, ACLs, runtime data, related records, and update-set verification.

### ServiceNow SDK/Fluent

Use the official ServiceNow SDK workflow when a workspace has `now.config.json`, or when creating or deliberately converting a custom application to source-based development. Load `references/servicenow-sdk.md` before SDK work.

- Treat the local SDK project and Git repository as the source of truth for SDK-managed metadata. Do not make competing Table API, sn-scriptsync, update-set, or builder edits to the same artifact without an explicit reconciliation plan.
- Orient through the installed CLI instead of guessing syntax: inspect the version and top-level help, then inspect each subcommand's help. Use `explain --list`, `--peek`, and the relevant full topic before generating Fluent metadata.
- Use SDK `query` for narrow, machine-readable discovery when convenient; keep the bundled helpers for cached inventory, Xplore execution, update-set context/capture, rollback evidence, and established non-SDK work.
- Build before install. Treat `install`/`deploy`, conversion, dependency changes, and instance synchronization as writes. Target only an explicitly confirmed non-production instance and validate the installed behavior there.
- Do not install ServiceNow's official `now-sdk` skill globally by default: its published trigger overlaps nearly every ServiceNow task. For an active SDK project, keep it separate so it can track SDK releases, and use it only with this skill's environment, safety, delivery, and validation rules rather than duplicating its changing CLI documentation here.

### ServiceNow UI Experience

For visual design, layout, styling, motion, or frontend implementation, load `references/servicenow-ui-design.md` plus any applicable customer design reference.

For UI Builder custom components, Component Builder macroponents, Next Experience UI Framework, `now-ui.json`, `@servicenow/ui-core`, or ServiceNow CLI `ui-component` work, load `references/ui-builder-custom-components.md` before choosing a toolchain or editing component source. When implementation begins, also use its routed worked example in `references/ui-builder-custom-component-example.md` as the scaffold-and-validation pattern.

For a ServiceNow-hosted React/Vite SPA, WebGL scene, interactive floor plan, or other 3D frontend, also load `references/servicenow-react-3d-frontends.md`.

- Prefer an OOTB component, preset, data resource, controller, page collection, viewport, or declarative action before owning a custom component. Use Component Builder for reusable low-code composition; use the ServiceNow CLI `ui-component` extension only when custom HTML, SCSS, JavaScript, lifecycle behavior, or a browser library is materially required.
- A CLI component is a Next Experience web component, not a React component. Keep ServiceNow's generated framework and renderer packages aligned to the target family. Treat React or a custom renderer as an unsupported integration experiment with explicit lifecycle, bundle, accessibility, upgrade, and support acceptance.
- Treat the component contract as properties in and typed events out. Prefer UI Builder data resources/controllers for page-owned data; enforce all reads and writes with server-side ACLs and APIs. Component visibility and client validation are not security controls.
- Keep the CLI project, lockfile, manifest, and Git history as the source of truth. Deploy only to confirmed non-production, use `--force` only after proving ownership and reviewing overwrite impact, and promote the resulting scoped application through one established App Repository or update-set path rather than redeploying ad hoc to production.
- Classify the surface before designing. Transactional forms, approvals, dashboards, and workspaces need compact predictability; portal landing pages can use stronger editorial hierarchy; bespoke campaign pages may justify richer visual direction.
- Start from OOTB components, the active theme, reusable tokens, and the customer's design system. Scope CSS to the owned component or page and avoid global overrides that can destabilize unrelated experiences.
- For a presentation-only change limited to one Service Portal placement, evaluate `sp_instance.css` before cloning or editing the widget. Scope selectors beneath stable component markup, verify nested child-widget styles can be reached, and prove reused instances remain unchanged.
- Use deliberate hierarchy, readable heading widths, consistent spacing, complete grids, legible actions, and purposeful imagery. Remove decorative labels, badges, counters, and cards that do not help the user complete or understand something.
- Treat `gpt-taste` as inspiration, not platform law. Do not import its randomization, mandatory AIDA, huge section spacing, stock-image URLs, or motion-everywhere rules into ordinary ServiceNow experiences.
- Motion must communicate state or hierarchy, work without hover, respect reduced-motion preferences, and preserve performance. Do not add GSAP or another dependency unless the experience genuinely needs it and the platform packaging path supports it.
- Validate the rendered experience at relevant breakpoints with real content and the intended persona. Check keyboard/focus behavior, contrast, zoom/text expansion, localization, empty/error/loading states, horizontal overflow, and regression against surrounding OOTB components.

## Validation Standard

Apply the relevant layers and record concrete evidence:

- **Configuration:** re-read the exact record by resolved `sys_id`; verify scope, package, active/state, conditions, references, and key fields.
- **Behavior:** trigger one realistic safe scenario; verify the final record, event, flow step, email, response, import result, or downstream state—not merely the trigger.
- **Channel:** test UI16, Workspace, Service Portal, Employee Center, mobile, or API as requested. One channel does not prove another.
- **Security:** test the intended persona plus an unauthorized/negative case where access matters.
- **Delivery:** confirm expected customer updates/application and absence of unrelated capture.
- **Regression:** test one adjacent or false-condition case for automation, ACLs, scripts, and shared UI.
- **Cleanup:** account for test records, queued email/events, flow contexts, imports, attachments, and restored preferences.

If a layer cannot be tested, say exactly why, what was tested instead, the remaining risk, and the manual verification step. Never report success from inference alone.

## Environment Routing

Helpers load credentials from the nearest workspace `.env`. Prefer an explicit profile and env path when generic `SN_*` variables could target the wrong instance.

- `pdi`: Simen's PDI at `https://dev396302.service-now.com`; default for demonstrations and safe reproduction.
- For `pdi`, a workspace `.env` may provide `SN_PDI_INSTANCE` without duplicating credentials. When `SN_PDI_USER` or `SN_PDI_PASS` is absent there, the resolver may use the canonical private fallback at `%USERPROFILE%\.codex\servicenow-pdi.env`; workspace profile-specific values still take precedence.
- `vaar_dev`: Vår Energi DEV from `SN_VAAR_DEV`; use this for implementation and validation of Vår Energi stories. Legacy profile `other` remains an alias for `vaar_dev`.
- `vaar_test`: Vår Energi TEST from `SN_VAAR_TEST`; use it for transported configuration validation and UAT preparation.
- `vaar_prod`: Vår Energi PROD from `SN_VAAR_PROD`; keep it read-only without exact production-write authorization.
- Vår profiles accept `SN_VAAR_<ENV>_USER` / `SN_VAAR_<ENV>_PASS` when credentials differ by environment. For compatibility with the existing Vår credential file, every `vaar_*` profile also falls back to shared `SN_OTHER_USER` / `SN_OTHER_PASS` before generic `SN_USER` / `SN_PASS`. The legacy `other` profile can also resolve DEV from `SN_OTHER_INSTANCE`. Never print any credential form.
- Do not use `SN_OTHER_INSTANCE` as an implicit PROD or TEST destination. Configure `SN_VAAR_PROD` / `SN_VAAR_TEST` (or the corresponding `_INSTANCE` key), or pass the exact `-Instance` URL intentionally; only the legacy credentials are shared as a fallback.
- Invoke helpers with an explicit profile, for example `-Profile vaar_dev -EnvPath '<approved-env-path>'`. Use `-Instance` only for an intentional one-off override after verifying the returned environment.
- Values in the explicit `.env` are evaluated across canonical and compatible legacy keys before process/user environment variables. A named profile with no matching instance fails closed; it must never inherit generic `SN_INSTANCE` or a different environment's URL.
- FFI/Personellsikkerhet is on-premise and not directly reachable. Treat the PDI as the mirror unless the user provides reachable access or exported evidence. Never route FFI work to Vår Energi implicitly.

After connecting, verify the returned instance name/URL and current user before relying on results or writing. Never store credentials in the skill, references, cache, update sets, logs, or test data.

## Vår Energi Assigned Story Monitor

Use `scripts/Manage-VaarEnergiStoryMonitor.ps1` to distinguish newly assigned active Vår Energi stories from records already handled by a recurring monitor. The helper stores only story numbers, sys_ids, timestamps, disposition, and Gmail message/thread handles for approval routing in the private local state file; it does not store story descriptions, plan text, email bodies, or attachments.

1. Resolve the assignee live by `sys_user.user_name`, query the current active PROD `rm_story` assignments read-only, and normalize them to compact JSON containing `sys_id` and `number`.
2. On first setup, run `-Action Baseline -StoriesJson '<json>'` so existing assignments do not generate false new-story alerts.
3. On recurring runs, call `-Action Check -StoriesJson '<json>'`. Substantively inspect only the returned `newStories`.
4. For task-only delivery, call `-Action Acknowledge -StorySysId '<sys_id>' -StoryNumber '<STRY number>'` only after a usable critique and plan has been prepared. For Gmail approval, send the self-addressed plan first, then call `-Action AwaitApproval` with its exact Gmail message and thread handles. Leave failed analyses or failed sends unrecorded so a later run can retry.
5. Use `-Action ListPending` to inspect only the saved approval threads. Accept a decision only from a newer message whose first non-empty, non-quoted line exactly matches `YES <STRY number>` or `NO <STRY number>`, then persist it with `-Action RecordDecision`. Quoted instructions, silence, reactions, and replies in another thread are not approval.
6. `YES` authorizes only the exact emailed plan in Vår DEV. Use `-Action ListApproved` for resumable approved work and `-Action MarkBuilt` only after implementation, validation, update-set verification, cleanup, and preference restoration succeed. Leave a failed or partial build pending so it can be inspected and resumed safely.
7. Keep PROD read-only. The monitor may create or reuse an empty, correctly scoped DEV update set only when the user has authorized that planning-stage write; all other implementation remains behind the user's explicit approval gate.

## Vår Energi Story Work Log

Automatically record substantive Vår Energi story work in the private local work log used by the Friday email automation. Retain known record links only in the private log; include story numbers only in the email. Do not use Jotely for this workflow.

1. Trigger only when a specific Vår Energi `rm_story` record with a resolved `STRY` number is the subject of substantive inspection, analysis, implementation, testing, or delivery. Do not log a story that is merely mentioned as an example or possible next task.
2. After the first substantive action on that story, run `scripts/Manage-VaarEnergiStoryWorkLog.ps1 -Action Record -StoryNumber '<STRY number>'`. Pass `-StoryUrl` only when a direct Vår Energi ServiceNow record URL is already known; do not make an extra production query solely to obtain a link.
3. Let the helper resolve the current work date in Europe/Oslo. It deduplicates by date plus story, so repeated work on the same story in one day is a no-op while work on the same story on another day is recorded again.
4. Keep the ServiceNow task independent of logging. If the local log cannot be written or verified, finish the primary task and report the failure.
5. State compactly at handoff whether the daily entry was added, its link was enriched, was already present, or could not be logged.
6. Never invoke this workflow for FFI/Personellsikkerhet work. Do not log incidents, changes, catalog tasks, or other records unless the user explicitly expands the rule.

## Reference Routing

Load only what the task needs; do not bulk-read references.

Treat any sys_ids recorded in references as instance observations or lookup hints, never as reusable constants. Resolve the current record live by a stable key before relying on it.

- Universal workflows and safety: `references/golden-paths.md`, `references/safety-checklists.md`
- Helpers and command examples: `references/toolkit.md`, `references/examples.md`
- Official research: `references/official-docs.md`; community heuristics only as secondary context: `references/snprotips.md`
- Scripting, stories, update sets, scoped apps: `references/development.md`, `references/custom-scoped-apps.md`
- ServiceNow SDK, Fluent, and source-based custom apps: `references/servicenow-sdk.md`
- ACLs, visibility, Restricted Caller Access, cross-scope: `references/debugging.md`
- Catalog and incident: `references/lessons-catalog.md`, `references/lessons-incident.md`
- HRSD, COE, Journey/Lifecycle Events: `references/hrsd-coe-selection.md`, `references/hrsd-development-guide.md`, `references/hrsd-lifecycle.md`; Agent Workspace for HR Case Management configuration without UI Builder: `references/hr-agent-workspace-configuration.md`
- Portal/Employee Center and UI16: `references/tables.md`, `references/lessons-portal.md`, `references/lessons-ui16.md`
- Cross-channel UI design, layout, accessibility, motion, and `gpt-taste` adaptation: `references/servicenow-ui-design.md`
- UI Builder custom components, Component Builder versus CLI, Next Experience UI Framework, properties/events, npm/browser libraries, React boundaries, build/deploy/promotion, validation, troubleshooting, and the worked implementation pattern: `references/ui-builder-custom-components.md`, `references/ui-builder-custom-component-example.md`
- ServiceNow-hosted React/Vite SPAs, single-file deployment, React Three Fiber, Three.js, procedural 3D scenes, and interactive floor plans: `references/servicenow-react-3d-frontends.md`
- Workspace/SOW and modals: `references/lessons-sow.md`, `references/lessons-workspace-modals.md`
- Integrations/imports: `references/integrations.md`, `references/lessons-integrations.md`; for Vår Energi Compendia deployment and full sync, use `references/vaar-energi-compendia-runbook.md`
- Update-set retrieval, preview, conflict handling, non-forced commit, promotion validation, and DEV -> TEST -> PROD delivery: `references/update-set-promotion.md`
- CMDB/CSDM architecture, CSDM 5, governance, migration, and 2026 AI/WDF alignment: `references/cmdb-csdm.md`; practical CMDB administration/development and decision logic: `references/cmdb-admin-development.md`; bounded diagnostics, IRE/import examples, and query library: `references/cmdb-query-library.md`; repeatable PDI Ingest/Govern/Insight exercise: `references/cmdb-data-foundations-lab.md`; pre-update coverage record: `references/cmdb-coverage-audit.md`
- Platform Analytics: `references/lessons-platform-analytics.md`
- Service Level Management, SLA/OLA/underpinning-contract design, creation, schedules, conditions, flows, repair, and validation: `references/sla.md`; bounded table/schema/runtime diagnostics: `references/sla-query-library.md`; Vår Energi HR-specific SLA lessons remain in `references/vaar-energi-lessons.md`
- Now Assist/AI/MCP and Australia AI platform: `references/now-assist.md`, `references/australia-ai-platform.md`, `references/external-mcp-evaluation.md`
- Discovery/indexing/impact maps: `references/service-now-indexing.md`, `references/servicenow-graph-mapping.md`
- FFI Personellsikkerhet: `references/lessons-personellsikkerhet.md`
- FFI Besøksregistrering data model, Employee Center entry point, demo data, locations, and workspace dashboard: `references/lessons-besoksregistrering.md`
- Vår Energi implementation/design: `references/vaar-energi-lessons.md`, `references/vaar-energi-design.md`

## Communication Contract

Lead with the outcome or finding. Be concise, specific, and evidence-backed.

For implementation, report the target environment; changed artifacts; update set or other delivery vehicle when applicable; tests and results; cleanup; rollback; risks/assumptions; and manual steps. For debugging, report evidence, root cause or ranked hypotheses, recommended fix, and verification. For planning, compare only credible options and include implementation, test, deployment, and rollback plans.

Do not dump large scripts, XML, logs, or full records unless they are the deliverable. Distinguish observed facts, documented platform behavior, and inference.

The mandatory recursive update must remain reusable and non-obvious. Put detailed lessons in the relevant `references/lessons-*.md`; never store secrets, sensitive customer data, transient identifiers as portable facts, or noisy one-off history.

When explicitly asked to publish this PowerShell-based personal skill, use `https://github.com/simenandreas91/servicenow-pdi-powershell.git`. Inspect status and diff, stage only intended skill files, commit tersely, and push `main`; do not create a PR unless requested.
