# Debugging Visibility and ACLs

When a user cannot see a record, field, related item, portal result, or other secured content, separate "data exists" from "security hides it" before changing anything.

1. Identify the exact user, table, record `sys_id`, field if relevant, operation, and entry point such as form, list, portal widget, related list, reference picker, report, or API.
2. Confirm the record and target fields exist with a narrow admin Table API read.
3. Reproduce as the affected user when possible. In UI, impersonate the user and enable Debug Security Rules.
4. Inspect relevant ACLs in `sys_security_acl`: table ACLs, field ACLs, parent table ACLs, and wildcard patterns such as `*.none` or `*.field`.
5. Use read-only Xplore/background snippets only when ACL behavior must be evaluated through ServiceNow APIs. Prefer `GlideRecordSecure`; plain `GlideRecord` can bypass ACL behavior in server code.

Read-only ACL check:

```powershell
$script = @'
(function () {
  var result = {};
  var table = 'incident';
  var recordSysId = '<record_sys_id>';
  var fieldName = 'short_description';

  var gr = new GlideRecordSecure(table);
  if (!gr.get(recordSysId)) {
    result.recordVisible = false;
    result.reason = 'Record not returned by GlideRecordSecure';
  } else {
    result.recordVisible = true;
    result.recordCanRead = gr.canRead();
    result.fieldCanRead = gr.getElement(fieldName).canRead();
    result.display = gr.getDisplayValue();
  }

  gs.print('CODEX_RESULT_START' + JSON.stringify(result) + 'CODEX_RESULT_END');
})();
'@

& "$HOME/.codex/skills/servicenow-pdi/scripts/Invoke-ServiceNowXploreScript.ps1" -Script $script
```

Interpretation:
- Record missing through `GlideRecordSecure`: investigate table/record ACLs, before-query business rules, domain separation, or query constraints.
- Record visible but field unreadable: investigate field ACLs.
- ACLs pass but UI hides content: inspect UI policies, client scripts, form sections/views, portal widget logic, related list conditions, reference qualifiers, reports, or encoded queries.

## Restricted Caller Access

Use this quick path when a portal, workspace, script, widget, or scoped app logs an error like `must declare a Restricted Caller Access privilege`.

1. Parse the message: note the operation (`read`, `write`, `create`, `delete`, `execute`), denied table or API, caller/source application scope, and application that must declare the privilege.
2. Resolve the caller and target applications in `sys_scope`, and resolve table targets in `sys_db_object`.
3. Inspect `sys_restricted_caller_access` for an existing row before creating another one. Prefer the narrowest record that fixes the exact runtime error.
4. For a scope-to-table grant, create the row with Table API; scoped `GlideRecord.insert()` can silently return no sys_id for this table:

```json
{
  "source_scope": "<caller_sys_scope_sys_id>",
  "source_type": "5",
  "source": "",
  "source_table": "",
  "target_scope": "<declaring_app_sys_scope_sys_id>",
  "target_type": "1",
  "target_table": "sys_db_object",
  "target": "<target_sys_db_object_sys_id>",
  "operation": "read",
  "status": "2",
  "rca_type": "real_rca",
  "description": "Allow <caller app> to <operation> <target> for <runtime need>."
}
```

Choice values commonly needed:
- `source_type=5`: Scope; leave `source` and `source_table` blank for scope-level grants.
- `source_type=2`: Script Include; set `source_table=sys_script_include` and `source=<script include sys_id>`.
- `source_type=6`: Service Portal Widget; set `source_table=sp_widget` and `source=<widget sys_id>`.
- `source_type=10`: GlideScopedEvaluator; set the source fields to the exact calling artifact when known.
- `target_type=1`: Table; set `target_table=sys_db_object` and `target=<sys_db_object.sys_id>`.
- `status=2`: Allowed.

Verification:
- Test from the caller scope where possible, for example with Xplore scoped to the caller application and a minimal `GlideRecord`/API operation against the denied target.
- Confirm the row is captured in the intended scoped update set. If it is valid runtime data but does not auto-capture, switch current update set to the intended scope and save it from Global with `GlideUpdateManager2().saveRecord(gr)`.
- Avoid broad scope-to-scope RCA rows unless the runtime error and source artifact require them; prefer table-specific or source-specific grants.
