# Worked UI Builder Component: Priority Case Summary

Use this worked example when a task moves from architecture into CLI component implementation. Read `ui-builder-custom-components.md` first. This example demonstrates the preferred boundary: UI Builder owns data retrieval, page state, navigation, and authorization; the component owns rendering and emits a small user-intent event.

The example is deliberately framework-native and has no external dependency. It is a reusable implementation pattern, not a frozen package template. Generate the project with the installed `snc ui-component` extension and preserve its `package.json`, lockfile, builder configuration, example entry convention, and `now-ui.json` schema. Merge the code and metadata concepts below into those generated files; do not replace a current scaffold with copied historical package versions.

## Requirement and Acceptance Criteria

Build a `Priority Case Summary` component for a Configurable Workspace landing page:

- accept an array of already-authorized case summaries from a UI Builder data resource;
- show a heading, bounded number of cases, number, short description, priority, and assignment group;
- render safe empty and invalid-input states without making its own network request;
- emit `ACME_CASE_SELECTED` with only the selected record ID and number;
- let UI Builder navigate to the record when that event occurs;
- work for the intended agent persona and reveal no data for a persona denied by ACLs;
- remain usable by keyboard, at narrow widths, with long text, and in the active theme.

Do not implement record retrieval, role checks, record navigation, or a second copy of page state inside the component.

## Planned Contract

| Direction | Name | Shape | Purpose |
| --- | --- | --- | --- |
| Property in | `heading` | string | Visible section heading |
| Property in | `items` | array of `{id, number, shortDescription, priority, assignmentGroup}` | Authorized presentation data |
| Property in | `emptyLabel` | string | Empty-state message |
| Property in | `maxItems` | number | Client-side rendering bound, clamped to 1-20 |
| Event out | `ACME_CASE_SELECTED` | `{id, number}` | User intent to open a case |

`id` is a runtime record identifier, not a hard-coded portable dependency. The component never trusts it for a privileged server operation. UI Builder uses it only as navigation context; any later server read/write still enforces ACLs.

## Create the Project

Confirm the non-production profile and current toolchain first:

```powershell
snc version
snc extension list-available -o table
snc ui-component project --help
snc ui-component develop --help
snc ui-component deploy --help
node --version
npm --version
snc configure profile list
```

From an empty source directory, substitute the approved company prefix and scope:

```powershell
snc ui-component project --name @acme/priority-case-summary --description "Reusable priority case summary" --scope x_acme_case_sum
npm install
git init
git add .
git commit -m "Scaffold priority case summary"
```

Do not add `--offline` unless disconnected scope reservation is intentional. If the organization does not want a Git repository initialized here, still preserve the initial generated tree and lockfile in its approved source-control workflow.

## Expected File Tree

The exact generated support files vary by extension release. The authored core should resemble:

```text
priority-case-summary/
|-- example/
|   `-- index.js                 # or the generated example entry filename
|-- src/
|   `-- x-acme-priority-case-summary/
|       |-- index.js
|       `-- styles.scss
|-- now-ui.json
|-- package.json
|-- package-lock.json            # or the scaffolded lockfile
`-- <generated builder/CLI files>
```

Do not rename the generated entry, tag, or scope casually. The custom-element tag must contain a hyphen and must match the source registration, manifest component key, local harness, deployed toolbox record, and every consumer.

## Component Source

Place the following in the scaffolded component entry, adjusting only the generated tag when necessary:

```js
import {createCustomElement} from '@servicenow/ui-core';
import snabbdom from '@servicenow/ui-renderer-snabbdom';
import styles from './styles.scss';

const CASE_SELECTED = 'ACME_CASE_SELECTED';
const DEFAULT_MAX_ITEMS = 5;
const MAX_ITEMS_LIMIT = 20;

const cleanText = (value, fallback = '') =>
    typeof value === 'string' && value.trim() ? value.trim() : fallback;

const clampMaxItems = (value) => {
    const parsed = Number.parseInt(value, 10);
    if (!Number.isFinite(parsed)) return DEFAULT_MAX_ITEMS;
    return Math.min(Math.max(parsed, 1), MAX_ITEMS_LIMIT);
};

const normalizeItems = (value, limit) => {
    if (!Array.isArray(value)) return [];

    return value
        .filter((item) => item && typeof item === 'object')
        .map((item) => ({
            id: cleanText(item.id),
            number: cleanText(item.number, 'Case'),
            shortDescription: cleanText(
                item.shortDescription,
                'No description provided'
            ),
            priority: cleanText(item.priority, 'Not set'),
            assignmentGroup: cleanText(item.assignmentGroup, 'Unassigned')
        }))
        .filter((item) => item.id)
        .slice(0, limit);
};

const view = ({properties}, {dispatch}) => {
    const heading = cleanText(properties.heading, 'Priority cases');
    const emptyLabel = cleanText(properties.emptyLabel, 'No priority cases');
    const items = normalizeItems(
        properties.items,
        clampMaxItems(properties.maxItems)
    );

    return (
        <section className="case-summary" aria-labelledby="case-summary-heading">
            <h2 id="case-summary-heading" className="case-summary__heading">
                {heading}
            </h2>

            {!items.length ? (
                <p className="case-summary__empty" role="status">
                    {emptyLabel}
                </p>
            ) : (
                <ul className="case-summary__list">
                    {items.map((item) => (
                        <li className="case-summary__item" key={item.id}>
                            <button
                                className="case-summary__button"
                                type="button"
                                aria-label={`Open ${item.number}: ${item.shortDescription}`}
                                on-click={() =>
                                    dispatch(CASE_SELECTED, {
                                        id: item.id,
                                        number: item.number
                                    })
                                }
                            >
                                <span className="case-summary__number">
                                    {item.number}
                                </span>
                                <span className="case-summary__description">
                                    {item.shortDescription}
                                </span>
                                <span className="case-summary__meta">
                                    Priority {item.priority} · {item.assignmentGroup}
                                </span>
                            </button>
                        </li>
                    ))}
                </ul>
            )}
        </section>
    );
};

createCustomElement('x-acme-priority-case-summary', {
    renderer: {type: snabbdom},
    view,
    styles,
    properties: {
        heading: {default: 'Priority cases'},
        items: {default: []},
        emptyLabel: {default: 'No priority cases'},
        maxItems: {default: DEFAULT_MAX_ITEMS}
    }
});
```

Why this shape:

- the view is deterministic and has no side effects;
- inputs are normalized before rendering and untrusted strings remain text nodes;
- the list has a hard client-side bound, but the data resource should also query narrowly;
- records are not mutated and only a small event payload leaves the component;
- no lifecycle handler is needed because the component owns no timer, subscription, request, observer, or imperative library root.

If a later requirement introduces one of those resources, initialize it in the release-compatible framework lifecycle/action handler, update it deterministically when relevant properties change, and destroy it in the matching disconnect/teardown handler. Never start side effects from `view`.

## Component Styles

Put the following in `styles.scss`. It intentionally inherits the host experience instead of installing a competing design system. Replace fallback values with approved current Horizon/Now Design System tokens when the target design system exposes the appropriate token.

```scss
:host {
    display: block;
    min-width: 0;
    color: inherit;
    font: inherit;
}

.case-summary {
    display: grid;
    gap: 0.75rem;
}

.case-summary__heading {
    margin: 0;
    font: inherit;
    font-size: 1.125rem;
    font-weight: 650;
    line-height: 1.35;
}

.case-summary__list {
    display: grid;
    gap: 0.5rem;
    margin: 0;
    padding: 0;
    list-style: none;
}

.case-summary__item {
    min-width: 0;
}

.case-summary__button {
    display: grid;
    width: 100%;
    min-width: 0;
    gap: 0.2rem;
    padding: 0.75rem;
    border: 1px solid currentColor;
    border-radius: 0.25rem;
    color: inherit;
    background: transparent;
    font: inherit;
    text-align: left;
    cursor: pointer;
}

.case-summary__button:hover {
    text-decoration: underline;
}

.case-summary__button:focus-visible {
    outline: 0.2rem solid currentColor;
    outline-offset: 0.15rem;
}

.case-summary__number {
    font-weight: 650;
}

.case-summary__description,
.case-summary__meta {
    overflow-wrap: anywhere;
}

.case-summary__meta,
.case-summary__empty {
    opacity: 0.8;
}

.case-summary__empty {
    margin: 0;
}
```

