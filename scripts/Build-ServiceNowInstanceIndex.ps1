param(
  [string]$Scope,
  [switch]$TablesOnly,
  [switch]$Artifacts,
  [switch]$IncludeBodies,
  [string]$OutputPath,
  [int]$PageSize = 500,
  [string]$Profile,
  [string]$EnvPath,
  [string]$Instance
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Resolve-ServiceNowConnection.ps1"

function New-ServiceNowIndexAuthHeaders {
  param($Connection)

  $pair = '{0}:{1}' -f $Connection.UserName, $Connection.Password
  $auth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
  return @{
    Authorization = "Basic $auth"
    Accept = 'application/json'
    'Content-Type' = 'application/json'
  }
}

function Invoke-ServiceNowIndexTablePage {
  param(
    [Parameter(Mandatory = $true)][string]$Table,
    [string]$Query,
    [string]$Fields,
    [int]$Limit,
    [int]$Offset,
    [string]$InstanceUrl,
    [hashtable]$Headers
  )

  $path = "$InstanceUrl/api/now/table/$([uri]::EscapeDataString($Table))"
  $params = @{
    sysparm_limit = [string]$Limit
    sysparm_offset = [string]$Offset
    sysparm_display_value = 'all'
    sysparm_exclude_reference_link = 'true'
  }
  if (-not [string]::IsNullOrWhiteSpace($Query)) { $params.sysparm_query = $Query }
  if (-not [string]::IsNullOrWhiteSpace($Fields)) { $params.sysparm_fields = $Fields }

  $queryParts = foreach ($key in $params.Keys) {
    '{0}={1}' -f [uri]::EscapeDataString($key), [uri]::EscapeDataString($params[$key])
  }
  $uri = "$path`?$($queryParts -join '&')"
  Invoke-RestMethod -Uri $uri -Headers $Headers -Method GET
}

function Get-ServiceNowIndexRows {
  param(
    [Parameter(Mandatory = $true)][string]$Table,
    [string]$Query,
    [string]$Fields,
    [int]$PageSize,
    [string]$InstanceUrl,
    [hashtable]$Headers
  )

  $rows = [System.Collections.Generic.List[object]]::new()
  $offset = 0
  while ($true) {
    $response = Invoke-ServiceNowIndexTablePage `
      -Table $Table `
      -Query $Query `
      -Fields $Fields `
      -Limit $PageSize `
      -Offset $offset `
      -InstanceUrl $InstanceUrl `
      -Headers $Headers

    $page = @($response.result)
    foreach ($row in $page) { $rows.Add($row) }
    if ($page.Count -lt $PageSize) { break }
    $offset += $PageSize
  }
  return @($rows)
}

function Convert-ServiceNowIndexValue {
  param($Value)

  if ($null -eq $Value) { return $null }
  if ($Value.PSObject.Properties.Name -contains 'value') { return $Value.value }
  return $Value
}

function Convert-ServiceNowIndexRow {
  param($Row)

  $out = [ordered]@{}
  foreach ($prop in $Row.PSObject.Properties) {
    $out[$prop.Name] = Convert-ServiceNowIndexValue -Value $prop.Value
  }
  return [pscustomobject]$out
}

function Get-ServiceNowIndexProp {
  param($Object, [string]$Name)

  if ($null -eq $Object) { return $null }
  if ($Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
  return $null
}

function Add-ServiceNowIndexSymbol {
  param(
    [System.Collections.Generic.List[object]]$Symbols,
    [string]$Kind,
    [string]$Name,
    [string]$Table,
    [string]$SysId
  )

  if ([string]::IsNullOrWhiteSpace($Name)) { return }
  $Symbols.Add([pscustomobject]@{
    kind = $Kind
    name = $Name
    table = $Table
    sys_id = $SysId
  })
}

function Add-ServiceNowIndexEdge {
  param(
    [System.Collections.Generic.List[object]]$Edges,
    [string]$Type,
    [string]$FromTable,
    [string]$FromSysId,
    [string]$ToTable,
    [string]$ToKey
  )

  if ([string]::IsNullOrWhiteSpace($ToKey)) { return }
  $Edges.Add([pscustomobject]@{
    type = $Type
    from_table = $FromTable
    from_sys_id = $FromSysId
    to_table = $ToTable
    to_key = $ToKey
  })
}

if ($PageSize -lt 1 -or $PageSize -gt 1000) {
  throw '-PageSize must be between 1 and 1000.'
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path (Get-Location).Path '.servicenow-index'
}
if (-not (Test-Path -LiteralPath $OutputPath)) {
  New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

$connection = Resolve-ServiceNowConnection -Profile $Profile -Instance $Instance -EnvPath $EnvPath
$headers = New-ServiceNowIndexAuthHeaders -Connection $connection

$scopeFilter = $null
if (-not [string]::IsNullOrWhiteSpace($Scope)) {
  if ($Scope -match '^[0-9a-f]{32}$') {
    $scopeFilter = $Scope
  } else {
    $scopeRows = Get-ServiceNowIndexRows `
      -Table sys_scope `
      -Query "scope=$Scope^ORname=$Scope" `
      -Fields 'sys_id,scope,name' `
      -PageSize 10 `
      -InstanceUrl $connection.Instance `
      -Headers $headers
    if ($scopeRows.Count -lt 1) { throw "Could not resolve scope '$Scope'." }
    $scopeFilter = (Convert-ServiceNowIndexRow -Row $scopeRows[0]).sys_id
  }
}

$metadata = [ordered]@{
  generated_at = (Get-Date).ToString('o')
  instance = $connection.Instance
  profile = $connection.Profile
  scope = $Scope
  include_bodies = [bool]$IncludeBodies
}

$tablesQuery = 'nameISNOTEMPTY^ORDERBYname'
if ($scopeFilter) { $tablesQuery = "sys_scope=$scopeFilter^$tablesQuery" }
$tableRows = Get-ServiceNowIndexRows `
  -Table sys_db_object `
  -Query $tablesQuery `
  -Fields 'sys_id,name,label,super_class,sys_scope,sys_package,is_extendable,number_ref,access,create_access,read_access,update_access,delete_access,sys_updated_on' `
  -PageSize $PageSize `
  -InstanceUrl $connection.Instance `
  -Headers $headers
$tables = @($tableRows | ForEach-Object { Convert-ServiceNowIndexRow -Row $_ })
$indexedTableNames = @($tables | ForEach-Object { $_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

$fields = @()
$choices = @()
$artifactsOut = @()
$symbols = [System.Collections.Generic.List[object]]::new()
$edges = [System.Collections.Generic.List[object]]::new()

if (-not $TablesOnly) {
  $dictionaryQuery = 'nameISNOTEMPTY^elementISNOTEMPTY^ORDERBYname^ORDERBYelement'
  if ($scopeFilter) { $dictionaryQuery = "sys_scope=$scopeFilter^$dictionaryQuery" }
  $dictionaryRows = Get-ServiceNowIndexRows `
    -Table sys_dictionary `
    -Query $dictionaryQuery `
    -Fields 'sys_id,name,element,column_label,internal_type,reference,mandatory,read_only,default_value,attributes,choice,sys_scope,sys_updated_on' `
    -PageSize $PageSize `
    -InstanceUrl $connection.Instance `
    -Headers $headers
  $fields = @($dictionaryRows | ForEach-Object {
      $row = Convert-ServiceNowIndexRow -Row $_
      Add-ServiceNowIndexEdge -Edges $edges -Type references -FromTable sys_dictionary -FromSysId $row.sys_id -ToTable sys_db_object -ToKey $row.reference
      $row
    })

  if (-not $scopeFilter -or $indexedTableNames.Count -gt 0) {
    $choiceQuery = 'nameISNOTEMPTY^elementISNOTEMPTY^inactive=false^ORDERBYname^ORDERBYelement^ORDERBYsequence'
    if ($scopeFilter) { $choiceQuery = "nameIN$($indexedTableNames -join ',')^elementISNOTEMPTY^inactive=false^ORDERBYname^ORDERBYelement^ORDERBYsequence" }
    $choiceRows = Get-ServiceNowIndexRows `
      -Table sys_choice `
      -Query $choiceQuery `
      -Fields 'sys_id,name,element,value,label,sequence,dependent_value,language,inactive,sys_updated_on' `
      -PageSize $PageSize `
      -InstanceUrl $connection.Instance `
      -Headers $headers
    $choices = @($choiceRows | ForEach-Object { Convert-ServiceNowIndexRow -Row $_ })
  }
}

if ($Artifacts -and -not $TablesOnly) {
  $artifactConfigs = @(
    @{ table = 'sys_script_include'; fields = 'sys_id,name,api_name,active,client_callable,sys_scope,sys_package,sys_updated_on'; body = 'script'; key = 'name'; symbol = 'script_include'; table_field = $null },
    @{ table = 'sys_script'; fields = 'sys_id,name,collection,active,when,order,sys_scope,sys_package,sys_updated_on'; body = 'script,condition'; key = 'name'; symbol = 'business_rule'; table_field = 'collection' },
    @{ table = 'sys_script_client'; fields = 'sys_id,name,table,active,type,ui_type,sys_scope,sys_package,sys_updated_on'; body = 'script'; key = 'name'; symbol = 'client_script'; table_field = 'table' },
    @{ table = 'sys_ui_action'; fields = 'sys_id,name,table,action_name,active,order,sys_scope,sys_package,sys_updated_on'; body = 'script,condition,client_script_v2'; key = 'name'; symbol = 'ui_action'; table_field = 'table' },
    @{ table = 'sys_security_acl'; fields = 'sys_id,name,operation,type,active,admin_overrides,sys_scope,sys_package,sys_updated_on'; body = 'script,condition'; key = 'name'; symbol = 'acl'; table_field = 'name' },
    @{ table = 'sysevent_register'; fields = 'sys_id,event_name,table,description,queue,sys_scope,sys_package,sys_updated_on'; body = ''; key = 'event_name'; symbol = 'event'; table_field = 'table' },
    @{ table = 'sysevent_email_action'; fields = 'sys_id,name,event_name,collection,subject,active,generation_type,sys_scope,sys_package,sys_updated_on'; body = 'advanced_condition'; key = 'name'; symbol = 'notification'; table_field = 'collection' },
    @{ table = 'sys_rest_message'; fields = 'sys_id,name,rest_endpoint,active,sys_scope,sys_package,sys_updated_on'; body = ''; key = 'name'; symbol = 'rest_message'; table_field = $null },
    @{ table = 'sys_transform_map'; fields = 'sys_id,name,source_table,target_table,active,sys_scope,sys_package,sys_updated_on'; body = 'script'; key = 'name'; symbol = 'transform_map'; table_field = 'target_table' },
    @{ table = 'sys_data_source'; fields = 'sys_id,name,type,import_set_table_name,sys_scope,sys_package,sys_updated_on'; body = 'data_loader,parsing_script'; key = 'name'; symbol = 'data_source'; table_field = 'import_set_table_name' },
    @{ table = 'sp_widget'; fields = 'sys_id,name,id,sys_scope,sys_package,sys_updated_on'; body = 'template,script,client_script,css,link'; key = 'name'; symbol = 'sp_widget'; table_field = $null },
    @{ table = 'sys_app_module'; fields = 'sys_id,title,name,application,link_type,table,active,order,sys_scope,sys_package,sys_updated_on'; body = ''; key = 'title'; symbol = 'module'; table_field = 'table' }
  )

  foreach ($config in $artifactConfigs) {
    $query = 'sys_idISNOTEMPTY^ORDERBYsys_updated_on'
    if ($scopeFilter) { $query = "sys_scope=$scopeFilter^$query" }
    $fieldsForRead = $config.fields
    if ($IncludeBodies -and -not [string]::IsNullOrWhiteSpace($config.body)) {
      $fieldsForRead = "$fieldsForRead,$($config.body)"
    }

    try {
      $rows = Get-ServiceNowIndexRows `
        -Table $config.table `
        -Query $query `
        -Fields $fieldsForRead `
        -PageSize $PageSize `
        -InstanceUrl $connection.Instance `
        -Headers $headers
    } catch {
      $artifactsOut += [pscustomobject]@{
        artifact_table = $config.table
        error = $_.Exception.Message
      }
      continue
    }

    foreach ($rawRow in $rows) {
      $row = Convert-ServiceNowIndexRow -Row $rawRow
      $name = Get-ServiceNowIndexProp -Object $row -Name $config.key
      $targetTable = if ($config.table_field) { Get-ServiceNowIndexProp -Object $row -Name $config.table_field } else { $null }
      $record = [ordered]@{
        artifact_table = $config.table
        sys_id = $row.sys_id
        name = $name
        target_table = $targetTable
        scope = $row.sys_scope
        package = $row.sys_package
        active = Get-ServiceNowIndexProp -Object $row -Name active
        updated = $row.sys_updated_on
        record = $row
      }
      $artifactsOut += [pscustomobject]$record

      Add-ServiceNowIndexSymbol -Symbols $symbols -Kind $config.symbol -Name $name -Table $config.table -SysId $row.sys_id
      if ($config.table -eq 'sys_script_include') {
        Add-ServiceNowIndexSymbol -Symbols $symbols -Kind api_name -Name $row.api_name -Table $config.table -SysId $row.sys_id
      }
      if ($config.table -eq 'sysevent_register') {
        Add-ServiceNowIndexEdge -Edges $edges -Type triggers -FromTable $config.table -FromSysId $row.sys_id -ToTable sys_db_object -ToKey $row.table
      } elseif ($config.table -eq 'sysevent_email_action') {
        Add-ServiceNowIndexEdge -Edges $edges -Type notifies -FromTable $config.table -FromSysId $row.sys_id -ToTable sysevent_register -ToKey $row.event_name
        Add-ServiceNowIndexEdge -Edges $edges -Type runs_on -FromTable $config.table -FromSysId $row.sys_id -ToTable sys_db_object -ToKey $row.collection
      } elseif ($config.table -eq 'sys_security_acl') {
        Add-ServiceNowIndexEdge -Edges $edges -Type secures -FromTable $config.table -FromSysId $row.sys_id -ToTable sys_db_object -ToKey $row.name
      } elseif ($targetTable) {
        Add-ServiceNowIndexEdge -Edges $edges -Type runs_on -FromTable $config.table -FromSysId $row.sys_id -ToTable sys_db_object -ToKey $targetTable
      }
    }
  }
}

$files = [ordered]@{
  metadata = Join-Path $OutputPath 'metadata.json'
  tables = Join-Path $OutputPath 'tables.json'
  fields = Join-Path $OutputPath 'fields.json'
  choices = Join-Path $OutputPath 'choices.json'
  artifacts = Join-Path $OutputPath 'artifacts.json'
  symbols = Join-Path $OutputPath 'symbols.json'
  edges = Join-Path $OutputPath 'edges.json'
}

$metadata | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $files.metadata -Encoding UTF8
$tables | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $files.tables -Encoding UTF8
$fields | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $files.fields -Encoding UTF8
$choices | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $files.choices -Encoding UTF8
$artifactsOut | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $files.artifacts -Encoding UTF8
@($symbols) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $files.symbols -Encoding UTF8
@($edges) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $files.edges -Encoding UTF8

[ordered]@{
  generated_at = $metadata.generated_at
  output_path = $OutputPath
  instance = $connection.Instance
  scope = $Scope
  include_bodies = [bool]$IncludeBodies
  counts = [ordered]@{
    tables = $tables.Count
    fields = $fields.Count
    choices = $choices.Count
    artifacts = $artifactsOut.Count
    symbols = @($symbols).Count
    edges = @($edges).Count
  }
  files = $files
} | ConvertTo-Json -Depth 8
