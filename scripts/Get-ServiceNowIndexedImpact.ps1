param(
  [string]$Table,
  [string]$SysId,
  [string]$Key,
  [string]$IndexPath,
  [int]$Limit = 100
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($IndexPath)) {
  $IndexPath = Join-Path (Get-Location).Path '.servicenow-index'
}
if (-not (Test-Path -LiteralPath $IndexPath)) {
  throw "Index path was not found: $IndexPath"
}
$IndexPath = (Resolve-Path -LiteralPath $IndexPath).Path

function Read-ServiceNowImpactJsonArray {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $raw = Get-Content -LiteralPath $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
  return @($raw | ConvertFrom-Json)
}

if ([string]::IsNullOrWhiteSpace($SysId) -and [string]::IsNullOrWhiteSpace($Key)) {
  throw 'Pass -SysId or -Key.'
}

$edges = Read-ServiceNowImpactJsonArray -Path (Join-Path $IndexPath 'edges.json')
$artifacts = Read-ServiceNowImpactJsonArray -Path (Join-Path $IndexPath 'artifacts.json')

$incoming = [System.Collections.Generic.List[object]]::new()
$outgoing = [System.Collections.Generic.List[object]]::new()

foreach ($edge in $edges) {
  if ($incoming.Count -lt $Limit) {
    $matchesTarget = $false
    if (-not [string]::IsNullOrWhiteSpace($Key) -and $edge.to_key -eq $Key) { $matchesTarget = $true }
    if (-not [string]::IsNullOrWhiteSpace($Table) -and $edge.to_table -eq $Table -and -not [string]::IsNullOrWhiteSpace($Key) -and $edge.to_key -eq $Key) { $matchesTarget = $true }
    if ($matchesTarget) {
      $source = @($artifacts | Where-Object { $_.sys_id -eq $edge.from_sys_id } | Select-Object -First 1)
      $incoming.Add([pscustomobject]@{
        edge = $edge
        source = if ($source.Count -gt 0) { $source[0] } else { $null }
      })
    }
  }

  if ($outgoing.Count -lt $Limit -and -not [string]::IsNullOrWhiteSpace($SysId) -and $edge.from_sys_id -eq $SysId) {
    $outgoing.Add($edge)
  }
}

[ordered]@{
  searched_at = (Get-Date).ToString('o')
  index_path = $IndexPath
  query = [ordered]@{
    table = $Table
    sys_id = $SysId
    key = $Key
  }
  incoming_count = $incoming.Count
  outgoing_count = $outgoing.Count
  incoming = @($incoming)
  outgoing = @($outgoing)
} | ConvertTo-Json -Depth 20
