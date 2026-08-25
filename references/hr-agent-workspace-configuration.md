# HR Agent Workspace Configuration Without UI Builder

Use this reference for configuration of **Agent Workspace for HR Case Management** through supported properties, records, form metadata, and administration pages. It deliberately excludes UI Builder page composition, variants, component placement, and client-state wiring.

## Product Boundary First

Do not treat the two HR workspaces as interchangeable:

| Product | Application | Typical OOTB route | Status and decision |
| --- | --- | --- | --- |
| Agent Workspace for HR Case Management (configurable) | `com.sn_hr_agent_ws`, scope `sn_hr_agent_ws` | `/now/hr/agent/home` | Current target for new work. Use this runbook. |
| HR Service Delivery Agent Workspace (Classic) | `com.sn_hr_agent_workspace`, commonly associated with `sn_hr_ws` metadata | `/now/hr/workspace/home` | Deprecated. Inspect only for migration or an explicitly supported existing deployment. |

Confirm the installed Store application name, scope, version, instance family/patch, page registry path, and actual route before planning a change. On an Australia Patch 2 PDI with Agent Workspace for HR Case Management 4.5.1, the active `sys_ux_page_registry` path was `hr/agent`; treat that as an instance observation, not a portable constant.

Never apply a classic-only property such as `sn_hr_ws.case_creation_tabs` to the configurable workspace merely because both UIs are called “HR Agent Workspace.” ServiceNow's current setup documentation identifies `com.sn_hr_agent_ws` as the configurable application, while the classic setup documentation identifies `com.sn_hr_agent_workspace` and states that Classic is deprecated.

### Roles and configuration authority

Use the least role that owns the requested surface and test with the actual agent role afterward:

| Role | Current documented use |
| --- | --- |
| `sn_hr_agent_ws.admin` | Configures Agent Workspace for HR Case Management. It contains several broad workspace administration roles, so grant it only to actual workspace administrators. |
| `sn_hr_core.manager` | Manages HR cases and workspace lists/categories within the HR manager's authorized data scope. |
| `sn_hr_core.case_writer` | Uses the workspace to view, create, and work HR cases; suitable for behavioral testing, not broad configuration. |
| `sn_hr_core.basic` | Base HR agent access and AWA-agent capability where installed; use for least-privilege persona tests. |
| `sn_cd.workspace_content_manager` | Manages and schedules workspace Content Publishing content. |

Some HR Playbook documentation still requires `sn_hr_ws.admin`, which is separate from the current workspace admin role. Verify the exact configuration table and installed role containment before assigning either role. Never grant `admin`, HR manager, or a workspace admin role merely to make a hidden list, field, or record appear; diagnose ACLs, audience mappings, scope, and route first.

## Configuration-First Decision Order

Use the first surface that cleanly owns the requested behavior:

1. **Workspace Page Configurations:** open Agent Workspace for HR Case Management and use its settings icon. This is the primary supported surface for the app/page properties listed below.
2. **Purpose-built configuration records:** lists, audiences, highlighted values, card filters, fulfillment instructions, response-template/Agent Assist mappings, email client templates, and scheduled content.
3. **Workspace form metadata:** the `Workspace UIB` form view, related lists, Activity Stream selection/order, UI policies, client scripts, workspace view rules, and ACLs.
4. **HR behavior properties:** use HR Administration > Properties or exact `sys_properties` records when the behavior is HR-case logic rather than page layout.
5. **Platform-wide workspace properties:** use only when the requirement intentionally affects every applicable workspace or the full instance.
6. Escalate to UI Builder only when none of these supported surfaces can express the requirement. That escalation is outside this runbook and must include upgrade-cost and regression analysis.

Do not edit `propertySettings`, `chrome_*`, `featureRoutes`, macroponents, screens, or ServiceNow-owned page composition merely to reach a setting already exposed by Page Configurations. Those are app-shell implementation metadata, not ordinary configuration contracts.

## Page Configurations and Scoped UX Page Properties

