# UI Builder Custom Components

Use this reference for UI Builder custom components, Component Builder macroponents, Next Experience UI Framework components, ServiceNow CLI `ui-component`, `now-ui.json`, `@servicenow/ui-core`, custom component properties or events, browser-side npm dependencies, or proposals to use React inside UI Builder.

This is the maintained operating recipe. Confirm the target instance family, patch, UI Builder/Store application versions, and installed CLI help before relying on a command or metadata shape. ServiceNow's Australia documentation was the current research baseline on 2026-08-26, but component packages and CLI extensions are release-aligned and can change independently of the family release.

When implementation begins, load `ui-builder-custom-component-example.md`. It contains a complete presentational component pattern, file tree, local harness, manifest merge guide, UI Builder bindings, event wiring, Workspace test, update, and promotion sequence. Use it as a shape, not as a substitute for the current CLI-generated files.

## First Decision: Do You Need a Custom Component?

Use the first option that meets the requirement:

1. Existing Next Experience component, supported configuration, theme token, or preset.
2. UI Builder composition using containers, data resources, client state, client scripts, events, formulas, repeaters, or conditional renderers.
3. Reusable controller when the value is a shared data/script/event contract rather than a visual primitive.
4. Page collection or viewport when the requirement is reusable page content or an extension point in a page the application does not own.
5. **Component Builder** when several existing components must become one reusable low-code component.
6. **ServiceNow CLI `ui-component`** when the requirement genuinely needs owned HTML, SCSS, JavaScript, lifecycle logic, a custom rendering primitive, or a browser library.
7. A separate ServiceNow-hosted SPA only when the whole experience benefits from another framework and the component boundary would be artificial. Load `servicenow-react-3d-frontends.md` for that architecture.

Do not build a custom component merely to restyle an OOTB component, bypass a missing ACL, hide fields from unauthorized users, reproduce an existing data visualization, or avoid learning UI Builder bindings. ServiceNow supports the framework and CLI, but customer-authored component code remains customer-owned; this is an explicit maintenance commitment.

## Component Builder or CLI?

| Need | Component Builder | CLI `ui-component` |
| --- | --- | --- |
| Compose existing components visually | Preferred | Usually unnecessary |
| Reuse data resources, controllers, client state, and client scripts | Preferred | Expose properties/events and let the page own them when practical |
| Custom HTML, SCSS, or JavaScript runtime | Not the primary path | Preferred |
| Browser-side npm library | No | Possible after compatibility review |
| Source code, lockfile, Git review, local development | Limited to platform metadata | Preferred |
| Artifact | Macroponent component in `sys_ux_macroponent` | Toolbox component represented in `sys_uib_toolbox_component` plus its scoped application metadata |
| Promotion | Application installation or update-set transport | Promote the deployed scoped application through the established application delivery path |

Component Builder is appropriate for simple to moderately complex reusable compositions. It is not a substitute for governance: search existing components first, use a clear owner and naming convention, document consumers, and audit duplicates. A shared component change updates every page using it.

Keep customer-owned reusable components read-only/protected in downstream environments according to the application's protection model. Do not make an OOTB component editable merely to change it; create an owned composition or extension and document the upgrade cost.

## Release and Environment Gate

Before creating or changing a component, record:

- target instance URL, family, patch/build, UI Builder version, and applicable Store application versions;
- intended runtime: Configurable Workspace, UI Builder portal experience, landing page, modal, viewport, or Virtual Agent;
- owning scoped application and whether the component is app-specific or a shared UI library;
- current application delivery path: Application Repository, update set, source control, or approved pipeline;
- developer identity, roles, and the non-admin runtime personas;
- component tag, application scope, public properties, emitted events, data sources, and server APIs;
- OOTB alternatives considered and why they do not satisfy the requirement.

Use `ui_builder_admin` for UI Builder authoring. CLI deployment commonly needs a privileged developer/admin account able to create or update the scoped application artifacts; determine the exact least-privilege role set on the target instead of assuming that UI Builder authoring access permits deployment.

Inspect, do not guess:

```powershell
snc version
snc --help
snc extension list-available -o table
snc ui-component --help
snc ui-component project --help
snc ui-component develop --help
snc ui-component deploy --help
node --version
npm --version
```

The current Australia docs identify ServiceNow CLI 1.1.0, the separately installed `ui-component` extension, and the most recent Node.js as prerequisites. Older component projects and extension releases have required older Node/npm combinations. For an existing project, its lockfile, generated `package.json`, documented engine constraints, and known working toolchain win over generic version advice. Never run a broad `npm update`, replace ServiceNow family tags, or modernize the renderer just because npm reports newer packages.

### Resolve conflicting and outdated guidance

Use this authority order when two sources disagree:

