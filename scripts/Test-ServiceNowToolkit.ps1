#requires -Version 7.0
# Offline regression suite: shadows both HTTP cmdlets and uses synthetic credentials.
param()
$ErrorActionPreference = 'Stop'
$toolkitRoot = $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sn-toolkit-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$state = @{ calls = 0; writes = 0; sleeps = 0; handler = $null; webHandler = $null }
$passed = 0

function Assert-True($Condition, [string]$Message) {
  if (-not $Condition) { throw "Assertion failed: $Message" }
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
  $caught = $null
  try { & $Action | Out-Null } catch { $caught = $_ }
  Assert-True ($null -ne $caught) 'Expected an error.'
  Assert-True ($caught.Exception.Message -like $Pattern) "Unexpected error: $($caught.Exception.Message)"
}
function Test-Case([string]$Name, [scriptblock]$Action) {
  $state.calls = 0; $state.writes = 0; $state.sleeps = 0
  $state.handler = { param($Request) @{ data = [pscustomobject]@{ result = @() }; headers = @{} } }
  $state.webHandler = $null
  & $Action
  $script:passed++
  Write-Output "PASS $Name"
}
function Invoke-RestMethod {
  [CmdletBinding()]
  param($Uri, $Headers, $Method, $Body, $ContentType, $TimeoutSec, $OperationTimeoutSeconds,
    $MaximumRedirection, $ResponseHeadersVariable)
  $state.calls++
  if ($Method -ne 'GET') { $state.writes++ }
  $reply = & $state.handler $PSBoundParameters
  if ($ResponseHeadersVariable) { Set-Variable -Name $ResponseHeadersVariable -Value $reply.headers -Scope 1 }
  return $reply.data
}
function Invoke-WebRequest {
  [CmdletBinding()]
  param($Uri, $Method, $Headers, $Body, $ContentType, $MaximumRedirection, [switch]$SkipHttpErrorCheck)
  if (-not $state.webHandler) { throw 'Unexpected web request blocked by offline suite.' }
  return (& $state.webHandler $PSBoundParameters)
}
function Start-Sleep { param($Seconds) $state.sleeps += $Seconds }
function Write-FixtureEnv([string]$Name, [string]$Origin, [string]$User = 'fixture_user') {
  $fixturePath = Join-Path $testRoot "$Name.env"
  @("SN_QA_INSTANCE=$Origin", "SN_QA_USER=$User", 'SN_QA_PASS=synthetic_password', 'SN_INSTANCE=https://generic.example.invalid') |
    Set-Content -LiteralPath $fixturePath -Encoding UTF8
  return $fixturePath
}
function New-HttpFailure([int]$Status, [int]$RetryAfter = 0) {
  $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)
  if ($RetryAfter) { $response.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([timespan]::FromSeconds($RetryAfter)) }
  return [Microsoft.PowerShell.Commands.HttpResponseException]::new('synthetic HTTP failure', $response)
}

