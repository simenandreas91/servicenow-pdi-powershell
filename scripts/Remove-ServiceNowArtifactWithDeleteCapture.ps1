param(
  [Parameter(Mandatory = $true)]
  [string]$Table,

  [Parameter(Mandatory = $true)]
  [string]$SysId,

  [Parameter(Mandatory = $true)]
  [string]$UpdateSetSysId,

  [Parameter(Mandatory = $true)]
  [string]$ExpectedApplication,

  [string]$Profile,
  [string]$EnvPath,
  [string]$Instance
)

$ErrorActionPreference = 'Stop'
$tableScript = Join-Path $PSScriptRoot 'Invoke-ServiceNowTable.ps1'
$saveScript = Join-Path $PSScriptRoot 'Save-ServiceNowCustomerUpdate.ps1'

function Invoke-TableJson {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$TableName,
    [string]$RecordSysId,
    [string]$Query,
    [string]$Fields,
    [string]$BodyJson,
    [int]$Limit = 10
  )

  $params = @{
    Method = $Method
    Table = $TableName
    DisplayValue = 'false'
    ExcludeReferenceLink = $true
    Limit = $Limit
  }
  if ($RecordSysId) { $params.SysId = $RecordSysId }
  if ($Query) { $params.Query = $Query }
  if ($Fields) { $params.Fields = $Fields }
  if ($BodyJson) { $params.BodyJson = $BodyJson }
  if ($Profile) { $params.Profile = $Profile }
  if ($EnvPath) { $params.EnvPath = $EnvPath }
  if ($Instance) { $params.Instance = $Instance }
  return (& $tableScript @params | ConvertFrom-Json)
}

$record = (Invoke-TableJson -Method GET -TableName $Table -RecordSysId $SysId `
  -Fields 'sys_id,sys_scope,sys_package,sys_created_by,sys_created_on,sys_updated_by,sys_updated_on,sys_name,sys_update_name').result
if (-not $record) {
  throw "Record not found: $Table/$SysId"
}

$actualApplication = if ($record.sys_scope) { [string]$record.sys_scope } else { [string]$record.sys_package }
if ($actualApplication -ne $ExpectedApplication) {
  throw "Application mismatch for $Table/$SysId. Expected $ExpectedApplication; found $actualApplication."
}
$updateName = if ($record.sys_update_name) { [string]$record.sys_update_name } else { "${Table}_${SysId}" }

$saveParams = @{
  Table = $Table
  SysId = $SysId
  UpdateSetSysId = $UpdateSetSysId
}
if ($Profile) { $saveParams.Profile = $Profile }
if ($EnvPath) { $saveParams.EnvPath = $EnvPath }
if ($Instance) { $saveParams.Instance = $Instance }
$saved = (& $saveScript @saveParams) | ConvertFrom-Json
if (-not $saved.saved) {
  throw "GlideUpdateManager2 did not capture $Table/$SysId."
}

$capture = (Invoke-TableJson -Method GET -TableName 'sys_update_xml' `
  -Query "name=$updateName^ORDERBYDESCsys_updated_on" `
  -Fields 'sys_id,name,action,application,payload,target_name,type,update_set' -Limit 1).result
if (-not $capture) {
  throw "Customer update not found in update set ${UpdateSetSysId}: $updateName"
}
if ([string]$capture.application -ne $ExpectedApplication) {
  throw "Captured application mismatch for $updateName. Expected $ExpectedApplication; found $($capture.application)."
}

[xml]$payload = [string]$capture.payload
$targetNode = @($payload.record_update.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })[0]
if (-not $targetNode) {
  throw "Unable to locate the target record element in the customer update payload for $updateName."
}
$targetNode.SetAttribute('action', 'DELETE')

$stringWriter = [System.IO.StringWriter]::new([System.Globalization.CultureInfo]::InvariantCulture)
$xmlWriterSettings = [System.Xml.XmlWriterSettings]::new()
$xmlWriterSettings.OmitXmlDeclaration = $false
$xmlWriterSettings.Indent = $false
$xmlWriterSettings.Encoding = [System.Text.UTF8Encoding]::new($false)
$xmlWriter = [System.Xml.XmlWriter]::Create($stringWriter, $xmlWriterSettings)
try {
  $payload.Save($xmlWriter)
} finally {
  $xmlWriter.Dispose()
}
$deletePayload = $stringWriter.ToString()
$stringWriter.Dispose()
$deletePayload = $deletePayload -replace 'encoding="utf-16"', 'encoding="UTF-8"'

$patchBody = @{
  action = 'DELETE'
  payload = $deletePayload
  update_set = $UpdateSetSysId
} | ConvertTo-Json -Compress
Invoke-TableJson -Method PATCH -TableName 'sys_update_xml' -RecordSysId $capture.sys_id `
  -Fields 'sys_id,name,action,application,payload,target_name,type,update_set' -BodyJson $patchBody | Out-Null

Invoke-TableJson -Method DELETE -TableName $Table -RecordSysId $SysId | Out-Null
$remaining = (Invoke-TableJson -Method GET -TableName $Table -Query "sys_id=$SysId" -Fields 'sys_id' -Limit 1).result
if ($remaining) {
  throw "Deletion verification failed: $Table/$SysId still exists."
}

$verifiedCapture = (Invoke-TableJson -Method GET -TableName 'sys_update_xml' -RecordSysId $capture.sys_id `
  -Fields 'sys_id,name,action,application,payload,target_name,type,update_set').result
[xml]$verifiedPayload = [string]$verifiedCapture.payload
$verifiedNode = @($verifiedPayload.record_update.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })[0]
if ($verifiedCapture.action -ne 'DELETE' -or $verifiedNode.GetAttribute('action') -ne 'DELETE' -or `
    [string]$verifiedCapture.update_set -ne $UpdateSetSysId) {
  throw "DELETE customer update verification failed for $updateName."
}

[pscustomobject]@{
  deleted = $true
  table = $Table
  sys_id = $SysId
  update_name = $updateName
  customer_update = $verifiedCapture.sys_id
  action = $verifiedCapture.action
  application = $verifiedCapture.application
  update_set = $verifiedCapture.update_set
  target_name = $verifiedCapture.target_name
  type = $verifiedCapture.type
} | ConvertTo-Json -Depth 5
