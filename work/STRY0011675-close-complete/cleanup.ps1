param([Parameter(Mandatory)][ValidateSet('vaar_dev','vaar_test')][string]$Profile)
$ErrorActionPreference='Stop'
$root='C:\Users\simen\.codex\skills\servicenow-pdi'
$files=@("$PSScriptRoot\$Profile-agent-fixture.json")
if($Profile -eq 'vaar_dev'){$files+="$PSScriptRoot\dev-fixture.json"}
$fixtures=@($files|ForEach-Object {Get-Content -LiteralPath $_ -Raw|ConvertFrom-Json})
$json=$fixtures|ConvertTo-Json -AsArray -Compress
$script=@'
(function(){var fixtures=FIXTURES;var expected=EXPECTED;if(gs.getProperty('instance_name')!=expected)throw 'Wrong cleanup environment';
fixtures.forEach(function(f){var g=new GlideRecord('sn_hr_core_case');if(!g.get(f.id)||String(g.getValue('short_description')).indexOf('STRY0011675 - ')!==0)throw 'Fixture identity mismatch';var t=new GlideRecord('sn_hr_core_task');t.addQuery('parent',f.id);t.setLimit(1);t.query();if(t.hasNext())throw 'Unexpected child task; inspect before cleanup';});
var slaIds=[];fixtures.forEach(function(f){var s=new GlideRecord('task_sla');s.addQuery('task',f.id);s.setLimit(11);s.query();var count=0;while(s.next()){slaIds.push(s.getUniqueValue());count++;}if(count>10)throw 'Unexpected test SLA count';});
slaIds.forEach(function(id){var s=new GlideRecord('task_sla');if(s.get(id)){s.setWorkflow(false);s.deleteRecord();}});
fixtures.forEach(function(f){var g=new GlideRecord('sn_hr_core_case');g.get(f.id);var a=new GlideSysAttachment().getAttachments('sn_hr_core_case',f.id);while(a.next())new GlideSysAttachment().deleteAttachment(a.getUniqueValue());g.setWorkflow(false);g.deleteRecord();var j=new GlideRecord('sys_journal_field');j.addQuery('element_id',f.id);j.setWorkflow(false);j.deleteMultiple();});var remaining=0;fixtures.forEach(function(f){var g=new GlideRecord('sn_hr_core_case');if(g.get(f.id))remaining++;var a=new GlideRecord('sys_attachment');a.addQuery('table_sys_id',f.id);a.setLimit(1);a.query();if(a.hasNext())remaining++;});return JSON.stringify({instance:expected,removed:fixtures.length,remaining:remaining});})();
'@
$expected=if($Profile -eq 'vaar_dev'){'varenergidev'}else{'varenergitest'}
$script=$script.Replace('FIXTURES',$json).Replace('EXPECTED',("'"+$expected+"'"))
$response=& "$root\scripts\Invoke-ServiceNowXploreScript.ps1" -Profile $Profile -EnvPath "$root\.env" -Scope sn_hr_core -Script $script -NoFixGsLog
$response|Set-Content "$PSScriptRoot\$Profile-cleanup.json"
$response