Do not copy global Workspace classes or rely on a parent page's generated selectors. If the current ServiceNow component library provides an appropriate button/card primitive and using it improves consistency, import that release-aligned package and add it to the scaffold's `innerComponents` declaration instead of guessing a package version.

## Local Harness

Keep the generated example entry structure. A minimal `example/index.js` can be:

```js
import '../src/x-acme-priority-case-summary';

const component = document.createElement('x-acme-priority-case-summary');

component.heading = 'Priority cases';
component.maxItems = 3;
component.items = [
    {
        id: 'local-example-1',
        number: 'INC0010001',
        shortDescription: 'Email delivery is delayed for several users',
        priority: '1 - Critical',
        assignmentGroup: 'Messaging'
    },
    {
        id: 'local-example-2',
        number: 'INC0010002',
        shortDescription:
            'A deliberately long description verifies wrapping at narrow widths without horizontal overflow',
        priority: '2 - High',
        assignmentGroup: 'Service desk'
    }
];

document.body.appendChild(component);
```

Use fake local IDs and non-sensitive text only. If the generated harness uses another property-assignment convention, retain that convention and supply the same data. Add explicit harness scenarios for:

- `items = []`;
- `items = null` and malformed entries;
- one, five, and more than 20 inputs;
- duplicate/missing IDs;
- long localized strings and narrow viewport;
- keyboard Tab/Enter/Space activation;
- click dispatch observed once in the framework inspector/logging available to the scaffold.

Run:

```powershell
snc ui-component develop --open
npm run
```

Execute the discovered lint/test/check scripts from `npm run`. A current `develop` server may rebuild or refresh efficiently, but do not assume universal hot module replacement. Refresh after source/style changes when needed and restart the server after dependency, builder configuration, entry, or manifest changes.

## Manifest Merge Guide

Open the generated `now-ui.json`. Keep its exact root structure, generated component key, scope, associated types, supported field types, and any schema/version fields. Merge these concepts into the generated component entry:

```json
{
  "components": {
    "x-acme-priority-case-summary": {
      "actions": [
        {
          "name": "ACME_CASE_SELECTED",
          "payload": [
            {"name": "id"},
            {"name": "number"}
          ]
        }
      ],
      "innerComponents": [],
      "uiBuilder": {
        "associatedTypes": ["global.core", "global.landing-page"],
        "label": "Priority Case Summary",
        "icon": "list-outline",
        "description": "Displays a bounded list of priority cases and emits a selection event.",
        "category": "primitives"
      },
      "properties": [
        {
          "name": "heading",
          "label": "Heading",
          "fieldType": "string",
          "required": false,
          "defaultValue": "Priority cases"
        },
        {
          "name": "items",
          "label": "Cases",
          "fieldType": "json",
          "required": false,
          "defaultValue": []
        },
        {
          "name": "emptyLabel",
          "label": "Empty-state label",
          "fieldType": "string",
          "required": false,
          "defaultValue": "No priority cases"
        },
        {
          "name": "maxItems",
          "label": "Maximum cases",
          "fieldType": "number",
          "required": false,
          "defaultValue": 5
        }
      ]
    }
  },
  "scopeName": "x_acme_case_sum"
}
```

This block documents semantic intent, not a license to overwrite the generated file. `fieldType`, default encoding, JSON schema, action labels, associated types, and payload metadata have varied. If the current scaffold or validator rejects a field, use the current schema/help and preserve the same public contract. Do not fall back to direct `sys_ux_*` edits before proving the supported manifest path cannot deploy it.

Before deployment, verify exact equality across:

- source tag, manifest component key, and harness tag;
- source property names and manifest property names;
- dispatched action name and manifest action name;
- event payload keys and manifest payload keys;
- generated/approved scope and `scopeName`.

