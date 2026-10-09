$ErrorActionPreference='Stop'
$root='C:\Users\simen\.codex\skills\servicenow-pdi'
$table="$root\scripts\Invoke-ServiceNowTable.ps1"
$live=@{Profile='vaar_prod';EnvPath="$root\.env";AsObject=$true;ExcludeReferenceLink=$true}
. "$root\scripts\Resolve-ServiceNowConnection.ps1"
$connection=Resolve-ServiceNowConnection -Profile vaar_prod -EnvPath "$root\.env"
if($connection.Instance.TrimEnd('/') -ne 'https://varenergi.service-now.com'){throw 'Unexpected target instance.'}
$identity=(& "$root\scripts\Invoke-ServiceNowXploreScript.ps1" -Profile vaar_prod -EnvPath "$root\.env" -Script 'JSON.stringify({instance:gs.getProperty("instance_name"),user:gs.getUserName()});' -NoFixGsLog)|ConvertFrom-Json
if($identity.instance -ne 'varenergi' -or $identity.user -ne $connection.UserName){throw 'Target identity mismatch.'}
$story=@((& $table @live -Table rm_story -Query 'number=STRY0011747' -Fields 'sys_id,number,state' -Limit 2).result)
if($story.Count -ne 1){throw 'Story target ambiguous/missing.'}
$storyId=$story[0].sys_id
$storyState=$story[0].state
foreach($name in @('test-revalidation.json','revalidation-ui-proof.json')){
    $proof=Get-Content "$PSScriptRoot\$name" -Raw|ConvertFrom-Json
    if(!$proof.passed){throw "Validation did not pass: $name"}
}
$cleanup=Get-Content "$PSScriptRoot\revalidation-cleanup.json" -Raw|ConvertFrom-Json
if($cleanup.remaining -ne 0){throw 'Test cleanup incomplete.'}
$fileNames=@(
    'STRY0011747_TEST_20261009_01_Incident_modal.jpg',
    'STRY0011747_TEST_20261009_02_Incident_task_attachments.jpg',
    'STRY0011747_TEST_20261009_03_RITM_modal.jpg',
    'STRY0011747_TEST_20261009_04_Catalog_task_attachments.jpg'
)
$authorization=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $connection.UserName,$connection.Password)))
$headers=@{Authorization="Basic $authorization";Accept='application/json'}
$attachments=@()
foreach($name in $fileNames){
    $path=Join-Path $PSScriptRoot $name
    $file=Get-Item -LiteralPath $path
    if($file.Length -lt 1000 -or $file.Length -gt 5MB){throw 'Unexpected screenshot size.'}
    $existing=@((& $table @live -Table sys_attachment -Query "table_name=rm_story^table_sys_id=$storyId^file_name=$name" -Fields 'sys_id,file_name,size_bytes,content_type,table_sys_id' -Limit 2).result)
    if($existing.Count -gt 1){throw 'Attachment target ambiguous.'}
    if($existing.Count){$record=$existing[0]}else{
        $url="$($connection.Instance)/api/now/attachment/file?table_name=rm_story&table_sys_id=$storyId&file_name=$([uri]::EscapeDataString($name))"
        $uploaded=Invoke-RestMethod -Uri $url -Method POST -Headers $headers -ContentType 'image/jpeg' -InFile $path -MaximumRedirection 0 -TimeoutSec 60
        $record=$uploaded.result
        $uploaded|ConvertTo-Json -Depth 8|Set-Content "$PSScriptRoot\uploaded-$name.json"
    }
    $fresh=(& $table @live -Table sys_attachment -SysId $record.sys_id -Fields 'sys_id,file_name,size_bytes,content_type,table_name,table_sys_id').result
    if($fresh.table_name -ne 'rm_story' -or $fresh.table_sys_id -ne $storyId -or $fresh.file_name -ne $name -or [long]$fresh.size_bytes -ne $file.Length -or $fresh.content_type -ne 'image/jpeg'){throw 'Attachment metadata mismatch.'}
    $download="$PSScriptRoot\verified-$name"
    Invoke-WebRequest -Uri "$($connection.Instance)/api/now/attachment/$($record.sys_id)/file" -Method GET -Headers $headers -OutFile $download -MaximumRedirection 0 -TimeoutSec 60|Out-Null
    if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash){throw 'Uploaded screenshot bytes differ.'}
    $attachments+=@{sys_id=$record.sys_id;file_name=$name;bytes=$file.Length;verified=$true}
    $attachments|ConvertTo-Json -Depth 6|Set-Content "$PSScriptRoot\story-validation-attachments.json"
    [pscustomobject]@{file=$name;id=$record.sys_id;verified=$true}|ConvertTo-Json -Compress
}
$note=(Get-Content "$PSScriptRoot\validation-work-note.txt" -Raw).Trim()
$journals=@((& $table @live -Table sys_journal_field -Query "element_id=$storyId^element=work_notes^ORDERBYDESCsys_created_on" -Fields 'sys_id,value,sys_created_on' -Limit 3).result)
$matching=@($journals|Where-Object value -CEQ $note)
if(!$matching.Count){
    @{work_notes=$note}|ConvertTo-Json -Depth 3|Set-Content "$PSScriptRoot\validation-note-body.json"
    & $table @live -Method PATCH -Table rm_story -SysId $storyId -BodyPath "$PSScriptRoot\validation-note-body.json" -Fields 'sys_id,number,state'|Out-Null
}
$journals=@((& $table @live -Table sys_journal_field -Query "element_id=$storyId^element=work_notes^ORDERBYDESCsys_created_on" -Fields 'sys_id,value,sys_created_on' -Limit 3).result)
$matching=@($journals|Where-Object value -CEQ $note)
$freshStory=(& $table @live -Table rm_story -SysId $storyId -Fields 'sys_id,number,state').result
if($matching.Count -ne 1 -or $freshStory.state -ne $storyState){throw 'Work note/state verification failed.'}
@{story=$freshStory.number;storyId=$storyId;attachments=$attachments;workNote=$matching[0].sys_id;createdOn=$matching[0].sys_created_on;stateUnchanged=$true;verified=$true}|ConvertTo-Json -Depth 8|Set-Content "$PSScriptRoot\story-validation-published.json"
[pscustomobject]@{story=$freshStory.number;attachments=$attachments.Count;workNoteVerified=$true;stateUnchanged=$true}|ConvertTo-Json -Compress
