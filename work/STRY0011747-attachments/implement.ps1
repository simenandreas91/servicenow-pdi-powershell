$ErrorActionPreference = 'Stop'
$root = 'C:\Users\simen\.codex\skills\servicenow-pdi'
$live = @{ Profile = 'vaar_dev'; EnvPath = "$root\.env"; ExcludeReferenceLink = $true; AsObject = $true }
$table = "$root\scripts\Invoke-ServiceNowTable.ps1"
$context = "$root\scripts\Set-ServiceNowUpdateSetContext.ps1"
$restore = "$root\scripts\Restore-ServiceNowPreferenceSnapshot.ps1"
$storyUrl = 'https://varenergi.service-now.com/rm_story.do?sys_id=fd7ac57f9fa70f5044f07b7c1724ab7b'
$items = @(
  @{ Table='sys_script_include'; Query='name=SupplierTaskAjax'; Field='script'; Scope='global'; Name='STRY0011747 - Always copy supplier task attachments' },
  @{ Table='sys_declarative_action_assignment'; Query='action_name=sow_create_supplier_task^table=incident'; Field='client_script'; Scope='sn_sow_inc'; Name='STRY0011747 - Incident supplier attachments read only' },
  @{ Table='sys_declarative_action_assignment'; Query='action_name=sow_ritm_create_supplier_task^table=sc_req_item'; Field='client_script'; Scope='sn_sow_req'; Name='STRY0011747 - RITM supplier attachments read only' }
)
$manifest = @()
foreach ($item in $items) {
  $existing = @((& $table @live -Table sys_update_set -Query ('name=' + $item.Name) -Limit 2).result)
  if ($existing.Count) { throw "Set already exists: $($item.Name). Inspect before resuming." }
  $records = @((& $table @live -Table $item.Table -Query $item.Query -Limit 2).result)
  if ($records.Count -ne 1) { throw "Expected one artifact for $($item.Query)" }
  $record = $records[0]
  $record | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath "$PSScriptRoot\before-$($record.sys_id).json"
  $before = [string]$record.($item.Field)
  if ($item.Table -eq 'sys_script_include') {
    $after = $before.Replace("        var includeAttachments = this._str('sysparm_include_attachments') == 'true';`n", '')
    $after = $after.Replace("        if (includeAttachments)`n            new GlideSysAttachment().copy(parentTable, parent.getUniqueValue(), childTable, childId);", "        new GlideSysAttachment().copy(parentTable, parent.getUniqueValue(), childTable, childId);")
    if ($after -match 'includeAttachments') { throw 'Attachment condition replacement failed.' }
  } else {
    $after = $before.Replace("                label: messages['Include attachments'],`n                value: false", "                label: messages['Include attachments'],`n                value: true,`n                readonly: true")
    $after = $after.Replace("            ajax.addParam('sysparm_include_attachments', getModalFieldValue(fieldValues, 'include_attachments'));`n", '')
  }
  if ($after -eq $before) { throw 'No code change was prepared.' }
  $snapshot = "$PSScriptRoot\preferences-$($record.sys_id).json"
  try {
    $ctx = (& $context -Profile vaar_dev -EnvPath "$root\.env" -Scope $item.Scope -Name $item.Name -Description "STRY0011747: $storyUrl`nLatest feedback: Include attachments is selected and read-only; all parent attachments are copied to the supplier task automatically." -SnapshotPath $snapshot) | ConvertFrom-Json
    if ($record.sys_scope -ne $ctx.scope_sys_id) { throw 'Scope does not match artifact.' }
    $body = @{ $item.Field = $after } | ConvertTo-Json -Depth 5
    $body | Set-Content -LiteralPath "$PSScriptRoot\body-$($record.sys_id).json"
    $saved = (& $table @live -Method PATCH -Table $item.Table -SysId $record.sys_id -BodyPath "$PSScriptRoot\body-$($record.sys_id).json").result
    $fresh = (& $table @live -Table $item.Table -SysId $record.sys_id).result
    if ($fresh.($item.Field) -cne $after) { throw 'Fresh source verification failed.' }
    $captureName = "$($item.Table)_$($record.sys_id)"
    $captures = @((& $table @live -Table sys_update_xml -Query "update_set=$($ctx.update_set_sys_id)^name=$captureName" -Limit 3).result)
    if ($captures.Count -ne 1 -or $captures[0].application -ne $record.sys_scope) { throw 'Natural update capture failed.' }
    $fresh | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath "$PSScriptRoot\after-$($record.sys_id).json"
    $manifest += @{ table=$item.Table; id=$record.sys_id; field=$item.Field; scope=$record.sys_scope; update_set=$ctx.update_set_sys_id; name=$item.Name; capture=$captureName }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$PSScriptRoot\manifest.json"
    [pscustomobject]@{ set=$item.Name; id=$ctx.update_set_sys_id; artifact=$record.sys_id; capture='verified' } | ConvertTo-Json -Compress
  } finally {
    if (Test-Path -LiteralPath $snapshot) { & $restore -Profile vaar_dev -EnvPath "$root\.env" -SnapshotPath $snapshot | Out-Null }
  }
}
