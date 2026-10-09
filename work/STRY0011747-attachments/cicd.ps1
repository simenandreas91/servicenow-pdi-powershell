param(
  [Parameter(Mandatory)][ValidateSet('vaar_test','vaar_prod')][string]$Profile,
  [Parameter(Mandatory)][ValidateSet('retrieve','preview','commit','progress')][string]$Action,
  [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{32}$')][string]$Id,
  [ValidatePattern('^[a-f0-9]{32}$')][string]$UpdateSourceId
)
$ErrorActionPreference = 'Stop'
$root = 'C:\Users\simen\.codex\skills\servicenow-pdi'
. "$root\scripts\Resolve-ServiceNowConnection.ps1"
$connection = Resolve-ServiceNowConnection -Profile $Profile -EnvPath "$root\.env"
$expected = if ($Profile -eq 'vaar_test') { 'https://varenergitest.service-now.com' } else { 'https://varenergi.service-now.com' }
if ($connection.Instance.TrimEnd('/') -ne $expected) { throw 'Unexpected target instance.' }
$authorization = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $connection.UserName,$connection.Password)))
$headers = @{Authorization="Basic $authorization";Accept='application/json'}
$parameters = @{Headers=$headers;ContentType='application/json';TimeoutSec=90;MaximumRedirection=0}
if ($Action -eq 'progress') {
  $parameters.Method = 'GET'
  $path = "progress/$Id"
} elseif ($Action -eq 'retrieve') {
  if (!$UpdateSourceId) { throw 'Retrieval requires exact Update Source.' }
  $parameters.Method = 'POST'
  $path = "update_set/retrieve?update_set_id=$Id&update_source_id=$UpdateSourceId"
  $parameters.Body = '{}'
} else {
  $parameters.Method = 'POST'
  $path = "update_set/$Action/$Id"
  $parameters.Body = if ($Action -eq 'commit') { '{"force_commit":false}' } else { '{}' }
}
$response = Invoke-RestMethod @parameters -Uri "$($connection.Instance)/api/sn_cicd/$path"
$response | ConvertTo-Json -Depth 20
