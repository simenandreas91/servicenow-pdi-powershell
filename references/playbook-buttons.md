# Playbook Activity Buttons

Use for adding, renaming, or diagnosing declarative buttons inside playbook cards, particularly HR Agent Workspace tasks that send the user to Employee Center. Resolve the actual workspace/page using [workspace-configuration.md](workspace-configuration.md); use [workspace-actions.md](workspace-actions.md) for general action controls.

## Evidence and limits

The record relationships and component event behavior below were inspected on Australia Patch 2 with Agent Workspace for HR Case Management 4.5.1. Re-resolve records and schemas on the target release and Store version; labels and historical sys_ids are not portable identities.

Observed failure: an action with a client payload and HR Playbook experience membership rendered successfully but had no UX add-on event mapping. The installed playbook component relays navigation events; its internal link event does not itself establish a workspace navigation handler. Configuration-only verification missed this gap.

The subsequent page-specific mappings to the workspace navigation handler were saved and captured, but were **not browser click-tested**. Treat that configuration as a candidate repair, not a proven end-to-end recipe. Do not infer a successful navigation test from a screenshot showing the button, an API save, or update-set capture.

## Two separate configuration chains

```text
Visibility:
Action Assignment (Playbook Card model, table, conditions, access)
  -> Playbook Experience Action Assignment Map
  -> experience selected by the runtime playbook component
  -> rendered button

UXF click behavior:
Action Assignment
  -> Specify client action (Action Payload Definition)
  -> effective payload (model defaults + assignment overrides)
  -> UX Add-on Event Mapping for the source action and runtime context
  -> controller/page handler and, if needed, page/variant relay
  -> shell navigation or modal handler
```

An experience membership record is not an event mapping. A payload definition's action key is not proof that the active workspace handles it. A generic form action layout is not a substitute for the Playbook Card model and experience membership.

## Discover the working comparison first

1. Resolve the workspace route, selected page variant, playbook component instance and experience. Distinguish Classic HR workspace from configurable HR Agent Workspace.
2. Read a working button on that same surface, such as **See activity**. Inspect the complete chain, not just its Action Assignment form.
3. Verify dictionary fields before querying; invalid encoded-query fields can be silently ignored. Use narrow fields, limits and pagination when needed.
4. Inspect these relationships:

| Table | Relevant fields / purpose |
| --- | --- |
| `sys_declarative_action_assignment` | `model`, `table`, `label`, `action_name`, `active`, `enabled`, `client_action`, `declarative_action_type`, `payload_map`, conditions, read/write requirements, render mode |
| `sys_declarative_action_payload_definition` | `label`, `action_key`, `payload_template`, `applicable_to` |
| `sys_declarative_action_payload_field` | `model`, `element`, `internal_type`, `default_value`, `configurable` |
| `sys_declarative_action_payload_mapping` | `action_payload_definition`, `model`, `payload_map`: model-level defaults |
| `sys_playbook_experience_action_assignment_map` | `playbook_experience`, `declarative_action_assignment`, optional `activity_definition`, `display_order` |
| `sys_ux_addon_event_mapping` | `source_da`, `parent_macroponent`, `source_element_id`, or `controller` and `source_component`; `target_event`, `target_payload_mapping`, `active` |
| `sys_ux_event` | Event identity including scope/API name and `props` payload schema |

The add-on mapping's source field is **`source_da`**, not `source_declarative_action`. Confirm it live before using that query.

On the inspected HR installation, **See activity** used **Playbook Open Modal**, with table/sys_id and HR modal parameters. It had both experience membership and separate UX add-on mappings: one for an older page/component instance, another for the HR playbook controller and source component. Its `current.assigned_to != gs.getUserID()` condition was specific to that button. Do not copy that restriction into a new action unless requested.

A controller mapping and a page-instance mapping are alternative context patterns, not interchangeable fields to populate indiscriminately. Follow the working pattern for the actual target. Names such as **Playbook default**, `hr_srp_playbook`, and `hr_playbook` were observed; locate the current composition rather than hard-coding them.

## Conditions for HR catalog submission

In the inspected schema, `sn_hr_core_task.template` references `sn_hr_core_template`. That template inherits `sys_template`; its `template` field contains encoded field assignments, including `hr_task_type=submit_catalog_item`. The generated HR task also stores `hr_task_type` directly. Do not assume the template has a directly queryable `hr_task_type` field or that a table named `sn_hr_core_task_template` exists.

For task-type-only requirements, a record condition can check:

```text
hr_task_type=submit_catalog_item^EQ
```

When the requirement explicitly requires a matching referenced template as well, use both gates:

```text
hr_task_type=submit_catalog_item^templateISNOTEMPTY^EQ
```

Example Script Condition for the template gate:

```javascript
!current.template.nil() &&
/(^|\^)hr_task_type=submit_catalog_item(\^|$)/.test(
    current.template.getRefRecord().getValue('template') || ''
)
```

This matches a complete encoded assignment, not a loose substring. Test missing/stale references and a nonmatching template. Requiring both gates intentionally hides the action if template and task types diverge; do not add that restriction to a task-type-only request. Add active/state/assignee restrictions only when the requested behavior needs them.

A navigation-only action can require record read access without requiring write access; choose deliberately rather than copying a mutation button's access flags. The portal still applies its own authorization. The generic To-dos URL does not guarantee that the current agent can submit somebody else's task.

## Wire portal navigation through the actual handler

