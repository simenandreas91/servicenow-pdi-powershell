# Configurable Workspace Configuration Playbook

Use this reference for Configurable Workspace and UI Builder page analysis, record-page composition, routes and variants, forms, lists, tabs, data resources, events, security, and safe extension. For action-bar, form, list, related-list, field, attachment, or modal actions, also load `workspace-actions.md`. For symptom-led investigation, deployment checks, and worked recipes, also load `workspace-debugging.md`.

This reference was verified against ServiceNow's Australia documentation on 2026-08-27. Treat family behavior and Store application versions as release-sensitive. Confirm the target family/build, UI Builder Store version, workspace Store application/version, and live schema before changing metadata.

## The Rule That Prevents Most Wrong Turns

A Workspace screen is the result of several independent configuration stacks. Do not assume that a visible element is controlled by the UI Builder page merely because it renders inside that page.

```text
experience URL and shell
  -> route and URL parameters
    -> matching page variant
      -> page definition and component tree
        -> component properties and data/event bindings
          -> form/list/action/product metadata
            -> table data, security, and runtime rules
```

Trace the chain from left to right. Make the change at the narrowest supported owner. A missing field is usually form metadata or a rule; a missing action is usually the action model/layout/condition chain; a missing custom component is usually page composition; a whole different layout is often routing or variant selection.

## Architecture and Ownership Map

| Layer | Meaning | Usually controls | Primary inspection surface / common metadata |
| --- | --- | --- | --- |
| Configurable Workspace | A Next Experience workspace shell plus one or more routed pages | Multi-tab work area, navigation, search, utilities, theme, landing path | UI Builder experience; workspace/product admin center; `sys_ux_page_registry`, `sys_ux_app_config`, `sys_ux_page_property` |
| Experience / UX Application | Collection of pages under a URL path and application scope, normally with an app shell | Base `/now/<path>/...` URL, title, scope, roles, shell, theme, navigation settings | UI Builder Experience view; UX Application [`sys_ux_page_registry`] |
| UX App Configuration | Runtime configuration associated with the experience | Active state, landing path, experience settings, page-property ownership | `sys_ux_app_config`; resolve from the experience rather than by memorized sys_id |
| App shell | Wrapper shared by pages | Header, session tabs, navigation, utilities, global search, shared data/handlers | Experience settings and UX page properties; product-specific shell configuration |
| Page | A named URL path/type and its parameter contract | Logical landing, list, record, dashboard, knowledge, or custom destination | UI Builder Experience view; route and screen collection records |
| Route | Maps a path and required/optional parameters into a screen collection | Which page family is entered and which values become `@context.props.*` | UX App Route [`sys_ux_app_route`] |
| Screen collection | Holds the variants available for one routed page | Variant membership and route-to-screen grouping | UX Screen Collection [`sys_ux_screen_type`] |
| Screen / page variant | One candidate implementation at the same route | Audience, conditions, order, active state, page definition | UX Screen [`sys_ux_screen`], UX Screen Condition [`sys_ux_screen_condition`], audience/applicability records; UI Builder variant settings |
| Page definition | The rendered composition for a variant | Layout, component instances, bindings, client scripts, handled/dispatched events | UX Macroponent Definition [`sys_ux_macroponent`]; UI Builder content tree and Developer > Open page definition |
| Containers and layouts | Responsive structure inside a page definition | Placement, columns, sizing, visibility, reflow | UI Builder content tree/stage/styles; composition in the page definition |
| Component | Reusable UI element placed in the composition | Form, record header, action bar, list, tabs, activity, visualization, modal trigger, custom UI | UI Builder Configure/Styles/Events; component definition commonly `sys_ux_macroponent`, pro-code toolbox component `sys_uib_toolbox_component` |
| Controller | Component/data/event contract, often added by a template | Form or list context, action layout, coordinated component behavior | UI Builder Data and scripts; controller definition commonly `sys_ux_controller` |
| Viewport | A component slot that loads another page/page collection dynamically | Modals, subpages, contextual content, nested routed content | Viewport component properties/events, parent macroponent and composition element ID, route/page collection |
| Page properties | Typed experience/shell values, often references or JSON | Default view, list/action/search/ribbon configs, chrome/navigation behavior | UX Page Property [`sys_ux_page_property`]; use supported Experience settings/product configuration first |
| Data resource | Server/client data operation exposed to the page | Record lookup, queries, GraphQL, REST, transforms, composite/controller data | UI Builder Data and scripts; local and inherited resources |
| Client state parameter | Page-local reactive variable | Selection, filter, UI mode, temporary values shared by bindings | UI Builder Client state panel; `@state.<name>` |
| Event and handler | Interaction edge between a producer and an operation | Navigation, state updates, modal open/close, data execution/refresh, alerts | Component/Data resource/Page Events; UX events/client scripts; UI interactions |
| Page collection | Reusable group of pages loaded in tabs, modals, or extension points | Reusable nested experiences | UI Builder page collections; UX Extension Point [`sys_ux_extension_point`] and related metadata |
| Traditional form/list metadata | Platform view definitions rendered by form/list components | Fields, sections, annotations, formatters, related lists, columns and their order | Form Builder; `sys_ui_view`, `sys_ui_form`, `sys_ui_section`, `sys_ui_element`, `sys_ui_related_list`, `sys_ui_list`, `sys_ui_list_element` |
| Workspace view rules | Runtime view selection for Workspace | Form view, tab/section behavior, table/role/condition-specific variation | Workspace View Rule [`sysrule_view_workspace`], UX View Rules Configuration [`sys_ux_view_rules_configuration`] |
| Declarative/action metadata | Actions returned to form/list/action components | Button availability, placement, grouping, order, implementation | See `workspace-actions.md` |
| Product configuration | Workspace feature records owned by HR, CSM/FSM, SOW, Security, etc. | Specialized tabs, playbooks, record information, list presets, admin-center behavior | Product admin center/guided setup and product-specific tables/properties |
| Security/runtime rules | Data and operation authority | Whether the user can reach a route, read/write fields, see/execute actions, query data | UX route ACLs, table/field ACLs, roles, application access, user criteria, before-query rules, data policies, Business Rules |

