# ServiceNow CMDB Administrator and Developer Runbook

## Purpose and authority

Use this runbook with `cmdb-csdm.md` for every CMDB task. This file turns the architecture guidance into an operating method for diagnosis, configuration, ingestion, remediation, and prevention. Load `cmdb-query-library.md` for the referenced `Qxx` scripts.

The baseline is ServiceNow Australia and CSDM 5. Tables, fields, roles, Store-app content, and workspace routes can differ by family, patch, plugin, and app version. Officially documented table names in this guide are safe discovery anchors, not permission to write to internal processing tables. Before scripting an unfamiliar table, run Q00/Q01 and verify it on the target instance.

## Contents

- [Core identification and reconciliation](#1-core-identification-and-reconciliation)
- [Health, visibility, and governance](#2-health-visibility-and-governance)
- [Class and relationship management](#3-class-and-relationship-management)
- [Data management and remediation](#4-data-management-and-remediation)
- [Prevention and remediation decision trees](#5-prevention-and-remediation-decision-trees)
- [PDI-safe exercise pattern](#6-pdi-safe-exercise-pattern)
- [Current live-verification note](#7-current-live-verification-note)
- [Official documentation index](#8-official-documentation-index)

## Mandatory response contract for CMDB work

When answering or executing CMDB work:

1. State the target environment, release/app baseline, requested outcome, consuming workflow, target class, and whether the work is read-only or mutating.
2. Resolve the class and tables live. Inspect the class in CI Class Manager and inspect physical schema with `sys_db_object`/`sys_dictionary`.
3. Trace the data contract in order: source/run -> class/payload -> identification -> reconciliation/provenance -> relationships/dependencies -> health/lifecycle consumers.
4. Prefer CSDM/OOTB classes, documented relationship direction, principal-class scope, Discovery/Service Graph/IH-ETL, and IRE.
5. Give exact encoded queries or bounded scripts, the expected result shape, failure interpretation, and the next decision. UI instructions alone are insufficient.
6. Keep diagnosis read-only. For a fix, preview counts and samples, stop recurrence first, define rollback/recovery, then change one controlled slice.
7. Never create/update automated CIs with direct `GlideRecord`, import coalesce, or a custom upsert. Use IRE. Direct reads of CMDB tables are normal; direct writes are the defect.
8. Do not write to internal result, simulation, workspace, or engine tables. Configure through supported UI/API and query those tables only for evidence.
9. Never assume a named workspace card is the source of truth. Find its underlying governed configuration/result table and collection timestamp.
10. Report observed facts separately from documented behavior and inference. If live proof is blocked, name the exact verification still needed.

## Safe tool and table discovery

Use the bundled helpers relative to the skill directory:

```powershell
& "$skillRoot/scripts/Get-ServiceNowTableShape.ps1" -Profile pdi -Table cmdb_identifier
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi -Table sys_db_object `
  -Query 'nameSTARTSWITHcmdb_^ORlabelLIKECMDB' -Fields 'name,label,super_class' -Limit 50 -ExcludeReferenceLink
```

If a documented UI label has no documented physical name, resolve it rather than guessing:

```text
sys_db_object.list?sysparm_query=labelLIKEHealth Inclusion
sys_dictionary.list?sysparm_query=name=<resolved_table>^active=true
```

Internal/read-mostly tables in this guide include health results, IRE contexts/logs, CMDB 360 raw data, policy executions, and remediation state. Do not add, delete, or modify their rows directly.

## 1. Core identification and reconciliation

### 1.1 Identification Rules

**Purpose and use**

Identification determines whether an incoming item matches one existing CI or should be inserted. Each class can have one effective identification rule, derived from an ancestor until the class defines its own. The rule contains ordered identifier entries. An entry can use fields on the CI, a lookup table referencing `cmdb_ci`, or both. Dependent classes also require a dependency chain.

**Key records**

- Identifier `[cmdb_identifier]`: one rule set per defining class.
- Identifier Entry `[cmdb_identifier_entry]`: prioritized regular, lookup, or hybrid criteria.
- `sys_db_object`, `sys_dictionary`: class hierarchy and field validation.
- Common lookup identity tables include Serial Number `[cmdb_serial_number]`; validate the class model before relying on any lookup table.
- Identification inclusion rules: configure in CI Class Manager. Resolve the physical table live if it is needed for analysis; do not guess it.

**How to work**

1. Inspect the effective rule in CI Class Manager, including whether it is defined or derived.
2. List entries in priority order with Q02. Lower numbers run first; equal priorities are unsafe because evaluation order is not deterministic.
3. For each entry, prove uniqueness against representative source data and existing CIs. Normalize source values before IRE when formatting differences are semantically irrelevant.
4. Use Identification Simulation or the no-commit IRE method in Q04 for match, no-match, missing-attribute, duplicate-match, and dependent-payload cases.
5. Re-run the identical payload. Expected result is the same CI and `NO_CHANGE` or an allowed update, never a second insert.

**Decision rules**

- Reuse the inherited rule when the child has the same real-world identity. Creating a child rule replaces the entire inherited rule for that class, including inherited identifier and related entries; recreate anything still required.
- Create/replace a rule only when the child has materially different identity and representative collision tests prove the need.
- Put the strongest, most stable, broadly populated unique key first. Do not use display names alone.
- Avoid `Allow null attribute` unless remaining populated attributes are independently unique; otherwise it broadens matches.
- Treat reference fields as weak unless the referenced record is consistently resolved and stable across sources.
- Use lookup/hybrid identification only when the related table is governed and has a reliable reference back to the CI.
- Do not configure both lookup identification of a related CI and an independent identifier for that same related data without proving they cannot conflict.

**Failure modes**

- Repeated inserts: weak/missing criteria, normalization differences, wrong target class, missing source-native key, missing dependent relationship, or a transform bypassing IRE.
- False merge: broad nullable criteria, reused serial/name, unknown reference values, inclusion conditions that collapse distinct populations.
- `MISSING_MATCHING_ATTRIBUTES`: payload lacks the minimum populated criterion set; fix mapping/payload, not the CI afterward.
- Multiple matches: existing duplicates or overlapping rules. Stop ingestion, audit the duplicate set, correct the rule/source, then remediate.

Official basis: [Identification rules](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_IdentificationRules.html), [create a rule](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/t_CreateCIIdentificationRule.html).

### 1.2 Reconciliation Rules

**Purpose and use**

Reconciliation decides whether the incoming discovery source may update a CI or an attribute after identity is resolved. Static rules express source authority and priority. Without rules, sources can overwrite one another. Identification correctness must be solved first; reconciliation cannot repair a false match.

**Key records**

- Reconciliation Definition `[cmdb_reconciliation_definition]`: static class/attribute authority.
- Data Source History `[cmdb_datasource_last_update]`: last source update evidence used with refresh behavior.
- Data Source Staleness Definition `[cmdb_datasource_staleness]`: effective duration by source.
- IRE Data Source Rule `[cmdb_ire_data_source_rule]`: insert/update restrictions for a source/class.
- Source `[sys_object_source]`: source-native object identity for IRE-processed records.
- CI `discovery_source`: source value; API source names must be valid choices for this field.
- CMDB 360 Data `[cmdb_multisource_data]`: all reported values when CMDB 360 is enabled.

**How to work**

1. Build an attribute-authority matrix per class: source, attributes, priority, refresh window, insertion rights, missing-source behavior.
2. Inspect defined and inherited static/dynamic rules with Q03 and preview precedence in CI Class Manager.
3. Submit the same CI identity from two safe test sources with conflicting non-sensitive values. Verify the allowed value, rejected value, IRE output, and provenance using Q05/Q06.
4. Test the behavior after the authoritative source exceeds its approved refresh window only if data refresh rules are intentionally used.
5. Segment unexpected overwrites by class, field, source, and timestamp; correct the definition/source contract before repairing values.

**Decision rules**

- Use static rules when source authority is contractual or semantic: HR owns owner, Discovery owns observed OS, asset process owns financial fields.
- Grant authority at the narrowest useful class and attribute set. Avoid one source owning every field on `cmdb_ci`.
- Use one distinct discovery-source choice per integration behavior. Reusing `ImportSet` across unrelated feeds destroys useful authority and provenance.
- Child-class rules override parent rules for the affected attributes. Review inherited consequences before adding a child rule.
- Treat manual updates as a source with explicit allowed fields and roles; do not let admin edits silently defeat governed sources.

**Failure modes**

- Trusted values overwritten: missing rule, wrong source choice, child override, dynamic rule precedence, or refresh behavior.
- Values never update: source is not authorized, higher-priority source still effective, IRE data-source rule blocks it, or payload uses the wrong attribute/class.
- “Correct on form, wrong later”: scheduled feed or Discovery reruns; trace `cmdb_datasource_last_update`, CMDB 360, audit, and source schedule.

Official basis: [Reconciliation rules](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/r_ReconciliationRulesPrinciples.html), [create reconciliation rule](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/create-reconciliation-rule.html).

### 1.3 Identification and Reconciliation Engine (IRE)

**Purpose and use**

IRE is the supported gate for automated CI and relationship ingestion. Use it for custom integrations, Scripted REST, classic imports, test utilities, and Flow actions. Discovery, Service Graph Connectors, and IntegrationHub ETL already route through their supported IRE/RTE paths when correctly configured.

**Key records and APIs**

- Global API: `SNC.IdentificationEngineScriptableApi.createOrUpdateCI(source, json)` and no-commit identification methods.
- Scoped API: `sn_cmdb.IdentificationEngine` methods such as `createOrUpdateCIEnhanced`/`identifyCIEnhanced`; verify signature for the target family.
- Simulation: `[cmdb_ie_context]`, `[cmdb_ie_run]`, `[cmdb_ie_log]` are internal evidence tables.
- Partial/incomplete evidence: `[cmdb_ire_partial_payloads]`, `[cmdb_ire_partial_payloads_index]`, `[cmdb_ire_incomplete_payloads]`.
- RTE/import evidence: `[cmdb_ire_output_aggregate_stats]`, `[cmdb_ire_output_target_item]` when detailed stats are requested.
- Source/provenance: `[sys_object_source]`, `[sys_rel_source]`.

**Payload contract**

- `items[]`: `className`, `values`, optional `display_values`, `internal_id`, `lookup`, `related`, `settings`, and `sys_object_source_info`.
- `relations[]`: parent/child indexes or internal IDs plus an exact `cmdb_rel_type.name` value and optional relationship source information.
- `referenceItems[]`: references between payload items.
- `source`: a valid `cmdb_ci.discovery_source` choice, not an arbitrary integration label.
- Use source-native keys and feed names for stable provenance, but do not assume they replace class identifier rules.

**How to work**

1. Validate class, fields, source choice, relationship type, and identification rule before calling IRE.
2. Run Q04 no-commit identification or Identification Simulation first. Capture operation, attempts, warnings, errors, partial/incomplete counts, and relation results.
3. For an approved PDI/DEV mutation, use the guarded Q05 pattern. Parse output; never treat HTTP 200 or a returned string as success without inspecting item errors.
4. Re-run identical input to prove idempotency.
5. Test a conflicting source and an invalid/missing criterion payload.
6. Correlate unexpected results to Q02/Q03/Q06 and IRE logs. Do not edit engine result tables.

**Failure modes**

- `INSERT_AS_PARTIAL`: recoverable missing context may match later; fix sequencing/dependencies and monitor the partial table.
- `INSERT_AS_INCOMPLETE`: irrecoverable payload error retained for short diagnostic rotation; fix payload/mapping and replay from source.
- Relationship missing: wrong direction/type, absent dependent item, invalid item indexes/internal IDs, or dependency rule mismatch.
- Unexpected class change: IRE reclassification matched identity across classes; follow section 3.2.
- Direct writes have no `sys_object_source`: find and replace the bypass path rather than backfilling provenance cosmetically.

**Decision rules**

- Prefer the platform ingestion hierarchy: Discovery or certified Service Graph Connector, then IH-ETL/RTE, then a narrow custom IRE integration.
- Use `identifyCI`/Identification Simulation for diagnosis and tests; use `createOrUpdateCI` only in an authorized ingestion path with parsed result handling.
- Keep one stable discovery-source identity per authority contract. Do not use an arbitrary label or share one choice across unrelated feeds.
- Send related/dependent items in one coherent payload when identity depends on their relationship; do not repair a rejected payload with direct writes.

**Scripted REST / Flow pattern**

Expose a narrow Script Include or Flow action that validates an allowlisted class and fields, validates the caller, builds the IRE payload, calls IRE, parses results, and returns `{operation, sysId, warnings, errors, correlationId}`. Consequential or multi-record actions belong in a subflow with approval/retry/dead-letter handling. Never expose a generic arbitrary-class/arbitrary-field IRE proxy.

Official basis: [IRE](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/ire.html), [IdentificationEngineScriptableApi](https://www.servicenow.com/docs/r/api-reference/server-api-reference/c_IdentEngineScriptAPI.html).

### 1.4 Dynamic Reconciliation Rules

**Purpose and use**

Dynamic Reconciliation is not Dynamic IRE. It chooses an attribute value from all reported CMDB 360 values using strategies such as largest reported or most reported value, rather than fixed source priority.

**Key records**

- Dynamic Reconciliation Definitions `[cmdb_dynamic_reconciliation_definition]`.
- CMDB 360 Data `[cmdb_multisource_data]`.
- Enabling property `glide.identification_engine.multisource_enabled` plus applicable CMDB/non-CMDB capture properties.

**How to work**

1. Confirm CMDB 360 is enabled and collecting the target class/attribute.
2. Query the candidate values and sources with Q07; define what tie/fallback behavior means for the business field.
3. Create only one dynamic rule per class attribute and preview it in CI Class Manager.
4. Replay controlled conflicting payloads; confirm selected value and fallback behavior when values tie or timestamps are absent.
5. Monitor CMDB 360 volume and deny only classes with no provenance/dynamic-reconciliation need.

**Decision rules**

- Prefer static reconciliation for ownership, lifecycle, security, support, or other semantically authoritative attributes.
- Use dynamic rules only when aggregation across sources is the actual business rule and CMDB 360 coverage is reliable.
- A dynamic rule takes precedence over a static rule on the same attribute at the same class level.
- IRE data-source rules and data refresh rules do not govern an attribute while a dynamic reconciliation rule is in effect.
- A child static rule can override a parent dynamic rule because child-class rules override inherited parent behavior; verify preview output.

**Failure modes**

- Unexpected winner: incomplete CMDB 360 coverage, stale source timestamps, tie fallback, or child-class override.
- No dynamic-rule option: CMDB 360 disabled, unsupported attribute type, existing dynamic rule, or new child class not yet saved.
- Performance/storage growth: too many noisy classes; review `[cmdb_multisource_deny_class]` and coverage threshold behavior.

### 1.5 CMDB reconciliation operating process

**Purpose and use**

Use this process to design, diagnose, or govern the complete path from source report to the current CI value. The evidence chain is source/run -> IRE payload -> identifier -> static/dynamic authority -> provenance/freshness -> relationship and lifecycle consumers.

**Key records and practical query**

Use Q02/Q03 for effective identity and authority, Q06/Q07 for source-native and all-reported-value evidence, and Q08 for downstream health. The core tables are `cmdb_identifier*`, `cmdb_reconciliation_definition`, `cmdb_dynamic_reconciliation_definition`, `sys_object_source`, `cmdb_multisource_data`, and the target CI/relationship tables.

Use this end-to-end loop instead of treating reconciliation as a one-time rule setup:

1. Inventory every automated/manual source by class, feed, schedule, owner, source-native key, and lifecycle signal.
2. Establish identity first with collision tests and idempotent reruns.
3. Establish insertion rights using IRE data-source rules where needed.
4. Establish static or justified dynamic attribute authority.
5. Establish freshness and missing-source behavior; distinguish data refresh from CI staleness and retirement.
6. Establish relationship authority and deletion behavior.
7. Test insert, update, conflict, no-change, incomplete, partial, duplicate, reclassification, and relationship cases.
8. Monitor source runs, IRE output/errors, duplicate recurrence, overwritten fields, and CMDB 360/provenance gaps.
9. Fix the earliest broken contract, replay safely, then remediate existing records.

**Decision rules and failures**

- Change identity only for real-world uniqueness defects; change reconciliation only for authority defects. Never use one to mask the other.
- A correct one-off form edit followed by regression indicates an upstream authority/schedule problem; trace the next run instead of repeating the edit.
- If evidence diverges between CMDB 360, `sys_object_source`, and the CI, verify capture properties, direct-write bypasses, child-class overrides, and collection timestamps before remediation.

## 2. Health, visibility, and governance

### 2.1 CMDB Health Dashboard and raw data

**Purpose and score meaning**

- Completeness: required (dictionary mandatory) and recommended fields populated.
- Correctness: duplicate, orphan, and stale evaluations.
- Compliance: most recent applicable audit/certification evidence; it is empty/misleading if audits are not active.
- Relationships: duplicate, orphan, stale, and governance conformance including suggested, hosting, and containment rules.

Scores are aggregations over a scoped denominator. A rising score can reflect changed inclusion, max-failure cutoffs, or stale collection rather than better data. Treat `failed` and `total` as the authoritative raw values. On the verified Australia Patch 1 PDI, `cmdb_health_scorecard.score` stored the failure percentage (`1/3 -> 33`, `1/7 -> 14`), while a dashboard may present the complementary healthy percentage. Reconfirm the widget calculation on the current family instead of labeling the raw `score` field as health without checking it.

**Key records**

- `[cmdb_health_metric]`: enabled KPI/metric settings and maximum failure thresholds.
- `[cmdb_health_result]`: latest cycle failures/details.
- `[cmdb_health_scorecard]`: current and historic scores.
- `[cmdb_health_metric_status]`, `[cmdb_health_processor_status]`: processing state, timeout, class progress.
- `[cmdb_health_orphan_rule]`, `[cmdb_recommended_fields]`: test definitions.
- `[cmdb_health_result_rel_all]`: relationship-health result store.
- Scheduled jobs named `CMDB Health Dashboard - ... Score Calculation` and the Relationship Compliance Processor.

**How to work**

1. Use Q08 to inspect metric configuration, last scorecards/results, processing status, and table fields before relying on the UI.
2. Record principal classes/services/health groups, numerator, denominator, exclusions, metric max-failure threshold, collection timestamp, and timed-out classes.
3. Sample failed CIs and verify against source and consuming workflow.
4. Group failures by class, source, owner, lifecycle, age, and same missing field/rule.
5. Fix source/rule/process root cause, rerun or await the correct job, then compare unchanged scope and raw failure count.
6. In a PDI, leave inactive OOTB schedules inactive. After scoping the denominator, use **Execute Now** on the exact `CMDB Health Dashboard - Completeness Score Calculation` and `... Correctness Score Calculation` records. If the action produces no status rows, run the exact job entry points shown on those records, then query processor state:

```javascript
SNC.MetricProcessorScript.completenessManager();
SNC.MetricProcessorScript.correctnessManager();
```

These managers enqueue class processors and can touch the wider CMDB. Configure inclusion rules, record baseline counts, and run them only in an authorized PDI or maintenance window.

**Decision rules**

- Publish critical-service/principal-class scores separately; never use one global percentage as the control.
- Recommended is preferred for progressive governance. Dictionary mandatory can block multiple creation channels and requires broader regression testing.
- Configure only fields with an owner, trusted source, consumer, acceptable value, and freshness expectation.
- Treat `MaxFailures` and daily timeout as incomplete processing, not as a valid low/high score.
- A CI can fail multiple metrics; do not sum health result rows as unique CI count without deduplication.

**Failure modes**

- Empty dashboard: jobs not enabled/run, no recommended fields, audits inactive, role/domain issue, or wrong scope.
- Misleading duplicate score: independent classes only, identification inclusion rules alter the population, or max-failure threshold reached.
- Stale relationship count: either endpoint is stale; correct endpoint lifecycle/source before deleting edges.

Official basis: [CMDB Health overview](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/overview-cmdb-health.html), [KPIs and metrics](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/r_CMDBHealthMetrics.html), [installed components](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/r_TablesInstalledCMDBHealth.html).

### 2.2 Health inclusion rules

**Purpose and use**

Health inclusion rules filter which CIs are evaluated for required, recommended, duplicate, orphan, and staleness metrics. They are temporary/governed scope controls, not a way to hide bad data indefinitely.

**Key behavior**

- Configure through CI Class Manager -> Health -> Health Inclusion Rules.
- Fields are Applies to, Active record condition, and Applies to metric.
- No base rules means all CIs are included.
- Parent rules apply to a child only when the child has no own rule; a child rule takes precedence.
- A rule on `cmdb_ci` can affect the entire hierarchy.
- Duplicate-metric rules are global-domain only and do not support dot-walking for performance reasons.
- Identification inclusion rules also change duplicate-health evaluation.
- Australia Patch 1 live validation identified Health Inclusion Rule `[cmdb_health_config]` with `metric`, `active_record_condition`, and `applies_to`. Resolve it again by label/schema after an upgrade or on another family.

**How to work**

1. Baseline counts without the proposed rule.
2. Write the condition as a class-local, indexed/selective encoded query. Avoid dot-walk for duplicate; avoid broad parent-class exclusions.
3. Count and sample included and excluded records directly on the CI class with Q09.
4. Document business reason, owner, metrics, affected hierarchy, expiry/review date, and expected denominator.
5. Save through CI Class Manager, run the relevant job, and verify raw health results plus denominator.

**Decision rules and failures**

- Exclude retired or deliberately ephemeral populations only when lifecycle/source governance supports it.
- Do not exclude a failing source/class solely to improve a score; create a time-bound exception and remediation plan.
- If a metric disappears unexpectedly, inspect child override, domain, identification inclusion (duplicate), invalid field names, and job refresh.

Official basis: [Create health inclusion rule](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/create-health-inclusion-rule.html).

### 2.3 CMDB 360 / CMDB 360 View

**Purpose and use**

CMDB 360 retains the reported values from every source/CI combination, including values not selected by reconciliation. Use it for provenance, conflicts, coverage gaps, dynamic reconciliation, and recompute—not as a second CMDB.

**Key records/properties**

- Raw store `[cmdb_multisource_data]`; column metadata `[cmdb_multisource_column_metadata]`.
- User queries/status/results: `[cmdb_multisource_query]`, `[cmdb_multisource_query_status]`, `[cmdb_multisource_query_result]`, `[cmdb_multisource_query_result_ms_record]`, `[cmdb_multisource_query_result_disco_source]`.
- Recompute: `[cmdb_multisource_recomp_task]`, `[cmdb_multisource_recomp_task_ci]`.
- Denied classes `[cmdb_multisource_deny_class]`; a record excludes the class and descendants and existing raw data is gradually cleaned.
- Coverage-only skipped classes `[sn_cmdb_ws_ms_skip_class]`; this affects workspace charts, not raw capture in the same way.
- Enablement: `glide.identification_engine.multisource_enabled` and CMDB/non-CMDB capture properties.
- Logs: `syslog^source=cmdb_multisource` when the logging property is enabled.

**How to work**

1. Verify properties and denied classes before calling a provenance gap a source failure.
2. Use Q07 for a specific CI/attribute and compare reported value, source, and timestamps.
3. Compare raw CMDB 360 coverage with `sys_object_source`, CI `discovery_source`, and current CI value.
4. Use supported recompute only after a rule/source change and within configured limits; monitor recompute tasks.

**Failure modes**

- UI chart omits a high-volume class: inspect `[sn_cmdb_ws_ms_skip_class]` and threshold property.
- Raw source absent: class denied, capture disabled, direct CMDB write, pre-CMDB-360 history, or feed bypassing IRE.
- Storage growth: exclude only classes with no provenance/dynamic rule need; understand descendant effect and cleanup lag.

**Decision rules**

- Enable/retain raw capture for classes where provenance, conflict analysis, or dynamic reconciliation has a named consumer.
- Deny a class only after measuring storage and proving no such consumer; a deny record affects descendants and triggers asynchronous cleanup.
- Recompute through supported CMDB 360 controls after a rule/source correction. Do not update `cmdb_multisource_data` directly.

Official basis: [CMDB 360](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/multisource-cmdb.html), [components](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/components-multisource-cmdb.html).

### 2.4 CMDB Workspace and Service Graph Workspace

**Purpose and use**

Use workspaces as consolidated human surfaces for class/CI exploration, health, CMDB 360, de-duplication, Data Manager, integrations, and governance. Australia direction favors Service Graph Workspace for consolidated governance; verify installed Store version and role.

**Key records and practical query**

Workspace cards surface records already described in this guide: `cmdb_health_*`, `cmdb_multisource_*`, `cmdb_data_management_*`, `reconcile_duplicate_task`, and class configuration such as `sn_cmdb_ws_ci_class_config`. Run Q00/Q01 and the relevant Q07-Q20 query before blaming the UI. Inspect installed plugin/app/version through `sys_plugins`/Store application records and inspect ACLs in the user context.

**Diagnostic rule**

For every workspace symptom, identify the underlying layer:

1. Data/configuration table (for example `cmdb_health_result`, `cmdb_multisource_data`, `reconcile_duplicate_task`).
2. Collector/job/execution state.
3. Workspace Store app version, configuration identifier, UX route/card, role/ACL/domain.
4. Browser/network/rendering only after the data layer is proven.

The create-CI class list uses workspace configuration, including `[sn_cmdb_ws_ci_class_config]`; this is not the same as Principal Class. Do not edit workspace-owned/internal records unless the supported configuration route requires it.

**Failure modes**

- Empty card but populated table: collection/app version/ACL/filter issue.
- Different classic/workspace counts: distinct scope, aggregation time, domain, or skipped-class behavior.
- CI not creatable in Workspace: class configuration identifier, rule/class support, or role; do not bypass by direct insert.

**Decision rules**

- Use the workspace for supported configuration and human workflow; use underlying tables for bounded evidence and automation-safe diagnostics.
- Do not write internal UX/card state or result rows to make a widget look correct. Correct the collector/configuration, ACL, Store version, or governed source record.
- When classic and workspace totals differ, compare encoded scope, domain, skipped-class configuration, and collection timestamps before escalating a UI defect.

### 2.5 Principal Class

**Purpose and use**

Principal classes focus CI pickers, class lists, health/governance, and Success Advisor on operationally important classes. The designation is stored in CMDB Class Information `[cmdb_class_info]`. It does not inherit to child classes.

**Key records/properties**

- `[cmdb_class_info]`; resolve the principal boolean and class/table reference fields live with Q10.
- `com.snc.task.principal_class_filter`: task types whose `cmdb_ci` field uses principal filtering; base value includes incident/problem/change task types.
- Success Advisor maintains its own scope and can become out of sync with class designation.

**How to work**

1. Run Q10 to list `cmdb_class_info.principal_class=true` and the task-filter property.
2. Compare those classes with actual task CI usage, critical-service membership, health scope, and ownership.
3. Change the designation through CI Class Manager, then test the picker as the intended non-admin user and recheck Success Advisor scope.

**Decision rules**

- Mark a class principal only if its CIs are valid operational selections or a governed quality/lifecycle scope.
- Start from classes used by named Incident/Problem/Change and service-impact workflows, not every populated class.
- Mark each required child explicitly; parent designation does not cover descendants.
- Verify picker behavior and Success Advisor sync after change.

**Failure modes**

- Valid CI missing from task picker: class not principal, task type property, reference qualifier/ACL/domain, or wrong operational class.
- Too much picker noise: overly broad principal list, base/abstract class marked, or inappropriate Business Application use.

Official basis: [Principal Class](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/principal-class-filter.html).

### 2.6 Life Cycle Mapping (`life_cycle_mapping`)

**Purpose and use**

Life Cycle Mapping converts legacy status values (`install_status`, `operational_status`, hardware status/substatus, and supported equivalents) to standard CSDM `life_cycle_stage` + `life_cycle_stage_status` pairs. It is separate from Data Manager retirement definitions.

**Key records/properties**

- Life Cycle Mapping `[life_cycle_mapping]`: mapping table/class, priority, active, legacy field/subfield/value, and target life-cycle control/pair.
- Life Cycle Control `[life_cycle_control]`: valid class/stage/status combinations.
- CI fields `life_cycle_stage`, `life_cycle_stage_status` plus class-specific legacy fields.
- `csdm.lifecycle.sync.between.ci.and.asset.activated`: enables ongoing CI/asset lifecycle synchronization after reviewed activation.

**How to work**

1. Inventory actual legacy value counts by class with Q11.
2. Query active mappings in priority order and detect unmapped values/overlaps.
3. Confirm target pairs exist in `life_cycle_control` for the intended class hierarchy.
4. Test representative CI-only and linked asset/CI records in PDI/DEV.
5. Before enabling sync, snapshot counts by legacy and standard values and review asset/CI direction behavior.
6. After enablement, compare counts, exceptions, and unintended reverse changes.

**Decision rules**

- Reuse OOTB mappings unless a real custom legacy value lacks a correct mapping.
- Lowest numerical priority wins when multiple legacy fields match; design priorities intentionally.
- A child-table mapping overrides applicable parent mapping for that table.
- Do not enable global sync until every in-scope legacy value has a reviewed mapping or explicit expected `TBD` outcome.
- Life-cycle controls aggregate from parents; extra inherited stage choices can be technically valid but semantically wrong for Business Applications. Govern by class/process.

**Failure modes**

- Standard fields become `TBD`: no usable mapping, inactive/high-priority mismatch, or invalid target control.
- CI and asset oscillate: conflicting sync/legacy ownership or ambiguous reverse mapping.
- Unexpected pair chosen: multiple matching legacy fields and misunderstood priority.

Official basis: [Life cycle mapping form](https://www.servicenow.com/docs/r/servicenow-platform/common-service-data-model-csdm/csdm-life-cycle-mapping-form.html), [standard values and synchronization](https://www.servicenow.com/docs/r/servicenow-platform/common-service-data-model-csdm/csdm-life-cycle-standard-values.html).

## 3. Class and relationship management

### 3.1 CI Class Manager

**Purpose and use**

CI Class Manager is the supported class-level control surface. Use it before creating a class, adding fields, or changing identity/health/relationships.

**Key records and practical queries**

Resolve the class hierarchy and attributes in `sys_db_object`/`sys_dictionary`, class governance in `cmdb_class_info`, and the feature-specific tables in sections 1-3. Run Q00-Q03 and Q09-Q13 for machine-readable evidence; make supported changes through CI Class Manager.

**Class review checklist**

1. Basic Info: table, label, parent, description, principal designation, population volume.
2. Attributes: inherited vs defined fields, data types, indexes, mandatory/recommended use, custom-field consumers.
3. Identification: effective rule, entries, inclusion rule, related entries, derivation.
4. Reconciliation: static/dynamic rules, refresh, IRE source restrictions, inheritance.
5. Dependent Relationships: hosting/containment rules and dependency chain.
6. Suggested Relationships and relationship governance.
7. Health: recommended, orphan, stale, inclusion, audits, thresholds/jobs.
8. Lifecycle: life-cycle controls/mappings and retirement definition.
9. Population/consumers: Discovery patterns, connectors, transforms, reports, ACLs, tasks, maps.
10. Test matrix and delivery: insert/update/conflict/duplicate/reclass/dependency plus rollback.

Use Q00-Q03 and Q10-Q13 to obtain machine-readable evidence; use CI Class Manager for supported edits. A custom class is approved only when no OOTB class matches meaning, identity, lifecycle, and consuming-product behavior.

**Decision rules and failures**

- Reuse an OOTB class when its semantics, identity, lifecycle, and product support fit. Create a child only for a durable subtype with distinct fields/rules/consumers; never create a parallel near-duplicate class for one feed.
- A missing tab/option usually means derived configuration, unsaved/new class state, plugin/app version, role/ACL, or an unsupported class—not permission to edit internal metadata directly.
- Before changing a parent, count descendants and preview inherited identification, reconciliation, health, lifecycle, and relationship effects.

### 3.2 CI class switch, upgrade, and downgrade

**Purpose, use, and definitions**

- Upgrade: move to a descendant/more specific class.
- Downgrade: move to an ancestor/more general class; child-only attributes are lost.
- Switch: move to another branch; effectively downgrade plus upgrade and can lose attributes.

The CI retains its `sys_id`, but the target hierarchy row is changed. Reclassification is possible only when source and target classes have identical identification rules.

**Key records/properties**

- Reclassification Task `[reclassification_task]`.
- Reclassification Restrictions `[cmdb_ire_reclassification_restriction]` for directional downgrade/switch protection.
- Global enablement: `glide.class.upgrade.enabled`, `.downgrade.enabled`, `.switch.enabled` (base true).
- Update-without-class-change controls: `glide.identification_engine.update_without_upgrade_enabled`, `_downgrade_`, `_switch_` (base false and take precedence).
- Restriction enablement: `glide.identification_engine.reclassification_restriction_rules_enabled` (base true).
- Payload controls: `classUpgrade`, `classDowngrade`, `classSwitch`, `updateWithoutUpgrade`, `updateWithoutDowngrade`, `updateWithoutSwitch`, and guarded `skipReclassificationRestrictionRules`.

**How to work**

1. Run Q12 to compare source/target hierarchy and fields; export class-only values, tasks, asset, relationships, and source mappings.
2. Confirm identical identification rules and simulate the IRE payload.
3. Prefer upgrade. Avoid downgrade/switch unless the semantic class is wrong and data-loss/consumer migration is approved.
4. Add directional restriction rules when a connector/source can mistakenly downgrade or switch CIs. Two rules are required to block both directions.
5. Test one representative CI in non-production. Verify retained `sys_id`, fields, `sys_class_name`, relationships, task/asset references, reports, ACLs, and next ingestion run.
6. For manual/bulk migration, use a supported reclassification approach and bounded wave; never run `gr.setValue('sys_class_name', ...)` as a generic fix script.

**Failure modes**

- Lost fields: downgrade/switch removed source-class-only data; restore from snapshot and correct ingestion/class mapping.
- CI repeatedly reclassifies: sources send different target classes; correct class mapping and add restriction/update-without controls.
- Reclassification task created: global class operation disabled or payload rejected; review rather than forcing.

**Decision rules**

- Upgrade when new evidence proves a more specific correct class and identifiers are compatible.
- Downgrade/switch only to correct semantic misclassification with an approved loss/consumer plan; prefer preventing the class change with restrictions when feeds disagree.
- Never reclassify in bulk until one CI survives the next authoritative ingestion and downstream task, asset, relationship, ACL, report, and service-impact checks.

Official basis: [Configure reclassification](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_CIReclassification.html), [Reclassify a CI](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/t_ManuallyReclassifyCI.html).

### 3.3 Dependent Relationships

**Purpose and use**

A dependent CI cannot be uniquely identified without one parent/container CI and an allowed dependency relationship. IRE identifies the dependency chain in parent-first order. This is identity metadata, not merely map decoration.

**Key records**

- Actual relationships `[cmdb_rel_ci]`; relationship types `[cmdb_rel_type]`.
- Hosting metadata `[cmdb_metadata_hosting]`; containment metadata `[cmdb_metadata_containment]`.
- Partial payloads often expose missing/out-of-order dependency context.
- Data Manager dependency evidence: `[cmdb_dependent_ci_ledger]`, `[cmdb_dependent_ci_class_exclusion]`, `[cmdb_dependent_ci_extra_rels_config]`.

**How to work**

1. Confirm the class has a dependent identification rule and dependency metadata.
2. Build one payload containing the dependent item, parent/container items, and correct relations. Use Identification Simulation to generate/validate structure.
3. Serialize many dependent writes sharing one parent to avoid contention.
4. Query missing dependency edges with Q13; distinguish IRE-dependent orphan from the broader CMDB Health orphan concept.

**Decision rules/failures**

- Use dependency only when parent context is part of real identity, not merely useful topology.
- Do not delete dependent relationships directly; repair source/metadata/payload.
- Classic `CMDBTransformUtil` import handling does not support dependent CIs; use IH-ETL/RTE or an explicit IRE payload with relationships.
- Duplicate dependent CIs usually mean the parent relation was omitted, reversed, late, or mapped to the wrong class/type.

### 3.4 CI Relationships

**Purpose and records**

`[cmdb_rel_ci]` stores directional parent/type/child edges. `[cmdb_rel_type]` stores both descriptors. `[sys_rel_source]` can store source/freshness for non-dependent relationships when enabled. `[cmdb_rel_type_suggest]` stores suggested class relationships.

**How to work**

1. State the business question and required direction before adding an edge.
2. Resolve the exact `cmdb_rel_type.name`; do not create a synonym because the display phrase feels better.
3. Prefer the producing integration/Discovery/Service Mapping payload through IRE. For a governed manual exception, use the supported editor/Unified Map and record owner/review date.
4. Use Q14 for duplicate/orphan edges, Q15 for provenance, and Q16 for bounded graph traversal.

**Decision rules**

- Use a reference field for ownership/classification; use `cmdb_rel_ci` for traversable topology/dependency.
- Match Discovery direction for infrastructure. `Depends on::Used by` means the parent depends on the child.
- Add an edge only when a named workflow/report/control consumes it.
- Never run an unbounded recursive traversal in a transaction; cap depth, node count, classes, and relationship types.

**Failure modes**

- Duplicate edges: same parent/child/type/port from multiple paths; fix emitting sources then merge/delete exact duplicates with approval.
- Orphan edge: endpoint missing due to direct delete/archive/import defect; determine recovery/retention before removal.
- Relationship reappears: Discovery/Service Mapping/source still asserts it.

### 3.5 Hosting and Containment Rules

**Purpose and distinction**

- Hosting rules (`[cmdb_metadata_hosting]`) are flat valid hosted/hosting pairs, usually software running on hardware/resources. A hosting rule implicitly supports its reverse.
- Containment rules (`[cmdb_metadata_containment]`) form chained configuration hierarchies for logical contained objects and can include inbound/outbound endpoints.

Both are dependent relationship rules used by IRE and Service Mapping. The same relationship type can appear in either; context distinguishes the rule.

**How to work**

1. For a simple class rule, use CI Class Manager -> Dependent Relationships. Use Metadata Editor only for grouped chains/endpoints.
2. Query metadata and actual edges with Q13/Q17.
3. Validate a generated dependent payload and a Service Mapping discovery.
4. Check relationship-health conformance after collectors run.

**Rule constraints**

- A class that is a child in containment cannot also be a hosting participant/root in conflicting ways.
- A containment root cannot be a child in a hosting rule.
- Hosting loops are invalid.
- Do not create a dependency rule until the class has a dependent identification rule.

**Failure modes**

- Dependent CI duplicates/partials: missing or conflicting rule chain.
- Service map omits contained CI: metadata direction/chain/always-include/endpoints or pattern output mismatch.
- Relationship health flags valid-looking edge: actual direction/type does not conform to inherited governance metadata.

Official basis: [Dependent rules](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_ServiceRulesMetadata.html), [create rules](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/create-dependent-relationship.html), [CI relationships](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_CIRelationships.html).

## 4. Data management and remediation

### 4.1 CMDB Data Manager

**Purpose and use**

Use CMDB Data Manager for governed bulk retire, archive, delete, attestation, certification, related-entry cleanup, and dependent-CI handling. A policy is a controlled lifecycle workflow, not a substitute for correcting source behavior.

**Key records**

- Policy `[cmdb_data_management_policy]` and policy type `[cmdb_policy_type]`.
- Execution `[cmdb_data_management_policy_execution]`; runtime state `[cmdb_data_management_policy_runtime_attributes]`.
- Task `[cmdb_data_management_task]`; CI/task association `[cmdb_data_management_task_to_ci]`; documents association `[cmdb_data_management_task_to_document]`.
- Exclusions `[cmdb_policy_ci_exclusion_list]`; scheduled policy records `[cmdb_policy_scheduled_job]`.
- Retirement definitions `[cmdb_retirement_custom_definitions]`.
- Dependent ledgers/configuration listed in section 3.3.
- Archive processing also relies on platform archive components and scheduled job state.

**How to work**

1. Fix source health and stop recreation first.
2. Confirm an active retirement definition for each class targeted by Retire/Archive/Delete.
3. Create policy inactive/draft through Workspace; specify class/filter, exclusions, owner/Managed by Group, approval, schedule, subflow, dependency behavior, and retention.
4. Preview exact count and samples; inspect assets, open tasks, services, relationships, and dependent CIs.
5. Run one bounded non-production execution and monitor Q18 tables/tasks.
6. Verify post-state and source does not recreate CIs. Archive has a restoration window; Data Manager delete is not a rollback mechanism.

**Decision rules**

- Retire when historical visibility is still operationally useful.
- Archive only after the CI meets its retirement definition and retention/restore behavior is approved.
- Delete only when no operational/audit need remains and recovery is separately planned.
- Use attestation for human knowledge; use certification for field-value evidence.
- Never publish a base-`cmdb_ci` policy without proving descendant scope.

**Failure modes**

- Tasks assigned to admin/unowned: missing Managed by Group/ownership design.
- Policy selects zero/unexpected CIs: retirement definition derivation, filter, exclusions, domain, or lifecycle mismatch.
- CIs return: source pipeline remains active or missing-source behavior is wrong.
- Orphan dependent growth: dependency chain/exclusion/ledger processing issue.

Official basis: [CMDB Data Manager](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/cmdb-data-management.html), [components](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/components-cmdb-data-manager.html).

### 4.2 Duplicate CI Remediator

**Purpose and use**

Use the supported remediator to select the main CI, choose surviving attribute values, redirect relationships/related references, and mark duplicates. Never emulate a merge with direct delete/update scripts.

**Key records**

- Task `[reconcile_duplicate_task]`; members/evidence `[duplicate_audit_result]`.
- Wizard state/run `[cmdb_duplicate_ci_remediation]`.
- Analytics snapshot `[reconcile_duplicate_task_data]`.
- Related-table behavior `[reconcile_duplicate_related_table_config]`.
- Template library `[sn_cmdb_ws_reconcile_duplicate_template_library]` and suggested-task mapping `[sn_cmdb_ws_reconcile_duplicate_template_suggested_task]`.
- CI `duplicate_of` is set on merged duplicates by supported remediation.

**How to work**

1. Use Q19 to group open tasks by class/source/identifier pattern. Stop recurrence first.
2. For one task, inspect all `duplicate_audit_result` members plus assets, tasks, relationships, source/native keys, lifecycle, and current discovery.
3. Choose main CI using authoritative identity/current source and downstream reference evidence—not simply oldest record.
4. Preview attribute, relationship, and related-record selections in the wizard.
5. Run one task; monitor `[cmdb_duplicate_ci_remediation]` status/results.
6. Verify Q20: duplicate markers, redirected task/asset/relationship references, main CI values, no orphan/duplicate relationships, and next source rerun.

**Decision rules/failures**

- A duplicate template is justified only after multiple reviewed tasks share the same deterministic safe choice logic.
- Now Assist recommendations are advisory; human review remains required for merge/reclassification.
- Do not casually alter `reconcile_duplicate_related_table_config`; disabling workflow can bypass business protections and must be tested table by table.
- Remediated duplicates can reappear in tasks unless recurrence is fixed and identification inclusion/skip behavior is correct.

Official basis: [Duplicate remediation](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/de-duplication-tasks.html), [installed components](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/components-installed-with-dup-ci.html).

### 4.3 Import Sets and Transform Maps for CMDB

**Purpose and use**

Prefer IntegrationHub ETL/RTE for structured CMDB integrations. Use classic Import Sets only for bounded/legacy feeds and explicitly route every row through IRE.

**Key records**

- Data Source `[sys_data_source]`, Import Set `[sys_import_set]`, staging table, Transform Map `[sys_transform_map]`, field maps `[sys_transform_entry]`, transform history/log/error records (resolve installed schema live).
- IRE/RTE output `[cmdb_ire_output_aggregate_stats]`, `[cmdb_ire_output_target_item]` where applicable.
- API `CMDBTransformUtil` in an onBefore Transform Script.

**Required classic pattern**

Use Q21. The script must set the intended source, call `identifyAndReconcile(source, map, log)`, set `ignore = true` so the transform does not also insert directly, and log parsed output/errors without sensitive payloads.

**Restrictions and decisions**

- Associate the import set with one transform map when using `CMDBTransformUtil`.
- `CMDBTransformUtil` does not support dependent CIs; use IH-ETL/RTE or explicit multi-item IRE payloads.
- It does not make missing mandatory values acceptable.
- A transform `coalesce` is not CMDB identity and must not be the upsert strategy.
- Resolve references deterministically; invalid display values can become `Unknown` and create duplicate identity.
- Map each row to the most specific correct class; never dump diverse inventory into `cmdb_ci`.

**Test sequence**

1. Load a small staged file; validate rows before transform.
2. Run in PDI/DEV; reconcile row counts: staged, ignored-by-transform-after-IRE, inserted, updated, unchanged, partial, incomplete, errored.
3. Rerun identical data and expect no new CI inserts.
4. Submit conflicting source values and a missing identifier.
5. Verify `sys_object_source`, IRE output, target class, relationships, and cleanup of temporary import data.

**Failure modes**

- Duplicate insert on rerun: transform still performs its normal insert, wrong/missing source-native identity, weak identifier, or inconsistent normalization.
- Row says ignored but no CI: `ignore=true` is expected after the IRE call; inspect `CMDBTransformUtil` error/output and IRE logs before treating it as skipped data.
- Wrong class/reference: source mapping or reference resolution defect; correct staging/mapping and replay through IRE rather than editing the CI.

Official basis: [Applying IRE to Import Sets](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/identification-import-sets.html), [CMDBTransformUtil](https://www.servicenow.com/docs/r/api-reference/server-api-reference/c_CMDBTransformUtilAPI.html).

### 4.4 Discovery

**Purpose and use**

Discovery observes infrastructure and running applications, executes through MID Servers/patterns/probes, classifies results, and sends CI/relationship payloads through IRE. It should be the authority for observed runtime facts, not ownership or portfolio semantics.

**Key evidence**

- Discovery schedule/range records, Discovery Status `[discovery_status]`, Discovery Log `[discovery_log]`, device history where installed, ECC Queue `[ecc_queue]`, MID Server `[ecc_agent]`, pattern execution logs, IRE logs/output, target CIs and relationships.
- Do not query credential values. Confirm only credential type/affinity/test result through supported UI and roles.

**Diagnostic order**

1. Schedule/range/IP inclusion and MID selection/capability/up state.
2. ECC input/output timing, queue state, agent correlation, and errors.
3. Credential/classification/pattern execution and command permissions.
4. Pattern output class, identity attributes, relations, and source.
5. IRE identification/reconciliation/reclassification result.
6. Final CI, `last_discovered`, source/provenance, and relationship state.

Use Q22 for a bounded recent-run correlation and Q02/Q03/Q06 for IRE consequences.

**Common failures and fixes**

- Device alive but no CI: range/MID/credential/classifier/pattern failure; fix earliest failed phase.
- Duplicate hardware after Discovery: preexisting direct imports, identifier normalization, wrong class, missing serial lookup, or cloud/source collision.
- Correct CI but wrong fields: pattern output or reconciliation authority.
- Stale CIs: failed schedule/range/credential versus decommission; do not retire until source coverage is proven.
- Relationship churn: conflicting patterns/sources or incorrect dependency metadata; inspect `sys_rel_source` and pattern output.
- Pattern customization skipped after upgrade: compare Store pattern version and customization ownership; prefer extension patterns where supported.

**Decision rules**

- Use Discovery for observed runtime facts and topology; assign portfolio, owner, financial, and lifecycle authority to the governed business source.
- Fix the earliest failed phase in schedule -> MID/ECC -> credential/classification -> pattern -> IRE -> final CI. A downstream workaround makes recurrence harder to diagnose.
- Do not retire or delete a CI merely because Discovery missed one run; prove expected coverage, retirement evidence, and downstream dependencies first.

**PDI exercise**

If Discovery/MID is unavailable in the PDI, use Identification Simulation with a Discovery-like payload and a valid source choice. Do not invent credentials or external targets.

### 4.5 Service Mapping

**Purpose and CSDM role**

Service Mapping creates and maintains runtime Service Instances/Application Services and their dependency topology. It consumes discovered CIs/relationships and adds a service boundary through pattern/top-down, tag-based, traffic-based, or governed query/manual methods. It does not replace Business Application or Business Service governance.

**Key records**

- Service Instance base `[cmdb_ci_service_auto]`; pattern-mapped `[cmdb_ci_service_discovered]`; tag-based `[cmdb_ci_service_by_tags]` where installed.
- Service membership `[svc_ci_assoc]` with `service_id` and `ci_id`.
- Runtime edges `[cmdb_rel_ci]`; entry points are Endpoint `[cmdb_ci_endpoint]` descendants.
- Candidate entry points `[sa_cand_entry_point]`; tag traversal `[svc_traversal_rules]` where installed.
- Pattern/discovery logs and Service Mapping error/review surfaces.

**How to work**

1. Define service owner, environment, boundary, consumers, entry points/tags/query, and operational acceptance.
2. Verify underlying discovered CIs/identity first; a map cannot repair a broken CMDB.
3. Inspect the service record, membership, direct edges, entry points, and last discovery using Q23.
4. Re-run mapping and compare added/removed CIs and errors. Validate load balancers, shared components, endpoints, and relationship direction.
5. Link the Business Application to the deployed Service Instance using current CSDM guidance; do not select Business Application as operational incident/change CI.
6. Test Change impact, Event impact, Incident selection/routing, owner review, and stale/removal behavior.

**Decision rules**

- Use pattern/top-down mapping when entry points and traffic traversal define the service.
- Use tag-based mapping when tags are governed, complete, and lifecycle-managed; validate traversal rules and map size.
- Use query-based/Dynamic CI Group for a durable property-based collection when a dependency map is not required.
- Manual maps require an owner, attestation cadence, and change-process trigger; avoid them at scale.
- One deployed environment/region/variant generally needs its own Service Instance; Business Application remains environment-neutral.

**Failure modes**

- Empty/incomplete map: wrong entry point, MID/credentials, underlying CI missing, pattern error, blocked port, boundary/traversal rule.
- Huge/noisy map: tag scope/traversal too broad or service boundary undefined.
- Map changes disappear/reappear: automated mapping remains authoritative over manual edits.
- Impact does not calculate: wrong direction/type, unsupported service/class, Event/Change configuration, stale membership, or incomplete map.

Official basis: [Service Mapping overview](https://www.servicenow.com/docs/r/it-operations-management/service-mapping/service-mapping-get-started.html), [entry points](https://www.servicenow.com/docs/r/it-operations-management/service-mapping/r_EntryPointsforBizSvcDef.html).

## 5. Prevention and remediation decision trees

### Duplicate CI

```text
New duplicates still arriving?
  yes -> stop/scope source -> compare target class and payload -> fix identity/dependency/normalization -> prove rerun
  no  -> inspect duplicate task members and downstream references -> choose main -> preview remediator -> merge one -> validate
```

### Unexpected attribute value

```text
Wrong CI identity?
  yes -> fix identification first; assess false merge/duplicates
  no  -> identify last reporting sources -> static or dynamic rule? -> child override? -> refresh/CMDB 360 coverage? -> fix rule/source -> replay -> validate
```

### Stale CI

```text
Source expected to see CI?
  yes -> source/MID/schedule/credential/range/run failure -> repair and rediscover
  no  -> decommission evidence + retirement definition + dependencies/tasks/assets -> Data Manager retire -> retention -> archive/delete if approved
```

### Missing relationship or service impact

```text
Endpoints/CIs exist and are correctly identified?
  no -> repair discovery/identity
  yes -> dependent or non-dependent? -> metadata/type/direction/source -> map/membership -> impact configuration -> validate bounded traversal
```

## 6. PDI-safe exercise pattern

1. Run read-only release/plugin/table/field/source-choice inspection. Never hard-code credentials or request them in skill instructions.
2. Choose an installed independent class with OOTB identification rules; avoid altering OOTB rules for a demo.
3. Use a unique test prefix and non-production source-native key. Start with Identification Simulation/Q04.
4. If the user authorizes PDI writes, call IRE for one record, rerun it, submit one conflict, and inspect provenance/health impact.
5. Do not run deduplication, Data Manager, delete, or reclassification merely as a demo. Create a preview/runbook unless the user explicitly asks for the controlled PDI exercise.
6. Record every test CI/relationship/import set created. Clean only task-created data through a supported, bounded path after validating no downstream references.

## 7. Current live-verification note

Authenticated read-only Table API checks against the current PDI succeeded on 2026-08-09. The instance reported Australia Patch 1. The checks confirmed the core schemas used here, including:

- health inclusion: `cmdb_health_config` with `metric`, `active_record_condition`, and `applies_to`;
- principal class: `cmdb_class_info.principal_class` (no principal-class rows were configured at check time);
- life-cycle mapping: `life_cycle_mapping` and its legacy-field/value, table, priority, active, and control fields;
- identification, static/dynamic reconciliation, health result/scorecard, multisource, Data Manager, duplicate remediation, Discovery, relationship metadata, and Service Mapping membership tables listed in this guide.

Treat this as schema evidence, not proof that every Store/plugin-dependent UI is installed or licensed. Resolve tables and fields again on another release or after upgrades. The normal saved connection profile may still require maintenance when the PDI is replaced; never embed instance credentials in this skill or in command history.

The read-only check did not execute collectors or mutating workflows. Verify rendered Workspace/CMDB 360 routes and roles, MID/Discovery and Service Mapping execution, health job output, reclassification restriction fields, and the Data Manager/deduplication wizards in the PDI only when a real task requires them. Keep mutating IRE, merge, reclassification, retire/archive/delete, and lifecycle-sync tests behind explicit authorization and the previews in this guide.

## 8. Official documentation index

- [CMDB documentation](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/c_ITILConfigurationManagement.html)
- [IRE](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/ire.html)
- [CMDB Health](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/overview-cmdb-health.html)
- [CMDB 360](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/multisource-cmdb.html)
- [CI Class Manager](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/ci-class-manager-landing-page.html)
- [CMDB Data Manager](https://www.servicenow.com/docs/r/servicenow-platform/configuration-management-database-cmdb/cmdb-data-management.html)
- [CSDM](https://www.servicenow.com/docs/r/servicenow-platform/common-service-data-model-csdm/csdm-landing-page.html)
- [Discovery](https://www.servicenow.com/docs/r/it-operations-management/discovery/r-discovery.html)
- [Service Mapping](https://www.servicenow.com/docs/r/it-operations-management/service-mapping/service-mapping-get-started.html)
