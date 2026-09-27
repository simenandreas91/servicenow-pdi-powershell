# Persistent Workspace task workflows

Use for identity/ownership investigations or similar durable follow-up in a Configurable Workspace. These lessons were verified on an Australia instance in September 2026; inspect the installed product, schema and persona before applying release-sensitive details. They are reusable implementation findings, not proof that another application's requirements are met.

## Choose the record model by lifecycle

Inspect existing product tables before extending `task`. A CMDB management task can be policy/execution-generated; duplicate reconciliation tasks address duplicates; an alarm remediation task can belong to automation. A familiar label is insufficient evidence that a table supports an ad hoc investigation. Check mandatory references, supported creation path and extendability. If none fits, a scoped task subclass may preserve native assignment, journal, history and form behavior without forcing the wrong lifecycle.

Extending `task` also inherits business logic, field permissions, qualifiers, notifications and potential SLA behavior. Inspect those dependencies and test the actual child class. A new subclass is not isolated merely because its own rules are small.

## Native forms, assignment and access

- Verify table-level and inherited field-level ACLs separately. A persona can have record write access while inherited fields remain read-only. Diagnose the exact blocked fields; use narrowly scoped child-table ACLs when justified, not edits to base Task ACLs or broader role grants.
- Check effective role inheritance. In the observed CMDB persona setup, a read-only persona inherited `data_manager_user`; that role was not an appropriate edit gate. Select permissions from the intended operation and test positive and negative personas rather than inferring authority from role names.
- A reference lookup may return no assignees because the inherited Task qualifier requires a role the intended data steward lacks. Inspect the dictionary/qualifier first. When appropriate, a dictionary override on the child table can use the intended eligible role without changing assignment behavior on all tasks.
- ACL permission and application-access permission are separate. A Global probe can have `canWrite()` true yet fail a cross-scope update that is prohibited by the child table's application access. Verify through the intended scoped service/native channel; do not broaden cross-scope writes merely to make a test harness succeed.
- Persist the Default form and the intended Workspace view. Follow the runtime route's selected view; successful Default-view editing does not prove the Workspace uses it.

## Journal, audit and configuration capture

For a GlideRecord journal field, assign directly before insert/update, for example `record.work_notes = note`. An observed `setValue('work_notes', note)` path updated ordinary fields without persisting the expected journal entry. Verify the resulting journal entry and visible activity, not just the record's update timestamp. A test double should not silently treat journal fields as ordinary scalar fields.

Enable and read back audit on the table's collection dictionary record (`sys_dictionary`, table name, empty element). Do not infer audit from an attempted `sys_db_object.audit` write. Confirm an actual change has an audit entry. Work notes and field audit serve different purposes; neither alone proves the other.

A native activity stream can use the installed `activity.xml` formatter (`sys_ui_element.type=formatter`). Inspect the working form metadata first. Check whether the form also has a standalone work-notes input to avoid needless duplicate entry surfaces.

Form capture can be aggregate-based: `sys_ui_form_sections_<id>` describes the form/section association while `sys_ui_section_<id>` carries section elements. Verify both payloads after fields/formatters have been added. If an early capture omitted later elements, diagnose the missed natural capture, then recapture the completed owning form/section in the correct context. Capture presence alone does not prove that the payload is complete or current.

## Repeated observations and truthful completion

- Use a stable source identity plus its namespace/zone and relevant workflow type. A changed display name should not create a new investigation; names or IP addresses alone may collide. Enforce a database unique key as well as a lookup, and handle concurrent duplicate insertion without retrying blindly.
- Preserve initial evidence and append repeated observations to the journal. Define whether recurrence updates the open task, reopens the completed task or creates a new occurrence; test that choice explicitly. If reopening clears the current decision, retain the previous decision in audit/history.
- Enforce closure conditions server-side. Distinguish pending/ambiguous/escalated decisions from completed resolution, and require the evidence appropriate to each investigation type.
- A verified-link checkbox is a human decision, not automatic identity matching. An owner field being populated does not prove authoritative source reconciliation. Keep those integration/verification gaps explicit.
- Label receipt timestamps as registered/received times unless the integration provides the actual observation timestamp. Treat provisional default deadlines separately from approved SLA policy.

## Workspace composition and work queues

Several navigation routes can share one page definition with conditionally visible sections; this is distinct from a single custom component rendering everything. Explain the route, page and component layers accurately. Shared pages suit closely related views; separate pages become useful when data resources, state and workflows diverge. A split is a design choice, not a prerequisite for every new route.

Personal work queues should query the authorized assigned records directly, with pagination. Deriving them from the currently visible or capped alarm/asset results silently hides work. A small homepage preview can be bounded, but link it to the full queue and do not present its count as a complete total. Hide irrelevant global filters on a dedicated queue or make their actual effect clear.

For explicit mutation feedback and resource-event deployment, read [UI Builder event automation](ui-builder-event-automation.md#explicit-mutating-data-resources).

## Acceptance evidence

Use a compact sequence: register, repeat with a changed name, inspect history, assign, reject incomplete closure, keep ambiguity pending, complete a verified case, and check allowed/denied personas. Read the final persisted state independently of UI feedback. Account for retained test records and inherited notifications; end test impersonation and restore the original session.

Keep customer records, sys_ids, test outcomes and delivery status in the project acceptance register. Do not turn a demonstrated workflow foundation into a claim of source integration, complete use-case coverage or production readiness.
