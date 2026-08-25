[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Baseline', 'Check', 'Acknowledge', 'AwaitApproval', 'ListPending', 'RecordDecision', 'ListApproved', 'MarkBuilt')]
    [string]$Action,

    [string]$StoriesJson,
    [string]$StorySysId,
    [string]$StoryNumber,
    [string]$ApprovalThreadId,
    [string]$ApprovalMessageId,
    [ValidateSet('Approved', 'Declined')]
    [string]$Decision,
    [string]$DecisionMessageId,
    [string]$StatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DefaultStatePath {
    $codexRootPath = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $env:CODEX_HOME
    }
    else {
        Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
    }

    Join-Path $codexRootPath 'local-state\vaar-energi-story-monitor.json'
}

function Read-MonitorState {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{
            version      = 1
            knownStories = @()
        }
    }

    $raw = [IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "The story-monitor state file is empty: $Path"
    }

    $state = $raw | ConvertFrom-Json -AsHashtable
    if ($null -eq $state -or $state['version'] -ne 1) {
        throw "The story-monitor state file has an unsupported schema: $Path"
    }

    if (-not $state.ContainsKey('knownStories') -or $null -eq $state['knownStories']) {
        $state['knownStories'] = @()
    }
    else {
        $state['knownStories'] = @($state['knownStories'])
    }

    $state
}

