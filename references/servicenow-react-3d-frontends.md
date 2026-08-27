# ServiceNow React and 3D Frontends

Use this reference for a bespoke React application hosted by ServiceNow, especially an interactive WebGL experience, 3D floor plan, map, configurator, or digital-twin-style demo. Do not use it to bypass an adequate native ServiceNow product. For workplace mapping and enterprise reservations, evaluate licensed Workplace Service Delivery Indoor Mapping before proposing a custom replacement.

The maintained reference implementation is `https://github.com/simenandreas91/servicenow-3d-desk-booking`. It evolves Andrew Pishchulin/ELIN Software's `https://github.com/elinsoftware/servicenow-react-app` boilerplate and preserves its MIT notice and repository history. Treat the ELIN project as the source for the ServiceNow-hosted React approach and the maintained desk-booking project as the working reference for the added Three.js scene, interaction, and responsive product UI.

## Current Australia Architecture Decision

ServiceNow now documents an official React UI-development path through ServiceNow IDE or the ServiceNow SDK. For a new source-managed React/3D surface, start by evaluating that path: scaffold from the current React template, define the page with the Fluent `UiPage` API in a `.now.ts` source file, build the client assets, and install them into the scoped application. The generated page receives a scoped `.do` endpoint and `direct: true` is the normal React-page configuration.

This is a React page/application, not a React renderer for a CLI UI Builder toolbox component. Integrate it into an experience through an owned route/link. If it must appear inside a UI Builder composition, the iframe component is a possible boundary only after validating same-instance session behavior, frame policy, sandbox permissions, target origin, focus, scrolling, responsive sizing, CSP, and a minimal `postMessage` contract. Do not claim that a UI Builder viewport can host an arbitrary Fluent UI page without release-specific proof.

The Australia documentation marks React UI development experimental and lists meaningful constraints, including no SSR, hash routing only, unsupported audio/video/WASM, restrictions on preload links and some stylesheet patterns, attachment-size settings, and one-way source ownership from IDE/SDK to the instance. Confirm the current target-release documentation and the generated project's Node/package-manager constraints before choosing it.

The property-backed single-file plus Scripted REST pattern later in this reference remains an established fallback for the maintained demo and existing update-set-managed applications. Do not select it automatically for a new long-lived application when the SDK/IDE React path meets the requirement.

Official starting points:

- React UI development: https://www.servicenow.com/docs/r/application-development/ui-development-react.html
- Fluent `UiPage` API: https://www.servicenow.com/docs/r/application-development/servicenow-sdk/fluent-ui-page-api.html
- ServiceNow SDK React UI-page sample: https://github.com/ServiceNow/sdk-examples/tree/main/react-ui-page-ts-sample
- UI Builder iframe component: https://horizon.servicenow.com/workspace/components/now-iframe?release=australia
- Configurable Workspace tabbed navigation: https://www.servicenow.com/docs/r/application-development/workspace-builder/configure-workspace-settings.html
- Link a UI Builder event to a destination page: https://www.servicenow.com/docs/r/application-development/ui-builder/link-component-destination.html
- Workplace Service Delivery suite: https://www.servicenow.com/docs/r/employee-service-management/workplace-service-delivery/workplace-service-delivery-suite-landing-page.html
- Enterprise Asset Management: https://www.servicenow.com/docs/r/it-asset-management/enterprise-asset-management/enterprise-asset-management.html

## Proven Stack

- **React** and **React DOM** for application state, panels, filters, booking flows, loading/error states, and accessibility markup.
- **TypeScript** for the ServiceNow record contracts and scene component props.
- **Vite** for fast local development and production bundling.
- **vite-plugin-singlefile** to inline JavaScript and CSS into one `dist/index.html` that ServiceNow can serve without a separate static-asset pipeline.
- **Three.js** for cameras, vectors, materials, geometry, lighting, fog, projection updates, and WebGL rendering.
- **@react-three/fiber** for declarative Three.js scenes in React through `Canvas`, `useFrame`, mesh event handlers, and normal component composition.
- **@react-three/drei** for reviewed React Three Fiber helpers where they reduce lifecycle or interaction code without importing unnecessary assets or runtime assumptions.
- **three-stdlib** for selectively imported framework-agnostic Three.js controls, loaders, and utilities; note that Drei already uses parts of this ecosystem, so inspect the final bundle for duplication.
- **Axios** for the current ServiceNow session-token bootstrap and Table API calls. Fetch is also viable; keep one HTTP convention per app.

