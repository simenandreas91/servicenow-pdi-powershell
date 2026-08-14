[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Record', 'WeeklyReport', 'MarkSent')]
    [string]$Action,

    [string]$StoryNumber,
    [string]$StoryUrl,
    [string]$WorkDate,
    [string]$WeekStart,
    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DefaultLogPath {
    $codexRootPath = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $env:CODEX_HOME
    }
    else {
        Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
    }

    Join-Path $codexRootPath 'local-state\vaar-energi-story-worklog.json'
}

function Get-OsloNow {
    $timeZone = $null
    foreach ($timeZoneId in @('W. Europe Standard Time', 'Europe/Oslo')) {
        try {
            $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById($timeZoneId)
            break
        }
        catch {
            continue
        }
    }

    if ($null -eq $timeZone) {
        throw 'Could not resolve the Europe/Oslo time zone.'
    }

    [TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow, $timeZone)
}

function ConvertTo-IsoDate {
    param(
        [string]$Value,
        [string]$ParameterName
    )

    $parsed = [datetime]::MinValue
    $valid = [datetime]::TryParseExact(
        $Value,
        'yyyy-MM-dd',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )
    if (-not $valid) {
        throw "$ParameterName must use yyyy-MM-dd format."
    }

    $parsed.Date
}

function Read-WorkLog {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{
            version   = 1
            entries   = @()
            sentWeeks = @()
        }
    }

    $raw = [IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "The work log is empty: $Path"
    }

    $state = $raw | ConvertFrom-Json -AsHashtable
    if ($null -eq $state -or -not $state.ContainsKey('version')) {
        throw "The work log has an invalid schema: $Path"
    }

    if (-not $state.ContainsKey('entries') -or $null -eq $state['entries']) {
        $state['entries'] = @()
    }
    else {
        $state['entries'] = @($state['entries'])
    }

    if (-not $state.ContainsKey('sentWeeks') -or $null -eq $state['sentWeeks']) {
        $state['sentWeeks'] = @()
    }
    else {
        $state['sentWeeks'] = @($state['sentWeeks'])
    }

    $state
}