1. the target instance family/build, installed UI Builder and Store application versions, and approved organization support matrix;
2. installed `snc` and `snc ui-component ... --help` output plus the newly generated scaffold;
3. current release-matched ServiceNow product documentation and Store listing/release notes;
4. maintained ServiceNow Developer Program examples;
5. older blogs, videos, community posts, or copied projects only as historical clues.

Apply these concrete rules:

- Use the **ServiceNow CLI executable `snc`** and its separately installed `ui-component` extension. Treat tutorials whose primary command is `now-cli` as legacy unless maintaining a project that is deliberately pinned to that toolchain.
- Do not install Node 12 or 14 merely because an older Orlando-through-Vancouver example says so. Current Australia documentation says to use the most recent Node.js, while old generated projects may still be pinned; inspect the extension, `engines`, lockfile, and known-good CI runtime and reproduce that combination.
- ServiceNow's Australia install page says CLI 1.1.0 while the Store release-history page lists later 1.1.x fixes. Do not downgrade to match a prose page. Check `snc version`, the current Store listing's family compatibility, and organizational approval; record the version actually used.
- The combined Washington DC-to-Australia UI Component CLI release notes report no removals or deprecations and identify Xanadu module caching as the notable addition. Absence of a deprecation does not make a copied manifest current; the generated schema remains authoritative.
- Quebec-era instructions to create `sys_ux_event` and edit a macroponent manually described a CLI limitation at that time. First use the current scaffolded manifest/action deployment path and verify the deployed event. Create manual metadata only after proving the installed extension cannot express it, and then package and own that metadata explicitly.
- Component Builder is a current low-code path whose output is a `sys_ux_macroponent`; a CLI component is a `sys_uib_toolbox_component`. Do not use the storage table or editing instructions for one as if they applied to the other.

## Required Dependencies

### Local workstation

- ServiceNow CLI installed from the ServiceNow Store bundle for the operating system.
- `ui-component` CLI extension:

  ```powershell
  snc extension add --name ui-component
  ```

- Node.js and npm compatible with the installed extension and scaffolded project.
- A code editor; Git is strongly recommended and is the normal source-of-truth/rollback mechanism.
- Browser developer tools. The Next Experience/Page Inspector tooling is useful when available.

The ServiceNow SDK/Fluent toolchain and ServiceNow IDE are separate application-development surfaces; they are not prerequisites for, or replacements for, the documented `ui-component` scaffold/build/deploy workflow. Use them only for other application artifacts when the owning project deliberately uses those tools, and do not make the same component metadata editable from two toolchains.

Do not install or upgrade the CLI, Node, extensions, or npm packages on the user's workstation unless the task authorizes software installation. Report missing prerequisites and provide the exact official path.

### Instance

- UI Builder and the applicable workspace/experience installed and at a compatible version.
- The ServiceNow CLI Metadata application/plugin (`sn_cli_metadata`) when the CLI functionality being used requires it. The Australia CLI installation docs call this out for full CLI functionality; verify the command at hand instead of activating plugins speculatively.
- A target scoped application or permission to create one, a valid company/vendor prefix, and an approved delivery path.
- Roles for deployment and `ui_builder_admin` for adding/configuring the result in UI Builder.
- Server-side ACLs and approved data resources/APIs for every protected read or write.

Plugin activation, Store installation, and production deployment are separate high-impact actions and require explicit authorization.

### Scaffolded project

Let the CLI scaffold the ServiceNow dependencies. A typical project contains:

- `package.json` and a lockfile;
- `now-ui.json`, the deployment/UI Builder contract;
- `src/<custom-element-tag>/index.js` and `styles.scss`;
- `example/` for a local harness;
- CLI/builder configuration files generated for that extension release.

Common generated runtime packages include `@servicenow/ui-core`, `@servicenow/ui-renderer-snabbdom`, release-aligned ServiceNow components such as `@servicenow/now-button`, and CLI archetype/build packages. Keep them on the same ServiceNow family/tag selected by the scaffold. Do not copy a package list from an Orlando, Quebec, or Vancouver tutorial into a current project.

## Pro-Code Quick Start

### 1. Configure a named non-production profile

Use the current CLI's interactive profile flow and the organization's approved authentication method. Current CLI documentation supports Basic, OAuth, and OAuth + MFA profiles; prefer the organization's OAuth/MFA standard when available:

```powershell
snc configure profile set --profile dev
snc configure profile list
```

Do not put a password, client secret, token, or profile file in the repository, terminal transcript, issue, or component configuration. Use `--profile dev` according to the installed command help when several instances are configured, and verify the returned host and user before deployment.

### 2. Choose stable names and scope

