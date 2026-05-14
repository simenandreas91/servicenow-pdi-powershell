# SN Pro Tips Reference Notes

Use this as a secondary, community-source reference when ServiceNow development work touches performance, debugging, GlideRecord, ACLs, query Business Rules, client scripts, update sets, Service Portal/catalog, notifications, or practical admin utilities.

Research baseline: `https://snprotips.com/` reviewed 2026-05-14. SN Pro Tips is valuable and practical, but it is not official ServiceNow documentation. Treat its articles and tools as field-tested patterns to validate against the target release, official docs, and the actual instance before installing or copying code.

## High-Value Themes

- **Performance hygiene**: scan custom scripts for inefficient GlideRecord patterns, synchronous client calls, repeated REST/Flow overhead, broad row-counting, and unnecessary per-record loops.
- **Security/debugging hygiene**: look for hidden executing scripts in ACLs/Business Rules, query Business Rules that silently hide records, plain-text auth headers, and tracked configuration files containing secrets.
- **Developer ergonomics**: the site has useful update-set utilities, Chrome/search helpers, docs-version redirects, catalog preview shortcuts, and script snippets. Prefer learning the pattern before importing any update set.
- **Service Portal/catalog pragmatism**: many older articles solve real portal/catalog limitations. Re-check against the current family because Service Portal behavior and supported APIs changed over time.

## Patterns Worth Remembering

### GlideRecord And Server-Side Code

- For single-record queries where code only uses `if (gr.next())`, add `gr.setLimit(1)` before `query()` unless the query is already constrained by `get()` or another exact-key API.
- Prefer `GlideAggregate` for count-only logic instead of loading rows with `GlideRecord.getRowCount()`.
- For identical bulk field changes across many records, consider `updateMultiple()` instead of looping and calling `update()` on every row. Use `setValue()` before `updateMultiple()` and constrain the query carefully.
- Prefer `getValue()` and `setValue()` for GlideRecord fields to avoid GlideElement/pass-by-reference surprises. Use `toString()` when dot-walking or reading variables where `getValue()` is not suitable. Do not use `setValue()` for journal fields such as work notes/comments because ServiceNow has special handlers there.
- Keep Script Include functions explicit about their inputs. Do not rely on ambient `current` or parent/calling scope; pass the GlideRecord or primitive values into the method.

### Business Rules, ACLs, And Query Rules

- Avoid `current.update()` in Business Rules. Use before rules for changing the current record, after rules for related visible records, and async rules/events/flows for peripheral work.
- Do not use `setWorkflow(false)` as a general recursion fix. It suppresses other automation that may be required. For journal/field synchronization, prefer an explicit loop-prevention strategy that does not disable workflow.
- Advanced ACLs and Business Rules can retain hidden scripts after the Advanced checkbox is unchecked. Check for `advanced=false^scriptISNOTEMPTY` on ACLs and equivalent hidden-script cases on Business Rules when debugging unexpected security, behavior, or performance.
- Query Business Rules are not a replacement for ACLs. Use them cautiously, often for performance/filtering, and document the reason because they silently remove records without the normal ACL “removed by security” clue.
- Negative query logic such as “is not”, “not in”, `!=`, “same as”, or “different from” can exclude blank values. If blank values should remain visible, add an explicit OR condition for NULL/empty values.

### Client Scripts And Portal/Catalog

- Client-side GlideAjax, GlideRecord, and `getReference()` calls should be asynchronous. Synchronous client-server calls degrade UX and are blocked in some portal contexts.
- For onSubmit validation that requires server data, use an async validation pattern that initially returns false, stores validation state in client data, and resubmits only after the callback succeeds. Avoid hidden variable workarounds unless they are intentionally part of the design.
- For client-side debugging, `debugger;` can be used as an explicit browser breakpoint in Client Scripts, Catalog Client Scripts, UI Policy scripts, UI Scripts, and Service Portal client code.
- Service Portal catalog scripts may require UI Type `Mobile / Service Portal` or `All`; Desktop-only catalog client scripts will not run in the portal.
- Avoid DOM manipulation in portal/catalog unless there is no supported API path. If using one of SN Pro Tips’ older DOM-enabling patterns, verify against the current portal/Employee Center architecture first.