function Write-WorkLog {
    param(
        [hashtable]$State,
        [string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($directory)) {
        throw 'LogPath must include a parent directory.'
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

function Get-ResolvedWeekStart {
    param([string]$Value)

    $date = if ([string]::IsNullOrWhiteSpace($Value)) {
        (Get-OsloNow).Date
    }
    else {
        ConvertTo-IsoDate -Value $Value -ParameterName 'WeekStart'
    }

    $daysSinceMonday = (([int]$date.DayOfWeek + 6) % 7)
    $date.AddDays(-$daysSinceMonday)
}

function Get-WeeklyReport {
    param(
        [hashtable]$State,
        [datetime]$StartDate
    )

    $endDate = $StartDate.AddDays(4)
    $startText = $StartDate.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $endText = $endDate.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $isoWeek = [Globalization.ISOWeek]::GetWeekOfYear($StartDate)
    $culture = [Globalization.CultureInfo]::GetCultureInfo('en-GB')

    $entries = @(
        $State['entries'] |
            Where-Object { $_['date'] -ge $startText -and $_['date'] -le $endText } |
            Sort-Object @{ Expression = { $_['date'] } }, @{ Expression = { $_['story'] } }
    )

    $subject = "Vår Energi - stories worked on - week $isoWeek"
    $bodyLines = [Collections.Generic.List[string]]::new()
    $bodyLines.Add('Vår Energi stories worked on')
    $bodyLines.Add("Week $isoWeek ($($StartDate.ToString('d MMMM yyyy', $culture)) - $($endDate.ToString('d MMMM yyyy', $culture)))")
    $bodyLines.Add('')

    if ($entries.Count -eq 0) {
        $bodyLines.Add('No Vår Energi stories were recorded this week.')
    }
    else {
        foreach ($dateGroup in ($entries | Group-Object { $_['date'] })) {
            $groupDate = ConvertTo-IsoDate -Value $dateGroup.Name -ParameterName 'Entry date'
            $bodyLines.Add($groupDate.ToString('dddd d MMMM yyyy', $culture))
            foreach ($entry in $dateGroup.Group) {
                $bodyLines.Add("- $($entry['story'])")
            }
            $bodyLines.Add('')
        }
    }

    $sentRecord = @($State['sentWeeks'] | Where-Object { $_['weekStart'] -eq $startText }) | Select-Object -First 1

    [ordered]@{
        weekStart   = $startText
        weekEnd     = $endText
        isoWeek     = $isoWeek
        entryCount  = $entries.Count
        alreadySent = ($null -ne $sentRecord)
        subject     = $subject
        body        = ($bodyLines -join [Environment]::NewLine).TrimEnd()
        logPath     = $LogPath
    }
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Get-DefaultLogPath
}
$LogPath = [IO.Path]::GetFullPath($LogPath)

$mutex = [Threading.Mutex]::new($false, 'CodexVaarEnergiStoryWorkLog')
$lockAcquired = $false
try {
    $lockAcquired = $mutex.WaitOne([TimeSpan]::FromSeconds(15))
    if (-not $lockAcquired) {
        throw 'Timed out waiting for the Vår Energi story work-log lock.'
    }

    $state = Read-WorkLog -Path $LogPath

    switch ($Action) {
        'Record' {
            if ([string]::IsNullOrWhiteSpace($StoryNumber)) {
                throw 'StoryNumber is required for Record.'
            }

            $normalizedStory = $StoryNumber.Trim().ToUpperInvariant()
            if ($normalizedStory -notmatch '^STRY[0-9]+$') {
                throw 'StoryNumber must match STRY followed by digits.'
            }

            $normalizedUrl = $null
            if (-not [string]::IsNullOrWhiteSpace($StoryUrl)) {
                $uri = $null
                if (-not [uri]::TryCreate($StoryUrl.Trim(), [UriKind]::Absolute, [ref]$uri) -or
                    $uri.Scheme -ne 'https' -or
                    $uri.Host -notmatch '^varenergi(?:dev|test|prod)\.service-now\.com$') {
                    throw 'StoryUrl must be an HTTPS Vår Energi ServiceNow URL.'
                }
                $normalizedUrl = $uri.AbsoluteUri
            }

            $recordDate = if ([string]::IsNullOrWhiteSpace($WorkDate)) {
                (Get-OsloNow).Date
            }
            else {
                ConvertTo-IsoDate -Value $WorkDate -ParameterName 'WorkDate'
            }
            $dateText = $recordDate.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

            $existing = @($state['entries'] | Where-Object {
                $_['date'] -eq $dateText -and $_['story'] -eq $normalizedStory
            }) | Select-Object -First 1

            $status = 'already_present'
            if ($null -eq $existing) {
                $state['entries'] += [ordered]@{
                    date          = $dateText
                    story         = $normalizedStory
                    url           = $normalizedUrl
                    recordedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
                }
                Write-WorkLog -State $state -Path $LogPath
                $status = 'added'
            }
            elseif ([string]::IsNullOrWhiteSpace([string]$existing['url']) -and $null -ne $normalizedUrl) {
                $existing['url'] = $normalizedUrl
                Write-WorkLog -State $state -Path $LogPath
                $status = 'updated_link'
            }

            $result = [ordered]@{
                action  = 'Record'
                status  = $status
                date    = $dateText
                story   = $normalizedStory
                url     = $normalizedUrl
                logPath = $LogPath
            }
        }
        'WeeklyReport' {
            $resolvedWeekStart = Get-ResolvedWeekStart -Value $WeekStart
            $result = Get-WeeklyReport -State $state -StartDate $resolvedWeekStart
        }
        'MarkSent' {
            $resolvedWeekStart = Get-ResolvedWeekStart -Value $WeekStart
            $report = Get-WeeklyReport -State $state -StartDate $resolvedWeekStart
            if (-not $report['alreadySent']) {
                $state['sentWeeks'] += [ordered]@{
                    weekStart = $report['weekStart']
                    sentAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
                    entryCount = $report['entryCount']
                    subject = $report['subject']
                }
                Write-WorkLog -State $state -Path $LogPath
                $status = 'marked_sent'
            }
            else {
                $status = 'already_marked'
            }

            $result = [ordered]@{
                action     = 'MarkSent'
                status     = $status
                weekStart  = $report['weekStart']
                entryCount = $report['entryCount']
                subject    = $report['subject']
                logPath    = $LogPath
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
