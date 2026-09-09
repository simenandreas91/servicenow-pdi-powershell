param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')]
  [string]$Table,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-fA-F]{32}$')]
  [string]$SysId,

  [string]$UpdateSetSysId,
  [string]$Profile,
  [string]$EnvPath,
  [string]$Instance
)

$ErrorActionPreference = 'Stop'
$xploreScript = Join-Path $PSScriptRoot 'Invoke-ServiceNowXploreScript.ps1'
$updateName = "${Table}_${SysId}"
if ($UpdateSetSysId -and $UpdateSetSysId -notmatch '^[0-9a-fA-F]{32}$') { throw 'UpdateSetSysId must be a 32-character sys_id.' }

$serverScript = @"
(function () {
  var result = { saved: false, updateXml: [] };
  var gr = new GlideRecord('$Table');
  if (!gr.get('$SysId')) {
    result.error = 'record_not_found';
    gs.print('SN_RESULT_START' + JSON.stringify(result) + 'SN_RESULT_END');
    return;
  }

  if (gr.isValidField('sys_update_name') && gr.getValue('sys_update_name')) {
    result.updateName = gr.getValue('sys_update_name');
  } else {
    result.updateName = '$updateName';
  }
  new GlideUpdateManager2().saveRecord(gr);
  result.saved = true;

  var grUpdate = new GlideRecord('sys_update_xml');
  grUpdate.addQuery('name', result.updateName);
  grUpdate.orderByDesc('sys_updated_on');
  grUpdate.setLimit(3);
  grUpdate.query();
  while (grUpdate.next()) {
    result.updateXml.push({
      sys_id: grUpdate.getUniqueValue(),
      update_set: grUpdate.getValue('update_set'),
      application: grUpdate.getValue('application'),
      target_name: grUpdate.getValue('target_name'),
      created: grUpdate.getValue('sys_created_on')
    });
  }

  gs.print('SN_RESULT_START' + JSON.stringify(result) + 'SN_RESULT_END');
})();
"@

$xParams = @{ Script = $serverScript }
if ($Profile) { $xParams.Profile = $Profile }
if ($EnvPath) { $xParams.EnvPath = $EnvPath }
if ($Instance) { $xParams.Instance = $Instance }
$saveResult = (& $xploreScript @xParams) | ConvertFrom-Json

if (-not $saveResult.saved -or -not $saveResult.updateXml) {
  throw 'The application file was not captured. Inspect the record and capture eligibility before retrying.'
}
if ($UpdateSetSysId) {
  $latest = @($saveResult.updateXml)[0]
  if ($latest.update_set -ne $UpdateSetSysId) {
    throw "Capture landed in update set '$($latest.update_set)', expected '$UpdateSetSysId'. Correct the execution scope/update-set context and recapture; customer updates were not moved."
  }
}

$saveResult | ConvertTo-Json -Depth 12