ServiceNow documents the settings-icon flow as **Page configurations**. In Australia, the configuration schema is stored in the HR workspace's `propertySettings` UX page property and the editable values are separate `sys_ux_page_property` records in scope `sn_hr_agent_ws`.

Prefer the settings dialog over direct record edits. When automation is justified, resolve the page by current scope/title/path and the property by exact `name`; update only its `value`. Do not create a missing HR page property: absence usually means a Store-app version mismatch or unavailable feature.

### Supported settings matrix

| Page Configurations label | Stable property or destination | Data shape | Use and constraints |
| --- | --- | --- | --- |
| Minimum input for adhoc approval user search | `minimumInputForAdhocApprovalUserSearch` | Integer in the settings schema; stored value may be a string | Minimum characters before approver user search starts. Use a positive bounded value and test both below and at the threshold. |
| Timeline for ER cases | `showTimelineforERCases` | Boolean | Show or hide the Employee Relations case timeline. Test an ER case and a non-ER case. |
| Case tab title field | `caseTabTitleField` | JSON object | Map a case table to one field name or an array of field names. A base `sn_hr_core_case` mapping applies to extensions when no child mapping exists. Validate table/field names and JSON before saving. |
| Playbook card configuration | `sn_hr_agent_ws.use_uib_playbook_card_config` | Boolean system property | `true` selects configurable-workspace playbook card configuration when both classic and configurable HR workspaces are installed; `false` selects classic. Verify the installed versions and corresponding card/override records before changing it. |
| Manager email template ID | `managerEmailTemplateId` | Target-local reference stored as a string | Email client template used from the manager popover. Resolve the intended active `sys_email_client_template` by stable name on every target; never transport a remembered `sys_id`. |
| Copy case attributes | `copyCaseAttributes` | Comma-separated field names | Fields copied by Copy case. Confirm every field exists on the relevant case tables, is appropriate to copy, and remains writable/authorized. |
| Sidebar tabs visibility | `contextualSidebarVisibility` | JSON object of tab IDs to table arrays | Remove a table from a tab's array, or clear the array, to hide that tab for the table. Adding a table does not make every feature functional; verify the feature supports that table and configure companion mappings. |
| Cases limit | `atAGlanceCasesLimit` | Integer | Maximum recent cases shown in At a Glance. Keep the value bounded and test load time plus empty/overflow states. |
| Manager fields for popover | `atAGlanceManagerFields` | Comma-separated field/dot-walk names | Fields shown in the manager popover. Verify each path and the viewer's field ACLs; avoid exposing unnecessary HR data. |
| User field | `atAGlanceUserField` | JSON table-to-user-field map | Identifies the person displayed by At a Glance for each table. Update this whenever a new supported table is added to the At a Glance visibility array. |
| Update employee info | `At a Glance` form view for `sn_hr_core_profile` | Form layout metadata | Configure Employee Details and Contacts sections through Form Layout. Test with populated and empty values; empty fields may not render. |
| Agent assist configuration | `agentAssistConfig` | JSON table-to-`cxs_table_config` reference map | Map each supported table to a target-local Agent Assist configuration. Resolve each record on the target; also configure the linked CXS table configuration. |
| Response templates configuration | `responseTemplatesConfig` | JSON table-to-`cxs_table_config` reference map | Map each case/task table to a target-local response-template configuration. Resolve locally and test actual template visibility/content. |
| Fulfillment instructions configuration | `sn_hr_core_fulfillment_instructions` records | Configuration records | Define active, targeted instructions for supported HR cases. Test conditions and persona access. |
| Email client templates configuration | `sys_email_client_template` records | Configuration records | Configure reusable email content. Validate applicable tables, recipients, security, and rendered email behavior. |
| List configuration ID | `listConfigId` -> `sys_ux_list_menu_config` | Target-local reference stored as a string | Points the workspace to its list menu configuration. Normally retain the OOTB configuration and edit its child categories/lists. Resolve the intended record locally. |
| Highlighted value configuration ID | `highlightedValueConfigId` -> `sys_ux_highlighted_value_config` | Target-local reference stored as a string | Selects the highlighted-value configuration used by lists/forms. Resolve locally; manage highlighted values and ordered conditions through their records. |
| Applicability | `sys_ux_applicability` | Audience/configuration records | Define role-based criteria for list visibility. This controls presentation, not record security. |
| M2M applicability | `sys_ux_applicability_m2m_list` | List-to-audience mappings | Associate each list with the audience that may see it. A missing mapping commonly explains admin-only list visibility. |
| Case creation employee fields | `employeeFields` | Comma-separated field/dot-walk names | Employee information shown during case creation. Confirm paths, HR data minimization, field ACLs, and responsive rendering. |
| Skip first step of case creation for child cases | `skipFirstStepOfCaseCreationForChildCases` | Boolean | Skip employee/case verification when creating a child case from the related list. Test parent context, copied user values, cancel, and direct creation. |
| High priority / recently updated / SLA-at-risk cards | `sn_hr_agent_card_config` records | Filter, text, and empty-state configuration | Configure the three OOTB landing cards without changing their page composition. Prove filters with positive, negative, and empty data. |
| Announcements / Quick Links / frequently used apps | Content Publishing visibility/schedule records | Active, audience, location, group, and date-bound records | Configure content targeted to `UIB Workspace` and the correct content group. Do not assume content visibility bypasses source or role security. |