### Terms that are easy to conflate

- **Experience versus page:** the experience owns the shell and URL namespace; a page is one destination inside it.
- **Page versus variant:** a page owns a path and parameter contract; variants are competing implementations at that same path.
- **Route versus screen:** the route parses navigation into parameters and points at a screen collection; a screen is a selectable variant that references a page definition.
- **Screen versus page definition:** the screen owns selection metadata; the macroponent/page definition owns the component composition.
- **Container versus viewport:** a container lays out components already in the page; a viewport dynamically loads another page or collection.
- **Form tab, record-page tab, session tab, and sidebar tab:** these are different layers. Identify which tab family is missing before changing anything.
- **UI Action versus “UI action” in UI Builder language:** `sys_ui_action` is traditional platform metadata. UI Builder event handlers are page interactions. Declarative Actions are another workspace action model. Inspect the implementation, not the visible label.

## First-Pass Investigation: Ten Facts Before Editing

Collect these in a read-only pass. Do not start by duplicating the page or opening every UI Builder tree node.

1. **Runtime identity:** instance URL/build, current user/persona, roles/groups, domain, application scope, workspace Store app and version.
2. **Exact reproduction:** full runtime URL, selected session tab, table/class, record sys_id, record state, expected versus actual result, screenshot if visual.
3. **Experience:** derive the path after `/now/`; resolve the exact active UX Application and app configuration. Do not select by title alone.
4. **Route:** match the remaining URL path to the active UX App Route and record required and optional parameters.
5. **Runtime inputs:** record the decoded values for `table`, `sysId`, `query`, `view/views`, `selectedTabIndex`, or product-specific parameters. Names are case-sensitive in bindings.
6. **Variant candidates:** list active screens for the route/screen collection with order, audience, conditions, scope, and page definition.
7. **Selected variant:** evaluate route parameters against variant conditions, then user against audience/user criteria; use order only to break otherwise equal matches. Confirm with the real URL, not only UI Builder Preview.
8. **Composition owner:** open the selected variant and page definition. Identify the component instance/ID, its controller, properties, visibility, bindings, and event mappings.
9. **Downstream owner:** follow bound references and IDs into form view, list configuration, action configuration/layout, data resource, page property, or product record.
10. **Security and delivery:** evaluate route/table/field/action access as the target persona; identify artifact ownership, application scope, intended update set/app repository path, and rollback before any change.

### Efficient metadata traversal

Use UI Builder's Experience view first to see routes, variants, audience counts, conditions, and order. Use its Developer menu to open the exact variant collection, variant record, or page definition. This is safer than guessing records by name.

