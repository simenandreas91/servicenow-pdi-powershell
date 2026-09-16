#requires -Version 7.0
param(
  [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$BatchSysId,
  [Parameter(Mandatory)][string]$OutputPath,
  [ValidatePattern('^[0-9a-f]{32}$')][string]$RemoteBatchSysId,
  [string]$Profile,
  [string]$EnvPath,
  [string]$Instance
)
$ErrorActionPreference = 'Stop'

function Test-BatchExportXml {
  param([string]$Path, [string]$RemoteId, [string]$LocalId, [array]$Sets, [array]$Updates)
  $document = [System.Xml.XmlDocument]::new()
  $document.XmlResolver = $null
  $document.Load($Path)
  if ($document.DocumentElement.LocalName -ne 'unload') { throw 'Export is not unload XML.' }
  $nodes = @($document.SelectNodes('/unload/sys_remote_update_set'))
  $groups = @($nodes | Group-Object { $_.SelectSingleNode('sys_id').InnerText })
  if ($groups.Count -ne $Sets.Count) { throw 'Exported set count differs from source.' }
  $remoteToLocal = @{}
  $seenSources = @{}
  foreach ($group in $groups) {
    if (@($group.Group | ForEach-Object { $_.OuterXml } | Select-Object -Unique).Count -ne 1) {
      throw 'Conflicting duplicate remote update set.'
    }
    $node = $group.Group[0]
    $id = $node.SelectSingleNode('sys_id').InnerText
    $sourceId = $node.SelectSingleNode('remote_sys_id').InnerText
    $source = @($Sets | Where-Object { $_.sys_id -eq $sourceId })
    if ($source.Count -ne 1 -or $seenSources.ContainsKey($sourceId)) { throw 'Unexpected source identity.' }
    $seenSources[$sourceId] = $true
    if ($node.SelectSingleNode('application').InnerText -ne $source[0].application) { throw 'Scope mismatch.' }
    if ($node.SelectSingleNode('remote_base_update_set').InnerText -ne $RemoteId) { throw 'Incorrect remote base.' }
    if ($sourceId -eq $LocalId) {
      if ($id -ne $RemoteId -or $node.SelectSingleNode('parent').InnerText) { throw 'Incorrect remote parent.' }
    } elseif ($node.SelectSingleNode('parent').InnerText -ne $RemoteId) { throw 'Incorrect child relationship.' }
    $remoteToLocal[$id] = $sourceId
  }
  $exported = @($document.SelectNodes('/unload/sys_update_xml'))
  if ($exported.Count -ne $Updates.Count) { throw 'Exported update count differs from source.' }
  $seenUpdates = @{}
  foreach ($node in $exported) {
    $owner = $remoteToLocal[$node.SelectSingleNode('remote_update_set').InnerText]
    $name = $node.SelectSingleNode('name').InnerText
    $key = "$owner/$name"
    $source = @($Updates | Where-Object { $_.update_set -eq $owner -and $_.name -eq $name })
    if ($source.Count -ne 1 -or $seenUpdates.ContainsKey($key)) { throw "Unexpected/duplicate update: $name" }
    $seenUpdates[$key] = $true
    foreach ($field in @('payload', 'action', 'application')) {
      if ($node.SelectSingleNode($field).InnerText -cne $source[0].$field) { throw "Export $field differs: $name" }
    }
  }
}

function Get-UiToken([string]$Content) {
  $inputTag = [regex]::Match($Content, '(?is)<input\b(?=[^>]*\bname=["'']sysparm_ck["''])[^>]*>')
  $match = [regex]::Match($inputTag.Value, '\bvalue=["'']([^"'']*)["'']')
  if (-not $match.Success) { $match = [regex]::Match($Content, 'g_ck\s*=\s*["'']([^"'']+)["'']') }
  if ($match.Success) { return [Net.WebUtility]::HtmlDecode($match.Groups[1].Value) }
}

function Read-AllRows([string]$Table, [string]$Query, [string]$Fields) {
  $offset = 0
  for ($page = 0; $page -lt 100; $page++) {
    $reply = & (Join-Path $PSScriptRoot 'Invoke-ServiceNowTable.ps1') @connectionArgs `
      -Table $Table -Query "$Query^ORDERBYsys_id" -Fields $Fields -Limit 500 -Offset $offset `
      -AsObject -ExcludeReferenceLink -IncludePaginationInfo
    $reply.result
    if ($null -eq $reply.pagination.next_offset) { return }
    $offset = $reply.pagination.next_offset
  }
  throw 'Inventory exceeded 100 pages; narrow the package before exporting.'
}

$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $OutputPath) { throw 'Destination already exists; choose a new filename.' }
$directory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw 'Destination directory does not exist.' }
$connectionArgs = @{}
foreach ($key in @('Profile', 'EnvPath', 'Instance')) {
  if ($PSBoundParameters.ContainsKey($key)) { $connectionArgs[$key] = $PSBoundParameters[$key] }
}
. (Join-Path $PSScriptRoot 'Resolve-ServiceNowConnection.ps1')
$connection = Resolve-ServiceNowConnection @connectionArgs
$sets = @(Read-AllRows 'sys_update_set' "sys_id=$BatchSysId^ORbase_update_set=$BatchSysId^ORparent=$BatchSysId" 'sys_id,application,state,parent,base_update_set')
$parent = @($sets | Where-Object { $_.sys_id -eq $BatchSysId })
if ($parent.Count -ne 1 -or $sets.Count -lt 2 -or $parent[0].application -ne 'global' -or $parent[0].parent) {
  throw 'Expected a Global batch parent with children.'
}
foreach ($set in $sets) {
  if ($set.state -ne 'complete' -or $set.base_update_set -ne $BatchSysId -or
      ($set.sys_id -ne $BatchSysId -and $set.parent -ne $BatchSysId)) {
    throw 'Expected a fully completed one-level batch with verified parent/base relationships.'
  }
}
$ids = ($sets.sys_id -join ',')
$updates = @(Read-AllRows 'sys_update_xml' "update_setIN$ids" 'name,update_set,application,action,payload')
if (-not $updates.Count) { throw 'Batch has no customer updates.' }
foreach ($update in $updates) {
  $owner = $sets | Where-Object { $_.sys_id -eq $update.update_set }
  if ($owner.application -ne $update.application) { throw "Mixed-scope capture: $($update.name)" }
}

