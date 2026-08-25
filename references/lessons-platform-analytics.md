# Platform Analytics Dashboard Lessons

Use this when creating, modifying, embedding, sharing, migrating, or transporting Platform Analytics dashboards (`par_dashboard`) in Simen's PDI or another approved environment.

## Current Official Baseline

The guidance below was reconciled with the ServiceNow **Australia** documentation on 2026-08-22. Re-check the target family, patch, Store application versions, roles, and live form before relying on release-sensitive fields or internal JSON.

- Platform Analytics is active by default in Australia. For upgraded instances, non-admin users can create Platform Analytics objects but not new Core UI reports, PA widgets, responsive dashboards, or interactive filters. Core UI dashboards are in maintenance mode. Default new work to Platform Analytics unless a real legacy dependency prevents it.
- A Platform Analytics dashboard contains data visualizations, filters, and other elements. Core UI reports and Performance Analytics widgets cannot be placed directly on it; create Platform Analytics data visualizations using table, indicator, or another supported data source.
- Any user with an internal role can create an in-line dashboard. A technical dashboard requires UI Builder access and is intended for developer capabilities such as scripting, data binding, custom event handling, or components.
- The in-line editor does not autosave. Save after each coherent layout or configuration slice.

Primary documentation:

- [Create a dashboard with the in-line editor](https://www.servicenow.com/docs/r/now-intelligence/create-db-in-ac.html)
- [Platform Analytics dashboard roles](https://www.servicenow.com/docs/r/now-intelligence/pa-dashboard-roles.html)
- [Data visualizations in Platform Analytics](https://www.servicenow.com/docs/r/now-intelligence/analytics-center-data-visualizations.html)
- [Platform Analytics tables](https://www.servicenow.com/docs/r/now-intelligence/platform-analytics-tables.html)
- [Create or add a filter on an inline dashboard](https://www.servicenow.com/docs/r/now-intelligence/select-workspace-filter-type.html)
- [Share a Platform Analytics dashboard](https://www.servicenow.com/docs/r/now-intelligence/share-db-in-ac.html)
- [Configure dashboard settings](https://www.servicenow.com/docs/r/now-intelligence/configure-ac-db-settings.html)
- [Move a Platform Analytics dashboard with an update set](https://www.servicenow.com/docs/r/now-intelligence/move-pae-db-with-update-set.html)
- [Australia Platform Analytics release notes](https://www.servicenow.com/docs/r/delta-washingtondc-australia/australia-washingtondc-platformanalyticsexperience-release-notes.html)

## Authoring Decision

Choose the least complex supported editor that meets the outcome:

1. **In-line dashboard editor:** default for shareable dashboards, tabs, data visualizations, filters, headings, lists, images, and rich text. Business owners can maintain these without UI Builder.
2. **Technical dashboard in UI Builder:** use only for scripting, data binding, custom events, local data resources, or components that the in-line editor cannot express. Requires `ui_builder_admin`; element edits redirect to UI Builder, technical dashboards cannot be rolled back to Core UI, and their dashboard structure is not supported by the in-line dashboard update-set unload procedure.
3. **Core UI responsive dashboard:** legacy exception only. In Australia it is maintenance-mode functionality, new customers do not receive responsive dashboards, and only admins can create new Core UI analytics objects after upgrade.
4. **Scripted `par_*` automation:** advanced non-production path for repeatable generation when a known-good same-release dashboard establishes the exact record graph and JSON contract. The official table reference allows Platform Analytics tables to be accessed through scripts, but direct creation bypasses editor guardrails. Keep it idempotent, inspect same-family records first, verify update capture immediately, and reopen/save the result in the supported editor.

For data sources, use table data for live operational counts, lists, and user-relative filters. Use indicators for collected history, targets, thresholds, breakdowns, trends, and governed KPI definitions. Confirm Performance Analytics activation or subscription before designing indicator-backed content.

## Supported In-line Creation Workflow

1. Establish the dashboard outcome, owner, audience, application scope, source tables or indicators, freshness expectation, filters, drilldowns, and promotion path.
2. Navigate to **Platform Analytics > Library > Dashboards**, select **Create new dashboard**, choose **In-line editor**, and enter a meaningful name and description.
3. Add either a new data visualization or a saved library visualization. Reuse a library visualization when its definition and lifecycle are genuinely shared; otherwise keep it dashboard-local so unrelated dashboards are not coupled.
4. Configure the visualization type, source, condition, aggregation, group/stack, title, description, interactions, filter following, and refresh behavior. Use **Run** or the designer preview to validate the source population before placing it.
5. Add filters, headings, lists, and tabs only when they support a user decision. Arrange the canvas for the intended breakpoint and save after each coherent slice.
6. Configure dashboard details: description, categories, visibility/experience, sharing, and any relevant homepage or embedding behavior.
7. Test as the intended viewer and an unauthorized persona. Verify data ACLs, default and cleared filters, drilldowns, empty/error states, freshness, load time, and that shared edits affect the intended audience only.
8. When the dashboard is complete, use the official **Unload Dashboard** action for update-set transport, then preview and validate it in the target environment.

## Fast Workflow

Use this only for the advanced scripted automation path after applying **Authoring Decision** and **Supported In-line Creation Workflow**.

1. Resolve the intended update set by `sys_id`, not only by name. `Set-ServiceNowUpdateSetContext.ps1 -Name` creates a new update set; use `-UpdateSetSysId` when continuing an existing one.
2. Confirm the application scope in the live UI and inspect a known-good dashboard from the same release/build. Read its related records and captured `sys_update_xml`; the payload reveals the exact `component_props` JSON saved by the builder.
3. When modifying a workspace-generated dashboard, reuse the existing `par_dashboard`, `par_dashboard_tab`, and tab canvas. The workspace scaffold may already have a small default widget set; update those widgets by resolved `sys_id` and add only missing widgets by stable `name`.
4. Create or reuse the following record graph in the scope proven by the inspected dashboard. Do not default blindly to Global:
   - `par_dashboard`
   - `par_dashboard_tab`
   - `par_dashboard_canvas` twice: one base canvas with no tab and one tab canvas
   - `par_dashboard_user_metadata`
   - `par_dashboard_permission`
   - `par_dashboard_visibility`
   - `par_dashboard_widget` per visualization
5. Put widgets on the tab canvas, not the base canvas.
6. Verify with Xplore by parsing every widget's `component_props`, counting widgets via `canvas.dashboard`, and running matching `GlideAggregate` checks for KPI filters.
7. Open the generated dashboard in the in-line editor, check layout and configuration, make a no-op-safe supported save if appropriate, and test it as the intended viewer.
8. For a generated workspace update set, a broad `Confirm-ServiceNowUpdateCapture.ps1` may report pre-existing mixed-scope rows. Narrow-check dashboard rows in `sys_update_xml` by `nameSTARTSWITHpar_dashboard` and by widget `target_nameLIKE<stable prefix>`.
9. After the dashboard is complete, run **Unload Dashboard** from `par_dashboard` so tabs and related structure are included for transport. Reinspect the update set, then restore preferences.

## Workspace Dashboard Modification Findings

Use the following pattern when App Engine Studio or Workspace creation has already generated the dashboard shell:

1. Resolve the dashboard and its tab by stable names and relationships. Find the active tab canvas through `par_dashboard_canvas.dashboard_tab=<tab sys_id>`; do not assume the tab record has a canvas field or query invented `tab`/`canvas` fields. A separate base canvas can exist without `dashboard_tab` and must not receive the visible widgets.
2. Resolve workspace placement through `par_dashboard_visibility.experience`. The direct experience, route, app configuration, macroponent, or screen fields on `par_dashboard` can all be empty while the dashboard is correctly associated with a workspace. Verify the exact visibility row, dashboard sharing, and source-table ACLs independently.
3. Expect generated starter widgets. Their `name` values can be empty, so first resolve the known scaffold widgets by `sys_id`, assign stable names while repurposing them, and then upsert additional widgets by `canvas + name`. Use the widget's `x`, `y`, `w`, and `h` fields for layout; a canvas `layout` value of `[]` does not prove that the widget layout is missing.
4. Treat script execution scope and record ownership as separate decisions. Because the `par_*` tables are Global, run Xplore in **Global** for scripted maintenance, keep the intended custom application and update set selected in developer preferences, and set `sys_scope` and `sys_package` explicitly on inserted app-owned records. An app-scoped Xplore run can create allowed `sys_scope_privilege` or Restricted Caller Access artifacts and update-set noise while a subsequent insert still fails.
5. After any mistaken app-scoped attempt, inspect new `sys_scope_privilege` records and dashboard-related customer updates. These are security-sensitive delivery artifacts; disclose them and obtain explicit authorization before deleting, denying, or otherwise changing them.
6. Make internal `component_props` IDs deterministic and consistent, but do not require base64. `dataSources[].id`, metric IDs, and component IDs are internal correlation keys; stable normalized strings are sufficient when a same-release example accepts them. Do not depend on `GlideStringUtil.base64Encode` in scoped Xplore because API availability can differ by scope.

Verification must cover the whole graph: parse every `component_props` value as JSON; confirm dashboard, tab, canvas, and visibility relationships; confirm the exact widget count and coordinates; keep each props payload within the field limit; verify sources, filters, grouping, and columns; compare KPI values with matching `GlideAggregate` queries; test sharing, permissions, and table/field ACLs; and inspect update-set capture. Finish with a rendered intended-persona test. If authentication or a suitable role-bearing user is unavailable, report that gap rather than treating structural checks as visual proof.

## Visitor and Reception Operations Pattern

Design a visitor-management dashboard around the decisions reception or security must make now:

- **Current state:** visitors inside now, expected today, overdue checkouts, and visitor cards currently available.
- **Immediate work:** active visits, upcoming arrivals ordered by expected time, and visits requiring attention such as no-shows or incomplete checkout.
- **Capacity and control:** available cards by location and the distribution of card statuses.
- **Exceptions:** blocked, lost, damaged, or otherwise unavailable cards, plus visits whose timestamps or assigned card conflict with their state.

A compact 48-column layout is effective: one full-width heading, four 12-column score widgets, two 24-column operational lists, two 24-column capacity/status charts, and two 24-column exception lists. Prefer table-backed real-time visualizations with drilldown for this operational use case. Until a compatible dashboard filter is deliberately designed and tested, use `filterConfigurations=[]`, `followFilters=false`, and `showFilterIcon=false` so an unrelated workspace filter cannot silently change safety-critical counts.

## Roles, Scope, Sharing, and Security

Treat dashboard rights, visualization rights, and data access as separate layers:

| Action | Australia requirement |
| --- | --- |
| Create an in-line dashboard | Any internal role |
| Edit a dashboard | Owner or recipient with edit rights; `dashboard_admin` can edit any dashboard |
| Edit a technical dashboard | Dashboard edit rights plus `ui_builder_admin` |
| Create a visualization on an editable dashboard | Any role with access to the source data |
| Create or edit a visualization in the library | `viz_creator` or a higher visualization role, plus ownership/edit rights where applicable |
| Create or edit a filter in the filter library | `analytics_filter_admin` or higher |
| Schedule dashboard refresh | `dashboard_admin` or higher |
| Create dashboard categories | `analytics_categories_admin` or higher |

- Select the dashboard's application scope before authoring or editing. To share a dashboard with a recipient as an editor, the sharer must be in the same application scope as the dashboard.
- Share with users or groups by default; share with roles only when the sharer can read `sys_user_role` and the audience is truly role-defined. Grant **Allow recipients to manage sharing** sparingly because it permits adding, changing, and deleting sharing entries.
- Sharing a dashboard automatically makes its table-based data visualizations available within that dashboard, but it does not bypass table, row, field, domain, or report-view access. Test the intended non-admin persona against the source and drilldown records.
- Dashboard edit rights do not grant edit rights to an underlying saved library visualization. Conversely, edits to a shared dashboard apply globally to all viewers; duplicate a dashboard when the audience needs an independent variant.
- Platform Analytics uses an edit lock by default. If the Edit button is missing, inspect ownership, sharing, application scope, role, and lock state before clearing a lock. Clear another user's lock only after confirming that their edit session is abandoned.
- Set **Dashboard visibility** to each intended experience or workspace before expecting the dashboard in a Dashboard page template. Visibility controls placement; it is not a substitute for sharing or data ACLs.

## Filters and Interactions

- Dashboard editors can create local single-select, multi-select, date, and true/false filters or reuse a saved library filter. Library filters require `analytics_filter_admin` to create or edit and are not available to technical dashboards or other UI Builder pages.
- Decide whether each visualization follows filters. For multi-metric bar and time-series visualizations, decide per metric; a denominator, benchmark, or target often should remain unfiltered while the operational numerator follows the viewer's selection.
- A date filter automatically applies to all indicator data on its page or tab. Verify that the indicator frequencies and collected periods make the selected range meaningful.
- Test filter defaults, clear-all, multiple selections, empty results, tab scope, filter groups/cascades, and copied links with filters. For an embedded dashboard configured with **Use as embedded**, URL-based copy/filter behavior is intentionally unavailable.
- Treat drilldown as a security and usability path. Verify the selected data point opens the intended visualization, list, record, or URL, and that the viewer has access to the destination data.

## Freshness and Performance

Choose and document one primary freshness model:

- **Manual refresh:** safest default for ordinary operational dashboards.
- **Scheduled repetition:** reloads only while the dashboard is open and requires `dashboard_admin` to configure. Use only where viewers need periodic refresh and the queries are bounded.
- **Dashboard data cache:** supported for table and indicator sources when `glide.analytics.cache.enabled=true`. New in-line dashboards do not enable caching by default unless the instance default property is changed. Choose a 1, 2, 4, 8, 12, or 24-hour expiry based on the business tolerance for staleness.
- **Visualization real-time or refresh-after-away:** use narrowly. These settings override caching for that visualization.

Scheduled repetition and dashboard caching are mutually exclusive. Do not change instance-wide cache or prefetch properties to optimize one dashboard. First reduce unnecessary data sources, broad conditions, groupings, dot-walks, tabs, and refresh frequency. Validate with representative data and inspect `dashboard_stats.list` for run count and recent runtime when usage evidence exists.

## Transport and Migration

For an in-line dashboard created or edited in a development instance:

1. Finish and save all tabs and content before unloading.
2. Open `par_dashboard_list.do`, open/select the exact dashboard, and choose **Unload Dashboard**. Ordinary update capture does not automatically include dashboard tabs.
3. Confirm the update set contains the dashboard structure, tabs, permissions/security configuration, settings, and saved visualizations or filters that the unload action includes. Ensure every other referenced artifact is already on the target or included through its supported delivery mechanism.
4. Preview on the target, resolve missing dependencies and scope errors without forcing, commit in dependency order, then test the real dashboard and personas. Scoped dashboards can expose mixed-scope dependencies; use separate coordinated update sets only when the preview evidence requires it.

Do not use this path for technical dashboards; their update-set transport is unsupported. Do not transport the output of a Core UI-to-Platform Analytics migration from non-production. Test migration in non-production, then run Migration Center against the production instance's own source content. Verify all migrated tabs, filters, visualizations, iframed compatibility content, links, and permissions. A migrated dashboard can be rolled back only through the supported rollback conditions; technical dashboards cannot be rolled back to Core UI.

## Success Dashboard Apps

- HR/ITSM Success Dashboard indicators are not ordinary `par_dashboard` dashboards. Verify them through Store app/scopes such as `sn_sd`, `sn_sd_common`, `sn_sd_hrsm`, `sn_sd_itsm`, navigation module `now/success-dashboard/home`, Success Dashboard tables (`sn_sd_*`), Self-Service Analytics tables (`ssa_*`), and PA jobs/indicators.
- In Vår Energi DEV on 2026-05-27, HR Success Dashboard indicators (`sn_sd_hrsm`), Success Dashboard Core (`sn_sd`), Success Dashboard Common (`sn_sd_common`), Self-Service Analytics Core (`sn_ssa_core`), PA Premium, PA, and HR PA content pack (`com.sn_hr_pa`) were installed. The `[SD HRSM] Daily Data Collection` and `[SD HRSM] Historic Data Collection` jobs existed but were inactive.
- For Vår Energi STRY0010074, the OOTB HR Analytics Center dashboards existed in DEV as `par_dashboard` records: `HR Agent`, `HR Case Dashboard`, `HR Manager`, `Human Resources Overview`, `Manager Dashboard`, and `SLA Dashboard`. The relevant HR PA data jobs were `[PA HR Case] Daily Data Collection` and `[PA HR Case] Historic Data Collection` in `sn_hr_pa`; both were inactive before activation on 2026-05-27.

## Indicator Backend Model

Platform Analytics still uses the Performance Analytics backend for indicators, sources, breakdowns, scores, and collection jobs. In the PDI, the key tables are:

- `pa_indicators`: automated, formula, manual, and external indicators. Important fields include `name`, `type`, `frequency`, `direction`, `unit`, `aggregate`, `cube`, `conditions`, `collect_records`, `show_realtime_score`, `formula`, and `scripted`.
- `pa_cubes`: indicator sources. Important fields include `name`, `facts_table`, `conditions`, `frequency`, and `calendar`.
- `sysauto_pa`: scheduled data collection jobs.
- `pa_job_indicators`: collection job to indicator relationships.
- `pa_scores_l1`: primary collected score rows used by current PA widgets. The `indicator` field stores the numeric `pa_indicators.id`, not the indicator `sys_id`.
- `pa_scores`: legacy/base score table; do not rely on manually inserting here for Platform Analytics widgets.

Indicator `type` values observed in the PDI:

- `1`: Automated
- `2`: Formula
- `3`: Manual

Useful reference values:

- Daily frequency: `10`
- Count aggregate: `1`
- Count unit `#`: `17b365e2d7320100ba986f14ce6103ad`
- Minimize direction: `2`
- Maximize direction: `3`

Official docs route new/migrated instances under **Platform Analytics Administration** for backend PA configuration. The old backend tables and jobs remain the implementation surface even when the dashboard UI is the newer Platform Analytics experience.

## Indicator Creation Pattern

Prefer reusing existing `pa_cubes` sources when they already encode the correct date-aware population. Sources are shared across many indicators and collection jobs query each source once, so duplicate sources add cost and make definitions drift.

Good reusable ITSM sources in Simen's PDI:

- `Incidents.Open`: table `incident`, daily source for records open during the collection day.
- `RequestedItems.Open`: table `sc_req_item`, daily source for records open during the collection day.
- `Incidents.New`, `Incidents.Closed`, `Incidents.Resolved`
- `RequestedItems.New`, `RequestedItems.Closed`

Create a narrow automated indicator on an existing source by setting:

```javascript
var indicator = new GlideRecord('pa_indicators');
indicator.initialize();
indicator.setValue('name', 'FFI - High priority open incidents');
indicator.setValue('label', 'High priority open incidents');
indicator.setValue('type', '1'); // Automated
indicator.setValue('frequency', '10'); // Daily
indicator.setValue('direction', '2'); // Minimize
indicator.setValue('unit', '17b365e2d7320100ba986f14ce6103ad'); // #
indicator.setValue('aggregate', '1'); // Count
indicator.setValue('cube', '<pa_cubes sys_id>');
indicator.setValue('conditions', 'priorityIN1,2^EQ');
indicator.setValue('collect_records', true);
indicator.setValue('show_realtime_score', true);
indicator.setValue('scripted', false);
indicator.setValue('precision', '0');
var indicatorId = indicator.insert();
```

`conditions` on the indicator are applied in addition to the source filter. Keep broad, reusable date logic on the source and metric-specific filters on the indicator.

Use formula indicators when the value is derived from other indicators, for example `([[Indicator A]] / [[Indicator B]]) * 100`. Avoid scripts, GlideRecords, or GlideAggregates in indicator formulas; official guidance calls out the performance cost. Use manual indicators only when humans will enter scores in the scoresheet; manual indicators have no indicator source and are not populated by collection jobs.

## Indicator Widgets

For indicator-backed Platform Analytics widgets, `par_dashboard_widget.component_props` uses `sourceType: "indicator"` rather than `sourceType: "table"`:

```json
{
  "dataSources": [{
    "allowRealTime": false,
    "allowTotalValue": true,
    "indicatorType": "1",
    "isScriptedIndicator": false,
    "label": "PA high priority incident backlog",
    "sourceType": "indicator",
    "uuid": {"indicator": "<pa_indicators sys_id>", "breakdowns": []},
    "preferredVisualizations": ["d24d53f60350de7a652caf3188a46ed2"],
    "id": "<base64 id>",
    "dataCategories": ["trend", "group", "simple"]
  }],
  "metrics": [{
    "dataSource": "<same datasource id>",
    "id": "<base64 metric id>",
    "aggregateIndicator": "",
    "frequency": 10,
    "axisId": "primary",
    "numberFormat": {"customFormat": true, "decimalPrecision": 0}
  }],
  "scoreType": null,
  "period": "M",
  "enableRealTimeUpdate": false,
  "enableDrilldown": true,
  "filterConfigurations": [],
  "followFilters": false,
  "showFilterIcon": false
}
```

For single score indicator widgets, use macroponent `d24d53f60350de7a652caf3188a46ed2`. Existing single-score indicator widgets in the PDI commonly use blank `aggregateIndicator`, `frequency=10`, `scoreType=null`, and `period=M`.

Do not enable real-time mode on indicator widgets that specify `metrics[0].aggregateIndicator`. Platform Analytics rejects that combination with "Invalid configuration. Indicators with aggregate are not supported for realtime." Keep `dataSources[0].allowRealTime=false`, `enableRealTimeUpdate=false`, and the indicator's `show_realtime_score=false` unless the widget is configured without an aggregate indicator.

Do not leave score-only indicator widgets wired to `@state.parFilters` unless a known-good indicator widget does so successfully. Workspace dashboard filters that target task tables can cause indicator score widgets to show "There is no data for the selected criteria." Use `filterConfigurations=[]`, `followFilters=false`, and `showFilterIcon=false` for shared PA score widgets that should show collected score history independent of the agent's table filters.

Do not replace personalized work widgets with PA indicators unless that is the intent. Dynamic filters such as "Me" and "One of My Groups" work well for real-time table-backed widgets, but scheduled PA score collection runs in a job/user context and can turn a personalized indicator into a global/admin-centered score. For agent dashboards, a good pattern is:

- table-backed widgets for "my work" and group queues
- PA indicator widgets for shared backlog/trend insights

## Indicator Verification

After creating indicators and widgets, verify all three layers:

1. Indicator metadata:
   - `pa_indicators.name`
   - `type=Automated`
   - expected `cube`
   - expected `conditions`
   - `show_realtime_score=false` when the dashboard widget uses an aggregate indicator
   - `collect_records=true`
   - `sys_scope`/`sys_package` are the intended app
2. Dashboard wiring:
   - `par_dashboard_widget.canvas` is the tab canvas, not the base canvas
   - `component` is the intended macroponent
   - `component_props.dataSources[0].sourceType == "indicator"`
   - `component_props.dataSources[0].uuid.indicator` matches the indicator sys_id
3. Runtime sanity:
   - run a matching `GlideAggregate` against the facts table using the source semantics plus indicator conditions
   - run the relevant `sysauto_pa` data collection job or create a narrow on-demand job for the new indicators
   - verify rows in `pa_scores_l1` using `pa_indicators.id`, and verify `pa_snapshots` if `collect_records=true`
   - narrow-check `sys_update_xml` rows for `pa_indicators_<sys_id>` and `par_dashboard_widget_<sys_id>`

Example verification query for the FFI high-priority incident indicator:

```javascript
var ga = new GlideAggregate('incident');
ga.addEncodedQuery('opened_atONToday@javascript:gs.beginningOfToday()@javascript:gs.endOfToday()^ORopened_at<javascript:gs.beginningOfToday()^resolved_atISEMPTY^ORresolved_at>javascript:gs.endOfToday()^state!=8^priorityIN1,2');
ga.addAggregate('COUNT');
ga.query();
if (ga.next()) gs.info(ga.getAggregate('COUNT'));
```

If the dashboard needs historical trends, create one on-demand historical `sysauto_pa` job for a bounded date range and relate the new indicators through `pa_job_indicators`. Do not run historical collection repeatedly for the same indicator/date range because it can delete and rebuild scores in the covered periods.

The UI's **Execute Now** action for `sysauto_pa` runs:

```javascript
current.update();
SncTriggerSynchronizer.executeNow(current);
```

For a demo dashboard, an idempotent on-demand collection job can be created as:

```javascript
var job = new GlideRecord('sysauto_pa');
job.initialize();
job.setValue('name', 'FFI Agent Dashboard Demo PA Collection');
job.setValue('active', true);
job.setValue('run_type', 'on_demand');
job.setValue('run_as', gs.getUserID()); // Or resolve the intended service account live by user_name.
job.setValue('collect', 'scores_text');
job.setValue('score_operator', 'relative');
job.setValue('score_relative_start', '7');
job.setValue('score_relative_start_interval', 'days');
job.setValue('score_relative_end', '0');
job.setValue('score_relative_end_interval', 'days');
var jobId = job.insert();
```

Then create one `pa_job_indicators` row per indicator with `job=<jobId>`, `indicator=<pa_indicators sys_id>`, `active=true`, `collect=1`, `collect_indicator=true`, and execute the job. Confirm collection by checking `pa_scores_l1.indicator=<pa_indicators.id>`.

## Dashboard Skeleton

Required starting values:

- `par_dashboard.grid`: `48`
- `par_dashboard.active`: `true`
- `par_dashboard.ready_to_migrate`: `Not Applicable`
- `par_dashboard_visibility.experience`: Platform Analytics page registry `08c73d60537101100834ddeeff7b1287`
- owner permission: `can_read=true`, `can_share=true`, `can_write=true`, `owner=true`; resolve `user` live by `user_name`
- metadata user fields: resolve `created_by_user` and `updated_by_user` live for the intended owner; do not embed a PDI user sys_id
- metadata `widgets_margin`: `$now-global-space--sm`
- metadata `po_project_id_list`: `[]`

The starter dashboard `Platform analytics dashboard test` showed this minimum captured pattern:

- dashboard
- metadata
- two canvases
- permission
- tab
- visibility
- one or more widgets
- optional `sys_translated` rows for translated dashboard name/description

## Common Macroponents

Use `sys_ux_macroponent` to resolve IDs when uncertain. Known IDs in the PDI:

- Heading: `1f6e0643eca7a637e36bd7833549ec9e`
- Single score: `d24d53f60350de7a652caf3188a46ed2`
- List: `7ff373544303121093711347efb8f23c`
- Vertical bar: `23051643b7e03010097cb81cde11a910`
- Horizontal bar: `85855283b7e03010097cb81cde11a91d`
- Pie Chart: `035b99ff532101102958ddeeff7b126a`
- Donut: `a2b0596cec6b9d49dd1ff9bf76b5084b`
- Line: `18ac962264404bcc0039359d184b15f3`

## Widget `component_props` Pattern

For table-backed widgets, `component_props` is JSON with:

- `configVersion`: `23.0.0-ci-SNAPSHOT`
- `dataSources[0].sourceType`: `table`
- `dataSources[0].tableOrViewName`: target table such as `sys_user`
- `dataSources[0].filterQuery`: encoded query
- `dataSources[0].preferredVisualizations`: array containing the widget macroponent sys_id
- `dataSources[0].dataCategories`: `["trend","group","simple"]`
- `metrics[0].aggregateFunction`: usually `COUNT`
- `groupBy`: `null` for single score, or a `groupByField` config for grouped charts
- `filterConfigurations`: `@state.parFilters`
- `enableDrilldown`: `true`

For PA List widgets, use the List macroponent and keep the same table-backed data source pattern, plus list-specific fields:

- `table`: target table such as `incident`
- `columns`: comma-separated field list
- `limit`: practical row count such as `10`
- `showLinks`: `true`
- `showViewAll`: `true`
- `allowListPagination`: `true`
- `showColumnSorting`: `true`

Generate unique, deterministic IDs for `dataSources[0].id`, `metrics[0].id`, and `componentId`; consistent normalized strings are sufficient and base64 strings are also accepted. If a same-release pattern specifically calls for base64, run it from a context where the API is available and coerce Java strings before JavaScript regex replacement in Rhino:

```javascript
String(GlideStringUtil.base64Encode('table:sys_user:Active users')).replace(/=/g, '')
```

Avoid Java `String.replace(regex, value)` ambiguity by using `String(...)` around GlideStringUtil returns.

## ITIL Agent Dashboard Pattern

For fulfiller/ITIL agent dashboards, frame the dashboard around "What needs my attention now?" rather than a flat collection of lists. Keep personal action, group pickup work, SLA risk, urgent priority, and cleanup/waiting work visually distinct.

An attention-first 48-column layout works well:

- `y=0`: Heading across `w=48`, `h=3`
- `y=3`: six KPI counters, each `w=8`, `h=7`
- `y=10`: two primary action lists, each `w=24`, `h=16`
- `y=26`: two SLA/priority focus lists, each `w=24`, `h=16`
- `y=42`: two cleanup/waiting lists, each `w=24`, `h=16`
- `y=58`: two control lists, each `w=24`, `h=16`

Recommended KPI counters:

- score: my open incidents, table `incident`, filter `assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe^stateNOT IN6,7,8`
- score: my request work, table `task`, filter `sys_class_nameINsc_req_item,sc_task^assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe^active=true`
- score: my interactions, table `interaction`, filter `assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe^active=true`
- score: unassigned in my groups, table `task`, filter `assignment_groupDYNAMICd6435e965f510100a9ad2572f2b47744^assigned_toISEMPTY^active=true^sys_class_nameINincident,sc_req_item,sc_task,interaction`
- score: breaching soon, table `task_sla`, filter `stageINin_progress,paused^planned_end_timeRELATIVELE@hour@ahead@4`
- score: P1/P2 active, table `task`, filter `priorityIN1,2^active=true^sys_class_nameINincident,sc_req_item,sc_task,interaction`

Recommended attention lists:

- list: my assigned work, table `task`, filter `assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe^active=true^sys_class_nameINincident,sc_req_item,sc_task,interaction^ORDERBYDESCpriority^ORDERBYsys_updated_on`
- list: my group's unassigned work, table `task`, filter `assignment_groupDYNAMICd6435e965f510100a9ad2572f2b47744^assigned_toISEMPTY^active=true^sys_class_nameINincident,sc_req_item,sc_task,interaction^ORDERBYDESCpriority^ORDERBYopened_at`
- list: SLA breaching soon, table `task_sla`, filter `stageINin_progress,paused^planned_end_timeRELATIVELE@hour@ahead@4^ORDERBYplanned_end_time`
- list: high priority active records, table `task`, filter `priorityIN1,2^active=true^sys_class_nameINincident,sc_req_item,sc_task,interaction^ORDERBYpriority^ORDERBYsys_updated_on`
- list: stale work, table `task`, filter `assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe^active=true^sys_class_nameINincident,sc_req_item,sc_task,interaction^sys_updated_onRELATIVELE@dayofweek@ago@2^ORDERBYsys_updated_on`
- list: waiting/on hold, table `task`, filter `assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe^active=true^stateIN3,4,-5^sys_class_nameINincident,sc_req_item,sc_task,interaction^ORDERBYsys_updated_on`
- list: recently updated by me, table `task`, filter `sys_updated_by=admin^sys_updated_onRELATIVEGE@dayofweek@ago@7^sys_class_nameINincident,sc_req_item,sc_task,interaction^ORDERBYDESCsys_updated_on`
- list: reopened incidents, table `incident`, filter `reopen_count>0^active=true^ORDERBYDESCreopen_count^ORDERBYsys_updated_on`

Useful generic task columns: `number,sys_class_name,priority,state,short_description,assigned_to,assignment_group,sys_updated_on`.

Known dynamic filter IDs:

- Me: `90d1921e5f510100a9ad2572f2b477fe`
- One of My Groups: `d6435e965f510100a9ad2572f2b47744`

## User Analytics Query Examples

Useful `sys_user` encoded queries:

- Active users: `active=true`
- New users this month: `sys_created_onONThis month@javascript:gs.beginningOfThisMonth()@javascript:gs.endOfThisMonth()^EQ`
- Users without manager: `managerISEMPTY`
- Users without department: `departmentISEMPTY`
- Active users by department: filter `active=true^departmentISNOTEMPTY`, group by `department`
- Active users by company: filter `active=true^companyISNOTEMPTY`, group by `company`
- Users by location: filter `locationISNOTEMPTY`, group by `location`
- Users by country: filter `countryISNOTEMPTY`, group by `country`
- Active vs inactive users: group by `active`
- Users created per month: filter `sys_created_onONLast 12 months@javascript:gs.monthsAgoStart(12)@javascript:gs.endOfThisMonth()^EQ`, group by `sys_created_on`

## Pitfalls

- Do not pass only `-Name` to `Set-ServiceNowUpdateSetContext.ps1` when the user named an existing update set; it will create a duplicate. Resolve and pass `-UpdateSetSysId`.
- Do not create duplicate dashboards if a script partially succeeds. Re-run idempotently: find the dashboard by exact name, find existing tab/canvases/metadata/permission/visibility, and only add missing widgets when `par_dashboard_widget` count is zero.
- For existing workspace dashboards, do not require widget count to be zero before proceeding. Repurpose known starter widgets by `sys_id`, then upsert new named widgets so reruns converge.
- Table shape helpers may report `create_access=false` on some `par_` tables, but admin/Xplore can still insert the builder-owned records. Keep writes narrow and verify capture immediately.
- `required_translations` can be minimal JSON messages for the title and empty state; `sys_translated` rows are not always necessary for created widgets.
- Workspace page registry path, UX app route path, and PA dashboard deep-link URLs can be non-obvious or unavailable from guessed URLs. Do not treat a browser 404 on a guessed `/now/<path>` route as dashboard failure; verify the PA records and widget data source queries first, then use known navigation if a visual check is required.
- Generated workspace update sets can already contain global AI Search rows and lots of UX scaffold rows. Report this as pre-existing mixed-scope workspace generation noise when dashboard-specific rows are captured in the intended app.
