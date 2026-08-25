# ServiceNow React and 3D Frontends

Use this reference for a bespoke React/Vite application hosted by ServiceNow, especially an interactive WebGL experience, 3D floor plan, map, configurator, or digital-twin-style demo. Do not use it to bypass an adequate native ServiceNow product. For workplace mapping and enterprise reservations, evaluate licensed Workplace Service Delivery Indoor Mapping before proposing a custom replacement.

The maintained reference implementation is `https://github.com/simenandreas91/servicenow-3d-desk-booking`. It evolves Andrew Pishchulin/ELIN Software's `https://github.com/elinsoftware/servicenow-react-app` boilerplate and preserves its MIT notice and repository history. Treat the ELIN project as the source for the ServiceNow-hosted React approach and the maintained desk-booking project as the working reference for the added Three.js scene, interaction, and responsive product UI.

## Proven Stack

- **React** and **React DOM** for application state, panels, filters, booking flows, loading/error states, and accessibility markup.
- **TypeScript** for the ServiceNow record contracts and scene component props.
- **Vite** for fast local development and production bundling.
- **vite-plugin-singlefile** to inline JavaScript and CSS into one `dist/index.html` that ServiceNow can serve without a separate static-asset pipeline.
- **Three.js** for cameras, vectors, materials, geometry, lighting, fog, projection updates, and WebGL rendering.
- **@react-three/fiber** for declarative Three.js scenes in React through `Canvas`, `useFrame`, mesh event handlers, and normal component composition.
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

When one spatial baseline will seed multiple products, tag a stable map-only revision and give each product its own repository or source boundary, ServiceNow scope, roles, data APIs, hosted bundle property, route, update set, and release lifecycle. Preserve portable geometry identifiers across the copies, but keep business adapters and sensitive data contracts product-specific. A copied deployment helper should fail closed until its new scope, property, and route are configured; transfer later map-only commits explicitly, and extract a shared package only after repeated synchronization work justifies the added release coupling.

## Single-File ServiceNow Hosting Pattern

1. Build the React app with Vite and `vite-plugin-singlefile` so `dist/index.html` contains the application JavaScript and CSS.
2. Store the built HTML in an owned scoped artifact such as a dedicated string property only when that deployment model is already chosen and the target supports the artifact size.
3. Return the HTML from a Scripted REST GET resource with an HTML content type.
   - Set `produces=text/html` and `produces_customized=true` on both the Scripted REST API and its HTML resource. Calling `response.setContentType('text/html')` inside the resource is not sufficient when metadata advertises only JSON: ServiceNow can reject an explicit `Accept: text/html` request with `406` before the resource script runs.
   - For a versioned scoped API, verify the generated route rather than guessing it; the common shape is `/api/<scope>/v1/<service_id>/<resource>`. Smoke-test that exact URL with `Accept: text/html`.
4. Obtain a user token only from an authenticated ServiceNow session endpoint, then send it as `X-UserToken` for same-instance API mutations. Never persist or log the token.
5. Continue to enforce table/field ACLs and server-side business rules. A public application-shell route must not make data APIs public.
6. For local development, use Vite proxy configuration and credentials from an ignored `.env`. Externalize the instance URL; do not publish a personal PDI or customer URL as the reusable default.
7. If the app has client-side routes, prefer `HashRouter` unless the hosting resource explicitly implements path fallback.

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

## Geospatial Site and Campus Scenes

For an exterior campus map, preserve the provenance and uncertainty of each geometry layer instead of treating the scene as one authoritative model:

- Keep source footprints, site boundaries, roads, and vertical assumptions separate. Convert geographic coordinates through one documented local metric origin, retain stable source identifiers, and let the React selection state use those identifiers rather than array positions.
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
