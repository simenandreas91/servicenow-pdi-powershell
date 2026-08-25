# Custom Scoped App Development

Use this guide when creating or expanding a custom scoped application. Prefer ServiceNow Studio, App Engine Studio, ServiceNow IDE/SDK, or source control for real project work; use API automation only for narrow PDI demos, probes, or repeatable metadata work.

## Decision Gate

Create a custom scoped app only when the use case is a good app candidate:

- Net-new process that does not fit an existing product area.
- Process could be forced into an OOTB app, but that would conflict with the app's intent.
- Proprietary or cross-department workflow that needs its own data, roles, navigation, automation, and lifecycle.

Do not create a custom app merely because a custom table is convenient. First check OOTB products, plugins, table extension patterns, Flow templates, catalog/HRSD/CSM models, and supported configuration.

## Tool Choice

- **ServiceNow Studio**: best default for admins/platform developers building scoped app files with UI guardrails, update sets, builders, and app details in one place.
- **App Engine Studio**: good for low-code data, experience, automation, and security, especially citizen-developer or template-led apps.
- **ServiceNow IDE/SDK + Fluent**: best for source-code-first apps, code review, reusable TypeScript metadata, JavaScript modules, third-party libraries, and real Git workflows.
- **Table API/Xplore automation**: use only when the task is narrow, repeatable, and verified record-by-record. Some builder-only steps are safer in UI.

For enterprise delivery, official guidance prefers Git/source control + Application Repository or pipelines for custom scoped apps. Update sets remain valid for demos, global work, emergency hotfixes, Store/plugin changes, and organizations still using legacy deployment.

## Golden Path

1. Run `Get-ServiceNowPdiHealth.ps1` and capture current scope/update-set context before creating anything.
2. Decide whether this is truly a custom app. State why OOTB/configuration is insufficient.
3. Name the app, scope, and package intentionally:
   - app name: business-readable, durable
   - scope: unique, short, no temporary names
   - role suffixes: `user`, `admin`, or clear personas
   - table names: `<scope>_<noun>` and labels without implementation jargon
4. Create the app in ServiceNow Studio/App Engine Studio when possible:
   - Navigate to **All > App Engine > ServiceNow Studio**.
   - Create **App > On your own** for pro-code scoped work.
   - Use **Scoped** unless the app must intentionally live in Global.
   - Define at least one role; Studio requires a role before continuing.
5. Set a dedicated scoped update set with `Set-ServiceNowUpdateSetContext.ps1`.
6. Build data first:
   - Choose whether to extend an existing table such as `task` or create a standalone table.
   - Add only required fields for the first vertical slice.
   - Enable `create_access_controls` and set `user_role` so ServiceNow generates table ACLs.
   - Keep cross-scope application access closed by default; open only read/create/update/delete/web-service access that is required.
   - After the fields exist, open the table in Table Builder/Form Builder, configure **Default view**, add an appropriate first section and fields, and save it. Treat this as part of table creation, not optional UX polish.
7. Add security before UX:
   - Create app roles before table ACLs.
   - Verify generated ACLs and `sys_security_acl_role` rows.
   - Test with a persona role when possible; admin-only success is not enough.
8. Add basic experience:
   - Application menu and list module for classic navigation.
   - Refine form/list layouts only after fields and ACLs exist; the saved Default form view itself must already exist for every table intended for form or Workspace use.
   - Portal, Workspace, UI Builder, or mobile only when that is the real target channel.
9. Add logic last:
   - Prefer Flow for business-owned process and approvals.
   - Use a small guarded Business Rule for table defaults/validation.
   - Use Script Includes when logic is reusable or test-worthy.
10. Insert one safe sample record and prove runtime behavior.
11. Confirm update-set capture:
    - one application in `sys_update_xml.application`
    - expected app file types
    - generated ACLs and role links present
    - no stale/default/mixed-scope updates
12. Clean throwaway data unless the sample record is intentionally part of the demo.
13. Restore preferences and report app, scope, update set, artifacts, tests, cleanup, and caveats.

## API Automation Pattern

