# ServiceNow SLA Query and Validation Library

## Use and safety

Use these patterns with `sla.md`.

- Q00-Q09 are read-only.
- Replace every `CHANGE_ME_*` value and resolve every sys_id live from a stable name/key.
- Run against PDI/DEV first. Keep production diagnosis selective and read-only.
- Use `Get-ServiceNowTableShape.ps1` before relying on release-sensitive fields.
- Do not insert, update, delete, or repair `task_sla` rows directly.
- Definition, schedule, flow, property, plugin, and repair changes are writes and require the skill's update-set/safety workflow.
- Do not print unrestricted task payloads, journal contents, personal data, notification bodies, or secrets.

## Q00 — Preflight release, plugin, engine, roles, and schema

```powershell
$skillRoot = 'C:\Users\simen\.codex\skills\servicenow-pdi'

& "$skillRoot/scripts/Get-ServiceNowPdiHealth.ps1" -Profile pdi

foreach ($table in @(
    'contract_sla',
    'task_sla',
    'sla_condition_class',
    'sla_repair_log',
    'sla_repair_log_entry',
    'cmn_schedule',
    'cmn_schedule_span',
    'cmn_relative_duration',
    'sysauto_script'
)) {
    & "$skillRoot/scripts/Get-ServiceNowTableShape.ps1" -Profile pdi -Table $table
}
```

If the named profile has no instance, pass the intentional `-Instance` URL after verifying the target. A 401 is a credential/access failure, not evidence that SLM is absent.

Inspect installed plugins without activating anything:

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table sys_plugins `
  -Query 'idINcom.snc.sla,com.snc.sla.breakdowns,com.sn_slm_timer,com.snc.service_level_management.atf' `
  -Fields 'id,name,active,version' -Limit 20 -ExcludeReferenceLink
```

Inspect engine and repair properties:

```powershell
$names = @(
  'com.snc.sla.engine.version',
  'com.snc.sla.engine.async',
  'com.snc.sla.compatibility.breach',
  'com.snc.sla.calculation.percentage',
  'com.snc.sla.maximum_duration',
  'com.snc.sla.workflow.run_for_breached',
  'com.snc.sla.calculate_planned_end_time_after_breach',
  'com.snc.sla.calculation.use_time_left',
  'glide.sla.calculate_on_display',
  'com.snc.sla.always_populate_business_fields',
  'com.snc.sla.repair.enabled'
) -join ','

& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table sys_properties -Query "nameIN$names" `
  -Fields 'name,value,description,sys_updated_on' -Limit 50 -ExcludeReferenceLink
```

Absence can mean a default, upgraded-instance lineage, or unavailable feature. Verify the current Australia documentation and plugin before creating a missing property.

## Q01 — Inventory definitions for a target table and likely ancestors

Start with the exact table and manually verified ancestors. Do not query every `contract_sla` row.

```powershell
$tables = 'CHANGE_ME_TABLE,CHANGE_ME_PARENT_TABLE'

& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table contract_sla `
  -Query "collectionIN$tables^ORDERBYcollection^ORDERBYname" `
  -Fields 'sys_id,name,active,collection,type,target,duration,schedule,start_condition,stop_condition,pause_condition,flow,workflow,sys_domain,sys_scope,sys_package,sys_updated_on' `
  -Limit 200 -ExcludeReferenceLink
```

This first query intentionally uses a conservative core. Field names for duration type, schedule source, time-zone source, cancel/resume/reset, and retroactive settings vary across releases and condition implementations. Use Q00 table shape to resolve their physical names, then add only verified fields. Compare active and inactive definitions; an inactive near-match may be the correct reusable artifact.

Inspect choices before setting stored values:

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table sys_choice `
  -Query 'name=contract_sla^elementINtype,target,when_to_cancel,when_to_resume,reset_action,schedule_source,timezone_source^inactive=false^ORDERBYelement^ORDERBYsequence' `
  -Fields 'element,label,value,sequence,inactive' -Limit 200 -ExcludeReferenceLink

& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table sys_choice `
  -Query 'name=task_sla^elementINstage,has_breached^inactive=false^ORDERBYelement^ORDERBYsequence' `
  -Fields 'element,label,value,sequence,inactive' -Limit 100 -ExcludeReferenceLink
```