For API/Xplore inspection, query narrowly and traverse references:

```text
sys_ux_page_registry (path=<experience path>)
  -> sys_ux_app_config
  -> sys_ux_page_property
  -> sys_ux_app_route (path/route)
    -> sys_ux_screen_type
      -> sys_ux_screen (active/order/conditions/audience/page definition)
        -> sys_ux_macroponent
```

Table and field names can change with Store versions. Before automating, inspect the live table shape with `Get-ServiceNowTableShape.ps1`, then use `Invoke-ServiceNowTable.ps1` with selective fields and a small limit. Treat internal JSON as diagnostic evidence, not the first editing interface.

Useful read-only queries include:

- experience by exact `path`, then exact `sys_id`;
- routes by resolved application/configuration and exact path;
- screens by resolved screen collection, returning active/order/name/condition/page definition;
- page properties by resolved page registry, returning name/type/suffix/value/route;
- macroponent by resolved screen's page-definition reference;
- list/action/view configuration by the reference bound in the selected component/controller/page property.

Never search for a familiar page label across the whole instance and edit the first match. Product workspaces often contain copied templates, inactive migrations, multiple Store versions, and same-named variants in different scopes.

## Routing and Variant Selection

### Route parameters

- Required parameters are ordered path segments and define the contract a page needs, commonly `table` and `sysId` for record pages.
- Optional parameters are name/value pairs and may carry query, view, tab, or product state.
- UI Builder exposes route values through page context, for example `@context.props.table`.
- Conditions can evaluate only declared parameters, except subpages can inherit additional controller outputs from their parent context.
- A hard-coded UI Builder test value proves the composition can render; it does not prove the runtime route supplies the same value.

### Variant decision procedure

1. Confirm the route and its declared parameters.
2. Enumerate every active variant for that route.
3. Evaluate each variant's condition using the runtime parameter values. Conditions commonly distinguish table/class, record, or other route values.
4. Evaluate its audience. Audiences can use allow/deny criteria for roles, groups, users, company, department, location, domain, or script. If `glide.ux.user_criteria_enabled` is required by the target setup, verify it rather than assuming audience evaluation is active.
5. If multiple variants still qualify, compare order: lower number has higher priority.
6. Verify the selected variant by using **Open URL path** or the actual Workspace session as the affected user. Previewing a chosen variant bypasses the key question of which variant runtime would choose.

### Unexpected variant checklist

- wrong experience or route with a similar title;
- table parameter contains an extension table rather than the expected base table;
- condition uses `table=task` but the runtime value is `incident`, or vice versa;
- optional parameter is absent, misspelled, or a different type;
- audience criteria, audience order, active state, or domain differs for the user;
- two variants match and lower order wins;
- a parent/subpage controller contributes an extra condition input;
- stale session/app-shell cache after a property or Store-app update;
- promoted screen condition or audience M2M is missing on the target;
- test values make the UI Builder editor appear correct while the real route is wrong.

Prefer a narrowly conditioned variant over copying an entire experience. Prefer an extension point, supported page template, declarative action, or product configuration when it can extend a ServiceNow-owned page without taking ownership.

## Record Pages: Composition Versus Form Metadata

A standard record page is a composition of separate concerns. Common pieces include a Form Controller, Form component, Record Header, action bar, Activity Stream/Compose, record-page tabs or related lists, contextual sidebar tabs, viewports for modals, and shared data resources. The older Agent Workspace model bundled several of these concerns together; Configurable Workspace exposes them as separate components.

### Determine the form view

Resolve view selection in this order:

1. explicit Form Controller/Form component property on the selected page variant;
2. route or optional `view`/`views` parameter passed by navigation;
3. Workspace View Rule matching exact runtime table, record condition, role, and order;
4. experience/page property such as a generated workspace `view` value;
5. product-specific page configuration or controller preset;
6. workspace-specific conventional view such as `Workspace UIB`, `Service Operations Workspace`, or a generated `workspace-<path>-<n>` view;
7. inherited/base or Default view fallback.

Do not assume every Configurable Workspace uses a view literally named `Workspace`. HR Agent Workspace commonly uses `Workspace UIB`; stock SOW has product-specific views; App Engine generated workspaces create a technical workspace view. Resolve it from live bindings and rules.

### Which layer controls form behavior

