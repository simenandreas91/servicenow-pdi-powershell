param([Parameter(Mandatory)][ValidateSet('vaar_dev','vaar_test')][string]$Profile)
$ErrorActionPreference='Stop'
$root='C:\Users\simen\.codex\skills\servicenow-pdi'
$script=@'
(function(){
var instance=gs.getProperty('instance_name');if(instance!='varenergidev'&&instance!='varenergitest')throw 'Non-production only';
function one(table,field,value){var g=new GlideRecord(table);g.addQuery(field,value);g.addActiveQuery();g.setLimit(2);g.query();if(!g.next())throw 'Missing '+table;var id=g.getUniqueValue();if(g.next())throw 'Ambiguous '+table;return id;}
var owner=one('sys_user','user_name','TEST_HRA_01'),service=one('sn_hr_core_service','name','HR General Inquiry');
var c=new GlideRecord('sn_hr_core_case');c.initialize();c.short_description='STRY0011675 - non-admin closure validation';c.description='Controlled validation of dedicated primary and secondary HR closure buttons.';c.hr_service=service;c.opened_for=owner;c.subject_person=owner;c.assigned_to=owner;c.state=18;c.u_inquiry_category='other';c.skip_automatic_user_acceptance_state=true;c.sla_suspended=false;c.setWorkflow(false);var id=c.insert();if(!id)throw 'Case insert failed';return JSON.stringify({instance:instance,id:String(id),number:c.getValue('number'),owner:owner,ownerName:'TEST_HRA_01',service:service,state:c.getValue('state')});
})();
'@
$response=& "$root\scripts\Invoke-ServiceNowXploreScript.ps1" -Profile $Profile -EnvPath "$root\.env" -Scope sn_hr_core -Script $script -NoFixGsLog
$result=$response|ConvertFrom-Json
if(!$result.id){throw 'Fixture creation failed.'}
$response|Set-Content "$PSScriptRoot\$Profile-agent-fixture.json"
$response
