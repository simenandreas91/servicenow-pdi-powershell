# Workspace Troubleshooting and Delivery Recipes

Use this reference when the request begins with a symptom: missing button/tab/list/component, wrong form/view/page variant, stale data, cross-user/table/workspace differences, failed promotion, or upgrade regression. Load `workspace-configuration.md` for the ownership model and `workspace-actions.md` for any action surface.

## Diagnostic Frame

Record this evidence before opening an editor:

```text
Environment/build:
Workspace title and exact runtime URL:
Store apps/versions (workspace, UI Builder, Configurable Workspace):
Affected user/persona, roles/groups/domain:
Working comparison user/workspace/table/record:
Table and actual sys_class_name:
Record sys_id and relevant state/field values:
Expected behavior:
Actual behavior and timestamp:
Browser console/network error or request:
Current scope and delivery vehicle:
```

Use one working-versus-failing comparison. Change one dimension at a time: user, record, table/class, route parameter, workspace, view, page variant, or environment. This turns a plausible story into evidence.

## Fast Triage Tree

```text
Is the whole page/layout different?
  yes -> experience -> route -> parameters -> variant -> page definition
  no
Is it a field/section/form rule?
  yes -> selected view -> form metadata -> view rules -> policies/scripts -> ACL
Is it a tab?
  yes -> classify session / record-page / form-section / sidebar tab
Is it a list/related list?
  yes -> list-menu or form-related-list metadata -> component/controller -> ACL
Is it an action/button?
  yes -> action type -> assignment/wrapper/layout/config -> condition/security -> event
Is data empty/stale?
  yes -> binding -> data resource/controller -> server query/security -> refresh event
Is it only one user?
  yes -> audience/user criteria -> ACL/role/domain -> personalization/cache
Is it only one environment/after upgrade?
  yes -> Store versions/plugins -> captured dependency graph -> preview/migration/cache
```

## Symptom Matrix

| Symptom | Most likely causes | Inspect first | Prove/fix direction |
| --- | --- | --- | --- |
| Button missing | not Workspace-compatible; wrong action model/layout/config; false condition/access; page lacks action bar/mapping | selected page/controller, action type and full chain | compare one working action at each gate; fix first difference; see `workspace-actions.md` |
| Entire action bar blank | action bar/Form Controller binding missing; explicit/winning layout empty; child layout overrides parent; M2M not transported | Form Controller/action bar, exact table candidate layouts and memberships | bind correct controller/layout or restore coherent layout membership; do not recreate all actions |
| Tab missing | wrong tab family; different variant; component visibility; form view/related list; product configuration | classify tab, selected variant, Tabs component/preset, selected form view | change tab's actual owner; test empty/unauthorized cases |
| Component not rendering | wrong variant; hidden condition; missing/invalid page definition; missing component dependency; runtime error | Experience view, screen page definition, content tree, console/network | restore reference/dependency or binding; avoid raw macroponent edits until builder path is exhausted |
| Different users see different page | audience/order, ACL/role/domain, user criteria, personalization, cache | variant audience/condition/order; route and table/field ACL | impersonate/test persona; compare evaluated criteria and network response |
| Different tables/classes behave differently | table route parameter; variant condition; child view/layout/policy/action; product subtype config | `table` and `sys_class_name`; child-specific screen/view/layout | compare base and child chain; preserve intentional specificity |
| Unexpected page variant | multiple matches/order; wrong route input; stale session; missing audience/condition after promotion | all active screens for exact screen collection | evaluate each candidate with runtime values; lower order wins equal matches |
| Data missing | binding path; resource never executed; ACL/before-query/domain/cross-scope; invalid query | resource Preview and operation status; network/server response | validate context inputs, result shape, user-context query and ACL |
| Data stale after action | no refresh; wrong resource/controller refreshed; operation async; client state diverged | action success handlers and data resource/Form Controller events | refresh exact controller/resource after confirmed server success |
| Related list missing | wrong selected view; relationship absent; tab component filters it; Workspace View Rule; ACL/no rows | `sys_ui_related_list`, exact view, relationship, record page tabs | configure selected view or component; distinguish true related list from product Related Records |
| Form uses wrong view | explicit component property; route `view`; Workspace View Rule; experience page property; fallback | Form Controller, URL params, `sysrule_view_workspace`, page properties | correct the narrow selection rule/property; do not edit every candidate view |
| Workspace layout unexpected | wrong experience/route/variant; ServiceNow-owned page changed; template/Store version mismatch | URL path, route, screen, macroponent, Store version | restore intended variant/dependency or supported extension; document page ownership |
| DEV works, target fails | missing dependencies; Store/plugin/version drift; sys_id/reference mismatch; mixed scopes; incomplete update set | preview problems, app/plugin versions, customer-update graph | install/align prerequisites, transport coherent app/update set, resolve target references |
| Behavior changed after upgrade | Store page/controller/action contract changed; customer-owned clone skipped updates; migration/unification incomplete; cache | release notes, skipped changes, action/layout migration, page ownership | reconcile customer changes with new OOTB artifact; do not blindly restore old JSON |