| Visible behavior | First owner to inspect | Then inspect |
| --- | --- | --- |
| Field present/order | selected form view: `sys_ui_section` / `sys_ui_element` | variant/component visibility; personalization; child-table inheritance |
| Section present/order | selected form view and sections | Record Page Tabs/custom UI Builder tab if it is not a form section |
| Annotation | form view element/annotation metadata | component support and release notes |
| Formatter | selected view/form metadata | Workspace compatibility; many Jelly-era formatters are not Next Experience components |
| Related list present/order | related-list configuration for the selected view | record-page tabs/list component, Workspace View Rule tab settings, ACLs/relationship |
| Mandatory/read-only/visible | dictionary, UI Policy, Client Script, data policy, ACL | view scope/UI Type, Workspace-supported client API, server rule |
| Reference choices | reference qualifier/dictionary, ACLs, before-query rules | client script, product configuration, dependent fields |
| Header label/highlights | form header/highlighted-value/product configuration | Record Header component binding and record data |
| Activity fields | Activity Stream configuration/product properties | journal ACLs, field presence, client state/component property |
| Record page layout | selected page variant and component tree | product extension points/templates |

### Traditional logic still matters

- UI Policies should handle declarative presentation. Confirm the policy's table, inherited flag, view restriction, condition, reverse-if-false behavior, and Workspace-supported actions.
- Client Scripts must target a UI type that includes Configurable Workspace and use supported APIs. In current documentation, **Mobile / Service Portal** includes configurable workspace; `All` also applies. A Desktop-only script can explain Core UI versus Workspace differences.
- Data Policies, Business Rules, dictionary constraints, ACLs, and application access provide server-side enforcement. A client-only mandatory or hidden field is not security or integrity.
- Avoid DOM manipulation and legacy Jelly/UI Macro assumptions. The Workspace form is a Next Experience component, not the Core UI DOM.
- Test base and extension tables separately. View rules, sections, policies, layouts, and action layouts can be more specific on a child table.

### When a backend form change affects Workspace

It affects Workspace when the change is made to the exact view rendered by the Workspace component and the artifact is supported in that component. A change to Default/Core UI does not affect a workspace using `Workspace UIB`, `sow`, or a generated view. A view-aware rule may select a different layout for another user, class, or record. Personalization can also make one user's view differ.

## The Four Kinds of Tabs

Before editing, classify the visible tab:

| Tab family | Examples | Common owner |
| --- | --- | --- |
| Shell/session tabs | open record sessions across the top | app shell/session-tab configuration, navigation events, page properties |
| Record page/sub-tabs | Details, Activity, Related Records, playbook/custom tab | UI Builder Tabs/Record Page Tabs component, page collections/extension points, component visibility; sometimes form/related-list metadata supplies entries |
| Form section tabs | sections of the selected form view | `sys_ui_section` / `sys_ui_element`, Workspace View Rule tab/section settings |
| Contextual sidebar tabs | Agent Assist, Attachments, Form Templates, Record Information | UI Builder Tabs sidebar and components, product page configuration/page properties |

### Add, hide, reorder, or condition a tab

1. Identify the tab family and selected page variant.
2. Inspect the Tabs component/preset/controller and determine whether entries are authored components, imported form sections/related lists, page-collection slots, or product-configured tabs.
3. For an authored tab, prefer an existing OOTB component or extension point. Bind context (`table`, `sysId`, controller data), configure visibility with supported conditions, and wire events.
4. For a form section or related-list tab, change the selected view or Workspace View Rule rather than duplicating the UI Builder record page.
5. For a product tab, use the product's admin center/Page Configurations/guided setup. A generic UI Builder copy may suppress Store upgrades.
6. Test empty, populated, unauthorized, base-table, child-table, and narrow/reflow states.

Do not hide a tab to secure its data. The nested component/data resource and underlying records still need ACL enforcement.

## Lists and Related Lists

### Workspace list page stack

A standard list page commonly contains a List Menu component and Record List bundle (Record List Header plus Presentational List), with Predicate Builder/filtering and a list controller. UI Builder owns the composition and bindings; record-driven list metadata owns many actual menu entries.

Common metadata:

```text
sys_ux_list_menu_config
  -> sys_ux_list_category
    -> sys_ux_list
      -> applicability/audience association (often sys_ux_applicability_m2m_list)
```

