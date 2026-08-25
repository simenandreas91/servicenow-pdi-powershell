# FFI Besøksregistrering Lessons

Use this for work on FFI's Besøksregistrering application in Simen's PDI mirror.

## Stable Application Context

- Application scope: `x_1122545_bes_ks_0`.
- Visit table: `x_1122545_bes_ks_0_visit`.
- Visitor-card table: `x_1122545_bes_ks_0_visitor_card`.
- Both tables reference `cmn_location` through `location`.
- Employee registration uses the Vår Energi Employee Center portal at `/esc`; do not route it to a Service Catalog portal.
- The reception/security experience uses the Besøksregistrering workspace and its Platform Analytics dashboard.

## Location And Demo-Data Rules

- FFI's two main locations are **Kjeller** and **Horten**. Demo data and dashboard examples must use only those locations unless the user explicitly introduces another real site. Do not invent an Oslo location.
- Before removing a demo `cmn_location`, resolve it live by exact name, enumerate every referencing visit and visitor-card record, and capture their stable business keys and current values.
- Reassign the exact dependent records to the approved surviving location first. Re-read every changed record, require zero remaining app references to the obsolete location, and only then delete the exact location requested by the user.
- After deletion, verify that the obsolete location returns no record, that Kjeller and Horten remain, and that table-backed dashboard visualizations still have valid location references. Demo-data changes are operational data changes, not update-set content.
