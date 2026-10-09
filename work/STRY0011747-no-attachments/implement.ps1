$ErrorActionPreference='Stop'
$root='C:\Users\simen\.codex\skills\servicenow-pdi'
$table="$root\scripts\Invoke-ServiceNowTable.ps1"
$live=@{Profile='vaar_dev';EnvPath="$root\.env";AsObject=$true;ExcludeReferenceLink=$true}
$items=@(
    @{table='sys_script_include';query='name=SupplierTaskAjax';field='script';scope='global';name='STRY0011747 - Supplier tasks without parent attachments'},
    @{table='sys_declarative_action_assignment';query='action_name=sow_create_supplier_task^table=incident';field='client_script';scope='sn_sow_inc';name='STRY0011747 - Incident supplier modal without attachments'},
    @{table='sys_declarative_action_assignment';query='action_name=sow_ritm_create_supplier_task^table=sc_req_item';field='client_script';scope='sn_sow_req';name='STRY0011747 - RITM supplier modal without attachments'}
)
$checkbox=@'
            }, {
                type: 'boolean',
                name: 'include_attachments',
                label: messages['Include attachments'],
                value: true,
                readonly: true
'@
$checkbox=$checkbox.Replace("`r`n","`n")+"`n"
$manifest=@()
foreach($item in $items){
    $sets=@((& $table @live -Table sys_update_set -Query ('name='+$item.name) -Limit 2).result)
    if($sets.Count){throw 'Matching update set already exists; inspect before resuming.'}
    $records=@((& $table @live -Table $item.table -Query $item.query -Limit 2).result)
    if($records.Count -ne 1){throw 'Expected one exact artifact.'}
    $record=$records[0]
    $record|ConvertTo-Json -Depth 15|Set-Content "$PSScriptRoot\before-$($record.sys_id).json"
    $before=[string]$record.($item.field)
    if($item.table -eq 'sys_script_include'){
        $copy="        new GlideSysAttachment().copy(parentTable, parent.getUniqueValue(), childTable, childId);`n"
        if(($before.Split($copy,[StringSplitOptions]::None).Count-1) -ne 1){throw 'Expected exactly one attachment copy statement.'}
        $after=$before.Replace($copy,'')
        if($after -match 'GlideSysAttachment|include_attachments'){throw 'Attachment code remains.'}
    }else{
        if(($before.Split($checkbox,[StringSplitOptions]::None).Count-1) -ne 1){throw 'Checkbox block has changed.'}
        $after=$before.Replace($checkbox,'').Replace(", 'Include attachments'",'')
        if($after -match 'include_attachments|Include attachments'){throw 'Checkbox references remain.'}
    }
    if($before -ceq $after){throw 'No change prepared.'}
    $snapshot="$PSScriptRoot\preferences-$($record.sys_id).json"
    try{
        $context=(& "$root\scripts\Set-ServiceNowUpdateSetContext.ps1" -Profile vaar_dev -EnvPath "$root\.env" -Scope $item.scope -Name $item.name -Description 'STRY0011747: https://varenergi.service-now.com/rm_story.do?sys_id=fd7ac57f9fa70f5044f07b7c1724ab7b. Approved feedback dated 9 October 2026: remove Include attachments from the Incident/RITM modal and do not copy parent attachments to newly created supplier tasks.' -SnapshotPath $snapshot)|ConvertFrom-Json
        if($context.scope_sys_id -ne $record.sys_scope){throw 'Scope mismatch.'}
        @{$item.field=$after}|ConvertTo-Json -Depth 3|Set-Content "$PSScriptRoot\body-$($record.sys_id).json"
        & $table @live -Method PATCH -Table $item.table -SysId $record.sys_id -BodyPath "$PSScriptRoot\body-$($record.sys_id).json"|Out-Null
        $fresh=(& $table @live -Table $item.table -SysId $record.sys_id).result
        if($fresh.($item.field) -cne $after){throw 'Fresh artifact verification failed.'}
        $captures=@((& $table @live -Table sys_update_xml -Query "update_set=$($context.update_set_sys_id)" -Limit 3).result)
        if($captures.Count -ne 1 -or $captures[0].name -ne "$($item.table)_$($record.sys_id)" -or $captures[0].application -ne $record.sys_scope -or $captures[0].action -ne 'INSERT_OR_UPDATE'){throw 'Capture audit failed.'}
        $fresh|ConvertTo-Json -Depth 15|Set-Content "$PSScriptRoot\after-$($record.sys_id).json"
        $manifest+=@{table=$item.table;id=$record.sys_id;field=$item.field;scope=$record.sys_scope;update_set=$context.update_set_sys_id;name=$item.name}
        $manifest|ConvertTo-Json -AsArray -Depth 8|Set-Content "$PSScriptRoot\manifest.json"
        [pscustomobject]@{name=$item.name;updateSet=$context.update_set_sys_id;capture='verified'}|ConvertTo-Json -Compress
    }finally{
        if(Test-Path -LiteralPath $snapshot){& "$root\scripts\Restore-ServiceNowPreferenceSnapshot.ps1" -Profile vaar_dev -EnvPath "$root\.env" -SnapshotPath $snapshot|Out-Null}
    }
}
