param(
  [Parameter(Mandatory = $true)]
  [string]$Text,

  [string]$IndexPath,
  [int]$Limit = 25
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($IndexPath)) {
  $IndexPath = Join-Path (Get-Location).Path '.servicenow-index'
}
if (-not (Test-Path -LiteralPath $IndexPath)) {
  throw "Index path was not found: $IndexPath"
}
$IndexPath = (Resolve-Path -LiteralPath $IndexPath).Path

function Read-ServiceNowIndexJsonArray {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $raw = Get-Content -LiteralPath $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
  return @($raw | ConvertFrom-Json)
}

function Test-ServiceNowIndexMatch {
  param($Object, [string]$Needle)

  foreach ($prop in $Object.PSObject.Properties) {
    if ($null -eq $prop.Value) { continue }
    if (($prop.Value -is [string]) -and $prop.Value.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      return $true
    }
  }
  return $false
}

$matches = [System.Collections.Generic.List[object]]::new()

foreach ($table in (Read-ServiceNowIndexJsonArray -Path (Join-Path $IndexPath 'tables.json'))) {
  if ($matches.Count -ge $Limit) { break }
  if (Test-ServiceNowIndexMatch -Object $table -Needle $Text) {
    $matches.Add([pscustomobject]@{
      kind = 'table'
      table = 'sys_db_object'
      sys_id = $table.sys_id
      name = $table.name
      label = $table.label
      target_table = $table.name
      updated = $table.sys_updated_on
      record = $table
    })
  }
}

foreach ($field in (Read-ServiceNowIndexJsonArray -Path (Join-Path $IndexPath 'fields.json'))) {
  if ($matches.Count -ge $Limit) { break }
  if (Test-ServiceNowIndexMatch -Object $field -Needle $Text) {
    $matches.Add([pscustomobject]@{
      kind = 'field'
      table = 'sys_dictionary'
      sys_id = $field.sys_id
      name = "$($field.name).$($field.element)"
      label = $field.column_label
      target_table = $field.name
      updated = $field.sys_updated_on
      record = $field
    })
  }
}

foreach ($artifact in (Read-ServiceNowIndexJsonArray -Path (Join-Path $IndexPath 'artifacts.json'))) {
  if ($matches.Count -ge $Limit) { break }
  if ($artifact.PSObject.Properties.Name -contains 'error') { continue }
  if ((Test-ServiceNowIndexMatch -Object $artifact -Needle $Text) -or (Test-ServiceNowIndexMatch -Object $artifact.record -Needle $Text)) {
    $matches.Add([pscustomobject]@{
      kind = 'artifact'
      table = $artifact.artifact_table
      sys_id = $artifact.sys_id
      name = $artifact.name
      label = $artifact.name
      target_table = $artifact.target_table
      updated = $artifact.updated
      record = $artifact.record
    })
  }
}

[ordered]@{
  searched_at = (Get-Date).ToString('o')
  index_path = $IndexPath
  text = $Text
  count = $matches.Count
  matches = @($matches)
} | ConvertTo-Json -Depth 20
