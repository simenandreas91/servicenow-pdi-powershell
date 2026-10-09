$ErrorActionPreference='Stop'
$root='C:\Users\simen\.codex\skills\servicenow-pdi'
$table="$root\scripts\Invoke-ServiceNowTable.ps1"
$live=@{Profile='vaar_dev';EnvPath="$root\.env";AsObject=$true;ExcludeReferenceLink=$true}
$scope='ff837553a1112010db4143775de96b71'
$layout='e0c2da40eb523010887bbc584952280e'
$oldId='2459ae435322301009d3ddeeff7b1259'
$name='STRY0011675 - Dedicated Close Complete primary action'
$existing=@((& $table @live -Table sys_update_set -Query "name=$name" -Limit 2).result)
if($existing.Count){throw 'Delivery set already exists; inspect before resuming.'}
$old=(& $table @live -Table sys_ux_m2m_action_layout_item -SysId $oldId).result
if($old.ux_form_action_layout -ne $layout -or $old.ux_form_action_layout_item -ne 'd4d82a435322301009d3ddeeff7b1285' -or $old.sys_scope -ne $scope -or $old.active -ne 'true'){throw 'Existing layout membership changed.'}
$old|ConvertTo-Json -Depth 12|Set-Content "$PSScriptRoot\before-membership.json"
$actions=@(
  @{action='0e829b1b5371301009d3ddeeff7b123b';label='Close Complete';name='STRY0011675 HR Close Complete primary';color='primary';order=100},
  @{action='6a72d71b5371301009d3ddeeff7b1279';label='Close Incomplete';name='STRY0011675 HR Close Incomplete secondary';color='secondary';order=110}
)
foreach($action in $actions){
  $record=(& $table @live -Table sys_ux_form_action -SysId $action.action).result
  if($record.name -ne $action.label -or $record.table -ne 'sn_hr_core_case' -or $record.sys_scope -ne $scope -or $record.active -ne 'true'){throw 'Existing closure action mismatch.'}
  $record|ConvertTo-Json -Depth 12|Set-Content "$PSScriptRoot\dependency-$($action.action).json"
}
$snapshot="$PSScriptRoot\dev-preferences.json"
try{
  $context=(& "$root\scripts\Set-ServiceNowUpdateSetContext.ps1" -Profile vaar_dev -EnvPath "$root\.env" -Scope sn_hr_agent_ws -Name $name -Description 'STRY0011675: https://varenergi.service-now.com/rm_story.do?sys_id=c792682a9f2b035044f07b7c1724abac. Separate the existing Close Complete and Close Incomplete actions: Close Complete is a dedicated primary button; Close Incomplete remains secondary. Preserve existing closure eligibility and behavior.' -SnapshotPath $snapshot)|ConvertFrom-Json
  if($context.scope_sys_id -ne $scope){throw 'Scope mismatch.'}
  $manifest=@()
  foreach($action in $actions){
    $itemBody=@{name=$action.name;label=$action.label;table='sn_hr_core_case';item_type='action';action=$action.action;color=$action.color;order=$action.order;active=$true;overflow=$false;sys_scope=$scope;description='Separate closure action preserving its existing eligibility and behavior.'}|ConvertTo-Json
    $item=(& $table @live -Method POST -Table sys_ux_form_action_layout_item -BodyJson $itemBody).result
    if(!$item.sys_id -or $item.sys_scope -ne $scope){throw 'Layout item creation/scope failed.'}
    $membershipBody=@{table='sn_hr_core_case';ux_form_action_layout=$layout;ux_form_action_layout_item=$item.sys_id;order=$action.order;active=$true;display_type='0';variant=$action.color;sys_scope=$scope}|ConvertTo-Json
    $membership=(& $table @live -Method POST -Table sys_ux_m2m_action_layout_item -BodyJson $membershipBody).result
    if(!$membership.sys_id -or $membership.sys_scope -ne $scope){throw 'Layout membership creation/scope failed.'}
    $manifest+=@{table='sys_ux_form_action_layout_item';id=$item.sys_id;expected=$item}
    $manifest+=@{table='sys_ux_m2m_action_layout_item';id=$membership.sys_id;expected=$membership}
    @{update_set=$context.update_set_sys_id;scope=$scope;name=$name;records=$manifest}|ConvertTo-Json -Depth 20|Set-Content "$PSScriptRoot\manifest.json"
  }
  $disabled=(& $table @live -Method PATCH -Table sys_ux_m2m_action_layout_item -SysId $oldId -BodyJson '{"active":false}').result
  $manifest+=@{table='sys_ux_m2m_action_layout_item';id=$oldId;expected=$disabled}
  foreach($record in $manifest){
    $capture=@((& $table @live -Table sys_update_xml -Query "update_set=$($context.update_set_sys_id)^name=$($record.table)_$($record.id)" -Limit 2).result)
    if($capture.Count -ne 1 -or $capture[0].application -ne $scope -or $capture[0].action -ne 'INSERT_OR_UPDATE'){throw 'Natural capture verification failed.'}
    $fresh=(& $table @live -Table $record.table -SysId $record.id).result
    if($fresh.sys_scope -ne $scope){throw 'Fresh scope check failed.'}
    $record.expected=$fresh
  }
  $captures=@((& $table @live -Table sys_update_xml -Query "update_set=$($context.update_set_sys_id)" -Limit 10).result)
  if($captures.Count -ne 5){throw 'Unexpected source package count.'}
  $captures|ConvertTo-Json -Depth 15|Set-Content "$PSScriptRoot\source-captures.json"
  @{update_set=$context.update_set_sys_id;scope=$scope;name=$name;records=$manifest}|ConvertTo-Json -Depth 20|Set-Content "$PSScriptRoot\manifest.json"
  [pscustomobject]@{updateSet=$context.update_set_sys_id;name=$name;scope=$scope;captures=$captures.Count}|ConvertTo-Json -Compress
}finally{
  if(Test-Path -LiteralPath $snapshot){& "$root\scripts\Restore-ServiceNowPreferenceSnapshot.ps1" -Profile vaar_dev -EnvPath "$root\.env" -SnapshotPath $snapshot|Out-Null}
}
