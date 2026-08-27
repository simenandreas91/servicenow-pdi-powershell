# Configurable Workspace Actions Cheat Sheet

Load this reference for missing or new Workspace buttons, form action bars, list/related-list actions, row/contextual actions, field decorators, attachment actions, action groups, or action-triggered modals. First resolve the experience, route, variant, component, table/class, view, and target persona using `workspace-configuration.md`.

This reference was verified against ServiceNow's Australia documentation on 2026-08-27. Declarative Action and UI Interaction capabilities are Store/version-sensitive; inspect the installed UI Builder and Configurable Workspace versions and the live record forms before applying internal field names.

## Choose the Action Model Before Debugging It

| Mechanism | Best use | Configuration center | Runtime/placement |
| --- | --- | --- | --- |
| Traditional UI Action | Existing server-side platform action that must also work on a Workspace form, or shared business operation with channel-specific launchers | UI Action [`sys_ui_action`] | Core UI form/list; Configurable Workspace only when workspace flags/format, component, condition, and layout chain support it |
| Declarative Form Action | Customer-owned Workspace form/header action, especially conditional, grouped, modal, client/server, or reusable across experiences | Action Assignment [`sys_declarative_action_assignment`], action config, form action/layout metadata | Form action bar or configured form position |
| Declarative List Action | Selection or list-level operation | Action Assignment with List model, action config/group | List header/action bar; exact selection contract depends on list controller |
| Declarative Related List Action | Operation on a child list with access to parent context | Action Assignment with Related List model, action config/group | Related-list header/action bar |
| Field Decorator | Small icon action next to a supported field | Declarative Action with Field decorator model | Supported single-line string fields; not a general replacement for form buttons |
| Attachment Action | Attachment-specific operation | Declarative Action with Attachment model | Attachment surface |
| UXF Client Action | Dispatch a page-level payload/event from a declarative action | Action Assignment plus payload/client action and UX Add-on Event Mapping [`sys_ux_addon_event_mapping`] | Requires the active page/controller to handle or map the event |
| UI Interaction | Reusable current UI/event logic, modal, branching, form/list operation without repeating page wiring | UI Builder UI Interaction [`sys_ui_interaction`] plus trigger mapping | Can be triggered by page events or Declarative Actions; prefer on supported current releases when it avoids page ownership/per-page UXF mapping |
| UI Builder component event | Button belongs only to a customer-owned page composition | Component Events panel and handler/UI Interaction | One page/variant; use for page-specific interaction, not a global record action |
| Product action/configuration | Product-owned workflow action, case type, playbook, SOW/HR/CSM operation | Product admin center/guided setup and product metadata | Product-specific page/component/action chain |

Prefer a Declarative Action or UI Interaction when the requirement is Workspace-specific and additive. Do not convert a working shared UI Action merely for consistency. Keep shared business logic in a server-side Script Include/Flow/action and use a thin launcher for each channel when client APIs differ.

## Declarative Action Record Graph

The visible button is not one record. Trace this graph for the exact model and runtime component:

```text
Action Assignment [sys_declarative_action_assignment]
  - model: form | list | related list | field decorator | attachment
  - table/view/experience applicability
  - active, label, order, implementation
  - access and visibility conditions
  - action configuration membership
  - exclusions / model fields
  - UX add-on event mapping when UXF client action is used

Form path:
  Action Assignment
    -> UX Form Action [sys_ux_form_action]
      -> UX Form Action Layout Item [sys_ux_form_action_layout_item]
        -> layout membership [commonly sys_ux_m2m_action_layout_item]
          -> UX Form Actions Layout [sys_ux_form_action_layout]
            -> action configuration [sys_ux_action_config]
              -> Form Controller / action bar on selected page

List / related-list path:
  Action Assignment
    -> action configuration [sys_ux_action_config]
    -> optional list action group [sys_declarative_action_group]
    -> Record List / related-list controller and action component
```

Form layout groups use UX Form Actions Layout Group [`sys_ux_form_action_layout_group`] and membership such as `sys_ux_m2m_action_layout_group_action`. Action exclusions commonly use Workspace Declarative Action Exclusion [`sys_workspace_declarative_action_exclusion`]. Resolve actual references from the current action form and related lists; do not construct M2M records from memory.

An action configuration groups actions for an experience/component. A form action layout controls which form actions appear and how they are ordered/grouped. They are related but not interchangeable.

## Visibility Is a Pipeline

An action renders only if every applicable gate succeeds:

```text
correct experience, route, variant, page, and component
  AND correct action model for that component
  AND active assignment/wrapper/layout item/membership/layout/configuration
  AND exact runtime table inheritance and view applicability
  AND experience restriction/global-experience settings
  AND no action exclusion
  AND form position/group/order is renderable
  AND user satisfies role/read/write requirements
  AND record/dynamic/script/client condition is true
  AND component/controller is wired to the selected action config/layout
  AND required event/UI interaction mapping exists
```

Treat a blank action bar differently from one missing action. A blank bar usually indicates the wrong/missing layout, action configuration, component/controller binding, child-table specificity, or `use_layout_items_only` membership. One missing action usually points to the assignment/wrapper/layout item, applicability, exclusion, condition, or access.

## Condition and Security Fields

Exact labels vary by action model and release. Common controls include:

- **Table** and **View** applicability;
- **Enable for all configurable experiences** or experience restriction/workspace association;
- **Requires read access** and **Requires write access**;
- server **Script Condition**;
- encoded/dynamic record conditions, with dynamic evaluation enabled when required;
- client condition or scripted client condition;
- required roles and action exclusions;
- active state and order;
- form position such as `action_bar`;
- action layout/group active state and membership;
- parent record context for related-list actions.

Use server/record conditions to avoid returning an inapplicable action, and keep the executing server operation authorized independently. Client conditions improve responsiveness but are not an authority boundary. The server implementation must re-check table, record state, user access, roles/group membership, and allowed transition before writing.

## Implementation Types

### Server script

Use for a bounded immediate server operation that needs no additional UI input. Keep it idempotent where practical, validate access and state, update only intended fields, and return a clear success/error contract. The action must still be refreshed in the form/list afterward if its result changes the visible record.

### Client script

Use for supported Workspace client orchestration such as collecting values with a supported modal API and then calling a guarded server endpoint. Do not place the business rule solely in the client. Core UI APIs such as `GlideDialogWindow` are not interchangeable with Workspace modal APIs.

### UXF Client Action

Use when an existing page/controller contract requires a dispatched UX Framework event. Verify:

1. the Action Assignment references the correct payload/client action;
2. the selected page/controller contains the matching UX Add-on Event Mapping;
3. the event payload fields are bound to current table/sysId/selection values;
4. the handler opens the intended viewport/modal or operation;
5. close/save/success events refresh the correct controller/resource.

A working mapping on one workspace page proves nothing about another page variant. The mapping is page/controller-specific unless the product supplies a shared contract.

### UI Interaction

On current supported releases, prefer a UI Interaction when the same reusable interaction should be invoked from components or Declarative Actions without per-page UXF add-on mapping. It can combine UI, logic, branching, form/list steps, and custom modal content. Confirm the installed Store version supports the required trigger/steps and that the interaction has explicit inputs matching the action context.

UI Interactions do not execute by themselves; attach one to a page/component event or configure the Declarative Action implementation to trigger it.

## Traditional UI Actions in Configurable Workspace

A UI Action visible in Core UI is not automatically a Workspace action. For a Workspace form action, inspect:

- Active, table, inheritance, condition, roles, view, and client/server implementation;
- **Workspace Form Button** (`form_button_v2`) when it should display as a Workspace form button;
- **Format for Configurable Workspace** (`format_for_configurable_workspace`) when supported by the release/action;
- Workspace-compatible client script (`client_script_v2`) if a client launcher is required;
- matching UX Form Action wrapper/layout item/layout chain if the installed model creates or expects one;
- selected page's Form Controller/action layout and action-bar component;
- server-side access and state guard.

Do not add wrapper/layout records blindly. Some releases automatically create layout metadata when a form action is formatted for Configurable Workspace; some product migrations already supply it; some simple server-side UI Actions render directly when properly flagged. Compare a working OOTB action with the failing action on the same table, view, layout, and page.

If the UI Action needs a legacy Core UI dialog and a Workspace modal, use two thin channel-specific client launchers that call one guarded server implementation. Do not make one client script branch through unsupported DOM or dialog APIs.

## Form Action Layout Selection

ServiceNow documents two selection paths:

1. **Explicit:** the Form Controller's **Action layout** property points to a UX Form Actions Layout.
2. **Specificity:** when no layout is assigned directly, the runtime selects by layout table and action configuration specificity; lower Order wins when specificity is equal.

For a missing or blank bar, capture:

- Form Controller instance and its action-layout/action-configuration bindings;
- selected exact runtime table, including extension class;
- every candidate layout's table, action config, order, active/unified state, and `use_layout_items_only` behavior;
- active layout items and M2M memberships;
- group membership/order and overrides;
- whether the action bar's model inputs are bound to the Form Controller. In generated workspaces, verify `actionNodes`, declarative action model, and client-action contract bindings rather than assuming the component preset is complete.

A more-specific child-table layout can replace a healthy parent layout. If it uses only explicit layout items, omitted memberships can suppress inherited actions and produce an empty bar.

## List and Related-List Actions

Check all of the following:

- correct action model: List versus Related List;
- exact table and view, including parent table for related lists;
- list/related-list action configuration bound to the component/controller;
- selection model: no selection, single, or multiple records;
- action model fields required by its script/payload;
- row versus header placement and component support;
- active action group and membership/order if grouped;
- experience restriction and exclusions;
- dynamic record/selection condition and read/write access;
- parent record access for related-list actions;
- list refresh and selection clearing after execution.

A form action does not become a list action because the label and table match. Create or reuse the action model intended for the list surface.

## Record Header, Contextual, and Page Buttons

- Primary record-header actions normally come from the Form Controller/action layout rendered by the action bar.
- A button authored directly on a customer-owned UI Builder page is a component event, not automatically a record action. Bind it to current context and an explicit handler/UI Interaction.
- Product “contextual actions” can be product components, Recommended Actions, playbook actions, or Declarative Actions. Inspect the component/preset and product configuration before applying generic action metadata.
- A button inside a custom tab/modal/page collection has that nested page's event context; it may not inherit the outer form controller unless explicitly exposed.

## Missing in Workspace but Visible in Backend: Exact Flow

1. **Capture the comparison.** Same user, record, table/class, state, and view if possible; full Workspace URL; screenshot; whether the entire action bar or one label is missing.
2. **Resolve implementation.** Open the Core UI control and identify whether it is `sys_ui_action`, a Declarative Action, a product action, or a UI Builder component. Do not infer from label.
3. **Check Workspace eligibility.** For a UI Action, inspect Workspace Form Button, Format for Configurable Workspace, client compatibility, view, active state, and table inheritance. For a Declarative Action, confirm the correct model/position/implementation.
4. **Resolve selected page.** Identify experience, route, variant, page definition, Form/List Controller, action bar/list component, action configuration, and explicit action layout.
5. **Trace metadata chain.** Confirm active wrapper, layout item, layout membership/group, layout/config association, exclusions, and exact child-table specificity.
6. **Evaluate conditions.** Record condition, script condition, client condition, dynamic-evaluation flag, roles, read/write requirements, view, experience restriction, and parent context.
7. **Check security.** Re-run server access checks as the target persona. Admin success is not evidence. Verify the server operation re-authorizes execution.
8. **Check event contract.** For UXF, find the exact selected page's add-on event mapping and payload. For UI Interaction, confirm trigger and inputs. For server action, confirm refresh behavior.
9. **Compare working OOTB action.** Same page, component, table/view, persona, and layout. Compare the first differing gate rather than copying its records.
10. **Fix at the narrowest owner.** Prefer flags/configuration, an additive customer-owned assignment/layout item, existing action configuration, UI Interaction, or product extension. Avoid duplicating the base page.
11. **Validate.** Fresh session, target persona, deny persona, true/false record states, base/child table, operation result, explicit refresh, no duplicate button, and update capture/dependencies.

### Ranked causes

For one missing button:

1. UI Action not formatted/eligible for Configurable Workspace;
2. assignment/wrapper/layout item or membership absent/inactive;
3. wrong table, view, position, experience restriction, or exclusion;
4. condition or read/write access false;
5. wrong page variant/action configuration;
6. UXF mapping or UI Interaction trigger missing;
7. stale session/Store migration issue.

For an empty bar:

1. action-bar component missing or not wired to Form Controller;
2. explicit Action layout references wrong/missing record;
3. more-specific child-table layout wins and has no members;
4. action configuration differs from the layout/items;
5. promoted layout M2M dependencies are missing;
6. migration/unification mismatch after upgrade.

## Add a New Workspace Action: Recipe