1. Resolve **Playbook Link to Destination** and its applicability before deciding to reuse it or create a dedicated payload definition. Prefer reuse when its actual payload contract fits.
2. Inspect the receiving handler, not only the emitter's name. The inspected component relayed `PLAYBOOK_INTERNAL#LINK_TO_DESTINATION` toward `PLAYBOOK#LINK_TO_DESTINATION`; this did not connect it automatically to the HR workspace shell.
3. For a UXF assignment, resolve/add its `sys_ux_addon_event_mapping` for the selected component/page or controller. Verify that its target handler is actually reachable in that context. If it targets a page relay, trace the active variant's `sys_ux_screen.event_mappings` through to the shell. See [ui-builder-event-automation.md](ui-builder-event-automation.md).
4. The inspected shell handler **Open page or URL** (`sn_canvas_core.NAV_ITEM_SELECTED`) accepts an `external` object. Example destination payload:

```json
{
  "external": {
    "url": "/esc?id=hrm_todos_page",
    "target": "_blank"
  }
}
```

Use a root-relative URL for same-instance portal navigation so imports stay on the target instance. Preserve an explicitly requested cross-instance destination. Choose the target window deliberately; `_blank` preserves the workspace, while `_self` replaces it. Neither choice is universally required.

Do not assume every playbook/portal handler accepts the shell's object shape: some handlers accept a URL string. Verify the exact consumer's schema and code. Similarly, `targetRoute` for workspace navigation is not automatically the browser window target.

With an object-shaped payload, an observed assignment override was:

```text
external@url=/esc?id=hrm_todos_page^EQ
```

An add-on mapping can bind the URL from the effective event payload using:

```json
{
  "type": "MAP_CONTAINER",
  "container": {
    "external": {
      "type": "MAP_CONTAINER",
      "container": {
        "url": {
          "type": "EVENT_PAYLOAD_BINDING",
          "binding": { "address": ["external", "url"] }
        },
        "target": { "type": "JSON_LITERAL", "value": "_blank" }
      }
    }
  }
}
```

These JSON examples describe payload shape, not a guarantee that an arbitrary page can dispatch directly to the shell. Prefer UI Builder's supported mapping interface and compare a working mapping from the target version before automating metadata. Additive mappings can avoid modifying an OOTB page; do not clone the entire experience or edit base page JSON just to make a button appear.

## Verification and silent-click diagnosis

Test in the actual workspace, with an existing suitable task where possible:

- Matching task: button renders once; clicking it opens the intended portal on the correct host and in the intended tab/window.
- Adjacent task type, missing template, and nonmatching template: button is hidden according to the requested gates.
- Intended non-admin HR persona: record access, visibility and click behavior work; portal access is checked separately.
- Navigation does not complete the HR task, change its state, or submit the catalog item automatically.
- Fresh session after capture/import: verify the active page variant, reference targets and click again. If the target has a custom variant, mappings tied only to an OOTB page may not apply.

For a visible button with no result, first inspect `source_da` mappings and exact page/component/controller matches. Then inspect effective payload defaults/overrides, target event scope/schema, relay-to-shell wiring, and console errors. Investigate popup blocking when the event reaches the navigation handler; do not use it as the default diagnosis for missing wiring.

For difficult event-contract questions, inspect the installed component source read-only. In the inspected instance, `sys_ux_lib_asset` held `@servicenow/now-playbook-experience/index` and its source map, although a search of `sys_ux_lib_source_script` returned no match. Fetch with `-AsObject`, save locally, and extract only relevant source-map snippets. Do not print an entire minified asset or treat internal source as a supported extension API.

If browser authentication or target access blocks verification, identify that precise limitation and keep the correction explicitly unverified. Do not repeat a configuration-only handoff as a confirmed working fix. Server-side condition checks and in-memory negative cases are useful but do not substitute for clicking the button.

## Capture, rename and rollback

- Use the owning scope and an in-progress update set with a preference snapshot. Capture the action, payload dependencies, experience membership and UX event mappings; include relay/variant records only if actually changed.
- New payload definitions can automatically create payload fields, model mappings and field labels. Inspect their defaults and capture; do not assume that three authored records mean three customer updates or discard generated dependencies as noise.
- If the original set is completed, use a correction set rather than reopening it. Check that no hard-coded development host remains in the effective navigation payload.
- For a rename, change `label` in the current delivery set and preserve stable `action_name`, sys_id, conditions and mappings. Inspect translations if the active user language still shows another label; use the user's exact requested text.
- Restore developer preferences. Complete/export/promote only when requested. Skill maintenance alone performs no instance writes or publication.
- Rollback an added button by deactivating its assignment. For a repair to an existing action, restore its before-values and deactivate only the newly added mappings. Keep dependencies intact until deletion is explicitly authorized.

## Official documentation

Use release-matched raw Markdown through [official-docs.md](official-docs.md); these are the human-facing source links:

- [Configure HR Playbook activity actions](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/playbook-hr-act-actions-config.html)
- [Configure HR Playbook Experiences](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/playbook-hr-experiences-config.html) — distinguish changing the experience itself from adding an action membership.
- [Configure HR Service Delivery playbook card](https://www.servicenow.com/docs/r/employee-service-management/agent-workspace-for-hr-case-management/playbook-hr-card-configuration.html)
- [Link an event to another page](https://www.servicenow.com/docs/r/application-development/ui-builder/link-component-destination.html)
