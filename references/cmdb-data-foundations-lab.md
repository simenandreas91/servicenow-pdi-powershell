# CMDB Data Foundations PDI Lab

Use this runbook to exercise ServiceNow's **Ingest, Govern, and Insight** Data Foundations pillars with an isolated, reversible CMDB dataset. Use it with `cmdb-csdm.md`, `cmdb-admin-development.md`, and `cmdb-query-library.md`.

## Contents

- [Lab contract](#lab-contract)
- [Preflight](#preflight)
- [Dataset](#dataset)
- [Ingest tests](#ingest-tests)
- [Govern tests](#govern-tests)
- [Insight tests](#insight-tests)
- [Remediation and prevention](#remediation-and-prevention)
- [Evidence and cleanup](#evidence-and-cleanup)

## Lab contract

- Run only in a PDI or explicitly approved non-production instance.
- Use a unique prefix such as `DFLAB-<date>-<short-run-id>` in every CI name, source-native key, and source feed.
- Resolve the release, table/field shape, source choices, relationship types, owners/groups, identifiers, and installed apps live. Never carry sys_ids between instances.
- Route CI and relationship creation/update through IRE. An intentionally invalid payload must be a no-commit identification test. Do not create a direct-write duplicate merely to demonstrate an anti-pattern.
- Do not alter shared OOTB identification or reconciliation rules merely for the lab. Diagnose their behavior and propose an isolated production design instead.
- Keep one manifest containing every created CI/relationship sys_id, IRE operation, source-native key, before value, remediation value, and cleanup decision.
- Do not enable CMDB 360, collectors, broad health rules, or lifecycle policies until their denominator, performance impact, and existing-data scope are measured.
- Do not expose credentials, tokens, MID credentials, sensitive payloads, or unrestricted CI exports in evidence.

## Preflight

1. Run the PDI health check and verify URL, authenticated user, family/patch, application scope, and write authorization.
2. Verify required tables with Q00/Q01: `cmdb_ci`, the selected child classes, `cmdb_rel_ci`, identifier/reconciliation tables, health tables, `sys_object_source`, and optional `cmdb_multisource_data`.
3. Inspect installed plugins/Store apps. Separate Discovery engine (`com.snc.discovery`) from Discovery Admin Workspace (`sn_disco_workspace`). An installed workspace does not prove the engine is active.
4. Count existing CIs and relationships by class/source. Query `nameSTARTSWITH<prefix>` and stop if any record already uses the proposed prefix.
5. Inspect the effective identifier, static/dynamic reconciliation, health inclusion, recommended fields, staleness/orphan rules, lifecycle mappings, principal-class designation, and relationship metadata for every selected class.
6. Resolve one active support/managed-by group and test owner by stable name/user name. Resolve exact relationship type records by `cmdb_rel_type.name`.
7. Record current health scorecard timestamps, processor status, collector jobs, CMDB 360 properties/deny classes, and the existing denominator before configuration changes.

## Dataset

Use the smallest operational slice that proves the contracts:

| Record | Recommended class | Intended state | Fault exercised |
| --- | --- | --- | --- |
| Production Service Instance | `cmdb_ci_service_auto` or installed supported child | Unique name and, where enforced, unique `number` (SN App Service ID); named owner/group, Production, operational | None; graph root for the lab |
| Running application | `cmdb_ci_appl` | Stable process command/key and version; `Runs on::Runs` a server | Dependent identification and hosting relationship |
| Good Linux server | `cmdb_ci_linux_server` | Unique serial/name; current discovery; owner/group/environment populated | Known-good comparison |
| Incomplete Linux server | `cmdb_ci_linux_server` | Unique serial/name; current discovery | Missing recommended owner/group/description/environment |
| Stale Linux server | `cmdb_ci_linux_server` | Unique serial/name; installed and operational | Old `last_discovered`, creating an intentional freshness contradiction |

Add only standard relationships with a named consumer:

```text
Service Instance --Depends on::Used by--> Running application
Running application --Runs on::Runs--> Good Linux server
```

For a relationship-governance fault, use one **non-dependent** reversed/incorrect edge only between lab records, capture its sys_id, detect it with Q14/Q16/Q17, then remove that exact edge during remediation. Never corrupt the dependent `Runs on::Runs` edge.

## Ingest tests

### 1. No-commit contract tests

Use Q04 or Identification Simulation before any write:

- valid Linux server: expect `INSERT` before creation;
- payload missing every active identifier attribute: expect a missing-matching-attributes/incomplete result and no CI;
- dependent application without its host relation: expect partial/incomplete/dependency evidence and no committed application;
- complete application + server + `Runs on::Runs` payload: expect both items and relationship to identify successfully.

Capture item operations, attempts, warnings, errors, relation results, and partial/incomplete counts. HTTP success or script completion is not proof.

### 2. Controlled IRE load

Use one valid `cmdb_ci.discovery_source` choice and one source feed derived from the run prefix. Build a single coherent payload where dependent items include their host. Resolve references such as owner/group at runtime.

After approval:

1. Call `createOrUpdateCI` for the slice.
2. Parse every item and relationship result; stop on any error.
3. Re-read exact returned sys_ids and verify class, values, relationships, `sys_object_source`, and `last_discovered`.
4. Replay the identical payload. Expect no new CI or relationship and an update/no-change result.
5. Run a second-source conflict against one lab server using the same real identity but a different source-native key and conflicting serial/description. Observe the actual identification and reconciliation outcome; do not assume source priority.
6. Repair the authoritative value through IRE after governance evidence is captured.

### 3. Classic import comparison

If classic Import Sets are part of the exercise, load only a few staging rows and use Q21 (`CMDBTransformUtil`) in one onBefore Transform Script. Set `ignore=true` after IRE. Do not use coalesce as CMDB identity, and do not use this path for the dependent application. Reconcile staged, inserted, updated/no-change, partial/incomplete, and errored counts; rerun the same rows to prove idempotency.

If IntegrationHub ETL is installed, prefer an IH-ETL/RTE sample and compare its IRE output to the classic path.

## Govern tests

1. **Identification:** use Q02 to explain the effective rule and entry order. For inherited hardware identity, test serial and name fallback separately. Treat a same-name/different-serial match as an identity-risk finding, not permission to change the OOTB rule without broader collision analysis.
2. **Reconciliation:** use Q03/Q06/Q07 to trace both source reports and the selected value. If no class/attribute authority exists, record the observed last-writer behavior as a governance gap. Do not add a shared-parent rule for one lab.
3. **Principal class:** inspect `cmdb_class_info` and `com.snc.task.principal_class_filter`. Designate only operational classes used by named task/health workflows, test the intended picker as a non-admin, and remember the flag does not inherit.
4. **Completeness:** configure a small recommended-field set with real consumers. The verified Australia Patch 1 Class Manager offered and successfully tested `environment`, `managed_by_group`, `owned_by`, and `support_group`; use the fields actually available on the target family. Use a health inclusion rule scoped to `nameSTARTSWITH<prefix>` before running collectors.
5. **Correctness/freshness:** inspect the effective staleness threshold and verify the intentionally old `last_discovered` record is in scope. Do not equate stale with delete.
6. **Relationships:** verify direction/type, hosting metadata, duplicate edges, bounded graph traversal, and source. The service must depend on the application; the application must run on the host.
7. **Lifecycle:** compare `install_status`/`operational_status` with `life_cycle_mapping` and standard life-cycle values. Do not enable global CI/asset lifecycle sync for the lab.
8. **Ownership:** confirm the good records route to a real active group and the incomplete record creates an actionable gap.

Make supported configuration changes through CI Class Manager/Workspace. Query internal result tables for evidence only.

## Insight tests

Treat dashboards as views over governed records:

1. Run the relevant health collectors only after recording scope and job state.
2. Use Q08/Q09 to capture scorecard `failed`, `total`, `score`, collection time, processor status, max-failure cutoff, and raw failure rows for the lab prefix.
3. Deduplicate failure rows by CI before describing affected-record counts; one CI may fail several metrics.
4. Compare the good, incomplete, and stale records. Expected result: the known-good CI is a control, the incomplete CI fails configured completeness, and the stale CI fails freshness when the effective threshold is exceeded.
5. Use Q06 to prove IRE source-native provenance. Use Q07 only when CMDB 360 is enabled and collecting the class.
6. If CMDB 360 is disabled, report that as an observed visibility gap. Do not enable it blindly; measure current CMDB volume, denied/skipped classes, capture properties, and storage implications first.
7. Inspect relationship-health raw results for the intentionally incorrect edge. If no collector/rule evaluates it, record the limitation and use the direct bounded relationship diagnostic as evidence.
8. Compare classic dashboard and Workspace counts by encoded scope, domain, skipped-class configuration, and collection timestamp before calling a UI defect.

## Remediation and prevention

Remediate the earliest broken contract first:

1. Invalid/missing identifier -> correct source mapping/payload and replay; do not patch the CI directly.
2. Wrong selected attribute -> correct source authority or source behavior, then replay the authoritative payload.
3. Missing governed fields -> populate them through IRE from the owning source.
4. Stale CI with healthy expected source -> repair source coverage. A deliberate lab timestamp can be refreshed through IRE after evidence is captured.
5. Incorrect non-dependent relationship -> stop the emitting path, remove the exact task-created edge, and replay the correct relationship payload.
6. Duplicate recurrence -> fix identity/dependency/normalization before using the supported Duplicate CI Remediator. Do not manufacture a direct-write duplicate for this lab.

Rerun the identical ingest and health checks. Prove:

- zero additional CI inserts on replay;
- authoritative values retained;
- missing-field and staleness failures reduced for an unchanged denominator;
- correct graph edges remain and the incorrect edge is gone;
- no unrelated CIs, relationships, health rules, tasks, or customer updates changed.

Convert each recurring issue into a prevention control: source contract, IRE regression payload, reconciliation authority matrix, health inclusion/recommended-field rule, lifecycle policy, relationship assertion, monitoring threshold, and named owner/SLA.

## Evidence and cleanup

Record compact evidence with these sections:

```text
Environment/release/apps:
Run prefix and source/feed:
Created CI and relationship manifest:
IRE no-commit, insert, replay, conflict, and remediation results:
Identifier/reconciliation/provenance findings:
Health scope, denominator, raw failures, and collection timestamps:
Relationship/lifecycle findings:
Before/after comparison:
Remaining plugin/UI/collector limitations:
Cleanup decision and exact rollback path:
```

Keep the dataset when the user wants to inspect it in Workspace; clearly label it as non-production lab data. For cleanup, first verify no task, asset, service, or non-lab relationship references the records. Prefer a previewed CMDB Data Manager policy when lifecycle testing is part of the goal. Otherwise delete only exact task-created PDI records with a separate explicit cleanup approval and recorded sys_ids; remove dependent children/relationships in the supported order.