`sys_ux_list` commonly supplies table, encoded condition, columns, order, grouping, and active flags. Applicability determines which users receive a list. Product workspaces may add their own list presets/controllers or admin-center configuration.

Classic `sys_ui_list`/`sys_ui_list_element` still controls view-based list layouts in several Workspace surfaces, especially generated or product-specific views. Inspect the component/controller binding to determine whether columns come from `sys_ux_list.columns`, a passed view, a user-saved list, a data resource, or classic list metadata.

### Related lists

Related lists originate from a relationship/reference and the selected form view, but their Workspace rendering may be a Record List/Related Lists/Record Page Tabs component. Trace both:

1. selected form view and `sys_ui_related_list` configuration;
2. relationship/reference and parent/child table correctness;
3. Workspace View Rule and tab order/visibility;
4. selected page variant's related-list/tab component and controller inputs;
5. table/read ACLs, before-query rules, domains, and row count;
6. related-list declarative actions/action configuration;
7. product-specific grouping or Related Items/Dynamic Related Records configuration.

Do not confuse a true related list with a product-specific “Related Records” component whose data is supplied by definitions, a playbook, or a scripted/GraphQL resource.

### Workspace list differences from Core UI

- Next Experience list components have their own controller, event, row-action, pagination, and refresh contracts.
- Workspace navigation lists are centrally configured in UX list-menu records and audiences; a Core UI module or favorite does not create one.
- Columns may be driven by UX list metadata, a workspace view, component properties, or a saved personal list.
- List and row buttons usually use declarative list/related-list actions, not only classic list UI Actions.
- “My Lists” are user-owned and should not be used as organization-wide configuration.
- Filters, sorting, grouping, pagination/page size, and row selection can live in encoded metadata, route parameters, client state, controller state, component properties, user preferences, or data resource inputs. Identify the source before editing.

## Components, Bindings, and Data Flow

### Inspect a component

For the exact component instance in the selected variant, record:

- label and stable element/component ID in the content tree;
- component definition, preset, bundle, and controller;
- static properties versus dynamic bindings;
- visibility condition and responsive/reflow behavior;
- events it emits and all mapped handlers;
- local versus inherited data resources;
- client state and route/page values it consumes;
- handled/dispatched events exposed to parent or child pages;
- scope/read-only/Store ownership.

Common binding roots:

- `@context.props.<name>`: route/page property such as table or sysId;
- `@data.<resource>...`: data resource output;
- `@state.<name>`: client state parameter;
- `@elements.<component>...`: another component's exposed state/output;
- event payload/context: value emitted by the triggering component/resource.

Copy the exact binding expression before changing it. A component can look empty because a binding path changed, a resource did not run, its result shape differs, or a route value is missing—not because the component itself is defective.

### Common components and likely owners

| Component/surface | Purpose | Inputs and secondary configuration |
| --- | --- | --- |
| Form bundle | Render and edit one record | Form Controller, `table`/`sysId`, selected view, form metadata, policies/scripts/ACLs |
| Record Header | Identity, highlights, primary context | record/controller data, header/highlighted-value/product configuration |
| Action bar | Form actions | Form Controller action layout, action configuration, UI/Declarative Action chain; see `workspace-actions.md` |
| Record List bundle | Render list or related list | list controller/data resource, table/query/view/columns, action configuration, ACLs |
| List Menu | Navigation among governed lists | `sys_ux_list_menu_config` graph and audience/applicability |
| Tabs / Record Page Tabs | Switch among nested content | tab definitions, page collections, form sections/related lists, visibility and selected-index state |
| Activity Stream/Compose | Record journal/history and communication | table/sysId, journal fields, activity configuration, email/product properties, ACLs |
| Contextual sidebar | Auxiliary tools | Tabs component plus product/page properties and feature components |
| Data visualization | Metrics/charts | visualization/report/Platform Analytics source, filter, drilldown/navigation events |
| Modal/viewport | Temporary nested page/dialog | route/page collection, parent viewport element, input payload, open/close/save events |
| Custom component | Unsupported bespoke interaction | property/event contract, data resources/controllers, ACL-backed server access; also load `ui-builder-custom-components.md` |

### Data resources

Current UI Builder documentation describes Controller, GraphQL, Transform, Client state, Composite, and REST data resource types; common Global resources also include record lookup and GlideRecord Query operations. Legacy, product, or customer applications can contain scripted data resources/controllers. Inspect their inputs, user context, server implementation, caching, and output contract; prefer a current built-in resource or narrow server API when it can replace opaque script. Use the least custom, bounded resource that supplies the required contract.

