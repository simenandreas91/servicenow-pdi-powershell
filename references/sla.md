# ServiceNow Service Level Management Runbook

## Purpose and baseline

Use this guide to design, create, diagnose, test, transport, and operate ServiceNow SLA definitions, OLAs, and underpinning contracts. Load `sla-query-library.md` only when the task needs its bounded live inspection commands or scripts. Product- or customer-specific guidance supplements this runbook but does not replace it.

The research baseline is ServiceNow **Australia (2026)** and the 2011 SLA engine. Release, patch, Store-app version, plugins, roles, table fields, choices, schedules, flows, domain behavior, and application scope must still be verified on the target instance. Official anchors:

- [Create an SLA definition](https://www.servicenow.com/docs/r/it-service-management/service-level-management/t_CreateAnSLADefinition.html)
- [SLA processing](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_SLAProcessing.html)
- [SLA conditions](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_SLAConditions.html)
- [SLA duration types](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_SLADuration.html)
- [Schedules within SLA](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_SLASchedule.html)
- [Time zones in SLAs](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_TimeZonesInSLAs.html)
- [Task SLA table](https://www.servicenow.com/docs/r/it-service-management/service-level-management/r_TaskSLATable.html)
- [SLA Timeline](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_SLATimeline.html)
- [Repair SLAs](https://www.servicenow.com/docs/r/it-service-management/service-level-management/c_RepairSLAs.html)
- [Flows for SLA](https://www.servicenow.com/docs/r/it-service-management/service-level-management/flows-for-sla.html)
- [SLA engine properties](https://www.servicenow.com/docs/r/it-service-management/service-level-management/t_ConfigureSLAProperties.html)
- [ServiceNow Fluent SLA API](https://www.servicenow.com/docs/r/application-development/servicenow-sdk/fluent-sla-api.html)

## Operating contract

For every SLA request:

1. State the target environment, release, table, business service/process, consumer, owner, and whether the task is analysis, implementation, repair, or reporting.
2. Translate the requirement into an unambiguous promise: response or resolution event, duration in running hours, schedule, time zone, pause ownership, exclusions, breach behavior, and escalation recipients.
3. Inspect the target table, its state model, existing active definitions on it and its ancestors, schedules, flows/workflows, choices, roles, domains, application scope, and current update set before writing.
4. Prefer one narrow OOTB SLA definition and an SLA flow. Add scripts, advanced conditions, custom condition classes, or engine properties only when declarative configuration cannot express a material requirement.
5. Create inactive-first when possible. Validate the definition against existing task history in SLA Timeline, then test a real disposable task in PDI/DEV.
6. Prove attachment and every configured transition from the final `task_sla` record, not from the definition form alone.
7. Confirm update capture/application scope. Transport definitions, schedules, flows, and supporting metadata; never transport runtime `task_sla` or repair-log data.
8. Repair existing Task SLAs only when the requirement includes historical correction, after a count/sample, side-effect review, and explicit approval for the affected environment.

## 1. Mental model and data model

### 1.1 Promise, definition, and runtime record

Keep three layers distinct:

1. **Service promise:** what the customer or internal team is entitled to and how achievement is measured.
2. **SLA Definition [`contract_sla`]:** configuration containing table, conditions, duration, schedule/time zone, flow/workflow, and reporting classifications.
3. **Task SLA [`task_sla`]:** runtime record attached by the engine to one task for one definition. It contains stage, start/stop/planned-end times, elapsed values, pause duration, breach state, definition, and task references.

One task can legitimately have several Task SLAs—for example an external resolution SLA and an internal OLA—but every concurrent timer must represent a named commitment. Do not use overlapping definitions as a substitute for priority logic.

Common supporting records:

| Purpose | Table / record |
| --- | --- |
| Definition | SLA Definition [`contract_sla`] |
| Runtime attachment | Task SLA [`task_sla`] |
| Condition-transition implementation | SLA Conditions [`sla_condition_class`] |
| Working calendar | Schedule [`cmn_schedule`] and Schedule Entry [`cmn_schedule_span`] |
| Relative cutoff logic | Relative Duration [`cmn_relative_duration`] |
| Modern automation | Flow [`sys_hub_flow`] and its runtime contexts/events |
| Legacy automation | Workflow [`wf_workflow`] and contexts; retain only where already required |
| Repair audit | SLA Repair Log [`sla_repair_log`] and SLA Repair Log Entry [`sla_repair_log_entry`] |
| Preferred timer display | SLA Timer Configuration [`sla_timer_config`] and mapping [`sla_timer_config_mapping`] when the timer plugin is installed |
| Assignment accountability | SLA breakdown tables when `com.snc.sla.breakdowns` is installed |

Resolve all fields live with `sys_db_object`, `sys_dictionary`, and `sys_choice`. Do not infer a stored choice value from its label.

### 1.2 SLA, OLA, underpinning contract, Target, and Service Commitment

- **SLA:** service provider commitment to an external customer.
- **OLA:** internal agreement between teams supporting the SLA.
- **Underpinning contract:** vendor commitment supporting the delivered service.
- **Type** is a reporting classification; it does not change condition processing.
- **Target** (`response`, `resolution`, or none where available) is also for filtering/reporting. A response target does not detect a response unless the Stop condition describes the response event.
- **Service Commitment** distinguishes a normal definition from a service-offering definition where the product model supports it. Inspect the service/offering relationship and installed behavior before using it.

## 2. How the SLA engine behaves

The engine evaluates task inserts and updates in two conceptual passes.

### 2.1 New definitions without an active Task SLA

1. If Start and Stop are both true, it does not attach; Stop wins.
2. If Start is true and Stop is false, it creates a Task SLA in `In progress`.
3. Cancel conditions can also prevent attachment under the selected condition method; verify the installed condition-class behavior in Timeline.

### 2.2 Existing active Task SLAs

The documented processing order is:

1. Stop true -> `Completed`, inactive.
2. Reset and Start true -> finish the current Task SLA according to Reset action and attach a new one.
3. Cancel true, or Start false when configured to cancel on start no longer matching -> `Cancelled`, inactive.
4. Pause true while In progress -> `Paused`.
5. Resume rule satisfied while Paused -> `In progress`.

The normal 2011-engine stages are `In progress`, `Paused`, `Completed`, and `Cancelled`. Breach is normally a flag/timing outcome, not a fifth stage. The legacy `Breached` stage appears only with the 2010 engine or compatibility mode. A completed SLA may therefore be completed after it breached; report achievement using the breach flag and timing fields, not the stage alone.

The synchronous `Run SLAs` Business Rule is the documented default and recommended user experience. `com.snc.sla.engine.async=true` is a performance exception; it creates a short delay before Task SLA attachments/changes appear. Do not enable it to work around a bad definition.

## 3. Designing the definition

### 3.1 Requirement worksheet

Complete this before configuration:

```text
Business service/process:
Consumer and commitment owner:
Agreement type: SLA | OLA | Underpinning contract
Target/reporting label: Response | Resolution | None
Tracked task table and child-table scope:
Start event and eligibility:
When start stops being true: cancel | remain active | explicit cancel condition
Pause reason(s) and who controls them:
Resume behavior:
Success/stop event:
Reset event and whether old Task SLA completes or cancels:
Duration: running hours/minutes, never ambiguous "business days"
Duration type: fixed | relative cutoff
Schedule source and schedule owner:
Time-zone source and fallback:
Retroactive start field and retroactive pause requirement:
Flow milestones, recipients, and side effects:
Required concurrent commitments:
Definitions that must not overlap:
Domain and application scope:
Acceptance tests and rollback/deactivation:
```

If the requirement says “one business day,” obtain the schedule's daily working hours. On a nine-hour working day, one business day is a nine-hour SLA duration. Do not enter `1 Day`: ServiceNow duration days are 24-hour blocks.

### 3.2 Conditions as a state machine

ServiceNow supports Start, Cancel, Pause, Resume, Stop, and Reset conditions.

**Start**

- Defines eligibility and attachment.
- Prefer stable fields on the task itself: service, priority, category, contract/customer, active, or an explicit milestone field.
- Decide `When to cancel` deliberately:
  - **Start conditions are not met:** later loss of any start criterion cancels the timer. This is commonly the UI default and can unexpectedly cancel after priority/service changes.
  - **Cancel conditions are met:** start is only the initial gate; an explicit Cancel condition controls cancellation afterward.
  - **Never:** the definition never cancels through start/cancel logic; Stop or Reset must terminate it.

**Pause and Resume**

- Pause suspends elapsed SLA-running time; it does not complete the promise.
- Use only states whose ownership and contractual meaning are approved, such as waiting for the requester when the agreement truly excludes that time.
- Decide whether the SLA resumes when Pause no longer matches or only when an explicit Resume condition matches.
- Do not use Pause with a relative duration; the platform documents them as incompatible.

**Stop**

- Defines success/completion, regardless of whether breach already occurred.
- For response, use a durable audited response milestone. “Assigned to is not empty” is not the same as a human response unless the contract says so.
- For resolution, use the product's real resolved/closed state model and decide how reopen/reset behavior works.
- Since Stop overrides Start during attachment, overly broad stop criteria produce “SLA never attached.”

**Reset**

- Finishes the running Task SLA and attaches a new one when Start still matches.
- Choose whether the previous Task SLA is cancelled or completed.
- Use for a genuine new measurement period, not as a workaround for incorrect start/cancel design.

**Dot-walk warning**

Timeline, Repair, and asynchronous replay use audit history on the task. They do not replay historical values of referenced/dot-walked records; they see the referenced record's final value. Frequently changing dot-walks can therefore produce different live and repaired results. If historical correctness matters, materialize the governed value on the task in an audited field using a supported, tested mechanism, then condition the SLA on that local field.

### 3.3 Preventing overlap

Before adding a definition:

1. List active definitions for the target table and relevant ancestor task tables.
2. Compare Start, Cancel, Stop, duration, target, domain, service commitment, and override behavior.
3. Test representative tasks through each Start filter.
4. Decide whether simultaneous attachment is intentional.
5. If a service-specific definition replaces a generic one, add a durable exclusion to the generic definition or use the platform's supported override/domain model. Do not depend on definition order.

Example: a generic active HR case resolution SLA and a General Inquiry resolution SLA both attach unless their conditions/override configuration are mutually exclusive. Reporting target labels do not prevent overlap.

## 4. Duration, schedule, time zone, and planned end

### 4.1 User-specified duration

Use a fixed duration for most response/resolution promises. The duration is the amount of time accumulated while the SLA is running and in schedule.

- `1 Day` equals 24 duration hours.
- With an 8-hour weekday schedule, 24 hours consumes three working days.
- With a 9-hour weekday schedule, a one-business-day promise is 9 hours and a five-business-day promise is 45 hours.
- With no schedule, the SLA runs 24x7.
- Holidays and excluded spans extend the calendar planned end without changing the promised running duration.

### 4.2 Relative duration

Use only when the promised deadline is a calculated future date/cutoff, such as Due Date, end of next business day, or next business day at 16:00.

- The relative duration is script-defined in `cmn_relative_duration` and can run against the task or SLA record.
- Pause conditions are not compatible.
- For the OOTB Breach on Due Date behavior, an empty or past due date yields a breach one second after start.
- If the target date is outside the SLA schedule, the breach moves to the next scheduled time.
- Treat custom relative-duration scripts as code: scope, review, test time zones/DST, and package them with the definition.

### 4.3 Schedule source

Choose explicitly:

- **No schedule:** 24x7.
- **SLA definition:** fixed `cmn_schedule` selected on the definition.
- **Task field:** schedule resolved from a field on the tracked task, such as a CI schedule.

Inspect the selected schedule's spans, holidays/exclusions, child schedules if present, owner, and intended time zone. Reusing a familiar schedule name without checking its actual spans is not validation.

### 4.4 Time-zone source

The supported sources include the caller, the caller's location, CI location, task location, or the SLA definition. If a derived source is empty, the platform falls back to the system time zone. Choose the contractual time zone, not the administrator's current preference, and test:

- start before, inside, and after the schedule;
- weekend and holiday boundaries;
- daylight-saving transitions in relevant regions;
- tasks with the selected source populated and empty.

### 4.5 Runtime timing fields

The Task SLA timing record distinguishes:

- Start and Stop time.
- Planned end time/Breach time.
- Original breach time at attachment.
- Actual elapsed/time left: wall-clock time minus pause.
- Business elapsed/time left: in-schedule time minus pause.
- Elapsed percentages.

Scheduled jobs refresh active Task SLA timing fields more often as breach approaches—from multi-day intervals far from breach down to every minute within ten minutes. A displayed percentage can therefore be last-calculated data. SLA Timeline computes a diagnostic view and may appear current even before a repair; verify stored `task_sla` fields and the relevant job/property before calling the engine wrong.

## 5. Flow, notifications, escalation, and timer display

### 5.1 Use flows for new SLA automation

Starting with Yokohama, ServiceNow's new base-system flows replace the legacy SLM workflows for new work. Existing workflows remain supported, but use Workflow Studio flows for new requirements.

- Select either Flow or Workflow; the definition form makes them mutually exclusive.
- The base Default SLA flow creates events at percentage milestones. The SLA Notification and Escalation flow demonstrates 50%, 75%, and 100% notification behavior.
- Copy/extend only through the supported application pattern; do not edit ServiceNow-owned base flows casually.
- Keep recipients and messages aligned to the task persona and contract. Verify notification conditions, event queue, mail records, flow context, retries, and duplicates.
- Retroactive attachment can create an already-breached Task SLA. By default, the platform does not run the workflow for an SLA attached after its planned end (`com.snc.sla.workflow.run_for_breached=false`). Review this intentionally; do not change the global property for one definition without broad regression testing.

### 5.2 SLA timer is presentation, not calculation

The timer component chooses which Task SLA to display. The optional Timer Configuration API can show the first to breach or a mapped hierarchy. It does not determine which SLAs attach or how they calculate. Create a governed configuration rather than relying on demo data, and test paused, out-of-schedule, completed, and cancelled states.

### 5.3 SLA breakdowns are optional accountability data

With `com.snc.sla.breakdowns`, breakdown definitions record assignment-group/user periods and their contribution to elapsed duration. Use them for important commitments where ownership handoffs matter, such as P1/P2 resolution. They create additional runtime data and retention considerations; they are not required to make an SLA work.

## 6. Creation and delivery runbook

### Step 0: Inspect and baseline

- Run PDI health/context checks and verify instance/release/user/scope/update set.
- Confirm `com.snc.sla`, 2011-engine mode, `contract_sla`, `task_sla`, Timeline, flow support, repair status, and required roles (`sla_admin`/`sla_manager` as applicable).
- Inspect dictionary/choices for the target release.
- Inventory definitions on the exact table and ancestors, including inactive near matches.
- Inspect the task's real state/response fields, audit history, domain, and existing sample Task SLAs.
- Inspect schedule spans/holidays and the selected flow.

### Step 1: Approve the specification

Complete the worksheet in section 3.1. Resolve ambiguous “days,” “response,” “waiting,” “closed,” and “business hours” language before configuration. Define whether historical tasks need repair or only new/future Task SLAs are in scope.

### Step 2: Select delivery context

- For established Global/plugin-owned configuration, use the approved application scope and one story/change update set.
- For an SDK-managed scoped app, use the official Fluent `Sla` metadata API and keep the source project authoritative.
- Do not mix UI/update-set and SDK ownership for the same definition.
- Capture related schedule, flow, condition support, and timer/breakdown metadata in the appropriate application/delivery vehicle.
- Never move `task_sla`, repair logs, flow contexts, events, or test tasks as configuration.

### Step 3: Create inactive-first

In **Service Level Management > SLA > SLA Definitions**, create the record and set:

1. Name using business service + target + tier/priority + duration where useful.
2. Type and Target for reporting.
3. Table at the narrowest correct task class.
4. Fixed duration or approved relative duration.
5. Schedule source/schedule and time-zone source/time zone.
6. Start and `When to cancel`; optional explicit Cancel.
7. Pause and resume method; omit for relative duration.
8. Stop; optional Reset and reset action.
9. Retroactive start field/pause only when required.
10. One flow for new milestone/escalation requirements, or the governed existing workflow.
11. Domain/service commitment/vendor fields only when the model requires them.
12. Enable logging temporarily only for a bounded diagnosis; revert afterward.

Save inactive where supported, re-read the stored record, and inspect its update capture before activation.

### Step 4: Validate without changing history

Use **Validate SLA Definition** from the definition to open SLA Timeline against representative existing tasks. Check:

- why Start did or did not match at each audited update;
- Stop precedence;
- pause/resume periods;
- cancel/reset transitions;
- retroactive and out-of-schedule intervals;
- expected planned end and breach;
- dot-walk limitations.

Timeline is diagnostic. It uses task audit history and the current definition and shows the result as if repair had run; it does not prove stored Task SLAs were changed.

### Step 5: Execute a real PDI/DEV test matrix

Create one disposable task that satisfies the final definition and capture its `sys_id`.

| Test | Expected proof |
| --- | --- |
| Negative/no attach | No Task SLA for this definition |
| Start | Exactly one Task SLA, correct definition/task, In progress, start time |
| Duration/schedule | Planned end matches manual schedule calculation including holiday/weekend/time zone |
| Pause | Stage Paused and elapsed running time stops |
| Resume | In progress and planned end/pause duration adjusted correctly |
| Stop before breach | Completed, inactive, not breached |
| Stop after breach where safely testable | Completed with breach evidence retained |
| Cancel | Cancelled under the configured method; no replacement unless designed |
| Reset | Old Task SLA finished as configured and exactly one new Task SLA attached |
| Overlap | Only intended concurrent definitions attached |
| Flow | Correct context/events/notifications, recipients, timing, and no duplicate fan-out |
| Security/channel | Intended fulfiller can view relevant timer/details; unauthorized user cannot access protected SLA data |

Re-test one boundary case around schedule start/end and one missing time-zone-source fallback. If async engine mode is active, poll for a bounded interval before diagnosing a missing attachment.

### Step 6: Activate and package

- Activate only after configuration and behavior checks pass.
- Re-read the exact definition without cache.
- Confirm the correct application/scope/package and all expected customer updates or SDK metadata.
- Confirm no unrelated schedule, form, flow, property, or generic definition changes were captured.
- On the target instance, resolve references by stable name, preview collisions, test one target task, and verify roles/domain behavior.

### Step 7: Cleanup and handoff

- Remove only task-created test tasks and their side effects using approved PDI/DEV cleanup; account for Task SLAs, flow contexts, events, emails, and repair logs.
- Restore update-set/scope preferences.
- Report the definition specification, overlap decision, test tasks/results, update set/application, cleanup, rollback/deactivation, historical repair scope (if any), and remaining channel/production validation.

## 7. Repair and historical recalculation

Changing an SLA definition or schedule does not prove existing Task SLA records are correct. Supported SLA Repair deletes and recreates Task SLAs from task audit history and recreates the associated flow. It may remove a Task SLA that no longer qualifies or create one that was previously missing.

Use repair only when historical/runtime correction is explicitly required:

1. Confirm `com.snc.sla.repair.enabled` and 2011-engine mode.
2. Define the exact source table and encoded filter; count and sample affected tasks/Task SLAs.
3. Snapshot identifiers, stages, planned ends, breach flags, flow/event/email implications, and reporting dependencies.
4. Validate the current definition in Timeline against samples.
5. Repair one non-production task through the supported UI; inspect Repair Log before/after entries.
6. Verify Task SLAs, flows, notifications, reports, and negative cases.
7. Expand only in bounded batches with approval and monitoring.

Do not directly update/delete `task_sla` to imitate repair. Do not run the documented `SLARepair` API broadly without the same preview/approval/validation controls. Repair cannot reconstruct historical dot-walk values, so it can legitimately differ from original live processing.

## 8. Diagnostic decision tree

### SLA did not attach

```text
Correct instance/table/domain and active definition?
  no -> correct context/configuration
  yes -> task insert/update audited? -> Start true? -> Stop/Cancel false? -> ancestor/override rules? -> async delay? -> engine/log evidence
```

Use Timeline with **Show all task updates**. Inspect updates that did not cause a transition and compare the displayed condition inputs. Do not create a Task SLA manually.

### SLA attached twice or wrong definitions attached

```text
Same definition twice?
  yes -> reset/repair/concurrency/history investigation
  no  -> overlapping exact/ancestor/service-specific definitions -> decide intended concurrent promises -> add exclusions/override -> retest
```

### Planned end is wrong

```text
Duration entered as days?
  yes -> convert promise to running hours
  no  -> schedule source/actual spans/holidays -> time-zone source/fallback/DST -> retroactive start -> pause duration -> relative due-date behavior
```

### SLA cancelled unexpectedly

Inspect `When to cancel`. If it is Start conditions are not met, any later loss of a Start criterion can cancel. If explicit Cancel is used, inspect the audited task update and condition. Do not remove cancellation globally without deciding how the timer will terminate after eligibility changes.

### SLA will not pause/resume

- Relative duration cannot pause.
- Confirm the task was updated when the relevant state changed.
- Inspect Pause/Resume mode and values at that audited update.
- Check that Stop/Cancel/Reset did not take precedence.

### Elapsed percentage looks stale

Inspect the stored calculation timestamp, scheduled jobs, `glide.sla.calculate_on_display`, and the relevant calculation properties. Jobs run more frequently near breach. Avoid enabling calculate-on-display globally without measuring form-load impact.

### Timeline/repair differs from the original Task SLA

Look for changed definitions/schedules, missing audit history, frequently changing dot-walks, relative-duration changes, domain/source-field changes, or unsupported custom condition logic. Timeline uses the current definition and represents the post-repair result; it is not a snapshot of the original definition.

### Notification/escalation did not fire

Inspect selected Flow versus Workflow, flow context, milestone wait/trigger, event queue, notification conditions, recipient data, email record, and the already-breached attachment property. A correct Task SLA does not prove its automation completed.

## 9. Engine properties and change discipline

Important properties include:

| Property | Meaning / caution |
| --- | --- |
| `com.snc.sla.engine.version` | Use 2011; legacy migration is a separate project |
| `com.snc.sla.engine.async` | Default false; enable only for measured performance need |
| `com.snc.sla.compatibility.breach` | Legacy breached stage; breach flag is preferred |
| `com.snc.sla.calculation.percentage` | Stops periodic recalculation far beyond breach; default documented as 1000% |
| `com.snc.sla.maximum_duration` | Definition duration ceiling; default documented as 1095 days |
| `com.snc.sla.workflow.run_for_breached` | Whether automation runs when attached already breached; default false |
| `com.snc.sla.calculate_planned_end_time_after_breach` | Whether planned end continues recalculating after breach |
| `com.snc.sla.calculation.use_time_left` | More precise breach calculation using time-left rather than rounded percentage |
| `glide.sla.calculate_on_display` | Refresh on task form display; disabled by default due performance risk |
| `com.snc.sla.always_populate_business_fields` | Copies actual values to business fields when there is no schedule, depending on instance lineage |
| `com.snc.sla.repair.enabled` | Enables supported repair modules/actions |

Properties are release- and lineage-sensitive. Read them live and change them only for an instance-wide requirement with performance, regression, and rollback evidence. Definition-level logging is safer for a bounded diagnosis than increasing global log levels.

## 10. Reporting and governance

Report explicit populations and definitions. Useful measures include:

- achievement rate = completed Task SLAs not breached / completed Task SLAs;
- breach count and rate by definition, priority, service, customer, group, and month;
- median/percentile response and resolution running time;
- active Task SLAs due within defined windows;
- paused age and pause reason;
- cancellation/reset rate;
- reassignment contribution using SLA breakdowns where enabled;
- overlap anomalies: tasks with mutually exclusive definitions;
- definition quality: owner, schedule, flow, active use, last review, and tested release.

Do not treat cancelled Task SLAs as achieved. Do not mix actual and business elapsed metrics without labeling them. Do not aggregate SLA, OLA, and underpinning-contract results into one unexplained percentage.

## 11. Definition specification template

```text
Name:
Table:
Type / Target:
Active at transport: false
Domain / application scope:

Duration
- Type: user specified | relative
- Running duration:
- Schedule source / schedule:
- Time-zone source / time zone:
- Retroactive start field / retroactive pause:

Conditions
- Start:
- When to cancel:
- Cancel:
- Pause:
- When to resume:
- Resume:
- Stop:
- Reset / old-record action:

Automation
- Flow (stable name):
- Milestones, recipients, events, external side effects:

Overlap
- Intended concurrent definitions:
- Definitions explicitly excluded or overridden:

Evidence
- Timeline tasks:
- Runtime test task:
- Expected start/planned end:
- Actual Task SLA result:
- Negative and boundary cases:
- Update set/application and capture:
- Cleanup and rollback:
```

## 12. PDI verification note

On 2026-08-16, the configured PDI URL resolved but the saved credentials returned HTTP 401 for both Xplore and Table API, so no current live schema or behavior claim was added from that instance and no writes were attempted. Previous Vår Energi DEV work recorded successful `contract_sla`/`task_sla` behavior for HR cases in `vaar-energi-lessons.md`; treat those customer-specific observations as dated evidence, not portable defaults. Re-run `sla-query-library.md` probes when PDI access is restored.
