function Get-ServiceNowDotEnvPath {
  param([string]$ExplicitPath)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    if (Test-Path -LiteralPath $ExplicitPath) {
      return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    throw "ServiceNow .env file was not found: $ExplicitPath"
  }

  $current = Get-Location
  while ($null -ne $current) {
    $candidate = Join-Path -Path $current.Path -ChildPath '.env'
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
    $current = $current.Parent
  }

  $userProfilePath = [Environment]::GetFolderPath('UserProfile')
  if (-not [string]::IsNullOrWhiteSpace($userProfilePath)) {
    $defaultCredentialPath = Join-Path -Path $userProfilePath -ChildPath '.codex\servicenow-pdi.env'
    if (Test-Path -LiteralPath $defaultCredentialPath) {
      return (Resolve-Path -LiteralPath $defaultCredentialPath).Path
    }
  }

  return $null
}

function Read-ServiceNowDotEnv {
  param([string]$Path)

  $values = @{}
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $values
  }

  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#') -or $line -notmatch '=') {
      return
    }

    $parts = $line -split '=', 2
    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    $values[$key] = $value
  }

  return $values
}

function Resolve-ServiceNowConnection {
  param(
    [string]$Profile,
    [string]$Instance,
    [string]$EnvPath
  )

  $dotEnvPath = Get-ServiceNowDotEnvPath -ExplicitPath $EnvPath
  $dotEnv = Read-ServiceNowDotEnv -Path $dotEnvPath

  if ([string]::IsNullOrWhiteSpace($Profile)) {
    $Profile = $env:SN_PROFILE
  }
  if ([string]::IsNullOrWhiteSpace($Profile) -and $dotEnv.ContainsKey('SN_PROFILE')) {
    $Profile = $dotEnv['SN_PROFILE']
  }

  $resolvedInstance = $Instance
  $userName = $null
  $password = $null

  if (-not [string]::IsNullOrWhiteSpace($Profile)) {
    $requestedProfile = ($Profile -replace '[^A-Za-z0-9_]', '_').ToUpperInvariant()
    $normalizedProfile = $requestedProfile
    $profileAliases = @{
      'OTHER' = 'VAAR_DEV'
    }
    if ($profileAliases.ContainsKey($normalizedProfile)) {
      $normalizedProfile = $profileAliases[$normalizedProfile]
    }

    $instanceProfiles = @($normalizedProfile)
    if ($requestedProfile -ne $normalizedProfile) {
      $instanceProfiles += $requestedProfile
    }
    if ($normalizedProfile -eq 'VAAR_DEV' -and $instanceProfiles -notcontains 'OTHER') {
      $instanceProfiles += 'OTHER'
    }

    $instanceKeys = foreach ($instanceProfile in $instanceProfiles) {
      "SN_${instanceProfile}_INSTANCE"
      "SN_${instanceProfile}"
    }
    foreach ($instanceKey in $instanceKeys) {
      if ([string]::IsNullOrWhiteSpace($resolvedInstance) -and $dotEnv.ContainsKey($instanceKey)) {
        $resolvedInstance = $dotEnv[$instanceKey]
      }
    }
    foreach ($instanceKey in $instanceKeys) {
      if ([string]::IsNullOrWhiteSpace($resolvedInstance)) {
        $environmentValue = [Environment]::GetEnvironmentVariable($instanceKey)
        if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
          $resolvedInstance = $environmentValue
        }
      }
    }

    $credentialProfiles = @($normalizedProfile)
    if ($normalizedProfile -like 'VAAR_*' -and $credentialProfiles -notcontains 'OTHER') {
      $credentialProfiles += 'OTHER'
    }

    foreach ($credentialProfile in $credentialProfiles) {
      $profileUserKey = "SN_${credentialProfile}_USER"
      $profilePassKey = "SN_${credentialProfile}_PASS"
      if ([string]::IsNullOrWhiteSpace($userName) -and $dotEnv.ContainsKey($profileUserKey)) {
        $userName = $dotEnv[$profileUserKey]
      }
      if ([string]::IsNullOrWhiteSpace($password) -and $dotEnv.ContainsKey($profilePassKey)) {
        $password = $dotEnv[$profilePassKey]
      }
    }
    foreach ($credentialProfile in $credentialProfiles) {
      $profileUserKey = "SN_${credentialProfile}_USER"
      $profilePassKey = "SN_${credentialProfile}_PASS"
      if ([string]::IsNullOrWhiteSpace($userName)) {
        $environmentUser = [Environment]::GetEnvironmentVariable($profileUserKey)
        if (-not [string]::IsNullOrWhiteSpace($environmentUser)) {
          $userName = $environmentUser
        }
      }
      if ([string]::IsNullOrWhiteSpace($password)) {
        $environmentPassword = [Environment]::GetEnvironmentVariable($profilePassKey)
        if (-not [string]::IsNullOrWhiteSpace($environmentPassword)) {
          $password = $environmentPassword
        }
      }
    }
  }

  if ([string]::IsNullOrWhiteSpace($resolvedInstance) -and [string]::IsNullOrWhiteSpace($Profile) -and $dotEnv.ContainsKey('SN_INSTANCE')) {
    $resolvedInstance = $dotEnv['SN_INSTANCE']
  }
  if ([string]::IsNullOrWhiteSpace($resolvedInstance) -and [string]::IsNullOrWhiteSpace($Profile)) {
    $resolvedInstance = $env:SN_INSTANCE
  }

  if ([string]::IsNullOrWhiteSpace($userName) -and $dotEnv.ContainsKey('SN_USER')) {
    $userName = $dotEnv['SN_USER']
  }
  if ([string]::IsNullOrWhiteSpace($userName)) {
    $userName = $env:SN_USER
  }

  if ([string]::IsNullOrWhiteSpace($password) -and $dotEnv.ContainsKey('SN_PASS')) {
    $password = $dotEnv['SN_PASS']
  }
  if ([string]::IsNullOrWhiteSpace($password)) {
    $password = $env:SN_PASS
  }

  if ([string]::IsNullOrWhiteSpace($resolvedInstance)) {
    throw 'Set the named profile instance with SN_<PROFILE>_INSTANCE or a supported direct profile key such as SN_VAAR_DEV, pass -Instance explicitly, or omit -Profile to use SN_INSTANCE.'
  }
  if ([string]::IsNullOrWhiteSpace($userName) -or [string]::IsNullOrWhiteSpace($password)) {
    throw 'Set SN_USER/SN_PASS or SN_<PROFILE>_USER/SN_<PROFILE>_PASS in environment variables or .env before calling ServiceNow.'
  }

  [pscustomobject]@{
    Instance = $resolvedInstance.TrimEnd('/')
    UserName = $userName
    Password = $password
    Profile = if ([string]::IsNullOrWhiteSpace($Profile)) { $null } else { $normalizedProfile.ToLowerInvariant() }
    DotEnvPath = $dotEnvPath
  }
}
