param(
  [Parameter(Mandatory)][ValidateSet('vaar_test','vaar_prod')][string]$Profile,
  [Parameter(Mandatory)][ValidateSet('vaar_dev','vaar_test')][string]$SourceProfile,
  [Parameter(Mandatory)][string]$SetsPath,
  [switch]$Commit
)
$ErrorActionPreference='Stop'
$root='C:\Users\simen\.codex\skills\servicenow-pdi'
$table="$root\scripts\Invoke-ServiceNowTable.ps1"
$api="$PSScriptRoot\cicd.ps1"
$target=@{Profile=$Profile;EnvPath="$root\.env";AsObject=$true;ExcludeReferenceLink=$true}
$source=@{Profile=$SourceProfile;EnvPath="$root\.env";AsObject=$true;ExcludeReferenceLink=$true}
$sourceUrl=if($SourceProfile -eq 'vaar_dev'){'https://varenergidev.service-now.com/'}else{'https://varenergitest.service-now.com/'}
$connections=@((& $table @target -Table sys_update_set_source -Query "active=true^url=$sourceUrl" -Limit 2).result)
if($connections.Count -ne 1){throw 'Expected exactly one active Update Source.'}
$connectionId=$connections[0].sys_id
$sets=Get-Content -LiteralPath $SetsPath -Raw | ConvertFrom-Json
function Wait-Progress($response){
  $id=$response.result.links.progress.id
  if(!$id){return $response}
  if($id -notmatch '^[a-f0-9]{32}$'){throw 'Invalid progress identifier.'}
  for($i=0;$i -lt 120;$i++){
    $progress=(& $api -Profile $Profile -Action progress -Id $id)|ConvertFrom-Json
    if($progress.result.status -eq '2') {return $progress}
    if($progress.result.status -notin @('0','1')){throw ('Worker failed: '+($progress|ConvertTo-Json -Depth 8 -Compress))}
    Start-Sleep -Seconds 2
  }
  throw "Progress timed out; inspect $id before retrying."
}
$evidence=@()
foreach($set in $sets){
  $sourceId=$set.update_set
  $sourceSet=(& $table @source -Table sys_update_set -SysId $sourceId).result
  if($sourceSet.state -ne 'complete'){throw 'Source set must be complete.'}
  $sourceUpdates=@((& $table @source -Table sys_update_xml -Query "update_set=$sourceId" -Limit 200).result)
  if(!$sourceUpdates.Count -or $sourceUpdates.Count -ge 200){throw 'Unexpected/unbounded source update count.'}
  $remote=@((& $table @target -Table sys_remote_update_set -Query "remote_sys_id=$sourceId^update_source=$connectionId" -Limit 2).result)
  if($remote.Count -gt 1){throw 'Remote set ambiguous.'}
  if(!$remote.Count){
    $response=(& $api -Profile $Profile -Action retrieve -Id $sourceId -UpdateSourceId $connectionId)|ConvertFrom-Json
    $response|ConvertTo-Json -Depth 15|Set-Content "$PSScriptRoot\$Profile-retrieve-$sourceId.json"
    Wait-Progress $response|ConvertTo-Json -Depth 15|Set-Content "$PSScriptRoot\$Profile-retrieved-$sourceId.json"
    $remote=@((& $table @target -Table sys_remote_update_set -Query "remote_sys_id=$sourceId^update_source=$connectionId" -Limit 2).result)
  }
  if($remote.Count -ne 1){throw 'Expected one retrieved set.'}
  $remote=$remote[0]
  if($remote.state -notin @('previewed','committed')){
    $response=(& $api -Profile $Profile -Action preview -Id $remote.sys_id)|ConvertFrom-Json
    Wait-Progress $response|Out-Null
    $remote=(& $table @target -Table sys_remote_update_set -SysId $remote.sys_id).result
  }
  if($remote.state -notin @('previewed','committed')){throw 'Preview did not finish.'}
  $problems=@((& $table @target -Table sys_update_preview_problem -Query "remote_update_set=$($remote.sys_id)" -Limit 200).result)
  $problems|ConvertTo-Json -Depth 15|Set-Content "$PSScriptRoot\$Profile-problems-$sourceId.json"
  if($problems.Count){throw "Preview problems on $($remote.name); inspect before commit."}
  $remoteUpdates=@((& $table @target -Table sys_update_xml -Query "remote_update_set=$($remote.sys_id)" -Limit 200).result)
  if($sourceUpdates.Count -ne $remoteUpdates.Count){throw 'Source and remote counts differ.'}
  foreach($row in $sourceUpdates){
    $match=@($remoteUpdates|Where-Object name -EQ $row.name)
    if($match.Count -ne 1 -or $match[0].action -ne $row.action -or $match[0].application -ne $row.application -or $match[0].payload -cne $row.payload){throw "Transport differs for $($row.name)."}
  }
  $entry=@{name=$sourceSet.name;source=$sourceId;remote=$remote.sys_id;count=$sourceUpdates.Count;previewProblems=0;state=$remote.state;local=$null}
  if($Commit -and $remote.state -ne 'committed'){
    $response=(& $api -Profile $Profile -Action commit -Id $remote.sys_id)|ConvertFrom-Json
    $response|ConvertTo-Json -Depth 15|Set-Content "$PSScriptRoot\$Profile-commit-$sourceId.json"
    Wait-Progress $response|Out-Null
    $remote=(& $table @target -Table sys_remote_update_set -SysId $remote.sys_id).result
    if($remote.state -ne 'committed'){throw 'Commit did not finish.'}
  }
  if($remote.state -eq 'committed'){
    $local=@((& $table @target -Table sys_update_set -Query "name=$($sourceSet.name)^application=$($sourceSet.application)" -Limit 2).result)
    if($local.Count -ne 1){throw 'Committed local set ambiguous/missing.'}
    $logs=@((& $table @target -Table sys_update_set_log -Query "update_set=$($local[0].sys_id)" -Limit 200).result)
    $logs|ConvertTo-Json -Depth 15|Set-Content "$PSScriptRoot\$Profile-logs-$sourceId.json"
    $bad=@($logs|Where-Object { $_.status -match 'error|warning' })
    if($bad.Count){throw 'Commit logs contain Error/Warning entries.'}
    $localUpdates=@((& $table @target -Table sys_update_xml -Query "update_set=$($local[0].sys_id)" -Limit 200).result)
    if($localUpdates.Count -ne $sourceUpdates.Count){throw 'Committed customer update count differs.'}
    $entry.local=$local[0].sys_id
    $entry.state='committed'
    $entry.logs=$logs.Count
  }
  $evidence+=$entry
  $evidence|ConvertTo-Json -Depth 10|Set-Content "$PSScriptRoot\$Profile-promotion.json"
  $entry|ConvertTo-Json -Depth 5 -Compress
}
