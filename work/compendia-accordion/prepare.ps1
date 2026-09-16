param([string]$Profile = 'vaar_dev', [string]$Instance = 'https://varenergidev.service-now.com')
$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot/../.."
$p = @{Profile=$Profile; Instance=$Instance; EnvPath='C:\Users\simen\Documents\Codex\ServiceNow\.env'}
$r = & "$root/scripts/Invoke-ServiceNowTable.ps1" @p -Table sys_script_include -Query 'name=VECompendiaKnowledgeSync' -Fields 'sys_id,name,script' -Limit 2 -AsObject
if (@($r.result).Count -ne 1) { throw 'Ambiguous Script Include' }
$record = $r.result[0]
$old = [string]$record.script
$needle = "  formatCollapsibles: function (html) {`n    var out = String(html || '');"
if (!$old.Contains($needle) -or $old.Contains('removeDuplicateCollapseMarkers:')) { throw 'Unexpected source version' }
$method = Get-Content "$PSScriptRoot/dedupe.js" -Raw
$new = $old.Replace($needle, $method + "`n  formatCollapsibles: function (html) {`n    var out = this.removeDuplicateCollapseMarkers(html);")
# Retain the exact live before-image for rollback and source-to-target comparison.
@{sys_id=$record.sys_id;script=$old} | ConvertTo-Json -Depth 4 | Set-Content "$PSScriptRoot/$Profile-before.json"
@{script=$new} | ConvertTo-Json -Depth 4 | Set-Content "$PSScriptRoot/$Profile-after.json"
Write-Output "Prepared $Profile $($record.sys_id): $($old.Length) -> $($new.Length) characters"