- **Local resources** are configured on the current page variant.
- **Inherited resources** come from surrounding app shell, parent page, template, or controller and are read-only in that page.
- **Eager/immediate** resources run on load; explicit resources require an event/operation. Do not assume a resource runs merely because it exists.
- Bind only the fields the page needs and keep table queries selective. Avoid repeated resource calls for data already in the Form Controller.
- A Transform reshapes data; it does not grant access. GraphQL/REST/scripted sources must still enforce server security.
- Composite/controller resources help reuse a coherent contract; do not hide many expensive operations behind a convenient component preset.

### Typical runtime flow

```text
open `/now/<experience>/<route>/<table>/<sysId>`
  -> route parses declared parameters
  -> audience + conditions + order select screen variant
  -> page definition loads component/controller graph
  -> data resources evaluate with context/state inputs
  -> component properties render from bindings
  -> user emits component/declarative-action event
  -> handler navigates, updates state, executes/refreshes resource,
     triggers UI interaction, or opens/closes viewport
  -> affected resource/controller/form refreshes
  -> bound components rerender
```

### Missing or stale data checklist

- route input missing, wrong case/name, invalid sys_id, or wrong table/class;
- data resource disabled, explicit but never executed, or condition false;
- binding path points to `result` versus `output`, display versus value, or an old schema;
- resource query/GraphQL/REST input is malformed or overbroad;
- ACL, application access, domain, before-query rule, or cross-scope restriction filters the result;
- event performs the write but no controller/data-resource refresh is mapped;
- refresh targets a different instance of the resource;
- optimistic/client state diverges from server response;
- cached shell/property/session or Store version mismatch;
- promoted resource, transform, client script, or referenced component is missing.

## Events and Interactions

Events do nothing until mapped to one or more handlers. Trace a click from the emitting component or declarative action, not from the destination you expect.

When a customer-owned UI Builder component/page event must be created, repaired, or validated through backend metadata rather than the builder UI, also load `ui-builder-event-automation.md`. It distinguishes event definitions (`sys_ux_event`) from component/page composition mappings (`sys_ux_macroponent`) and active variant relay mappings (`sys_ux_screen`).

1. Select the exact component/data resource/page variant and open its Events panel.
2. Identify the emitted event and payload contract.
3. Enumerate every handler in order: navigation, state update, data operation, client script, inherited handler, modal/viewport, UI interaction, or handled/dispatched event.
4. Resolve every dynamic payload binding and confirm its value using real test inputs.
5. If a UXF Declarative Action is involved, inspect the UX Add-on Event Mapping on the selected page/controller. On current Australia-capable instances, prefer a reusable UI Interaction when it can extend the page without per-page mapping.
6. Inspect Operation Initiated/Succeeded/Failed mappings for data resources.
7. Confirm the final observable state and explicit refresh. A successful server write with a stale form/list is an incomplete interaction.

Use UI Builder client scripts only for page orchestration that cannot be expressed with built-in handlers or UI Interactions. Keep business authorization and data integrity on the server.

## Configuration Outside UI Builder

Use this quick reverse map before taking ownership of a base page:

| Visible Workspace feature | Likely configuration location |
| --- | --- |
| Workspace title/path/landing page | Experience settings; `sys_ux_page_registry`, `sys_ux_app_config` |
| Header/sidebar/search/utilities/theme | Experience settings, UX page properties, theme/search config, product shell config |
| Navigation list/category | `sys_ux_list_menu_config`, `sys_ux_list_category`, `sys_ux_list`, audience/applicability |
| Record fields/sections | selected workspace form view; Form Builder and `sys_ui_*` form metadata |
| Related list definition/order | selected form view, `sys_ui_related_list`, Workspace View Rule; then related-list component |
| Form/list/related-list button | UI Action flags or Declarative Action, action configuration/layout/model; see `workspace-actions.md` |
| Field mandatory/read-only/hidden | dictionary, UI Policy, Client Script, Data Policy, ACL, Business Rule |
| Reference choices | reference qualifier, ACL, before-query rule, dependent fields |
| Header highlights | UX Highlighted Value Configuration [`sys_ux_highlighted_value_config`] or product config |
| Form header | form-header/product configuration and Record Header inputs |
| Activity entries/compose fields | activity configuration, journal fields, email/product properties and ACLs |
| List columns/filter | `sys_ux_list`, component/controller properties, selected `sys_ui_list` view, personal list |
| Page variant by user | audience/user criteria plus screen conditions/order |
| Page variant by table/record | route parameters plus screen conditions/order |
| Playbook/process tab | Playbook Experience/process/product configuration, page extension point/component |
| Contextual sidebar tab | UI Builder Tabs sidebar plus page properties/product Page Configurations |
| Search result/source | global search config, search context/source/facets or AI Search profile/product config |
| Catalog item / record producer in Workspace | catalog/producer record, variable sets, catalog UI policies/client scripts, user criteria, submission Flow/producer script, and the Workspace catalog/launcher component or product configuration |
| Route inaccessible | experience active/roles, UX route ACL, route metadata, application access |
| Data absent for non-admin | record/field ACL, domain, before-query rule, data-resource server security |