## Reverse-Engineering an Existing UI Element

Start with only what the user can point at.

1. Capture the label, location, icon, nearby components, click result, target URL/modal, and affected table/record.
2. Classify the surface: shell/navigation, page component, form element, action, list, related list, record-page tab, form section, sidebar, visualization, product/playbook content.
3. Resolve experience, route, selected variant, and page definition from the runtime URL.
4. In UI Builder select the likely component in the content tree. Record its stable element ID, preset/controller, properties, visibility, bindings, and events.
5. Follow bound configuration IDs/references to their owner. Examples: `listConfigId` -> UX list menu; action config -> action assignments/layout; form controller view -> form metadata; event -> UI Interaction/add-on mapping; viewport -> nested page.
6. If the component imports platform configuration, inspect the exact view/list/action/product records rather than altering the component.
7. Trace the click through emitted event, payload, handlers, server operation, navigation/modal, and refresh.
8. Confirm with a read-only comparison: change to another record/user/table and observe which condition changes.
9. Document the complete path as `visible element -> page element ID -> binding/config -> underlying metadata -> security/runtime rule`.

## Tools and Best Use

| Tool | Best for | Cautions |
| --- | --- | --- |
| UI Builder Experience view | routes, page hierarchy, variants, audiences, conditions, order, settings | Previewing a selected variant does not prove runtime selection |
| UI Builder Developer menu | open exact variant collection, variant record, page definition | internal records/JSON are diagnostic; use supported builder/configuration for edits |
| Content tree and Data/scripts drawer | component IDs, nesting, presets, bindings, data resources, client state, events | inspect selected variant, not same-named page elsewhere |
| Open URL path / actual Workspace | runtime route and variant selection | use clean session and target persona |
| Next Experience Developer Tools / Inspector | component tree and IDs, property/state update journal, dispatched/handled actions, events, traces/waterfall, service workers, client/server logs and health indicators | optional Chrome extension; verify installed version, capture only the failing interval, and do not expose sensitive state/log data |
| Browser DevTools Elements | confirm rendered component boundary/attributes | do not design fixes around private DOM structure |
| Browser Console | component/client script/runtime exceptions | preserve stack, page/element ID, timestamp; clear unrelated historical errors |
| Browser Network | route, GraphQL/REST/data-resource response, status, timing, payload shape | redact tokens/PII; a 200 can still contain filtered/empty data |
| ServiceNow security debugging | ACL decision and access path | run controlled target-persona test; disable debugging afterward |
| Logs/transactions | server script, REST, GraphQL, Business Rule, error timing | correlate exact request/user/time; avoid broad log dumps |
| Table API helper | narrow metadata/data traversal and post-write reread | inspect live shape; use stable keys and selective fields |
| Xplore | bounded server-side reference traversal, access/result comparison | read-only by default; do not turn diagnosis into repair |
| SN Utils | copy sys_id, inspect current record, encoded queries, script utilities | never expose Agent API/token; verify environment and record ownership |
| Cached instance index/impact graph | discover candidate artifacts and dependencies | refresh/verify every edit candidate live |
| ATF Workspace support | repeatable component/form regression where supported | align target Workspace/form UI and Store version; supplement with persona/security tests |

### Browser inspection recipe

