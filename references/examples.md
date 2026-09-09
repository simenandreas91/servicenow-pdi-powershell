# ServiceNow Helper Examples

Run in PowerShell 7. Resolve this skill's actual directory and the approved environment before using these examples. Values in angle brackets are task inputs.

```powershell
$skillRoot = '<directory containing SKILL.md>'
$scripts = Join-Path $skillRoot 'scripts'
$tableHelper = Join-Path $scripts 'Invoke-ServiceNowTable.ps1'
$connectionArgs = @{ Profile = 'pdi'; EnvPath = '<approved-env-path>' }
Get-Command $tableHelper -Syntax
```

Resolve one exact user without hiding duplicate matches:

```powershell
$read = @{
  Table = 'sys_user'
  Query = 'user_name=<exact-user-name>'
  Fields = 'sys_id,user_name,active'
  Limit = 2
  ExcludeReferenceLink = $true
  AsObject = $true
}
$users = @((& $tableHelper @connectionArgs @read).result)
if ($users.Count -ne 1) { throw 'Expected exactly one user.' }
$userSysId = $users[0].sys_id
```

Inspect schema before writing:

```powershell
& (Join-Path $scripts 'Get-ServiceNowTableShape.ps1') @connectionArgs -Table rm_story -NoCache
```

Create a story only when requested. Resolve every reference on the intended target before constructing its body:

```powershell
$body = @{
  short_description = 'Example story'
  description = 'As a user, I want an example story so that I can verify the workflow.'
  assigned_to = $userSysId
} | ConvertTo-Json -Depth 5 -Compress
$create = @{
  Method = 'POST'
  Table = 'rm_story'
  Fields = 'sys_id,number,short_description,assigned_to,state'
  BodyJson = $body
  ExcludeReferenceLink = $true
  AsObject = $true
}
$created = & $tableHelper @connectionArgs @create
```

For larger JSON payloads, save a UTF-8 JSON object to a task file and pass `-BodyPath <path>` instead of `-BodyJson`. Do not construct nested shell command strings containing the body.

Read-only Xplore probe, using a single-quoted here-string so PowerShell does not expand JavaScript content:

```powershell
$probe = @'
(function () {
  var result = { activeUsers: 0 };
  var users = new GlideAggregate('sys_user');
  users.addQuery('active', true);
  users.addAggregate('COUNT');
  users.query();
  if (users.next()) result.activeUsers = parseInt(users.getAggregate('COUNT'), 10);
  gs.print('SN_RESULT_START' + JSON.stringify(result) + 'SN_RESULT_END');
})();
'@
& (Join-Path $scripts 'Invoke-ServiceNowXploreScript.ps1') @connectionArgs -Script $probe
```

For substantial JavaScript, save a `.js` file and use `-ScriptPath`. For scoped Xplore, pass `-Scope <sys_scope.scope>` or `-ScopeSysId <live-sys-id>`.

Resume an existing scoped update set. Resolve the set and scope live first; choose a new snapshot filename in an existing directory:

```powershell
$contextArgs = @{
  Scope = '<resolved-scope-name>'
  UpdateSetSysId = '<resolved-update-set-sys-id>'
  SnapshotPath = Join-Path (Get-Location).Path 'preferences-before-change.json'
}
& (Join-Path $scripts 'Set-ServiceNowUpdateSetContext.ps1') @connectionArgs @contextArgs
# Perform the authorized change and verify records, behavior, and capture.
& (Join-Path $scripts 'Restore-ServiceNowPreferenceSnapshot.ps1') @connectionArgs -SnapshotPath $contextArgs.SnapshotPath
```

Page a bounded discovery query without assuming a short page is the last one:

```powershell
$pageArgs = @{
  Table = 'sys_script_include'
  Query = 'sys_scope=<resolved-scope-sys-id>^ORDERBYsys_id'
  Fields = 'sys_id,name,sys_updated_on'
  Limit = 100
  Offset = 0
  IncludePaginationInfo = $true
  ExcludeReferenceLink = $true
  AsObject = $true
}
for ($pageNumber = 0; $pageNumber -lt 10; $pageNumber++) {
  $page = & $tableHelper @connectionArgs @pageArgs
  $page.result | Select-Object sys_id,name,sys_updated_on
  if ($null -eq $page.pagination.next_offset) { break }
  if ($pageNumber -eq 9) { throw 'Page budget reached; results are incomplete.' }
  $pageArgs.Offset = $page.pagination.next_offset
}
```

Run the local regression suite after changing shared helpers:

```powershell
& (Join-Path $scripts 'Test-ServiceNowToolkit.ps1')
```