if (-not $RemoteBatchSysId) {
  $script = @"
var current = new GlideRecord('sys_update_set');
if (!current.get('$BatchSysId') || current.getValue('state') !== 'complete')
  throw 'Completed batch missing';
var remoteId = new UpdateSetExport().exportHierarchy(current);
gs.info('SN_RESULT_START' + remoteId + 'SN_RESULT_END');
"@
  $RemoteBatchSysId = ([string](& (Join-Path $PSScriptRoot 'Invoke-ServiceNowXploreScript.ps1') @connectionArgs -Scope global -Script $script)).Trim()
  if ($RemoteBatchSysId -notmatch '^[0-9a-f]{32}$') { throw 'Exporter outcome uncertain; inspect remote sets before retrying.' }
}
Write-Host "Remote batch export ID: $RemoteBatchSysId (retain for recovery)."
$remote = (& (Join-Path $PSScriptRoot 'Invoke-ServiceNowTable.ps1') @connectionArgs `
  -Table sys_remote_update_set -SysId $RemoteBatchSysId -Fields 'sys_id,remote_sys_id,remote_base_update_set' `
  -AsObject -ExcludeReferenceLink).result
if ($remote.remote_sys_id -ne $BatchSysId -or $remote.remote_base_update_set -ne $RemoteBatchSysId) {
  throw 'Remote export does not match this batch.'
}
$temporaryPath = Join-Path $directory ('.sn-batch-' + [guid]::NewGuid().ToString('N') + '.xml')
try {
  # The export processor requires a UI cookie session on the observed PDI.
  $login = Invoke-WebRequest -Uri ($connection.Instance + '/login.do') -SessionVariable uiSession -MaximumRedirection 5 -TimeoutSec 60
  $body = @{
    user_name = $connection.UserName; user_password = $connection.Password
    'ni.nolog.user_password' = 'true'; 'ni.noecho.user_name' = 'true'; 'ni.noecho.user_password' = 'true'
    sys_action = 'sysverb_login'; sysparm_login_url = 'welcome.do'; sysparm_referring_url = 'welcome.do'
  }
  $token = Get-UiToken $login.Content
  if ($token) { $body.sysparm_ck = $token }
  $login = Invoke-WebRequest -Uri ($connection.Instance + '/login.do') -WebSession $uiSession -Method POST `
    -Body $body -ContentType 'application/x-www-form-urlencoded' -MaximumRedirection 5 -SkipHttpErrorCheck -TimeoutSec 60
  if ($login.StatusCode -ge 400 -or $login.Headers['X-Is-Logged-In'] -contains 'false') { throw 'UI login failed.' }
  $landing = Invoke-WebRequest -Uri ($connection.Instance + '/welcome.do') -WebSession $uiSession -MaximumRedirection 5 -TimeoutSec 60
  $token = Get-UiToken $landing.Content
  if (-not $token) { throw 'Authenticated UI token missing; use the native Export Update Set Batch to XML UI action.' }
  $url = $connection.Instance + '/export_base_update_set.do?sysparm_sys_id=' + $RemoteBatchSysId +
    '&sysparm_delete_when_done=true&sysparm_is_remote=false&sysparm_ck=' + [uri]::EscapeDataString($token)
  Invoke-WebRequest -Uri $url -WebSession $uiSession -OutFile $temporaryPath -MaximumRedirection 0 -TimeoutSec 60 | Out-Null
  Test-BatchExportXml -Path $temporaryPath -RemoteId $RemoteBatchSysId -LocalId $BatchSysId -Sets $sets -Updates $updates
  [IO.File]::Move($temporaryPath, $OutputPath)
} catch {
  throw "Batch export did not finish. Remote ID: $RemoteBatchSysId; inspect recovery file if present: $temporaryPath. Do not blindly regenerate. $($_.Exception.Message)"
}
[pscustomobject]@{
  batch_sys_id = $BatchSysId; remote_batch_sys_id = $RemoteBatchSysId
  child_sets = $sets.Count - 1; updates = $updates.Count; path = $OutputPath
  bytes = (Get-Item -LiteralPath $OutputPath).Length
  sha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
} | ConvertTo-Json
