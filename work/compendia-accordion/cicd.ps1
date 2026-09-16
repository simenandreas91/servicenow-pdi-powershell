param([string]$Profile,[string]$Instance,[string]$Path,[string]$Method='POST')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../../scripts/Resolve-ServiceNowConnection.ps1"
$c=Resolve-ServiceNowConnection -Profile $Profile -Instance $Instance -EnvPath 'C:\Users\simen\Documents\Codex\ServiceNow\.env'
$auth=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $c.UserName,$c.Password)))
Invoke-RestMethod -Uri ($c.Instance+'/api/sn_cicd/'+$Path) -Method $Method -ContentType 'application/json' -Headers @{Authorization="Basic $auth";Accept='application/json'} -TimeoutSec 120 | ConvertTo-Json -Depth 12