When UI creation is unavailable and the task is a PDI/demo, this worked reliably:

1. Create the app as `sys_app` with matching `name`, `scope`, and `source`.
2. Set scoped update-set context after the app exists.
3. Use Table API, not scoped Xplore inserts, for metadata records that may silently fail in scoped script:
   - `sys_user_role`
   - `sys_db_object`
   - `sys_dictionary`
   - `sys_choice`
   - `sys_script`
   - Global catalog metadata such as `sc_cat_item_producer`, `item_option_new`, `user_criteria`, and `catalog_script_client`
4. Pass `sys_scope` and `sys_package` explicitly on metadata creates.
5. After creating a table and dictionary fields, create and save its **Default view** through Table Builder/Form Builder. API-created table metadata does not guarantee that ServiceNow creates the form metadata needed by downstream builders. Avoid hand-building `sys_ui_section` and form-element records unless the UI path is unavailable and the exact metadata contract has been established.
6. Verify table availability and the Default-view section before inserting data or selecting the table in a Workspace:

```powershell
& "$HOME/.codex/skills/servicenow-pdi/scripts/Invoke-ServiceNowTable.ps1" `
  -Table sys_db_object `
  -Query "name=x_scope_table" `
  -Fields "sys_id,name,label,sys_scope,sys_package,user_role,create_access_controls" `
  -DisplayValue all `
  -ExcludeReferenceLink `
  -Profile pdi
```

```powershell
& "$HOME/.codex/skills/servicenow-pdi/scripts/Invoke-ServiceNowTable.ps1" `
  -Table sys_ui_section `
  -Query "name=x_scope_table^view=Default view" `
  -Fields "sys_id,name,view,caption,position,sys_scope" `
  -DisplayValue all `
  -ExcludeReferenceLink `
  -Profile pdi
```

Require at least one matching `sys_ui_section`. App Engine Studio's Workspace table picker uses an `ONLY_DEF_VIEW_TABLES` filter and excludes a table when this record is missing, regardless of cache refresh, scope, application access, or table ACLs.

7. Insert sample data in a later request/transaction after table creation has completed.

## PDI Demo Findings

Demo app built on 2026-05-24:

- App: `Codex Scoped Demo`
- Scope/package: `x_simen_codex_demo`
- Update set: `Codex scoped demo app`
- Table: `x_simen_codex_demo_request`
- Role: `x_simen_codex_demo.user`
- Fields: `u_summary`, `u_state`, `u_priority`, `u_notes`
- Choices: state `new/in_progress/done`, priority `1/2/3`
- Navigation: `Codex Demo` menu, `Requests` list module
- Logic: before-insert Business Rule `Codex Demo request defaults`
- Runtime proof: sample record inserted with blank state/priority and Business Rule defaulted `State=New`, `Priority=3 - Low`
- Update-set proof: 31 customer updates, all in the app scope, no mixed scope

What was tricky:

- Creating `sys_app` by server script worked, but role/table/dictionary inserts through scoped Xplore returned empty sys_ids for several metadata tables. Table API with explicit `sys_scope`/`sys_package` worked.
- Creating the table and immediately inserting a runtime record in the same server-side transaction failed because the physical table was not yet available. Split metadata creation and sample data insertion.
- `sys_db_object.create_access_controls=true` with `user_role` generated read/create/write/delete ACLs and matching access-role rows automatically. Verify generated ACL operations; do not assume the generated set matches the desired delete/update model.
- Application menus/modules captured in scope even before the table existed, so a failed table attempt can leave partial navigation metadata. Inspect and clean or reuse intentionally.

## Verification Commands

Update-set summary:

```powershell
& "$HOME/.codex/skills/servicenow-pdi/scripts/Get-ServiceNowUpdateSetSummary.ps1" `
  -UpdateSetSysId "<sys_update_set>" `
  -Profile pdi
```

Runtime record proof:

```powershell
& "$HOME/.codex/skills/servicenow-pdi/scripts/Invoke-ServiceNowTable.ps1" `
  -Table "<scope>_<table>" `
  -Query "u_summary=<sample summary>" `
  -Fields "sys_id,u_summary,u_state,u_priority" `
  -DisplayValue all `
  -ExcludeReferenceLink `
  -Profile pdi
```

