# FFI EBA FDV Foundation

Load this reference for FFI FDV work in the EBA application, including Workspace setup, the 3D building explorer, foundation-table changes, and later migration from the existing Kjeller prototype.

## Source-of-truth boundary

The existing Kjeller map prototype is coupled to Global `u_bygg` and `u_rom_nummer` records and to the earlier EBA floor/layout/desk/booking tables. Treat that model as a prototype integration surface, not as the canonical FDV domain model.

The FDV source of truth belongs in the existing EBA scope and uses the `fdv_` namespace. Do not repurpose or delete the prototype tables as part of ordinary FDV work. Migrate or adapt them only through a separately approved, reconciled change so the current frontend is not broken.

Keep the FDV tables package-private while the Workspace, data resources, and custom components are all in EBA. If a consumer must live in another scope, design and validate the cross-scope/application-access contract explicitly instead of broadly opening every table.

## Foundation model

The MVP foundation consists of six EBA tables:

| Table | Purpose | Parent/reference |
|---|---|---|
| `x_1122545_eba_fdv_location` | Site or campus | — |
| `x_1122545_eba_fdv_building` | Building | mandatory location |
| `x_1122545_eba_fdv_floor` | Storey/floor | mandatory building |
| `x_1122545_eba_fdv_room` | Space/room | mandatory floor |
| `x_1122545_eba_fdv_asset_type` | Reusable technical-equipment classification | — |
| `x_1122545_eba_fdv_asset` | Installed technical asset | mandatory type and building; optional floor and room |

Each hierarchy/classification table has a unique stable code, a mandatory display name, an active flag, and a description. Technical assets use a unique asset ID and also carry status, criticality, manufacturer, model, serial number, responsible group, and placement references.

Use stable codes/asset IDs for integrations and reconciliation. Use `sys_id` only for live references and client state; never encode display labels as reference values. When adding placement validation, enforce that an asset's selected floor belongs to its building and that its room belongs to its floor.

The initial choice sets are deliberately small:

- Room types: office, meeting room, laboratory, workshop, technical room, storage, common area, other.
- Asset categories: HVAC, electrical, plumbing, fire safety, building systems, ICT, furniture, other.
- Asset statuses: planned, in service, out of service, inactive.
- Criticality: 1 critical through 4 low.

Refine these values with FFI before treating them as controlled enterprise taxonomies.

## MVP boundary

The foundation deliberately excludes maintenance plans, work orders, service history, contracts, warranties, lifecycle events, dashboards, and Platform Analytics artifacts. Add those as later domain increments after the location/asset model and user workflows have been exercised. Avoid creating empty lifecycle tables merely to anticipate the full product.

Keep foundation configuration separate from operational data. Do not transport locations, buildings, rooms, or assets in an update set. Use an approved import/seed process with deterministic business keys and reconciliation when sample or real data is requested.

Before seeding, read the live `sys_choice.value` entries instead of deriving internal values from their labels. In the current foundation schema, examples include room type `technical` and asset category `building`; label-like guesses such as `technical_room` or `building_systems` are invalid. An FDV seed should be idempotent by `u_code`/`u_asset_id`, resolve parent records to live `sys_id` values, avoid overwriting existing matches, and reconcile exact counts, duplicate keys, empty mandatory references, and asset building/floor/room consistency after insertion.

## Access model

Use the existing EBA role hierarchy:

- `x_1122545_eba.user`: read FDV foundation records.
- `x_1122545_eba.fdv_manager`: contains the user role; create and update foundation records.
- `x_1122545_eba.admin`: contains the manager role; retains delete and application administration access.

Generated table ACLs retain the EBA admin role. Add the user role only to read and the manager role only to create/write. Validate the exact ACL-role links after transport; do not rely on platform-admin bypass as proof that Workspace users can operate the model.

## Workspace and 3D component readiness

Every table exposed during Workspace creation needs a usable Default form view with its important fields and references. Confirm the form sections and elements are captured in the EBA delivery vehicle; ServiceNow can record `sys_ui_element` update XML as Global even when the section belongs to EBA, so reconcile the update-set application before handoff.

Build Workspace navigation and record pages around the canonical hierarchy. The Three.js component should receive bounded, server-authorized data through UI Builder properties/data resources, emit selection/navigation events, and use record `sys_id` values to open the standard Workspace record route or tab. Keep rendering state separate from record ownership so the 3D scene can evolve without changing the FDV schema.

Before creating the Workspace, re-query the live scope and tables, confirm the six Default views are present, and select these tables in the Workspace table step. Do not create duplicate tables if the picker appears stale; refresh the authoring session and verify scope/application context first.

UI Builder can retain the scoped update-set context that was active when its browser session loaded. After switching `sys_update_set` and `updateSetForScope<scope_sys_id>`, reload or reopen UI Builder, save one small intended artifact, and confirm its `sys_update_xml.update_set` before continuing. If the first artifact lands in the previous set, stop and reopen the authoring session; do not assume the current preference records prove the builder is using them.

Workspace side navigation and the workspace homepage are separate settings. `chrome_toolbar` controls the visible navigation entries and their order, while `sys_ux_app_config.landing_path` controls the route opened from the workspace root. Verify both when promoting an FDV page to the homepage; placing the route first in side navigation does not change a remaining `landing_path=home`.
