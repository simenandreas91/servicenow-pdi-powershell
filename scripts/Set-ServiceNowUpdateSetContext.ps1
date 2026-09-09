param(
  [Parameter(Mandatory = $true)]
  [string]$Scope,

  [string]$Name,
  [string]$Description = '',
  [string]$UpdateSetSysId,
  [string]$UserSysId,
  [string]$SnapshotPath,
  [string]$Profile,
  [string]$EnvPath,
  [string]$Instance
)

$ErrorActionPreference = 'Stop'
$tableScript = Join-Path $PSScriptRoot 'Invoke-ServiceNowTable.ps1'
. (Join-Path $PSScriptRoot '_ServiceNowToolkitCommon.ps1')

if (-not $UpdateSetSysId -and [string]::IsNullOrWhiteSpace($Name)) {
  throw 'Provide -Name to create an update set or -UpdateSetSysId to resume one.'
}
if ($UpdateSetSysId -and $UpdateSetSysId -notmatch '^[0-9a-fA-F]{32}$') { throw 'UpdateSetSysId must be a 32-character sys_id.' }
if ($Name -eq 'Default') { throw 'Do not develop in the Default update set.' }
if ([string]::IsNullOrWhiteSpace($SnapshotPath)) { throw 'Provide a new -SnapshotPath to persist recovery evidence before changing preferences.' }
if (Test-Path -LiteralPath $SnapshotPath) { throw 'SnapshotPath already exists. Preserve the original recovery snapshot and choose a new path.' }

function Invoke-Table {
  param(
    [string]$Method = 'GET',
    [Parameter(Mandatory = $true)][string]$Table,
    [string]$SysId,
    [string]$Query,
    [string]$Fields,
    [int]$Limit = 10,
    [string]$DisplayValue = 'false',
    [string]$BodyJson
  )

  $invokeParams = @{
    Method = $Method
    Table = $Table
    DisplayValue = $DisplayValue
    ExcludeReferenceLink = $true
  }
  if ($SysId) { $invokeParams.SysId = $SysId }
  if ($Query) { $invokeParams.Query = $Query }
  if ($Fields) { $invokeParams.Fields = $Fields }
  if ($Method -eq 'GET') { $invokeParams.Limit = $Limit }
  if ($BodyJson) { $invokeParams.BodyJson = $BodyJson }
  if ($Profile) { $invokeParams.Profile = $Profile }
  if ($EnvPath) { $invokeParams.EnvPath = $EnvPath }
  if ($Instance) { $invokeParams.Instance = $Instance }

  (& $tableScript @invokeParams) | ConvertFrom-Json
}

function Get-ScopeSysId {
  param([string]$ScopeValue)
  return (Resolve-ServiceNowToolkitScope -Scope $ScopeValue -Profile $Profile -EnvPath $EnvPath -Instance $Instance -NoCache).sys_id
}

function Get-Preference {
  param([string]$Name)
  $query = "user=$UserSysId^name=$Name"
  $response = Invoke-Table -Table 'sys_user_preference' -Query $query -Fields 'sys_id,name,value,user' -Limit 1
  if ($response.result -and $response.result.Count -gt 0) { return $response.result[0] }
  return $null
}

function Set-Preference {
  param([string]$Name, [string]$Value)
  $existing = Get-Preference -Name $Name
  $body = @{ user = $UserSysId; name = $Name; value = $Value } | ConvertTo-Json
  if ($existing) {
    Invoke-Table -Method PATCH -Table 'sys_user_preference' -SysId $existing.sys_id -Fields 'sys_id,name,value,user' -DisplayValue all -BodyJson $body | Out-Null
    return $existing.sys_id
  }
  $created = Invoke-Table -Method POST -Table 'sys_user_preference' -Fields 'sys_id,name,value,user' -DisplayValue all -BodyJson $body
  return $created.result.sys_id.value
}

$UserSysId = Resolve-ServiceNowToolkitUserSysId `
  -UserSysId $UserSysId `
  -Profile $Profile `
  -EnvPath $EnvPath `
  -Instance $Instance
$scopeSysId = Get-ScopeSysId -ScopeValue $Scope
if ($UpdateSetSysId) {
  $existingSet = (Invoke-Table -Table 'sys_update_set' -SysId $UpdateSetSysId -Fields 'sys_id,name,state,application').result
  if (-not $existingSet -or $existingSet.application -ne $scopeSysId -or
      $existingSet.state -ne 'in progress' -or $existingSet.name -eq 'Default') {
    throw 'The selected update set must exist, be in progress, be non-Default, and match the requested scope.'
  }
}
. (Join-Path $PSScriptRoot 'Resolve-ServiceNowConnection.ps1')
$connection = Resolve-ServiceNowConnection -Profile $Profile -EnvPath $EnvPath -Instance $Instance
$prefNames = @('apps.current_app', 'sys_update_set', "updateSetForScope$scopeSysId")
$snapshot = [ordered]@{
  instance = $connection.Instance
  user_name = $connection.UserName
  user_sys_id = $UserSysId
  scope_sys_id = $scopeSysId
  captured_at = (Get-Date).ToString('o')
  preferences = @()
}

foreach ($prefName in $prefNames) {
  $pref = Get-Preference -Name $prefName
  $snapshot.preferences += [ordered]@{
    name = $prefName
    existed = [bool]$pref
    sys_id = if ($pref) { $pref.sys_id } else { $null }
    value = if ($pref) { $pref.value } else { $null }
  }
}

# Persist recovery evidence BEFORE the first remote mutation; never overwrite it.
$snapshotJson = $snapshot | ConvertTo-Json -Depth 8
$snapshotFile = [System.IO.File]::Open($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SnapshotPath),
  [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
try {
  $snapshotBytes = [System.Text.Encoding]::UTF8.GetBytes($snapshotJson)
  $snapshotFile.Write($snapshotBytes, 0, $snapshotBytes.Length)
} finally { $snapshotFile.Dispose() }

Set-Preference -Name 'apps.current_app' -Value $scopeSysId | Out-Null

if (-not $UpdateSetSysId) {
  if (-not $Name) { throw 'Provide -Name when -UpdateSetSysId is omitted.' }
  $body = @{
    name = $Name
    description = $Description
    application = $scopeSysId
    state = 'in progress'
  } | ConvertTo-Json
  $created = Invoke-Table -Method POST -Table 'sys_update_set' -Fields 'sys_id,name,state,application,description' -DisplayValue all -BodyJson $body
  $UpdateSetSysId = $created.result.sys_id.value
  $actualApplication = $created.result.application.value
  if ($actualApplication -ne $scopeSysId) {
    throw "Created update set in application '$actualApplication', expected '$scopeSysId'. Restore preferences before retrying."
  }
}

Set-Preference -Name "updateSetForScope$scopeSysId" -Value $UpdateSetSysId | Out-Null
Set-Preference -Name 'sys_update_set' -Value $UpdateSetSysId | Out-Null

[ordered]@{
  scope_sys_id = $scopeSysId
  update_set_sys_id = $UpdateSetSysId
  snapshot_path = $SnapshotPath
  snapshot = $snapshot
} | ConvertTo-Json -Depth 10
