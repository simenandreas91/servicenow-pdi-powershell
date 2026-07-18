# ServiceNow UI Design

Use this reference for visual design, CSS, layout, typography, imagery, responsive behavior, motion, or interaction work in Service Portal, Employee Center, Workspace, UI Builder, dashboards, and ServiceNow-hosted custom frontends.

## Precedence

Use this order when design rules conflict:

1. accessibility, security, user task, and platform constraints;
2. the customer's approved design system and content guidance;
3. the active ServiceNow theme, Now Design System, and existing OOTB component behavior;
4. established patterns on the surrounding page or application;
5. creative direction from a general frontend skill such as `gpt-taste`.

Do not make a ServiceNow surface look novel at the cost of clarity, upgradeability, performance, or consistency.

## Classify the Surface

- **Transactional:** forms, approvals, cases, catalog items, task lists, workspaces, operational dashboards. Optimize for scanning, density, predictability, fast completion, and clear system state.
- **Discovery or landing:** portal homepages, Employee Center landing pages, service/category navigation, campaign hubs. Stronger editorial hierarchy, imagery, and section composition can help, but navigation and findability remain primary.
- **Campaign or bespoke frontend:** an explicitly branded microsite, source-based application, or custom SPA. AIDA or richer motion may be useful when it matches the user journey and is requested.
- **Embedded component:** a widget, modal, card, or macroponent inside an existing page. Blend with its host; do not impose a new page-level visual system from inside one component.

## Useful Principles Adapted from `gpt-taste`

### Hierarchy and Typography

- Give important headings enough width to avoid awkward multi-line towers. On landing-page heroes, aim for roughly two or three lines at the primary desktop breakpoint; use a smaller responsive size before forcing a narrow column.
- Keep transactional headings concise and subordinate to task content. Do not apply cinematic hero typography to forms, lists, or approvals.
- Use headings for semantic hierarchy, not decoration. Remove labels such as `SECTION 01`, arbitrary stamps, and pill tags unless they convey real status or navigation.
- Reuse approved type families, weights, and line heights from the active theme. Never introduce a font merely because a general design skill prefers it.

### Layout and Spacing

- Use a consistent spacing rhythm derived from existing theme tokens. Increase separation between conceptual sections, but fix accidental container, row, column, or widget margins before adding large padding.
- Plan grids mathematically. Confirm that column spans, row spans, and responsive breakpoints leave no accidental dead cells or clipped content. Intentional negative space is allowed; unexplained holes are not.
- Prefer three to five purposeful navigation or content cards over a large repetitive card wall. A card must group related content or provide a clear action.
- Prevent horizontal overflow at every supported breakpoint. Scope overflow fixes to the responsible component; do not hide page-wide overflow to conceal broken layout or inaccessible off-screen content.

### Actions and Imagery

- Give every action a readable label, sufficient contrast, visible focus, and clear default, hover, active, disabled, loading, and error behavior where applicable.
- Do not rely on hover for essential information or action because portal experiences must work with touch, keyboard, and assistive technology.
- Use approved customer imagery, icons, or platform assets. Do not ship placeholder services such as Picsum, arbitrary remote stock images, or unlicensed assets.
- Keep imagery relevant to the task and optimize dimensions, format, loading, and alternative text. Decorative images should not add noisy announcements to screen readers.

### Motion

- Use motion to explain a transition, relationship, progress state, or direct manipulation. Static interfaces are acceptable and usually preferable for routine platform work.
- Prefer small CSS transitions or platform-native behavior for ordinary widgets. Add GSAP only for an explicitly motion-led custom experience with an approved dependency and delivery model.
- Support `prefers-reduced-motion`, keyboard operation, touch input, interrupted navigation, and component teardown. Avoid scroll-jacking, mandatory pinned sections, continuous marquees, and animations that delay task completion.
- Test performance on realistic portal pages where several widgets and client frameworks execute together.

## ServiceNow Implementation Rules

- Inspect the rendered DOM, active `sp_theme`, CSS variables, CSS includes, page/container/row/column hierarchy, widget instance options, and component scope before changing styles.
- Prefer instance options, theme variables, scoped component styles, and supported OOTB composition before cloning widgets or overriding broad selectors.
- Service Portal uses its own AngularJS and Bootstrap-era runtime. Do not paste React, Tailwind, or GSAP examples from a generic design skill into widget fields without adapting them to the actual runtime and packaging model.
- Scope widget CSS beneath a stable wrapper owned by the widget. Avoid bare element selectors, fragile generated classes, blanket `!important`, and document-level event handlers.
- Preserve localization. Keep user-facing strings translatable and test longer translated text rather than designing only for short English labels.
- Separate design tokens from one-off component rules. For Vår Energi work, also load `references/vaar-energi-design.md`; for portal implementation details, load `references/lessons-portal.md`.

## Rendered Validation

Before editing, capture a baseline screenshot and identify the exact component boundaries. After editing, verify:

- the intended desktop, tablet, and mobile widths;
- typical, longest realistic, empty, loading, permission-denied, and error content;
- keyboard traversal, focus visibility, touch behavior, and no hover-only dependency;
- text zoom/expansion, heading wrapping, contrast, alternative text, landmarks, and accessible names;
- no unintended horizontal scroll, clipping, overlap, layout shift, or excessive page length;
- surrounding OOTB widgets, shared themes, headers, footers, modals, and reused widget instances remain unchanged;
- the intended non-admin persona can complete the task and an unauthorized persona cannot expose protected data;
- record readback, update-set or source capture, cache refresh where needed, and behavior-level evidence are complete.

Use the in-app browser for visual proof. API record verification alone cannot establish layout, responsive behavior, accessibility, or interaction quality.

## Official Sources

- ServiceNow widget development guidelines: https://www.servicenow.com/docs/r/platform-user-interface/service-portal/general-guidelines-developing-widgets.html
- Using Service Portal widgets: https://www.servicenow.com/docs/r/platform-user-interface/service-portal/service-portal-widgets.html
- Creating portal pages: https://www.servicenow.com/docs/r/platform-user-interface/service-portal/c_Pages.html
- Defining portal styles: https://www.servicenow.com/docs/r/platform-user-interface/service-portal/portal-css.html
- Widget API reference, including accessibility utilities: https://www.servicenow.com/docs/r/platform-user-interface/service-portal/widget-api-reference.html