- Custom-element tags must contain a hyphen and should carry the customer/vendor namespace, for example `x-acme-case-summary`.
- The application scope is snake case, maximum 18 characters in the documented CLI workflow, normally `x_<company>_<component>`.
- Resolve the company code from `glide.appcreator.company.code`; do not copy another PDI's numeric prefix.
- Treat the tag and scope as durable identities. Renaming after consumers exist creates migration work.
- Use the owning app's scope for an app-specific component only when the CLI workflow and application ownership support it. For a component shared by several apps, prefer a dedicated shared-component application with an owner, version, dependency contract, and install order.

### 3. Scaffold and install exactly

From an empty project directory:

```powershell
snc ui-component project --name @acme/case-summary --description "Reusable case summary" --scope x_acme_case_sum
npm install
```

Use `--offline` only when the lack of scope validation is intentional; validate the scope against the instance before any deployment. Commit the initial scaffold and lockfile before substantive changes so generated-versus-authored differences remain reviewable.

### 4. Build the smallest contract first

A component should normally receive configuration/data through properties and communicate user intent through events. Keep page navigation, page state, and page-specific data orchestration outside the visual component when practical.

Minimal framework shape:

```js
import {createCustomElement} from '@servicenow/ui-core';
import snabbdom from '@servicenow/ui-renderer-snabbdom';
import styles from './styles.scss';

const ITEM_SELECTED = 'ACME_ITEM_SELECTED';

const view = ({properties}, {dispatch}) => {
    const items = Array.isArray(properties.items) ? properties.items : [];

    if (!items.length) {
        return <p className="empty">{properties.emptyLabel}</p>;
    }

    return (
        <ul className="items">
            {items.map((item) => (
                <li key={item.id}>
                    <button
                        type="button"
                        on-click={() => dispatch(ITEM_SELECTED, {id: item.id})}
                    >
                        {item.label}
                    </button>
                </li>
            ))}
        </ul>
    );
};

createCustomElement('x-acme-case-summary', {
    renderer: {type: snabbdom},
    view,
    styles,
    properties: {
        items: {default: []},
        emptyLabel: {default: 'No items'}
    }
});
```

The JSX resembles React JSX but is rendered by ServiceNow's supported Snabbdom renderer; it is not React. Confirm event syntax and renderer behavior in the framework reference matching the project family.

Expose only intentional public properties and actions/events in the scaffolded `now-ui.json`. Preserve the generated schema and add UI Builder metadata such as a meaningful label, description, icon, category, associated experience types, property schemas/defaults, and action payload schemas. Names in JavaScript and `now-ui.json` must match exactly.

Do not blindly copy an old manifest. Property field types, action payload schema, configuration layout, supported associated types, and event deployment behavior have changed across extension versions. Validate with the installed extension by deploying a minimal property/event slice before building the full component.

### 5. Develop locally

Use representative harness data for normal, empty, loading, error, long-text, and permission-denied states:

```powershell
snc ui-component develop --open
```

The default entry is normally `example/index.js`; use `--entry`, `--port`, or `--host` only after confirming current help. Local rendering proves the browser bundle and component logic, not UI Builder binding, platform theming, session behavior, ACLs, or workspace integration.

Treat this as a local development-server loop, not a guaranteed hot-module-reload contract. Current docs guarantee the server, and Xanadu+ release notes document module caching; they do not promise that every source, style, dependency, or manifest change is injected without a refresh. Observe the installed extension: refresh the browser after a source/style change when needed, and restart the server after dependency, entry, builder configuration, or manifest changes when behavior is stale.

Debug in this order:

1. terminal build/compile output and the first error, not the final cascade;
2. browser console for render/action exceptions and duplicate custom-element registration;
3. browser Network for missing bundles/assets, wrong content types, CSP/CORS, authentication, and server responses;
4. Next Experience Developer Tools Inspector/Profiler for component properties, state, dispatched/handled events, health indicators, traces, service-worker/cache behavior, and performance;
5. deployed record/version, UI Builder binding, page state/data resources, and non-admin ACL behavior.

The ServiceNow CLI log directory is normally `%USERPROFILE%\.snc\.logs` on Windows. Inspect only the relevant time window and redact credentials/tokens before sharing. Do not enable verbose logging in a way that persists secrets. Use the browser's Disable cache option only while DevTools is open and only for diagnosis; confirm the final behavior with normal caching restored.

### 6. Run project checks

Run the scripts actually present in `package.json`; do not invent a generic build/test command:

```powershell
npm run
npm run <discovered-script-name>
```

Execute only scripts the project defines. Review the lockfile diff, production dependency tree, license obligations, vulnerability output, generated bundle size, and source diff. Treat `npm audit` as input for engineering judgment: do not apply `npm audit fix --force` to a ServiceNow-aligned dependency tree.

### 7. Deploy to DEV

Confirm the CLI profile, source branch, scope, tag, and intended overwrite set. Then:

```powershell
snc ui-component deploy --open
```

First deployment should not use `--force`. The flag overwrites existing component records and is justified only when the project is the established source of truth, the exact target records are known, and overwrite impact has been reviewed. A successful CLI message is only packaging evidence.

