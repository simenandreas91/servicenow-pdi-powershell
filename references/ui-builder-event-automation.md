# UI Builder Event Automation

Use this reference when creating, repairing, or validating UI Builder component-event mappings through ServiceNow metadata instead of relying on repeated manual builder steps. It applies to customer-owned pages and components in an explicitly authorized non-production environment. Also load `workspace-configuration.md`; load `ui-builder-custom-components.md` when the producer is a CLI or Component Builder custom component.

UI Builder event metadata is release- and Store-version-sensitive. Confirm the instance family/build, UI Builder version, live table shapes, owning scope, active page variant, current update set, and one known-good mapping from the same instance before writing. Prefer the supported Events surface when it works. Backend automation is a controlled fallback, not permission to edit ServiceNow-owned pages or production.

## The Complete Event Chain

A working component-to-Workspace record navigation is not one record:

```text
component framework dispatch
  -> source sys_ux_event
  -> component sys_ux_macroponent.dispatched_events
  -> component instance mapping in page sys_ux_macroponent.composition
  -> page-owned relay sys_ux_event
  -> page sys_ux_macroponent.dispatched_events
  -> active variant sys_ux_screen.event_mappings
  -> inherited shell event (normally sn_canvas_core.NAV_ITEM_SELECTED)
  -> sys_ux_app_route route_type=record with fields table,sysId
```

Definitions live in `sys_ux_event`. Ordinary component and page mappings are serialized in `sys_ux_macroponent.composition` and `sys_ux_screen.event_mappings`; they are not separate `sys_ux_event` rows. `sys_ux_addon_event_mapping` is for UX add-on/declarative-action mappings and is not the default storage for a custom component click.

## Required Stable Inputs

Resolve these live rather than accepting copied sys_ids:

- named environment/profile and verified instance URL/user;
- application scope and current in-progress update set;
- experience path/app configuration;
- exact route and active screen collection/variant;
- page definition referenced by that variant;
- component instance `elementId`, component tag/toolbox record, and component macroponent;
- source event name, label, and payload schema;
- destination route type and required fields;
- inherited target handler by API name/event name in the current instance.

For record navigation, the component contract should normally be `{table, sysId, source}`. The page owns `route: "record"`; the component must not embed a page, route-record, relay, or instance sys_id.

For scoped list navigation, prefer one reusable component contract such as `{table, query, listTitle, source}` and keep route ownership in the page mapping. Resolve the list route from the live app configuration before choosing it. In Workspace releases that expose `route_type=simplelist`, the observed contract is normally required field `table` plus optional parameters `query`, `listTitle`, and `disableInlineEditing`. Bind the event payload into those route fields/parameters and set `disableInlineEditing` as a page-owned literal when the list is intended for drill-down rather than editing.

## Read-Only Discovery

1. Run `Get-ServiceNowPdiHealth.ps1` for substantial or resumed work.
2. Resolve the experience and app configuration, then traverse `sys_ux_app_route -> sys_ux_screen_type -> sys_ux_screen -> sys_ux_macroponent` as described in `workspace-configuration.md`.
3. Resolve the component through the exact composition element and its definition. For a CLI component, correlate `sys_uib_toolbox_component.macroponent`, the component macroponent, and its root `sys_ux_lib_component.tag`.
4. Read the source `sys_ux_event` by scoped API/event name and verify label plus payload properties.
5. Parse, do not regex-edit, the page composition. Locate the exact component element and its `eventMappings` entry for the source API name.
6. Read the active screen's `event_mappings` and the page definition's `dispatched_events`.
7. Resolve the destination route in the same app configuration. For record navigation it must declare `route_type=record` and required fields `table,sysId`.
8. Resolve the inherited shell target event live, normally API name `sn_canvas_core.NAV_ITEM_SELECTED`, and verify its route/fields payload contract.
9. Compare one builder-generated working mapping on the same release before constructing JSON. Null `sourceEventSysId` and `sourceEventDefinition.id` can be normal when `sourceEventApiName` is authoritative.

Stop after discovery for a diagnosis request. Do not turn a read-only inspection into a metadata write.

