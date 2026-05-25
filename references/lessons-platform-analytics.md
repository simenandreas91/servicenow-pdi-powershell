# Platform Analytics Dashboard Lessons

Use this when creating or modifying Platform Analytics dashboards (`par_dashboard`) in Simen's PDI. Prefer the UI when visual placement must be hand-tuned, but Table API plus Xplore is fast and reliable for repeatable dashboard creation after one good dashboard pattern is known.

## Fast Workflow

1. Resolve the intended update set by `sys_id`, not only by name. `Set-ServiceNowUpdateSetContext.ps1 -Name` creates a new update set; use `-UpdateSetSysId` when continuing an existing one.
2. Inspect a known-good dashboard's captured `sys_update_xml` rows first. For Platform Analytics, the payload reveals the exact `component_props` JSON that the builder saves.
3. When modifying a workspace-generated dashboard, reuse the existing `par_dashboard`, `par_dashboard_tab`, and tab canvas. The workspace scaffold may already have a small default widget set; update those widgets by `sys_id` and add only the missing widgets by stable `name`.
4. Create or reuse these records in Global unless the inspected dashboard or existing workspace scope proves otherwise:
   - `par_dashboard`
   - `par_dashboard_tab`
   - `par_dashboard_canvas` twice: one base canvas with no tab and one tab canvas
   - `par_dashboard_user_metadata`
   - `par_dashboard_permission`
   - `par_dashboard_visibility`
   - `par_dashboard_widget` per visualization
5. Put widgets on the tab canvas, not the base canvas.
6. Verify with Xplore by parsing every widget's `component_props`, counting widgets via `canvas.dashboard`, and running matching `GlideAggregate` checks for KPI filters.
7. For a generated workspace update set, a broad `Confirm-ServiceNowUpdateCapture.ps1` may report pre-existing mixed-scope rows. Narrow-check dashboard rows in `sys_update_xml` by `nameSTARTSWITHpar_dashboard` and by widget `target_nameLIKE<stable prefix>`.
8. Restore preferences.

## Indicator Backend Model

Platform Analytics still uses the Performance Analytics backend for indicators, sources, breakdowns, scores, and collection jobs. In the PDI, the key tables are:

- `pa_indicators`: automated, formula, manual, and external indicators. Important fields include `name`, `type`, `frequency`, `direction`, `unit`, `aggregate`, `cube`, `conditions`, `collect_records`, `show_realtime_score`, `formula`, and `scripted`.
- `pa_cubes`: indicator sources. Important fields include `name`, `facts_table`, `conditions`, `frequency`, and `calendar`.
- `sysauto_pa`: scheduled data collection jobs.
- `pa_job_indicators`: collection job to indicator relationships.
- `pa_scores`: collected score rows.

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
    "allowRealTime": true,
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
    "aggregateIndicator": "1d7a2073eb21020065deac6aa206fe5c",
    "frequency": 10,
    "frequencyInterval": "DAY",
    "axisId": "primary",
    "numberFormat": {"customFormat": true, "decimalPrecision": 0}
  }],
  "scoreType": "latest",
  "period": "D",
  "enableRealTimeUpdate": true,
  "enableDrilldown": true,
  "filterConfigurations": "@state.parFilters"
}
```

For single score indicator widgets, use macroponent `d24d53f60350de7a652caf3188a46ed2`. Existing indicator widgets in the PDI commonly use aggregate indicator `1d7a2073eb21020065deac6aa206fe5c` (`By month SUM +`) even when the score card shows the latest score.

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
   - `show_realtime_score=true`
   - `collect_records=true`
   - `sys_scope`/`sys_package` are the intended app
2. Dashboard wiring:
   - `par_dashboard_widget.canvas` is the tab canvas, not the base canvas
   - `component` is the intended macroponent
   - `component_props.dataSources[0].sourceType == "indicator"`
   - `component_props.dataSources[0].uuid.indicator` matches the indicator sys_id
3. Runtime sanity:
   - run a matching `GlideAggregate` against the facts table using the source semantics plus indicator conditions
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

## Dashboard Skeleton

Required starting values:

- `par_dashboard.grid`: `48`
- `par_dashboard.active`: `true`
- `par_dashboard.ready_to_migrate`: `Not Applicable`
- `par_dashboard_visibility.experience`: Platform Analytics page registry `08c73d60537101100834ddeeff7b1287`
- owner permission: `can_read=true`, `can_share=true`, `can_write=true`, `owner=true`, `user=6816f79cc0a8016401c5a33be04be441`
- metadata user fields: `created_by_user` and `updated_by_user` should use Simen Admin `6816f79cc0a8016401c5a33be04be441`
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

Generate unique but stable-looking IDs for `dataSources[0].id`, `metrics[0].id`, and `componentId`; base64 strings are accepted. Coerce Java strings before JavaScript regex replacement in Rhino:

```javascript
String(GlideStringUtil.base64Encode('table:sys_user:Active users')).replace(/=/g, '')
```

Avoid Java `String.replace(regex, value)` ambiguity by using `String(...)` around GlideStringUtil returns.

## ITIL Agent Dashboard Pattern

For agent-facing work dashboards, a compact 48-column layout works well:

- `y=0`: Heading across `w=48`, `h=3`
- `y=3`: four single scores, each `w=12`, `h=8`
- `y=11`: three charts, each `w=16`, `h=14`
- `y=25`: two worklists, each `w=24`, `h=18`
- `y=43`: one full-width queue list, `w=48`, `h=16`

Useful ITIL widgets:

- score: my active incidents, table `incident`, filter `active=true^assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe`
- score: my open request items, table `sc_req_item`, filter `active=true^assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe`
- score: my active interactions, table `interaction`, filter `active=true^assigned_toDYNAMIC90d1921e5f510100a9ad2572f2b477fe`
- score: high priority incidents, table `incident`, filter `active=true^priorityIN1,2`
- bar: incident queue by priority, table `incident`, filter `active=true^assignment_groupDYNAMICd6435e965f510100a9ad2572f2b47744`, group by `priority`
- bar: request items by stage, table `sc_req_item`, filter `active=true^assignment_groupDYNAMICd6435e965f510100a9ad2572f2b47744`, group by `stage`
- donut: interactions by state, table `interaction`, filter `active=true`, group by `state`
- list: my incident worklist, columns `number,priority,state,short_description,caller_id,sys_updated_on`
- list: my request item worklist, columns `number,stage,cat_item,request,requested_for,short_description,sys_updated_on`
- list: group interaction queue, columns `number,state,type,opened_for,short_description,assigned_to,opened_at`

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