## Q02 — Inspect one definition, its schedule, and automation references

Resolve the definition by exact name plus table and domain/scope if needed:

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table contract_sla `
  -Query 'name=CHANGE_ME_EXACT_NAME^collection=CHANGE_ME_TABLE' `
  -Fields 'sys_id,name,active,collection,type,target,duration,schedule,start_condition,stop_condition,pause_condition,flow,workflow,sys_domain,sys_scope,sys_package,sys_updated_on' `
  -Limit 10 -ExcludeReferenceLink
```

If more than one result returns, stop and disambiguate domain/scope rather than selecting an arbitrary sys_id. Then use the Q00 dictionary output to query the release's verified physical fields for duration type; relative duration; schedule source/field; time-zone source/value; cancel/resume/reset; condition type; retroactive start/set-start-to/pause; override; vendor; service commitment; and logging.

Inspect the resolved fixed schedule:

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table cmn_schedule -Query 'name=CHANGE_ME_SCHEDULE_NAME' `
  -Fields 'sys_id,name,time_zone,type,parent,description,sys_scope,sys_updated_on' `
  -Limit 20 -ExcludeReferenceLink

& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table cmn_schedule_span -Query 'schedule=CHANGE_ME_RESOLVED_SCHEDULE_SYS_ID^ORDERBYstart_date_time' `
  -Fields 'name,type,schedule,start_date_time,end_date_time,repeat_type,repeat_count,repeat_until,float_day,show_as,sys_updated_on' `
  -Limit 200 -ExcludeReferenceLink
```

Schedule-entry fields vary; inspect shape and parent/child schedule behavior. The list must account for holidays/exclusions, not only recurring weekday spans.

Resolve Flow/Workflow by stable name, then inspect its active/published state through the supported builder/table for the installed version. Never carry a base flow sys_id from documentation or another instance.

## Q03 — Preview condition overlap against representative tasks

This read-only Xplore script evaluates snapshot-compatible encoded conditions for a small task sample. It cannot faithfully replay `changes`, `changes to/from`, advanced journal/system conditions, historical dot-walk values, custom condition classes, domain overrides, or full engine precedence. Use it only to find likely overlap, then prove behavior with SLA Timeline and a real task update.

```javascript
(function () {
    var taskTable = 'CHANGE_ME_TASK_TABLE';
    var taskQuery = 'CHANGE_ME_SELECTIVE_TASK_QUERY';
    var definitionTables = ['CHANGE_ME_TASK_TABLE', 'CHANGE_ME_VERIFIED_PARENT_TABLE'];
    var maxTasks = 20;

    var tasks = new GlideRecord(taskTable);
    tasks.addEncodedQuery(taskQuery);
    tasks.orderByDesc('sys_updated_on');
    tasks.setLimit(maxTasks);
    tasks.query();

    while (tasks.next()) {
        var matches = [];
        var defs = new GlideRecord('contract_sla');
        defs.addQuery('active', true);
        defs.addQuery('collection', 'IN', definitionTables.join(','));
        defs.orderBy('name');
        defs.setLimit(200);
        defs.query();

        while (defs.next()) {
            var start = defs.getValue('start_condition') || '';
            var stop = defs.getValue('stop_condition') || '';
            var cancel = defs.isValidField('cancel_condition') ? (defs.getValue('cancel_condition') || '') : '';
            var dynamicOperator = /(^|\^)([^\^]+)(CHANGES|CHANGESTO|CHANGESFROM)/i.test(start + '^' + stop + '^' + cancel);

            if (dynamicOperator) {
                gs.info('MANUAL TIMELINE REQUIRED task=' + tasks.getUniqueValue() +
                    ' definition=' + defs.getDisplayValue() + ' reason=change operator');
                continue;
            }

            var startMatches = !start || GlideFilter.checkRecord(tasks, start, true);
            var stopMatches = !!stop && GlideFilter.checkRecord(tasks, stop, true);
            var cancelMatches = !!cancel && GlideFilter.checkRecord(tasks, cancel, true);

            if (startMatches && !stopMatches && !cancelMatches)
                matches.push(defs.getDisplayValue() + ' [' + defs.getUniqueValue() + ']');
        }

        gs.info('TASK ' + tasks.getDisplayValue() + ' | possible_attach=' + matches.length +
            ' | ' + matches.join(' ; '));
    }
})();
```

Expected use: a task that represents one exclusive commitment should normally show one candidate for that commitment. Multiple candidates require an explicit concurrency/override/exclusion decision.

## Q04 — Inspect Task SLAs attached to one task

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table task_sla -Query 'task=CHANGE_ME_TASK_SYS_ID^ORDERBYstart_time' `
  -Fields 'sys_id,number,task,sla,stage,active,has_breached,start_time,stop_time,planned_end_time,original_breach_time,duration,pause_duration,business_duration,business_elapsed_time,business_time_left,business_percentage,percentage,timezone,schedule,flow_context,sys_created_on,sys_updated_on' `
  -Limit 100 -ExcludeReferenceLink
```