1. Reproduce in a fresh tab with Preserve log enabled only when navigation must be captured.
2. Clear console/network, trigger once, note exact timestamp.
3. Filter network to failed requests and relevant table/GraphQL/REST routes.
4. Compare request inputs with route/client-state values and response shape with the component binding.
5. Repeat as working persona/record and diff status, payload keys, row count, and timing—not sensitive content.
6. Map a client error's component/page ID back to UI Builder content tree/page definition.

## Practical Example A: Backend UI Action Missing in Workspace

Scenario: a UI Action appears on the Core UI form but not on the Configurable Workspace record.

1. Confirm same user, record, state, table/class, and view. Identify `sys_ui_action` exactly.
2. Inspect Active, table/inheritance, roles, condition, view, client/server type, Workspace Form Button, Format for Configurable Workspace, and Workspace client script.
3. Resolve Workspace experience, route, variant, Form Controller, action bar, action configuration, and form action layout.
4. Determine whether the installed release generated/expects a `sys_ux_form_action` wrapper and active layout item/membership.
5. Compare exact child-table layout and parent layout; check explicit controller layout, specificity/order, `use_layout_items_only`, groups, and exclusions.
6. Evaluate roles/read/write ACL and the action condition as target user. Re-check in server implementation.
7. If a client/UXF action, trace payload and the selected page's add-on event mapping or UI Interaction trigger.
8. Compare a working OOTB action on the same page/layout. The first differing gate is the leading cause.
9. Best-practice fix: enable supported UI Action flags when it is truly shared; otherwise create an additive Declarative Action/UI Interaction with shared guarded server logic. Do not duplicate the record page for one button.
10. Validate visible/hidden states, actual operation, refresh, denied user, Core UI regression, duplicate buttons, and packaging.

## Practical Example B: Two HR Services Behave Differently

Scenario: two HR cases open in the same Agent Workspace, but one shows different actions or tabs.

1. Capture both case table names and `sys_class_name`, HR service, COE, lifecycle/ER subtype, state, subject/opened-for context, and actual URLs.
2. Confirm both use configurable scope `sn_hr_agent_ws`, not deprecated Classic HR workspace.
3. Compare route parameters and selected page variant. A table-specific condition may select a different page.
4. Compare Workspace View Rule and selected `Workspace UIB` view for each exact child table: fields, sections, related lists, and tab order.
5. Compare Page Configurations/product properties that list supported tables or service behaviors.
6. For actions, compare the selected child-table form action layout, action item memberships, conditions, roles/access, and service/state conditions. A child layout can override the base HR case layout.
7. Compare HR Service configuration, case template/process/playbook, COE/product feature configuration, and plugin/version prerequisites.
8. Test both records as the same HR persona, then compare a denied persona. Do not assume a visual difference is an ACL defect if product configuration intentionally differs.
9. Fix the narrow service/child-table/page/view/action configuration. Also load `hr-agent-workspace-configuration.md`.

## Practical Example C: Add a Custom Record Tab

Requirement example: show a table-related summary only for Incident records and only to the fulfiller audience.

1. Resolve the actual record route, Incident variant, page definition, Tabs component/preset, and extension points.
2. Determine whether the requested content is already a form section, related list, Related Items definition, page collection, or OOTB component. Prefer that owner.
3. Prefer a supported extension point/page collection or a narrowly conditioned customer-owned variant. Avoid copying the full ServiceNow record page solely for one tab.
4. Add an OOTB component/page to the tab and bind `table`/`sysId` from context or Form Controller. Use a bounded data resource only if controller/related-list data cannot supply it.
5. Configure visibility for Incident and intended audience as presentation; enforce data ACLs separately.
6. Wire row/navigation/events and explicit refresh if the tab can change data. Provide empty/loading/error states.
7. Test Incident versus another Task class, allowed versus denied user, data versus empty, direct URL/navigation, keyboard/focus, narrow/reflow, and session restore.
8. Confirm route/screen/page collection/component/data resource/audience dependencies are captured without taking ownership of unrelated OOTB pages.
9. Promote and validate the actual target URL/persona. Roll back by removing/deactivating the additive tab/extension/variant.

## Practical Example D: Find Where a Visible Button/Tab/List Is Configured