### Integrations And REST

- For high-frequency or button-triggered REST calls, benchmark Flow Designer REST steps against a server-side Script Include using `sn_ws.RESTMessageV2`. SN Pro Tips published a Yokohama benchmark where a scripted RESTMessage path was materially faster than invoking a Flow action.
- Still choose Flow Designer when business maintainability, visibility, retries, approvals, or low-code ownership matter more than raw latency. Use Script Includes when performance, testing, reusability, and exact REST control are the drivers.
- Do not store bearer/basic auth values as plain-text REST message headers. Use auth profiles, credential aliases, OAuth profiles, or supported secure credential storage.

### Utilities To Remember

Useful SN Pro Tips tools/pages to revisit before building from scratch:
- Dangerous-code scan ideas: hidden ACL/BR scripts, query BR filters, tracked config secrets, sync client calls, `current.update()`, plain-text auth headers, `getRowCount()`.
- Inefficient single-record query scanner: finds scripts using `if (gr.next())` without `setLimit(1)`.
- Detect Duplicates: single/multi-field duplicate detection patterns.
- Include in Update Set / Update Relocator / Update Set Collision Avoidance: update-set hygiene and collision support.
- Paginated GlideRecord Utility: page through large result sets deliberately.
- Advanced Attachment Copy Util and Journal Redactor: attachment/journal support patterns.
- Temporary Permissions Utility: temporary role/group membership with expiration.
- Get RITM Variables via SRAPI: JSON access to populated request item variables.
- Try Catalog Item in Portal and Set Catalog Variables from URL: catalog development/testing helpers.
- Get Latest Docs Page Version: ServiceNow Docs version redirect helper.

## How To Use This Reference

1. Start with platform-supported OOTB behavior and official ServiceNow docs.
2. Use SN Pro Tips to identify practical failure modes, scan queries, or established implementation patterns.
3. Prefer reading the article and adapting the principle over importing update sets into client/dev instances.
4. If importing an SN Pro Tips tool, inspect all update XML first, install only in a sandbox/dev instance, and verify update-set capture, scopes, ACLs, and scheduled jobs before reuse.
5. For Vår Energi, use "Simen" if a demo record or marker needs a human-facing name.

## Source Pages Reviewed

- SN Pro Tips homepage and tool index: https://snprotips.com/ and https://snprotips.com/tools
- Dangerous code checks: https://snprotips.com/blog/2025/3-ways-to-check-your-servicenow-instance-for-dangerous-code-in-less-than-5-minut
- Inefficient single-record queries: https://snprotips.com/blog/2025/find-filthy-inefficient-single-record-queries-fast
- Flow Designer vs scripted REST performance: https://snprotips.com/blog/2026/flow-designer-vs-scripting-rest-message-performance
- Bi-directional journal sync: https://snprotips.com/blog/2026/bi-directional-journal-entry-sync-without-infinite-loops-for-comments-or-work-no
- Script Includes and `current`: https://snprotips.com/blog/2019/can-script-includes-use-the-current-variable
- Hidden ACL/Business Rule scripts: https://snprotips.com/blog/2023/4/28/your-servicenow-acls-are-broken
- Query Business Rules and negative query logic: https://snprotips.com/blog/2018/9/18/broken-queries-and-query-rules
- `updateMultiple()` efficiency: https://snprotips.com/blog/2016/12/20/pro-tip-use-updatemultiple-for-maximum-efficiency
- Asynchronous onSubmit client/catalog scripts: https://snprotips.com/blog/2018/10/19/synchronous-lite-onsubmit-catalogclient-scripts
- `getValue()` / `setValue()` / pass-by-reference: https://snprotips.com/blog/2017/4/9/always-use-getters-and-setters