Verify:

- exact definition and task;
- one attachment unless Reset or intentional concurrent definitions explain more;
- stage/active combination;
- start/stop/planned end/original breach;
- actual versus business elapsed/left;
- pause duration;
- breach flag;
- schedule/time zone and automation context where fields exist.

Use table shape to correct release-specific field names. Do not infer achievement from `stage=Completed` alone.

## Q05 — Detect duplicate/unexpected active timers for a bounded population

```javascript
(function () {
    var taskTable = 'CHANGE_ME_TASK_TABLE';
    var taskQuery = 'CHANGE_ME_SELECTIVE_TASK_QUERY';
    var maxTasks = 100;

    var tasks = new GlideRecord(taskTable);
    tasks.addEncodedQuery(taskQuery);
    tasks.orderByDesc('sys_updated_on');
    tasks.setLimit(maxTasks);
    tasks.query();

    while (tasks.next()) {
        var agg = new GlideAggregate('task_sla');
        agg.addQuery('task', tasks.getUniqueValue());
        agg.addQuery('active', true);
        agg.addAggregate('COUNT');
        agg.groupBy('sla');
        agg.query();

        var activeDefinitions = 0;
        while (agg.next()) {
            activeDefinitions++;
            var count = parseInt(agg.getAggregate('COUNT'), 10);
            if (count > 1)
                gs.info('DUPLICATE ACTIVE TASK SLA task=' + tasks.getDisplayValue() +
                    ' definition=' + agg.getDisplayValue('sla') + ' count=' + count);
        }

        if (activeDefinitions > 1)
            gs.info('MULTIPLE ACTIVE DEFINITIONS task=' + tasks.getDisplayValue() +
                ' definition_count=' + activeDefinitions + ' (review whether intentional)');
    }
})();
```

This identifies symptoms only. Inspect Reset, repair, concurrent saves, definition overlap, domains, and intended SLA/OLA combinations before changing anything.

## Q06 — Inspect scheduled calculation jobs and recent execution state

Resolve names live because job tables/fields vary by release:

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table sysauto_script `
  -Query 'nameSTARTSWITHSLA update^ORDERBYname' `
  -Fields 'sys_id,name,active,run_type,run_time,run_period,next_action,last_error_message,sys_updated_on' `
  -Limit 50 -ExcludeReferenceLink
```

Documented jobs refresh timings for already-breached, breach-after-30-days, within-30-days, within-1-day, within-1-hour, and within-10-minutes populations. Do not execute or reschedule a job merely because one displayed percentage is old.

## Q07 — Inspect definition-level and engine logging safely