1. Capture exact runtime URL and the element's location/result.
2. Resolve the experience path, exact route, runtime parameters, selected screen variant, and page definition.
3. In the content tree identify the containing component and element ID.
4. If it is a direct component, inspect its properties, bindings, visibility, and events.
5. If it is generated/imported content, follow its config reference:
   - Form Controller -> selected view, form/related-list metadata, action layout;
   - List Menu/Record List -> UX list menu/list or list view/controller;
   - Action bar -> action configuration/layout/assignment;
   - Tabs -> authored tab/page collection or selected form sections/related lists;
   - contextual/product component -> page property or product Page Configuration;
   - viewport -> nested route/screen/page definition.
6. Trace security and the event/data path.
7. Reproduce with one controlled difference to prove the owner.
8. Record the stable natural keys and traversal path, not portable sys_ids.

## Related List Exists in Core UI but Is Missing in Workspace

1. Confirm Core UI and Workspace are using the same table/class and form view. They usually are not.
2. Resolve Workspace's selected view through Form Controller, route view parameter, Workspace View Rule, page property, and product fallback.
3. Inspect `sys_ui_related_list` for that exact table/view and the relationship/reference record.
4. Inspect Record Page Tabs/Related Lists component and controller inputs; confirm the related-list surface is present on the selected variant.
5. Check Workspace View Rule tab order/visibility and product-specific Related Items/grouping configuration.
6. Check parent-record and child-table ACLs, domain, before-query rules, audience, and whether zero rows are hidden by the component.
7. Check related-list action configuration only after the list itself renders.
8. Add/configure the related list in the selected view or supported product surface. Do not add a duplicate custom list component unless a true related list cannot meet the requirement.
9. Test populated/empty, create/read-only/denied, base/child table, and correct parent filter.

## Wrong Form View or Layout

1. Record exact table/class and URL optional parameters.
2. Read Form Controller view inputs and any static value.
3. Inspect route `view`/`views` values and navigation event payload.
4. Evaluate `sysrule_view_workspace` records by table, role, condition, order, and UX view-rules configuration.
5. Inspect experience/page `view` property or product Page Configurations.
6. Confirm selected `sys_ui_view`, sections/elements, related lists, and user personalization.
7. Compare actual form response/bindings to the expected view.
8. Change the narrow selector or the exact selected view, not every similarly named view.

## Action Executes but UI Does Not Refresh

1. Prove the server update completed by re-reading the record; distinguish async pending from finished.
2. Inspect success handler, not only click handler.
3. Identify the rendered data owner: Form Controller, record lookup, list controller, GraphQL/REST resource, or client state.
4. Map success to the exact resource/controller refresh operation; do not refresh a duplicate resource instance.
5. Update/clear selection and modal state as needed.
6. Handle failure separately; never refresh into an apparently successful state after a rejected write.
7. Test slow response, failure, double click/idempotency, and whether action visibility changes after the refreshed state.

## Deployment and Transport

### Choose one coherent delivery model

- For an established Global/product/update-set implementation, use scoped update sets per application and the skill's update-set controls.
- For a customer-owned scoped application managed by App Repository/source control/ServiceNow SDK, keep the application/source project authoritative and transport the app version.
- Do not edit one UX artifact through competing builder, Table API, update-set, SDK, and source-control paths without reconciling ownership.
- ServiceNow Store/product pages are dependencies, not customer deliverables. Verify their required target versions.

### Dependency inventory

Depending on the change, include or verify:

- experience/page registry, app configuration, page properties, route, screen collection, screen conditions/audiences, page definition;
- page collections/extension points, controllers, data resources/transforms, client scripts, events, UI Interactions, custom components/assets;
- UX list menu/categories/lists/applicability;
- action assignments/configurations, wrappers, layouts/items/groups/M2Ms/exclusions/model fields/event mappings;
- views, forms/sections/elements, related lists, list layouts/elements, UI Policies/actions, Client Scripts, UI Actions;
- ACLs/roles/application access and product-owned configuration only when intentionally changed;
- server Script Includes/Flows, properties, search/analytics/playbook dependencies;
- Store apps/plugins and minimum versions.

### Pre-promotion checklist