The installed app may contain additional page properties such as `atAGlanceRecentCasesDays`, `hasFormPrefetchEnabled`, or `playbookActivityView`. Do not treat a discovered property as a supported customer knob unless it appears in the installed Page Configurations schema or current ServiceNow documentation. Inspect it for diagnosis, but avoid direct changes to undocumented implementation properties.

### JSON examples

Tab title with two fields:

```json
{
  "sn_hr_core_case": ["subject_person", "number"]
}
```

At a Glance user mapping:

```json
{
  "sn_hr_core_case": "subject_person",
  "sn_hr_er_case": "opened_for",
  "interaction": "opened_for",
  "sn_hr_core_profile": "user",
  "sn_hr_core_task": "assigned_to"
}
```

For `contextualSidebarVisibility`, keep the existing JSON as the baseline and make the smallest table-array change. Some tabs only support their OOTB table; adding another table can reveal a nonfunctional tab. Agent Assist and Response Templates require matching CXS configuration mappings, and At a Glance requires a matching `atAGlanceUserField` entry.

## Lists, Categories, and Audience

The configurable workspace list hierarchy is record-driven and does not require UI Builder:

- `sys_ux_list_menu_config`: the container referenced by `listConfigId`.
- `sys_ux_list_category`: categories; use `active` and `order` to control visibility and position.
- `sys_ux_list`: filtered lists; configure title, table, columns, encoded condition, order, active state, and supported feature flags.
- `sys_ux_applicability`: reusable audience criteria.
- `sys_ux_applicability_m2m_list`: list-to-audience association.

Do not paste an OOTB list-menu `sys_id` from another instance. Resolve the list menu from the current HR workspace property, then traverse its categories and lists. To remove an unwanted OOTB list, prefer a reversible `active=false` only after confirming scope, ownership, audience, dependencies, and upgrade implications. For a new list, create the category/list in the appropriate application scope and add the audience M2M; an admin-only test is insufficient.

`glide.lists.live_list_enabled=true` is a platform-wide prerequisite for list live-update controls. When enabled intentionally, each `sys_ux_list` can select off, manual refresh, or automatic refresh. Test query cost and concurrent changes before selecting automatic refresh.

Personal **My Lists** are user-owned workspace records and are not a substitute for centrally governed navigation. Use them for an individual agent's workflow, not for organization-wide list delivery.

## Forms, Related Lists, Activity Stream, and Highlighted Values

These surfaces are configured outside UI Builder even though the current form view is named `Workspace UIB`:

