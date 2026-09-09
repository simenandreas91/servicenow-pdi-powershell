# ServiceNow Helper Router

Resolve helper paths relative to `SKILL.md`.

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
| `Invoke-ServiceNowTable.ps1` | Exact Table API GET/POST/PATCH/DELETE; UTF-8 body files, object/JSON output, bounded GET retries, explicit paging | Read or write by method |
| `Invoke-ServiceNowXploreScript.ps1` | Scoped server execution with structured output; preferred runtime probe | Depends on submitted script |
| `Invoke-ServiceNowBackgroundScript.ps1` | Background Script fallback when Xplore is unavailable or comparison is required | Depends on submitted script |

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

### Update-set lifecycle

| Helper | Use | State |
| --- | --- | --- |
| `Set-ServiceNowUpdateSetContext.ps1` | Validate/select scoped update set; requires a new `-SnapshotPath` saved before any remote write | Controlled write |
| `Restore-ServiceNowPreferenceSnapshot.ps1` | Restore saved application/update-set preferences | Controlled write |
| `Confirm-ServiceNowUpdateCapture.ps1` | Check expected update XML names/application | Read |
| `Get-ServiceNowUpdateSetSummary.ps1` | Contents, types, scope mixing, and likely noise | Read |
| `Save-ServiceNowCustomerUpdate.ps1` | Force capture of one legitimate application file after diagnosing missed natural capture | Controlled write |
| `Export-ServiceNowUpdateSetXml.ps1` | Export one update set; `-Complete` also changes its state | Local file; conditional write |
| `Remove-ServiceNowArtifactWithDeleteCapture.ps1` | Snapshot, delete, and create deployable DELETE capture for one proven customer artifact | Destructive write |

The delete helper requires explicit deletion authority and target preview planning.

### Focused workflows

| Helper | Use | State |
| --- | --- | --- |
| `Test-ServiceNowNotification.ps1` | Inspect event/notification/email evidence; `-Trigger` queues an event | Read; conditional write |
| `Get-ServiceNowCompendiaSyncStatus.ps1` | Compact Compendia configuration/sync health | Read |
| `Initialize-ServiceNowAndrewReactApp.ps1` | Configure the maintained React/Vite boilerplate for a confirmed non-production instance; `-Install` installs dependencies | Local write; optional install |
| `Manage-VaarEnergiStoryMonitor.ps1` | Maintain local assigned-story approval/monitor state | Local state write |
| `Manage-VaarEnergiStoryWorkLog.ps1` | Maintain local Vår story work log/report state | Local state write |
| `Test-ServiceNowToolkit.ps1` | Offline regression checks with synthetic credentials and intercepted HTTP; run after changing core helpers | Local test |

Load the matching domain/customer reference for focused workflows.

## Command and response contracts

Use PowerShell 7. Prefer `& $helper @params` in the existing shell or `pwsh -NoProfile -File <path>`; avoid nested command strings. Table `-AsObject` returns native objects; default output is compact JSON with a `result` envelope. Use UTF-8 `-BodyPath` for substantial JSON and `-ScriptPath` or a single-quoted here-string for JavaScript. Python can process offline exports; share the existing credential resolver for instance calls.

### Table API

- `-TimeoutSec`: default 60; connection and stalled reads on PowerShell 7.4+.
- `-MaxRetries`: default 2; only GET HTTP 429/502/503/504. Retry-After up to 60 seconds is honored; longer waits fail. No automatic replay of writes, transport failures, or permanent errors.
- HTTPS origin required; redirects refused. These contracts are specific to the Table helper, not Xplore/Background Script.
- Collection GET: `-Offset`, `-Limit`, `-IncludePaginationInfo`. `pagination.next_offset` comes from the Link header; null means no next link supplied. Keep query/order/page size fixed and impose a budget. ACL-filtered short/empty pages can have a next link. Changing data prevents offset traversal from being a consistent snapshot.

Sources: [PowerShell HTTP behavior](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-restmethod), [ServiceNow pagination](https://www.servicenow.com/docs/r/api-reference/rest-api-explorer/c_RESTAPI.html).

### Cache and recovery

Discovery cache keys include resolved instance, username, and response shape. `-Refresh` replaces a cached entry; `-NoCache` bypasses caching for sensitive reads, permission changes, and post-write proof. Cached admin results cannot prove another persona's access.

`Set-ServiceNowUpdateSetContext.ps1` requires a new snapshot filename with a writable parent directory. It validates resumed sets as in-progress, non-Default, and scope-matching before writes. Restore checks instance/username; verify legacy snapshot origin locally before adding missing binding fields. `Save-ServiceNowCustomerUpdate.ps1 -UpdateSetSysId` asserts the capture destination; correct context and recapture on mismatch.
