# ServiceNow Success Dashboard Handbook

Use this handbook for ITSM or HR Success Dashboard indicators, the Success Dashboard Admin Console, Operational Success, Success Dashboard Benchmarks, self-service instrumentation, cost-savings configuration, or `sn_sd_*` records. It is not the handbook for an ordinary Platform Analytics dashboard.

## Current Official Baseline

This guidance was reconciled with the ServiceNow **Australia** documentation and Store release notes on **2026-08-28**. The current Store release notes listed ITSM Success Dashboard indicators **9.1.2** (June 2026), but the installed Store app version and target family are always the controlling facts. Re-check current documentation before relying on a field, job name, script body, dependency, or navigation route.

The ITSM dashboard is delivered by the **ITSM Success Dashboard indicators** Store application (`sn_sd_itsm`) and uses the Success Dashboard Core/Common applications, Performance Analytics, and Self-Service Analytics. The HR dashboard uses its corresponding HR Success Dashboard indicators application (`sn_sd_hrsm`) with the shared Success Dashboard framework. These experiences are not ordinary `par_dashboard` dashboards even though their indicators use the Performance Analytics backend and Operational Success can embed Platform Analytics dashboards.

Primary documentation:

- [ITSM Success Dashboard indicators](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/success-dashboard-indicator-landing.html)
- [Install ITSM Success Dashboard indicators](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/install-success-dashboard.html)
- [ITSM Success Dashboard Admin console](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/admin-console-sd.html)
- [Success Dashboard roles and responsibilities](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/success-roles.html)
- [ITSM Success Dashboard components](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/itsm-sdb-dasboard-overview.html)
- [ITSM Success Dashboard KPI definitions and formulas](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/sd-kpi-formulae.html)
- [ITSM Success Dashboard Store release notes](https://www.servicenow.com/docs/r/store-release-notes/store-rn-itsm-success-dashboard-indicators.html)
- [Configure HR Success Dashboard indicators](https://www.servicenow.com/docs/r/employee-service-management/hr-service-delivery/configure-success-dashboard.html)

## Product Boundary and Navigation

Use the following routes as the starting points, then verify them on the installed version:

- Viewer experience: **All > Success Dashboard > Success Dashboard**.
- Admin experience: **All > Success Dashboard > Getting Started**.
- Current Next Experience route observed for the viewer: `now/success-dashboard/home`.
- PA collection jobs: **All > Performance Analytics > Data Collector > Jobs**.

The dashboard has several related but distinct surfaces:

| Surface | Purpose | Ownership |
| --- | --- | --- |
| Success Dashboard | Prescribed outcome KPIs, trends, drilldowns, targets, contextual information, and cost savings | Success Dashboard Store apps plus PA indicators and scores |
| Getting Started / Admin Console | Roles, instrumentation, PA jobs, KPIs, cost savings, properties, Operational Success, and Benchmarks setup | Supported configuration entry point |
| Operational Success | Tabs containing operational ITSM process dashboards | Success Dashboard tab/category mappings to Platform Analytics dashboards |
| Benchmarks | Peer and top-performer comparisons | Benchmarks application and explicit organizational opt-in |
| Platform Analytics | Indicator sources, indicators, jobs, breakdowns, scores, and mapped operational dashboards | PA backend; use `lessons-platform-analytics.md` when editing this layer |

Do not try to find the Success Dashboard as a normal `par_dashboard` record or rebuild it in UI Builder because a KPI or tab is missing. Trace the Store app, role, registry, instrumentation, PA collection, formula, and score chain first.

## Access Model

Use the least-privileged Success Dashboard role that matches the persona:

| Role | Intended access |
| --- | --- |
| `sn_sd.success_dashboard_read` | View dashboard, KPI summaries, high-level breakdowns, and share |
| `sn_sd.success_dashboard_details_read` | View dashboard plus record-level KPI details; underlying record ACLs still apply |
| `sn_sd.success_dashboard_admin` | Configure dashboard settings, contributing indicators, cost savings, contextual information, and sharing |

Installation and several setup tasks require `admin`; Performance Analytics configuration can require its own PA roles. Assign roles through governed groups when that is the customer convention. Test with the real non-admin persona: an admin seeing the page or drilldown does not prove user access.

If the module is missing, check in this order: Store app installed and active, installed version compatible, dependencies present, user role, application/module visibility, and route access. Do not solve a missing module by granting `admin`.

## Installation and Upgrade Readiness

Installing or upgrading a Store application is a high-impact operation. Inspect first and obtain explicit authorization before changing an environment.

1. Confirm the target instance, family/build, environment, current Store application versions, entitlements, and licensed product edition with the customer or subscription data. Do not treat an older documentation statement about ITSM Pro as a substitute for current entitlement evidence.
2. For ITSM, resolve `sn_sd_itsm` under **System Applications > All Available Applications > All**. For HR, resolve the HR Success Dashboard indicators application and its current dependencies.
3. For the current ITSM documentation, confirm **Performance Analytics**, **Performance Analytics Premium**, and **Self-Service Analytics** before installing the Store application.
4. Review the installation dependency list and Store release notes. Record versions of the product app and shared Core/Common apps; mixed or stale versions can produce schema, job, formula, or UI mismatches.
5. After install or upgrade, verify modules, roles, prescribed registry records, PA jobs, scheduled formula job, and the dashboard route before configuring instrumentation.

Never edit a ServiceNow-owned Store artifact merely to make it look like another version. Prefer the Admin Console and documented extension registries. If official documentation directs an override such as `SSADeflectionHelper`, compare the installed base/extension contract with documentation for that exact release, snapshot the record, use the documented extension point, and regression-test after Store upgrades.

## Recommended Configuration Order

Configure a coherent vertical slice rather than activating every capability at once:

1. Define business outcomes, dashboard audience, service group, included ticket populations, self-service channels, period, expected formulas, owners, and data-sharing constraints.
2. Verify app/dependency versions and assign the minimum Success Dashboard roles.
3. Baseline the dashboard before changes: visible tabs/KPIs, current period, service-group filter, job states, score freshness, and any no-data/error cards.
4. Configure one instrumented channel, such as Knowledge, Virtual Agent, or automated catalog fulfillment.
5. Verify its raw activity/records and corresponding contributing PA indicator before enabling or changing rollups.
6. Review prescribed primary KPIs and register only necessary custom contributing indicators.
7. Recalculate formulas when the contributing model changed, then activate the required daily jobs and execute the bounded historical jobs when approved.
8. Validate the dashboard score, trend, drilldown, period aggregation, and security for that slice.
9. Configure optional cost savings, targets, Operational Success, Process Mining, Automation Discovery, or Benchmarks only after the base metric is trusted.

## Self-Service Instrumentation

### Knowledge deflection

Self-solved using Knowledge depends on Self-Service Analytics activity and the absence of a subsequent ticket or qualifying live-agent interaction during the configured window. It is not simply a count of article views.

- Use **Self-Service Analytics > Activity Context**, open the **Viewed a knowledge article** activity context type, and constrain its condition to the knowledge bases that genuinely represent the service group. Do not count unrelated HR, external, test, or draft content in an ITSM KPI.
- In **Success Dashboard > Getting Started**, use the Knowledge deflection card to review the deflection pattern and its window.
- Treat the window as a business definition, not a display refresh preference. A wider window can reduce counted deflections because more later tickets/interactions disqualify the activity.
- Test a positive case with an eligible article and no later ticket/agent interaction, and a negative case that creates a qualifying ticket or interaction within the window.

Official references:

- [Configure the knowledge base](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/configure-knowledge-sdb.html)
- [Set the Knowledge deflection interval](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/configure-knowledge-deflection.html)

### Virtual Agent deflection

Use the current Self-Service Analytics/Admin Console configuration first. Review the deflection pattern, refresh window, incidents considered, and topics considered. For custom topics that are not instrumented by the base application, use the documented Virtual Agent deflection nodes:

- `ITSM VA-Self-Resolving` when the conversation resolves the issue without creating an IT ticket.
- `ITSM VA-Triage & Created` when VA submits an incident or request and contributes to call deflection.
- When a Link Output submits a catalog item and the installed-version documentation requires it, append the documented `referrer=va` parameter so the channel is attributed correctly.

The interaction exclusion logic is central to the metric. Current Australia documentation instructs administrators to override `checkInteraction` in `SSADeflectionHelper` for live-agent detection. Do not paste a stored script from this handbook or an older release. Inspect the installed `SSADeflectionHelperSNC` contract and use the current official snippet only when the target version requires it.

Official references:

- [Configure VA with Self-Service Analytics](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/instrument-va-sdb2.html)
- [Configure custom VA topics and deflection nodes](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/instrument-virtual-agent-sdb.html)
- [Update the live-agent Script Include](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/update-live-agent-script-include.html)

### Catalog fulfillment automation

The catalog item's **Fulfillment automation level** is classification metadata used by the dashboard. Setting it to **Fully automated** does not make the item automated and does not prove end-to-end fulfillment.

- Set **Manual**, **Semi-automated**, or **Fully automated** only after inspecting the actual fulfillment flow/workflow, approvals, manual tasks, integrations, exceptions, and closure behavior.
- Use **Unspecified** until ownership and behavior are known.
- A fully automated item can contribute to the relevant dashboard metric only when its real process and indicator definition satisfy the installed-version rules.
- Validate one request from submission through final fulfillment and confirm the expected requested-item record is counted.

Reference: [Set catalog-item fulfillment automation level](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/set-fulfillment-automation-level-sdb.html).

## Performance Analytics Collection and Formulas

The current ITSM documentation names these daily jobs:

- `[SD ITSM] Daily Data Collection`
- `[PA SLA] Daily Data Collection`
- `[PA Requested Item] Daily Data Collection`
- `[PA Incident] Daily Data Collection`
- `[PA ITSM Dashboard] Daily Data Collection`

It names these historical jobs:

- `[SD ITSM] Historic Data Collection`
- `[PA Requested Item] Historic Data Collection`
- `[PA Incident] Historic Data Collection`
- `[PA ITSM Dashboard] Historic Data Collection`

The official procedure says Execute Now on the historical jobs to collect the past 60 days. Treat that as a version-specific default. Before executing a historical job, inspect its configured relative/absolute period, indicators, sources, estimated population, prior runs, schedule, and target environment. Historic collection writes PA scores and can be resource-intensive; obtain explicit approval for production execution.

For the Australia HR Success Dashboard indicators application, the prescribed sequence is narrower:

1. Activate `[SD HRSM] Daily Data Collection` so new scores are collected continuously.
2. Keep `[SD HRSM] Historic Data Collection` on demand and use **Execute Now** once to initialize the configured 60-day window.
3. Do not activate or schedule the historical job. Before execution, confirm its live period, active job-indicator set, existing score population, prior `pa_job_logs`, and target environment.
4. Treat daily-job activation as portable configuration/update-set content. Treat the historical execution and generated PA scores as environment-specific operational state.

An indicator's recent `scores_modified_at` is not proof that usable history exists. Verify base-score rows in `pa_scores_l1`/`pa_scores`, collection evidence in `pa_job_logs`, and the rendered dashboard. If the daily job has never run or collected only an empty day, the definitions can be complete while the cards still say **No data available** and the trends say **Unable to display content**. After a successful historical run, zero-valued cards can be valid evidence that the source population is empty; distinguish that from a missing visualization by confirming that the card and time-series chart both render.

`UpdateFormulasSD` is a scheduled job that recalculates Success Dashboard formulas and normally runs every 24 hours. Run it on demand after an approved contributing-indicator change or when stale formulas are proven; it does not repair missing source activity or missing PA scores.

References:

- [Activate PA jobs for ITSM Success Dashboard indicators](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/activae-pa-indicator-jobs-sdb.html)
- [Activate PA jobs for HR Success Dashboard indicators](https://www.servicenow.com/docs/r/employee-service-management/hr-service-delivery/activae-pa-indicator-jobs-sdb.html)
- [Collect historical data](https://www.servicenow.com/docs/r/now-intelligence/performance-analytics/t_RunHistoricalDataCollection.html)

## KPI Ownership and Customization

Preserve the prescribed Success Dashboard model:

- Primary indicator registry: `sn_sd_primary_indicator_registry`.
- Primary PA indicator mapping: `sn_sd_primary_indicator`.
- Contributing indicator registry: `sn_sd_contributing_indicator_registry`.
- PA backend: `pa_indicators`, indicator sources such as `pa_cubes`, jobs in `sysauto_pa`, job/indicator relationships, breakdown mappings, and score tables.

Do **not** modify prescribed primary indicators. ServiceNow explicitly warns that changes can affect dashboard scores. To represent a legitimate customer-specific source:

1. Define and validate a daily PA indicator with the correct source population, date semantics, unit, aggregation, direction, collection job, breakdowns, and record collection policy.
2. Register it in `sn_sd_contributing_indicator_registry` against the intended primary KPI and the correct ITSM or HR service group.
3. Add a concise description and, when useful, a More Information context card.
4. Add persona/time-saved assumptions only when cost savings are in scope.
5. Recalculate formulas and recollect only the periods needed to establish a comparable baseline.
6. Verify the contributing score, automatic primary rollup, manual formula KPI, dashboard display, and drilldown independently.

References:

- [Configure Success Dashboard KPIs](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/config-kpis-sdb.html)
- [Add contributing indicators](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/add-contributing-indicators.html)
- [Update More Information cards](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/update-sidepanel-more.html)

## Cost Savings and Currency

Cost savings are modeled estimates, not accounting evidence. They combine contributing-indicator volumes with persona groups, time-saved assumptions, and compensation/cost inputs. Require named business owners for those assumptions and record units, effective dates, and review cadence.

- Configure persona group and time saved per contributing indicator through the Admin Console.
- Validate that time units and salary/hourly-cost units match the implementation.
- Avoid double-counting the same work across overlapping contributing indicators.
- Use `sn_sd.success_dashboard_currency` for the dashboard currency code through the documented system-properties card. Confirm that changing the display code does not imply currency conversion of stored assumptions.
- Reconcile one period manually: qualifying volume × time saved × approved persona cost, following the installed formula.

References:

- [Estimated Cost Savings](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/estimated-cost-savings-sd.html)
- [Create a cost-savings indicator](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/customize-cost-savings.html)
- [Modify the currency code](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/customize-currency-code.html)

## Operational Success

Operational Success is a Success Dashboard framework that maps operational KPI categories/tabs to Platform Analytics dashboards. Use it when the goal is a consolidated operational view of Incident, Major Incident, Change, Request, Service Catalog, Interaction, Problem, On-call, Password Reset, Walk-up, or another configured process.

- Configure through the Operational Success Admin Console where available.
- The current model uses `sn_sd_kpi_category` for KPI categories and `sn_sd_tab_m2m_dashboard` to map a tab to a `par_dashboard`.
- Validate the mapped Platform Analytics dashboard independently using `lessons-platform-analytics.md` before exposing it in Operational Success.
- Preserve OOTB categories and mappings; add customer content rather than taking ownership of Store records unless the product explicitly supports the edit.

References:

- [Operational Success](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/operational-success-ref.html)
- [Operational Success Admin Console](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/admin-console-os.html)
- [Create an Operational Success dashboard](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/create-operational-success-dashboard.html)

## Benchmarks

Benchmarks requires explicit opt-in and permission to share the organization's indicator data. Treat this as an external data-sharing and governance decision, not an ordinary dashboard toggle.

Before opt-in, establish the approving business owner, privacy/security review, data classification, legal or contractual requirements, included KPIs, cohort implications, and opt-out/retention expectations. Do not opt in merely to remove the **Configuration needed** card. After approved opt-in, verify that benchmarked KPI definitions and service-group filters are comparable; a benchmark is not meaningful when the customer's custom numerator or denominator no longer matches the prescribed definition.

References:

- [Benchmarks Admin Console](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/admin-console-bm.html)
- [Benchmarks for Success Dashboard](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/success-dashboard-benchmark.html)

## Targets, Sharing, and Improvement Workflows

- Dashboard users can select monthly, quarterly, or yearly aggregation. Do not infer a formula KPI's period calculation from the chart label alone, including labels containing `AVG`. Resolve the installed indicator formula and time-series settings, total the contributing scores for the same period, and reconcile the rendered result. Australia HR default formula KPIs have been observed applying the percentage formula to period-level contributing totals rather than taking a simple average of the daily percentages.
- Create KPI targets only after a trustworthy baseline exists. Record target value, start date, review date, owner, direction, and rationale.
- Sharing sends a dashboard link or email; it does not grant the recipient roles, source-record ACLs, or benchmark access.
- Automation Discovery and Process Mining links are optional downstream workflows. Verify their app/license, project, input population, and user access before treating an insight card as actionable evidence.

References:

- [Monitor ITSM KPIs](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/monitor-kpi-for-itsm-imlementation.html)
- [Share the Success Dashboard](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/share-itsm-success-dashboard.html)
- [Create a KPI target](https://www.servicenow.com/docs/r/it-service-management/create-target-kpi-sd.html)
- [Identify automation opportunities](https://www.servicenow.com/docs/r/it-service-management/itsm-success-dashboard-indicators/view-auto-opportunities.html)

## Subproduction Demo Data

Use synthetic demo data only in an explicitly approved subproduction environment. Do not manufacture `pa_scores*` rows: seed the exact source populations used by the installed cubes and automated-indicator conditions so cards, formulas, trends, and drilldowns remain internally consistent.

1. Inspect the raw indicator cube, condition, date field, and contributing formula chain. For HR defaults, examples can include case `opened_at`/`closed_at`, case `contact_type`, the HR Service fulfillment type, and `ssa_deflection_metric.sys_created_on` plus the prescribed deflection pattern/type. Resolve all records live by stable names and conditions.
2. Design a small date series within the historical job's configured window. Calculate the expected period numerator, denominator, and percentage before writing; include existing source activity so synthetic data does not create implausible percentages.
3. Use non-sensitive identities, professional `DEMO` labels, deterministic natural keys, and a cleanup marker. Set `test_run=true` when the source table provides it. Keep supporting knowledge content inactive/draft unless the demonstration explicitly needs an employee-facing article.
4. Dry-run exact existing-marker counts and cap the maximum inserts. For controlled scripted backdating, suppress workflow on the synthetic source records and use `autoSysFields(false)` only where the cube collects by a system timestamp such as `sys_created_on`. Re-read every inserted row.
5. Check fan-out before collection: HR tasks, SLAs, Flow contexts, email, and business events should be absent unless intentionally demonstrated. Search-indexing events can still be emitted by direct record inserts even with workflow suppression; confirm they are only processed index events.
6. Execute the bounded historical job once after seeding, understanding that it deletes and rebuilds the covered score window. Reconcile source counts to base PA scores for representative dates, then verify the rendered card, comparison, trend, and drilldown.
7. Keep demo source data, generated PA scores, and cleanup steps out of update sets. Cleanup must target only the deterministic markers, then recollect the same bounded period; never delete shared score rows as the primary cleanup method.

## Inspection Anchors

Resolve all records live. Use these as discovery anchors, not portable identifiers:

- Store apps/scopes: `sn_sd`, `sn_sd_common`, `sn_sd_itsm`, `sn_sd_hrsm`, `sn_ssa_core`.
- Success Dashboard registries: `sn_sd_primary_indicator_registry`, `sn_sd_primary_indicator`, `sn_sd_contributing_indicator_registry`.
- Context cards: `sn_sd_indicator_context_information`, `sn_sd_m2m_indicator_context_information`.
- Operational mappings: `sn_sd_kpi_category`, `sn_sd_tab_m2m_dashboard`.
- PA collection: `pa_indicators`, `pa_cubes`, `sysauto_pa`, `pa_job_indicators`, breakdown mappings, `pa_scores_l1` and installed-version score tables.
- Self-Service Analytics: installed `ssa_*` tables, activity contexts/types, deflection configurations/patterns, and generated activity/deflection records.
- Runtime: PA job run logs, scheduled-job execution, application/system logs, dashboard network errors, and record-level drilldowns.

For a read-only inventory, capture app versions, active roles, relevant system properties, registry mappings, job state/last run, indicator source/formula/frequency/unit, latest score date, and score counts by service group. Avoid broad reads of score or activity tables; query one indicator and a bounded date range.

## Validation Standard

Validate at least one trusted KPI end to end:

1. **Definition:** business owner confirms the intended numerator, denominator, exclusions, time window, service group, unit, and desired direction.
2. **Instrumentation:** a controlled positive and negative scenario produce the expected raw activity or ticket records.
3. **Collection:** the relevant daily job completes without errors and writes a score for the expected date and breakdown.
4. **Formula:** contributing, automatic primary, and manual/formula KPI values reconcile for the same day and service group.
5. **Presentation:** the correct card, period, comparison, trend, contextual help, and target appear.
6. **Drilldown:** the card resolves to the expected contributing indicator and, when authorized, the exact supporting records.
7. **Security:** read and details personas get only their intended level; an unauthorized user cannot reach source records by URL.
8. **Freshness:** latest score date and dashboard-selected period match the documented collection schedule and time zone.
9. **Regression:** an adjacent KPI and another service group remain unchanged unless intentionally affected.
10. **Delivery:** configuration captured in the intended scope/update set is separated from operational activation, historical scores, role assignments, personal targets, shares, and benchmark opt-in.

## Troubleshooting Matrix

| Symptom | First checks | Common root causes |
| --- | --- | --- |
| Module or page missing | Store app/version, dependencies, module active, user roles, route | App not installed, dependency/version mismatch, missing Success Dashboard role |
| Dashboard loads but cards show no data | Selected period/service group, daily and historical job states, last successful run, latest PA scores | Jobs inactive/failed, historical job never run, no eligible source data, wrong period |
| One self-service channel is zero | Activity context, included KBs/topics, window, qualifying and disqualifying events | Channel not instrumented, wrong topic/KB filter, later ticket/live-agent interaction excludes activity |
| Self-solved or call-deflection percentage exceeds 100% | Recalculate daily numerator and denominator for the same date/service group; inspect each contributing score and formula | Partial or misaligned collection, custom contributor with wrong unit, denominator missing a population, breakdown mismatch, duplicate channel attribution |
| Formula remains stale after registry change | Registry active state, mapped PA indicator, `UpdateFormulasSD` last run/output | Formula job not run or failed, wrong service group/primary mapping, unsupported direct primary edit |
| Drilldown is empty but score is nonzero | Indicator record collection setting, score date/breakdown, user ACLs | Score collected without supporting records, viewer lacks table ACL, period/breakdown mismatch |
| Catalog automation percentage looks wrong | Catalog item's metadata and actual fulfillment behavior | Items left Unspecified, metadata mislabeled, job has not recollected, automated workflow does not meet formula conditions |
| Cost savings is implausible | Volume, time unit, persona mapping, hourly cost, overlap | Minutes treated as hours, stale salary assumption, duplicated contributor, display currency mistaken for conversion |
| Benchmarks says Configuration needed | Opt-in state, role, approved data sharing, app dependencies | Organization has not opted in; do not bypass governance |
| Operational Success tab is absent | KPI category, tab-to-dashboard mapping, mapped `par_dashboard` availability and access | Missing/inactive mapping, target dashboard not transported, dashboard permission failure |

When a percentage is implausible, do not average already aggregated percentages or compare mixed frequencies. Reconcile daily component scores first, then reproduce the dashboard's monthly/quarterly/yearly aggregation exactly.

## Delivery, Rollback, and Upgrade Safety

- Install Store apps separately in each environment through the supported application process; do not transport Store-owned metadata in an update set.
- Make configuration changes in the documented application scope and a dedicated update set, then confirm natural capture immediately. Some Admin Console actions update operational data or properties rather than application files; document and repeat approved target-environment steps instead of forcing capture.
- Treat PA score rows, Self-Service Analytics activity, job run history, benchmark opt-in, personal targets, shared-recipient state, and generated insights as runtime/operational data, not deployable configuration.
- Activate daily jobs and execute historical jobs explicitly per environment after definitions and dependencies are present. Prevent simultaneous or duplicate historical runs.
- Snapshot registry, property, mapping, Script Include extension, catalog metadata, and job before-values. Rollback means restoring those definitions and recollecting affected periods when necessary; an update-set backout does not undo collected scores or externally shared benchmark data.
- After Store upgrades, revalidate extension overrides, registry relationships, job errors, formulas, dashboard routes, localized labels, breakdown mappings, and one end-to-end KPI. Review Store release notes for security, accessibility, filter, and data-collection fixes.

## Handoff Template

Report Success Dashboard work with:

- target environment, family/build, and installed Success Dashboard/Core/Common/Self-Service Analytics versions;
- viewer/admin route and roles tested;
- service group, KPI definitions, instrumentation windows, included channels, and exclusions;
- changed records/properties/jobs and delivery vehicle;
- historical period collected and job results;
- reconciled source, contributing, primary, formula, dashboard, and drilldown evidence;
- cost/benchmark assumptions and approvals where applicable;
- cleanup, rollback, target-environment operational steps, and remaining risk.