Resolve mutually compatible current versions when starting a new app. A working combination used React 19, Three.js 0.185, React Three Fiber 9, and Vite 8, but do not freeze those versions into a general requirement.

## Why React Three Fiber and an Orthographic Camera

- React Three Fiber is the React renderer for Three.js. Its version should match the React major version; the documented working combination for this app is React 19 with React Three Fiber 9. Confirm the current compatibility guidance in the [React Three Fiber repository](https://github.com/pmndrs/react-three-fiber) before starting a new build.
- React Three Fiber exposes pointer, click, wheel, propagation, and capture behavior directly on raycastable Three.js objects. Use the official [event documentation](https://r3f.docs.pmnd.rs/api/events) when implementing overlapping meshes, hover, selection, or `stopPropagation()` behavior.
- A Three.js `OrthographicCamera` keeps an object's rendered size constant as its distance changes. That produces the architectural/isometric appearance used by the desk-booking scene without perspective convergence. Use the official [OrthographicCamera documentation](https://threejs.org/docs/pages/OrthographicCamera.html), and call `updateProjectionMatrix()` after changing camera properties such as zoom.

## Prior Art Reviewed

Use these projects as design and architecture references, not as mandatory dependencies:

- [OpenPlan3D](https://github.com/laanlabs/openPlan3D): a SvelteKit and Three.js 2D/3D floor-plan editor; useful for comparing plan and spatial views.
- [Aedifex](https://github.com/TangSY/aedifex): a React, React Three Fiber, Three.js/WebGPU architectural editor; useful for scene structure, spatial interactions, and camera controls.
- [Floorcraft](https://github.com/rcasto123/Floorcraft): a React/Konva 2D office planner; useful for desk/employee data modeling and seating-management interactions, even though it is not the 3D renderer used here.
- [threejs-3d-room-designer](https://github.com/CodeHole7/threejs-3d-room-designer): a React and Three.js room planner/configurator with linked 2D and 3D editing concepts.

Review each project's current license before reusing code or assets. Preserve required notices and prefer learning from interaction and architecture patterns over copying an editor wholesale into ServiceNow.

## Architecture

Keep three layers distinct:

1. **ServiceNow data and security:** scoped tables, ACLs, server validation, collision prevention, and Scripted REST resources.
2. **React application:** business state, filters, booking panel, API client, responsive layout, accessible fallbacks, and user feedback.
3. **3D scene:** a pure visual projection of desk/space records. Selecting a mesh raises a desk identifier back to React; it never authorizes or persists a reservation itself.

The browser must never be the security boundary. Recheck availability and permissions on the server when booking or cancelling, even when the mesh appears available.

For a broader facilities-management or FDV solution, perform a product-fit and licensing gate before designing custom tables or workflows. Evaluate Workplace Service Delivery/Workplace Central and Indoor Mapping for the location-space hierarchy, floor maps, reservations, workplace maintenance, and leases; Enterprise Asset Management for asset lifecycle, contracts, maintenance plans, work orders, mobile work, and asset workspace; and Field Service Management when dispatch, scheduling, or technician execution is central. Reuse the licensed product data model and processes where they fit, and customize only the proven gaps.

In a tabbed Configurable Workspace, the durable end state is normally native record pages and workflows plus a focused spatial navigator. A UI Builder custom component can raise a record-selection event that UI Builder links to the workspace record route. A full React `UiPage` or iframe can still serve as a standalone digital-twin/editor or a transitional embedded map, but it requires a reviewed message bridge to request native workspace navigation and does not become a workspace page merely because it is hosted on the same instance.

When one spatial baseline will seed multiple products, tag a stable map-only revision and give each product its own repository or source boundary, ServiceNow scope, roles, data APIs, hosted bundle property, route, update set, and release lifecycle. Preserve portable geometry identifiers across the copies, but keep business adapters and sensitive data contracts product-specific. A copied deployment helper should fail closed until its new scope, property, and route are configured; transfer later map-only commits explicitly, and extract a shared package only after repeated synchronization work justifies the added release coupling.

When one React application opens a second React Three Fiber view, prefer source-level composition: make each scene a visual component that receives typed records and selection callbacks, while a React feature shell owns data loading, authorization-aware states, and product actions. Do not copy a second application shell, API client, or reservation workflow merely to reuse its scene. Avoid leaving two continuously rendering `Canvas`/WebGL renderers active beneath an overlay; pause or unmount the background scene while the foreground floor view is open, or deliberately swap scene graphs inside one canvas when the extra camera/state complexity is justified. Use an iframe only when independent security and release boundaries outweigh the duplicated runtime, framing-policy, session-bootstrap, focus, scrolling, and cross-window messaging costs, and validate those constraints on the real ServiceNow route.

## Established Single-File ServiceNow Hosting Pattern

In project documentation and handoffs, describe bundle delivery and runtime data access as separate channels. The Scripted REST resource may stream the property-backed HTML shell, but business data should load afterward through authenticated JSON requests. Document the session bootstrap, token lifetime, API wrapper, ACL boundary, and local-development fallback explicitly; never imply that live records or the session token are embedded in or streamed with the compiled HTML. Keep repository agent instructions operational and concise; place narrative architecture, provenance, and troubleshooting detail in the README or linked docs so it is not injected into every task. A durable README should distinguish current from planned behavior and record the product boundary, source layout, natural-key contract, stable ServiceNow artifact names, local/live differences, security model, diagnostic path, deployment proof, rollback, provenance, and any missing automated-test coverage.

1. Build the React app with Vite and `vite-plugin-singlefile` so `dist/index.html` contains the application JavaScript and CSS.
2. Store the built HTML in an owned scoped artifact such as a dedicated string property only when that deployment model is already chosen and the target supports the artifact size.
3. Return the HTML from a Scripted REST GET resource with an HTML content type.
   - Set `produces=text/html` and `produces_customized=true` on both the Scripted REST API and its HTML resource. Calling `response.setContentType('text/html')` inside the resource is not sufficient when metadata advertises only JSON: ServiceNow can reject an explicit `Accept: text/html` request with `406` before the resource script runs.
   - Send `Cache-Control: no-store, no-cache, must-revalidate, max-age=0` with compatible `Pragma: no-cache` and `Expires: 0` headers when the route serves a mutable property-backed bundle. Verify the authenticated response headers after deployment; Classic UI frames can otherwise keep executing an obsolete client even when the property itself has been updated.
   - For a versioned scoped API, verify the generated route rather than guessing it; the common shape is `/api/<scope>/v1/<service_id>/<resource>`. Smoke-test that exact URL with `Accept: text/html`.
4. Obtain a user token only from the current ServiceNow session endpoint, then send it as `X-UserToken` for same-instance data requests that must execute as the logged-in user. This includes standard Table/Aggregate reads when the app can run inside Classic UI or another frame whose implicit cookie context does not evaluate identically to direct navigation. Bootstrap the token before rendering data-dependent React components, retain it only in memory, and never persist, display, or log it. An unauthenticated caller may receive only a guest-session token, which must not grant data access.
5. Continue to enforce table/field ACLs and server-side business rules. A public application-shell route must not make data APIs public.
6. For local development, use Vite proxy configuration and credentials from an ignored `.env`. Externalize the instance URL; do not publish a personal PDI or customer URL as the reusable default.
7. If the app has client-side routes, prefer `HashRouter` unless the hosting resource explicitly implements path fallback.

For Scripted REST JSON data resources, prefer `response.setBody(payload)` and let ServiceNow serialize the object instead of manually streaming `JSON.stringify(payload)`. Keep stream writers for content that genuinely needs streaming, such as the hosted HTML shell. Validate both the HTTP status and the parsed contract from the real browser session: a `200` is not sufficient when `syslog_transaction.output_length` is abnormally short. When a client retry is appropriate, limit it to one malformed-2xx retry with cache bypass; do not retry authorization, validation, or not-found responses.

For multi-request read panels, log one correlation ID across the natural-key lookup and each aggregate stage. Keep console diagnostics structured and directly readable, but omit encoded queries, record identifiers, tokens, response bodies, and identity data. Include the same correlation ID in the user-facing error state so a screenshot can be matched to the exact failed stage and status without exposing secured content.

The single-file pattern is convenient for a demo and an established update-set-managed app. For a new long-lived source-managed custom application, evaluate the ServiceNow SDK/Fluent and Git workflow before choosing a large property-backed bundle.

## Procedural 3D Floor Plan Pattern

Prefer procedural geometry for simple workplace demos. It avoids remote model licensing, CORS, asset paths, and missing-file failures in a single-file build.

- Render the scene with `<Canvas orthographic>` for an isometric or plan-like floor. Orthographic projection keeps desk sizes consistent and reads more like a floor plan than a perspective camera.
- Build walls, floors, desks, monitors, chairs, dividers, and plants from `boxGeometry`, `cylinderGeometry`, `planeGeometry`, and other small primitives.
- Group each workstation so one record controls its entire desk, monitor, chair, hover state, selection lift, and rotation.
- Convert record coordinates through one deterministic `worldPosition()` function. Keep source coordinates human-editable, then center and scale them into scene units.
- Store layout attributes such as `x`, `y`, `width`, `height`, and `rotation` on the desk/space record. Keep `zone`, `equipment`, and active state outside the geometry contract.
- Apply the record rotation to the workstation group. For paired desks, verify chair and monitor direction visually; monitor backs should meet at the center when employees are intended to face one another.
- Use color and small elevation changes for available, reserved, current-user, hovered, and selected states. Do not rely on color alone; repeat the state in accessible text and the booking panel.

For an isometric camera, a small `CameraRig` component can update position, up vector, zoom, and `lookAt()` inside `useFrame`. Interpolate with a delta-based easing value and call `camera.updateProjectionMatrix()` after changing orthographic zoom.

Treat product zoom as a separate concept from browser/UI scaling:

```ts
camera.zoom = baseZoom * productBaselineScale * userZoom
```

This lets the control display `100%` while using a deliberately closer product baseline. Preserve enough zoom-out range to recover a complete overview on small screens.

Perform every camera-to-control conversion against the same composed baseline. Define `productBaseZoom = baseZoom * productBaselineScale`, multiply user zoom by it when driving the camera, and divide camera zoom by it after wheel or control gestures. Clamp in user-zoom space; clamping against raw `baseZoom` makes the readout drift from the actual view and can unintentionally remove the recoverable overview range.

Define the product's default user zoom once and reuse it for both initial state and the reset action. After changing that baseline, verify the visible readout on first load, change zoom in both directions, and prove reset returns to the same declared value; otherwise the camera and control can silently disagree.

Define the product's default view mode once and reuse it for both initial React state and the reset action. When changing the default projection, verify the corresponding control's `aria-pressed` state on first load, switch to the alternate projection, and prove reset restores the declared mode together with its camera orientation and user-zoom baseline.

## Geospatial Site and Campus Scenes

For an exterior campus map, preserve the provenance and uncertainty of each geometry layer instead of treating the scene as one authoritative model:

- Keep source footprints, site boundaries, roads, and vertical assumptions separate. Convert geographic coordinates through one documented local metric origin, retain stable source identifiers, and let the React selection state use those identifiers rather than array positions.
- Keep the geometry identifier separate from the ServiceNow record key when a public-source footprint ID is not the business record's portable identity. Give every selectable geometry exactly one non-empty natural key, reject duplicate keys, resolve the live `sys_id` server-side, and verify that the frontend key set and parent-table key set are an exact match before enabling record-driven interactions.
- When the UI says a building label comes from ServiceNow, treat the table display value as authoritative at runtime instead of only copying it into the bundle. Fetch only the portable key and safe display field through an ACL-protected same-origin read, merge by key into one resolved building collection used by map tags, status text, panels, and keyboard controls, and retain a descriptive static fallback for local development or read failure. Verify a fresh hosted session shows the live names on every identification surface and that obsolete placeholder labels are absent.
- For read-only capacity, occupancy, or status panels, first evaluate the standard Table API for natural-key resolution and the Aggregate API for counts and sums. Keep the response identity-free and calculate simple derived presentation values in React when they do not enforce a business invariant. Prove the intended non-admin persona can read every required table and field; do not grant a generated full-CRUD table role merely to make aggregate reads work. Use a custom Scripted REST resource only when ACL-safe standard APIs cannot express the required contract, authorization boundary, or server-side business rule. If `GlideAggregate` is justified, treat result cardinality as observable rather than assumed: multiple additive aggregates can produce grouped rows in scoped execution, so inspect `getEncodedQuery()` during diagnosis and either iterate every aggregate result row, run independent aggregates, or use a tightly bounded record loop. Compare the endpoint totals with an independent representative query before deploying; a successful `200` with plausible first-row values is not proof that the aggregate is complete.
- When demo capacity data makes every location appear uniformly over capacity, reconcile the smallest operational dataset before changing presentation rules or bulk-editing users. Preview identity-free employee counts and room-capacity sums by building natural key, verify room references remain within the same building, and prefer bounded room-capacity corrections when user records may be shared with other applications. Resolve each room by a unique natural key, retain before-values, fail on drift or duplicates, roll back a partial batch, and re-read both the changed rows and the exact frontend-derived status mix. Keep operational corrections out of update sets and preserve a deliberate mix of available, full, mildly over-capacity, and no-data states when that reflects the demo requirement.
- Model exterior roads from named public centerlines as their own context layer; do not infer them from a campus boundary or draw a decorative perimeter road. Preserve junction topology and road roles, clip only after coordinate conversion, and validate the plan-view alignment against a current public map or aerial reference before tuning the 3D camera.
- Keep pedestrian shortcuts separate from vehicle and service-road geometry. When a proprietary aerial view reveals a missing path but cannot be redistributed, snap the path endpoints to reusable public footprints or road nodes, keep the intermediate curve explicitly schematic, and record that distinction in source notes. Render walkways materially narrower and lighter than service roads, validate their topology in plan and isometric views, and do not present an inferred path as an accessible route, permitted route, or navigation instruction.
- Keep road-name labels in a deduplicated orientation layer rather than generating one label per source way. Place one restrained label per named road on a visually verified centreline segment, give destination/building labels higher visual priority, and hide or reposition edge labels at narrow breakpoints instead of accepting clipped or overlapping text. Test both the breakpoint itself and a width just above it; an off-canvas projected label can leave a visible fragment even when the narrower layout hides it cleanly.
- Distinguish surveyed or published geometry from inferred presentation geometry. If heights, roof forms, vegetation, parking, or rooftop volumes are schematic, say so in the interface and source notes; do not let visual polish imply survey, navigation, or legal-boundary accuracy.
- For sensitive or security-relevant sites, model only lawful public exterior context needed by the user. Omit interiors, access-control layouts, surveillance, utilities, restricted infrastructure, and operational detail even when procedural modeling makes them easy to invent.
- Prefer procedural/static site data over runtime map tiles, remote textures, or protected 3D services when the final app must be a self-contained ServiceNow HTML artifact. Use proprietary map or satellite imagery only as a visual calibration reference unless its license explicitly permits redistribution; derive shipped geometry from a separately reusable source, retain its stable identifiers, and record attribution and reuse constraints with the project.
- Scale an orthographic camera from the rendered viewport, not only from a desktop baseline. Prove a complete recoverable overview in both isometric and plan views at wide desktop and narrow mobile sizes; keep user zoom separate so the control can still report a meaningful `100%` product baseline.
- Match the treatment of parking and other ground landmarks to their role. An actionable destination may need distinct geometry, an accessible label, and a legend item; a legend entry does not give anonymous WebGL primitives an accessible or spatially anchored name. A contextual orientation cue should usually remain implicit through recognizable bay striping, asphalt, vegetation, or nearby public features. Validate that either treatment remains legible without obscuring buildings in isometric, plan, and mobile views.

## Interaction and Accessibility

- Use mesh `onClick`, `onPointerOver`, and `onPointerOut` handlers for direct manipulation. Clear the cursor and transient hover state during teardown.
- Keep selection in React by stable desk identifier so the 3D scene, list/filter state, and booking panel stay synchronized.
- Provide a real HTML button for every selectable mesh in a keyboard desk selector. It may be visually clipped until focused, but its accessible name must include desk name and availability.
- Provide a non-WebGL fallback and meaningful loading, empty, and error states. WebGL support is not authorization to make the booking workflow 3D-only.
- Essential state and actions must not depend on hover.
- Treat labels projected over selected or hovered meshes as spatial reinforcement, not the only identification channel. Test buildings or objects near every viewport edge; on narrow screens, suppress or reposition a clipped projected label while retaining the selected styling and name in an accessible HTML panel or list.
- Respect `prefers-reduced-motion` for panel, toast, and scene-adjacent UI transitions.

## Performance and Packaging

- Bound device pixel ratio, for example `dpr={[1, 1.6]}`, instead of rendering at an unrestricted high-DPI value.
- Prefer basic shadows, a modest shadow map, a few lights, and simple materials for an operational UI.
- Reuse geometries/material decisions through component composition and avoid loading large GLTF models unless the experience requires them.
- Use fog or background color to soften distant geometry without adding texture assets.
- Watch the final single-file bundle size. Three.js materially increases it; verify build size and the live ServiceNow response rather than assuming the property/resource path can carry it.
- Do not infer the usable bundle limit only from `sys_dictionary.max_length` for `sys_properties.value`; a target can accept a much larger property value through the supported API path. Prove support by deploying the real bundle, re-reading its character length, and comparing a hash of the authenticated live HTML response with `dist/index.html`.
- If a target demonstrably cannot carry one bundle property, multiple properties can be concatenated server-side, but deploy them as immutable versioned chunks plus a small active-manifest property—not as one mutable numbered set. Write every chunk under the new version, verify declared count, total length, order, and final hash, then atomically switch the manifest; make the resource fail closed on a missing or mismatched chunk and retain the previous manifest/version for rollback. Prefer one proven property while it works because chunking multiplies application files, update-set records, cache entries, partial-deployment states, and cross-instance validation work.
- Distinguish a benign library deprecation warning from an application error, but do not ship unresolved runtime errors.

## Data Model for Desk Booking Demos

A compact model is sufficient:

- **Desk/space:** stable desk ID, display name, active, zone, equipment, `x`, `y`, `width`, `height`, and `rotation`.
- **Booking:** booking date, desk reference, booked-for user, optional notes/status, and created metadata.
- **Room:** optional when the experience includes rooms; do not retain room geometry merely to fill the canvas.

Seed data idempotently by a stable desk ID. Reconcile existing rows, deactivate known surplus demo desks rather than deleting them, and keep operational bookings out of update sets. Enforce one booking per desk/day and any user/day rule server-side.

When existing demo parent records already have child or user references, reconcile them in place by a unique natural key: rename matching parents without changing their `sys_id`, insert only missing keys, and report surplus parents for explicit review instead of automatically deleting them. Validate exact parent-key uniqueness, expected totals, reference counts, and zero orphan children after every run; transport the repeatable reconciliation procedure separately because operational demo rows do not belong in an update set.

## Validation Checklist

1. Run lint, TypeScript build, production build, and a dependency audit appropriate to the project.
2. Validate the rendered app locally at desktop, tablet, and mobile sizes with no horizontal overflow.
3. Test 3D selection, keyboard selection, filters/search, plan/isometric toggle, zoom bounds, booking, cancellation, loading, empty, and error behavior.
4. Test wide embedded ServiceNow layouts; an orthographic scene that looks correct locally can appear too small in a very wide UI16 frame. Tune product camera zoom, not browser zoom, for the scene.
5. Verify booking-panel typography and scrolling separately from the scene. A readable desktop panel may require vertical scrolling on mobile, but must not introduce horizontal scrolling.
6. Build the final single file and compare the authenticated live application response with `dist/index.html` exactly after deployment.
7. Re-read the property/resource, confirm the intended scope/package, and verify the update set contains only the expected application artifact types.
8. Restore developer preferences and remove transient snapshots after deployment.

## Rollback

Keep the previous built HTML hash or artifact and the source commit that produced it. Roll back by rebuilding/redeploying the prior source revision or applying a narrow follow-up configuration update; restoring the UI bundle does not reverse booking data created while it was active.