### 8. Verify the deployed artifacts

- Confirm the scoped application, scope, version, package ownership, and component tag.
- Confirm the component appears once in UI Builder's toolbox with the expected label/category and on the intended experience type.
- Verify the CLI-created `sys_uib_toolbox_component` and related component/macroponent metadata read-only; do not make routine direct-table edits.
- Confirm every property, default, required flag, event, and payload field exposed by the manifest.
- Inspect cross-scope privilege/request records and application dependencies when the page and component use different scopes.
- Add the component to a dedicated test page or safe page variant in the correct scope; bind real data and events, save, preview, and test the runtime route.
- Re-test after a fresh session or supported cache refresh. Do not accept a local dev-server result or admin-only UI Builder preview as runtime proof.

## Component Architecture and Coding Standards

### Contract design

- Prefer **properties in, events out**. Properties should describe data/configuration; events should describe user intent or completed outcomes.
- Keep property and event names stable, documented, and semantic. Avoid exposing internal state or DOM details.
- Use typed, bounded payloads with portable business keys when possible. Do not emit whole records, tokens, credentials, encoded queries, or sensitive fields.
- Supply safe defaults and render missing/invalid properties without throwing. Validate arrays, object shape, enum values, URLs, and maximum lengths.
- Treat property schema changes like API changes. Add backward-compatible defaults, deprecate before removal, and version breaking contracts.
- Preserve one-way data flow. Never mutate `state`, `properties`, arrays, or objects in place; create new values and update state through framework APIs.

### State and actions

- Keep only component-owned transient UI state locally: expanded row, active tab, pending gesture, or request status.
- Keep shared/page state in UI Builder client state or a controller. Do not create a hidden global store inside a leaf component.
- Keep the view pure: derive markup from state/properties and dispatch actions. Put asynchronous work, timers, and side effects in effects/action handlers.
- Give every request explicit idle/loading/success/empty/error/unauthorized states. Prevent stale responses from overwriting newer state and prevent duplicate submits.
- Remove timers, subscriptions, observers, global listeners, object URLs, and imperative library roots in the current framework disconnect/teardown lifecycle.
- Avoid direct DOM manipulation for framework-rendered nodes. If an imperative library requires DOM access, mount it only into a dedicated component-owned node after connection, never query or mutate the Workspace shell/document globally, and keep every update and teardown inside the lifecycle boundary.
- Split substantial components into view, actions/effects, constants, selectors/normalizers, and focused child components. Avoid a monolithic `index.js`.

### Presentational versus connected

Default to a presentational component fed by UI Builder data resources or controllers. This makes the component reusable and lets the page own refresh, parameters, caching, and event wiring.

A connected component is justified when a stable reusable component owns a genuinely cohesive data contract used on several pages or needs tightly coupled incremental interaction. Use supported effects such as the release-compatible HTTP or GraphQL effect. Query narrowly and still expose refresh/result events where the host page needs coordination.

### Data and security

- The browser is not a security boundary. Enforce table/field ACLs, roles, data policies, authorization, validation, and business invariants on the server.
- UI Builder visibility, disabled buttons, client validation, component properties, and hidden event handlers do not authorize an operation.
- Prefer UI Builder data resources/controllers for page data. For component-owned same-instance calls, use supported effects and an ACL-enforcing API; request only required fields and rows.
- Never use client-side GlideRecord, embed credentials, or call a privileged endpoint that trusts client-supplied roles, table names, field names, encoded queries, or sys_ids.
- For a consequential write, call a narrow server contract that re-resolves records, checks authorization, validates allowed transitions, is idempotent where retry is possible, and returns a small typed result.
- Do not render untrusted HTML. Prefer text nodes and structured markup. If a requirement truly needs HTML, use an approved sanitizer and a narrowly documented content contract; `innerHTML` is not a default rendering strategy.
- Validate outbound URLs and navigation targets. Prevent `javascript:`/unsafe schemes and open redirects.
- Keep external API credentials server-side in Connection and Credential Aliases/REST Messages or an approved integration layer. Direct browser CORS is appropriate only for an approved public or user-authenticated endpoint with no hidden secret and an explicit data-egress review.

### Styling, accessibility, and localization

- Prefer Next Experience components and Horizon/Now Design System tokens over recreating buttons, inputs, modals, and loaders.
- Import every ServiceNow inner component package and declare it in the current `now-ui.json` `innerComponents` contract when required by the toolchain.
- Scope SCSS to the component. Do not rely on generated host-page classes, global element selectors, document-level CSS, or `!important` as architecture.
- Use semantic HTML, correct heading order, native buttons/links where possible, accessible names, visible focus, keyboard operation, touch support, and status/error announcements.
- Never use color, hover, animation, or iconography as the only carrier of meaning. Respect reduced motion, high contrast, zoom/text expansion, and theme changes.
- Use translation services/patterns supported by the current framework. Do not concatenate translatable sentences or design only for short English labels.
- Test light/dark/customer themes and surrounding OOTB components. A component embedded in a transactional workspace should look native to that workspace.