## Security and Persona Validation

An admin render is discovery evidence only. Validate with the target persona in a clean session.

1. Confirm workspace entry roles and any route `read` ACL matching the experience namespace.
2. Confirm audience/user criteria, including allow/deny rules, order, domain, and scripted criteria.
3. Confirm table and field read/write/create/delete ACLs and application access.
4. Confirm the data resource uses the expected user context and does not bypass security unintentionally.
5. Confirm action roles, access flags, server/script conditions, record conditions, and server-side authorization.
6. Compare a permitted and denied record/field/action. Use Security Rule Debugging only in a controlled session and disable it after the test.
7. Verify no sensitive value is present in network responses, client state, component properties, or hidden tabs for the denied user.

Roles, user criteria, variant conditions, component visibility, and button hiding are selection/presentation controls. Only server-side access and guarded server operations are authority controls.

## Current Versus Legacy Workspace Models

- **Configurable Workspace** is the current platform workspace app-shell model and uses the modern UI Builder/Next Experience component stack.
- **Product-specific configurable workspaces** such as Service Operations Workspace, Agent Workspace for HR Case Management, and CSM/FSM Configurable Workspace use the common stack but add Store-app templates, controllers, extension points, page properties, views, actions, and admin-center configuration.
- **Agent Workspace / legacy product Agent Workspaces** use the earlier workspace framework and legacy UI Builder limitations. Do not assume a modern page variant, controller, or declarative action recipe applies.
- Product deprecation is specific. For example, official CSM documentation marks CSM Agent Workspace deprecated and directs new activation to CSM Configurable Workspace. Verify the exact product's current migration/deprecation guidance rather than declaring every older-named workspace unsupported.
- A product label can still contain “Agent Workspace” while the implementation is configurable; HR is a prominent example. Inspect the page registry, route, Store plugin/scope, and ability to open the experience in modern UI Builder.
- Do not lift-and-shift legacy pages or scripts. Re-evaluate each customization against current templates, components, declarative actions/UI Interactions, form metadata, and product extension points.

## Product-Specific Boundary

The generic platform model tells you how to trace the experience. It does not tell you which product configuration is authoritative.

- **SOW:** also load `lessons-sow.md`; prefer SOW Admin Center/product views and additive action/layout configuration before page ownership.
- **HR Agent Workspace:** also load `hr-agent-workspace-configuration.md`; many supported Page Configurations and `Workspace UIB` form changes are intentionally outside UI Builder.
- **CSM/FSM:** check the installed Configurable Workspace Store version, guided setup, case type/record page templates, contextual side panel, playbook, inbox, and product declarative actions.
- **Security/IRM and other industry workspaces:** inspect Record View Configuration, group/related-record definitions, product roles, and admin center. Similar visible labels do not imply generic metadata.
- **Custom App Engine/SDK workspace:** inspect the generated route/screen/page-property/list/applicability graph and scoped app ownership. Also read the App Engine section of `lessons-sow.md` and `servicenow-sdk.md` when source-managed.

Before reusing configuration from another workspace, compare page variant, controller/preset, action configuration, form view, list configuration, product plugin version, and extension points.

## Safe Change Decision Ladder