function Write-MonitorState {
    param(
        [hashtable]$State,
        [string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($directory)) {
        throw 'StatePath must include a parent directory.'
    }

    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temporaryPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')

    try {
        $json = $State | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText($temporaryPath, $json, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Assert-StoryIdentity {
    param(
        [string]$SysId,
        [string]$Number
    )

    if ([string]::IsNullOrWhiteSpace($SysId) -or $SysId.Trim() -notmatch '^[0-9a-fA-F]{32}$') {
        throw 'StorySysId must be a 32-character hexadecimal ServiceNow sys_id.'
    }
    if ([string]::IsNullOrWhiteSpace($Number) -or $Number.Trim().ToUpperInvariant() -notmatch '^STRY[0-9]+$') {
        throw 'StoryNumber must match STRY followed by digits.'
    }
}

function ConvertFrom-StoriesJson {
    param([string]$Json)

    if ([string]::IsNullOrWhiteSpace($Json)) {
        throw 'StoriesJson is required for Baseline and Check.'
    }

    $parsed = @($Json | ConvertFrom-Json -AsHashtable)
    $stories = [Collections.Generic.List[hashtable]]::new()
    foreach ($story in $parsed) {
        if ($null -eq $story -or -not $story.ContainsKey('sys_id') -or -not $story.ContainsKey('number')) {
            throw 'Each StoriesJson item must contain sys_id and number.'
        }

        $sysId = ([string]$story['sys_id']).Trim().ToLowerInvariant()
        $number = ([string]$story['number']).Trim().ToUpperInvariant()
        Assert-StoryIdentity -SysId $sysId -Number $number
        $stories.Add(@{
            sys_id = $sysId
            number = $number
        })
    }

    @($stories)
}

if ([string]::IsNullOrWhiteSpace($StatePath)) {
    $StatePath = Get-DefaultStatePath
}
$StatePath = [IO.Path]::GetFullPath($StatePath)

$mutex = [Threading.Mutex]::new($false, 'CodexVaarEnergiStoryMonitor')
$lockAcquired = $false
try {
    $lockAcquired = $mutex.WaitOne([TimeSpan]::FromSeconds(15))
    if (-not $lockAcquired) {
        throw 'Timed out waiting for the Vår Energi story-monitor lock.'
    }

    $state = Read-MonitorState -Path $StatePath
    $now = [DateTimeOffset]::UtcNow.ToString('o')

    switch ($Action) {
        'Baseline' {
            $stories = ConvertFrom-StoriesJson -Json $StoriesJson
            $added = 0
            foreach ($story in $stories) {
                $existing = @($state['knownStories'] | Where-Object { $_['sysId'] -eq $story['sys_id'] }) | Select-Object -First 1
                if ($null -eq $existing) {
                    $state['knownStories'] += [ordered]@{
                        sysId          = $story['sys_id']
                        number         = $story['number']
                        disposition    = 'baseline'
                        acknowledgedAt = $now
                    }
                    $added++
                }
            }
            $state['lastBaselineAt'] = $now
            Write-MonitorState -State $state -Path $StatePath

            $result = [ordered]@{
                action     = 'Baseline'
                added      = $added
                knownCount = @($state['knownStories']).Count
                statePath  = $StatePath
            }
        }
        'Check' {
            $stories = ConvertFrom-StoriesJson -Json $StoriesJson
            $knownIds = @{}
            foreach ($knownStory in @($state['knownStories'])) {
                $knownIds[[string]$knownStory['sysId']] = $true
            }

            $newStories = @($stories | Where-Object { -not $knownIds.ContainsKey($_['sys_id']) })
            $result = [ordered]@{
                action       = 'Check'
                currentCount = $stories.Count
                knownCount   = @($state['knownStories']).Count
                newCount     = $newStories.Count
                newStories   = $newStories
                statePath    = $StatePath
            }
        }
        'Acknowledge' {
            $normalizedSysId = if ($null -eq $StorySysId) { '' } else { $StorySysId.Trim().ToLowerInvariant() }
            $normalizedNumber = if ($null -eq $StoryNumber) { '' } else { $StoryNumber.Trim().ToUpperInvariant() }
            Assert-StoryIdentity -SysId $normalizedSysId -Number $normalizedNumber

            $existing = @($state['knownStories'] | Where-Object { $_['sysId'] -eq $normalizedSysId }) | Select-Object -First 1
            $status = 'already_acknowledged'
            if ($null -eq $existing) {
                $state['knownStories'] += [ordered]@{
                    sysId          = $normalizedSysId
                    number         = $normalizedNumber
                    disposition    = 'reviewed'
                    acknowledgedAt = $now
                }
                Write-MonitorState -State $state -Path $StatePath
                $status = 'acknowledged'
            }

            $result = [ordered]@{
                action     = 'Acknowledge'
                status     = $status
                story      = $normalizedNumber
                knownCount = @($state['knownStories']).Count
                statePath  = $StatePath
            }
        }
        'AwaitApproval' {
            $normalizedSysId = if ($null -eq $StorySysId) { '' } else { $StorySysId.Trim().ToLowerInvariant() }
            $normalizedNumber = if ($null -eq $StoryNumber) { '' } else { $StoryNumber.Trim().ToUpperInvariant() }
            Assert-StoryIdentity -SysId $normalizedSysId -Number $normalizedNumber
            if ([string]::IsNullOrWhiteSpace($ApprovalThreadId) -or [string]::IsNullOrWhiteSpace($ApprovalMessageId)) {
                throw 'ApprovalThreadId and ApprovalMessageId are required for AwaitApproval.'
            }

            $existing = @($state['knownStories'] | Where-Object { $_['sysId'] -eq $normalizedSysId }) | Select-Object -First 1
            $status = 'updated'
            if ($null -eq $existing) {
                $existing = [ordered]@{
                    sysId = $normalizedSysId
                    number = $normalizedNumber
                }
                $state['knownStories'] += $existing
                $status = 'recorded'
            }

            $existing['number'] = $normalizedNumber
            $existing['disposition'] = 'awaiting_approval'
            $existing['approvalThreadId'] = $ApprovalThreadId.Trim()
            $existing['approvalMessageId'] = $ApprovalMessageId.Trim()
            $existing['approvalSentAt'] = $now
            $existing.Remove('decision')
            $existing.Remove('decisionMessageId')
            $existing.Remove('decidedAt')
            Write-MonitorState -State $state -Path $StatePath

            $result = [ordered]@{
                action     = 'AwaitApproval'
                status     = $status
                story      = $normalizedNumber
                knownCount = @($state['knownStories']).Count
                statePath  = $StatePath
            }
        }
        'ListPending' {
            $pending = @(
                $state['knownStories'] |
                    Where-Object { $_['disposition'] -eq 'awaiting_approval' } |
                    ForEach-Object {
                        [ordered]@{
                            sysId             = $_['sysId']
                            number            = $_['number']
                            approvalThreadId  = $_['approvalThreadId']
                            approvalMessageId = $_['approvalMessageId']
                            approvalSentAt    = $_['approvalSentAt']
                        }
                    }
            )
            $result = [ordered]@{
                action    = 'ListPending'
                count     = $pending.Count
                approvals = $pending
                statePath = $StatePath
            }
        }
        'RecordDecision' {
            $normalizedSysId = if ($null -eq $StorySysId) { '' } else { $StorySysId.Trim().ToLowerInvariant() }
            $normalizedNumber = if ($null -eq $StoryNumber) { '' } else { $StoryNumber.Trim().ToUpperInvariant() }
            Assert-StoryIdentity -SysId $normalizedSysId -Number $normalizedNumber
            if ([string]::IsNullOrWhiteSpace($Decision) -or [string]::IsNullOrWhiteSpace($DecisionMessageId)) {
                throw 'Decision and DecisionMessageId are required for RecordDecision.'
            }

            $existing = @($state['knownStories'] | Where-Object {
                $_['sysId'] -eq $normalizedSysId -and $_['number'] -eq $normalizedNumber
            }) | Select-Object -First 1
            if ($null -eq $existing -or $existing['disposition'] -ne 'awaiting_approval') {
                throw "No pending approval was found for $normalizedNumber."
            }

            $existing['decision'] = $Decision.ToLowerInvariant()
            $existing['decisionMessageId'] = $DecisionMessageId.Trim()
            $existing['decidedAt'] = $now
            $existing['disposition'] = if ($Decision -eq 'Approved') { 'approved_pending_build' } else { 'declined' }
            Write-MonitorState -State $state -Path $StatePath

            $result = [ordered]@{
                action      = 'RecordDecision'
                story       = $normalizedNumber
                decision    = $Decision.ToLowerInvariant()
                disposition = $existing['disposition']
                statePath   = $StatePath
            }
        }
        'ListApproved' {
            $approved = @(
                $state['knownStories'] |
                    Where-Object { $_['disposition'] -eq 'approved_pending_build' } |
                    ForEach-Object {
                        [ordered]@{
                            sysId             = $_['sysId']
                            number            = $_['number']
                            approvalThreadId  = $_['approvalThreadId']
                            approvalMessageId = $_['approvalMessageId']
                            decisionMessageId = $_['decisionMessageId']
                            decidedAt         = $_['decidedAt']
                        }
                    }
            )
            $result = [ordered]@{
                action    = 'ListApproved'
                count     = $approved.Count
                approvals = $approved
                statePath = $StatePath
            }
        }
        'MarkBuilt' {
            $normalizedSysId = if ($null -eq $StorySysId) { '' } else { $StorySysId.Trim().ToLowerInvariant() }
            $normalizedNumber = if ($null -eq $StoryNumber) { '' } else { $StoryNumber.Trim().ToUpperInvariant() }
            Assert-StoryIdentity -SysId $normalizedSysId -Number $normalizedNumber

            $existing = @($state['knownStories'] | Where-Object {
                $_['sysId'] -eq $normalizedSysId -and $_['number'] -eq $normalizedNumber
            }) | Select-Object -First 1
            if ($null -eq $existing -or $existing['disposition'] -ne 'approved_pending_build') {
                throw "No approved pending build was found for $normalizedNumber."
            }

            $existing['disposition'] = 'built'
            $existing['builtAt'] = $now
            Write-MonitorState -State $state -Path $StatePath

            $result = [ordered]@{
                action    = 'MarkBuilt'
                story     = $normalizedNumber
                status    = 'built'
                statePath = $StatePath
            }
        }
    }

    $result | ConvertTo-Json -Depth 6 -Compress
}
finally {
    if ($lockAcquired) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}
