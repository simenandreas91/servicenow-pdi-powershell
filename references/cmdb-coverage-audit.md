# CMDB Skill Coverage Audit

## Scope and rating rule

This records the state of `SKILL.md` and `references/cmdb-csdm.md` before the 2026-08-09 CMDB admin/developer expansion. It is not a rating of ServiceNow product capability.

- **Fully covered:** practical purpose, tables/fields, executable query or script, failure diagnosis, remediation, and decision rules.
- **Partially covered:** useful concepts or guardrails exist, but an administrator cannot complete the work from the reference alone.
- **Missing:** absent, only named, or confused with a different feature.

## Before-update assessment

| Topic | Rating | Evidence and gap |
| --- | --- | --- |
| Identification Rules | Partially covered | Explains independent/dependent identity and identifier strength, but lacks configuration-table inspection, rule inheritance diagnostics, and runnable probes. |
| Reconciliation Rules | Partially covered | Explains attribute authority and source precedence at a high level, but lacks tables, rule-precedence inspection, conflict tests, and repair logic. |
| Identification and Reconciliation Engine (IRE) | Partially covered | Correctly mandates IRE and names ingestion choices, but provides no usable payload/API, result parsing, error-table workflow, or Scripted REST pattern. |
| Dynamic Reconciliation Rules | Missing | Dynamic IRE is mentioned, but Dynamic Reconciliation is a separate CMDB 360-backed feature and is not covered. |
| CMDB Reconciliation overall | Partially covered | Contains governance principles, but not the end-to-end source-to-attribute reconciliation operating process. |
| CMDB Health Dashboard | Partially covered | Defines KPIs and an operating loop, but lacks score interpretation details, underlying result/scorecard/status tables, and queries. |
| Configure health inclusion rules | Missing | Exclusion is advised conceptually, but inheritance, metric scope, duplicate limitations, and configuration diagnostics are absent. |
| CMDB 360 / CMDB 360 View | Partially covered | Identifies it as a provenance view, but lacks properties, data/query tables, denied classes, and raw-data queries. |
| CMDB Workspace | Partially covered | Provides tool routing only; no distinction between workspace UI state and authoritative platform records or troubleshooting workflow. |
| Principal Class | Partially covered | Advises using principal classes, but lacks `cmdb_class_info`, task-filter property behavior, non-inheritance, and inspection logic. |
| Life Cycle Mapping (`life_cycle_mapping`) | Missing | Lifecycle governance is discussed, but legacy-to-CSDM mapping, priorities, controls, sync activation, and table inspection are absent. |
| CI Class Manager | Partially covered | Advises inspecting it, but lacks a class review procedure and metadata/table inspection sequence. |
| CI class switch, upgrade, and downgrade | Missing | Warns not to change `sys_class_name` casually, but does not define operations, data-loss behavior, IRE controls, tasks, or restrictions. |
| Dependent Relationships | Partially covered | Explains identity-bearing relationships but lacks metadata tables, payload requirements, and orphan-dependent diagnosis. |
| CI Relationships | Partially covered | Correctly names `cmdb_rel_ci` and direction rules, but lacks duplicate/orphan/source queries and safe write patterns. |
| Hosting Rule and Containment Rule | Partially covered | Mentions dependent relationships but not the distinct semantics, metadata tables, rule constraints, or practical diagnostics. |
| CMDB Data Manager | Partially covered | Correctly explains retire/archive/delete and preview controls, but lacks policy/execution/task tables and operating queries. |
| Duplicate CI Remediator | Partially covered | Advises root-cause-first and preview, but lacks task/audit/remediation tables, wizard state, and post-merge validation queries. |
| Import Sets + Transform Maps for CMDB | Partially covered | Warns that classic transforms require IRE but provides no `CMDBTransformUtil` script, `ignore=true` requirement, restrictions, or run diagnostics. |
| Discovery | Partially covered | Explains how Discovery populates runtime topology, but lacks run/log/ECC/IRE correlation, diagnostic order, and common failure isolation. |
| Service Mapping | Partially covered | Explains CSDM role and service boundaries, but lacks application-service/membership/entry-point tables, map diagnostics, and source/remediation logic. |

No requested topic met the strict **Fully covered** definition before the update.

## Post-update disposition

`cmdb-admin-development.md` now supplies the operational decision logic for every topic. `cmdb-query-library.md` supplies reusable read-only diagnostics, IRE and Transform Map examples, relationship queries, and guarded mutation patterns. Items whose internal table or field names are not guaranteed by official documentation deliberately require live `sys_db_object`/`sys_dictionary` resolution instead of a guessed name.

On 2026-08-09, authenticated read-only Table API checks against the current PDI confirmed Australia Patch 1 and the core table/field schemas used by the new runbook and query library. Credentials were supplied only for the live check and were not written to this skill. Release- or plugin-sensitive items remain explicitly marked for live resolution rather than assumed.