- **Fields and sections:** use Form Builder/Form Layout on the `Workspace UIB` view. Configure the base case table and relevant COE extensions deliberately; inheritance does not remove the need to test child tables.
- **Related lists:** from an HR case, use Configure > Related Lists and select the `Workspace UIB` view. Verify presence, order, reference relationship, ACLs, and create/edit actions.
- **Activity Stream:** select the activity filter on a case, choose journal/activity types, order them, and save. Test internal versus employee-visible communication as the intended persona.
- **At a Glance employee data:** configure the `At a Glance` view on `sn_hr_core_profile`, specifically its Employee Details and Contacts sections.
- **Highlighted values:** use Workspace Experience > Administration > Highlighted Values. Configure table, field, application/workspace, then ordered conditions, color, optional hidden label/icon, and optional value override.
- **Workspace view rules:** use `sysrule_view_workspace` and the applicable UX view-rules configuration to select views, roles, conditions, tab order, section navigation, and collapsing behavior.
- **UI policies and client scripts:** use view-aware policies/scripts for client presentation; prefer UI policies for declarative visibility, mandatory, and read-only behavior. Test Workspace separately from Core UI.
- **ACLs, data policies, and Business Rules:** enforce security and data integrity server-side. A hidden list, field, button, or sidebar tab is never an authorization control.
- **Actions:** use existing UI Action workspace flags or supported Declarative Action/action-assignment metadata. Avoid direct changes to ServiceNow-owned actions; add a scoped action or visibility rule when the requirement is additive.

## HR Behavior Properties That Change the Workspace Experience

These are HRSD behaviors observed in the workspace, not page-layout controls. Inspect current documentation and the live property record before changing:

| Property | Shape | Workspace effect |
| --- | --- | --- |
| `sn_hr_core.duplicate_hr_case_time_out` | Number of days | Duplicate warning window for the same HR service and subject person during HR case creation. Test inside and outside the window. |
| `sn_hr_core.hr_vip_default_priority` | Priority value | Default priority for cases whose Opened for and/or Subject person is VIP. Verify template and transfer interactions. |
| `sn_hr_core.rollup_work_notes` | Boolean | Rolls task work notes up to the HR case. Validate confidentiality and notification side effects before enabling. |
| `sn_hr_core.reclassify_default_transfer` | Boolean | Selects transfer behavior: `true` uses the standard new-case-number transfer; `false` uses reclassification and retains the case number. Test links, work notes, child tasks, notifications, and history. |
| `sn_hr_core.restrict_guest_email` | Boolean | Controls how replies from personal/guest email are handled; when false, content can appear in Work notes. Validate inbound-email security and privacy. |
| `sn_hr_core.case_auto_categorization` | Boolean | Enables or disables Predictive Intelligence HR-service suggestions/banners for eligible new cases. Requires the licensed apps/model configuration. |
| `glide.platform_ml.auto_training.enabled` | Boolean, platform-wide | Allows qualifying predictive models to auto-train. Do not change solely for HR workspace without platform ML ownership and capacity review. |
| `sn_hr_core.impersonateCheck` | Boolean | When true, prevents impersonated sessions from viewing HR information. Treat as a security control, not a test inconvenience. |
| `sn_hr_core.include_elevated_roles` | Boolean | Includes elevated-role state in HR access evaluation. Review security impact and test elevated/unelevated sessions. |
| `glide.enforce_security_scope.sn_hr_agent_ws` | Boolean; recommended/default `true` | Enforces the HR workspace plugin's security scope. Keep `true`; setting false can expose scope-master data through ACLs from other scopes. |

The minimum-active-admin control is version/product-sensitive. A current configurable-workspace installation can contain `sn_hr_agent_ws.min_admin_count`, while older or Classic HR documentation can refer to `sn_hr_ws.min_admin_count`. Resolve the existing property and role live for the installed app; never create or rename one from memory. Changing the minimum is a scoped-administration governance decision, not a workspace presentation fix.

