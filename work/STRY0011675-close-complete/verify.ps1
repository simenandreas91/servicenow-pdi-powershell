param([Parameter(Mandatory)][ValidateSet('vaar_dev','vaar_test')][string]$Profile)
$ErrorActionPreference='Stop'
$root='C:\Users\simen\.codex\skills\servicenow-pdi'
$live=@{Profile=$Profile;EnvPath="$root\.env";AsObject=$true;ExcludeReferenceLink=$true}
$manifest=Get-Content "$PSScriptRoot\manifest.json" -Raw|ConvertFrom-Json
$checked=@()
foreach($entry in $manifest.records){
    $actual=(& "$root\scripts\Invoke-ServiceNowTable.ps1" @live -Table $entry.table -SysId $entry.id).result
    $fields=if($entry.table -eq 'sys_ux_form_action_layout_item'){@('name','label','item_type','action','layout_group','color','order','overflow','active','sys_scope','table')}else{@('ux_form_action_layout','ux_form_action_layout_item','variant','display_type','order','active','sys_scope','table')}
    foreach($field in $fields){if([string]$actual.$field -cne [string]$entry.expected.$field){throw "Record mismatch: $($entry.id).$field"}}
    $checked+=@{table=$entry.table;id=$entry.id;fields=$fields.Count}
}
$checked|ConvertTo-Json -Depth 5|Set-Content "$PSScriptRoot\$Profile-configuration-proof.json"
[pscustomobject]@{profile=$Profile;records=$checked.Count;passed=$true}|ConvertTo-Json -Compress