- correct scope/current update set or app project selected before each change;
- exact changed records re-read; customer updates/app files present;
- no unexpected OOTB page definition ownership or broad layout churn;
- all referenced records resolve in source and have a target transport/install path;
- mixed-scope artifacts separated/coordinated without moving update XML rows manually;
- preview/update-set summary has no missing dependencies, deletes, collisions, or unrelated records;
- target Store/plugin/UI Builder versions recorded;
- rollback and post-deploy URL/persona tests documented.

### Target validation

1. Verify prerequisite Store apps/plugins and versions before commit/install.
2. Preview and resolve missing references/collisions; do not force/skip a dependency to make preview green.
3. Re-resolve experience, route, screen, page definition, views, list/action configs, and customer-owned references by stable identity.
4. Clear only the relevant cache/session through supported means; start a fresh Workspace session.
5. Run the original reproduction and negative/persona/table cases.
6. Verify network/console, data refresh, security, performance, update/install state, and no duplicate routes/actions/tabs.

### Common target failures

- screen imported without its macroponent/page definition;
- route/screen condition/audience imported without M2M/user criteria;
- action layout membership references an absent layout item;
- custom page references a Store component not installed at target version;
- page property embeds a source sys_id that does not exist at target;
- UI Builder page saved in one scope while form/action records captured in another;
- classic form view or related-list metadata omitted because only UX records were reviewed;
- target has a more-specific view/layout/variant that wins;
- cloned OOTB page skipped upgraded controller/event contracts;
- stale session mistaken for deployment failure.

## Upgrade Regression Recipe

1. Record pre/post family patch and every relevant Store app version.
2. Reproduce on one known record/persona and capture console/network.
3. Identify whether the customer owns/cloned the selected page, component, controller, action layout, or view.
4. Compare route/screen/page-definition references and skipped upgrade changes.
5. Review product, UI Builder, Configurable Workspace, Declarative Action/UI Interaction release notes and migration status.
6. For actions, verify layout unification/migration and controller contract. For pages, verify page definition and component dependencies. For forms, verify view rules and product configuration.
7. Reapply the customer requirement using the current supported extension point/configuration instead of restoring obsolete page JSON.
8. Test an adjacent OOTB flow to detect broader reconciliation damage.

## Compact Handoff Template

```text
Finding/root cause:
Runtime chain: experience -> route -> variant -> page/component -> downstream metadata
Evidence: URL, persona, table/class, record state, working comparison
Changed artifacts and scope:
Delivery vehicle/update set/app version:
Tests: intended, denied, false-condition, base/child, empty/populated, refresh
Console/network/security result:
Target prerequisites/dependencies:
Rollback:
Remaining release/product-specific risk or manual check:
```

## Primary Official Sources

- [Manage UI Builder pages and variants](https://www.servicenow.com/docs/r/application-development/ui-builder/work-pages.html)
- [Control variant conditions](https://www.servicenow.com/docs/r/application-development/ui-builder/control-conditions-for-your-variant.html)
- [Data resources](https://www.servicenow.com/docs/r/application-development/ui-builder/data-resources.html)
- [Manage events](https://www.servicenow.com/docs/r/application-development/ui-builder/work-events.html)
- [Forms in Configurable Workspace](https://www.servicenow.com/docs/r/platform-user-interface/form-configurable-workspace.html)
- [Lists in Configurable Workspace](https://www.servicenow.com/docs/r/platform-user-interface/lists-configurable-workspace.html)
- [Administering forms](https://www.servicenow.com/docs/r/platform-user-interface/administer-forms-configurable-workspace.html)
- [Declarative Actions glossary](https://www.servicenow.com/docs/r/platform-user-interface/declarative-actions-glossary.html)
- [Workspace API / UX metadata](https://www.servicenow.com/docs/r/application-development/servicenow-sdk/fluent-workspace-api.html)
- [Resolve a missing page definition](https://www.servicenow.com/docs/r/application-development/ui-builder/resolve-missing-page-definition.html)
- [Next Experience Developer Tools release notes](https://www.servicenow.com/docs/r/release-notes/ned-tools-rn.html)
- [Application Repository](https://www.servicenow.com/docs/r/application-development/application-repository-self-hosted/app-repo.html)

Recheck the applicable family and product documentation during a real task. Use official docs for current behavior; community guidance can suggest a table relationship but must not override the live Store version or supported configuration surface.
