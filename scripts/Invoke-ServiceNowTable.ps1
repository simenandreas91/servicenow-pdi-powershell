#requires -Version 7.0
param(
  [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
  [string]$Method = 'GET',

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')]
  [string]$Table,

  [string]$SysId,
  [string]$Query,
  [string]$Fields,
  [ValidateRange(1, 10000)][int]$Limit = 10,
  [ValidateRange(0, 2147483647)][int]$Offset = 0,
  [ValidateSet('false', 'true', 'all')]
  [string]$DisplayValue = 'false',
  [switch]$ExcludeReferenceLink,
  [switch]$WantSessionDebugMessages,
  [string]$BodyJson,
  [string]$BodyPath,
  [switch]$AsObject,
  [switch]$IncludePaginationInfo,
  [ValidateRange(1, 600)][int]$TimeoutSec = 60,
  [ValidateRange(0, 3)][int]$MaxRetries = 2,
  [string]$Profile,
  [string]$EnvPath,
  [string]$Instance
)

$ErrorActionPreference = 'Stop'

if ($Method -in @('PATCH', 'DELETE') -and [string]::IsNullOrWhiteSpace($SysId)) {
  throw 'PATCH and DELETE require one exact -SysId; -Query is not a write target.'
}
if ($Method -eq 'POST' -and $SysId) { throw 'POST creates a record and must not include -SysId.' }
if ($SysId -and $SysId -notmatch '^[0-9a-fA-F]{32}$') { throw 'SysId must be a 32-character sys_id.' }
if ($BodyPath -and $BodyJson) { throw 'Pass either -BodyPath or -BodyJson, not both.' }
if ($BodyPath) { $BodyJson = Get-Content -LiteralPath $BodyPath -Raw -Encoding UTF8 }
if ($Method -in @('POST', 'PATCH')) {
  if ([string]::IsNullOrWhiteSpace($BodyJson)) { throw 'POST and PATCH require a JSON object body.' }
  try { $parsedBody = ConvertFrom-Json -InputObject $BodyJson -AsHashtable -ErrorAction Stop }
  catch { throw 'Body must contain valid JSON.' }
  if ($parsedBody -isnot [System.Collections.IDictionary]) { throw 'Body must be a JSON object.' }
} elseif ($BodyJson) { throw 'A request body is supported only for POST and PATCH.' }
if (($Offset -gt 0 -or $IncludePaginationInfo) -and ($Method -ne 'GET' -or $SysId)) {
  throw 'Pagination options apply only to collection GET requests.'
}

. "$PSScriptRoot/Resolve-ServiceNowConnection.ps1"
$connection = Resolve-ServiceNowConnection -Profile $Profile -Instance $Instance -EnvPath $EnvPath
$instance = $connection.Instance

$pair = '{0}:{1}' -f $connection.UserName, $connection.Password
$auth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
  Authorization = "Basic $auth"
  Accept = 'application/json'
}
if ($WantSessionDebugMessages) {
  $headers['X-WantSessionDebugMessages'] = 'true'
}

$escapedTable = [uri]::EscapeDataString($Table)
$path = "$instance/api/now/table/$escapedTable"
if (-not [string]::IsNullOrWhiteSpace($SysId)) {
  $path = "$path/$([uri]::EscapeDataString($SysId))"
}

$params = @{}
if (-not [string]::IsNullOrWhiteSpace($Query)) {
  $params.sysparm_query = $Query
}
if (-not [string]::IsNullOrWhiteSpace($Fields)) {
  $params.sysparm_fields = $Fields
}
if ($Method -eq 'GET' -and [string]::IsNullOrWhiteSpace($SysId)) {
  $params.sysparm_limit = [string]$Limit
  $params.sysparm_offset = [string]$Offset
}
if ($DisplayValue -ne 'false') {
  $params.sysparm_display_value = $DisplayValue
}
if ($ExcludeReferenceLink) {
  $params.sysparm_exclude_reference_link = 'true'
}

if ($params.Count -gt 0) {
  $queryParts = foreach ($key in $params.Keys) {
    '{0}={1}' -f [uri]::EscapeDataString($key), [uri]::EscapeDataString($params[$key])
  }
  $path = "$path`?$($queryParts -join '&')"
}

$invokeParams = @{
  Uri = $path
  Headers = $headers
  Method = $Method
  TimeoutSec = $TimeoutSec
  MaximumRedirection = 0
  ResponseHeadersVariable = 'responseHeaders'
}
# In 7.4+, TimeoutSec bounds connection setup; also bound stalled response reads.
if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey('OperationTimeoutSeconds')) {
  $invokeParams.OperationTimeoutSeconds = $TimeoutSec
}

if ($Method -in @('POST', 'PATCH') -and -not [string]::IsNullOrWhiteSpace($BodyJson)) {
  $invokeParams.Body = [System.Text.Encoding]::UTF8.GetBytes($BodyJson)
  $invokeParams.ContentType = 'application/json; charset=utf-8'
}

for ($attempt = 0; ; $attempt++) {
  try {
    $response = Invoke-RestMethod @invokeParams
    break
  } catch {
    $httpResponse = $_.Exception.Response
    $status = if ($httpResponse) { [int]$httpResponse.StatusCode } else { 0 }
    $delay = [int][Math]::Pow(2, $attempt)
    if ($httpResponse -and $httpResponse.Headers.RetryAfter) {
      $retryAfter = $httpResponse.Headers.RetryAfter
      if ($retryAfter.Delta) { $delay = [int][Math]::Ceiling($retryAfter.Delta.TotalSeconds) }
      elseif ($retryAfter.Date) { $delay = [int][Math]::Ceiling(($retryAfter.Date - [DateTimeOffset]::UtcNow).TotalSeconds) }
      $delay = [Math]::Max(1, $delay)
    }
    if ($Method -eq 'GET' -and $status -in @(429, 502, 503, 504) -and $attempt -lt $MaxRetries -and $delay -le 60) {
      Start-Sleep -Seconds $delay
      continue
    }
    $detail = if ($status) { "HTTP $status" } else { 'a transport failure or timeout' }
    $guidance = if ($Method -eq 'GET') { 'Check connectivity, permissions, and the query before retrying.' }
      else { 'Write outcome may be unknown. Read the target and its side effects before any retry.' }
    throw "ServiceNow $Method on table '$Table' failed with $detail. $guidance"
  }
}

if ($Method -ne 'DELETE' -and ($null -eq $response -or $response.PSObject.Properties.Name -notcontains 'result')) {
  throw 'ServiceNow did not return a Table API result. Check the endpoint and authentication; do not blindly replay writes.'
}
if ($IncludePaginationInfo) {
  $nextOffset = $null
  $links = @($responseHeaders['Link']) -join ','
  foreach ($link in ($links -split ',(?=\s*<)')) {
    if ($link -match ';\s*rel\s*=\s*"?next"?' -and $link -match '[?&]sysparm_offset=(\d+)') {
      $nextOffset = [int]$Matches[1]
      if ($nextOffset -le $Offset) { throw 'Table API returned a non-advancing pagination link.' }
    }
  }
  $response | Add-Member -NotePropertyName pagination -NotePropertyValue ([ordered]@{
    offset = $Offset; limit = $Limit; next_offset = $nextOffset
  }) -Force
}
if ($AsObject) { return $response }
ConvertTo-Json -InputObject $response -Depth 12 -Compress
