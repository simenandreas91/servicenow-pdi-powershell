[CmdletBinding()]
param(
  [string]$KnowledgeBaseTitle = 'Compendia',
  [string]$StagingTable = 'u_compendia_import_staging',
  [string]$ScheduledJobName = 'Vår Energi - Compendia knowledge sync',
  [string]$ExpectedAuthorUserName = 'compendia',
  [string]$PropertyPrefix = 'varenergi.compendia',
  [string]$Profile,
  [string]$EnvPath,
  [string]$Instance
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_ServiceNowToolkitCommon.ps1')

function Get-ServiceNowScalar {
  param($Value)

  if ($null -eq $Value) { return $null }
  if ($Value -is [string] -or $Value -is [ValueType]) { return [string]$Value }
  if ($Value.PSObject.Properties.Name -contains 'value') { return [string]$Value.value }
  if ($Value.PSObject.Properties.Name -contains 'display_value') { return [string]$Value.display_value }
  return [string]$Value
}

function Invoke-CompendiaTableRead {
  param(
    [Parameter(Mandatory = $true)][string]$Table,
    [string]$Query,
    [string]$Fields,
    [int]$Limit = 1000
  )

  $params = @{
    Table = $Table
    Query = $Query
    Fields = $Fields
    Limit = $Limit
    DisplayValue = 'false'
    ExcludeReferenceLink = $true
    NoCache = $true
  }
  if ($Profile) { $params.Profile = $Profile }
  if ($EnvPath) { $params.EnvPath = $EnvPath }
  if ($Instance) { $params.Instance = $Instance }
  return Invoke-ServiceNowToolkitTable @params
}

$warnings = [System.Collections.Generic.List[string]]::new()

$knowledgeBases = @((Invoke-CompendiaTableRead -Table 'kb_knowledge_base' -Query "title=$KnowledgeBaseTitle" -Fields 'sys_id,title,active' -Limit 10).result |
  Where-Object { (Get-ServiceNowScalar $_.title) -eq $KnowledgeBaseTitle })
if ($knowledgeBases.Count -ne 1) {
  throw "Expected one knowledge base named '$KnowledgeBaseTitle'; found $($knowledgeBases.Count)."
}
$knowledgeBase = $knowledgeBases[0]
$knowledgeBaseSysId = Get-ServiceNowScalar $knowledgeBase.sys_id

$authors = @((Invoke-CompendiaTableRead -Table 'sys_user' -Query "user_name=$ExpectedAuthorUserName" -Fields 'sys_id,user_name,name,active' -Limit 10).result |
  Where-Object { (Get-ServiceNowScalar $_.user_name) -eq $ExpectedAuthorUserName })
$expectedAuthorSysId = $null
if ($authors.Count -eq 1) {
  $expectedAuthorSysId = Get-ServiceNowScalar $authors[0].sys_id
} else {
  $warnings.Add("Expected one author user '$ExpectedAuthorUserName'; found $($authors.Count).")
}

$articles = @((Invoke-CompendiaTableRead -Table 'kb_knowledge' -Query "kb_knowledge_base=$knowledgeBaseSysId" -Fields 'sys_id,number,workflow_state,author,display_attachments' -Limit 10000).result)
$staging = @((Invoke-CompendiaTableRead -Table $StagingTable -Fields 'sys_id,u_external_key,u_handbook_slug,u_sync_state,u_error_message,u_target_article' -Limit 10000).result)

$propertyNames = @(
  "$PropertyPrefix.sync.enabled",
  "$PropertyPrefix.sync.auto_publish",
  "$PropertyPrefix.sync.max_per_run"
)
$properties = @((Invoke-CompendiaTableRead -Table 'sys_properties' -Query ("nameIN" + ($propertyNames -join ',')) -Fields 'name,value,type' -Limit 20).result)
$propertyMap = [ordered]@{}
foreach ($property in $properties) {
  $propertyMap[(Get-ServiceNowScalar $property.name)] = Get-ServiceNowScalar $property.value
}

$jobs = @((Invoke-CompendiaTableRead -Table 'sysauto_script' -Query "name=$ScheduledJobName^ORDERBYDESCsys_updated_on" -Fields 'sys_id,name,active,run_type,run_time,run_start' -Limit 10).result |
  Where-Object { (Get-ServiceNowScalar $_.name) -eq $ScheduledJobName })
$job = $null
$triggers = @()
if ($jobs.Count -eq 0) {
  $warnings.Add("Scheduled job '$ScheduledJobName' was not found.")
} else {
  if ($jobs.Count -gt 1) {
    $warnings.Add("Found $($jobs.Count) scheduled jobs named '$ScheduledJobName'; reporting the newest record.")
  }
  $job = $jobs[0]
  $jobSysId = Get-ServiceNowScalar $job.sys_id
  $triggers = @((Invoke-CompendiaTableRead -Table 'sys_trigger' -Query "document_key=$jobSysId" -Fields 'sys_id,state,next_action,trigger_type,last_error' -Limit 20).result)
}

$attachments = @()
$articleIds = @($articles | ForEach-Object { Get-ServiceNowScalar $_.sys_id })
for ($offset = 0; $offset -lt $articleIds.Count; $offset += 35) {
  $last = [Math]::Min($offset + 34, $articleIds.Count - 1)
  $chunk = $articleIds[$offset..$last] -join ','
  $attachments += @((Invoke-CompendiaTableRead -Table 'sys_attachment' -Query "table_name=kb_knowledge^table_sys_idIN$chunk" -Fields 'sys_id,table_sys_id,content_type' -Limit 10000).result)
}

$uniqueAttachments = @($attachments | Group-Object { Get-ServiceNowScalar $_.sys_id } | ForEach-Object { $_.Group[0] })
$articleStates = @($articles | Group-Object { Get-ServiceNowScalar $_.workflow_state } | Sort-Object Name |
  ForEach-Object { [ordered]@{ state = $_.Name; count = $_.Count } })
$handbooks = @($staging | Group-Object { Get-ServiceNowScalar $_.u_handbook_slug } | Sort-Object Name |
  ForEach-Object { [ordered]@{ handbook = $_.Name; count = $_.Count } })
$stagingStates = @($staging | Group-Object { Get-ServiceNowScalar $_.u_sync_state } | Sort-Object Name |
  ForEach-Object { [ordered]@{ state = $_.Name; count = $_.Count } })
$stagingErrors = @($staging | Where-Object { (Get-ServiceNowScalar $_.u_sync_state) -eq 'error' } |
  ForEach-Object {
    [ordered]@{
      external_key = Get-ServiceNowScalar $_.u_external_key
      error = Get-ServiceNowScalar $_.u_error_message
      target_article = Get-ServiceNowScalar $_.u_target_article
    }
  })
$authorMismatchCount = if ($expectedAuthorSysId) {
  @($articles | Where-Object { (Get-ServiceNowScalar $_.author) -ne $expectedAuthorSysId }).Count
} else {
  $null
}
$displayAttachmentsFalseCount = @($articles | Where-Object { (Get-ServiceNowScalar $_.display_attachments) -ne 'true' }).Count
$attachmentTypes = @($uniqueAttachments | Group-Object { Get-ServiceNowScalar $_.content_type } | Sort-Object Count -Descending |
  ForEach-Object { [ordered]@{ content_type = $_.Name; count = $_.Count } })
$articlesWithAttachments = @($uniqueAttachments | ForEach-Object { Get-ServiceNowScalar $_.table_sys_id } | Sort-Object -Unique).Count

if ($articles.Count -ne $staging.Count) {
  $warnings.Add("Knowledge article count ($($articles.Count)) does not match staging count ($($staging.Count)).")
}
if ($stagingErrors.Count -gt 0) {
  $warnings.Add("Staging contains $($stagingErrors.Count) error row(s).")
}
if ($null -ne $authorMismatchCount -and $authorMismatchCount -gt 0) {
  $warnings.Add("$authorMismatchCount article(s) do not use '$ExpectedAuthorUserName' as author.")
}
if ($displayAttachmentsFalseCount -gt 0) {
  $warnings.Add("$displayAttachmentsFalseCount article(s) have display_attachments disabled.")
}
if (-not $propertyMap.Contains("$PropertyPrefix.sync.enabled")) {
  $warnings.Add("Property '$PropertyPrefix.sync.enabled' was not found.")
} elseif ($propertyMap["$PropertyPrefix.sync.enabled"] -ne 'true') {
  $warnings.Add("Property '$PropertyPrefix.sync.enabled' is not true.")
}
if ($job) {
  if ((Get-ServiceNowScalar $job.active) -ne 'true') {
    $warnings.Add("Scheduled job '$ScheduledJobName' is inactive.")
  }
  if ((Get-ServiceNowScalar $job.run_type) -ne 'daily') {
    $warnings.Add("Scheduled job '$ScheduledJobName' is not in daily mode.")
  }
}

$jobOutput = if ($job) {
  [ordered]@{
    sys_id = Get-ServiceNowScalar $job.sys_id
    name = Get-ServiceNowScalar $job.name
    active = Get-ServiceNowScalar $job.active
    run_type = Get-ServiceNowScalar $job.run_type
    run_time = Get-ServiceNowScalar $job.run_time
    run_start = Get-ServiceNowScalar $job.run_start
    triggers = @($triggers | ForEach-Object {
      [ordered]@{
        state = Get-ServiceNowScalar $_.state
        next_action = Get-ServiceNowScalar $_.next_action
        trigger_type = Get-ServiceNowScalar $_.trigger_type
        last_error = Get-ServiceNowScalar $_.last_error
      }
    })
  }
} else {
  $null
}

[ordered]@{
  generated_at = (Get-Date).ToString('o')
  instance = $Instance
  knowledge_base = [ordered]@{
    title = Get-ServiceNowScalar $knowledgeBase.title
    active = Get-ServiceNowScalar $knowledgeBase.active
    article_count = $articles.Count
    article_states = $articleStates
    expected_author = $ExpectedAuthorUserName
    author_mismatch_count = $authorMismatchCount
    display_attachments_false_count = $displayAttachmentsFalseCount
  }
  staging = [ordered]@{
    table = $StagingTable
    row_count = $staging.Count
    counts_by_handbook = $handbooks
    counts_by_state = $stagingStates
    errors = $stagingErrors
  }
  attachments = [ordered]@{
    count = $uniqueAttachments.Count
    articles_with_attachments = $articlesWithAttachments
    counts_by_content_type = $attachmentTypes
  }
  properties = $propertyMap
  scheduled_job = $jobOutput
  warnings = @($warnings)
} | ConvertTo-Json -Depth 20