## Deploy to DEV

Deployment is the component build-and-publish operation; not every scaffold defines a separate universal `build` script. Run the scripts that exist, then deploy:

```powershell
npm ci
npm run
npm run <discovered-check-script>
snc ui-component deploy --open
```

Use `npm ci` after the lockfile exists and is known good. On the first deployment, do not use `--force`. Confirm the prompt/profile points to the intended DEV/PDI, then verify:

- the scoped application, scope, version, and ownership;
- one `sys_uib_toolbox_component` for the intended tag;
- expected properties and the `ACME_CASE_SELECTED` event;
- no unexpected application files or cross-scope privileges;
- the component appears once in the intended UI Builder toolbox.

Before diagnosing a missing or stale toolbox entry, use the page variant editor's hamburger menu and select **Developer > Clear UI Builder cache**, then reopen the builder route. Readback proves deployment; the cache clear proves the authoring session is not showing an older component contract. Do not repeatedly deploy, add `--force`, or recreate the page until both checks have been made.

## Add and Configure in UI Builder

1. Open the intended non-production experience and a dedicated test page or safe page variant in the page's correct application scope.
2. Add a narrow **Look Up Records** or other approved data resource for the target case table. For an Incident demonstration, query only active priority 1/2 records, request only `sys_id`, `number`, `short_description`, `priority`, and `assignment_group`, sort deliberately, and impose a small server-side limit.
3. Test the data resource as the intended agent. Confirm table/field ACLs remove or reject unauthorized content.
4. Add **Priority Case Summary** from the toolbox.
5. Set `heading`, `emptyLabel`, and `maxItems` with static values or page properties as appropriate.
6. Bind `items` to a transformed data-resource result with this shape:

   ```json
   [
     {
       "id": "<record sys_id from the authorized result>",
       "number": "<display number>",
       "shortDescription": "<short description display value>",
       "priority": "<priority display value>",
       "assignmentGroup": "<assignment group display value>"
     }
   ]
   ```

   Use the actual data pill/output contract shown on the target release. A scripted property or transform may map it, but it must not perform another fetch or hard-code an internal output path copied from another data-resource version.
7. In the component's **Events** tab, add a handler for **Case selected** / `ACME_CASE_SELECTED`.
8. Map the handler to the supported record-navigation action for that Workspace. Set table to the target table and bind the record ID to the event payload's `id`. Do not put navigation logic inside the component.
9. Save, preview, and open the actual Workspace route in a fresh session.

If the component and page reside in different application scopes, inspect application dependencies and generated cross-scope access. Do not approve broad cross-scope privileges merely to make a data resource work.

Prefer this UI Builder event workflow over direct edits to the page definition. If narrowly authorized automation must patch `sys_ux_macroponent.composition`, retain the exact release-specific schema and its top-level array. PowerShell JSON conversion can unwrap a one-element array into an object; after serialization, assert that the stored value starts with `[`, parse it again, and confirm the component/event-mapping counts before reopening UI Builder. A malformed composition can surface as **No URL and/or Screen** or **No content available**, which is a page-metadata failure rather than a component-bundle failure.

## Workspace Validation

Record concrete evidence for each relevant row:

| Test | Expected evidence |
| --- | --- |
| Normal data | Correct bounded rows and display values; one server query |
| Empty query | `emptyLabel`, no blank container or exception |
| Loading/error | Page-level resource state is understandable; no stale protected data remains |
| Selection | One `ACME_CASE_SELECTED`; one navigation to the correct record |
| Intended non-admin | Only ACL-authorized records/fields appear; navigation succeeds where authorized |
| Denied persona | No protected rows or sensitive network response; no client-only role bypass |
| Narrow panel/zoom | No horizontal overflow; long content wraps |
| Keyboard/screen reader | Logical order, visible focus, useful button name, Enter/Space activation |
| Theme/localization | Legible in supported themes and expanded text |
| Browser evidence | No unexpected console error, duplicate request, blocked asset, or sensitive log |
| Inspector/profiler | Correct properties/event payload, no undelivered event, acceptable render/action timing |