## Platform-Wide Boolean and Form Properties

These affect the HR workspace because it is a Configurable Workspace, but their blast radius is wider. Do not use them for a one-page preference:

| Property or field | Effect | Guardrail |
| --- | --- | --- |
| `glide.ui.activity.journal.stacked=true` | Offers separate/stacked internal and external journal composers. | Mandatory Activity Stream fields can prevent the option from appearing. Test other workspaces. |
| `glide.ui.journal.use_html=true` | Enables rich text for journal input. | Instance-wide behavior and potential performance/security implications; test rendering, sanitization, email, mobile, and other workspaces. |
| `glide.ux.autoreflow.disable=true` | Disables reflow across the instance. | Reflow supports accessibility up to high zoom; leave enabled unless there is an approved accessibility-tested exception. |
| `sys_ux_app_config.disable_auto_reflow=true` | Disables reflow only for the selected experience. | Prefer this narrower exception over the instance property, but still test 400% zoom. |
| `sys_ux_screen.disable_auto_reflow=true` | Disables reflow for one page. | Narrowest reflow exception; only applicable to pages using the supported layout system. |
| `glide.ui.personalize_form` | Enables/disables Personalize Form. | Platform-wide; prefer role restriction when only access needs narrowing. |
| `glide.ui.personalize_form_role` | Roles allowed to personalize forms. | UI capability only; it does not grant field or record access. |
| `glide.ui.workspace.script.code_editor.enable=true` | Shows script fields with a workspace code editor. | Enable only for personas/tables that genuinely expose script fields; pair with ACL review. |

Automatic-resize properties for text area, journal HTML, and Activity Stream composers are also supported platform configuration. Use the current Configurable Workspace forms documentation to select the exact property for the field subtype; validate line limits and accessibility rather than copying a generic value.

## Safe Inspection and Change Pattern

### Read-only inventory

1. Confirm the instance and user, then inspect `sys_store_app` for scope `sn_hr_agent_ws` and record the version.
2. Resolve the current registry record from `sys_ux_page_registry` by scope/title/path; verify the active route rather than assuming `/now/hr/agent`.
3. Query `sys_ux_page_property` for that page and scope. Return only `name`, `type`, `suffix`, `value`, description, package, and update metadata. Redact or omit target-local reference values from reusable notes.
4. Read `propertySettings` only to identify the settings that the installed app exposes. Do not edit it.
5. Query exact `sys_properties.name` records for requested system behavior. Record type, current value, description, scope, and whether the docs say to add the property when absent.
6. For a reference-valued property, resolve and validate the referenced record on the same target. Never infer validity from a 32-character string.
7. Inspect the intended update set/scope and the existing customer-update history before any write.

### Controlled change

1. Capture the exact before-value and a JSON-formatted snapshot where relevant.
2. Validate JSON syntax, tables, fields, encoded queries, reference targets, roles, audiences, and plugin/licensing prerequisites before saving.
3. Change one coherent setting through Page Configurations or its purpose-built form. Use direct `sys_ux_page_property.value` automation only for a repeatable non-production change whose ownership and capture behavior have been proven on the installed version.
4. Re-read the exact record without cache and confirm the expected update-set/application capture. Store app files can behave differently across versions; a successful write is not transport proof.
5. Refresh or start a clean workspace session and test the intended persona plus a negative persona. Some shell/page properties are cached.
6. Test the exact surface and one adjacent regression: base case plus an extension, populated plus empty data, visible plus hidden audience, or current workspace plus another workspace for platform-wide properties.

If direct scripting is justified, update only the resolved record's `value`; never modify `unique_name`, `name`, `type`, `page`, `route`, `sys_scope`, or package fields. Do not create a missing `sys_ux_page_property` to imitate a newer Store-app version.

## Validation Matrix