### Performance

- Keep the initial bundle and dependency count small; prefer tree-shakeable, browser-native, or existing ServiceNow primitives.
- Avoid repeated network calls per child row, unbounded results, expensive work in `view`, unnecessary state updates, and document-wide observers.
- Debounce user-driven queries, cancel or ignore obsolete requests, and virtualize or paginate large collections rather than rendering them all.
- Lazy-load heavy optional behavior only when the ServiceNow bundler/runtime path supports it and the deployed chunks/assets are proven.
- Measure the real workspace page. Local component speed does not reveal contention with the shell, data resources, other components, or a slow client network.

## External Browser Libraries

External npm libraries can be used in a CLI component, but they are not automatically supported by ServiceNow. ServiceNow supports the Next Experience framework/CLI; the custom code is yours, and the third-party vendor owns library support.

Install only the reviewed, exact version and commit the resulting lockfile:

```powershell
npm install --save-exact <browser-library>@<approved-version>
```

Then import it from source so the project bundler can account for it. Do not paste minified vendor code into the component or load an unversioned global script.

| Library shape | Typical risk | Decision rule |
| --- | --- | --- |
| Pure ESM utility with no DOM/global side effects | Lower | Accept when it saves meaningful code and tree-shakes cleanly |
| Headless/imperative browser library mounted in an owned node | Medium | Require explicit update/teardown and accessibility proof |
| Chart, map, editor, worker, WASM, or remote-asset library | Medium-high | Prefer OOTB first; prove assets, CSP/CORS, size, cleanup, and degraded states |
| React/Vue/Angular renderer or component ecosystem | High | Treat as unsupported framework integration, not an ordinary dependency |
| Full React UI kit such as Material UI | Very high | Usually reject inside a leaf component; justify only at product architecture level |

For 3D work, classify the libraries by renderer rather than treating them as one stack:

| Package | CLI UI Builder component | Preferred use |
| --- | --- | --- |
| `three` | Viable with customer-owned integration risk | Mount one renderer/canvas in a component-owned node; handle resize, visibility, animation-loop shutdown, and GPU-resource disposal explicitly |
| `three-stdlib` | Often viable selectively | Import only the controls/loaders/utilities that pass bundler, asset, worker, CSP, and teardown tests |
| `@react-three/fiber` | High-risk custom-renderer integration | Use in a React UI page/application, not as an ordinary dependency of the supported Snabbdom component model |
| `@react-three/drei` | Same boundary as React Three Fiber | Use with React Three Fiber in the React application path; audit every helper's asset, portal, loader, worker, and WebGL assumptions |

For a small drag-and-drop 3D widget in UI Builder, prefer `three` plus only the necessary framework-agnostic `three-stdlib` exports. For a substantial 3D surface, digital twin, planner, or configurator that naturally needs React Three Fiber and Drei, use the ServiceNow React UI-page path described below.

Before adding a package, document:

- the user value that cannot be met cleanly with the platform/component library;
- exact pinned version and lockfile;
- license, attribution, maintenance health, vulnerability status, and upgrade owner;
- minified/transitive bundle cost and duplicate dependencies;
- browser support, ESM/CommonJS/bundler compatibility, and reliance on Node built-ins;
- global CSS, `window`/`document`, portal/overlay, Web Worker, WASM, dynamic import, remote asset, or CDN assumptions;
- initialization, property-update, error, and teardown behavior;
- accessibility and localization behavior;
- proof in local harness and the real deployed workspace across the supported target releases.

Prefer pure utility or headless libraries. Be cautious with UI frameworks that bring a second design system, theme engine, global reset, focus manager, or portal-to-`document.body` behavior. Mount imperative libraries only inside a component-owned element, bridge changes through properties/events, and destroy the instance on teardown.

Bundle dependencies through `package.json` and imports when the toolchain supports them. Avoid runtime CDN scripts: they add CSP/CORS, availability, version drift, privacy, integrity, offline, and support failure modes. Libraries that fetch fonts, icons, workers, WASM, maps, or chunks at runtime need an explicit asset-hosting and Content Security Policy design.

Do not apply Australia's ServiceNow IDE/SDK **server-side** third-party-library support list to a CLI UI Builder browser bundle. Server modules, CLI custom components, and SDK/IDE React UI-page assets are different runtimes and packaging paths. For a React UI page, declare browser dependencies in that project's `package.json`, retain its lockfile, and prove the generated client assets through the SDK/IDE build and install flow.

## React: Supported Boundary and Safer Choices