Use ATF Configurable Workspace Page Inspector interactions where the deployed component and navigation action are exposed to ATF. Supplement gaps with repeatable browser automation or a documented manual test. Local success is not a substitute for this matrix.

## Update an Existing Component

For a backward-compatible change:

1. fetch/pull the established repository and reproduce its pinned toolchain;
2. confirm the tag, scope, deployed owner, current app version, page consumers, and contract;
3. create a branch and add/adjust tests or harness scenarios;
4. change source and manifest together, preserving defaults for existing pages;
5. run `npm ci`, discovered checks, and the local harness;
6. deploy normally to DEV and verify the exact deployed record/version;
7. use `--force` only if a normal deployment cannot update a record that is proven to be owned by this repository, after reviewing every overwrite target;
8. re-test one existing consumer and one new/changed scenario;
9. version and promote the scoped application through the established path.

Treat property removal/rename, payload changes, changed defaults, or new required properties as contract-breaking. Inventory consumers and provide a migration plan before deployment.

## Promotion and CI/CD Shape

The repository is source of truth for the component. A safe pipeline shape is:

```text
pull request
  -> pinned Node/npm + npm ci
  -> discovered lint/test/static checks
  -> dependency/license/vulnerability and bundle review
  -> authorized CLI deploy to an integration DEV instance
  -> metadata readback + UI Builder/Workspace smoke tests
  -> version/publish the scoped application
  -> approved App Repository or application-pipeline promotion to TEST
  -> TEST/UAT/security/regression evidence
  -> approved application promotion to PROD
```

Keep CLI credentials in the approved CI secret store, use a dedicated least-privilege deployment identity, prevent pull requests from untrusted forks from accessing secrets, and restrict deployment jobs by environment/approval. Do not make production `snc ui-component deploy` the release mechanism.

If the organization uses update sets for this application, publish the completed scoped application to an update set and use the established preview/commit path. Do not install the same application through App Repository and update sets on the same target.

## Example-Specific Failure Checks

- **Component absent:** compare tag/scope/associated type, deployed toolbox record, author role, and current page scope before redeploying.
- **Cases property is a string:** inspect the data pill and manifest field/schema; normalize the binding to an actual array rather than parsing arbitrary JSON inside the component.
- **Click renders but no event appears:** compare dispatch/action names and payload keys character-for-character, inspect the current manifest deployment, then inspect events in Next Experience Developer Tools.
- **Admin works, agent is empty:** inspect the data resource response and table/field ACLs as the agent. Do not add a client role bypass.
- **Duplicate navigation:** inspect duplicate UI Builder event handlers and action traces before changing the component.
- **Stale source after deploy:** compare source commit, built/deployed component version, record update time, UI Builder page instance, service-worker/cache state, and fresh-session result.
- **White or blank component:** clear UI Builder cache once, then bisect the deployed view from a static heading through list, selection, panels, imperative mount, and renderer attributes. Do not delete the page while isolating the bundle/renderer boundary.
- **Native button does not dispatch:** use `on-click={() => dispatch(...)}` with the `dispatch` argument provided to `view`; do not substitute React `onClick`, raw `onclick`, or delegated `data-*` routing.
- **Lifecycle never finds the mount:** do not guess an `onConnect` signature or search indefinitely through nested shadow roots. Verify the installed ui-core lifecycle/action contract and keep one stable imperative mount node.
- **Automation sees but cannot activate a control:** nested Workspace/UI Builder shadow roots and frames can exceed a harness's input support. Collect Inspector/console evidence and perform a documented real keyboard/pointer or ATF check before judging runtime behavior.
- **Long list is slow:** impose a small server-side query limit first; the client `maxItems` clamp protects rendering but does not reduce network/database work.

## Definition of Done

The example is complete only when source and lockfile are reproducible, local scenarios/checks pass, manifest and code contracts match, DEV metadata is read back, the component is bound on a safe UI Builder page, one event drives one Workspace navigation, intended and denied personas are tested, packaging is clean, the promotion/rollback path is recorded, and no task-created sensitive or throwaway data remains.
