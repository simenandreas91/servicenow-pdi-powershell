# ServiceNow Instance Index

Use for repeated broad discovery or dependency analysis. For a known artifact, use a narrow live read.

## Contents and limits

The builder writes `metadata.json`, `tables.json`, `fields.json`, `choices.json`, `artifacts.json`, `symbols.json`, and `edges.json` under the chosen output folder. They describe table/dictionary metadata, configured artifact types, names, and metadata relationships.

- This is a local snapshot. Re-resolve edit targets live; refresh affected discovery after changes.
- The artifact list is not exhaustive. Impact edges such as `runs_on`, `references`, `notifies`, `triggers`, and `secures` do not capture every dynamic script call.
- Keep generated files out of Git. Exclude credentials, auth/session data, and unnecessary sensitive content. Fetch script bodies only for targeted analysis.
- Broad scans of production-like instances require explicit approval. Prefer a scope filter.
- No semantic-search or embedding dependency is required. Use `rg` and the bundled helpers first. Any external processing of ServiceNow-derived content requires explicit task-level approval.

## Build

Resolve the skill directory and approved environment first:

```powershell
$build = @{
  Profile = '<approved-profile>'
  EnvPath = '<approved-env-path>'
  Scope = '<resolved-scope-name>'
  Artifacts = $true
  OutputPath = '.servicenow-index'
}
& (Join-Path '<skill-root>' 'scripts/Build-ServiceNowInstanceIndex.ps1') @build
```

| Option | Purpose |
| --- | --- |
| `-TablesOnly` | Only `sys_db_object`; fastest table-name lookup |
| `-Scope` | Restrict to one application |
| `-Artifacts` | Include configured artifact tables, e.g. scripts, ACLs, notifications, widgets |
| `-IncludeBodies` | Add script/template/condition fields; increases size and sensitivity |
| `-OutputPath` | Choose local index directory |
| `-PageSize` | Default 500 |
| `-MaxPagesPerTable` | Default 1000; a budget error means incomplete coverage |

Pagination follows server next-page metadata through ACL-filtered short/empty pages, with a `sys_id` ordering tie-breaker. Concurrent changes can still affect offset traversal. Inspect artifact-table errors before treating coverage as complete.

## Search and impact

```powershell
$search = @{ Text = 'holiday approval'; IndexPath = '.servicenow-index'; Limit = 25 }
& (Join-Path '<skill-root>' 'scripts/Find-ServiceNowIndexedArtifact.ps1') @search
$impact = @{ Key = 'sysapproval_approver'; IndexPath = '.servicenow-index' }
& (Join-Path '<skill-root>' 'scripts/Get-ServiceNowIndexedImpact.ps1') @impact
```

Inspect incoming/outgoing relationships for the small candidate set, then retrieve current records and relevant bodies live. For richer graph design, read `servicenow-graph-mapping.md`.