The supported **CLI custom-component** model is Next Experience UI Framework plus the ServiceNow-supported default renderer. The component JSX is not React JSX at runtime. ServiceNow has stated that it does not provide an officially supported React renderer for that component model; third-party/custom renderers and React integration code inside it are customer-supported.

Australia also documents a distinct, official React UI-development path through ServiceNow IDE or the ServiceNow SDK. A React template builds client assets with Rollup and a Fluent `UiPage` definition links the generated `index.html` to a scoped `.do` endpoint, normally with `direct: true`. This creates a React **page/application**, not a drag-and-drop `sys_uib_toolbox_component`, and it does not make React Three Fiber a supported renderer inside a CLI custom component.

Treat the current React UI-page capability as experimental until the target release documentation says otherwise. At the Australia baseline it has material limitations: no server-side rendering, hash routing only, unsupported audio/video/WASM assets, restrictions around preload links and some stylesheet patterns, attachment-size constraints, and one-way source ownership from the IDE/SDK to the instance. Validate the exact template, generated files, supported asset types, and install behavior against the target family and patch.

Use this decision order:

1. Implement with the default Next Experience renderer and ServiceNow components.
2. Use a focused framework-agnostic browser library inside that component if necessary.
3. If a whole surface must be React, prefer the current ServiceNow IDE/SDK React template and Fluent `UiPage` path when its experimental limitations are acceptable. Give it its own ServiceNow route; link/navigate to it from the experience, or use the UI Builder iframe component only when in-page embedding is required and its sandbox, sizing, focus, session, CSP, and `postMessage` tradeoffs are proven. Do not assume a UI Builder viewport can host an arbitrary Fluent UI page.
4. Wrap React inside a custom component only as an explicitly accepted engineering experiment.

If a React wrapper is approved, it must:

- pin compatible `react` and `react-dom` versions and count their full bundle cost;
- create exactly one React root in a component-owned mount node after connection;
- translate ServiceNow properties into React props without sharing mutable state;
- translate React callbacks into small ServiceNow component events;
- update the React root deterministically when component properties change;
- unmount the root and remove subscriptions/listeners during component teardown;
- contain portals, focus management, CSS-in-JS insertion, and theme context within the safe component/page boundary;
- prove no duplicate React runtime or custom-element registration collisions;
- pass accessibility, performance, UI Builder authoring, deployed runtime, upgrade, and non-admin tests.

Material UI and similar React design systems are usually a poor fit inside one UI Builder component: they add React, a second design language, styling/portal/focus machinery, and substantial bundle weight while competing with the Now Design System. Use them only with a documented product-level reason and explicit ownership of the unsupported integration.

### Assessing an existing React application for conversion

Do not equate “it renders one screen” with “it is one component.” Before proposing a conversion, inventory:

- whether the source is a reusable visual primitive or a complete page shell with navigation, panels, dialogs, routing, session bootstrap, and product workflows;
- renderer lock-in such as React hooks, React Three Fiber, Drei, portals, or framework-specific lifecycle and state;
- document-wide behavior such as `:root`/`html`/`body` CSS, `100vh`, fixed overlays, global listeners, body cursor/scroll changes, and direct `window.location` access;
- deployed bundle size, asset/chunk/worker/WASM behavior, WebGL lifecycle, and whether more than one continuously rendering canvas can exist;
- data ownership, ACL-enforcing server contracts, direct Table API calls, current-user/session handling, and which inputs/actions should become UI Builder properties, data resources, or events.

Use the smallest honest migration boundary:

| Existing application shape | Recommended path |
| --- | --- |
| Whole React product whose page boundary is natural | Keep or migrate it as a ServiceNow React UI page; link to it or use an iframe only when embedded composition is required |
| Focused framework-independent visualization | Port it to a CLI component and expose properties in/events out |
| Large React/React Three Fiber scene required as a true toolbox component | Treat as a substantial rewrite to the supported renderer plus imperative Three.js, or obtain explicit acceptance for an unsupported React wrapper experiment |
| Page shell containing one valuable visualization | Put only the visualization in a custom component; let UI Builder own surrounding layout, data resources, panels, dialogs, navigation, and page state |

Estimate reuse by layer rather than by file count. Static geometry, typed contracts, pure calculations, and server APIs often transfer; React component trees, hooks, React Three Fiber/Drei scene JSX, global CSS, routing, and document-level lifecycle usually do not transfer directly to a supported CLI component.

## Deployment and Promotion Recipe

### DEV deployment

1. Confirm source branch/status, lockfile, CLI/extension/Node versions, profile host/user, scope, component tag, and app ownership.
2. Run local checks and the representative local harness.
3. Deploy without `--force`; record CLI output and time.
4. Read back the scoped application and component metadata.
5. Test a dedicated UI Builder page/variant with real bindings and events.
6. Test runtime as intended non-admin and denied personas.
7. Confirm no accidental application files, cross-scope privileges, direct OOTB edits, or unrelated page changes.
8. Commit reviewed source and lockfile. Do not treat instance-generated component records as a second editable source.

