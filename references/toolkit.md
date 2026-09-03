# ServiceNow Helper Router

Use these PowerShell helpers for deterministic, low-noise ServiceNow work. Resolve every script relative to the directory containing `SKILL.md`; do not assume a fixed installation path.

Before guessing parameters, inspect the installed script:

```powershell
$script = Join-Path '<skill-root>' 'scripts/Get-ServiceNowTableShape.ps1'
Get-Command $script -Syntax
```

Most live-instance helpers accept `-Profile`, `-EnvPath`, and `-Instance`. Read `environment-routing.md` before selecting them. Discovery helpers commonly accept `-CachePath`, `-CacheTtlMinutes`, `-Refresh`, and `-NoCache`. Cache exploratory reads; use `-NoCache` after writes.

## Capability Map

### Connection and exact execution

| Helper | Use | State |
| --- | --- | --- |
| `Resolve-ServiceNowConnection.ps1` | Dot-source shared profile/env resolution; fail closed on missing named targets | Local/read |
| `Invoke-ServiceNowTable.ps1` | Exact Table API GET/POST/PATCH/DELETE with fields, limits, display mode, and debug header | Read or write by method |
| `Invoke-ServiceNowXploreScript.ps1` | Scoped server execution with structured output; preferred runtime probe | Depends on submitted script |
| `Invoke-ServiceNowBackgroundScript.ps1` | Background Script fallback when Xplore is unavailable or comparison is required | Depends on submitted script |

Default to Table API GET. Use Xplore when server semantics or API-blocked metadata must be observed. Background Script is last choice. Treat both execution helpers as admin capability even when the submitted code is read-only.

### Discovery, schema, and impact

| Helper | Use | State |
| --- | --- | --- |
| `Get-ServiceNowPdiHealth.ps1` | Build/user/scope/update-set/Xplore/Table API preflight | Read |
| `Get-ServiceNowScopeInventory.ps1` | Cached common-artifact inventory for one scope | Read |
| `Find-ServiceNowArtifact.ps1` | Targeted live search by name; optional body search | Read |
| `Get-ServiceNowTableShape.ps1` | Table metadata, dictionary, optional choices and ACL summary | Read |
| `Export-ServiceNowDelta.ps1` | Changed artifacts in one scope since a timestamp | Read/local file |
| `Build-ServiceNowInstanceIndex.ps1` | Reusable table/artifact index for broad discovery | Read/local files |
| `Find-ServiceNowIndexedArtifact.ps1` | Fast offline search of an existing index | Local/read |
| `Get-ServiceNowIndexedImpact.ps1` | Offline incoming/outgoing impact from index edges | Local/read |

Use live exact search for one artifact. Build an index only when repeated broad discovery justifies its cost. Verify every index-derived edit target live.

### Update-set lifecycle

| Helper | Use | State |
| --- | --- | --- |
| `Set-ServiceNowUpdateSetContext.ps1` | Create/select scoped update set and snapshot developer preferences | Controlled write |
| `Restore-ServiceNowPreferenceSnapshot.ps1` | Restore saved application/update-set preferences | Controlled write |
| `Confirm-ServiceNowUpdateCapture.ps1` | Check expected update XML names/application | Read |
| `Get-ServiceNowUpdateSetSummary.ps1` | Contents, types, scope mixing, and likely noise | Read |
| `Save-ServiceNowCustomerUpdate.ps1` | Force capture of one legitimate application file after diagnosing missed natural capture | Controlled write |
| `Export-ServiceNowUpdateSetXml.ps1` | Export one update set; `-Complete` also changes its state | Local file; conditional write |
| `Remove-ServiceNowArtifactWithDeleteCapture.ps1` | Snapshot, delete, and create deployable DELETE capture for one proven customer artifact | Destructive write |

Never use a write helper merely because it is convenient. The SKILL write gate, exact stable-key resolution, before-value capture, and post-write readback still apply. `Save-ServiceNowCustomerUpdate.ps1` does not repair a wrong scope/context. The delete helper requires explicit deletion authority and target preview planning.

### Focused workflows

| Helper | Use | State |
| --- | --- | --- |
| `Test-ServiceNowNotification.ps1` | Inspect event/notification/email evidence; `-Trigger` queues an event | Read; conditional write |
| `Get-ServiceNowCompendiaSyncStatus.ps1` | Compact Compendia configuration/sync health | Read |
| `Initialize-ServiceNowAndrewReactApp.ps1` | Configure the maintained React/Vite boilerplate for a confirmed non-production instance; `-Install` installs dependencies | Local write; optional install |
| `Manage-VaarEnergiStoryMonitor.ps1` | Maintain local assigned-story approval/monitor state | Local state write |
| `Manage-VaarEnergiStoryWorkLog.ps1` | Maintain local Vår story work log/report state | Local state write |

Load the matching domain/customer reference before these focused helpers. Their presence does not authorize a trigger, install, external call, or instance mutation.

## Efficient Sequences

For a known narrow read:

1. Resolve the profile and run one `Invoke-ServiceNowTable.ps1` GET with exact query, fields, and limit.
2. Escalate only if the record/schema/runtime evidence is insufficient.

For substantial controlled configuration:

1. Health check when context is uncertain.
2. Exact artifact lookup and table shape.
3. Snapshot and set scope/update set.
4. Apply one coherent slice.
5. Fresh record read plus update-capture check.
6. Behavior/security/regression test.
7. Restore preferences.

For broad unfamiliar work:

1. Scope inventory or existing index.
2. Targeted artifact/impact lookup.
3. Live verification of the small candidate set.
4. Continue with the controlled-change sequence.

Avoid habitual health checks, full inventories, body searches, and indexes when an exact read answers the question.