1. Product admin center, Page Configurations, guided setup, supported experience setting, form/list view, Workspace View Rule, highlighted value, or declarative action.
2. Additive list/category/audience, action layout/assignment, route-safe page variant, page collection, extension point, or OOTB component on a customer-owned page.
3. Customer-owned page/template composition change in the correct scope.
4. Component Builder macroponent when composition cannot meet the need.
5. Pro-code custom component only for a stable property/event contract that native components cannot satisfy; also load `ui-builder-custom-components.md`.
6. Clone or take ownership of a ServiceNow page only with a documented upgrade and reconciliation plan.

Anti-patterns:

- duplicating an entire record page to add one action or related list;
- editing `sys_ux_macroponent` JSON without first locating the supported builder/configuration surface;
- hard-coding target sys_ids in payloads, page properties, routes, or scripts;
- changing Default/Core UI form layout when Workspace renders another view;
- relying on admin testing, UI hiding, or a client condition for authorization;
- creating a custom data resource that duplicates Form/List Controller data;
- polling or refreshing the entire page when one resource/controller can refresh;
- modifying ServiceNow-owned Store records when an extension point, variant, action, or override is supported;
- transporting only the visible top-level page while omitting screens, routes, controllers, actions, audiences, views, or components.

## Definition of Done for a Workspace Change

- exact experience, route, parameters, selected variant, page definition, and component owner recorded;
- downstream form/list/action/product/security metadata resolved;
- narrow supported change made in correct application scope and delivery context;
- changed records re-read and expected customer updates/application files confirmed;
- actual runtime URL tested in a fresh session, not only UI Builder Preview;
- intended persona and denied persona tested;
- base/child table, true/false condition, populated/empty, and stale/refresh cases tested as relevant;
- browser console/network contains no unexplained errors or sensitive leakage;
- adjacent workspace/page regression checked for shared metadata;
- promotion dependencies and target Store/plugin versions validated;
- rollback is a precise property/layout/action/variant revert or removal of the additive customer-owned artifact.

## Official Sources

- [Exploring Configurable Workspace](https://www.servicenow.com/docs/r/platform-user-interface/learn-about-agent-workspace.html)
- [UI Builder overview](https://www.servicenow.com/docs/r/application-development/ui-builder/ui-builder-overview.html)
- [Configure UI Builder experiences](https://www.servicenow.com/docs/r/application-development/ui-builder/work-experiences.html)
- [Manage pages and variants](https://www.servicenow.com/docs/r/application-development/ui-builder/work-pages.html)
- [Control page variant conditions](https://www.servicenow.com/docs/r/application-development/ui-builder/control-conditions-for-your-variant.html)
- [Learn about audiences](https://www.servicenow.com/docs/r/application-development/ui-builder/add-audiences.html)
- [Add and configure components](https://www.servicenow.com/docs/r/application-development/ui-builder/add-components.html)
- [Data resources](https://www.servicenow.com/docs/r/application-development/ui-builder/data-resources.html)
- [Client state parameters](https://www.servicenow.com/docs/r/application-development/ui-builder/client-state-parameters.html)
- [Manage events and handlers](https://www.servicenow.com/docs/r/application-development/ui-builder/work-events.html)
- [UI interactions](https://www.servicenow.com/docs/r/application-development/ui-builder/create-ui-interaction-show-alert.html)
- [Forms in Configurable Workspace](https://www.servicenow.com/docs/r/platform-user-interface/form-configurable-workspace.html)
- [Lists in Configurable Workspace](https://www.servicenow.com/docs/r/platform-user-interface/lists-configurable-workspace.html)
- [Tabs sidebar](https://www.servicenow.com/docs/r/platform-user-interface/contextual-sidebar-configurable-workspace.html)
- [Administering Configurable Workspace](https://www.servicenow.com/docs/r/platform-user-interface/administering-configurable-workspace.html)
- [Workspace API / generated UX metadata](https://www.servicenow.com/docs/r/application-development/servicenow-sdk/fluent-workspace-api.html)
- [Studio UI Builder metadata taxonomy](https://www.servicenow.com/docs/r/application-development/servicenow-studio-classic/servicenow-studio-file-navigator-taxonomy.html)
- [Resolve a missing page definition](https://www.servicenow.com/docs/r/application-development/ui-builder/resolve-missing-page-definition.html)
- [Configurable Workspace release notes](https://www.servicenow.com/docs/r/release-notes/configurable-workspace-rn.html)

Reopen the applicable family and product documentation during implementation. Store applications can evolve between family patches, so a live table shape and builder surface are stronger evidence than a remembered internal field name.