try {
  $envA = Write-FixtureEnv 'a' 'https://a.example.invalid'
  $envB = Write-FixtureEnv 'b' 'https://b.example.invalid'
  $envC = Write-FixtureEnv 'c' 'https://a.example.invalid' 'second_user'
  $table = Join-Path $toolkitRoot 'Invoke-ServiceNowTable.ps1'
  $argsA = @{ Profile = 'qa'; EnvPath = $envA }
  . (Join-Path $toolkitRoot 'Resolve-ServiceNowConnection.ps1')
  . (Join-Path $toolkitRoot '_ServiceNowToolkitCommon.ps1')

  Test-Case 'nearest ancestor .env and named-profile isolation' {
    $nested = Join-Path $testRoot 'workspace/child/grandchild'
    New-Item -ItemType Directory -Path $nested -Force | Out-Null
    $parentEnv = Join-Path $testRoot 'workspace/.env'
    Set-Content -LiteralPath $parentEnv -Value '# synthetic fixture'
    Push-Location $nested
    try { Assert-True ((Get-ServiceNowDotEnvPath) -eq $parentEnv) 'Parent .env was not discovered.' }
    finally { Pop-Location }
    Assert-Throws { Resolve-ServiceNowConnection -Profile qa_offline_missing -EnvPath $envA } '*named profile instance*'
    Assert-Throws { Resolve-ServiceNowConnection @argsA -Instance 'http://a.example.invalid' } '*HTTPS origin*'
  }

  Test-Case 'PDI_2 uses its own destination and long credential keys' {
    $secondPdiEnv = Join-Path $testRoot 'second-pdi.env'
    @(
      'SN_PDI_INSTANCE=https://first.example.invalid'
      'SN_PDI_USER=first_user'
      'SN_PDI_PASS=first_password'
      'SN_PDI_2_INSTANCE=https://second.example.invalid'
      'SN_PDI_2_USERNAME=second_user'
      'SN_PDI_2_PASSWORD=second_password'
      'SN_INSTANCE=https://generic.example.invalid'
      'SN_USER=generic_user'
      'SN_PASS=generic_password'
    ) | Set-Content -LiteralPath $secondPdiEnv
    $savedSecondUser = $env:SN_PDI_2_USER
    $savedSecondPass = $env:SN_PDI_2_PASS
    try {
      $env:SN_PDI_2_USER = 'process_user'
      $env:SN_PDI_2_PASS = 'process_password'
      $connection = Resolve-ServiceNowConnection -Profile PDI_2 -EnvPath $secondPdiEnv
      Assert-True ($connection.Profile -eq 'pdi_2') 'Profile normalization changed.'
      $state.handler = {
        param($request)
        Assert-True (([uri]$request.Uri).Host -eq 'second.example.invalid') 'Request reached the wrong PDI.'
        $expected = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('second_user:second_password'))
        Assert-True ($request.Headers.Authorization -ceq $expected) 'Request used credentials from another source or profile.'
        @{ data = [pscustomobject]@{ result = @() }; headers = @{} }
      }
      & $table -Profile PDI_2 -EnvPath $secondPdiEnv -Table sys_user | Out-Null
      Assert-True ($state.calls -eq 1 -and $state.writes -eq 0) 'Expected one read.'
      Add-Content -LiteralPath $secondPdiEnv -Value @('SN_PDI_2_USER=short_user', 'SN_PDI_2_PASS=short_password')
      $connection = Resolve-ServiceNowConnection -Profile pdi_2 -EnvPath $secondPdiEnv
      Assert-True ($connection.UserName -ceq 'short_user' -and $connection.Password -ceq 'short_password') 'Short credential keys lost precedence.'
    } finally {
      $env:SN_PDI_2_USER = $savedSecondUser
      $env:SN_PDI_2_PASS = $savedSecondPass
    }
  }

  Test-Case 'invalid writes fail before transport' {
    Assert-Throws { & $table @argsA -Table incident -Method PATCH -BodyJson '{}' } '*require one exact*'
    Assert-Throws { & $table @argsA -Table incident -Method DELETE -Query 'active=false' } '*require one exact*'
    Assert-Throws { & $table @argsA -Table incident -Method POST -BodyJson '[]' } '*JSON object*'
    Assert-Throws { & $table @argsA -Table incident -Method POST -BodyJson '{broken' } '*valid JSON*'
    Assert-True ($state.calls -eq 0) 'Invalid write reached transport.'
  }

  Test-Case 'UTF-8 body file and native object output' {
    $bodyPath = Join-Path $testRoot 'body.json'
    $fixtureJson = '{"description":"Vår Energi – 日本語","script":"var x = `$value;\n"}'
    Set-Content -LiteralPath $bodyPath -Value $fixtureJson -Encoding UTF8 -NoNewline
    $state.handler = {
      param($request)
      Assert-True ([System.Text.Encoding]::UTF8.GetString($request.Body) -ceq $fixtureJson) 'Body bytes changed.'
      Assert-True ($request.ContentType -eq 'application/json; charset=utf-8') 'Missing UTF-8 content type.'
      Assert-True ($request.TimeoutSec -eq 60 -and $request.OperationTimeoutSeconds -eq 60) 'Missing timeout.'
      Assert-True ($request.MaximumRedirection -eq 0) 'Unexpected redirect policy.'
      @{ data = [pscustomobject]@{ result = [pscustomobject]@{ sys_id = ('a' * 32) } }; headers = @{} }
    }
    $result = & $table @argsA -Table incident -Method POST -BodyPath $bodyPath -AsObject
    Assert-True ($result.result.sys_id -eq ('a' * 32)) 'Native result contract changed.'
    Assert-True ($state.writes -eq 1) 'Expected one write.'
  }

  Test-Case 'bounded transient GET retries honor Retry-After' {
    $state.handler = {
      param($request)
      if ($state.calls -eq 1) { throw (New-HttpFailure 429 4) }
      @{ data = [pscustomobject]@{ result = @() }; headers = @{} }
    }
    & $table @argsA -Table incident | Out-Null
    Assert-True ($state.calls -eq 2 -and $state.sleeps -eq 4) 'Retry policy did not honor Retry-After.'
    $state.calls = 0
    $state.handler = { param($request) throw (New-HttpFailure 503) }
    Assert-Throws { & $table @argsA -Table incident -MaxRetries 2 } '*HTTP 503*'
    Assert-True ($state.calls -eq 3) 'Retry budget was not enforced.'
  }

  Test-Case 'writes, authorization failures, and long Retry-After are never replayed' {
    $state.handler = { param($request) throw (New-HttpFailure 503) }
    Assert-Throws { & $table @argsA -Table incident -Method POST -BodyJson '{}' } '*outcome may be unknown*'
    Assert-True ($state.calls -eq 1) 'Write was replayed.'
    $state.calls = 0
    $state.handler = { param($request) throw (New-HttpFailure 403) }
    Assert-Throws { & $table @argsA -Table incident } '*HTTP 403*'
    Assert-True ($state.calls -eq 1) 'Authorization failure was retried.'
    $state.calls = 0
    $state.handler = { param($request) throw (New-HttpFailure 429 120) }
    Assert-Throws { & $table @argsA -Table incident } '*HTTP 429*'
    Assert-True ($state.calls -eq 1) 'Retry-After longer than budget was ignored.'
  }

  Test-Case 'cache is isolated by resolved instance, principal, and response shape' {
    $cache = Join-Path $testRoot 'cache'
    Invoke-ServiceNowToolkitTable @argsA -Table sys_scope -CachePath $cache | Out-Null
    Invoke-ServiceNowToolkitTable @argsA -Table sys_scope -CachePath $cache | Out-Null
    Assert-True ($state.calls -eq 1) 'Identical read missed the cache.'
    Invoke-ServiceNowToolkitTable -Profile qa -EnvPath $envB -Table sys_scope -CachePath $cache | Out-Null
    Invoke-ServiceNowToolkitTable -Profile qa -EnvPath $envC -Table sys_scope -CachePath $cache | Out-Null
    Invoke-ServiceNowToolkitTable @argsA -Table sys_scope -CachePath $cache -ExcludeReferenceLink | Out-Null
    Assert-True ($state.calls -eq 4) 'Different environment, principal, or shape reused cache.'
    Invoke-ServiceNowToolkitTable @argsA -Table sys_scope -CachePath $cache -NoCache | Out-Null
    Invoke-ServiceNowToolkitTable @argsA -Table sys_scope -CachePath $cache -Refresh | Out-Null
    Assert-True ($state.calls -eq 6) 'Freshness override did not reach transport.'
    Get-ChildItem -LiteralPath $cache -Filter '*.json' | ForEach-Object { Set-Content -LiteralPath $_.FullName -Value '{partial' }
    Invoke-ServiceNowToolkitTable @argsA -Table sys_scope -CachePath $cache | Out-Null
    Assert-True ($state.calls -eq 7) 'Corrupt cache did not recover.'
  }

  Test-Case 'ambiguous application scope is rejected' {
    $state.handler = { param($request) @{ data = [pscustomobject]@{ result = @([pscustomobject]@{sys_id='a'}, [pscustomobject]@{sys_id='b'}) }; headers = @{} } }
    Assert-Throws { Resolve-ServiceNowToolkitScope @argsA -Scope 'Duplicate name' -NoCache } '*exactly one scope*'
  }

  Test-Case 'index follows next link through an ACL-filtered empty page' {
    $state.handler = {
      param($request)
      if ($request.Uri -match 'sysparm_offset=0(?:&|$)') {
        return @{ data = [pscustomobject]@{ result = @() }; headers = @{ Link = '<https://a.example.invalid/api/now/table/sys_db_object?sysparm_offset=2&sysparm_limit=2>;rel="next"' } }
      }
      @{ data = [pscustomobject]@{ result = @([pscustomobject]@{ sys_id = ('b' * 32); name = 'fixture_table'; label = 'Fixture' }) }; headers = @{} }
    }
    $indexScript = Join-Path $toolkitRoot 'Build-ServiceNowInstanceIndex.ps1'
    $index = & $indexScript @argsA -TablesOnly -PageSize 2 -OutputPath (Join-Path $testRoot 'index') | ConvertFrom-Json
    Assert-True ($index.counts.tables -eq 1 -and $state.calls -eq 2) 'Index stopped at filtered page.'
    Assert-Throws { & $indexScript @argsA -TablesOnly -PageSize 2 -MaxPagesPerTable 1 -OutputPath (Join-Path $testRoot 'bounded-index') } '*page budget reached*'
  }

  Test-Case 'context validates resumed set and persists snapshot before first mutation' {
    $snapshotPath = Join-Path $testRoot 'snapshot.json'
    $state.handler = {
      param($request)
      if ($request.Method -ne 'GET') {
        Assert-True (Test-Path -LiteralPath $snapshotPath) 'Recovery snapshot was not saved before write.'
        $snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
        Assert-True ($snapshot.instance -eq 'https://a.example.invalid') 'Snapshot has no target binding.'
        throw (New-HttpFailure 503)
      }
      if ($request.Uri -match '/sys_update_set/') {
        return @{ data = [pscustomobject]@{ result = [pscustomobject]@{ sys_id=('c'*32); name='Fixture'; state='in progress'; application='global' } }; headers=@{} }
      }
      @{ data = [pscustomobject]@{ result=@() }; headers=@{} }
    }
    $context = Join-Path $toolkitRoot 'Set-ServiceNowUpdateSetContext.ps1'
    Assert-Throws { & $context @argsA -Scope global -UpdateSetSysId ('c'*32) -UserSysId ('d'*32) -SnapshotPath $snapshotPath } '*outcome may be unknown*'
    Assert-True ($state.writes -eq 1) 'Preference write was replayed.'
    Assert-Throws { & $context @argsA -Scope global -Name 'Fixture' -UserSysId ('d'*32) -SnapshotPath $snapshotPath } '*already exists*'
    $state.writes = 0
    $state.handler = { param($request) @{ data=[pscustomobject]@{result=[pscustomobject]@{state='complete'; application='global'; name='Fixture'}}; headers=@{} } }
    Assert-Throws { & $context @argsA -Scope global -UpdateSetSysId ('c'*32) -UserSysId ('d'*32) -SnapshotPath (Join-Path $testRoot 'other-snapshot.json') } '*must exist*'
    Assert-True ($state.writes -eq 0) 'Invalid update set changed preferences.'
    Assert-Throws { & (Join-Path $toolkitRoot 'Restore-ServiceNowPreferenceSnapshot.ps1') -Profile qa -EnvPath $envB -SnapshotPath $snapshotPath } '*does not match*'
  }

  Test-Case 'capture mismatch fails without moving customer updates' {
    $state.webHandler = {
      param($request)
      $capture = @{ saved=$true; updateXml=@(@{sys_id=('e'*32); update_set=('f'*32)}) } | ConvertTo-Json -Compress -Depth 5
      @{ StatusCode=200; Content=(@{'$success'=$true; result=@{string=$capture}} | ConvertTo-Json -Compress -Depth 8) }
    }
    Assert-Throws { & (Join-Path $toolkitRoot 'Save-ServiceNowCustomerUpdate.ps1') @argsA -Table sys_script_include -SysId ('a'*32) -UpdateSetSysId ('b'*32) } '*Correct the execution scope*'
    Assert-True ($state.writes -eq 0) 'Capture helper moved customer updates.'
  }

  Test-Case 'successful context switch and restore preserve original preferences' {
    $snapshotPath = Join-Path $testRoot 'successful-snapshot.json'
    $state.preferences = @{'apps.current_app'='old_scope'; 'sys_update_set'='old_set'; 'updateSetForScopeglobal'='old_scoped_set'}
    $state.preferenceIds = @{'apps.current_app'= ('1'*32); 'sys_update_set'= ('2'*32); 'updateSetForScopeglobal'= ('3'*32)}
    $state.handler = {
      param($request)
      if ($request.Uri -match '/sys_update_set/') {
        return @{data=[pscustomobject]@{result=[pscustomobject]@{sys_id=('c'*32); name='Fixture'; state='in progress'; application='global'}}; headers=@{}}
      }
      if ($request.Method -eq 'GET') {
        $query = [uri]::UnescapeDataString(([uri]$request.Uri).Query)
        $name = @($state.preferences.Keys | Where-Object { $query -match ('\^name=' + [regex]::Escape($_) + '(?:&|$)') })[0]
        Assert-True ($null -ne $name) 'Unexpected preference lookup.'
        return @{data=[pscustomobject]@{result=@([pscustomobject]@{sys_id=$state.preferenceIds[$name]; name=$name; value=$state.preferences[$name]})}; headers=@{}}
      }
      $id = ([uri]$request.Uri).AbsolutePath.Split('/')[-1]
      $name = @($state.preferenceIds.Keys | Where-Object { $state.preferenceIds[$_] -eq $id })[0]
      Assert-True ($null -ne $name -and $request.Method -eq 'PATCH') 'Unexpected preference mutation.'
      $body = [System.Text.Encoding]::UTF8.GetString($request.Body) | ConvertFrom-Json
      $state.preferences[$name] = $body.value
      @{data=[pscustomobject]@{result=[pscustomobject]@{sys_id=@{value=$id}; name=@{value=$name}; value=@{value=$body.value}}}; headers=@{}}
    }
    $context = Join-Path $toolkitRoot 'Set-ServiceNowUpdateSetContext.ps1'
    Assert-Throws { & $context @argsA -Scope global -Name Fixture } '*Provide a new -SnapshotPath*'
    $switched = & $context @argsA -Scope global -UpdateSetSysId ('c'*32) -UserSysId ('d'*32) -SnapshotPath $snapshotPath | ConvertFrom-Json
    Assert-True ($switched.update_set_sys_id -eq ('c'*32)) 'Wrong selected update set.'
    Assert-True ($state.preferences['apps.current_app'] -eq 'global' -and $state.preferences['sys_update_set'] -eq ('c'*32)) 'Context did not switch.'
    & (Join-Path $toolkitRoot 'Restore-ServiceNowPreferenceSnapshot.ps1') @argsA -SnapshotPath $snapshotPath | Out-Null
    Assert-True ($state.preferences['apps.current_app'] -eq 'old_scope' -and $state.preferences['sys_update_set'] -eq 'old_set' -and $state.preferences['updateSetForScopeglobal'] -eq 'old_scoped_set') 'Original preferences were not restored.'
  }

  Write-Output "$passed offline regression cases passed; no live HTTP requests were made."
} finally {
  # Delete only this suite's unique temporary directory, after checking its parent.
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $expectedParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
  if ((Split-Path -Parent $resolvedTestRoot) -eq $expectedParent -and
      (Split-Path -Leaf $resolvedTestRoot) -like 'sn-toolkit-test-*') {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
  }
}