| Layer | Required evidence |
| --- | --- |
| Product/version | Current app is `com.sn_hr_agent_ws`; Store version, family/patch, scope, route, and feature prerequisites recorded. |
| Configuration | Exact property/config record re-read; expected type/value/JSON/reference; correct scope/package and active state. |
| Rendered behavior | Fresh workspace session shows the requested result on the intended route, table, and record state. |
| Persona/security | Intended HR persona succeeds; unauthorized persona cannot gain data or action access; no reliance on UI hiding. |
| Cross-table | Base HR case and every materially affected COE/ER/Lifecycle/task table behave as intended. |
| Cross-workspace | Required for global properties: verify at least one other workspace or document why no other workspace is installed/applicable. |
| Performance/accessibility | Bounded list/sidebar queries, acceptable load time, keyboard/focus behavior, zoom/reflow, empty/error states, and rich-text sanitization where relevant. |
| Delivery | Expected update records/application files captured with no unrelated page, layout, or ServiceNow-owned metadata changes. Target-local reference values are re-resolved after promotion. |
| Rollback | Restore the before-value or deactivate/remove only the additive record created by the change; repeat the original test and clear cache/session as needed. |

## Classic-Only Appendix

Use only when the route/app inspection proves the deprecated Classic HR workspace is the actual supported target:

- `sn_hr_ws.case_creation_tabs` is a JSON system property used to add or remove initial tabs from the Classic Create a new case flow.
- Classic landing-page cards and tags use Classic HR landing-page configuration records, not the configurable workspace's `sn_hr_agent_card_config` and UX list stack.
- `glide.ui.journal.use_html` and `glide.ui.activity.journal.stacked` are platform properties and can affect both classic and configurable workspace experiences, so their blast-radius controls still apply.

Prefer a migration assessment to new Classic customization. Do not copy classic `sn_hr_ws` card, list, or page metadata into scope `sn_hr_agent_ws`.

## Official Sources

- [Setting up Agent Workspace for HR Case Management](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/setup-configurable-hr-agent-workspace.html)
- [Agent Workspace for HR Case Management Guided Setup](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/hr-agent-ws-guided-setup.html)
- [Page configurations](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/page-configurations.html)
- [Page Configurations reference](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/configuration-settings.html)
- [Customize tab label](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/customise-tab-lable-agent-ws.html)
- [Customize related lists](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/related-lists-aws.html)
- [Customize Activity stream](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/activity-stream-aws.html)
- [Customize fields in a form](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/form-builder-aws.html)
- [Configure the At a Glance panel](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/hr-agent-ws-config-ataglance.html)
- [Highlight fields](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/highlight-form-fields.html)
- [Lists in Agent Workspace for HR Case Management](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/hr-agent-ws-lists.html)
- [HR properties](https://www.servicenow.com/docs/r/employee-service-management/hr-service-delivery/t_HRProperties.html)
- [Auto determination of HR service](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/hr-agent-ws-auto-hrservice.html)
- [Configure HR Service Delivery playbook card](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/playbook-hr-card-configuration.html)
- [Enforce Security Scope for Agent Workspace for HR Case Management](https://www.servicenow.com/docs/r/platform-security/instance-security-hardening-settings/sc-enforce-security-scope-for-agent-workspace-hr-case.html)
- [Disable reflow for Configurable Workspace](https://www.servicenow.com/docs/r/platform-user-interface/disable-auto-reflow-for-configurable-workspace.html)
- [Configure stacked view for the Activity stream](https://www.servicenow.com/docs/r/platform-user-interface/configure-activity-stream-general.html)
- [Configure rich text editor for the Activity stream](https://www.servicenow.com/docs/r/platform-user-interface/config-activity-stream-rte.html)
- [Workspace API / UX list metadata](https://www.servicenow.com/docs/r/xanadu/application-development/servicenow-sdk/fluent-workspace-api.html)
- [Administering forms for Configurable Workspace](https://www.servicenow.com/docs/r/platform-user-interface/administer-forms-configurable-workspace.html)

Recheck these sources against the target family and installed Store-app version. HR workspace Page Configurations are Store-app metadata and can gain, rename, or remove settings independently of the family release.