First inspect whether the exact definition has `Enable logging` active; do not enable it yet. Then query a narrow recent time window and known SLA/task correlation in system logs using the installed log fields. Avoid broad log dumps.

Useful global logging properties are:

```text
com.snc.sla.task_sla_controller.log
com.snc.sla.task_sla.log
com.snc.sla.condition.log
com.snc.sla.workflow.log
com.snc.sla.calculatorng.log
com.snc.sla.repair.log
com.snc.sla.log.destination
```

Prefer temporary definition-level logging in non-production. If a global log level is genuinely required, snapshot it, time-box the change, reproduce once, collect only relevant rows, and restore it.

## Q08 — Inspect repair scope and logs without running repair

Preview the exact task population first:

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table CHANGE_ME_TASK_TABLE -Query 'CHANGE_ME_EXACT_REPAIR_FILTER' `
  -Fields 'sys_id,number,sys_class_name,active,state,sys_created_on,sys_updated_on' `
  -Limit 100 -ExcludeReferenceLink
```

If the candidate count can exceed the helper limit, use a bounded aggregate through Xplore and state the maximum affected rows before approval.

Inspect existing repair logs:

```powershell
& "$skillRoot/scripts/Invoke-ServiceNowTable.ps1" -Profile pdi `
  -Table sla_repair_log -Query 'sys_created_on>=javascript:gs.daysAgoStart(30)^ORDERBYDESCsys_created_on' `
  -Fields 'sys_id,source_table,filter,state,started,ended,sys_created_by,sys_created_on' `
  -Limit 50 -ExcludeReferenceLink
```

Resolve repair-log-entry fields with table shape, then query only entries related to one resolved repair log. Before-only can mean a Task SLA was removed; after-only can mean one was created. Do not invoke `SLARepair.repairByFilter` as a diagnostic.

## Q09 — Post-create or post-change verification checklist

Run and record each relevant layer:

```text
Configuration
[ ] exact contract_sla re-read by resolved sys_id
[ ] active, table, Type, Target, duration type/value
[ ] schedule source/schedule and time-zone source/value
[ ] Start/Cancel/Pause/Resume/Stop/Reset and their methods/actions
[ ] Flow XOR Workflow, domain, scope, package

Collision
[ ] exact and ancestor definitions inventoried
[ ] representative Start-filter preview
[ ] intended concurrent definitions documented

Behavior
[ ] negative task does not attach
[ ] positive task attaches exactly one intended Task SLA
[ ] planned end manually reconciled to schedule/holiday/time zone
[ ] pause/resume and stop verified where configured
[ ] cancel/reset verified where configured
[ ] breach flag and Completed stage interpreted separately

Automation
[ ] flow context and milestone event
[ ] correct notification recipients/content
[ ] no duplicate mail/event/external action

Channel/security
[ ] intended UI16/Workspace/Portal visibility
[ ] intended fulfiller role
[ ] unauthorized persona denied protected details

Delivery/cleanup
[ ] expected update-set or SDK artifacts only
[ ] test tasks, Task SLAs, flows, events, and emails accounted for
[ ] preferences restored
[ ] rollback/deactivation and repair scope documented
```

## Official references

- [Create an SLA definition](https://www.servicenow.com/docs/r/it-service-management/service-level-management/t_CreateAnSLADefinition.html)
- [SLA processing](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_SLAProcessing.html)
- [SLA duration types](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_SLADuration.html)
- [Task SLA table](https://www.servicenow.com/docs/r/it-service-management/service-level-management/r_TaskSLATable.html)
- [SLA Timeline validation](https://www.servicenow.com/docs/r/it-service-management/service-level-management/validate-new-sla-definition.html)
- [Scheduled jobs for SLA](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_ScheduledJobsForSLA.html)
- [SLA Repair](https://www.servicenow.com/docs/r/it-service-management/service-level-management/r_ManageSLARepair.html)
- [Quick start tests for SLM](https://www.servicenow.com/docs/r/it-service-management/service-level-management/quick-start-tests-sla.html)