1. Write acceptance criteria: surface, exact tables/classes/views, record condition, persona, inputs, server result, UI response, false/denied cases.
2. Resolve the actual workspace/page/controller/action configuration/layout and application ownership.
3. Reuse an OOTB action or product extension when it already implements the business result.
4. Choose Form, List, Related List, Field Decorator, Attachment, page button, or product action. Choose server script, client orchestration, UXF, or UI Interaction.
5. Implement server authorization/data integrity independently from visibility. Prefer a reusable Script Include/Flow operation for shared logic.
6. Create customer-owned metadata in the correct scope. For form actions, add only the necessary wrapper/layout item/layout membership; reuse a suitable layout/configuration when supported.
7. Configure applicability, exclusions, conditions, roles/read/write requirements, order/group, and experience restrictions explicitly.
8. Wire payload/events and success/failure/refresh behavior. Use current `table`, `sysId`, parent, or selection context, never a hard-coded record sys_id.
9. Re-read the complete chain and confirm natural update capture/application files. Check for unexpected ServiceNow-owned page ownership.
10. Test operation and rendering as intended and denied users, in matching and nonmatching states/tables/views, plus Core UI if shared.
11. Promote the coherent dependency set and repeat the target tests. Rollback by deactivating/removing only the additive customer-owned action metadata or restoring captured before-values.

## Action-Triggered Modal Recipe

Prefer, in order:

1. a supported product/OOTB modal action;
2. a current UI Interaction containing modal/form steps;
3. an existing product form-modal route/viewport contract;
4. a UXF Client Action plus add-on event mapping to a customer-owned modal page/viewport;
5. a supported simple Workspace modal API plus guarded Ajax/server endpoint;
6. a new custom modal component only when native patterns cannot satisfy the interaction.

For a routed/viewport modal, verify route, required inputs, parent macroponent, parent composition element ID, page collection/variant, open/close/save payload, and refresh target. Use a dedicated narrow form view for modal fields when the modal is a form, with server-side enforcement for required values and allowed transition. Also load `lessons-workspace-modals.md` for the existing modal recipes.

## Transport and Upgrade Checks

- Package the assignment/action, implementation dependencies, action config association, wrapper/layout item/layout/group/M2Ms, exclusions, model fields, event mapping or UI Interaction, modal page/route/screen/page definition, form view/policies, and server logic that the action uses.
- Reuse target OOTB dependencies only after verifying the same Store/plugin version and stable record identity. A target can contain the wrapper but not the expected layout item.
- Preview missing-reference errors. Never accept a missing layout item/M2M and call the action deployed.
- Verify the change did not take ownership of a ServiceNow page merely to attach an event. Current UI Interactions and Declarative Actions are designed to reduce that upgrade risk.
- After upgrades, compare layout unification/migration status, action config, page/controller contracts, and product release notes before rebuilding records.

## Official Sources

- [Declarative Actions overview](https://www.servicenow.com/docs/r/platform-user-interface/declarative-actions-landing.html)
- [Declarative Actions glossary](https://www.servicenow.com/docs/r/platform-user-interface/declarative-actions-glossary.html)
- [Create Declarative Action buttons](https://www.servicenow.com/docs/r/platform-user-interface/creating-declarative-actions.html)
- [Configure an action configuration](https://www.servicenow.com/docs/r/platform-user-interface/config-da-action-configuration.html)
- [Configure a form action layout](https://www.servicenow.com/docs/r/platform-user-interface/configure-da-action-layout.html)
- [Create a UXF client action for forms](https://www.servicenow.com/docs/r/platform-user-interface/create-a-new-uxf-client-action-for-forms.html)
- [Bind an event to a Declarative Action](https://www.servicenow.com/docs/r/application-development/ui-builder/bind-event-declarative-action.html)
- [Trigger a UI Interaction from a Declarative Action](https://www.servicenow.com/docs/r/platform-user-interface/configure-da-ui-interactions.html)
- [Create a UI Interaction](https://www.servicenow.com/docs/r/application-development/ui-builder/create-ui-interaction-show-alert.html)
- [UI Interaction toolbox steps](https://www.servicenow.com/docs/r/application-development/ui-builder/uib-ui-interaction-steps.html)
- [Hide a form action from a layout](https://www.servicenow.com/docs/r/platform-user-interface/hide-global-actions-from-a-page-layout.html)
- [Create a list or related-list action](https://www.servicenow.com/docs/r/platform-user-interface/create-a-new-list-or-related-list-action.html)
- [Configure a page variant as a modal](https://www.servicenow.com/docs/r/platform-user-interface/configure-a-page-variant-as-a-modal-in-uib.html)
- [Configurable Workspace release notes](https://www.servicenow.com/docs/r/release-notes/configurable-workspace-rn.html)

Use community diagrams only to understand relationships, then verify every record/table/field and recommendation in official docs and the live target. The action framework has changed materially across releases.