### Promote the application, not an ad hoc rebuild

CLI deployment produces a scoped application/plugin on the development instance. Choose one established downstream path:

- **Application Repository/pipeline:** preferred for installing and versioning a completed custom application across company instances.
- **Publish to Update Set:** acceptable where that is the established application transport or for an auditable/exportable application version. Publishing the application creates a complete update set of its configuration records.

Do not mix Application Repository and update-set installation paths for the same application on a target instance. Do not run CLI component deployment directly against production. If the component is a dependency of another application, declare and test the dependency/install order and version compatibility.

On every target:

- preview/install through the approved process and review conflicts rather than forcing them;
- confirm required platform/Store dependencies and scope exist;
- re-read component, application, property, event, inner-component, and cross-scope metadata;
- smoke-test the real runtime page and events as non-admin;
- verify server reads/writes, ACL denials, and side effects;
- run ATF Configurable Workspace Page Inspector interactions when the component/actions are testable, supplemented by browser automation or manual checks for gaps.

### Rollback

Keep the previous Git revision, lockfile, application version/package, and component contract. Roll back with the approved prior application version or a reviewed redeployment of the prior source to DEV followed by normal promotion. A UI rollback does not reverse records, messages, uploads, integrations, or other runtime side effects created while the component was active; plan those separately.

## Validation Matrix

### Local contract

- scaffold installs reproducibly from the lockfile;
- defined lint/test/check scripts pass;
- normal, empty, loading, error, invalid-property, long-text, and large-but-bounded data render correctly;
- events fire once with the documented payload;
- timers, listeners, observers, requests, and library roots clean up;
- no secrets, customer URLs, personal PDI identifiers, or instance sys_ids are committed.

### UI Builder authoring

- one correctly labeled toolbox entry appears in the intended category/experience types;
- property editors, defaults, required flags, schemas, and test values behave correctly;
- emitted events and payload fields are selectable and bindable;
- component can be duplicated/reused without ID collisions or hidden global state;
- component works in the correct page/application scope and dependencies are explicit.

### Runtime behavior

- fresh session, intended page route, modal/viewport context, and page variants work;
- intended non-admin succeeds and unauthorized persona receives no protected data/action;
- loading, retry, empty, validation, server error, timeout, and permission-denied states are understandable;
- navigation, event handlers, data refresh, and server side effects occur exactly once;
- browser console and network contain no unexpected errors, blocked resources, duplicate requests, or sensitive logs.

### UX and accessibility

- keyboard order, activation, escape/close behavior, focus return, visible focus, screen-reader names/status, touch, and no hover-only interaction;
- responsive widths, workspace side panels, text zoom, reflow, localization expansion, light/dark/customer themes, and no horizontal overflow;
- contrast, reduced motion, non-color status cues, semantic headings, labels, and errors;
- performance remains acceptable in the full workspace, not only in isolation.

### Packaging

- exact application scope/version and delivery mechanism are recorded;
- component application files and application dependencies are complete;
- no competing App Repository/update-set/source path exists on the target;
- target install readback and runtime smoke test pass;
- prior version and runtime-data rollback responsibilities are known.

## Troubleshooting Order

### CLI or install failure

1. Run `snc version`, extension list, `snc ui-component --help`, Node/npm versions, and `npm install` without changing anything.
2. Compare the project's engines, lockfile, ServiceNow family tags, and known working versions with the installed extension.
3. Confirm the profile host/auth method/user and exact target family.
4. Reproduce with a newly scaffolded minimal component only in a temporary directory when necessary; do not rewrite the real project first.
5. Never solve a peer warning with a blind `--force`, broad npm upgrade, or copied legacy Node version.

### Deploy succeeds but component is absent

1. Confirm correct instance, application install state, scope, tag, and toolbox component record.
2. Validate `now-ui.json` UI Builder metadata, associated types, label/category, and exact component key.
3. Confirm the author has `ui_builder_admin` and is editing the correct experience/page scope.
4. Start a fresh UI Builder session or use the supported cache refresh; do not repeatedly redeploy first.
5. Inspect related macroponent/component metadata and system logs read-only before any direct repair.

### Properties or events are missing/stale

1. Compare JavaScript names with the current manifest property/action names and payload schema.
2. Confirm the deployed component record/version changed and the page is not using another tag/component.
3. Refresh UI Builder cache/session and re-add the component only on a disposable test page if needed.
4. Check cross-scope access and generated `sys_ux_event`/macroponent relationships.
5. Older tutorials require manual event records because older CLI versions did not deploy them. Do not copy that workaround into a current project until the installed extension's supported manifest path is disproven; if manual metadata is unavoidable, own and package it explicitly.

