param([Parameter(Mandatory)][ValidateSet('vaar_test','vaar_prod')][string]$Profile)
$ErrorActionPreference='Stop'
$root='C:\Users\simen\.codex\skills\servicenow-pdi'
$manifest=Get-Content "$PSScriptRoot\final-config-manifest.json" -Raw|ConvertFrom-Json
$targets=@($manifest|Where-Object action -EQ INSERT_OR_UPDATE|Select-Object table,id,fields)
$json=$targets|ConvertTo-Json -Compress -Depth 15
$script=@'
(function(){var targets=TARGETS;var matches=[],mismatches=[],systemFields=['sys_created_on','sys_created_by','sys_updated_on','sys_updated_by','sys_mod_count','sys_update_name','sys_tags','sys_customer_update'];function normalize(v){if(v===null||v===undefined)return '';v=String(v);return v==='true'?'1':v==='false'?'0':v;}
targets.forEach(function(t){var g=new GlideRecord(t.table);if(!g.get(t.id)){mismatches.push({table:t.table,id:t.id,error:'missing'});return;}var checked=0;Object.keys(t.fields).forEach(function(k){if(systemFields.indexOf(k)>-1||!g.isValidField(k))return;var expected=normalize(t.fields[k]),actual=normalize(g.getValue(k));if(expected!==actual)mismatches.push({table:t.table,id:t.id,field:k,expectedLength:expected.length,actualLength:actual.length});checked++;});matches.push({table:t.table,id:t.id,checkedFields:checked});});
var deletions=[];['incident','sc_req_item'].forEach(function(table){['sys_dictionary','sys_documentation'].forEach(function(target){var g=new GlideRecord(target);g.addQuery('name',table);g.addQuery('element','u_supplier');g.setLimit(2);g.query();if(g.hasNext())mismatches.push({table:target,field:table+'.u_supplier',error:'legacy field still exists'});deletions.push({table:target,target:table+'.u_supplier',absent:!g.hasNext()});});});
var ajax=new SupplierTaskAjax(),suppliers=ajax._suppliers();if(!suppliers.length)mismatches.push({error:'no supplier groups'});var activeValid=true;suppliers.forEach(function(s){var g=new GlideRecord('sys_user_group');if(!g.get(s.value)||g.getValue('active')!='1'||!ajax._isSupplierGroup(g))activeValid=false;});if(!activeValid)mismatches.push({error:'invalid supplier choice'});
return JSON.stringify({instance:gs.getProperty('instance_name'),matches:matches,deletions:deletions,supplierCount:suppliers.length,suppliersValid:activeValid,mismatches:mismatches,passed:mismatches.length===0});})();
'@
$script=$script.Replace('TARGETS',$json)
$response=& "$root\scripts\Invoke-ServiceNowXploreScript.ps1" -Profile $Profile -EnvPath "$root\.env" -Script $script -NoFixGsLog
$response|Set-Content "$PSScriptRoot\$Profile-final-verification.json"
$result=$response|ConvertFrom-Json
if(!$result.passed){$response;throw 'Installed configuration differs from final source.'}
[pscustomobject]@{instance=$result.instance;matchedRecords=$result.matches.Count;absentLegacyRecords=$result.deletions.Count;supplierChoices=$result.supplierCount;passed=$result.passed}|ConvertTo-Json -Compress