## Idempotent Creation or Repair

Only proceed after the user authorizes the controlled non-production change and the intended scope/update set is current.

### 1. Source event and component contract

- Reuse the scoped source `sys_ux_event` when its event name, label, and payload schema match.
- Otherwise create one customer-owned event with a descriptive label and the exact manifest/framework event name.
- Ensure the component macroponent's `dispatched_events` glide list contains it exactly once.
- Verify the component actually dispatches the same event name and payload keys. Creating metadata cannot make absent client code emit an event.

### 2. Page-owned relay

- Resolve a relay by the page definition and target handler, not by a label copied from another page.
- Prefer the builder-generated naming shape `NAV_ITEM_SELECTED_RELAY_<page-definition-identity>` and a human label such as `Open page or URL Relay (<page name>)`.
- Reuse an existing page-owned relay only when its scope, API name, label, and payload schema match the current target handler.
- Otherwise create a customer-owned relay in the page scope, using the live inherited handler's payload schema as the model.
- Add the relay to the page definition's `dispatched_events` exactly once.

Never borrow a relay labeled for Home/default/another page merely because its properties look compatible. Relays are page/variant routing edges, not general utilities.

### 3. Component instance to relay

In the exact component element inside `sys_ux_macroponent.composition`:

- reuse or add one source mapping keyed by the source event API name;
- add one `EVENT` target whose event API name resolves to the page-owned relay;
- bind `route` to the literal `record`;
- bind `fields.table` to event payload `table`;
- bind `fields.sysId` to event payload `sysId`;
- leave optional navigation values null unless the requirement explicitly needs them;
- preserve existing unrelated targets and ordering.

Do not append a duplicate target when the same relay API name and payload mapping already exist.

When the page already has a valid generic `NAV_ITEM_SELECTED` relay and active-screen pass-through, record and list source events can reuse that same page-owned relay. Clone the schema of the working component-to-relay mapping, change only the source contract and route payload, and leave the page relay plus screen mapping untouched. For a `simplelist` target, bind `fields.table`, `params.query`, and `params.listTitle`; use an exact encoded query such as `sys_idIN...` when the component has already computed the authoritative scoped record set. Do not dispatch for an empty set, because an empty or missing query can expose an unfiltered table.

### 4. Relay to Workspace shell

In the active variant's `sys_ux_screen.event_mappings`:

- add one source mapping for the page relay API name;
- target the live inherited `sn_canvas_core.NAV_ITEM_SELECTED` event (or the release-matched equivalent resolved from a known-good screen);
- pass through `route`, `fields`, `params`, `redirect`, `passiveNavigation`, `title`, `multiInstField`, `targetRoute`, `external`, and `navigationOptions` when those properties exist on the live target schema;
- omit properties not present on the target release instead of inventing them.

An exposed relay under page **Dispatched events** is not sufficient. If `sys_ux_screen.event_mappings` is `[]`, or the builder shows only **Add handler** under the relay, the event stops there.

## Serialized JSON Safeguards

Direct JSON writes are fragile. For each target record:

1. Capture sys_id, scope, update timestamp, exact before-value, top-level type, and relevant component/mapping/target counts.
2. Parse the JSON and select the exact element by stable identity. Fail closed on zero or multiple matches.
3. Modify only the intended mapping/target.
4. Preserve all arrays. PowerShell can unwrap one-element arrays; explicitly retain the top-level `[...]` and nested `eventMappings`/`targets` arrays.
5. Serialize, assert the expected top-level type, and parse the candidate again before writing.
6. In PowerShell, parse serialized UX arrays with `ConvertFrom-Json -InputObject $raw -NoEnumerate`; do not pipe a one-element array through `ConvertFrom-Json`, because pipeline enumeration can collapse it into an object. Before writing, assert the trimmed candidate starts with `[` and that the reparsed value is an array.
7. Write one record at a time, reread without cache, parse again, and compare semantic invariants such as top-level type, element identities, mapping counts, API names, bindings, and stable references. ServiceNow can normalize whitespace or property ordering, so raw string equality is not a valid post-write test by itself.
8. Confirm natural update-set capture after each coherent slice. Do not hand-move `sys_update_xml` rows.
9. Clear UI Builder cache through the supported Developer action, reopen the builder, and test the actual Workspace route.