### Local works, instance fails

1. Compare deployed bundle/version and fresh-session behavior.
2. Inspect browser console/network for CSP, CORS, missing chunks/assets, wrong content types, auth/ACL failures, and duplicate custom-element registration.
3. Verify theme tokens, container size, page data bindings, and real property types.
4. Test the same call as the non-admin persona and inspect server logs/ACL diagnostics.
5. Remove or isolate third-party libraries to find the smallest failing boundary.

### Stale UI or force-deploy temptation

Prove whether the stale layer is source, built bundle, deployed record, UI Builder metadata, page instance, browser cache, or ServiceNow cache. Use `--force` only when the deployed record is known to be owned by the local project and a normal deployment cannot update it for an understood reason.

## Official Sources and Maintained Examples

- Create custom components using ServiceNow CLI: https://www.servicenow.com/docs/r/application-development/custom-components.html
- ServiceNow CLI commands, including `ui-component`: https://www.servicenow.com/docs/r/application-development/servicenow-cli/sn-cli-commands.html
- Install ServiceNow CLI: https://www.servicenow.com/docs/r/application-development/servicenow-cli/download-cli.html
- ServiceNow CLI Store release history: https://www.servicenow.com/docs/r/store-release-notes/store-rn-ancillary-software-sn-cli.html
- Manage CLI extensions: https://www.servicenow.com/docs/r/application-development/servicenow-cli/find-extensions.html
- Combined UI Component CLI Extension release notes through Australia: https://www.servicenow.com/docs/r/delta-washingtondc-australia/australia-washingtondc-uicomponentcliextension-release-notes.html
- Set up a component project: https://www.servicenow.com/docs/r/xanadu/application-development/building-applications/setup-component-project.html
- Develop a component: https://www.servicenow.com/docs/r/washingtondc/application-development/develop-component.html
- Deploy a component: https://www.servicenow.com/docs/r/washingtondc/application-development/deploy-to-instance.html
- Component Builder and CLI comparison: https://www.servicenow.com/docs/r/application-development/ui-builder/component-builder.html
- Add/configure components and bind events in UI Builder: https://www.servicenow.com/docs/r/application-development/ui-builder/add-components.html
- UI Builder security and scope: https://www.servicenow.com/docs/r/application-development/ui-builder/security-roles.html
- UI Builder client scripts: https://www.servicenow.com/docs/r/application-development/ui-builder/define-client-scripts.html
- UI Builder page performance: https://www.servicenow.com/docs/r/application-development/ui-builder/performance-settings.html
- Next Experience Developer Tools release notes: https://www.servicenow.com/docs/r/release-notes/ned-tools-rn.html
- ATF Configurable Workspace interaction testing: https://www.servicenow.com/docs/r/application-development/automated-test-framework-atf/atf-create-tests-ws.html
- Application sharing choices: https://www.servicenow.com/docs/r/application-development/c_SharingApplications.html
- Publish an application to an update set: https://www.servicenow.com/docs/r/application-development/t_PublishApplicationsToAnUpdateSet.html
- ServiceNow employee guidance on third-party support, default renderer support, Git source of truth, and update-set promotion: https://www.servicenow.com/community/developer-blog/technow-ep-78-building-now-experience-components/ba-p/2275564/page/2
- ServiceNow UI Builder FAQ on the custom-code support boundary: https://www.servicenow.com/community/next-experience-articles/ui-builder-faq/ta-p/2331977
- React UI development with ServiceNow IDE/SDK, including templates, build/install behavior, and current limitations: https://www.servicenow.com/docs/r/application-development/ui-development-react.html
- Fluent `UiPage` API for scoped `.do` endpoints and `direct` React pages: https://www.servicenow.com/docs/r/application-development/servicenow-sdk/fluent-ui-page-api.html
- ServiceNow SDK React UI-page sample: https://github.com/ServiceNow/sdk-examples/tree/main/react-ui-page-ts-sample
- UI Builder iframe component and `postMessage` contract: https://horizon.servicenow.com/workspace/components/now-iframe?release=australia
- Maintained Developer Program component example (Vancouver-era; use for patterns, not current package versions): https://github.com/ServiceNowDevProgram/Menu-Generating-Operations-Program-Widget-Custom-Component
- Official developer examples: https://github.com/ServiceNowDevProgram/now-experience-component-examples
- Official Developer Program advanced example: https://github.com/ServiceNowDevProgram/Menu-Generating-Operations-Program-Widget-Custom-Component
- Current framework/component documentation and usage guidance: https://developer.servicenow.com/ and https://horizon.servicenow.com/

ServiceNow employee guidance also establishes two important support boundaries: ServiceNow supports the framework/CLI rather than customer component code, and it has not offered an officially supported React renderer. Treat Community and Developer Blog material as implementation context; verify current behavior against the target release and installed CLI.