Generated ACL proof:

```powershell
& "$HOME/.codex/skills/servicenow-pdi/scripts/Invoke-ServiceNowTable.ps1" `
  -Table sys_security_acl `
  -Query "nameSTARTSWITH<scope>_<table>" `
  -Fields "sys_id,name,operation,active,type,sys_scope,sys_package" `
  -DisplayValue all `
  -ExcludeReferenceLink `
  -Profile pdi
```

## Common Pitfalls

- Building in the wrong current app/update set, especially after prior HRSD/Journey work.
- Mixing global app files, scoped app files, generated ACLs, and portal/workspace records in one update set.
- Treating application access as user security. Application access controls cross-scope runtime/design-time access; ACLs control users and fields.
- Opening table web-service or cross-scope access broadly during early development and forgetting to tighten it.
- Creating business logic before the data model and role model are stable.
- Testing only as admin.
- Assuming that creating `sys_db_object` and dictionary rows also creates a Default form view. Without a saved Default-view `sys_ui_section`, the table can exist and accept records while remaining absent from App Engine Studio's Workspace table picker; `cache.do` does not repair missing form metadata.
- Treating a non-empty metadata row as runtime proof. Verify reference qualifiers against the live target-table dictionary, test duplicate rejection after creating a unique index, and run one valid plus one negative insert through the owning scope.
- Using scoped Xplore as a general metadata builder. Cross-scope calls made only for construction or testing can create Restricted Caller Access records and update-set noise that the application does not need at runtime; prefer Table API/owning-scope writes and inspect `Cross scope privilege` rows before handoff.
- Adding sample/reference data to update sets unintentionally. Application Repository does not move app data; manage seed data deliberately.

## Scope-Collision Creation Error

For `This scope is already taken by another application`, distinguish a real collision from a broken creation path before changing anything:

1. Determine the exact generated scope and query `sys_scope`/`sys_app` for that value. On enterprise instances, also check the company Application Repository because a scope can be reserved elsewhere in the same vendor namespace and therefore be absent locally.
2. Try one deliberately unique application name or create through ServiceNow Studio's advanced/classic application creator, where the internal scope can be controlled. App Engine Studio can derive a short internal scope from the label and collide even when the friendly name looks different. Renaming the label after successful creation does not rename the internal scope.
3. If several unrelated, deliberately unique names fail on a fresh PDI and no matching local scope exists, treat the message as a probable PDI/vendor-prefix registration failure rather than evidence that every scope is occupied. Inspect `glide.appcreator.company.code` read-only and capture the release/build and creator channel. Do not delete `sys_scope`/`sys_store_app` records, alter the company code, or create the app in Global as a routine workaround.
4. Use a template-based creation only as a disposable PDI workaround and inspect/delete unwanted generated artifacts deliberately. For persistent failure, preserve/export needed work and use the PDI support/reset path; for a customer instance, open ServiceNow Support with the failed scope, namespace/company code, build, timestamps, and transaction/application logs.

## Official Docs Shortlist

- `markdown/application-development/determining-good-candidates-for-apps.md`
- `markdown/application-development/developing-applications.md`
- `markdown/application-development/c_ApplicationScope.md`
- `markdown/application-development/c_ApplicationAccessSettings.md`
- `markdown/application-development/c_ApplicationFiles.md`
- `markdown/application-development/r_TableApplicationAccessFields.md`
- `markdown/application-development/best-practices-use-source-control.md`
- `markdown/application-development/moving-applications-between-instances.md`
- `markdown/application-development/servicenow-studio-classic/create-an-application-in-servicenow-studio.md`
- `markdown/application-development/servicenow-studio-classic/working-with-update-sets-in-servicenow-studio.md`
- `markdown/application-development/app-engine-studio/create-application.md`
- `markdown/application-development/app-engine-studio/add-data.md`
- `markdown/application-development/app-engine-studio/add-security.md`