Never overwrite the entire composition from a reconstructed template, copy JSON from another instance, or use a transient sys_id as a portable constant. If a supported builder save can generate the remaining relationship safely, prefer it.

## Failure Signatures

| Symptom | Metadata evidence | Repair boundary |
| --- | --- | --- |
| `sys_ux_event` ID `undefined` / **This handler is not valid** | Component target has `type: "EVENT"` but `event: null` | Remove only the null target; preserve the valid source mapping/relay |
| Missing concrete event ID | Target has an obsolete/unresolvable `event.sysId` | Resolve by API name/scope; recreate through builder or narrowly replace only the stale target reference |
| Blank source-event group | Source event exists but its `label` is empty | Add a descriptive label, refresh metadata/cache, then recreate/validate mapping |
| Component handler visible but click is silent | Component-to-relay exists; active screen `event_mappings` is empty or lacks that relay | Add the relay-to-shell screen mapping |
| Relay label references another page | Component target points to a relay owned by a different page/variant | Create/reuse a page-specific relay and mapping; retire the borrowed target after verification |
| `No current page in dataContext` | Navigation handler executed without the expected selected page/shell context, or mapping targets the wrong layer | Verify actual Workspace route, selected variant, and relay-to-shell target before changing component code |
| Builder works but target transport fails | Relay/target API names resolve locally but referenced events, screen mapping, scope, or update capture are absent downstream | Inventory dependencies and validate target records after promotion |

Do not infer that null source IDs are broken when the source API name matches known-good mappings on the same release. Conversely, do not accept an `event: null` target merely because the UI saved successfully.

## Validation and Definition of Done

- Source event row exists in the intended scope with a label and exact payload schema.
- Component macroponent exposes it once and the deployed client dispatch matches it.
- Page composition remains a top-level array and parses successfully.
- The exact component source mapping has one intended page-relay target; every `EVENT` target has a non-null event object and resolvable API name.
- Page `dispatched_events` contains the page relay exactly once.
- Active screen `event_mappings` contains the relay-to-shell mapping exactly once.
- Destination route exists in the same app configuration and accepts the bound fields.
- UI Builder has no missing-event/invalid-handler errors after cache refresh.
- A real click opens the intended record in the actual Workspace session/tab behavior, with no duplicate navigation and no unexpected console/network errors.
- A malformed or missing record identity does not navigate.
- Intended non-admin succeeds; an unauthorized user cannot read the destination record.
- Expected application/update-set records are captured and unrelated metadata is absent.

## Rollback

Rollback is the inverse, using the captured before-values:

1. Remove only the new component target/source mapping when no other target uses it.
2. Remove only the active screen relay mapping created for the change.
3. Remove the relay from page `dispatched_events` only when no remaining mapping references it.
4. Delete/deactivate a newly created customer-owned relay or source event only with explicit authorization and only after proving no other consumer exists; prefer a recoverable metadata revert.
5. Restore exact before-values for JSON fields, reread/parse, clear UI Builder cache, and retest the page.

Update-set backout does not reverse records or side effects created by navigation or downstream actions.

## Official Sources

- Manage actions in UI Builder: https://www.servicenow.com/docs/r/application-development/ui-builder/work-events.html
- Bind an event to a component: https://www.servicenow.com/docs/r/application-development/ui-builder/bind-event-component.html
- Bind an event to a page: https://www.servicenow.com/docs/r/application-development/ui-builder/bind-event-page.html
- Link a component event to a destination: https://www.servicenow.com/docs/r/application-development/ui-builder/link-component-destination.html
- Configure an event handler manually: https://www.servicenow.com/docs/r/application-development/ui-builder/event-handler.html

Reopen the release-matched documentation during implementation. The table names above are durable diagnostic anchors on the verified Australia baseline, but JSON shapes and inherited handlers can change with UI Builder and Workspace Store versions.
